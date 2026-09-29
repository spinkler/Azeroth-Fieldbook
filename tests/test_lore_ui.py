"""Lore widgets in a synthetic host: control flow, not native Forever rendering."""
import unittest

from ui_test_harness import ROOT, new_ui_client
from atlas_test_harness import ENV


def new_lore_ui():
    lua = new_ui_client([
        'Scrollbars.lua', 'CreatureLocations.lua', 'FieldbookShell.lua',
        'AtlasJournal.lua', 'AtlasUI.lua', 'AtlasMap.lua', 'LoreJournal.lua',
        'LoreReferences.lua', 'LoreMap.lua', 'LoreEditors.lua', 'LoreBook.lua',
    ])
    lua.execute(ENV)
    lua.execute(r'''
        timers={};C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
        function flush() local pending=timers;timers={};for _,fn in ipairs(pending) do fn() end end
        L=ns.Lore;saved={};j=ns.CreateLoreJournal(saved)
        t={GetStatus=function() return 'Capture waits for a readable interaction.' end,
            RecordPerson=function() return j:Create('person',{title='Synthetic speaker'}) end,
            SavePassage=function() return nil,'No current dialogue.' end,
            CaptureCurrent=function() return nil,'No current readable source.' end}
        shell=ns.CreateFieldbookShell();shell:RegisterSection('other',{title='Other',build=function() end})
        c=ns.CreateLoreBook(j,t,shell);shell:ShowSection('lore');m=c.main
        function writing(title)
            local e=assert(j:Create('writing',{title=title or 'Synthetic writing',sourceTitle='Observed title'}))
            e.pages[1]={number=1,raw='<HTML><P>First paragraph — café.</P><P>Second paragraph.</P></HTML>',
                origin='captured',nature='source',method='displayed',personallyViewed=true,source='Synthetic inscription',at=now}
            e.pages[3]={number=3,raw='Automatically retrieved third page',origin='captured',nature='source',method='automatic',personallyViewed=false,source='Synthetic inscription',at=now}
            e.firstPage=1;e.lastPage=3;j:Changed(e);return e
        end
        function openMenu(button)
            local function node()
                local n={children={}}
                function n:CreateButton(label,fn) local child=node();child.label=label;child.action=fn;self.children[#self.children+1]=child;return child end
                function n:CreateDivider() end
                function n:CreateTitle(label) self.title=label end
                function n:SetScrollMode() end
                return n
            end
            MenuUtil={CreateContextMenu=function(_,build) menu=node();build(nil,menu) end}
            click(button);return menu
        end
        function choose(menu,label)
            for _,item in ipairs(menu.children) do if item.label==label then if item.action then item.action() end;return item end end
            error('Menu missing '..label)
        end
    ''')
    return lua


