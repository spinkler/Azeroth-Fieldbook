-- Ephemeral observations only. Secret values go directly to FontStrings, never SavedVariables.
local _, ns = ...
local window = {}
ns.SpellIDWindow = window
local db, panel, background
local customPosition = false
local rows, seen = {}, { player = {}, target = {} }
local castBars = {}
local castBarOrder = {}
local displayAlpha = 1
local layoutHeight = 44
local blacklistWindow
local auraStatus = { player = "not scanned", target = "not scanned" }
local events = CreateFrame("Frame")
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function validID(value)
    return public(value) and type(value)=="number" and value>0 and value<=2147483647 and value==math.floor(value)
end
local function bottomAnchor(point,relativePoint,x,y,height)
    local fraction=point:find("TOP",1,true) and 1 or (point:find("BOTTOM",1,true) and 0 or 0.5)
    local bottom=point:find("LEFT",1,true) and "BOTTOMLEFT" or (point:find("RIGHT",1,true) and "BOTTOMRIGHT" or "BOTTOM")
    return bottom,relativePoint,x,y-height*fraction
end
local function layout()
    if not panel then return end
    local count,height=0,0
    for _, row in ipairs(rows) do
        if row.observed then
            row.body:ClearAllPoints()
            row.body:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-48-height)
            row.body:SetSize(330,row.hasCaster and 68 or 52)
            height=height+(row.hasCaster and 72 or 56)
            row.body:Show();count=count+1
        else row.body:Hide() end
    end
    layoutHeight=count==0 and 44 or 50+height
    panel:SetSize(330,layoutHeight)
end
local function readableTable(value)
    return public(value) and type(value) == "table" and not (issecrettable and issecrettable(value))
end
local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function targetUnit(unit)
    if not public(unit) or type(unit) ~= "string" then return false end
    if unit == "target" then return true end
    local same = read(UnitIsUnit, unit, "target")
    return public(same) and same == true
end
local function npcTarget()
    local exists = read(UnitExists, "target")
    local player = read(UnitIsPlayer, "target")
    local controlled = read(UnitPlayerControlled, "target")
    return public(exists) and public(player) and public(controlled)
        and exists == true and not player and not controlled
end
local function enemyTarget()
    local exists = read(UnitExists, "target")
    local enemy = read(UnitIsEnemy, "player", "target")
    local controlled = read(UnitPlayerControlled, "target")
    return public(exists) and public(enemy) and public(controlled)
        and exists == true and enemy == true and not controlled
end
local function clear(row)
    row.observed = nil
    row.rawID=nil;row.token=nil
    row.id:SetText(""); row.name:SetText(""); row.effect:SetText("")
    if row.caster then row.caster:SetText("") end
    row.body:Hide()
    layout()
end
function window:IsBlacklisted(id)
    return validID(id) and db and db.spellIDWindowBlacklist and db.spellIDWindowBlacklist[id]==true or false
