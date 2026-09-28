"""Synthetic Treasure contracts; these fixtures never populate a live journal."""
from ui_test_harness import new_ui_client
from atlas_test_harness import ENV

TREASURE_MODULES = [
    'TreasureJournal.lua', 'TreasureTracking.lua', 'TreasureReports.lua',
    'TreasureMap.lua', 'TreasureEditors.lua', 'TreasureBook.lua',
]


def new_treasure(ui=False):
    lua = new_ui_client([
        'Scrollbars.lua', 'CreatureLocations.lua', 'FieldbookShell.lua',
        'AtlasJournal.lua', 'AtlasUI.lua', 'AtlasMap.lua', *TREASURE_MODULES,
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
        timers={};C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
        function flush() local list=timers;timers={};for _,fn in ipairs(list) do fn() end end
        function GetTime() return now end
        bags={};loot={};metadata={};NUM_BAG_SLOTS=4
        C_Container={GetContainerNumSlots=function(b) return #(bags[b] or {}) end,
            GetContainerItemInfo=function(b,s) return bags[b] and bags[b][s] end}
        ItemLocation={CreateFromBagAndSlot=function(_,bag,slot) return {bag=bag,slot=slot} end}
        C_Item={GetItemGUID=function(loc) return bags[loc.bag][loc.slot].guid end,
            GetItemInfo=function(id) return metadata[id] end,GetItemNameByID=function(id) return metadata[id] end,
            RequestLoadItemDataByID=function(id) requestedID=id end,GetItemIconByID=function() return 123 end}
        function IsFishingLoot() return fishing or false end
        function GetNumLootItems() return #loot end
        function GetLootSourceInfo(slot) return unpack(loot[slot].sources) end
        function GetLootSlotLink(slot) return loot[slot].itemID and '|Hitem:'..loot[slot].itemID..'|h[Fixture]|h' end
        function GetLootSlotInfo(slot) return 123,loot[slot].name,loot[slot].quantity end
        function lootrow(id,n,guid) return {itemID=id,name='Observed item '..id,quantity=n,sources={guid,n}} end
        function bagitem(id,guid) return {itemID=id,itemName='Container '..id,hasLoot=true,guid=guid} end
        T=ns.Treasure;R=ns.TreasureReports;saved={};j=ns.CreateTreasureJournal(saved);t=ns.CreateTreasureTracking(j)
        shell=ns.CreateFieldbookShell();shell:RegisterSection('other',{title='Other',build=function() end})
        c=ns.CreateTreasureBook(j,t,shell)
        function record(name,kindID,form,context)
            form=form or 'world';context=context or (form=='world' and 'world' or 'acquired')
            return assert(j:Record(kindID,{name=name or 'Synthetic chest',form=form,category='container'},
                {context=context,location=T.CurrentLocation(context),facts={sighted=true},capture='missing',items={}},'manual'))
        end
        function inspect(id,items,capture,method)
            local e=j:Get(id);local context=e.form=='world' and 'world' or 'opened'
            return j:Record(id,nil,{context=context,location=T.CurrentLocation(context),facts={inspected=true},capture=capture or 'partial',items=items or {}},method)
        end
        function carried()
            bags[0]={bagitem(1001,'Item-exact-1')};fire('BAG_UPDATE_DELAYED');flush();return j:FindItem(1001)
        end
        function openitem()
            loot={lootrow(2001,3,'Item-exact-1')};fire('LOOT_READY');fire('LOOT_OPENED',false,true)
        end
        function import(recipient,report,selected)
            return R.Accept(recipient,assert(R.Prepare(report)),selected)
        end
    ''')
    if ui:
        lua.execute("shell:ShowSection('treasure');m=c.main")
    return lua
