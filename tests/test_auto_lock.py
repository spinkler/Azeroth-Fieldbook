"""Auto-lock uses credited kills and persistent recorded-content changes."""
import unittest
from kill_test_harness import new_client, ROOT


def loot_client():
    lua = new_client()
    lua.execute((ROOT/'BestiaryLoot.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute('''
        local create=ns.CreateBestiaryJournal
        ns.CreateBestiaryJournal=function(...) activeJournal=create(...);return activeJournal end
        fire('ADDON_LOADED','AzerothFieldbook')
        lootItem,lootQuantity=100,1
        function GetNumLootItems() return 1 end
        function GetLootSourceInfo() return units.target.guid,lootQuantity end
        function GetLootSlotLink() return 'item:'..lootItem end
        function killAndLoot(suffix)
            beginKill(suffix);finishKill();fire('LOOT_READY');tick()
        end
    ''')
    return lua


class AutoLockTests(unittest.TestCase):
    def test_identical_loot_allows_auto_lock_and_new_items_restart_progress(self):
        lua = loot_client()
        lua.execute('''
            for i=1,10 do killAndLoot('same'..i) end
            local e=activeJournal.entries[42]
            assert(not e.confirmed and e.unchangedKills==9,
                'Only the first newly learned drop restarts the streak')
            for i=11,30 do killAndLoot('same'..i) end
            assert(e.confirmed and e.unchangedKills==10 and e.kills==30)
            assert(e.loot.samples==30 and e.loot.items[100].quantity==30)
            activeJournal:SetEntryConfirmed(42,false)
            for i=31,33 do killAndLoot('same'..i) end
            assert(e.unchangedKills==3)
            lootItem=101;fire('LOOT_READY')
            assert(e.unchangedKills==0,'A new drop resets progress immediately')
            for i=34,35 do killAndLoot('new'..i) end
            assert(e.unchangedKills==2)
            lootQuantity=4;fire('LOOT_READY');fire('LOOT_OPENED');tick()
            assert(e.unchangedKills==2,'Quantity and duplicate snapshots are bookkeeping')
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(activeJournal.entries[42].unchangedKills==2,'Reload preserves the streak')
        ''')

    def test_signature_upgrade_preserves_existing_progress(self):
        lua = new_client()
        lua.execute('''
            for i=1,8 do beginKill('legacy'..i);finishKill() end
            local e=AzerothFieldbookDB.bestiary.entries[42]
            e.autoLockSignature='{legacy full-loot signature}'
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(e.unchangedKills==8,'Changing the signature format is not new knowledge')
            for i=9,10 do beginKill('legacy'..i);finishKill() end
            assert(e.confirmed and e.unchangedKills==10)
        ''')

    def test_idle_observation_does_not_serialize_loot_history(self):
        lua = loot_client()
        lua.execute('''
            activeJournal:SetAutoLockEnabled(false)
            for i=1,128 do killAndLoot('history'..i) end
            units.target.dead=false;tick()
            local e=activeJournal.entries[42]
            local signature=e.autoLockSignature
            local sort=table.sort;local sorts=0
            table.sort=function(...) sorts=sorts+1;return sort(...) end
            collectgarbage('collect');collectgarbage('stop')
            local before=collectgarbage('count')
            for i=1,300 do tick() end
            local allocated=collectgarbage('count')-before
            collectgarbage('restart');table.sort=sort
            assert(sorts==0,'Unchanged polling must not rebuild sorted content signatures')
            assert(allocated<2048,'One minute of idle polling allocated '..allocated..' KiB')
            assert(e.autoLockSignature==signature and #e.loot.recent==128)
            units.target.level=6;tick()
            assert(e.levelMax==6 and e.autoLockSignature~=signature,
                'The cache must still notice new creature knowledge')
        ''')

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

    def test_content_cache_releases_deleted_entries_and_handles_replacement(self):
        lua = loot_client()
        lua.execute('''
            killAndLoot('deleted')
            local refs=setmetatable({activeJournal.entries[42]},{__mode='v'})
            assert(activeJournal:DeleteEntry(42))
            collectgarbage('collect');collectgarbage('collect')
            assert(refs[1]==nil,'The content cache must not retain deleted entries')
            killAndLoot('replacement')
            local e=activeJournal.entries[42]
            assert(not e.confirmed and e.unchangedKills==0 and e.loot.samples==1)
            killAndLoot('replacementAgain');assert(e.unchangedKills==1)
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
            assert(e.lockedBasic.locations['Test zone'] and points()==0)
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
            assert(points()==0,'re-adding this critter never repeats discovery credit')
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
            assert(e.confirmed and e.category=='Critter' and points()==0)
        ''')
        lua = new_client()
        lua.execute('''
            units.mouseover=spawn('beast',false)
            fire('UPDATE_MOUSEOVER_UNIT')
            assert(not AzerothFieldbookDB.bestiary.entries[42].confirmed)
        ''')


if __name__ == '__main__':
    unittest.main()
