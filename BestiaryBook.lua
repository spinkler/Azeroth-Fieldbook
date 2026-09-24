local addonName, ns = ...
BINDING_NAME_CLASSICBESTIARY_BOOK = "Open / close Azeroth Fieldbook Bestiary"
BINDING_NAME_CLASSICBESTIARY_MOUSEOVER_BOOK = "Open Azeroth Fieldbook Bestiary at mouseover"
local effectGroups = {
    { "Control", { "Stun", "Root/Immobilize", "Slow/Snare", "Daze", "Fear", "Horror", "Disorient", "Sleep/Incapacitate", "Polymorph/Transform", "Charm/Possession", "Banish", "Knockback/Pull", "Disarm", "Silence" } },
    { "Combat", { "Interrupt", "School Lockout", "Damage over Time", "Heal over Time", "Shield/Absorb", "Damage Reduction", "Damage Vulnerability", "Enrage", "Immunity/Invulnerability" } },
    { "Dispel type", { "Magic", "Curse", "Disease", "Poison" } },
}

local function addonVersion()
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        local ok, version = pcall(C_AddOns.GetAddOnMetadata, addonName, "Version")
        if ok and type(version) == "string" and version ~= "" then return version end
    end
    return "0.8.3"
end

function ns.CreateBestiaryBook(journal)
    local creatureNotes = ns.CreateCreatureNotesWindow and ns.CreateCreatureNotesWindow(journal)
    local book, selected, offset, abilityOffset = nil, nil, 0, 0
    local noteOffset, refreshDamageNotes = 0, nil
    local category, initial, reviewOnly = nil, nil, false
    local locationFilters, rankFilters = {}, {}
    local typeOrder = { "Beast", "Humanoid", "Dragonkin", "Demon", "Elemental", "Giant", "Undead", "Mechanical", "Critter", "Totem", "Aberration", "Gas Cloud", "Unclassified" }
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
    local function addSelectionOutline(control)
        local lines={}
        local function addEdge(inset, alpha)
            local edge={}
            for i=1,4 do
                edge[i]=control:CreateTexture(nil,"OVERLAY")
                edge[i]:SetColorTexture(1.00,0.70,0.10,alpha)
                edge[i]:SetBlendMode("ADD")
                lines[#lines+1]=edge[i]
            end
            edge[1]:SetPoint("TOPLEFT",inset,-inset); edge[1]:SetPoint("TOPRIGHT",-inset,-inset); edge[1]:SetHeight(1)
            edge[2]:SetPoint("BOTTOMLEFT",inset,inset); edge[2]:SetPoint("BOTTOMRIGHT",-inset,inset); edge[2]:SetHeight(1)
            edge[3]:SetPoint("TOPLEFT",inset,-inset); edge[3]:SetPoint("BOTTOMLEFT",inset,inset); edge[3]:SetWidth(1)
            edge[4]:SetPoint("TOPRIGHT",-inset,-inset); edge[4]:SetPoint("BOTTOMRIGHT",-inset,inset); edge[4]:SetWidth(1)
        end
        -- A faint halo and a restrained additive core keep the selection
        -- visible without painting a thick, opaque rectangle over the button.
        addEdge(4,0.12); addEdge(5,0.52)
        control.selectionOutline=lines
        control.SetSelected=function(self,selected)
            for _,line in ipairs(self.selectionOutline) do line:SetShown(selected) end
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
        selected, abilityOffset = id, 0
        if creatureNotes then creatureNotes:SetCreature(id) end
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
        offset=math.floor((nextIndex-1)/13)*13
        choose(rows[nextIndex].id)
    end
    refresh = function()
        if not book then return end
        local available = {}
        for _, e in pairs(journal.entries) do
            local displayCategory = e.category == "Not specified" and "Unclassified" or e.category
            available[displayCategory] = true
        end
        if category and not available[category] then category = nil end
        for name, typeButton in pairs(book.typeButtons) do
            local selectedType=(name == "All creatures" and category == nil) or category == name
            typeButton:Show()
            typeButton:SetEnabled(name == "All creatures" or available[name] == true)
            typeButton:SetSelected(selectedType)
        end
        book.indexReset:SetEnabled(initial ~= nil)
        local observedLocations = {}
        for _, entry in pairs(journal.entries) do
            for location in pairs(entry.locations or {}) do observedLocations[location] = true end
        end
        for location in pairs(locationFilters) do
            if not observedLocations[location] then locationFilters[location] = nil end
        end
        local locationCount = 0
        for _ in pairs(locationFilters) do locationCount = locationCount + 1 end
        book.locationsButton:SetText(locationCount > 0 and ("Locations (" .. locationCount .. ")") or "Locations")
        book.locationsButton:SetSelected(locationCount > 0)
        local rankCount = 0
        for _ in pairs(rankFilters) do rankCount = rankCount + 1 end
        book.ranksButton:SetText(rankCount > 0 and ("Ranks (" .. rankCount .. ")") or "Ranks")
        book.ranksButton:SetSelected(rankCount > 0)
        local unletteredRows=journal:List(category,book.search:GetText(),reviewOnly,nil,locationFilters,rankFilters)
        local availableLetters={}
        for _,row in ipairs(unletteredRows) do availableLetters[row.name:sub(1,1):upper()]=true end
        for _,letterButton in ipairs(book.letterButtons) do
            letterButton:SetEnabled(availableLetters[letterButton.letter] == true)
            letterButton:SetSelected(initial == letterButton.letter)
        end
        local rows = initial and journal:List(category, book.search:GetText(), reviewOnly, initial, locationFilters, rankFilters) or unletteredRows
        offset = math.max(0, math.min(offset, math.max(0, #rows - 13)))
        for i, row in ipairs(book.rows) do
            local data = rows[offset + i]
            row.id = data and data.id
            if data then
                row.reviewMark:SetText(data.review and "*" or "")
                row.text:SetText(data.name)
                local rowSelected = data.id == selected
                row.text:SetTextColor(rowSelected and 1.00 or ink[1], rowSelected and 0.82 or ink[2], rowSelected and 0.14 or ink[3])
                row.highlight:SetShown(rowSelected)
                row:SetBackdropBorderColor(0.95, 0.70, 0.15, rowSelected and 1 or 0)
                row:Show()
            else row:Hide() end
        end
        local entryCount, points = journal:GetTotals()
        book.entryCount:SetText(entryCount .. " entries")
        book.pointsCount:SetText(points .. " points")
        local e = selected and journal.entries[selected]
        if creatureNotes then creatureNotes:Refresh() end
        book.creatureNotesButton:SetEnabled(e ~= nil)
        book.killCount:SetShown(e ~= nil)
        local _, star, kills = journal:GetKillReward(selected)
        book.killCount:SetText("Kills: " .. kills)
        book.killStar:SetShown(e ~= nil and star ~= nil)
        for _, part in ipairs(book.killStar.parts) do
            if star == "gold" then part:SetColorTexture(1,0.82,0.14,1)
            else part:SetColorTexture(0.78,0.82,0.88,1) end
        end
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
            book.confirm:Hide()
            book.modelCaption:SetText("")
            book.title:SetText("A field guide of your own")
            book.subTitle:SetText("Target or mouse over an enemy to begin a new entry.")
            book.combatStatus:SetText("")
            return
        end
        book.title:SetText(e.name or ("Encountered creature #" .. selected))
        local levels = "Level Range: not yet observed"
        if e.levelMin then levels = "Level Range: " .. e.levelMin
            if e.levelMax ~= e.levelMin then levels = levels .. "-" .. e.levelMax end
        end
        local status = { e.category }
        if e.rank then status[#status + 1] = e.rank end
        status[#status + 1] = levels
        local locations = {}
        for location in pairs(e.locations or {}) do locations[#locations + 1] = location end
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
        book.subTitle:SetText(table.concat(status, "  |  "))
        local combat = {}
        local offenses = schoolSummary("offenses")
        local resistances = schoolSummary("resistances")
        local immunities = schoolSummary("immunities")
        if #offenses > 0 then combat[#combat + 1] = "Casts: " .. table.concat(offenses, ", ") end
        if #resistances > 0 then combat[#combat + 1] = "Resists: " .. table.concat(resistances, ", ") end
        if #immunities > 0 then combat[#combat + 1] = "Immune: " .. table.concat(immunities, ", ") end
        local behaviours = {}
        for _,name in ipairs(behaviourOrder) do
            if type(e.behaviours)=="table" and e.behaviours[name] then behaviours[#behaviours+1]=name end
        end
        if #behaviours > 0 then combat[#combat + 1] = "Behaviour: " .. table.concat(behaviours, ", ") end
        book.combatStatus:SetText(table.concat(combat, "  |  "))
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
                row.link:SetEnabled(editable)
                row.reject:SetEnabled(editable)
                row.tooltipCheck:SetEnabled(editable)
                for _, control in ipairs({row.accept,row.link,row.reject,row.tooltipCheck}) do control:SetAlpha(editable and 1 or 0.45) end
                row.reject:SetText(ability.state == "rejected" and "Remove" or "Reject")
            else row:Hide() end
        end
        book.abilityCount:SetText(#names == 0 and "No abilities recorded. Add what you experienced below." or (#names .. " recorded abilities" .. (#names > 4 and " - scroll to review" or "")))
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
            row.level=level; row.text:SetText("Lv "..level..": "..table.concat(parts,"; ").."  >")
            local textHeight = row.text:GetStringHeight()
            local rowHeight = math.max(14, type(textHeight) == "number" and textHeight or 14)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-contentHeight)
            row:SetHeight(rowHeight); row:Show()
            contentHeight = contentHeight + rowHeight + 1
        end
        for i=#levels+1,#book.damageRows do book.damageRows[i]:Hide() end
        book.noDamage:SetShown(#levels==0)
        local viewportHeight = 75
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
        book:SetClampedToScreen(true)
        book:SetMovable(true)
        book:EnableMouse(true)
        book:RegisterForDrag("LeftButton")
        -- Keep one anchor and one cursor coordinate space throughout a drag.
        -- Native StartMoving reanchors scaled frames to screen space.
        local drag
        local function stopBookDrag() drag = nil end
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
        book.helpButton=CreateFrame("Button",nil,book.titleBar,"UIPanelCloseButton")
        book.helpButton:SetSize(24,24); book.helpButton:SetPoint("RIGHT",book.closeButton,"LEFT",-2,0)
        local helpCover=book.helpButton:CreateTexture(nil,"OVERLAY")
        helpCover:SetPoint("TOPLEFT",6,-6); helpCover:SetPoint("BOTTOMRIGHT",-6,6)
        helpCover:SetColorTexture(0.13,0.025,0.015,0.96)
        local helpGlyph=book.helpButton:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        helpGlyph:SetAllPoints(); helpGlyph:SetJustifyH("CENTER"); helpGlyph:SetJustifyV("MIDDLE")
        helpGlyph:SetTextColor(1.00,0.82,0.14); helpGlyph:SetText("?")
        book.helpButton:SetScript("OnClick",function() book.help:SetShown(not book.help:IsShown()) end)
        book.typeButtons = {}
        local function addTypeButton(name, y)
            local typeButton = button(book, name == "All creatures" and "All" or name, 42, y, 88, function()
                category = name == "All creatures" and nil or name
                offset = 0; refresh()
            end)
            addSelectionOutline(typeButton)
            book.typeButtons[name] = typeButton
        end
        addTypeButton("All creatures", -110)
        for i, name in ipairs(typeOrder) do addTypeButton(name, -110-i*28) end
        book.locationsButton = button(book, "Locations", 42, -516, 88, function()
            book.locationFrame:SetShown(not book.locationFrame:IsShown())
        end)
        addSelectionOutline(book.locationsButton)
        book.ranksButton = button(book, "Ranks", 42, -548, 88, function() book.rankFrame:SetShown(not book.rankFrame:IsShown()) end)
        addSelectionOutline(book.ranksButton)
        book.entryCount=label(book,"",135,-55,90,"GameFontHighlightSmall")
        book.pointsCount=label(book,"",225,-55,90,"GameFontHighlightSmall")
        book.pointsCount:SetJustifyH("RIGHT")
        book.search = edit(book, 139, -78, 176, 100)
        local searchPlaceholder=label(book.search,"Search",0,-4,170,"GameFontHighlightSmall")
        searchPlaceholder:SetTextColor(0.55,0.55,0.55)
        book.search:SetScript("OnTextChanged", function(self)
            searchPlaceholder:SetShown(self:GetText() == "")
            offset = 0; refresh()
        end)
        book.review = button(book, "Pending", 42, -580, 88, function()
            reviewOnly = not reviewOnly
            book.review:SetText(reviewOnly and "All entries" or "Pending")
            offset = 0; refresh()
        end)
        book.rows = {}
        for i = 1, 13 do
            local row = CreateFrame("Button", nil, book, "BackdropTemplate")
            row:SetPoint("TOPLEFT", 135, -110 - (i-1)*29); row:SetSize(180, 27)
            row:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8, insets={left=1,right=1,top=-3,bottom=1}})
            row:SetBackdropBorderColor(0.95, 0.70, 0.15, 0)
            row.highlight = row:CreateTexture(nil, "BACKGROUND")
            row.highlight:SetPoint("TOPLEFT", 1, -1)
            row.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
            row.highlight:SetColorTexture(0.18,0.10,0.02,0.50)
            row.reviewMark = label(row, "", 5, -6, 10)
            row.reviewMark:SetTextColor(1, 1, 1)
            row.reviewMark:SetWordWrap(false)
            row.text = label(row, "", 17, -6, 158)
            row.text:SetWordWrap(false)
            row:SetScript("OnClick", function(self) if self.id then choose(self.id) end end)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta) offset=offset-delta*3; refresh() end)
            book.rows[i] = row
        end
        button(book, "Previous", 135, -596, 84, function() cycleEntry(-1) end)
        button(book, "Next", 229, -596, 86, function() cycleEntry(1) end)
        local deleteForm = CreateFrame("Frame", "AzerothFieldbookDeleteCreature", book, "BackdropTemplate")
        book.deleteForm = deleteForm
        deleteForm:SetSize(440,210); deleteForm:SetPoint("CENTER")
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
            deleteForm.description:SetText("Permanently delete " .. (entry.name or ("Encountered creature #" .. selected)) .. "?\nAll its abilities, observations, ID logs and notes will be removed.")
            deleteForm.input:SetText(""); deleteForm:Show(); deleteForm.input:SetFocus()
        end)
        book.shareButton = button(book, "Share", 229, -626, 86, function() end)
        book.shareButton:SetEnabled(false)
        book.indexCount = label(book, "* awaiting review", 135, -660, 180, "GameFontHighlightSmall")
        book.indexCount:SetTextColor(0.55,0.58,0.58)
        label(book, "Use type and A-Z tabs to filter the index.\nBind this book in Options > Keybindings.",38,-704,256,"GameFontHighlightSmall")
        book.indexReset = button(book, "Index", 3, -78, 57, function() initial=nil; offset=0; refresh() end)
        book.letterButtons = {}
        for i=1,26 do
            local letter = string.char(64+i)
            local tab = button(book, letter, 4, -107-(i-1)*23, 28, function()
                initial=letter; offset=0; refresh()
            end)
            tab:SetHeight(21)
            tab.letter=letter; addSelectionOutline(tab)
            book.letterButtons[i]=tab
        end
        book.title = label(book, "", 362, -55, 339, "GameFontNormalLarge")
        book.title:SetTextColor(1,0.82,0.14)
        book.title:SetWordWrap(false)
        book.creatureNotesButton=button(book,"Creature Notes",806,-52,130,function()
            if creatureNotes then creatureNotes:Open(selected) end
        end)
        book.creatureNotesButton:ClearAllPoints()
        book.creatureNotesButton:SetPoint("TOPRIGHT",book,"TOPRIGHT",-24,-52)
        book.killCount=label(book,"",720,-57,78,"GameFontHighlightSmall")
        book.killCount:ClearAllPoints()
        book.killCount:SetPoint("RIGHT",book.creatureNotesButton,"LEFT",-8,0)
        book.killCount:SetJustifyH("RIGHT")
        book.killCount:SetWidth(0) -- Fit the text so the adjacent star keeps a 3px gap.
        book.killStar=CreateFrame("Frame",nil,book)
        book.killStar:SetSize(14,14)
        book.killStar:SetPoint("RIGHT",book.killCount,"LEFT",-3,0)
        book.killStar.parts={}
        -- Draw a five-point star with solid scanlines so silver and gold share one silhouette.
        local vertices={}
        for i=0,9 do
            local angle=-math.pi/2+i*math.pi/5
            local radius=i%2==0 and 7 or 3
            vertices[#vertices+1]={7+math.cos(angle)*radius,7+math.sin(angle)*radius}
        end
        for y=0,13 do
            local intersections={}
            for i,a in ipairs(vertices) do
                local b=vertices[i%10+1]
                local scan=y+0.5
                if (a[2]<=scan and b[2]>scan) or (b[2]<=scan and a[2]>scan) then
                    intersections[#intersections+1]=a[1]+(scan-a[2])*(b[1]-a[1])/(b[2]-a[2])
                end
            end
            table.sort(intersections)
            for i=1,#intersections,2 do
                local part=book.killStar:CreateTexture(nil,"ARTWORK")
                part:SetPoint("TOPLEFT",intersections[i],-y)
                part:SetSize(intersections[i+1]-intersections[i],1)
                book.killStar.parts[#book.killStar.parts+1]=part
            end
        end
        local titlePath, titleSize, titleFlags = book.title:GetFont()
        if titlePath and titleSize then book.title:SetFont(titlePath, titleSize + 2, titleFlags) end
        book.subTitle = label(book, "", 362, -84, 574)
        book.combatStatus = label(book, "", 362, -101, 574, "GameFontHighlightSmall")
        book.combatStatus:SetHeight(28); book.combatStatus:SetJustifyV("TOP")
        book.empty = label(book, "Every page begins with an encounter.\n\nOnly creatures you have met appear here.\nSelect an entry from the index to review your notes.", 366, -210, 494)
        book.detail = CreateFrame("Frame", nil, book)
        book.detail:SetAllPoints()
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
        book.modelCaption = label(detail, "", 364, -302, 229, "GameFontHighlightSmall")
        book.model:SetScript("OnModelLoaded", function()
            book.modelCaption:SetText("")
        end)
        book.confirm = CreateFrame("Button", nil, detail, "BackdropTemplate")
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
        local damageHeading = label(book.damageBorder, "Equal-level damage taken", 13, -9, 311)
        damageHeading:SetTextColor(1.00, 0.82, 0.14)
        local damageScroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
        damageScroll:SetPoint("TOPLEFT",592,-163); damageScroll:SetSize(296,75)
        book.damageChild=CreateFrame("Frame",nil,damageScroll)
        book.damageChild:SetSize(296,75); damageScroll:SetScrollChild(book.damageChild)
        book.damageScroll=damageScroll
        book.damageScrollBar=damageScroll.ScrollBar
        if type(book.damageScrollBar)=="function" then book.damageScrollBar=nil end
        if not book.damageScrollBar and type(damageScroll.GetScrollBar)=="function" then book.damageScrollBar=damageScroll:GetScrollBar() end
        book.damageRows={}
        book.noDamage=label(book.damageChild,"No damage recorded.",3,-3,281,"GameFontHighlightSmall")
        book.noDamage:SetTextColor(0.55,0.58,0.58)
        local abilityDivider = detail:CreateTexture(nil, "ARTWORK")
        abilityDivider:SetColorTexture(0.35,0.20,0.08,0.42)
        abilityDivider:SetPoint("TOPLEFT",352,-315); abilityDivider:SetSize(574,1)
        label(detail, "Recorded abilities", 352, -325, 222, "GameFontNormalLarge")
        book.abilityCount = label(detail, "", 580, -331, 346, "GameFontHighlightSmall")
        book.abilityCount:SetJustifyH("RIGHT")
        book.abilityScrollBar=CreateFrame("Slider",nil,detail,"UIPanelScrollBarTemplate")
        book.abilityScrollBar:SetPoint("TOPLEFT",918,-377)
        book.abilityScrollBar:SetSize(16,138)
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
            row:SetPoint("TOPLEFT", 352, -360-(i-1)*43); row:SetSize(558, 42)
            row.tooltipCheck=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            row.tooltipCheck:SetPoint("TOPLEFT",-2,0); row.tooltipCheck:SetSize(20,20)
            row.tooltipCheck:SetScript("OnClick",function(self)
                if selected and row.name then journal:SetAbilityTooltip(selected,row.name,self:GetChecked() == true); refresh() end
            end)
            row.text = label(row,"",22,0,256)
            row.text:SetWordWrap(false)
            row.note = label(row,"",35,-17,326,"GameFontHighlightSmall")
            row.note:SetHeight(23)
            row.link = button(row,"Edit",287,0,72,function()
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
            row.accept = button(row,"Confirm",368,0,88,function()
                journal:SetAbility(selected,row.name,"confirmed"); refresh()
            end)
            row.reject = button(row,"Reject",462,0,88,function()
                local a=journal.entries[selected].abilities[row.name]
                if a.state=="rejected" then
                    journal:RemoveAbility(selected,row.name)
                    message("Ability removed from this entry.")
                else journal:SetAbility(selected,row.name,"rejected") end
                refresh()
            end)
            row:SetScript("OnEnter",function(self)
                local ability=selected and journal.entries[selected] and journal.entries[selected].abilities[self.name]
                if not ability or ability.state~="confirmed" or type(ability.spellID)~="number" or ability.spellID<=0 then return end
                if GameTooltip and type(GameTooltip.SetOwner)=="function" and type(GameTooltip.SetSpellByID)=="function" then
                    pcall(GameTooltip.SetOwner,GameTooltip,self,"ANCHOR_CURSOR")
                    pcall(GameTooltip.SetSpellByID,GameTooltip,ability.spellID)
                end
            end)
            row:SetScript("OnLeave",function()
                if GameTooltip and type(GameTooltip.Hide)=="function" then GameTooltip:Hide() end
            end)
            row:EnableMouse(true)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel",function(_,delta) abilityOffset=abilityOffset-delta; refresh() end)
            book.abilities[i]=row
        end
        label(detail,"Ability name you experienced",352,-549,241,"GameFontHighlightSmall")
        label(detail,"Effects (optional)",608,-549,268,"GameFontHighlightSmall")
        book.manualName=edit(detail,358,-567,234,100)
        book.manualEffects={}
        book.effectButton=button(detail,"Choose effects",614,-567,321,function() book.effectPicker:SetShown(not book.effectPicker:IsShown()); book.refreshEffectPicker() end)
        label(detail,"Field note (optional)",352,-600,549,"GameFontHighlightSmall")
        book.manualNote=edit(detail,358,-620,577,300)
        label(detail,"Optional spell ID, link, or exact name (out of combat)",352,-652,549,"GameFontHighlightSmall")
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
        book.offenseButton=button(detail,"Offenses",579,-277,111,function()
            book.offensePicker:SetShown(not book.offensePicker:IsShown())
        end)
        book.defenseButton=button(detail,"Defenses",695,-277,111,function()
            book.defensePicker:SetShown(not book.defensePicker:IsShown())
        end)
        book.behaviourButton=button(detail,"Behaviour",811,-277,111,function()
            book.behaviourPicker:SetShown(not book.behaviourPicker:IsShown())
        end)
        book.message=label(book,"",352,-704,552,"GameFontHighlightSmall")
        book.message:SetHeight(25); book.message:SetJustifyV("TOP")
        local effectPicker=CreateFrame("Frame",nil,book,"BackdropTemplate")
        effectPicker:SetSize(560,635); effectPicker:SetPoint("CENTER"); effectPicker:SetFrameStrata("FULLSCREEN_DIALOG"); effectPicker:SetFrameLevel(102)
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
        label(effectPicker,"Effects",25,-25,350,"GameFontNormalLarge")
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
        label(effectPicker,"Dispel type",rightX,-315,220,"GameFontHighlightSmall")
        for i,name in ipairs(effectGroups[3][2]) do addEffect(name,rightX,-337-(i-1)*23) end
        label(effectPicker,"School resistance",leftX,-447,235,"GameFontHighlightSmall")
        label(effectPicker,"School immunity",rightX,-447,235,"GameFontHighlightSmall")
        for i, school in ipairs(magicSchools) do
            addEffect(school.name .. " Resistance",leftX,-469-(i-1)*23)
            addEffect(school.name .. " Immunity",rightX,-469-(i-1)*23)
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

        local observationPickerLevel=200
        local function raiseObservationPicker(picker)
            observationPickerLevel=observationPickerLevel+10
            local function setLevel(frame,level)
                frame:SetFrameLevel(level)
                if type(frame.GetChildren)=="function" then
                    for _,child in ipairs({frame:GetChildren()}) do setLevel(child,level+1) end
                end
            end
            setLevel(picker,observationPickerLevel)
        end
        local observationPickers, lastObservationPicker = {}, nil
        local sharedObservationPosition
        local function rememberObservationPosition(picker)
            if not picker or not journal:GetSingleObservationWindow() then return end
            local left, top = picker:GetLeft(), picker:GetTop()
            local scale, parentScale = picker:GetEffectiveScale(), UIParent:GetEffectiveScale()
            if type(left)=="number" and type(top)=="number" and type(scale)=="number"
                and type(parentScale)=="number" and parentScale>0 then
                sharedObservationPosition={left*scale/parentScale,top*scale/parentScale}
            end
        end
        local function applyObservationPosition(picker)
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
            label(picker,title,25,-25,width-155,"GameFontNormalLarge")
            label(picker,description,25,-54,width-50,"GameFontHighlightSmall")
            cornerClose(picker)
            picker:SetScript("OnHide",function(self)
                self:StopMovingOrSizing()
                if self==lastObservationPicker then rememberObservationPosition(self) end
            end)
            return picker
        end

        local offensePicker=createObservationPicker("AzerothFieldbookBestiaryOffenses","Observed offenses","Select every magic school this creature has been observed casting.",480,250)
        offensePicker.schoolButtons={}
        local refreshOffensePicker
        for i,school in ipairs(magicSchools) do
            local schoolName,schoolColor=school.name,school.color
            local column=(i-1)%2
            local row=math.floor((i-1)/2)
            local control=button(offensePicker,"",25+column*220,-91-row*40,200,function()
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

        local defensePicker=createObservationPicker("AzerothFieldbookBestiaryDefenses","Observed defenses","Mark each magic school as resistant, immune, or both when personally observed.",540,335)
        label(defensePicker,"Magic school",35,-88,180,"GameFontHighlightSmall")
        label(defensePicker,"Resistant",285,-88,90,"GameFontHighlightSmall")
        label(defensePicker,"Immune",415,-88,80,"GameFontHighlightSmall")
        defensePicker.rows={}
        local refreshDefensePicker
        for i,school in ipairs(magicSchools) do
            local schoolName,schoolColor=school.name,school.color
            local y=-112-(i-1)*34
            local schoolLabel=label(defensePicker,"|cff"..schoolColor..schoolName.."|r",40,y-5,190)
            local resistant=CreateFrame("CheckButton",nil,defensePicker,"UICheckButtonTemplate")
            resistant:SetPoint("TOPLEFT",305,y); resistant:SetSize(24,24)
            local immune=CreateFrame("CheckButton",nil,defensePicker,"UICheckButtonTemplate")
            immune:SetPoint("TOPLEFT",430,y); immune:SetSize(24,24)
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

        local behaviourPicker=createObservationPicker("AzerothFieldbookBestiaryBehaviour","Observed behaviour","Record only behaviour you have personally seen from this creature.",540,430)
        local behaviourGroups={
            { "Disposition", { "Hostile", "Neutral" } },
            { "Combat style", { "Melee", "Ranged", "Caster" } },
            { "Traits", { "Flees at low health", "Calls allies", "Patrols", "Summons", "Heals", "Enrages", "Stealths" } },
        }
        behaviourPicker.controls={}
        local refreshBehaviourPicker
        local groupY={-88,-150,-244}
        for groupIndex,group in ipairs(behaviourGroups) do
            label(behaviourPicker,group[1],30,groupY[groupIndex],210,"GameFontHighlightSmall")
            for i,name in ipairs(group[2]) do
                local column=(i-1)%2
                local row=math.floor((i-1)/2)
                local y=groupY[groupIndex]-25-row*32
                local control=CreateFrame("CheckButton",nil,behaviourPicker,"UICheckButtonTemplate")
                control:SetPoint("TOPLEFT",30+column*250,y); control:SetSize(24,24)
                control.behaviourName=name
                control.text=label(behaviourPicker,name,60+column*250,y-5,190,"GameFontHighlightSmall")
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

        local form=CreateFrame("Frame",nil,book,"BackdropTemplate")
        form:SetSize(560,230); form:SetPoint("CENTER"); form:SetFrameStrata("FULLSCREEN_DIALOG"); form:SetFrameLevel(100)
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
        label(form,"Your equal-level damage observation",22,-22,515,"GameFontNormalLarge")
        label(form,"Record hits you took when you and this creature were the SAME level.\nThese are personal observations, affected by your armor and buffs.",22,-55,515)
        label(form,"Both level",28,-103,125); label(form,"Smallest hit",185,-103,140); label(form,"Largest hit",350,-103,140)
        local selectedLevel
        local level=CreateFrame("Frame",nil,form,"UIDropDownMenuTemplate")
        level:SetPoint("TOPLEFT",18,-119)
        if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(level,125) end
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
        local low=edit(form,191,-129,140,9)
        local high=edit(form,356,-129,140,9)
        button(form,"Confirm observation",28,-172,290,function()
            local ok,msg=journal:AddDamage(selected,selectedLevel,low:GetText(),high:GetText())
            if ok then form:Hide(); low:SetText(""); high:SetText("") end
            message(msg); refresh()
        end)
        button(form,"Cancel",350,-172,146,function() form:Hide() end)
        form:Hide(); book.damageForm=form
        form:SetScript("OnShow",function()
            local entry=selected and journal.entries[selected]
            selectedLevel=entry and entry.levelMin or nil
            if UIDropDownMenu_SetText then UIDropDownMenu_SetText(level,selectedLevel and tostring(selectedLevel) or "No observed level") end
        end)
        local notesForm=CreateFrame("Frame","AzerothFieldbookBestiaryDamageNotes",book,"BackdropTemplate")
        notesForm:SetSize(500,330); notesForm:SetPoint("CENTER"); notesForm:SetFrameStrata("FULLSCREEN_DIALOG"); notesForm:SetFrameLevel(101)
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
            notesForm.title:SetText("Level "..tostring(book.notesLevel or "?").." damage observations")
            for i,row in ipairs(notesForm.rows) do
                local index=noteOffset+i; local note=notes[index]
                row.noteIndex=note and index or nil
                if note then
                    local entry=selected and journal.entries[selected]
                    row.remove:SetEnabled(entry ~= nil and not entry.confirmed)
                    row.remove:SetAlpha(entry and not entry.confirmed and 1 or 0.45)
                    row.text:SetText((note.legacy and "Older combined note: " or "Observed range: ")..note.low.."-"..note.high)
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
        rankFrame:SetSize(350,270); rankFrame:SetPoint("CENTER")
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
        label(rankFrame,"FILTER BY RANK",28,-28,290,"GameFontNormalLarge")
        label(rankFrame,"Show any checked rank. None checked shows all.",28,-58,290,"GameFontHighlightSmall")
        local rankChecks={}
        for i, rank in ipairs({"Elite", "Rare", "Rare Elite", "World Boss"}) do
            local check=CreateFrame("CheckButton",nil,rankFrame,"UICheckButtonTemplate")
            check:SetSize(24,24); check:SetPoint("TOPLEFT",28,-88-(i-1)*28)
            label(rankFrame,rank,58,-93-(i-1)*28,250)
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
        locationFrame:SetSize(440,460); locationFrame:SetPoint("CENTER"); locationFrame:SetFrameStrata("FULLSCREEN_DIALOG"); locationFrame:SetClampedToScreen(true)
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
        label(locationFrame,"FILTER BY LOCATIONS",28,-28,360,"GameFontNormalLarge")
        label(locationFrame,"Show creatures observed in any checked location.",28,-58,370,"GameFontHighlightSmall")
        local locationScroll=CreateFrame("ScrollFrame",nil,locationFrame,"UIPanelScrollFrameTemplate")
        locationScroll:SetPoint("TOPLEFT",28,-88); locationScroll:SetSize(370,280)
        local locationChild=CreateFrame("Frame",nil,locationScroll)
        locationChild:SetSize(350,280); locationScroll:SetScrollChild(locationChild)
        local locationRows={}
        local noLocations=label(locationChild,"No locations have been observed yet.",4,-6,330,"GameFontHighlightSmall")
        local refreshLocationPicker
        refreshLocationPicker=function()
            local names={}
            local seen={}
            for _,entry in pairs(journal.entries) do
                for location in pairs(entry.locations or {}) do
                    if not seen[location] then seen[location]=true; names[#names+1]=location end
                end
            end
            table.sort(names)
            for i,location in ipairs(names) do
                local row=locationRows[i]
                if not row then
                    row=CreateFrame("CheckButton",nil,locationChild,"UICheckButtonTemplate")
                    row:SetSize(24,24); row:SetPoint("TOPLEFT",0,-(i-1)*28)
                    row.text=label(locationChild,"",30,-5-(i-1)*28,300,"GameFontHighlightSmall")
                    row:SetScript("OnClick",function(self)
                        locationFilters[self.location]=self:GetChecked() == true and true or nil
                        offset=0; refresh(); refreshLocationPicker()
                    end)
                    locationRows[i]=row
                end
                row.location=location
                row:SetChecked(locationFilters[location] == true)
                row.text:SetText(location)
                row:Show(); row.text:Show()
            end
            for i=#names+1,#locationRows do locationRows[i]:Hide(); locationRows[i].text:Hide() end
            noLocations:SetShown(#names==0)
            local contentHeight = math.max(280,#names*28)
            local scrollable = contentHeight > 280
            locationChild:SetHeight(contentHeight)
            local scrollBar = locationScroll.ScrollBar
            if type(scrollBar) == "function" then scrollBar = nil end
            if not scrollBar and type(locationScroll.GetScrollBar) == "function" then
                scrollBar = locationScroll:GetScrollBar()
            end
            if scrollBar then scrollBar:SetShown(scrollable) end
            locationScroll:EnableMouseWheel(scrollable)
            local currentScroll = locationScroll:GetVerticalScroll()
            locationScroll:SetVerticalScroll(math.min(type(currentScroll) == "number" and currentScroll or 0, contentHeight-280))
        end
        button(locationFrame,"Clear all",28,-405,170,function()
            for location in pairs(locationFilters) do locationFilters[location]=nil end
            offset=0; refresh(); refreshLocationPicker()
        end)
        cornerClose(locationFrame)
        locationFrame:SetScript("OnShow",refreshLocationPicker)
        locationFrame:SetScript("OnHide",function(self) self:StopMovingOrSizing() end)
        locationFrame:Hide(); book.locationFrame=locationFrame

        local help=CreateFrame("Frame","AzerothFieldbookHelp",UIParent,"BackdropTemplate")
        help:SetSize(610,767); help:SetPoint("CENTER"); help:SetFrameStrata("FULLSCREEN_DIALOG"); help:SetClampedToScreen(true)
        help:SetMovable(true); help:EnableMouse(true); help:RegisterForDrag("LeftButton")
        help:SetScript("OnDragStart",function(self) self:StartMoving() end)
        help:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        help:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local helpPaper=help:CreateTexture(nil,"BACKGROUND",nil,1)
        helpPaper:SetPoint("TOPLEFT",help,"TOPLEFT",6,-6)
        helpPaper:SetPoint("BOTTOMRIGHT",help,"BOTTOMRIGHT",-6,6)
        helpPaper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        helpPaper:SetTexCoord(0,1,0,1); addBackgroundLayer(helpPaper, 0.504,0.504,0.48888)
        label(help,"AZEROTH FIELDBOOK - BESTIARY",30,-30,500,"GameFontNormalLarge")
        local helpScroll=CreateFrame("ScrollFrame",nil,help,"UIPanelScrollFrameTemplate")
        helpScroll:SetPoint("TOPLEFT",help,"TOPLEFT",0,-75)
        helpScroll:SetPoint("BOTTOMRIGHT",help,"BOTTOMRIGHT",-32,65)
        local helpBody=CreateFrame("Frame",nil,helpScroll)
        helpBody:SetSize(570,855)
        helpScroll:SetScrollChild(helpBody)
        local helpInstructions=label(helpBody,"|cffffd1001. Encounter|r\nTarget or mouse over an attackable NPC to add it to your Bestiary. Its name, creature type, location and observed level range are recorded automatically.\n\n|cffffd1002. Record|r\nReadable casts and safe post-combat observations are added as pending notes. Abilities the addon cannot observe directly can also be added manually. Damage ranges must be recorded manually from your own data. Equal-level observations are recommended so level scaling does not distort the results.\n\n|cffffd1003. Review|r\nOpen the Bestiary and select a creature to review its observations. Confirm accurate abilities, reject doubtful ones, or remove notes you no longer want.\n\n|cffffd1004. Lock Entry|r\nWhen you are satisfied with an entry, lock it to stop further changes. Confirmed abilities appear in NPC tooltips. Kill and discovery points continue, and ID Logs and Notes remain editable. Unlock to resume recording and hide its abilities from tooltips.\n\n|cffffd1005. Browse|r\nUse creature-type filters, search, A-Z tabs and Index reset to navigate the Bestiary. All knowledge is stored per character and comes from your own encounters.",35,0,535)
        local helpDetails=CreateFrame("Frame",nil,helpBody)
        helpDetails:SetPoint("TOPLEFT",helpInstructions,"BOTTOMLEFT",-35,-14)
        helpDetails:SetSize(570,771)
        helpBody:SetHeight(helpInstructions:GetStringHeight()+14+771)
        label(helpDetails,"|cffffd100ABOUT|r",35,0,120,"GameFontNormal")
        label(helpDetails,"Created by Spinkler\n\nDeveloped with AI-assisted coding tools.\nDesign, direction, testing and final development decisions by the author.",35,-22,535,"GameFontHighlightSmall")
        label(helpDetails,"|cffffd100OPTIONS|r",35,-93,160,"GameFontNormal")
        local optionsBody=CreateFrame("Frame",nil,helpDetails)
        optionsBody:SetPoint("TOPLEFT",0,-28); optionsBody:SetSize(570,743)
        help.creatureAnnouncement=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        help.creatureAnnouncement:SetPoint("TOPLEFT",30,-93); help.creatureAnnouncement:SetSize(24,24)
        label(optionsBody,"Show a chat message when a new creature entry is added",58,-99,460,"GameFontHighlightSmall")
        help.creatureAnnouncement:SetScript("OnClick",function(self) journal:SetCreatureAnnouncement(self:GetChecked() == true) end)
        help.spellIDTooltips=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        help.spellIDTooltips:SetPoint("TOPLEFT",30,-125); help.spellIDTooltips:SetSize(24,24)
        label(optionsBody,"Show aura spell IDs on tooltips",58,-131,460,"GameFontHighlightSmall")
        help.spellIDTooltips:SetScript("OnClick",function(self) journal:SetSpellIDTooltips(self:GetChecked() == true) end)
        help.displayCastIDs=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        help.displayCastIDs:SetPoint("TOPLEFT",30,-157); help.displayCastIDs:SetSize(24,24)
        label(optionsBody,"Display Cast IDs",58,-163,460,"GameFontHighlightSmall")
        help.displayCastIDs:SetScript("OnClick",function(self) journal:SetDisplayCastIDs(self:GetChecked() == true) end)
        label(optionsBody,"Background brightness",58,-190,170,"GameFontHighlightSmall")
        help.backgroundBrightness=CreateFrame("Slider",nil,optionsBody,"OptionsSliderTemplate")
        help.backgroundBrightness:SetPoint("TOPLEFT",30,-205)
        help.backgroundBrightness:SetSize(180,16)
        local brightnessTrack=help.backgroundBrightness:CreateTexture(nil,"BACKGROUND")
        brightnessTrack:SetPoint("TOPLEFT",2,-4)
        brightnessTrack:SetPoint("BOTTOMRIGHT",-2,4)
        brightnessTrack:SetColorTexture(0.045,0.032,0.018,1)
        help.backgroundBrightness:SetMinMaxValues(0.5,1.5)
        help.backgroundBrightness:SetValueStep(0.05)
        help.backgroundBrightness:SetObeyStepOnDrag(true)
        help.backgroundBrightness:SetScript("OnValueChanged",function(_,value)
            journal:SetBackgroundBrightness(value)
            book:SetBackgroundBrightness(value)
        end)
        label(optionsBody,"SPELL ID WINDOW",35,-243,460,"GameFontNormal")
        local function windowCheck(key, title, y)
            local check=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
            check:SetPoint("TOPLEFT",30,y); check:SetSize(24,24)
            label(optionsBody,title,58,y-6,470,"GameFontHighlightSmall")
            check:SetScript("OnClick",function(self) journal:SetSpellIDWindowOption(key,self:GetChecked() == true) end)
            help[key]=check
        end
        windowCheck("displaySpellIDWindow","Display Spell ID window",-264)
        windowCheck("spellIDWindowLocked","Lock Spell ID window",-292)
        windowCheck("spellIDWindowIndefinite","Display Spell IDs in the ID window indefinitely",-320)
        windowCheck("displayHoveredAuraSnapshots","Retain hovered aura tooltips",-348)
        windowCheck("spellIDWindowAutoFade","Auto-fade when the Spell ID window contains no data",-376)
        local alphaLabel=label(optionsBody,"Window background opacity: 35%",58,-414,460,"GameFontHighlightSmall")
        help.spellIDWindowAlpha=CreateFrame("Slider",nil,optionsBody,"OptionsSliderTemplate")
        help.spellIDWindowAlpha:SetPoint("TOPLEFT",30,-429); help.spellIDWindowAlpha:SetSize(180,16)
        local alphaTrack=help.spellIDWindowAlpha:CreateTexture(nil,"BACKGROUND")
        alphaTrack:SetPoint("TOPLEFT",2,-4)
        alphaTrack:SetPoint("BOTTOMRIGHT",-2,4)
        alphaTrack:SetColorTexture(0.045,0.032,0.018,1)
        help.spellIDWindowAlpha:SetMinMaxValues(0,1); help.spellIDWindowAlpha:SetValueStep(0.05)
        help.spellIDWindowAlpha:SetObeyStepOnDrag(true)
        help.spellIDWindowAlpha:SetScript("OnValueChanged",function(_,value)
            journal:SetSpellIDWindowOption("spellIDWindowAlpha",value)
            alphaLabel:SetText("Window background opacity: " .. math.floor(value*100+0.5) .. "%")
        end)
        label(optionsBody,"Each row expires two minutes after observation unless kept indefinitely. IDs are display-only; record useful findings manually.",35,-476,510,"GameFontHighlightSmall")
        help.singleObservationWindow=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        help.singleObservationWindow:SetPoint("TOPLEFT",30,-703); help.singleObservationWindow:SetSize(24,24)
        label(optionsBody,"Show only one Offenses, Defenses or Behaviour window",58,-709,470,"GameFontHighlightSmall")
        help.singleObservationWindow:SetScript("OnClick",function(self)
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
        local scaleLabel=label(optionsBody,"UI scale: 100%",58,-633,460,"GameFontHighlightSmall")
        help.uiScale=CreateFrame("Slider",nil,optionsBody,"OptionsSliderTemplate")
        help.uiScale:SetPoint("TOPLEFT",30,-653); help.uiScale:SetSize(180,16)
        help.uiScale:SetMinMaxValues(0.5,1.5); help.uiScale:SetValueStep(0.05)
        help.uiScale:SetObeyStepOnDrag(true)
        local scaleTrack=help.uiScale:CreateTexture(nil,"BACKGROUND")
        scaleTrack:SetPoint("TOPLEFT",2,-4); scaleTrack:SetPoint("BOTTOMRIGHT",-2,4)
        scaleTrack:SetColorTexture(0.045,0.032,0.018,1)
        local pendingScale
        help.uiScale:SetScript("OnValueChanged",function(_,value)
            pendingScale=math.max(0.5,math.min(1.5,value))
            scaleLabel:SetText("UI scale: " .. math.floor(pendingScale*100+0.5) .. "%")
        end)
        local function applyPendingScale()
            if pendingScale then
                local value=pendingScale
                pendingScale=nil
                journal:SetUIScale(value)
            end
        end
        help.uiScale:SetScript("OnMouseUp",applyPendingScale)
        help.uiScale:EnableKeyboard(false)
        help.uiScale:SetScript("OnHide",function() pendingScale=nil end)
        button(optionsBody,"100%",230,-648,65,function()
            help.uiScale:SetValue(1)
            pendingScale=nil
            journal:SetUIScale(1)
        end)
        help.showMinimapButton=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        help.showMinimapButton:SetPoint("TOPLEFT",30,-590); help.showMinimapButton:SetSize(24,24)
        label(optionsBody,"Show minimap button",58,-596,470,"GameFontHighlightSmall")
        help.showMinimapButton:SetScript("OnClick",function(self) journal:SetMinimapButton(self:GetChecked() == true) end)
        help.pointAnnouncements=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        help.pointAnnouncements:SetPoint("TOPLEFT",30,-558); help.pointAnnouncements:SetSize(24,24)
        label(optionsBody,"Show a chat message when a point is awarded",58,-564,470,"GameFontHighlightSmall")
        help.pointAnnouncements:SetScript("OnClick",function(self) journal:SetPointAnnouncements(self:GetChecked() == true) end)
        help.creatureNotesFollowTarget=CreateFrame("CheckButton",nil,optionsBody,"UICheckButtonTemplate")
        help.creatureNotesFollowTarget:SetPoint("TOPLEFT",30,-526); help.creatureNotesFollowTarget:SetSize(24,24)
        label(optionsBody,"Creature notes follow target selection",58,-532,470,"GameFontHighlightSmall")
        help.creatureNotesFollowTarget:SetScript("OnClick",function(self)
            journal:SetNotesFollowTarget(self:GetChecked() == true)
            if creatureNotes then creatureNotes:FollowTarget() end
        end)
        if type(StaticPopupDialogs) == "table" then
            StaticPopupDialogs.AZEROTHFIELDBOOK_BESTIARY_RESET_CONFIRM = {
                text = "Reset the Azeroth Fieldbook Bestiary? This permanently deletes all creature entries, notes, abilities, damage records and Bestiary settings.",
                button1 = YES, button2 = NO,
                OnAccept = function()
                    journal:ResetDatabase()
                    for location in pairs(locationFilters) do locationFilters[location] = nil end
                    book:SetBackgroundBrightness(journal:GetBackgroundBrightness())
                    refresh()
                    message("The Azeroth Fieldbook Bestiary was reset.")
                end,
                timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            }
        end
        button(help,"Reset Bestiary",30,-722,160,function()
            if StaticPopup_Show then StaticPopup_Show("AZEROTHFIELDBOOK_BESTIARY_RESET_CONFIRM") end
        end)
        help:SetScript("OnShow",function()
            helpBody:SetHeight(helpInstructions:GetStringHeight()+14+771)
            help.singleObservationWindow:SetChecked(journal:GetSingleObservationWindow())
            help.uiScale:SetValue(journal:GetUIScale())
            help.showMinimapButton:SetChecked(journal:GetMinimapButton())
            help.pointAnnouncements:SetChecked(journal:GetPointAnnouncements())
            help.creatureNotesFollowTarget:SetChecked(journal:GetNotesFollowTarget())
            help.creatureAnnouncement:SetChecked(journal:GetCreatureAnnouncement())
            help.spellIDTooltips:SetChecked(journal:GetSpellIDTooltips())
            help.displayCastIDs:SetChecked(journal:GetDisplayCastIDs())
            for _, key in ipairs({"displaySpellIDWindow","spellIDWindowLocked","spellIDWindowIndefinite","displayHoveredAuraSnapshots","spellIDWindowAutoFade"}) do
                help[key]:SetChecked(journal:GetSpellIDWindowOption(key))
            end
            help.spellIDWindowAlpha:SetValue(journal:GetSpellIDWindowOption("spellIDWindowAlpha"))
            help.backgroundBrightness:SetValue(journal:GetBackgroundBrightness())
        end)
        cornerClose(help)
        help:Hide(); book.help=help
        book:SetScript("OnHide",function() rankFrame:Hide(); deleteForm:Hide(); book.search:ClearFocus(); book.manualName:ClearFocus(); book.manualNote:ClearFocus(); book.spellLink:ClearFocus(); form:Hide(); notesForm:Hide(); effectPicker:Hide(); locationFrame:Hide(); offensePicker:Hide(); defensePicker:Hide(); behaviourPicker:Hide() end)
        local elapsed, revision = 0, -1
        book:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt
            if elapsed>=0.5 then elapsed=0; if revision~=journal.revision then revision=journal.revision; refresh() end end
        end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiary"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookHelp"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryDamageNotes"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryLocations"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryOffenses"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryDefenses"; UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBestiaryBehaviour" end
        if UIParent.GetWidth and UIParent.GetHeight then
            book:SetScale(math.min(1, (UIParent:GetWidth()-30)/960, (UIParent:GetHeight()-30)/740))
        end
        if ns.UIScale then
            for _, window in ipairs({book,help,locationFrame,rankFrame,offensePicker,defensePicker,behaviourPicker}) do
                ns.UIScale:Register(window)
            end
        end
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
    function controller:Refresh() if book then refresh() end end
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
