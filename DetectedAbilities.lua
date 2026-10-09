local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end

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
    function journal:GetDetectedAbilities(creatureID)
        if not id(creatureID) then return end
        local list = hints[creatureID]
        local entry = self.entries[creatureID]
        if not entry then hints[creatureID]=nil; return end
        if list then
            for index=#list,1,-1 do
                if recorded(entry,list[index].spellID) then table.remove(list,index) end
            end
            if #list>0 then return list end
        end
    end
    function journal:GetDetectedAbility(creatureID)
        local list=self:GetDetectedAbilities(creatureID)
        return list and list[#list]
    end
    function journal:DetectAbility(creatureID, spellID, name, castBarID)
        if not id(creatureID) or not self.entries[creatureID] or not self:GetCreatureName(creatureID) then return end
        if public(spellID) and not id(spellID) then return end
        local key = id(castBarID) and castBarID or true
        local history=seen[creatureID]
        if not history then history={keys={},order={}};seen[creatureID]=history end
        local duplicate=history.keys[key]
        if not duplicate then
            history.keys[key]=true
            if key~=true then
                history.order[#history.order+1]=key
                if #history.order>32 then history.keys[table.remove(history.order,1)]=nil end
            end
        end
        local list=hints[creatureID] or {}
        local hint
        for _,value in ipairs(list) do if value.key==key then hint=value;break end end
        -- A public cast-bar identity deduplicates polling and target aliases,
        -- including after manually clearing the hint during the same cast.
        if recorded(self.entries[creatureID],spellID) then
            for index=#list,1,-1 do
                if list[index]==hint or recorded(self.entries[creatureID],list[index].spellID) then
                    table.remove(list,index);self:Touch()
                end
            end
            return
        end
        if duplicate then
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
        if public(name) and (type(name)~="string" or name=="") then
            local ok, value
            if C_Spell and type(C_Spell.GetSpellName)=="function" then ok,value=pcall(C_Spell.GetSpellName,spellID) end
            if ok then name=value end -- Display relay only, including secret output.
        end
        if public(name) and (type(name)~="string" or name=="") then name="Name unavailable" end
        local stamp = date and date("%Y-%m-%d %H:%M:%S") or "This session"
        list[#list+1]={spellID=spellID,name=name,stamp=stamp,restricted=not public(spellID),key=key}
        if #list>4 then table.remove(list,1) end
        hints[creatureID]=list
        self:Touch()
    end
    function journal:FinishDetectedCast(creatureID)
        if seen[creatureID] then seen[creatureID].keys[true]=nil end
        -- A later cast without a public token must not enrich an older slot.
        for _,hint in ipairs(hints[creatureID] or {}) do if hint.key==true then hint.key=nil end end
    end
    function journal:DismissDetectedAbility(creatureID,hint)
        if not id(creatureID) then return end
        local list=hints[creatureID] or {}
        for index,value in ipairs(list) do
            if value==hint then table.remove(list,index);self:Touch();return end
        end
    end
    -- Preserve the single-hint acknowledgement. With multiple opaque hints a
    -- linked save cannot identify which one the player transcribed; dismiss
    -- those slots explicitly instead of erasing unrelated evidence.
    function journal:AcknowledgeDetectedAbility(creatureID,spellID)
        if not id(creatureID) then return end
        local list=hints[creatureID]
        if not list or not id(spellID) then return end
        local single=#list==1
        for index=#list,1,-1 do
            local hint=list[index]
            if hint.restricted and single or not hint.restricted and hint.spellID==spellID then
                table.remove(list,index);self:Touch()
            end
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
    local function text(owner,x,y,width)
        local f=owner:CreateFontString(nil,"OVERLAY",textFont("GameFontHighlightSmall"))
        f:SetPoint("TOPLEFT",x,y);f:SetSize(width,14);f:SetJustifyH("LEFT");f:SetWordWrap(false)
        return f
    end
    frame.heading=text(frame,0,0,583);frame.heading:SetTextColor(0.5,0.82,1)
    frame.heading:SetText("Last detected spells:  |cff999999Oldest first / Right-click a slot to clear|r")
    frame.slots={}
    local selected
    for index=1,4 do
        local slot=CreateFrame("Frame",nil,frame)
        slot:SetSize(145,14);slot:SetPoint("TOPLEFT",(index-1)*146,-14)
        slot.ability=text(slot,0,0,145)
        frame.slots[index]=slot
        slot:EnableMouse(true)
        slot:SetScript("OnMouseUp",function(_,button)
            if button=="RightButton" and slot.current and not ns.InitializationBlocked then
                journal:DismissDetectedAbility(selected,slot.current)
                if GameTooltip then GameTooltip:Hide() end
                frame:Refresh(selected)
            end
        end)
        slot:SetScript("OnEnter",function(self)
            if not self.current or not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_CURSOR")
            local ok=type(GameTooltip.SetSpellByID)=="function" and pcall(GameTooltip.SetSpellByID,GameTooltip,self.current.spellID)
            if not ok then GameTooltip:Hide();return end
            if GameTooltip.AddLine then GameTooltip:AddLine("Detected: " .. self.current.stamp,0.6,0.6,0.6) end
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    end
    function frame:Refresh(creatureID)
        selected=creatureID
        local list=journal.GetDetectedAbilities and journal:GetDetectedAbilities(creatureID)
        local shown=false
        for index,slot in ipairs(self.slots) do
            slot.current=list and list[index]
            slot.ability:SetText("")
            local rendered=false
            if slot.current then
                -- Only the native renderer formats the potentially opaque ID.
                rendered=pcall(slot.ability.SetFormattedText,slot.ability,
                    "|cff999999" .. index .. ":|r |cffffffff%s|r",slot.current.spellID)
            end
            slot:SetShown(rendered)
            shown=shown or rendered
        end
        self:SetShown(shown)
    end
    frame:Hide()
    return frame
end
