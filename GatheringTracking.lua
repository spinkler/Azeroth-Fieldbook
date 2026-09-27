local _, ns = ...

local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...);if ok and public(v) then return v end
end
local function spellName(id)
    return read(C_Spell and C_Spell.GetSpellName or GetSpellInfo,id)
end
local function gatheringKind(id)
    if not public(id) or type(id)~="number" or id<=0 or id>=math.huge or id~=math.floor(id) then return end
    if id==2366 then return "herb" elseif id==2575 then return "mineral" end
    -- Localized spell names cover profession ranks without an English-only list.
    local name=spellName(id)
    if type(name)~="string" or name=="" then return end
    if name==spellName(2366) then return "herb" end
    if name==spellName(2575) then return "mineral" end
end
local function castKey(v)
    return public(v) and type(v)=="string" and #v>0 and #v<=128 and not v:find("[%c|]")
end

local function text(v)
    if not public(v) or type(v)~="string" or #v>512 then return end
    return v:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$")
end
local function escape(v) return (v:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")) end
local function requirementKind(value,errorMessage)
    value=text(value)
    if not value or value=="" then return end
    local formats={}
    for _,key in ipairs({"ERR_USE_LOCKED_WITH_SPELL_S","ERR_USE_LOCKED_WITH_SPELL_KNOWN_SI",
        "LOCKED_WITH_SPELL","LOCKED_WITH_SPELL_KNOWN","ITEM_REQ_SKILL"}) do
        local format=text(_G[key]);if format then formats[#formats+1]=format end
    end
    local locale=read(GetLocale)
    local english=not locale or locale=="enUS" or locale=="enGB"
    if english then
        for _,format in ipairs({"Requires %s","Requires %s %d","Requires %s (%d)"}) do formats[#formats+1]=format end
    end
    local result
    for _,kind in ipairs({"herb","mineral"}) do
        local labels={}
        for _,id in ipairs(kind=="herb" and {2366,9134,170691} or {2575}) do
            local label=text(spellName(id));if label and label~="" then labels[#labels+1]=label end
        end
        if english then labels[#labels+1]=ns.GatheringKinds[kind].profession end
        for _,label in ipairs(labels) do
            local matches=not errorMessage and value==label
            for _,format in ipairs(formats) do
                -- Accept the client's localized requirement, not a substring in
                -- arbitrary quest text. Support positional printf placeholders.
                local pattern=format:gsub("%%[12]%$s",function() return label end)
                    :gsub("%%s",function() return label end)
                    :gsub("%%[12]%$d","AFBGATHERINGRANK"):gsub("%%d","AFBGATHERINGRANK")
                pattern=escape(pattern):gsub("AFBGATHERINGRANK",function() return "%d+" end)
                if value:match("^"..pattern.."$") then matches=true;break end
            end
            if matches then
                if result and result~=kind then return end
                result=kind
            end
        end
    end
    return result
end
local function worldResource()
    if not GameTooltip or read(GameTooltip.IsShown,GameTooltip)~=true then return end
    local info=read(GameTooltip.GetPrimaryTooltipInfo,GameTooltip)
    if type(info)~="table" or not public(info.getterName) or info.getterName~="GetWorldCursor" then return end
    -- Read a fresh world-cursor snapshot, not a fading tooltip or bag item.
    local data=read(C_TooltipInfo and C_TooltipInfo.GetWorldCursor)
    local objectType=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
    if not objectType or type(data)~="table" or not public(data.type) or data.type~=objectType
        or not public(data.lines) or type(data.lines)~="table" then return end
    local first=data.lines[1]
    local name=public(first) and type(first)=="table" and ns.GatheringName(text(first.leftText))
    if not name then return end
    local kind
    for i=2,math.min(#data.lines,16) do
        local line=data.lines[i]
        if public(line) and type(line)=="table" then
            for _,side in ipairs({"leftText","rightText"}) do
                local found=requirementKind(line[side])
                if found then
                    if kind and kind~=found then return end
                    kind=found
                end
            end
        end
    end
    if kind then return {name=name,kind=kind,modelFileID=ns.GatheringModel(kind,name,data.id)} end
end
local function worldHasMouseFocus()
    if not WorldFrame then return false end
    local foci=read(GetMouseFoci)
    if type(foci)=="table" then
        -- The world may have no mouse-enabled region, or only the root frame.
        -- Reject actual UI controls regardless of their order in the focus list.
        for _,focus in ipairs(foci) do
            if not public(focus) or (focus~=WorldFrame and focus~=UIParent) then return false end
        end
        return true
    end
    local focus=read(GetMouseFocus)
    return focus==WorldFrame or focus==UIParent
end

function ns.CreateGatheringTracking(journal)
    local controller={}
    local pending,lastFinished,clicked,hovered,lastRejected,blockedUntil
    local function clock()
        local now=read(GetTime)
        if type(now)=="number" and now>=0 and now<math.huge then return now end
    end
    local function clear() pending=nil end
    local function recent(context,field,now,limit)
        return context and now and context[field] and now>=context[field] and now-context[field]<=limit
    end
    local function same(a,b) return a and b and a.name==b.name and a.kind==b.kind end
    local function dismissedWorldTooltip()
        if not GameTooltip or read(GameTooltip.IsShown,GameTooltip)~=true then return true end
        local info=read(GameTooltip.GetPrimaryTooltipInfo,GameTooltip)
        -- ClearHandlerInfo can run before the fading tooltip is hidden.
        return info==nil or (type(info)=="table" and public(info.getterName) and info.getterName=="GetWorldCursor"
            and read(C_TooltipInfo and C_TooltipInfo.GetWorldCursor)==nil)
    end
    function controller:ObserveWorldCursor()
        local resource=worldResource()
        if resource then
            resource.observedAt=clock();hovered=resource
            journal:Discover(resource.kind,resource.name,read(time),read(GetRealZoneText),
                ns.CreatureLocations.CurrentMap(),resource.modelFileID)
        end
    end
    local function record(context)
        if context.id then return end
        -- Sampling requires a gathering cast or a skill-rejected interaction.
        -- Game objects have no dependable UnitPosition, so label player samples
        -- approximate. Discovery alone never calls this method.
        context.id=journal:RecordInteraction(context.kind,context.name,ns.CreatureLocations.Sample(),
            read(GetRealZoneText),read(time),context.modelFileID)
        if clicked and clicked.name==context.name and clicked.kind==context.kind then clicked.id=context.id end
    end
    function controller:OnEvent(event,unit,a,b,c)
        if event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then
            clear();clicked=nil;hovered=nil;lastRejected=nil;blockedUntil=clock();return
        end
        if event=="GLOBAL_MOUSE_DOWN" then
            clicked=nil
            local now=clock()
            blockedUntil=now and now+2 or nil
            if not public(unit) or unit~="RightButton" or not worldHasMouseFocus() then hovered=nil;return end
            local resource=worldResource()
            if not resource and recent(hovered,"observedAt",now,0.5) and dismissedWorldTooltip() then
                resource={name=hovered.name,kind=hovered.kind,modelFileID=hovered.modelFileID}
            end
            if resource and now then resource.clickedAt=now;clicked=resource;blockedUntil=nil end
            return -- A right-click by itself is not proof that the node was used.
        end
        if event=="UI_ERROR_MESSAGE" then
            local now=clock()
            local kind=requirementKind(a,true)
            if not kind or not now then clicked=nil;blockedUntil=now and now+2 or nil;return end
            local current=worldResource()
            local attempt=clicked
            if attempt and not recent(attempt,"clickedAt",now,2) then clicked=nil;attempt=nil end
            if attempt then
                if attempt.id then return end
                if kind~=attempt.kind or (current and not same(current,attempt))
                    or (not current and not dismissedWorldTooltip()) then
                    clicked=nil;blockedUntil=now+2;return
                end
            else
                if blockedUntil and now<=blockedUntil then return end
                -- The matching skill error is itself evidence of attempted use.
                -- This also works when global mouse events are absent or an
                -- interaction key is used, but requires a live world resource.
                if not current or current.kind~=kind or not worldHasMouseFocus() then return end
                attempt=current
            end
            if same(lastRejected,attempt) and recent(lastRejected,"rejectedAt",now,0.25) then return end
            if same(pending,attempt) and recent(pending,"sentAt",now,2) then attempt.id=pending.id end
            record(attempt) -- Missing profession/rank; never counts as a completed gather.
            attempt.rejectedAt=now;lastRejected=attempt
            if same(pending,attempt) then pending.id=attempt.id end
            return
        end
        if not public(unit) or unit~="player" then return end
        if event=="UNIT_SPELLCAST_SENT" then
            if castKey(b) and (b==lastFinished or (pending and b==pending.guid)) then return end
            -- Any new player cast invalidates an older pending gathering attempt.
            clear()
            local name,kind=ns.GatheringName(a),gatheringKind(c)
            if clicked and (clicked.name~=name or clicked.kind~=kind) then clicked=nil end
            local now=clock()
            if not name or not kind or not castKey(b) or not now then
                blockedUntil=now and now+2 or nil;hovered=nil;return
            end
            pending={name=name,kind=kind,guid=b,spellID=c,sentAt=now}
            if clicked and clicked.id and now>=clicked.clickedAt and now-clicked.clickedAt<=2 then pending.id=clicked.id end
            if same(lastRejected,pending) and recent(lastRejected,"rejectedAt",now,0.25) then pending.id=lastRejected.id end
            local current=worldResource()
            if current and current.name==name and current.kind==kind then pending.modelFileID=current.modelFileID end
            return
        end
        if not pending or not castKey(a) or a~=pending.guid or not public(b) or b~=pending.spellID then return end
        local now=clock()
        if not now or now-pending.sentAt>30 or now<pending.sentAt then clear();return end
        if event=="UNIT_SPELLCAST_START" then
            record(pending)
        elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
            record(pending) -- also supports an instant gather with no START event
            if pending.id then journal:Complete(pending.id) end
            lastFinished=pending.guid
            clear()
        elseif event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_FAILED_QUIET"
            or event=="UNIT_SPELLCAST_INTERRUPTED" then lastFinished=pending.guid;clear() end
        -- STOP can precede SUCCEEDED. It never records anything or drops evidence.
    end
    local frame=CreateFrame("Frame")
    for _,event in ipairs({"UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_START","UNIT_SPELLCAST_SUCCEEDED",
        "UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_FAILED_QUIET","UNIT_SPELLCAST_INTERRUPTED"}) do
        frame:RegisterUnitEvent(event,"player")
    end
    frame:RegisterEvent("PLAYER_ENTERING_WORLD");frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("UI_ERROR_MESSAGE")
    -- Older clients may lack global input events; gathering casts still work.
    pcall(frame.RegisterEvent,frame,"GLOBAL_MOUSE_DOWN")
    frame:SetScript("OnEvent",function(_,event,...) controller:OnEvent(event,...) end)
    local elapsed=0
    frame:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed>=0.2 then elapsed=0;controller:ObserveWorldCursor() end
    end)
    controller.frame=frame
    return controller
end
