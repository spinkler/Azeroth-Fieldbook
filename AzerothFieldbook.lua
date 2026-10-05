-- Azeroth Fieldbook Bestiary section for Forever 1.60.1.
-- Original monster-tooltip concept by Urbit @ Benediction.
-- No bundled spell list or creature database. Sharing requires explicit acceptance.
local addonName, ns = ...
ns = ns or {}
-- The observer also supports running without the optional journal module.
local applySpellIDTooltipPreference = ns.ApplySpellIDTooltipPreference or function(settings)
    if type(settings.showSpellIDs) ~= "boolean" then settings.showSpellIDs = true end
    settings.spellIDTooltipInitialized = nil
    if type(GetCVarBool) == "function" then
        local ok, enabled = pcall(GetCVarBool, "tooltipShowAuraSpellIDs")
        if ok and enabled == (settings.showTooltips ~= false and settings.showSpellIDs) then return end
    end
    if type(SetCVar) == "function" then
        pcall(SetCVar, "tooltipShowAuraSpellIDs", (settings.showTooltips ~= false and settings.showSpellIDs) and "1" or "0")
    end
end
local db, trackingDB
local encounters
local journal, book, fieldbook, ledgerBook, gatheringBook, lossOfControl
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
    return id, id and "NPC identity readable." or "Not a Creature GUID.", guid
end

local function watchedEnemy(unit, explicit, sourceGUID)
    if not publicString(unit) then return nil, "Unit token unavailable/restricted." end
    -- Effect sources and manual portrait snapshots supply an exact, public GUID.
    -- Keep ordinary target/mouseover discovery limits unchanged.
    local effectSource = publicString(sourceGUID)
    -- Deliberately exclude focus, bosses, group targets and background nameplates.
    if not effectSource and unit ~= "target" and unit ~= "mouseover" then return nil, "Not target/mouseover." end
    if not effectSource and unit == "mouseover" and not explicit then
        -- Taxi flights do not necessarily report IsFlying. Explicit targets
        -- remain observable from either kind of flight.
        for _, flight in ipairs({{UnitOnTaxi, "player"}, {IsFlying}}) do
            if type(flight[1]) == "function" then
                local ok, value = pcall(flight[1], flight[2])
                if not ok or not public(value) or value ~= false then
                    return nil, "Mouseover discovery excluded while flying or flight state unavailable."
                end
            end
        end
    end
    local ok, reason = booleanCheck("UnitExists", UnitExists, true, unit)
    if not ok then return nil, reason end
    -- An explicitly selected creature can be outside the render/visibility
    -- range while flying. Its readable identity and attackability still count.
    if not explicit then
        ok, reason = booleanCheck("UnitIsVisible", UnitIsVisible, true, unit)
        if not ok then return nil, reason end
    end
    ok, reason = booleanCheck("UnitCanAttack", UnitCanAttack, true, "player", unit)
    if not ok then return nil, reason end
    local id, identityReason, identityGUID = npcID(unit)
    if effectSource then
        local success, guid = pcall(UnitGUID, unit)
        if identityGUID ~= sourceGUID or not success or not publicString(guid) or guid ~= sourceGUID then
            return nil, "Aura source identity changed/unavailable."
        end
    end
    return id, identityReason
end

