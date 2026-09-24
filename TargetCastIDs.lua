-- Direct presentation of Forever cast IDs. Never read back or measure secret text.
local _, ns = ...
local enabled, panel, idText, stateText, debugEnabled
local settings
local display = {}
ns.CastIDs = display
local current = "disabled"
local lastAttempt = "none"
local events = CreateFrame("Frame")
local lingerSeconds = 60
local generation = 0
local presented, lingering = false, false
local dismissed = false
local activeCastBarID
local traceFrame
local trace = {}
local successReceived, successMatched, sentReceived = 0, 0, 0

local function DebugUnitLabel(unit)
    if issecretvalue(unit) then return "secret unit token" end
    if type(unit) ~= "string" then return "non-string unit token" end
    if unit == "target" then return "target" end
    if unit:match("^nameplate") then return "nameplate token" end
    local ok, same
    if type(UnitIsUnit) == "function" then ok, same = pcall(UnitIsUnit, unit, "target") end
    if ok and not issecretvalue(same) and same == true then return "target alias" end
    return "other unit token"
end

local function IsTarget(unit)
    if issecretvalue(unit) then return false end
    if unit == "target" then return true end
    if type(unit) ~= "string" or type(UnitIsUnit) ~= "function" then return false end
    -- Only test the supplied event token against target; never enumerate units.
    local ok, same = pcall(UnitIsUnit, unit, "target")
    return ok and not issecretvalue(same) and same == true
end

local function Clear(reason)
    generation = generation + 1
    presented, lingering = false, false
    activeCastBarID = nil
    current = reason
    if panel then
        panel:Hide()
        -- Public empty replacement; deliberately do not remove secret aspects.
        idText:SetText("")
    end
end

local function Linger()
    if lingering then return end -- Duplicate stop events must not extend the timer.
    if not presented then Clear("no cast/channel"); return end
    lingering = true
    current = "cast/channel ended; ID lingering"
    if debugEnabled then stateText:SetText(current) end
    local token = generation
    -- Keep the already-rendered secret text in place; never read it back.
    C_Timer.After(lingerSeconds, function()
        if token == generation then Clear("linger expired") end
    end)
end

local function Setup()
    if panel then return true end
    if InCombatLockdown() then
        current = "setup deferred until out of combat"
        return false
    end
    local bar = TargetFrame and TargetFrame.spellbar
    if not bar then
        current = "TargetFrame.spellbar unavailable"
        return false
    end
    -- Independent parent avoids becoming a child of the secure target button.
    -- Establish this one-way anchor out of combat; never modify Blizzard's bar.
    panel = CreateFrame("Frame", nil, UIParent)
        if ns.UIScale then ns.UIScale:Register(panel) end
    panel:Hide()
    panel:SetSize(180, 14)
    panel:SetFrameStrata("HIGH")
    panel:SetPoint("BOTTOM", bar, "TOP", 0, 5)
    panel:EnableMouse(true)
    panel:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            dismissed = true
            Clear("dismissed")
        end
    end)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetSize(85, 14)
    label:SetJustifyH("LEFT")
    label:SetText("Last Spell ID:")
    idText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    idText:SetPoint("TOPLEFT", 88, 0)
    idText:SetSize(92, 14)
    idText:SetJustifyH("LEFT")
    stateText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stateText:SetPoint("BOTTOM", panel, "TOP", 0, 2)
    stateText:SetSize(240, 14)
    stateText:SetJustifyH("LEFT")
    stateText:Hide()
    return true
end

local function Eligible()
    -- These predicates have public returns in build 69977. Fail closed if that changes.
    local exists = UnitExists("target")
    local enemy = UnitIsEnemy("player", "target")
    local controlled = UnitPlayerControlled("target")
    if issecretvalue(exists) or issecretvalue(enemy) or issecretvalue(controlled) then
        return false
    end
    return exists and enemy and not controlled
end

local function Present(kind, spellID)
    Clear("new cast/channel")
    local secret = issecretvalue(spellID)
    local visibility = secret and "secret" or "public"
    -- Only the public branch may inspect the ID. The secret branch passes it through.
    if not secret then
        if spellID == nil then
            current = kind .. ": ID absent"
            lastAttempt = current
            if debugEnabled then stateText:SetText(current); stateText:Show(); panel:Show() end
            return
        end
        if type(spellID) ~= "number" then
            current = kind .. ": unexpected public ID type"
            lastAttempt = current
            if debugEnabled then stateText:SetText(current); stateText:Show(); panel:Show() end
            return
        end
    end
    -- pcall's success boolean is public; never inspect or print its error payload.
    local accepted = pcall(idText.SetText, idText, spellID)
    presented = accepted
    current = kind .. " " .. visibility .. (accepted and ": SetText accepted" or ": SetText rejected")
    lastAttempt = current
    if debugEnabled and not secret then
        lastAttempt = lastAttempt .. "; public API ID=" .. tostring(spellID)
    end
    if debugEnabled then stateText:SetText(current); stateText:Show() else stateText:Hide() end
    if accepted or debugEnabled then panel:Show() end
    -- Acceptance is NOT proof of visible rendering. The player must observe the number.
end

