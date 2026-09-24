"""Recorder control flow only: mocks do not establish Forever API semantics."""
import unittest
from kill_test_harness import new_client


class KillDiagnostics(unittest.TestCase):
    def test_opt_in_recorder_separates_discovery_from_kill_rewards(self):
        lua = new_client(diagnostics=True)
        self.assertFalse(lua.eval('ns.KillDiagnostics.enabled'))
        self.assertEqual(lua.eval('#frames'), 1, 'no new event frame while disabled')
        lua.execute(r'''
            SlashCmdList.AZEROTHFIELDBOOK('debug kills on')
            units.mouseover = spawn('corpse', true)
            fire('UPDATE_MOUSEOVER_UNIT'); tick(); tick()
            units.target = units.mouseover
            fire('PLAYER_TARGET_CHANGED'); fire('UNIT_HEALTH', 'target'); tick()
            SlashCmdList.AZEROTHFIELDBOOK('debug kills')
        ''')
        self.assertEqual(lua.eval('kills()'), 0)
        self.assertEqual(lua.eval('points()'), 1, 'discovery is still earned')
        report = lua.eval('copiedReport')
        self.assertIn('build=69977', report)
        self.assertIn('tappedByPlayer=API MISSING', report)
        self.assertIn('tapDenied=false', report)
        self.assertIn('savedKills=0; killTierPoints=0; totalEarned=1', report)
        self.assertIn('sample only (no credit inferred from unit state)', report)
        self.assertNotIn('silver star', lua.eval('output()'))
        self.assertNotIn('gold star', lua.eval('output()'))
        lua.execute('beforeRows=#ns.KillDiagnostics.rows; beforeMessages=#messages; tick(); tick()')
        self.assertEqual(lua.eval('#ns.KillDiagnostics.rows'), lua.eval('beforeRows'))
        self.assertEqual(lua.eval('#messages'), lua.eval('beforeMessages'), 'recording does not flood chat')

    def test_candidate_event_stays_bound_to_payload_guid_and_never_awards(self):
        lua = new_client(diagnostics=True)
        lua.execute(r'''
            SlashCmdList.AZEROTHFIELDBOOK('debug kills on')
            units.target=spawn('A', false); fire('PLAYER_TARGET_CHANGED')
            units.target=spawn('B', true); fire('PLAYER_TARGET_CHANGED')
            fire('PARTY_KILL', 'Player-1-1', 'Creature-0-1-2-3-42-A')
            fire('PARTY_KILL', 'Player-1-1', 'Creature-0-1-2-3-42-A')
            fire('UNIT_DIED', 'Creature-0-1-2-3-42-A')
            fire('UNIT_LOOT', 'Creature-0-1-2-3-42-A', false)
            fire('PLAYER_XP_UPDATE', 'player')
            tick(); SlashCmdList.AZEROTHFIELDBOOK('debug kills')
        ''')
        self.assertEqual(lua.eval('kills()'), 0)
        self.assertEqual(lua.eval('points()'), 1)
        self.assertIn('PARTY_KILL: registered=true; delivered=2', lua.eval('copiedReport'))
        self.assertIn('victim=Creature-0-1-2-3-42-A', lua.eval('copiedReport'))
        self.assertNotIn('victim=Creature-0-1-2-3-42-B', lua.eval('copiedReport'))

    def test_secret_unknown_and_error_states_are_never_formatted_or_accepted(self):
        lua = new_client(diagnostics=True)
        lua.execute(r'''
            SlashCmdList.AZEROTHFIELDBOOK('debug kills on')
            units.target=spawn('safe', true); fire('PLAYER_TARGET_CHANGED')
            units.target.guid=secret; units.target.dead=secret
            units.target.denied=secret; units.target.name=secret; units.target.level=secret
            UnitIsTappedByPlayer=function() return secret end
            UnitHealth=function() return secret end
            fire('UNIT_FLAGS', 'target'); fire('UNIT_FLAGS', secret)
            fire('PARTY_KILL', secret, secret); fire('UNIT_DIED', secret); fire('UNIT_LOOT', secret, secret)
            UnitIsTapDenied=function() error('DO_NOT_EXPOSE_ERROR_PAYLOAD') end
            fire('UNIT_FACTION', 'target')
            UnitIsTapDenied=function() return nil end; fire('UNIT_FLAGS', 'target')
            UnitIsTapDenied=function() return 1 end; fire('UNIT_FLAGS', 'target')
            UnitIsTapDenied=nil; fire('UNIT_FLAGS', 'target')
            SlashCmdList.AZEROTHFIELDBOOK('debug kills')
        ''')
        report = lua.eval('copiedReport')
        for text in ['guid=SECRET', 'tappedByPlayer=SECRET', 'tapDenied=SECRET',
                     'tapDenied=API ERROR', 'tapDenied=MISSING', 'tapDenied=INVALID',
                     'tapDenied=API MISSING', 'attacker=SECRET; victim=SECRET']:
            self.assertIn(text, report)
        self.assertNotIn('DO_NOT_EXPOSE_ERROR_PAYLOAD', report)
        self.assertEqual(lua.eval('kills()'), 0)

    def test_bounded_reset_disable_and_registration_failure(self):
        lua = new_client(diagnostics=True)
        lua.execute(r'''
            SlashCmdList.AZEROTHFIELDBOOK('debug kills on')
            for i=1,120 do fire('UNIT_DIED', 'Creature-0-1-2-3-42-'..i) end
        ''')
        self.assertEqual(lua.eval('#ns.KillDiagnostics.rows'), 80)
        lua.execute(r'''
            local probe=ns.KillDiagnostics
            SlashCmdList.AZEROTHFIELDBOOK('debug kills off')
            fire('UNIT_DIED', 'should-not-arrive')
            assert(next(probe.frame.events)==nil)
            assert(probe.counts.UNIT_DIED==120)
            local register=probe.frame.RegisterEvent
            probe.frame.RegisterEvent=function(self, event)
                if event=='PARTY_KILL' then error('PRIVATE_REGISTRATION_ERROR') end
                return register(self, event)
            end
            SlashCmdList.AZEROTHFIELDBOOK('debug kills on')
            SlashCmdList.AZEROTHFIELDBOOK('debug kills')
        ''')
        self.assertIn('PARTY_KILL: registered=API ERROR; delivered=0', lua.eval('copiedReport'))
        self.assertNotIn('PRIVATE_REGISTRATION_ERROR', lua.eval('copiedReport'))
        self.assertEqual(lua.eval('#frames'), 2, 'reuse diagnostic frame')
        self.assertLess(lua.eval('#ns.KillDiagnostics.rows'), 10)
        self.assertIsNone(lua.eval('AzerothFieldbookDB.killDiagnostics'), 'recorder is not saved')

    def test_loot_returns_classified_independently_without_credit_inference(self):
        lua = new_client(diagnostics=True)
        lua.execute(r'''
            lootCalls=0
            CanLootUnit=function(guid)
                assert(not issecretvalue(guid), 'never pass restricted GUIDs to the query')
                lootCalls=lootCalls+1
                return lootHas,lootPermission
            end
            SlashCmdList.AZEROTHFIELDBOOK('debug kills on')
            assert(lootCalls==0, 'missing GUID does not call CanLootUnit')
            units.target=spawn('loot', true)
            -- Return combinations test classification only, not game semantics.
            lootHas,lootPermission=true,false
            fire('PLAYER_TARGET_CHANGED'); tick()
            lootHas,lootPermission=false,true
            fire('UNIT_LOOT', units.target.guid, false)
            lootHas,lootPermission=secret,true
            fire('UNIT_DIED', units.target.guid)
            lootHas,lootPermission=true,secret
            fire('UNIT_LOOT', units.target.guid, true)
            lootHas,lootPermission=nil,nil
            fire('UNIT_FLAGS','target')
            local before=lootCalls
            fire('UNIT_LOOT', secret, secret)
            assert(lootCalls==before, 'secret GUID is never queried')
            CanLootUnit=function() error('DO_NOT_PRINT_LOOT_ERROR') end
            fire('UNIT_FLAGS','target')
            SlashCmdList.AZEROTHFIELDBOOK('debug kills')
        ''')
        report = lua.eval('copiedReport')
        for state in ['hasLoot=true,canLoot=false', 'hasLoot=false,canLoot=true',
                      'hasLoot=SECRET,canLoot=true', 'hasLoot=true,canLoot=SECRET',
                      'hasLoot=MISSING,canLoot=MISSING', 'lootQuery=API ERROR',
                      'tapped=API MISSING', 'tappedByAllThreatList=API MISSING']:
            self.assertIn(state, report)
        self.assertNotIn('DO_NOT_PRINT_LOOT_ERROR', report)
        self.assertEqual(lua.eval('kills()'), 0)
        self.assertEqual(lua.eval('points()'), 1)

    def test_live_decisions_report_actual_awards_duplicates_and_expiry(self):
        lua = new_client(diagnostics=True)
        lua.execute(r'''
            SlashCmdList.AZEROTHFIELDBOOK('debug kills on')
            beginKill('first'); finishKill()
            beginKill('earned'); finishKill()
            fire('UNIT_DIED',units.target.guid)
            beginKill('expired')
            fire('PARTY_KILL',UnitGUID('player'),units.target.guid)
            clock=11; units.target.dead=true; fire('UNIT_DIED',units.target.guid)
            SlashCmdList.AZEROTHFIELDBOOK('debug kills')
        ''')
        report = lua.eval('copiedReport')
        self.assertIn('qualified kill tracking active', report)
        self.assertIn('accepted; killAward=1; killPointsAward=0', report)
        self.assertIn('accepted; killAward=1; killPointsAward=1', report)
        self.assertIn('duplicate; killAward=0; killPointsAward=0', report)
        self.assertIn('expired: observation or pending evidence', report)
        self.assertEqual(lua.eval('kills()'), 2)


if __name__ == '__main__':
    unittest.main()