local function say(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAFB:|r " .. message)
    end
end

local function announceBestiary(entry, title, amount, observation, categoryOnly, chatEnabled, skipLog)
    local name = journal:GetCreatureName(entry.id)
    if not name then return end
    local basic = journal.GetBasicInfo and journal:GetBasicInfo(entry.id) or entry
    observation = observation or {}
    local category = observation.category or basic.category
    local details = { publicString(category) and category:gsub("[|%c]", "") or "Unclassified" }
    if not categoryOnly then
        if positiveID(observation.level) then details[#details + 1] = "Lvl" .. observation.level end
        if publicString(observation.location) then details[#details + 1] = observation.location end
    end
    local reward = amount and ("+" .. amount .. " knowledge: ") or ""
    local text="|cffffd100[" .. reward .. title .. "]|r |cff80d0ffBestiary:|r |cffffffff" .. name
        .. "|r |cff999999(" .. table.concat(details, " • ") .. ")|r"
    if not skipLog then journal:RecordEvent(text,{creatureID=entry.id,title=title,points=amount,level=observation.level,location=observation.location}) end
    if chatEnabled then say(text) end
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

local function storeObserved(id, spellID, observedName, creatureName)
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
    if name:match("^%s*(.-)%s*$"):lower() == "attack" then
        diagnostics.last = "Basic Attack ignored."
        return
    end
    if journal and not journal:Offer(id, name, "Automatic observation", spellID, creatureName) then
        local entry = journal.entries[id]
        diagnostics.last = entry and entry.confirmed and "Creature locked; observation not recorded."
            or "Creature identity unavailable or observation excluded; nothing recorded."
        return
    end
    local creature = trackingDB.bestiary.creatures[id]
    if not creature then
        creature = { spells = {} }
        trackingDB.bestiary.creatures[id] = creature
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
    if journal then journal:RecordEvent("Observed: " .. name,{kind="cast",creatureID=id}) end
    if db.spellFeedback == true then say("Observed: " .. name) end
    return true
end

local function remember(unit, spellID, observedName, castBarID)
    if afterWipeHold then return end
    local id, reason = watchedEnemy(unit)
    if not id then diagnostics.last = reason; return end
    -- Instant cast events may arrive before target/mouseover discovery. Resolve
    -- the watched unit's identity before either observation store is written.
    if journal then journal:Observe(unit) end
    if journal and journal.DetectAbility then journal:DetectAbility(id,spellID,observedName,castBarID) end
    -- Only fresh, directly attributed casts qualify for automatic confirmation.
    -- Historical encounter imports and readable names without an ID stay pending.
    -- Public spell IDs may be usable in combat. The storage path never looks
    -- up a secret ID; the separate hint above only relays it for display.
    if journal and journal.RecordVerifiedCast and journal:GetAutoRecordAbilities() and positiveID(spellID) then
        local added, reason = journal:RecordVerifiedCast(id, spellID, observedName)
        diagnostics.last = "Automatic cast: " .. reason
        if added then diagnostics.learned = diagnostics.learned + 1 end
        return added
    end
    return storeObserved(id, spellID, observedName)
end

local function observeCurrent(unit, explicit)
    if afterWipeHold then return end
    if not db then return end
    if journal then journal:RecordKill(unit) end
    if not watchedEnemy(unit, explicit) then return end
    if journal then journal:Observe(unit, explicit) end
    local castPresent=false
    local function inspect(label, fn, channel)
        local source = unit .. " " .. label
        if type(fn) ~= "function" then
            noteProbe(source, "API MISSING", true)
            diagnostics.last = source .. ": API MISSING."
            return
        end
        local ok, name, _, _, _, _, _, _, eighth, ninth, tenth, eleventh = pcall(fn, unit)
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
        castPresent=true
        local status = "name " .. nameState .. "; ID " .. idState
        noteProbe(source, status, nameState ~= "READABLE" or idState ~= "READABLE")
        local castBarID=tenth
        if channel then castBarID=eleventh end
        remember(unit, spellID, name, castBarID)
        if not publicString(name) and not positiveID(spellID) then
            diagnostics.last = source .. ": " .. status .. "; neither field identifies the spell."
        end
    end
    inspect("UnitCastingInfo", UnitCastingInfo, false)
    inspect("UnitChannelInfo", UnitChannelInfo, true)
    if not castPresent and journal and journal.FinishDetectedCast then
        local id=watchedEnemy(unit)
        if id then journal:FinishDetectedCast(id) end
    end
end

-- Display metadata is requested only for saved, visible, confirmed abilities.
-- Never persist descriptions or inspect restricted spell values.
local tooltipCreatureID, refreshingTooltip
local function spellDisplay(ability)
    if not ability or not positiveID(ability.spellID) then return end
    local icon, description
    local iconAPI = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
    if type(iconAPI) == "function" then
        local ok, value = pcall(iconAPI, ability.spellID)
        if ok and (positiveID(value) or publicString(value)) then icon = value end
    end
    local descriptionAPI = C_Spell and C_Spell.GetSpellDescription or GetSpellDescription
    if type(descriptionAPI) == "function" then
        local ok, value = pcall(descriptionAPI, ability.spellID)
        if ok and publicString(value) then description = value end
    end
    return icon, description
end

local function refreshAbilityTooltip()
    local tooltip = GameTooltip
    if refreshingTooltip or not tooltipCreatureID or not tooltip
        or not readTrue(tooltip.IsShown, tooltip) or type(tooltip.SetUnit) ~= "function" then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or not publicString(unit) or npcID(unit) ~= tooltipCreatureID then return end
    -- Rebuild the native unit tooltip so Ctrl changes cannot append duplicate lines.
    refreshingTooltip = true
    pcall(tooltip.SetUnit, tooltip, unit)
    refreshingTooltip = false
end

local function addTooltip(tooltip)
    if not db or tooltip ~= GameTooltip then return end
    tooltipCreatureID = nil
    if db.showTooltips == false then tooltipStatus = "Fieldbook tooltips disabled."; return end
    diagnostics.tooltips = diagnostics.tooltips + 1
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok then tooltipStatus = "GetUnit: API ERROR."; return end
    if not publicString(unit) then tooltipStatus = "GetUnit token: " .. valueState(unit) .. "."; return end
    local id, reason = npcID(unit)
    if not id then tooltipStatus = reason; return end
    local creature = id and trackingDB.bestiary.creatures[id]
    if journal then
        journal:ObserveTameability(unit)
        local names = journal:ConfirmedNames(id)
        local behaviours = journal:GetBehaviourTooltips() and journal:TooltipBehaviours(id) or {}
        local _,_,kills=journal:GetKillReward(id)
        local showKills=journal:GetKillCountTooltips() and journal.entries[id]~=nil and kills>0
        if #names == 0 and #behaviours == 0 and not showKills then tooltipStatus = "No selected tooltip facts: review this entry in /fieldbook."; return end
        local expanded = readTrue(IsControlKeyDown)
        local hasDetails = false
        for _, name in ipairs(names) do
            local icon, description = spellDisplay(journal.entries[id].abilities[name])
            local label = icon and ("|T" .. icon .. ":16:16:0:0|t " .. name) or name
            tooltip:AddLine(label, 1, 1, 1, true)
            if description then
                hasDetails = true
                if expanded then tooltip:AddLine(description, 1, 0.82, 0.14, true) end
            end
        end
        if #names > 0 then tooltipCreatureID = id end
        if hasDetails and not expanded then
            tooltip:AddLine("(Ctrl for details)", 0.6, 0.6, 0.6, true)
        end
        if #behaviours>0 then
            tooltip:AddLine(table.concat(behaviours, ", "),0.72,0.80,0.72,true)
        end
        if showKills then
            tooltip:AddLine("Kills: " .. kills,1,0.82,0.14)
        end
        tooltipStatus = "Added " .. #names .. " confirmed ability names and " .. #behaviours .. " behaviour traits" .. (showKills and " and kill count." or ".")
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
    if not db or db.showTooltips == false or db.showSpellIDs ~= true or type(tooltipData) ~= "table" then return end
    local spellID = tooltipData.id
    if not positiveID(spellID) or not tooltip or type(tooltip.AddLine) ~= "function" then return end
    tooltip:AddLine("Spell ID: " .. spellID, 1.00, 0.82, 0.20)
end

-- This preflight must precede every initializer: Tracking allocates import keys,
-- and journal/UI setup can normalize saved data even before the first event.
-- A missing marker is not evidence of a supported legacy format.
local function supportedRoot(value)
    local function plain(v) return public(v) and type(v)=="table" and not getmetatable(v) end
    if not plain(value) or not public(value.version) or value.version~=1 then return false end
    if value.accountTrackingKey~=nil and not positiveID(value.accountTrackingKey) then return false end
    if value.accountWideTracking~=nil and type(value.accountWideTracking)~="boolean" then return false end
    for _,key in ipairs({"bestiary","eventLog","bestiaryBackups","spellIDWindowBlacklist"}) do
        if value[key]~=nil and not plain(value[key]) then return false end
    end
    local bestiary=value.bestiary
    if bestiary then
        for _,key in ipairs({"creatures","entries","points","recentKills","sharing","sharingCharacters","zoneTerritories"}) do
            if bestiary[key]~=nil and not plain(bestiary[key]) then return false end
        end
        for id,creature in pairs(bestiary.creatures or {}) do
            if not positiveID(id) or not plain(creature) or not plain(creature.spells)
                or (creature.names~=nil and not plain(creature.names)) then return false end
        end
        for id,entry in pairs(bestiary.entries or {}) do
            if not positiveID(id) or not plain(entry) then return false end
        end
    end
    return true
end

-- Whole-save restoration commits only in a fresh namespace, before any of the
-- ordinary schema migrations and before observers hold saved-table references.
local backupStartupChecked=false
function ns.HoldForFieldbookRestore()
    ns.InitializationBlocked=true
    local closing=fieldbook
    db,trackingDB,journal,encounters=nil,nil,nil,nil
    book,fieldbook,ledgerBook,gatheringBook=nil,nil,nil,nil
    AzerothFieldbookRecordAtlasPoint=nil
    wipeDeadline=0
    -- Drop writers before UI hooks run; even a failing OnHide cannot leave the
    -- main dispatcher live while a restore is awaiting reload.
    if AzerothFieldbookCreatureNotes then pcall(AzerothFieldbookCreatureNotes.Hide,AzerothFieldbookCreatureNotes) end
    if closing then pcall(closing.Hide,closing) end
end
local function initializeImpl()
    if not backupStartupChecked then
        backupStartupChecked=true
        if ns.FieldbookBackups then
            ns.FieldbookBackups.ApplyFullReset()
            local ok,err=ns.FieldbookBackups.ApplyPending()
            if not ok then
                ns.HoldForFieldbookRestore()
                say("Backup recovery paused: "..ns.Atlas.Safe(err).." Use /fieldbook backups to export or cancel the pending restore, then /reload.")
                return
            end
        end
    end
    if ns.InitializationBlocked or (AzerothFieldbookDB~=nil and not supportedRoot(AzerothFieldbookDB)) then
        -- Latch until a real /reload creates a new namespace. Independent section
        -- observers and queued captures must not retain access to earlier stores.
        ns.InitializationBlocked=true
        -- Pinned notes outlive the book. Force closure without unpinning or
        -- saving; the latch already protects retained callbacks during OnHide.
        if AzerothFieldbookCreatureNotes then AzerothFieldbookCreatureNotes:Hide() end
        if fieldbook then fieldbook:Hide() end
        -- Drop the main dispatcher's old references as well as any pending reset.
        -- No initializer, normalization, account import or capture setup may run.
        db,trackingDB,journal,encounters=nil,nil,nil,nil
        book,fieldbook,ledgerBook,gatheringBook=nil,nil,nil,nil
        AzerothFieldbookRecordAtlasPoint=nil
        wipeDeadline=0
        say("Unsupported or malformed saved data; Fieldbook is disabled for this session. Saved data was left unchanged. Use /fieldbook backups for recovery, or restore supported saved files, then /reload.")
        return
    end
    if AzerothFieldbookDB == nil then
        AzerothFieldbookDB = { version = 1, bestiary = { creatures = {}, entries = {} }, announce = false }
    end
    db = AzerothFieldbookDB
    trackingDB = ns.InitializeTracking and ns.InitializeTracking(db) or db
    if ns.InitializeSectionTracking then ns.InitializeSectionTracking(db) end
    trackingDB.bestiary = type(trackingDB.bestiary) == "table" and trackingDB.bestiary or {}
    trackingDB.bestiary.creatures = type(trackingDB.bestiary.creatures) == "table" and trackingDB.bestiary.creatures or {}
    trackingDB.bestiary.entries = type(trackingDB.bestiary.entries) == "table" and trackingDB.bestiary.entries or {}
    if type(db.creatureAnnouncements) ~= "boolean" then db.creatureAnnouncements = true end
    applySpellIDTooltipPreference(db)
    -- Discard malformed saved entries rather than trying to infer missing data.
    for id, creature in pairs(trackingDB.bestiary.creatures) do
        if not positiveID(id) or type(creature) ~= "table" or type(creature.spells) ~= "table" then
            trackingDB.bestiary.creatures[id] = nil
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
    if ns.UIScale then ns.UIScale:Initialize(db) end
    if ns.TextSize then ns.TextSize:Initialize() end
    if ns.CastIDs then ns.CastIDs:Initialize(db) end
    if ns.CreateBestiaryJournal then journal = ns.CreateBestiaryJournal(db, watchedEnemy, trackingDB) end
    if journal then
        if journal.SetAutomaticRecordCallback then journal:SetAutomaticRecordCallback(function(message, details)
            if details and details.spellID then
                if db.spellFeedback == true then say(message) end
            else say(message) end
        end) end
        if ns.SpellIDWindow and ns.SpellIDWindow.SetAssignmentCapture then
            ns.SpellIDWindow:SetAssignmentCapture(function(unit, spellID, kind)
                if afterWipeHold or not journal.CaptureSpellAssignment then return end
                return journal:CaptureSpellAssignment(unit, spellID, kind, say, function() return not afterWipeHold end)
            end)
        end
        if ns.SpellIDWindow and ns.SpellIDWindow.SetCreatureOpener then
            ns.SpellIDWindow:SetCreatureOpener(function(candidate)
                if ns.InitializationBlocked or afterWipeHold or not book then return false end
                return candidate.open(function(id)
                    return book:GetShell():ShowSection("bestiary", {creatureID=id})
                end)
            end)
        end
        if ns.CreateLossOfControlObserver then lossOfControl = ns.CreateLossOfControlObserver(journal, watchedEnemy, function(message) if db.spellFeedback == true then say(message) end end) end
        journal:SetPointsRecordedCallback(function(entry, amount, reason, observation)
            local killTitles = { ["first kill"] = "First kill!", ["silver star"] = "10 kills!", ["gold star"] = "25 kills!!", ["gold crown"] = "50 kills!!!" }
            local discoveryTitles = { location = "New observed location" }
            local title = killTitles[reason] or (reason == "new creature entry" and "New discovery!")
                or (observation and discoveryTitles[observation.kind])
            if title then announceBestiary(entry, title, amount, observation, killTitles[reason] ~= nil,journal:GetPointAnnouncements()) end
        end)
        journal:SetEntryAddedCallback(function(entry, discovered, observation, previouslyCredited)
            if ns.RecordFieldbookDiscovery then ns.RecordFieldbookDiscovery("bestiary",entry,journal) end
            local chatEnabled=journal:GetCreatureAnnouncement()
            local title=discovered and "New discovery!" or (previouslyCredited and "Entry restored" or "Entry observed")
            announceBestiary(entry,title,nil,observation,false,chatEnabled)
        end)
        journal:SetDiscoveryRecordedCallback(function(entry, observation)
            announceBestiary(entry,"New observed location",nil,observation,false,journal:GetCreatureAnnouncement())
        end)
    end
    if ns.SpellIDWindow then ns.SpellIDWindow:Initialize(db) end
    if journal and ns.InitializeSharing then ns.InitializeSharing(journal) end
    if journal and ns.StartBestiaryLoot then ns.StartBestiaryLoot(journal) end
    if journal and ns.CreateFieldbookShell then
        fieldbook=ns.CreateFieldbookShell({
            getStorageScope=function(id) return ns.GetActiveStorageScope(id,trackingDB.bestiary) end,
            getBrightness=function() return journal:GetBackgroundBrightness() end,
            getDarkMode=function() return journal:GetDarkMode() end,
        })
    end
    if journal and ns.CreateBestiaryBook then book = ns.CreateBestiaryBook(journal,fieldbook) end
    if fieldbook and ns.InitializeGathering then
        gatheringBook=ns.InitializeGathering(fieldbook,function() return journal:GetBackgroundBrightness() end)
        gatheringBook.journal.onDiscovery=function(entry,title,location)
            if not journal:GetCreatureAnnouncement() then return end
            local details=ns.GatheringKinds[entry.kind].title
            if location then details=details .. " • " .. location end
            say("|cffffd100[" .. title .. "]|r |cff80d0ff" .. fieldbook.sections.gathering.definition.title .. ":|r |cffffffff" .. entry.name .. "|r"
                .. " |cff999999(" .. details .. ")|r")
        end
    end
    local atlasBook,anglingBook,treasureBook,loreBook
    if fieldbook and ns.InitializeAtlas then atlasBook=ns.InitializeAtlas(fieldbook,journal) end
    if fieldbook and ns.InitializeAngling then anglingBook=ns.InitializeAngling(fieldbook) end
    if fieldbook and ns.InitializeLedger then ledgerBook=ns.InitializeLedger(fieldbook,journal) end
    if fieldbook and ns.InitializeTreasure then treasureBook=ns.InitializeTreasure(fieldbook,journal) end
    if fieldbook and ns.InitializeLore then
        loreBook=ns.InitializeLore(fieldbook,db,{bestiary=journal,gathering=gatheringBook,atlas=atlasBook,
            angling=anglingBook,merchants=ledgerBook,treasure=treasureBook})
    end
    if fieldbook and ns.InitializeAnnals then
        ns.InitializeAnnals(fieldbook,{bestiary=journal,gathering=gatheringBook,atlas=atlasBook,
            angling=anglingBook,merchants=ledgerBook,treasure=treasureBook,lore=loreBook})
    end
    if ns.MapBrightness then
        ns.MapBrightness:Initialize(db,atlasBook and atlasBook.journal and atlasBook.journal.saved or AzerothFieldbookAtlasDB,
            ns.ActiveSectionStores and ns.ActiveSectionStores.gathering or AzerothFieldbookGatheringDB)
    end
    if fieldbook and ns.RegisterFieldbookWishlistSections then ns.RegisterFieldbookWishlistSections(fieldbook) end
    if journal and journal.sharing then
        journal.sharing:SetImportedCallback(function() if book then book:Refresh() end end)
        journal.sharing:SetCostAdjustedCallback(function(tx)
            say("|cffffd100[" .. (tx.basicDiscount or 1) .. " knowledge saved]|r " .. tx.recipient ..
                " already has this creature's basic information; its cost was waived. Charged " ..
                tx.cost .. " knowledge.")
        end)
    end
    if ns.MinimapButton then ns.MinimapButton:Initialize(db, fieldbook or book) end
    if ns.CreateBestiaryEncounterReader then
        encounters = ns.CreateBestiaryEncounterReader(function(id, spellID, creatureName)
            return storeObserved(id, spellID, nil, creatureName)
        end, function(id, creatureName)
            return journal and journal:ObserveEncounter(id, creatureName)
        end)
    end
    if encounters and db.ignoreEncounterHistory then encounters:ForgetHistory() end
    if ns.ReportTrackingTransition then ns.ReportTrackingTransition(db, say) end
end

local function initialize()
    local ok,err=pcall(initializeImpl)
    local restored=ns.FieldbookBackups and ns.FieldbookBackups.FinishStartup(ok and not ns.InitializationBlocked)
    if restored and (not ok or ns.InitializationBlocked) then
        ns.HoldForFieldbookRestore()
        say("Fieldbook restore could not initialize. The original saved journals were put back unchanged. Use /fieldbook backups to cancel the pending restore or export recovery data, then /reload.")
    elseif not ok then error(err,0) end
end

local bindingReminderShown = false
local function remindAboutUnboundBookKey()
    if bindingReminderShown or type(GetBindingKey) ~= "function" then return end
    bindingReminderShown = true
    local primary, secondary = GetBindingKey("CLASSICBESTIARY_BOOK")
    if not primary and not secondary then
        say("The Azeroth Fieldbook Bestiary has no keybinding. Bind it in Options > Keybindings.")
    end
end

function AzerothFieldbookToggleBestiary()
    if fieldbook or book then (fieldbook or book):Toggle() end
end

function AzerothFieldbookOpenMouseover()
    if gatheringBook and gatheringBook.OpenAtMouseover and gatheringBook:OpenAtMouseover() then return true end
    if ledgerBook and ledgerBook.OpenAtUnit and ledgerBook:OpenAtUnit("mouseover") then return true end
    if book and book:OpenAtUnit("mouseover") then return true end
    if fieldbook and fieldbook.ShowSection then fieldbook:ShowSection(fieldbook.active or "bestiary") end
    return false
end

-- Keep existing macros and the saved binding action compatible.
function AzerothFieldbookOpenMouseoverBestiary()
    return AzerothFieldbookOpenMouseover()
end

function AzerothFieldbookNextEntry()
    if book then return book:CycleEntry(1) end
end

function AzerothFieldbookPreviousEntry()
    if book then return book:CycleEntry(-1) end
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

frame:SetScript("OnEvent", function(_, event, ...)
    local unit, castGUID, spellID, sentSpellID = ...
    if event == "ADDON_LOADED" then
        if unit == addonName then initialize() end
        return
    end
    if not db then return end
    if lossOfControl and not afterWipeHold then lossOfControl:Event(event, ...) end
    if journal and not afterWipeHold and journal.BeastLoreEvent then
        journal:BeastLoreEvent(event,unit,castGUID,spellID,sentSpellID)
    end
    if encounters then encounters:Event(event) end
    if event == "MODIFIER_STATE_CHANGED" then
        if unit == "LCTRL" or unit == "RCTRL" then refreshAbilityTooltip() end
    elseif event == "SPELL_TEXT_UPDATE" then
        refreshAbilityTooltip()
    elseif event == "PLAYER_LOGIN" then
        remindAboutUnboundBookKey()
    elseif event == "PLAYER_TARGET_CHANGED" then
        afterWipeHold = false
        observeCurrent("target", true)
        if journal and journal.ObserveBuffs then journal:ObserveBuffs("target") end
        if book then book:FollowNotesTarget() end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        afterWipeHold = false
        observeCurrent("mouseover")
        if journal and journal.ObserveBuffs then journal:ObserveBuffs("mouseover") end
    elseif event == "CHAT_MSG_MONSTER_EMOTE" then
        if journal and not afterWipeHold then journal:RecordMonsterEmote(unit,castGUID,select(12,...)) end
    elseif event == "PARTY_KILL" then
        if journal and not afterWipeHold then journal:RecordPartyKill(unit, castGUID) end
    elseif event == "UNIT_DIED" then
        if journal and not afterWipeHold then journal:RecordUnitDeath(unit) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if journal then journal:ObserveZoneTerritory() end
        if journal then journal:ClearKillEvidence() end
        if journal and not afterWipeHold and journal.ObserveBuffs then
            journal:ObserveBuffs("target"); journal:ObserveBuffs("mouseover")
        end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS" then
        if journal then journal:ObserveZoneTerritory() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if journal and not afterWipeHold and journal.ObserveBuffs then
            journal:ObserveBuffs("target"); journal:ObserveBuffs("mouseover")
        end
    elseif event == "UNIT_AURA" then
        local watched = watchedAlias(unit)
        if watched and journal and not afterWipeHold and journal.ObserveBuffs then journal:ObserveBuffs(watched) end
    elseif event == "UNIT_HEALTH" then
        local watched = watchedAlias(unit)
        if watched and journal then journal:RecordKill(watched) end
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
            remember(watched, spellID, nil, sentSpellID)
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
    if not db then return end
    if journal and not afterWipeHold and journal.PollBeastLore then journal:PollBeastLore(elapsed) end
    if journal and not afterWipeHold and journal.PollBuffs then journal:PollBuffs(elapsed) end
    if encounters then encounters:Update(elapsed) end
    elapsedSinceScan = elapsedSinceScan + elapsed
    if elapsedSinceScan < 0.2 then return end
    elapsedSinceScan = 0
    observeCurrent("target")
    observeCurrent("mouseover")
end)

for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
    "UNIT_HEALTH", "UNIT_AURA", "CHAT_MSG_MONSTER_EMOTE",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
    "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED", "DAMAGE_METER_RESET" }) do
    frame:RegisterEvent(event)
end
-- Standalone GUID events in Forever 69977 (not combat-log subevents). Missing
-- registration can fail; a watched alive-to-dead transition can still count
-- with readable tag eligibility. PARTY_KILL is optional (pets may not emit it).
for _, event in ipairs({ "PARTY_KILL", "UNIT_DIED", "MODIFIER_STATE_CHANGED", "SPELL_TEXT_UPDATE", "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED" }) do
    pcall(frame.RegisterEvent, frame, event)
end

SLASH_AZEROTHFIELDBOOK1 = "/fieldbook"
SLASH_AZEROTHFIELDBOOK2 = "/bestiary"
SlashCmdList.AZEROTHFIELDBOOK = function(message)
    local command = message:lower():match("^%s*(.-)%s*$"):gsub("%s+", " ")
    if command=="backups" and ns.OpenFieldbookBackups then ns.OpenFieldbookBackups();return end
    if not db then return end
    if command == "wipe" or command == "reset" or command == "reset confirm" then
        wipeDeadline = GetTime() + 60
        local scope = trackingDB ~= db and "the account-wide" or "this character's"
        say("WARNING: wipe permanently deletes ALL of " .. scope .. " Bestiary entries, abilities, notes, damage records and sharing knowledge/history, plus this character's settings.")
        say("Command 1/2 accepted. Type /fieldbook wipe confirm within 60 seconds to permanently delete it.")
    elseif command == "wipe confirm" then
        if wipeDeadline == 0 or GetTime() > wipeDeadline then
            wipeDeadline = 0; say("No active wipe request. Start with /fieldbook wipe."); return
        end
        wipeDeadline = 0
        if journal then journal:ResetDatabase()
        else
            for key in pairs(db) do db[key] = nil end
            db.version, trackingDB.bestiary, db.announce, db.creatureAnnouncements = 1, { creatures = {}, entries = {} }, false, true
            applySpellIDTooltipPreference(db)
        end
        if ns.CastIDs then ns.CastIDs:Initialize(db) end
        if ns.SpellIDWindow then ns.SpellIDWindow:Initialize(db) end
        -- Prevent retained meter history from silently restoring wiped knowledge
        -- after reload. New sessions after each load can still be learned.
        db.ignoreEncounterHistory = true
        if encounters then encounters:ForgetHistory() end
        if book then book:Refresh() end
        afterWipeHold = true
        say((trackingDB ~= db and "The account-wide" or "This character's") .. " Azeroth Fieldbook Bestiary has been wiped. Retarget an NPC to begin again.")
    elseif command == "wipe cancel" then
        wipeDeadline = 0
        say("Wipe cancelled. Nothing deleted.")
    elseif command == "" or command == "book" then
        if fieldbook or book then (fieldbook or book):Toggle() else say("Book module unavailable; reload the UI.") end
    elseif command == "notes" then
        if book then book:OpenNotes() else say("Book module unavailable; reload the UI.") end
    elseif command == "encounters" then
        if encounters then encounters:Report(say) else say("Encounter module unavailable.") end
    elseif command == "scan" then
        if encounters then encounters:Scan(); encounters:Report(say) else say("Encounter module unavailable.") end
    elseif command == "debug kills on" or command == "debug kills off" then
        if not ns.KillDiagnostics then say("Kill diagnostic module unavailable; reload the UI."); return end
        local enabled = command == "debug kills on"
        ns.KillDiagnostics:SetEnabled(enabled)
        if enabled then
            ns.KillDiagnostics:Sample("target", journal, "start")
            ns.KillDiagnostics:Sample("mouseover", journal, "start")
        end
        say(enabled and "Kill evidence recording on until /reload. Qualified kills and discovery remain active. /fieldbook debug kills opens the report."
            or "Kill evidence recording off.")
    elseif command == "debug kills" then
        if not ns.KillDiagnostics then say("Kill diagnostic module unavailable; reload the UI."); return end
        local lines = {}
        ns.KillDiagnostics:Report(function(line) lines[#lines + 1] = line end)
        if ns.ShowDebugReport then ns.ShowDebugReport(table.concat(lines, "\n")) end
        say("Kill diagnostic snapshot opened. Decision lines separate kill awards from discovery knowledge.")
    elseif command == "debug model" then
        if not gatheringBook or not gatheringBook.ReportModel then say("Open the Gatherer's Compendium first.");return end
        local lines={}
        gatheringBook:ReportModel(function(line) lines[#lines+1]=line end)
        if ns.ShowDebugReport then ns.ShowDebugReport(table.concat(lines,"\n")) end
    elseif command == "debug on" or command == "debug off" then
        local enabled = command == "debug on"
        if ns.CastIDs then ns.CastIDs:SetDebug(enabled) end
        say(enabled and "Cast ID diagnostics on until /reload." or "Cast ID diagnostics off.")
    elseif command == "debug ?" then
        say("/fieldbook debug opens a copyable diagnostic report; /fieldbook debug on | off toggles cast ID diagnostic text.")
        say("/fieldbook debug kills on | off controls the temporary kill evidence recorder; /fieldbook debug kills opens its report.")
    elseif command == "debug" then
        local lines = {}
        local function say(line)
            lines[#lines + 1] = line
        end
        local function section(label, source, method)
            if not source or type(source[method]) ~= "function" then return end
            local ok = pcall(source[method], source, say)
            if not ok then say(label .. ": diagnostic collection failed; other sections follow.") end
        end
        local function collect()
            section("Cast ID display", ns.CastIDs, "Report")
            section("Spell ID window", ns.SpellIDWindow, "Report")
            section("Automatic abilities", journal, "ReportBuffs")
            section("Player Loss of Control", lossOfControl, "Report")
            section("Automatic behaviours", journal, "ReportBehaviours")
            if ns.KillDiagnostics then
                say("Kill evidence recorder: " .. (ns.KillDiagnostics.enabled and "ON" or "OFF")
                    .. ". /fieldbook debug kills opens its separate report.")
            end
            local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version") or "unknown"
            say("Version " .. version .. "; all cast events: " .. diagnostics.events .. "; new observations: " .. diagnostics.learned
                .. "; tooltip callbacks: " .. diagnostics.tooltips)
            say("Last cast check: " .. diagnostics.last)
            say("Events matched to target/mouseover: " .. matchedEvents .. ". All-event count includes unrelated units.")
            say("Last tooltip: " .. tooltipStatus)
            if encounters then say("Encounter learning: " .. encounters.status .. " (/fieldbook encounters for details)") end
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
        end
        -- A diagnostic failure must leave a copyable partial report. Error
        -- payloads can contain restricted data, so never append them verbatim.
        local ok = pcall(collect)
        if not ok then say("Report interrupted by a diagnostic error; available snapshot is shown above.") end
        if ns.ShowDebugReport then
            ns.ShowDebugReport(table.concat(lines, "\n"))
        else
            -- Degraded hosts can still expose the report if the UI module failed.
            for _, line in ipairs(lines) do
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line) end
            end
        end
    elseif command == "alerts" then
        db.announce = not db.announce
        say(db.announce and "Discovery messages on." or "Discovery messages off.")
    else
        local creatures, spells = 0, 0
        for _, creature in pairs(trackingDB.bestiary.creatures) do
            creatures = creatures + 1
            for _ in pairs(creature.spells) do spells = spells + 1 end
            for _ in pairs(creature.names or {}) do spells = spells + 1 end
        end
        say(creatures .. " creatures; " .. spells .. " observed creature/ability pairs.")
        say("Learns from direct NPC casts and readable post-combat records, including party encounters.")
        if encounters then say("Encounter learning: " .. encounters.status) end
        say("Unreadable spell IDs this session: " .. skipped .. " (readable active cast names can still be learned).")
        say("/fieldbook debug explains discovery checks (no hidden spell data).")
        say("/fieldbook alerts toggles discovery messages; /fieldbook wipe starts the double-confirmed wipe.")
        say("/fieldbook opens the Azeroth Fieldbook Bestiary; confirm entries and add your own ability notes there.")
        say("/fieldbook notes opens ID Logs and Notes for the selected Bestiary creature.")
    end
end
