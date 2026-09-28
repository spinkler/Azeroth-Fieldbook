local _, ns = ...
local T={SCHEMA=1,MAX_KINDS=2000,MAX_ENCOUNTERS=20000,MAX_ITEMS=80}
ns.Treasure=T
-- These exposed helpers are pure. Treasure never borrows another journal's state.
for _,key in ipairs({"Public","Read","Text","Safe","Number","Integer","Array","Count","Copy","Now","Position"}) do T[key]=ns.Atlas[key] end
T.ICON="Interface\\Icons\\INV_Misc_TreasureChest01a"
T.VISION="Record discovered chests, locked containers and salvage opportunities. Distinguish sightings from opened finds, with locations, observed contents and personal notes."
T.contexts={world="World find",acquired="Acquired",opened="Contents inspected",carried="Observed carried"}
T.captures={missing="Contents not recorded",partial="Partial contents capture",full="Full contents capture (player assertion)"}
function T.Name(v) if T.Text(v,160) and not v:find('%c') then return v end end
function T.Key(a,b) return #a..":"..a..#b..":"..b end
function T.Player()
    if ns.PlayerNames and ns.PlayerNames.Current then return ns.PlayerNames:Current() or "Unknown character" end
    local name=T.Read(UnitName,"player");return T.Name(name) or "Unknown character"
end
function T.Date(at) return T.Integer(at,0,9999999999) and ns.AtlasUI.Date(at) or "Time unknown" end
function T.Location(v,context)
    if type(v)~="table" or getmetatable(v) then return nil,"Invalid location." end
    local p={}
    for _,key in ipairs({"zone","subzone","floor","instance"}) do
        if v[key]~=nil and not T.Text(v[key],160,true) then return nil,"Use plain location labels." end
        p[key]=v[key] or ""
    end
    if v.mapID~=nil then
        if not T.Integer(v.mapID,1,2147483647) then return nil,"Invalid map ID." end
        p.mapID=v.mapID
    end
    p.precision="unknown";p.method=v.method or "manual";p.meaning=context
    if p.method~="manual" and p.method~="observed" then return nil,"Invalid location provenance." end
    if v.x~=nil or v.y~=nil then
        if not T.Position(v) or (v.x==0 and v.y==0) then return nil,"Use a map and both coordinates; 0,0 is not a location." end
        if v.precision~="player" and v.precision~="manual" then return nil,"Identify approximate player or manually placed coordinates." end
        p.x,p.y,p.precision=v.x,v.y,v.precision
    end
    return p
end
function T.CurrentLocation(context)
    local p=ns.Atlas.CurrentLocation();p.precision=T.Position(p) and "player" or "unknown";p.method="observed"
    p.instance=T.Name(T.Read(GetInstanceInfo)) or ""
    return T.Location(p,context)
end
function T.LocationText(p)
    local name=p.zone~="" and p.zone or "Unknown zone"
    if p.subzone~="" then name=name.." / "..p.subzone end
    if p.floor~="" then name=name.." / "..p.floor end
    if p.instance~="" then name=name.." / "..p.instance end
    local prefix=({acquired="Acquisition: ",opened="Opening: ",carried="Carried: ",world="Past find: "})[p.meaning] or ""
    return prefix..name..(T.Position(p) and string.format(" • %.2f, %.2f (%s)",p.x/100,p.y/100,
        p.precision=="player" and "approximate player position" or "manually placed") or " • coordinates unknown")
