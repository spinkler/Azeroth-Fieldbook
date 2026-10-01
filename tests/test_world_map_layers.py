"""Native filter integration and recorded merchant/node layers (widget host)."""
import unittest
from ui_test_harness import new_ui_client
from ledger_test_harness import new_ledger
from test_gathering import client


MENU = r'''
    calls=0
    MenuResponse={Refresh=2}
    Menu={ModifyMenu=function(tag,fn)
        assert(tag=='MENU_WORLD_MAP_TRACKING');calls=calls+1;modifier=fn
    end}
    entries={};order={};root={}
    function root:CreateDivider() end
    function root:CreateTitle(title) assert(title=='Azeroth Fieldbook') end
    function root:CreateCheckbox(label,selected,toggle)
        order[#order+1]=label
        local entry={selected=selected}
        function entry.toggle()
            inMenuCallback=true
            local result=toggle()
            inMenuCallback=false
            assert(result==nil,'Native checkbox default must handle the response')
        end
        function entry:SetEnabled(on) self.enabled=on end
        function entry:SetSelectionIgnored() self.selectionIgnored=true end
        entries[label]=entry;return entry
    end
    function nextFrame()
        local work={}
        for _,frame in ipairs(objects) do
            if frame.scripts and frame.scripts.OnUpdate and frame:IsShown() then
                work[#work+1]={frame,frame.scripts.OnUpdate}
            end
        end
        for _,row in ipairs(work) do row[2](row[1],0) end
    end
'''


