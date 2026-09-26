local _, ns = ...

function ns.CreateCreatureLocationsWindow(journal,getBook)
    local controller={}
    local frame,selected,zoneKey,revision,visibleKey
    local zones,tiles,exploration,fills,dots,glows={},{},{},{},{},{}
    local menuOffset=0
    local WIDTH,HEIGHT=640,426
    local function public(v) return not (issecretvalue and issecretvalue(v)) end
    local function number(v) return public(v) and type(v)=="number" and v>0 and v<=100000 end
    local function read(fn,...)
        if type(fn)~="function" then return end
        local ok,v=pcall(fn,...);if ok and public(v) then return v end
    end
    local function label(parent,text,x,y,w,font)
        local t=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
        t:SetPoint("TOPLEFT",x,y);t:SetWidth(w);t:SetJustifyH("LEFT");t:SetText(text);return t
    end
    local function key(zone) return zone.mapID and ("map:"..zone.mapID) or ("name:"..zone.name) end
    local function hide(pool) for _,item in ipairs(pool) do item:Hide() end end
    local function tipLeave() if GameTooltip then GameTooltip:Hide() end end
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
                    t:SetColorTexture(1,0.55,1,style[2]);t:SetBlendMode("ADD")
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
            texture:SetSize(tw,th);texture:SetColorTexture(0.9,0.18,1,0.46)
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
                    dot.texture=dot:CreateTexture(nil,"OVERLAY");dot.texture:SetAllPoints()
                    dot.texture:SetTexture("Interface\\COMMON\\Indicator-Yellow")
                    dot:EnableMouse(true)
                    dot:SetScript("OnEnter",function(self)
                        if GameTooltip then
                            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                            GameTooltip:SetText(self.location.approximate and "Approximate kill location" or "Creature kill location")
                            GameTooltip:AddLine(string.format("%.1f, %.1f",self.location.u*100,self.location.v*100),1,1,1)
                            if self.location.approximate then GameTooltip:AddLine("Your position when the kill was credited.",0.7,0.7,0.7) end
                            GameTooltip:Show()
                        end
                    end)
                    dot:SetScript("OnLeave",tipLeave);dot:SetScript("OnHide",tipLeave)
                end
                dot.location=p;dot:ClearAllPoints();dot:SetPoint("CENTER",frame.map,"TOPLEFT",p.u*w,-p.v*h)
                dot.texture:SetVertexColor(1,p.approximate and 0.7 or 0.3,0.1);dot:Show()
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
        local signature=tostring(selected)..":"..tostring(zoneKey)
        if not force and revision==journal.revision and visibleKey==signature then return end
        revision=journal.revision
        local brightness=0.504*journal:GetBackgroundBrightness()*0.34
        frame.paper:SetVertexColor(brightness,brightness,brightness)
        frame.menu.paper:SetVertexColor(brightness,brightness,brightness)
        zones=ns.CreatureLocations.Zones(entry)
        local chosen
        for _,zone in ipairs(zones) do if key(zone)==zoneKey then chosen=zone;break end end
        if not chosen then
            local current=ns.CreatureLocations.CurrentMap()
            for _,zone in ipairs(zones) do if current and zone.mapID==current.mapID then chosen=zone;break end end
            chosen=chosen or zones[1]
        end
        zoneKey=chosen and key(chosen)
        visibleKey=tostring(selected)..":"..tostring(zoneKey)
        frame.creature:SetText(entry and (journal:GetCreatureName(selected) or "Creature") or "Select a creature in the Bestiary.")
        frame.zoneName:SetText(chosen and chosen.name or "No zones recorded")
        frame.zoneName:SetShown(#zones<=1)
        frame.zoneButton:SetShown(#zones>1);frame.zoneButton:SetText((chosen and chosen.name or "Select zone").."  v")
        frame.menu:Hide();renderMenu()
        local available=drawMap(chosen and chosen.mapID)
        hide(fills);hide(dots);hide(glows)
        local count,approx,triangles=0,0,0
        if available then count,approx,triangles=drawSamples(chosen.data) end
        frame.empty:SetShown(not available or count==0)
        frame.empty:SetText(not available and (chosen and "Zone map unavailable. Visit this zone and observe a creature to link its map." or "No locations recorded yet.")
            or "No mapped kills yet. Locations are collected from new credited kills.")
        frame.status:SetText(count>0 and (count.." mapped positions • "..approx.." approximate"..(triangles>0 and " • nearby groups shaded" or ""))
            or "Earlier kill totals do not contain coordinates.")
        if count>=3 and chosen.data and (not chosen.data.width or not chosen.data.height) then
            frame.status:SetText(count.." mapped positions • "..approx.." approximate • map scale unavailable; dots only")
        end
        frame.legend:SetText("Orange dots and violet areas mark kill locations. Nearby points join within 180 yards.\nApproximate positions use your location when the kill was credited.")
        frame.brightness:SetValue(journal:GetLocationMapBrightness())
        applyBrightness()
    end
    local function build()
        if frame then return end
        frame=CreateFrame("Frame","AzerothFieldbookCreatureLocations",UIParent,"BackdropTemplate")
        frame.afbPreferBookEdge=true;frame.afbAnchorRule="right";frame.afbAlignBookTop=true
        frame:SetSize(676,628);frame:SetFrameStrata("DIALOG");frame:SetClampedToScreen(true)
        local book=getBook and getBook()
        if book then frame:SetPoint("TOPLEFT",book,"TOPRIGHT",6,0) else frame:SetPoint("CENTER") end
        frame:SetScale(math.min(1,(UIParent:GetWidth()-30)/(676*1.5),(UIParent:GetHeight()-30)/(628*1.5)))
        frame:SetMovable(true);frame:EnableMouse(true);frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart",frame.StartMoving);frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
        frame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=20})
        frame.paper=frame:CreateTexture(nil,"BACKGROUND")
        frame.paper:SetPoint("TOPLEFT",6,-6);frame.paper:SetPoint("BOTTOMRIGHT",-6,6)
        frame.paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        frame.paper:SetDesaturated(true)
        label(frame,"Locations",18,-16,600,"GameFontNormalLarge")
        frame.creature=label(frame,"",18,-40,640,"GameFontNormal")
        frame.creature:SetWordWrap(false)
        frame.zoneName=label(frame,"",18,-66,640,"GameFontHighlight")
        frame.zoneButton=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
        frame.zoneButton:SetSize(420,24);frame.zoneButton:SetPoint("TOPLEFT",16,-60)
        frame.map=CreateFrame("Frame",nil,frame)
        frame.map:SetPoint("TOP",frame,"TOP",0,-92);frame.map:SetSize(WIDTH,HEIGHT)
        frame.empty=label(frame.map,"",0,0,596,"GameFontHighlight")
        frame.empty:ClearAllPoints();frame.empty:SetPoint("CENTER",frame.map,"CENTER",0,0)
        frame.empty:SetJustifyH("CENTER");frame.empty:SetHeight(60)
        frame.status=label(frame,"",18,-524,640)
        frame.legend=label(frame,"",18,-545,640);frame.legend:SetTextColor(0.65,0.65,0.65);frame.legend:SetHeight(29)
        label(frame,"Map brightness",18,-585,150)
        frame.brightness=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate")
        frame.brightness:SetPoint("TOPLEFT",180,-584);frame.brightness:SetSize(180,16)
        local brightnessTrack=frame.brightness:CreateTexture(nil,"BACKGROUND")
        brightnessTrack:SetPoint("TOPLEFT",2,-4);brightnessTrack:SetPoint("BOTTOMRIGHT",-2,4)
        brightnessTrack:SetColorTexture(0.045,0.032,0.018,1)
        frame.brightness:SetMinMaxValues(0.2,1);frame.brightness:SetValueStep(0.05);frame.brightness:SetObeyStepOnDrag(true)
        frame.brightnessValue=label(frame,"",374,-585,80)
        frame.brightness:SetScript("OnValueChanged",function(_,value)
            journal:SetLocationMapBrightness(value);applyBrightness()
        end)
        local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
        close:SetPoint("TOPRIGHT",-3,-3);close:SetScript("OnClick",function() frame:Hide() end)
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
            local row=CreateFrame("Button",nil,frame.menu,"UIPanelButtonTemplate")
            row:SetPoint("TOPLEFT",8,-8-(i-1)*23);row:SetSize(404,22)
            row:SetScript("OnClick",function(self) zoneKey=key(self.zone);render(true) end)
            frame.menu.rows[i]=row
        end
        for _,spec in ipairs({{"previous","Previous",8,-8},{"next","Next",216,8}}) do
            local b=CreateFrame("Button",nil,frame.menu,"UIPanelButtonTemplate")
            b:SetSize(196,22);b:SetPoint("TOPLEFT",spec[3],-197);b:SetText(spec[2])
            local step=spec[4];b:SetScript("OnClick",function() menuOffset=menuOffset+step;renderMenu() end)
            frame.menu[spec[1]]=b
        end
        frame.menu:Hide()
        frame.zoneButton:SetScript("OnClick",function() renderMenu();frame.menu:SetShown(not frame.menu:IsShown()) end)
        frame:SetScript("OnShow",function() if controller.visibilityCallback then controller.visibilityCallback(true) end end)
        frame:SetScript("OnHide",function()
            frame:StopMovingOrSizing();frame.menu:Hide();tipLeave()
            if controller.visibilityCallback then controller.visibilityCallback(false) end
        end)
        local elapsed=0
        frame:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt;if elapsed>=0.5 then elapsed=0;render() end end)
        frame:RegisterEvent("MAP_EXPLORATION_UPDATED")
        frame:SetScript("OnEvent",function() render(true) end)
        if ns.WindowFocus then ns.WindowFocus:Register(frame) end
        if ns.UIScale then ns.UIScale:Register(frame,"AzerothFieldbookCreatureLocations") end
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookCreatureLocations" end
        frame:Hide()
    end
    function controller:SetCreature(id)
        if selected~=id then zoneKey=nil;menuOffset=0 end
        selected=id;render()
    end
    function controller:Refresh() render() end
    function controller:GetFrame() return frame end
    function controller:Hide() if frame then frame:Hide() end end
    function controller:IsShown() return frame and frame:IsShown() or false end
    function controller:Open(id)
        build();self:SetCreature(id);frame:Show();render(true)
        frame:Raise()
    end
    function controller:Toggle(id) if self:IsShown() then self:Hide() else self:Open(id) end end
    function controller:SetVisibilityCallback(callback) self.visibilityCallback=callback;callback(self:IsShown()) end
    return controller
end
