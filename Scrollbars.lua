local _, ns = ...

-- Keep the template's scrolling behavior, but only display its controls when
-- there is content outside the viewport. Range changes also cover EditBox text.
function ns.AutoHideScrollBar(scroll)
    local function update(self)
        local range = math.max(0, tonumber(self:GetVerticalScrollRange()) or 0)
        local bar = self.ScrollBar
        if type(bar) == "function" then bar = nil end
        if not bar and type(self.GetScrollBar) == "function" then bar = self:GetScrollBar() end
        if bar then bar:SetShown(range > 0) end
        self:EnableMouseWheel(range > 0)
        local offset = tonumber(self:GetVerticalScroll()) or 0
        if offset > range then self:SetVerticalScroll(range) end
    end
    scroll:HookScript("OnScrollRangeChanged", update)
    scroll:HookScript("OnShow", function(self)
        self:UpdateScrollChildRect()
        update(self)
    end)
    update(scroll)
end
