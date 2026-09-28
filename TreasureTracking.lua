local _, ns = ...
local T=ns.Treasure
local function clock() local n=T.Read(GetTime);return T.Number(n,0,9999999999) and n or T.Now() end
local function returns(fn,...)
    if type(fn)~="function" then return end
    local values={pcall(fn,...)};if not values[1] then return end
    for i=2,#values do if not T.Public(values[i]) then return end end
    return unpack(values,2)
end
function ns.CreateTreasureTracking(journal)
    local t={journal=journal,bagGUIDs={},recent={},status="World finds and uncertain loot sources require Record a find."}
    function t:Status(message)
        if self.status==message then return end;self.status=message
        if self.onStatus then self.onStatus(message) end
    end
    function t:Expire()
        local now=clock()
        for guid,v in pairs(self.bagGUIDs) do if v.absentAt and now-v.absentAt>60 then self.bagGUIDs[guid]=nil end end
        for guid,v in pairs(self.recent) do if now-v.at>120 then self.recent[guid]=nil end end
        if self.pending and now-self.pending.at>3 then self.pending=nil end
        if self.active and now-self.active.at>60 then self.active=nil end
    end
    function t:ScanBags()
        self:Expire()
        if journal.readOnly or not C_Container then return end
        local maximum=T.Integer(NUM_BAG_SLOTS,0,5) and NUM_BAG_SLOTS or 4
        local carried,seenGUIDs={},{}
        for _,v in pairs(journal.encounters) do if not v.reported and v.context=="carried" then carried[v.kindID]=true end end
        for bag=0,maximum do
            local slots=T.Read(C_Container.GetContainerNumSlots,bag)
            for slot=1,(T.Integer(slots,0,64) and slots or 0) do
                local info=T.Read(C_Container.GetContainerItemInfo,bag,slot)
                if type(info)=="table" and T.Public(info.hasLoot) and info.hasLoot==true and T.Integer(info.itemID,1,2147483647) then
                    local e=journal:FindItem(info.itemID)
                    if not e or not carried[e.id] then
                        local kind={name=T.Name(info.itemName) or "Item #"..info.itemID,itemID=info.itemID,form="portable",category="container"}
                        local err
                        e,err=journal:Record(e and e.id,kind,{context="carried",location=T.CurrentLocation("carried"),facts={sighted=true},capture="missing",items={}},"observed")
                        if not e and type(err)=="string" then self:Status(err) end
                        if e then carried[e.id]=true end
                    end
                    local loc=T.Read(ItemLocation and ItemLocation.CreateFromBagAndSlot,ItemLocation,bag,slot)
                    local guid=loc and T.Read(C_Item and C_Item.GetItemGUID,loc)
                    if e and T.Text(guid,160) and (self.bagGUIDs[guid] or T.Count(self.bagGUIDs)<384) then
                        self.bagGUIDs[guid]={kindID=e.id,itemID=info.itemID,at=clock()}
                        seenGUIDs[guid]=true
                    end
                end
            end
        end
        -- While a bag snapshot still contains an item, its opaque identity is
        -- useful even after a long idle. Grace begins when a later snapshot
        -- no longer finds it, allowing an autoloot-consumed item to correlate.
        for guid,v in pairs(self.bagGUIDs) do if not seenGUIDs[guid] and not v.absentAt then v.absentAt=clock() end end
    end
    function t:ReadLoot()
        self:Expire()
        if T.Read(IsFishingLoot)~=false then return end
        local n=T.Read(GetNumLootItems);if not T.Integer(n,1,T.MAX_ITEMS) then return end
        local sample={items={},at=clock()};local byItem={}
        for slot=1,n do
            local sources={returns(GetLootSourceInfo,slot)}
            -- Require one exact GUID supplied by the item API. Never parse an
            -- object/creature GUID or attach the target/recent hover to loot.
            if #sources~=2 or not T.Text(sources[1],160) or not T.Integer(sources[2],1,1000000) then return end
            local guid=sources[1];local known=self.bagGUIDs[guid]
            if not known or (sample.guid and sample.guid~=guid) then return end
            sample.guid,sample.kindID=guid,known.kindID
            local link=T.Read(GetLootSlotLink,slot)
            local id=type(link)=="string" and tonumber(link:match("item:(%d+)"))
            local _,name,quantity=returns(GetLootSlotInfo,slot)
            if T.Integer(id,1,2147483647) and T.Integer(quantity,1,1000000) and quantity==sources[2] then
                local row=byItem[id] or {itemID=id,name=T.Name(name),quantity=0}
                byItem[id]=row;row.quantity=row.quantity+quantity
                if row.quantity>1000000 then return end
            end
        end
        for _,row in pairs(byItem) do sample.items[#sample.items+1]=row end
        table.sort(sample.items,function(a,b) return a.itemID<b.itemID end)
        if #sample.items==0 then return end
        sample.location=T.CurrentLocation("opened");return sample
    end
    function t:Capture(sample)
        if not sample or journal.readOnly then return end
        local previous=self.recent[sample.guid]
        if previous and previous.suppressed then return end
        if not previous and T.Count(self.recent)>=128 then self:Status("Automatic correlation buffer is full; use Record a find.");return end
        local encounter=previous and journal.encounters[previous.id]
        if not encounter then
            local _,v=journal:Record(sample.kindID,nil,{context="opened",location=sample.location,
                facts={inspected=true},capture="partial",items=sample.items},"observed")
            if type(v)~="table" then self:Status(type(v)=="string" and v or "Capture unavailable.");return end
            encounter=v
        else
            local changed=false;local byID={};for _,v in ipairs(encounter.items) do byID[v.itemID]=v end
            for _,v in ipairs(sample.items) do
                local old=byID[v.itemID]
                if old then if v.quantity>old.quantity then old.quantity=v.quantity;changed=true end
                elseif #encounter.items<T.MAX_ITEMS then encounter.items[#encounter.items+1]=T.Copy(v);changed=true end
            end
            if changed then journal:Changed(encounter.kindID) end
        end
        self.recent[sample.guid]={id=encounter.id,at=clock()}
        self.active={guid=sample.guid,id=encounter.id,at=clock()}
        self:Status("Portable contents captured (partial); personal receipt unconfirmed.")
    end
    function t:Event(event,...)
        self:Expire()
        if event=="PLAYER_ENTERING_WORLD" then self.active=nil;self.pending=nil;self.bagGUIDs={};self.recent={} end
        if event=="BAG_UPDATE_DELAYED" or event=="PLAYER_ENTERING_WORLD" then
            if self.bagQueued then return end;self.bagQueued=true
            local function scan() self.bagQueued=false;self:ScanBags() end
            if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(0.25,scan) else scan() end
        elseif event=="LOOT_READY" then
            self.active=nil;self.pending=self:ReadLoot()
        elseif event=="LOOT_OPENED" then
            local _,isFromItem=...
            if not T.Public(isFromItem) or isFromItem~=true or T.Read(IsFishingLoot)~=false then self.pending=nil;self.active=nil;return end
            local current=self:ReadLoot()
            -- A nonempty but unreadable/different window must not inherit the
            -- READY snapshot. Only an autoloot-cleared window can use it alone.
            local sample=current or (T.Read(GetNumLootItems)==0 and self.pending)
            if current and self.pending and current.guid~=self.pending.guid then self.pending=nil;self.active=nil;return end
            if current and self.pending then
                local seen={};for _,row in ipairs(current.items) do seen[row.itemID]=row end
                for _,row in ipairs(self.pending.items) do
                    if seen[row.itemID] then seen[row.itemID].quantity=math.max(seen[row.itemID].quantity,row.quantity)
                    elseif #current.items<T.MAX_ITEMS then current.items[#current.items+1]=row end
                end
            end
            self.pending=nil;self:Capture(sample)
        elseif event=="LOOT_SLOT_CHANGED" then
            local sample=self.active and self:ReadLoot()
            if sample and sample.guid==self.active.guid then self:Capture(sample) end
        elseif event=="LOOT_CLOSED" then self.active=nil;self.pending=nil
        elseif event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then
            local id=...;if T.Integer(id,1,2147483647) and journal.requested[id] then
                if journal.metadata[id] then journal.metadataCount=math.max(0,journal.metadataCount-1) end
                journal.metadata[id]=nil;journal:Changed()
            end
        end
    end
    local frame=CreateFrame("Frame");t.frame=frame
    journal.onRemove=function(id)
        for _,v in pairs(t.recent) do if v.id==id then v.suppressed=true end end
        if t.active and t.active.id==id then t.active=nil;t.pending=nil end
    end
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","LOOT_READY","LOOT_OPENED","LOOT_SLOT_CHANGED","LOOT_CLOSED","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT"}) do
        pcall(frame.RegisterEvent,frame,event)
    end
    frame:SetScript("OnEvent",function(_,event,...) t:Event(event,...) end)
    return t
end
