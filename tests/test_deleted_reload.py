"""Retained combat sessions must not resurrect explicitly deleted creatures."""
import unittest
from kill_test_harness import new_client, ROOT
from test_zone_colours import client as ui_client

class DeletedReloadTests(unittest.TestCase):
    def test_old_meter_roster_cannot_discover_or_replay_after_delete(self):
        lua=new_client(initialize=False)
        lua.execute((ROOT/'BestiaryEncounterReader.lua').read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
        lua.execute("""
            local create=ns.CreateBestiaryJournal
            ns.CreateBestiaryJournal=function(...) journal=create(...);return journal end
            local createReader=ns.CreateBestiaryEncounterReader
            ns.CreateBestiaryEncounterReader=function(...) reader=createReader(...);return reader end
            local combat=UnitAffectingCombat
            function UnitAffectingCombat(unit) if unit=='player' then return false end;return combat(unit) end
            function InCombatLockdown() return false end
            Enum={DamageMeterType={EnemyDamageTaken=10},DamageMeterSourceDisplayType={Ally=1}}
            C_DamageMeter={
                GetAvailableCombatSessions=function() return {{sessionID=1}} end,
                GetCombatSessionFromID=function() return {combatSources={{sourceCreatureID=42,
                    sourceGUID='Creature-0-1-2-3-42-old',name='Rabid Dire Wolf',classFilename='',isLocalPlayer=false,sourceDisplayType=0}}} end,
            }
            fire('ADDON_LOADED','AzerothFieldbook')
            for i=1,6 do tick() end
            assert(reader, 'real encounter reader is loaded')
            reader:Scan()
            assert(not journal.entries[42], 'historical roster cannot discover a creature')
            units.target=spawn('old',false);units.target.name='Rabid Dire Wolf'
            fire('PLAYER_TARGET_CHANGED')
            assert(journal.entries[42].category=='Beast')
            assert(journal:DeleteEntry(42) and AzerothFieldbookDB.bestiary.deletedEntries[42])
            units.target=nil;fire('PLAYER_TARGET_CHANGED')
            assert(not AzerothFieldbookDB.bestiary.creatures[42])
            messages={};fire('ADDON_LOADED','AzerothFieldbook')
            for i=1,30 do tick() end
            fire('PLAYER_ENTERING_WORLD');for i=1,30 do tick() end
            SlashCmdList.AZEROTHFIELDBOOK('scan')
            assert(not journal.entries[42] and not output():find('Entry restored',1,true))
            units.target=spawn('new',false);units.target.name='Rabid Dire Wolf'
            fire('PLAYER_TARGET_CHANGED')
            assert(journal.entries[42].category=='Beast' and not AzerothFieldbookDB.bestiary.deletedEntries[42])
            assert(output():find('Entry restored',1,true) and points()==0)
        """)

    def test_held_guid_guard_and_marker_survive_reload_until_selection_leaves(self):
        lua=new_client()
        lua.execute("""
            local create=ns.CreateBestiaryJournal
            ns.CreateBestiaryJournal=function(...) journal=create(...);return journal end
            fire('ADDON_LOADED','AzerothFieldbook')
            units.target=spawn('held',false);fire('PLAYER_TARGET_CHANGED')
            assert(journal:DeleteEntry(42))
            fire('ADDON_LOADED','AzerothFieldbook');tick();fire('PLAYER_TARGET_CHANGED')
            assert(not journal.entries[42] and not journal:ObserveEncounter(42,'Rabid Dire Wolf'))
            local held=units.target;units.target=nil;fire('PLAYER_TARGET_CHANGED')
            units.target=held;fire('PLAYER_TARGET_CHANGED')
            assert(journal.entries[42].category=='Beast' and not AzerothFieldbookDB.bestiary.deletedEntries[42])
        """)

    def test_deletion_marker_backup_and_account_import_protect_saved_data(self):
        lua=ui_client()
        lua.execute("""
            assert(j:DeleteEntry(42))
            local backup=assert(j:CaptureBackup())
            local decoded=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(backup))))
            assert(decoded.bestiary.deletedEntries[42] and not decoded.bestiary.entries[42])
            assert(j:RestoreBackup(decoded) and not j:ObserveEncounter(42,'Rabid Dire Wolf'))
            settings.accountWideTracking=true;local account=ns.InitializeTracking(settings)
            assert(account.bestiary.deletedEntries[42] and not account.bestiary.entries[42])
            local other={accountWideTracking=false};local j2=ns.CreateBestiaryJournal(other,function() return 42 end)
            j2:Observe('target');other.accountWideTracking=true;ns.InitializeTracking(other)
            assert(not account.bestiary.entries[42],'new character import cannot restore a deleted account entry')
            local imported=ns.CreateBestiaryJournal(settings,function() return 42 end,account)
            assert(not imported:ObserveEncounter(42,'Rabid Dire Wolf'))
        """)

if __name__=='__main__': unittest.main()
