local _, ns = ...
local T=ns.Treasure
function ns.CreateTreasureMap(parent,journal,state,onEncounter)
    local adapter={};local points={}
    function adapter:Get(id) return points[id] end
    function adapter:List(_,mapID)
        local rows={};for _,p in pairs(points) do if not mapID or p.mapID==mapID then rows[#rows+1]=p end end
        table.sort(rows,function(a,b) return a.id<b.id end);return rows
    end
    function adapter:Layer() return true end
    function adapter:WeatherText() return "" end
    local map=ns.CreateAtlasMap(parent,adapter,onEncounter,function() end)
    local emptyOverlay=CreateFrame("Frame",nil,map)
    emptyOverlay:SetAllPoints();emptyOverlay:SetFrameLevel(map:GetFrameLevel()+5);emptyOverlay:EnableMouse(false)
    map.emptyShade=emptyOverlay:CreateTexture(nil,"BACKGROUND")
    map.emptyShade:SetAllPoints();map.emptyShade:SetColorTexture(0,0,0,0.48);map.emptyShade:Hide()
    map.empty:SetParent(emptyOverlay);map.empty:ClearAllPoints();map.empty:SetPoint("CENTER",map,"CENTER",0,0)
    local render=map.Render
    function map:Render()
        points={}
        for _,v in ipairs(journal:Markers(state.selected,state.mapID,state.allZone)) do
            local p=T.Copy(v.location);local e=journal:Get(v.kindID)
            p.id=v.id;p.name=journal:Title(e);p.category="other";p.stops={};p.encounter=v;points[v.id]=p
        end
        local noHistory=not next(points)
        local displayed=state.mapID
        if noHistory then
            local current=ns.Atlas.CurrentLocation()
            displayed=current and current.mapID or displayed
        end
        local caption=render(self,displayed,state.encounter)
        self.emptyShade:SetShown(noHistory and self.available)
        self.empty:SetWidth(self:GetWidth()-24)
        -- The same fixed fit rectangle is retained even without a usable point.
        if noHistory then
            self.empty:SetText("No historical find coordinates on this map.\nOpening/carried locations are metadata, not places to find containers.")
            self.empty:Show()
        end
        for _,pin in ipairs(self.pins or {}) do if pin.group and pin:IsShown() then
            local v=pin.group[1].point.encounter
            local kind=journal:Get(v.kindID)
            pin.icon:SetTexture(kind and kind.form=="world" and T.WORLD_ICON or T.ICON)
            pin.icon:SetVertexColor(v.reported and 0.55 or 1,v.reported and 0.7 or 1,1)
            pin:SetScript("OnEnter",function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText("Past finds — current availability unknown")
                for i,marker in ipairs(self.group) do
                    if i>8 then GameTooltip:AddLine("More overlapping encounters; click repeatedly or use History.",1,1,1,true);break end
                    local p=marker.point;local encounter=p.encounter
                    GameTooltip:AddLine(T.Safe(p.name),1,0.82,0.14,true)
                    GameTooltip:AddLine(T.Safe(T.LocationText(encounter.location)),1,1,1,true)
                    GameTooltip:AddLine(T.Safe((encounter.reported and "Reported by " or "Personal / "..encounter.origin.method..": ")..encounter.origin.source.." • "..T.Date(encounter.origin.at)),0.75,0.8,1,true)
                    GameTooltip:AddLine(T.Safe(T.Outcome(encounter)),1,1,1,true)
                    if encounter.note~="" then GameTooltip:AddLine(T.Safe(encounter.note),1,1,1,true) end
                    if encounter.reported then GameTooltip:AddLine("Received "..T.Date(encounter.received),1,1,1,true) end
                end
                if #self.group>1 then GameTooltip:AddLine("Click repeatedly to select each historical encounter.",1,0.82,0.14,true) end
                GameTooltip:Show()
            end)
        end end
        return caption
    end
    return map
end
