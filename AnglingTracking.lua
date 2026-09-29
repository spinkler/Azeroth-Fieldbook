local _, ns = ...
local A=ns.Angling

-- Contracts checked in Blizzard's Forever source, commit bd2470ae.
-- IsFishingLoot is authoritative about activity, never about a pool.
function A.ReadFishingSkill()
    local data=A.Read(C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID,356)
    if type(data)~="table" or not A.Public(data.skillID) or data.skillID~=356 then return {} end
    local s={}
    if A.Integer(data.rank,0,10000) then s.base=data.rank end
    if A.Integer(data.modifier,-1000,10000) then s.modifier=data.modifier end
    if A.Integer(data.tempPoints,0,10000) then s.temporary=data.tempPoints end
    if s.base and s.modifier and s.temporary==0 then
        -- Forever's SkillsEntryMixin displays rank plus modifier. tempPoints
        -- is not included by that UI and has no established fishing meaning;
        -- a nonzero/unreadable value leaves effective skill unknown.
        local n=s.base+s.modifier;if A.Integer(n,0,10000) then s.effective=n end
    end
    -- Modifier/temporary points are API totals. They do not separately identify
    -- a rod, equipment bonus or lure; leave those fields unknown.
    return s
end
local function fishingSpell(id)
    if not A.Integer(id,1,2147483647) then return false end
    if id==7620 then return true end
    local name=A.Read(C_Spell and C_Spell.GetSpellName or GetSpellInfo,id)
    local fishing=A.Read(C_Spell and C_Spell.GetSpellName or GetSpellInfo,7620)
    return A.Name(name)~=nil and A.Name(fishing)~=nil and name==fishing
end
local function clock() local n=A.Read(GetTime);return A.Number(n,0,math.huge-1) and n or A.Now() end
local function fishingFailure(id,message)
    local name=A.Integer(id,1,2147483647) and A.Read(GetGameMessageInfo,id)
    for _,key in ipairs({"ERR_FISH_ESCAPED","ERR_FISH_NOT_HOOKED"}) do
        if name==key then return key end
        local localized=_G[key]
        if A.Text(message,512) and A.Text(localized,512) and message==localized then return key end
    end
