"""Faction kill objectives are creatures; faction services remain excluded."""
import unittest

from kill_test_harness import ROOT
from test_discovery_rules import client


def quest_client():
    lua = client()
    lua.execute('''
        faction='Horde';related=true;inLog=true;civilian=false;tooltipCalls=0
        objectiveText="Rog'mar Poachers slain: 6/12"
        objectives={{type='monster',finished=false,text=objectiveText}}
        Enum={TooltipDataLineType={None=0,Blank=1,UnitName=2,QuestObjective=8,
            QuestTitle=17,QuestPlayer=18,UnitLevel=47,UnitType=48}}
        PVP_RANK_CIVILIAN='Civilian'
        locale='enUS';function GetLocale() return locale end
        function UnitFactionGroup(unit) return unit=='player' and 'Alliance' or faction end
        function UnitIsCivilian() return civilian end
        C_QuestLog={
            UnitIsRelatedToActiveQuest=function() return related end,
            GetLogIndexForQuestID=function(id) return inLog and id==12345 and 1 or nil end,
            GetQuestObjectives=function(id) assert(id==12345);return objectives end,
        }
        lines={{type=2,leftText="Rog'mar Poacher"},{type=47,leftText='Level 39'},
            {type=17,id=12345,leftText='Poacher hunt'},
            {type=8,leftText=objectiveText}}
        C_TooltipInfo={GetUnit=function(unit)
            tooltipCalls=tooltipCalls+1
            return {lines=lines}
        end}
        units.target=mob(39);units.target.name="Rog'mar Poacher"
    ''')
    return lua


