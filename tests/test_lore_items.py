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
        for setup in ["itemName='Other item'", 'itemID=secret',
                      'openerGUID=nil;useBag();step(11)', 'openerGUID=secret',
                      'function C_Item.GetItemInfo() error("unavailable") end']:
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
