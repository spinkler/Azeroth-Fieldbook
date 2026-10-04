"""Stationary Share entry points and retained actions in the synthetic widget host."""
import unittest

from ui_test_harness import ROOT, new_ui_client
from atlas_test_harness import new_atlas
from angling_test_harness import new_angling
from ledger_test_harness import new_ledger
from test_lore_ui import new_lore_ui
from treasure_test_harness import new_treasure
from test_gathering import client as new_gathering


FOOTER = '''
    function checkFooter(button)
        assert(button:GetText()=='Share')
        assert(button.point[1]=='TOPLEFT' and button.point[2]==42 and button.point[3]==-672)
        assert(button:GetWidth()==120 and button:GetHeight()==24)
    end
'''


class ShareFooterTests(unittest.TestCase):
    def test_delete_footers_match_across_journals(self):
        for factory, button, width in (
            (new_atlas, 'm.deleteButton', 118), (new_angling, 'm.deleteButton', 118),
            (new_ledger, 'm.remove', 120), (new_treasure, 'm.remove', 118),
        ):
            lua = factory(ui=True)
            lua.execute(f'''
                local b={button}
                assert(b:GetText()=='Delete' and b.point[2]==174 and b.point[3]==-672)
                assert(b:GetWidth()=={width} and b:GetHeight()==24 and not b.enabled)
            ''')
        lua = new_lore_ui()
        lua.execute("assert(m.deleteButton:GetText()=='Delete' and m.deleteButton.point[2]==174 and m.deleteButton.point[3]==-672 and not m.deleteButton.enabled)")
        lua = new_gathering(ui=True)
        lua.execute('''
            shell:ShowSection('gathering');local b=gathering.frame.deleteButton
            assert(b:GetText()=='Delete' and b.point[2]==174 and b.point[3]==-672 and not b.enabled)
        ''')

    def test_angling_delete_uses_only_displayed_view_and_keeps_history(self):
        lua = new_angling(ui=True)
        lua.execute('''
            local place=spot('Selected spot','Selected pool')
            local fact=observe('one','pool',place.poolID,place.id)
            local water=j:Get(fact.waterID);local pool=j:Get(place.poolID);local fish=j:List('catches')[1]
            local history=snapshot(saved.history);local facts=snapshot(saved.aggregates)
            for _,e in ipairs({place,pool,water,fish}) do
                c:Select(e.id);assert(m.deleteButton.enabled)
                local view=saved.state.view
                c:SetView(view=='catches' and 'pools' or 'catches')
                c:State().selected=e.id;c:Refresh()
                assert(not m.deleteButton.enabled,'foreign selection must be disabled')
                m.deleteButton.scripts.OnClick(m.deleteButton);assert(not e.removed)
                c:Select(e.id);click(m.deleteButton)
                assert(not e.removed and m.deleteForm:IsShown())
                click(m.deleteForm.cancel);assert(not e.removed and not m.deleteForm:IsShown())
                click(m.deleteButton);click(m.deleteForm.confirm)
                assert(e.removed and not m.deleteButton.enabled and c:State().selected==nil)
                assert(history==snapshot(saved.history) and facts==snapshot(saved.aggregates))
                c:State().status='removed';c:Refresh();c:Select(e.id)
                assert(not m.deleteButton.enabled and m.restore:IsShown() and m.restore.enabled)
                assert(m.restore:GetText()=='Restore')
                click(m.restore);assert(not e.removed)
            end
            c:Select(fish.id);click(m.deleteButton);c:Select(pool.id)
            click(m.deleteForm.confirm);assert(not fish.removed and not pool.removed)
            c:Select(fish.id);click(m.deleteButton);j.readOnly=true
            click(m.deleteForm.confirm);assert(not fish.removed)
            j.readOnly=false;click(m.deleteButton);click(m.deleteForm.cancel)
            m.deleteForm.confirm.scripts.OnClick(m.deleteForm.confirm);assert(not fish.removed)
            c:Select(fish.id);j.readOnly=true;c:Refresh()
            assert(not m.deleteButton.enabled);m.deleteButton.scripts.OnClick(m.deleteButton);assert(not fish.removed)
            j.readOnly=false;c:Refresh();c:OpenReports()
            m.deleteButton.scripts.OnClick(m.deleteButton);assert(not fish.removed)
        ''')

    def test_atlas_and_lore_confirmations_reject_changed_selection(self):
        lua = new_atlas(ui=True)
        lua.execute('''
            local first=j:Save(fixture('First'));local second=j:Save(fixture('Second'))
            c:Select(first);click(m.deleteButton);c:Select(second)
            click(m.deleteForm.confirm);assert(j:Get(first) and j:Get(second))
            c:Select(first);click(m.deleteButton);click(m.deleteForm.cancel);assert(j:Get(first))
            click(m.deleteButton);click(m.deleteForm.confirm)
            assert(not j:Get(first) and j:Get(second) and not m.deleteButton.enabled)
        ''')
        lua = new_lore_ui()
        lua.execute('''
            local first=writing('First');local second=writing('Second')
            c:Select(first.id);click(m.deleteButton);c:Select(second.id)
            click(m.deleteForm.confirm);assert(j:Get(first.id) and j:Get(second.id))
            c:ClosePanel();c:Select(first.id);click(m.deleteButton);click(m.deleteForm.cancel);assert(j:Get(first.id))
            click(m.deleteButton);click(m.deleteForm.confirm)
            assert(not j:Get(first.id) and j:Get(second.id))
        ''')

    def test_gathering_delete_requires_current_selection_and_confirmation(self):
        lua = new_gathering(ui=True)
        lua.execute('''
            local a={id=journal:Discover('herb','Silverleaf',100,'Elwynn',37)}
            local b={id=journal:Discover('mineral','Copper Vein',100,'Elwynn',37)}
            shell:ShowSection('gathering');local book=gathering.frame
            local function selectEntry(id)
                for _,row in ipairs(book.rows) do if row.id==id then row.scripts.OnClick(row);return end end
                error('fixture row missing')
            end
            selectEntry(a.id)
            book.deleteButton.scripts.OnClick(book.deleteButton);assert(journal.entries[a.id])
            assert(not book.deleteForm.confirm.enabled)
            book.deleteForm.input:SetText('DELETE');book.deleteForm.confirm.scripts.OnClick(book.deleteForm.confirm)
            assert(journal.entries[a.id])
            book.deleteForm.cancel.scripts.OnClick(book.deleteForm.cancel);assert(not book.deleteForm:IsShown())
            book.deleteButton.scripts.OnClick(book.deleteButton)
            selectEntry(b.id)
            book.deleteForm.input:SetText('delete');book.deleteForm.input.scripts.OnEnterPressed(book.deleteForm.input)
            assert(journal.entries[a.id] and journal.entries[b.id])
            book.deleteButton.scripts.OnClick(book.deleteButton)
            book.deleteForm.input:SetText('delete');book.deleteForm.input.scripts.OnEnterPressed(book.deleteForm.input)
            assert(journal.entries[a.id] and not journal.entries[b.id])
            assert(journal:Discover('mineral','Copper Vein',101,'Elwynn',37)==b.id)
            gathering:Refresh();selectEntry(b.id);assert(book.deleteButton.enabled)
        ''')

    def test_ledger_and_treasure_reject_foreign_or_stale_targets(self):
        lua = new_ledger(ui=True)
        lua.execute('''
            local first=visit(42);local second=visit(43);flush()
            c:Select(first.id);click(m.remove);c:Select(second.id)
            click(c.panels.remove.confirm);assert(j:Get(first.id) and j:Get(second.id))
            c:ClosePanel();c:Select(first.id);click(m.remove);click(c.panels.remove.confirm)
            assert(not j:Get(first.id) and j:Get(second.id))
            local fresh=visit(42);flush()
            assert(fresh.id~=first.id and j:Get(fresh.id) and next(fresh.goods))
        ''')
        lua = new_treasure(ui=True)
        lua.execute('''
            local first,v=record('First');local second,w=record('Second')
            c:Select(first.id);c:Encounter(w.id)
            assert(not m.remove.enabled);m.remove.scripts.OnClick(m.remove)
            assert(not c.panels.remove and j.encounters[w.id])
            c:Encounter(v.id);assert(m.remove.enabled)
            for _,row in ipairs(m.rows) do
                if row:IsShown() then assert(-row.point[3]+row:GetHeight()<=604,'catalogue overlaps footer controls') end
            end
        ''')

    def test_atlas_angling_and_ledger_keep_footer_and_maps_when_switching(self):
        for factory, section, button, action in (
            (new_atlas, 'atlas', 'm.shareButton', 'assert(c.pages.report:IsShown())'),
            (new_angling, 'angling', 'm.reports', 'assert(c.panels.reports:IsShown())'),
            (new_ledger, 'merchants', 'm.reports', 'assert(c.panel==c.panels.reports)'),
        ):
            with self.subTest(section=section):
                lua = factory(ui=True)
                lua.execute(FOOTER)
                lua.globals().section = section
                lua.execute(f'''
                    local mapPoint=m.map.point
                    local mapWidth,mapHeight=m.map:GetWidth(),m.map:GetHeight()
                    local rootWidth,rootHeight=shell:GetFrame():GetWidth(),shell:GetFrame():GetHeight()
                    for i=1,3 do
                        shell:ShowSection('other');shell:ShowSection(section)
                        checkFooter({button})
                        assert(m.map.point==mapPoint and m.map.point[5]==-205)
                        assert(m.map:GetWidth()==mapWidth and m.map:GetHeight()==mapHeight)
                        assert(shell:GetFrame():GetWidth()==rootWidth and shell:GetFrame():GetHeight()==rootHeight)
                    end
                    click({button});{action}
                ''')

    def test_bestiary_keeps_footer_when_selection_changes(self):
        lua = new_ui_client(['SharingReport.lua', 'BestiaryJournal.lua', 'Scrollbars.lua',
            'ActionButtons.lua', 'FieldbookShell.lua', 'BestiaryPages.lua', 'BestiaryBook.lua'])
        lua.execute(FOOTER + '''
            j=ns.CreateBestiaryJournal({},function() return npcID end)
            j.sharing={HasActiveOutgoing=function() return false end}
            ns.CreateSharingWindow=function()
                return {Open=function(_,id) offeredID=id end,Refresh=function() end,Hide=function() end,
                    SetVisibilityCallback=function() end}
            end
            shell=ns.CreateFieldbookShell()
            c=ns.CreateBestiaryBook(j,shell);c:OpenAtUnit('target')
            m=AzerothFieldbookBestiarySection;checkFooter(m.shareButton)
            m.shareButton.scripts.OnClick(m.shareButton);assert(offeredID==npcID)
            assert(m.deleteButton.point[2]==174 and m.deleteButton.point[3]==-672)
            npcID=43;c:OpenAtUnit('target');checkFooter(m.shareButton)
            m.shareButton.scripts.OnClick(m.shareButton);assert(offeredID==43)
            m.deleteButton.scripts.OnClick(m.deleteButton);assert(j.entries[43] and not m.deleteForm.confirm.enabled)
            m.deleteForm.input:SetText('Delete');m.deleteForm.confirm.scripts.OnClick(m.deleteForm.confirm);assert(j.entries[43])
            m.deleteForm.cancel.scripts.OnClick(m.deleteForm.cancel);assert(j.entries[43] and not m.deleteForm:IsShown())
            m.deleteButton.scripts.OnClick(m.deleteButton);m.deleteForm.input:SetText('delete')
            assert(m.deleteForm.confirm.enabled)
            m.deleteForm.input.scripts.OnEscapePressed(m.deleteForm.input);assert(j.entries[43] and not m.deleteForm:IsShown())
            m.deleteButton.scripts.OnClick(m.deleteButton);assert(m.deleteForm.input:GetText()=='' and not m.deleteForm.confirm.enabled)
            m.deleteForm.input:SetText('delete')
            m.deleteForm.confirm.scripts.OnClick(m.deleteForm.confirm);assert(not j.entries[43])
        ''')

    def test_lore_export_import_and_capture_remain_available_from_both_views(self):
        lua = new_lore_ui()
        for name in ('LoreReports.lua', 'LoreReportUI.lua'):
            lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute(FOOTER + '''
            c.reportUI=ns.CreateLoreReportUI(c.frame,j,function() return c.state.selected end,nil,shell)
            assert(m.import==nil and m.capture==nil)
            checkFooter(m.shareButton)
            choose(openMenu(m.shareButton),'Import report')
            assert(c.reportUI.mode=='import' and c.reportUI.panel:IsShown())
            c.reportUI:Close()
            local e=writing();c:Select(e.id)
            for _,view in ipairs({'entry','location'}) do
                c:SetView(view);checkFooter(m.shareButton);assert(m.shareButton:IsShown())
                choose(openMenu(m.shareButton),'Export report')
                assert(c.reportUI.mode=='export' and c.reportUI.id==e.id)
                assert(not c.reportUI.panel.checks.notes:GetChecked())
                c.reportUI:Close()
            end
            local captures=0
            t.CaptureCurrent=function() captures=captures+1;return true end
            choose(openMenu(m.new),'Capture / retry current text');assert(captures==1)
        ''')

    def test_ledger_scroll_clamps_to_shorter_viewport_and_reaches_last_contact(self):
        lua = new_ledger(ui=True)
        lua.execute('''
            for i=1,30 do visit(100+i);now=now+1 end
            flush();m.contactList.scripts.OnVerticalScroll(m.contactList,100000)
            local maximum=m.listBody:GetHeight()-m.contactList:GetHeight()
            assert(c.state.contactScroll==maximum and maximum>0)
            assert(m.contactList.point[3]-m.contactList:GetHeight()==-632)
            assert(m.manual.point[3]==-638 and m.reports.point[3]==-672)
            local found=false
            for _,row in ipairs(m.rows) do if row.id==c.rows[#c.rows].contact.id then found=true end end
            assert(found,'last contact is unreachable after shortening the list')
        ''')


if __name__ == '__main__':
    unittest.main()
