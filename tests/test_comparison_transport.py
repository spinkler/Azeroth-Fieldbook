"""Timed two-client comparison using the real queues, catalogue and receipts."""
import base64
import unittest
import zlib

from test_bestiary_comparison import clients


def install_encoding(lua):
    # Pass binary arguments as hex across Lupa's UTF-8 Python boundary.
    def deflate(data):
        compressor = zlib.compressobj(wbits=-15)
        return compressor.compress(bytes.fromhex(data)) + compressor.flush()

    lua.globals().deflate = deflate
    lua.globals().inflate = lambda data: zlib.decompress(bytes.fromhex(data), -15)
    lua.globals().to_base64 = lambda data: base64.b64encode(bytes.fromhex(data))
    lua.globals().from_base64 = lambda data: base64.b64decode(data, validate=True)
    lua.execute("""
        local function hex(s)
            return (s:gsub('.',function(c) return string.format('%02x',c:byte()) end))
        end
        encoding={
            CompressString=function(s) return deflate(hex(s)) end,
            DecompressString=function(s) return inflate(hex(s)) end,
            EncodeBase64=function(s) return to_base64(hex(s)) end,
            DecodeBase64=function(s) return from_base64(s) end,
        }
    """)


def timed_clients(sender_codec=True, receiver_codec=True):
    lua = clients()
    install_encoding(lua)
    lua.globals().a.env.encoding = lua.globals().encoding if sender_codec else None
    lua.globals().b.env.encoding = lua.globals().encoding if receiver_codec else None
    lua.execute("""
        frame=0
        local epoch=now
        for _,p in ipairs({a,b}) do
            p.env.clock=function() return frame/20 end
            p.e=ns.CreateSharing(p.j,p.env);p.c=p.e.comparison
        end
        local active
        function useNativeDrivers()
            C_ChatInfo={RegisterAddonMessagePrefix=function() return Enum.RegisterAddonMessagePrefixResult.Success end,
                SendAddonMessage=function(...)
                    assert(active.env.send(...));return Enum.SendAddonMessageResult.Success
                end}
            for _,p in ipairs({a,b}) do
                playerName=p.name;C_EncodingUtil=p.env.encoding
                p.e=ns.InitializeSharing(p.j);p.c=p.e.comparison;p.driver=objects[#objects]
            end
        end
        local function tick(p)
            active=p
            if p.driver then p.driver.scripts.OnUpdate(p.driver,0.05) else p.e:Tick() end
        end
        function advance()
            frame=frame+1;now=epoch+math.floor(frame/20)
            local arriving=wire;wire={}
            for _,m in ipairs(arriving) do
                local to=m.target==a.name and a or b
                assert(to.name==m.target)
                if to.driver then to.driver.scripts.OnEvent(to.driver,'CHAT_MSG_ADDON',m.prefix,m.text,'WHISPER',m.from)
                else to.e:Receive(m.prefix,m.text,'WHISPER',m.from) end
            end
            tick(a);tick(b)
        end
        function untilStage(p,stage,other)
            local start=frame
            while p.c.session==nil or p.c.session.stage~=stage or
                    (other and (not other.c.session or other.c.session.stage~=stage)) do
                assert(frame-start<16000 and not (p.c.session and p.c.session.stage=='closed'),
                    p.c.session and (p.c.session.message or p.c.session.stage) or stage)
                advance()
            end
            return (frame-start)/20
        end
        function stats(start)
            local bytes=0
            for i=start+1,#packets do bytes=bytes+#packets[i].text end
            return {packets=#packets-start,bytes=bytes}
        end
        function sync()
            assert(a.c:Invite(b.name));untilStage(b,'invited')
            b.c:AcceptInvitation();untilStage(a,'ready',b)
        end
        function giveAll()
            a.c:Select('give',nil,true);assert(a.c:Approve())
            untilStage(b,'review');assert(b.c:Approve())
        end
        function populate()
            local regions={'Elwynn Forest','Duskwood','Westfall','Redridge Mountains','Dun Morogh','Loch Modan',
                'Darkshore','Ashenvale','Wetlands','Badlands','Stranglethorn Vale'}
            local names={'Wolf','Spider','Bear','Raptor','Owl','Stag','Strider','Boar','Vulture','Basilisk',
                'Crocolisk','Scorpid','Lynx'}
            for i=1,501 do
                local region=regions[(i-1)%#regions+1]
                local name=region..' '..names[(i-1)%#names+1]..' '..math.ceil(i/(#regions*#names))
                for _,p in ipairs({a,b}) do
                    if (p==a and i<=500) or (p==b and (i<=496 or i==501)) then
                        local e=entry(p,1000+i,name)
                        e.locations={[region]=true}
                        e.levelMin=3+i%48;e.levelMax=e.levelMin+2
                        if i%3==0 then e.behaviours.Patrols=true end
                        if i%5==0 then e.offenses.Fire=true end
                    end
                end
            end
            a.db.bestiary.points.earned=100;b.db.bestiary.points.earned=100
        end
        function measure()
            populate();assert(a.c:Invite(b.name));untilStage(b,'invited')
            local start=#packets
            b.c:AcceptInvitation()
            local seconds=untilStage(a,'ready',b)
            local catalogue=stats(start);catalogue.seconds=seconds
            a.c:Select('give',nil,true);a.c:Select('take',nil,true)
            eq(a.c.session.outgoing.entries,4);eq(a.c.session.incoming.entries,1)
            assert(a.c:Approve());untilStage(b,'review')
            start=#packets;assert(b.c:Approve())
            seconds=untilStage(a,'done',b)
            local exchange=stats(start);exchange.seconds=seconds
            eq(a.c.session.sent,4);eq(a.c.session.received,1)
            balance(a,94,6);balance(b,98,2)
            return catalogue,exchange
        end
    """)
    return lua


