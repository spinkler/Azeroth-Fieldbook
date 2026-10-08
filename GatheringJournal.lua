local _, ns = ...

-- AccountSections selects the account or character store. Bestiary resets,
-- backups and sharing deliberately never own these records.
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

-- Identity is independent of the earliest observation, which account imports can lower.
function ns.GatheringEnsureReferences(saved)
    if (saved.schema or 0)>1 then return end
    saved.referenceOrigin=saved.referenceOrigin or tostring(time and time() or 0)..'-'..math.random(1,999999999)
    saved.referenceSerial=saved.referenceSerial or 0
    for id,e in pairs(saved.entries or {}) do if type(e)=='table' and not e.reference then
        saved.referenceSerial=saved.referenceSerial+1
        e.reference='gathering:'..saved.referenceOrigin..':'..saved.referenceSerial
        -- Only records already present at migration can own timestamp-era links.
        e.legacyReferences=e.legacyReferences or {}
        if type(e.firstSeen)=='number' then e.legacyReferences[tostring(id)..'@:'..e.firstSeen]=true end
    end end
end
local function gatheringReference(e,key)
    return e.reference==key or (e.referenceAliases or {})[key] or (e.legacyReferences or {})[key]
end
function ns.CreateGatheringJournal(saved,getBrightness)
    local readOnly=type(saved.schema)=="number" and saved.schema>1
    -- Never normalize a schema this version cannot interpret. The empty view
    -- is detached, and both editing and background capture remain disabled.
    if readOnly then saved={} end
    saved.schema=1
    saved.entries=type(saved.entries)=="table" and saved.entries or {}
    ns.GatheringEnsureReferences(saved)
    local journal={entries=saved.entries,saved=saved,revision=0,readOnly=readOnly}
    function journal:Reference(key)
        local found
        for _,e in pairs(self.entries) do if gatheringReference(e,key) then
            if found then return end;found=e
        end end
        if found then return found end
        -- Account-created links may return to a retained contributing personal record.
        local account=AzerothFieldbookAccountDB
        local shared=account and account.sections and account.sections.gathering
        if not shared or shared==saved then return end
        local target
        for _,e in pairs(shared.entries or {}) do if gatheringReference(e,key) then
            if target then return end;target=e
        end end
        if target then for _,e in pairs(self.entries) do if gatheringReference(target,e.reference) then
            if found then return end;found=e
        end end end
        return found
    end
    local dimensions={}
    local function mapSize(id)
        if dimensions[id] then return dimensions[id][1],dimensions[id][2] end
        if not C_Map or type(C_Map.GetMapWorldSize)~="function" then return end
        local ok,w,h=pcall(C_Map.GetMapWorldSize,id)
        if ok and public(w) and public(h) and type(w)=="number" and type(h)=="number"
            and w>0 and h>0 and w<=100000 and h<=100000 then
            dimensions[id]={w,h};return w,h
        end
    end
    local function nearby(points,p,w,h)
        local best,bestDistance,bestKey
        for key,q in pairs(points) do
            local dx,dy=(p.x-q.x)*w/10000,(p.y-q.y)*h/10000
            local distance=dx*dx+dy*dy
            if distance<=100 and (not bestDistance or distance<bestDistance or
                (distance==bestDistance and key<bestKey)) then
                best,bestDistance,bestKey=q,distance,key
            end
        end
        return best
    end
    local cleaned=setmetatable({},{__mode="k"})
    local function cleanMap(map,id)
        if cleaned[map] then return end
        local w,h=mapSize(id);if not w then return end
        local keys={};for key in pairs(map.points) do keys[#keys+1]=key end
        -- Stable positions prevent clusters drifting as repeated interactions arrive.
        table.sort(keys)
        local retained={}
        for _,key in ipairs(keys) do
            local p=map.points[key];local existing=nearby(retained,p,w,h)
            if existing then existing.seenAt=math.max(existing.seenAt,p.seenAt)
            else retained[key]=p end
        end
        map.points=retained;cleaned[map]=true
    end
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
            entry.loot=type(entry.loot)=="table" and entry.loot or {}
            local lootCount=0
            for itemID,item in pairs(entry.loot) do
                if not number(itemID,1,2147483647) or type(item)~="table" or lootCount>=128
                    or not number(item.minQuantity,1,1000000) or not number(item.maxQuantity,item.minQuantity,1000000)
                    or not number(item.firstSeen,0,9999999999) or not number(item.lastSeen,item.firstSeen,9999999999) then
                    entry.loot[itemID]=nil
                else item.name=cleanName(item.name);lootCount=lootCount+1 end
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
                    cleanMap(map,mapID)
                end
            end
        end
    end
    function journal:Changed() self.revision=self.revision+1 end
    function journal:ShowNodesOn(map)
        return (map=="worldMap" or map=="minimap") and saved[map]==true
    end
    function journal:SetShowNodesOn(map,enabled)
        if self.readOnly then return end
        if map~="worldMap" and map~="minimap" then return end
        saved[map]=enabled==true;self:Changed()
    end
    function journal:Discover(kind,name,stamp,zone,map,modelFileID)
        if self.readOnly then return end
        name=cleanName(name)
        if not kinds[kind] or not name then return end
        stamp=number(stamp,0,9999999999) and stamp or 0
        local id=identity(kind,name)
        local entry=self.entries[id]
        local isNew=not entry
        if not entry then
            entry={id=id,name=name,kind=kind,interactions=0,completed=0,firstSeen=stamp,
                lastSeen=0,zones={},locations={},note=""}
            saved.referenceSerial=saved.referenceSerial+1
            entry.reference='gathering:'..saved.referenceOrigin..':'..saved.referenceSerial
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
        local newLocation
        if zone and not entry.zones[zone] then entry.zones[zone]=true;changed=true;newLocation=zone end
        if type(map)=="table" and number(map.mapID,1,2147483647) and cleanName(map.name)
            and not entry.locations[map.mapID] and count(entry.locations)<64 then
            entry.locations[map.mapID]={name=cleanName(map.name),points={}};changed=true
            newLocation=newLocation or cleanName(map.name)
        end
        if changed then self:Changed() end
        if isNew and ns.RecordFieldbookDiscovery then ns.RecordFieldbookDiscovery("gathering",entry,self) end
        if self.onDiscovery and (isNew or newLocation) then
            self.onDiscovery(entry,isNew and "New node type" or "New observed location",newLocation)
        end
        return id
    end
    function journal:RecordInteraction(kind,name,sample,zone,stamp,modelFileID)
        local id=self:Discover(kind,name,stamp,zone,sample,modelFileID)
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
                cleanMap(map,sample.mapID)
                local w,h=mapSize(sample.mapID)
                local existing=w and nearby(map.points,p,w,h) or map.points[1+p.x*10001+p.y]
                if existing then existing.seenAt=math.max(existing.seenAt,p.seenAt)
                else
                    map.points[1+p.x*10001+p.y]={x=p.x,y=p.y,seenAt=p.seenAt,approximate=true}
                    if self.onDiscovery then
                        self.onDiscovery(entry,"New node location",string.format("%s — %.1f, %.1f",map.name,p.x/100,p.y/100))
                    end
                end
                ns.CreatureLocations.TrimPoints(map.points)
            end
        end
        self:Changed()
        return id
    end
    function journal:Complete(id)
        if self.readOnly then return end
        local entry=self.entries[id]
        if not entry or entry.completed>=entry.interactions then return end
        entry.completed=entry.completed+1;self:Changed()
    end
    function journal:ObserveLoot(id,items,stamp)
        if self.readOnly then return end
        local entry=self.entries[id]
        if not entry or not number(stamp,0,9999999999) then return end
        entry.loot=type(entry.loot)=="table" and entry.loot or {}
        local changed=false
        for itemID,item in pairs(items) do
            if number(itemID,1,2147483647) and type(item)=="table" and number(item.quantity,1,1000000) then
                local old=entry.loot[itemID]
                if old or count(entry.loot)<128 then
                    old=old or {firstSeen=stamp,minQuantity=item.quantity,maxQuantity=item.quantity}
                    old.name=cleanName(item.name) or old.name
                    old.minQuantity=math.min(old.minQuantity,item.quantity)
                    old.maxQuantity=math.max(old.maxQuantity,item.quantity)
                    old.lastSeen=stamp;entry.loot[itemID]=old;changed=true
                end
            end
        end
        if changed then self:Changed() end
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
        if self.readOnly then return end
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
        if self.readOnly then return false end
        local entry=self.entries[id]
        if not entry or not public(text) or type(text)~="string" or #text>4000 then return false end
        entry.note=text;self:Changed();return true
    end
    function journal:DeleteEntry(id)
        if self.readOnly or not self.entries[id] then return false end
        self.entries[id]=nil;self:Changed();return true
    end
    function journal:GetBackgroundBrightness() return getBrightness and getBrightness() or 1 end
    function journal:GetLocationMapBrightness()
        if ns.MapBrightness and ns.MapBrightness.saved then return ns.MapBrightness:Get() end
        local v=saved.mapBrightness
        return type(v)=="number" and v>=0.2 and v<=1 and v or 0.65
    end
    function journal:SetLocationMapBrightness(value)
        if ns.MapBrightness and ns.MapBrightness.saved then ns.MapBrightness:Set(value);return end
        if self.readOnly then return end
        if public(value) and type(value)=="number" and value>=0.2 and value<=1 then saved.mapBrightness=value end
    end
    return journal
end
