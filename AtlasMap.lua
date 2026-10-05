local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local A=ns.Atlas
local function categoryInfo(id)
    return A.category[id] or (ns.AtlasEntrances and ns.AtlasEntrances.Category(id))
end
function A.MapCatalog(journal)
    local maps,seen={},{}
    local function add(id,name)
        if not A.Integer(id,1,2147483647) or seen[id] then return end
        local info=A.Read(C_Map and C_Map.GetMapInfo,id)
        name=type(info)=="table" and info.name or name
        if not A.Text(name,160) then return end
        local parent=info;local continent="Recorded maps"
        for _=1,12 do
            if type(parent)~="table" then break end
            if A.Number(parent.mapType,2,2) then continent=A.Safe(parent.name);break end
            if not A.Integer(parent.parentMapID,1,2147483647) then break end
            parent=A.Read(C_Map and C_Map.GetMapInfo,parent.parentMapID)
        end
        seen[id]=true;maps[#maps+1]={mapID=id,zone=name,continent=continent}
    end
    local current=A.CurrentLocation();local root=current.mapID
    add(root,current.zone)
    for _=1,12 do
        local info=root and A.Read(C_Map and C_Map.GetMapInfo,root)
        if type(info)~="table" or not A.Integer(info.parentMapID,1,2147483647) or info.parentMapID==root then break end
        root=info.parentMapID
    end
    local children=root and A.Read(C_Map and C_Map.GetMapChildrenInfo,root,nil,true)
    if type(children)=="table" then
        for i,info in ipairs(children) do
            if i>4096 then break end
            if A.Public(info) and type(info)=="table" and (info.mapType==nil or A.Number(info.mapType,3,6)) then add(info.mapID,info.name) end
        end
    end
    for _,e in ipairs(journal:List("",nil,true)) do
        add(e.mapID,e.zone)
        for _,s in ipairs(e.stops) do local p=journal:ResolveStop(s);add(p.mapID,p.zone) end
    end
    table.sort(maps,function(a,b) if a.zone==b.zone then return a.mapID<b.mapID end;return a.zone<b.zone end)
    return maps
end
-- Menu geography is client map metadata, not seeded journal discoveries.
function A.MapMenuGroups(extraMaps)
    local maps,roots={},{}
    local battlegrounds={[1459]=true,[1460]=true,[1461]=true} -- Classic UI map IDs
    local bgNames={}
    local count=A.Read(GetNumBattlegroundTypes)
    for i=1,(A.Integer(count,0,256) and count or 128) do
        local info=A.Read(C_PvP and C_PvP.GetBattlegroundInfo,i)
        local name=type(info)=="table" and info.name or A.Read(GetBattlegroundInfo,i)
        if A.Text(name,160) then bgNames[name]=true end
    end
    local function add(id)
        if not A.Integer(id,1,2147483647) then return end
        if maps[id] then return maps[id] end
        local info=A.Read(C_Map and C_Map.GetMapInfo,id)
        if type(info)~="table" or not A.Text(info.name,160) then return end
        local row={mapID=id,zone=info.name,
            parent=A.Integer(info.parentMapID,1,2147483647) and info.parentMapID or nil,
            mapType=A.Integer(info.mapType,0,10) and info.mapType or nil}
        maps[id]=row;return row
    end
    local function ancestry(id)
        local seen={}
        for _=1,16 do
            if seen[id] then break end
            local row=add(id);if not row then break end
            seen[id]=true;roots[id]=true
            if not A.Integer(row.parent,1,2147483647) then break end
            id=row.parent
        end
    end
    ancestry(A.CurrentLocation().mapID)
    -- Include the base world even when the player is inside an instance.
    for _,id in ipairs({947,1414,1415,1459,1460,1461}) do ancestry(id) end
    for _,id in ipairs(extraMaps or {}) do ancestry(id) end
    for id in pairs(roots) do
        local children=A.Read(C_Map and C_Map.GetMapChildrenInfo,id,nil,true)
        if type(children)=="table" then for i,info in ipairs(children) do
            if i>4096 then break end
            if A.Public(info) and type(info)=="table" then add(info.mapID) end
        end end
    end
    local groups,byKey={},{}
    local function group(key,name,base)
        if not byKey[key] then
            byKey[key]={name=name,base=base,rows={}};groups[#groups+1]=byKey[key]
        end
        return byKey[key]
    end
    for id,row in pairs(maps) do
        local base,scan,seen=nil,row,{}
        local bg=battlegrounds[id] or bgNames[row.zone]
        local other=row.zone=="Zephras Isle"
        for _=1,16 do
            if not scan or seen[scan.mapID] then break end
            seen[scan.mapID]=true
            if battlegrounds[scan.mapID] or bgNames[scan.zone] then bg=true end
            if scan.zone=="Zephras Isle" then other=true end
            if scan.mapType==2 and not base then base=scan end
            scan=maps[scan.parent]
        end
        local g
        if bg then g=group("battlegrounds","Battlegrounds")
        elseif other then g=group("other","Other")
        elseif base then g=group(base.mapID,base.zone,base)
        elseif row.mapType==0 or row.mapType==1 then g=group("world","World maps")
        else g=group("other","Other") end
        g.rows[#g.rows+1]=row
    end
    local function sort(a,b) if a.zone==b.zone then return a.mapID<b.mapID end;return a.zone<b.zone end
    for _,g in ipairs(groups) do table.sort(g.rows,sort) end
    table.sort(groups,function(a,b)
        local ar=a.base and 0 or a.name=="World maps" and 1 or a.name=="Battlegrounds" and 2 or 3
        local br=b.base and 0 or b.name=="World maps" and 1 or b.name=="Battlegrounds" and 2 or 3
        if ar~=br then return ar<br end;return a.name<b.name
    end)
    return groups
end
function ns.CreateAtlasMap(parent,journal,onSelect,onPlace,onNavigate)
    -- Keep the enlarged maps, trimmed 1% to give the details more space.
    local WIDTH,HEIGHT=578*0.99,302*1.25*0.99
    local map=CreateFrame("Frame",nil,parent)
    map:SetSize(WIDTH,HEIGHT);map:EnableMouse(true)
    local viewport=CreateFrame("Frame",nil,map)
    viewport:SetAllPoints();viewport:SetClipsChildren(true);viewport:EnableMouse(false)
    local canvas=CreateFrame("Frame",nil,viewport)
    canvas:SetPoint("TOPLEFT",map,"TOPLEFT");canvas:SetSize(WIDTH,HEIGHT);canvas:EnableMouse(false)
    map.canvas=canvas;map.zoom=1;map.panX=0;map.panY=0
    local function positionCanvas()
        canvas:SetSize(map:GetWidth(),map:GetHeight());canvas:SetScale(map.zoom)
        canvas:ClearAllPoints()
        canvas:SetPoint("TOPLEFT",map,"TOPLEFT",-map.panX/map.zoom,map.panY/map.zoom)
        if map.UpdateSubzoneDotSize then map:UpdateSubzoneDotSize() end
    end
    local function cursorPoint()
        if type(GetCursorPosition)~="function" then return end
        local ok,cx,cy=pcall(GetCursorPosition)
        if not ok or not A.Number(cx,-1000000,1000000) or not A.Number(cy,-1000000,1000000) then return end
        local scale,left,top=map:GetEffectiveScale(),map:GetLeft(),map:GetTop()
        if not cx or not cy or not left or not top or not scale or scale<=0 then return end
        return math.max(0,math.min(map:GetWidth(),cx/scale-left)),
            math.max(0,math.min(map:GetHeight(),top-cy/scale))
    end
    local panDriver=CreateFrame("Frame",nil,map);panDriver:Hide()
    local drag,panConsumed
    function map:CancelPan()
        drag=nil;panConsumed=nil;panDriver:Hide()
    end
    function map:StartPan(button)
        self:CancelPan()
        if button~="LeftButton" or self.placing or not self.available or self.zoom<=1 then return end
        local ok,x,y=pcall(GetCursorPosition)
        local scale=self:GetEffectiveScale()
        if not ok or not A.Number(x,-1000000,1000000) or not A.Number(y,-1000000,1000000) or not scale or scale<=0 then return end
        drag={x=x,y=y,scale=scale,panX=self.panX,panY=self.panY};panDriver:Show()
    end
    function map:UpdatePan()
        if not drag then return end
        local ok,x,y=pcall(GetCursorPosition)
        if not ok or not A.Number(x,-1000000,1000000) or not A.Number(y,-1000000,1000000) then return end
        local dx,dy=(x-drag.x)/drag.scale,(y-drag.y)/drag.scale
        if not panConsumed and dx*dx+dy*dy<16 then return end
        panConsumed=true
        self.panX=math.max(0,math.min(self:GetWidth()*(self.zoom-1),drag.panX-dx))
        self.panY=math.max(0,math.min(self:GetHeight()*(self.zoom-1),drag.panY+dy))
        positionCanvas();if GameTooltip then GameTooltip:Hide() end
    end
    function map:FinishPan()
        self:UpdatePan();drag=nil;panDriver:Hide()
        return panConsumed==true
    end
    panDriver:SetScript("OnUpdate",function()
        map:UpdatePan()
        if type(IsMouseButtonDown)=="function" and not IsMouseButtonDown("LeftButton") then map:FinishPan() end
    end)
    map:SetScript("OnMouseDown",function(self,button) self:StartPan(button) end)
    function map:ZoomBy(delta)
        if not self.available or not A.Number(delta,-100,100) or delta==0 then return end
        self:CancelPan()
        local zoom=math.max(1,math.min(4,self.zoom*1.25^delta))
        local x,y=cursorPoint();x,y=x or self:GetWidth()/2,y or self:GetHeight()/2
        self.panX=math.max(0,math.min(self:GetWidth()*(zoom-1),(self.panX+x)*zoom/self.zoom-x))
        self.panY=math.max(0,math.min(self:GetHeight()*(zoom-1),(self.panY+y)*zoom/self.zoom-y))
        self.zoom=zoom;positionCanvas()
        if self.UpdateRegionHighlight then self:UpdateRegionHighlight() end
        if GameTooltip then GameTooltip:Hide() end
    end
    map:EnableMouseWheel(true)
    map:SetScript("OnMouseWheel",function(self,delta) self:ZoomBy(delta) end)
    -- Both journals use the shell's native frame art, scaled down to a thin
    -- click-through trim outside the existing artwork bounds.
    local border=CreateFrame("Frame",nil,map,"BackdropTemplate")
    border:SetPoint("TOPLEFT",map,"TOPLEFT",-4,4)
    border:SetPoint("BOTTOMRIGHT",map,"BOTTOMRIGHT",4,-4)
    border:SetFrameLevel(map:GetFrameLevel()+6);border:EnableMouse(false)
    local atlases={"_UI-Frame-Bot","!UI-Frame-LeftTile","!UI-Frame-RightTile",
        "UI-Frame-BotCornerLeft","UI-Frame-BotCornerRight"}
    local native=C_Texture and type(C_Texture.GetAtlasInfo)=="function"
    if native then
        for _,atlas in ipairs(atlases) do
            if not A.Read(C_Texture.GetAtlasInfo,atlas) then native=false;break end
        end
    end
    if native then
        local function edge(atlas,width,height,horizontal,vertical,rotation)
            local t=border:CreateTexture(nil,"OVERLAY")
            t:SetAtlas(atlas);t:SetSize(width,height)
            if horizontal then t:SetHorizTile(true) end
            if vertical then t:SetVertTile(true) end
            if rotation then t:SetRotation(rotation) end
            return t
        end
        local bl=edge(atlases[4],7,7);bl:SetPoint("BOTTOMLEFT")
        local br=edge(atlases[5],5.5,5.5);br:SetPoint("BOTTOMRIGHT")
        local tl=edge(atlases[5],5.5,5.5,false,false,math.pi);tl:SetPoint("TOPLEFT")
        local tr=edge(atlases[4],7,7,false,false,math.pi);tr:SetPoint("TOPRIGHT")
        local bottom=edge(atlases[1],128,4.5,true)
        bottom:SetPoint("BOTTOMLEFT",bl,"BOTTOMRIGHT");bottom:SetPoint("BOTTOMRIGHT",br,"BOTTOMLEFT")
        local top=edge(atlases[1],128,4.5,true,false,math.pi)
        top:SetPoint("TOPLEFT",tl,"TOPRIGHT");top:SetPoint("TOPRIGHT",tr,"TOPLEFT")
        local left=edge(atlases[2],8,128,false,true)
        left:SetPoint("TOPLEFT",tl,"BOTTOMLEFT");left:SetPoint("BOTTOMLEFT",bl,"TOPLEFT")
        local right=edge(atlases[3],5,128,false,true)
        right:SetPoint("TOPRIGHT",tr,"BOTTOMRIGHT");right:SetPoint("BOTTOMRIGHT",br,"TOPRIGHT")
    else
        border:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=8})
    end
    map.playerCoordinates=ns.FieldbookUI.Label(border,"",0,0,250,"GameFontHighlightSmall")
    map.playerCoordinates:ClearAllPoints()
    map.playerCoordinates:SetPoint("BOTTOMLEFT",map,"BOTTOMLEFT",8,29)
    map.playerCoordinates:SetTextColor(0.55,0.57,0.57)
    map.playerCoordinates:SetJustifyH("LEFT")
    local coordinateFont,coordinateSize=map.playerCoordinates:GetFont()
    map.playerCoordinates:SetFont(coordinateFont,coordinateSize,"OUTLINE")
    map.playerCoordinates:SetShadowColor(0,0,0,1);map.playerCoordinates:SetShadowOffset(1,-1)
    local tiles,overlays,pins,lines={},{},{},{}
    function map:SetPinIcon(pin,texture)
        pin.icon:SetTexture(texture)
        pin.icon:SetTexCoord(0,1,0,1)
    end
    function map:ApplyBrightness()
        local value=ns.MapBrightness.saved and ns.MapBrightness:Get()
            or (journal.subzones and A.Number(journal.state.mapBrightness,0.2,1) and journal.state.mapBrightness or 1)
        for _,pool in ipairs({tiles,overlays}) do
            for _,texture in ipairs(pool) do texture:SetVertexColor(value,value,value) end
        end
    end
    map.brightness=ns.MapBrightness:Attach(map,function()
        return journal.subzones and A.Number(journal.state.mapBrightness,0.2,1) and journal.state.mapBrightness or 1
    end,function(value)
        if journal.state and not journal.readOnly then journal.state.mapBrightness=value end
    end,function() map:ApplyBrightness() end)
    local cachedMap
    local displayedMapID,playerElapsed
    if journal.subzones and ns.AtlasSubzones then ns.AtlasSubzones.InstallMap(map,journal,cursorPoint) end
    -- Reuse the native map highlight shape, cropped and positioned in map coordinates.
    map.regionHighlight=canvas:CreateTexture(nil,"ARTWORK",nil,1)
    map.regionHighlight:SetBlendMode("ADD");map.regionHighlight:Hide()
    function map:UpdateRegionHighlight()
        local texture=self.regionHighlight;texture:Hide()
        if not self.available or not displayedMapID or self.placing or drag or
            A.Read(self.IsVisible,self)==false or A.Read(self.IsMouseOver,self)~=true or
            (ns.IsMapClickNavigationEnabled and not ns.IsMapClickNavigationEnabled()) or
            (IsControlKeyDown and IsControlKeyDown()) then return end
        local fn=C_Map and C_Map.GetMapHighlightInfoAtPosition
        if type(fn)~="function" then return end
        local x,y=cursorPoint();if not x then return end
        local ok,file,atlas,u,v,w,h,left,top=pcall(fn,displayedMapID,
            (x+self.panX)/(self:GetWidth()*self.zoom),(y+self.panY)/(self:GetHeight()*self.zoom))
        if not ok or not A.Number(u,0,1) or not A.Number(v,0,1) or
            not A.Number(w,0.000001,2) or not A.Number(h,0.000001,2) or
            not A.Number(left,-1,2) or not A.Number(top,-1,2) then return end
        if A.Text(atlas,256) then texture:SetAtlas(atlas)
        elseif A.Integer(file,1,2147483647) then texture:SetTexture(file,nil,nil,"TRILINEAR")
        else return end
        texture:SetTexCoord(0,u,0,v)
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT",canvas,"TOPLEFT",left*self:GetWidth(),-top*self:GetHeight())
        texture:SetSize(w*self:GetWidth(),h*self:GetHeight());texture:Show()
    end
    function map:UpdateWeather()
        if self.weatherText then self.weatherText:SetText("|cffffd100Observed Weather:|r "..journal:WeatherText(displayedMapID)) end
    end
    local player=CreateFrame("Frame",nil,canvas)
    player:SetAllPoints();player:SetFrameLevel(map:GetFrameLevel()+5);player:EnableMouse(false)
    map.playerArrow=player:CreateTexture(nil,"OVERLAY",nil,7)
    map.playerArrow:SetSize(27,27);map.playerArrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    map.playerArrow:Hide()
    function map:UpdatePlayer()
        self:UpdateRegionHighlight()
        if self.RenderSubzones then self:RenderSubzones();self:SubzoneHover() end
        local arrow=self.playerArrow;arrow:Hide()
        self.playerCoordinates:SetText("Player coordinates unavailable")
        if not C_Map then return end
        if A.Read(self.IsVisible,self)==false then return end
        local currentMapID=A.Read(C_Map.GetBestMapForUnit,"player")
        if not A.Integer(currentMapID,1,2147483647) then return end
        local position=A.Read(C_Map.GetPlayerMapPosition,currentMapID,"player")
        if type(position)~="table" then return end
        local x,y=A.Read(function() return position.x end),A.Read(function() return position.y end)
        if not A.Number(x,0,1) or not A.Number(y,0,1) or (x==0 and y==0) then return end
        self.playerCoordinates:SetText(string.format("Player: %.2f, %.2f",x*100,y*100)..
            (currentMapID~=displayedMapID and " (other map)" or ""))
        if not self.available or currentMapID~=displayedMapID then return end
        local facing=A.Read(GetPlayerFacing)
        if not A.Number(facing,0,2*math.pi) then return end
        arrow:ClearAllPoints();arrow:SetPoint("CENTER",canvas,"TOPLEFT",x*self:GetWidth(),-y*self:GetHeight())
        arrow:SetRotation(facing);arrow:Show()
    end
    function map:SuspendPlayer()
        self:SetScript("OnUpdate",nil);self.playerArrow:Hide();self.regionHighlight:Hide();playerElapsed=0
    end
    function map:ResumePlayer()
        self:UpdatePlayer()
        if A.Read(self.IsVisible,self)==false then self:SuspendPlayer();return end
        playerElapsed=0
        self:SetScript("OnUpdate",function(self,dt)
            playerElapsed=playerElapsed+dt
            if playerElapsed>=0.1 then playerElapsed=0;self:UpdatePlayer() end
        end)
    end
    function map:Invalidate() cachedMap=nil end
    local function hide(pool) for _,f in ipairs(pool) do f:Hide() end end
    local function leave()
        if GameTooltip then GameTooltip:Hide() end
    end
    map.empty=ns.FieldbookUI.Label(map,"",12,-110,554,"GameFontHighlight")
    map.empty:SetJustifyH("CENTER");map.empty:SetWordWrap(true)
    local function drawArt(id)
        hide(tiles);hide(overlays);map:SetSize(WIDTH,HEIGHT);map.available=false
        if not id then return end
        local layers=A.Read(C_Map and C_Map.GetMapArtLayers,id)
        local l=type(layers)=="table" and layers[1]
        if not A.Public(l) or type(l)~="table" then return end
        for _,k in ipairs({"layerWidth","layerHeight","tileWidth","tileHeight"}) do if not A.Number(l[k],1,100000) then return end end
        local cols,rows=math.ceil(l.layerWidth/l.tileWidth),math.ceil(l.layerHeight/l.tileHeight)
        if cols*rows>128 then return end
        local textures=A.Read(C_Map.GetMapArtLayerTextures,id,1)
        if type(textures)~="table" then return end
        for i=1,cols*rows do if not A.Integer(textures[i],1,2147483647) then return end end
        local scale=math.min(WIDTH/l.layerWidth,HEIGHT/l.layerHeight)
        map:SetSize(l.layerWidth*scale,l.layerHeight*scale)
        for row=0,rows-1 do for col=0,cols-1 do
            local i=row*cols+col+1;local t=tiles[i] or canvas:CreateTexture(nil,"BACKGROUND");tiles[i]=t
            local w,h=math.min(l.tileWidth,l.layerWidth-col*l.tileWidth),math.min(l.tileHeight,l.layerHeight-row*l.tileHeight)
            t:ClearAllPoints();t:SetPoint("TOPLEFT",col*l.tileWidth*scale,-row*l.tileHeight*scale)
            t:SetSize(w*scale,h*scale);t:SetTexture(textures[i]);t:SetTexCoord(0,w/l.tileWidth,0,h/l.tileHeight);t:Show()
        end end
        local regions=A.Read(C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures,id)
        local index=0
        local function power(v) local n=16;while n<v do n=n*2 end;return n end
        for ri,r in ipairs(type(regions)=="table" and regions or {}) do
            if ri>128 then break end
            if A.Public(r) and type(r)=="table" and A.Number(r.textureWidth,1,100000) and A.Number(r.textureHeight,1,100000)
                and A.Number(r.offsetX,0,100000) and A.Number(r.offsetY,0,100000)
                and A.Public(r.fileDataIDs) and type(r.fileDataIDs)=="table" and A.Public(r.isShownByMouseOver) and not r.isShownByMouseOver then
                local nc,nr=math.ceil(r.textureWidth/l.tileWidth),math.ceil(r.textureHeight/l.tileHeight)
                if nc*nr<=128 then
                    for row=0,nr-1 do for col=0,nc-1 do
                        local file=r.fileDataIDs[row*nc+col+1]
                        local x,y=r.offsetX+col*l.tileWidth,r.offsetY+row*l.tileHeight
                        local w,h=math.min(l.tileWidth,r.textureWidth-col*l.tileWidth),math.min(l.tileHeight,r.textureHeight-row*l.tileHeight)
                        local fw,fh=col==nc-1 and power(w) or l.tileWidth,row==nr-1 and power(h) or l.tileHeight
                        w,h=math.min(w,l.layerWidth-x),math.min(h,l.layerHeight-y)
                        if index<256 and w>0 and h>0 and A.Integer(file,1,2147483647) then
                            index=index+1;local t=overlays[index] or canvas:CreateTexture(nil,"BORDER");overlays[index]=t
                            t:ClearAllPoints();t:SetPoint("TOPLEFT",x*scale,-y*scale);t:SetSize(w*scale,h*scale)
                            t:SetTexture(file);t:SetTexCoord(0,w/fw,0,h/fh);t:Show()
                        end
                    end end
                end
            end
        end
        map.available=true
    end
    function map:Render(mapID,selected)
        leave();hide(pins);hide(lines)
        if displayedMapID~=mapID then self:CancelPan();self.zoom,self.panX,self.panY=1,0,0 end
        -- Pooled native frames outlive their contents. Release every previous
        -- group, including unused slots after switching to a less populated map.
        for _,pin in ipairs(pins) do pin.group,pin.selected=nil,nil end
        if cachedMap~=mapID or not self.available then drawArt(mapID);cachedMap=mapID end
        self:ApplyBrightness()
        positionCanvas()
        displayedMapID=mapID;self.displayedMapID=mapID;self.subzoneMapID=mapID;self:ResumePlayer();self:UpdateWeather()
        self.empty:SetShown(not self.available)
        self.empty:SetText(mapID and "Map artwork unavailable in this client.\nCoordinates and the index remain available." or "Choose a zone or use Current Zone.\nAdd Discovery can also save an unpositioned record.")
        if not self.available then return "Map unavailable; use the index." end
        local markers={};local entry=journal:Get(selected)
        if entry and entry.category=="route" and not entry.entrance then
            local routePins,segments=journal:RouteMap(entry,mapID)
            for _,p in ipairs(routePins) do markers[#markers+1]={id=selected,point=p,category="route",number=p.number,name=entry.name.." • "..p.number..". "..p.name} end
            if journal.DrawRoute then
                journal:DrawRoute(self,lines,segments)
            else
                for i,segment in ipairs(segments) do
                    local line=lines[i]
                    if not line and type(canvas.CreateLine)=="function" then
                        local ok,v=pcall(canvas.CreateLine,canvas,nil,"ARTWORK");if ok then line=v;lines[i]=v end
                    end
                    if line and type(line.SetStartPoint)=="function" then
                        line:SetThickness(2);line:SetColorTexture(1,0.82,0.14,0.8)
                        line:SetStartPoint("TOPLEFT",segment.from.x/10000*self:GetWidth(),-segment.from.y/10000*self:GetHeight())
                        line:SetEndPoint("TOPLEFT",segment.to.x/10000*self:GetWidth(),-segment.to.y/10000*self:GetHeight());line:Show()
                    end
                end
            end
            self.linesAvailable=#segments==0 or lines[1]~=nil
        end
        for _,e in ipairs(journal:List("",mapID,false)) do
            -- A passage can be recorded as a position before an itinerary is
            -- built. Show that observation without manufacturing a stop.
            if e.category=="route" and #e.stops==0 and e.mapID==mapID and A.Position(e) and journal:Layer("route") then
                markers[#markers+1]={id=e.id,point=e,category="route",name=e.name..(e.entrance and " • observed entrance" or " • recorded passage position")}
            elseif e.category~="route" and A.Position(e) and journal:Layer(e.category) then
                markers[#markers+1]={id=e.id,point=e,category=e.category,name=e.name}
            elseif e.category=="route" and e.id~=selected and journal:Layer("route") then
                local routePins=journal:RouteMap(e,mapID)
                local p=routePins[1]
                if p then markers[#markers+1]={id=e.id,point=p,category="route",name=e.name.." • select for itinerary"} end
            end
        end
        -- Pixel buckets collect overlapping icons. Repeated clicks cycle every
        -- member; all records also remain accessible in the searchable index.
        local groups,byCell={},{}
        for _,m in ipairs(markers) do
            local key=math.floor(m.point.x/10000*self:GetWidth()/18)..":"..math.floor(m.point.y/10000*self:GetHeight()/18)
            local group=byCell[key]
            if not group then group={};byCell[key]=group;groups[#groups+1]=group end
            group[#group+1]=m;if m.id==selected then group.selected=true end
        end
        table.sort(groups,function(a,b) if a.selected~=b.selected then return a.selected==true end;return a[1].name<b[1].name end)
        for i=1,math.min(192,#groups) do
            local g=groups[i];local p=pins[i]
            if not p then
                p=CreateFrame("Button",nil,canvas,"BackdropTemplate");p:SetSize(20,20)
                p:EnableMouseWheel(true);p:SetScript("OnMouseWheel",function(_,delta) map:ZoomBy(delta) end)
                if not journal.borderlessPins then p:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8}) end
                p.icon=p:CreateTexture(nil,"ARTWORK");p.icon:SetPoint("TOPLEFT",3,-3);p.icon:SetPoint("BOTTOMRIGHT",-3,3)
                -- Counts belong to the icon, not the journal's reading text.
                -- Scale a small fixed font with the pin and inherited map zoom.
                p.text=p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                local font=p.text:GetFont()
                p.text:SetFont(font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",8,"OUTLINE")
                p.text:SetPoint("BOTTOMRIGHT",p.icon,"BOTTOMRIGHT",0,0)
                p.text:SetJustifyH("RIGHT")
                p:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
                p:RegisterForClicks("LeftButtonUp","RightButtonUp")
                p:SetScript("OnMouseDown",function(_,button) map:StartPan(button) end)
                p:SetScript("OnClick",function(self,button)
                    if map:FinishPan() then return end
                    if button=="RightButton" then map:Navigate(button);return end
                    local index=0
                    for n,m in ipairs(self.group) do if m.id==self.selected then index=n;break end end
                    local nextMarker=self.group[index%#self.group+1];onSelect(nextMarker.id)
                end)
                p:SetScript("OnEnter",function(self)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText("Atlas discoveries")
                    for n,m in ipairs(self.group) do
                        if n>8 then GameTooltip:AddLine("… "..(#self.group-8).." more; use the index.");break end
                        GameTooltip:AddLine(A.AutomaticLabel(m.name,m.point.entrance).." — "..categoryInfo(m.category).label,1,1,1,true)
                        GameTooltip:AddLine(string.format("%.1f, %.1f",m.point.x/100,m.point.y/100),0.75,0.8,0.8)
                        if m.point.entrance then
                            local e=m.point.evidence
                            GameTooltip:AddLine(e.entries.." entries / "..e.exits.." exits • "..e.evidence,0.75,0.8,0.8)
                            GameTooltip:AddLine("Type: "..m.point.classification.kind,0.75,0.8,0.8)
                        end
                    end
                    if #self.group>1 then GameTooltip:AddLine("Click repeatedly to cycle overlapping entries.",1,0.82,0.14,true) end
                    GameTooltip:Show()
                end)
                p:SetScript("OnLeave",leave);p:SetScript("OnHide",leave);pins[i]=p
            end
            local m=g[1];for _,v in ipairs(g) do if v.id==selected then m=v;break end end
            p.group,p.selected=g,selected;p:ClearAllPoints()
            p:SetPoint("CENTER",canvas,"TOPLEFT",m.point.x/10000*self:GetWidth(),-m.point.y/10000*self:GetHeight())
            local info=categoryInfo(m.category)
            p.icon:SetTexture(info.icon);p.icon:SetVertexColor(1,1,1)
            p.text:SetText(m.number and tostring(m.number) or (#g>1 and tostring(#g) or ""))
            local iconSize=journal.state and journal.state.iconSize
            local size=A.Number(iconSize,6,40) and iconSize or 20
            size=size+(g.selected and 4 or 0)
            p:SetSize(size,size)
            local inset=journal.borderlessPins and 0 or size*0.15
            p.icon:ClearAllPoints();p.icon:SetPoint("TOPLEFT",inset,-inset);p.icon:SetPoint("BOTTOMRIGHT",-inset,inset)
            p.text:SetScale(size/20)
            if not journal.borderlessPins then p:SetBackdropBorderColor(g.selected and 1 or 0.15,g.selected and 0.82 or 0.15,g.selected and 0.14 or 0.15,1) end
            p:Show()
        end
        self.pins,self.lines=pins,lines
        local caption=""
        if #groups>192 then caption="192 marker groups shown; use the index for the full journal." end
        if entry and entry.category=="route" and not entry.entrance then
            if #entry.stops==0 then
                caption=A.Position(entry) and "Recorded passage position; no itinerary stops added yet." or "Unpositioned passage; add a map position or itinerary stops."
            else
                caption=self.linesAvailable and "Numbered stops; lines are recorded connections, not safe paths." or "Numbered stops only; line rendering is unavailable."
            end
        end
        return caption
    end
    function map:Navigate(button)
        if self.placing or not onNavigate or not displayedMapID or
            (ns.IsMapClickNavigationEnabled and not ns.IsMapClickNavigationEnabled()) or
            (IsControlKeyDown and IsControlKeyDown()) then return end
        local target
        if button=="RightButton" then
            local info=A.Read(C_Map and C_Map.GetMapInfo,displayedMapID)
            if type(info)=="table" and A.Integer(info.parentMapID,1,2147483647) then
                target=A.Read(C_Map and C_Map.GetMapInfo,info.parentMapID)
            end
        elseif button=="LeftButton" and self.available then
            local x,y=cursorPoint();if not x then return end
            target=A.Read(C_Map and C_Map.GetMapInfoAtPosition,displayedMapID,
                (x+self.panX)/(self:GetWidth()*self.zoom),(y+self.panY)/(self:GetHeight()*self.zoom))
        end
        if type(target)=="table" and A.Integer(target.mapID,1,2147483647) and target.mapID~=displayedMapID
            and A.Text(target.name,160) then
            if GameTooltip then GameTooltip:Hide() end
            onNavigate(target.mapID,target.name)
        end
    end
    map:SetScript("OnMouseUp",function(self,button)
        if self:FinishPan() then return end
        if not self.placing then self:Navigate(button);return end
        if button~="LeftButton" or not self.available then return end
        local x,y=cursorPoint();if not x then return end
        x,y=(x+self.panX)/(self:GetWidth()*self.zoom),(y+self.panY)/(self:GetHeight()*self.zoom)
        if A.Number(x,0,1) and A.Number(y,0,1) then onPlace(math.floor(x*10000+0.5),math.floor(y*10000+0.5)) end
    end)
    map:HookScript("OnEnter",function(self) self:UpdateRegionHighlight() end)
    map:HookScript("OnLeave",function(self) self.regionHighlight:Hide() end)
    map:SetScript("OnShow",function(self) self:ResumePlayer() end)
    map:SetScript("OnHide",function(self)
        self.subzoneHover=false;self:CancelPan();leave();self:SuspendPlayer()
        if self.CancelSubzones then self:CancelSubzones() end
    end)
    return map
end
