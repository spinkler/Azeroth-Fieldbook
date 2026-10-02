"""Shared terrain preference, cross-screen updates and compact Atlas controls."""
import unittest
from atlas_test_harness import new_atlas
from ui_test_harness import ROOT, new_ui_client


class MapBrightnessTests(unittest.TestCase):
    def test_migration_validation_and_reload(self):
        lua = new_ui_client()
        lua.execute('''
            local B=ns.MapBrightness
            local db={locationMapBrightness=.35}
            local atlas={settings={mapBrightness=.5}}
            B:Initialize(db,atlas,{mapBrightness=.65})
            assert(B:Get()==.5 and db.mapBrightness==.5)
            assert(atlas.settings.mapBrightness==.5 and db.locationMapBrightness==.35)
            B:Set(.7);B:Initialize(db,atlas);assert(B:Get()==.7)
            for _,bad in ipairs({secret,0/0,-1,2,'50'}) do B:Set(bad);assert(B:Get()==.7) end
            ns.InitializationBlocked=true;B:Set(.4);assert(db.mapBrightness==.7)
            ns.InitializationBlocked=nil
            B:Initialize({locationMapBrightness=.35},{settings={mapBrightness=0/0}})
            assert(B:Get()==.35)
            B:Initialize({},{settings=5},{mapBrightness=.65});assert(B:Get()==.65)
            B:Initialize({});assert(B:Get()==.8)
        ''')

    def test_all_journal_maps_and_both_location_windows_synchronize(self):
        lua = new_atlas(ui=True)
        for name in ['LocationGeometry.lua', 'BestiaryJournal.lua', 'CreatureLocationsWindow.lua', 'GatheringLocationsWindow.lua',
                     'AnglingJournal.lua', 'AnglingMap.lua', 'LedgerJournal.lua', 'LedgerMap.lua',
                     'TreasureJournal.lua', 'TreasureMap.lua', 'LoreJournal.lua', 'LoreMap.lua']:
            lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute('''
            db={};j.state.mapBrightness=.5
            ns.MapBrightness:Initialize(db,saved)
            assert(db.mapBrightness==.5)
            local bj=ns.CreateBestiaryJournal(db,function() return 42 end)
            local gj=ns.CreateGatheringJournal({mapBrightness=.65})
            local e=bj:Ensure(42,false,'Synthetic creature')
            ns.CreatureLocations.Record(e,{mapID=101,name='Synthetic coast',width=4000,height=3000,
                point={x=1000,y=1000,seenAt=now,approximate=true}})
            local revision=bj.revision
            local bw=ns.CreateCreatureLocationsWindow(bj);bw:Open(42)
            local gw=ns.CreateGatheringLocationsWindow(gj,function() return m end);gw:Open('missing')
            local b,g=bw:GetFrame(),gw:GetFrame()
            local function empty() end
            local angling=ns.CreateAnglingMap(m,ns.CreateAnglingJournal({}),empty,function() return {} end)
            local ledger=ns.CreateLedgerMap(m,ns.CreateLedgerJournal({}),function() return nil end,empty)
            local treasure=ns.CreateTreasureMap(m,ns.CreateTreasureJournal({}),{mapID=101},empty)
            local lore=ns.CreateLoreMap(m,ns.CreateLoreJournal({}),function() return nil,nil,101 end,empty,empty)
            local maps={m.map,angling,ledger,treasure,lore}
            angling:Render(101);ledger:Render();treasure:Render();lore:Render()
            ledger:Hide()
            local evidence=snapshot(saved.subzones)
            m.map.brightness.scripts.OnValueChanged(m.map.brightness,.4)
            for _,map in ipairs(maps) do
                assert(map.brightness.valueLabel:GetText()=='40%')
                assert(map.brightness.panel.point[1]=='BOTTOMLEFT' and map.brightness.panel.point[2]==map)
                assert(map.brightness.panel.point[5]<map.playerCoordinates.point[5])
                local count=0
                for _,texture in ipairs(objects) do
                    if texture.parent==map.canvas and type(texture.texture)=='number' and texture:IsShown() then
                        assert(texture.vertexColor[1]==.4);count=count+1
                    end
                end
                if map==m.map or map==angling then assert(count==12) end
            end
            assert(b.brightnessValue:GetText()=='40%' and g.brightnessValue:GetText()=='40%')
            assert(bj:GetLocationMapBrightness()==.4 and gj:GetLocationMapBrightness()==.4)
            local tiles=0
            for _,texture in ipairs(objects) do
                if texture.parent==b.map and type(texture.texture)=='number' and texture:IsShown() then
                    assert(texture.vertexColor[1]==.4);tiles=tiles+1
                end
            end
            assert(tiles==12,'The already-open Locations terrain updates immediately')
            b.brightness.scripts.OnValueChanged(b.brightness,.65)
            assert(m.map.brightness.valueLabel:GetText()=='65%' and g.brightnessValue:GetText()=='65%')
            gj:SetLocationMapBrightness(.3)
            assert(db.mapBrightness==.3 and lore.brightness.valueLabel:GetText()=='30%')
            assert(bj.revision==revision and snapshot(saved.subzones)==evidence)
            ns.MapBrightness:Initialize(db,{settings={mapBrightness=.9}})
            assert(db.mapBrightness==.3 and m.map.brightness.valueLabel:GetText()=='30%')
        ''')

    def test_legacy_fill_has_its_own_compact_header_control(self):
        lua = new_atlas(ui=True)
        lua.execute('''
            assert(m.legacySubzones.parent==m.subzoneControls)
            assert(m.legacySubzones:GetWidth()==20 and m.legacySubzones:GetHeight()==20)
            assert(m.legacySubzones.label:GetText()=='Legacy Fill')
            assert(m.layerMenu.parent==m and m.layerMenu.point[3]==-174)
            assert(m.brightness==m.map.brightness and m.brightness.parent.parent==m.map)
            m.legacySubzones:SetChecked(true);click(m.legacySubzones)
            assert(j.state.subzoneFillMethod=='convex')
        ''')


if __name__ == '__main__':
    unittest.main()
