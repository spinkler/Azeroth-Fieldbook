local _,ns=...
local A,U=ns.Annals,ns.AtlasUI
local HELP="Your character writes this history automatically: quest acceptance, removal and confirmed turn-in, plus deaths, flight departures, Hearthstone/teleport casts, cross-continent crossings, battleground transfers, dungeon/raid visits and lightweight links to Fieldbook discoveries. Existing quests are not backfilled. Removed does not always mean abandoned.\n\nJourney Trail is a separate approximate route. Uncheck Record Journey and choose Yes to stop future breadcrumbs; No keeps recording. Re-enabling is immediate; events and their locations remain. No history is erased. Balanced recording checks every two seconds but keeps ordinary points roughly 15–60 seconds apart while moving; stationary players add no periodic points. Events, confirmed stops and segment endpoints are exceptions. Stop arrival/departure times are retained without periodic idle samples. Loading and missing positions leave gaps. Successful Hearthstone, Astral Recall, Classic capital teleports and Moonglade casts record departures. Loading transitions record arrivals, battleground entry/exit and cross-continent travel with separate icons. Ship icons indicate observed continent crossings, not a confirmed vessel. Login/reload do not invent journeys. Ordinary same-continent loading does not create travel events. Dungeon, raid and scenario visits record entry/exit and hold the arrow at the last observed outdoor entrance while inside, including across reloads. Interior events remain in the timeline but do not move the outdoor arrow or create route lines. Exits and hearths out jump to the observed outdoor arrival. If the entrance was not observed, its position remains unknown. Unrecognized portal uses are not automatically identified. Subzone names do not interrupt flights.\n\nSearch matches partial words without case sensitivity across quest names, event details, dates, places and offered/received rewards. Multiple words can match different fields: sword Westfall finds recorded sword rewards in Westfall. Client item types, equipment slots, descriptions and readable tooltip text are included when available; results refresh when item data loads. Search combines with date/level/event filters and filters map markers without hiding the historical route or arrow. Clear it with the red cross or Now / reset. Enter dates as YYYY-MM-DD, optionally a character level, then Apply. Dates use your computer's local calendar. Select an event and Around event to inspect its surrounding hour, or Quest interval for discoveries during its observed acceptance-to-removal/turn-in period. Temporal overlap never means a quest caused those discoveries.\n\nThe timeline opens newest first at the top each session. The sort button beside the filter toggles newest first / oldest first. Use Latest, page buttons or the mouse wheel. Journey opens by default on the right for the selected dates, with the timeline on the left. Selecting a timeline event pauses and seeks its recorded time and map. Show detail sits in the left pane and glows while its scrollable detail overlay covers the timeline. Turn it off to restore the same timeline page and selection. The Journey map and playback remain available while details are open. Around selected event, Trail age contrast and Map icon size are in the right pane. The map footer shows date and time above the position, state and recorded level. Right-click either filter funnel to clear date, level, search and event filters. Hover the contrast slider for an explanation. Choose zone above the map selects a historical map. The Legend button toggles an overlay with the actual event icons, player arrows and trail colours. Legend and Follow player glow while active. Instance icons show a green entry arrow or an orange exit arrow. Drag the time slider to browse. Play advances one recorded second per real second at 1x; choose 8x, 32x, 64x, 128x or 256x to speed up, or enter a Custom speed (0.1-4096x) and press Enter. Use the arrow / pause symbol to start or stop playback. Pause, scrub or leave Journey to stop playback. Playback stops at the range end; Play there restarts from the beginning. Now / reset returns to the current time, clears search/date/level/event filters, restores full-range timing and 1x speed, disables Follow player, and returns to the current map (or the known outdoor entrance during an instance visit). Choose Full range, 3 hours, 1 hour or 15 minutes to change slider resolution and show only that duration of trail behind the selected playback time. The mouse wheel makes precise second-by-second adjustments. Find player pauses at the selected time and centers its historical position, switching to the recorded map if needed. It keeps a closer zoom or zooms in to locate the arrow. Follow player keeps the historical arrow in view during playback, switching recorded zones and continents and jumping directly to observed hearth/teleport arrivals. Turn it off to pan freely while playback continues. Playback estimates movement between connected samples using their timestamps, with smooth arrow updates and a progressively revealed route. Estimates are labelled; no new positions are saved. Routes and markers also project onto continent and world maps where the client supplies map rectangles. Existing saved gaps are preserved. The clock uses recorded timestamps; the arrow moves between connected samples and holds at the last known position through gaps. Old recordings may lack stop timing; new recordings preserve it during simplification. Its heading follows recorded movement, not camera facing. Mount trails use Rare blue for 60% and Epic purple for 100%; these require newly recorded mount observations. Green means flight, red means dead, blue means ghost and white means alive or unknown. Event filter checkboxes combine types without hiding the arrow. Map icon size adjusts markers and the arrow.\n\nLarge map ranges display at most 64 recent chunks, 2,048 lines and the latest 15 located events at the selected time; the oldest five icons progressively fade. Scrub earlier or narrow dates for older geometry. The timeline always retains all matching events.\n\nAccepted quests retain the observed quest text and objectives alongside the potential item choices and guaranteed rewards observed in the quest dialogue, plus readable XP, money, currency and spell offers. If accepted before reward data loads, the new entry waits up to ten seconds for the matching quest log rewards; its original time and location stay fixed. The selected quest is restored after reads. Missing data stays explicitly unknown after the retry window or quest removal, and older entries are not backfilled. Completed quests show the chosen reward when the reward request and turn-in were observed; guaranteed items are separate. Hover reward icons or names for tooltips. Reward names are enlarged and use quality colours; single items omit the count. Timeline icons have drop shadows. Money uses gold, silver and copper units. Actual XP and money come from the turn-in event. Currency and spell offers are not proof of balance changes or learned spells. Reputation rewards are not captured. Older entries and unreadable offers remain explicitly unknown; opening them does not rewrite history. Source inspection and mock tests still require in-game API validation.\n\nAll history is local and character-specific, regardless of account tracking. SavedVariables persist on a successful logout or /reload; a client crash may lose the current session, as with other journals."
function A.ParseDate(text,ending)
    if not A.Text(text,10) then return end
    local y,m,d=text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$');y,m,d=tonumber(y),tonumber(m),tonumber(d)
    if not y or y<1970 or y>2200 or m<1 or m>12 or d<1 or d>31 or type(time)~='function' then return end
    local stamp=A.Read(time,{year=y,month=m,day=d,hour=ending and 23 or 0,min=ending and 59 or 0,sec=ending and 59 or 0})
    if not A.Int(stamp,0,9999999999) or (date and date('%Y-%m-%d',stamp)~=text) then return end
    return stamp
