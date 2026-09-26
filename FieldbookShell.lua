local addonName, ns = ...

-- Shared window chrome and navigation. Sections own their content and data;
-- the legacy root name preserves saved positions and external window anchors.
local ink, inkShadow = {0.75,0.8,0.8}, {0.05,0.05,0.05}
local function addonVersion()
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        local ok, version = pcall(C_AddOns.GetAddOnMetadata, addonName, "Version")
        if ok and type(version) == "string" and version ~= "" then return version end
    end
    return "unknown"
end

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

ns.FieldbookUI = {Label=label, Button=button, Close=cornerClose, Edit=edit}

function ns.CreateFieldbookShell(settings)
    settings=settings or {}
    local shell={sections={}, order={}}
    local book, addBackgroundLayer
    local baseScale=1
    function shell:GetFrame() return book end
    function shell:GetBaseScale() return baseScale end
    function shell:EnsureFrame()
        if book then return book end
        if UIParent.GetWidth and UIParent.GetHeight then
            baseScale=math.min(1,(UIParent:GetWidth()-30)/960,(UIParent:GetHeight()-30)/740)
        end
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
        local backgroundBrightness = (settings.getBrightness and settings.getBrightness() or 1)
        local backgroundLayers = {}
        addBackgroundLayer = function(texture, red, green, blue)
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
        book.windowTitle:SetText("Azeroth Fieldbook - v" .. addonVersion())
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
            shell:TogglePage("help")
        end)
        local helpGlyph=book.helpButton:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        helpGlyph:SetAllPoints(); helpGlyph:SetJustifyH("CENTER"); helpGlyph:SetJustifyV("MIDDLE")
        helpGlyph:SetTextColor(1.00,0.82,0.14); helpGlyph:SetText("?")
        book.optionsButton=titleButton(book.helpButton,function()
            shell:TogglePage("options")
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
        book.eventLogButton=titleButton(book.optionsButton,function() shell:TogglePage("eventLog") end)
        for line=1,3 do
            local stroke=book.eventLogButton:CreateTexture(nil,"OVERLAY",nil,1)
            stroke:SetColorTexture(1,0.82,0.14,1);stroke:SetSize(10,1)
            stroke:SetPoint("CENTER",0,4-(line-1)*4)
        end
        book.eventLogButton:SetScript("OnEnter",function(self)
            if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Event log");GameTooltip:Show() end
        end)
        book.eventLogButton:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        book:HookScript("OnHide",function()
            local section=self.sections[self.active]
            if section and section.frame then section.frame:Hide() end
        end)
        book:SetScale(baseScale)
        if ns.UIScale then ns.UIScale:Register(book) end
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=book:GetName() end
        book:Hide()
        return book
    end
    function shell:AddBackgroundLayer(texture,red,green,blue)
        self:EnsureFrame()
        addBackgroundLayer(texture,red,green,blue)
    end
    function shell:SetBackgroundBrightness(value)
        self:EnsureFrame():SetBackgroundBrightness(value)
    end
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

    function shell:CreatePage(name,title,bottomInset)
        self:EnsureFrame()
        return createBookPage(name,title,bottomInset)
    end
    function shell:ShowPage(page) showBookPage(page) end
    function shell:SetSectionPages(id,pages)
        local section=assert(self.sections[id],"Unknown Fieldbook section")
        section.pages=pages
        for key,page in pairs(pages) do
            page.afbPreferBookEdge=true
            page.afbAnchorRule="pages"
            if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=page:GetName() end
            if ns.UIScale then ns.UIScale:Register(page) end
            if ns.WindowPositions then
                local shared=key=="help" or key=="options"
                ns.WindowPositions:Register(page,page:GetName(),shared and function()
                    return page==lastBookPage and "BookPages" or nil
                end or nil)
            end
        end
    end
    function shell:TogglePage(key)
        local section=self.sections[self.active]
        local pages=section and section.pages
        local page=pages and pages[key]
        if not page then return false end
        if key=="help" and pages.options then pages.options:Hide()
        elseif key=="options" and pages.help then pages.help:Hide() end
        page:SetShown(not page:IsShown())
        return true
    end
    function shell:RegisterSection(id,definition)
        assert(type(id)=="string" and id~="" and not self.sections[id],"Duplicate or invalid Fieldbook section")
        assert(type(definition)=="table" and type(definition.title)=="string" and type(definition.build)=="function",
            "A Fieldbook section needs a title and builder")
        self.sections[id]={definition=definition,width=definition.width or 960,height=definition.height or 740}
        self.order[#self.order+1]=id
    end
    function shell:EnsureSection(id)
        local section=assert(self.sections[id],"Unknown Fieldbook section")
        if section.frame then return section.frame end
        local window=self:EnsureFrame()
        local content=CreateFrame("Frame",section.definition.frameName,window)
        content:SetPoint("TOPLEFT");content:SetSize(section.width,section.height)
        content:Hide()
        section.frame=content
        section.definition.build(content,self)
        -- Register after the first section builds, so focus reaches its controls.
        if ns.WindowPositions then ns.WindowPositions:Register(window,window:GetName()) end
        if ns.WindowFocus then ns.WindowFocus:Register(window) end
        return content
    end
    function shell:SetSectionSize(id,width,height)
        local section=assert(self.sections[id],"Unknown Fieldbook section")
        section.width,section.height=width,height
        if section.frame then section.frame:SetSize(width,height) end
        if book and self.active==id then book:SetSize(width,height) end
    end
    function shell:IsSectionShown(id)
        return book~=nil and book:IsShown() and self.active==id
    end
    function shell:ShowSection(id,context)
        local section=self.sections[id]
        if not section then return false end
        local content=self:EnsureSection(id)
        if self.active~=id then
            local previous=self.sections[self.active]
            if previous then
                if previous.frame then previous.frame:Hide() end
                for _,page in pairs(previous.pages or {}) do page:Hide() end
                if previous.definition.onLeave then previous.definition.onLeave() end
            end
        end
        self.active=id
        book:SetSize(section.width,section.height)
        book.windowTitle:SetText("Azeroth Fieldbook - "..section.definition.title.." - v"..addonVersion())
        for _,key in ipairs({"help","options","eventLog"}) do
            book[key.."Button"]:SetEnabled(section.pages~=nil and section.pages[key]~=nil)
        end
        content:Show();book:Show()
        if ns.WindowFocus then ns.WindowFocus:Register(book) end
        if section.definition.onOpen then section.definition.onOpen(context) end
        return true
    end
    function shell:Hide() if book then book:Hide() end end
    function shell:ToggleSection(id)
        if self:IsSectionShown(id) then self:Hide();return end
        return self:ShowSection(id)
    end
    function shell:Toggle()
        return self:ToggleSection(self.active or self.order[1])
    end
    return shell
end
