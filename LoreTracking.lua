local _, ns = ...
local L=ns.Lore

-- This adapter follows the Classic ItemTextFrame contract. Availability checks
-- are not proof of Forever compatibility: no hidden-page API is assumed.
local function public(v)
    if type(issecretvalue)=="function" then local ok,secret=pcall(issecretvalue,v);if not ok or secret then return false end end
    return true
end
local function value(fn,...)
    if type(fn)~="function" then return false end
    local ok,v=pcall(fn,...);if ok and public(v) then return true,v end
    return false
end
local function read(fn,...) local ok,v=value(fn,...);if ok then return v end end
local function label(v)
    if public(v) and type(v)=="string" and #v>0 and #v<=240 and not v:find('%c') then return v end
end
local function number(v,low,high) return public(v) and type(v)=="number" and v==v and v%1==0 and v>=low and v<=high end
local function unit(token)
    if read(UnitIsPlayer,token)~=false then return end
    local guid,name=read(UnitGUID,token),label(read(UnitName,token))
    if type(guid)~="string" or not name then return end
    local id=tonumber(guid:match('^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$'))
    if not number(id,1,2147483647) then return end
    local context={guid=guid,npcID=id,name=name}
    -- The Ledger's existing unit adapter can supply a native tooltip sublabel;
    -- reading it neither creates a contact nor copies inventory/service data.
    local existing=ns.Ledger and read(ns.Ledger.Unit,token)
    if type(existing)=="table" and existing.guid==guid then context.sublabel=label(existing.sublabel) end
    return context
end
local function defaultAdapter()
    local a={}
    function a.Now() return read(GetTime) or L.Now() end
    function a.After(delay,fn)
        if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(delay,fn);return true end
        return false
    end
    function a.IsOpen() return ItemTextFrame and read(ItemTextFrame.IsShown,ItemTextFrame) end
    function a.Scroll() return ItemTextScrollFrame and read(ItemTextScrollFrame.GetVerticalScroll,ItemTextScrollFrame) end
    function a.RestoreScroll(n)
        if type(n)=="number" and ItemTextScrollFrame then
            local max=read(ItemTextScrollFrame.GetVerticalScrollRange,ItemTextScrollFrame)
            if type(max)=="number" then n=math.max(0,math.min(n,max)) end
            read(ItemTextScrollFrame.SetVerticalScroll,ItemTextScrollFrame,n)
        end
    end
    function a.Read()
        local creatorOK,creator=value(ItemTextGetCreator)
        local nextOK,hasNext=value(ItemTextHasNextPage)
        local raw=read(ItemTextGetText)
        local page=read(ItemTextGetPage)
        return {title=label(read(ItemTextGetItem)),raw=type(raw)=="string" and raw or nil,
            page=number(page,0,1000000) and page or nil,
            hasNext=hasNext==true or hasNext==1,
            nextKnown=nextOK and (hasNext==nil or type(hasNext)=="boolean" or hasNext==1),
            creator=label(creator),creatorKnown=creatorOK and (creator==nil or type(creator)=="string"),
            playerAuthored=creatorOK and type(creator)=="string" and creator~="",
            sourceKind="readable",material=label(read(ItemTextGetMaterial)),locale=read(GetLocale) or "unknown"}
    end
    function a.CanTraverse()
        return type(ItemTextNextPage)=="function" and type(ItemTextPrevPage)=="function"
            and type(hooksecurefunc)=="function" and C_Timer and type(C_Timer.After)=="function"
    end
    function a.Navigate(direction)
        local fn=direction=="next" and ItemTextNextPage or ItemTextPrevPage
        if type(fn)~="function" then return false end
        return pcall(fn)
    end
    function a.HookNavigation(callback)
        if type(hooksecurefunc)~="function" then return false end
        local ok1,ok2=false,false
        if type(ItemTextNextPage)=="function" then ok1=pcall(hooksecurefunc,"ItemTextNextPage",function() callback("next") end) end
        if type(ItemTextPrevPage)=="function" then ok2=pcall(hooksecurefunc,"ItemTextPrevPage",function() callback("previous") end) end
        return ok1 and ok2
    end
    function a.HookScroll(callback)
        if ItemTextScrollFrame and not a.scrollHooked and type(ItemTextScrollFrame.HookScript)=="function" then
            a.scrollHooked=true;pcall(ItemTextScrollFrame.HookScript,ItemTextScrollFrame,"OnMouseWheel",callback)
        end
        local bar=ItemTextScrollFrameScrollBar
        if bar and not a.barHooked and type(bar.HookScript)=="function" then
            a.barHooked=true;pcall(bar.HookScript,bar,"OnMouseDown",callback)
        end
    end
    function a.Progress(text)
        if not a.progress and ItemTextFrame and type(ItemTextFrame.CreateFontString)=="function" then
            a.progress=ItemTextFrame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
            a.progress:SetPoint("BOTTOM",ItemTextFrame,"BOTTOM",0,9);a.progress:SetWidth(250)
        end
        if a.progress then a.progress:SetText(text or "");a.progress:SetShown(text~=nil) end
    end
    function a.IsMail()
        return (MailFrame and read(MailFrame.IsShown,MailFrame)==true)
            or (OpenMailFrame and read(OpenMailFrame.IsShown,OpenMailFrame)==true) or false
    end
    function a.Unit(token) return unit(token) end
    function a.Dialogue(kind)
        local fn=kind=="gossip" and (C_GossipInfo and C_GossipInfo.GetText or GetGossipText)
            or kind=="quest-detail" and GetQuestText or kind=="quest-progress" and GetProgressText
            or kind=="quest-complete" and GetRewardText
        local raw=read(fn)
        if type(raw)~="string" or raw=="" then return end
        return {raw=raw,speaker=unit("npc"),sourceTitle=kind~="gossip" and label(read(GetTitleText)) or nil}
    end
    return a
