"""Automatic live-test observations: <=40-yard proximity and a fixed 42-yard circle."""
import unittest
from test_observation_tracking import observation_client


def prototype_client():
    lua = observation_client()
    lua.execute(r'''
        item40Range=true;itemRange=false;interactRange=false
        mapCalls=0;loadRequests=0;borderX=.8
        C_Item={
            IsItemInRange=function(id,unit)
                if id==4945 then return item40Range end
                assert(id==18904);return itemRange
            end,
            RequestLoadItemDataByID=function(id)
                assert(id==4945 or id==18904);loadRequests=loadRequests+1
            end,
        }
        function CheckInteractDistance(unit,index) assert(index==4);return interactRange end
        C_Map.GetMapInfo=function(id)
            if id==13 then return {mapID=id,name='Continent',mapType=2,parentMapID=0} end
            if id==3737 then return {mapID=id,name='Small area',mapType=5,parentMapID=37} end
            if id==37 or id==38 then
                return {mapID=id,name=id==37 and 'Test zone' or 'Adjacent zone',mapType=3,parentMapID=13}
            end
        end
        C_Map.GetMapWorldSize=function(id)
            if id==13 then return 40000,30000 end
            return 4000,3000
        end
        C_Map.GetPlayerMapPosition=function(id,unit)
            assert(unit=='player')
            if id==13 then return {x=.1+px*.1,y=.1+py*.1} end
            return {x=px,y=py}
        end
        C_Map.GetMapInfoAtPosition=function(id,x,y)
            mapCalls=mapCalls+1
            if id==13 then x=(x-.1)/.1;y=(y-.1)/.1 end
            return C_Map.GetMapInfo(x>=borderX and 38 or 37)
        end
        units.target=mob(5)
        L=ns.CreatureLocations
        function captureTick() clock=clock+1;tick() end
        function check(force) return L.CheckObservation('target',units.target.guid,force) end
        function entry() return journal.entries[42] end
        function report()
            local lines={};L.ReportPrototype(function(s) lines[#lines+1]=s end,journal)
            return table.concat(lines,'\n')
        end
    ''')
    return lua


