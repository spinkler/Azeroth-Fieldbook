"""Visibility, empty-book recovery and real observer pause/resume boundaries."""
import unittest
from unittest.mock import patch

from ui_test_harness import ROOT, new_ui_client
import test_fieldbook_tabs as tabs
import test_gathering as gathering
import angling_test_harness as angling
import ledger_test_harness as ledger
import treasure_test_harness as treasure
import annals_test_harness as annals
import test_lore_tracking as lore
import atlas_test_harness as atlas
from test_atlas_entrances import ENV as ENTRANCE_ENV
from kill_test_harness import new_client
from test_player_names_preservation import full_client


IDS = ['bestiary', 'gathering', 'atlas', 'annals', 'merchants', 'treasure', 'angling', 'lore']


def visibility_client(module, factory):
    with patch.object(module, 'new_ui_client',
                      lambda modules: new_ui_client(['SectionVisibility.lua', *modules])):
        lua = factory()
    lua.execute('AzerothFieldbookDB=AzerothFieldbookDB or {}')
    return lua


def book_client():
    fixture = tabs.FieldbookTabsTests()
    lua = visibility_client(tabs, lambda: (fixture.setUp(), fixture.lua)[1])
    for name in ['AnnalsJournal.lua', 'AnnalsTrail.lua', 'AnnalsTracking.lua',
                 'AnnalsMap.lua', 'AnnalsBook.lua', 'AnnalsIntegration.lua']:
        lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute('''
        AzerothFieldbookDB=settings
        ns.InitializeAnnals(shell,{bestiary=journal,gathering=gathering,atlas=atlas,
            angling=angling,merchants=ledger,treasure=treasure,lore=lore})
    ''')
    return lua