end

-- An injected adapter uses the same interface and exists for deterministic
-- lifecycle tests, not to infer support from mocks. Only event-ready text is read.
function ns.CreateLoreTracking(journal,settings,adapter)
    settings=settings or {};if settings.autoArchiveLore==nil then settings.autoArchiveLore=true end
    if settings.loreOnlyOpenedPages==nil then settings.loreOnlyOpenedPages=true end
    local a=adapter or defaultAdapter()
    local t={journal=journal,settings=settings,status="Open a readable source to preserve its displayed pages."}
    local serial=0
    local function changed()
        if t.onChange then t.onChange() end
        if t.onStatus then t.onStatus(t.status) end
    end
    local function status(text,s,code,reason)
        t.status=text
        if s and s.entryID then journal:SetCaptureStatus(s.entryID,code or "partial",reason) end
        if a.Progress then a.Progress(s and (s.traversing or s.restoring) and text or nil) end
        changed()
    end
    local function alive(s) return t.active==s and not s.closed end
    local function release(s)
        s.closed=true
        if journal.EndCapture then journal:EndCapture(s.sessionID) end
    end
    local function after(s,delay,fn)
        return a.After and a.After(delay,function() if alive(s) then fn() end end)==true
    end
    local function allowed(s)
        return settings.autoArchiveLore==true and not s.excluded and not journal.readOnly
    end
    local function finish(s,reason,code)
        if not alive(s) then return end
        s.traversing=false;s.restoring=false;s.queue=nil;s.generation=s.generation+1
        if s.pending then s.pending.cancelled=true end
        status(reason or "Capture interrupted.",s,code or "interrupted",reason)
    end
    local function same(s,v)
        return v and (not s.title or v.title==s.title) and (not s.material or v.material==s.material)
            and (not s.identity or v.identity==s.identity)
            and (not s.locale or v.locale==s.locale) and (not s.creatorKnown or (v.creatorKnown and v.creator==s.creator))
    end
    local function snapshot(s)
        if not alive(s) then return end
        if a.IsOpen and a.IsOpen()==false then finish(s,"Capture interrupted: the reader is no longer available.");release(s);return end
        local v=a.Read and a.Read()
        if not same(s,v) then finish(s,"Capture interrupted: the readable source changed.");release(s);return end
        return v
    end
    local function pageNumber(v)
        if number(v.page,1,1000000) then return v.page end
        -- Classic displays page <= 1 without a number for one-page sources.
        -- Only the explicit single-page case can safely normalize zero to one.
        if v.page==0 and v.nextKnown and v.hasNext==false then return 1 end
    end
    local function terminal(v)
        return v.nextKnown==true and v.hasNext==false
    end
    local function private(s,v)
        return t.mailOpen or (a.IsMail and a.IsMail()) or v.playerAuthored or not v.creatorKnown
    end
    local advance,ready
    local function request(s,direction,restore)
        if not alive(s) or s.pending or (not s.traversing and not s.restoring) then return end
        if not allowed(s) or settings.loreOnlyOpenedPages~=false then finish(s,"Capture interrupted: automatic traversal was disabled.");return end
        local v=snapshot(s);if not v then return end
        if private(s,v) then finish(s,"Automatic capture unavailable for player-authored or ambiguous correspondence.","unsupported");return end
        if v.page~=s.currentPage or not s.ready then finish(s,"Capture interrupted: the reader changed.");return end
        if s.steps>=768 or a.Now()-s.started>180 then finish(s,"Partial archive: automatic navigation limit reached.","partial");return end
        local delta=direction=="next" and 1 or -1
        s.steps=s.steps+1;s.ready=false;s.generation=s.generation+1
        local p={from=v.page,expected=v.page+delta,at=a.Now(),restore=restore,deadline=a.Now()+6}
        s.pending=p;t.issuing=true
        local ok=a.Navigate and a.Navigate(direction)==true
        t.issuing=false
        if not ok then finish(s,"Capture interrupted: the client declined page navigation.");return end
        local function timeout()
            if s.pending~=p or p.cancelled then return end
            if a.Now()<p.deadline then after(s,p.deadline-a.Now(),timeout);return end
            finish(s,"Partial archive: timed out waiting for the next page.","partial")
        end
        if not after(s,6,timeout) then finish(s,"Automatic full-book capture unavailable: no supported asynchronous timer.","unsupported") end
    end
    local function queue(s,direction,restore)
        if s.queue or s.pending then return end
        local token={};s.queue=token
        if not after(s,0.15,function()
            if s.queue~=token then return end;s.queue=nil;request(s,direction,restore)
        end) then finish(s,"Automatic full-book capture unavailable: no supported asynchronous timer.","unsupported") end
    end
    local function completed(s)
        s.traversing=false
        if s.originalPage and s.currentPage~=s.originalPage and not s.playerControl then
            s.restoring=true;status("Archive captured; restoring the original page…",s,"complete")
            queue(s,s.currentPage>s.originalPage and "previous" or "next",true)
        else
            s.restoring=false
            if not s.playerControl and a.RestoreScroll then a.RestoreScroll(s.originalScroll) end
            status("Complete archive.",s,"complete")
        end
    end
    advance=function(s,v)
        if not alive(s) then return end
        if s.restoring then
            if s.currentPage==s.originalPage then completed(s) else queue(s,s.currentPage>s.originalPage and "previous" or "next",true) end
            return
        end
        if not s.traversing then return end
        if s.phase=="backward" and v.page>1 then queue(s,"previous");return end
        s.phase="forward"
        if terminal(v) then completed(s)
        elseif v.nextKnown and v.hasNext==true then queue(s,"next")
        else finish(s,"Partial archive: the client did not establish whether another page exists.","partial") end
    end
    local function store(s,v,method,atEnd)
        local n=pageNumber(v)
        local context={sessionID=s.sessionID,title=v.title or "Untitled readable source",sourceKind=v.sourceKind or "readable",
            locale=v.locale or "unknown",identity=v.identity,location=s.location,method=method,
            firstPage=n==1 and 1 or nil,lastPage=atEnd and n or nil}
        local e,err=journal:CapturePage(context,{number=n,sourcePage=v.page,raw=v.raw,method=method,
            personallyViewed=method~="automatic",first=n==1,last=atEnd and n~=nil})
        if not e then finish(s,"Partial archive: "..(type(err)=="string" and err or "the page could not be preserved."),"partial");return end
        s.entryID=e.id;s.currentPage=v.page
        return e
    end
    local function consume(s,v,confirmed,explicit)
        if not alive(s) or not s.ready then return end
        if type(v.raw)~="string" then return end
        local p=s.pending
        if p and v.page~=p.expected then
            if v.page==p.from then return end -- a duplicate READY cannot complete a request
            t:OnNavigation("unexpected");p=nil
        end
        if p and p.cancelled then s.pending=nil;s.currentPage=v.page;return end
        if p then s.pending=nil end
        local method=(p or (s.currentPage==v.page and s.currentMethod=="automatic")) and "automatic" or "displayed"
        s.currentMethod=method
        if s.restoring or (p and p.restore) then s.currentPage=v.page;advance(s,v);return end
        s.excluded=private(s,v)
        if not explicit and not allowed(s) then
            if s.excluded then status("Automatic capture unavailable for player-authored or ambiguous correspondence. Use explicit capture or manual transcription.") end
            return
        end
        local e=store(s,v,method,terminal(v) and confirmed)
        if not e then return end
        if not s.originalPage then s.originalPage=v.page;s.originalScroll=a.Scroll and a.Scroll() end
        local summary=journal.WritingSummary and journal:WritingSummary(e)
        if s.traversing then
            status("Archiving… page "..tostring(pageNumber(v) or "unknown").." captured. Keep the reader open.",s,"partial")
            advance(s,v);return
        end
        if not explicit and allowed(s) and settings.loreOnlyOpenedPages==false and not s.playerControl then
            if summary and summary.complete then status("Complete archive.",s,"complete");return end
            if not pageNumber(v) or v.page==0 or not s.hooks or not a.CanTraverse or not a.CanTraverse() then
                status("Automatic full-book capture unavailable; displayed text preserved.",s,"unsupported","Navigation, pagination or takeover hooks are unavailable.");return
            end
            s.traversing=true;s.phase=v.page>1 and "backward" or "forward";s.started=a.Now();s.steps=0
            status("Archiving… keep the source open; its pages may turn briefly.",s,"partial");advance(s,v)
        elseif summary and summary.complete then status("Complete archive.",s,"complete")
        else status("Partial archive. Pages you open remain available in Lore & Landmarks.",s,"partial") end
    end
    ready=function(s,explicit)
        if not alive(s) then return end
        local current=a.Read and a.Read();s.readyPage=current and current.page
        s.ready=true;s.generation=s.generation+1
        local generation=s.generation;local retries=0
        local function sample()
            if not s.ready or generation~=s.generation then return end
            local v=snapshot(s);if not v then return end
            if type(v.raw)~="string" then
                retries=retries+1
                if retries<=12 and after(s,0.25,sample) then return end
                finish(s,"Partial archive: text did not become available.","partial");return
            end
            local function confirm()
                if not s.ready or generation~=s.generation then return end
                local fresh=snapshot(s);if not fresh then return end
                if fresh.page~=v.page or fresh.raw~=v.raw or fresh.nextKnown~=v.nextKnown or fresh.hasNext~=v.hasNext then
                    retries=retries+1
                    if retries<=12 and after(s,0.25,sample) then return end
                    finish(s,"Partial archive: the reader did not settle.","partial");return
                end
                consume(s,fresh,true,explicit)
            end
            -- Two consistent samples following READY establish a terminal signal;
            -- transient nil/unknown and TRANSLATION never mean end-of-work.
            if not after(s,0.12,confirm) then consume(s,v,false,explicit) end
        end
        if not after(s,0.05,sample) then sample() end
    end
    function t:OnNavigation(direction)
        if self.issuing then return end
        local s=self.active;if not s then return end
        if s.traversing or s.restoring or s.pending or s.queue then finish(s,"Capture interrupted: you took control of the reader.") end
        local wasReady=s.ready
        local v=a.Read and a.Read()
        local delivered=wasReady and v and v.page==s.readyPage and v.page~=s.currentPage
        s.playerControl=true;s.pending=nil;s.ready=direction=="scroll" and wasReady or false;s.currentMethod="displayed";s.generation=s.generation+1
        -- Secure hooks run AFTER the native function. Cached pages can dispatch
        -- READY synchronously before this hook; do not invalidate that delivery.
        if direction~="scroll" and delivered then ready(s) end
    end
    function t:OptionsChanged()
        local s=self.active
        if s and (settings.autoArchiveLore~=true or settings.loreOnlyOpenedPages~=false) then
            if s.traversing or s.restoring or s.queue or s.pending then finish(s,"Capture interrupted: automatic traversal was disabled.") end
        end
        changed()
    end
    function t:GetStatus() return self.status end
    function t:CaptureCurrent()
        local s=self.active
        if s and s.pending and s.pending.cancelled then
            local current=snapshot(s)
            if current and current.page==s.pending.from and type(current.raw)=="string" then s.pending=nil;s.ready=true end
        end
        if not s or not s.ready or s.pending or s.traversing or s.restoring then return nil,"Open a readable source and wait until its text is ready." end
        local v=snapshot(s);if not v or type(v.raw)~="string" then return nil,"The current source text is unavailable; use manual transcription." end
        s.playerControl=false
        -- Explicitly requested capture can preserve ambiguous correspondence;
        -- it never enables automatic traversal while the master switch is off.
        ready(s,true)
        if settings.autoArchiveLore==true and settings.loreOnlyOpenedPages==false and not private(s,v) then
            ready(s,false)
        end
        return true
    end
    local function person(context)
        if not context then return nil,"No supported NPC is available; use a manual person record." end
        if context.npcID then
            for _,e in ipairs(journal:List({kind="person"})) do
                if e.npcID==context.npcID and (not e.locale or e.locale==(read(GetLocale) or "unknown")) then return e end
            end
        end
        return journal:Create("person",{title=context.name or "Unidentified speaker",sourceName=context.name,
            sourceTitle=context.sublabel,npcID=context.npcID,locale=read(GetLocale) or "unknown",subtype="NPC"})
    end
    function t:RecordPerson()
        local context
        if self.dialogue then
            context=self.dialogue.speaker
            local current=a.Unit and a.Unit("npc")
            if context and (not current or current.guid~=context.guid) then return nil,"The NPC interaction has changed." end
        else context=a.Unit and a.Unit("target") end
        local e,err=person(context);if e then journal:AddLocation(e.id,L.CurrentLocation(self.dialogue and "encounter" or "observation")) end
        return e,err
    end
    function t:SavePassage()
        local d=self.dialogue
        if not d then return nil,"Open supported gossip or quest text, or add a manual quotation." end
        local current=a.Dialogue and a.Dialogue(d.kind)
        if not current or (d.speaker and (not current.speaker or current.speaker.guid~=d.speaker.guid)) then
            return nil,"The displayed dialogue or speaker is no longer available."
        end
        local e,err=person(current.speaker or {name="Unidentified speaker"});if not e then return nil,err end
        local passage;passage,err=journal:AddPassage(e.id,{raw=current.raw,origin="captured",nature="account",method="displayed",
            personallyViewed=true,source=d.kind,speaker=current.speaker and current.speaker.name,sourceTitle=current.sourceTitle,at=L.Now()})
        if not passage then return nil,err end
        journal:AddLocation(e.id,d.location);return e
    end
    function t:Event(event,...)
        if event=="ITEM_TEXT_BEGIN" then
            local v=a.Read and a.Read() or {}
            local active=self.active
            -- BEGIN also accompanies page loads in clients using the classic
            -- item-text lifecycle. It is not necessarily a new book.
            if active and same(active,v) and active.currentPage and number(v.page,1,1000000)
                and (active.pending or math.abs(v.page-active.currentPage)<=1) then
                active.ready=false;active.generation=active.generation+1;return
            end
            if self.active then finish(self.active,"Capture interrupted: another reading interaction began.");release(self.active) end
            serial=serial+1
            local s={sessionID=tostring(L.Now())..":"..serial,title=v.title,material=v.material,locale=v.locale,
                identity=v.identity,creator=v.creator,creatorKnown=false,generation=0,location=L.CurrentLocation("read-here"),steps=0,started=a.Now()}
            self.active=s;s.hooks=self.navigationHooked
            if a.HookScroll then a.HookScroll(function() if self.active and (self.active.traversing or self.active.restoring) then self:OnNavigation("scroll") end end) end
        elseif event=="ITEM_TEXT_READY" then
            local s=self.active
            if s then
                local v=a.Read and a.Read()
                if v and not s.title then s.title=v.title end
                if v and not s.creatorKnown and v.creatorKnown then s.creatorKnown=true;s.creator=v.creator end
                ready(s)
            end
        elseif event=="ITEM_TEXT_TRANSLATION" then
            local s=self.active
            if s then
                s.ready=false;s.generation=s.generation+1
                local duration=...
                if s.pending and public(duration) and type(duration)=="number" and duration==duration then s.pending.deadline=a.Now()+math.max(6,math.min(30,duration+2)) end
            end
        elseif event=="ITEM_TEXT_CLOSED" or event=="PLAYER_LEAVING_WORLD" then
            if self.active then
                if self.active.traversing or self.active.restoring or self.active.pending then finish(self.active,"Capture interrupted: the source closed.") end
                release(self.active);self.active=nil
            end
            if a.Progress then a.Progress(nil) end
            if event=="PLAYER_LEAVING_WORLD" then self.dialogue=nil end
        elseif event=="MAIL_SHOW" then
            self.mailOpen=true
            if self.active and (self.active.traversing or self.active.restoring) then finish(self.active,"Automatic capture unavailable while personal mail is open.","unsupported") end
        elseif event=="MAIL_CLOSED" then self.mailOpen=false
        elseif event=="GOSSIP_CLOSED" or event=="QUEST_FINISHED" then self.dialogue=nil
        else
            local kind=({GOSSIP_SHOW="gossip",GOSSIP_OPTIONS_REFRESHED="gossip",GOSSIP_UPDATE="gossip",
                QUEST_DETAIL="quest-detail",QUEST_PROGRESS="quest-progress",QUEST_COMPLETE="quest-complete"})[event]
            if kind then
                local d=a.Dialogue and a.Dialogue(kind);self.dialogue=d
                if d then d.kind=kind;d.location=L.CurrentLocation("encounter") end
            end
        end
    end
    t.navigationHooked=a.HookNavigation and a.HookNavigation(function(direction) t:OnNavigation(direction) end)==true
    if type(CreateFrame)=="function" then
        local frame=CreateFrame("Frame");t.frame=frame
        for _,event in ipairs({"ITEM_TEXT_BEGIN","ITEM_TEXT_READY","ITEM_TEXT_TRANSLATION","ITEM_TEXT_CLOSED","PLAYER_LEAVING_WORLD",
            "MAIL_SHOW","MAIL_CLOSED","GOSSIP_SHOW","GOSSIP_OPTIONS_REFRESHED","GOSSIP_UPDATE","GOSSIP_CLOSED",
            "QUEST_DETAIL","QUEST_PROGRESS","QUEST_COMPLETE","QUEST_FINISHED"}) do pcall(frame.RegisterEvent,frame,event) end
        frame:SetScript("OnEvent",function(_,event,...) t:Event(event,...) end)
    end
    return t
end