class LocationPrototypeTests(unittest.TestCase):
    def test_stationary_capture_does_no_repeat_range_border_writes_or_sorting(self):
        lua=prototype_client()
        lua.execute('''
            local ranges,writes,trims=0,0,0
            local range,record,trim=C_Item.IsItemInRange,L.Record,L.TrimPoints
            C_Item.IsItemInRange=function(...) ranges=ranges+1;return range(...) end
            L.Record=function(...) writes=writes+1;return record(...) end
            L.TrimPoints=function(...) trims=trims+1;return trim(...) end
            units.mouseover=units.target;fire('PLAYER_TARGET_CHANGED')
            local initialRanges=ranges;assert(mapCalls==25 and writes==1 and trims==0)
            for i=1,100 do stamp=stamp+1;tick();fire('UPDATE_MOUSEOVER_UNIT') end
            assert(mapCalls==25 and ranges==initialRanges and writes==1 and trims==0)
            assert(observations().points[1+2000*10001+3000].seenAt==1790300000)
        ''')

    def test_movement_needs_ten_yards_and_one_second_and_rechecks_current_border(self):
        lua=prototype_client()
        lua.execute('''
            fire('PLAYER_TARGET_CHANGED');assert(mapCalls==25)
            px=px+9/4000;captureTick();assert(mapCalls==25)
            px=px+3/4000;captureTick();assert(mapCalls==50)
            local count=0;for _ in pairs(observations().points) do count=count+1 end
            assert(count==2)
            px=px+20/4000;fire('PLAYER_TARGET_CHANGED');tick()
            assert(mapCalls==50,'events cannot bypass the one-second limit')
            borderX=px+41/4000;captureTick()
            assert(mapCalls==75,'movement uses a fresh guard at the current position')
            count=0;for _ in pairs(observations().points) do count=count+1 end
            assert(count==2,'a formerly safe location cannot allow a new border point')
            borderX=.8;captureTick()
            count=0;for _ in pairs(observations().points) do count=count+1 end
            assert(count==3,'rejected positions remain eligible for a later retry')
        ''')

    def test_existing_point_and_zone_remain_silent(self):
        lua=prototype_client()
        lua.execute('''
            L.SetPrototypeEnabled(false);fire('PLAYER_TARGET_CHANGED')
            entry().locations['Test zone']=true
            AzerothFieldbookDB.bestiary.points.credits[42].zones['Test zone']=true
            L.Record(entry(),{mapID=37,name='Test zone',
                point={x=2000,y=3000,seenAt=stamp-100,approximate=false}},'observations')
            journal:SetCreatureAnnouncement(true);messages={};L.SetPrototypeEnabled(true)
            captureTick()
            assert(#messages==0,'saved locations stay silent')
            assert(not journal.prototypeLocationStats,'existing point is not refreshed to force feedback')
            for i=1,10 do tick() end
            assert(#messages==0 and mapCalls==25)
        ''')

    def test_click_adds_entry_then_first_qualified_location_announces_once(self):
        lua=prototype_client()
        lua.execute('''
            journal:SetCreatureAnnouncement(true)
            item40Range=false;fire('PLAYER_TARGET_CHANGED')
            assert(entry() and entry().personalEncountered and not next(entry().locations))
            assert(not observations() and #messages==1)
            messages={};item40Range=true;borderX=px+41/4000;captureTick()
            assert(not next(entry().locations) and #messages==0)
            borderX=.8;clock=clock+1;captureTick()
            assert(entry().locations['Test zone'] and observations() and #messages==1)
            assert(messages[1]:find('[New Location Observed]',1,true))
            assert(messages[1]:find('Test zone',1,true) and points()==0)
            stamp=stamp+1;px=.25;captureTick();captureTick()
            assert(#messages==1,'additional points and refreshes in this zone stay silent')
            fire('ADDON_LOADED','AzerothFieldbook');captureTick();assert(#messages==1)
            mapID=38
            C_Map.GetMapInfoAtPosition=function() return C_Map.GetMapInfo(38) end
            captureTick()
            assert(entry().locations['Adjacent zone'] and observations(38) and #messages==2)
            assert(messages[2]:find('[New Location Observed]',1,true))
        ''')

    def test_new_point_in_saved_zone_stays_silent(self):
        lua=prototype_client()
        lua.execute('''
            L.SetPrototypeEnabled(false);fire('PLAYER_TARGET_CHANGED')
            entry().locations['Test zone']=true
            AzerothFieldbookDB.bestiary.points.credits[42].zones['Test zone']=true
            L.Record(entry(),{mapID=37,name='Test zone',
                point={x=1000,y=1000,seenAt=stamp,approximate=false}},'observations')
            journal:SetCreatureAnnouncement(true);messages={};L.SetPrototypeEnabled(true)
            captureTick();assert(#messages==0,'saved locations stay silent')
            assert(observations().points[1+2000*10001+3000] and points()==0)
            stamp=stamp+1;captureTick();captureTick();fire('PLAYER_TARGET_CHANGED')
            assert(#messages==0,'timestamp refreshes and retargeting do not announce')
            for i=1,10 do px=.2+i*.003;stamp=stamp+1;captureTick() end
            assert(#messages==0,'movement must not spam notices')
            local count=0;for _ in pairs(observations().points) do count=count+1 end
            assert(count==12,'all new points still record despite silent notices')
            units.target.guid='Creature-0-1-2-3-43-other';fire('PLAYER_TARGET_CHANGED')
            assert(#messages==1,'another creature combines its entry and location notice')
            assert(messages[1]:find('Test zone',1,true))
        ''')

    def test_first_qualified_location_announces_even_with_unknown_level(self):
        for level in ('5','-1'):
            with self.subTest(level=level):
                lua=prototype_client();lua.execute('units.target.effective='+level)
                lua.execute('''
                    journal:SetCreatureAnnouncement(true);fire('PLAYER_TARGET_CHANGED');captureTick()
                    local notices=0
                    for _,message in ipairs(messages) do
                        if message:find('[New Location Observed]',1,true) then notices=notices+1 end
                    end
                    assert(notices==0 and #messages==1 and messages[1]:find('Test zone',1,true))
                    assert(entry().locations['Test zone'] and observations() and points()==0)
                ''')

    def test_location_notice_respects_chat_preference_and_is_logged_without_replay(self):
        lua=prototype_client()
        lua.execute('''
            item40Range=false;fire('PLAYER_TARGET_CHANGED');journal:SetEntryConfirmed(42,true)
            entry().lockedBasic={locations={}}
            messages={};journal:SetCreatureAnnouncement(false);item40Range=true;captureTick()
            assert(entry().lockedBasic.locations['Test zone'] and #messages==0)
            local log=journal:GetEventLog().entries
            assert(log[#log].details.title=='New Location Observed' and log[#log].details.location=='Test zone')
            journal:SetCreatureAnnouncement(true);captureTick();assert(#messages==0)
        ''')

    def test_terminal_events_cannot_bypass_guard_or_add_a_location_when_range_turns_positive(self):
        lua=prototype_client()
        lua.execute('''
            item40Range=false;fire('PLAYER_TARGET_CHANGED')
            assert(entry() and not next(entry().locations))
            item40Range=true;units.target.combat=true;units.target.dead=true
            ns.CreatureLocations.Sample=function() error('no kill location sampling') end
            local guid=units.target.guid;fire('PARTY_KILL',UnitGUID('player'),guid)
            fire('UNIT_DIED',guid);captureTick();fire('PLAYER_TARGET_CHANGED')
            assert(entry().kills==1 and points()==1)
            assert(not next(entry().locations) and not observations() and not entry().killLocations)
        ''')

    def test_enabled_by_default_real_target_and_mouseover_events_record_without_commands(self):
        lua=prototype_client()
        lua.execute('''
            assert(L.prototypeEnabled)
            fire('PLAYER_TARGET_CHANGED')
            assert(entry().locations['Test zone'] and observations().points[1+2000*10001+3000])
            assert(not observations().points[1+2000*10001+3000].approximate)
            assert(not entry().killLocations and entry().kills==0 and points()==0)
            units.mouseover=units.target;units.target=nil;px=.25
            fire('UPDATE_MOUSEOVER_UNIT');captureTick()
            assert(observations().points[1+2500*10001+3000])
            assert(not next(entry().subzones or {}),'guard does not prove the creature subzone')
            publicTree(AzerothFieldbookDB)
        ''')

    def test_40_yard_check_covers_the_35_to_40_band_and_no_range_rejects_before_map_queries(self):
        lua=prototype_client()
        lua.execute('''
            assert(item40Range and not itemRange and not interactRange)
            assert(check().allowed and check().range.yards==40 and loadRequests==2)
            item40Range=false
            mapCalls=0;fire('PLAYER_TARGET_CHANGED')
            assert(not observations() and not next(entry().locations))
            assert(mapCalls==0,'no map queries when proximity is not established')
            assert(check().reason=='no positive proximity check' and loadRequests==2)
            item40Range=true;fire('PLAYER_TARGET_CHANGED');captureTick();assert(observations())
        ''')

    def test_shorter_positive_fallbacks_keep_the_full_42_yard_guard(self):
        lua=prototype_client()
        lua.execute('''
            borderX=px+41/4000
            for _,mode in ipairs({'40','35','28'}) do
                item40Range=mode=='40';itemRange=mode=='35';interactRange=mode=='28'
                local r=check(true)
                assert(not r.allowed and r.border.guardYards==42)
                assert(r.reason=='another zone within border guard')
            end
            borderX=.8;item40Range=secret;itemRange=true;interactRange=false
            assert(check(true).allowed,'a known shorter positive check proves <=40 yards')
            itemRange=nil;assert(not check().allowed)
            interactRange=true;assert(check().allowed and check().range.yards==28)
        ''')

    def test_circle_samples_include_centre_inner_rings_and_diagonals_without_exceeding_42(self):
        lua=prototype_client()
        lua.execute('''
            local r=check(true);assert(r.allowed and #r.border.rows==25 and mapCalls==25)
            local rings={[0]=0,[14]=0,[28]=0,[42]=0}
            for _,row in ipairs(r.border.rows) do
                local distance=math.sqrt(row.dx*row.dx+row.dy*row.dy)
                assert(distance<=42+.000001,'no square corners beyond the requested radius')
                local radius=math.floor(distance+.5);assert(rings[radius])
                rings[radius]=rings[radius]+1
            end
            assert(rings[0]==1 and rings[14]==8 and rings[28]==8 and rings[42]==8)
            C_Map.GetMapInfoAtPosition=function(id,x,y)
                return C_Map.GetMapInfo(x>px+31/4000 and y>py+31/3000 and 38 or 37)
            end
            assert(check(true).allowed,'diagonal region outside 42 yards must not reject')
            C_Map.GetMapInfoAtPosition=function(id,x,y)
                return C_Map.GetMapInfo(x>px+29/4000 and y>py+29/3000 and 38 or 37)
            end
            assert(not check(true).allowed,'diagonal region within the guard must reject')
        ''')

    def test_every_sample_must_agree_intermediate_border_and_nil_are_not_inferred(self):
        for foreign in (True, False):
            with self.subTest(foreign=foreign):
                lua=prototype_client()
                value='C_Map.GetMapInfo(38)' if foreign else 'nil'
                lua.execute('''
                    C_Map.GetMapInfoAtPosition=function(id,x,y)
                        mapCalls=mapCalls+1
                        if math.abs(x-px-14/4000)<.000001 and math.abs(y-py)<.000001 then
                            return '''+value+'''
                        end
                        return C_Map.GetMapInfo(37)
                    end
                    local r=check(true)
                    assert(not r.allowed and mapCalls==25,'no retries or additional probes')
                    fire('PLAYER_TARGET_CHANGED');assert(not observations())
                ''')

    def test_north_gap_still_rejects_even_when_surrounding_points_would_agree(self):
        lua=prototype_client()
        lua.execute('''
            C_Map.GetMapInfoAtPosition=function(id,x,y)
                mapCalls=mapCalls+1
                local north=(py-y)*3000
                if north>41 and north<43 then return nil end
                return C_Map.GetMapInfo(37)
            end
            local r=check(true)
            assert(not r.allowed and r.border.counts.unknown==1 and mapCalls==25)
            fire('PLAYER_TARGET_CHANGED');assert(not observations())
            assert(report():find('position lookup returned nil',1,true))
        ''')

    def test_missing_secret_error_and_malformed_lookups_cannot_write_or_expose_payloads(self):
        for body in ('return nil', 'return secret', "error('private payload')",
                     'return {mapID=secret}', 'return {mapID=999}', 'return C_Map.GetMapInfo(13)'):
            with self.subTest(body=body):
                lua=prototype_client()
                lua.execute('C_Map.GetMapInfoAtPosition=function(id,x,y) '+body+' end')
                lua.execute('''
                    fire('PLAYER_TARGET_CHANGED')
                    assert(not observations() and not next(entry().locations))
                    assert(not check(true).allowed and not report():find('private payload',1,true))
                    publicTree(AzerothFieldbookDB)
                ''')

    def test_secret_error_and_unknown_range_results_never_establish_proximity(self):
        lua=prototype_client()
        lua.execute('''
            item40Range=secret;itemRange=nil;interactRange=secret
            assert(not check().allowed)
            C_Item.IsItemInRange=function() error('private range payload') end
            CheckInteractDistance=nil
            assert(not check().allowed and loadRequests==2)
            local text=report()
            assert(text:find('API error',1,true) and not text:find('private range payload',1,true))
        ''')

    def test_centre_mismatch_off_map_dimensions_positions_and_instances_reject(self):
        for setup in ("C_Map.GetMapInfoAtPosition=function() return C_Map.GetMapInfo(38) end",
                      "px=.005", "C_Map.GetMapWorldSize=nil",
                      "C_Map.GetMapWorldSize=function() return secret,3000 end",
                      "px=secret", "px=0;py=0", "function IsInInstance() return true end",
                      "C_Map.GetMapInfo=function(id) return {mapID=id,name='Dungeon',mapType=4} end"):
            with self.subTest(setup=setup):
                lua=prototype_client();lua.execute(setup)
                lua.execute('assert(not check(true).allowed)')

    def test_near_border_rejects_and_moving_inland_does_not_reuse_cache(self):
        lua=prototype_client()
        lua.execute('''
            borderX=px+41/4000
            assert(not check().allowed)
            fire('PLAYER_TARGET_CHANGED');assert(not observations())
            px=px-.02;fire('PLAYER_TARGET_CHANGED');captureTick()
            assert(observations() and entry().locations['Test zone'])
        ''')

    def test_child_maps_normalize_and_continent_uses_its_own_yard_scale(self):
        lua=prototype_client()
        lua.execute('''
            mapID=3737;mapName='Small area'
            local r=check(true);assert(r.allowed and r.border.zone.mapID==37 and r.border.query.mapID==37)
            L.SetPrototypeLookup('continent')
            r=check(true);assert(r.allowed and r.border.query.mapID==13)
            borderX=px+41/4000
            assert(not check(true).allowed)
            L.SetPrototypeLookup('zone');assert(not check(true).allowed)
        ''')

    def test_stationary_cache_expires_and_report_forces_fresh_25_checks(self):
        lua=prototype_client()
        lua.execute('''
            assert(check().allowed and mapCalls==25)
            assert(check().allowed and mapCalls==25)
            borderX=px+.005
            assert(check().allowed and mapCalls==25)
            assert(not check(true).allowed and mapCalls==50)
            borderX=.8;clock=1
            assert(check().allowed and mapCalls==75)
            report();assert(mapCalls==100,'report only samples the fixed guard')
        ''')

    def test_dead_secret_or_swapped_creature_identity_cannot_supply_observation(self):
        lua=prototype_client()
        lua.execute('''
            units.target.dead=true;assert(not check(true).allowed)
            units.target.dead=false
            local original=C_Item.IsItemInRange
            C_Item.IsItemInRange=function(...)
                units.target=mob(5);units.target.guid='Creature-0-1-2-3-42-swapped'
                return original(...)
            end
            assert(not check(true).allowed)
            assert(not L.CheckObservation(secret,'Creature-0-1-2-3-42-test',true).allowed)
        ''')

    def test_locked_entry_location_snapshot_updates_without_changing_other_facts(self):
        lua=prototype_client()
        lua.execute('''
            L.SetPrototypeEnabled(false);fire('PLAYER_TARGET_CHANGED');journal:SetEntryConfirmed(42,true)
            entry().lockedBasic={levelMin=5,locations={}}
            L.SetPrototypeEnabled(true);fire('PLAYER_TARGET_CHANGED')
            assert(entry().confirmed and entry().lockedBasic.locations['Test zone'])
            assert(observations() and entry().levelMin==5 and entry().kills==0)
        ''')

    def test_optional_report_is_read_only_and_pause_resume_commands_retain_points(self):
        lua=prototype_client()
        lua.execute('''
            ns.ShowDebugReport=function(s) copiedReport=s end
            SlashCmdList.AZEROTHFIELDBOOK('debug locations')
            assert(copiedReport:find('recording on (default)',1,true) and not entry())
            fire('PLAYER_TARGET_CHANGED');assert(observations())
            SlashCmdList.AZEROTHFIELDBOOK('debug locations off');px=.3;fire('PLAYER_TARGET_CHANGED')
            assert(not observations().points[1+3000*10001+3000])
            SlashCmdList.AZEROTHFIELDBOOK('debug locations on');fire('PLAYER_TARGET_CHANGED');captureTick()
            assert(observations().points[1+3000*10001+3000])
            SlashCmdList.AZEROTHFIELDBOOK('debug locations continent');assert(L.prototypeLookup=='continent')
            SlashCmdList.AZEROTHFIELDBOOK('debug locations zone');assert(L.prototypeLookup=='zone')
        ''')

    def test_player_only_report_needs_no_creature_and_does_not_record(self):
        lua=prototype_client()
        lua.execute('''
            units.target=nil;units.mouseover=nil
            local text=report()
            assert(text:find('Player-only border check: PASS:',1,true))
            assert(text:find('Guard: 42-yard radius',1,true) and mapCalls==25)
            assert(not entry() and L.prototypeEnabled)
        ''')

    def test_kill_credit_continues_without_locations_when_proximity_or_border_fails(self):
        for setup in ('item40Range=false;itemRange=false;interactRange=false', 'borderX=px+41/4000'):
            with self.subTest(setup=setup):
                lua=prototype_client();lua.execute(setup)
                lua.execute('''
                    fire('PLAYER_TARGET_CHANGED');assert(not observations())
                    units.target.combat=true
                    local guid=units.target.guid;fire('PARTY_KILL',UnitGUID('player'),guid)
                    units.target.dead=true;fire('UNIT_DIED',guid);captureTick()
                    assert(entry().kills==1 and points()==1 and not entry().killLocations)
                    assert(not next(entry().locations) and not next(entry().subzones or {}))
                    assert(not observations())
                ''')

    def test_existing_entry_added_points_have_counters_without_stationary_refreshes(self):
        lua=prototype_client()
        lua.execute('''
            L.SetPrototypeEnabled(false);fire('PLAYER_TARGET_CHANGED');entry().locations['Test zone']=true
            L.Record(entry(),{mapID=37,name='Test zone',point={x=1000,y=1000,seenAt=stamp,approximate=false}},'observations')
            L.SetPrototypeEnabled(true);fire('PLAYER_TARGET_CHANGED');captureTick();captureTick()
            assert(journal.prototypeLocationStats.added==1 and journal.prototypeLocationStats.refreshed==0)
            local text=report()
            assert(text:find('1 points added; 0 points refreshed',1,true))
            assert(text:find('Saved observer points for this creature on player map: 2',1,true))
            stamp=stamp+1;captureTick();captureTick()
            assert(journal.prototypeLocationStats.added==1 and journal.prototypeLocationStats.refreshed==0)
            assert(not AzerothFieldbookDB.prototypeLocationStats and not entry().prototypeLocationStats)
        ''')

    def test_full_map_capacity_does_not_report_unsaved_point_as_written(self):
        lua=prototype_client()
        lua.execute('''
            L.SetPrototypeEnabled(false);fire('PLAYER_TARGET_CHANGED')
            for i=1,64 do
                L.Record(entry(),{mapID=1000+i,name='Other map',point={x=1,y=1,seenAt=stamp,approximate=false}},'observations')
            end
            L.SetPrototypeEnabled(true);fire('PLAYER_TARGET_CHANGED')
            assert(not observations() and not journal.prototypeLocationStats)
            assert(report():find('0 points added; 0 points refreshed',1,true))
        ''')


if __name__ == '__main__':
    unittest.main()
