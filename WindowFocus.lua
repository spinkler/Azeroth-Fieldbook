local _, ns = ...
local focus = {}
ns.WindowFocus = focus
local windows, watched = {}, setmetatable({}, { __mode = "k" })

local function acceptsClicks(frame)
    if type(frame.IsMouseClickEnabled) == "function" then return frame:IsMouseClickEnabled() == true end
    return frame:IsMouseEnabled() == true
end

local function watch(frame, window)
    if windows[frame] and frame ~= window then return end
    -- Installing OnMouseDown enables mouse input. Never hook decorative or
    -- hover-only containers: some cover the entire book and would eat clicks.
    if not watched[frame] and acceptsClicks(frame) then
        local motion = type(frame.IsMouseMotionEnabled) == "function" and frame:IsMouseMotionEnabled()
        watched[frame] = true
        frame:HookScript("OnMouseDown", function() window:Raise() end)
        if type(motion) == "boolean" and type(frame.SetMouseMotionEnabled) == "function" then
            frame:SetMouseMotionEnabled(motion)
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do watch(child, window) end
end

function focus:Register(window, strata)
    if windows[window] then watch(window,window); return end
    windows[window] = true
    if ns.WindowPositions then ns.WindowPositions:Track(window) end
    -- Raise only works within one strata. Native top-level handling also raises
    -- a window when clicking controls added after it was first displayed.
    window:SetFrameStrata(strata or "DIALOG")
    window:SetToplevel(true)
    watch(window, window)
    window:HookScript("OnShow", function(self)
        watch(self, self)
        self:Raise()
    end)
end
