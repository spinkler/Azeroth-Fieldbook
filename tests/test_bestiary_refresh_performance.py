"""Bestiary work stays bounded during scrolling and cold item searches."""
import unittest
from test_zone_colours import client


class BestiaryRefreshTests(unittest.TestCase):
    def test_metadata_is_reused_for_category_and_location_availability(self):
        lua = client()
        lua.execute('''
            for i=1,128 do
                local e=j:Ensure(1000+i,true,string.format('Zebra %03d',i))
                e.category='Beast';e.locations={['Distant zone']=true}
            end
            section.search:SetText('no matching creature')
            local basic=j.GetBasicInfo;local reads=0
            j.GetBasicInfo=function(self,id)
                if id>1000 then reads=reads+1 end
                return basic(self,id)
            end
            book:Refresh()
            print('Bestiary 128 off-page entries: '..reads..' metadata reads per refresh')
            assert(reads==256,'one availability read and one List read per off-page entry')
            assert(section.typeButtons.Beast:IsEnabled())
            local revision=j.revision
            section.search:SetText('Zebra 001')
            assert(section.rows[1].id==1001 and section.rows[2].id==nil)
            section.search:SetText('Zebra 002')
            assert(section.rows[1].id==1002 and section.rows[2].id==nil)
            assert(j.revision==revision,'search changes need no journal revision')
        ''')

    def test_slider_reuses_the_index_until_the_journal_changes(self):
        lua = client()
        lua.execute('''
            for i=1,918 do j:Ensure(1000+i,true,string.format('Zebra %03d',i)) end
            book:Refresh()
            local list,totals=j.List,j.GetTotals
            local lists,totalReads,detailLayouts=0,0,0
            j.List=function(self,...)
                lists=lists+1
                return list(self,...)
            end
            j.GetTotals=function(self)
                totalReads=totalReads+1
                return totals(self)
            end
            local shell=book:GetShell()
            local setSize=shell.SetSectionSize
            shell.SetSectionSize=function(self,...)
                detailLayouts=detailLayouts+1
                return setSize(self,...)
            end
            local slider=section.creatureScrollBar
            local function drag(value)
                slider:SetValue(value)
                slider.scripts.OnValueChanged(slider,value)
            end
            local selectedTitle=section.title:GetText()
            for i=1,120 do
                local offset=i*7
                drag(offset)
                eq(section.rows[1].id,1000+offset)
            end
            drag(901)
            eq(section.rows[18].id,1918,'the last entry remains reachable')
            section.rows[1].scripts.OnMouseWheel(section.rows[1],1)
            eq(slider:GetValue(),898,'wheel and thumb use the same offset')
            eq(section.title:GetText(),selectedTitle,'scrolling preserves the selected creature')
            assert(lists==0 and totalReads==0 and detailLayouts==0,'scrolling only updates visible rows')

            assert(j:DeleteEntry(1918))
            drag(901)
            eq(slider:GetValue(),900,'a changed journal clamps to the new last page')
            eq(section.rows[18].id,1917)
            eq(lists,1,'scrolling refreshes stale rows once')
            section.scripts.OnUpdate(section,0.5)
            eq(lists,1,'the next poll already has the current journal')
        ''')

    def test_cold_loot_search_batches_lookups_and_only_refreshes_for_relevant_items(self):
        lua = client()
        lua.execute('''
            local names,reads,timer={},0,0
            C_Item={GetItemInfo=function(id)
                reads=reads+1
                timer=timer+0.6
                return names[id]
            end}
            for i=1,918 do
                local entry=j:Ensure(1000+i,true,string.format('Zebra %03d',i))
                entry.loot={samples=1,items={[2000+i]={quantity=1,drops=1}}}
            end
            book:Refresh()
            local list,lists=j.List,0
            j.List=function(self,...)
                lists=lists+1
                return list(self,...)
            end
            local function tick(elapsed) section.scripts.OnUpdate(section,elapsed) end
            local function itemLoaded(id,success) section.scripts.OnEvent(section,'GET_ITEM_INFO_RECEIVED',id,success) end
            local revision=j.revision
            section.search:SetText('light leather')
            eq(reads,0,'typing does no native item lookups')
            debugprofilestop=function() return timer end
            tick(1/60)
            eq(reads,2,'expensive native lookups also respect the time budget')
            debugprofilestop=nil
            for _=1,40 do
                local before=reads
                tick(1/60)
                assert(reads-before<=32,'native item lookups are capped per frame')
            end
            eq(reads,918,'each distinct item is looked up once while its name is missing')
            eq(lists,1,'unavailable names do not cause redraws')

            for i=1,40 do itemLoaded(5000+i,true) end
            itemLoaded(2001,false)
            tick(0.5)
            eq(reads,918)
            eq(lists,1,'unrelated or failed events do not refresh the search')

            for i=1,4 do
                names[2000+i]='Light Leather'
                itemLoaded(2000+i,true)
                itemLoaded(2000+i,true)
            end
            eq(reads,918,'the event handler queues results')
            tick(0.1)
            eq(reads,922,'repeated events are deduplicated')
            eq(lists,2,'the four loaded names trigger one list rebuild')
            for i=1,4 do eq(section.rows[i].id,1000+i) end
            eq(section.rows[5].id,nil)
            eq(j.revision,revision,'item metadata does not revise the journal')
            section.search:SetText('LeaTher')
            tick(0.1)
            eq(reads,922,'later keystrokes reuse resolved names')
            eq(section.rows[4].id,1004)
        ''')


if __name__ == '__main__':
    unittest.main()
