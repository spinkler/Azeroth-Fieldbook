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
    return "0.5.68"
end

function ns.CreateBook(journal)
    local book, selected, offset, abilityOffset = nil, nil, 0, 0
    local noteOffset, refreshDamageNotes = 0, nil
    local category, initial, reviewOnly = nil, nil, false
    local typeOrder = { "Beast", "Humanoid", "Dragonkin", "Demon", "Elemental", "Giant", "Undead", "Mechanical", "Critter", "Totem", "Aberration", "Gas Cloud", "Not specified", "Unclassified" }
    local ink = { 0.1, 0.1, 0.1 }
    local inkShadow = { 0.65, 0.7, 0.7 }
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
                edge[i]:SetColorTexture(1.00,0.76,0.20,alpha)
                lines[#lines+1]=edge[i]
            end
            edge[1]:SetPoint("TOPLEFT",inset,-inset); edge[1]:SetPoint("TOPRIGHT",-inset,-inset); edge[1]:SetHeight(1)
            edge[2]:SetPoint("BOTTOMLEFT",inset,inset); edge[2]:SetPoint("BOTTOMRIGHT",-inset,inset); edge[2]:SetHeight(1)
            edge[3]:SetPoint("TOPLEFT",inset,-inset); edge[3]:SetPoint("BOTTOMLEFT",inset,inset); edge[3]:SetWidth(1)
            edge[4]:SetPoint("TOPRIGHT",-inset,-inset); edge[4]:SetPoint("BOTTOMRIGHT",-inset,inset); edge[4]:SetWidth(1)
        end
        -- Three fading one-pixel edges make a glow contained inside the
        -- native button border at every aspect ratio.
        addEdge(3,0.18); addEdge(4,0.48); addEdge(5,0.95)
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
        local rows=journal:List(category,book.search:GetText(),reviewOnly,initial)
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
        for _, e in pairs(journal.entries) do available[e.category] = true end
        if category and not available[category] then category = nil end
        for name, typeButton in pairs(book.typeButtons) do
            local selectedType=(name == "All creatures" and category == nil) or category == name
            typeButton:Show()
            typeButton:SetEnabled(name == "All creatures" or available[name] == true)
            typeButton:SetSelected(selectedType)
        end
        book.indexReset:SetEnabled(initial ~= nil)
        local unletteredRows=journal:List(category,book.search:GetText(),reviewOnly,nil)
        local availableLetters={}
        for _,row in ipairs(unletteredRows) do availableLetters[row.name:sub(1,1):upper()]=true end
        for _,letterButton in ipairs(book.letterButtons) do
            letterButton:SetEnabled(availableLetters[letterButton.letter] == true)
            letterButton:SetSelected(initial == letterButton.letter)
        end
        local rows = initial and journal:List(category, book.search:GetText(), reviewOnly, initial) or unletteredRows
        offset = math.max(0, math.min(offset, math.max(0, #rows - 13)))
        for i, row in ipairs(book.rows) do
            local data = rows[offset + i]
            row.id = data and data.id
            if data then
                row.text:SetText((data.review and "* " or "") .. data.name)
                row.highlight:SetShown(data.id == selected)
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
        book.subTitle:SetText(table.concat(status, "  |  "))
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
                local note=ability.note or ability.origin or "Observed"
                row.note:SetText(effects and (effects.." — "..note) or note)
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
        book:SetFrameStrata("DIALOG")
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
        book:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=24, insets={left=8,right=8,top=8,bottom=8}})
        -- QuestBG has transparent padding. Back the entire page with opaque
        -- parchment, then stretch only an interior, non-transparent texture area.
        local paper = book:CreateTexture(nil, "BACKGROUND", nil, 1)
        paper:SetPoint("TOPLEFT", book, "TOPLEFT", 9, -9)
        paper:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -2, 9)
        paper:SetColorTexture(0.4928, 0.4368, 0.336, 1)
        local page = book:CreateTexture(nil, "BACKGROUND", nil, 2)
        page:SetAllPoints(paper)
        page:SetTexture("Interface\\QuestFrame\\QuestBG")
        -- This high-resolution sheet matches the book's aspect closely and is
        -- downscaled slightly, avoiding both tiled seams and enlarged pixels.
        page:SetTexture("Interface\\AddOns\\ClassicBestiary\\Artwork\\ParchmentBook.tga")
        page:SetHorizTile(false)
        page:SetVertTile(false)
        page:SetTexCoord(0, 1, 0, 1)
        page:SetVertexColor(0.56, 0.56, 0.5432)
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
            paper:SetPoint("TOPLEFT",book,"TOPLEFT",9,-9)
            paper:SetPoint("BOTTOMRIGHT",book,"BOTTOMRIGHT",-2,9)
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
        label(book, "Filters", 24, -90, 96, "GameFontHighlightSmall")
        book.typeButtons = {}
        local function addTypeButton(name, y)
            local typeButton = button(book, name == "All creatures" and "All" or name, 24, y, 96, function()
                category = name == "All creatures" and nil or name
                offset = 0; refresh()
            end)
            addSelectionOutline(typeButton)
            book.typeButtons[name] = typeButton
        end
        addTypeButton("All creatures", -110)
        for i, name in ipairs(typeOrder) do addTypeButton(name, -110-i*28) end
        label(book, "Search the index", 124, -55, 172)
        book.search = edit(book, 136, -78, 152, 100)
        book.search:SetScript("OnTextChanged", function() offset = 0; refresh() end)
        book.review = button(book, "Pending", 24, -534, 96, function()
            reviewOnly = not reviewOnly
            book.review:SetText(reviewOnly and "All entries" or "Pending")
            offset = 0; refresh()
        end)
        book.rows = {}
        for i = 1, 13 do
            local row = CreateFrame("Button", nil, book)
            row:SetPoint("TOPLEFT", 132, -110 - (i-1)*29); row:SetSize(156, 27)
            row.highlight = row:CreateTexture(nil, "BACKGROUND")
            row.highlight:SetAllPoints(); row.highlight:SetColorTexture(0.4,0.23,0.06,0.18)
            row.text = label(row, "", 5, -6, 146)
            row.text:SetWordWrap(false)
            row:SetScript("OnClick", function(self) if self.id then choose(self.id) end end)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta) offset=offset-delta*3; refresh() end)
            book.rows[i] = row
        end
        button(book, "Previous", 132, -626, 72, function() cycleEntry(-1) end)
        button(book, "Next", 214, -626, 74, function() cycleEntry(1) end)
        book.indexCount = label(book, "", 132, -660, 156, "GameFontHighlightSmall")
        label(book, "Use type and A-Z tabs to filter the index.\nBind this book in Options > Keybindings.",24,-704,256,"GameFontHighlightSmall")
        book.indexReset = button(book, "Index", 892, -54, 57, function() initial=nil; offset=0; refresh() end)
        book.letterButtons = {}
        for i=1,26 do
            local letter = string.char(64+i)
            local tab = button(book, letter, 921, -83-(i-1)*23, 28, function()
                initial=letter; offset=0; refresh()
            end)
            tab:SetHeight(21)
            tab.letter=letter; addSelectionOutline(tab)
            book.letterButtons[i]=tab
        end
        book.title = label(book, "", 336, -55, 365, "GameFontNormalLarge")
        local titlePath, titleSize, titleFlags = book.title:GetFont()
        if titlePath and titleSize then book.title:SetFont(titlePath, titleSize + 2, titleFlags) end
        book.subTitle = label(book, "", 336, -84, 570)
        book.empty = label(book, "Every page begins with an encounter.\n\nOnly creatures you have met appear here.\nSelect an entry from the index to review your notes.", 340, -210, 520)
        book.detail = CreateFrame("Frame", nil, book)
        book.detail:SetAllPoints()
        local detail = book.detail
        book.modelBorder=CreateFrame("Frame",nil,detail,"BackdropTemplate")
        book.modelBorder:SetPoint("TOPLEFT",338,-107); book.modelBorder:SetSize(229,194)
        book.modelBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=8,insets={left=2,right=2,top=2,bottom=2}})
        book.modelBorder:SetBackdropColor(0.045,0.032,0.018,0.88)
        book.modelBorder:SetBackdropBorderColor(0.37,0.25,0.11,0.90)
        book.model = CreateFrame("PlayerModel", nil, detail)
        book.model:SetPoint("TOPLEFT", 340, -109); book.model:SetSize(225, 190)
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
            book.modelCaption:SetText("Creature model - drag to rotate")
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
        book.damageBorder:SetPoint("TOPLEFT",575,-109); book.damageBorder:SetSize(320,139)
        book.damageBorder:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12,insets={left=2,right=2,top=2,bottom=2}})
        -- Neutral translucent cream separates this panel without a coloured cast.
        book.damageBorder:SetBackdropColor(1.00,1.00,1.00,0.55)
        book.damageBorder:SetBackdropBorderColor(0.36,0.23,0.10,0.48)
        label(detail, "Equal-level damage taken", 588, -118, 285)
        local damageScroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
        damageScroll:SetPoint("TOPLEFT",588,-139); damageScroll:SetSize(290,72)
        book.damageChild=CreateFrame("Frame",nil,damageScroll)
        book.damageChild:SetSize(285,72); damageScroll:SetScrollChild(book.damageChild)
        book.damageScroll=damageScroll
        book.damageScrollBar=damageScroll.ScrollBar
        if type(book.damageScrollBar)=="function" then book.damageScrollBar=nil end
        if not book.damageScrollBar and type(damageScroll.GetScrollBar)=="function" then book.damageScrollBar=damageScroll:GetScrollBar() end
        book.damageRows={}
        book.noDamage=label(book.damageChild,"No equal-level hit ranges recorded.",3,-3,275,"GameFontHighlightSmall")
        local abilityDivider = detail:CreateTexture(nil, "ARTWORK")
        abilityDivider:SetColorTexture(0.35,0.20,0.08,0.42)
        abilityDivider:SetPoint("TOPLEFT",326,-315); abilityDivider:SetSize(570,1)
        label(detail, "Recorded abilities", 326, -325, 248, "GameFontNormalLarge")
        book.abilityCount = label(detail, "", 580, -331, 316, "GameFontHighlightSmall")
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
        book.effectButton=button(detail,"Choose effects",602,-567,303,function() book.effectPicker:Show(); book.refreshEffectPicker() end)
        label(detail,"Field note (optional)",326,-600,575,"GameFontHighlightSmall")
        book.manualNote=edit(detail,332,-620,573,300)
        label(detail,"Optional spell ID, link, or exact name (out of combat)",326,-652,575,"GameFontHighlightSmall")
        book.spellLink=edit(detail,332,-672,300,255)
        button(detail,"Resolve",640,-672,92,function()
            local spellID,spellName,errorMessage=journal:ResolveSpell(book.spellLink:GetText())
            if errorMessage then message(errorMessage); return end
            if not spellID then message("No exact readable spell match. Enter an ID or paste a spell link."); return end
            local ok,link=false,nil
            if C_Spell and type(C_Spell.GetSpellLink)=="function" then ok,link=pcall(C_Spell.GetSpellLink,spellID) end
            if ok and not (issecretvalue and issecretvalue(link)) and type(link)=="string" then book.spellLink:SetText(link) else book.spellLink:SetText(tostring(spellID)) end
            if book.manualName:GetText()=="" then book.manualName:SetText(spellName) end
            message("Exact match: "..spellName.." (ID "..spellID..").")
        end)
        button(detail,"Confirm this ability",740,-672,165,function()
            local ok,msg=journal:AddManual(selected,book.manualName:GetText(),book.manualNote:GetText(),book.spellLink:GetText(),book.manualEffects)
            message(msg)
            if ok then book.manualName:SetText(""); book.manualNote:SetText(""); book.spellLink:SetText(""); book.manualEffects={}; book.effectButton:SetText("Choose effects"); refresh() end
        end)
        book.damageButton=button(detail,"Record equal-level hits",588,-277,285,function()
            book.damageForm:SetShown(not book.damageForm:IsShown())
        end)
        book.message=label(book,"",326,-704,578,"GameFontHighlightSmall")
        book.message:SetHeight(25); book.message:SetJustifyV("TOP")
        local effectPicker=CreateFrame("Frame",nil,book,"BackdropTemplate")
        effectPicker:SetSize(560,455); effectPicker:SetPoint("CENTER"); effectPicker:SetFrameStrata("FULLSCREEN_DIALOG"); effectPicker:SetFrameLevel(102)
        effectPicker:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=24})
        effectPicker:SetBackdropColor(0.90,0.80,0.60,1)
        local effectPaper=effectPicker:CreateTexture(nil,"BACKGROUND",nil,1)
        effectPaper:SetPoint("TOPLEFT",effectPicker,"TOPLEFT",12,-12); effectPaper:SetPoint("BOTTOMRIGHT",effectPicker,"BOTTOMRIGHT",-12,12)
        effectPaper:SetColorTexture(0.4704,0.3976,0.2632,1)
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
        formPaper:SetVertexColor(0.56,0.56,0.5432)
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
        notesForm:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        local notesPaper=notesForm:CreateTexture(nil,"BACKGROUND",nil,1)
        notesPaper:SetPoint("TOPLEFT",notesForm,"TOPLEFT",12,-12); notesPaper:SetPoint("BOTTOMRIGHT",notesForm,"BOTTOMRIGHT",-12,12)
        notesPaper:SetColorTexture(0.4592,0.3864,0.2576,1)
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
        notesForm:Hide(); book.notesForm=notesForm

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
        helpPaper:SetTexCoord(0,1,0,1); helpPaper:SetVertexColor(0.56,0.56,0.5432)
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
        help:SetScript("OnShow",function()
            help.creatureAnnouncement:SetChecked(journal:GetCreatureAnnouncement())
            help.spellIDTooltips:SetChecked(journal:GetSpellIDTooltips())
        end)
        button(help,"Close",225,-595,160,function() help:Hide() end)
        help:Hide(); book.help=help
        book:SetScript("OnHide",function() book.search:ClearFocus(); book.manualName:ClearFocus(); book.manualNote:ClearFocus(); book.spellLink:ClearFocus(); form:Hide(); notesForm:Hide(); effectPicker:Hide() end)
        local elapsed, revision = 0, -1
        book:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt
            if elapsed>=0.5 then elapsed=0; if revision~=journal.revision then revision=journal.revision; refresh() end end
        end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="ClassicBestiaryBook"; UISpecialFrames[#UISpecialFrames+1]="ClassicBestiaryHelp"; UISpecialFrames[#UISpecialFrames+1]="ClassicBestiaryDamageNotes" end
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
