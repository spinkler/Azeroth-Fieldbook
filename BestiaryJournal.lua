local _, ns = ...

function ns.CreateBestiaryJournal(db, identify)
    db.bestiary = type(db.bestiary) == "table" and db.bestiary or {}
    db.bestiary.entries = type(db.bestiary.entries) == "table" and db.bestiary.entries or {}
    db.bestiary.creatures = type(db.bestiary.creatures) == "table" and db.bestiary.creatures or {}
    local journal = { entries = db.bestiary.entries, revision = 0 }
    local seenGUIDs = {}
    local killedGUIDs = {}
    local onEntryAdded
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
    local function clean(value, limit)
        if not str(value) then return end
        -- Literal field notes only: no links, textures, colors or control codes.
        value = value:gsub("|", ""):gsub("[%c]", " "):match("^%s*(.-)%s*$")
        if value == "" or #value > limit then return end
        return value
    end
    function journal:Touch() self.revision = self.revision + 1 end
    function journal:SetEntryAddedCallback(callback)
        onEntryAdded = type(callback) == "function" and callback or nil
    end
    function journal:GetCreatureAnnouncement()
        return db.creatureAnnouncements == true
    end
    function journal:SetCreatureAnnouncement(enabled)
        db.creatureAnnouncements = enabled == true
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
    function journal:Ensure(id)
        if not number(id) then return end
        local entry = self.entries[id]
        if not entry then
            entry = { id = id, category = "Unclassified", abilities = {}, damage = {}, locations = {}, offenses = {}, resistances = {}, immunities = {}, behaviours = {}, kills = 0, confirmed = false }
            self.entries[id] = entry
            self:Touch()
        end
        return entry
    end
    function journal:Observe(unit)
        local id = identify(unit)
        if not id then return end
        local name = read(UnitName, unit)
        if not str(name) then return end
        local entry = self:Ensure(id)
        local wasNamed = str(entry.name)
        local category, level, classification = read(UnitCreatureType, unit), read(UnitLevel, unit), read(UnitClassification, unit)
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
        local location = read(GetRealZoneText) or read(GetZoneText)
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
        if not wasNamed and onEntryAdded then onEntryAdded(entry) end
        if changed then self:Touch() end
        return id
    end
    local function setSchoolObservation(self, id, field, school, enabled)
        local entry = self.entries[id]
        if not entry or not magicSchools[school] then return false end
        entry[field] = type(entry[field]) == "table" and entry[field] or {}
        local value = enabled == true and true or nil
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
        if not entry or not behaviourNames[name] then return false end
        entry.behaviours = type(entry.behaviours) == "table" and entry.behaviours or {}
        local value = enabled == true and true or nil
        if value and name == "Hostile" then entry.behaviours.Neutral = nil end
        if value and name == "Neutral" then entry.behaviours.Hostile = nil end
        if entry.behaviours[name] == value then return true end
        entry.behaviours[name] = value
        self:Touch()
        return true
    end
    function journal:RecordKill(unit)
        if read(UnitIsDead, unit) ~= true then return false end
        local id = identify(unit)
        local entry = id and self.entries[id]
        local guid = read(UnitGUID, unit)
        if not entry or not str(guid) or killedGUIDs[guid] then return false end
        killedGUIDs[guid] = true
        entry.kills = math.max(0, tonumber(entry.kills) or 0) + 1
        self:Touch()
        return true
    end
    function journal:Offer(id, name, origin, spellID)
        name = clean(name, 100)
        if not name then return end
        local entry = self:Ensure(id)
        if not entry then return end
        if entry.ignoredAbilities and entry.ignoredAbilities[name] then return end
        -- Rejected observations stay rejected when automatic scans repeat.
        if not entry.abilities[name] then
            entry.abilities[name] = { state = "pending", origin = origin or "Observed", spellID = number(spellID) and spellID or nil }
            self:Touch()
        elseif number(spellID) and not entry.abilities[name].spellID then
            entry.abilities[name].spellID = spellID
            self:Touch()
        end
    end
    function journal:SetEntryConfirmed(id, confirmed)
        local entry = self.entries[id]
        if not entry then return false end
        entry.confirmed = confirmed == true
        self:Touch()
        return true
    end
    function journal:SetAbility(id, name, state)
        local entry = self.entries[id]
        if not entry or not entry.abilities[name] then return false end
        if state ~= "confirmed" and state ~= "rejected" and state ~= "pending" then return false end
        entry.abilities[name].state = state
        self:Touch()
        return true
    end
    function journal:SetAbilityTooltip(id, name, enabled)
        local entry = self.entries[id]
        if not entry or not entry.abilities[name] then return false end
        entry.abilities[name].showInTooltip = enabled == true
        self:Touch()
        return true
    end
    function journal:RemoveAbility(id, name)
        local entry = self.entries[id]
        if not entry or not entry.abilities[name] then return false end
        entry.abilities[name] = nil
        entry.ignoredAbilities = entry.ignoredAbilities or {}
        entry.ignoredAbilities[name] = true
        self:Touch()
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
    function journal:AddManual(id, name, note, reference, effects)
        local entry = self.entries[id]
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
        self:Touch()
        return true, "Ability confirmed. Lock in the entry to show it in tooltips."
    end
    function journal:AddDamage(id, level, low, high)
        local entry = self.entries[id]
        level, low, high = tonumber(level), tonumber(low), tonumber(high)
        if not entry or not number(level) or not number(low) or not number(high) or low > high then
            return false, "Enter a shared level and a positive minimum/maximum hit range."
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
        record.notes[#record.notes + 1] = { low = low, high = high }
        record.low, record.high, record.reports = nil, nil, #record.notes
        for _, note in ipairs(record.notes) do
            record.low = record.low and math.min(record.low, note.low) or note.low
            record.high = record.high and math.max(record.high, note.high) or note.high
        end
        self:Touch()
        return true, "Saved your equal-level damage observation."
    end
    function journal:DamageNotes(id, level)
        local entry = self.entries[id]
        local record = entry and entry.damage[level]
        if not record then return {} end
        record.notes = type(record.notes) == "table" and record.notes or {}
        if #record.notes == 0 and record.low and record.high and (record.reports or 0) > 0 then
            record.notes[1] = { low = record.low, high = record.high, legacy = true }
        end
        return record.notes
    end
    function journal:RemoveDamageNote(id, level, index)
        local entry = self.entries[id]
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
        if entry and entry.confirmed then
            for name, ability in pairs(entry.abilities) do
            if ability.state == "confirmed" and ability.showInTooltip ~= false then names[#names + 1] = name end
            end
        end
        table.sort(names)
        return names
    end
    function journal:List(category, query, reviewOnly, initial, locations)
        query = (query or ""):lower()
        local locationFilterActive = type(locations) == "table" and next(locations) ~= nil
        local rows = {}
        for id, entry in pairs(self.entries) do
            local name = entry.name or ("Encountered creature #" .. id)
            local review = not entry.confirmed
            for _, ability in pairs(entry.abilities) do if ability.state == "pending" then review = true end end
            local first = name:sub(1, 1):upper()
            local locationMatch = not locationFilterActive
            if locationFilterActive then
                for location in pairs(entry.locations or {}) do
                    if locations[location] then locationMatch = true; break end
                end
            end
            local categoryMatch = not category or entry.category == category
                or (category == "Unclassified" and entry.category == "Not specified")
            if categoryMatch and (not initial or first == initial)
                and (not reviewOnly or review)
                and locationMatch
                and (name:lower():find(query, 1, true) or entry.category:lower():find(query, 1, true)) then
                rows[#rows + 1] = { id = id, name = name, review = review }
            end
        end
        table.sort(rows, function(a, b) if a.name == b.name then return a.id < b.id end return a.name < b.name end)
        return rows
    end
    function journal:Reset()
        db.bestiary = { entries = {}, creatures = {} }
        self.entries = db.bestiary.entries
        seenGUIDs = {}
        killedGUIDs = {}
        self:Touch()
    end
    function journal:ResetDatabase()
        for key in pairs(db) do db[key] = nil end
        db.version, db.bestiary, db.announce, db.creatureAnnouncements = 1, { entries = {}, creatures = {} }, false, true
        db.showSpellIDs, db.spellIDTooltipInitialized = true, true
        db.backgroundBrightness = 1
        db.ignoreEncounterHistory = true
        self:Reset()
    end
    -- Preserve old observations but ask for review; never invent names/levels.
    for id, creature in pairs(db.bestiary.creatures) do
        for spellID, spell in pairs(creature.spells or {}) do
            if type(spell) == "table" then journal:Offer(id, spell.name, "Previous observations", spellID) end
        end
        for name in pairs(creature.names or {}) do journal:Offer(id, name, "Previous observations") end
    end
    return journal
end