end
function T.Outcome(v)
    local out={T.contexts[v.context]}
    if v.facts.sighted and v.context=="world" then out[#out+1]="Sighted" end
    if v.facts.attempted then out[#out+1]="Access attempted" end
    if v.facts.inspected and v.context~="opened" then out[#out+1]="Contents inspected" end
    if v.result~="" then out[#out+1]=v.result end
    return table.concat(out," • ")
end
function T.Kind(v)
    if type(v)~="table" or getmetatable(v) or not T.Name(v.name) then return nil,"Enter a container/find name." end
    if v.form~="world" and v.form~="portable" then return nil,"Choose world or portable form." end
    if not ({container=true,find=true,salvage=true})[v.category] then return nil,"Choose a category." end
    local e={name=v.name,form=v.form,category=v.category}
    if v.itemID~=nil then
        if v.form~="portable" or not T.Integer(v.itemID,1,2147483647) then return nil,"Item identities belong only to portable containers." end
        e.itemID=v.itemID
    end
    for _,key in ipairs({"label","note","bookmarkNote"}) do
        if not T.Text(v[key] or "",key=="label" and 160 or 4000,true) then return nil,"Use plain labels/notes (160 / 4,000 bytes)." end
        e[key]=v[key] or ""
    end
    e.bookmark=v.bookmark==true
    return e
end
function T.Encounter(v,form)
    if type(v)~="table" or getmetatable(v) then return nil,"Invalid encounter." end
    if not T.contexts[v.context] or (form=="world")~=(v.context=="world") then return nil,"Encounter context does not match the container form." end
    local p,err=T.Location(v.location or {},v.context);if not p then return nil,err end
    if not ({missing=true,partial=true,full=true})[v.capture] then return nil,"Choose contents capture completeness." end
    if type(v.facts)~="table" or getmetatable(v.facts) then return nil,"Invalid outcome facts." end
    local out={context=v.context,location=p,capture=v.capture,items={},facts={}}
    for _,k in ipairs({"sighted","attempted","inspected"}) do
        if v.facts[k]~=nil and type(v.facts[k])~="boolean" then return nil,"Invalid outcome flag." end
        out.facts[k]=v.facts[k]==true
    end
    if v.context=="opened" then out.facts.inspected=true end
    if not T.Array(v.items or {},T.MAX_ITEMS) then return nil,"At most 80 contents rows per encounter." end
    local seen={}
    for _,item in ipairs(v.items or {}) do
        if type(item)~="table" or getmetatable(item) then return nil,"Invalid item observation." end
        local row={}
        if item.itemID~=nil then
            if not T.Integer(item.itemID,1,2147483647) then return nil,"Invalid observed item ID." end
            row.itemID=item.itemID
        end
        if item.name~=nil then if not T.Name(item.name) then return nil,"Invalid item name." end;row.name=item.name end
        if not row.itemID and not row.name then return nil,"Each contents row needs an item ID or name." end
        if not T.Integer(item.quantity,1,1000000) then return nil,"Item quantity must be 1–1,000,000." end
        row.quantity=item.quantity
        if item.recovered~=nil then
            if not T.Integer(item.recovered,1,item.quantity) then return nil,"Recovered quantity must not exceed observed quantity." end
            row.recovered=item.recovered
        end
        local key=row.itemID and "item:"..row.itemID or "name:"..row.name
        if seen[key] then return nil,"Combine duplicate contents rows." end
        seen[key]=true;out.items[#out.items+1]=row
    end
    if #out.items>0 and (out.capture=="missing" or not out.facts.inspected) then return nil,"Recorded items require an inspection and partial/full capture." end
    if out.capture~="missing" and not out.facts.inspected then return nil,"Contents capture requires inspection." end
    for _,key in ipairs({"note","access","result"}) do
        if not T.Text(v[key] or "",key=="note" and 4000 or 500,true) then return nil,"Use plain encounter notes and access observations." end
        out[key]=v[key] or ""
    end
    out.accessMethod=v.accessMethod or "manual"
    if out.accessMethod~="manual" and out.accessMethod~="observed" then return nil,"Invalid access provenance." end
    return out
end
function ns.CreateTreasureJournal(saved)
    local readOnly=type(saved)~="table" or (saved.schema~=nil and (not T.Integer(saved.schema,0,T.SCHEMA)))
    if not readOnly then for _,key in ipairs({"kinds","encounters","state"}) do
        if saved[key]~=nil and type(saved[key])~="table" then readOnly=true end
    end end
    local db=readOnly and {} or saved
    db.kinds=db.kinds or {};db.encounters=db.encounters or {};db.state=db.state or {};db.schema=T.SCHEMA
    db.serial=T.Integer(db.serial,0,999999999) and db.serial or 0
    db.origin=T.Name(db.origin) or tostring(T.Now()).."-"..math.random(1,999999999)
    local j={db=db,state=db.state,readOnly=readOnly,kinds={},encounters={},cache={},metadata={},requested={},
        metadataCount=0,requestCount=0,invalid=0,revision=0}
    for id,e in pairs(db.kinds) do
        local n=T.Kind(e)
        if n and T.Text(id,64) and e.id==id and T.Text(e.reference,160) then
            for k,value in pairs(n) do e[k]=value end;j.kinds[id]=e
        else j.invalid=j.invalid+1 end
    end
    for id,v in pairs(db.encounters) do
        local e=type(v)=="table" and j.kinds[v.kindID]
        local n=e and T.Encounter(v,e.form);local o=type(v)=="table" and v.origin
        if n and T.Text(id,64) and v.id==id and type(o)=="table" and T.Name(o.source) and T.Text(o.key,200)
            and (o.method=="manual" or o.method=="observed") and (o.at==nil or T.Integer(o.at,0,9999999999))
            and (v.reported==nil or v.reported==true) and (not v.reported or (T.Integer(v.received,0,9999999999)
                and type(v.reportIdentity)=="table" and T.Name(v.reportIdentity.source) and T.Text(v.reportIdentity.key,160)
                and T.Kind(v.reportIdentity) and (v.reportNote==nil or T.Text(v.reportNote,4000,true)))) then
            for k,value in pairs(n) do v[k]=value end;j.encounters[id]=v
        else j.invalid=j.invalid+1 end
    end
    function j:Changed(id)
        self.revision=self.revision+1;self.histories=nil
        if id then self.cache[id]=nil else self.cache={} end
        if self.onChange then self.onChange(id) end
    end
    function j:Get(id) return self.kinds[id] end
    function j:Next(prefix)
        repeat db.serial=db.serial+1 until not db.kinds[prefix..db.serial] and not db.encounters[prefix..db.serial]
        return prefix..db.serial
    end
    function j:FindItem(itemID)
        -- A client item ID is a kind identity; no world-object GUID parsing.
        for _,e in pairs(self.kinds) do if e.form=="portable" and e.itemID==itemID then return e end end
    end
    function j:NewKind(v)
        if self.readOnly then return nil,"Saved schema is read-only." end
        local e,err=T.Kind(v);if not e then return nil,err end
        if T.Count(db.kinds)>=T.MAX_KINDS then return nil,"2,000-kind limit reached; existing history is preserved." end
        e.id=self:Next("kind:");e.reference="treasure:"..db.origin..":"..e.id
        self.kinds[e.id]=e;db.kinds[e.id]=e;return e
    end
    function j:Record(kindID,kind,v,method)
        if self.readOnly then return nil,"Saved schema is read-only." end
        local e=kindID and self:Get(kindID)
        if kindID and not e then return nil,"Choose an existing kind." end
        local k,err=e,nil;if not k then k,err=T.Kind(kind) end;if not k then return nil,err end
        local encounter;encounter,err=T.Encounter(v,k.form);if not encounter then return nil,err end
        if v.timeUnknown~=nil and type(v.timeUnknown)~="boolean" then return nil,"Invalid observation time choice." end
        if T.Count(db.encounters)>=T.MAX_ENCOUNTERS then return nil,"20,000-encounter limit reached; no history was discarded." end
        if method~="observed" then method="manual" end
        if not e and k.itemID then e=self:FindItem(k.itemID) end
        if not e then e,err=self:NewKind(k);if not e then return nil,err end end
        encounter.id=self:Next("enc:");encounter.kindID=e.id
        encounter.origin={source=T.Player(),key=e.reference..":"..encounter.id,method=method}
        encounter.recordedAt=T.Now()
        if method=="observed" or not v.timeUnknown then encounter.origin.at=encounter.recordedAt end
        self.encounters[encounter.id]=encounter;db.encounters[encounter.id]=encounter
        self:Changed(e.id);return e,encounter
    end
    function j:History(id)
        local cache=self.cache[id];if cache then return cache.history end
        if not self.histories then
            self.histories={}
            for _,v in pairs(self.encounters) do
                local list=self.histories[v.kindID] or {};self.histories[v.kindID]=list;list[#list+1]=v
            end
        end
        local rows=self.histories[id] or {}
        table.sort(rows,function(a,b) if a.origin.at~=b.origin.at then return (a.origin.at or 0)>(b.origin.at or 0) end;return a.id<b.id end)
        self.cache[id]={history=rows};return rows
    end
    function j:Summary(e)
        self:History(e.id);if self.cache[e.id].summary then return self.cache[e.id].summary end
        local s={personal=0,reported=0,inspections=0,recoveries=0,contents=0,last=0,zones={}}
        for _,v in ipairs(self:History(e.id)) do
            s.last=math.max(s.last,v.origin.at or 0);s.zones[v.location.zone]=true
            if #v.items>0 or v.capture=="full" then s.contents=s.contents+1 end
            if v.reported then s.reported=s.reported+1 else
                s.personal=s.personal+1
                if v.facts.inspected then s.inspections=s.inspections+1 end
                for _,item in ipairs(v.items) do if item.recovered then s.recoveries=s.recoveries+item.recovered end end
            end
        end
        s.knowledge=s.personal>0 and "Personally encountered" or s.reported>0 and "Reported only" or "No encounters recorded"
        self.cache[e.id].summary=s
        return s
    end
    function j:ItemName(item)
        if not item.itemID then return item.name end
        local cached=self.metadata[item.itemID]
        if not cached then
            local name=T.Read(C_Item and C_Item.GetItemNameByID,item.itemID) or T.Read(C_Item and C_Item.GetItemInfo or GetItemInfo,item.itemID)
            if T.Name(name) then
                if self.metadataCount<4096 then self.metadata[item.itemID]=name;self.metadataCount=self.metadataCount+1 end
                cached=name
            end
        end
        if not cached and not self.requested[item.itemID] and self.requestCount<512 then
            self.requested[item.itemID]=true;self.requestCount=self.requestCount+1;T.Read(C_Item and C_Item.RequestLoadItemDataByID,item.itemID)
        end
        return cached or item.name or "Item #"..item.itemID.." (details pending)"
    end
    function j:Title(e) return e.label~="" and e.label or (e.itemID and self:ItemName(e)) or e.name end
    function j:List(f)
        f=f or {};local rows={};local query=T.Text(f.query,200,true) and f.query:lower() or ""
        local current=f.zone=="@current" and T.CurrentLocation("world").zone or f.zone
        for _,e in pairs(self.kinds) do
            local s=self:Summary(e);local cached=self.cache[e.id]
            if not cached.search then
                local text={e.name,e.label,e.note,e.bookmarkNote,self:Title(e)}
                for _,v in ipairs(self:History(e.id)) do
                    local p=v.location;text[#text+1]=p.zone.." "..p.subzone.." "..p.floor.." "..v.note.." "..v.access
                    if p.zone~="" and (not cached.zone or p.zone<cached.zone) then cached.zone=p.zone end
                    for _,item in ipairs(v.items) do text[#text+1]=self:ItemName(item) end
                end
                cached.search=table.concat(text," "):lower()
            end
            local category=not f.category or f.category==e.form or (f.category=="salvage" and e.category=="salvage")
            local source=not f.knowledge or (f.knowledge=="personal" and s.personal>0) or (f.knowledge=="reported" and s.reported>0 and s.personal==0)
                or (f.knowledge=="missing" and s.contents==0) or (f.knowledge=="contents" and s.contents>0)
            if category and source and (not f.zone or s.zones[current]) and (not f.bookmarks or e.bookmark) and cached.search:find(query,1,true) then
                rows[#rows+1]={entry=e,summary=s,zone=cached.zone or "Unknown zone",title=self:Title(e)}
            end
        end
        table.sort(rows,function(a,b)
            if f.sort=="recent" and a.summary.last~=b.summary.last then return a.summary.last>b.summary.last end
            if f.sort=="location" and a.zone~=b.zone then return a.zone<b.zone end
            if a.title:lower()~=b.title:lower() then return a.title:lower()<b.title:lower() end;return a.entry.id<b.entry.id
        end)
        return rows,T.Count(self.kinds)
    end
    function j:Zones(id)
        local rows,seen={},{}
        for _,v in pairs(self.encounters) do if not id or v.kindID==id then
            local p=v.location;local key=tostring(p.mapID)..":"..p.zone
            if not seen[key] and (p.mapID or p.zone~="") then seen[key]=true;rows[#rows+1]=p end
        end end
        table.sort(rows,function(a,b) if a.zone==b.zone then return (a.mapID or 0)<(b.mapID or 0) end;return a.zone<b.zone end);return rows
    end
    function j:Markers(id,mapID,all)
        local rows={}
        for _,v in pairs(self.encounters) do if (all or v.kindID==id) and (not mapID or v.location.mapID==mapID)
            and (v.context=="world" or v.context=="acquired") and T.Position(v.location) then rows[#rows+1]=v end end
        table.sort(rows,function(a,b) return a.id<b.id end);return rows
    end
    function j:Annotate(id,values)
        local e=self:Get(id);if self.readOnly or not e then return nil,"Entry unavailable or read-only." end
        local candidate=T.Copy(e);for _,k in ipairs({"label","note","bookmarkNote","category","form"}) do if values[k]~=nil then candidate[k]=values[k] end end
        if candidate.form~=e.form and #self:History(id)>0 then return nil,"Correct encounter contexts before changing form; record a new kind if necessary." end
        local clean,err=T.Kind(candidate);if not clean then return nil,err end
        for k,v in pairs(clean) do e[k]=v end;self:Changed(id);return true
    end
    function j:Bookmark(id) local e=self:Get(id);if e and not self.readOnly then e.bookmark=not e.bookmark;self:Changed(id) end end
    function j:EditEncounter(id,v)
        local old=self.encounters[id];if self.readOnly or not old or old.reported then return nil,"Only personal encounters can be corrected." end
        local new,err=T.Encounter(v,self:Get(old.kindID).form);if not new then return nil,err end
        if old.origin.method=="observed" then
            -- Editing notes/position must not relabel manual contents as automatic.
            new=T.Copy(old);new.note=v.note or old.note;new.location=assert(T.Location(v.location or old.location,old.context))
            new.access=v.access or old.access;new.accessMethod="manual"
        end
        new.id,new.kindID,new.origin=id,old.kindID,T.Copy(old.origin);new.correctedAt=T.Now()
        new.recordedAt=old.recordedAt
        if old.origin.method=="manual" and v.timeUnknown==true then new.origin.at=nil end
        self.encounters[id]=new;db.encounters[id]=new;self:Changed(old.kindID);return true
    end
    function j:Remove(id,confirmed)
        local v=self.encounters[id]
        if self.readOnly or not v or confirmed~=true then return nil,"Confirm removal of this encounter and its recorded contents." end
        self.encounters[id]=nil;db.encounters[id]=nil
        if self.onRemove then self.onRemove(id,v) end
        self:Changed(v.kindID);return true
    end
    return j
end
