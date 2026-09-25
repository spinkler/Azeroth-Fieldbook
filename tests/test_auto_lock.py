"""Auto-lock uses credited kills and persistent recorded-content changes."""
import unittest
from kill_test_harness import new_client, ROOT


class AutoLockTests(unittest.TestCase):
    def test_default_threshold_and_reload(self):
        lua = new_client()
        lua.execute('''
            for i=1,9 do beginKill('stable'..i);finishKill() end
            local entry=AzerothFieldbookDB.bestiary.entries[42]
            assert(not entry.confirmed and entry.unchangedKills==9)
            fire('ADDON_LOADED','AzerothFieldbook')
            beginKill('stable10');finishKill()
            assert(entry.confirmed and entry.unchangedKills==10)
            assert(AzerothFieldbookDB.eventLog.entries[#AzerothFieldbookDB.eventLog.entries-1].details.kind=='autoLock')
        ''')

    def test_changes_noops_unlock_disable_and_validation(self):
        lua = new_client()
        lua.execute('''
            beginKill('first');finishKill()
            local db=AzerothFieldbookDB
            local j=ns.CreateBestiaryJournal(db,function() return 42 end)
            local e=db.bestiary.entries[42]
            assert(j:GetAutoLockEnabled() and j:GetAutoLockKills()==10)
            assert(j:SetAutoLockKills(3))
            assert(not j:SetAutoLockKills('') and not j:SetAutoLockKills(0) and not j:SetAutoLockKills(1.5))
            assert(j:GetAutoLockKills()==3)
            j:SetCreatureNotes(42,'Changed')
            assert(e.unchangedKills==0)
            beginKill('second');finishKill()
            j:SetCreatureNotes(42,'Changed')
            assert(e.unchangedKills==1,'no-op note edit retains streak')
            beginKill('third');finishKill()
            assert(not e.confirmed)
            j:Offer(42,'New ability','Automatic observation',123)
            assert(e.unchangedKills==0)
            for i=1,3 do beginKill('afterchange'..i);finishKill() end
            assert(e.confirmed and e.abilities['New ability'].state=='pending', 'locked='..tostring(e.confirmed)..' streak='..tostring(e.unchangedKills)..' state='..tostring(e.abilities['New ability'].state))
            j:SetEntryConfirmed(42,false)
            assert(e.unchangedKills==0)
            j:SetAutoLockEnabled(false)
            for i=1,4 do beginKill('disabled'..i);finishKill() end
            assert(not e.confirmed and e.unchangedKills==0)
            j:SetAutoLockEnabled(true)
            for i=1,3 do beginKill('enabled'..i);finishKill() end
            assert(e.confirmed)
        ''')

    def test_new_critter_default_snapshot_and_manual_unlock(self):
        lua = new_client()
        lua.execute(ROOT.joinpath('SharingReport.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute('''
            local create=ns.CreateBestiaryJournal
            ns.CreateBestiaryJournal=function(...)
                activeJournal=create(...);return activeJournal
            end
            fire('ADDON_LOADED','AzerothFieldbook')
            function UnitCreatureType() return 'Critter' end
            units.mouseover=spawn('critter',false)
            fire('UPDATE_MOUSEOVER_UNIT')
            local e=activeJournal.entries[42]
            assert(activeJournal:GetLockNewCritters() and e.confirmed)
            assert(e.lockedBasic.category=='Critter' and e.lockedBasic.levelMin==5)
            assert(e.lockedBasic.locations['Test zone'] and points()==1)
            assert(not activeJournal:Offer(42,'New ability','Automatic observation',123))
            activeJournal:SetEntryConfirmed(42,false)
            fire('UPDATE_MOUSEOVER_UNIT');tick()
            assert(not e.confirmed,'manual unlock is respected')
            assert(activeJournal:Offer(42,'New ability','Automatic observation',123))
            activeJournal:SetLockNewCritters(false)
            assert(activeJournal:DeleteEntry(42))
            fire('ADDON_LOADED','AzerothFieldbook')
            fire('UPDATE_MOUSEOVER_UNIT')
            assert(not activeJournal:GetLockNewCritters() and not activeJournal.entries[42].confirmed)
            activeJournal:SetLockNewCritters(true)
            tick()
            assert(not activeJournal.entries[42].confirmed,'enabling does not relock an existing critter')
            assert(points()==1,'re-adding this critter never repeats discovery credit')
            activeJournal:ResetDatabase()
            assert(activeJournal:GetLockNewCritters(),'full reset restores the enabled default')
        ''')

    def test_unreadable_type_retries_classification_without_affecting_beasts(self):
        lua = new_client()
        lua.execute('''
            units.mouseover=spawn('unknown-type',false)
            function UnitCreatureType() return secret end
            fire('UPDATE_MOUSEOVER_UNIT')
            local e=AzerothFieldbookDB.bestiary.entries[42]
            assert(not e.confirmed and e.category=='Unclassified')
            function UnitCreatureType() return 'Critter' end
            fire('UPDATE_MOUSEOVER_UNIT')
            assert(e.confirmed and e.category=='Critter' and points()==1)
        ''')
        lua = new_client()
        lua.execute('''
            units.mouseover=spawn('beast',false)
            fire('UPDATE_MOUSEOVER_UNIT')
            assert(not AzerothFieldbookDB.bestiary.entries[42].confirmed)
        ''')


if __name__ == '__main__':
    unittest.main()
