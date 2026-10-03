local _,ns=...
local B=ns.FieldbookBackups
local frame,selected,parts,part,importParts,loading,displayedText
local textDirty,updatePending,cursorTop,cursorHeight
local importMode,pasteState,setImportMode,readPaste
local reflow
local function safe(text) return ns.Atlas.Safe(text or "") end
local function status(text)
    frame.status:SetText(safe(text))
    if reflow then reflow() end
end
local function setText(text)
    if setImportMode then setImportMode(false) end
    textDirty=false;updatePending=false;cursorTop=nil;cursorHeight=nil
    frame:SetScript("OnUpdate",nil)
    displayedText=text or ""
    loading=true;frame.text:SetText(displayedText);loading=false
    frame.text:ClearFocus()
end
local function invalidate()
    selected=nil;parts=nil;frame.restore:SetEnabled(false);frame.export:SetEnabled(false)
    frame.previous:SetEnabled(false);frame.next:SetEnabled(false);frame.part:SetText("")
    frame.summary:SetText("No backup selected. Save a copy or load every part of an external backup.")
end
local function review(text)
    -- A new explicit review supersedes pending edits; subsequent input must
    -- invalidate this new approval even before the next frame update.
    displayedText=frame.text:GetText();textDirty=false
    if pasteState then pasteState.checked=true end
    invalidate()
    local snapshot,err=B.Decode(text)
    if not snapshot then status(err);return end
    selected=text;frame.export:SetEnabled(true)
    local ok,reason=B.CanRestore(snapshot)
    frame.restore:SetEnabled(ok==true)
    frame.summary:SetText(safe(B.Summary(snapshot)))
    status(ok and "Backup checked. Review the scope and replacement warning before restoring." or reason)
