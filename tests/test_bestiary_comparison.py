"""Two independent Bestiaries using the real whisper dispatcher and Lua 5.1 widgets."""
import unittest

from ui_test_harness import new_ui_client


MODULES = ['TextSize.lua', 'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua',
           'SharingReport.lua', 'BestiaryJournal.lua', 'BestiaryComparison.lua',
           'ComparisonCodec.lua', 'ComparisonSession.lua', 'Sharing.lua', 'Scrollbars.lua', 'ActionButtons.lua',
           'FieldbookShell.lua', 'ComparisonWindow.lua', 'SharingWindow.lua',
           'BestiaryPages.lua', 'BestiaryBook.lua']


def clients():
    lua = new_ui_client(MODULES)
    lua.execute("""
        D=ns.BestiaryComparison
        wire={};packets={}
        function client(name)
            local p={name=name,db={}}
            p.j=ns.CreateBestiaryJournal(p.db,function() return nil end)
            p.env={character=name,addonVersion=buildVersion,ready=true,now=time,
                blocked=function() return p.blocked==true end,nonce=function() return 123456 end,
                send=function(prefix,text,channel,target)
                    assert(#text<=240 and channel=='WHISPER')
                    local msg={prefix=prefix,text=text,from=name,target=target}
                    wire[#wire+1]=msg;packets[#packets+1]=msg
                    return true
                end}
            p.e=ns.CreateSharing(p.j,p.env);p.c=p.e.comparison
            return p
        end
        a=client('Alice Sunstrider');b=client('Bob Stonewell')
        function pump(seconds)
            for _=1,seconds do
                now=now+1;a.e:Tick();b.e:Tick()
                local received=wire;wire={}
                for _,m in ipairs(received) do
                    if not drop or not drop(m) then
                        local to=m.target==a.name and a or b
                        assert(to.name==m.target)
                        to.e:Receive(m.prefix,m.text,'WHISPER',m.from)
                    end
                end
            end
        end
        function waitFor(fn,seconds)
            for _=1,seconds or 120 do if fn() then return end;pump(1) end
            assert(fn(),(a.c.session and a.c.session.stage..' '..(a.c.session.message or '') or '-')..
                ' / '..(b.c.session and b.c.session.stage..' '..(b.c.session.message or '') or '-'))
        end
        function entry(p,id,name,rank)
            local e=p.j:Ensure(id,false,name,{level=9})
            e.category='Beast';e.levelMin,e.levelMax=9,10;e.locations.Elwynn=true;e.rank=rank
            return e
        end
        function fixture()
            local e=entry(a,101,'Amber Wolf','Elite')
            e.behaviours.Patrols=true;e.offenses.Fire=true
            e.notes='private field note'
            e.beastLore={level=9,observed=now,rows={{left='Diet:',right='Private tooltip meat'}}}
            e.beastLoreSource='gameTooltip'
            local mine=entry(a,102,'Marsh Strider','Elite')
            local theirs=entry(b,102,'Marsh Strider','Rare')
            mine.abilities.Blast={state='confirmed',spellID=500}
            theirs.abilities.Burst={state='pending',spellID=500}
            mine.behaviours.Melee=true;theirs.behaviours.Heals=true
            local owl=entry(b,103,'Owlet','Rare');owl.immunities.Fire=true
            entry(a,104,'Grey Stag');entry(b,104,'Grey Stag')
            a.db.bestiary.points.earned=20;b.db.bestiary.points.earned=20
        end
        function compare()
            assert(a.c:Invite(b.name));pump(2)
            eq(b.c.session.stage,'invited')
            for _,m in ipairs(packets) do assert(not m.text:find('~S1/',1,true),'catalogue before consent') end
            b.c:AcceptInvitation()
            waitFor(function() return a.c.session.stage=='ready' and b.c.session.stage=='ready' end)
        end
        function selectBoth()
            a.c:Select('give',nil,true);a.c:Select('take',nil,true)
            assert(a.c:Approve())
            waitFor(function() return b.c.session.stage=='review' end)
        end
        function balance(p,available,spent)
            eq(p.j:GetSharingBalance(),available);eq(select(3,p.j:GetSharingBalance()),spent)
            eq(select(4,p.j:GetSharingBalance()),0)
        end
    """)
    return lua


