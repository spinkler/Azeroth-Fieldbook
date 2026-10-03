"""Player translation round trips; synthetic Lua host, no native-language decoding."""
import unittest

from ui_test_harness import ROOT, new_ui_client
from test_lore_ui import new_lore_ui


class TranslationTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_ui_client(['AtlasJournal.lua', 'LoreJournal.lua', 'LoreReports.lua'])
        self.lua.execute('''
            L=ns.Lore;R=ns.LoreReports
            owner=ns.CreateLoreJournal({});helper=ns.CreateLoreJournal({})
            original=assert(owner:CapturePage({sessionID='tablet',title='Tablet'},
                {number=1,raw='Anu thera',first=true,last=true,method='displayed'}))
            function receive(j,report,id)
                return assert(R.Accept(j,assert(R.Prepare(assert(R.Encode(report)),'Courier')),id))
            end
            shared=receive(helper,assert(R.Build(owner,original.id)))
            function contribution(raw)
                return {raw=raw or 'Readable player translation',origin='manual',nature='translation',method='manual',source='Tablet',
                    translation={translator='Translator-Realm',fromLanguage='Darnassian',toLanguage='Common',
                        sourceTitle='Tablet',sourceRaw='Anu thera',page=1}}
            end
        ''')

    def test_return_forward_reload_search_and_original_preservation(self):
        self.lua.execute('''
            local t=assert(helper:AddPassage(shared.id,contribution()))
            assert(not t.private and not t.personallyViewed and shared.origin=='reported')
            local report=assert(R.Build(helper,shared.id))
            assert(#report.pages==0 and #report.passages==1 and report.version==2)
            local preview=assert(R.Preview(report))
            assert(preview:find('Anu thera',1,true) and preview:find('Translator-Realm',1,true))
            local result=receive(owner,report,original.id)
            assert(result.pages[1].raw=='Anu thera' and #result.passages==0)
            assert(result.reports[1].passages[1].raw=='Readable player translation')
            assert(#owner:List({query='translator-realm'})==1 and #owner:List({query='darnassian'})==1)
            owner=ns.CreateLoreJournal(owner.db)
            local saved=owner:Get(original.id).reports[1].passages[1].translation
            assert(saved.sourceRaw=='Anu thera' and saved.translator=='Translator-Realm' and saved.page==1)
            local forwarded=assert(R.Build(owner,original.id,{report=1}))
            assert(forwarded.passages[1].translation.translator=='Translator-Realm')
            local third=ns.CreateLoreJournal({});local copy=receive(third,forwarded)
            assert(copy.reports[1].passages[1].translation.sourceRaw=='Anu thera')
            assert(next(copy.pages)==nil and not copy.firstEncounter)
            assert(helper:Delete(shared.id))
            assert(copy.reports[1].passages[1].raw=='Readable player translation')
        ''')

    def test_distinct_originals_and_authors_do_not_deduplicate(self):
        self.lua.execute('''
            local a=assert(helper:AddPassage(shared.id,contribution()))
            assert(helper:AddPassage(shared.id,contribution()).id==a.id)
            local b=contribution();b.translation.sourceRaw='Different original'
            assert(helper:AddPassage(shared.id,b).id~=a.id)
            local c=contribution();c.translation.translator='Another translator'
            assert(helper:AddPassage(shared.id,c).id~=a.id)
            assert(#helper:Get(shared.id).passages==3)
            helper=ns.CreateLoreJournal(helper.db)
            assert(#helper:Get(shared.id).passages==3)
        ''')

    def test_invalid_metadata_text_and_capacity_refuse_without_truncating(self):
        self.lua.execute('''
            for _,field in ipairs({'translator','fromLanguage','toLanguage','sourceTitle','sourceRaw'}) do
                local p=contribution();p.translation[field]='';assert(not helper:AddPassage(shared.id,p))
            end
            local p=contribution();p.translation.extra=true;assert(not helper:AddPassage(shared.id,p))
            p=contribution();p.translation.sourceRaw=string.rep('x',131073);assert(not helper:AddPassage(shared.id,p))
            p=contribution();p.translation.page=-1;assert(not helper:AddPassage(shared.id,p))
            p=contribution();p.nature='source';assert(not helper:AddPassage(shared.id,p))
            L.MAX_WORK_BYTES=10
            assert(not helper:AddPassage(shared.id,contribution()))
            assert(#helper:Get(shared.id).passages==0)
        ''')

    def test_report_schema_and_metadata_validation_preserve_legacy_reports(self):
        self.lua.execute('''
            local legacy=assert(R.Build(owner,original.id));legacy.version=1
            assert(R.Normalize(legacy).version==2)
            legacy.received=1;legacy.receivedFrom='Old courier'
            assert(R.NormalizeStored(legacy).pages[1].raw=='Anu thera')
            assert(helper:AddPassage(shared.id,contribution()))
            local report=assert(R.Build(helper,shared.id))
            report.version=1;assert(not R.Normalize(report))
            report.version=2;report.passages[1].translation.extra='bad';assert(not R.Normalize(report))
            report.passages[1].translation.extra=nil;report.passages[1].translation.sourceRaw=string.rep('x',131073)
            assert(not R.Normalize(report))
            report=assert(R.Build(helper,shared.id));report.version=99;assert(not R.Normalize(report))
            report=assert(R.Build(helper,shared.id));report.addonVersion='0.0.1';assert(not R.Normalize(report))
        ''')

    def test_private_translation_requires_explicit_export(self):
        self.lua.execute('''
            local p=contribution();p.private=true;assert(helper:AddPassage(shared.id,p))
            assert(#R.Build(helper,shared.id).passages==0)
            assert(#R.Build(helper,shared.id,{interpretations=true}).passages==1)
        ''')


