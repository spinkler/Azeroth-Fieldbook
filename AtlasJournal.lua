local _, ns = ...

-- Atlas owns its schema, identities, settings and labels.
local A={SCHEMA=1,MAX_RECORDS=5000,MAX_EXPEDITIONS=1000,MAX_STOPS=100}
A.weatherTypes={[0]="Clear",[1]="Rain",[2]="Snow",[3]="Sandstorm",[4]="Other weather"}
ns.Atlas=A
A.categories={
    {id="cave",label="Cave / Entrance",short="Caves",icon="Interface\\Icons\\Spell_Shadow_Twilight"},
    {id="ruins",label="Ruins",short="Ruins",icon="Interface\\Icons\\INV_Misc_StoneTablet_01"},
    {id="route",label="Route / Passage",short="Routes",icon="Interface\\Icons\\Ability_Tracking"},
    {id="crossing",label="Crossing",short="Crossings",icon="Interface\\Icons\\INV_Misc_Foot_Kodo"},
    {id="useful",label="Useful Place",short="Useful",icon="Interface\\Icons\\INV_Misc_Spyglass_03"},
    {id="camp",label="Camp / Settlement",short="Camps",icon="Interface\\Icons\\Spell_Fire_Fire"},
    {id="landmark",label="Landmark",short="Landmarks",icon="Interface\\Icons\\INV_Misc_Map_01"},
    {id="other",label="Other",short="Other",icon="Interface\\Icons\\INV_Misc_QuestionMark"},
}
A.category={};for _,c in ipairs(A.categories) do A.category[c.id]=c end
function A.Public(v) return not (issecretvalue and issecretvalue(v)) end
function A.Number(v,lo,hi) return A.Public(v) and type(v)=="number" and v>=lo and v<=hi end
function A.Integer(v,lo,hi) return A.Number(v,lo,hi) and v==math.floor(v) end
function A.Text(v,max,empty)
    return A.Public(v) and type(v)=="string" and #v<=max and (empty or v:find("%S")~=nil)
        and not v:find("[|%z\1-\8\11\12\14-\31\127]")
end
function A.Safe(v)
    if not A.Public(v) or type(v)~="string" then return "Unavailable" end
    -- gsub also returns a replacement count. Never forward that as an extra
    -- argument to UI methods when Safe is the final argument in a call.
    local cleaned=v:gsub("|","¦"):gsub("[%z\1-\8\11\12\14-\31\127]","")
    return cleaned
end
function A.AutomaticLabel(name,automatic)
    return A.Safe(name)..(automatic and " |cff80d0ff[A]|r" or "")
end
function A.Read(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...);if ok and A.Public(v) then return v end
end
function A.Copy(v)
    if type(v)~="table" then return v end
    local t={};for k,x in pairs(v) do t[k]=A.Copy(x) end;return t
end
function A.Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
function A.Array(t,max)
    if not A.Public(t) or type(t)~="table" or getmetatable(t) then return false end
    local n=0;for k in pairs(t) do if not A.Integer(k,1,max) then return false end;n=n+1 end
    -- Lua 5.1's length operator is undefined for lists with holes. Check every
    -- index so normalization cannot silently truncate a route or report.
    for i=1,n do if t[i]==nil then return false end end
    return true
end
function A.Now() local v=A.Read(time);return A.Integer(v,0,9999999999) and v or 0 end
function A.LegacyLoreKey(id,e)
    -- Match the old adapter's immutable creation stamp (not update time).
    local stamp=e.reference or e.created or e.firstSeen or e.firstEncounter or e.first
    if type(stamp)~="number" and type(e.reference)~="string" then
        stamp=0;local name=tostring(e.name or e.title or "")
        for i=1,#name do stamp=(stamp*31+name:byte(i))%2147483647 end
    end
    return tostring(id).."@:"..tostring(stamp)
