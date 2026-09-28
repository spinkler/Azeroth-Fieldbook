local _, ns = ...
local L=ns.Lore
L.locationLabels={read="Read here",found="Found here",encounter="Encountered here",observation="Observation position",landmark="Landmark position",reported="Reported location"}
L.locationLabels['read-here']=L.locationLabels.read;L.locationLabels['found-here']=L.locationLabels.found
L.locationLabels.mentioned="Mentioned place (not discovered)"
function L.VisibleLocations(e)
    local rows={}
    for _,p in ipairs(e and e.locations or {}) do rows[#rows+1]=p end
    for index,r in ipairs(e and e.reports or {}) do for number,p in ipairs(r.locations or {}) do
        local copy=L.Copy(p);copy.id="report:"..index..":"..number;copy.origin="reported";copy.reported=true
        copy.claimedMeaning=copy.meaning;copy.meaning="reported";copy.sender=r.receivedFrom;copy.senderClaim=r.sender;rows[#rows+1]=copy
    end end
    return rows
end
function L.LocationLabel(p)
    if not p then return "No location recorded." end
    local meaning=L.locationLabels[p.meaning] or p.meaning or "Location"
    local text=meaning..": "..((p.zone and p.zone~="") and p.zone or "Unknown zone")
    if p.subzone and p.subzone~="" then text=text.." / "..p.subzone end
    if p.x and p.y then text=text..string.format(" • %.2f, %.2f",p.x/100,p.y/100)
    else text=text.." • coordinates unknown" end
    if p.origin=="reported" then text=text.." • received report" end
    if p.claimedMeaning then text=text.." (claimed "..(L.locationLabels[p.claimedMeaning] or p.claimedMeaning)..")" end
    return text
end
function ns.CreateLoreMap(parent,journal,getSelection,onSelect,onPlace)
    local adapter={}
    local function points()
        local id=getSelection();local e=journal:Get(id);local rows={}
        for i,p in ipairs(L.VisibleLocations(e)) do
            local v=L.Copy(p);v.id=tostring(i);v.name=L.LocationLabel(p);v.category="other";v.stops={}
            rows[#rows+1]=v
        end
        return rows
    end
    function adapter:Get(id) for _,p in ipairs(points()) do if p.id==id then return p end end end
    function adapter:List(_,mapID,all)
        local rows={};for _,p in ipairs(points()) do if all or p.mapID==mapID then rows[#rows+1]=p end end;return rows
    end
    function adapter:Layer() return true end
    function adapter:WeatherText() return "" end
    local map=ns.CreateAtlasMap(parent,adapter,function(id) onSelect(tonumber(id)) end,onPlace)
    local emptyOverlay=CreateFrame("Frame",nil,map)
    emptyOverlay:SetAllPoints();emptyOverlay:SetFrameLevel(map:GetFrameLevel()+5);emptyOverlay:EnableMouse(false)
    map.emptyShade=emptyOverlay:CreateTexture(nil,"BACKGROUND")
    map.emptyShade:SetAllPoints();map.emptyShade:SetColorTexture(0,0,0,0.48);map.emptyShade:Hide()
    map.empty:SetParent(emptyOverlay);map.empty:ClearAllPoints();map.empty:SetPoint("CENTER",map,"CENTER",0,0)
    local render=map.Render
    function map:Render()
        local _,index,mapID=getSelection();local rows=points();local selected=rows[index or 1]
        mapID=mapID or selected and selected.mapID
        local noMap=not mapID
        local displayed=mapID
        if noMap then local current=ns.Atlas.CurrentLocation();displayed=current and current.mapID end
        render(self,displayed,selected and selected.id)
        self.emptyShade:SetShown(noMap and self.available)
        self.empty:SetWidth(self:GetWidth()-24)
        if noMap then self.empty:SetText("No map recorded. Add a location or keep the reference as text.");self.empty:Show() end
        for _,pin in ipairs(self.pins or {}) do if pin.group and pin:IsShown() then
            pin.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
            pin:SetScript("OnEnter",function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText("Lore locations")
                for i,marker in ipairs(self.group) do
                    if i>8 then break end
                    local p=marker.point
                    GameTooltip:AddLine(L.Safe(L.LocationLabel(p)),1,1,1,true)
                    if p.sender then GameTooltip:AddLine("Received from: "..L.Safe(p.sender),0.75,0.8,1,true) end
                    if p.senderClaim then GameTooltip:AddLine("Sender claim (not authenticated): "..L.Safe(p.senderClaim),0.75,0.8,1,true) end
                    if p.note and p.note~="" then GameTooltip:AddLine(L.Safe(p.note),1,1,1,true) end
                end
                GameTooltip:AddLine("Location meaning is retained; a reading position is not a source's origin.",1,0.82,0.14,true)
                GameTooltip:Show()
            end)
        end end
        return selected
    end
    return map
end
