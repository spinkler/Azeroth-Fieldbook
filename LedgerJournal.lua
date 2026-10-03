local _, ns = ...
local L={SCHEMA=1,MAX_CONTACTS=2000,MAX_REFERENCES=8000,MAX_GOODS=500,MAX_LESSONS=500,MAX_SIGHTINGS=24,MAX_REPORTS=16}
ns.Ledger=L
for _,k in ipairs({"Public","Read","Text","Safe","Integer","Number","Copy","Array","Count","Now","Position"}) do L[k]=ns.Atlas[k] end
L.roles={merchant="Merchant",repair="Repairs",trainer="Trainer",innkeeper="Innkeeper",banker="Banker",auctioneer="Auctioneer",stable="Stable master",transport="Transport"}
L.roleOrder={"merchant","repair","trainer","innkeeper","banker","auctioneer","stable","transport"}
L.VISION="Remember merchants, trainers and useful services encountered during exploration. Record observed goods, recipe sources, locations and access notes."
function L.Key(...) local out={};for i=1,select('#',...) do local s=tostring(select(i,...) or '');out[i]=#s..':'..s end;return table.concat(out) end
function L.Name(v) if L.Text(v,160) and not v:find('%c') then return v end end
function L.Player()
    if ns.PlayerNames and ns.PlayerNames.Current then return ns.PlayerNames:Current() or "Unknown character" end
    local ok,first,last=pcall(UnitName,"player")
    if ok and L.Public(first) and L.Public(last) then
        return L.Name(L.Read(NameUtil and NameUtil.GetFullNameWithoutRealm,first,last)) or L.Name(first) or "Unknown character"
    end
    return "Unknown character"
end
function L.Location(p,near)
    p=p or {};local out={zone=L.Name(p.zone) or "Unknown zone",subzone=L.Name(p.subzone) or "",precision="unknown"}
    if L.Integer(p.mapID,1,2147483647) then out.mapID=p.mapID end
    if (near or p.precision=="npc") and L.Position(p) and not (p.x==0 and p.y==0) then
        out.x,out.y,out.precision=p.x,p.y,p.precision=="npc" and "npc" or "player"
    end
    return out
end
function L.PositionLabel(p)
    if not p then return "Location unknown" end
    local text=p.zone..(p.subzone~="" and " / "..p.subzone or "")
    if L.Position(p) then
        return (p.precision=="npc" and "Observed at " or "Encountered near ")..text..
            string.format(" (%.2f, %.2f; %s)",p.x/100,p.y/100,p.precision=="npc" and "NPC position" or "approximate")
    end
    return text.." — coordinates not recorded for this sighting"
end
function L.Stock(n)
    if not L.Public(n) then return {state="unknown"} end
    if n==-1 then return {state="unlimited"} end
    if L.Integer(n,0,1000000000) then return {state=n==0 and "soldout" or "finite",quantity=n} end
    return {state="unknown"}
end
function L.StockLabel(s)
    if s.state=="finite" then return tostring(s.quantity).." available" end
    return ({soldout="Sold out",unlimited="Unrestricted availability",unknown="Unknown quantity"})[s.state] or "Unknown quantity"
end
function L.GoodKey(v) return L.Key(v.itemID,v.currencyID,v.spellID,v.bundle,v.variant or "") end
function L.LessonKey(v) return L.Key(v.name,v.rank,v.category) end
function L.Date(v) return L.Integer(v,1,9999999999) and ns.AtlasUI.Date(v) or "Not recorded" end
local function touch(f,at) f.first=f.first and math.min(f.first,at) or at;f.last=math.max(f.last or 0,at) end
local function reportIdentity(report)
    local o=report.identity and report.identity.origin
    if o and L.Text(o.source,160) and L.Text(o.key,700) then return L.Key(o.source,o.key) end
