local _, ns = ...
local panel, edit, scroll

-- Opt-in, bounded evidence capture. The journal's decision records distinguish
-- actual kill awards from observations and optional research-only API probes.
local killProbe = { enabled = false, rows = {}, last = {}, counts = {}, registrations = {} }
ns.KillDiagnostics = killProbe
local probeEvents = { "PARTY_KILL", "UNIT_DIED", "UNIT_FLAGS", "UNIT_FACTION",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_XP_UPDATE", "UNIT_LOOT" }
local function probeValue(value, kind)
    if issecretvalue and issecretvalue(value) then return "SECRET" end
    if value == nil then return "MISSING" end
    if type(value) ~= kind then return "INVALID" end
    if kind == "string" then
        if value == "" then return "MISSING" end
        return value:gsub("|", ""):gsub("[%c]", " "):sub(1, 120), value
    end
    if kind == "number" and (value ~= value or value == math.huge or value == -math.huge) then return "INVALID" end
    return tostring(value), value
end
local function probeRead(fn, kind, ...)
    if type(fn) ~= "function" then return "API MISSING" end
    local ok, value = pcall(fn, ...)
    if not ok then return "API ERROR" end -- Never retain or print error payloads.
    return probeValue(value, kind)
end
local function probeLoot(guid)
    if not guid then return "GUID UNAVAILABLE" end
    if type(CanLootUnit) ~= "function" then return "API MISSING" end
    -- Build 69977 documents TWO independent booleans. Never interpret the first
    -- as the second, and never call with a restricted GUID or inspect errors.
    local ok, hasLoot, canLoot = pcall(CanLootUnit, guid)
    if not ok then return "API ERROR" end
    return "hasLoot=" .. probeValue(hasLoot, "boolean") .. ",canLoot=" .. probeValue(canLoot, "boolean")
end
function killProbe:Append(line)
    local time = probeRead(GetTime, "number")
    self.rows[#self.rows + 1] = "[" .. time .. "] " .. line
    if #self.rows > 80 then table.remove(self.rows, 1) end
end
function killProbe:Sample(unit, journal, source)
    if not self.enabled then return end
    if issecretvalue and issecretvalue(unit) then return end
    if unit ~= "target" and unit ~= "mouseover" then return end
    self.journal = journal or self.journal
    local guidState, guid = probeRead(UnitGUID, "string", unit)
    local id = guid and tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    local entry = id and self.journal and self.journal.entries[id]
    local tierPoints = entry and self.journal:GetKillReward(id) or 0
    local _, totalPoints = 0, 0
    if self.journal then _, totalPoints = self.journal:GetTotals() end
    local line = unit .. " guid=" .. guidState .. "; npc=" .. (id or "unknown")
        .. "; name=" .. probeRead(UnitName, "string", unit) .. "; level=" .. probeRead(UnitLevel, "number", unit)
        .. "; dead=" .. probeRead(UnitIsDead, "boolean", unit) .. "; hp=" .. probeRead(UnitHealth, "number", unit)
        .. "; exists=" .. probeRead(UnitExists, "boolean", unit)
        .. "; controlled=" .. probeRead(UnitPlayerControlled, "boolean", unit)
        .. "; combat=" .. probeRead(UnitAffectingCombat, "boolean", unit)
        .. "; tapped=" .. probeRead(UnitIsTapped, "boolean", unit)
        .. "; tappedByPlayer=" .. probeRead(UnitIsTappedByPlayer, "boolean", unit)
        .. "; tappedByAllThreatList=" .. probeRead(UnitIsTappedByAllThreatList, "boolean", unit)
        .. "; tapDenied=" .. probeRead(UnitIsTapDenied, "boolean", unit)
        .. "; lootQuery=" .. probeLoot(guid)
        .. "; savedKills=" .. (entry and entry.kills or 0) .. "; killTierPoints=" .. tierPoints
        .. "; totalEarned=" .. totalPoints
        .. "; sample only (no credit inferred from unit state)"
    -- The existing scanner calls this; unchanged samples do not fill the ring.
    if self.last[unit] ~= line then
        self.last[unit] = line
        self:Append((source or "scan") .. ": " .. line)
    end
end
function killProbe:Decision(guid, status, points)
    if not self.enabled then return end
    local line = "decision guid=" .. probeValue(guid, "string") .. "; " .. status
        .. "; killAward=" .. (status == "accepted" and "1" or "0") .. "; killPointsAward=" .. points
    if self.lastDecision ~= line then self:Append(line); self.lastDecision = line end
end
function killProbe:Event(event, first, second)
    if not self.enabled then return end
    self.counts[event] = (self.counts[event] or 0) + 1
    if event == "PARTY_KILL" then
        self:Append(event .. " attacker=" .. probeValue(first, "string")
            .. "; victim=" .. probeValue(second, "string")
            .. "; player=" .. probeRead(UnitGUID, "string", "player")
            .. "; pet=" .. probeRead(UnitGUID, "string", "pet")
            .. "; event payload only (see journal decision lines)")
        -- The payload stays attached to its own GUID, never to a current token.
        self:Sample("target", nil, event)
        self:Sample("mouseover", nil, event)
    elseif event == "UNIT_DIED" or event == "UNIT_LOOT" then
        local guidState, guid = probeValue(first, "string")
        self:Append(event .. " guid=" .. guidState
            .. (event == "UNIT_LOOT" and ("; hasLoot=" .. probeValue(second, "boolean")) or "")
            .. "; lootQuery=" .. probeLoot(guid)
            .. "; event payload only (see journal decision lines)")
    elseif event == "UNIT_FLAGS" or event == "UNIT_FACTION" then
        self:Sample(first, nil, event)
    else
        self:Append(event .. "; context only (never grants credit)")
        self:Sample("target", nil, event)
        self:Sample("mouseover", nil, event)
    end
end
function killProbe:SetEnabled(enabled)
    self.enabled = enabled == true
    if not self.enabled then
        if self.frame then self.frame:UnregisterAllEvents() end
        return
    end
    self.rows, self.last, self.counts, self.registrations = {}, {}, {}, {}
    self.lastDecision = nil
    if not self.frame then
        self.frame = CreateFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, ...) self:Event(...) end)
    end
    for _, event in ipairs(probeEvents) do
        local ok = pcall(self.frame.RegisterEvent, self.frame, event)
        self.registrations[event] = ok and probeRead(self.frame.IsEventRegistered, "boolean", self.frame, event) or "API ERROR"
    end
    local version, build, interface = "API MISSING", "API MISSING", "API MISSING"
    if type(GetBuildInfo) == "function" then
        local ok, v, b, _, i = pcall(GetBuildInfo)
        if ok then
            version, build, interface = probeValue(v, "string"), probeValue(b, "string"), probeValue(i, "number")
        else version, build, interface = "API ERROR", "API ERROR", "API ERROR" end
    end
    self.client = "client=" .. version .. "; build=" .. build .. "; interface=" .. interface
