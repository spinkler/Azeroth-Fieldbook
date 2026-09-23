-- Observation-only reimplementation of ClassicBestiary for Forever 1.60.1.
-- Original tooltip concept: Urbit @ Benediction / icheatatlan/ClassicBestiary.
-- No bundled spell list, descriptions, or shared player data.
local addonName, ns = ...
ns = ns or {}
local db
local encounters
local journal, book
local wipeDeadline = 0
local afterWipeHold = false
local skipped = 0
local diagnostics = { events = 0, learned = 0, tooltips = 0, last = "No cast checked yet." }
local probes = {}
local matchedEvents = 0
local tooltipStatus = "No tooltip callback yet."
local frame = CreateFrame("Frame")

local function public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function publicString(value)
    return public(value) and type(value) == "string" and value ~= ""
end

local function positiveID(value)
    return public(value) and type(value) == "number" and value > 0
        and value < math.huge and value == math.floor(value)
end

local function readTrue(fn, ...)
    if not fn then return false end
    local ok, value = pcall(fn, ...)
    return ok and public(value) and value == true
end

-- Never stringify secret values or error payloads, which may contain spell data.
local function valueState(value, kind)
    if not public(value) then return "SECRET" end
    if value == nil then return "MISSING" end
    if kind == "id" then return positiveID(value) and "READABLE" or "INVALID" end
    return publicString(value) and "READABLE" or "INVALID"
end

local function noteProbe(source, status, problem)
    local probe = probes[source] or { samples = 0 }
    probes[source] = probe
    probe.samples = probe.samples + 1
    probe.latest = status
    if problem then probe.problem = status end
end

local function booleanCheck(label, fn, expected, ...)
    if type(fn) ~= "function" then return false, label .. ": API MISSING." end
    local ok, value = pcall(fn, ...)
    if not ok then return false, label .. ": API ERROR (call failed)." end
    if not public(value) then return false, label .. ": SECRET (client prevents inspection)." end
    if type(value) ~= "boolean" then return false, label .. ": MISSING/INVALID boolean result." end
    if value ~= expected then return false, label .. ": " .. (value and "true" or "false") .. " (unit excluded)." end
    return true
end

local function npcID(unit)
    if not publicString(unit) then return nil, "Unit token unavailable." end
    -- Apply ownership checks to both discovery and tooltip display.
    -- Unknown/secret ownership fails closed, including charmed creatures.
    local ownershipOK, reason = booleanCheck("UnitPlayerControlled", UnitPlayerControlled, false, unit)
    if not ownershipOK then return nil, reason end
    if type(UnitGUID) ~= "function" then return nil, "UnitGUID: API MISSING." end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok then return nil, "UnitGUID: API ERROR (call failed)." end
    if not publicString(guid) then return nil, "UnitGUID: " .. valueState(guid) .. "; cannot identify NPC." end
    -- Creature only: never players, pets, or vehicles. Match exact creature ID.
    local id = tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    return id, id and "NPC identity readable." or "Not a Creature GUID."
end

local function watchedEnemy(unit)
    if not publicString(unit) then return nil, "Unit token unavailable/restricted." end
    -- Deliberately exclude focus, bosses, group targets and background nameplates.
    if unit ~= "target" and unit ~= "mouseover" then return nil, "Not target/mouseover." end
    local ok, reason = booleanCheck("UnitExists", UnitExists, true, unit)
    if not ok then return nil, reason end
    ok, reason = booleanCheck("UnitIsVisible", UnitIsVisible, true, unit)
    if not ok then return nil, reason end
    ok, reason = booleanCheck("UnitCanAttack", UnitCanAttack, true, "player", unit)
    if not ok then return nil, reason end
    return npcID(unit)
end

