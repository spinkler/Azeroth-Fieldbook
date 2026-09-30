local _, ns = ...
local textSize = {}
ns.TextSize = textSize
local fonts, activeOffset = {}, nil
local styledEdits = setmetatable({}, {__mode = "k"})

local function normalize(value)
    value = tonumber(value) or 0
    if value ~= value then value = 0 end
    return math.max(-3, math.min(3, math.floor(value + 0.5)))
end

function textSize:Get()
    -- The standalone recovery UI can open before a damaged account save has
    -- been initialized. Reading a font preference must not repair that save.
    return normalize(type(AzerothFieldbookAccountDB)=="table" and AzerothFieldbookAccountDB.textSizeOffset or nil)
end

function textSize:Initialize()
    if activeOffset == nil then activeOffset = self:Get() end
end

function textSize:Set(value)
    self:Initialize()
    if type(AzerothFieldbookAccountDB) ~= "table" then AzerothFieldbookAccountDB = {} end
    AzerothFieldbookAccountDB.textSizeOffset = normalize(value)
end

function textSize:NeedsReload()
    self:Initialize()
    return self:Get() ~= activeOffset
end

-- Copy only Fieldbook's font references. Blizzard's shared fonts stay intact.
-- Freeze the active size until reload, including windows built lazily later.
function textSize:Font(base)
    self:Initialize()
    if activeOffset == 0 or not base then return base end
    if fonts[base] then return fonts[base] end
    local source = type(base) == "string" and _G[base] or base
    if not source or type(source.GetFont) ~= "function" then return base end
    local path, size, flags = source:GetFont()
    if not path or type(size) ~= "number" then return base end
    local name = "AzerothFieldbookTextSize" .. tostring(self.nextFont or 1)
    local font = CreateFont(name)
    self.nextFont = (self.nextFont or 1) + 1
    font:CopyFontObject(source)
    font:SetFont(path, math.max(1, size + activeOffset), flags)
    fonts[base] = type(base) == "string" and name or font
    fonts[font], fonts[name] = font, name
    return fonts[base]
end

function textSize:StyleControl(control)
    self:Initialize()
    -- Even assigning the same native Font wrapper back to an EditBox can
    -- create a self-referential font chain in Forever (client stack overflow).
    -- At the default size, leave every template font entirely untouched.
    if activeOffset == 0 then return end
    if control.GetFont and control.SetFont then
        if styledEdits[control] then return end
        local path, size, flags = control:GetFont()
        if path and type(size) == "number" then
            control:SetFont(path, math.max(1, size + activeOffset), flags)
            styledEdits[control] = true
        end
        return
    end
    for _, state in ipairs({"Normal", "Highlight", "Disabled"}) do
        local get, set = control["Get" .. state .. "FontObject"], control["Set" .. state .. "FontObject"]
        if get and set then
            local base = get(control)
            local font = base and self:Font(base)
            if font and font ~= base then set(control, font) end
        end
    end
end
