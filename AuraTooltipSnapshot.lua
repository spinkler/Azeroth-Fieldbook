-- Experimental relay of rendered tooltip text. Never parse or save its contents.
local _, ns = ...
local snapshot = {}
ns.AuraTooltipSnapshot = snapshot
local db, panel, scroll, body, heading, eligible
local lines, hooked = {}, {}
local observed
local status = "no GameTooltip aura callback received"
local callbacks = 0
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function clear()
    observed = nil
    if not panel then return end
    panel:Hide()
    for _, pair in ipairs(lines) do
        pair[1]:SetText(""); pair[2]:SetText("")
    end
end
local function capture(tooltip, unit, kind, filter)
    if not db or db.displayHoveredAuraSnapshots == false then return end
    if not public(unit) or type(unit) ~= "string" then status = "hover unit unavailable"; return end
    if kind == "aura" then
        if not public(filter) then status = "hover filter unavailable"; return end
        if filter == nil then
            local owner = read(tooltip.GetOwner, tooltip)
            if public(owner) and type(owner) == "table" then filter = read(owner.GetFilter, owner) end
        end
        if not public(filter) or type(filter) ~= "string" then status = "hover category unavailable"; return end
        if filter:match("^HARMFUL") then kind = "debuff"
        elseif filter:match("^HELPFUL") then kind = "buff"
        else status = "hover category unavailable"; return end
    end
    local label = eligible(unit, kind)
    if not label then status = "hover excluded"; return end
    local forbidden = read(tooltip.IsForbidden, tooltip)
    if not public(forbidden) or forbidden then status = "tooltip access denied"; return end
    local shown = read(tooltip.IsShown, tooltip)
    if not public(shown) or not shown then status = "tooltip not visible"; return end
    local count = read(tooltip.NumLines, tooltip)
    if not public(count) or type(count) ~= "number" or count < 1 or count > 64 then
        status = "tooltip line count unavailable"; return
    end
    clear()
    local accepted, contentHeight = 0, 0
    for index = 1, count do
        if not lines[index] then
            lines[index] = {}
            for side = 1, 2 do
                local text = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                text:SetSize(side == 1 and 305 or 105, 32)
                text:SetJustifyH(side == 1 and "LEFT" or "RIGHT"); text:SetJustifyV("TOP")
                lines[index][side] = text
            end
        end
        local rowHeight = 14
        for side, suffix in ipairs({ "Left", "Right" }) do
            local destination = lines[index][side]
            destination:ClearAllPoints()
            destination:SetPoint("TOPLEFT",side == 1 and 0 or 310,-contentHeight)
            destination:SetHeight(0)
            local source = _G["GameTooltipText" .. suffix .. index]
            if source then
                local ok, value = pcall(source.GetText, source)
                if ok and pcall(lines[index][side].SetText, lines[index][side], value) then
                    accepted = accepted + 1
                    -- Only measure public text. Secret text keeps a fixed wrapping allowance.
                    local height = public(value) and read(destination.GetStringHeight,destination) or nil
                    if public(value) and public(height) and type(height)=="number" then
                        rowHeight = math.max(rowHeight,math.min(256,height))
                    elseif not public(value) then rowHeight = math.max(rowHeight,32) end
                end
            end
        end
        for _, destination in ipairs(lines[index]) do destination:SetHeight(rowHeight) end
        contentHeight = contentHeight + rowHeight + 3
    end
    if accepted == 0 then status = "tooltip text relay rejected"; return end
    body:SetHeight(contentHeight)
    panel:SetHeight(math.min(340, contentHeight+60))
    local overflowing = contentHeight > 280
    if scroll.ScrollBar and type(scroll.ScrollBar) ~= "function" then scroll.ScrollBar:SetShown(overflowing) end
    scroll:EnableMouseWheel(overflowing)
    scroll:SetVerticalScroll(0)
    heading:SetText(label .. " — hovered snapshot")
    observed = GetTime()
    status = "text passed to display (" .. count .. " lines); rendering needs visual confirmation"
    panel:Show()
end
function snapshot:ApplySettings()
    if not panel then return end
    panel:SetBackdropColor(0,0,0,db.spellIDWindowAlpha or 0.35)
    if db.displayHoveredAuraSnapshots == false then clear() end
end
function snapshot:Initialize(settings, anchor, eligibility)
    db, eligible = settings, eligibility
    db.displayHoveredAuraSnapshots = db.displayHoveredAuraSnapshots ~= false
    if not panel then
        panel = CreateFrame("Frame", "AzerothFieldbookAuraSnapshot", UIParent, "BackdropTemplate")
        if ns.UIScale then ns.UIScale:Register(panel) end
        panel:SetSize(455,340); panel:SetClampedToScreen(true); panel:SetFrameStrata("MEDIUM")
        panel:SetPoint("TOPLEFT",anchor,"TOPRIGHT",8,0)
        panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
        heading = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        heading:SetPoint("TOPLEFT",10,-10)
        local note = panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        note:SetPoint("TOPLEFT",10,-28); note:SetText("Timers frozen. Right-click to dismiss.")
        panel:EnableMouse(true)
        panel:SetScript("OnMouseUp",function(_,button) if button == "RightButton" then clear() end end)
        scroll = CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",10,-50); scroll:SetPoint("BOTTOMRIGHT",-30,10)
        body = CreateFrame("Frame",nil,scroll); body:SetSize(415,1); scroll:SetScrollChild(body)
        panel:SetScript("OnUpdate",function()
            if observed and not db.spellIDWindowIndefinite and GetTime()-observed >= 120 then clear() end
        end)
    end
    clear(); self:ApplySettings()
    if not GameTooltip or type(hooksecurefunc) ~= "function" then status = "tooltip hooks unavailable"; return end
    for method, kind in pairs({SetUnitBuff="buff",SetUnitDebuff="debuff",SetUnitAura="aura",
        SetUnitBuffByAuraInstanceID="buff",SetUnitDebuffByAuraInstanceID="debuff",SetUnitAuraByAuraInstanceID="aura"}) do
        if not hooked[method] and type(GameTooltip[method]) == "function" then
            local category = kind
            local ok = pcall(hooksecurefunc, GameTooltip, method, function(tooltip,unit,_,filter)
                callbacks = callbacks + 1
                capture(tooltip,unit,category,filter)
            end)
            hooked[method] = ok or nil
        end
    end
end
function snapshot:Report(say)
    local installed = 0
    for _, active in pairs(hooked) do if active then installed = installed + 1 end end
    say("Hovered aura snapshot: " .. status)
    say("GameTooltip aura hooks installed=" .. installed .. "; callbacks=" .. callbacks)
    say("Forever target-aura tooltips use Blizzard's private AuraButtonTooltip, which is forbidden and hidden from addons. These GameTooltip hooks cannot capture it.")
end