local function say(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffBestiary:|r " .. message)
    end
end

local function spellName(spellID)
    if not C_Spell or type(C_Spell.GetSpellName) ~= "function" then
        noteProbe("C_Spell.GetSpellName", "API MISSING", true)
        return
    end
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    noteProbe("C_Spell.GetSpellName", ok and valueState(name) or "API ERROR", not ok or not publicString(name))
    if ok and publicString(name) then return name end
end

--[[ Disabled: Forever marks combat aura payloads as secret. Addons cannot read
-- their spell names or IDs, so this recorder cannot provide reliable output.
local function announceAddedDebuffs(unit, updateInfo)
    -- Forever blocks the addon combat log. UNIT_AURA is the supported player
    -- aura notification; it exposes no reliable caster identity, so none is
    -- inferred or guessed here.
    if unit ~= "player" or not db or db.debuffAnnouncements ~= true or type(updateInfo) ~= "table" then return end
    local added = updateInfo.addedAuras
    -- A secret table advertises itself as a table, but Lua cannot index or
    -- iterate it. Check the capability before touching it.
    if type(added) ~= "table" then return end
    if type(canaccesstable) == "function" then
        local ok, readable = pcall(canaccesstable, added)
        if not ok or readable ~= true then return end
    elseif type(issecrettable) == "function" then
        local ok, secret = pcall(issecrettable, added)
        if not ok or secret == true then return end
    end
    for _, aura in ipairs(added) do
        local readable = type(aura) == "table"
        if readable and type(canaccesstable) == "function" then
            local ok, allowed = pcall(canaccesstable, aura)
            readable = ok and allowed == true
        elseif readable and type(issecrettable) == "function" then
            local ok, secret = pcall(issecrettable, aura)
            readable = ok and secret ~= true
        end
        if readable and aura.isHarmful == true
            and publicString(aura.name) and positiveID(aura.spellId) and #pendingDebuffMessages < 20 then
            pendingDebuffMessages[#pendingDebuffMessages + 1] = "Debuff observed: " .. aura.name
                .. " (Spell ID: " .. aura.spellId .. ")."
        end
    end
end
]]

local function storeObserved(id, spellID, observedName)
    if not db or not positiveID(id) then return end
    local hasID = positiveID(spellID)
    local hasName = publicString(observedName)
    if not hasID then
        skipped = skipped + 1
        if not hasName then
            diagnostics.last = "Cannot record: spell ID " .. valueState(spellID, "id")
                .. ", observed name " .. valueState(observedName) .. "."
            return
        end
    end
    -- Called only with direct cast evidence or attributed encounter records.
    local name = hasName and observedName or spellName(spellID)
    if not name then diagnostics.last = "Observed spell name unavailable."; return end
    if journal then journal:Offer(id, name, "Automatic observation", spellID) end
    local creature = db.creatures[id]
    if not creature then
        creature = { spells = {} }
        db.creatures[id] = creature
    end
    -- A directly observed, public cast name is sufficient evidence. Never guess
    -- a hidden ID by searching spell data. No secret values enter SavedVariables.
    creature.names = creature.names or {}
    if hasID then
        if creature.spells[spellID] then diagnostics.last = "Cast already recorded."; return end
        local knownByName = creature.names[name]
        creature.names[name] = nil
        creature.spells[spellID] = { name = name }
        if knownByName then diagnostics.last = "Observed name now has a readable ID."; return end
    else
        for _, record in pairs(creature.spells) do
            if type(record) == "table" and record.name == name then
                diagnostics.last = "Cast already recorded."
                return
            end
        end
        if creature.names[name] then diagnostics.last = "Cast already recorded."; return end
        creature.names[name] = true
    end
    diagnostics.learned = diagnostics.learned + 1
    diagnostics.last = "Cast recorded."
    if db.announce then say("Observed: " .. name) end
    return true
end

local function remember(unit, spellID, observedName)
    if afterWipeHold then return end
    local id, reason = watchedEnemy(unit)
    if not id then diagnostics.last = reason; return end
    return storeObserved(id, spellID, observedName)
end

local function observeCurrent(unit)
    if afterWipeHold then return end
    if not db or not watchedEnemy(unit) then return end
    if journal then journal:Observe(unit) end
    local function inspect(label, fn, channel)
        local source = unit .. " " .. label
        if type(fn) ~= "function" then
            noteProbe(source, "API MISSING", true)
            diagnostics.last = source .. ": API MISSING."
            return
        end
        local ok, name, _, _, _, _, _, _, eighth, ninth = pcall(fn, unit)
        if not ok then
            noteProbe(source, "API ERROR (pcall failed)", true)
            diagnostics.last = source .. ": API ERROR; this does not establish a secret value."
            return
        end
        local spellID
        if channel then spellID = eighth else spellID = ninth end
        local nameState, idState = valueState(name), valueState(spellID, "id")
        if nameState == "MISSING" and idState == "MISSING" then
            noteProbe(source, "IDLE (no active cast returned)", false)
            return
        end
        local status = "name " .. nameState .. "; ID " .. idState
        noteProbe(source, status, nameState ~= "READABLE" or idState ~= "READABLE")
        if publicString(name) or positiveID(spellID) then
            remember(unit, spellID, name)
        else
            diagnostics.last = source .. ": " .. status .. "; neither field identifies the spell."
        end
    end
    inspect("UnitCastingInfo", UnitCastingInfo, false)
    inspect("UnitChannelInfo", UnitChannelInfo, true)
end

local function addTooltip(tooltip)
    if not db or tooltip ~= GameTooltip then return end
    diagnostics.tooltips = diagnostics.tooltips + 1
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok then tooltipStatus = "GetUnit: API ERROR."; return end
    if not publicString(unit) then tooltipStatus = "GetUnit token: " .. valueState(unit) .. "."; return end
    local id, reason = npcID(unit)
    if not id then tooltipStatus = reason; return end
    local creature = id and db.creatures[id]
    if journal then
        local names = journal:ConfirmedNames(id)
        if #names == 0 then tooltipStatus = "No confirmed abilities: review this entry in /bestiary book."; return end
        tooltip:AddLine("Bestiary - confirmed abilities", 0.5, 0.82, 1)
        for _, name in ipairs(names) do tooltip:AddLine(name, 1, 1, 1, true) end
        tooltipStatus = "Added " .. #names .. " confirmed ability names."
        return
    end
    if not creature then tooltipStatus = "Eligible NPC, but no saved observations for this creature ID."; return end
    local names, seen = {}, {}
    local function include(name)
        if publicString(name) and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    for spellID, record in pairs(creature.spells) do
        if positiveID(spellID) and type(record) == "table" and publicString(record.name) then
            include(record.name)
        end
    end
    for name in pairs(creature.names or {}) do include(name) end
    if #names == 0 then tooltipStatus = "NPC record contains no displayable observed names."; return end
    tooltipStatus = "Added " .. #names .. " observed ability names."
    table.sort(names)
    tooltip:AddLine("Experienced abilities", 0.5, 0.82, 1)
    for _, name in ipairs(names) do
        tooltip:AddLine(name, 1, 1, 1, true)
    end
end

local function addSpellIDTooltip(tooltip, tooltipData)
    -- Forever's native aura-tooltip CVar provides the correct ID for aura
    -- tooltips. Retain this callback only as a fallback for clients without it.
    if type(GetCVarBool) == "function" then return end
    if not db or db.showSpellIDs ~= true or type(tooltipData) ~= "table" then return end
    local spellID = tooltipData.id
    if not positiveID(spellID) or not tooltip or type(tooltip.AddLine) ~= "function" then return end
    tooltip:AddLine("Spell ID: " .. spellID, 1.00, 0.82, 0.20)
end

local function initialize()
    -- Distinct saved-variable name; never import the original scraped database.
    if type(ClassicBestiaryObservedDB) ~= "table" or ClassicBestiaryObservedDB.version ~= 1 then
        ClassicBestiaryObservedDB = { version = 1, creatures = {}, announce = false }
    end
    db = ClassicBestiaryObservedDB
    if type(db.creatures) ~= "table" then db.creatures = {} end
    if type(db.creatureAnnouncements) ~= "boolean" then db.creatureAnnouncements = true end
    if db.spellIDTooltipInitialized ~= true then
        db.showSpellIDs, db.spellIDTooltipInitialized = true, true
        if type(SetCVar) == "function" then pcall(SetCVar, "tooltipShowAuraSpellIDs", "1") end
    elseif type(db.showSpellIDs) ~= "boolean" then
        db.showSpellIDs = true
    end
    -- Discard malformed saved entries rather than trying to infer missing data.
    for id, creature in pairs(db.creatures) do
        if not positiveID(id) or type(creature) ~= "table" or type(creature.spells) ~= "table" then
            db.creatures[id] = nil
        elseif type(creature.names) ~= "table" then
            creature.names = {}
        end
    end
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, addTooltip)
        if Enum.TooltipDataType.Spell then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, addSpellIDTooltip)
        end
    elseif GameTooltip and GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit", addTooltip)
    end
    if ns.CreateJournal then journal = ns.CreateJournal(db, watchedEnemy) end
    if journal then
        journal:SetEntryAddedCallback(function(entry)
            if journal:GetCreatureAnnouncement() then
                say("New bestiary entry: " .. entry.name .. " (" .. entry.category .. ").")
            end
        end)
    end
    if journal and ns.CreateBook then book = ns.CreateBook(journal) end
    if ns.CreateEncounterReader then encounters = ns.CreateEncounterReader(storeObserved) end
    if encounters and db.ignoreEncounterHistory then encounters:ForgetHistory() end
