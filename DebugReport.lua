local _, ns = ...
local panel, edit, scroll

function ns.ShowDebugReport(report)
    if not panel then
        panel = CreateFrame("Frame", "AzerothFieldbookDebugReport", UIParent, "BackdropTemplate")
        panel:SetSize(740, 540); panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG"); panel:SetClampedToScreen(true)
        panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=16})
        panel:SetBackdropColor(0.04, 0.04, 0.04, 0.97)
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 18, -18); title:SetText("Azeroth Fieldbook — Debug report")
        local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 18, -43)
        hint:SetText("Select text and press Ctrl+C to copy. Run /fieldbook debug again for a fresh snapshot.")
        scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -70); scroll:SetPoint("BOTTOMRIGHT", -38, 55)
        edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal)
        edit:SetMaxLetters(0); edit:SetWidth(684); edit:SetHeight(1)
        edit:SetScript("OnEscapePressed", function() panel:Hide() end)
        edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
            local top = -y
            local offset = scroll:GetVerticalScroll()
            if top < offset then scroll:SetVerticalScroll(math.max(0, top))
            elseif top + height > offset + scroll:GetHeight() then
                scroll:SetVerticalScroll(math.max(0, top + height - scroll:GetHeight()))
            end
        end)
        scroll:SetScrollChild(edit)
        local selectAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        selectAll:SetSize(130, 24); selectAll:SetPoint("BOTTOMLEFT", 18, 17)
        selectAll:SetText("Select all")
        selectAll:SetScript("OnClick", function() edit:SetFocus(); edit:HighlightText() end)
        local close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        close:SetSize(100, 24); close:SetPoint("BOTTOMRIGHT", -18, 17); close:SetText("Close")
        close:SetScript("OnClick", function() panel:Hide() end)
        panel:SetScript("OnHide", function() edit:ClearFocus(); panel:StopMovingOrSizing() end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "AzerothFieldbookDebugReport" end
        if UIParent.GetWidth and UIParent.GetHeight then
            panel:SetScale(math.min(1, (UIParent:GetWidth()-30)/740, (UIParent:GetHeight()-30)/540))
        end
    end
    panel:Show()
    edit:SetText(report); edit:SetCursorPosition(0)
    scroll:SetVerticalScroll(0)
    edit:SetFocus(); edit:HighlightText()
end
