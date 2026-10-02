local _,ns=...
local A=ns.Atlas
local E={MAX_ANCESTRY=16};ns.AtlasEnvironment=E
local function id(v) return A.Integer(v,1,2147483647) end
local function label(v) return A.Text(v,160,true) and v or "" end
function E.MapType(name,fallback)
    local value=Enum and Enum.UIMapType and Enum.UIMapType[name]
    return A.Integer(value,0,20) and value or fallback
end
function E.Info(mapID)
    if not id(mapID) then return end
    local info=A.Read(C_Map and C_Map.GetMapInfo,mapID)
    if type(info)~="table" then return end
    local reported=A.Read(function() return info.mapID end)
    if reported~=nil and (not id(reported) or reported~=mapID) then return end
    local kind=A.Read(function() return info.mapType end)
    local parent=A.Read(function() return info.parentMapID end)
    if not A.Integer(kind,0,20) then return end
    return {mapID=mapID,mapType=kind,parentMapID=id(parent) and parent or nil,
        name=label(A.Read(function() return info.name end))}
end
function E.Context()
    local best=A.Read(C_Map and C_Map.GetBestMapForUnit,"player")
    local info=E.Info(best);if not info then return end
    local result={bestMapID=best,mapName=info.name,parentMapID=info.parentMapID,
        subzone=label(A.Read(GetSubZoneText)),minimap=label(A.Read(GetMinimapZoneText))}
    local seen={}
    for _=1,E.MAX_ANCESTRY do
        if not info or seen[info.mapID] then break end
        seen[info.mapID]=true
        if info.mapType==E.MapType("Micro",5) and not result.microMapID then
            result.microMapID,result.microName=info.mapID,info.name
        end
        if info.mapType==E.MapType("Zone",3) then
            result.zoneMapID,result.zone=info.mapID,info.name;break
        end
        info=E.Info(info.parentMapID)
    end
    return result
end
function E.Position(mapID)
    if not id(mapID) then return end
    local p=A.Read(C_Map and C_Map.GetPlayerMapPosition,mapID,"player")
    if type(p)~="table" and type(p)~="userdata" then return end
    local x=A.Read(function() return p.x end)
    local y=A.Read(function() return p.y end)
    if not A.Number(x,0,1) or not A.Number(y,0,1) or (x==0 and y==0) then return end
    return {mapID=mapID,x=math.floor(x*10000+0.5),y=math.floor(y*10000+0.5)}
end
function E.Size(mapID)
    local fn=C_Map and C_Map.GetMapWorldSize
    if not id(mapID) or type(fn)~="function" then return end
    local ok,w,h=pcall(fn,mapID)
    if ok and A.Number(w,1,100000) and A.Number(h,1,100000) then return {width=w,height=h} end
end
local function vector(p)
    if not A.Public(p) or (type(p)~="table" and type(p)~="userdata") then return end
    local x=A.Read(function() return p.x end);local y=A.Read(function() return p.y end)
    if A.Number(x,-1000000,1000000) and A.Number(y,-1000000,1000000) then return x,y end
end
function E.World(position)
    if not A.Position(position) or not C_Map or type(CreateVector2D)~="function"
        or type(C_Map.GetWorldPosFromMapPos)~="function" or type(C_Map.GetMapPosFromWorldPos)~="function" then return end
    local ok,continent,p=pcall(function()
        return C_Map.GetWorldPosFromMapPos(position.mapID,CreateVector2D(position.x/10000,position.y/10000))
    end)
    if not ok or not A.Integer(continent,0,2147483647) then return end
    local x,y=vector(p);if not x then return end
    local back,mapID,localP=pcall(C_Map.GetMapPosFromWorldPos,continent,p,position.mapID)
    local bx,by=vector(localP)
    if not back or not id(mapID) or mapID~=position.mapID or not bx or
        math.abs(bx-position.x/10000)>0.0002 or math.abs(by-position.y/10000)>0.0002 then return end
    return {continentID=continent,x=x,y=y,source="map-roundtrip"}
