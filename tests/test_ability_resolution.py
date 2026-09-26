"""Resolving a recorded ability commits canonical identity and review together."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime


def journal():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(r'''
        ns, db, secret = {}, {}, {}
        function issecretvalue(value) return rawequal(value,secret) end
        combat=false
        function InCombatLockdown() return combat end
        C_Spell={
            GetSpellName=function(id) if id==123 then return 'Canonical Spell' end end,
            GetSpellIDForSpellIdentifier=function(name) if name=='Canonical Spell' then return 123 end end,
        }
    ''')
    for file in ['SharingReport.lua', 'BestiaryJournal.lua']:
        lua.execute(ROOT.joinpath(file).read_text(), 'AzerothFieldbook', lua.globals().ns)
    lua.execute(r'''
        journal=ns.CreateBestiaryJournal(db,function() end)
        entry=journal:Ensure(42,false,'Test creature')
        journal:Offer(42,'Observed Spell','Automatic observation',123)
        ability=entry.abilities['Observed Spell']
        ability.note='Keep this note'
        ability.effects={Poison=true}
        ability.showInTooltip=false
        entry.rumours={{kind='ability',value='Canonical Spell',spellID=123}}
        db.bestiary.creatures[42]={spells={[123]={name='Observed Spell'}},names={}}
    ''')
    return lua


class AbilityResolutionTests(unittest.TestCase):
    def test_resolve_renames_confirms_and_preserves_details_across_reload(self):
        lua = journal()
        lua.execute(r'''
            assert(journal:ResolveAbility(42,'Observed Spell'))
            assert(not entry.abilities['Observed Spell'])
            assert(entry.abilities['Canonical Spell']==ability and ability.spellID==123)
            assert(ability.state=='confirmed' and ability.origin=='Your note')
            assert(ability.note=='Keep this note' and ability.effects.Poison and ability.showInTooltip==false)
            assert(entry.rumours[1].resolved, 'confirmation resolves matching rumours')
            journal:Offer(42,'Observed Spell','Automatic observation',123)
            assert(not entry.abilities['Observed Spell'], 'rescan must not revive the renamed pending record')
            journal=ns.CreateBestiaryJournal(db,function() end)
            assert(not journal.entries[42].abilities['Observed Spell'])
            assert(journal.entries[42].abilities['Canonical Spell'].state=='confirmed')
        ''')

    def test_name_only_resolution_confirms_and_removes_origin_label(self):
        lua = journal()
        lua.execute(r'''
            journal:Offer(42,'Canonical Spell','Automatic observation')
            assert(journal:ResolveAbility(42,'Canonical Spell'))
            local resolved=entry.abilities['Canonical Spell']
            assert(resolved.spellID==123 and resolved.state=='confirmed' and resolved.origin=='Your note')
            assert(not resolved.note)
        ''')

    def test_locked_combat_uncached_and_secret_fail_without_partial_changes(self):
        lua = journal()
        lua.execute(r'''
            local function unchanged()
                assert(entry.abilities['Observed Spell']==ability and not entry.abilities['Canonical Spell'])
                assert(ability.state=='pending' and ability.origin=='Automatic observation')
                assert(ability.note=='Keep this note' and not entry.rumours[1].resolved)
            end
            for _,state in ipairs({true,secret}) do
                combat=state
                assert(not journal:ResolveAbility(42,'Observed Spell')); unchanged()
            end
            combat=false
            journal:SetEntryConfirmed(42,true)
            assert(not journal:ResolveAbility(42,'Observed Spell')); unchanged()
            journal:SetEntryConfirmed(42,false)
            for _,readName in ipairs({function() end,function() return secret end,function() error('unreadable') end}) do
                C_Spell.GetSpellName=readName
                assert(not journal:ResolveAbility(42,'Observed Spell')); unchanged()
            end
        ''')

    def test_duplicate_canonical_record_merges_without_losing_notes_or_effects(self):
        lua = journal()
        lua.execute(r'''
            -- Legacy journals may already contain duplicate names for one ID.
            entry.abilities['Canonical Spell']={state='pending',origin='Automatic observation',
                spellID=123,note='Second note',effects={Slow=true}}
            assert(journal:ResolveAbility(42,'Observed Spell'))
            assert(not entry.abilities['Observed Spell'])
            assert(ability.note=='Keep this note\nSecond note' and ability.effects.Poison and ability.effects.Slow)
            assert(ability.state=='confirmed' and ability.showInTooltip==false)
        ''')

    def test_conflicting_ids_do_not_overwrite_existing_record(self):
        lua = journal()
        lua.execute(r'''
            journal:Offer(42,'Canonical Spell','Automatic observation',456)
            assert(not journal:ResolveAbility(42,'Observed Spell'))
            assert(entry.abilities['Observed Spell']==ability and ability.state=='pending')
            assert(entry.abilities['Canonical Spell'].spellID==456)
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