end
local function detailArea(parent)
    local area,body=U.Scroll(parent,0,0,228,436)
    area.rows={};area.requests={};area.body=body
    local function hideTooltip() if GameTooltip then GameTooltip:Hide() end end
    local function scroll(_,delta)
        area:SetVerticalScroll(math.max(0,math.min(math.max(0,body:GetHeight()-area:GetHeight()),area:GetVerticalScroll()-delta*32)))
    end
    area:EnableMouseWheel(true);area:SetScript('OnMouseWheel',scroll)
    body:EnableMouseWheel(true);body:SetScript('OnMouseWheel',scroll)
    function area:SetEvent(e,reset)
        hideTooltip();self.event=e;self.visibleItems={}
        local blocks={}
        local function add(text,kind) blocks[#blocks+1]={text=text,kind=kind or 'text'} end
        if not e then add(A.Paint('Select an event to read its historical details.','999999'))
        else
            add(A.Paint(e.title,'ffd100'),'title')
            add(A.Paint(A.eventNames[e.kind] or e.kind,A.eventColours[e.kind] or '55ddee'),'status')
            add(A.Paint(U.Date(e.at)..(e.level and (' • Level '..e.level) or ''),'999999'))
            if e.zone or e.subzone then
                local location=e.zone or e.subzone
                if e.zone and e.subzone and e.subzone~='' and e.subzone~=e.zone then location=location..' — '..e.subzone end
                add(A.Paint(location,'dddddd'))
            end
            if A.Int(e.x,0,10000) and A.Int(e.y,0,10000) then add(A.Paint(string.format('Coordinates: %.1f, %.1f',e.x/100,e.y/100),'999999')) end
            if e.removal=='abandoned' then add(A.Paint('Abandon request observed.','999999')) end
            local instanceNote=A.InstanceNote(e);if instanceNote then add(A.Paint(instanceNote,'999999')) end
            for _,block in ipairs(A.QuestTextBlocks(e,true)) do blocks[#blocks+1]=block end
            for _,block in ipairs(A.RewardBlocks(e,true)) do blocks[#blocks+1]=block end
            if e.link then add(A.Paint('Fieldbook discovery','55ddee'),'heading');add(A.Paint(e.link.section..' • Recorded during the journey.','dddddd')) end
        end
        local y=0
        for i,block in ipairs(blocks) do
            local row=self.rows[i]
            if not row then
                row=CreateFrame('Button',nil,body);row:SetWidth(228)
                row.label=U.Label(row,'',0,0,228,'GameFontHighlightSmall');row.label:SetWordWrap(true);row.label:SetSpacing(3)
                row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(24,24);row.icon:SetPoint('TOPLEFT',0,0)
                row:EnableMouseWheel(true);row:SetScript('OnMouseWheel',scroll)
                row:SetScript('OnEnter',function(self)
                    if not self.link or not GameTooltip then return end
                    GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetHyperlink(self.link);GameTooltip:Show()
                end)
                row:SetScript('OnLeave',hideTooltip);row:SetScript('OnHide',hideTooltip)
                self.rows[i]=row
            end
            local font=block.kind=='title' and 'GameFontNormalLarge' or block.kind=='heading' and 'GameFontNormal' or 'GameFontHighlightSmall'
            local fontObject=ns.TextSize and ns.TextSize:Font(font) or font
            row.label:SetFontObject(fontObject)
            local base=type(fontObject)=='string' and _G[fontObject] or fontObject
            if base and type(base.GetFont)=='function' then
                local path,size,flags=base:GetFont()
                if path and type(size)=='number' then row.label:SetFont(path,size+(block.item and 2 or 0),flags) end
            end
            row.block=block;row.link=nil;row.label:ClearAllPoints()
            row.label:SetPoint('TOPLEFT',block.item and 32 or 0,0);row.label:SetWidth(block.item and 196 or 228)
            row.label:SetText(block.text);row.icon:SetShown(block.item~=nil);row:EnableMouse(block.item~=nil)
            if block.item then
                local _,_,icon,link=A.RewardPresentation(block.item);row.icon:SetTexture(icon);row.link=link
                local id=block.item.itemID
                if id then self.visibleItems[id]=true end
                if id and not self.requests[id] and C_Item and type(C_Item.RequestLoadItemDataByID)=='function' then
                    self.requests[id]=true;A.Read(C_Item.RequestLoadItemDataByID,id)
                end
            end
            if block.kind=='heading' then y=y+10 end
            row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-y)
            row:SetHeight(math.max(block.item and 26 or 0,row.label:GetStringHeight()))
            row:Show();y=y+row:GetHeight()+(block.kind=='title' and 6 or 5)
        end
        for i=#blocks+1,#self.rows do self.rows[i].link=nil;self.rows[i].block=nil;self.rows[i]:Hide() end
        body:SetHeight(math.max(364,y+8))
        self:SetVerticalScroll(reset and 0 or math.min(self:GetVerticalScroll(),math.max(0,body:GetHeight()-self:GetHeight())))
        self:UpdateScrollChildRect();self:RefreshScrollBar()
    end
    area:SetScript('OnHide',hideTooltip)
    area:SetScript('OnShow',function(self) if self.event then self:SetEvent(self.event,false) end end)
    area:RegisterEvent('GET_ITEM_INFO_RECEIVED')
    area:SetScript('OnEvent',function(self,_,id,success)
        if success and self.visibleItems[id] and self:IsVisible() and self.event then self:SetEvent(self.event,false) end
    end)
    area:SetEvent(nil,true)
    return area
end
function ns.CreateAnnalsBook(j,shell)
    local c={journal=j,shell=shell,offset=0,newestFirst=true,filter='all',rows={},showDetail=false,query='',searchCache={}}
    local eventKinds={'accepted','removed','completed','discovery','flight','death','hearth','teleport','crossing','battleground','instance'}
    c.filter={}
    for _,kind in ipairs(eventKinds) do
        c.filter[kind]=type(j.db.settings.eventFilters)~='table' or j.db.settings.eventFilters[kind]~=false
    end
    function c:LatestOffset()
        return self.newestFirst and 0 or math.max(0,math.floor((#self.rows-1)/7)*7)
    end
    function c:ToggleSort()
        self.newestFirst=not self.newestFirst;self.offset=0;self:Refresh()
    end
    function c:SetEventFilter(kind,enabled)
        for _,key in ipairs(eventKinds) do if kind=='all' or key==kind then self.filter[key]=enabled end end
        if not j.readOnly and not ns.InitializationBlocked then j.db.settings.eventFilters=A.Copy(self.filter) end
        self.offset=0;self:Refresh(true)
    end
    function c:QueueSearchRefresh()
        if self.searchPending then return end
        if C_Timer and type(C_Timer.After)=='function' then
            self.searchPending=true
            C_Timer.After(0.15,function()
                self.searchPending=false
                if self.main:IsVisible() then self:Refresh(true) end
            end)
        else self:Refresh(true) end
    end
    function c:RefreshStorage()
        if self.main then local usage=j:StorageStatus();self.main.capacity:SetText(usage) end
    end
    function c:SyncDetailOverlay()
        if not self.main then return end
        local m=self.main
        m.detailPane:SetShown(self.showDetail);m.timeline:SetShown(not self.showDetail);m.paging:SetShown(not self.showDetail)
        m.show:SetSelected(self.showDetail)
    end
    c.playbackSpeed=1
    function c:SyncPlayButton()
        if not self.main or not self.main.play then return end
        local button=self.main.play
        button.symbol:SetShown(not self.playing)
        for _,bar in ipairs(button.pauseBars) do bar:SetShown(self.playing==true) end
        button.tooltipText=self.playing and 'Pause playback' or 'Play journey'
    end
    function c:SetPlaybackSpeed(rate)
        if not ns.Atlas.Number(rate,0.1,4096) then return false end
        self.playbackSpeed=rate
        if self.main and self.main.customSpeed then self.main.customSpeed:SetText(tostring(rate)) end
        if self.main then for value,button in pairs(self.main.speeds) do button:SetEnabled(value~=rate) end end
    end
    function c:PausePlayback()
        self.playing=false;self.playbackElapsed=0
        self:SyncPlayButton()
    end
    function c:SyncSlider()
        if not self.main or not self.first then return end
        local first,last=self.first,self.last
        local span=self.sliderSpan
        if span and last-first>span then
            local start=self.sliderStart
            if not start or self.at<start or self.at>start+span then start=self.at-span/2 end
            first=math.max(self.first,math.min(self.last-span,start));last=first+span
        end
        self.sliderStart=first
        local slider=self.main.slider;slider.syncing=true
        -- Native sliders use floats: epoch timestamps can lose whole minutes.
        -- Small offsets retain second-level precision, especially when zoomed.
        slider:SetMinMaxValues(0,math.max(1,last-first));slider:SetValue((self.at or last)-first)
        slider.syncing=false
    end
    function c:Seek(at)
        self:PausePlayback();self.follow=false
        self.at=math.max(self.first,math.min(self.last,at));self:SyncSlider();self:Journey()
    end
    function c:TogglePlayback()
        if self.playing then self:PausePlayback();return end
        if self.last<=self.first then return end
        self.follow=false
        if not self.at or self.at>=self.last then self.at=self.first;self.sliderStart=nil end
        self.playing=true;self.playbackElapsed=0;self:SyncPlayButton()
        self:SyncSlider();self:Journey()
    end
    function c:TickPlayback(elapsed)
        if not self.playing then return end
        self.at=math.min(self.last,self.at+elapsed*self.playbackSpeed)
        self.playbackElapsed=(self.playbackElapsed or 0)+elapsed
        if self.playbackElapsed>=0.1 or self.at>=self.last or (self.followPlayer and self.followBoundary and self.at>=self.followBoundary) then
            self.playbackElapsed=0;self:SyncSlider();self:Journey()
        elseif not self.main.map:AdvanceHistoricalPlayer(self.at) then
            self.playbackElapsed=0;self:SyncSlider();self:Journey()
        end
        if self.followPlayer then self.main.map:PanToHistoricalPlayer() end
        if self.at>=self.last then self:PausePlayback() end
    end
    function c:Message(text) if self.main then self.main.message:SetText(ns.Atlas.Safe(text or '')) end end
    function c:Maps()
        local known={};local rows={}
        local function add(id,zone) if A.Int(id,1,2147483647) and not known[id] then
            known[id]=true;local info=A.Read(C_Map and C_Map.GetMapInfo,id)
            rows[#rows+1]={mapID=id,zone=zone or (type(info)=='table' and info.name) or ('Map '..id)}
        end end
        for _,s in ipairs(j.db.segments) do if type(s)=='table' then add(s.mapID) end end
        for _,row in ipairs(j.events) do add(row.event.mapID,row.event.zone) end
        return rows
    end
    function c:SetRange(first,last)
        self:PausePlayback();self.sliderStart=nil
        self.follow=false
        self.first,self.last=first,last;self.at=last;self.offset=0;self.index=nil
        if self.main then
            self.main.from:SetText(date and date('%Y-%m-%d',first) or '')
            self.main.to:SetText(date and date('%Y-%m-%d',last) or '')
        end
        self:Refresh(true)
    end
    function c:ResetNow()
        self:PausePlayback();self:SetPlaybackSpeed(1)
        self.followPlayer=false;self.followBoundary=nil;self.main.followPlayer:SetSelected(false)
        self.level=nil;self.selected=nil;self.sliderSpan=nil;self.sliderStart=nil
        self.query='';self.searchCache={};self.searchSync=true;self.main.search:SetText('');self.searchSync=false
        self.main.level:SetText('');self.main.timeZoom:SetText('Full range');self.main.detail:SetEvent(nil,true)
        for _,kind in ipairs(eventKinds) do self.filter[kind]=true end
        if not j.readOnly and not ns.InitializationBlocked then j.db.settings.eventFilters=A.Copy(self.filter) end
        self.mapID=A.Location().mapID or self.mapID
        self.first=math.min(j:Bounds(),A.Now());self.last=A.Now();self.at=self.last
        local held=A.JourneyPosition(A.JourneyIndex(j,self.first,self.last,nil),self.last)
        if held and held.instanceName then self.mapID=held.mapID end
        self.follow=true;self.index=nil;self.offset=self.newestFirst and 0 or math.huge
        self.main.map.zoom,self.main.map.panX,self.main.map.panY=1,0,0
        self:Refresh(true)
    end
    function c:SyncRowSelection()
        for i,row in ipairs(self.main.rows) do
            local selected=row.record~=nil and row.record.id==self.selected
            row:SetSelected(selected)
            local previous=self.main.rows[i-1]
            local previousSelected=previous and previous.record and previous.record.id==self.selected
            for _,line in ipairs(row.divider or {}) do
                line:SetShown(row.record~=nil and not selected and not previousSelected)
            end
        end
    end
    function c:Select(id,preserveJourney)
        id=tonumber(id);local e=id and j.db.events[id];if not A.ValidEvent(e) then return end
        self.selected=id
        if self.main then
            self.main.detail:SetEvent(e,true)
            self:SyncRowSelection()
        end
        if not preserveJourney then
            self.mapID=e.mapID or self.mapID
            if self.main then self.index=nil;self:Seek(e.at) end
        end
    end
    function c:Around(quest)
        local e=self.selected and j.db.events[self.selected];if not e then self:Message('Select an event first.');return end
        local first,last=e.at-1800,e.at+1800
        if quest and e.questID then
            first,last=e.at,e.at
            if e.kind=='accepted' then
                last=A.Now()
                for id=self.selected+1,#j.db.events do local nextEvent=j.db.events[id]
                    if A.ValidEvent(nextEvent) and nextEvent.questID==e.questID and (nextEvent.kind=='removed' or nextEvent.kind=='completed') then last=nextEvent.at;break end
                end
            else
                for id=self.selected-1,1,-1 do local previous=j.db.events[id]
                    if A.ValidEvent(previous) and previous.questID==e.questID then if previous.kind=='accepted' then first=previous.at end;break end
                end
            end
        end
        self:SetRange(math.max(0,first),last)
    end
    function c:FindPlayer()
        self:PausePlayback();self.follow=false
        local at=self.at or self.last
        -- Search all recorded maps, independently of marker filters. A nil map
        -- keeps source coordinates, so a stale arrow on the viewed map cannot win.
        local all=A.JourneyIndex(j,self.first,self.last,nil,nil,self.level)
        local p=A.JourneyPosition(all,at)
        if not p then self:Message('No recorded player position at this time in the selected range.');return end
        if not A.MapTransform(p.mapID,self.mapID) then self.mapID=p.mapID end
        self.index=nil;self:Journey()
        if not self.main.map:CenterHistoricalPlayer() then self:Message('Player position found, but map artwork is unavailable.');return end
        p=self.main.map.historicalPlayer
        self:Message(p.interpolated and 'Centered on the estimated player position at the selected time.' or 'Centered on the last recorded player position at or before the selected time.')
    end
    function c:ToggleFollowPlayer()
        self.followPlayer=not self.followPlayer;self.followBoundary=nil
        self.main.followPlayer:SetSelected(self.followPlayer)
        if self.followPlayer then self:Journey() end
    end
    function c:Journey()
        if not self.main then return end
        local followPosition;local zoom=self.main.map.zoom
        if self.followPlayer then
            local index=self.positionIndex
            if not index or index.first~=self.first or index.last~=self.last or index.level~=self.level then
                index=A.JourneyIndex(j,self.first,self.last,nil,nil,self.level);self.positionIndex=index
            end
            followPosition,self.followBoundary=A.JourneyPosition(index,self.at or self.last)
            if followPosition then self.mapID=followPosition.mapID end
        end
        self.mapID=self.mapID or (self:Maps()[1] or {}).mapID
        if not self.index or self.index.mapID~=self.mapID then self.index=A.JourneyIndex(j,self.first,self.last,self.mapID,self.filter,self.level,self.query,self.searchCache) end
        self.index.trailSpan=self.sliderSpan
        local cursor,limited,invalid=self.main.map:ShowJourney(self.index,self.at or self.last)
        if followPosition then self.main.map:CenterHistoricalPlayer(zoom) end
        local stamp=math.floor(self.at or self.last)
        self.main.clock:SetText((date and date('%Y-%m-%d %H:%M:%S',stamp) or U.Date(stamp))..(cursor and ((cursor.instanceName and ' • At instance entrance' or cursor.interpolated and ' • Estimated position' or (' • Last sample '..U.Date(cursor.at)))..string.format(' • %.1f, %.1f',cursor.x/100,cursor.y/100)) or ' • No sample on this map yet'))
        local level=cursor and cursor.level;local lo,hi=1,#self.rows
        while lo<=hi do local mid=math.floor((lo+hi)/2);if self.rows[mid].event.at<=(self.at or self.last) then lo=mid+1 else hi=mid-1 end end
        if not level and self.rows[hi] then level=self.rows[hi].event.level end
        self.main.map.recordedLevel=level;self.main.map:ShowHistoricalPlayer()
        self:Message((limited and 'Dense range: recent geometry shown. Scrub earlier or narrow dates. ' or 'Recorded routes projected onto this map. ')
            ..(invalid>0 and (invalid..' malformed segments preserved but not drawn. ') or '')
            ..(self.main.map.linesAvailable==false and 'Line rendering unavailable; markers and stored history remain.' or ''))
    end
    function c:Refresh(requery)
        if not self.main then return end
        if self.follow then self.first=math.min(j:Bounds(),A.Now());self.last=A.Now();self.at=self.last end
        if not self.first then local lo,hi=j:Bounds();self.first,self.last=lo,hi;self.at=hi end
        if requery or self.revision~=j.revision then
            self.rows=A.SearchEvents(j:Range(self.first,self.last,self.filter,self.level),self.query,self.searchCache)
            self.revision=j.revision;self.index=nil;self.positionIndex=nil
        end
        self.offset=math.max(0,math.min(self.offset,math.max(0,math.floor((#self.rows-1)/7)*7)))
        local m=self.main
        local filtered=false
        for _,kind in ipairs(eventKinds) do if not self.filter[kind] then filtered=true;break end end
        m.filter:SetSelected(filtered);m.mapFilter:SetSelected(filtered)
        for i,line in ipairs(m.sort.lines) do line:SetSize(self.newestFirst and (11-i*2) or (i*2-1),1) end
        m.timelineScroll.syncing=true
        m.timelineScroll:SetMinMaxValues(0,math.max(0,math.floor((#self.rows-1)/7)))
        m.timelineScroll:SetValue(self.offset/7);m.timelineScroll:SetShown(#self.rows>7)
        m.timelineScroll.syncing=false
        if self.follow then
            m.from:SetText(date and date('%Y-%m-%d',self.first) or '');m.to:SetText(date and date('%Y-%m-%d',self.last) or '')
        end
        self:SyncDetailOverlay()
        m.page:SetText(string.format('%d–%d / %d events',#self.rows>0 and self.offset+1 or 0,math.min(self.offset+7,#self.rows),#self.rows))
        m.emptySearch:SetShown(#self.rows==0)
        m.emptySearch:SetText(self.query~='' and 'No matching events. Try a broader search or reset the filters.' or 'No events match the current filters.')
        for i,row in ipairs(m.rows) do
            local index=self.offset+i
            local source=self.rows[self.newestFirst and (#self.rows-index+1) or index]
            row:SetShown(source~=nil);row.record=source
            if source then
                local e=source.event;row.icon:SetTexture(A.icons[e.kind]);row.iconShadow:SetTexture(A.icons[e.kind]);A.InstanceDirection(row,row.icon,e,0.6);row.label:SetText(A.Paint(e.title,'ffd100'))
                row.status:SetText(A.Paint(A.eventNames[e.kind],A.eventColours[e.kind])..A.Paint(' • '..U.Date(e.at),'999999'))
                row.location:SetText(A.Paint((e.zone or 'Unknown location')..(e.level and (' • Level '..e.level) or ''),'bbbbbb'))
            end
        end
        self:SyncRowSelection()
        m.record:SetChecked(j.db.settings.trail~=false)
        self:RefreshStorage()
        self:SyncSlider()
        self:Journey()
    end
    local function build(content)
        c.main=content;local m=content;m.rows={}
        m.spine=m:CreateTexture(nil,'ARTWORK');m.spine:SetColorTexture(0.25,0.13,0.055,0.35)
        m.spine:SetPoint('TOPLEFT',306,-53);m.spine:SetSize(3,661)
        ns.FieldbookUI.SectionTitle(m,"Adventurer's Annals")
        m.search=U.Search(m,42,-96,194,200);m.search:SetText(c.query)
        m.search:HookScript('OnTextChanged',function(self)
            if c.searchSync then return end
            c.query=self:GetText();c.offset=0;c.selected=nil
            if #A.SearchTerms(c.query)==0 then c.searchCache={} end
            m.detail:SetEvent(nil,true);c:QueueSearchRefresh()
        end)
        m:RegisterEvent('GET_ITEM_INFO_RECEIVED')
        m:SetScript('OnEvent',function(_,_,id,success)
            local cache=c.searchCache;local keys=cache.itemKeys and cache.itemKeys[id]
            if not keys or not success then return end
            for key in pairs(keys) do cache.items[key]=nil end
            if c.query~='' and m:IsVisible() then c:QueueSearchRefresh() end
        end)
        m.from=U.Field(m,'From date',342,-71,130,10);m.to=U.Field(m,'Through date',480,-71,130,10)
        m.level=U.Field(m,'Level (optional)',618,-71,105,3)
        U.Button(m,'Apply',731,-91,75,function()
            local first,last=A.ParseDate(m.from:GetText()),A.ParseDate(m.to:GetText(),true)
            local levelText=m.level:GetText();local level=levelText~='' and tonumber(levelText) or nil
            if not first or not last or first>last or (levelText~='' and not A.Int(level,1,1000)) then c:Message('Use valid YYYY-MM-DD dates, earliest first, and an optional level.');return end
            c.level=level;c:SetRange(first,last)
        end)
        m.now=U.Button(m,'Now / reset',814,-91,106,function() c:ResetNow() end)
        local function showFilters(owner)
            m.search:ClearFocus()
            if not MenuUtil then return end
            MenuUtil.CreateContextMenu(owner,function(_,root)
                local function allSelected()
                    for _,key in ipairs(eventKinds) do if not c.filter[key] then return false end end;return true
                end
                local all=root:CreateCheckbox('All events',allSelected,function() c:SetEventFilter('all',not allSelected()) end)
                all:SetResponse(MenuResponse.Refresh)
                for _,kind in ipairs(eventKinds) do local key=kind
                    local item=root:CreateCheckbox(A.eventNames[key],function() return c.filter[key] end,function() c:SetEventFilter(key,not c.filter[key]) end)
                    item:SetResponse(MenuResponse.Refresh)
                end
            end)
        end
        m.filter=ns.FieldbookUI.FilterButton(m,244,-96,showFilters)
        m.filter.ResetFilters=function()
            c.level=nil;c.query='';c.searchCache={};c.searchSync=true;m.search:SetText('');c.searchSync=false
            m.level:SetText('')
            for _,kind in ipairs(eventKinds) do c.filter[kind]=true end
            if not j.readOnly and not ns.InitializationBlocked then j.db.settings.eventFilters=A.Copy(c.filter) end
            c:SetRange(math.min(j:Bounds(),A.Now()),A.Now())
        end
        U.StyleSelection(m.filter)
        m.filter:SetScript('OnEnter',function(self)
            if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText('Filter events\nRight-click to reset filters.');GameTooltip:Show() end
        end)
        m.filter:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
        m.sort=U.Button(m,'',270,-96,22,function(button)
            m.search:ClearFocus();c:ToggleSort()
            if GameTooltip and GameTooltip:IsOwned(button) then button:GetScript('OnEnter')(button) end
        end)
        m.sort:SetSize(22,22);m.sort.lines={}
        for row=0,4 do
            local stroke=m.sort:CreateTexture(nil,'OVERLAY')
            stroke:SetPoint('CENTER',0,2-row);stroke:SetColorTexture(1,0.82,0.14,1)
            m.sort.lines[row+1]=stroke
        end
        m.sort:SetScript('OnEnter',function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
                GameTooltip:SetText(c.newestFirst and 'Newest first' or 'Oldest first')
                GameTooltip:AddLine(c.newestFirst and 'Click for oldest first.' or 'Click for newest first.',1,1,1)
                GameTooltip:Show()
            end
        end)
        m.sort:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)

        m.show=U.Button(m,'Show detail',42,-126,250,function() c.showDetail=not c.showDetail;c:SyncDetailOverlay() end)
        U.StyleSelection(m.show)
        m.timeline=CreateFrame('Frame',nil,m);m.timeline:SetPoint('TOPLEFT',42,-155);m.timeline:SetSize(228,455)
        m.detailPane=CreateFrame('Frame',nil,m);m.detailPane:SetPoint('TOPLEFT',42,-155);m.detailPane:SetSize(250,507)
        m.detailPane:SetFrameLevel(m.timeline:GetFrameLevel()+5);m.detailPane:EnableMouse(true);m.detailPane:Hide()
        m.journey=CreateFrame('Frame',nil,m);m.journey:SetAllPoints()
        m.emptySearch=U.Label(m.timeline,'',0,-5,250,'GameFontDisableSmall');m.emptySearch:SetWordWrap(true);m.emptySearch:Hide()
        for i=1,7 do
            local row=CreateFrame('Button',nil,m.timeline,'BackdropTemplate');row:SetPoint('TOPLEFT',0,-(i-1)*65);row:SetSize(228,64)
            ns.FieldbookUI.StyleMenuRow(row)
            if i>1 then row.divider=ns.FieldbookUI.EntryDivider(row,1) end
            row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(22,22);row.icon:SetPoint('TOPLEFT',2,-8)
            row.iconShadow=row:CreateTexture(nil,'BACKGROUND');row.iconShadow:SetSize(22,22);row.iconShadow:SetPoint('TOPLEFT',row.icon,'TOPLEFT',2,-2);row.iconShadow:SetVertexColor(0,0,0,0.6)
            row.label=U.Label(row,'',32,-6,192,'GameFontNormal');row.label:SetWordWrap(false)
            row.status=U.Label(row,'',32,-24,192,'GameFontHighlightSmall');row.status:SetWordWrap(true);row.status:SetHeight(20)
            row.location=U.Label(row,'',32,-46,192,'GameFontHighlightSmall');row.location:SetWordWrap(false)
            row:SetScript('OnClick',function(self) if self.record then c:Select(self.record.id) end end)
            m.rows[i]=row
        end
        m.timeline:EnableMouseWheel(true);m.timeline:SetScript('OnMouseWheel',function(_,delta) c.offset=c.offset+(delta<0 and 7 or -7);c:Refresh() end)
        m.timelineScroll=CreateFrame('Slider',nil,m.timeline,'UIPanelScrollBarTemplate')
        m.timelineScroll.scrollStep=1;m.timelineScroll:ClearAllPoints()
        m.timelineScroll:SetPoint('TOPLEFT',m.timeline,'TOPRIGHT',3,-16);m.timelineScroll:SetSize(16,423)
        m.timelineScroll:SetValueStep(1);m.timelineScroll:SetObeyStepOnDrag(true)
        ns.StyleScrollBarTrack(m.timelineScroll,0.4)
        m.timelineScroll:SetScript('OnValueChanged',function(self,value)
            if self.syncing then return end
            c.offset=math.floor(value+0.5)*7;c:Refresh()
        end)
        m.detail=detailArea(m.detailPane)
        U.Button(m.detailPane,'Around event',0,-449,112,function() c:Around(false) end)
        U.Button(m.detailPane,'Quest interval',118,-449,132,function() c:Around(true) end)
        U.Button(m.detailPane,'Open linked journal',0,-483,250,function()
            local e=c.selected and j.db.events[c.selected]
            if not e or not e.link then c:Message('Select a linked discovery first.');return end
            local ok,message=c:OpenLink(e.link);if not ok then c:Message(message) end
        end)
        m.paging=CreateFrame('Frame',nil,m);m.paging:SetPoint('TOPLEFT',42,-618);m.paging:SetSize(250,42)
        U.Button(m.paging,'Previous',0,0,80,function() c.offset=c.offset-7;c:Refresh() end)
        U.Button(m.paging,'Next',86,0,70,function() c.offset=c.offset+7;c:Refresh() end)
        U.Button(m.paging,'Latest',162,0,80,function() c.offset=c:LatestOffset();c:Refresh() end)
        m.page=U.Label(m.paging,'',0,-26,250,'GameFontHighlightSmall')
        m.map=ns.CreateAnnalsMap(m.journey,j,function(id) c:Select(id,true);c.showDetail=true;c:SyncDetailOverlay() end,function(id) c.mapID=id;c.index=nil;c:Journey() end)
        m.mapFilter=ns.FieldbookUI.FilterButton(m.map,0,0,showFilters)
        m.mapFilter.ResetFilters=m.filter.ResetFilters
        m.mapFilter:ClearAllPoints();m.mapFilter:SetPoint('TOPLEFT',m.map,'TOPLEFT',8,-8)
        m.mapFilter:SetFrameLevel(m.map:GetFrameLevel()+25);U.StyleSelection(m.mapFilter)
        m.mapFilter:SetScript('OnEnter',m.filter:GetScript('OnEnter'));m.mapFilter:SetScript('OnLeave',m.filter:GetScript('OnLeave'))
        m.map:SetPoint('TOP',m.journey,'TOPLEFT',632,-205)
        m.zoneMenu=U.ZoneMenu(m.journey,0,0,256,function() return c:Maps() end,function(id) c.mapID=id;c.index=nil;c:Journey() end)
        m.zoneMenu:ClearAllPoints();m.zoneMenu:SetPoint('TOPLEFT',m.journey,'TOPLEFT',342,-174)
        m.legend=CreateFrame('Frame',nil,m.map,'BackdropTemplate');m.legend:SetSize(500,348)
        m.legend:SetPoint('TOP',m.map,'TOP',0,-8);m.legend:SetFrameLevel(m.map:GetFrameLevel()+20);m.legend:EnableMouse(true)
        m.legend:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=16})
        m.legend:SetBackdropColor(0.06,0.045,0.025,0.97);m.legend:Hide()
        U.Label(m.legend,'Journey legend',16,-16,410,'GameFontNormal')
        m.legend.icons={};m.legend.arrows={};m.legend.trails={}
        local legendEntries={}
        for _,kind in ipairs(eventKinds) do
            if kind=='instance' then
                legendEntries[#legendEntries+1]={kind=kind,instanceAction='enter',label='Instance entry'}
                legendEntries[#legendEntries+1]={kind=kind,instanceAction='exit',label='Instance exit'}
            else legendEntries[#legendEntries+1]={kind=kind,label=A.eventNames[kind]} end
        end
        for i,entry in ipairs(legendEntries) do
            local holder=CreateFrame('Frame',nil,m.legend);holder:SetSize(20,20);holder:SetPoint('TOPLEFT',16,-46-(i-1)*22)
            local icon=holder:CreateTexture(nil,'ARTWORK');icon:SetTexture(A.icons[entry.kind]);icon:SetAllPoints();A.InstanceDirection(holder,icon,entry)
            m.legend.icons[entry.instanceAction or entry.kind]=icon;U.Label(m.legend,entry.label,44,-49-(i-1)*22,208,'GameFontHighlightSmall')
        end
        for i,entry in ipairs({{'Alive / unknown','alive'},{'Flying','flight'},{'Dead','dead'},{'Ghost','ghost'}}) do
            local icon=m.legend:CreateTexture(nil,'ARTWORK');icon:SetTexture('Interface\\Minimap\\MinimapArrow');icon:SetVertexColor(A.PlayerColor(entry[2]))
            icon:SetSize(20,20);icon:SetPoint('TOPLEFT',270,-46-(i-1)*26);m.legend.arrows[i]=icon
            U.Label(m.legend,entry[1],299,-49-(i-1)*26,178,'GameFontHighlightSmall')
        end
        for i,entry in ipairs({{'Recent trail',0,false},{'Older trail (1 hour)',3600,false},{'Flight trail',0,true},{'60% mount (Rare)',0,false,60},{'100% mount (Epic)',0,false,100}}) do
            local line=m.legend:CreateTexture(nil,'ARTWORK');line:SetSize(25,3);line:SetPoint('TOPLEFT',267,-178-(i-1)*26)
            m.legend.trails[i]={texture=line,age=entry[2],flight=entry[3],mount=entry[4]}
            U.Label(m.legend,entry[1],299,-173-(i-1)*26,178,'GameFontHighlightSmall')
        end
        U.Label(m.legend,'Instance visits hold the arrow at the observed entrance.',270,-302,208,'GameFontDisableSmall'):SetWordWrap(true)
        function m.legend:RefreshTrails()
            for _,entry in ipairs(m.legend.trails) do
                local r,g,b,alpha=A.TrailColor(entry.age,0,j.db.settings.trailContrast,entry.flight,entry.mount);entry.texture:SetColorTexture(r,g,b,alpha)
            end
        end
        m.legendButton=U.Button(m.journey,'Legend',0,0,65,function()
            m.legend:RefreshTrails()
            m.legend:SetShown(not m.legend:IsShown())
            m.legendButton:SetSelected(m.legend:IsShown())
        end)
        U.StyleSelection(m.legendButton)
        m.legend:SetScript('OnHide',function() m.legendButton:SetSelected(false) end)
        m.legendButton:ClearAllPoints();m.legendButton:SetPoint('TOPLEFT',m.journey,'TOPLEFT',857,-174)
        m.followPlayer=U.Button(m.journey,'Follow player',0,0,110,function() c:ToggleFollowPlayer() end);U.StyleSelection(m.followPlayer)
        m.followPlayer:ClearAllPoints();m.followPlayer:SetPoint('RIGHT',m.legendButton,'LEFT',-6,0)
        m.findPlayer=U.Button(m.journey,'Find player',0,0,100,function() c:FindPlayer() end)
        m.findPlayer:ClearAllPoints();m.findPlayer:SetPoint('RIGHT',m.followPlayer,'LEFT',-6,0)
        m.journey:SetScript('OnHide',function() m.legend:Hide() end)
        m.around=U.Button(m.journey,'Around selected event',342,-129,200,function() c:Around(false) end)
        m.around:SetScript('OnEnter',function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText('Around selected event')
            GameTooltip:AddLine('Selects a one-hour window: 30 minutes before and 30 minutes after the selected event. Pauses playback.',1,1,1,true)
            local e=c.selected and j.db.events[c.selected]
            if e then GameTooltip:AddLine(U.Date(math.max(0,e.at-1800))..' — '..U.Date(e.at+1800),1,0.82,0.14,true)
            else GameTooltip:AddLine('Select a timeline event or map marker first.',0.6,0.6,0.6,true) end
            GameTooltip:Show()
        end)
        m.around:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
        m.around:SetScript('OnHide',function() if GameTooltip then GameTooltip:Hide() end end)
        m.footerBackground=U.FooterBackground(m.journey,shell)
        m.slider=CreateFrame('Slider',nil,m.journey,'OptionsSliderTemplate');m.slider:SetPoint('TOPLEFT',355,-618);m.slider:SetSize(545,18)
        m.slider.track=m.slider:CreateTexture(nil,'BACKGROUND')
        m.slider.track:SetPoint('TOPLEFT',2,-4);m.slider.track:SetPoint('BOTTOMRIGHT',-2,4)
        m.slider.track:SetColorTexture(0,0,0,1)
        m.slider:SetValueStep(1);m.slider:SetObeyStepOnDrag(true)
        for _,key in ipairs({'Low','High','Text'}) do local region=m.slider[key];if type(region)=='table' or type(region)=='userdata' then region:Hide() end end
        m.slider:SetScript('OnValueChanged',function(self,value)
            if self.syncing then return end;c:PausePlayback();c.follow=false
            c.at=math.max(c.first,math.min(c.last,c.sliderStart+math.floor(value+0.5)))
            if c.scrubPending then return end
            if C_Timer and C_Timer.After then c.scrubPending=true;C_Timer.After(0.1,function() c.scrubPending=false;if m:IsVisible() then c:Journey() end end)
            else c:Journey() end
        end)
        m.slider:EnableMouseWheel(true)
        m.slider:SetScript('OnMouseWheel',function(_,delta) c:Seek((c.at or c.last)+(delta>0 and 1 or -1)) end)
        m.play=U.Button(m.journey,'',350,-671,24,function() c:TogglePlayback() end)
        m.play:SetSize(24,24)
        m.play.symbol=m.play:CreateTexture(nil,'OVERLAY');m.play.symbol:SetTexture('Interface\\ChatFrame\\ChatFrameExpandArrow')
        m.play.symbol:SetSize(14,16);m.play.symbol:SetPoint('CENTER',1,0)
        m.play.pauseBars={}
        for i=1,2 do
            local bar=m.play:CreateTexture(nil,'OVERLAY');bar:SetColorTexture(1,0.82,0.14,1)
            bar:SetSize(3,10);bar:SetPoint('CENTER',i==1 and -3 or 3,0);m.play.pauseBars[i]=bar
        end
        m.play:SetScript('OnEnter',function(self) if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText(self.tooltipText);GameTooltip:Show() end end)
        m.play:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
        c:SyncPlayButton()
        m.speeds={}
        for i,speed in ipairs({1,8,32,64,128,256}) do local rate=speed
            m.speeds[rate]=U.Button(m.journey,tostring(rate)..'x',380+(i-1)*47,-671,45,function() c:SetPlaybackSpeed(rate) end)
        end
        m.speeds[1]:SetEnabled(false)
        m.timeZoom=U.MenuButton(m.journey,'Full range',665,-671,115,function()
            if not MenuUtil then return end
            MenuUtil.CreateContextMenu(m.timeZoom,function(_,root)
                for _,choice in ipairs({{'Full range',false},{'3 hours',10800},{'1 hour',3600},{'15 minutes',900}}) do
                    local label,span=choice[1],choice[2]
                    root:CreateButton(label,function() c.sliderSpan=span or nil;c.sliderStart=nil;m.timeZoom:SetText(label);c:SyncSlider();c:Journey() end)
                end
            end)
        end)
        m.customSpeed=U.Field(m.journey,'Custom speed (x)',792,-650,128,7)
        m.customSpeed:SetText('1')
        m.customSpeed:SetScript('OnEnterPressed',function(self)
            if c:SetPlaybackSpeed(tonumber(self:GetText()))==false then
                c:Message('Enter a playback speed from 0.1 to 4096.');self:SetText(tostring(c.playbackSpeed))
            end
            self:ClearFocus()
        end)
        m.customSpeed:SetScript('OnEscapePressed',function(self) self:SetText(tostring(c.playbackSpeed));self:ClearFocus() end)
        m.clock=U.Label(m.journey,'',350,-641,430,'GameFontHighlightSmall')
        U.Label(m.journey,'Map icon size',646,-594,92,'GameFontNormalSmall'):SetWordWrap(false)
        m.iconSize=CreateFrame('Slider',nil,m.journey,'OptionsSliderTemplate')
        m.iconSize:SetPoint('TOPLEFT',746,-591);m.iconSize:SetSize(110,18)
        m.iconSize.track=m.iconSize:CreateTexture(nil,'BACKGROUND')
        m.iconSize.track:SetPoint('TOPLEFT',2,-4);m.iconSize.track:SetPoint('BOTTOMRIGHT',-2,4)
        m.iconSize.track:SetColorTexture(0,0,0,1)
        m.iconSize:SetMinMaxValues(6,40);m.iconSize:SetValueStep(1);m.iconSize:SetObeyStepOnDrag(true)
        for _,key in ipairs({'Low','High','Text'}) do local region=m.iconSize[key];if type(region)=='table' or type(region)=='userdata' then region:Hide() end end
        local iconSize=ns.Atlas.Number(j.db.settings.iconSize,6,40) and j.db.settings.iconSize or 20
        m.iconSize:SetValue(iconSize)
        m.iconSizeValue=U.Label(m.journey,tostring(iconSize),868,-594,48,'GameFontHighlightSmall')
        m.iconSize:SetScript('OnValueChanged',function(_,value)
            if j.readOnly or ns.InitializationBlocked or not ns.Atlas.Number(value,6,40) then return end
            value=math.floor(value+0.5);j.db.settings.iconSize=value;m.iconSizeValue:SetText(tostring(value));c:Journey()
        end)
        U.Label(m.journey,'Trail age contrast',350,-594,118,'GameFontNormalSmall'):SetWordWrap(false)
        m.contrast=CreateFrame('Slider',nil,m.journey,'OptionsSliderTemplate')
        m.contrast:SetPoint('TOPLEFT',476,-591);m.contrast:SetSize(98,18)
        m.contrast.track=m.contrast:CreateTexture(nil,'BACKGROUND')
        m.contrast.track:SetPoint('TOPLEFT',2,-4);m.contrast.track:SetPoint('BOTTOMRIGHT',-2,4)
        m.contrast.track:SetColorTexture(0,0,0,1)
        for _,key in ipairs({'Low','High','Text'}) do local region=m.contrast[key];if type(region)=='table' or type(region)=='userdata' then region:Hide() end end
        m.contrast:SetMinMaxValues(0,100);m.contrast:SetValueStep(5);m.contrast:SetObeyStepOnDrag(true)
        local contrast=ns.Atlas.Number(j.db.settings.trailContrast,0,1) and j.db.settings.trailContrast or 0.75
        m.contrast:SetValue(contrast*100)
        m.contrastValue=U.Label(m.journey,math.floor(contrast*100+0.5)..'%',582,-594,44,'GameFontHighlightSmall')
        m.contrast:SetScript('OnEnter',function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText('Trail age contrast')
            GameTooltip:AddLine('0%: uniform gold\n100%: strongest cooling and fading\nRecent: warm gold • Older: cool blue\nHalf cooled after 30 minutes.',1,1,1,true)
            GameTooltip:Show()
        end)
        m.contrast:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
        m.contrast:SetScript('OnHide',function() if GameTooltip then GameTooltip:Hide() end end)
        m.contrast:SetScript('OnValueChanged',function(_,value)
            if j.readOnly or ns.InitializationBlocked or not ns.Atlas.Number(value,0,100) then return end
            value=math.floor(value/5+0.5)*5
            j.db.settings.trailContrast=value/100;m.contrastValue:SetText(value..'%')
            if m.legend:IsShown() then m.legend:RefreshTrails() end
            c:Journey()
        end)
        m.recordConfirm=CreateFrame('Frame',nil,m);m.recordConfirm:SetAllPoints();m.recordConfirm:SetFrameLevel(m:GetFrameLevel()+40);m.recordConfirm:EnableMouse(true);m.recordConfirm:Hide()
        local shade=m.recordConfirm:CreateTexture(nil,'BACKGROUND');shade:SetAllPoints();shade:SetColorTexture(0,0,0,0.45)
        local dialog=CreateFrame('Frame',nil,m.recordConfirm,'BackdropTemplate');dialog:SetSize(360,132);dialog:SetPoint('CENTER');dialog:EnableMouse(true)
        dialog:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=20});dialog:SetBackdropColor(0.09,0.065,0.035,1)
        U.Label(dialog,'Stop recording your Journey?',24,-26,312,'GameFontNormal')
        m.recordConfirm.yes=U.Button(dialog,'Yes',70,-82,95,function()
            j.trail:SetEnabled(false);m.record:SetChecked(j.db.settings.trail~=false);m.recordConfirm:Hide()
        end)
        m.recordConfirm.no=U.Button(dialog,'No',195,-82,95,function() m.recordConfirm:Hide() end)
        m.record=U.Check(m,'Record Journey',48,-671,160,function(value)
            if value then j.trail:SetEnabled(true)
            elseif j.db.settings.trail~=false then m.recordConfirm:Show() end
            m.record:SetChecked(j.db.settings.trail~=false)
        end)
        U.Button(m,'Refresh',218,-672,74,function() c.index=nil;c:Refresh(true) end)
        m.capacity=U.Label(m,'',42,-701,250,'GameFontDisableSmall');m.capacity:SetWordWrap(false)
        m.capacityHover=CreateFrame('Frame',nil,m);m.capacityHover:SetPoint('TOPLEFT',42,-699);m.capacityHover:SetSize(250,20)
        m.capacityHover:EnableMouse(true)
        m.capacityHover:SetScript('OnEnter',function(self)
            local title,detail=j:StorageStatus();m.capacity:SetText(title)
            if GameTooltip then
                GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(title);GameTooltip:AddLine(detail,1,1,1,true);GameTooltip:Show()
            end
        end)
        m.capacityHover:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
        -- Journey samples can grow without a new event. Only poll while visible.
        local storageElapsed=0
        m:SetScript('OnUpdate',function(_,elapsed)
            c:TickPlayback(elapsed)
            storageElapsed=storageElapsed+elapsed
            if storageElapsed>=30 then storageElapsed=0;c:RefreshStorage() end
        end)
        m.message=U.Label(m,'',342,-712,580,'GameFontHighlightSmall');m.message:SetWordWrap(false)
        m:SetScript('OnHide',function()
            c:PausePlayback();m.from:ClearFocus();m.to:ClearFocus();m.level:ClearFocus();m.search:ClearFocus()
            c.searchCache={};c.index=nil
            m.recordConfirm:Hide();m.legend:Hide()
            if GameTooltip then GameTooltip:Hide() end
        end)
        c:SetRange(j:Bounds());c.follow=true
        if j.readOnly then c:Message('Unsupported or malformed Annals store: recording disabled; original data preserved.') end
    end
    shell:RegisterSection('annals',{title="Adventurer's Annals",icon='Interface\\Icons\\INV_Misc_PocketWatch_02',
        frameName='AzerothFieldbookAnnalsSection',help=HELP,build=build,onOpen=function() c:Refresh(true) end})
    return c
end
