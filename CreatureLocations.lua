local _, ns = ...

-- Personal, bounded kill samples. Coordinates are integers so the literal
-- backup format preserves them exactly. No opaque values enter saved data.
local locations = { SCALE=10000, MAX_MAPS=64, MAX_POINTS=256, EDGE_YARDS=180 }
ns.CreatureLocations = locations
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function finite(value, low, high)
    return public(value) and type(value)=="number" and value>=low and value<=high
end
local function positive(value) return finite(value,1,2147483647) and value==math.floor(value) end
local function name(value)
    return public(value) and type(value)=="string" and #value>0 and #value<=256 and not value:find("[%c|]")
end
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok and public(value) then return value end
end
local function coordinates(position)
    if not public(position) or type(position)~="table" then return end
    local x,y=position.x,position.y
    if finite(x,0,1) and finite(y,0,1) then
        return math.floor(x*locations.SCALE+0.5),math.floor(y*locations.SCALE+0.5)
    end
end
function locations.CurrentMap()
    if not C_Map then return end
    local id=read(C_Map.GetBestMapForUnit,"player")
    if not positive(id) then return end
    local info=read(C_Map.GetMapInfo,id)
    if type(info)~="table" or not name(info.name) then return end
    local result={mapID=id,name=info.name}
    if type(C_Map.GetMapWorldSize)=="function" then
        local ok,w,h=pcall(C_Map.GetMapWorldSize,id)
        if ok and finite(w,1,100000) and finite(h,1,100000) then
            result.width,result.height=math.floor(w+0.5),math.floor(h+0.5)
        end
    end
    return result
end
function locations.Sample(unit,guid,expectedMapID)
    local map=locations.CurrentMap()
    if not map or (expectedMapID and map.mapID~=expectedMapID) then return end
    local x,y
    if unit and read(UnitGUID,unit)==guid and type(UnitPosition)=="function"
        and type(CreateVector2D)=="function" and type(C_Map.GetMapPosFromWorldPos)=="function" then
        local ok,wx,wy,_,world=pcall(UnitPosition,unit)
        if ok and finite(wx,-1000000,1000000) and finite(wy,-1000000,1000000)
            and finite(world,0,2147483647) then
            local converted,mapID,position=pcall(function()
                return C_Map.GetMapPosFromWorldPos(world,CreateVector2D(wx,wy),map.mapID)
            end)
            if converted and public(mapID) and mapID==map.mapID then x,y=coordinates(position) end
        end
    end
    local approximate=x==nil
    if approximate then x,y=coordinates(read(C_Map.GetPlayerMapPosition,map.mapID,"player")) end
    if not x or (unit and read(UnitGUID,unit)~=guid) then return end
    local stamp=read(time)
    map.point={x=x,y=y,approximate=approximate,seenAt=finite(stamp,0,9999999999) and math.floor(stamp) or 0}
    return map
end
local function count(values) local n=0;for _ in pairs(values) do n=n+1 end;return n end
function locations.RememberMap(entry,map)
    if not entry or not map then return end
    entry.killLocations=entry.killLocations or {}
    local saved=entry.killLocations[map.mapID]
    local changed=false
    if not saved then
        if count(entry.killLocations)>=locations.MAX_MAPS then return end
        saved={name=map.name,points={}}
        entry.killLocations[map.mapID]=saved;changed=true
    end
    for _,key in ipairs({"name","width","height"}) do
        if map[key] and saved[key]~=map[key] then saved[key]=map[key];changed=true end
    end
    return saved,changed
end
function locations.TrimPoints(points)
    local keys={}
    for key in pairs(points) do keys[#keys+1]=key end
    table.sort(keys,function(a,b)
        if points[a].seenAt~=points[b].seenAt then return points[a].seenAt>points[b].seenAt end
        return a<b
    end)
    for i=locations.MAX_POINTS+1,#keys do points[keys[i]]=nil end
end
function locations.Record(entry,sample)
    local saved=locations.RememberMap(entry,sample)
    if not saved or not sample.point then return end
    local p=sample.point
    local key=1+p.x*10001+p.y
    local previous=saved.points[key]
    -- Repeated kills at the same coordinate occupy one marker. A precise sample
    -- upgrades an approximation; a later approximation never downgrades it.
    saved.points[key]={x=p.x,y=p.y,seenAt=p.seenAt,
        approximate=p.approximate and (not previous or previous.approximate) or false}
    locations.TrimPoints(saved.points)
end
function locations.Merge(target,source)
    for id,map in pairs(source or {}) do
        local saved=locations.RememberMap(target,{mapID=id,name=map.name,width=map.width,height=map.height})
        if saved then
            for key,p in pairs(map.points or {}) do
                local old=saved.points[key]
                saved.points[key]={x=p.x,y=p.y,seenAt=math.max(p.seenAt,old and old.seenAt or 0),
                    approximate=p.approximate and (not old or old.approximate) or false}
            end
            locations.TrimPoints(saved.points)
        end
    end
end
local mapNames, mapRoot
local function mapForName(zone,current)
    if not current then return end
    if current.name==zone then return current.mapID end
    if not C_Map or type(C_Map.GetMapChildrenInfo)~="function" then return end
    local root=current.mapID
    for _=1,12 do
        local info=read(C_Map.GetMapInfo,root)
        local parent=type(info)=="table" and info.parentMapID
        if not positive(parent) or parent==root then break end
        root=parent
    end
    if mapRoot~=root then
        local children=read(C_Map.GetMapChildrenInfo,root,nil,true)
        if type(children)~="table" then return end
        mapNames,mapRoot={},root
        for i,info in ipairs(children) do
            if i>4096 then break end
            if public(info) and type(info)=="table" and name(info.name) and positive(info.mapID) then
                local old=mapNames[info.name]
                if old==nil then mapNames[info.name]=info.mapID
                elseif old~=info.mapID then mapNames[info.name]=false end
            end
        end
    end
    -- Duplicate names/floors are ambiguous. Wait for a direct observation.
    return mapNames[zone] or nil
end
function locations.Zones(entry)
    local result,known={},{}
    for id,map in pairs(entry and entry.killLocations or {}) do
        result[#result+1]={mapID=id,name=map.name,data=map};known[map.name]=true
    end
    -- Old entries retain their zone names but contain no historical coordinates.
    local current=locations.CurrentMap()
    for zone in pairs(entry and entry.locations or {}) do
        if not known[zone] then
            result[#result+1]={name=zone,mapID=mapForName(zone,current)}
        end
    end
    table.sort(result,function(a,b)
        if a.name~=b.name then return a.name<b.name end
        return (a.mapID or 0)<(b.mapID or 0)
    end)
    return result
end
