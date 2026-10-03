local _,ns=...
-- Lore owns the selected archive. These utilities never select an account store.
local L={SCHEMA=1,MAX_ENTRIES=2000,MAX_PAGES=256,MAX_PAGE_BYTES=131072,MAX_WORK_BYTES=4194304,
    MAX_ARCHIVE_BYTES=33554432,MAX_PASSAGES=256,MAX_LOCATIONS=100,MAX_LINKS=100,MAX_TAGS=32,MAX_REPORTS=32}
ns.Lore=L
for _,key in ipairs({'Public','Read','Text','Safe','AutomaticLabel','Number','Integer','Array','Count','Now','Position'}) do L[key]=ns.Atlas[key] end
function L.IsAutomatic(entry)
    return type(entry)=='table' and entry.origin=='captured'
end
L.kinds={writing='Writings',landmark='Landmarks',person='People',mystery='Mysteries'}
local aliases={writings='writing',landmarks='landmark',people='person',mysteries='mystery'}
local origins={captured=true,manual=true,reported=true}
local natures={source=true,translation=true,observation=true,account=true,interpretation=true,annotation=true,paraphrase=true,rumour=true,theory=true}
local methods={displayed=true,automatic=true,manual=true,reported=true,observed=true,transcribed=true,gossip=true,quest=true,dialogue=true}
local meanings={['read-here']=true,['found-here']=true,landmark=true,observation=true,encounter=true,reported=true,mentioned=true}
local statuses={open=true,investigating=true,resolved=true}
local captureStatuses={partial=true,complete=true,failed=true,interrupted=true,unsupported=true}
local function plainTable(v) return L.Public(v) and type(v)=='table' and not getmetatable(v) end
local function rawText(v,max,empty)
    return L.Public(v) and type(v)=='string' and #v<=max and (empty or v:find('%S')~=nil)
        and not v:find('[%z\1-\8\11\12\14-\31\127]')
end
local function sameLocation(a,b)
    for _,key in ipairs({'mapID','x','y','zone','subzone','floor','instance','meaning','origin','source','note','precision','method'}) do
        if a[key]~=b[key] then return false end
    end
    return true
end
function L.Copy(value)
    local seen,nodes={},0
    local function copy(v,depth)
        if not L.Public(v) then return nil end
        if type(v)~='table' then return v end
        if depth>16 or getmetatable(v) or seen[v] then return nil end
        nodes=nodes+1;if nodes>20000 then return nil end
        seen[v]=true;local out={}
        for k,x in pairs(v) do if type(k)=='string' or type(k)=='number' then out[k]=copy(x,depth+1) end end
        seen[v]=nil;return out
    end
    return copy(value,0)
end
function L.Player()
    local fn=UnitNameUnmodified or UnitName
    if type(fn)~='function' then return 'Unknown player' end
    local ok,name,surname=pcall(fn,'player')
    if not ok or not L.Public(name) or not L.Public(surname) or type(name)~='string' or name=='' then return 'Unknown player' end
    if type(surname)=='string' and surname~='' then
        local full=L.Read(NameUtil and NameUtil.GetFullNameWithoutRealm,name,surname)
        if L.Text(full,160) then return full end
        return 'Unknown player'
    end
    return name
end
function L.Plain(raw)
    if not L.Public(raw) or type(raw)~='string' then return '' end
    local markup={html=true,body=true,p=true,h1=true,h2=true,h3=true,br=true,a=true,img=true,b=true,i=true,u=true,font=true,div=true,span=true}
    local out=raw:gsub('|H.-|h(.-)|h','%1'):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
        :gsub('|T.-|t',''):gsub('|A.-|a',''):gsub('<[Bb][Rr]%s*/?>','\n')
        :gsub('</[Pp]>','\n\n'):gsub('</[Hh][1-6]>','\n\n'):gsub('</[Ll][Ii]>','\n'):gsub('<[^>]*>',function(tag)
            local name=tag:match('^</?([%a%d]+)[%s/>]')
            return name and markup[name:lower()] and '' or tag
        end):gsub('&lt;','<'):gsub('&gt;','>')
        :gsub('&quot;','"'):gsub('&apos;',"'"):gsub('&nbsp;',' '):gsub('&amp;','&')
    local cleaned=out:gsub('[%z\1-\8\11\12\14-\31\127]','');return cleaned
end
function L.Location(value,meaning)
    if not plainTable(value) then return nil,'Invalid location.' end
    local out={};meaning=meaning or value.meaning or 'observation'
    if meaning=='read' then meaning='read-here' elseif meaning=='found' then meaning='found-here' end
    if not meanings[meaning] then return nil,'Choose what this location records.' end
    out.meaning=meaning
    for _,key in ipairs({'zone','subzone','floor','instance','source','note'}) do
        if not L.Text(value[key] or '',key=='note' and 4000 or 200,true) then return nil,'Invalid location label.' end
        out[key]=value[key] or ''
    end
    if value.mapID~=nil then
        if not L.Integer(value.mapID,1,2147483647) then return nil,'Invalid map ID.' end
        out.mapID=value.mapID
    end
    out.precision=value.precision or ((value.x~=nil and value.origin=='manual') and 'manual' or 'unknown');out.method=value.method or 'manual'
    if out.precision~='unknown' and out.precision~='player' and out.precision~='manual' then return nil,'Invalid coordinate precision.' end
    if not methods[out.method] then return nil,'Invalid location method.' end
    if value.x~=nil or value.y~=nil then
        if meaning=='mentioned' then return nil,'A merely mentioned place has no established coordinates; leave its position unknown.' end
        if not L.Position(value) or (value.x==0 and value.y==0) or out.precision=='unknown' then return nil,'Coordinates require a map, both values and an explicit approximation.' end
        out.x,out.y=value.x,value.y
    else out.precision='unknown' end
    out.origin=value.origin or (out.method=='manual' and 'manual' or 'captured')
    if not origins[out.origin] then return nil,'Invalid location origin.' end
    if value.at~=nil and not L.Integer(value.at,0,9999999999) then return nil,'Invalid location time.' end
    out.at=value.at or L.Now()
    if value.id~=nil then if not L.Text(value.id,64) then return nil,'Invalid location ID.' end;out.id=value.id end
    return out
