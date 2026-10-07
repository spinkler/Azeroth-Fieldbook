local _,ns=...
local A,C,T=ns.Atlas,ns.AtlasEnvironment,ns.AtlasEntranceTypes
local E={SCHEMA=1,MAX_RECORDS=5000,CLUSTER_YARDS=35,UNKNOWN_YARDS=12,PREFIX="entrance:"}
ns.AtlasEntrances=E
E.generic={id="entrance",label="Generic Entrances",icon="Interface\\Icons\\Achievement_Dungeon_UlduarRaid_Archway_01"}
function E.Category(category) return A.category[category] or (category=="entrance" and E.generic) end
local function plain(t) return type(t)=="table" and not getmetatable(t) end
function E.SupportsStore(saved)
    local s=saved.entrances
    return s==nil or (plain(s) and s.schema==E.SCHEMA and plain(s.records))
end
local function identity(context)
    if not plain(context) or not A.Integer(context.zoneMapID,1,2147483647)
        or not A.Integer(context.bestMapID,1,2147483647) then return end
    for _,field in ipairs({"parentMapID","microMapID"}) do
        if context[field]~=nil and not A.Integer(context[field],1,2147483647) then return end
    end
    for _,field in ipairs({"mapName","microName","zone","subzone","minimap"}) do
        if context[field]~=nil and not A.Text(context[field],160,true) then return end
    end
    return true
end
function E.Valid(e)
    if not plain(e) or not A.Text(e.id,64) or not A.Position(e.exterior) or not identity(e.interior)
        or e.exterior.mapID~=e.interior.zoneMapID or not A.Text(e.name,160)
        or not A.Integer(e.firstSeen,0,9999999999) or not A.Integer(e.lastSeen,e.firstSeen,9999999999)
        or not A.Integer(e.entries,0,1000000000) or not A.Integer(e.exits,0,1000000000)
        or e.entries+e.exits<1 or not plain(e.classification) then return false end
    local kind=e.classification.kind
    if kind~="none" and kind~="inferred" and kind~="player" then return false end
    if not E.Category(e.classification.category) or (kind=="none" and e.classification.category~="entrance") then return false end
    if kind=="inferred" and not A.category[e.classification.category] then return false end
    local evidence=e.entries>0 and e.exits>0 and "corroborated" or e.entries+e.exits>1 and "repeated" or "candidate"
    if e.total~=e.entries+e.exits or e.evidence~=evidence then return false end
    if e.position and (not A.Position(e.position) or e.position.mapID~=e.exterior.mapID) then return false end
    if e.interiorPosition and (not A.Position(e.interiorPosition) or e.interiorPosition.mapID~=e.interior.microMapID) then return false end
    if e.world and not C.ValidWorld(e.world) then return false end
    for _,field in ipairs({"notes","access"}) do if e[field]~=nil and not A.Text(e[field],8000,true) then return false end end
    return true
end
function E.Related(a,b)
    if a.zoneMapID~=b.zoneMapID then return false end
    -- Conflicting numeric interior identities outweigh coincident names.
    if a.microMapID and b.microMapID then return a.microMapID==b.microMapID end
    if a.bestMapID~=a.zoneMapID and b.bestMapID~=b.zoneMapID then
        return a.bestMapID==b.bestMapID or a.parentMapID==b.bestMapID or b.parentMapID==a.bestMapID
    end
    for _,field in ipairs({"subzone","minimap"}) do
        if A.Text(a[field],160) and a[field]~=a.zone and b[field]~=b.zone and a[field]==b[field] then return true end
    end
    return nil -- No distinguishing identity: use the smaller radius.
end
function E.Find(records,observation)
    local best,distance,metric
    local size=observation.size or C.Size(observation.exterior.mapID)
    for id,e in pairs(records) do
        if E.Valid(e) and e.id==id and e.exterior.mapID==observation.exterior.mapID then
            local related=E.Related(e.interior,observation.interior)
            if related~=false then
                local d,source=C.Distance(e.exterior,observation.exterior,e.world,observation.world,size)
                local radius=related and E.CLUSTER_YARDS or E.UNKNOWN_YARDS
                if d and d<=radius and (not distance or d<distance or (d==distance and id<best)) then
                    best,distance,metric=id,d,source
                end
            end
        end
    end
    return best,metric
