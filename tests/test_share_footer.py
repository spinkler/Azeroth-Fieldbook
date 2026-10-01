"""Stationary Share entry points and retained actions in the synthetic widget host."""
import unittest

from ui_test_harness import ROOT, new_ui_client
from atlas_test_harness import new_atlas
from angling_test_harness import new_angling
from ledger_test_harness import new_ledger
from test_lore_ui import new_lore_ui


FOOTER = '''
    function checkFooter(button)
        assert(button:GetText()=='Share')
        assert(button.point[1]=='TOPLEFT' and button.point[2]==42 and button.point[3]==-672)
        assert(button:GetWidth()==120 and button:GetHeight()==24)
    end
'''


class ShareFooterTests(unittest.TestCase):
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