end
function L.CurrentLocation(meaning)
    local p=ns.Atlas.CurrentLocation();p.precision=L.Position(p) and 'player' or 'unknown';p.method='observed'
    p.instance=L.Read(GetInstanceInfo) or '';return L.Location(p,meaning or 'observation')
end
function L.LocationText(p)
    if type(p)~='table' then return 'Location unknown' end
    local label=p.zone and p.zone~='' and p.zone or 'Unknown zone'
    if p.subzone and p.subzone~='' then label=label..' / '..p.subzone end
    if p.floor and p.floor~='' then label=label..' / '..p.floor end
    if p.instance and p.instance~='' then label=label..' / '..p.instance end
    if L.Position(p) then label=label..string.format(' • %.2f, %.2f (%s)',p.x/100,p.y/100,p.precision=='player' and 'approximate player position' or 'manually placed') end
    return label..' • '..(p.meaning or 'observation')
end
local function provenance(value,out)
    out.origin=value.origin or 'manual';out.nature=value.nature or 'annotation';out.method=value.method or 'manual'
    if not origins[out.origin] or not natures[out.nature] or not methods[out.method] then return nil,'Invalid passage provenance.' end
    if value.personallyViewed~=nil and type(value.personallyViewed)~='boolean' then return nil,'Invalid viewed flag.' end
    out.personallyViewed=out.origin=='captured' and value.personallyViewed==true
    for _,key in ipairs({'source','sourceTitle','speaker','sender','claimedObserver','claim','locale'}) do
        if not L.Text(value[key] or '',key=='claim' and 1000 or 200,true) then return nil,'Invalid source attribution.' end
        out[key]=value[key] or ''
    end
    if value.at~=nil and not L.Integer(value.at,0,9999999999) then return nil,'Invalid passage time.' end
    out.at=value.at or L.Now()
    if value.received~=nil then if not L.Integer(value.received,0,9999999999) then return nil,'Invalid received time.' end;out.received=value.received end
    return out
end
function L.Page(value)
    if not plainTable(value) or not rawText(value.raw,L.MAX_PAGE_BYTES,true) then return nil,'Source page is unreadable or exceeds 128 KiB; nothing was truncated.' end
    local out={raw=value.raw,nature='source'}
    if value.number~=nil then if not L.Integer(value.number,1,L.MAX_PAGES) then return nil,'Page number is outside 1–256.' end;out.number=value.number end
    if value.sourcePage~=nil then if not L.Integer(value.sourcePage,0,100000) then return nil,'Invalid original page number.' end;out.sourcePage=value.sourcePage end
    for _,key in ipairs({'first','last'}) do
        if value[key]~=nil and type(value[key])~='boolean' then return nil,'Invalid page boundary evidence.' end
        if value[key]~=nil then out[key]=value[key] end
    end
    local _,err=provenance(value,out);if err then return nil,err end
    out.nature='source';return out
end
-- A translation carries its exact original, never a title-only association or
-- a foreign archive ID. It remains understandable after forwarding/deletion.
local translationFields={translator=200,fromLanguage=80,toLanguage=80,sourceTitle=200,sourceRaw=131072}
function L.Translation(value)
    if not plainTable(value) then return nil,'Translation details are missing.' end
    for key in pairs(value) do if not translationFields[key] and key~='page' then return nil,'Unexpected translation detail.' end end
    local out={}
    for key,max in pairs(translationFields) do
        local valid=key=='sourceRaw' and rawText(value[key],max) or key~='sourceRaw' and L.Text(value[key],max)
        if not valid then return nil,'Enter a translator, both languages, source title and original text within their limits.' end
        out[key]=value[key]
    end
    if value.page~=nil then
        if not L.Integer(value.page,0,100000) then return nil,'Invalid translated page number.' end
        out.page=value.page
    end
    return out
end
function L.TranslationLabel(t)
    return 'Translation • '..t.fromLanguage..' → '..t.toLanguage..(t.page~=nil and ' • page '..t.page or '')..' • '..t.translator
end
local function sameTranslation(a,b)
    if not a or not b then return a==b end
    for key in pairs(translationFields) do if a[key]~=b[key] then return false end end
    return a.page==b.page
end
function L.Passage(value)
    if not plainTable(value) or not rawText(value.raw or value.text,L.MAX_PAGE_BYTES) then return nil,'Enter passage text, up to 128 KiB; nothing was truncated.' end
    local out={raw=value.raw or value.text}
    local _,err=provenance(value,out);if err then return nil,err end
    if out.nature=='translation' then
        out.translation,err=L.Translation(value.translation);if not out.translation then return nil,err end
    elseif value.translation~=nil then return nil,'Translation details require a translation passage.' end
    if value.id~=nil then if not L.Text(value.id,64) then return nil,'Invalid passage ID.' end;out.id=value.id end
    if value.private~=nil and type(value.private)~='boolean' then return nil,'Invalid privacy flag.' end
    if value.private~=nil then out.private=value.private
    else out.private=not (out.nature=='source' or out.nature=='translation' or (out.nature=='account' and out.origin=='captured')) end
    return out
end
function L.Link(value)
    if not plainTable(value) then return nil,'Invalid related record.' end
    local out={section=value.section,id=value.id or value.key,label=value.label or value.name or '',explanation=value.explanation or value.reason or ''}
    if not ({lore=true,bestiary=true,gathering=true,atlas=true,angling=true,merchants=true,ledger=true,treasure=true})[out.section]
        or not (L.Text(out.id,160) or L.Integer(out.id,1,2147483647)) or not L.Text(out.label,200,true)
        or not L.Text(out.explanation,4000,true) then return nil,'Choose a valid related record and plain labels.' end
    if value.atlasOwner~=nil then
        if out.section~='atlas' or not L.Integer(value.atlasOwner,1,2147483647) then return nil,'Invalid Atlas reference owner.' end
        out.atlasOwner=value.atlasOwner
    end
    return out
