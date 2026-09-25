local _, ns = ...

function ns.StyleScrollBarTrack(bar, backgroundAlpha)
    if backgroundAlpha then
        -- A translucent track needs a hollow border: an opaque rectangle behind
        -- the fill would prevent the parchment from showing through it.
        bar.trackEdges={}
        for _,edge in ipairs({
            {"TOPLEFT",-2,2,"TOPRIGHT",2,2},
            {"BOTTOMLEFT",-2,-2,"BOTTOMRIGHT",2,-2},
            {"TOPLEFT",-2,1,"BOTTOMLEFT",-2,-1},
            {"TOPRIGHT",2,1,"BOTTOMRIGHT",2,-1},
        }) do
            local texture=bar:CreateTexture(nil,"BACKGROUND",nil,-2)
            texture:SetPoint(edge[1],edge[2],edge[3]);texture:SetPoint(edge[4],edge[5],edge[6])
            if edge[3]==edge[6] then texture:SetHeight(1) else texture:SetWidth(1) end
            texture:SetColorTexture(0.37,0.25,0.11,backgroundAlpha)
            bar.trackEdges[#bar.trackEdges+1]=texture
        end
        bar.trackBorder=bar.trackEdges[1]
    else
        bar.trackBorder = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
        bar.trackBorder:SetPoint("TOPLEFT", -2, 2); bar.trackBorder:SetPoint("BOTTOMRIGHT", 2, -2)
        bar.trackBorder:SetColorTexture(0.37, 0.25, 0.11, 0.9)
    end
    bar.trackBackground = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    bar.trackBackground:SetPoint("TOPLEFT", -1, 1); bar.trackBackground:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.trackBackground:SetColorTexture(0.045, 0.032, 0.018, backgroundAlpha or 0.9)
end

-- Shared parchment-window track, spanning the window without overlapping its close button.
function ns.StyleWindowScrollBar(scroll, window)
    local bar = scroll.ScrollBar
    if type(bar) == "function" then bar = nil end
    if not bar and type(scroll.GetScrollBar) == "function" then bar = scroll:GetScrollBar() end
    if not bar then return end
    local up, down = bar.ScrollUpButton, bar.ScrollDownButton
    local upHeight = up and type(up) ~= "function" and up:GetHeight() or 16
    local downHeight = down and type(down) ~= "function" and down:GetHeight() or 16
    bar:ClearAllPoints()
    bar:SetPoint("TOP", window.closeButton, "BOTTOM", -1, 1-upHeight)
    bar:SetPoint("BOTTOM", window, "BOTTOMRIGHT", -16, 6+downHeight)
    if up and type(up) ~= "function" then
        up:ClearAllPoints(); up:SetPoint("BOTTOM", bar, "TOP", 0, 0)
    end
    if down and type(down) ~= "function" then
        down:ClearAllPoints(); down:SetPoint("TOP", bar, "BOTTOM", 0, 0)
    end
    ns.StyleScrollBarTrack(bar)
end

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
    scroll.RefreshScrollBar=update
    update(scroll)
end