end
function killProbe:Report(say)
    say("Kill evidence recorder: " .. (self.enabled and "ON; qualified kill tracking active." or "OFF."))
    if self.client then say(self.client) end
    if #self.rows == 0 then return end
    say("A kill needs player/pet/party PARTY_KILL, readable eligibility and death for the same observed GUID.")
    say("Probe revision 3: CanLootUnit/legacy tap APIs are research only. Discovery may separately award points.")
    say("Last 80 changed samples/events, session only. Registration success does not prove event delivery or credit.")
    for _, event in ipairs(probeEvents) do
        say(event .. ": registered=" .. (self.registrations[event] or "not attempted") .. "; delivered=" .. (self.counts[event] or 0))
    end
    for _, row in ipairs(self.rows) do say(row) end
end

function ns.ShowDebugReport(report)
    if not panel then
        panel = CreateFrame("Frame", "AzerothFieldbookDebugReport", UIParent, "BackdropTemplate")
        panel:SetSize(740, 540); panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG"); panel:SetClampedToScreen(true)
        panel:SetMovable(true); panel:EnableMouse(true); panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=16})
        panel:SetBackdropColor(0.04, 0.04, 0.04, 0.97)
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 18, -18); title:SetText("Azeroth Fieldbook — Debug report")
        local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 18, -43)
        hint:SetText("Select text and press Ctrl+C to copy. Run /fieldbook debug again for a fresh snapshot.")
        scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -70); scroll:SetPoint("BOTTOMRIGHT", -38, 55)
        edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal)
        edit:SetMaxLetters(0); edit:SetWidth(684); edit:SetHeight(1)
        edit:SetScript("OnEscapePressed", function() panel:Hide() end)
        edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
            local top = -y
            local offset = scroll:GetVerticalScroll()
            if top < offset then scroll:SetVerticalScroll(math.max(0, top))
            elseif top + height > offset + scroll:GetHeight() then
                scroll:SetVerticalScroll(math.max(0, top + height - scroll:GetHeight()))
            end
        end)
        scroll:SetScrollChild(edit)
        ns.AutoHideScrollBar(scroll)
        local selectAll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        selectAll:SetSize(130, 24); selectAll:SetPoint("BOTTOMLEFT", 18, 17)
        selectAll:SetText("Select all")
        selectAll:SetScript("OnClick", function() edit:SetFocus(); edit:HighlightText() end)
        local close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        close:SetSize(100, 24); close:SetPoint("BOTTOMRIGHT", -18, 17); close:SetText("Close")
        close:SetScript("OnClick", function() panel:Hide() end)
        panel:SetScript("OnHide", function() edit:ClearFocus(); panel:StopMovingOrSizing() end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "AzerothFieldbookDebugReport" end
        if UIParent.GetWidth and UIParent.GetHeight then
            panel:SetScale(math.min(1, (UIParent:GetWidth()-30)/740, (UIParent:GetHeight()-30)/540))
        end
    end
    if ns.UIScale then ns.UIScale:Register(panel) end
    panel:Show()
    edit:SetText(report); edit:SetCursorPosition(0)
    scroll:SetVerticalScroll(0)
    edit:SetFocus(); edit:HighlightText()
end
