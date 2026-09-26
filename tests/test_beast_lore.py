"""Beast Lore capture from public native tooltips, identity binding and persistence."""
import unittest
from kill_test_harness import ROOT, LuaRuntime, new_client


def client():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        ns={};secret={};now=1000000
        function issecretvalue(v) return rawequal(v,secret) end
        function time() return now end
        units={target={id=42,guid='Creature-0-1-2-3-42-1',name='Forest Wolf',level=12}}
        function UnitGUID(u) return units[u] and units[u].guid end
        function UnitName(u) return units[u] and units[u].name end
        function UnitLevel(u) return units[u] and units[u].level end
        function UnitCreatureType(u) return units[u] and 'Beast' end
        function identify(u) return units[u] and units[u].id end
        rows={{leftText='Forest Wolf'},{leftText='Level 12 Beast'}}
        C_TooltipInfo={GetUnit=function() return {lines=rows} end}
    ''')
    for filename in ['SharingReport.lua', 'BeastLore.lua', 'BestiaryJournal.lua']:
        lua.execute((ROOT / filename).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute('''
        db={};j=ns.CreateBestiaryJournal(db,identify)
        e=j:Ensure(42,true,'Forest Wolf');e.category='Beast'
        function sent() j:BeastLoreEvent('UNIT_SPELLCAST_SENT','player','Forest Wolf','Cast-1',1462) end
        function success() j:BeastLoreEvent('UNIT_SPELLCAST_SUCCEEDED','player','Cast-1',1462) end
        function revealed()
            rows={{leftText='Forest Wolf'},{leftText='Level 12 Beast'},
                {leftText='Damage:',rightText='12 - 18'}, {leftText='Health:',rightText='244'},
                {leftText='Armor:',rightText='120'}, {leftText='Resistances:',rightText='Fire 5'},
                {leftText='Diet:',rightText='Meat'}, {leftText='Abilities:',rightText='Bite'},
                {leftText='Tameable'}, {leftText='Additional client field:',rightText='Retained'}}
        end
    ''')
    return lua


class BeastLoreTests(unittest.TestCase):
    def test_real_addon_cast_events_and_updates(self):
        lua = new_client(beast_lore=True)
        lua.execute('''
            function time() return 1000000 end
            units.target=spawn('lore',false)
            fire('PLAYER_TARGET_CHANGED')
            local lines={{leftText='Test creature'}}
            C_TooltipInfo={GetUnit=function() return {lines=lines} end}
            fire('UNIT_SPELLCAST_SENT','player','Test creature','Cast-lore',1462)
            fire('UNIT_SPELLCAST_SUCCEEDED','player','Cast-lore',1462)
            lines[2]={leftText='Tameable'};lines[3]={leftText='Diet:',rightText='Meat'}
            tick()
            local entry=AzerothFieldbookDB.bestiary.entries[42]
            assert(entry.beastLore.rows[2].right=='Meat')
            assert(entry.beastLoreSource=='gameTooltip')
        ''')

    def test_delayed_capture_locked_entry_reload_and_complete_native_rows(self):
        lua = client()
        lua.execute('''
            j:SetEntryConfirmed(42,true)
            sent();success();assert(not e.beastLore)
            revealed();j:PollBeastLore(0.2)
            assert(e.beastLore and #e.beastLore.rows==8)
            assert(e.beastLore.rows[1].right=='12 - 18')
            assert(e.beastLore.rows[8].right=='Retained')
            assert(e.beastLore.level==12 and e.beastLoreSource=='gameTooltip' and e.confirmed)
            local revision=j.revision;j:PollBeastLore(0.2);assert(j.revision==revision)
            local reload=ns.CreateBestiaryJournal(db,identify)
            assert(reload.entries[42].beastLore.rows[5].right=='Meat')
            assert(reload:GetSharingBalance()==0)
            j:PollBeastLore(6);rows[3].rightText='999';j:PollBeastLore(0.2)
            assert(e.beastLore.rows[1].right=='12 - 18','capture window expires')
        ''')

    def test_failed_cast_wrong_guid_secrets_and_ordinary_tooltip_never_capture(self):
        lua = client()
        lua.execute('''
            revealed();j:PollBeastLore(0.2);assert(not e.beastLore)
            sent();j:PollBeastLore(0.2);assert(not e.beastLore,'must succeed')
            units.target.guid='Creature-0-1-2-3-42-2';success();assert(not e.beastLore,'same species is not same target')
            units.target.guid='Creature-0-1-2-3-42-1'
            rows[3].rightText=secret;j:PollBeastLore(0.2);assert(not e.beastLore)
            C_TooltipInfo.GetUnit=function() error('restricted') end
            j:PollBeastLore(0.2);assert(not e.beastLore)
        ''')

    def test_ambiguous_mouseover_name_and_deletion_cancel_capture(self):
        lua = client()
        lua.execute('''
            units.mouseover={id=42,guid='Creature-0-1-2-3-42-2',name='Forest Wolf',level=12}
            sent();revealed();success();assert(not e.beastLore)
            units.mouseover=nil;sent();success();assert(e.beastLore)
            assert(j:DeleteEntry(42));j:PollBeastLore(0.2)
            assert(not j.entries[42],'pending capture cannot undo deletion')
        ''')

    def test_wire_validation_and_personal_precedence(self):
        lua = client()
        lua.execute('''
            sent();revealed();success()
            local S=ns.SharingReport
            local value=assert(S.CaptureLore(j,42))
            value.transaction='1000000-1-1';value.created=now;value.recipient='Bob Stonewell'
            local decoded=assert(S.Decode(assert(S.Encode(value))))
            assert(#decoded.beastLore.rows==8 and decoded.version==2)
            local other=ns.CreateBestiaryJournal({},identify)
            assert(other:ImportReport(decoded,'Alice Sunstrider',now))
            assert(other.entries[42].beastLoreSender=='Alice Sunstrider')
            assert(#other:GetRumours(42)==0 and other:GetSharingBalance()==0)
            decoded.beastLore.rows[1].right='999'
            assert(j:ImportReport(decoded,'Other Player',now))
            assert(e.beastLore.rows[1].right=='12 - 18' and e.beastLoreSource=='gameTooltip')
            decoded.rumours={{kind='offense',value='Fire'}};assert(not S.Validate(decoded))
            decoded.rumours={};decoded.beastLore.rows[1].right='|Hspell:1|h';assert(not S.Validate(decoded))
            decoded.beastLore.rows[1].right=secret;assert(not S.Validate(decoded))
            decoded.beastLore=secret;assert(not S.Validate(decoded))
        ''')


if __name__ == '__main__':
    unittest.main()