end

local bindingReminderShown = false
local function remindAboutUnboundBookKey()
    if bindingReminderShown or type(GetBindingKey) ~= "function" then return end
    bindingReminderShown = true
    local primary, secondary = GetBindingKey("CLASSICBESTIARY_BOOK")
    if not primary and not secondary then
        say("The Bestiary book has no keybinding. Bind it in Options > Keybindings.")
    end
end

function ClassicBestiaryToggleBook()
    if book then book:Toggle() end
end

function ClassicBestiaryOpenMouseoverBook()
    if book then book:OpenAtUnit("mouseover") end
end

local function watchedAlias(unit)
    if not publicString(unit) then return end
    if unit == "target" or unit == "mouseover" then return unit end
    -- A nameplate/boss token may refer to our target. Require a readable match;
    -- this never admits unrelated background enemies.
    for _, watched in ipairs({ "target", "mouseover" }) do
        if readTrue(UnitIsUnit, unit, watched) then return watched end
    end
end

frame:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if encounters then encounters:Event(event) end
    if event == "ADDON_LOADED" then
        if unit == addonName then initialize() end
    elseif event == "PLAYER_LOGIN" then
        remindAboutUnboundBookKey()
    elseif event == "PLAYER_TARGET_CHANGED" then
        afterWipeHold = false
        observeCurrent("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        afterWipeHold = false
        observeCurrent("mouseover")
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_EMPOWER_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- START counts even if interrupted later: the enemy was seen attempting it.
        -- SUCCEEDED captures instant casts without inferring from damage or auras.
        diagnostics.events = diagnostics.events + 1
        local watched = watchedAlias(unit)
        if watched then
            matchedEvents = matchedEvents + 1
            local state = valueState(spellID, "id")
            noteProbe("Matched cast event", "spell ID " .. state, state ~= "READABLE")
            remember(watched, spellID)
            -- Use the actual active cast name if the spell cache is not ready.
            observeCurrent(watched)
        elseif not publicString(unit) then
            noteProbe("Unmatched event unit", valueState(unit), true)
            diagnostics.last = "Event unit " .. valueState(unit) .. "; cannot associate with target/mouseover."
        end
    end
end)

