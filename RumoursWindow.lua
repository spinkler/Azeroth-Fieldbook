local _, ns = ...

function ns.CreateRumoursWindow(journal,onChanged,getAnchors)
    local frame,selected,entry,revision,nameRevision
    local minWidth,maxWidth=260,420
    local textInset=64 -- Two 24px buttons, a 6px gap, then 10px before the text.
    local contentMargins=56 -- Left padding plus the right scrollbar gutter.
    local controller={}
    local function playerName(name) return ns.PlayerNames and ns.PlayerNames:Format(name) or name end
    local function label(parent,text,x,y,width,font)
        local value=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
        value:SetPoint("TOPLEFT",x,y); value:SetWidth(width); value:SetJustifyH("LEFT")
        value:SetWordWrap(true); value:SetText(text)
        return value
    end
    local function tip(owner,text)
        if not GameTooltip then return end
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); GameTooltip:SetText(text); GameTooltip:Show()
    end
    local function hideTip() if GameTooltip then GameTooltip:Hide() end end
    local function render()
        if not frame then return end
        entry=selected and journal.entries[selected]
        revision=journal.revision
        nameRevision=ns.PlayerNames and ns.PlayerNames.revision or 0
        local basic=entry and journal:GetBasicInfo(selected)
        frame.creature:SetText(basic and basic.name or "Select a creature in the Bestiary.")
        frame.instructions:SetText(entry and entry.confirmed
            and "This entry is locked. Unlock it to verify rumours. You can still reject them."
            or "Verify a rumour to add it to your journal, or reject it.")
        local rows={}
        for _,claim in ipairs(journal:GetRumours(selected)) do
            local text="Unverified: " .. ns.SharingReport.ClaimText(claim) .. "\nReported by " .. playerName(claim.sender)
            if journal:WasRumourRejected(selected,claim) then text=text .. "\n|cffffb347Previously rejected|r" end
            rows[#rows+1]={claim=claim,text=text}
        end
        if #rows==0 then rows[1]={text="No unverified rumours for this creature."} end
        for _,shared in ipairs(entry and entry.sharedReports or {}) do
            rows[#rows+1]={shared=shared,text="Shared basics from " .. playerName(shared.sender) .. ":\n" .. shared.name .. " — " .. shared.category ..
                "\nLevels: " .. (shared.levelMin and (shared.levelMin .. "–" .. shared.levelMax) or "unknown") ..
                "\nLocations: " .. (#shared.locations>0 and table.concat(shared.locations,", ") or "not recorded")}
        end
        local function measure(text,font)
            frame.measure:SetFontObject(font)
            local width=0
            for line in text:gmatch("[^\n]+") do
                frame.measure:SetText(line)
                width=math.max(width,frame.measure:GetStringWidth())
            end
            return width
        end
        -- Size to the actual report lines. Instructions and status messages may
        -- wrap, so a long explanation does not stretch a short list of rumours.
        local width=math.max(minWidth,measure(frame.creature:GetText(),"GameFontNormal")+36)
        for _,data in ipairs(rows) do
            width=math.max(width,measure(data.text,"GameFontHighlightSmall")
                +(data.claim and textInset or 0)+contentMargins)
        end
        width=math.min(maxWidth,math.ceil(width))
        local contentWidth=width-contentMargins
        frame:SetWidth(width)
        frame.title:SetWidth(width-60)
        frame.creature:SetWidth(width-36)
        frame.instructions:SetWidth(width-36)
        frame.message:SetWidth(width-36)
        frame.area:SetWidth(contentWidth+6)
        frame.body:SetWidth(contentWidth)
        local y,visibleRumourHeight,otherHeight,rumourCount=0,0,0,0
        for index,data in ipairs(rows) do
            local row=frame.rows[index]
            if not row then
                row=CreateFrame("Frame",nil,frame.body)
                row:EnableMouse(true)
                row.text=label(row,"",0,0,contentWidth-textInset)
                row.divider=row:CreateTexture(nil,"ARTWORK")
                row.divider:SetPoint("TOPLEFT",0,0); row.divider:SetPoint("TOPRIGHT",0,0)
                row.divider:SetHeight(1); row.divider:SetColorTexture(0.35,0.20,0.08,0.2)
                row.verify=CreateFrame("Button",nil,row,"UIPanelCloseButton")
                row.verify:SetSize(24,24)
                ns.StyleConfirmButton(row.verify)
                row.verify:SetMotionScriptsWhileDisabled(true)
                row.verify:SetScript("OnClick",function()
                    if not row.claim then return end
                    hideTip()
                    local ok,message=journal:ConfirmRumour(selected,row.claim)
                    frame.message:SetText(message or "")
                    render()
                    if ok and onChanged then onChanged() end
                end)
                row.verify:SetScript("OnEnter",function()
                    tip(row.verify,entry and entry.confirmed and "Unlock this creature before verifying rumours."
                        or "Verify rumour — add to your journal")
                end)
                row.verify:SetScript("OnLeave",hideTip)
                row.remove=CreateFrame("Button",nil,row,"UIPanelCloseButton")
                row.remove:SetSize(24,24)
                row.remove:SetScript("OnClick",function()
                    if row.claim and journal:DismissRumour(selected,row.claim) then
                        hideTip()
                        frame.message:SetText("Rumour rejected. Future reports will show that you rejected it before.")
                        render()
                        if onChanged then onChanged() end
                    end
                end)
                row.remove:SetScript("OnEnter",function() tip(row.remove,"Reject rumour") end)
                row.remove:SetScript("OnLeave",hideTip)
                row:SetScript("OnEnter",function()
                    local source=row.claim or row.shared
                    if not source or not GameTooltip then return end
                    GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
                    GameTooltip:SetText("Report from " .. playerName(source.sender))
                    GameTooltip:AddLine("Creature #" .. source.creatureID .. " • " .. source.source)
                    GameTooltip:AddLine("Report: " .. source.transaction)
                    GameTooltip:AddLine("Received: " .. (date and date("%Y-%m-%d %H:%M",source.received) or tostring(source.received)))
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave",hideTip)
                frame.rows[index]=row
            end
            row.claim,row.shared=data.claim,data.shared
            row:SetWidth(contentWidth)
            row.text:SetWidth(contentWidth-(data.claim and textInset or 0)); row.text:SetText(data.text)
            local padding=index>1 and 12 or 0
            row.text:ClearAllPoints(); row.text:SetPoint("TOPLEFT",data.claim and textInset or 0,-padding)
            row.verify:ClearAllPoints(); row.verify:SetPoint("TOPLEFT",0,-padding-1)
            row.remove:ClearAllPoints(); row.remove:SetPoint("TOPLEFT",30,-padding-1)
            row.divider:SetShown(index>1)
            local height=padding+math.max(data.claim and 24 or 0,row.text:GetStringHeight() or 28)+12
            if data.claim then
                rumourCount=rumourCount+1
                if rumourCount<=4 then visibleRumourHeight=visibleRumourHeight+height end
            else otherHeight=otherHeight+height end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-y); row:SetHeight(height)
            row.verify:SetShown(data.claim~=nil); row.remove:SetShown(data.claim~=nil)
            row.verify:SetEnabled(entry~=nil and not entry.confirmed)
            row.verify.cover:SetColorTexture(unpack(entry and not entry.confirmed and {0.13,0.025,0.015,1} or {0.22,0.22,0.22,1}))
            row:Show(); y=y+height
        end
        for index=#rows+1,#frame.rows do
            frame.rows[index].claim,frame.rows[index].shared=nil,nil
            frame.rows[index]:Hide()
        end
        local creatureHeight=frame.creature:GetStringHeight()
        local instructionY=48+creatureHeight+12
        frame.instructions:ClearAllPoints(); frame.instructions:SetPoint("TOPLEFT",18,-instructionY)
        local areaY=instructionY+frame.instructions:GetStringHeight()+18
        local hasMessage=frame.message:GetText()~=""
        local footer=hasMessage and (12+frame.message:GetStringHeight()+16) or 16
        local areaHeight=visibleRumourHeight+otherHeight
        -- Four rumours fit in full, including wrapping. Only screen bounds may
        -- impose an earlier limit on exceptionally long content.
        local screenHeight=UIParent:GetHeight()
        local scale=frame:GetEffectiveScale()
        local parentScale=UIParent:GetEffectiveScale()
        if type(screenHeight)=="number" and type(scale)=="number" and scale>0
            and type(parentScale)=="number" and parentScale>0 then
            areaHeight=math.min(areaHeight,math.max(40,(screenHeight-30)*parentScale/scale-areaY-footer))
        end
        frame:SetHeight(areaY+areaHeight+footer)
        frame.area:ClearAllPoints(); frame.area:SetPoint("TOPLEFT",18,-areaY)
        frame.area:SetHeight(areaHeight)
        frame.body:SetHeight(y)
        frame.area:SetVerticalScroll(math.min(frame.area:GetVerticalScroll(),math.max(0,y-areaHeight)))
        frame.area:UpdateScrollChildRect()
        frame.area:RefreshScrollBar()
        frame.message:ClearAllPoints(); frame.message:SetPoint("TOPLEFT",18,-(areaY+areaHeight+12))
        frame.message:SetShown(hasMessage)
        local brightness=journal:GetBackgroundBrightness()
        frame.paper:SetVertexColor(0.504*brightness,0.504*brightness,0.48888*brightness)
    end
    local function build()
        if frame then return end
        frame=CreateFrame("Frame","AzerothFieldbookRumours",UIParent,"BackdropTemplate")
        frame.afbPreferBookEdge=true
        frame:SetSize(maxWidth,500)
        local book=getAnchors and getAnchors()
        if book then
            -- Reserve the expanded, empty ID Logs and Notes window (310 high)
            -- even if Rumours is the first of the two windows opened.
            frame:SetPoint("TOPLEFT",book,"TOPRIGHT",6,-316)
        else frame:SetPoint("CENTER",UIParent,"CENTER",160,0) end
        -- Share the book's layer so dialogs stay above this independent window.
        frame:SetFrameStrata("HIGH"); frame:SetClampedToScreen(true)
        frame:SetToplevel(true)
        frame:SetScript("OnShow",frame.Raise)
        if UIParent.GetWidth and UIParent.GetHeight then
            frame:SetScale(math.min(1,(UIParent:GetWidth()-30)/(maxWidth*1.5),(UIParent:GetHeight()-30)/(500*1.5)))
        end
        frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart",frame.StartMoving); frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
        frame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=20})
        frame.paper=frame:CreateTexture(nil,"BACKGROUND")
        frame.paper:SetPoint("TOPLEFT",6,-6); frame.paper:SetPoint("BOTTOMRIGHT",-6,6)
        frame.paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        frame.title=label(frame,"Rumours",18,-18,maxWidth-60,"GameFontNormalLarge")
        frame.measure=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        frame.measure:SetWordWrap(false);frame.measure:Hide()
        frame.creature=label(frame,"",18,-48,maxWidth-36,"GameFontNormal")
        frame.instructions=label(frame,"",18,-86,maxWidth-36)
        frame.closeButton=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
        frame.closeButton:SetSize(24,24); frame.closeButton:SetPoint("TOPRIGHT",-3,-3)
        frame.closeButton:SetScript("OnClick",function() frame:Hide() end)
        frame.area=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
        frame.area:SetPoint("TOPLEFT",18,-128); frame.area:SetSize(maxWidth-contentMargins+6,300)
        frame.body=CreateFrame("Frame",nil,frame.area)
        frame.body:SetSize(maxWidth-contentMargins,300); frame.area:SetScrollChild(frame.body)
        ns.StyleWindowScrollBar(frame.area,frame)
        ns.AutoHideScrollBar(frame.area)
        frame.message=label(frame,"",18,-449,maxWidth-36)
        frame.rows={}
        frame:SetScript("OnHide",function()
            frame:StopMovingOrSizing(); hideTip()
            if onChanged then onChanged() end
        end)
        -- Refresh when notes, sharing, deletion or reset change the journal even
        -- while the main book is hidden. Hidden windows do no per-frame work.
        frame:SetScript("OnUpdate",function()
            if revision~=journal.revision or nameRevision~=(ns.PlayerNames and ns.PlayerNames.revision or 0) then controller:Refresh() end
        end)
        frame:HookScript("OnShow",function() if controller.visibilityCallback then controller.visibilityCallback(true) end end)
        frame:HookScript("OnHide",function() if controller.visibilityCallback then controller.visibilityCallback(false) end end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookRumours" end
        if ns.UIScale then ns.UIScale:Register(frame,"AzerothFieldbookRumours") end
        frame:Hide()
    end
    function controller:SetCreature(id)
        if selected~=id or entry~=(id and journal.entries[id]) then
            selected=id
            if frame then frame.area:SetVerticalScroll(0); frame.message:SetText("") end
        end
        render()
    end
    function controller:Refresh() self:SetCreature(selected) end
    function controller:IsShown() return frame~=nil and frame:IsShown() end
    function controller:Toggle(id)
        build()
        if frame:IsShown() then frame:Hide(); return end
        self:SetCreature(id); frame:Show()
    end
    function controller:SetVisibilityCallback(callback)
        self.visibilityCallback=callback
        callback(frame~=nil and frame:IsShown())
    end
    return controller
end