class ComparisonTransportTests(unittest.TestCase):
    def test_large_catalogue_and_five_reports(self):
        raw = timed_clients(receiver_codec=False)
        raw.globals().useNativeDrivers()
        raw_catalogue, raw_exchange = raw.globals().measure()
        self.assertEqual(raw.globals().a.c.session.mode, '2')
        packed = timed_clients()
        packed.globals().useNativeDrivers()
        catalogue, exchange = packed.globals().measure()
        self.assertEqual(packed.globals().b.c.session.mode, '2z')
        self.assertLess(catalogue.bytes, raw_catalogue.bytes / 2)
        self.assertLess(catalogue.packets, raw_catalogue.packets / 2)
        self.assertLess(catalogue.seconds, raw_catalogue.seconds / 2)
        self.assertLess(raw_catalogue.seconds, 100)
        self.assertLess(max(raw_exchange.seconds, exchange.seconds), 6)

    def test_codec_bounds_localized_text_and_literal_fallback(self):
        lua = timed_clients()
        lua.execute("""
            local c=ns.ComparisonCodec
            math.randomseed(27)
            local letters={}
            for i=1,4096 do letters[i]=string.char(math.random(33,122)) end
            local noise=table.concat(letters)
            eq(c.Pack(encoding,noise,180),noise)
            eq(c.Pack(encoding,'00',180),'00')
            local raw=noise..string.rep('x',4095)..'Élan 森林'..noise
            local packed=c.Pack(encoding,raw,180)
            assert(packed:match('^Z%d+:0:'),'incompressible first block stays literal')
            eq(c.Unpack(encoding,packed,#raw),raw)
            assert(not c.Unpack(nil,packed,#raw) and not c.Unpack(encoding,packed,#raw-1))
            assert(not c.Unpack(encoding,packed:sub(1,-2),#raw))
            assert(not c.Unpack(encoding,packed..'x',#raw))
            for _,wireText in ipairs({'Z9999999:4:AAAA','Z300:4:!!!!','Z300:4:eA==','Z300:0:short',
                    'Z300:8:QWxhZGRpb','Z300:4:A===','Z20:11:12345678901'}) do
                assert(not c.Unpack(encoding,wireText,8192),wireText)
            end
            local wrongSize=c.Pack(encoding,string.rep('a',8192),180):gsub('^Z8192:', 'Z500:')
            assert(not c.Unpack(encoding,wrongSize,8192))
            for _,bad in ipairs({function() return secret end,function() error('unavailable') end,function() end}) do
                local api=setmetatable({CompressString=bad},{__index=encoding})
                eq(c.Pack(api,string.rep('0',2048),180),string.rep('0',2048))
            end
        """)

    def test_original_comparison_handshake_in_both_directions(self):
        lua = timed_clients()
        lua.execute("""
            fixture()
            local original=b.c.Receive
            function b.c:Receive(id,sender,body)
                if body:sub(1,1)=='I' and body~='I1~'..buildVersion then
                    b.env.send('AFBShare','4~B~'..id..'~Xversion','WHISPER',sender)
                    return
                end
                return original(self,id,sender,body)
            end
            sync();eq(a.c.session.mode,'1');eq(b.c.session.mode,'1')
            local ids={}
            for _,m in ipairs(packets) do
                local id=m.text:match('^4~B~([%d%-]+)~I')
                if id then ids[#ids+1]=id end
                assert(not m.text:match('~[SQP]1/%d+:Z'))
            end
            eq(#ids,2);assert(ids[1]~=ids[2])
            giveAll();untilStage(a,'done',b);balance(a,15,5);balance(b,20,0)

            -- An original inviter simply sends I1 and understands only Y1.
            local send=a.env.send
            a.env.send=function(prefix,text,channel,target)
                return send(prefix,(text:gsub('~I2z~','~I1~')),channel,target)
            end
            b.c.Receive=original;sync();eq(a.c.session.mode,'1');eq(b.c.session.mode,'1')
        """)

    def test_busy_catalogue_backs_off_and_resumes_the_same_packet(self):
        lua = timed_clients(sender_codec=False)
        lua.execute("""
            for i=1,40 do entry(a,i,'Redridge Wolf '..i) end
            local send=a.env.send
            local tries={}
            a.env.send=function(prefix,text,channel,target)
                if text:match('~S1/') then
                    tries[#tries+1]={frame=frame,text=text}
                    if #tries<=2 then return false,'throttle' end
                end
                return send(prefix,text,channel,target)
            end
            assert(a.c:Invite(b.name));untilStage(b,'invited');b.c:AcceptInvitation()
            while #tries<3 do advance() end
            eq(tries[1].text,tries[2].text);eq(tries[2].text,tries[3].text)
            assert(tries[2].frame-tries[1].frame>=40 and tries[3].frame-tries[2].frame>=80)
            assert(a.c.session.rate<400)
            frame=frame+40;local start=#packets
            for i=1,20 do a.e:Tick() end
            eq(#packets-start,1,'a stalled frame cannot bank a send burst')
            untilStage(a,'ready',b)
            eq(a.c.session.mode,'2');eq(b.c.session.mode,'2');eq(#b.c.session.theirs,40)
        """)

    def test_large_batch_keeps_its_own_receive_budget(self):
        lua = timed_clients()
        lua.execute("""
            for i=1,80 do entry(a,i,'Marsh Owl '..i) end
            a.db.bestiary.points.earned=80
            sync()
            for i=1,190 do b.e:Receive('AFBShare','4~K~1-1-1','WHISPER','Another Player') end
            b.e:Receive('AFBShare','4~H~1-2-1~'..buildVersion,'WHISPER','Another Player')
            assert(not next(b.j:GetSharingStorage().incoming),'ordinary traffic is still capped')
            local start=#packets;giveAll()
            local seconds=untilStage(a,'done',b)
            local incoming=0
            for i=start+1,#packets do if packets[i].from==a.name then incoming=incoming+1 end end
            assert(seconds<60 and incoming>180)
            eq(a.c.session.sent,80);balance(a,0,80);balance(b,0,0)
        """)

    def test_compressed_lore_and_paid_retry_with_a_literal_report(self):
        lua = timed_clients()
        lua.execute("""
            local owl=entry(a,1,'Forest Owl');owl.locations={};owl.levelMax=9
            owl.beastLore={level=9,observed=now,rows={}};owl.beastLoreSource='gameTooltip'
            for i=1,32 do owl.beastLore.rows[i]={left='Field '..i,right=string.rep('plume ',30)} end
            local bear=entry(a,2,'Moss Bear')
            for i=1,16 do bear.abilities['Forest guardian call '..i]={state='confirmed',spellID=500+i} end
            a.db.bestiary.points.earned=17
            local send=a.env.send
            a.env.send=function(prefix,text,channel,target)
                local tx=a.e:GetOutgoing()
                if tx and tx.cost>0 and text:match('^4~C~') then return true end
                return send(prefix,text,channel,target)
            end
            sync();giveAll();untilStage(a,'closed')
            eq(#b.j.entries[1].beastLore.rows,32)
            eq(b.j.entries[1].beastLore.rows[32].right,owl.beastLore.rows[32].right)
            local tx=a.e:GetOutgoing();eq(tx.stage,'unknown');eq(tx.cost,17)
            local original=tx.payload;eq(#ns.SharingReport.Decode(original).rumours,16)
            local packed=0
            for _,m in ipairs(packets) do if m.text:match('^4~O~[%d%-]+~1~%d+~Z') then packed=packed+1 end end
            eq(packed,2);balance(a,0,17)

            -- After losing the staged receive data and reloading, the original
            -- paid transaction can be offered through ordinary Share.
            a.env.send=send;a.e=ns.CreateSharing(a.j,a.env);a.c=a.e.comparison
            b=client(b.name);b.env.clock=a.env.clock;b.e=ns.CreateSharing(b.j,b.env);b.c=b.e.comparison
            packets={};wire={};assert(a.e:Retry())
            local start=frame
            while #b.e:GetIncoming()==0 do assert(frame-start<600);advance() end
            local item=b.e:GetIncoming()[1];eq(item.payload,original);eq(item.comparison,nil)
            for _,m in ipairs(packets) do assert(not m.text:match('^4~O~[%d%-]+~1~%d+~Z')) end
            assert(b.e:Accept(item))
            while tx.stage~='complete' do assert(frame-start<1000);advance() end
            eq(#b.j:GetRumours(2),16);balance(a,0,17)
        """)

    def test_packed_data_requires_the_agreed_session(self):
        lua = timed_clients()
        lua.execute("""
            fixture();sync()
            local value=assert(ns.SharingReport.Capture(a.j,101))
            value.created,value.recipient,value.transaction=now,b.name,'99-99-99'
            value.locations={}
            for i=1,8 do value.locations[i]='Elwynn survey area '..i..string.rep('x',40) end
            local packed=ns.ComparisonCodec.Pack(encoding,assert(ns.SharingReport.Encode(value)),180)
            assert(packed:sub(1,1)=='Z' and #packed<=180)
            local function receive(text) b.e:Receive('AFBShare',text,'WHISPER',a.name) end
            receive('4~H~99-99-99~'..buildVersion)
            receive('4~O~99-99-99~1~1~'..packed)
            assert(not next(b.j:GetSharingStorage().incoming) and not b.j.entries[101])
            local s=b.c.session;eq(s.stage,'ready')
            receive('4~B~'..s.id..'~P1/1:Z10000:4:!!!!')
            eq(s.stage,'closed');balance(b,20,0)
        """)


if __name__ == '__main__':
    unittest.main()
