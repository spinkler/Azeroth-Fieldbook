local _, ns = ...
local function read(fn,...)
    if type(fn)~="function" then return end
    local v={pcall(fn,...)}
    if not v[1] then return end
    for i=2,#v do if issecretvalue and issecretvalue(v[i]) then return end end
    return unpack(v,2)
end
function ns.StartBestiaryLoot(journal)
    if journal.lootObserver then return journal.lootObserver end
    local frame=CreateFrame("Frame")
    journal.lootObserver=frame
    local function snapshot()
        if read(IsFishingLoot)==true then return end
        local count=read(GetNumLootItems)
        if type(count)~="number" then return end
        local corpses={}
        for slot=1,count do
            local sources={read(GetLootSourceInfo,slot)}
            local link=read(GetLootSlotLink,slot)
            local itemID=type(link)=="string" and tonumber(link:match("item:(%d+)"))
            for i=1,#sources,2 do
                local guid,quantity=sources[i],sources[i+1]
                local id=type(guid)=="string" and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
                local entry=id and journal.entries[id]
                if entry and entry.personalEncountered then
                    local sample=corpses[guid] or {id=id,entry=entry,items={}}
                    corpses[guid]=sample
                    if itemID and type(quantity)=="number" and quantity>0 then
                        sample.items[itemID]=(sample.items[itemID] or 0)+quantity
                    end
                end
            end
        end
        local changed=false
        for guid,sample in pairs(corpses) do
            local entry=sample.entry
            entry.loot=entry.loot or {samples=0,items={},recent={}}
            local loot=entry.loot
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
            if learned and journal.TrackStableContent then journal:TrackStableContent(sample.id) end
        end
        if changed then journal:Touch() end
    end
    frame:RegisterEvent("LOOT_READY");frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:SetScript("OnEvent",function(_,event)
        if event=="GET_ITEM_INFO_RECEIVED" then journal:Touch() else snapshot() end
    end)
    return frame
end
