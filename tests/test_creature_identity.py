"""Creature identity through real encounter, cast, journal and reload paths."""
from pathlib import Path
import unittest

from kill_test_harness import new_client


ROOT = Path(__file__).resolve().parents[1]


def client():
    lua = new_client()
    for file in ['SharingReport.lua', 'BestiaryEncounterReader.lua']:
        lua.execute(ROOT.joinpath(file).read_text(), 'AzerothFieldbook', lua.globals().ns)
    lua.execute(r'''
        local createJournal=ns.CreateBestiaryJournal
        ns.CreateBestiaryJournal=function(...)
            journal=createJournal(...)
            return journal
        end
        function InCombatLockdown() return false end
        local affecting=UnitAffectingCombat
        function UnitAffectingCombat(unit)
            if unit=='player' then return false end
            return affecting(unit)
        end
        C_Spell={GetSpellName=function(id) return id==7384 and 'Attack' or 'Bottle of Poison' end}
        Enum={DamageMeterType={DamageDone=0,HealingDone=2,DamageTaken=7,EnemyDamageTaken=10},
            DamageMeterSourceDisplayType={Ally=1,Enemy=2}}
        creatureID, creatureName, spellID=1176, 'Tunnel Rat Forager', 7365
        rosterEnabled=true
        C_DamageMeter={
            IsDamageMeterAvailable=function() return true end,
            GetAvailableCombatSessions=function() return {{sessionID=1}} end,
            GetCombatSessionFromID=function(_,mode)
                if not rosterEnabled then return {combatSources={}} end
                if mode==10 or mode==0 then
                    return {combatSources={{sourceCreatureID=creatureID,name=creatureName,
                        classFilename='',isLocalPlayer=false,sourceDisplayType=2,
                        sourceGUID='Creature-0-1-2-3-'..creatureID..'-000001'}}}
                end
                return {combatSources={}}
            end,
            GetCombatSessionSourceFromID=function() return {combatSpells={{spellID=spellID,creatureName=''}}} end,
        }
        function scan() SlashCmdList.AZEROTHFIELDBOOK('scan') end
        fire('ADDON_LOADED','AzerothFieldbook')
        messages={}
    ''')
    return lua