end
function A.EnsureReferences(saved)
    if ns.InitializationBlocked or (saved.schema or 0)>A.SCHEMA then return end
    if not A.Text(saved.origin,100) then saved.origin=tostring(A.Now()).."-"..math.random(1,999999999) end
    saved.loreAliases=saved.loreAliases or {}
    for _,field in ipairs({"records","expeditions"}) do for id,e in pairs(saved[field] or {}) do
        if type(e)=="table" and not e.reference then
            local legacy=A.LegacyLoreKey(id,e)
            saved.referenceSerial=(saved.referenceSerial or 0)+1
            e.reference="atlas:"..(saved.referenceOrigin or saved.origin)..":"..saved.referenceSerial
            e.referenceLegacy=true
            if saved.loreAliases[legacy]==nil then saved.loreAliases[legacy]=e.reference
            elseif saved.loreAliases[legacy]~=e.reference then saved.loreAliases[legacy]=false end
        end
    end end
end
function A.Position(p)
    return type(p)=="table" and A.Integer(p.mapID,1,2147483647)
        and A.Integer(p.x,0,10000) and A.Integer(p.y,0,10000)
end
function A.Coordinates(x,y)
    if x=="" and y=="" then return nil,nil end
    x,y=tonumber(x),tonumber(y)
    if not A.Number(x,0,100) or not A.Number(y,0,100) then return nil,nil,"Use both coordinates from 0 to 100, or leave both blank." end
    return math.floor(x*100+0.5),math.floor(y*100+0.5)
end
function A.CurrentLocation()
    local result={zone=A.Safe(A.Read(GetRealZoneText) or ""),subzone=A.Safe(A.Read(GetSubZoneText) or "")}
    local map=ns.CreatureLocations and ns.CreatureLocations.CurrentMap()
    if map then
        result.mapID,result.zone=map.mapID,map.name
        local p=A.Read(C_Map and C_Map.GetPlayerMapPosition,map.mapID,"player")
        if type(p)=="table" and A.Number(p.x,0,1) and A.Number(p.y,0,1) and not (p.x==0 and p.y==0) then
            result.x,result.y=math.floor(p.x*10000+0.5),math.floor(p.y*10000+0.5)
        end
    end
    return result
