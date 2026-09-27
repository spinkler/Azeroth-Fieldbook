"""Minimap territory colours use observed, faction-specific zone data."""
import unittest
from ui_test_harness import new_ui_client
from test_discovery_rules import client as event_client


def client():
    lua=new_ui_client(['SharingReport.lua','BestiaryBackups.lua','BestiaryJournal.lua','Tracking.lua',
        'Scrollbars.lua','ActionButtons.lua','WindowFocus.lua','WindowPositions.lua','UIScale.lua',
        'FieldbookShell.lua','BestiaryPages.lua','BestiaryBook.lua'])
    lua.execute('''
        zone='Friendly zone';faction='Alliance';territory='friendly';subzone=false
        function GetRealZoneText() return zone end
        function UnitFactionGroup() return faction end
        C_PvP={GetZonePVPInfo=function() return territory,subzone end}
        NORMAL_FONT_COLOR={r=1,g=0.82,b=0}
        settings={accountWideTracking=false}
        j=ns.CreateBestiaryJournal(settings,function() return 42 end)
        book=ns.CreateBestiaryBook(j);book:OpenAtUnit('target');e=j.entries[42]
        section=AzerothFieldbookBestiarySection
        function summary()
            local text='';for _,row in ipairs(section.summaryBasicRows) do
                if row:IsShown() then text=text..row.text end
            end;return text
        end
    ''')
    return lua


class ZoneColourTests(unittest.TestCase):
    def test_minimap_palette_historical_zones_and_locked_quiet_updates(self):
        lua=client()
        lua.execute('''
            for _,case in ipairs({{'Friendly zone','friendly','1aff1a'},
                {'Enemy zone','hostile','ff1a1a'},{'Contested zone','contested','ffb300'},
                {'Sanctuary','sanctuary','69ccf0'},{'Arena','arena','ff1a1a'},
                {'Other zone','combat','ffd100'}}) do
                zone,territory=case[1],case[2];j:Observe('target');book:Refresh()
                assert(summary():find('|cff'..case[3]..zone..'|r',1,true))
            end
            assert(summary():find('|cff1aff1aFriendly zone|r',1,true),'old location retains observed colour')
            j:SetEntryConfirmed(42,true)
            local events=#j:GetEventLog().entries;local snapshot=e.lockedBasic
            zone='Friendly zone';territory='hostile';assert(j:ObserveZoneTerritory());book:Refresh()
            assert(summary():find('|cffff1a1aFriendly zone|r',1,true))
            assert(e.confirmed and e.lockedBasic==snapshot and #j:GetEventLog().entries==events)
            assert(not j:ObserveZoneTerritory(),'unchanged territory is a no-op')
            e.lockedBasic.locations['Unvisited zone']=true;book:Refresh()
            assert(summary():find('Unvisited zone',1,true))
            assert(not summary():find('|cff1aff1aUnvisited zone',1,true))
        ''')

    def test_faction_isolation_reload_backup_merge_and_shared_report_isolation(self):
        lua=client()
        lua.execute('''
            faction='Horde';assert(not j:GetLocationTerritory(zone))
            territory='hostile';assert(j:ObserveZoneTerritory())
            faction='Alliance';assert(j:GetLocationTerritory(zone)=='friendly')
            j=ns.CreateBestiaryJournal(settings,function() return 42 end)
            assert(j:GetLocationTerritory(zone)=='friendly')
            local snapshot=assert(j:CaptureBackup())
            local decoded=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(snapshot))))
            settings.bestiary.zoneTerritories={};assert(j:RestoreBackup(decoded))
            assert(j:GetLocationTerritory(zone)=='friendly')
            settings.accountWideTracking=true;local account=ns.InitializeTracking(settings)
            assert(account.bestiary.zoneTerritories[zone].Alliance=='friendly')
            assert(account.bestiary.zoneTerritories[zone].Horde=='hostile')
            local other={accountWideTracking=false};local j2=ns.CreateBestiaryJournal(other,function() return 42 end)
            territory='contested';j2:ObserveZoneTerritory();zone='New zone';j2:ObserveZoneTerritory()
            other.accountWideTracking=true;ns.InitializeTracking(other)
            assert(account.bestiary.zoneTerritories['Friendly zone'].Alliance=='friendly')
            assert(account.bestiary.zoneTerritories['New zone'].Alliance=='contested')
            local report=assert(ns.SharingReport.Capture(j,42))
            assert(not report.zoneTerritories and report.locations[1]=='Friendly zone')
            decoded.bestiary.zoneTerritories['Friendly zone'].Alliance='invented'
            assert(not ns.BestiaryBackups.Validate(decoded))
        ''')

    def test_subzone_restricted_unavailable_and_bounded_cache(self):
        lua=client()
        lua.execute('''
            territory='hostile';subzone=true;assert(not j:ObserveZoneTerritory())
            assert(j:GetLocationTerritory(zone)=='friendly')
            subzone=secret;assert(not j:ObserveZoneTerritory())
            subzone=false;territory=secret;assert(not j:ObserveZoneTerritory())
            territory='invented';assert(not j:ObserveZoneTerritory())
            C_PvP.GetZonePVPInfo=function() error('unavailable') end;assert(not j:ObserveZoneTerritory())
            C_PvP=nil;assert(not j:ObserveZoneTerritory())
            function GetZonePVPInfo() return 'contested',false end
            assert(j:ObserveZoneTerritory())
            faction=secret;assert(not j:ObserveZoneTerritory());faction='Alliance'
            zone=secret;assert(not j:ObserveZoneTerritory())
            settings.bestiary.zoneTerritories={}
            for i=1,1024 do settings.bestiary.zoneTerritories['Zone '..i]={Alliance='friendly'} end
            zone='Overflow';assert(not j:ObserveZoneTerritory())
            zone='Zone 1';assert(j:ObserveZoneTerritory())
            assert(j:GetLocationTerritory(zone)=='contested')
        ''')

    def test_zone_events_learn_without_creatures_or_notices(self):
        lua=event_client()
        lua.execute('''
            faction='Alliance';function UnitFactionGroup() return faction end
            territory='friendly';C_PvP={GetZonePVPInfo=function() return territory,false end}
            local messagesBefore=#messages;local eventsBefore=#journal:GetEventLog().entries
            fire('PLAYER_ENTERING_WORLD')
            assert(journal:GetLocationTerritory('Elwynn Forest')=='friendly')
            zone='Westfall';territory='contested';fire('ZONE_CHANGED_NEW_AREA')
            assert(journal:GetLocationTerritory('Westfall')=='contested')
            zone='Redridge';territory='hostile';fire('ZONE_CHANGED')
            assert(journal:GetLocationTerritory('Redridge')=='hostile')
            assert(not next(journal.entries) and #messages==messagesBefore)
            assert(#journal:GetEventLog().entries==eventsBefore)
        ''')


if __name__=='__main__':
    unittest.main()
