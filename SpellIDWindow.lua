-- Ephemeral observations only. Secret values go directly to FontStrings, never SavedVariables.
local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local window = {}
ns.SpellIDWindow = window
BINDING_NAME_AZEROTHFIELDBOOK_PIN_CAST = "Pin latest enemy cast"
BINDING_NAME_AZEROTHFIELDBOOK_UNPIN_CAST = "Unpin last pinned enemy cast"
local recordedAbility
local creatureLocked
local updateTargetSuppression
local targetSuppressed = false
local function suppressed(candidate)
    return candidate and candidate.suppressionVerified and creatureLocked and creatureLocked(candidate)
end
local db, panel, background
local captureAssignment
local openCreature
local customPosition = false
local rows, seen = {}, { player = {}, target = {} }
local castRows, effectRows = {}, {}
local castSerial = 0
local castTokens, castTokenOrder = {}, {}
local castBars = {}
local castBarOrder = {}
local displayAlpha = 1
local layoutHeight = 44
local blacklistWindow
local auraStatus = { player = "not scanned", target = "not scanned" }
local auraEventSerial = 0
local playerAuraEvents = 0
local lastPlayerAuraEvent = "none received"
local events = CreateFrame("Frame")
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function validID(value)
    return public(value) and type(value)=="number" and value>0 and value<=2147483647 and value==math.floor(value)
end
local function bottomAnchor(point,relativePoint,x,y,height)
    local fraction=point:find("TOP",1,true) and 1 or (point:find("BOTTOM",1,true) and 0 or 0.5)
    local bottom=point:find("LEFT",1,true) and "BOTTOMLEFT" or (point:find("RIGHT",1,true) and "BOTTOMRIGHT" or "BOTTOM")
    return bottom,relativePoint,x,y-height*fraction