end
function window:GetBlacklist()
    local list={}
    for id,enabled in pairs(db and db.spellIDWindowBlacklist or {}) do
        if validID(id) and enabled==true then list[#list+1]=id end
    end
    table.sort(list);return list
end
function window:AddBlacklist(id)
    if not public(id) then return false,"This ID is restricted. Enter the displayed ID manually. Restricted future IDs cannot be matched to the blacklist." end
    if type(id)=="string" then id=tonumber(id:match("^%s*(%d+)%s*$")) end
    if not validID(id) or not db then return false,"Enter a positive numeric spell ID." end
    db.spellIDWindowBlacklist=db.spellIDWindowBlacklist or {}
    db.spellIDWindowBlacklist[id]=true
    for _, row in ipairs(rows) do
        if validID(row.rawID) and row.rawID==id then clear(row) end
    end
    if blacklistWindow then blacklistWindow:Refresh() end
    return true,"Blacklisted spell ID "..id.."."
end
function window:RemoveBlacklist(id)
    if not validID(id) or not db then return end
    if db.spellIDWindowBlacklist then db.spellIDWindowBlacklist[id]=nil end
    for _, row in ipairs(rows) do
        if row.dismissedID==id then row.dismissedID=nil;row.dismissedToken=nil end
    end
    seen={player={},target={}}
    if blacklistWindow then blacklistWindow:Refresh() end
end
function window:OpenBlacklist(message)
    if not blacklistWindow and ns.CreateSpellBlacklistWindow then blacklistWindow=ns.CreateSpellBlacklistWindow(self) end
    if blacklistWindow then blacklistWindow:Open(message) end
end
local function text(parent, x, y, width, template)
    local value = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    value:SetPoint("TOPLEFT", x, y); value:SetSize(width, 14); value:SetJustifyH("LEFT")
    return value
end
local function updateFade(delta)
    local hasData = false
    for _, row in ipairs(rows) do if row.observed then hasData = true; break end end
    local fading = db.spellIDWindowAutoFade == true and not hasData
    if fading then displayAlpha = math.max(0, displayAlpha - delta / 0.3)
    else displayAlpha = 1 end
    panel:SetAlpha(displayAlpha)
    panel:EnableMouse(not db.spellIDWindowLocked and not fading)
end
local function setup()
    if panel then return end
    panel = CreateFrame("Frame", "AzerothFieldbookSpellIDWindow", UIParent)
        if ns.UIScale then ns.UIScale:Register(panel) end
    panel:SetSize(330, 44); panel:SetFrameStrata("LOW")
    panel:SetClampedToScreen(true); panel:SetMovable(true)
    if panel.SetClampRectInsets then panel:SetClampRectInsets(0,0,0,0) end
    panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(); background:SetColorTexture(0, 0, 0, 0.35)
    text(panel, 10, -9, 310, "GameFontNormalSmall"):SetText("Last observed spell IDs")
    panel.hint = text(panel, 10, -27, 310)
    panel.hint:SetTextColor(0.6, 0.6, 0.6)
    panel:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            db.displaySpellIDWindow = false
            window:ApplySettings()
        end
    end)
    panel:SetScript("OnDragStart", function(self)
        if not db.spellIDWindowLocked then self:StartMoving() end
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        point,relativePoint,x,y=bottomAnchor(point,relativePoint,x,y,layoutHeight)
        self:ClearAllPoints();self:SetPoint(point,UIParent,relativePoint,x,y)
        db.spellIDWindowPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
        customPosition = true
    end)
    for index, title in ipairs({ "Enemy cast", "Enemy instant cast", "Debuff on you", "Buff on target" }) do
        local row = {}
        rows[index] = row
        row.body = CreateFrame("Frame", nil, panel)
        row.body:SetSize(330,68)
        text(row.body, 10, -16, 52):SetText("Spell ID:")
        row.id = text(row.body, 65, -16, 92)
        row.effect = text(row.body, 164, -16, 156)
        row.name = text(row.body, 10, -32, 310)
        text(row.body,10,0,310,"GameFontNormalSmall"):SetText(title)
        row.casterLabel=text(row.body,10,-48,52);row.casterLabel:SetText("Cast by:")
        row.caster=text(row.body,65,-48,255)
        row.caster:SetTextColor(0.7,0.7,0.7)
        row.body:EnableMouse(true);row.body:RegisterForDrag("LeftButton")
        row.body:SetScript("OnDragStart",function() if not db.spellIDWindowLocked then panel:StartMoving() end end)
        row.body:SetScript("OnDragStop",function() panel:GetScript("OnDragStop")(panel) end)
        row.body:SetScript("OnMouseUp",function(_,button)
            if button=="RightButton" then
                local token=row.token
                local dismissedID=validID(row.rawID) and row.rawID or nil
                if IsControlKeyDown and IsControlKeyDown() then
                    local ok,message=window:AddBlacklist(row.rawID)
                    if not ok then window:OpenBlacklist(message) end
                end
                row.dismissedToken=token
                row.dismissedID=dismissedID
                clear(row);updateFade(0)
            elseif button=="LeftButton" and IsShiftKeyDown() then
                db.displaySpellIDWindow=false;window:ApplySettings()
            end
        end)
        clear(row)
    end
    local elapsed = 0
    panel:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.25 then
            elapsed = 0
            if not db.spellIDWindowIndefinite then
                for _, row in ipairs(rows) do
                    if row.observed and GetTime() - row.observed >= 120 then clear(row) end
                end
            end
        end
        updateFade(delta)
    end)
    if ns.WindowFocus then ns.WindowFocus:Register(panel, "LOW") end
