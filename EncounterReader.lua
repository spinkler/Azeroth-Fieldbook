-- Only consumes this character's retained combat sessions. No static ability data.
local _, ns = ...

function ns.CreateEncounterReader(record)
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

    function reader:Schedule()
        delay, retries = math.min(delay or 1, 1), 4
    end

    function reader:ForgetHistory()
        for sessionID in pairs(seenSessions) do ignoredSessions[sessionID] = true end
        local ok, sessions = pcall(function() return C_DamageMeter.GetAvailableCombatSessions() end)
        if ok and tab(sessions) then
            for _, session in ipairs(sessions) do
                if tab(session) and id(session.sessionID) then ignoredSessions[session.sessionID] = true end
            end
        else
            ignoreNextSnapshot = true
        end
        delay, retries = nil, 0
        self.status = "Bestiary cleared; existing meter sessions excluded from future imports."
    end

    function reader:Scan()
        if not outOfCombat() then self.status = "Deferred: combat active or combat state unreadable."; return end
        local meter, modes = C_DamageMeter, Enum and Enum.DamageMeterType
        if not meter or not modes or type(meter.GetAvailableCombatSessions) ~= "function"
            or type(meter.GetCombatSessionFromID) ~= "function"
            or type(meter.GetCombatSessionSourceFromID) ~= "function"
            or not enum(modes.EnemyDamageTaken) or not enum(modes.DamageTaken) then
            self.status = "API MISSING: combat-session queries or required categories unavailable."
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
            ambiguous = 0, excluded = 0, unreadable = 0, errors = 0, capped = 0 }
        local proposals = {}
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
        local function propose(npcID, spell)
            -- creatureName denotes pet contribution in Blizzard's spell rows.
            if not id(spell.spellID) or not empty(spell.creatureName) then
                stats.excluded = stats.excluded + 1; return
            end
            stats.candidates = stats.candidates + 1
            proposals[npcID] = proposals[npcID] or {}
            proposals[npcID][spell.spellID] = true
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
            if ignoreNextSnapshot then
                each(sessions, 1000, function(session)
                    if id(session.sessionID) then ignoredSessions[session.sessionID] = true end
                end)
                ignoreNextSnapshot = false
                return
            end
            each(sessions, 30, function(session)
                if not id(session.sessionID) then stats.unreadable = stats.unreadable + 1; return end
                local sessionID = session.sessionID
                if ignoredSessions[sessionID] then return end
                seenSessions[sessionID] = true
                stats.sessions = stats.sessions + 1
                local roster = get(meter.GetCombatSessionFromID, sessionID, modes.EnemyDamageTaken)
                local names, enemies = {}, {}
                local completeRoster = true
                if roster then
                    local completeList = each(roster.combatSources, 250, function(source)
                    local creatureID = npc(source)
                    if not creatureID or not text(source.name) then
                        stats.excluded = stats.excluded + 1; completeRoster = false; return
                    end
                    enemies[creatureID] = true
                    stats.roster = stats.roster + 1
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
                local taken = get(meter.GetCombatSessionFromID, sessionID, modes.DamageTaken)
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
                        propose(creatureID, spell)
                    end) end
                end) end

                -- Direct outgoing NPC damage/healing, if the meter exposes it.
                -- EnemyDamageTaken itself contains attacks AGAINST the NPC and
                -- must never be imported as that NPC's own abilities.
                for _, modeName in ipairs({ "DamageDone", "HealingDone" }) do
                    local mode = modes[modeName]
                    if enum(mode) then
                        local summary = get(meter.GetCombatSessionFromID, sessionID, mode)
                        if summary then each(summary.combatSources, 250, function(source)
                            local creatureID = npc(source)
                            if not creatureID or not enemies[creatureID] then return end
                            local result = details(sessionID, mode, source)
                            if result then each(result.combatSpells, 500, function(spell)
                                propose(creatureID, spell)
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
        local added = 0
        for creatureID, spells in pairs(proposals) do
            for spellID in pairs(spells) do
                if record(creatureID, spellID) then added = added + 1 end
            end
        end
        self.status = "Last scan: " .. stats.sessions .. " sessions; " .. added .. " new NPC/ability pairs."
        if stats.candidates == 0 then
            self.status = self.status .. " No spell rows could be attributed safely. See /bestiary encounters."
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
            or event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" or event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" then
            self:Schedule()
        elseif event == "DAMAGE_METER_RESET" then
            delay, retries = nil, 0
            self.status = "Meter history cleared; learned bestiary entries retained."
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
        end
        say("Imports only readable records in your retained encounters, including attacks on party members.")
        say("Incoming NPC names must match one creature ID in the SAME encounter. Players, pets and ambiguous names are excluded.")
        say("The meter is not a full cast log: buffs, missed/interrupted casts and enemy self-heals may be absent.")
        say("/bestiary scan retries now outside combat. Scans also retry automatically after combat ends.")
    end
    return reader
end
