local _,ns=...
local A,U=ns.Annals,ns.AtlasUI
local HELP="Your character writes this history automatically: quest acceptance, removal and confirmed turn-in, plus flight departures and lightweight links to Fieldbook discoveries. Existing quests are not backfilled. Removed does not always mean abandoned.\n\nJourney Trail is a separate approximate route. Uncheck Record Journey to stop future breadcrumbs; events and their locations remain. No history is erased. Balanced recording checks every two seconds but keeps ordinary points roughly 15–60 seconds apart while moving; stationary players add no periodic points. Events and segment endpoints are exceptions. Loading and missing positions leave gaps. Subzone names do not interrupt flights.\n\nEnter dates as YYYY-MM-DD, optionally a character level, then Apply. Dates use your computer's local calendar. Select an event and Around event to inspect its surrounding hour, or Quest interval for discoveries during its observed acceptance-to-removal/turn-in period. Temporal overlap never means a quest caused those discoveries.\n\nThe timeline runs oldest to newest. Use Latest, page buttons or the mouse wheel. Show Journey opens the map for the selected dates. Choose a historical map and drag the time slider. Routes and markers also project onto continent and world maps where the client supplies map rectangles. Existing saved gaps are preserved. The clock uses recorded timestamps; the position is the latest actual sample, not an invented constant-speed location.\n\nLarge map ranges display at most 64 recent chunks, 2,048 lines and 512 events at the selected time (Atlas groups at most 192 visible pins). Scrub earlier or narrow dates for older geometry. The timeline always retains all matching events.\n\nReward choices are recorded only when an observed reward request matches a confirmed turn-in and readable offered item metadata. Automatic items are labelled separately. XP and copper come from the turn-in event. Currency offers are recorded where readable and labelled as offered amounts, not measured balance changes. Reputation and spell rewards are not captured; missing item metadata remains unknown. Source inspection and mock tests still require in-game API validation.\n\nAll history is local and character-specific, regardless of account tracking. SavedVariables persist on a successful logout or /reload; a client crash may lose the current session, as with other journals."
function A.ParseDate(text,ending)
    if not A.Text(text,10) then return end
    local y,m,d=text:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$');y,m,d=tonumber(y),tonumber(m),tonumber(d)
    if not y or y<1970 or y>2200 or m<1 or m>12 or d<1 or d>31 or type(time)~='function' then return end
    local stamp=A.Read(time,{year=y,month=m,day=d,hour=ending and 23 or 0,min=ending and 59 or 0,sec=ending and 59 or 0})
    if not A.Int(stamp,0,9999999999) or (date and date('%Y-%m-%d',stamp)~=text) then return end
    return stamp
