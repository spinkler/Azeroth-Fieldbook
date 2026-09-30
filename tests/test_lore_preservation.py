"""Lossless capture and duplicate handling at the real Lore capacity limits."""
import unittest
from ui_test_harness import new_ui_client


class LorePreservationTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_ui_client(['AtlasJournal.lua', 'LoreJournal.lua', 'LoreReports.lua'])
        self.lua.execute(r'''
            L=ns.Lore;R=ns.LoreReports
            function snapshot(v)
                if type(v)~='table' then return type(v)..':'..tostring(v) end
                local rows={};for k,x in pairs(v) do rows[#rows+1]=snapshot(k)..'='..snapshot(x) end
                table.sort(rows);return '{'..table.concat(rows,';')..'}'
            end
            function ctx(session,x)
                return {sessionID=session,title='Two-page book',locale='enUS',sourceKind='readable',
                    location={meaning='read-here',zone='Zone',mapID=37,x=x,y=4000,precision='player',method='observed',origin='captured'}}
            end
            function page(n,viewed)
                return {number=n,raw='Page '..n,method=viewed and 'displayed' or 'automatic',personallyViewed=viewed==true,first=n==1,last=n==2}
            end
            function location(x,note)
                return {meaning='observation',zone='Zone',mapID=37,x=x,y=4000,precision='manual',origin='manual',note=note}
            end
            function fixture(destinationLocations,sourceLocations)
                saved={};j=ns.CreateLoreJournal(saved)
                old=assert(j:CapturePage(ctx('older',1000),page(2,true)));j:EndCapture('older')
                target=assert(j:CapturePage(ctx('newer',2000),page(1,false)))
                assert(j:CapturePage(ctx('newer',2000),page(2,false)).id==target.id);j:EndCapture('newer')
                assert(old.id~=target.id,'fixture must reach consolidation with distinct IDs')
                for i=1,destinationLocations-1 do assert(j:AddLocation(target.id,location(2000+i))) end
                for i=1,sourceLocations-1 do assert(j:AddLocation(old.id,location(1000+i))) end
            end
            function completeAndCheck(reason)
                local before=snapshot(target);local sourceLocations=snapshot(old.locations)
                local oldID,created=old.id,old.created
                local sourceKey=assert(R.Build(j,old.id)).sourceKey
                assert(j:CapturePage(ctx('revisit',1000),page(2,true)).id==old.id)
                local e,err,notice=j:CapturePage(ctx('revisit',1000),page(1,true))
                assert(e and not err,'accepted page must not be reported as failure')
                assert(j:Get(oldID)==old,'consolidation deleted the source')
                assert(e==old and old.id==oldID and old.created==created,'source identity changed')
                assert(old.pages[1] and old.pages[2] and j:WritingSummary(old).complete,'accepted page was lost')
                assert(snapshot(old.locations)==sourceLocations,'source locations changed')
                assert(snapshot(target)==before,'consolidation partially mutated the destination')
                assert(j.sessions.revisit.id==oldID,'active session points at a retired record')
                assert(type(notice)=='string' and notice:find('kept separate',1,true),'successful capture needs a separate consolidation notice')
                if reason then assert(notice:find(reason,1,true),notice) end
                assert(R.Build(j,oldID).sourceKey==sourceKey,'export identity changed')
                local after=snapshot(saved)
                local reloaded=ns.CreateLoreJournal(saved)
                assert(reloaded:Get(oldID) and reloaded:Get(target.id),'reload deleted preserved records')
                assert(snapshot(saved)==after,'reload mutated preserved data')
                assert(R.Build(reloaded,oldID).sourceKey==sourceKey,'reload changed export identity')
            end
            function workBytes(e)
                return ns.CreateLoreJournal({schema=1,entries={[e.id]=L.Copy(e)},state={}}):ArchiveBytes()
            end
            function fillWork(owner,e,desired)
                while desired-workBytes(e)>L.MAX_PAGE_BYTES+256 do
                    assert(owner:AddPassage(e.id,{raw=string.rep('x',L.MAX_PAGE_BYTES),nature='annotation',source=tostring(#e.passages)}))
                end
                local room=desired-workBytes(e)-512
                if room>0 then assert(owner:AddPassage(e.id,{raw=string.rep('y',room),nature='annotation',source='last'})) end
            end
        ''')

    def test_full_destination_keeps_new_page_and_both_identities_through_reload(self):
        self.lua.execute("fixture(100,1);completeAndCheck('locations')")

    def test_partial_location_and_read_flag_transfers_never_publish(self):
        self.lua.execute("fixture(99,2);completeAndCheck('locations')")

    def test_real_work_byte_limit_keeps_source_and_destination(self):
        self.lua.execute(r'''
            fixture(1,1)
            assert(j:AddLocation(old.id,location(1001,string.rep('n',4000))))
            fillWork(j,target,L.MAX_WORK_BYTES)
            assert(workBytes(target)<=4194304 and workBytes(target)>4194304-1024)
            assert(L.ValidateEntry(target,target.id),'fixture must be a valid near-limit work')
            completeAndCheck('4 MiB')
        ''')

    def test_real_archive_boundary_preserves_accepted_page_on_skipped_merge(self):
        self.lua.execute(r'''
            fixture(100,1)
            for i=1,7 do
                local e=assert(j:Create('mystery',{title='Archive filler '..i}))
                fillWork(j,e,L.MAX_WORK_BYTES)
            end
            local filler=assert(j:Create('mystery',{title='Last archive filler'}))
            local free=L.MAX_ARCHIVE_BYTES-j:ArchiveBytes()-4096
            fillWork(j,filler,math.min(L.MAX_WORK_BYTES,free))
            assert(j:ArchiveBytes()>L.MAX_ARCHIVE_BYTES-16384 and j:ArchiveBytes()<=L.MAX_ARCHIVE_BYTES)
            completeAndCheck('locations')
        ''')

    def test_identity_unsafe_merge_is_skipped_even_when_all_data_fits(self):
        self.lua.execute("fixture(1,1);completeAndCheck('identit')")

    def test_reload_staging_cannot_exceed_real_archive_limit_with_annotations(self):
        self.lua.execute(r'''
            fixture(1,1)
            -- A valid historical duplicate with private annotations: converting
            -- them into passages would add metadata beyond the archive budget.
            local duplicate=L.Copy(target);duplicate.id=old.id
            for _,key in ipairs({'title','subtype','description','notes','theory','nextStep'}) do duplicate[key]='Private '..key end
            duplicate.title='Z Private title' -- reload orders by title; annotations belong to the proposed source
            j.entries[old.id]=duplicate;saved.entries[old.id]=duplicate
            assert(L.ValidateEntry(duplicate,duplicate.id))
            for i=1,7 do
                local e=assert(j:Create('mystery',{title='Archive filler '..i}))
                fillWork(j,e,L.MAX_WORK_BYTES)
            end
            local reserve=assert(j:Create('mystery',{title='Annotation reserve'}))
            local filler=assert(j:Create('mystery',{title='Last archive filler'}))
            fillWork(j,filler,math.min(L.MAX_WORK_BYTES,L.MAX_ARCHIVE_BYTES-j:ArchiveBytes()-4096))
            local room=L.MAX_ARCHIVE_BYTES-j:ArchiveBytes()-1
            assert(room>0 and room<32000)
            assert(j:Update(reserve.id,{notes=string.rep('z',room)}))
            assert(j:ArchiveBytes()==33554431,'fixture must reach the real archive boundary')
            local before=snapshot(saved)
            local reloaded=ns.CreateLoreJournal(saved)
            assert(reloaded:Get(old.id) and reloaded:Get(target.id) and snapshot(saved)==before,'archive-limit merge changed originals')
            assert(reloaded.consolidationNotice:find('32 MiB',1,true),reloaded.consolidationNotice)
        ''')

    def test_reload_preserves_annotations_links_reading_and_previously_exported_keys(self):
        self.lua.execute(r'''
            fixture(1,1)
            local duplicate=L.Copy(target);duplicate.id=old.id;duplicate.created=old.created-10
            duplicate.notes='Second private note';duplicate.tags={'private'};duplicate.pages[1].personallyViewed=true
            saved.entries[old.id]=duplicate;j.entries[old.id]=duplicate
            target.notes='First private note';saved.state.selected=old.id;saved.state.reading={[old.id]=2,[target.id]=1}
            assert(j:AddPassage(old.id,{raw='Private interpretation',nature='interpretation',private=true}))
            assert(j:AddPassage(target.id,{raw='Separate private annotation',nature='annotation',private=true}))
            local report=assert(R.Build(j,target.id))
            assert(R.Accept(j,assert(R.Prepare(assert(R.Encode(report)),'First courier')),old.id))
            assert(R.Accept(j,assert(R.Prepare(assert(R.Encode(report)),'Second courier')),target.id))
            local originalKey=assert(R.Build(j,old.id)).sourceKey
            local targetKey=assert(R.Build(j,target.id)).sourceKey
            local question=assert(j:Create('mystery',{title='Question'}))
            question.variantOf=old.id
            assert(j:AddLink(question.id,{section='lore',id=old.id,label='Original identity'}))
            local before=snapshot(saved)
            local reloaded=ns.CreateLoreJournal(saved)
            assert(reloaded:Get(old.id) and reloaded:Get(target.id),'reload retired distinct saved identities')
            assert(snapshot(saved)==before,'reload changed annotations, reading state, flags or references')
            assert(reloaded:Get(question.id).links[1].id==old.id)
            assert(reloaded:Get(question.id).variantOf==old.id)
            assert(R.Build(reloaded,old.id).sourceKey==originalKey and R.Build(reloaded,target.id).sourceKey==targetKey)
        ''')

    def test_selected_edited_and_referenced_sources_stay_protected(self):
        for protection in ('selected', 'edited', 'referenced'):
            with self.subTest(protection=protection):
                self.lua.execute("fixture(1,1)")
                self.lua.globals().protection = protection
                self.lua.execute(r'''
                    if protection=='selected' then saved.state.selected=old.id
                    elseif protection=='edited' then assert(j:Update(old.id,{notes='KEEP'}))
                    else
                        local q=assert(j:Create('mystery',{title='Question'}))
                        assert(j:AddLink(q.id,{section='lore',id=old.id,label='KEEP'}))
                    end
                    local before=snapshot(target)
                    assert(j:CapturePage(ctx('revisit',1000),page(2,true)).id==old.id)
                    assert(j:CapturePage(ctx('revisit',1000),page(1,true)).id==old.id)
                    assert(j:Get(old.id)==old and snapshot(target)==before,'protected source was consolidated')
                ''')

    def test_new_page_at_location_101_is_archived_without_changing_any_locations(self):
        self.lua.execute(r'''
            fixture(1,1)
            for i=1,99 do assert(j:AddLocation(old.id,location(3000+i))) end
            assert(j:CapturePage(ctx('revisit',1000),page(2,true)).id==old.id)
            local expected=L.Copy(saved);local locations=snapshot(old.locations)
            local e,err,notice=j:CapturePage(ctx('revisit',9999),page(1,true))
            assert(e==old and not err and e.pages[1].raw=='Page 1')
            assert(#e.locations==100 and snapshot(e.locations)==locations)
            assert(notice:find('Page archived.',1,true) and notice:find('location was not saved',1,true))
            assert(notice:find('100-location limit',1,true),notice)
            expected.entries[e.id].pages[1]=L.Copy(e.pages[1]);expected.entries[e.id].firstPage=1
            assert(snapshot(saved)==snapshot(expected),'only the new page and its boundary may change')
            assert(#j.sessions.revisit.locations==1,'declined location leaked into session evidence')
            local reloaded=ns.CreateLoreJournal(saved)
            assert(reloaded:Get(e.id).pages[1] and snapshot(saved)==snapshot(expected))
        ''')

    def test_duplicate_page_at_location_101_warns_without_adding_evidence(self):
        self.lua.execute(r'''
            fixture(1,1)
            for i=1,99 do assert(j:AddLocation(old.id,location(3000+i))) end
            local before=snapshot(saved)
            local e,err,notice=j:CapturePage(ctx('revisit',9999),page(2,true))
            assert(e==old and not err and snapshot(saved)==before)
            assert(notice:find('Page archived.',1,true) and notice:find('100-location limit',1,true))
            assert(#j.sessions.revisit.locations==0)
        ''')

    def test_new_page_at_known_location_when_full_needs_no_location_warning(self):
        self.lua.execute(r'''
            fixture(1,1)
            for i=1,99 do assert(j:AddLocation(old.id,location(3000+i))) end
            assert(j:CapturePage(ctx('revisit',1000),page(2,true)).id==old.id)
            local locations=snapshot(old.locations)
            local e,err,notice=j:CapturePage(ctx('revisit',1000),page(1,true))
            assert(e==old and e.pages[1] and not err and snapshot(e.locations)==locations)
            assert(not notice or not notice:find('location was not saved',1,true))
        ''')

    def test_location_cap_does_not_bypass_page_validation_or_work_capacity(self):
        self.lua.execute(r'''
            fixture(1,1)
            for i=1,99 do assert(j:AddLocation(old.id,location(3000+i))) end
            assert(j:CapturePage(ctx('revisit',1000),page(2,true)).id==old.id)
            local before=snapshot(saved)
            local invalidLocation=ctx('revisit',9999);invalidLocation.location.x=10001
            assert(not j:CapturePage(invalidLocation,page(1,true)))
            local limit=L.MAX_ARCHIVE_BYTES;L.MAX_ARCHIVE_BYTES=j:ArchiveBytes()+1
            local e,err,notice=j:CapturePage(ctx('revisit',9999),page(1,true))
            assert(not e and err:find('32 MiB',1,true) and not notice)
            assert(snapshot(saved)==before and not old.pages[1])
            L.MAX_ARCHIVE_BYTES=limit
            fillWork(j,old,L.MAX_WORK_BYTES)
            before=snapshot(saved)
            local invalid=page(1,true);invalid.raw=string.rep('x',L.MAX_PAGE_BYTES+1)
            assert(not j:CapturePage(ctx('revisit',9999),invalid))
            local large=page(1,true);large.raw=string.rep('x',2048)
            local e,err,notice=j:CapturePage(ctx('revisit',9999),large)
            assert(not e and err:find('4 MiB',1,true) and not notice)
            assert(snapshot(saved)==before and not old.pages[1])
        ''')

    def test_native_adapter_status_says_page_saved_but_location_101_declined(self):
        from test_lore_tracking import client
        lua = client()
        lua.execute(r'''
            book.pages={'First page','Second page'}
            begin(2);step(1);local e=writing();close()
            for i=1,99 do assert(j:AddLocation(e.id,{meaning='observation',zone='Zone',mapID=37,x=2000+i,y=4000,precision='manual'})) end
            function GetRealZoneText() return 'New reading zone' end
            local visible;t.onStatus=function(text) visible=text end
            begin(2);step(1);turn(1);step(1)
            assert(t.active.entryID==e.id and e.pages[1] and e.pages[2] and #e.locations==100)
            assert(visible==t:GetStatus() and visible:find('Complete archive.',1,true))
            assert(visible:find('Page archived.',1,true) and visible:find('location was not saved',1,true))
            assert(visible:find('100-location limit',1,true),visible)
        ''')

    def test_native_adapter_status_distinguishes_saved_page_from_skipped_merge(self):
        from test_lore_tracking import client
        lua = client()
        lua.execute(r'''
            book.identity=nil;book.pages={'First page','Second page'}
            begin(2);step(1);local source=writing();close()
            begin(1);step(1);turn(2);step(1);local destination=j:Get(t.active.entryID);close()
            assert(source.id~=destination.id,'fixture must use distinct captured entries')
            for i=1,99 do assert(j:AddLocation(destination.id,{meaning='observation',zone='Zone',mapID=37,x=2000+i,y=4000,precision='manual'})) end
            begin(2);step(1);turn(1);step(1)
            assert(t.active.entryID==source.id and j:Get(source.id) and j:Get(destination.id))
            assert(j:WritingSummary(source).complete,'accepted page did not complete the source')
            assert(t:GetStatus():find('Complete archive.',1,true) and t:GetStatus():find('kept separate',1,true),t:GetStatus())
            assert(not t:GetStatus():find('could not be preserved',1,true))
        ''')


if __name__ == '__main__':
    unittest.main()
