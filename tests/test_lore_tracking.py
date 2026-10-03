"""Deterministic ItemText lifecycle checks; these do not certify Forever APIs."""
import unittest
from ui_test_harness import new_ui_client
from atlas_test_harness import ENV


def client(settings='{}'):
    lua = new_ui_client(['AtlasJournal.lua', 'LoreJournal.lua', 'LoreTracking.lua'])
    lua.execute(ENV)
    lua.execute(r'''
        function GetLocale() return 'enUS' end
        ticks=0;timers={};requests={};open=false;scroll=87
        function later(delay,fn) timers[#timers+1]={at=ticks+delay,fn=fn};return true end
        function step(seconds)
            local untilAt=ticks+seconds;local guard=0
            while true do
                local index
                for i,v in ipairs(timers) do if v.at<=untilAt and (not index or v.at<timers[index].at) then index=i end end
                if not index then break end
                local v=table.remove(timers,index);ticks=v.at;v.fn();guard=guard+1;assert(guard<5000,'timer loop')
            end
            ticks=untilAt
        end
        book={title='Synthetic world book',identity='fixture:book',pages={'First page','Second page','Third page'},page=1,
            creatorKnown=true,nextKnown=true,hasNext=true,sourceKind='readable',locale='enUS'}
        adapter={Now=function() return ticks end,After=later,IsOpen=function() return open end,
            Scroll=function() return scroll end,RestoreScroll=function(v) restoredScroll=v end,
            Progress=function(v) progress=v end,CanTraverse=function() return navigation~=false end,
            IsMail=function() return mailbox==true end}
        function adapter.Read()
            local v=ns.Lore.Copy(book);v.raw=book.pages[book.page]
            if book.noText then v.raw=nil end
            v.hasNext=book.page<#book.pages
            if book.forcedNext~=nil then v.hasNext=book.forcedNext end
            return v
        end
        function adapter.HookNavigation(fn) navHook=fn;return hooks~=false end
        function adapter.Navigate(direction)
            navHook(direction);requests[#requests+1]=direction
            if decline then return false end
            if noProgress then later(0.02,function() t:Event('ITEM_TEXT_READY') end);return true end
            local delta=direction=='next' and 1 or -1
            local destination=book.page+delta
            later(delay or 0.02,function()
                if open then book.page=destination;t:Event('ITEM_TEXT_READY') end
            end)
            return true
        end
        function adapter.Unit(token) return token=='npc' and speaker or token=='target' and targetNPC end
        function adapter.Dialogue(kind)
            if dialogueText then return {raw=dialogueText,speaker=speaker,sourceTitle=questTitle} end
        end
        function begin(page)
            open=true;book.page=page or 1;t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY')
        end
        function close() open=false;t:Event('ITEM_TEXT_CLOSED') end
        function turn(page)
            navHook('player');book.page=page;t:Event('ITEM_TEXT_READY')
        end
        function writing() return j:List({kind='writing'})[1] end
        function pageCount(e) local n=0;for _ in pairs(e.pages) do n=n+1 end;return n end
        saved={};j=ns.CreateLoreJournal(saved)
    ''')
    lua.execute('settings=' + settings + ';t=ns.CreateLoreTracking(j,settings,adapter)')
    return lua


