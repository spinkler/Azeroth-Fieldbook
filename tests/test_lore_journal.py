"""Lore archive invariants in a synthetic Lua 5.1 host; no live API claims."""
import unittest
from ui_test_harness import new_ui_client


class LoreJournalTests(unittest.TestCase):
    def test_recorded_callback_only_after_new_entry_is_saved(self):
        self.lua.execute('''
            recorded={}
            j.onRecorded=function(e)
                assert(j:Get(e.id)==e)
                if e.origin=='captured' then assert(next(e.pages),'Capture notification must follow page storage') end
                recorded[#recorded+1]=e.id
            end
            for _,kind in ipairs({'writing','landmark','person','mystery'}) do
                local e=assert(j:Create(kind,{title='New '..kind}))
                assert(j:Update(e.id,{notes='Updated annotation'}))
            end
            assert(#recorded==4)
            assert(not j:Create('writing',{title=''}));assert(#recorded==4)
            local e=assert(capture('a','item:1',1,'First page',true,false))
            assert(#recorded==5 and recorded[5]==e.id)
            assert(capture('a','item:1',2,'Second page',false,true).id==e.id)
            assert(capture('reread','item:1',1,'First page',true,false).id==e.id)
            assert(#recorded==5,'Extra pages and rereads are not new entries')
            assert(capture('variant','item:1',1,'Changed first page',true,true).id~=e.id)
            assert(#recorded==6)
            ns.CreateLoreJournal(saved);assert(#recorded==6,'Loading stored records is silent')
            j.readOnly=true;assert(not j:Create('writing',{title='Cannot save'}));assert(#recorded==6)
        ''')

    def setUp(self):
        self.lua = new_ui_client(['AtlasJournal.lua', 'LoreJournal.lua'])
        self.lua.execute('''
            L=ns.Lore;saved={};j=ns.CreateLoreJournal(saved)
            function context(session,identity,title)
                return {sessionID=session or 'read1',identity=identity,title=title or 'Old text',locale='enUS',sourceKind='item'}
            end
            function capture(session,identity,number,text,first,last)
                return j:CapturePage(context(session,identity),{number=number,raw=text,method='displayed',personallyViewed=true,first=first,last=last})
            end
            function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
        ''')

    def test_character_isolation_manual_types_and_reload(self):
        self.lua.execute('''
            AzerothFieldbookDB={points=912};AzerothFieldbookAccountDB={sections={}}
            for _,kind in ipairs({'writing','landmark','person','mystery'}) do
                local e=assert(j:Create(kind,{title='My '..kind,notes='Private',tags={'One','one','Two'}}))
                assert(#e.tags==2 and e.notes=='Private' and e.status=='open')
            end
            assert(count(j.entries)==4 and AzerothFieldbookDB.points==912 and next(AzerothFieldbookAccountDB.sections)==nil)
            local reloaded=ns.CreateLoreJournal(saved);assert(count(reloaded.entries)==4 and not reloaded.readOnly)
        ''')

    def test_future_or_malformed_schema_is_detached_and_untouched(self):
        self.lua.execute('''
            local future={schema=99,entries={keep={raw='original'}},state={selected='keep'}}
            local f=ns.CreateLoreJournal(future);assert(f.readOnly and next(f.entries)==nil)
            assert(not f:Create('person',{title='No'}));f.state.selected='new'
            assert(future.schema==99 and future.state.selected=='keep' and future.entries.keep.raw=='original')
            local malformed={schema=1,entries='important invalid original'}
            local m=ns.CreateLoreJournal(malformed);assert(m.readOnly and malformed.entries=='important invalid original')
            local bad={schema=1,entries={bad={id='bad'}},state={}}
            local b=ns.CreateLoreJournal(bad);assert(b.invalid==1 and bad.entries.bad.id=='bad')
        ''')

    def test_source_and_annotation_provenance_are_independent(self):
        self.lua.execute('''
            local e=assert(capture('a','item:1',1,'<HTML><BODY>Original café |cfffffffftext|r</BODY></HTML>',true,true))
            assert(e.pages[1].raw:find('<HTML>',1,true) and e.pages[1].origin=='captured' and e.pages[1].nature=='source')
            assert(L.Plain(e.pages[1].raw)=='Original café text')
            local p=assert(j:AddPassage(e.id,{raw='I suspect a hidden meaning',origin='manual',nature='interpretation'}))
            local r=assert(j:AddPassage(e.id,{raw='Someone says so',origin='reported',nature='account',sender='Actual sender',claimedObserver='Claimed witness',personallyViewed=true}))
            assert(p.private and r.sender=='Actual sender' and r.claimedObserver=='Claimed witness' and not r.personallyViewed)
            assert(not j:RemovePassage(e.id,r.id));assert(j:RemovePassage(e.id,p.id))
            assert(j:Update(e.id,{title='My label',sourceTitle='Wrong',notes='My note'}))
            assert(e.title=='My label' and e.sourceTitle=='Old text' and e.pages[1].raw:find('Original',1,true))
        ''')

    def test_same_titles_require_exact_page_evidence(self):
        self.lua.execute('''
            local a=assert(capture('a',nil,1,'Identical',true,false))
            local b=assert(capture('b',nil,1,'Identical',true,false));assert(a.id==b.id)
            assert(capture('other',nil,1,'Different',true,false).id~=a.id)
            local c=assert(capture('c','item:1',1,'Identical',true,true))
            local d=assert(capture('d','item:1',1,'Identical',true,true));assert(c.id==d.id)
            assert(count(j.entries)==3)
        ''')

    def test_repeated_reads_reuse_evidence_and_conflicting_versions_remain_separate(self):
        self.lua.execute('''
            local a=assert(capture('a',nil,1,'Same beginning',true,false))
            capture('a',nil,2,'Same ending',false,true)
            local b=assert(capture('b',nil,1,'Same beginning',true,false));assert(a.id==b.id)
            local dedup=assert(capture('b',nil,2,'Same ending',false,true));assert(a.id==dedup.id and count(j.entries)==1)
            local c=assert(capture('c',nil,1,'Same beginning',true,false))
            c=assert(capture('c',nil,2,'Different ending',false,true));assert(count(j.entries)==2 and c.pages[2].raw=='Different ending')
            local d=assert(capture('d',nil,1,'Same beginning',true,false));j:Update(d.id,{notes='Personal annotation'})
            capture('d',nil,2,'Same ending',false,true);assert(count(j.entries)==2 and d.notes=='Personal annotation')
            capture('e',nil,1,'Same beginning',true,false)
            assert(capture('e',nil,2,'Different ending',false,true).id==c.id and count(j.entries)==2)
        ''')

    def test_reload_retains_duplicate_identities_notes_and_links_without_aliases(self):
        self.lua.execute('''
            local a=assert(capture('a',nil,1,'Original page',true,false));a.notes='First private note'
            local b=L.Copy(a);b.id='lore:99';b.notes='Second private note';b.revisit=true
            saved.entries[b.id]=b;saved.state.selected=b.id
            local mystery=assert(j:Create('mystery',{title='Question'}))
            assert(j:AddLink(mystery.id,{section='lore',id=b.id,label=b.title}))
            local reload=ns.CreateLoreJournal(saved);local rows=reload:List({kind='writing'})
            -- A duplicate's ID/creation stamp can already be in an exported
            -- report. Keep both identities until persistent aliases are defined.
            assert(#rows==2 and reload:Get(a.id).notes=='First private note')
            assert(reload:Get(b.id).notes=='Second private note' and reload:Get(b.id).revisit)
            assert(#reload:Get(a.id).passages==0 and #reload:Get(b.id).passages==0)
            assert(mystery.links[1].id==b.id and saved.state.selected==b.id)
            assert(#ns.CreateLoreJournal(saved):List({kind='writing'})==2)
        ''')

    def test_conflicting_later_page_forks_session_evidence_without_composite(self):
        self.lua.execute('''
            local a=assert(capture('a','item:1',1,'Shared introduction',true,false))
            assert(capture('a','item:1',2,'Old ending',false,true).id==a.id)
            assert(capture('b','item:1',1,'Shared introduction',true,false).id==a.id)
            local b=assert(capture('b','item:1',2,'Different ending',false,true))
            assert(a.id~=b.id and b.variantOf==a.id and a.pages[2].raw=='Old ending')
            assert(b.pages[1].raw=='Shared introduction' and b.pages[2].raw=='Different ending')
            assert(j:WritingSummary(a).complete and j:WritingSummary(b).complete)
            local c=assert(capture('c','item:1',3,'Only page three',false,true))
            assert(c.id~=a.id and c.id~=b.id and c.pages[1]==nil and c.pages[2]==nil)
        ''')

    def test_missing_page_requires_overlapping_evidence_to_resume(self):
        self.lua.execute('''
            local a=assert(capture('a','item:2',1,'Page one',true,false))
            local b=assert(capture('b','item:2',2,'Page two',false,true))
            assert(a.id~=b.id and not j:WritingSummary(a).complete and not j:WritingSummary(b).complete)
            local c=assert(capture('c','item:2',1,'Page one',true,false));assert(c.id==a.id)
            local d=assert(capture('c','item:2',2,'Page two',false,true))
            assert(d.id==a.id and d.id~=b.id and d.pages[1] and d.pages[2])
        ''')

    def test_partial_rereads_without_source_id_reuse_and_delete_allows_recapture(self):
        self.lua.execute('''
            local a=assert(capture('a',nil,1,'Page one',true,false))
            j:EndCapture('a')
            assert(capture('b',nil,1,'Page one',true,false).id==a.id)
            assert(capture('b',nil,2,'Page two',false,true).id==a.id and count(j.entries)==1)
            assert(j:Delete(a.id) and count(j.entries)==0)
            local b=assert(capture('b',nil,1,'Page one',true,false));assert(b.id~=a.id)
            assert(capture('c',nil,1,'Page one',true,false).id==b.id and count(j.entries)==1)
            assert(capture('d',nil,1,'Different work',true,false).id~=b.id)
        ''')

    def test_page_duplicates_unknowns_empty_and_missing_boundaries(self):
        self.lua.execute('''
            local a=assert(capture('a',nil,nil,'Unnumbered'))
            assert(a.pages['unknown:1'].number==nil and j:WritingSummary(a).last==nil)
            assert(capture('a',nil,nil,'Unnumbered').id==a.id and count(a.pages)==1)
            local b=assert(capture('b',nil,1,'',true,true));assert(b.pages[1].raw=='' and j:WritingSummary(b).complete)
            assert(capture('b',nil,1,'',true,true).id==b.id and count(b.pages)==1)
            local c=assert(capture('c',nil,1,'Beginning',true,false))
            assert(capture('c',nil,3,'End',false,true).id==c.id)
            local summary=j:WritingSummary(c);assert(not summary.complete and summary.missing[1]==2)
            assert(not j:SetCaptureStatus(c.id,'complete'))
            assert(j:SetCaptureStatus(c.id,'interrupted','Closed early'));assert(j:WritingSummary(c).status=='interrupted')
        ''')

    def test_search_filters_and_cache_invalidation(self):
        self.lua.execute('''
            local e=assert(j:Create('mystery',{title='Hidden door',notes='Private hypothesis',tags={'Puzzle'},revisit=true,status='investigating'}))
            assert(j:AddPassage(e.id,{raw='Listen for singing',nature='observation'}))
            assert(j:AddLocation(e.id,{zone='Forest',meaning='mentioned',origin='reported'}))
            assert(j:AddLocation(e.id,{zone='Coast',meaning='observation'}))
            assert(#j:List({query='singing',kind='mystery',zone='Coast',revisit=true,status='investigating',origin='reported'})==1)
            assert(#j:List({query='puzzle'})==1 and #j:List({query='hypothesis'})==1)
            assert(j:Update(e.id,{notes='New thought',status='resolved'}))
            assert(#j:List({query='hypothesis'})==0 and #j:List({status='resolved'})==1)
            assert(j:Update(e.id,{status='open'}));assert(e.status=='open')
        ''')

    def test_location_meaning_accuracy_and_dangling_links(self):
        self.lua.execute('''
            local e=assert(j:Create('landmark',{title='Stone'}))
            local p=assert(j:AddLocation(e.id,{mapID=1,x=2000,y=3000,precision='player',meaning='read',origin='captured'}))
            assert(p.meaning=='read-here' and p.precision=='player')
            assert(not j:AddLocation(e.id,{mapID=1,x=0,y=0,precision='manual'}))
            assert(not j:AddLocation(e.id,{mapID=1,x=1000,precision='manual'}))
            local u=assert(j:AddLocation(e.id,{zone='Unknown',meaning='mentioned'}));assert(u.x==nil)
            local link=assert(j:AddLink(e.id,{section='atlas',id='deleted-place',label='Past place',explanation='May be connected'}))
            assert(link.id=='deleted-place' and #e.links==1)
            assert(j:RemoveLink(e.id,'deleted-place','atlas') and #e.links==0)
        ''')

    def test_bounds_refuse_without_truncation_or_partial_mutation(self):
        self.lua.execute('''
            local e,err=capture('a',nil,1,string.rep('x',L.MAX_PAGE_BYTES+1),true,true)
            assert(not e and err:find('nothing was truncated',1,true) and count(j.entries)==0)
            e=assert(capture('b',nil,1,string.rep('x',L.MAX_PAGE_BYTES),true,true));assert(#e.pages[1].raw==L.MAX_PAGE_BYTES)
            local before=count(e.pages);assert(not capture('b',nil,257,'Bad'));assert(count(e.pages)==before)
            local old=L.MAX_ARCHIVE_BYTES;L.MAX_ARCHIVE_BYTES=#e.pages[1].raw
            assert(not j:AddPassage(e.id,{raw='More'}));assert(#e.passages==0);L.MAX_ARCHIVE_BYTES=old
            local cycle={};cycle.self=cycle;assert(L.Copy(cycle).self==nil)
            assert(not j:Create('person',{title=secret}))
        ''')

    def test_changed_source_page_never_carries_old_unvisited_pages(self):
        self.lua.execute('''
            local a=assert(capture('a',nil,1,'Old beginning',true,false))
            capture('a',nil,2,'Old ending',false,true)
            local b=assert(capture('a',nil,1,'Changed beginning',true,false))
            assert(a.id~=b.id and a.pages[2].raw=='Old ending' and b.pages[2]==nil)
            assert(not j:WritingSummary(b).complete and b.lastPage==nil)
            local c=assert(capture('c','stable',1,'Shared',true,false))
            j:CapturePage(context('c','stable'),{number=1,raw='Shared',method='automatic',personallyViewed=false})
            local d=assert(capture('c','stable',1,'Changed',true,false))
            assert(c.pages[1].personallyViewed and d.pages[1].raw=='Changed')
            j:EndCapture('c');assert(j.sessions.c==nil)
        ''')

    def test_notes_count_toward_capacity_and_failed_replace_is_atomic(self):
        self.lua.execute('''
            local e=assert(j:Create('mystery',{title='Capacity'}))
            local limit=L.MAX_ARCHIVE_BYTES;L.MAX_ARCHIVE_BYTES=j:ArchiveBytes()+10
            assert(not j:Update(e.id,{notes=string.rep('x',100)}));assert(e.notes=='')
            local proposed=L.Copy(e);proposed.notes=string.rep('x',100)
            assert(not j:ReplaceEntry(e.id,proposed));assert(j:Get(e.id)==e and e.notes=='')
            L.MAX_ARCHIVE_BYTES=limit
            assert(j:Update(e.id,{notes=string.rep('x',100)}));assert(j:ArchiveBytes()>100)
            local valid=assert(L.ValidateEntry(e,e.id));valid.extra='Unknown future metadata'
            saved.entries[e.id]=valid
            local reloaded=ns.CreateLoreJournal(saved);assert(reloaded:Get(e.id).extra=='Unknown future metadata')
        ''')

    def test_encounter_dates_ignore_annotation_edits_and_reported_material(self):
        self.lua.execute('''
            now=100;local e=assert(capture('a',nil,1,'Text',true,true))
            assert(e.firstEncounter==100 and e.lastEncounter==100)
            now=200;j:Update(e.id,{notes='A later thought'})
            assert(e.updated==200 and e.lastEncounter==100)
            now=300;capture('a',nil,1,'Text',true,true)
            assert(e.firstEncounter==100 and e.lastEncounter==300)
            now=400;j:AddPassage(e.id,{raw='Reported assertion',origin='reported',nature='account'})
            assert(e.lastEncounter==300)
            now=500;j:AddPassage(e.id,{raw='NPC assertion',origin='captured',nature='account'})
            assert(e.firstEncounter==100 and e.lastEncounter==500)
            local reloaded=ns.CreateLoreJournal(saved);assert(reloaded:Get(e.id).lastEncounter==500)
        ''')

    def test_passage_privacy_defaults_preserve_source_and_personal_boundaries(self):
        self.lua.execute('''
            assert(not L.Passage({raw='A transcription',origin='manual',nature='source'}).private)
            assert(not L.Passage({raw='NPC says',origin='captured',nature='account'}).private)
            assert(L.Passage({raw='My observation',origin='manual',nature='observation'}).private)
            assert(L.Passage({raw='My interpretation',origin='manual',nature='interpretation'}).private)
            assert(L.Passage({raw='Private source',origin='captured',nature='source',private=true}).private)
            assert(not L.Passage({raw='Shared interpretation',nature='interpretation',private=false}).private)
        ''')

    def test_background_duplicate_never_deletes_selected_edited_or_linked_work(self):
        self.lua.execute('''
            local a=assert(capture('original',nil,1,'A',true,false));capture('original',nil,2,'B',false,true)
            local selected=assert(capture('selected',nil,1,'A',true,false));j.state.selected=selected.id
            assert(capture('selected',nil,2,'B',false,true).id==selected.id and j:Get(selected.id))
            j.state.selected=nil
            local edited=assert(capture('edited',nil,1,'A',true,false));j:Update(edited.id,{theory='An idea',nextStep='Look closer'})
            assert(capture('edited',nil,2,'B',false,true).id==edited.id)
            local linked=assert(capture('linked',nil,1,'A',true,false))
            local mystery=assert(j:Create('mystery',{title='Question'}));j:AddLink(mystery.id,{section='lore',id=linked.id,label='Evidence'})
            assert(capture('linked',nil,2,'B',false,true).id==linked.id and j:Get(linked.id))
        ''')

    def test_raw_source_search_render_and_report_roundtrip_remain_lossless(self):
        lua = new_ui_client(['AtlasJournal.lua', 'LoreJournal.lua', 'LoreReports.lua'])
        lua.execute('''
            local L,R=ns.Lore,ns.LoreReports
            local raw='<HTML><BODY><P>café — 星 |cffffffffgold|r &amp; blue</P></BODY></HTML>'
            local source={};local j=ns.CreateLoreJournal(source)
            local e=assert(j:CapturePage({sessionID='read',title='Original'},
                {number=1,raw=raw,method='displayed',personallyViewed=true,first=true,last=true}))
            L.Safe(L.Plain(raw));assert(#j:List({query='gold & blue'})==1 and e.pages[1].raw==raw)
            local report=assert(R.Build(j,e.id));local envelope=assert(R.Encode(report));local decoded=assert(R.Decode(envelope))
            assert(decoded.pages[1].raw==raw)
            local target={};local other=ns.CreateLoreJournal(target)
            local ticket=assert(R.Prepare(decoded,'Known messenger'));local received=assert(R.Accept(other,ticket))
            assert(received.origin=='reported' and next(received.pages)==nil and received.reports[1].pages[1].raw==raw)
            assert(#other:List({query='gold & blue',origin='reported'})==1 and #other:List({origin='captured'})==0)
            metadataVersion=decoded.addonVersion..'-other'
            local reload=ns.CreateLoreJournal(target);assert(reload:Get(received.id).reports[1].pages[1].raw==raw)
            assert(reload:Get(received.id).reports[1].receivedFrom=='Known messenger')
            assert(not R.Decode(envelope),'Old installed-version imports must still be rejected')
        ''')


if __name__ == '__main__':
    unittest.main()
