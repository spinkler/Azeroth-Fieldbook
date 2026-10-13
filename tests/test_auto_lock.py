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
    def test_known_level_variants_share_one_counter_across_reload(self):
        lua = new_client()
        lua.execute('''
            for level=7,8 do
                units.target=spawn('observe'..level,false);units.target.level=level
                fire('PLAYER_TARGET_CHANGED')
            end
            local e=AzerothFieldbookDB.bestiary.entries[42]
            assert(e.levelMin==7 and e.levelMax==8 and e.unchangedKills==0)
            for i=1,10 do
                units.target=spawn('mixed'..i,false);units.target.level=i%2==0 and 8 or 7
                fire('PLAYER_TARGET_CHANGED');units.target.combat=true;finishKill()
                assert(e.kills==i and e.unchangedKills==i,
                    'each known level must advance the same auto-lock streak')
                if i==5 then fire('ADDON_LOADED','AzerothFieldbook') end
            end
            assert(e.confirmed and e.autoLocked)
        ''')

    def test_new_level_restarts_once_then_both_levels_count(self):
        lua = new_client()
        lua.execute('''
            for i,level in ipairs({7,7,8,8,7,8}) do
                units.target=spawn('newlevel'..i,false);units.target.level=level
                fire('PLAYER_TARGET_CHANGED');units.target.combat=true;finishKill()
                local e=AzerothFieldbookDB.bestiary.entries[42]
                local expected=i<3 and i or i-2
                assert(e.kills==i and e.unchangedKills==expected,
                    'a new level resets once, repeated level variants do not')
                if i>=3 then assert(e.autoLockResetReason=='level range changed') end
            end
        ''')

    def test_lock_origin_survives_reload_settings_changes_and_manual_relocking(self):
        lua = new_client()
        lua.execute('''
            for i=1,10 do beginKill('origin'..i);finishKill() end
            local db=AzerothFieldbookDB
            local j=ns.CreateBestiaryJournal(db,function() return 42 end)
            local e=j.entries[42]
            assert(e.autoLocked and j:IsEntryAutoLocked(42))
            e.autoLocked=nil
            j=ns.CreateBestiaryJournal(db,function() return 42 end)
            assert(j:IsEntryAutoLocked(42),'legacy completed streaks retain automatic origin')
            j:SetAutoLockKills(50);j:SetAutoLockEnabled(false)
            j=ns.CreateBestiaryJournal(db,function() return 42 end)
            assert(j:IsEntryAutoLocked(42) and e.unchangedKills==0,
                'changing the threshold or disabling auto-lock preserves its origin')
            assert(e.autoLockResetReason=='auto-lock disabled')
            j:SetEntryConfirmed(42,false)
            assert(not e.autoLocked and not j:IsEntryAutoLocked(42))
            assert(e.autoLockResetReason=='manually unlocked')
            j:SetEntryConfirmed(42,true)
            e.unchangedKills=50
            j=ns.CreateBestiaryJournal(db,function() return 42 end)
            assert(e.confirmed and not j:IsEntryAutoLocked(42),
                'an explicit manual lock cannot be inferred as automatic')
            e.autoLocked=nil;e.unchangedKills=0
            j=ns.CreateBestiaryJournal(db,function() return 42 end)
            assert(not j:IsEntryAutoLocked(42),'legacy locks without evidence stay unmarked')
        ''')

    def test_pending_casts_and_restricted_hints_do_not_reset_progress(self):
        lua = new_client()
        lua.execute(ROOT.joinpath('DetectedAbilities.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute('''
            beginKill('first');finishKill()
            local j=ns.CreateBestiaryJournal(AzerothFieldbookDB,function() return 42 end)
            local e=j.entries[42];j:SetAutoLockKills(4)
            ns.InstallDetectedAbilities(j)
            local opaque={};issecretvalue=function(value) return value==opaque end
            for i=1,3 do
                local before=e.unchangedKills
                j:Offer(42,'Pending cast '..i,'Observed',100+i)
                j:DetectAbility(42,opaque,opaque,i)
                j:TrackStableContent(42)
                assert(e.unchangedKills==before,'display evidence cannot restart auto-lock')
                beginKill('cast'..i);finishKill()
            end
            assert(e.confirmed and e.unchangedKills==4)
            j:SetEntryConfirmed(42,false)
            e.unchangedKills=2;e.autoLockSignature='knowledge2:legacy'
            local reloaded=ns.CreateBestiaryJournal(AzerothFieldbookDB,function() return 42 end)
            assert(e.unchangedKills==2,'signature migration preserves progress')
            reloaded:AddManual(42,'Recorded ability','Manual',{},1234)
            assert(e.unchangedKills==0,'actual recording resets progress')
        ''')

    def test_new_loot_never_resets_progress_and_locked_entries_keep_recording(self):
        lua = loot_client()
        lua.execute('''
            for i=1,10 do killAndLoot('same'..i) end
            local e=activeJournal.entries[42]
            assert(e.confirmed and e.unchangedKills==10,
                'Even the first newly learned drop must not restart the streak')
            for i=11,30 do killAndLoot('same'..i) end
            assert(e.confirmed and e.unchangedKills==10 and e.kills==30)
            assert(e.loot.samples==30 and e.loot.items[100].quantity==30)
            lootItem=102;killAndLoot('lockednew')
            assert(e.confirmed and e.unchangedKills==10 and e.kills==31)
            assert(e.loot.samples==31 and e.loot.items[102].quantity==1 and e.loot.items[102].drops==1,
                'locked creatures still record previously unseen drops')
            fire('LOOT_READY');fire('LOOT_OPENED');tick()
            assert(e.loot.samples==31 and e.loot.items[102].quantity==1,'locked loot stays deduplicated')
            activeJournal:SetEntryConfirmed(42,false)
            for i=32,34 do killAndLoot('same'..i) end
            assert(e.unchangedKills==3)
            lootItem=101;fire('LOOT_READY')
            assert(e.unchangedKills==3,'A previously unseen drop does not reset progress')
            assert(e.autoLockResetReason=='manually unlocked')
            for i=35,36 do killAndLoot('new'..i) end
            assert(e.unchangedKills==5)
            lootQuantity=4;fire('LOOT_READY');fire('LOOT_OPENED');tick()
            assert(e.unchangedKills==5,'Quantity and duplicate snapshots are bookkeeping')
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(activeJournal.entries[42].unchangedKills==5,'Reload preserves the streak')
            assert(activeJournal.entries[42].autoLockResetReason=='manually unlocked','Reload preserves the reset explanation')
        ''')

    def test_signature_upgrade_preserves_existing_progress(self):
        for signature in ['{legacy full-loot signature}', 'knowledge2:legacy', 'knowledge3:legacy']:
            with self.subTest(signature=signature):
                lua = new_client()
                lua.globals().legacySignature = signature
                lua.execute('''
                    for i=1,8 do beginKill('legacy'..i);finishKill() end
                    local e=AzerothFieldbookDB.bestiary.entries[42]
                    e.autoLockSignature=legacySignature
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
            assert(AzerothFieldbookDB.eventLog.entries[#AzerothFieldbookDB.eventLog.entries].details.kind=='autoLock')
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
            assert(not e.confirmed and e.unchangedKills==1 and e.loot.samples==1)
            killAndLoot('replacementAgain');assert(e.unchangedKills==2)
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
            assert(e.autoLockResetReason=='notes changed')
            beginKill('second');finishKill()
            j:SetCreatureNotes(42,'Changed')
            assert(e.unchangedKills==1,'no-op note edit retains streak')
            beginKill('third');finishKill()
            assert(not e.confirmed)
            j:Offer(42,'New ability','Automatic observation',123)
            assert(e.unchangedKills==2,'pending observations retain count')
            j:SetAbility(42,'New ability','confirmed')
            assert(e.unchangedKills==0,'recorded ability resets count')
            assert(e.autoLockResetReason=='abilities changed')
            for i=1,3 do beginKill('afterchange'..i);finishKill() end
            assert(e.confirmed and e.abilities['New ability'].state=='confirmed', 'locked='..tostring(e.confirmed)..' streak='..tostring(e.unchangedKills)..' state='..tostring(e.abilities['New ability'].state))
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
            assert(activeJournal:GetLockNewCritters() and e.confirmed and e.autoLocked)
            assert(e.lockedBasic.category=='Critter' and e.lockedBasic.levelMin==5)
            assert(not next(e.lockedBasic.locations) and points()==0)
            assert(not activeJournal:Offer(42,'New ability','Automatic observation',123))
            activeJournal:SetEntryConfirmed(42,false)
            fire('UPDATE_MOUSEOVER_UNIT');tick()
            assert(not e.confirmed and not e.autoLocked,'manual unlock clears the automatic origin')
            assert(activeJournal:Offer(42,'New ability','Automatic observation',123))
            activeJournal:SetLockNewCritters(false)
            assert(activeJournal:DeleteEntry(42))
            fire('ADDON_LOADED','AzerothFieldbook')
            fire('UPDATE_MOUSEOVER_UNIT')
            assert(not activeJournal:GetLockNewCritters() and not activeJournal.entries[42], 'deletion survives reload while the same creature remains selected')
            units.mouseover=nil;fire('UPDATE_MOUSEOVER_UNIT')
            units.mouseover=spawn('critter-again',false);fire('UPDATE_MOUSEOVER_UNIT')
            assert(activeJournal.entries[42] and not activeJournal.entries[42].confirmed, 'leaving the selection allows rediscovery without relocking')
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
