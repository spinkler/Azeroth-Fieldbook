local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end

-- Shared marker art for the journal, world map and minimap.
function ns.StyleGatheringDot(dot)
    dot:SetSize(6,6);dot:EnableMouse(true)
    dot:SetHitRectInsets(-2,-2,-2,-2)
    dot.border=dot:CreateTexture(nil,"ARTWORK")
    dot.border:SetAllPoints();dot.border:SetVertexColor(0.05,0.05,0.05,1)
    dot.texture=dot:CreateTexture(nil,"OVERLAY")
    dot.texture:SetPoint("TOPLEFT",1,-1);dot.texture:SetPoint("BOTTOMRIGHT",-1,1)
    for _,texture in ipairs({dot.border,dot.texture}) do
        -- The image carries the circular alpha for both the border and fill.
        texture:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\GatheringDot.tga","CLAMP","CLAMP","TRILINEAR")
    end
end

function ns.CreateGatheringLocationsWindow(journal,getBook)
    -- Keep the Bestiary map presentation, with a single interaction-only layer.
    local controller={}
    local frame,selected,zoneKey,revision,visibleKey,currentZone
    local zones,tiles,exploration,dots={},{},{},{}
    local menuOffset=0
    local displayedMapID
    local WIDTH,HEIGHT=558,372
    local palettes={herb={0.3,1,0.35},mineral={1,0.78,0.18}}
    local function colour(texture,alpha)
        local entry=journal.entries[selected]
        local c=palettes[entry and entry.kind or "herb"]
        texture:SetVertexColor(c[1],c[2],c[3],alpha)
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
        hide(dots)
        -- Resource nodes are discrete interaction samples. Never build the
        -- Bestiary's triangulated coverage areas or connect nearby positions.
        local points={}
        for _,p in pairs(map and map.points or {}) do points[#points+1]=p end
        table.sort(points,function(a,b) if a.x~=b.x then return a.x<b.x end;return a.y<b.y end)
        for i,p in ipairs(points) do
            local dot=dots[i]
            if not dot then
                dot=CreateFrame("Frame",nil,frame.map)
                ns.StyleGatheringDot(dot)
                dot:SetScript("OnMouseUp",function(_,button) frame.map:Navigate(button) end)
                dot:SetScript("OnEnter",function(self)
                    if GameTooltip then
                        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                        GameTooltip:SetText(journal:GetName(selected) or "Gathering interaction")
                        GameTooltip:AddLine(string.format("%.1f, %.1f",self.location.x/100,self.location.y/100),1,1,1)
                        GameTooltip:AddLine("Your position while gathering; approximate node location.",1,1,1,true)
                        GameTooltip:Show()
                    end
                end)
                dot:SetScript("OnLeave",tipLeave);dot:SetScript("OnHide",tipLeave)
                dots[i]=dot
            end
            dot.location=p;dot:ClearAllPoints()
            dot:SetPoint("CENTER",frame.map,"TOPLEFT",p.x/10000*frame.map:GetWidth(),-p.y/10000*frame.map:GetHeight())
            colour(dot.texture,1);dot:Show()
        end
        return #points
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
        local signature=tostring(selected)..":"..tostring(zoneKey)
        if not force and revision==journal.revision and visibleKey==signature then return end
        revision=journal.revision
        local brightness=0.504*journal:GetBackgroundBrightness()*0.34
        frame.paper:SetVertexColor(brightness,brightness,brightness)
        frame.menu.paper:SetVertexColor(brightness,brightness,brightness)
        zones=journal:GetLocationZones(selected)
        local chosen
        for _,zone in ipairs(zones) do if key(zone)==zoneKey then chosen=zone;break end end
        if not chosen and currentZone and key(currentZone)==zoneKey then chosen=currentZone end
        if not chosen then
            local current=ns.CreatureLocations.CurrentMap()
            for _,zone in ipairs(zones) do if current and zone.mapID==current.mapID then chosen=zone;break end end
            chosen=chosen or zones[1]
        end
        zoneKey=chosen and key(chosen)
        visibleKey=tostring(selected)..":"..tostring(zoneKey)
        frame.creature:SetText(entry and (journal:GetName(selected) or "Resource") or "Select a herb or mineral.")
        frame.zoneName:SetText(chosen and chosen.name or "No zones recorded")
        frame.zoneName:Hide()
        frame.zoneButton:Show();frame.zoneButton:SetEnabled(#zones>0);frame.zoneButton:SetText(chosen and chosen.name or "Select zone")
        frame.menu:Hide();renderMenu()
        local available=drawMap(chosen and chosen.mapID)
        displayedMapID=available and chosen.mapID or nil
        frame.map.regionHighlight:Hide()
        updatePlayer()
        hide(dots)
        local count=available and drawSamples(chosen.data) or 0
        frame.empty:SetShown(not available)
        frame.empty:SetText(chosen and "Zone map unavailable." or "No locations recorded yet.")
        frame.status:SetText(count>0 and (count.." interaction positions • approximate node locations")
            or "No mapped positions. Interact with this herb or mineral to record coordinates.")
        if count>0 then frame.status:SetTextColor(1,1,1) else frame.status:SetTextColor(1,0.2,0.2) end
        frame.legend:SetText((entry and entry.kind=="mineral" and "Gold" or "Green")..
            ": your position while gathering. Each marker comes from an interaction.")
        frame.brightness:Display(journal:GetLocationMapBrightness())
        applyBrightness()
    end
    local function build()
        if frame then return end
        local book=getBook()
        frame=CreateFrame("Frame","AzerothFieldbookGatheringLocations",book,"BackdropTemplate")
        -- Keep 24px between the panel and either the divider edge (309) or book edge (960).
        frame:SetPoint("TOPLEFT",book,"TOPLEFT",333,-87);frame:SetSize(603,627)
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
        frame.empty=label(frame.map,"",0,0,534,"GameFontHighlight")
        frame.empty:ClearAllPoints();frame.empty:SetPoint("CENTER",frame.map,"CENTER",0,0)
        frame.empty:SetJustifyH("CENTER");frame.empty:SetHeight(60)
        frame.status=label(frame,"",18,-476,558);frame.status:SetHeight(36);frame.status:SetWordWrap(true)
        frame.legend=label(frame,"",18,-522,558);frame.legend:SetTextColor(0.45,0.45,0.45);frame.legend:SetHeight(36);frame.legend:SetWordWrap(true)
        frame.brightness=ns.MapBrightness:Attach(frame.map,function() return journal:GetLocationMapBrightness() end,
            function(value) journal:SetLocationMapBrightness(value) end,applyBrightness)
        frame.brightnessValue=frame.brightness.valueLabel
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
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookGatheringLocations" end
        book:HookScript("OnHide",function() frame:Hide() end)
        frame:Hide()
    end
    function controller:SetResource(id)
        if selected~=id then zoneKey=nil;menuOffset=0 end
        selected=id;render()
    end
    function controller:Refresh() render() end
    function controller:GetFrame() return frame end
    function controller:Hide() if frame then frame:Hide() end end
    function controller:IsShown() return frame and frame:IsShown() or false end
    function controller:Open(id,mapID)
        build();self:SetResource(id)
        if mapID then zoneKey="map:"..mapID end
        frame:Show();render(true)
        frame:Raise()
    end
    function controller:Toggle(id) if self:IsShown() then self:Hide() else self:Open(id) end end
    function controller:SetVisibilityCallback(callback) self.visibilityCallback=callback;callback(self:IsShown()) end
    return controller
end
