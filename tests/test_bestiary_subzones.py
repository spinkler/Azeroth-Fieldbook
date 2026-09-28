"""Zone-only Bestiary locations, subzone hover and conservative migration."""
import unittest
from test_zone_colours import client

class SubzoneTests(unittest.TestCase):
    def test_zone_parent_and_locked_subzone_observation(self):
        lua=client()
        lua.execute(r'''
            zone='Sentinel Tower';local sub='Sentinel Tower'
            function GetSubZoneText() return sub end
            C_Map={GetBestMapForUnit=function() return 101 end,GetMapInfo=function(id)
                if id==101 then return {name='Sentinel Tower',mapType=5,parentMapID=100} end
                return {name='Westfall',mapType=3,parentMapID=0}
            end}
            j:Observe('target')
            assert(e.locations.Westfall and not e.locations['Sentinel Tower'])
            assert(j:GetSubzones(42,'Westfall')[1]=='Sentinel Tower')
            local before=settings.bestiary.points.earned
            j:SetEntryConfirmed(42,true);sub='Moonbrook';zone='Westfall';j:Observe('target')
            assert(#j:GetSubzones(42,'Westfall')==2 and e.confirmed)
            assert(settings.bestiary.points.earned==before,'subzones do not award zone discovery points')
            book:Refresh()
            assert(not summary():find('Moonbrook',1,true) and not summary():find('Sentinel Tower',1,true))
            GameTooltip={lines={}}
            function GameTooltip:SetOwner() end
            function GameTooltip:SetText(text) self.title=text;self.lines={} end
            function GameTooltip:AddLine(text) self.lines[#self.lines+1]=text end
            function GameTooltip:Show() self.shown=true end
            function GameTooltip:Hide() self.shown=false end
            local index
            for i,name in ipairs(section.locationNames) do if name=='Westfall' then index=i end end
            section.summaryArea.scripts.OnHyperlinkEnter(section.summaryArea,'afbzone:'..index)
            assert(GameTooltip.title=='Westfall' and GameTooltip.lines[2]=='Moonbrook' and GameTooltip.lines[3]=='Sentinel Tower')
            section.summaryArea.scripts.OnHyperlinkLeave();assert(not GameTooltip.shown)
        ''')

    def test_migration_reload_backup_and_account_merge(self):
        lua=client()
        lua.execute(r'''
            e.locations={Westfall=true,['Sentinel Tower']=true,['Unknown old place']=true}
            j:SetEntryConfirmed(42,true)
            e.discoveryProgress={zones={['Sentinel Tower']=true},levels={},points=0}
            local before=settings.bestiary.points.earned
            j=ns.CreateBestiaryJournal(settings,function() return 42 end);e=j.entries[42]
            assert(not e.locations['Sentinel Tower'] and e.locations.Westfall)
            assert(not e.lockedBasic.locations['Sentinel Tower'])
            assert(e.locations['Unknown old place'],'unresolvable history is preserved')
            assert(e.subzones.Westfall['Sentinel Tower'])
            assert(not e.discoveryProgress.zones['Sentinel Tower'] and e.discoveryProgress.zones.Westfall)
            assert(settings.bestiary.points.earned==before,'migration preserves earned knowledge')
            assert(not j:MigrateLocations(),'migration is idempotent')
            local snapshot=assert(j:CaptureBackup())
            local decoded=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(snapshot))))
            assert(decoded.bestiary.entries[42].subzones.Westfall['Sentinel Tower'])
            assert(j:RestoreBackup(decoded))
            settings.accountWideTracking=true;local account=ns.InitializeTracking(settings)
            assert(account.bestiary.entries[42].subzones.Westfall['Sentinel Tower'])
            local other={accountWideTracking=false};local second=ns.CreateBestiaryJournal(other,function() return 42 end)
            second:Observe('target');second.entries[42].subzones={Westfall={Moonbrook=true}}
            other.accountWideTracking=true;ns.InitializeTracking(other)
            assert(account.bestiary.entries[42].subzones.Westfall.Moonbrook)
            assert(account.bestiary.entries[42].subzones.Westfall['Sentinel Tower'])
        ''')

    def test_learned_association_repairs_only_supported_history(self):
        lua=client()
        lua.execute(r'''
            e.locations={Westfall=true,Moonbrook=true}
            e.confirmed=false
            local old=j:Ensure(43,false,'Other creature')
            old.locations={Moonbrook=true,['Other zone']=true}
            zone='Westfall';function GetSubZoneText() return 'Moonbrook' end
            j:Observe('target')
            assert(e.locations.Westfall and not e.locations.Moonbrook)
            assert(e.subzones.Westfall.Moonbrook)
            assert(old.locations.Moonbrook and not old.locations.Westfall,'ambiguous other history is preserved')
            local report=assert(ns.SharingReport.Capture(j,42))
            assert(#report.locations==1 and report.locations[1]=='Westfall' and not report.subzones)
        ''')

    def test_unavailable_secret_and_duplicate_subzones(self):
        lua=client()
        lua.execute(r'''
            local sub='Small settlement';zone='Elwynn Forest'
            function GetSubZoneText() return sub end
            C_Map={GetBestMapForUnit=function() return secret end}
            j:Observe('target');j:Observe('target')
            assert(#j:GetSubzones(42,zone)==1)
            sub=secret;j:Observe('target');assert(#j:GetSubzones(42,zone)==1)
            sub='Unmapped area';zone=sub;j:Observe('target')
            assert(not e.locations[sub],'known subzone is not recorded as a zone without a parent')
        ''')

if __name__=='__main__':
    unittest.main()