end
local function refs(values)
    if not A.Array(values,100) then return end
    local out,seen={},{}
    for _,r in ipairs(values) do
        if type(r)~="table" or not A.Text(r.section,40) or not A.Text(r.key,160) or not A.Text(r.name,160) then return end
        local id=r.section..":"..r.key
        if not seen[id] then out[#out+1]={section=r.section,key=r.key,name=r.name};seen[id]=true end
    end
    return out
end
local function ids(values)
    if not A.Array(values,100) then return end
    local out,seen={},{}
    for _,id in ipairs(values) do
        if not A.Text(id,64) then return end
        if not seen[id] then out[#out+1]=id;seen[id]=true end
    end
    return out
end
function A.Location(value)
    if type(value)~="table" then return nil,"Invalid location." end
    local out={}
    for _,k in ipairs({"zone","subzone"}) do
        if value[k]~=nil and not A.Text(value[k],160,true) then return nil,"Invalid zone label." end
        out[k]=value[k] or ""
    end
    if value.mapID~=nil then
        if not A.Integer(value.mapID,1,2147483647) then return nil,"Invalid map ID." end
        out.mapID=value.mapID
    end
    if value.x~=nil or value.y~=nil then
        if not A.Position(value) then return nil,"Coordinates need a valid map and both values." end
        out.x,out.y=value.x,value.y
    end
    return out
end
function A.Stop(s)
    if type(s)~="table" then return nil,"Invalid route stop." end
    if s.recordID then
        if not A.Text(s.recordID,64) or not A.Text(s.name or "Missing place",160) then return nil,"Invalid place reference." end
        return {recordID=s.recordID,name=s.name or "Missing place"}
    end
    local out,err=A.Location(s);if not out then return nil,err end
    if not A.Text(s.name,160) then return nil,"Give the waypoint a name." end
    out.name=s.name;return out
end
local function normalize(value,expedition)
    if type(value)~="table" then return nil,"Invalid entry." end
    local out,err=A.Location(value);if not out then return nil,err end
    if not A.Text(value.name,160) then return nil,"A name is required (up to 160 bytes; plain text only)." end
    out.name=value.name
    for _,field in ipairs({"notes","access","interior"}) do
        if not A.Text(value[field] or "",field=="interior" and 160 or 8000,true) then return nil,"Notes must be plain text, within their length limit." end
        out[field]=value[field] or ""
    end
    out.related=ids(value.related or {});out.references=refs(value.references or {})
    if not out.related or not out.references then return nil,"Too many or invalid connections (maximum 100)." end
    if expedition then
        out.zones={}
        if not A.Array(value.zones or {},64) then return nil,"Invalid expedition zones (maximum 64)." end
        for _,zone in ipairs(value.zones or {}) do
            local z,e=A.Location(zone);if not z then return nil,e end
            out.zones[#out.zones+1]={mapID=z.mapID,zone=z.zone}
        end
    else
        if not A.category[value.category] then return nil,"Choose a category." end
        out.category=value.category;out.explored=value.explored==true
        if value.interiorMapID~=nil and not A.Integer(value.interiorMapID,1,2147483647) then return nil,"Invalid interior map ID." end
        out.interiorMapID=value.interiorMapID;out.stops={}
        if not A.Array(value.stops or {},A.MAX_STOPS) then return nil,"Routes allow up to 100 stops." end
        for _,s in ipairs(value.stops or {}) do
            local stop,e=A.Stop(s);if not stop then return nil,e end;out.stops[#out.stops+1]=stop
        end
        local p=value.provenance or {kind="recorded",source="Personal record"}
        if type(p)~="table" or (p.kind~="recorded" and p.kind~="reported") or not A.Text(p.source,160) then return nil,"Invalid knowledge source." end
        out.provenance={kind=p.kind,source=p.source}
    end
    return out
end
-- Whole-save recovery checks records without projecting away private metadata.
A.ValidateRecord=normalize
function ns.CreateAtlasJournal(saved)
    -- Additive schema-0 -> 1 migration. Preserve unknown fields and unsupported
    -- future schemas; never rewrite or reset another SavedVariable.
    local writable=not ns.InitializationBlocked and (saved.schema==nil or saved.schema==0 or saved.schema==A.SCHEMA)
    if writable then
        saved.records=type(saved.records)=="table" and saved.records or {}
        saved.expeditions=type(saved.expeditions)=="table" and saved.expeditions or {}
        saved.weather=type(saved.weather)=="table" and saved.weather or {}
        saved.settings=type(saved.settings)=="table" and saved.settings or {}
        saved.settings.layers=type(saved.settings.layers)=="table" and saved.settings.layers or {}
        saved.schema=A.SCHEMA
        A.EnsureReferences(saved)
    end
    local j={saved=saved,records=writable and saved.records or {},expeditions=writable and saved.expeditions or {},
        state=writable and saved.settings or {layers={}},readOnly=not writable,revision=0}
    function j:StorageStatus(checkpoint)
        if self.readOnly then return 'Archive: read-only','Saved data is unsupported; archive usage is unavailable. Original data is preserved.' end
        checkpoint=checkpoint or function() end
        local active={}
        local function size(value,depth)
            checkpoint()
            local kind=type(value)
            if kind=='string' then return #string.format('%q',value) end
            if kind=='number' or kind=='boolean' then return #tostring(value) end
            if kind~='table' or active[value] or depth>64 then return nil end
            active[value]=true
            local bytes=3+depth
            for key,item in pairs(value) do
                local k,v=size(key,depth+1),size(item,depth+1)
                if not k or not v then active[value]=nil;return nil end
                bytes=bytes+depth+1+1+k+4+v+2
            end
            active[value]=nil;return bytes
        end
        local bytes=size(self.saved,0)
        if not bytes then return 'Archive: usage unavailable','The Atlas store contains data that cannot be estimated. Original data is preserved.' end
        local surveys,crossings,pointBytes=0,0,0
        for _,rows in pairs(self.saved.subzones or {}) do
            if type(rows)=='table' then for key,row in pairs(rows) do
                checkpoint()
                if type(row)=='table' and type(key)=='number' then
                    if row.kind=='interior' then surveys=surveys+1 else crossings=crossings+1 end
                    -- Include each sample's array key and formatting at its saved depth.
                    pointBytes=pointBytes+(size(row,3) or 0)+(size(key,3) or 0)+10
                end
            end end
        end
        local count=surveys+crossings
        local coverageCount,coverageBytes=0,0
        local coverage=self.saved.subzoneCoverage
        if type(coverage)=='table' and coverage.version==1 and type(coverage.maps)=='table' then
            coverageBytes=size(coverage,1) or 0
            for _,map in pairs(coverage.maps) do
                checkpoint()
                if type(map)=='table' then for _,packed in pairs(map) do
                    checkpoint()
                    if type(packed)=='string' then coverageCount=coverageCount+math.floor(#packed/8) end
                end end
            end
        end
        return string.format('Archive: ~%.2f MiB',bytes/1048576),
            string.format('%d estimated saved-data bytes\n%d survey points • %d crossing points\n%d estimated point bytes • %.0f bytes per point on average\n%d compact coverage positions • %d estimated coverage bytes\nIncludes the active Atlas store: discoveries, expeditions, sub-zone samples, coverage, weather, references and settings. Excludes separate backups and inactive character stores. Estimated Lua formatting; actual SavedVariables file size and memory usage differ. Updates while this page is open.',bytes,surveys,crossings,pointBytes,count>0 and pointBytes/count or 0,coverageCount,coverageBytes)
    end
    function j:ObserveWeather()
        if self.readOnly then return end
        local mapID=A.Read(C_Map and C_Map.GetBestMapForUnit,"player")
        local info=A.Read(C_Weather and C_Weather.GetCurrentWeather)
        local kind=type(info)=="table" and A.Read(function() return info.type end)
        if not A.Integer(mapID,1,2147483647) or not A.Integer(kind,0,4) then return end
        local zone=saved.weather[mapID]
        if type(zone)~="table" then
            if A.Count(saved.weather)>=4096 then return end
            zone={};saved.weather[mapID]=zone
        end
        if not A.Integer(zone[kind],0,9999999999) then zone[kind]=A.Now() end
    end
    function j:WeatherText(mapID)
        local zone=not self.readOnly and A.Integer(mapID,1,2147483647) and saved.weather[mapID]
        local labels={}
        if type(zone)=="table" then
            for kind=0,4 do
                if A.Integer(zone[kind],0,9999999999) then labels[#labels+1]=A.weatherTypes[kind] end
            end
        end
        return #labels>0 and table.concat(labels,", ") or "No weather observed yet."
    end
    function j:Get(id,expedition)
        if not A.Text(id,64) then return end
        local v=(expedition and self.expeditions or self.records)[id]
        if type(v)~="table" then return end
        local out=normalize(v,expedition)
        if out then
            out.id=id;out.created=A.Integer(v.created,0,9999999999) and v.created or 0
            out.updated=A.Integer(v.updated,0,9999999999) and v.updated or 0
            out.reference=v.reference
        end
        return out -- Callers always receive detached data, including adapters/UI.
    end
    function j:Save(value,id,expedition)
        if self.readOnly then return nil,"This Atlas schema is newer than this addon; data was left untouched." end
        local out,err=normalize(value,expedition);if not out then return nil,err end
        local store=expedition and self.expeditions or self.records
        if id and not store[id] then return nil,"The entry no longer exists." end
        if not id then
            if A.Count(store)>=(expedition and A.MAX_EXPEDITIONS or A.MAX_RECORDS) then return nil,"Journal capacity reached." end
            repeat
                saved.nextID=(A.Integer(saved.nextID,0,999999999) and saved.nextID or 0)+1
                id=(expedition and "e" or "p")..saved.nextID
            until not self.records[id] and not self.expeditions[id]
        end
        out.id=id;out.created=store[id] and store[id].created or A.Now();out.updated=A.Now()
        out.reference=store[id] and store[id].reference
        out.referenceLegacy=store[id] and store[id].referenceLegacy
        local newlyCreated=store[id]==nil
        -- Editing a received record never silently upgrades its knowledge source.
        if store[id] and not expedition then out.provenance=A.Copy(store[id].provenance or out.provenance) end
        store[id]=out;A.EnsureReferences(saved);if newlyCreated then out.referenceLegacy=nil end
        if newlyCreated and not expedition and ns.RecordFieldbookDiscovery then ns.RecordFieldbookDiscovery("atlas",out,self) end
        self.revision=self.revision+1;return id
    end
    function j:Delete(id,expedition)
        if self.readOnly then return false end
        local store=expedition and self.expeditions or self.records
        if not store[id] then return false end
        store[id]=nil;self.revision=self.revision+1
        -- References intentionally survive as unresolved; route numbering and
        -- expedition history are not silently rewritten on deletion.
        return true
    end
    function j:Layer(category) return self.state.layers[category]~=false end
    function j:SetLayer(category,visible)
        if not self.readOnly and A.category[category] then self.state.layers[category]=visible==true end
    end
    function j:ResolveStop(stop)
        if stop.recordID then
            local entry=self:Get(stop.recordID)
            if entry then return entry end
            return {name=(stop.name or stop.recordID).." (missing)",missing=true}
        end
        return A.Copy(stop)
    end
    function j:InZone(entry,mapID)
        if entry.mapID==mapID then return true end
        if entry.category=="route" then
            for _,s in ipairs(entry.stops) do if self:ResolveStop(s).mapID==mapID then return true end end
        end
        return false
    end
    function j:List(query,mapID,all,expedition)
        query=string.lower(query or "");local rows={}
        for id in pairs(expedition and self.expeditions or self.records) do
            local e=self:Get(id,expedition)
            if e then
                local hay=e.name.." "..(A.category[e.category] and A.category[e.category].label or "Expedition").." "..e.zone.." "..e.subzone.." "..e.notes.." "..e.access.." "..e.interior
                for _,z in ipairs(e.zones or {}) do hay=hay.." "..z.zone end
                if (all or expedition or self:InZone(e,mapID)) and hay:lower():find(query,1,true) then rows[#rows+1]=e end
            end
        end
        table.sort(rows,function(a,b) if a.name:lower()==b.name:lower() then return a.id<b.id end;return a.name:lower()<b.name:lower() end)
        return rows
    end
    function j:RouteMap(entry,mapID)
        local pins,lines,previous={},{}
        for i,s in ipairs(entry.stops or {}) do
            local p=self:ResolveStop(s)
            if p.mapID==mapID and A.Position(p) and (not p.category or self:Layer(p.category)) and self:Layer("route") then
                p.number=i;p.recordID=s.recordID;p.routeID=entry.id;pins[#pins+1]=p
                if previous then lines[#lines+1]={from=previous,to=p} end
                previous=p
            else previous=nil end -- Never connect across maps, missing stops or hidden layers.
        end
        return pins,lines
    end
    function j:MoveStop(entry,from,to)
        if not A.Integer(from,1,#entry.stops) or not A.Integer(to,1,#entry.stops) then return false end
        table.insert(entry.stops,to,table.remove(entry.stops,from));return true
    end
    function j:Associated(id)
        local rows={}
        for _,e in ipairs(self:List("",nil,true,true)) do
            for _,link in ipairs(e.related) do if link==id then rows[#rows+1]=e;break end end
        end
        return rows
    end
    if ns.AtlasSubzones then ns.AtlasSubzones.Attach(j) end
    if ns.AtlasEntrances then ns.AtlasEntrances.Attach(j) end
    return j
end
