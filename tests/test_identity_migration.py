"""F1-F3 production capture, report, scope and saved-migration regressions."""
import unittest

from ui_test_harness import ROOT
from angling_test_harness import new_angling
from atlas_test_harness import new_atlas
from ledger_test_harness import new_ledger
from test_account_sections import account
import test_root_initialization


def lore_adapter(lua):
    for name in ('LoreJournal.lua', 'LoreReferences.lua', 'LoreIntegration.lua'):
        lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute('''
        function referenceHost(section,journal)
            local owner={journal=journal,Select=function(_,id) opened=journal:Get(id) end}
            local host={references=ns.CreateLoreReferences(ns.CreateLoreJournal({}),shell)}
            ns.RegisterLoreReferences(host,shell,{[section]=owner})
            return host.references
        end
    ''')


class FishingIdentityTests(unittest.TestCase):
    def test_details_show_original_contributor_without_promoting_personal_to_reported(self):
        lua = new_angling(ui=True)
        lua.execute('''
            local fact=observe('one');local water=j:Get(fact.waterID)
            c:Select(water.id,{factID=fact.id});local text=table.concat(c:Details(water),'\\n')
            assert(text:find('Alice Sunstrider',1,true) and not text:find('(Reported)',1,true))
            fact.origin=nil;fact.contributor=nil;A.PrepareOrigins(saved)
            text=table.concat(c:Details(water),'\\n')
            assert(text:find('original observer not recorded',1,true))
        ''')

    def test_conflicting_alias_assertions_are_rejected_atomically(self):
        lua = new_angling()
        lua.execute('''
            observe('one');local r=reportFor(next(saved.items))
            r.facts[2]=A.Copy(r.facts[1]);r.facts[2].id='f2';r.facts[2].origin.key='Independent origin'
            assert(not R.Normalize(r),'two facts cannot assert the same original alias')
            r=reportFor(next(saved.items));local receiver=ns.CreateAnglingJournal({});assert(import(receiver,r))
            local before=snapshot(receiver.db);r.facts[1].items[1].quantity=1
            r.facts[1].last=r.facts[1].last+1
            assert(not import(receiver,r),'divergent historical totals must remain unresolved')
            assert(snapshot(receiver.db)==before,'conflicting repair changed stored evidence')
        ''')

    def test_stale_legacy_delivery_cannot_replace_newer_canonical_totals(self):
        lua = new_angling()
        lua.execute('''
            observe('one');local itemID=next(saved.items);local legacy=reportFor(itemID)
            for _,field in ipairs({'records','facts'}) do for _,v in ipairs(legacy[field]) do
                v.origin.legacyKeys=nil;v.origin.source='Old courier'
            end end
            local receiver=ns.CreateAnglingJournal({});assert(import(receiver,legacy))
            now=now+10;observe('two');assert(import(receiver,reportFor(itemID)))
            local fish=receiver:List('catches')[1]
            assert(receiver:Summary(fish).reportedEvents==2 and A.Count(receiver.db.reported)==1)
            local before=snapshot(receiver.db.reported)
            assert(import(receiver,legacy));assert(receiver:Summary(fish).reportedEvents==2)
            assert(snapshot(receiver.db.reported)==before,'stale alias changed canonical evidence or receipts')
            for _,field in ipairs({'records','facts'}) do for _,v in ipairs(legacy[field]) do v.origin.source='Unseen old courier' end end
            assert(import(receiver,legacy));assert(A.Count(receiver.db.reported)==1 and receiver:Summary(fish).reportedEvents==2)
            local forwarded=assert(R.Build(receiver,fish.id,'reported'))
            assert(forwarded.facts[1].origin.source=='Alice Sunstrider')
        ''')

    def test_opt_out_is_a_fork_not_a_sync_or_shared_new_catch_identity(self):
        lua = new_angling()
        account(lua)
        lua.execute('''
            observe('initial');local personal=saved;local itemID=next(saved.items)
            local receiver=ns.CreateAnglingJournal({});assert(import(receiver,reportFor(itemID)))
            local shared=ns.SelectSectionStorage('angling',personal)
            j=ns.CreateAnglingJournal(shared);now=now+1;observe('account-new')
            local accountReport=reportFor(itemID);assert(import(receiver,accountReport))
            scope(1,false);j=ns.CreateAnglingJournal(ns.SelectSectionStorage('angling',personal))
            now=now+1;observe('local-new');assert(import(receiver,reportFor(itemID)))
            local fish=receiver:List('catches')[1];assert(receiver:Summary(fish).reportedEvents==3)
            scope(1);j=ns.CreateAnglingJournal(ns.SelectSectionStorage('angling',personal))
            assert(j:Summary(j:Get(itemID)).events==2,'opt-out edits must not be reimported')
            assert(import(receiver,reportFor(itemID)));assert(receiver:Summary(fish).reportedEvents==3)
        ''')

    def test_unproven_legacy_origins_with_same_key_are_not_collapsed(self):
        lua = new_angling()
        lua.execute('''
            observe('one');local first=reportFor(next(saved.items));local second=A.Copy(first)
            for _,field in ipairs({'records','facts'}) do for _,v in ipairs(first[field]) do v.origin.legacyKeys=nil end end
            for _,field in ipairs({'records','facts'}) do for _,v in ipairs(second[field]) do
                v.origin.legacyKeys=nil;v.origin.source='Independent observer'
            end end
            local receiver=ns.CreateAnglingJournal({});assert(import(receiver,first));assert(import(receiver,second))
            assert(A.Count(receiver.db.reported)==2,'a bare matching legacy key is not an alias assertion')
        ''')

    def test_already_migrated_legacy_totals_aliases_and_unknown_observer(self):
        lua = new_angling()
        account(lua)
        lua.execute('''
            observe('one');local itemID=next(saved.items);local legacy=reportFor(itemID)
            local function oldReport(sender)
                local r=A.Copy(legacy);r.sender=sender
                for _,field in ipairs({'records','facts'}) do for _,v in ipairs(r[field]) do
                    v.origin.source=sender;v.origin.legacyKeys=nil
                end end
                return r
            end
            local receiver=ns.CreateAnglingJournal({})
            assert(import(receiver,oldReport('Alice Sunstrider')));assert(import(receiver,oldReport('Courier')))
            assert(A.Count(receiver.db.reported)==2,'fixture must contain the old double count')
            local shared=A.Copy(saved)
            for _,db in ipairs({saved,shared}) do for _,field in ipairs({'waters','spots','pools','items','aggregates'}) do
                for _,e in pairs(db[field]) do e.origin=nil;e.contributor=nil end
            end end
            AzerothFieldbookAccountDB.sections={angling=shared}
            AzerothFieldbookAccountDB.sectionImports={angling={[1]=true}}
            scope(1);shared=ns.SelectSectionStorage('angling',saved);j=ns.CreateAnglingJournal(shared)
            local report=reportFor(itemID)
            assert(report.facts[1].origin.source=='Unknown original observer','must not invent a legacy observer')
            assert(import(receiver,report))
            local fish=receiver:List('catches')[1]
            assert(A.Count(receiver.db.reported)==1 and receiver:Summary(fish).reportedEvents==1)
            local fact=receiver.db.reported[next(receiver.db.reported)]
            assert(A.Count(fact.receipts)==2,'both historical deliveries must survive canonicalization')
            local before=snapshot(shared);scope(1);j=ns.CreateAnglingJournal(ns.SelectSectionStorage('angling',saved))
            assert(snapshot(shared)==before,'repeat repair changed legacy identity')
            observe('new');assert(import(receiver,reportFor(itemID)))
            assert(receiver:Summary(fish).reportedEvents==2 and receiver:Summary(fish).events==0)
            assert(import(receiver,oldReport('Courier')),'supported old aliases must remain recognized')
            assert(receiver:Summary(fish).reportedEvents==2)
        ''')

    def test_legacy_spot_aliases_and_original_store_remap(self):
        lua = new_angling()
        account(lua)
        lua.execute('''
            local spot=spot();observe('one','open',nil,spot.id)
            local report=reportFor(spot.id);local original=report.facts[1].origin.key
            -- A second imported character used the old deterministic char2 ID remap.
            scope(1);ns.SelectSectionStorage('angling',{});scope(2)
            local shared=ns.SelectSectionStorage('angling',saved)
            for _,field in ipairs({'waters','spots','pools','items','aggregates'}) do for _,e in pairs(shared[field]) do
                e.origin=nil;e.contributor=nil
            end end
            AzerothFieldbookAccountDB.anglingIdentityRepairs=nil;shared.captureOrigin=nil
            local receiver=ns.CreateAnglingJournal({})
            local old=A.Copy(report)
            for _,field in ipairs({'records','facts'}) do for _,v in ipairs(old[field]) do v.origin.legacyKeys=nil end end
            assert(import(receiver,old))
            scope(2);shared=ns.SelectSectionStorage('angling',saved);j=ns.CreateAnglingJournal(shared)
            local fixed=reportFor('char2:'..spot.id)
            assert(import(receiver,fixed));assert(A.Count(receiver.db.reported)==1)
            assert(receiver.db.reportOrigins[A.Key(old.facts[1].origin.source,original)])
            playerName='Another Courier';assert(import(receiver,reportFor('char2:'..spot.id)))
            assert(A.Count(receiver.db.reported)==1)
        ''')

    def test_capture_export_from_another_character_and_cumulative_updates(self):
        lua = new_angling()
        account(lua)
        lua.execute('''
            catch('first');local itemID=next(saved.items)
            local first=assert(R.Build(j,itemID,'personal'))
            local receiver=ns.CreateAnglingJournal({});assert(import(receiver,first))
            local shared=ns.SelectSectionStorage('angling',saved)
            playerName='Second Angler';scope(2)
            shared=ns.SelectSectionStorage('angling',{})
            j=ns.CreateAnglingJournal(shared);t=ns.CreateAnglingTracking(j)
            local second=assert(R.Build(j,itemID,'personal'))
            assert(second.sender=='Second Angler' and second.facts[1].origin.source=='Alice Sunstrider',
                'F1: delivery replaced the original observer')
            local ok,added=import(receiver,second)
            assert(ok and added==0 and A.Count(receiver.db.reported)==1,'F1: one catch was counted twice')
            catch('second');local third=assert(R.Build(j,itemID,'personal'))
            assert(#third.facts==2,'contributors must have separate cumulative evidence')
            local sources={};for _,f in ipairs(third.facts) do sources[f.origin.source]=f.events end
            assert(sources['Alice Sunstrider']==1 and sources['Second Angler']==1)
            assert(import(receiver,third));catch('third');assert(import(receiver,assert(R.Build(j,itemID,'personal'))))
            local fish=receiver:List('catches')[1]
            assert(receiver:Summary(fish).reportedEvents==3 and receiver:Summary(fish).events==0)
            AzerothFieldbookAccountDB=A.Copy(AzerothFieldbookAccountDB)
            scope(2);j=ns.CreateAnglingJournal(ns.SelectSectionStorage('angling',{}))
            receiver=ns.CreateAnglingJournal(A.Copy(receiver.db))
            assert(import(receiver,assert(R.Build(j,itemID,'personal'))))
            assert(A.Count(receiver.db.reported)==2 and receiver:Summary(fish).reportedEvents==3)
            assert(not next(receiver.db.aggregates) and #receiver.db.history==0 and #receiver.db.sessions==0)
        ''')

    def test_matching_independent_origins_remain_separate(self):
        lua = new_angling()
        lua.execute('''
            observe('one');local first=reportFor(next(saved.items));local other={}
            j=ns.CreateAnglingJournal(other);observe('one')
            local second=reportFor(next(other.items));local receiver=ns.CreateAnglingJournal({})
            assert(import(receiver,first));assert(import(receiver,second))
            assert(A.Count(receiver.db.reported)==2 and receiver:Summary(receiver:List('catches')[1]).reportedEvents==2)
        ''')


