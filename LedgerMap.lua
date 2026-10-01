local _, ns = ...
local L=ns.Ledger
-- Remembered merchant locations only. No map position is invented for contacts
-- whose sightings have a zone name but no recorded coordinates.
function ns.CreateLedgerWorldPins(journal)
    local controller={pins={}}
    local world,revision,mapID,rows
    local function hide(first)
        for i=first or 1,#controller.pins do controller.pins[i]:Hide();controller.pins[i].row=nil end
    end
    local function read(fn,...)
        if type(fn)~="function" then return end
        local ok,value=pcall(fn,...)
        if ok and not (issecretvalue and issecretvalue(value)) then return value end
    end
    local function number(n,low,high)
        return not (issecretvalue and issecretvalue(n)) and type(n)=="number" and n>=low and n<=high
    end
    function controller:Refresh()
        if not world or not world:IsShown() or journal.state.showMerchantsOnWorldMap~=true then hide();return end
        local canvas=read(world.GetCanvas,world);local id=read(world.GetMapID,world)
        if not canvas or not number(id,1,2147483647) then hide();return end
        local width,height=canvas:GetWidth(),canvas:GetHeight()
        local scale=read(world.GetCanvasScale,world) or read(canvas.GetScale,canvas) or 1
        if not number(width,1,100000) or not number(height,1,100000) or not number(scale,0.0001,1000) then hide();return end
        if revision~=journal.revision or mapID~=id then
            rows={};revision=journal.revision;mapID=id
            for _,entry in pairs(journal.db.contacts) do
                if journal:Roles(entry).merchant then
                    for _,p in ipairs(journal:Locations(entry)) do
                        if p.mapID==id and number(p.x,0,10000) and number(p.y,0,10000) then
                            rows[#rows+1]={entry=entry,point=p}
                            -- Locations prefers personal evidence, then recency.
                            -- One marker per merchant on each map avoids trails.
                            break
                        end
                    end
                end
            end
            table.sort(rows,function(a,b)
                if a.point.last~=b.point.last then return a.point.last>b.point.last end
                return a.entry.id<b.entry.id
            end)
        end
        local manager=read(world.GetPinFrameLevelsManager,world)
        local level=manager and read(manager.GetValidFrameLevel,manager,"PIN_FRAME_LEVEL_AREA_POI")
        local count=math.min(512,#rows)
        for i=1,count do
            local pin=self.pins[i]
            if not pin then
                pin=CreateFrame("Frame",nil,canvas);pin:SetSize(14,14);pin:EnableMouse(true)
                pin.icon=pin:CreateTexture(nil,"ARTWORK");pin.icon:SetAllPoints()
                pin.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
                pin:SetScript("OnEnter",function(self)
                    if not self.row or not GameTooltip then return end
                    local p=self.row.point
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(L.Safe(self.row.entry.name))
                    GameTooltip:AddLine(L.Safe(L.PositionLabel(p)),1,1,1,true)
                    GameTooltip:AddLine((p.reported and "Reported by " or "Personally observed by ")..L.Safe(p.origin.source).." • "..L.Date(p.last),0.75,0.8,1,true)
                    GameTooltip:AddLine("Remembered merchant location; the NPC may have moved.",1,0.82,0.14,true)
                    GameTooltip:Show()
                end)
                local function leave(self) if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end
                pin:SetScript("OnLeave",leave);pin:SetScript("OnHide",leave);self.pins[i]=pin
            end
            local row=rows[i];pin.row=row;pin:SetParent(canvas)
            pin:SetFrameLevel(number(level,0,65535) and level or canvas:GetFrameLevel()+10)
            pin:SetScale(1/scale);pin:ClearAllPoints()
            pin:SetPoint("CENTER",canvas,"TOPLEFT",row.point.x/10000*width*scale,-row.point.y/10000*height*scale)
            pin.icon:SetVertexColor(row.point.reported and 0.55 or 1,row.point.reported and 0.7 or 1,1)
            pin:Show()
        end
        hide(count+1)
    end
    controller.frame=CreateFrame("Frame");controller.frame:Hide()
    local elapsed=0
    controller.frame:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed>=0.2 then elapsed=0;controller:Refresh() end
    end)
    function controller:Attach()
        if world or not WorldMapFrame or type(WorldMapFrame.GetCanvas)~="function" then return end
        world=WorldMapFrame
        world:HookScript("OnShow",function() controller.frame:Show();controller:Refresh() end)
        world:HookScript("OnHide",function() controller.frame:Hide();hide() end)
        if world:IsShown() then controller.frame:Show();controller:Refresh() end
        controller.loader:UnregisterEvent("ADDON_LOADED")
    end
    controller.loader=CreateFrame("Frame");controller.loader:RegisterEvent("ADDON_LOADED")
    controller.loader:SetScript("OnEvent",function() controller:Attach() end)
    if ns.RegisterWorldMapLayer then
        ns.RegisterWorldMapLayer("Merchants",function() return journal.state.showMerchantsOnWorldMap==true end,function(on)
            if journal.readOnly then return end
            journal.state.showMerchantsOnWorldMap=on
        end,function() return not journal.readOnly end,function() controller:Attach();controller:Refresh() end)
    end
    controller:Attach()
    return controller
end
function ns.CreateLedgerMap(parent,journal,getSelection,onSighting)
    local adapter={}
    local function points()
        local id,index=getSelection();local e=journal:Get(id);local rows={}
        if not e then return rows end
        for i,p in ipairs(journal:Locations(e)) do
            local v=L.Copy(p);v.id=tostring(i);v.name=e.name;v.category="other";v.stops={};v.contact=e;rows[#rows+1]=v
        end
        return rows,index
    end
    function adapter:Get(id) for _,p in ipairs(points()) do if p.id==id then return p end end end
    function adapter:List(_,mapID)
        local out={};for _,p in ipairs(points()) do if p.mapID==mapID then out[#out+1]=p end end;return out
    end
    function adapter:Layer() return true end
    function adapter:WeatherText() return "" end
    -- The existing factory supplies exact Atlas geometry, tiles, clipping and
    -- independent pan/zoom/cache state. No Atlas-owned frame or data is borrowed.
    local map=ns.CreateAtlasMap(parent,adapter,function(id) onSighting(tonumber(id)) end,function() end)
    local emptyOverlay=CreateFrame("Frame",nil,map)
    emptyOverlay:SetAllPoints();emptyOverlay:SetFrameLevel(map:GetFrameLevel()+5);emptyOverlay:EnableMouse(false)
    map.emptyShade=emptyOverlay:CreateTexture(nil,"BACKGROUND")
    map.emptyShade:SetAllPoints();map.emptyShade:SetColorTexture(0,0,0,0.48);map.emptyShade:Hide()
    map.empty:SetParent(emptyOverlay);map.empty:ClearAllPoints();map.empty:SetPoint("CENTER",map,"CENTER",0,0)
    local render=map.Render
    function map:Render()
        local _,index=getSelection();local all=points();local selected=all[index or 1]
        local noMap=not selected or not selected.mapID
        local displayed=selected and selected.mapID
        if noMap then
            local current=ns.Atlas.CurrentLocation()
            displayed=current and current.mapID
        end
        render(self,displayed,selected and selected.id)
        self.emptyShade:SetShown(noMap and self.available)
        self.empty:SetWidth(self:GetWidth()-24)
        if noMap then
            self.empty:SetText("No map was recorded for this contact.\nIts services and notes remain available.")
            self.empty:Show()
        end
        for _,pin in ipairs(self.pins or {}) do if pin.group and pin:IsShown() then
            local point=pin.group[1].point
            pin.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
            pin.icon:SetVertexColor(point.reported and 0.55 or 1,point.reported and 0.7 or 1,1)
            pin:SetScript("OnEnter",function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText("Remembered contact locations")
                for i,marker in ipairs(self.group) do
                    if i>8 then break end;local p=marker.point
                    GameTooltip:AddLine(L.Safe(p.contact.name),1,0.82,0.14,true)
                    GameTooltip:AddLine(L.Safe(journal:Sublabel(p.contact)),1,1,1,true)
                    GameTooltip:AddLine(L.Safe(L.PositionLabel(p)),1,1,1,true)
                    GameTooltip:AddLine((p.reported and "Reported by " or "Personally observed by ")..L.Safe(p.origin.source).." • "..L.Date(p.last),0.75,0.8,1,true)
                    if p.reported then GameTooltip:AddLine("Received "..L.Date(p.received),1,1,1,true) end
                end
                GameTooltip:AddLine("Observed locations; the NPC may have moved. Click to select a sighting.",1,0.82,0.14,true);GameTooltip:Show()
            end)
        end end
        return selected
    end
    return map
end