end
function E.Attach(j)
    if not j.readOnly and j.saved.entrances==nil then j.saved.entrances={schema=E.SCHEMA,records={},nextID=0} end
    local writable=not j.readOnly and E.SupportsStore(j.saved)
    local store=writable and j.saved.entrances or {records={}}
    local s={saved=store,records=store.records,readOnly=not writable,revision=0};j.entrances=s
    if writable then
        if j.state.autoEntrances==nil then j.state.autoEntrances=false end
        if j.state.layers.entrance==nil then j.state.layers.entrance=false end
    end
    function s:Enabled() return not self.readOnly and not ns.InitializationBlocked and j.state.autoEntrances==true end
    function s:Layer(category)
        if category=="entrance" then return j.state.layers.entrance==true end
        return j:Layer(category)
    end
    function s:SetLayer(category,on)
        if category=="entrance" then
            if not self.readOnly then j.state.layers.entrance=on==true end
        else j:SetLayer(category,on) end
    end
    function s:Get(id)
        if not A.Text(id,64) then return end
        local e=self.records[id];if E.Valid(e) and e.id==id then return A.Copy(e) end
    end
    function s:Record(o)
        if not self:Enabled() or type(o)~="table" or not A.Position(o.exterior) or not identity(o.interior)
            or o.exterior.mapID~=o.interior.zoneMapID or (o.direction~="entry" and o.direction~="exit")
            or not A.Integer(o.at,0,9999999999) then return end
        -- Need a real distance metric even for the first candidate. Otherwise
        -- a wide doorway could accrue unmergeable duplicates on later visits.
        if not C.Distance(o.exterior,o.exterior,o.world,o.world,o.size) then return end
        local id,metric=E.Find(self.records,o)
        local e=id and self.records[id]
        local created=not e
        if not e then
            if A.Count(self.records)>=E.MAX_RECORDS then return end
            repeat
                store.nextID=(A.Integer(store.nextID,0,999999999) and store.nextID or 0)+1
                id="n"..store.nextID
            until not self.records[id]
            local name=o.interior.microName
            if not A.Text(name,140) then name=o.interior.subzone end
            if not A.Text(name,140) then name=o.interior.minimap end
            e={id=id,name=A.Text(name,140) and name.." entrance" or "Interior entrance",
                exterior=A.Copy(o.exterior),world=C.ValidWorld(o.world) and A.Copy(o.world) or nil,
                interior=A.Copy(o.interior),firstSeen=o.at,lastSeen=o.at,entries=0,exits=0,
                classification=T.Suggest(o.interior),notes="",access=""}
            self.records[id]=e
        end
        e.lastSeen=math.max(e.lastSeen,o.at)
        local count=o.direction=="entry" and "entries" or "exits"
        e[count]=math.min(1000000000,e[count]+1)
        e.total=e.entries+e.exits
        e.evidence=e.entries>0 and e.exits>0 and "corroborated" or e.total>1 and "repeated" or "candidate"
        -- Keep the first point fixed. Refine metadata when a stable Micro ID
        -- becomes available, but never downgrade it to a zone-only identity.
        if (not e.interior.microMapID and o.interior.microMapID) or
            (e.interior.bestMapID==e.interior.zoneMapID and o.interior.bestMapID~=o.interior.zoneMapID) then
            e.interior=A.Copy(o.interior)
        end
        if A.Position(o.interiorPosition) and o.interiorPosition.mapID==e.interior.microMapID then
            e.interiorPosition=A.Copy(o.interiorPosition)
        end
        if e.classification.kind=="none" then e.classification=T.Suggest(o.interior) end
        e.latest={direction=o.direction,at=o.at,exterior=A.Copy(o.exterior),interior=A.Copy(o.interior),
            coordinateSource=o.coordinateSource,metric=metric or (C.ValidWorld(o.world) and "world" or "map-size")}
        if created then A.EnsureReferences(j.saved) end
        self.revision=self.revision+1
        if created and ns.RecordFieldbookDiscovery then ns.RecordFieldbookDiscovery("atlas",e,self) end
        if created and self.onRecorded then self.onRecorded(A.Copy(e)) end
        return id
    end
    function s:Edit(id,d)
        local e=self.records[id]
        if self.readOnly or ns.InitializationBlocked or not E.Valid(e) then return nil,"Entrance unavailable." end
        if not A.Text(d.name,160) or not A.Text(d.notes or "",8000,true) or not A.Text(d.access or "",8000,true) then
            return nil,"Use plain text within the field limits."
        end
        if not A.Position(d) or d.mapID~=e.exterior.mapID then return nil,"Entrance positions must stay on their exterior zone map." end
        if d.confirmCategory and not E.Category(d.confirmCategory) then return nil,"Choose a supported category." end
        e.name,e.notes,e.access=d.name,d.notes or "",d.access or ""
        e.explored=d.explored==true;e.position={mapID=d.mapID,x=d.x,y=d.y}
        if d.confirmCategory then e.classification={kind="player",category=d.confirmCategory,at=A.Now()} end
        self.revision=self.revision+1;return id
    end
    function s:Delete(id)
        if self.readOnly or ns.InitializationBlocked or not self.records[id] then return false end
        self.records[id]=nil;self.revision=self.revision+1;return true
    end
    return s
