"""Native item-source adapters, quest labels and correspondence boundaries."""
import unittest

from test_lore_tracking import client
from ui_test_harness import ROOT


def item_client():
    lua = client()
    lua.execute('''
        nativeHooks={};C_Timer={After=later}
        function GetTime() return ticks end
        function hooksecurefunc(owner,name,callback)
            if type(owner)=='string' then nativeHooks[owner]=name
            else nativeHooks[name]=callback end
        end
        book.title='Translated Letter from The Embalmer';book.pages={'Synthetic quest letter text'}
        itemID=3248;itemClass=12;itemName=book.title;openerGUID='Item-0-12345'
        C_Item={GetItemIDByGUID=function(guid) assert(guid==openerGUID);return itemID end,
            GetItemInfo=function(id)
                assert(id==itemID)
                return itemName,'item:'..id,nil,nil,nil,nil,nil,nil,nil,nil,nil,itemClass
            end}
        C_Container={UseContainerItem=function() end,GetContainerItemID=function() return itemID end}
        function UnitGUID(token) if token=='npc' then return openerGUID end end
        function ItemTextGetItem() return book.title end
        function ItemTextGetText() return book.pages[math.max(1,book.page)] end
        function ItemTextGetPage() return book.page end
        function ItemTextHasNextPage() return false end
        -- A known game item can establish eligibility when the creator API is
        -- absent, fails, or supplies an author the generic path cannot classify.
        ItemTextGetCreator=nil
        ItemTextFrame=CreateFrame('Frame');ItemTextFrame:Show()
        t=ns.CreateLoreTracking(j,settings)
        function useBag()
            nativeHooks.UseContainerItem(0,1)
        end
    ''')
    return lua


