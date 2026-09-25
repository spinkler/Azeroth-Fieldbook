local _, ns = ...

function ns.CreateCreatureNotesWindow(journal,getBook)
    local frame, selected, entry, loading, expanded, pinned
    local controller = {}
    local function label(parent, value, x, y, width, font)
        local text = parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT",x,y); text:SetWidth(width); text:SetJustifyH("LEFT"); text:SetText(value)
        return text
    end
    local function public(value) return not (issecretvalue and issecretvalue(value)) end
    local function spellName(id)
        if C_Spell and type(C_Spell.GetSpellName)=="function" then
            local ok, name = pcall(C_Spell.GetSpellName,id)
            if ok and public(name) and type(name)=="string" and name~="" then return name:gsub("|", "") end
        end
        return "Spell " .. id
    end
    local function tooltip(row, pinned)
        if not row.spellID then return end
        local tip = GameTooltip
        if pinned and type(SetItemRef)=="function" then
            local ok = pcall(SetItemRef,"spell:" .. row.spellID,row.link,"LeftButton",row)
            if ok and ItemRefTooltip then
                tip = ItemRefTooltip
                if type(tip.SetSpellByID)=="function" then pcall(tip.SetSpellByID,tip,row.spellID) end
            else return end
        else
            if not tip then return end
            tip:SetOwner(row,"ANCHOR_RIGHT")
            if type(tip.SetSpellByID)=="function" then pcall(tip.SetSpellByID,tip,row.spellID) end
        end
        if journal:GetSpellIDTooltips() then tip:AddLine("Spell ID: " .. row.spellID,1,0.82,0) end
        tip:Show()
    end
    local function render()
        if not frame then return end
        local log = selected and journal:GetIDNotes(selected)
        local basic=entry and journal.GetBasicInfo and journal:GetBasicInfo(selected) or entry
        frame.creature:SetText(basic and basic.name and (basic.name .. " |cff999999[#" .. selected .. "]|r")
            or "Select a creature in the Bestiary.")
        local stamp,personal=journal:GetFirstEncounteredAt(selected)
        local encountered=personal and "Unknown" or "Not personally encountered"
        if stamp and type(date)=="function" then
            local ok,formatted=pcall(date,"%d %b %Y, %H:%M:%S",stamp)
            if ok and public(formatted) and type(formatted)=="string" then encountered=formatted end
        end
        frame.firstEncountered:SetText(entry and ("First encountered: "..encountered) or "")
        frame.firstEncountered:SetShown(entry~=nil)
        frame.spellInput:SetShown(entry ~= nil)
        frame.inputLabel:SetShown(entry ~= nil)
        frame.notesToggle:SetEnabled(entry ~= nil)
        -- Personal notes remain editable regardless of the Bestiary entry lock.
        frame.notes:SetEnabled(entry ~= nil)
        frame.notes:SetAlpha(1)
        local count = log and #log.spells or 0
        for index,row in ipairs(frame.rows) do
            local id = log and log.spells[index]
            row.spellID = id
            if id then
                row.link = "|cff71d5ff|Hspell:" .. id .. "|h[" .. spellName(id) .. "]|h|r"
                row.text:SetText(row.link)
                row:Show()
            else row:Hide() end
        end
        frame.count:SetText(count .. "/10")
        local bottom = 152 + count*26
        frame.notesToggle:ClearAllPoints(); frame.notesToggle:SetPoint("TOPLEFT",16,-bottom)
        frame.notesToggle:SetText(expanded and "Notes −" or "Notes +")
        frame.notesArea:ClearAllPoints(); frame.notesArea:SetPoint("TOPLEFT",18,-bottom-30)
        frame.notesArea:SetShown(entry ~= nil and expanded == true)
        frame.notesBorder:SetShown(entry ~= nil and expanded == true)
        frame.notesCount:SetShown(entry ~= nil and expanded == true)
        frame:SetHeight(bottom + (expanded and 180 or 46))
        local brightness=journal:GetBackgroundBrightness()
        frame.paper:SetVertexColor(0.504*brightness,0.504*brightness,0.48888*brightness)
    end
    local function build()
        if frame then return end
        frame=CreateFrame("Frame","AzerothFieldbookCreatureNotes",UIParent,"BackdropTemplate")
        frame.afbPreferBookEdge=true
        frame:SetSize(400,198)
        local book=getBook and getBook()
        if book then frame:SetPoint("TOPLEFT",book,"TOPRIGHT",6,0)
        else frame:SetPoint("CENTER",UIParent,"CENTER",200,0) end
        frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true)
        if UIParent.GetWidth and UIParent.GetHeight then
            frame:SetScale(math.min(1,(UIParent:GetWidth()-30)/(400*1.5),(UIParent:GetHeight()-30)/(592*1.5)))
        end
        frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart",frame.StartMoving); frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
        frame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=20})
        frame.paper=frame:CreateTexture(nil,"BACKGROUND")
        frame.paper:SetPoint("TOPLEFT",6,-6); frame.paper:SetPoint("BOTTOMRIGHT",-6,6)
        frame.paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        label(frame,"ID Logs and Notes",18,-18,280,"GameFontNormalLarge")
        frame.creature=label(frame,"",18,-43,360,"GameFontNormal")
        frame.creature:SetHeight(28)
        frame.firstEncountered=label(frame,"",18,-73,360)
        frame.firstEncountered:SetTextColor(0.6,0.6,0.6)
        local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
        close:SetSize(24,24); close:SetPoint("TOPRIGHT",-3,-3); close:SetScript("OnClick",function() if not pinned then frame:Hide() end end)
        frame.closeButton=close
        local pin=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
        pin:SetSize(24,24); pin:SetPoint("RIGHT",close,"LEFT",-2,0)
        local cover=pin:CreateTexture(nil,"OVERLAY")
        cover:SetPoint("TOPLEFT",6,-6); cover:SetPoint("BOTTOMRIGHT",-6,6)
        cover:SetColorTexture(0.13,0.025,0.015,1)
        local pinParts={}
        local function pinPart(width,height,x,y)
            local part=pin:CreateTexture(nil,"OVERLAY",nil,1)
            part:SetSize(width,height); part:SetPoint("CENTER",x,y)
            part:SetColorTexture(1,0.82,0.14,1)
            pinParts[#pinParts+1]=part
        end
        pinPart(8,2,0,4); pinPart(4,4,0,1)
        pinPart(10,2,0,-2); pinPart(1,4,0,-5)
        pin:SetScript("OnEnter",function()
            if GameTooltip then GameTooltip:SetOwner(pin,"ANCHOR_RIGHT"); GameTooltip:SetText(pinned and "Unpin notes window" or "Pin notes window"); GameTooltip:Show() end
        end)
        pin:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
        frame.pinButton=pin
        pin:SetScript("OnClick",function()
            pinned=not pinned
            frame.afbPinned=pinned
            if pinned and ns.WindowPositions then
                ns.WindowPositions:Save(frame)
                ns.WindowPositions:Restore(frame)
            end
            for _,part in ipairs(pinParts) do
                part:SetVertexColor(1,pinned and 0.65 or 1,pinned and 0.35 or 1)
            end
            pin:SetButtonState(pinned and "PUSHED" or "NORMAL",pinned)
            close:SetEnabled(not pinned); close:SetAlpha(pinned and 0.4 or 1)
            if UISpecialFrames then
                for i=#UISpecialFrames,1,-1 do
                    if UISpecialFrames[i]=="AzerothFieldbookCreatureNotes" then table.remove(UISpecialFrames,i) end
                end
                if not pinned then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookCreatureNotes" end
            end
        end)
        frame.inputLabel=label(frame,"Spell ID — press Enter to record",18,-99,300)
        frame.spellInput=CreateFrame("EditBox",nil,frame,"InputBoxTemplate")
        frame.spellInput:SetSize(145,22); frame.spellInput:SetPoint("TOPLEFT",23,-116)
        frame.spellInput:SetAutoFocus(false); frame.spellInput:SetMaxLetters(10)
        frame.spellInput:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        frame.count=label(frame,"0/10",180,-122,45)
        frame.message=label(frame,"",230,-113,150)
        frame.message:SetHeight(36); frame.message:SetTextColor(1,0.65,0.45)
        frame.spellInput:SetScript("OnEnterPressed",function(self)
            local ok, message=journal:AddNoteSpell(selected,self:GetText())
            frame.message:SetText(message or "")
            if ok then self:SetText(""); render() end
        end)
        frame.rows={}
        for index=1,10 do
            local row=CreateFrame("Button",nil,frame)
            row:SetPoint("TOPLEFT",18,-150-(index-1)*26); row:SetSize(364,24)
            row.text=label(row,"",0,-4,335); row.text:SetWordWrap(false)
            row:SetScript("OnEnter",function() tooltip(row) end)
            row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
            row:SetScript("OnClick",function()
                if IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(row.link)
                else tooltip(row,true) end
            end)
            row.remove=CreateFrame("Button",nil,row)
            row.remove:SetSize(22,22); row.remove:SetPoint("RIGHT",0,0)
            local cross=label(row.remove,"x",5,-3,16,"GameFontNormal")
            cross:SetTextColor(1,0.2,0.15)
            row.remove:SetScript("OnClick",function()
                journal:RemoveNoteSpell(selected,row.spellID); frame.message:SetText(""); render()
            end)
            frame.rows[index]=row
        end
        frame.notesToggle=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
        frame.notesToggle:SetSize(90,22)
        frame.notesToggle:SetScript("OnClick",function() expanded=not expanded; render() end)
        frame.notesBorder=CreateFrame("Frame",nil,frame,"BackdropTemplate")
        frame.notesBorder:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10})
        frame.notesBorder:SetBackdropColor(0.035,0.025,0.015,0.85)
        frame.notesBorder:SetBackdropBorderColor(0.55,0.40,0.20,1)
        frame.notesCount=label(frame,"0/400",310,0,65)
        frame.notesCount:ClearAllPoints(); frame.notesCount:SetPoint("LEFT",frame.notesToggle,"RIGHT",205,0)
        frame.notesArea=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
        frame.notesArea:SetSize(338,116)
        frame.notesBorder:SetPoint("TOPLEFT",frame.notesArea,"TOPLEFT",-5,5)
        frame.notesBorder:SetPoint("BOTTOMRIGHT",frame.notesArea,"BOTTOMRIGHT",25,-5)
        frame.notes=CreateFrame("EditBox",nil,frame.notesArea)
        frame.notes:SetMultiLine(true); frame.notes:SetAutoFocus(false); frame.notes:SetFontObject(ChatFontNormal)
        frame.notes:SetWidth(332); frame.notes:SetHeight(116); frame.notes:SetMaxLetters(400)
        frame.notesArea:SetScrollChild(frame.notes)
        ns.AutoHideScrollBar(frame.notesArea)
        local function focusNotes(_, button)
            if entry and button == "LeftButton" then frame.notes:SetFocus() end
        end
        frame.notesArea:EnableMouse(true)
        frame.notesArea:SetScript("OnMouseDown",focusNotes)
        frame.notesBorder:EnableMouse(true)
        frame.notesBorder:SetScript("OnMouseDown",focusNotes)
        frame.notes:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        frame.notes:SetScript("OnTextChanged",function(self)
            local value=self:GetText()
            local _, count=value:gsub("[^\128-\191]", "")
            frame.notesCount:SetText(count .. "/400")
            if not loading and selected then journal:SetCreatureNotes(selected,value) end
        end)
        frame.notes:SetScript("OnCursorChanged",function(_,_,y,_,height)
            local top, offset = -y, frame.notesArea:GetVerticalScroll()
            if top<offset then frame.notesArea:SetVerticalScroll(math.max(0,top))
            elseif top+height>offset+116 then frame.notesArea:SetVerticalScroll(math.max(0,top+height-116)) end
        end)
        frame:SetScript("OnHide",function()
            frame.spellInput:ClearFocus(); frame.notes:ClearFocus(); frame:StopMovingOrSizing()
        end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookCreatureNotes" end
        if ns.UIScale then ns.UIScale:Register(frame,"AzerothFieldbookCreatureNotes") end
        frame:Hide()
    end
    function controller:SetCreature(id)
        local nextEntry=id and journal.entries[id]
        if id==selected and nextEntry==entry then render(); return end
        selected,entry=id,nextEntry
        if not frame then return end
        loading=true
        frame.spellInput:SetText(""); frame.message:SetText("")
        local log=entry and journal:GetIDNotes(id)
        frame.notes:SetText(log and log.text or "")
        frame.notes:ClearFocus(); frame.notesArea:SetVerticalScroll(0)
        expanded=entry ~= nil
        loading=false
        render()
    end
    function controller:GetFrame() return frame end
    function controller:Refresh()
        self:SetCreature(selected)
    end
    function controller:FollowTarget()
        local id=journal:GetNotesTarget()
        if id then self:SetCreature(id) end
    end
    function controller:Open(id)
        build()
        -- Refresh even when a creature was selected before the window was built.
        selected,entry=false,false
        self:SetCreature(id)
        render(); frame:Show()
    end
    function controller:Toggle(id)
        if frame and frame:IsShown() then
            if not pinned then frame:Hide() end
        else
            self:Open(id)
        end
    end
    return controller
end
