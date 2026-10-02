local _, ns = ...

-- Personal, bounded location samples. Coordinates are integers so the literal
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
function locations.Observation()
    -- Target-selection observations describe the observer, never the creature's position.
    local map=locations.CurrentMap()
    if not map then return end
    local x,y=coordinates(read(C_Map.GetPlayerMapPosition,map.mapID,"player"))
    if not x then return end
    local stamp=read(time)
    map.point={x=x,y=y,approximate=false,seenAt=finite(stamp,0,9999999999) and math.floor(stamp) or 0}
    return map
end
local function count(values) local n=0;for _ in pairs(values) do n=n+1 end;return n end
local function field(mode) return mode=="observations" and "observationLocations" or "killLocations" end
function locations.RememberMap(entry,map,mode)
    if not entry or not map then return end
    local key=field(mode)
    entry[key]=entry[key] or {}
    local maps=entry[key]
    local saved=maps[map.mapID]
    local changed=false
    if not saved then
        if count(maps)>=locations.MAX_MAPS then return end
        saved={name=map.name,points={}}
        maps[map.mapID]=saved;changed=true
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
function locations.Record(entry,sample,mode)
    local saved=locations.RememberMap(entry,sample,mode)
    if not saved or not sample.point then return end
    local p=sample.point
    local key=1+p.x*10001+p.y
    local previous=saved.points[key]
    -- Repeated kills at the same coordinate occupy one marker. A precise sample
    -- upgrades an approximation; a later approximation never downgrades it.
    saved.points[key]={x=p.x,y=p.y,seenAt=p.seenAt,
        approximate=p.approximate and (not previous or previous.approximate) or false}
    locations.TrimPoints(saved.points)
    return true
end
function locations.Merge(target,source,mode)
    for id,map in pairs(source or {}) do
        local saved=locations.RememberMap(target,{mapID=id,name=map.name,width=map.width,height=map.height},mode)
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
function locations.Zones(entry,mode)
    local result,known,mapIDs={},{},{}
    for id,map in pairs(entry and entry[field(mode)] or {}) do
        result[#result+1]={mapID=id,name=map.name,data=map};known[map.name]=true;mapIDs[id]=true
    end
    -- Keep the zone selector stable while switching layers, including locked
    -- entries whose newly observed map is absent from their frozen basics.
    for id,map in pairs(entry and entry[field(mode=="observations" and "kills" or "observations")] or {}) do
        if not mapIDs[id] then result[#result+1]={mapID=id,name=map.name};known[map.name]=true end
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

-- Shared native region highlighting and one-level navigation for location panels.
function locations.InstallMapNavigation(map,getMapID,onNavigate)
    map:EnableMouse(true)
    local highlight=map:CreateTexture(nil,"ARTWORK",nil,1)
    highlight:SetBlendMode("ADD");highlight:Hide();map.regionHighlight=highlight
    local function enabled()
        return not ns.IsMapClickNavigationEnabled or ns.IsMapClickNavigationEnabled()
    end
    local function cursor()
        if type(GetCursorPosition)~="function" then return end
        local ok,x,y=pcall(GetCursorPosition)
        if not ok or not finite(x,-1000000,1000000) or not finite(y,-1000000,1000000) then return end
        local scale,left,top=map:GetEffectiveScale(),map:GetLeft(),map:GetTop()
        local w,h=map:GetWidth(),map:GetHeight()
        if not finite(scale,0.000001,1000) or not finite(left,-1000000,1000000)
            or not finite(top,-1000000,1000000) or not finite(w,1,100000) or not finite(h,1,100000) then return end
        x,y=(x/scale-left)/w,(top-y/scale)/h
        if finite(x,0,1) and finite(y,0,1) then return x,y end
    end
    function map:UpdateRegionHighlight()
        highlight:Hide()
        local id=getMapID()
        if not id or not enabled() or not self:IsMouseOver() or (IsControlKeyDown and IsControlKeyDown()) then return end
        local x,y=cursor();if not x then return end
        local fn=C_Map and C_Map.GetMapHighlightInfoAtPosition
        if type(fn)~="function" then return end
        local ok,file,atlas,u,v,w,h,left,top=pcall(fn,id,x,y)
        if not ok or not finite(u,0,1) or not finite(v,0,1) or not finite(w,0.000001,2)
            or not finite(h,0.000001,2) or not finite(left,-1,2) or not finite(top,-1,2) then return end
        if name(atlas) then highlight:SetAtlas(atlas)
        elseif positive(file) then highlight:SetTexture(file,nil,nil,"TRILINEAR") else return end
        highlight:SetTexCoord(0,u,0,v);highlight:ClearAllPoints()
        highlight:SetPoint("TOPLEFT",self,"TOPLEFT",left*self:GetWidth(),-top*self:GetHeight())
        highlight:SetSize(w*self:GetWidth(),h*self:GetHeight());highlight:Show()
    end
    function map:Navigate(button)
        local id=getMapID()
        if not id or not enabled() or (IsControlKeyDown and IsControlKeyDown()) then return end
        local target
        if button=="RightButton" then
            local info=read(C_Map and C_Map.GetMapInfo,id)
            if type(info)=="table" and positive(info.parentMapID) then target=read(C_Map.GetMapInfo,info.parentMapID) end
        elseif button=="LeftButton" then
            local x,y=cursor();if not x then return end
            target=read(C_Map and C_Map.GetMapInfoAtPosition,id,x,y)
            -- Position lookup can return a deeper descendant; stop at the next level.
            local seen={}
            for _=1,32 do
                if type(target)~="table" or not positive(target.mapID) or seen[target.mapID] then target=nil;break end
                seen[target.mapID]=true
                if target.parentMapID==id then break end
                if not positive(target.parentMapID) then target=nil;break end
                target=read(C_Map and C_Map.GetMapInfo,target.parentMapID)
            end
            if type(target)~="table" or target.parentMapID~=id then return end
        end
        if type(target)=="table" and positive(target.mapID) and target.mapID~=id and name(target.name) then
            highlight:Hide();if GameTooltip then GameTooltip:Hide() end
            onNavigate(target.mapID,target.name)
        end
    end
    map:SetScript("OnMouseUp",function(self,button) self:Navigate(button) end)
    map:HookScript("OnEnter",function(self) self:UpdateRegionHighlight() end)
    map:HookScript("OnLeave",function() highlight:Hide() end)
    map:HookScript("OnHide",function() highlight:Hide() end)
    local elapsed=0
    map:HookScript("OnUpdate",function(self,dt)
        elapsed=elapsed+dt;if elapsed>=0.05 then elapsed=0;self:UpdateRegionHighlight() end
    end)
end