end
local function tags(value)
    if not L.Array(value or {},L.MAX_TAGS) then return nil end
    local out,seen={},{}
    for _,tag in ipairs(value or {}) do
        if not L.Text(tag,80) then return nil end
        local key=tag:lower();if not seen[key] then out[#out+1]=tag;seen[key]=true end
    end
    return out
end
local fieldLimits={title=200,sourceTitle=200,subtype=80,description=16000,notes=32000,theory=16000,nextStep=4000,
    sourceName=200,sourceKind=80,locale=40,identity=200,captureReason=1000}
local function fields(value,kind)
    if not plainTable(value) then return nil,'Invalid entry fields.' end
    local out={kind=aliases[kind] or kind}
    if not L.kinds[out.kind] then return nil,'Choose writings, landmarks, people or mysteries.' end
    for key,max in pairs(fieldLimits) do
        if not L.Text(value[key] or '',max,key~='title') then return nil,'Invalid or oversized '..key..'.' end
        out[key]=value[key] or ''
    end
    out.tags=tags(value.tags);if not out.tags then return nil,'Use at most 32 plain tags, each up to 80 bytes.' end
    if value.revisit~=nil and type(value.revisit)~='boolean' then return nil,'Invalid revisit flag.' end
    out.revisit=value.revisit==true;out.status=value.status or 'open'
    out.origin=value.origin or 'manual';if not origins[out.origin] then return nil,'Invalid entry origin.' end
    if not statuses[out.status] then return nil,'Choose open, investigating or resolved.' end
    out.captureStatus=value.captureStatus or 'partial'
    if not captureStatuses[out.captureStatus] then return nil,'Invalid writing capture status.' end
    if value.npcID~=nil then if not L.Integer(value.npcID,1,2147483647) then return nil,'Invalid NPC ID.' end;out.npcID=value.npcID end
    for _,key in ipairs({'firstPage','lastPage'}) do
        if value[key]~=nil then if not L.Integer(value[key],1,L.MAX_PAGES) then return nil,'Invalid known page boundary.' end;out[key]=value[key] end
    end
    if out.firstPage and out.lastPage and out.lastPage<out.firstPage then return nil,'Page boundaries are inconsistent.' end
    return out
end
local function reports(values)
    -- At most 32 historical copies could predate evidence deduplication. Keeping
    -- all of them can leave at most 31 redundant copies alongside 32 revisions.
    -- This physical ceiling and the unchanged byte limits bound preserved data.
    if not L.Array(values or {},L.MAX_REPORTS*2-1) then return nil,'Too many stored report snapshots.' end
    local out,seen,count={},{},0
    for _,report in ipairs(values or {}) do
        if not ns.LoreReports then return nil,'Report validation is unavailable; saved data was preserved.' end
        local valid,err=ns.LoreReports.NormalizeStored(report);if not valid then return nil,err end
        local key=ns.LoreReports.EvidenceKey(valid)
        if not seen[key] then seen[key]=true;count=count+1 end
        if count>L.MAX_REPORTS then return nil,'Use at most 32 evidence revisions per entry.' end
        out[#out+1]=valid
    end
    return out
end
local function reportBytes(values)
    local bytes=0
    for _,r in ipairs(values or {}) do
        for _,p in ipairs(r.pages or {}) do bytes=bytes+#p.raw end
        for _,p in ipairs(r.passages or {}) do bytes=bytes+#p.raw end
        for _,value in pairs(r.annotations or {}) do if type(value)=='string' then bytes=bytes+#value end end
    end
    return bytes
end
local bytesOf
function L.ValidateEntry(value,id)
    if not plainTable(value) or not L.Text(id or value.id,64) or (id and value.id~=id) then return nil,'Invalid entry identity.' end
    local out,err=fields(value,value.kind);if not out then return nil,err end
    out.id=id or value.id
    for _,key in ipairs({'created','updated'}) do
        if not L.Integer(value[key],0,9999999999) then return nil,'Invalid entry time.' end;out[key]=value[key]
    end
    for _,key in ipairs({'firstEncounter','lastEncounter'}) do
        if value[key]~=nil then if not L.Integer(value[key],0,9999999999) then return nil,'Invalid encounter time.' end;out[key]=value[key] end
    end
    if out.firstEncounter and out.lastEncounter and out.lastEncounter<out.firstEncounter then return nil,'Encounter dates are inconsistent.' end
    out.locations={};out.links={};out.passages={};out.pages={};local bytes=0
    for _,spec in ipairs({{'locations',L.MAX_LOCATIONS,L.Location},{'links',L.MAX_LINKS,L.Link},{'passages',L.MAX_PASSAGES,L.Passage}}) do
        if not L.Array(value[spec[1]] or {},spec[2]) then return nil,'Invalid or excessive '..spec[1]..'.' end
        local seen={}
        for _,item in ipairs(value[spec[1]] or {}) do
            local v,e=spec[3](item);if not v then return nil,e end
            if spec[1]~='links' and (not v.id or seen[v.id]) then return nil,'Missing or duplicate record identity.' end
            if v.id then seen[v.id]=true end
            if v.raw then bytes=bytes+#v.raw end
            out[spec[1]][#out[spec[1]]+1]=v
        end
    end
    if not plainTable(value.pages or {}) or L.Count(value.pages or {})>L.MAX_PAGES then return nil,'Invalid or excessive writing pages.' end
    for key,page in pairs(value.pages or {}) do
        if not (L.Integer(key,1,L.MAX_PAGES) or (L.Text(key,64) and key:match('^unknown:%d+$'))) then return nil,'Invalid local page key.' end
        local p,e=L.Page(page);if not p then return nil,e end
        if type(key)=='number' and p.number~=key then return nil,'Page number does not match its key.' end
        if type(key)=='string' and p.number~=nil then return nil,'Unknown page has an invented number.' end
        out.pages[key]=p;bytes=bytes+#p.raw
    end
    out.reports,err=reports(value.reports);if not out.reports then return nil,err end
    if bytesOf(out)>L.MAX_WORK_BYTES then return nil,'Work exceeds 4 MiB; nothing was truncated.' end
    if value.variantOf~=nil then if not L.Text(value.variantOf,64) then return nil,'Invalid variant identity.' end;out.variantOf=value.variantOf end
    return out
end
local function itemBytes(value)
    if type(value)=='string' then return #value end
    local bytes=0;if type(value)=='table' then for _,v in pairs(value) do bytes=bytes+itemBytes(v) end end
    return bytes
end
bytesOf=function(e)
    local bytes=0;for key in pairs(fieldLimits) do bytes=bytes+itemBytes(e[key]) end
    for _,key in ipairs({'tags','pages','passages','locations','links','reports'}) do bytes=bytes+itemBytes(e[key]) end
    return bytes
end
function L.SupportsStore(saved)
    if not plainTable(saved) or (saved.schema~=nil and not L.Integer(saved.schema,0,L.SCHEMA)) then return false end
    for _,key in ipairs({'entries','state'}) do if saved[key]~=nil and not plainTable(saved[key]) then return false end end
    return true
end
function ns.CreateLoreJournal(saved)
    local readOnly=ns.InitializationBlocked or not L.SupportsStore(saved)
    local db=readOnly and {} or saved
    db.schema=L.SCHEMA;db.entries=db.entries or {};db.state=db.state or {}
    db.serial=L.Integer(db.serial,0,999999999) and db.serial or 0
    if not L.Text(db.archiveID,160) then db.archiveID=tostring(L.Now())..'-'..tostring(math.random(1,999999999))..'-'..tostring(math.random(1,999999999)) end
    local j={db=db,saved=saved,entries={},state=db.state,readOnly=readOnly,invalid=0,revision=0,cache={},sessions={}}
    for id,e in pairs(db.entries) do
        local valid=L.ValidateEntry(e,id)
        if valid then for key,v in pairs(valid) do e[key]=v end;j.entries[id]=e else j.invalid=j.invalid+1 end
    end
    function j:Get(id) return self.entries[id] end
    function j:Title(e) if type(e)~='table' then e=self:Get(e) end;return e and e.title or 'Missing record' end
    function j:Changed(e)
        self.revision=self.revision+1
        local id=type(e)=='table' and e.id or e
        if id then self.cache[id]=nil else self.cache={} end
        if type(e)=='table' then e.updated=L.Now() end
        if self.onChange then self.onChange(type(e)=='table' and e.id or e) end
    end
    function j:Next(prefix)
        repeat db.serial=db.serial+1 until not db.entries[(prefix or 'lore:')..db.serial]
        return (prefix or 'lore:')..db.serial
    end
    function j:ArchiveBytes() local n=0;for _,e in pairs(self.entries) do n=n+bytesOf(e) end;return n end
    -- Requested by the visible catalogue only; uses the capture/import byte
    -- model, not serialized file size. Never normalizes or writes saved data.
    function j:StorageStatus()
        if self.readOnly then return 'Archive: read-only', 'Saved data is unsupported; archive usage is unavailable. Preserved data has not been measured.' end
        local bytes,entries=self:ArchiveBytes(),L.Count(db.entries)
        local usage=string.format('Archive: %.2f / %g MiB',math.floor(bytes/1048576*100)/100,L.MAX_ARCHIVE_BYTES/1048576)
        local detail=string.format('%d / %d archive bytes\n%d / %d entry slots',bytes,L.MAX_ARCHIVE_BYTES,entries,L.MAX_ENTRIES)
        detail=detail..string.format('\nCounts archived text and evidence, not total SavedVariables file size. Each entry also has a %g MiB limit.',L.MAX_WORK_BYTES/1048576)
        if self.invalid>0 then
            usage='Archive: usage incomplete'
            detail=detail..'\nByte usage covers valid entries only. '..self.invalid..' invalid saved entries are preserved but cannot be measured.'
        elseif bytes>=L.MAX_ARCHIVE_BYTES or entries>=L.MAX_ENTRIES then detail='An archive limit has been reached.\n'..detail
        elseif bytes>=L.MAX_ARCHIVE_BYTES*0.9 or entries>=L.MAX_ENTRIES*0.9 then detail='Near an archive limit.\n'..detail end
        return usage,detail
    end
    function j:Encounter(e,at)
        at=L.Integer(at,0,9999999999) and at or L.Now()
        e.firstEncounter=e.firstEncounter and math.min(e.firstEncounter,at) or at
        e.lastEncounter=e.lastEncounter and math.max(e.lastEncounter,at) or at
    end
    function j:CanAddBytes(e,n)
        if bytesOf(e)+n>L.MAX_WORK_BYTES then return nil,'Work is full (4 MiB); nothing was truncated.' end
        if self:ArchiveBytes()+n>L.MAX_ARCHIVE_BYTES then return nil,'Archive is full (32 MiB); nothing was removed.' end
        return true
    end
    function j:Recorded(e)
        if e.origin~='reported' and ns.RecordFieldbookDiscovery then ns.RecordFieldbookDiscovery("lore",e,self) end
        if self.onRecorded then self.onRecorded(e) end
    end
    function j:Create(kind,value,deferRecorded,dryRun)
        if self.readOnly then return nil,'This archive uses an unsupported schema and is read-only.' end
        if L.Count(db.entries)>=L.MAX_ENTRIES then return nil,'Archive is full (2,000 entries); nothing was removed.' end
        local e,err=fields(value or {},kind);if not e then return nil,err end
        e.reports,err=reports(value and value.reports);if not e.reports then return nil,err end
        if bytesOf(e)>L.MAX_WORK_BYTES or self:ArchiveBytes()+bytesOf(e)>L.MAX_ARCHIVE_BYTES then return nil,'Archive capacity exceeded; nothing was removed.' end
        if dryRun then return e end
        e.id=self:Next();e.created=L.Now();e.updated=e.created;e.locations={};e.links={};e.passages={};e.pages={}
        if db.exportOrigin then e.exportSource=L.Player() end
        db.entries[e.id]=e;self.entries[e.id]=e;self:Changed(e)
        if not deferRecorded then self:Recorded(e) end
        return e
    end
    function j:ReplaceEntry(id,candidate,dryRun)
        if self.readOnly then return nil,'Archive is read-only.' end
        local old=self:Get(id);if not old then return nil,'Entry no longer exists.' end
        local replacement,err=L.ValidateEntry(candidate,id);if not replacement then return nil,err end
        if replacement.kind~=old.kind then return nil,'An entry cannot change kind.' end
        if bytesOf(replacement)>L.MAX_WORK_BYTES or self:ArchiveBytes()-bytesOf(old)+bytesOf(replacement)>L.MAX_ARCHIVE_BYTES then return nil,'Archive is full (32 MiB); nothing was changed.' end
        -- Preserve unrecognized local metadata while validating every owned collection.
        local merged=L.Copy(candidate);for key,v in pairs(replacement) do merged[key]=v end
        if dryRun then return merged end
        db.entries[id]=merged;self.entries[id]=merged;self:Changed(merged);return merged
    end
    function j:Update(id,value)
        if self.readOnly then return nil,'Archive is read-only.' end
        local e=self:Get(id);if not e then return nil,'Entry no longer exists.' end
        if not plainTable(value) then return nil,'Invalid entry fields.' end
        local merged=L.Copy(e)
        for key in pairs(fieldLimits) do if value[key]~=nil then merged[key]=value[key] end end
        for _,key in ipairs({'tags','revisit','status','npcID'}) do if value[key]~=nil then merged[key]=value[key] end end
        local normalized,err=fields(merged,e.kind);if not normalized then return nil,err end
        local proposed=bytesOf(e)
        for key in pairs(fieldLimits) do proposed=proposed-itemBytes(e[key])+itemBytes(normalized[key]) end
        proposed=proposed-itemBytes(e.tags)+itemBytes(normalized.tags)
        if proposed>L.MAX_WORK_BYTES or self:ArchiveBytes()-bytesOf(e)+proposed>L.MAX_ARCHIVE_BYTES then return nil,'Archive capacity exceeded; no annotations were changed.' end
        -- Captured identity, title and page boundaries are historical source facts, not editable annotations.
        for key,v in pairs(normalized) do
            if key~='identity' and key~='sourceTitle' and key~='sourceKind' and key~='locale' and key~='captureStatus' and key~='captureReason'
                and key~='firstPage' and key~='lastPage' then e[key]=v end
        end
        self:Changed(e);return e
    end
    function j:Delete(id)
        if self.readOnly then return nil,'Archive is read-only.' end
        if not self.entries[id] then return nil,'Entry no longer exists.' end
        db.entries[id]=nil;self.entries[id]=nil
        for key,s in pairs(self.sessions) do if s.id==id then self.sessions[key]=nil end end
        self:Changed();return true
    end
    function j:AddPassage(id,value)
        if self.readOnly then return nil,'Archive is read-only.' end
        local e=self:Get(id);if not e then return nil,'Entry no longer exists.' end
        local p,err=L.Passage(value);if not p then return nil,err end
        for _,old in ipairs(e.passages) do
            if old.raw==p.raw and old.origin==p.origin and old.nature==p.nature and old.source==p.source and old.speaker==p.speaker
                and old.sender==p.sender and old.claimedObserver==p.claimedObserver and old.private==p.private
                and old.sourceTitle==p.sourceTitle and old.locale==p.locale and old.claim==p.claim and sameTranslation(old.translation,p.translation) then
                if p.origin=='captured' then self:Encounter(e,p.at);self:Changed(e) end
                return old
            end
        end
        if #e.passages>=L.MAX_PASSAGES then return nil,'Entry has 256 passages; nothing was removed.' end
        local ok;ok,err=self:CanAddBytes(e,itemBytes(p));if not ok then return nil,err end
        p.id=self:Next('passage:');e.passages[#e.passages+1]=p
        if p.origin=='captured' then self:Encounter(e,p.at) end
        self:Changed(e);return p
    end
    function j:RemovePassage(id,passageID)
        if self.readOnly then return nil,'Archive is read-only.' end
        local e=self:Get(id);if not e then return nil,'Entry no longer exists.' end
        for i,p in ipairs(e.passages) do if p.id==passageID then
            if p.origin~='manual' then return nil,'Captured and reported source passages are immutable; remove the entry instead.' end
            table.remove(e.passages,i);self:Changed(e);return true
        end end
        return nil,'Passage no longer exists.'
    end
    function j:AddLocation(id,value)
        if self.readOnly then return nil,'Archive is read-only.' end
        local e=self:Get(id);if not e then return nil,'Entry no longer exists.' end
        local p,err=L.Location(value);if not p then return nil,err end
        for _,old in ipairs(e.locations) do
            if sameLocation(old,p) then
                if p.origin=='captured' and p.meaning~='mentioned' and p.meaning~='reported' then self:Encounter(e,p.at);self:Changed(e) end
                return old
            end
        end
        if #e.locations>=L.MAX_LOCATIONS then return nil,'Entry has 100 locations; nothing was removed.' end
        local ok;ok,err=self:CanAddBytes(e,itemBytes(p));if not ok then return nil,err end
        p.id=self:Next('location:');e.locations[#e.locations+1]=p
        if p.origin=='captured' and p.meaning~='mentioned' and p.meaning~='reported' then self:Encounter(e,p.at) end
        self:Changed(e);return p
    end
    function j:RemoveLocation(id,locationID)
        if self.readOnly then return nil,'Archive is read-only.' end
        local e=self:Get(id);if not e then return nil,'Entry no longer exists.' end
        for i,p in ipairs(e.locations) do if p.id==locationID then table.remove(e.locations,i);self:Changed(e);return true end end
        return nil,'Location no longer exists.'
    end
    function j:AddLink(id,value)
        if self.readOnly then return nil,'Archive is read-only.' end
        local e=self:Get(id);if not e then return nil,'Entry no longer exists.' end
        local p,err=L.Link(value);if not p then return nil,err end
        for _,old in ipairs(e.links) do if old.section==p.section and old.id==p.id then return old end end
        if #e.links>=L.MAX_LINKS then return nil,'Entry has 100 links; nothing was removed.' end
        local ok;ok,err=self:CanAddBytes(e,itemBytes(p));if not ok then return nil,err end
        e.links[#e.links+1]=p;self:Changed(e);return p
    end
    function j:RemoveLink(id,linkID,section)
        if self.readOnly then return nil,'Archive is read-only.' end
        local e=self:Get(id);if not e then return nil,'Entry no longer exists.' end
        for i,p in ipairs(e.links) do if (p.id==linkID or (not section and type(linkID)=='number' and i==linkID)) and (not section or p.section==section) then table.remove(e.links,i);self:Changed(e);return true end end
        return nil,'Link no longer exists.'
    end
    function j:WritingSummary(e)
        if type(e)~='table' then e=self:Get(e) end
        if not e or e.kind~='writing' then return {status='partial',captured=0,missing={},first=nil,last=nil} end
        local captured,missing=0,{};for _ in pairs(e.pages) do captured=captured+1 end
        if e.firstPage and e.lastPage then for n=e.firstPage,e.lastPage do if not e.pages[n] then missing[#missing+1]=n end end end
        local complete=e.firstPage==1 and e.lastPage~=nil and #missing==0
        local status=e.captureStatus
        if status=='complete' and not complete then status='partial' end
        if status=='partial' and complete then status='complete' end
        return {status=status,captured=captured,first=e.firstPage,last=e.lastPage,missing=missing,complete=complete,reason=e.captureReason}
    end
    function j:SetCaptureStatus(id,status,reason)
        if self.readOnly then return nil,'Archive is read-only.' end
        local e=self:Get(id);if not e or e.kind~='writing' then return nil,'Writing no longer exists.' end
        if not captureStatuses[status] or not L.Text(reason or '',1000,true) then return nil,'Invalid capture status.' end
        if status=='complete' and not self:WritingSummary(e).complete then return nil,'A complete capture requires every page from the known beginning to the known end.' end
        e.captureStatus=status;e.captureReason=reason or '';self:Changed(e);return true
    end
    function j:EndCapture(sessionID) self.sessions[sessionID]=nil end
    -- Preflight on detached data only. Distinct saved IDs also appear in exported
    -- source keys, which we cannot rewrite or redirect without durable aliases.
    -- Until that identity policy exists, even a capacity-valid merge is skipped.
    local function consolidationReason(source,target,archiveBytes)
        local merged=L.Copy(target)
        for _,key in ipairs({'title','subtype','description','notes','theory','nextStep'}) do
            if source[key]~='' and source[key]~=target[key] then
                local p=L.Passage({raw=source[key],origin='manual',nature='annotation',method='manual',
                    source='Duplicate entry '..key,private=true,at=source.updated})
                p.id='merged:'..source.id..':'..key;merged.passages[#merged.passages+1]=p
            end
        end
        for _,key in ipairs({'passages','locations','links','reports'}) do
            for index,value in ipairs(source[key]) do
                local item=L.Copy(value)
                if key=='passages' or key=='locations' then item.id='merged:'..source.id..':'..key..':'..index end
                merged[key][#merged[key]+1]=item
            end
        end
        for _,tag in ipairs(source.tags) do
            local found=false;for _,old in ipairs(merged.tags) do if old==tag then found=true end end
            if not found then merged.tags[#merged.tags+1]=tag end
        end
        merged.revisit=merged.revisit or source.revisit
        merged.created=math.min(merged.created,source.created);merged.updated=math.max(merged.updated,source.updated)
        for _,at in ipairs({source.firstEncounter,source.lastEncounter}) do j:Encounter(merged,at) end
        for key,page in pairs(source.pages) do if page.personallyViewed then merged.pages[key].personallyViewed=true end end
        local valid,reason=L.ValidateEntry(merged,target.id)
        if valid and (archiveBytes or j:ArchiveBytes())-bytesOf(source)-bytesOf(target)+bytesOf(merged)>L.MAX_ARCHIVE_BYTES then
            reason='Archive is full (32 MiB).'
        end
        return reason or 'Their saved identities and existing report references must be preserved.'
    end
    local function consolidationNotice(source,target,archiveBytes)
        -- Optional preflight must never turn a saved page into a failed capture,
        -- including if bounded copying cannot represent an unusually large work.
        local ok,reason=pcall(consolidationReason,source,target,archiveBytes)
        if not ok then reason='The complete merge could not be validated; original records were preserved.' end
        j.consolidationNotice='Duplicate writings kept separate: '..reason
        return j.consolidationNotice
    end
    function j:CapturePage(context,value)
        if self.readOnly then return nil,'Archive is read-only.' end
        if not plainTable(context) or not plainTable(value) or not L.Text(context.sessionID,160) then return nil,'Readable source needs a valid session identity.' end
        local meta,err=fields({title=context.title or 'Untitled writing',sourceTitle=context.title or '',sourceKind=context.sourceKind or 'readable',
            identity=context.identity or '',locale=context.locale or '',origin='captured'},'writing');if not meta then return nil,err end
        local incoming=L.Copy(value);incoming.origin='captured';incoming.nature='source';incoming.method=value.method or context.method or 'displayed'
        incoming.source=context.source or context.title or '';incoming.sourceTitle=context.title or '';incoming.locale=context.locale or ''
        local p;p,err=L.Page(incoming);if not p then return nil,err end
        local loc;if context.location then loc,err=L.Location(context.location);if not loc then return nil,err end end
        local s=self.sessions[context.sessionID]
        if s and (s.identity~=meta.identity or s.title~=meta.sourceTitle or s.locale~=meta.locale or s.sourceKind~=meta.sourceKind) then
            return nil,'The readable source changed during this session; begin a fresh capture.'
        end
        if not s then
            if L.Count(self.sessions)>=32 then return nil,'Too many open reading sessions; close an earlier readable before starting another.' end
            s={identity=meta.identity,title=meta.sourceTitle,locale=meta.locale,sourceKind=meta.sourceKind,pages={},locations={}}
        end
        local key=p.number
        if not key then
            for k,old in pairs(s.pages) do if not old.number and old.raw==p.raw then key=k;break end end
            if not key then key='unknown:'..(L.Count(s.pages)+1) end
        end
        local seenPage=s.pages[key]
        if seenPage and seenPage.raw==p.raw and seenPage.personallyViewed then p.personallyViewed=true end
        local e=self:Get(s.id)
        local function match(candidate)
            if candidate.kind~='writing' or candidate.identity~=meta.identity or candidate.sourceTitle~=meta.sourceTitle
                or candidate.locale~=meta.locale or candidate.sourceKind~=meta.sourceKind then return false end
            local page=candidate.pages[key]
            if not page or page.raw~=p.raw or page.origin~='captured' then return false end
            for n,seen in pairs(s.pages) do
                if n~=key and (not candidate.pages[n] or candidate.pages[n].raw~=seen.raw) then return false end
            end
            return true
        end
        -- Match exact page evidence as well as source metadata, never title alone.
        -- A subsequent conflict forks using this session's evidence only.
        if not e and p.number then
            for _,candidate in pairs(self.entries) do
                if match(candidate) and (not e or candidate.id<e.id) then e=candidate;s.borrowed=true end
            end
        end
        local old=e and e.pages[key]
        local fork=e and old and old.raw~=p.raw
        if e and s.borrowed and not old then
            for n,page in pairs(e.pages) do
                if not s.pages[n] or s.pages[n].raw~=page.raw then fork=true;break end
            end
        end
        if fork then
            s.variantOf=e.id;e=nil;s.borrowed=false
            for _,candidate in pairs(self.entries) do
                if match(candidate) and (not e or candidate.id<e.id) then e=candidate;s.borrowed=true end
            end
            old=e and e.pages[key]
        end
        local changedPage=seenPage and seenPage.raw~=p.raw
        local pending=changedPage and {} or L.Copy(s.pages);pending[key]=p
        local first=context.firstPage or (value.first and p.number) or (not changedPage and s.first or nil)
        local last=context.lastPage or (value.last and p.number) or (not changedPage and s.last or nil)
        if first~=nil and not L.Integer(first,1,L.MAX_PAGES) or last~=nil and not L.Integer(last,1,L.MAX_PAGES)
            or first and last and last<first then return nil,'Invalid known page boundary.' end
        if e and s.borrowed and ((first and e.firstPage and first~=e.firstPage) or (last and e.lastPage and last~=e.lastPage)) then
            s.variantOf=e.id;e=nil;s.borrowed=false;old=nil
        end
        local sessionLocations={}
        for _,location in ipairs(s.locations) do sessionLocations[#sessionLocations+1]=location end
        local sessionLocation=loc~=nil
        if loc then for _,location in ipairs(sessionLocations) do if sameLocation(location,loc) then sessionLocation=false;break end end end
        if sessionLocation then sessionLocations[#sessionLocations+1]=loc end
        local newLocation=loc~=nil
        if loc and e then for _,location in ipairs(e.locations) do if sameLocation(location,loc) then newLocation=false;break end end end
        local locationNotice
        if newLocation and ((e and #e.locations>=L.MAX_LOCATIONS) or #sessionLocations>L.MAX_LOCATIONS) then
            -- Decline only the extra location, including its session copy and
            -- byte cost. The page still passes every ordinary archive limit.
            if sessionLocation then table.remove(sessionLocations) end
            loc=nil;newLocation=false
            locationNotice='Page archived. This reading location was not saved because the entry has reached the 100-location limit.'
        end
        local count,total=0,bytesOf(meta)+itemBytes(sessionLocations);for _,item in pairs(pending) do count=count+1;total=total+itemBytes(item) end
        if count>L.MAX_PAGES then return nil,'Work has 256 pages; nothing was removed.' end
        if total>L.MAX_WORK_BYTES then return nil,'Work exceeds 4 MiB; nothing was truncated.' end
        if not e and self:ArchiveBytes()+total>L.MAX_ARCHIVE_BYTES then return nil,'Archive is full (32 MiB); nothing was removed.' end
        if e then
            local additional=(not old and itemBytes(p) or 0)+(newLocation and itemBytes(loc) or 0)
            local ok;ok,err=self:CanAddBytes(e,additional);if not ok then return nil,err end
        end
        local createdID
        if not e then
            e,err=self:Create('writing',meta,true);if not e then return nil,err end
            createdID=e.id
            e.pages=L.Copy(pending);e.variantOf=s.variantOf
            for _,previous in ipairs(s.locations) do self:AddLocation(e.id,previous) end
        elseif not old then e.pages[key]=p
        elseif p.personallyViewed and not old.personallyViewed and old.origin=='captured' then old.personallyViewed=true end
        if loc then self:AddLocation(e.id,loc) end
        s.locations=sessionLocations
        e.firstPage=first or e.firstPage;e.lastPage=last or e.lastPage
        self:Encounter(e,L.Now())
        s.id=e.id;s.pages=pending;s.first=first;s.last=last;self.sessions[context.sessionID]=s
        -- Capture succeeds independently of this optional consolidation preflight.
        -- Keep the existing protections for selected, referenced and edited works.
        local notice
        if meta.identity=='' and first==1 and last and self:WritingSummary(e).complete then
            for _,candidate in pairs(self.entries) do
                if candidate.id~=e.id and candidate.kind=='writing' and candidate.identity=='' and candidate.sourceTitle==meta.sourceTitle
                    and candidate.locale==meta.locale and candidate.sourceKind==meta.sourceKind and candidate.firstPage==first and candidate.lastPage==last
                    and L.Count(candidate.pages)==L.Count(e.pages) and self:WritingSummary(candidate).complete then
                    local same=true
                    for n,page in pairs(e.pages) do if not candidate.pages[n] or candidate.pages[n].raw~=page.raw or candidate.pages[n].origin~='captured' then same=false;break end end
                    local referenced=false
                    for _,owner in pairs(self.entries) do for _,link in ipairs(owner.links) do
                        if link.section=='lore' and link.id==e.id then referenced=true;break end
                    end;if referenced then break end end
                    if same and self.state.selected~=e.id and not referenced and e.title==meta.title and e.subtype==''
                        and e.notes=='' and e.description=='' and e.theory=='' and e.nextStep=='' and #e.passages==0 and #e.reports==0 and #e.links==0 and #e.tags==0 and not e.revisit then
                        notice=consolidationNotice(e,candidate)
                        break
                    end
                end
            end
        end
        self:Changed(e)
        if createdID==e.id then self:Recorded(e) end
        if locationNotice then notice=locationNotice..(notice and (' '..notice) or '') end
        return e,nil,notice
    end
    function j:SearchText(e)
        local cached=self.cache[e.id];if cached then return cached end
        local out={e.title,e.sourceTitle,e.sourceName,e.subtype,e.description,e.notes,e.theory,e.nextStep}
        local function translation(p)
            local t=p.translation;if not t then return end
            out[#out+1]=L.TranslationLabel(t);out[#out+1]=t.sourceTitle;out[#out+1]=L.Plain(t.sourceRaw)
        end
        for _,tag in ipairs(e.tags) do out[#out+1]=tag end
        for _,p in pairs(e.pages) do out[#out+1]=L.Plain(p.raw);out[#out+1]=p.source;out[#out+1]=p.claimedObserver end
        for _,p in ipairs(e.passages) do out[#out+1]=L.Plain(p.raw);out[#out+1]=p.source;out[#out+1]=p.speaker;out[#out+1]=p.sender;out[#out+1]=p.claimedObserver;translation(p) end
        for _,p in ipairs(e.locations) do out[#out+1]=p.zone;out[#out+1]=p.subzone;out[#out+1]=p.note end
        for _,p in ipairs(e.links) do out[#out+1]=p.label;out[#out+1]=p.explanation end
        for _,r in ipairs(e.reports or {}) do
            out[#out+1]=r.title;out[#out+1]=r.sourceTitle;out[#out+1]=r.sender;out[#out+1]=r.originalSource;out[#out+1]=r.receivedFrom or ''
            for _,p in ipairs(r.pages) do out[#out+1]=L.Plain(p.raw);out[#out+1]=p.source end
            for _,p in ipairs(r.passages) do out[#out+1]=L.Plain(p.raw);out[#out+1]=p.source;translation(p) end
            for _,p in ipairs(r.locations) do out[#out+1]=p.zone;out[#out+1]=p.subzone;out[#out+1]=p.label end
            for _,p in ipairs(r.references) do out[#out+1]=p.label;out[#out+1]=p.explanation end
            for _,v in pairs(r.annotations) do if type(v)=='string' then out[#out+1]=v elseif type(v)=='table' then for _,tag in ipairs(v) do out[#out+1]=tag end end end
        end
        cached=table.concat(out,'\n'):lower();self.cache[e.id]=cached;return cached
    end
    function j:List(filters)
        filters=type(filters)=='table' and filters or {};local out={}
        local query=type(filters.query)=='string' and filters.query:lower() or ''
        for _,e in pairs(self.entries) do
            local match=(not filters.kind or filters.kind=='' or filters.kind=='all' or e.kind==(aliases[filters.kind] or filters.kind))
                and (filters.revisit==nil or e.revisit==filters.revisit)
                and (not filters.status or filters.status=='' or e.status==filters.status)
                and (query=='' or self:SearchText(e):find(query,1,true))
            if match and filters.zone and filters.zone~='' then
                match=false;for _,p in ipairs(e.locations) do if p.zone==filters.zone or p.mapID==filters.zone then match=true;break end end
                for _,r in ipairs(e.reports or {}) do for _,p in ipairs(r.locations) do if p.zone==filters.zone or p.mapID==filters.zone then match=true;break end end end
            end
            if match and filters.origin and filters.origin~='' and filters.origin~='all' then
                local origin=filters.origin;match=false
                for _,rows in ipairs({e.pages,e.passages,e.locations}) do for _,p in pairs(rows) do if p.origin==origin then match=true;break end end end
                if origin==e.origin then match=true end
                if origin=='reported' and #(e.reports or {})>0 then match=true end
            end
            if match and filters.completeness and filters.completeness~='' and filters.completeness~='all' then match=e.kind=='writing' and self:WritingSummary(e).status==filters.completeness end
            if match then out[#out+1]=e end
        end
        table.sort(out,function(a,b)
            local key=filters.sort=='newest' and 'created' or filters.sort=='updated' and 'updated'
            if key and a[key]~=b[key] then return a[key]>b[key] end
            if a.title:lower()~=b.title:lower() then return a.title:lower()<b.title:lower() end
            return a.id<b.id
        end)
        return out
    end
    -- Inspect exact duplicates left by older readers using the same detached
    -- preflight. Reload must not undo capture-time preservation of saved IDs.
    function j:CollapseDuplicateWritings()
        if self.readOnly then return end
        local groups={};local archiveBytes=self:ArchiveBytes()
        local rows=self:List({kind='writing'})
        for _,e in ipairs(rows) do
            local parts={};local eligible=next(e.pages)~=nil
            local function part(v) v=tostring(v or '');parts[#parts+1]=#v..':'..v end
            for _,key in ipairs({'sourceTitle','sourceKind','identity','locale','firstPage','lastPage'}) do part(e[key]) end
            local keys={};for key in pairs(e.pages) do keys[#keys+1]=key end
            table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
            for _,key in ipairs(keys) do
                local page=e.pages[key];if page.origin~='captured' then eligible=false end
                part(key);part(page.raw)
            end
            if eligible then
                local signature=table.concat(parts);local target=groups[signature]
                if not target then groups[signature]=e
                else
                    consolidationNotice(e,target,archiveBytes)
                end
            end
        end
    end
    j:CollapseDuplicateWritings()
    return j
end
