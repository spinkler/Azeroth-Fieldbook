local _, ns = ...

-- Player LOC is the observation. Only a matching player aura supplies automatic
-- source evidence. Never retain a source unit token for use on a later event.
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function read(fn, ...)
    if type(fn) ~= "function" then return nil, "API MISSING" end
    local ok, value = pcall(fn, ...)
    if not ok then return nil, "API ERROR" end
    if not public(value) then return nil, "SECRET" end
    if value == nil then return nil, "MISSING" end
    return value, "READABLE"
end
local function accessible(value)
    if not public(value) or type(value) ~= "table" then return false end
    if type(canaccesstable) == "function" then return read(canaccesstable, value) == true end
    if type(issecrettable) == "function" then return read(issecrettable, value) == false end
    return true
end
local function field(value, key)
    return read(function() return value[key] end)
end
local function integer(value, minimum)
    return public(value) and type(value) == "number" and value >= minimum
        and value <= 2147483647 and value == math.floor(value)
end
local function finite(value)
    return public(value) and type(value) == "number" and value >= 0 and value < math.huge
end
local function text(value)
    if not public(value) or type(value) ~= "string" then return end
    value = value:gsub("[|%c]", ""):match("^%s*(.-)%s*$")
    if value ~= "" then return value:sub(1, 160) end
end

