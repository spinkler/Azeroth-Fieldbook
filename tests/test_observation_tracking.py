"""Explicit airborne observations, independent map layers and their persistence."""
import unittest
from kill_test_harness import ROOT
from test_discovery_rules import client
from test_locations import MAP_API
import test_locations as locations


def observation_client():
    lua = client()
    lua.execute((ROOT/'CreatureLocations.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute(MAP_API)
    lua.execute('''
        function GetRealZoneText() return mapName end
        function observations(id)
            local e=journal.entries[42]
            return e and e.observationLocations and e.observationLocations[id or 37]
        end
    ''')
    return lua


class ObservationTrackingTests(unittest.TestCase):
    def test_airborne_target_records_skull_entry_log_and_player_position(self):
        lua = observation_client()
        lua.execute('''
            taxi=true;units.target=mob(-1)
            function UnitIsVisible() return false end -- Selected beyond render range in flight.
            fire('PLAYER_TARGET_CHANGED')
            assert(journal.entries[42] and journal:IsSkull(42) and points()==0)
            local log=journal:GetEventLog().entries
            assert(#log==1 and log[1].details.title=='Entry observed')
            local p=observations().points[1+2000*10001+3000]
            assert(p and not p.approximate and p.x~=nx*10000,'use the player, not NPC coordinates')
            px=0.8;py=0.9;tick();tick()
            assert(count(observations().points)==1,'polling never draws a flight path')
            fire('ADDON_LOADED','AzerothFieldbook');tick()
            assert(#journal:GetEventLog().entries==1 and count(observations().points)==1)
            fire('PLAYER_TARGET_CHANGED')
            assert(count(observations().points)==2 and #log==1,'retargeting adds a point, not another discovery')
            assert(not next(journal.entries[42].killLocations[37].points))
        ''')

    def test_explicit_mouseover_in_flight_bypasses_only_passive_filters(self):
        lua = observation_client()
        lua.execute('''
            flying=true;units.mouseover=mob(5)
            fire('UPDATE_MOUSEOVER_UNIT');tick();assert(not journal.entries[42])
            assert(journal:Observe('mouseover',true)==42)
            assert(points()==0 and not observations(),'opening a mouseover entry does not record a map point')
            assert(#journal:GetEventLog().entries==1)
            journal:Observe('mouseover',true);assert(not observations())
            units.mouseover.controlled=true;px=0.9
            assert(not journal:Observe('mouseover',true) and not observations())
            units.mouseover.controlled=false;units.mouseover.attackable=false
            assert(not journal:Observe('mouseover',true))
            assert(not journal:Observe('focus',true))
        ''')

    def test_first_personal_skull_encounter_of_named_shared_entry_is_logged(self):
        for locked in (False, True):
            with self.subTest(locked=locked):
                lua = observation_client()
                lua.execute('''
                    local e=journal:Ensure(42,true,'Test creature')
                    units.target=mob(-1);taxi=true
                ''')
                lua.execute(f'journal.entries[42].confirmed={str(locked).lower()}')
                lua.execute('''
                    fire('PLAYER_TARGET_CHANGED')
                    assert(journal.entries[42].personalEncountered and points()==0)
                    assert(#journal:GetEventLog().entries==1)
                    assert(journal:GetEventLog().entries[1].details.title=='Entry observed')
                    fire('PLAYER_TARGET_CHANGED');tick()
                    assert(#journal:GetEventLog().entries==1)
                ''')

    def test_passive_ground_observations_and_missing_coordinates_do_not_make_points(self):
        lua = observation_client()
        lua.execute('''
            units.mouseover=mob(5);fire('UPDATE_MOUSEOVER_UNIT');tick()
            assert(journal.entries[42] and not observations())
            units.target=units.mouseover
            for _,bad in ipairs({secret,-0.1,1.1,0/0}) do
                px=bad;fire('PLAYER_TARGET_CHANGED');assert(not observations())
            end
            C_Map.GetPlayerMapPosition=function() error('unavailable') end
            fire('PLAYER_TARGET_CHANGED');assert(not observations())
            assert(points()==0 and #journal:GetEventLog().entries==1)
            publicTree(AzerothFieldbookDB)
        ''')

    def test_locked_entry_new_zone_and_changed_guid_during_capture(self):
        lua = observation_client()
        lua.execute('''
            units.target=mob(5);fire('PLAYER_TARGET_CHANGED')
            journal:SetEntryConfirmed(42,true)
            mapID=52;mapName='Other zone';px=0.5
            fire('PLAYER_TARGET_CHANGED');assert(observations(52).points[1+5000*10001+3000])
            assert(#ns.CreatureLocations.Zones(journal.entries[42],'observations')==2)
            C_Map.GetPlayerMapPosition=function()
                units.target.guid='Creature-0-1-2-3-99-other';return {x=0.9,y=0.9}
            end
            journal:Observe('target',true)
            assert(count(observations(52).points)==1,'identity changed during sampling')
        ''')

    def test_layers_back_up_merge_and_remain_private_with_separate_limits(self):
        from ui_test_harness import new_ui_client
        lua = new_ui_client(['CreatureLocations.lua','SharingReport.lua','BestiaryBackups.lua','BestiaryJournal.lua','Tracking.lua'])
        lua.execute('''
            local db={accountWideTracking=false};local j=ns.CreateBestiaryJournal(db,function() return 42 end)
            local e=j:Ensure(42,false,'Creature');local L=ns.CreatureLocations
            for i=1,300 do L.Record(e,{mapID=37,name='Elwynn',point={x=i,y=i,seenAt=i,approximate=false}},'observations') end
            local n=0;for _ in pairs(e.observationLocations[37].points) do n=n+1 end;eq(n,256)
            assert(not e.killLocations)
            local backup=assert(j:CreateBackup())
            local decoded=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(backup))))
            local key=1+300*10001+300
            eq(decoded.bestiary.entries[42].observationLocations[37].points[key].x,300)
            assert(j:RestoreBackup(decoded))
            local report=ns.SharingReport.Capture(j,42)
            assert(not report.observationLocations and not report.killLocations)
            decoded.bestiary.entries[42].observationLocations[37].points[key].x=301
            assert(not ns.BestiaryBackups.Validate(decoded,true),'mismatched coordinate key rejected')
            db.accountWideTracking=true;local account=ns.InitializeTracking(db)
            local other={accountWideTracking=false};local j2=ns.CreateBestiaryJournal(other,function() return 42 end)
            local e2=j2:Ensure(42,false,'Creature')
            L.Record(e2,{mapID=37,name='Elwynn',point={x=9000,y=9000,seenAt=now,approximate=false}},'observations')
            L.Record(e2,{mapID=37,name='Elwynn',point={x=1000,y=2000,seenAt=now,approximate=true}})
            other.accountWideTracking=true;ns.InitializeTracking(other)
            local merged=account.bestiary.entries[42]
            assert(merged.observationLocations[37].points[key] and merged.observationLocations[37].points[1+9000*10001+9000])
            assert(merged.killLocations[37].points[1+1000*10001+2000])
            assert(not db.bestiary.entries[42].killLocations,'character source preserved')
            j:DeleteEntry(42);assert(not j.entries[42])
        ''')

    def test_layer_switching_keeps_distinct_same_named_maps_accessible(self):
        from ui_test_harness import new_ui_client
        lua = new_ui_client(['CreatureLocations.lua'])
        lua.execute('''
            local e={};local L=ns.CreatureLocations
            L.RememberMap(e,{mapID=1,name='Cave'})
            L.RememberMap(e,{mapID=2,name='Cave'},'observations')
            for _,mode in ipairs({'kills','observations'}) do
                local zones=L.Zones(e,mode)
                eq(#zones,2);eq(zones[1].mapID,1);eq(zones[2].mapID,2)
                assert(zones[mode=='kills' and 1 or 2].data)
                assert(not zones[mode=='kills' and 2 or 1].data)
            end
        ''')

    def test_window_switches_layers_colours_tooltips_and_saved_mode(self):
        lua = locations.LocationsWindowTests().client()
        lua.execute('''
            local L=ns.CreatureLocations
            for _,p in ipairs({{2000,2000},{2100,2000},{2000,2100},{9000,9000}}) do
                L.Record(e,{mapID=37,name='Test zone',width=4000,height=3000,
                    point={x=p[1],y=p[2],seenAt=now,approximate=false}},'observations')
            end
            window:Open(42);local f=window:GetFrame();local toggle=f.trackingMode
            eq(toggle.text,'Tracking: Kills')
            assert(toggle.point[2]>f.brightnessValue.point[2]+f.brightnessValue:GetWidth())
            assert(toggle.point[2]+toggle:GetWidth()<=f:GetWidth()-18)
            GameTooltip={SetOwner=function() end,SetText=function(_,t) tooltipTitle=t end,
                AddLine=function(_,t) tooltipLine=t end,Show=function() end,Hide=function() end}
            toggle.scripts.OnEnter(toggle);eq(tooltipTitle,'Location tracking')
            assert(tooltipLine:find('Both are recorded',1,true))
            toggle.scripts.OnClick()
            eq(toggle.text,'Tracking: Observations');eq(j:GetLocationTrackingMode(),'observations')
            assert(f.status.text:find('4 observation positions',1,true))
            assert(f.legend.text:find('Cyan:',1,true))
            local triangles,edges,dots=0,0,0
            for _,o in ipairs(objects) do
                if o.parent==f.map and o:IsShown() then
                    if o.vertices and o.rgba[4]==0.46 then
                        triangles=triangles+1;eq(o.rgba[1],0.05);eq(o.rgba[3],1)
                    elseif o.vertices then edges=edges+1;eq(o.rgba[2],1);eq(o.rgba[3],1)
                    elseif o.location then
                        dots=dots+1;o.scripts.OnEnter(o);eq(tooltipTitle,'Observation location')
                        assert(tooltipLine:find('targeted this creature',1,true))
                        eq(o.border.rgba[3],1)
                    end
                end
            end
            eq(triangles,1);eq(edges,9);eq(dots,1)
            f.brightness.scripts.OnValueChanged(f.brightness,0.2)
            window:Hide();window:Open(42);eq(toggle.text,'Tracking: Observations')
            local reloaded=ns.CreateBestiaryJournal(db,function() end)
            eq(reloaded:GetLocationTrackingMode(),'observations')
            toggle.scripts.OnClick();eq(toggle.text,'Tracking: Kills')
            assert(f.status.text:find('1 approximate',1,true))
            for _,o in ipairs(objects) do if o.parent==f.map and o.location and o:IsShown() then
                eq(o.border.rgba[1],1);eq(o.border.rgba[2],0.55)
                o.scripts.OnEnter(o);eq(tooltipTitle,'Approximate kill location')
            end end
            e.observationLocations=nil;j:Touch();toggle.scripts.OnClick()
            assert(f.status.text:find('No mapped observations.',1,true))
        ''')

    def test_book_mouseover_action_adds_entry_without_an_observation_map_point(self):
        lua = locations.LocationsWindowTests().client(book=True)
        lua.execute('''
            local observedUnit,explicit
            j=ns.CreateBestiaryJournal({},function(unit,requested)
                observedUnit,explicit=unit,explicit or requested;return 42
            end)
            local book=ns.CreateBestiaryBook(j)
            book:OpenAtUnit('mouseover')
            assert(AzerothFieldbookBestiarySection:IsShown())
            eq(observedUnit,'mouseover');assert(explicit)
            assert(j.entries[42] and not j.entries[42].observationLocations)
        ''')


if __name__ == '__main__':
    unittest.main()
