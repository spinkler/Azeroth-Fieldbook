"""O6: previews use actual acceptance and never write to live journals."""
import unittest
from angling_test_harness import new_angling
from ledger_test_harness import new_ledger
from test_lore_reports import MODULES
from test_player_names_preservation import SUPPORT
from ui_test_harness import new_ui_client


class AnglingPreflightTests(unittest.TestCase):
    def setUp(self):
        self.lua=new_angling()
        self.lua.execute(r"""
            e=spot('My pool','School');observe('one','pool',e.poolID,e.id);r=reportFor(e.id)
            recipient=ns.CreateAnglingJournal({});changes=0
            recipient.onChange=function() changes=changes+1 end
            function review(report)
                local ticket=assert(R.Prepare(assert(R.Encode(report))))
                local before=snapshot(recipient.db);local revision=recipient.revision;local count=changes
                local text,ok,delta=R.Preflight(recipient,ticket)
                local again,stillOK=R.Preflight(recipient,ticket)
                assert(again==text and stillOK==ok)
                assert(before==snapshot(recipient.db) and revision==recipient.revision and count==changes)
                assert(ticket.preview:find(report.sender,1,true) and ticket.preview:find(report.facts[1].origin.source,1,true))
                if not ok then
                    local accepted,err=R.Accept(recipient,ticket)
                    assert(not accepted and text=='Cannot accept now: '..err and before==snapshot(recipient.db))
                    return text
                end
                local accepted,added,updated,actual=R.Accept(recipient,ticket)
                assert(accepted and added==delta.added and updated==delta.updated and snapshot(actual)==snapshot(delta))
                return text,delta
            end
        """)

    def test_new_repeated_mixed_updated_and_forwarded(self):
        self.lua.execute(r"""
            local text,d=review(r);assert(d.added==1 and d.updated==0 and d.known==0 and d.identities.added==#r.records)
            text,d=review(r);assert(d.known==1 and d.identities.known==#r.records and d.identities.updated==0)
            now=now+10;observe('two','pool',e.poolID,e.id);local newer=reportFor(e.id)
            text,d=review(newer);assert(d.updated==1 and d.added==0)
            local mixed=A.Copy(newer);local extra=A.Copy(mixed.facts[1]);extra.id='f2';extra.origin.key='additional';extra.origin.legacyKeys=nil
            mixed.facts[#mixed.facts+1]=extra
            text,d=review(mixed);assert(d.added==1 and d.known==1)
            mixed.sender='Forwarding player';text,d=review(mixed);assert(d.known==2 and d.updated==0)
        """)

    def test_conflicts_capacity_read_only_and_validation(self):
        self.lua.execute(r"""
            R.MAX_STORED_FACTS=0;assert(review(r):find('capacity',1,true));R.MAX_STORED_FACTS=4096
            recipient.readOnly=true;assert(review(r):find('read-only',1,true));recipient.readOnly=false
            review(r)
            local conflict=A.Copy(r);conflict.facts[1].source='open';conflict.facts[1].poolID=nil;conflict.facts[1].spotID=nil
            assert(review(conflict):find('Conflicting',1,true))
            local wire=assert(R.Encode(r));assert(not R.Prepare(wire..'junk'))
            metadataVersion='incompatible';assert(not R.Prepare(wire))
        """)

    def test_ui_keeps_detail_and_blocks_capacity(self):
        self.lua.execute(r"""
            shell:ShowSection('angling');c:Select(e.id);c:OpenReports();local p=c.panels.reports
            p.data:SetText(assert(R.Encode(r)));click(p.check)
            assert(p.preview.text:GetText():find('Against this journal now:',1,true))
            assert(p.preview.text:GetText():find('Sender claim:',1,true) and p.accept.enabled)
            R.MAX_STORED_FACTS=0;click(p.check)
            assert(not p.accept.enabled and p.preview.text:GetText():find('Cannot accept now:',1,true))
        """)


