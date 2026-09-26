"""Verified, surname-aware class colours without trusting report identity claims."""
import unittest
from kill_test_harness import ROOT, LuaRuntime


def client():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(r'''
        ns,units,frames={},{},{}
        secret=setmetatable({}, {__tostring=function() error('secret formatted') end,
            __eq=function() error('secret compared') end})
        function issecretvalue(value) return rawequal(value,secret) end
        function UnitIsPlayer(unit) return units[unit] and units[unit].player end
        function UnitNameUnmodified(unit)
            local value=units[unit]
            if value then return value.first,value.surname end
        end
        UnitName=UnitNameUnmodified
        function UnitClass(unit) return 'Localized class',units[unit].class end
        NameUtil={GetFullNameWithoutRealm=function(first,surname)
            return surname and surname~='' and first..' '..surname or first
        end}
        RAID_CLASS_COLORS={MAGE={r=0.25,g=0.78,b=0.92},WARRIOR={r=0.78,g=0.61,b=0.43}}
        function CreateFrame()
            local frame={events={}}
            function frame:RegisterEvent(event) self.events[event]=true end
            function frame:SetScript(event,fn) self[event]=fn end
            frames[#frames+1]=frame;return frame
        end
        function fire(event,unit)
            for _,frame in ipairs(frames) do if frame.events[event] then frame.OnEvent(frame,event,unit) end end
        end
        function grey(name) return '|cff8c9494'..name..'|r' end
    ''')
    for name in ['SharingReport.lua', 'PlayerNames.lua']:
        lua.execute(ROOT.joinpath(name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    return lua


class PlayerNameTests(unittest.TestCase):
    def test_shared_class_survives_reload_and_unknown_source_is_backfilled(self):
        lua = client()
        lua.execute('''
            AzerothFieldbookDB={version=1}
            units.party1={player=true,first='Erna',surname='Lionguard',class='MAGE'}
            ns.PlayerNames:Remember('Erna Lionguard')
            ns.PlayerNames:Remember('Later Player')
            assert(AzerothFieldbookDB.sourceClasses['erna lionguard']=='MAGE')
            assert(AzerothFieldbookDB.sourceClasses['later player']==false)
            units.party1=nil
        ''')
        lua.execute(ROOT.joinpath('PlayerNames.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute('''
            assert(ns.PlayerNames:Format('Erna Lionguard')=='|cff40c7ebErna Lionguard|r')
            assert(ns.PlayerNames:Format('Later Player')==grey('Later Player'))
            units.target={player=true,first='Later',surname='Player',class='WARRIOR'}
            fire('PLAYER_TARGET_CHANGED')
            assert(AzerothFieldbookDB.sourceClasses['later player']=='WARRIOR')
            assert(ns.PlayerNames:Format('Later Player')=='|cffc79c6eLater Player|r')
        ''')

    def test_full_name_player_check_and_session_cache(self):
        lua = client()
        lua.execute('''
            local names=ns.PlayerNames
            assert(names:Format('Erna Lionguard')==grey('Erna Lionguard'))
            units.party1={player=true,first='Erna',surname='Lionguard',class='MAGE'}
            fire('GROUP_ROSTER_UPDATE')
            assert(names:Format('Erna Lionguard')=='|cff40c7ebErna Lionguard|r')
            assert(names:Format('erna lionguard')=='|cff40c7eberna lionguard|r')
            assert(names:Format('Erna')==grey('Erna'),'first names never match a full surname')
            assert(names:Format('Erna Othername')==grey('Erna Othername'))
            local revision=names.revision
            fire('GROUP_ROSTER_UPDATE');assert(names.revision==revision)
            units.party1=nil;fire('GROUP_ROSTER_UPDATE')
            assert(names:Format('Erna Lionguard')=='|cff40c7ebErna Lionguard|r','verified class survives leaving group')
            units.target={player=false,first='Peww',surname='Pewz',class='WARRIOR'}
            fire('PLAYER_TARGET_CHANGED')
            assert(names:Format('Peww Pewz')==grey('Peww Pewz'),'NPC classes are not player evidence')
            units.target.player=true;fire('PLAYER_TARGET_CHANGED')
            assert(names:Format('Peww Pewz')=='|cffc79c6ePeww Pewz|r')
        ''')
        lua.execute(ROOT.joinpath('PlayerNames.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute("assert(ns.PlayerNames:Format('Erna Lionguard')==grey('Erna Lionguard'),'a new session has no saved class guesses')")

    def test_restricted_missing_and_erroring_api_values_stay_grey(self):
        lua = client()
        lua.execute('''
            for _,field in ipairs({'player','first','surname','class'}) do
                units.mouseover={player=true,first='Hidden',surname='Person',class='MAGE'}
                units.mouseover[field]=secret
                fire('UPDATE_MOUSEOVER_UNIT')
                assert(ns.PlayerNames:Format('Hidden Person')==grey('Hidden Person'))
                assert(ns.PlayerNames.revision==0)
            end
            units.mouseover={player=true,first='Hidden',surname='Person',class='MAGE'}
            UnitClass=function() error('identity API unavailable') end
            fire('UPDATE_MOUSEOVER_UNIT')
            assert(ns.PlayerNames.revision==0)
            UnitClass=nil;fire('UPDATE_MOUSEOVER_UNIT')
            assert(ns.PlayerNames.revision==0)
            assert(ns.PlayerNames:Format(secret)=='Unknown player')
        ''')

    def test_name_helper_fallback_and_colour_validation(self):
        lua = client()
        lua.execute('''
            NameUtil=nil
            UnitNameUnmodified=nil
            units.mouseover={player=true,first='Erna',surname='Lionguard',class='MAGE'}
            fire('UPDATE_MOUSEOVER_UNIT')
            assert(ns.PlayerNames:Format('Erna Lionguard')==grey('Erna Lionguard'))
            units.mouseover.first='Erna Lionguard';units.mouseover.surname=nil
            fire('UPDATE_MOUSEOVER_UNIT')
            assert(ns.PlayerNames:Format('Erna Lionguard')=='|cff40c7ebErna Lionguard|r')
            C_ClassColor={GetClassColor=function(class) assert(class=='MAGE');return {r=1,g=0,b=0} end}
            assert(ns.PlayerNames:Format('Erna Lionguard')=='|cffff0000Erna Lionguard|r')
            for _,red in ipairs({secret,-1,2,0/0}) do
                C_ClassColor.GetClassColor=function() return {r=red,g=0,b=0} end
                assert(ns.PlayerNames:Format('Erna Lionguard')==grey('Erna Lionguard'))
            end
            C_ClassColor=nil;RAID_CLASS_COLORS=nil
            assert(ns.PlayerNames:Format('Erna Lionguard')==grey('Erna Lionguard'))
        ''')


if __name__ == '__main__':
    unittest.main()