end
local function tooltipText(value)
    if not A.Public(value) or type(value)~="string" or #value>512 then return end
    return A.Name((value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")))
end
local function fishingRequirement(value)
    value=tooltipText(value);if not value then return false end
    local label=tooltipText(A.Read(C_Spell and C_Spell.GetSpellName or GetSpellInfo,7620))
    if not label then return false end
    if value==label then return true end
    local formats={}
    for _,key in ipairs({"ERR_USE_LOCKED_WITH_SPELL_S","ERR_USE_LOCKED_WITH_SPELL_KNOWN_SI",
        "LOCKED_WITH_SPELL","LOCKED_WITH_SPELL_KNOWN","ITEM_REQ_SKILL"}) do
        local f=tooltipText(_G[key]);if f then formats[#formats+1]=f end
    end
    local locale=A.Read(GetLocale)
    if locale=="enUS" or locale=="enGB" then
        for _,f in ipairs({"Requires %s","Requires %s %d","Requires %s (%d)"}) do formats[#formats+1]=f end
    end
    for _,f in ipairs(formats) do
        local pattern=f:gsub("%%[12]%$s",function() return label end):gsub("%%s",function() return label end)
            :gsub("%%[12]%$d","AFBFISHINGRANK"):gsub("%%d","AFBFISHINGRANK")
        pattern=pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"):gsub("AFBFISHINGRANK",function() return "%d+" end)
        if value:match("^"..pattern.."$") then return true end
    end
    return false
end
local function worldPool()
    if not GameTooltip then return end
    local info=A.Read(GameTooltip.GetPrimaryTooltipInfo,GameTooltip)
    if type(info)=="table" then
        if not A.Public(info.getterName) or info.getterName~="GetWorldCursor" then return end
    else
        -- Some native world tooltips do not populate the Lua processing-info
        -- table. Require a visible tooltip and world-only mouse focus instead.
        if A.Read(GameTooltip.IsShown,GameTooltip)~=true or not WorldFrame then return end
        local foci=A.Read(GetMouseFoci)
        if type(foci)=="table" then
            for _,focus in ipairs(foci) do
                if not A.Public(focus) or (focus~=WorldFrame and focus~=UIParent) then return end
            end
        else
            local focus=A.Read(GetMouseFocus)
            if focus~=WorldFrame and focus~=UIParent then return end
        end
    end
    local data=A.Read(C_TooltipInfo and C_TooltipInfo.GetWorldCursor)
    local kind=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
    if kind==nil or type(data)~="table" or not A.Public(data.type) or data.type~=kind
        or not A.Public(data.lines) or type(data.lines)~="table" then return end
    local first=data.lines[1]
    local name=A.Public(first) and type(first)=="table" and tooltipText(first.leftText)
    if not name then return end
    if name==tooltipText(_G.FISHING_BOBBER) or name:lower()=="fishing bobber" then return end
    for i=2,math.min(#data.lines,16) do
        local line=data.lines[i]
        if A.Public(line) and type(line)=="table" and (fishingRequirement(line.leftText) or fishingRequirement(line.rightText)) then
            return {name=name}
        end
    end
    -- Some pools expose only their name. Restrict this fallback to English
    -- world-object tooltips; never classify bag links or unit names this way.
    local locale=A.Read(GetLocale)
    if locale=="enUS" or locale=="enGB" then
        local n=name:lower()
        if n:match(" school$") or n:match(" shoal$") or n:match(" pool$")
            or n:match(" wreckage$") or n=="floating debris" or n=="patch of elemental water" then return {name=name} end
    end
end
local function slotInfo(slot)
    local link=A.Read(GetLootSlotLink,slot)
    local id=type(link)=="string" and tonumber(link:match("item:(%d+)"))
    if not A.Integer(id,1,2147483647) or type(GetLootSlotInfo)~="function" then return end
    local ok,texture,name,quantity=pcall(GetLootSlotInfo,slot)
    -- The readable item hyperlink establishes item identity. Do not depend on
    -- the later quality/currency return positions, which differ across clients.
    if not ok or not A.Integer(quantity,1,1000000) then return end
    local label=A.Name(name)
    if not label then
        label=A.Name(A.Read(C_Item and C_Item.GetItemNameByID,id) or A.Read(GetItemInfo,id))
        if not label then A.Read(C_Item and C_Item.RequestLoadItemDataByID,id) end
    end
    return {itemID=id,name=label,quantity=quantity,icon=A.Integer(texture,1,2147483647) and texture or nil}
end
function ns.CreateAnglingTracking(journal)
    local t={journal=journal,status="Fishing catches record automatically when fishing loot is readable."}
    local cast,assignment,failedWindow
    local function changed() if t.onChange then t.onChange() end end
    function t:ObserveWorldCursor()
        if ns.InitializationBlocked then return end
        local pool=worldPool();if not pool then return end
        self.observingHover=true
        local e=journal:ObservePool(pool,A.CurrentLocation())
        self.observingHover=nil;return e
    end
    function t:ClearSource(reason)
        local hadSource=assignment~=nil
        if cast and not cast.context then cast.assignment=nil end
        assignment=nil;journal:EndSession();self.status=reason or "Session source cleared; future catches are unclassified.";changed()
        if hadSource then journal:Log("Source",self.status) end
    end
    function t:Assignment(location)
        if not assignment then return end
        local p=A.Location(location or A.CurrentLocation())
        if (assignment.spotID and not journal.db.spots[assignment.spotID]) or (assignment.poolID and not journal.db.pools[assignment.poolID])
            or (assignment.spotID and journal.db.spots[assignment.spotID].removed)
            or (assignment.poolID and journal.db.pools[assignment.poolID].removed)
            or A.WaterKey(p)~=assignment.waterKey or clock()-assignment.last>300 or clock()<assignment.last
            or (assignment.x and (not p.x or math.abs(p.x-assignment.x)>50 or math.abs(p.y-assignment.y)>50)) then
            self:ClearSource("Source assignment expired after a context change.");return
        end
        return assignment
    end
    function t:Assign(source,id)
        if journal.readOnly then return nil,"Newer Almanac schema: read-only." end
        local p=A.Location(A.CurrentLocation());local e=journal:Get(id)
        if e and e.removed then return nil,"Restore this record before assigning it." end
        local value={source=source,waterKey=A.WaterKey(p),x=p.x,y=p.y,last=clock(),method="recorded"}
        if source=="pool" then
            if e and e.kind=="pool" and e.removed then return nil,"Restore this pool type before assigning it." end
            if e and e.kind=="spot" then
                if e.mapID~=p.mapID or e.zone~=p.zone or e.subzone~=p.subzone then return nil,"Visit the selected spot's waters before assigning it." end
                value.spotID,value.poolID=e.id,e.poolID
            elseif e and e.kind=="pool" then value.poolID=e.id end
            if not value.poolID then return nil,"Select a known pool type or pool sighting first." end
            if journal.db.pools[value.poolID].removed then return nil,"Restore this pool type before assigning it." end
        elseif source=="open" or (source=="unclassified" and e and e.kind=="spot" and not e.poolID) then
            if e and e.kind=="spot" and not e.poolID and e.mapID==p.mapID and e.zone==p.zone and e.subzone==p.subzone then value.spotID=e.id end
        else self:ClearSource();return true end
        assignment=value;cast=nil;journal:EndSession()
        self.status=A.SourceLabels[source].." — "..(source=="unclassified" and "spot" or "source").." player assigned for this session."
        journal:Log("Source",self.status..(e and " "..e.name or "").." — "..p.zone)
        changed();return true
    end
    function t:SessionText()
        local current=self:Assignment();local s=journal.session
        local label=current and (A.SourceLabels[current.source]..(current.poolID and ": "..journal:Get(current.poolID).name or "").." (player assigned)")
            or "Unclassified water — no source assigned"
        if current and current.spotID then label=label.." • "..journal:Get(current.spotID).name end
        if s then label=label.."\nThis session: "..s.events.." catch events • "..s.newItems.." new personal items" end
        return label
    end
    local function alive()
        return cast and clock()>=cast.started and clock()-cast.started<=90
            and (not cast.interruptedAt or cast.loot or clock()-cast.interruptedAt<=2)
    end
    local function collect()
        if not alive() or not cast.context or not cast.loot then return end
        local items={}
        for slot,item in pairs(cast.slots) do if cast.cleared[slot] then items[#items+1]=item end end
        if #items>0 then
            local fact,didChange=journal:RecordCatch(cast.guid,cast.context,items)
            if fact and didChange then t.status="Fishing loot recorded. Source: "..A.SourceLabels[cast.context.source]..".";changed() end
        end
    end
    local function snapshot(isFromItem,ready)
        if isFromItem==true then cast=nil;return end -- a caught container opened later
        if failedWindow then
            -- Ignore late OPENED/CHANGED/CLEARED for the escaped fish. Clients
            -- without readable casts can resume at a fresh nonempty READY.
            if not ready or not A.Integer(A.Read(GetNumLootItems),1,50) then return end
            failedWindow=nil
        end
        local fishing=A.Read(IsFishingLoot)==true
        local completed=cast and cast.fallback and cast.closed and next(cast.slots)~=nil
        if completed then for slot in pairs(cast.slots) do if not cast.cleared[slot] then completed=false;break end end end
        -- IsFishingLoot independently establishes the activity. A client cast
        -- GUID is useful for deduplication, but is not required evidence of it.
        -- Keep partial windows across retries; a new nonempty READY after a
        -- fully collected fallback window starts the next obtained event.
        if fishing and (not alive() or (ready and completed and A.Number(A.Read(GetNumLootItems),1,50))) then
            local p=A.Location(A.CurrentLocation())
            cast={guid=journal:ID("loot"),started=clock(),position=p,skill={},assignment=A.Copy(t:Assignment(p)),
                slots={},cleared={},blocked={},fallback=true}
        end
        if not alive() then
            return
        end
        if not fishing and not ready then
            cast.loot=false;cast.window=false
            t.status="Loot was not identified as fishing by the client; no catch added."
            journal:Log("Capture skipped",t.status,"skip:"..cast.guid);changed();return
        end
        -- READY may precede the fishing flag, and autoloot may clear slots
        -- before OPENED. Cache evidence now; only commit after both signals.
        cast.window=true;cast.closed=false;cast.loot=cast.loot or fishing
        if not cast.context then
            local current=A.Location(A.CurrentLocation())
            if A.WaterKey(current)~=A.WaterKey(cast.position) then cast=nil;return end
            local skill=A.ReadFishingSkill()
            for _,key in ipairs({"base","modifier","temporary","effective"}) do
                if skill[key]~=cast.skill[key] then cast.skill.effective=nil;break end
            end
            cast.context=journal:Context(cast.position,cast.assignment,"observed",cast.skill)
        end
        local count=A.Read(GetNumLootItems)
        if not A.Integer(count,0,50) then return end
        for slot=1,count do
            local item=slotInfo(slot);local previous=cast.slots[slot]
            -- Retain the pre-autoloot snapshot. A reshuffled/reused slot is not
            -- another catch, and unreadable replacement values cannot erase it.
            if item and previous and not cast.cleared[slot] and (item.itemID~=previous.itemID or item.quantity~=previous.quantity) then
                cast.slots[slot]=nil;cast.blocked[slot]=true
                t.status="Loot slots changed; use Record catch for omitted items."
                journal:Log("Capture skipped",t.status,"slots:"..cast.guid);changed()
            elseif item and not previous and not cast.cleared[slot] and not cast.blocked[slot] then cast.slots[slot]=item end
        end
        collect()
    end
    function t:ManualCatch(input)
        local items=A.Array(input,50) and input or {input}
        if #items==0 or #items>50 then return nil,"Enter between one and 50 items from one catch event." end
        for _,item in ipairs(items) do
            if type(item)~="table" or not A.ItemIdentity(item) or not A.Integer(item.quantity,1,1000000) then
                return nil,"Enter an item ID or name and a whole quantity from 1 to 1,000,000."
            end
        end
        local p=A.Location(A.CurrentLocation())
        local context=journal:Context(p,self:Assignment(p),"recorded",{})
        if not context then return nil,"Journal is read-only." end
        -- Manual entry is an assertion about a past catch. Current skill is not
        -- historical evidence and is intentionally not attached to it.
        local fact,err=journal:RecordCatch(journal:ID("manual"),context,items)
        if fact then self.status="One player-recorded catch event added.";changed() end
        return fact,err
    end
    function t:OnEvent(event,a,b,c,d)
        if ns.InitializationBlocked then return end
        if event=="UI_ERROR_MESSAGE" or event=="UI_INFO_MESSAGE" then
            local failure=fishingFailure(a,b)
            if failure then
                local duplicate=failedWindow
                cast=nil;failedWindow=true
                self.status=failure=="ERR_FISH_ESCAPED" and "Fish got away; no catch recorded. Ready for the next cast."
                    or "No fish was hooked; no catch recorded. Ready for the next cast."
                if not duplicate then journal:Log("Fishing attempt",self.status) end
                changed()
            end
            return
        end
        if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_LEAVING_WORLD" or event=="PLAYER_LOGOUT"
            or event=="ZONE_CHANGED" or event=="ZONE_CHANGED_INDOORS" or event=="ZONE_CHANGED_NEW_AREA" or event=="PLAYER_STARTED_MOVING" then
            cast=nil;failedWindow=nil;self:ClearSource("Fishing context changed; session source cleared.");return
        end
        if event=="GET_ITEM_INFO_RECEIVED" then
            if not A.Integer(a,1,2147483647) or not A.Public(b) or not b then return end
            local name=A.Read(C_Item and C_Item.GetItemNameByID,a) or A.Read(GetItemInfo,a)
            local id=journal.db.itemKeys["item:"..a];local e=id and journal:Get(id)
            if e and e.personal and A.Name(name) then e.name=A.Name(name);journal:Changed() end
            if e and not e.personal then changed() end -- refresh cached icons without changing report provenance
            return
        end
        if event=="LOOT_READY" then snapshot(false,true);return end
        if event=="LOOT_OPENED" then snapshot(A.Public(b) and b or nil);return end
        if event=="LOOT_SLOT_CHANGED" then if cast and cast.loot then snapshot(false) end;return end
        if event=="LOOT_SLOT_CLEARED" then
            if alive() and cast.window and A.Integer(a,1,50) and cast.slots[a] and not cast.cleared[a] then
                if A.Read(IsFishingLoot)==true then cast.loot=true end
                cast.cleared[a]=true;collect()
            end
            return
        end
        if event=="LOOT_CLOSED" then if cast then cast.loot=false;cast.window=false;cast.closed=true end;return end
        if not A.Public(a) or a~="player" then return end
        local guid,spell=event=="UNIT_SPELLCAST_SENT" and c or b,event=="UNIT_SPELLCAST_SENT" and d or c
        if event=="UNIT_SPELLCAST_SENT" or event=="UNIT_SPELLCAST_CHANNEL_START" or event=="UNIT_SPELLCAST_START" then
            if not fishingSpell(spell) then cast=nil;self:ClearSource("Another activity cleared the fishing source assignment.");return end
            failedWindow=nil
            local readableGUID=A.Text(guid,200) and guid or nil
            if cast and ((readableGUID and cast.clientGUID==readableGUID) or
                (not readableGUID and not cast.clientGUID and not cast.context and clock()-cast.started<=2)) then return end
            local p=A.Location(A.CurrentLocation());local current=self:Assignment(p)
            if current then current.last=clock() end
            cast={guid=readableGUID or journal:ID("cast"),clientGUID=readableGUID,started=clock(),position=p,
                skill=A.ReadFishingSkill(),assignment=A.Copy(current),slots={},cleared={},blocked={}}
            self.status="Fishing cast observed; waiting for collected fishing loot.";changed()
        elseif event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_FAILED_QUIET" or event=="UNIT_SPELLCAST_INTERRUPTED" then
            if cast and ((A.Text(guid,200) and cast.clientGUID==guid) or (not A.Text(guid,200) and fishingSpell(spell))) then
                if event=="UNIT_SPELLCAST_INTERRUPTED" then cast.interruptedAt=clock()
                else cast=nil end
            end
        end
        -- A channel ending is not a catch or a skill rejection. LOOT_READY can
        -- follow CHANNEL_STOP; the authoritative loot flag still has to pass.
    end
    local frame=CreateFrame("Frame");t.frame=frame
    for _,event in ipairs({"UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_START","UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_FAILED_QUIET","UNIT_SPELLCAST_INTERRUPTED"}) do
        pcall(frame.RegisterUnitEvent,frame,event,"player")
    end
    for _,event in ipairs({"LOOT_READY","LOOT_OPENED","LOOT_SLOT_CLEARED","LOOT_SLOT_CHANGED","LOOT_CLOSED",
        "PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","PLAYER_LOGOUT","PLAYER_STARTED_MOVING","ZONE_CHANGED",
        "ZONE_CHANGED_NEW_AREA","ZONE_CHANGED_INDOORS","GET_ITEM_INFO_RECEIVED","UI_ERROR_MESSAGE","UI_INFO_MESSAGE"}) do pcall(frame.RegisterEvent,frame,event) end
    frame:SetScript("OnEvent",function(_,event,...) t:OnEvent(event,...) end)
    local objectType=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
    if objectType and TooltipDataProcessor and type(TooltipDataProcessor.AddTooltipPostCall)=="function" then
        TooltipDataProcessor.AddTooltipPostCall(objectType,function(tooltip)
            if tooltip==GameTooltip then t:ObserveWorldCursor() end
        end)
    end
    if GameTooltip and type(GameTooltip.SetWorldCursor)=="function" and type(hooksecurefunc)=="function" then
        hooksecurefunc(GameTooltip,"SetWorldCursor",function() t:ObserveWorldCursor() end)
    end
    if GameTooltip and type(GameTooltip.HookScript)=="function" then
        -- Native world-object tooltips can bypass Lua processor callbacks and
        -- replace their text without another OnShow. Sample only the visible
        -- tooltip, at most five times per second, using fresh cursor data.
        local elapsed=0
        GameTooltip:HookScript("OnShow",function() elapsed=0;t:ObserveWorldCursor() end)
        GameTooltip:HookScript("OnHide",function() elapsed=0 end)
        GameTooltip:HookScript("OnUpdate",function(tooltip,dt)
            if A.Read(tooltip.IsShown,tooltip)~=true or not A.Number(dt,0,100) then return end
            elapsed=elapsed+dt
            if elapsed>=0.2 then elapsed=0;t:ObserveWorldCursor() end
        end)
    end
    -- No hidden world/bag scanning or notification spam. Hover never assigns a catch.
    return t
end
