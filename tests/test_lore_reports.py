"""Lore section reports: no live transport or native rendering is simulated."""
import unittest
from ui_test_harness import new_ui_client

MODULES = ['Scrollbars.lua', 'FieldbookShell.lua', 'AtlasJournal.lua', 'AtlasUI.lua',
           'LoreJournal.lua', 'LoreSettings.lua', 'LoreReports.lua', 'LoreReportUI.lua']


class LoreReportTests(unittest.TestCase):
    def test_only_new_imported_entries_emit_recorded_callback(self):
        self.lua.execute('''
            local recorded=0
            recipient.onRecorded=function(entry)
                recorded=recorded+1
                assert(recipient:Get(entry.id)==entry and entry.origin=='reported' and #entry.reports==1)
            end
            local report=build()
            local received=assert(receive(report));assert(recorded==1)
            local ticket=assert(R.Prepare(assert(R.Encode(report)),'Recorded courier'))
            R.Accept(recipient,ticket,received.id)
            assert(recorded==1,'Merging a report into an existing entry is not a new entry')
        ''')

    def setUp(self):
        self.lua = new_ui_client(MODULES)
        self.lua.execute('''
            L=ns.Lore;R=ns.LoreReports
            db={};j=ns.CreateLoreJournal(db)
            e=assert(j:Create('writing',{title='Synthetic archive',notes='PRIVATE NOTE',description='PRIVATE DESCRIPTION',tags={'private tag'}}))
            assert(j:AddPassage(e.id,{raw='Source words',origin='captured',nature='source',method='displayed',source='Stone tablet'}))
            assert(j:AddPassage(e.id,{raw='PRIVATE THEORY',origin='manual',nature='interpretation',source='My thoughts'}))
            function build(options) return assert(R.Build(j,e.id,options)) end
            function receive(report,target)
                local data=assert(R.Encode(report));local ticket=assert(R.Prepare(data,'Recorded courier'))
                return R.Accept(recipient,ticket,target)
            end
            recipient=ns.CreateLoreJournal({})
        ''')

    def test_default_preview_excludes_private_fields_and_investigation(self):
        self.lua.execute('''
            local r=build();local text=assert(R.Preview(r));local wire=assert(R.Encode(r))
            assert(#r.passages==1 and next(r.annotations)==nil and #r.references==0)
            assert(not text:find('PRIVATE',1,true) and not wire:find('PRIVATE',1,true))
            r=build({notes=true,description=true,tags=true,interpretations=true})
            assert(r.annotations.notes=='PRIVATE NOTE' and #r.passages==2)
            assert(R.Preview(r):find('PRIVATE THEORY',1,true))
        ''')

    def test_report_pages_and_provenance_survive_reload(self):
        self.lua.execute('''
            e=assert(j:CapturePage({sessionID='book',title='Book',identity='object:17',locale='enUS'},
                {number=1,raw='<HTML><BODY><P>Ω — preserved\\nwords</P></BODY></HTML>',first=true,last=true,method='automatic'}))
            local original=e.pages[1].raw;local r=build();local received=assert(receive(r))
            assert(next(received.pages)==nil and received.origin=='reported' and #received.reports==1)
            assert(received.reports[1].pages[1].raw==original and not received.reports[1].pages[1].personallyViewed)
            assert(received.reports[1].receivedFrom=='Recorded courier')
            local db2=recipient.db;local id=received.id
            metadataVersion='0.16.1'
            recipient=ns.CreateLoreJournal(db2)
            assert(recipient:Get(id) and recipient:Get(id).reports[1].pages[1].raw==original)
            assert(not R.Decode(assert(R.Encode(build())):gsub('0.16.1','0.16.0')))
        ''')

    def test_selected_page_batches_and_exact_import_deduplication(self):
        self.lua.execute('''
            e=assert(j:CapturePage({sessionID='book',title='Book'}, {number=1,raw='First',first=true,method='displayed'}))
            assert(j:CapturePage({sessionID='book',title='Book'}, {number=2,raw='Second',last=true,method='automatic'}))
            local r=build({pages={[2]=true}});assert(#r.pages==1 and r.pages[1].number==2)
            local a=assert(receive(r));local b=assert(receive(r));assert(a.id==b.id and #b.reports==1)
            local rest=build({pages={[1]=true}});local c=assert(receive(rest));assert(c.id==a.id and #c.reports==2)
            assert(next(c.pages)==nil and c.notes=='')
        ''')

    def test_attach_preserves_personal_notes_and_conflicting_source(self):
        self.lua.execute('''
            local localEntry=assert(recipient:CapturePage({sessionID='mine',title='Personal book'},
                {number=1,raw='Personal source',first=true,last=true,method='displayed'}))
            recipient:Update(localEntry.id,{notes='My own notes',theory='My own conclusion'})
            local r=build({notes=true});local result=assert(receive(r,localEntry.id))
            assert(result.notes=='My own notes' and result.theory=='My own conclusion')
            assert(result.pages[1].raw=='Personal source' and result.reports[1].annotations.notes=='PRIVATE NOTE')
            assert(#recipient:List({origin='reported',query='Source words'})==1)
        ''')

    def test_invalid_oversized_and_unsupported_inputs_fail_without_mutation(self):
        self.lua.execute('''
            local wire=assert(R.Encode(build()))
            for _,data in ipairs({'', 'return os.execute("bad")', wire..'junk', wire:sub(1,-5), 'AFBLR1:t9999999:', 'AFBLR1:'..string.rep('x',R.MAX_BYTES)}) do
                assert(not R.Prepare(data))
            end
            local r=build();r.passages[1].raw=string.rep('x',131073);assert(not R.Normalize(r))
            r=build();r.locations={{meaning='observation',zone='Here',mapID=1,x=10001,y=20}};assert(not R.Normalize(r))
            r=build();r.pages={{number=1,raw='x',method='automatic',origin='captured',nature='source',source='x',at=0,personallyViewed=true}}
            assert(not R.Normalize(r))
            r=build();r.extra=true;assert(not R.Normalize(r))
            assert(next(recipient.entries)==nil)
        ''')

    def test_atomic_capacity_failure_and_confirmation_ticket(self):
        self.lua.execute('''
            local r=build();local ticket=assert(R.Prepare(r))
            assert(not R.Accept(recipient,{}))
            R.Cancel(ticket);assert(not R.Accept(recipient,ticket))
            local a=assert(receive(r));local before=#a.reports
            R.MAX_REPORTS=before
            r.annotations.notes='another claim';local t=assert(R.Prepare(r))
            assert(not R.Accept(recipient,t,a.id) and #recipient:Get(a.id).reports==before)
            recipient.readOnly=true;assert(not R.Accept(recipient,t,a.id))
        ''')

    def test_references_are_labels_only_and_notes_need_explicit_selection(self):
        self.lua.execute('''
            local mystery=assert(j:Create('mystery',{title='Question',theory='Private theory'}))
            assert(j:AddLink(e.id,{section='lore',id=mystery.id,label='Question',explanation='Possible connection'}))
            local r=build({includeReferences=true})
            assert(#r.references==1 and r.references[1].label=='Question' and not r.references[1].id)
            local imported=assert(receive(r));assert(#imported.links==0)
            assert(not R.Encode(r):find('Private theory',1,true))
        ''')

    def test_report_widgets_preview_accept_and_invalidate_modified_input(self):
        self.lua.execute('''
            shell=ns.CreateFieldbookShell();shell:RegisterSection('lore',{title='Lore',build=function() end});shell:ShowSection('lore')
            c=ns.CreateLoreReportUI(shell.sections.lore.frame,j,function() return e.id end,function() end,shell)
            c:OpenExport();c:Prepare();assert(c.panel.data:GetText():sub(1,7)=='AFBLR1:')
            local wire=c.panel.data:GetText();assert(not c.panel.preview.text:GetText():find('PRIVATE',1,true))
            c:OpenImport();c.panel.data:SetText(wire);c:Prepare();assert(c.ticket and c.panel.accept.enabled)
            c.panel.data:SetText(wire..'x');assert(not c.ticket and not c.panel.accept.enabled)
            c:Close();assert(not c.panel:IsShown())
        ''')

    def test_private_passages_require_opt_in_and_export_deselection_clears_wire(self):
        self.lua.execute('''
            assert(j:AddPassage(e.id,{raw='PRIVATE OBSERVATION',nature='observation',origin='manual',source='Me'}))
            assert(j:AddPassage(e.id,{raw='PRIVATE QUOTATION',nature='source',origin='manual',source='Me',private=true}))
            local r=build();assert(#r.passages==1)
            assert(#build({interpretations=true}).passages==4)
            shell=ns.CreateFieldbookShell();shell:RegisterSection('lore',{title='Lore',build=function() end});shell:ShowSection('lore')
            c=ns.CreateLoreReportUI(shell.sections.lore.frame,j,function() return e.id end,function() end,shell)
            c:OpenExport();local p=c.panel
            p.checks.notes:SetChecked(true);p.checks.notes.scripts.OnClick(p.checks.notes);c:Prepare()
            assert(p.data:GetText():find('PRIVATE NOTE',1,true) and p.copy.enabled)
            p.checks.notes:SetChecked(false);p.checks.notes.scripts.OnClick(p.checks.notes)
            assert(p.data:GetText()=='' and not p.copy.enabled)
            c:Prepare();assert(not p.data:GetText():find('PRIVATE NOTE',1,true))
        ''')

    def test_forward_preserves_private_source_flags_and_kind_cannot_change(self):
        self.lua.execute('''
            assert(j:AddPassage(e.id,{raw='Private source',nature='source',private=true,source='Me'}))
            local r=build({interpretations=true});local imported=assert(receive(r))
            local forward=assert(R.Build(recipient,imported.id,{report=1}))
            assert(#forward.passages==1 and forward.passages[1].raw=='Source words')
            assert(#assert(R.Build(recipient,imported.id,{report=1,interpretations=true})).passages==3)
            r.kind='person';assert(not receive(r))
            assert(recipient:Get(imported.id).kind=='writing' and #recipient:Get(imported.id).reports==1)
        ''')


if __name__ == '__main__':
    unittest.main()
