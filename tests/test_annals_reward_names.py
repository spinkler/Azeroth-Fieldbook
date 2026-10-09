"""Blank historical reward names must not mask cache lookups or fallback labels."""
import unittest

from annals_test_harness import client
from atlas_test_harness import ENV
from test_player_names_preservation import full_client


class AnnalsRewardNameTests(unittest.TestCase):
    def test_blank_names_use_cache_or_visible_fallback_without_rewriting_history(self):
        l = client(); l.execute('''
            local A=ns.Annals;local queried=0;local ready=false
            C_Item={GetItemInfo=function(id)
                queried=queried+1;assert(id=='item:724:0')
                return ready and 'Redridge Goulash' or '',nil,1,nil,nil,nil,nil,nil,nil,123
            end}
            for _,blank in ipairs({'','   '}) do
                local item={itemID=724,name=blank,quantity=5,link='item:724:0'}
                local before=snapshot(item)
                ready=false
                local name,_,icon,link=A.RewardPresentation(item)
                assert(name=='Item #724' and icon==123 and link=='item:724:0')
                ready=true;assert(A.RewardPresentation(item)=='Redridge Goulash')
                local calls=queried
                assert(A.RewardPresentation(item,true)=='Item #724' and queried==calls)
                assert(snapshot(item)==before,'presentation must not rewrite historical observations')
            end
            assert(A.RewardName(secret)==nil and A.RewardName(5)==nil)
            assert(A.RewardPresentation({itemID=724,name='Recorded name',link='item:724:0'})=='Recorded name')
            C_Spell={GetSpellInfo=function() return {name='',iconID=123} end}
            assert(A.RewardPresentation({spellID=42,name=''})=='Spell #42')
            C_Spell.GetSpellInfo=function() return {name='Readable spell',iconID=123} end
            assert(A.RewardPresentation({spellID=42,name='  '})=='Readable spell')
            assert(A.RewardPresentation({currencyID=1,name=''})=='Currency #1')
        ''')

    def test_screenshot_case_names_refresh_while_icons_counts_and_tooltips_survive(self):
        l = full_client(); l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local j=c.journal;local ready=false;local requests=0
            local names={[724]='Redridge Goulash',[2697]='Recipe: Goretusk Liver Pie'}
            C_Item={GetItemInfo=function(id)
                return ready and names[id] or '',nil,1,nil,nil,nil,nil,nil,nil,123
            end,RequestLoadItemDataByID=function() requests=requests+1 end}
            GameTooltip={IsOwned=function() return false end,SetOwner=function() end,
                SetHyperlink=function(_,link) shownLink=link end,Show=function() end,Hide=function() end}
            local e,id=j:Append('completed','Redridge Goulash',{reward={choiceStatus='none',automatic={
                {itemID=724,name='',icon=123,quality=1,quantity=5},
                {itemID=2697,name='   ',icon=456,quality=1,quantity=1}}}},
                {mapID=101,x=1760,y=4390},100)
            local before=snapshot(e)
            c.shell:ShowSection('annals');c.main.show.scripts.OnClick(c.main.show);c:Select(id)
            local detail=c.main.detail;local rows={}
            for _,row in ipairs(detail.rows) do
                if row.block and row.block.item then rows[row.block.item.itemID]=row end
            end
            assert(rows[724].label:GetText():find('Item #724',1,true))
            assert(rows[724].label:GetText():find('×5',1,true) and rows[724].icon.texture==123)
            assert(rows[2697].label:GetText():find('Item #2697',1,true) and rows[2697].icon.texture==456)
            rows[724].scripts.OnEnter(rows[724]);assert(shownLink=='item:724')
            ready=true;detail.scripts.OnEvent(detail,'GET_ITEM_INFO_RECEIVED',724,true)
            assert(rows[724].label:GetText():find('Redridge Goulash',1,true))
            assert(rows[2697].label:GetText():find('Recipe: Goretusk Liver Pie',1,true))
            assert(not rows[2697].label:GetText():find('×1',1,true))
            rows[2697].scripts.OnEnter(rows[2697]);assert(shownLink=='item:2697')
            assert(snapshot(e)==before and requests==2)
        ''')

    def test_new_capture_treats_blank_names_as_unavailable_then_recovers_readable_names(self):
        l = client(); l.execute('''
            local original=GetQuestItemInfo;local ready=false
            GetQuestItemInfo=function(kind,i)
                local name,icon,count,quality,usable,id=original(kind,i)
                return ready and name or (i==1 and '' or '   '),icon,count,quality,usable,id
            end
            t:Event('QUEST_COMPLETE')
            local first=ns.Annals.RewardSnapshot()
            assert(first.automatic[1].name==nil and first.choices[1].name==nil and first.choices[2].name==nil)
            ready=true;t:Event('QUEST_ITEM_UPDATE');t:RewardRequested(2)
            t:Event('QUEST_TURNED_IN',42,500,100);advance(1)
            assert(db.events[1].reward.chosen.name=='choice item 2')
            assert(db.events[1].reward.automatic[1].name=='reward item 1')
        ''')


if __name__ == '__main__':
    unittest.main()