class CreatureIdentityTests(unittest.TestCase):
    def test_roster_recovers_creature_without_live_identity_or_abilities(self):
        for kind in ('party', 'raid'):
            with self.subTest(kind=kind):
                lua = client()
                lua.globals().instanceKind = kind
                lua.execute(r'''
                    function IsInInstance() return true,instanceKind end
                    function GetInstanceInfo() return 'The Hall of Thanes',instanceKind end
                    units.target=spawn('restricted',false)
                    units.target.guid=secret;units.target.name=secret
                    fire('PLAYER_TARGET_CHANGED')
                    assert(not next(journal.entries),'hidden live identity must stay excluded')
                    C_DamageMeter.GetCombatSessionSourceFromID=function() return {combatSpells={}} end
                    scan()
                    local e=journal.entries[creatureID]
                    assert(e and e.name==creatureName and e.personalEncountered)
                    assert(not next(e.abilities) and e.kills==0 and not e.levelMin and not next(e.locations))
                    assert(not e.killLocations and not e.observationLocations and points()==0)
                    assert(#journal:GetEventLog().entries==1)
                    scan();fire('ADDON_LOADED','AzerothFieldbook');scan()
                    assert(#journal:GetEventLog().entries==1 and #journal:List()==1)
                ''')

    def test_roster_recovery_does_not_require_spell_detail_api_or_category(self):
        lua = client()
        lua.execute(r'''
            C_DamageMeter.GetCombatSessionSourceFromID=nil
            Enum.DamageMeterType.DamageTaken=nil
            scan()
            assert(journal.entries[creatureID].name==creatureName)
            assert(not next(journal.entries[creatureID].abilities))
        ''')

    def test_roster_recovery_preserves_wipe_boundary(self):
        lua = client()
        lua.execute(r'''
            C_DamageMeter.GetCombatSessionSourceFromID=function() return {combatSpells={}} end
            scan();assert(journal.entries[creatureID])
            SlashCmdList.AZEROTHFIELDBOOK('wipe')
            SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
            scan();assert(not next(journal.entries))
            fire('ADDON_LOADED','AzerothFieldbook');scan()
            assert(not next(journal.entries),'reload cannot reimport wiped roster history')
            C_DamageMeter.GetAvailableCombatSessions=function() return {{sessionID=2}} end
            scan();assert(journal.entries[creatureID])
        ''')

    def test_restriction_change_retries_roster_only_recovery_outside_combat(self):
        lua=client()
        lua.execute(r'''
            C_DamageMeter.GetCombatSessionSourceFromID=nil
            local summary=C_DamageMeter.GetCombatSessionFromID
            local readable=false
            C_DamageMeter.GetCombatSessionFromID=function(sid,mode)
                local result=summary(sid,mode)
                if not readable and mode==10 then result.combatSources[1].name=secret end
                return result
            end
            scan();assert(not next(journal.entries))
            local combat=true
            function InCombatLockdown() return combat end
            fire('ADDON_RESTRICTION_STATE_CHANGED')
            readable=true
            for _=1,10 do tick() end
            assert(not next(journal.entries),'restriction event never enables in-combat imports')
            combat=false
            for _=1,10 do tick() end
            assert(journal.entries[creatureID].name==creatureName)
        ''')

    def test_roster_only_import_rejects_restricted_owned_and_conflicting_identities(self):
        fixtures = [
            "row.sourceGUID=secret", "row.name=secret", "row.sourceCreatureID=secret",
            "row.sourceGUID='Pet-0-1-2-3-1176-1'", "row.classFilename='MAGE'",
            "row.isLocalPlayer=true", "row.sourceDisplayType=1",
            "rows[2]={sourceCreatureID=creatureID,name='Conflicting name',classFilename='',isLocalPlayer=false,sourceDisplayType=2}",
            "row.name=nil;setmetatable(row,{__index=function() error('restricted row') end})",
        ]
        for fixture in fixtures:
            with self.subTest(fixture=fixture):
                lua=client()
                lua.execute(r'''
                    C_DamageMeter.GetCombatSessionSourceFromID=nil
                    local summary=C_DamageMeter.GetCombatSessionFromID
                    C_DamageMeter.GetCombatSessionFromID=function(sid,mode)
                        local result=summary(sid,mode)
                        if mode==10 then
                            local rows=result.combatSources;local row=rows[1]
                ''' + fixture + r'''
                        end
                        return result
                    end
                    scan();assert(not next(journal.entries) and points()==0)
                ''')

    def test_post_combat_import_has_name_without_target_or_mouseover(self):
        lua = client()
        lua.execute(r'''
            assert(not next(units))
            scan()
            local entry=journal.entries[1176]
            assert(entry and entry.name=='Tunnel Rat Forager', 'meter identity must reach the journal')
            assert(entry.abilities['Bottle of Poison'].state=='pending')
            assert(journal:GetBasicInfo(1176).name==entry.name, 'book and Creature Notes use the same named record')
            assert(journal:List()[1].name==entry.name and select(1,journal:GetTotals())==1)
            assert(output():find('[Entry observed]|r Bestiary: Tunnel Rat Forager',1,true))
            assert(not output():find('Creature #',1,true))
            local _, announcements=output():gsub(' Bestiary: ', '')
            assert(announcements==1, 'discovery announces once without points alongside scan diagnostics')
            scan()
            assert(select(2,journal:GetTotals())==0, 'meter names without levels earn no discovery points')
            assert(not entry.levelMin and not next(entry.locations), 'meter cannot invent level or location')
        ''')

    def test_live_discovery_announces_name_before_points_callback(self):
        lua = client()
        lua.execute(r'''
            units.target=spawn('first',false)
            fire('PLAYER_TARGET_CHANGED')
            assert(output():find('[New discovery!]|r Bestiary: Test creature',1,true), 'identity must be saved before announcing')
            assert(not output():find('Creature #',1,true))
            assert(#messages==1, 'discovery announces once without points')
        ''')

    def test_instant_cast_requires_named_entry_before_saving_either_store(self):
        lua = client()
        lua.execute(r'''
            UNKNOWNOBJECT='Unknown'
            units.target=spawn('instant',false)
            for _,badName in ipairs({secret, '', '   ', UNKNOWNOBJECT, 'Creature #42', 'Encountered creature #42'}) do
                units.target.name=badName
                fire('UNIT_SPELLCAST_SUCCEEDED','target',nil,7365)
                assert(not journal.entries[42], 'unidentified casts cannot allocate a journal entry')
                assert(not AzerothFieldbookDB.bestiary.creatures[42], 'unidentified casts cannot create legacy observations')
                assert(select(2,journal:GetTotals())==0)
            end
            units.target.name='Test creature'
            fire('UNIT_SPELLCAST_SUCCEEDED','target',nil,7365)
            assert(journal.entries[42].name=='Test creature')
            assert(journal.entries[42].abilities['Bottle of Poison'])
            assert(AzerothFieldbookDB.bestiary.creatures[42].spells[7365])
        ''')

    def test_unknown_meter_names_fail_closed_and_retry(self):
        lua = client()
        lua.execute(r'''
            UNKNOWNOBJECT='Unknown'
            for _,badName in ipairs({secret, '', '   ', UNKNOWNOBJECT, 'Creature #1176'}) do
                creatureName=badName
                scan()
                assert(not journal.entries[1176])
                assert(not AzerothFieldbookDB.bestiary.creatures[1176])
                assert(select(2,journal:GetTotals())==0)
            end
            creatureName='Tunnel Rat Forager'
            scan()
            assert(journal.entries[1176].name==creatureName)
        ''')

    def test_existing_nameless_entry_is_hidden_then_repaired_without_data_loss(self):
        lua = client()
        lua.execute(r'''
            scan()
            journal:Ensure(1176,false,nil,{level=9}) -- Previously earned legacy credit.
            local saved=journal.entries[1176]
            saved.name=nil
            saved.abilities['Bottle of Poison'].note='Keep my evidence'
            saved.abilities['Bottle of Poison'].state='rejected'
            saved.confirmed=true
            saved.lockedBasic={category='Unclassified',locations={}}
            saved.idNotes={spells={7365},text='Keep these notes'}
            saved.kills=2
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(#journal:List()==0 and select(1,journal:GetTotals())==0, 'unresolved legacy entries stay out of the book')
            assert(select(2,journal:GetTotals())==1, 'earned credit is preserved')
            messages={}
            scan()
            local entry=journal.entries[1176]
            assert(entry==saved and entry.name=='Tunnel Rat Forager')
            assert(journal:GetBasicInfo(1176).name==entry.name, 'repair also fills missing locked identity')
            assert(entry.confirmed and entry.abilities['Bottle of Poison'].state=='rejected')
            assert(entry.abilities['Bottle of Poison'].note=='Keep my evidence')
            assert(entry.idNotes.text=='Keep these notes' and entry.kills==2)
            assert(select(2,journal:GetTotals())==1 and not output():find('+1 knowledge:',1,true))
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(journal:List()[1].name=='Tunnel Rat Forager', 'repair survives reload')
        ''')

    def test_legacy_ability_only_records_wait_for_identity(self):
        lua = client()
        lua.execute(r'''
            AzerothFieldbookDB.bestiary.creatures[42]={spells={[7365]={name='Bottle of Poison'}},names={}}
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(not journal.entries[42], 'legacy spell IDs alone cannot create a visible discovery')
            assert(#journal:List()==0 and select(2,journal:GetTotals())==0)
            units.target=spawn('legacy',false)
            fire('PLAYER_TARGET_CHANGED')
            assert(journal.entries[42].name=='Test creature')
            assert(journal.entries[42].abilities['Bottle of Poison'].state=='pending', 'deferred evidence restores after naming')
            assert(select(2,journal:GetTotals())==0)
            assert(journal:DeleteEntry(42))
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(not journal.entries[42] and not AzerothFieldbookDB.bestiary.creatures[42])
        ''')

    def test_ability_offers_cannot_create_a_creature_from_only_ids(self):
        lua = client()
        lua.execute(r'''
            assert(not journal:Ensure(1176))
            assert(not journal:Offer(1176,'Bottle of Poison','Automatic observation',7365))
            assert(not journal:Offer(secret,'Bottle of Poison','Automatic observation',7365,creatureName))
            assert(not next(journal.entries) and select(2,journal:GetTotals())==0)
        ''')

    def test_nameless_records_survive_account_migration_and_repair(self):
        lua = client()
        lua.execute(r'''
            scan()
            journal.entries[1176].name=nil
            journal.entries[1176].idNotes={spells={7365},text='Keep account migration notes'}
            local original=AzerothFieldbookDB.bestiary
            originalEntry=original.entries[1176]
        ''')
        lua.execute(ROOT.joinpath('Tracking.lua').read_text(), 'AzerothFieldbook', lua.globals().ns)
        lua.execute(r'''
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(journal.entries==AzerothFieldbookAccountDB.bestiary.entries)
            assert(#journal:List()==0 and select(1,journal:GetTotals())==0)
            scan()
            assert(journal.entries[1176].name=='Tunnel Rat Forager')
            assert(journal.entries[1176].idNotes.text=='Keep account migration notes')
            assert(journal.entries[1176].abilities['Bottle of Poison'])
            assert(select(2,journal:GetTotals())==0)
            assert(originalEntry.name==nil, 'character backup remains independent')
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(journal:List()[1].name=='Tunnel Rat Forager' and select(2,journal:GetTotals())==0)
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