local function Refresh()
    if not enabled then return end
    if dismissed then return end
    if not Eligible() then Clear("no applicable target"); return end
    if not Setup() then return end

    local ok, name, _, _, _, _, _, _, _, spellID, castBarID = pcall(UnitCastingInfo, "target")
    if not ok then
        Clear("UnitCastingInfo API call failed")
        lastAttempt = current
        return
    end
    -- Never branch on a secret name; the public secrecy predicate short-circuits first.
    if issecretvalue(name) or name ~= nil then
        Present("cast", spellID)
        activeCastBarID = castBarID
        return
    end
    local channelOK, channelName, _, _, _, _, _, _, channelID, _, _, channelBarID = pcall(UnitChannelInfo, "target")
    if not channelOK then
        Clear("UnitChannelInfo API call failed")
        lastAttempt = current
        return
    end
    if issecretvalue(channelName) or channelName ~= nil then
        Present("channel", channelID)
        activeCastBarID = channelBarID
        return
    end
    Linger()
end

local stopEvents = {
    UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_EMPOWER_STOP = true,
}
local unitEvents = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_FACTION",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_SENT",
}
events:SetScript("OnEvent", function(_, event, unit, arg2, arg3, arg4, arg5)
    if not enabled then return end
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
            dismissed = false
            Clear("target/world changed")
        end
        Setup()
        Refresh()
    elseif IsTarget(unit) then
        if event == "UNIT_SPELLCAST_SENT" then
            -- Forever's SENT payload is unit, targetName, castGUID, spellID.
            -- This is the remaining direct path when a secret instant cast has
            -- no START/SUCCEEDED event. The targetName and GUID stay untouched.
            if not Eligible() then Clear("no applicable target"); return end
            if not Setup() then return end
            dismissed = false
            Present("sent event", arg4)
            if presented then Linger() end
            return
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if not Eligible() then Clear("no applicable target"); return end
            if not Setup() then return end
            -- Channels can succeed at their start. Preserve the active lifecycle.
            -- Compare only the documented NeverSecret castBarID, never spellID/GUID.
            if not issecretvalue(arg4) and not issecretvalue(activeCastBarID)
                and arg4 ~= nil and arg4 == activeCastBarID
                and presented and not lingering then return end
            dismissed = false
            Present("succeeded event", arg3)
            if presented then Linger() end
            return
        end
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
            or event == "UNIT_SPELLCAST_EMPOWER_START" then
            dismissed = false
            Clear("new cast/channel")
        end
        if stopEvents[event] then
            Linger()
            -- One deferred query handles stop/start ordering without a polling loop.
            local token = generation
            C_Timer.After(0, function()
                if token == generation then Refresh() end
            end)
        else
            Refresh()
        end
    end
end)

function display:SetEnabled(value)
    dismissed = false
    if settings then settings.displayCastIDs = value == true end
    enabled = value == true and type(issecretvalue) == "function"
    events:UnregisterAllEvents()
    if not enabled then
        Clear("disabled")
    else
        events:RegisterEvent("PLAYER_TARGET_CHANGED")
        events:RegisterEvent("PLAYER_LOGIN")
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        for _, event in ipairs(unitEvents) do
            if event == "UNIT_SPELLCAST_SUCCEEDED" then
                events:RegisterEvent(event) -- Accept legally comparable aliases of target too.
            else
                events:RegisterUnitEvent(event, "target")
            end
        end
        Setup()
        Refresh()
    end
end

function display:Initialize(db)
    settings = db
    self:SetEnabled(db.displayCastIDs ~= false)
end

function display:SetDebug(value)
    debugEnabled = value == true
    if debugEnabled then
        trace = {}
        successReceived, successMatched, sentReceived = 0, 0, 0
        if not traceFrame then
            traceFrame = CreateFrame("Frame")
            traceFrame:SetScript("OnEvent", function(_, event, unit, second, third, fourth)
                if event == "UNIT_SPELLCAST_SUCCEEDED" then successReceived = successReceived + 1 end
                if event == "UNIT_SPELLCAST_SENT" then sentReceived = sentReceived + 1 end
                local targetMatch = IsTarget(unit)
                if targetMatch and event == "UNIT_SPELLCAST_SUCCEEDED" then successMatched = successMatched + 1 end
                local spellID = third
                if event == "UNIT_SPELLCAST_SENT" then spellID = fourth end
                local classification
                if issecretvalue(spellID) then classification = "secret ID"
                elseif spellID == nil then classification = "ID absent"
                elseif type(spellID) == "number" then classification = "public numeric ID"
                else classification = "unexpected public ID type" end
                if #trace == 12 then table.remove(trace, 1) end
                trace[#trace + 1] = event .. " (" .. DebugUnitLabel(unit) .. "; target match="
                    .. (targetMatch and "yes" or "no") .. "): " .. classification
            end)
        end
        for _, event in ipairs(unitEvents) do
            if event ~= "UNIT_FACTION" then traceFrame:RegisterEvent(event) end
        end
        traceFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
        traceFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
    elseif traceFrame then
        traceFrame:UnregisterAllEvents()
    end
    if stateText then stateText:Hide() end
    Refresh()
end

function display:Report(say)
    say("Cast IDs: " .. current .. "; last attempt: " .. lastAttempt)
    say(enabled and "Cast ID display enabled." or "Cast ID display disabled.")
    if panel and type(panel.IsRectValid) == "function" then
        local ok, valid = pcall(panel.IsRectValid, panel)
        if ok and not issecretvalue(valid) then
            say(valid and "Cast ID display has a valid layout rectangle." or "Cast ID display has no valid layout rectangle.")
        end
    end
    if debugEnabled then
        say("Since debug on: success events received=" .. successReceived .. "; matched to target=" .. successMatched
            .. "; sent events received=" .. sentReceived)
        say("Latest cast events (up to 12; no IDs logged):")
        for _, entry in ipairs(trace) do say(entry) end
        if #trace == 0 then say("No target cast events received. An absent event cannot supply a Spell ID.") end
    end
end
