local _,ns=...
local function copy(v)
    if type(v)~="table" then return v end
    local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
local function missing(target,source)
    for k,v in pairs(source or {}) do
        if target[k]==nil then target[k]=copy(v)
        elseif type(v)=="table" and type(target[k])=="table" then missing(target[k],v) end
    end
end
local function notes(a,b)
    if not b or b=="" or a==b then return a end
    if not a or a=="" then return b end
    local combined=a.."\n\n"..b
    return #combined<=4000 and combined or a
end
local function mergeRecord(a,b)
    a.note=notes(a.note,b.note)
    a.favourite=a.favourite or b.favourite
    for _,k in ipairs({"first","firstSeen","personalFirst"}) do
        if b[k] then a[k]=a[k] and math.min(a[k],b[k]) or b[k] end
    end
    for _,k in ipairs({"last","lastSeen","personalLast"}) do
        if b[k] then a[k]=math.max(a[k] or 0,b[k]) end
    end
    if b.claims then
        a.claims=a.claims or {};local seen={}
        for _,id in ipairs(a.claims) do seen[id]=true end
        for _,id in ipairs(b.claims) do if not seen[id] then a.claims[#a.claims+1]=id;seen[id]=true end end
    end
    missing(a,b)
end
local function mergeGathering(target,source)
    target.entries=target.entries or {}
    for id,e in pairs(source.entries or {}) do
        local prior=target.entries[id]
        if prior then
            for _,k in ipairs({"interactions","completed"}) do prior[k]=(prior[k] or 0)+(e[k] or 0) end
            for itemID,item in pairs(e.loot or {}) do
                local old=prior.loot and prior.loot[itemID]
                if type(old)=="table" and type(item)=="table" then
                    for _,field in ipairs({"firstSeen","minQuantity"}) do
                        if type(old[field])=="number" and type(item[field])=="number" then old[field]=math.min(old[field],item[field]) end
                    end
                    for _,field in ipairs({"lastSeen","maxQuantity"}) do
                        if type(old[field])=="number" and type(item[field])=="number" then old[field]=math.max(old[field],item[field]) end
                    end
                end
            end
            mergeRecord(prior,e)
            for mapID,map in pairs(e.locations or {}) do
                local saved=prior.locations and prior.locations[mapID]
                if saved then for key,p in pairs(map.points or {}) do
                    if saved.points[key] then saved.points[key].seenAt=math.max(saved.points[key].seenAt or 0,p.seenAt or 0) end
                end end
            end
        else target.entries[id]=copy(e) end
    end
    missing(target,source)
end
local function mergeAtlas(target,source,key)
    local ids,reserved={},{};local serial=0
    for _,field in ipairs({"records","expeditions"}) do
        target[field]=target[field] or {}
        for id,e in pairs(target[field]) do
            reserved[id]=true
            for _,related in ipairs(e.related or {}) do reserved[related]=true end
            for _,stop in ipairs(e.stops or {}) do if stop.recordID then reserved[stop.recordID]=true end end
        end
    end
    local function remapID(id)
        if not ids[id] then
            local candidate
            repeat serial=serial+1;candidate="char"..key..":"..serial until not reserved[candidate]
            ids[id]=candidate;reserved[candidate]=true
        end
        return ids[id]
    end
    for _,field in ipairs({"records","expeditions"}) do
        for id in pairs(source[field] or {}) do remapID(id) end
    end
    local function record(e)
        local out=copy(e)
        if out.id then out.id=remapID(out.id) end
        -- Deleted records keep references too. Qualify their IDs without
        -- creating records, so they cannot resolve to another character's data.
        for i,id in ipairs(out.related or {}) do out.related[i]=remapID(id) end
        for _,stop in ipairs(out.stops or {}) do if stop.recordID then stop.recordID=remapID(stop.recordID) end end
        return out
    end
    for _,field in ipairs({"records","expeditions"}) do
        for id,e in pairs(source[field] or {}) do target[field][ids[id]]=record(e) end
    end
    target.subzones=target.subzones or {}
    for mapID,rows in pairs(source.subzones or {}) do
        local saved=target.subzones[mapID] or {};target.subzones[mapID]=saved
        local function signature(p)
            return table.concat({p.kind or "crossing",p.name or "",p.from or "",p.to or "",
                p.x or 0,p.y or 0,p.fromX or 0,p.fromY or 0},"\t")
        end
        local seen={};for _,p in ipairs(saved) do seen[signature(p)]=true end
        for _,p in ipairs(rows) do
            local identity=signature(p)
            if not seen[identity] and #saved<4096 then saved[#saved+1]=copy(p);seen[identity]=true end
        end
    end
    target.weather=target.weather or {};missing(target.weather,source.weather)
    for field,value in pairs(source) do if target[field]==nil then target[field]=copy(value) end end
    return ids
end
local referenceFields={id=true,waterID=true,poolID=true,spotID=true,recordID=true,aggregateID=true,sessionID=true,mergedInto=true}
local function remap(value,ids,field)
    if type(value)~="table" then
        if referenceFields[field] or field=="mergedFrom" then return ids[value] or value end
        return value
    end
    local out={}
    for k,v in pairs(value) do
        local key=(field=="items" and ids[k]) or k
        out[key]=remap(v,ids,field=="mergedFrom" and field or k)
    end
    return out
end
local function mergeAngling(target,source,key)
    local ids={}
    local stores={"waters","pools","items","spots","merged","aggregates","reported"}
    -- Identity maps deduplicate waters, pool types and items. Catch facts remain
    -- separate observations; never overwrite totals from another character.
    for _,field in ipairs(stores) do
        target[field]=target[field] or {}
        for id in pairs(source[field] or {}) do ids[id]="char"..key..":"..id end
    end
    for _,field in ipairs({"history","sessions"}) do
        for _,e in ipairs(source[field] or {}) do if e.id then ids[e.id]="char"..key..":"..e.id end end
    end
    for _,field in ipairs({"waterKeys","poolKeys","itemKeys"}) do
        target[field]=target[field] or {}
        for identity,id in pairs(source[field] or {}) do
            if target[field][identity] then ids[id]=target[field][identity]
            else target[field][identity]=ids[id] or id end
        end
    end
    for identity,claim in pairs(source.claims or {}) do
        local existing=target.claims and target.claims[identity]
        if existing then ids[claim.recordID]=existing.recordID end
    end
    for identity,origin in pairs(source.reportOrigins or {}) do
        local existing=target.reportOrigins and target.reportOrigins[identity]
        if existing then ids[origin.id]=existing.id end
    end
    for _,field in ipairs(stores) do
        for id,e in pairs(source[field] or {}) do
            local out=remap(e,ids);out.id=ids[id]
            if target[field][out.id] then
                local prior=target[field][out.id]
                if field=="reported" and (out.last or 0)>=(prior.last or 0) and (out.events or 0)>=(prior.events or 0) then
                    target[field][out.id]=out
                else mergeRecord(prior,out) end
            else target[field][out.id]=out end
        end
    end
    for _,field in ipairs({"history","sessions","eventLog"}) do
        target[field]=target[field] or {}
        for _,e in ipairs(source[field] or {}) do
            local out=remap(e,ids)
            if out.token then out.token="char"..key..":"..out.token end
            if field=="eventLog" and out.key then out.key="char"..key..":"..out.key end
            target[field][#target[field]+1]=out
        end
        table.sort(target[field],function(a,b) return (a.at or a.last or 0)<(b.at or b.last or 0) end)
    end
    for _,field in ipairs({"claims","reportOrigins"}) do
        target[field]=target[field] or {}
        for identity,e in pairs(source[field] or {}) do
            if not target[field][identity] then target[field][identity]=remap(e,ids) end
        end
    end
    target.aggregateKeys=target.aggregateKeys or {};target.hoverKeys=target.hoverKeys or {}
    for id,e in pairs(target.aggregates) do
        local identity=ns.Angling.AggregateKey(e)
        if not target.aggregateKeys[identity] then target.aggregateKeys[identity]=id end
    end
    for id,e in pairs(target.spots) do
        if e.hover and e.poolID then target.hoverKeys[ns.Angling.Key(e.poolID,e.waterID)]=id end
    end
    -- Explicit merges can point a hover lookup at a manually recorded spot.
    -- Preserve that choice rather than reconstructing it from hover flags alone.
    for _,id in pairs(source.hoverKeys or {}) do
        local mapped=ids[id]
        local e=mapped and (target.spots[mapped] or target.merged[mapped])
        if e and e.poolID then target.hoverKeys[ns.Angling.Key(e.poolID,e.waterID)]=mapped end
    end
    -- Replay tokens are character-local. Qualify them along with their ledger.
    target.recent=target.recent or {};target.recentOrder=target.recentOrder or {}
    for _,token in ipairs(source.recentOrder or {}) do
        local qualified="char"..key..":"..token
        target.recentOrder[#target.recentOrder+1]=qualified
        target.recent[qualified]=remap(source.recent[token],ids)
        if target.recent[qualified] then target.recent[qualified].items=copy(source.recent[token].items) end
    end
    -- Do not mix old local lookup IDs into the rebuilt indexes.
    for field,value in pairs(source) do if target[field]==nil then target[field]=copy(value) end end
end
local function mergeLedger(target,source,key)
    target.contacts=target.contacts or {};target.references=target.references or {}
    target.aliases=target.aliases or {};target.reportKeys=target.reportKeys or {}
    local ids={}
    for id,e in pairs(source.contacts or {}) do
        ids[id]=(#(e.reports or {})==0 and target.references[e.reference]) or ("char"..key..":"..id)
    end
    for id,e in pairs(source.contacts or {}) do
        local out=copy(e);out.id=ids[id]
        if target.contacts[out.id] then mergeRecord(target.contacts[out.id],out)
        else target.contacts[out.id]=out end
    end
    for reference,id in pairs(source.references or {}) do target.references[reference]=ids[id] or id end
    for alias,id in pairs(source.aliases or {}) do
        if not target.aliases[alias] then target.aliases[alias]=ids[id] or id end
    end
    for identity,id in pairs(source.reportKeys or {}) do
        if not target.reportKeys[identity] then target.reportKeys[identity]=ids[id] or id end
    end
    target.contactAliases=target.contactAliases or {}
    for alias,id in pairs(source.contactAliases or {}) do target.contactAliases["char"..key..":"..alias]=ids[id] or id end
    for field,value in pairs(source) do if target[field]==nil then target[field]=copy(value) end end
end
local mergers={gathering=mergeGathering,atlas=mergeAtlas,angling=mergeAngling,ledger=mergeLedger}
local settings
ns.ActiveSectionStores={}
function ns.InitializeSectionTracking(value)
    if ns.InitializationBlocked then return end
    settings=value;ns.ActiveSectionStores={}
end
local function atlasMappings(account,personal,shared,key,ids)
    account.atlasReferenceRepairs=account.atlasReferenceRepairs or {}
    if account.atlasReferenceRepairs[key] then return end
    account.atlasReferenceMaps=account.atlasReferenceMaps or {}
    local map=account.atlasReferenceMaps[key] or {};account.atlasReferenceMaps[key]=map
    account.atlasReferenceIssues=account.atlasReferenceIssues or {}
    local issues=account.atlasReferenceIssues[key] or {};account.atlasReferenceIssues[key]=issues
    local first=account.atlasFirstImport
    if not first then
        -- Old imports retained the owner in every remapped ID, but omitted the
        -- first owner's key. Recover it only if the other owners are evidenced.
        local qualified={}
        for _,field in ipairs({"records","expeditions"}) do for id in pairs(shared[field] or {}) do
            local owner=tostring(id):match("^char(%d+):");if owner then qualified[tonumber(owner)]=true end
        end end
        local candidates={}
        for owner in pairs(account.sectionImports.atlas or {}) do if not qualified[owner] then candidates[#candidates+1]=owner end end
        if #candidates==1 then first=candidates[1];account.atlasFirstImport=first end
    end
    for id,e in pairs(personal.records or {}) do
        if map[e.reference]==nil then
            local candidates,exact={},{}
            for dest,record in pairs(shared.records or {}) do
                local owner=tostring(dest):match("^char(%d+):")
                local owned=owner and tonumber(owner)==key or not owner and first==key and dest==id
                if ids then
                    if dest==(ids[id] or id) then exact[#exact+1]=record end
                elseif record.reference==e.reference then exact[#exact+1]=record
                elseif e.referenceLegacy and record.referenceLegacy and owned and type(e.created)=="number" and record.created==e.created then
                    candidates[#candidates+1]=record
                end
            end
            if #exact>0 then candidates=exact end
            -- Two local entries created in the same second cannot be inverted
            -- from an old charN:serial namespace using the timestamp alone.
            local localCount=0
            for _,other in pairs(personal.records or {}) do if other.created==e.created then localCount=localCount+1 end end
            local found=#candidates==1 and candidates[1]
            if found and (ids or found.reference==e.reference or first==key or localCount==1) then
                map[e.reference]=found.reference
            else
                map[e.reference]=false
                issues[e.reference]=#candidates==0 and "No saved Atlas destination mapping survives in this scope."
                    or "Multiple Atlas records share the surviving migration stamp; the original ID mapping was not saved."
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("Azeroth Fieldbook: "..e.name..": "..issues[e.reference].." Reference retained.") end
            end
        end
    end
    for alias,reference in pairs(personal.loreAliases or {}) do
        if map[alias]==nil then
            local mapped=map[reference] or false
            if not ids and mapped and shared.loreAliases[alias] and shared.loreAliases[alias]~=mapped then
                mapped=false;issues[alias]="This old Atlas key could refer to different local and account discoveries; its saved scope is unknown."
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("Azeroth Fieldbook: "..issues[alias].." Reference retained.") end
            end
            map[alias]=mapped
        end
    end
    account.atlasReferenceRepairs[key]=true
end
function ns.ResolveAtlasLoreReference(journal,key)
    if ns.InitializationBlocked then return end
    local db=journal.saved;local account=AzerothFieldbookAccountDB
    local map=account and account.atlasReferenceMaps and settings and account.atlasReferenceMaps[settings.accountTrackingKey] or {}
    local issues=account and account.atlasReferenceIssues and settings and account.atlasReferenceIssues[settings.accountTrackingKey] or {}
    -- A legacy key whose original scope was lost is ambiguous in both scopes.
    -- Explicit durable local identities remain usable even if their account
    -- mapping is unavailable; only the conflicted old alias is refused here.
    if issues[key] and key:find("@:",1,true) then return end
    local shared=account and account.sections and account.sections.atlas==db
    local reference=key
    if shared then
        if map[key]~=nil then reference=map[key]
        elseif db.loreAliases then reference=db.loreAliases[key] or key end
    else
        reference=db and db.loreAliases and db.loreAliases[key] or key
        -- Account references can return to this character's original discovery.
        -- A local ID alone is never used as an opt-out fallback.
        for _,e in pairs(journal.records) do
            if e.reference==reference or map[e.reference]==reference then return e.id,e end
        end
        local alias=account and account.sections and account.sections.atlas and account.sections.atlas.loreAliases
        local target=map[key] or (alias and alias[key])
        if target then for _,e in pairs(journal.records) do if map[e.reference]==target then return e.id,e end end end
        return
    end
    if reference then for id,e in pairs(journal.records) do if e.reference==reference then return id,e end end end
end
local function fishingAliases(account,personal,shared,key)
    account.anglingIdentityRepairs=account.anglingIdentityRepairs or {}
    if account.anglingIdentityRepairs[key] then return end
    -- Angling's old remap was deterministic. These are store/ID aliases, not
    -- guesses based on matching fish, positions or totals.
    for _,field in ipairs({"waters","spots","pools","items","merged","aggregates"}) do
        for id,e in pairs(personal[field] or {}) do
            local target=shared[field] and shared[field]["char"..key..":"..id]
            if personal.origin==shared.origin then target=shared[field] and shared[field][id] end
            if target and target.origin and e.origin and (target.originUnknown or target.origin.key==e.origin.key) then
                ns.Angling.AddLegacyKey(target.origin,e.origin.key)
                for _,alias in ipairs(e.origin.legacyKeys or {}) do ns.Angling.AddLegacyKey(target.origin,alias) end
            end
        end
        for id,e in pairs(shared[field] or {}) do
            if e.originUnknown then ns.Angling.AddLegacyKey(e.origin,shared.origin..":"..id) end
        end
    end
    account.anglingIdentityRepairs[key]=true
end
function ns.SelectSectionStorage(section,personal)
    if ns.InitializationBlocked then return nil end
    if ns.ActiveSectionStores[section] then return ns.ActiveSectionStores[section] end
    if not settings or settings.accountWideTracking==false then
        ns.ActiveSectionStores[section]=personal;return personal
    end
    local account=AzerothFieldbookAccountDB
    account.sections=account.sections or {};account.sectionImports=account.sectionImports or {}
    local imports=account.sectionImports[section] or {};account.sectionImports[section]=imports
    local key=settings.accountTrackingKey
    local existing=account.sections[section]
    -- Preserve unsupported schemas unchanged rather than interpreting future data.
    if (personal.schema or 0)>1 or (existing and (existing.schema or 0)>1) then
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("Azeroth Fieldbook: "..section.." uses a newer data schema; account migration deferred.") end
        ns.ActiveSectionStores[section]=personal;return personal
    end
    if section=="atlas" then ns.Atlas.EnsureReferences(personal)
    elseif section=="angling" then ns.Angling.PrepareOrigins(personal) end
    local ids
    if not imports[key] then
        local staged=copy(existing or {})
        if not existing then staged=copy(personal)
        else ids=mergers[section](staged,personal,key) end
        account.sections[section]=staged;imports[key]=true
        if section=="atlas" and not existing then account.atlasFirstImport=key;ids={} end
    end
    local selected=account.sections[section]
    -- A one-time import forks the store. New allocations in the account and in
    -- the retained opt-out copy must never mint the same original identity.
    local allocation=({atlas="referenceOrigin",angling="captureOrigin",ledger="contactOrigin"})[section]
    if allocation and not selected[allocation] then
        selected[allocation]="account-"..tostring(ns.Atlas.Now()).."-"..math.random(1,999999999)
    end
    if section=="atlas" then
        ns.Atlas.EnsureReferences(selected);atlasMappings(account,personal,selected,key,ids)
    elseif section=="angling" then
        ns.Angling.PrepareOrigins(selected);fishingAliases(account,personal,selected,key)
    elseif section=="ledger" then ns.Ledger.ReconcileReports(selected) end
    ns.ActiveSectionStores[section]=selected
    return selected
end