class SectionVisibilityTests(unittest.TestCase):
    def test_single_journal_uses_its_portrait_without_a_tab_or_outside_space(self):
        lua = book_client()
        lua.execute('''
            shell:Toggle()
            local root=shell:GetFrame();local icon=root.titleIcon.icon
            local bookIcon=icon:GetTexture()
            for _,id in ipairs(shell.order) do shell:SetSectionEnabled(id,false) end
            assert(icon:GetTexture()==bookIcon)
            for _,id in ipairs(shell.order) do
                shell:SetSectionEnabled(id,true)
                assert(shell.active==id and shell:IsSectionShown(id))
                assert(#shell:GetVisibleSections()==1 and not root.navigation:IsShown())
                assert(not shell.sections[id].tab:IsShown())
                assert(root.afbOutsideRight==0 and root.navigation:GetWidth()==0)
                assert(root.clampInsets[2]==0)
                assert(root.titleIcon.icon==icon and icon:GetTexture()==shell.sections[id].definition.icon)
                assert(root.optionsButton:IsShown() and root.closeButton:IsShown())
                shell:Hide();shell:Toggle()
                assert(shell.active==id and not root.navigation:IsShown())
                assert(icon:GetTexture()==shell.sections[id].definition.icon)
                shell:SetSectionEnabled(id,false)
                assert(shell.active==nil and icon:GetTexture()==bookIcon)
            end
            shell:SetSectionEnabled('atlas',true)
            shell:SetSectionEnabled('lore',true)
            assert(root.navigation:IsShown() and root.afbOutsideRight>0)
            assert(icon:GetTexture()==bookIcon)
            for _,tab in ipairs(root.sectionTabs) do assert(tab:IsShown()) end
            shell:SetSectionEnabled('atlas',false)
            assert(shell.active=='lore' and not root.navigation:IsShown())
            assert(icon:GetTexture()==shell.sections.lore.definition.icon)
        ''')

    def test_hiding_bestiary_blocks_new_offers_and_preserves_accepted_transfers(self):
        lua = new_ui_client(['SectionVisibility.lua','SharingReport.lua','BestiaryJournal.lua','Sharing.lua'])
        lua.execute('''
            AzerothFieldbookDB={}
            local journal=ns.CreateBestiaryJournal(AzerothFieldbookDB,function() return nil end)
            local engine=ns.CreateSharing(journal,{ready=true,character='Alice Sunstrider',addonVersion=buildVersion,
                now=function() return now end,blocked=function() return false end,send=function() return true end})
            local incoming=journal:GetSharingStorage().incoming
            local function hello(id)
                engine:Receive('AFBShare','4~H~'..id..'~'..buildVersion,'WHISPER','Bob Stonewell')
            end
            hello('1000000-1-1');assert(next(incoming))
            local accepted={state='accepted',id='1000000-1-2',sender='Carol Riverwind',expires=now+86400}
            incoming.accepted=accepted
            ns.SetFieldbookSectionEnabled('bestiary',false)
            assert(incoming.accepted==accepted)
            for _,item in pairs(incoming) do assert(item==accepted) end
            now=now+20;hello('1000000-1-3')
            for _,item in pairs(incoming) do assert(item==accepted) end
            assert(not journal:GetBlockIncomingOffers(),'Hiding a tab preserves the independent offer preference')
            ns.SetFieldbookSectionEnabled('bestiary',true)
            now=now+20;hello('1000000-1-4')
            local count=0;for _ in pairs(incoming) do count=count+1 end
            assert(count==2)
        ''')

    def test_full_startup_with_every_tab_hidden_keeps_options_and_pauses_id_windows(self):
        hidden=','.join(id+'=false' for id in IDS)
        lua = full_client('{version=1,sectionVisibility={' + hidden + '}}', initialize=False)
        lua.execute('''
            castReads=0
            function UnitExists() return true end
            function UnitIsEnemy() return true end
            function UnitPlayerControlled() return false end
            function UnitCastingInfo() castReads=castReads+1 end
            mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
            assert(castReads==0,'Hidden journals must not query live casts during startup')
            local _,book=debug.getupvalue(AzerothFieldbookNextEntry,1)
            local shell=book:GetShell()
            AzerothFieldbookToggleBestiary()
            local root=shell:GetFrame()
            assert(root:IsShown() and shell.active==nil and #root.sectionTabs==0)
            assert(not AzerothFieldbookSpellIDWindow:IsShown())
            root.optionsButton.scripts.OnClick();assert(AzerothFieldbookOptions:IsShown())
            shell:SetSectionEnabled('bestiary',true)
            assert(shell.active=='bestiary' and AzerothFieldbookSpellIDWindow:IsShown())
            shell:SetSectionEnabled('bestiary',false)
            assert(shell.active==nil and not AzerothFieldbookSpellIDWindow:IsShown())
            assert(not book:OpenAtUnit('mouseover'))
            local annals=ns.AnnalsController.journal
            local before=#annals.db.events
            ns.RecordFieldbookDiscovery('bestiary',{id=42})
            assert(#annals.db.events==before)
            shell:SetSectionEnabled('annals',true)
            ns.RecordFieldbookDiscovery('bestiary',{id=42})
            assert(#annals.db.events>before)
        ''')

    def test_all_eight_default_on_and_checkboxes_recover_an_empty_book(self):
        lua = book_client()
        lua.execute('''
            assert(#shell.order==8 and not settings.sectionVisibility)
            shell:Toggle();shell:TogglePage('options')
            local root=shell:GetFrame();local options=shell.sections.bestiary.pages.options
            options.tabs.Journals.scripts.OnClick()
            local count=0
            for _,id in ipairs(shell.order) do
                local toggle=assert(options.sectionVisibility[id]);count=count+1
                assert(toggle:GetChecked() and toggle:IsShown())
                toggle:SetChecked(false);toggle.scripts.OnClick(toggle)
                assert(not shell:IsSectionEnabled(id) and not shell:ShowSection(id))
            end
            assert(count==8 and #root.sectionTabs==0 and not root.navigation:IsShown())
            assert(root:IsShown() and shell.active==nil and root.afbOutsideRight==0)
            assert(root.optionsButton:IsShown() and root.closeButton:IsShown())
            assert(not root.helpButton:IsShown() and not root.eventLogButton:IsShown())
            for _,section in pairs(shell.sections) do assert(not section.frame or not section.frame:IsShown()) end
            assert(options:IsShown(),'The controls stay available while hiding the active tab')
            root.optionsButton.scripts.OnClick();assert(not options:IsShown())
            root.closeButton.scripts.OnClick();shell:Toggle()
            assert(root:IsShown() and #root.sectionTabs==0 and shell.active==nil)
            root.optionsButton.scripts.OnClick();assert(options:IsShown())
            assert(not shell:CycleSection(1))
            local toggle=options.sectionVisibility.annals
            toggle:SetChecked(true);toggle.scripts.OnClick(toggle)
            assert(shell.active=='annals' and #root.sectionTabs==1 and options:IsShown())
            assert(not root.navigation:IsShown() and root.afbOutsideRight==0)
            for _,id in ipairs(shell.order) do shell:SetSectionEnabled(id,true) end
            assert(#root.sectionTabs==8)
            for index,id in ipairs(shell.order) do
                assert(root.sectionTabs[index]==shell.sections[id].tab)
            end
        ''')

    def test_saved_choices_blank_start_navigation_and_bestiary_reset(self):
        lua = book_client()
        lua.execute('''
            settings.sectionVisibility={}
            for _,id in ipairs(shell.order) do settings.sectionVisibility[id]=false end
            shell:Toggle();assert(shell.active==nil and #shell:GetFrame().sectionTabs==0)
            shell:TogglePage('options')
            assert(shell.sections.bestiary.pages.options:IsShown())
            shell:SetSectionEnabled('atlas',true);shell:SetSectionEnabled('lore',true)
            assert(shell.active=='atlas')
            shell:CycleSection(1);assert(shell.active=='lore')
            shell:CycleSection(1);assert(shell.active=='atlas')
            shell:CycleSection(-1);assert(shell.active=='lore')
            journal:ResetDatabase()
            assert(not shell:IsSectionEnabled('bestiary') and shell:IsSectionEnabled('lore'))
            shell:SetSectionEnabled('lore',false)
            assert(shell.active=='atlas')
            shell:SetSectionEnabled('atlas',false);assert(shell.active==nil)
        ''')

    def test_main_bestiary_dispatch_pauses_and_resumes_kills(self):
        lua = new_client(initialize=False)
        lua.execute((ROOT / 'SectionVisibility.lua').read_text(encoding='utf-8'),
                    'AzerothFieldbook', lua.globals().ns)
        lua.execute('''
            fire('ADDON_LOADED','AzerothFieldbook')
            beginKill('first');finishKill();local before=kills();local earned=points()
            ns.SetFieldbookSectionEnabled('bestiary',false)
            beginKill('hidden');finishKill();tick()
            assert(kills()==before and points()==earned)
            ns.SetFieldbookSectionEnabled('bestiary',true)
            beginKill('resumed');finishKill();assert(kills()==before+1)
        ''')

    def test_gathering_drops_inflight_cast_and_ignores_hidden_hover(self):
        lua = visibility_client(gathering, gathering.client)
        lua.execute('''
            hover('Silverleaf');sent('Silverleaf','before');start('before')
            local before=entry().interactions
            ns.SetFieldbookSectionEnabled('gathering',false)
            hover('Peacebloom');gather('Peacebloom','hidden')
            assert(not entry('herb:peacebloom'))
            ns.SetFieldbookSectionEnabled('gathering',true)
            finish('before');assert(entry().interactions==before)
            hover('Silverleaf');gather('Silverleaf','fresh');assert(entry().interactions==before+1)
        ''')

    def test_angling_pool_discovery_pauses_independently(self):
        lua = visibility_client(angling, angling.new_angling)
        lua.execute('''
            ns.SetFieldbookSectionEnabled('angling',false)
            hoverPool('Oily Blackmouth School','Requires Fishing')
            assert(next(saved.pools)==nil)
            ns.SetFieldbookSectionEnabled('angling',true)
            hoverPool('Oily Blackmouth School','Requires Fishing')
            assert(next(saved.pools)~=nil and ns.IsFieldbookSectionEnabled('gathering'))
        ''')

    def test_atlas_survey_and_entrances_start_fresh_after_a_pause(self):
        lua = visibility_client(atlas, atlas.new_atlas)
        lua.execute(ENTRANCE_ENV)
        lua.execute('''
            local survey=j.subzones
            survey:Observe();local before=snapshot(survey.store)
            local observer=ns.AtlasEntranceTracking.Track(j)
            j.state.autoEntrances=true
            observer:SetEnabled(true)
            inside=true;mapID=201
            observer.scripts.OnEvent(observer,'ZONE_CHANGED_INDOORS')
            ns.SetFieldbookSectionEnabled('atlas',false)
            C_Weather={GetCurrentWeather=function() return {type=1} end}
            local weather=snapshot(saved.weather)
            j:ObserveWeather();assert(snapshot(saved.weather)==weather)
            area='Hidden cave';px=.26
            survey:Observe();c.subzoneObserver.scripts.OnUpdate(c.subzoneObserver,1)
            observer.scripts.OnEvent(observer,'ZONE_CHANGED_INDOORS');advance(5);settle()
            assert(snapshot(survey.store)==before and next(j.entrances.records)==nil)
            ns.SetFieldbookSectionEnabled('atlas',true);advance(3)
            j:ObserveWeather();assert(snapshot(saved.weather)~=weather)
            assert(next(j.entrances.records)==nil,'Resuming inside is a baseline, never an entrance')
            inside=false;mapID=101;px=.27
            observer.scripts.OnEvent(observer,'ZONE_CHANGED_INDOORS');advance(.4)
            inside=true;mapID=201;px=.272
            observer.scripts.OnEvent(observer,'ZONE_CHANGED_INDOORS');advance(.4)
            assert(next(j.entrances.records)~=nil)
        ''')

    def test_ledger_cancels_pending_visit_and_excludes_paused_income(self):
        lua = visibility_client(ledger, ledger.new_ledger)
        lua.execute('''
            AzerothFieldbookLedgerDB=saved
            balance=100;function GetMoney() return balance end
            t:Money(true);local e=visit();local visits=e.visits
            ns.SetFieldbookSectionEnabled('merchants',false)
            balance=500;t:Money();fire('MERCHANT_SHOW');flush()
            assert(e.visits==visits and #saved.cashFlow.entries==0)
            ns.SetFieldbookSectionEnabled('merchants',true);flush();t:Money()
            assert(#saved.cashFlow.entries==0,'Hidden income must not appear on resume')
            balance=510;t:Money();assert(saved.cashFlow.income==10)
            visit();assert(t.visits.merchant)
        ''')

    def test_treasure_discards_cast_and_delayed_bag_work(self):
        lua = visibility_client(treasure, treasure.new_treasure)
        lua.execute('''
            fire('UNIT_SPELLCAST_SENT','player','Battered Chest','old',3365)
            fire('BAG_UPDATE_DELAYED')
            ns.SetFieldbookSectionEnabled('treasure',false)
            bags[0]={bagitem(1234,'Item-1')};flush()
            assert(next(j.kinds)==nil)
            ns.SetFieldbookSectionEnabled('treasure',true)
            fire('UNIT_SPELLCAST_SUCCEEDED','player','old',3365)
            assert(not t.interaction and not t.bagQueued)
            fire('BAG_UPDATE_DELAYED');flush();assert(next(j.kinds)~=nil)
        ''')

    def test_lore_cancels_traversal_even_after_a_quick_reenable(self):
        lua = visibility_client(lore, lambda: lore.client('{loreOnlyOpenedPages=false}'))
        lua.execute('''
            begin();step(0.2);local e=writing();assert(e)
            local pages=pageCount(e)
            ns.SetFieldbookSectionEnabled('lore',false)
            ns.SetFieldbookSectionEnabled('lore',true)
            step(5);assert(pageCount(e)==pages and not t.active)
            close();begin();step(5);assert(pageCount(writing())==3)
        ''')

    def test_annals_pauses_events_and_breaks_the_journey(self):
        lua = visibility_client(annals, annals.client)
        lua.execute('''
            t:Event('PLAYER_LEVEL_UP',24);point(1000,1000,now)
            local count=#db.events;local segments=#db.segments;local n=points()
            local previous=db.segments[segments];local data=previous.data
            ns.SetFieldbookSectionEnabled('annals',false)
            t:Event('PLAYER_LEVEL_UP',25);t:Poll();point(1100,1100,now+1)
            assert(#db.events==count and points()==n)
            ns.SetFieldbookSectionEnabled('annals',true)
            t:Event('PLAYER_LEVEL_UP',26);point(1200,1200,now+2)
            assert(#db.events==count+1,'events '..#db.events..' expected '..count+1)
            assert(#db.segments>segments and previous.data==data,'Resume must start a separate journey segment')
        ''')


if __name__ == '__main__':
    unittest.main()
