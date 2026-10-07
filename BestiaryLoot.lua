local _, ns = ...
local function read(fn,...)
    if type(fn)~="function" then return end
    local v={pcall(fn,...)}
    if not v[1] then return end
    for i=2,#v do if issecretvalue and issecretvalue(v[i]) then return end end
    return unpack(v,2)
end
-- Opt-in runtime trace; no saved data, chat spam or restricted-value inspection.
local diagnostics={enabled=false,rows={}}
ns.PickpocketDiagnostics=diagnostics
function diagnostics:Log(event,...)
    if not self.enabled then return end
    local parts={string.format("%.3f",read(GetTime) or 0),event}
    for i=1,select("#",...) do
        local v=select(i,...)
        if issecretvalue and issecretvalue(v) then v="<restricted>"
        elseif v==nil then v="<nil>"
        elseif type(v)=="string" then v=v:gsub("|",""):gsub("[%c]"," "):sub(1,120)
        elseif type(v)~="number" and type(v)~="boolean" then v="<"..type(v)..">" end
        parts[#parts+1]=tostring(v)
    end
    self.rows[#self.rows+1]=table.concat(parts," | ")
    if #self.rows>200 then table.remove(self.rows,1) end
end
function diagnostics:Report()
    return "Pickpocket cash trace v1 (runtime only)\n"..table.concat(self.rows,"\n")
end
function ns.StartBestiaryLoot(journal)
    if journal.lootObserver then return journal.lootObserver end
    local frame=CreateFrame("Frame")
    journal.lootObserver=frame
    local pending, buffered, moneyContext
    -- Runtime-only evidence: Cash Flow still owns amounts and balance changes.
    local function clock() return read(GetTime) or 0 end
    local function discardMoney()
        diagnostics:Log("context discarded",moneyContext and moneyContext.cast,moneyContext and moneyContext.confirmed)
        if moneyContext and not (moneyContext.taken and moneyContext.confirmed) then moneyContext.invalid=true end
        moneyContext=nil
    end
    local function confirmMoney()
        if pending and pending.succeeded and moneyContext and moneyContext.cast==pending.cast
            and not moneyContext.invalid and clock()-pending.at<=3 then
            moneyContext.confirmed=true
            moneyContext.windowEvidence=pending.moneyWindow==true
            if pending.windowEvidence then moneyContext.expires=nil else moneyContext.expires=pending.at+3 end
        end
    end
    local function liveState(guid)
        for _,unit in ipairs({"target","mouseover","softenemy"}) do
            if read(UnitGUID,unit)==guid then return read(UnitIsDead,unit) end
        end
    end
    ns.TakePickpocketMoneyContext=function()
        local context=moneyContext
        diagnostics:Log("cash context requested: cast/confirmed/taken/invalid/expires/alive",
            context and context.cast,context and context.confirmed,context and context.taken,
            context and context.invalid,context and context.expires,context and liveState(context.guid))
        if context and liveState(context.guid)==false and not context.taken and not context.invalid
            and (not context.expires or (read(GetTime) or 0)<=context.expires) then
            diagnostics:Log("cash context accepted",context.cast)
            context.taken=true
            return context
        end
    end
    local function snapshot(replay)
        if pending and clock()-pending.at>3 then
            pending=nil;buffered=nil;discardMoney()
            if replay then return end -- Expired cast evidence is not a current corpse window.
        end
        if not replay and read(IsFishingLoot)==true then discardMoney();return end
        local count=replay and 0 or read(GetNumLootItems)
        diagnostics:Log("snapshot: replay/count",replay~=nil,count)
        if type(count)~="number" then
            if not replay then discardMoney() end
            return
        end
        local corpses=replay or {}
        local matchingSource,moneySlot,conflictingSource=false,false,false
        for slot=1,replay and 0 or count do
            local sources={read(GetLootSourceInfo,slot)}
            if read(GetLootSlotType,slot)==2 then moneySlot=true end
            local link=read(GetLootSlotLink,slot)
            local itemID=type(link)=="string" and tonumber(link:match("item:(%d+)"))
            for i=1,#sources,2 do
                local guid,quantity=sources[i],sources[i+1]
                local expected=pending and pending.guid or moneyContext and moneyContext.guid
                if expected then
                    if guid==expected then matchingSource=true else conflictingSource=true end
                end
                local id=type(guid)=="string" and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
                local entry=id and journal.entries[id]
                local state=liveState(guid)
                local pocket=pending and pending.guid==guid
                -- A living source cannot be a corpse. Ambiguous casts never teach loot.
                local allowed=pocket and not pending.failed and state==false
                    or not pending and state~=false
                if entry and entry.personalEncountered and allowed then
                    local sample=corpses[guid] or {id=id,entry=entry,items={},observed=true,pocket=pocket,key=pocket and pending.cast or guid}
                    corpses[guid]=sample
                    if itemID and type(quantity)=="number" and quantity>0 then
                        sample.items[itemID]=(sample.items[itemID] or 0)+quantity
                    end
                end
            end
        end
        if not replay and pending and pending.guid then
            if conflictingSource or liveState(pending.guid)~=false then
                discardMoney()
            elseif matchingSource or moneySlot then
                -- Some coin slots have no source GUID. A successful matched cast,
                -- living unit and money window still identify this interaction.
                pending.windowEvidence=true
                pending.moneyWindow=pending.moneyWindow or moneySlot
                confirmMoney()
            end
        end
        if not replay and not pending and moneyContext then
            -- Native autoloot can close and reopen the same living coin source.
            -- Keep only the already-confirmed window, inside its close grace.
            if not moneyContext.confirmed or not moneyContext.windowEvidence
                or moneyContext.invalid or not moneyContext.expires or clock()>moneyContext.expires
                or not matchingSource or conflictingSource or liveState(moneyContext.guid)~=false then
                discardMoney()
            end
        end
        diagnostics:Log("snapshot: matchingSource/moneySlot/conflict",matchingSource,moneySlot,conflictingSource)
        if pending and not pending.succeeded then
            if next(corpses) then buffered=corpses end
            return
        end
        local changed=false
        for guid,sample in pairs(corpses) do
            local entry=sample.entry
            if not sample.pocket then discardMoney() end
            local field=sample.pocket and "pickpocketLoot" or "loot"
            entry[field]=entry[field] or {samples=0,items={},recent={}}
            local loot=entry[field]
            guid=sample.key
            local previous
            for _,record in ipairs(loot.recent) do if record.guid==guid then previous=record;break end end
            if not previous then
                previous={guid=guid,items={}}
                loot.recent[#loot.recent+1]=previous
                if #loot.recent>128 then table.remove(loot.recent,1) end
                loot.samples=loot.samples+1;changed=true
            end
            -- Preserve the maximum snapshot across autoloot and repeated opens.
            local learned=false
            for id,quantity in pairs(sample.items) do
                local old=previous.items[id] or 0
                if quantity>old then
                    if not loot.items[id] then learned=true end
                    local item=loot.items[id] or {quantity=0,drops=0}
                    loot.items[id]=item
                    item.quantity=item.quantity+quantity-old
                    if old==0 then item.drops=item.drops+1 end
                    previous.items[id]=quantity;changed=true
                end
            end
            if learned and not sample.pocket and journal.TrackStableContent then journal:TrackStableContent(sample.id) end
        end
        if changed then journal:Touch() end
    end
    frame:RegisterEvent("LOOT_READY");frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    for _,event in ipairs({"UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED","LOOT_CLOSED","PLAYER_ENTERING_WORLD"}) do frame:RegisterEvent(event) end
    frame:SetScript("OnEvent",function(_,event,unit,a,b,c)
        if ns.InitializationBlocked then return end
        if event~="GET_ITEM_INFO_RECEIVED" then
            diagnostics:Log(event,unit,a,b,c)
            diagnostics:Log("state: pending/succeeded/guid/context",pending and pending.cast,
                pending and pending.succeeded,pending and pending.guid,moneyContext and moneyContext.cast)
        end
        for _,value in pairs({unit,a,b,c}) do if issecretvalue and issecretvalue(value) then return end end
        if event=="PLAYER_ENTERING_WORLD" then pending=nil;buffered=nil;discardMoney();return end
        if event=="LOOT_CLOSED" then
            if moneyContext then moneyContext.expires=clock()+1 end
            pending=nil;buffered=nil;return
        end
        if event=="UNIT_SPELLCAST_SENT" then
            if unit~="player" or c~=921 then return end
            pending={at=clock(),cast=b};buffered=nil
            if type(a)~="string" or type(b)~="string" then discardMoney();return end
            for _,token in ipairs({"target","mouseover","softenemy"}) do
                local guid=read(UnitGUID,token)
                if type(guid)=="string" and read(UnitName,token)==a and read(UnitIsDead,token)==false then
                    if pending.guid and pending.guid~=guid then pending.guid=nil;discardMoney();return end
                    pending.guid=guid
                end
            end
            diagnostics:Log("cast target matched",pending.guid)
            -- A repeat press while the same coin window is closing must not
            -- replace its proven source before PLAYER_MONEY arrives. Do not
            -- carry cast-only evidence, a different source, or consumed cash.
            local carry=moneyContext and moneyContext.confirmed and moneyContext.windowEvidence
                and not moneyContext.taken and not moneyContext.invalid and moneyContext.guid==pending.guid
                and (not moneyContext.expires or clock()<=moneyContext.expires)
            if carry then
                diagnostics:Log("coin window retained across repeat cast",moneyContext.cast,b)
            else
                discardMoney()
                if pending.guid then
                    moneyContext={name=a,guid=pending.guid,cast=b,expires=clock()+3,confirmed=false}
                end
            end
            return
        elseif event:find("^UNIT_SPELLCAST_") then
            if unit=="player" and pending and a==pending.cast and b==921 then
                pending.succeeded=event=="UNIT_SPELLCAST_SUCCEEDED"
                pending.failed=not pending.succeeded
                if pending.failed then
                    pending=nil;buffered=nil
                    if moneyContext and moneyContext.cast==a then discardMoney() end
                    return
                else confirmMoney() end
                if pending.succeeded then
                    local samples=buffered
                    local id=pending.guid and tonumber(pending.guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
                    local entry=id and journal.entries[id]
                    if not samples and entry and entry.personalEncountered then
                        samples={[pending.guid]={id=id,entry=entry,items={},pocket=true,key=pending.cast}}
                    end
                    if samples then snapshot(samples) end
                    buffered=nil
                end
            end
            return
        end
        if event=="GET_ITEM_INFO_RECEIVED" then journal:Touch() else snapshot() end
    end)
    return frame
end
