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

-- Automatic live-test observations: positive range <=40 yards and a fixed
-- 42-yard map guard. Unknown samples reject; no gap inference or surveying.
locations.prototypeEnabled=true
locations.prototypeLookup="zone"
locations.BORDER_YARDS=42
locations.RANGE_ITEM_ID=4945 -- Faintly Glowing Skull, 40 yards (LibRangeCheck Era/Forever).
locations.SHORT_RANGE_ITEM_ID=18904 -- Zorbin's Ultra-Shrinker, 35-yard fallback.
local borderCache,requestedRangeItems
local function mapDetails(id)
    local info=read(C_Map and C_Map.GetMapInfo,id)
    if type(info)~="table" then return end
    local kind,parent,label=read(function() return info.mapType end),
        read(function() return info.parentMapID end),read(function() return info.name end)
    if not finite(kind,0,6) or not name(label) then return end
    return {mapID=id,mapType=kind,parentMapID=positive(parent) and parent or nil,name=label}
end
local function zoneDetails(id)
    local seen={}
    for _=1,16 do
        if not positive(id) or seen[id] then return end
        seen[id]=true
        local info=mapDetails(id)
        if not info or info.mapType==4 then return end -- Dungeon/floor has no outdoor proof.
        if info.mapType==3 then return info end
        id=info.parentMapID
    end
end
local function queryMap(zone,lookup)
    if lookup=="zone" then return zone end
    local id,seen=zone.parentMapID,{}
    for _=1,16 do
        if not positive(id) or seen[id] then return end
        seen[id]=true
        local info=mapDetails(id)
        if not info then return end
        if info.mapType==2 then return info end
        id=info.parentMapID
    end
end
local function rangeRead(fn,...)
    if type(fn)~="function" then return nil,"API missing" end
    local ok,value=pcall(fn,...)
    if not ok then return nil,"API error" end
    if not public(value) then return nil,"secret" end
    if value==true or value==1 then return true,"in range" end
    if value==false or value==0 then return false,"out of range" end
    return nil,"unavailable"
end
function locations.Nearby(unit)
    if not requestedRangeItems and C_Item and type(C_Item.RequestLoadItemDataByID)=="function" then
        requestedRangeItems=true
        for _,id in ipairs({locations.RANGE_ITEM_ID,locations.SHORT_RANGE_ITEM_ID}) do
            pcall(C_Item.RequestLoadItemDataByID,id)
        end
    end
    local item40,state40=rangeRead(C_Item and C_Item.IsItemInRange,locations.RANGE_ITEM_ID,unit)
    local item35,state35=rangeRead(C_Item and C_Item.IsItemInRange,locations.SHORT_RANGE_ITEM_ID,unit)
    local interact,interactState=rangeRead(CheckInteractDistance,unit,4)
    -- Shorter positive checks also prove <=40 yards. Errors, secrets and nil
    -- never establish proximity. No unreliable 0-0 spell range checks are used.
    local yards=item40==true and 40 or (item35==true and 35 or (interact==true and 28 or nil))
    return yards~=nil,{item40=state40,item=state35,interact=interactState,yards=yards}
end
local function classifyPosition(row,id,zone)
    if not public(id) then row.detail="secret map ID";return end
    if not positive(id) then row.detail="missing or invalid map ID";return end
    local classified=zoneDetails(id)
    if classified then
        row.zoneID,row.zoneName=classified.mapID,classified.name
        row.state=classified.mapID==zone.mapID and "same zone" or "different zone"
    else
        local raw=mapDetails(id)
        row.detail="returned "..(raw and (raw.name.." ("..id..", type "..raw.mapType..")") or ("map "..id)).."; no readable zone ancestor"
    end
end
local function lookupPosition(row,query,x,y,zone)
    local fn=C_Map.GetMapInfoAtPosition
    if type(fn)~="function" then row.detail="position lookup API missing";return end
    local ok,info=pcall(fn,query.mapID,x,y)
    if not ok then row.detail="position lookup API error";return end
    if not public(info) then row.detail="secret lookup result";return end
    if info==nil then row.detail="position lookup returned nil";return end
    if type(info)~="table" then row.detail="invalid lookup result";return end
    classifyPosition(row,read(function() return info.mapID end),zone)
