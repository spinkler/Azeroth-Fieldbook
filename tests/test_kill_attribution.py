"""Real event/scan paths, informed by Forever captures and tag eligibility policy.

Group/pet mocks test the policy, not live group/pet compatibility. No XP/loot API
or undocumented tap function is invented to manufacture positive credit.
"""
import unittest
from kill_test_harness import new_client


class KillAttribution(unittest.TestCase):
    def test_first_encounter_is_another_players_corpse(self):
        for unit, event in [('mouseover', 'UPDATE_MOUSEOVER_UNIT'), ('target', 'PLAYER_TARGET_CHANGED')]:
            with self.subTest(unit=unit):
                lua = new_client()
                lua.execute(f"units.{unit} = spawn('corpse', true); units.{unit}.denied = true; fire('{event}')")
                self.assertEqual(lua.eval('kills()'), 0)
                self.assertEqual(lua.eval('points()'), 1, 'permitted discovery point')
                lua.execute("tick(); tick(); fire('UNIT_HEALTH', '" + unit + "')")
                self.assertEqual(lua.eval('kills()'), 0, 'corpse observation must not manufacture a kill')
                self.assertEqual(lua.eval('points()'), 1, 'no silver/gold points')
                self.assertNotIn('10 kills!', lua.eval('output()'))
                self.assertNotIn('25 kills!!', lua.eval('output()'))

    def test_observed_alive_then_killed_by_someone_else(self):
        lua = new_client()
        lua.execute("units.target = spawn('watched', false); fire('PLAYER_TARGET_CHANGED')")
        self.assertEqual(lua.eval('points()'), 1)
        lua.execute("units.target.dead = true; units.target.attackable = false; units.target.denied = true; tick()")
        self.assertEqual(lua.eval('kills()'), 0, 'previously alive is identity evidence only')
        self.assertEqual(lua.eval('points()'), 1)

    def test_unclaimed_living_target_is_not_credit_or_cached_eligibility(self):
        lua = new_client()
        lua.execute("units.target = spawn('untagged', false); fire('PLAYER_TARGET_CHANGED')")
        # Not denied while alive must neither count nor supply later eligibility.
        lua.execute("tick(); tick(); fire('UNIT_HEALTH', 'target')")
        self.assertEqual(lua.eval('kills()'), 0)
        lua.execute('UnitIsTapDenied=function() return nil end')
        lua.execute("units.target.dead = true; fire('UNIT_HEALTH', 'target'); tick()")
        self.assertEqual(lua.eval('kills()'), 0, 'unknown eligibility at death must not use an old living sample')
        self.assertEqual(lua.eval('points()'), 1)

    def test_solo_kill_and_duplicate_notifications_follow_live_capture(self):
        lua = new_client()
        lua.execute(r'''
            victim=beginKill('solo')
            fire('PARTY_KILL', UnitGUID('player'), victim)
            assert(kills()==0, 'wait for independent death evidence')
            units.target=nil -- observed client behavior: the target can clear
            fire('UNIT_DIED', victim)
            fire('PLAYER_XP_UPDATE', 'player')
            fire('UNIT_LOOT', victim, true)
            units.mouseover=spawn('solo', true)
            fire('UPDATE_MOUSEOVER_UNIT'); tick(); tick()
            fire('PARTY_KILL', UnitGUID('player'), victim)
            fire('UNIT_DIED', victim)
        ''')
        self.assertEqual(lua.eval('kills()'), 1)
        self.assertEqual(lua.eval('points()'), 1)
        self.assertNotIn('10 kills!', lua.eval('output()'))

    def test_zero_xp_no_loot_and_cap_policy(self):
        for scenario in ['grey', 'capped']:
            with self.subTest(scenario=scenario):
                lua = new_client()
                # API shape/ordering recorded in the no-XP capture. The cap label
                # tests identical no-XP policy, not an unperformed live cap test.
                lua.execute(f"beginKill('{scenario}'); units.target.level=1; finishKill()")
                self.assertEqual(lua.eval('kills()'), 1)
                self.assertEqual(lua.eval('points()'), 1, 'only initial discovery; new levels award nothing')
                self.assertNotIn('10 kills!', lua.eval('output()'))

    def test_pet_and_party_policy_with_no_personal_final_blow(self):
        for role in ['pet', 'party1', 'partypet1']:
            with self.subTest(role=role):
                lua = new_client()
                lua.execute(f"actorUnits.{role}='Pet-0-1-2-3-9-abc'; beginKill('group'); finishKill(actorUnits.{role})")
                self.assertEqual(lua.eval('kills()'), 1)
                self.assertEqual(lua.eval('points()'), 1)

    def test_eligible_tag_counts_without_event_or_with_outside_finisher(self):
        for actor in [None, 'Player-2-999']:
            with self.subTest(actor=actor):
                lua = new_client()
                lua.execute("actorUnits.party1='Player-2-1'; victim=beginKill('other')")
                if actor:
                    lua.execute(f"fire('PARTY_KILL', '{actor}', victim)")
                lua.execute("units.target.dead=true; fire('UNIT_DIED', victim); fire('UNIT_LOOT', victim, true); fire('PLAYER_XP_UPDATE','player'); tick()")
                self.assertEqual(lua.eval('kills()'), 1)
                self.assertEqual(lua.eval('points()'), 1)

    def test_pet_party_raid_and_low_level_kills_without_party_kill_or_loot(self):
        for role in ['pet', 'party1', 'partypet1', 'raid1', 'raidpet1']:
            for level in [1, 5, 60]:
                for denied in [False, True]:
                    with self.subTest(role=role, level=level, denied=denied):
                        lua = new_client()
                        lua.execute(f"""
                            actorUnits.{role}='Pet-0-1-2-3-9-abc'
                            victim=beginKill('eligible')
                            units.target.level={level}; units.target.denied={str(denied).lower()}
                            -- No PARTY_KILL, XP or loot events. Loot APIs throw.
                            units.target.dead=true
                            fire('UNIT_DIED', victim); tick(); tick()
                            fire('UNIT_DIED', victim)
                        """)
                        self.assertEqual(lua.eval('kills()'), 0 if denied else 1)

    def test_pet_capture_target_clears_and_corpse_supplies_tag_eligibility(self):
        lua = new_client()
        lua.execute(r'''
            -- Reproduce build 70009: pet finish, no PARTY_KILL, target clears,
            -- then matching mouseover exposes the eligible corpse.
            victim=beginKill('pet'); corpse=units.target
            units.target=nil
            fire('UNIT_DIED', victim)
            assert(kills()==0, 'death alone cannot infer an unreadable tag')
            fire('UNIT_LOOT', victim, true)
            assert(kills()==0, 'actual drops do not establish tag eligibility')
            corpse.dead=true; corpse.combat=false; units.mouseover=corpse
            fire('UPDATE_MOUSEOVER_UNIT'); tick()
            assert(kills()==1)
            units.target=corpse; fire('PLAYER_TARGET_CHANGED')
            fire('PARTY_KILL', secret, victim); fire('UNIT_DIED',victim); tick()
            assert(kills()==1, 'late events and corpse inspection cannot duplicate')
        ''')

    def test_no_event_pet_kills_cross_crown_milestone_and_survive_reload(self):
        lua = new_client()
        lua.execute(r'''
            for i=1,49 do beginKill('old'..i); finishKill() end
            assert(kills()==49 and points()==4)
            for i=50,51 do
                victim=beginKill('pet'..i)
                units.target.dead=true; units.target.combat=false
                fire('UNIT_DIED',victim); tick(); fire('UNIT_DIED',victim)
            end
            assert(kills()==51 and points()==7)
            fire('ADDON_LOADED','AzerothFieldbook'); tick(); fire('UNIT_DIED',victim)
            assert(kills()==51 and points()==7)
        ''')
        self.assertEqual(lua.eval('output()').count('50 kills!!!'), 1)

    def test_own_or_party_finisher_cannot_steal_another_players_tap(self):
        for actor in ['player', 'party1']:
            with self.subTest(actor=actor):
                lua = new_client()
                lua.execute("actorUnits.party1='Player-2-1'; beginKill('denied'); units.target.denied=true")
                lua.execute(f"finishKill(UnitGUID('{actor}')); units.target.denied=false; tick()")
                self.assertEqual(lua.eval('kills()'), 0, 'late cleared denial must not undo a rejection')
                self.assertNotIn('star', lua.eval('output()'))

    def test_locked_entry_milestones_and_announcements(self):
        lua = new_client()
        lua.execute(r'''
            beginKill('one'); finishKill()
            entry=AzerothFieldbookDB.bestiary.entries[42]
            entry.confirmed=true
            beginKill('two'); units.target.name='Changed name'; finishKill()
            for i=3,9 do beginKill('spawn'..i); finishKill() end
            assert(points()==1 and not output():find('10 kills!',1,true), 'no silver before 10 kills')
            beginKill('silver'); finishKill()
            assert(kills()==10 and points()==2, 'tenth kill awards silver')
            for i=11,24 do beginKill('spawn'..i); finishKill() end
            assert(kills()==24 and points()==2, 'only silver is earned before 25 kills')
            assert(not output():find('25 kills!!',1,true), 'no early gold announcement')
            beginKill('gold'); finishKill()
            beginKill('afterGold'); finishKill()
            for i=27,49 do beginKill('spawn'..i); finishKill() end
            assert(points()==4 and not output():find('50 kills!!!',1,true), 'no crown before 50 kills')
            beginKill('crown'); finishKill()
            beginKill('afterCrown'); finishKill()
        ''')
        self.assertEqual(lua.eval('kills()'), 51)
        self.assertEqual(lua.eval('points()'), 7, 'discovery + silver 1 + gold 2 + crown 3')
        self.assertEqual(lua.eval('entry.name'), 'Test creature')
        self.assertEqual(lua.eval('output()').count('10 kills!'), 1)
        self.assertEqual(lua.eval('output()').count('25 kills!!'), 1)
        self.assertEqual(lua.eval('output()').count('50 kills!!!'), 1)

    def test_existing_crown_credit_is_added_once_and_survives_deletion(self):
        lua = new_client()
        lua.execute(r'''
            for i=1,50 do beginKill('old'..i); finishKill() end
            local ledger=AzerothFieldbookDB.bestiary.points
            ledger.credits[42].killPoints=3; ledger.earned=4; ledger.spent=2
            for i=1,3 do fire('ADDON_LOADED','AzerothFieldbook') end
            assert(kills()==50 and points()==7 and ledger.credits[42].killPoints==6)
            assert(ledger.spent==2, 'existing spending is preserved')
            -- Deleting and earning the same tiers again cannot pay again.
            AzerothFieldbookDB.bestiary.entries[42]=nil
            for i=1,50 do beginKill('new'..i); finishKill() end
            assert(points()==7 and kills()==50)
        ''')

    def test_old_silver_credit_is_preserved_without_paying_again_at_ten(self):
        lua = new_client()
        lua.execute(r'''
            for i=1,2 do beginKill('old'..i); finishKill() end
            local ledger=AzerothFieldbookDB.bestiary.points
            ledger.credits[42].killPoints=1; ledger.earned=2
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(kills()==2 and points()==2)
            messages={}
            for i=3,10 do beginKill('new'..i); finishKill() end
            assert(points()==2 and not output():find('10 kills!',1,true))
        ''')

    def test_eligibility_absent_error_nil_secret_invalid_remains_unknown(self):
        for query in ['nil', "function() error('PRIVATE') end", 'function() return nil end',
                      'function() return secret end', 'function() return 0 end']:
            with self.subTest(query=query):
                lua = new_client()
                lua.execute(f"beginKill('unknown'); UnitIsTapDenied={query}; finishKill()")
                self.assertEqual(lua.eval('kills()'), 0)
                lua.execute('UnitIsTapDenied=function() return false end; tick(); tick()')
                self.assertEqual(lua.eval('kills()'), 1, 'late readable eligibility completes once')

    def test_secret_identity_and_death_fail_closed_but_attacker_is_not_required(self):
        lua = new_client()
        lua.execute(r'''
            victim=beginKill('secret')
            fire('PARTY_KILL', secret, victim)
            fire('PARTY_KILL', UnitGUID('player'), secret)
            fire('UNIT_DIED', secret)
            units.target.dead=secret; tick()
            assert(kills()==0)
            units.target.dead=true
            fire('UNIT_DIED', victim)
            assert(kills()==1, 'readable death and tag eligibility need no attacker')
            fire('PARTY_KILL', UnitGUID('player'), victim)
        ''')
        self.assertEqual(lua.eval('kills()'), 1)

    def test_missing_party_kill_does_not_block_an_observed_eligible_death(self):
        lua = new_client()
        lua.execute("frames[1].events.PARTY_KILL=nil; beginKill('noevent'); finishKill()")
        self.assertEqual(lua.eval('kills()'), 1)

    def test_watched_death_without_either_notification_uses_tag_eligibility(self):
        for denied in [False, True]:
            with self.subTest(denied=denied):
                lua = new_client()
                lua.execute(f"""
                    beginKill('polled')
                    units.target.denied={str(denied).lower()}
                    units.target.dead=true; units.target.combat=false
                    tick(); tick()
                """)
                self.assertEqual(lua.eval('kills()'), 0 if denied else 1)

    def test_corpse_first_inspection_never_counts_even_when_tag_is_eligible(self):
        lua = new_client()
        lua.execute(r'''
            units.target=spawn('oldcorpse',true)
            fire('PLAYER_TARGET_CHANGED'); tick()
            fire('UNIT_DIED',units.target.guid); tick()
        ''')
        self.assertEqual(lua.eval('kills()'), 0)

    def test_death_before_credit_completes_without_current_target(self):
        lua = new_client()
        lua.execute(r'''
            victim=beginKill('late')
            units.target.dead=true
            fire('UNIT_DIED', victim)
            assert(kills()==1, 'eligible death counts before optional PARTY_KILL')
            units.target=nil
            clock=1
            fire('PARTY_KILL', UnitGUID('player'), victim)
            fire('PARTY_KILL', UnitGUID('player'), victim)
        ''')
        self.assertEqual(lua.eval('kills()'), 1)

    def test_token_change_never_moves_evidence_between_guids(self):
        lua = new_client()
        lua.execute(r'''
            first=beginKill('A')
            second=beginKill('B')
            fire('PARTY_KILL', UnitGUID('player'), first)
            fire('UNIT_DIED', first)
            assert(kills()==0, 'B cannot supply A eligibility')
            finishKill()
            assert(kills()==1)
            units.mouseover=spawn('A',true)
            fire('UPDATE_MOUSEOVER_UNIT'); tick()
            assert(kills()==2, 'late eligibility is still tied to A')
            tick(); fire('UNIT_DIED', first)
        ''')
        self.assertEqual(lua.eval('kills()'), 2)

    def test_reset_and_pending_expiry_do_not_reuse_terminal_evidence(self):
        for reset in [True, False]:
            with self.subTest(reset=reset):
                lua = new_client()
                lua.execute("victim=beginKill('stale'); fire('PARTY_KILL',UnitGUID('player'),victim)")
                if reset:
                    lua.execute("units.target.combat=false; fire('PLAYER_TARGET_CHANGED')")
                    lua.execute('UnitIsTapDenied=function() return nil end')
                else:
                    lua.execute('clock=11')
                lua.execute("units.target.dead=true; fire('UNIT_DIED',victim); tick()")
                self.assertEqual(lua.eval('kills()'), 0)

    def test_reload_rehover_and_repeated_loading_preserve_existing_points(self):
        lua = new_client()
        lua.execute(r'''
            beginKill('savedFirst'); finishKill()
            victim=beginKill('saved'); finishKill()
            saved=AzerothFieldbookDB
            saved.bestiary.points.spent=1
            saved.bestiary.entries[42].notes='Keep my notes'
            for i=1,3 do
                fire('ADDON_LOADED','AzerothFieldbook')
                tick(); fire('PARTY_KILL',UnitGUID('player'),victim); fire('UNIT_DIED',victim)
            end
        ''')
        self.assertTrue(lua.eval('saved==AzerothFieldbookDB'))
        self.assertEqual(lua.eval('kills()'), 2)
        self.assertEqual(lua.eval('points()'), 1)
        self.assertEqual(lua.eval('saved.bestiary.points.spent'), 1)
        self.assertEqual(lua.eval('saved.bestiary.entries[42].notes'), 'Keep my notes')
        self.assertEqual(lua.eval('#saved.bestiary.recentKills'), 2)
        self.assertEqual(lua.eval('output()').count('10 kills!'), 0)

    def test_bounded_recent_history_does_not_make_old_corpses_credit(self):
        lua = new_client()
        lua.execute(r'''
            for i=1,520 do beginKill('spawn'..i); finishKill() end
            assert(#AzerothFieldbookDB.bestiary.recentKills==512)
            assert(#AzerothFieldbookDB.bestiary.points.credits[42].killGUIDs==16)
            fire('ADDON_LOADED','AzerothFieldbook')
            units.target=spawn('spawn1',true)
            fire('PLAYER_TARGET_CHANGED'); tick()
            fire('PARTY_KILL',UnitGUID('player'),units.target.guid)
            fire('UNIT_DIED',units.target.guid)
        ''')
        self.assertEqual(lua.eval('kills()'), 520)
        self.assertEqual(lua.eval('points()'), 7)

    def test_unseen_shared_record_cannot_supply_instance_evidence(self):
        lua = new_client()
        lua.execute(r'''
            -- An entry imported or retained from history is identity, not a
            -- personally observed living instance. Existing sharing suite tests
            -- actual import transactions and point-ledger migration separately.
            AzerothFieldbookDB.bestiary.entries[42]={id=42,kills=0,confirmed=true}
            units.target=spawn('imported',true)
            fire('PARTY_KILL',UnitGUID('player'),units.target.guid)
            fire('UNIT_DIED',units.target.guid)
        ''')
        self.assertEqual(lua.eval('kills()'), 0)

    def test_scan_cannot_take_death_from_a_tokens_new_occupant(self):
        lua = new_client()
        lua.execute(r'''
            victim=beginKill('aliveA')
            fire('PARTY_KILL',UnitGUID('player'),victim)
            local oldDead=UnitIsDead
            UnitIsDead=function(unit)
                units.target=spawn('deadB',true)
                return true
            end
            fire('UNIT_HEALTH','target')
            UnitIsDead=oldDead
            assert(kills()==0, 'B death must never finish A record')
            fire('UNIT_DIED',victim)
        ''')
        self.assertEqual(lua.eval('kills()'), 1, 'only a death for A completes it')

    def test_instance_capacity_age_and_world_change_fail_closed(self):
        for expired in ['capacity', 'age', 'world']:
            with self.subTest(expired=expired):
                lua = new_client()
                lua.execute("first=beginKill('old'); units.target=nil")
                if expired == 'capacity':
                    lua.execute("for i=1,64 do clock=i; beginKill('new'..i) end")
                elif expired == 'age':
                    lua.execute('clock=121')
                else:
                    lua.execute("fire('PLAYER_ENTERING_WORLD')")
                lua.execute("units.target=spawn('old',true); fire('PARTY_KILL',UnitGUID('player'),first); fire('UNIT_DIED',first); tick()")
                self.assertEqual(lua.eval('kills()'), 0)


if __name__ == '__main__':
    unittest.main()
