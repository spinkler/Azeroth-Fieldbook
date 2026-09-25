local _, ns = ...

function ns.CreateBestiaryJournal(db, identify, trackingDB)
    trackingDB = trackingDB or db
    trackingDB.bestiary = type(trackingDB.bestiary) == "table" and trackingDB.bestiary or {}
    trackingDB.bestiary.entries = type(trackingDB.bestiary.entries) == "table" and trackingDB.bestiary.entries or {}
    trackingDB.bestiary.creatures = type(trackingDB.bestiary.creatures) == "table" and trackingDB.bestiary.creatures or {}
    local journal = { entries = trackingDB.bestiary.entries, revision = 0 }
    local activeAccountWideTracking = db.accountWideTracking ~= false
    local seenGUIDs = {}
    local killedGUIDs = {}
    local killInstances = {}
    local recentKills
    local instanceLimit, observationSeconds, pendingSeconds, recentLimit = 64, 120, 10, 512
    local onEntryAdded, onPointsAwarded, onPointsRecorded, onEventLogChanged
    local restoreObservations
    local ledger
    local rankLabels = { elite = "Elite", rare = "Rare", rareelite = "Rare Elite", worldboss = "World Boss" }
    local rankPriority = { ["Rare"] = 1, ["Elite"] = 2, ["Rare Elite"] = 3, ["World Boss"] = 4 }
    local magicSchools = { Arcane=true, Fire=true, Frost=true, Holy=true, Nature=true, Shadow=true }
    local behaviourNames = {
        Hostile=true, Neutral=true, Melee=true, Ranged=true, Caster=true,
        ["Flees at low health"]=true, ["Calls allies"]=true, Patrols=true,
        Summons=true, Heals=true, Enrages=true, Stealths=true,
    }
    local function public(v) return not (issecretvalue and issecretvalue(v)) end
    local function str(v) return public(v) and type(v) == "string" and v ~= "" end
    local function number(v) return public(v) and type(v) == "number" and v > 0 and v < math.huge and v == math.floor(v) end
    local function read(fn, ...)
        if type(fn) ~= "function" then return end
        local ok, value = pcall(fn, ...)
        if ok and public(value) then return value end
    end
    local function creatureID(guid)
        if not str(guid) or #guid > 128 then return end
        local id = tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%w+$"))
        if number(id) then return id end
    end
    local function now()
        local value = read(GetTime)
        if type(value) == "number" and value >= 0 and value < math.huge then return value end
    end
    local function decision(guid, status, points)
        if ns.KillDiagnostics and ns.KillDiagnostics.enabled then
            ns.KillDiagnostics:Decision(guid, status, points or 0)
        end
        return status == "accepted"
    end
    local function clearTerminal(guid, observed)
        if observed.deadline then decision(guid, "stale: living reset or combat state unknown") end
        observed.actor, observed.dead, observed.eligible, observed.rejected, observed.deadline = nil, nil, nil, nil, nil
    end
    local function pruneInstances(at)
        for guid, observed in pairs(killInstances) do
            local deadline = observed.deadline or (observed.seenAt + observationSeconds)
            if at > deadline or at < observed.seenAt then
                killInstances[guid] = nil
                decision(guid, "expired: observation or pending evidence")
            end
        end
    end
    local function observeInstance(id, guid, at)
        if not at or creatureID(guid) ~= id then return end
        pruneInstances(at)
        local observed = killInstances[guid]
        if not observed then
            local count, oldestGUID, oldest = 0, nil, math.huge
            for key, value in pairs(killInstances) do
                count = count + 1
                if value.seenAt < oldest then oldestGUID, oldest = key, value.seenAt end
            end
            if count >= instanceLimit then
                killInstances[oldestGUID] = nil
                decision(oldestGUID, "evicted: observation limit")
            end
            observed = { id = id }
            killInstances[guid] = observed
        end
        observed.seenAt = at
    end
    local function clean(value, limit)
        if not str(value) then return end
        -- Literal field notes only: no links, textures, colors or control codes.
        value = value:gsub("|", ""):gsub("[%c]", " "):match("^%s*(.-)%s*$")
        if value == "" or #value > limit then return end
        return value
    end
    local function creatureName(value)
        if not str(value) or #value > 100 or value:find("[%c|]") then return end
        value = value:match("^%s*(.-)%s*$")
        if value == "" or value == UNKNOWNOBJECT or value == UNKNOWN
            or value:match("^Creature #%d+$") or value:match("^Encountered creature #%d+$") then return end
        return value
    end
    function journal:GetCreatureName(id)
        if not number(id) then return end
        local entry = self.entries[id]
        if not entry then return end
        local locked = entry.confirmed and entry.lockedBasic
        local name = locked and creatureName(locked.name) or creatureName(entry.name)
        if name then return name end
        if not entry.confirmed then
            for _, shared in ipairs(entry.sharedReports or {}) do
                name = creatureName(shared.name)
                if name then return name end
            end
        end
    end
    -- Each tier stores cumulative points: silver 1, gold adds 2, crown adds 3.
    local killMilestones = {
        { kills = 50, points = 6, star = "crown" },
        { kills = 25, points = 3, star = "gold" },
        { kills = 10, points = 1, star = "silver" },
    }
    function journal:GetKillReward(id)
        local entry = self.entries[id]
        local kills = entry and math.max(0, math.floor(tonumber(entry.kills) or 0)) or 0
        for _, milestone in ipairs(killMilestones) do
            if kills >= milestone.kills then return milestone.points, milestone.star, kills end
        end
        return 0, nil, kills
    end
    function journal:GetPointAnnouncements()
        return db.pointAnnouncements ~= false
    end
    function journal:SetPointAnnouncements(enabled)
        db.pointAnnouncements = enabled == true
    end
    function journal:SetPointsAwardedCallback(callback)
        onPointsAwarded = type(callback) == "function" and callback or nil
    end
    function journal:SetPointsRecordedCallback(callback) onPointsRecorded=callback end
    function journal:GetEventLog()
        if type(db.eventLog)~="table" then db.eventLog={startedAt=read(time),entries={}} end
        return db.eventLog
    end
    function journal:SetEventLogChangedCallback(callback) onEventLogChanged=callback end
    function journal:RecordEvent(message, details)
        local log=self:GetEventLog()
        log.entries[#log.entries+1]={timestamp=read(time),message=message,details=details}
        if onEventLogChanged then onEventLogChanged() end
    end
    journal:GetEventLog()
    local function award(self, entry, amount, reason, observation)
        if amount > 0 then ledger.earned = ledger.earned + amount end
        if amount > 0 and onPointsRecorded then onPointsRecorded(entry,amount,reason,observation) end
        if amount > 0 and self:GetPointAnnouncements() and onPointsAwarded then
            onPointsAwarded(entry, amount, reason, observation)
        end
    end
    local function discoveryProgress(entry)
        if type(entry.discoveryProgress) ~= "table" then
            local progress = { levels = {}, zones = {} }
            -- Older journals kept only level endpoints; never infer unseen levels between them.
            if number(entry.levelMin) then progress.levels[entry.levelMin] = true end
            if number(entry.levelMax) then progress.levels[entry.levelMax] = true end
            for zone in pairs(entry.locations or {}) do progress.zones[zone] = true end
            entry.discoveryProgress = progress
        end
        local progress = entry.discoveryProgress
        if progress.points == nil then
            local levels, zones = 0, 0
            for _ in pairs(progress.levels) do levels = levels + 1 end
            for _ in pairs(progress.zones) do zones = zones + 1 end
            -- Remove the first level/zone bonuses from older scoring. Old records
            -- do not retain whether later discoveries happened together.
            progress.points = math.max(0, levels-1) + math.max(0, zones-1)
        end
        return progress
    end
    -- Credit survives deletion of a display entry. Migration runs only once and
    -- preserves the old derived total, including its legacy endpoint rules.
    local function initializePoints()
        if type(trackingDB.bestiary.points) ~= "table" then
            ledger = { version = 1, earned = 0, spent = 0, credits = {}, reservations = {} }
            for id, entry in pairs(journal.entries) do
                local progress = discoveryProgress(entry)
                local credit = { discovered = true, levels = {}, zones = {}, points = progress.points,
                    initial = progress.initial, killPoints = journal:GetKillReward(id), killGUIDs = {} }
                for level in pairs(progress.levels) do credit.levels[level] = true end
                for zone in pairs(progress.zones) do credit.zones[zone] = true end
                ledger.credits[id] = credit
                ledger.earned = ledger.earned + 1 + credit.points + credit.killPoints
                entry.personalEncountered = true
            end
            trackingDB.bestiary.points = ledger
        else
            ledger = trackingDB.bestiary.points
        end
        -- Reconcile newly available tiers for existing personal records. Keep
        -- earlier credit when a threshold rises; never repeat a paid milestone.
        for id in pairs(journal.entries) do
            local credit = ledger.credits[id]
            if credit and credit.discovered then
                local reward = journal:GetKillReward(id)
                local previous = credit.killPoints or 0
                ledger.earned = ledger.earned + math.max(0, reward - previous)
                credit.killPoints = math.max(previous, reward)
            end
        end
    end
    initializePoints()
    local function initializeRecentKills()
        -- Separate from the point ledger: a bounded replay guard, never credit.
        recentKills, killedGUIDs = {}, {}
        local saved = type(trackingDB.bestiary.recentKills) == "table" and trackingDB.bestiary.recentKills or {}
        for index = math.max(1, #saved - recentLimit + 1), #saved do
            local guid = saved[index]
            if creatureID(guid) and not killedGUIDs[guid] then
                recentKills[#recentKills + 1], killedGUIDs[guid] = guid, true
            end
        end
        trackingDB.bestiary.recentKills = recentKills
    end
    initializeRecentKills()
    local function creditFor(id)
        local credit = ledger.credits[id]
        if not credit then
            credit = { levels = {}, zones = {}, points = 0, killPoints = 0, killGUIDs = {} }
            ledger.credits[id] = credit
        end
        return credit
    end
    local function recordDiscovery(self, entry, level, zone, observation)
        local progress = creditFor(entry.id)
        local reasons = {}
        if number(level) and not progress.levels[level] then
            progress.levels[level] = true
            reasons[#reasons+1] = "new observed level " .. level
        end
        if str(zone) and not progress.zones[zone] then
            progress.zones[zone] = true
            reasons[#reasons+1] = "new zone: " .. zone
        end
        if progress.initial then
            -- The entry point covers its first observed level and zone together.
            progress.initial = nil
        elseif #reasons > 0 then
            progress.points = progress.points + 1
            observation = observation or {}
            observation.kind = #reasons == 2 and "levelAndLocation"
                or (reasons[1]:find("new observed level", 1, true) and "level" or "location")
            award(self, entry, 1, table.concat(reasons, "; "), observation)
        end
        if #reasons > 0 then self:Touch() end
    end
    function journal:GetTotals()
        local count = 0
        for id in pairs(self.entries) do if self:GetCreatureName(id) then count = count + 1 end end
        return count, ledger.earned
    end
    function journal:GetSharingBalance()
        local reserved = 0
        for _, cost in pairs(ledger.reservations) do reserved = reserved + cost end
        return math.max(0, ledger.earned - ledger.spent - reserved), ledger.earned, ledger.spent, reserved
    end
    function journal:ReserveShare(transaction, cost)
        if not str(transaction) or not number(cost) then return false end
        if ledger.reservations[transaction] then return ledger.reservations[transaction] == cost end
        if self:GetSharingBalance() < cost then return false end
        ledger.reservations[transaction] = cost
        self:Touch()
        return true
    end
    function journal:ReleaseShare(transaction)
        ledger.reservations[transaction] = nil
        self:Touch()
    end
    function journal:CommitShare(transaction, waiveBasic)
        local cost = ledger.reservations[transaction]
        if not cost then return false end
        -- Settle the recipient's one-point basic-information waiver atomically
        -- with the existing reservation; never refund or reprice a paid report.
        if waiveBasic == true then cost = math.max(0, cost - 1) end
        ledger.spent = ledger.spent + cost
        ledger.reservations[transaction] = nil
        self:Touch()
        return true, cost
    end
    function journal:GetSharingStorage()
        if trackingDB ~= db then
            trackingDB.bestiary.sharingCharacters = trackingDB.bestiary.sharingCharacters or {}
            local stores, key = trackingDB.bestiary.sharingCharacters, db.accountTrackingKey
            stores[key] = stores[key] or { sequence = 0, receipts = {}, incoming = {} }
            return stores[key]
        end
        trackingDB.bestiary.sharing = trackingDB.bestiary.sharing or { sequence = 0, receipts = {}, incoming = {} }
        return trackingDB.bestiary.sharing
    end
    function journal:Touch() self.revision = self.revision + 1 end
    function journal:SetEntryAddedCallback(callback)
        onEntryAdded = type(callback) == "function" and callback or nil
    end
    function journal:DeleteEntry(id)
        if not number(id) or not self.entries[id] then return false end
        self.entries[id] = nil
        for guid, observed in pairs(killInstances) do if observed.id == id then killInstances[guid] = nil end end
        -- Remove legacy observations too, so reload cannot migrate the entry back.
        trackingDB.bestiary.creatures[id] = nil
        self:Touch()
        return true
    end
    function journal:GetSingleObservationWindow()
        return db.singleObservationWindow ~= false
    end
    function journal:GetAlwaysAnchorToMain()
        return db.alwaysAnchorToMain ~= false
    end
    function journal:SetAlwaysAnchorToMain(enabled)
        db.alwaysAnchorToMain = enabled == true
    end
    function journal:GetBlockIncomingOffers()
        return db.blockIncomingOffers == true
    end
    function journal:SetBlockIncomingOffers(enabled)
        db.blockIncomingOffers = enabled == true
        if self.sharing then self.sharing:ApplyIncomingOfferSetting() end
        self:Touch()
    end
    function journal:GetAccountWideTracking()
        return db.accountWideTracking ~= false
    end
    function journal:SetAccountWideTracking(enabled)
        db.accountWideTracking = enabled == true
    end
    function journal:IsTrackingChangePending()
        return self:GetAccountWideTracking() ~= activeAccountWideTracking
    end
    function journal:IsAccountWideTrackingActive()
        return activeAccountWideTracking
    end
    function journal:SetSingleObservationWindow(enabled)
        db.singleObservationWindow = enabled == true
    end
    function journal:GetUIScale()
        return math.max(0.5, math.min(1.5, tonumber(db.uiScale) or 1))
    end
    function journal:SetUIScale(value)
        db.uiScale = math.max(0.5, math.min(1.5, tonumber(value) or 1))
        if ns.UIScale then ns.UIScale:Set(db.uiScale) end
    end
    function journal:GetMinimapButton()
        return db.showMinimapButton ~= false
    end
    function journal:SetMinimapButton(enabled)
        db.showMinimapButton = enabled == true
        if ns.MinimapButton then ns.MinimapButton:ApplySettings() end
    end
    function journal:GetNotesFollowTarget()
        return db.creatureNotesFollowTarget ~= false
    end
    function journal:SetNotesFollowTarget(enabled)
        db.creatureNotesFollowTarget = enabled == true
    end
    function journal:GetNotesTarget()
        if not self:GetNotesFollowTarget() then return end
        return self:Observe("target")
    end
    function journal:GetCreatureAnnouncement()
        return db.creatureAnnouncements == true
    end
    function journal:SetCreatureAnnouncement(enabled)
        db.creatureAnnouncements = enabled == true
    end
    function journal:GetDisplayCastIDs()
        return db.displayCastIDs ~= false
    end
    function journal:SetDisplayCastIDs(enabled)
        db.displayCastIDs = enabled == true
        if ns.CastIDs then ns.CastIDs:SetEnabled(db.displayCastIDs) end
    end
    function journal:GetSpellIDWindowOption(key)
        if key == "displaySpellIDWindow" then return db[key] ~= false end
        if key == "spellIDWindowAlpha" then return tonumber(db[key]) or 0.35 end
        return db[key] == true
    end
    function journal:SetSpellIDWindowOption(key, value)
        if key == "spellIDWindowAlpha" then
            db[key] = math.max(0, math.min(1, tonumber(value) or 0.35))
        elseif key == "displaySpellIDWindow" or key == "displayHoveredAuraSnapshots" or key == "spellIDWindowLocked" or key == "spellIDWindowIndefinite" or key == "spellIDWindowAutoFade" then
            db[key] = value == true
        else return end
        if ns.SpellIDWindow then ns.SpellIDWindow:ApplySettings() end
    end
    function journal:GetSpellIDTooltips()
        if type(GetCVarBool) == "function" then
            local ok, enabled = pcall(GetCVarBool, "tooltipShowAuraSpellIDs")
            if ok and type(enabled) == "boolean" then return enabled end
        end
        return db.showSpellIDs == true
    end
    function journal:SetSpellIDTooltips(enabled)
        db.showSpellIDs = enabled == true
        if type(SetCVar) == "function" then
            pcall(SetCVar, "tooltipShowAuraSpellIDs", enabled and "1" or "0")
        end
    end
    function journal:GetBackgroundBrightness()
        local value = tonumber(db.backgroundBrightness)
        if not value then return 1 end
        return math.max(0.5, math.min(1.5, value))
    end
    function journal:SetBackgroundBrightness(value)
        value = tonumber(value)
        if not value then return end
        db.backgroundBrightness = math.max(0.5, math.min(1.5, value))
        self:Touch()
    end
    -- Debuff chat reporting is intentionally unavailable: Forever exposes
    -- combat aura details as secret values that addons cannot inspect.
    function journal:Ensure(id, sharedOnly, name, observation)
        if not number(id) then return end
        name = creatureName(name)
        local wasNamed = self:GetCreatureName(id)
        -- Spell IDs alone cannot establish a creature entry. Shared reports
        -- supply their validated basics immediately after allocating the entry.
        if not sharedOnly and not wasNamed and not name then return end
        local entry = self.entries[id]
        if not entry then
            entry = { id = id, category = "Unclassified", abilities = {}, damage = {}, locations = {}, offenses = {}, resistances = {}, immunities = {}, behaviours = {}, kills = 0, confirmed = false }
            self.entries[id] = entry
            self:Touch()
        end
        if name and not creatureName(entry.name) then
            entry.name = name
            -- Older versions could lock a nameless page. Repair identity only;
            -- its saved abilities, notes and other locked metadata stay intact.
            if entry.confirmed and entry.lockedBasic and not creatureName(entry.lockedBasic.name) then
                entry.lockedBasic.name = name
            end
            self:Touch()
        end
        local discovered = false
        if not sharedOnly then
            local credit = creditFor(id)
            if not entry.personalEncountered then entry.personalEncountered = true; self:Touch() end
            if not credit.discovered then
                credit.discovered, credit.initial = true, true
                discovered = true
                award(self, entry, 1, "new creature entry", observation)
                self:Touch()
            end
        end
        if not wasNamed and self:GetCreatureName(id) and restoreObservations then restoreObservations(self, id) end
        return entry, discovered
    end
    function journal:Observe(unit)
        local id = identify(unit)
        if not id then return end
        local category, level = read(UnitCreatureType, unit), read(UnitLevel, unit)
        local location = read(GetRealZoneText) or read(GetZoneText)
        local observation = {
            category = clean(category, 100),
            level = number(level) and level > 0 and level or nil,
            location = clean(location, 200),
        }
        local liveGUID = read(UnitGUID, unit)
        if str(liveGUID) and read(UnitIsDead, unit) == false then
            observeInstance(id, liveGUID, now())
            local observed = killInstances[liveGUID]
            if observed and read(UnitAffectingCombat, unit) ~= true then
                clearTerminal(liveGUID, observed)
            end
        end
        if self.entries[id] and self.entries[id].confirmed and self:GetCreatureName(id) then
            self:Ensure(id, false, nil, observation)
            recordDiscovery(self, self.entries[id], level, location, observation)
            return id
        end
        local name = creatureName(read(UnitName, unit))
        if not name then return end
        local wasNamed = self.entries[id] and creatureName(self.entries[id].name)
        local entry, discovered = self:Ensure(id, false, name, observation)
        if not entry then return end
        recordDiscovery(self, entry, level, location, observation)
        if entry.confirmed then return id end
        local classification = read(UnitClassification, unit)
        local changed = entry.name ~= name
        entry.name = name
        if str(category) and category ~= entry.category then entry.category = category; changed = true end
        local rank = rankLabels[classification]
        if rank and (not entry.rank or rankPriority[rank] > (rankPriority[entry.rank] or 0)) then
            entry.rank = rank
            changed = true
        end
        entry.locations = type(entry.locations) == "table" and entry.locations or {}
        entry.offenses = type(entry.offenses) == "table" and entry.offenses or {}
        entry.resistances = type(entry.resistances) == "table" and entry.resistances or {}
        entry.immunities = type(entry.immunities) == "table" and entry.immunities or {}
        entry.behaviours = type(entry.behaviours) == "table" and entry.behaviours or {}
        entry.kills = tonumber(entry.kills) or 0
        if str(location) and not entry.locations[location] then
            entry.locations[location] = true
            changed = true
        end
        if number(level) then
            if not entry.levelMin or level < entry.levelMin then entry.levelMin = level; changed = true end
            if not entry.levelMax or level > entry.levelMax then entry.levelMax = level; changed = true end
        end
        local guid = read(UnitGUID, unit)
        if str(guid) then
            if not seenGUIDs[guid] then
                entry.sightings = (entry.sightings or 0) + 1
                changed = true
            end
            seenGUIDs[guid] = { id = id, level = number(level) and level or nil }
        end
        if not wasNamed and onEntryAdded then onEntryAdded(entry, discovered, observation) end
        if changed then self:Touch() end
        return id
    end
    local function setSchoolObservation(self, id, field, school, enabled)
        local entry = self.entries[id]
        if not entry or entry.confirmed or not magicSchools[school] then return false end
        entry[field] = type(entry[field]) == "table" and entry[field] or {}
        local value = enabled == true and true or nil
        if value and self.ResolveRumours then
            local kinds={offenses="offense",resistances="resistance",immunities="immunity"}
            self:ResolveRumours(id,{kind=kinds[field],value=school})
        end
        if entry[field][school] == value then return true end
        entry[field][school] = value
        self:Touch()
        return true
    end
    function journal:SetResistance(id, school, enabled)
        return setSchoolObservation(self, id, "resistances", school, enabled)
    end
    function journal:SetImmunity(id, school, enabled)
        return setSchoolObservation(self, id, "immunities", school, enabled)
    end
    function journal:SetOffense(id, school, enabled)
        return setSchoolObservation(self, id, "offenses", school, enabled)
    end
    function journal:SetBehaviour(id, name, enabled)
        local entry = self.entries[id]
        if not entry or entry.confirmed or not behaviourNames[name] then return false end
        entry.behaviours = type(entry.behaviours) == "table" and entry.behaviours or {}
        local value = enabled == true and true or nil
        if value and name == "Hostile" then entry.behaviours.Neutral = nil end
        if value and name == "Neutral" then entry.behaviours.Hostile = nil end
        if value and self.ResolveRumours then self:ResolveRumours(id,{kind="behaviour",value=name}) end
        if entry.behaviours[name] == value then return true end
        entry.behaviours[name] = value
        self:Touch()
        return true
    end
    local function getInstance(guid, at)
        if not at or not creatureID(guid) then return end
        pruneInstances(at)
        return killInstances[guid]
    end
    local function startPending(observed, at)
        -- Repeated scans/events never extend an ambiguous death indefinitely.
        observed.deadline = observed.deadline or (at + pendingSeconds)
    end
    local function actorRole(guid)
        if not str(guid) then return end
        for _, unit in ipairs({ "player", "pet", "party1", "partypet1", "party2", "partypet2",
            "party3", "partypet3", "party4", "partypet4" }) do
            local candidate = read(UnitGUID, unit)
            if str(candidate) and candidate == guid then return unit end
        end
    end
    local function sampleEligibility(observed, unit, guid)
        if read(UnitGUID, unit) ~= guid then return end
        local exists, controlled = read(UnitExists, unit), read(UnitPlayerControlled, unit)
        local denied = read(UnitIsTapDenied, unit)
        if read(UnitGUID, unit) ~= guid then return end
        if controlled == true or denied == true then
            observed.rejected, observed.eligible = true, nil
        elseif exists == true and controlled == false and denied == false then
            observed.eligible = true
        end
        -- Missing/error/secret values leave eligibility unknown. In particular,
        -- false denial is useful ONLY alongside a qualifying PARTY_KILL event.
    end
    local function completeKill(self, guid, observed)
        if observed.rejected then return decision(guid, "rejected: tap denied or player-controlled") end
        if not observed.actor then return decision(guid, "pending: no qualifying PARTY_KILL") end
        if not observed.dead then return decision(guid, "pending: death not readable yet") end
        if observed.eligible ~= true then return decision(guid, "pending: eligibility unknown") end
        local id, entry = observed.id, self.entries[observed.id]
        if not entry then return decision(guid, "rejected: entry removed") end
        local credit = creditFor(id)
        if killedGUIDs[guid] then return decision(guid, "duplicate") end
        for _, previous in ipairs(credit.killGUIDs) do
            if previous == guid then return decision(guid, "duplicate") end
        end
        -- Consume evidence before callbacks; failed/early attempts consume none.
        killInstances[guid] = nil
        killedGUIDs[guid] = true
        recentKills[#recentKills + 1] = guid
        if #recentKills > recentLimit then killedGUIDs[table.remove(recentKills, 1)] = nil end
        credit.killGUIDs[#credit.killGUIDs + 1] = guid
        if #credit.killGUIDs > 16 then table.remove(credit.killGUIDs, 1) end
        self:Ensure(id)
        entry.kills = math.max(0, tonumber(entry.kills) or 0) + 1
        self:Touch()
        local points, star = self:GetKillReward(id)
        local newlyEarned = math.max(0, points - credit.killPoints)
        credit.killPoints = math.max(credit.killPoints, points)
        award(self, entry, newlyEarned, star == "crown" and "gold crown" or (star or "kill") .. " star")
        return decision(guid, "accepted", newlyEarned)
    end
    function journal:ClearKillEvidence()
        killInstances = {}
    end
    function journal:RecordPartyKill(attackerGUID, victimGUID)
        local at = now()
        if not creatureID(victimGUID) then return false end
        if killedGUIDs[victimGUID] then return decision(victimGUID, "duplicate") end
        local observed = getInstance(victimGUID, at)
        if not observed then return decision(victimGUID, "rejected: no recent living observation") end
        local role = actorRole(attackerGUID)
        if not role then return decision(victimGUID, "rejected: attacker not readable player/pet/party") end
        observed.actor = role
        startPending(observed, at)
        -- Query only watched tokens that STILL identify this event's victim.
        -- Eligibility is sampled only with a kill/death notification or corpse,
        -- never cached from ordinary living observations before either event.
        for _, unit in ipairs({ "target", "mouseover" }) do
            sampleEligibility(observed, unit, victimGUID)
        end
        return completeKill(self, victimGUID, observed)
    end
    function journal:RecordUnitDeath(guid)
        if not creatureID(guid) then return false end
        if killedGUIDs[guid] then return decision(guid, "duplicate") end
        local at = now()
        local observed = getInstance(guid, at)
        if not observed then return false end
        observed.dead = true
        startPending(observed, at)
        for _, unit in ipairs({ "target", "mouseover" }) do
            sampleEligibility(observed, unit, guid)
        end
        return completeKill(self, guid, observed)
    end
    function journal:RecordKill(unit)
        if ns.KillDiagnostics and ns.KillDiagnostics.enabled then ns.KillDiagnostics:Sample(unit, self) end
        local guid, at = read(UnitGUID, unit), now()
        if not creatureID(guid) then return false end
        if killedGUIDs[guid] then return decision(guid, "duplicate") end
        local observed = getInstance(guid, at)
        if not observed then return false end
        local dead = read(UnitIsDead, unit)
        if read(UnitGUID, unit) ~= guid then return false end
        if dead == false then
            -- A reset/evade or living reappearance invalidates terminal evidence.
            -- Ordinary live tap/threat/combat observations never authorize kills.
            if read(UnitAffectingCombat, unit) ~= true then
                clearTerminal(guid, observed)
            end
            return false
        end
        if dead ~= true then return false end
        observed.dead = true
        startPending(observed, at)
        sampleEligibility(observed, unit, guid)
        return completeKill(self, guid, observed)
    end
    function journal:Offer(id, name, origin, spellID, observedCreatureName)
        name = clean(name, 100)
        if not name or name:lower() == "attack" then return end
        local wasNamed = self:GetCreatureName(id)
        local entry, discovered = self:Ensure(id, false, observedCreatureName)
        if not entry or entry.confirmed then return end
        if entry.ignoredAbilities and entry.ignoredAbilities[name] then return end
        -- Rejected observations stay rejected when automatic scans repeat.
        if not entry.abilities[name] then
            entry.abilities[name] = { state = "pending", origin = origin or "Observed", spellID = number(spellID) and spellID or nil }
            self:Touch()
        elseif number(spellID) and not entry.abilities[name].spellID then
            entry.abilities[name].spellID = spellID
            self:Touch()
        end
        if not wasNamed and onEntryAdded then onEntryAdded(entry, discovered) end
        return true
    end
    function journal:SetEntryConfirmed(id, confirmed)
        local entry = self.entries[id]
        if not entry then return false end
        if confirmed==true and not entry.confirmed and self.GetBasicInfo then
            entry.lockedBasic = self:GetBasicInfo(id)
        elseif confirmed~=true then entry.lockedBasic=nil end
        entry.confirmed = confirmed == true
        self:Touch()
        return true
    end
    function journal:SetAbility(id, name, state)
        local entry = self.entries[id]
        if not entry or entry.confirmed or not entry.abilities[name] then return false end
        if state ~= "confirmed" and state ~= "rejected" and state ~= "pending" then return false end
        entry.abilities[name].state = state
        if state=="confirmed" and self.ResolveRumours then
            self:ResolveRumours(id,{kind="ability",value=name,spellID=entry.abilities[name].spellID})
        end
        self:Touch()
        return true
    end
    function journal:SetAbilityTooltip(id, name, enabled)
        local entry = self.entries[id]
        if not entry or entry.confirmed or not entry.abilities[name] then return false end
        entry.abilities[name].showInTooltip = enabled == true
        self:Touch()
        return true
    end
    function journal:RemoveAbility(id, name)
        local entry = self.entries[id]
        if not entry or entry.confirmed or not entry.abilities[name] then return false end
        entry.abilities[name] = nil
        entry.ignoredAbilities = entry.ignoredAbilities or {}
        entry.ignoredAbilities[name] = true
        self:Touch()
        return true
    end
    function journal:GetIDNotes(id)
        local entry = self.entries[id]
        if not entry then return end
        return entry.idNotes or { spells = {}, text = "" }
    end
    function journal:AddNoteSpell(id, reference)
        local entry = self.entries[id]
        if not entry then return false, "Select a creature in the Bestiary first." end
        local spellID = str(reference) and tonumber(reference:match("^%s*(%d+)%s*$"))
        if not number(spellID) or spellID > 2147483647 then return false, "Enter a positive numeric spell ID." end
        local log = self:GetIDNotes(id)
        for _, existing in ipairs(log.spells) do
            if existing == spellID then return false, "That spell ID is already recorded." end
        end
        if #log.spells >= 10 then return false, "Ten abilities recorded. Remove a row to add another." end
        log.spells[#log.spells + 1] = spellID
        entry.idNotes = log
        self:Touch()
        return true
    end
    function journal:RemoveNoteSpell(id, spellID)
        local log = self:GetIDNotes(id)
        if not log then return false end
        for index, existing in ipairs(log.spells) do
            if existing == spellID then table.remove(log.spells, index); self:Touch(); return true end
        end
        return false
    end
    function journal:SetCreatureNotes(id, text)
        local entry = self.entries[id]
        if not entry or not public(text) or type(text) ~= "string" then return false end
        -- Literal manual notes; preserve line breaks but not embedded UI markup.
        text = text:gsub("|", ""):gsub("%c", function(character)
            return (character == "\n" or character == "\t") and character or ""
        end)
        local characters = 0
        for position in text:gmatch("()[^\128-\191]") do
            characters = characters + 1
            if characters > 400 then text = text:sub(1, position - 1); break end
        end
        local log = self:GetIDNotes(id)
        if log.text == text then return true end
        log.text = text; entry.idNotes = log; self:Touch()
        return true
    end
    function journal:ResolveSpell(reference)
        if not str(reference) or not reference:match("%S") then return end
        local identifier = reference:match("^%s*(.-)%s*$")
        local combat = read(InCombatLockdown)
        if combat ~= false then return nil, nil, "Spell linking is available outside combat." end
        local spellID = tonumber(identifier:match("^(%d+)$"))
            or tonumber(identifier:match("|Hspell:(%d+)[:|]"))
        if not number(spellID) and C_Spell then
            spellID=read(C_Spell.GetSpellIDForSpellIdentifier, identifier)
        end
        if not number(spellID) and C_Spell then
            local link=read(C_Spell.GetSpellLink, identifier)
            if str(link) then spellID=tonumber(link:match("|Hspell:(%d+)[:|]")) end
        end
        if not number(spellID) and C_Spell then
            local info=read(C_Spell.GetSpellInfo, identifier)
            if type(info)=="table" and number(info.spellID) then spellID=info.spellID end
        end
        if not number(spellID) then return nil, nil, "No readable exact match for '" .. identifier .. "'. Use its localized in-game name, an ID, or a spell link." end
        local name = C_Spell and read(C_Spell.GetSpellName, spellID)
        if not str(name) then return nil, nil, "That spell is not readable/cached. Try again, or save the name without a link." end
        return spellID, name
    end
    function journal:ResolveAbility(id, name)
        local entry = self.entries[id]
        local ability = entry and entry.abilities[name]
        if not ability then return false, "Select a recorded ability first." end
        if entry.confirmed then return false, "Unlock this creature before changing its abilities." end
        local reference = number(ability.spellID) and tostring(ability.spellID) or name
        local spellID, linkedName, errorMessage = self:ResolveSpell(reference)
        if errorMessage then return false, errorMessage end
        if not spellID then return false, "No exact readable spell match. Use Edit to enter an ID or spell link." end
        linkedName = clean(linkedName, 100)
        if not linkedName then return false, "The resolved spell name is unavailable." end
        local existing = entry.abilities[linkedName]
        local note, effects = ability.note, {}
        for effect, enabled in pairs(ability.effects or {}) do effects[effect] = enabled end
        if existing and existing ~= ability then
            if number(existing.spellID) and existing.spellID ~= spellID then
                return false, "Another ability named " .. linkedName .. " has a different spell ID. Use Edit to review it."
            end
            if str(existing.note) and existing.note ~= note then
                note = str(note) and (note .. "\n" .. existing.note) or existing.note
                if #note > 300 then return false, "Combining these abilities would exceed the note limit. Use Edit to review their notes." end
            end
            for effect, enabled in pairs(existing.effects or {}) do if enabled then effects[effect] = true end end
        end
        -- The recorded ID is authoritative. Keep the canonical spelling and
        -- suppress the old observation name so rescans/reloads cannot revive it.
        if linkedName ~= name then
            entry.abilities[name] = nil
            entry.ignoredAbilities = entry.ignoredAbilities or {}
            entry.ignoredAbilities[name] = true
        end
        if entry.ignoredAbilities then entry.ignoredAbilities[linkedName] = nil end
        ability.note, ability.effects, ability.origin = note, effects, "Your note"
        ability.spellID = spellID
        if existing and existing.showInTooltip == false then ability.showInTooltip = false end
        entry.abilities[linkedName] = ability
        self:SetAbility(id, linkedName, "confirmed")
        return true, "Ability confirmed: " .. linkedName .. " (ID " .. spellID .. ")."
    end
    function journal:AddManual(id, name, note, reference, effects)
        local entry = self.entries[id]
        if entry and entry.confirmed then return false, "Unlock this creature before changing its abilities." end
        name = clean(name, 100)
        local spellID, linkedName, errorMessage = self:ResolveSpell(reference)
        if errorMessage then return false, errorMessage end
        if linkedName then
            if name and name:lower() ~= linkedName:lower() then
                return false, "The link is for " .. linkedName .. ". Use that name or remove the link."
            end
            name = linkedName
        end
        if not entry or not name then return false, "Select a seen creature and enter an ability name (up to 100 characters)." end
        local cleaned = clean(note, 300)
        if str(note) and not cleaned and note:match("%S") then return false, "Keep the effect note under 300 characters." end
        if entry.ignoredAbilities then entry.ignoredAbilities[name] = nil end
        local savedEffects={}
        if type(effects)=="table" then
            for effect,enabled in pairs(effects) do
                local valid=clean(effect,60)
                if enabled==true and valid then savedEffects[valid]=true end
            end
        end
        entry.abilities[name] = { state = "confirmed", origin = "Your note", note = cleaned, effects = savedEffects, spellID = spellID }
        if self.ResolveRumours then self:ResolveRumours(id,{kind="ability",value=name,spellID=spellID}) end
        self:Touch()
        return true, "Ability confirmed. Lock in the entry to show it in tooltips."
    end
    function journal:AddDamage(id, level, low, high, playerLevel)
        local entry = self.entries[id]
        if entry and entry.confirmed then return false, "Unlock this creature before recording damage." end
        level, low, high = tonumber(level), tonumber(low), tonumber(high)
        playerLevel = playerLevel == nil and level or tonumber(playerLevel)
        if not entry or not number(level) or not number(playerLevel) or not number(low) or not number(high) or low > high then
            return false, "Enter positive whole-number player and creature levels and a valid minimum/maximum hit range."
        end
        if not entry.levelMin or level < entry.levelMin or level > entry.levelMax then
            return false, "That level is outside this creature's observed level range."
        end
        local record = entry.damage[level]
        if not record then record = { notes = {} }; entry.damage[level] = record end
        record.notes = type(record.notes) == "table" and record.notes or {}
        if #record.notes == 0 and record.low and record.high and (record.reports or 0) > 0 then
            record.notes[1] = { low = record.low, high = record.high, legacy = true }
        end
        self:DamageNotes(id, level)
        record.notes[#record.notes + 1] = { low = low, high = high, playerLevel = playerLevel, creatureLevel = level }
        record.low, record.high, record.reports = nil, nil, #record.notes
        for _, note in ipairs(record.notes) do
            record.low = record.low and math.min(record.low, note.low) or note.low
            record.high = record.high and math.max(record.high, note.high) or note.high
        end
        self:Touch()
        return true, "Saved your damage observation."
    end
    function journal:DamageNotes(id, level)
        local entry = self.entries[id]
        local record = entry and entry.damage[level]
        if not record then return {} end
        record.notes = type(record.notes) == "table" and record.notes or {}
        if #record.notes == 0 and record.low and record.high and (record.reports or 0) > 0 then
            record.notes[1] = { low = record.low, high = record.high, legacy = true }
        end
        -- Records made before separate levels were supported were equal-level.
        for _, note in ipairs(record.notes) do
            note.playerLevel = note.playerLevel or level
            note.creatureLevel = note.creatureLevel or level
        end
        return record.notes
    end
    function journal:RemoveDamageNote(id, level, index)
        local entry = self.entries[id]
        if entry and entry.confirmed then return false end
        local record = entry and entry.damage[level]
        local notes = self:DamageNotes(id, level)
        if not record or not number(index) or not notes[index] then return false end
        table.remove(notes, index)
        if #notes == 0 then
            entry.damage[level] = nil
        else
            record.low, record.high, record.reports = nil, nil, #notes
            for _, note in ipairs(notes) do
                record.low = record.low and math.min(record.low, note.low) or note.low
                record.high = record.high and math.max(record.high, note.high) or note.high
            end
        end
        self:Touch()
        return true
    end
    function journal:ConfirmedNames(id)
        local entry, names = self.entries[id], {}
        if entry and entry.confirmed and self:GetCreatureName(id) then
            for name, ability in pairs(entry.abilities) do
            if ability.state == "confirmed" and ability.showInTooltip ~= false then names[#names + 1] = name end
            end
        end
        table.sort(names)
        return names
    end
    function journal:GetCategoryFilter(category)
        if category == "Unclassified" or category == "Not specified"
            or category == "Totem" or category == "Gas Cloud" then return "Other" end
        return category
    end
    function journal:List(category, query, reviewOnly, initial, locations, ranks)
        query = (query or ""):lower()
        local locationFilterActive = type(locations) == "table" and next(locations) ~= nil
        local rows = {}
        for id, entry in pairs(self.entries) do
            local name = self:GetCreatureName(id)
            -- Keep unresolved old records for later identification, without
            -- exposing placeholder pages or counting them as usable entries.
            if name then
                local basic = self.GetBasicInfo and self:GetBasicInfo(id) or entry
                local review = not entry.confirmed
                for _, ability in pairs(entry.abilities) do if ability.state == "pending" then review = true end end
                local first = name:sub(1, 1):upper()
                local locationMatch = not locationFilterActive
                if locationFilterActive then
                    for location in pairs(basic.locations or {}) do
                        if locations[location] then locationMatch = true; break end
                    end
                end
                local categoryMatch = not category or self:GetCategoryFilter(basic.category) == category
                if categoryMatch and (not initial or first == initial)
                    and (not reviewOnly or review)
                    and (not ranks or not next(ranks) or ranks[entry.rank] == true)
                    and locationMatch
                    and (name:lower():find(query, 1, true) or basic.category:lower():find(query, 1, true)) then
                    rows[#rows + 1] = { id = id, name = name, review = review }
                end
            end
        end
        table.sort(rows, function(a, b) if a.name == b.name then return a.id < b.id end return a.name < b.name end)
        return rows
    end
    function journal:Reset()
        trackingDB.bestiary = { entries = {}, creatures = {} }
        self.entries = trackingDB.bestiary.entries
        initializePoints()
        initializeRecentKills()
        seenGUIDs = {}
        killInstances = {}
        if self.sharing then self.sharing:Reset() end
        if ns.UIScale then ns.UIScale:Initialize(db) end
        if ns.MinimapButton then ns.MinimapButton:ApplySettings() end
        self:Touch()
    end
    function journal:ResetDatabase()
        local personalBestiary, trackingKey, eventLog = db.bestiary, db.accountTrackingKey, self:GetEventLog()
        for key in pairs(db) do db[key] = nil end
        db.eventLog=eventLog
        db.version, db.announce, db.creatureAnnouncements = 1, false, true
        db.accountTrackingKey, db.accountWideTracking = trackingKey, activeAccountWideTracking
        if trackingDB ~= db then db.bestiary = personalBestiary end
        db.showSpellIDs, db.spellIDTooltipInitialized = true, true
        db.backgroundBrightness = 1
        self:SetDisplayCastIDs(true)
        if ns.SpellIDWindow then ns.SpellIDWindow:Initialize(db) end
        db.ignoreEncounterHistory = true
        self:Reset()
        -- Closing sharing dialogs during Reset can save their final positions.
        if ns.WindowPositions then ns.WindowPositions:Reset() end
    end
    -- Unknown legacy spell records wait in their original store until a live
    -- observation or an attributed encounter supplies the creature's name.
    restoreObservations = function(self, id)
        local creature = trackingDB.bestiary.creatures[id]
        if not creature or not self:GetCreatureName(id) then return end
        for spellID, spell in pairs(creature.spells or {}) do
            if type(spell) == "table" then self:Offer(id, spell.name, "Previous observations", spellID) end
        end
        for name in pairs(creature.names or {}) do self:Offer(id, name, "Previous observations") end
    end
    if ns.InstallSharingRecords then ns.InstallSharingRecords(journal) end
    for id in pairs(trackingDB.bestiary.creatures) do restoreObservations(journal, id) end
    return journal
end