class FactionQuestEnemies(unittest.TestCase):
    def test_kaijo_banner_bounty_without_active_kill_objective(self):
        lua = quest_client()
        lua.execute("""
            related=false
            units.target.guid='Creature-0-1-2-3-263071-kaijo'
            fire('PLAYER_TARGET_CHANGED')
            local entry=assert(journal.entries[263071])
            assert(entry.factionAffiliation=='Horde' and not entry.factionQuestObjective)
            assert(not journal:IsFactionAffiliated(263071) and #journal:List()==1)
        """)

    def test_debug_reports_first_failure_only_for_rejected_unit(self):
        lua = quest_client()
        lua.execute("""
            units.mouseover=units.target
            C_QuestLog.UnitIsRelatedToActiveQuest=function(unit) return unit~='mouseover' end
            lines[4].leftText='different progress text'
            SlashCmdList.AZEROTHFIELDBOOK('debug')
            local report=table.concat(messages,' ')
            assert(report:find('target first failed quest check: Tooltip and quest-log objective text differ.',1,true))
            assert(report:find('mouseover first failed quest check: UnitIsRelatedToActiveQuest: false',1,true))
            messages={}
            table.insert(lines,{type=8,leftText=objectiveText})
            SlashCmdList.AZEROTHFIELDBOOK('debug')
            report=table.concat(messages,' ')
            assert(report:find('target: eligible NPC',1,true))
            assert(not report:find('target first failed quest check',1,true))
        """)

    def test_nonservice_titles_are_allowed_for_verified_kill_targets(self):
        for title in ("<Rog'mar Clan>", '<Chief Poacher>', '<Master of the Hunt>',
                      "<Vendor's Bane>", 'Clan Chieftain',
                      '  |cffffd100< Captain of the Guard >|r  '):
            for kind in (0, 2):
                for faction in ('Alliance', 'Horde'):
                    with self.subTest(title=title, kind=kind, faction=faction):
                        lua = quest_client()
                        lua.globals().npcTitle = title
                        lua.globals().titleKind = kind
                        lua.globals().faction = faction
                        lua.execute('''
                            table.insert(lines,2,{type=titleKind,leftText=npcTitle})
                            fire('PLAYER_TARGET_CHANGED')
                            assert(journal.entries[42] and journal.entries[42].factionQuestObjective==12345)
                            assert(#journal:List()==1 and not journal:IsFactionAffiliated(42))
                        ''')

    def test_both_factions_and_deliberate_observation_paths(self):
        for faction in ('Alliance', 'Horde'):
            for token, event in (('target', 'PLAYER_TARGET_CHANGED'), ('mouseover', 'UPDATE_MOUSEOVER_UNIT')):
                with self.subTest(faction=faction, token=token):
                    lua = quest_client()
                    lua.globals().faction = faction
                    lua.globals().token = token
                    lua.globals().event = event
                    lua.execute('''
                        units[token]=units.target;if token~='target' then units.target=nil end
                        fire(event)
                        local e=journal.entries[42]
                        assert(e and e.factionAffiliation==faction and e.factionQuestObjective==12345)
                        assert(not journal:IsFactionAffiliated(42) and #journal:List()==1 and journal:GetTotals()==1)
                        assert(e.personalEncountered and e.levelMin==39 and points()==0)
                    ''')

    def test_existing_hidden_page_is_restored_without_losing_knowledge(self):
        lua = quest_client()
        lua.execute('''
            local e=journal:Ensure(42,false,"Rog'mar Poacher")
            e.factionAffiliation='Horde';e.notes='Keep my notes';e.kills=9
            assert(journal:IsFactionAffiliated(42) and #journal:List()==0 and journal:GetTotals()==0)
            fire('PLAYER_TARGET_CHANGED')
            assert(journal.entries[42]==e and not journal:IsFactionAffiliated(42))
            assert(#journal:List()==1 and e.notes=='Keep my notes' and e.kills==9)
        ''')

    def test_completed_or_abandoned_quest_keeps_capture_and_kill_eligibility(self):
        lua = quest_client()
        lua.execute('''
            fire('PLAYER_TARGET_CHANGED')
            local calls=tooltipCalls
            related=false;inLog=false;objectives[1].finished=true
            C_TooltipInfo.GetUnit=function() error('saved eligibility needs no new tooltip') end
            tick();fire('ADDON_LOADED','AzerothFieldbook');tick()
            assert(not journal:IsFactionAffiliated(42) and #journal:List()==1 and tooltipCalls==calls)
            function UnitCastingInfo() return 'Poacher shot',nil,nil,nil,nil,nil,nil,nil,456 end
            fire('UNIT_SPELLCAST_START','target')
            assert(journal.entries[42].abilities['Poacher shot'])
            units.target.combat=true;tick();finishKill()
            assert(kills()==1 and points()==1)
        ''')

    def test_faction_services_civilians_and_plain_npcs_remain_excluded(self):
        for setup in (
            'related=false',
            'civilian=true',
            "table.insert(lines,2,{type=0,leftText='<Flight Master>'})",
            "table.insert(lines,2,{type=0,leftText='<Wind Rider Master>'})",
            "table.insert(lines,2,{type=0,leftText='<Gryphon Master>'})",
            "table.insert(lines,2,{type=0,leftText='<Vendor>'})",
            "table.insert(lines,2,{type=2,leftText='<Class Trainer>'})",
            "MINIMAP_TRACKING_FLIGHTMASTER='Maître de vol';table.insert(lines,2,{type=0,leftText='<Maître de vol>'})",
            "lines[#lines+1]={type=0,leftText='Civilian'}",
            'lines[4]=nil',  # A quest giver/title is insufficient.
        ):
            for faction in ('Horde', 'Alliance'):
                with self.subTest(setup=setup, faction=faction):
                    lua = quest_client()
                    lua.globals().faction = faction
                    lua.execute(setup)
                    lua.execute('''
                        fire('PLAYER_TARGET_CHANGED');tick()
                        assert(not journal.entries[42] and points()==0)
                        journal:Ensure(42,false,'Old NPC');fire('PLAYER_TARGET_CHANGED')
                        assert(journal:IsFactionAffiliated(42) and #journal:List()==0)
                    ''')

    def test_service_titles_remain_excluded_even_with_matching_kill_objectives(self):
        for title in ('Hippogryph Master', 'Bat Handler', 'Innkeeper', 'Banker',
                      'Auctioneer', 'Stable Master', 'Battlemaster', 'Spirit Healer',
                      'Guild Master', 'Weapon Master', 'Mage Trainer', 'Mining Trainer',
                      'Food & Drink', 'General Goods', 'Blacksmithing Supplies',
                      'Reagents', 'Tabard Vendor', 'Travelling Merchant', 'Armorer',
                      'Gunsmith', 'Civilian', 'Former Mage Trainer',
                      '  |cffffd100< WIND  RIDER MASTER >|r  '):
            with self.subTest(title=title):
                lua = quest_client()
                lua.globals().npcTitle = title
                lua.execute('''
                    table.insert(lines,2,{type=0,leftText=npcTitle})
                    fire('PLAYER_TARGET_CHANGED');tick()
                    assert(not journal.entries[42])
                ''')

    def test_new_service_or_civilian_evidence_overrides_saved_quest_eligibility(self):
        for setup in ('civilian=true',
                      "table.insert(lines,2,{type=0,leftText='<Flight Master>'})",
                      "lines[#lines+1]={type=0,leftText='Civilian'}"):
            with self.subTest(setup=setup):
                lua = quest_client()
                lua.execute('''
                    table.insert(lines,2,{type=0,leftText='<Chief Poacher>'})
                    fire('PLAYER_TARGET_CHANGED')
                    local e=assert(journal.entries[42]);e.notes='Keep';e.kills=7
                    assert(e.factionQuestObjective==12345)
                    table.remove(lines,2);related=false;inLog=false
                    C_QuestLog.GetQuestObjectives=function() error('completed quest is not queried') end
                ''' + setup + '''
                    tick()
                    assert(journal:IsFactionAffiliated(42) and not e.factionQuestObjective)
                    assert(#journal:List()==0 and e.notes=='Keep' and e.kills==7)
                    fire('ADDON_LOADED','AzerothFieldbook')
                    assert(journal:IsFactionAffiliated(42) and journal.entries[42].notes=='Keep')
                ''')

    def test_titled_enemies_still_need_objectives_and_a_readable_supported_title(self):
        for setup in ('related=false', 'inLog=false', "objectives[1].type='item'",
                      'lines[2].leftText=secret', 'lines[2].leftText=123',
                      'locale="frFR"', 'locale=secret', 'GetLocale=nil'):
            with self.subTest(setup=setup):
                lua = quest_client()
                lua.execute('''
                    table.insert(lines,2,{type=0,leftText='<Chief Poacher>'})
                ''' + setup + '''
                    fire('PLAYER_TARGET_CHANGED');assert(not journal.entries[42])
                ''')

    def test_only_matching_personal_active_kill_objectives_qualify(self):
        for setup in (
            "objectives[1].type='item'",
            "objectives[1].type='event'",
            'objectives[1].finished=true',
            "objectives[1].text='Other enemy slain: 6/12'",
            'inLog=false',
            'lines[3].id=999',
            'table.insert(lines,4,{type=18,guid="Player-1-party"})',
            'lines[3]=lines[4];lines[4]=nil',
        ):
            with self.subTest(setup=setup):
                lua = quest_client()
                lua.execute(setup)
                lua.execute("fire('PLAYER_TARGET_CHANGED');assert(not journal.entries[42])")

    def test_quest_title_can_end_header_without_level(self):
        for subtitle, active, eligible in (
            ('Trainee', True, True), ('Mage Trainer', True, False),
            ('Trainee', False, False),
        ):
            with self.subTest(subtitle=subtitle, active=active):
                lua = quest_client()
                lua.globals().subtitle = subtitle
                lua.globals().inLog = active
                lua.execute("""
                    lines[2]={type=48,leftText=subtitle}
                    fire('PLAYER_TARGET_CHANGED')
                """)
                self.assertEqual(lua.eval("journal.entries[42] ~= nil"), eligible)

    def test_multiple_subtitles_still_check_each_role_and_require_kill_proof(self):
        for last, objective_type, eligible in (
            ('Trainee', 'monster', True), ('Mage Trainer', 'monster', False),
            ('Trainee', 'item', False),
        ):
            with self.subTest(last=last, objective_type=objective_type):
                lua = quest_client()
                lua.globals().last = last
                lua.globals().objectiveType = objective_type
                lua.execute("""
                    table.insert(lines,2,{type=0,leftText='<Clan Member>'})
                    table.insert(lines,3,{type=2,leftText='<Recruit>'})
                    table.insert(lines,4,{type=Enum.TooltipDataLineType.UnitType,leftText=last})
                    objectives[1].type=objectiveType
                    fire('PLAYER_TARGET_CHANGED')
                """)
                self.assertEqual(lua.eval("journal.entries[42] ~= nil"), eligible)

    def test_restricted_missing_and_failing_data_never_grant_an_exception(self):
        for setup in (
            'related=secret', 'related=nil', 'civilian=secret',
            'C_QuestLog=nil', 'C_TooltipInfo=nil', 'Enum=nil',
            'C_QuestLog.UnitIsRelatedToActiveQuest=nil',
            "C_QuestLog.UnitIsRelatedToActiveQuest=function() error('unavailable') end",
            "C_TooltipInfo.GetUnit=function() error('unavailable') end",
            'C_TooltipInfo.GetUnit=function() return secret end',
            'lines=secret', 'lines[3]=secret', 'lines[3].id=secret',
            'lines[4].type=secret', 'lines[4].leftText=secret',
            'objectives=secret', 'objectives[1]=secret',
            'objectives[1].type=secret', 'objectives[1].finished=secret',
            'objectives[1].text=secret',
            'function issecrettable(v) return rawequal(v,lines) end',
        ):
            with self.subTest(setup=setup):
                lua = quest_client()
                lua.execute(setup)
                lua.execute("fire('PLAYER_TARGET_CHANGED');assert(not journal.entries[42])")

    def test_identity_changes_and_stale_tooltips_do_not_authorize_either_creature(self):
        for setup in (
            "data.guid='Creature-0-1-2-3-99-other'",
            'data.guid=secret',
            "units[unit].guid='Creature-0-1-2-3-99-other'",
        ):
            with self.subTest(setup=setup):
                lua = quest_client()
                lua.execute('''
                    local get=C_TooltipInfo.GetUnit
                    C_TooltipInfo.GetUnit=function(unit)
                        local data=get(unit)
                ''' + setup + '''
                        return data
                    end
                    fire('PLAYER_TARGET_CHANGED')
                    assert(not journal.entries[42] and not journal.entries[99])
                ''')

    def test_exact_effect_sources_use_the_same_gate_and_reject_identity_mismatches(self):
        lua = quest_client()
        lua.execute('''
            local guid=units.target.guid
            assert(not journal:Observe('target',true,'Creature-0-1-2-3-99-other'))
            assert(not journal.entries[42])
            units.nameplate1=units.target;units.target=nil
            assert(journal:Observe('nameplate1',false,guid)==42)
            assert(journal.entries[42].factionQuestObjective==12345)
        ''')

    def test_ownership_attackability_and_airborne_rules_still_apply(self):
        for setup in ('units.target.controlled=true', 'units.target.attackable=false',
                      "units.target.guid='Player-1-1'", "units.target.guid='Pet-0-1-2-3-42-x'",
                      'taxi=true;units.mouseover=units.target;units.target=nil'):
            with self.subTest(setup=setup):
                lua = quest_client()
                lua.execute(setup)
                lua.execute("fire('PLAYER_TARGET_CHANGED');fire('UPDATE_MOUSEOVER_UNIT');tick();assert(not journal.entries[42])")

    def test_unknown_or_neutral_affiliation_keeps_existing_rules(self):
        for faction in ('nil', 'secret', "'Neutral'"):
            lua = quest_client()
            lua.execute(f'faction={faction};related=false')
            lua.execute('''
                fire('PLAYER_TARGET_CHANGED')
                assert(journal.entries[42] and not journal.entries[42].factionAffiliation)
            ''')

    def test_backup_account_import_and_sharing_boundaries(self):
        lua = quest_client()
        for module in ('SharingReport.lua', 'BestiaryBackups.lua', 'Tracking.lua'):
            lua.execute((ROOT / module).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute('''
            fire('ADDON_LOADED','AzerothFieldbook')
            fire('PLAYER_TARGET_CHANGED')
            local saved=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(assert(journal:CreateBackup())))))
            assert(saved.bestiary.entries[42].factionQuestObjective==12345)
            assert(journal:RestoreBackup(saved) and not journal:IsFactionAffiliated(42))
            local report=assert(ns.SharingReport.Capture(journal,42))
            assert(not report.factionQuestObjective and not report.factionAffiliation)
            local settings={accountWideTracking=false}
            local other=ns.CreateBestiaryJournal(settings,function() return 42 end)
            other:Ensure(42,false,"Rog'mar Poacher")
            settings.accountWideTracking=true
            local account=ns.InitializeTracking(settings)
            account.bestiary.entries[42].factionAffiliation='Horde'
            AzerothFieldbookDB.accountWideTracking=true
            local merged=ns.InitializeTracking(AzerothFieldbookDB)
            assert(merged.bestiary.entries[42].factionQuestObjective==12345)
            local j=ns.CreateBestiaryJournal(AzerothFieldbookDB,function() return 42 end,merged)
            assert(not j:IsFactionAffiliated(42))
            saved.bestiary.entries[42].factionQuestObjective='12345'
            assert(not ns.BestiaryBackups.Validate(saved))
        ''')


if __name__ == '__main__':
    unittest.main()
