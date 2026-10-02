"""Shared portrait capture through the real root binding and Bestiary recorder."""
import unittest

from test_loss_of_control import client


class SpellPortraitTests(unittest.TestCase):
    def test_open_uses_captured_id_without_assigning_even_when_locked_or_secret(self):
        lua = client()
        lua.execute('''
            local snapshot=captureAssignment('target',secret,'cast')
            units.target=units.nameplate1
            local opened
            assert(snapshot.open(function(id) opened=id;return true end))
            assert(opened==43 and journal.entries[43].name=='Creature B' and not ability(43))
            journal:SetEntryConfirmed(43,true)
            local revision=journal.revision
            assert(snapshot.open(function(id) assert(id==43);return true end))
            assert(journal.revision==revision and not ability(43))
            journal:DeleteEntry(43)
            assert(not snapshot.open(function() error('deleted page must not reopen') end))
            assert(not journal.entries[43]);publicTree(AzerothFieldbookDB)
        ''')

    def test_each_kind_assigns_captured_creature_in_combat_with_auto_off(self):
        for kind in ('cast', 'buff', 'debuff'):
            with self.subTest(kind=kind):
                lua = client(); lua.globals().kind = kind
                lua.execute('''
                    journal:SetAutoRecordAbilities(false)
                    local snapshot=captureAssignment('target',12345,kind)
                    assert(snapshot.id==43 and snapshot.unit=='target')
                    assert(not next(journal.entries))
                    units.target=units.nameplate1
                    assert(snapshot.assign())
                    local a=ability(43)
                    assert(a.state=='confirmed' and a.origin=='Your note' and not a.playerLossOfControl)
                    assert(not ability(42));publicTree(AzerothFieldbookDB)
                    local revision=journal.revision
                    assert(snapshot.assign() and journal.revision==revision and abilityCount(43)==1)
                    local log=journal:GetEventLog().entries
                    assert(log[#log].details.kind=='manual '..kind)
                ''')

    def test_buff_recipient_and_debuff_source_have_independent_captures(self):
        lua = client()
        lua.execute('''
            local buff=captureAssignment('target',54321,'buff')
            local debuff=captureAssignment('nameplate1',12345,'debuff')
            units.target=nil;units.nameplate1=nil
            assert(buff.assign() and debuff.assign())
            assert(ability(43,54321) and ability(42,12345))
            assert(not ability(43,12345) and not ability(42,54321))
            assert(journal.entries[43].abilities['Spell ID 54321'].origin=='Your note')
        ''')

    def test_restricted_id_has_identity_but_cannot_write_or_lookup_spell(self):
        lua = client()
        lua.execute('''
            local snapshot=captureAssignment('target',secret,'cast')
            assert(snapshot.id==43)
            local revision=journal.revision
            C_Spell.GetSpellName=function() error('must not query restricted spell') end
            assert(not snapshot.assign() and not next(journal.entries))
            assert(journal.revision==revision and output():find('ID is restricted',1,true))
            publicTree(AzerothFieldbookDB)
        ''')

    def test_public_identity_and_live_capture_race_fail_closed(self):
        for change in ('absent', 'controlled', 'friendly', 'guid', 'name', 'race'):
            with self.subTest(change=change):
                lua = client(); lua.globals().change = change
                lua.execute('''
                    if change=='absent' then units.target=nil
                    elseif change=='controlled' then units.target.controlled=true
                    elseif change=='friendly' then units.target.attackable=false
                    elseif change=='guid' then units.target.guid=secret
                    elseif change=='name' then units.target.name=secret
                    else UnitName=function() units.target=units.nameplate1;return 'Creature B' end end
                    assert(not captureAssignment('target',12345,'buff'))
                    assert(not next(journal.entries))
                ''')

    def test_snapshot_respects_lock_deletion_reset_and_wipe_hold(self):
        for change in ('lock', 'delete', 'reset', 'wipe', 'blocked'):
            with self.subTest(change=change):
                lua = client(); lua.globals().change = change
                lua.execute('''
                    journal:Ensure(43,false,'Creature B')
                    local snapshot=captureAssignment('target',12345,'cast')
                    if change=='lock' then journal:SetEntryConfirmed(43,true)
                    elseif change=='delete' then journal:DeleteEntry(43)
                    elseif change=='reset' then journal:Reset()
                    elseif change=='wipe' then
                        ns.SpellIDWindow.Initialize=function() duringWipe=captureAssignment('target',12345,'cast') end
                        SlashCmdList.AZEROTHFIELDBOOK('wipe');SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
                    else ns.InitializationBlocked=true end
                    local revision=journal.revision
                    assert(not snapshot.assign() and journal.revision==revision and not ability(43))
                    if change=='wipe' then assert(duringWipe and not duringWipe.assign() and not ability(43)) end
                    if change=='wipe' or change=='blocked' then assert(not captureAssignment('target',12345,'cast')) end
                ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
