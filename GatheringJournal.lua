local _, ns = ...

-- This journal has its own per-character SavedVariable. Bestiary account scope,
-- resets, backups and sharing deliberately never own these records.
local kinds={herb={title="Herb",profession="Herbalism",icon="Interface\\Icons\\INV_Misc_Flower_02"},
    mineral={title="Mineral",profession="Mining",icon="Interface\\Icons\\INV_Ore_Copper_01"}}
ns.GatheringKinds=kinds
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v,low,high)
    return public(v) and type(v)=="number" and v>=low and v<=high and v==math.floor(v)
end
local function cleanName(v)
    if not public(v) or type(v)~="string" or #v>160 or v:find("[%c|]") then return end
    v=v:match("^%s*(.-)%s*$")
    if v~="" then return v end
end
ns.GatheringName=cleanName
local function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function identity(kind,name) return kind..":"..string.lower(name) end
local function validPoint(p)
    return type(p)=="table" and number(p.x,0,10000) and number(p.y,0,10000)
        and number(p.seenAt,0,9999999999)
end
local sortFields={name=true,kind=true,interactions=true,completed=true,firstSeen=true,lastSeen=true}

function ns.CreateGatheringJournal(saved,getBrightness)
    saved.schema=1
    saved.entries=type(saved.entries)=="table" and saved.entries or {}
    local journal={entries=saved.entries,revision=0}
    -- Validate the small, literal-only schema when loading saved data.
    for id,entry in pairs(journal.entries) do
        if type(entry)~="table" or not kinds[entry.kind] or not cleanName(entry.name)
            or id~=identity(entry.kind,cleanName(entry.name)) then
            journal.entries[id]=nil
        else
            entry.id,entry.name=id,cleanName(entry.name)
            if not ns.GatheringModelAllowed(entry.kind,entry.modelFileID) then entry.modelFileID=nil end
            for _,field in ipairs({"interactions","completed","firstSeen","lastSeen"}) do
                if not number(entry[field],0,9999999999) then entry[field]=0 end
            end
            entry.completed=math.min(entry.completed,entry.interactions)
            if type(entry.note)~="string" or #entry.note>4000 then entry.note="" end
            entry.zones=type(entry.zones)=="table" and entry.zones or {}
            for zone in pairs(entry.zones) do
                if not cleanName(zone) then entry.zones[zone]=nil else entry.zones[zone]=true end
            end
            entry.locations=type(entry.locations)=="table" and entry.locations or {}
            local maps=0
            for mapID,map in pairs(entry.locations) do
                if not number(mapID,1,2147483647) or type(map)~="table" or not cleanName(map.name) or maps>=64 then
                    entry.locations[mapID]=nil
                else
                    maps=maps+1
                    map.name=cleanName(map.name)
                    map.points=type(map.points)=="table" and map.points or {}
                    for key,p in pairs(map.points) do
                        if not validPoint(p) or key~=1+p.x*10001+p.y then map.points[key]=nil
                        else p.approximate=true end
                    end
                    ns.CreatureLocations.TrimPoints(map.points)
                end
            end
        end
    end
    function journal:Changed() self.revision=self.revision+1 end
    function journal:ShowNodesOn(map)
        return (map=="worldMap" or map=="minimap") and saved[map]==true
    end
    function journal:SetShowNodesOn(map,enabled)
        if map~="worldMap" and map~="minimap" then return end
        saved[map]=enabled==true;self:Changed()
    end
    function journal:Discover(kind,name,stamp,zone,map,modelFileID)
        name=cleanName(name)
        if not kinds[kind] or not name then return end
        stamp=number(stamp,0,9999999999) and stamp or 0
        local id=identity(kind,name)
        local entry=self.entries[id]
        if not entry then
            entry={id=id,name=name,kind=kind,interactions=0,completed=0,firstSeen=stamp,
                lastSeen=0,zones={},locations={},note=""}
            self.entries[id]=entry
            self:Changed()
        end
        -- Hover observations remember a zone/map, never a position or interaction.
        local changed=false
        modelFileID=modelFileID or ns.GatheringModel(kind,name)
        if ns.GatheringModelAllowed(kind,modelFileID) and entry.modelFileID~=modelFileID then
            entry.modelFileID=modelFileID;changed=true
        end
        zone=cleanName(zone)
        if zone and not entry.zones[zone] then entry.zones[zone]=true;changed=true end
        if type(map)=="table" and number(map.mapID,1,2147483647) and cleanName(map.name)
            and not entry.locations[map.mapID] and count(entry.locations)<64 then
            entry.locations[map.mapID]={name=cleanName(map.name),points={}};changed=true
        end
        if changed then self:Changed() end
        return id
    end
    function journal:RecordInteraction(kind,name,sample,zone,stamp,modelFileID)
        local id=self:Discover(kind,name,stamp,nil,nil,modelFileID)
        if not id then return end
        stamp=number(stamp,0,9999999999) and stamp or 0
        local entry=self.entries[id]
        entry.interactions=entry.interactions+1;entry.lastSeen=stamp
        zone=cleanName(zone)
        if zone then entry.zones[zone]=true end
        if type(sample)=="table" and number(sample.mapID,1,2147483647) and cleanName(sample.name) then
            local map=entry.locations[sample.mapID]
            if not map and count(entry.locations)<64 then
                map={name=cleanName(sample.name),points={}}
                entry.locations[sample.mapID]=map
            end
            if map and validPoint(sample.point) then
                local p=sample.point
                map.points[1+p.x*10001+p.y]={x=p.x,y=p.y,seenAt=p.seenAt,approximate=true}
                ns.CreatureLocations.TrimPoints(map.points)
            end
        end
        self:Changed()
        return id
    end
    function journal:Complete(id)
        local entry=self.entries[id]
        if not entry or entry.completed>=entry.interactions then return end
        entry.completed=entry.completed+1;self:Changed()
    end
    function journal:GetName(id) return self.entries[id] and self.entries[id].name end
    function journal:GetLocationZones(id)
        local entry=self.entries[id]
        local result,known={},{}
        for mapID,map in pairs(entry and entry.locations or {}) do
            result[#result+1]={mapID=mapID,name=map.name,data=map};known[map.name]=true
        end
        for zone in pairs(entry and entry.zones or {}) do
            if not known[zone] then result[#result+1]={name=zone} end
        end
        table.sort(result,function(a,b)
            if a.name~=b.name then return a.name<b.name end
            return (a.mapID or 0)<(b.mapID or 0)
        end)
        return result
    end
    function journal:GetListSort()
        return sortFields[saved.sortField] and saved.sortField or "name",saved.sortDescending==true
    end
    function journal:SetListSort(field,descending)
        saved.sortField=sortFields[field] and field or "name";saved.sortDescending=descending==true
        self:Changed()
    end
    function journal:List(kind,query,initial,zoneFilters)
        query=string.lower(query or "")
        local result={}
        for _,entry in pairs(self.entries) do
            local locationMatch=not zoneFilters or not next(zoneFilters)
            local search=string.lower(entry.name.." "..kinds[entry.kind].title.." "..kinds[entry.kind].profession)
            for _,zone in ipairs(self:GetLocationZones(entry.id)) do
                search=search.." "..string.lower(zone.name)
                if zoneFilters and zoneFilters[zone.name] then locationMatch=true end
            end
            if (not kind or entry.kind==kind) and locationMatch and search:find(query,1,true)
                and (not initial or string.upper(entry.name:sub(1,1))==initial) then result[#result+1]=entry end
        end
        local field,descending=self:GetListSort()
        table.sort(result,function(a,b)
            local left,right=a[field],b[field]
            if type(left)=="string" then left=string.lower(left);right=string.lower(right) end
            if left~=right then
                if descending then return left>right else return left<right end
            end
            local an,bn=string.lower(a.name),string.lower(b.name)
            if an~=bn then return an<bn end
            return a.id<b.id
        end)
        return result
    end
    function journal:SetNote(id,text)
        local entry=self.entries[id]
        if not entry or not public(text) or type(text)~="string" or #text>4000 then return false end
        entry.note=text;self:Changed();return true
    end
    function journal:GetBackgroundBrightness() return getBrightness and getBrightness() or 1 end
    function journal:GetLocationMapBrightness()
        local v=saved.mapBrightness
        return type(v)=="number" and v>=0.2 and v<=1 and v or 0.65
    end
    function journal:SetLocationMapBrightness(value)
        if public(value) and type(value)=="number" and value>=0.2 and value<=1 then saved.mapBrightness=value end
    end
    return journal
end