end
local function showPart()
    setText(parts[part]);frame.text:SetFocus();frame.text:HighlightText()
    frame.part:SetText("Export part "..part.." of "..#parts)
    frame.previous:SetEnabled(part>1);frame.next:SetEnabled(part<#parts)
    status("Copy this entire part into your external text file. Keep every part. Private notes and source identities are included.")
end
local function list()
    local a,err=B.GetArchive()
    for _,row in ipairs(frame.rows) do row:Hide();row.backup=nil end
    if not a then status(err);return end
    local entries={}
    if a.recovery then entries[#entries+1]={text=a.recovery,title="Before last restore"} end
    for i,text in ipairs(a.saved) do entries[#entries+1]={text=text,title="Saved Fieldbook "..i} end
    for i,item in ipairs(entries) do
        local row=frame.rows[i];row:SetText(item.title);row.backup=item.text;row:Show()
    end
    frame.cancel:SetShown(a.pending~=nil);frame.reload:SetShown(a.pending~=nil or ns.InitializationBlocked==true)
    frame.save:SetEnabled(a.pending==nil)
    if a.pending then status("Restore staged. Reload to apply it, or cancel and reload to resume the current journals.") end
end
local function build()
    if frame then return end
    local U=ns.AtlasUI
    frame=CreateFrame("Frame","AzerothFieldbookWholeBackups",UIParent,"BackdropTemplate")
    frame:SetSize(640,680);frame:SetPoint("CENTER");frame:SetClampedToScreen(true)
    frame:SetFrameStrata("MEDIUM");frame:SetToplevel(true);frame:SetMovable(true);frame:EnableMouse(true);frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background-Dark",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24})
    frame:SetBackdropColor(0.12,0.09,0.06,1)
    U.Label(frame,"Whole-Fieldbook backup and recovery",24,-22,590,"GameFontNormalLarge")
    local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",16,-58);scroll:SetPoint("BOTTOMRIGHT",-36,55)
    local body=CreateFrame("Frame",nil,scroll);body:SetSize(578,1000);scroll:SetScrollChild(body)
    ns.AutoHideScrollBar(scroll)
    U.Label(body,"All eight journals • Account + current character • Two saved copies + one recovery copy",12,0,550,"GameFontHighlightSmall")
    frame.status=U.Label(body,"",12,-38,550,"GameFontHighlightSmall")
    frame.save=U.Button(body,"Save Fieldbook",12,-105,170,function()
        local text,err=B.Create()
        if text then review(text);list();status("Backup saved. Export it to protect against lost SavedVariables; /reload or log out normally to save it to disk.") else status(err) end
    end)
    frame.import=U.Button(body,"New import",196,-105,170,function()
        invalidate();importParts={};setText("")
        setImportMode(true)
        status("Paste one complete export part, then click Add / check part. Repeat for every part in any order.")
        frame.paste:SetFocus()
    end)
    frame.export=U.Button(body,"Export selected",380,-105,170,function()
        if not selected then return end
        parts=B.Parts(selected);part=1;importParts=nil;showPart()
    end)
    frame.rows={}
    for i=1,B.MAX_SAVED+1 do
        local row=U.Button(body,"",12+(i-1)*184,-145,170,function(self) importParts={};review(self.backup);setText("") end)
        frame.rows[i]=row
    end
    frame.summary=U.Label(body,"",12,-188,550,"GameFontHighlightSmall")
    local border=CreateFrame("Frame",nil,body,"BackdropTemplate")
    border:SetPoint("TOPLEFT",12,-370);border:SetSize(540,146)
    border:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=10})
    border:SetBackdropColor(0.025,0.025,0.025,1)
    local textScroll=CreateFrame("ScrollFrame",nil,border,"UIPanelScrollFrameTemplate")
    textScroll:SetPoint("TOPLEFT",8,-8);textScroll:SetPoint("BOTTOMRIGHT",-30,8)
    frame.text=CreateFrame("EditBox",nil,textScroll);frame.text:SetMultiLine(true);frame.text:SetAutoFocus(false)
    frame.text:SetFontObject(ns.TextSize and ns.TextSize:Font("GameFontHighlightSmall") or "GameFontHighlightSmall")
    frame.text:SetSize(490,130);frame.text:SetMaxLetters(B.PART_BYTES*2+1)
    textScroll:SetScrollChild(frame.text);ns.AutoHideScrollBar(textScroll)
    frame.text:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    -- Native acceptance confirmed 128 OnChar bytes with only 95 stored at this
    -- capacity. Keep layout small and capture all characters outside the widget.
    frame.paste=CreateFrame("EditBox",nil,border)
    frame.paste:SetPoint("TOPLEFT",8,-30);frame.paste:SetSize(500,26)
    frame.paste:SetMultiLine(false);frame.paste:SetAutoFocus(false)
    frame.paste:SetFontObject(ns.TextSize and ns.TextSize:Font("GameFontHighlightSmall") or "GameFontHighlightSmall")
    frame.paste:SetMaxLetters(0)
    frame.paste:SetMaxBytes(96)
    local pasteHint=U.Label(border,"Click here and paste one complete part (Ctrl+V).",8,-8,500,"GameFontHighlightSmall")
    frame.pasteStatus=U.Label(border,"",8,-65,500,"GameFontHighlightSmall")
    local function resetPaste()
        pasteState={blocks={},chars={},bytes=0,prefix="",native="",pending=false}
    end
    readPaste=function()
        local s=pasteState
        if not s then return end
        s.native=frame.paste:GetText();s.hasChars=false
        if not s.text then
            s.blocks[#s.blocks+1]=table.concat(s.chars);s.chars={}
            s.text=table.concat(s.blocks);s.blocks={}
        end
    end
    local function showPasteStatus()
        local s=pasteState;if not s then return end
        s.pending=false
        frame.pasteStatus:SetText(s.error or (s.bytes==0 and "Waiting for a complete part." or
            (s.bytes.." bytes received. Click Add / check part.\nStarts with: "..safe(s.prefix).."\nOnly this short preview is displayed; validation uses all received text.")))
    end
    setImportMode=function(enabled)
        importMode=enabled;pasteState=nil
        textScroll:SetShown(not enabled);frame.paste:SetShown(enabled)
        pasteHint:SetShown(enabled);frame.pasteStatus:SetShown(enabled)
        frame.selectText:SetEnabled(not enabled)
        frame.paste:ClearFocus();frame.paste:SetText("")
        frame.pasteStatus:SetText("")
        frame.clearPaste:SetShown(enabled)
        if enabled then resetPaste();showPasteStatus() end
    end
    local function readText()
        displayedText=frame.text:GetText();textDirty=false
        return displayedText
    end
    local function flushUpdates()
        frame:SetScript("OnUpdate",nil);updatePending=false
        if importMode and pasteState and pasteState.pending then showPasteStatus() end
        if textDirty then readText();reflow() end
        local top,height=cursorTop,cursorHeight;cursorTop=nil;cursorHeight=nil
        if top then
            local offset=textScroll:GetVerticalScroll()
            if top<offset then textScroll:SetVerticalScroll(math.max(0,top))
            elseif top+height>offset+130 then textScroll:SetVerticalScroll(math.max(0,top+height-130)) end
        end
    end
    local function queueUpdate()
        if updatePending then return end
        updatePending=true;frame:SetScript("OnUpdate",flushUpdates)
    end
    local function invalidatePaste()
        invalidate()
        if StaticPopup_Hide then StaticPopup_Hide("AZEROTHFIELDBOOK_WHOLE_RESTORE") end
        frame.status:SetText("Input changed. Add / check this complete part before restoring.")
    end
    frame.paste:SetScript("OnChar",function(_,char)
        if not importMode or loading or not frame:IsShown() or type(char)~="string" or char=="" then return end
        if not pasteState or pasteState.checked then resetPaste() end
        local s=pasteState
        if s.bytes==0 and not s.error then invalidatePaste() end
        s.hasChars=true
        if s.error then return end
        if s.bytes+#char>B.PART_BYTES*2 then
            s.error="Input is too large. Clear input and paste one complete backup part."
            s.blocks={};s.chars={}
        else
            s.bytes=s.bytes+#char;s.chars[#s.chars+1]=char
            if #s.prefix<96 then s.prefix=s.prefix..char:sub(1,96-#s.prefix) end
            if #s.chars>=1024 then s.blocks[#s.blocks+1]=table.concat(s.chars);s.chars={} end
        end
        s.pending=true;queueUpdate()
    end)
    frame.paste:SetScript("OnTextChanged",function(self)
        if not importMode or loading or not pasteState or not frame:IsShown() then return end
        local s=pasteState;local native=self:GetText() -- at most 95 bytes
        if s.hasChars then s.native=native;s.hasChars=false;return end
        if native==s.native then return end
        -- Deletion/cut or input without character delivery cannot reuse an old
        -- complete capture. Never validate the widget's truncated prefix.
        resetPaste();pasteState.native=native
        pasteState.error="Input edited or not captured. Clear input and paste the complete part again."
        pasteState.pending=true;invalidatePaste()
        queueUpdate()
    end)
    frame.paste:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    frame.clearPaste=U.Button(border,"Clear input",370,-108,130,function()
        loading=true;frame.paste:SetText("");loading=false
        resetPaste();invalidate();showPasteStatus()
        if StaticPopup_Hide then StaticPopup_Hide("AZEROTHFIELDBOOK_WHOLE_RESTORE") end
        status("Input cleared. Paste one complete backup part.");frame.paste:SetFocus()
    end)
    frame.text:SetScript("OnTextChanged",function(_,userInput)
        if importMode or loading or textDirty or not frame:IsShown() then return end
        -- Native notifications can arrive after SetText returns, or repeat
        -- without an edit. Preserve export/review for unchanged programmatic text.
        if userInput~=true and frame.text:GetText()==displayedText then return end
        -- Invalidate immediately, but do not copy a growing paste buffer or
        -- relayout/scroll on each notification. Read its final contents next frame.
        textDirty=true
        invalidate()
        if StaticPopup_Hide then StaticPopup_Hide("AZEROTHFIELDBOOK_WHOLE_RESTORE") end
        frame.status:SetText("Text changed. Add / check this part before restoring.")
        queueUpdate()
    end)
    frame.text:SetScript("OnCursorChanged",function(_,_,y,_,height)
        if importMode or loading or not frame:IsShown() then return end
        cursorTop,cursorHeight=-y,height;queueUpdate()
    end)
    frame.check=U.Button(body,"Add / check part",12,-530,160,function()
        -- A click can precede the queued frame update; consume the final text now.
        local text
        if importMode then
            readPaste()
            local s=pasteState;s.checked=true
            showPasteStatus()
            if s.error or s.bytes==0 then
                invalidate();status(s.error or "No text received. Click the paste field and paste one complete part.");return
            end
            text=s.text
            loading=true;frame.paste:SetText("");loading=false
            s.native="";frame.paste:SetFocus()
        else text=readText() end
        if text:match("^%s*AFBWB1:") then review(text);return end
        local received,err=B.AddPart(importParts or {},text)
        if not received then invalidate();status(err);return end
        importParts=received
        if received.complete then review(received.complete)
        else invalidate();status(received.received.." of "..received.total.." parts checked. No journal data has changed.") end
    end)
    frame.selectText=U.Button(body,"Select text",184,-530,116,function() frame.text:SetFocus();frame.text:HighlightText() end)
    frame.previous=U.Button(body,"Previous",312,-530,112,function() if parts and part>1 then part=part-1;showPart() end end)
    frame.next=U.Button(body,"Next",436,-530,112,function() if parts and part<#parts then part=part+1;showPart() end end)
    frame.part=U.Label(body,"",12,-570,550,"GameFontHighlightSmall")
    frame.notice=U.Label(body,
        "Restore replaces ALL account journals and this character's retained journals, settings and logs with the selected copy. It also affects other characters using the account journals. It requires a reload. A recovery copy is saved first. Current Bestiary earned milestones, spending and delivery state are retained; old offers are never replayed. Completed character imports stay completed; older journals are not automatically imported again.\n\n"..
        "Backups include private notes, annotations and player identities. Keep them private. Reports omit information and cannot restore your Fieldbook. Old AFB1 copies remain Bestiary-only; use Restore Bestiary in Options.\n\n"..
        "In-game copies share SavedVariables storage. Export ALL parts to a separate text file and check that file by importing it before relying on it. For large archives, a file copy is more practical: exit WoW normally, then copy the WTF folder to another location. It includes the account and every character's SavedVariables. Restore those files only while WoW is closed.\n\n"..
        "Offline characters' separate journals cannot be read by the addon. Log in on each character to export its retained journals, or copy WTF. Never restore an older account snapshot casually: newer account knowledge will be replaced.",12,-605,550,"GameFontHighlightSmall")
    body:SetHeight(625+frame.notice:GetStringHeight())
    reflow=function()
        local y=math.max(370,188+frame.summary:GetStringHeight()+18)
        border:ClearAllPoints();border:SetPoint("TOPLEFT",12,-y)
        for i,control in ipairs({frame.check,frame.selectText,frame.previous,frame.next}) do
            control:ClearAllPoints();control:SetPoint("TOPLEFT",({12,184,312,436})[i],-y-160)
        end
        frame.part:ClearAllPoints();frame.part:SetPoint("TOPLEFT",12,-y-200)
        frame.notice:ClearAllPoints();frame.notice:SetPoint("TOPLEFT",12,-y-235)
        body:SetHeight(y+255+frame.notice:GetStringHeight())
    end
    frame.restore=U.Button(frame,"Restore / reload",24,0,170,function()
        if not selected or not StaticPopup_Show then return end
        StaticPopup_Show("AZEROTHFIELDBOOK_WHOLE_RESTORE",nil,nil,selected)
    end)
    frame.restore:ClearAllPoints();frame.restore:SetPoint("BOTTOMLEFT",24,18)
    frame.cancel=U.Button(frame,"Cancel pending",208,0,160,function()
        local ok,err=B.CancelPending();list();status(ok and "Restore cancelled. /reload to resume; no journal was replaced." or err)
    end)
    frame.cancel:ClearAllPoints();frame.cancel:SetPoint("BOTTOMLEFT",208,18)
    frame.reload=U.Button(frame,"Reload",382,0,105,function() if ReloadUI then ReloadUI() end end)
    frame.reload:ClearAllPoints();frame.reload:SetPoint("BOTTOMLEFT",382,18)
    local close=U.Button(frame,"Close",500,0,110,function() frame:Hide() end)
    close:ClearAllPoints();close:SetPoint("BOTTOMRIGHT",-24,18)
    if type(StaticPopupDialogs)=="table" then
        StaticPopupDialogs.AZEROTHFIELDBOOK_WHOLE_RESTORE={
            text="Replace all account journals AND this character's retained journals, settings and logs? Other characters' account view changes too. A recovery copy will be saved first. Reload now to apply this whole-Fieldbook backup.",
            button1="Restore / reload",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
            OnAccept=function(_,text)
                if selected~=text then status("Selection changed. Review the backup again.");return end
                local ok,err=B.RequestRestore(text)
                if not ok then status(err);return end
                invalidate();list()
                if ReloadUI then ReloadUI() end
            end,
        }
    end
    frame:SetScript("OnHide",function()
        frame.text:ClearFocus();setText("");invalidate();importParts=nil
        for _,row in ipairs(frame.rows) do row.backup=nil end
        if StaticPopup_Hide then StaticPopup_Hide("AZEROTHFIELDBOOK_WHOLE_RESTORE") end
    end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="AzerothFieldbookWholeBackups" end
    -- Recovery must also work with a malformed main save. Do not initialize
    -- settings, window-position stores or the Fieldbook shell to show this UI.
    if ns.WindowFocus then ns.WindowFocus:Register(frame) end
    if ns.UIScale then ns.UIScale:Register(frame) end
    frame:Hide()
end
function ns.OpenFieldbookBackups()
    build();invalidate();setText("");importParts={}
    status("Save a full backup, select a saved copy, or start an import. Nothing is replaced before confirmation.")
    list();frame:Show();frame:Raise()
end