end
local function present(index, id, name, effect, caster, token)
    if public(id) and (type(id) ~= "number" or id <= 0) then return end
    if window:IsBlacklisted(id) then return false,"suppressed" end
    local row = rows[index]
    if token and row.dismissedToken==token then return false,"suppressed" end
    row.dismissedToken=nil;row.dismissedID=nil
    clear(row)
    if not pcall(row.id.SetText, row.id, id) then return end
    -- Never concatenate, compare, measure or read back these potentially secret fields.
    pcall(row.name.SetText, row.name, name)
    pcall(row.effect.SetText, row.effect, effect)
    row.hasCaster=not public(caster) or (type(caster)=="string" and caster~="" and caster~="Unknown")
    row.casterLabel:SetShown(row.hasCaster);row.caster:SetShown(row.hasCaster)
    if row.hasCaster then
        local shown=pcall(row.caster.SetText,row.caster,caster)
        if not shown then row.hasCaster=false;row.casterLabel:Hide();row.caster:Hide() end
    end
    row.rawID=id;row.token=token
    row.observed = GetTime()
    row.body:Show()
    layout()
    updateFade(0)
    return true
end
local function scanAuras(unit, updates)
    if unit == "target" and not npcTarget() then
        seen.target = {}
        auraStatus.target = "target excluded (absent, player or player-controlled)"
        return
    end
    if not C_UnitAuras then auraStatus[unit] = "aura API unavailable"; return end
    local updated = {}
    if readableTable(updates) and readableTable(updates.updatedAuraInstanceIDs) then
        for _, id in ipairs(updates.updatedAuraInstanceIDs) do
            if public(id) and type(id) == "number" then updated[id] = true end
        end
    end
    local current = {}
    local filter = unit == "player" and "HARMFUL" or "HELPFUL"
    local returned, displayed, unchanged = 0, 0, 0
    local problem
    local path = "index"
    local slotFailure
    local function failure(label, errorValue)
        if public(errorValue) and type(errorValue) == "string" then
            return label .. ": " .. errorValue:gsub("[\r\n]", " "):gsub("|", ""):sub(1, 240)
        end
        return label .. " (error text unavailable)"
    end
    local function accept(aura, key)
        returned = returned + 1
        if not public(aura) or type(aura) ~= "table" then
            problem = "aura table unavailable"
            return
        end
        -- issecrettable also flags accessible tables whose fields produce secrets.
        -- Check access permission instead; text fields still go only to SetText.
        if type(canaccesstable) == "function" then
            if not canaccesstable(aura) then problem = "aura table access denied"; return end
        elseif not readableTable(aura) then
            problem = "aura table access unavailable"
            return
        end
        local ok, instance, spellID, name, effect = pcall(function()
            return aura.auraInstanceID, aura.spellId, aura.name, aura.dispelName
        end)
        if not ok then problem = "aura field access failed"; return end
        -- Public slots track enumeration even when auraInstanceID is secret.
        -- Use public instance identity when available to distinguish slot reuse.
        local identity = true
        if public(instance) and type(instance) == "number" then
            identity = instance
            key = "instance:" .. instance
        else key = path .. ":" .. key end
        current[key] = identity
        if seen[unit][key] ~= identity or (identity ~= true and updated[identity]) then
            local source=read(function() return aura.sourceUnit end)
            local caster
            if public(source) and type(source)=="string" and source~="" then caster=read(UnitName,source) end
            local shown,reason=present(unit == "player" and 3 or 4, spellID, name, effect,caster,"aura:"..unit..":"..key)
            if shown then
                displayed = displayed + 1
            elseif reason=="suppressed" then unchanged=unchanged+1
            else
                problem = "aura ID absent or SetText rejected"
                current[key] = nil -- Retry on the next observation.
            end
        else unchanged = unchanged + 1 end
    end
    local completed = true
    if type(C_UnitAuras.GetAuraSlots) == "function" and type(C_UnitAuras.GetAuraDataBySlot) == "function" then
        path = "slots"
        local function pack(...) return { n = select("#", ...), ... } end
        local token
        completed = false
        for page = 1, 16 do
            local result = pack(pcall(C_UnitAuras.GetAuraSlots, unit, filter, 32, token))
            if not result[1] then
                slotFailure = failure("aura slot query failed", result[2])
                problem = slotFailure
                break
            end
            for index = 3, result.n do
                local slot = result[index]
                if public(slot) and type(slot) == "number" then
                    accept(read(C_UnitAuras.GetAuraDataBySlot, unit, slot), slot)
                else problem = "aura slot unavailable" end
            end
            token = result[2]
            if not public(token) then problem = "aura continuation unavailable"; break end
            if token == nil then completed = true; break end
        end
        if not completed and not problem then problem = "aura page limit reached" end
    else completed = false end
    -- A slot-query error is not an empty aura list. Try the documented indexed
    -- API when slots returned nothing, and retain both errors if access is denied.
    if not completed and returned == 0 then
        path = slotFailure and "index fallback" or "index"
        if type(C_UnitAuras.GetAuraDataByIndex) == "function" then
            problem = nil
            for index = 1, 255 do
                local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
                if not ok then problem = failure("aura index query failed", aura); break end
                if public(aura) and aura == nil then completed = true; break end
                accept(aura, index)
            end
            if not completed and not problem then problem = "aura index limit reached" end
        else problem = "aura index API unavailable" end
    end
    if completed then seen[unit] = current end
    auraStatus[unit] = "path=" .. path .. "; returned=" .. returned .. "; displayed=" .. displayed .. "; unchanged=" .. unchanged
        .. (slotFailure and ("; " .. slotFailure) or "")
        .. (problem and problem ~= slotFailure and ("; " .. problem) or "")
