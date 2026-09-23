local addonName, ns = ...
BINDING_NAME_CLASSICBESTIARY_BOOK = "Open / close bestiary book"
BINDING_NAME_CLASSICBESTIARY_MOUSEOVER_BOOK = "Open bestiary at mouseover"
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
    return "0.7.0"
end

function ns.CreateBook(journal)
    local book, selected, offset, abilityOffset = nil, nil, 0, 0
    local noteOffset, refreshDamageNotes = 0, nil
    local category, initial, reviewOnly = nil, nil, false
    local locationFilters = {}
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
        selected, abilityOffset = id, 0
        book.manualName:SetText(""); book.manualNote:SetText(""); book.spellLink:SetText("")
        book.manualEffects={}; if book.effectButton then book.effectButton:SetText("Choose effects") end
        book.damageForm:Hide()
        message("")
        safeModel(id)
        refresh()
    end
    local function cycleEntry(direction)
        local rows=journal:List(category,book.search:GetText(),reviewOnly,initial,locationFilters)
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
        local unletteredRows=journal:List(category,book.search:GetText(),reviewOnly,nil,locationFilters)
        local availableLetters={}
        for _,row in ipairs(unletteredRows) do availableLetters[row.name:sub(1,1):upper()]=true end
        for _,letterButton in ipairs(book.letterButtons) do
            letterButton:SetEnabled(availableLetters[letterButton.letter] == true)
            letterButton:SetSelected(initial == letterButton.letter)
        end
        local rows = initial and journal:List(category, book.search:GetText(), reviewOnly, initial, locationFilters) or unletteredRows
        offset = math.max(0, math.min(offset, math.max(0, #rows - 13)))
        for i, row in ipairs(book.rows) do
            local data = rows[offset + i]
            row.id = data and data.id
            if data then
                local reviewMark = data.review and "|cffffffff* |r" or ""
                row.text:SetText(reviewMark .. data.name)
                local rowSelected = data.id == selected
                row.text:SetTextColor(rowSelected and 1.00 or ink[1], rowSelected and 0.82 or ink[2], rowSelected and 0.14 or ink[3])
                row.highlight:SetShown(rowSelected)
                row:SetBackdropBorderColor(0.95, 0.70, 0.15, rowSelected and 1 or 0)
                row:Show()
            else row:Hide() end
        end
        book.indexCount:SetText(#rows .. " entries  |  * awaiting review")
        local e = selected and journal.entries[selected]
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
        local combat = { "Kills: " .. math.max(0,math.floor(tonumber(e.kills) or 0)) }
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
        abilityOffset = math.max(0, math.min(abilityOffset, math.max(0, #names - 4)))
        for i, row in ipairs(book.abilities) do
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
                row.accept:SetEnabled(ability.state ~= "confirmed")
                row.link:SetEnabled(true)
                row.reject:SetText(ability.state == "rejected" and "Remove" or "Reject")
            else row:Hide() end
        end
        book.abilityCount:SetText(#names == 0 and "No abilities recorded. Add what you experienced below." or (#names .. " recorded abilities - scroll to review"))
        local levels = {}
        for level in pairs(e.damage) do levels[#levels + 1] = level end
        table.sort(levels)
        for i, level in ipairs(levels) do
            local hit = e.damage[level]
            local parts = {}
            if hit.normalLow then parts[#parts + 1] = "normal " .. hit.normalLow .. "-" .. hit.normalHigh .. " (" .. hit.normalCount .. ")" end
            if hit.critLow then parts[#parts + 1] = "crit " .. hit.critLow .. "-" .. hit.critHigh .. " (" .. hit.critCount .. ")" end
            if #parts == 0 and hit.low then parts[1] = hit.low .. "-" .. hit.high .. " (" .. (hit.reports or 1) .. " notes)" end
            local row=book.damageRows[i]
            if not row then
                row=CreateFrame("Button",nil,book.damageChild)
                row:SetSize(278,22); row:SetPoint("TOPLEFT",0,-(i-1)*23)
                row.text=label(row,"",3,-3,270,"GameFontHighlightSmall")
                row.highlight=row:CreateTexture(nil,"HIGHLIGHT"); row.highlight:SetAllPoints(); row.highlight:SetColorTexture(0.55,0.35,0.12,0.16)
                row:SetScript("OnClick",function(self)
                    book.notesLevel=self.level; noteOffset=0; refreshDamageNotes(); book.notesForm:Show()
                end)
                book.damageRows[i]=row
            end
            row.level=level; row.text:SetText("Lv "..level..": "..table.concat(parts,"; ").."  >"); row:Show()
        end
        for i=#levels+1,#book.damageRows do book.damageRows[i]:Hide() end
        book.noDamage:SetShown(#levels==0)
        local damageHeight=math.max(72,#levels*23)
        book.damageChild:SetHeight(damageHeight)
        local scrollable=damageHeight>72
        if book.damageScrollBar and type(book.damageScrollBar) ~= "function" then book.damageScrollBar:SetShown(scrollable) end
        book.damageScroll:EnableMouseWheel(scrollable)
    end
    local function build()
        book = CreateFrame("Frame", "ClassicBestiaryBook", UIParent, "BackdropTemplate")
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
        page:SetTexture("Interface\\AddOns\\ClassicBestiary\\Artwork\\ParchmentBook.tga")
        page:SetHorizTile(false)
        page:SetVertTile(false)
        page:SetTexCoord(0, 1, 0, 1)
        addBackgroundLayer(page, 0.504, 0.504, 0.48888)
        local spine = book:CreateTexture(nil, "ARTWORK")
        spine:SetColorTexture(0.25, 0.13, 0.055, 0.35)
        spine:SetPoint("TOPLEFT", 300, -53); spine:SetSize(3, 661)
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
        trackingIcon:SetTexture("Interface\\Icons\\Ability_Tracking")
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
        book.windowTitle:SetText("The Bestiary - v" .. addonVersion())
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
        book.locationsButton = button(book, "Locations", 42, -510, 88, function()
            book.locationFrame:Show()
        end)
        addSelectionOutline(book.locationsButton)
        label(book, "Search the index", 127, -55, 172)
        book.search = edit(book, 139, -78, 152, 100)
        book.search:SetScript("OnTextChanged", function() offset = 0; refresh() end)
        book.review = button(book, "Pending", 42, -542, 88, function()
            reviewOnly = not reviewOnly
            book.review:SetText(reviewOnly and "All entries" or "Pending")
            offset = 0; refresh()
        end)
        book.rows = {}
        for i = 1, 13 do
            local row = CreateFrame("Button", nil, book, "BackdropTemplate")
            row:SetPoint("TOPLEFT", 135, -110 - (i-1)*29); row:SetSize(156, 27)
            row:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=8, insets={left=1,right=1,top=-3,bottom=1}})
            row:SetBackdropBorderColor(0.95, 0.70, 0.15, 0)
            row.highlight = row:CreateTexture(nil, "BACKGROUND")
            row.highlight:SetPoint("TOPLEFT", 1, -1)
            row.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
            row.highlight:SetColorTexture(0.18,0.10,0.02,0.50)
            row.text = label(row, "", 5, -6, 146)
            row.text:SetWordWrap(false)
            row:SetScript("OnClick", function(self) if self.id then choose(self.id) end end)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta) offset=offset-delta*3; refresh() end)
            book.rows[i] = row
        end
        button(book, "Previous", 135, -626, 72, function() cycleEntry(-1) end)
        button(book, "Next", 217, -626, 74, function() cycleEntry(1) end)
        book.indexCount = label(book, "", 135, -660, 156, "GameFontHighlightSmall")
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
        book.title = label(book, "", 336, -55, 365, "GameFontNormalLarge")
        local titlePath, titleSize, titleFlags = book.title:GetFont()
        if titlePath and titleSize then book.title:SetFont(titlePath, titleSize + 2, titleFlags) end
        book.subTitle = label(book, "", 336, -84, 600)
        book.combatStatus = label(book, "", 336, -101, 600, "GameFontHighlightSmall")
        book.combatStatus:SetHeight(28); book.combatStatus:SetJustifyV("TOP")
        book.empty = label(book, "Every page begins with an encounter.\n\nOnly creatures you have met appear here.\nSelect an entry from the index to review your notes.", 340, -210, 520)
        book.detail = CreateFrame("Frame", nil, book)
        book.detail:SetAllPoints()
        local detail = book.detail
        book.modelBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        book.modelBorder:SetPoint("TOPLEFT",338,-133); book.modelBorder:SetSize(229,168)
        book.modelBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        book.modelBorder:SetBackdropColor(0.045,0.032,0.018,0.88)
        book.modelBorder:SetBackdropBorderColor(0.37,0.25,0.11,0.90)
        book.model = CreateFrame("PlayerModel", nil, detail)
        book.model:SetPoint("TOPLEFT", 340, -135); book.model:SetSize(225, 164)
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
        book.modelCaption = label(detail, "", 338, -302, 255, "GameFontHighlightSmall")
        book.model:SetScript("OnModelLoaded", function()
            book.modelCaption:SetText("")
        end)
        book.confirm = CreateFrame("Button", nil, detail, "BackdropTemplate")
        book.confirm:SetSize(26, 26)
        book.confirm:SetPoint("TOPLEFT", 306, -52)
        book.confirm:SetFrameLevel(detail:GetFrameLevel() + 5)
        book.confirm:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=5, insets={left=2,right=2,top=2,bottom=2}})
        book.confirm:SetBackdropColor(0.06, 0.04, 0.02, 0.95)
        book.confirm:SetBackdropBorderColor(0.55, 0.40, 0.16, 1)
        local lockBody = book.confirm:CreateTexture(nil, "ARTWORK")
        lockBody:SetColorTexture(0.20, 0.20, 0.20, 1)
        lockBody:SetPoint("BOTTOM", 0, 5)
        lockBody:SetSize(14, 11)
        local lockCorners = {}
        for _, point in ipairs({"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}) do
            local corner = book.confirm:CreateTexture(nil, "OVERLAY")
            corner:SetSize(1, 1)
            corner:SetPoint(point, lockBody, point)
            lockCorners[#lockCorners + 1] = corner
        end
        local lockTop = book.confirm:CreateTexture(nil, "ARTWORK")
        lockTop:SetColorTexture(0.20, 0.20, 0.20, 1)
        lockTop:SetPoint("TOP", 0, -7)
        lockTop:SetSize(10, 2)
        local lockLeft = book.confirm:CreateTexture(nil, "ARTWORK")
        lockLeft:SetColorTexture(0.20, 0.20, 0.20, 1)
        lockLeft:SetPoint("TOP", -4, -7)
        lockLeft:SetSize(2, 8)
        local lockRight = book.confirm:CreateTexture(nil, "ARTWORK")
        lockRight:SetColorTexture(0.20, 0.20, 0.20, 1)
        lockRight:SetPoint("TOP", 4, -7)
        lockRight:SetSize(2, 8)
        book.confirm.lockParts = { lockBody, lockTop, lockLeft, lockRight }
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
        book.damageBorder:SetPoint("TOPLEFT",575,-133); book.damageBorder:SetSize(350,115)
        book.damageBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        -- Neutral translucent cream separates this panel without a coloured cast.
        book.damageBorder:SetBackdropColor(0.045,0.032,0.018,0.88)
        book.damageBorder:SetBackdropBorderColor(0.36,0.23,0.10,0.48)
        local damageHeading = label(book.damageBorder, "Equal-level damage taken", 13, -9, 315)
        damageHeading:SetTextColor(1.00, 0.82, 0.14)
        local damageScroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
        damageScroll:SetPoint("TOPLEFT",588,-163); damageScroll:SetSize(320,55)
        book.damageChild=CreateFrame("Frame",nil,damageScroll)
        book.damageChild:SetSize(315,55); damageScroll:SetScrollChild(book.damageChild)
        book.damageScroll=damageScroll
        book.damageScrollBar=damageScroll.ScrollBar
        if type(book.damageScrollBar)=="function" then book.damageScrollBar=nil end
        if not book.damageScrollBar and type(damageScroll.GetScrollBar)=="function" then book.damageScrollBar=damageScroll:GetScrollBar() end
        book.damageRows={}
        book.noDamage=label(book.damageChild,"No equal-level hit ranges recorded.",3,-3,305,"GameFontHighlightSmall")
        local abilityDivider = detail:CreateTexture(nil, "ARTWORK")
        abilityDivider:SetColorTexture(0.35,0.20,0.08,0.42)
        abilityDivider:SetPoint("TOPLEFT",326,-315); abilityDivider:SetSize(600,1)
        label(detail, "Recorded abilities", 326, -325, 248, "GameFontNormalLarge")
        book.abilityCount = label(detail, "", 580, -331, 346, "GameFontHighlightSmall")
        book.abilityCount:SetJustifyH("RIGHT")
        book.abilities = {}
        for i=1,4 do
            local row = CreateFrame("Frame", nil, detail)
            row:SetPoint("TOPLEFT", 326, -360-(i-1)*43); row:SetSize(584, 42)
            row.tooltipCheck=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
            row.tooltipCheck:SetPoint("TOPLEFT",-2,0); row.tooltipCheck:SetSize(20,20)
            row.tooltipCheck:SetScript("OnClick",function(self)
                if selected and row.name then journal:SetAbilityTooltip(selected,row.name,self:GetChecked() == true); refresh() end
            end)
            row.text = label(row,"",22,0,280)
            row.text:SetWordWrap(false)
            row.note = label(row,"",35,-17,350,"GameFontHighlightSmall")
            row.note:SetHeight(23)
            row.link = button(row,"Edit",313,0,72,function()
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
            row.accept = button(row,"Confirm",394,0,88,function()
                journal:SetAbility(selected,row.name,"confirmed"); refresh()
            end)
            row.reject = button(row,"Reject",488,0,88,function()
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
        label(detail,"Ability name you experienced",326,-549,255,"GameFontHighlightSmall")
        label(detail,"Effects (optional)",596,-549,280,"GameFontHighlightSmall")
        book.manualName=edit(detail,332,-567,248,100)
        book.manualEffects={}
        book.effectButton=button(detail,"Choose effects",602,-567,333,function() book.effectPicker:Show(); book.refreshEffectPicker() end)
        label(detail,"Field note (optional)",326,-600,575,"GameFontHighlightSmall")
        book.manualNote=edit(detail,332,-620,603,300)
        label(detail,"Optional spell ID, link, or exact name (out of combat)",326,-652,575,"GameFontHighlightSmall")
        book.spellLink=edit(detail,332,-672,300,255)
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
        button(detail,"Resolve",640,-672,92,resolveSpellLink)
        button(detail,"Confirm this ability",740,-672,195,function()
            local ok,msg=journal:AddManual(selected,book.manualName:GetText(),book.manualNote:GetText(),book.spellLink:GetText(),book.manualEffects)
            message(msg)
            if ok then book.manualName:SetText(""); book.manualNote:SetText(""); book.spellLink:SetText(""); book.manualEffects={}; book.effectButton:SetText("Choose effects"); refresh() end
        end)
        book.damageButton=button(detail,"Record equal-level hits",575,-248,347,function()
            book.damageForm:SetShown(not book.damageForm:IsShown())
        end)
        book.offenseButton=button(detail,"Offenses",575,-277,111,function()
            book.offensePicker:Show()
        end)
        book.defenseButton=button(detail,"Defenses",693,-277,111,function()
            book.defensePicker:Show()
        end)
        book.behaviourButton=button(detail,"Behaviour",811,-277,111,function()
            book.behaviourPicker:Show()
        end)
        book.message=label(book,"",326,-704,578,"GameFontHighlightSmall")
        book.message:SetHeight(25); book.message:SetJustifyV("TOP")
        local effectPicker=CreateFrame("Frame",nil,book,"BackdropTemplate")
        effectPicker:SetSize(560,455); effectPicker:SetPoint("CENTER"); effectPicker:SetFrameStrata("FULLSCREEN_DIALOG"); effectPicker:SetFrameLevel(102)
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
        effectPaper:SetTexture("Interface\\AddOns\\ClassicBestiary\\Artwork\\ParchmentBook.tga")
        effectPaper:SetTexCoord(0,1,0,1)
        addBackgroundLayer(effectPaper, 0.504,0.504,0.48888)
        label(effectPicker,"Effects",25,-25,350,"GameFontNormalLarge")
        label(effectPicker,"Choose every effect you personally observed for this ability.",25,-54,470,"GameFontHighlightSmall")
        button(effectPicker,"Close",410,-20,110,function() effectPicker:Hide() end)
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
        local function createObservationPicker(globalName,title,description,width,height)
            local picker=CreateFrame("Frame",globalName,UIParent,"BackdropTemplate")
            picker:SetSize(width,height); picker:SetPoint("CENTER"); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetClampedToScreen(true)
            picker:SetToplevel(true)
            picker:SetMovable(true); picker:EnableMouse(true); picker:RegisterForDrag("LeftButton")
            picker:SetScript("OnDragStart",function(self) self:StartMoving() end)
            picker:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
            picker:SetScript("OnMouseDown",raiseObservationPicker)
            picker:SetScript("OnShow",raiseObservationPicker)
            picker:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
            local paper=picker:CreateTexture(nil,"BACKGROUND",nil,1)
            paper:SetPoint("TOPLEFT",picker,"TOPLEFT",6,-6); paper:SetPoint("BOTTOMRIGHT",picker,"BOTTOMRIGHT",-6,6)
            paper:SetTexture("Interface\\AddOns\\ClassicBestiary\\Artwork\\ParchmentBook.tga")
            paper:SetTexCoord(0,1,0,1)
            addBackgroundLayer(paper,0.504,0.504,0.48888)
            label(picker,title,25,-25,width-155,"GameFontNormalLarge")
            label(picker,description,25,-54,width-50,"GameFontHighlightSmall")
            button(picker,"Close",width-140,-20,110,function() picker:Hide() end)
            picker:SetScript("OnHide",function(self) self:StopMovingOrSizing() end)
            return picker
        end

        local offensePicker=createObservationPicker("ClassicBestiaryOffenses","Observed offenses","Select every magic school this creature has been observed casting.",480,250)
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
                control:SetAlpha(enabled and 1 or 0.45); control:SetEnabled(entry ~= nil)
            end
        end
        offensePicker:HookScript("OnShow",refreshOffensePicker)
        offensePicker:Hide(); book.offensePicker=offensePicker; book.refreshOffensePicker=refreshOffensePicker

        local defensePicker=createObservationPicker("ClassicBestiaryDefenses","Observed defenses","Mark each magic school as resistant, immune, or both when personally observed.",540,335)
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
                row.resistant:SetEnabled(entry ~= nil); row.immune:SetEnabled(entry ~= nil)
            end
        end
        defensePicker:HookScript("OnShow",refreshDefensePicker)
        defensePicker:Hide(); book.defensePicker=defensePicker; book.refreshDefensePicker=refreshDefensePicker

        local behaviourPicker=createObservationPicker("ClassicBestiaryBehaviour","Observed behaviour","Record only behaviour you have personally seen from this creature.",540,430)
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
                control:SetEnabled(entry ~= nil)
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
        formPaper:SetTexture("Interface\\AddOns\\ClassicBestiary\\Artwork\\ParchmentBook.tga")
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
        local notesForm=CreateFrame("Frame","ClassicBestiaryDamageNotes",book,"BackdropTemplate")
        notesForm:SetSize(500,330); notesForm:SetPoint("CENTER"); notesForm:SetFrameStrata("FULLSCREEN_DIALOG"); notesForm:SetFrameLevel(101)
        notesForm:SetClampedToScreen(true)
        notesForm:SetMovable(true); notesForm:EnableMouse(true); notesForm:RegisterForDrag("LeftButton")
        notesForm:SetScript("OnDragStart",function(self) self:StartMoving() end)
        notesForm:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        notesForm:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local notesPaper=notesForm:CreateTexture(nil,"BACKGROUND",nil,1)
        notesPaper:SetPoint("TOPLEFT",notesForm,"TOPLEFT",6,-6); notesPaper:SetPoint("BOTTOMRIGHT",notesForm,"BOTTOMRIGHT",-6,6)
        notesPaper:SetTexture("Interface\\AddOns\\ClassicBestiary\\Artwork\\ParchmentBook.tga")
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

        local locationFrame=CreateFrame("Frame","ClassicBestiaryLocations",UIParent,"BackdropTemplate")
        locationFrame:SetSize(440,460); locationFrame:SetPoint("CENTER"); locationFrame:SetFrameStrata("FULLSCREEN_DIALOG"); locationFrame:SetClampedToScreen(true)
        locationFrame:SetMovable(true); locationFrame:EnableMouse(true); locationFrame:RegisterForDrag("LeftButton")
        locationFrame:SetScript("OnDragStart",function(self) self:StartMoving() end)
        locationFrame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        locationFrame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local locationPaper=locationFrame:CreateTexture(nil,"BACKGROUND",nil,1)
        locationPaper:SetPoint("TOPLEFT",locationFrame,"TOPLEFT",6,-6)
        locationPaper:SetPoint("BOTTOMRIGHT",locationFrame,"BOTTOMRIGHT",-6,6)
        locationPaper:SetTexture("Interface\\AddOns\\ClassicBestiary\\Artwork\\ParchmentBook.tga")
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
            locationChild:SetHeight(math.max(280,#names*28))
        end
        button(locationFrame,"Clear all",28,-405,170,function()
            for location in pairs(locationFilters) do locationFilters[location]=nil end
            offset=0; refresh(); refreshLocationPicker()
        end)
        button(locationFrame,"Close",242,-405,170,function() locationFrame:Hide() end)
        locationFrame:SetScript("OnShow",refreshLocationPicker)
        locationFrame:SetScript("OnHide",function(self) self:StopMovingOrSizing() end)
        locationFrame:Hide(); book.locationFrame=locationFrame

        local help=CreateFrame("Frame","ClassicBestiaryHelp",UIParent,"BackdropTemplate")
        help:SetSize(610,640); help:SetPoint("CENTER"); help:SetFrameStrata("FULLSCREEN_DIALOG"); help:SetClampedToScreen(true)
        help:SetMovable(true); help:EnableMouse(true); help:RegisterForDrag("LeftButton")
        help:SetScript("OnDragStart",function(self) self:StartMoving() end)
        help:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        help:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local helpPaper=help:CreateTexture(nil,"BACKGROUND",nil,1)
        helpPaper:SetPoint("TOPLEFT",help,"TOPLEFT",6,-6)
        helpPaper:SetPoint("BOTTOMRIGHT",help,"BOTTOMRIGHT",-6,6)
        helpPaper:SetTexture("Interface\\AddOns\\ClassicBestiary\\Artwork\\ParchmentBook.tga")
        helpPaper:SetTexCoord(0,1,0,1); addBackgroundLayer(helpPaper, 0.504,0.504,0.48888)
        label(help,"HOW TO USE THE BESTIARY",30,-30,500,"GameFontNormalLarge")
        label(help,"1. Encounter\nTarget or mouse over an attackable NPC. Its name, creature type and observed level range are added without revealing unseen abilities.\n\n2. Record\nReadable casts and safe post-combat records become pending field notes. Add hidden traps or other missing abilities manually only after experiencing them. Equal-level hit ranges are manual observations because Forever blocks per-hit combat-log data.\n\n3. Review\nOpen the book, select the creature and review each ability. Confirm accurate observations, reject doubtful ones, or remove rejected notes.\n\n4. Lock in\nLock the creature entry when you are satisfied. Only confirmed abilities from locked entries appear in NPC tooltips. Unlocking hides them again without deleting your notes.\n\n5. Browse\nUse creature-type buttons, search, A-Z tabs and the Index reset to navigate a large journal. All knowledge remains per character and comes from your own encounters.\n\n6. Reset\nTo permanently erase the Bestiary, type /bestiary wipe, then /bestiary wipe confirm within 60 seconds.",35,-75,535)
        help.creatureAnnouncement=CreateFrame("CheckButton",nil,help,"UICheckButtonTemplate")
        help.creatureAnnouncement:SetPoint("TOPLEFT",30,-478); help.creatureAnnouncement:SetSize(24,24)
        label(help,"Show a chat message when a new creature entry is added",58,-484,460,"GameFontHighlightSmall")
        help.creatureAnnouncement:SetScript("OnClick",function(self) journal:SetCreatureAnnouncement(self:GetChecked() == true) end)
        help.spellIDTooltips=CreateFrame("CheckButton",nil,help,"UICheckButtonTemplate")
        help.spellIDTooltips:SetPoint("TOPLEFT",30,-510); help.spellIDTooltips:SetSize(24,24)
        label(help,"Show aura spell IDs on tooltips",58,-516,460,"GameFontHighlightSmall")
        help.spellIDTooltips:SetScript("OnClick",function(self) journal:SetSpellIDTooltips(self:GetChecked() == true) end)
        label(help,"Background brightness",58,-543,170,"GameFontHighlightSmall")
        help.backgroundBrightness=CreateFrame("Slider",nil,help,"OptionsSliderTemplate")
        help.backgroundBrightness:SetPoint("TOPLEFT",30,-558)
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
        if type(StaticPopupDialogs) == "table" then
            StaticPopupDialogs.CLASSICBESTIARY_RESET_CONFIRM = {
                text = "Reset the Bestiary database? This permanently deletes all entries, notes, abilities, damage records and settings.",
                button1 = YES, button2 = NO,
                OnAccept = function()
                    journal:ResetDatabase()
                    for location in pairs(locationFilters) do locationFilters[location] = nil end
                    book:SetBackgroundBrightness(journal:GetBackgroundBrightness())
                    refresh()
                    message("The Bestiary database was reset.")
                end,
                timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            }
        end
        button(help,"Reset database",30,-595,160,function()
            if StaticPopup_Show then StaticPopup_Show("CLASSICBESTIARY_RESET_CONFIRM") end
        end)
        help:SetScript("OnShow",function()
            help.creatureAnnouncement:SetChecked(journal:GetCreatureAnnouncement())
            help.spellIDTooltips:SetChecked(journal:GetSpellIDTooltips())
            help.backgroundBrightness:SetValue(journal:GetBackgroundBrightness())
        end)
        button(help,"Close",225,-595,160,function() help:Hide() end)
        help:Hide(); book.help=help
        book:SetScript("OnHide",function() book.search:ClearFocus(); book.manualName:ClearFocus(); book.manualNote:ClearFocus(); book.spellLink:ClearFocus(); form:Hide(); notesForm:Hide(); effectPicker:Hide(); locationFrame:Hide(); offensePicker:Hide(); defensePicker:Hide(); behaviourPicker:Hide() end)
        local elapsed, revision = 0, -1
        book:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt
            if elapsed>=0.5 then elapsed=0; if revision~=journal.revision then revision=journal.revision; refresh() end end
        end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ClassicBestiaryBook"; UISpecialFrames[#UISpecialFrames+1]="ClassicBestiaryHelp"; UISpecialFrames[#UISpecialFrames+1]="ClassicBestiaryDamageNotes"; UISpecialFrames[#UISpecialFrames+1]="ClassicBestiaryLocations"; UISpecialFrames[#UISpecialFrames+1]="ClassicBestiaryOffenses"; UISpecialFrames[#UISpecialFrames+1]="ClassicBestiaryDefenses"; UISpecialFrames[#UISpecialFrames+1]="ClassicBestiaryBehaviour" end
        if UIParent.GetWidth and UIParent.GetHeight then
            book:SetScale(math.min(1, (UIParent:GetWidth()-30)/960, (UIParent:GetHeight()-30)/740))
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
    return controller
end