class AtlasReferenceTests(unittest.TestCase):
    def test_legacy_reference_with_lost_scope_does_not_choose_between_two_origins(self):
        lua = new_atlas()
        account(lua)
        lore_adapter(lua)
        lua.execute('''
            local personal={};local journal=ns.CreateAtlasJournal(personal);journal:Save(fixture('Second'))
            local shared={records={p1=A.Copy(personal.records.p1),['char2:1']=A.Copy(personal.records.p1)},expeditions={}}
            shared.records.p1.name='First';shared.records['char2:1'].id='char2:1'
            for _,e in pairs(shared.records) do e.reference=nil end
            personal.records.p1.reference=nil;personal.origin=nil;personal.loreAliases=nil
            AzerothFieldbookAccountDB.sections={atlas=shared}
            AzerothFieldbookAccountDB.sectionImports={atlas={[1]=true,[2]=true}}
            scope(2);ns.SelectSectionStorage('atlas',personal)
            local refs=referenceHost('atlas',ns.CreateAtlasJournal(shared))
            assert(refs:Resolve({section='atlas',id='p1@:'..now}).missing)
            assert(AzerothFieldbookAccountDB.atlasReferenceIssues[2]['p1@:'..now]:find('scope',1,true))
            scope(2,false);refs=referenceHost('atlas',ns.CreateAtlasJournal(personal))
            assert(refs:Resolve({section='atlas',id='p1@:'..now}).missing,'lost original scope remains ambiguous after opt-out')
            local explicit=refs:List('Second')[1]
            assert(refs:Open(explicit) and opened.name=='Second','the known local identity itself remains usable')
        ''')

    def test_new_account_and_local_records_do_not_reuse_reference_after_fork(self):
        lua = new_atlas()
        account(lua)
        lore_adapter(lua)
        lua.execute('''
            local personal={};local journal=ns.CreateAtlasJournal(personal)
            journal:Save(fixture('Original'))
            local shared=ns.SelectSectionStorage('atlas',personal);local sharedJournal=ns.CreateAtlasJournal(shared)
            local sharedID=sharedJournal:Save(fixture('Account new'))
            local accountLink=referenceHost('atlas',sharedJournal):List('Account new')[1]
            scope(1,false);ns.SelectSectionStorage('atlas',personal)
            local localID=journal:Save(fixture('Local new'));assert(localID==sharedID,'fixture needs colliding local IDs')
            local refs=referenceHost('atlas',journal);assert(refs:Resolve(accountLink).missing)
            local localLink=refs:List('Local new')[1];assert(localLink.key~=accountLink.key)
            scope(1);ns.SelectSectionStorage('atlas',personal)
            refs=referenceHost('atlas',sharedJournal);assert(refs:Resolve(localLink).missing)
            assert(refs:Open(accountLink) and opened.name=='Account new')
        ''')

    def test_old_account_scope_link_resolves_locally_via_preserved_mapping(self):
        lua = new_atlas()
        account(lua)
        lore_adapter(lua)
        lua.execute('''
            local personal={};local journal=ns.CreateAtlasJournal(personal)
            now=1000010;journal:Save(fixture('Second'))
            local shared={records={['char2:1']=A.Copy(personal.records.p1)},expeditions={}}
            shared.records['char2:1'].id='char2:1';shared.records['char2:1'].reference=nil
            personal.records.p1.reference=nil;personal.origin=nil;personal.loreAliases=nil
            AzerothFieldbookAccountDB.sections={atlas=shared}
            AzerothFieldbookAccountDB.sectionImports={atlas={[1]=true,[2]=true}}
            scope(2);ns.SelectSectionStorage('atlas',personal)
            local link={section='atlas',id='char2:1@:1000010'}
            scope(2,false);local refs=referenceHost('atlas',ns.CreateAtlasJournal(personal))
            assert(refs:Open(link) and opened.name=='Second')
        ''')

    def test_ambiguous_historical_mapping_stays_unavailable(self):
        lua = new_atlas()
        account(lua)
        lore_adapter(lua)
        lua.execute('''
            local personal={};local journal=ns.CreateAtlasJournal(personal)
            journal:Save(fixture('Second A'));journal:Save(fixture('Second B'))
            local shared={records={},expeditions={}}
            for i=1,2 do local e=A.Copy(personal.records['p'..i]);e.id='char2:'..i;e.reference=nil;shared.records[e.id]=e end
            for _,e in pairs(personal.records) do e.reference=nil end
            personal.origin=nil;personal.loreAliases=nil
            AzerothFieldbookAccountDB.sections={atlas=shared}
            AzerothFieldbookAccountDB.sectionImports={atlas={[1]=true,[2]=true}}
            scope(2);shared=ns.SelectSectionStorage('atlas',personal)
            local refs=referenceHost('atlas',ns.CreateAtlasJournal(shared))
            assert(refs:Resolve({section='atlas',id='p1@:'..now}).missing,'ambiguous timestamp must not pick a destination')
            local issues=AzerothFieldbookAccountDB.atlasReferenceIssues[2]
            assert(next(issues),'historical ambiguity must be explicit')
            local before=snapshot(shared);scope(2);ns.SelectSectionStorage('atlas',personal)
            assert(snapshot(shared)==before)
            scope(2,false);refs=referenceHost('atlas',ns.CreateAtlasJournal(personal))
            assert(refs:Open({section='atlas',id='p1@:'..now}) and opened.name=='Second A')
        ''')

    def test_same_stamp_scopes_and_account_only_destination(self):
        lua = new_atlas()
        account(lua)
        lore_adapter(lua)
        lua.execute('''
            local a,b={},{};local ja=ns.CreateAtlasJournal(a);local jb=ns.CreateAtlasJournal(b)
            ja:Save(fixture('First'));jb:Save(fixture('Second'))
            scope(1);ns.SelectSectionStorage('atlas',a);scope(2);local shared=ns.SelectSectionStorage('atlas',b)
            local refs=referenceHost('atlas',ns.CreateAtlasJournal(shared))
            assert(refs:Open({section='atlas',id='p1@:'..now}) and opened.name=='Second')
            local first=refs:List('First')[1];local second=refs:List('Second')[1]
            scope(2,false);refs=referenceHost('atlas',jb)
            assert(refs:Resolve(first).missing,'same ID and timestamp in another scope cannot match')
            assert(refs:Open(second) and opened.name=='Second')
            scope(2);refs=referenceHost('atlas',ns.CreateAtlasJournal(ns.SelectSectionStorage('atlas',b)))
            assert(refs:Open(first) and opened.name=='First')
            local edited=ns.CreateAtlasJournal(shared);local id=opened.id
            local value=edited:Get(id);value.name='Renamed';assert(edited:Save(value,id))
            refs=referenceHost('atlas',edited);assert(refs:Open(first) and opened.name=='Renamed')
            assert(edited:Delete(id));assert(refs:Resolve(first).missing)
            edited:Save(fixture('Replacement'));assert(refs:Resolve(first).missing)
        ''')

    def run_collision(self, order):
        lua = new_atlas()
        account(lua)
        lore_adapter(lua)
        lua.globals().firstCharacter = order
        lua.execute('''
            local stores={{},{}};local links={}
            for i=1,2 do
                now=1000000+i*10
                local journal=ns.CreateAtlasJournal(stores[i]);local id=assert(journal:Save(fixture('Place '..i)))
                assert(id=='p1');scope(i,false);ns.SelectSectionStorage('atlas',stores[i])
                -- The historical key in existing Lore saves must remain valid.
                links[i]={section='atlas',id=id..'@:'..now,label='Place '..i}
                local ref=referenceHost('atlas',journal);assert(ref:Open(links[i]) and opened.name=='Place '..i)
            end
            for _,i in ipairs({firstCharacter,3-firstCharacter}) do
                scope(i);ns.SelectSectionStorage('atlas',stores[i])
            end
            for pass=1,2 do for i=1,2 do
                scope(i);local shared=ns.SelectSectionStorage('atlas',stores[i])
                local ref=referenceHost('atlas',ns.CreateAtlasJournal(shared))
                assert(ref:Open(links[i]) and opened.name=='Place '..i,'F2: migration lost the intended destination')
                local canonical
                for _,row in ipairs(ref:List('Place '..i)) do canonical=row end
                scope(i,false);local personal=ns.SelectSectionStorage('atlas',stores[i])
                ref=referenceHost('atlas',ns.CreateAtlasJournal(personal))
                assert(ref:Open(links[i]) and opened.name=='Place '..i)
                assert(ref:Open(canonical) and opened.name=='Place '..i,'account reference must resolve locally')
                local wrong={section='atlas',id=links[3-i].id,label='Other character'}
                assert(ref:Resolve(wrong).missing,'must not open a colliding local ID')
            end
                AzerothFieldbookAccountDB=A.Copy(AzerothFieldbookAccountDB)
            end
        ''')

    def test_migration_order_one_two(self):
        self.run_collision(1)

    def test_migration_order_two_one(self):
        self.run_collision(2)

    def test_already_migrated_reference_and_missing_local_scope(self):
        lua = new_atlas()
        account(lua)
        lore_adapter(lua)
        lua.execute('''
            local a,b={},{};local ja=ns.CreateAtlasJournal(a);local jb=ns.CreateAtlasJournal(b)
            local one=assert(ja:Save(fixture('First')));now=1000010
            local two=assert(jb:Save(fixture('Second')))
            -- Reproduce the actual old migration shape, without a saved ID map.
            local shared=A.Copy(a);shared.records['char2:1']=A.Copy(b.records[two]);shared.records['char2:1'].id='char2:1'
            for _,db in ipairs({a,b,shared}) do db.origin=nil;db.loreAliases=nil
                for _,e in pairs(db.records) do e.reference=nil end
            end
            AzerothFieldbookAccountDB.sections={atlas=shared}
            AzerothFieldbookAccountDB.sectionImports={atlas={[1]=true,[2]=true}}
            local link={section='atlas',id='p1@:1000010',label='Second'}
            scope(2);shared=ns.SelectSectionStorage('atlas',b)
            local ref=referenceHost('atlas',ns.CreateAtlasJournal(shared))
            assert(ref:Open(link) and opened.name=='Second','F2: already-migrated save was not repaired')
            local stable=ref:List('Second')[1]
            local before=snapshot(shared)
            scope(2);ns.SelectSectionStorage('atlas',b);assert(snapshot(shared)==before,'repair changed identities again')
            scope(2,false);ref=referenceHost('atlas',ns.CreateAtlasJournal(ns.SelectSectionStorage('atlas',b)))
            assert(ref:Open(stable) and opened.name=='Second')
            jb:Delete(two)
            ref=referenceHost('atlas',jb);assert(ref:Resolve(stable).missing)
            local ok,message=ref:Open(stable);assert(not ok and message:find('unavailable',1,true))
            scope(2);ref=referenceHost('atlas',ns.CreateAtlasJournal(ns.SelectSectionStorage('atlas',b)))
            assert(ref:Open(link) and opened.name=='Second')
        ''')