-- Catch readable, ongoing casts even if their start event was not delivered for
-- target/mouseover. Never scan spell lists or inspect completed/hidden casts.
local elapsedSinceScan = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    if encounters then encounters:Update(elapsed) end
    elapsedSinceScan = elapsedSinceScan + elapsed
    if elapsedSinceScan < 0.2 then return end
    elapsedSinceScan = 0
    observeCurrent("target")
    observeCurrent("mouseover")
end)

for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET" }) do
    frame:RegisterEvent(event)
end

SLASH_CLASSICBESTIARYOBSERVED1 = "/bestiary"
SlashCmdList.CLASSICBESTIARYOBSERVED = function(message)
    if not db then return end
    local command = message:lower():match("^%s*(.-)%s*$"):gsub("%s+", " ")
    if command == "wipe" or command == "reset" or command == "reset confirm" then
        wipeDeadline = GetTime() + 60
        say("WARNING: wipe permanently deletes ALL of this character's bestiary entries, abilities, notes, damage records and settings.")
        say("Command 1/2 accepted. Type /bestiary wipe confirm within 60 seconds to permanently delete it.")
    elseif command == "wipe confirm" then
        if wipeDeadline == 0 or GetTime() > wipeDeadline then
            wipeDeadline = 0; say("No active wipe request. Start with /bestiary wipe."); return
        end
        wipeDeadline = 0
        for key in pairs(db) do db[key] = nil end
        db.version, db.creatures, db.announce, db.creatureAnnouncements = 1, {}, false, true
        db.showSpellIDs, db.spellIDTooltipInitialized = true, true
        if type(SetCVar) == "function" then pcall(SetCVar, "tooltipShowAuraSpellIDs", "1") end
        -- Prevent retained meter history from silently restoring wiped knowledge
        -- after reload. New sessions after each load can still be learned.
        db.ignoreEncounterHistory = true
        if journal then journal:Reset() end
        if encounters then encounters:ForgetHistory() end
        if book then book:Refresh() end
        afterWipeHold = true
        say("This character's entire bestiary has been wiped. Retarget an NPC to begin again.")
    elseif command == "wipe cancel" then
        wipeDeadline = 0
        say("Wipe cancelled. Nothing deleted.")
    elseif command == "" or command == "book" then
        if book then book:Toggle() else say("Book module unavailable; reload the UI.") end
    elseif command == "encounters" then
        if encounters then encounters:Report(say) else say("Encounter module unavailable.") end
    elseif command == "scan" then
        if encounters then encounters:Scan(); encounters:Report(say) else say("Encounter module unavailable.") end
    elseif command == "debug" then
        say("Version 0.6.14; all cast events: " .. diagnostics.events .. "; new observations: " .. diagnostics.learned
            .. "; tooltip callbacks: " .. diagnostics.tooltips)
        say("Last cast check: " .. diagnostics.last)
        say("Events matched to target/mouseover: " .. matchedEvents .. ". All-event count includes unrelated units.")
        say("Last tooltip: " .. tooltipStatus)
        if encounters then say("Encounter learning: " .. encounters.status .. " (/bestiary encounters for details)") end
        for _, unit in ipairs({ "target", "mouseover" }) do
            local id, reason = watchedEnemy(unit)
            say(unit .. ": " .. (id and "eligible NPC" or reason))
        end
        local keys = {}
        for key in pairs(probes) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local probe = probes[key]
            say(key .. ": " .. probe.latest .. " [" .. probe.samples .. " checks]")
            if probe.problem and probe.problem ~= probe.latest then
                say("  Earlier non-readable result: " .. probe.problem)
            end
        end
        if #keys == 0 then say("No eligible NPC cast API checks yet. Target an enemy and witness a cast.") end
        say("SECRET = issecretvalue confirmed hidden data. UI may display it, but this addon cannot inspect it.")
        say("API ERROR = call threw an error; it may be an API/access problem, not necessarily secret data.")
        say("MISSING/INVALID = no usable value. API MISSING = function absent. IDLE is normal between casts.")
        say("Readable name OR ID can identify a spell; NPC identity must also pass. Checks are samples, not unique casts.")
        say("Earlier results are session-wide, may belong to a previous target, and survive idle polls until /reload.")
        say("Equal-hit automation unavailable: Forever blocks addon combat-log events; C_DamageMeter exposes totals, not individual hits or crit flags.")
    elseif command == "alerts" then
        db.announce = not db.announce
        say(db.announce and "Discovery messages on." or "Discovery messages off.")
    else
        local creatures, spells = 0, 0
        for _, creature in pairs(db.creatures) do
            creatures = creatures + 1
            for _ in pairs(creature.spells) do spells = spells + 1 end
            for _ in pairs(creature.names or {}) do spells = spells + 1 end
        end
        say(creatures .. " creatures; " .. spells .. " observed creature/ability pairs.")
        say("Learns from direct NPC casts and readable post-combat records, including party encounters.")
        if encounters then say("Encounter learning: " .. encounters.status) end
        say("Unreadable spell IDs this session: " .. skipped .. " (readable active cast names can still be learned).")
        say("/bestiary debug explains discovery checks (no hidden spell data).")
        say("/bestiary alerts toggles discovery messages; /bestiary wipe starts the double-confirmed wipe.")
        say("/bestiary book opens the field guide; confirm entries and add your own ability notes there.")
    end
end
