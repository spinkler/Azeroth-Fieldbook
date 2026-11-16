"""World and readable-item hints reflect missing writings and numbered pages."""
import unittest

from ui_test_harness import new_ui_client


def client(fallback=False):
    lua = new_ui_client(['AtlasJournal.lua', 'LoreJournal.lua', 'LoreReports.lua', 'LoreTooltips.lua'])
    lua.execute(r'''
        locale='enUS';function GetLocale() return locale end
        Enum.TooltipDataType={Object=4,Item=0,Unit=2}
        getter='GetWorldCursor'
        GameTooltip={lines={},colors={}}
        function GameTooltip:GetName() return 'GameTooltip' end
        function GameTooltip:GetPrimaryTooltipInfo() return {getterName=getter} end
        function GameTooltip:GetTooltipData() return cursor end
        function GameTooltip:NumLines() return #self.lines end
        function GameTooltip:AddLine(text,r,g,b)
            self.lines[#self.lines+1]=text;self.colors[#self.colors+1]={r,g,b}
            _G['GameTooltipTextLeft'..#self.lines]={GetText=function() return text end}
        end
        function GameTooltip:SetWorldCursor() end
        C_TooltipInfo={GetWorldCursor=function() return cursor end}
        posts={}
        TooltipDataProcessor={AddTooltipPostCall=function(kind,fn)
            assert(kind==4 or kind==0);posts[kind]=fn;if kind==4 then post=fn else itemPost=fn end
        end}
        function hooksecurefunc(owner,key,fn)
            assert(owner==GameTooltip and key=='SetWorldCursor');hook=fn
        end
        function hover(name,id,kind)
            GameTooltip.lines={};GameTooltip.colors={};GameTooltip:AddLine(name,1,1,1)
            cursor={type=kind or 4,id=id,lines={{leftText=name}}}
            if post then (posts[cursor.type] or post)(GameTooltip,cursor) else t:Append(GameTooltip,cursor) end
            local line=GameTooltip.lines[2];return line and plain(line)
        end
        saved={};settings={};j=ns.CreateLoreJournal(saved)
        function capture(title,identity,language,partial)
            local e=assert(j:CapturePage({sessionID='session',title=title,identity=identity,
                locale=language or locale,sourceKind='readable'},
                {number=1,raw='Synthetic source text',first=true,last=not partial}))
            j:EndCapture('session');return e
        end
    ''')
    if fallback:
        lua.execute('TooltipDataProcessor=nil')
    lua.execute('t=ns.CreateLoreTooltips(j,settings)')
    return lua


