"""Level Range delegates colours to Blizzard and refreshes as player level changes."""
import unittest
from ui_test_harness import new_ui_client


def client():
    lua=new_ui_client(['SharingReport.lua','BestiaryJournal.lua','Scrollbars.lua','ActionButtons.lua',
        'WindowFocus.lua','WindowPositions.lua','UIScale.lua','FieldbookShell.lua','BestiaryPages.lua','BestiaryBook.lua'])
    lua.execute('''
        playerLevel=20;calls={}
        function UnitEffectiveLevel(unit) return unit=='player' and playerLevel or 20 end
        -- Native contract fixture: Blizzard owns these thresholds, not addon code.
        function GetCreatureDifficultyColor(level)
            calls[#calls+1]=level
            local delta=level-playerLevel
            if delta>=5 then return {r=1,g=0,b=0}
            elseif delta>=3 then return {r=1,g=0.5,b=0}
            elseif delta>=-4 then return {r=1,g=1,b=0}
            elseif -delta<=5 then return {r=0,g=1,b=0}
            else return {r=0.5,g=0.5,b=0.5} end
        end
        j=ns.CreateBestiaryJournal({},function() return 42 end)
        book=ns.CreateBestiaryBook(j);book:OpenAtUnit('target')
        section=AzerothFieldbookBestiarySection;e=j.entries[42]
        function summary()
            local text='';for _,row in ipairs(section.summaryBasicRows) do
                if row:IsShown() then text=text..row.text end
            end;return text
        end
    ''')
    return lua


class LevelDifficultyTests(unittest.TestCase):
    def test_native_bands_and_independent_range_endpoints(self):
        lua=client()
        lua.execute('''
            for _,case in ipairs({{14,'808080'},{15,'00ff00'},{16,'ffff00'},
                {22,'ffff00'},{23,'ff8000'},{24,'ff8000'},{25,'ff0000'}}) do
                e.levelMin=case[1];e.levelMax=case[1];calls={};book:Refresh()
                assert(summary():find('Level Range: |cff'..case[2]..case[1]..'|r',1,true))
                assert(#calls==1 and calls[1]==case[1])
            end
            e.levelMin=14;e.levelMax=25;calls={};book:Refresh()
            assert(summary():find('Level Range: |cff80808014|r-|cffff000025|r',1,true))
            assert(#calls==2 and calls[1]==14 and calls[2]==25)
        ''')

    def test_player_level_change_refreshes_locked_entry_without_journal_mutation(self):
        lua=client()
        lua.execute('''
            e.levelMin=25;e.levelMax=25;j:SetEntryConfirmed(42,true);book:Refresh()
            section.scripts.OnUpdate(section,0.5)
            local revision=j.revision;local snapshot=e.lockedBasic
            playerLevel=21;section.scripts.OnUpdate(section,0.5)
            assert(summary():find('|cffff800025|r',1,true))
            assert(e.confirmed and e.lockedBasic==snapshot and j.revision==revision)
            playerLevel=30;section.scripts.OnUpdate(section,0.5)
            assert(summary():find('|cff00ff0025|r',1,true))
            playerLevel=31;section.scripts.OnUpdate(section,0.5)
            assert(summary():find('|cff80808025|r',1,true))
        ''')

    def test_missing_restricted_or_failed_colour_api_preserves_readable_levels(self):
        lua=client()
        lua.execute('''
            e.levelMin=20;e.levelMax=20
            for _,value in ipairs({secret,{r=secret,g=1,b=1},{r=1,g=0/0,b=1},
                {r=1,g=2,b=1},{r=1,g=1},{r=1,g=1,b=secret},'yellow'}) do
                GetCreatureDifficultyColor=function() return value end
                book:Refresh();assert(summary():find('Level Range: 20',1,true))
            end
            GetCreatureDifficultyColor=function() error('unavailable') end
            book:Refresh();assert(summary():find('Level Range: 20',1,true))
            GetCreatureDifficultyColor=nil;book:Refresh()
            assert(summary():find('Level Range: 20',1,true))
            DifficultyUtil={GetCreatureDifficultyColor=function() return {r=1,g=1,b=0} end}
            book:Refresh();assert(summary():find('|cffffff0020|r',1,true))
            UnitEffectiveLevel=function() return secret end
            section.scripts.OnUpdate(section,0.5)
        ''')


if __name__=='__main__':
    unittest.main()
