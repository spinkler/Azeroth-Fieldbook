local _, ns = ...
local minimap = {}
ns.MinimapButton = minimap
local db, button, controller
local dragging, suppressClick = false, false
local function tooltip()
    if not GameTooltip then return end
    GameTooltip:SetOwner(button,"ANCHOR_LEFT")
    GameTooltip:SetText("Azeroth Fieldbook")
    GameTooltip:AddLine("Click to open or close the journal.",1,1,1)
    GameTooltip:AddLine(db.minimapButtonLocked and "Locked. Shift-click to unlock." or "Drag around the minimap. Shift-click to lock.",1,0.82,0.14)
    GameTooltip:Show()
end
function minimap:UpdatePosition()
    if not button or not db then return end
    local angle=math.rad(tonumber(db.minimapButtonAngle) or 225)
    local mapScale, buttonScale=Minimap:GetEffectiveScale(),button:GetEffectiveScale()
    local ratio=mapScale/buttonScale
    local x=math.cos(angle)*(Minimap:GetWidth()/2+8)
    local y=math.sin(angle)*(Minimap:GetHeight()/2+8)
    button:ClearAllPoints()
    button:SetPoint("CENTER",Minimap,"CENTER",x*ratio,y*ratio)
end
local function dragUpdate()
    if not dragging or db.minimapButtonLocked then return end
    local x,y=GetCursorPosition()
    local cx,cy=Minimap:GetCenter()
    if not cx or not cy then return end
    local scale=Minimap:GetEffectiveScale()
    x,y=x/scale-cx,y/scale-cy
    if x==0 and y==0 then return end
    db.minimapButtonAngle=math.deg(math.atan2(y,x))%360
    minimap:UpdatePosition()
end
local function stopDrag()
    dragging=false
    button:SetScript("OnUpdate",nil)
end
function minimap:ApplySettings()
    if button and db then
        if db.minimapButtonLocked or db.showMinimapButton==false then stopDrag() end
        self:UpdatePosition()
        button:SetShown(db.showMinimapButton ~= false)
    end
end
function minimap:Initialize(settings, book)
    db, controller = settings, book
    if not Minimap or not controller then return end
    if not button then
        button = CreateFrame("Button", "AzerothFieldbookMinimapButton", Minimap)
        if ns.UIScale then ns.UIScale:Register(button) end
        button:SetSize(32,32)
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(Minimap:GetFrameLevel()+5)
        button:RegisterForDrag("LeftButton")
        button:RegisterForClicks("LeftButtonUp")
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        local icon=button:CreateTexture(nil,"ARTWORK")
        icon:SetTexture("Interface\\Icons\\INV_Misc_Book_02")
        icon:SetSize(20,20); icon:SetPoint("CENTER")
        icon:SetTexCoord(0.07,0.93,0.07,0.93)
        if type(button.CreateMaskTexture)=="function" and type(icon.AddMaskTexture)=="function" then
            local mask=button:CreateMaskTexture()
            mask:SetAllPoints(icon)
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            icon:AddMaskTexture(mask)
        end
        local border=button:CreateTexture(nil,"OVERLAY")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        border:SetSize(54,54); border:SetPoint("TOPLEFT")
        button:SetScript("OnMouseDown",function() suppressClick=false end)
        button:SetScript("OnDragStart",function()
            if db.minimapButtonLocked or (IsShiftKeyDown and IsShiftKeyDown()) then return end
            dragging=true; suppressClick=true
            if GameTooltip then GameTooltip:Hide() end
            button:SetScript("OnUpdate",dragUpdate)
            dragUpdate()
        end)
        button:SetScript("OnDragStop",function() dragUpdate(); stopDrag() end)
        button:SetScript("OnHide",stopDrag)
        button:SetScript("OnClick",function()
            if suppressClick then suppressClick=false; return end
            if IsShiftKeyDown and IsShiftKeyDown() then
                db.minimapButtonLocked=not db.minimapButtonLocked
                if db.minimapButtonLocked then stopDrag() end
                tooltip()
            else controller:Toggle() end
        end)
        button:SetScript("OnEnter",function() if not dragging then tooltip() end end)
        button:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    end
    self:ApplySettings()
end
