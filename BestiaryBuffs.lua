local _, ns = ...

-- Shared automatic ability storage, plus the outside-combat buff scanner.
-- Cast callers provide direct evidence from a watched NPC, including in combat.
-- The ID window can display secrets; its text is never recording evidence.
function ns.InstallBestiaryBuffs(journal, identify)
    local elapsed = 0
    local onRecorded
    local status = {target="not scanned", mouseover="not scanned"}
    local function public(value) return not (issecretvalue and issecretvalue(value)) end
    local function read(fn, ...)
        if type(fn) ~= "function" then return end
        local ok, value = pcall(fn, ...)
        if ok and public(value) then return value end
    end
    local function number(value)
        return public(value) and type(value) == "number" and value > 0
            and value <= 2147483647 and value == math.floor(value)
    end
    local function slotNumber(value)
        return public(value) and type(value) == "number" and value >= 0
            and value < math.huge and value == math.floor(value)
    end
    local function spellName(value)
        if not public(value) or type(value) ~= "string" then return end
        value = value:gsub("[|%c]", ""):match("^%s*(.-)%s*$")
        if value ~= "" and #value <= 100 and value:lower() ~= "attack" then return value end
    end
    local function auraFields(aura)
        if not public(aura) or type(aura) ~= "table" then return nil, nil, nil, "aura unavailable" end
        if type(canaccesstable) == "function" then
            if read(canaccesstable, aura) ~= true then return nil, nil, nil, "aura access denied" end
        elseif issecrettable and issecrettable(aura) then return nil, nil, nil, "aura access unavailable" end
        local spellID = read(function() return aura.spellId end)
        if not number(spellID) then return nil, nil, nil, "spell ID unreadable or invalid" end
        -- The observed public ID is sufficient to resolve the spell. Optional
        -- aura name/caster fields must not discard that independent evidence.
        local name = spellName(C_Spell and read(C_Spell.GetSpellName, spellID))
            or spellName(read(function() return aura.name end))
        if not name then return nil, nil, nil, "name unavailable for spell ID " .. spellID end
        local source = read(function() return aura.sourceUnit end)
        if source == "" then source = nil end
        return spellID, name, source
    end
    local function record(id, name, spellID, kind)
        local entry = journal.entries[id]
        if not entry or entry.confirmed then return false, "entry locked or unavailable" end
        local creatureName = journal:GetCreatureName(id)
        if not creatureName then return false, "creature name unavailable" end
        local ability = entry.abilities[name]
        if ability and ability.spellID and ability.spellID ~= spellID then return false, "conflicting spell ID" end
        -- Spell IDs deduplicate an existing record even if its name was edited.
        for knownName, known in pairs(entry.abilities) do
            if known.spellID == spellID then
                if known.state == "confirmed" then return false, "already confirmed: spell ID " .. spellID end
                if not ability then name, ability = knownName, known end
            end
        end
        if not ability then
            ability = {}
            entry.abilities[name] = ability
        end
        -- Keep a manually confirmed record's provenance, notes and tooltip choice.
        if ability.state ~= "confirmed" then ability.state, ability.origin = "confirmed", "Automatic " .. kind .. " observation" end
        ability.spellID = spellID
        -- With automatic recording enabled, fresh verified ability evidence
        -- restores removed/rejected abilities, including legacy name dismissals.
        if entry.ignoredAbilities then entry.ignoredAbilities[name] = nil end
        if journal.ResolveRumours then journal:ResolveRumours(id, {kind="ability", value=name, spellID=spellID}) end
        journal:Touch()
        journal:TrackStableContent(id)
        local message = "Automatically recorded: " .. name .. " (Spell ID: " .. spellID .. ") — " .. creatureName
        journal:RecordEvent(message, {kind=kind, creatureID=id, spellID=spellID})
        if onRecorded then onRecorded(message) end
        return true, "recorded spell ID " .. spellID
    end
    function journal:SetAutomaticAbilityRecordedCallback(callback)
        onRecorded = type(callback) == "function" and callback or nil
    end
    function journal:RecordVerifiedCast(id, spellID, observedName)
        if not self:GetAutoRecordAbilities() then return false, "automatic recording disabled" end
        if not number(id) or not number(spellID) then return false, "cast identity unreadable or invalid" end
        local name = spellName(C_Spell and read(C_Spell.GetSpellName, spellID)) or spellName(observedName)
        if not name then return false, "name unavailable for spell ID " .. spellID end
        return record(id, name, spellID, "cast")
    end
    function journal:ReportBuffs(say)
        say("Automatic ability recording: " .. (self:GetAutoRecordAbilities() and "ON" or "OFF"))
        for _, unit in ipairs({"target", "mouseover"}) do say("Automatic buffs " .. unit .. ": " .. status[unit]) end
    end
    function journal:ObserveBuffs(unit)
        if not public(unit) or (unit ~= "target" and unit ~= "mouseover") then return false end
        local function skip(reason) status[unit] = reason; return false end
        if not self:GetAutoRecordAbilities() then return skip("option disabled") end
        if read(InCombatLockdown) ~= false or read(UnitAffectingCombat, "player") ~= false
            or read(UnitAffectingCombat, unit) ~= false or read(UnitIsDead, unit) ~= false then return skip("combat, dead unit or state unavailable") end
        local id = identify(unit)
        if not number(id) or not C_UnitAuras then return skip("NPC or aura API unavailable") end
        if self.entries[id] and self.entries[id].confirmed then return skip("entry locked") end
        if self:Observe(unit) ~= id or self.entries[id].confirmed then return skip("entry locked or identity unavailable") end
        local changed = false
        status[unit] = "no readable buffs found"
        local function accept(aura)
            local spellID, name, source, reason = auraFields(aura)
            if not spellID then status[unit] = reason; return end
            -- Some long-lived NPC buffs have no source token. Retain the fact
            -- that the buff was present, without claiming to have seen a cast.
            if source ~= nil and (type(source) ~= "string" or source == ""
                or (source ~= unit and read(UnitIsUnit, source, unit) ~= true)) then status[unit] = "different caster: spell ID " .. spellID; return end
            local added, result = record(id, name, spellID, "buff")
            status[unit] = result
            if added then changed = true end
        end
        local function scanSlots()
            if type(C_UnitAuras.GetAuraSlots) ~= "function" or type(C_UnitAuras.GetAuraDataBySlot) ~= "function" then return false end
            local function pack(...) return {n=select("#", ...), ...} end
            local token
            for page = 1, 16 do
                local result = pack(pcall(C_UnitAuras.GetAuraSlots, unit, "HELPFUL", 32, token))
                if not result[1] then return false end
                for index = 3, result.n do
                    local slot = result[index]
                    if slotNumber(slot) then accept(read(C_UnitAuras.GetAuraDataBySlot, unit, slot)) end
                end
                token = result[2]
                if not public(token) then return false end
                if token == nil then return true end
                if not slotNumber(token) then return false end
            end
            return false
        end
        if not scanSlots() and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
            for index = 1, 255 do
                local aura = read(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
                if aura == nil then break end
                accept(aura)
            end
        end
        return changed
    end
    function journal:PollBuffs(delta)
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        self:ObserveBuffs("target")
        self:ObserveBuffs("mouseover")
    end
end
