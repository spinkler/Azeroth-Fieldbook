"""Selected Bestiary pages remain reachable after navigation and filter clearing."""
import unittest
from test_zone_colours import client


class BestiarySelectionScrollTests(unittest.TestCase):
    def test_direct_opens_and_filter_clearing_reveal_selection(self):
        lua = client()
        lua.execute('''
            for i=1,80 do
                local e=j:Ensure(1000+i,true,string.format('Creature %03d',i))
                e.category='Beast';e.locations={['Distant zone']=true}
            end
            local shell=book:GetShell()
            local function visible(id)
                for _,row in ipairs(section.rows) do
                    if row:IsShown() and row.id==id then return true end
                end
                return false
            end
            shell:ShowSection('bestiary',{creatureID=1070})
            assert(visible(1070),'direct open scrolls down to the page')
            shell:ShowSection('bestiary',{creatureID=1002})
            assert(visible(1002),'direct open scrolls back up')
            section.search:SetText('Creature 070')
            shell:ShowSection('bestiary',{creatureID=1070})
            assert(section.search:GetText()=='Creature 070','matching filters remain')
            section.search:SetText('')
            assert(visible(1070),'erasing search reveals the retained selection')
            section.search:SetText('Creature 070')
            section.searchClear.scripts.OnClick(section.searchClear)
            assert(visible(1070),'search clear button reveals the retained selection')
            section.search:SetText('Creature 070')
            section.listFilterButton.ResetFilters()
            assert(visible(1070),'full filter reset reveals the retained selection')
            section.search:SetText('no match')
            section.typeButtons.Humanoid.scripts.OnClick(section.typeButtons.Humanoid)
            shell:ShowSection('bestiary',{creatureID=1070})
            assert(section.search:GetText()=='' and visible(1070),'direct open clears blocking filters')
            section.creatureScrollBar:SetValue(0)
            section.creatureScrollBar.scripts.OnValueChanged(section.creatureScrollBar,0)
            assert(not visible(1070),'manual scrolling can leave the selected page')
            book:Refresh()
            assert(section.creatureScrollBar:GetValue()==0 and not visible(1070),'routine refresh preserves browsing')
        ''')


if __name__ == '__main__':
    unittest.main()
