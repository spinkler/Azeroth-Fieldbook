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
                assert(p.border.texture:find('GatheringDot.tga',1,true) and p.texture.texture==p.border.texture)
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
