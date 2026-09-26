"""Real kill-credit path, bounded location data, geometry and native-widget calls."""
import unittest
from kill_test_harness import new_client, ROOT
from ui_test_harness import new_ui_client

MAP_API = '''
    mapID=37;mapName='Test zone';px=0.2;py=0.3;nx=0.4;ny=0.5
    stamp=1790300000
    function time() return stamp end
    function CreateVector2D(x,y) return {x=x,y=y} end
    function UnitPosition(unit) return nx,ny,0,0 end
    C_Map={
        GetBestMapForUnit=function(unit) assert(unit=='player');return mapID end,
        GetMapInfo=function(id) return {name=mapName,mapID=id} end,
        GetMapWorldSize=function() return 4000,3000 end,
        GetPlayerMapPosition=function(id,unit) assert(unit=='player');return {x=px,y=py} end,
        GetMapPosFromWorldPos=function(world,v,id)
            assert(not issecretvalue(v.x) and not issecretvalue(v.y));return id,v
        end,
    }
    function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
    function publicTree(t)
        assert(not issecretvalue(t))
        if type(t)=='table' then for k,v in pairs(t) do publicTree(k);publicTree(v) end end
    end
'''


def kills_client():
    lua = new_client()
    lua.execute((ROOT/'CreatureLocations.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute(MAP_API)
    lua.execute('''
        function entry() return AzerothFieldbookDB.bestiary.entries[42] end
        function pointsIn(id) return entry().killLocations[id or 37].points end
    ''')
    return lua


def geometry_client():
    lua = new_ui_client(['CreatureLocations.lua', 'LocationGeometry.lua'])
    lua.execute('''
        function shape(coords,w,h)
            local map={width=w or 10000,height=h or 10000,points={}}
            for i,p in ipairs(coords) do map.points[i]={x=p[1],y=p[2],approximate=false} end
            return ns.LocationGeometry.Build(map)
        end
        function area(p,t)
            local total=0
            for _,v in ipairs(t) do
                local a,b,c=p[v[1]],p[v[2]],p[v[3]]
                total=total+math.abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))/2
                for i=1,3 do
                    local l,r=p[v[i]],p[v[i%3+1]]
                    assert((l.x-r.x)^2+(l.y-r.y)^2<=180^2+0.001,'every edge is bounded')
                end
            end
            return total
        end
    ''')
    return lua


class LocationStorageTests(unittest.TestCase):
    def test_credited_kills_only_exact_coordinates_and_deduplication(self):
        lua=kills_client()
        lua.execute('''
            beginKill('1');assert(count(pointsIn())==0,'sighting has zone but no kill marker')
            local guid=finishKill('Pet-0-1-2-3-9-1')
            assert(kills()==1 and count(pointsIn())==1)
            local p=select(2,next(pointsIn()))
            assert(p.x==4000 and p.y==5000 and not p.approximate)
            assert(p.seenAt==stamp and entry().killLocations[37].width==4000)
            fire('UNIT_DIED',guid);tick();tick();assert(count(pointsIn())==1 and kills()==1)
            beginKill('2');units.target.denied=true;finishKill();assert(count(pointsIn())==1 and kills()==1)
            beginKill('3');nx=0.41;finishKill();assert(kills()==2 and count(pointsIn())==2)
            publicTree(AzerothFieldbookDB)
        ''')

    def test_secret_or_missing_npc_position_uses_labelled_player_fallback(self):
        lua=kills_client()
        lua.execute('''
            nx=secret;beginKill('1');finishKill()
            local p=select(2,next(pointsIn()))
            assert(p.x==2000 and p.y==3000 and p.approximate)
            UnitPosition=function() error('not available for NPCs') end
            px=0.25;beginKill('2');finishKill();assert(count(pointsIn())==2)
            assert(pointsIn()[1+2500*10001+3000].approximate)
            -- Player coordinates are never substituted without the approximation flag.
            publicTree(AzerothFieldbookDB)
        ''')

    def test_secret_player_map_and_coordinate_failures_do_not_change_credit(self):
        lua=kills_client()
        lua.execute('''
            nx=secret;px=secret;beginKill('1');finishKill()
            assert(kills()==1 and count(pointsIn())==0)
            mapID=secret;beginKill('2');finishKill();assert(kills()==2 and count(pointsIn())==0)
            mapID=37;px=0.2
            C_Map.GetPlayerMapPosition=function() error('blocked') end
            beginKill('3');finishKill();assert(kills()==3 and count(pointsIn())==0)
            publicTree(AzerothFieldbookDB)
        ''')

    def test_first_death_sample_retained_no_delayed_player_drift_or_target_swap(self):
        lua=kills_client()
        lua.execute('''
            nx=nil;local guid=beginKill('1')
            fire('PARTY_KILL','Player-1-1',guid)
            px=0.9;py=0.9;units.target.dead=true;fire('UNIT_DIED',guid);tick()
            local p=select(2,next(pointsIn()))
            assert(p.x==2000 and p.y==3000,'retain event-time position')
            local original=UnitPosition
            UnitPosition=function() units.target=spawn('other',false);return 0.8,0.8,0,0 end
            assert(not ns.CreatureLocations.Sample('target',guid,37),'changed identity cannot supply precise coordinates')
            UnitPosition=original;mapID=52;mapName='Other zone'
            assert(not ns.CreatureLocations.Sample(nil,nil,37),'delayed death cannot move to another zone')
        ''')

    def test_locked_pages_new_zones_and_saved_variables_reload(self):
        lua=kills_client()
        lua.execute('''
            beginKill('1');finishKill();entry().confirmed=true
            mapID=52;mapName='Other zone';beginKill('2');finishKill()
            assert(count(entry().killLocations)==2 and count(pointsIn(52))==1)
            local j=ns.CreateBestiaryJournal(AzerothFieldbookDB,function() return 42 end)
            assert(j.entries[42].killLocations[37].points[1+4000*10001+5000])
            assert(#ns.CreatureLocations.Zones(j.entries[42])==2)
            j:DeleteEntry(42);assert(not j.entries[42])
        ''')

    def test_evade_clears_a_previous_uncredited_kill_sample(self):
        lua=kills_client()
        lua.execute('''
            nx=nil;local guid=beginKill('1');fire('PARTY_KILL','Player-1-1',guid)
            -- A living reset invalidates both terminal evidence and its position.
            units.target.combat=false;tick();px=0.7;units.target.combat=true
            finishKill();local p=select(2,next(pointsIn()))
            assert(p.x==7000 and p.approximate)
        ''')

    def test_legacy_zone_name_resolution_rejects_ambiguous_and_secret_maps(self):
        lua=geometry_client()
        lua.execute(MAP_API)
        lua.execute('''
            C_Map.GetMapInfo=function(id)
                return {name=id==37 and 'Test zone' or 'World',parentMapID=id==37 and 1 or 0}
            end
            local calls=0
            C_Map.GetMapChildrenInfo=function(root,kind,recursive)
                assert(root==1 and recursive and kind==nil);calls=calls+1
                return {{name='Other zone',mapID=52},{name='Same name',mapID=53},
                    {name='Same name',mapID=54},secret,{name='Secret map',mapID=secret}}
            end
            local e={locations={['Test zone']=true,['Other zone']=true,['Same name']=true,['Secret map']=true}}
            local zones=ns.CreatureLocations.Zones(e);local byName={}
            for _,z in ipairs(zones) do byName[z.name]=z end
            eq(byName['Test zone'].mapID,37);eq(byName['Other zone'].mapID,52)
            assert(not byName['Same name'].mapID and not byName['Secret map'].mapID)
            ns.CreatureLocations.Zones(e);eq(calls,1,'reuse map-name index')
        ''')

    def test_bounded_history_and_exact_upgrade(self):
        lua=geometry_client()
        lua.execute('''
            local e={};local L=ns.CreatureLocations
            for i=1,300 do L.Record(e,{mapID=37,name='Elwynn',point={x=i,y=i,seenAt=i,approximate=true}}) end
            local n=0;for _ in pairs(e.killLocations[37].points) do n=n+1 end
            eq(n,256);assert(not e.killLocations[37].points[1+10001+1])
            local key=1+300*10001+300
            L.Record(e,{mapID=37,name='Elwynn',point={x=300,y=300,seenAt=301,approximate=false}})
            L.Record(e,{mapID=37,name='Elwynn',point={x=300,y=300,seenAt=302,approximate=true}})
            assert(not e.killLocations[37].points[key].approximate)
            for id=1,100 do L.RememberMap(e,{mapID=id,name='Zone '..id}) end
            n=0;for _ in pairs(e.killLocations) do n=n+1 end;eq(n,64)
        ''')

    def test_backup_roundtrip_validation_tracking_merge_and_sharing_isolation(self):
        lua=new_ui_client(['CreatureLocations.lua','SharingReport.lua','BestiaryBackups.lua','BestiaryJournal.lua','Tracking.lua'])
        lua.execute('''
            db={accountWideTracking=false};local j=ns.CreateBestiaryJournal(db,function() return 42 end)
            local e=j:Ensure(42,false,'Creature');e.category='Beast';e.locations.Elwynn=true
            local L=ns.CreatureLocations
            L.Record(e,{mapID=37,name='Elwynn',width=4000,height=3000,point={x=4321,y=6789,seenAt=now,approximate=true}})
            local backup=assert(j:CreateBackup())
            local decoded=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(backup))))
            local key=1+4321*10001+6789
            eq(decoded.bestiary.entries[42].killLocations[37].points[key].x,4321)
            assert(j:RestoreBackup(decoded))
            assert(not ns.SharingReport.Capture(j,42).killLocations,'coordinates remain personal')
            decoded.bestiary.entries[42].killLocations[37].points[key].x=10001
            assert(not ns.BestiaryBackups.Validate(decoded,true))
            db.accountWideTracking=true
            local account=ns.InitializeTracking(db)
            local other={accountWideTracking=false};local j2=ns.CreateBestiaryJournal(other,function() return 42 end)
            local e2=j2:Ensure(42,false,'Creature')
            L.Record(e2,{mapID=37,name='Elwynn',point={x=1000,y=2000,seenAt=now,approximate=false}})
            L.Record(e2,{mapID=37,name='Elwynn',point={x=4321,y=6789,seenAt=now,approximate=false}})
            other.accountWideTracking=true;ns.InitializeTracking(other)
            local p=account.bestiary.entries[42].killLocations[37].points
            assert(p[key] and not p[key].approximate and p[1+1000*10001+2000])
            assert(db.bestiary.entries[42].killLocations[37].points[key].approximate,'character source preserved')
        ''')


class LocationGeometryTests(unittest.TestCase):
    def test_one_two_collinear_and_unknown_scale_remain_dots(self):
        lua=geometry_client()
        lua.execute('''
            for _,coords in ipairs({{{100,100}},{{100,100},{120,120}},{{100,100},{150,150},{200,200}}}) do
                local p,t,c=shape(coords);eq(#p,#coords);eq(#t,0);assert(not next(c))
            end
            local p,t,c=ns.LocationGeometry.Build({points={{x=100,y=100},{x=150,y=100},{x=100,y=150}}})
            eq(#p,3);eq(#t,0);assert(not next(c))
        ''')

    def test_close_triangles_separate_populations_and_distant_outlier(self):
        lua=geometry_client()
        lua.execute('''
            local p,t,c=shape({{100,100},{150,100},{100,150},{1000,1000},{1050,1000},{1000,1050},{5000,5000}})
            eq(#t,2);eq(area(p,t),2500);assert(not c[7])
            local n=0;for _ in pairs(c) do n=n+1 end;eq(n,6)
            local p2,t2=shape({{100,100},{250,100},{100,250}})
            eq(#t2,0,'two short edges do not permit a long diagonal')
        ''')

    def test_square_ties_determinism_and_nonoverlapping_grid(self):
        lua=geometry_client()
        lua.execute('''
            local p,t=shape({{100,100},{200,100},{200,200},{100,200}})
            eq(#t,2);eq(area(p,t),10000)
            local p2,t2=shape({{100,200},{200,100},{100,100},{200,200}})
            eq(#t2,2);eq(area(p2,t2),10000)
            for i,v in ipairs(t) do for j=1,3 do eq(v[j],t2[i][j]) end end
            local coords={}
            for y=1,16 do for x=1,16 do coords[#coords+1]={x*50,y*50} end end
            local p3,t3=shape(coords)
            eq(#p3,256);eq(#t3,450);assert(math.abs(area(p3,t3)-750^2)<0.001)
        ''')

    def test_yard_scale_respects_map_aspect_and_no_sparse_hull_fill(self):
        lua=geometry_client()
        lua.execute('''
            local p,t=shape({{100,100},{300,100},{100,150}},10000,1000)
            eq(#t,0,'200 yard horizontal edge excluded')
            local p2,t2=shape({{100,100},{300,100},{100,150}},1000,10000)
            eq(#t2,1);eq(area(p2,t2),500)
            local p3,t3=shape({{100,100},{100,150},{150,100},{250,100},{400,100},{550,100},{600,100},{600,150}})
            assert(area(p3,t3)<10000,'a line of samples does not fill the whole cluster hull')
        ''')


class LocationsWindowTests(unittest.TestCase):
    def client(self, book=False):
        modules=['CreatureLocations.lua','LocationGeometry.lua','WindowFocus.lua','WindowPositions.lua','UIScale.lua',
                 'BestiaryJournal.lua','CreatureLocationsWindow.lua']
        if book: modules+=['Scrollbars.lua','ActionButtons.lua','FieldbookShell.lua','BestiaryPages.lua','BestiaryBook.lua']
        lua=new_ui_client(modules)
        lua.execute(MAP_API)
        lua.execute('''
            local create=CreateFrame
            function CreateFrame(...)
                local object=create(...)
                if object.kind=='Texture' then
                    function object:SetTexture(id) self.textureID=id end
                    function object:SetColorTexture(...) self.rgba={...} end
                    function object:SetVertexColor(...) self.tint={...} end
                    function object:SetDesaturated(value) self.desaturated=value end
                    function object:SetVertexOffset(i,x,y)
                        self.vertices=self.vertices or {};self.vertices[i]={x,y}
                    end
                end
                return object
            end
            db={};ns.UIScale:Initialize(db)
            j=ns.CreateBestiaryJournal(db,function() return 42 end)
            e=j:Ensure(42,false,'Creature');e.locations['Test zone']=true
            local L=ns.CreatureLocations
            L.Record(e,{mapID=37,name='Test zone',width=4000,height=3000,point={x=1000,y=1000,seenAt=now,approximate=true}})
            C_Map.GetMapArtLayers=function() return {{layerWidth=1000,layerHeight=668,tileWidth=256,tileHeight=256}} end
            C_Map.GetMapArtLayerTextures=function() return {1,2,3,4,5,6,7,8,9,10,11,12} end
            C_MapExplorationInfo={GetExploredMapTextures=function() return {{textureWidth=280,textureHeight=290,
                offsetX=30,offsetY=40,fileDataIDs={101,102,103,104},isShownByMouseOver=false}} end}
            window=ns.CreateCreatureLocationsWindow(j)
        ''')
        return lua

    def test_zone_selector_pool_reuse_and_unavailable_map(self):
        lua=self.client()
        lua.execute('''
            window:Open(42);f=window:GetFrame()
            assert(f:IsShown() and f.zoneName:IsShown() and not f.zoneButton:IsShown())
            assert(f.status.text:find('1 approximate',1,true) and not f.empty:IsShown())
            local size=#objects;window:Refresh();window:Open(42);eq(#objects,size,'reuse textures and controls')
            for id=1,10 do ns.CreatureLocations.RememberMap(e,{mapID=id,name='Zone '..id}) end;j:Touch();window:Refresh()
            assert(f.zoneButton:IsShown() and not f.zoneName:IsShown())
            f.zoneButton.scripts.OnClick();assert(f.menu:IsShown())
            f.menu.next.scripts.OnClick();assert(f.menu.previous.enabled)
            local row=f.menu.rows[1];row.scripts.OnClick(row)
            assert(not f.menu:IsShown() and f.zoneButton.text:find(row.zone.name,1,true))
            assert(f.empty:IsShown() and f.empty.text:find('No mapped kills',1,true))
            C_Map.GetMapArtLayers=function() return secret end
            window:Open(42);assert(f.empty:IsShown() and f.empty.text:find('map unavailable',1,true))
            j:DeleteEntry(42);window:Refresh();eq(f.zoneName.text,'No zones recorded')
        ''')

    def test_close_scale_focus_book_button_selection_and_lifecycle(self):
        lua=self.client(book=True)
        lua.execute('''
            book=ns.CreateBestiaryBook(j);book:OpenAtUnit('target')
            local content=AzerothFieldbookBestiarySection
            assert(content.creatureLocationsButton.enabled)
            eq(content.creatureLocationsButton.point[2],content.creatureNotesButton)
            content.creatureLocationsButton.scripts.OnClick()
            local map=AzerothFieldbookCreatureLocations
            map.scripts.OnShow(map) -- The mock's Show omits native OnShow dispatch.
            assert(map:IsShown() and content.creatureLocationsButton.afbSelected)
            eq(map.strata,'DIALOG');assert(map.toplevel and map.clamped)
            assert(map.afbPreferBookEdge and map.afbAnchorRule=='right' and map.afbAlignBookTop)
            local base=map:GetScale();ns.UIScale:Set(1.25);eq(map:GetScale(),base*1.25)
            content:Hide();assert(not map:IsShown() and not content.creatureLocationsButton.afbSelected)
            content:Show();content.creatureLocationsButton.scripts.OnClick();assert(map:IsShown())
            content.creatureLocationsButton.scripts.OnClick();assert(not map:IsShown())
        ''')

    def test_three_nearby_kills_replace_dots_with_translucent_triangle(self):
        lua=self.client()
        lua.execute('''
            ns.CreatureLocations.Record(e,{mapID=37,name='Test zone',point={x=1200,y=1000,seenAt=now,approximate=false}})
            ns.CreatureLocations.Record(e,{mapID=37,name='Test zone',point={x=1000,y=1200,seenAt=now,approximate=false}})
            window:Open(42)
            local f=window:GetFrame();local dots=0
            for _,o in ipairs(objects) do if o.parent==f.map and o.location and o:IsShown() then dots=dots+1 end end
            eq(dots,0);assert(f.status.text:find('nearby groups shaded',1,true))
            ns.CreatureLocations.Record(e,{mapID=37,name='Test zone',point={x=9000,y=9000,seenAt=now,approximate=false}})
            j:Touch();window:Refresh();dots=0
            for _,o in ipairs(objects) do if o.parent==f.map and o.location and o:IsShown() then dots=dots+1 end end
            eq(dots,1,'distant fourth sample remains a dot')
        ''')

    def test_compact_notes_and_overflow_heading_hover_scroll(self):
        lua=self.client(book=True)
        lua.execute('''
            book=ns.CreateBestiaryBook(j);book:OpenAtUnit('target')
            local content=AzerothFieldbookBestiarySection
            eq(content.creatureNotesButton:GetWidth(),58)
            local hover=content.titleHover
            assert(not hover:IsMouseClickEnabled() and hover:IsMouseMotionEnabled())
            j.entries[42].name='Stonesplinter Skullthumper with an exceptionally long creature name'
            j:Touch();book:Refresh();content.title:SetWidth(180)
            hover.scripts.OnEnter(hover)
            assert(hover.nameViewport:IsShown() and not content.title:IsShown())
            hover.scripts.OnUpdate(hover,1.5)
            assert(hover.nameViewport.horizontalScroll>0)
            hover.scripts.OnLeave(hover)
            assert(content.title:IsShown() and not hover.nameViewport:IsShown())
            eq(hover.nameViewport.horizontalScroll,0);assert(not hover.scripts.OnUpdate)
            hover.scripts.OnEnter(hover);hover.scripts.OnUpdate(hover,1.5)
            j.entries[42].name='Wolf';j:Touch();book:Refresh()
            assert(not hover.scripts.OnUpdate and content.title:IsShown())
            hover.scripts.OnEnter(hover);assert(not hover.scripts.OnUpdate,'short headings stay stationary')
        ''')

    def test_map_tile_crops_exploration_padding_and_triangle_vertices(self):
        lua=self.client()
        lua.execute('''
            ns.CreatureLocations.Record(e,{mapID=37,name='Test zone',point={x=1200,y=1000,seenAt=now,approximate=false}})
            ns.CreatureLocations.Record(e,{mapID=37,name='Test zone',point={x=1000,y=1200,seenAt=now,approximate=false}})
            window:Open(42)
            local tile,overlay,triangle
            for _,o in ipairs(objects) do
                if o.textureID==12 then tile=o end
                if o.textureID==104 then overlay=o end
                if o.vertices and o.rgba[4]==0.46 then triangle=o end
            end
            assert(tile and overlay and triangle)
            eq(tile.texCoord[2],232/256);eq(tile.texCoord[4],156/256)
            eq(overlay.texCoord[2],24/32);eq(overlay.texCoord[4],34/64)
            eq(triangle.rgba[4],0.46)
            local w,h=triangle:GetWidth(),triangle:GetHeight()
            local base={{0,0},{0,-h},{w,0},{w,-h}}
            local actual={}
            for i=1,4 do actual[i]={base[i][1]+triangle.vertices[i][1],base[i][2]+triangle.vertices[i][2]} end
            assert(math.abs(actual[2][1]-actual[4][1])<0.000001 and math.abs(actual[2][2]-actual[4][2])<0.000001,
                'fourth vertex collapses onto the second, rather than leaving a rectangle')
            for _,p in ipairs(actual) do assert(p[1]>=-0.000001 and p[1]<=w+0.000001 and p[2]>=-h-0.000001 and p[2]<=0.000001) end
        ''')

    def test_boundary_glow_and_brightness_are_independent_and_persist(self):
        lua=self.client()
        lua.execute('''
            for _,p in ipairs({{1200,1000},{1000,1200},{1200,1200}}) do
                ns.CreatureLocations.Record(e,{mapID=37,name='Test zone',point={x=p[1],y=p[2],seenAt=now,approximate=false}})
            end
            window:Open(42);local f=window:GetFrame()
            assert(f.paper.textureID:find('ParchmentBook.tga',1,true))
            j:SetBackgroundBrightness(1.2);window:Refresh()
            eq(f.paper.tint[1],0.504*1.2*0.34);eq(f.paper.tint[3],f.paper.tint[1])
            assert(f.paper.desaturated and f.menu.paper.desaturated)
            eq(f.menu.paper.tint[1],f.paper.tint[1])
            local glows,fillCount=0,0
            for _,o in ipairs(objects) do
                if o.vertices and o:IsShown() then
                    if o.rgba[4]==0.46 then fillCount=fillCount+1 else glows=glows+1 end
                end
            end
            eq(fillCount,2);eq(glows,12,'three glow strips per exposed edge; no internal diagonal')
            eq(f.brightnessValue.text,'80%')
            local revision=j.revision
            f.brightness.scripts.OnValueChanged(f.brightness,0.35)
            eq(j.revision,revision,'dragging brightness does not retriangulate')
            eq(f.brightnessValue.text,'35%');eq(db.locationMapBrightness,0.35)
            eq(f.paper.tint[1],0.504*1.2*0.34,'map brightness does not dim the parchment')
            for _,o in ipairs(objects) do
                if o.textureID and type(o.textureID)=='number' then eq(o.tint[1],0.35)
                elseif o.vertices then assert(not o.tint,'fill and glow are not dimmed') end
            end
            local reloaded=ns.CreateBestiaryJournal(db,function() return 42 end)
            eq(reloaded:GetLocationMapBrightness(),0.35)
            window:Hide();window:Open(42);eq(f.brightnessValue.text,'35%')
            j:SetLocationMapBrightness(-10);eq(j:GetLocationMapBrightness(),0.2)
            j:SetLocationMapBrightness(10);eq(j:GetLocationMapBrightness(),1)
            C_Map.GetMapArtLayers=function() return nil end
            window:Open(42)
            for _,o in ipairs(objects) do if o.vertices then assert(not o:IsShown(),'no stale glow on missing map') end end
        ''')


if __name__=='__main__':
    unittest.main(verbosity=2)