class LedgerPreflightTests(unittest.TestCase):
    def setUp(self):
        self.lua=new_ledger()
        self.lua.execute(r"""
            e=visit();r=reportFor(e);recipient=ns.CreateLedgerJournal({});changes=0
            recipient.onChange=function() changes=changes+1 end
            function review(report,selected)
                local ticket=assert(R.Prepare(assert(R.Encode(report))))
                local before=snapshot(recipient.db);local revision=recipient.revision;local count=changes
                local text,ok,delta=R.Preflight(recipient,ticket,selected)
                local again,stillOK=R.Preflight(recipient,ticket,selected)
                assert(again==text and stillOK==ok)
                assert(before==snapshot(recipient.db) and revision==recipient.revision and count==changes)
                assert(ticket.preview:find(report.sender,1,true) and ticket.preview:find(report.identity.origin.source,1,true))
                local accepted,err,actual=R.Accept(recipient,ticket,selected)
                if not ok then
                    assert(not accepted and text=='Cannot accept now: '..err and before==snapshot(recipient.db));return text
                end
                assert(accepted and snapshot(actual)==snapshot(delta));return text,delta,accepted
            end
        """)

    def test_new_known_updated_mixed_and_attachment(self):
        self.lua.execute(r"""
            local text,d,entry=review(r);assert(d.newContact and d.newSource)
            text,d=review(r);assert(d.knownSource and not d.updatedSource)
            local forward=L.Copy(r);forward.sender='Forwarding player';now=now+10;forward.created=now
            text,d=review(forward);assert(d.knownSource)
            now=now+10;items[1].numAvailable=0;fire('MERCHANT_UPDATE');flush()
            text,d=review(reportFor(e));assert(d.updatedSource)
            now=now+10;visit(42,'ABC',{item(1001,0,250),item(1002,5,20)})
            text,d=review(reportFor(e));assert(d.updatedSource and #entry.reports[1].goods==2)
            local other=visit(42,'DEF');local another=reportFor(other)
            text,d=review(another,entry.id);assert(not d.newContact and d.newSource and #entry.reports==2)
            local omitted=L.Copy(another);omitted.goods={};text,d=review(omitted,entry.id);assert(d.knownSource)
        """)

    def test_conflict_capacity_read_only_and_validation(self):
        self.lua.execute(r"""
            R.MAX_STORED_REPORTS=0;assert(review(r):find('limit',1,true));R.MAX_STORED_REPORTS=512
            L.MAX_CONTACTS=0;assert(review(r):find('limit',1,true));L.MAX_CONTACTS=2000
            recipient.readOnly=true;assert(review(r):find('read-only',1,true));recipient.readOnly=false
            local _,_,entry=review(r)
            local conflict=L.Copy(r);conflict.identity.npcID=99;assert(review(conflict):find('conflicts',1,true))
            local wire=assert(R.Encode(r));assert(not R.Prepare(wire..'junk'))
            metadataVersion='incompatible';assert(not R.Prepare(wire))
        """)

    def test_ui_invalidates_attachment_and_preserves_provenance(self):
        self.lua.execute(r"""
            shell:ShowSection('merchants');c:Select(e.id);c:Reports();local p=c.panels.reports
            p.data:SetText(assert(R.Encode(r)));click(p.review)
            assert(p.accept.enabled and p.preview.text:GetText():find('Would add 1 contact',1,true))
            assert(p.preview.text:GetText():find('Original observer:',1,true))
            p.attach:SetChecked(true);click(p.attach);assert(not p.ticket and not p.accept.enabled)
            click(p.review);assert(p.preview.text:GetText():find('existing contact',1,true))
            j.readOnly=true;click(p.review);assert(not p.accept.enabled)
        """)


