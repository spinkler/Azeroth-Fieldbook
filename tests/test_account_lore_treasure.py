"""F8 uses production initializers, journals, references and report identities."""
import unittest

from ui_test_harness import ROOT
from treasure_test_harness import new_treasure
from test_account_sections import account
import test_root_initialization


def client():
    lua = new_treasure()
    for name in ('AtlasSubzones.lua', 'AtlasReferences.lua', 'AtlasReports.lua',
                 'AtlasEditors.lua', 'AtlasReportUI.lua', 'AtlasBook.lua',
                 'LoreJournal.lua', 'LoreSettings.lua', 'LoreTracking.lua',
                 'LoreReports.lua', 'LoreReportUI.lua', 'LoreReferences.lua',
                 'LoreMap.lua', 'LoreEditors.lua', 'LoreBook.lua', 'LoreIntegration.lua'):
        lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    account(lua)
    lua.execute("""
        L=ns.Lore;LR=ns.LoreReports
        function init(key,on,lore,treasure,atlas)
            playerName='Character '..key;playerSurname=nil
            scope(key,on)
            AzerothFieldbookLoreDB=lore;AzerothFieldbookTreasureDB=treasure
            shell=ns.CreateFieldbookShell()
            local sources={}
            if atlas then
                AzerothFieldbookAtlasDB=atlas;sources.atlas=ns.InitializeAtlas(shell)
            end
            local treasureBook=ns.InitializeTreasure(shell);sources.treasure=treasureBook
            local loreBook=ns.InitializeLore(shell,{},sources)
            return loreBook.journal,treasureBook.journal,loreBook,sources.atlas
        end
        function writing(j,title,session)
            return assert(j:CapturePage({sessionID=session or 'read',identity='item:1',
                title=title or 'Inscription',locale='enUS',sourceKind='item'},
                {number=1,raw='Preserved source',method='displayed',personallyViewed=true,first=true,last=true}))
        end
        function find(j,title)
            for _,e in pairs(j.entries or j.kinds) do if e.title==title or e.name==title then return e end end
        end
        function treasure(j,name,id)
            return assert(j:Record(id,{name=name or 'Chest',form='world',category='container',note='Kind note'},
                {context='world',location=T.CurrentLocation('world'),facts={inspected=true},capture='partial',
                 items={{itemID=2001,quantity=3,recovered=1}},note='Encounter note',access='Manual access'},'manual'))
        end
    """)
    return lua


