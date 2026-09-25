"""Personal first-encounter timestamps survive observations, migration and restore."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime


def client():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        ns={};stamp=1790300000;secret={}
        function issecretvalue(value) return rawequal(value,secret) end
        function time() return stamp end
        function UnitName() return 'Forest Lurker' end
        function UnitCreatureType() return 'Beast' end
        function UnitLevel() return 11 end
        function GetRealZoneText() return 'Loch Modan' end
        function identify() return 42 end
        function open(db,store) return ns.CreateBestiaryJournal(db,identify,store) end
    ''')
    for filename in ['SharingReport.lua', 'BestiaryBackups.lua', 'BestiaryJournal.lua', 'Tracking.lua']:
        lua.execute((ROOT / filename).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    return lua


class FirstEncounterTests(unittest.TestCase):
    def test_personal_discovery_preserves_date_through_lock_reload_and_deletion(self):
        lua = client()
        lua.execute('''
            local db={accountWideTracking=false};local j=open(db)
            j:Observe('target')
            local first=j:GetFirstEncounteredAt(42)
            assert(first==stamp and j.entries[42].firstEncounteredAt==stamp)
            assert(db.bestiary.points.credits[42].firstEncounteredAt==stamp)
            stamp=stamp+100;j:SetEntryConfirmed(42,true);j:Observe('target')
            assert(j:GetFirstEncounteredAt(42)==first)
            j=open(db);j:Observe('target');assert(j:GetFirstEncounteredAt(42)==first)
            j:DeleteEntry(42);j:Observe('target');assert(j:GetFirstEncounteredAt(42)==first)
            stamp=stamp+100
            j:Offer(43,'Poison','Automatic observation',123,'Another creature')
            assert(j:GetFirstEncounteredAt(43)==stamp,'attributed encounter casts also record discovery time')
        ''')

    def test_shared_report_waits_for_personal_encounter(self):
        lua = client()
        lua.execute('''
            local j=open({})
            local report={version=1,transaction='1-1-1',created=stamp,recipient='Player',creatureID=42,
                name='Forest Lurker',category='Beast',levelMin=11,levelMax=11,locations={'Loch Modan'},rumours={}}
            assert(j:ImportReport(report,'Ally',stamp))
            local first,personal=j:GetFirstEncounteredAt(42)
            assert(first==nil and personal==false)
            j:SetEntryConfirmed(42,true)
            stamp=stamp+300;j:Observe('target')
            assert(j:GetFirstEncounteredAt(42)==stamp and j.entries[42].personalEncountered)
        ''')

    def test_legacy_history_recovery_never_invents_a_date(self):
        lua = client()
        lua.execute('''
            local db={bestiary={entries={[42]={id=42,name='Forest Lurker',locations={},abilities={},damage={}}}}}
            local j=open(db)
            assert(j:GetFirstEncounteredAt(42)==nil)
            j:Observe('target');assert(j:GetFirstEncounteredAt(42)==nil,'later observations cannot date old entries')
            db.eventLog.entries={
                {timestamp=stamp-1000,details={creatureID=42,title='New observed level',points=1}},
                {timestamp=stamp-900,details={creatureID=42,kind='cast'}},
                {timestamp=stamp-800,details={creatureID=42,title='New discovery!'}},
                {timestamp=stamp-100,details={creatureID=42,title='New discovery!',points=1}},
                {timestamp=stamp-200,details={creatureID=42,title='New discovery!',points=1}},
                {timestamp=secret,details={creatureID=42,title='New discovery!',points=1}},
            }
            j=open(db);assert(j:GetFirstEncounteredAt(42)==stamp-200,'earliest scored discovery, not other activity')
            local later=stamp
            stamp=secret
            local missing=open({});missing:Observe('target');assert(missing:GetFirstEncounteredAt(42)==nil)
            stamp=later;missing:Observe('target');assert(missing:GetFirstEncounteredAt(42)==nil)
        ''')

    def test_account_merge_keeps_earliest_and_recovers_character_log(self):
        lua = client()
        lua.execute('''
            local a={};open(a):Observe('target')
            local first=stamp
            local account=ns.InitializeTracking(a)
            stamp=stamp-500
            local b={};local bj=open(b);bj:Observe('target')
            -- Simulate a journal from before timestamps were stored on entries.
            bj.entries[42].firstEncounteredAt=nil;b.bestiary.points.credits[42].firstEncounteredAt=nil
            b.eventLog.entries={{timestamp=stamp,details={creatureID=42,title='New discovery!',points=1}}}
            local sameAccount=ns.InitializeTracking(b)
            assert(account==sameAccount)
            assert(account.bestiary.entries[42].firstEncounteredAt==stamp)
            assert(account.bestiary.points.credits[42].firstEncounteredAt==stamp)
            stamp=first+500;local merged=open(a,account);merged:Observe('target')
            assert(merged:GetFirstEncounteredAt(42)==first-500)
        ''')

    def test_backup_round_trip_and_older_backup_keep_known_date(self):
        lua = client()
        lua.execute('''
            local db={accountWideTracking=false};local j=open(db);j:Observe('target')
            local first=stamp
            local saved=assert(j:CreateBackup())
            local copied=assert(ns.BestiaryBackups.Decode(ns.BestiaryBackups.Encode(saved)))
            assert(copied.bestiary.entries[42].firstEncounteredAt==first)
            assert(copied.bestiary.points.credits[42].firstEncounteredAt==first)
            copied.bestiary.entries[42].firstEncounteredAt=nil
            copied.bestiary.points.credits[42].firstEncounteredAt=nil
            stamp=stamp+100;assert(j:RestoreBackup(copied))
            assert(j:GetFirstEncounteredAt(42)==first,'undated backups do not erase current history')
            local imported=open({});assert(imported:RestoreBackup(saved))
            assert(imported:GetFirstEncounteredAt(42)==first)
        ''')


if __name__ == '__main__':
    unittest.main()
