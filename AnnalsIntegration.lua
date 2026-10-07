local _,ns=...
local A=ns.Annals
-- Narrow optional publication bus. Sources call this only at an observed or
-- deliberate discovery boundary; imports and database enumeration never emit.
local listeners={}
function ns.RegisterFieldbookDiscoveryListener(key,callback) listeners[key]=callback end
function ns.RecordFieldbookDiscovery(section,entry,owner)
    for _,callback in pairs(listeners) do
        -- A prototype observer cannot prevent a source journal from recording.
        local ok,err=pcall(callback,section,entry,owner)
        if not ok then ns.AnnalsDiscoveryError=tostring(err) end
    end
end
function ns.InitializeAnnals(shell,sources)
    if ns.InitializationBlocked then return end
    if AzerothFieldbookAnnalsDB==nil then AzerothFieldbookAnnalsDB={} end
    local j=ns.CreateAnnalsJournal(AzerothFieldbookAnnalsDB)
    local trail=ns.CreateAnnalsTrail(j);local tracking=ns.CreateAnnalsTracking(j)
    local c=ns.CreateAnnalsBook(j,shell);c.tracking=tracking;c.adapters={}
    local function identity(e)
        if A.Text(e.reference,500) then return e.reference end
        local origin=type(e.origin)=='table' and e.origin or nil
        return tostring(origin and (origin.key or origin.id) or e.created or e.firstSeen or e.firstEncounter or e.first or '')
    end
    function c:RegisterReference(section,adapter) self.adapters[section]=adapter end
    function c:Resolve(link)
        local adapter=type(link)=='table' and self.adapters[link.section]
        return adapter and adapter.resolve(link)
    end
    function c:OpenLink(link)
        local e=self:Resolve(link);if not e then return false,'The linked record is unavailable in this scope. Its historical label is retained.' end
        return self.adapters[link.section].open(e)
    end
    for section,source in pairs(sources or {}) do
        local id,owner=section,source;local journal=owner.journal or owner
        local function find(link)
            if ns.InitializationBlocked then return end
            if id=='atlas' and journal.entrances and not tostring(link.identity):match('^atlas:') then
                local reference=link.identity
                local entrance=journal.entrances:Get(link.key)
                local personal=AzerothFieldbookAtlasDB
                local old=type(personal)=='table' and type(personal.entrances)=='table'
                    and type(personal.entrances.records)=='table' and personal.entrances.records[link.key]
                old=ns.AtlasEntrances.Valid(old) and old or nil
                -- Old Annals links contain only a local key and timestamp. Resolve
                -- through this character's retained original, never another owner's key.
                if old and tostring(old.firstSeen)==link.identity then reference=old.reference end
                if journal.saved==personal and entrance and tostring(entrance.firstSeen)==link.identity then return entrance end
                local found
                for key in pairs(journal.entrances.records) do
                    local candidate=journal.entrances:Get(key)
                    if candidate and candidate.reference and candidate.reference==reference then
                        if found then return end -- Ambiguous identity is unavailable.
                        found=candidate
                    end
                end
                if found then return found end
                -- Pre-reference secondary imports used char<owner>:<serial>.
                -- Recover only within that owner's namespace and only when the
                -- retained original's immutable traversal evidence is unique.
                local character=type(AzerothFieldbookDB)=='table' and AzerothFieldbookDB.accountTrackingKey
                local account=AzerothFieldbookAccountDB
                if old and tostring(old.firstSeen)==link.identity and character and type(account)=='table'
                    and account.sections and journal.saved==account.sections.atlas then
                    local prefix='char'..character..':'
                    for key in pairs(journal.entrances.records) do
                        local candidate=journal.entrances:Get(key)
                        local owned=type(key)=='string' and key:sub(1,#prefix)==prefix
                            or account.atlasFirstImport==character and key==link.key
                        if owned and candidate and candidate.firstSeen==old.firstSeen
                            and candidate.exterior.mapID==old.exterior.mapID
                            and candidate.exterior.x==old.exterior.x and candidate.exterior.y==old.exterior.y
                            and candidate.interior.zoneMapID==old.interior.zoneMapID
                            and candidate.interior.bestMapID==old.interior.bestMapID
                            and candidate.interior.microMapID==old.interior.microMapID
                            and candidate.interior.subzone==old.interior.subzone then
                            if found then return end
                            found=candidate
                        end
                    end
                    if found then return found end
                end
                if old or entrance or tostring(link.key):match('^n%d+$') or tostring(link.identity):match('^atlas%-entrance:') then return end
            end
            local e=journal.Get and journal:Get(link.key) or (journal.entries and journal.entries[tonumber(link.key) or link.key])
            if e and not e.removed and identity(e)==link.identity then return e end
            -- Durable references resolve ID remapping without matching unrelated reused IDs.
            if journal.Reference then e=journal:Reference(link.identity);if e and identity(e)==link.identity then return e end end
            if id=='atlas' and journal.records then for _,record in pairs(journal.records) do if identity(record)==link.identity then return record end end end
            if id=='angling' and journal.db then
                for _,bucket in ipairs({'waters','spots','pools','items'}) do for _,record in pairs(journal.db[bucket] or {}) do
                    if not record.removed then
                        if identity(record)==link.identity then return record end
                        for _,old in ipairs(type(record.origin)=='table' and record.origin.legacyKeys or {}) do if old==link.identity then return record end end
                    end
                end end
            end
        end
        c:RegisterReference(id,{resolve=find,open=function(e)
            if id=='bestiary' then return shell:ShowSection(id,{creatureID=e.id}) end
            if id=='lore' then return shell:ShowSection(id,{entryID=e.id}) end
            shell:ShowSection(id)
            if id=='atlas' and type(owner.Select)=='function' then
                local entrance=journal.entrances and journal.entrances:Get(e.id)
                local key=entrance and entrance.reference==e.reference and ns.AtlasEntrances.PREFIX..e.id or e.id
                owner:Select(key)
                return journal.state.selected==key
            end
            if type(owner.Select)=='function' then owner:Select(e.id);return true end
            if type(owner.OpenEntry)=='function' then owner:OpenEntry(e.id);return true end
            return false,'Opened the journal. Select '..tostring(e.name or e.title or e.id)..' in its index.'
        end})
    end
    ns.RegisterFieldbookDiscoveryListener('annals',function(section,e,publisher)
        if type(e)~='table' or not e.id or not c.adapters[section] then return end
        local owner=sources[section];local active=owner and (owner.journal or owner)
        if publisher and publisher~=active and publisher~=(active and active.entrances) then return end
        local definition=shell.sections[section] and shell.sections[section].definition
        local label=e.name or e.title
        if section=='bestiary' and sources.bestiary.GetCreatureName then label=sources.bestiary:GetCreatureName(e.id) end
        j:Discover(section,tostring(e.id),label or tostring(e.id),definition and definition.icon,identity(e))
    end)
    ns.AnnalsController=c;tracking:Start();return c
end
