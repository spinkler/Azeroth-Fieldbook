local _,ns=...

-- Display only the player's recorded interaction positions, never inferred nodes.
-- Native frames cannot be reclaimed during a session. Limit display pools;
-- the journal keeps all saved positions regardless of the display budget.
local WORLD_PIN_LIMIT, MINIMAP_PIN_LIMIT = 512, 128
local function finite(v,low,high)
    return not (issecretvalue and issecretvalue(v)) and type(v)=="number" and v>=low and v<=high
end
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end
function ns.CreateGatheringMapPins(journal)
    local controller={worldPins={},miniPins={}}
    local cache,revision={},nil
    local function recentFirst(a,b)
        if a.point.seenAt~=b.point.seenAt then return a.point.seenAt>b.point.seenAt end
        if a.entry.id~=b.entry.id then return a.entry.id<b.entry.id end
        if a.point.x~=b.point.x then return a.point.x<b.point.x end
        return a.point.y<b.point.y
    end
    local function nearestFirst(a,b)
        if a.distance~=b.distance then return a.distance<b.distance end
        return recentFirst(a,b)
    end
    local function nodes(mapID,view)
        if revision~=journal.revision then cache={};revision=journal.revision end
        local current=cache[view]
        if not current or current.mapID~=mapID then
            -- Retain at most the two maps being displayed, sharing the same
            -- list when world map and minimap show the same zone.
            for _,other in pairs(cache) do
                if other.mapID==mapID then cache[view]=other;return other.nodes end
            end
            local result={}
            for _,entry in pairs(journal.entries) do
                local location=entry.locations[mapID]
                for _,point in pairs(location and location.points or {}) do
                    result[#result+1]={entry=entry,point=point}
                end
            end
            table.sort(result,recentFirst)
            current={mapID=mapID,nodes=result};cache[view]=current
        end
        return current.nodes
    end
    local function hide(pool,first)
        for i=first or 1,#pool do pool[i]:Hide();pool[i].node=nil end
    end
    local function release(view,pool)
        cache[view]=nil;hide(pool)
    end
    local function pin(pool,index,parent,node,x,y,anchor,scale,level)
        local p=pool[index]
        if not p then
            p=CreateFrame("Frame",nil,parent)
            ns.StyleGatheringDot(p)
            p:SetScript("OnEnter",function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(self.node.entry.name)
                GameTooltip:AddLine(string.format("Recorded position: %.1f, %.1f",self.node.point.x/100,self.node.point.y/100),1,1,1)
                GameTooltip:AddLine("Approximate interaction location; the node may be depleted.",0.75,0.8,0.8,true)
                GameTooltip:Show()
            end)
            local function leave(self)
                if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end
            p:SetScript("OnLeave",leave);p:SetScript("OnHide",leave);pool[index]=p
        end
        scale=scale or 1
        p:SetParent(parent);p:SetFrameLevel(level or parent:GetFrameLevel()+10)
        p:SetScale(scale)
        p.node=node
        if node.entry.kind=="mineral" then p.texture:SetVertexColor(1,0.78,0.18,1)
        else p.texture:SetVertexColor(0.3,1,0.35,1) end
        p:ClearAllPoints();p:SetPoint("CENTER",parent,anchor,x/scale,y/scale);p:Show()
    end
    function controller:RefreshWorld()
        local map=WorldMapFrame
        local canvas=map and journal:ShowNodesOn("worldMap") and map:IsShown() and read(map.GetCanvas,map)
        local id=canvas and read(map.GetMapID,map)
        if not finite(id,1,2147483647) then release("world",self.worldPins);return end
        local width,height=canvas:GetWidth(),canvas:GetHeight()
        if not finite(width,1,100000) or not finite(height,1,100000) then release("world",self.worldPins);return end
        -- The map canvas is terrain-sized and scaled down to fit the window.
        -- Native pins counter-scale their artwork and divide anchor offsets by
        -- that pin scale. Without this a six-pixel dot can become subpixel.
        local canvasScale=read(map.GetCanvasScale,map) or read(canvas.GetScale,canvas)
        local scale=finite(canvasScale,0.0001,1000) and 1/canvasScale or 1
        -- DEFAULT is below Blizzard's exploration and fog pins. Use the normal
        -- location-icon layer: lower layers can hide the art without blocking
        -- this frame's mouse input, leaving an apparently invisible tooltip pin.
        local manager=read(map.GetPinFrameLevelsManager,map)
        local level=manager and read(manager.GetValidFrameLevel,manager,"PIN_FRAME_LEVEL_AREA_POI")
        if not finite(level,0,65535) then level=nil end
        local visible=nodes(id,"world")
        local count=math.min(WORLD_PIN_LIMIT,#visible)
        for i=1,count do
            local node=visible[i]
            pin(self.worldPins,i,canvas,node,node.point.x/10000*width,-node.point.y/10000*height,"TOPLEFT",scale,level)
        end
        hide(self.worldPins,count+1)
    end
    function controller:RefreshMinimap()
        local mini=Minimap
        if not mini or not mini:IsShown() or not journal:ShowNodesOn("minimap") then release("minimap",self.miniPins);return end
        local map=ns.CreatureLocations.CurrentMap()
        local position=map and read(C_Map.GetPlayerMapPosition,map.mapID,"player")
        local radius=read(C_Minimap and C_Minimap.GetViewRadius)
        if not map or not map.width or not map.height or type(position)~="table"
            or not finite(position.x,0,1) or not finite(position.y,0,1) or not finite(radius,1,100000) then
            release("minimap",self.miniPins);return
        end
        local facing=0
        local rotating=read(GetCVar,"rotateMinimap")=="1"
        if rotating and read(C_Minimap and C_Minimap.IsRotateMinimapIgnored)~=true then
            facing=read(GetPlayerFacing)
            if not finite(facing,-100,100) then release("minimap",self.miniPins);return end
        end
        local width,height=mini:GetWidth()/2,mini:GetHeight()/2
        local cos,sin=math.cos(facing),math.sin(facing)
        local nearby={}
        local inset=1-8/math.max(8,math.min(width,height))
        for _,node in ipairs(nodes(map.mapID,"minimap")) do
            local east=(node.point.x/10000-position.x)*map.width
            local north=(position.y-node.point.y/10000)*map.height
            local x,y=(east*cos+north*sin)/radius,(north*cos-east*sin)/radius
            -- Keep the complete icon inside the circular map, never clamp distant nodes to its edge.
            local distance=x*x+y*y
            if distance<=inset*inset then
                node.miniX,node.miniY,node.distance=x*width,y*height,distance
                nearby[#nearby+1]=node
            end
        end
        table.sort(nearby,nearestFirst)
        local count=math.min(MINIMAP_PIN_LIMIT,#nearby)
        for i=1,count do
            local node=nearby[i]
            pin(self.miniPins,i,mini,node,node.miniX,node.miniY,"CENTER")
        end
        hide(self.miniPins,count+1)
    end
    function controller:Refresh() self:RefreshWorld();self:RefreshMinimap() end
    if ns.RegisterWorldMapLayer then
        ns.RegisterWorldMapLayer("Nodes",function() return journal:ShowNodesOn("worldMap") end,function(on)
            journal:SetShowNodesOn("worldMap",on);controller:RefreshWorld()
        end,function() return not journal.readOnly end)
    end
    controller.frame=CreateFrame("Frame")
    local elapsed=0
    controller.frame:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed>=0.1 then elapsed=0;controller:Refresh() end
    end)
    return controller
end
