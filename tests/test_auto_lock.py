"""Auto-lock uses credited kills and persistent recorded-content changes."""
import unittest
from kill_test_harness import new_client


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


if __name__ == '__main__':
    unittest.main()
