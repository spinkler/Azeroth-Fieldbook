local _,ns=...
local data,report=ns.BestiaryComparison,ns.SharingReport
local PAGE=5

local function targetName(engine)
    if not engine.comparison:Available() or type(UnitIsPlayer)~="function" then return end
    local function readable(fn,...)
        if type(fn)~="function" then return end
        local ok,value=pcall(fn,...)
        return ok and report.Public(value) and value==true
    end
    if not readable(UnitIsPlayer,"target") or (UnitCanCooperate and not readable(UnitCanCooperate,"player","target"))
        or (UnitIsConnected and not readable(UnitIsConnected,"target")) then return end
    return engine:ValidateRecipient(report.UnitCharacter("target"))
end

local function describe(entry)
    if not entry then return "No entry" end
    local text=entry.basic and "Basics" or "Entry"
    if #entry.claims>0 then text=text.." · "..#entry.claims..(#entry.claims==1 and " trait" or " traits") end
    if entry.heldRumours>0 then text=text.." · "..entry.heldRumours..(entry.heldRumours==1 and " rumour" or " rumours") end
    return text..(entry.mark and " · Lore" or "")
end
local function differences(quote)
    local parts={}
    if quote.basic then parts[#parts+1]="basics" end
    if #quote.indices>0 then parts[#parts+1]=#quote.indices..(#quote.indices==1 and " trait" or " traits") end
    if quote.lore then parts[#parts+1]="Lore" end
    return table.concat(parts," + ")
end
local function detail(entry,quote,verb,other)
    if not entry then return "No entry in this Bestiary." end
    local lines={entry.name.."  #"..entry.id}
    local basic=entry.basic
    if basic then
        local level=basic.levelMin and (basic.levelMin..(basic.levelMax~=basic.levelMin and ("–"..basic.levelMax) or "")) or "unknown"
        local otherBasic=other and other.basic
        if quote.basic and basic.levelMin and otherBasic and otherBasic.levelMin
            and (basic.levelMin<otherBasic.levelMin or basic.levelMax>otherBasic.levelMax) then level=level.." (extends range)" end
        lines[#lines+1]=basic.category.." · Level "..level
        local known,locations={},{}
        for _,place in ipairs(otherBasic and otherBasic.locations or {}) do known[place]=true end
        for i,place in ipairs(basic.locations) do
            locations[i]=quote.basic and otherBasic and not known[place] and (place.." |cffffd124(new)|r") or place
        end
        lines[#lines+1]=#locations>0 and table.concat(locations,", ") or "No recorded locations"
    end
    if quote.unavailable then lines[#lines+1]="This bundle exceeds a report or storage limit. Use Share to review a smaller report." end
    if entry.heldRumours>0 then
        lines[#lines+1]=entry.heldRumours..(entry.heldRumours==1 and " unverified rumour" or " unverified rumours").." held for review."
    end
    lines[#lines+1]=""
    if quote.regular then
        lines[#lines+1]=string.format("%s for %d knowledge",verb,quote.cost)
        lines[#lines+1]=string.format("(%d basic + %d rumours) × %s, rounded down",quote.basic and 1 or 0,#quote.indices,entry.multiplier)
        lines[#lines+1]=quote.basic and "Adds basic information." or "Basic information is covered when this report arrives."
    end
    if entry.mark then
        local state=quote.lore and " · included for free" or other and other.mark==entry.mark and " · both have this observation"
            or other and other.personalLore and " · recipient keeps their own observation" or " · not selected for transfer"
        lines[#lines+1]=(entry.personalLore and "Observed Beast Lore" or "Shared Beast Lore")..state
    end
    if #entry.claims>0 then
        lines[#lines+1]=""
        local wanted={}
        for _,index in ipairs(quote.indices) do wanted[index]=true end
        for i,claim in ipairs(entry.claims) do
            lines[#lines+1]=report.ClaimText(claim).."  "..(quote.unavailable and "" or
                (wanted[i] and ("|cffffd124"..verb.."|r") or "|cff98aba8Already held|r"))
        end
    end
    return table.concat(lines,"\n")
end
local function totals(plan)
    return string.format("Basics %d  +  Rumours %d  +  Rank %d\n",plan.basics,plan.traits,plan.cost-plan.basics-plan.traits)..
        plan.entries..(plan.entries==1 and " entry" or " entries").." · Beast Lore "..plan.lore.." (free)"
end

function ns.CreateComparisonWindow(journal,engine,ui)
    local comparison,controller=engine.comparison,{}
    local frame,visibility,detailRow,filtered,filterSource,filterText,filterDiff
    local page,onlyDiff,reviewAll=1,false,false
    local refresh
    local function edit(parent,x,y,width)
        local box=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
        if ns.TextSize then ns.TextSize:StyleControl(box) end
        box:SetPoint("TOPLEFT",x,y);box:SetSize(width,24);box:SetAutoFocus(false);box:SetMaxLetters(100)
        box:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        return box
    end
    local function pane(parent)
        local p=CreateFrame("Frame",nil,parent);p:SetAllPoints();return p
    end
    local function invite()
        local ok,why=comparison:Invite(frame.nameBox:GetText())
        frame.notice=not ok and why or nil
        frame.nameBox:ClearFocus();refresh()
    end
    local function act()
        local session=comparison.session
        if not session then invite()
        elseif session.stage=="invited" then comparison:AcceptInvitation()
        elseif session.stage=="done" or session.stage=="closed" then
            local peer=session.peer
            comparison.session=nil;detailRow=nil;frame.notice=nil;page=1;onlyDiff=false;reviewAll=false;frame.search:SetText("")
            frame.nameBox:SetText(peer);refresh()
        else
            local ok,why=comparison:Approve()
            frame.notice=not ok and why or nil
            if ok then page=1;detailRow=nil;reviewAll=false;frame.search:SetText("") end
            refresh()
        end
    end
    local function cell(row,x,direction)
        local check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
        check:SetPoint("TOPLEFT",x,-8);check:SetSize(24,24)
        check:SetHitRectInsets(0,-208,-4,-9)
        check:SetScript("OnClick",function()
            if row.record then comparison:Select(direction,row.record.id,not comparison.session[direction][row.record.id]) end
        end)
        local owner=ui.label(row,"",x+28,-2,210,"GameFontHighlightSmall")
        local offer=ui.label(row,"",x+28,-21,214)
        owner:SetMaxLines(1);offer:SetMaxLines(1)
        return {check=check,owner=owner,offer=offer}
    end
    local function build()
        if frame then return end
        frame=ui.window("AzerothFieldbookCompare","Compare Bestiaries",606,784)
        frame.intro=pane(frame)
        frame.introText=ui.label(frame.intro,"",24,-58,406,"GameFontHighlight")
        frame.nameBox=edit(frame.intro,30,-118,388)
        frame.nameBox:SetScript("OnEnterPressed",invite)
        frame.nameBox:SetScript("OnTextChanged",function() frame.notice=nil;refresh() end)
        frame.introStatus=ui.label(frame.intro,"",24,-154,406)
        frame.list=pane(frame)
        frame.search=ns.FieldbookUI.Search(frame.list,26,-61,184,100)
        frame.search.placeholder:SetText("Find a creature")
        frame.search:HookScript("OnTextChanged",function() page=1;refresh() end)
        frame.filter=ui.button(frame.list,"All entries",236,-61,150,function()
            if comparison.session.stage=="ready" then onlyDiff=not onlyDiff else reviewAll=not reviewAll end
            page=1;refresh()
        end)
        frame.prev=ui.button(frame.list,"Previous",487,-61,86,function() page=page-1;refresh() end)
        frame.page=ui.label(frame.list,"",578,-67,88);frame.page:SetJustifyH("CENTER")
        frame.next=ui.button(frame.list,"Next",674,-61,84,function() page=page+1;refresh() end)
        ui.label(frame.list,"Creature",24,-107,170,"GameFontNormal")
        frame.mine=ui.label(frame.list,"You",212,-101,251,"GameFontNormal")
        frame.theirs=ui.label(frame.list,"",484,-101,274,"GameFontNormal")
        frame.mine:SetMaxLines(1);frame.theirs:SetMaxLines(1)
        local function bulk(direction)
            comparison:Select(direction,nil,not frame[direction].all,filtered)
        end
        frame.give=ui.button(frame.list,"Select all to send",212,-127,216,function() bulk("give") end)
        frame.take=ui.button(frame.list,"Select all to receive",484,-127,230,function() bulk("take") end)
        frame.rows={}
        for i=1,PAGE do
            local row=CreateFrame("Frame",nil,frame.list)
            row:SetPoint("TOPLEFT",24,-163-(i-1)*49);row:SetSize(732,48)
            row.line=row:CreateTexture(nil,"BACKGROUND")
            row.line:SetPoint("BOTTOMLEFT");row.line:SetPoint("BOTTOMRIGHT");row.line:SetHeight(1)
            row.line:SetColorTexture(0.73,0.62,0.44,0.28)
            row.inspect=ui.button(row,"",0,-3,170,function()
                detailRow=row.record;frame.detailArea:SetVerticalScroll(0);refresh()
            end)
            row.inspect:SetHeight(36)
            local name=row.inspect:GetFontString()
            name:SetWidth(156);name:SetWordWrap(true);name:SetMaxLines(2)
            row.give=cell(row,185,"give");row.take=cell(row,457,"take")
            frame.rows[i]=row
        end
        frame.empty=ui.label(frame.list,"",24,-190,728)
        frame.detail=pane(frame)
        frame.back=ui.button(frame.detail,"Back to entries",24,-60,156,function() detailRow=nil;refresh() end)
        frame.detailHeading=ui.label(frame.detail,"",202,-64,554,"GameFontNormal")
        frame.detailMine=ui.label(frame.detail,"You",24,-105,345,"GameFontNormal")
        frame.detailTheirs=ui.label(frame.detail,"",397,-105,349,"GameFontNormal")
        frame.detailTheirs:SetMaxLines(1);frame.detailHeading:SetMaxLines(2)
        frame.detailArea,frame.detailBody=ui.scroll(frame.detail,24,-135,710,267)
        frame.left=ui.label(frame.detailBody,"",0,0,336)
        frame.right=ui.label(frame.detailBody,"",373,0,326)
        frame.summary=pane(frame)
        frame.youPay=ui.label(frame.summary,"",24,-420,352,"GameFontNormal")
        frame.theyPay=ui.label(frame.summary,"",397,-420,360,"GameFontNormal")
        frame.yourBreakdown=ui.label(frame.summary,"",24,-451,352)
        frame.theirBreakdown=ui.label(frame.summary,"",397,-451,360)
        frame.status=ui.label(frame.summary,"",24,-517,732,"GameFontHighlight")
        frame.action=ui.button(frame,"",24,-560,202,act)
        frame.dismiss=ui.button(frame,"Close",604,-560,152,function() frame:Hide() end)
        frame:SetScript("OnHide",function()
            frame.nameBox:ClearFocus();frame.search:ClearFocus();frame:StopMovingOrSizing()
            local session=comparison.session
            comparison:Close(session and (session.stage=="invited" or session.stage=="review") and "declined" or "closed")
            comparison.session=nil;detailRow,filtered,filterSource=nil,nil,nil
            if visibility then visibility(false) end
        end)
        frame:HookScript("OnShow",function() if visibility then visibility(true) end end)
        local elapsed=0
        frame:SetScript("OnUpdate",function(_,delta)
            elapsed=elapsed+delta
            if elapsed>=1 then elapsed=0;refresh() end
        end)
        if ns.WindowPositions then ns.WindowPositions:Register(frame,"AzerothFieldbookCompare") end
    end
    local function showCell(widget,entry,quote,chosen,editable,verb)
        widget.owner:SetText(describe(entry))
        local possible=data.CanSelect(quote)
        widget.check:SetShown(possible==true)
        widget.check:SetChecked(chosen==true);widget.check:SetEnabled(editable)
        if possible then
            widget.offer:SetText(verb.." · "..quote.cost.." KP · "..differences(quote))
            if verb=="Send" then widget.offer:SetTextColor(0.55,0.84,1)
            else widget.offer:SetTextColor(0.96,0.79,0.47) end
        else
            widget.offer:SetText(quote and (quote.unavailable and "Report unavailable" or "Up to date") or "")
            widget.offer:SetTextColor(0.7,0.72,0.7)
        end
    end
    local function showList(session)
        local query=frame.search:GetText():lower()
        local editable=session.stage=="ready"
        local filter=editable and (onlyDiff and "differences" or "all") or (reviewAll and "all" or "selected")
        if filterSource~=session.rows or filterText~=query or filterDiff~=filter then
            filterSource,filterText,filterDiff=session.rows,query,filter
            filtered={}
            for _,row in ipairs(session.rows) do
                local visible=filter=="all" or (filter=="differences" and (data.CanSelect(row.give) or data.CanSelect(row.take)))
                    or (filter=="selected" and (session.give[row.id] or session.take[row.id]))
                if visible and (row.name:lower():find(query,1,true) or tostring(row.id)==query or
                    (row.theirs and row.theirs.name:lower():find(query,1,true))) then filtered[#filtered+1]=row end
            end
        end
        local pages=math.max(1,math.ceil(#filtered/PAGE))
        page=math.max(1,math.min(page,pages))
        frame.prev:SetEnabled(page>1);frame.next:SetEnabled(page<pages);frame.page:SetText(page.." / "..pages)
        frame.filter:SetText(filter~="all" and "Show all entries" or editable and "Differences only" or "Selected only")
        frame.theirs:SetText(session.peer)
        for _,direction in ipairs({"give","take"}) do
            local all,any=true,false
            for _,row in ipairs(filtered) do
                if data.CanSelect(row[direction]) then
                    any=true
                    if not session[direction][row.id] then all=false;break end
                end
            end
            local control=frame[direction]
            control.all=any and all
            control:SetEnabled(editable and any)
            control:SetText((control.all and "Clear all to " or "Select all to ")..(direction=="give" and "send" or "receive"))
            if not editable then
                control:SetText(direction=="give" and ("Sending · "..session.outgoing.entries) or ("Receiving · "..session.incoming.entries))
            end
        end
        for i,row in ipairs(frame.rows) do
            local record=filtered[(page-1)*PAGE+i]
            row.record=record;row:SetShown(record~=nil)
            if record then
                row.inspect:SetText(record.name)
                showCell(row.give,record.mine,record.give,session.give[record.id],editable,"Send")
                showCell(row.take,record.theirs,record.take,session.take[record.id],editable,"Receive")
            end
        end
        frame.empty:SetShown(#filtered==0)
        frame.empty:SetText(#session.rows==0 and "Both Bestiaries are empty." or "No entries match this view.")
    end
    local function position(control,x,y) control:ClearAllPoints();control:SetPoint("TOPLEFT",x,y) end
    refresh=function()
        if not frame or not frame:IsShown() then return end
        ui.appearance(frame)
        local session=comparison.session
        local stage=session and session.stage
        local full=session and session.rows~=nil
        if frame.fullSize~=(full==true) then
            frame.fullSize=full==true;frame:SetSize(full and 784 or 458,full and 606 or 248)
            if ns.WindowPositions then ns.WindowPositions:AvoidWindowOverlap(frame) end
        end
        frame.intro:SetShown(not full);frame.list:SetShown(full and not detailRow or false)
        frame.detail:SetShown(full and detailRow~=nil or false);frame.summary:SetShown(full==true)
        position(frame.action,24,full and -560 or -202)
        position(frame.dismiss,full and 604 or 284,full and -560 or -202)
        frame.dismiss:SetText((stage=="invited" or stage=="review") and "Decline" or stage=="exchanging" and "Stop exchange" or "Close")
        local label,enabled,status
        if full then
            if detailRow then
                frame.detailHeading:SetText(detailRow.name.."  #"..detailRow.id)
                frame.detailTheirs:SetText(session.peer)
                frame.left:SetText(detail(detailRow.mine,detailRow.give,"Send",detailRow.theirs))
                frame.right:SetText(detail(detailRow.theirs,detailRow.take,"Receive",detailRow.mine))
                frame.detailBody:SetHeight(math.max(267,frame.left:GetStringHeight()+8,frame.right:GetStringHeight()+8))
                frame.detailArea:UpdateScrollChildRect();frame.detailArea:RefreshScrollBar()
            else showList(session) end
            local a,b=session.outgoing,session.incoming
            frame.youPay:SetText("You spend "..a.cost.." knowledge")
            frame.theyPay:SetText("They spend "..b.cost.." knowledge")
            frame.yourBreakdown:SetText(totals(a).."\n"..journal:GetSharingBalance().." available · "..a.required.." needed to reserve")
            frame.theirBreakdown:SetText(totals(b).."\n"..b.required.." needed to reserve · receiving is free")
            if stage=="ready" or stage=="review" then
                label=stage=="review" and "Accept exchange" or "Propose exchange"
                local why
                enabled,why=comparison:CanApprove()
                status=stage=="review" and "Review the checked entries and both costs before accepting."
                    or "Choose what to send and receive. Select a creature name for its facts and price."
                if why and a.entries+b.entries>0 then status=why end
            elseif stage=="proposed" then status="Waiting for "..session.peer.." to approve this exchange."
            elseif stage=="exchanging" then
                status=string.format("Delivered %d / %d outgoing reports · Received %d / %d · You spent %d knowledge",
                    session.sent,#a.jobs,session.received,#b.jobs,session.spent+(session.tx and session.tx.spent and session.tx.cost or 0))
            elseif stage=="done" or stage=="closed" then
                label,enabled="Compare again",true
                status=(stage=="done" and "Exchange complete." or session.message)..
                    string.format(" Sent %d · Received %d · You spent %d knowledge.",session.sent,session.received,session.spent)
                frame.youPay:SetText("You spent "..session.spent.." knowledge")
                frame.theyPay:SetText("Received reports cost "..session.peerSpent.." knowledge")
                frame.yourBreakdown:SetText("Selection · "..a.cost.." knowledge\n"..totals(a))
                frame.theirBreakdown:SetText("Selection · "..b.cost.." knowledge\n"..totals(b))
            end
            frame.status:SetText(frame.notice or status or "")
        else
            frame.nameBox:SetShown(not session)
            if not session then
                frame.introText:SetText("Invite a player to compare Bestiaries. Enter their full character name, including surname.")
                label="Invite to compare"
                local ready,why=comparison:Available()
                enabled=ready and engine:ValidateRecipient(frame.nameBox:GetText())~=nil and not engine:HasActiveOutgoing()
                status=frame.notice or why or (engine:HasActiveOutgoing() and "Finish your outgoing report in Share first.")
                    or "Both players review the selection and costs before sharing."
            elseif stage=="invited" then
                frame.introText:SetText(session.peer.." would like to compare Bestiaries.")
                status="Comparing shows creature basics, shareable traits and Beast Lore availability. You approve any exchange separately."
                label,enabled="Compare books",comparison:Available()
            elseif stage=="closed" then
                frame.introText:SetText("Comparison with "..session.peer)
                status=session.message;label,enabled="Compare again",true
            else
                frame.introText:SetText("Comparing with "..session.peer)
                status=stage=="inviting" and "Waiting for an invitation reply. Both players need a compatible build."
                    or string.format("Comparing creature catalogues… %d%% sent · %d%% received",session.sentPercent or 0,session.syncPercent or 0)
            end
            position(frame.introStatus,24,session and -math.max(106,68+frame.introText:GetStringHeight()) or -154)
            frame.introStatus:SetText(status or "")
        end
        frame.action:SetShown(label~=nil);frame.action:SetText(label or "");frame.action:SetEnabled(enabled==true)
    end
    function controller:Open(peer,inviteNow)
        build()
        if not comparison:Active() then
            comparison.session=nil;detailRow=nil;page=1;onlyDiff=false;reviewAll=false;frame.notice=nil
            frame.search:SetText("");frame.nameBox:SetText(peer or targetName(engine) or "")
        end
        frame:Show();refresh()
        if inviteNow and not comparison:Active() then invite() end
    end
    function controller:Hide() if frame and frame:IsShown() then frame:Hide() end end
    function controller:SetVisibilityCallback(fn) visibility=fn;fn(frame~=nil and frame:IsShown()) end
    comparison:SetChangedCallback(function(open)
        if open then
            build()
            if comparison.session.stage=="invited" or comparison.session.stage=="review" then
                detailRow=nil;page=1;onlyDiff=false;reviewAll=false;filterSource=nil;frame.search:SetText("")
            end
            frame.notice=nil;frame:Show()
        end
        refresh()
    end)
    local function attach()
        if not Menu or type(Menu.ModifyMenu)~="function" then return end
        local function add(_,root,context)
            if not report.Public(context) or type(context)~="table" or not report.Public(context.unit) or context.unit~="target" then return end
            local peer=targetName(engine)
            if not peer or engine:HasActiveOutgoing() or (comparison:Active() and not report.SameCharacter(peer,comparison.session.peer)) then return end
            root:CreateButton("Compare Bestiaries",function()
                if report.SameCharacter(peer,targetName(engine)) then controller:Open(peer,true) end
            end)
        end
        for _,tag in ipairs({"PLAYER","PARTY","RAID_PLAYER","TARGET"}) do Menu.ModifyMenu("MENU_UNIT_"..tag,add) end
        return true
    end
    if not attach() then
        local loader=CreateFrame("Frame")
        loader:RegisterEvent("ADDON_LOADED")
        loader:SetScript("OnEvent",function() if attach() then loader:UnregisterEvent("ADDON_LOADED") end end)
    end
    return controller
end
