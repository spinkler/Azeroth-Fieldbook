"""Entrance evidence, native-event lifecycle and preservation of Atlas surveys."""
import unittest
from atlas_test_harness import new_atlas
from ui_test_harness import ROOT
from test_account_sections import account


ENV = r'''
    C=ns.AtlasEnvironment;E=ns.AtlasEntrances;D=ns.AtlasEntranceTracking;T=ns.AtlasEntranceTypes
    clock=100;inside=false;mapID=101;px=.25;py=.25;mx=.6;my=.4
    area='Quiet Hollow';mini='Quiet Hollow';microName='Quiet Hollow'
    Enum.UIMapType={Zone=3,Dungeon=4,Micro=5}
    function GetTime() return clock end
    function IsIndoors() return inside end
    function IsOutdoors() return not inside end
    function GetLocale() return 'enUS' end
    function GetSubZoneText() return area end
    function GetMinimapZoneText() return mini end
    function GetPlayerFacing() return 1.2 end
    function GetUnitSpeed() return speed or 0 end
    function UnitIsDeadOrGhost() return dead or false end
    function UnitOnTaxi() return taxi or false end
    function IsFlying() return flying or false end
    function IsInInstance() return instanced or false end
    C_Map.GetMapInfo=function(id)
        if id==100 then return {mapID=id,mapType=2,name='Continent',parentMapID=0} end
        if id==101 or id==102 then return {mapID=id,mapType=3,name='Coast '..id,parentMapID=100} end
        if id==201 or id==202 then return {mapID=id,mapType=5,name=microName,parentMapID=101} end
        if id==203 then return {mapID=id,mapType=4,name='Deep floor',parentMapID=201} end
    end
    reads={};artReads={}
    C_Map.GetPlayerMapPosition=function(id)
        reads[#reads+1]=id
        if id==101 or id==102 then return {x=px,y=py} end
        if id==201 or id==202 or id==203 then return {x=mx,y=my} end
    end
    C_Map.GetMapWorldSize=function(id)
        if id==101 or id==102 then return 1000,2000 end
        return 100,200
    end
    local art=C_Map.GetMapArtLayers
    C_Map.GetMapArtLayers=function(id) artReads[id]=(artReads[id] or 0)+1;return art(id) end
    function settle()
        local S=ns.AtlasSubzones
        for _=1,100000 do if not S.worker or not S.worker:IsShown() then return end;S.Step() end
        error('survey worker did not finish')
    end
    timers={}
    C_Timer={After=function(delay,fn) timers[#timers+1]={at=clock+delay,fn=fn} end}
    function advance(seconds)
        local target=clock+seconds;local limit=0
        while true do
            local index,at
            for i,t in ipairs(timers) do if t.at<=target and (not at or t.at<at) then index,at=i,t.at end end
            if not index then break end
            local t=table.remove(timers,index);clock=t.at;t.fn();limit=limit+1
            assert(limit<10000,'unbounded timers')
        end
        clock=target
    end
    function observe(x,direction,best,name)
        local context={zoneMapID=101,zone='Coast 101',bestMapID=best or 201,
            microMapID=(best~=101) and (best or 201) or nil,parentMapID=101,
            mapName=name or 'Quiet Hollow',microName=(best~=101) and (name or 'Quiet Hollow') or nil,
            subzone=name or 'Quiet Hollow',minimap=name or 'Quiet Hollow'}
        return {direction=direction or 'entry',at=now,exterior={mapID=101,x=x or 2500,y=2500},
            size={width=1000,height=2000},interior=context,coordinateSource='last-exterior',
            interiorPosition=context.microMapID and {mapID=context.microMapID,x=6000,y=4000} or nil}
    end
    function enabled()
        j.state.autoEntrances=true;d=D.Create(j.entrances);d:Reset(C.Capture())
    end
    function feed(state,x,seconds,best)
        inside=state;px=x or px;clock=clock+(seconds or .4);mapID=best or (state and 201 or 101)
        return d:Feed(C.Capture())
    end
    function enter(x)
        feed(true,x or .252,.1);local id=feed(true,x or .252,.4)
        assert(id,'entry did not commit');return id
    end
    function exitAt(x)
        feed(true,.265,1);feed(true,.265,1)
        feed(false,x or .25,1);return feed(false,x or .25,.4)
    end
    c:Refresh();settle()
'''


class EntranceTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_atlas(ui=True)
        self.lua.execute(ENV)

    def test_defaults_off_login_indoors_and_reenable_baseline(self):
        self.lua.execute('''
            assert(j.state.autoEntrances==false and j.state.layers.entrance==false)
            enabled();inside=true;mapID=201;d:Reset(C.Capture())
            feed(true,.25,1);assert(not next(j.entrances.records))
            c.entranceObserver:SetEnabled(false)
            d=c.entranceObserver.detector;feed(false,.25,1);feed(true,.25,1);feed(true,.25,1)
            assert(not next(j.entrances.records))
            c.entranceObserver:SetEnabled(true);advance(1)
            assert(not next(j.entrances.records),'Enabling indoors is not entry')
        ''')

    def test_entry_exit_and_repeated_crossings_corroborate_fixed_anchor(self):
        self.lua.execute('''
            enabled();local id=enter();local entry=j.entrances:Get(id)
            assert(entry.entries==1 and entry.exits==0 and entry.evidence=='candidate')
            assert(entry.exterior.mapID==101 and entry.exterior.x==2500)
            assert(entry.interior.microMapID==201 and entry.interiorPosition.mapID==201)
            local anchor=snapshot(entry.exterior)
            assert(exitAt(.255)==id)
            entry=j.entrances:Get(id);assert(entry.entries==1 and entry.exits==1 and entry.evidence=='corroborated')
            feed(false,.24,1);feed(false,.24,1);feed(false,.25,1)
            assert(enter()==id and A.Count(j.entrances.records)==1)
            assert(j.entrances:Get(id).total==3 and snapshot(j.entrances:Get(id).exterior)==anchor)
            assert(j.entrances:Get(id).latest.coordinateSource=='last-exterior')
        ''')

    def test_exit_after_indoor_login_is_observed_not_synthetic_entry(self):
        self.lua.execute('''
            inside=true;mapID=201;enabled()
            feed(false,.251,.1);local id=feed(false,.251,.4)
            local e=assert(j.entrances:Get(id));assert(e.entries==0 and e.exits==1)
            assert(e.exterior.x==2510 and e.latest.coordinateSource=='first-exterior')
        ''')

    def test_boundary_chatter_requires_stability_and_excursion(self):
        self.lua.execute('''
            enabled()
            for _=1,30 do feed(true,.251,.1);feed(false,.25,.1) end
            assert(not next(j.entrances.records),'Brief indoor flickers must not commit')
            local id=enter()
            for _=1,20 do feed(false,.25,.4);feed(false,.25,.4);feed(true,.251,.4);feed(true,.251,.4) end
            assert(A.Count(j.entrances.records)==1 and j.entrances:Get(id).total==1,
                'Stable toggles at the threshold must not inflate evidence without an excursion')
        ''')

    def test_wide_threshold_dedup_and_distant_entrances(self):
        self.lua.execute('''
            enabled();local id=assert(j.entrances:Record(observe(2500)))
            assert(j.entrances:Record(observe(2700,'exit'))==id)
            assert(j.entrances:Record(observe(2850))==id,'35 yard inclusive wide-mouth threshold')
            local second=assert(j.entrances:Record(observe(3000)))
            assert(second~=id and A.Count(j.entrances.records)==2,'No transitive cluster growth')
            assert(j.entrances:Get(id).exterior.x==2500)
            local far=assert(j.entrances:Record(observe(8000)))
            assert(far~=id and far~=second,'One interior can have several entrances')
        ''')

    def test_clustering_respects_metric_aspect_ratio_and_identity(self):
        self.lua.execute('''
            enabled();local id=j.entrances:Record(observe(2500))
            local tall=observe(2500);tall.exterior.y=2700
            assert(j.entrances:Record(tall)~=id,'200 normalized Y units are 40 yards on this map')
            assert(j.entrances:Record(observe(2501,'entry',202))~=id,'Conflicting Micro IDs do not merge')
            local a=observe(4000,'entry',101,'First room');local unknown=j.entrances:Record(a)
            local b=observe(4100,'entry',101,'Unknown room')
            assert(j.entrances:Record(b)==unknown,'Unknown identity can merge within 12 yards')
            b.exterior.x=4130;assert(j.entrances:Record(b)~=unknown)
        ''')

    def test_login_loading_death_and_zone_transfers_reset_pending(self):
        self.lua.execute('''
            for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_LEAVING_WORLD','LOADING_SCREEN_ENABLED',
                'LOADING_SCREEN_DISABLED','ZONE_CHANGED_NEW_AREA','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST'}) do
                inside=false;mapID=101;px=.25;c.entranceObserver:SetEnabled(true)
                local f=c.entranceObserver
                inside=true;mapID=201;f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS')
                f.scripts.OnEvent(f,event);advance(2)
                assert(not next(j.entrances.records),event..' must invalidate pending crossing')
                f.scripts.OnEvent(f,'PLAYER_ENTERING_WORLD');advance(1)
            end
        ''')

    def test_teleport_jump_stale_map_and_spellcasts_fail_closed(self):
        self.lua.execute('''
            enabled();feed(true,.9,.1);feed(true,.9,.4);assert(not next(j.entrances.records))
            inside=false;mapID=101;px=.25;enabled();feed(true,.252,10);feed(true,.252,.4)
            assert(not next(j.entrances.records),'Stale exterior sample')
            inside=false;mapID=101;enabled();feed(true,.25,.1,102);feed(true,.25,.4,102)
            assert(not next(j.entrances.records),'Different canonical zone')
            for _,event in ipairs({'UNIT_SPELLCAST_SENT','UNIT_SPELLCAST_START','UNIT_SPELLCAST_SUCCEEDED',
                'UNIT_SPELLCAST_STOP','UNIT_SPELLCAST_CHANNEL_START'}) do
                inside=false;mapID=101;px=.25
                local f=c.entranceObserver;c.entranceObserver:SetEnabled(true)
                f.scripts.OnEvent(f,event,'player');inside=true;mapID=201
                f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS');advance(1.5)
                assert(not next(j.entrances.records),event)
                f.scripts.OnEvent(f,'UNIT_SPELLCAST_STOP','player');advance(1.5)
            end
        ''')

    def test_missing_invalid_and_secret_environment_data(self):
        self.lua.execute('''
            enabled();px=nil;assert(not C.Capture());d:Feed(nil)
            px=.25;feed(true,.25,.4);feed(true,.25,.4);assert(not next(j.entrances.records))
            for _,value in ipairs({0/0,math.huge,-1,1.1,secret,'0.5'}) do
                mx=value;assert(not C.Position(201))
            end
            mx=0;my=0;assert(not C.Position(201))
            px=0;py=0;assert(not C.Capture())
            px=.25;py=.25;IsIndoors=function() return secret end;IsOutdoors=function() return secret end
            assert(not C.Capture());IsIndoors=function() return true end;IsOutdoors=function() return true end
            assert(C.Indoors()==nil,'Contradictory signals are not a boundary')
            IsOutdoors=nil;assert(C.Indoors()==true,'Feature-detect the remaining signal')
            IsIndoors=function() error('unavailable') end;assert(not C.Capture())
        ''')

    def test_flight_death_instance_and_api_errors_pause_capture(self):
        self.lua.execute('''
            for _,field in ipairs({'dead','taxi','flying','instanced'}) do
                _G[field]=true;assert(not C.Capture(),field);_G[field]=false
            end
            IsFlying=function() error('restricted') end;assert(not C.Capture())
            IsFlying=nil;assert(C.Capture(),'Missing optional APIs remain supported')
        ''')

    def test_map_hierarchy_is_bounded_and_never_relabels_micro_coordinates(self):
        self.lua.execute('''
            mapID=203;inside=true
            local context=C.Context();assert(context.zoneMapID==101 and context.microMapID==201)
            local p=C.Capture();assert(p.position.mapID==101 and p.position.x==2500)
            assert(p.interiorPosition.mapID==201 and p.interiorPosition.x==6000)
            local original=C_Map.GetPlayerMapPosition
            C_Map.GetPlayerMapPosition=function(id) if id==101 then return nil end;return original(id) end
            assert(not C.Capture(),'No canonical zone position: do not substitute Micro position')
            local calls=0;C_Map.GetMapInfo=function(id) calls=calls+1;return {mapType=5,name='Cycle',parentMapID=id} end
            assert(not C.Context().zoneMapID and calls<=2)
            calls=0;C_Map.GetMapInfo=function(id) calls=calls+1;return {mapType=5,name='Chain',parentMapID=id+1} end
            assert(not C.Context().zoneMapID and calls<=C.MAX_ANCESTRY+1)
        ''')

    def test_world_conversion_roundtrip_and_map_size_fallback(self):
        self.lua.execute('''
            function CreateVector2D(x,y) return {x=x,y=y} end
            C_Map.GetWorldPosFromMapPos=function(id,p) return 7,{x=p.x*1000,y=p.y*2000} end
            C_Map.GetMapPosFromWorldPos=function(world,p,id) return id,{x=p.x/1000,y=p.y/2000} end
            local a={mapID=101,x=2500,y=2500};local b={mapID=101,x=2700,y=2500}
            local wa,wb=C.World(a),C.World(b);assert(wa.continentID==7 and wa.source=='map-roundtrip')
            local distance,metric=C.Distance(a,b,wa,wb,C.Size(101));assert(distance==20 and metric=='world')
            wb.x=999;distance,metric=C.Distance(a,b,wa,wb,C.Size(101));assert(distance==20 and metric=='map-size')
            C_Map.GetMapPosFromWorldPos=function() return 201,{x=.25,y=.25} end
            assert(not C.World(a),'Roundtrip to a different map is invalid')
            C_Map.GetMapPosFromWorldPos=function() error('unsupported') end;assert(not C.World(a))
            C_Map.GetWorldPosFromMapPos=function() return secret,secret end;assert(not C.World(a))
            local o=observe();o.size=nil;o.world=nil;enabled()
            assert(not j.entrances:Record(o),'No metric means no unmergeable candidate')
        ''')

    def test_type_suggestions_are_token_aware_and_only_supported_types(self):
        self.lua.execute('''
            local known={};for _,category in ipairs(A.categories) do known[category.id]=true end
            for _,spec in ipairs({{'Cavern of Mists','cave'},{'Silver Mine','cave'},{'Dark Tunnel','route'},
                {'Old Ruins','ruins'},{'Hidden Den','cave'}}) do
                local suggestion=T.Suggest({microName=spec[1]})
                assert(suggestion.category==spec[2] and suggestion.kind=='inferred' and known[suggestion.category])
            end
            for _,name in ipairs({'Golden Garden','Tomb of Kings','Crypt','Catacomb','Inn','Building'}) do
                local suggestion=T.Suggest({microName=name});assert(suggestion.category=='entrance' and suggestion.kind=='none',name)
            end
            assert(T.Suggest({microName='Cave'},'deDE').kind=='none','No English guessing in other locales')
            local category=A.category.cave;A.category.cave=nil
            assert(T.Suggest({subzone='Cave'}).kind=='none');A.category.cave=category
        ''')

    def test_classification_reload_and_player_authority(self):
        self.lua.execute('''
            enabled();local id=j.entrances:Record(observe(2500,'entry',201,'Silver Mine'))
            local entry=j.entrances:Get(id);assert(entry.classification.kind=='inferred' and entry.classification.category=='cave')
            local view=c.entries:Get(E.PREFIX..id);view.notes='Notes alone';assert(c.entries:Save(view,view.id))
            assert(j.entrances:Get(id).classification.kind=='inferred')
            view=c.entries:Get(E.PREFIX..id);view.confirmCategory='ruins';assert(c.entries:Save(view,view.id))
            assert(j.entrances:Record(observe(2501,'exit',201,'Dark Tunnel'))==id)
            entry=j.entrances:Get(id);assert(entry.classification.kind=='player' and entry.classification.category=='ruins')
            local bytes=snapshot(saved);local reload=ns.CreateAtlasJournal(saved)
            assert(bytes==snapshot(saved) and reload.entrances:Get(id).classification.kind=='player')
            local generic=j.entrances:Record(observe(8000,'entry',201,'Golden Garden'))
            assert(j.entrances:Get(generic).classification.kind=='none')
        ''')

    def test_editor_plain_type_choices_preserve_explicit_confirmation_and_reload(self):
        self.lua.execute('''
            enabled();local id=j.entrances:Record(observe(2500,'entry',201,'Deep Cave'))
            c:OpenEditor(E.PREFIX..id);local editor=c.editor
            assert(rawget(editor.category,'savedCheck')==nil and rawget(editor.category,'savedBox')==nil)
            editor.notes:SetText('More notes');assert(editor:Save())
            assert(j.entrances:Get(id).classification.kind=='inferred')
            click(editor.category);local picker=editor.categoryMenu;picker.scripts.OnShow()
            assert(picker.rows[1].categoryID=='cave' and rawget(picker.rows[1],'savedCheck')==nil)
            click(picker.rows[1]);assert(editor:Save())
            assert(j.entrances:Get(id).classification.kind=='player')
            local reload=ns.CreateAtlasJournal(saved);assert(reload.entrances:Get(id).classification.kind=='player')
            click(editor.category);click(picker.rows[3]);assert(editor:Save())
            assert(j.entrances:Get(id).classification.category=='route','Existing Route category stays authoritative')
            assert(not editor.links.enabled and not editor.stops:IsShown())
        ''')

    def test_generic_layer_independence_and_typed_layer_filters(self):
        self.lua.execute('''
            enabled();local id=j.entrances:Record(observe());c:Refresh()
            assert(not j.entrances:Layer('entrance') and #c.entries:List('',101,false)==1)
            for _,pin in ipairs(m.map.pins or {}) do assert(not pin:IsShown()) end
            c.entries:SetLayer('entrance',true);c:Refresh();assert(m.map.pins[1]:IsShown())
            c.entries:SetLayer('entrance',false);assert(j.entrances:Record(observe(2501,'exit'))==id)
            c.entranceObserver:SetEnabled(false);assert(j.entrances:Get(id).total==2)
            c.entries:SetLayer('entrance',true);c:Refresh();assert(m.map.pins[1]:IsShown(),'Recording off preserves visible observations')
            enabled();local typed=j.entrances:Record(observe(7000,'entry',201,'Deep Cave'))
            j:SetLayer('cave',false);c:Select(E.PREFIX..typed);assert(m.reveal:IsShown())
            click(m.reveal);assert(j:Layer('cave'))
        ''')

    def test_existing_records_reports_and_coordinate_edits_stay_separate(self):
        self.lua.execute('''
            local deliberate=j:Save(fixture())
            local draft={title='Report',region={kind='selection',name='Region'},records={[deliberate]=true}}
            local report=snapshot(assert(R.Build(j,draft,'Author')));local records=snapshot(j.records)
            enabled();local id=j.entrances:Record(observe())
            assert(#j:List('',101,false)==1 and not j:Get(E.PREFIX..id))
            assert(snapshot(j.records)==records and snapshot(assert(R.Build(j,draft,'Author')))==report)
            local e=c.entries:Get(E.PREFIX..id);local before=snapshot(j.entrances.records)
            e.mapID=201;e.x=6000;e.y=4000;assert(not c.entries:Save(e,e.id));assert(snapshot(j.entrances.records)==before)
            e.mapID=101;assert(c.entries:Save(e,e.id));local saved=j.entrances:Get(id)
            assert(saved.position.mapID==101 and saved.exterior.x==2500,'Manual display position does not move clustering anchor')
            assert(saved.interiorPosition.mapID==201 and saved.interiorPosition.x==6000)
        ''')

    def test_corrupt_future_and_readonly_extension_preserves_old_journal(self):
        self.lua.execute('''
            local old={schema=1,entrances={schema=999,records={future={data='retain'}}}}
            local journal=ns.CreateAtlasJournal(old);local before=snapshot(old.entrances)
            assert(not journal.readOnly and journal.entrances.readOnly)
            assert(journal:Save(fixture()));journal.entrances:SetLayer('cave',false)
            assert(not journal:Layer('cave') and snapshot(old.entrances)==before)
            local future={schema=999,settings={autoEntrances=true},entrances={future=true}}
            before=snapshot(future);journal=ns.CreateAtlasJournal(future)
            assert(journal.readOnly and not journal.entrances:Record(observe()) and before==snapshot(future))
            enabled();local id=j.entrances:Record(observe());j.entrances.records[id].exterior.mapID=201
            local corrupt=snapshot(saved.entrances);assert(not j.entrances:Get(id))
            assert(ns.CreateAtlasJournal(saved).entrances.records[id] and snapshot(saved.entrances)==corrupt)
        ''')

    def test_capacity_and_detached_evidence(self):
        self.lua.execute('''
            enabled();E.MAX_RECORDS=1;local id=j.entrances:Record(observe())
            local copy=j.entrances:Get(id);copy.exterior.x=9999;copy.interior.microMapID=888
            assert(j.entrances:Get(id).exterior.x==2500)
            assert(not j.entrances:Record(observe(9000)) and j.entrances:Record(observe(2501,'exit'))==id)
        ''')

    def test_event_coalescing_movement_lifetime_and_toggle_cancels_work(self):
        self.lua.execute('''
            local f=c.entranceObserver;f:SetEnabled(true)
            assert(f.scripts.OnUpdate==nil and #timers==0)
            f.scripts.OnEvent(f,'PLAYER_STARTED_MOVING');assert(#timers==1)
            advance(1);inside=true;mapID=201;px=.252
            for _,event in ipairs({'ZONE_CHANGED_INDOORS','ZONE_CHANGED','PLAYER_MAP_CHANGED','NEW_WMO_CHUNK'}) do f.scripts.OnEvent(f,event) end
            assert(not next(j.entrances.records));advance(.4)
            local id=next(j.entrances.records);assert(id and j.entrances:Get(id).total==1)
            f.scripts.OnEvent(f,'PLAYER_STOPPED_MOVING');advance(2);assert(#timers==0)
            f.scripts.OnEvent(f,'PLAYER_STARTED_MOVING');f:SetEnabled(false);advance(2)
            assert(#timers==0 and j.entrances:Get(id).total==1 and f.scripts.OnUpdate==nil)
        ''')

    def test_disabling_mid_transition_cannot_write_later(self):
        self.lua.execute('''
            local f=c.entranceObserver;f:SetEnabled(true)
            inside=true;mapID=201;f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS')
            f:SetEnabled(false);advance(2);assert(not next(j.entrances.records))
            f:SetEnabled(true);advance(2);assert(not next(j.entrances.records))
        ''')

    def test_micro_view_removed_and_entrance_controls_retained(self):
        self.lua.execute("""
            assert(m.microMap==nil and c.microView==nil)
            assert(m.autoEntrances and not j.state.autoEntrances)
            m.autoEntrances:SetChecked(true);click(m.autoEntrances)
            assert(j.state.autoEntrances)
            mapID=201;c:Refresh()
            assert(m.map.displayedMapID==101)
        """)

    def test_subzone_observer_is_identical_without_detector_and_with_off_on(self):
        self.lua.execute('''
            function surveyRun(mode)
                inside=false;mapID=101;px=.25;py=.25;area='Meadow';clock=100;timers={}
                local journal=ns.CreateAtlasJournal({});local notifications=0
                local survey=ns.AtlasSubzones.Track(journal,function() notifications=notifications+1 end)
                local entrance
                if mode~=nil then
                    journal.state.autoEntrances=mode;entrance=D.Track(journal)
                end
                local function step(event,newInside,x,name,best)
                    clock=clock+.5;inside=newInside;px=x;area=name;mapID=best or 101
                    survey.scripts.OnEvent(survey,event)
                    if entrance then entrance.scripts.OnEvent(entrance,event) end
                    survey.scripts.OnUpdate(survey,.25);advance(.4);settle()
                end
                step('PLAYER_ENTERING_WORLD',false,.25,'Meadow')
                step('ZONE_CHANGED',false,.252,'River')
                step('ZONE_CHANGED_INDOORS',true,.254,'Cave',201)
                step('ZONE_CHANGED',true,.27,'Deep Cave',201)
                step('ZONE_CHANGED_INDOORS',false,.26,'River')
                step('PLAYER_LEAVING_WORLD',false,.26,'River')
                step('PLAYER_ENTERING_WORLD',true,.85,'Remote',201)
                step('ZONE_CHANGED_INDOORS',false,.852,'Forest')
                survey.scripts.OnEvent(survey,'PLAYER_LOGOUT')
                return snapshot({rows=journal.saved.subzones,previous=journal.subzones.previous,
                    revisions=journal.subzones.revisions,revision=journal.subzones.revision,notifications=notifications})
            end
            local original=surveyRun(nil)
            assert(original==surveyRun(false),'Automation OFF changed surveys')
            assert(original==surveyRun(true),'Automation ON changed surveys')
        ''')

    def test_subzone_toggle_does_not_control_entrances_or_manual_point_semantics(self):
        self.lua.execute('''
            j.state.automaticMapping=false;enabled();local id=enter()
            assert(id and not next(saved.subzones),'Entrance discovery does not own survey recording')
            inside=false;mapID=101;px=.75;py=.75
            assert(j.subzones:RecordPoint());local survey=snapshot(saved.subzones)
            c.entranceObserver:SetEnabled(false)
            assert(survey==snapshot(saved.subzones) and j.state.automaticMapping==false)
        ''')

    def test_account_scope_collision_safe_import_and_future_store(self):
        account(self.lua)
        self.lua.execute('''
            enabled();local id=j.entrances:Record(observe());local personal=A.Copy(saved)
            local second=A.Copy(saved);second.entrances.records[id].classification={kind='player',category='camp'}
            local before=snapshot(second.entrances)
            local shared=ns.SelectSectionStorage('atlas',personal);scope(2)
            shared=ns.SelectSectionStorage('atlas',second)
            assert(A.Count(shared.entrances.records)==2 and snapshot(second.entrances)==before)
            for key,e in pairs(shared.entrances.records) do assert(key==e.id and E.Valid(e)) end
            scope(2);assert(A.Count(ns.SelectSectionStorage('atlas',second).entrances.records)==2)
            scope(2,false);assert(ns.SelectSectionStorage('atlas',second)==second)
            local future={schema=1,entrances={schema=999,records={}}};scope(3)
            assert(ns.SelectSectionStorage('atlas',future)==future,'Unknown extension defers account migration')
        ''')

    def test_initialization_blocked_cancels_pending_observations(self):
        self.lua.execute('''
            local f=c.entranceObserver;f:SetEnabled(true)
            inside=true;mapID=201;f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS')
            local before=snapshot(saved);ns.InitializationBlocked=true;advance(3)
            f:SetEnabled(false);f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS')
            assert(before==snapshot(saved) and not next(j.entrances.records))
        ''')

    def test_summon_pending_and_acceptance_in_same_zone_never_form_an_entrance(self):
        self.lua.execute('''
            local f=c.entranceObserver;f:SetEnabled(true)
            summon=1;C_IncomingSummon={IncomingSummonStatus=function(unit) assert(unit=='player');return summon end}
            f.scripts.OnEvent(f,'CONFIRM_SUMMON');advance(4)
            inside=true;mapID=201;px=.252;summon=2
            f.scripts.OnEvent(f,'INCOMING_SUMMON_CHANGED','player')
            f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS');advance(4)
            assert(not next(j.entrances.records),'Accepted summon is a transfer, even without loading or a zone change')
            summon=0;f.scripts.OnEvent(f,'PLAYER_MAP_CHANGED');advance(.5)
            assert(not next(j.entrances.records),'Arrival primes indoor baseline')
            inside=false;mapID=101;px=.253;f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS');advance(.5)
            local id=assert(next(j.entrances.records));assert(j.entrances:Get(id).entries==0 and j.entrances:Get(id).exits==1)
        ''')

    def test_declined_cancelled_and_unknown_api_summons_resume_safely(self):
        self.lua.execute('''
            local f=c.entranceObserver;f:SetEnabled(true)
            f.scripts.OnEvent(f,'CONFIRM_SUMMON');inside=true;mapID=201;advance(5)
            f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS');assert(not next(j.entrances.records))
            f.scripts.OnEvent(f,'CANCEL_SUMMON');advance(3.1)
            assert(not next(j.entrances.records),'Unknown API cancellation/arrival primes, never compares the request origin')
            inside=false;mapID=101;f.scripts.OnEvent(f,'PLAYER_ENTERING_WORLD');advance(.5)
            summon=3;C_IncomingSummon={IncomingSummonStatus=function() return summon end}
            f.scripts.OnEvent(f,'INCOMING_SUMMON_CHANGED','player');advance(3.1)
            inside=true;mapID=201;px=.252;f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS');advance(.5)
            assert(A.Count(j.entrances.records)==1,'A later physical crossing still works')
        ''')

    def test_summon_signals_feature_detection_and_other_party_members(self):
        self.lua.execute('''
            C_SummonInfo={GetSummonConfirmTimeLeft=function() return 20 end};assert(not C.Capture())
            C_SummonInfo=nil;GetSummonConfirmTimeLeft=function() return 20 end;assert(not C.Capture())
            GetSummonConfirmTimeLeft=function() return 0 end;assert(C.Capture())
            GetSummonConfirmTimeLeft=function() return secret end;assert(not C.Capture())
            GetSummonConfirmTimeLeft=nil
            C_IncomingSummon={HasIncomingSummon=function() return true end};assert(not C.Capture())
            C_IncomingSummon.HasIncomingSummon=function() error('restricted') end;assert(not C.Capture())
            C_IncomingSummon=nil
            local f=c.entranceObserver;f:SetEnabled(true)
            inside=true;mapID=201;px=.252;f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS')
            f.scripts.OnEvent(f,'INCOMING_SUMMON_CHANGED','party1');advance(.5)
            assert(A.Count(j.entrances.records)==1,'Another party member summon cannot consume player events')
        ''')

    def test_death_release_ghost_and_resurrection_prime_each_life(self):
        self.lua.execute('''
            local f=c.entranceObserver;f:SetEnabled(true)
            inside=true;mapID=201;f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS')
            dead=true;f.scripts.OnEvent(f,'PLAYER_DEAD');advance(1)
            ghost=true;UnitIsGhost=function() return ghost end;dead=false
            f.scripts.OnEvent(f,'PLAYER_ALIVE');inside=false;mapID=101;px=.255
            f.scripts.OnEvent(f,'PLAYER_STARTED_MOVING');f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS');advance(4)
            assert(not next(j.entrances.records),'Neither death nor spirit release records a doorway')
            inside=true;mapID=201;ghost=false;f.scripts.OnEvent(f,'PLAYER_UNGHOST');advance(.5)
            assert(not next(j.entrances.records),'Resurrection establishes a new baseline')
            inside=false;mapID=101;px=.256;f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS');advance(.5)
            local id=assert(next(j.entrances.records));assert(j.entrances:Get(id).entries==0 and j.entrances:Get(id).exits==1)
        ''')

    def test_legacy_death_signals_and_control_loss_are_discontinuities(self):
        self.lua.execute('''
            UnitIsDeadOrGhost=nil;UnitIsDead=function() return true end;assert(not C.Capture())
            UnitIsDead=function() return false end;UnitIsGhost=function() return true end;assert(not C.Capture())
            UnitIsGhost=function() return secret end;assert(not C.Capture())
            UnitIsGhost=function() return false end
            local f=c.entranceObserver;f:SetEnabled(true);f.scripts.OnEvent(f,'PLAYER_CONTROL_LOST')
            inside=true;mapID=201;f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS');advance(1)
            f.scripts.OnEvent(f,'PLAYER_CONTROL_GAINED');advance(.5)
            assert(not next(j.entrances.records))
        ''')

    def test_reload_preserves_inference_and_different_browsed_zone_is_not_storage_context(self):
        self.lua.execute('''
            c:SetZone(102,'Coast 102');enabled();microName='Deep Cave';local id=enter()
            local before=snapshot(saved);local reload=ns.CreateAtlasJournal(saved)
            assert(before==snapshot(saved) and reload.entrances:Get(id).classification.kind=='inferred')
            assert(reload.entrances:Get(id).exterior.mapID==101 and j.state.mapID==102)
            assert(j.entrances:Get(id).exterior.x==2500 and j.entrances:Get(id).interiorPosition.x==6000)
        ''')

    def test_whole_fieldbook_backup_retains_entrance_evidence_and_classification(self):
        from test_fieldbook_backups import client
        lua = client()
        lua.execute('''
            local j=ns.CreateAtlasJournal(AzerothFieldbookAtlasDB);j.state.autoEntrances=true
            local id=assert(j.entrances:Record({direction='entry',at=now,
                exterior={mapID=101,x=2500,y=2500},size={width=1000,height=2000},
                interior={zoneMapID=101,bestMapID=201,microMapID=201,microName='Cave',zone='Coast'},
                world={continentID=7,x=123.25,y=456.75,source='map-roundtrip'},
                interiorPosition={mapID=201,x=6000,y=4000}}))
            local view=ns.AtlasEntrances.View(j);local e=view:Get(ns.AtlasEntrances.PREFIX..id)
            e.notes='Private entrance notes';e.confirmCategory='camp';assert(view:Save(e,e.id))
            local text=assert(B.Capture());local decoded=assert(B.Decode(text))
            assert(B.CanRestore(decoded),'The extension must remain restorable by the established whole-save path')
            local restored=ns.CreateAtlasJournal(decoded.stores.AzerothFieldbookAtlasDB)
            local result=assert(restored.entrances:Get(id))
            assert(result.exterior.mapID==101 and result.interiorPosition.mapID==201 and result.world.x==123.25)
            assert(result.classification.kind=='player' and result.classification.category=='camp' and result.notes=='Private entrance notes')
            assert(result.total==1 and result.entries==1 and result.exits==0)
        ''')

    def test_new_entries_announce_once_with_atlas_closed_and_generic_layer_hidden(self):
        self.lua.execute('''
            local chat,log={},{}
            DEFAULT_CHAT_FRAME={AddMessage=function(_,message) chat[#chat+1]=message end}
            local events={RecordEvent=function(_,message,details) log[#log+1]={message=message,details=details} end}
            AzerothFieldbookAtlasDB=saved;shell=ns.CreateFieldbookShell()
            c=ns.InitializeAtlas(shell,events);j=c.journal
            assert(not c.main and not shell:GetFrame())
            local f=c.entranceObserver;f:SetEnabled(true)
            inside=true;mapID=201;px=.252;f.scripts.OnEvent(f,'ZONE_CHANGED_INDOORS');advance(.4)
            local id=assert(next(j.entrances.records))
            assert(not j.entrances:Layer('entrance') and not c.main and not shell:GetFrame())
            local expected='|cffffd100[Recorded]|r |cff80d0ffTraveller’s Atlas:|r |cffffffffQuiet Hollow entrance |cff80d0ff[A]|r|r |cff999999(Coast 101 • 25.0, 25.0)|r'
            assert(#chat==1 and chat[1]=='|cff80d0ffAFB:|r '..expected)
            assert(#log==1 and log[1].message==expected and log[1].details.kind=='atlas-recorded')
            assert(log[1].details.entranceID==id and log[1].details.mapID==101 and log[1].details.automatic)
            assert(j.entrances:Record(observe(2501,'exit'))==id and j.entrances:Get(id).total==2)
            local view=E.View(j);local entry=view:Get(E.PREFIX..id);entry.notes='Private notes';entry.confirmCategory='cave'
            assert(view:Save(entry,entry.id));ns.CreateAtlasJournal(saved)
            assert(#chat==1 and #log==1,'Repeat observations, editing and reload do not repeat new-entry notices')
            f:SetEnabled(false);assert(not j.entrances:Record(observe(8000)))
            f:SetEnabled(true);E.MAX_RECORDS=1;assert(not j.entrances:Record(observe(8000)))
            assert(#chat==1 and #log==1,'Disabled and failed recording stay silent')
            E.MAX_RECORDS=5000;DEFAULT_CHAT_FRAME=nil
            assert(j.entrances:Record(observe(8000)));assert(#log==2 and #chat==1)
        ''')

    def test_automatic_tags_survive_confirmation_without_changing_saved_names(self):
        self.lua.execute('''
            enabled();local id=j.entrances:Record(observe(2500,'entry',201,'Deep Cave'))
            local manual=assert(j:Save(fixture('Manual entrance')))
            local tag='|cff80d0ff[A]|r';local selected=E.PREFIX..id;c:Select(selected)
            local row
            for _,r in ipairs(m.rows) do
                if r.id==selected then row=r;assert(r.name:GetText():find(tag,1,true)) end
                if r.id==manual then assert(not r.name:GetText():find('[A]',1,true)) end
            end
            row.scripts.OnEnter(row);assert(GameTooltip:GetText():find(tag,1,true))
            local found=false
            for _,pin in ipairs(m.map.pins) do
                if pin:IsShown() then
                    for _,marker in ipairs(pin.group) do if marker.id==selected then
                        pin.scripts.OnEnter(pin)
                        for _,line in ipairs(GameTooltip.lines) do if line.text:find(tag,1,true) then found=true end end
                    end end
                end
            end
            assert(found,'Map tooltip identifies the automatic entrance')
            c:OpenEditor(selected);assert(c.editor.source:GetText():find(tag,1,true))
            c.editor.name:SetText('Renamed entrance');assert(c.editor:Save())
            click(c.editor.category);click(c.editor.categoryMenu.rows[1]);assert(c.editor:Save());c:Refresh()
            assert(j.entrances:Get(id).classification.kind=='player')
            assert(c.editor.source:GetText():find(tag,1,true),'Gold type confirmation does not erase automatic origin')
            local reloaded=ns.CreateAtlasJournal(saved);local projected=E.View(reloaded):Get(selected)
            assert(projected.name=='Renamed entrance' and projected.entrance==id)
            assert(A.AutomaticLabel(projected.name,projected.entrance)=='Renamed entrance '..tag)
            assert(not snapshot(saved):find(tag,1,true),'The badge is display-only, never saved in names or notes')
        ''')

    def test_stationary_environment_changes_and_disabled_events_do_not_poll_or_record(self):
        self.lua.execute('''
            enabled();feed(true,.25,.1);feed(true,.25,.4)
            assert(not next(j.entrances.records),'Stationary flag changes alone do not establish a physical crossing')
            local f=c.entranceObserver;f:SetEnabled(false);timers={};reads={}
            for _,event in ipairs({'UNIT_SPELLCAST_SENT','UNIT_SPELLCAST_START','UNIT_SPELLCAST_STOP',
                'CONFIRM_SUMMON','CANCEL_SUMMON','PLAYER_ENTERING_WORLD','ZONE_CHANGED_INDOORS','PLAYER_STARTED_MOVING'}) do
                f.scripts.OnEvent(f,event,'player')
            end
            assert(#timers==0 and #reads==0 and f.scripts.OnUpdate==nil)
        ''')


if __name__ == '__main__':
    unittest.main()