class BestiaryComparisonTests(unittest.TestCase):
    def test_two_way_exchange_pricing_provenance_and_repeat(self):
        lua = clients()
        lua.execute("""
            fixture();compare()
            local s=a.c.session
            eq(#s.rows,4);eq(s.byID[101].theirs,nil);eq(s.byID[103].mine,nil)
            local r=s.byID[102]
            eq(#r.give.indices,1);eq(#r.take.indices,1)
            eq(r.give.cost,1);eq(r.give.reserve,3);eq(r.take.cost,2)
            assert(not D.CanSelect(s.byID[104].give))
            selectBoth()
            eq(s.outgoing.cost,5);eq(s.outgoing.required,7);eq(s.outgoing.lore,1)
            eq(s.incoming.cost,6);eq(b.c.session.outgoing.cost,6)
            balance(a,20,0);balance(b,20,0);assert(not b.j.entries[101] and not a.j.entries[103])
            for _,m in ipairs(packets) do
                assert(not m.text:find('private field note',1,true))
                assert(not m.text:find('Private tooltip meat',1,true))
            end
            assert(b.c:Approve())
            waitFor(function() return s.stage=='done' and b.c.session.stage=='done' end,160)
            eq(s.sent,3);eq(s.received,2);eq(s.spent,5);eq(s.peerSpent,6)
            balance(a,15,5);balance(b,14,6)
            eq(#b.j:GetRumours(101),2);eq(b.j:GetRumours(101)[1].sender,a.name)
            eq(b.j.entries[101].beastLoreSender,a.name);assert(not b.j.entries[101].personalEncountered)
            eq(b.j.entries[101].beastLore.rows[1].right,'Private tooltip meat')
            assert(not b.j.entries[101].behaviours.Patrols)
            eq(#b.j:GetRumours(102),1);eq(#a.j:GetRumours(102),1);eq(#a.j:GetRumours(103),1)
            packets={};compare()
            a.c:Select('give',nil,true);a.c:Select('take',nil,true)
            eq(a.c.session.outgoing.entries,0);eq(a.c.session.incoming.entries,0)
        """)

    def test_consent_blocks_mismatch_decline_and_spoof(self):
        lua = clients()
        lua.execute("""
            fixture();b.env.addonVersion='0.0.1'
            assert(a.c:Invite(b.name));pump(5);eq(a.c.session.stage,'closed');assert(not b.c.session)
            b.env.addonVersion=buildVersion;b.j:SetBlockIncomingOffers(true)
            assert(a.c:Invite(b.name));pump(5);eq(a.c.session.stage,'closed');assert(not b.c.session)
            b.j:SetBlockIncomingOffers(false);packets={};compare()
            a.c:Select('take',nil,true);assert(a.c:Approve());pump(3)
            local s=a.c.session;eq(s.stage,'proposed')
            a.e:Receive('AFBShare','4~B~'..s.id..'~A','WHISPER','False Friend')
            a.e:Receive('AFBShare','4~B~1-1-1~A','WHISPER',b.name)
            a.e:Receive('AFBShare','4~B~'..s.id..'~A','PARTY',b.name)
            eq(s.stage,'proposed')
            b.c:Close('declined');pump(3)
            eq(s.stage,'closed');balance(a,20,0);balance(b,20,0)
            packets={};compare();selectBoth()
            b.j:SetBlockIncomingOffers(true);pump(3)
            eq(s.stage,'closed');eq(a.c.session.stage,'closed');assert(not a.j.entries[103])
            balance(a,20,0);balance(b,20,0)
        """)

    def test_affordability_snapshot_changes_and_free_lore(self):
        lua = clients()
        lua.execute("""
            fixture();compare();a.c:Select('give',nil,true)
            a.db.bestiary.points.earned=5
            assert(not a.c:Approve(),'batch must fund the temporary maximum of each report')
            a.db.bestiary.points.earned=7;assert(a.c:Approve());pump(3)
            a.j.entries[101].rank='Rare';assert(b.c:Approve());pump(8)
            eq(a.c.session.stage,'closed');balance(a,7,0);assert(not b.j.entries[101])
            a.j.entries[101].rank='Elite'
            local copy=entry(b,101,'Amber Wolf','Elite');copy.behaviours.Patrols=true;copy.offenses.Fire=true
            a.db.bestiary.points.earned=0;packets={};compare()
            a.c:Select('give',101,true)
            eq(a.c.session.outgoing.cost,0);eq(a.c.session.outgoing.required,0)
            assert(a.c:Approve());pump(3);assert(b.c:Approve())
            waitFor(function() return a.c.session.stage=='done' end)
            balance(a,0,0);eq(copy.beastLoreSender,a.name)
        """)

    def test_stale_receiver_quote_and_paid_retry(self):
        lua = clients()
        lua.execute("""
            fixture();compare()
            a.c:Select('give',102,true);assert(a.c:Approve());pump(3)
            b.j.entries[102].locations={}
            assert(b.c:Approve());pump(25);eq(a.c.session.stage,'closed')
            balance(a,20,0);eq(#b.j:GetRumours(102),0)
            packets={};compare()
            a.c:Select('give',101,true);assert(a.c:Approve());pump(3)
            drop=function(m) return m.text:find('~K~',1,true) and a.e:GetOutgoing().cost>0 end
            assert(b.c:Approve());pump(90)
            eq(a.c.session.stage,'closed');eq(a.e:GetOutgoing().stage,'unknown')
            balance(a,16,4);eq(#b.j:GetRumours(101),2);assert(b.j.entries[101].beastLore)
            drop=nil;assert(a.e:Retry());pump(20);eq(a.e:GetOutgoing().stage,'complete')
            balance(a,16,4);eq(#b.j:GetRumours(101),2)
        """)

    def test_lore_supplies_free_basics_before_pricing_traits(self):
        lua = clients()
        lua.execute("""
            local wolf=entry(a,1,'Wolf')
            wolf.locations={};wolf.levelMax=wolf.levelMin
            wolf.beastLore={level=9,observed=now,rows={{left='Diet:',right='Meat'}}}
            wolf.beastLoreSource='gameTooltip'
            a.db.bestiary.points.earned=0;compare()
            a.c:Select('give',1,true)
            local p=a.c.session.outgoing
            eq(#p.jobs,1);eq(p.lore,1);eq(p.cost,0);eq(p.required,0)
            assert(a.c:Approve());pump(3);assert(b.c:Approve());pump(20)
            eq(a.c.session.stage,'done');balance(a,0,0)
            eq(b.j:GetBasicInfo(1).levelMin,9);eq(b.j.entries[1].beastLoreSender,a.name)
            b.j:Reset();packets={}
            wolf.behaviours.Patrols=true;a.db.bestiary.points.earned=2
            compare();a.c:Select('give',1,true);p=a.c.session.outgoing
            eq(p.cost,1);eq(p.required,2);assert(p.jobs[1].lore)
            assert(a.c:Approve());pump(3);assert(b.c:Approve());pump(28)
            eq(a.c.session.stage,'done');balance(a,1,1);eq(#b.j:GetRumours(1),1)
        """)

    def test_swapping_overlapping_basics_while_other_reports_are_in_flight(self):
        lua = clients()
        lua.execute("""
            local left=entry(a,200,'Wanderer');left.locations={Marsh=true};left.levelMax=12
            local right=entry(b,200,'Wanderer');right.locations={Hills=true};right.levelMin=7
            for i=1,3 do entry(a,i,'Earlier creature '..i) end
            a.db.bestiary.points.earned=8;b.db.bestiary.points.earned=4
            compare();selectBoth();assert(b.c:Approve())
            waitFor(function() return a.c.session.stage=='done' and b.c.session.stage=='done' end)
            for _,p in ipairs({a,b}) do
                local info=p.j:GetBasicInfo(200)
                eq(info.levelMin,7);eq(info.levelMax,12);assert(info.locations.Marsh and info.locations.Hills)
            end
            local delivered=right.sharedReports[1]
            eq(#delivered.locations,1);eq(delivered.locations[1],'Marsh')
            balance(a,4,4);balance(b,3,1)
        """)

    def test_crossed_invites_and_proposals_need_both_approvals(self):
        lua = clients()
        lua.execute("""
            fixture();assert(a.c:Invite(b.name));assert(b.c:Invite(a.name))
            waitFor(function() return a.c.session.stage=='ready' and b.c.session.stage=='ready' end)
            eq(a.c.session.id,b.c.session.id);assert(a.c.session.host and not b.c.session.host)
            a.c:Select('give',102,true);b.c:Select('give',103,true)
            assert(a.c:Approve());assert(b.c:Approve());pump(8)
            eq(a.c.session.stage,'proposed');eq(b.c.session.stage,'review')
            eq(b.c.session.incoming.cost,1);eq(b.c.session.outgoing.entries,0)
            balance(a,20,0);balance(b,20,0)
            assert(b.c:Approve());pump(18);eq(a.c.session.stage,'done')
            balance(a,19,1);balance(b,20,0);assert(not a.j.entries[103])
        """)

    def test_ordinary_offers_and_commit_price_are_bound_to_approved_selection(self):
        lua = clients()
        lua.execute("""
            fixture();compare();a.c:Select('give',102,true);assert(a.c:Approve());pump(3);assert(b.c:Approve())
            local offer=ns.SharingReport.Capture(a.j,101)
            offer.created,offer.recipient,offer.transaction=now,b.name,'99-99-99'
            local payload=assert(ns.SharingReport.Encode(offer))
            b.e:Receive('AFBShare','4~H~99-99-99~'..buildVersion,'WHISPER',a.name)
            assert(#payload<=180)
            b.e:Receive('AFBShare','4~O~99-99-99~1~1~'..payload,'WHISPER',a.name)
            eq(b.e:GetIncoming()[1].state,'pending')
            assert(not b.j.entries[101]);assert(b.e:Decline(b.e:GetIncoming()[1]))
            waitFor(function() local tx=a.e:GetOutgoing();return tx and tx.stage=='offering' end)
            local tx=a.e:GetOutgoing()
            a.e:Receive('AFBShare','4~A~'..tx.id..'~1','WHISPER',b.name)
            eq(tx.stage,'failed');balance(a,20,0)
            pump(8);eq(a.c.session.stage,'closed');eq(#b.j:GetRumours(102),0)
        """)

    def test_empty_large_partial_and_malformed_catalogues(self):
        lua = clients()
        lua.execute("""
            compare();eq(#a.c.session.rows,0);assert(not a.c:Approve())
            a.c:Close();pump(2);packets={}
            for i=1,140 do entry(a,i,'Creature '..i) end
            for i=1,9 do a.j.entries[2].locations['Extra '..i]=true end
            assert(a.c:Invite(b.name));pump(2);b.c:AcceptInvitation()
            waitFor(function() return a.c.session.stage=='ready' and b.c.session.stage=='ready' end,250)
            eq(#b.c.session.rows,140);assert(b.c.session.byID[2].take.unavailable)
            b.c:Select('take',nil,true);eq(b.c.session.incoming.entries,139)
            local text=D.EncodeCatalog(D.Catalog(a.j))
            assert(not D.DecodeCatalog(text..'1:x'));assert(not D.DecodeCatalog(text:sub(1,-2)))
            assert(not D.DecodeQuotes('10.999999',D.Catalog(a.j)))
            a.c:Close();pump(3);assert(a.c:Invite(b.name));pump(2);b.c:AcceptInvitation()
            b.e:Receive('AFBShare','4~B~'..b.c.session.id..'~S2/1:x','WHISPER',a.name)
            eq(b.c.session.stage,'closed')
        """)

    def test_book_portrait_bulk_controls_and_geometry(self):
        lua = clients()
        lua.execute("""
            fixture()
            menus={};Menu={ModifyMenu=function(tag,fn) menus[tag]=fn end}
            local target=b.name
            function UnitIsPlayer(unit) return target~=nil end
            function UnitNameUnmodified(unit) return target end
            function UnitCanCooperate() return true end
            shell=ns.CreateFieldbookShell();book=ns.CreateBestiaryBook(a.j,shell)
            shell:ShowSection('bestiary');local root=shell:GetFrame();local w,h=root:GetWidth(),root:GetHeight()
            local main=AzerothFieldbookBestiarySection
            eq(main.shareButton:GetWidth(),120);eq(main.shareButton.point[3],-672)
            main.compareButton.scripts.OnClick();local f=AzerothFieldbookCompare
            assert(f:IsShown());eq(f.nameBox:GetText(),b.name);eq(f:GetWidth(),458)
            f:Hide()
            local action
            local menu={CreateButton=function(_,name,fn) eq(name,'Compare Bestiaries');action=fn end}
            local function popup(unit)
                action=nil;menus.MENU_UNIT_PLAYER(nil,menu,{unit=unit});return action
            end
            assert(not popup('focus'));target=a.name;assert(not popup('target'))
            target=b.name;a.blocked=true;assert(not popup('target'))
            a.blocked=false;local stale=assert(popup('target'));target='Another Friend';stale()
            assert(not a.c.session);target=b.name;assert(popup('target'))()
            pump(2);eq(b.c.session.stage,'invited');b.c:AcceptInvitation()
            waitFor(function() return a.c.session.stage=='ready' and b.c.session.stage=='ready' end)
            eq(f:GetWidth(),784);eq(root:GetWidth(),w);eq(root:GetHeight(),h)
            assert(f.rows[1].take.owner:GetText()=='No entry')
            f.rows[1].inspect.scripts.OnClick();assert(f.detail:IsShown())
            assert(f.left:GetText():find('Patrols',1,true));assert(f.left:GetText():find('1.5',1,true))
            f.back.scripts.OnClick();f.search:SetText('Marsh');f.give.scripts.OnClick()
            eq(a.c.session.outgoing.entries,1);eq(a.c.session.outgoing.required,3)
            f.search:SetText('');f.take.scripts.OnClick();eq(a.c.session.incoming.entries,2)
            assert(f.youPay:GetText():find('1 knowledge',1,true))
            f.action.scripts.OnClick();pump(3);assert(b.c:Approve());pump(55)
            eq(a.c.session.stage,'done');assert(f.status:GetText():find('Exchange complete',1,true))
            eq(root:GetWidth(),w);eq(root:GetHeight(),h);balance(a,19,1);balance(b,14,6)
        """)

    def test_remote_proposal_review_at_large_scale_on_small_screen(self):
        lua = clients()
        lua.execute("""
            UIParent:SetSize(1024,640)
            AzerothFieldbookAccountDB={textSizeOffset=3,uiScale=1.5}
            for _,font in ipairs({'GameFontNormal','GameFontNormalLarge','GameFontHighlight','GameFontHighlightSmall'}) do CreateFont(font) end
            ns.TextSize:Initialize();ns.UIScale:Initialize(a.db)
            eq(_G[ns.TextSize:Font('GameFontHighlightSmall')].size,15)
            b=client(string.rep('B',88)..' Stonewell')
            fixture()
            for i=1,20 do a.j.entries[101].abilities['Long comparison trait '..i..string.rep('x',23)]={state='confirmed'} end
            a.db.bestiary.points.earned=100
            shell=ns.CreateFieldbookShell();book=ns.CreateBestiaryBook(a.j,shell);shell:ShowSection('bestiary')
            local main=AzerothFieldbookBestiarySection
            main.compareButton.scripts.OnClick();compare();local f=AzerothFieldbookCompare
            f.search:SetText('Grey');assert(f.rows[1].record.id==104)
            b.c:Select('take',101,true);assert(b.c:Approve());pump(4)
            eq(a.c.session.stage,'review');eq(f.search:GetText(),'');eq(f.rows[1].record.id,101)
            assert(not f.rows[2]:IsShown());eq(f.action:GetText(),'Accept exchange')
            f.rows[1].inspect.scripts.OnClick()
            assert(f.detail:IsShown() and f.detailBody:GetHeight()>f.detailArea:GetHeight())
            assert(f:GetWidth()*f:GetEffectiveScale()<=UIParent:GetWidth()-29)
            assert(f:GetHeight()*f:GetEffectiveScale()<=UIParent:GetHeight()-29)
            assert(-f.status.point[3]+f.status:GetStringHeight() < -f.action.point[3])
            assert(-f.action.point[3]+f.action:GetHeight()<f:GetHeight())
            f.dismiss.scripts.OnClick();pump(4)
            eq(b.c.session.stage,'closed');balance(a,100,0);balance(b,20,0)
        """)

    def test_reset_and_timeout_discard_unpaid_work(self):
        lua = clients()
        lua.execute("""
            fixture();assert(a.c:Invite(b.name));pump(94)
            eq(a.c.session.stage,'closed');eq(b.c.session.stage,'closed')
            balance(a,20,0);balance(b,20,0)
            packets={};compare();a.c:Select('give',102,true);assert(a.c:Approve());pump(4)
            b.j:Reset();pump(4);eq(a.c.session.stage,'closed');assert(not b.c.session)
            balance(a,20,0)
        """)

    def test_reverse_offer_can_finish_while_large_lore_is_sending(self):
        lua = clients()
        lua.execute("""
            entry(a,1,'Field Rat')
            local owl=entry(b,2,'Owl');owl.levelMax=9;owl.locations={}
            owl.beastLore={level=9,observed=now,rows={}};owl.beastLoreSource='gameTooltip'
            for i=1,32 do owl.beastLore.rows[i]={left='Field '..i,right=string.rep('a',195)} end
            a.db.bestiary.points.earned=1;b.db.bestiary.points.earned=0
            compare();selectBoth();assert(b.c:Approve())
            -- Stagger the two queues so the small report's preflight arrives
            -- after the other sender has queued over 30 Lore chunks.
            local tick=a.c.Tick;a.c.Tick=function() end
            pump(8);eq(b.e:GetOutgoing().stage,'offering');assert(#b.e:GetOutgoing().payload>6000)
            a.c.Tick=tick
            waitFor(function() return a.c.session.sent==1 end,16)
            assert(not a.j.entries[2])
            waitFor(function() return a.c.session.stage=='done' and b.c.session.stage=='done' end)
            eq(#a.j.entries[2].beastLore.rows,32);balance(a,0,1);balance(b,0,0)
        """)


if __name__ == '__main__':
    unittest.main()