class MerchantIdentityTests(unittest.TestCase):
    def test_new_account_and_local_contacts_have_independent_references(self):
        lua = new_ledger()
        account(lua)
        lua.execute('''
            local personal={};local localJournal=ns.CreateLedgerJournal(personal)
            localJournal:New('Original');local shared=ns.SelectSectionStorage('ledger',personal)
            local accountJournal=ns.CreateLedgerJournal(shared);local a=accountJournal:New('New account contact')
            scope(1,false);ns.SelectSectionStorage('ledger',personal);local b=localJournal:New('New local contact')
            assert(a.id==b.id and a.reference~=b.reference)
            assert(not accountJournal:Reference(b.reference) and not localJournal:Reference(a.reference))
        ''')

    def test_old_local_id_alias_future_selection_remove_and_reload(self):
        lua = new_ledger()
        account(lua)
        lua.execute('''
            local e=visit();local report=reportFor(e);local a,b={},{}
            local one=import(ns.CreateLedgerJournal(a),report);local two=import(ns.CreateLedgerJournal(b),report)
            scope(1);ns.SelectSectionStorage('ledger',a);scope(2);local shared=ns.SelectSectionStorage('ledger',b)
            local journal=ns.CreateLedgerJournal(shared);local oldID='char2:'..two.id
            local canonical=journal:Reference(two.reference)
            assert(journal:Get(oldID)==canonical,'old local ID must remain a canonical alias')
            assert(import(journal,report,oldID).id==canonical.id)
            assert(journal:Remove(oldID));assert(not next(shared.contacts),'removing an alias must remove the canonical contact')
            assert(not journal:Reference(one.reference) and not journal:Reference(two.reference))
            local fresh=assert(journal:New('Different contact'))
            assert(not journal:Get(oldID) and fresh.id~=canonical.id,'stale aliases must not resolve to replacements')
        ''')

    def test_receipts_long_notes_and_conflicting_personal_evidence_survive(self):
        lua = new_ledger()
        account(lua)
        lua.execute('''
            local origin=visit();local report=reportFor(origin);local stores={};local refs={}
            for i=1,2 do
                stores[i]={origin='local'..i};local journal=ns.CreateLedgerJournal(stores[i])
                report.sender='Courier '..i;now=now+10;local e=import(journal,report);refs[i]=e.reference
                journal:Annotate(e.id,string.rep(tostring(i),3000),'trainer','Distinct '..i)
                e.goods.conflict={name='Personal '..i,last=now,origin={source='Local '..i,key='fact',at=now}}
                e.personal=true
                scope(i);ns.SelectSectionStorage('ledger',stores[i])
            end
            local db=AzerothFieldbookAccountDB.sections.ledger;local journal=ns.CreateLedgerJournal(db)
            assert(L.Count(db.contacts)==1);local e=journal:Reference(refs[1])
            assert(e==journal:Reference(refs[2]) and L.Count(e.migrationEvidence)==2)
            local notes=e.note..journal:ImportedNotes(e)
            assert(notes:find(string.rep('1',3000),1,true) and notes:find(string.rep('2',3000),1,true))
            local book=ns.CreateLedgerBook(journal,{},ns.CreateFieldbookShell())
            local details=book:Details(e,false,'services')
            assert(details:find(string.rep('1',3000),1,true) and details:find(string.rep('2',3000),1,true))
            local deliveries={}
            for _,old in pairs(e.migrationEvidence) do
                local r=old.reports[1];deliveries[r.sender]=r.received
                assert(next(r.factReceipts) and old.manualRoles.trainer and old.goods.conflict)
            end
            assert(deliveries['Courier 1']==1000010 and deliveries['Courier 2']==1000020)
            assert(e.reports[1].received==1000010 and e.reports[1].lastReceived==1000020)
            local before=snapshot(e.migrationEvidence)
            import(journal,report);assert(snapshot(e.migrationEvidence)==before)
            local exported=assert(R.Build(journal,e.id,{report=1}))
            assert(not exported.migrationEvidence and not exported.notes,'private retained data cannot leak into reports')
        ''')

    def test_distinct_reports_with_same_template_stay_distinct(self):
        lua = new_ledger()
        account(lua)
        lua.execute('''
            local a=visit();local reportA=reportFor(a);fire('MERCHANT_CLOSED');now=now+10
            local b=visit(42,'DEF');local reportB=reportFor(b)
            assert(reportA.identity.npcID==reportB.identity.npcID)
            local one,two={},{};import(ns.CreateLedgerJournal(one),reportA);import(ns.CreateLedgerJournal(two),reportB)
            scope(1);ns.SelectSectionStorage('ledger',one);scope(2)
            local db=ns.SelectSectionStorage('ledger',two)
            assert(L.Count(db.contacts)==2 and L.Count(db.reportKeys)==2)
        ''')

    def run_imports(self, order, already=False):
        lua = new_ledger()
        account(lua)
        lore_adapter(lua)
        lua.globals().firstCharacter = order
        lua.globals().alreadyMigrated = already
        lua.execute('''
            local origin=visit();local report=reportFor(origin);local stores={{origin='recipient-one'},{origin='recipient-two'}}
            local contacts,links={},{}
            for i=1,2 do
                playerName='Courier '..i;report.sender=playerName;now=now+10
                local journal=ns.CreateLedgerJournal(stores[i]);local e=import(journal,report);contacts[i]=e
                journal:Annotate(e.id,'Private note '..i,'trainer','Speciality '..i)
                links[i]={section='merchants',id=e.id..'@:'..e.reference,label=e.name}
            end
            local identity=L.Key(report.identity.origin.source,report.identity.origin.key)
            if alreadyMigrated then
                local shared=L.Copy(stores[firstCharacter]);local other=3-firstCharacter
                local id='char'..other..':'..contacts[other].id
                shared.contacts[id]=L.Copy(contacts[other]);shared.contacts[id].id=id
                shared.references[contacts[other].reference]=id
                AzerothFieldbookAccountDB.sections={ledger=shared}
                AzerothFieldbookAccountDB.sectionImports={ledger={[1]=true,[2]=true}}
            else
                for _,i in ipairs({firstCharacter,3-firstCharacter}) do scope(i);ns.SelectSectionStorage('ledger',stores[i]) end
            end
            scope(2);local shared=ns.SelectSectionStorage('ledger',stores[2]);local journal=ns.CreateLedgerJournal(shared)
            assert(L.Count(shared.contacts)==1,'F3: same original report created two account contacts')
            local canonical=journal:Reference(contacts[1].reference)
            assert(canonical and journal:Reference(contacts[2].reference)==canonical)
            assert(shared.reportKeys[identity]==canonical.id and #canonical.reports==1)
            assert(canonical.note:find('Private note 1',1,true) and canonical.note:find('Private note 2',1,true))
            assert(canonical.specialities['Speciality 1'] and canonical.specialities['Speciality 2'])
            assert(L.Count(canonical.migrationEvidence)==2)
            for i=1,2 do
                scope(i);ns.SelectSectionStorage('ledger',stores[i])
                local ref=referenceHost('merchants',journal)
                assert(ref:Open(links[i]) and opened.id==canonical.id,'old local reference lost')
            end
            local before=snapshot(shared);AzerothFieldbookAccountDB=L.Copy(AzerothFieldbookAccountDB)
            scope(2);shared=ns.SelectSectionStorage('ledger',stores[2]);journal=ns.CreateLedgerJournal(shared)
            assert(snapshot(shared)==before,'repair allocated or merged again')
            playerName='Alice Sunstrider';now=now+10;items[1].numAvailable=0;fire('MERCHANT_UPDATE');flush()
            local update=reportFor(origin);local changed=import(journal,update)
            assert(changed.id==canonical.id and L.Count(shared.contacts)==1 and #changed.reports==1)
            assert(changed.reports[1].goods[1].stock.state=='soldout')
        ''')

    def test_migration_order_one_two(self):
        self.run_imports(1)

    def test_migration_order_two_one(self):
        self.run_imports(2)

    def test_repair_existing_duplicates(self):
        for order in (1, 2):
            with self.subTest(order=order):
                self.run_imports(order, already=True)


