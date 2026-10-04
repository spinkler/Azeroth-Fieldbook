"""Synthetic Forever merchant/trainer contracts. Not proof of native rendering."""
from ui_test_harness import new_ui_client
from atlas_test_harness import ENV

LEDGER_MODULES = [
    'LedgerJournal.lua', 'LedgerTracking.lua', 'LedgerReports.lua',
    'LedgerMap.lua', 'LedgerBook.lua',
]


def new_ledger(ui=False):
    lua = new_ui_client([
        'Scrollbars.lua', 'CreatureLocations.lua', 'FieldbookShell.lua',
        'AtlasJournal.lua', 'AtlasUI.lua', 'AtlasMap.lua', *LEDGER_MODULES,
    ])
    lua.execute(ENV)
    lua.execute(r'''
        local create=CreateFrame
        function CreateFrame(...)
            local f=create(...);f.events={}
            function f:RegisterEvent(event) self.events[event]=true end
            function f:GetScript(event) return self.scripts[event] end
            function f:Enable() self.enabled=true end
            function f:Disable() self.enabled=false end
            return f
        end
        function fire(event,...)
            for _,f in ipairs(objects) do if f.events and f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
        end
        timers={};C_Timer={After=function(delay,fn) timers[#timers+1]=fn end}
        function flush() local pending=timers;timers={};for _,fn in ipairs(pending) do fn() end end
        Enum.TooltipDataLineType={None=0,Blank=1,UnitName=2,UnitLevel=47,UnitType=48,UsageRequirement=43,ErrorLine=41,DisabledLine=42}
        Enum.ItemClass={Recipe=9};Enum.TrainerType={Pet=2,Class=0}
        name='Synthetic contact';sublabel='Bowyer';targetNPC=42;vendorNPC=42;spawn='ABC';targetSpawn='ABC'
        function UnitGUID(unit)
            if unit=='player' then return 'Player-1-1' end
            local id=targetNPC; if unit=='npc' then id=vendorNPC end
            return id and 'Creature-0-1-2-3-'..id..'-'..(unit=='npc' and spawn or targetSpawn)
        end
        function UnitName(unit) if unit=='player' then return playerName end;return name end
        function UnitIsPlayer(unit) return unit=='player' end
        C_TooltipInfo={GetUnit=function(unit)
            return {lines={{type=2,leftText=name},{type=0,leftText=sublabel},{type=47,leftText='Level 10'}}}
        end}
        items={};metadata={};trainer={};filter=1;LE_LOOT_FILTER_ALL=1;repair=true
        MerchantFrame={selectedTab=1}
        C_MerchantFrame={GetItemInfo=function(i) if badSlot==i then return end;return items[i] end}
        function GetMerchantNumItems() return numItems or #items end
        function GetMerchantItemID(i) return items[i] and items[i].id end
        function GetMerchantItemLink(i) return items[i] and items[i].id and '|Hitem:'..items[i].id..'|h[Item]|h' end
        function GetMerchantFilter() return filter end
        function CanMerchantRepair() return repair end
        function GetMerchantItemCostInfo(i) return #(items[i].costs or {}) end
        function GetMerchantItemCostItem(i,n) local c=items[i].costs[n];if c then return 123,c.quantity,c.link,c.name end end
        C_Item={GetItemInfo=function(id)
            local m=metadata[id];if m then return m.name,nil,1,1,1,'Recipe',m.profession,nil,nil,123,nil,m.classID or 0 end
        end,RequestLoadItemDataByID=function() end}
        function GetNumTrainerServices() return #trainer end
        function GetTrainerServiceInfo(i)
            local v=trainer[i];return v.name,v.status,123,v.level,v.rank,v.category
        end
        function GetTrainerServiceCost(i) return trainer[i].price end
        function GetTrainerServiceNumAbilityReq() return 0 end
        C_Trainer={GetTrainerType=function() return trainerType or 0 end}
        function item(id,stock,price,name)
            return {id=id,name=name or 'Synthetic goods',numAvailable=stock,price=price,stackCount=5,
                isPurchasable=true,isUsable=true,hasExtendedCost=false,texture=123}
        end
        L=ns.Ledger;R=ns.LedgerReports;saved={};j=ns.CreateLedgerJournal(saved);t=ns.CreateLedgerTracking(j)
        shell=ns.CreateFieldbookShell();shell:RegisterSection('other',{title='Other',build=function() end})
        chatEnabled=true;c=ns.CreateLedgerBook(j,t,shell,{GetCreatureAnnouncement=function() return chatEnabled end})
        function visit(id,guid,goods)
            vendorNPC=id or 42;targetNPC=vendorNPC;spawn=guid or 'ABC';targetSpawn=spawn;items=goods or {item(1001,3,250)}
            fire('MERCHANT_SHOW');return j:Get(t.visits.merchant.contact)
        end
        function one(store) local _,v=next(store);return v end
        function import(recipient,report,selected)
            local ticket=assert(R.Prepare(assert(R.Encode(report))))
            return assert(R.Accept(recipient,ticket,selected))
        end
        function reportFor(e) return assert(R.Build(j,e.id)) end
    ''')
    if ui:
        lua.execute("shell:ShowSection('merchants');m=c.main")
    return lua