end
-- Centre plus eight directions at three radii: all 25 probes lie within
-- 42 yards, including diagonals (unlike a +/-42-yard square).
local probeOffsets={{0,0}}
local diagonal=math.sqrt(0.5)
for _,radius in ipairs({14,28,locations.BORDER_YARDS}) do
    for _,direction in ipairs({{-1,0},{1,0},{0,-1},{0,1},
        {-diagonal,-diagonal},{diagonal,-diagonal},{-diagonal,diagonal},{diagonal,diagonal}}) do
        probeOffsets[#probeOffsets+1]={direction[1]*radius,direction[2]*radius}
    end
end
function locations.BorderCheck(force,lookup)
    local result={allowed=false,reason="map unavailable",rows={},lookup=lookup or locations.prototypeLookup,
        guardYards=locations.BORDER_YARDS,counts={same=0,different=0,unknown=0}}
    local map=locations.CurrentMap()
    if not map then return result end
    result.map=map
    local inside=read(IsInInstance)
    if inside==true then result.reason="outdoor prototype only";return result end
    local zone=zoneDetails(map.mapID)
    if not zone then result.reason="outdoor zone unavailable";return result end
    result.zone=zone
    local query=queryMap(zone,result.lookup)
    if not query then result.reason="query map unavailable";return result end
    result.query=query
    local p=read(C_Map.GetPlayerMapPosition,query.mapID,"player")
    if type(p)~="table" then result.reason="player position unavailable";return result end
    local x,y=read(function() return p.x end),read(function() return p.y end)
    if not finite(x,0,1) or not finite(y,0,1) or (x==0 and y==0) then
        result.reason="player position unavailable";return result
    end
    result.x,result.y=x,y
    local at=read(GetTime)
    -- Reuse only while stationary; movement always rechecks the full guard.
    if not force and borderCache and finite(at,0,1e12) and at>=borderCache.at and at-borderCache.at<0.5
        and borderCache.result.map.mapID==map.mapID and borderCache.result.query.mapID==query.mapID
        and borderCache.result.lookup==result.lookup and borderCache.result.x==x and borderCache.result.y==y then
        return borderCache.result
    end
    local ok,w,h=pcall(function() return C_Map.GetMapWorldSize(query.mapID) end)
    if not ok or not finite(w,1,100000) or not finite(h,1,100000) then
        result.reason="yard scale unavailable";return result
    end
    result.width,result.height=w,h
    result.allowed=true;result.reason="all 42-yard samples agree"
    for _,offset in ipairs(probeOffsets) do
        local dx,dy=offset[1],offset[2]
        local qx,qy=x+dx/w,y+dy/h
        local row={dx=dx,dy=dy,x=qx,y=qy,state="unavailable"}
        if finite(qx,0,1) and finite(qy,0,1) then lookupPosition(row,query,qx,qy,zone)
        else row.state="outside query map" end
        result.rows[#result.rows+1]=row
        local category=row.state=="same zone" and "same" or (row.state=="different zone" and "different" or "unknown")
        result.counts[category]=result.counts[category]+1
        if row.state~="same zone" then
            result.allowed=false
            if dx==0 and dy==0 then result.reason="centre does not resolve to current zone"
            elseif result.reason=="all 42-yard samples agree" then
                result.reason=row.state=="different zone" and "another zone within border guard" or "border lookup unavailable"
            end
        end
    end
    result.centre=result.rows[1]
    result.centreMismatch=result.centre.state=="different zone"
    if result.counts.same>0 and result.counts.different>0 then result.reason="another zone within border guard" end
    if finite(at,0,1e12) then borderCache={at=at,result=result} end
    return result
end
function locations.CheckObservation(unit,guid,force)
    local result={allowed=false,reason="creature unavailable"}
    if not public(unit) then return result end
    if unit~="target" and unit~="mouseover" then return result end
    if not name(guid) or read(UnitGUID,unit)~=guid then return result end
    if read(UnitIsDead,unit)~=false then result.reason="living creature required";return result end
    local nearby,range=locations.Nearby(unit)
    result.range=range
    if not nearby and not force then result.reason="no positive proximity check";return result end
    local border=locations.BorderCheck(force)
    result.border=border
    if not nearby then result.reason="no positive proximity check";return result end
    if not border.allowed then result.reason=border.reason;return result end
    local sample=locations.Observation()
    if not sample or (sample.point.x==0 and sample.point.y==0) or sample.mapID~=border.map.mapID or read(UnitGUID,unit)~=guid then
        result.reason="identity or map changed";return result
    end
    result.allowed=true;result.reason="within 40 yards and all 42-yard samples agree"
    sample.zoneID,sample.zoneName=border.zone.mapID,border.zone.name
    return result,sample
end
function locations.SetPrototypeEnabled(enabled)
    locations.prototypeEnabled=enabled==true;borderCache=nil
end
function locations.SetPrototypeLookup(mode)
    if mode~="zone" and mode~="continent" then return end
    locations.prototypeLookup=mode;borderCache=nil
end
function locations.ReportPrototype(say,journal)
    say("Creature location live test: "..(locations.prototypeEnabled and "recording on (default)" or "recording paused until /reload"))
    say("Probe revision 6: positive range <=40 yards; all 25 samples within a 42-yard radius must match the player's zone.")
    say("Automatic target/mouseover observations. No retries or surveying; kills do not record locations.")
    if journal then
        local stats=journal.prototypeLocationStats
        say("Prototype writes this session: "..(stats and stats.added or 0).." points added; "..(stats and stats.refreshed or 0).." points refreshed")
        local last=stats and stats.last
        if last then
            say(string.format("Last actual write: %s point %.2f, %.2f; creature %d; map %d; %d saved observer points on that map",
                last.action,last.x/100,last.y/100,last.creatureID,last.mapID,last.points))
        end
    end
    local reportedBorder
    local function reportBorder(b)
        say("  Border: "..b.reason.."; lookup="..b.lookup)
        if b.map then say("  Player map: "..b.map.name.." ("..b.map.mapID..")") end
        if b.query then say("  Query map: "..b.query.name.." ("..b.query.mapID..")") end
        if b.x then say(string.format("  Query position: %.4f, %.4f",b.x,b.y)) end
        if b.width then say(string.format("  Query size: %.1f x %.1f yards; negative X=west, negative Y=north",b.width,b.height)) end
        say("  Guard: 42-yard radius; centre and eight directions at 14, 28, 42 yards")
        say("  Samples: "..b.counts.same.." current zone; "..b.counts.different.." other zone; "..b.counts.unknown.." unavailable")
        for _,r in ipairs(b.rows) do
            say(string.format("  Offset %.2f, %.2f yd: %s",r.dx,r.dy,r.state)
                ..(r.zoneID and ("; "..r.zoneName.." ("..r.zoneID..")") or "")
                ..string.format("; query %.2f, %.2f",r.x*100,r.y*100)..(r.detail and ("; "..r.detail) or ""))
        end
    end
    for _,unit in ipairs({"target","mouseover"}) do
        local result=locations.CheckObservation(unit,read(UnitGUID,unit),true)
        say(unit..": "..(result.allowed and "PASS: " or "SKIP: ")..result.reason)
        if result.range then
            say("  Item 4945 (40 yd): "..result.range.item40.."; item 18904 (35 yd fallback): "..result.range.item
                .."; interaction 4 (~28 yd): "..result.range.interact)
        end
        local b=result.border
        if b then
            reportedBorder=b
            if b.map and journal and journal.ExistingUnitEntry then
                local id=journal:ExistingUnitEntry(unit)
                local entry=id and journal.entries[id]
                local saved=entry and entry.observationLocations and entry.observationLocations[b.map.mapID]
                local total=0;for _ in pairs(saved and saved.points or {}) do total=total+1 end
                say("  Saved observer points for this creature on player map: "..total)
            end
            reportBorder(b)
        end
    end
    if not reportedBorder then
        local b=locations.BorderCheck(true)
        say("Player-only border check: "..(b.allowed and "PASS: " or "SKIP: ")..b.reason)
        reportBorder(b)
    end
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
    if not previous and count(saved.points)>locations.MAX_POINTS then locations.TrimPoints(saved.points) end
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
