local _, ns = ...
local schema=ns.SharingReport
local names={revision=0}
ns.PlayerNames=names
local classes={}

local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok and schema.Public(value) then return value end
end
local function fullName(unit)
    local getName=UnitNameUnmodified or UnitName
    if type(getName)~="function" then return end
    local ok,first,surname=pcall(getName,unit)
    if not ok or not schema.Public(first) or not schema.Public(surname) then return end
    if not schema.Character(first) then return end
    if surname~=nil and surname~="" and not schema.Character(surname) then return end
    -- Forever returns separate name/surname parts, including for party members.
    if NameUtil and type(NameUtil.GetFullNameWithoutRealm)=="function" then
        return schema.Character(read(NameUtil.GetFullNameWithoutRealm,first,surname))
    end
    if surname==nil or surname=="" then return schema.Character(first) end
end
function names:Observe(unit)
    if not schema.Text(unit,20) or read(UnitIsPlayer,unit)~=true then return end
    local name=fullName(unit)
    if not name or type(UnitClass)~="function" then return end
    local ok,_,class=pcall(UnitClass,unit)
    if not ok or not schema.Text(class,40) or not class:match("^[A-Z]+$") then return end
    local key=name:lower()
    if classes[key]~=class then
        classes[key]=class
        self.revision=self.revision+1
    end
end
function names:Refresh()
    for _,unit in ipairs({"player","target","mouseover"}) do self:Observe(unit) end
    for i=1,4 do self:Observe("party"..i) end
    for i=1,40 do self:Observe("raid"..i) end
end
local function classColor(class)
    local color=read(C_ClassColor and C_ClassColor.GetClassColor,class)
    if type(color)~="table" then
        color=read(function() return RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] end)
    end
    if type(color)~="table" then return end
    return read(function()
        local rgb={color.r,color.g,color.b}
        for i=1,3 do
            local value=rgb[i]
            if not schema.Public(value) or type(value)~="number" or not (value>=0 and value<=1) then return end
            rgb[i]=math.floor(value*255+0.5)
        end
        return string.format("%02x%02x%02x",unpack(rgb))
    end)
end
function names:Format(value)
    local name=schema.Character(value)
    if not name then return "Unknown player" end
    local class=classes[name:lower()]
    local color=class and classColor(class) or nil
    return "|cff" .. (color or "8c9494") .. name .. "|r"
end

-- Only game-observed classes are cached, for this session. Reports, backups and
-- sharing messages keep plain names and never establish another player's class.
local frame=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE",
    "PLAYER_TARGET_CHANGED","UPDATE_MOUSEOVER_UNIT","UNIT_NAME_UPDATE","UNIT_CONNECTION"}) do
    frame:RegisterEvent(event)
end
frame:SetScript("OnEvent",function(_,event,unit)
    if event=="PLAYER_TARGET_CHANGED" then names:Observe("target")
    elseif event=="UPDATE_MOUSEOVER_UNIT" then names:Observe("mouseover")
    elseif event=="UNIT_NAME_UPDATE" or event=="UNIT_CONNECTION" then names:Observe(unit)
    else names:Refresh() end
end)
names:Refresh()
