"""Real section builders in the widget host; native rendering is a live check."""
import unittest
import xml.etree.ElementTree as ET
from kill_test_harness import new_client, ROOT
from ui_test_harness import new_ui_client
from atlas_test_harness import ATLAS_MODULES
from angling_test_harness import ANGLING_MODULES
from ledger_test_harness import LEDGER_MODULES
from treasure_test_harness import TREASURE_MODULES

LORE_MODULES = ['LoreJournal.lua', 'LoreSettings.lua', 'LoreTracking.lua', 'LoreReports.lua',
                'LoreReportUI.lua', 'LoreReferences.lua', 'LoreMap.lua', 'LoreEditors.lua',
                'LoreBook.lua', 'LoreIntegration.lua']


class FieldbookTabsTests(unittest.TestCase):
    def test_search_placeholders_follow_query_and_clear_button(self):
        self.lua.execute('''
            local sections={atlas=atlas,angling=angling,merchants=ledger,treasure=treasure,lore=lore}
            for _,id in ipairs({'bestiary','gathering','atlas','angling','merchants','treasure','lore'}) do
                shell:ShowSection(id)
                local page=sections[id] and sections[id].main or shell.sections[id].frame
                local search=assert(page.search,id)
                assert(search.placeholder:IsShown(),id..': empty query')
                search:SetText('no matching entry')
                assert(not search.placeholder:IsShown(),id..': entered query')
                search:SetText('')
                assert(search.placeholder:IsShown(),id..': deleted query')
                search:SetText('restored query')
                assert(not search.placeholder:IsShown(),id..': restored query')
                search.clearButton.scripts.OnClick(search.clearButton)
                assert(search:GetText()=='' and search.placeholder:IsShown(),id..': clear button')
            end
        ''')

    def test_background_lore_capture_announces_automatic_tag_once(self):
        self.lua.execute('''
            local chat={};DEFAULT_CHAT_FRAME={AddMessage=function(_,message) chat[#chat+1]=message end}
            journal:SetPointAnnouncements(false);journal:SetCreatureAnnouncement(false)
            local events=journal:GetEventLog().entries;local before=#events
            local page,title=1,'Captured book';local words={'First private source page','Second source page'}
            ItemTextFrame=CreateFrame('Frame');ItemTextFrame:Show()
            function ItemTextGetItem() return title end
            function ItemTextGetPage() return page end
            function ItemTextGetText() return words[page] end
            function ItemTextHasNextPage() return page<2 end
            function ItemTextGetCreator() return nil end
            local t=lore.tracking;t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY')
            assert(not shell:GetFrame() and not lore.main,'Automatic capture never opens the archive')
            local e=assert(lore.journal:List({kind='writing'})[1])
            local expected="|cffffd100[Recorded]|r |cff80d0ffLorekeeper's Chronicle:|r |cffffffffCaptured book |cff80d0ff[A]|r|r |cff999999(Writing)|r"
            assert(#chat==1 and chat[1]=='|cff80d0ffAFB:|r '..expected)
            assert(#events==before+1 and events[#events].message==expected and events[#events].details.automatic)
            assert(not chat[1]:find(words[1],1,true),'Chat contains the title, never source text')
            page=2;t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY')
            t:Event('ITEM_TEXT_CLOSED');page=1;t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY')
            lore.journal:Update(e.id,{notes='Private annotation'});ns.CreateLoreJournal(lore.journal.db)
            assert(#chat==1 and #events==before+1,'Extra pages, rereads, annotations and reload are silent')
            t:Event('ITEM_TEXT_CLOSED');settings.autoArchiveLore=false;title='Requested capture'
            t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY');assert(#chat==1)
            assert(t:CaptureCurrent());assert(#chat==2 and chat[2]:find('|cff80d0ff[A]|r',1,true))
            assert(lore.journal:Create('writing',{title='Manual transcription'}))
            assert(lore.journal:Create('writing',{title='Received writing',origin='reported'}))
            assert(#chat==4 and not chat[3]:find('[A]',1,true) and not chat[4]:find('[A]',1,true))
            assert(not events[#events].details.automatic)
        ''')

    def test_lore_records_announce_and_persist_in_shared_event_log(self):
        self.lua.execute('''
            local chat={};DEFAULT_CHAT_FRAME={AddMessage=function(_,message) chat[#chat+1]=message end}
            local entries=journal:GetEventLog().entries;local before=#entries
            journal:SetPointAnnouncements(false);journal:SetCreatureAnnouncement(false)
            local e=assert(lore.journal:Create('landmark',{title='Old tower',notes='Private annotation'}))
            assert(#chat==1 and #entries==before+1)
            local event=entries[#entries]
            assert(event.message=="|cffffd100[Recorded]|r |cff80d0ffLorekeeper's Chronicle:|r |cffffffffOld tower|r |cff999999(Landmark)|r")
            assert(chat[1]:find(event.message,1,true) and not chat[1]:find('Private annotation',1,true))
            assert(event.timestamp and event.details.kind=='lore-recorded' and event.details.loreID==e.id)
            lore.journal:Update(e.id,{notes='Changed'});assert(#chat==1 and #entries==before+1)
            local currentMessage="Lorekeeper's Chronicle recorded: Old tower (Landmark)."
            event.message='Lore recorded: Old tower (Landmark).'
            shell:ShowSection('lore');local root=shell:GetFrame()
            assert(root.eventLogButton:IsShown() and root.eventLogButton.enabled)
            root.eventLogButton.scripts.OnClick()
            local page=shell.sections.bestiary.pages.eventLog
            page.scripts.OnShow(page) -- The widget host does not dispatch native OnShow.
            assert(shell.active=='lore' and page:IsShown() and page.text:GetText():find(currentMessage,1,true))
            assert(event.message=='Lore recorded: Old tower (Landmark).','Displaying the current section title preserves saved history')
            DEFAULT_CHAT_FRAME=nil
            assert(lore.journal:Create('mystery',{title='Lost inscription'}))
            assert(#entries==before+2 and page.text:GetText():find('Lost inscription',1,true))
            shell:ShowSection('atlas');assert(not page:IsShown())
            journal:ResetDatabase();assert(#journal:GetEventLog().entries==before+2)
        ''')

    def test_text_size_slider_default_reset_reload_and_shared_setting(self):
        self.lua.execute('''
            shell:ShowSection('bestiary');shell:TogglePage('options')
            local options=shell.sections.bestiary.pages.options
            assert(options.textSize:GetValue()==0 and not ns.TextSize:NeedsReload())
            options.textSize:SetValue(3);options.textSize.scripts.OnValueChanged(options.textSize,3)
            assert(ns.TextSize:Get()==3 and ns.TextSize:NeedsReload())
            shell:ShowSection('lore');shell:TogglePage('options')
            assert(shell.sections.bestiary.pages.options==options and options.textSize:GetValue()==3)
            local reloaded=false;ReloadUI=function() reloaded=true end
            options.textSizeReload.scripts.OnClick();assert(reloaded)
            options.textSizeReset.scripts.OnClick()
            assert(ns.TextSize:Get()==0 and options.textSize:GetValue()==0 and not ns.TextSize:NeedsReload())
            options.textSize.scripts.OnValueChanged(options.textSize,-3)
            ns.UIScale:Set(1.25);journal:ResetDatabase()
            assert(ns.TextSize:Get()==-3 and ns.UIScale:Get()==1.25)
        ''')

    def test_lore_options_defaults_false_persistence_and_bestiary_reset_scope(self):
        self.lua.execute('''
            assert(settings.autoArchiveLore==true and settings.loreOnlyOpenedPages==true)
            shell:ShowSection('lore');shell:TogglePage('options')
            local options=shell.sections.bestiary.pages.options
            options.autoArchiveLore:SetChecked(false);options.autoArchiveLore.scripts.OnClick(options.autoArchiveLore)
            options.loreOnlyOpenedPages:SetChecked(false);options.loreOnlyOpenedPages.scripts.OnClick(options.loreOnlyOpenedPages)
            ns.LoreSettings.Initialize(settings)
            assert(settings.autoArchiveLore==false and settings.loreOnlyOpenedPages==false)
            local e=assert(lore.journal:Create('mystery',{title='Preserved investigation',notes='Keep this'}))
            local db=lore.journal.db;local atlasStore=atlas.journal.records
            journal:ResetDatabase()
            assert(settings.autoArchiveLore==false and settings.loreOnlyOpenedPages==false)
            assert(lore.journal.db==db and lore.journal:Get(e.id).notes=='Keep this')
            assert(atlas.journal.records==atlasStore)
        ''')

    def test_lore_references_use_known_source_stores_and_never_redirect_deleted_refs(self):
        self.lua.execute('''
            atlas.journal.records['fixture']={id='fixture',name='Known Atlas place',created=1}
            ledger.journal.db.contacts['fixture']={id='fixture',name='Known person',reference='ledger:scope:1'}
            treasure.journal.kinds['fixture']={id='fixture',name='Known find',reference='treasure:scope:1'}
            local references=lore.references
            for _,section in ipairs({'atlas','merchants','treasure'}) do
                local rows=references.adapters[section].list();assert(#rows==1 and rows[1].key)
                local ref={section=section,key=rows[1].key,name=rows[1].name}
                assert(not references:Resolve(ref).missing)
                if section=='atlas' then atlas.journal.records.fixture=nil
                elseif section=='merchants' then ledger.journal.db.contacts.fixture.reference='ledger:other-scope:1'
                else treasure.journal.kinds.fixture.reference='treasure:other-scope:1' end
                assert(references:Resolve(ref).missing)
                assert(not references:Open(ref))
            end
        ''')

    def test_first_open_known_target_then_reopen_last_selected_entry(self):
        self.lua.execute('''
            npcID=42;journal:Observe('target')
            shell:Toggle()
            local content=AzerothFieldbookBestiarySection
            assert(content.modelEntryID==42,'First opening should use the known target')
            local title=content.title:GetText()
            assert(title~='A field guide of your own')
            content.manualName:SetText('Keep this draft')
            shell:GetFrame().closeButton.scripts.OnClick()
            npcID=99;shell:Toggle()
            assert(content.title:GetText()==title and not journal.entries[99])
            assert(content.manualName:GetText()=='Keep this draft')
            controller:Toggle();npcID=nil;controller:Toggle()
            assert(content.title:GetText()==title)
            click(2);click(1);assert(content.title:GetText()==title)
            npcID=33;controller:OpenAtUnit('mouseover')
            assert(content.title:GetText()~=title,'Explicit mouseover still selects its creature')
        ''')

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
            pageDirections={}
            ns.CreateFieldbookShell=function() return {Toggle=function() shellToggles=shellToggles+1 end,
                CycleSection=function(_,direction) pageDirections[#pageDirections+1]=direction end} end
            ns.CreateBestiaryBook=function() return {CycleEntry=function(_,direction)
                directions[#directions+1]=direction;return true end,
                Toggle=function() error('binding must toggle the shared shell') end,
                OpenAtUnit=function(_,unit) openedUnit=unit end} end
            fire('ADDON_LOADED','AzerothFieldbook')
        ''')
        nodes=list(ET.parse(ROOT/'Bindings.xml').getroot())
        self.assertEqual(len(nodes),7)
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
        lua.execute(bindings['AZEROTHFIELDBOOK_NEXT_PAGE'])
        lua.execute(bindings['AZEROTHFIELDBOOK_PREVIOUS_PAGE'])
        lua.execute('assert(#pageDirections==2 and pageDirections[1]==1 and pageDirections[2]==-1)')
        lua.execute(bindings['CLASSICBESTIARY_BOOK'])
        lua.execute(bindings['CLASSICBESTIARY_MOUSEOVER_BOOK'])
        lua.execute('assert(#directions==2 and directions[1]==1 and directions[2]==-1)')
        lua.execute("assert(shellToggles==1 and openedUnit=='mouseover')")
        self.lua.execute('''
            assert(BINDING_HEADER_AZEROTHFIELDBOOK=='Azeroth Fieldbook')
            assert(BINDING_NAME_CLASSICBESTIARY_BOOK=='Toggle Azeroth Fieldbook')
            assert(BINDING_NAME_CLASSICBESTIARY_MOUSEOVER_BOOK=='Open Azeroth Fieldbook at mouseover')
        ''')

    def test_page_navigation_wraps_in_display_order(self):
        self.lua.execute('''
            shell:ShowSection(shell.order[1])
            shell:CycleSection(-1);assert(shell.active==shell.order[#shell.order])
            shell:CycleSection(1);assert(shell.active==shell.order[1])
            shell:CycleSection(1);assert(shell.active==shell.order[2])
            shell:Hide();shell:CycleSection(-1)
            assert(shell.active==shell.order[1] and shell:GetFrame():IsShown())
            ns.InitializationBlocked=true
            assert(shell:CycleSection(1)==false and shell.active==shell.order[1])
        ''')

    def test_mouseover_binding_prefers_ledger_then_falls_back_to_bestiary(self):
        lua=new_client()
        lua.execute('''
            bestiaryOpens=0;ledgerOpens=0;gatheringOpens=0;knownContact=true;node=false
            ns.CreateFieldbookShell=function() return {} end
            ns.InitializeGathering=function() return {journal={},OpenAtMouseover=function()
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
            'Scrollbars.lua', 'WindowFocus.lua', 'WindowPositions.lua', 'UIScale.lua', 'TextSize.lua',
            'ActionButtons.lua', 'SharingReport.lua', 'BestiaryBackups.lua', 'BestiaryJournal.lua', 'BackupWindow.lua',
            'CreatureNotes.lua', 'RumoursWindow.lua', 'FieldbookShell.lua',
            'CreatureLocations.lua', 'GatheringJournal.lua', 'GatheringModels.lua', 'GatheringTracking.lua',
            'GatheringLocationsWindow.lua', 'GatheringMapPins.lua', 'GatheringBook.lua',
            *ATLAS_MODULES, *ANGLING_MODULES, *LEDGER_MODULES, *TREASURE_MODULES, *LORE_MODULES,
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
            lore=ns.InitializeLore(shell,settings,{bestiary=journal,gathering=gathering,atlas=atlas,angling=angling,merchants=ledger,treasure=treasure})
            ns.RegisterFieldbookWishlistSections(shell)
            function click(index,button,inside)
                local tab=shell:GetFrame().sectionTabs[index]
                tab.scripts.OnMouseUp(tab,button or 'LeftButton',inside~=false)
            end
        ''')

    def test_shared_page_title_and_compendium_model_alignment(self):
        self.lua.execute("""
            local sections={atlas=atlas,angling=angling,merchants=ledger,treasure=treasure,lore=lore}
            for _,id in ipairs({'bestiary','gathering','atlas','angling','merchants','treasure','lore'}) do
                shell:ShowSection(id)
                local page=sections[id] and sections[id].main or shell.sections[id].frame
                local title=page.pageTitle
                assert(shell.sections[id].frame:GetHeight()==740 and shell:GetFrame():GetHeight()==740,id..': standard section height')
                assert(title and title.point[1]=='TOPLEFT' and title.point[2]==37 and title.point[3]==-60,id)
                assert(title:GetText()==shell.sections[id].definition.title,id)
                local count=page.entryCount or page.count
                assert(count.point[2]==37 and count.point[3]==-88 and count:GetWidth()==260,id..': count below title')
                assert(count:GetText():match('^%d+ entries • %d+ shown$'),id..': consistent count text')
                assert(page.search.point[2]==70 and page.search.point[3]==-110,id..': shared search row')
                local filter=page.listFilterButton or page.filters
                if filter then assert(filter.point[2]==244 and filter.point[3]==-110,id..': filter beside search') end
                local sort=page.sortButton or page.sort
                if sort then assert(sort.point[2]==270 and sort.point[3]==-110,id..': sort beside filter') end

            end
            local b=shell.sections.bestiary.frame
            local g=shell.sections.gathering.frame
            assert(b.confirm.point[2]==b.modelBorder and b.confirm.point[3]=='TOPLEFT')
            assert(b.confirm.point[4]==6 and b.confirm.point[5]==-6,'lock sits inside the viewer top left')
            assert(g.model.point[2]==b.model.point[2] and g.model.point[3]==b.model.point[3])
            assert(g.modelBorder.point[2]==b.modelBorder.point[2] and g.modelBorder.point[3]==b.modelBorder.point[3])
            assert(g.model:GetWidth()==b.model:GetWidth() and g.model:GetHeight()==b.model:GetHeight())
            assert(g.mineralModel.point[2]==g.model.point[2] and g.mineralModel.point[3]==g.model.point[3])
            assert(g.basicHeading.point[3]==g.locationsHeading.point[3])
            assert(-g.stats.point[3]>-g.modelBorder.point[3]+g.modelBorder:GetHeight())
            assert(g.noteScroll.parent.point[3]==g.lootScroll.parent.point[3])
            assert(-g.mapOptions.worldMap.point[3]+g.mapOptions.worldMap:GetHeight()<=714)
            for _,page in ipairs({b,g}) do
                assert(page.entryCount.point[3]==-88 and page.search.point[3]==-110)
                assert(#page.rows==18 and page.rows[1].point[3]==-140 and page.rows[18].point[3]==-599)
                assert(page.rows[18]:GetHeight()==26)
            end
        """)

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
            local names={'Bestiary',"Gatherer's Compendium",'Traveller’s Atlas','Merchant’s Ledger',
                'Treasure Journal','Angler’s Almanac',"Lorekeeper's Chronicle"}
            assert(shell.active=='bestiary' and #root.sectionTabs==7)
            assert(root.navigation.point[2]==root and root.navigation.point[3]=='TOPRIGHT')
            assert(root.navigation.point[4]==-2,'native tab art overlaps the trim only enough to seal the seam')
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
                assert(root.eventLogButton:IsShown()==(shell.active=='angling' or shell.active=='lore'))
                local content=shell.sections[shell.active].frame
                click(index);assert(shell.sections[shell.active].frame==content and root:IsShown())
            end
            root.closeButton.scripts.OnClick();assert(not root:IsShown())
            shell:Toggle();assert(shell.active=='lore' and root:IsShown())
            click(1);assert(root.helpButton:IsShown() and root.optionsButton:IsShown() and root.eventLogButton:IsShown())
        ''')

    def test_lore_is_a_functional_archive_without_changing_bestiary(self):
        self.lua.execute('''
            shell:Toggle()
            local entry=journal.entries[42]
            click(7)
            assert(shell.active=='lore' and lore.main and lore.main.reader and lore.main.map)
            assert(next(lore.journal.entries)==nil)
            local record=assert(lore.journal:Create('mystery',{title='My question',nextStep='Visit again'}))
            lore:Select(record.id)
            assert(lore.main.reader.text:GetText():find('Visit again',1,true))
            assert(journal.entries[42]==entry,'Lore edits preserve Bestiary data')
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
            controller:OpenAtUnit('target')
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
            for _,size in ipairs({{7680,2160},{1920,1200},{1920,1080},{1280,720},{1024,768}}) do
                UIParent:SetSize(size[1],size[2])
                root.scripts.OnEvent(root,'DISPLAY_SIZE_CHANGED')
                for _,value in ipairs({0.5,0.75,1,1.25,1.5}) do
                    ns.UIScale:Set(value)
                    local scale=root:GetScale()
                    assert((root:GetWidth()+root.afbOutsideRight)*scale<=size[1]-30+0.001)
                    assert(root:GetHeight()*scale<=size[2]-30+0.001)
                    assert(40+root.navigation:GetHeight()+6<root:GetHeight())
                    assert(root.clampInsets[2]==-root.afbOutsideRight)
                    assert(root.afbOutsideRight==root.navigation:GetWidth()+root.navigation.point[4]+6)
                    assert(root.navigation.point[4]==-2 and root.navigation.point[5]==-40)
                    for _,tab in ipairs(root.sectionTabs) do assert(tab:GetEffectiveScale()==root:GetEffectiveScale()) end
                end
            end
        ''')


if __name__ == '__main__':
    unittest.main()
