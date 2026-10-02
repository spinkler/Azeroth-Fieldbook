local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end

function ns.CreateCreatureLocationsWindow(journal,getBook)
    local controller={}
    local frame,selected,zoneKey,revision,visibleKey,currentZone
    local zones,tiles,exploration,fills,dots,glows={},{},{},{},{},{}
    local menuOffset=0
    local displayedMapID
    local WIDTH,HEIGHT=558,372
    local palettes={
        kills={fill={0.9,0.18,1},border={1,0.55,1}},
        observations={fill={0.05,0.8,1},border={0.45,1,1}},
    }
    local function mode() return journal:GetLocationTrackingMode() end
    local function colour(texture,kind,alpha)
        local c=palettes[mode()][kind]
        texture:SetColorTexture(c[1],c[2],c[3],alpha)
    end
    local function public(v) return not (issecretvalue and issecretvalue(v)) end
    local function number(v) return public(v) and type(v)=="number" and v>0 and v<=100000 end
    local function read(fn,...)
        if type(fn)~="function" then return end
        local ok,v=pcall(fn,...);if ok and public(v) then return v end
    end
    local function label(parent,text,x,y,w,font)
        local t=parent:CreateFontString(nil,"OVERLAY",textFont(font or "GameFontHighlightSmall"))
        t:SetPoint("TOPLEFT",x,y);t:SetWidth(w);t:SetJustifyH("LEFT");t:SetText(text);return t
    end
    local function key(zone) return zone.mapID and ("map:"..zone.mapID) or ("name:"..zone.name) end
    local function hide(pool) for _,item in ipairs(pool) do item:Hide() end end
    local function tipLeave() if GameTooltip then GameTooltip:Hide() end end
    local function updatePlayer()
        local arrow=frame.playerArrow
        arrow:Hide()
        frame.playerCoordinates:SetText("Player coordinates unavailable")
        if not displayedMapID or not C_Map then return end
        if read(C_Map.GetBestMapForUnit,"player")~=displayedMapID then return end
        local position=read(C_Map.GetPlayerMapPosition,displayedMapID,"player")
        if type(position)~="table" then return end
        local x,y=read(function() return position.x end),read(function() return position.y end)
        local facing=read(GetPlayerFacing)
        local function finite(v,low,high) return type(v)=="number" and v>=low and v<=high end
        if not finite(x,0,1) or not finite(y,0,1) then return end
        frame.playerCoordinates:SetText(string.format("Player: %.2f, %.2f",x*100,y*100))
        if not finite(facing,0,2*math.pi) then return end
        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER",frame.map,"TOPLEFT",x*frame.map:GetWidth(),-y*frame.map:GetHeight())
        arrow:SetRotation(facing);arrow:Show()
    end
    local function applyBrightness()
        local value=journal:GetLocationMapBrightness()
        for _,pool in ipairs({tiles,exploration}) do
            for _,texture in ipairs(pool) do texture:SetVertexColor(value,value,value) end
        end
        frame.brightnessValue:SetText(math.floor(value*100+0.5).."%")
    end
    local function drawBoundary(points,triangles,w,h)
        hide(glows)
        local edges={}
        for _,t in ipairs(triangles) do
            for i=1,3 do
                local a,b=t[i],t[i%3+1]
                if a>b then a,b=b,a end
                local k=a..":"..b
                if edges[k] then edges[k].count=edges[k].count+1 else edges[k]={a,b,count=1} end
            end
        end
        local index=0
        for _,edge in pairs(edges) do
            -- Outline only exposed edges, not the triangulation's internal seams.
            if edge.count==1 then
                local a,b=points[edge[1]],points[edge[2]]
                local ax,ay,bx,by=a.u*w,a.v*h,b.u*w,b.v*h
                local dx,dy=bx-ax,by-ay
                local length=math.sqrt(dx*dx+dy*dy)
                for _,style in ipairs({{8,0.07},{4,0.16},{1.5,0.85}}) do
                    index=index+1
                    local t=glows[index] or frame.map:CreateTexture(nil,"ARTWORK",nil,1)
                    glows[index]=t
                    local nx,ny=-dy/length*style[1]/2,dx/length*style[1]/2
                    local corners={{ax-nx,ay-ny},{ax+nx,ay+ny},{bx-nx,by-ny},{bx+nx,by+ny}}
                    local left,right,top,bottom=math.huge,-math.huge,math.huge,-math.huge
                    for _,p in ipairs(corners) do
                        left=math.min(left,p[1]);right=math.max(right,p[1]);top=math.min(top,p[2]);bottom=math.max(bottom,p[2])
                    end
                    local tw,th=right-left,bottom-top
                    t:ClearAllPoints();t:SetPoint("TOPLEFT",frame.map,"TOPLEFT",left,-top);t:SetSize(tw,th)
                    colour(t,"border",style[2]);t:SetBlendMode("ADD")
                    local base={{0,0},{0,-th},{tw,0},{tw,-th}}
                    for i,p in ipairs(corners) do t:SetVertexOffset(i,p[1]-left-base[i][1],top-p[2]-base[i][2]) end
                    t:Show()
                end
            end
        end
    end
    local function drawExploration(mapID,layer,scale)
        hide(exploration)
        local regions=read(C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures,mapID)
        if type(regions)~="table" then return end
        local index=0
        local function powerOfTwo(value) local size=16;while size<value do size=size*2 end;return size end
        for _,region in ipairs(regions) do
            if public(region) and type(region)=="table" and number(region.textureWidth) and number(region.textureHeight)
                and public(region.offsetX) and type(region.offsetX)=="number" and region.offsetX>=0
                and public(region.offsetY) and type(region.offsetY)=="number" and region.offsetY>=0
                and public(region.fileDataIDs) and type(region.fileDataIDs)=="table"
                and public(region.isShownByMouseOver) and not region.isShownByMouseOver then
                local cols,rows=math.ceil(region.textureWidth/layer.tileWidth),math.ceil(region.textureHeight/layer.tileHeight)
                if cols*rows<=128 then
                    for row=0,rows-1 do for col=0,cols-1 do
                        local id=region.fileDataIDs[row*cols+col+1]
                        local x,y=region.offsetX+col*layer.tileWidth,region.offsetY+row*layer.tileHeight
                        local pw=math.min(layer.tileWidth,region.textureWidth-col*layer.tileWidth)
                        local ph=math.min(layer.tileHeight,region.textureHeight-row*layer.tileHeight)
                        local fw=col==cols-1 and powerOfTwo(pw) or layer.tileWidth
                        local fh=row==rows-1 and powerOfTwo(ph) or layer.tileHeight
                        pw,ph=math.min(pw,layer.layerWidth-x),math.min(ph,layer.layerHeight-y)
                        if public(id) and type(id)=="number" and id>0 and pw>0 and ph>0 then
                            index=index+1;if index>256 then return end
                            local t=exploration[index] or frame.map:CreateTexture(nil,"BORDER")
                            exploration[index]=t
                            t:ClearAllPoints();t:SetPoint("TOPLEFT",frame.map,"TOPLEFT",x*scale,-y*scale)
                            t:SetSize(pw*scale,ph*scale);t:SetTexCoord(0,pw/fw,0,ph/fh)
                            t:SetTexture(id,nil,nil,"TRILINEAR")
                            t:SetDrawLayer("BORDER",public(region.isDrawOnTopLayer) and region.isDrawOnTopLayer and 1 or 0)
                            t:Show()
                        end
                    end end
                end
            end
        end
    end
    local function drawMap(mapID)
        hide(tiles);hide(exploration)
        frame.map:SetSize(WIDTH,HEIGHT)
        if not mapID or not C_Map then return false end
        local layers=read(C_Map.GetMapArtLayers,mapID)
        local layer=type(layers)=="table" and layers[1]
        if not public(layer) or type(layer)~="table" then return false end
        for _,k in ipairs({"layerWidth","layerHeight","tileWidth","tileHeight"}) do
            if not number(layer[k]) then return false end
        end
        local cols,rows=math.ceil(layer.layerWidth/layer.tileWidth),math.ceil(layer.layerHeight/layer.tileHeight)
        if cols*rows>128 then return false end
        local textures=read(C_Map.GetMapArtLayerTextures,mapID,1)
        if type(textures)~="table" then return false end
        for i=1,cols*rows do
            if not public(textures[i]) or type(textures[i])~="number" or textures[i]<=0 then return false end
        end
        local scale=math.min(WIDTH/layer.layerWidth,HEIGHT/layer.layerHeight)
        frame.map:SetSize(layer.layerWidth*scale,layer.layerHeight*scale)
        for row=0,rows-1 do
            for col=0,cols-1 do
                local i=row*cols+col+1
                local tile=tiles[i] or frame.map:CreateTexture(nil,"BACKGROUND")
                tiles[i]=tile
                local w=math.min(layer.tileWidth,layer.layerWidth-col*layer.tileWidth)
                local h=math.min(layer.tileHeight,layer.layerHeight-row*layer.tileHeight)
                tile:ClearAllPoints();tile:SetPoint("TOPLEFT",frame.map,"TOPLEFT",col*layer.tileWidth*scale,-row*layer.tileHeight*scale)
                tile:SetSize(w*scale,h*scale);tile:SetTexture(textures[i],nil,nil,"TRILINEAR")
                tile:SetTexCoord(0,w/layer.tileWidth,0,h/layer.tileHeight);tile:Show()
            end
        end
        drawExploration(mapID,layer,scale)
        return true
    end
    local function drawSamples(map)
        hide(fills);hide(dots)
        local points,triangles,covered=ns.LocationGeometry.Build(map)
        local w,h=frame.map:GetWidth(),frame.map:GetHeight()
        local approx=0
        for _,p in ipairs(points) do if p.approximate then approx=approx+1 end end
        for i,t in ipairs(triangles) do
            local texture=fills[i] or frame.map:CreateTexture(nil,"ARTWORK")
            fills[i]=texture
            local a,b,c=points[t[1]],points[t[2]],points[t[3]]
            -- UL=a, LL=b, UR=c, LR=b: one triangle plus a degenerate one.
            if (b.u-a.u)*(c.v-a.v)-(b.v-a.v)*(c.u-a.u)>0 then b,c=c,b end
            local left,top=math.min(a.u,b.u,c.u)*w,math.min(a.v,b.v,c.v)*h
            local tw,th=math.max(a.u,b.u,c.u)*w-left,math.max(a.v,b.v,c.v)*h-top
            texture:ClearAllPoints();texture:SetPoint("TOPLEFT",frame.map,"TOPLEFT",left,-top)
            texture:SetSize(tw,th);colour(texture,"fill",0.46)
            texture:SetVertexOffset(1,a.u*w-left,top-a.v*h)
            texture:SetVertexOffset(2,b.u*w-left,top+th-b.v*h)
            texture:SetVertexOffset(3,c.u*w-left-tw,top-c.v*h)
            texture:SetVertexOffset(4,b.u*w-left-tw,top+th-b.v*h)
            texture:Show()
        end
        drawBoundary(points,triangles,w,h)
        local index=0
        for i,p in ipairs(points) do
            if not covered[i] then
                index=index+1
                local dot=dots[index]
                if not dot then
                    dot=CreateFrame("Frame",nil,frame.map);dots[index]=dot;dot:SetSize(10,10)
                    dot.border=dot:CreateTexture(nil,"BACKGROUND");dot.border:SetAllPoints()
                    dot.texture=dot:CreateTexture(nil,"OVERLAY")
                    dot.texture:SetPoint("TOPLEFT",2,-2);dot.texture:SetPoint("BOTTOMRIGHT",-2,2)
                    dot:EnableMouse(true)
                    dot:SetScript("OnMouseUp",function(_,button) frame.map:Navigate(button) end)
                dot:SetScript("OnEnter",function(self)
                        if GameTooltip then
                            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                            GameTooltip:SetText(mode()=="observations" and "Observation location"
                                or self.location.approximate and "Approximate kill location" or "Creature kill location")
                            GameTooltip:AddLine(string.format("%.1f, %.1f",self.location.u*100,self.location.v*100),1,1,1)
                            if mode()=="observations" then GameTooltip:AddLine("Your position when you targeted this creature.",0.7,0.7,0.7)
                            elseif self.location.approximate then GameTooltip:AddLine("Your position when the kill was credited.",0.7,0.7,0.7) end
                            GameTooltip:Show()
                        end
                    end)
                    dot:SetScript("OnLeave",tipLeave);dot:SetScript("OnHide",tipLeave)
                end
                dot.location=p;dot:ClearAllPoints();dot:SetPoint("CENTER",frame.map,"TOPLEFT",p.u*w,-p.v*h)
                colour(dot.border,"border",1);colour(dot.texture,"fill",1);dot:Show()
            end
        end
        return #points,approx,#triangles
    end
    local render,renderMenu
    renderMenu=function()
        menuOffset=math.max(0,math.min(menuOffset,math.floor(math.max(0,#zones-1)/8)*8))
        for i,row in ipairs(frame.menu.rows) do
            local zone=zones[menuOffset+i]
            row.zone=zone;row:SetShown(zone~=nil)
            if zone then row:SetText(zone.name) end
        end
        frame.menu.previous:SetEnabled(menuOffset>0)
        frame.menu.next:SetEnabled(menuOffset+8<#zones)
    end
    render=function(force)
        if not frame or not frame:IsShown() then return end
        local entry=selected and journal.entries[selected]
        if not entry then currentZone=nil end
        local signature=tostring(selected)..":"..tostring(zoneKey)..":"..mode()
        if not force and revision==journal.revision and visibleKey==signature then return end
        revision=journal.revision
        local brightness=0.504*journal:GetBackgroundBrightness()*0.34
        frame.paper:SetVertexColor(brightness,brightness,brightness)
        frame.menu.paper:SetVertexColor(brightness,brightness,brightness)
        zones=ns.CreatureLocations.Zones(entry,mode())
        local chosen
        for _,zone in ipairs(zones) do if key(zone)==zoneKey then chosen=zone;break end end
        if not chosen and currentZone and key(currentZone)==zoneKey then chosen=currentZone end
        if not chosen then
            local current=ns.CreatureLocations.CurrentMap()
            for _,zone in ipairs(zones) do if current and zone.mapID==current.mapID then chosen=zone;break end end
            chosen=chosen or zones[1]
        end
        zoneKey=chosen and key(chosen)
        visibleKey=tostring(selected)..":"..tostring(zoneKey)..":"..mode()
        frame.creature:SetText(entry and (journal:GetCreatureName(selected) or "Creature") or "Select a creature in the Bestiary.")
        frame.zoneName:SetText(chosen and chosen.name or "No zones recorded")
        frame.zoneName:Hide()
        frame.zoneButton:Show();frame.zoneButton:SetEnabled(#zones>0);frame.zoneButton:SetText((chosen and chosen.name or "Select zone"))
        frame.menu:Hide();renderMenu()
        local available=drawMap(chosen and chosen.mapID)
        displayedMapID=available and chosen.mapID or nil
        frame.map.regionHighlight:Hide()
        updatePlayer()
        hide(fills);hide(dots);hide(glows)
        local count,approx,triangles=0,0,0
        if available then count,approx,triangles=drawSamples(chosen.data) end
        frame.empty:SetShown(not available)
        frame.empty:SetText(chosen and "Zone map unavailable. Visit this zone and observe a creature to link its map." or "No locations recorded yet.")
        local observations=mode()=="observations"
        local status=count..(observations and " observation positions" or " mapped positions • "..approx.." approximate")
        frame.status:SetText(count>0 and (status..(triangles>0 and " • nearby groups shaded" or ""))
            or observations and "No mapped observations. Target this creature to record your position."
            or "No mapped kills. Locations are collected from credited kills.")
        if count>0 then frame.status:SetTextColor(1,1,1) else frame.status:SetTextColor(1,0.2,0.2) end
        if count>=3 and chosen.data and (not chosen.data.width or not chosen.data.height) then
            frame.status:SetText(status.." • map scale unavailable; dots only")
        end
        frame.legend:SetText(observations and "Cyan: your position when you targeted the creature, including during flight."
            or "Violet: credited kills. Approximate positions use your location at the time.")
        frame.trackingMode:SetText(observations and "Tracking: Observations" or "Tracking: Kills")
        frame.brightness:Display(journal:GetLocationMapBrightness())
        applyBrightness()
    end
    local function build()
        if frame then return end
        local book=getBook and getBook() or UIParent
        frame=CreateFrame("Frame","AzerothFieldbookCreatureLocations",book,"BackdropTemplate")
        -- Keep 24px between the panel and either the divider edge (309) or book edge (960).
        frame:SetPoint("TOPLEFT",book,"TOPLEFT",333,-78);frame:SetSize(603,636)
        frame:SetFrameLevel(book:GetFrameLevel()+30);frame:EnableMouse(true)
        frame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=20})
        frame.paper=frame:CreateTexture(nil,"BACKGROUND")
        frame.paper:SetPoint("TOPLEFT",6,-6);frame.paper:SetPoint("BOTTOMRIGHT",-6,6)
        frame.paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        frame.paper:SetDesaturated(true)
        label(frame,"Locations",18,-16,520,"GameFontNormalLarge")
        frame.creature=label(frame,"",18,-40,558,"GameFontNormal")
        frame.creature:SetWordWrap(false)
        frame.zoneName=label(frame,"",18,-66,558,"GameFontHighlight")
        frame.zoneButton=ns.FieldbookUI.MenuButton(frame,"Select zone",16,-60,420,function()
            renderMenu();frame.menu:SetShown(not frame.menu:IsShown())
        end)
        frame.currentZone=ns.FieldbookUI.Button(frame,"Current Zone",444,-60,132,function()
            local current=ns.CreatureLocations.CurrentMap()
            if not current then return end
            currentZone=current;zoneKey=key(current);render(true)
        end)
        frame.map=CreateFrame("Frame",nil,frame)
        frame.map:SetPoint("TOP",frame,"TOP",0,-92);frame.map:SetSize(WIDTH,HEIGHT)
        ns.CreatureLocations.InstallMapNavigation(frame.map,function() return displayedMapID end,function(id,name)
            currentZone={mapID=id,name=name};zoneKey=key(currentZone);render(true)
        end)

        frame.playerCoordinates=label(frame.map,"Player coordinates unavailable",0,0,250)
        frame.playerCoordinates:ClearAllPoints()
        frame.playerCoordinates:SetPoint("BOTTOMLEFT",frame.map,"BOTTOMLEFT",8,29)
        frame.playerCoordinates:SetTextColor(0.55,0.57,0.57)
        local coordinateFont,coordinateSize=frame.playerCoordinates:GetFont()
        frame.playerCoordinates:SetFont(coordinateFont,coordinateSize,"OUTLINE")
        frame.playerCoordinates:SetShadowColor(0,0,0,1);frame.playerCoordinates:SetShadowOffset(1,-1)
        frame.playerArrow=frame.map:CreateTexture(nil,"OVERLAY",nil,7)
        frame.playerArrow:SetSize(18,18)
        frame.playerArrow:SetTexture("Interface\\Minimap\\MinimapArrow")
        frame.playerArrow:Hide()
        frame.empty=label(frame.map,"",0,0,596,"GameFontHighlight")
        frame.empty:ClearAllPoints();frame.empty:SetPoint("CENTER",frame.map,"CENTER",0,0)
        frame.empty:SetJustifyH("CENTER");frame.empty:SetHeight(60)
        frame.status=label(frame,"",18,-476,558);frame.status:SetHeight(36);frame.status:SetWordWrap(true)
        frame.legend=label(frame,"",18,-522,558);frame.legend:SetTextColor(0.45,0.45,0.45);frame.legend:SetHeight(36);frame.legend:SetWordWrap(true)
        frame.brightness=ns.MapBrightness:Attach(frame.map,function() return journal:GetLocationMapBrightness() end,
            function(value) journal:SetLocationMapBrightness(value) end,applyBrightness)
        frame.brightnessValue=frame.brightness.valueLabel
        frame.trackingMode=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate"); if ns.TextSize then ns.TextSize:StyleControl(frame.trackingMode) end
        frame.trackingMode:SetPoint("TOPLEFT",376,-582);frame.trackingMode:SetSize(200,24)
        frame.trackingMode:SetScript("OnClick",function()
            tipLeave()
            journal:SetLocationTrackingMode(mode()=="kills" and "observations" or "kills")
            render(true)
        end)
        frame.trackingMode:SetScript("OnEnter",function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_TOP")
                GameTooltip:SetText("Location tracking")
                GameTooltip:AddLine("Switch between violet kill positions and cyan observation positions. Both are recorded while you explore.",1,1,1,true)
                GameTooltip:Show()
            end
        end)
        frame.trackingMode:SetScript("OnLeave",tipLeave)
        frame.trackingMode:SetScript("OnHide",tipLeave)
        frame.menu=CreateFrame("Frame",nil,frame,"BackdropTemplate")
        frame.menu:SetPoint("TOPLEFT",frame.zoneButton,"BOTTOMLEFT",0,0);frame.menu:SetSize(420,226)
        frame.menu:SetFrameLevel(frame:GetFrameLevel()+20);frame.menu:EnableMouse(true)
        frame.menu:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
        frame.menu.paper=frame.menu:CreateTexture(nil,"BACKGROUND")
        frame.menu.paper:SetPoint("TOPLEFT",3,-3);frame.menu.paper:SetPoint("BOTTOMRIGHT",-3,3)
        frame.menu.paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        frame.menu.paper:SetDesaturated(true)
        frame.menu.rows={}
        for i=1,8 do
            local row=CreateFrame("Button",nil,frame.menu,"UIPanelButtonTemplate"); if ns.TextSize then ns.TextSize:StyleControl(row) end
            row:SetPoint("TOPLEFT",8,-8-(i-1)*23);row:SetSize(404,22)
            row:SetScript("OnClick",function(self) zoneKey=key(self.zone);render(true) end)
            frame.menu.rows[i]=row
        end
        for _,spec in ipairs({{"previous","Previous",8,-8},{"next","Next",216,8}}) do
            local b=CreateFrame("Button",nil,frame.menu,"UIPanelButtonTemplate"); if ns.TextSize then ns.TextSize:StyleControl(b) end
            b:SetSize(196,22);b:SetPoint("TOPLEFT",spec[3],-197);b:SetText(spec[2])
            local step=spec[4];b:SetScript("OnClick",function() menuOffset=menuOffset+step;renderMenu() end)
            frame.menu[spec[1]]=b
        end
        frame.menu:Hide()
        frame.zoneButton:SetScript("OnClick",function() renderMenu();frame.menu:SetShown(not frame.menu:IsShown()) end)
        frame:SetScript("OnShow",function() if controller.visibilityCallback then controller.visibilityCallback(true) end end)
        frame:SetScript("OnHide",function()
            frame.menu:Hide();tipLeave()
            if controller.visibilityCallback then controller.visibilityCallback(false) end
        end)
        local elapsed,playerElapsed=0,0
        frame:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt;playerElapsed=playerElapsed+dt
            if elapsed>=0.5 then elapsed=0;render() end
            if playerElapsed>=0.05 then playerElapsed=0;updatePlayer() end
        end)
        frame:RegisterEvent("MAP_EXPLORATION_UPDATED")
        frame:SetScript("OnEvent",function() render(true) end)
        book:HookScript("OnHide",function() frame:Hide() end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookCreatureLocations" end
        frame:Hide()
    end
    local function defaultTrackingMode(id)
        local entry=journal.entries[id]
        local function hasPositions(field)
            for _,map in pairs(entry and entry[field] or {}) do
                if map.points and next(map.points) then return true end
            end
            return false
        end
        journal:SetLocationTrackingMode(not hasPositions("killLocations") and hasPositions("observationLocations")
            and "observations" or "kills")
    end
    function controller:SetCreature(id)
        if selected~=id then
            zoneKey=nil;menuOffset=0
            defaultTrackingMode(id)
        end
        selected=id;render()
    end
    function controller:Refresh() render() end
    function controller:GetFrame() return frame end
    function controller:Hide() if frame then frame:Hide() end end
    function controller:IsShown() return frame and frame:IsShown() or false end
    function controller:Open(id)
        build();defaultTrackingMode(id);self:SetCreature(id);frame:Show();render(true)
        frame:Raise()
    end
    function controller:Toggle(id) if self:IsShown() then self:Hide() else self:Open(id) end end
    function controller:SetVisibilityCallback(callback) self.visibilityCallback=callback;callback(self:IsShown()) end
    return controller
end