class LoreTrackingTests(unittest.TestCase):
    def test_native_object_dialogue_capture_and_manual_retry(self):
        lua = client()
        lua.execute("""
            local title='Draconic for Dummies'
            local guid='GameObject-0-1-2-3-180665-ABC'
            function UnitName(token) assert(token=='npc');return title end
            function UnitGUID(token) assert(token=='npc');return guid end
            function UnitIsPlayer() return false end
            C_GossipInfo={GetText=function() return 'Zenn tiros me enkil...' end}
            t=ns.CreateLoreTracking(j,settings)
            local notices=0;j.onRecorded=function() notices=notices+1 end
            t:Event('GOSSIP_SHOW')
            local e=writing();assert(e and e.title==title and e.pages[1].raw=='Zenn tiros me enkil...')
            assert(e.pages[1].personallyViewed and e.firstPage==1 and e.lastPage==1)
            e.firstPage=nil;e.lastPage=nil;e.pages[1].first=false;e.pages[1].last=false
            t:Event('GOSSIP_UPDATE');t:Event('GOSSIP_CLOSED');t:Event('GOSSIP_SHOW')
            assert(writing().lastPage==1,'reread repairs the previous partial archive')
            assert(#j:List({kind='writing'})==1 and notices==1)
            assert(next(j.sessions)==nil)
            t:Event('GOSSIP_CLOSED');assert(not t:CaptureCurrent())
            guid='Creature-0-1-2-3-91-ABC';title='Ordinary NPC'
            t:Event('GOSSIP_SHOW');assert(#j:List({kind='writing'})==1)
            guid=nil;title='Draconic for Dummies';settings.autoArchiveLore=false
            saved={};j=ns.CreateLoreJournal(saved);t=ns.CreateLoreTracking(j,settings)
            t:Event('GOSSIP_SHOW');assert(not writing())
            assert(t:CaptureCurrent());assert(writing().title==title)
            title='Unknown dialogue';t:Event('GOSSIP_SHOW');assert(not t.dialogue.writing)
        """)

    def test_defaults_false_values_and_no_default_navigation(self):
        lua = client()
        lua.execute('''
            assert(settings.autoArchiveLore and settings.loreOnlyOpenedPages)
            begin();step(2);assert(#requests==0 and pageCount(writing())==1)
            assert(writing().pages[1].personallyViewed and writing().pages[1].method=='displayed')
            turn(2);step(1);assert(#requests==0 and pageCount(writing())==2)
            settings.autoArchiveLore=false;settings.loreOnlyOpenedPages=false
            close();t=ns.CreateLoreTracking(j,settings,adapter);begin(3);step(1)
            assert(not settings.autoArchiveLore and not settings.loreOnlyOpenedPages)
            assert(pageCount(writing())==2 and #requests==0)
        ''')

    def test_opt_in_traversal_and_restore_without_personal_view_claims(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            begin();step(5);local e=writing()
            assert(pageCount(e)==3 and j:WritingSummary(e).complete)
            assert(e.pages[1].personallyViewed and not e.pages[2].personallyViewed)
            assert(e.pages[2].method=='automatic' and e.pages[3].method=='automatic')
            assert(book.page==1 and restoredScroll==87 and #requests==4)
            assert(t:GetStatus()=='Complete archive.' and progress==nil)
            assert(e.locations[1].meaning=='read-here')
        ''')

    def test_mid_book_backtracking_captures_preceding_pages(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            begin(2);step(5);local e=writing()
            assert(pageCount(e)==3 and j:WritingSummary(e).complete and book.page==2)
            assert(e.pages[2].personallyViewed and not e.pages[1].personallyViewed)
            assert(requests[1]=='previous' and requests[2]=='next')
        ''')

    def test_mid_book_displayed_only_retains_honest_gaps(self):
        lua = client()
        lua.execute('''
            begin(3);step(1);local e=writing()
            assert(e.lastPage==3 and not j:WritingSummary(e).complete and #requests==0)
            assert(e.firstPage==nil and pageCount(e)==1)
            turn(1);step(1);assert(#j:WritingSummary(e).missing==1 and j:WritingSummary(e).missing[1]==2)
        ''')

    def test_single_page_and_unknown_or_zero_pagination(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            book.pages={'Only page'};begin();step(1)
            assert(j:WritingSummary(writing()).complete and #requests==0)
            close();book.identity='zero';book.pages={[0]='Unnumbered page'};book.forcedNext=false
            begin(0);step(1);local entries=j:List({kind='writing'})
            assert(#entries==2 and j:WritingSummary(j:Get(t.active.entryID)).complete)
            close();book.identity='unusual';book.pages={[0]='First of an unusual sequence',[1]='More'};book.forcedNext=true
            begin(0);step(1);local e=j:Get(t.active.entryID)
            assert(not j:WritingSummary(e).complete and #requests==0 and t:GetStatus():find('unavailable'))
        ''')

    def test_nil_delayed_and_empty_ready_text(self):
        lua = client()
        lua.execute('''
            book.noText=true;begin();step(0.5);assert(not writing())
            book.noText=false;step(0.5);assert(writing().pages[1].raw=='First page')
            close();book.identity='empty';book.pages={''};begin();step(1)
            local e=j:Get(t.active.entryID);assert(e.pages[1].raw=='' and j:WritingSummary(e).complete)
        ''')

    def test_translation_invalidates_readiness_and_delayed_samples(self):
        lua = client()
        lua.execute('''
            begin();t:Event('ITEM_TEXT_TRANSLATION',1);step(1);assert(not writing())
            book.pages[1]='Translated text';t:Event('ITEM_TEXT_READY');step(1)
            assert(writing().pages[1].raw=='Translated text')
        ''')

    def test_duplicate_events_do_not_mark_automatic_pages_viewed(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            begin();t:Event('ITEM_TEXT_READY');t:Event('ITEM_TEXT_READY');step(.55)
            assert(book.page==2);t:Event('ITEM_TEXT_READY');step(.25)
            assert(not writing().pages[2].personallyViewed)
            step(5);assert(pageCount(writing())==3 and #j:List({kind='writing'})==1)
        ''')

    def test_close_and_new_source_cancel_old_callbacks(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            begin();step(.2);close();step(10);assert(pageCount(writing())==1 and #requests==0)
            book.title='Second source';book.identity='second';book.pages={'New source'}
            begin();step(.06);close();book.title='Third source';book.identity='third';book.pages={'Different source'}
            begin();step(2);local e=j:Get(t.active.entryID)
            assert(e.sourceTitle=='Third source' and e.pages[1].raw=='Different source')
            assert(#j:List({kind='writing'})==2)
        ''')

    def test_source_title_context_change_cannot_attach_stale_text(self):
        lua = client()
        lua.execute('''
            begin();step(.06);book.title='Changed';book.pages[1]='Unrelated';step(1)
            assert(not writing() and t:GetStatus():find('source changed'))
        ''')

    def test_manual_navigation_takes_over_and_remains_displayed_only(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            begin();step(.2);turn(3);step(2)
            local e=writing();assert(#requests==0 and pageCount(e)==2)
            assert(e.pages[3].personallyViewed and not e.pages[2] and book.page==3)
        ''')

    def test_options_cancel_work_and_do_not_delete_captured_text(self):
        for option in ['autoArchiveLore', 'loreOnlyOpenedPages']:
            lua = client('{loreOnlyOpenedPages=false}')
            lua.execute('''
                begin();step(.2);settings.%s=%s;t:OptionsChanged();step(10)
                assert(#requests==0 and pageCount(writing())==1)
            ''' % (option, 'false' if option == 'autoArchiveLore' else 'true'))

    def test_option_change_during_pending_page_does_not_claim_it_viewed(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            delay=1;begin();step(.4);assert(#requests==1)
            settings.loreOnlyOpenedPages=true;t:OptionsChanged();step(3)
            assert(pageCount(writing())==1 and #requests==1)
        ''')

    def test_timeout_no_progress_and_declined_navigation(self):
        for setup in ['noProgress=true', 'decline=true']:
            lua = client('{loreOnlyOpenedPages=false}')
            lua.execute(setup + '''
                begin();step(20);assert(#requests==1 and pageCount(writing())==1)
                assert(not j:WritingSummary(writing()).complete and not t.active.traversing)
            ''')

    def test_explicit_retry_after_no_progress_preserves_partial_and_completes(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            noProgress=true;begin();step(8);assert(pageCount(writing())==1)
            noProgress=false;assert(t:CaptureCurrent());step(5)
            assert(j:WritingSummary(writing()).complete and pageCount(writing())==3)
            assert(#j:List({kind='writing'})==1)
        ''')

    def test_unavailable_navigation_preserves_displayed_text(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            navigation=false;begin();step(1)
            assert(pageCount(writing())==1 and #requests==0 and t:GetStatus():find('unavailable'))
        ''')

    def test_privacy_automatic_exclusion_and_explicit_capture(self):
        for setup in ["book.playerAuthored=true;book.creator='Player'", 'book.creatorKnown=false', 'mailbox=true']:
            lua = client('{loreOnlyOpenedPages=false}')
            lua.execute(setup + '''
                begin();step(1);assert(not writing() and #requests==0)
                assert(t:CaptureCurrent());step(1);assert(pageCount(writing())==1 and #requests==0)
            ''')

    def test_master_off_explicit_capture_still_works_without_traversal(self):
        lua = client('{autoArchiveLore=false,loreOnlyOpenedPages=false}')
        lua.execute('''
            begin();step(1);assert(not writing());assert(t:CaptureCurrent());step(1)
            assert(pageCount(writing())==1 and #requests==0)
        ''')

    def test_ready_without_begin_recovers_visible_world_book(self):
        lua = client()
        lua.execute('''
            open=true;t:Event('ITEM_TEXT_READY');step(1)
            assert(writing() and pageCount(writing())==1)
            turn(2);step(1);turn(3);step(1)
            assert(#j:List({kind='writing'})==1 and j:WritingSummary(writing()).complete)
        ''')

    def test_ready_recovery_waits_for_native_reader_and_respects_close(self):
        for cancel in ["t:Event('ITEM_TEXT_CLOSED')", "t:Event('PLAYER_LEAVING_WORLD')", 'open=false']:
            lua = client()
            lua.execute("t:Event('ITEM_TEXT_READY');open=true;" + cancel + '''
                step(1);assert(not writing() and not t:CaptureCurrent())
            ''')
        lua = client()
        lua.execute('''
            assert(not t:CaptureCurrent(),'opening the Fieldbook cannot archive stale globals')
            t:Event('ITEM_TEXT_READY');open=true;step(1)
            assert(writing(),'native READY handlers can show the reader after our event')
        ''')

    def test_begin_stale_source_metadata_is_bound_at_ready(self):
        lua = client()
        lua.execute('''
            begin();step(1);close()
            open=true;t:Event('ITEM_TEXT_BEGIN')
            book.title='Aegwynn and the Dragon Hunt';book.identity='fixture:westfall-book'
            book.material='Parchment';book.pages={'New first page','New second page'}
            t:Event('ITEM_TEXT_READY');step(1)
            book.page=2;t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY');step(1)
            local found
            for _,e in ipairs(j:List({kind='writing'})) do
                if e.title==book.title then found=e end
            end
            assert(found and pageCount(found)==2 and j:WritingSummary(found).complete)
            assert(found.pages[1].raw=='New first page' and #j:List({kind='writing'})==2)
        ''')

    def test_deliberate_dialogue_correct_attribution_and_deduplication(self):
        lua = client()
        lua.execute('''
            speaker={guid='Creature-0-1-2-3-91-1',npcID=91,name='Actual speaker'}
            targetNPC={guid='Creature-0-1-2-3-42-1',npcID=42,name='Unrelated target'}
            dialogueText='The tower was here before us.';t:Event('GOSSIP_SHOW')
            assert(#j:List({kind='person'})==0)
            local e=assert(t:SavePassage());assert(e.npcID==91 and e.title=='Actual speaker')
            assert(e.passages[1].raw==dialogueText and e.passages[1].nature=='account')
            assert(e.passages[1].origin=='captured' and e.locations[1].meaning=='encounter')
            assert(t:RecordPerson().id==e.id and t:SavePassage().id==e.id)
            assert(#j:List({kind='person'})==1)
            speaker=targetNPC;assert(not t:SavePassage())
            t:Event('GOSSIP_CLOSED');assert(not t:SavePassage())
        ''')

    def test_dialogue_without_npc_context_never_uses_target(self):
        lua = client()
        lua.execute('''
            targetNPC={guid='Creature-0-1-2-3-42-1',npcID=42,name='Unrelated target'}
            dialogueText='An account without known speaker.';questTitle='Synthetic quest';t:Event('QUEST_DETAIL')
            local e=assert(t:SavePassage());assert(e.npcID==nil and e.title=='Unidentified speaker')
            assert(e.passages[1].sourceTitle=='Synthetic quest' and not t:RecordPerson())
            t:Event('QUEST_FINISHED');local target=assert(t:RecordPerson());assert(target.npcID==42)
            assert(target.locations[1].meaning=='observation')
        ''')

    def test_real_archive_survives_closing_and_reloading_with_annotations_separate(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            begin();step(5);local id=writing().id
            assert(j:Update(id,{notes='My private interpretation',title='My title'}))
            close();assert(next(j.sessions)==nil)
            j=ns.CreateLoreJournal(saved);local e=j:Get(id)
            assert(e.notes=='My private interpretation' and e.sourceTitle=='Synthetic world book')
            assert(e.pages[1].raw=='First page' and pageCount(e)==3 and j:WritingSummary(e).complete)
            assert(not e.pages[2].personallyViewed and e.title=='My title')
        ''')

    def test_size_limit_is_explicit_and_keeps_previously_stored_pages(self):
        lua = client('{loreOnlyOpenedPages=false}')
        lua.execute('''
            book.pages[2]=string.rep('x',131073);begin();step(3)
            assert(pageCount(writing())==1 and not j:WritingSummary(writing()).complete)
            assert(t:GetStatus():find('128 KiB') and #requests==1)
        ''')

    def test_identity_revalidated_even_for_same_title_and_page(self):
        lua = client()
        lua.execute('''
            begin();step(.06);book.identity='different physical work';book.pages[1]='Other content';step(1)
            assert(not writing() and t:GetStatus():find('source changed'))
        ''')

    def test_native_adapter_boolean_terminal_and_guarded_creator(self):
        lua = client()
        lua.execute('''
            nativeHooks={};C_Timer={After=later}
            function GetTime() return ticks end
            function hooksecurefunc(name,fn) nativeHooks[name]=fn end
            function ItemTextGetItem() return book.title end
            function ItemTextGetText() return book.pages[book.page] end
            function ItemTextGetPage() return book.page end
            function ItemTextGetMaterial() return 'Stone' end
            function ItemTextHasNextPage() return book.page<#book.pages end
            function ItemTextGetCreator() return nil end
            function ItemTextNextPage()
                requests[#requests+1]='next';book.page=book.page+1;t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY')
                if nativeHooks.ItemTextNextPage then nativeHooks.ItemTextNextPage() end
            end
            function ItemTextPrevPage()
                requests[#requests+1]='previous';book.page=book.page-1;t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY')
                if nativeHooks.ItemTextPrevPage then nativeHooks.ItemTextPrevPage() end
            end
            ItemTextFrame=CreateFrame('Frame');ItemTextFrame:Show()
            settings={loreOnlyOpenedPages=false};t=ns.CreateLoreTracking(j,settings)
            begin();step(5);assert(j:WritingSummary(writing()).complete and #requests==4)
            assert(writing().pages[1].personallyViewed and not writing().pages[2].personallyViewed)
            close();settings.loreOnlyOpenedPages=true;begin();step(1)
            ItemTextNextPage();step(1);ItemTextNextPage();step(1)
            assert(#j:List({kind='writing'})==1 and pageCount(writing())==3)
            assert(writing().pages[2].personallyViewed and writing().pages[3].personallyViewed)
            close();assert(j:Delete(writing().id));assert(#j:List({kind='writing'})==0)
            -- Native truthy/nil flags and post-call hooks, starting with an empty archive.
            function ItemTextHasNextPage() if book.page<#book.pages then return 1 end end
            begin();step(1);ItemTextNextPage();step(1);ItemTextNextPage();step(1)
            assert(#j:List({kind='writing'})==1 and pageCount(writing())==3 and j:WritingSummary(writing()).complete)
            close();begin();step(1);assert(#j:List({kind='writing'})==1)
            close();book.title='World book with false creator';book.pages={'World text'}
            function ItemTextGetCreator() return false end
            begin();step(1);assert(#j:List({kind='writing'})==2)
            close();assert(j:Delete(writing().id))
            close();book.title='Untrusted creator signal';book.pages={'Do not automatically collect'}
            function ItemTextGetCreator() error('unavailable') end
            begin();step(1);assert(#j:List({kind='writing'})==1)
            assert(t:CaptureCurrent());step(1);assert(#j:List({kind='writing'})==2)
        ''')

    def test_native_nil_pagination_is_unknown_and_missing_timers_degrade(self):
        lua = client()
        lua.execute('''
            C_Timer=nil
            function ItemTextGetItem() return 'Unpaged native source' end
            function ItemTextGetText() return 'Preserved available text' end
            function ItemTextGetPage() return nil end
            function ItemTextHasNextPage() return nil end
            function ItemTextGetCreator() return nil end
            t=ns.CreateLoreTracking(j,{loreOnlyOpenedPages=false})
            begin();local e=writing();assert(e and pageCount(e)==1 and not j:WritingSummary(e).complete)
            assert(t:GetStatus():find('unavailable') and #requests==0)
        ''')


if __name__ == '__main__':
    unittest.main()
