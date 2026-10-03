"""Flight observation gates and client-authoritative level/Knowledge rules."""
import unittest
from kill_test_harness import new_client


def client():
    lua = new_client()
    lua.execute('''
        local create=ns.CreateBestiaryJournal
        ns.CreateBestiaryJournal=function(...)
            journal=create(...);return journal
        end
        fire('ADDON_LOADED','AzerothFieldbook')
        taxi,flying=false,false
        function UnitOnTaxi() return taxi end
        function IsFlying() return flying end
        function UnitEffectiveLevel(unit) return units[unit].effective end
        zone='Elwynn Forest'
        function GetRealZoneText() return zone end
        function mob(level)
            local unit=spawn('discovery',false)
            unit.level=60;unit.effective=level
            return unit
        end
    ''')
    return lua


class DiscoveryRules(unittest.TestCase):
    def test_instance_observations_and_kills_do_not_require_a_map(self):
        for kind in ('party', 'raid'):
            for token,event in (('target','PLAYER_TARGET_CHANGED'),('mouseover','UPDATE_MOUSEOVER_UNIT')):
                with self.subTest(kind=kind,token=token):
                    lua=client()
                    from kill_test_harness import ROOT
                    lua.execute((ROOT/'CreatureLocations.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
                    lua.globals().instanceKind=kind
                    lua.globals().watchedToken=token
                    lua.globals().observedEvent=event
                    lua.execute(r'''
                        function IsInInstance() return true,instanceKind end
                        function GetInstanceInfo() return 'The Hall of Thanes',instanceKind end
                        function GetRealZoneText() return 'The Hall of Thanes' end
                        function GetSubZoneText() return '' end
                        C_Map={GetBestMapForUnit=function() return nil end}
                        units[watchedToken]=mob(17)
                        fire('PLAYER_ENTERING_WORLD');fire(observedEvent)
                        local e=journal.entries[42]
                        assert(e and e.levelMin==17 and e.locations['The Hall of Thanes'])
                        assert(not e.observationLocations and not e.killLocations)
                        units[watchedToken].combat=true;tick()
                        fire('PARTY_KILL',UnitGUID('player'),units[watchedToken].guid)
                        units[watchedToken].dead=true
                        fire('UNIT_DIED',units[watchedToken].guid);tick()
                        assert(e.kills==1 and points()==1 and not e.killLocations)
                    ''')

    def test_airborne_mouseover_excluded_target_allowed(self):
        for state in ['taxi=true', 'flying=true', 'taxi=secret', 'flying=secret']:
            with self.subTest(state=state):
                lua = client()
                lua.execute(state)
                lua.execute('''
                    units.mouseover=mob(5)
                    fire('UPDATE_MOUSEOVER_UNIT');tick()
                    assert(not journal.entries[42] and points()==0)
                    units.target=units.mouseover
                    fire('PLAYER_TARGET_CHANGED')
                    assert(journal.entries[42].levelMin==5 and points()==0)
                ''')

    def test_landing_resumes_mouseover_without_retargeting(self):
        lua = client()
        lua.execute('''
            taxi=true;units.mouseover=mob(5);tick()
            assert(not journal.entries[42])
            taxi=false;tick()
            assert(journal.entries[42].levelMax==5 and points()==0)
        ''')

    def test_unknown_levels_defer_points_and_never_use_raw_level(self):
        for level in ['-1', '0', 'nil', 'secret']:
            with self.subTest(level=level):
                lua = client()
                lua.execute(f'units.target=mob({level})')
                lua.execute('''
                    fire('PLAYER_TARGET_CHANGED')
                    assert(journal.entries[42] and not journal.entries[42].levelMin)
                    assert(points()==0)
                    zone='Westfall';tick();assert(points()==0)
                    fire('ADDON_LOADED','AzerothFieldbook');assert(points()==0)
                    units.target.effective=12;tick()
                    assert(points()==0 and journal.entries[42].levelMin==12)
                    tick();assert(points()==0)
                    zone='Redridge';tick();assert(points()==0)
                    units.target.effective=-1;zone='Duskwood';tick()
                    assert(points()==0 and journal.entries[42].levelMax==12)
                    units.target.effective=13;tick()
                    assert(points()==0 and journal.entries[42].levelMax==13)
                ''')

    def test_effective_level_failure_does_not_fall_back(self):
        lua = client()
        lua.execute('''
            function UnitEffectiveLevel() error('unavailable') end
            units.target=mob(5);fire('PLAYER_TARGET_CHANGED')
            assert(not journal.entries[42].levelMin and points()==0)
        ''')

    def test_locked_placeholder_acquires_first_level_only(self):
        lua = client()
        lua.execute('''
            units.target=mob(-1);fire('PLAYER_TARGET_CHANGED')
            journal:SetEntryConfirmed(42,true)
            journal.entries[42].lockedBasic={name='Test creature'}
            units.target.effective=12;tick()
            assert(journal.entries[42].levelMin==12 and points()==0)
            assert(journal.entries[42].lockedBasic.levelMin==12)
            units.target.effective=13;tick()
            assert(journal.entries[42].levelMax==12 and points()==0)
        ''')

    def test_skull_ui_and_help(self):
        from ui_test_harness import new_ui_client
        lua = new_ui_client(modules=['Scrollbars.lua', 'ActionButtons.lua',
            'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua',
            'SharingReport.lua', 'BestiaryJournal.lua', 'FieldbookShell.lua',
            'BestiaryPages.lua', 'BestiaryBook.lua'])
        lua.execute('''
            function UnitEffectiveLevel() return -1 end
            local j=ns.CreateBestiaryJournal({},function() return 42 end)
            local book=ns.CreateBestiaryBook(j)
            book:OpenAtUnit('target')
            local function hasText(needle)
                for _,o in ipairs(objects) do
                    if type(o.text)=='string' and o.text:find(needle,1,true) then return true end
                end
            end
            assert(hasText('Level Range: |TInterface'))
            assert(hasText('UI-TargetingFrame-Skull:18:18:0:2|t'))
            local content=AzerothFieldbookBestiarySection
            local row=content.rows[1]
            assert(row.skullMark:IsShown() and not row.unknownMark:IsShown() and not row.killReward:IsShown())
            j.entries[42].kills=50;j:Touch();book:Refresh()
            assert(row.skullMark:IsShown() and not row.killReward:IsShown(),'skull occupies the reward slot')
            assert(hasText('While flying, including flight paths'))
            assert(hasText('Qualifying kills earn knowledge even at an unknown/skull level'))
            function UnitEffectiveLevel() return 12 end
            book:OpenAtUnit('target')
            assert(hasText('Level Range: 12'))
            assert(not row.skullMark:IsShown() and row.killReward:IsShown(),'readable level restores the earned crown')
        ''')

    def test_kills_pay_without_level_and_do_not_repeat(self):
        lua = client()
        lua.execute('''
            for i=1,10 do
                beginKill('skull'..i)
                units.target.effective=-1
                finishKill()
            end
            assert(kills()==10 and points()==2)
            fire('ADDON_LOADED','AzerothFieldbook');assert(points()==2)
            units.target=mob(20);fire('PLAYER_TARGET_CHANGED')
            assert(points()==2,'first kill and silver milestone')
            tick();fire('ADDON_LOADED','AzerothFieldbook');tick()
            assert(points()==2,'reload and polls cannot duplicate rewards')
        ''')


if __name__ == '__main__':
    unittest.main()
