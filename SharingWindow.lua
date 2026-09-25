local _, ns = ...
local schema=ns.SharingReport

function ns.CreateSharingWindow(journal,engine,getBook)
    local controller={}
    local composer,receiver,captured,candidates,chosen,transaction,incoming
    local refreshing=false
    local function label(parent,text,x,y,width,font)
        local value=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall")
        value:SetPoint("TOPLEFT",x,y); value:SetWidth(width); value:SetJustifyH("LEFT")
        value:SetWordWrap(true); value:SetText(text)
        return value
    end
    local function button(parent,text,x,y,width,callback)
        local value=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
        value:SetPoint("TOPLEFT",x,y); value:SetSize(width,24); value:SetText(text)
        value:SetScript("OnClick",callback)
        return value
    end
    local function window(name,title,height,width)
        width=width or 520
        local frame=CreateFrame("Frame",name,UIParent,"BackdropTemplate")
        frame:SetSize(width,height); frame:SetPoint("CENTER",getBook and getBook() or UIParent,"CENTER")
        frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true)
        frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart",frame.StartMoving); frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
        frame:SetBackdrop({edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
        frame.paper=frame:CreateTexture(nil,"BACKGROUND")
        frame.paper:SetPoint("TOPLEFT",6,-6); frame.paper:SetPoint("BOTTOMRIGHT",-6,6)
        frame.paper:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\ParchmentBook.tga")
        label(frame,title,22,-22,width-70,"GameFontNormalLarge")
        frame.close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
        frame.close:SetSize(24,24); frame.close:SetPoint("TOPRIGHT",-3,-3)
        frame.close:SetScript("OnClick",function() frame:Hide() end)
        if UIParent.GetWidth and UIParent.GetHeight then
            frame:SetScale(math.min(1,(UIParent:GetWidth()-30)/(width*1.5),(UIParent:GetHeight()-30)/(height*1.5)))
        end
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=name end
        if ns.UIScale then ns.UIScale:Register(frame) end
        frame:Hide()
        return frame
    end
    local function scroll(parent,x,y,width,height)
        local area=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
        area:SetPoint("TOPLEFT",x,y); area:SetSize(width,height)
        local body=CreateFrame("Frame",nil,area)
        body:SetSize(width-6,height); area:SetScrollChild(body)
        ns.AutoHideScrollBar(area)
        return area,body
    end
    local function basicDetails(value)
        if not value then return "" end
        local level=value.levelMin and (value.levelMin .. (value.levelMax~=value.levelMin and ("–" .. value.levelMax) or "")) or "unknown"
        return value.category .. " • Level " .. level ..
            "\nLocations: " .. (#value.locations>0 and table.concat(value.locations,", ") or "not recorded")
    end
    local function basicText(value)
        if not value then return "" end
        return "|cffffd124" .. value.name .. "|r |cff999999[#" .. value.creatureID .. "]|r\n" .. basicDetails(value)
    end
    local function place(widget,x,y)
        widget:ClearAllPoints(); widget:SetPoint("TOPLEFT",x,-y)
    end
    local function layoutComposer()
        -- Keep short reports compact; long names, locations and rumour lists
        -- retain bounded scrolling areas instead of pushing controls off-screen.
        local headingHeight=composer.basic:GetStringHeight()
        place(composer.details,0,headingHeight+6)
        local basicHeight=headingHeight+6+composer.details:GetStringHeight()+6
        composer.basicBody:SetHeight(basicHeight)
        composer.basicArea:SetHeight(math.min(112,basicHeight))
        local y=124+composer.basicArea:GetHeight()+16
        place(composer.rumourHeading,24,y)
        y=y+composer.rumourHeading:GetStringHeight()+12
        place(composer.rumourArea,24,y)
        local rumourHeight=math.min(166,composer.rumourBody:GetHeight())
        composer.rumourArea:SetHeight(rumourHeight)
        y=y+rumourHeight+18
        place(composer.cost,24,y)
        y=y+composer.cost:GetStringHeight()+12
        place(composer.balance,24,y)
        y=y+composer.balance:GetStringHeight()+16
        place(composer.status,24,y)
        y=y+composer.status:GetStringHeight()+18
        if composer.resolve:IsShown() then
            place(composer.resolve,24,y); y=y+30
        end
        place(composer.send,24,y); place(composer.retry,160,y); place(composer.cancel,324,y)
        composer:SetHeight(y+48)
    end
    local function countChosen()
        local n=0
        for _,enabled in pairs(chosen or {}) do if enabled then n=n+1 end end
        return n
    end
    local function busy()
        return transaction and (transaction.stage=="preflight" or transaction.stage=="offering" or
            transaction.stage=="committed" or transaction.stage=="unknown")
    end
    local function buildComposer()
        if composer then return end
        composer=window("AzerothFieldbookShare","Share one creature",650,460)
        composer.afbPreferBookEdge=true
        local book=getBook and getBook()
        if book then
            composer:ClearAllPoints()
            composer:SetPoint("BOTTOMLEFT",book,"BOTTOMRIGHT",6,0)
        end
        label(composer,"Recipient character (include surname)",24,-60,260)
        composer.recipient=CreateFrame("EditBox",nil,composer,"InputBoxTemplate")
        composer.recipient:SetPoint("TOPLEFT",30,-82); composer.recipient:SetSize(390,24)
        composer.recipient:SetAutoFocus(false); composer.recipient:SetMaxLetters(100)
        composer.recipient:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        composer.basicArea,composer.basicBody=scroll(composer,24,-124,390,88)
        composer.basic=label(composer.basicBody,"",0,0,376,"GameFontNormalLarge")
        composer.basic:SetTextColor(1,0.82,0.14)
        composer.details=label(composer.basicBody,"",0,-28,376)
        composer.details:SetTextColor(0.75,0.8,0.8)
        composer.rumourHeading=label(composer,"Optional unverified rumours — 1 point each",24,-230,400,"GameFontNormal")
        composer.rumourArea,composer.rumourBody=scroll(composer,24,-255,390,166)
        composer.rows={}
        composer.empty=label(composer.rumourBody,"No eligible ability or trait records. Basic information can still be shared.",0,0,360)
        composer.cost=label(composer,"",24,-440,410,"GameFontNormal")
        composer.balance=label(composer,"",24,-466,410)
        composer.status=label(composer,"",24,-504,410)
        composer.send=button(composer,"Send offer",24,-594,125,function()
            if busy() then return end
            local claims={}
            for index,claim in ipairs(candidates or {}) do if chosen[index] then claims[#claims+1]=claim end end
            local tx,err=engine:Start(captured,composer.recipient:GetText(),claims)
            if tx then transaction=tx else composer.notice=err end
            controller:Refresh()
        end)
        composer.retry=button(composer,"Retry status",160,-594,125,function()
            local ok,err=engine:Retry()
            composer.notice=ok and nil or err
            controller:Refresh()
        end)
        composer.cancel=button(composer,"Cancel",324,-594,112,function() composer:Hide() end)
        composer.resolve=button(composer,"Close unresolved report",24,-568,230,function()
            engine:CloseUnknown(); controller:Refresh()
        end)
        composer.inbox=button(composer,"Incoming reports",296,-60,140,function() controller:OpenIncoming() end)
        composer:SetScript("OnHide",function()
            composer.recipient:ClearFocus(); composer:StopMovingOrSizing()
            if transaction and not transaction.spent then engine:Cancel() end
        end)
        composer.recipient:SetScript("OnTextChanged",function()
            composer.notice=nil
            controller:Refresh()
        end)
        if ns.WindowPositions then ns.WindowPositions:Register(composer,"AzerothFieldbookShare") end
    end
    local function buildReceiver()
        if receiver then return end
        receiver=window("AzerothFieldbookReceive","Creature report offered",570)
        receiver.from=label(receiver,"",24,-62,465,"GameFontNormal")
        receiver.area,receiver.body=scroll(receiver,24,-96,450,305)
        receiver.preview=label(receiver.body,"",0,0,436)
        receiver.status=label(receiver,"",24,-423,465)
        receiver.status:SetHeight(65)
        receiver.accept=button(receiver,"Accept — free",24,-518,145,function()
            local ok,err=engine:Accept(incoming)
            receiver.notice=ok and nil or err
            controller:Refresh()
        end)
        receiver.decline=button(receiver,"Decline",345,-518,145,function()
            engine:Decline(incoming); controller:Refresh()
        end)
        receiver:SetScript("OnHide",function()
            receiver:StopMovingOrSizing()
            if incoming and incoming.state=="pending" then engine:Decline(incoming) end
        end)
        if ns.WindowPositions then ns.WindowPositions:Register(receiver,"AzerothFieldbookReceive") end
    end
    function controller:Refresh()
        if refreshing then return end
        refreshing=true
        local brightness=journal:GetBackgroundBrightness()
        if composer then
            composer.paper:SetVertexColor(0.504*brightness,0.504*brightness,0.48888*brightness)
            local n=countChosen()
            local cost=busy() and transaction.cost or 1+n
            local basicCost=busy() and (transaction.basicCost or 1) or 1
            local available,earned,spent,reserved=journal:GetSharingBalance()
            composer.cost:SetText("Rumours: " .. n .. "   •   Basic info: " .. basicCost .. "   •   Total cost: " .. cost .. (cost==1 and " point" or " points") ..
                (busy() and transaction.spent and "" or " (maximum)"))
            composer.balance:SetText("Available: " .. available .. "   Earned: " .. earned .. "   Spent: " .. spent .. "   Reserved: " .. reserved ..
                (busy() and "" or (available>=cost and ("\nBalance after sending: " .. (available-cost)) or "\nInsufficient available points.")))
            composer.recipient:SetEnabled(not busy())
            local ready,unavailable=engine:Available()
            local blocked,restriction=engine:Blocked()
            local recipient=composer.recipient:GetText()
            local _,recipientError=engine:ValidateRecipient(recipient)
            local disabled
            if not captured then disabled=composer.notice or "Select a creature with valid basic information."
            elseif busy() or engine:HasActiveOutgoing() then disabled=transaction and transaction.message or "An outgoing report is already active. Reopen Share to view its status."
            elseif not ready then disabled=unavailable or "Addon messaging is unavailable."
            elseif blocked then disabled=restriction or "Sharing is available outside combat and messaging restrictions."
            elseif recipient~="" and recipientError then disabled=recipientError
            elseif available<cost then disabled="Insufficient points: this report needs " .. cost .. " available " .. (cost==1 and "point" or "points") .. "; you have " .. available .. "." end
            composer.send:SetEnabled(disabled==nil)
            composer.retry:SetShown(transaction and transaction.spent and transaction.stage=="unknown" or false)
            composer.retry:SetEnabled(engine:CanRetry()==true and not engine:Blocked())
            composer.resolve:SetShown(transaction and transaction.stage=="unknown" and not engine:CanRetry() or false)
            composer.cancel:SetText(busy() and not transaction.spent and "Cancel offer" or "Close")
            local status=disabled or composer.notice or (transaction and transaction.message)
                or "Reserve on Send. Spend only after acceptance. A missing acknowledgement leaves delivery unknown."
            local remaining=engine:GetPreflightSecondsRemaining()
            if remaining then
                status="Checking compatibility with " .. engine:GetOutgoing().recipient .. " (" .. remaining .. "s remaining). Points reserved; none spent."
            end
            if transaction and transaction.basicInfoWaived then
                status=status .. " Basic information already known by " .. transaction.recipient ..
                    "; its 1-point cost was waived. This report cost " .. transaction.cost .. (transaction.cost==1 and " point." or " points.")
            end
            composer.status:SetText(status)
            composer.inbox:SetShown(#engine:GetIncoming()>0)
            for index,row in ipairs(composer.rows) do
                row:SetChecked(chosen and chosen[index]==true)
                row:SetEnabled(not busy())
            end
            layoutComposer()
        end
        local list=engine:GetIncoming()
        local exists=false
        for _,item in ipairs(list) do if incoming==item then exists=true end end
        if not exists then
            incoming=list[1]
            if incoming then
                buildReceiver(); receiver.notice=nil; receiver.area:SetVerticalScroll(0); receiver:Show()
            elseif receiver then receiver:Hide() end
        end
        if incoming and receiver then
            receiver.paper:SetVertexColor(0.504*brightness,0.504*brightness,0.48888*brightness)
            local value=incoming.report
            local preview,err=journal:PreviewReport(value,incoming.sender)
            receiver.from:SetText("Offered by " .. incoming.sender)
            local lines={basicText(value),"",#value.rumours .. " unverified rumour(s):"}
            for _,claim in ipairs(value.rumours) do
                local text=schema.ClaimText(claim) .. "\nReported by " .. incoming.sender
                if journal:WasRumourRejected(value.creatureID,claim) then text=text .. "\n|cffffb347Previously rejected|r" end
                if journal:IsRumourKnown(value.creatureID,claim) then text=text .. "\nAlready in your journal" end
                lines[#lines+1]=text
            end
            if #value.rumours==0 then lines[#lines+1]="Basic information only." end
            lines[#lines+1]="\n" .. (preview and (preview.newInformation and "Adds new information or a separately attributed claim."
                or "No new creature information or rumours; this records the offering source.") or err)
            if preview and preview.conflict then lines[#lines+1]="Names/types differ. Your local information wins; the report stays separate." end
            if preview and preview.locked then lines[#lines+1]="Locked page: local metadata and traits stay locked. See received basics and rumours in Rumours." end
            if preview and not preview.newBasic then lines[#lines+1]="You already have the basic information; the sender's 1-point basic-information cost will be waived." end
            lines[#lines+1]="\nThe character offering this report is identified by the addon-message sender. Its claims remain unverified. Receiving earns no points."
            receiver.preview:SetText(table.concat(lines,"\n"))
            receiver.body:SetHeight(math.max(305,(receiver.preview:GetStringHeight() or 305)+16))
            local pending=incoming.state=="pending"
            receiver.accept:SetEnabled(pending and preview~=nil and not engine:Blocked())
            receiver.decline:SetEnabled(pending)
            receiver.status:SetText(receiver.notice or (pending and "Accept to add this report. Declining or closing this offer is free."
                or "Accepted; waiting for the sender's commit. You can close this window. No information is imported yet."))
        end
        refreshing=false
    end
    function controller:OpenIncoming()
        incoming=nil; self:Refresh()
        if receiver and #engine:GetIncoming()>0 then receiver:Show() end
    end
    function controller:Open(id)
        buildComposer()
        transaction=engine:GetOutgoing()
        if busy() then
            composer.notice=nil
            captured=schema.Decode(transaction.payload)
            candidates=captured.rumours; chosen={}
            for i=1,#candidates do chosen[i]=true end
            composer.recipient:SetText(transaction.recipient)
        else
            transaction=nil
            local result,choices=schema.Capture(journal,id)
            captured,candidates,chosen=result,result and choices or {},{}
            if result then composer.notice=nil else composer.notice=choices end
        end
        composer.basic:SetText(captured and (captured.name .. " |cff999999[#" .. captured.creatureID .. "]|r") or "Unable to share this entry.")
        composer.details:SetText(basicDetails(captured))
        composer.basicArea:SetVerticalScroll(0); composer.rumourArea:SetVerticalScroll(0)
        composer.empty:SetShown(#candidates==0)
        local y,rowHeight=0,0
        local columnGap=8
        local columnWidth=(composer.rumourBody:GetWidth()-columnGap)/2
        for index,claim in ipairs(candidates) do
            local row=composer.rows[index]
            if not row then
                row=CreateFrame("CheckButton",nil,composer.rumourBody,"UICheckButtonTemplate")
                row:SetSize(24,24)
                -- Align the check mark with the first line's centre, including
                -- when a longer claim wraps onto additional lines.
                row.text=label(row,"",28,-8,columnWidth-28)
                composer.rows[index]=row
                row:SetScript("OnClick",function(self)
                    if busy() then return end
                    chosen[index]=not chosen[index]
                    composer.notice=nil; controller:Refresh()
                end)
            end
            local column=(index-1)%2
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",column*(columnWidth+columnGap),-y)
            row.text:SetText(schema.ClaimText(claim))
            rowHeight=math.max(rowHeight,30,(row.text:GetStringHeight() or 26)+16)
            if column==1 or index==#candidates then y=y+rowHeight; rowHeight=0 end
            row:Show()
        end
        for i=#candidates+1,#composer.rows do composer.rows[i]:Hide() end
        composer.rumourBody:SetHeight(#candidates==0 and composer.empty:GetStringHeight()+8 or math.max(30,y))
        composer:Show(); self:Refresh()
    end
    engine:SetChangedCallback(function(reason)
        if reason=="reset" then
            captured,candidates,chosen,transaction,incoming=nil,{}, {},nil,nil
            if composer then composer.notice="Journal reset; reopen Share to select a creature."; composer:Hide() end
            if receiver then receiver:Hide() end
        end
        controller:Refresh()
    end)
    -- Refresh controls as combat state and personal earnings change, even if
    -- the book is closed while the composer or receipt window remains open.
    local updater=CreateFrame("Frame")
    local elapsed=0
    updater:SetScript("OnUpdate",function(_,delta)
        elapsed=elapsed+delta
        if elapsed>=1 then elapsed=0; controller:Refresh() end
    end)
    return controller
end
