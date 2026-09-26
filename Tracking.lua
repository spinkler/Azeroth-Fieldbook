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
    target.firstEncounteredAt=ns.EarliestEncounterTime(target.firstEncounteredAt,source.firstEncounteredAt)
    target.kills = (tonumber(target.kills) or 0) + (tonumber(source.kills) or 0)
    target.sightings = (tonumber(target.sightings) or 0) + (tonumber(source.sightings) or 0)
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
    for _, field in ipairs({"locations", "offenses", "resistances", "immunities", "behaviours", "ignoredAbilities"}) do
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

function ns.InitializeTracking(settings)
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
        for id, entry in pairs(source.entries) do
            if target.entries[id] then mergeEntry(target.entries[id], entry)
            else target.entries[id] = copy(entry) end
        end
        mergeMissing(target.creatures, source.creatures)
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
    end
    return account
end
