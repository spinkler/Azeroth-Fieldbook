local _,ns=...
local L=ns.Lore
local titles={bestiary='Bestiary',gathering="Gatherer's Compendium",atlas='Traveller’s Atlas',
    angling='Angler’s Almanac',merchants='Merchant’s Ledger',treasure='Treasure Journal'}
local function stamp(e)
    if type(e.reference)=='string' then return e.reference end
    local time=e.created or e.firstSeen or e.firstEncounter or e.first
    if type(time)=='number' then return tostring(time) end
    local name=tostring(e.name or e.title or '')
    local hash=0;for i=1,#name do hash=(hash*31+name:byte(i))%2147483647 end
    return tostring(hash)
end
-- Enumerate only active, already-known records. No discoveries are synthesized,
-- no source database is changed, and foreign report references use labels only.
function ns.RegisterLoreReferences(controller,shell,sources)
    for section,source in pairs(sources or {}) do if type(source)=='table' then
        local id,owner=section,source
        local journal=owner.journal or owner
        local function records()
            local all={}
            if id=='angling' then
                for _,bucket in ipairs({'waters','spots','pools','items'}) do for key,e in pairs(journal.db and journal.db[bucket] or {}) do
                    if type(e)=='table' and not e.removed then all[key]=e end
                end end
            else
                local known=id=='atlas' and journal.records or id=='merchants' and journal.db and journal.db.contacts
                    or id=='treasure' and journal.kinds or journal.entries or {}
                for key,e in pairs(known) do if type(e)=='table' and not e.removed then all[key]=e end end
            end
            return all
        end
        local function ref(key,e)
            local scope=id=='angling' and journal.db and journal.db.origin or ''
            local identity=(id=='atlas' or id=='merchants' or id=='treasure') and e.reference
            return {key=identity or tostring(key)..'@'..scope..':'..stamp(e),name=tostring(e.name or e.title or (journal.GetCreatureName and journal:GetCreatureName(key)) or key)}
        end
        local function find(key,link)
            if ns.InitializationBlocked or type(key)~='string' then return end
            if id=='atlas' and ns.ResolveAtlasLoreReference and journal.saved then
                return ns.ResolveAtlasLoreReference(journal,key,link and link.atlasOwner)
            end
            if id=='atlas' and journal.saved and journal.saved.loreAliases then
                key=journal.saved.loreAliases[key] or key
            elseif (id=='merchants' and journal.Reference) or id=='treasure' then
                local reference=key:match('^.-@:(.+)$') or key
                local e=journal.Reference and journal:Reference(reference);if e then return e.id,e end
                -- A known record can predate its lookup index. Require its full
                -- durable reference; a matching local ID is never a fallback.
                for recordID,known in pairs(records()) do
                    if known.reference==reference then return recordID,known end
                end
                return
            end
            for recordID,e in pairs(records()) do if ref(recordID,e).key==key then return recordID,e end end
        end
        controller.references:Register(id,{title=titles[id] or id,list=function()
            local rows={};for key,e in pairs(records()) do rows[#rows+1]=ref(key,e) end;return rows
        end,resolve=function(key,link) local recordID,e=find(key,link);if e then return ref(recordID,e) end end,
        open=function(key,link)
            local recordID,e=find(key,link);if not e then return false,'The linked record is no longer available.' end
            if id=='bestiary' then return shell:ShowSection(id,{creatureID=recordID}) end
            if type(owner.Select)=='function' then shell:ShowSection(id);owner:Select(recordID);return true end
            if type(owner.OpenEntry)=='function' then return owner:OpenEntry(recordID) end
            return false,(titles[id] or id)..': '..ref(recordID,e).name..'. Select this known entry in its journal; direct entry navigation is unavailable.'
        end})
    end end
end
function ns.InitializeLore(shell,settings,sources)
    if ns.InitializationBlocked then return end
    if AzerothFieldbookLoreDB==nil then AzerothFieldbookLoreDB={} end
    ns.LoreSettings.Initialize(settings or AzerothFieldbookDB or {})
    local store=AzerothFieldbookLoreDB
    if ns.SelectSectionStorage then store=ns.SelectSectionStorage("lore",store) end
    local journal=ns.CreateLoreJournal(store)
    local eventJournal=sources and sources.bestiary
    local kindNames={writing="Writing",landmark="Landmark",person="Person",mystery="Mystery"}
    journal.onRecorded=function(entry)
        local title=entry.title:gsub("[\r\n]+"," ")
        local automatic=L.IsAutomatic(entry)
        local message=shell.sections.lore.definition.title.." recorded: "..L.AutomaticLabel(title,automatic).." ("..(kindNames[entry.kind] or "Lore")..")."
        if eventJournal and eventJournal.RecordEvent then
            eventJournal:RecordEvent(message,{kind="lore-recorded",loreID=entry.id,loreKind=entry.kind,origin=entry.origin,automatic=automatic})
        end
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff80d0ffAFB:|r "..message) end
    end
    local tracking=ns.CreateLoreTracking(journal,ns.LoreSettings.db)
    ns.LoreSettings.tracking=tracking
    local controller=ns.CreateLoreBook(journal,tracking,shell)
    ns.RegisterLoreReferences(controller,shell,sources)
    return controller
end
