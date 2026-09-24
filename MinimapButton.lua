local _, ns = ...
local minimap = {}
ns.MinimapButton = minimap
local db, button, controller
function minimap:ApplySettings()
    if button and db then button:SetShown(db.showMinimapButton ~= false) end
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
        button:SetPoint("CENTER",Minimap,"CENTER",-76,-76)
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
        button:SetScript("OnClick",function() controller:Toggle() end)
        button:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_LEFT")
            GameTooltip:SetText("Azeroth Fieldbook")
            GameTooltip:AddLine("Click to open or close the journal.",1,1,1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    end
    self:ApplySettings()
end