class LoreTooltipTests(unittest.TestCase):
    def test_unstored_capture_rename_delete_and_reload(self):
        lua = client()
        lua.execute(r'''
            local title='The Guardians of Tirisfal'
            local revision,serial=j.revision,j.db.serial
            assert(hover(title,175735)=='[AFB] Chronicle: Unread')
            assert(GameTooltip.lines[2]=='|cff80d0ff[AFB] Chronicle:|r Unread')
            eq(GameTooltip.colors[2][1],1);eq(GameTooltip.colors[2][2],0.82);eq(GameTooltip.colors[2][3],0.14)
            assert(next(j.entries)==nil and j.revision==revision and j.db.serial==serial)
            local e=capture(title)
            assert(hover(title,175735)==nil and #GameTooltip.lines==1)
            assert(j:Update(e.id,{title='My renamed writing'}))
            assert(hover(title,175735)==nil)
            j=ns.CreateLoreJournal(saved);t=ns.CreateLoreTooltips(j)
            assert(hover(title,175735)==nil)
            assert(j:Delete(e.id))
            assert(hover(title,175735)=='[AFB] Chronicle: Unread')
        ''')

    def test_world_object_boundaries_and_duplicate_callbacks(self):
        lua = client()
        lua.execute(r'''
            assert(hover('Silverleaf',1617)==nil)
            assert(hover('Solid Chest',2850)==nil)
            assert(hover('Ordinary NPC',42,2)==nil)
            assert(hover('The Guardians of Tirisfal',175735,0)==nil)
            getter='GetItemByID'
            assert(hover('The Guardians of Tirisfal',175735)==nil)
            getter='GetWorldCursor'
            assert(hover('The Guardians of Tirisfal',175735))
            post(GameTooltip,cursor);post(GameTooltip,cursor)
            assert(#GameTooltip.lines==2)
            local other={};post(other,cursor);assert(#GameTooltip.lines==2)
            assert(hover('Draconic for Dummies',180665)=='[AFB] Chronicle: Unread')
        ''')

    def test_guid_localized_titles_and_known_custom_sources(self):
        lua = client()
        lua.execute(r'''
            locale='deDE'
            local e=capture('Die Wächter von Tirisfal')
            assert(hover('Die Wächter von Tirisfal',175735)==nil)
            assert(hover('Lokalisierter Buchtitel',175738)=='[AFB] Chronicle: Unread')
            locale='enUS'
            assert(hover('The Guardians of Tirisfal',175735)=='[AFB] Chronicle: Unread')
            local custom=capture('A custom world inscription','gameobject:9999')
            assert(hover('A custom world inscription',9999)==nil)
            assert(hover('A custom world inscription',9998)=='[AFB] Chronicle: Unread')
            hover('Unrelated localized name',nil)
            cursor.guid='GameObject-0-1-2-3-175735-ABC'
            post(GameTooltip,cursor)
            assert(plain(GameTooltip.lines[2])=='[AFB] Chronicle: Unread')
            -- The English title fallback supports clients without object IDs.
            assert(hover('The Guardians of Tirisfal',nil)=='[AFB] Chronicle: Unread')
        ''')

    def test_empty_entries_do_not_count_as_stored_but_source_text_does(self):
        lua = client()
        lua.execute(r'''
            local e=assert(j:Create('writing',{title='The Guardians of Tirisfal',notes='Personal notes'}))
            assert(hover(e.title,175735)=='[AFB] Chronicle: Unread')
            assert(j:AddPassage(e.id,{raw='Manually preserved source',nature='source',method='transcribed'}))
            assert(hover(e.title,175735)==nil)
            local partial=capture('Aegwynn and the Dragon Hunt',nil,nil,true)
            assert(not j:WritingSummary(partial).complete)
            assert(hover(partial.sourceTitle,175738)==nil)
        ''')

    def test_reported_source_is_stored_under_its_own_title(self):
        lua = client()
        lua.execute(r'''
            local e=capture('The Guardians of Tirisfal')
            local report=assert(ns.LoreReports.Build(j,e.id))
            local target=ns.CreateLoreJournal({})
            local host=assert(target:Create('writing',{title='Aegwynn and the Dragon Hunt'}))
            local staged=assert(ns.LoreReports.Prepare(report))
            assert(ns.LoreReports.Accept(target,staged,host.id))
            t=ns.CreateLoreTooltips(target)
            assert(hover('The Guardians of Tirisfal',175735)==nil)
            assert(hover('Aegwynn and the Dragon Hunt',175738)=='[AFB] Chronicle: Unread')
        ''')

    def test_restricted_missing_disabled_and_readonly_data(self):
        lua = client()
        lua.execute(r'''
            local function rejected(change)
                hover('The Guardians of Tirisfal',175735)
                GameTooltip.lines={'The Guardians of Tirisfal'}
                change();post(GameTooltip,cursor);assert(#GameTooltip.lines==1)
            end
            rejected(function() cursor=secret end)
            rejected(function() cursor.type=secret end)
            rejected(function() cursor.lines=secret end)
            rejected(function() cursor.lines[1]=secret end)
            rejected(function() cursor.lines[1].leftText=secret end)
            rejected(function() getter=secret end);getter='GetWorldCursor'
            rejected(function() cursor=nil end)
            rejected(function() ns.InitializationBlocked=true end);ns.InitializationBlocked=nil
            rejected(function() settings.showTooltips=false end);settings.showTooltips=true
            assert(hover('The Guardians of Tirisfal',175735)=='[AFB] Chronicle: Unread')
            rejected(function() ns.IsFieldbookSectionEnabled=function() return false end end)
            ns.IsFieldbookSectionEnabled=nil
            rejected(function() j.readOnly=true end);j.readOnly=nil
            rejected(function() j.invalid=1 end);j.invalid=0
            hover('The Guardians of Tirisfal',nil)
            GameTooltip.lines={'The Guardians of Tirisfal'}
            cursor.guid=secret;cursor.id=secret;post(GameTooltip,cursor)
            assert(plain(GameTooltip.lines[2])=='[AFB] Chronicle: Unread')
            C_TooltipInfo=nil;GameTooltip.lines={};post(GameTooltip,cursor)
            assert(#GameTooltip.lines==0)
        ''')

    def test_fallback_hook_and_active_archive_isolation(self):
        lua = client(fallback=True)
        lua.execute(r'''
            assert(hook and not post)
            capture('The Guardians of Tirisfal')
            local personal=ns.CreateLoreJournal({})
            t=ns.CreateLoreTooltips(personal)
            assert(hover('The Guardians of Tirisfal',175735)=='[AFB] Chronicle: Unread')
            t=ns.CreateLoreTooltips(j)
            assert(hover('The Guardians of Tirisfal',175735)==nil)
            hook();assert(#GameTooltip.lines==1)
            GameTooltip=nil;TooltipDataProcessor=nil;hooksecurefunc=nil
            assert(ns.CreateLoreTooltips(j),'Missing client hooks are optional')
        ''')

    def test_missing_numbered_pages_before_and_after_capture(self):
        lua = client()
        lua.execute(r'''
            local title='The Guardians of Tirisfal'
            local function page(n,last)
                return assert(j:CapturePage({sessionID='pages',title=title,locale='enUS'},
                    {number=n,raw='Text '..n,first=n==1,last=last==true}))
            end
            page(2);page(4);local e=page(6,true)
            local before=j.revision
            assert(hover(title,175735)=='[AFB] Chronicle: Missing pages (1, 3, 5)')
            assert(GameTooltip.lines[2]=='|cff80d0ff[AFB] Chronicle:|r Missing pages (1, 3, 5)')
            post(GameTooltip,cursor);assert(#GameTooltip.lines==2 and j.revision==before)
            page(1);page(3)
            assert(hover(title,175735)=='[AFB] Chronicle: Missing pages (5)')
            page(5);assert(j:WritingSummary(e).complete and hover(title,175735)==nil)
        ''')

    def test_unknown_final_page_does_not_invent_trailing_pages(self):
        lua = client()
        lua.execute(r'''
            local title='The Guardians of Tirisfal'
            capture(title,nil,nil,true)
            assert(hover(title,175735)==nil,'Unknown later pages cannot be enumerated')
            assert(j:CapturePage({sessionID='gap',title=title,locale='enUS'},
                {number=3,raw='Third page'}))
            assert(hover(title,175735)=='[AFB] Chronicle: Missing pages (2)')
        ''')

    def test_readable_items_use_ids_and_source_titles_on_bag_and_link_tooltips(self):
        lua = client()
        lua.execute(r'''
            getter='GetBagItem'
            assert(hover('A Dusty Unsent Letter',889,0)=='[AFB] Chronicle: Unread')
            capture('A Dusty Unsent Letter')
            assert(hover('Localized item name',889,0)==nil,'Known item ID can match the original source title')
            getter='GetHyperlink'
            assert(hover('An Undelivered Letter',910,0)=='[AFB] Chronicle: Unread')
            ItemRefTooltip=setmetatable({lines={},colors={}}, {__index=GameTooltip})
            function ItemRefTooltip:GetName() return 'ItemRefTooltip' end
            function ItemRefTooltip:AddLine(text,r,g,b)
                self.lines[#self.lines+1]=text
                _G['ItemRefTooltipTextLeft'..#self.lines]={GetText=function() return text end}
            end
            itemPost(ItemRefTooltip,cursor)
            assert(plain(ItemRefTooltip.lines[1])=='[AFB] Chronicle: Unread')
            itemPost(ItemRefTooltip,cursor);assert(#ItemRefTooltip.lines==1)
        ''')

    def test_item_eligibility_excludes_ordinary_items_player_letters_and_restricted_ids(self):
        lua = client()
        lua.execute(r'''
            getter='GetBagItem'
            assert(hover('The Guardians of Tirisfal',175735,0)==nil,'Object IDs are not item IDs')
            assert(hover('A Dusty Unsent Letter',42,0)==nil,'Title alone does not qualify an item')
            assert(hover('Plain Letter',8383,0)==nil)
            assert(hover('An Undelivered Letter',secret,0)==nil)
            assert(hover('An Undelivered Letter',nil,0)==nil)
            hover('An Undelivered Letter',910,0);GameTooltip.lines={}
            itemPost(GameTooltip,secret);assert(#GameTooltip.lines==0)
            settings.showTooltips=false
            assert(hover('An Undelivered Letter',910,0)==nil)
        ''')

    def test_item_missing_pages_and_received_pages(self):
        lua = client()
        lua.execute(r'''
            local title='A Dusty Unsent Letter'
            assert(j:CapturePage({sessionID='letter',title=title,locale='enUS'},
                {number=1,raw='Beginning',first=true}))
            assert(j:CapturePage({sessionID='letter',title=title,locale='enUS'},
                {number=3,raw='Ending',last=true}))
            getter='GetBagItem'
            assert(hover(title,889,0)=='[AFB] Chronicle: Missing pages (2)')
            local report=assert(ns.LoreReports.Build(j,j:List({kind='writing'})[1].id))
            local other=ns.CreateLoreJournal({})
            assert(ns.LoreReports.Accept(other,assert(ns.LoreReports.Prepare(report))))
            t=ns.CreateLoreTooltips(other)
            assert(hover(title,889,0)=='[AFB] Chronicle: Missing pages (2)')
        ''')


if __name__ == '__main__':
    unittest.main()
