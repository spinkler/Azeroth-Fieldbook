local _, ns = ...
local positions = {}
ns.WindowPositions = positions
local db, events
local frames = {}

local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function applyDefault(frame, registration)
    frame:ClearAllPoints()
    if type(registration.default) == "function" then
        registration.default(frame)
    else
        local point, relative, relativePoint, x, y = unpack(registration.default)
        -- A report can arrive before the book has been built. Once it exists,
        -- centered fallback dialogs use it as their origin too.
        if point == "CENTER" and (not relative or relative == UIParent)
            and AzerothFieldbookBestiary and frame ~= AzerothFieldbookBestiary then
            relative, relativePoint = AzerothFieldbookBestiary, "CENTER"
        end
        frame:SetPoint(point, relative, relativePoint, x, y)
    end
end

function positions:Save(frame, key)
    key = key or (frames[frame] and frames[frame].key)
    if not db or not key then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    local scale, parentScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not finite(left) or not finite(top) or not finite(scale) or scale <= 0
        or not finite(parentScale) or parentScale <= 0 then return end
    -- UIParent coordinates keep the title in place even for scaled windows,
    -- children inheriting the book's scale, and windows that change height.
    if type(db.windowPositions) ~= "table" then db.windowPositions = {} end
    db.windowPositions[key] = { left = left * scale / parentScale, top = top * scale / parentScale }
    if frames[frame] then frames[frame].moved = true end
    local sharedKey = frames[frame] and frames[frame].sharedKey
    if sharedKey and key == frames[frame].key then
        local shared = sharedKey()
        if shared then self:Save(frame, shared) end
    end
end

-- Showing, hiding and resizing a default window must not detach it from the
-- book. Only explicit drags (or restored user positions) become screen anchors.
function positions:SaveIfMoved(frame, key)
    if frames[frame] and frames[frame].moved then self:Save(frame, key) end
end

function positions:Restore(frame, key)
    key = key or (frames[frame] and frames[frame].key)
    local saved = db and type(db.windowPositions) == "table" and db.windowPositions[key]
    if type(saved) ~= "table" or not finite(saved.left) or not finite(saved.top) then return false end
    local scale, parentScale = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not finite(scale) or scale <= 0 or not finite(parentScale) or parentScale <= 0 then return false end
    local left, top = saved.left, saved.top
    local width = frame.GetWidth and frame:GetWidth()
    local height = frame.GetHeight and frame:GetHeight()
    local screenWidth = UIParent.GetWidth and UIParent:GetWidth()
    local screenHeight = UIParent.GetHeight and UIParent:GetHeight()
    if finite(width) and finite(screenWidth) and screenWidth > 0 then
        left = math.max(0, math.min(left, math.max(0, screenWidth-width*scale/parentScale)))
    end
    if finite(height) and finite(screenHeight) and screenHeight > 0 then
        top = math.max(math.min(height*scale/parentScale, screenHeight), math.min(top, screenHeight))
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * parentScale / scale, top * parentScale / scale)
    if frames[frame] then frames[frame].moved = true end
    return true
end

function positions:SaveVisible()
    for frame in pairs(frames) do
        if frame:IsShown() then self:SaveIfMoved(frame) end
    end
end

function positions:RestoreAll(resetMissing)
    for frame, registration in pairs(frames) do
        if not self:Restore(frame) and resetMissing then
            registration.moved = false
            applyDefault(frame, registration)
        end
    end
end

function positions:Initialize(settings)
    db = settings
    if type(db.windowPositions) ~= "table" then db.windowPositions = {} end
    self:RestoreAll(true)
    if not events then
        events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_LOGOUT")
        events:SetScript("OnEvent", function() self:SaveVisible() end)
    end
end

function positions:Reset()
    if not db then return end
    db.windowPositions = {}
    self:RestoreAll(true)
end

function positions:Register(frame, key, sharedKey, defaultPosition)
    if frames[frame] then return end
    if ns.WindowFocus then ns.WindowFocus:Register(frame) end
    frames[frame] = { key = key, default = defaultPosition or { frame:GetPoint() }, sharedKey = sharedKey }
    frame:SetClampedToScreen(true)
    if frame.SetClampRectInsets then frame:SetClampRectInsets(0, 0, 0, 0) end
    frame:HookScript("OnDragStop", function(self) positions:Save(self) end)
    frame:HookScript("OnHide", function(self) positions:SaveIfMoved(self) end)
    frame:HookScript("OnShow", function(self)
        local registration = frames[self]
        if not registration.moved then
            applyDefault(self, registration)
        end
    end)
    if not self:Restore(frame) then applyDefault(frame, frames[frame]) end
end
