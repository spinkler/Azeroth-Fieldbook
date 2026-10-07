local _, ns = ...

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

-- Keep the account's existing decisions when scalar values conflict. Original
-- character journals remain intact and accessible with account tracking off.
local function mergeMissing(target, source)
    for key, value in pairs(source or {}) do
        if target[key] == nil then target[key] = copy(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            mergeMissing(target[key], value)
        end
    end
end

local function equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local function appendUnique(target, source, limit)
    for _, value in ipairs(source or {}) do
        local found = false
        for _, existing in ipairs(target) do if equal(existing, value) then found = true; break end end
        if not found and (not limit or #target < limit) then target[#target + 1] = copy(value) end
    end
end

local function minimum(left, right)
    if type(left) ~= "number" then return right end
    if type(right) ~= "number" then return left end
    return math.min(left, right)
end

local function maximum(left, right)
    if type(left) ~= "number" then return right end
    if type(right) ~= "number" then return left end
    return math.max(left, right)
end

local function combineText(left, right, limit, unicode)
    if not left or left == "" then return right end
    if not right or right == "" or left == right then return left end
    local combined = left .. "\n" .. right
    -- Respect the editor's limit; never truncate either original note.
    local characters = #combined
    if unicode then
        local _, count = combined:gsub("[^\128-\191]", "")
        characters = count
    end
    return characters <= limit and combined or left
end

local ranks = { Rare = 1, Elite = 2, ["Rare Elite"] = 3, ["World Boss"] = 4 }
local function mergeEntry(target, source)
    ns.MigrateDisposition(target);ns.MigrateDisposition(source)
    target.firstEncounteredAt=ns.EarliestEncounterTime(target.firstEncounteredAt,source.firstEncounteredAt)
    for _,field in ipairs({"loot","pickpocketLoot"}) do
    if source[field] then
        target[field]=target[field] or {samples=0,items={},recent={}}
        target[field].samples=target[field].samples+source[field].samples
        for id,item in pairs(source[field].items) do
            local into=target[field].items[id] or {quantity=0,drops=0}
            into.quantity=into.quantity+item.quantity;into.drops=into.drops+item.drops
            target[field].items[id]=into
        end
        for _,record in ipairs(source[field].recent) do
            target[field].recent[#target[field].recent+1]=copy(record)
            if #target[field].recent>128 then table.remove(target[field].recent,1) end
        end
    end
    end
    target.kills = (tonumber(target.kills) or 0) + (tonumber(source.kills) or 0)
    target.sightings = (tonumber(target.sightings) or 0) + (tonumber(source.sightings) or 0)
    if ns.CreatureLocations then
        ns.CreatureLocations.Merge(target,source.killLocations)
        ns.CreatureLocations.Merge(target,source.observationLocations,"observations")
    end
    target.levelMin = minimum(target.levelMin, source.levelMin)
    target.levelMax = maximum(target.levelMax, source.levelMax)
    if (ranks[source.rank] or 0) > (ranks[target.rank] or 0) then target.rank = source.rank end
    if not target.name or target.name == "" then target.name = source.name end
    if not target.category or target.category == "Unclassified" or target.category == "Not specified" then
        target.category = source.category or target.category
    end
    target.personalEncountered = target.personalEncountered == true or source.personalEncountered == true
    if source.beastLore and (not target.beastLore or (target.beastLoreSource~="gameTooltip" and source.beastLoreSource=="gameTooltip")) then
        target.beastLore=copy(source.beastLore)
        target.beastLoreSource=source.beastLoreSource
        target.beastLoreSender=source.beastLoreSender
    end
    if target.tameabilitySource~="gameTooltip" and source.tameabilitySource=="gameTooltip" then
        target.tameable=source.tameable;target.tameabilitySource="gameTooltip"
    end
    target.confirmed = target.confirmed == true and source.confirmed == true
    -- Preserve the account's locked snapshot until the page is unlocked.
    if not target.confirmed then target.lockedBasic = nil end
    target.behaviours=target.behaviours or {}
    target.behaviourSources=target.behaviourSources or {}
    target.ignoredBehaviours=target.ignoredBehaviours or {}
    for name,ignored in pairs(source.ignoredBehaviours or {}) do
        if ignored and (not target.behaviours[name] or target.behaviourSources[name]) then
            target.behaviours[name]=nil
            target.ignoredBehaviours[name]=true
        end
    end
    for name,enabled in pairs(source.behaviours or {}) do
        if enabled and not target.ignoredBehaviours[name] and not target.behaviours[name] then
            target.behaviours[name]=true
        end
    end
    -- Automatic evidence remains historical even while its checkbox is off.
    mergeMissing(target.behaviourSources,source.behaviourSources)
    for _, field in ipairs({"locations", "subzones", "offenses", "resistances", "immunities", "ignoredTypeImmunities", "ignoredAbilities"}) do
        target[field] = target[field] or {}
        mergeMissing(target[field], source[field])
    end
    target.abilities = target.abilities or {}
    for name, ability in pairs(source.abilities or {}) do
        local existing = target.abilities[name]
        if existing then
            existing.note = combineText(existing.note, ability.note, 300)
            mergeMissing(existing, ability)
        elseif not target.ignoredAbilities[name] then target.abilities[name] = copy(ability) end
    end
    target.damage = target.damage or {}
    for level, record in pairs(source.damage or {}) do
        local existing = target.damage[level]
        if not existing then target.damage[level] = copy(record)
        else
            local function notes(value)
                if value.notes and #value.notes > 0 then return value.notes end
                if value.low and value.high then return {{low=value.low, high=value.high, legacy=true}} end
                return {}
            end
            local merged = copy(notes(existing))
            for _, note in ipairs(notes(record)) do merged[#merged + 1] = copy(note) end
            for _, field in ipairs({"low", "normalLow", "critLow"}) do existing[field] = minimum(existing[field], record[field]) end
            for _, field in ipairs({"high", "normalHigh", "critHigh"}) do existing[field] = maximum(existing[field], record[field]) end
            existing.notes, existing.reports = merged, #merged
            for _, field in ipairs({"normalCount", "critCount"}) do
                existing[field] = (existing[field] or 0) + (record[field] or 0)
            end
        end
    end
    if source.idNotes then
        target.idNotes = target.idNotes or {spells={}, text=""}
        target.idNotes.spells = target.idNotes.spells or {}
        appendUnique(target.idNotes.spells, source.idNotes.spells, 10)
        target.idNotes.text = combineText(target.idNotes.text, source.idNotes.text, 400, true)
    end
    for _, field in ipairs({"rumours", "sharedReports"}) do
        if source[field] then
            target[field] = target[field] or {}
            appendUnique(target[field], source[field])
        end
    end
    -- Preserve any older fields without replacing the explicitly merged lists.
    for key, value in pairs(source) do if target[key] == nil and key ~= "lockedBasic" then target[key] = copy(value) end end
end

-- Ephemeral outcomes collected only after existing import commits. This does
-- not select stores or replace any of the per-section replay guards.
local trackingResult
function ns.RecordTrackingResult(section, deferred)
    if trackingResult then trackingResult[section] = deferred and "deferred" or "imported" end
end

function ns.ReportTrackingTransition(settings, say)
    local enabled = settings.accountWideTracking ~= false
    local changed = type(settings.accountTrackingActive) == "boolean" and settings.accountTrackingActive ~= enabled
    local imported, deferred = {}, {}
    for _,section in ipairs({{"bestiary","Bestiary"},{"gathering","Gatherer's Compendium"},{"atlas","Traveller’s Atlas"},
        {"angling","Angler’s Almanac"},{"ledger","Merchant’s Ledger"},{"treasure","Treasure Journal"},{"lore","Lorekeeper's Chronicle"}}) do
        local result = trackingResult and trackingResult[section[1]]
        if result == "imported" then imported[#imported+1] = section[2]
        elseif result == "deferred" then deferred[#deferred+1] = section[2] end
    end
    if enabled and (#imported > 0 or changed) then
        local message = "Account-wide tracking enabled. "
        if #imported > 0 then
            message = message .. "One-time import completed for: " .. table.concat(imported, ", ") .. ". Original character journals retained separately. "
        else
            message = message .. "Resumed existing account journals; previously imported sections do not re-import later character-only changes. "
        end
        if #deferred > 0 then message = message .. "Migration deferred for: " .. table.concat(deferred, ", ") .. "; saved data preserved. " end
        say(message .. "Later account and character data are not continuously synchronized.")
    elseif not enabled and changed then
        say("Account-wide tracking disabled. Using this character's separate journals; account data was not copied back. Account journals remain available when re-enabled.")
    end
    settings.accountTrackingActive = enabled
    trackingResult = nil
end

function ns.InitializeTracking(settings)
    if ns.InitializationBlocked then return settings end
    trackingResult = {}
    if type(settings.accountWideTracking) ~= "boolean" then settings.accountWideTracking = true end
    if not settings.accountWideTracking then return settings end
    if type(AzerothFieldbookAccountDB) ~= "table" then AzerothFieldbookAccountDB = {} end
    local account = AzerothFieldbookAccountDB
    account.version = 1
    account.importedCharacters = account.importedCharacters or {}
    account.nextCharacter = tonumber(account.nextCharacter) or 0
    if type(settings.accountTrackingKey) ~= "number" then
        account.nextCharacter = account.nextCharacter + 1
        settings.accountTrackingKey = account.nextCharacter
    end
    local key = settings.accountTrackingKey
    account.nextCharacter = math.max(account.nextCharacter, key)
    if not account.importedCharacters[key] then
        -- Normalize copies with the journal's existing migrations. No live
        -- observations, announcements or messaging occur during this import.
        local sourceDB = {bestiary=copy(settings.bestiary or {}),eventLog=settings.eventLog}
        ns.CreateBestiaryJournal(sourceDB, function() end)
        local mergedDB = {bestiary=copy(account.bestiary or {})}
        local combined = ns.CreateBestiaryJournal(mergedDB, function() end)
        local target, source = mergedDB.bestiary, sourceDB.bestiary
        target.deletedEntries=target.deletedEntries or {}
        for id,deleted in pairs(source.deletedEntries or {}) do
            if deleted and not target.entries[id] and not source.entries[id] then target.deletedEntries[id]=true end
        end
        for id, entry in pairs(source.entries) do
            if not (target.deletedEntries or {})[id] then
                if target.entries[id] then mergeEntry(target.entries[id], entry)
                else target.entries[id] = copy(entry) end
            end
        end
        mergeMissing(target.creatures, source.creatures)
        for id,deleted in pairs(target.deletedEntries or {}) do if deleted then target.creatures[id]=nil end end
        target.zoneTerritories=target.zoneTerritories or {}
        for zone,territories in pairs(source.zoneTerritories or {}) do
            if target.zoneTerritories[zone] then mergeMissing(target.zoneTerritories[zone],territories)
            else
                local count=0;for _ in pairs(target.zoneTerritories) do count=count+1 end
                if count<1024 then target.zoneTerritories[zone]=copy(territories) end
            end
        end
        target.points.earned = target.points.earned + source.points.earned
        target.points.spent = target.points.spent + source.points.spent
        mergeMissing(target.points.reservations, source.points.reservations)
        for id, credit in pairs(source.points.credits) do
            local existing = target.points.credits[id]
            if not existing then target.points.credits[id] = copy(credit)
            else
                existing.firstEncounteredAt=ns.EarliestEncounterTime(existing.firstEncounteredAt,credit.firstEncounteredAt)
                existing.discovered = existing.discovered or credit.discovered
                existing.initial = existing.initial and credit.initial
                existing.points = (existing.points or 0) + (credit.points or 0)
                existing.killPoints = math.max(existing.killPoints or 0, credit.killPoints or 0)
                mergeMissing(existing.levels, credit.levels)
                mergeMissing(existing.zones, credit.zones)
                existing.killGUIDs = existing.killGUIDs or {}
                appendUnique(existing.killGUIDs, credit.killGUIDs)
                while #existing.killGUIDs > 16 do table.remove(existing.killGUIDs, 1) end
            end
            local merged = target.points.credits[id]
            local tier = combined:GetKillReward(id)
            local newlyEarned = math.max(0, tier - (merged.killPoints or 0))
            target.points.earned = target.points.earned + newlyEarned
            merged.killPoints = math.max(tier, merged.killPoints or 0)
        end
        appendUnique(target.recentKills, source.recentKills)
        while #target.recentKills > 512 do table.remove(target.recentKills, 1) end
        target.sharingCharacters = target.sharingCharacters or {}
        target.sharingCharacters[key] = copy(source.sharing or {sequence=0, receipts={}, incoming={}})
        -- Commit only the completed merge, so an interrupted/failed import
        -- cannot leave half-added kills or points to be imported again.
        account.bestiary = target
        -- This registry survives journal resets, preventing old character data
        -- from resurrecting cleared account progress on the next login.
        account.importedCharacters[key] = true
        ns.RecordTrackingResult("bestiary")
    end
    return account
end
