local _, ns = ...

function ns.CreateBackupWindow(journal, ui, onRestored)
    local data=ns.BestiaryBackups
    local frame,body,selected,mode,loading
    local controller={}
    local refresh
    local scope=journal:IsAccountWideTrackingActive() and "account-wide" or "character"
    local function summary(snapshot)
        local creatures,abilities,notes=data.Summary(snapshot)
        return data.Date(snapshot).."\n"..creatures.." creatures • "..abilities.." abilities • "..notes.." creature notes"
            .."\n"..(snapshot.scope=="account" and "Account-wide" or "Character").." backup"
            ..(snapshot.character and (" • "..snapshot.character) or "").." • v"..snapshot.addonVersion
    end
    local function status(text,problem)
        frame.status:SetText(text or "")
        frame.status:SetTextColor(problem and 1 or 0.75,problem and 0.4 or 0.8,problem and 0.3 or 0.8)
    end
    local function setMode(nextMode)
        mode=nextMode
        if mode=="import" then selected=nil;loading=true;frame.text:SetText("");loading=false end
        if mode=="export" then
            local encoded,err
            if selected then encoded,err=data.Encode(selected) end
            if not encoded then status(err or "Select a backup first.",true);mode="list"
            else loading=true;frame.text:SetText(encoded);loading=false end
        end
        refresh()
        if mode=="export" then frame.text:SetFocus();frame.text:HighlightText()
        elseif mode=="import" then frame.text:SetFocus() else frame.text:ClearFocus() end
    end
    local function build()
        if frame then return end
        frame,body=ui.page("AzerothFieldbookBackups","Bestiary backups",58)
        controller.frame=frame
        frame.afbPreferBookEdge=true;frame.afbAnchorRule="pages"
        ui.label(body,"Your "..scope.." Bestiary • Five recent backups and one recovery copy",30,0,530,"GameFontHighlightSmall")
        frame.status=ui.label(body,"",30,-25,530,"GameFontHighlightSmall")
        frame.savedButton=ui.button(body,"Saved backups",30,-78,160,function() status("");setMode("list") end)
        frame.importButton=ui.button(body,"Import a backup",204,-78,160,function() status("");setMode("import") end)
        frame.exportButton=ui.button(body,"Export selected",378,-78,160,function() setMode("export") end)
        frame.rows={}
        for index=1,data.MAX_SAVED+1 do
            local row=CreateFrame("Button",nil,body)
            row:SetPoint("TOPLEFT",30,-114-(index-1)*36);row:SetSize(508,32)
            row.text=ui.label(row,"",8,-8,494,"GameFontHighlightSmall")
            row.highlight=row:CreateTexture(nil,"BACKGROUND")
            row.highlight:SetAllPoints();row.highlight:SetColorTexture(1,0.72,0.15,0.12)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row:SetScript("OnClick",function(self) selected=self.snapshot;refresh() end)
            frame.rows[index]=row
        end
        frame.empty=ui.label(body,"No backups yet. Use Backup Bestiary in Options, or import a copy saved outside the game.",30,-120,510,"GameFontHighlightSmall")
        frame.instructions=ui.label(body,"",30,-114,510,"GameFontHighlightSmall")
        frame.textBorder=CreateFrame("Frame",nil,body,"BackdropTemplate")
        frame.textBorder:SetPoint("TOPLEFT",30,-162);frame.textBorder:SetSize(508,168)
        frame.textBorder:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10})
        frame.textBorder:SetBackdropColor(0.035,0.025,0.015,0.85)
        frame.textBorder:SetBackdropBorderColor(0.55,0.40,0.20,1)
        frame.textScroll=CreateFrame("ScrollFrame",nil,frame.textBorder,"UIPanelScrollFrameTemplate")
        frame.textScroll:SetPoint("TOPLEFT",8,-8);frame.textScroll:SetPoint("BOTTOMRIGHT",-30,8)
        frame.text=CreateFrame("EditBox",nil,frame.textScroll)
        frame.text:SetMultiLine(true);frame.text:SetAutoFocus(false);frame.text:SetFontObject("GameFontHighlightSmall")
        frame.text:SetWidth(464);frame.text:SetHeight(152);frame.text:SetMaxLetters(data.MAX_BYTES+1)
        frame.textScroll:SetScrollChild(frame.text);ns.AutoHideScrollBar(frame.textScroll)
        local bar=frame.textScroll.ScrollBar
        if bar and type(bar)~="function" then
            local track=bar:CreateTexture(nil,"BACKGROUND")
            track:SetAllPoints();track:SetColorTexture(0.045,0.032,0.018,0.9)
        end
        frame.text:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        frame.text:SetScript("OnTextChanged",function(self,userInput)
            if loading then return end
            if mode=="import" then
                selected=nil;frame.preview:SetText("Preview the pasted backup before restoring.")
                frame.restoreButton:SetEnabled(false);frame.exportButton:SetEnabled(false)
                status("")
            elseif userInput then status("Export text was edited. Click Export selected to prepare a fresh copy.",true) end
        end)
        frame.text:SetScript("OnCursorChanged",function(_,_,y,_,height)
            local top,offset=-y,frame.textScroll:GetVerticalScroll()
            if top<offset then frame.textScroll:SetVerticalScroll(math.max(0,top))
            elseif top+height>offset+152 then frame.textScroll:SetVerticalScroll(math.max(0,top+height-152)) end
        end)
        frame.previewButton=ui.button(body,"Preview import",30,-342,160,function()
            local snapshot,err=data.Decode(frame.text:GetText())
            selected=snapshot
            status(snapshot and "Backup checked. Review the details below before restoring." or err,not snapshot)
            refresh()
        end)
        frame.selectAll=ui.button(body,"Select all text",30,-342,160,function() frame.text:SetFocus();frame.text:HighlightText() end)
        frame.preview=ui.label(body,"",30,-386,510,"GameFontHighlightSmall")
        frame.notice=ui.label(body,"",30,0,510,"GameFontHighlightSmall")
        frame.notice:SetTextColor(0.6,0.6,0.6)
        frame.restoreButton=ui.button(frame,"Restore this backup",30,0,190,function()
            if selected and StaticPopup_Show then
                StaticPopup_Show("AZEROTHFIELDBOOK_RESTORE_CONFIRM",summary(selected).."\n\nReplace your "..scope
                    .." creature records with this backup? Your current records will be saved as a recovery copy.",nil,selected)
            end
        end)
        frame.restoreButton:ClearAllPoints();frame.restoreButton:SetPoint("BOTTOMLEFT",30,20)
        local close=ui.button(frame,"Close",420,0,118,function() frame:Hide() end)
        close:ClearAllPoints();close:SetPoint("BOTTOMRIGHT",-72,20)
        if type(StaticPopupDialogs)=="table" then
            StaticPopupDialogs.AZEROTHFIELDBOOK_RESTORE_CONFIRM={
                text="%s",button1="Restore",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
                OnAccept=function(_,snapshot)
                    local ok,err=journal:RestoreBackup(snapshot)
                    if ok then
                        selected=nil;mode="list"
                        onRestored()
                        status("Bestiary restored. Select Before last restore to recover your previous records.")
                    else status(err,true) end
                    refresh()
                end,
            }
        end
        frame:HookScript("OnHide",function()
            frame.text:ClearFocus();loading=true;frame.text:SetText("");loading=false
            if StaticPopup_Hide then StaticPopup_Hide("AZEROTHFIELDBOOK_RESTORE_CONFIRM") end
        end)
        frame:SetScript("OnShow",function() refresh() end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookBackups" end
        if ns.UIScale then ns.UIScale:Register(frame,"AzerothFieldbookBackups")
        elseif ns.WindowPositions then ns.WindowPositions:Register(frame,"AzerothFieldbookBackups") end
        frame:Hide()
    end
    refresh=function()
        local archive=journal:GetBackups()
        local list={}
        if archive.recovery then list[#list+1]={snapshot=archive.recovery,recovery=true} end
        for _,snapshot in ipairs(archive.saved) do list[#list+1]={snapshot=snapshot} end
        if mode=="list" then
            local found=false
            for _,item in ipairs(list) do if item.snapshot==selected then found=true;break end end
            if not found then selected=list[1] and list[1].snapshot end
        end
        for index,row in ipairs(frame.rows) do
            local item=list[index]
            row:SetShown(mode=="list" and item~=nil)
            if item then
                row.snapshot=item.snapshot
                row.text:SetText((item.recovery and "Before last restore • " or "")..data.Date(item.snapshot)
                    .." • "..data.Summary(item.snapshot).." creatures")
                local chosen=selected==item.snapshot
                row.text:SetTextColor(chosen and 1 or 0.75,chosen and 0.82 or 0.8,chosen and 0.14 or 0.8)
                row.highlight:SetShown(chosen)
            end
        end
        local code=mode=="import" or mode=="export"
        frame.empty:SetShown(mode=="list" and #list==0)
        frame.instructions:SetShown(code);frame.textBorder:SetShown(code)
        frame.previewButton:SetShown(mode=="import");frame.selectAll:SetShown(mode=="export")
        frame.instructions:SetText(mode=="import" and "Paste the complete backup below (Ctrl+V), then click Preview import. Nothing changes until you confirm Restore."
            or "Press Ctrl+C to copy the selected text, then paste it into a text document and save it. The copy includes your personal creature notes.")
        frame.exportButton:SetEnabled(selected~=nil)
        frame.restoreButton:SetEnabled(selected~=nil and mode~="export")
        local y=code and 386 or (114+math.max(1,#list)*36+14)
        frame.preview:ClearAllPoints();frame.preview:SetPoint("TOPLEFT",30,-y)
        frame.preview:SetText(selected and summary(selected) or (mode=="import" and "Preview the pasted backup before restoring." or ""))
        y=y+frame.preview:GetStringHeight()+16
        frame.notice:ClearAllPoints();frame.notice:SetPoint("TOPLEFT",30,-y)
        frame.notice:SetText("Restore replaces creature records. Earned milestones and knowledge spending are preserved; settings, Event log and active offers stay current.\n\nIn-game backups share the addon's saved files. Export a separate copy for protection if those files are lost. Log out or reload normally to save in-game backups to disk.")
        local height=y+frame.notice:GetStringHeight()+16
        body:SetHeight(height)
        local windowHeight=math.min(720,math.max(340,frame.contentTop+height+58))
        local resized=frame:GetHeight()~=windowHeight
        frame:SetHeight(windowHeight)
        if resized and frame:IsShown() and ns.WindowPositions then ns.WindowPositions:AvoidWindowOverlap(frame) end
    end
    function controller:Open(makeBackup)
        build()
        frame.text:ClearFocus()
        selected=nil;mode="list"
        if makeBackup then
            local snapshot,err=journal:CreateBackup()
            selected=snapshot
            status(snapshot and "Backup saved. You can restore it here anytime, or use Export selected to keep a separate copy." or err,not snapshot)
        else status("Select a dated backup, or import one you saved outside the game.") end
        refresh();frame:Show();frame:Raise()
    end
    return controller
end
