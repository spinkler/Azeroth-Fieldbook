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
    local t={journal=journal,bagGUIDs={},recent={},status="Recognized world containers and portable contents record automatically; uncertain sources require Record a find."}
    -- Match observed tooltip identity to the actual loot source, never to the
    -- current target or loot-chat text. Unknown object types stay manual.
    local function objectID(guid)
        if not T.Text(guid,160) then return end
        local id=guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$")
        id=tonumber(id);return T.Integer(id,1,2147483647) and id or nil
    end
    local function containerName(value)
        local name=T.Name(value);if not name then return end
        name=name:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
        for _,word in ipairs({"chest","crate","coffer","strongbox","footlocker","lockbox","cache","barrel","sack"}) do
            if name:lower():find("%f[%a]"..word.."%f[%A]") then return name end
        end
    end
    local function fresh(value,limit)
        return value and clock()>=value.at and clock()-value.at<=limit
    end
    local function worldFocus()
        local foci=T.Read(GetMouseFoci)
        if type(foci)=="table" then
            for _,focus in ipairs(foci) do if not T.Public(focus) or (focus~=WorldFrame and focus~=UIParent) then return false end end
            return true
        end
        local focus=T.Read(GetMouseFocus)
        return focus~=nil and (focus==WorldFrame or focus==UIParent)
    end
    function t:ObserveWorldCursor()
        if ns.InitializationBlocked or journal.readOnly then return end
        local data=T.Read(C_TooltipInfo and C_TooltipInfo.GetWorldCursor)
        local objectType=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
        if type(data)~="table" then return end
        self.world=nil
        if not objectType or not T.Public(data.type) or data.type~=objectType
            or not T.Public(data.lines) or type(data.lines)~="table" then return end
        local first=data.lines[1]
        local name=T.Public(first) and type(first)=="table" and containerName(first.leftText)
        if not name then return end
        local guid=T.Text(data.guid,160) and objectID(data.guid) and data.guid or nil
        local id=guid and objectID(guid) or (T.Integer(data.id,1,2147483647) and data.id)
        self.world={name=name,objectID=id,guid=guid,at=clock()}
    end
    function t:WorldSource(guid)
        local id=objectID(guid);if not id then return end
        -- Once a window is attributed, asynchronous slot updates retain its
        -- identity even if the mouse moves to another tooltip.
        local active=self.active and self.active.guid==guid and journal.encounters[self.active.id]
        local existing=active and journal:Get(active.kindID)
        if existing and existing.form=="world" then return {kindID=existing.id,world=true} end
        local seen=self.world
        if not fresh(seen,15) or not seen.objectID then
            seen=fresh(self.interaction,3) and self.interaction or nil
        end
        if not seen then return end
        if seen.objectID and seen.objectID~=id or seen.guid and seen.guid~=guid then return end
        if not seen.objectID and not fresh(self.interaction,3) then return end
        local kindID
        for _,e in pairs(journal.kinds) do
            if e.form=="world" and e.objectID==id then kindID=e.id;break end
        end
        return {kindID=kindID,kind={name=seen.name,form="world",category="container",objectID=id},world=true}
    end
    function t:Status(message)
        if self.status==message then return end;self.status=message
        if self.onStatus then self.onStatus(message) end
    end
    function t:Expire()
        local now=clock()
        for guid,v in pairs(self.bagGUIDs) do if v.absentAt and now-v.absentAt>60 then self.bagGUIDs[guid]=nil end end
        for guid,v in pairs(self.recent) do if now-v.at>120 then self.recent[guid]=nil end end
        if self.world and now-self.world.at>15 then self.world=nil end
        if self.interaction and not fresh(self.interaction,3) then self.interaction=nil end
        if self.cast and not fresh(self.cast,30) then self.cast=nil end
        if self.pending and now-self.pending.at>3 then self.pending=nil end
        if self.active and now-self.active.at>60 then self.active=nil end
    end
    function t:ScanBags()
        if ns.InitializationBlocked then return end
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
        self:ObserveWorldCursor()
        if T.Read(IsFishingLoot)~=false then return nil,"Fishing context unavailable or fishing loot." end
        local n=T.Read(GetNumLootItems);if not T.Integer(n,1,T.MAX_ITEMS) then return nil,"No readable loot slots." end
        local sample={items={},at=clock()};local byItem={}
        for slot=1,n do
            local sources={returns(GetLootSourceInfo,slot)}
            -- Coin rows can report zero quantity. They still need the same
            -- exact source as every item; never let coins mask mixed loot.
            local moneyType=Enum and Enum.LootSlotType and Enum.LootSlotType.Money or LOOT_SLOT_MONEY
            local coin=moneyType~=nil and T.Read(GetLootSlotType,slot)==moneyType
            if #sources~=2 or not T.Text(sources[1],160) or not T.Integer(sources[2],coin and 0 or 1,1000000) then return nil,"Loot source missing or mixed." end
            local guid=sources[1];local known=self.bagGUIDs[guid] or self:WorldSource(guid)
            if not known then
                if objectID(guid) then
                    local seen=self.interaction or self.world or self.cast
                    return nil,"World loot has no matching container tooltip or recent opening interaction. Source: "..guid
                        .."; observed container: "..(seen and seen.name or "none")
                        .."; tooltip object ID: "..tostring(seen and seen.objectID or "none")
                        .."; opening: "..(self.lastOpening or "none").."."
                end
                -- Retain the rejected readable identity so native client
                -- differences can be diagnosed after the loot window closes.
                local seen=self.interaction or self.world or self.cast
                return nil,"Loot source is not a recognized container. Source: "..guid
                    .."; observed container: "..(seen and seen.name or "none").."."
            end
            if sample.guid and sample.guid~=guid then return nil,"Loot slots have different sources." end
            sample.guid,sample.kindID,sample.kind,sample.world=guid,known.kindID,known.kind,known.world
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
        if #sample.items==0 then return nil,"Container identified, but item links or quantities are unreadable." end
        sample.location=T.CurrentLocation(sample.world and "world" or "opened");return sample
    end
    function t:Capture(sample)
        if not sample or journal.readOnly then return end
        local previous=self.recent[sample.guid]
        if previous and previous.suppressed then return end
        if not previous and T.Count(self.recent)>=128 then self:Status("Automatic correlation buffer is full; use Record a find.");return end
        local encounter=previous and journal.encounters[previous.id]
        local newlyRecorded=not encounter
        if not encounter then
            local _,v=journal:Record(sample.kindID,sample.kind,{context=sample.world and "world" or "opened",location=sample.location,
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
        if newlyRecorded and self.onContentsRecorded then self.onContentsRecorded(journal:Get(encounter.kindID),encounter) end
        self:Status((sample.world and "World container" or "Portable").." contents captured (partial); personal receipt unconfirmed.")
    end
    function t:Event(event,...)
        if ns.InitializationBlocked then return end
        self:Expire()
        if event=="GLOBAL_MOUSE_DOWN" then
            self.interaction=nil;self.cast=nil;self.pending=nil
            local button=...
            if not T.Public(button) or button~="RightButton" or not worldFocus() then self.world=nil;return end
            self:ObserveWorldCursor()
            if fresh(self.world,0.5) then self.interaction=T.Copy(self.world);self.interaction.at=clock() end
            return
        elseif event=="UNIT_SPELLCAST_SENT" then
            local unit,target,castGUID,spellID=...
            if not T.Public(unit) or unit~="player" then return end
            local clicked=fresh(self.interaction,0.5) and self.interaction or nil
            self.cast=nil;self.interaction=nil;self.pending=nil
            local name=containerName(target)
            -- Opening can omit its target name. Carry only a just-clicked
            -- world container through this specific cast, never an arbitrary
            -- spell or hover. Completion and exact loot-source checks remain.
            local unnamed=T.Public(target) and (target==nil or target=="")
            local opening=T.Public(spellID) and spellID==3365
            if not name and unnamed and opening and clicked then name=clicked.name end
            self.lastOpening="spell "..(T.Integer(spellID,1,2147483647) and tostring(spellID) or "unreadable")
                ..", target "..(T.Name(target) or "none")..", clicked "..(clicked and clicked.name or "none")
            if name and T.Text(castGUID,160) and T.Integer(spellID,1,2147483647) then
                self:ObserveWorldCursor()
                local seen=clicked and clicked.name==name and clicked
                    or (fresh(self.world,0.5) and self.world.name==name and self.world or nil)
                self.world=seen
                self.cast={name=name,guid=seen and seen.guid,objectID=seen and seen.objectID,
                    castGUID=castGUID,spellID=spellID,at=clock()}
            else self.world=nil end
            return
        elseif event=="UNIT_SPELLCAST_SUCCEEDED" or event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_FAILED_QUIET" or event=="UNIT_SPELLCAST_INTERRUPTED" then
            local unit,castGUID,spellID=...
            if T.Public(unit) and unit=="player" and self.cast and T.Public(castGUID) and T.Public(spellID)
                and self.cast.castGUID==castGUID and self.cast.spellID==spellID then
                if event=="UNIT_SPELLCAST_SUCCEEDED" then self.interaction=self.cast;self.interaction.at=clock()
                else self.interaction=nil;self.world=nil;self.pending=nil end
                self.cast=nil
            end
            return
        end
        if event=="PLAYER_ENTERING_WORLD" then self.active=nil;self.pending=nil;self.world=nil;self.interaction=nil;self.cast=nil;self.lastOpening=nil;self.bagGUIDs={};self.recent={} end
        if event=="BAG_UPDATE_DELAYED" or event=="PLAYER_ENTERING_WORLD" then
            if self.bagQueued then return end;self.bagQueued=true
            local function scan() self.bagQueued=false;self:ScanBags() end
            if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(0.25,scan) else scan() end
        elseif event=="LOOT_READY" then
            self.active=nil;self.pending,self.pendingReason=self:ReadLoot()
        elseif event=="LOOT_OPENED" then
            local _,isFromItem=...
            if not T.Public(isFromItem) or (isFromItem~=nil and type(isFromItem)~="boolean") or T.Read(IsFishingLoot)~=false then
                self.pending=nil;self.active=nil;self:Status("Capture skipped: fishing or unreadable loot context.");return
            end
            local current,reason=self:ReadLoot()
            -- A nonempty but unreadable/different window must not inherit the
            -- READY snapshot. Only an autoloot-cleared window can use it alone.
            local sample=current or (T.Read(GetNumLootItems)==0 and self.pending)
            -- Exact bag GUID attribution is stronger than the optional origin
            -- flag, which can be absent/false for opened clams on this client.
            -- ReadLoot already requires every slot to match that observed item.
            if sample and sample.world and isFromItem==true then
                self.pending=nil;self.active=nil;self:Status("Capture skipped: container and loot-window type disagree.");return
            end
            if current and self.pending and current.guid~=self.pending.guid then self.pending=nil;self.active=nil;self:Status("Capture skipped: loot source changed while opening.");return end
            if current and self.pending then
                local seen={};for _,row in ipairs(current.items) do seen[row.itemID]=row end
                for _,row in ipairs(self.pending.items) do
                    if seen[row.itemID] then seen[row.itemID].quantity=math.max(seen[row.itemID].quantity,row.quantity)
                    elseif #current.items<T.MAX_ITEMS then current.items[#current.items+1]=row end
                end
            end
            if not sample and (self.world or self.interaction or self.cast or isFromItem==true) then
                self:Status("Capture skipped: "..((T.Read(GetNumLootItems)==0 and self.pendingReason) or reason or self.pendingReason or "Source unavailable."))
            end
            self.pending=nil;self.pendingReason=nil;self:Capture(sample)
        elseif event=="LOOT_SLOT_CHANGED" then
            local sample=self.active and self:ReadLoot()
            if sample and sample.guid==self.active.guid then self:Capture(sample) end
        elseif event=="LOOT_CLOSED" then
            self.active=nil;self.pending=nil;self.interaction=nil;self.cast=nil
            for guid,v in pairs(self.recent) do if v.suppressed then self.recent[guid]=nil end end
        elseif event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then
            local id=...;if T.Integer(id,1,2147483647) and journal.requested[id] then
                if journal.metadata[id] then journal.metadataCount=math.max(0,journal.metadataCount-1) end
                journal.metadata[id]=nil;journal:Changed()
            end
        end
    end
    local frame=CreateFrame("Frame");t.frame=frame
    journal.onRemove=function(id)
        -- Ignore duplicate signals from the currently open window only. A new
        -- opening must be free to rediscover the same item immediately.
        local active=t.active and t.active.id==id
        for guid,v in pairs(t.recent) do if v.id==id then
            if active then v.suppressed=true else t.recent[guid]=nil end
        end end
        if t.active and t.active.id==id then t.active=nil;t.pending=nil end
    end
    for _,event in ipairs({"GLOBAL_MOUSE_DOWN","UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_FAILED_QUIET","UNIT_SPELLCAST_INTERRUPTED","PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","LOOT_READY","LOOT_OPENED","LOOT_SLOT_CHANGED","LOOT_CLOSED","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT"}) do
        pcall(frame.RegisterEvent,frame,event)
    end
    frame:SetScript("OnEvent",function(_,event,...) t:Event(event,...) end)
    local objectType=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
    if objectType and TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall)=="function" then
        TooltipDataProcessor.AddTooltipPostCall(objectType,function(tooltip) if tooltip==GameTooltip then t:ObserveWorldCursor() end end)
    end
    if GameTooltip and type(GameTooltip.SetWorldCursor)=="function" and type(hooksecurefunc)=="function" then
        hooksecurefunc(GameTooltip,"SetWorldCursor",function() t:ObserveWorldCursor() end)
    end
    local elapsed=0
    frame:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt;if elapsed>=0.2 then elapsed=0;t:ObserveWorldCursor() end
    end)
    return t
end