class AccountLoreTreasureTests(unittest.TestCase):
    def test_real_initializers_select_local_or_shared_stores(self):
        for enabled in (False, True):
            with self.subTest(enabled=enabled):
                lua=client();lua.globals().enabled=enabled
                lua.execute("""
                    local lore,finds={},{}
                    local l,t=init(1,enabled,lore,finds)
                    writing(l);treasure(t)
                    if enabled then
                        assert(l.db==AzerothFieldbookAccountDB.sections.lore and l.db~=lore)
                        assert(t.db==AzerothFieldbookAccountDB.sections.treasure and t.db~=finds)
                        assert(not lore.entries and not finds.kinds)
                    else
                        assert(l.db==lore and t.db==finds)
                        assert(not AzerothFieldbookAccountDB.sections)
                    end
                    assert(ns.ActiveSectionStores.lore==l.db and ns.ActiveSectionStores.treasure==t.db)
                """)

    def test_cross_character_visibility_opt_out_and_repeated_reload(self):
        lua=client()
        lua.execute("""
            local a,b,ta,tb={},{},{},{}
            local l,t=init(1,false,a,ta);writing(l,'Local A');treasure(t,'Local A')
            local la,fa=snapshot(a),snapshot(ta)
            l,t=init(2,false,b,tb);writing(l,'Local B');treasure(t,'Local B')
            local lb,fb=snapshot(b),snapshot(tb)
            l,t=init(1,true,a,ta);writing(l,'Shared A','shared');treasure(t,'Shared A')
            assert(snapshot(a)==la and snapshot(ta)==fa,'import mutated originals')
            l,t=init(2,true,b,tb)
            assert(find(l,'Shared A') and find(t,'Shared A'))
            assert(size(l.entries)==3 and size(t.kinds)==3)
            assert(snapshot(b)==lb and snapshot(tb)==fb)
            local sharedLore,sharedTreasure=l.db,t.db
            local beforeL,beforeT=snapshot(sharedLore),snapshot(sharedTreasure)
            for pass=1,3 do
                l,t=init(2,false,b,tb)
                assert(l.db==b and t.db==tb and not find(l,'Shared A') and not find(t,'Shared A'))
                assert(size(l.entries)==1 and size(t.kinds)==1,'shared copied down')
                l,t=init(2,true,b,tb)
                assert(l.db==sharedLore and t.db==sharedTreasure)
                assert(snapshot(l.db)==beforeL and snapshot(t.db)==beforeT,'toggle/reload changed records')
            end
            l,t=init(2,false,b,tb);writing(l,'Later local','later');treasure(t,'Later local')
            l,t=init(2,true,b,tb)
            assert(not find(l,'Later local') and not find(t,'Later local'),'not a continuous sync')
            assert(snapshot(l.db)==beforeL and snapshot(t.db)==beforeT)
        """)

    def test_saved_state_reloads_in_a_fresh_lua_session_in_each_scope(self):
        lua=client()
        lua.execute("""
            personalLore={};personalTreasure={}
            local l,t=init(1,false,personalLore,personalTreasure);writing(l,'Local');treasure(t,'Local')
            l,t=init(1,true,personalLore,personalTreasure);writing(l,'Shared','shared');treasure(t,'Shared')
            function literal(value)
                if type(value)=='string' then return string.format('%q',value) end
                if type(value)~='table' then return tostring(value) end
                local parts={}
                for k,v in pairs(value) do parts[#parts+1]='['..literal(k)..']='..literal(v) end
                return '{'..table.concat(parts,',')..'}'
            end
        """)
        saved={name:lua.eval('literal('+name+')') for name in
               ('AzerothFieldbookAccountDB','personalLore','personalTreasure')}
        for enabled in (True,False,True):
            with self.subTest(enabled=enabled):
                fresh=client()
                for name,value in saved.items():
                    fresh.execute(name+'='+value)
                fresh.globals().enabled=enabled
                fresh.execute("""
                    local before=snapshot(AzerothFieldbookAccountDB)
                    local l,t=init(1,enabled,personalLore,personalTreasure)
                    assert(find(l,'Local') and find(t,'Local'))
                    assert((find(l,'Shared')~=nil)==enabled and (find(t,'Shared')~=nil)==enabled)
                    assert(snapshot(AzerothFieldbookAccountDB)==before,'startup repeated the import or allocated identities')
                """)

    def test_old_five_section_markers_do_not_skip_new_imports_or_repeat_old_ones(self):
        lua=client()
        lua.execute("""
            local lore,finds={},{}
            local l,t=init(7,false,lore,finds);writing(l);treasure(t)
            local acc=AzerothFieldbookAccountDB
            acc.importedCharacters={[7]=true};acc.bestiary={sentinel=123}
            acc.sections={};acc.sectionImports={}
            for _,section in ipairs({'gathering','atlas','angling','ledger'}) do
                acc.sections[section]={sentinel=section,counter=987};acc.sectionImports[section]={[7]=true}
            end
            local before=snapshot(acc)
            l,t=init(7,true,lore,finds)
            assert(size(l.entries)==1 and size(t.kinds)==1)
            assert(acc.sectionImports.lore[7] and acc.sectionImports.treasure[7])
            local loreStore,treasureStore=l.db,t.db
            l,t=init(7,true,lore,finds);assert(l.db==loreStore and t.db==treasureStore)
            local check=L.Copy(acc);check.sections.lore=nil;check.sections.treasure=nil
            check.sectionImports.lore=nil;check.sectionImports.treasure=nil
            assert(snapshot(check)==before,'old migrations were reset or changed')
        """)

    def test_lore_distinct_records_annotations_read_state_links_and_export_keys_survive(self):
        lua=client()
        lua.execute("""
            local a,b,ta,tb={},{},{},{}
            local l=init(1,false,a,ta);local one=writing(l)
            local keyA=assert(LR.Build(l,one.id)).sourceKey
            l=init(2,false,b,tb);local two=writing(l)
            assert(one.id==two.id)
            l:Update(two.id,{notes='Second annotations',theory='Keep this theory',tags={'Private tag'}})
            local passage=assert(l:AddPassage(two.id,{raw='Private annotation',origin='manual',nature='annotation'}))
            local place=assert(l:AddLocation(two.id,{meaning='read-here',zone='Coast',origin='manual'}))
            local variant=assert(l:Create('writing',{title='Separate variant'}));variant.variantOf=two.id
            local mystery=assert(l:Create('mystery',{title='Question'}))
            assert(l:AddLink(mystery.id,{section='lore',id=two.id,label='Evidence'}))
            assert(l:AddLink(mystery.id,{section='lore',id='lore:999',label='Deleted'}))
            l.state.reading={[two.id]={source='passage:'..passage.id,scroll=27}}
            local keyB=assert(LR.Build(l,two.id)).sourceKey
            local original=snapshot(b)
            l=init(1,true,a,ta);l=init(2,true,b,tb)
            assert(size(l.entries)==4,'similar writings collapsed')
            local imported
            for _,e in pairs(l.entries) do if e.notes=='Second annotations' then imported=e end end
            assert(imported and imported.id~=one.id)
            assert(imported.pages[1].raw=='Preserved source' and imported.pages[1].personallyViewed)
            assert(imported.passages[1].id==passage.id and imported.locations[1].id==place.id)
            assert(imported.theory=='Keep this theory' and imported.tags[1]=='Private tag')
            assert(l.state.reading[imported.id].scroll==27)
            assert(find(l,'Separate variant').variantOf==imported.id)
            local question=find(l,'Question');assert(question.links[1].id==imported.id)
            assert(not l:Get(question.links[2].id) and question.links[2].id~='lore:999')
            assert(assert(LR.Build(l,one.id)).sourceKey==keyA)
            assert(assert(LR.Build(l,imported.id)).sourceKey==keyB)
            assert(snapshot(b)==original,'local identity/evidence changed')
            local before=snapshot(l.db)
            l=init(1,true,a,ta);assert(snapshot(l.db)==before)
            local serial=l.db.serial;local count=size(l.entries)
            writing(l,'Inscription','reread')
            assert(size(l.entries)==count and l.db.serial==serial,'matching reread allocated another identity')
        """)

    def test_lore_export_identity_includes_original_source_across_characters(self):
        lua=client()
        lua.execute("""
            local a,ta={},{}
            local l=init(1,false,a,ta);local original=writing(l)
            local report=assert(LR.Build(l,original.id))
            local receiver=ns.CreateLoreJournal({});local received=assert(LR.Accept(receiver,assert(LR.Prepare(report))))
            l=init(1,true,a,ta);local accountEntry=assert(l:Create('mystery',{title='New shared question'}))
            local accountReport=assert(LR.Build(l,accountEntry.id))
            l=init(2,true,{},{})
            local exported=assert(LR.Build(l,original.id))
            assert(exported.sender=='Character 2')
            assert(exported.sourceKey==report.sourceKey and exported.originalSource==report.originalSource,
                're-export changed the original identity pair')
            now=now+1
            local same=assert(LR.Accept(receiver,assert(LR.Prepare(exported))))
            assert(same.id==received.id and size(receiver.entries)==1)
            local second=assert(LR.Build(l,accountEntry.id))
            assert(second.sourceKey==accountReport.sourceKey and second.originalSource==accountReport.originalSource)
        """)

    def test_imported_lore_children_keep_unique_ids_when_annotations_are_added(self):
        lua=client()
        lua.execute("""
            local a,b,ta,tb={},{},{},{}
            local first=init(1,true,a,ta);writing(first,'Different writing')
            local l=init(2,false,b,tb);local e=writing(l)
            local p=assert(l:AddPassage(e.id,{raw='First note'}))
            local place=assert(l:AddLocation(e.id,{zone='First place'}))
            l=init(2,true,b,tb);e=find(l,'Inscription')
            for i=1,4 do
                assert(l:AddPassage(e.id,{raw='New note '..i}))
                assert(l:AddLocation(e.id,{zone='New place '..i}))
            end
            assert(L.ValidateEntry(e,e.id),'new annotations collided with imported child IDs')
            assert(e.passages[1].id==p.id and e.locations[1].id==place.id)
            l=init(2,true,b,tb);assert(l.invalid==0 and size(l.entries)==2)
        """)

    def test_preexisting_account_atlas_alias_still_uses_the_f2_fallback(self):
        lua=client()
        lua.execute("""
            local atlas,lore,finds={},{},{}
            scope(1)
            local shared=ns.SelectSectionStorage('atlas',atlas)
            local aj=ns.CreateAtlasJournal(shared)
            local id=assert(aj:Save(fixture('Existing account discovery')))
            -- Lore used a local journal before F8 while Atlas was already shared.
            local l=ns.CreateLoreJournal(lore)
            local e=assert(l:Create('mystery',{title='Account question'}))
            l:AddLink(e.id,{section='atlas',id=id..'@:'..now,label='Existing account discovery'})
            local t,c,a;l,t,c,a=init(1,true,lore,finds,atlas)
            local link=find(l,'Account question').links[1]
            assert(c.references:Resolve(link).name=='Existing account discovery')
            assert(c.references:Open(link) and a.journal:Get(a.journal.state.selected).name=='Existing account discovery')
            l,t,c=init(2,true,{},{},{})
            assert(not c.references:Resolve(find(l,'Account question').links[1]).missing)
        """)

    def test_first_import_and_new_scope_allocations_have_independent_export_identities(self):
        lua=client()
        lua.execute("""
            local a,t={},{}
            local l,f=init(1,false,a,t);local original=writing(l);local kind=treasure(f)
            local originalKey=assert(LR.Build(l,original.id)).sourceKey
            l,f=init(1,true,a,t)
            assert(assert(LR.Build(l,original.id)).sourceKey==originalKey)
            local new=assert(l:Create('mystery',{title='Account new'}))
            local accountKey=assert(LR.Build(l,new.id)).sourceKey
            local _,accountEncounter=treasure(f,nil,kind.id)
            local accountKind=treasure(f,'Account kind')
            l,f=init(1,false,a,t)
            new=assert(l:Create('mystery',{title='Local new'}))
            assert(assert(LR.Build(l,new.id)).sourceKey~=accountKey)
            local _,localEncounter=treasure(f,nil,kind.id)
            local localKind=treasure(f,'Local kind')
            assert(accountEncounter.origin.key~=localEncounter.origin.key,'forked encounters share export identity')
            assert(accountKind.reference~=localKind.reference,'forked kinds share identity')
        """)

    def test_treasure_collision_preserves_history_annotations_reports_and_references(self):
        lua=client()
        lua.execute("""
            local a,b,ta,tb={},{},{},{}
            local l,t=init(1,false,a,ta);local first=treasure(t,'First chest')
            l,t=init(2,false,b,tb);local second,event=treasure(t,'Second chest')
            assert(first.id==second.id)
            t:Bookmark(second.id);t:Annotate(second.id,{bookmarkNote='Return soon',label='My label'})
            local report=assert(ns.TreasureReports.Build(t,second.id,{notes=true}))
            local q=assert(l:Create('mystery',{title='Find the chest'}))
            -- Existing legacy reference format from before account Treasure.
            l:AddLink(q.id,{section='treasure',id=second.id..'@:'..second.reference,label='Chest'})
            local oldReference,oldOrigin=second.reference,snapshot(event.origin)
            init(1,true,a,ta);local c
            l,t,c=init(2,true,b,tb)
            assert(size(t.kinds)==2 and size(t.encounters)==2)
            second=find(t,'Second chest');assert(second and second.id~=first.id)
            assert(second.reference==oldReference and second.note=='Kind note' and second.bookmark)
            assert(second.bookmarkNote=='Return soon' and second.label=='My label')
            local history=t:History(second.id);assert(#history==1)
            event=history[1];assert(event.kindID==second.id and snapshot(event.origin)==oldOrigin)
            assert(event.note=='Encounter note' and event.items[1].quantity==3 and event.items[1].recovered==1)
            assert(assert(ns.TreasureReports.Build(t,second.id,{notes=true})).identity.key==report.identity.key)
            assert(not c.references:Resolve(find(l,'Find the chest').links[1]).missing)
            local before=snapshot(t.db);init(2,true,b,tb);assert(snapshot(t.db)==before)
        """)

    def test_atlas_links_follow_import_owner_in_both_orders_and_local_scope(self):
        for order in ((1,2),(2,1)):
            with self.subTest(order=order):
                lua=client();lua.globals().first=order[0];lua.globals().second=order[1]
                lua.execute("""
                    local lore,finds,atlas={},{},{}
                    for i=1,2 do
                        lore[i]={};finds[i]={};atlas[i]={}
                        local l,t,c,a=init(i,false,lore[i],finds[i],atlas[i])
                        local id=assert(a.journal:Save(fixture('Place '..i)))
                        local e=assert(l:Create('mystery',{title='Question '..i}))
                        l:AddLink(e.id,{section='atlas',id=id..'@:'..now,label='Place '..i})
                        l:AddLink(e.id,{section='atlas',id=a.journal:Get(id).reference,label='Durable place '..i})
                    end
                    init(first,true,lore[first],finds[first],atlas[first])
                    local l,t,c,a=init(second,true,lore[second],finds[second],atlas[second])
                    for pass=1,3 do
                        for i=1,2 do
                            l,t,c,a=init(i,true,lore[i],finds[i],atlas[i])
                            for owner=1,2 do
                                for _,link in ipairs(find(l,'Question '..owner).links) do
                                    local resolved=c.references:Resolve(link)
                                    assert(not resolved.missing and resolved.name=='Place '..owner,'Atlas ID crossed owners')
                                    assert(c.references:Open(link))
                                    assert(a.journal:Get(a.journal.state.selected).name=='Place '..owner,'opened wrong discovery')
                                end
                            end
                            l,t,c,a=init(i,false,lore[i],finds[i],atlas[i])
                            assert(size(l.entries)==1)
                            local link=find(l,'Question '..i).links[1]
                            assert(not link.atlasOwner,'local link rewritten')
                            assert(c.references:Resolve(link).name=='Place '..i)
                        end
                    end
                """)

    def test_ambiguous_historical_atlas_mapping_stays_missing_for_other_characters(self):
        lua=client()
        lua.execute("""
            local atlas={};local j=ns.CreateAtlasJournal(atlas)
            j:Save(fixture('Old A'));j:Save(fixture('Old B'))
            local shared={records={},expeditions={}}
            for i=1,2 do
                local e=L.Copy(atlas.records['p'..i]);e.id='char2:'..i;e.reference=nil;shared.records[e.id]=e
                atlas.records['p'..i].reference=nil
            end
            atlas.origin=nil;atlas.loreAliases=nil
            AzerothFieldbookAccountDB.sections={atlas=shared}
            AzerothFieldbookAccountDB.sectionImports={atlas={[1]=true,[2]=true}}
            local lore,finds={},{}
            local l=init(2,false,lore,finds)
            local q=assert(l:Create('mystery',{title='Old question'}))
            l:AddLink(q.id,{section='atlas',id='p1@:'..now,label='Old A'})
            local t,c
            l,t,c=init(2,true,lore,finds,atlas)
            assert(c.references:Resolve(find(l,'Old question').links[1]).missing)
            l,t,c=init(1,true,{},{},{})
            assert(c.references:Resolve(find(l,'Old question').links[1]).missing,'another owner guessed historical ambiguity')
            l,t,c=init(2,true,lore,finds,atlas)
            assert(c.references:Resolve(find(l,'Old question').links[1]).missing)
        """)

    def test_malformed_retained_report_list_keys_survive_account_copy_for_validation(self):
        for field in ('pages','passages','locations','references','tags'):
            with self.subTest(field=field):
                lua=client();lua.globals().field=field
                lua.execute("""
                    local lore,finds={},{}
                    local l=init(2,false,lore,finds);local e=writing(l)
                    local report=assert(LR.Build(l,e.id));report.received=now
                    local values=field=='tags' and report.annotations.tags or report[field]
                    if not values then values={};report.annotations.tags=values end
                    values[false]='Malformed retained evidence'
                    e.reports={report}
                    assert(not L.ValidateEntry(e,e.id))
                    local before=snapshot(lore)
                    init(1,true,{},{})
                    l=init(2,true,lore,finds)
                    assert(l.invalid==1 and size(l.entries)==0)
                    local raw=l.db.entries[next(l.db.entries)]
                    local retained=field=='tags' and raw.reports[1].annotations.tags or raw.reports[1][field]
                    assert(retained[false]=='Malformed retained evidence','migration hid invalid evidence')
                    assert(snapshot(lore)==before)
                """)

    def test_invalid_saved_record_identities_are_not_repaired_by_rekeying(self):
        for section in ('lore','treasure'):
            with self.subTest(section=section):
                lua=client();lua.globals().section=section
                lua.execute("""
                    local lore,finds={},{}
                    local l,t=init(2,false,lore,finds);local e
                    if section=='lore' then
                        e=writing(l);lore.entries[e.id]=nil;e.id=false;lore.entries[false]=e
                    else
                        e=treasure(t);finds.kinds[e.id]=nil;e.id=false;finds.kinds[false]=e
                    end
                    local beforeL,beforeT=snapshot(lore),snapshot(finds)
                    init(1,true,{},{})
                    l,t=init(2,true,lore,finds)
                    assert(size(section=='lore' and l.entries or t.kinds)==0,'invalid identity became valid')
                    local rows=section=='lore' and l.db.entries or t.db.kinds
                    assert(rows[next(rows)].id==false,'original malformed identity was lost')
                    assert(snapshot(lore)==beforeL and snapshot(finds)==beforeT)
                """)

    def test_invalid_lore_link_and_variant_identities_remain_invalid_after_import(self):
        for field in ('link','variant'):
            with self.subTest(field=field):
                lua=client();lua.globals().field=field
                lua.execute("""
                    local lore,finds={},{}
                    local l=init(2,false,lore,finds);local e=writing(l)
                    if field=='link' then e.links={{section='lore',id=false,label='Invalid retained link'}}
                    else e.variantOf=123 end
                    assert(not L.ValidateEntry(e,e.id))
                    local before=snapshot(lore)
                    init(1,true,{},{})
                    l=init(2,true,lore,finds)
                    assert(l.invalid==1 and size(l.entries)==0,'invalid evidence became valid during rekeying')
                    local raw=l.db.entries[next(l.db.entries)]
                    assert((field=='link' and raw.links[1].id==false) or (field=='variant' and raw.variantOf==123))
                    assert(snapshot(lore)==before)
                """)

    def test_unsupported_stores_are_unchanged_and_do_not_get_import_markers(self):
        for section in ('lore','treasure'):
            for fixture in ('false', "{schema=99,marker='KEEP'}", "{schema='1',marker='KEEP'}"):
                with self.subTest(section=section,fixture=fixture):
                    lua=client();lua.globals().section=section
                    lua.execute('unsupported='+fixture)
                    lua.execute("""
                        local before=snapshot(unsupported)
                        local lore,finds={},{}
                        if section=='lore' then lore=unsupported else finds=unsupported end
                        local l,t=init(1,true,lore,finds)
                        assert((section=='lore' and l or t).readOnly)
                        assert(snapshot(unsupported)==before)
                        assert(not AzerothFieldbookAccountDB.sections or not AzerothFieldbookAccountDB.sections[section])
                        assert(not AzerothFieldbookAccountDB.sectionImports or not AzerothFieldbookAccountDB.sectionImports[section]
                            or not AzerothFieldbookAccountDB.sectionImports[section][1])
                    """)

    def test_received_treasure_evidence_keeps_its_receipts_and_original_identity(self):
        lua=client()
        lua.execute("""
            local source=ns.CreateTreasureJournal({});local kind=treasure(source,'Reported chest')
            local report=assert(ns.TreasureReports.Build(source,kind.id,{notes=true}))
            local lore,finds={},{}
            local l,t=init(2,false,lore,finds)
            local imported=assert(ns.TreasureReports.Accept(t,assert(ns.TreasureReports.Prepare(report))))
            local old=snapshot(t:History(imported.id)[1])
            init(1,true,{},{})
            l,t=init(2,true,lore,finds);local e=find(t,'Reported chest')
            local history=t:History(e.id);assert(#history==1)
            local row=L.Copy(history[1]);row.id=finds.encounters[next(finds.encounters)].id;row.kindID=imported.id
            assert(snapshot(row)==old,'reported facts or receipts changed')
            assert(t:Summary(e).personal==0 and t:Summary(e).reported==1)
            local forwarded=assert(ns.TreasureReports.Forward(t,history[1].id))
            assert(forwarded.identity.key==report.identity.key)
        """)

    def test_unsupported_shared_roots_defer_only_the_new_section_import(self):
        for section in ('lore','treasure'):
            for fixture in ('false', "{schema=99,marker='KEEP'}", "{schema=1,state='KEEP'}"):
                with self.subTest(section=section,fixture=fixture):
                    lua=client();lua.globals().section=section
                    lua.execute('unsupported='+fixture)
                    lua.execute("""
                        local lore,finds={},{}
                        local l,t=init(1,false,lore,finds);writing(l);treasure(t)
                        AzerothFieldbookAccountDB.sections={[section]=unsupported}
                        local before=snapshot(unsupported)
                        l,t=init(1,true,lore,finds)
                        assert((section=='lore' and l.db or t.db)==(section=='lore' and lore or finds))
                        assert(AzerothFieldbookAccountDB.sections[section]==unsupported and snapshot(unsupported)==before)
                        local markers=AzerothFieldbookAccountDB.sectionImports
                        assert(not markers[section] or not markers[section][1])
                    """)

    def test_new_initializers_and_selection_respect_latched_root_block(self):
        lua=client()
        lua.execute("""
            local l,t=init(1,true,{},{})
            writing(l);treasure(t)
            before=snapshot(AzerothFieldbookAccountDB)
        """)
        test_root_initialization.RootInitializationTests().block_existing_client(lua)
        lua.execute("""
            AzerothFieldbookDB={version=1}
            local localLore,localTreasure=snapshot(AzerothFieldbookLoreDB),snapshot(AzerothFieldbookTreasureDB)
            ns.InitializeSectionTracking({accountTrackingKey=99})
            assert(not ns.SelectSectionStorage('lore',{}));assert(not ns.SelectSectionStorage('treasure',{}))
            assert(not ns.InitializeLore(ns.CreateFieldbookShell(),{}))
            assert(not ns.InitializeTreasure(ns.CreateFieldbookShell()))
            assert(snapshot(AzerothFieldbookAccountDB)==before and ns.InitializationBlocked)
            assert(snapshot(AzerothFieldbookLoreDB)==localLore and snapshot(AzerothFieldbookTreasureDB)==localTreasure)
        """)


if __name__=='__main__':
    unittest.main()
