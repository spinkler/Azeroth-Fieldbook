"""Announcement wording, colors and deduplication through real addon events."""
import unittest
from kill_test_harness import new_client


PREFIX = '|cff80d0ffAzeroth Fieldbook:|r '


def announcement(title, details, points=1):
    reward = '' if points is None else f'+{points} knowledge: '
    return f'{PREFIX}|cffffd100[{reward}{title}]|r Bestiary: Forest Lurker |cff999999({details})|r'


class AnnouncementTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_client()
        self.lua.execute('''
            local originalSpawn=spawn
            function spawn(...)
                local creature=originalSpawn(...)
                creature.name='Forest Lurker'; creature.level=11
                return creature
            end
            zone='Loch Modan'
            function GetRealZoneText() return zone end
            messages={}
            function observe()
                units.target=units.target or spawn('first',false)
                fire('PLAYER_TARGET_CHANGED')
            end
        ''')

    def messages(self):
        return list(self.lua.globals().messages.values())

    def test_single_discovery_has_exact_wording_and_colors(self):
        self.lua.execute('observe(); observe(); tick()')
        self.assertEqual(self.messages(), [announcement('New discovery!', 'Beast • Lvl11 • Loch Modan')])

    def test_level_and_location_use_current_observation_even_when_locked(self):
        self.lua.execute('''
            observe(); messages={}
            AzerothFieldbookDB.bestiary.entries[42].confirmed=true
            units.target.level=10; observe(); observe()
            zone='The Twisting Nether'; observe(); observe()
        ''')
        self.assertEqual(self.messages(), [
            announcement('New observed location', 'Beast • Lvl10 • The Twisting Nether'),
        ])
        self.assertEqual(self.lua.eval('AzerothFieldbookDB.bestiary.entries[42].levelMin'), 11)

    def test_level_and_location_together_keep_one_point(self):
        self.lua.execute("observe(); messages={}; units.target.level=10; zone='The Twisting Nether'; observe()")
        self.assertEqual(self.messages(), [
            announcement('New observed location', 'Beast • Lvl10 • The Twisting Nether')
        ])
        self.assertEqual(self.lua.eval('points()'), 2)

    def test_levels_update_without_rewards_and_preserve_old_balances(self):
        self.lua.execute('''
            observe();messages={}
            local ledger=AzerothFieldbookDB.bestiary.points
            -- Simulate an already-earned level reward from an earlier release.
            ledger.earned=ledger.earned+1;ledger.credits[42].points=1
            ledger.credits[42].levels[12]=true
            for level=10,15 do units.target.level=level;observe() end
            assert(points()==2 and #messages==0)
            local entry=AzerothFieldbookDB.bestiary.entries[42]
            assert(entry.levelMin==10 and entry.levelMax==15)
            fire('ADDON_LOADED','AzerothFieldbook')
            units.target.level=16;observe()
            assert(points()==2 and #messages==0)
            zone='New place';observe();observe()
            assert(points()==3 and #messages==1)
        ''')

    def test_kill_milestones_have_exact_punctuation_and_no_level_or_zone(self):
        self.lua.execute("for i=1,51 do beginKill('kill'..i); finishKill() end")
        self.assertEqual(self.messages(), [
            announcement('New discovery!', 'Beast • Lvl11 • Loch Modan'),
            announcement('10 kills!', 'Beast'),
            announcement('25 kills!!', 'Beast', 2),
            announcement('50 kills!!!', 'Beast', 3),
        ])

    def test_both_announcement_settings_remain_effective(self):
        for points in (True, False):
            for discoveries in (True, False):
                with self.subTest(points=points, discoveries=discoveries):
                    self.setUp()
                    settings = self.lua.globals().AzerothFieldbookDB
                    settings.pointAnnouncements = points
                    settings.creatureAnnouncements = discoveries
                    self.lua.execute('observe(); observe()')
                    expected = [announcement('New discovery!', 'Beast • Lvl11 • Loch Modan', 1 if points else None)] if points or discoveries else []
                    self.assertEqual(self.messages(), expected)
                    self.lua.execute("messages={}; units.target.level=10; zone='New location'; observe()")
                    self.assertEqual(len(self.messages()), 1 if points else 0)
                    self.assertEqual(self.lua.eval('#AzerothFieldbookDB.eventLog.entries'), 2)
                    self.assertEqual(self.lua.eval('AzerothFieldbookDB.eventLog.entries[1].details.points'), 1)

    def test_log_survives_reload_and_bestiary_reset_without_replaying(self):
        self.lua.execute('''
            AzerothFieldbookDB.pointAnnouncements=false
            AzerothFieldbookDB.creatureAnnouncements=false
            observe()
            local log=AzerothFieldbookDB.eventLog
            fire('ADDON_LOADED','AzerothFieldbook')
            observe()
            assert(AzerothFieldbookDB.eventLog==log and #log.entries==1)
            SlashCmdList.AZEROTHFIELDBOOK('wipe')
            SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
            assert(AzerothFieldbookDB.eventLog==log and #log.entries==1)
        ''')

    def test_unresolved_names_are_silent_and_repair_announces_once(self):
        self.lua.execute('''
            units.target=spawn('unreadable',false)
            UNKNOWNOBJECT='Unknown'
            for _,name in ipairs({secret,'','Unknown','Creature #1195','Encountered creature #1195'}) do
                units.target.name=name; observe()
            end
        ''')
        self.assertEqual(self.messages(), [])
        self.lua.execute("units.target.name='Forest Lurker'; observe()")
        self.assertEqual(self.messages(), [announcement('New discovery!', 'Beast • Lvl11 • Loch Modan')])

    def test_unreadable_details_are_not_invented_or_stringified(self):
        self.lua.execute('''
            function UnitCreatureType() return secret end
            zone=secret; units.target=spawn('hidden',false); units.target.level=secret
            observe()
        ''')
        self.assertEqual(self.messages(), [announcement('New discovery!', 'Unclassified')])


    def test_deleted_creature_returns_on_hover_without_duplicate_knowledge(self):
        self.lua.execute('''
            local create=ns.CreateBestiaryJournal
            ns.CreateBestiaryJournal=function(...)
                activeJournal=create(...);return activeJournal
            end
            fire('ADDON_LOADED','AzerothFieldbook')
            units.mouseover=spawn('same-mob',false)
            fire('UPDATE_MOUSEOVER_UNIT')
            local original=activeJournal.entries[42]
            local before=points()
            assert(before==1 and original.sightings==1)
            assert(activeJournal:DeleteEntry(42))
            assert(not activeJournal.entries[42])
            messages={}
            fire('UPDATE_MOUSEOVER_UNIT')
            local restored=activeJournal.entries[42]
            assert(restored and restored~=original and restored.sightings==1)
            assert(points()==before and #messages==1)
            assert(messages[1]:find('Entry restored',1,true) and not messages[1]:find('+1 knowledge',1,true))
            fire('UPDATE_MOUSEOVER_UNIT');tick()
            assert(points()==before and #messages==1,'repeat hover does not announce or award twice')
            activeJournal:DeleteEntry(42)
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(not activeJournal.entries[42],'reload alone keeps the entry deleted')
            fire('UPDATE_MOUSEOVER_UNIT')
            assert(activeJournal.entries[42] and points()==before)
            -- Levels are recorded without rewards; new locations still earn once.
            units.mouseover.level=12;fire('UPDATE_MOUSEOVER_UNIT')
            assert(points()==before and activeJournal.entries[42].levelMax==12)
            zone='New location';fire('UPDATE_MOUSEOVER_UNIT')
            assert(points()==before+1)
            for i=1,50 do beginKill('credited'..i);finishKill() end
            local milestoneBalance=points()
            assert(milestoneBalance==before+7)
            activeJournal:DeleteEntry(42)
            for i=1,50 do beginKill('after-delete'..i);finishKill() end
            assert(points()==milestoneBalance,'previously credited kill milestones survive deletion')
        ''')

    def test_sharing_waiver_notifies_sender_with_actual_cost(self):
        self.lua.execute('''
            ns.InitializeSharing=function(journal)
                journal.sharing={
                    SetImportedCallback=function() end,
                    SetCostAdjustedCallback=function(_,callback) costAdjusted=callback end,
                }
            end
            fire('ADDON_LOADED','AzerothFieldbook')
            messages={}
            costAdjusted({recipient='Bob Stonewell',cost=2})
        ''')
        self.assertEqual(self.messages(), [
            f'{PREFIX}|cffffd100[1 knowledge saved]|r Bob Stonewell already has this creature\'s basic information; '
            'its cost was waived. Charged 2 knowledge.'
        ])


if __name__ == '__main__':
    unittest.main()
