import unittest
from annals_test_harness import client
from test_player_names_preservation import full_client
from atlas_test_harness import ENV

LOG_REWARDS = '''
    logPresent=true;logReady=false;selectedQuest=99;logReads=0;questRequests=0
    C_QuestLog.GetLogIndexForQuestID=function(id) if logPresent then return id end end
    C_QuestLog.GetInfo=function(index) return {questID=index,title='Logged quest '..index} end
    C_QuestLog.GetSelectedQuest=function() return selectedQuest end
    C_QuestLog.SetSelectedQuest=function(id) selectedQuest=id;t:Event('QUEST_LOG_UPDATE') end
    C_QuestLog.RequestLoadQuestByID=function(id) assert(id==42);questRequests=questRequests+1 end
    function GetNumQuestLogChoices(id,includeCurrency) assert(selectedQuest==id and includeCurrency);return 2 end
    function GetNumQuestLogRewards() return 1 end
    function GetQuestLogChoiceInfo(i)
        logReads=logReads+1;assert(selectedQuest==42)
        if logReady then return 'Log choice '..i,123,1,2,true,100+i end
    end
    function GetQuestLogRewardInfo(i) if logReady then return 'Log supplies',123,3,2,true,200+i end end
    function GetQuestLogItemLink(kind,i) return '|Hitem:'..((kind=='choice' and 100 or 200)+i)..':0|h[Reward]|h' end
    function GetQuestLogRewardXP() return 700 end
    function GetQuestLogRewardMoney() return 23456 end
'''


