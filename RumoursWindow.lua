local _, ns = ...

function ns.CreateRumoursWindow(journal,onChanged,getAnchors)
    local frame,selected,entry,revision
    local controller={}
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
        local basic=entry and journal:GetBasicInfo(selected)
        frame.creature:SetText(basic and basic.name or "Select a creature in the Bestiary.")
        frame.instructions:SetText(entry and entry.confirmed
            and "This entry is locked. Unlock it to verify rumours. You can still reject them."
            or "Verify a rumour to add it to your journal, or reject it.")
        local rows={}
        for _,claim in ipairs(journal:GetRumours(selected)) do
            local text="Unverified: " .. ns.SharingReport.ClaimText(claim) .. "\nReported by " .. claim.sender
            if journal:WasRumourRejected(selected,claim) then text=text .. "\n|cffffb347Previously rejected|r" end
            rows[#rows+1]={claim=claim,text=text}
        end
        if #rows==0 then rows[1]={text="No unverified rumours for this creature."} end
        for _,shared in ipairs(entry and entry.sharedReports or {}) do
            rows[#rows+1]={shared=shared,text="Shared basics: " .. shared.name .. " — " .. shared.category ..
                "\nLevels: " .. (shared.levelMin and (shared.levelMin .. "–" .. shared.levelMax) or "unknown") ..
                "\nLocations: " .. (#shared.locations>0 and table.concat(shared.locations,", ") or "not recorded") ..
                "\nReported by " .. shared.sender}
        end
        local y=0
        for index,data in ipairs(rows) do
            local row=frame.rows[index]
            if not row then
                row=CreateFrame("Frame",nil,frame.body)
                row:SetWidth(416); row:EnableMouse(true)
                row.text=label(row,"",0,0,348)
                row.verify=CreateFrame("Button",nil,row,"UIPanelButtonTemplate")
                row.verify:SetSize(24,24); row.verify:SetPoint("TOPRIGHT",-28,0)
                row.verify.check=row.verify:CreateTexture(nil,"OVERLAY")
                row.verify.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
                row.verify.check:SetSize(24,24); row.verify.check:SetPoint("CENTER")
                row.verify.check:SetVertexColor(0.4,1,0.4)
                row.verify:SetScript("OnClick",function()
                    if not row.claim then return end
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
                row.remove=CreateFrame("Button",nil,row,"UIPanelButtonTemplate")
                row.remove:SetSize(24,24); row.remove:SetPoint("TOPRIGHT",0,0); row.remove:SetText("x")
                row.remove:SetScript("OnClick",function()
                    if row.claim and journal:DismissRumour(selected,row.claim) then
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
                    GameTooltip:SetText("Report from " .. source.sender)
                    GameTooltip:AddLine("Creature #" .. source.creatureID .. " • " .. source.source)
                    GameTooltip:AddLine("Report: " .. source.transaction)
                    GameTooltip:AddLine("Received: " .. (date and date("%Y-%m-%d %H:%M",source.received) or tostring(source.received)))
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave",hideTip)
                frame.rows[index]=row
            end
            row.claim,row.shared=data.claim,data.shared
            row.text:SetWidth(data.claim and 348 or 416); row.text:SetText(data.text)
            local height=math.max(44,(row.text:GetStringHeight() or 70)+16)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-y); row:SetHeight(height)
            row.verify:SetShown(data.claim~=nil); row.remove:SetShown(data.claim~=nil)
            row.verify:SetEnabled(entry~=nil and not entry.confirmed)
            row.verify.check:SetAlpha(entry and not entry.confirmed and 1 or 0.35)
            row:Show(); y=y+height
        end
        for index=#rows+1,#frame.rows do
            frame.rows[index].claim,frame.rows[index].shared=nil,nil
            frame.rows[index]:Hide()
        end
        local empty=#rows==1 and not rows[1].claim and not rows[1].shared
        local areaHeight=empty and y or 300
        local hasMessage=frame.message:GetText()~=""
        local height=empty and (128+areaHeight+(hasMessage and 72 or 16)) or 500
        if frame:GetHeight()~=height then
            -- Both default and restored positions already use a top anchor.
            -- Preserve it so resizing does not detach this window from the book.
            frame:SetHeight(height)
        end
        frame.area:SetHeight(areaHeight)
        frame.body:SetHeight(math.max(areaHeight,y))
        frame.area:SetVerticalScroll(math.min(frame.area:GetVerticalScroll(),math.max(0,y-areaHeight)))
        frame.message:ClearAllPoints(); frame.message:SetPoint("TOPLEFT",18,-(128+areaHeight+21))
        frame.message:SetShown(not empty or hasMessage)
        local brightness=journal:GetBackgroundBrightness()
        frame.paper:SetVertexColor(0.504*brightness,0.504*brightness,0.48888*brightness)
    end
    local function build()
        if frame then return end
        frame=CreateFrame("Frame","AzerothFieldbookRumours",UIParent,"BackdropTemplate")
        frame.afbPreferBookEdge=true
        frame:SetSize(480,500)
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
            frame:SetScale(math.min(1,(UIParent:GetWidth()-30)/(480*1.5),(UIParent:GetHeight()-30)/(500*1.5)))
        end
        frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart",frame.StartMoving); frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
        frame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=20})
        frame.paper=frame:CreateTexture(nil,"BACKGROUND")
        frame.paper:SetPoint("TOPLEFT",6,-6); frame.paper:SetPoint("BOTTOMRIGHT",-6,6)
        frame.paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        label(frame,"Rumours",18,-18,390,"GameFontNormalLarge")
        frame.creature=label(frame,"",18,-48,424,"GameFontNormal"); frame.creature:SetHeight(32)
        frame.instructions=label(frame,"",18,-86,424); frame.instructions:SetHeight(34)
        frame.closeButton=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
        frame.closeButton:SetSize(24,24); frame.closeButton:SetPoint("TOPRIGHT",-3,-3)
        frame.closeButton:SetScript("OnClick",function() frame:Hide() end)
        frame.area=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
        frame.area:SetPoint("TOPLEFT",18,-128); frame.area:SetSize(422,300)
        frame.body=CreateFrame("Frame",nil,frame.area)
        frame.body:SetSize(416,300); frame.area:SetScrollChild(frame.body)
        ns.AutoHideScrollBar(frame.area)
        frame.message=label(frame,"",18,-449,424); frame.message:SetHeight(36)
        frame.rows={}
        frame:SetScript("OnHide",function()
            frame:StopMovingOrSizing(); hideTip()
            if onChanged then onChanged() end
        end)
        -- Refresh when notes, sharing, deletion or reset change the journal even
        -- while the main book is hidden. Hidden windows do no per-frame work.
        frame:SetScript("OnUpdate",function() if revision~=journal.revision then controller:Refresh() end end)
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
    return controller
end
