local _,ns=...
local data,report=ns.BestiaryComparison,ns.SharingReport
local codec=ns.ComparisonCodec
local CHUNK=180
local messages={
    closed="The comparison was closed.",declined="The invitation or exchange was declined.",
    busy="The other player already has a comparison or report in progress.",
    blocked="Comparison is unavailable while incoming sharing is blocked, the Bestiary is hidden, or messaging is restricted.",
    version="Both players need the same addon version with Bestiary comparison.",
    invalid="The comparison data could not be validated. Start a new comparison.",
    changed="The selected data or its price changed. Compare again to review a fresh selection.",
    funds="The sender has insufficient available knowledge for the selected reports.",
    timeout="The comparison timed out while waiting for the other player.",
    transport="The comparison whisper could not be delivered.",
    report="The exchange stopped before all reports were delivered.",
    limit="The catalogue exceeds the comparison message limit.",
}

function ns.CreateComparisonSession(journal,engine,env,send,purge,newID,incomingBlocked)
    local comparison={}
    local clock=env.clock or env.now
    -- 1 is the original comparison transport. 2 adds byte pacing, 2z also
    -- accepts compressed streams. Both players still need the same addon build.
    local localMode=codec.Available(env.encoding) and "2z" or "2"
    local function helloMode(body)
        local mode,version=body:match("^([^~]+)~(.+)$")
        if version==env.addonVersion and (mode=="1" or mode=="2" or mode=="2z") then return mode end
    end
    local callback
    local inviteWindow,inviteCount=0,0
    local function notify(open) if callback then callback(open) end end
    function comparison:SetChangedCallback(fn) callback=fn end
    function comparison:Active()
        local session=self.session
        return session and session.stage~="closed" and session.stage~="done"
    end
    function comparison:FastSession(peer)
        local s=self.session
        if s and (s.mode=="2" or s.mode=="2z") and s.stage~="done" and s.stage~="closed"
            and (not peer or report.SameCharacter(s.peer,peer)) then return s end
    end
    function comparison:ReportEncoding(id,peer)
        local s=self.session
        if s and s.stage=="exchanging" and s.id==id and s.mode=="2z"
            and report.SameCharacter(s.peer,peer) then return env.encoding end
    end
    function comparison:Available()
        local ready,why=engine:Available()
        if not ready then return false,why end
        if ns.InitializationBlocked or incomingBlocked() then return false,messages.blocked end
        local blocked,reason=engine:Blocked()
        if blocked then return false,reason or messages.blocked end
        return true
    end
    local function control(session,body) return send("B",session.id,session.peer,body) end
    local function newSession(id,peer,stage,host,offer)
        local session={id=id,peer=peer,stage=stage,host=host,offer=offer,deadline=clock()+90,streams={},assembly={},
            give={},take={},sent=0,received=0,spent=0,peerSpent=0,addonVersion=env.addonVersion}
        comparison.session=session
        return session
    end
    local function stop(session,reason,tell,detail)
        if session~=comparison.session or not comparison:Active() then return end
        session.stage,session.message="closed",detail or messages[reason] or messages.closed
        session.streams,session.assembly={},{}
        purge(session.id,session.peer)
        engine:ClearComparisonOffers(session.id,session.peer)
        if session.tx and engine:GetOutgoing()==session.tx then
            if not session.tx.spent then engine:Cancel()
            else
                session.spent=session.spent+session.tx.cost
                if session.tx.stage=="complete" then session.sent=session.sent+1 end
            end
            if session.tx.spent and session.tx.stage~="complete" then
                session.message=session.message.." Open Share for the paid report's receipt or retry."
            end
        end
        if tell then control(session,"X"..reason) end
        notify()
    end
    function comparison:Close(reason)
        if self:Active() then stop(self.session,reason or "closed",true) end
    end
    function comparison:Invite(peer)
        local ready,reason=self:Available()
        if not ready then return nil,reason end
        peer,reason=engine:ValidateRecipient(peer)
        if not peer then return nil,reason end
        if self:Active() or engine:HasActiveOutgoing() then return nil,"Finish the current comparison or outgoing report first." end
        -- An original client uses suffix 3. Keep simultaneous invitations
        -- distinct even if both players happen to generate the same nonce.
        local session=newSession(newID("4"),peer,"inviting",true,localMode)
        if not control(session,"I"..session.offer.."~"..env.addonVersion) then stop(session,"transport");return nil,session.message end
        notify(true)
        return true
    end
    local function stream(session,kind,text)
        if not text or #text>data.MAX_BYTES then stop(session,"limit",true);return end
        if session.mode=="2z" then text=codec.Pack(env.encoding,text,CHUNK) end
        session.streams[#session.streams+1]={kind=kind,text=text,next=1,total=math.ceil(#text/CHUNK)}
        return true
    end
    local function startCatalog(session)
        session.stage,session.deadline="syncing",clock()+90
        session.mine=data.Catalog(journal)
        stream(session,"S",data.EncodeCatalog(session.mine))
        notify()
    end
    function comparison:AcceptInvitation()
        local session=self.session
        if not session or session.stage~="invited" then return end
        if clock()>=session.deadline then stop(session,"timeout",true);return end
        if not self:Available() then stop(session,"blocked",true);return end
        session.mode=session.offer=="2z" and localMode or session.offer
        if not control(session,"Y"..session.mode.."~"..env.addonVersion) then stop(session,"transport");return end
        startCatalog(session)
    end
    local function plans(session)
        session.outgoing=data.Plan(session.mine,session.giveQuotes,session.give)
        session.incoming=data.Plan(session.theirs,session.takeQuotes,session.take)
    end
    local function ready(session)
        if session.stage=="syncing" and session.giveQuotes and session.takeQuotes then
            session.rows,session.byID=data.Rows(session.mine,session.theirs,session.giveQuotes,session.takeQuotes)
            plans(session)
            session.stage,session.deadline="ready",clock()+900
        end
        notify()
    end
    function comparison:Select(direction,id,enabled,visibleRows)
        local session=self.session
        if not session or session.stage~="ready" or (direction~="give" and direction~="take") then return end
        for _,row in ipairs(visibleRows or (id and {session.byID[id]}) or session.rows) do
            if (not id or id==row.id) and data.CanSelect(row[direction]) then
                session[direction][row.id]=enabled or nil
            end
        end
        plans(session);notify()
    end
    local function selection(catalog,chosen)
        local bits={}
        for i,e in ipairs(catalog) do bits[i]=chosen[e.id] and "1" or "0" end
        return table.concat(bits)
    end
    local function readSelection(bits,catalog,quotes)
        if #bits~=#catalog then return end
        local chosen={}
        for i,e in ipairs(catalog) do
            if bits:sub(i,i)=="1" then
                if not data.CanSelect(quotes[i]) then return end
                chosen[e.id]=true
            end
        end
        return chosen
    end
    function comparison:CanApprove()
        local session=self.session
        if not session or (session.stage~="ready" and session.stage~="review") then return false end
        if clock()>=session.deadline then return false,messages.timeout end
        if session.outgoing.entries+session.incoming.entries==0 then return false,"Select entries to exchange." end
        if engine:HasActiveOutgoing() then return false,"Finish your active report in Share first." end
        if journal:GetSharingBalance()<session.outgoing.required then
            return false,"You need "..session.outgoing.required.." available knowledge to reserve these reports."
        end
        return self:Available()
    end
    local function currentSelection(session)
        for _,job in ipairs(session.outgoing.jobs) do
            if not data.CaptureJob(journal,job) then stop(session,"changed",true);return false end
        end
        return true
    end
    local function exchange(session)
        session.stage,session.deadline="exchanging",clock()+240
        notify()
    end
    function comparison:Approve()
        local ok,why=self:CanApprove()
        if not ok then return nil,why end
        local session=self.session
        if not currentSelection(session) then return nil,session.message end
        if session.stage=="ready" then
            session.stage,session.deadline="proposed",clock()+180
            stream(session,"P",selection(session.mine,session.give).."/"..selection(session.theirs,session.take))
            notify()
        elseif control(session,"A") then exchange(session)
        else stop(session,"transport") end
        return true
    end
    local function assembled(session,kind,text)
        text=codec.Unpack(session.mode=="2z" and env.encoding,text,data.MAX_BYTES)
        if not text then stop(session,"invalid",true);return end
        if kind=="S" then
            session.theirs=data.DecodeCatalog(text)
            if not session.theirs then stop(session,"invalid",true);return end
            session.takeQuotes=data.Quotes(journal,session.theirs,session.peer,env.character)
            if stream(session,"Q",data.EncodeQuotes(session.takeQuotes)) then ready(session) end
        elseif kind=="Q" then
            session.giveQuotes=data.DecodeQuotes(text,session.mine)
            if not session.giveQuotes then stop(session,"invalid",true);return end
            ready(session)
        else
            -- A simultaneous proposal from the inviter wins. The other player
            -- still has to explicitly approve that particular selection.
            if session.stage=="proposed" and session.host then return end
            local theirs,mine=text:match("^([01]*)/([01]*)$")
            local give=mine and readSelection(mine,session.mine,session.giveQuotes)
            local take=theirs and readSelection(theirs,session.theirs,session.takeQuotes)
            if not give or not take or (not next(give) and not next(take)) then stop(session,"invalid",true);return end
            session.give,session.take=give,take
            plans(session)
            session.stage,session.deadline="review",clock()+180
            notify(true)
        end
    end
    local function chunk(session,kind,body)
        if kind=="P" then
            if session.stage~="ready" and session.stage~="proposed" then return end
        elseif session.stage~="syncing" or (kind=="S" and session.theirs) or (kind=="Q" and session.giveQuotes) then return end
        local i,n,part=body:match("^(%d+)/(%d+):(.*)$")
        i,n=tonumber(i),tonumber(n)
        if not report.Integer(n,1,math.ceil(data.MAX_BYTES/CHUNK)) or not report.Integer(i,1,n)
            or #part==0 or #part>CHUNK or (i<n and #part~=CHUNK) or (i-1)*CHUNK+#part>data.MAX_BYTES then
            stop(session,"invalid",true);return
        end
        local a=session.assembly[kind]
        if not a then a={n=n,count=0,parts={}};session.assembly[kind]=a end
        if n~=a.n or (a.parts[i] and a.parts[i]~=part) then stop(session,"invalid",true);return end
        if a.parts[i] then return end
        a.parts[i],a.count=part,a.count+1
        session.deadline=clock()+180
        if kind=="S" then session.syncPercent=math.floor(100*a.count/n) end
        if a.count==n then
            session.assembly[kind]=nil
            assembled(session,kind,table.concat(a.parts))
        end
    end
    function comparison:Receive(id,peer,body)
        local kind,rest=body:sub(1,1),body:sub(2)
        local session=self.session
        if kind=="I" then
            local now=clock()
            if now-inviteWindow>=60 then inviteWindow,inviteCount=now,0 end
            if inviteCount>=8 then return end
            inviteCount=inviteCount+1
            local reason
            local mode=helloMode(rest)
            if not mode then reason="version"
            elseif not self:Available() then reason="blocked"
            elseif self:Active() and report.SameCharacter(session.peer,peer) and session.stage=="inviting" then
                -- Crossed invitations already give mutual catalogue consent.
                -- Both clients use the first character's invitation.
                if env.character:lower()>peer:lower() then
                    purge(session.id,session.peer)
                    newSession(id,peer,"invited",false,mode)
                    self:AcceptInvitation()
                end
                return
            elseif self:Active() and id==session.id and report.SameCharacter(session.peer,peer) then return
            elseif self:Active() or engine:HasActiveOutgoing() then reason="busy" end
            if reason then send("B",id,peer,"X"..reason);return end
            newSession(id,peer,"invited",false,mode);notify(true)
            return
        end
        if not self:Active() or id~=session.id or not report.SameCharacter(session.peer,peer) then return end
        if clock()>=session.deadline then stop(session,"timeout",true);return end
        if not self:Available() then stop(session,"blocked",true);return end
        if kind=="X" and messages[rest] then
            -- Older same-build installations reject the capability offer as a
            -- version mismatch. Retry their exact handshake once, with a fresh id.
            if rest=="version" and session.stage=="inviting" and session.offer~="1" then
                purge(session.id,session.peer)
                session.id,session.offer,session.deadline=newID("4"),"1",clock()+90
                if not control(session,"I1~"..env.addonVersion) then stop(session,"transport") end
            else stop(session,rest) end
            return
        end
        if kind=="Y" and session.stage=="inviting" then
            local mode=helloMode(rest)
            if not mode or (mode~="1" and session.offer=="1") or (mode=="2z" and session.offer~="2z") then
                stop(session,"version",true);return
            end
            session.mode=mode
            startCatalog(session)
        elseif kind=="S" or kind=="Q" or kind=="P" then chunk(session,kind,rest)
        elseif kind=="A" and rest=="" and session.stage=="proposed" then
            if journal:GetSharingBalance()<session.outgoing.required then stop(session,"funds",true)
            elseif engine:HasActiveOutgoing() then stop(session,"busy",true)
            elseif currentSelection(session) then exchange(session) end
        end
    end

    -- A tagged preflight must belong to the next agreed incoming report.
    -- An ordinary offer, even from the same player, keeps its own consent UI.
    function comparison:BindOffer(sessionID,peer,txID)
        local session=self.session
        if not session or session.stage~="exchanging" or session.id~=sessionID or not report.SameCharacter(session.peer,peer)
            or not session.incoming.jobs[session.received+1] or (session.inID and session.inID~=txID) then return false end
        session.inID,session.deadline=txID,clock()+240
        return true
    end
    function comparison:AcceptReport(item)
        local session=self.session
        if not self:BindOffer(item.comparison,item.sender,item.id) then return false end
        local job=session.incoming.jobs[session.received+1]
        if data.Matches(job,item.report) then
            local q=data.Quotes(journal,{job.entry},session.peer,env.character)[1]
            if (job.lore and q.lore) or (not job.lore and q.regular and q.cost<=job.quote.cost
                and table.concat(q.indices,".")==table.concat(job.quote.indices,".")) then
                if engine:Accept(item) then return true end
            end
        end
        stop(session,"changed",true)
        return false
    end
    function comparison:Imported(item)
        local session=self.session
        if not session or session.stage~="exchanging" or session.inID~=item.id or session.id~=item.comparison
            or not report.SameCharacter(session.peer,item.sender) then return end
        local job=session.incoming.jobs[session.received+1]
        session.peerSpent=session.peerSpent+(job.lore and 0 or report.Cost(job.quote.indices,job.entry.multiplier,item.basicCost))
        session.received,session.inID,session.deadline=session.received+1,nil,clock()+240
        notify()
    end
    function comparison:SendFailed(id,peer)
        local session=self.session
        if self:Active() and session.id==id and report.SameCharacter(session.peer,peer) then stop(session,"transport",true) end
    end
    function comparison:Pump()
        local session=self.session
        local part=self:Active() and session.streams[1]
        if not part then return end
        local i=part.next
        if not control(session,part.kind..i.."/"..part.total..":"..part.text:sub((i-1)*CHUNK+1,i*CHUNK)) then
            stop(session,"transport");return
        end
        if i==part.total then table.remove(session.streams,1) else part.next=i+1 end
        if part.kind=="S" then session.sentPercent=math.floor(100*i/part.total) end
        session.deadline=math.max(session.deadline,clock()+90)
    end
    function comparison:Tick()
        if not self:Active() then return end
        local session=self.session
        if not self:Available() then stop(session,"blocked",true);return end
        if session.addonVersion~=env.addonVersion then stop(session,"version",true);return end
        if clock()>=session.deadline then stop(session,"timeout",true);return end
        if session.stage~="exchanging" then return end
        if session.tx then
            if session.tx.stage=="complete" then
                session.sent,session.spent=session.sent+1,session.spent+session.tx.cost
                session.tx=nil;session.deadline=clock()+240
                notify()
            elseif session.tx.stage~="preflight" and session.tx.stage~="offering" and session.tx.stage~="committed" then
                stop(session,"report",true);return
            else return end
        end
        local job=session.outgoing.jobs[session.sent+1]
        if job then
            local value,claims=data.CaptureJob(journal,job)
            if not value then stop(session,"changed",true);return end
            if journal:GetSharingBalance()<(job.lore and 0 or job.quote.reserve) then stop(session,"funds",true);return end
            local tx,reason=engine:Start(value,session.peer,claims,{id=session.id,host=session.host,limit=job.lore and 0 or job.quote.cost})
            if not tx then stop(session,"report",true,reason);return end
            session.tx,session.deadline=tx,clock()+240
            notify()
        elseif session.received==#session.incoming.jobs then
            session.stage="done";notify()
        end
    end
    function comparison:Reset()
        self:Close();self.session=nil;notify()
    end
    return comparison
end
