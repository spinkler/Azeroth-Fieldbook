"""F5: production exports distinguish evidence revisions from deliveries."""
import unittest

from ui_test_harness import ROOT, new_ui_client
from test_account_lore_treasure import client as account_client
from test_lore_ui import new_lore_ui


class LoreReportRevisionTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_ui_client(['AtlasJournal.lua', 'LoreJournal.lua', 'LoreReports.lua'])
        self.lua.execute('''
            L=ns.Lore;R=ns.LoreReports
            source=ns.CreateLoreJournal({});recipient=ns.CreateLoreJournal({})
            e=assert(source:CapturePage({sessionID='book',title='F5 book'},
                {number=1,raw='Unchanged source',method='displayed',first=true,last=true}))
            function export(options) return assert(R.Encode(assert(R.Build(source,e.id,options)))) end
            function accept(wire,who,id)
                return R.Accept(recipient,assert(R.Prepare(wire,who)),id)
            end
        ''')

    def test_fresh_unchanged_exports_leave_capacity_for_useful_update(self):
        self.lua.execute('''
            local received
            for i=1,32 do now=now+1;received=assert(accept(export(),'Courier '..i)) end
            print('Fresh unchanged deliveries=32; stored snapshots='..#received.reports)
            assert(source:AddPassage(e.id,{raw='Useful new evidence',nature='source',source='Original source'}))
            now=now+1
            local update,err=accept(export(),'Update courier')
            print('Useful update accepted='..tostring(update~=nil)..'; error='..tostring(err))
            assert(update,err)
            assert(#update.reports==2,'unchanged deliveries consumed revision capacity')
            assert(update.reports[1].receivedFrom=='Courier 1')
            assert(update.reports[1].latestReceipt.receivedFrom=='Courier 32')
            assert(update.reports[2].passages[1].raw=='Useful new evidence')
        ''')

    def test_forward_sender_and_reload_preserve_first_and_latest_receipts(self):
        self.lua.execute('''
            local original=export();local received=assert(accept(original,'First courier'))
            local first=L.Copy(received.reports[1]);local id=received.id
            playerName='Forwarding character';now=now+20
            local forwarded=assert(R.Encode(assert(R.Build(recipient,id,{report=1}))))
            local decoded=assert(R.Decode(forwarded))
            assert(decoded.sender==playerName and decoded.originalSource==first.originalSource)
            assert(decoded.sourceKey==first.sourceKey)
            received=assert(accept(forwarded,'Second courier'))
            assert(#received.reports==1 and received.reports[1].sender==first.sender)
            assert(received.reports[1].created==first.created and received.reports[1].received==first.received)
            assert(received.reports[1].receivedFrom=='First courier')
            local latest=received.reports[1].latestReceipt
            assert(latest.sender==playerName and latest.created==now and latest.received==now)
            assert(latest.receivedFrom=='Second courier')
            local serial=recipient.db.serial;local archiveID=recipient.db.archiveID
            for reload=1,3 do
                recipient=ns.CreateLoreJournal(recipient.db)
                received=recipient:Get(id);assert(#received.reports==1)
                assert(received.reports[1].latestReceipt.receivedFrom=='Second courier')
                assert(recipient.db.serial==serial and recipient.db.archiveID==archiveID)
                now=now+1;received=assert(accept(forwarded,'Second courier'))
                assert(received.reports[1].latestReceipt.received==now and #received.reports==1)
            end
            -- Exact replay is a new receipt too; missing entered attribution
            -- must not borrow the previous courier's name.
            received=assert(accept(original))
            assert(received.reports[1].latestReceipt.receivedFrom==nil)
            assert(received.reports[1].receivedFrom=='First courier')
            for k in pairs(received.reports[1].latestReceipt) do
                assert(k=='sender' or k=='created' or k=='received' or k=='receivedFrom')
            end
        ''')

    def test_many_deliveries_have_constant_receipt_storage(self):
        self.lua.execute('''
            local received=assert(accept(export(),'Courier'))
            for i=1,256 do
                now=now+1;received=assert(accept(export(),'Courier'))
                if i==1 then bytes=recipient:ArchiveBytes() end
                assert(recipient:ArchiveBytes()==bytes and #received.reports==1)
            end
            assert(received.reports[1].latestReceipt.received==now)
        ''')

    def test_latest_receipt_is_visible_in_existing_reader_and_report_details(self):
        lua=new_lore_ui()
        lua.execute((ROOT/'LoreReports.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute('''
            local R=ns.LoreReports;local e=writing('Reader test')
            local wire=assert(R.Encode(assert(R.Build(j,e.id))))
            local imported=assert(R.Accept(j,assert(R.Prepare(wire,'First recorded courier'))))
            playerName='Forwarding character';now=now+10
            local forwarded=assert(R.Encode(assert(R.Build(j,imported.id,{report=1}))))
            imported=assert(R.Accept(j,assert(R.Prepare(forwarded,'Latest recorded courier'))))
            local details,pages=0,0
            for _,row in ipairs(c:Sources(imported)) do if row.report then
                local text=c:SourceText(imported,row)
                assert(text:find('First recorded courier',1,true))
                assert(text:find('Latest recorded courier',1,true))
                assert(text:find('Forwarding character',1,true))
                assert(text:find('Latest delivery',1,true) and text:find('not authenticated',1,true))
                if row.page then pages=pages+1 else details=details+1 end
            end end
            assert(details==1 and pages==2)
        ''')

    def test_selections_expansion_and_meaningful_revision_fields(self):
        self.lua.execute('''
            for n=2,5 do assert(source:CapturePage({sessionID='book',title='F5 book'},
                {number=n,raw='Page '..n,method='displayed'})) end
            local options={pages={[1]=true,[2]=true,[3]=true}}
            local a=assert(accept(export(options)));now=now+1
            assert(#assert(accept(export(options))).reports==1)
            a=assert(accept(export()));assert(#a.reports==2 and #a.reports[2].pages==5)
            a=assert(accept(export({pages={[2]=true,[3]=true,[4]=true}})))
            assert(#a.reports==3 and a.reports[3].pages[1].number==2)
            local base=assert(R.Build(source,e.id,options))
            local variants={
                function(r) r.pages[1].raw='Changed page text' end,
                function(r) r.pages[1].source='Independent observer' end,
                function(r) r.pages[1].at=r.pages[1].at+1 end,
                function(r) r.pages[1].method='automatic' end,
                function(r) r.references={{section='atlas',label='New place',explanation='Material reference'}} end,
                function(r) r.locations={{meaning='observation',zone='New zone',source='Witness',at=1}} end,
                function(r) r.passages={{raw='New account',method='manual',origin='manual',nature='account',source='Witness',at=1}} end,
                function(r) r.annotations.notes='Explicitly shared revision' end,
                function(r) r.annotations.tags={'New tag'} end,
            }
            for i,change in ipairs(variants) do
                local r=L.Copy(base);change(r)
                a=assert(accept(assert(R.Encode(r))));assert(#a.reports==3+i)
            end
            local id=a.id;recipient=ns.CreateLoreJournal(recipient.db)
            assert(#recipient:Get(id).reports==3+#variants)
        ''')

    def test_identical_text_with_independent_original_identities_stays_distinct(self):
        self.lua.execute('''
            local base=assert(R.Build(source,e.id));local a=assert(accept(assert(R.Encode(base))))
            local independent=L.Copy(base);independent.sourceKey='another-archive:another-work'
            a=assert(accept(assert(R.Encode(independent)),nil,a.id));assert(#a.reports==2)
            independent=L.Copy(base);independent.originalSource='Another original observer'
            a=assert(accept(assert(R.Encode(independent)),nil,a.id));assert(#a.reports==3)
            independent=L.Copy(base);independent.sender='Different courier';independent.created=now+1
            assert(#assert(accept(assert(R.Encode(independent)),nil,a.id)).reports==3)
        ''')

    def test_historical_duplicates_survive_and_only_unique_revisions_exhaust_capacity(self):
        self.lua.execute('''
            local function same(a,b)
                if type(a)~=type(b) then return false end
                if type(a)~='table' then return a==b end
                for k,v in pairs(a) do if not same(v,b[k]) then return false end end
                for k in pairs(b) do if a[k]==nil then return false end end
                return true
            end
            local historical={};local r=assert(R.Build(source,e.id))
            for i=1,32 do
                local old=L.Copy(r);old.created=old.created+i;old.received=now+i
                old.receivedFrom='Historical courier '..i;old.sender='Sender '..i
                historical[i]=old
            end
            local a=assert(recipient:Create('writing',{title='Historical',origin='reported',reports=historical}))
            local id=a.id;recipient=ns.CreateLoreJournal(recipient.db)
            assert(#recipient:Get(id).reports==32)
            for i=1,31 do
                local update=L.Copy(r);update.annotations.notes='Genuine revision '..i
                a=assert(accept(assert(R.Encode(update)),nil,id));assert(#a.reports==32+i)
            end
            assert(#a.reports==63,'32 legacy copies plus 31 genuinely new revisions')
            for i,old in ipairs(historical) do
                local current=a.reports[i]
                assert(same(current,old),'historical snapshot or receipt changed')
            end
            local update=L.Copy(r);update.annotations.notes='33rd genuine revision'
            local before=recipient:Get(id);local rejected,err=accept(assert(R.Encode(update)),nil,id)
            assert(not rejected and err:find('limit') and recipient:Get(id)==before)
            now=now+100
            a=assert(accept(assert(R.Encode(r)),'Latest courier',id))
            assert(#a.reports==63 and a.reports[1].latestReceipt.receivedFrom=='Latest courier')
            for reload=1,3 do
                recipient=ns.CreateLoreJournal(recipient.db)
                assert(#recipient:Get(id).reports==63 and recipient.invalid==0)
            end
        ''')

    def test_new_store_stops_at_32_distinct_revisions(self):
        self.lua.execute('''
            local r=assert(R.Build(source,e.id));local a
            for i=1,32 do
                r.annotations.notes='Revision '..i;a=assert(accept(assert(R.Encode(r))))
            end
            assert(#a.reports==32)
            r.annotations.notes='Revision 33';assert(not accept(assert(R.Encode(r))))
            r.annotations.notes='Revision 1';now=now+1
            a=assert(accept(assert(R.Encode(r))));assert(#a.reports==32)
        ''')

    def test_stored_version_compatibility_and_fresh_version_gate(self):
        self.lua.execute('''
            metadataVersion='0.16.9';local oldWire=export();local a=assert(accept(oldWire))
            metadataVersion='0.17.0';recipient=ns.CreateLoreJournal(recipient.db)
            assert(not R.Prepare(oldWire))
            now=now+1;a=assert(accept(export()))
            assert(#a.reports==1 and a.reports[1].addonVersion=='0.16.9')
            assert(a.reports[1].latestReceipt.received==now)
        ''')

    def test_receipt_updates_are_guarded_atomic_and_strictly_validated(self):
        self.lua.execute('''
            local wire=export();local a=assert(accept(wire));local id=a.id
            recipient.readOnly=true;assert(not accept(wire));recipient.readOnly=false
            ns.InitializationBlocked=true;assert(not accept(wire));ns.InitializationBlocked=nil
            assert(recipient:Get(id)==a and not a.reports[1].latestReceipt)
            local limit=L.MAX_ARCHIVE_BYTES;L.MAX_ARCHIVE_BYTES=recipient:ArchiveBytes()
            assert(not accept(wire,'Extra receipt bytes'))
            L.MAX_ARCHIVE_BYTES=limit;assert(recipient:Get(id)==a and not a.reports[1].latestReceipt)
            local saved=recipient.db
            a.reports[1].latestReceipt={sender='Courier',created=now,received=now,extra=true}
            local raw=a.reports[1].latestReceipt
            local loaded=ns.CreateLoreJournal(saved)
            assert(loaded.invalid==1 and loaded:Get(id)==nil and saved.entries[id].reports[1].latestReceipt==raw)
            a.reports[1].latestReceipt=nil
            a.reports[1].pages[true]=a.reports[1].pages[1]
            assert(not accept(wire),'must not erase malformed list keys via a prevalidation copy')
            assert(a.reports[1].pages[true] and not a.reports[1].latestReceipt)
            local unsupported={schema=999,entries={}};local frozen=ns.CreateLoreJournal(unsupported)
            assert(not R.Accept(frozen,assert(R.Prepare(wire))))
            assert(unsupported.schema==999 and next(unsupported.entries)==nil)
        ''')

    def test_account_characters_and_scope_switches_share_evidence_not_delivery(self):
        lua=account_client()
        lua.execute('''
            local a,b,ta,tb={},{},{},{};local recipient=ns.CreateLoreJournal({})
            local j=init(1,false,a,ta);local e=writing(j,'Original local')
            local function receive(j,id)
                local r=assert(LR.Build(j,id));local wire=assert(LR.Encode(r))
                local entry=assert(LR.Accept(recipient,assert(LR.Prepare(wire,'Courier '..playerName))))
                return entry,r
            end
            local received,original=receive(j,e.id)
            j=init(1,true,a,ta);e=find(j,'Original local');now=now+1
            received=receive(j,e.id);assert(#received.reports==1)
            -- Empty source text attribution must use the preserved original
            -- owner, including manual passages created in shared scope.
            local shared=assert(j:Create('writing',{title='Shared manual'}))
            assert(j:AddPassage(shared.id,{raw='Same manual text',nature='source'}))
            local sharedReceived,sharedReport=receive(j,shared.id)
            for pass=1,3 do
                j=init(2,true,b,tb);now=now+1
                received=receive(j,find(j,'Original local').id)
                assert(#received.reports==1 and received.reports[1].sourceKey==original.sourceKey)
                assert(received.reports[1].originalSource=='Character 1')
                assert(received.reports[1].latestReceipt.sender=='Character 2')
                sharedReceived=receive(j,shared.id)
                assert(#sharedReceived.reports==1)
                assert(sharedReceived.reports[1].passages[1].source==sharedReport.originalSource)
                j=init(1,false,a,ta);now=now+1
                received=receive(j,find(j,'Original local').id);assert(#received.reports==1)
                assert(not find(j,'Shared manual'))
            end
            j=init(2,false,b,tb);local independent=writing(j,'Original local')
            local separate,r=receive(j,independent.id)
            assert(separate.id~=received.id and r.sourceKey~=original.sourceKey)
            assert(r.originalSource=='Character 2')
        ''')


if __name__ == '__main__':
    unittest.main()