end
local function layout()
    if not panel then return end
    local count,height=0,0
    local ordered = {}
    for _, row in ipairs(castRows) do
        if row.observed then ordered[#ordered+1]=row end
    end
    table.sort(ordered,function(a,b) return a.serial<b.serial end)
    for index,row in ipairs(ordered) do
        row.title:SetText(index .. ". " .. row.castTitle .. (row.pinned and " |cff80ccff[Pinned]|r" or ""))
    end
    for index=3,5 do
        if effectRows[index] then ordered[#ordered+1]=effectRows[index] end
    end
    for _, row in ipairs(ordered) do
        if row.observed then
            row.body:ClearAllPoints()
            row.body:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-48-height)
            row.body:SetSize(330,row.hasCaster and 68 or 52)
            height=height+(row.hasCaster and 72 or 56)
            row.body:Show();count=count+1
        else row.body:Hide() end
    end
    layoutHeight=count==0 and 44 or 50+height
    panel:SetSize(330,layoutHeight)
end
local function readableTable(value)
    return public(value) and type(value) == "table" and not (issecrettable and issecrettable(value))
end
local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end
local function accessibleTable(value)
    if not public(value) or type(value) ~= "table" then return false end
    if type(canaccesstable) == "function" then
        local allowed = read(canaccesstable, value)
        return public(allowed) and allowed == true
    end
    return readableTable(value)
end
local function targetUnit(unit)
    if not public(unit) or type(unit) ~= "string" then return false end
    if unit == "target" then return true end
    local same = read(UnitIsUnit, unit, "target")
    return public(same) and same == true
end
local function npcUnit(unit)
    if not public(unit) or type(unit) ~= "string" or unit == "" then return false end
    local controlled = read(UnitPlayerControlled, unit)
    if not public(controlled) or controlled ~= false then return false end
    local guid = read(UnitGUID, unit)
    return public(guid) and type(guid) == "string" and guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-%d+%-") ~= nil
end
local function npcTarget()
    local exists = read(UnitExists, "target")
    local player = read(UnitIsPlayer, "target")
    local controlled = read(UnitPlayerControlled, "target")
    return public(exists) and public(player) and public(controlled)
        and exists == true and player == false and controlled == false and npcUnit("target")
end
local function enemyTarget()
    local exists = read(UnitExists, "target")
    local enemy = read(UnitIsEnemy, "player", "target")
    local controlled = read(UnitPlayerControlled, "target")
    return public(exists) and public(enemy) and public(controlled)
        and exists == true and enemy == true and controlled == false and npcUnit("target")
end
local function clear(row)
    row.observed = nil
    row.pinned=nil
    if row.hovered and GameTooltip then GameTooltip:Hide() end
    row.hovered=nil
    row.rawID=nil;row.token=nil
    row.candidate=nil;row.assignmentSaved=nil
    if row.portraitButton then
        row.portraitButton:Hide();row.portrait:SetTexture(nil)
        if row.portraitHovered and GameTooltip then GameTooltip:Hide() end
        row.portraitHovered=nil
    end
    row.id:SetText(""); row.name:SetText(""); row.effect:SetText("")
    if row.caster then row.caster:SetText("") end
    row.body:Hide()
    layout()
end
function window:IsBlacklisted(id)
    return validID(id) and db and db.spellIDWindowBlacklist and db.spellIDWindowBlacklist[id]==true or false
end
function window:GetBlacklist()
    local list={}
    for id,enabled in pairs(db and db.spellIDWindowBlacklist or {}) do
        if validID(id) and enabled==true then list[#list+1]=id end
    end
    table.sort(list);return list
end
function window:AddBlacklist(id)
    if not public(id) then return false,"This ID is restricted. Enter the displayed ID manually. Restricted future IDs cannot be matched to the blacklist." end
    if type(id)=="string" then id=tonumber(id:match("^%s*(%d+)%s*$")) end
    if not validID(id) or not db then return false,"Enter a positive numeric spell ID." end
    db.spellIDWindowBlacklist=db.spellIDWindowBlacklist or {}
    db.spellIDWindowBlacklist[id]=true
    for _, row in ipairs(rows) do
        if validID(row.rawID) and row.rawID==id then clear(row) end
    end
    if blacklistWindow then blacklistWindow:Refresh() end
    return true,"Blacklisted spell ID "..id.."."
end
function window:RemoveBlacklist(id)
    if not validID(id) or not db then return end
    if db.spellIDWindowBlacklist then db.spellIDWindowBlacklist[id]=nil end
    for _, row in ipairs(rows) do
        if row.dismissedID==id then row.dismissedID=nil;row.dismissedToken=nil end
    end
    seen={player={},target={}}
    for index=#castTokenOrder,1,-1 do
        local token=castTokenOrder[index]
        if castTokens[token]==id then castTokens[token]=nil;table.remove(castTokenOrder,index) end
    end
    if blacklistWindow then blacklistWindow:Refresh() end
end
function window:OpenBlacklist(message)
    if not blacklistWindow and ns.CreateSpellBlacklistWindow then blacklistWindow=ns.CreateSpellBlacklistWindow(self) end
    if blacklistWindow then blacklistWindow:Open(message) end
end
local function text(parent, x, y, width, template)
    local value = parent:CreateFontString(nil, "OVERLAY", textFont(template or "GameFontHighlightSmall"))
    value:SetPoint("TOPLEFT", x, y); value:SetSize(width, 14); value:SetJustifyH("LEFT")
    return value
end
local function castTooltip(row, owner)
    if not GameTooltip or not row.observed then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.candidate and row.candidate.name or row.castTitle)
    if row.candidate and row.candidate.description then
        GameTooltip:AddLine(row.candidate.description, 0.7, 0.7, 0.7, true)
    end
    if row.pinned then
        GameTooltip:AddLine("Pinned. This cast stays until you remove it.", 0.5, 0.82, 1, true)
        GameTooltip:AddLine("Right-click: unpin and remove this slot.", 1, 1, 1, true)
        local pinned=0
        for _,slot in ipairs(castRows) do if slot.pinned then pinned=pinned+1 end end
        if pinned==4 then
            GameTooltip:AddLine("All four slots are pinned. Clear one to capture another cast.", 1, 0.82, 0.4, true)
        end
    else
        GameTooltip:AddLine("Live slot: new casts replace this observation until pinned.", 1, 0.82, 0.4, true)
        GameTooltip:AddLine("Left-click: pin this cast and capture the next in another slot.", 1, 1, 1, true)
        GameTooltip:AddLine("Right-click: remove this slot.", 1, 1, 1, true)
        if not db.spellIDWindowIndefinite then
            GameTooltip:AddLine("Unpinned observations expire after two minutes.", 0.7, 0.7, 0.7, true)
        end
    end
    if row.candidate then
        GameTooltip:AddLine("Ctrl+Click: open this creature in the Bestiary.", 0.7, 0.7, 0.7, true)
    end
    if validID(row.rawID) then
        GameTooltip:AddLine("Enter Spell ID " .. row.rawID .. " in the Bestiary to record the ability.", 0.7, 0.7, 0.7, true)
    else
        GameTooltip:AddLine("This spell ID is restricted. Enter the displayed ID manually in the Bestiary.", 1, 0.82, 0.4, true)
    end
    GameTooltip:AddLine("Ctrl+Right-click: blacklist this ID, or enter it manually if restricted.", 0.7, 0.7, 0.7, true)
    GameTooltip:AddLine("Pin/unpin keybinds: Key Bindings > Azeroth Fieldbook.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end
local function portraitTooltip(row)
    if row.isCast then castTooltip(row,row.portraitButton);return end
    if not GameTooltip or not row.candidate then return end
    GameTooltip:SetOwner(row.portraitButton, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.candidate.name)
    if row.assignmentSaved then
        GameTooltip:AddLine("Assigned to this creature in the Bestiary.", 0.5, 1, 0.5, true)
    else
        GameTooltip:AddLine(row.candidate.description or "Your target when this effect was detected. The caster is unverified.", 1, 0.82, 0.4, true)
        if row.candidate.casterName then GameTooltip:AddLine("Cast by: " .. row.candidate.casterName, 0.7, 0.7, 0.7, true) end
        if validID(row.rawID) then
            GameTooltip:AddLine("Click to assign Spell ID " .. row.rawID .. " to this creature in the Bestiary.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("This spell ID is restricted. Enter the displayed ID manually in the Bestiary.", 1, 0.82, 0.4, true)
        end
    end
    GameTooltip:AddLine("Ctrl+Click: open this creature in the Bestiary.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end
local function pin(row)
    if not row.observed or row.pinned then return false end
    row.pinned=true
    layout()
    if row.portraitHovered then portraitTooltip(row)
    elseif row.hovered then castTooltip(row,row.body) end
    return true
end
local function createPortrait(row)
    local button = CreateFrame("Button", nil, row.body)
    row.portraitButton = button
    button:SetSize(42, 42);button:SetPoint("TOPRIGHT", row.body, "TOPRIGHT", -9, -8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local function circle(size, r, g, b, layer)
        local texture = button:CreateTexture(nil, "BACKGROUND", nil, layer)
        texture:SetSize(size, size);texture:SetPoint("CENTER");texture:SetColorTexture(r, g, b, 1)
        if button.CreateMaskTexture and texture.AddMaskTexture then
            local mask = button:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(texture);texture:AddMaskTexture(mask)
        end
        return texture
    end
    circle(44, 0.20, 0.12, 0.055, -2)
    row.portraitRing = circle(42, 0.67, 0.43, 0.19, -1)
    circle(38, 0.035, 0.025, 0.015, 0)
    row.portrait = button:CreateTexture(nil, "ARTWORK")
    row.portrait:SetSize(38, 38);row.portrait:SetPoint("CENTER")
    if button.CreateMaskTexture and row.portrait.AddMaskTexture then
        local mask = button:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(row.portrait);row.portrait:AddMaskTexture(mask)
    end
    row.portraitUnknown = text(button, 0, -11, 42, "GameFontNormalLarge")
    row.portraitUnknown:SetJustifyH("CENTER");row.portraitUnknown:SetText("?")
    row.portraitLevel = text(button, 25, -31, 22, "GameFontNormalSmall")
    row.portraitLevel:SetJustifyH("CENTER")
    button:SetScript("OnEnter", function() row.portraitHovered=true;portraitTooltip(row) end)
    button:SetScript("OnLeave", function() row.portraitHovered=nil;if GameTooltip then GameTooltip:Hide() end end)
    button:SetScript("OnMouseDown", function() row.dragged=nil end)
    button:SetScript("OnClick", function(_, mouseButton)
        if row.isCast or mouseButton == "RightButton" or IsShiftKeyDown() then
            row.body:GetScript("OnMouseUp")(row.body, mouseButton)
        elseif mouseButton == "LeftButton" and row.observed and row.candidate and not ns.InitializationBlocked then
            if IsControlKeyDown and IsControlKeyDown() then
                if openCreature then openCreature(row.candidate) end
            elseif not row.assignmentSaved and row.candidate.assign() then
                row.assignmentSaved=true
                row.casterLabel:SetText("Saved:")
                row.portraitRing:SetColorTexture(0.35, 0.75, 0.35, 1)
                if row.portraitHovered then portraitTooltip(row) end
            end
        end
    end)
    button:Hide()
end
local function showCandidate(row, candidate)
    row.title:SetSize(candidate and 260 or 310, 14)
    row.name:SetSize(candidate and 260 or 310, 14)
    row.effect:SetSize(candidate and 106 or 156, 14)
    row.caster:SetSize(candidate and 205 or 255, 14)
    row.casterLabel:SetText(candidate and (candidate.label or "Target:") or "Cast by:")
    if not candidate then return end
    row.candidate=candidate
    row.portraitRing:SetColorTexture(0.67, 0.43, 0.19, 1)
    row.portraitUnknown:Show()
    -- Render once while the token still matches the captured identity. Never
    -- refresh this texture on target changes or inspect native portrait pixels.
    local unit = candidate.unit or "target"
    local guid = read(UnitGUID, unit)
    if public(guid) and guid == candidate.guid and type(SetPortraitTexture) == "function" then
        local ok = pcall(SetPortraitTexture, row.portrait, unit)
        local after = read(UnitGUID, unit)
        if ok and public(after) and after == candidate.guid then row.portraitUnknown:Hide()
        else row.portrait:SetTexture(nil) end
    end
    row.portraitLevel:SetText(candidate.level or "")
    row.portraitButton:Show()
end
local function updateFade(delta)
    local hasData = false
    for _, row in ipairs(rows) do if row.observed then hasData = true; break end end
    local fading = db.spellIDWindowAutoFade == true and not hasData and not targetSuppressed
    if fading then displayAlpha = math.max(0, displayAlpha - delta / 0.3)
    else displayAlpha = 1 end
    panel:SetAlpha(displayAlpha)
    panel:EnableMouse(not db.spellIDWindowLocked and not fading)
end
local function setup()
    if panel then return end
    panel = CreateFrame("Frame", "AzerothFieldbookSpellIDWindow", UIParent)
        if ns.UIScale then ns.UIScale:Register(panel) end
    panel:SetSize(330, 44); panel:SetFrameStrata("LOW")
    panel:SetClampedToScreen(true); panel:SetMovable(true)
    if panel.SetClampRectInsets then panel:SetClampRectInsets(0,0,0,0) end
    panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
    background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(); background:SetColorTexture(0, 0, 0, 0.35)
    text(panel, 10, -9, 310, "GameFontNormalSmall"):SetText("Last observed spell IDs")
    panel.hint = text(panel, 10, -27, 310)
    panel.hint:SetTextColor(0.6, 0.6, 0.6)
    panel:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            db.displaySpellIDWindow = false
            window:ApplySettings()
        end
    end)
    panel:SetScript("OnDragStart", function(self)
        if not db.spellIDWindowLocked then self:StartMoving() end
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        point,relativePoint,x,y=bottomAnchor(point,relativePoint,x,y,layoutHeight)
        self:ClearAllPoints();self:SetPoint(point,UIParent,relativePoint,x,y)
        db.spellIDWindowPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
        customPosition = true
    end)
    local titles = { "Enemy cast", "Enemy instant cast", "Debuff on you", "Buff on target", "Loss of Control on you" }
    for index, kind in ipairs({ 1, 1, 1, 1, 3, 4, 5 }) do
        local row = {isCast=kind==1}
        rows[index] = row
        if kind==1 then castRows[#castRows+1]=row else effectRows[kind]=row end
        row.body = CreateFrame("Frame", nil, panel)
        row.body:SetSize(330,68)
        text(row.body, 10, -16, 52):SetText("Spell ID:")
        row.id = text(row.body, 65, -16, 92)
        row.effect = text(row.body, 164, -16, 156)
        row.name = text(row.body, 10, -32, 310)
        row.title=text(row.body,10,0,310,"GameFontNormalSmall");row.title:SetText(titles[kind])
        row.casterLabel=text(row.body,10,-48,52);row.casterLabel:SetText("Cast by:")
        row.caster=text(row.body,65,-48,255)
        row.caster:SetTextColor(0.7,0.7,0.7)
        row.body:EnableMouse(true);row.body:RegisterForDrag("LeftButton")
        row.body:SetScript("OnMouseDown",function() row.dragged=nil end)
        row.body:SetScript("OnDragStart",function()
            if not db.spellIDWindowLocked then row.dragged=true;panel:StartMoving() end
        end)
        row.body:SetScript("OnDragStop",function() panel:GetScript("OnDragStop")(panel) end)
        if row.isCast then
            row.body:SetScript("OnEnter",function() row.hovered=true;castTooltip(row,row.body) end)
            row.body:SetScript("OnLeave",function() row.hovered=nil;if GameTooltip then GameTooltip:Hide() end end)
        end
        row.body:SetScript("OnMouseUp",function(_,button)
            if row.dragged then row.dragged=nil;return end
            if ns.InitializationBlocked then return end
            if button=="RightButton" then
                local token=row.token
                local dismissedID=validID(row.rawID) and row.rawID or nil
                if IsControlKeyDown and IsControlKeyDown() then
                    local ok,message=window:AddBlacklist(row.rawID)
                    if not ok then window:OpenBlacklist(message) end
                end
                row.dismissedToken=token
                row.dismissedID=dismissedID
                clear(row);updateFade(0)
            elseif button=="LeftButton" and IsShiftKeyDown() then
                db.displaySpellIDWindow=false;window:ApplySettings()
            elseif button=="LeftButton" and row.isCast and row.observed then
                if IsControlKeyDown and IsControlKeyDown() then
                    if row.candidate and openCreature then openCreature(row.candidate) end
                else
                    pin(row)
                end
            end
        end)
        clear(row)
    end
    for _, row in ipairs(rows) do createPortrait(row) end
    local elapsed = 0
    panel:SetScript("OnUpdate", function(_, delta)
        if ns.InitializationBlocked then return end
        elapsed = elapsed + delta
        if elapsed >= 0.25 then
            elapsed = 0
            updateTargetSuppression()
            if not db.spellIDWindowIndefinite then
                for _, row in ipairs(rows) do
                    if row.observed and not row.pinned and GetTime() - row.observed >= 120 then clear(row) end
                end
            end
            for _, row in ipairs(rows) do
                if row.observed and not row.pinned and row.candidate then
                    if suppressed(row.candidate) then
                        clear(row)
                        if not row.isCast then seen = { player = {}, target = {} } end
                    elseif validID(row.rawID) and recordedAbility and recordedAbility(row.candidate, row.rawID) then clear(row) end
                end
            end
        end
        updateFade(delta)
    end)
    if ns.WindowFocus then ns.WindowFocus:Register(panel, "LOW") end
end
function window:SetAssignmentCapture(callback)
    captureAssignment = callback
end
function window:SetRecordedAbilityCheck(callback)
    recordedAbility = callback
end
function window:SetCreatureLockedCheck(callback)
    creatureLocked = callback
end
function window:SetCreatureOpener(callback)
    openCreature = callback
end
function window:PinLatestCast()
    if not db or db.displaySpellIDWindow==false or ns.InitializationBlocked then return false end
    for _,row in ipairs(castRows) do
        if row.observed and not row.pinned then return pin(row) end
    end
    return false
end
function window:UnpinLastCast()
    if not db or db.displaySpellIDWindow==false or ns.InitializationBlocked then return false end
    local latest
    for _,row in ipairs(castRows) do
        if row.observed and row.pinned and (not latest or row.serial>latest.serial) then latest=row end
    end
    if not latest then return false end
    latest.dismissedToken=latest.token
    latest.dismissedID=validID(latest.rawID) and latest.rawID or nil
    clear(latest);updateFade(0)
    return true
end
function AzerothFieldbookPinLatestCast() return window:PinLatestCast() end
function AzerothFieldbookUnpinLastCast() return window:UnpinLastCast() end
local function candidateFor(unit, spellID, kind, expectedGUID, description, label)
    if not captureAssignment or not public(unit) or type(unit) ~= "string" or unit == "" then return end
    if not public(expectedGUID) then return end
    if unit == "target" and (type(expectedGUID) ~= "string" or expectedGUID == "") then return end
    local candidate = captureAssignment(unit, spellID, kind)
    if not candidate or expectedGUID and candidate.guid ~= expectedGUID then return end
    candidate.description, candidate.label = description, label
    -- Buffs belong to the identified recipient; debuffs require their actual
    -- source, never the fallback target offered for manual assignment.
    candidate.suppressionVerified = kind == "cast" or kind == "buff" or kind == "debuff" and label == "Cast by:"
    return candidate
end
updateTargetSuppression = function()
    local candidate
    if not ns.InitializationBlocked and npcTarget() then
        candidate = candidateFor("target", nil, "cast", read(UnitGUID, "target"))
    end
    targetSuppressed = suppressed(candidate) and true or false
    if panel then
        panel.hint:SetText(targetSuppressed and "Suppressed target" or "Cast: click to pin / Right-click: remove")
        if targetSuppressed then panel.hint:SetTextColor(1, 0.15, 0.15)
        else panel.hint:SetTextColor(0.6, 0.6, 0.6) end
    end
end
local function present(index, id, name, effect, caster, token, candidate)
    local isCast = index==1 or index==2
    -- Only positively attributed observations can use the creature's lock.
    if suppressed(candidate) then return false,"locked" end
    if public(id) and (type(id) ~= "number" or id <= 0) then return end
    local matching
    if isCast and token then
        for _, slot in ipairs(castRows) do
            if slot.observed and slot.token==token then matching=slot;break end
        end
    end
    local duplicate = matching or isCast and token and castTokens[token]
    if matching and matching.pinned then return false,"suppressed" end
    if window:IsBlacklisted(id) or validID(id) and candidate and recordedAbility and recordedAbility(candidate, id) then
        if matching then clear(matching);updateFade(0) end
        return false,"suppressed"
    end
    -- Late public evidence can replace an opaque ID for the same public cast
    -- token, without adding a slot or extending the original expiry.
    if duplicate and not (matching and validID(id) and not validID(matching.rawID)) then return false,"suppressed" end
    local row = effectRows[index]
    if isCast then
        row=matching
        if not row then
            -- Keep exactly one live slot. Only pinning advances capture; a
            -- cleared hole does not create a second live slot beside it.
            for _, slot in ipairs(castRows) do
                if slot.observed and not slot.pinned then row=slot;break end
            end
            if not row then
                for _, slot in ipairs(castRows) do
                    if not slot.observed then row=slot;break end
                end
            end
        end
        if not row then return false,"suppressed" end -- All four slots are pinned.
    end
    local observed=matching and matching.observed
    if token and row.dismissedToken==token then return false,"suppressed" end
    row.dismissedToken=nil;row.dismissedID=nil
    clear(row)
    if not pcall(row.id.SetText, row.id, id) then return end
    -- Never concatenate, compare, measure or read back these potentially secret fields.
    pcall(row.name.SetText, row.name, name)
    pcall(row.effect.SetText, row.effect, effect)
    caster = candidate and candidate.name or caster
    row.hasCaster=not public(caster) or (type(caster)=="string" and caster~="" and caster~="Unknown")
    row.casterLabel:SetShown(row.hasCaster);row.caster:SetShown(row.hasCaster)
    if row.hasCaster then
        local shown=pcall(row.caster.SetText,row.caster,caster)
        if not shown then row.hasCaster=false;row.casterLabel:Hide();row.caster:Hide() end
    end
    row.rawID=id;row.token=token
    showCandidate(row, candidate)
    if isCast then
        if not matching then castSerial=castSerial+1;row.serial=castSerial end
        row.castTitle=index==2 and "Enemy instant cast" or "Enemy cast"
        if token then
            castTokens[token]=validID(id) and id or true
            if not duplicate then
                castTokenOrder[#castTokenOrder+1]=token
                if #castTokenOrder>32 then castTokens[table.remove(castTokenOrder,1)]=nil end
            end
        end
    end
    row.observed = observed or GetTime()
    row.body:Show()
    layout()
    updateFade(0)
    return true
end
local function castToken(guid, bar)
    if public(guid) and type(guid)=="string" and validID(bar) then
        return "cast:" .. guid .. ":" .. bar
    end
end
-- LOC owns its event/deduplication path. Keep a separate row so an unrelated
-- harmful aura or the window's event order cannot overwrite the LOC evidence.
function window:ObserveLossOfControl(id, name, effect, caster, token, candidate)
    if not db or db.displaySpellIDWindow == false or ns.InitializationBlocked then return false end
    if not validID(id) then return false end
    local shown, reason = present(5, id, name or "Name unavailable", effect, caster, token, candidate)
    return shown or reason == "suppressed"
end
local function scanAuras(unit, updates)
    if unit == "target" and not npcTarget() then
        seen.target = {}
        auraStatus.target = "target excluded (absent, player or player-controlled)"
        return
    end
    local C_UnitAuras = C_UnitAuras or {}
    local targetGUID = read(UnitGUID, "target")
    local updated = {}
    if accessibleTable(updates) and accessibleTable(updates.updatedAuraInstanceIDs) then
        for _, id in ipairs(updates.updatedAuraInstanceIDs) do
            if public(id) and type(id) == "number" then updated[id] = true end
        end
    end
    local current = {}
    local filter = unit == "player" and "HARMFUL" or "HELPFUL"
    local returned, displayed, unchanged, additions = 0, 0, 0, 0
    local problem
    local path = "index"
    local slotFailure
    local function failure(label, errorValue)
        if public(errorValue) and type(errorValue) == "string" then
            return label .. ": " .. errorValue:gsub("[\r\n]", " "):gsub("|", ""):sub(1, 240)
        end
        return label .. " (error text unavailable)"
    end
    local function accept(aura, key, added)
        returned = returned + 1
        if not public(aura) or type(aura) ~= "table" then
            problem = "aura table unavailable"
            return
        end
        -- issecrettable also flags accessible tables whose fields produce secrets.
        -- Check access permission instead; text fields still go only to SetText.
        if type(canaccesstable) == "function" then
            if not canaccesstable(aura) then problem = "aura table access denied"; return end
        elseif not readableTable(aura) then
            problem = "aura table access unavailable"
            return
        end
        local auraSource = read(function() return aura.sourceUnit end)
        if unit == "player" and not npcUnit(auraSource) then return end
        if unit == "target" and (not public(auraSource) or auraSource ~= nil and not npcUnit(auraSource)) then return end
        local ok, instance, spellID, name, effect = pcall(function()
            return aura.auraInstanceID, aura.spellId, aura.name, aura.dispelName
        end)
        if not ok then problem = "aura field access failed"; return end
        -- Public slots track enumeration even when auraInstanceID is secret.
        -- Use public instance identity when available to distinguish slot reuse.
        local identity = true
        if public(instance) and type(instance) == "number" then
            identity = instance
            key = "instance:" .. instance
        else key = path .. ":" .. key end
        current[key] = identity
        if added or seen[unit][key] ~= identity or (identity ~= true and updated[identity]) then
            local source=read(function() return aura.sourceUnit end)
            local caster
            if public(source) and type(source)=="string" and source~="" then caster=read(UnitName,source) end
            local candidate
            if unit == "target" then
                candidate=candidateFor("target", spellID, "buff", targetGUID,
                    "This buff was observed on this creature. Another unit may have cast it.", "Target:")
                if candidate and public(caster) and type(caster) == "string" and caster ~= "" then candidate.casterName=caster end
            else
                local sourceGUID
                if public(source) and source == "target" then sourceGUID=targetGUID end
                candidate=candidateFor(source, spellID, "debuff", sourceGUID,
                    "This creature was identified as the source of the debuff on you.", "Cast by:")
                if not candidate then
                    candidate=candidateFor("target", spellID, "debuff", targetGUID,
                        "Your target when this debuff was detected. The caster is unverified.", "Target:")
                end
            end
            local shown,reason=present(unit == "player" and 3 or 4, spellID, name, effect,caster,"aura:"..unit..":"..key,candidate)
            if shown then
                displayed = displayed + 1
            elseif reason=="locked" then
                unchanged=unchanged+1
                current[key]=nil -- Allow the still-present aura after unlocking.
            elseif reason=="suppressed" then unchanged=unchanged+1
            else
                problem = "aura ID absent or SetText rejected"
                current[key] = nil -- Retry on the next observation.
            end
        else unchanged = unchanged + 1 end
    end
    local completed = true
    if type(C_UnitAuras.GetAuraSlots) == "function" and type(C_UnitAuras.GetAuraDataBySlot) == "function" then
        path = "slots"
        local function pack(...) return { n = select("#", ...), ... } end
        local token
        completed = false
        for page = 1, 16 do
            local result = pack(pcall(C_UnitAuras.GetAuraSlots, unit, filter, 32, token))
            if not result[1] then
                slotFailure = failure("aura slot query failed", result[2])
                problem = slotFailure
                break
            end
            for index = 3, result.n do
                local slot = result[index]
                if public(slot) and type(slot) == "number" then
                    accept(read(C_UnitAuras.GetAuraDataBySlot, unit, slot), slot)
                else problem = "aura slot unavailable" end
            end
            token = result[2]
            if not public(token) then problem = "aura continuation unavailable"; break end
            if token == nil then completed = true; break end
        end
        if not completed and not problem then problem = "aura page limit reached" end
    else completed = false end
    -- Enumerating slots does not guarantee their aura data was readable. A nil
    -- or inaccessible slot result must not prevent the indexed fallback.
    if path == "slots" and problem then slotFailure = slotFailure or problem end
    if (not completed or problem) and displayed == 0 then
        path = slotFailure and "index fallback" or "index"
        completed = false
        if type(C_UnitAuras.GetAuraDataByIndex) == "function" then
            problem = nil
            for index = 1, 255 do
                local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
                if not ok then problem = failure("aura index query failed", aura); break end
                if public(aura) and aura == nil then completed = true; break end
                accept(aura, index)
            end
            if not completed and not problem then problem = "aura index limit reached" end
        else problem = "aura index API unavailable" end
    end
    -- The event can carry a short-lived aura which enumeration no longer
    -- returns (or cannot read). Give additions precedence over the full scan.
    -- Polarity must be public; never mistake a player buff for a debuff.
    local eventStatus = "no additions"
    if accessibleTable(updates) and accessibleTable(updates.addedAuras) then
        eventStatus = "accessible additions"
        auraEventSerial = auraEventSerial + 1
        for index, aura in ipairs(updates.addedAuras) do
            local polarity = accessibleTable(aura) and read(function()
                if unit == "player" then return aura.isHarmful end
                return aura.isHelpful
            end)
            if public(polarity) and polarity == true then
                additions = additions + 1
                accept(aura, "event:" .. auraEventSerial .. ":" .. index, true)
            elseif not public(polarity) then
                eventStatus = "addition polarity restricted"
            end
        end
    elseif not public(updates) or updates ~= nil then
        eventStatus = "addition data unavailable"
    end
    if completed then seen[unit] = current end
    auraStatus[unit] = "path=" .. path .. "; returned=" .. returned .. "; displayed=" .. displayed .. "; unchanged=" .. unchanged
        .. "; event additions=" .. additions
        .. "; " .. eventStatus
        .. (slotFailure and ("; " .. slotFailure) or "")
        .. (problem and problem ~= slotFailure and ("; " .. problem) or "")
end

local function observeCast()
    if not enemyTarget() then return end
    local guid = read(UnitGUID, "target")
    local ok, name, _, _, _, _, _, _, _, id, bar = pcall(UnitCastingInfo, "target")
    if ok and (not public(name) or name ~= nil) then
        if public(bar) and type(bar) == "number" and not castBars[bar] then
            castBars[bar] = true; castBarOrder[#castBarOrder + 1] = bar
            if #castBarOrder > 32 then castBars[table.remove(castBarOrder, 1)] = nil end
        end
        local candidate=candidateFor("target", id, "cast", guid, "This creature was observed casting the spell.", "Cast by:")
        present(1, id, name,nil,read(UnitName,"target"),castToken(guid,bar),candidate)
        return true
    end
    local channelOK, channelName, _, _, _, _, _, _, channelID, _, _, channelBar = pcall(UnitChannelInfo, "target")
    if channelOK and (not public(channelName) or channelName ~= nil) then
        if public(channelBar) and type(channelBar) == "number" and not castBars[channelBar] then
            castBars[channelBar] = true; castBarOrder[#castBarOrder + 1] = channelBar
            if #castBarOrder > 32 then castBars[table.remove(castBarOrder, 1)] = nil end
        end
        local candidate=candidateFor("target", channelID, "cast", guid, "This creature was observed channeling the spell.", "Cast by:")
        present(1, channelID, channelName,nil,read(UnitName,"target"),castToken(guid,channelBar),candidate)
        return true
    end
end
events:SetScript("OnEvent", function(_, event, unit, second, id, bar)
    if ns.InitializationBlocked then return end
    if not db or db.displaySpellIDWindow == false then return end
    if event == "PLAYER_TARGET_CHANGED" then
        updateTargetSuppression();updateFade(0)
        seen.target = {}; castBars = {}; castBarOrder = {}
        scanAuras("target"); observeCast()
    elseif event == "PLAYER_ENTERING_WORLD" then
        updateTargetSuppression();updateFade(0)
        seen = { player = {}, target = {} }; castBars = {}; castBarOrder = {}
        scanAuras("player"); scanAuras("target"); observeCast()
    elseif event == "PLAYER_REGEN_ENABLED" then
        scanAuras("player"); scanAuras("target")
    elseif event == "UNIT_AURA" then
        if public(unit) and unit == "player" then
            playerAuraEvents = playerAuraEvents + 1
            scanAuras("player", second)
            lastPlayerAuraEvent = auraStatus.player
        elseif targetUnit(unit) then scanAuras("target", second) end
    elseif targetUnit(unit) and enemyTarget() then
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local guid = read(UnitGUID, "target")
            if public(bar) and type(bar) == "number" and castBars[bar] then return end
            if observeCast() then return end -- Channels may report success as they begin.
            local info = C_Spell and read(C_Spell.GetSpellInfo, id)
            local instant = readableTable(info) and public(info.castTime) and info.castTime == 0
            local name = C_Spell and read(C_Spell.GetSpellName, id)
            -- Unclassified successes remain casts; SENT alone never proves an instant succeeded.
            local candidate=candidateFor("target", id, "cast", guid, "This creature was observed casting the spell.", "Cast by:")
            present(instant and 2 or 1, id, name, instant and nil or "Succeeded",read(UnitName,"target"),castToken(guid,bar),candidate)
        else observeCast() end
    end
end)
function window:ApplySettings()
    if not db then return end
    setup()
    if ns.AuraTooltipSnapshot then ns.AuraTooltipSnapshot:ApplySettings() end
    panel:StopMovingOrSizing()
    panel:SetMovable(not db.spellIDWindowLocked)
    panel.afbPinned=db.spellIDWindowLocked
    panel:EnableMouse(not db.spellIDWindowLocked)
    updateTargetSuppression()
    background:SetColorTexture(0, 0, 0, db.spellIDWindowAlpha)
    events:UnregisterAllEvents()
    if db.displaySpellIDWindow == false then
        panel:Hide()
        for _, row in ipairs(rows) do clear(row) end
        castTokens,castTokenOrder={},{};castSerial=0
        seen = { player = {}, target = {} }; castBars = {}; castBarOrder = {}
        return
    end
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterUnitEvent("UNIT_AURA", "player", "target")
    events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START" }) do
        events:RegisterUnitEvent(event, "target")
    end
    panel:Show()
    scanAuras("player"); scanAuras("target")
    updateFade(0)
end
function window:AnchorToBook(book)
    if panel and book and not customPosition then
        panel:ClearAllPoints()
        panel:SetPoint("BOTTOMRIGHT",book,"BOTTOMLEFT",-6,0)
    end
end

function window:Initialize(settings)
    db = settings
    if type(db.spellIDWindowBlacklist)~="table" then db.spellIDWindowBlacklist={} end
    db.displaySpellIDWindow = db.displaySpellIDWindow ~= false
    db.spellIDWindowLocked = db.spellIDWindowLocked == true
    db.spellIDWindowIndefinite = db.spellIDWindowIndefinite == true
    db.spellIDWindowAlpha = math.max(0, math.min(1, tonumber(db.spellIDWindowAlpha) or 0.35))
    setup()
    for _, row in ipairs(rows) do clear(row);row.dismissedToken=nil;row.dismissedID=nil end
    castTokens,castTokenOrder={},{};castSerial=0
    seen = { player = {}, target = {} }; castBars = {}; castBarOrder = {}
    panel:ClearAllPoints()
    local position = db.spellIDWindowPosition
    customPosition = false
    local points = { TOP=true, BOTTOM=true, LEFT=true, RIGHT=true, CENTER=true,
        TOPLEFT=true, TOPRIGHT=true, BOTTOMLEFT=true, BOTTOMRIGHT=true }
    if type(position) == "table" and points[position.point] and points[position.relativePoint]
        and type(position.x) == "number" and type(position.y) == "number" then
        local point,relativePoint,x,y=bottomAnchor(position.point,position.relativePoint,position.x,position.y,286)
        panel:SetPoint(point, UIParent, relativePoint,x,y)
        db.spellIDWindowPosition={point=point,relativePoint=relativePoint,x=x,y=y}
        customPosition = true
    else
        panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 30, 100)
        self:AnchorToBook(AzerothFieldbookBestiary)
    end
    if ns.AuraTooltipSnapshot then
        ns.AuraTooltipSnapshot:Initialize(db, panel, function(unit, kind)
            if unit == "player" and kind == "debuff" then return "Debuff on you" end
            if kind == "buff" and targetUnit(unit) and npcTarget() then return "Buff on target" end
        end)
    end
    self:ApplySettings()
    if db.displaySpellIDWindow then observeCast() end
end

function window:Report(say)
    say("ID window player debuffs: " .. auraStatus.player)
    say("ID window player UNIT_AURA events=" .. playerAuraEvents .. "; last event: " .. lastPlayerAuraEvent)
    say("ID window enabled=" .. tostring(db and db.displaySpellIDWindow ~= false)
        .. "; Disarm 6713 blacklisted=" .. tostring(self:IsBlacklisted(6713)))
    say("ID window target buffs: " .. auraStatus.target)
    if ns.AuraTooltipSnapshot then ns.AuraTooltipSnapshot:Report(say) end
end
