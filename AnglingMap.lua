local _, ns = ...
local A=ns.Angling

function ns.CreateAnglingMap(parent,journal,onSelect,getFilters,onNavigate)
    -- Adapt data into the already exposed renderer. Its closure owns its tiles,
    -- pins, map cache and player updates; it never needs an Atlas saved variable.
    local adapter={};local selectedID
    local function marker(e)
        return {id=e.id,name=e.name,mapID=e.mapID,zone=e.zone,x=e.x,y=e.y,precision=e.precision,
            last=e.personalLast or e.last,category="other",stops={},transient=e.transient,itemName=e.itemName}
    end
    local function selectedWater(id)
        local e=journal.db.waters[id];local f=getFilters()
        if not e or e.mapPositionHidden or f.knowledge=="reported" then return end
        local latest,position,stamp,itemName
        if f.focusFact then
            latest=journal.db.aggregates[f.focusFact] or journal.db.reported[f.focusFact]
            if not latest or latest.waterID~=e.id then return end
            local item=f.focusItem and latest.items[f.focusItem]
            position=f.focusItem and item and item.lastPosition or (not f.focusItem and latest.lastPosition)
            stamp=item and item.last or latest.last
            itemName=item and journal:Get(f.focusItem).name
            if not A.Position(position) then return end -- a reported/unknown point stays unknown
        else
            for _,row in ipairs(journal:Facts(e,"personal",f)) do
                local fact=row.fact
                if A.Position(fact.lastPosition) and (not latest or fact.last>latest.last) then latest=fact end
            end
            position=latest and latest.lastPosition;stamp=latest and latest.last
        end
        if latest then
            local p=A.Copy(position);p.id,p.name,p.last,p.transient,p.itemName=e.id,e.name,stamp,true,itemName;return marker(p)
        end
    end
    function adapter:Get(id) local e=journal.db.spots[id];return e and not e.removed and marker(e) or selectedWater(id) end
    function adapter:List(_,mapID)
        local filters=A.Copy(getFilters());filters.mapID=mapID;filters.query="";filters.status="all"
        local out={};for _,e in ipairs(journal:List("waters",filters)) do if e.kind=="spot" and e.mapID==mapID then out[#out+1]=marker(e) end end
        local water=selectedWater(selectedID);if water and water.mapID==mapID then out[#out+1]=water end
        return out
    end
    function adapter:Layer() return true end
    function adapter:WeatherText() return "" end
    local map=ns.CreateAtlasMap(parent,adapter,onSelect,function() end,onNavigate)
    local render=map.Render
    function map:Render(mapID,selected)
        selectedID=selected
        local caption=render(self,mapID,selected)
        if not self.available then self.empty:SetText("Map artwork unavailable.\nYour fishing records and notes remain in the index.") end
        for _,pin in ipairs(self.pins or {}) do
            if pin.group and pin:IsShown() then
                pin:RegisterForClicks("LeftButtonUp","RightButtonUp")
                pin:SetScript("OnClick",function(self,button)
                    if map:FinishPan() then return end
                    if button=="RightButton" then
                        if not IsControlKeyDown or not IsControlKeyDown() then map:Navigate(button);return end
                        local target=self.group[1]
                        for _,m in ipairs(self.group) do if m.id==self.selected then target=m;break end end
                        if GameTooltip then GameTooltip:Hide() end
                        if target.point.transient then journal:HideWaterPosition(target.id)
                        else journal:SetSightingRemoved(target.id,true) end
                        return
                    end
                    local index=0
                    for n,m in ipairs(self.group) do if m.id==self.selected then index=n;break end end
                    onSelect(self.group[index%#self.group+1].id)
                end)
                pin.icon:SetTexture("Interface\\Icons\\Trade_Fishing")
                local e=journal:Get(pin.group[1].id)
                if e and not e.personal then pin.icon:SetVertexColor(0.65,0.75,1) else pin.icon:SetVertexColor(1,1,1) end
                pin:SetScript("OnEnter",function(self)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText("Remembered fishing locations")
                    for i,m in ipairs(self.group) do
                        if i>8 then GameTooltip:AddLine("More overlapping spots are available in the index.",1,1,1,true);break end
                        local spot=journal:Get(m.id)
                        GameTooltip:AddLine(A.Safe(spot.name),1,0.82,0.14,true)
                        GameTooltip:AddLine(A.PositionLabel(m.point),0.75,0.8,0.8,true)
                        GameTooltip:AddLine("Last seen "..ns.AtlasUI.Date(m.point.last)..(spot.personal and " • personal" or " • reported"),1,1,1,true)
                        if m.point.transient then GameTooltip:AddLine("Latest recorded fishing position; not a permanent remembered spot.",1,1,1,true) end
                        if m.point.itemName then GameTooltip:AddLine("Latest recorded catch position for "..A.Safe(m.point.itemName),1,1,1,true) end
                    end
                    GameTooltip:AddLine("Remembered observations; current pool availability is unknown.",1,1,1,true)
                    if not journal.readOnly then
                        GameTooltip:AddLine("Ctrl+Right Click: remove the selected spot or position marker. Catch history is retained.",1,0.82,0.14,true)
                    end
                    if #self.group>1 then GameTooltip:AddLine("Click repeatedly to cycle overlapping spots.",1,0.82,0.14,true) end
                    GameTooltip:Show()
                end)
            end
        end
        return caption
    end
    return map
end
