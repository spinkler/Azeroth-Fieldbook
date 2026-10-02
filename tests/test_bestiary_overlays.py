"""Overlay lifecycle with ancestor visibility events, including hidden-child Hide."""
import unittest
from ui_test_harness import new_ui_client
from test_locations import MAP_API


class BestiaryOverlayTests(unittest.TestCase):
    def test_close_reopen_restores_content_and_exclusive_pickers(self):
        for children_first in (False, True):
            with self.subTest(children_first=children_first):
                lua = new_ui_client([
                    'CreatureLocations.lua', 'LocationGeometry.lua',
                    'CreatureLocationsWindow.lua',
                    'SharingReport.lua', 'BestiaryJournal.lua', 'Scrollbars.lua',
                    'ActionButtons.lua', 'FieldbookShell.lua', 'BestiaryPages.lua',
                    'BestiaryBook.lua'])
                lua.globals().childrenFirst = children_first
                lua.execute(MAP_API)
                lua.execute('''
                    -- Native Show/Hide scripts follow effective visibility;
                    -- Hide on an already invisible child emits no second event.
                    local function setShown(self, shown)
                        local before={}
                        for _,object in ipairs(objects) do before[object]=object:IsVisible() end
                        self.shown=shown
                        local first,last,step=1,#objects,1
                        if childrenFirst then first,last,step=#objects,1,-1 end
                        for i=first,last,step do
                            local object=objects[i]
                            local visible=object:IsVisible()
                            if before[object]~=visible then
                                local script=object.scripts[visible and 'OnShow' or 'OnHide']
                                if script then script(object) end
                            end
                        end
                    end
                    local create=CreateFrame
                    function CreateFrame(...)
                        local frame=create(...)
                        frame.SetShown=setShown
                        function frame:Show() setShown(self,true) end
                        function frame:Hide() setShown(self,false) end
                        return frame
                    end
                    j=ns.CreateBestiaryJournal({},function() return npcID end)
                    controller=ns.CreateBestiaryBook(j)
                    controller:OpenAtUnit('target')
                    section=AzerothFieldbookBestiarySection
                    local pickers={section.offensePicker,section.defensePicker,section.behaviourPicker}
                    local buttons={section.offenseButton,section.defenseButton,section.behaviourButton}
                    for cycle=1,3 do
                        for i,button in ipairs(buttons) do
                            button.scripts.OnClick(button)
                            assert(pickers[i]:IsVisible() and button.afbSelected)
                            assert(not section.abilityPanel:IsVisible())
                            controller:GetShell():Hide()
                            controller:Toggle()
                            assert(section.abilityPanel:IsVisible(), 'base content must return')
                            for k,picker in ipairs(pickers) do
                                assert(not picker:IsShown() and not buttons[k].afbSelected,
                                    'closed overlay must not leave a selected button')
                            end
                        end
                    end
                    for i,button in ipairs(buttons) do
                        button.scripts.OnClick(button)
                        for k,picker in ipairs(pickers) do
                            assert(picker:IsVisible()==(i==k))
                            assert(buttons[k].afbSelected==(i==k))
                        end
                    end
                    local locations=section.creatureLocationsButton
                    locations.scripts.OnClick(locations)
                    assert(AzerothFieldbookCreatureLocations:IsVisible() and locations.afbSelected)
                    local close=controller:GetShell():GetFrame().closeButton
                    close.scripts.OnClick(close)
                    controller:Toggle()
                    assert(not AzerothFieldbookCreatureLocations:IsShown())
                    assert(not locations.afbSelected and section.abilityPanel:IsVisible())
                    locations.scripts.OnClick(locations)
                    assert(AzerothFieldbookCreatureLocations:IsVisible() and locations.afbSelected)
                ''')


if __name__ == '__main__':
    unittest.main()