end
function E.ValidWorld(p)
    return type(p)=="table" and A.Integer(p.continentID,0,2147483647)
        and A.Number(p.x,-1000000,1000000) and A.Number(p.y,-1000000,1000000) and p.source=="map-roundtrip"
end
function E.Distance(a,b,wa,wb,size)
    if not A.Position(a) or not A.Position(b) or a.mapID~=b.mapID then return end
    local mapped
    if type(size)=="table" and A.Number(size.width,1,100000) and A.Number(size.height,1,100000) then
        mapped=math.sqrt(((a.x-b.x)*size.width/10000)^2+((a.y-b.y)*size.height/10000)^2)
    end
    if E.ValidWorld(wa) and E.ValidWorld(wb) and wa.continentID==wb.continentID then
        local world=math.sqrt((wa.x-wb.x)^2+(wa.y-wb.y)^2)
        -- Round-trip plus agreement with map dimensions catches bogus scale or
        -- stale conversion results where both APIs otherwise look plausible.
        if not mapped or math.abs(world-mapped)<=math.max(1,mapped*0.05) then return world,"world" end
    end
    return mapped,mapped and "map-size" or nil
end
local function boolean(fn,...)
    local value=A.Read(fn,...)
    if value==true or value==1 then return true end
    if value==false or value==0 then return false end
end
function E.Indoors()
    local inside,outside=boolean(IsIndoors),boolean(IsOutdoors)
    if inside~=nil and outside~=nil then if inside~=outside then return inside end;return end
    if inside~=nil then return inside end
    if outside~=nil then return not outside end
end
function E.DeadOrGhost()
    local combined=type(UnitIsDeadOrGhost)=="function"
    local separate=type(UnitIsDead)=="function" and type(UnitIsGhost)=="function"
    for _,spec in ipairs({{UnitIsDeadOrGhost},{UnitIsDead},{UnitIsGhost}}) do
        if type(spec[1])=="function" then
            if boolean(spec[1],"player")~=false then return true end
        end
    end
    if combined or separate then return false end
end
function E.SummonPending()
    local known=false
    local fn=C_IncomingSummon and C_IncomingSummon.IncomingSummonStatus
    if type(fn)=="function" then
        known=true;local status=A.Read(fn,"player")
        if not A.Integer(status,0,3) or status==1 or status==2 then return true end
    end
    fn=C_IncomingSummon and C_IncomingSummon.HasIncomingSummon
    if type(fn)=="function" then
        known=true;if boolean(fn,"player")~=false then return true end
    end
    fn=(C_SummonInfo and C_SummonInfo.GetSummonConfirmTimeLeft) or GetSummonConfirmTimeLeft
    if type(fn)=="function" then
        known=true;local remaining=A.Read(fn)
        if not A.Number(remaining,0,1e9) or remaining>0 then return true end
    end
    if known then return false end
end
function E.Blocked()
    if E.DeadOrGhost()==true or E.SummonPending()==true then return true end
    for _,spec in ipairs({{UnitOnTaxi,"player"},{IsFlying},{IsInInstance}}) do
        if type(spec[1])=="function" and boolean(spec[1],spec[2])~=false then return true end
    end
    return false
end
function E.Capture()
    local clock=A.Read(GetTime) or A.Now()
    local context=E.Context();local inside=E.Indoors()
    if not context or not context.zoneMapID or inside==nil or E.Blocked() or not A.Number(clock,0,1e12) then return end
    local exterior=E.Position(context.zoneMapID)
    if not exterior then return end -- Never substitute best-map / Micro coordinates.
    return {clock=clock,at=A.Now(),inside=inside,context=context,position=exterior,
        world=E.World(exterior),size=E.Size(exterior.mapID),
        interiorPosition=inside and context.microMapID and E.Position(context.microMapID) or nil}
end