class LorePreflightTests(unittest.TestCase):
    def setUp(self):
        self.lua=new_ui_client(MODULES)
        self.lua.execute(SUPPORT)
        self.lua.execute(r"""
            L=ns.Lore;R=ns.LoreReports;j=ns.CreateLoreJournal({})
            e=assert(j:Create('writing',{title='Source writing'}))
            assert(j:AddPassage(e.id,{raw='Original words',nature='source',source='Original author'}))
            r=assert(R.Build(j,e.id));recipient=ns.CreateLoreJournal({});changes=0
            recipient.onChange=function() changes=changes+1 end
            recipient.onRecorded=function() changes=changes+1 end
            function review(report,selected)
                local ticket=assert(R.Prepare(assert(R.Encode(report)),'Recorded courier'))
                local before=literal(recipient.db);local revision=recipient.revision;local count=changes
                local text,ok,delta=R.Preflight(recipient,ticket,selected)
                local again,stillOK=R.Preflight(recipient,ticket,selected)
                assert(again==text and stillOK==ok)
                assert(before==literal(recipient.db) and revision==recipient.revision and count==changes)
                assert(ticket.preview:find(report.sender,1,true) and ticket.preview:find(report.originalSource,1,true))
                local accepted,err,actual=R.Accept(recipient,ticket,selected)
                if not ok then
                    assert(not accepted and text=='Cannot accept now: '..err and before==literal(recipient.db));return text
                end
                assert(accepted and literal(actual)==literal(delta));return text,delta,accepted
            end
        """)

    def test_new_repeated_mixed_revisions_and_local_precedence(self):
        self.lua.execute(r"""
            local text,d,entry=review(r);assert(d.newEntry and d.newEvidence and #entry.reports==1)
            assert(entry.reports[1].receivedFrom=='Recorded courier')
            text,d=review(r);assert(d.knownEvidence and not d.newEntry)
            local forward=L.Copy(r);forward.sender='Forwarding player';now=now+10;forward.created=now
            text,d=review(forward);assert(d.knownEvidence)
            assert(recipient:Get(entry.id).reports[1].latestReceipt.receivedFrom=='Recorded courier')
            assert(j:AddPassage(e.id,{raw='More words',nature='source',source='Original author'}))
            local newer=assert(R.Build(j,e.id));text,d,entry=review(newer)
            assert(not d.newEntry and d.newEvidence and #entry.reports==2)
            local conflict=L.Copy(newer);conflict.passages[1].raw='Different account of the source'
            text,d,entry=review(conflict);assert(d.newEvidence and #entry.reports==3)
            assert(text:find('Earlier versions and personal material stay separate.',1,true))
            local personal=assert(recipient:CapturePage({sessionID='mine',title='Local writing'},
                {number=1,raw='Personal source',first=true,last=true,method='displayed'}))
            recipient:Update(personal.id,{notes='My notes'})
            text,d,entry=review(r,personal.id)
            assert(d.newEvidence and not d.newEntry and entry.notes=='My notes' and entry.pages[1].raw=='Personal source')
        """)

    def test_failures_match_accept_and_ticket_stays_valid(self):
        self.lua.execute(r"""
            L.MAX_ENTRIES=0;assert(review(r):find('full',1,true));L.MAX_ENTRIES=2000
            L.MAX_ARCHIVE_BYTES=1;assert(review(r):find('capacity',1,true));L.MAX_ARCHIVE_BYTES=33554432
            recipient.readOnly=true;assert(review(r):find('read-only',1,true));recipient.readOnly=false
            local _,_,entry=review(r)
            R.MAX_REPORTS=1;local changed=L.Copy(r);changed.passages[1].raw='Revised'
            assert(review(changed):find('limit',1,true));R.MAX_REPORTS=32
            local different=assert(recipient:Create('person',{title='A person'}))
            assert(review(r,different.id):find('same kind',1,true))
            assert(review(r,'missing'):find('no longer exists',1,true))
            local wire=assert(R.Encode(r));assert(not R.Prepare(wire..'junk'))
            metadataVersion='incompatible';assert(not R.Prepare(wire))
        """)

    def test_ui_preflight_detail_and_disabled_accept(self):
        self.lua.execute(r"""
            shell=ns.CreateFieldbookShell();shell:RegisterSection('lore',{title='Lore',build=function() end});shell:ShowSection('lore')
            local c=ns.CreateLoreReportUI(shell.sections.lore.frame,recipient,function() return nil end,function() end,shell)
            c:OpenImport();c.panel.data:SetText(assert(R.Encode(r)));c:Prepare()
            local text=c.panel.preview.text:GetText()
            assert(text:find('Would add 1 reported entry',1,true) and text:find('Claimed original source:',1,true))
            assert(c.panel.accept.enabled)
            recipient.readOnly=true;c:Prepare();assert(not c.panel.accept.enabled)
            assert(c.panel.preview.text:GetText():find('Cannot accept now:',1,true))
        """)


if __name__ == '__main__':
    unittest.main()
