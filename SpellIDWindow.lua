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
local auraStatus = { player = "not scanned", target = "not scanned" }
local events = CreateFrame("Frame")
local function public(value) return not (issecretvalue and issecretvalue(value)) end
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
    row.id:SetText(""); row.name:SetText(""); row.effect:SetText("")
    row.body:Hide()
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
    panel:SetSize(330, 286); panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true); panel:SetMovable(true)
    if panel.SetClampRectInsets then panel:SetClampRectInsets(0,0,0,0) end
    panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(); background:SetColorTexture(0, 0, 0, 0.35)
    text(panel, 10, -9, 310, "GameFontNormalSmall"):SetText("Last observed spell IDs")
    panel.hint = text(panel, 10, -27, 310)
    panel:SetScript("OnDragStart", function(self)
        if not db.spellIDWindowLocked then self:StartMoving() end
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        db.spellIDWindowPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
        customPosition = true
    end)
    for index, title in ipairs({ "Enemy cast", "Enemy instant cast", "Debuff on you", "Buff on target" }) do
        local row = {}
        rows[index] = row
        local y = -50 - (index - 1) * 58
        text(panel, 10, y, 310, "GameFontNormalSmall"):SetText(title)
        row.body = CreateFrame("Frame", nil, panel)
        row.body:SetAllPoints(panel)
        text(row.body, 10, y - 16, 52):SetText("Spell ID:")
        row.id = text(row.body, 65, y - 16, 92)
        row.effect = text(row.body, 164, y - 16, 156)
        row.name = text(row.body, 10, y - 32, 310)
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
    if ns.WindowFocus then ns.WindowFocus:Register(panel) end
end
local function present(index, id, name, effect)
    if public(id) and (type(id) ~= "number" or id <= 0) then return end
    local row = rows[index]
    clear(row)
    if not pcall(row.id.SetText, row.id, id) then return end
    -- Never concatenate, compare, measure or read back these potentially secret fields.
    pcall(row.name.SetText, row.name, name)
    pcall(row.effect.SetText, row.effect, effect)
    row.observed = GetTime()
    row.body:Show()
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
            if present(unit == "player" and 3 or 4, spellID, name, effect) then
                displayed = displayed + 1
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
        present(1, id, name)
        return true
    end
    local channelOK, channelName, _, _, _, _, _, _, channelID, _, _, channelBar = pcall(UnitChannelInfo, "target")
    if channelOK and (not public(channelName) or channelName ~= nil) then
        if public(channelBar) and type(channelBar) == "number" and not castBars[channelBar] then
            castBars[channelBar] = true; castBarOrder[#castBarOrder + 1] = channelBar
            if #castBarOrder > 32 then castBars[table.remove(castBarOrder, 1)] = nil end
        end
        present(1, channelID, channelName)
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
            present(instant and 2 or 1, id, name, instant and nil or "Succeeded")
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
    panel.hint:SetText(db.spellIDWindowLocked and "" or "Drag to move")
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
        panel:SetPoint("RIGHT",book,"LEFT",-6,0)
    end
end

function window:Initialize(settings)
    db = settings
    db.displaySpellIDWindow = db.displaySpellIDWindow ~= false
    db.spellIDWindowLocked = db.spellIDWindowLocked == true
    db.spellIDWindowIndefinite = db.spellIDWindowIndefinite == true
    db.spellIDWindowAlpha = math.max(0, math.min(1, tonumber(db.spellIDWindowAlpha) or 0.35))
    setup()
    for _, row in ipairs(rows) do clear(row) end
    seen = { player = {}, target = {} }; castBars = {}; castBarOrder = {}
    panel:ClearAllPoints()
    local position = db.spellIDWindowPosition
    customPosition = false
    local points = { TOP=true, BOTTOM=true, LEFT=true, RIGHT=true, CENTER=true,
        TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true }
    if type(position) == "table" and points[position.point] and points[position.relativePoint]
        and type(position.x) == "number" and type(position.y) == "number" then
        panel:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
        customPosition = true
    else
        panel:SetPoint("LEFT", UIParent, "LEFT", 30, 0)
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
