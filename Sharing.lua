local addonName, ns = ...
local schema = ns.SharingReport
local PREFIX, DAY, OFFER_SECONDS = "AFBShare", 86400, 180
local PREFLIGHT_SECONDS = 20
-- Protocol 4 adds the recipient's basic-information cost to acceptance replies.
-- The literal report format stays at schema 1 so paid retries retain their data.
local PROTOCOL = "4"
local MAX_INCOMING, MAX_RECEIPTS, CHUNK = 3, 512, 180
local function size(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function key(sender,id) return sender:lower() .. "/" .. id end
local function committed(tx) return tx and tx.spent==true end
local function active(tx) return tx and (tx.stage=="preflight" or tx.stage=="offering" or tx.stage=="committed" or tx.stage=="unknown") end
local function validVersion(value)
    return schema.Text(value,32) and value:match("^%d+%.%d+%.%d+[%w%.%-%+]*$")~=nil
end

-- Environment injection keeps protocol/accounting tests independent of WoW.
function ns.CreateSharing(journal, env)
    local engine={ PREFIX=PREFIX }
    journal.sharing=engine
    local store=journal:GetSharingStorage()
    local queue, changed, imported, costAdjusted = {}, nil, nil, nil
    local clock=env.clock or env.now
    local preflightDeadline
    local nextSend, nextHello, helloWindow, helloCount = 0, {}, 0, 0
    local receiveWindow, receiveCount = 0, 0
    local function notify(reason) if changed then changed(reason) end end
    local function purge(id,target)
        for i=#queue,1,-1 do
            if queue[i].id==id and schema.SameCharacter(queue[i].target,target) then table.remove(queue,i) end
        end
    end
    local function send(kind,id,target,body,version)
        local text=(version or PROTOCOL) .. "~" .. kind .. "~" .. id .. (body and ("~" .. body) or "")
        if #queue>=64 or #text>240 then return false end
        queue[#queue+1]={text=text,id=id,target=target,attempts=0}
        return true
    end
    local function finish(tx,stage,message)
        purge(tx.id,tx.recipient)
        if not tx.spent then journal:ReleaseShare(tx.id) end
        preflightDeadline=nil
        tx.stage,tx.message=stage,message
        notify()
    end
    local function expirePreflight()
        local tx=store.outgoing
        if tx and tx.stage=="preflight" and preflightDeadline and clock()>=preflightDeadline then
            finish(tx,"failed","No response from " .. tx.recipient .. " after " .. PREFLIGHT_SECONDS ..
                " seconds. Azeroth Fieldbook may be missing or disabled, or the player may be offline, restricted or lagging. No knowledge spent. Check their name and try again.")
        end
    end
    local function unknown(tx,message)
        purge(tx.id,tx.recipient)
        tx.stage,tx.message="unknown",message .. " Knowledge remains spent; retry this transaction."
        notify()
    end
    local function incompatible(tx,version)
        local message=validVersion(version)
            and ("Version mismatch: you have " .. env.addonVersion .. "; " .. tx.recipient .. " has " .. version .. ". Both players need the same addon version.")
            or "Receiver cannot confirm a compatible addon version. Both players need the same updated build."
        if tx.spent then unknown(tx,message) else finish(tx,"failed",message .. " No knowledge spent.") end
        send("X",tx.id,tx.recipient)
    end
    local function prune()
        local now=env.now()
        for k,receipt in pairs(store.receipts) do
            if now-receipt.received>2*DAY then store.receipts[k]=nil end
        end
        for k,item in pairs(store.incoming) do
            if now>item.expires then
                store.incoming[k]=nil
                purge(item.id,item.sender)
                notify()
            end
        end
    end
    local function fresh(value)
        return value.created<=env.now()+300 and env.now()-value.created<=DAY
    end
    local function offer(tx)
        purge(tx.id,tx.recipient)
        if not tx.spent then tx.stage="offering"; preflightDeadline=nil end
        tx.deadline=env.now()+OFFER_SECONDS
        tx.message="Waiting for " .. tx.recipient .. " to accept or decline."
        local count=math.ceil(#tx.payload/CHUNK)
        for i=1,count do
            if not send("O",tx.id,tx.recipient,i .. "~" .. count .. "~" .. tx.payload:sub((i-1)*CHUNK+1,i*CHUNK)) then
                if tx.spent then unknown(tx,"Send queue full.") else finish(tx,"failed","Send queue full; no knowledge spent.") end
                return
            end
        end
        notify()
    end
    local function commit(tx,basicCost)
        local adjusted=false
        if not tx.spent then
            local ok,cost=journal:CommitShare(tx.id,basicCost==0)
            if not ok then finish(tx,"failed","Reservation missing; nothing sent for import."); return end
            tx.cost,tx.basicCost=cost,basicCost
            tx.basicInfoWaived=basicCost==0
            adjusted=tx.basicInfoWaived
            tx.spent=true
        end
        purge(tx.id,tx.recipient)
        tx.stage,tx.deadline="committed",env.now()+60
        tx.message="Accepted. " .. tx.cost .. " knowledge spent; awaiting import acknowledgement."
        send("C",tx.id,tx.recipient)
        notify()
        if adjusted and costAdjusted then costAdjusted(tx) end
    end
    -- An uncommitted offer cannot import. Reload safely cancels its reservation.
    -- A committed decision remains paid and uncertain until receipt is reconciled.
    if active(store.outgoing) then
        if committed(store.outgoing) then
            store.outgoing.stage="unknown"
            store.outgoing.message="Reload interrupted delivery. Knowledge remains spent; retry this transaction."
        else
            journal:ReleaseShare(store.outgoing.id)
            store.outgoing.stage="cancelled"
            store.outgoing.message="Reload cancelled the uncommitted offer; no knowledge spent."
        end
    end
    for k,item in pairs(store.incoming) do
        if item.state~="accepted" then store.incoming[k]=nil end
    end
    prune()
    function engine:SetChangedCallback(callback) changed=callback end
    function engine:SetImportedCallback(callback) imported=callback end
    function engine:SetCostAdjustedCallback(callback) costAdjusted=callback end
    function engine:GetOutgoing() return store.outgoing end
    function engine:GetPreflightSecondsRemaining()
        if store.outgoing and store.outgoing.stage=="preflight" and preflightDeadline then
            return math.max(0,math.ceil(preflightDeadline-clock()))
        end
    end
    function engine:HasActiveOutgoing() return active(store.outgoing)==true end
    function engine:Available()
        if env.ready~=true then return false,env.error end
        if not validVersion(env.addonVersion) then return false,"The installed addon version is unavailable; sharing cannot check compatibility." end
        return true
    end
    function engine:Blocked() return env.blocked() end
    function engine:ValidateRecipient(recipient)
        recipient=schema.Character(recipient)
        if not recipient then return nil,"Enter another character's full name, including their surname if they have one." end
        if schema.SameCharacter(recipient,env.character) then return nil,"You cannot send an offer to yourself." end
        return recipient
    end
    function engine:GetIncoming()
        local list={}
        for _,item in pairs(store.incoming) do
            if item.state=="pending" or item.state=="accepted" then list[#list+1]=item end
        end
        table.sort(list,function(a,b) return a.id<b.id end)
        return list
    end
    function engine:Start(captured, recipient, claims)
        local ready,err=self:Available()
        if not ready then return nil,err or "Addon messaging is unavailable." end
        local blocked,reason=env.blocked()
        if blocked then return nil,reason or "Share outside combat and messaging restrictions." end
        if active(store.outgoing) then return nil,"An outgoing report is already active. Use its status, Cancel or Retry." end
        recipient,err=self:ValidateRecipient(recipient)
        if not recipient then return nil,err end
        if type(captured)~="table" then return nil,"Select a creature first." end
        local value={}
        for k,v in pairs(captured) do value[k]=v end
        store.sequence=store.sequence+1
        local id=env.now() .. "-" .. store.sequence .. "-" .. (env.nonce and env.nonce() or math.random(100000,999999))
        value.transaction,value.created,value.recipient=id,env.now(),recipient
        value.rumours=claims or {}
        local payload,err=schema.Encode(value)
        if not payload then return nil,err end
        local cost=schema.Cost(value.rumours)
        if not journal:ReserveShare(id,cost) then return nil,"Insufficient available knowledge." end
        local tx={id=id,recipient=recipient,payload=payload,cost=cost,basicCost=1,created=env.now(),
            stage="preflight",deadline=env.now()+PREFLIGHT_SECONDS,retries=0,
            message="Checking recipient compatibility (up to " .. PREFLIGHT_SECONDS .. " seconds); knowledge reserved."}
        store.outgoing=tx
        preflightDeadline=clock()+PREFLIGHT_SECONDS
        if not send("H",id,recipient,env.addonVersion) then finish(tx,"failed","Send queue full; no knowledge spent."); return nil,tx.message end
        notify()
        return tx
    end
    function engine:Cancel()
        local tx=store.outgoing
        if not active(tx) or tx.spent then return false end
        finish(tx,"cancelled","Cancelled; no knowledge spent.")
        send("X",tx.id,tx.recipient)
        return true
    end
    function engine:CanRetry()
        local tx=store.outgoing
        return tx and tx.stage=="unknown" and tx.spent and tx.retries<3 and env.now()-tx.created<=DAY
    end
    function engine:Retry()
        local ready,err=self:Available()
        if not ready then return nil,err or "Addon messaging is unavailable." end
        if env.blocked() then return nil,"Retry outside combat and messaging restrictions." end
        if not self:CanRetry() then return nil,"Retry limit reached (three attempts within 24 hours). Delivery remains unknown." end
        local tx=store.outgoing
        tx.retries=tx.retries+1
        tx.stage,tx.deadline="committed",env.now()+60
        tx.message="Reconciling the same paid report (attempt " .. tx.retries .. "/3)."
        purge(tx.id,tx.recipient)
        -- Re-check installed versions before reconciling a saved receipt or
        -- consent; either player may have updated since the original offer.
        send("H",tx.id,tx.recipient,env.addonVersion)
        notify()
        return true
    end
    function engine:CloseUnknown()
        local tx=store.outgoing
        if not tx or tx.stage~="unknown" or self:CanRetry() then return false end
        finish(tx,"unresolved","Delivery unresolved; knowledge remains spent. No further retries for this report.")
        return true
    end
    function engine:Accept(item)
        local ready,err=self:Available()
        if not ready then return nil,err or "Addon messaging is unavailable." end
        if journal:GetBlockIncomingOffers() then return nil,"Incoming offers are blocked in Options." end
        if env.blocked() then return nil,"Accept outside combat and messaging restrictions." end
        if not item or store.incoming[key(item.sender,item.id)]~=item or item.state~="pending" then return false end
        if item.addonVersion~=env.addonVersion then return nil,"The sender's addon version must match yours before accepting." end
        if env.now()>item.expires or not fresh(item.report) then return nil,"This offer expired." end
        prune()
        if size(store.receipts)>=MAX_RECEIPTS then return nil,"Receipt storage full; try after older receipts expire." end
        local preview,err=journal:PreviewReport(item.report,item.sender)
        if not preview then return nil,err end
        -- Freeze the quote with consent so retries/reloads cannot change it.
        item.basicCost=preview.newBasic and 1 or 0
        item.state,item.expires="accepted",item.report.created+DAY
        send("A",item.id,item.sender,tostring(item.basicCost))
        notify()
        return true
    end
    function engine:Decline(item)
        if not item or store.incoming[key(item.sender,item.id)]~=item or item.state~="pending" then return false end
        store.incoming[key(item.sender,item.id)]=nil
        purge(item.id,item.sender)
        send("D",item.id,item.sender)
        notify()
        return true
    end
    function engine:ApplyIncomingOfferSetting()
        if not journal:GetBlockIncomingOffers() then return end
        for k,item in pairs(store.incoming) do
            -- Accepted reports may already have cost the sender points. Allow
            -- their commit/receipt exchange to finish, including paid retries.
            if item.state~="accepted" then
                store.incoming[k]=nil
                purge(item.id,item.sender)
                send("D",item.id,item.sender)
            end
        end
        notify()
    end
    function engine:Receive(prefix,message,channel,sender)
        if not schema.Public(prefix) or not schema.Public(channel) or not schema.Public(sender)
            or not schema.Public(message) then return end
        if not self:Available() or prefix~=PREFIX or channel~="WHISPER" or env.blocked() or not schema.Text(message,240) then return end
        sender=schema.Character(sender)
        if not sender or schema.SameCharacter(sender,env.character) then return end
        local now=env.now()
        if now-receiveWindow>=60 then receiveWindow,receiveCount=now,0 end
        receiveCount=receiveCount+1
        if receiveCount>180 then return end
        local version,kind,id,body=message:match("^(%d+)~([A-Z])~([%d%-]+)~?(.*)$")
        if not version or #version>2 or not schema.Transaction(id) then return end
        if kind=="A" then
            if body~="0" and body~="1" then return end
        elseif kind~="O" and kind~="H" and kind~="R" and kind~="I" and body~="" then return end
        -- A reply arriving after the deadline cannot revive an expired offer,
        -- even if it arrives before the next periodic update.
        expirePreflight()
        prune()
        local k=key(sender,id)
        local item,receipt,tx=store.incoming[k],store.receipts[k],store.outgoing
        local expected=active(tx) and tx.id==id and schema.SameCharacter(sender,tx.recipient)
        if kind=="H" then
            if not item then
                if now-helloWindow>=60 then helloWindow,helloCount=now,0; nextHello={} end
                if helloCount>=8 or now<(nextHello[sender:lower()] or 0) then return end
                helloCount=helloCount+1; nextHello[sender:lower()]=now+15
            end
            if version~=PROTOCOL then send("I",id,sender,nil,version); return end
            if not validVersion(body) or body~=env.addonVersion then send("I",id,sender,env.addonVersion); return end
            if receipt then send("K",id,sender); return end
            if journal:GetBlockIncomingOffers() and not (item and item.state=="accepted") then
                if item then self:ApplyIncomingOfferSetting() else send("D",id,sender) end
                return
            end
            if item then
                item.addonVersion=body
                send(item.state=="accepted" and "A" or "R",id,sender,
                    item.state=="accepted" and tostring(item.basicCost or 1) or env.addonVersion)
                return
            end
            if size(store.incoming)>=MAX_INCOMING then send("D",id,sender); return end
            store.incoming[k]={id=id,sender=sender,addonVersion=body,state="receiving",expires=now+OFFER_SECONDS,chunks={}}
            send("R",id,sender,env.addonVersion)
            return
        end
        -- Older peers return their own protocol in the incompatibility reply.
        -- Recognize that reply only from the expected recipient/transaction.
        if kind=="I" and expected then
            incompatible(tx,body)
            return
        end
        if version~=PROTOCOL then return end
        if kind=="R" and expected and (tx.stage=="preflight" or (tx.spent and tx.stage=="committed")) then
            if not validVersion(body) or body~=env.addonVersion then incompatible(tx,body); return end
            offer(tx)
        elseif kind=="O" and item and (item.state=="receiving") then
            if journal:GetBlockIncomingOffers() then self:ApplyIncomingOfferSetting(); return end
            local index,total,data=body:match("^(%d+)~(%d+)~(.*)$")
            index,total=tonumber(index),tonumber(total)
            if not schema.Integer(total,1,12) or not schema.Integer(index,1,total)
                or #data<1 or #data>CHUNK or (index<total and #data~=CHUNK)
                or (item.total and item.total~=total) or (item.chunks[index] and item.chunks[index]~=data) then
                store.incoming[k]=nil; send("D",id,sender); return
            end
            item.total=total; item.chunks[index]=data
            if size(item.chunks)~=total then return end
            local payload=table.concat(item.chunks)
            local value=schema.Decode(payload)
            if not value or value.transaction~=id or not schema.SameCharacter(value.recipient,env.character) or not fresh(value) then
                store.incoming[k]=nil; send("D",id,sender); return
            end
            local preview=journal:PreviewReport(value,sender)
            if not preview then store.incoming[k]=nil; send("D",id,sender); return end
            item.state,item.report,item.payload,item.chunks="pending",value,payload,nil
            notify()
        elseif kind=="A" and expected and (tx.stage=="offering" or tx.stage=="committed" or tx.stage=="unknown") then
            commit(tx,tonumber(body))
        elseif kind=="D" and expected then
            if tx.spent then unknown(tx,"Receiver declined or could not stage the retry.")
            else finish(tx,"declined","Offer declined, invalid, or receiver busy; no knowledge spent.") end
        elseif kind=="X" and item then
            store.incoming[k]=nil; purge(id,sender); notify()
        elseif kind=="C" then
            if receipt then send("K",id,sender); return end
            if not item or item.state~="accepted" or item.addonVersion~=env.addonVersion or not fresh(item.report) then return end
            if size(store.receipts)>=MAX_RECEIPTS then send("E",id,sender); return end
            local ok=journal:ImportReport(item.report,sender,now)
            if not ok then send("E",id,sender); return end
            store.receipts[k]={received=now,creatureID=item.report.creatureID}
            store.incoming[k]=nil
            send("K",id,sender)
            if imported then imported(item.report.creatureID) end
            notify()
        elseif kind=="K" and expected and tx.spent then
            finish(tx,"complete","Receipt acknowledged by " .. sender .. ". Spent " .. tx.cost .. " knowledge.")
        elseif kind=="E" and expected and tx.spent then
            unknown(tx,"Recipient could not import the report (storage or validation changed).")
        end
    end
    function engine:Tick()
        expirePreflight()
        prune()
        local now,tx=env.now(),store.outgoing
        if active(tx) and tx.stage~="unknown" and tx.stage~="preflight" and now>tx.deadline then
            if tx.spent then unknown(tx,"Delivery acknowledgement timed out.")
            else finish(tx,"failed","Offer expired without acceptance; no knowledge spent.") end
        end
        if env.blocked() or now<nextSend or #queue==0 then return end
        -- One small packet per second, no catch-up bursts. This is deliberately
        -- below the library's throughput, but server throttles still take priority.
        nextSend=now+1
        local packet=queue[1]
        local ok,reason=env.send(PREFIX,packet.text,"WHISPER",packet.target)
        packet.attempts=packet.attempts+1
        if not ok and reason=="throttle" and packet.attempts<3 then nextSend=now+packet.attempts*2; return end
        table.remove(queue,1)
        if not ok and active(tx) and packet.id==tx.id and schema.SameCharacter(packet.target,tx.recipient) then
            if tx.spent then unknown(tx,"Transport failed: " .. (reason or "unavailable") .. ".")
            else finish(tx,"failed","Transport failed: " .. (reason or "unavailable") .. "; no knowledge spent.") end
        end
    end
    function engine:Reset()
        store=journal:GetSharingStorage()
        queue={}; nextHello={}; nextSend=0; preflightDeadline=nil
        notify("reset")
    end
    return engine
end

function ns.InitializeSharing(journal)
    local function read(fn,...)
        if type(fn)~="function" then return end
        local ok,value=pcall(fn,...)
        if ok and schema.Public(value) then return value end
    end
    local registration=Enum and Enum.RegisterAddonMessagePrefixResult
    local results=Enum and Enum.SendAddonMessageResult
    -- Runtime elapsed time bounds the initial check independently of wall-clock
    -- adjustments. Persisted report timestamps still use the calendar clock.
    local runtime=0
    local env={now=function() return time() end,clock=function() return runtime end}
    function env.blocked()
        if read(InCombatLockdown)~=false then return true,"Leave combat to send this report." end
        local restrictions=Enum and Enum.AddOnRestrictionType
        if C_RestrictedActions and restrictions and restrictions.Chat~=nil then
            local states=Enum.AddOnRestrictionState
            local restricted
            if states and type(C_RestrictedActions.GetAddOnRestrictionState)=="function" then
                restricted=read(C_RestrictedActions.GetAddOnRestrictionState,restrictions.Chat)~=states.Inactive
            else
                restricted=read(C_RestrictedActions.IsAddOnRestrictionActive,restrictions.Chat)~=false
            end
            if restricted then return true,"Sharing is blocked by the client's chat restrictions." end
        end
        return false
    end
    local registered=false
    local function initialize()
        -- UnitFullName's first return is the character name; its second is a
        -- server, not a surname. Preserve the full literal name from the client.
        env.character=schema.Character(read(UnitFullName,"player")) or schema.Character(read(UnitName,"player"))
        env.addonVersion=read(C_AddOns and C_AddOns.GetAddOnMetadata,addonName,"Version")
        env.ready=false
        if not env.character then
            env.error="Your character's full name is unavailable; waiting for login."
        elseif not validVersion(env.addonVersion) then
            env.error="The installed addon version is unavailable; sharing cannot check compatibility."
        elseif not registration or not results or not C_ChatInfo or type(C_ChatInfo.SendAddonMessage)~="function"
            or type(C_ChatInfo.RegisterAddonMessagePrefix)~="function" then
            env.error="The required Forever addon-messaging API is unavailable."
        else
            if not registered then
                local result=read(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX)
                registered=result~=nil and (result==registration.Success or result==registration.DuplicatePrefix)
                env.error=result~=nil and result==registration.MaxPrefixes and "Too many addon-message prefixes are registered; sharing cannot register."
                    or "Sharing could not register addon messaging; reload to retry."
            end
            env.ready=registered
            if registered then env.error=nil end
        end
    end
    initialize()
    function env.send(prefix,text,channel,target)
        if env.blocked() then return false,"restricted" end
        local result=read(C_ChatInfo.SendAddonMessage,prefix,text,channel,target)
        if result~=nil and result==results.Success then return true end
        if result~=nil and (result==results.AddonMessageThrottle or result==results.ChannelThrottle) then return false,"throttle" end
        if result~=nil and result==results.TargetOffline then return false,"recipient offline" end
        if result~=nil and result==results.AddOnMessageLockdown then return false,"messaging lockdown" end
        return false,"API rejected send or returned an unreadable result"
    end
    local engine=ns.CreateSharing(journal,env)
    local frame=CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("UNIT_NAME_UPDATE")
    frame:SetScript("OnEvent",function(_,event,...)
        if event=="CHAT_MSG_ADDON" then engine:Receive(...)
        elseif event~="UNIT_NAME_UPDATE" or (...)=="player" then initialize() end
    end)
    local elapsed=0
    frame:SetScript("OnUpdate",function(_,delta)
        runtime=runtime+delta
        elapsed=elapsed+delta
        if elapsed>=0.25 then elapsed=0; engine:Tick() end
    end)
    return engine
end
