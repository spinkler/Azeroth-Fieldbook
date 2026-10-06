BINDING_NAME_AZEROTHFIELDBOOK_ATLAS_POINT = "Record Atlas survey point"
local addonName, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
-- Keep the copper circle at the calibrated elite position for every rank.
local portraitHeaderX=314-(24+(-15*48/58-10-24)*1.20)
BINDING_HEADER_AZEROTHFIELDBOOK = "Azeroth Fieldbook"
BINDING_NAME_CLASSICBESTIARY_BOOK = "Toggle Azeroth Fieldbook"
BINDING_NAME_CLASSICBESTIARY_MOUSEOVER_BOOK = "Open Azeroth Fieldbook at mouseover"
BINDING_NAME_CLASSICBESTIARY_NEXT_ENTRY = "Next Bestiary entry"
BINDING_NAME_CLASSICBESTIARY_PREVIOUS_ENTRY = "Previous Bestiary entry"
BINDING_NAME_AZEROTHFIELDBOOK_NEXT_PAGE = "Next Page"
BINDING_NAME_AZEROTHFIELDBOOK_PREVIOUS_PAGE = "Previous Page"
local effectGroups = {
    { "Control", { "Stun", "Root/Immobilize", "Slow/Snare", "Daze", "Fear", "Horror", "Disorient", "Sleep/Incapacitate", "Polymorph/Transform", "Charm/Possession", "Banish", "Knockback/Pull", "Disarm", "Silence" } },
    { "Combat", { "Interrupt", "School Lockout", "Damage over Time", "Heal", "Heal over Time", "Shield/Absorb", "Damage Reduction", "Damage Vulnerability", "Enrage", "Immunity/Invulnerability" } },
    { "Dispel type", { "Magic", "Curse", "Disease", "Poison" } },
}
local function behaviourText(entry,name)
    return entry.behaviourSources and entry.behaviourSources[name] and ("|cff80d0ff"..name.." [A]|r") or name
end

local function readableNumber(value)
    return not (issecretvalue and issecretvalue(value)) and type(value)=="number"
        and value==value and value>-math.huge and value<math.huge
end
local function playerDifficultyLevel()
    local api=type(UnitEffectiveLevel)=="function" and UnitEffectiveLevel or UnitLevel
    if type(api)~="function" then return end
    local ok,level=pcall(api,"player")
    if ok and readableNumber(level) then return level end
end
local function colorText(text,color)
    if (issecretvalue and issecretvalue(color)) or type(color)~="table" then return text end
    local r,g,b=color.r,color.g,color.b
    for _,value in ipairs({r,g,b}) do
        if not readableNumber(value) or value<0 or value>1 then return text end
    end
    if r==nil or g==nil or b==nil then return text end
    return string.format("|cff%02x%02x%02x%s|r",math.floor(r*255+0.5),math.floor(g*255+0.5),math.floor(b*255+0.5),text)
end
local function difficultyLevelText(level)
    local text=tostring(level)
    local api=GetCreatureDifficultyColor or (DifficultyUtil and DifficultyUtil.GetCreatureDifficultyColor)
    if type(api)~="function" then return text end
    -- Delegate thresholds (including the player's trivial range) to Blizzard.
    local ok,color=pcall(api,level)
    return ok and colorText(text,color) or text
end
-- Blizzard_Minimap/Mainline/Minimap.lua: Minimap_Update's zone-name palette.
local territoryColors={friendly={r=0.1,g=1,b=0.1},hostile={r=1,g=0.1,b=0.1},
    arena={r=1,g=0.1,b=0.1},contested={r=1,g=0.7,b=0},sanctuary={r=0.41,g=0.8,b=0.94}}

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
    artwork("RewardStar.png",reward.parts)
    artwork("RewardCrown.png",reward.crownParts)
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

local function addNameScroller(row,heading)
    local viewport=CreateFrame("ScrollFrame",nil,row)
    viewport:SetPoint("TOPLEFT",28,0);viewport:SetSize(140,28);viewport:EnableMouse(false)
    local body=CreateFrame("Frame",nil,viewport)
    body:SetSize(140,28);body:EnableMouse(false);viewport:SetScrollChild(body)
    local text=body:CreateFontString(nil,"OVERLAY",textFont("GameFontHighlight"))
    text:SetPoint("TOPLEFT",0,-6);text:SetJustifyH("LEFT");text:SetWordWrap(false)
    text:SetShadowColor(0.05,0.05,0.05)
    text:SetShadowOffset(1,-1)
    if heading then
        text:SetShadowColor(0,0,0,0.85);text:SetShadowOffset(1,-1)
        viewport:ClearAllPoints();viewport:SetAllPoints(row)
        text:ClearAllPoints();text:SetPoint("TOPLEFT",0,0)
        text:SetFontObject(textFont("GameFontNormalLarge"))
        local path,size,flags=row.text:GetFont()
        if path then text:SetFont(path,size,flags) end
    end
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
        if heading then body:SetHeight(self:GetHeight()) end
        text:SetText(self.text:GetText());text:SetTextColor(self.text:GetTextColor())
        -- Alpha gradients suppress native font shadows. Let the viewport clip
        -- the scrolling text so its shadow survives throughout the hover.
        self.text:Hide();viewport:Show();viewport:SetHorizontalScroll(0)
        local elapsed,distance=0,width-visible
        local travel=distance/24 -- Gentle movement in UI pixels per second.
        self:SetScript("OnUpdate",function(_,dt)
            if heading and self.text:GetWidth()~=visible then self:StopNameScroll();return end
            elapsed=(elapsed+dt)%(travel*2+2)
            local position
            if elapsed<0.8 then position=0
            elseif elapsed<0.8+travel then position=(elapsed-0.8)*24
            elseif elapsed<2+travel then position=distance
            else position=distance-(elapsed-2-travel)*24 end
            viewport:SetHorizontalScroll(position)
        end)
    end)
    row:SetScript("OnLeave",function(self) self:StopNameScroll() end)
    row:SetScript("OnHide",function(self) self:StopNameScroll() end)
    row:StopNameScroll()
end

function ns.CreateBestiaryBook(journal,shell)
    shell=shell or ns.CreateFieldbookShell({getBrightness=function() return journal:GetBackgroundBrightness() end, getDarkMode=function() return journal:GetDarkMode() end})
    local ui=ns.FieldbookUI
    local label,button,cornerClose,edit=ui.Label,ui.Button,ui.Close,ui.Edit
    local book, selected, offset, abilityOffset = nil, nil, 0, 0
    local creaturePageSize = 18
    local creatureNotes = ns.CreateCreatureNotesWindow and ns.CreateCreatureNotesWindow(journal,function() return shell:GetFrame() end)
    local creatureLocations = ns.CreateCreatureLocationsWindow and ns.CreateCreatureLocationsWindow(journal,function() return book.detail end)
    local sharingWindow = journal.sharing and ns.CreateSharingWindow and ns.CreateSharingWindow(journal,journal.sharing,function() return shell:GetFrame() end)
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
    local behaviourOrder = { "Melee", "Ranged", "Caster", "Flees at low health", "Calls allies", "Patrols", "Summons", "Heals", "Enrages", "Stealths" }
