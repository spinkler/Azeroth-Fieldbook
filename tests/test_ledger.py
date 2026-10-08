"""Ledger data, guarded capture, report boundary and real widget-builder checks."""
import unittest
from ledger_test_harness import new_ledger
from ui_test_harness import ROOT


class LedgerTests(unittest.TestCase):
    def test_pickpocket_cash_uses_confirmed_capture_and_separate_runs(self):
        lua=new_ledger()
        lua.execute((ROOT/'BestiaryLoot.lua').read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
        lua.execute(r"""
            AzerothFieldbookLedgerDB={};balance=1000
            function GetMoney() return balance end
            function GetTime() return now end
            GOLD_AMOUNT='%d Gold';SILVER_AMOUNT='%d Silver';COPPER_AMOUNT='%d Copper'
            fire('PLAYER_ENTERING_WORLD')
            local guid='Creature-0-1-2-3-42-ABC'
            local dead=false
            function UnitGUID(unit) if unit=='target' then return guid end end
            function UnitName() return 'Gnarlpine Ursa' end
            function UnitIsDead() return dead end
            function GetNumLootItems() return 1 end
            function GetLootSourceInfo() return guid,0 end
            function GetLootSlotLink() return nil end -- Coins only: no item row.
            local best={entries={[42]={name='Gnarlpine Ursa',personalEncountered=true}},Touch=function() end}
            local observer=ns.StartBestiaryLoot(best)
            local function event(event,...) observer.scripts.OnEvent(observer,event,...) end
            local function pick(cast)
                event('UNIT_SPELLCAST_SENT','player','Gnarlpine Ursa',cast,921)
                event('UNIT_SPELLCAST_SUCCEEDED','player',cast,921)
                event('LOOT_READY');event('LOOT_OPENED')
            end
            pick('Cast-1')
            event('LOOT_CLOSED') -- Native money notification may trail close.
            balance=balance+7;fire('PLAYER_MONEY');fire('CHAT_MSG_MONEY','You loot 7 Copper.')
            local cash=AzerothFieldbookLedgerDB.cashFlow
            assert(cash.entries[1].context=='Pickpocketed cash')
            assert(cash.entries[1].counterparty=='Gnarlpine Ursa' and cash.income==7)
            assert(next(best.entries[42].pickpocketLoot.items)==nil,'No coins in item table')
            pick('Cast-2')
            fire('CHAT_MSG_MONEY','You loot 3 Copper.');balance=balance+3;fire('PLAYER_MONEY')
            assert(#cash.entries==1 and cash.entries[1].amount==10 and cash.entries[1].lootCount==2)
            event('LOOT_CLOSED');dead=true;event('LOOT_READY')
            balance=balance+5;fire('CHAT_MSG_MONEY','You loot 5 Copper.')
            assert(#cash.entries==2 and cash.entries[1].context=='Looted cash')
            event('LOOT_CLOSED');dead=false;pick('Cast-3');event('LOOT_CLOSED');now=now+2
            balance=balance+2;fire('CHAT_MSG_MONEY','You loot 2 Copper.')
            assert(cash.entries[1].context=='Looted cash','Expired capture cannot classify later cash')
            assert(cash.income==17)
            shell:ShowSection('merchants');c:CashFlow()
            c.panels.cashFlow.search:SetText('pickpocket');c:RefreshCashFlow()
            local text=c.panels.cashFlow.read.transactionRows[1].text:GetText()
            assert(text:find('Pickpocketed cash',1,true) and text:find('Gnarlpine Ursa',1,true))
        """)

    def test_pickpocket_cash_missing_coin_guid_and_early_money_events(self):
        for early, mismatch, failed in [(False,False,False),(True,False,False),(True,True,False),(True,False,True)]:
            with self.subTest(early=early,mismatch=mismatch,failed=failed):
                lua=new_ledger()
                lua.execute((ROOT/'BestiaryLoot.lua').read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
                lua.globals().early=early;lua.globals().mismatch=mismatch;lua.globals().failed=failed
                lua.execute(r"""
                    AzerothFieldbookLedgerDB={};balance=1000
                    function GetMoney() return balance end
                    function GetTime() return now end
                    GOLD_AMOUNT='%d Gold';SILVER_AMOUNT='%d Silver';COPPER_AMOUNT='%d Copper'
                    fire('PLAYER_ENTERING_WORLD')
                    local guid='Creature-0-1-2-3-42-ABC'
                    function UnitGUID(unit) if unit=='target' then return guid end end
                    function UnitName() return 'Gnarlpine Ursa' end
                    function UnitIsDead() return false end
                    function GetNumLootItems() return 1 end
                    function GetLootSourceInfo() if mismatch then return 'Creature-0-1-2-3-43-DEF',0 end end
                    function GetLootSlotType() return 2 end
                    function GetLootSlotLink() return nil end
                    local best={entries={[42]={name='Gnarlpine Ursa',personalEncountered=true}},Touch=function() end}
                    local observer=ns.StartBestiaryLoot(best)
                    local function event(event,...) observer.scripts.OnEvent(observer,event,...) end
                    event('UNIT_SPELLCAST_SENT','player','Gnarlpine Ursa','Cast-1',921)
                    local function money()
                        balance=balance+7;fire('PLAYER_MONEY');fire('CHAT_MSG_MONEY','You loot 7 Copper.')
                    end
                    if early then money() end
                    event('LOOT_READY')
                    event(failed and 'UNIT_SPELLCAST_FAILED' or 'UNIT_SPELLCAST_SUCCEEDED','player','Cast-1',921)
                    event('LOOT_OPENED');event('LOOT_CLOSED')
                    if not early then money() end
                    flush()
                    local cash=AzerothFieldbookLedgerDB.cashFlow
                    assert(cash.income==7 and #cash.entries==1 and cash.entries[1].amount==7)
                    assert(cash.entries[1].context==((mismatch or failed) and 'Looted cash' or 'Pickpocketed cash'))
                    if not mismatch and not failed then assert(cash.entries[1].counterparty=='Gnarlpine Ursa') end
                    -- Consuming the evidence cannot label a subsequent money message.
                    balance=balance+3;fire('CHAT_MSG_MONEY','You loot 3 Copper.');flush()
                    assert(cash.entries[1].context=='Looted cash' and cash.income==10)
                """)

    def test_pickpocket_cash_without_any_readable_loot_slots(self):
        for ordering in ['no_window','empty_window','early_money','failed','corpse','expired','native_delayed_chat']:
            with self.subTest(ordering=ordering):
                lua=new_ledger()
                lua.execute((ROOT/'BestiaryLoot.lua').read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
                lua.globals().ordering=ordering
                lua.execute(r"""
                    AzerothFieldbookLedgerDB={};balance=1000
                    function GetMoney() return balance end
                    function GetTime() return now end
                    GOLD_AMOUNT='%d Gold';SILVER_AMOUNT='%d Silver';COPPER_AMOUNT='%d Copper'
                    fire('PLAYER_ENTERING_WORLD')
                    local guid='Creature-0-1-2-3-42-ABC'
                    local dead=false
                    function UnitGUID(unit) if unit=='target' then return guid end end
                    function UnitName() return 'Gnarlpine Ursa' end
                    function UnitIsDead() return dead end
                    function GetNumLootItems() return 0 end
                    GetLootSourceInfo=nil;GetLootSlotType=nil;GetLootSlotLink=nil
                    local best={entries={[42]={name='Gnarlpine Ursa',personalEncountered=true}},Touch=function() end}
                    local observer=ns.StartBestiaryLoot(best)
                    local function event(event,...) observer.scripts.OnEvent(observer,event,...) end
                    local function money()
                        balance=balance+2;fire('PLAYER_MONEY');fire('CHAT_MSG_MONEY','You loot 2 Copper.')
                    end
                    event('UNIT_SPELLCAST_SENT','player','Gnarlpine Ursa','Cast-coins',921)
                    if ordering=='early_money' then money() end
                    event(ordering=='failed' and 'UNIT_SPELLCAST_FAILED' or 'UNIT_SPELLCAST_SUCCEEDED','player','Cast-coins',921)
                    if ordering=='empty_window' then event('LOOT_READY');event('LOOT_OPENED');event('LOOT_CLOSED') end
                    if ordering=='corpse' then dead=true end
                    if ordering=='expired' then now=now+4 end
                    if ordering=='native_delayed_chat' then
                        -- Native report: close 931497.772, balance +1 at .948,
                        -- chat 931498.774 (2ms after the context expires).
                        local mono=931496.970
                        function GetTime() return mono end
                        event('UNIT_SPELLCAST_SENT','player','Gnarlpine Ursa','Cast-native',921)
                        event('UNIT_SPELLCAST_SUCCEEDED','player','Cast-native',921)
                        mono=931497.772;event('LOOT_CLOSED');event('LOOT_CLOSED')
                        mono=931497.948;balance=balance+2;fire('PLAYER_MONEY')
                        assert(not AzerothFieldbookLedgerDB.cashFlow.entries[1].source,'Balance alone does not prove loot')
                        mono=931498.774;fire('CHAT_MSG_MONEY','You loot 2 Copper.')
                    elseif ordering~='early_money' then money() end
                    flush()
                    local cash=AzerothFieldbookLedgerDB.cashFlow
                    local expected=(ordering=='failed' or ordering=='corpse' or ordering=='expired') and 'Looted cash' or 'Pickpocketed cash'
                    assert(#cash.entries==1 and cash.income==2 and cash.entries[1].amount==2)
                    assert(cash.entries[1].context==expected,cash.entries[1].context)
                """)

    def test_flight_fares_handle_close_and_money_order_without_guessing(self):
        for ordering in ('before_close','after_close','late_taxi','cancelled','expired','competing','income'):
            with self.subTest(ordering=ordering):
                lua=new_ledger();lua.globals().ordering=ordering
                lua.execute("""
                    AzerothFieldbookLedgerDB={};balance=1000;taxi=false
                    function GetMoney() return balance end
                    function UnitOnTaxi() return taxi end
                    fire('PLAYER_ENTERING_WORLD');fire('TAXIMAP_OPENED')
                    if ordering~='before_close' then fire('TAXIMAP_CLOSED') end
                    if ordering=='expired' then now=now+4 end
                    if ordering=='competing' then fire('MAIL_SHOW') end
                    taxi=ordering~='late_taxi' and ordering~='cancelled'
                    balance=balance+(ordering=='income' and 330 or -330);fire('PLAYER_MONEY')
                    if ordering=='before_close' then fire('TAXIMAP_CLOSED') end
                    if ordering=='late_taxi' then taxi=true end
                    flush()
                    local cash=AzerothFieldbookLedgerDB.cashFlow;local e=cash.entries[1]
                    local matched=ordering=='before_close' or ordering=='after_close' or ordering=='late_taxi'
                    assert((e.source=='flight')==matched,ordering)
                    if matched then assert(e.counterparty=='Flight transport' and e.context=='Flight fare') end
                    assert(#cash.entries==1 and cash.expense==(ordering=='income' and 0 or 330))
                    if matched then
                        balance=balance-1;fire('PLAYER_MONEY');flush()
                        assert(not cash.entries[1].source,'one departure cannot classify two payments')
                    end
                    now=now+4;balance=balance-7;fire('PLAYER_MONEY');flush()
                    assert(not cash.entries[1].source,'later expenditure inherited the fare')
                """)

    def test_cash_flow_login_logout_and_disabled_addon_discrepancies(self):
        lua=new_ledger()
        lua.execute('''
            AzerothFieldbookLedgerDB={};balance=1000
            function GetMoney() return balance end
            t:OnEvent('PLAYER_ENTERING_WORLD')
            local cash=AzerothFieldbookLedgerDB.cashFlow
            assert(cash.loginBalance==1000 and cash.lastBalance==1000 and not cash.entries[1])
            balance=1200;t:OnEvent('PLAYER_MONEY');t:OnEvent('PLAYER_LOGOUT')
            assert(cash.logoutBalance==1200 and cash.income==200)
            -- No tracking events while the addon is disabled.
            balance=1500;local resumed=ns.CreateLedgerTracking(j)
            assert(cash.lastBalance==1200,'Construction preserves the saved checkpoint')
            resumed:OnEvent('PLAYER_ENTERING_WORLD')
            assert(cash.entries[1].source=='discrepancy' and cash.entries[1].amount==300)
            assert(cash.entries[1].previousBalance==1200 and cash.income==500)
            local count=#cash.entries
            resumed:OnEvent('PLAYER_ENTERING_WORLD');resumed:OnEvent('PLAYER_MONEY')
            assert(#cash.entries==count,'Login discrepancy is recorded only once')
            resumed:OnEvent('PLAYER_LOGOUT')
            balance=1400;resumed=ns.CreateLedgerTracking(j);resumed:OnEvent('PLAYER_ENTERING_WORLD')
            assert(cash.entries[1].source=='discrepancy' and cash.entries[1].amount==-100 and cash.expense==100)
            balance=1410;resumed:OnEvent('PLAYER_MONEY')
            assert(cash.entries[1].amount==10 and not cash.entries[1].source and cash.income==510)
            resumed:OnEvent('PLAYER_LOGOUT');assert(cash.logoutBalance==1410)
        ''')

    def test_cash_flow_icon_loot_and_existing_run_repair(self):
        lua=new_ledger()
        lua.execute('''
            AzerothFieldbookLedgerDB={cashFlow={income=38,expense=0,entries={
                {at=3,amount=1,balance=184},{at=2,amount=4,balance=183},{at=1,amount=33,balance=179}}}}
            balance=184;function GetMoney() return balance end
            t=ns.CreateLedgerTracking(j)
            t:OnEvent('PLAYER_ENTERING_WORLD')
            local cash=AzerothFieldbookLedgerDB.cashFlow
            assert(#cash.entries==1 and cash.entries[1].amount==38 and cash.income==38)
            -- Isolate this tracker because the harness already has another one.
            balance=balance+2;t:OnEvent('PLAYER_MONEY')
            t:OnEvent('CHAT_MSG_MONEY','You loot 2|TInterface\\\\MoneyFrame\\\\UI-CopperIcon:0:0|t.')
            assert(cash.entries[1].source=='loot' and cash.entries[1].amount==2,snapshot(cash.entries))
            balance=balance+3;t:OnEvent('CHAT_MSG_MONEY','You loot 3|TInterface\\\\MoneyFrame\\\\UI-CopperIcon:0:0|t.')
            t:OnEvent('PLAYER_MONEY')
            assert(#cash.entries==2 and cash.entries[1].amount==5 and cash.entries[1].lootCount==2)
            balance=balance-1;t:OnEvent('PLAYER_MONEY')
            balance=balance+4;t:OnEvent('CHAT_MSG_MONEY','You loot 4 copper coins.')
            assert(#cash.entries==4 and cash.entries[1].amount==4 and cash.income==47)
        ''')

    def test_cash_flow_consolidates_only_uninterrupted_confirmed_loot(self):
        lua=new_ledger()
        lua.execute('''
            AzerothFieldbookLedgerDB={};balance=1000
            GOLD_AMOUNT='%d Gold';SILVER_AMOUNT='%d Silver';COPPER_AMOUNT='%d Copper'
            function GetMoney() return balance end
            fire('PLAYER_ENTERING_WORLD')
            balance=balance+20;fire('CHAT_MSG_MONEY','You loot 20 Copper.');fire('PLAYER_MONEY');flush()
            balance=balance+30;fire('PLAYER_MONEY');fire('CHAT_MSG_MONEY','You loot 30 Copper.');flush()
            local cash=AzerothFieldbookLedgerDB.cashFlow
            assert(#cash.entries==1 and cash.entries[1].amount==50 and cash.entries[1].lootCount==2)
            assert(cash.income==50 and cash.entries[1].balance==1050)
            balance=balance+100;fire('PLAYER_MONEY');flush()
            balance=balance+10;fire('CHAT_MSG_MONEY','You loot 10 Copper.');fire('PLAYER_MONEY');flush()
            assert(#cash.entries==3 and cash.entries[1].amount==10)
            balance=balance-5;fire('PLAYER_MONEY');flush()
            balance=balance+40;fire('PLAYER_MONEY');fire('CHAT_MSG_MONEY','You loot 40 Copper.');flush()
            assert(#cash.entries==5 and cash.entries[1].amount==40)
            balance=balance+50;fire('PLAYER_MONEY');fire('CHAT_MSG_MONEY','You loot 50 Copper.');flush()
            assert(#cash.entries==5 and cash.entries[1].amount==90 and cash.entries[1].lootCount==2)
            assert(cash.income==250 and cash.expense==5)
            -- A message with a different amount must not classify unrelated income.
            balance=balance+60;fire('PLAYER_MONEY');fire('CHAT_MSG_MONEY','You loot 1 Copper.');flush()
            assert(#cash.entries==6 and not cash.entries[1].source)
            fire('PLAYER_ENTERING_WORLD')
            balance=balance+10;fire('CHAT_MSG_MONEY','You loot 10 Copper.');flush()
            assert(#cash.entries==7,'World entry cannot bridge an unobserved interval')
        ''')

    def test_training_checks_current_spellbook_and_rank_without_changing_history(self):
        lua=new_ledger()
        lua.execute('''
            local e=visit();UnitLevel=function() return 20 end
            trainer={{name='Battle Shout',status='available',level=1,rank='Rank 1',price=10},
                {name='Battle Shout',status='available',level=10,rank='Rank 2',price=100}}
            fire('TRAINER_SHOW');flush();shell:ShowSection('merchants');c:Select(e.id);c:Catalogue('training')
            local before=snapshot(e.lessons)
            assert(c.main.events.SPELLS_CHANGED and not c.main.events.LEARNED_SPELL_IN_TAB)
            GetNumSpellTabs=function() return 1 end
            GetSpellTabInfo=function() return 'Warrior',123,0,1 end
            local learnedRank='Rank 1'
            GetSpellBookItemName=function() return 'Battle Shout',learnedRank end
            fire('SPELLS_CHANGED')
            local function displayed() local parts={};for _,block in ipairs(c.panels.catalogue.read.blocks) do parts[#parts+1]=block:GetText() or '' end;return table.concat(parts,' ') end
            local text=displayed()
            assert(text:find('Learned by this character',1,true))
            local _,count=text:gsub('Learned by this character','')
            assert(count==1,'Knowing Rank 1 does not mark Rank 2 learned')
            learnedRank='Rank 2';fire('SPELLS_CHANGED')
            text=displayed()
            _,count=text:gsub('Learned by this character','');assert(count==2)
            assert(snapshot(e.lessons)==before,'Spellbook checks are display-only')
            GetNumSpellTabs=nil;GetSpellTabInfo=nil;GetSpellBookItemName=nil
            Enum.SpellBookSpellBank={Player=0}
            C_SpellBook={GetNumSpellBookSkillLines=function() return 1 end,
                GetSpellBookSkillLineInfo=function() return {itemIndexOffset=0,numSpellBookItems=1} end,
                GetSpellBookItemName=function(index,bank) assert(bank==0);return 'Battle Shout','Rank 1' end}
            fire('SPELLS_CHANGED')
            text=displayed()
            _,count=text:gsub('Learned by this character','');assert(count==1)
        ''')

    def test_cash_flow_tracks_character_money_without_login_income(self):
        lua = new_ledger()
        lua.execute('''
            AzerothFieldbookLedgerDB={};balance=10000
            function GetMoney() return balance end
            fire('PLAYER_ENTERING_WORLD')
            balance=12345;fire('PLAYER_MONEY');fire('PLAYER_MONEY')
            balance=12000;fire('PLAYER_MONEY')
            local cash=AzerothFieldbookLedgerDB.cashFlow
            assert(cash.income==2345 and cash.expense==345 and #cash.entries==2)
            assert(not saved.cashFlow,'Shared directory must not own character finances')
            balance=99999;fire('PLAYER_ENTERING_WORLD');fire('PLAYER_MONEY')
            assert(cash.income==90344 and #cash.entries==3,'World transitions preserve balance changes')
            for i=1,205 do balance=balance+1;fire('PLAYER_MONEY') end
            assert(#cash.entries==208 and cash.income==90549)
            assert(cash.entries[208].amount==2345,'Old activity remains past 200 rows')
            ns.InitializationBlocked=true;balance=balance+10;fire('PLAYER_MONEY')
            assert(cash.income==90549)
        ''')

    def test_cash_flow_toggle_covers_directory_and_restores_it(self):
        lua = new_ledger()
        lua.execute('''
            shell:ShowSection('merchants');c:CashFlow()
            assert(c.panel==c.panels.cashFlow and not c.main.directory:IsShown())
            assert(c.panels.cashFlow.read.topFade and c.panels.cashFlow.read.bottomFade)
            assert(#c.panels.cashFlow.read.topFade.strips==24,'Cash Flow uses the shared parchment fades')
            assert(c.panels.cashFlow.usage:GetText():find('No row limit',1,true))
            assert(c.panels.cashFlow.read.header:GetText():find('No gold changes recorded yet.',1,true))
            AzerothFieldbookLedgerDB={cashFlow={income=100,expense=50,entries={
                {at=ns.Ledger.Now(),amount=-50,balance=50,context='Fireball'},
                {at=ns.Ledger.Now(),amount=100,balance=100,context='Cloth'}}}}
            local p=c.panels.cashFlow
            local function cashText()
                local text=p.read.header:GetText()
                for _,row in ipairs(p.read.transactionRows) do if row:IsShown() then text=text.." "..row.text:GetText() end end
                return text
            end
            assert(p.character:GetText()==ns.Ledger.Safe(ns.Ledger.Player()))
            assert(p.character.point[4]==37 and p.character.point[5]==-88)
            assert(not p.read.header:GetText():find(ns.Ledger.Safe(ns.Ledger.Player()),1,true),'Character name is outside activity text')
            assert(not p.title:IsShown(),'Cash Flow heading stays hidden')
            assert(cashText():find('|cff80e680Gold in:|r',1,true),'Colour markup is preserved')
            assert(cashText():find('0|cffb87333c|r',1,true),'Zero uses the copper suffix colour')
            assert(not cashText():find('||cff',1,true),'Colour codes must not be escaped')
            p.search:SetText('fireball');c:RefreshCashFlow()
            assert(p.usage:GetText():find('2 rows',1,true),'Usage covers the whole history, not search matches')
            assert(cashText():find('To: ',1,true),'Expenses name a destination')
            assert(cashText():find('|cff71d5ff•|r',1,true))
            assert(cashText():find('|cffffffffFireball|r',1,true),'Observed ability names are white')
            assert(cashText():find('|cffff8080Balance:|r |cffffffff',1,true),'Balance labels follow transaction colour and figures remain white')
            assert(p.read.transactionRows[1].text:GetText():sub(1,10)=='|cffffffff','Transaction dates are white')
            assert(#p.read.transactionRows[1].divider==32 and p.read.transactionRows[1]:IsShown())
            local transaction=p.read.transactionRows[1]
            assert(transaction.dividerHost.point[2]==transaction)
            assert(transaction.dividerHost.point[5]==-transaction:GetHeight()+8,'Divider anchor stays beneath transaction')
            p.read:SetVerticalScroll(35)
            assert(transaction.dividerHost.point[5]==-transaction:GetHeight()+8,'Scrolling preserves divider offset')
            assert(cashText():find('Fireball',1,true))
            assert(not cashText():find('Cloth',1,true))
            p.direction='income';c:RefreshCashFlow()
            assert(cashText():find('No activity matches',1,true))
            assert(not p.read.transactionRows[1]:IsShown(),'Filtered rows and their dividers are hidden')
            p.search:SetText('');c:RefreshCashFlow()
            assert(cashText():find('Cloth',1,true))
            assert(cashText():find('From: ',1,true),'Income names a source')
            assert(not cashText():find('Fireball',1,true))
            c:CashFlow()
            assert(c.panel==nil and c.main.directory:IsShown())
        ''')

    def setUp(self):
        self.lua = new_ledger()

    def test_manual_services_allow_multiple_choices_and_preserve_observations(self):
        self.lua.execute("""
            local e=visit();shell:ShowSection('merchants');c:Select(e.id);c:Notes()
            local p=c.panels.notes;local choices={}
            MenuUtil={CreateContextMenu=function(_,build)
                build(nil,{SetScrollMode=function() end,CreateCheckbox=function(_,name,checked,action)
                    choices[name]={checked=checked,action=action}
                end})
            end}
            p.role.scripts.OnClick(p.role)
            choices[ns.Ledger.roles.banker].action()
            choices[ns.Ledger.roles.trainer].action()
            assert(p.roles.banker and p.roles.trainer)
            assert(choices[ns.Ledger.roles.banker].checked() and choices[ns.Ledger.roles.trainer].checked())
            local observed=snapshot(e.roles)
            assert(j:Annotate(e.id,'Notes',p.roles,''))
            assert(e.manualRoles.banker and e.manualRoles.trainer)
            assert(j:Annotate(e.id,'Notes',{trainer=true},''))
            assert(not e.manualRoles.banker and e.manualRoles.trainer)
            assert(snapshot(e.roles)==observed,'Manual deselection preserves observed roles')
            p.contact=nil;c:ClosePanel();c:Notes()
            assert(p.roles.trainer and not p.roles.banker,'Saved selections reopen checked')
        """)

    def test_class_trainers_discovered_without_training_window(self):
        self.lua.execute('''
            for i,class in ipairs({'Druid','Hunter','Mage','Paladin','Priest','Rogue','Shaman','Warlock','Warrior'}) do
                targetNPC=100+i;vendorNPC=targetNPC;sublabel='<'..class..' Trainer>'
                fire('UPDATE_MOUSEOVER_UNIT');fire('PLAYER_TARGET_CHANGED')
                local e=j:Get(saved.aliases[UnitGUID('target')])
                assert(e and e.personal and e.roles.trainer and not e.roles.merchant)
                assert(e.sublabel==sublabel and next(e.lessons)==nil and not e.trainerInspection)
                assert(e.sightings[1].x==nil,'Distant sightings cannot use player coordinates')
                assert(#j:List({query=class,roles={trainer=true}})==1)
            end
            assert(L.Count(saved.contacts)==9 and shell:GetFrame()==nil)
        ''')

    def test_class_trainer_dialogue_and_later_lessons_share_contact(self):
        self.lua.execute('''
            sublabel='Mage Trainer';targetNPC=99
            C_TooltipInfo.GetUnit=function()
                return {lines={{type=2,leftText=name},{type=2,leftText=sublabel}}}
            end
            fire('GOSSIP_SHOW')
            local e=one(saved.contacts)
            assert(e and e.npcID==42 and e.roles.trainer and e.sightings[1].precision=='player')
            assert(not e.trainerInspection and next(e.lessons)==nil)
            fire('GOSSIP_OPTIONS_REFRESHED')
            trainer={{name='Fireball',status='available',rank='Rank 2',category='Fire',price=100}}
            fire('TRAINER_SHOW')
            assert(L.Count(saved.contacts)==1 and t.visits.trainer.contact==e.id)
            assert(one(e.lessons).name=='Fireball' and not e.trainerInspection.complete)
        ''')

    def test_class_trainer_discovery_requires_readable_exact_title_and_identity(self):
        self.lua.execute('''
            for _,title in ipairs({'Trainer','Mage','Not a Mage Trainer','Mage Trainer assistant','Bowyer'}) do
                sublabel=title;name='Mage Trainer'
                fire('PLAYER_TARGET_CHANGED');fire('UPDATE_MOUSEOVER_UNIT');fire('GOSSIP_SHOW')
                assert(next(saved.contacts)==nil)
            end
            sublabel=secret;fire('GOSSIP_SHOW');assert(next(saved.contacts)==nil)
            sublabel='Mage Trainer';vendorNPC=nil
            fire('GOSSIP_SHOW');assert(next(saved.contacts)==nil,'No target fallback for dialogue')
            vendorNPC=42;C_TooltipInfo.GetUnit=function() error('unavailable') end
            fire('UPDATE_MOUSEOVER_UNIT');assert(next(saved.contacts)==nil)
        ''')

    def test_all_contact_announcements_obey_chat_setting(self):
        self.lua.execute("""
            local messages={}
            DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
            for i,role in ipairs({'trainer','innkeeper','banker','auctioneer','stable','transport','repair'}) do
                local v={name='Contact '..i,guid='Creature-0-1-2-3-'..i..'-ABC',npcID=i}
                local e=j:Encounter(v,{[role]=true},false)
                assert(e and #messages==i and messages[i]:find(e.name,1,true))
                if role=='trainer' then assert(messages[i]:find('|cff999999(Trainer)|r',1,true)) end
                j:Encounter(v,{[role]=true},false);assert(#messages==i)
            end
            j:Manual({name='Manual contact'});assert(#messages==8 and messages[8]:find('|cff999999(Contact)|r',1,true))
            chatEnabled=false
            j:Manual({name='Silent manual contact'})
            j:Encounter({name='Silent trainer',guid='Creature-0-1-2-3-99-ABC',npcID=99},{trainer=true},false)
            assert(#messages==8)
        """)

    def test_transport_discovery_when_path_learned_before_flight_map(self):
        self.lua.execute('''
            local messages={}
            DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
            targetNPC=99
            fire('NEW_TAXI_PATH')
            local e=one(saved.contacts)
            assert(e and e.npcID==42 and e.personal and e.roles.transport)
            assert(#messages==1 and messages[1]:find('(Transport)',1,true))
            fire('NEW_TAXI_PATH');fire('TAXIMAP_OPENED')
            assert(L.Count(saved.contacts)==1 and #messages==1,'Flight map must not repeat discovery')
            vendorNPC=nil;fire('NEW_TAXI_PATH')
            assert(L.Count(saved.contacts)==1,'Missing interaction identity must not use target')
            vendorNPC=100;fire('TAXIMAP_OPENED')
            assert(L.Count(saved.contacts)==2 and #messages==2,'Already learned paths still discover contacts')
        ''')

    def test_merchant_discovery_message_once_per_contact(self):
        self.lua.execute(r'''
            local messages={}
            DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
            local e=visit()
            assert(#messages==1 and messages[1]=='|cff80d0ffAFB:|r |cffffd100[New discovery!]|r |cff80d0ffMerchant’s Ledger:|r |cffffffff'..e.name..'|r |cff999999(Merchant)|r')
            fire('MERCHANT_UPDATE');fire('MERCHANT_CLOSED');visit()
            assert(#messages==1,'Repeat visits cannot spam discovery messages')
            local reloaded=ns.CreateLedgerJournal(saved)
            reloaded.onContactDiscovered=j.onContactDiscovered
            reloaded:Encounter(L.Unit('npc'),{merchant=true},true)
            assert(#messages==1,'Saved merchant role prevents duplicate notices after reload')
            fire('MERCHANT_CLOSED');t:Forget(e.id);assert(j:Remove(e.id));visit()
            assert(#messages==2,'Removed merchants can be discovered again')
        ''')

    def test_empty_isolation_background_discovery_and_actual_sublabel(self):
        self.lua.execute('''
            assert(next(saved.contacts)==nil and shell:GetFrame()==nil)
            fire('PLAYER_TARGET_CHANGED');fire('UPDATE_MOUSEOVER_UNIT');assert(next(saved.contacts)==nil)
            items={};local e=visit(42,'ABC',{})
            assert(e.name==name and e.sublabel=='Bowyer' and e.roles.merchant and e.roles.repair)
            assert(next(e.goods)==nil and shell:GetFrame()==nil)
            assert(e.sightings[1].precision=='player' and e.sightings[1].x==2500)
            assert(not AzerothFieldbookDB and not AzerothFieldbookAtlasDB and not AzerothFieldbookAnglingDB)
            assert(e.reference:find('ledger:',1,true)==1)
        ''')

    def test_delayed_interaction_identity_recovers_without_target_fallback(self):
        self.lua.execute('''
            vendorNPC=nil;targetNPC=99;name='Innkeeper Heather';items={item(1001,3,250)}
            fire('MERCHANT_SHOW');assert(next(saved.contacts)==nil)
            vendorNPC=42;flush()
            local e=j:Get(t.visits.merchant.contact)
            assert(e.name=='Innkeeper Heather' and e.npcID==42 and e.roles.merchant)
            assert(one(e.goods).itemID==1001 and L.Count(saved.contacts)==1)
            flush();assert(L.Count(saved.contacts)==1)
        ''')

    def test_missing_identity_close_cancels_retry_and_late_updates(self):
        self.lua.execute('''
            vendorNPC=nil;fire('MERCHANT_SHOW');fire('MERCHANT_CLOSED')
            vendorNPC=42;flush();fire('MERCHANT_UPDATE');flush()
            assert(next(saved.contacts)==nil and t.visits.merchant==nil)
        ''')

    def test_merchant_update_recovers_initially_unreadable_identity(self):
        self.lua.execute('''
            vendorNPC=nil;fire('MERCHANT_SHOW');flush()
            vendorNPC=42;items={item(1001,3,250)};fire('MERCHANT_UPDATE')
            assert(t.visits.merchant and L.Count(saved.contacts)==1)
        ''')

    def test_bracketed_title_and_matching_tooltip_fallback(self):
        self.lua.execute('''
            C_TooltipInfo.GetUnit=function(unit)
                if unit=='npc' then return {lines={}} end
                return {lines={{type=0,leftText=name},{type=0,leftText='<Innkeeper>'}}}
            end
            local e=visit();assert(e.sublabel=='<Innkeeper>')
            assert(j:Sublabel(e)=='<Innkeeper>')
            e.sublabel='Innkeeper';assert(j:Sublabel(e)=='<Innkeeper>')
            e.sublabel='';targetNPC=99
            fire('MERCHANT_UPDATE');flush();assert(e.sublabel=='')
            targetNPC=42;fire('MERCHANT_UPDATE');flush();assert(j:Sublabel(e)=='<Innkeeper>')
        ''')

    def test_goods_rich_text_icons_and_links_are_generated_from_item_ids(self):
        self.lua.execute('''
            local e=visit();c.state.detail='goods'
            local text=c:Details(e,true)
            assert(text:find('|Hitem:1001|h|T123:18:18:0:0|t ',1,true))
            one(e.goods).name='Bad |Hitem:999|hname|h'
            text=c:Details(e,true);assert(not text:find('|Hitem:999|h',1,true))
            one(e.goods).icon=nil;text=c:Details(e,true)
            assert(text:find('|Hitem:1001|h',1,true))
        ''')

    def test_contact_removal_cleans_indexes_and_allows_reencounter(self):
        self.lua.execute('''
            local e=visit();local id=e.id;local reference=e.reference
            saved.references['old-linked-reference']=id;saved.reportKeys['source']=id
            t:Forget(id);assert(j:Remove(id));flush();fire('MERCHANT_UPDATE');flush()
            assert(not j:Get(id) and not j:Reference(reference))
            assert(next(saved.aliases)==nil and next(saved.references)==nil and next(saved.reportKeys)==nil)
            assert(t.pendingCount==0 and next(saved.contacts)==nil)
            local fresh=visit();assert(fresh.id~=id and fresh.roles.merchant and next(fresh.goods))
            j.readOnly=true;assert(not j:Remove(fresh.id));assert(j:Get(fresh.id))
        ''')

    def test_favourite_toggle_keeps_icon_and_label_anchors(self):
        self.lua.execute('''
            local e=visit();shell:ShowSection('merchants');c:Select(e.id)
            local b=c.main.favourite;local box=b.savedBox;local check=b.savedCheck
            assert(box.texture==table.concat({'Interface','Buttons','UI-CheckBox-Up'},string.char(92)))
            assert(check.texture==table.concat({'Interface','Buttons','UI-CheckBox-Check'},string.char(92)))
            local point=snapshot(box.point);local label=snapshot(b:GetFontString().points)
            assert(not check:IsShown() and b:GetText()=='Favourite')
            b.scripts.OnClick();flush();assert(check:IsShown() and b:GetText()=='Favourite')
            assert(snapshot(box.point)==point and snapshot(b:GetFontString().points)==label)
            b.scripts.OnClick();flush();assert(not check:IsShown() and b:GetText()=='Favourite' and snapshot(box.point)==point)
        ''')

    def test_remove_contact_requires_confirmation(self):
        self.lua.execute('''
            local e=visit();shell:ShowSection('merchants');c:Select(e.id)
            c:RemoveContact();assert(j:Get(e.id))
            c:ClosePanel();assert(j:Get(e.id))
            c:RemoveContact();c.panels.remove.confirm.scripts.OnClick()
            assert(not j:Get(e.id) and c.panel==nil)
        ''')

    def test_goods_heading_uses_larger_font_and_item_quality(self):
        self.lua.execute('''
            local e=visit();shell:ShowSection('merchants');c:Select(e.id)
            C_Item.GetItemInfo=function() return 'Rare goods',nil,3 end
            ITEM_QUALITY_COLORS={[3]={hex='|cff0070dd'}}
            local text,blocks=c:Details(e,true)
            assert(text:find('|cff0070dd',1,true))
            assert(blocks[2].heading)
            c:Catalogue('goods');assert(c.panels.catalogue.read.blocks[2]:GetText():find('|cff0070dd',1,true))
            C_Item.GetItemInfo=function() return nil end
            assert(c:Details(e,true):find('|cffffffff',1,true))
        ''')

    def test_training_eligibility_uses_current_level_without_changing_observations(self):
        self.lua.execute("""
            shell:ShowSection('merchants')
            local e=visit()
            trainer={{name='Sword lesson',status='unavailable',level=20,rank='',category='',price=100}}
            fire('TRAINER_SHOW');flush();c:Select(e.id);c:Catalogue('training')
            local before=snapshot(e)
            UnitLevel=function() return 19 end
            local text=c:Details(e,true,'training')
            assert(text:find('|cffff8080Sword lesson|r',1,true))
            assert(text:find('Cannot learn yet: requires level 20',1,true))
            UnitLevel=function() return 20 end
            c.main.scripts.OnEvent(c.main,'PLAYER_LEVEL_UP',20)
            text=c:Details(e,true,'training')
            assert(text:find('|cff80e680Sword lesson|r',1,true))
            assert(text:find('Can learn at your current level',1,true))
            assert(snapshot(e)==before,'Level-based display must preserve the observation')
            local lesson=one(e.lessons);lesson.requirements={'Required level: 20','Sword proficiency (100)'}
            assert(c:Details(e,true,'training'):find('additional requirements must be met',1,true))
        """)

    def test_goods_training_overlays_toggle_and_leave_notes_visible(self):
        self.lua.execute('''
            local e=visit();e.note='Use the side entrance'
            trainer={{name='Sword lesson',status='available',rank='',category='',price=10}};fire('TRAINER_SHOW')
            shell:ShowSection('merchants');c:Select(e.id);local m=c.main
            local notes=m.details.text:GetText();assert(notes:find(e.note,1,true))
            m.detailButtons.goods.scripts.OnClick()
            local panel=c.panels.catalogue
            assert(c.panel==panel and m.directory:IsShown() and panel.kind=='goods')
            assert(not m.contactList:IsShown() and m.search:IsVisible())
            assert(m.detailButtons.goods:IsVisible() and m.detailButtons.training:IsVisible())
            assert(panel.point[2]==42 and panel.point[3]==-170)
            assert(panel.read:GetHeight()==524)
            for _,button in ipairs(m.catalogueHiddenButtons) do assert(not button:IsShown()) end
            assert(panel.read.point[3]==panel.sort.point[3])
            assert(m.detailButtons.goods.afbSelected and not m.detailButtons.training.afbSelected)
            m.detailButtons.training.scripts.OnClick()
            assert(c.panel==panel and panel.kind=='training')
            for _,button in ipairs(m.catalogueHiddenButtons) do assert(not button:IsShown()) end
            assert(not m.detailButtons.goods.afbSelected and m.detailButtons.training.afbSelected)
            assert(m.details.text:GetText()==notes)
            m.detailButtons.training.scripts.OnClick()
            assert(c.panel==nil and m.directory:IsShown() and not m.detailButtons.training.afbSelected)
            assert(panel.back==nil)
            for _,button in ipairs(m.catalogueHiddenButtons) do assert(button:IsShown()) end
            m.detailButtons.goods.scripts.OnClick();m.detailButtons.goods.scripts.OnClick()
            assert(c.panel==nil and not m.detailButtons.goods.afbSelected)
        ''')

    def test_catalogue_search_filters_offerings_and_restores_contact_search(self):
        self.lua.execute('''
            local e=visit()
            trainer={{name='Sword lesson',status='available',rank='',category='',price=10},
                {name='Axe lesson',status='available',rank='',category='',price=20}}
            fire('TRAINER_SHOW');flush();shell:ShowSection('merchants');c:Select(e.id)
            local m=c.main;m.search:SetText(e.name)
            c:Catalogue('training');assert(m.search:GetText()=='')
            m.search:SetText('sWoRd')
            local text=c:Details(e,false,'training')
            assert(text:find('Sword lesson',1,true) and not text:find('Axe lesson',1,true))
            m.search:SetText('no such offering')
            assert(c:Details(e,false,'training'):find('No offerings match your search.',1,true))
            m.search:SetText('');text=c:Details(e,false,'training')
            assert(text:find('Sword lesson',1,true) and text:find('Axe lesson',1,true))
            c:Catalogue('goods');local name
            for _,v in pairs(e.goods) do name=v.name;break end
            assert(name);m.search:SetText(name)
            assert(c:Details(e,false,'goods'):find(name,1,true))
            m.search:SetText('no such offering')
            assert(c:Details(e,false,'goods'):find('No offerings match your search.',1,true))
            c:ClosePanel();assert(m.search:GetText()==e.name and m.contactList:IsShown())
        ''')

    def test_offering_rows_hover_metadata_dividers_and_filter_reuse(self):
        self.lua.execute('''
            local e=visit(42,'ABC',{item(1001,-1,250),item(1002,-1,500)})
            trainer={{name='Sword lesson',status='available',rank='',category='',price=10},
                {name='Axe lesson',status='available',rank='',category='',price=20}}
            fire('TRAINER_SHOW');flush();shell:ShowSection('merchants');c:Select(e.id)
            local lines={}
            GameTooltip={SetOwner=function() end,SetText=function() lines={} end,
                SetHyperlink=function() lines={} end,AddLine=function(_,line) lines[#lines+1]=line end,
                Show=function() end,Hide=function() end}
            for _,kind in ipairs({'goods','training'}) do
                c:Catalogue(kind);local area=c.panels.catalogue.read
                assert(area.rows[1]:IsShown() and area.rows[2]:IsShown())
                assert(not area.rows[1].divider[1]:IsShown() and area.rows[2].divider[1]:IsShown())
                local row=area.rows[1]
                if kind=='goods' then
                    assert(row.view.point[2]==46 and row.view:GetWidth()==area:GetWidth()-46)
                    assert(row.view.icon.parent==row and row.view.icon.point[3]==-4)
                    assert(row:GetHeight()>=49,'Goods row must contain its icon alongside name and price')
                else
                    assert(row:GetHeight()>=row.view:GetHeight()+5+40+5,
                        'Training entries must contain the full icon below their heading')
                end
                assert(area.rows[2].top>=row.top+row:GetHeight(),
                    'Next entry must begin after the previous icon and hover area')
                assert(row.highlightTexture=='Interface\\\\QuestFrame\\\\UI-QuestTitleHighlight')
                assert(row:GetHeight()>row.view:GetHeight() and row:GetWidth()==area:GetWidth())
                row.scripts.OnEnter(row)
                local tooltip=table.concat(lines,' ')
                assert(tooltip:find('First:',1,true) and tooltip:find('Last:',1,true))
                assert(tooltip:find(row.view.offering.value.origin.source,1,true))
                row.scripts.OnLeave(row)
                c.main.search:SetText('nothing matches this')
                assert(not area.rows[1]:IsShown() and not area.rows[2]:IsShown())
                c.main.search:SetText('');assert(area.rows[2]:IsShown())
                c:ClosePanel()
            end
        ''')

    def test_innkeeper_name_typed_and_legacy_titles_add_both_roles(self):
        self.lua.execute('''
            name='Innkeeper Heather'
            C_TooltipInfo.GetUnit=function() return {lines={
                {type=2,leftText=name},{type=2,leftText='Innkeeper'},
                {type=47,leftText='Level 30'}}} end
            local e=visit();assert(j:Sublabel(e)=='<Innkeeper>')
            assert(e.roles.innkeeper and e.roles.merchant)
            C_TooltipInfo.GetUnit=function() return {lines={
                {type=0,leftText=name},{type=0,leftText='Innkeeper'},
                {type=0,leftText='Level 30'}}} end
            local other=visit(43,'DEF');assert(j:Sublabel(other)=='<Innkeeper>')
            assert(other.roles.innkeeper and other.roles.merchant)
        ''')

    def test_portrait_uses_selected_identity_and_manual_placeholder(self):
        self.lua.execute('''
            local e=visit();shell:ShowSection('merchants');c:Select(e.id)
            local m=c.main;local selected
            SetPortraitTexture=function(_,unit) selected=unit end
            m.portraitResolver.SetCreature=function(_,id) selected=id end
            m.portraitResolver.GetDisplayInfo=function() return 1234 end
            SetPortraitTextureFromCreatureDisplayID=function(_,id) assert(id==1234) end
            m.portraitKey=nil;c:Refresh();assert(selected=='npc')
            vendorNPC=99;targetNPC=99;c:Refresh();assert(selected==e.npcID)
            local manual=j:Manual({name='Manual contact'});c:Select(manual.id)
            assert(not m.portrait:IsShown() and m.portraitUnknown:IsShown())
            assert(m.favourite.savedBox.point[2]==14)
        ''')

    def test_goods_suppress_unlimited_stock_and_usage_purchase_warning(self):
        self.lua.execute('''
            local e=visit(42,'ABC',{item(1001,-1,250)});c.state.detail='goods'
            local v=one(e.goods);v.usable=false;v.purchasable=false
            v.requirements={'Requires Level 40'}
            local text=c:Details(e,true)
            assert(not text:find('Last observed stock:',1,true))
            assert(not text:find('Not purchasable',1,true))
            assert(not text:find('Not usable when inspected',1,true) and text:find('Requires Level 40',1,true))
            assert(not text:find('First:',1,true))
            v.notSeen=true;assert(c:Details(e,true):find('Not seen on the latest inspection',1,true))
            for _,stock in ipairs({{state='finite',quantity=2},{state='soldout'},{state='unknown'}}) do
                v.stock=stock;assert(c:Details(e,true):find('Last observed stock:',1,true))
            end
            v.usable=true;assert(c:Details(e,true):find('Not purchasable',1,true))
        ''')

    def test_notes_toggle_and_overflow_heading_scroll_reset(self):
        self.lua.execute('''
            local e=visit();shell:ShowSection('merchants');c:Select(e.id);local m=c.main
            m.detailButtons.services.scripts.OnClick();assert(m.detailButtons.services.afbSelected)
            c.panels.notes.edit:SetText('Unsaved draft')
            m.detailButtons.services.scripts.OnClick();assert(c.panel==nil and not m.detailButtons.services.afbSelected)
            m.detailButtons.services.scripts.OnClick();assert(c.panels.notes.edit:GetText()=='Unsaved draft')
            c:Catalogue('goods');local area=c.panels.catalogue.read;local label=area.blocks[2]
            GameFontNormal={GetFont=function() return 'font',14,'' end}
            label.SetFont=function(_,_,size) headingSize=size end
            label.GetUnboundedStringWidth=function() return 500 end
            c:Refresh();assert(headingSize==17)
            local view=area.headingViews[2];assert(view.contentWidth==501)
            local tooltipLink
            GameTooltip={IsOwned=function() return false end,SetOwner=function() end,SetHyperlink=function(_,link) tooltipLink=link end,
                AddLine=function() end,Show=function() end,Hide=function() tooltipLink=nil end}
            view.iconHover.scripts.OnEnter(view.iconHover)
            assert(tooltipLink==label:GetText():match('|H(item:%d+)'))
            view.iconHover.scripts.OnLeave();assert(tooltipLink==nil)

            assert(label:GetWidth()==view:GetWidth())
            view.scripts.OnEnter(view);assert(view.scripts.OnUpdate)
            assert(label:GetWidth()==501)
            view.scripts.OnUpdate(view,2);assert(view:GetHorizontalScroll()>0)
            view.scripts.OnLeave(view);assert(view:GetHorizontalScroll()==0 and not view.scripts.OnUpdate)
            assert(label:GetWidth()==view:GetWidth())
            assert(not view.canvas:IsMouseEnabled() and view.hover:IsMouseEnabled())
            view.hover.scripts.OnEnter(view.hover);assert(view.scripts.OnUpdate)
            view.scripts.OnUpdate(view,2);assert(view:GetHorizontalScroll()>0)
            view.hover.scripts.OnLeave(view.hover)
            assert(view:GetHorizontalScroll()==0 and not view.scripts.OnUpdate)
            assert(label:GetWidth()==view:GetWidth())
            label.GetUnboundedStringWidth=function() return 50 end
            c:Refresh();view.scripts.OnEnter(view);assert(not view.scripts.OnUpdate)
            assert(c:Details(e):find('Price:',1,true) and not c:Details(e):find('Last quoted price',1,true))
        ''')

    def test_repeated_mouseover_refresh_does_not_grow_goods_headings(self):
        self.lua.execute('''
            GameFontNormal={GetFont=function() return 'font',14,'' end}
            GameFontHighlightSmall={GetFont=function() return 'font',12,'' end}
            local e=visit();shell:ShowSection('merchants');c:Select(e.id);c:Catalogue('goods')
            local area=c.panels.catalogue.read;local label=area.blocks[2];local size=17
            label.GetFont=function() return 'font',size,'' end
            label.SetFont=function(_,_,value) size=value end
            for i=1,20 do
                now=now+1;fire('UPDATE_MOUSEOVER_UNIT');flush()
                assert(size==17,'Mouseover changed the heading size')
            end
            c:ClosePanel();c:Catalogue('goods');assert(size==17)
            c:Catalogue('training');assert(size==17)
            c:Catalogue('goods');assert(size==17)
        ''')

    def test_compact_bundle_price_and_exact_individual_cost(self):
        self.lua.execute('''
            local e=visit(42,'ABC',{item(1001,-1,125)});c.state.detail='goods'
            local v=one(e.goods);local text=c:Details(e)
            assert(text:find('Price: 1s 25c / 5 (25c ea)',1,true))
            assert(not text:find('0g',1,true) and not text:find('Per item, copper portion',1,true))
            v.price=10125;local colored=c:Details(e,true)
            assert(colored:find('1|cffffd100g|r',1,true))
            assert(colored:find('1|cffc7c7cfs|r',1,true))
            assert(colored:find('25|cffb87333c|r',1,true))
            assert(not colored:find('Per item',1,true))
            v.price=10000;assert(c:Details(e):find('Price: 1g / 5 (20s ea)',1,true))
            v.price=0;assert(c:Details(e):find('Price: Free / 5',1,true))
            v.price=nil;assert(c:Details(e):find('Price: Unknown / 5',1,true))
            v.price=101;assert(c:Details(e):find('(20.2c ea)',1,true))
            v.price=300;v.bundle=200;assert(c:Details(e):find('Price: 3s / 200 (1.5c ea)',1,true))
            v.bundle=nil;assert(c:Details(e):find('Bundle size unknown',1,true))
        ''')

    def test_mouseover_open_selects_contact_without_new_observations(self):
        self.lua.execute('''
            local e=visit();shell:ShowSection('merchants');c:Select(e.id)
            c.main.search:SetText('no match');c:Notes();shell:ShowSection('other')
            local before=snapshot(saved.contacts);local revision=j.revision
            assert(c:OpenAtUnit('mouseover') and shell.active=='merchants')
            assert(c.state.selected==e.id and c.state.query=='' and c.panel==nil)
            assert(snapshot(saved.contacts)==before and j.revision==revision)
            targetSpawn='DEF';assert(c:OpenAtUnit('mouseover'))
            assert(not saved.aliases[UnitGUID('mouseover')])
            targetNPC=999;assert(not c:OpenAtUnit('mouseover'))
        ''')

    def test_notes_and_map_toolbar_spacing(self):
        self.lua.execute('''
            local e=visit();shell:ShowSection('merchants');c:Select(e.id);local m=c.main
            assert(m.notes==nil)
            assert(m.sightings.point[3]==-174)
            assert(m.link.parent==m and m.link.point[2]==654 and m.link.point[3]==-89)
            assert(m.link.point[2]+m.link:GetWidth()==922)
            local goods=m.detailButtons.goods
            assert(goods.parent==m.directory and goods.point[2]==42 and goods:GetWidth()==122)
            assert(m.search.point[3]-m.search:GetHeight()>goods.point[3])
            assert(m.count.point[3]>m.search.point[3])
            assert(goods.point[3]-goods:GetHeight()>m.contactList.point[3])
            assert(not m.details.text:GetText():find('Access notes',1,true))
            e.note='Upstairs';c:Refresh();assert(m.details.text:GetText():find('Upstairs',1,true))
        ''')

    def test_default_location_prefers_recorded_point_in_same_area(self):
        self.lua.execute('''
            local e=visit();shell:ShowSection('merchants');c:Select(e.id);local m=c.main
            now=now+10;fire('UPDATE_MOUSEOVER_UNIT');flush()
            local sightings=j:Locations(e)
            assert(not L.Position(sightings[1]) and L.Position(sightings[2]))
            assert(c.state.sighting==2 and m.location:GetText():find('approximate',1,true))
            c:Sighting(1)
            assert(c.state.sighting==1 and m.location:GetText():find('coordinates not recorded for this sighting',1,true))
            c.state.sightingKey=nil;mapID=102;now=now+10;fire('UPDATE_MOUSEOVER_UNIT');flush()
            assert(c.state.sighting==1 and not L.Position(j:Locations(e)[1]))
            assert(m.location:GetText():find('coordinates not recorded for this sighting',1,true))
        ''')

    def test_location_menu_counts_only_coordinates_and_keeps_original_indices(self):
        self.lua.execute('''
            local e=visit();shell:ShowSection('merchants');c:Select(e.id);local m=c.main
            now=now+10;fire('UPDATE_MOUSEOVER_UNIT');flush()
            local sightings=j:Locations(e)
            assert(#sightings==2 and not L.Position(sightings[1]) and L.Position(sightings[2]))
            assert(m.sightings:GetText()=='NPC Location (1)' and m.sightings.enabled)
            local buttons={}
            function c:Menu(button,build)
                local root={SetScrollMode=function() end}
                function root:CreateButton(label,callback) buttons[#buttons+1]={label,callback} end
                build(button,root)
            end
            m.sightings.scripts.OnClick(m.sightings)
            assert(#buttons==1 and not buttons[1][1]:find('coordinates not recorded',1,true))
            buttons[1][2]();assert(c.state.sighting==2)
            assert(#j:Locations(e)==2,'Do not delete zone-only evidence')
            local unknown=j:New('Unlocated NPC');c:Select(unknown.id)
            assert(m.sightings:GetText()=='NPC Locations (0)' and not m.sightings.enabled)
        ''')

    def test_visible_items_without_buying_and_per_vendor_stock(self):
        self.lua.execute('''
            local a=visit(42,'ABC',{item(1001,2,100)})
            now=now+10;local b=visit(43,'DEF',{item(1001,0,0)})
            assert(a~=b and one(a.goods).price==100 and one(b.goods).price==0)
            assert(one(a.goods).stock.state=='finite' and one(b.goods).stock.state=='soldout')
            assert(one(a.goods).last<one(b.goods).last and one(a.goods).bundle==5)
            assert(a.merchantInspection.complete and b.merchantInspection.complete)
        ''')

    def test_nearby_identity_fallback_across_sessions_and_ambiguity(self):
        self.lua.execute('''
            local function encounter(book,guid,x,y,title,near)
                return book:Encounter({guid=guid,npcID=42,name='Stationary service',sublabel=title,
                    location={mapID=101,zone='Town',subzone='Square',x=x,y=y}},
                    {merchant=true},near~=false)
            end
            local a=encounter(j,'old',7123,7236,'Gryphon Master')
            a.note='Keep my notes';local ref=a.reference
            local loaded=ns.CreateLedgerJournal(saved)
            local b=encounter(loaded,'new',7132,7243,'Gryphon Master')
            assert(a==b and L.Count(saved.contacts)==1 and b.note=='Keep my notes')
            assert(loaded:Reference(ref)==b and saved.aliases.new==b.id)
            assert(encounter(loaded,'new',8000,8000,'Gryphon Master')==b,'Known GUID must follow movement')
            local separate=encounter(loaded,'other',7132,7243,'Gryphon Master')
            assert(separate~=b,'Same-session GUIDs must stay distinct')
            loaded=ns.CreateLedgerJournal(saved)
            assert(encounter(loaded,'ambiguous',7130,7240,'Gryphon Master')~=b,'Multiple candidates must not auto-match')
            local function isolated(x,y,title,near)
                local db={};local book=ns.CreateLedgerJournal(db)
                local first=encounter(book,'first',1000,1000,'Trainer')
                book=ns.CreateLedgerJournal(db)
                return first,encounter(book,'second',x,y,title,near)
            end
            local a,b=isolated(1015,1020,'Trainer');assert(a==b,'Radius boundary must match across grid cells')
            a,b=isolated(1020,1020,'Trainer');assert(a~=b,'Diagonal beyond radius must not match')
            a,b=isolated(1000,1000,'Different title');assert(a~=b)
            a,b=isolated(1000,1000,nil);assert(a==b,'Missing title must not create a duplicate')
            a,b=isolated(1000,1000,'Trainer',false);assert(a~=b,'No coordinates means no fallback')
        ''')

    def test_guid_context_identity_motion_reload_and_ambiguity(self):
        self.lua.execute('''
            local a=visit();mapID=102;px=0.8;now=now+10;local b=visit()
            assert(a==b and #a.sightings==2 and L.Count(saved.contacts)==1)
            j=ns.CreateLedgerJournal(saved);t=ns.CreateLedgerTracking(j);assert(visit()==a)
            local other=visit(42,'DEF');assert(other~=a and other.ambiguous and L.Count(saved.contacts)==2)
            assert(other.name==a.name and other.npcID==a.npcID)
        ''')

    def test_transport_duplicate_migration_and_changed_spawn(self):
        self.lua.execute('''
            local refs,ids={},{}
            saved.transportIdentityMigration=nil
            -- Seed the four legacy records without invoking encounter matching.
            for i=1,4 do
                local e=j:New('Dungar Longdrink');ids[i]=e.id;refs[i]=e.reference
                e.personal=true;e.npcID=352;e.roles.transport={at=i}
                e.sublabel=i==1 and '' or 'Gryphon Master'
                e.note='Note '..i;e.favourite=i==3;e.first=i;e.last=i+10
                e.sightings={{mapID=1453,zone='Stormwind City',subzone='Trade District',
                    x=7120+i*3,y=7236,precision='player',first=i,last=i+10}}
                j:Bind(e,'legacy'..i)
            end
            local messages=0
            local book=ns.CreateLedgerJournal(saved)
            book.onContactDiscovered=function() messages=messages+1 end
            assert(L.Count(saved.contacts)==1)
            local e=one(saved.contacts)
            assert(e.favourite and e.first==1 and e.last==14 and #e.sightings==4)
            assert(L.Count(e.migrationEvidence)==4)
            for i=1,4 do
                assert(book:Get(ids[i])==e and book:Reference(refs[i])==e)
                assert(book:Get(saved.aliases['legacy'..i])==e)
                assert(e.note:find('Note '..i,1,true))
            end
            local before=snapshot(saved)
            local reconcile=L.ReconcileReports
            L.ReconcileReports=function() error('Completed migration must not run again') end
            book=ns.CreateLedgerJournal(saved);assert(snapshot(saved)==before,'Migration is idempotent')
            L.ReconcileReports=reconcile
            book.onContactDiscovered=function() messages=messages+1 end
            for i=1,3 do
                assert(book:Encounter({guid='new'..i,npcID=352,name=e.name,sublabel='Gryphon Master',
                    location={mapID=1453,zone='Stormwind City',subzone='Trade District',x=7132,y=7243}},
                    {transport=true},true)==e)
            end
            assert(messages==0 and L.Count(saved.contacts)==1)
        ''')

    def test_transport_migration_keeps_unproven_contacts_separate(self):
        self.lua.execute('''
            saved.transportIdentityMigration=nil
            for i=1,5 do
                local e=j:New('Service');e.npcID=352;e.personal=true
                e.roles.transport={at=1};e.sublabel='Gryphon Master'
                e.sightings={{mapID=1453,zone='Stormwind City',subzone='Trade District',
                    x=7100,y=7200,precision='player'}}
                if i==2 then e.sightings[1].x=7500 end
                if i==3 then e.sightings={} end
                if i==4 then e.personal=nil end
                if i==5 then e.sublabel='Different service' end
            end
            ns.CreateLedgerJournal(saved);assert(L.Count(saved.contacts)==5)
            saved.schema=999;local before=snapshot(saved)
            ns.CreateLedgerJournal(saved);assert(snapshot(saved)==before)
        ''')

    def test_delayed_metadata_and_target_change_retain_original_context(self):
        self.lua.execute('''
            local a=visit(42,'ABC',{item(1001,5,100)})
            targetNPC=55;targetSpawn='DEF';now=now+10
            fire('MERCHANT_UPDATE');flush()
            assert(L.Count(saved.contacts)==1 and one(a.goods).price==100)
            fire('MERCHANT_CLOSED');local b=visit(43,'DEF',{item(1002,1,200)})
            local stamp=one(a.goods).last
            metadata[1001]={name='Delayed recipe',profession='Cooking',classID=9}
            fire('GET_ITEM_INFO_RECEIVED',1001,true);flush()
            assert(one(a.goods).name=='Delayed recipe' and one(a.goods).recipe and one(a.goods).last==stamp)
            assert(one(b.goods).itemID==1002 and one(b.goods).price==200)
        ''')

    def test_close_reopen_timers_never_cross_contacts(self):
        self.lua.execute('''
            filter=2;local a=visit();fire('MERCHANT_UPDATE');fire('MERCHANT_CLOSED')
            local b=visit(43,'DEF',{item(1002,7,77)});flush()
            assert(one(a.goods).itemID==1001 and one(b.goods).itemID==1002)
            local before=snapshot(b);fire('MERCHANT_CLOSED');flush();assert(snapshot(b)==before)
        ''')

    def test_mid_scan_npc_replacement_discards_unattributable_rows(self):
        self.lua.execute('''
            local e=visit();local before=snapshot(e.goods)
            C_MerchantFrame.GetItemInfo=function(i) vendorNPC=43;return item(2002,9,999) end
            fire('MERCHANT_UPDATE');flush()
            assert(snapshot(e.goods)==before and not e.merchantInspection.complete)
            assert(e.merchantInspection.reason:find('identity changed',1,true))
        ''')

    def test_unsupported_item_metadata_cannot_create_a_refresh_loop(self):
        self.lua.execute('''
            local scans=0;local read=C_MerchantFrame.GetItemInfo
            C_MerchantFrame.GetItemInfo=function(i) scans=scans+1;return read(i) end
            C_Item.RequestLoadItemDataByID=function(id) fire('GET_ITEM_INFO_RECEIVED',id,true) end
            visit();for _=1,20 do flush() end
            assert(scans<=4 and #timers==0 and t.pendingCount==0)
        ''')

    def test_stock_states_price_bundle_and_buyback(self):
        self.lua.execute('''
            local e=visit(42,'ABC',{item(1,5,0),item(2,0,1),item(3,-1,2),item(4,nil,3),item(5,-2,4)})
            local found={};for _,v in pairs(e.goods) do found[v.itemID]=v end
            assert(found[1].stock.state=='finite' and found[1].price==0 and found[1].bundle==5)
            assert(found[2].stock.state=='soldout' and found[3].stock.state=='unlimited')
            assert(found[4].stock.state=='unknown' and found[4].stock.quantity==nil and found[5].stock.state=='unknown')
            MerchantFrame.selectedTab=2;items={item(6,7,8)};fire('MERCHANT_UPDATE');flush()
            assert(L.Count(e.goods)==5)
        ''')

    def test_partial_failed_filtered_scans_preserve_positive_history(self):
        self.lua.execute('''
            local e=visit(42,'ABC',{item(1,1,1),item(2,2,2)});local original=one(e.goods).first
            items={item(1,0,1)};filter=2;now=now+10;fire('MERCHANT_UPDATE');flush()
            assert(not e.merchantInspection.complete and L.Count(e.goods)==2)
            for _,v in pairs(e.goods) do assert(not v.notSeen) end
            filter=1;badSlot=1;fire('MERCHANT_UPDATE');flush();assert(not e.merchantInspection.complete)
            for _,v in pairs(e.goods) do assert(not v.notSeen) end
            badSlot=nil;fire('MERCHANT_UPDATE');flush();assert(e.merchantInspection.complete)
            for _,v in pairs(e.goods) do if v.itemID==2 then assert(v.notSeen and v.stock.state=='finite' and v.first==original) end end
            items={};fire('MERCHANT_UPDATE');flush();assert(not e.merchantInspection.complete)
            for _,v in pairs(e.goods) do assert(not v.notSeen) end
        ''')

    def test_bounded_refresh_locations_and_inventory(self):
        self.lua.execute('''
            local e=visit();local first=one(e.goods).first
            for n=1,200 do now=now+1;items[1].numAvailable=n;fire('MERCHANT_UPDATE');flush() end
            assert(L.Count(e.goods)==1 and one(e.goods).first==first and one(e.goods).stock.quantity==200)
            assert(not e.inventoryHistory and #e.sightings==1)
            for n=1,50 do px=n/100;py=0.5;now=now+1;visit() end
            assert(#e.sightings==24 and L.Count(saved.contacts)==1)
        ''')

    def test_distant_sightings_do_not_borrow_player_position(self):
        self.lua.execute('''
            local e=visit();now=now+1;px=0.9;fire('PLAYER_TARGET_CHANGED')
            assert(#e.sightings==2 and e.sightings[1].x==nil and e.sightings[1].precision=='unknown')
            assert(e.sightings[2].x==2500)
            assert(L.Location({mapID=101,x=0,y=0,zone='Zone'},true).x==nil)
            assert(L.Location({mapID=101,x=-1,y=100,zone='Zone'},true).x==nil)
        ''')

    def test_legitimate_npc_position_uses_existing_guarded_sampler_and_original_map(self):
        self.lua.execute('''
            ns.CreatureLocations.Sample=function(unit,guid,expected)
                assert(unit=='npc' or unit=='target');assert(expected==101)
                return {mapID=101,point={x=4200,y=5300,approximate=false}}
            end
            local e=visit();assert(e.sightings[1].precision=='npc' and e.sightings[1].x==4200)
            assert(L.PositionLabel(e.sightings[1]):find('NPC position',1,true))
            assert(R.Validate(reportFor(e)))
            now=now+1;fire('PLAYER_TARGET_CHANGED');assert(e.sightings[1].precision=='npc')
            ns.CreatureLocations.Sample=function() return {mapID=999,point={x=9000,y=9000,approximate=false}} end
            now=now+1;visit();assert(e.sightings[1].mapID==101 and e.sightings[1].x==2500 and e.sightings[1].precision=='player')
        ''')

    def test_trainer_forever_return_order_costs_requirements_and_partial_curriculum(self):
        self.lua.execute('''
            trainer={{name='Sword lesson',status='unavailable',level=20,rank='Rank 2',category='Swords',price=0}}
            function GetTrainerServiceSkillReq() return 'Swords',50,false end
            fire('TRAINER_SHOW');local e=j:Get(t.visits.trainer.contact);local v=one(e.lessons)
            assert(e.roles.trainer and v.name=='Sword lesson' and v.rank=='Rank 2' and v.requiredLevel==20)
            assert(v.availability=='unavailable' and v.price==0 and v.costUnit=='copper')
            assert(v.icon==123)
            assert(not e.trainerInspection.complete and #v.requirements==2 and e.specialities.Swords)
            assert(next(e.goods)==nil)
            trainer[1].level=nil;trainer[1].name='Pet lesson';trainerType=2;fire('TRAINER_UPDATE');flush()
            for _,v in pairs(e.lessons) do if v.name=='Pet lesson' then assert(not v.requiredLevel and v.costUnit=='training points') end end
            C_Trainer.GetTrainerType=function() return secret end
            fire('TRAINER_UPDATE');flush()
            for _,v in pairs(e.lessons) do if v.name=='Pet lesson' then assert(v.costUnit=='unknown') end end
        ''')

    def test_training_icons_survive_unreadable_refresh_without_changing_reports(self):
        self.lua.execute('''
            trainer={{name='Sword lesson',status='available',rank='Rank 2',category='',price=100}}
            fire('TRAINER_SHOW');local e=j:Get(t.visits.trainer.contact)
            local original=GetTrainerServiceInfo
            function GetTrainerServiceInfo(i)
                local name,status,_,level,rank,category=original(i)
                return name,status,nil,level,rank,category
            end
            now=now+10;fire('TRAINER_UPDATE');flush()
            assert(one(e.lessons).icon==123)
            local loaded=ns.CreateLedgerJournal(saved);assert(one(loaded:Get(e.id).lessons).icon==123)
            local report=reportFor(e);assert(report.lessons[1].icon==nil and R.Validate(report))
            local receiver=ns.CreateLedgerJournal({});assert(#import(receiver,report).reports[1].lessons==1)
        ''')

    def test_extended_costs_unknown_metadata_and_restrictions(self):
        self.lua.execute('''
            local v=item(1001,3,0);v.hasExtendedCost=true;v.costs={{quantity=4,link='|Hcurrency:5|h[Token]|h',name='Token'}}
            C_TooltipInfo.GetMerchantItem=function() return {lines={{type=43,leftText='Account restriction'}}} end
            local e=visit(42,'ABC',{v});local g=one(e.goods)
            assert(g.price==0 and g.costsKnown and g.costs[1].id==5 and g.costs[1].quantity==4)
            assert(g.requirements[1]=='Account restriction')
            local stamp=g.costsAt;now=now+10;v.costs[1].quantity=nil;fire('MERCHANT_UPDATE');flush();assert(not e.merchantInspection.complete)
            g=one(e.goods);assert(g.costs[1].quantity==4 and g.costsAt==stamp and not g.costsKnown)
        ''')

    def test_secret_api_errors_and_sublabel_extraction_conservative(self):
        self.lua.execute('''
            sublabel='Maître des arcs';local e=visit();assert(e.sublabel==sublabel)
            sublabel=secret;visit();assert(e.sublabel=='Maître des arcs')
            C_TooltipInfo.GetUnit=function() error('restricted') end
            visit();assert(e.sublabel=='Maître des arcs')
            items[1].price=secret;items[1].numAvailable=secret;items[1].stackCount=secret;items[1].hasExtendedCost=secret
            fire('MERCHANT_UPDATE');flush();local g=one(e.goods)
            assert(g.stock.state=='unknown' or g.stock.state=='finite')
            C_MerchantFrame.GetItemInfo=function() error('restricted') end
            fire('MERCHANT_UPDATE');flush();assert(not e.merchantInspection.complete)
            UnitGUID=function() return secret end;fire('MERCHANT_SHOW');assert(t.visits.merchant==nil)
        ''')

    def test_search_all_fields_any_role_and_intersecting_filters(self):
        self.lua.execute('''
            metadata[1001]={name='Copper recipe',profession='Smithing',classID=9}
            local a=visit();j:Annotate(a.id,'Enter through west door','banker','Weapon skills');j:Favourite(a.id)
            trainer={{name='Sword lesson',status='available',rank='',category='',price=10}};fire('TRAINER_SHOW')
            local b=visit(43,'DEF',{item(1002,2,5,'Thread')})
            for _,query in ipairs({'SYNTHETIC CONTACT','bowyer','synthetic coast','synthetic subzone','copper','smithing','sword','west door','weapon skills','repairs'}) do
                local rows=j:List({query=query});local found=false;for _,r in ipairs(rows) do found=found or r.contact.id==a.id end;assert(found,query)
            end
            local rows=j:List({query='copper',roles={trainer=true,banker=true},zone='Synthetic coast',favourites=true,recipes=true,knowledge='personal'})
            assert(#rows==1 and rows[1].contact==a and rows[1].match.kind=='goods')
            assert(#j:List({query='copper',zone='Elsewhere'})==0)
            assert(#j:List({knowledge='reported'})==0)
            local zones=j:Zones();assert(zones['Synthetic coast']['Synthetic subzone'] and not zones['Undiscovered'])
        ''')

    def test_current_zone_filter_combines_search_with_guarded_zone_lookup(self):
        self.lua.execute('''
            local coast=visit();mapID=102;local hills=visit(43,'DEF')
            mapID=101;repair=false;local merchant=visit(44,'ACD')
            local revision=j.revision;local rows=j:List({query='repair',currentZone=true})
            assert(#rows==1 and rows[1].contact==coast)
            assert(#j:List({currentZone=true})==2)
            mapID=102;rows=j:List({query='REPAIR',currentZone=true,roles={repair=true}})
            assert(#rows==1 and rows[1].contact==hills)
            mapID=nil;GetRealZoneText=function() return 'Synthetic coast' end
            rows=j:List({query='repair',currentZone=true});assert(#rows==1 and rows[1].contact==coast)
            GetRealZoneText=function() return nil end
            assert(#j:List({currentZone=true})==0,'unavailable zone must not expose the whole directory')
            assert(#j:List({query='repair'})==2 and j.revision==revision)
        ''')

    def test_report_roundtrip_private_notes_and_per_fact_provenance(self):
        self.lua.execute('''
            local a=visit();j:Annotate(a.id,'PRIVATE SECRET');local r=reportFor(a)
            assert(r.notes==nil and not assert(R.Encode(r)):find('PRIVATE SECRET',1,true))
            local receiver=ns.CreateLedgerJournal({});now=now+20;local e=import(receiver,r)
            assert(not e.personal and not e.identityOrigin and next(e.goods)==nil and #e.reports==1)
            assert(e.reports[1].goods[1].origin.source==playerName and e.reports[1].goods[1].last==r.goods[1].last)
            assert(e.reports[1].received==now and e.note=='')
            local personally=assert(receiver:Encounter(L.Unit('npc'),{merchant=true},true,e.id))
            assert(personally.personal and next(personally.goods)==nil and personally.roles.merchant and not personally.roles.repair)
            assert(#personally.reports[1].goods==1)
        ''')

    def test_forwarding_deduplication_freshness_and_notes_preservation(self):
        self.lua.execute('''
            local a=visit();local r=reportFor(a);local observed=r.goods[1].last
            now=now+20;local receiver=ns.CreateLedgerJournal({});local e=import(receiver,r)
            receiver:Annotate(e.id,'My private directions');local received=e.reports[1].received
            now=now+100;playerName='Bob';local forwarded=assert(R.Build(receiver,e.id,{report=1}))
            assert(forwarded.created==r.created and forwarded.goods[1].last==observed and forwarded.goods[1].origin.source=='Alice Sunstrider')
            import(receiver,forwarded);assert(#e.reports==1 and e.reports[1].received==received and e.note=='My private directions')
            assert(not saved.points and not receiver.db.points)
        ''')

    def test_reports_cannot_overwrite_personal_prices_or_claims(self):
        self.lua.execute('''
            local e=visit();j:Annotate(e.id,'Private');local personal=snapshot(e.goods);local r=reportFor(e)
            now=now+100;r.created=now;r.goods[1].last=now;r.goods[1].origin.at=now;r.goods[1].price=99999;r.notes='Reported note'
            r.notesOrigin=j:Origin(e,'notes',now,'recorded')
            import(j,r,e.id);assert(snapshot(e.goods)==personal and e.note=='Private' and e.reports[1].notes=='Reported note')
        ''')

    def test_untrusted_reports_reject_schemas_markup_coordinates_types_and_freshness(self):
        self.lua.execute('''
            local e=visit();local base=reportFor(e)
            local function reject(fn) local r=L.Copy(base);fn(r);assert(not R.Validate(r)) end
            reject(function(r) r.version=99 end)
            reject(function(r) r.addonVersion='old' end)
            reject(function(r) r.identity.name='|Hitem:1|hEvil|h' end)
            reject(function(r) r.identity.npcID=1.5 end)
            reject(function(r) r.locations[1].mapID=nil end)
            reject(function(r) r.locations[1].x=10001 end)
            reject(function(r) r.locations[1].x=0;r.locations[1].y=0 end)
            reject(function(r) r.goods[1].stock.quantity=-1 end)
            reject(function(r) r.goods[1].price=0/0 end)
            reject(function(r) r.created=now+1 end)
            reject(function(r) r.goods[1].origin.at=r.goods[1].last+1 end)
            reject(function(r) r.goods[1].execute='print(1)' end)
            reject(function(r) r.goods[3]=r.goods[1] end)
            assert(not R.Decode('return loadstring("oops")()'))
            assert(not R.Decode(assert(R.Encode(base))..'junk'))
            assert(not R.Decode(string.rep('x',R.MAX_BYTES+1)))
            local ticket=assert(R.Prepare(assert(R.Encode(base))));ticket.preview='forged';ticket.goods={}
            local receiver=ns.CreateLedgerJournal({});local incoming=assert(R.Accept(receiver,ticket));assert(#incoming.reports[1].goods==1)
            assert(not R.Accept(receiver,ticket),'consent is one use')
        ''')

    def test_explicit_identity_link_keeps_notes_first_last_and_stable_references(self):
        self.lua.execute('''
            local a=visit();j:Annotate(a.id,'First entrance');local ref=a.reference;local first=one(a.goods).first
            now=now+50;local b=visit(42,'DEF',{item(1001,0,777)});j:Annotate(b.id,'Second floor')
            local merged=assert(j:Link(b.id,a.id));assert(L.Count(saved.contacts)==1 and merged.id==a.id)
            assert(one(merged.goods).price==777 and one(merged.goods).first==first and one(merged.goods).stock.state=='soldout')
            assert(merged.note:find('First entrance',1,true) and merged.note:find('Second floor',1,true))
            assert(j:Reference(ref)==merged and j:Reference(b.reference)==merged and not merged.ambiguous)
            local wrong=visit(50,'AAA');assert(not j:Link(wrong.id,merged.id))
        ''')

    def test_schema_reload_state_and_future_schema_preserved(self):
        self.lua.execute('''
            local e=visit();j:Annotate(e.id,'Saved access note');saved.state.query='bowyer';saved.state.selected=e.id
            local loaded=ns.CreateLedgerJournal(saved);assert(loaded:Get(e.id).note=='Saved access note' and loaded.state.query=='bowyer')
            saved.schema=99;local before=snapshot(saved);local future=ns.CreateLedgerJournal(saved)
            assert(future.readOnly and not future:Manual({name='No'}));assert(snapshot(saved)==before)
        ''')

    def test_unreadable_refresh_retains_last_quote_without_fabricating_freshness(self):
        self.lua.execute('''
            local e=visit();local g=one(e.goods);local priceAt=g.priceAt;now=now+20
            items[1].price=nil;items[1].stackCount=nil;items[1].numAvailable=nil
            fire('MERCHANT_UPDATE');flush();g=one(e.goods)
            assert(L.Count(e.goods)==1 and g.price==250 and g.priceAt==priceAt and g.last==now)
            assert(g.bundle==5 and g.stock.state=='unknown' and g.stockAt==now and not e.merchantInspection.complete)
            assert(R.Validate(reportFor(e)))
        ''')

    def test_reported_sublabel_is_not_promoted_by_missing_personal_metadata(self):
        self.lua.execute('''
            local a=visit();local report=reportFor(a);local receiver=ns.CreateLedgerJournal({});local e=import(receiver,report)
            C_TooltipInfo.GetUnit=function() return nil end
            receiver:Encounter(L.Unit('npc'),{merchant=true},true,e.id)
            assert(e.personal and receiver:Sublabel(e):find('(reported)',1,true))
            local localReport=assert(R.Build(receiver,e.id))
            assert(localReport.identity.sublabel=='' and #localReport.goods==0 and not localReport.roles.repair)
        ''')

    def test_fact_receipt_dates_are_separate_and_forwarding_does_not_refresh_them(self):
        self.lua.execute('''
            local a=visit();local report=reportFor(a);local receiver=ns.CreateLedgerJournal({})
            now=now+10;local e=import(receiver,report);local g=e.reports[1].goods[1]
            local key=L.Key(g.origin.source,g.origin.key);local received=e.reports[1].factReceipts[key].received
            now=now+10;import(receiver,report);assert(e.reports[1].factReceipts[key].received==received)
            now=now+10;items[1].numAvailable=0;fire('MERCHANT_UPDATE');flush();report=reportFor(a)
            now=now+10;import(receiver,report);assert(e.reports[1].factReceipts[key].received==now)
            assert(e.reports[1].goods[1].last==now-10 and e.reports[1].received==received)
        ''')

    def test_report_limits_fail_before_mutation_and_keep_known_offerings(self):
        self.lua.execute('''
            local e=visit();local r=reportFor(e);local receiver=ns.CreateLedgerJournal({})
            R.MAX_STORED_REPORTS=0;local ticket=assert(R.Prepare(assert(R.Encode(r))))
            local before=snapshot(receiver.db);assert(not R.Accept(receiver,ticket));assert(snapshot(receiver.db)==before)
            R.MAX_STORED_REPORTS=512
            local incoming=assert(R.Accept(receiver,ticket));r.goods={};import(receiver,r)
            assert(#incoming.reports[1].goods==1,'a partial report does not remove positive history')
            L.MAX_GOODS=1;items={item(1,1,1),item(2,2,2)};fire('MERCHANT_UPDATE');flush()
            assert(L.Count(e.goods)==1 and not e.merchantInspection.complete)
        ''')

    def test_large_contact_shares_all_offerings_in_bounded_parts(self):
        self.lua.execute('''
            trainer={{name='Lesson 1',status='available',rank='',category='Mage',price=100}}
            fire('TRAINER_SHOW')
            local e=j:Get(t.visits.trainer.contact);local template=one(e.lessons)
            for i=2,170 do
                local lesson=L.Copy(template);lesson.name='Lesson '..i
                lesson.key=L.LessonKey(lesson)
                lesson.origin=L.Copy(template.origin);lesson.origin.key=lesson.key
                e.lessons[lesson.key]=lesson
            end
            local receiver=ns.CreateLedgerJournal({});local target
            for part=1,3 do
                local report,err,total,index=R.Build(j,e.id,{part=part})
                assert(report,err);assert(total==3 and index==part)
                assert(#report.lessons==(part<3 and 80 or 10))
                local wire=assert(R.Encode(report));assert(#wire<=R.MAX_BYTES)
                local ticket=assert(R.Prepare(wire))
                target=assert(R.Accept(receiver,ticket,target and target.id or nil))
                assert(#target.reports==1 and #target.reports[1].lessons==math.min(part*80,170))
            end
            assert(#target.reports[1].lessons==170)
            local first=assert(R.Build(j,e.id,{part=1}))
            local ticket=assert(R.Prepare(assert(R.Encode(first))))
            local summary=assert(R.Preflight(receiver,ticket,target.id))
            assert(summary:find('already known',1,true))
            assert(R.Accept(receiver,ticket,target.id) and #target.reports[1].lessons==170)
            local forwarded,err,total,index=R.Build(receiver,target.id,{report=1,part=3})
            assert(forwarded,err);assert(total==3 and index==3 and #forwarded.lessons==10)
            assert(forwarded.identity.origin.source==first.identity.origin.source)
        ''')

    def test_report_parts_stop_atomically_at_contact_offering_limit(self):
        self.lua.execute('''
            local e=visit();local template=one(e.goods)
            for i=2,L.MAX_GOODS do
                local good=L.Copy(template);good.itemID=1000+i;good.name='Synthetic good '..i
                good.key=L.GoodKey(good);good.origin=L.Copy(template.origin);good.origin.key=good.key
                e.goods[good.key]=good
            end
            local receiver=ns.CreateLedgerJournal({});local target
            for part=1,7 do
                local report,err,total,index=R.Build(j,e.id,{part=part})
                assert(report,err);assert(total==7 and index==part)
                target=assert(R.Accept(receiver,assert(R.Prepare(assert(R.Encode(report)))),target and target.id or nil))
            end
            assert(#target.reports==1 and #target.reports[1].goods==L.MAX_GOODS)
            local extra=assert(R.Build(j,e.id,{part=7}))
            local good=extra.goods[1];good.itemID=999999;good.name='Unseen extra'
            good.key=L.GoodKey(good);good.origin.key=good.key
            local ticket=assert(R.Prepare(assert(R.Encode(extra))))
            local before=snapshot(receiver.db)
            local summary,canAccept=R.Preflight(receiver,ticket,target.id)
            assert(not canAccept and summary:find('limit',1,true))
            assert(not R.Accept(receiver,ticket,target.id) and snapshot(receiver.db)==before)
        ''')

    def test_native_service_events_and_manual_annotations_are_distinct(self):
        self.lua.execute('''
            fire('BANKFRAME_OPENED');local e=one(saved.contacts);assert(e.roles.banker and next(e.goods)==nil)
            fire('CONFIRM_BINDER');fire('PET_STABLE_SHOW');fire('AUCTION_HOUSE_SHOW');fire('TAXIMAP_OPENED')
            assert(e.roles.innkeeper and e.roles.stable and e.roles.auctioneer and e.roles.transport)
            assert(L.Count(saved.contacts)==1 and next(e.lessons)==nil)
            local manual=assert(j:Manual({name='Manual helper',sublabel='Local title'}))
            j:Annotate(manual.id,'Use upstairs entrance','trainer','Weapons')
            assert(not manual.personal and manual.recorded and not manual.roles.trainer and manual.manualRoles.trainer)
            assert(j:Sublabel(manual):find('(manual)',1,true))
        ''')

    def test_conflicting_subtitle_and_partial_unit_data_are_not_guessed(self):
        self.lua.execute('''
            C_TooltipInfo.GetUnit=function() return {lines={{type=2,leftText=name},{type=48,leftText='Humanoid'},{type=47,leftText='Level 10'}}} end
            local e=visit();assert(e.sublabel=='')
            C_TooltipInfo.GetUnit=function() return {lines={{type=2,leftText=name},{type=0,leftText='A'},{type=0,leftText='B'},{type=47,leftText='Level 10'}}} end
            visit();assert(e.sublabel=='')
            assert(L.Count(saved.contacts)==1)
        ''')


class LedgerUITests(unittest.TestCase):
    def setUp(self):
        self.lua = new_ledger(ui=True)
        self.lua.execute('''
        MenuResponse={Refresh=2}
        function openMenu(button)
            local function node()
                local n={children={}}
                function n:CreateButton(label,fn) local child=node();child.label=label;child.action=fn;self.children[#self.children+1]=child;return child end
                function n:CreateCheckbox(label,selected,fn) local child=self:CreateButton(label,fn);child.selected=selected;return child end
                function n:SetResponse(response) self.response=response end
                function n:CreateDivider() end
                function n:CreateTitle(label) self.title=label end
                function n:SetScrollMode() end
                return n
            end
            MenuUtil={CreateContextMenu=function(_,build) menu=node();build(nil,menu) end}
            click(button);return menu
        end
        function choose(menu,label)
            for _,item in ipairs(menu.children) do if item.label==label then if item.action then item.action() end;return item end end
            error('Menu missing '..label)
        end
    ''')

    def test_training_sort_menu_orders_all_sources_and_remembers_choice(self):
        self.lua.execute('''
            local e=visit()
            trainer={
                {name='Zulu',status='available',level=10,rank='',category='',price=100},
                {name='alpha',status='unavailable',level=20,rank='',category='',price=100},
                {name='Unknown level',status='unknown',rank='',category='',price=100},
                {name='Beta',status='used',level=10,rank='Rank 10',category='',price=100},
                {name='Beta',status='used',level=10,rank='Rank 2',category='',price=100},
            }
            fire('TRAINER_SHOW');flush();c:Select(e.id)
            local report=reportFor(e);local lesson=L.Copy(report.lessons[1])
            lesson.name='Reported first';lesson.rank='';lesson.requiredLevel=5;lesson.key=L.LessonKey(lesson)
            lesson.origin.source='Another observer';report.lessons={lesson};report.goods={}
            import(j,report,e.id);flush()
            for key,v in pairs(e.lessons) do if v.name=='alpha' then c.state.focus=key end end
            c:Catalogue('training');local p=c.panels.catalogue;local area=p.read
            local function order(expected)
                local _,blocks=c:Details(e,true,'training');local index=0
                for _,block in ipairs(blocks) do if block.heading then
                    index=index+1;assert(block.text:find(expected[index],1,true),block.text)
                end end
                assert(index==#expected)
            end
            assert(p.sort:IsShown() and c.state.trainingSort=='level')
            order({'Reported first','(Rank 2)','(Rank 10)','Zulu','alpha','Unknown level'})
            area:SetVerticalScroll(50);choose(openMenu(p.sort),'Name')
            assert(c.state.trainingSort=='name' and area:GetVerticalScroll()==0)
            order({'alpha','(Rank 2)','(Rank 10)','Reported first','Unknown level','Zulu'})
            c:Refresh();order({'alpha','(Rank 2)','(Rank 10)','Reported first','Unknown level','Zulu'})
            c:Catalogue('goods');assert(not p.sort:IsShown())
            c:Catalogue('training');assert(p.sort:IsShown())
            choose(openMenu(p.sort),'Name (selected)')
            local loaded=ns.CreateLedgerJournal(saved)
            local book=ns.CreateLedgerBook(loaded,t,ns.CreateFieldbookShell())
            assert(book.state.trainingSort=='name')
            choose(openMenu(p.sort),'Level');assert(c.state.trainingSort=='level')
            order({'Reported first','(Rank 2)','(Rank 10)','Zulu','alpha','Unknown level'})
        ''')

    def test_training_rich_rows_icons_colours_and_historical_cost_units(self):
        self.lua.execute(r'''
            local e=visit()
            UnitLevel=function() return 20 end
            trainer={{name='Sword lesson',status='available',level=20,rank='Rank 2',category='Swords',price=12345}}
            fire('TRAINER_SHOW');flush();c:Select(e.id);c:Catalogue('training')
            local area=c.panels.catalogue.read;local lesson=one(e.lessons)
            local before=snapshot(e)
            local text,blocks=c:Details(e,true,'training')
            assert(blocks[2].heading and blocks[2].text:find('|T123:18:18:0:0|t ',1,true))
            assert(text:find('|cff80e680Sword lesson|r',1,true) and text:find('(Rank 2)',1,true))
            assert(text:find('|cffffd100Required: Level 20|r',1,true))
            assert(select(2,text:gsub('Required:', ''))==1)
            lesson.requirements={'Required level: 20','Greater Stamina (Rank 2)'}
            assert(c:Details(e,true,'training'):find('|cffffd100Required: Level 20, Greater Stamina (Rank 2)|r',1,true))
            lesson.requirements={'Required level: 20'}
            assert(text:find('|cff80cfffCategory: Swords|r',1,true))
            assert(text:find('1|cffffd100g|r 23|cffc7c7cfs|r 45|cffb87333c|r',1,true))
            assert(not text:find('First:',1,true) and not text:find('Last: '..L.Date(lesson.last),1,true))
            assert(text:match('Price: ([^\n]+)')=='1|cffffd100g|r 23|cffc7c7cfs|r 45|cffb87333c|r')
            assert(c:Details(e,false,'training'):match('Price: ([^\n]+)')=='1g 23s 45c')
            local view=area.headingViews[2]
            assert(view.icon.texture==123 and view.icon:GetWidth()==40 and view.icon:IsShown())
            local tooltipLink
            C_Spell={GetSpellLink=function(identifier)
                assert(identifier=='Sword lesson(Rank 2)');return '|Hspell:1234|h[Sword lesson]|h'
            end}
            GameTooltip.SetHyperlink=function(self,link) tooltipLink=link;self.lines={} end
            view.iconHover.scripts.OnEnter(view.iconHover);assert(tooltipLink:find('spell:1234',1,true))
            view.iconHover.scripts.OnLeave();assert(not GameTooltip:IsShown())
            tooltipLink=nil;view.hover.scripts.OnEnter(view.hover);assert(tooltipLink:find('spell:1234',1,true))
            view.hover.scripts.OnLeave();assert(not GameTooltip:IsShown())
            C_Spell.GetSpellLink=function() return nil end
            view.iconHover.scripts.OnEnter(view.iconHover);assert(GameTooltip:GetText()=='Sword lesson (Rank 2)')
            view.iconHover.scripts.OnLeave()

            assert(area.blocks[3].point[2]==46 and area.blocks[3]:GetWidth()==182)
            assert(not area.blocks[2]:GetText():find('|T',1,true))
            assert(snapshot(e)==before,'Display must not change observations')
            for status,color in pairs({unavailable='ff80e680',used='ff999999',unknown='ff80e680'}) do
                lesson.availability=status
                assert(c:Details(e,true,'training'):find('|c'..color..'Sword lesson|r',1,true))
            end
            lesson.costUnit='training points';lesson.price=7
            text=c:Details(e,true,'training');assert(text:find('7 training points',1,true) and not text:find('7c',1,true))
            lesson.costUnit='unknown';assert(c:Details(e,true,'training'):find('7 (unit unknown)',1,true))
            lesson.icon=nil
            C_Spell={GetSpellTexture=function(identifier) assert(identifier=='Sword lesson(Rank 2)');return 456 end}
            c:Refresh();assert(view.icon.texture==456 and lesson.icon==nil)
            C_Spell.GetSpellTexture=function(identifier) return identifier=='Sword lesson' and 789 or nil end
            c:Refresh();assert(view.icon.texture==789)
            C_Spell.GetSpellTexture=function() return secret end
            c:Refresh();assert(view.icon.texture==134400)
            C_Spell=nil;c:Refresh();assert(view.icon.texture==134400)
            c:Catalogue('goods');assert(view.icon.texture==123)
            c:Catalogue('training');assert(view.icon.texture==134400)
            lesson.name='Bad |Hitem:999|hname|h';lesson.rank='|cffff0000Rank'
            text=c:Details(e,true,'training')
            assert(not text:find('|Hitem:999|h',1,true) and not text:find('|cffff0000Rank',1,true))
        ''')

    def test_training_overflow_scrolls_from_text_headings_icons_and_viewport(self):
        self.lua.execute('''
            local e=visit()
            for i=1,20 do trainer[i]={name='Lesson '..i,status='available',level=i,rank='',category='',price=100} end
            fire('TRAINER_SHOW');flush();c:Select(e.id);c:Catalogue('training')
            local area=c.panels.catalogue.read;local body=area.blocks[1].parent
            local view=area.headingViews[2];local mapZoom=m.map.zoom
            assert(body:GetHeight()>area:GetHeight() and area.ScrollBar:IsShown() and area.mouseWheel)
            for _,surface in ipairs({area,body,view,view.hover,view.iconHover}) do
                area:SetVerticalScroll(0);surface.scripts.OnMouseWheel(surface,-1)
                assert(area:GetVerticalScroll()==32)
                surface.scripts.OnMouseWheel(surface,-100000)
                assert(area:GetVerticalScroll()==body:GetHeight()-area:GetHeight())
                surface.scripts.OnMouseWheel(surface,100000);assert(area:GetVerticalScroll()==0)
            end
            assert(m.map.zoom==mapZoom)
            area:SetVerticalScroll(64);c:Refresh();assert(area:GetVerticalScroll()==64)
            area:SetContact(nil,false,'training')
            assert(area:GetVerticalScroll()==0 and not area.ScrollBar:IsShown() and not area.mouseWheel)
            body.scripts.OnMouseWheel(body,-1);assert(area:GetVerticalScroll()==0)
        ''')

    def test_training_requires_personal_or_reported_lessons(self):
        self.lua.execute('''
            assert(m.detailButtons.training.enabled==false and m.detailButtons.training:IsShown())
            c:Catalogue('training');assert(c.panel==nil)
            local e=visit();flush();c:Select(e.id)
            assert(m.detailButtons.goods.enabled==true and m.detailButtons.training.enabled==false)
            assert(m.detailButtons.goods:IsShown() and m.detailButtons.training:IsShown())
            assert(m.detailButtons.goods.point[2]==42 and m.detailButtons.goods:GetWidth()==122)
            c:Catalogue('training');assert(c.panel==nil)
            trainer={{name='Sword lesson',status='available',rank='',category='',price=10}}
            fire('TRAINER_SHOW');flush()
            assert(m.detailButtons.training.enabled==true)
            assert(m.detailButtons.goods:IsShown() and m.detailButtons.training:IsShown())
            assert(m.detailButtons.goods.point[2]==42 and m.detailButtons.training.point[2]==170)
            assert(m.detailButtons.goods:GetWidth()==122 and m.detailButtons.training:GetWidth()==122)
            local goods=e.goods;e.goods={};j:Changed(e.id);flush();c:Refresh()
            assert(m.detailButtons.goods:IsShown() and not m.detailButtons.goods.enabled and m.detailButtons.training:IsShown())
            assert(m.detailButtons.training.point[2]==170 and m.detailButtons.training:GetWidth()==122)
            e.goods=goods;j:Changed(e.id);flush();c:Refresh()
            assert(m.detailButtons.goods:GetWidth()==122 and m.detailButtons.training:GetWidth()==122)
            c:Catalogue('training');assert(c.panel==c.panels.catalogue and c.panel.kind=='training')
            c:ClosePanel()
            local report=reportFor(e);assert(j:Remove(e.id));flush()
            local reported=import(j,report);flush();c:Select(reported.id)
            assert(next(reported.lessons)==nil and #reported.reports>0)
            assert(m.detailButtons.training.enabled==true)
            c:Catalogue('training');assert(c.panel==c.panels.catalogue)
            c:ClosePanel();local empty=assert(j:Manual({name='Empty contact'}));flush();c:Select(empty.id)
            assert(m.detailButtons.training.enabled==false and m.detailButtons.training:IsShown())
        ''')

    def test_known_goods_requires_personal_or_reported_offerings(self):
        self.lua.execute('''
            assert(m.detailButtons.goods.enabled==false and m.detailButtons.goods:IsShown())
            c:Catalogue('goods');assert(c.panel==nil)
            local empty=assert(j:Manual({name='Empty merchant',role='merchant'}));flush();c:Select(empty.id)
            assert(m.detailButtons.goods.enabled==false and m.detailButtons.goods:IsShown())
            c:Catalogue('goods');assert(c.panel==nil)
            local stocked=visit();flush();c:Select(stocked.id)
            assert(m.detailButtons.goods.enabled==true)
            c:Catalogue('goods');assert(c.panel==c.panels.catalogue)
            c:ClosePanel()
            local report=reportFor(stocked)
            assert(j:Remove(stocked.id));flush()
            local reported=import(j,report);flush();c:Select(reported.id)
            assert(next(reported.goods)==nil and #reported.reports>0)
            assert(m.detailButtons.goods.enabled==true)
            c:Catalogue('goods');assert(c.panel==c.panels.catalogue)
            c:ClosePanel();c:Select(empty.id)
            assert(m.detailButtons.goods.enabled==false and m.detailButtons.goods:IsShown())
        ''')

    def test_current_zone_checkbox_tracks_travel_and_excludes_fixed_zone_filters(self):
        self.lua.execute('''
            local coast=visit();mapID=102;local hills=visit(43,'DEF')
            mapID=101;repair=false;visit(44,'ACD');flush()
            m.search:SetText('repair');assert(#c.rows==2)
            local current=choose(openMenu(m.filters),'Current Zone')
            assert(current.selected() and current.response==MenuResponse.Refresh and m.filters.afbSelected)
            assert(#c.rows==1 and c.rows[1].contact==coast and c.state.query=='repair')
            assert(ns.CreateLedgerJournal(saved).state.currentZone==true)
            mapID=102;fire('ZONE_CHANGED_NEW_AREA');assert(#c.rows==1 and c.rows[1].contact==hills)
            choose(openMenu(m.filters),'Current Zone');assert(#c.rows==2 and not m.filters.afbSelected)
            local locations=choose(openMenu(m.filters),'Zone / location')
            choose(choose(locations,'Synthetic coast'),'Synthetic subzone')
            assert(c.state.zone=='Synthetic coast' and c.state.subzone=='Synthetic subzone')
            choose(openMenu(m.filters),'Current Zone')
            assert(c.state.currentZone and not c.state.zone and not c.state.subzone and c.rows[1].contact==hills)
            locations=choose(openMenu(m.filters),'Zone / location')
            choose(choose(locations,'Synthetic coast'),'All of Synthetic coast')
            assert(not c.state.currentZone and #c.rows==1 and c.rows[1].contact==coast)
            choose(openMenu(m.filters),'Current Zone')
            locations=choose(openMenu(m.filters),'Zone / location');choose(locations,'All zones')
            assert(not c.state.currentZone and #c.rows==2)
            choose(openMenu(m.filters),'Current Zone');shell:ShowSection('other')
            mapID=101;fire('ZONE_CHANGED_NEW_AREA');shell:ShowSection('merchants')
            assert(c.state.currentZone and #c.rows==1 and c.rows[1].contact==coast)
            choose(openMenu(m.filters),'Clear')
            assert(not c.state.currentZone and c.state.query=='' and #c.rows==3 and not m.filters.afbSelected)
        ''')

    def test_widget_selection_item_reason_reset_and_empty_states(self):
        self.lua.execute('''
            assert(m.empty:GetText():find('begins empty',1,true))
            local e=visit();flush();assert(m.name:GetText()==e.name and m.sublabel:GetText()=='<Bowyer>')
            assert(m.rows[1].sublabel:GetText()=='<Bowyer>')
            m.search:SetText('synthetic goods');assert(c.rows[1].match and m.rows[1].reason:GetText():find('Offers:',1,true))
            click(m.rows[1]);assert(c.state.detail=='goods' and c.state.focus)
            m.search:SetText('not in journal');assert(m.empty:GetText():find('No matching',1,true))
            choose(openMenu(m.filters),'Clear');assert(c.state.query=='' and #c.rows==1 and c.state.selected==e.id)
        ''')

    def test_map_geometry_exact_independent_state_and_tooltip(self):
        self.lua.execute('''
            local e=visit();flush();c:Select(e.id)
            assert(m.map.point[1]=='TOP' and m.map.point[2]==m and m.map.point[3]=='TOPLEFT' and m.map.point[4]==632 and m.map.point[5]==-205)
            local adapter={Get=function() end,List=function() return {} end,Layer=function() return true end,WeatherText=function() return '' end}
            local atlas=ns.CreateAtlasMap(CreateFrame('Frame'),adapter,function() end,function() end);atlas:Render(101)
            assert(atlas:GetWidth()==m.map:GetWidth() and atlas:GetHeight()==m.map:GetHeight())
            local pin=m.map.pins[1];assert(pin:IsShown());pin.scripts.OnEnter(pin)
            local text=snapshot(GameTooltip.lines);assert(text:find('Bowyer',1,true) and text:find('Encountered near',1,true) and text:find('25.00',1,true))
            m.map.zoom=2;m.map.panX=20;m.map.panY=20;c:Refresh();assert(atlas.zoom==1 and m.map.zoom==2)
            assert(m.map.pins~=atlas.pins and not AzerothFieldbookAtlasDB)
        ''')

    def test_unknown_location_and_reported_pin_labels(self):
        self.lua.execute('''
            px=0;py=0;local e=visit();flush();c:Select(e.id);assert(#m.map.pins==0 and m.location:GetText():find('coordinates not recorded for this sighting',1,true))
            px=0.25;py=0.75;now=now+1;visit();flush();local r=reportFor(e)
            local receiver=ns.CreateLedgerJournal({});local reported=import(receiver,r)
            local map=ns.CreateLedgerMap(CreateFrame('Frame'),receiver,function() return reported.id,1 end,function() end)
            map:Render();local pin=map.pins[1];pin.scripts.OnEnter(pin)
            assert(snapshot(GameTooltip.lines):find('Reported by',1,true))
            C_Map.GetMapArtLayers=function() return nil end;m.map:Invalidate();c:Refresh();assert(not m.map.available)
            assert(m.name:GetText()==e.name)
        ''')

    def test_section_switch_editor_draft_scroll_and_background_capture(self):
        self.lua.execute('''
            local e=visit();flush();c:Select(e.id);m.search:SetText('Bowyer');c:Notes()
            local p=c.panels.notes;p.edit:SetText('Unfinished access note');m.details:SetVerticalScroll(20)
            local width,height=shell:GetFrame():GetWidth(),shell:GetFrame():GetHeight()
            shell:ShowSection('other');items[1].numAvailable=0;fire('MERCHANT_UPDATE');flush()
            assert(shell.active=='other' and one(e.goods).stock.state=='soldout')
            shell:ShowSection('merchants');assert(m.search:GetText()=='Bowyer' and p.edit:GetText()=='Unfinished access note')
            assert(c.state.selected==e.id and m.details:GetVerticalScroll()==20)
            assert(shell:GetFrame():GetWidth()==width and shell:GetFrame():GetHeight()==height)
        ''')

    def test_panels_bounded_reports_preview_opt_in_and_no_frame_growth(self):
        self.lua.execute('''
            local e=visit();flush();c:Select(e.id);j:Annotate(e.id,'Secret access notes');flush()
            c:Reports();local p=c.panels.reports;assert(not p.notes:GetChecked())
            assert(p:GetWidth()==260 and p:GetHeight()==615 and m.map.point[5]==-205)
            p.data:SetText(assert(R.Encode(reportFor(e))))
            c:ClosePanel();c:Notes();c:ClosePanel();c:Catalogue();c:ClosePanel();c:Manual();c:ClosePanel();c:Identity();c:ClosePanel()
            local count=#objects
            for _=1,20 do c:Reports();c:ClosePanel();c:Notes();c:ClosePanel();c:Catalogue();c:ClosePanel();c:Manual();c:ClosePanel();c:Identity();c:ClosePanel() end
            assert(#objects==count)
        ''')

    def test_bounded_list_sort_favourites_and_stable_scroll_during_updates(self):
        self.lua.execute('''
            for i=1,20 do now=now+1;name=string.format('Contact %02d',i);visit(i,'ABC') end
            flush();c.state.contactScroll=924;c:Refresh();local first=m.rows[1].id
            fire('MERCHANT_UPDATE');flush();assert(c.state.offset==12 and m.rows[1].id==first)
            choose(openMenu(m.sort),'Last encounter');assert(c.state.offset==0 and m.rows[1].name:GetText()=='Contact 20')
            click(m.rows[1]);click(m.favourite);flush();local item=choose(openMenu(m.filters),'Favourites');assert(item.selected() and item.response==MenuResponse.Refresh)
            assert(#c.rows==1)
        ''')

    def test_runtime_loading_and_exact_map_anchor_reference(self):
        toc = (ROOT / 'AzerothFieldbook.toc').read_text(encoding='utf-8')
        self.assertIn('AzerothFieldbookLedgerDB', toc)
        self.assertIn('LedgerTracking.lua', toc)
        atlas = (ROOT / 'AtlasBook.lua').read_text(encoding='utf-8')
        ledger = (ROOT / 'LedgerBook.lua').read_text(encoding='utf-8')
        anchor = 'm.map:SetPoint("TOP",m,"TOPLEFT",632,-205)'
        self.assertIn(anchor, atlas)
        self.assertIn(anchor, ledger)

    def test_report_controls_require_current_preview_and_explicit_note_choice(self):
        self.lua.execute('''
            local e=visit();flush();c:Select(e.id);j:Annotate(e.id,'PRIVATE');flush();c:Reports()
            local p=c.panels.reports;click(p.prepare)
            assert(not p.data:GetText():find('PRIVATE',1,true) and not p.accept.enabled)
            p.notes:SetChecked(true);click(p.prepare);assert(p.data:GetText():find('PRIVATE',1,true))
            click(p.review);assert(p.accept.enabled and p.ticket)
            p.data:SetText('malformed');assert(not p.ticket and not p.accept.enabled)
            p.data:SetText(assert(R.Encode(reportFor(e))));click(p.review);click(p.accept)
            assert(c.panel==nil and #j:Get(c.state.selected).reports==1)
        ''')

    def test_large_report_screen_steps_through_every_part(self):
        self.lua.execute('''
            local e=visit();local template=one(e.goods)
            for i=2,170 do
                local good=L.Copy(template);good.itemID=1000+i;good.name='Synthetic good '..i
                good.key=L.GoodKey(good);good.origin=L.Copy(template.origin);good.origin.key=good.key
                e.goods[good.key]=good
            end
            flush();c:Select(e.id);c:Reports();local p=c.panels.reports
            for index=1,3 do
                click(p.prepare)
                local report=assert(R.Decode(p.data:GetText()))
                assert(report.part==index and report.parts==3)
                assert(p.preview.text:GetText():find('Part '..index..' of 3',1,true))
                assert(p.part==index and #report.goods==(index<3 and 80 or 10))
            end
            click(p.prepare);assert(p.part==1 and assert(R.Decode(p.data:GetText())).part==1)
            p.goods:SetChecked(false);p.goods.scripts.OnClick(p.goods)
            assert(p.part==0 and p.data:GetText()=='' and p.prepare:GetText()=='Prepare')
            click(p.prepare);assert(not assert(R.Decode(p.data:GetText())).parts)
        ''')

    def test_viewport_inherits_scale_once_and_never_changes_shell_size(self):
        self.lua.execute('''
            local root=shell:GetFrame();local width,height=root:GetWidth(),root:GetHeight()
            for _,size in ipairs({{1920,1080},{1280,720},{1024,768}}) do
                UIParent:SetSize(size[1],size[2])
                for _,scale in ipairs({0.5,0.75,1,1.25,1.5}) do
                    root:SetScale(scale);c:Refresh()
                    assert(m.map:GetEffectiveScale()==root:GetEffectiveScale())
                    assert(m.map.point[4]==632 and m.map.point[5]==-205)
                    assert(root:GetWidth()==width and root:GetHeight()==height)
                end
            end
        ''')

    def test_service_details_and_selected_sighting_remain_coherent(self):
        self.lua.execute('''
            local e=visit();flush();c:Select(e.id);assert(c.state.detail=='goods')
            now=now+1;px=0.8;visit();flush();c:Sighting(2);local key=c.state.sightingKey
            now=now+1;px=0.5;visit();flush();assert(c.state.sightingKey==key and c.state.sighting==3)
            m.search:SetText('not found');assert(m.status==nil and c.state.selected==e.id);c:Reset()
            vendorNPC=50;spawn='DEF';fire('BANKFRAME_OPENED');flush();local bank=j:Get(saved.aliases[UnitGUID('npc')]);c:Select(bank.id)
            assert(c.state.detail=='services' and not m.details.text:GetText():find('No goods',1,true))
            trainer={{name='Sword lesson',status='available',rank='',category='',price=10}}
            vendorNPC=51;spawn='AAA';fire('TRAINER_SHOW');flush();c:Select(t.visits.trainer.contact)
            assert(c.state.detail=='training' and not m.details.text:GetText():find('Observed Training',1,true))
            c:Catalogue('training');assert(c.panels.catalogue.read.text:GetText():find('Observed Training',1,true))
            assert(L.Date(0)=='Not recorded')
        ''')


if __name__ == '__main__':
    unittest.main()
