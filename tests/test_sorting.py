"""Creature sorting uses effective displayed levels and stable, reversible ordering."""
import unittest
from kill_test_harness import ROOT, LuaRuntime


class SortingTests(unittest.TestCase):
    def test_sort_orders_filters_unknown_levels_and_saved_preference(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        lua.execute('ns={};db={}')
        for filename in ['SharingReport.lua', 'BestiaryJournal.lua']:
            lua.execute((ROOT / filename).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute('''
            local j=ns.CreateBestiaryJournal(db,function() end)
            for id,name in ipairs({'zebra','Alpha','beta','Alpha'}) do
                local e=j:Ensure(id,true,name);e.category='Beast'
                e.kills=({2,10,0,10})[id]
                e.levelMin=({5,8,3})[id];e.levelMax=({9,10,15})[id]
            end
            local function ids(rows)
                local values={};for _,row in ipairs(rows) do values[#values+1]=row.id end
                return table.concat(values,',')
            end
            local field,descending=j:GetListSort();assert(field=='name' and not descending)
            assert(ids(j:List())=='2,4,3,1')
            j:SetListSort('name',true);assert(ids(j:List())=='1,3,2,4')
            j:SetListSort('kills',false);assert(ids(j:List())=='3,1,2,4')
            j:SetListSort('kills',true);assert(ids(j:List())=='2,4,1,3')
            j:SetListSort('maxLevel',false);assert(ids(j:List())=='1,2,3,4')
            j:SetListSort('maxLevel',true);assert(ids(j:List())=='3,2,1,4')
            j:SetListSort('minLevel',false);assert(ids(j:List())=='3,1,2,4')
            j:SetListSort('minLevel',true);assert(ids(j:List())=='2,1,3,4')
            assert(ids(j:List(nil,'alpha'))=='2,4')
            assert(ids(j:List(nil,'',false,'A'))=='2,4')
            j.entries[1].sharedReports={{name='zebra',category='Beast',levelMin=1,levelMax=50,locations={}}}
            j:SetListSort('maxLevel',true);assert(ids(j:List())=='1,3,2,4')
            local reload=ns.CreateBestiaryJournal(db,function() end)
            field,descending=reload:GetListSort();assert(field=='maxLevel' and descending)
            assert(ids(reload:List())=='1,3,2,4')
            j.entries[1].firstEncounteredAt=300
            j.entries[2].firstEncounteredAt=100
            j.entries[3].firstEncounteredAt=200
            j:SetListSort('firstEncountered',false);assert(ids(j:List())=='2,3,1,4')
            j:SetListSort('firstEncountered',true);assert(ids(j:List())=='1,3,2,4')
            reload=ns.CreateBestiaryJournal(db,function() end)
            field,descending=reload:GetListSort();assert(field=='firstEncountered' and descending)
            assert(not j:SetListSort('invalid',true))
            db.listSort='invalid';db.listSortDescending=false
            assert(j:GetListSort()=='name')
        ''')


if __name__ == '__main__':
    unittest.main()
