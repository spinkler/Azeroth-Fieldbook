"""Real section builders in the widget host; native rendering is a live check."""
import unittest
import xml.etree.ElementTree as ET
from kill_test_harness import new_client, ROOT
from ui_test_harness import new_ui_client
from atlas_test_harness import ATLAS_MODULES
from angling_test_harness import ANGLING_MODULES
from ledger_test_harness import LEDGER_MODULES
from treasure_test_harness import TREASURE_MODULES


class FieldbookTabsTests(unittest.TestCase):
    def test_repeated_navigation_reuses_all_section_and_page_widgets(self):
        self.lua.execute('''
            local function visit()
                for _,id in ipairs(shell.order) do
                    shell:ShowSection(id)
                    shell:TogglePage('help');shell:TogglePage('help')
                    shell:TogglePage('options');shell:TogglePage('options')
                end
            end
            visit()
            local count,escapes=#objects,#UISpecialFrames
            for _=1,100 do visit() end
            assert(#objects==count,'Repeated navigation must not allocate native frames or regions')
            assert(#UISpecialFrames==escapes,'Escape registrations must not accumulate')
        ''')

    def test_every_section_help_uses_shared_button_and_relevant_content(self):
        self.lua.execute('''
            shell:ShowSection('bestiary')
            local root=shell:GetFrame();local button=root.helpButton
            local x,y=button:GetWidth(),button:GetHeight();local anchor=button.point
            for _,id in ipairs(shell.order) do
                shell:ShowSection(id)
                assert(root.helpButton==button and button:IsShown())
                assert(button:GetWidth()==x and button:GetHeight()==y and button.point==anchor)
                root.optionsButton.scripts.OnClick()
                assert(shell.sections.bestiary.pages.options:IsShown())
                button.scripts.OnClick()
                local help=shell.sections[id].pages.help
                assert(help:IsShown() and not shell.sections.bestiary.pages.options:IsShown())
                assert(help:GetWidth()==610 and help.scroll and help.closeButton)
                if id=='gathering' then assert(help.instructions:GetText():find('Save notes',1,true)) end
                if id=='atlas' then assert(help.instructions:GetText():find('Route / Passage',1,true)) end
                for _,definition in ipairs(ns.FieldbookWishlistSections) do
                    if definition.id==id then
                        assert(help.instructions:GetText():find(definition.wishlist,1,true))
                        assert(help.instructions:GetText():find('does not collect or save data',1,true))
                    end
                end
                button.scripts.OnClick();assert(not help:IsShown())
                button.scripts.OnClick();assert(help:IsShown())
                root.optionsButton.scripts.OnClick()
                assert(not help:IsShown() and shell.sections.bestiary.pages.options:IsShown())
                root.optionsButton.scripts.OnClick()
            end
        ''')

    def test_options_access_from_every_section_before_bestiary_open(self):
        self.lua.execute('''
            shell:ShowSection('gathering')
            assert(shell.sections.bestiary.frame==nil)
            local root=shell:GetFrame()
            root.optionsButton.scripts.OnClick()
            local options=shell.sections.bestiary.pages.options
            assert(options:IsShown() and shell.active=='gathering')
            assert(not shell.sections.bestiary.frame:IsShown())
            root.optionsButton.scripts.OnClick();assert(not options:IsShown())
            for _,id in ipairs(shell.order) do
                shell:ShowSection(id)
                assert(root.optionsButton:IsShown() and root.optionsButton.enabled)
                root.optionsButton.scripts.OnClick();assert(options:IsShown() and shell.active==id)
                root.optionsButton.scripts.OnClick();assert(not options:IsShown())
            end
        ''')

    def test_binding_xml_routes_next_and_previous_actions(self):
        lua=new_client()
        lua.execute('''
            directions={}
            AzerothFieldbookNextEntry();AzerothFieldbookPreviousEntry()
            shellToggles=0
            ns.CreateFieldbookShell=function() return {Toggle=function() shellToggles=shellToggles+1 end} end
            ns.CreateBestiaryBook=function() return {CycleEntry=function(_,direction)
                directions[#directions+1]=direction;return true end,
                Toggle=function() error('binding must toggle the shared shell') end,
                OpenAtUnit=function(_,unit) openedUnit=unit end} end
            fire('ADDON_LOADED','AzerothFieldbook')
        ''')
        nodes=list(ET.parse(ROOT/'Bindings.xml').getroot())
        self.assertEqual(len(nodes),5)
        for node in nodes:
            self.assertEqual(node.attrib.get('category'),'BINDING_HEADER_AZEROTHFIELDBOOK')
            self.assertNotIn('header',node.attrib,'legacy headers create synthetic binding rows')
            self.assertFalse(node.attrib['name'].startswith('HEADER'))
        bindings={node.attrib['name']:node.text for node in nodes}
        lua.execute('atlasPoints=0;function AzerothFieldbookRecordAtlasPoint() atlasPoints=atlasPoints+1 end')
        lua.execute(bindings['AZEROTHFIELDBOOK_ATLAS_POINT'])
        lua.execute('assert(atlasPoints==1)')
        lua.execute(bindings['CLASSICBESTIARY_NEXT_ENTRY'])
        lua.execute(bindings['CLASSICBESTIARY_PREVIOUS_ENTRY'])
        lua.execute(bindings['CLASSICBESTIARY_BOOK'])
        lua.execute(bindings['CLASSICBESTIARY_MOUSEOVER_BOOK'])
        lua.execute('assert(#directions==2 and directions[1]==1 and directions[2]==-1)')
        lua.execute("assert(shellToggles==1 and openedUnit=='mouseover')")
        self.lua.execute('''
            assert(BINDING_HEADER_AZEROTHFIELDBOOK=='Azeroth Fieldbook')
            assert(BINDING_NAME_CLASSICBESTIARY_BOOK=='Toggle Azeroth Fieldbook')
            assert(BINDING_NAME_CLASSICBESTIARY_MOUSEOVER_BOOK=='Open Azeroth Fieldbook at mouseover')
        ''')

    def test_mouseover_binding_prefers_ledger_then_falls_back_to_bestiary(self):
        lua=new_client()
        lua.execute('''
            bestiaryOpens=0;ledgerOpens=0;gatheringOpens=0;knownContact=true;node=false
            ns.CreateFieldbookShell=function() return {} end
            ns.InitializeGathering=function() return {OpenAtMouseover=function()
                gatheringOpens=gatheringOpens+1;return node end} end
            ns.InitializeLedger=function() return {OpenAtUnit=function(_,unit)
                assert(unit=='mouseover');ledgerOpens=ledgerOpens+1;return knownContact end} end
            ns.CreateBestiaryBook=function() return {OpenAtUnit=function(_,unit)
                assert(unit=='mouseover');bestiaryOpens=bestiaryOpens+1;return true end} end
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(AzerothFieldbookOpenMouseover() and ledgerOpens==1 and bestiaryOpens==0)
            knownContact=false;assert(AzerothFieldbookOpenMouseoverBestiary())
            assert(ledgerOpens==2 and bestiaryOpens==1)
            node=true;assert(AzerothFieldbookOpenMouseover())
            assert(gatheringOpens==3 and ledgerOpens==2 and bestiaryOpens==1)
        ''')

    def test_entry_keys_reuse_filtered_order_scroll_wrap_and_visibility_gates(self):
        self.lua.execute('''
            assert(not controller:CycleEntry(1) and shell:GetFrame()==nil)
            for i=1,20 do
                local e=journal:Ensure(i,true,string.format('Animal %02d',i))
                e.category='Beast';e.levelMin=i;e.levelMax=i
            end
            shell:ShowSection('bestiary',{creatureID=1})
            local section=AzerothFieldbookBestiarySection
            assert(controller:CycleEntry(1) and section.title.text=='Animal 02')
            assert(controller:CycleEntry(-1) and section.title.text=='Animal 01')
            assert(controller:CycleEntry(-1) and section.title.text=='Animal 20')
            assert(section.creatureScrollBar:GetValue()>0,'selected entry scrolls into view')
            assert(controller:CycleEntry(1) and section.title.text=='Animal 01')
            section.search:SetText('Animal 1')
            section.search.scripts.OnTextChanged(section.search)
            assert(controller:CycleEntry(1) and section.title.text=='Animal 10')
            journal:SetListSort('maxLevel',true);controller:Refresh()
            assert(controller:CycleEntry(1) and section.title.text=='Animal 19')
            assert(controller:CycleEntry(-1) and section.title.text=='Animal 10')
            GetCurrentKeyBoardFocus=function() return section.search end
            assert(not controller:CycleEntry(1) and section.title.text=='Animal 10')
            GetCurrentKeyBoardFocus=nil
            shell:ShowSection('atlas',{navigation=true})
            assert(not controller:CycleEntry(1) and section.title.text=='Animal 10')
            shell:ShowSection('bestiary',{navigation=true});shell:GetFrame():Hide()
            assert(not controller:CycleEntry(-1) and section.title.text=='Animal 10')
            shell:ShowSection('bestiary',{navigation=true})
            section.search:SetText('no matching creature');section.search.scripts.OnTextChanged(section.search)
            assert(not controller:CycleEntry(1))
        ''')

    def setUp(self):
        self.lua = new_ui_client([
            'Scrollbars.lua', 'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua',
            'ActionButtons.lua', 'SharingReport.lua', 'BestiaryBackups.lua', 'BestiaryJournal.lua', 'BackupWindow.lua',
            'CreatureNotes.lua', 'RumoursWindow.lua', 'FieldbookShell.lua',
            'CreatureLocations.lua', 'GatheringJournal.lua', 'GatheringModels.lua', 'GatheringTracking.lua',
            'GatheringLocationsWindow.lua', 'GatheringMapPins.lua', 'GatheringBook.lua',
            *ATLAS_MODULES, *ANGLING_MODULES, *LEDGER_MODULES, *TREASURE_MODULES,
            'FieldbookSections.lua', 'BestiaryPages.lua', 'BestiaryBook.lua',
        ])
        self.lua.execute('''
            settings={}
            ns.UIScale:Initialize(settings)
            GameTooltip=CreateFrame('Frame')
            function GameTooltip:SetOwner(owner,anchor) self.owner=owner;self.anchor=anchor end
            function GameTooltip:IsOwned(owner) return self.owner==owner end
            journal=ns.CreateBestiaryJournal(settings,function() return npcID end)
            shell=ns.CreateFieldbookShell()
            controller=ns.CreateBestiaryBook(journal,shell)
            gathering=ns.InitializeGathering(shell)
            atlas=ns.InitializeAtlas(shell,journal)
            angling=ns.InitializeAngling(shell)
            ledger=ns.InitializeLedger(shell)
            treasure=ns.InitializeTreasure(shell)
            ns.RegisterFieldbookWishlistSections(shell)
            function click(index,button,inside)
                local tab=shell:GetFrame().sectionTabs[index]
                tab.scripts.OnMouseUp(tab,button or 'LeftButton',inside~=false)
            end
        ''')

    def test_order_default_reuse_selection_and_tooltips(self):
        self.lua.execute('''
            assert(shell:GetFrame()==nil,'registration stays lazy')
            shell:Toggle()
            local root=shell:GetFrame()
            local content=AzerothFieldbookBestiarySection
            assert(content.indexButton:GetFrameLevel()==root.titleIcon:GetFrameLevel()-1)
            for _,tab in ipairs(content.letterButtons) do
                assert(tab:GetFrameLevel()==root.titleIcon:GetFrameLevel()-1)
                assert(tab:GetFrameLevel()>root:GetFrameLevel(),'index stays above parchment')
            end
            assert(root.closeButton:GetFrameLevel()>root.titleIcon:GetFrameLevel())
            assert(not root.titleIcon:IsMouseEnabled(),'decorative trim does not block tab clicks')
            local names={'Bestiary',"Gatherer's Compendium",'Traveller’s Atlas','Angler’s Almanac',
                'Merchant’s Ledger','Treasure & Salvage','Lore & Landmarks'}
            assert(shell.active=='bestiary' and #root.sectionTabs==7)
            assert(root.navigation.point[2]==root and root.navigation.point[3]=='TOPRIGHT')
            assert(root.navigation.point[4]==0,'tabs attach to the outside edge')
            assert(root.sectionTabs[1].Icon.texture=='Interface\\\\Icons\\\\Ability_Tracking')
            for index,tab in ipairs(root.sectionTabs) do
                assert(tab.template=='LargeSideTabButtonTemplate' and tab.tooltipText==names[index])
                assert(tab:GetWidth()==root.sectionTabs[1]:GetWidth())
                assert(tab.point[3]==-(index-1)*(tab:GetHeight()+2))
                assert(tab.SelectedTexture:IsShown()==(index==1))
                tab.scripts.OnEnter(tab)
                assert(GameTooltip:GetText()==names[index] and GameTooltip.owner==tab and GameTooltip:IsShown())
                tab.scripts.OnLeave(tab);assert(not GameTooltip:IsShown())
            end
            click(2,'RightButton');assert(shell.active=='bestiary')
            click(2,'LeftButton',false);assert(shell.active=='bestiary')
            for index=2,7 do
                click(index)
                assert(shell:GetFrame()==root and root:IsShown())
                for other,tab in ipairs(root.sectionTabs) do
                    assert(tab.SelectedTexture:IsShown()==(other==index),'exactly one gold selection')
                    assert(shell.sections[shell.order[other]].frame==nil or
                        shell.sections[shell.order[other]].frame:IsShown()==(other==index))
                end
                assert(root.helpButton:IsShown() and root.optionsButton:IsShown())
                assert(root.eventLogButton:IsShown()==(shell.active=='angling'))
                local content=shell.sections[shell.active].frame
                click(index);assert(shell.sections[shell.active].frame==content and root:IsShown())
            end
            root.closeButton.scripts.OnClick();assert(not root:IsShown())
            shell:Toggle();assert(shell.active=='lore' and root:IsShown())
            click(1);assert(root.helpButton:IsShown() and root.optionsButton:IsShown() and root.eventLogButton:IsShown())
        ''')

    def test_exact_copy_and_wrapping_bounds(self):
        paragraphs = [
            'Collect references to books, inscriptions, landmarks and noteworthy characters. Keep source-labelled notes, connect related discoveries and record mysteries worth revisiting.',
        ]
        self.lua.globals().paragraphs = self.lua.table_from(paragraphs)
        self.lua.execute('''
            shell:Toggle()
            local entry=journal.entries[42]
            for index,text in ipairs(paragraphs) do
                click(index+6)
                local content=shell.sections[shell.active].frame
                assert(content.title:GetText()==shell.sections[shell.active].definition.title)
                assert(content.heading:GetText()=='Wishlist for future releases')
                assert(content.wishlist:GetText()==text)
                assert(content.wishlist.wordWrap and not content.wishlist.nonSpaceWrap)
                assert(content.wishlist.point[2]>=40 and content.wishlist:GetWidth()<=content:GetWidth()-96)
                assert(-content.wishlist.point[3]+content.wishlist:GetStringHeight()<content:GetHeight()-48)
                assert(journal.entries[42]==entry,'placeholder visits preserve the journal data')
            end
        ''')

    def test_return_keeps_creature_filters_scroll_and_draft_with_different_target(self):
        self.lua.execute('''
            for id=1,50 do npcID=id;journal:Observe('target') end
            npcID=22;controller:OpenAtUnit('target')
            local content=AzerothFieldbookBestiarySection
            local entry=journal.entries[22]
            for index=1,12 do entry.abilities[string.format('Ability %02d',index)]={state='confirmed',origin='Your note'} end
            content.typeButtons.Humanoid.scripts.OnClick()
            content.search:SetText('Creature')
            content.creatureScrollBar.scripts.OnValueChanged(content.creatureScrollBar,17)
            content.abilityScrollBar.scripts.OnValueChanged(content.abilityScrollBar,5)
            content.damageScroll:SetVerticalScroll(12)
            content.manualName:SetText('Unfinished name');content.manualNote:SetText('Unfinished note')
            local first,ability=content.rows[1].id,content.abilities[1].name
            local title=content.title:GetText()
            click(2)
            npcID=49
            journal:Observe('target') -- Tracking can continue while the content is hidden.
            click(1)
            assert(content.title:GetText()==title and journal.entries[22]==entry)
            assert(content.search:GetText()=='Creature' and content.typeButtons.Humanoid.afbSelected)
            assert(content.rows[1].id==first and content.creatureScrollBar:GetValue()==17)
            assert(content.abilities[1].name==ability and content.abilityScrollBar:GetValue()==5)
            assert(content.manualName:GetText()=='Unfinished name' and content.manualNote:GetText()=='Unfinished note')
            click(1);assert(content.abilityScrollBar:GetValue()==5,'reclick is not a refresh/open action')
            click(3);npcID=33
            assert(controller:OpenAtUnit('mouseover') and shell.active=='bestiary')
            assert(content.title:GetText()~=title and shell:GetFrame().sectionTabs[1].SelectedTexture:IsShown())
        ''')

    def test_section_windows_close_and_pinned_notes_keep_their_existing_lifetime(self):
        self.lua.execute('''
            shell:Toggle()
            local root=shell:GetFrame()
            local content=AzerothFieldbookBestiarySection
            root.helpButton.scripts.OnClick()
            content.damageButton.scripts.OnClick()
            content.creatureNotesButton.scripts.OnClick()
            content.rumoursButton.scripts.OnClick()
            content.backupWindow:Open(false)
            StaticPopup_Hide=function(name) hiddenPopup=name end
            assert(AzerothFieldbookCreatureNotes:IsShown() and AzerothFieldbookRumours:IsShown())
            click(2)
            assert(not shell.sections.bestiary.pages.help:IsShown() and not content.damageForm:IsShown())
            assert(not AzerothFieldbookCreatureNotes:IsShown() and not AzerothFieldbookRumours:IsShown())
            assert(not AzerothFieldbookBackups:IsShown() and hiddenPopup=='AZEROTHFIELDBOOK_BESTIARY_RESET_CONFIRM')
            click(1);content.creatureNotesButton.scripts.OnClick()
            AzerothFieldbookCreatureNotes.pinButton.scripts.OnClick()
            click(2);assert(AzerothFieldbookCreatureNotes:IsShown(),'explicitly pinned utility remains independent')
        ''')

    def test_scale_changes_and_display_changes_include_the_whole_column(self):
        self.lua.execute('''
            shell:Toggle()
            local root=shell:GetFrame()
            for _,size in ipairs({{1920,1080},{1280,720},{1024,768}}) do
                UIParent:SetSize(size[1],size[2])
                root.scripts.OnEvent(root,'DISPLAY_SIZE_CHANGED')
                for _,value in ipairs({0.5,0.75,1,1.25,1.5}) do
                    ns.UIScale:Set(value)
                    local scale=root:GetScale()
                    assert((root:GetWidth()+root.afbOutsideRight)*scale<=size[1]-30+0.001)
                    assert(root:GetHeight()*scale<=size[2]-30+0.001)
                    assert(40+root.navigation:GetHeight()+6<root:GetHeight())
                    assert(root.clampInsets[2]==-root.afbOutsideRight)
                    for _,tab in ipairs(root.sectionTabs) do assert(tab:GetEffectiveScale()==root:GetEffectiveScale()) end
                end
            end
        ''')


if __name__ == '__main__':
    unittest.main()