function ns.CreateLossOfControlObserver(journal, identify, say)
    local observer = {}
    local seen, sequence = {}, 0
    local counts, history = {}, {}
    local status = "No player Loss of Control event received."
    local function trace(line)
        status = line
        if history[#history] == line then return end
        history[#history + 1] = line
        if #history > 12 then table.remove(history, 1) end
    end
    local function source(aura, auraID)
        if not accessible(aura) then return nil, nil, nil, "aura inaccessible/missing" end
        local instance, instanceState = field(aura, "auraInstanceID")
        if not integer(instance, 1) or instance ~= auraID then return nil, nil, nil, "aura identity " .. instanceState .. "/mismatch" end
        local unit, unitState = field(aura, "sourceUnit")
        if not text(unit) then return nil, nil, nil, "sourceUnit " .. unitState end
        local guid, guidState = read(UnitGUID, unit)
        if not text(guid) then return nil, nil, nil, "source GUID " .. guidState end
        local id, reason = identify(unit, false, guid)
        if not integer(id, 1) then return nil, nil, nil, "source excluded: " .. (reason or "invalid NPC") end
        return unit, guid, id, "sourceUnit=" .. text(unit) .. "; NPC=" .. id
    end
    local function targetSnapshot(spellID)
        local guid = read(UnitGUID, "target")
        if not text(guid) then return end
        local id = identify("target", false, guid)
        if not integer(id, 1) then return end
        local name = text(read(UnitName, "target"))
        local level = read(type(UnitEffectiveLevel) == "function" and UnitEffectiveLevel or UnitLevel, "target")
        if not name or #name > 100 or read(UnitGUID, "target") ~= guid then return end
        local entries, entry = journal.entries, journal.entries[id]
        local candidate = { id=id, guid=guid, name=name, level=integer(level, 1) and level or nil }
        -- Read-only until the user clicks. Neither a target nor its combat state
        -- proves the source, and subsequent target changes must not retarget this.
        candidate.assign = function()
            if ns.InitializationBlocked or journal.entries ~= entries or entry and journal.entries[id] ~= entry then
                say("This observation is no longer available after the Bestiary changed.")
                return false
            end
            local current = journal.entries[id]
            if current and current.confirmed then
                say("Unlock " .. name .. " in the Bestiary before assigning this ability.")
                return false
            end
            if not current then journal:Ensure(id, false, name) end
            entry = journal.entries[id]
            local _, result, saved = journal:AssignObservedLossOfControl(id, spellID)
            if saved then say("Ability assigned: Spell ID " .. spellID .. " — " .. name .. ".")
            else say("Ability assignment failed: " .. result .. ".") end
            return saved == true
        end
        return candidate
    end
    local function additions(updates)
        local result = {}
        if not accessible(updates) then return result end
        -- Full updates discard event-local additions and use exact-instance queries.
        if field(updates, "isFullUpdate") == true then return result end
        local added = field(updates, "addedAuras")
        if not accessible(added) then return result end
        for index = 1, 255 do
            local aura, auraState = field(added, index)
            if aura == nil and auraState == "MISSING" then break end
            if accessible(aura) then
                local instance = field(aura, "auraInstanceID")
                if integer(instance, 1) then result[instance] = aura end
            end
        end
        return result
    end
    local function observe(data, payload, occurrences, at, dataState)
        if not accessible(data) then trace("LOC data " .. dataState .. "; table inaccessible/missing"); return false end
        local spellID, spellState = field(data, "spellID")
        if not integer(spellID, 1) then trace("LOC spell ID " .. spellState .. "/invalid; deferred"); return false end
        -- locType is a label, never an acceptance whitelist.
        local locType, typeState = field(data, "locType")
        local label = text(field(data, "displayText")) or text(locType) or "Loss of Control"
        local auraID, auraState = field(data, "auraInstanceID")
        auraID = integer(auraID, 1) and auraID or nil
        local start, duration, school = field(data, "startTime"), field(data, "duration"), field(data, "lockoutSchool")
        local key
        if auraID then key = "aura:" .. auraID
        else
            key = table.concat({"effect", spellID, text(locType) or "unknown",
                finite(start) and tostring(start) or "?", finite(duration) and tostring(duration) or "?",
                integer(school, 0) and tostring(school) or "?"}, ":")
            -- Distinguish simultaneous identical no-aura effects without relying
            -- on their changing active-list index or timeRemaining.
            occurrences[key] = (occurrences[key] or 0) + 1
            key = key .. ":" .. occurrences[key]
        end
        local state = seen[key]
        if state and state.absentAt and at - state.absentAt > 2 then state = nil end
        if not state then
            sequence = sequence + 1
            state = { token = "loc:" .. sequence, candidate = targetSnapshot(spellID) }
            seen[key] = state
        end
        state.at, state.absentAt, state.active = at, nil, true
        local name = text(C_Spell and read(C_Spell.GetSpellName, spellID))
        local reason, caster = "no readable aura instance (" .. auraState .. ")", state.caster
        local recordingDisabled = not journal:GetAutoRecordAbilities()
        if not state.saved and auraID then
            local aura, queryState = payload[auraID], "UNIT_AURA addition"
            if not aura then aura, queryState = read(C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID, "player", auraID) end
            local unit, guid, id, sourceState = source(aura, auraID)
            reason = queryState .. "; " .. sourceState
            if id then
                if recordingDisabled then reason = "automatic recording disabled"
                elseif journal:Observe(unit, false, guid) ~= id then reason = "source discovery unavailable/identity changed"
                else
                    -- Recheck the exact identity immediately before persisting.
                    local current = identify(unit, false, guid)
                    if current == id and read(UnitGUID, unit) == guid then
                        local _, result, saved = journal:RecordPlayerLossOfControl(id, spellID)
                        reason = result
                        if saved then
                            state.saved = true
                            caster = journal:GetCreatureName(id)
                            state.caster = caster
                        end
                    else reason = "source identity changed before recording" end
                end
                reason = queryState .. "; " .. sourceState .. "; " .. reason
            end
        end
        if not state.displayed or state.saved and not state.displayedSaved then
            if ns.SpellIDWindow and ns.SpellIDWindow.ObserveLossOfControl then
                state.displayed = ns.SpellIDWindow:ObserveLossOfControl(spellID, name, label, caster, state.token,
                    not state.saved and state.candidate or nil)
                state.displayedSaved = state.saved
            end
        end
        if not state.saved and not state.notified then
            local spell = name and (name .. " (Spell ID " .. spellID .. ")") or ("Spell ID " .. spellID)
            local explanation = recordingDisabled and "Automatic recording is disabled."
                or "Source could not be identified safely."
            say("Loss of Control detected — " .. label .. " — " .. spell .. ". " .. explanation .. " Add the spell manually once identified.")
            state.notified = true
        end
        local result = "locType=" .. (text(locType) or typeState) .. "; spellID=" .. spellID
            .. "; auraInstanceID=" .. (auraID or auraState) .. "; " .. (state.saved and "attributed" or "unattributed")
        -- Retain useful source/access diagnostics across repeated updates.
        if not state.saved or not state.tracedSaved then
            trace(result .. "; " .. reason)
            state.tracedSaved = state.saved
        end
        return true
    end
    function observer:Event(event, unit, second)
        if ns.InitializationBlocked then return end
        local updates, addedIndex
        if event == "UNIT_AURA" then
            if not public(unit) or unit ~= "player" then return end
            updates = second
        elseif event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then
            if not public(unit) then return end
            -- Forever 70170 supplies unitTarget first. Older index-only ADDED
            -- and payload-free UPDATE can still use the player-only getters.
            if type(unit) == "string" and unit ~= "player" then return end
            addedIndex = integer(second, 1) and second or (integer(unit, 1) and unit or nil)
        elseif event ~= "PLAYER_ENTERING_WORLD" and event ~= "PLAYER_LOGIN" and event ~= "PLAYER_REGEN_ENABLED" then return end
        counts[event] = (counts[event] or 0) + 1
        local at = read(GetTime)
        at = finite(at) and at or 0
        local count, countState = read(C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount)
        local payload, occurrences = additions(updates), {}
        for _, state in pairs(seen) do state.active = false end
        local complete = true
        local function accept(index)
            local data, dataState = read(C_LossOfControl and C_LossOfControl.GetActiveLossOfControlData, index)
            if not observe(data, payload, occurrences, at, dataState) then complete = false end
        end
        if integer(count, 0) and count <= 255 then
            for index = 1, count do
                accept(index)
            end
        elseif addedIndex then
            accept(addedIndex)
            complete = false
        else trace("LOC count " .. countState .. "/unavailable"); return end
        -- Session-only cache: active applications remain, absent ones have a
        -- two-second grace period for event ordering; no permanent suppression.
        local size, oldestKey, oldest = 0, nil, math.huge
        for key, state in pairs(seen) do
            if complete and not state.active then state.absentAt = state.absentAt or at end
            if at < state.at or state.absentAt and at - state.absentAt > 2 then seen[key] = nil
            else
                size = size + 1
                if state.at < oldest then oldest, oldestKey = state.at, key end
            end
        end
        while size > 512 and oldestKey do
            seen[oldestKey], size = nil, size - 1
            oldestKey, oldest = nil, math.huge
            for key, state in pairs(seen) do
                if state.at < oldest then oldest, oldestKey = state.at, key end
            end
        end
    end
    function observer:Report(output)
        output("Player Loss of Control: " .. status)
        output("LOC events ADDED=" .. (counts.LOSS_OF_CONTROL_ADDED or 0) .. "; UPDATE=" .. (counts.LOSS_OF_CONTROL_UPDATE or 0)
            .. "; player UNIT_AURA=" .. (counts.UNIT_AURA or 0))
        for _, line in ipairs(history) do output("  LOC " .. line) end
    end
    return observer
end