end
function ns.CreateAnnalsBook(j,shell)
    local c={journal=j,shell=shell,offset=0,filter='all',rows={},mode='timeline'}
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
        self.follow=false
        self.first,self.last=first,last;self.at=last;self.offset=0;self.index=nil
        if self.main then
            self.main.from:SetText(date and date('%Y-%m-%d',first) or '')
            self.main.to:SetText(date and date('%Y-%m-%d',last) or '')
        end
        self:Refresh(true)
    end
    function c:Select(id)
        id=tonumber(id);local e=id and j.db.events[id];if not A.ValidEvent(e) then return end
        self.selected=id;self.mapID=e.mapID or self.mapID
        if self.main then self.main.detail:SetText(A.EventText(e),true) end
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
        self:SetRange(math.max(0,first),last);self.mode='journey';self:Refresh()
    end
    function c:Journey()
        if not self.main or self.mode~='journey' then return end
        self.mapID=self.mapID or (self:Maps()[1] or {}).mapID
        if not self.index or self.index.mapID~=self.mapID then self.index=A.JourneyIndex(j,self.first,self.last,self.mapID,self.filter,self.level) end
        local cursor,limited,invalid=self.main.map:ShowJourney(self.index,self.at or self.last)
        self.main.clock:SetText(U.Date(self.at or self.last)..(cursor and (' • Last sample '..U.Date(cursor.at)..string.format(' • %.1f, %.1f',cursor.x/100,cursor.y/100)) or ' • No sample on this map yet'))
        local level=cursor and cursor.level;local lo,hi=1,#self.rows
        while lo<=hi do local mid=math.floor((lo+hi)/2);if self.rows[mid].event.at<=(self.at or self.last) then lo=mid+1 else hi=mid-1 end end
        if not level and self.rows[hi] then level=self.rows[hi].event.level end
        self.main.levelAt:SetText(level and ('Recorded level '..level) or 'Level unknown in this interval')
        self:Message((limited and 'Dense range: recent geometry shown. Scrub earlier or narrow dates. ' or 'Recorded routes projected onto this map. ')
            ..(invalid>0 and (invalid..' malformed segments preserved but not drawn. ') or '')
            ..(self.main.map.linesAvailable==false and 'Line rendering unavailable; markers and stored history remain.' or ''))
    end
    function c:Refresh(requery)
        if not self.main then return end
        if self.follow then self.first,self.last=j:Bounds();self.at=self.last end
        if not self.first then local lo,hi=j:Bounds();self.first,self.last=lo,hi;self.at=hi end
        if requery or self.revision~=j.revision then self.rows=j:Range(self.first,self.last,self.filter,self.level);self.revision=j.revision;self.index=nil end
        self.offset=math.max(0,math.min(self.offset,math.max(0,math.floor((#self.rows-1)/7)*7)))
        local m=self.main;local journey=self.mode=='journey'
        m.timeline:SetShown(not journey);m.journey:SetShown(journey)
        m.show:SetText(journey and 'Show Timeline' or 'Show Journey')
        m.page:SetText(string.format('%d–%d / %d events',#self.rows>0 and self.offset+1 or 0,math.min(self.offset+7,#self.rows),#self.rows))
        for i,row in ipairs(m.rows) do local source=self.rows[self.offset+i]
            row:SetShown(source~=nil);row.record=source
            if source then
                local e=source.event;row.icon:SetTexture(A.icons[e.kind]);row.label:SetText(ns.Atlas.Safe(U.Date(e.at)..' — '..A.eventNames[e.kind]..'\n'..e.title..'\n'..(e.zone or 'Unknown location')..(e.level and (' • Level '..e.level) or '')))
            end
        end
        m.record:SetChecked(j.db.settings.trail~=false)
        if journey then
            m.slider.syncing=true;m.slider:SetMinMaxValues(self.first,math.max(self.first+1,self.last));m.slider:SetValue(self.at or self.last);m.slider.syncing=false
            self:Journey()
        end
    end
    local function build(content)
        c.main=content;local m=content;m.rows={}
        U.Label(m,"Adventurer's Annals",48,-64,600,'GameFontNormalLarge')
        m.from=U.Field(m,'From date',48,-92,145,10);m.to=U.Field(m,'Through date',205,-92,145,10)
        m.level=U.Field(m,'Level (optional)',362,-92,115,3)
        U.Button(m,'Apply',494,-112,75,function()
            local first,last=A.ParseDate(m.from:GetText()),A.ParseDate(m.to:GetText(),true)
            local levelText=m.level:GetText();local level=levelText~='' and tonumber(levelText) or nil
            if not first or not last or first>last or (levelText~='' and not A.Int(level,1,1000)) then c:Message('Use valid YYYY-MM-DD dates, earliest first, and an optional level.');return end
            c.level=level;c:SetRange(first,last)
        end)
        U.Button(m,'All dates',575,-112,90,function() c.level=nil;m.level:SetText('');c:SetRange(j:Bounds());c.follow=true end)
        m.filter=U.MenuButton(m,'Event filter',672,-112,120,function()
            if not MenuUtil then return end
            MenuUtil.CreateContextMenu(m.filter,function(_,root)
                for _,kind in ipairs({'all','accepted','removed','completed','discovery','flight'}) do local key=kind
                    root:CreateButton(A.eventNames[key] or 'All events',function() c.filter=key;c.offset=0;c:Refresh(true) end)
                end
            end)
        end)
        m.show=U.Button(m,'Show Journey',798,-112,122,function() c.mode=c.mode=='journey' and 'timeline' or 'journey';c.index=nil;c:Refresh() end)
        m.timeline=CreateFrame('Frame',nil,m);m.timeline:SetAllPoints()
        m.journey=CreateFrame('Frame',nil,m);m.journey:SetAllPoints();m.journey:Hide()
        for i=1,7 do
            local row=CreateFrame('Button',nil,m.timeline);row:SetPoint('TOPLEFT',48,-155-(i-1)*65);row:SetSize(485,60)
            row:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
            row.icon=row:CreateTexture(nil,'ARTWORK');row.icon:SetSize(22,22);row.icon:SetPoint('TOPLEFT',2,-5)
            row.label=U.Label(row,'',32,-3,446,'GameFontHighlightSmall');row.label:SetSpacing(3)
            row:SetScript('OnClick',function(self) if self.record then c:Select(self.record.id) end end)
            m.rows[i]=row
        end
        m.timeline:EnableMouseWheel(true);m.timeline:SetScript('OnMouseWheel',function(_,delta) c.offset=c.offset+(delta<0 and 7 or -7);c:Refresh() end)
        m.detail=U.ReadArea(m.timeline,553,-157,340,364);m.detail:SetText('Select an event to read its historical details.',true)
        U.Button(m.timeline,'Around event',553,-537,155,function() c:Around(false) end)
        U.Button(m.timeline,'Quest interval',723,-537,170,function() c:Around(true) end)
        U.Button(m.timeline,'Open linked journal',553,-572,340,function()
            local e=c.selected and j.db.events[c.selected]
            if not e or not e.link then c:Message('Select a linked discovery first.');return end
            local ok,message=c:OpenLink(e.link);if not ok then c:Message(message) end
        end)
        U.Button(m.timeline,'Previous',48,-618,95,function() c.offset=c.offset-7;c:Refresh() end)
        U.Button(m.timeline,'Next',148,-618,75,function() c.offset=c.offset+7;c:Refresh() end)
        U.Button(m.timeline,'Latest',228,-618,75,function() c.offset=math.max(0,math.floor((#c.rows-1)/7)*7);c:Refresh() end)
        m.page=U.Label(m.timeline,'',319,-624,214,'GameFontHighlightSmall')
        m.map=ns.CreateAnnalsMap(m.journey,j,function(id) c:Select(id);c.mode='timeline';c:Refresh() end,function(id) c.mapID=id;c.index=nil;c:Journey() end)
        m.map:SetPoint('TOP',m.journey,'TOPLEFT',632,-205)
        U.ZoneMenu(m.journey,48,-160,270,function() return c:Maps() end,function(id) c.mapID=id;c.index=nil;c:Journey() end)
        U.Label(m.journey,'Historical maps\n\nAccepted: !\nCompleted: ?\nRemoved: parchment\nDiscoveries: map\nFlights: flight master\n\nRecorded routes also appear on continent and world maps. Missing observations leave gaps.',48,-213,260,'GameFontHighlightSmall')
        U.Button(m.journey,'Around selected event',48,-410,270,function() c:Around(false) end)
        m.slider=CreateFrame('Slider',nil,m.journey,'OptionsSliderTemplate');m.slider:SetPoint('TOPLEFT',355,-610);m.slider:SetSize(545,18)
        m.slider.track=m.slider:CreateTexture(nil,'BACKGROUND')
        m.slider.track:SetPoint('TOPLEFT',2,-4);m.slider.track:SetPoint('BOTTOMRIGHT',-2,4)
        m.slider.track:SetColorTexture(0,0,0,1)
        m.slider:SetValueStep(1);m.slider:SetObeyStepOnDrag(true)
        for _,key in ipairs({'Low','High','Text'}) do local region=m.slider[key];if type(region)=='table' or type(region)=='userdata' then region:Hide() end end
        m.slider:SetScript('OnValueChanged',function(self,value)
            if self.syncing then return end;c.at=math.max(c.first,math.min(c.last,math.floor(value)))
            if c.scrubPending then return end
            if C_Timer and C_Timer.After then c.scrubPending=true;C_Timer.After(0.1,function() c.scrubPending=false;if m:IsVisible() then c:Journey() end end)
            else c:Journey() end
        end)
        m.clock=U.Label(m.journey,'',350,-644,558,'GameFontHighlightSmall')
        m.levelAt=U.Label(m.journey,'',48,-465,275,'GameFontNormalSmall')
        U.Label(m.journey,'Trail age contrast',48,-500,210,'GameFontNormalSmall')
        m.contrast=CreateFrame('Slider',nil,m.journey,'OptionsSliderTemplate')
        m.contrast:SetPoint('TOPLEFT',48,-525);m.contrast:SetSize(210,18)
        m.contrast.track=m.contrast:CreateTexture(nil,'BACKGROUND')
        m.contrast.track:SetPoint('TOPLEFT',2,-4);m.contrast.track:SetPoint('BOTTOMRIGHT',-2,4)
        m.contrast.track:SetColorTexture(0,0,0,1)
        for _,key in ipairs({'Low','High','Text'}) do local region=m.contrast[key];if type(region)=='table' or type(region)=='userdata' then region:Hide() end end
        m.contrast:SetMinMaxValues(0,100);m.contrast:SetValueStep(5);m.contrast:SetObeyStepOnDrag(true)
        local contrast=ns.Atlas.Number(j.db.settings.trailContrast,0,1) and j.db.settings.trailContrast or 0.75
        m.contrast:SetValue(contrast*100)
        m.contrastValue=U.Label(m.journey,math.floor(contrast*100+0.5)..'%',270,-528,48,'GameFontHighlightSmall')
        U.Label(m.journey,'0%: uniform gold\n100%: strongest cooling and fading\nRecent: warm gold • Older: cool blue\nHalf cooled after 30 minutes.',48,-554,270,'GameFontHighlightSmall')
        m.contrast:SetScript('OnValueChanged',function(_,value)
            if j.readOnly or ns.InitializationBlocked or not ns.Atlas.Number(value,0,100) then return end
            value=math.floor(value/5+0.5)*5
            j.db.settings.trailContrast=value/100;m.contrastValue:SetText(value..'%')
            c:Journey()
        end)
        m.record=U.Check(m,'Record Journey',48,-660,160,function(value) j.trail:SetEnabled(value) end)
        U.Button(m,'Refresh',218,-661,90,function() c.index=nil;c:Refresh(true) end)
        U.Button(m,'Storage',316,-661,85,function()
            local points,bytes=0,0;for _,s in ipairs(j.db.segments) do if type(s)=='table' and type(s.data)=='string' then points=points+#s.data/9;bytes=bytes+#s.data end end
            c:Message(string.format('%d events • %d segments • %d points • %.2f MiB trail payload (headers and events additional).',#j.events,#j.db.segments,points,bytes/1048576))
        end)
        m.message=U.Label(m,'',48,-699,860,'GameFontHighlightSmall')
        m:SetScript('OnHide',function() m.from:ClearFocus();m.to:ClearFocus();m.level:ClearFocus();if GameTooltip then GameTooltip:Hide() end end)
        c:SetRange(j:Bounds());c.follow=true
        if j.readOnly then c:Message('Unsupported or malformed Annals store: recording disabled; original data preserved.') end
    end
    local function buildTabIcon(tab)
        tab.Icon:SetColorTexture(0.04,0.025,0.01,1)
        tab.questMarkers={}
        for i,kind in ipairs({'completed','accepted'}) do
            local marker=tab:CreateTexture(nil,'ARTWORK',nil,i)
            marker:SetTexture(A.icons[kind]);marker:SetSize(28,28)
            marker:SetPoint('CENTER',tab.Icon,'CENTER',i==1 and -7 or 7,i==1 and 7 or -7)
            tab.questMarkers[i]=marker
        end
    end
    shell:RegisterSection('annals',{title="Adventurer's Annals",icon=A.icons.completed,buildTabIcon=buildTabIcon,
        frameName='AzerothFieldbookAnnalsSection',help=HELP,build=build,onOpen=function() c:Refresh(true) end})
    return c
end