class TranslationUITests(unittest.TestCase):
    def setUp(self):
        self.lua = new_lore_ui()

    def test_editor_drafts_reader_and_original_snapshot(self):
        self.lua.execute('''
            local e=writing();c:Select(e.id);c:Page(0,'page:1')
            choose(openMenu(m.more),'Add translation of selected text')
            local p=c.panels.translation
            assert(p:IsShown() and p.to:GetText()=='Common' and p.from:GetText()=='')
            p.from:SetText('Darnassian');p.raw:SetText('Player supplied readable version')
            c:ClosePanel();c:Translation()
            assert(p.raw:GetText()=='Player supplied readable version' and p.from:GetText()=='Darnassian')
            click(p.save)
            local t=j:Get(e.id).passages[1];assert(t.nature=='translation' and not t.private)
            assert(t.translation.sourceRaw==e.pages[1].raw and t.translation.translator==L.Player())
            assert(m.reader.text:GetText()=='Player supplied readable version')
            assert(m.reader.header:GetText():find('Darnassian',1,true))
            c:Page(0,'passage:'..t.id..':original')
            assert(m.reader.text:GetText()==L.Plain(e.pages[1].raw))
            assert(e.pages[1].raw:find('<HTML>',1,true))
            c:Page(0,'page:3');c:Translation();assert(p.raw:GetText()=='')
        ''')

    def test_requires_source_selection_and_rejects_private_passages(self):
        self.lua.execute('''
            local e=writing();c:Select(e.id);c:Page(0,'overview');c:Translation()
            assert(not c.panels.translation)
            c:Page(0,'page:2');c:Translation();assert(not c.panels.translation)
            local p=assert(j:AddPassage(e.id,{raw='Private source',nature='source',private=true}))
            c:Page(0,'passage:'..p.id);c:Translation();assert(not c.panels.translation)
        ''')

    def test_explicitly_uses_own_readable_capture_without_title_auto_merge(self):
        self.lua.execute('''
            local original=writing();local readable=writing()
            readable.pages[1].raw='Readable captured version';j:Changed(readable)
            c:Select(original.id);c:Page(0,'page:1');c:Translation()
            local p=c.panels.translation;p.from:SetText('Darnassian')
            local choices=openMenu(p.captured);local found=false
            for _,choice in ipairs(choices.children) do if choice.label:find('Readable captured version',1,true) then
                choice.action();found=true;break
            end end
            assert(found and p.raw:GetText()=='Readable captured version')
            click(p.save)
            assert(j:Get(original.id).passages[1].raw=='Readable captured version')
            assert(j:Get(original.id).pages[1].raw~=readable.pages[1].raw)
            assert(j:Get(readable.id) and #j:Get(readable.id).passages==0)
        ''')

    def test_translation_of_received_page_and_report_reader(self):
        self.lua.execute((ROOT / 'LoreReports.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', self.lua.globals().ns)
        self.lua.execute('''
            local e=writing();local R=ns.LoreReports
            local report=assert(R.Build(j,e.id));local other=ns.CreateLoreJournal({})
            local received=assert(R.Accept(other,assert(R.Prepare(report))))
            local copied=assert(j:Create('writing',{title='Received work',origin='reported',reports=received.reports}))
            c:Select(copied.id);c:Page(0,'report:1:page:1');c:Translation()
            local p=c.panels.translation;p.from:SetText('Darnassian');p.raw:SetText('Readable text');click(p.save)
            local translation=assert(R.Build(j,copied.id))
            assert(R.Accept(j,assert(R.Prepare(translation)),e.id));c:Select(e.id)
            c:Page(0,'report:1:passage:1');assert(m.reader.text:GetText()=='Readable text')
            assert(m.reader.header:GetText():find('Received report',1,true))
            c:Page(0,'report:1:passage:1:original')
            assert(m.reader.text:GetText()==L.Plain(e.pages[1].raw))
        ''')


if __name__ == '__main__':
    unittest.main()