class IdentityGuardTests(unittest.TestCase):
    def test_new_repair_entry_points_respect_latched_startup_block(self):
        for section, factory in (('angling', new_angling), ('atlas', new_atlas), ('ledger', new_ledger)):
            with self.subTest(section=section):
                lua = factory()
                account(lua)
                lua.globals().section = section
                lua.execute('''
                    localShared=ns.SelectSectionStorage(section,saved)
                    localBefore=snapshot(saved);sharedBefore=snapshot(localShared)
                ''')
                test_root_initialization.RootInitializationTests().block_existing_client(lua)
                lua.execute('''
                    accountBefore=snapshot(AzerothFieldbookAccountDB)
                    AzerothFieldbookDB={version=1}
                    ns.InitializeSectionTracking({accountTrackingKey=99})
                    assert(not ns.SelectSectionStorage(section,saved))
                    if section=='angling' then ns.Angling.PrepareOrigins(saved);ns.CreateAnglingJournal(saved)
                    elseif section=='atlas' then ns.Atlas.EnsureReferences(saved);ns.CreateAtlasJournal(saved)
                    else ns.Ledger.ReconcileReports(saved);ns.CreateLedgerJournal(saved) end
                    assert(snapshot(saved)==localBefore and snapshot(localShared)==sharedBefore)
                    assert(snapshot(AzerothFieldbookAccountDB)==accountBefore and ns.InitializationBlocked)
                ''')


if __name__ == '__main__':
    unittest.main()
