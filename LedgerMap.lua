local _, ns = ...
local L=ns.Ledger
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