class LoreItemTests(unittest.TestCase):
    def test_manual_right_clicked_without_bag_use_hook_or_reader_guid(self):
        lua = item_client()
        lua.execute('''
            itemID=10789;itemName='Manual of Engineering Disciplines';book.title=itemName;openerGUID=nil
            local button={GetBagID=function() return 0 end,GetID=function() return 7 end}
            function GetMouseFoci() return {button} end
            function C_Container.GetContainerItemInfo(bag,slot)
                assert(bag==0 and slot==7);return {itemID=itemID,isReadable=true,itemName=itemName}
            end
            t:Event('GLOBAL_MOUSE_DOWN','LeftButton');begin();step(4)
            assert(not writing() and t:GetStatus():find('author check'));close()
            t:Event('GLOBAL_MOUSE_DOWN','RightButton');assert(not writing())
            begin();step(1);assert(writing().identity=='item:10789' and writing().pages[1].raw==book.pages[1])
            close();assert(j:Delete(writing().id))
            itemID=8383;itemClass=0
            t:Event('GLOBAL_MOUSE_DOWN','RightButton');begin();step(1);assert(not writing())
        ''')

    def test_manual_opener_only_available_at_begin(self):
        lua = item_client()
        lua.execute('''
            itemID=10789;itemName='Manual of Engineering Disciplines';book.title=itemName
            book.pages={'First engineering page','Second engineering page'}
            function ItemTextHasNextPage() return book.page<#book.pages end
            local hints=ns.CreateLoreTooltips(j,settings)
            assert(hints:Status(itemName,itemID,'item'))
            t:Event('ITEM_TEXT_BEGIN');openerGUID=nil
            t:Event('ITEM_TEXT_READY');step(1)
            local e=assert(writing());assert(e.identity=='item:10789' and e.subtype=='Quest item')
            book.page=2;t:Event('ITEM_TEXT_READY');step(1)
            assert(e.pages[2].raw==book.pages[2] and j:WritingSummary(e).complete)
            assert(not hints:Status(itemName,itemID,'item'));close()
            assert(j:Delete(e.id));begin();step(1);assert(not writing())
        ''')

    def test_uncatalogued_plaque_correlated_with_native_reader(self):
        lua = item_client()
        lua.execute('''
            openerGUID=nil;book.title='A newly discovered plaque'
            Enum.TooltipDataType={Object=4}
            C_TooltipInfo={GetWorldCursor=function()
                return {type=4,id=900003,lines={{leftText=book.title}}}
            end}
            begin();step(1);assert(writing().identity=='gameobject:900003')
        ''')

    def test_uncatalogued_carried_quest_book_with_late_item_info(self):
        lua = item_client()
        lua.execute('''
            openerGUID=nil;itemID=900002;itemName='An uncatalogued book';book.title=itemName
            local cached=C_Item.GetItemInfo
            C_Item.GetItemInfo=function(id) if ticks>=0.55 then return cached(id) end end
            useBag();begin();step(1)
            assert(writing().identity=='item:900002' and writing().pages[1].raw==book.pages[1])
        ''')

    def test_reader_with_initially_missing_source_retries_without_another_ready(self):
        lua = item_client()
        lua.execute('''
            openerGUID=nil;itemID=10789;itemName='Manual of Engineering Disciplines';book.title=itemName
            C_Item.GetItemInfo=nil
            begin();step(.5);assert(not writing())
            openerGUID='Item-0-12345';step(1)
            assert(writing().identity=='item:10789' and writing().pages[1].raw==book.pages[1])
        ''')

    def test_uncatalogued_item_with_localized_heading_in_replacement_reader(self):
        lua = item_client()
        lua.execute('''
            function GetLocale() return 'deDE' end
            itemID=900002;itemName='Handbuch';book.title='Vorwort'
            ItemTextFrame:Hide();settings.loreOnlyOpenedPages=false
            begin();step(1);assert(writing().identity=='item:900002' and writing().pages[1].raw==book.pages[1])
            close();assert(not t:CaptureCurrent())
        ''')

    def test_dialogueui_prefetch_records_world_book_with_no_fieldbook_page_turns(self):
        for only_opened in (True, False):
            with self.subTest(only_opened=only_opened):
                lua = item_client()
                lua.globals().settings.loreOnlyOpenedPages = only_opened
                lua.execute('''
                    openerGUID='GameObject-0-1-2-3-900003-ABC'
                    book.title='World book in DialogueUI'
                    book.pages={'Opening page','Middle page','Final page'}
                    function ItemTextHasNextPage() return book.page<#book.pages end
                    local pageRequests=0
                    function ItemTextNextPage() pageRequests=pageRequests+1 end
                    function ItemTextPrevPage() pageRequests=pageRequests+1 end
                    ItemTextFrame:Hide()
                    function ItemTextFrame:IsEventRegistered(event)
                        assert(event=='ITEM_TEXT_READY');return false
                    end
                    t=ns.CreateLoreTracking(j,settings)
                    local function prefetch(page)
                        -- DialogueUI can call a cached native function, bypassing
                        -- Fieldbook's navigation hook, before any delayed sample.
                        t:Event('ITEM_TEXT_BEGIN');book.page=page;t:Event('ITEM_TEXT_READY')
                    end
                    begin()
                    later(.02,function() prefetch(2) end)
                    later(.04,function() prefetch(3) end)
                    later(.06,function() prefetch(2) end)
                    later(.08,function() prefetch(1) end)
                    step(1);close()
                    local e=assert(writing())
                    assert(#j:List({kind='writing'})==1 and e.identity=='gameobject:900003')
                    assert(e.pages[1].raw=='Opening page' and e.pages[1].personallyViewed)
                    assert(not t:CaptureCurrent())
                    if settings.loreOnlyOpenedPages then
                        assert(pageCount(e)==1 and not j:WritingSummary(e).complete)
                    else
                        assert(pageCount(e)==3 and j:WritingSummary(e).complete)
                        assert(e.pages[2].raw=='Middle page' and not e.pages[2].personallyViewed)
                        assert(e.pages[3].raw=='Final page' and e.pages[3].method=='automatic')
                    end
                    begin();step(1);close()
                    assert(#j:List({kind='writing'})==1 and pageRequests==0)
                ''')

    def test_uncatalogued_native_object_and_item_quest_panels(self):
        for guid, identity in [('GameObject-0-1-2-3-900003-ABC','gameobject:900003'),
                               ('Item-0-12345','item:900003')]:
            lua = item_client()
            lua.execute(f'''
                openerGUID='{guid}';itemID=900003;itemName='New writing'
                function UnitName() return itemName end
                function GetQuestText() return 'Displayed text' end
                t:Event('QUEST_DETAIL');assert(writing().identity=='{identity}')
            ''')

    def test_uncatalogued_nonquest_parchment_without_creator_api(self):
        lua = item_client()
        lua.execute('''
            itemID=900005;itemClass=15;itemName='An unlisted notebook';book.title=itemName
            begin();step(1);assert(writing().identity=='item:900005')
            close();assert(j:Delete(writing().id))
            function ItemTextGetCreator() return 'Player' end
            begin();step(1);assert(not writing());close()
            function ItemTextGetCreator() return secret end
            begin();step(1);assert(not writing());close()
            itemID=8383;function ItemTextGetCreator() return nil end
            begin();step(1);assert(not writing() and t:GetStatus():find('saved mail'))
        ''')

    def test_native_readable_bag_item_in_dialogue(self):
        lua = item_client()
        lua.execute('''
            openerGUID=nil;itemID=900002;itemClass=15;itemName='An uncatalogued book'
            function C_Container.GetContainerItemInfo() return {itemID=itemID,isReadable=true} end
            function UnitName() return itemName end
            function GetQuestText() return 'Displayed writing' end
            t:Event('QUEST_DETAIL');useBag();step(1)
            assert(writing().identity=='item:900002' and writing().pages[1].raw=='Displayed writing')
        ''')

    def test_world_tooltip_dismissed_by_click(self):
        lua = item_client()
        lua.execute('''
            openerGUID=nil;book.title='Archbishop Alonsus Faol';Enum.TooltipDataType={Object=4}
            local cursor
            C_TooltipInfo={GetWorldCursor=function() return cursor end}
            TooltipDataProcessor={AddTooltipPostCall=function(_,fn) hover=fn end}
            t=ns.CreateLoreTracking(j,settings)
            function point()
                cursor={type=4,id=177199,lines={{leftText=book.title}}};hover(GameTooltip);cursor=nil
            end
            point();step(3);begin();step(1);assert(not writing());close()
            point();assert(not writing());begin();step(1);assert(writing().identity=='gameobject:177199')
        ''')

    def test_keyboard_and_title_only_cursor_openers(self):
        for setup in [
            """function UnitGUID(token) if token=='softinteract' then
                return 'GameObject-0-1-2-3-177199-ABC' end end
                function UnitName(token) if token=='softinteract' then return book.title end end""",
            """Enum.TooltipDataType={Object=4};C_TooltipInfo={GetWorldCursor=function()
                return {type=4,lines={{leftText=book.title}}} end}""",
        ]:
            lua = item_client()
            lua.execute(setup + '''
                openerGUID=nil;book.title='Archbishop Alonsus Faol'
                local hints=ns.CreateLoreTooltips(j,settings)
                assert(hints:Status(book.title,177199));begin(0);step(1)
                assert(writing().pages[1].raw==book.pages[1] and not hints:Status(book.title,177199))
            ''')

    def test_item_with_distinct_page_heading_or_uncached_name(self):
        for setup in ["book.title='A different page heading'",
                      "function C_Item.GetItemInfo() return nil end;book.title=nil"]:
            lua = item_client()
            lua.execute(setup + '''
                local hints=ns.CreateLoreTooltips(j,settings)
                assert(hints:Status(itemName,itemID,'item'));begin();step(1)
                assert(writing().identity=='item:3248' and writing().pages[1].raw==book.pages[1])
                assert(not hints:Status('Localized tooltip heading',itemID,'item'))
            ''')

    def test_readable_quest_and_gossip_panels(self):
        for event, accessor in [('QUEST_GREETING','GetGreetingText'), ('QUEST_DETAIL','GetQuestText'),
                                ('QUEST_PROGRESS','GetProgressText'), ('QUEST_COMPLETE','GetRewardText'),
                                ('GOSSIP_SHOW','GetGossipText')]:
            for guid, name, source in [('GameObject-0-1-2-3-177199-ABC','Archbishop Alonsus Faol','gameobject:177199'),
                                       ('Item-0-12345','Translated Letter from The Embalmer','item:3248')]:
                with self.subTest(event=event, guid=guid):
                    lua = item_client()
                    lua.execute(f"""
                        openerGUID='{guid}';function UnitName() return '{name}' end
                        function UnitIsPlayer() return false end
                        C_GossipInfo={{GetText=function() return '' end}}
                        function {accessor}() return panel end
                        function GetTitleText() return 'Quest heading' end
                        t:Event('{event}');panel='Too late';t:Event('{'GOSSIP_CLOSED' if event=='GOSSIP_SHOW' else 'QUEST_FINISHED'}')
                        step(1);assert(not writing())
                        panel=nil;t:Event('{event}');panel='Visible words';step(1)
                        local e=assert(writing());assert(e.title=='{name}' and e.identity=='{source}')
                        assert(e.pages[1].raw==panel and t:CaptureCurrent() and #j:List({{kind='writing'}})==1)
                        local hints=ns.CreateLoreTooltips(j,settings)
                        assert(not hints:Status('{name}',{source.split(':')[1]},'{source.split(':')[0]}'))
                        assert(j:Delete(e.id));openerGUID='Creature-0-1-2-3-177199-ABC'
                        t:Event('{event}');step(1);assert(not writing())
                    """)

    def test_bag_hook_after_quest_dialogue_and_close(self):
        lua = item_client()
        lua.execute('''
            openerGUID=nil;function UnitName() return itemName end
            function GetQuestText() return 'Displayed quest page' end
            t:Event('QUEST_DETAIL');useBag();step(1)
            assert(writing().identity=='item:3248' and writing().pages[1].raw=='Displayed quest page')
            assert(j:Delete(writing().id));t:Event('QUEST_FINISHED')
            t:Event('QUEST_DETAIL');step(1);assert(not writing())
        ''')

    def test_world_reader_uses_object_identity_and_displayed_text(self):
        lua = item_client()
        lua.execute('''
            book.title='Archbishop Alonsus Faol';book.pages={'Displayed inscription'}
            openerGUID='GameObject-0-1-2-3-177199-ABC'
            local hints=ns.CreateLoreTooltips(j,settings)
            assert(hints:Status(book.title,177199))
            begin(0);step(1)
            local e=assert(writing())
            assert(e.identity=='gameobject:177199' and e.title==book.title)
            assert(e.pages[1].raw=='Displayed inscription' and j:WritingSummary(e).complete)
            assert(not hints:Status(book.title,177199))
            close();begin(0);step(1);assert(#j:List({kind='writing'})==1)
            close();openerGUID='GameObject-0-1-2-3-900001-ABC';book.title='Another inscription'
            begin(0);step(1);assert(#j:List({kind='writing'})==2)
        ''')

    def test_cursor_object_requires_matching_read_and_respects_item_and_mail(self):
        lua = item_client()
        lua.execute('''
            Enum.TooltipDataType={Object=4}
            openerGUID=nil;book.title='Archbishop Alonsus Faol'
            local cursor={type=4,id=177199,lines={{leftText=book.title}}}
            C_TooltipInfo={GetWorldCursor=function() return cursor end}
            assert(not writing())
            t:Event('MAIL_SHOW');begin(0);step(1);assert(not writing())
            close();t:Event('MAIL_CLOSED')
            function ItemTextGetCreator() return 'Player' end
            begin(0);step(1);assert(not writing())
            close();ItemTextGetCreator=nil;openerGUID='Item-0-12345'
            begin(0);step(1);assert(not writing())
            close();openerGUID=nil;cursor.lines[1].leftText='Other'
            begin(0);step(1);assert(not writing())
            close();cursor.lines[1].leftText=book.title
            useBag();step(11)
            begin(0);step(1);assert(writing().identity=='gameobject:177199')
        ''')

    def test_quest_letter_with_missing_creator_is_captured_and_survives_reload(self):
        lua = item_client()
        lua.execute('''
            begin();step(1)
            local e=assert(writing());assert(e.subtype=='Quest item' and e.identity=='item:3248')
            assert(e.pages[1].raw=='Synthetic quest letter text' and j:WritingSummary(e).complete)
            local id=e.id;close();j=ns.CreateLoreJournal(saved)
            assert(j:Get(id).subtype=='Quest item' and j:Get(id).identity=='item:3248')
            t=ns.CreateLoreTracking(j,settings);begin();step(1)
            assert(#j:List({kind='writing'})==1)
        ''')

    def test_quest_identity_handles_author_and_failed_creator_without_collecting_mail(self):
        for creator in ["return 'The Embalmer'", "error('unavailable')", 'return secret']:
            lua = item_client()
            lua.execute('function ItemTextGetCreator() ' + creator + ''' end
                begin();step(1);assert(writing())
                close();assert(j:Delete(writing().id))
                t:Event('MAIL_SHOW');begin();step(1);assert(not writing())
                t:Event('MAIL_CLOSED');close()
                MailFrame=CreateFrame('Frame');MailFrame:Show()
                begin();step(1);assert(not writing())
            ''')

    def test_mailbox_state_ends_with_the_world_interaction(self):
        lua = item_client()
        lua.execute('''
            t:Event('MAIL_SHOW');begin();step(1);assert(not writing())
            t:Event('PLAYER_LEAVING_WORLD');begin();step(1)
            assert(writing().identity=='item:3248')
        ''')

    def test_unlisted_quest_readables_qualify_but_player_letters_do_not(self):
        lua = item_client()
        lua.execute('''
            itemID=900001;book.title='Custom quest writing';itemName=book.title
            begin();step(1);assert(writing().identity=='item:900001')
            close();assert(j:Delete(writing().id))
            itemID=8383;itemClass=0;book.title='Translated Letter from The Embalmer';itemName=book.title
            function ItemTextGetCreator() return 'Player' end
            begin();step(1);assert(not writing())
            ItemTextGetCreator=nil;close();begin();step(1);assert(not writing())
            assert(t:CaptureCurrent());step(1);assert(writing().subtype=='')
        ''')

    def test_bag_use_after_synchronous_ready_and_zero_page_are_supported(self):
        lua = item_client()
        lua.execute('''
            openerGUID=nil;open=true;book.page=0
            t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY');useBag();step(1)
            local e=assert(writing());assert(e.identity=='item:3248' and e.pages[1].sourcePage==0)
            assert(e.subtype=='Quest item' and j:WritingSummary(e).complete)
            close();assert(j:Delete(e.id))
            -- No leftover bag identity may authorize a later interaction.
            begin();step(1);assert(not writing())
        ''')

    def test_disabling_section_clears_pending_item_context(self):
        lua = item_client()
        lua.execute('''
            function ns.RegisterSectionVisibilityListener(section,callback)
                assert(section=='lore');visibilityChanged=callback
            end
            t=ns.CreateLoreTracking(j,settings);openerGUID=nil;useBag();visibilityChanged()
            begin();step(1);assert(not writing())
        ''')

    def test_mismatched_expired_and_restricted_sources_cannot_authorize_capture(self):
        for setup in ["openerGUID=nil;itemName='Other item';useBag()", 'itemID=secret',
                      'openerGUID=nil;useBag();step(11)', 'openerGUID=secret',
                      """openerGUID=nil;itemID=900002;useBag()
                         function C_Item.GetItemInfo() error("unavailable") end"""]:
            lua = item_client()
            lua.execute(setup + ';begin();step(1);assert(not writing())')

    def test_item_identity_is_rechecked_during_stabilization(self):
        lua = item_client()
        lua.execute('''
            begin();step(.06);itemID=3249;step(1)
            assert(not writing() and t:GetStatus():find('source changed'))
        ''')
        lua = item_client()
        lua.execute('''
            openerGUID=nil;open=true;book.page=1
            t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY');useBag();step(.06)
            openerGUID='Item-0-12345';itemID=3249;step(1)
            assert(not writing() and t:GetStatus():find('source changed'))
        ''')

    def test_master_switch_and_legacy_bag_api(self):
        lua = item_client()
        lua.execute('''
            openerGUID=nil;UseContainerItem=C_Container.UseContainerItem
            GetContainerItemID=C_Container.GetContainerItemID;GetItemInfo=C_Item.GetItemInfo
            C_Item=nil;C_Container=nil;settings.autoArchiveLore=false
            t=ns.CreateLoreTracking(j,settings);useBag();begin();step(1);assert(not writing())
            assert(t:CaptureCurrent());step(1)
            assert(writing().identity=='item:3248' and writing().subtype=='Quest item')
        ''')

    def test_new_bag_use_cannot_reuse_a_quest_item_identity(self):
        lua = item_client()
        lua.execute('''
            openerGUID=nil;useBag();begin();step(1);assert(writing())
            assert(j:Delete(writing().id))
            -- Another same-titled item can open without a preceding CLOSED.
            t:Event('ITEM_TEXT_BEGIN');t:Event('ITEM_TEXT_READY')
            itemID=8383;itemClass=0;useBag();step(1)
            assert(not writing() and t:GetStatus():find('source changed'))
        ''')

    def test_predefined_nonquest_readable_uses_the_shared_registry(self):
        lua = item_client()
        lua.execute((ROOT / 'LoreTooltips.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute('''
            itemClass=0;begin();step(1)
            assert(writing() and writing().subtype=='' and writing().identity=='item:3248')
        ''')


if __name__ == '__main__':
    unittest.main()