class LoreUITests(unittest.TestCase):
    def setUp(self):
        self.lua = new_lore_ui()

    def test_empty_catalogue_reader_and_background_does_not_select(self):
        self.lua.execute('''
            assert(m.empty:GetText():find('begins empty',1,true))
            local e=writing();flush()
            assert(c.state.selected==nil and m.rows[1].id==e.id)
            click(m.rows[1]);assert(c.state.selected==e.id)
            assert(m.reader.text:GetText():find('First paragraph — café.',1,true))
            assert(not m.reader.text:GetText():find('<HTML>',1,true))
            assert(m.reader.header:GetText():find('Presented in the original reader',1,true))
            c:Page(1);assert(m.reader.text:GetText():find('has not been preserved',1,true))
            c:Page(1);assert(m.reader.header:GetText():find('not personally opened',1,true))
            assert(not e.pages[3].personallyViewed)
        ''')

    def test_reading_position_per_entry_and_background_refresh(self):
        self.lua.execute('''
            local a=writing('A');local b=writing('B');c:Select(a.id);c:Page(2);m.reader:SetVerticalScroll(82)
            c:Select(b.id);m.reader:SetVerticalScroll(25);c:Select(a.id)
            assert(m.reader:GetVerticalScroll()==82 and c.state.reading[a.id].source=='page:3')
            j:AddPassage(a.id,{raw='New background evidence',origin='captured',nature='source',method='observed'})
            flush();assert(m.reader:GetVerticalScroll()==82 and c.state.reading[a.id].source=='page:3')
            shell:ShowSection('other');j:Changed(a);flush();assert(shell.active=='other')
            shell:ShowSection('lore');assert(c.state.selected==a.id and m.reader:GetVerticalScroll()==82)
        ''')

    def test_editor_drafts_survive_switches_and_updates(self):
        self.lua.execute('''
            local a=writing('A');local b=writing('B');c:Select(a.id);c:Edit(nil,a.id)
            local p=c.panels.edit;p.notes:SetText('UNSAVED private buffer')
            shell:ShowSection('other');j:AddPassage(a.id,{raw='Captured update',origin='captured',nature='source',method='observed'});flush()
            shell:ShowSection('lore');assert(p.notes:GetText()=='UNSAVED private buffer')
            c:ClosePanel();c:Select(b.id);c:Edit(nil,b.id);p.notes:SetText('Other draft');c:ClosePanel()
            c:Select(a.id);c:Edit(nil,a.id);assert(p.notes:GetText()=='UNSAVED private buffer')
            click(p.save);assert(a.notes=='UNSAVED private buffer' and b.notes=='')
            assert(a.pages[1].raw:find('First paragraph',1,true) and a.sourceTitle=='Observed title')
        ''')

    def test_creation_mystery_reopening_and_manual_source_separation(self):
        self.lua.execute('''
            for _,kind in ipairs({'writing','landmark','person','mystery'}) do
                c:Edit(kind);local p=c.panels.edit;p.name:SetText('Manual '..kind);p.notes:SetText('Private note')
                if kind=='mystery' then p.statusID='resolved';p.theory:SetText('My interpretation');p.nextStep:SetText('Return at dawn') end
                click(p.save);local e=j:Get(c.state.selected);assert(e.kind==kind and e.notes=='Private note')
                if kind=='mystery' then assert(e.status=='resolved' and e.nextStep=='Return at dawn');c:Edit(nil,e.id);p.statusID='open';click(p.save);assert(e.status=='open') end
            end
            local mystery=j:Get(c.state.selected);c:Passage();local p=c.panels.passage
            p.raw:SetText('Preserved transcription |Hunsafe:123|hLabel|h');p.source:SetText('Monument text');click(p.save)
            assert(mystery.notes=='Private note' and #mystery.passages==1 and mystery.passages[1].origin=='manual')
            assert(mystery.passages[1].raw:find('|Hunsafe',1,true))
            c:Page(1);assert(not m.reader.text:GetText():find('|Hunsafe',1,true))
        ''')

    def test_oversized_transcription_is_refused_without_truncation(self):
        self.lua.execute('''
            local e=writing();c:Select(e.id);c:Passage();local p=c.panels.passage
            local text=string.rep('x',L.MAX_PAGE_BYTES+1);p.raw:SetText(text);click(p.save)
            assert(#e.passages==0 and p.raw:GetText()==text and p:IsShown())
            assert(p.message:GetText():find('nothing was truncated',1,true))
        ''')

    def test_filter_controls_search_sort_revisit_and_position(self):
        self.lua.execute('''
            for i=1,20 do now=now+1;j:Create('person',{title=string.format('Person %02d',i),notes='Needle '..i}) end
            flush();click(m.next);assert(c.state.offset==7);local first=m.rows[1].id
            j:Changed();flush();assert(c.state.offset==7 and m.rows[1].id==first)
            m.search:SetText('Needle 18');assert(#c.rows==1 and c.rows[1].title=='Person 18')
            click(m.rows[1]);click(m.revisit);choose(openMenu(m.filters),'Only revisit / follow up');assert(#c.rows==1)
            click(m.reset);assert(c.state.query=='' and #c.rows==20 and c.state.selected)
            click(m.sort);assert(m.rows[1].name:GetText()=='Person 20')
            local kind=openMenu(m.kind);choose(kind,'Mysteries');assert(#c.rows==0)
        ''')

    def test_exact_atlas_geometry_map_meanings_and_manual_placement(self):
        self.lua.execute('''
            local e=assert(j:Create('landmark',{title='Synthetic monument'}));c:Select(e.id)
            c:Location();local p=c.panels.location
            assert(p.meaningID=='observation');p.zone:SetText('Synthetic coast');p.mapID:SetText('101');p.x:SetText('25');p.y:SetText('75');click(p.save)
            c:SetView('location');assert(e.locations[1].meaning=='observation' and e.locations[1].x==2500)
            assert(m.map.point[1]=='TOP' and m.map.point[2]==m and m.map.point[3]=='TOPLEFT' and m.map.point[4]==632 and m.map.point[5]==-205)
            local adapter={Get=function() end,List=function() return {} end,Layer=function() return true end,WeatherText=function() return '' end}
            local atlas=ns.CreateAtlasMap(CreateFrame('Frame'),adapter,function() end,function() end);atlas:Render(101)
            assert(atlas:GetWidth()==m.map:GetWidth() and atlas:GetHeight()==m.map:GetHeight())
            local pin=m.map.pins[1];pin.scripts.OnEnter(pin);assert(snapshot(GameTooltip.lines):find('Observation position',1,true))
            c:Location(nil,{meaning='landmark',zone='Synthetic coast',mapID=101,x=6000,y=3000,precision='manual'})
            click(p.save);assert(#e.locations==2 and e.locations[2].meaning=='landmark' and e.locations[2].x==6000)
            assert(not AzerothFieldbookAtlasDB)
            c:SetView('entry');assert(not m.map:IsShown() and m.reader:IsShown())
        ''')

    def test_empty_location_map_uses_darkened_current_map_without_saving_it(self):
        self.lua.execute('''
            local e=writing();c:Select(e.id);c:SetView('location')
            assert(m.map.available and m.map.subzoneMapID==101 and m.map.emptyShade:IsShown())
            assert(m.map.emptyShade.colorTexture[4]==0.48 and m.map.empty:IsShown())
            assert(m.map.empty.point[1]=='CENTER' and m.map.empty.point[2]==m.map)
            assert(#e.locations==0 and c.state.mapID==nil and not AzerothFieldbookAtlasDB)
            local adapter={Get=function() end,List=function() return {} end,Layer=function() return true end,WeatherText=function() return '' end}
            local atlas=ns.CreateAtlasMap(CreateFrame('Frame'),adapter,function() end,function() end);atlas:Render(101)
            assert(atlas:GetWidth()==m.map:GetWidth() and atlas:GetHeight()==m.map:GetHeight())
            mapID=102;m.map:Render();assert(m.map.subzoneMapID==102 and m.map.emptyShade:IsShown())
            -- Explicit map browsing remains usable for deliberate landmark placement.
            c.state.mapID=101;m.map:Render();assert(m.map.subzoneMapID==101 and not m.map.emptyShade:IsShown())
            c.state.mapID=nil;C_Map.GetMapArtLayers=function() end;m.map:Invalidate();m.map:Render()
            assert(not m.map.available and not m.map.emptyShade:IsShown() and m.map.empty:IsShown())
            mapID=nil;m.map:Render();assert(not m.map.available and m.map.empty:IsShown())
            assert(#e.locations==0 and c.state.mapID==nil)
        ''')

    def test_relationships_known_records_missing_safe_and_delete_keeps_evidence(self):
        self.lua.execute('''
            local mystery=assert(j:Create('mystery',{title='Who built it?'}));local evidence=writing('Stone inscription')
            c:Select(mystery.id);c:Relationships();local p=c.panels.links
            p.search:SetText('Stone inscription');p.reason:SetText('Mentions the same emblem');click(p.rows[1].action)
            assert(#mystery.links==1 and mystery.links[1].explanation=='Mentions the same emblem')
            click(p.rows[1].action);assert(#mystery.links==0 and j:Get(evidence.id))
            click(p.rows[1].action);c:ClosePanel();j:Delete(evidence.id)
            c:Relationships();click(p.mode);assert(p.rows[1]:GetText():find('[unavailable]',1,true))
            click(p.rows[1].open);assert(p.message:GetText():find('reference is retained',1,true))
            local other=writing('Other evidence');j:AddLink(mystery.id,{section='lore',id=other.id,label=other.title})
            j:Delete(mystery.id);assert(j:Get(other.id))
        ''')

    def test_report_sources_are_separate_readable_and_mapped_as_reports(self):
        self.lua.execute('''
            local e=writing();e.reports={{sender='Claimed author',receivedFrom='Recorded sender',received=now,sourceTitle='Reported title',
                pages={{number=1,raw='Received text',nature='source',origin='captured',method='displayed',personallyViewed=true}},
                passages={},annotations={notes='Sender chose to share'},references={},
                locations={{zone='Synthetic hills',mapID=102,x=3500,y=4500,meaning='read-here',origin='captured'}}}}
            c:Select(e.id);c:Page(0,'report:1:page:1')
            local text=m.reader.header:GetText();assert(text:find('Recorded sender',1,true) and text:find('Claimed author',1,true))
            assert(text:find('Not personally encountered',1,true) and m.reader.text:GetText():find('Received text',1,true))
            assert(e.pages[1].raw:find('First paragraph',1,true) and e.notes=='')
            c:SetView('location');assert(m.locationMenu:GetText():find('Reported location',1,true))
            assert(m.locationMenu:GetText():find('Read here',1,true))
            c:Location(1);assert(not c.panels.location.remove:IsShown())
        ''')

    def test_report_claims_without_recorded_sender_do_not_become_received_from(self):
        self.lua.execute('''
            local e=writing();e.reports={{sender='Payload sender',originalSource='Claimed original observer',received=now,
                sourceTitle='Reported title',pages={{number=1,raw='Received text',nature='source',origin='captured',method='displayed'}},
                passages={},annotations={},references={},locations={}}}
            c:Select(e.id);c:Page(0,'report:1:page:1')
            local text=m.reader.header:GetText()
            assert(text:find('Sender claim: Payload sender',1,true))
            assert(text:find('Claimed original observer',1,true))
            assert(not text:find('Received from Payload sender',1,true))
            c:Page(0,'report:1');text=m.reader.text:GetText()
            assert(text:find('Sender claim: Payload sender',1,true) and text:find('Claimed original observer',1,true))
        ''')

    def test_encounter_dates_are_visible_separate_from_note_updates(self):
        self.lua.execute('''
            local e=writing();e.firstEncounter=now-200;e.lastEncounter=now-100;c:Select(e.id);c:Page(0,'overview')
            local text=m.reader.text:GetText()
            assert(text:find('First encounter',1,true) and text:find('Last encounter',1,true))
            assert(text:find(ns.AtlasUI.Date(e.firstEncounter),1,true) and text:find(ns.AtlasUI.Date(e.lastEncounter),1,true))
            now=now+100;j:Update(e.id,{notes='Later interpretation'});flush()
            assert(e.lastEncounter==now-200)
        ''')

    def test_unsupported_or_malformed_archive_has_visible_preservation_notice(self):
        self.lua.execute('''
            for _,db in ipairs({{schema=999,entries={untouched={raw='Preserve me'}}},{schema=1,entries={broken={title='Malformed'}}}}) do
                local before=snapshot(db);local other=ns.CreateLoreJournal(db)
                local host=ns.CreateFieldbookShell();local book=ns.CreateLoreBook(other,t,host);host:ShowSection('lore')
                local text=book.main.message:GetText()..' '..book.main.empty:GetText()..' '..book.main.captureStatus:GetText()
                assert(text:lower():find('preserv',1,true),'Missing visible saved-data preservation notice')
                if db.schema==999 then assert(snapshot(db)==before and other.readOnly) end
            end
        ''')

    def test_annotation_removal_and_record_delete_require_explicit_action(self):
        self.lua.execute('''
            local e=writing();local p=assert(j:AddPassage(e.id,{raw='Manual note',nature='annotation',origin='manual',method='manual'}))
            c:Select(e.id);c:RemovePassage();local panel=c.panels.removePassage
            local choices=openMenu(panel.choose);choices.children[1].action();assert(#e.passages==1)
            click(panel.confirm);assert(#e.passages==0 and e.pages[1])
            local menu=openMenu(m.more);choose(menu,'Delete entry…');assert(j:Get(e.id))
            click(c.panels.confirm.accept);assert(not j:Get(e.id))
        ''')

    def test_readonly_reference_adapter_and_all_scale_inheritance(self):
        self.lua.execute('''
            local external={x={name='Known geography'}};local called
            c.references:Register('atlas',{title='Traveller’s Atlas',list=function() return {{key='x',name=external.x.name}} end,
                resolve=function(key) return external[key] and {name=external[key].name} end,
                open=function(key) called=key;return true end})
            local rows=c.references:List('geography');assert(#rows==1 and rows[1].section=='atlas')
            assert(c.references:Open(rows[1]) and called=='x')
            local e=writing();c:Select(e.id);c:SetView('location')
            local root=shell:GetFrame();local w,h=root:GetWidth(),root:GetHeight()
            for _,scale in ipairs({0.5,0.75,1,1.25,1.5}) do root:SetScale(scale);c:Refresh()
                assert(m.map:GetEffectiveScale()==root:GetEffectiveScale() and root:GetWidth()==w and root:GetHeight()==h)
            end
            assert(external.x.name=='Known geography')
        ''')

    def test_widgets_reused_and_runtime_map_anchor_is_identical(self):
        self.lua.execute('''
            local e=writing();c:Select(e.id)
            for i=1,2 do
                c:Edit(nil,e.id);c:ClosePanel();c:Passage();c:ClosePanel();c:Location();c:ClosePanel()
                c:Relationships();c:ClosePanel();c:RemovePassage();c:ClosePanel()
                if i==1 then count=#objects else assert(#objects==count) end
            end
        ''')
        anchor = 'm.map:SetPoint("TOP",m,"TOPLEFT",632,-205)'
        self.assertIn(anchor, (ROOT / 'LoreBook.lua').read_text(encoding='utf-8'))
        self.assertIn(anchor, (ROOT / 'AtlasBook.lua').read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