class WorldMapLayerTests(unittest.TestCase):
    def test_menu_can_load_after_layers_without_duplicate_hooks(self):
        lua=new_ui_client()
        lua.execute("ns.RegisterWorldMapLayer('Points',function() return true end,function() end)")
        lua.execute(MENU)
        lua.execute(r'''
            for _,frame in ipairs(objects) do
                if frame.scripts and frame.scripts.OnEvent then
                    frame.scripts.OnEvent(frame,'ADDON_LOADED','Blizzard_Menu')
                    frame.scripts.OnEvent(frame,'ADDON_LOADED','Blizzard_WorldMap')
                end
            end
            assert(calls==1);modifier(nil,root);assert(entries.Points.selected())
        ''')

    def test_native_menu_registers_once_with_stable_order_and_read_only_guard(self):
        lua=new_ui_client()
        lua.execute(MENU)
        lua.execute(r'''
            local values={};local writable=true
            for _,name in ipairs({'Nodes','Merchants','Zones','Labels','Points'}) do
                local key=name
                ns.RegisterWorldMapLayer(key,function() return values[key]==true end,
                    function(on) values[key]=on end,function() return writable end)
            end
            assert(calls==1,'One native hook even when journals register separately')
            modifier(nil,root)
            assert(table.concat(order,',')=='Points,Labels,Zones,Merchants,Nodes')
            for _,entry in pairs(entries) do assert(entry.selectionIgnored) end
            entries.Nodes.toggle();assert(entries.Nodes.selected() and not entries.Merchants.selected())
            writable=false;entries.Nodes.toggle();assert(entries.Nodes.selected())
            modifier(nil,root);assert(entries.Nodes.enabled==false)
            ns.RegisterWorldMapLayer('Nodes',function() return false end,function() error('new journal') end)
            assert(calls==1);modifier(nil,root);assert(not entries.Nodes.selected(),'Rebinding replaces stale journals')
        ''')

    def test_clicks_defer_and_coalesce_redraws_and_drop_replaced_journals(self):
        lua=new_ui_client()
        lua.execute(MENU)
        lua.execute(r'''
            local value,draws=false,0
            ns.RegisterWorldMapLayer('Nodes',function() return value end,function(on) value=on end,nil,function()
                assert(not inMenuCallback,'No map rendering on the menu response stack')
                draws=draws+1
            end)
            modifier(nil,root)
            entries.Nodes.toggle();assert(value and draws==0,'Preference and check state change immediately')
            entries.Nodes.toggle();entries.Nodes.toggle();nextFrame()
            assert(value and draws==1,'One redraw for rapid clicks using the final preference')
            nextFrame();assert(draws==1,'Worker sleeps once the queue is drained')
            entries.Nodes.toggle()
            local previous=entries.Nodes
            ns.RegisterWorldMapLayer('Nodes',function() return true end,function() error('stale menu') end)
            nextFrame();assert(draws==1,'Do not redraw a replaced journal')
            previous.toggle();assert(not value,'An already-open menu cannot change the old journal')
        ''')

    def test_nodes_use_existing_world_setting_without_changing_minimap_or_evidence(self):
        lua=client(ui=True)
        lua.execute(MENU)
        lua.execute(r'''
            WorldMapFrame=CreateFrame('Frame');WorldMapFrame:Show()
            local canvas=CreateFrame('Frame',nil,WorldMapFrame);canvas:SetSize(1000,600)
            function WorldMapFrame:GetCanvas() return canvas end
            function WorldMapFrame:GetMapID() return 37 end
            journal:RecordInteraction('herb','Silverleaf',{mapID=37,name='Elwynn',point={x=2000,y=3000,seenAt=10}},'Elwynn',10)
            journal:SetShowNodesOn('minimap',true)
            local pins=ns.CreateGatheringMapPins(journal)
            local refresh=pins.RefreshWorld
            function pins:RefreshWorld() assert(not inMenuCallback);return refresh(self) end
            modifier(nil,root);assert(not entries.Nodes.selected())
            entries.Nodes.toggle()
            assert(journal:ShowNodesOn('worldMap') and journal:ShowNodesOn('minimap'))
            assert(#pins.worldPins==0,'No frames created while handling the click');nextFrame()
            assert(pins.worldPins[1]:IsShown())
            entries.Nodes.toggle();nextFrame();assert(not pins.worldPins[1]:IsShown())
            assert(journal:ShowNodesOn('minimap'))
            journal.readOnly=true;entries.Nodes.toggle();assert(not journal:ShowNodesOn('worldMap'))
        ''')

    def test_merchants_use_recorded_locations_zoom_cache_and_map_lifecycle(self):
        lua=new_ledger()
        lua.execute(MENU)
        lua.execute(r'''
            local merchant=visit()
            local trainer=j:New('Trainer');trainer.roles.trainer=true
            local unknown=j:New('Unlocated merchant');unknown.roles.merchant=true
            local original=#merchant.sightings
            WorldMapFrame=CreateFrame('Frame');WorldMapFrame:Show()
            local canvas=CreateFrame('Frame',nil,WorldMapFrame);canvas:SetSize(1000,600)
            local id,scale=101,1
            function WorldMapFrame:GetCanvas() return canvas end
            function WorldMapFrame:GetMapID() return id end
            function WorldMapFrame:GetCanvasScale() return scale end
            function WorldMapFrame:GetPinFrameLevelsManager() return {GetValidFrameLevel=function() return 2023 end} end
            local pins=ns.CreateLedgerWorldPins(j)
            local refresh=pins.Refresh
            function pins:Refresh() assert(not inMenuCallback);return refresh(self) end
            modifier(nil,root);assert(not entries.Merchants.selected())
            entries.Merchants.toggle()
            assert(#pins.pins==0,'No merchant frames created while handling the click');nextFrame()
            assert(entries.Merchants.selected() and #pins.pins==1)
            local pin=pins.pins[1];assert(pin.row.entry==merchant and pin:IsShown() and pin:GetFrameLevel()==2023)
            pin.scripts.OnEnter(pin);assert(GameTooltip:IsOwned(pin))
            local count=#objects;scale=2;pins:Refresh()
            assert(#objects==count and pin:GetScale()==0.5 and #merchant.sightings==original)
            id=102;pins:Refresh();assert(not pin:IsShown())
            id=101;pins:Refresh();assert(pin:IsShown())
            WorldMapFrame:Hide();WorldMapFrame.scripts.OnHide(WorldMapFrame)
            assert(not pin:IsShown() and not pins.frame:IsShown())
            WorldMapFrame:Show();WorldMapFrame.scripts.OnShow(WorldMapFrame);assert(pin:IsShown())
            entries.Merchants.toggle();nextFrame();assert(not pin:IsShown())
            assert(ns.CreateLedgerJournal(saved).state.showMerchantsOnWorldMap==false)
            j.readOnly=true;entries.Merchants.toggle();assert(not entries.Merchants.selected())
        ''')

    def test_reported_merchants_remain_labelled_as_reported(self):
        lua=new_ledger()
        lua.execute(MENU)
        lua.execute(r'''
            local merchant=visit();local recipient=ns.CreateLedgerJournal({})
            import(recipient,reportFor(merchant))
            WorldMapFrame=CreateFrame('Frame');WorldMapFrame:Show()
            local canvas=CreateFrame('Frame',nil,WorldMapFrame);canvas:SetSize(1000,600)
            function WorldMapFrame:GetCanvas() return canvas end
            function WorldMapFrame:GetMapID() return 101 end
            local pins=ns.CreateLedgerWorldPins(recipient)
            modifier(nil,root);entries.Merchants.toggle();nextFrame()
            assert(#pins.pins==1 and pins.pins[1].row.point.reported)
            pins.pins[1].scripts.OnEnter(pins.pins[1])
            local found=false
            for _,line in ipairs(GameTooltip.lines) do if line.text:find('Reported by',1,true) then found=true end end
            assert(found)
        ''')


if __name__ == '__main__':
    unittest.main()
