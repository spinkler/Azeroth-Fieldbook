local addonName, ns = ...
BINDING_NAME_CLASSICBESTIARY_BOOK = "Open / close Azeroth Fieldbook Bestiary"
BINDING_NAME_CLASSICBESTIARY_MOUSEOVER_BOOK = "Open Azeroth Fieldbook Bestiary at mouseover"
local effectGroups = {
    { "Control", { "Stun", "Root/Immobilize", "Slow/Snare", "Daze", "Fear", "Horror", "Disorient", "Sleep/Incapacitate", "Polymorph/Transform", "Charm/Possession", "Banish", "Knockback/Pull", "Disarm", "Silence" } },
    { "Combat", { "Interrupt", "School Lockout", "Damage over Time", "Heal", "Heal over Time", "Shield/Absorb", "Damage Reduction", "Damage Vulnerability", "Enrage", "Immunity/Invulnerability" } },
    { "Dispel type", { "Magic", "Curse", "Disease", "Poison" } },
}

local function addonVersion()
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        local ok, version = pcall(C_AddOns.GetAddOnMetadata, addonName, "Version")
        if ok and type(version) == "string" and version ~= "" then return version end
    end
    return "unknown"
end

-- Pack complete property groups before letting the font wrap an oversized
-- group. Each returned paragraph gets its own hanging-indent FontString.
function ns.GroupPropertyLines(groups,width,measure)
    local lines,current={},nil
    for _,group in ipairs(groups) do
        local combined=current and (current .. "  •  " .. group) or group
        if current and measure(combined)>width then
            lines[#lines+1]=current
            current=group
        else current=combined end
        if measure(current)>width then
            lines[#lines+1]=current
            current=nil
        end
    end
    if current then lines[#lines+1]=current end
    return lines
end

local function createKillReward(parent,crownOffset)
    crownOffset=crownOffset or 2
    local reward=CreateFrame("Frame",nil,parent)
    reward:SetSize(14,14);reward:EnableMouse(false)
    reward.parts,reward.crownParts={},{}
    local function artwork(name,parts)
        local texture=reward:CreateTexture(nil,"ARTWORK")
        texture:SetAllPoints(reward)
        texture:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\" .. name)
        texture:SetVertexColor(1,0.82,0.14,1)
        local shadow=reward:CreateTexture(nil,"BACKGROUND")
        shadow:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\" .. name)
        shadow:SetPoint("TOPLEFT",texture,"TOPLEFT",1,-1)
        shadow:SetPoint("BOTTOMRIGHT",texture,"BOTTOMRIGHT",1,-1)
        shadow:SetVertexColor(0,0,0,0.7)
        texture.shadow=shadow
        parts[1]=texture
    end
    artwork("RewardStar.tga",reward.parts)
    artwork("RewardCrown.tga",reward.crownParts)
    reward.crownParts[1]:ClearAllPoints()
    reward.crownParts[1]:SetPoint("TOPLEFT",reward,"TOPLEFT",0,crownOffset)
    reward.crownParts[1]:SetPoint("BOTTOMRIGHT",reward,"BOTTOMRIGHT",0,crownOffset)
    function reward:SetReward(star)
        self:SetShown(star~=nil)
        for _,part in ipairs(self.parts) do
            part:SetShown(star~="crown")
            part.shadow:SetShown(star~="crown")
            if star=="gold" then part:SetVertexColor(1,0.82,0.14,1)
            else part:SetVertexColor(0.78,0.82,0.88,1) end
        end
        for _,part in ipairs(self.crownParts) do
            part:SetShown(star=="crown")
            part.shadow:SetShown(star=="crown")
        end
    end
    reward:SetReward(nil)
    return reward
end

local function addNameScroller(row)
    local viewport=CreateFrame("ScrollFrame",nil,row)
    viewport:SetPoint("TOPLEFT",17,0);viewport:SetSize(140,28);viewport:EnableMouse(false)
    local body=CreateFrame("Frame",nil,viewport)
    body:SetSize(140,28);body:EnableMouse(false);viewport:SetScrollChild(body)
    local text=body:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    text:SetPoint("TOPLEFT",0,-8);text:SetJustifyH("LEFT");text:SetWordWrap(false)
    text:SetShadowColor(0.05,0.05,0.05)
    row.nameViewport,row.scrollingName=viewport,text
    function row:StopNameScroll()
        self:SetScript("OnUpdate",nil)
        viewport:SetHorizontalScroll(0);viewport:Hide();self.text:Show()
    end
    row:SetScript("OnEnter",function(self)
        local width=self.text:GetUnboundedStringWidth()
        if type(width)~="number" then width=self.text:GetStringWidth() end
        local visible=self.text:GetWidth()
        if not self.id or type(width)~="number" or width<=visible then return end
        width=math.ceil(width)+1
        viewport:SetWidth(visible);body:SetWidth(width);text:SetWidth(width)
        text:SetText(self.text:GetText());text:SetTextColor(self.text:GetTextColor())
        text:SetAlphaGradient(visible-20,20)
        self.text:Hide();viewport:Show();viewport:SetHorizontalScroll(0)
        local elapsed,distance=0,width-visible
        local travel=distance/24 -- Gentle movement in UI pixels per second.
        self:SetScript("OnUpdate",function(_,dt)
            elapsed=(elapsed+dt)%(travel*2+2)
            local position
            if elapsed<0.8 then position=0
            elseif elapsed<0.8+travel then position=(elapsed-0.8)*24
            elseif elapsed<2+travel then position=distance
            else position=distance-(elapsed-2-travel)*24 end
            viewport:SetHorizontalScroll(position)
            -- Fade into the stationary right edge while travelling, then show
            -- the complete ending during the pause. The viewport clips the left.
            if position<distance then text:SetAlphaGradient(position+visible-20,20)
            else text:ClearAlphaGradient() end
        end)
    end)
    row:SetScript("OnLeave",function(self) self:StopNameScroll() end)
    row:SetScript("OnHide",function(self) self:StopNameScroll() end)
    row:StopNameScroll()
end

function ns.CreateBestiaryBook(journal)
    local book, selected, offset, abilityOffset = nil, nil, 0, 0
    local creaturePageSize = 16
    local creatureNotes = ns.CreateCreatureNotesWindow and ns.CreateCreatureNotesWindow(journal,function() return book end)
    local sharingWindow = journal.sharing and ns.CreateSharingWindow and ns.CreateSharingWindow(journal,journal.sharing,function() return book end)
    local function basicInfo(id) return journal.GetBasicInfo and journal:GetBasicInfo(id) or journal.entries[id] end
    local noteOffset, refreshDamageNotes = 0, nil
    local category, initial, reviewOnly = nil, nil, false
    local indexOpen = false
    local locationFilters, rankFilters = {}, {}
    local typeOrder = { "Beast", "Humanoid", "Dragonkin", "Demon", "Elemental", "Giant", "Undead", "Mechanical", "Critter", "Aberration", "Other" }
    local magicSchools = {
        { name="Arcane", color="d884ff" }, { name="Fire", color="ff7043" },
        { name="Frost", color="69ccf0" }, { name="Holy", color="fff09a" },
        { name="Nature", color="72d65b" }, { name="Shadow", color="b79cff" },
    }
    local behaviourOrder = { "Hostile", "Neutral", "Melee", "Ranged", "Caster", "Flees at low health", "Calls allies", "Patrols", "Summons", "Heals", "Enrages", "Stealths" }
local ink = { 0.75, 0.8, 0.8 }
    local inkShadow = { 0.05, 0.05, 0.05 }
    local function label(parent, text, x, y, width, size)
        local font = parent:CreateFontString(nil, "OVERLAY", size or "GameFontHighlight")
        font:SetPoint("TOPLEFT", x, y)
        font:SetWidth(width)
        font:SetJustifyH("LEFT")
        font:SetTextColor(unpack(ink))
        font:SetShadowColor(unpack(inkShadow))
        font:SetText(text)
        return font
    end
    local function layoutSummary(status,combat)
        local y=0
        local function section(groups,rows,fontObject)
            book.summaryMeasure:SetFontObject(fontObject)
            local lines=ns.GroupPropertyLines(groups,574,function(text)
                book.summaryMeasure:SetText(text)
                return book.summaryMeasure:GetStringWidth()
            end)
            for i,text in ipairs(lines) do
                local row=rows[i]
                if not row then
                    row=label(book.summaryArea,"",0,0,574,fontObject)
                    row:SetWordWrap(true); row:SetIndentedWordWrap(true)
                    row:SetJustifyV("TOP")
                    rows[i]=row
                end
                row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-y)
                row:SetText(text); row:Show()
                y=y+row:GetStringHeight()+2
            end
            for i=#lines+1,#rows do rows[i]:SetText(""); rows[i]:Hide() end
        end
        section(status,book.summaryBasicRows,"GameFontHighlight")
        section(combat,book.summaryCombatRows,"GameFontHighlightSmall")
        local height=math.max(16,y)
        book.summaryArea:SetHeight(height)
        -- All summary text stays visible. Grow the book and move the content
        -- below it together, preserving panel sizes and space for the footer.
        local extra=math.max(0,84+height+5-133)
        book.detail:ClearAllPoints(); book.detail:SetPoint("TOPLEFT",0,-extra)
        book:SetHeight(740+extra)
    end
    local function button(parent, text, x, y, width, action)
        local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        b:SetSize(width, 24)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(text)
        b:SetScript("OnClick", action)
        return b
    end
    local function cornerClose(parent)
        local close=CreateFrame("Button",nil,parent,"UIPanelCloseButton")
        close:SetPoint("TOPRIGHT",-3,-3)
        close:SetScript("OnClick",function() parent:Hide() end)
        parent.closeButton=close
        return close
    end
    local filterFonts={}
    local function filterFont(base)
        if not filterFonts[base] then
            local name="AzerothFieldbookFilter"..base
            local font=CreateFont(name)
            font:CopyFontObject(_G[base])
            local path,size,flags=font:GetFont()
            if path and size then font:SetFont(path,math.max(1,size-1),flags) end
            filterFonts[base]=name
        end
        return filterFonts[base]
    end
    local function styleSelection(control,keepGoldText,borderOnly)
        if not borderOnly then
            control:SetHighlightTexture("")
            control:SetDisabledFontObject(filterFont("GameFontDisable"))
        end
        -- Crop the native bevel only; the red face is never tinted or brightened.
        local borders={}
        local function border(source,l,r,t,b,x1,y1,x2,y2)
            for layer=0,1 do
                local piece=control:CreateTexture(nil,"BORDER",nil,layer)
                piece:SetPoint("TOPLEFT",source,"TOPLEFT",x1,y1)
                piece:SetPoint("BOTTOMRIGHT",source,"BOTTOMRIGHT",x2,y2)
                piece:SetTexCoord(l,r,t,b)
                piece:SetVertexColor(1,1,0)
                piece:SetBlendMode(layer==0 and "BLEND" or "ADD")
                borders[#borders+1]={texture=piece,source=source}
            end
        end
        local function refreshBorder()
            for _,part in ipairs(borders) do
                part.texture:SetTexture(part.source:GetTexture())
                part.texture:SetShown(control.afbSelected and control:IsEnabled())
            end
        end
        -- UIPanelButtonTemplate uses a 128x32 texture with an 80x22 button,
        -- split into 12px end caps and a stretching middle. Its outer 4px
        -- contain the bevel; copying those pixels preserves the native shape.
        local function createBorder()
            local height=control:GetHeight()
            local edge=height*4/22
            for _,slice in ipairs({{"Left",0,12},{"Middle",12,68},{"Right",68,80}}) do
                local source=control[slice[1]]
                if source and type(source)~="function" then
                    border(source,slice[2]/128,slice[3]/128,0,4/32,0,0,0,height-edge)
                    border(source,slice[2]/128,slice[3]/128,18/32,22/32,0,-height+edge,0,0)
                    if slice[1]=="Left" then
                        border(source,0,4/128,4/32,18/32,0,-edge,-8,edge)
                    elseif slice[1]=="Right" then
                        border(source,76/128,80/128,4/32,18/32,8,-edge,0,edge)
                    end
                end
            end
        end
        control.SetSelected=function(self,selected)
            if not borderOnly then
                local font=filterFont((selected or keepGoldText) and "GameFontNormal" or "GameFontDisable")
                self:SetNormalFontObject(font)
                self:SetHighlightFontObject(font)
            end
            self.afbSelected=selected
            if selected and #borders==0 then createBorder() end
            refreshBorder()
        end
        for _,event in ipairs({"OnMouseDown","OnMouseUp","OnEnable","OnDisable","OnShow"}) do
            control:HookScript(event,refreshBorder)
        end
        control:SetSelected(false)
    end
    local function edit(parent, x, y, width, limit)
        local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        e:SetSize(width, 22)
        e:SetPoint("TOPLEFT", x, y)
        e:SetAutoFocus(false)
        e:SetMaxLetters(limit)
        e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        return e
    end
    local function safeModel(id)
        book.model:ClearModel()
        book.model:Hide()
        book.modelCaption:SetText("Illustration not available yet")
        if not id then return end
        -- Query appearance only for an already encountered NPC. Never scan IDs.
        local ok = pcall(book.model.SetCreature, book.model, id)
        if ok then
            book.model:Show()
        end
    end
    local refresh
    local rumoursWindow = ns.CreateRumoursWindow and ns.CreateRumoursWindow(journal,function()
        if book then refresh() end
        if sharingWindow then sharingWindow:Refresh() end
    end,function()
        return book, creatureNotes and creatureNotes:GetFrame()
    end)
    local function message(text) book.message:SetText(text or "") end
    local function effectsText(effects)
        local names={}
        for name,enabled in pairs(effects or {}) do if enabled then names[#names+1]=name end end
        table.sort(names)
        return #names>0 and table.concat(names,", ") or nil
    end
    local function effectButtonText(effects)
        local count=0
        for _,enabled in pairs(effects or {}) do if enabled then count=count+1 end end
        return count>0 and ("Effects ("..count..")") or "Choose effects"
    end
    local function choose(id)
        if book.deleteForm then book.deleteForm:Hide() end
        if book.beastLore then
            book.beastLore.area:SetVerticalScroll(0)
            book.beastLore.status:SetText("Free to send • 0 Knowledge")
        end
        selected, abilityOffset = id, 0
        if creatureNotes then creatureNotes:SetCreature(id) end
        if rumoursWindow then rumoursWindow:SetCreature(id) end
        book.manualName:SetText(""); book.manualNote:SetText(""); book.spellLink:SetText("")
        book.manualEffects={}; if book.effectButton then book.effectButton:SetText("Choose effects") end
        book.damageForm:Hide()
        message("")
        safeModel(id)
        refresh()
    end
    local function cycleEntry(direction)
        local rows=journal:List(category,book.search:GetText(),reviewOnly,initial,locationFilters,rankFilters)
        if #rows==0 then return end
        local current
        for i,row in ipairs(rows) do if row.id==selected then current=i; break end end
        if not current then current=direction>0 and 0 or 1 end
        local nextIndex=((current-1+direction)%#rows)+1
        offset=math.floor((nextIndex-1)/creaturePageSize)*creaturePageSize
        choose(rows[nextIndex].id)
    end
    refresh = function()
        if not book then return end
        local available = {}
        for id in pairs(journal.entries) do
            local e=basicInfo(id)
            local displayCategory = journal:GetCategoryFilter(e.category)
            available[displayCategory] = true
        end
        if category and not available[category] then category = nil end
        for name, typeButton in pairs(book.typeButtons) do
            local selectedType=(name == "All creatures" and category == nil) or category == name
            typeButton:Show()
            typeButton:SetEnabled(name == "All creatures" or available[name] == true)
            typeButton:SetSelected(selectedType)
        end
        book.indexButton:SetSelected(indexOpen)
        local observedLocations = {}
        for id in pairs(journal.entries) do
            local entry=basicInfo(id)
            for location in pairs(entry.locations or {}) do observedLocations[location] = true end
        end
        for location in pairs(locationFilters) do
            if not observedLocations[location] then locationFilters[location] = nil end
        end
        local locationCount = 0
        for _ in pairs(locationFilters) do locationCount = locationCount + 1 end
        book.locationsButton:SetText(locationCount > 0 and ("Locations (" .. locationCount .. ")") or "Locations")
        local rankCount = 0
        for _ in pairs(rankFilters) do rankCount = rankCount + 1 end
        book.ranksButton:SetText(rankCount > 0 and ("Ranks (" .. rankCount .. ")") or "Ranks")
        book.locationsButton:UpdateWindowBorder()
        book.ranksButton:UpdateWindowBorder()
        book.review:SetSelected(reviewOnly)
        local unletteredRows=journal:List(category,book.search:GetText(),reviewOnly,nil,locationFilters,rankFilters)
        local availableLetters={}
        for _,row in ipairs(unletteredRows) do availableLetters[row.name:sub(1,1):upper()]=true end
        if initial and not availableLetters[initial] then initial=nil; offset=0 end
        for _,letterButton in ipairs(book.letterButtons) do
            letterButton:SetShown(indexOpen)
            letterButton:SetEnabled(availableLetters[letterButton.letter] == true)
            letterButton:SetSelected(initial == letterButton.letter)
        end
        local rows = initial and journal:List(category, book.search:GetText(), reviewOnly, initial, locationFilters, rankFilters) or unletteredRows
        offset = math.max(0, math.min(offset, math.max(0, #rows - creaturePageSize)))
        book.updatingCreatureScroll=true
        book.creatureScrollBar:SetMinMaxValues(0,math.max(0,#rows-creaturePageSize))
        book.creatureScrollBar:SetValue(offset)
        book.creatureScrollBar:SetShown(#rows>creaturePageSize)
        book.updatingCreatureScroll=false
        for i, row in ipairs(book.rows) do
            row:EnableMouseWheel(#rows>creaturePageSize)
            local data = rows[offset + i]
            if row.id~=(data and data.id) or (data and row.text:GetText()~=data.name) then row:StopNameScroll() end
            row.id = data and data.id
            if data then
                row.reviewMark:SetText(data.review and "*" or "")
                row.text:SetText(data.name)
                local _,reward=journal:GetKillReward(data.id)
                row.killReward:SetReward(reward)
                if row.text:GetWidth()~=(reward and 121 or 140) then row:StopNameScroll() end
                row.text:SetWidth(reward and 121 or 140)
                -- Fade the last 20px of the name, ending before the icon's gap.
                -- Clear it when recycled rows no longer have an earned reward.
                if reward then row.text:SetAlphaGradient(101,20)
                else row.text:ClearAlphaGradient() end
                local rowSelected = data.id == selected
                local hasRumours=journal.GetRumours and #journal:GetRumours(data.id)>0
                if hasRumours then row.text:SetTextColor(114/255,214/255,91/255)
                else row.text:SetTextColor(rowSelected and 1.00 or ink[1], rowSelected and 0.82 or ink[2], rowSelected and 0.14 or ink[3]) end
                row.scrollingName:SetTextColor(row.text:GetTextColor())
                row.highlight:SetShown(rowSelected)
                row:SetBackdropBorderColor(0.95, 0.70, 0.15, rowSelected and 1 or 0)
                row:Show()
            else row:Hide() end
        end
        local entryCount, points = journal:GetTotals()
        book.entryCount:SetText(entryCount .. " entries")
        book.pointsCount:SetText(points .. " knowledge earned")
        local e = selected and journal.entries[selected]
        local basic=e and basicInfo(selected)
        local isBeast=basic~=nil and basic.category=="Beast"
        book.beastLoreButton:SetShown(isBeast)
        book.damageBorder:ClearAllPoints()
        book.damageBorder:SetPoint("TOPLEFT",579,isBeast and -162 or -133)
        book.damageBorder:SetHeight(isBeast and 86 or 115)
        book.damageScroll:ClearAllPoints()
        book.damageScroll:SetPoint("TOPLEFT",592,isBeast and -192 or -163)
        book.damageScroll:SetHeight(isBeast and 46 or 75)
        book.damageButton:ClearAllPoints()
        book.damageButton:SetPoint("TOPLEFT",579,-248)
        if isBeast then
            book.beastLore.creature:SetText(basic.name or ("Encountered creature #" .. selected))
            local lore=e.beastLore
            local valid=ns.SharingReport and ns.SharingReport.ValidLore(lore)
            book.beastLore.content:SetText(valid and ns.SharingReport.LoreText(lore) or "No Beast Lore recorded. Cast Beast Lore on this creature to record its revealed information.")
            book.beastLore.body:SetHeight(math.max(230,book.beastLore.content:GetStringHeight()+12))
            book.beastLore.provenance:SetText(valid and ("Locked • Verified • " ..
                (e.beastLoreSource=="gameTooltip" and "Observed in game" or ("Shared by " .. (e.beastLoreSender or "Unknown player")))) or "")
            book.beastLore.send:SetEnabled(valid and journal.sharing~=nil)
        else book.beastLore:Hide() end
        if creatureNotes then creatureNotes:Refresh() end
        if rumoursWindow then rumoursWindow:Refresh() end
        book.creatureNotesButton:SetEnabled(e ~= nil)
        book.rumoursButton:SetEnabled(rumoursWindow ~= nil and (e ~= nil or rumoursWindow:IsShown()))
        book.shareButton:SetEnabled(sharingWindow~=nil and (e~=nil or journal.sharing:HasActiveOutgoing()))
        book.killCount:SetShown(e ~= nil)
        local _, star, kills = journal:GetKillReward(selected)
        book.killCount:SetText("Kills: " .. kills)
        book.killStar:SetReward(star)
        book.deleteButton:SetEnabled(e ~= nil)
        if book.deleteForm:IsShown() and book.deleteForm.entry ~= e then book.deleteForm:Hide() end
        local editable = e ~= nil and not e.confirmed
        for _, control in ipairs({book.offenseButton, book.defenseButton, book.behaviourButton,
            book.effectButton, book.confirmAbilityButton, book.resolveButton, book.damageButton,
            book.manualName, book.manualNote, book.spellLink}) do
            control:SetEnabled(editable)
            control:SetAlpha(editable and 1 or 0.45)
        end
        if not editable then
            book.manualName:ClearFocus(); book.manualNote:ClearFocus(); book.spellLink:ClearFocus()
            book.offensePicker:Hide(); book.defensePicker:Hide(); book.behaviourPicker:Hide()
            book.effectPicker:Hide(); book.damageForm:Hide(); book.notesForm:Hide()
        end
        book.detail:SetShown(e ~= nil)
        book.empty:SetShown(e == nil)
        if not e then
            book.model:Hide()
            book.tameableBadge:Hide()
            book.confirm:Hide()
            book.modelCaption:SetText("")
            book.title:SetText("A field guide of your own")
            layoutSummary({"Target or mouse over an enemy to begin a new entry."},{})
            return
        end
        book.title:SetText(basic.name or ("Encountered creature #" .. selected))
        local levels = "Level Range: not yet observed"
        if basic.levelMin then levels = "Level Range: " .. basic.levelMin
            if basic.levelMax ~= basic.levelMin then levels = levels .. "-" .. basic.levelMax end
        end
        local status = { basic.category }
        local sources=journal.GetSharedSources and journal:GetSharedSources(selected) or {}
        local sourceNames={}
        for i,name in ipairs(sources) do sourceNames[i]=ns.PlayerNames and ns.PlayerNames:Format(name) or name end
        local attribution=#sources>0 and ("Shared by " .. table.concat(sourceNames,", ")) or "Shared • source not recorded"
        local showSource=basic.hasShared and not basic.personal
        book.sourceStatus:SetText(showSource and attribution or "")
        if showSource and #sources>1 and book.sourceStatus:GetStringWidth()>book.sourceStatus:GetWidth() then
            book.sourceStatus:SetText("Shared by " .. sourceNames[1] .. " +" .. (#sources-1) .. (#sources==2 and " other" or " others"))
        end
        book.sourceTooltip.text=attribution .. "\n" .. (e.confirmed and "Shared reports remain in Rumours while this page is locked."
            or basic.personal and "Includes shared basics. See Rumours for each report."
            or "Not personally encountered. See Rumours for each report.")
        book.sourceTooltip:SetShown(showSource==true)
        if e.rank then status[#status + 1] = e.rank end
        status[#status + 1] = levels
        local locations = {}
        for location in pairs(basic.locations or {}) do locations[#locations + 1] = location end
        table.sort(locations)
        if #locations > 0 then status[#status + 1] = "Locations: " .. table.concat(locations, ", ") end
        local function schoolSummary(field)
            local names = {}
            for _, school in ipairs(magicSchools) do
                if type(e[field]) == "table" and e[field][school.name] then
                    names[#names + 1] = "|cff" .. school.color .. school.name .. "|r"
                end
            end
            return names
        end
        local combat = {}
        local offenses = schoolSummary("offenses")
        local resistances = schoolSummary("resistances")
        local immunities = schoolSummary("immunities")
        if #offenses > 0 then combat[#combat + 1] = "Casts: " .. table.concat(offenses, ", ") end
        if #resistances > 0 then combat[#combat + 1] = "Resists: " .. table.concat(resistances, ", ") end
        if #immunities > 0 then combat[#combat + 1] = "Immune: " .. table.concat(immunities, ", ") end
        local behaviours = {}
        book.tameableBadge:SetShown(e.tameable==true and e.tameabilitySource=="gameTooltip")
        for _,name in ipairs(behaviourOrder) do
            if type(e.behaviours)=="table" and e.behaviours[name] then behaviours[#behaviours+1]=name end
        end
        if #behaviours > 0 then combat[#combat + 1] = "Behaviour: " .. table.concat(behaviours, ", ") end
        layoutSummary(status,combat)
        book.confirm:SetText(e.confirmed and "Unlock this entry" or "Lock this entry")
        book.confirm:SetLockedState(e.confirmed)
        book.confirm:SetEnabled(true)
        book.confirm:Show()
        local names = {}
        for name in pairs(e.abilities) do names[#names + 1] = name end
        table.sort(names)
        local maxAbilityOffset = math.max(0, #names - 4)
        abilityOffset = math.max(0, math.min(abilityOffset, maxAbilityOffset))
        book.updatingAbilityScroll = true
        book.abilityScrollBar:SetMinMaxValues(0, maxAbilityOffset)
        book.abilityScrollBar:SetValue(abilityOffset)
        book.abilityScrollBar:SetShown(maxAbilityOffset > 0)
        book.updatingAbilityScroll = false
        for i, row in ipairs(book.abilities) do
            row:SetWidth(maxAbilityOffset > 0 and 559 or 583)
            row:EnableMouseWheel(maxAbilityOffset > 0)
            local name = names[abilityOffset + i]
            if name then
                local ability = e.abilities[name]
                row:Show()
                row.name = name
                row.tooltipCheck:SetChecked(ability.showInTooltip ~= false)
                local linkMissing = type(ability.spellID) ~= "number" or ability.spellID <= 0
                row.text:SetText(name .. (linkMissing and "  [?]" or "") .. (ability.state == "confirmed" and "" or "  [" .. ability.state .. "]"))
                local effects=effectsText(ability.effects)
                local note=ability.note or (ability.origin ~= "Your note" and ability.origin or nil)
                row.note:SetText(effects and note and (effects.." — "..note) or effects or note or "")
                row.accept:SetEnabled(editable and ability.state ~= "confirmed")
                row.accept.cover:SetColorTexture(unpack((editable and ability.state ~= "confirmed") and {0.13,0.025,0.015,1} or {0.22,0.22,0.22,1}))
                row.resolve:SetShown(editable and (linkMissing or ability.state ~= "confirmed"))
                for _,control in ipairs({row.tooltipCheck,row.link,row.reject,row.accept}) do control:SetShown(editable) end
                row.divider:SetShown(i>1)
                row.tooltipArea:ClearAllPoints()
                row.tooltipArea:SetPoint("TOPLEFT",row,"TOPLEFT",20,0)
                if editable then
                    row.tooltipArea:SetPoint("BOTTOMRIGHT",row.resolve:IsShown() and row.resolve or row.link,"BOTTOMLEFT",-6,-18)
                else
                    row.tooltipArea:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",0,0)
                end
                row.resolve:SetEnabled(editable)
                row.link:SetEnabled(editable)
                row.reject:SetEnabled(editable)
                row.tooltipCheck:SetEnabled(editable)
                for _, control in ipairs({row.resolve,row.link,row.reject,row.tooltipCheck}) do control:SetAlpha(editable and 1 or 0.45) end
                local removing=ability.state=="rejected"
                row.reject.cover:SetShown(removing)
                row.reject.dash:SetShown(removing)
                row.reject.tooltipText=removing and "Remove ability" or "Reject ability"
                if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row.reject) then
                    if editable then
                        GameTooltip:SetText(row.reject.tooltipText);GameTooltip:Show()
                    else GameTooltip:Hide() end
                end
            else row:Hide() end
        end
        book.abilityCount:SetText(#names == 0 and "No abilities recorded. Add what you experienced below." or (#names .. " recorded abilities" .. (#names > 4 and " - scroll to review" or "")))
        if #names == 0 then book.abilityCount:SetTextColor(0.55,0.58,0.58)
        else book.abilityCount:SetTextColor(unpack(ink)) end
        local levels = {}
        for level in pairs(e.damage) do levels[#levels + 1] = level end
        table.sort(levels)
        local contentHeight = 0
        for i, level in ipairs(levels) do
            local hit = e.damage[level]
            local parts = {}
            if hit.normalLow then parts[#parts + 1] = "normal " .. hit.normalLow .. "-" .. hit.normalHigh .. " (" .. hit.normalCount .. ")" end
            if hit.critLow then parts[#parts + 1] = "crit " .. hit.critLow .. "-" .. hit.critHigh .. " (" .. hit.critCount .. ")" end
            if #parts == 0 and hit.low then parts[1] = hit.low .. "-" .. hit.high .. " (" .. (hit.reports or 1) .. " notes)" end
            local row=book.damageRows[i]
            if not row then
                row=CreateFrame("Button",nil,book.damageChild)
                row:SetSize(296,14)
                row.text=label(row,"",3,0,290,"GameFontHighlightSmall")
                row.highlight=row:CreateTexture(nil,"HIGHLIGHT"); row.highlight:SetAllPoints(); row.highlight:SetColorTexture(0.55,0.35,0.12,0.16)
                row:SetScript("OnClick",function(self)
                    book.notesLevel=self.level; noteOffset=0; refreshDamageNotes(); book.notesForm:Show()
                end)
                book.damageRows[i]=row
            end
            local playerLevels, seenPlayers = {}, {}
            for _, note in ipairs(journal:DamageNotes(selected,level)) do
                if not seenPlayers[note.playerLevel] then playerLevels[#playerLevels+1]=note.playerLevel; seenPlayers[note.playerLevel]=true end
            end
            table.sort(playerLevels)
            local players = #playerLevels>0 and (" · Player "..table.concat(playerLevels,", ")) or ""
            row.level=level; row.text:SetText("Creature "..level..players..": "..table.concat(parts,"; ").."  >")
            local textHeight = row.text:GetStringHeight()
            local rowHeight = math.max(14, type(textHeight) == "number" and textHeight or 14)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-contentHeight)
            row:SetHeight(rowHeight); row:Show()
            contentHeight = contentHeight + rowHeight + 1
        end
        for i=#levels+1,#book.damageRows do book.damageRows[i]:Hide() end
        book.noDamage:SetShown(#levels==0)
        local viewportHeight = book.damageScroll:GetHeight()
        local damageHeight=math.max(viewportHeight,contentHeight)
        book.damageChild:SetHeight(damageHeight)
        local scrollable=contentHeight>viewportHeight
        local currentScroll = book.damageScroll:GetVerticalScroll()
        book.damageScroll:SetVerticalScroll(math.min(type(currentScroll) == "number" and currentScroll or 0, damageHeight-viewportHeight))
        if book.damageScrollBar and type(book.damageScrollBar) ~= "function" then book.damageScrollBar:SetShown(scrollable) end
        book.damageScroll:EnableMouseWheel(scrollable)
    end
    local function build()
        book = CreateFrame("Frame", "AzerothFieldbookBestiary", UIParent, "BackdropTemplate")
        book:SetSize(960, 740)
        book:SetPoint("CENTER")
        book:SetFrameStrata("HIGH")
        book:SetToplevel(true)
        book:SetScript("OnShow",book.Raise)
        book:SetClampedToScreen(true)
        book:SetMovable(true)
        book:EnableMouse(true)
        book:RegisterForDrag("LeftButton")
        -- Keep one anchor and one cursor coordinate space throughout a drag.
        -- Native StartMoving reanchors scaled frames to screen space.
        local drag
        local function stopBookDrag()
            if drag and ns.WindowPositions then ns.WindowPositions:Save(book) end
            drag = nil
        end
        local function startBookDrag()
            if drag then return end
            local x,y = GetCursorPosition()
            local scale = book:GetEffectiveScale()
            local left,top = book:GetLeft(),book:GetTop()
            if not left or not top or not scale or scale <= 0 then return end
            drag = { x=x, y=y, left=left, top=top, scale=scale }
        end
        book:SetScript("OnDragStart", startBookDrag)
        book:SetScript("OnDragStop", stopBookDrag)
        local backgroundBrightness = journal:GetBackgroundBrightness()
        local backgroundLayers = {}
        local function addBackgroundLayer(texture, red, green, blue)
            backgroundLayers[#backgroundLayers + 1] = { texture = texture, red = red, green = green, blue = blue }
            texture:SetVertexColor(red * backgroundBrightness, green * backgroundBrightness, blue * backgroundBrightness)
        end
        function book:SetBackgroundBrightness(value)
            backgroundBrightness = math.max(0.5, math.min(1.5, tonumber(value) or 1))
            for _, layer in ipairs(backgroundLayers) do
                layer.texture:SetVertexColor(layer.red * backgroundBrightness, layer.green * backgroundBrightness, layer.blue * backgroundBrightness)
            end
        end
        book:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=24, insets={left=8,right=8,top=8,bottom=8}})
        -- QuestBG has transparent padding. Back the entire page with opaque
        -- parchment, then stretch only an interior, non-transparent texture area.
        local paper = book:CreateTexture(nil, "BACKGROUND", nil, 1)
        paper:SetPoint("TOPLEFT", book, "TOPLEFT", 6, -9)
        paper:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -2, 6)
        paper:SetColorTexture(1, 1, 1, 1)
        addBackgroundLayer(paper, 0.44352, 0.39312, 0.3024)
        local page = book:CreateTexture(nil, "BACKGROUND", nil, 2)
        page:SetAllPoints(paper)
        page:SetTexture("Interface\\QuestFrame\\QuestBG")
        -- This high-resolution sheet matches the book's aspect closely and is
        -- downscaled slightly, avoiding both tiled seams and enlarged pixels.
        page:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        page:SetHorizTile(false)
        page:SetVertTile(false)
        page:SetTexCoord(0, 1, 0, 1)
        addBackgroundLayer(page, 0.504, 0.504, 0.48888)
        local spine = book:CreateTexture(nil, "ARTWORK")
        spine:SetColorTexture(0.25, 0.13, 0.055, 0.35)
        spine:SetPoint("TOPLEFT", 324, -53); spine:SetSize(3, 661)
        book.titleBar=CreateFrame("Frame",nil,book,"BackdropTemplate")
        book.titleBar:SetPoint("TOPLEFT",1,-3); book.titleBar:SetPoint("TOPRIGHT",-1,-3); book.titleBar:SetHeight(24)
        book.titleBar:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background-Dark",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=6,insets={left=2,right=2,top=2,bottom=2}})
        book.titleBar:SetBackdropColor(0.16,0.10,0.055,0.96)
        book.titleBar:EnableMouse(true); book.titleBar:RegisterForDrag("LeftButton")
        book.titleBar:SetScript("OnDragStart",startBookDrag)
        book.titleBar:SetScript("OnDragStop",stopBookDrag)
        book.titleBar:SetScript("OnHide",stopBookDrag)
        book.titleBar:SetScript("OnUpdate",function()
            if not drag then return end
            if not IsMouseButtonDown("LeftButton") then stopBookDrag(); return end
            local x,y = GetCursorPosition()
            local left = drag.left + (x-drag.x)/drag.scale
            local top = drag.top + (y-drag.y)/drag.scale
            book:ClearAllPoints()
            book:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left,top)
        end)
        -- Match the native character-sheet portrait: the icon is clipped by a
        -- real circular mask and surrounded by the UI-Frame portrait ring.
        book.titleIcon=CreateFrame("Frame",nil,book)
        book.titleIcon:SetAllPoints(book)
        local trackingIcon=book.titleIcon:CreateTexture(nil,"ARTWORK")
        trackingIcon:SetSize(61,61); trackingIcon:SetPoint("TOPLEFT",0,4)
        trackingIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_02")
        trackingIcon:SetTexCoord(0,1,0,1)
        if type(book.titleIcon.CreateMaskTexture)=="function" and type(trackingIcon.AddMaskTexture)=="function" then
            local circleMask=book.titleIcon:CreateMaskTexture()
            if circleMask then
                circleMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
                circleMask:SetAllPoints(trackingIcon)
                trackingIcon:AddMaskTexture(circleMask)
            end
        end
        local iconBorder=book.titleIcon:CreateTexture(nil,"OVERLAY")
        iconBorder:SetSize(78,78); iconBorder:SetPoint("TOPLEFT",-8,7)
        iconBorder:SetTexture("Interface\\FrameGeneral\\UI-Frame")
        iconBorder:SetTexCoord(0.00781250,0.61718750,0.00781250,0.61718750)
        -- Use one native portrait-frame art family for the surrounding edges.
        -- Keep the old backdrop as a fallback if this client lacks the atlases.
        local edgeAtlases = {"UI-Frame-TopCornerRightSimple", "_UI-Frame-TitleTile", "!UI-Frame-LeftTile", "!UI-Frame-RightTile", "UI-Frame-BotCornerLeft", "UI-Frame-BotCornerRight", "_UI-Frame-Bot"}
        local hasFrameArt = C_Texture and type(C_Texture.GetAtlasInfo) == "function"
        if hasFrameArt then
            for _, atlas in ipairs(edgeAtlases) do
                if not C_Texture.GetAtlasInfo(atlas) then hasFrameArt = false; break end
            end
        end
        if hasFrameArt then
            book:SetBackdrop(nil)
            book.titleBar:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background-Dark",tile=true,tileSize=32})
            book.titleBar:SetBackdropColor(0.16,0.10,0.055,0.96)
            -- Retain the complete portrait sheet region above. Switching this
            -- texture to an atlas after cropping it produced a cropped ring.
            -- Extend the paper under the narrower native trim to prevent gaps.
            paper:ClearAllPoints()
            paper:SetPoint("TOPLEFT",book,"TOPLEFT",6,-9)
            paper:SetPoint("BOTTOMRIGHT",book,"BOTTOMRIGHT",-2,6)
            -- The portrait supplies the left cap. Do not paint a rectangular
            -- title background behind its transparent outer silhouette.
            book.titleBar:ClearAllPoints()
            book.titleBar:SetPoint("TOPLEFT",60,-5)
            book.titleBar:SetPoint("TOPRIGHT",-5,-5)
            book.titleBar:SetHeight(20)
            local function edge(atlas, width, height, horizontal, vertical)
                local texture = book.titleIcon:CreateTexture(nil,"OVERLAY")
                texture:SetAtlas(atlas)
                texture:SetSize(width,height)
                if horizontal then texture:SetHorizTile(true) end
                if vertical then texture:SetVertTile(true) end
                return texture
            end
            -- The close button already supplies its own bevelled corner.
            -- An additional square corner here protrudes above that bevel.
            local top = edge("_UI-Frame-TitleTile",256,28,true)
            -- Keep the native top trim on the same edge as the dark title fill.
            top:SetPoint("TOPLEFT",iconBorder,"TOPRIGHT",0,-10)
            top:SetPoint("TOPRIGHT",book,"TOPRIGHT",-2,-5)
            local topRight = edge("UI-Frame-TopCornerRightSimple",18,18)
            topRight:SetPoint("TOPRIGHT",book,"TOPRIGHT",0,-2)
            local bottomLeft = edge("UI-Frame-BotCornerLeft",14,14)
            bottomLeft:SetPoint("BOTTOMLEFT",0,0)
            local bottomRight = edge("UI-Frame-BotCornerRight",11,11)
            bottomRight:SetPoint("BOTTOMRIGHT",0,0)
            local bottom = edge("_UI-Frame-Bot",256,9,true)
            bottom:SetPoint("BOTTOMLEFT",bottomLeft,"BOTTOMRIGHT",0,0)
            bottom:SetPoint("BOTTOMRIGHT",bottomRight,"BOTTOMLEFT",0,0)
            local left = edge("!UI-Frame-LeftTile",16,256,false,true)
            left:SetPoint("TOPLEFT",iconBorder,"BOTTOMLEFT",8,0)
            left:SetPoint("BOTTOMLEFT",bottomLeft,"TOPLEFT",0,0)
            local right = edge("!UI-Frame-RightTile",10,256,false,true)
            right:SetPoint("TOPRIGHT",book,"TOPRIGHT",0,-27)
            right:SetPoint("BOTTOMRIGHT",bottomRight,"TOPRIGHT",0,0)
        end
        book.windowTitle=book.titleBar:CreateFontString(nil,"OVERLAY","GameFontNormal")
        book.windowTitle:SetPoint("CENTER",book,"TOP",0,-15)
        book.windowTitle:SetWidth(700)
        book.windowTitle:SetJustifyH("CENTER"); book.windowTitle:SetTextColor(1.00,0.82,0.14)
        book.windowTitle:SetText("Azeroth Fieldbook - Bestiary - v" .. addonVersion())
        book.closeButton=CreateFrame("Button",nil,book.titleBar,"UIPanelCloseButton")
        book.closeButton:SetPoint("RIGHT",4,0); book.closeButton:SetSize(24,24); book.closeButton:SetScript("OnClick",function() book:Hide() end)
        local function titleButton(neighbour,action)
            local control=CreateFrame("Button",nil,book.titleBar,"UIPanelCloseButton")
            control:SetSize(24,24); control:SetPoint("RIGHT",neighbour,"LEFT",-2,0)
            local cover=control:CreateTexture(nil,"OVERLAY")
            cover:SetPoint("TOPLEFT",6,-6); cover:SetPoint("BOTTOMRIGHT",-6,6)
            cover:SetColorTexture(0.13,0.025,0.015,0.96)
            control:SetScript("OnClick",action)
            return control
        end
        book.helpButton=titleButton(book.closeButton,function()
            book.options:Hide()
            book.help:SetShown(not book.help:IsShown())
        end)
        local helpGlyph=book.helpButton:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        helpGlyph:SetAllPoints(); helpGlyph:SetJustifyH("CENTER"); helpGlyph:SetJustifyV("MIDDLE")
        helpGlyph:SetTextColor(1.00,0.82,0.14); helpGlyph:SetText("?")
        book.optionsButton=titleButton(book.helpButton,function()
            book.help:Hide()
            book.options:SetShown(not book.options:IsShown())
        end)
        do
            -- Native texture scanlines keep the cog crisp without depending on
            -- a font's Unicode coverage or a client-specific settings atlas.
            for y=0,11 do
                local first
                for x=0,12 do
                    local dx,dy=x-5.5,y-5.5
                    local radius=math.sqrt(dx*dx+dy*dy)
                    local filled=x<12 and radius>=2 and (radius<=4.2
                        or (radius<=6 and math.cos(8*math.atan2(dy,dx))>=0.25))
                    if filled and not first then first=x end
                    if first and not filled then
                        local part=book.optionsButton:CreateTexture(nil,"OVERLAY",nil,1)
                        part:SetColorTexture(1.00,0.82,0.14,1)
                        part:SetSize(x-first,1)
                        part:SetPoint("TOPLEFT",book.optionsButton,"CENTER",first-6,6-y)
                        first=nil
                    end
                end
            end
        end
        book.optionsButton:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText("Options"); GameTooltip:Show() end
        end)
        book.optionsButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        book.eventLogButton=titleButton(book.optionsButton,function() book.eventLog:SetShown(not book.eventLog:IsShown()) end)
        for line=1,3 do
            local stroke=book.eventLogButton:CreateTexture(nil,"OVERLAY",nil,1)
            stroke:SetColorTexture(1,0.82,0.14,1);stroke:SetSize(10,1)
            stroke:SetPoint("CENTER",0,4-(line-1)*4)
        end
        book.eventLogButton:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Event log");GameTooltip:Show() end
        end)
        book.eventLogButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        book.typeButtons = {}
        local function addTypeButton(name, y)
            local typeButton = button(book, name == "All creatures" and "All" or name, 42, y, 88, function()
                if name=="All creatures" or category==name then category=nil else category=name end
                offset = 0; refresh()
            end)
            styleSelection(typeButton)
            book.typeButtons[name] = typeButton
        end
        addTypeButton("All creatures", -110)
        for i, name in ipairs(typeOrder) do addTypeButton(name, -110-i*28) end
        book.locationsButton = button(book, "Locations", 42, -479, 88, function()
            book.locationFrame:SetShown(not book.locationFrame:IsShown())
        end)
        styleSelection(book.locationsButton,true)
        book.ranksButton = button(book, "Ranks", 42, -511, 88, function() book.rankFrame:SetShown(not book.rankFrame:IsShown()) end)
        styleSelection(book.ranksButton,true)
        book.entryCount=label(book,"",135,-55,55,"GameFontHighlightSmall")
        book.pointsCount=label(book,"",190,-55,125,"GameFontHighlightSmall")
        book.pointsCount:SetJustifyH("RIGHT")
        book.search = edit(book, 145, -78, 146, 100)
        -- The single-line edit box scrolls within these insets, keeping its
        -- text and cursor clear of the fixed clear button.
        book.search:SetTextInsets(0,22,0,0)
        book.searchClear=CreateFrame("Button",nil,book.search)
        book.searchClear:SetSize(18,18)
        book.searchClear:SetPoint("RIGHT",book.search,"RIGHT",-2,0)
        local clearGlyph=book.searchClear:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        clearGlyph:SetPoint("CENTER");clearGlyph:SetText("×")
        clearGlyph:SetTextColor(0.95,0.15,0.12)
        book.searchClear:SetScript("OnEnter",function() clearGlyph:SetTextColor(1,0.4,0.3) end)
        book.searchClear:SetScript("OnLeave",function() clearGlyph:SetTextColor(0.95,0.15,0.12) end)
        book.searchClear:SetScript("OnClick",function()
            book.search:SetText("")
            book.search:SetFocus()
        end)
        local searchPlaceholder=label(book.search,"Search",0,-5,124,"GameFontHighlightSmall")
        searchPlaceholder:SetTextColor(0.55,0.55,0.55)
        book.search:SetScript("OnTextChanged", function(self)
            searchPlaceholder:SetShown(self:GetText() == "")
            offset = 0; refresh()
        end)
        -- Keep the popup independent of book focus/strata changes. Its entire
        -- hierarchy must draw above nested row rewards and scrollbar buttons.
        local sortDismiss=CreateFrame("Button","AzerothFieldbookSortMenu",UIParent)
        sortDismiss:SetAllPoints(UIParent);sortDismiss:SetFrameStrata("FULLSCREEN_DIALOG")
        sortDismiss:SetToplevel(true)
        sortDismiss:SetScript("OnShow",function(self) self:SetScale(book:GetScale());self:Raise() end)
        sortDismiss:EnableMouse(true)
        sortDismiss:SetScript("OnClick",function(self) self:Hide() end)
        local sortMenu=CreateFrame("Frame",nil,sortDismiss,"BackdropTemplate")
        sortMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        sortMenu:SetSize(184,263);sortMenu:SetClampedToScreen(true);sortMenu:EnableMouse(true)
        sortMenu:SetFrameLevel(sortDismiss:GetFrameLevel()+1)
        sortMenu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
        sortMenu:SetBackdropColor(0.08,0.055,0.025,1)
        sortMenu:SetBackdropBorderColor(0.45,0.30,0.13,1)
        label(sortMenu,"Sorting by",12,-12,160,"GameFontNormal"):SetTextColor(1,0.82,0.14)
        local sortChoices={}
        local function refreshSortChoices()
            local field,descending=journal:GetListSort()
            for _,choice in ipairs(sortChoices) do
                choice.control:SetSelected(choice.field and choice.field==field or (choice.field==nil and choice.descending==descending))
            end
        end
        for i,choice in ipairs({{"name","Name"},{"kills","Kills"},{"maxLevel","Max Level"},{"minLevel","Min Level"},{"firstEncountered","First Encountered"}}) do
            local field=choice[1]
            local control=button(sortMenu,choice[2],12,-32-(i-1)*27,160,function()
                local _,descending=journal:GetListSort()
                journal:SetListSort(field,descending);offset=0;refresh();refreshSortChoices()
            end)
            control:SetFrameStrata("FULLSCREEN_DIALOG")
            styleSelection(control);sortChoices[#sortChoices+1]={control=control,field=field}
        end
        label(sortMenu,"Order",12,-172,160,"GameFontNormal"):SetTextColor(1,0.82,0.14)
        for i,title in ipairs({"Ascending","Descending"}) do
            local descending=i==2
            local control=button(sortMenu,title,12,-192-(i-1)*27,160,function()
                local field=journal:GetListSort()
                journal:SetListSort(field,descending);offset=0;refresh();refreshSortChoices()
            end)
            control:SetFrameStrata("FULLSCREEN_DIALOG")
            styleSelection(control);sortChoices[#sortChoices+1]={control=control,descending=descending}
        end
        book.sortButton=button(book,"",297,-78,22,function()
            book.search:ClearFocus();refreshSortChoices();sortDismiss:SetShown(not sortDismiss:IsShown())
        end)
        book.sortButton:SetSize(22,22)
        for row=0,4 do
            local stroke=book.sortButton:CreateTexture(nil,"OVERLAY")
            stroke:SetSize(9-row*2,1);stroke:SetPoint("CENTER",0,2-row)
            stroke:SetColorTexture(1,0.82,0.14,1)
        end
        book.sortButton:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Sort");GameTooltip:Show() end
        end)
        book.sortButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        sortMenu:SetPoint("TOPRIGHT",book.sortButton,"BOTTOMRIGHT",0,-4)
        book.sortMenu,book.sortChoices=sortDismiss,sortChoices
        sortDismiss:Hide()
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookSortMenu" end
        book.review = button(book, "Pending", 42, -543, 88, function()
            reviewOnly = not reviewOnly
            offset = 0; refresh()
        end)
        styleSelection(book.review)
        book.rows = {}
        book.creatureScrollBar=CreateFrame("Slider",nil,book,"UIPanelScrollBarTemplate")
        book.creatureScrollBar:SetPoint("TOPLEFT",301,-126)
        book.creatureScrollBar:SetSize(14,446)
        ns.StyleScrollBarTrack(book.creatureScrollBar,0.3)
        book.creatureScrollBar:SetMinMaxValues(0,0)
        book.creatureScrollBar:SetValueStep(1)
        book.creatureScrollBar:SetObeyStepOnDrag(true)
        book.creatureScrollBar:SetScript("OnValueChanged",function(_,value)
            if book.updatingCreatureScroll then return end
            local nextOffset=math.floor(value+0.5)
            if nextOffset~=offset then offset=nextOffset; refresh() end
        end)
        book.creatureScrollBar:EnableMouseWheel(true)
        book.creatureScrollBar:SetScript("OnMouseWheel",function(_,delta) offset=offset-delta*3; refresh() end)
        book.creatureScrollBar:Hide()
        for i = 1, creaturePageSize do
            local row = CreateFrame("Button", nil, book, "BackdropTemplate")
            row:SetPoint("TOPLEFT", 135, -110 - (i-1)*30); row:SetSize(162, 28)
            row:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8, insets={left=1,right=1,top=-3,bottom=1}})
            row:SetBackdropBorderColor(0.95, 0.70, 0.15, 0)
            row.highlight = row:CreateTexture(nil, "BACKGROUND")
            row.highlight:SetPoint("TOPLEFT", 1, -1)
            row.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
            row.highlight:SetColorTexture(0.18,0.10,0.02,0.50)
            row.reviewMark = label(row, "", 5, -8, 10)
            row.reviewMark:SetTextColor(1, 1, 1)
            row.reviewMark:SetWordWrap(false)
            row.text = label(row, "", 17, -8, 140)
            row.text:SetWordWrap(false)
            addNameScroller(row)
            row.killReward=createKillReward(row,1)
            row.killReward:SetPoint("RIGHT",row,"RIGHT",-5,0)
            row:SetScript("OnClick", function(self) if self.id then choose(self.id) end end)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta) offset=offset-delta*3; refresh() end)
            book.rows[i] = row
        end
        button(book, "Previous", 135, -596, 84, function() cycleEntry(-1) end)
        button(book, "Next", 229, -596, 86, function() cycleEntry(1) end)
        local deleteForm = CreateFrame("Frame", "AzerothFieldbookDeleteCreature", UIParent, "BackdropTemplate")
        book.deleteForm = deleteForm
        deleteForm:SetSize(440,210); deleteForm:SetPoint("CENTER",book,"CENTER")
        deleteForm:SetFrameStrata("FULLSCREEN_DIALOG"); deleteForm:EnableMouse(true)
        deleteForm:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        deleteForm:SetBackdropColor(0.10,0.08,0.05,1)
        label(deleteForm,"Delete creature entry",22,-20,396,"GameFontNormalLarge")
        deleteForm.description=label(deleteForm,"",22,-50,396)
        label(deleteForm,"Type delete and press Enter to confirm.",22,-113,396)
        deleteForm.input=edit(deleteForm,28,-142,240,20)
        button(deleteForm,"Cancel",295,-141,115,function() deleteForm:Hide() end)
        deleteForm.input:SetScript("OnEscapePressed",function() deleteForm:Hide() end)
        deleteForm.input:SetScript("OnEnterPressed",function(self)
            local id, entry = deleteForm.id, deleteForm.entry
            if not deleteForm:IsShown() or self:GetText() ~= "delete" then return end
            if selected ~= id or journal.entries[id] ~= entry then deleteForm:Hide(); return end
            if journal:DeleteEntry(id) then
                deleteForm:Hide()
                choose(nil)
                message("Creature entry deleted. Future encounters may record it again.")
            end
        end)
        deleteForm:SetScript("OnHide",function(self)
            self.id, self.entry = nil, nil
            self.input:ClearFocus(); self.input:SetText("")
        end)
        deleteForm:Hide()
        table.insert(UISpecialFrames,"AzerothFieldbookDeleteCreature")
        book.deleteButton=button(book,"Delete",135,-626,84,function()
            local entry = selected and journal.entries[selected]
            if not entry then return end
            deleteForm.id, deleteForm.entry = selected, entry
            deleteForm.description:SetText("Permanently delete " .. (basicInfo(selected).name or ("Encountered creature #" .. selected)) .. "?\nIts records and rumours will be removed. Earned credit and spending remain.")
            deleteForm.input:SetText(""); deleteForm:Show(); deleteForm.input:SetFocus()
        end)
        book.shareButton = button(book, "Share", 229, -626, 86, function()
            if sharingWindow then sharingWindow:Open(selected) end
        end)
        book.indexCount = label(book, "* awaiting review\n|cff72d65bGreen|r: outstanding rumours", 135, -660, 180, "GameFontHighlightSmall")
        book.indexCount:SetTextColor(0.55,0.58,0.58)
        label(book, "Click Index to show or hide A-Z filters.\nBind this book in Options > Keybindings.",38,-704,256,"GameFontHighlightSmall")
        book.indexButton = button(book, "Index", 3, -78, 57, function()
            indexOpen = not indexOpen
            initial=nil; offset=0; refresh()
        end)
        styleSelection(book.indexButton)
        book.letterButtons = {}
        for i=1,26 do
            local letter = string.char(64+i)
            local tab = button(book, letter, 4, -107-(i-1)*23, 28, function()
                if initial==letter then initial=nil else initial=letter end
                offset=0; refresh()
            end)
            tab:SetHeight(21)
            tab:SetDisabledFontObject("GameFontDisable")
            tab.letter=letter; styleSelection(tab)
            tab:Hide()
            book.letterButtons[i]=tab
        end
        book.title = label(book, "", 362, -55, 264, "GameFontNormalLarge")
        book.title:SetTextColor(1,0.82,0.14)
        book.title:SetWordWrap(false)
        book.creatureNotesButton=button(book,"Creature Notes",806,-52,130,function()
            if creatureNotes then creatureNotes:Toggle(selected) end
        end)
        book.creatureNotesButton:ClearAllPoints()
        book.creatureNotesButton:SetPoint("TOPRIGHT",book,"TOPRIGHT",-24,-52)
        book.rumoursButton=button(book,"Rumours",710,-52,88,function()
            if rumoursWindow then rumoursWindow:Toggle(selected) end
        end)
        book.rumoursButton:ClearAllPoints()
        book.rumoursButton:SetPoint("RIGHT",book.creatureNotesButton,"LEFT",-8,0)
        book.killCount=label(book,"",720,-57,78,"GameFontHighlightSmall")
        book.killCount:ClearAllPoints()
        book.killCount:SetPoint("RIGHT",book.rumoursButton,"LEFT",-8,0)
        book.killCount:SetJustifyH("RIGHT")
        book.killCount:SetWidth(0) -- Fit the text so the adjacent reward keeps a 3px gap.
        book.killStar=createKillReward(book)
        book.killStar:SetPoint("RIGHT",book.killCount,"LEFT",-3,0)
        book.title:SetPoint("TOPRIGHT",book.killStar,"LEFT",-8,9)
        local titlePath, titleSize, titleFlags = book.title:GetFont()
        if titlePath and titleSize then book.title:SetFont(titlePath, titleSize + 2, titleFlags) end
        book.summaryArea=CreateFrame("Frame",nil,book)
        book.summaryArea:SetPoint("TOPLEFT",362,-84); book.summaryArea:SetSize(574,45)
        book.summaryMeasure=book:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        book.summaryMeasure:SetWordWrap(false); book.summaryMeasure:Hide()
        book.summaryBasicRows,book.summaryCombatRows={},{}
        book.empty = label(book, "Every page begins with an encounter or an accepted report.\n\nSelect an entry from the index to review your notes.", 366, -210, 494)
        book.detail = CreateFrame("Frame", nil, book)
        book.detail:SetPoint("TOPLEFT",0,0); book.detail:SetSize(960,740)
        local detail = book.detail
        book.modelBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        book.modelBorder:SetPoint("TOPLEFT",364,-133); book.modelBorder:SetSize(207,168)
        book.modelBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        book.modelBorder:SetBackdropColor(0.045,0.032,0.018,0.88)
        book.modelBorder:SetBackdropBorderColor(0.37,0.25,0.11,0.90)
        book.model = CreateFrame("PlayerModel", nil, detail)
        book.model:SetPoint("TOPLEFT", 366, -135); book.model:SetSize(203, 164)
        book.model:SetPortraitZoom(0); book.model:SetCamDistanceScale(1.25)
        book.model:EnableMouse(true)
        book.sourceTooltip=CreateFrame("Frame",nil,book.modelBorder)
        book.sourceTooltip:SetFrameLevel(book.model:GetFrameLevel()+2)
        book.sourceTooltip:SetPoint("BOTTOMLEFT",book.modelBorder,"BOTTOMLEFT",7,5)
        book.sourceTooltip:SetSize(191,12)
        book.sourceStatus=label(book.sourceTooltip,"",0,0,191,"GameFontHighlightSmall")
        book.sourceStatus:SetTextColor(0.55,0.58,0.58)
        book.sourceStatus:SetHeight(12); book.sourceStatus:SetWordWrap(false)
        book.sourceTooltip:EnableMouse(true)
        book.sourceTooltip:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText("Shared information")
            GameTooltip:AddLine(self.text,0.55,0.58,0.58,true)
            GameTooltip:Show()
        end)
        book.sourceTooltip:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        book.tameableBadge=CreateFrame("Button",nil,book.modelBorder,"BackdropTemplate")
        book.tameableBadge:SetSize(24,24);book.tameableBadge:SetPoint("TOPLEFT",6,-6)
        book.tameableBadge:SetFrameLevel(book.model:GetFrameLevel()+2)
        book.tameableBadge:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8})
        book.tameableBadge:SetBackdropColor(0.08,0.06,0.02,1)
        local tameIcon=book.tameableBadge:CreateTexture(nil,"ARTWORK")
        tameIcon:SetPoint("TOPLEFT",3,-3);tameIcon:SetPoint("BOTTOMRIGHT",-3,3)
        tameIcon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
        book.tameableBadge:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Tameable");GameTooltip:Show() end
        end)
        book.tameableBadge:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        book.tameableBadge:Hide()
        local rotation, rotating, lastCursorX = 0, false, nil
        local function cursorX()
            local x=GetCursorPosition and GetCursorPosition()
            local scale=UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
            return x and x/scale
        end
        book.model:SetScript("OnMouseDown", function()
            rotating=true; lastCursorX=cursorX()
        end)
        book.model:SetScript("OnMouseUp", function() rotating=false; lastCursorX=nil end)
        book.model:SetScript("OnUpdate", function()
            if rotating then
                local x=cursorX()
                if x and lastCursorX then rotation=rotation+(x-lastCursorX)*0.015; book.model:SetRotation(rotation) end
                lastCursorX=x
            end
        end)
        book.model:SetScript("OnHide", function() rotating=false; lastCursorX=nil end)
        book.modelCaption = label(book.modelBorder, "", 8, -76, 191, "GameFontHighlightSmall")
        book.modelCaption:SetJustifyH("CENTER")
        book.model:SetScript("OnModelLoaded", function()
            book.modelCaption:SetText("")
        end)
        book.confirm = CreateFrame("Button", nil, book, "BackdropTemplate")
        book.confirm:SetSize(24, 24)
        book.confirm:SetPoint("TOPLEFT", 333, -51)
        book.confirm:SetFrameLevel(detail:GetFrameLevel() + 5)
        book.confirm:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=5, insets={left=2,right=2,top=2,bottom=2}})
        book.confirm:SetBackdropColor(0.06, 0.04, 0.02, 0.95)
        book.confirm:SetBackdropBorderColor(0.55, 0.40, 0.16, 1)
        -- Preserve the original screen center while shrinking the button and artwork.
        local function lockPart(width, height, x, y, layer)
            local part = book.confirm:CreateTexture(nil, layer or "ARTWORK")
            part:SetSize(width, height)
            part:SetPoint("TOP", x, y + 1)
            return part
        end
        local lockBody = lockPart(10, 8, 0, -12)
        local lockCorners = {}
        for _, point in ipairs({"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}) do
            -- Two stepped pixels round each corner without enlarging the silhouette.
            for _, size in ipairs({{2, 1}, {1, 2}}) do
                local corner = book.confirm:CreateTexture(nil, "OVERLAY")
                corner:SetSize(size[1], size[2])
                corner:SetPoint(point, lockBody, point)
                lockCorners[#lockCorners + 1] = corner
            end
        end
        -- A raised, arched shackle and central keyhole distinguish it from a case.
        local lockTop = lockPart(2, 1, 0, -8)
        local lockShoulders = lockPart(4, 1, 0, -9)
        local lockLeft = lockPart(2, 4, -2, -10)
        local lockRight = lockPart(2, 4, 2, -10)
        local keyhole = lockPart(2, 2, 0, -14, "OVERLAY")
        local keyStem = lockPart(1, 2, 0, -16, "OVERLAY")
        lockCorners[#lockCorners + 1] = keyhole
        lockCorners[#lockCorners + 1] = keyStem
        book.confirm.lockParts = { lockBody, lockTop, lockShoulders, lockLeft, lockRight }
        book.confirm.lockCorners = lockCorners
        function book.confirm:SetLockedState(locked)
            self.locked = locked and true or false
            local r, g, b = self.locked and 0.95 or 0.22, self.locked and 0.12 or 0.22, self.locked and 0.06 or 0.22
            for _, part in ipairs(self.lockParts) do
                part:SetColorTexture(r, g, b, 1)
            end
            local bgR, bgG, bgB = self.locked and 0.22 or 0.06, 0.04, 0.02
            for _, corner in ipairs(self.lockCorners) do
                corner:SetColorTexture(bgR, bgG, bgB, 1)
            end
            self:SetBackdropColor(bgR, bgG, bgB, 0.95)
        end
        book.confirm:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetText(self.locked and "Unlock this entry" or "Lock this entry")
            GameTooltip:Show()
        end)
        book.confirm:SetScript("OnLeave", function() GameTooltip:Hide() end)
        book.confirm:SetScript("OnClick", function()
            if selected then
                local entry=journal.entries[selected]
                journal:SetEntryConfirmed(selected,not entry.confirmed)
                message(entry.confirmed and "Entry locked in. Confirmed abilities now appear in tooltips." or "Entry unlocked. Its abilities are hidden from tooltips.")
                refresh()
            end
        end)
        book.confirm:SetLockedState(false)
        book.confirm:Hide()
        book.damageBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        book.damageBorder:SetPoint("TOPLEFT",579,-133); book.damageBorder:SetSize(346,115)
        book.damageBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        -- Neutral translucent cream separates this panel without a coloured cast.
        book.damageBorder:SetBackdropColor(0.045,0.032,0.018,0.88)
        book.damageBorder:SetBackdropBorderColor(0.36,0.23,0.10,0.48)
        local damageHeading = label(book.damageBorder, "Damage taken", 13, -9, 311)
        damageHeading:SetTextColor(1.00, 0.82, 0.14)
        local damageScroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
        damageScroll:SetPoint("TOPLEFT",592,-163); damageScroll:SetSize(296,75)
        book.damageChild=CreateFrame("Frame",nil,damageScroll)
        book.damageChild:SetSize(296,75); damageScroll:SetScrollChild(book.damageChild)
        ns.AutoHideScrollBar(damageScroll)
        book.damageScroll=damageScroll
        book.damageScrollBar=damageScroll.ScrollBar
        if type(book.damageScrollBar)=="function" then book.damageScrollBar=nil end
        if not book.damageScrollBar and type(damageScroll.GetScrollBar)=="function" then book.damageScrollBar=damageScroll:GetScrollBar() end
        if book.damageScrollBar and type(book.damageScrollBar)~="function" then
            local bar=book.damageScrollBar
            local up,down=bar.ScrollUpButton,bar.ScrollDownButton
            local upHeight=up and type(up)~="function" and up:GetHeight() or 16
            local downHeight=down and type(down)~="function" and down:GetHeight() or 16
            -- Anchor to the panel, so its beast-only height change keeps both
            -- arrows flush with the edges without changing the content viewport.
            bar:ClearAllPoints()
            bar:SetPoint("TOPRIGHT",book.damageBorder,"TOPRIGHT",-6,-upHeight)
            bar:SetPoint("BOTTOMRIGHT",book.damageBorder,"BOTTOMRIGHT",-6,downHeight)
            if up and type(up)~="function" then
                up:ClearAllPoints();up:SetPoint("BOTTOM",bar,"TOP",0,0)
            end
            if down and type(down)~="function" then
                down:ClearAllPoints();down:SetPoint("TOP",bar,"BOTTOM",0,0)
            end
            ns.StyleScrollBarTrack(bar)
        end
        book.damageRows={}
        book.noDamage=label(book.damageChild,"No damage recorded.",3,-3,281,"GameFontHighlightSmall")
        book.noDamage:SetTextColor(0.55,0.58,0.58)
        local abilityDivider = detail:CreateTexture(nil, "ARTWORK")
        abilityDivider:SetColorTexture(0.35,0.20,0.08,0.42)
        abilityDivider:SetPoint("TOPLEFT",352,-315); abilityDivider:SetSize(574,1)
        local abilitiesHeading = label(detail, "Recorded abilities", 352, -325, 222, "GameFontNormalLarge")
        abilitiesHeading:SetTextColor(1.00, 0.82, 0.14)
        book.abilityCount = label(detail, "", 580, -331, 346, "GameFontHighlightSmall")
        book.abilityCount:SetJustifyH("RIGHT")
        book.abilityScrollBar=CreateFrame("Slider",nil,detail,"UIPanelScrollBarTemplate")
        book.abilityScrollBar:SetPoint("TOPLEFT",918,-377)
        book.abilityScrollBar:SetSize(16,150)
        local abilityTrackBorder=book.abilityScrollBar:CreateTexture(nil,"BACKGROUND",nil,-2)
        abilityTrackBorder:SetPoint("TOPLEFT",-2,2);abilityTrackBorder:SetPoint("BOTTOMRIGHT",2,-2)
        abilityTrackBorder:SetColorTexture(0.37,0.25,0.11,0.9)
        local abilityTrack=book.abilityScrollBar:CreateTexture(nil,"BACKGROUND",nil,-1)
        abilityTrack:SetPoint("TOPLEFT",-1,1);abilityTrack:SetPoint("BOTTOMRIGHT",1,-1)
        abilityTrack:SetColorTexture(0.045,0.032,0.018,0.9)
        book.abilityScrollBar:SetMinMaxValues(0,0)
        book.abilityScrollBar:SetValueStep(1)
        book.abilityScrollBar:SetObeyStepOnDrag(true)
        book.abilityScrollBar:SetScript("OnValueChanged",function(_,value)
            if book.updatingAbilityScroll then return end
            local nextOffset=math.floor(value+0.5)
            if nextOffset ~= abilityOffset then abilityOffset=nextOffset; refresh() end
        end)
        book.abilityScrollBar:Hide()
        book.abilities = {}
        for i=1,4 do
            local row = CreateFrame("Frame", nil, detail)
            row:SetPoint("TOPLEFT", 352, -360-(i-1)*48); row:SetSize(583, 42)
            row.divider=row:CreateTexture(nil,"ARTWORK")
            row.divider:SetColorTexture(0.35,0.20,0.08,0.16)
            row.divider:SetPoint("TOPLEFT",0,7);row.divider:SetPoint("TOPRIGHT",-9,7)
            row.divider:SetHeight(1)
            row.tooltipCheck=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            row.tooltipCheck:SetPoint("TOPLEFT",-2,0); row.tooltipCheck:SetSize(20,20)
            row.tooltipCheck:SetScript("OnClick",function(self)
                if selected and row.name then journal:SetAbilityTooltip(selected,row.name,self:GetChecked() == true); refresh() end
            end)
            row.tooltipCheck:SetMotionScriptsWhileDisabled(true)
            row.tooltipCheck:SetScript("OnEnter",function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText("Display on tooltip")
                GameTooltip:Show()
            end)
            row.tooltipCheck:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
            row.text = label(row,"",22,0,214)
            row.text:SetWordWrap(false)
            row.note = label(row,"",35,-17,201,"GameFontHighlightSmall")
            row.note:SetHeight(23)
            row.resolve = button(row,"Resolve",244,0,72,function()
                local ok,msg=journal:ResolveAbility(selected,row.name)
                message(msg)
                if ok then refresh() end
            end)
            row.link = button(row,"Edit",322,0,54,function()
                local ability=journal.entries[selected].abilities[row.name]
                local ok,combat=pcall(InCombatLockdown)
                if not ok or (issecretvalue and issecretvalue(combat)) or combat~=false then message("Spell linking is available outside combat."); return end
                book.manualName:SetText(row.name)
                book.manualNote:SetText(ability.note or "")
                book.manualEffects={}
                for effect,enabled in pairs(ability.effects or {}) do if enabled then book.manualEffects[effect]=true end end
                book.effectButton:SetText(effectButtonText(book.manualEffects))
                if ability.spellID and C_Spell and type(C_Spell.GetSpellLink)=="function" then
                    local success,link=pcall(C_Spell.GetSpellLink,ability.spellID)
                    if success and not (issecretvalue and issecretvalue(link)) and type(link)=="string" then book.spellLink:SetText(link) else book.spellLink:SetText(tostring(ability.spellID)) end
                    message("Ability loaded below. Edit its details, then confirm.")
                else
                    book.spellLink:SetText("")
                    message("Ability loaded below. Add an optional spell ID, link, or exact name, then confirm.")
                end
            end)
            row.accept = CreateFrame("Button",nil,row,"UIPanelCloseButton")
            row.accept:SetSize(24,24)
            row.accept:SetPoint("TOPRIGHT",row,"TOPRIGHT",0,-1)
            ns.StyleConfirmButton(row.accept)
            row.accept:SetMotionScriptsWhileDisabled(true)
            row.accept:SetScript("OnEnter",function(self)
                local ability=selected and journal.entries[selected] and journal.entries[selected].abilities[row.name]
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(ability and ability.state=="confirmed" and "Ability confirmed" or "Confirm ability")
                GameTooltip:Show()
            end)
            row.accept:SetScript("OnLeave",function() GameTooltip:Hide() end)
            row.accept:SetScript("OnClick",function()
                journal:SetAbility(selected,row.name,"confirmed"); refresh()
            end)
            row.reject = CreateFrame("Button",nil,row,"UIPanelCloseButton")
            row.reject:SetSize(24,24)
            local rejectCover=row.reject:CreateTexture(nil,"OVERLAY")
            rejectCover:SetPoint("TOPLEFT",6,-6);rejectCover:SetPoint("BOTTOMRIGHT",-6,6)
            rejectCover:SetColorTexture(0.13,0.025,0.015,1)
            row.reject.cover=rejectCover
            local dash=row.reject:CreateTexture(nil,"OVERLAY",nil,1)
            dash:SetSize(10,3);dash:SetPoint("CENTER",0,0)
            dash:SetColorTexture(1,0.82,0.14,1)
            row.reject.dash=dash
            row.reject:SetScript("OnEnter",function(self)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText)
                GameTooltip:Show()
            end)
            row.reject:SetScript("OnLeave",function() GameTooltip:Hide() end)
            row.reject:SetScript("OnClick",function()
                local a=journal.entries[selected].abilities[row.name]
                if a.state=="rejected" then
                    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row.reject) then GameTooltip:Hide() end
                    journal:RemoveAbility(selected,row.name)
                    message("Ability removed from this entry.")
                else journal:SetAbility(selected,row.name,"rejected") end
                refresh()
            end)
            row.reject:SetPoint("TOPRIGHT",row.accept,"TOPLEFT",-6,0)
            row.link:ClearAllPoints(); row.link:SetPoint("TOPRIGHT",row.reject,"TOPLEFT",-6,1)
            row.resolve:ClearAllPoints(); row.resolve:SetPoint("TOPRIGHT",row.link,"TOPLEFT",-6,0)
            row.tooltipArea=CreateFrame("Frame",nil,row)
            row.tooltipArea:EnableMouse(true)
            row.tooltipArea:SetScript("OnEnter",function(self)
                local ability=selected and journal.entries[selected] and journal.entries[selected].abilities[row.name]
                if not ability or ability.state~="confirmed" or type(ability.spellID)~="number" or ability.spellID<=0 then return end
                if GameTooltip and type(GameTooltip.SetOwner)=="function" and type(GameTooltip.SetSpellByID)=="function" then
                    pcall(GameTooltip.SetOwner,GameTooltip,self,"ANCHOR_CURSOR")
                    local ok=pcall(GameTooltip.SetSpellByID,GameTooltip,ability.spellID)
                    if ok then
                        if journal:GetSpellIDTooltips() and type(GameTooltip.AddLine)=="function" then
                            GameTooltip:AddLine("Spell ID: " .. ability.spellID,1,0.82,0)
                        end
                        if type(GameTooltip.Show)=="function" then GameTooltip:Show() end
                    end
                end
            end)
            row.tooltipArea:SetScript("OnLeave",function()
                if GameTooltip and type(GameTooltip.Hide)=="function" then GameTooltip:Hide() end
            end)
            row:EnableMouse(true)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel",function(_,delta) abilityOffset=abilityOffset-delta; refresh() end)
            row.tooltipArea:EnableMouseWheel(true)
            row.tooltipArea:SetScript("OnMouseWheel",function(_,delta) abilityOffset=abilityOffset-delta; refresh() end)
            book.abilities[i]=row
        end
        label(detail,"Ability name you experienced",352,-549,241,"GameFontHighlightSmall")
        label(detail,"Effects |cff999999(optional)|r",608,-549,268,"GameFontHighlightSmall")
        book.manualName=edit(detail,358,-567,234,100)
        book.manualEffects={}
        book.effectButton=button(detail,"Choose effects",614,-567,321,function() book.effectPicker:SetShown(not book.effectPicker:IsShown()); book.refreshEffectPicker() end)
        label(detail,"Field note |cff999999(optional)|r",352,-600,549,"GameFontHighlightSmall")
        book.manualNote=edit(detail,358,-620,577,300)
        label(detail,"Optional spell ID, link, or exact name |cff999999(out of combat)|r",352,-652,549,"GameFontHighlightSmall")
        book.spellLink=edit(detail,358,-672,274,255)
        local function resolveSpellLink()
            local spellID,spellName,errorMessage=journal:ResolveSpell(book.spellLink:GetText())
            if errorMessage then message(errorMessage); return end
            if not spellID then message("No exact readable spell match. Enter an ID or paste a spell link."); return end
            local ok,link=false,nil
            if C_Spell and type(C_Spell.GetSpellLink)=="function" then ok,link=pcall(C_Spell.GetSpellLink,spellID) end
            if ok and not (issecretvalue and issecretvalue(link)) and type(link)=="string" then book.spellLink:SetText(link) else book.spellLink:SetText(tostring(spellID)) end
            if book.manualName:GetText()=="" then book.manualName:SetText(spellName) end
            message("Exact match: "..spellName.." (ID "..spellID..").")
        end
        book.spellLink:SetScript("OnEnterPressed",function(self) resolveSpellLink(); self:ClearFocus() end)
        book.resolveButton=button(detail,"Resolve",640,-672,92,resolveSpellLink)
        book.confirmAbilityButton=button(detail,"Confirm this ability",740,-672,195,function()
            local ok,msg=journal:AddManual(selected,book.manualName:GetText(),book.manualNote:GetText(),book.spellLink:GetText(),book.manualEffects)
            message(msg)
            if ok then book.manualName:SetText(""); book.manualNote:SetText(""); book.spellLink:SetText(""); book.manualEffects={}; book.effectButton:SetText("Choose effects"); refresh() end
        end)
        book.damageButton=button(detail,"Record damage taken",579,-248,343,function()
            book.damageForm:SetShown(not book.damageForm:IsShown())
        end)
        book.beastLoreButton=button(detail,"Known Beast Lore",579,-133,343,function()
            book.beastLore:SetShown(not book.beastLore:IsShown())
        end)
        book.beastLoreButton:Hide()
        local beastLore=CreateFrame("Frame","AzerothFieldbookKnownBeastLore",UIParent,"BackdropTemplate")
        beastLore:SetSize(460,460); beastLore:SetPoint("CENTER")
        beastLore:SetFrameStrata("DIALOG"); beastLore:SetClampedToScreen(true)
        beastLore:SetMovable(true); beastLore:EnableMouse(true); beastLore:RegisterForDrag("LeftButton")
        beastLore:SetScript("OnDragStart",beastLore.StartMoving)
        beastLore:SetScript("OnDragStop",beastLore.StopMovingOrSizing)
        beastLore:SetScript("OnHide",function(self) self:StopMovingOrSizing();self.recipient:ClearFocus() end)
        beastLore:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local lorePaper=beastLore:CreateTexture(nil,"BACKGROUND")
        lorePaper:SetPoint("TOPLEFT",6,-6); lorePaper:SetPoint("BOTTOMRIGHT",-6,6)
        lorePaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        addBackgroundLayer(lorePaper,0.504,0.504,0.48888)
        label(beastLore,"Known Beast Lore",25,-25,300,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        beastLore.creature=label(beastLore,"",25,-58,350,"GameFontNormal")
        beastLore.creature:SetTextColor(1,0.82,0.14)
        beastLore.provenance=label(beastLore,"",25,-82,410,"GameFontHighlightSmall")
        local loreBorder=CreateFrame("Frame",nil,beastLore,"BackdropTemplate")
        loreBorder:SetPoint("TOPLEFT",20,-108);loreBorder:SetSize(420,250)
        loreBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        loreBorder:SetBackdropColor(0.045,0.032,0.018,0.88)
        loreBorder:SetBackdropBorderColor(0.36,0.23,0.10,0.48)
        beastLore.area=CreateFrame("ScrollFrame",nil,beastLore,"UIPanelScrollFrameTemplate")
        beastLore.area:SetPoint("TOPLEFT",32,-118);beastLore.area:SetSize(380,230)
        beastLore.body=CreateFrame("Frame",nil,beastLore.area);beastLore.body:SetSize(380,230)
        beastLore.area:SetScrollChild(beastLore.body);ns.AutoHideScrollBar(beastLore.area)
        beastLore.content=label(beastLore.body,"",2,-2,374,"GameFontHighlightSmall")
        label(beastLore,"Recipient's full name (including surname)",25,-373,410,"GameFontHighlightSmall")
        beastLore.recipient=edit(beastLore,31,-394,242,100)
        beastLore.status=label(beastLore,"Free to send • 0 Knowledge",25,-428,410,"GameFontHighlightSmall")
        beastLore.send=button(beastLore,"Send Beast Lore",287,-394,148,function()
            local captured,err=ns.SharingReport.CaptureLore(journal,selected)
            local tx
            if captured and journal.sharing then tx,err=journal.sharing:Start(captured,beastLore.recipient:GetText(),{}) end
            beastLore.status:SetText(tx and "Offer sent. Waiting for acceptance • 0 Knowledge" or err or "Sharing is unavailable.")
            beastLore.recipient:ClearFocus()
            if tx and sharingWindow then sharingWindow:Open(selected) end
        end)
        beastLore.recipient:SetScript("OnEnterPressed",function(self) self:ClearFocus();beastLore.send:Click() end)
        cornerClose(beastLore)
        beastLore:Hide(); book.beastLore=beastLore
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookKnownBeastLore" end
        book.offenseButton=button(detail,"Offenses",579,-277,111,function()
            book.offensePicker:SetShown(not book.offensePicker:IsShown())
        end)
        book.defenseButton=button(detail,"Defenses",695,-277,111,function()
            book.defensePicker:SetShown(not book.defensePicker:IsShown())
        end)
        book.behaviourButton=button(detail,"Behaviour",811,-277,111,function()
            book.behaviourPicker:SetShown(not book.behaviourPicker:IsShown())
        end)
        book.message=label(detail,"",352,-704,552,"GameFontHighlightSmall")
        book.message:SetHeight(25); book.message:SetJustifyV("TOP")
        local effectPicker=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        effectPicker:SetSize(560,658); effectPicker:SetPoint("CENTER",book,"CENTER"); effectPicker:SetFrameStrata("FULLSCREEN_DIALOG")
        effectPicker:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        effectPicker:EnableMouse(true)
        effectPicker:SetMovable(true)
        effectPicker:SetClampedToScreen(true)
        effectPicker:RegisterForDrag("LeftButton")
        effectPicker:SetScript("OnDragStart",function(self) self:StartMoving() end)
        effectPicker:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        effectPicker:SetScript("OnHide",function(self) self:StopMovingOrSizing() end)
        local effectPaper=effectPicker:CreateTexture(nil,"BACKGROUND",nil,1)
        effectPaper:SetPoint("TOPLEFT",effectPicker,"TOPLEFT",6,-6); effectPaper:SetPoint("BOTTOMRIGHT",effectPicker,"BOTTOMRIGHT",-6,6)
        effectPaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        effectPaper:SetTexCoord(0,1,0,1)
        addBackgroundLayer(effectPaper, 0.504,0.504,0.48888)
        label(effectPicker,"Effects",25,-25,350,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        label(effectPicker,"Choose every effect you personally observed for this ability.",25,-54,470,"GameFontHighlightSmall")
        cornerClose(effectPicker)
        local leftX,rightX=25,290
        label(effectPicker,"Control",leftX,-83,220,"GameFontHighlightSmall")
        label(effectPicker,"Combat",rightX,-83,220,"GameFontHighlightSmall")
        effectPicker.effectButtons={}
        local function addEffect(name,x,y)
            local control=button(effectPicker,"",x,y,235,function()
                book.manualEffects[name]=not book.manualEffects[name]
                book.refreshEffectPicker()
            end)
            control.effectName=name; effectPicker.effectButtons[#effectPicker.effectButtons+1]=control
        end
        for i,name in ipairs(effectGroups[1][2]) do addEffect(name,leftX,-105-(i-1)*23) end
        for i,name in ipairs(effectGroups[2][2]) do addEffect(name,rightX,-105-(i-1)*23) end
        label(effectPicker,"Dispel type",rightX,-338,220,"GameFontHighlightSmall")
        for i,name in ipairs(effectGroups[3][2]) do addEffect(name,rightX,-360-(i-1)*23) end
        label(effectPicker,"School resistance",leftX,-470,235,"GameFontHighlightSmall")
        label(effectPicker,"School immunity",rightX,-470,235,"GameFontHighlightSmall")
        for i, school in ipairs(magicSchools) do
            addEffect(school.name .. " Resistance",leftX,-492-(i-1)*23)
            addEffect(school.name .. " Immunity",rightX,-492-(i-1)*23)
        end
        book.refreshEffectPicker=function()
            for _,control in ipairs(effectPicker.effectButtons) do
                local selected=book.manualEffects[control.effectName]==true
                control:SetText(control.effectName)
                control:SetAlpha(selected and 1 or 0.45)
            end
            book.effectButton:SetText(effectButtonText(book.manualEffects))
        end
        effectPicker:Hide(); book.effectPicker=effectPicker

        local function raiseObservationPicker(picker)
            picker:Raise()
        end
        local observationPickers, lastObservationPicker = {}, nil
        local sharedObservationPosition
        local function rememberObservationPosition(picker)
            if not picker or not journal:GetSingleObservationWindow() then return end
            if ns.WindowPositions then ns.WindowPositions:SaveIfMoved(picker,"ObservationPanels"); return end
            local left, top = picker:GetLeft(), picker:GetTop()
            local scale, parentScale = picker:GetEffectiveScale(), UIParent:GetEffectiveScale()
            if type(left)=="number" and type(top)=="number" and type(scale)=="number"
                and type(parentScale)=="number" and parentScale>0 then
                sharedObservationPosition={left*scale/parentScale,top*scale/parentScale}
            end
        end
        local function applyObservationPosition(picker)
            if ns.WindowPositions then ns.WindowPositions:Restore(picker,"ObservationPanels"); return end
            if not sharedObservationPosition then return end
            local scale, parentScale = picker:GetEffectiveScale(), UIParent:GetEffectiveScale()
            if type(scale)~="number" or scale<=0 or type(parentScale)~="number" then return end
            picker:ClearAllPoints()
            picker:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",
                sharedObservationPosition[1]*parentScale/scale,sharedObservationPosition[2]*parentScale/scale)
        end
        local function closeOtherObservationPickers(active)
            if not journal:GetSingleObservationWindow() then return end
            for _, picker in ipairs(observationPickers) do
                if picker ~= active then picker:Hide() end
            end
        end
        local function createObservationPicker(globalName,title,description,width,height)
            local picker=CreateFrame("Frame",globalName,UIParent,"BackdropTemplate")
            picker:SetSize(width,height); picker:SetPoint("CENTER"); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetClampedToScreen(true)
            picker:SetToplevel(true)
            picker:SetMovable(true); picker:EnableMouse(true); picker:RegisterForDrag("LeftButton")
            picker:SetScript("OnDragStart",function(self) self:StartMoving() end)
            picker:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); rememberObservationPosition(self) end)
            picker:SetScript("OnMouseDown",raiseObservationPicker)
            observationPickers[#observationPickers+1]=picker
            picker:SetScript("OnShow",function(self)
                if journal:GetSingleObservationWindow() then
                    if lastObservationPicker and lastObservationPicker:IsShown() then
                        lastObservationPicker:StopMovingOrSizing()
                        rememberObservationPosition(lastObservationPicker)
                    end
                    applyObservationPosition(self)
                    rememberObservationPosition(self)
                end
                lastObservationPicker=self
                closeOtherObservationPickers(self)
                raiseObservationPicker(self)
            end)
            picker:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
            local paper=picker:CreateTexture(nil,"BACKGROUND",nil,1)
            paper:SetPoint("TOPLEFT",picker,"TOPLEFT",6,-6); paper:SetPoint("BOTTOMRIGHT",picker,"BOTTOMRIGHT",-6,6)
            paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
            paper:SetTexCoord(0,1,0,1)
            addBackgroundLayer(paper,0.504,0.504,0.48888)
            label(picker,title,25,-25,width-155,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
            label(picker,description,25,-54,width-50,"GameFontHighlightSmall")
            cornerClose(picker)
            picker:SetScript("OnHide",function(self)
                self:StopMovingOrSizing()
                if self==lastObservationPicker then rememberObservationPosition(self) end
            end)
            return picker
        end

        local offensePicker=createObservationPicker("AzerothFieldbookBestiaryOffenses","Observed offenses","Select every magic school this creature has been observed casting.",400,220)
        offensePicker.schoolButtons={}
        local refreshOffensePicker
        for i,school in ipairs(magicSchools) do
            local schoolName,schoolColor=school.name,school.color
            local column=(i-1)%2
            local row=math.floor((i-1)/2)
            local control=button(offensePicker,"",25+column*185,-91-row*40,165,function()
                local entry=selected and journal.entries[selected]
                local enabled=entry and type(entry.offenses)=="table" and entry.offenses[schoolName] == true
                journal:SetOffense(selected,schoolName,not enabled)
                refresh(); refreshOffensePicker()
            end)
            control.schoolName=schoolName; control.schoolColor=schoolColor
            offensePicker.schoolButtons[#offensePicker.schoolButtons+1]=control
        end
        refreshOffensePicker=function()
            local entry=selected and journal.entries[selected]
            for _,control in ipairs(offensePicker.schoolButtons) do
                local enabled=entry and type(entry.offenses)=="table" and entry.offenses[control.schoolName] == true
                control:SetText("|cff"..control.schoolColor..control.schoolName.."|r")
                control:SetAlpha(enabled and 1 or 0.45); control:SetEnabled(entry ~= nil and not entry.confirmed)
            end
        end
        offensePicker:HookScript("OnShow",refreshOffensePicker)
        offensePicker:Hide(); book.offensePicker=offensePicker; book.refreshOffensePicker=refreshOffensePicker

        local defensePicker=createObservationPicker("AzerothFieldbookBestiaryDefenses","Observed defenses","Mark each magic school as resistant, immune, or both\nwhen personally observed.",360,335)
        label(defensePicker,"Magic school",35,-88,120,"GameFontHighlightSmall")
        label(defensePicker,"Resistant",170,-88,80,"GameFontHighlightSmall"):SetJustifyH("CENTER")
        label(defensePicker,"Immune",265,-88,70,"GameFontHighlightSmall"):SetJustifyH("CENTER")
        defensePicker.rows={}
        local refreshDefensePicker
        for i,school in ipairs(magicSchools) do
            local schoolName,schoolColor=school.name,school.color
            local y=-112-(i-1)*34
            local schoolLabel=label(defensePicker,"|cff"..schoolColor..schoolName.."|r",40,y-5,120)
            local resistant=CreateFrame("CheckButton",nil,defensePicker,"UICheckButtonTemplate")
            resistant:SetPoint("TOPLEFT",198,y); resistant:SetSize(24,24)
            local immune=CreateFrame("CheckButton",nil,defensePicker,"UICheckButtonTemplate")
            immune:SetPoint("TOPLEFT",288,y); immune:SetSize(24,24)
            resistant:SetScript("OnClick",function(self) journal:SetResistance(selected,schoolName,self:GetChecked()==true); refresh(); refreshDefensePicker() end)
            immune:SetScript("OnClick",function(self) journal:SetImmunity(selected,schoolName,self:GetChecked()==true); refresh(); refreshDefensePicker() end)
            defensePicker.rows[#defensePicker.rows+1]={ schoolName=schoolName, label=schoolLabel, resistant=resistant, immune=immune }
        end
        refreshDefensePicker=function()
            local entry=selected and journal.entries[selected]
            for _,row in ipairs(defensePicker.rows) do
                row.resistant:SetChecked(entry and type(entry.resistances)=="table" and entry.resistances[row.schoolName] == true)
                row.immune:SetChecked(entry and type(entry.immunities)=="table" and entry.immunities[row.schoolName] == true)
                row.resistant:SetEnabled(entry ~= nil and not entry.confirmed); row.immune:SetEnabled(entry ~= nil and not entry.confirmed)
            end
        end
        defensePicker:HookScript("OnShow",refreshDefensePicker)
        defensePicker:Hide(); book.defensePicker=defensePicker; book.refreshDefensePicker=refreshDefensePicker

        local behaviourPicker=createObservationPicker("AzerothFieldbookBestiaryBehaviour","Observed behaviour","Record only behaviour you have personally seen\nfrom this creature.",350,430)
        local behaviourGroups={
            { "Disposition", { "Hostile", "Neutral" } },
            { "Combat style", { "Melee", "Ranged", "Caster" } },
            { "Traits", { "Flees at low health", "Calls allies", "Patrols", "Summons", "Heals", "Enrages", "Stealths" } },
        }
        behaviourPicker.controls={}
        local refreshBehaviourPicker
        local groupY={-88,-150,-244}
        for groupIndex,group in ipairs(behaviourGroups) do
            label(behaviourPicker,group[1],30,groupY[groupIndex],180,"GameFontHighlightSmall")
            for i,name in ipairs(group[2]) do
                local column=(i-1)%2
                local row=math.floor((i-1)/2)
                local y=groupY[groupIndex]-25-row*32
                local control=CreateFrame("CheckButton",nil,behaviourPicker,"UICheckButtonTemplate")
                control:SetPoint("TOPLEFT",30+column*180,y); control:SetSize(24,24)
                control.behaviourName=name
                control.text=label(behaviourPicker,name,60+column*180,y-5,column==0 and 135 or 85,"GameFontHighlightSmall")
                control:SetScript("OnClick",function(self)
                    journal:SetBehaviour(selected,self.behaviourName,self:GetChecked()==true)
                    refresh(); refreshBehaviourPicker()
                end)
                behaviourPicker.controls[#behaviourPicker.controls+1]=control
            end
        end
        refreshBehaviourPicker=function()
            local entry=selected and journal.entries[selected]
            for _,control in ipairs(behaviourPicker.controls) do
                control:SetChecked(entry and type(entry.behaviours)=="table" and entry.behaviours[control.behaviourName] == true)
                control:SetEnabled(entry ~= nil and not entry.confirmed)
            end
        end
        behaviourPicker:HookScript("OnShow",refreshBehaviourPicker)
        behaviourPicker:Hide(); book.behaviourPicker=behaviourPicker; book.refreshBehaviourPicker=refreshBehaviourPicker

        local form=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        form:SetSize(524,230); form:SetPoint("TOPLEFT",book,"TOPRIGHT",6,0); form:SetFrameStrata("FULLSCREEN_DIALOG")
        form:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local formPaper=form:CreateTexture(nil,"BACKGROUND",nil,1)
        -- Run the parchment beneath the complete frame so there are no bare
        -- background strips between the paper and the ornamental border.
        formPaper:SetPoint("TOPLEFT",form,"TOPLEFT",6,-6)
        formPaper:SetPoint("BOTTOMRIGHT",form,"BOTTOMRIGHT",-6,6)
        formPaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        formPaper:SetTexCoord(0,1,0,1)
        addBackgroundLayer(formPaper, 0.504,0.504,0.48888)
        form:EnableMouse(true)
        form:SetMovable(true)
        form:RegisterForDrag("LeftButton")
        form:SetScript("OnDragStart",function(self) self:StartMoving() end)
        form:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        label(form,"Your damage observations",22,-22,480,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        label(form,"Same-level observations are recommended; other levels are welcome.\nHits are affected by your armor and buffs. Record your level at the time.",22,-55,480)
        label(form,"Player level",28,-103,100); label(form,"Creature level",143,-103,110)
        label(form,"Smallest hit",266,-103,105); label(form,"Largest hit",386,-103,110)
        local playerLevel=edit(form,34,-129,94,4)
        form.playerLevel=playerLevel
        local selectedLevel
        local level=CreateFrame("Frame",nil,form,"UIDropDownMenuTemplate")
        level:SetPoint("TOPLEFT",128,-126)
        if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(level,95) end
        if UIDropDownMenu_Initialize then
            UIDropDownMenu_Initialize(level,function(_,menuLevel)
                local entry=selected and journal.entries[selected]
                if not entry or not entry.levelMin then return end
                for value=entry.levelMin,entry.levelMax do
                    local info=UIDropDownMenu_CreateInfo()
                    info.text=tostring(value); info.checked=value==selectedLevel
                    info.func=function() selectedLevel=value; UIDropDownMenu_SetText(level,tostring(value)) end
                    UIDropDownMenu_AddButton(info,menuLevel)
                end
            end)
        end
        local low=edit(form,272,-129,99,9)
        local high=edit(form,392,-129,104,9)
        button(form,"Confirm observation",28,-172,290,function()
            local ok,msg=journal:AddDamage(selected,selectedLevel,low:GetText(),high:GetText(),playerLevel:GetText())
            if ok then form:Hide(); low:SetText(""); high:SetText("") end
            message(msg); refresh()
        end)
        button(form,"Cancel",350,-172,146,function() form:Hide() end)
        form:Hide(); book.damageForm=form
        form:SetScript("OnShow",function()
            local ok,currentLevel=pcall(UnitLevel,"player")
            if not ok or (issecretvalue and issecretvalue(currentLevel)) or type(currentLevel)~="number" or currentLevel<=0 then currentLevel=nil end
            playerLevel:SetText(currentLevel and tostring(currentLevel) or "")
            local entry=selected and journal.entries[selected]
            selectedLevel=entry and entry.levelMin or nil
            if UIDropDownMenu_SetText then UIDropDownMenu_SetText(level,selectedLevel and tostring(selectedLevel) or "No observed level") end
        end)
        local notesForm=CreateFrame("Frame","AzerothFieldbookBestiaryDamageNotes",UIParent,"BackdropTemplate")
        notesForm:SetSize(500,330); notesForm:SetPoint("CENTER",book,"CENTER"); notesForm:SetFrameStrata("FULLSCREEN_DIALOG")
        notesForm:SetClampedToScreen(true)
        notesForm:SetMovable(true); notesForm:EnableMouse(true); notesForm:RegisterForDrag("LeftButton")
        notesForm:SetScript("OnDragStart",function(self) self:StartMoving() end)
        notesForm:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        notesForm:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local notesPaper=notesForm:CreateTexture(nil,"BACKGROUND",nil,1)
        notesPaper:SetPoint("TOPLEFT",notesForm,"TOPLEFT",6,-6); notesPaper:SetPoint("BOTTOMRIGHT",notesForm,"BOTTOMRIGHT",-6,6)
        notesPaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        notesPaper:SetTexCoord(0,1,0,1)
        addBackgroundLayer(notesPaper, 0.504,0.504,0.48888)
        notesForm.title=label(notesForm,"Damage observations",24,-25,400,"GameFontNormalLarge")
        label(notesForm,"Each row is one observation. Removing it recalculates the displayed range.",24,-57,440,"GameFontHighlightSmall")
        button(notesForm,"X",451,-19,25,function() notesForm:Hide() end)
        notesForm.rows={}
        for i=1,6 do
            local row=CreateFrame("Frame",nil,notesForm)
            row:SetPoint("TOPLEFT",27,-91-(i-1)*31); row:SetSize(440,29)
            row.text=label(row,"",2,-6,320)
            row.remove=button(row,"Remove",340,-1,92,function()
                if selected and book.notesLevel and row.noteIndex then
                    journal:RemoveDamageNote(selected,book.notesLevel,row.noteIndex)
                    refresh(); refreshDamageNotes()
                end
            end)
            notesForm.rows[i]=row
        end
        notesForm.previous=button(notesForm,"Previous",27,-282,105,function() noteOffset=math.max(0,noteOffset-6); refreshDamageNotes() end)
        notesForm.next=button(notesForm,"Next",140,-282,105,function() noteOffset=noteOffset+6; refreshDamageNotes() end)
        refreshDamageNotes=function()
            local notes=selected and book.notesLevel and journal:DamageNotes(selected,book.notesLevel) or {}
            noteOffset=math.max(0,math.min(noteOffset,math.max(0,#notes-6)))
            notesForm.title:SetText("Creature level "..tostring(book.notesLevel or "?").." damage observations")
            for i,row in ipairs(notesForm.rows) do
                local index=noteOffset+i; local note=notes[index]
                row.noteIndex=note and index or nil
                if note then
                    local entry=selected and journal.entries[selected]
                    row.remove:SetEnabled(entry ~= nil and not entry.confirmed)
                    row.remove:SetAlpha(entry and not entry.confirmed and 1 or 0.45)
                    row.text:SetText("Player "..note.playerLevel.." · "..(note.legacy and "Older range: " or "Range: ")..note.low.."-"..note.high)
                    row:Show()
                else row:Hide() end
            end
            notesForm.previous:SetEnabled(noteOffset>0)
            notesForm.next:SetEnabled(noteOffset+6<#notes)
            if #notes==0 then notesForm:Hide() end
        end
        notesForm:SetScript("OnHide",function(self) self:StopMovingOrSizing() end)
        notesForm:Hide(); book.notesForm=notesForm

        local rankFrame=CreateFrame("Frame","AzerothFieldbookBestiaryRanks",UIParent,"BackdropTemplate")
        book.rankFrame=rankFrame
        rankFrame:SetSize(320,270); rankFrame:SetPoint("CENTER")
        rankFrame:SetFrameStrata("FULLSCREEN_DIALOG"); rankFrame:SetClampedToScreen(true)
        rankFrame:SetToplevel(true)
        rankFrame:SetScript("OnMouseDown",raiseObservationPicker)
        rankFrame:EnableMouse(true); rankFrame:SetMovable(true); rankFrame:RegisterForDrag("LeftButton")
        rankFrame:SetScript("OnDragStart",function(self) raiseObservationPicker(self); self:StartMoving() end)
        rankFrame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        rankFrame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local rankPaper=rankFrame:CreateTexture(nil,"BACKGROUND",nil,1)
        rankPaper:SetPoint("TOPLEFT",6,-6); rankPaper:SetPoint("BOTTOMRIGHT",-6,6)
        rankPaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        addBackgroundLayer(rankPaper,0.504,0.504,0.48888)
        label(rankFrame,"Filter: Rank",28,-28,264,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        label(rankFrame,"Show any checked rank. None checked shows all.",28,-58,264,"GameFontHighlightSmall")
        local rankChecks={}
        for i, rank in ipairs({"Elite", "Rare", "Rare Elite", "World Boss"}) do
            local check=CreateFrame("CheckButton",nil,rankFrame,"UICheckButtonTemplate")
            check:SetSize(24,24); check:SetPoint("TOPLEFT",28,-88-(i-1)*28)
            label(rankFrame,rank,58,-93-(i-1)*28,234)
            check:SetScript("OnClick",function(self)
                rankFilters[rank]=self:GetChecked() == true and true or nil
                offset=0; refresh()
            end)
            rankChecks[rank]=check
        end
        local function refreshRanks()
            for rank, check in pairs(rankChecks) do check:SetChecked(rankFilters[rank] == true) end
        end
        button(rankFrame,"Clear all",28,-223,135,function()
            for rank in pairs(rankFilters) do rankFilters[rank]=nil end
            offset=0; refreshRanks(); refresh()
        end)
        cornerClose(rankFrame)
        rankFrame:SetScript("OnShow",function(self) raiseObservationPicker(self); refreshRanks() end)
        rankFrame:SetScript("OnHide",function(self) self:StopMovingOrSizing() end)
        rankFrame:Hide()
        table.insert(UISpecialFrames,"AzerothFieldbookBestiaryRanks")

        local locationFrame=CreateFrame("Frame","AzerothFieldbookBestiaryLocations",UIParent,"BackdropTemplate")
        locationFrame:SetSize(440,178); locationFrame:SetPoint("TOPRIGHT",book,"TOPLEFT",-6,0); locationFrame:SetFrameStrata("FULLSCREEN_DIALOG"); locationFrame:SetClampedToScreen(true)
        locationFrame:SetMovable(true); locationFrame:EnableMouse(true); locationFrame:RegisterForDrag("LeftButton")
        locationFrame:SetScript("OnDragStart",function(self) self:StartMoving() end)
        locationFrame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        locationFrame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local locationPaper=locationFrame:CreateTexture(nil,"BACKGROUND",nil,1)
        locationPaper:SetPoint("TOPLEFT",locationFrame,"TOPLEFT",6,-6)
        locationPaper:SetPoint("BOTTOMRIGHT",locationFrame,"BOTTOMRIGHT",-6,6)
        locationPaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        locationPaper:SetTexCoord(0,1,0,1)
        addBackgroundLayer(locationPaper,0.504,0.504,0.48888)
        label(locationFrame,"Filter: Locations",28,-28,360,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        label(locationFrame,"Show creatures observed in any checked location.",28,-58,370,"GameFontHighlightSmall")
        local locationScroll=CreateFrame("ScrollFrame",nil,locationFrame,"UIPanelScrollFrameTemplate")
        locationScroll:SetPoint("TOPLEFT",28,-88); locationScroll:SetSize(370,28)
        local locationChild=CreateFrame("Frame",nil,locationScroll)
        locationChild:SetSize(350,28); locationScroll:SetScrollChild(locationChild)
        locationFrame.scroll=locationScroll
        ns.AutoHideScrollBar(locationScroll)
        local locationRows={}
        local noLocations=label(locationChild,"No locations have been observed yet.",4,-6,330,"GameFontHighlightSmall")
        local refreshLocationPicker
        refreshLocationPicker=function()
            local names={}
            local seen={}
            for id in pairs(journal.entries) do
                local entry=basicInfo(id)
                for location in pairs(entry.locations or {}) do
                    if not seen[location] then seen[location]=true; names[#names+1]=location end
                end
            end
            table.sort(names)
            local contentHeight, viewportHeight=0,0
            for i,location in ipairs(names) do
                local row=locationRows[i]
                if not row then
                    row=CreateFrame("CheckButton",nil,locationChild,"UICheckButtonTemplate")
                    row:SetSize(24,24)
                    row.text=label(locationChild,"",30,0,300,"GameFontHighlightSmall")
                    row:SetScript("OnClick",function(self)
                        locationFilters[self.location]=self:GetChecked() == true and true or nil
                        offset=0; refresh(); refreshLocationPicker()
                    end)
                    locationRows[i]=row
                end
                row.location=location
                row:SetChecked(locationFilters[location] == true)
                row.text:SetText(location)
                row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-contentHeight)
                row.text:ClearAllPoints(); row.text:SetPoint("TOPLEFT",30,-contentHeight-5)
                contentHeight=contentHeight+math.max(28,row.text:GetStringHeight()+10)
                if i<=15 then viewportHeight=contentHeight end
                row:Show(); row.text:Show()
            end
            for i=#names+1,#locationRows do locationRows[i]:Hide(); locationRows[i].text:Hide() end
            noLocations:SetShown(#names==0)
            if #names==0 then
                contentHeight=math.max(28,noLocations:GetStringHeight()+12)
                viewportHeight=contentHeight
            end
            local scrollable = #names>15
            locationFrame:SetHeight(88+viewportHeight+62)
            locationScroll:SetHeight(viewportHeight)
            locationChild:SetHeight(contentHeight)
            locationScroll:UpdateScrollChildRect()
            local scrollBar = locationScroll.ScrollBar
            if type(scrollBar) == "function" then scrollBar = nil end
            if not scrollBar and type(locationScroll.GetScrollBar) == "function" then
                scrollBar = locationScroll:GetScrollBar()
            end
            if scrollBar then scrollBar:SetShown(scrollable) end
            locationScroll:EnableMouseWheel(scrollable)
            local currentScroll = locationScroll:GetVerticalScroll()
            locationScroll:SetVerticalScroll(math.min(type(currentScroll) == "number" and currentScroll or 0, contentHeight-viewportHeight))
        end
        local clearLocations=button(locationFrame,"Clear all",28,0,170,function()
            for location in pairs(locationFilters) do locationFilters[location]=nil end
            offset=0; refresh(); refreshLocationPicker()
        end)
        clearLocations:ClearAllPoints(); clearLocations:SetPoint("BOTTOMLEFT",28,22)
        cornerClose(locationFrame)
        locationFrame.closeButton:SetSize(24,24)
        ns.StyleWindowScrollBar(locationScroll,locationFrame)
        locationFrame:SetScript("OnShow",refreshLocationPicker)
        locationFrame:SetScript("OnHide",function(self) self:StopMovingOrSizing() end)
        locationFrame:Hide(); book.locationFrame=locationFrame

        local sharedBookPagePosition, lastBookPage
        local function rememberBookPagePosition(page)
            if page~=lastBookPage then return end
            if ns.WindowPositions then ns.WindowPositions:SaveIfMoved(page,"BookPages"); return end
            local left,top=page:GetLeft(),page:GetTop()
            local scale,parentScale=page:GetEffectiveScale(),UIParent:GetEffectiveScale()
            if type(left)=="number" and type(top)=="number" and type(scale)=="number" and scale>0
                and type(parentScale)=="number" and parentScale>0 then
                sharedBookPagePosition={left*scale/parentScale,top*scale/parentScale}
            end
        end
        local function showBookPage(page)
            if ns.WindowPositions then
                ns.WindowPositions:Restore(page,"BookPages")
            elseif sharedBookPagePosition then
                local scale,parentScale=page:GetEffectiveScale(),UIParent:GetEffectiveScale()
                if type(scale)=="number" and scale>0 and type(parentScale)=="number" and parentScale>0 then
                    page:ClearAllPoints()
                    page:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",
                        sharedBookPagePosition[1]*parentScale/scale,sharedBookPagePosition[2]*parentScale/scale)
                end
            end
            lastBookPage=page
            page:Raise()
        end
        local function stopBookPageDrag(page)
            page:StopMovingOrSizing()
            rememberBookPagePosition(page)
        end
        local function createBookPage(name,title,bottomInset)
            local page=CreateFrame("Frame",name,UIParent,"BackdropTemplate")
            page:SetSize(610,767); page:SetPoint("TOPLEFT",book,"TOPRIGHT",6,0); page:SetFrameStrata("FULLSCREEN_DIALOG")
            page:SetClampedToScreen(true); page:SetToplevel(true)
            page:SetMovable(true); page:EnableMouse(true); page:RegisterForDrag("LeftButton")
            page:SetScript("OnDragStart",function(self) self:StartMoving() end)
            page:SetScript("OnDragStop",stopBookPageDrag)
            page:SetScript("OnHide",stopBookPageDrag)
            local paper=page:CreateTexture(nil,"BACKGROUND",nil,1)
            paper:SetPoint("TOPLEFT",6,-6); paper:SetPoint("BOTTOMRIGHT",-6,6)
            paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
            paper:SetTexCoord(0,1,0,1); addBackgroundLayer(paper,0.504,0.504,0.48888)
            page.titleBar=CreateFrame("Frame",nil,page,"BackdropTemplate")
            page.titleBar:SetPoint("TOPLEFT",6,-3);page.titleBar:SetPoint("TOPRIGHT",-5,-3)
            page.titleBar:SetHeight(20);page.titleBar:EnableMouse(false)
            page.titleBar:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background-Dark",tile=true,tileSize=32})
            page.titleBar:SetBackdropColor(0.16,0.10,0.055,0.96)
            if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("_UI-Frame-TitleTile") then
                local trim=page.titleBar:CreateTexture(nil,"ARTWORK")
                trim:SetAtlas("_UI-Frame-TitleTile");trim:SetHorizTile(true)
                trim:SetPoint("TOPLEFT");trim:SetPoint("TOPRIGHT");trim:SetHeight(28)
            end
            page.windowTitle=page.titleBar:CreateFontString(nil,"OVERLAY","GameFontNormal")
            page.windowTitle:SetPoint("LEFT",12,-3);page.windowTitle:SetPoint("RIGHT",-28,-3)
            page.windowTitle:SetJustifyH("CENTER");page.windowTitle:SetTextColor(1,0.82,0.14)
            page.windowTitle:SetText(title)
            local scroll=CreateFrame("ScrollFrame",nil,page,"UIPanelScrollFrameTemplate")
            local contentTop=42
            page.contentTop=contentTop
            scroll:SetPoint("TOPLEFT",0,-contentTop); scroll:SetPoint("BOTTOMRIGHT",-32,bottomInset)
            local body=CreateFrame("Frame",nil,scroll)
            body:SetSize(570,1); scroll:SetScrollChild(body)
            ns.AutoHideScrollBar(scroll)
            cornerClose(page)
            page.closeButton:SetSize(24,24)
            page.scroll=scroll
            ns.StyleWindowScrollBar(scroll,page)
            -- Blend clipped text AND controls into the exact underlying paper.
            -- Thin texture strips preserve its pattern and brightness without
            -- requiring a separate gradient asset or intercepting mouse input.
            local fadeHeight,steps=12,24
            local function edgeFade(top)
                local edge=CreateFrame("Frame",nil,page)
                edge:SetFrameLevel(scroll:GetFrameLevel()+10)
                edge:EnableMouse(false)
                edge:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT",scroll,top and "TOPLEFT" or "BOTTOMLEFT",6,top and 1 or 0)
                edge:SetSize(page:GetWidth()-38,fadeHeight)
                edge.strips={}
                for i=1,steps do
                    local strip=edge:CreateTexture(nil,"ARTWORK")
                    strip:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT",0,(top and -1 or 1)*(i-1)*fadeHeight/steps)
                    strip:SetSize(page:GetWidth()-38,fadeHeight/steps)
                    strip:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
                    strip:SetAlpha(1-(i-1)/(steps-1))
                    addBackgroundLayer(strip,0.504,0.504,0.48888)
                    edge.strips[i]=strip
                end
                return edge
            end
            page.topFade,page.bottomFade=edgeFade(true),edgeFade(false)
            -- The parchment masks sit over scrolling content, but under the
            -- window trim. Keep this decorative layer transparent to clicks.
            page.border=CreateFrame("Frame",nil,page,"BackdropTemplate")
            page.border:SetAllPoints(page)
            page.border:SetFrameLevel(page.topFade:GetFrameLevel()+1)
            page.border:EnableMouse(false)
            page.border:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
            page.titleBar:SetFrameLevel(page.topFade:GetFrameLevel())
            page.closeButton:SetFrameLevel(page.border:GetFrameLevel()+1)
            local function layoutFades()
                local width,height=page:GetWidth()-12,page:GetHeight()-12
                local stripHeight=fadeHeight/steps
                for _,edge in ipairs({page.topFade,page.bottomFade}) do
                    edge:SetWidth(page:GetWidth()-38)
                    for i,strip in ipairs(edge.strips) do
                        local y=edge==page.topFade and (contentTop-1+(i-1)*stripHeight) or (page:GetHeight()-bottomInset-i*stripHeight)
                        strip:SetWidth(page:GetWidth()-38)
                        strip:SetTexCoord(0,(page:GetWidth()-38)/width,(y-6)/height,(y+stripHeight-6)/height)
                    end
                end
            end
            local function updateFades()
                local range=math.max(0,scroll:GetVerticalScrollRange() or 0)
                local offset=scroll:GetVerticalScroll() or 0
                page.topFade:SetShown(range>0 and offset>0)
                page.bottomFade:SetShown(range>0 and offset<range)
            end
            scroll:HookScript("OnVerticalScroll",updateFades)
            scroll:HookScript("OnScrollRangeChanged",updateFades)
            scroll:HookScript("OnShow",updateFades)
            page:HookScript("OnSizeChanged",layoutFades)
            layoutFades(); updateFades()
            return page,body
        end
        local eventLog,eventBody=createBookPage("AzerothFieldbookEventLog","Event log",65)
        book.eventLog=eventLog
        local eventPage=0
        local eventText=label(eventBody,"",30,0,530,"GameFontHighlightSmall")
        local eventStatus=label(eventLog,"",255,-722,300,"GameFontHighlightSmall")
        local newer,older
        local function refreshEventLog()
            local log=journal:GetEventLog()
            local entries=log.entries
            eventPage=math.max(0,math.min(eventPage,math.max(0,math.ceil(#entries/50)-1)))
            local lines={}
            for index=#entries-eventPage*50,math.max(1,#entries-eventPage*50-49),-1 do
                local entry=entries[index]
                local stamp=entry.timestamp and date and date("%Y-%m-%d %H:%M:%S",entry.timestamp) or "Unknown time"
                lines[#lines+1]="|cff999999"..stamp.."|r\n"..entry.message
            end
            eventText:SetText(#lines>0 and table.concat(lines,"\n\n") or "No events recorded yet. Events are saved even when chat messages are disabled.")
            local contentHeight=math.max(1,eventText:GetStringHeight()+20)
            local height=math.max(200,math.min(767,eventLog.contentTop+contentHeight+65))
            local resized=eventLog:GetHeight()~=height
            eventLog:SetHeight(height)
            eventBody:SetHeight(contentHeight)
            local range=math.max(0,contentHeight-(height-eventLog.contentTop-65))
            eventLog.scroll:SetVerticalScroll(math.min(eventLog.scroll:GetVerticalScroll() or 0,range))
            eventLog.scroll:UpdateScrollChildRect()
            local bar=eventLog.scroll.ScrollBar
            if bar and type(bar)~="function" then bar:SetShown(range>0) end
            eventLog.scroll:EnableMouseWheel(range>0)
            if resized and eventLog:IsShown() and ns.WindowPositions then ns.WindowPositions:AvoidWindowOverlap(eventLog) end
            eventStatus:SetText(#entries.." events"..(#entries>50 and (" · Page "..(eventPage+1).." / "..math.ceil(#entries/50)) or ""))
            newer:SetShown(#entries>50);older:SetShown(#entries>50)
            newer:SetEnabled(eventPage>0);older:SetEnabled((eventPage+1)*50<#entries)
        end
        newer=button(eventLog,"Newer",30,-722,100,function() eventPage=eventPage-1;eventLog.scroll:SetVerticalScroll(0);refreshEventLog() end)
        older=button(eventLog,"Older",140,-722,100,function() eventPage=eventPage+1;eventLog.scroll:SetVerticalScroll(0);refreshEventLog() end)
        newer:ClearAllPoints();newer:SetPoint("BOTTOMLEFT",30,21)
        older:ClearAllPoints();older:SetPoint("BOTTOMLEFT",140,21)
        eventStatus:ClearAllPoints();eventStatus:SetPoint("BOTTOMRIGHT",-35,28)
        eventLog.text,eventLog.newer,eventLog.older=eventText,newer,older
        eventLog:SetScript("OnShow",refreshEventLog)
        journal:SetEventLogChangedCallback(function() if eventLog:IsShown() then refreshEventLog() end end)
        eventLog:Hide()
        UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookEventLog"
        local help,helpBody=createBookPage("AzerothFieldbookHelp","AZEROTH FIELDBOOK - HELP",24)
        local helpInstructions=label(helpBody,"|cffffd1001. Encounter|r\nTarget or mouse over an attackable NPC to add it to your Bestiary. Its name, creature type, location and observed level range are recorded automatically.\n\n|cffffd1002. Record|r\nReadable casts and safe post-combat observations are added as pending notes. Abilities the addon cannot observe directly can also be added manually. Damage ranges must be recorded manually from your own data. Equal-level observations are recommended so level scaling does not distort the results.\n\n|cffffd1003. Review|r\nOpen the Bestiary and select a creature to review its observations. Confirm accurate abilities, reject doubtful ones, or remove notes you no longer want.\n\n|cffffd1004. Lock Entry|r\nWhen you are satisfied with an entry, lock it to stop further changes. Confirmed abilities appear in NPC tooltips. You continue to earn knowledge from kills and discoveries, and ID Logs, Notes and received Rumours remain separate and editable. Unlock to resume recording and hide its abilities from tooltips.\n\n|cffffd1005. Browse|r\nUse creature-type filters and search to navigate the Bestiary. Click Index to reveal the A-Z tabs; click it again to hide them and clear the letter filter. Account-wide tracking is on by default in Options. Turn it off to use this character's separate journal; changes apply after /reload. Existing character journals merge once when first using account tracking.\n\n|cffffd1006. Share|r\nOutside combat, Share sends one creature to one named recipient. New basics cost 1 knowledge; already-known basics are free. Each selected rumour costs 1 knowledge. Choose any number of existing traits within the report size limit. All received traits are unverified Rumours with the offering character's name. Click Rumours beside Creature Notes to open or close its separate window. The green tick verifies a rumour and adds it to your journal; x rejects it. Unlock an entry before verifying. Matching manual records remove rumours, and repeated rejected claims are marked Previously rejected. Receiving alone never confirms traits or abilities; verified abilities use the normal entry-lock and tooltip rules.\n\nThe book shows knowledge earned. Share shows available knowledge after spending and reservations. Send reserves the maximum cost; acceptance waives the basic-information cost if the recipient already knows it and commits the final cost. Declines and pre-commit cancellation are free. Unknown delivery keeps the cost spent: reopen Share to retry the same report, at most three times within 24 hours. Receiving earns no knowledge; later personal discovery still can. Entry deletion preserves credited milestones and spending; full reset erases them.",35,0,535)
        local pointsBlock=CreateFrame("Frame",nil,helpBody,"BackdropTemplate")
        pointsBlock:SetPoint("TOPLEFT",helpInstructions,"BOTTOMLEFT",0,-18)
        pointsBlock:SetWidth(535)
        pointsBlock:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
        pointsBlock:SetBackdropColor(0.12,0.08,0.03,0.35)
        pointsBlock:SetBackdropBorderColor(0.55,0.40,0.20,1)
        pointsBlock.title=label(pointsBlock,"Knowledge",14,-14,507,"GameFontNormalLarge")
        pointsBlock.title:SetTextColor(1,0.82,0.14)
        pointsBlock.awardHeading=label(pointsBlock,"Earning knowledge",14,0,507,"GameFontNormal")
        pointsBlock.awardHeading:SetTextColor(1,0.82,0.14)
        pointsBlock.awards=label(pointsBlock,"+1 for new creature discovery\n+1 for new location discovery on an existing creature\n\n+1 for 10 kills\n+2 for 25 kills\n+3 for 50 kills\n\nThe first location is included in a new discovery. New levels are recorded but do not award knowledge.",14,0,507,"GameFontHighlightSmall")
        pointsBlock.spendHeading=label(pointsBlock,"Sharing knowledge",14,0,507,"GameFontNormal")
        pointsBlock.spendHeading:SetTextColor(1,0.82,0.14)
        pointsBlock.spending=label(pointsBlock,"Use knowledge to share creature information with another player.\n\n1 knowledge for basic information; free if the recipient already knows it.\n1 knowledge per selected rumour.\n\nSending reserves the maximum cost; knowledge are spent after acceptance. Receiving information is free.",14,0,507,"GameFontHighlightSmall")
        help.pointsBlock=pointsBlock
        local helpDetails=CreateFrame("Frame",nil,helpBody)
        helpDetails:SetPoint("TOPLEFT",pointsBlock,"BOTTOMLEFT",-35,-18)
        helpDetails:SetWidth(570)
        label(helpDetails,"|cffffd100ABOUT|r",35,0,120,"GameFontNormal")
        local about=label(helpDetails,"Created by |cff40c7ebSpinkler|r\nSPECIAL THANKS to |cfff48cbaErna|r, |cffaad372Labrick|r, and |cffff7c0aRhysdogg|r for beta testing\n\nDeveloped with AI-assisted coding tools.\nDesign, direction, testing and final development decisions by the author.",35,-22,535,"GameFontHighlightSmall")
        help:SetScript("OnShow",function(self)
            local pointsHeight=14
            for i,text in ipairs({pointsBlock.title,pointsBlock.awardHeading,pointsBlock.awards,pointsBlock.spendHeading,pointsBlock.spending}) do
                if i>1 then pointsHeight=pointsHeight+((i==2 or i==4) and 16 or 8) end
                text:ClearAllPoints(); text:SetPoint("TOPLEFT",14,-pointsHeight)
                pointsHeight=pointsHeight+text:GetStringHeight()
            end
            pointsHeight=pointsHeight+14
            pointsBlock:SetHeight(pointsHeight)
            helpDetails:SetHeight(22+about:GetStringHeight())
            helpBody:SetHeight(helpInstructions:GetStringHeight()+18+pointsHeight+18+22+about:GetStringHeight()+16)
            showBookPage(self)
        end)
        help:Hide(); book.help=help
        local options,optionsBody=createBookPage("AzerothFieldbookOptions","AZEROTH FIELDBOOK - OPTIONS",65)
        optionsBody:SetHeight(1104)
        local function optionHeading(title,y)
            local heading=label(optionsBody,title,30,-y,510,"GameFontNormalLarge")
            heading:SetTextColor(1,0.82,0.14)
            local font,size,flags=heading:GetFont()
            if font and type(size)=="number" then heading:SetFont(font,size-2,flags) end
        end
        optionHeading("Tracking",0)
        optionHeading("Chat notifications",122)
        label(optionsBody,"Events are saved in the Event log even when chat messages are off.",35,-216,510,"GameFontHighlightSmall")
        optionHeading("Appearance",266)
        optionHeading("Window behavior",462)
        optionHeading("Sharing",600)
        optionHeading("Tooltips and cast IDs",674)
        options.accountWideTracking=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.accountWideTracking:SetPoint("TOPLEFT",30,-26); options.accountWideTracking:SetSize(24,24)
        label(optionsBody,"Account-wide tracking",58,-32,235,"GameFontHighlightSmall")
        options.trackingReload=label(optionsBody,"",300,-32,235,"GameFontHighlightSmall")
        local function refreshTrackingOption()
            options.accountWideTracking:SetChecked(journal:GetAccountWideTracking())
            options.trackingReload:SetText(journal:IsTrackingChangePending() and "Applies after /reload" or "")
        end
        options.accountWideTracking:SetScript("OnClick",function(self)
            journal:SetAccountWideTracking(self:GetChecked() == true)
            refreshTrackingOption()
        end)
        options.accountWideTracking:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText("Account-wide tracking")
            GameTooltip:AddLine("Share Bestiary progress across your characters. Turn off to use this character's journal. Changes apply after /reload.",1,1,1,true)
            GameTooltip:Show()
        end)
        options.accountWideTracking:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        options.autoLockEnabled=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.autoLockEnabled:SetPoint("TOPLEFT",30,-58);options.autoLockEnabled:SetSize(24,24)
        label(optionsBody,"Auto-lock after",58,-64,100,"GameFontHighlightSmall")
        options.autoLockKills=edit(optionsBody,166,-60,45,5)
        options.autoLockKills:SetNumeric(true)
        label(optionsBody,"kills without changes",226,-64,300,"GameFontHighlightSmall")
        options.autoLockEnabled:SetScript("OnClick",function(self)
            journal:SetAutoLockEnabled(self:GetChecked()==true)
            options.autoLockKills:SetEnabled(journal:GetAutoLockEnabled())
        end)
        options.autoLockKills:SetScript("OnEditFocusLost",function(self)
            journal:SetAutoLockKills(self:GetText())
            self:SetText(tostring(journal:GetAutoLockKills()))
        end)
        options.lockNewCritters=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.lockNewCritters:SetPoint("TOPLEFT",30,-90);options.lockNewCritters:SetSize(24,24)
        label(optionsBody,"Lock newly encountered critters",58,-96,470,"GameFontHighlightSmall")
        options.lockNewCritters:SetScript("OnClick",function(self)
            journal:SetLockNewCritters(self:GetChecked()==true)
        end)
        options.lockNewCritters:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText("Lock newly encountered critters")
            GameTooltip:AddLine("Start new critter entries locked after recording their basic information. Existing entries and manual unlocks are kept. You can unlock a critter to record abilities.",1,1,1,true)
            GameTooltip:Show()
        end)
        options.lockNewCritters:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        options.creatureAnnouncement=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.creatureAnnouncement:SetPoint("TOPLEFT",30,-148); options.creatureAnnouncement:SetSize(24,24)
        label(optionsBody,"Show a chat message when a new creature entry is added",58,-154,460,"GameFontHighlightSmall")
        options.creatureAnnouncement:SetScript("OnClick",function(self) journal:SetCreatureAnnouncement(self:GetChecked() == true) end)
        options.spellIDTooltips=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.spellIDTooltips:SetPoint("TOPLEFT",30,-732); options.spellIDTooltips:SetSize(24,24)
        label(optionsBody,"Show spell IDs on tooltips if possible",58,-738,460,"GameFontHighlightSmall")
        options.spellIDTooltips:SetScript("OnClick",function(self) journal:SetSpellIDTooltips(self:GetChecked() == true) end)
        options.displayCastIDs=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.displayCastIDs:SetPoint("TOPLEFT",30,-764); options.displayCastIDs:SetSize(24,24)
        label(optionsBody,"Display Cast IDs",58,-770,460,"GameFontHighlightSmall")
        options.displayCastIDs:SetScript("OnClick",function(self) journal:SetDisplayCastIDs(self:GetChecked() == true) end)
        label(optionsBody,"Background brightness",58,-332,170,"GameFontHighlightSmall")
        options.backgroundBrightness=CreateFrame("Slider",nil,optionsBody,"OptionsSliderTemplate")
        options.backgroundBrightness:SetPoint("TOPLEFT",30,-354)
        options.backgroundBrightness:SetSize(180,16)
        local brightnessTrack=options.backgroundBrightness:CreateTexture(nil,"BACKGROUND")
        brightnessTrack:SetPoint("TOPLEFT",2,-4)
        brightnessTrack:SetPoint("BOTTOMRIGHT",-2,4)
        brightnessTrack:SetColorTexture(0.045,0.032,0.018,1)
        options.backgroundBrightness:SetMinMaxValues(0.5,1.5)
        options.backgroundBrightness:SetValueStep(0.05)
        options.backgroundBrightness:SetObeyStepOnDrag(true)
        options.backgroundBrightness:SetScript("OnValueChanged",function(_,value)
            journal:SetBackgroundBrightness(value)
            book:SetBackgroundBrightness(value)
        end)
        options.killCountTooltips=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.killCountTooltips:SetPoint("TOPLEFT",30,-700);options.killCountTooltips:SetSize(24,24)
        label(optionsBody,"Show kill count in creature tooltips",58,-706,460,"GameFontHighlightSmall")
        options.killCountTooltips:SetScript("OnClick",function(self) journal:SetKillCountTooltips(self:GetChecked()==true) end)
        optionHeading("Spell ID window",814)
        local function windowCheck(key, title, y)
            local check=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
            check:SetPoint("TOPLEFT",30,y); check:SetSize(24,24)
            label(optionsBody,title,58,y-6,470,"GameFontHighlightSmall")
            check:SetScript("OnClick",function(self) journal:SetSpellIDWindowOption(key,self:GetChecked() == true) end)
            options[key]=check
        end
        windowCheck("displaySpellIDWindow","Display Spell ID window",-840)
        windowCheck("spellIDWindowLocked","Lock Spell ID window",-868)
        windowCheck("spellIDWindowIndefinite","Display Spell IDs in the ID window indefinitely",-896)
        windowCheck("displayHoveredAuraSnapshots","Retain hovered aura tooltips",-924)
        windowCheck("spellIDWindowAutoFade","Auto-fade when the Spell ID window contains no data",-952)
        local alphaLabel=label(optionsBody,"Window background opacity: 35%",58,-990,460,"GameFontHighlightSmall")
        options.spellIDWindowAlpha=CreateFrame("Slider",nil,optionsBody,"OptionsSliderTemplate")
        options.spellIDWindowAlpha:SetPoint("TOPLEFT",30,-1010); options.spellIDWindowAlpha:SetSize(180,16)
        local alphaTrack=options.spellIDWindowAlpha:CreateTexture(nil,"BACKGROUND")
        alphaTrack:SetPoint("TOPLEFT",2,-4)
        alphaTrack:SetPoint("BOTTOMRIGHT",-2,4)
        alphaTrack:SetColorTexture(0.045,0.032,0.018,1)
        options.spellIDWindowAlpha:SetMinMaxValues(0,1); options.spellIDWindowAlpha:SetValueStep(0.05)
        options.spellIDWindowAlpha:SetObeyStepOnDrag(true)
        options.spellIDWindowAlpha:SetScript("OnValueChanged",function(_,value)
            journal:SetSpellIDWindowOption("spellIDWindowAlpha",value)
            alphaLabel:SetText("Window background opacity: " .. math.floor(value*100+0.5) .. "%")
        end)
        label(optionsBody,"Each row expires two minutes after observation unless kept indefinitely. IDs are display-only; record useful findings manually.",35,-1050,510,"GameFontHighlightSmall")
        options.singleObservationWindow=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.singleObservationWindow:SetPoint("TOPLEFT",30,-520); options.singleObservationWindow:SetSize(24,24)
        label(optionsBody,"Show only one Offenses, Defenses or Behaviour window",58,-526,470,"GameFontHighlightSmall")
        options.singleObservationWindow:SetScript("OnClick",function(self)
            journal:SetSingleObservationWindow(self:GetChecked() == true)
            local active=lastObservationPicker
            if not active or not active:IsShown() then
                active=nil
                for _,picker in ipairs(observationPickers) do
                    if picker:IsShown() then active=picker; break end
                end
            end
            rememberObservationPosition(active)
            closeOtherObservationPickers(active)
        end)
        options.blockIncomingOffers=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.blockIncomingOffers:SetPoint("TOPLEFT",30,-626); options.blockIncomingOffers:SetSize(24,24)
        label(optionsBody,"Block incoming offers",58,-632,470,"GameFontHighlightSmall")
        options.blockIncomingOffers:SetScript("OnClick",function(self)
            journal:SetBlockIncomingOffers(self:GetChecked() == true)
        end)
        options.blockIncomingOffers:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:SetText("Block incoming offers")
            GameTooltip:AddLine("Automatically decline new offers and close unaccepted offers. Reports already accepted can still finish.",1,1,1,true)
            GameTooltip:Show()
        end)
        options.blockIncomingOffers:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        options.alwaysAnchorToMain=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.alwaysAnchorToMain:SetPoint("TOPLEFT",30,-552); options.alwaysAnchorToMain:SetSize(24,24)
        label(optionsBody,"Always attempt to anchor to main window",58,-558,470,"GameFontHighlightSmall")
        options.alwaysAnchorToMain:SetScript("OnClick",function(self)
            journal:SetAlwaysAnchorToMain(self:GetChecked()==true)
        end)
        local scaleLabel=label(optionsBody,"UI scale: 100%",58,-392,460,"GameFontHighlightSmall")
        options.uiScale=CreateFrame("Slider",nil,optionsBody,"OptionsSliderTemplate")
        options.uiScale:SetPoint("TOPLEFT",30,-414); options.uiScale:SetSize(180,16)
        options.uiScale:SetMinMaxValues(0.5,1.5); options.uiScale:SetValueStep(0.05)
        options.uiScale:SetObeyStepOnDrag(true)
        local scaleTrack=options.uiScale:CreateTexture(nil,"BACKGROUND")
        scaleTrack:SetPoint("TOPLEFT",2,-4); scaleTrack:SetPoint("BOTTOMRIGHT",-2,4)
        scaleTrack:SetColorTexture(0.045,0.032,0.018,1)
        local pendingScale
        local function updateScaleControls(value)
            scaleLabel:SetText("UI scale: " .. math.floor(value*100+0.5) .. "%")
            options.uiScaleDecrease:SetEnabled(value>0.5)
            options.uiScaleIncrease:SetEnabled(value<1.5)
        end
        local function applyScale(value)
            value=math.max(0.5,math.min(1.5,value))
            options.uiScale:SetValue(value)
            pendingScale=nil
            journal:SetUIScale(value)
            updateScaleControls(value)
        end
        local function stepScale(percent)
            applyScale((math.floor(journal:GetUIScale()*100+0.5)+percent)/100)
        end
        options.uiScaleDecrease=button(optionsBody,"-",230,-409,28,function() stepScale(-5) end)
        options.uiScaleReset=button(optionsBody,"100%",264,-409,65,function() applyScale(1) end)
        options.uiScaleIncrease=button(optionsBody,"+",335,-409,28,function() stepScale(5) end)
        options.uiScale:SetScript("OnValueChanged",function(_,value)
            pendingScale=math.max(0.5,math.min(1.5,value))
            updateScaleControls(pendingScale)
        end)
        local function applyPendingScale()
            if pendingScale then applyScale(pendingScale) end
        end
        options.uiScale:SetScript("OnMouseUp",applyPendingScale)
        options.uiScale:EnableKeyboard(false)
        options.uiScale:SetScript("OnHide",function() pendingScale=nil end)
        options.showMinimapButton=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.showMinimapButton:SetPoint("TOPLEFT",30,-292); options.showMinimapButton:SetSize(24,24)
        label(optionsBody,"Show minimap button",58,-298,470,"GameFontHighlightSmall")
        options.showMinimapButton:SetScript("OnClick",function(self) journal:SetMinimapButton(self:GetChecked() == true) end)
        options.pointAnnouncements=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.pointAnnouncements:SetPoint("TOPLEFT",30,-180); options.pointAnnouncements:SetSize(24,24)
        label(optionsBody,"Show a chat message when knowledge is earned",58,-186,470,"GameFontHighlightSmall")
        options.pointAnnouncements:SetScript("OnClick",function(self) journal:SetPointAnnouncements(self:GetChecked() == true) end)
        options.creatureNotesFollowTarget=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        options.creatureNotesFollowTarget:SetPoint("TOPLEFT",30,-488); options.creatureNotesFollowTarget:SetSize(24,24)
        label(optionsBody,"Creature notes follow target selection",58,-494,470,"GameFontHighlightSmall")
        options.creatureNotesFollowTarget:SetScript("OnClick",function(self)
            journal:SetNotesFollowTarget(self:GetChecked() == true)
            if creatureNotes then creatureNotes:FollowTarget() end
        end)
        if type(StaticPopupDialogs) == "table" then
            StaticPopupDialogs.AZEROTHFIELDBOOK_BESTIARY_RESET_CONFIRM = {
                text = "Reset the " .. (journal:IsAccountWideTrackingActive() and "account-wide" or "character") .. " Azeroth Fieldbook Bestiary? This deletes its creature entries, notes, abilities, damage records and sharing knowledge/history, plus this character's settings. Saved backups and the Event log are kept.",
                button1 = YES, button2 = NO,
                OnAccept = function()
                    journal:ResetDatabase()
                    options.lockNewCritters:SetChecked(journal:GetLockNewCritters())
                    options.autoLockEnabled:SetChecked(journal:GetAutoLockEnabled())
                    options.autoLockKills:SetText(tostring(journal:GetAutoLockKills()))
                    options.autoLockKills:SetEnabled(journal:GetAutoLockEnabled())
                    options.blockIncomingOffers:SetChecked(journal:GetBlockIncomingOffers())
                    options.alwaysAnchorToMain:SetChecked(journal:GetAlwaysAnchorToMain())
                    refreshTrackingOption()
                    for location in pairs(locationFilters) do locationFilters[location] = nil end
                    book:SetBackgroundBrightness(journal:GetBackgroundBrightness())
                    refresh()
                    message("The Azeroth Fieldbook Bestiary was reset.")
                end,
                timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            }
        end
        button(options,"Reset Bestiary",30,-722,160,function()
            if StaticPopup_Show then StaticPopup_Show("AZEROTHFIELDBOOK_BESTIARY_RESET_CONFIRM") end
        end)
        if ns.CreateBackupWindow and journal.CreateBackup then
            local backupWindow=ns.CreateBackupWindow(journal,{page=createBookPage,label=label,button=button},function()
                category,initial,reviewOnly,offset=nil,nil,false,0
                for key in pairs(locationFilters) do locationFilters[key]=nil end
                for key in pairs(rankFilters) do rankFilters[key]=nil end
                book.search:SetText("")
                book.notesForm:Hide();book.effectPicker:Hide()
                book.offensePicker:Hide();book.defensePicker:Hide();book.behaviourPicker:Hide()
                if not selected or not journal.entries[selected] then
                    local rows=journal:List()
                    selected=rows[1] and rows[1].id
                end
                choose(selected)
                if sharingWindow then sharingWindow:Refresh() end
            end)
            book.backupWindow=backupWindow
            options.backupButton=button(options,"Backup Bestiary",208,-722,160,function() backupWindow:Open(true) end)
            options.restoreButton=button(options,"Restore Bestiary",378,-722,160,function() backupWindow:Open(false) end)
        end
        options:SetScript("OnShow",function(self)
            showBookPage(self)
            refreshTrackingOption()
            options.singleObservationWindow:SetChecked(journal:GetSingleObservationWindow())
            options.lockNewCritters:SetChecked(journal:GetLockNewCritters())
            options.autoLockEnabled:SetChecked(journal:GetAutoLockEnabled())
            options.autoLockKills:SetText(tostring(journal:GetAutoLockKills()))
            options.autoLockKills:SetEnabled(journal:GetAutoLockEnabled())
            options.alwaysAnchorToMain:SetChecked(journal:GetAlwaysAnchorToMain())
            options.blockIncomingOffers:SetChecked(journal:GetBlockIncomingOffers())
            options.uiScale:SetValue(journal:GetUIScale())
            pendingScale=nil; updateScaleControls(journal:GetUIScale())
            options.showMinimapButton:SetChecked(journal:GetMinimapButton())
            options.pointAnnouncements:SetChecked(journal:GetPointAnnouncements())
            options.creatureNotesFollowTarget:SetChecked(journal:GetNotesFollowTarget())
            options.creatureAnnouncement:SetChecked(journal:GetCreatureAnnouncement())
            options.spellIDTooltips:SetChecked(journal:GetSpellIDTooltips())
            options.killCountTooltips:SetChecked(journal:GetKillCountTooltips())
            options.displayCastIDs:SetChecked(journal:GetDisplayCastIDs())
            for _, key in ipairs({"displaySpellIDWindow","spellIDWindowLocked","spellIDWindowIndefinite","displayHoveredAuraSnapshots","spellIDWindowAutoFade"}) do
                options[key]:SetChecked(journal:GetSpellIDWindowOption(key))
            end
            options.spellIDWindowAlpha:SetValue(journal:GetSpellIDWindowOption("spellIDWindowAlpha"))
            options.backgroundBrightness:SetValue(journal:GetBackgroundBrightness())
        end)
        options:Hide(); book.options=options
        -- Drive window-button borders from visibility, including close buttons,
        -- Escape, shared observation panels and windows opened elsewhere.
        local function watchWindow(control,window,alreadyStyled,activeFilters)
            if not alreadyStyled then styleSelection(control,nil,true) end
            local function update()
                control:SetSelected(window:IsShown() or (activeFilters~=nil and next(activeFilters)~=nil))
            end
            control.UpdateWindowBorder=update
            window:HookScript("OnShow",update)
            window:HookScript("OnHide",update)
            update()
        end
        for _,pair in ipairs({
            {book.damageButton,form},{book.beastLoreButton,beastLore},{book.offenseButton,offensePicker},
            {book.defenseButton,defensePicker},{book.behaviourButton,behaviourPicker},
            {book.effectButton,effectPicker},
        }) do watchWindow(pair[1],pair[2]) end
        watchWindow(book.locationsButton,locationFrame,true,locationFilters)
        watchWindow(book.ranksButton,rankFrame,true,rankFilters)
        for _,pair in ipairs({
            {book.rumoursButton,rumoursWindow},{book.creatureNotesButton,creatureNotes},
            {book.shareButton,sharingWindow},
        }) do
            local control,controller=pair[1],pair[2]
            styleSelection(control,nil,true)
            if controller then
                controller:SetVisibilityCallback(function(shown) control:SetSelected(shown) end)
            end
        end
        book:SetScript("OnHide",function() rankFrame:Hide(); deleteForm:Hide(); book.search:ClearFocus(); book.manualName:ClearFocus(); book.manualNote:ClearFocus(); book.spellLink:ClearFocus(); form:Hide(); notesForm:Hide(); effectPicker:Hide(); locationFrame:Hide(); offensePicker:Hide(); defensePicker:Hide(); behaviourPicker:Hide() end)
        book:HookScript("OnHide",function() beastLore:Hide() end)
        book:HookScript("OnHide",function() sortDismiss:Hide() end)
        local elapsed, revision, nameRevision = 0, -1, -1
        book:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt
            if elapsed>=0.5 then
                elapsed=0
                local currentNames=ns.PlayerNames and ns.PlayerNames.revision or 0
                if revision~=journal.revision or nameRevision~=currentNames then
                    revision,nameRevision=journal.revision,currentNames
                    refresh()
                end
            end
        end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiary"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookHelp"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookOptions"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryDamageNotes"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryLocations"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryOffenses"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryDefenses"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryBehaviour" end
        local bookScale=1
        if UIParent.GetWidth and UIParent.GetHeight then
            bookScale=math.min(1, (UIParent:GetWidth()-30)/960, (UIParent:GetHeight()-30)/740)
        end
        -- Independent roots can move in front of or behind the book. Preserve
        -- the scale formerly inherited by its child dialogs and their anchors.
        for _, window in ipairs({book,deleteForm,effectPicker,form,notesForm,beastLore}) do window:SetScale(bookScale) end
        if ns.UIScale then
            for _, window in ipairs({book,help,options,eventLog,locationFrame,rankFrame,offensePicker,defensePicker,behaviourPicker,deleteForm,effectPicker,form,notesForm,beastLore}) do
                window.afbPreferBookEdge=window~=book
                ns.UIScale:Register(window)
            end
        end
        if ns.WindowFocus then ns.WindowFocus:Register(deleteForm); ns.WindowFocus:Register(beastLore) end
        for _, window in ipairs({form,offensePicker,defensePicker,behaviourPicker,effectPicker}) do
            window.afbAnchorRule="right"
        end
        locationFrame.afbAnchorRule="filters";rankFrame.afbAnchorRule="filters"
        help.afbAnchorRule="pages";options.afbAnchorRule="pages";eventLog.afbAnchorRule="pages"
        -- Establish the initial stacks before registering saved-position overrides.
        for _, picker in ipairs(observationPickers) do
            picker:ClearAllPoints()
            picker.afbAlignBookBottom=true
            picker:SetPoint("BOTTOMLEFT",book,"BOTTOMRIGHT",0,0)
        end
        rankFrame:ClearAllPoints()
        local function positionRankFilter(self)
            self:SetPoint("TOPRIGHT",book,"TOPLEFT",-6,-(locationFrame:GetHeight()*locationFrame:GetEffectiveScale()/self:GetEffectiveScale()+6))
        end
        positionRankFilter(rankFrame)
        if ns.WindowPositions then
            ns.WindowPositions:Register(eventLog,eventLog:GetName())
            for _, window in ipairs({book,locationFrame,notesForm,beastLore}) do
                ns.WindowPositions:Register(window,window:GetName())
            end
            ns.WindowPositions:Register(rankFrame,rankFrame:GetName(),nil,positionRankFilter)
            ns.WindowPositions:Register(effectPicker,"AbilityEffects")
            ns.WindowPositions:Register(form,"DamageObservation")
            for _, window in ipairs({help,options}) do
                local page=window
                ns.WindowPositions:Register(page,page:GetName(),function()
                    return page==lastBookPage and "BookPages" or nil
                end)
            end
            for _, window in ipairs(observationPickers) do
                local picker=window
                ns.WindowPositions:Register(picker,picker:GetName(),function()
                    return journal:GetSingleObservationWindow() and picker==lastObservationPicker and "ObservationPanels" or nil
                end)
            end
        end
        if ns.SpellIDWindow and ns.SpellIDWindow.AnchorToBook then ns.SpellIDWindow:AnchorToBook(book) end
        book:Hide()
    end
    local controller = {}
    function controller:Toggle()
        if not book then build() end
        if book:IsShown() then book:Hide() else
            book:Show()
            local target=journal:Observe("target")
            if target then choose(target) elseif selected and journal.entries[selected] then safeModel(selected); refresh() else refresh() end
        end
    end
    function controller:OpenAtUnit(unit)
        if not book then build() end
        local id=journal:Observe(unit)
        if not id then return false end
        book:Show()
        choose(id)
        return true
    end
    function controller:Refresh()
        if book then refresh() elseif creatureNotes then creatureNotes:Refresh() end
        if sharingWindow then sharingWindow:Refresh() end
    end
    function controller:FollowNotesTarget()
        if creatureNotes then creatureNotes:FollowTarget() end
    end
    function controller:OpenNotes()
        if not book then build() end
        if not selected or not journal.entries[selected] then
            local target=journal:Observe("target")
            if target then choose(target) else book:Show(); refresh() end
        end
        if creatureNotes then creatureNotes:Open(journal:GetNotesTarget() or selected) end
    end
    return controller
end