local ink = { 0.75, 0.8, 0.8 }
    local function layoutSummary(status,combat)
        local y=0
        local function section(groups,rows,fontObject)
            book.summaryMeasure:SetFontObject(textFont(fontObject))
            local lines=ns.GroupPropertyLines(groups,524,function(text)
                book.summaryMeasure:SetText(text)
                return book.summaryMeasure:GetStringWidth()
            end)
            for i,text in ipairs(lines) do
                local row=rows[i]
                if not row then
                    row=label(book.summaryArea,"",0,0,524,fontObject)
                    row:SetWordWrap(true); row:SetIndentedWordWrap(true)
                    row:SetJustifyV("TOP")
                    rows[i]=row
                end
                row:ClearAllPoints(); row:SetPoint("TOPLEFT",6,-y)
                row:SetText(text); row:Show()
                y=y+row:GetStringHeight()+2
            end
            for i=#lines+1,#rows do rows[i]:SetText(""); rows[i]:Hide() end
        end
        section(status,book.summaryBasicRows,"GameFontHighlight")
        if #combat>0 then y=y+2 end
        section(combat,book.summaryCombatRows,"GameFontHighlightSmall")
        local height=math.max(16,y)
        book.summaryArea:SetHeight(height)
        -- All summary text stays visible. Grow the book and move the content
        -- below it together, preserving panel sizes and space for the footer.
        local extra=math.max(0,84+height+5-133)
        book.detail:ClearAllPoints(); book.detail:SetPoint("TOPLEFT",0,-extra)
        shell:SetSectionSize("bestiary",960,740+extra)
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
            control:SetDisabledFontObject(textFont(filterFont("GameFontDisable")))
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
                self:SetNormalFontObject(textFont(font))
                self:SetHighlightFontObject(textFont(font))
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
    local function layoutModel(isBeast)
        if book.modelIsBeast==isBeast then return end
        book.modelIsBeast=isBeast
        book.beastLoreButton:SetShown(isBeast)
        book.modelBorder:ClearAllPoints()
        book.modelBorder:SetPoint("TOPLEFT",344,-133)
        book.modelBorder:SetHeight(isBeast and 139 or 168)
        book.model:ClearAllPoints()
        book.model:SetPoint("TOPLEFT",346,-135)
        book.model:SetHeight(isBeast and 135 or 164)
    end
    local function setPortrait(setter,value)
        -- A native portrait setter can return without replacing its texture.
        -- Clear first so a failed request cannot reveal the outgoing portrait.
        book.portrait:SetTexture(nil)
        book.portrait:Hide();book.portraitUnknown:Show()
        local ok=pcall(setter,book.portrait,value)
        local readable,texture=pcall(book.portrait.GetTexture,book.portrait)
        if ok and readable and not (issecretvalue and issecretvalue(texture)) and texture then
            book.portrait:Show();book.portraitUnknown:Hide()
            return true
        end
    end
    local function requestModel()
        if not book.modelPending then return end
        local model,id=book.model,book.modelEntryID
        book.modelAttempts=book.modelAttempts+1
        book.modelRetryElapsed=0
        -- A creature ID can choose a different racial/visual variant. A live
        -- unit preserves the individual appearance, including its equipment.
        -- Revalidate tokens on every retry: target/mouseover can change midway.
        if book.modelAttempts%4~=0 and type(model.SetUnit)=="function" then
            local first=book.modelPreferredUnit or "target"
            for _,unit in ipairs({first,first=="target" and "mouseover" or "target"}) do
                if journal:MatchesModelUnit(unit,id) then
                    local ok,loaded=pcall(model.SetUnit,model,unit)
                    -- Cached loads can finish inside SetUnit, including clients
                    -- that return nil. Never overwrite that completed scene.
                    if model~=book.model or not book.modelPending then return end
                    if ok and not (issecretvalue and issecretvalue(loaded)) and loaded~=false then return end
                end
            end
        end
        -- SetCreature can return normally before the client has the appearance.
        -- Only OnModelLoaded completes the request; retries never clear it.
        pcall(model.SetCreature,model,id)
    end
    local function safeModel(id)
        local entry=id and journal.entries[id]
        local personal=entry and entry.personalEncountered==true or false
        book.modelEntryID,book.modelPersonal=id,personal
        book.modelPending=false
        book.portraitFrame:SetShown(entry~=nil)
        book.portrait:SetTexture(nil)
        book.portrait:Hide();book.portraitUnknown:Show()
        if personal and type(SetPortraitTexture)=="function" then
            local first=book.modelPreferredUnit or "target"
            for _,unit in ipairs({first,first=="target" and "mouseover" or "target"}) do
                if journal:MatchesModelUnit(unit,id) and setPortrait(SetPortraitTexture,unit) then
                    break
                end
            end
        end
        -- Keep the frame shown for asynchronous loading, but conceal any old
        -- rendered appearance until the replacement reports it has loaded.
        book.model:SetAlpha(0)
        book.model:Hide()
        book.model:ClearModel()
        if personal then
            -- OnModelLoaded has no request identity. Keep each native frame
            -- assigned to one creature for its lifetime, so an outgoing load
            -- can never be mistaken for a different entry's completion.
            local model=book.modelFrames[id]
            if not model then
                model=not book.model.afbEntryID and book.model or book.createModel()
                model.afbEntryID=id
                book.modelFrames[id]=model
            end
            if model~=book.model then
                book.model=model
                book.modelIsBeast=nil
                model:SetAlpha(0);model:Hide();model:ClearModel()
            end
            model:SetRotation(0)
            model.afbRotation=0
        end
        -- Unload the outgoing scene before changing either the lore header,
        -- surrounding border or native viewport. Load only after layout ends.
        local basic=entry and basicInfo(id)
        layoutModel(basic~=nil and basic.category=="Beast")
        book.modelUnknown:SetShown(entry~=nil and not personal)
        if entry and not personal then
            book.modelCaption:SetText("")
            return
        end
        book.modelCaption:SetText("")
        if not entry then return end
        -- Query appearance only for an already encountered NPC. Never scan IDs.
        book.model:Show()
        book.modelPending=true
        book.modelAttempts=0
        requestModel()
    end
    local encounterHints={}
    local refresh
    local rumoursWindow = ns.CreateRumoursWindow and ns.CreateRumoursWindow(journal,function()
        if book then refresh() end
        if sharingWindow then sharingWindow:Refresh() end
    end,function()
        return shell:GetFrame(), creatureNotes and creatureNotes:GetFrame()
    end,function() return book and book.damageBorder end)
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
        if book.titleHover then book.titleHover:StopNameScroll() end
        if book.deleteForm then book.deleteForm:Hide() end
        if book.beastLore then
            book.beastLore.area:SetVerticalScroll(0)
            book.beastLore.status:SetText("Free to send • 0 Knowledge")
        end
        if id~=selected and rumoursWindow then rumoursWindow:Hide() end
        selected, abilityOffset = id, 0
        safeModel(id)
        if creatureNotes then creatureNotes:SetCreature(id) end
        if creatureLocations then creatureLocations:SetCreature(id) end
        if rumoursWindow then rumoursWindow:SetCreature(id) end
        book.manualName:SetText(""); book.manualNote:SetText(""); book.spellLink:SetText("")
        book.manualEffects={}; if book.effectButton then book.effectButton:SetText("Choose effects") end
        book.damageForm:Hide()
        message("")
        refresh()
    end
    local function cycleEntry(direction)
        local rows=journal:List(category,book.search:GetText(),reviewOnly,nil,locationFilters,rankFilters)
        if #rows==0 then return false end
        local current
        for i,row in ipairs(rows) do if row.id==selected then current=i; break end end
        if not current then current=direction>0 and 0 or 1 end
        local nextIndex=((current-1+direction)%#rows)+1
        offset=math.floor((nextIndex-1)/creaturePageSize)*creaturePageSize
        choose(rows[nextIndex].id)
        return true
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
        if book.RefreshFilters then book.RefreshFilters() end
        local unletteredRows=journal:List(category,book.search:GetText(),reviewOnly,nil,locationFilters,rankFilters)
        local availableLetters={}
        for _,row in ipairs(unletteredRows) do availableLetters[row.name:sub(1,1):upper()]=true end
        if initial and not availableLetters[initial] then initial=nil; offset=0 end
        for _,letterButton in ipairs(book.letterButtons) do
            letterButton:SetShown(indexOpen)
            letterButton:SetEnabled(availableLetters[letterButton.letter] == true)
            letterButton:SetSelected(initial == letterButton.letter)
        end
        local rows = unletteredRows
        offset = math.max(0, math.min(offset, math.max(0, #rows - creaturePageSize)))
        book.updatingCreatureScroll=true
        book.creatureScrollBar:SetMinMaxValues(0,math.max(0,#rows-creaturePageSize))
        book.creatureScrollBar:SetValue(offset)
        book.creatureScrollBar:SetShown(#rows>creaturePageSize)
        book.updatingCreatureScroll=false
        local visibleRumours=false
        for i, row in ipairs(book.rows) do
            row:EnableMouseWheel(#rows>creaturePageSize)
            local data = rows[offset + i]
            local previous=i>1 and rows[offset+i-1]
            local groupBoundary=data and previous and data.name:sub(1,1):upper()~=previous.name:sub(1,1):upper()
            for _,line in ipairs(row.groupDivider) do line:SetShown(groupBoundary==true) end
            if row.id~=(data and data.id) or (data and row.text:GetText()~=data.name) then row:StopNameScroll() end
            row.id = data and data.id
            if data then
                row.reviewMark:SetText(data.review and "*" or "")
                row.text:SetText(data.name)
                local _,reward=journal:GetKillReward(data.id)
                local unknown=journal.entries[data.id].personalEncountered~=true
                local skull=journal:IsSkull(data.id)
                if unknown or skull then reward=nil end
                row.killReward:SetReward(reward)
                row.unknownMark:SetShown(unknown)
                row.skullMark:SetShown(skull)
                local hasMarker=unknown or skull or reward~=nil
                if row.text:GetWidth()~=(hasMarker and 184 or 203) then row:StopNameScroll() end
                row.text:SetWidth(hasMarker and 184 or 203)
                -- Native alpha gradients suppress the font's drop shadow.
                -- The narrower text width already reserves space for markers.
                row.text:ClearAlphaGradient()
                local rowSelected = data.id == selected
                local hasRumours=journal.GetRumours and #journal:GetRumours(data.id)>0
                if hasRumours then visibleRumours=true;row.text:SetTextColor(114/255,214/255,91/255)
                else row.text:SetTextColor(rowSelected and 1.00 or ink[1], rowSelected and 0.82 or ink[2], rowSelected and 0.14 or ink[3]) end
                row.scrollingName:SetTextColor(row.text:GetTextColor())
                row:SetSelected(rowSelected)
                row:Show()
            else row:Hide() end
        end
        book.indexCount:SetText("* Unlocked"..(visibleRumours and "\n|cff72d65bGreen|r: rumours" or ""))
        local entryCount, points = journal:GetTotals()
        book.entryCount:SetCounts(entryCount,#rows)
        book.pointsCount:SetText(points .. " knowledge")
        local e = selected and journal.entries[selected]
        book.koboldIllustration:SetAlpha(0.33)
        for _,strip in ipairs(book.dragonIllustration) do strip:SetShown(e==nil) end
        local hasLoot=book.lootMode and e and e.loot and next(e.loot.items or {})~=nil
        book.lootFilter:SetShown(hasLoot==true and not (rumoursWindow and rumoursWindow:IsShown()))
        if not hasLoot then book.lootFilterMenu:Hide() end
        local basic=e and basicInfo(selected)
        local isBeast=basic~=nil and basic.category=="Beast"
        -- Do not resize a visible model or re-anchor it on routine refreshes.
        -- Cached models can finish loading synchronously inside safeModel.
        if book.modelEntryID~=selected or book.modelPersonal~=(e and e.personalEncountered==true or false)
            or book.modelIsBeast~=isBeast then safeModel(selected) end
        book.damageBorder:ClearAllPoints()
        book.damageBorder:SetPoint("TOPLEFT",579,-133)
        book.damageBorder:SetHeight(rumoursWindow and rumoursWindow:IsShown() and book.modelBorder:GetHeight() or 115)
        book.damageScroll:ClearAllPoints()
        book.damageScroll:SetPoint("TOPLEFT",592,-163)
        book.damageScroll:SetHeight(75)
        book.damageButton:ClearAllPoints()
        book.damageButton:SetPoint("TOPLEFT",579,-248)
        if isBeast then
            local lore=e.beastLore
            local valid=ns.SharingReport and ns.SharingReport.ValidLore(lore)
            book.beastLore.content:SetText(valid and ns.SharingReport.LoreText(lore,true) or "No Beast Lore recorded. Cast Beast Lore on this creature to record its revealed information.")
            book.beastLore.body:SetHeight(math.max(book.beastLore.area:GetHeight(),book.beastLore.content:GetStringHeight()+12))
            book.beastLore.area:UpdateScrollChildRect()
            book.beastLore.area:RefreshScrollBar()
            book.beastLore.provenance:SetText(valid and ("Locked • Verified • " ..
                (e.beastLoreSource=="gameTooltip" and "Observed in game" or ("Shared by " .. (e.beastLoreSender or "Unknown player")))) or "")
            book.beastLore.send:SetEnabled(valid and journal.sharing~=nil)
        else book.beastLore:Hide() end
        if creatureNotes then creatureNotes:Refresh() end
        if creatureLocations then creatureLocations:Refresh() end
        if book.behaviourPicker:IsShown() then book.refreshBehaviourPicker() end
        if rumoursWindow then rumoursWindow:Refresh() end
        book.creatureNotesButton:SetEnabled(e ~= nil)
        book.creatureLocationsButton:SetEnabled(e ~= nil and creatureLocations ~= nil)
        local hasRumours=e ~= nil and journal.GetRumours and #journal:GetRumours(selected)>0
        book.rumoursButton:SetEnabled(rumoursWindow ~= nil and (hasRumours or rumoursWindow:IsShown()))
        book.rumoursButton:SetText(hasRumours and "|cff72d65bRumours|r" or "Rumours")
        book.shareButton:SetEnabled(sharingWindow~=nil and (e~=nil or journal.sharing:HasActiveOutgoing()))
        book.killCount:SetShown(e ~= nil)
        local _, star, kills = journal:GetKillReward(selected)
        book.killCount:SetText("Kills: " .. kills)
        book.killStar:SetReward(star)
        book.deleteButton:SetEnabled(e ~= nil)
        if book.deleteForm:IsShown() and book.deleteForm.entry ~= e then book.deleteForm:Hide() end
        local needsEncounter = e ~= nil and e.personalEncountered ~= true
        local editable = e ~= nil and not e.confirmed and not needsEncounter
        for _, control in ipairs({book.offenseButton, book.defenseButton, book.behaviourButton,
            book.effectButton, book.confirmAbilityButton, book.resolveButton, book.damageButton,
            book.manualName, book.manualNote, book.spellLink}) do
            control:SetEnabled(editable)
            control:SetAlpha(editable and 1 or 0.45)
            -- Disabled buttons do not reliably receive hover events. A child
            -- frame supplies the explanation without re-enabling the action.
            if not encounterHints[control] then
                local hint=CreateFrame("Frame",nil,control)
                hint:SetAllPoints(control);hint:EnableMouse(true)
                hint:SetFrameLevel(control:GetFrameLevel()+1)
                hint:SetScript("OnEnter",function(self)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                    GameTooltip:SetText(self.title)
                    GameTooltip:AddLine(self.description,1,1,1,true)
                    GameTooltip:Show()
                end)
                local function hideHint(self)
                    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
                end
                hint:SetScript("OnLeave",hideHint);hint:SetScript("OnHide",hideHint)
                control.encounterHint=hint
                encounterHints[control]=hint
            end
            local hint=control.encounterHint
            hint.title=needsEncounter and "Personal encounter required" or "Creature locked"
            hint.description=needsEncounter
                and "You have not personally encountered this creature. Encounter it before recording damage, traits or abilities."
                or "Unlock this creature to edit its observations."
            hint:SetShown(e~=nil and not editable)
        end
        if not editable then
            book.manualName:ClearFocus(); book.manualNote:ClearFocus(); book.spellLink:ClearFocus()
            book.offensePicker:Hide(); book.defensePicker:Hide(); book.behaviourPicker:Hide()
            book.effectPicker:Hide(); book.damageForm:Hide(); book.notesForm:Hide()
        end
        if ns.CreateDetectedAbilityHint and book.detectedAbility then book.detectedAbility:Refresh(selected) end
        book.detail:SetShown(e ~= nil)
        book.empty:SetShown(e == nil)
        if not e then
            safeModel(nil)
            book.tameableBadge:Hide()
            book.confirm:Hide()
            book.modelCaption:SetText("")
            book.titleHover:StopNameScroll();book.titleHover.id=nil
            book.title:SetText("A field guide of your own")
            layoutSummary({"Target or mouse over an enemy to begin a new entry."},{})
            return
        end
        if book.modelEntryID~=selected or book.modelPersonal~=(e.personalEncountered==true) then safeModel(selected) end
        local portraitBorders={Elite="Gold",Rare="Rare-Silver",["Rare Elite"]="Rare-Silver",["World Boss"]="Gold-Winged"}
        local rank=basic.rank or e.rank
        local portraitBorder=portraitBorders[rank]
        book.portraitBorder:SetShown(portraitBorder~=nil)
        book.portraitFrame:ClearAllPoints()
        local scale=48/58
        local inset=rank=="World Boss" and 34 or 15
        -- Align the visible dragon coil with our standalone copper circle.
        -- Native target-frame bounds include padding and do not centre the
        -- artwork on this portrait; use a stable correction for every entry.
        local x,y=-inset*scale-10,11*scale+10
        -- Expand around the face centre so the claws reach the copper rim
        -- without shifting the coil away from the portrait.
        local dragonScale=1.20
        x,y=24+(x-24)*dragonScale,-24+(y+24)*dragonScale
        if portraitBorder then
            local atlas="UI-HUD-UnitFrame-Target-PortraitOn-Boss-"..portraitBorder
            book.portraitBorder:SetAtlas(atlas,true)
            local width,height=book.portraitBorder:GetWidth()*scale*dragonScale,book.portraitBorder:GetHeight()*scale*dragonScale
            book.portraitBorder:SetSize(width,height)
            book.portraitBorder:ClearAllPoints()
            -- Final visual nudge in screen pixels; leave the face anchor alone.
            local pixel=1/book.portraitFrame:GetEffectiveScale()
            book.portraitBorder:SetPoint("TOPLEFT",x+pixel,y-2*pixel)
            book.portraitBorder:SetTexCoord(1,0,0,1)
        end
        book.portraitFrame:SetPoint("TOPLEFT",portraitHeaderX-3/book:GetEffectiveScale(),-60+4/book:GetEffectiveScale())
        local title=basic.name or ("Encountered creature #" .. selected)
        if book.title:GetText()~=title then book.titleHover:StopNameScroll() end
        book.titleHover.id=selected
        book.title:SetText(title)
        local dispositionColours={
            Hostile=FACTION_BAR_COLORS and FACTION_BAR_COLORS[2] or FACTION_RED_COLOR or {r=1,g=0.1,b=0.1},
            Neutral=FACTION_BAR_COLORS and FACTION_BAR_COLORS[4] or FACTION_YELLOW_COLOR or {r=1,g=1,b=0},
            Friendly=FACTION_BAR_COLORS and FACTION_BAR_COLORS[5] or FACTION_GREEN_COLOR or {r=0,g=1,b=0},
        }
        local colourName=journal:GetDispositionNameColour()
        local nameColour=colourName and dispositionColours[basic.disposition]
        book.title:SetTextColor(nameColour and nameColour.r or 1,nameColour and nameColour.g or 0.82,nameColour and nameColour.b or 0.14)
        book.titleHover.scrollingName:SetTextColor(book.title:GetTextColor())
        local levels = "Level Range: |TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:18:18:0:2|t"
        if basic.levelMin then levels = "Level Range: " .. difficultyLevelText(basic.levelMin)
            if basic.levelMax ~= basic.levelMin then levels = levels .. "-" .. difficultyLevelText(basic.levelMax) end
        end
        local status = { basic.category }
        if not colourName and basic.disposition=="Hostile" then
            status[#status+1]=colorText("Hostile",FACTION_BAR_COLORS and FACTION_BAR_COLORS[2] or FACTION_RED_COLOR)
        elseif not colourName and basic.disposition=="Neutral" then
            status[#status+1]=colorText("Neutral",FACTION_BAR_COLORS and FACTION_BAR_COLORS[4] or FACTION_YELLOW_COLOR)
        end
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
        local suppressRank=journal:GetSuppressRankInfo() and
            (e.rank=="Elite" or e.rank=="Rare" or e.rank=="Rare Elite")
        if e.rank and not suppressRank then status[#status + 1] = e.rank end
        status[#status + 1] = levels
        local locations = {}
        for location in pairs(basic.locations or {}) do locations[#locations + 1] = location end
        table.sort(locations)
        book.locationNames={}
        for i,location in ipairs(locations) do
            book.locationNames[i]=location
            local territory=journal.GetLocationTerritory and journal:GetLocationTerritory(location)
            if territory then locations[i]=colorText(location,territoryColors[territory] or NORMAL_FONT_COLOR) end
            locations[i]="|Hafbzone:"..i.."|h"..locations[i].."|h"
        end
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
        for _,name in ipairs(ns.BestiaryImmunityEffects) do
            if e.immunities and e.immunities[name] then immunities[#immunities+1]=name end
        end
        if #offenses > 0 then combat[#combat + 1] = "Casts: " .. table.concat(offenses, ", ") end
        if #resistances > 0 then combat[#combat + 1] = "Resists: " .. table.concat(resistances, ", ") end
        if #immunities > 0 then combat[#combat + 1] = "Immune: " .. table.concat(immunities, ", ") end
        local expected,expectedNames=journal:GetExpectedImmunities(selected),{}
        for _,name in ipairs(ns.BestiaryImmunityEffects) do if expected[name] then expectedNames[#expectedNames+1]=name end end
        if #expectedNames>0 then combat[#combat+1]="Expected Immunities: "..table.concat(expectedNames,", ") end
        local behaviours = {}
        book.tameableBadge:SetShown(e.tameable==true and e.tameabilitySource=="gameTooltip")
        for _,name in ipairs(behaviourOrder) do
            if type(e.behaviours)=="table" and e.behaviours[name] then behaviours[#behaviours+1]=behaviourText(e,name) end
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
        local maxAbilityOffset = math.max(0, #names - 1)
        abilityOffset = math.max(0, math.min(abilityOffset, maxAbilityOffset))
        book.updatingAbilityScroll = true
        book.abilityScrollBar:SetMinMaxValues(0, maxAbilityOffset)
        book.abilityScrollBar:SetValue(abilityOffset)
        book.abilityScrollBar:SetShown(maxAbilityOffset > 0)
        book.updatingAbilityScroll = false
        local abilityHeight=e.confirmed and 344 or 184
        book.abilityEditor:SetShown(not e.confirmed)
        book.abilityScrollBar:SetHeight(e.confirmed and 310 or 150)
        if e.confirmed then
            book.manualName:ClearFocus(); book.manualNote:ClearFocus(); book.spellLink:ClearFocus()
            book.effectPicker:Hide()
        end
        local abilityY,visibleAbilities,abilityFull=0,0,false
        for i, row in ipairs(book.abilities) do
            row:SetWidth(maxAbilityOffset > 0 and 569 or 593)
            row:EnableMouseWheel(maxAbilityOffset > 0)
            local name = names[abilityOffset + i]
            if name then
                local ability = e.abilities[name]
                row:Show()
                row.name = name
                row.tooltipCheck:SetChecked(ability.showInTooltip ~= false)
                local linkMissing = type(ability.spellID) ~= "number" or ability.spellID <= 0
                local icon
                local iconAPI=C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
                if not linkMissing and type(iconAPI)=="function" then
                    local ok,value=pcall(iconAPI,ability.spellID)
                    if ok and not (issecretvalue and issecretvalue(value))
                        and ((readableNumber(value) and value>0) or (type(value)=="string" and value~="")) then icon=value end
                end
                row.icon:SetTexture(icon)
                row.icon:SetShown(icon~=nil)
                row.text:ClearAllPoints()
                row.text:SetPoint("TOPLEFT",icon and 52 or 22,0)
                local textX=icon and 52 or 22
                local description
                local descriptionAPI=C_Spell and C_Spell.GetSpellDescription or GetSpellDescription
                if not linkMissing and type(descriptionAPI)=="function" then
                    local ok,value=pcall(descriptionAPI,ability.spellID)
                    if ok and not (issecretvalue and issecretvalue(value)) and type(value)=="string" then description=value end
                end
                row.description:SetText(description or "")
                local displayName=name
                local automatic = ability.playerLossOfControl or ability.origin == "Automatic buff observation" or ability.origin == "Automatic cast observation"
                row.text:SetText(displayName .. (automatic and "  |cff80d0ff[A]|r" or "") .. (linkMissing and "  [?]" or "") .. (ability.state == "confirmed" and "" or "  [" .. ability.state .. "]"))
                local effects=effectsText(ability.effects)
                local note=ability.note or (ability.origin ~= "Your note" and ability.origin or nil)
                if not ability.note and ability.origin=="Automatic buff observation" then note="|cff999999"..note.."|r" end
                row.note:SetText(effects and note and (effects.." — "..note) or effects or note or "")
                row.accept:SetEnabled(editable and ability.state ~= "confirmed")
                row.accept.cover:SetColorTexture(unpack((editable and ability.state ~= "confirmed") and {0.13,0.025,0.015,1} or {0.22,0.22,0.22,1}))
                row.resolve:SetShown(editable and (linkMissing or ability.state ~= "confirmed"))
                for _,control in ipairs({row.link,row.reject,row.accept}) do control:SetShown(editable) end
                local textRight=row:GetWidth()-9
                if editable then
                    -- Action buttons are anchored to the right edge of the row.
                    textRight=row:GetWidth()-row.accept:GetWidth()-row.reject:GetWidth()-row.link:GetWidth()-18
                    if row.resolve:IsShown() then textRight=textRight-row.resolve:GetWidth()-6 end
                end
                row.text:SetWidth(textRight-textX)
                row.text:SetHeight(0)
                local titleHeight=math.max(20,row.text:GetStringHeight())
                row.description:ClearAllPoints()
                row.description:SetPoint("TOPLEFT",textX,-titleHeight-4)
                row.description:SetWidth(textRight-textX)
                row.description:SetHeight(0)
                local descriptionHeight=description and description~="" and row.description:GetStringHeight() or 0
                row.note:ClearAllPoints()
                row.note:SetPoint("TOPLEFT",textX,-titleHeight-4-descriptionHeight-3)
                row.note:SetWidth(textRight-textX)
                row.note:SetHeight(0)
                local noteHeight=row.note:GetText()~="" and row.note:GetStringHeight() or 0
                local rowHeight=titleHeight+4+descriptionHeight+(noteHeight>0 and noteHeight+3 or 0)+16
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT",342,-360-abilityY)
                row:SetHeight(rowHeight-4)
                if not abilityFull and (e.confirmed or i<=3) and (abilityY+rowHeight<=abilityHeight or i==1) then
                    abilityY=abilityY+rowHeight;visibleAbilities=visibleAbilities+1
                else abilityFull=true;row:Hide() end
                for _,line in ipairs(row.divider) do line:SetShown(i>1) end
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
                row.tooltipCheck:Show()
                row.tooltipCheck:SetEnabled(true)
                for _, control in ipairs({row.resolve,row.link,row.reject}) do control:SetAlpha(editable and 1 or 0.45) end
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
        book.abilityScrollBar:SetShown(abilityOffset>0 or #names>visibleAbilities)
        book.abilityCount:SetText(#names == 0 and (e.confirmed and "No abilities recorded." or "No abilities recorded. Add what you experienced below.") or (#names .. " recorded abilities" .. (#names > visibleAbilities and " - scroll to review" or "")))
        if #names == 0 then book.abilityCount:SetTextColor(0.55,0.58,0.58)
        else book.abilityCount:SetTextColor(unpack(ink)) end
        local levels = {}
        for level in pairs(book.lootMode and {} or e.damage) do levels[#levels + 1] = level end
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
        for _,row in ipairs(book.lootRows or {}) do row:Hide() end
        if book.skinningHeading then book.skinningHeading:Hide() end
        book.damageHeading:SetText(book.lootMode and ("Loot · "..tostring(e.loot and e.loot.samples or 0).." observed corpses") or "Damage taken")
        book.noDamage:SetText(book.lootMode and "No item drops observed yet." or "No damage recorded.")
        local itemIDs={}
        if book.lootMode then
            for id in pairs(e.loot and e.loot.items or {}) do
                local getInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
                local info=type(getInfo)=="function" and {pcall(getInfo,id)} or {}
                local quality=info[1] and info[4]
                if (issecretvalue and issecretvalue(quality)) or type(quality)~="number" or quality<0 or quality>5 then quality=-1 end
                if not book.lootQualityHidden or not book.lootQualityHidden[quality] then itemIDs[#itemIDs+1]=id end
            end
            if next(e.loot and e.loot.items or {}) and #itemIDs==0 then book.noDamage:SetText("No drops match the quality filter.") end
            local skinning={}
            for _,id in ipairs(itemIDs) do
                local fn=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
                local info=type(fn)=="function" and {pcall(fn,id)} or {}
                if info[1] and not (issecretvalue and (issecretvalue(info[7]) or issecretvalue(info[8]))) then
                    skinning[id]=info[7]==7 and info[8]==6 -- Trade goods / leather, not leather armour.
                end
                if not info[1] or info[7]==nil then
                    fn=C_Item and C_Item.GetItemInfo or GetItemInfo
                    info=type(fn)=="function" and {pcall(fn,id)} or {}
                    if info[1] and not (issecretvalue and (issecretvalue(info[13]) or issecretvalue(info[14]))) then
                        skinning[id]=info[13]==7 and info[14]==6
                    end
                end
            end
            table.sort(itemIDs,function(a,b)
                if not not skinning[a]~=not not skinning[b] then return not skinning[a] end
                return a<b
            end)
            local skinningStarted=false
            book.lootRows=book.lootRows or {}
            for i,id in ipairs(itemIDs) do
                if skinning[id] and not skinningStarted then
                    skinningStarted=true
                    if not book.skinningHeading then book.skinningHeading=label(book.damageChild,"Skinning",0,0,296,"GameFontNormal") end
                    book.skinningHeading:ClearAllPoints();book.skinningHeading:SetPoint("TOPLEFT",0,-contentHeight-4)
                    book.skinningHeading:Show();contentHeight=contentHeight+24
                end
                local row=book.lootRows[i]
                if not row then
                    row=CreateFrame("Button",nil,book.damageChild);row:SetSize(296,32)
                    row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetPoint("LEFT",3,0);row.icon:SetSize(26,26)
                    row.name=label(row,"",35,-1,255,"GameFontHighlightSmall")
                    row.stats=label(row,"",35,-16,255,"GameFontHighlightSmall")
                    row.stats:SetTextColor(0.8,0.72,0.52)
                    row:SetScript("OnEnter",function(self)
                        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("item:"..self.itemID)
                        GameTooltip:AddLine("Observed rate: corpses with this item / observed loot sources.",0.8,0.72,0.52,true)
                        if self.skinning then GameTooltip:AddLine("Skinning groups leatherworking materials by item category; historical loot method was not recorded.",0.8,0.72,0.52,true) end
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave",function() GameTooltip:Hide() end)
                    row:SetScript("OnHide",function(self) if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
                    book.lootRows[i]=row
                end
                local item=e.loot.items[id]
                local getInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
                local name,link,icon
                if type(getInfo)=="function" then
                    local info={getInfo(id)}
                    name,link,icon=info[1],info[2],info[10]
                end
                row.skinning=skinning[id]==true
                row.itemID=id;row.name:SetText(link or name or ("Item "..id))
                row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.stats:SetText(string.format("%d items · %d/%d corpses · %.1f%%",item.quantity,item.drops,e.loot.samples,100*item.drops/math.max(1,e.loot.samples)))
                row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-contentHeight);row:Show()
                contentHeight=contentHeight+34
            end
        end
        book.noDamage:SetShown(book.lootMode and #itemIDs==0 or not book.lootMode and #levels==0)
        local viewportHeight = book.damageScroll:GetHeight()
        local damageHeight=math.max(viewportHeight,contentHeight)
        book.damageChild:SetHeight(damageHeight)
        book.damageScroll:UpdateScrollChildRect()
        local scrollable=contentHeight>viewportHeight
        local currentScroll = book.damageScroll:GetVerticalScroll()
        book.damageScroll:SetVerticalScroll(math.min(type(currentScroll) == "number" and currentScroll or 0, damageHeight-viewportHeight))
        if book.damageScrollBar and type(book.damageScrollBar) ~= "function" then book.damageScrollBar:SetShown(scrollable) end
        book.damageScroll:EnableMouseWheel(scrollable)
        book.damageScroll:RefreshScrollBar()
    end
    local function build(content)
        book=content
        book.lootMode=true
        local function addBackgroundLayer(...) shell:AddBackgroundLayer(...) end
        local function applyIllustrationInk(texture,asset,left,right,top,bottom)
            -- Render cropped artwork directly; cropped native ink masks smear
            -- their edge samples on this client.
            texture:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\" .. asset)
            texture:SetTexCoord(left,right,top,bottom)
            texture:SetDesaturated(false)
            addBackgroundLayer(texture,1,1,1,true)
        end
        -- Quiet illustration on the paper, below all interactive content.
        book.gnollIllustration=book:CreateTexture(nil,"BACKGROUND",nil,3)
        book.gnollIllustration:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryGnoll.png")
        -- Full image is 360 x 440 at (-58,-16); keep it left of the divider.
        book.gnollIllustration:SetSize(296,418)
        book.gnollIllustration:SetPoint("BOTTOMLEFT",book,"BOTTOMLEFT",6,6)
        book.gnollIllustration:SetTexCoord(64/360,1,0,1-22/440)
        book.gnollIllustration:SetAlpha(0.33)
        applyIllustrationInk(book.gnollIllustration,"BestiaryGnoll.png",64/360,1,0,1-22/440)
        book.koboldIllustration=book:CreateTexture(nil,"BACKGROUND",nil,3)
        book.koboldIllustration:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryKobold.png")
        book.koboldIllustration:SetSize(334,418)
        book.koboldIllustration:SetPoint("BOTTOMRIGHT",book,"BOTTOMRIGHT",-22,6)
        book.koboldIllustration:SetTexCoord(0,334/360,0,1-22/440)
        book.koboldIllustration:SetAlpha(0.33)
        applyIllustrationInk(book.koboldIllustration,"BestiaryKobold.png",0,334/360,0,1-22/440)
        book.koboldFades={}
        -- Mask only the kobold silhouette, keeping surrounding dragon lines.
        book.dragonIllustration={}
        local dragon=book:CreateTexture(nil,"BACKGROUND",nil,0)
        dragon:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryDragon.png")
        -- Shift the full illustration 202 pixels right, cropping at the paper edge.
        dragon:SetSize(302,360)
        dragon:SetPoint("TOPRIGHT",book,"TOPRIGHT",-2,-122)
        dragon:SetTexCoord(0,302/540,0,1)
        dragon:SetAlpha(0.33)
        applyIllustrationInk(dragon,"BestiaryDragon.png",0,302/540,0,1)
        book.dragonIllustration[1]=dragon
        -- A shallow 12-pixel fade softens the dragon's cropped right edge.
        local dragonEdge={}
        for i=1,12 do
            local strip=book:CreateTexture(nil,"BACKGROUND",nil,1)
            strip:SetPoint("TOPRIGHT",book,"TOPRIGHT",-2-(i-1),-122);strip:SetSize(1,360)
            strip:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png")
            strip:SetAlpha(1-(i-1)/11);addBackgroundLayer(strip,0.504,0.504,0.48888)
            dragonEdge[i]=strip;book.dragonIllustration[#book.dragonIllustration+1]=strip
        end
        local function updateDragonFade()
            local width,height=book:GetWidth()-8,book:GetHeight()-15
            if width<=0 or height<=0 then return end
            for i,strip in ipairs(dragonEdge) do
                local x=book:GetWidth()-2-i-6
                strip:SetTexCoord(x/width,(x+1)/width,113/height,473/height)
            end
        end
        book:HookScript("OnSizeChanged",updateDragonFade);updateDragonFade()
        if type(book.CreateMaskTexture)=="function" and type(dragon.AddMaskTexture)=="function" then
            local mask=book:CreateMaskTexture()
            mask:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\BestiaryKoboldSilhouetteMask.png")
            mask:SetSize(960,740)
            mask:SetPoint("BOTTOMRIGHT",book,"BOTTOMRIGHT",-20,0)
            dragon:AddMaskTexture(mask)
            book.dragonKoboldMask=mask
        end
        -- Sample the same parchment beneath the illustration. These background
        -- strips soften the cropped left/bottom edges without covering controls.
        local gnollFades={}
        local fadeWidth,steps=28,28
        local function addGnollFade(x,y,width,height,alpha,right)
            local strip=book:CreateTexture(nil,"BACKGROUND",nil,4)
            strip:SetPoint("BOTTOMLEFT",book,"BOTTOMLEFT",x,y)
            strip:SetSize(width,height)
            strip:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png")
            strip:SetAlpha(alpha)
            addBackgroundLayer(strip,0.504,0.504,0.48888)
            gnollFades[#gnollFades+1]={texture=strip,x=x,y=y,width=width,height=height,right=right}
            if right then book.koboldFades[#book.koboldFades+1]=strip end
        end
        for i=1,steps do
            local offset=(i-1)*fadeWidth/steps
            local alpha=1-(i-1)/(steps-1)
            addGnollFade(6+offset,6,fadeWidth/steps,418,alpha)
            addGnollFade(6,6+offset,296,fadeWidth/steps,alpha)
            addGnollFade(22+offset,6,fadeWidth/steps,418,alpha,true)
            addGnollFade(22,6+offset,334,fadeWidth/steps,alpha,true)
        end
        local function updateGnollFadeCoords()
            local width,height=book:GetWidth()-8,book:GetHeight()-15
            if width<=0 or height<=0 then return end
            for _,fade in ipairs(gnollFades) do
                local left=fade.right and book:GetWidth()-fade.x-fade.width or fade.x
                fade.texture:ClearAllPoints()
                fade.texture:SetPoint("BOTTOMLEFT",book,"BOTTOMLEFT",left,fade.y)
                local x,y=left-6,fade.y-6
                fade.texture:SetTexCoord(x/width,(x+fade.width)/width,
                    1-(y+fade.height)/height,1-y/height)
            end
        end
        book:HookScript("OnSizeChanged",updateGnollFadeCoords)
        updateGnollFadeCoords()
        book.gnollCornerFade=ui.IllustrationCornerFade(book,shell,6)
        book.pageTitle=ui.SectionTitle(book,"Bestiary")
        book.spine=ns.FieldbookUI.PageDivider(book)
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
        book.entryCount=ui.EntryCount(book)
        book.pointsCount=label(book,"",42,-701,250,"GameFontHighlightSmall")
        book.pointsCount:SetWordWrap(false)
        book.pointsCount:SetTextColor(0.55,0.58,0.58)
        book.search = ui.Search(book,70,-110,168,100)
        book.searchClear=book.search.clearButton
        book.search:HookScript("OnTextChanged", function() offset=0;refresh() end)
        book.searchClear:HookScript("OnClick",function()
            local rows=journal:List(category,"",reviewOnly,nil,locationFilters,rankFilters)
            for index,row in ipairs(rows) do
                if row.id==selected then
                    offset=index-1
                    refresh()
                    break
                end
            end
        end)
        -- Keep the popup independent of book focus/strata changes. Its entire
        -- hierarchy must draw above nested row rewards and scrollbar buttons.
        local sortDismiss=CreateFrame("Button","AzerothFieldbookSortMenu",UIParent)
        sortDismiss:SetAllPoints(UIParent);sortDismiss:SetFrameStrata("FULLSCREEN_DIALOG")
        sortDismiss:SetToplevel(true)
        sortDismiss:SetScript("OnShow",function(self) self:SetScale(shell:GetFrame():GetScale());self:Raise() end)
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
        book.sortButton=button(book,"",270,-110,22,function()
            if book.listFilterMenu then book.listFilterMenu:Hide() end
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
        sortMenu:SetPoint("TOPLEFT",book.sortButton,"BOTTOMLEFT",0,0)
        book.sortMenu,book.sortChoices=sortDismiss,sortChoices
        sortDismiss:Hide()
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookSortMenu" end
        book.review = button(book, "Pending", 42, -543, 88, function()
            reviewOnly = not reviewOnly
            offset = 0; refresh()
        end)
        styleSelection(book.review)
        -- Filters live in the dropdown; the list uses the full left pane.
        book.listFilterButton=ui.FilterButton(book,244,-110,function()
            book.search:ClearFocus();sortDismiss:Hide()
            book.listFilterMenu:SetShown(not book.listFilterMenu:IsShown())
            book.RefreshFilters()
        end)
        book.listFilterButton.ResetFilters=function()
            category=nil;initial=nil;reviewOnly=false;offset=0
            for key in pairs(locationFilters) do locationFilters[key]=nil end
            for key in pairs(rankFilters) do rankFilters[key]=nil end
            book.search:SetText("");book.listFilterMenu:Hide();book.HideFilterSubmenus();refresh()
        end
        local listFilter=book.listFilterButton
        styleSelection(listFilter,nil,true)
        listFilter:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Filter creatures\nRight-click to reset filters.");GameTooltip:Show() end
        end)
        listFilter:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        local filterMenu=CreateFrame("Frame",nil,book,"BackdropTemplate");book.listFilterMenu=filterMenu
        filterMenu:SetSize(190,432)
        filterMenu:SetPoint("TOPLEFT",listFilter,"BOTTOMLEFT",0,0)
        filterMenu:SetFrameLevel(book:GetFrameLevel()+40);filterMenu:EnableMouse(true)
        filterMenu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        filterMenu:SetBackdropColor(0.055,0.04,0.022,1)
        book.filterControls={}
        local function placeFilter(key,control,y)
            control:SetParent(filterMenu);control:SetFrameLevel(filterMenu:GetFrameLevel()+1);control:ClearAllPoints()
            control:SetPoint("TOPLEFT",10,y);control:SetWidth(170)
            control:HookScript("OnClick",function()
                if not book.filterSubmenus[key] then book.HideFilterSubmenus() end
            end)
            book.filterControls[key]={control=control}
        end
        placeFilter("All creatures",book.typeButtons["All creatures"],-10)
        for i,name in ipairs(typeOrder) do placeFilter(name,book.typeButtons[name],-10-i*27) end
        placeFilter("Locations",book.locationsButton,-338)
        placeFilter("Ranks",book.ranksButton,-365)
        placeFilter("Pending",book.review,-392)
        book.filterSubmenus={}
        function book.HideFilterSubmenus(except)
            for key,menu in pairs(book.filterSubmenus) do if key~=except then menu:Hide() end end
        end
        local function addSubmenu(key,selectedFilters,getNames)
            local control=book.filterControls[key].control
            ui.StyleMenuArrow(control)
            local menu=CreateFrame("Frame",nil,filterMenu,"BackdropTemplate")
            book.filterSubmenus[key]=menu
            menu:SetPoint("TOPLEFT",control,"TOPRIGHT",0,8);menu:SetSize(260,120)
            menu:SetFrameLevel(filterMenu:GetFrameLevel()+5);menu:EnableMouse(true);menu:SetClampedToScreen(true)
            menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
            menu:SetBackdropColor(0.055,0.04,0.022,1)
            label(menu,"None checked shows all.",12,-10,236,"GameFontHighlightSmall")
            local scroll=CreateFrame("ScrollFrame",nil,menu,"UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT",10,-32);scroll:SetSize(218,26)
            local body=CreateFrame("Frame",nil,scroll);body:SetSize(218,26);scroll:SetScrollChild(body)
            menu.scroll,menu.rows=scroll,{}
            local empty=label(body,"No locations recorded.",4,-5,214,"GameFontHighlightSmall")
            ns.AutoHideScrollBar(scroll,function() return body:GetHeight() end)
            if scroll.ScrollBar then ns.StyleScrollBarTrack(scroll.ScrollBar,0.4) end
            function menu:Refresh()
                local names=getNames();local height=0
                for i,name in ipairs(names) do
                    local row=self.rows[i]
                    if not row then
                        row=CreateFrame("CheckButton",nil,body,"UICheckButtonTemplate");row:SetSize(24,24)
                        row.label=label(row,"",26,-5,188,"GameFontHighlightSmall");row.label:SetWordWrap(true)
                        row:SetScript("OnClick",function(self)
                            selectedFilters[self.value]=self:GetChecked()==true or nil
                            offset=0;refresh()
                        end)
                        self.rows[i]=row
                    end
                    row.value=name;row.label:SetText(name);row:SetChecked(selectedFilters[name]==true)
                    row:ClearAllPoints();row:SetPoint("TOPLEFT",0,-height);row:Show()
                    height=height+math.max(26,row.label:GetStringHeight()+10)
                end
                for i=#names+1,#self.rows do self.rows[i]:Hide() end
                empty:SetShown(#names==0)
                height=math.max(26,height);local viewport=math.min(208,height)
                body:SetHeight(height);scroll:SetHeight(viewport);self:SetHeight(viewport+76)
                scroll:UpdateScrollChildRect()
                scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),height-viewport))
            end
            menu.clear=button(menu,"Clear all",12,0,236,function()
                for name in pairs(selectedFilters) do selectedFilters[name]=nil end
                offset=0;refresh()
            end)
            menu.clear:ClearAllPoints();menu.clear:SetPoint("BOTTOMLEFT",12,10)
            local function open()
                book.HideFilterSubmenus(key);menu:Refresh();menu:Show()
            end
            control:SetScript("OnEnter",open)
            control:SetScript("OnClick",open)
            menu:Hide()
        end
        addSubmenu("Locations",locationFilters,function()
            local names,seen={},{}
            for id in pairs(journal.entries) do
                for name in pairs(basicInfo(id).locations or {}) do
                    if not seen[name] then seen[name]=true;names[#names+1]=name end
                end
            end
            table.sort(names);return names
        end)
        addSubmenu("Ranks",rankFilters,function() return {"Elite","Rare","Rare Elite","World Boss"} end)
        for key,pair in pairs(book.filterControls) do
            if not book.filterSubmenus[key] then pair.control:SetScript("OnEnter",function() book.HideFilterSubmenus() end) end
        end
        function book.RefreshFilters()
            for key,pair in pairs(book.filterControls) do
                local selectedFilter
                if key=="Locations" then selectedFilter=next(locationFilters)~=nil
                elseif key=="Ranks" then selectedFilter=next(rankFilters)~=nil
                elseif key=="Pending" then selectedFilter=reviewOnly
                else selectedFilter=(key=="All creatures" and category==nil) or category==key end
                pair.control:SetSelected(selectedFilter)
            end
            for _,menu in pairs(book.filterSubmenus) do if menu:IsShown() then menu:Refresh() end end
            listFilter:SetSelected(filterMenu:IsShown() or category~=nil or reviewOnly or next(locationFilters)~=nil or next(rankFilters)~=nil)
        end
        ui.DismissOnOutsideClick(filterMenu,listFilter,book.filterSubmenus)
        filterMenu:SetScript("OnShow",book.RefreshFilters)
        filterMenu:SetScript("OnHide",function() book.HideFilterSubmenus();book.RefreshFilters() end)
        filterMenu:Hide()
        book:HookScript("OnHide",function() filterMenu:Hide() end)
        book.rows = {}
        book.creatureScrollBar=CreateFrame("Slider",nil,book,"UIPanelScrollBarTemplate")
        book.creatureScrollBar:SetPoint("TOPLEFT",282,-156)
        book.creatureScrollBar:SetSize(14,454)
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
            row:SetPoint("TOPLEFT", 42, -140 - (i-1)*27); row:SetSize(236, 26)
            ns.FieldbookUI.StyleMenuRow(row)
            row.groupDivider=ns.FieldbookUI.EntryDivider(row,1,236)
            row.reviewMark = label(row, "", 16, -6, 10)
            row.reviewMark:SetTextColor(1, 1, 1)
            row.reviewMark:SetWordWrap(false)
            row.text = label(row, "", 28, -6, 203)
            row.text:SetWordWrap(false)
            addNameScroller(row)
            row.killReward=createKillReward(row,1)
            row.killReward:SetPoint("RIGHT",row,"RIGHT",-5,0)
            row.unknownMark=row:CreateFontString(nil,"OVERLAY",textFont("GameFontNormalLarge"))
            row.unknownMark:SetPoint("CENTER",row.killReward,"CENTER",0,0)
            row.unknownMark:SetText("?")
            row.unknownMark:SetTextColor(1,0.82,0.14)
            row.unknownMark:SetShadowColor(0,0,0,0.7)
            row.unknownMark:SetShadowOffset(1,-1)
            row.unknownMark:Hide()
            row.skullMark=row:CreateTexture(nil,"OVERLAY")
            row.skullMark:SetPoint("CENTER",row.killReward,"CENTER",0,0);row.skullMark:SetSize(16,16)
            row.skullMark:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
            row.skullMark:Hide()
            row:SetScript("OnClick", function(self) if self.id then choose(self.id) end end)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta) offset=offset-delta*3; refresh() end)
            book.rows[i] = row
        end
        local deleteForm=ui.DeletePanel(book,shell,"Delete creature entry",true)
        deleteForm.title:SetFontObject(textFont("GameFontNormalLarge"))
        book.deleteForm=deleteForm
        book.deleteButton=button(book,"Delete",174,-672,118,function()
            local id=selected;local entry=id and journal.entries[id]
            if not entry then return end
            deleteForm.id,deleteForm.entry=id,entry
            local lead="Permanently delete |cffffff00"..(basicInfo(id).name or ("Encountered creature #"..id)).."|r?"
            deleteForm:Open("Its observations, abilities, notes, damage records and rumours will be removed. This cannot be undone. Earned credit and spending remain.\n\nDeselect this creature before targeting or hovering over it again to restore its entry.",function()
                if selected~=id or journal.entries[id]~=entry then return nil,"Selection changed; nothing deleted." end
                if journal:DeleteEntry(id) then
                    choose(nil);message("Creature entry deleted. Deselect it before targeting or hovering over it again.");return true
                end
                return nil,"Could not delete this entry."
            end,lead)
        end)
        book.shareButton = ui.ShareButton(book, function()
            if sharingWindow then sharingWindow:Open(selected) end
        end)
        deleteForm:ClearAllPoints();deleteForm:SetPoint("TOPLEFT",3,-60);deleteForm:SetSize(294,648)
        deleteForm:SetBackdrop(nil)
        deleteForm.paper:Hide()
        deleteForm.title:ClearAllPoints();deleteForm.title:SetPoint("TOPLEFT",34,0);deleteForm.title:SetWidth(255)
        deleteForm.title:SetJustifyH("CENTER")
        deleteForm.scroll:ClearAllPoints();deleteForm.scroll:SetPoint("TOPLEFT",39,-52);deleteForm.scroll:SetSize(230,450)
        deleteForm.body:SetWidth(230);deleteForm.lead:SetWidth(230);deleteForm.description:SetWidth(230)
        deleteForm.confirmationHint:ClearAllPoints();deleteForm.confirmationHint:SetPoint("TOPLEFT",39,-546)
        deleteForm.confirmationHint:SetWidth(250)
        deleteForm.input:ClearAllPoints();deleteForm.input:SetPoint("TOPLEFT",44,-576);deleteForm.input:SetWidth(240)
        deleteForm.confirm:ClearAllPoints();deleteForm.confirm:SetPoint("TOPLEFT",39,-612);deleteForm.confirm:SetWidth(118)
        deleteForm.cancel:ClearAllPoints();deleteForm.cancel:SetPoint("TOPLEFT",171,-612);deleteForm.cancel:SetWidth(118)
        local hiddenForDelete
        local function hideDeleteControls()
            for _,key in ipairs({"pageTitle","search","searchClear","indexButton","listFilterButton",
                "sortButton","creatureScrollBar","indexCount","shareButton","deleteButton"}) do
                local control=book[key]
                if control then
                    if hiddenForDelete[control]==nil then hiddenForDelete[control]=control:IsShown() end
                    control:Hide()
                end
            end
            for _,controls in ipairs({book.rows or {},book.letterButtons or {},book.typeButtons or {}}) do
                for _,control in pairs(controls) do
                    if hiddenForDelete[control]==nil then hiddenForDelete[control]=control:IsShown() end
                    control:Hide()
                end
            end
        end
        deleteForm:HookScript("OnShow",function()
            hiddenForDelete={};book.search:ClearFocus();filterMenu:Hide();sortDismiss:Hide()
            book.HideFilterSubmenus();hideDeleteControls()
        end)
        deleteForm:HookScript("OnHide",function()
            if not hiddenForDelete then return end
            for control,shown in pairs(hiddenForDelete) do control:SetShown(shown) end
            hiddenForDelete=nil;refresh()
        end)
        local refreshWithList=refresh
        refresh=function()
            refreshWithList()
            if hiddenForDelete and deleteForm:IsShown() then hideDeleteControls() end
        end
        book.indexCount = label(book, "* Unlocked", 42, -628, 250, "GameFontHighlightSmall")
        book.indexCount:SetHeight(44)
        book.indexCount:SetJustifyV("MIDDLE")
        book.indexCount:SetTextColor(0.55,0.58,0.58)
        book.indexButton = button(book, "Index", 3, -110, 57, function()
            indexOpen = not indexOpen
            initial=nil; offset=0; refresh()
        end)
        book.indexButton:SetHeight(22)
        book.indexButton:SetNormalFontObject(textFont("GameFontNormalSmall"))
        book.indexButton:SetHighlightFontObject(textFont("GameFontHighlightSmall"))
        styleSelection(book.indexButton)
        -- Index controls must remain above the page's illustration fade textures.
        local indexFrameLevel=math.max(book:GetFrameLevel()+1,shell:GetFrame().titleIcon:GetFrameLevel()-1)
        book.indexButton:SetFrameLevel(indexFrameLevel)
        book.letterButtons = {}
        for i=1,26 do
            local letter = string.char(64+i)
            local tab = button(book, letter, 3, -139-(i-1)*21, 29, function()
                local rows=journal:List(category,book.search:GetText(),reviewOnly,nil,locationFilters,rankFilters)
                for index,row in ipairs(rows) do
                    if row.name:sub(1,1):upper()==letter then
                        initial=letter;offset=index-1;refresh();break
                    end
                end
            end)
            tab:SetHeight(19)
            -- Extend only the left edge; compensate for the half-pixel shift
            -- in its centre so the letter keeps its original screen position.
            local text=tab:GetFontString()
            if text then text:ClearAllPoints();text:SetPoint("CENTER",tab,"CENTER",0.5,0) end
            tab:SetFrameLevel(indexFrameLevel)
            tab:SetDisabledFontObject(textFont("GameFontDisable"))
            tab.letter=letter; styleSelection(tab)
            tab:Hide()
            book.letterButtons[i]=tab
        end
        book.portraitFrame=CreateFrame("Frame",nil,book)
        book.portraitFrame:SetPoint("TOPLEFT",portraitHeaderX-3/book:GetEffectiveScale(),-60+4/book:GetEffectiveScale());book.portraitFrame:SetSize(48,48)
        -- Every creature uses the same copper rim, beneath any dragon overlay.
        book.portraitRings={}
        for i,spec in ipairs({
            {57.75,0.12,0.075,0.035},
            {56.25,0.38,0.23,0.09},
            {54.75,0.76,0.51,0.22},
            {52.5,0.53,0.31,0.11},
            {50.25,0.20,0.115,0.045},
            {48,0.035,0.025,0.015},
        }) do
            local ring=book.portraitFrame:CreateTexture(nil,"BACKGROUND",nil,i-7)
            ring:SetSize(spec[1],spec[1]);ring:SetPoint("CENTER")
            ring:SetColorTexture(spec[2],spec[3],spec[4],1)
            local mask=book.portraitFrame:CreateMaskTexture()
            mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(ring);ring:AddMaskTexture(mask)
            book.portraitRings[i]=ring
        end
        book.portrait=book.portraitFrame:CreateTexture(nil,"ARTWORK")
        book.portrait:SetAllPoints()
        if type(book.portraitFrame.CreateMaskTexture)=="function" and type(book.portrait.AddMaskTexture)=="function" then
            book.portraitMask=book.portraitFrame:CreateMaskTexture()
            book.portraitMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            book.portraitMask:SetAllPoints(book.portrait);book.portrait:AddMaskTexture(book.portraitMask)
        end
        book.portraitUnknown=label(book.portraitFrame,"?",0,-12,48,"GameFontNormalLarge")
        book.portraitUnknown:SetJustifyH("CENTER")
        -- Native target-frame artwork is already separate from the bars and
        -- portrait circle. Mirror it directly; no custom mask is needed.
        book.portraitBorder=book.portraitFrame:CreateTexture(nil,"OVERLAY")
        book.portraitBorder:Hide()
        book.title = label(book, "", 406+1/book:GetEffectiveScale(), -60, 220, "GameFontNormalLarge")
        book.title:SetTextColor(1,0.82,0.14)
        book.title:SetShadowColor(0,0,0,0.85);book.title:SetShadowOffset(1,-1)
        book.title:SetWordWrap(false)
        book.creatureNotesButton=button(book,"Notes",806,-60,58,function()
            if creatureNotes then creatureNotes:Toggle(selected) end
        end)
        book.creatureNotesButton:ClearAllPoints()
        book.creatureLocationsButton=button(book,"Locations",710,-60,82,function()
            if creatureLocations then creatureLocations:Toggle(selected) end
        end)
        book.creatureLocationsButton:ClearAllPoints()
        book.creatureLocationsButton:SetPoint("TOPRIGHT",book,"TOPRIGHT",-24,-60)
        book.rumoursButton=button(book,"Rumours",710,-60,76,function()
            if rumoursWindow then rumoursWindow:Toggle(selected) end
        end)
        book.rumoursButton:SetMotionScriptsWhileDisabled(true)
        book.rumoursButton:SetScript("OnEnter",function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Rumours")
            GameTooltip:AddLine("Review unverified creature information shared by other players, then verify or reject it."..(not self:IsEnabled() and " No rumours are available for this creature." or ""),1,1,1,true)
            GameTooltip:Show()
        end)
        book.rumoursButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        book.rumoursButton:ClearAllPoints()
        book.rumoursButton:SetPoint("RIGHT",book.creatureLocationsButton,"LEFT",-6,0)
        book.creatureNotesButton:SetPoint("RIGHT",book.rumoursButton,"LEFT",-6,0)
        book.killCount=label(book,"",720,-57,78,"GameFontHighlightSmall")
        book.killCount:ClearAllPoints()
        book.killCount:SetPoint("RIGHT",book.creatureNotesButton,"LEFT",-8,0)
        book.killCount:SetJustifyH("RIGHT")
        book.killCount:SetWidth(0) -- Fit the text so the adjacent reward keeps a 3px gap.
        book.killStar=createKillReward(book)
        book.killStar:SetPoint("RIGHT",book.killCount,"LEFT",-3,0)
        book.title:SetPoint("TOPRIGHT",book.killStar,"LEFT",-8,12)
        local titlePath, titleSize, titleFlags = book.title:GetFont()
        if titlePath and titleSize then book.title:SetFont(titlePath, titleSize + 3, titleFlags) end
        book.titleHover=CreateFrame("Frame",nil,book)
        book.titleHover:SetPoint("TOPLEFT",book.title,"TOPLEFT",0,0)
        book.titleHover:SetPoint("TOPRIGHT",book.title,"TOPRIGHT",0,0)
        book.titleHover:SetHeight(24);book.titleHover.text=book.title
        addNameScroller(book.titleHover,true)
        book.titleHover:SetMouseClickEnabled(false)
        book.titleHover:SetMouseMotionEnabled(true)
        book.summaryArea=CreateFrame("Frame",nil,book)
        book.summaryArea:SetPoint("TOPLEFT",406,-92); book.summaryArea:SetSize(530,45)
        book.summaryArea:SetHyperlinksEnabled(true)
        book.summaryArea:SetScript("OnHyperlinkEnter",function(self,link)
            local index=type(link)=="string" and tonumber(link:match("^afbzone:(%d+)$"))
            local zone=index and book.locationNames and book.locationNames[index]
            if not zone or not selected or not GameTooltip then return end
            GameTooltip:SetOwner(self,"ANCHOR_CURSOR")
            GameTooltip:SetText(zone)
            GameTooltip:AddLine("Observed from subzones:",0.6,0.6,0.6)
            local names=journal:GetSubzones(selected,zone)
            if #names==0 then GameTooltip:AddLine("No subzones recorded.",1,1,1,true) end
            for _,name in ipairs(names) do GameTooltip:AddLine(name,1,1,1,true) end
            GameTooltip:Show()
        end)
        book.summaryArea:SetScript("OnHyperlinkLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        book.summaryArea:SetScript("OnHide",function() if GameTooltip then GameTooltip:Hide() end end)
        book.summaryMeasure=book:CreateFontString(nil,"OVERLAY",textFont("GameFontHighlight"))
        book.summaryMeasure:SetWordWrap(false); book.summaryMeasure:Hide()
        book.summaryBasicRows,book.summaryCombatRows={},{}
        book.empty = label(book, "Every page begins with an encounter or an accepted report.\n\nSelect an entry from the index to review your notes.", 342, -210, 518)
        book.detail = CreateFrame("Frame", nil, book)
        book.detail:SetPoint("TOPLEFT",0,0); book.detail:SetSize(960,740)
        local detail = book.detail
        book.modelBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        book.modelBorder:SetPoint("TOPLEFT",344,-133); book.modelBorder:SetSize(227,168)
        book.modelBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        book.modelBorder:SetBackdropColor(0.045,0.032,0.018,0.88)
        book.modelBorder:SetBackdropBorderColor(0.37,0.25,0.11,0.90)
        book.model = CreateFrame("PlayerModel", nil, detail)
        book.model:SetPoint("TOPLEFT", 346, -135); book.model:SetSize(223, 164)
        book.model:SetPortraitZoom(0); book.model:SetCamDistanceScale(1.25)
        book.model:EnableMouse(true)
        book.modelFrames={}
        book.modelUnknown=book.modelBorder:CreateFontString(nil,"OVERLAY",textFont("GameFontNormalLarge"))
        book.modelUnknown:SetPoint("CENTER",book.modelBorder,"CENTER",0,6)
        book.modelUnknown:SetFont(STANDARD_TEXT_FONT,72,"OUTLINE")
        book.modelUnknown:SetText("?")
        book.modelUnknown:SetTextColor(1,0.82,0.14)
        book.modelUnknown:Hide()
        book.sourceTooltip=CreateFrame("Frame",nil,book.modelBorder)
        book.sourceTooltip:SetFrameLevel(book.model:GetFrameLevel()+2)
        book.sourceTooltip:SetPoint("BOTTOMLEFT",book.modelBorder,"BOTTOMLEFT",7,5)
        book.sourceTooltip:SetSize(211,12)
        book.sourceStatus=label(book.sourceTooltip,"",0,0,211,"GameFontHighlightSmall")
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
        book.tameableBadge:SetSize(24,24);book.tameableBadge:SetPoint("TOPRIGHT",-6,-6)
        book.tameableBadge:SetFrameLevel(book.model:GetFrameLevel()+2)
        book.tameableBadge:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
        book.tameableBadge:SetBackdropColor(0.08,0.06,0.02,1)
        local tameIcon=book.tameableBadge:CreateTexture(nil,"ARTWORK")
        tameIcon:SetPoint("TOPLEFT",3,-3);tameIcon:SetPoint("BOTTOMRIGHT",-3,3)
        tameIcon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
        tameIcon:SetTexCoord(0.08,0.92,0.08,0.92)
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
        book.model:SetScript("OnMouseDown", function(self)
            if self~=book.model or book.modelPending then return end
            rotation=self.afbRotation or 0
            rotating=true; lastCursorX=cursorX()
        end)
        book.model:SetScript("OnMouseUp", function() rotating=false; lastCursorX=nil end)
        book.model:SetScript("OnUpdate", function(self,elapsed)
            if self~=book.model then return end
            if book.modelPending then
                book.modelRetryElapsed=book.modelRetryElapsed+(elapsed or 0)
                local interval=book.modelAttempts<4 and 0.5 or 5
                if book.modelRetryElapsed>=interval then requestModel() end
            end
            if rotating then
                local x=cursorX()
                if x and lastCursorX then
                    rotation=rotation+(x-lastCursorX)*0.015
                    self.afbRotation=rotation;self:SetRotation(rotation)
                end
                lastCursorX=x
            end
        end)
        book.model:SetScript("OnHide", function() rotating=false; lastCursorX=nil end)
        book.modelCaption = label(book.modelBorder, "", 8, -76, 211, "GameFontHighlightSmall")
        book.modelCaption:SetJustifyH("CENTER")
        book.model:SetScript("OnModelLoaded", function(self)
            local entry=journal.entries[book.modelEntryID]
            if self~=book.model or self.afbEntryID~=book.modelEntryID
                or not book.modelPersonal or not entry or entry.personalEncountered~=true then
                self:SetAlpha(0);self:ClearModel()
                return
            end
            if not book.modelPending then return end
            local ok,displayID=pcall(self.GetDisplayInfo,self)
            if not ok or (issecretvalue and issecretvalue(displayID))
                or type(displayID)~="number" or displayID<=0 then return end
            if type(SetPortraitTextureFromCreatureDisplayID)=="function" then
                setPortrait(SetPortraitTextureFromCreatureDisplayID,displayID)
            end
            book.modelPending=false
            self:SetAlpha(1)
            book.modelCaption:SetText("")
        end)
        local modelScripts={}
        for _,event in ipairs({"OnMouseDown","OnMouseUp","OnUpdate","OnHide","OnModelLoaded"}) do
            modelScripts[event]=book.model:GetScript(event)
        end
        book.createModel=function()
            local model=CreateFrame("PlayerModel",nil,detail)
            model:SetAlpha(0);model:Hide()
            model:SetPoint("TOPLEFT",346,-135);model:SetSize(223,164)
            model:SetPortraitZoom(0);model:SetCamDistanceScale(1.25)
            model:EnableMouse(true)
            for event,handler in pairs(modelScripts) do model:SetScript(event,handler) end
            return model
        end
        book.confirm = CreateFrame("Button", nil, book)
        book.confirm:SetSize(24, 24)
        book.confirm:SetPoint("TOPLEFT",book.modelBorder,"TOPLEFT",6,-6)
        book.confirm:SetFrameLevel(detail:GetFrameLevel() + 5)
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
        book.damageHeading=damageHeading
        damageHeading:SetWidth(296);damageHeading:SetWordWrap(false)
        book.lootQualityHidden={}
        book.lootFilter=ui.FilterButton(book.damageBorder,0,0,function()
            book.lootFilterMenu:SetShown(not book.lootFilterMenu:IsShown())
        end)
        local filter=book.lootFilter
        filter:ClearAllPoints();filter:SetPoint("TOPRIGHT",-6,-4);filter:SetSize(24,24)
        filter:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Filter loot quality\nRight-click to reset filters.");GameTooltip:Show()
        end)
        filter:SetScript("OnLeave",function() GameTooltip:Hide() end)
        styleSelection(filter,nil,true)
        local qualityMenu=CreateFrame("Frame",nil,filter,"BackdropTemplate");book.lootFilterMenu=qualityMenu
        qualityMenu:SetPoint("TOPRIGHT",filter,"BOTTOMRIGHT",0,-2);qualityMenu:SetSize(190,218)
        qualityMenu:SetFrameLevel(filter:GetFrameLevel()+30);qualityMenu:EnableMouse(true)
        qualityMenu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        qualityMenu:SetBackdropColor(0.055,0.04,0.022,1)
        local checks={}
        local names={"Poor","Common","Uncommon","Rare","Epic","Legendary"}
        local qualityColors={{0.62,0.62,0.62},{1,1,1},{0.12,1,0},{0,0.44,0.87},{0.64,0.21,0.93},{1,0.5,0}}
        local function updateFilter()
            filter:SetSelected(next(book.lootQualityHidden)~=nil or qualityMenu:IsShown())
            book.damageScroll:SetVerticalScroll(0);refresh()
        end
        filter.ResetFilters=function()
            book.lootQualityHidden={};for _,check in ipairs(checks) do check:SetChecked(true) end
            qualityMenu:Hide();updateFilter()
        end
        for quality=-1,5 do
            local value=quality
            local check=CreateFrame("CheckButton",nil,qualityMenu,"UICheckButtonTemplate")
            check:SetPoint("TOPLEFT",8,-8-(quality+1)*24);check:SetSize(24,24);check:SetChecked(true)
            check.label=label(check,quality==-1 and "Unknown" or names[quality+1],26,-5,140,"GameFontHighlightSmall")
            local color=qualityColors[quality+1] or {0.75,0.8,0.8}
            check.label:SetTextColor(unpack(color))
            check:SetScript("OnClick",function(self)
                book.lootQualityHidden[value]=not self:GetChecked() or nil;updateFilter()
            end)
            checks[#checks+1]=check
        end
        button(qualityMenu,"Show all",12,-182,166,function()
            book.lootQualityHidden={};for _,check in ipairs(checks) do check:SetChecked(true) end;updateFilter()
        end)
        ui.DismissOnOutsideClick(qualityMenu,filter)
        qualityMenu:SetScript("OnShow",function() filter:SetSelected(true) end)
        qualityMenu:SetScript("OnHide",function() filter:SetSelected(next(book.lootQualityHidden)~=nil) end)
        qualityMenu:Hide()
        filter:HookScript("OnHide",function() qualityMenu:Hide() end)
        filter:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        filter:SetScript("OnEvent",function() if filter:IsShown() and book.lootMode then refresh() end end)

        damageHeading:SetTextColor(1.00, 0.82, 0.14)
        local damageScroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
        damageScroll:SetPoint("TOPLEFT",592,-163); damageScroll:SetSize(296,75)
        book.damageChild=CreateFrame("Frame",nil,damageScroll)
        book.damageChild:SetSize(296,75); damageScroll:SetScrollChild(book.damageChild)
        ns.AutoHideScrollBar(damageScroll,function() return book.damageChild:GetHeight() end)
        book.damageScroll=damageScroll
        book.damageScrollBar=damageScroll.ScrollBar
        if type(book.damageScrollBar)=="function" then book.damageScrollBar=nil end
        if not book.damageScrollBar and type(damageScroll.GetScrollBar)=="function" then book.damageScrollBar=damageScroll:GetScrollBar() end
        if book.damageScrollBar and type(book.damageScrollBar)~="function" then
            local bar=book.damageScrollBar
            local up,down=bar.ScrollUpButton,bar.ScrollDownButton
            -- Keep all native controls inside the existing panel backdrop.
            -- A separate opaque track creates a seam against its translucent fill.
            local width,inset=16,6
            bar:SetWidth(width)
            for _,arrow in ipairs({up,down}) do
                if arrow and type(arrow)~="function" then
                    arrow:SetSize(width,width)
                    for _,getter in ipairs({"GetNormalTexture","GetPushedTexture","GetDisabledTexture","GetHighlightTexture"}) do
                        local texture=arrow[getter] and arrow[getter](arrow)
                        if texture and type(texture)~="function" then
                            texture:ClearAllPoints();texture:SetAllPoints(arrow)
                        end
                    end
                end
            end
            bar:ClearAllPoints()
            bar:SetPoint("TOPRIGHT",book.damageBorder,"TOPRIGHT",-inset,-inset-width)
            bar:SetPoint("BOTTOMRIGHT",book.damageBorder,"BOTTOMRIGHT",-inset,inset+width)
            if up and type(up)~="function" then
                up:ClearAllPoints();up:SetPoint("BOTTOM",bar,"TOP",0,0)
            end
            if down and type(down)~="function" then
                down:ClearAllPoints();down:SetPoint("TOP",bar,"BOTTOM",0,0)
            end
            local thumb=bar.GetThumbTexture and bar:GetThumbTexture()
            if thumb and type(thumb)~="function" then thumb:SetSize(width,width) end
        end
        local function layoutLootFilter()
            local scrolling=book.damageScrollBar and book.damageScrollBar:IsShown()
            filter:ClearAllPoints()
            filter:SetPoint("TOPRIGHT",book.damageBorder,"TOPRIGHT",scrolling and -26 or -6,-4)
            damageHeading:SetWidth(scrolling and 276 or 296)
        end
        local refreshDamageScrollBar=damageScroll.RefreshScrollBar
        function damageScroll:RefreshScrollBar()
            refreshDamageScrollBar(self)
            layoutLootFilter()
        end
        if book.damageScrollBar then
            book.damageScrollBar:HookScript("OnShow",layoutLootFilter)
            book.damageScrollBar:HookScript("OnHide",layoutLootFilter)
        end
        layoutLootFilter()
        book.damageRows={}
        book.noDamage=label(book.damageChild,"No damage recorded.",3,-3,281,"GameFontHighlightSmall")
        book.noDamage:SetTextColor(0.55,0.58,0.58)
        -- Abilities and observations are alternate native views of this page.
        local abilityPanel=CreateFrame("Frame",nil,detail)
        abilityPanel:SetAllPoints(detail)
        book.abilityPanel=abilityPanel
        local abilityDivider = CreateFrame("Frame",nil,detail)
        abilityDivider:SetPoint("TOPLEFT",330,-315); abilityDivider:SetSize(608,3)
        ns.FieldbookUI.EntryDivider(abilityDivider,0,608,nil,3)
        local abilitiesHeading = label(abilityPanel, "Recorded abilities", 342, -325, 232, "GameFontNormalLarge")
        abilitiesHeading:SetTextColor(1.00, 0.82, 0.14)
        book.abilityCount = label(abilityPanel, "", 580, -331, 346, "GameFontHighlightSmall")
        book.abilityCount:SetJustifyH("RIGHT")
        book.abilityScrollBar=CreateFrame("Slider",nil,abilityPanel,"UIPanelScrollBarTemplate")
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
        for i=1,10 do
            local row = CreateFrame("Frame", nil, abilityPanel)
            row:SetPoint("TOPLEFT", 342, -360-(i-1)*62); row:SetSize(593, 58)
            row.divider=ns.FieldbookUI.EntryDivider(row,6,569)
            row.tooltipCheck=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            row.tooltipCheck:SetPoint("TOPLEFT",-2,5); row.tooltipCheck:SetSize(20,20)
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
            row.icon=row:CreateTexture(nil,"ARTWORK")
            row.icon:SetPoint("TOPLEFT",22,3);row.icon:SetSize(24,24)
            row.icon:Hide()
            row.text = label(row,"",22,0,224)
            row.text:SetWordWrap(true)
            row.text:SetJustifyV("TOP")
            local abilityFont,abilitySize,abilityFlags=row.text:GetFont()
            if abilityFont and abilitySize then row.text:SetFont(abilityFont,abilitySize+3,abilityFlags) end
            row.description=label(row,"",52,-24,510,"GameFontHighlightSmall")
            row.description:SetHeight(24)
            row.description:SetTextColor(1,0.82,0.14)
            row.description:SetWordWrap(true)
            row.description:SetJustifyV("TOP")
            row.note = label(row,"",52,-46,510,"GameFontHighlightSmall")
            row.note:SetHeight(12)
            row.resolve = button(row,"Resolve",254,0,72,function()
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
            row.accept:SetFrameStrata("MEDIUM");row.accept:SetFrameLevel(row:GetFrameLevel()+1)
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
            row.reject:SetFrameStrata("MEDIUM");row.reject:SetFrameLevel(row:GetFrameLevel()+1)
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
                        if ability.playerLossOfControl and type(GameTooltip.AddLine)=="function" then
                            GameTooltip:AddLine("[A] Automatically attributed from a Loss of Control effect observed on the player. The matching player aura identified this creature as its source.",0.5,0.82,1,true)
                        end
                        if ability.origin == "Automatic buff observation" and type(GameTooltip.AddLine)=="function" then
                            GameTooltip:AddLine("[A] Automatically recorded from a readable buff outside combat. Observed on this creature; caster may be unknown.",0.5,0.82,1,true)
                        elseif ability.origin == "Automatic cast observation" and type(GameTooltip.AddLine)=="function" then
                            GameTooltip:AddLine("[A] Automatically recorded from this creature's readable cast spell ID. A cast may be interrupted before completion.",0.5,0.82,1,true)
                        end
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
        local abilityEditor=CreateFrame("Frame",nil,abilityPanel)
        abilityEditor:SetAllPoints(abilityPanel)
        book.abilityEditor=abilityEditor
        label(abilityEditor,"Ability name you experienced",342,-549,251,"GameFontHighlightSmall")
        label(abilityEditor,"Effects |cff999999(optional)|r",608,-549,268,"GameFontHighlightSmall")
        book.manualName=edit(abilityEditor,348,-567,244,100)
        book.manualEffects={}
        book.effectButton=button(abilityEditor,"Choose effects",614,-567,321,function() book.effectPicker:SetShown(not book.effectPicker:IsShown()); book.refreshEffectPicker() end)
        label(abilityEditor,"Field note |cff999999(optional)|r",342,-590,559,"GameFontHighlightSmall")
        book.manualNote=edit(abilityEditor,348,-609,587,300)
        label(abilityEditor,"Optional spell ID, link, or exact name |cff999999(out of combat)|r",342,-637,559,"GameFontHighlightSmall")
        book.spellLink=edit(abilityEditor,348,-656,284,255)
        if ns.CreateDetectedAbilityHint then
            book.detectedAbility=ns.CreateDetectedAbilityHint(abilityEditor,journal)
            book.detectedAbility:SetPoint("TOPLEFT",342,-684)
        end
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
        book.resolveButton=button(abilityEditor,"Resolve",640,-656,92,resolveSpellLink)
        book.confirmAbilityButton=button(abilityEditor,"Confirm this ability",740,-656,195,function()
            local ok,msg=journal:AddManual(selected,book.manualName:GetText(),book.manualNote:GetText(),book.spellLink:GetText(),book.manualEffects)
            message(msg)
            if ok then book.manualName:SetText(""); book.manualNote:SetText(""); book.spellLink:SetText(""); book.manualEffects={}; book.effectButton:SetText("Choose effects"); refresh() end
        end)
        book.damageButton=button(detail,"Record damage taken",579,-248,227,function()
            book.damageForm:SetShown(not book.damageForm:IsShown())
        end)
        book.beastLoreButton=button(detail,"Known Beast Lore",344,-277,227,function()
            book.beastLore:SetShown(not book.beastLore:IsShown())
        end)
        book.beastLoreButton:Hide()
        -- Lore replaces the abilities view inside the page, using the same heading and footer bounds.
        local beastLore=CreateFrame("Frame","AzerothFieldbookKnownBeastLore",detail)
        beastLore:SetSize(593,389); beastLore:SetPoint("TOPLEFT",342,-325)
        beastLore:SetScript("OnHide",function(self) self.recipient:ClearFocus() end)
        label(beastLore,"Known Beast Lore",0,0,300,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
        beastLore.provenance=label(beastLore,"",0,-33,593,"GameFontHighlightSmall")
        local loreBorder=CreateFrame("Frame",nil,beastLore,"BackdropTemplate")
        loreBorder:SetPoint("TOPLEFT",0,-57);loreBorder:SetSize(593,214)
        loreBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        loreBorder:SetBackdropColor(0.045,0.032,0.018,0.88)
        loreBorder:SetBackdropBorderColor(0.36,0.23,0.10,0.48)
        beastLore.area=CreateFrame("ScrollFrame",nil,beastLore,"UIPanelScrollFrameTemplate")
        beastLore.area:SetPoint("TOPLEFT",12,-67);beastLore.area:SetSize(553,194)
        beastLore.body=CreateFrame("Frame",nil,beastLore.area);beastLore.body:SetSize(553,194)
        beastLore.area:SetScrollChild(beastLore.body)
        ns.AutoHideScrollBar(beastLore.area,function() return beastLore.body:GetHeight() end)
        beastLore.content=label(beastLore.body,"",2,-2,543,"GameFontHighlightSmall")
        beastLore.content:SetSpacing(3)
        label(beastLore,"Recipient's full name (including surname)",0,-288,593,"GameFontHighlightSmall")
        beastLore.recipient=edit(beastLore,6,-309,330,100)
        beastLore.status=label(beastLore,"Free to send • 0 Knowledge",0,-345,593,"GameFontHighlightSmall")
        beastLore.send=button(beastLore,"Send Beast Lore",357,-309,190,function()
            local captured,err=ns.SharingReport.CaptureLore(journal,selected)
            local tx
            if captured and journal.sharing then tx,err=journal.sharing:Start(captured,beastLore.recipient:GetText(),{}) end
            beastLore.status:SetText(tx and "Offer sent. Waiting for acceptance • 0 Knowledge" or err or "Sharing is unavailable.")
            beastLore.recipient:ClearFocus()
            if tx and sharingWindow then sharingWindow:Open(selected) end
        end)
        beastLore.recipient:SetScript("OnEnterPressed",function(self) self:ClearFocus();beastLore.send:Click() end)
        beastLore:Hide(); book.beastLore=beastLore
        book.offenseButton=button(detail,"Offenses",579,-277,111,function()
            book.offensePicker:SetShown(not book.offensePicker:IsShown())
        end)
        book.defenseButton=button(detail,"Defenses",695,-277,111,function()
            book.defensePicker:SetShown(not book.defensePicker:IsShown())
        end)
        book.lootButton=button(detail,"Show Damage",811,-248,111,function()
            if rumoursWindow and rumoursWindow:IsShown() then rumoursWindow:Hide();book.lootMode=true end
            book.lootMode=not book.lootMode
            book.lootButton:SetSelected(not book.lootMode)
            book.damageScroll:SetVerticalScroll(0)
            refresh()
        end)
        styleSelection(book.lootButton,nil,true)
        book.behaviourButton=button(detail,"Behaviour",811,-277,111,function()
            book.behaviourPicker:SetShown(not book.behaviourPicker:IsShown())
        end)
        book.message=label(detail,"",342,-716,593,"GameFontHighlightSmall")
        book.message:SetHeight(18); book.message:SetJustifyV("TOP")
        local effectPicker=CreateFrame("Frame",nil,UIParent,"BackdropTemplate")
        effectPicker:SetSize(560,673); effectPicker:SetPoint("CENTER",book,"CENTER"); effectPicker:SetFrameStrata("FULLSCREEN_DIALOG")
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
        effectPaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png")
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
        -- Both right-column subsection headings have 17px above them.
        label(effectPicker,"Dispel type",rightX,-353,220,"GameFontHighlightSmall")
        for i,name in ipairs(effectGroups[3][2]) do addEffect(name,rightX,-375-(i-1)*23) end
        label(effectPicker,"School resistance",leftX,-485,235,"GameFontHighlightSmall")
        label(effectPicker,"School immunity",rightX,-485,235,"GameFontHighlightSmall")
        for i, school in ipairs(magicSchools) do
            addEffect(school.name .. " Resistance",leftX,-507-(i-1)*23)
            addEffect(school.name .. " Immunity",rightX,-507-(i-1)*23)
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

        local observationPickers = {beastLore}
        local function showObservationPicker(self)
            for _,other in ipairs(observationPickers) do
                if other~=self then other:Hide() end
            end
            abilityPanel:Hide()
            book.manualName:ClearFocus(); book.manualNote:ClearFocus(); book.spellLink:ClearFocus()
            effectPicker:Hide()
            if GameTooltip then GameTooltip:Hide() end
        end
        local function hideObservationPicker()
            for _,other in ipairs(observationPickers) do
                if other:IsShown() then return end
            end
            abilityPanel:Show()
        end
        beastLore:SetScript("OnShow",showObservationPicker)
        beastLore:HookScript("OnHide",hideObservationPicker)
        local function createObservationPicker(globalName,title,description)
            local picker=CreateFrame("Frame",globalName,detail)
            picker:SetPoint("TOPLEFT",detail,"TOPLEFT",342,-325)
            picker:SetSize(593,389)
            picker:EnableMouse(true)
            observationPickers[#observationPickers+1]=picker
            picker:SetScript("OnShow",showObservationPicker)
            label(picker,title,0,0,593,"GameFontNormalLarge"):SetTextColor(1,0.82,0.14)
            label(picker,description,0,-33,593,"GameFontHighlightSmall")
            picker:SetScript("OnHide",hideObservationPicker)
            return picker
        end

        local offensePicker=createObservationPicker("AzerothFieldbookBestiaryOffenses","Observed offenses","Select every magic school this creature has been observed casting.")
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

        local defensePicker=createObservationPicker("AzerothFieldbookBestiaryDefenses","Observed defenses","Record observed defenses. [Type] means expected, not verified.\nUncheck expectations to override; unmarked means unknown.")
        for _,spec in ipairs({{"Magic school",35,120,"LEFT"},{"Resistant",170,80,"CENTER"},{"Immune",265,70,"CENTER"}}) do
            local heading=label(defensePicker,spec[1],spec[2],-88,spec[3],"GameFontHighlightSmall")
            heading:SetJustifyH(spec[4]);heading:SetTextColor(1,0.82,0.14)
            local font,size,flags=heading:GetFont()
            if font and size then heading:SetFont(font,size+2,flags) end
        end
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
        local effectMenu=CreateFrame("Frame",nil,defensePicker,"BackdropTemplate")
        effectMenu:SetSize(330,302);effectMenu:SetClampedToScreen(true)
        effectMenu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
        effectMenu:SetBackdropColor(0.08,0.06,0.04,1)
        effectMenu:SetFrameLevel(defensePicker:GetFrameLevel()+10)
        defensePicker.effectMenu=effectMenu
        local effectDropdown=ui.MenuButton(defensePicker,"Effect Immunities",30,-325,330,function()
            effectMenu:SetShown(not effectMenu:IsShown())
        end)
        effectMenu:SetPoint("BOTTOMLEFT",effectDropdown,"TOPLEFT",0,2)
        effectMenu:Hide();defensePicker.effectDropdown=effectDropdown
        defensePicker:HookScript("OnHide",function() effectMenu:Hide() end)
        defensePicker.effectRows={}
        for i,name in ipairs(ns.BestiaryImmunityEffects) do
            local effect=name
            local x=12+((i-1)%2)*158
            local y=-12-math.floor((i-1)/2)*28
            local control=CreateFrame("CheckButton",nil,effectMenu,"UICheckButtonTemplate")
            control:SetPoint("TOPLEFT",x,y);control:SetSize(24,24)
            local text=label(effectMenu,effect,x+28,y-5,126,"GameFontHighlightSmall")
            control:SetScript("OnClick",function(self)
                journal:SetImmunity(selected,effect,self:GetChecked()==true);refresh();refreshDefensePicker()
            end)
            control:SetMotionScriptsWhileDisabled(true)
            control:SetScript("OnEnter",function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(effect.." immunity")
                local expected=journal:GetExpectedImmunities(selected)
                GameTooltip:AddLine(expected[effect] and "Expected from creature type; not verified for this creature in Forever. Uncheck to override."
                    or "Your recorded immunity. Unmarked means unknown, not susceptible.",1,1,1,true)
                GameTooltip:Show()
            end)
            control:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
            defensePicker.effectRows[#defensePicker.effectRows+1]={name=effect,control=control,text=text}
        end
        refreshDefensePicker=function()
            local entry=selected and journal.entries[selected]
            for _,row in ipairs(defensePicker.rows) do
                row.resistant:SetChecked(entry and type(entry.resistances)=="table" and entry.resistances[row.schoolName] == true)
                row.immune:SetChecked(entry and type(entry.immunities)=="table" and entry.immunities[row.schoolName] == true)
                row.resistant:SetEnabled(entry ~= nil and not entry.confirmed); row.immune:SetEnabled(entry ~= nil and not entry.confirmed)
            end
        end
        local refreshSchools=refreshDefensePicker
        refreshDefensePicker=function()
            refreshSchools()
            local entry=selected and journal.entries[selected]
            local expected=journal:GetExpectedImmunities(selected)
            for _,row in ipairs(defensePicker.effectRows) do
                row.text:SetText(row.name..(expected[row.name] and " [Type]" or ""))
                row.control:SetChecked(expected[row.name] or (entry and entry.immunities and entry.immunities[row.name]==true))
                row.control:SetEnabled(entry~=nil and not entry.confirmed)
            end
        end
        defensePicker:HookScript("OnShow",refreshDefensePicker)
        defensePicker:Hide(); book.defensePicker=defensePicker; book.refreshDefensePicker=refreshDefensePicker

        local behaviourPicker=createObservationPicker("AzerothFieldbookBestiaryBehaviour","Observed behaviour","Record behaviour you have seen. Blue [A] entries\ncome from automatic observations.")
        local behaviourGroups={
            { "Combat style", { "Melee", "Ranged", "Caster" } },
            { "Traits", { "Flees at low health", "Calls allies", "Patrols", "Summons", "Heals", "Enrages", "Stealths" } },
        }
        behaviourPicker.controls={}
        local refreshBehaviourPicker
        local groupY={-88,-182}
        for groupIndex,group in ipairs(behaviourGroups) do
            local heading=label(behaviourPicker,group[1],30,groupY[groupIndex],180,"GameFontHighlightSmall")
            local headingFont,headingSize,headingFlags=heading:GetFont()
            if headingFont and headingSize then heading:SetFont(headingFont,headingSize+2,headingFlags) end
            heading:SetTextColor(1,0.82,0.14)
            for i,name in ipairs(group[2]) do
                local column=(i-1)%2
                local row=math.floor((i-1)/2)
                local y=groupY[groupIndex]-25-row*32
                local control=CreateFrame("CheckButton",nil,behaviourPicker,"UICheckButtonTemplate")
                control:SetPoint("TOPLEFT",30+column*180,y); control:SetSize(24,24)
                control.behaviourName=name
                control.text=label(behaviourPicker,name,60+column*180,y-5,column==0 and 135 or 85,"GameFontHighlightSmall")
                local checkboxFont,checkboxSize,checkboxFlags=control.text:GetFont()
                if checkboxFont and checkboxSize then control.text:SetFont(checkboxFont,checkboxSize+1,checkboxFlags) end
                control:SetScript("OnClick",function(self)
                    journal:SetBehaviour(selected,self.behaviourName,self:GetChecked()==true)
                    refresh(); refreshBehaviourPicker()
                end)
                control:SetScript("OnEnter",function(self)
                    if GameTooltip then
                        local entry=selected and journal.entries[selected]
                        local automatic=entry and entry.behaviourSources and entry.behaviourSources[self.behaviourName]
                        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(self.behaviourName)
                        GameTooltip:AddLine(automatic and "[A] Automatically recorded from this creature's flee emote."
                            or "A personal behaviour record.",automatic and 0.5 or 1,automatic and 0.82 or 1,1,true)
                        GameTooltip:AddLine("Uncheck to remove the mark for now. Fresh automatic evidence will restore it. Previously observed behaviours keep their [A] provenance when rechecked.",0.7,0.7,0.7,true)
                        GameTooltip:Show()
                    end
                end)
                control:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
                control:SetScript("OnHide",function() if GameTooltip then GameTooltip:Hide() end end)
                behaviourPicker.controls[#behaviourPicker.controls+1]=control
            end
        end
        refreshBehaviourPicker=function()
            local entry=selected and journal.entries[selected]
            for _,control in ipairs(behaviourPicker.controls) do
                control:SetChecked(entry and type(entry.behaviours)=="table" and entry.behaviours[control.behaviourName] == true)
                control:SetEnabled(entry ~= nil and not entry.confirmed)
                control.text:SetText(entry and behaviourText(entry,control.behaviourName) or control.behaviourName)
            end
        end
        behaviourPicker:HookScript("OnShow",refreshBehaviourPicker)
        behaviourPicker:Hide(); book.behaviourPicker=behaviourPicker; book.refreshBehaviourPicker=refreshBehaviourPicker

        local form=createObservationPicker(nil,"Your damage observations","Same-level observations are recommended; other levels are welcome.\nHits are affected by your armor and buffs. Record your level at the time.")
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
        form:HookScript("OnShow",function()
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
        notesPaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.png")
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

        local rankFrame=book.filterSubmenus.Ranks
        local locationFrame=book.filterSubmenus.Locations
        book.rankFrame,book.locationFrame=rankFrame,locationFrame

        ns.CreateBestiaryPages(journal,shell,book,{
            followNotesTarget=function() if creatureNotes then creatureNotes:FollowTarget() end end,
            onReset=function()
                for location in pairs(locationFilters) do locationFilters[location]=nil end
                refresh()
                message("The Azeroth Fieldbook Bestiary was reset.")
            end,
            onRestored=function()
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
            end,
        })
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
            {book.creatureLocationsButton,creatureLocations},
            {book.shareButton,sharingWindow},
        }) do
            local control,controller=pair[1],pair[2]
            styleSelection(control,nil,true)
            if controller then
                controller:SetVisibilityCallback(function(shown)
                    control:SetSelected(shown)
                    if controller==rumoursWindow then
                        book.damageBorder:SetHeight(shown and book.modelBorder:GetHeight() or 115)
                        if shown then rumoursWindow:Refresh() end
                        book.damageHeading:SetShown(not shown);book.damageScroll:SetShown(not shown)
                        local entry=selected and journal.entries[selected]
                        book.lootFilter:SetShown(not shown and book.lootMode and entry~=nil and entry.loot~=nil and next(entry.loot.items or {})~=nil)
                        if shown then book.lootFilterMenu:Hide() end
                    end
                end)
            end
        end
        book:SetScript("OnHide",function() filterMenu:Hide();rankFrame:Hide(); deleteForm:Hide(); book.search:ClearFocus(); book.manualName:ClearFocus(); book.manualNote:ClearFocus(); book.spellLink:ClearFocus(); form:Hide(); notesForm:Hide(); effectPicker:Hide(); locationFrame:Hide(); offensePicker:Hide(); defensePicker:Hide(); behaviourPicker:Hide() end)
        book:HookScript("OnHide",function() beastLore:Hide();if rumoursWindow then rumoursWindow:Hide() end end)
        book:HookScript("OnHide",function() sortDismiss:Hide() end)
        book:HookScript("OnHide",function() if creatureLocations then creatureLocations:Hide() end end)
        local function resetOverlayState()
            -- Hiding an ancestor fires OnHide while children can still be
            -- IsShown(). Hiding those children afterwards need not fire it
            -- again, so restore the base panel and borders explicitly.
            for _,picker in ipairs(observationPickers) do picker:Hide() end
            abilityPanel:Show()
            for _,control in ipairs({book.damageButton,book.beastLoreButton,
                book.offenseButton,book.defenseButton,book.behaviourButton,
                book.effectButton,book.locationsButton,book.ranksButton}) do
                control.UpdateWindowBorder()
            end
            if creatureLocations then creatureLocations:Hide() end
            book.creatureLocationsButton:SetSelected(false)
        end
        book:HookScript("OnHide",resetOverlayState)
        book:HookScript("OnShow",resetOverlayState)
        local elapsed, revision, nameRevision = 0, -1, -1
        local difficultyPlayerLevel=playerDifficultyLevel()
        book:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt
            if elapsed>=0.5 then
                elapsed=0
                local currentNames=ns.PlayerNames and ns.PlayerNames.revision or 0
                local currentLevel=playerDifficultyLevel()
                if revision~=journal.revision or nameRevision~=currentNames or difficultyPlayerLevel~=currentLevel then
                    difficultyPlayerLevel=currentLevel
                    revision,nameRevision=journal.revision,currentNames
                    refresh()
                end
            end
        end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryDamageNotes"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryOffenses"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryDefenses"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryBehaviour" end
        local bookScale=shell:GetBaseScale()
        -- Independent roots can move in front of or behind the book. Preserve
        -- the scale formerly inherited by its child dialogs and their anchors.
        for _, window in ipairs({effectPicker,notesForm}) do window:SetScale(bookScale) end
        if ns.UIScale then
            for _, window in ipairs({effectPicker,notesForm}) do
                window.afbPreferBookEdge=true
                ns.UIScale:Register(window)
            end
        end
        for _, window in ipairs({effectPicker}) do
            window.afbAnchorRule="right"
        end
        if ns.WindowPositions then
            for _, window in ipairs({notesForm}) do
                ns.WindowPositions:Register(window,window:GetName())
            end
            ns.WindowPositions:Register(effectPicker,"AbilityEffects")
        end
        if ns.SpellIDWindow and ns.SpellIDWindow.AnchorToBook then ns.SpellIDWindow:AnchorToBook(shell:GetFrame()) end
        book:Hide()
    end
    shell:RegisterSection("bestiary",{
        title="Bestiary",icon="Interface\\Icons\\Ability_Tracking",frameName="AzerothFieldbookBestiarySection",build=build,
        onOpen=function(context)
            if context and context.creatureID then choose(context.creatureID);return end
            -- Previous browsing selection wins; only fall back to a known target.
            if selected and journal.entries[selected] then
                safeModel(selected)
            else
                local target=journal:ExistingUnitEntry("target")
                if target then choose(target);return end
            end
            refresh()
        end,
        onLeave=function()
            if creatureNotes then creatureNotes:Hide() end
            if rumoursWindow then rumoursWindow:Hide() end
            if sharingWindow then sharingWindow:Hide() end
            if book and book.backupWindow then book.backupWindow:Hide() end
            if StaticPopup_Hide then StaticPopup_Hide("AZEROTHFIELDBOOK_BESTIARY_RESET_CONFIRM") end
        end,
    })
    local controller = {}
    function controller:GetShell() return shell end
    function controller:CycleEntry(direction)
        local root=shell:GetFrame()
        if not book or not root or not root:IsShown() or not book:IsShown() or shell.active~="bestiary" then return false end
        if direction~=1 and direction~=-1 then return false end
        if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return false end
        return cycleEntry(direction)
    end
    function controller:Toggle() return shell:ToggleSection("bestiary") end
    function controller:OpenAtUnit(unit)
        shell:EnsureSection("bestiary")
        local id=journal:Observe(unit,true)
        if not id then return false end
        book.modelPreferredUnit=unit=="mouseover" and "mouseover" or "target"
        return shell:ShowSection("bestiary",{creatureID=id})
    end
    function controller:Refresh()
        if book then refresh() elseif creatureNotes then creatureNotes:Refresh() end
        if sharingWindow then sharingWindow:Refresh() end
    end
    function controller:FollowNotesTarget()
        if creatureNotes then creatureNotes:FollowTarget() end
    end
    function controller:OpenNotes()
        shell:EnsureSection("bestiary")
        if not selected or not journal.entries[selected] then
            local target=journal:Observe("target")
            if target then choose(target) else shell:ShowSection("bestiary"); refresh() end
        end
        if creatureNotes then creatureNotes:Open(journal:GetNotesTarget() or selected) end
    end
    return controller
end
