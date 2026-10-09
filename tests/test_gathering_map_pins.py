"""Recorded-node display settings and world/minimap projection lifecycle."""
import unittest
from test_gathering import client


class GatheringMapPinsTests(unittest.TestCase):
    def setUp(self):
        self.lua=client(ui=True)
        self.lua.execute('''
            WorldMapFrame=CreateFrame('Frame');canvas=CreateFrame('Frame',nil,WorldMapFrame)
            canvas:SetSize(1000,600);shownMap=37
            function WorldMapFrame:GetCanvas() return canvas end
            function WorldMapFrame:GetMapID() return shownMap end
            -- Forever 1.60.1.70009: WorldMapMixin:OnLoad registers exploration
            -- and fog ABOVE DEFAULT, then AREA_POI above both. Merely being a
            -- child above the canvas (or using DEFAULT) doesn't clear the art.
            -- See GATHERING_MAP_PINS.md for the pinned client-source evidence.
            mapLevels={PIN_FRAME_LEVEL_DEFAULT=2000,PIN_FRAME_LEVEL_MAP_EXPLORATION=2002,
                PIN_FRAME_LEVEL_FOG_OF_WAR=2006,PIN_FRAME_LEVEL_AREA_POI=2023}
            mapLevelManager={GetValidFrameLevel=function(_,kind)
                return mapLevels[kind] or mapLevels.PIN_FRAME_LEVEL_DEFAULT end}
            function WorldMapFrame:GetPinFrameLevelsManager() return mapLevelManager end
            exploration=CreateFrame('Frame',nil,canvas);exploration:EnableMouse(false)
            exploration:SetFrameLevel(mapLevels.PIN_FRAME_LEVEL_MAP_EXPLORATION)
            fog=CreateFrame('Frame',nil,canvas);fog:EnableMouse(false)
            fog:SetFrameLevel(mapLevels.PIN_FRAME_LEVEL_FOG_OF_WAR)
            Minimap=CreateFrame('Frame');Minimap:SetSize(200,200)
            radius=100;rotating='0';facing=0
            C_Minimap={GetViewRadius=function() return radius end}
            function GetCVar() return rotating end
            function GetPlayerFacing() return facing end
            journal:RecordInteraction('herb','Silverleaf',
                {mapID=37,name='Elwynn',point={x=2100,y=3000,seenAt=10}},'Elwynn',10)
            journal:Discover('mineral','Copper Vein',10,'Elwynn',{mapID=37,name='Elwynn'})
            pins=gathering.mapPins
            function pinTick(dt)
                -- WoW only dispatches OnUpdate to effectively visible frames.
                if pins.frame:IsVisible() and pins.frame.scripts.OnUpdate then
                    pins.frame.scripts.OnUpdate(pins.frame,dt or 0.1)
                end
            end
        ''')

    def test_inactive_pools_release_once_and_reactivate_at_existing_limits(self):
        self.lua.execute('''
            shell:ShowSection('gathering');shell:GetFrame():Hide()
            -- Fill the retained pools without testing journal capture limits here.
            local points=journal.entries['herb:silverleaf'].locations[37].points
            for i=1,600 do points[i]={x=2100+i%5,y=3000,seenAt=i} end
            journal.revision=journal.revision+1
            journal:SetShowNodesOn('worldMap',true);journal:SetShowNodesOn('minimap',true)
            pinTick();assert(#pins.worldPins==512 and #pins.miniPins==128)
            local hideCalls={world=0,mini=0}
            for view,pool in pairs({world=pins.worldPins,mini=pins.miniPins}) do
                for _,p in ipairs(pool) do
                    local hide=p.Hide
                    p.Hide=function(self) hideCalls[view]=hideCalls[view]+1;hide(self) end
                end
            end
            local weak=setmetatable({pins.worldPins[1].node,pins.miniPins[1].node},{__mode='v'})
            pins.worldPins[1].scripts.OnEnter(pins.worldPins[1])
            WorldMapFrame:Hide();journal:SetShowNodesOn('minimap',false)
            shell:GetFrame():Hide();assert(not shell:GetFrame():IsVisible())
            pinTick()
            assert(hideCalls.world==512 and hideCalls.mini==128)
            assert(not GameTooltip:IsShown())
            for _,pool in ipairs({pins.worldPins,pins.miniPins}) do
                for _,p in ipairs(pool) do assert(not p:IsShown() and p.node==nil) end
            end
            collectgarbage('collect');assert(not weak[1] and not weak[2],'inactive caches retained nodes')
            for _=1,100 do pinTick() end
            print(string.format('Inactive pins over 100 ticks: world=%d minimap=%d extra Hide calls',
                hideCalls.world-512,hideCalls.mini-128))
            assert(hideCalls.world==512 and hideCalls.mini==128,'unchanged inactive pools were traversed again')
            -- Changes while inactive must appear on the first active tick.
            for k in pairs(points) do points[k]=nil end
            points[1]={x=2200,y=3000,seenAt=700};journal.revision=journal.revision+1
            WorldMapFrame:Show();journal:SetShowNodesOn('minimap',true);pinTick()
            assert(pins.worldPins[1]:IsVisible() and pins.worldPins[1].point[4]==220)
            assert(pins.miniPins[1]:IsVisible() and math.abs(pins.miniPins[1].point[4]-80)<0.001)
            assert(#pins.worldPins==512 and #pins.miniPins==128,'native pools must be reused')
            assert(not pins.worldPins[2]:IsShown() and not pins.miniPins[2]:IsShown())
            journal:SetShowNodesOn('worldMap',false);Minimap:Hide();pinTick()
            local world,mini=hideCalls.world,hideCalls.mini
            for _=1,10 do pinTick() end
            assert(hideCalls.world==world and hideCalls.mini==mini)
            journal:SetShowNodesOn('worldMap',true);Minimap:Show();pinTick()
            assert(pins.worldPins[1]:IsVisible() and pins.miniPins[1]:IsVisible())
        ''')

    def test_controller_keeps_active_minimap_moving_with_fieldbook_closed(self):
        self.lua.execute('''
            shell:ShowSection('gathering');shell:GetFrame():Hide()
            journal:SetShowNodesOn('minimap',true);WorldMapFrame:Hide();shell:GetFrame():Hide()
            assert(not shell:GetFrame():IsVisible() and pins.frame:IsVisible())
            positionReads=0;pinTick(0.05);assert(positionReads==0)
            pinTick(0.05);assert(positionReads==1)
            local p=pins.miniPins[1];assert(p:IsVisible() and math.abs(p.point[4]-40)<0.001)
            rotating='1';facing=math.pi/2;pinTick()
            assert(math.abs(p.point[4])<0.001 and math.abs(p.point[5]+40)<0.001)
            radius=50;pinTick();assert(math.abs(p.point[5]+80)<0.001)
            px=0.21;pinTick();assert(p.point[4]==0 and p.point[5]==0)
            assert(positionReads==4,'enabled minimap must read position on each controller tick')
            -- Invalid API state releases once, then recovers without a UI event.
            local hides=0;local hide=p.Hide
            p.Hide=function(self) hides=hides+1;hide(self) end
            px=secret;pinTick();assert(not p:IsShown() and p.node==nil and hides==1)
            for _=1,10 do pinTick() end
            assert(hides==1)
            px=0.2;radius=100;pinTick();assert(p:IsVisible())
            mapID=38;pinTick();assert(not p:IsShown())
            mapID=37;pinTick();assert(p:IsVisible())
            journal:RecordInteraction('herb','Peacebloom',
                {mapID=37,name='Elwynn',point={x=2200,y=3000,seenAt=20}},'Elwynn',20)
            pinTick();assert(pins.miniPins[2]:IsVisible(),'active revision changes refresh the node cache')
        ''')

    def test_world_invalid_geometry_releases_once_then_recovers(self):
        self.lua.execute('''
            journal:SetShowNodesOn('worldMap',true);pinTick()
            local p=pins.worldPins[1];local hides=0;local hide=p.Hide
            p.Hide=function(self) hides=hides+1;hide(self) end
            canvas:SetWidth(0);pinTick();assert(hides==1 and not p:IsShown() and p.node==nil)
            for _=1,10 do pinTick() end
            assert(hides==1)
            canvas:SetSize(500,300);pinTick();assert(p:IsVisible() and p.point[4]==105)
            shownMap=secret;pinTick();assert(hides==2)
            pinTick();assert(hides==2)
            shownMap=37;pinTick();assert(p:IsVisible())
        ''')

    def test_shared_cache_revision_does_not_mask_other_display_cleanup(self):
        self.lua.execute('''
            journal:SetShowNodesOn('worldMap',true);journal:SetShowNodesOn('minimap',true)
            local original=pairs;local scans=0
            pairs=function(t)
                if t==journal.entries then scans=scans+1 end
                return original(t)
            end
            pinTick();assert(scans==1,'both maps share one node list')
            for _=1,10 do pinTick() end
            assert(scans==1,'active displays reuse unchanged node data')
            local p=pins.miniPins[1];local hides=0;local hide=p.Hide
            p.Hide=function(self) hides=hides+1;hide(self) end
            journal.revision=journal.revision+1;journal:SetShowNodesOn('minimap',false)
            pinTick()
            assert(scans==2 and hides==1 and p.node==nil and not p:IsShown())
            assert(pins.worldPins[1]:IsVisible(),'world map remains active')
            for _=1,10 do pinTick() end
            assert(scans==2 and hides==1)
            journal:SetShowNodesOn('minimap',true);pinTick()
            -- Changing the setting touches the journal; world and minimap
            -- still share the single list rebuilt for that revision.
            assert(scans==3 and p:IsVisible(),'reactivation shares the rebuilt world map list')
            pairs=original
        ''')

    def test_world_dots_draw_above_explored_terrain_and_fog(self):
        self.lua.execute('''
            journal:SetShowNodesOn('worldMap',true);pins:Refresh()
            local p=pins.worldPins[1]
            p.scripts.OnEnter(p)
            assert(GameTooltip:IsOwned(p) and GameTooltip:IsShown(),
                'mouse-transparent map art leaves the tooltip working even below the art')
            assert(p:GetFrameLevel()>exploration:GetFrameLevel(),
                'dot must draw above explored terrain, not just above the canvas')
            assert(p:GetFrameLevel()>fog:GetFrameLevel(),'dot must draw above fog overlays')
            assert(p:GetFrameLevel()==mapLevels.PIN_FRAME_LEVEL_AREA_POI)
            -- Use the manager's current value; don't hard-code 2023 or assume
            -- other providers cannot insert layers later in the session.
            mapLevels.PIN_FRAME_LEVEL_AREA_POI=2100
            fog:SetFrameLevel(2090);pins:Refresh()
            assert(p:GetFrameLevel()==2100 and p:GetFrameLevel()>fog:GetFrameLevel())
        ''')

    def test_independent_settings_persist_and_buttons_work_without_entries(self):
        self.lua.execute('''
            assert(not journal:ShowNodesOn('worldMap') and not journal:ShowNodesOn('minimap'))
            pins:Refresh();assert(#pins.worldPins==0 and #pins.miniPins==0)
            shell:ShowSection('gathering')
            local check=gathering.frame.mapOptions.worldMap
            check:SetChecked(true);check.scripts.OnClick(check)
            assert(journal:ShowNodesOn('worldMap') and not journal:ShowNodesOn('minimap'))
            local reloaded=ns.CreateGatheringJournal(AzerothFieldbookGatheringDB)
            assert(reloaded:ShowNodesOn('worldMap') and not reloaded:ShowNodesOn('minimap'))
            assert(#pins.worldPins==1 and #pins.miniPins==0,'hover-only zones have no pin')
            check:SetChecked(false);check.scripts.OnClick(check)
            assert(not pins.worldPins[1]:IsShown())
        ''')

    def test_world_map_switch_resize_hide_and_new_record(self):
        self.lua.execute('''
            journal:SetShowNodesOn('worldMap',true);pins:Refresh()
            local p=pins.worldPins[1]
            assert(p.point[4]==210 and p.point[5]==-180)
            canvas:SetSize(500,300);pins:Refresh();assert(p.point[4]==105)
            shownMap=38;pins:Refresh();assert(not p:IsShown())
            shownMap=37;pins:Refresh();assert(p:IsShown())
            p.scripts.OnEnter(p);assert(GameTooltip:IsOwned(p) and GameTooltip:IsShown())
            WorldMapFrame:Hide();pins:Refresh();assert(not p:IsShown() and not GameTooltip:IsShown())
            WorldMapFrame:Show()
            journal:RecordInteraction('herb','Peacebloom',
                {mapID=37,name='Elwynn',point={x=2200,y=3000,seenAt=20}},'Elwynn',20)
            pins:Refresh();assert(#pins.worldPins==2 and pins.worldPins[2]:IsShown())
        ''')

    def test_map_markers_use_visible_compendium_dot_textures(self):
        self.lua.execute('''
            journal:SetShowNodesOn('worldMap',true)
            journal:SetShowNodesOn('minimap',true);pins:Refresh()
            for _,p in ipairs({pins.worldPins[1],pins.miniPins[1]}) do
                assert(p:GetWidth()==6 and p:GetHeight()==6)
                assert(p.border.texture:find('GatheringDot.png',1,true) and p.texture.texture==p.border.texture)
                assert(not rawget(p.border,'mask') and not rawget(p.texture,'mask'),'no scroll-frame mask dependency')
                assert(p.border.vertexColor[4]==1 and p.texture.vertexColor[4]==1)
                assert(p.texture.vertexColor[1]==0.3 and p.texture.vertexColor[2]==1
                    and p.texture.vertexColor[3]==0.35,'same green as Compendium herb dot')
            end
            assert(pins.worldPins[1]:GetFrameLevel()>canvas:GetFrameLevel())
            journal:RecordInteraction('mineral','Copper Vein',
                {mapID=37,name='Elwynn',point={x=2100,y=3000,seenAt=20}},'Elwynn',20)
            pins:Refresh()
            for _,p in ipairs(pins.worldPins) do
                if p.node.entry.kind=='mineral' then
                    assert(p.texture.vertexColor[1]==1 and p.texture.vertexColor[2]==0.78)
                end
            end
        ''')

    def test_world_dots_keep_size_and_position_on_scaled_terrain(self):
        self.lua.execute('''
            zoom=0.125;pinLevel=500
            function WorldMapFrame:GetCanvasScale() return zoom end
            local manager={GetValidFrameLevel=function(_,kind)
                assert(kind=='PIN_FRAME_LEVEL_AREA_POI');return pinLevel end}
            function WorldMapFrame:GetPinFrameLevelsManager() return manager end
            journal:SetShowNodesOn('worldMap',true)
            for _,value in ipairs({0.125,0.25,0.5,1,2}) do
                zoom=value;canvas:SetScale(zoom);pins:Refresh()
                local p=pins.worldPins[1]
                assert(math.abs(p:GetScale()*zoom*p:GetWidth()-6)<0.0001,
                    'dot stays six pixels across in map-window units')
                assert(math.abs(p.point[4]*p:GetScale()-210)<0.0001)
                assert(math.abs(p.point[5]*p:GetScale()+180)<0.0001)
                assert(p:GetFrameLevel()==500,'native pin layer is used')
            end
        ''')

    def test_minimap_movement_rotation_zoom_and_unreadable_position(self):
        self.lua.execute('''
            journal:SetShowNodesOn('minimap',true);pins:Refresh()
            local p=pins.miniPins[1]
            assert(math.abs(p.point[4]-40)<0.001 and p.point[5]==0)
            rotating='1';facing=math.pi/2;pins:Refresh()
            assert(math.abs(p.point[4])<0.001 and math.abs(p.point[5]+40)<0.001)
            radius=50;pins:Refresh();assert(math.abs(p.point[5]+80)<0.001)
            radius=20;pins:Refresh();assert(not p:IsShown(),'out of range is hidden')
            radius=100;px=0.21;pins:Refresh();assert(p:IsShown() and p.point[4]==0 and p.point[5]==0)
            px=secret;pins:Refresh();assert(not p:IsShown())
            px=0.2;C_Minimap.GetViewRadius=nil;pins:Refresh();assert(not p:IsShown())
            C_Minimap.GetViewRadius=function() return 100 end
            mapID=38;pins:Refresh();assert(not p:IsShown())
            mapID=37;pins:Refresh();assert(p:IsShown())
            journal:SetShowNodesOn('minimap',false);pins:Refresh();assert(not p:IsShown())
        ''')


if __name__=='__main__':
    unittest.main()