end

local function observeCast()
    if not enemyTarget() then return end
    local ok, name, _, _, _, _, _, _, _, id, bar = pcall(UnitCastingInfo, "target")
    if ok and (not public(name) or name ~= nil) then
        if public(bar) and type(bar) == "number" and not castBars[bar] then
            castBars[bar] = true; castBarOrder[#castBarOrder + 1] = bar
            if #castBarOrder > 32 then castBars[table.remove(castBarOrder, 1)] = nil end
        end
        present(1, id, name,nil,read(UnitName,"target"),validID(bar) and ("cast:"..bar) or nil)
        return true
    end
    local channelOK, channelName, _, _, _, _, _, _, channelID, _, _, channelBar = pcall(UnitChannelInfo, "target")
    if channelOK and (not public(channelName) or channelName ~= nil) then
        if public(channelBar) and type(channelBar) == "number" and not castBars[channelBar] then
            castBars[channelBar] = true; castBarOrder[#castBarOrder + 1] = channelBar
            if #castBarOrder > 32 then castBars[table.remove(castBarOrder, 1)] = nil end
        end
        present(1, channelID, channelName,nil,read(UnitName,"target"),validID(channelBar) and ("cast:"..channelBar) or nil)
        return true
    end
end
events:SetScript("OnEvent", function(_, event, unit, second, id, bar)
    if not db or db.displaySpellIDWindow == false then return end
    if event == "PLAYER_TARGET_CHANGED" then
        seen.target = {}; castBars = {}; castBarOrder = {}
        scanAuras("target"); observeCast()
    elseif event == "PLAYER_ENTERING_WORLD" then
        seen = { player = {}, target = {} }; castBars = {}; castBarOrder = {}
        scanAuras("player"); scanAuras("target"); observeCast()
    elseif event == "PLAYER_REGEN_ENABLED" then
        scanAuras("player"); scanAuras("target")
    elseif event == "UNIT_AURA" then
        if public(unit) and unit == "player" then scanAuras("player", second)
        elseif targetUnit(unit) then scanAuras("target", second) end
    elseif targetUnit(unit) and enemyTarget() then
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if public(bar) and type(bar) == "number" and castBars[bar] then return end
            if observeCast() then return end -- Channels may report success as they begin.
            local info = C_Spell and read(C_Spell.GetSpellInfo, id)
            local instant = readableTable(info) and public(info.castTime) and info.castTime == 0
            local name = C_Spell and read(C_Spell.GetSpellName, id)
            -- Unclassified successes remain casts; SENT alone never proves an instant succeeded.
            present(instant and 2 or 1, id, name, instant and nil or "Succeeded",read(UnitName,"target"),validID(bar) and ("cast:"..bar) or nil)
        else observeCast() end
    end
end)
function window:ApplySettings()
    if not db then return end
    setup()
    if ns.AuraTooltipSnapshot then ns.AuraTooltipSnapshot:ApplySettings() end
    panel:StopMovingOrSizing()
    panel:SetMovable(not db.spellIDWindowLocked)
    panel.afbPinned=db.spellIDWindowLocked
    panel:EnableMouse(not db.spellIDWindowLocked)
    panel.hint:SetText("Right-click: hide / Ctrl+Right-click: blacklist")
    background:SetColorTexture(0, 0, 0, db.spellIDWindowAlpha)
    events:UnregisterAllEvents()
    if db.displaySpellIDWindow == false then
        panel:Hide()
        for _, row in ipairs(rows) do clear(row) end
        seen = { player = {}, target = {} }; castBars = {}; castBarOrder = {}
        return
    end
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterUnitEvent("UNIT_AURA", "player", "target")
    events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START" }) do
        events:RegisterUnitEvent(event, "target")
    end
    panel:Show()
    scanAuras("player"); scanAuras("target")
    updateFade(0)
end
function window:AnchorToBook(book)
    if panel and book and not customPosition then
        panel:ClearAllPoints()
        panel:SetPoint("BOTTOMRIGHT",book,"BOTTOMLEFT",-6,0)
    end
end

function window:Initialize(settings)
    db = settings
    if type(db.spellIDWindowBlacklist)~="table" then db.spellIDWindowBlacklist={} end
    db.displaySpellIDWindow = db.displaySpellIDWindow ~= false
    db.spellIDWindowLocked = db.spellIDWindowLocked == true
    db.spellIDWindowIndefinite = db.spellIDWindowIndefinite == true
    db.spellIDWindowAlpha = math.max(0, math.min(1, tonumber(db.spellIDWindowAlpha) or 0.35))
    setup()
    for _, row in ipairs(rows) do clear(row);row.dismissedToken=nil;row.dismissedID=nil end
    seen = { player = {}, target = {} }; castBars = {}; castBarOrder = {}
    panel:ClearAllPoints()
    local position = db.spellIDWindowPosition
    customPosition = false
    local points = { TOP=true, BOTTOM=true, LEFT=true, RIGHT=true, CENTER=true,
        TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true }
    if type(position) == "table" and points[position.point] and points[position.relativePoint]
        and type(position.x) == "number" and type(position.y) == "number" then
        local point,relativePoint,x,y=bottomAnchor(position.point,position.relativePoint,position.x,position.y,286)
        panel:SetPoint(point, UIParent, relativePoint,x,y)
        db.spellIDWindowPosition={point=point,relativePoint=relativePoint,x=x,y=y}
        customPosition = true
    else
        panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 30, 100)
        self:AnchorToBook(AzerothFieldbookBestiary)
    end
    if ns.AuraTooltipSnapshot then
        ns.AuraTooltipSnapshot:Initialize(db, panel, function(unit, kind)
            if unit == "player" and kind == "debuff" then return "Debuff on you" end
            if kind == "buff" and targetUnit(unit) and npcTarget() then return "Buff on target" end
        end)
    end
    self:ApplySettings()
    if db.displaySpellIDWindow then observeCast() end
end

function window:Report(say)
    say("ID window player debuffs: " .. auraStatus.player)
    say("ID window target buffs: " .. auraStatus.target)
    if ns.AuraTooltipSnapshot then ns.AuraTooltipSnapshot:Report(say) end
end