end
function L.ReconcileReports(db)
    if ns.InitializationBlocked or (db.schema or 0)>L.SCHEMA then return end
    local contacts=db.contacts or {};local parent,ids={},{}
    for id in pairs(contacts) do parent[id]=id;ids[#ids+1]=id end;table.sort(ids)
    local function root(id) while parent[id] and parent[id]~=id do id=parent[id] end;return id end
    local origins={}
    for _,id in ipairs(ids) do for _,report in ipairs(contacts[id].reports or {}) do
        local key=reportIdentity(report)
        if key then
            local prior=origins[key]
            if prior then
                local a,b=root(prior),root(id)
                local indexed=db.reportKeys and db.reportKeys[key]
                if indexed and parent[indexed] and root(indexed)==b then parent[a]=b else parent[b]=a end
            else origins[key]=id end
        end
    end end
    local function retain(into,e)
        into.migrationEvidence=into.migrationEvidence or {}
        for key,original in pairs(e.migrationEvidence or {}) do
            if not into.migrationEvidence[key] then into.migrationEvidence[key]=L.Copy(original) end
        end
        local key=L.Key(e.id,e.reference)
        if not into.migrationEvidence[key] then
            local original={};for field,value in pairs(e) do if field~="migrationEvidence" then original[field]=L.Copy(value) end end
            into.migrationEvidence[key]=original
        end
    end
    for _,id in ipairs(ids) do
        local destination=root(id)
        if destination~=id then
            local a,b=contacts[destination],contacts[id]
            retain(a,a);retain(a,b)
            if b.note and b.note~="" and a.note~=b.note then
                local combined=(a.note or "")..((a.note or "")~="" and "\n\n" or "")..b.note
                if #combined<=4000 then a.note=combined end
                -- Over-limit or conflicting originals remain accessible in the
                -- ordinary details pane, outside the editable 4,000-byte note.
            end
            a.favourite=a.favourite or b.favourite
            for _,field in ipairs({"roles","manualRoles","specialities","goods","lessons"}) do
                a[field]=a[field] or {}
                for key,v in pairs(b[field] or {}) do
                    local old=a[field][key]
                    local stamp=v.last or v.at or 0
                    if not old or stamp>(old.last or old.at or 0) then a[field][key]=L.Copy(v) end
                end
            end
            for _,p in ipairs(b.sightings or {}) do a.sightings[#a.sightings+1]=L.Copy(p) end
            local reportKeys={};for i,r in ipairs(a.reports) do local key=reportIdentity(r);if key then reportKeys[key]=i end end
            for _,r in ipairs(b.reports or {}) do
                local key=reportIdentity(r);local index=key and reportKeys[key]
                if index then
                    local combined,reason=ns.LedgerReports.MergeStored(a.reports[index],r)
                    if combined then a.reports[index]=combined
                    else a.migrationIssue=reason.." Both original reports are retained with the imported contact evidence." end
                else a.reports[#a.reports+1]=L.Copy(r);if key then reportKeys[key]=#a.reports end end
            end
            for _,field in ipairs({"personal","recorded"}) do a[field]=a[field] or b[field] end
            if b.first then a.first=math.min(a.first or b.first,b.first) end
            if b.last then a.last=math.max(a.last or 0,b.last) end
            for field,value in pairs(b) do if a[field]==nil and field~="migrationEvidence" then a[field]=L.Copy(value) end end
            a.aliases=a.aliases or {};for guid,at in pairs(b.aliases or {}) do a.aliases[guid]=math.max(a.aliases[guid] or 0,at) end
            db.contactAliases=db.contactAliases or {};db.contactAliases[id]=destination
            contacts[id]=nil
        end
    end
    for _,index in ipairs({db.references or {},db.aliases or {},db.reportKeys or {},db.contactAliases or {}}) do
        for key,id in pairs(index) do if parent[id] then index[key]=root(id) end end
    end
    db.reportKeys=db.reportKeys or {};db.references=db.references or {}
    for id,e in pairs(contacts) do
        db.references[e.reference]=id
        for _,original in pairs(e.migrationEvidence or {}) do db.references[original.reference]=id end
        for _,r in ipairs(e.reports or {}) do local key=reportIdentity(r);if key then db.reportKeys[key]=id end end
    end
end
function ns.CreateLedgerJournal(saved)
    local readOnly=ns.InitializationBlocked or (type(saved.schema)=="number" and saved.schema>L.SCHEMA)
    local db=readOnly and {} or saved
    for _,k in ipairs({"contacts","state","aliases","reportKeys","references"}) do if type(db[k])~="table" then db[k]={} end end
    db.schema=L.SCHEMA;db.serial=L.Integer(db.serial,0,999999999) and db.serial or 0
    if not L.Text(db.origin,100) then db.origin=tostring(L.Now())..'-'..math.random(1,999999999) end
    local j={db=db,state=db.state,readOnly=readOnly,revision=0,cache={}}
    function j:Changed(id)
        local e=id and self:Get(id);id=e and e.id or id
        self.revision=self.revision+1;self.cache[id or false]=nil;if self.onChange then self.onChange(id) end
    end
    function j:Get(id)
        local seen={}
        while db.contactAliases and db.contactAliases[id] and not seen[id] do seen[id]=true;id=db.contactAliases[id] end
        return db.contacts[id]
    end
    function j:New(name,dryRun)
        if self.readOnly or L.Count(db.contacts)>=L.MAX_CONTACTS or L.Count(db.references)>=L.MAX_REFERENCES then return nil,"Contact/reference limit reached or newer schema is read-only." end
        if dryRun then return true end
        local id
        repeat db.serial=db.serial+1;id="contact:"..db.serial until not db.contacts[id] and not (db.contactAliases and db.contactAliases[id])
        local e={id=id,reference="ledger:"..(db.contactOrigin or db.origin)..":"..db.serial,name=name,sublabel="",roles={},manualRoles={},specialities={},
            sightings={},goods={},lessons={},reports={},note="",favourite=false,aliases={}}
        db.contacts[id]=e;db.references[e.reference]=id;return e
    end
    function j:Origin(e,key,at,method)
        return {source=L.Player(),key=e.reference..":"..key,method=method or "observed",at=at}
    end
    function j:Bind(e,guid)
        if db.aliases[guid] and db.aliases[guid]~=e.id then return nil,"This encounter already belongs to another contact." end
        if not e.aliases[guid] then
            if L.Count(e.aliases)>=8 then
                local old;for key,at in pairs(e.aliases) do if not old or at<e.aliases[old] then old=key end end
                e.aliases[old]=nil;db.aliases[old]=nil
            end
        end
        db.aliases[guid]=e.id;e.aliases[guid]=L.Now();return true
    end
    function j:Sighting(e,p,at)
        local key=L.Key(p.mapID,p.zone,p.subzone,p.x and math.floor(p.x/50),p.y and math.floor(p.y/50),p.precision)
        local found
        for _,v in ipairs(e.sightings) do if v.key==key then found=v;break end end
        if not found then found=L.Copy(p);found.key=key;e.sightings[#e.sightings+1]=found end
        found.x,found.y=p.x,p.y;touch(found,at);found.origin=self:Origin(e,"location:"..key,at)
        table.sort(e.sightings,function(a,b) return a.last>b.last end)
        while #e.sightings>L.MAX_SIGHTINGS do table.remove(e.sightings) end
    end
    function j:Encounter(v,roles,near,selected)
        if self.readOnly or not v or not L.Name(v.name) or not L.Text(v.guid,160) or not L.Integer(v.npcID,1,10000000) then return end
        local e=self:Get(db.aliases[v.guid]);local at=L.Now()
        if selected and not e then
            e=self:Get(selected)
            if not e or (e.npcID and e.npcID~=v.npcID) then return nil,"NPC template does not match the selected contact." end
        end
        if not e then
            e=self:New(v.name);if not e then return end
            for _,other in pairs(db.contacts) do if other~=e and other.npcID==v.npcID then e.ambiguous=true;break end end
        end
        local newMerchant=roles and roles.merchant and not e.roles.merchant
        self:Bind(e,v.guid);e.npcID=v.npcID;e.name=v.name;e.identityOrigin=self:Origin(e,"identity",at)
        if L.Name(v.sublabel) then e.sublabel=v.sublabel;e.sublabelOrigin=self:Origin(e,"sublabel",at) end
        e.personal=true;touch(e,at)
        for role in pairs(roles or {}) do if L.roles[role] then e.roles[role]=self:Origin(e,"role:"..role,at) end end
        self:Sighting(e,L.Location(v.location,near),at);self:Changed(e.id)
        if ns.RecordFieldbookDiscovery then ns.RecordFieldbookDiscovery("merchants",e,self) end
        if newMerchant and self.onMerchantDiscovered then self.onMerchantDiscovered(e) end
        return e
    end
    function j:Manual(v)
        if self.readOnly or not L.Name(v.name) then return nil,"Enter a contact name." end
        local e,err=self:New(v.name);if not e then return nil,err end
        e.recorded=true;e.identityOrigin=self:Origin(e,"identity",L.Now(),"recorded")
        e.sublabel=L.Name(v.sublabel) or "";e.sublabelOrigin=self:Origin(e,"sublabel",L.Now(),"recorded")
        if ns.RecordFieldbookDiscovery then ns.RecordFieldbookDiscovery("merchants",e,self) end
        self:Changed(e.id);return e
    end
    function j:Annotate(id,note,role,speciality)
        local e=self:Get(id);if self.readOnly or not e or not L.Text(note,4000,true) then return nil,"Use plain notes, up to 4,000 bytes." end
        if e.note~=note then e.note=note;e.noteOrigin=self:Origin(e,"notes",L.Now(),"recorded") end
        if type(role)=="table" then
            for key in pairs(e.manualRoles) do if role[key]~=true then e.manualRoles[key]=nil end end
            for key,selected in pairs(role) do
                if selected==true and L.roles[key] and not e.manualRoles[key] then
                    e.manualRoles[key]=self:Origin(e,"manual-role:"..key,L.Now(),"recorded")
                end
            end
        elseif role and L.roles[role] then e.manualRoles[role]=self:Origin(e,"manual-role:"..role,L.Now(),"recorded") end
        if L.Name(speciality) and (e.specialities[speciality] or L.Count(e.specialities)<32) then e.specialities[speciality]=self:Origin(e,"speciality:"..speciality,L.Now(),"recorded") end
        self:Changed(id);return true
    end
    function j:Favourite(id) local e=self:Get(id);if e and not self.readOnly then e.favourite=not e.favourite;self:Changed(id) end end
    function j:Remove(id)
        if self.readOnly then return nil,"Newer Ledger schema is read-only." end
        local e=self:Get(id);if not e then return nil,"Contact no longer exists." end
        local selected=self:Get(self.state.selected);id=e.id
        db.contacts[id]=nil
        for _,index in ipairs({db.aliases,db.references,db.reportKeys}) do
            for key,value in pairs(index) do if value==id then index[key]=nil end end
        end
        if selected==e then
            self.state.selected=nil;self.state.sighting=nil;self.state.sightingKey=nil
            self.state.focus=nil;self.state.focusReported=nil;self.state.detailScroll=0
        end
        self:Changed(id);return true
    end
    function j:Reference(reference) return self:Get(db.references[reference]) end
    function j:ImportedNotes(e)
        local notes,seen={},{}
        for key,original in pairs(e.migrationEvidence or {}) do
            if original.note and original.note~="" and not (e.note or ""):find(original.note,1,true) and not seen[original.note] then
                notes[#notes+1]={key=key,text=original.note};seen[original.note]=true
            end
        end
        table.sort(notes,function(a,b) return a.key<b.key end)
        local lines={};for _,note in ipairs(notes) do lines[#lines+1]="Retained imported note:\n"..note.text end
        return table.concat(lines,"\n\n")
    end
    function j:Link(sourceID,destinationID)
        local a,b=self:Get(sourceID),self:Get(destinationID)
        if self.readOnly or not a or not b or a==b then return nil,"Choose two different contacts." end
        sourceID,destinationID=a.id,b.id
        if a.npcID and b.npcID and a.npcID~=b.npcID then return nil,"NPC templates differ; identity linking is unavailable." end
        local out=L.Copy(b)
        for _,kind in ipairs({"goods","lessons"}) do
            for key,v in pairs(a[kind]) do
                local old=out[kind][key]
                if not old or v.last>old.last then out[kind][key]=L.Copy(v) end
                if old then out[kind][key].first=math.min(old.first,v.first) end
            end
            if L.Count(out[kind])>(kind=="goods" and L.MAX_GOODS or L.MAX_LESSONS) then return nil,"Combined offering limit exceeded." end
        end
        if #out.reports+#a.reports>L.MAX_REPORTS then return nil,"Combined report-source limit exceeded." end
        if a.note~="" and a.note~=b.note then out.note=b.note..(b.note~="" and "\n\n" or "")..a.note end
        if #out.note>4000 then return nil,"Combined notes exceed 4,000 bytes; edit them first." end
        if out.note~=b.note then out.noteOrigin=self:Origin(b,"notes",L.Now(),"recorded") end
        for _,kind in ipairs({"roles","manualRoles","specialities"}) do for k,o in pairs(a[kind]) do if not out[kind][k] or o.at>out[kind][k].at then out[kind][k]=L.Copy(o) end end end
        if L.Count(out.specialities)>32 then return nil,"Combined speciality limit exceeded." end
        for _,r in ipairs(a.reports) do out.reports[#out.reports+1]=L.Copy(r) end
        for _,p in ipairs(a.sightings) do out.sightings[#out.sightings+1]=L.Copy(p) end
        table.sort(out.sightings,function(x,y) return x.last>y.last end);while #out.sightings>L.MAX_SIGHTINGS do table.remove(out.sightings) end
        if a.personal and (not b.last or a.last>b.last) then
            for _,k in ipairs({"name","sublabel","identityOrigin","sublabelOrigin"}) do out[k]=L.Copy(a[k]) end
        end
        out.personal=a.personal or b.personal;out.recorded=a.recorded or b.recorded;out.npcID=b.npcID or a.npcID
        if a.first then out.first=math.min(a.first,b.first or a.first) end
        if a.last then out.last=math.max(a.last,b.last or a.last) end
        out.favourite=a.favourite or b.favourite;out.ambiguous=nil;out.linkedAt=L.Now()
        if a.migrationEvidence then
            out.migrationEvidence=out.migrationEvidence or {}
            for key,original in pairs(a.migrationEvidence) do if not out.migrationEvidence[key] then out.migrationEvidence[key]=L.Copy(original) end end
        end
        for _,kind in ipairs({"merchantInspection","trainerInspection"}) do if a[kind] and (not out[kind] or a[kind].at>out[kind].at) then out[kind]=L.Copy(a[kind]) end end
        -- Binding is a deliberate user assertion, never an automatic name/template merge.
        db.contacts[destinationID]=out;db.contacts[sourceID]=nil
        for guid in pairs(a.aliases) do db.aliases[guid]=nil;self:Bind(out,guid) end
        for key,id in pairs(db.reportKeys) do if id==sourceID then db.reportKeys[key]=destinationID end end
        for key,id in pairs(db.references) do if id==sourceID then db.references[key]=destinationID end end
        for key,id in pairs(db.contactAliases or {}) do if id==sourceID then db.contactAliases[key]=destinationID end end
        self.cache[sourceID]=nil;self:Changed(destinationID);return out
    end
    function j:Begin(id,kind)
        local e=self:Get(id);if not e or self.readOnly then return end
        db.serial=db.serial+1
        local visit={id=db.serial,contact=id,kind=kind,at=L.Now(),seen={},complete=false,reason="Inspection pending"}
        e[kind.."Inspection"]={id=visit.id,at=visit.at,complete=false,reason=visit.reason,seen={}}
        self:Changed(id);return visit
    end
    function j:Scan(visit,rows,complete,reason)
        local e=visit and self:Get(visit.contact);if self.readOnly or not e or visit.closed then return end
        local kind=visit.kind;local inspection=e[kind.."Inspection"]
        if not inspection or inspection.id~=visit.id then return end
        local store=kind=="merchant" and e.goods or e.lessons;local seen={};local at=L.Now()
        for _,data in ipairs(rows) do
            local key=kind=="merchant" and L.GoodKey(data) or L.LessonKey(data)
            if kind=="merchant" and (not data.bundle or not data.costsKnown) then
                local candidate,ambiguous
                for oldKey,old in pairs(store) do
                    if old.itemID==data.itemID and old.currencyID==data.currencyID and old.spellID==data.spellID and (not data.bundle or old.bundle==data.bundle) then
                        if candidate then ambiguous=true else candidate=oldKey end
                    end
                end
                if candidate and not ambiguous then key=candidate end
            end
            local duplicate=seen[key]
            if duplicate then complete=false;reason="Ambiguous duplicate offering" end
            seen[key]=true
            local old=store[key]
            if duplicate then
                -- Do not silently choose one of two conflicting same-key listings.
            elseif not old and L.Count(store)>=(kind=="merchant" and L.MAX_GOODS or L.MAX_LESSONS) then
                complete=false;reason="Stored offering limit reached"
            else
                local v=L.Copy(data);v.key=key;v.first=old and old.first or at;v.last=at;v.visit=visit.id
                if kind=="trainer" and old and v.icon==nil then v.icon=old.icon end
                if kind=="merchant" and old then
                    for _,field in ipairs({"name","recipe","profession","icon","bundle"}) do if v[field]==nil then v[field]=old[field] end end
                    if not v.costsKnown then v.variant=old.variant;v.costs=L.Copy(old.costs);v.costsAt=old.costsAt end
                end
                if kind=="merchant" and v.costsKnown then v.costsAt=at end
                if v.price~=nil then v.priceAt=at elseif old then v.price,v.priceAt=old.price,old.priceAt end
                if kind=="merchant" then v.stockAt=at end
                v.origin=self:Origin(e,kind..":"..key,at);store[key]=v;data.observationKey=key
                if kind=="trainer" and L.Name(data.category) and (e.specialities[data.category] or L.Count(e.specialities)<32) then e.specialities[data.category]=self:Origin(e,"speciality:"..data.category,at) end
                visit.seen[key]=true
            end
        end
        inspection.at=at;inspection.complete=complete==true;inspection.reason=reason or "Readable, unfiltered inspection"
        inspection.seen=seen;visit.complete=inspection.complete
        -- Positive history survives. Absence refers only to this reliable scan.
        for key,v in pairs(store) do v.notSeen=complete and not seen[key] or nil end
        self:Changed(e.id)
    end
    function j:Metadata(id,key,itemID,metadata)
        local e=self:Get(id);local v=e and e.goods[key]
        if self.readOnly or not v or v.itemID~=itemID then return end
        for _,k in ipairs({"name","recipe","profession","icon"}) do if metadata[k]~=nil then v[k]=metadata[k] end end
        self:Changed(id) -- metadata never refreshes a price, stock or observation timestamp
    end
    function j:Locations(e)
        local rows={};for _,p in ipairs(e.sightings) do rows[#rows+1]=p end
        for _,report in ipairs(e.reports) do for _,p in ipairs(report.locations) do
            local v=L.Copy(p);v.reported=true
            local receipt=report.factReceipts and report.factReceipts[L.Key(p.origin.source,p.origin.key)]
            v.received=receipt and receipt.received or report.received;rows[#rows+1]=v
        end end
        table.sort(rows,function(a,b)
            if not a.reported~=not b.reported then return not a.reported end
            if a.last~=b.last then return a.last>b.last end
            return L.Key(a.origin.source,a.origin.key)<L.Key(b.origin.source,b.origin.key)
        end)
        return rows
    end
    function j:Roles(e)
        local r={};for role in pairs(e.roles) do r[role]="personal" end
        for role in pairs(e.manualRoles) do if not r[role] then r[role]="manual" end end
        for _,report in ipairs(e.reports) do for role in pairs(report.roles) do if not r[role] then r[role]="reported" end end end
        return r
    end
    function j:RoleText(e)
        local r,parts=self:Roles(e),{}
        for _,role in ipairs(L.roleOrder) do if r[role] then parts[#parts+1]=L.roles[role]..(r[role]=="manual" and " (manual)" or r[role]=="reported" and " (reported)" or "") end end
        return table.concat(parts,", ")
    end
    function j:Sublabel(e)
        if e.sublabel=="" then return "" end
        local label=e.sublabel:match("^%s*<(.-)>%s*$") or e.sublabel
        return "<"..label..">"..(not e.sublabelOrigin and #e.reports>0 and " (reported)" or e.sublabelOrigin and e.sublabelOrigin.method=="recorded" and " (manual)" or "")
    end
    function j:Index(e)
        if self.cache[e.id] then return self.cache[e.id] end
        local fields={e.name,e.sublabel,e.note,self:RoleText(e),self:ImportedNotes(e)};local offerings={};local recipe=false
        for s in pairs(e.specialities) do fields[#fields+1]=s end
        local locations=self:Locations(e);for _,p in ipairs(locations) do fields[#fields+1]=p.zone;fields[#fields+1]=p.subzone end
        local function add(store,kind,reported)
            for key,v in pairs(store) do
                offerings[#offerings+1]={text=string.lower((v.name or "").." "..(v.profession or "")),name=v.name or "Unknown offering",key=v.key or key,kind=kind,reported=reported}
                recipe=recipe or v.recipe==true
            end
        end
        add(e.goods,"goods");add(e.lessons,"training")
        for _,report in ipairs(e.reports) do
            add(report.goods,"goods",true);add(report.lessons,"training",true)
            for s in pairs(report.specialities) do fields[#fields+1]=s end
        end
        local value={text=string.lower(table.concat(fields," ")),offerings=offerings,recipe=recipe,locations=locations,roles=self:Roles(e)}
        self.cache[e.id]=value;return value
    end
    function j:List(f)
        f=f or {};local q=string.lower(f.query or "");local rows={};local total=0
        local zone,subzone=f.zone,f.subzone;local currentOnly=f.currentZone==true
        if currentOnly then zone=L.Name(ns.Atlas.CurrentLocation().zone);subzone=nil end
        for _,e in pairs(db.contacts) do
            total=total+1;local ix=self:Index(e);local roleOK=not f.roles or not next(f.roles)
            for role in pairs(f.roles or {}) do if ix.roles[role] then roleOK=true end end
            local zoneOK=not zone and not currentOnly
            for _,p in ipairs(ix.locations) do if p.zone==zone and (not subzone or p.subzone==subzone) then zoneOK=true end end
            if roleOK and zoneOK and (not f.favourites or e.favourite) and (not f.recipes or ix.recipe)
                and (f.knowledge~="personal" or e.personal) and (f.knowledge~="reported" or (not e.personal and not e.recorded and #e.reports>0)) then
                local match=ix.text:find(q,1,true)~=nil;local why
                if q~="" then for _,o in ipairs(ix.offerings) do if o.text:find(q,1,true) then why=o;match=true;break end end end
                if match then rows[#rows+1]={contact=e,match=why} end
            end
        end
        table.sort(rows,function(a,b)
            a,b=a.contact,b.contact
            if f.sort=="recent" and (a.last or 0)~=(b.last or 0) then return (a.last or 0)>(b.last or 0) end
            if a.name:lower()==b.name:lower() then return a.id<b.id end;return a.name:lower()<b.name:lower()
        end)
        return rows,total
    end
    function j:Zones()
        local zones={};for _,e in pairs(db.contacts) do for _,p in ipairs(self:Index(e).locations) do
            zones[p.zone]=zones[p.zone] or {};if p.subzone~="" then zones[p.zone][p.subzone]=true end
        end end;return zones
    end
    return j
end
