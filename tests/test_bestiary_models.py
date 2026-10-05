"""Model request lifecycle; native appearance rendering still needs WoW."""
import unittest
from ui_test_harness import new_ui_client


class BestiaryModelTests(unittest.TestCase):
    def test_portrait_appearance_and_gated_placeholder(self):
        lua = new_ui_client(['SharingReport.lua', 'BestiaryJournal.lua', 'Scrollbars.lua',
            'ActionButtons.lua', 'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua',
            'FieldbookShell.lua', 'BestiaryPages.lua', 'BestiaryBook.lua'])
        lua.execute(r'''
            function SetPortraitTexture(texture,unit) texture.appearance=unit end
            function SetPortraitTextureFromCreatureDisplayID(texture,id) texture.appearance=id end
            j=ns.CreateBestiaryJournal({},function() return npcID end)
            c=ns.CreateBestiaryBook(j);c:OpenAtUnit('target')
            local section=AzerothFieldbookBestiarySection
            assert(section.portrait:IsShown() and not section.portraitUnknown:IsShown())
            assert(section.indexCount:GetText()=='* Unlocked')
            local rumours=j.GetRumours
            function j:GetRumours(id) return id==42 and {{}} or {} end
            c:Refresh()
            assert(section.indexCount:GetText():find('Green',1,true))
            section.search:SetText('No matching creature');c:Refresh()
            assert(section.indexCount:GetText()=='* Unlocked')
            section.search:SetText('');j.GetRumours=rumours;c:Refresh()
            assert(section.confirm.backdrop==nil)
            function section.portraitBorder:SetAtlas(name,useAtlasSize)
                assert(useAtlasSize==true)
                self.atlas=name
                self:SetSize(100,90)
            end
            function section.model:GetDisplayInfo() return 1234 end
            section.model.scripts.OnModelLoaded(section.model)
            assert(section.portrait.appearance==1234)
            j.entries[42].personalEncountered=false
            j.entries[42].rank='Rare Elite'
            c:Refresh()
            assert(section.portraitFrame:IsShown() and section.portraitUnknown:IsShown())
            assert(not section.portrait:IsShown())
            assert(section.portraitBorder.atlas=='UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver')
            assert(section.portraitBorder:IsShown() and section.portraitRings[1]:IsShown())
            assert(section.portraitBorder.texCoord[1]==1 and section.portraitBorder.texCoord[2]==0,
                'mirror the complete atlas, not a second crop of its texture sheet')
            assert(section.portraitBorder.texCoord[3]==0 and section.portraitBorder.texCoord[4]==1)
            section.model.scripts.OnModelLoaded(section.model)
            assert(not section.portrait:IsShown(), 'late model callback revealed gated appearance')
            j.entries[42].personalEncountered=true;j.entries[42].rank='Elite';c:Refresh()
            local pixel=1/section.portraitFrame:GetEffectiveScale()
            assert(math.abs(section.portraitBorder.point[2]-(24+(-15*48/58-10-24)*1.20+pixel))<0.001)
            assert(math.abs(section.portraitBorder.point[3]-(-24+(11*48/58+10+24)*1.20-2*pixel))<0.001)
            local eliteX,eliteY=section.portraitBorder.point[2],section.portraitBorder.point[3]
            assert(section.portrait:IsShown() and not section.portraitUnknown:IsShown())
            assert(section.portraitBorder.atlas=='UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold')
            assert(section.portraitRings[1]:IsShown())
            j.entries[42].rank='World Boss';c:Refresh()
            assert(section.portraitBorder.atlas=='UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged')
            j.entries[42].rank='Rare';c:Refresh()
            assert(section.portraitBorder.atlas=='UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver')
            assert(section.portraitBorder.point[2]==eliteX and section.portraitBorder.point[3]==eliteY)
            local width=section.portraitBorder:GetWidth()
            c:Refresh();c:Refresh()
            assert(section.portraitBorder:GetWidth()==width, 'refresh must not repeatedly shrink the atlas')
            assert(section.portraitBorder.mask==nil, 'native artwork needs no custom mask')
            local circleX,circleY=section.portraitFrame.point[2],section.portraitFrame.point[3]
            for _,rank in ipairs({'Elite','Rare','Rare Elite','World Boss','Normal'}) do
                j.entries[42].rank=rank;c:Refresh()
                assert(section.portraitFrame.point[2]==circleX and section.portraitFrame.point[3]==circleY,
                    'copper circle must stay fixed when dragon artwork changes')
            end
            j.entries[42].rank=nil;c:Refresh()
            assert(not section.portraitBorder:IsShown())
            assert(section.portraitRings[1]:IsShown())
            j.entries[42].personalEncountered=false;c:Refresh()
            assert(section.portraitUnknown:IsShown() and section.portraitRings[1]:IsShown())
            assert(not section.portrait:IsShown())
        ''')

    def test_index_letters_scroll_without_filtering(self):
        lua = new_ui_client(['SharingReport.lua', 'BestiaryJournal.lua', 'Scrollbars.lua',
            'ActionButtons.lua', 'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua',
            'FieldbookShell.lua', 'BestiaryPages.lua', 'BestiaryBook.lua'])
        lua.execute("""
            j=ns.CreateBestiaryJournal({},function() return npcID end)
            function UnitName(unit) return string.format('%s %02d',npcID<=20 and 'Alpha' or 'Beta',npcID) end
            for i=1,40 do npcID=i;j:Observe('target') end
            controller=ns.CreateBestiaryBook(j);controller:Toggle()
            local section=AzerothFieldbookBestiarySection
            section.letterButtons[2].scripts.OnClick()
            assert(section.rows[1].id==21)
            assert(section.creatureScrollBar:GetValue()==20)
            section.creatureScrollBar.scripts.OnValueChanged(section.creatureScrollBar,0)
            assert(section.rows[1].id==1,'earlier letters must remain in the list')
            section.letterButtons[2].scripts.OnClick()
            assert(section.rows[1].id==21,'repeat clicks jump again instead of clearing a filter')
            section.indexButton.scripts.OnClick()
            section.creatureScrollBar.scripts.OnValueChanged(section.creatureScrollBar,10)
            assert(section.rows[10].id==20 and section.rows[11].id==21)
            assert(section.rows[11].groupDivider[1]:IsShown())
            assert(not section.rows[10].groupDivider[1]:IsShown())
            section.indexButton.scripts.OnClick()
            section.creatureScrollBar.scripts.OnValueChanged(section.creatureScrollBar,10)
            assert(section.rows[11].groupDivider[1]:IsShown(),'group dividers remain when Index is closed')
            assert(not section.rows[10].groupDivider[1]:IsShown())
        """)

    def test_reopening_prefers_previous_then_known_target_without_creating_entries(self):
        lua = new_ui_client(['SharingReport.lua', 'BestiaryJournal.lua', 'Scrollbars.lua',
            'ActionButtons.lua', 'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua',
            'FieldbookShell.lua', 'BestiaryPages.lua', 'BestiaryBook.lua'])
        lua.execute("""
            j=ns.CreateBestiaryJournal({},function() return npcID end)
            npcID=41;j:Observe('target');npcID=42;j:Observe('target')
            controller=ns.CreateBestiaryBook(j)
            npcID=nil;controller:Toggle()
            local section=AzerothFieldbookBestiarySection
            assert(section.modelEntryID==nil)
            controller:Toggle();npcID=999;controller:Toggle()
            assert(section.modelEntryID==nil and j.entries[999]==nil)
            controller:Toggle();npcID=41;controller:Toggle()
            assert(section.modelEntryID==41)
            controller:Toggle();npcID=42;controller:Toggle()
            assert(section.modelEntryID==41,'previous selection must beat the target')
            controller:Toggle();npcID=nil;controller:Toggle()
            assert(section.modelEntryID==41)
        """)

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

    def test_live_unit_priority_identity_recheck_and_fallback(self):
        lua = new_ui_client(['SharingReport.lua', 'BestiaryJournal.lua', 'Scrollbars.lua',
            'ActionButtons.lua', 'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua',
            'FieldbookShell.lua', 'BestiaryPages.lua', 'BestiaryBook.lua'])
        lua.execute('''
            local ids={target=42,mouseover=42}
            j=ns.CreateBestiaryJournal({},function(unit) return ids[unit] end)
            c=ns.CreateBestiaryBook(j);c:OpenAtUnit('target')
            local section=AzerothFieldbookBestiarySection
            local model=section.model;local units={};local fallback=0
            function model:SetUnit(unit)
                units[#units+1]=unit
                if fail then return false end
                if complete then self.scripts.OnModelLoaded(self) end
                return true
            end
            function model:SetCreature(id) fallback=fallback+1 end
            complete=true;c:OpenAtUnit('mouseover')
            assert(units[1]=='mouseover' and fallback==0 and model.alpha==1)
            complete=false;c:OpenAtUnit('target')
            assert(section.modelPending)
            ids.target=43;ids.mouseover=44
            model.scripts.OnUpdate(model,.5)
            assert(fallback==1,'changed unit tokens must use creature fallback')
            ids.target=42;ids.mouseover=42;fail=true;c:OpenAtUnit('target')
            assert(fallback==2,'failed SetUnit falls back')
            fail=false;c:OpenAtUnit('target')
            for i=1,3 do model.scripts.OnUpdate(model,.5) end
            assert(fallback==3,'stalled live load eventually falls back')
            j.entries[42].personalEncountered=false;c:Refresh()
            local count=#units;model.scripts.OnUpdate(model,5)
            assert(#units==count and not model:IsShown(),'report-only models stay hidden')
        ''')


if __name__ == '__main__':
    unittest.main()
