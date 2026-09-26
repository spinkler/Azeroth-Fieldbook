"""Section navigation and shared-window lifetime, independent of Bestiary data."""
import unittest
from ui_test_harness import ROOT, new_ui_client


class FieldbookShellTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_ui_client([
            'Scrollbars.lua', 'WindowFocus.lua', 'WindowPositions.lua',
            'UIScale.lua', 'FieldbookShell.lua',
        ])
        self.lua.execute('''
            settings={uiScale=1.25,windowPositions={
                AzerothFieldbookBestiary={left=300,top=900}
            }}
            ns.UIScale:Initialize(settings)
            shell=ns.CreateFieldbookShell({getBrightness=function() return 0.8 end})
            builds,opens,leaves=0,0,0
            function section(id,title)
                shell:RegisterSection(id,{
                    title=title,frameName='TestSection'..id,
                    build=function(content)
                        builds=builds+1
                        content.selection='saved selection'
                        content.control=CreateFrame('Button',nil,content)
                        content.dialog=CreateFrame('Frame',nil,UIParent)
                        content:SetScript('OnHide',function() content.dialog:Hide() end)
                        local help=shell:CreatePage('TestHelp'..id,title..' Help',24)
                        local options=shell:CreatePage('TestOptions'..id,title..' Options',65)
                        help:Hide();options:Hide()
                        shell:SetSectionPages(id,{help=help,options=options})
                    end,
                    onOpen=function(context) opens=opens+1;lastContext=context end,
                    onLeave=function() leaves=leaves+1 end,
                })
            end
            section('one','First');section('two','Second')
        ''')

    def test_lazy_build_and_reuse_with_legacy_position_and_escape(self):
        self.lua.execute('''
            assert(shell:GetFrame()==nil and builds==0)
            assert(shell:ShowSection('one','context'))
            local root=shell:GetFrame()
            local content=shell.sections.one.frame
            assert(root==AzerothFieldbookBestiary and content.parent==root)
            assert(root.point[2]==UIParent and root.point[4]==300/1.25,
                'existing saved position is restored onto the shell')
            assert(builds==1 and opens==1 and lastContext=='context')
            assert(root.windowTitle:GetText()=='Azeroth Fieldbook - First - v'..buildVersion)
            local escape=0
            for _,name in ipairs(UISpecialFrames) do if name==root:GetName() then escape=escape+1 end end
            assert(escape==1,'Escape closes the shared root exactly once')
            root.closeButton.scripts.OnClick()
            assert(not root:IsShown() and not content:IsShown())
            shell:Toggle()
            assert(shell:IsSectionShown('one') and builds==1 and opens==2)
            assert(content.selection=='saved selection')
            shell:ToggleSection('one');assert(not root:IsShown())
            assert(not shell:ShowSection('missing') and builds==1)
            assert(not pcall(function() section('one','Duplicate') end))
        ''')

    def test_switching_preserves_content_and_closes_section_windows(self):
        self.lua.execute('''
            shell:ShowSection('one')
            local first=shell.sections.one
            first.frame.selection='keep me'
            first.frame.dialog:Show()
            shell:TogglePage('help');assert(first.pages.help:IsShown())
            shell:ShowSection('two')
            assert(builds==2 and leaves==1 and not first.frame:IsShown())
            assert(not first.frame.dialog:IsShown() and not first.pages.help:IsShown())
            shell:SetSectionSize('two',800,680)
            shell:SetSectionSize('one',960,780)
            assert(shell:GetFrame():GetWidth()==800 and shell:GetFrame():GetHeight()==680,
                'an inactive section cannot resize the active section')
            shell:ShowSection('one')
            assert(builds==2 and first.frame.selection=='keep me')
            assert(shell:GetFrame():GetWidth()==960 and shell:GetFrame():GetHeight()==780)
            assert(not shell.sections.two.frame:IsShown())
            first.frame.control.scripts.OnMouseDown(first.frame.control)
            assert(focusedWindow==shell:GetFrame(),'section controls focus the shared window')
        ''')

    def test_toolbar_routes_to_active_pages_and_content_inherits_scale_once(self):
        self.lua.execute('''
            shell:ShowSection('one')
            local root=shell:GetFrame()
            root.helpButton.scripts.OnClick()
            assert(shell.sections.one.pages.help:IsShown())
            root.optionsButton.scripts.OnClick()
            assert(not shell.sections.one.pages.help:IsShown() and shell.sections.one.pages.options:IsShown())
            assert(root:GetScale()==1.25 and shell.sections.one.frame:GetScale()==1)
            assert(shell.sections.one.frame:GetEffectiveScale()==1.25)
            ns.UIScale:Set(0.75)
            assert(root:GetScale()==0.75 and shell.sections.one.frame:GetEffectiveScale()==0.75)
            assert(shell.sections.one.pages.help:GetScale()==0.75)
            shell:ShowSection('two')
            root.helpButton.scripts.OnClick()
            assert(shell.sections.two.pages.help:IsShown() and not shell.sections.one.pages.help:IsShown())
            assert(shell.sections.two.frame:GetEffectiveScale()==0.75,'late section inherits current scale')
            local tint=CreateFrame('Texture',nil,shell.sections.two.frame)
            local red
            tint.SetVertexColor=function(_,r) red=r end
            shell:AddBackgroundLayer(tint,0.5,0.5,0.5)
            assert(red==0.4)
            shell:SetBackgroundBrightness(1.2);assert(red==0.6)
            shell:RegisterSection('empty',{title='Empty',build=function() end})
            shell:ShowSection('empty')
            assert(not root.helpButton.enabled and not root.optionsButton.enabled and not root.eventLogButton.enabled)
            assert(not shell:TogglePage('help'))
        ''')

    def test_bestiary_returns_to_same_shell_after_another_section(self):
        for name in ['ActionButtons.lua', 'SharingReport.lua', 'BestiaryJournal.lua',
                     'BestiaryPages.lua', 'BestiaryBook.lua']:
            self.lua.execute((ROOT / name).read_text(encoding='utf-8'),
                             'AzerothFieldbook', self.lua.globals().ns)
        self.lua.execute('''
            local journal=ns.CreateBestiaryJournal(settings,function() return 42 end)
            local controller=ns.CreateBestiaryBook(journal,shell)
            shell:ShowSection('one')
            local root=shell:GetFrame()
            assert(controller:OpenAtUnit('target') and shell:IsSectionShown('bestiary'))
            assert(shell:GetFrame()==root and controller:GetShell()==shell)
            local content=AzerothFieldbookBestiarySection
            local entry=journal.entries[42]
            content.search:SetText('Creature')
            shell:ShowSection('two')
            assert(not content:IsShown() and journal.entries[42]==entry)
            controller:Toggle()
            assert(shell:IsSectionShown('bestiary') and content.search:GetText()=='Creature')
            assert(journal.entries[42]==entry and shell:GetFrame()==root)
            AzerothFieldbookSortMenu.scripts.OnShow(AzerothFieldbookSortMenu)
            assert(AzerothFieldbookSortMenu:GetScale()==root:GetScale(),
                'independent Sort popup uses the shell scale, not the child content scale')
            controller:Toggle();assert(not root:IsShown() and not content:IsShown())
            shell:Toggle();assert(shell:IsSectionShown('bestiary'))
        ''')


if __name__ == '__main__':
    unittest.main()
