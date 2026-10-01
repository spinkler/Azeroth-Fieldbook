"""Model request lifecycle; native appearance rendering still needs WoW."""
import unittest
from ui_test_harness import new_ui_client


class BestiaryModelTests(unittest.TestCase):
    def test_loading_retries_selection_and_encounter_gate(self):
        lua = new_ui_client(['SharingReport.lua', 'BestiaryJournal.lua', 'Scrollbars.lua',
            'ActionButtons.lua', 'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua',
            'FieldbookShell.lua', 'BestiaryPages.lua', 'BestiaryBook.lua'])
        lua.execute('''
            j=ns.CreateBestiaryJournal({},function() return npcID end)
            controller=ns.CreateBestiaryBook(j);controller:OpenAtUnit('target')
            section=AzerothFieldbookBestiarySection
            model=section.model; requests={}; clears=0
            function model:ClearModel()
                assert(self.alpha==0, 'previous appearance must be concealed before clearing')
                clears=clears+1
                self.scene=nil
            end
            function model:SetCreature(id)
                assert(self:IsShown(), 'load requested while hidden')
                requests[#requests+1]=id
                self.scene=id
                if #requests==1 then error('transient load failure') end
                if complete then self.scripts.OnModelLoaded(self) end
            end
            controller:OpenAtUnit('target')
            assert(#requests==1 and section.modelPending)
            assert(model.alpha==0)
            assert(section.modelCaption:GetText()=='')
            model.scripts.OnUpdate(model,0.25);assert(#requests==1)
            model.scripts.OnUpdate(model,0.25);assert(#requests==2)
            complete=true
            model.scripts.OnUpdate(model,0.5)
            assert(#requests==3 and not section.modelPending)
            assert(model.alpha==1)
            assert(section.modelCaption:GetText()=='')
            model.scripts.OnUpdate(model,5);assert(#requests==3 and clears==1)

            complete=false;requests={}
            controller:OpenAtUnit('target')
            assert(model.alpha==0, 'previous creature remains visible during replacement')
            for i=1,20 do model.scripts.OnUpdate(model,0.5) end
            assert(#requests==4 and section.modelCaption:GetText()=='')
            assert(model.alpha==0)
            -- A new selection replaces the pending request immediately.
            npcID=43;controller:OpenAtUnit('target')
            assert(model.alpha==0)
            model.scripts.OnUpdate(model,0.5)
            assert(requests[#requests]==43)
            j.entries[43].personalEncountered=false;controller:Refresh()
            local count=#requests
            model.scripts.OnUpdate(model,5)
            model.scripts.OnModelLoaded(model)
            assert(#requests==count and not section.modelPending)
            assert(not model:IsShown() and section.modelUnknown:IsShown())
            assert(model.alpha==0)

            -- Cached loads complete synchronously: geometry must already be final.
            local resizes=0
            function model:SetHeight(height)
                assert(not self:IsShown() and self.alpha==0, 'resized a visible model')
                assert(self.scene==nil, 'resized before unloading the outgoing scene')
                self.height=height;resizes=resizes+1
            end
            local borderSetHeight=section.modelBorder.SetHeight
            function section.modelBorder:SetHeight(height)
                assert(model.scene==nil and not model:IsShown(), 'border resized before unloading')
                borderSetHeight(self,height)
            end
            function model:ClearAllPoints()
                assert(not self:IsShown(), 're-anchored a visible model')
            end
            complete=true
            function UnitCreatureType() return 'Beast' end
            npcID=44;controller:OpenAtUnit('target')
            assert(model.height==135 and model.alpha==1 and resizes==1)
            controller:Refresh();controller:Refresh()
            assert(resizes==1)
            function UnitCreatureType() return 'Humanoid' end
            npcID=45;controller:OpenAtUnit('target')
            assert(model.height==164 and model.alpha==1 and resizes==2)
        ''')


if __name__ == '__main__':
    unittest.main()
