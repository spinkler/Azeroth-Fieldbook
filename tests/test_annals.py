import unittest
from annals_test_harness import client
from test_player_names_preservation import full_client
from atlas_test_harness import ENV


class AnnalsTests(unittest.TestCase):
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
            c:SetRange(100,3710);c.mapID=101;c.mode='journey';c:Refresh()
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
            lines,markers=A.JourneyFrame(world,3);assert(#lines==1 and #markers==1)
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
            c.mode='journey';c:Refresh();c.shell:ShowSection('bestiary');c.shell:ShowSection('annals')
            assert(c.mode=='journey' and not ns.AnnalsDiscoveryError)
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
            c:SetRange(100,110);c.mapID=101;c.mode='journey';c:Refresh()
            local map=c.main.map;assert(map.available and #map.lines==1 and #map.pins==1)
            assert(not map.playerArrow:IsShown())
            local pin=map.pins[1];pin.scripts.OnClick(pin,'LeftButton');assert(c.selected==1)
            c.mode='journey';c:Refresh();pin.scripts.OnClick(pin,'LeftButton');assert(c.selected==2)
            c.shell:ShowSection('atlas');c.shell:ShowSection('annals');assert(not map.playerArrow:IsShown())
            C_Map.GetMapRectOnMap=function(child,parent)
                if child==101 and parent==100 then return 0.1,0.5,0.2,0.6 end
            end
            j:Append('flight','Test flight',nil,{mapID=101,x=2500,y=7500,level=23},110)
            c.mapID=100;c.mode='journey';c.index=nil;c:Refresh(true)
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
