"""Bestiary delete view replaces list controls and restores them on cancellation."""
import unittest
from test_zone_colours import client

class DeleteViewTests(unittest.TestCase):
    def test_confirmation_replaces_list_controls_and_restores_on_cancel(self):
        lua=client()
        lua.execute("""
            local main=AzerothFieldbookBestiarySection
            assert(main.beastLore.creature==nil and main.beastLore.area:GetHeight()==194)
            main.deleteButton.scripts.OnClick(main.deleteButton)
            local form=main.deleteForm;form.scripts.OnShow(form)
            assert(form:IsShown() and form.lead:IsShown())
            assert(form.lead.text:find('|cffffff00Creature 42|r',1,true))
            for _,key in ipairs({'search','indexButton','listFilterButton','sortButton','shareButton','deleteButton'}) do
                assert(not main[key]:IsShown(),key..' is replaced while confirming')
            end
            book:Refresh()
            assert(not main.rows[1]:IsShown() and not main.deleteButton:IsShown())
            form.cancel.scripts.OnClick(form.cancel)
            assert(not form:IsShown())
            for _,key in ipairs({'search','indexButton','listFilterButton','sortButton','shareButton','deleteButton'}) do
                assert(main[key]:IsShown(),key..' returns after cancel')
            end
            main.deleteButton.scripts.OnClick(main.deleteButton);form.scripts.OnShow(form)
            form.input:SetText('delete');form.input.scripts.OnEnterPressed(form.input)
            assert(not form:IsShown() and not j.entries[42])
            assert(main.search:IsShown() and main.shareButton:IsShown() and main.deleteButton:IsShown())
        """)

if __name__=='__main__': unittest.main()