end
function E.Project(e)
    local p=e.position or e.exterior
    return {id=E.PREFIX..e.id,entrance=e.id,name=e.name,category=e.classification.category,
        classification=A.Copy(e.classification),mapID=p.mapID,x=p.x,y=p.y,
        zone=e.interior.zone or "",subzone=e.interior.subzone or "",notes=e.notes or "",access=e.access or "",
        interior=e.interior.microName or e.interior.mapName or "",interiorMapID=e.interior.microMapID,
        created=e.firstSeen,updated=e.lastSeen,explored=e.explored==true,stops={},related={},references={},
        provenance={kind="observed",source="Indoor / outdoor traversal"},evidence=e}
end
-- Only the Atlas index, map and editor use this adapter. Deliberate journal
-- methods and all existing report/reference contracts retain their old meaning.
function E.View(j)
    local view={state=j.state,subzones=j.subzones,readOnly=j.readOnly,saved=j.saved,records=j.records}
    function view:Get(id,expedition)
        local e=j:Get(id,expedition);if e or expedition then return e end
        if type(id)=="string" and id:sub(1,#E.PREFIX)==E.PREFIX then
            local entry=j.entrances:Get(id:sub(#E.PREFIX+1));return entry and E.Project(entry)
        end
    end
    function view:List(query,mapID,all,expedition)
        local rows=j:List(query,mapID,all,expedition);if expedition then return rows end
        query=(query or ""):lower()
        for id in pairs(j.entrances.records) do
            local raw=j.entrances:Get(id)
            if raw then
                local e=E.Project(raw)
                if (all or e.mapID==mapID) and (e.name.." "..e.zone.." "..e.subzone.." "..e.notes.." "..
                    e.access.." "..e.interior.." "..E.Category(e.category).label):lower():find(query,1,true) then rows[#rows+1]=e end
            end
        end
        table.sort(rows,function(a,b) if a.name:lower()==b.name:lower() then return a.id<b.id end;return a.name:lower()<b.name:lower() end)
        return rows
    end
    function view:Save(d,id,expedition)
        local e=self:Get(id,expedition)
        if e and e.entrance then
            local saved,err=j.entrances:Edit(e.entrance,d);return saved and E.PREFIX..saved or nil,err
        end
        return j:Save(d,id,expedition)
    end
    function view:Delete(id,expedition)
        local e=self:Get(id,expedition)
        if e and e.entrance then return j.entrances:Delete(e.entrance) end
        return j:Delete(id,expedition)
    end
    function view:Layer(category) return j.entrances:Layer(category) end
    function view:SetLayer(category,on) return j.entrances:SetLayer(category,on) end
    for _,method in ipairs({"WeatherText","RouteMap","InZone","ResolveStop","Associated"}) do
        local key=method;view[key]=function(_,...) return j[key](j,...) end
    end
    return view
end
function E.MergeStores(target,source,key)
    if not source.entrances or not E.SupportsStore(source) or not E.SupportsStore(target) then return end
    target.entrances=target.entrances or {schema=E.SCHEMA,records={},nextID=0}
    local records=target.entrances.records
    local serial=0
    for _,e in pairs(source.entrances.records) do
        local id
        repeat serial=serial+1;id="char"..key..":"..serial until not records[id]
        local out=A.Copy(e)
        if type(out)=="table" then out.id=id end
        records[id]=out
    end
end