class AnnalsTests(unittest.TestCase):
    def test_recent_trail_window_and_marker_fading(self):
        l=client();l.execute('''
            local A=ns.Annals
            local j=ns.CreateAnnalsJournal({})
            local data=''
            for at=0,1800,300 do data=data..A.EncodePoint({x=at,y=1000,at=at},math.max(0,at-300)) end
            j.db.segments={{v=1,mapID=101,at=0,finish=1800,data=data,mount=60}}
            for i=1,20 do j:Append('accepted','Event '..i,nil,{mapID=101,x=i*100,y=2000},i*80) end
            local idx=A.JourneyIndex(j,0,1800,101);idx.trailSpan=900
            local lines,markers=A.JourneyFrame(idx,1750)
            assert(#markers==15 and markers[1].event.title=='Event 6' and markers[15].event.title=='Event 20')
            for i=1,5 do assert(math.abs(markers[i].alpha-i/6)<0.0001) end
            for i=6,15 do assert(markers[i].alpha==1) end
            local earliest=1800
            for _,edge in ipairs(lines) do
                assert(edge.from.at>=850 and edge.to.at<=1750)
                earliest=math.min(earliest,edge.from.at)
                assert(edge.from.mount==60 and edge.to.mount==60)
            end
            assert(earliest==850,'must clip an edge crossing the duration boundary')
            idx.trailSpan=nil
            assert(#A.JourneyFrame(idx,1750)>#lines,'full range should restore older geometry')
            local r,g,b=A.TrailColor(0,0,1,false,60)
            assert(r==0 and g==112/255 and b==221/255)
            r,g,b=A.TrailColor(0,0,1,false,100)
            assert(r==163/255 and g==53/255 and b==238/255)
            r,g,b=A.TrailColor(0,0,1,true,100);assert(g>r and g>b,'taxi colour takes priority')
        ''')

    def test_mount_capture_and_segment_transitions(self):
        l=client();l.execute('''
            local A=ns.Annals
            IsMounted=function() return true end
            GetUnitSpeed=function() return 0,11.2 end
            assert(A.Location().mount==60,'stationary mounts need maximum run speed')
            GetUnitSpeed=function() return 0,14 end
            assert(A.Location().mount==100)
            IsMounted=function() return false end
            assert(A.Location().mount==0)
            local j=ns.CreateAnnalsJournal({});local trail=ns.CreateAnnalsTrail(j)
            trail:Sample({at=100,mapID=101,x=100,y=100,mount=60},true)
            trail:Sample({at=102,mapID=101,x=200,y=100,mount=100},true)
            trail:Sample({at=104,mapID=101,x=300,y=100,mount=0},true)
            assert(#j.db.segments==3)
            assert(j.db.segments[2].joinFrom==1 and j.db.segments[3].joinFrom==2)
            assert(A.Decode(j.db.segments[1])[1].mount==60 and A.Decode(j.db.segments[2])[1].mount==100)
            assert(not A.Decode(j.db.segments[3])[1].mount)
        ''')

    def test_custom_playback_and_timeline_scrollbar(self):
        l=full_client();l.execute(ENV);l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            for i=1,20 do j:Append('accepted','Event '..i,nil,{mapID=101,x=i*100,y=100},100+i) end
            c.shell:ShowSection('annals');c:SetRange(100,200)
            local m=c.main
            assert(m.timelineScroll:IsShown())
            m.timelineScroll.scripts.OnValueChanged(m.timelineScroll,2)
            assert(c.offset==14 and m.rows[1].record.event.title=='Event 15')
            m.customSpeed:SetText('2.5');m.customSpeed.scripts.OnEnterPressed(m.customSpeed)
            assert(c.playbackSpeed==2.5)
            c:Seek(100);c:TogglePlayback();c:TickPlayback(2)
            assert(c.at==105)
            m.customSpeed:SetText('0');m.customSpeed.scripts.OnEnterPressed(m.customSpeed)
            assert(c.playbackSpeed==2.5 and m.customSpeed:GetText()=='2.5')
            m.speeds[256].scripts.OnClick();assert(c.playbackSpeed==256 and m.customSpeed:GetText()=='256')
            c:SetEventFilter('accepted',false)
            assert(m.filter.afbSelected and m.mapFilter.afbSelected)
            assert(not m.timelineScroll:IsShown())
            c:ResetNow();assert(c.playbackSpeed==1 and m.customSpeed:GetText()=='1')
        ''')

    def test_fast_acceptance_recovers_rewards_from_matching_quest_log(self):
        l=client();l.execute(LOG_REWARDS);l.execute('''
            local acceptedAt=now;missing=true;logPresent=false
            function GetRewardXP() return 500 end
            t:Event('QUEST_DETAIL');quest=0;t:Event('QUEST_FINISHED');t:Event('QUEST_ACCEPTED',42)
            assert(#db.events==0 and db.pending[42].kind=='accepted' and questRequests==1 and selectedQuest==99)
            t:Event('QUEST_ACCEPTED',42);assert(questRequests==1,'duplicate acceptance restarted capture')
            advance(1);logPresent=true;px=0.5;t:Poll();local segments=#db.segments
            j:Discover('atlas','other','Later discovery',1,'later')
            quest=99;logReady=true;advance(1);t:Event('GET_ITEM_INFO_RECEIVED',101,true);advance(1)
            local rows=j:Range(0,now);local e=rows[1].event
            assert(e.kind=='accepted' and e.at==acceptedAt and e.x==2500 and rows[2].event.kind=='discovery')
            assert(e.reward.choices[2].itemID==102 and e.reward.automatic[1].quantity==3 and e.reward.status=='observed')
            assert(e.reward.offeredXP==500 and e.reward.offeredMoney==23456,'recovery replaced observed offered XP')
            assert(e.reward.captureSource=='quest log after acceptance' and e.reward.capturedAt>=acceptedAt)
            assert(not db.pending[42] and selectedQuest==99 and #db.segments==segments)
            local before=snapshot(e);logReady=false;advance(20);t:Poll()
            assert(snapshot(e)==before,'final historical snapshot was rewritten')
        ''')

    def test_acceptance_retry_reload_timeout_and_terminal_event_order(self):
        l=client();l.execute(LOG_REWARDS);l.execute('''
            missing=true;t:Event('QUEST_DETAIL');t:Event('QUEST_ACCEPTED',42)
            local acceptedAt=now;advance(1);reset(db);logReady=true;advance(1);t:Flush(42)
            assert(#db.events==1 and db.events[1].at==acceptedAt and db.events[1].reward.status=='observed')
            reset();missing=true;logReady=false;t:Event('QUEST_DETAIL');t:Event('QUEST_ACCEPTED',42)
            local p=db.pending[42];local original=snapshot(p.reward)
            reset(db);now=now+11;logReady=true;local reads=logReads;t:Flush(42)
            assert(logReads==reads and snapshot(db.events[1].reward)==original,'expired capture read later rewards')
            reset();logReady=false;t:Event('QUEST_DETAIL');t:Event('QUEST_ACCEPTED',42)
            logPresent=false;t:Event('QUEST_REMOVED',42);advance(2)
            assert(#db.events==2 and db.events[1].kind=='accepted' and db.events[2].kind=='removed')
            reset();logPresent=true;t:Event('QUEST_DETAIL');t:Event('QUEST_ACCEPTED',42)
            t:Event('QUEST_TURNED_IN',42,100,25);advance(1)
            assert(#db.events==2 and db.events[1].kind=='accepted' and db.events[2].kind=='completed')
        ''')

    def test_quest_log_recovery_guards_selection_mismatches_and_missing_apis(self):
        l=client();l.execute(LOG_REWARDS);l.execute('''
            local A=ns.Annals;logReady=true
            GetQuestLogItemLink=nil;GetQuestLogRewardXP=nil;GetQuestLogRewardMoney=nil
            function GetQuestItemLink() error('read the unrelated dialogue') end
            function GetRewardXP() error('read the unrelated dialogue XP') end
            local r=A.LogRewardSnapshot(42)
            assert(r and not r.choices[1].link and not r.offeredXP and selectedQuest==99)
            C_QuestLog.GetInfo=function() return {questID=43} end
            assert(not A.LogRewardSnapshot(42) and selectedQuest==99)
            C_QuestLog.GetInfo=function(index) return {questID=index} end
            GetNumQuestLogRewards=function() error('uncached client read') end
            r=A.LogRewardSnapshot(42);assert(r.status=='incomplete' and selectedQuest==99 and not A.logRewardReading)
            GetNumQuestLogRewards=function() return 1 end
            local count=GetNumQuestLogChoices;GetNumQuestLogChoices=function() return nil end
            assert(A.LogRewardSnapshot(42).status=='incomplete','missing log count fell back to dialogue rewards')
            GetNumQuestLogChoices=count
            local original=GetQuestItemInfo
            GetQuestItemInfo=function(kind,i) if kind=='choice' and i==1 then return end;return original(kind,i) end
            t:Event('QUEST_DETAIL');quest=0
            GetQuestLogChoiceInfo=function(i) return 'Different offer',123,1,2,true,500+i end
            t:Event('QUEST_ACCEPTED',42);advance(10)
            assert(db.events[1].reward.status=='incomplete' and db.events[1].reward.choices[2].itemID==102)
        ''')

    def test_instance_visit_holds_entrance_and_breaks_exit_trail(self):
        l=client();l.execute('''
            local A=ns.Annals;local kind='none';local instanceID=0
            function IsInInstance() return kind~='none',kind end
            function GetInstanceInfo() return kind=='raid' and 'Test Raid' or 'Test Dungeon',kind,1,'Normal',5,0,false,instanceID end
            local start=now;t:Event('PLAYER_ENTERING_WORLD',true,false);t:Poll()
            advance(2);px=0.3;t:Event('PLAYER_LEAVING_WORLD')
            kind='party';instanceID=36;mapID=501;px=0.9
            advance(2);t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1)
            assert(#db.events==1 and db.events[1].instanceAction=='enter' and db.events[1].x==3000)
            local count=#db.segments
            advance(20);t:Poll();t:Event('PLAYER_DEAD');j:Discover('atlas','inside','Dungeon discovery',1,'inside')
            assert(#db.segments==count,'interior observations created outdoor trail segments')
            assert(db.events[2].instanceType=='party' and A.ValidEvent(db.events[2]))
            local idx=A.JourneyIndex(j,start+10,now+100,nil,{completed=true},99)
            local p=A.JourneyPosition(idx,now)
            assert(p.mapID==101 and p.x==3000 and p.instanceName=='Test Dungeon','filtered range lost entrance hold')
            local projected=A.JourneyIndex(j,start+10,now+100,101,{completed=true},99)
            local _,markers,cursor,_,_,motion=A.JourneyFrame(projected,now)
            assert(#markers==0 and cursor.x==3000 and not motion)
            t:Event('PLAYER_LEAVING_WORLD');mapID=502
            t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1)
            assert(#j:Range(0,now,'instance')==1,'same-instance floor loading created another visit')
            advance(600);t:Poll();t:Event('PLAYER_LEAVING_WORLD')
            kind='none';instanceID=0;mapID=101;px=0.8
            t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1);t:Poll()
            local visits=j:Range(0,now,'instance');assert(#visits==2 and visits[2].event.instanceAction=='exit')
            p=A.JourneyPosition(A.JourneyIndex(j,start,now,nil),now);assert(p.x==8000 and not p.instanceName)
            for _,segment in ipairs(db.segments) do
                assert(segment.mapID==101)
                local entrance,exit=false,false
                for _,point in ipairs(A.Decode(segment)) do entrance=entrance or point.x==3000;exit=exit or point.x==8000 end
                assert(not (entrance and exit),'instance exit drew a teleport chord')
            end
        ''')

    def test_instance_reload_and_hearth_out_preserve_visit(self):
        l=client();l.execute('''
            local A=ns.Annals;local kind='none'
            function IsInInstance() return kind~='none',kind end
            function GetInstanceInfo() return 'Test Raid',kind,1,'Normal',40,0,false,409 end
            t:Event('PLAYER_ENTERING_WORLD',true,false);trail:SetEnabled(false);t:Poll();t:Event('PLAYER_LEAVING_WORLD')
            kind='raid';mapID=501;px=0.9;t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1)
            local entrance=db.events[1];assert(entrance.instanceID==409)
            reset(db);t:Event('PLAYER_ENTERING_WORLD',false,true);advance(1);t:Poll()
            assert(#db.events==1 and t.instanceVisit==entrance,'reload invented an entry or forgot entrance')
            t:Event('UNIT_SPELLCAST_START','player','raid-hearth',8690)
            t:Event('UNIT_SPELLCAST_SUCCEEDED','player','raid-hearth',8690)
            local p=A.JourneyPosition(A.JourneyIndex(j,entrance.at,now,nil),now)
            assert(p.mapID==101 and p.x==2500,'hearth departure pulled arrow into instance')
            t:Event('PLAYER_LEAVING_WORLD');kind='none';mapID=201;px=0.7
            t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1)
            assert(#db.events==4 and db.events[3].instanceAction=='exit' and db.events[4].kind=='hearth')
            assert(#db.segments==0,'disabled Journey recorded trail during instance transfers')
            p=A.JourneyPosition(A.JourneyIndex(j,entrance.at,now,nil),now)
            assert(p.mapID==201 and p.x==7000 and not p.instanceName)
        ''')

    def test_unobserved_instance_entrance_stays_unknown_and_login_exit_closes_visit(self):
        l=client();l.execute('''
            local A=ns.Annals;local kind='party'
            function IsInInstance() return kind~='none',kind end
            function GetInstanceInfo() return 'Test Dungeon',kind,1,'Normal',5,0,false,36 end
            j:Append('accepted','Old outdoor event',nil,{mapID=101,x=2000,y=3000},now-100)
            mapID=501;t:Event('PLAYER_ENTERING_WORLD',true,false);advance(1);t:Poll()
            assert(db.events[2].instanceAction=='enter' and not db.events[2].mapID)
            assert(not A.JourneyPosition(A.JourneyIndex(j,now-200,now,nil),now),'invented an entrance from unrelated old position')
            assert(not select(3,A.JourneyFrame(A.JourneyIndex(j,now-200,now,101),now)))
            reset(db);kind='none';mapID=101;px=0.6;advance(20)
            t:Event('PLAYER_ENTERING_WORLD',true,false)
            assert(db.events[3].instanceAction=='exit' and db.events[3].x==6000)
            assert(A.JourneyPosition(A.JourneyIndex(j,now-200,now,nil),now).x==6000)
        ''')

    def test_follow_player_holds_instance_entrance_outside_selected_dates(self):
        l=full_client();l.execute(ENV);l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            j:Append('instance','Instance entry',{instanceAction='enter',instanceName='Test Raid',instanceID=409},{mapID=101,x=3000,y=4000},100)
            j:Append('death','Interior death',nil,{instanceType='raid',mapID=501,x=9000,y=2000},170)
            j:Append('instance','Instance exit',{instanceAction='exit',instanceName='Test Raid',instanceID=409},{mapID=102,x=7000,y=4000},200)
            c.shell:ShowSection('annals');c:SetRange(150,250);c.at=150;c.mapID=102;c:Refresh()
            c:ToggleFollowPlayer();c:TogglePlayback();c:TickPlayback(40)
            assert(c.mapID==101 and c.main.map.historicalPlayer.x==3000 and c.main.map.historicalPlayer.instanceName=='Test Raid')
            c:TickPlayback(10)
            assert(c.mapID==102 and c.main.map.historicalPlayer.x==7000 and not c.main.map.historicalPlayer.instanceName)
            j:Append('instance','Second entry',{instanceAction='enter',instanceName='Test Raid',instanceID=409},{mapID=101,x=3500,y=4000},260)
            c:ResetNow();assert(c.mapID==101 and c.main.map.historicalPlayer.x==3500)
        ''')

    def test_recording_confirmation_and_journey_controls(self):
        l=full_client();l.execute(ENV);l.execute('''
            local c=ns.AnnalsController;local j=c.journal;c.shell:ShowSection('annals')
            local m=c.main
            m.record:SetChecked(false);m.record.scripts.OnClick(m.record)
            assert(m.recordConfirm:IsShown() and j.db.settings.trail~=false and m.record:GetChecked())
            m.recordConfirm.no.scripts.OnClick();assert(not m.recordConfirm:IsShown() and j.db.settings.trail~=false)
            m.record:SetChecked(false);m.record.scripts.OnClick(m.record);m.recordConfirm.yes.scripts.OnClick()
            assert(j.db.settings.trail==false and not m.record:GetChecked() and not m.recordConfirm:IsShown())
            m.record:SetChecked(true);m.record.scripts.OnClick(m.record)
            assert(j.db.settings.trail==true and not m.recordConfirm:IsShown())
            m.record:SetChecked(false);m.record.scripts.OnClick(m.record);m.scripts.OnHide(m)
            assert(not m.recordConfirm:IsShown() and j.db.settings.trail)
            local _,relative,anchor,x,y=m.zoneMenu:GetPoint();assert(relative==m.journey and anchor=='TOPLEFT' and x==342 and y==-174)
            assert(m.zoneMenu:GetWidth()==256 and m.legendButton.point[4]==857 and m.legendButton.point[5]==-174)
            assert(m.legendButton:GetWidth()==65 and m.followPlayer:GetWidth()==110 and m.findPlayer:GetWidth()==100)
            assert(m.around.point[3]==-129 and m.now.point[3]==-91)
            local _,_,_,mx,my=m.map:GetPoint();assert(mx==632 and my==-205)
            assert(-my+m.map:GetHeight()<-m.contrast.point[3],'map overlaps display settings')
            m.legendButton.scripts.OnClick();assert(m.legend:IsShown() and m.legendButton.afbSelected)
            for kind,icon in pairs(m.legend.icons) do assert(icon.texture==ns.Annals.icons[(kind=='enter' or kind=='exit') and 'instance' or kind]) end
            assert(#m.legend.arrows==4 and #m.legend.trails==5)
            assert(not m.legend.close)
            m.legendButton.scripts.OnClick();assert(not m.legend:IsShown() and not m.legendButton.afbSelected)
            c:ToggleFollowPlayer();assert(m.followPlayer:GetText()=='Follow player' and m.followPlayer.afbSelected)
            c:ToggleFollowPlayer();assert(m.followPlayer:GetText()=='Follow player' and not m.followPlayer.afbSelected)
            local choices={};MenuUtil={CreateContextMenu=function(_,build)
                build(nil,{CreateButton=function(_,label,fn) choices[#choices+1]={label=label,fn=fn} end})
            end}
            m.timeZoom.scripts.OnClick();assert(#choices==4)
            for i,expected in ipairs({false,10800,3600,900}) do choices[i].fn();assert((c.sliderSpan or false)==expected) end
        ''')

    def test_left_detail_overlay_preserves_journey_playback_and_timeline_selection(self):
        l=full_client();l.execute(ENV);l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            for i=1,9 do
                j:Append('flight','Shared timeline '..i,nil,{mapID=i==8 and 102 or 101,x=3000,y=4000,level=20},100+i)
            end
            c.shell:ShowSection('annals');c:SetRange(101,109);local m=c.main
            assert(m.journey:IsVisible() and m.timeline:IsVisible())
            assert(not m.detailPane:IsShown() and not m.show.afbSelected and m.show:GetText()=='Show detail')
            assert(m.rows[1]:IsVisible() and m.rows[1].record.event.title=='Shared timeline 1')
            m.timeline.scripts.OnMouseWheel(m.timeline,-1)
            assert(c.offset==7 and m.rows[1].record.event.title=='Shared timeline 8' and m.page:IsVisible())
            m.rows[1].scripts.OnClick(m.rows[1])
            assert(not c.showDetail and c.selected==8 and c.at==108 and c.mapID==102)
            assert(m.map.journeyAt==108 and m.detail.event.title=='Shared timeline 8')
            c:TogglePlayback();assert(c.playing)
            local page=m.page:GetText();m.show.scripts.OnClick(m.show)
            assert(c.showDetail and c.playing and m.show.afbSelected and m.show:GetText()=='Show detail')
            assert(m.detail:IsVisible() and m.journey:IsVisible() and not m.timeline:IsShown() and not m.paging:IsShown())
            assert(c.offset==7 and c.selected==8 and m.page:GetText()==page)
            assert(m.show.point[2]+m.show:GetWidth()<306 and m.detailPane.point[2]+m.detailPane:GetWidth()<306)
            assert(m.detail:GetWidth()==228 and m.detail.rows[1].label:GetWidth()==228)
            c:TickPlayback(0.25);assert(c.at==108.25 and m.map.journeyAt==108.25 and m.detail:IsVisible())
            m.show.scripts.OnClick(m.show)
            assert(not c.showDetail and c.playing and not m.show.afbSelected and m.show:GetText()=='Show detail')
            assert(m.rows[1]:IsVisible() and m.paging:IsVisible() and m.journey:IsVisible() and c.offset==7 and c.at==108.25)
            for _,control in ipairs({m.around,m.levelAt,m.contrast,m.iconSize}) do
                assert(control.parent==m.journey and control.point[2]>309,'Journey control occupies timeline pane')
            end
            m.search:SetText('Shared timeline 8');c:Refresh(true)
            assert(#c.rows==1 and m.rows[1].record.id==8 and m.rows[1]:IsVisible())
            m.rows[1].scripts.OnClick(m.rows[1])
            m.around.scripts.OnClick(m.around)
            assert(m.journey:IsVisible() and not m.show.afbSelected and c.first==0 and c.last==1908)
        ''')

    def test_instance_entry_exit_badges_and_timeline_icon_shadows(self):
        l=full_client();l.execute(ENV);l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            j:Append('instance','Entry',{instanceAction='enter',instanceName='Dungeon'},{mapID=101,x=3000,y=4000},100)
            j:Append('instance','Exit',{instanceAction='exit',instanceName='Dungeon'},{mapID=101,x=3000,y=4000},200)
            j:Append('accepted','Quest',nil,{mapID=101,x=6000,y=4000},220)
            c.shell:ShowSection('annals');c:SetRange(100,250)
            local m=c.main
            assert(m.rows[1].instanceArrow.vertexColor[2]==1 and m.rows[2].instanceArrow.vertexColor[2]==0.6)
            assert(m.rows[1].iconShadow.texture==m.rows[1].icon.texture and m.rows[3].iconShadow.texture==ns.Annals.icons.accepted)
            assert(m.rows[3].iconShadow.vertexColor[1]==0 and m.rows[3].iconShadow.point[4]==2)
            c.mapID=101;c.at=100;c:Refresh()
            local pin=m.map.pins[1];assert(pin.instanceArrow:IsShown() and pin.instanceArrow.vertexColor[2]==1)
            c.at=200;c:Journey();assert(pin.instanceArrow.vertexColor[2]==0.6,'grouped icon did not switch to observed exit')
        ''')

    def test_search_matches_partial_quest_reward_text_and_item_types(self):
        l=client()
        l.execute('''
            local A=ns.Annals;ns.AtlasUI={Date=function() return '03 Oct 2026, 17:39' end}
            C_Item={GetItemInfoInstant=function(id)
                return id,'Weapon',id==101 and 'One-Handed Swords' or 'Daggers','INVTYPE_WEAPON'
            end,GetItemInfo=function(id)
                return id==101 and "Harvester's Pest Slayer" or 'Silent Fang',nil,2,20,15,'Weapon',id==101 and 'One-Handed Swords' or 'Daggers'
            end}
            INVTYPE_WEAPON='One-Hand';ITEM_QUALITY2_DESC='Uncommon'
            C_TooltipInfo={GetHyperlink=function(link)
                if link=='item:101' then return {lines={{leftText='|cff00ff00+4 Strength|r'..string.char(10)..'Durability 60 / 60',rightText='Speed 2.60'}}} end
            end}
            local loc={mapID=101,x=5600,y=3120,zone='Westfall',subzone="Saldean's Farm",level=15}
            j:Append('accepted','The Killing Fields',{questID=42,reward={count=2,choices={
                {itemID=101,name="Harvester's Pest Slayer",quantity=1},
                {itemID=102,name='Silent Fang',quantity=1}},offeredXP=1050,offeredMoney=12345}},loc,100)
            j:Append('completed','The Killing Fields',{questID=42,reward={chosen={itemID=102,name='Silent Fang',quantity=1},money=34,xp=1050}},loc,120)
            j:Append('discovery','A [100%] record',nil,{zone='Duskwood'},130)
            local before=snapshot(db);local rows=j:Range(0,200);local cache={}
            local function search(q) return A.SearchEvents(rows,q,cache) end
            assert(#search('KiLLiNG FiEL')==2)
            assert(#search(' pest sla ')==1 and search('pest sla')[1].event.kind=='accepted')
            assert(#search('SWORD')==1 and search('sword')[1].event.kind=='accepted')
            assert(#search('sword westfall')==1 and #search('dagger')==2)
            assert(#search('uncommon sword')==1 and #search('Saldean')==2)
            assert(#search('strength')==1 and #search('speed 2.60')==1 and #search('cff00ff00')==0)
            assert(#search('durability')==1)
            assert(#search('1050')==2 and #search('23s 45c')==1 and #search('03 oct')==3)
            assert(#search('[100%]')==1 and #search('[')==1,'query was treated as a Lua pattern')
            assert(#search('  ')==3 and #search('missing sword')==0)
            assert(snapshot(db)==before,'search rewrote saved observations')
        ''')

    def test_search_covers_all_reward_buckets_and_preserves_filters_and_routes(self):
        l=client()
        l.execute('''
            local A=ns.Annals;ns.AtlasUI={Date=tostring}
            local loc={mapID=101,x=2000,y=3000,level=15}
            j:Append('accepted','Offer',{reward={count=3,choices={[3]={itemID=1,name='Bronze Sword',quantity=1}},
                automatic={{itemID=2,name='Linen Shirt',quantity=1}},currencyOffers={{currencyID=3,name='Honor Tokens',quantity=10}},
                spellOffers={{spellID=4,name='Training Ritual',quantity=1}}}},loc,100)
            j:Append('completed','Finish',{reward={single={itemID=5,name='Copper Wand',quantity=1}}},loc,110)
            j:Append('removed','Abandoned offer',nil,loc,120)
            for _,q in ipairs({'bronze','linen','tokens','ritual'}) do
                local rows=A.SearchEvents(j:Range(0,200),q,{});assert(#rows==1 and rows[1].event.kind=='accepted')
            end
            assert(#A.SearchEvents(j:Range(0,200),'wand',{})==1)
            assert(#A.SearchEvents(j:Range(105,200),'sword',{})==0)
            assert(#A.SearchEvents(j:Range(0,200,{completed=true}),'sword',{})==0)
            assert(#A.SearchEvents(j:Range(0,200,nil,16),'sword',{})==0)
            local idx=A.JourneyIndex(j,0,200,101,nil,nil,'sword',{})
            local lines,markers,arrow=A.JourneyFrame(idx,120)
            assert(#markers==1 and arrow.at==120 and #idx.positions==3,'search hid historical positions')
            local plain=A.JourneyIndex(j,0,200,101)
            assert(#lines==#A.JourneyFrame(plain,120),'search changed route geometry')
        ''')

    def test_search_control_cache_loading_clear_and_reset(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            local loaded=false;local requests=0;local calls=0
            C_Item={GetItemInfoInstant=function() calls=calls+1;return nil end,
                GetItemInfo=function() if loaded then return 'Moonlight Blade',nil,2,20,15,'Weapon','Two-Handed Swords' end end,
                RequestLoadItemDataByID=function() requests=requests+1 end}
            j:Append('accepted','Old offer',{reward={count=1,choices={{itemID=123,quantity=1}}}},
                {mapID=101,x=4000,y=5000,level=15},100)
            j:Append('completed','Other quest',nil,{mapID=101,x=5000,y=5000,level=15},110)
            local before=snapshot(j.db.events)
            c.shell:ShowSection('annals');c:SetRange(0,200)
            local m=c.main;local timers={}
            C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
            local function flush() local queued=timers;timers={};for _,fn in ipairs(queued) do fn() end end
            assert(m.search.placeholder:IsShown() and m.search.clearButton)
            m.search:SetText('s');m.search:SetText('sword');assert(#timers==1 and not m.search.placeholder:IsShown())
            flush();assert(#c.rows==0 and requests==1 and m.emptySearch:IsShown())
            c:Refresh(true);assert(requests==1 and calls==1,'search repeatedly queried/requested the same item')
            loaded=true;m.scripts.OnEvent(m,'GET_ITEM_INFO_RECEIVED',123,true);flush()
            assert(#c.rows==1 and c.rows[1].event.title=='Old offer' and not m.emptySearch:IsShown())
            m.search:SetText('moonlight');flush();assert(#c.rows==1)
            c.mapID=101;c.at=110;c:Refresh()
            assert(c.main.map.historicalPlayer.at==110 and #c.index.events==1)
            m.search.clearButton.scripts.OnClick(m.search.clearButton);flush()
            assert(c.query=='' and #c.rows==2 and m.search.placeholder:IsShown())
            m.search:SetText('no match');flush();assert(#c.rows==0)
            c:ResetNow();assert(m.search:GetText()=='' and c.query=='' and #c.rows==2)
            assert(snapshot(j.db.events)==before)
            m.search:SetText('sword');m.scripts.OnHide(m);assert(next(c.searchCache)==nil)
        ''')

    def test_follow_player_crosses_maps_continents_and_teleports_during_playback(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            local function p(map,x,at) j.trail:Sample({mapID=map,x=x,y=5000,at=at,state='alive'},true) end
            p(101,4000,100);p(101,5000,110);j.trail:Break('zone')
            p(102,4000,111);p(102,5000,118);j.trail:SetEnabled(false)
            j:Append('hearth','Hearth departure',nil,{mapID=102,x=5000,y=5000},119)
            j:Append('hearth','Hearth arrival',nil,{mapID=201,x=5200,y=5000},130)
            j:Append('teleport','Teleport arrival',nil,{mapID=201,x=9000,y=5000},150)
            local before=snapshot(j.db.events)
            c.shell:ShowSection('annals');c:SetRange(100,160);c:SetEventFilter('all',false)
            c:Seek(100);c.main.followPlayer.scripts.OnClick(c.main.followPlayer)
            local map=c.main.map
            assert(c.followPlayer and c.mapID==101 and map.zoom==2)
            local calls=0;local render=map.ShowJourney
            map.ShowJourney=function(self,...) calls=calls+1;return render(self,...) end
            c:TogglePlayback();local rendered=calls;local pan=map.panX
            c:TickPlayback(0.016)
            assert(map.panX>pan and calls==rendered,'following needs a full redraw to pan')
            c:Seek(110.99);c:TogglePlayback();c:TickPlayback(0.02)
            assert(c.mapID==102 and map.displayedMapID==102 and map.zoom==2,'zone boundary did not switch maps')
            c:Seek(125);assert(c.mapID==102 and map.historicalPlayer.x==5000)
            c:TogglePlayback();c:TickPlayback(5)
            assert(c.playing and c.mapID==201 and map.historicalPlayer.x==5200,'hearth arrival did not jump continents')
            c:TickPlayback(19.99);assert(map.historicalPlayer.x==5200,'teleport interpolated unobserved travel')
            c:TickPlayback(0.02);assert(map.historicalPlayer.x==9000 and c.mapID==201)
            local at=c.at;c.main.followPlayer.scripts.OnClick(c.main.followPlayer)
            assert(not c.followPlayer and c.playing and c.at==at)
            map.panX=17;c:TickPlayback(0.016);assert(map.panX==17,'disabled follow still pans')
            assert(snapshot(j.db.events)==before and #c.rows==0,'follow mutated history or enabled marker filters')
            c:ToggleFollowPlayer();c:ResetNow();assert(not c.followPlayer)
        ''')

    def test_position_lookup_matches_playback_and_refreshes_live_chunk_cache(self):
        l=client()
        l.execute('''
            local A=ns.Annals
            point(1000,1000,100,101,true);point(2000,1000,110,101,true)
            local all=A.JourneyIndex(j,100,150,nil)
            for _,at in ipairs({100,105.5,110,120}) do
                local p=A.JourneyPosition(all,at);local _,_,drawn=A.JourneyFrame(all,at)
                assert(p.x==drawn.x and p.at==drawn.at and p.mapID==101)
            end
            point(2500,1000,120,101,true)
            local p=A.JourneyPosition(all,115);assert(p.x==2250,'live chunk cache retained stale coordinates')
            local _,_,drawn=A.JourneyFrame(all,115);assert(drawn.x==2250)
            assert(#all.order<=64)
        ''')

    def test_acceptance_reward_choices_and_completion_selection_are_separate(self):
        l=client()
        l.execute('''
            ns.AtlasUI={Date=tostring}
            function GetRewardXP() return 500 end
            function GetRewardMoney() return 12345 end
            function GetQuestItemLink(kind,i) return '|cff1eff00|Hitem:'..((kind=='reward' and 200 or 100)+i)..':0:0:0|h[Item]|h|r' end
            C_QuestInfoSystem={GetQuestRewardSpells=function() return {777} end,
                GetQuestRewardSpellInfo=function() return {name='Training',texture=888} end}
            t:Event('QUEST_DETAIL');assert(#db.events==0)
            quest=0;t:Event('QUEST_FINISHED');t:Event('QUEST_ACCEPTED',42)
            local accepted=db.events[1];local r=accepted.reward
            assert(r.count==2 and r.choices[1].itemID==101 and r.choices[2].itemID==102)
            assert(r.choices[1].quality==2 and r.choices[1].icon==123 and r.choices[1].link=='item:101:0:0:0')
            assert(r.automatic[1].itemID==201 and r.offeredXP==500 and r.offeredMoney==12345)
            assert(r.spellOffers[1].spellID==777 and not r.chosen)
            local before=snapshot(accepted)
            quest=42;t:Event('QUEST_COMPLETE');t:RewardRequested(2);t:Event('QUEST_TURNED_IN',42,1050,34);advance(1)
            local completed=db.events[2].reward
            assert(completed.chosen.itemID==102 and not completed.choices)
            assert(completed.xp==1050 and completed.money==34 and snapshot(accepted)==before)
            local text=ns.Annals.EventText(accepted,true)
            assert(text:find('Potential rewards') and text:find('choice item 1') and text:find('choice item 2'))
            text=ns.Annals.EventText(db.events[2],true)
            assert(text:find('Chosen reward') and text:find('choice item 2') and not text:find('choice item 1'))
            reset(db);assert(#j.events==2 and snapshot(db.events[1])==before)
            quest=99;t:Event('QUEST_ACCEPTED',43);assert(db.events[3].reward.status=='unknown')
        ''')

    def test_acceptance_partial_offers_updates_and_validation(self):
        l=client()
        l.execute('''
            ns.AtlasUI={Date=tostring}
            local original=GetQuestItemInfo
            GetQuestItemInfo=function(kind,i) if kind=='choice' and i==1 and missing then return end;return original(kind,i) end
            missing=true;t:Event('QUEST_DETAIL');missing=false;t:Event('QUEST_ITEM_UPDATE');t:Event('QUEST_ACCEPTED',42)
            assert(db.events[1].reward.choices[1].itemID==101)
            t:Event('QUEST_ACCEPTED',42);assert(#db.events==1)
            quest=43
            GetQuestItemInfo=function(kind,i) if kind=='choice' and i==1 then return end;return original(kind,i) end
            t:Event('QUEST_DETAIL');t:Event('QUEST_ACCEPTED',43)
            local e=db.events[2];assert(e.reward.status=='incomplete' and not e.reward.choices[1] and e.reward.choices[2].itemID==102)
            local text=ns.Annals.EventText(e,true)
            assert(text:find('Reward option 1 unavailable') and text:find('choice item 2'))
            for _,bad in ipairs({{choices='bad'},{choices={[65]={itemID=1,quantity=1}}},
                {choices={{itemID=1,quantity=1,quality=99}}},{choices={{itemID=1,quantity=1,link='item:2'}}},
                {spellOffers={{spellID=0,quantity=1}}},{offeredXP=-1}}) do
                assert(not ns.Annals.ValidEvent({kind='accepted',title='Quest',at=100,reward=bad}))
            end
            local before=snapshot(db);ns.InitializationBlocked=true
            t:Event('QUEST_DETAIL');t:Event('QUEST_ITEM_UPDATE');t:Event('QUEST_ACCEPTED',44)
            assert(snapshot(db)==before)
        ''')

    def test_now_resets_time_filters_and_symbol_controls(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            j:Append('accepted','Earlier',nil,{mapID=101,x=4000,y=5000},100)
            j:Append('completed','Later',nil,{mapID=101,x=5000,y=5000},200)
            c.shell:ShowSection('annals');c:Select(1);c:SetRange(110,150)
            c:SetEventFilter('all',false);c.level=99;c.sliderSpan=60;c.sliderStart=110;c:SetPlaybackSpeed(128)
            c:TogglePlayback();local m=c.main
            assert(c.playing and m.play:GetText()=='' and not m.play.symbol:IsShown() and m.play.pauseBars[1]:IsShown())
            now=1000;m.now.scripts.OnClick(m.now)
            assert(not c.playing and c.at==1000 and c.last==1000 and c.first==100)
            assert(c.follow and not c.level and not c.selected and not c.sliderSpan and c.playbackSpeed==1)
            assert(#c.rows==2 and m.level:GetText()=='' and m.timeZoom:GetText()=='Full range')
            for kind,value in pairs(c.filter) do assert(value and j.db.settings.eventFilters[kind]) end
            assert(m.map.zoom==1 and m.map.panX==0 and m.map.panY==0)
            assert(m.play.symbol:IsShown() and not m.play.pauseBars[1]:IsShown() and not m.speeds[16] and m.speeds[128])
            assert(m.play.symbol.texture=='Interface\\\\ChatFrame\\\\ChatFrameExpandArrow')
            assert(m.detail.event==nil and not m.detail.rows[1].link)
            c:Seek(130);assert(not c.follow and c.at==130)
            c.showDetail=true;c:SyncDetailOverlay();m.now.scripts.OnClick(m.now);assert(c.showDetail and c.at==1000)
        ''')

    def test_reward_detail_item_tooltips_colours_cache_and_pool_cleanup(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local A=ns.Annals;local c=ns.AnnalsController;local j=c.journal
            local cached=false;local loads=0
            C_Item={GetItemInfo=function(id) if cached then return 'Cached name',nil,3,nil,nil,nil,nil,nil,nil,999 end end,
                RequestLoadItemDataByID=function() loads=loads+1 end}
            GameTooltip={SetOwner=function() end,SetHyperlink=function(_,link) shownLink=link end,
                Show=function() tooltipShown=true end,Hide=function() tooltipShown=false end}
            local e,id=j:Append('completed','The Killing Fields',{reward={chosen={itemID=1560,quantity=1,name="Harvester's Pest Slayer"},
                automatic={{itemID=201,quantity=3,name='Supply',quality=2,icon=123}},xp=1050,money=12345}},
                {mapID=101,x=5600,y=3120,zone='Westfall',subzone="Saldean's Farm",level=15},100)
            c.shell:ShowSection('annals');c.main.show.scripts.OnClick(c.main.show);local before=snapshot(e);c:Select(id)
            local detail=c.main.detail;local itemRow
            for _,row in ipairs(detail.rows) do if row.block and row.block.item==e.reward.chosen then itemRow=row end end
            assert(itemRow and itemRow.icon.texture==134400 and loads==2)
            cached=true;detail.scripts.OnEvent(detail,'GET_ITEM_INFO_RECEIVED',1560,true)
            assert(itemRow.icon.texture==999 and itemRow.label:GetText():find('|cff0070dd',1,true))
            assert(itemRow.label:GetText():find("Harvester's Pest Slayer",1,true) and not itemRow.label:GetText():find('Cached name'))
            assert(not itemRow.label:GetText():find('×1',1,true))
            GameFontHighlightSmall={GetFont=function() return 'test-font',12,'' end}
            for _,row in ipairs(detail.rows) do row.label.SetFont=function(self,_,size) self.testFontSize=size end end
            detail:SetEvent(e,false);assert(itemRow.label.testFontSize==14)
            local countShown=false
            for _,row in ipairs(detail.rows) do if row.block and row.block.item==e.reward.automatic[1] then countShown=row.label:GetText():find('×3',1,true)~=nil end end
            assert(countShown)
            itemRow.scripts.OnEnter(itemRow);assert(shownLink=='item:1560' and tooltipShown)
            itemRow.scripts.OnLeave(itemRow);assert(not tooltipShown)
            assert(A.MoneyText(12345,true)=='1|cffffd100g|r 23|cffc7c7cfs|r 45|cffb87333c|r')
            assert(A.MoneyText(0,true)=='0|cffb87333c|r' and A.MoneyText(10000,false)=='1g')
            assert(detail.rows[1].block.kind=='title' and detail.rows[2].label:GetText():find('|cff77dd88',1,true))
            assert(snapshot(e)==before,'display metadata changed the saved event')
            detail:SetEvent(nil,true);assert(not itemRow:IsShown() and not itemRow.link)
            local old={kind='accepted',at=100,title='Old quest'}
            assert(A.EventText(old,true):find('not captured'))
            local many={kind='accepted',at=100,title='Many options',reward={count=64,choices={},status='observed'}}
            for i=1,64 do many.reward.choices[i]={itemID=i,quantity=1,name='Long offered reward name '..i,quality=2} end
            detail:SetEvent(many,true)
            assert(detail.body:GetHeight()>detail:GetHeight() and #detail.rows>=64)
            assert(detail.ScrollBar:IsShown(),'long details need a visible scrollbar')
            detail.rows[10].scripts.OnMouseWheel(detail.rows[10],-1);assert(detail:GetVerticalScroll()==32)
            detail.scripts.OnMouseWheel(detail,1000);assert(detail:GetVerticalScroll()==0)
            detail:SetEvent(e,true);assert(detail:GetVerticalScroll()==0 and not detail.rows[60]:IsShown())
            detail:SetEvent(nil,true);assert(not detail.ScrollBar:IsShown(),'short details should hide the scrollbar')
        ''')

    def test_interpolated_motion_timing_gaps_and_exact_samples(self):
        l=client()
        l.execute('''
            local A=ns.Annals
            point(1000,2000,100,101,true);point(1600,2000,110,101,true)
            point(1600,2600,120,101,true);trail:Break('loading')
            point(5000,5000,130,101,true)
            local before=snapshot(db);local idx=A.JourneyIndex(j,100,140,101)
            local lines,markers,p,_,_,motion=A.JourneyFrame(idx,105.5)
            assert(p.interpolated and p.x==1330 and p.y==2000 and p.sampleAt==100)
            assert(#lines==1 and lines[1].to==p and motion.to.at==110)
            lines,markers,p=A.JourneyFrame(idx,110)
            assert(not p.interpolated and p.x==1600 and p.y==2000)
            lines,markers,p=A.JourneyFrame(idx,115)
            assert(p.x==1600 and p.y==2300 and p.previous.y==2000)
            lines,markers,p=A.JourneyFrame(idx,125)
            assert(not p.interpolated and p.at==120 and #lines==2)
            lines,markers,p=A.JourneyFrame(idx,130)
            assert(p.x==5000 and #lines==2,'loading gap gained a line')
            lines,markers,p=A.JourneyFrame(A.JourneyIndex(j,105,108,101),106)
            assert(p.x==1360 and #lines==1 and lines[1].from.at==105)
            lines,markers,p=A.JourneyFrame(A.JourneyIndex(j,110,120,101),110)
            assert(p.x==1600 and #lines==0,'range began by revealing earlier geometry')
            assert(snapshot(db)==before,'display interpolation changed the archive')
            reset();point(1000,1000,100,101,true);point(2000,1000,100,101,true)
            point(2500,1000,110,101,true)
            lines,markers,p=A.JourneyFrame(A.JourneyIndex(j,100,110,101),105)
            assert(p.x==2250,'same-second observations divided by zero or reversed')
        ''')

    def test_stop_resume_and_time_aware_simplification(self):
        l=client()
        l.execute('''
            local A=ns.Annals
            for at=0,20,2 do point(1000+at*10,1000,at) end
            for at=22,100,2 do point(1200,1000,at) end
            local count=points()
            for at=102,200,2 do point(1200,1000,at) end
            assert(points()==count,'idle observations grew the saved payload')
            for at=202,220,2 do point(1200+(at-200)*10,1000,at) end
            trail:Break('done')
            local idx=A.JourneyIndex(j,0,220,101)
            local _,_,p=A.JourneyFrame(idx,110);assert(p.x==1200)
            _,_,p=A.JourneyFrame(idx,201);assert(p.x==1210)
            local times={};for _,v in ipairs(assert(A.Decode(db.segments[1]))) do times[v.at]=v end
            assert(times[20].anchor and times[200].anchor)
            local speed={{x=0,y=0,at=0},{x=900,y=0,at=10},{x=1000,y=0,at=100}}
            assert(#A.Simplify(speed,30)==3,'straight speed changes lost timing')
            reset();for at=0,7200,2 do point(1000,1000,at) end
            point(1020,1000,7202);point(1200,1000,7204);trail:Break('done')
            for _,s in ipairs(db.segments) do assert(A.Decode(s)) end
            assert(points()<8,'long rest added periodic samples')
            reset();trail=ns.CreateAnnalsTrail(j,{simplify=false})
            for at=0,6000,2 do
                local cycle=at%20
                point(1000+math.floor(at/20)*10+math.min(cycle,10),1000,at)
            end
            trail:Break('done')
            for _,s in ipairs(db.segments) do assert(#assert(A.Decode(s))<=A.MAX_POINTS) end
        ''')

    def test_find_player_other_map_filters_and_subframe_playback(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            local function sample(x,at,map)
                j.trail:Sample({mapID=map or 101,x=x,y=5000,at=at,state='alive'},true)
            end
            sample(4000,100);sample(5000,110);sample(6000,120);j.trail:Break('loading')
            sample(5000,130,102);sample(5500,140,102)
            c.shell:ShowSection('annals');c:SetRange(100,140)
            c:SetEventFilter('all',false);c.mapID=102;c:Seek(105)
            local m=c.main;local map=m.map
            m.findPlayer.scripts.OnClick(m.findPlayer)
            assert(c.mapID==101 and c.at==105 and map.historicalPlayer.x==4500)
            assert(map.zoom==2 and math.abs(map.panX-map:GetWidth()*0.4)<0.001)
            assert(math.abs(map.panY-map:GetHeight()*0.5)<0.001)
            local render=map.ShowJourney;local renders=0
            map.ShowJourney=function(self,...) renders=renders+1;return render(self,...) end
            c:TogglePlayback();local baseline=renders
            c:TickPlayback(0.016);local x=map.historicalPlayer.x
            assert(x>4500 and x<4502 and renders==baseline,'arrow needs a full redraw to move')
            c:TickPlayback(0.016);assert(map.historicalPlayer.x>x and renders==baseline)
            c:Seek(109.99);c:TogglePlayback();c:TickPlayback(0.02)
            assert(map.historicalPlayer.x>5000,'sample boundary paused the arrow')
            m.findPlayer.scripts.OnClick(m.findPlayer);assert(not c.playing)
            c:Seek(135);m.findPlayer.scripts.OnClick(m.findPlayer)
            assert(c.mapID==102 and c.at==135 and map.historicalPlayer.x==5250)
            local oldInfo=C_Map.GetMapInfo
            C_Map.GetMapInfo=function(id) return id==102 and {mapID=id,parentMapID=100,name='Child'} or oldInfo(id) end
            C_Map.GetMapRectOnMap=function(child,parent) if child==102 and parent==100 then return 0.1,0.9,0.1,0.9 end end
            c.mapID=100;c.index=nil;c:Journey();map:ZoomBy(20)
            m.findPlayer.scripts.OnClick(m.findPlayer)
            assert(c.mapID==100 and map.zoom==4 and map.historicalPlayer.x==5200)
            j.trail:SetEnabled(false)
            j:Append('death','Died',nil,{mapID=102,x=0,y=10000,state='dead'},140)
            c:Seek(140);c.mapID=101;m.findPlayer.scripts.OnClick(m.findPlayer)
            assert(c.mapID==102 and map.historicalPlayer.state=='dead' and map.panX==0)
            assert(map.panY==map:GetHeight()*(map.zoom-1),'edge position was not clamped')
            c:SetRange(90,140);c:Seek(95);local oldMap=c.mapID
            m.findPlayer.scripts.OnClick(m.findPlayer)
            assert(c.mapID==oldMap and m.message:GetText():find('No recorded player position'))
        ''')

    def test_hearth_and_teleport_success_cancellation_and_departure(self):
        l=client();l.execute('''
            function GetSpellInfo(id) return id==8690 and 'Hearthstone' or 'Teleport: Stormwind' end
            function IsInInstance() return false,'none' end
            t:Event('UNIT_SPELLCAST_START','player','cancel',8690)
            t:Event('UNIT_SPELLCAST_INTERRUPTED','player','cancel',8690)
            assert(#db.events==0)
            t:Event('UNIT_SPELLCAST_SUCCEEDED','target','other',8690)
            t:Event('UNIT_SPELLCAST_SUCCEEDED','player','portal-creation',10059)
            assert(#db.events==0)
            t:Event('UNIT_SPELLCAST_START','player','hearth',8690)
            px=0.8;py=0.2
            t:Event('UNIT_SPELLCAST_SUCCEEDED','player','hearth',8690)
            t:Event('UNIT_SPELLCAST_SUCCEEDED','player','hearth',8690)
            assert(#db.events==1 and db.events[1].kind=='hearth' and db.events[1].x==2500)
            assert(db.events[1].spellID==8690 and ns.Annals.ValidEvent(db.events[1]))
            t:Event('PLAYER_LEAVING_WORLD');advance(60)
            t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1)
            assert(#db.events==2 and db.events[2].kind=='hearth' and db.events[2].x==8000)
            t:Poll();assert(#db.events==2)
            db.settings.trail=false;t:Poll()
            t:Event('UNIT_SPELLCAST_SUCCEEDED','player','teleport',3561)
            assert(#db.events==3 and db.events[3].kind=='teleport')
            assert(#ns.CreateAnnalsJournal(db).events==3)
        ''')

    def test_cross_continent_and_battleground_transfers_without_false_logins(self):
        l=client();l.execute('''
            local instance='none'
            function IsInInstance() return instance~='none',instance end
            local original=C_Map.GetMapInfo
            function C_Map.GetMapInfo(id)
                if id==201 then return {mapID=201,mapType=3,parentMapID=200} end
                if id==200 then return {mapID=200,mapType=2,parentMapID=0} end
                return original(id)
            end
            t:Event('PLAYER_ENTERING_WORLD',true,false);advance(1);assert(#db.events==0)
            db.settings.trail=false
            t:Event('PLAYER_LEAVING_WORLD');mapID=201;px=0.6
            t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1)
            assert(#db.events==2 and db.events[1].kind=='crossing' and db.events[2].kind=='crossing')
            assert(db.events[1].mapID==101 and db.events[2].mapID==201 and #db.segments==0)
            t:Event('PLAYER_LEAVING_WORLD');instance='pvp'
            t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1)
            assert(#db.events==4 and db.events[3].kind=='battleground' and db.events[3].title:find('entry'))
            t:Event('PLAYER_LEAVING_WORLD');instance='none';mapID=101
            t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1)
            assert(#db.events==6 and db.events[5].title:find('exit'))
            t:Event('PLAYER_LEAVING_WORLD');t:Event('PLAYER_ENTERING_WORLD',false,true);advance(1)
            assert(#db.events==6,'reload is not travel')
            t:Event('PLAYER_LEAVING_WORLD');mapID=102
            t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1);advance(31);t:Poll()
            assert(#db.events==6,'ordinary same-continent loading is not a teleport')
        ''')

    def test_transfer_waits_for_position_and_never_bridges_trail(self):
        l=client();l.execute('''
            local instance='none'
            function IsInInstance() return instance~='none',instance end
            t:Event('PLAYER_ENTERING_WORLD',true,false);t:Poll()
            t:Event('PLAYER_LEAVING_WORLD');instance='pvp';px=0.8
            local position=ns.AtlasEnvironment.Position
            ns.AtlasEnvironment.Position=function() return nil end
            t:Event('PLAYER_ENTERING_WORLD',false,false);advance(1)
            assert(#db.events==0)
            ns.AtlasEnvironment.Position=position;t:Poll()
            assert(#db.events==2 and db.events[2].x==8000)
            for _,segment in ipairs(db.segments) do
                local seenOrigin,seenArrival=false,false
                for _,p in ipairs(assert(ns.Annals.Decode(segment))) do
                    seenOrigin=seenOrigin or p.x==2500;seenArrival=seenArrival or p.x==8000
                end
                assert(not (seenOrigin and seenArrival),'no travel chord across the transfer')
            end
            local count=#db.events
            ns.InitializationBlocked=true
            t:Event('UNIT_SPELLCAST_SUCCEEDED','player','blocked',8690);t:Poll()
            assert(#db.events==count)
        ''')

    def test_travel_icons_filters_and_tooltips(self):
        l=full_client();l.execute(ENV);l.execute('''
            local c=ns.AnnalsController;local A=ns.Annals
            for i,kind in ipairs({'hearth','teleport','crossing','battleground'}) do
                c.journal:Append(kind,kind..' travel',nil,{mapID=101,x=i*1800,y=4000},100+i)
            end
            c.shell:ShowSection('annals');c:SetRange(100,110);c.mapID=101;c.at=110;c:Refresh()
            local map=c.main.map;assert(#map.pins==4)
            for _,pin in ipairs(map.pins) do
                local event=pin.group[1].point.event
                assert(pin.icon.texture==A.icons[event.kind] and c.filter[event.kind])
                pin.scripts.OnEnter(pin);assert(GameTooltip.lines[1].text:find(event.title,1,true))
            end
            c:SetEventFilter('hearth',false)
            local count=0;for _,pin in ipairs(map.pins) do if pin:IsShown() then count=count+1 end end
            assert(count==3)
        ''')

    def test_grouped_tooltip_shows_latest_three_without_changing_click_order(self):
        l=full_client();l.execute(ENV);l.execute('''
            local c=ns.AnnalsController;local A=ns.Annals
            for i,at in ipairs({150,100,130,140,160,160}) do
                c.journal:Append('flight','Flight '..i,nil,{mapID=101,x=3000,y=4000},at)
            end
            c.shell:ShowSection('annals');c:SetRange(100,170);c.mapID=101;c.at=170;c:Refresh()
            local pin=c.main.map.pins[1];assert(#pin.group==6)
            local ids={};for i,member in ipairs(pin.group) do ids[i]=member.id end
            pin.scripts.OnEnter(pin)
            assert(GameTooltip.lines[1].text:find('Flight 6',1,true))
            assert(GameTooltip.lines[3].text:find('Flight 5',1,true))
            assert(GameTooltip.lines[5].text:find('Flight 1',1,true))
            assert(GameTooltip.lines[6].text:find('3 more older events',1,true))
            assert(#GameTooltip.lines==7)
            for i,member in ipairs(pin.group) do assert(member.id==ids[i],'hover reordered click cycling') end
            for i=1,6 do
                pin.scripts.OnClick(pin,'LeftButton');assert(tostring(c.selected)==ids[i])
            end
            c.at=140;c:Refresh();pin=c.main.map.pins[1]
            pin.scripts.OnEnter(pin)
            assert(#pin.group==3 and #GameTooltip.lines==6)
            assert(GameTooltip.lines[1].text:find('Flight 4',1,true))
            assert(GameTooltip.lines[5].text:find('Flight 2',1,true))
            local text=A.EventText({kind='discovery',title='Found herb',at=100,link={section='gathering'}},true)
            assert(text:find('Fieldbook discovery',1,true) and text:find('gathering',1,true))
            assert(not text:find('quest causation',1,true) and not text:find('Discovered during',1,true))
        ''')

    def test_ribbon_shared_edges_no_gap_bridging_and_bounded_corners(self):
        l=client()
        l.execute('''
            local A=ns.Annals
            local a={x=0,y=0,at=0};local b={x=5000,y=0,at=10};local c={x=5000,y=5000,at=20}
            local lines=A.SmoothTrail({{from=a,to=b},{from=b,to=c}},500,500)
            local quads=A.TrailRibbon(lines,500,500,2)
            for i=2,#quads do
                assert(quads[i-1][3]==quads[i][1] and quads[i-1][4]==quads[i][2],
                    'adjacent strips must share both vertices, without overlapping caps')
            end
            for i,quad in ipairs(quads) do
                for n,p in ipairs(quad) do
                    local center=n<=2 and lines[i].from or lines[i].to
                    local dx,dy=p.x-center.x*0.05,p.y+center.y*0.05
                    assert(dx*dx+dy*dy<=4.00001,'bounded join must not spike')
                end
            end
            local other={x=b.x,y=b.y,at=b.at}
            local gap=A.TrailRibbon({{from=a,to=b},{from=other,to=c}},500,500,2)
            assert(gap[1][3]~=gap[2][1],'coincident but disconnected history keeps separate caps')
            local zero=A.TrailRibbon({{from=a,to=a},{from=a,to=b}},500,500,2)
            assert(zero[1]==false and zero[2])
        ''')

    def test_ribbon_zoom_keeps_screen_width_and_reuses_hidden_pool(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local A=ns.Annals;c.shell:ShowSection('annals')
            local map=c.main.map
            local create=map.canvas.CreateTexture
            function map.canvas:CreateTexture(...)
                local texture=create(self,...)
                function texture:SetVertexOffset(i,x,y)
                    self.offsets=self.offsets or {};self.offsets[i]={x,y}
                end
                return texture
            end
            c.journal.db.segments={{v=1,mapID=101,at=100,finish=120,
                data=A.EncodePoint({x=1000,y=2000,at=100},100)..
                    A.EncodePoint({x=5000,y=2000,at=110},100)..
                    A.EncodePoint({x=5000,y=6000,at=120},110)}}
            c:SetRange(100,120);c.mapID=101;c.at=120;c:Refresh()
            local first=map.lines[1]
            local function screenWidth()
                local a,b=first.offsets[1],first.offsets[2]
                local dx,dy=a[1]-b[1],a[2]-(b[2]-first:GetHeight())
                return math.sqrt(dx*dx+dy*dy)*map.zoom
            end
            assert(math.abs(screenWidth()-2)<0.00001)
            map:ZoomBy(20);assert(map.zoom==4 and map.lines[1]==first)
            assert(math.abs(screenWidth()-2)<0.00001,'zoom must not enlarge the stroke')
            map:ZoomBy(-20);assert(map.zoom==1 and math.abs(screenWidth()-2)<0.00001)
            c.at=100;c:Journey()
            for _,texture in ipairs(map.lines) do assert(not texture:IsShown()) end
        ''')

    def test_playback_rates_pause_bounds_and_precise_relative_slider(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;c.shell:ShowSection('annals')
            c:SetRange(1800000000,1800010000)
            local m=c.main
            for _,speed in ipairs({1,8,32,64,128}) do
                c:Seek(c.first);m.speeds[speed].scripts.OnClick(m.speeds[speed])
                c:TogglePlayback();c:TickPlayback(2.5)
                assert(c.at==c.first+2.5*speed and c.playing)
                c:TogglePlayback();local at=c.at;c:TickPlayback(20);assert(c.at==at)
            end
            c:Seek(c.last-1);c:TogglePlayback();c:TickPlayback(1)
            assert(c.at==c.last and not c.playing)
            c:TogglePlayback();assert(c.at==c.first and c.playing)
            m.scripts.OnHide(m);assert(not c.playing)
            c:Seek(c.first+500);c.sliderSpan=60;c.sliderStart=nil;c:SyncSlider()
            assert(c.sliderStart==c.first+470)
            m.slider.scripts.OnValueChanged(m.slider,31)
            assert(c.at==c.first+501 and not c.playing)
            m.slider.scripts.OnMouseWheel(m.slider,1);assert(c.at==c.first+502)
            assert(m.findPlayer and not m.backSecond and not m.forwardSecond)
            c:Seek(c.first);m.slider.scripts.OnMouseWheel(m.slider,-1);assert(c.at==c.first)
            c:TogglePlayback();m.show.scripts.OnClick(m.show);assert(c.playing and m.journey:IsVisible())
            c:SetRange(c.first,c.first);c:TogglePlayback();assert(not c.playing)
        ''')

    def test_multi_select_menu_icon_size_and_historical_player(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            j:Append('accepted','Quest',nil,{mapID=101,x=2000,y=2000},100)
            j:Append('death','Died',nil,{mapID=101,x=3000,y=3000,state='dead'},110)
            j:Append('flight','Flight',nil,{mapID=101,x=4000,y=4000},120)
            c.shell:ShowSection('annals');c:SetRange(100,120)
            MenuResponse={Refresh=1};local items={}
            MenuUtil={CreateContextMenu=function(_,build)
                build(nil,{CreateCheckbox=function(_,label,checked,click)
                    local item={checked=checked,click=click,SetResponse=function() end};items[label]=item;return item
                end})
            end}
            c.main.filter.scripts.OnClick(c.main.filter)
            assert(items['All events'].checked())
            items['All events'].click();assert(#c.rows==0)
            items['Death'].click();items['Flight path'].click()
            assert(#c.rows==2 and c.filter.death and c.filter.flight and not c.filter.accepted)
            assert(j.db.settings.eventFilters.death and not j.db.settings.eventFilters.accepted)
            c.mapID=101;c.at=110;c:Refresh()
            local map=c.main.map
            assert(map.playerArrow:IsShown() and map.historicalPlayer.state=='dead')
            assert(map.historicalPlayer.x==3000 and map.historicalPlayer.at==110)
            c:SetEventFilter('all',false)
            assert(map.playerArrow:IsShown() and map.historicalPlayer.state=='dead')
            c.main.iconSize.scripts.OnValueChanged(c.main.iconSize,32)
            assert(j.db.settings.iconSize==32 and map.playerArrow:GetWidth()==32)
            c:SetEventFilter('death',true);assert(map.pins[1]:GetWidth()==32)
            j:Append('death','Second death',nil,{mapID=101,x=3000,y=3000,state='dead'},110)
            c.index=nil;c:Journey()
            local pin=map.pins[1];assert(pin.text:GetText()=='2')
            assert(pin.text:GetScale()==32/20 and pin.text.point[1]=='BOTTOMRIGHT')
            assert(pin.text.point[2]==pin.icon and pin.text.point[3]=='BOTTOMRIGHT')
            assert(pin.text.point[4]==0 and pin.text.point[5]==0)
            assert(pin.icon.points[1][2]==0 and pin.icon.points[2][2]==0)
            local base=pin:GetEffectiveScale()
            map:ZoomBy(20);assert(map.zoom==4 and pin:GetWidth()==32)
            assert(math.abs(pin:GetEffectiveScale()/base-4)<0.00001)
            assert(math.abs(pin.text:GetEffectiveScale()/pin:GetEffectiveScale()-32/20)<0.00001)
            c.main.iconSize.scripts.OnValueChanged(c.main.iconSize,6)
            assert(pin:GetWidth()==6 and pin.text:GetScale()==6/20 and map.zoom==4)
            map:ZoomBy(-20);assert(map.zoom==1 and pin:GetWidth()==6)
            c.at=120;c:Journey();assert(map.historicalPlayer.state=='flight')
            c.at=99;c.first=0;c.index=nil;c:Journey();assert(not map.playerArrow:IsShown())
            c.at=110;c:Journey();c.shell:ShowSection('atlas');c.shell:ShowSection('annals')
            assert(map.playerArrow:IsShown() and map.historicalPlayer.state=='dead')
        ''')

    def test_shallow_trail_elbows_preserve_gaps_endpoints_and_budget(self):
        l=client()
        l.execute('''
            local A=ns.Annals
            local a={x=0,y=0,at=0,mapID=101}
            local b={x=5000,y=0,at=100,mapID=101}
            local c={x=5000,y=5000,at=200,mapID=101}
            local source={{from=a,to=b},{from=b,to=c}}
            local rounded=A.SmoothTrail(source,500,500)
            assert(#rounded>=4 and #rounded<=8 and rounded[1].from==a and rounded[#rounded].to==c)
            assert(source[1].to==b and b.x==5000 and b.y==0)
            for i=2,#rounded-1 do
                assert(rounded[i-1].to==rounded[i].from)
                local p=rounded[i].to
                assert(p.x>=4880 and p.x<=5000 and p.y>=0 and p.y<=120)
                assert(p.at>=rounded[i].from.at)
                local dx,dy=(p.x-rounded[i].from.x)*0.05,(p.y-rounded[i].from.y)*0.05
                assert(dx*dx+dy*dy>=0.0625,'avoid subpixel over-tessellation')
            end
            assert(rounded[#rounded-1].to==rounded[#rounded].from)
            local tiny=A.SmoothTrail(source,10,10)
            assert(#tiny>2,'ribbon elbows must also work at low zoom')
            -- Coincident points separated by a recording gap must not round.
            local other={x=b.x,y=b.y,at=b.at,mapID=101}
            local gap=A.SmoothTrail({{from=a,to=b},{from=other,to=c}},500,500)
            assert(#gap==2 and gap[1].to==b and gap[2].from==other)
            local straight=A.SmoothTrail({{from=a,to=b},{from=b,to={x=10000,y=0,at=200}}},500,500)
            assert(#straight==2 and straight[1].to==b)
            local reversal=A.SmoothTrail({{from=a,to=b},{from=b,to=a}},500,500)
            assert(#reversal==2)
            local dense={};local previous=a
            for i=1,2048 do
                local point={x=i%2*5000,y=i,at=i,mapID=101}
                dense[i]={from=previous,to=point};previous=point
            end
            assert(#A.SmoothTrail(dense,500,500)==2048)
            table.remove(dense);assert(#A.SmoothTrail(dense,500,500)<=2048)
        ''')

    def test_deaths_record_once_per_life_with_trail_disabled(self):
        l=client()
        l.execute('''
            local dead=false;function UnitIsDeadOrGhost() return dead end
            t:Event('PLAYER_ENTERING_WORLD');trail:SetEnabled(false)
            dead=true;t:Event('PLAYER_DEAD');t:Event('PLAYER_DEAD')
            assert(#db.events==1 and db.events[1].kind=='death' and #db.segments==0)
            assert(db.events[1].at==now and db.events[1].mapID)
            t:Event('PLAYER_ALIVE');t:Event('PLAYER_DEAD');assert(#db.events==1)
            dead=false;t:Event('PLAYER_UNGHOST');dead=true;t:Event('PLAYER_DEAD')
            assert(#db.events==2 and #j:Range(0,9999999999,'death')==2)
            local reloaded=ns.CreateAnnalsJournal(db);assert(#reloaded.events==2)
            t:Event('PLAYER_ENTERING_WORLD');t:Event('PLAYER_DEAD');assert(#db.events==2)
            ns.InitializationBlocked=true;t:Event('PLAYER_UNGHOST');t:Event('PLAYER_DEAD');assert(#db.events==2)
        ''')

    def test_flight_segments_preserve_state_through_codec_and_projection(self):
        l=client()
        l.execute('''
            local A=ns.Annals
            local flying=false;function UnitOnTaxi() return flying end
            t:Poll();advance(2);flying=true;t:Poll()
            for i=1,20 do advance(2);px=px+0.001;t:Poll() end
            local flight=db.segments[#db.segments];assert(flight.flight==true)
            local decoded=assert(A.Decode(flight));assert(decoded[1].flight==true)
            advance(2);flying=false;t:Poll();assert(db.segments[#db.segments].flight~=true)
            local index=A.JourneyIndex(j,0,now,101)
            local lines=A.JourneyFrame(index,now);local green=false
            for _,edge in ipairs(lines) do
                if edge.to.flight then
                    green=true
                    local r,g,b=A.TrailColor(now,edge.to.at,1,true);assert(g>r and g>b)
                end
            end
            assert(green)
            flight.flight=nil;assert(A.Decode(flight)[1].flight==false,'legacy trails must not invent flight state')
        ''')

    def test_archive_estimate_includes_whole_store_and_preserves_data(self):
        l=client()
        from annals_storage import SIMULATION
        l.execute(SIMULATION)
        l.execute('''
            local title,detail=j:StorageStatus()
            assert(title:find('Archive: ~',1,true))
            assert(detail:find(tostring(diskSize(db))..' estimated saved-data bytes',1,true))
            j:Quest('accepted',42,'A quest')
            point(100,100,now,101,true)
            db.settings.extra=string.rep('x',20000)
            local before=diskSize(db);local revision=j.revision
            title,detail=j:StorageStatus()
            assert(detail:find(tostring(before)..' estimated saved-data bytes',1,true))
            assert(detail:find('1 event records',1,true) and detail:find(tostring(points())..' encoded points',1,true))
            assert(diskSize(db)==before and j.revision==revision)
            db.settings.loop=db
            assert(j:StorageStatus()=='Archive: usage unavailable' and db.settings.loop==db)
            local saved={schema=99,keep='original'}
            assert(ns.CreateAnnalsJournal(saved):StorageStatus()=='Archive: read-only')
            assert(saved.keep=='original' and saved.events==nil)
        ''')

    def test_archive_footer_in_both_views_and_live_trail_refresh(self):
        l=full_client()
        l.execute('''
            GameTooltip={SetOwner=function() end,SetText=function(self,text) self.title=text end,
                AddLine=function(self,text) self.detail=text end,Show=function() end,Hide=function() end}
            local c=ns.AnnalsController;c.shell:ShowSection('annals')
            local m=c.main;assert(m.capacity:GetText()==c.journal:StorageStatus())
            c:Refresh();assert(m.capacity:GetText()==c.journal:StorageStatus())
            c.journal.db.settings.extra=string.rep('x',20000)
            m.scripts.OnUpdate(m,30)
            assert(m.capacity:GetText()==c.journal:StorageStatus())
            c.journal.db.settings.extra=string.rep('x',40000)
            m.capacityHover.scripts.OnEnter(m.capacityHover)
            assert(m.capacity:GetText()==c.journal:StorageStatus())
            assert(GameTooltip.detail:find('estimated saved-data bytes',1,true))
            m.capacityHover.scripts.OnLeave(m.capacityHover)
        ''')

    def test_trail_age_contrast_scrubbing_and_saved_control(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local A=ns.Annals
            local r,g,b,alpha=A.TrailColor(3600,3600,1)
            assert(r==1 and g==0.82 and b==0.14 and alpha==0.8)
            local coldR,_,coldB,coldAlpha=A.TrailColor(3600,0,1)
            assert(coldR<r and coldB>b and coldAlpha<alpha and coldAlpha>=0.12)
            r,g,b,alpha=A.TrailColor(99999,0,0)
            assert(r==1 and g==0.82 and b==0.14 and alpha==0.8)
            local c=ns.AnnalsController;local j=c.journal
            j.db.segments={}
            for _,at in ipairs({100,3700}) do
                j.db.segments[#j.db.segments+1]={v=1,mapID=101,at=at,finish=at+10,
                    data=A.EncodePoint({x=100,y=200,at=at},at)..A.EncodePoint({x=200,y=300,at=at+10},at)}
            end
            local saved=snapshot(j.db.segments)
            c.shell:ShowSection('annals')
            function c.main.map.canvas:CreateLine() return CreateFrame('Texture',nil,self) end
            c:SetRange(100,3710);c.mapID=101;c:Refresh()
            local map=c.main.map
            assert(map.lines[1].colorTexture[4]<map.lines[2].colorTexture[4])
            c.at=110;c:Journey();assert(map.lines[1].colorTexture[4]==0.8)
            c.main.contrast.scripts.OnValueChanged(c.main.contrast,0)
            c.at=3710;c:Journey()
            assert(map.lines[1].colorTexture[4]==0.8 and map.lines[2].colorTexture[4]==0.8)
            assert(j.db.settings.trailContrast==0 and snapshot(j.db.segments)==saved)
            assert(ns.CreateAnnalsJournal(j.db).db.settings.trailContrast==0)
        ''')

    def test_dense_projection_keeps_latest_edges_within_budget(self):
        l=client()
        l.execute('''
            local A=ns.Annals
            for segment=1,20 do
                local start=segment*1000;local data={}
                for n=0,255 do
                    data[#data+1]=A.EncodePoint({x=100+n,y=200,at=start+n*2},n==0 and start or start+(n-1)*2)
                end
                db.segments[segment]={v=1,mapID=101,at=start,finish=start+510,data=table.concat(data)}
            end
            local idx=A.JourneyIndex(j,0,20510,101)
            local lines,_,cursor,limited=A.JourneyFrame(idx,20510)
            assert(#lines==2048 and limited and cursor.at==20510)
            local latest=false
            for _,line in ipairs(lines) do
                assert(line.from.at>=12000,'old edges displaced recent geometry')
                if line.to.at==20510 then latest=true end
            end
            assert(latest)
        ''')

    def test_balanced_cadence_turns_and_anchors(self):
        l=client()
        l.execute('''
            for at=0,600,2 do
                point(5000+math.floor(300*math.sin(at)),5000+math.floor(300*math.cos(at)),at)
            end
            local p=assert(ns.Annals.Decode(db.segments[1]))
            assert(#p<=41,'ordinary meandering retained more than one point per 15 seconds')
            for i=2,#p do assert(p[i].at-p[i-1].at>=15) end
            point(5200,5200,602,101,true)
            p=assert(ns.Annals.Decode(db.segments[1]));assert(p[#p].anchor and p[#p].at==602)
            reset();for at=0,58,2 do point(1000+at,1000,at) end
            assert(points()==1);point(1060,1000,60);assert(points()==2)
        ''')

    def test_flight_departure_and_subzone_continuity(self):
        l=client()
        l.execute('''
            local flying=false
            function UnitOnTaxi() return flying end
            function NumTaxiNodes() return 2 end
            function TaxiNodeGetType(i) return i==1 and 'CURRENT' or 'REACHABLE' end
            function TaxiNodeName(i) return i==1 and 'Sentinel Hill' or 'Stormwind' end
            t:Poll();t:Event('TAXIMAP_OPENED');assert(#db.events==0)
            for i=1,50 do advance(2);t:Poll() end
            t:Event('TAXIMAP_CLOSED');flying=true;advance(2);px=px+0.01;t:Poll()
            assert(#db.events==1 and db.events[1].kind=='flight' and db.events[1].title=='Flight from Sentinel Hill')
            -- Browsing the taxi map for a while must preserve its origin name.
            -- Subzone notifications must not add gaps during the actual flight.
            local segments=#db.segments
            for i=1,60 do
                advance(2);px=px+0.001
                function GetSubZoneText() return 'Subzone '..i end
                t:Event('ZONE_CHANGED');t:Event('ZONE_CHANGED_INDOORS');t:Event('ZONE_CHANGED_NEW_AREA');t:Poll()
            end
            assert(#db.segments==segments and #db.events==1)
            flying=false;advance(2);t:Poll();flying=true;advance(2);t:Poll();assert(#db.events==2)
            t:Event('PLAYER_ENTERING_WORLD');advance(2);t:Poll();assert(#db.events==2,'reload mid-flight invented departure')
            flying=false;advance(2);t:Poll();trail:SetEnabled(false)
            local count=#db.segments;flying=true;advance(2);t:Poll()
            assert(#db.events==3 and #db.segments==count,'flight event should survive disabled breadcrumbs')
        ''')

    def test_continent_world_projection_and_boundary_join(self):
        l=client()
        l.execute('''
            local A=ns.Annals
            C_Map.GetMapInfo=function(id)
                return {mapID=id,parentMapID=id==101 and 100 or id==102 and 100 or id==100 and 99 or 0}
            end
            C_Map.GetMapRectOnMap=function(child,parent)
                if child==101 and parent==100 then return 0.1,0.3,0.2,0.4 end
                if child==102 and parent==100 then return 0.3,0.5,0.2,0.4 end
                if child==100 and parent==99 then return 0.5,1,0,0.5 end
            end
            -- A validated world conversion is the recording-time evidence for
            -- a continuous map crossing; projection alone never grants a join.
            ns.AtlasEnvironment.World=function(p) return {continentID=1,x=p.mapID==101 and p.x or p.x+10000,y=p.y} end
            point(9800,5000,0);point(9950,5000,2)
            point(50,5000,4,102)
            for at=6,20,2 do point(50+(at-4)*16,5000,at,102) end
            assert(db.segments[2].joinFrom==1)
            j:Append('flight','Departure',nil,{mapID=101,x=9800,y=5000},0)
            local before=snapshot(db)
            local idx=A.JourneyIndex(j,0,20,100)
            local lines,markers,cursor=A.JourneyFrame(idx,20)
            assert(#lines==3 and #markers==1 and cursor.mapID==100)
            assert(markers[1].x==2960 and markers[1].y==3000)
            local world=A.JourneyIndex(j,0,20,99)
            lines,markers,cursor=A.JourneyFrame(world,20)
            assert(#lines==3 and markers[1].x==6480 and markers[1].y==1500)
            assert(snapshot(db)==before,'projection mutated recorded coordinates')
            lines,markers,cursor=A.JourneyFrame(world,3);assert(#lines==2 and #markers==1)
            assert(cursor.interpolated and cursor.at==3 and cursor.x==6500)
            assert(#A.JourneyIndex(j,0,20,103).segments==0)
            C_Map.GetMapRectOnMap=function() return 0,0,0,0 end
            assert(#A.JourneyIndex(j,0,20,99).segments==0)
            trail:Break('loading');point(400,5000,22,102)
            assert(not db.segments[#db.segments].joinFrom)
            advance(20);point(450,5000,42,101)
            assert(not db.segments[#db.segments].joinFrom,'gap across maps must not connect')
        ''')

    def test_startup_restore_hold_blocks_deferred_and_hook_writes(self):
        l=client()
        l.execute('''
            t:Event('QUEST_ACCEPTED',42);t:Event('QUEST_COMPLETE');t:Event('QUEST_REMOVED',42)
            local before=snapshot(db);ns.InitializationBlocked=true
            advance(5);t:RewardRequested(1);t:Poll();t:Seed();t:Flush(42)
            trail:SetEnabled(false);trail:Break('blocked');j:Sequence()
            t:Event('QUEST_TURNED_IN',42);j:Discover('atlas','p1','Blocked',nil,'fixed')
            assert(snapshot(db)==before,'restore hold must preserve every Annals byte')
        ''')

    def test_single_option_and_currency_offers(self):
        l=client()
        l.execute('''
            choiceCount=1;t:Event('QUEST_COMPLETE');t:RewardRequested(1);t:Event('QUEST_TURNED_IN',42);advance(1)
            assert(not db.events[1].reward.chosen and db.events[1].reward.single.itemID==101)
            quest=43;choiceCount=2
            C_QuestInfoSystem={GetQuestRewardCurrencies=function() return {{currencyID=7,totalRewardAmount=20,name='Tokens'}} end}
            C_QuestOffer={GetQuestRewardCurrencyInfo=function() return {currencyID=8,totalRewardAmount=5,name='Choice tokens'} end}
            function GetQuestItemInfoLootType(kind) return kind=='choice' and 1 or 0 end
            t:Event('QUEST_COMPLETE');t:RewardRequested(2);t:Event('QUEST_TURNED_IN',43);advance(1)
            local r=db.events[2].reward
            assert(r.chosen.currencyID==8 and r.chosen.offered and r.currencyOffers[1].quantity==20)
        ''')

    def test_login_baseline_and_disabled_pending_fallback(self):
        l=client()
        l.execute('''
            C_QuestLog.GetNumQuestLogEntries=function() return 1 end
            C_QuestLog.GetInfo=function() return {questID=42,title='Existing quest',isHeader=false} end
            t:Seed();assert(#db.events==0 and db.quests[42].kind=='baseline')
            trail:SetEnabled(false);C_Timer=nil;t:Event('QUEST_REMOVED',42);now=now+3;t:Poll()
            assert(#db.events==1 and db.events[1].kind=='removed' and #db.segments==0)
            reset(db);t:Event('PLAYER_ENTERING_WORLD');assert(#db.events==1)
        ''')

    def test_accept_abandon_reacquire_complete_repeat_reload(self):
        l=client()
        l.execute('''
            t:Event('QUEST_ACCEPTED',42);t:Event('QUEST_ACCEPTED',42);assert(#db.events==1)
            t:Event('QUEST_REMOVED',42);advance(2);assert(#db.events==2)
            reset(db);t:Event('QUEST_ACCEPTED',42);assert(#db.events==3)
            t:Event('QUEST_TURNED_IN',42,50,60);t:Event('QUEST_REMOVED',42);advance(1)
            assert(#db.events==4 and db.events[4].kind=='completed')
            t:Event('QUEST_TURNED_IN',42,50,60);advance(1);assert(#db.events==4)
            reset(db);t:Event('QUEST_ACCEPTED',42);t:Event('QUEST_TURNED_IN',42,50,60);advance(1)
            assert(#db.events==6 and db.events[1].kind=='accepted' and db.events[2].kind=='removed')
        ''')

    def test_pending_reload_and_turnin_before_reward_posthook(self):
        l=client()
        l.execute('''
            t:Event('QUEST_COMPLETE');t:Event('QUEST_REMOVED',42)
            t:Event('QUEST_TURNED_IN',42,70,80);t:RewardRequested(2)
            reset(db);t:Start()
            assert(#db.events==1 and db.events[1].kind=='completed')
            local r=db.events[1].reward
            assert(r.chosen.itemID==102 and r.chosen.quantity==1 and r.automatic[1].itemID==201)
            assert(r.automatic[1].quantity==3 and r.xp==70 and r.money==80)
            assert(r.choices==nil)
        ''')

    def test_rewards_none_missing_unknown_and_automatic(self):
        l=client()
        l.execute('''
            choiceCount=0;autoCount=0;t:Event('QUEST_COMPLETE');t:RewardRequested(0)
            t:Event('QUEST_TURNED_IN',42,0,0);advance(1)
            assert(db.events[1].reward.choiceStatus=='none' and #db.events[1].reward.automatic==0)
            quest=43;choiceCount=2;autoCount=1;missing=true
            t:Event('QUEST_COMPLETE');t:RewardRequested(1);t:Event('QUEST_TURNED_IN',43);advance(1)
            assert(db.events[2].reward.status=='incomplete' and not db.events[2].reward.chosen)
            t:Event('QUEST_TURNED_IN',44);advance(1);assert(db.events[3].reward.status=='unknown')
            missing=false;quest=45;choiceCount=0;autoCount=1
            t:Event('QUEST_COMPLETE');t:Event('QUEST_TURNED_IN',45);advance(1)
            assert(not db.events[4].reward.chosen and db.events[4].reward.automatic[1].itemID==201)
        ''')

    def test_repeated_reward_without_accept_and_duplicate_suppression(self):
        l=client()
        l.execute('''
            for i=1,2 do t:Event('QUEST_COMPLETE');t:RewardRequested(1);t:Event('QUEST_TURNED_IN',42);advance(1) end
            assert(#db.events==2)
            t:Event('QUEST_TURNED_IN',42);advance(1);assert(#db.events==2)
        ''')

    def test_codec_validation_roundtrip(self):
        l=client()
        l.execute('''
            local A=ns.Annals;local s={v=1,mapID=101,at=10,data=''}
            s.data=A.EncodePoint({x=10000,y=0,at=10,anchor=true},10)..A.EncodePoint({x=3,y=9999,at=4105},10)
            assert(#s.data==18);local p=assert(A.Decode(s));assert(p[1].anchor and p[2].at==4105 and p[2].y==9999)
            for _,bad in ipairs({'!',s.data..'0',string.rep('z',9),string.rep('0',2305)}) do s.data=bad;assert(not A.Decode(s)) end
            s.data='000000000';s.v=2;assert(not A.Decode(s))
            assert(not A.EncodePoint({x=10001,y=1,at=10},10))
        ''')

    def test_stationary_slow_and_continuous(self):
        l=client()
        l.execute('''
            for at=0,7200,2 do point(1000,1000,at) end
            assert(points()==1 and #db.segments==1,'stationary storage grew')
            reset();for at=0,200,2 do point(1000+at/2,1000,at) end
            assert(points()>1 and points()<20,'slow movement filtering')
            reset();for at=0,300,2 do point(1000+at*10,1000,at) end
            assert(points()>2 and points()<=20);trail:Break('done');assert(points()<10,'straight path simplification')
        ''')

    def test_turns_breaks_and_event_anchors(self):
        l=client()
        l.execute('''
            for at=0,20,2 do point(1000+at*10,1000,at) end
            point(1200,1000,20,101,true)
            for at=22,40,2 do point(1200,1000+(at-20)*10,at) end
            point(1200,1200,42,102);assert(#db.segments==2)
            point(8000,8000,44,102);assert(#db.segments==3)
            trail:Break('reload');point(8010,8010,46,102);assert(#db.segments==4)
            local anchor=false;for _,p in ipairs(assert(ns.Annals.Decode(db.segments[1]))) do if p.anchor and p.x==1200 then anchor=true end end
            assert(anchor)
            reset(db);point(8020,8020,48,102);assert(#db.segments==5)
        ''')

    def test_simplification_anchors_and_disabled_recording(self):
        l=client()
        l.execute('''
            local p={};for i=1,100 do p[i]={x=i,y=i,at=i,anchor=i==42} end
            local result=ns.Annals.Simplify(p,10);assert(#result==3 and result[2].at==42)
            j:Quest('accepted',42,'Preserved');local event=db.events[1]
            trail:SetEnabled(false);point(10,10,100);j:Quest('completed',42,'Preserved')
            assert(#db.events==2 and db.events[1]==event)
            local n=#db.segments;trail:SetEnabled(true);point(20,20,102);assert(#db.segments==n+1)
        ''')

    def test_links_between_quest_events_preserve_labels(self):
        l=client()
        l.execute('''
            j:Quest('accepted',42,'Quest');j:Discover('bestiary','12','Wolf',nil,'original')
            j:Discover('atlas','p1','Cave',nil,'ref1');j:Discover('angling','water1','River',nil,'ref2')
            j:Discover('atlas','p1','Renamed cave',nil,'ref1');assert(#db.events==4)
            j:Quest('completed',42,'Quest');assert(#db.events==5 and db.events[3].title=='Cave')
            reset(db);j:Discover('atlas','p1','Reused ID',nil,'ref3');assert(#db.events==6)
        ''')

    def test_malformed_and_future_stores_are_preserved(self):
        l=client()
        l.execute('''
            for _,bad in ipairs({{schema=2,precious='keep'},{events='keep'},{events={[2]={title='keep'}}},{pending={a='keep'}}}) do
                local copy=snapshot(bad);reset(bad);assert(j.readOnly);j:Quest('accepted',42,'No');assert(snapshot(bad)==copy)
            end
            reset({events={{kind='accepted',at=10,title='Bad',reward={automatic={'bad'}}}}})
            assert(#j.events==0 and #db.events==1);j:Quest('accepted',42,'Valid');assert(#db.events==2)
            reset({segments={false,{at=100,finish=50}}});local first,last=j:Bounds();assert(first==now and last==now)
        ''')

    def test_large_ranges_scrubber_map_filter_and_cache_bound(self):
        l=client()
        l.execute('''
            for i=1,200 do
                db.segments[i]={v=1,mapID=i%2==0 and 101 or 102,at=i*100,finish=i*100+10,
                    data=ns.Annals.EncodePoint({x=100,y=100,at=i*100},i*100)..ns.Annals.EncodePoint({x=200,y=200,at=i*100+10},i*100)}
            end
            for i=1,10000 do j:Append('accepted','Quest '..i,{questID=i},{mapID=101,x=1,y=1,level=23},i*2) end
            local idx=ns.Annals.JourneyIndex(j,0,20010,101)
            local lines,markers,cursor,limited=ns.Annals.JourneyFrame(idx,999999)
            assert(#lines<=2048 and #markers<=512 and limited and cursor.at==20010)
            for at=0,20000,100 do ns.Annals.JourneyFrame(idx,at) end
            assert(#idx.order<=64);lines,markers,cursor=ns.Annals.JourneyFrame(idx,-1);assert(#lines==0 and #markers==0 and not cursor)
            assert(#j:Range(0,20000,'accepted',23)==10000)
        ''')

    def test_full_toc_ui_navigation_and_link_resolution(self):
        l=full_client()
        l.execute('''
            local c=ns.AnnalsController;assert(c and #c.shell.order==8)
            c.shell:ShowSection('annals');assert(c.main)
            assert(c.main.slider.track,'journey slider needs an opaque track')
            local color=c.main.slider.track.colorTexture
            assert(color[1]==0 and color[2]==0 and color[3]==0 and color[4]==1)
            local entries={x={id='x',name='Original'}};local opened
            c:RegisterReference('test',{resolve=function(link) return entries[link.key] end,open=function(e) opened=e.id;return true end})
            c.journal:Discover('test','x','Original',nil,'fixed');local link=c.journal.db.events[1].link
            assert(c:OpenLink(link) and opened=='x');entries.x=nil;assert(not c:OpenLink(link))
            assert(c.journal.db.events[1].title=='Original')
            for i=1,100 do c.journal:Append('accepted','Long timeline '..i,{questID=i}) end
            c:Refresh(true);assert(#c.main.rows==7 and #c.rows==101)
            c:Refresh();c.shell:ShowSection('bestiary');c.shell:ShowSection('annals')
            assert(c.main.journey:IsVisible() and not ns.AnnalsDiscoveryError)
        ''')

    def test_backup_contains_annals_and_old_envelope_accepted(self):
        l=full_client()
        l.execute('''
            ns.AnnalsController.journal:Quest('accepted',42,'Backup quest')
            local B=ns.FieldbookBackups;local encoded=assert(B.Capture());local s=assert(B.Decode(encoded))
            assert(s.stores.AzerothFieldbookAnnalsDB.events[1].title=='Backup quest')
            s.present.AzerothFieldbookAnnalsDB=nil;s.stores.AzerothFieldbookAnnalsDB=nil
            assert(B.Encode(s));assert(B.CanRestore(s))
        ''')

    def test_actual_map_renderer_and_overlapping_marker_cycle(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            j:Append('accepted','First',{questID=1},{mapID=101,x=2500,y=7500,level=23},100)
            j:Append('completed','Second',{questID=2},{mapID=101,x=2500,y=7500,level=23},110)
            j.db.segments={{v=1,mapID=101,at=100,finish=110,data=ns.Annals.EncodePoint({x=2500,y=7500,at=100},100)..ns.Annals.EncodePoint({x=3000,y=7500,at=110},100)}}
            c.shell:ShowSection('annals')
            function c.main.map.canvas:CreateLine() return CreateFrame('Texture',nil,self) end
            c:SetRange(100,110);c.mapID=101;c:Refresh()
            local map=c.main.map;assert(map.available and #map.lines==1 and #map.pins==1)
            assert(map.playerArrow:IsShown())
            local pin=map.pins[1];pin.scripts.OnClick(pin,'LeftButton');assert(c.selected==1)
            assert(c.main.show.afbSelected and c.main.detail:IsVisible() and not c.main.timeline:IsShown())
            assert(c.main.journey:IsVisible() and c.at==110 and c.mapID==101)
            c:Refresh();pin.scripts.OnClick(pin,'LeftButton');assert(c.selected==2)
            c.shell:ShowSection('atlas');c.shell:ShowSection('annals');assert(map.playerArrow:IsShown())
            C_Map.GetMapRectOnMap=function(child,parent)
                if child==101 and parent==100 then return 0.1,0.5,0.2,0.6 end
            end
            j:Append('flight','Test flight',nil,{mapID=101,x=2500,y=7500,level=23},110)
            c.mapID=100;c.index=nil;c:Refresh(true)
            assert(map.available and map.lines[1]:IsShown() and map.pins[1]:IsShown())
            assert(map.pins[1].icon.texture==ns.Annals.icons.flight)
            assert(map.pins[1].group[1].point.mapID==100)
        ''')

    def test_real_discovery_emitters_keep_sources_intact(self):
        l=full_client();l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local n=#c.journal.db.events
            local gathering=ns.CreateGatheringJournal({},function() return 1 end)
            local lore=ns.CreateLoreJournal({})
            local shell=ns.CreateFieldbookShell()
            shell:RegisterSection('gathering',{title='Gathering',build=function() end});shell:RegisterSection('lore',{title='Lore',build=function() end})
            AzerothFieldbookAnnalsDB={}
            c=ns.InitializeAnnals(shell,{gathering={journal=gathering},lore={journal=lore}});n=0
            local id=gathering:Discover('herb','Peacebloom',now,'Coast',{mapID=101,name='Coast'})
            assert(id and #c.journal.db.events==n+1)
            gathering:Discover('herb','Peacebloom',now,'Coast',{mapID=101,name='Coast'});assert(#c.journal.db.events==n+1)
            local entry=assert(lore:Create('mystery',{title='Mystery',origin='manual'}))
            assert(entry.title=='Mystery' and #c.journal.db.events==n+2)
            assert(lore:Create('mystery',{title='Imported',origin='reported'}))
            assert(#c.journal.db.events==n+2,'reported entry must not become a local discovery')
            local detached=ns.CreateLoreJournal({});assert(detached:Create('mystery',{title='Staged',origin='manual'}))
            assert(#c.journal.db.events==n+2,'detached staging journal must not publish history')
            assert(not ns.AnnalsDiscoveryError)
        ''')

    def test_old_backup_restore_preserves_current_annals(self):
        from test_fieldbook_backups import client as backup_client, reload_client
        l=backup_client()
        l.execute('''
            ns.AnnalsController.journal:Quest('accepted',42,'Keep this history')
            local B=ns.FieldbookBackups;local s=assert(B.Decode(assert(B.Capture())))
            s.present.AzerothFieldbookAnnalsDB=nil;s.stores.AzerothFieldbookAnnalsDB=nil
            assert(B.RequestRestore(assert(B.Encode(s))))
        ''')
        restored=reload_client(l)
        restored.execute("assert(AzerothFieldbookAnnalsDB.events[1].title=='Keep this history')")


if __name__=='__main__':
    unittest.main()
