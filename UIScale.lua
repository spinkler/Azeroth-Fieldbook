local _, ns = ...
local scale = {}
ns.UIScale = scale
local db, frames = nil, {}
function scale:Get()
    return math.max(0.5, math.min(1.5, tonumber(db and db.uiScale) or 1))
end
function scale:Apply()
    local value = self:Get()
    for frame, base in pairs(frames) do frame:SetScale(base * value) end
    if ns.WindowPositions then ns.WindowPositions:RestoreAll() end
    if ns.MinimapButton then ns.MinimapButton:UpdatePosition() end
end
function scale:Initialize(settings)
    if type(AzerothFieldbookAccountDB) ~= "table" then AzerothFieldbookAccountDB = {} end
    db = AzerothFieldbookAccountDB
    -- The first character after upgrading seeds the shared preference.
    if db.uiScale == nil then
        db.uiScale = math.max(0.5, math.min(1.5, tonumber(settings.uiScale) or 1))
    end
    settings.uiScale = nil
    self:Apply()
    if ns.WindowPositions then ns.WindowPositions:Initialize(settings) end
end
function scale:Register(frame, positionKey)
    if not frames[frame] then frames[frame] = frame:GetScale() or 1 end
    frame:SetScale(frames[frame] * self:Get())
    if positionKey and ns.WindowPositions then ns.WindowPositions:Register(frame, positionKey) end
end
function scale:Set(value)
    if not db then return end
    if ns.WindowPositions then ns.WindowPositions:SaveVisible() end
    db.uiScale = math.max(0.5, math.min(1.5, tonumber(value) or 1))
    self:Apply()
end
