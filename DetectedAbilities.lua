local _, ns = ...

-- Session-only display evidence. Opaque spell fields go only to rendering APIs;
-- never serialize them, compare them, or read their rendered text back.
function ns.InstallDetectedAbilities(journal)
    local hints, seen = {}, {}
    local function public(value) return not (issecretvalue and issecretvalue(value)) end
    local function id(value)
        return public(value) and type(value)=="number" and value>0 and value<math.huge and value==math.floor(value)
    end
    local function recorded(creature, spellID)
        if not id(spellID) then return false end
        for _, ability in pairs(creature.abilities or {}) do
            if ability.spellID==spellID and ability.state~="rejected" then return true end
        end
        return false
    end
    function journal:GetDetectedAbility(creatureID)
        if not id(creatureID) then return end
        local hint = hints[creatureID]
        local entry = self.entries[creatureID]
        if not entry or (hint and recorded(entry,hint.spellID)) then hints[creatureID]=nil; return end
        return hint
    end
    function journal:DetectAbility(creatureID, spellID, name, castBarID)
        if not id(creatureID) or not self.entries[creatureID] or not self:GetCreatureName(creatureID) then return end
        if public(spellID) and not id(spellID) then return end
        local key = id(castBarID) and castBarID or true
        -- A public cast-bar identity deduplicates polling and target aliases,
        -- including after manually clearing the hint during the same cast.
        if recorded(self.entries[creatureID],spellID) then
            seen[creatureID]=key
            if hints[creatureID] then hints[creatureID]=nil; self:Touch() end
            return
        end
        if seen[creatureID]==key then
            local hint=hints[creatureID]
            if hint and hint.restricted and id(spellID) then
                -- The same public cast-bar token can later supply public spell
                -- evidence. Use that new value without inspecting the old one.
                hint.spellID=spellID; hint.restricted=false; self:Touch()
            end
            if hint and public(hint.name) and hint.name=="Name unavailable"
                and (not public(name) or type(name)=="string" and name~="") then
                hint.name=name; self:Touch()
            end
            return
        end
        seen[creatureID]=key
        if public(name) and (type(name)~="string" or name=="") then
            local ok, value
            if C_Spell and type(C_Spell.GetSpellName)=="function" then ok,value=pcall(C_Spell.GetSpellName,spellID) end
            if ok then name=value end -- Display relay only, including secret output.
        end
        if public(name) and (type(name)~="string" or name=="") then name="Name unavailable" end
        local stamp = date and date("%Y-%m-%d %H:%M:%S") or "This session"
        hints[creatureID]={spellID=spellID,name=name,stamp=stamp,restricted=not public(spellID)}
        self:Touch()
    end
    function journal:FinishDetectedCast(creatureID)
        if seen[creatureID]==true then seen[creatureID]=nil end
    end
    -- A manual linked save acknowledges the current opaque hint; it does not
    -- establish a mapping from a secret to the user-entered public spell ID.
    function journal:AcknowledgeDetectedAbility(creatureID,spellID)
        if not id(creatureID) then return end
        local hint=hints[creatureID]
        if not hint or not id(spellID) then return end
        if hint.restricted or hint.spellID==spellID then
            hints[creatureID]=nil; self:Touch()
        end
    end
    local delete=journal.DeleteEntry
    function journal:DeleteEntry(creatureID)
        local a,b=delete(self,creatureID)
        if not self.entries[creatureID] then hints[creatureID],seen[creatureID]=nil,nil end
        return a,b
    end
    local reset=journal.Reset
    function journal:Reset(...)
        hints,seen={},{}
        return reset(self,...)
    end
end

function ns.CreateDetectedAbilityHint(parent,journal)
    local frame=CreateFrame("Frame",nil,parent)
    frame:SetSize(583,30)
    local function text(x,y,width)
        local f=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        f:SetPoint("TOPLEFT",x,y);f:SetSize(width,14);f:SetJustifyH("LEFT");f:SetWordWrap(false)
        return f
    end
    frame.heading=text(0,0,583);frame.heading:SetTextColor(0.5,0.82,1)
    frame.ability=text(0,-14,583)
    local current
    function frame:Refresh(creatureID)
        current=journal.GetDetectedAbility and journal:GetDetectedAbility(creatureID)
        self:SetShown(current~=nil)
        if not current then
            self.ability:SetText("")
            return
        end
        self.heading:SetText("Last observed ability  |cff999999(" .. current.stamp .. ")|r")
        self.ability:SetText("")
        -- Native SetFormattedText accepts opaque arguments. The renderer lays
        -- these out inline; Lua never formats, measures or reads secret text.
        local shown=pcall(self.ability.SetFormattedText,self.ability,
            "|cffffff00%s|r  |cff999999Spell ID:|r |cffffffff%s|r",current.name,current.spellID)
        if not shown then self:Hide() end
    end
    frame:EnableMouse(true)
    frame:SetScript("OnEnter",function(self)
        if not current or not GameTooltip then return end
        GameTooltip:SetOwner(self,"ANCHOR_CURSOR")
        local ok=type(GameTooltip.SetSpellByID)=="function" and pcall(GameTooltip.SetSpellByID,GameTooltip,current.spellID)
        if not ok then
            GameTooltip:Hide()
            return
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    frame:Hide()
    return frame
end
