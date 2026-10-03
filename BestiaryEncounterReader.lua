-- Only consumes this character's retained combat sessions. No static ability data.
local _, ns = ...

function ns.CreateBestiaryEncounterReader(record, recordCreature)
    local reader = { status = "Waiting for post-combat data.", scans = 0 }
    local delay, retries = 1, 0
    local ignoredSessions, seenSessions = {}, {}
    local ignoreNextSnapshot = false
    local function public(v) return not (issecretvalue and issecretvalue(v)) end
    local function text(v) return public(v) and type(v) == "string" and v ~= "" end
    local function id(v)
        return public(v) and type(v) == "number" and v > 0 and v < math.huge and v == math.floor(v)
    end
    local function tab(v)
        return public(v) and type(v) == "table"
            and (not canaccesstable or canaccesstable(v))
            and (not issecrettable or not issecrettable(v))
    end
    local function equals(v, expected) return public(v) and v == expected end
    local function empty(v) return public(v) and (v == nil or v == "") end
    local function outOfCombat()
        if type(InCombatLockdown) ~= "function" or type(UnitAffectingCombat) ~= "function" then return false end
        local ok1, lockdown = pcall(InCombatLockdown)
        local ok2, fighting = pcall(UnitAffectingCombat, "player")
        return ok1 and ok2 and equals(lockdown, false) and equals(fighting, false)
    end
    local function enum(value) return public(value) and type(value) == "number" end

    -- Only a complete readable snapshot can retire old session identities or
    -- establish the wipe boundary. A restricted/malformed row is not an empty
    -- history. The client retains a small list; fail closed above this bound.
    local function sessionIDs(sessions)
        if not tab(sessions) then return end
        local ids, count = {}, 0
        for index, session in pairs(sessions) do
            if not id(index) or index > 1000 or not tab(session) or not id(session.sessionID) then return end
            ids[session.sessionID] = true
            count = count + 1
        end
        for index = 1, count do if sessions[index] == nil then return end end
        return ids
    end

    function reader:Schedule()
        delay, retries = math.min(delay or 1, 1), 4
    end

    function reader:ForgetHistory()
        local ok, ids = pcall(function() return sessionIDs(C_DamageMeter.GetAvailableCombatSessions()) end)
        if ok and ids then
            ignoredSessions, seenSessions = ids, ids
            ignoreNextSnapshot = false
        else
            ignoredSessions = seenSessions
            ignoreNextSnapshot = true
        end
        delay, retries = nil, 0
        self.status = "Bestiary section cleared; existing meter sessions excluded from future imports."
    end

    function reader:Scan()
        if not outOfCombat() then self.status = "Deferred: combat active or combat state unreadable."; return end
        local meter, modes = C_DamageMeter, Enum and Enum.DamageMeterType
        if not meter or not modes or type(meter.GetAvailableCombatSessions) ~= "function"
            or type(meter.GetCombatSessionFromID) ~= "function"
            or not enum(modes.EnemyDamageTaken) then
            self.status = "API MISSING: combat-session queries or enemy roster unavailable."
            return
        end
        if type(meter.IsDamageMeterAvailable) == "function" then
            local ok, available = pcall(meter.IsDamageMeterAvailable)
            if not ok or not equals(available, true) then
                self.status = "Meter unavailable: check the game's damage-meter setting; no settings were changed."
                return
            end
        end
        local stats = { sessions = 0, roster = 0, incoming = 0, candidates = 0,
            ambiguous = 0, excluded = 0, unreadable = 0, errors = 0, capped = 0,
            rosterRows = 0, hiddenIDs = 0, hiddenNames = 0, hiddenGUIDs = 0 }
        local proposals = {}
        local function identity(npcID, name)
            local proposal = proposals[npcID]
            if not proposal then
                proposal = { name = name, spells = {} }
                proposals[npcID] = proposal
            elseif proposal.name ~= name and proposal.name ~= false then
                proposal.name = false
                stats.ambiguous = stats.ambiguous + 1
            end
            return proposal
        end
        local function get(fn, ...)
            local ok, result = pcall(fn, ...)
            if not ok then stats.errors = stats.errors + 1; return end
            if not tab(result) then stats.unreadable = stats.unreadable + 1; return end
            return result
        end
        local function each(rows, limit, visit)
            if not tab(rows) then stats.unreadable = stats.unreadable + 1; return false end
            local n = 0
            local complete = true
            for _, row in ipairs(rows) do
                n = n + 1
                if n > limit then stats.capped = stats.capped + 1; return false end
                if tab(row) then visit(row) else stats.unreadable = stats.unreadable + 1; complete = false end
            end
            return complete
        end
        local function npc(row)
            -- Blizzard also uses empty classFilename + sourceCreatureID for NPCs.
            if not id(row.sourceCreatureID) or not equals(row.classFilename, "") then return end
            if not equals(row.isLocalPlayer, false) then return end
            local display = Enum.DamageMeterSourceDisplayType
            if display and (not public(row.sourceDisplayType) or equals(row.sourceDisplayType, display.Ally)) then return end
            local guid = row.sourceGUID
            if not public(guid) then return end
            if guid ~= nil then
                if not text(guid) then return end
                local parsed = tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
                if parsed ~= row.sourceCreatureID then return end
            end
            return row.sourceCreatureID
        end
        local function propose(npcID, name, spell)
            -- creatureName denotes pet contribution in Blizzard's spell rows.
            if not text(name) or not id(spell.spellID) or not empty(spell.creatureName) then
                stats.excluded = stats.excluded + 1; return
            end
            stats.candidates = stats.candidates + 1
            local proposal = identity(npcID, name)
            proposal.spells[spell.spellID] = true
        end
        local function details(sessionID, mode, source)
            if not public(source.sourceGUID) or not public(source.sourceCreatureID) then
                stats.unreadable = stats.unreadable + 1; return
            end
            local guid, creatureID = source.sourceGUID, source.sourceCreatureID
            if guid ~= nil and not text(guid) then return end
            if creatureID ~= nil and not id(creatureID) then return end
            if guid == nil and creatureID == nil then return end
            return get(meter.GetCombatSessionSourceFromID, sessionID, mode, guid, creatureID)
        end
        local ok = pcall(function()
            local sessions = get(meter.GetAvailableCombatSessions)
            if not sessions then return end
            local available = sessionIDs(sessions)
            if ignoreNextSnapshot then
                if available then
                    ignoredSessions, seenSessions = available, available
                    ignoreNextSnapshot = false
                end
                return
            end
            if available then
                local retained = {}
                for sessionID in pairs(ignoredSessions) do
                    if available[sessionID] then retained[sessionID] = true end
                end
                ignoredSessions, seenSessions = retained, available
            end
            each(sessions, 30, function(session)
                if not id(session.sessionID) then stats.unreadable = stats.unreadable + 1; return end
                local sessionID = session.sessionID
                if ignoredSessions[sessionID] then return end
                stats.sessions = stats.sessions + 1
                local roster = get(meter.GetCombatSessionFromID, sessionID, modes.EnemyDamageTaken)
                local names, enemies = {}, {}
                local completeRoster = true
                if roster then
                    local completeList = each(roster.combatSources, 250, function(source)
                    stats.rosterRows = stats.rosterRows + 1
                    if not public(source.sourceCreatureID) then stats.hiddenIDs = stats.hiddenIDs + 1 end
                    if not public(source.name) then stats.hiddenNames = stats.hiddenNames + 1 end
                    if not public(source.sourceGUID) then stats.hiddenGUIDs = stats.hiddenGUIDs + 1 end
                    local creatureID = npc(source)
                    if not creatureID or not text(source.name) then
                        stats.excluded = stats.excluded + 1; completeRoster = false; return
                    end
                    local previousName = enemies[creatureID]
                    if previousName == nil then enemies[creatureID] = source.name
                    elseif previousName ~= source.name then enemies[creatureID] = false end
                    stats.roster = stats.roster + 1
                    -- The enemy roster is direct encounter evidence even when
                    -- live unit identity or every spell detail is unavailable.
                    identity(creatureID, source.name)
                    local previous = names[source.name]
                    if previous == nil then names[source.name] = creatureID
                    elseif previous ~= creatureID then names[source.name] = false end
                    end)
                    if not completeList then completeRoster = false end
                else completeRoster = false end
                -- An unreadable/truncated roster could hide a second NPC with
                -- the same name. Do not perform name-based attribution then.
                if not completeRoster then names = {} end

                -- Incoming rows are grouped by the victim; NEVER assign their
                -- spells to that victim. Match the NPC attacker to this session's
                -- roster only. Same-name/different-ID encounters fail closed.
                local hasDetails = type(meter.GetCombatSessionSourceFromID) == "function"
                local taken = hasDetails and enum(modes.DamageTaken)
                    and get(meter.GetCombatSessionFromID, sessionID, modes.DamageTaken)
                if taken then each(taken.combatSources, 250, function(victim)
                    local result = details(sessionID, modes.DamageTaken, victim)
                    if result then each(result.combatSpells, 500, function(spell)
                        stats.incoming = stats.incoming + 1
                        local actor = spell.combatSpellDetails
                        if not tab(actor) or not equals(actor.isMob, true) or not equals(actor.isPet, false)
                            or not equals(actor.unitClassFilename, "") or not text(actor.unitName) then
                            stats.excluded = stats.excluded + 1; return
                        end
                        local creatureID = names[actor.unitName]
                        if not creatureID then stats.ambiguous = stats.ambiguous + 1; return end
                        propose(creatureID, enemies[creatureID], spell)
                    end) end
                end) end

                -- Direct outgoing NPC damage/healing, if the meter exposes it.
                -- EnemyDamageTaken itself contains attacks AGAINST the NPC and
                -- must never be imported as that NPC's own abilities.
                for _, modeName in ipairs({ "DamageDone", "HealingDone" }) do
                    local mode = modes[modeName]
                    if hasDetails and enum(mode) then
                        local summary = get(meter.GetCombatSessionFromID, sessionID, mode)
                        if summary then each(summary.combatSources, 250, function(source)
                            local creatureID = npc(source)
                            if not creatureID or not enemies[creatureID] then return end
                            local result = details(sessionID, mode, source)
                            if result then each(result.combatSpells, 500, function(spell)
                                propose(creatureID, enemies[creatureID], spell)
                            end) end
                        end) end
                    end
                end
            end)
        end)
        self.scans = self.scans + 1
        self.stats = stats
        if not ok then
            self.status = "API/table access ERROR: discarded this scan; no partial import."
            return
        end
        local added, creatures = 0, 0
        for creatureID, proposal in pairs(proposals) do
            if proposal.name then
                if recordCreature and recordCreature(creatureID, proposal.name) then creatures = creatures + 1 end
                for spellID in pairs(proposal.spells) do
                    if record(creatureID, spellID, proposal.name) then added = added + 1 end
                end
            end
        end
        self.status = "Last scan: " .. stats.sessions .. " sessions; " .. added .. " new NPC/ability pairs."
        self.status = self.status .. " " .. creatures .. " new creature records."
        if stats.candidates == 0 then
            self.status = self.status .. " No spell rows could be attributed safely. See /fieldbook encounters."
        end
    end

    function reader:Update(elapsed)
        if not delay then return end
        delay = delay - elapsed
        if delay > 0 then return end
        if not outOfCombat() then delay = 1; return end
        self:Scan()
        if retries > 0 then retries = retries - 1; delay = 3 else delay = nil end
    end

    function reader:Event(event)
        if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD"
            or event == "ADDON_RESTRICTION_STATE_CHANGED"
            or event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" or event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" then
            self:Schedule()
        elseif event == "DAMAGE_METER_RESET" then
            delay, retries = nil, 0
            ignoredSessions, seenSessions, ignoreNextSnapshot = {}, {}, false
            self.status = "Meter history cleared; learned Bestiary entries retained."
        end
    end

    function reader:Report(say)
        say("Encounter learning: " .. self.status)
        local s = self.stats
        if s then
            say("Last scan: NPC roster rows " .. s.roster .. "; incoming spell rows " .. s.incoming
                .. "; attributed candidates " .. s.candidates .. ".")
            say("Skipped: unmatched/ambiguous attacker " .. s.ambiguous .. "; excluded/invalid " .. s.excluded
                .. "; unreadable data " .. s.unreadable .. "; API errors " .. s.errors .. "; capped lists " .. s.capped .. ".")
            say("Enemy roster rows inspected " .. s.rosterRows .. "; secret creature IDs " .. s.hiddenIDs
                .. "; secret names " .. s.hiddenNames .. "; secret GUIDs " .. s.hiddenGUIDs .. ".")
        end
        say("Imports only readable records in your retained encounters, including attacks on party members.")
        say("Readable enemy rosters also recover creature entries without spell details; no kills, levels or locations are inferred.")
        say("Incoming NPC names must match one creature ID in the SAME encounter. Players, pets and ambiguous names are excluded.")
        say("The meter is not a full cast log: buffs, missed/interrupted casts and enemy self-heals may be absent.")
        say("/fieldbook scan retries now outside combat. Scans also retry automatically after combat ends.")
    end
    return reader
end
