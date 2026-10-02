"""Personal crossing evidence, inferred regions and the optional Atlas overlay."""
import unittest
from atlas_test_harness import new_atlas


class SubzoneTests(unittest.TestCase):
    def test_ctrl_cleanup_cleans_all_saved_maps_and_preserves_selection(self):
        self.lua.execute('''
            j.state.subzoneFillMethod='convex'
            for _,id in ipairs({101,102,999}) do
                local function point(x,y) return {kind='interior',mapID=id,name='Lake',x=x,y=y,at=100} end
                local border=crossing('Lake','Bank',2500,2000);border.mapID=id
                s.store[id]={point(2000,2000),point(8000,2000),point(8000,8000),point(2000,8000),
                    point(5000,2000),point(5000,5000),point(6000,6000),border,{invalid='preserve'}}
                s:Changed(id)
            end
            s.index={};local selected=j.state.mapID
            local records=snapshot(j.records);local messages={}
            DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
            IsControlKeyDown=function() return true end
            m.cleanPoints.scripts.OnEnter(m.cleanPoints)
            local tip=GameTooltip.lines[1].text
            assert(tip:find('Ctrl+Click',1,true) and tip:find('ALL saved Atlas maps',1,true))
            click(m.cleanPoints);assert(not m.cleanPoints.enabled and s.cleaning)
            assert(not S.CleanInterior(j,102) and not S.CleanAllInterior(j),'Batch prevents overlapping cleanup')
            settle()
            for _,id in ipairs({101,102,999}) do
                assert(#s.store[id]==7 and #s:Crossings(id)==1)
                assert(s.store[id][5].y==2000 and s.store[id][7].invalid=='preserve')
            end
            assert(m.cleanPoints.enabled and not s.cleaning)
            assert(j.state.mapID==selected and snapshot(j.records)==records)
            assert(messages[#messages]:find('removed 6',1,true) and messages[#messages]:find('3 maps',1,true))
            click(m.cleanPoints);settle();assert(m.message:GetText():find('removed 0',1,true))
        ''')

    def test_all_map_cleanup_skips_stale_map_and_continues(self):
        self.lua.execute('''
            j.state.subzoneFillMethod='convex'
            for _,id in ipairs({101,102}) do
                s.store[id]={}
                for _,p in ipairs({{2000,2000},{8000,2000},{8000,8000},{2000,8000},{5000,5000}}) do
                    s.store[id][#s.store[id]+1]={kind='interior',mapID=id,name='Lake',x=p[1],y=p[2],at=100}
                end
                s:Changed(id)
            end
            s.index={};s:Index(101)
            local removed,message
            assert(S.CleanAllInterior(j,function(n,text) removed=n;message=text end))
            local clock=0;debugprofilestop=function() clock=clock+2;return clock end
            S.Step();debugprofilestop=nil
            table.insert(s.store[101],{kind='interior',mapID=101,name='Lake',x=5500,y=5500,at=100})
            s:Changed(101);local unchanged=snapshot(s.store[101]);settle()
            assert(snapshot(s.store[101])==unchanged and #s.store[102]==4)
            assert(removed==1 and message:find('1 map could not be cleaned',1,true) and not s.cleaning)
            local readOnly=ns.CreateAtlasJournal({schema=999})
            assert(not S.CleanAllInterior(readOnly,function() error('read only') end))
            local empty=ns.CreateAtlasJournal({});local finished=false
            assert(not S.CleanAllInterior(empty,function(n) assert(n==0);finished=true end))
            assert(finished and not empty.subzones.cleaning)
        ''')

    def test_great_sea_pauses_automatic_mapping_without_excluding_the_coast(self):
        self.lua.execute('''
            C_Map.GetMapWorldSize=function() return 1000,1000 end
            for _,signal in ipairs({'subzone','zone','realZone'}) do
                s:Reset();s.store[101]={};s.index={}
                GetRealZoneText=function() return 'Coast' end
                GetZoneText=function() return 'Coast' end
                sample('Meadow',.4,.4);local before=snapshot(s.store)
                if signal=='zone' then GetZoneText=function() return 'The Great Sea' end end
                if signal=='realZone' then GetRealZoneText=function() return 'The Great Sea' end end
                local sea=signal=='subzone' and 'The Great Sea' or 'Coastal waters'
                assert(not sample(sea,.401,.4) and not sample(sea,.6,.6))
                assert(snapshot(s.store)==before and not s.previous and j.state.automaticMapping~=false)
                assert(s:RecordPoint(),'Deliberate manual points remain allowed at sea')
                GetRealZoneText=function() return 'Coast' end;GetZoneText=function() return 'Coast' end
                sample('Forest',.402,.4);assert(#s:Crossings(101)==0,'No crossing across the excluded sea')
                sample('Hill',.403,.4);assert(#s:Crossings(101)==1,'Nearby land still maps normally')
            end
        ''')

    def test_traced_fill_indents_through_samples_and_legacy_restores_gap(self):
        self.lua.execute(r'''
            local rows={crossing('Meadow','Forest',2000,2000,0,0),crossing('Meadow','Forest',8000,2000,0,0)}
            for _,p in ipairs({{2000,8000},{8000,8000},{5000,4000}}) do
                rows[#rows+1]={kind='interior',mapID=101,name='Meadow',x=p[1],y=p[2],at=100}
            end
            local original=snapshot(rows)
            local traced=S.Build(rows)
            local legacy=S.Build(rows,nil,nil,nil,'convex')
            assert(legacy:At(5000,2500) and not traced:At(5000,2500),'Leave the unsampled notch blank')
            for _,r in ipairs(traced.strips) do
                assert(not (5000>=r.x/traced.grid*10000 and 5000<=(r.x+r.width)/traced.grid*10000
                    and 2500>=r.y/traced.grid*10000 and 2500<=(r.y+1)/traced.grid*10000),'No rendered strip across the gap')
            end
            local function side(a,b,x,y) return (b.x-a.x)*(y-a.y)-(b.y-a.y)*(x-a.x) end
            for _,t in ipairs(traced.triangles) do
                local a,b,c=side(t[1],t[2],5000,2500),side(t[2],t[3],5000,2500),side(t[3],t[1],5000,2500)
                assert(not ((a>=0 and b>=0 and c>=0) or (a<=0 and b<=0 and c<=0)),'No rendered triangle across the gap')
            end
            local h=traced.areas.Meadow.hull
            local detour=false
            for i,p in ipairs(h) do
                if p.x==5000 and p.y==4000 then
                    local a,b=h[(i-2)%#h+1],h[i%#h+1]
                    detour=a.y==2000 and b.y==2000
                end
            end
            assert(detour,'Border to interior to border, rather than a straight border chord')
            for _,p in ipairs(rows) do assert(traced:At(p.x,p.y),'Keep every observed point') end
            local reversed={};for i=#rows,1,-1 do reversed[#reversed+1]=rows[i] end
            local again=S.Build(reversed)
            assert(snapshot(again.areas.Meadow.hull)==snapshot(h),'Input order cannot change the outline')
            assert(snapshot(rows)==original,'Building either mode preserves saved evidence')
            s.store[101]=rows;s:Changed(101);j.state.showSubzones=true;c:Refresh()
            local model=m.map.subzoneModel
            assert(model.method=='traced' and not model:At(5000,2500))
            m.legacySubzones:SetChecked(true);click(m.legacySubzones);settle()
            assert(m.map.subzoneModel.method=='convex' and m.map.subzoneModel:At(5000,2500))
            m.legacySubzones:SetChecked(false);click(m.legacySubzones);settle()
            assert(m.map.subzoneModel.method=='traced' and not m.map.subzoneModel:At(5000,2500))
            for name,a in pairs(model.areas) do assert(m.map.subzoneModel.areas[name].colourID==a.colourID) end
        ''')

    def test_traced_dense_and_collinear_samples_remain_inside_simple_outlines(self):
        self.lua.execute(r'''
            for seed=1,4 do
                local rows={}
                for i=1,80 do
                    rows[#rows+1]={kind='interior',mapID=101,name='Survey',x=(i*127*seed)%9800+100,y=(i*271)%9800+100,at=100}
                end
                -- Duplicate and collinear observations must not pinch the outline.
                for x=1000,9000,1000 do
                    rows[#rows+1]={kind='interior',mapID=101,name='Survey',x=x,y=5000,at=100}
                end
                rows[#rows+1]=rows[1]
                local model=S.Build(rows)
                for _,p in ipairs(rows) do assert(model:At(p.x,p.y),'Never carve away observed samples') end
                local h=model.areas.Survey.hull
                local function cross(a,b,p) return (b.x-a.x)*(p.y-a.y)-(b.y-a.y)*(p.x-a.x) end
                for i,a in ipairs(h) do for k,c in ipairs(h) do
                    local b,d=h[i%#h+1],h[k%#h+1]
                    assert(not (cross(a,b,c)*cross(a,b,d)<0 and cross(c,d,a)*cross(c,d,b)<0),'No self-crossing outlines')
                end end
                assert(#model.triangles<=S.MAX_TRIANGLES)
            end
        ''')

    def test_traced_cleanup_preserves_samples_and_cancels_legacy_cleanup_on_switch(self):
        self.lua.execute(r'''
            s.store[101]={}
            for _,p in ipairs({{2000,2000},{8000,2000},{8000,8000},{2000,8000},{5000,5000}}) do
                s.store[101][#s.store[101]+1]={kind='interior',mapID=101,name='Lake',x=p[1],y=p[2],at=100}
            end
            s:Changed(101);local before=snapshot(s.store);local message
            assert(not S.CleanInterior(j,101,function(n,text) assert(n==0);message=text end))
            assert(message:find('preserved') and snapshot(s.store)==before)
            assert(not S.CleanAllInterior(j,function(n) assert(n==0) end))
            j.state.subzoneFillMethod='convex'
            assert(S.CleanInterior(j,101,function(n,text) assert(n==0);message=text end))
            j.state.subzoneFillMethod='traced';settle()
            assert(snapshot(s.store)==before and message:find('preserved'))
        ''')

    def test_native_filters_control_independent_layers_and_preserve_recording(self):
        self.lua.execute(r'''
            local modifier;Menu={ModifyMenu=function(tag,fn) assert(tag=='MENU_WORLD_MAP_TRACKING');modifier=fn end}
            WorldMapFrame=CreateFrame('Frame');WorldMapFrame:Show()
            local canvas=CreateFrame('Frame',nil,WorldMapFrame);canvas:SetSize(1000,800)
            function WorldMapFrame:GetCanvas() return canvas end
            function WorldMapFrame:GetMapID() return 101 end
            C_Timer=nil
            local control=S.CreateWorldOverlay(j)
            local entries={};local root={CreateDivider=function() end,CreateTitle=function(_,title) assert(title=='Azeroth Fieldbook') end}
            local inMenu=false
            local refresh=control.Refresh
            function control:Refresh() assert(not inMenu,'Render outside native menu callbacks');return refresh(self) end
            function root:CreateCheckbox(label,selected,toggle)
                local entry={selected=selected}
                function entry.toggle()
                    inMenu=true;assert(toggle()==nil);inMenu=false
                end
                function entry:SetEnabled() end
                function entry:SetSelectionIgnored() self.ignored=true end
                entries[label]=entry;return entry
            end
            local settleSurvey=settle
            local function settle()
                local work={}
                for _,frame in ipairs(objects) do
                    if frame.scripts and frame.scripts.OnUpdate and frame:IsShown() then
                        work[#work+1]={frame,frame.scripts.OnUpdate}
                    end
                end
                for _,row in ipairs(work) do row[2](row[1],0) end
                settleSurvey()
            end
            modifier(nil,root)
            for _,entry in pairs(entries) do assert(entry.ignored) end
            s.store[101]=ring();s.store[101][5]={kind='interior',mapID=101,name='Isolated',x=9000,y=9000,at=100};s:Changed(101)
            local before=snapshot(s.store);local atlas=snapshot({j.state.showSubzones,j.state.showSubzoneLabels,j.state.showSubzonePoints})
            assert(not entries.Zones.selected())
            entries.Zones.toggle();settle()
            local overlay=control.overlay;assert(overlay.subzoneModel)
            for _,dot in ipairs(overlay.subzoneDots) do assert(not dot:IsShown(),'Points off also hides isolated native-map dots') end
            entries.Points.toggle();settle();assert(entries.Points.selected())
            local visible=0;for _,dot in ipairs(overlay.subzoneDots) do if dot:IsShown() then visible=visible+1 end end
            assert(visible==5)
            entries.Labels.toggle();settle();assert(entries.Labels.selected())
            entries.Zones.toggle();settle();assert(not entries.Zones.selected() and entries.Points.selected())
            entries.Points.toggle();entries.Labels.toggle();settle()
            assert(not overlay.subzoneModel and not overlay.subzonePending)
            assert(snapshot(s.store)==before and snapshot({j.state.showSubzones,j.state.showSubzoneLabels,j.state.showSubzonePoints})==atlas)
            assert(j.state.automaticMapping~=false)
            local reload=ns.CreateAtlasJournal(j.saved)
            assert(reload.state.worldSubzonePoints==false and reload.state.worldSubzoneLabels==false and reload.state.worldSubzoneZones==false)
            j.readOnly=true;entries.Zones.toggle();assert(not entries.Zones.selected())
        ''')

    def setUp(self):
        self.lua = new_atlas(ui=True)
        self.lua.execute('''
            S=ns.AtlasSubzones;s=j.subzones
            function settle()
                for i=1,20000 do
                    if not S.worker or not S.worker:IsShown() then assert(not m.map.subzoneError,m.map.subzoneError);return end
                    S.Step()
                end
                error('Sub-zone worker did not settle')
            end
            autoSettle=true
            local refresh=c.Refresh
            function c:Refresh(...) refresh(self,...);if autoSettle then settle() end end
            for _,buffer in ipairs(m.map.subzoneBuffers) do
                local create=buffer.frame.CreateFontString
                function buffer.frame:CreateFontString(...)
                    local label=create(self,...)
                    local stringWidth=label.GetStringWidth
                    function label:SetFont(_,size,flags) self.fontSize=size;self.fontFlags=flags end
                    function label:GetStringWidth() return stringWidth(self)*(self.fontSize or 12)/12 end
                    return label
                end
            end
            tick=10;name='Meadow';function GetTime() return tick end
            function GetSubZoneText() return name end
            function GetRealZoneText() return 'Coast' end
            function sample(label,x,y)
                name=label;px=x or px;py=y or py;tick=tick+0.25
                return s:Observe()
            end
            s:Reset();sample('Meadow',.4,.4)
            function crossing(from,to,x,y,dx,dy)
                return {mapID=101,from=from,to=to,x=x,y=y,fromX=x+(dx or -10),fromY=y+(dy or 0),at=100}
            end
            function ring()
                return {crossing('Meadow','Forest',3000,3000),crossing('Meadow','Forest',7000,3000),
                    crossing('Meadow','Hill',7000,7000),crossing('Meadow','Hill',3000,7000)}
            end
        ''')

    def test_main_map_opt_in_cache_layers_map_changes_and_hide(self):
        self.lua.execute('''
            C_Timer=nil
            function hooksecurefunc(owner,key,fn)
                local original=owner[key]
                owner[key]=function(self,...) local result=original(self,...);fn(self,...);return result end
            end
            WorldMapFrame=CreateFrame('Frame');WorldMapFrame:Show()
            local canvas=CreateFrame('Frame',nil,WorldMapFrame);canvas:SetSize(1000,800)
            function WorldMapFrame:GetCanvas() return canvas end
            function WorldMapFrame:GetCanvasScale() return canvas:GetScale() end
            local displayed=101
            function WorldMapFrame:GetMapID() return displayed end
            function WorldMapFrame:SetMapID(id) displayed=id end
            s.store[101]=ring();s:Changed(101)
            local control=c.worldSubzones
            control:Refresh();assert(not control.overlay,'Disabled overlay allocates no drawing widgets')
            j.state.showSubzones=true;j.state.showSubzoneLabels=true;j.state.showSubzonePoints=true
            assert(m.worldSubzones==nil,'World map filters replace the redundant Atlas checkbox')
            j.state.showSubzonesOnWorldMap=true;control:Refresh();settle() -- Existing saved preference.
            local overlay=assert(control.overlay)
            local function clickThrough()
                assert(not overlay:IsMouseClickEnabled() and not overlay:IsMouseMotionEnabled() and not overlay.mouseWheel,
                    'Native map overlay must pass clicks, drags and wheel input through')
                assert(not overlay.scripts.OnEnter and not overlay.scripts.OnLeave,'No interactive hover handlers on the native overlay')
                for _,buffer in ipairs(overlay.subzoneBuffers) do
                    assert(not buffer.frame:IsMouseClickEnabled() and not buffer.frame:IsMouseMotionEnabled(),
                        'Both paint buffers must remain non-interactive')
                end
                assert(m.map.scripts.OnEnter and m.map.scripts.OnLeave,'Atlas map keeps its own hover interactions')
            end
            clickThrough()
            assert(not overlay.subzoneError and overlay.subzoneModel and #overlay.subzoneModel.rows>0)
            assert(not overlay.scripts.OnUpdate and not control.loader.scripts.OnUpdate,'No idle polling')
            local model=overlay.subzoneModel;local count=#objects
            for i=1,10 do control:Refresh();settle() end
            assert(overlay.subzoneModel==model and #objects==count,'Unchanged refresh reuses geometry and widgets')
            j.state.showSubzoneLabels=false;c:Refresh();settle()
            assert(overlay.subzoneModel==model,'Layer changes reuse geometry')
            for _,label in ipairs(overlay.subzoneLabels) do assert(not label:IsShown()) end
            canvas:SetScale(2);settle();assert(overlay:GetWidth()==2000 and overlay:GetScale()==0.5)
            assert(overlay.subzoneModel==model,'Zoom does not rebuild survey geometry')
            WorldMapFrame:SetMapID(102);settle();assert(#overlay.subzoneModel.rows==0,'Uses the native map selection')
            WorldMapFrame:SetMapID(101);S.Step()
            WorldMapFrame:Hide();WorldMapFrame.scripts.OnHide(WorldMapFrame);settle()
            assert(not overlay:IsShown() and not overlay.subzonePending)
            WorldMapFrame:Show();WorldMapFrame.scripts.OnShow(WorldMapFrame);settle()
            assert(overlay:IsShown() and #overlay.subzoneModel.rows>0)
            clickThrough()
            j.state.showSubzonesOnWorldMap=false;control:Refresh();settle()
            assert(not overlay:IsShown() and not overlay.subzonePending)
            assert(j.state.automaticMapping~=false,'Display toggle does not change collection')
        ''')

    def test_automatic_survey_pauses_in_flight_and_breaks_continuity(self):
        self.lua.execute('''
            C_Map.GetMapWorldSize=function() return 1000,1000 end
            for _,signal in ipairs({'UnitOnTaxi','IsFlying'}) do
                s:Reset();s.store[101]={};s.index={}
                _G[signal]=function(unit) if signal=='UnitOnTaxi' then assert(unit=='player') end;return false end
                sample('Meadow',.4,.4);local before=snapshot(s.store)
                _G[signal]=function() return true end
                assert(not sample('Forest',.401,.4) and not sample('Hill',.6,.6))
                assert(s.previous==nil and snapshot(s.store)==before)
                _G[signal]=function() return false end
                sample('Forest',.402,.4);assert(#s:Crossings(101)==0,'Do not bridge the flight')
                sample('Hill',.403,.4);assert(#s:Crossings(101)==1,'Ground sampling resumes')
                _G[signal]=nil
            end
            UnitOnTaxi=function() error('Unavailable') end
            local before=snapshot(s.store);assert(not sample('Other',.404,.4) and snapshot(s.store)==before and not s.previous)
            UnitOnTaxi=function() return 1 end
            assert(not sample('Other',.405,.4),'Legacy taxi flag also blocks sampling')
        ''')

    def test_capitals_map_on_ground_and_pause_during_flight(self):
        self.lua.execute('''
            C_Map.GetMapWorldSize=function() return 1000,1000 end
            local info=C_Map.GetMapInfo
            C_Map.GetMapInfo=function(id) if id==900 then return {parentMapID=1453} end;return info(id) end
            IsResting=function() return true end
            for _,id in ipairs({1453,1454,1455,1456,1457,1458,900}) do
                mapID=id;s:Reset()
                assert(sample('City district',.4,.4),'Grounded capitals record interior samples')
                assert(sample('Market',.402,.4) and #s:Crossings(id)==1,'City district crossings are recorded')
                for _,signal in ipairs({'UnitOnTaxi','IsFlying'}) do
                    local before=snapshot(s.store)
                    _G[signal]=function() return true end
                    assert(not sample('Flight district',.404,.4))
                    assert(s.previous==nil and snapshot(s.store)==before,'Flight cannot map cities')
                    _G[signal]=function() return false end
                    sample('Market',.402,.4)
                    assert(#s:Crossings(id)==1,'Landing must not bridge the flight')
                end
                px=.7;py=.7;assert(s:RecordPoint(),'Manual city survey remains available')
            end
            mapID=101
            sample('Inn',.401,.4);assert(#s:Crossings(101)==0,'Map changes cannot invent crossings')
            sample('Road',.402,.4);assert(#s:Crossings(101)==1,'Ordinary resting areas still map')
        ''')

    def test_cleanup_keeps_edges_crossings_and_other_maps(self):
        self.lua.execute('''
            j.state.subzoneFillMethod='convex'
            local function point(x,y) return {kind='interior',mapID=101,name='Lake',x=x,y=y,at=100} end
            local border=crossing('Lake','Bank',2500,2000)
            s.store[101]={point(2000,2000),point(8000,2000),point(8000,8000),point(2000,8000),
                point(5000,2000),point(5000,5000),point(6000,6000),border,{invalid='preserve'}}
            s.store[102]={point(3000,3000)}
            local other=snapshot(s.store[102]);s.index={};s:Changed(101)
            j.state.showSubzones=true;j.state.showSubzonePoints=true;c:Refresh();settle()
            local messages={};DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
            click(m.cleanPoints);settle()
            assert(#messages>=3 and messages[1]:find('Starting cleanup',1,true))
            assert(messages[#messages]:find('kept',1,true) and messages[#messages]:find('cross-over',1,true))
            assert(m.cleanPoints:GetWidth()>m.layerMenu:GetWidth())
            assert(#s.store[101]==7 and #s:Crossings(101)==1)
            assert(s.store[101][5].y==2000,'Collinear perimeter evidence stays')
            assert(s.store[101][6]==border and s.store[101][7].invalid=='preserve')
            assert(snapshot(s.store[102])==other)
            assert(m.message:GetText():find('Removed 2',1,true))
            click(m.cleanPoints);settle();assert(#s.store[101]==7,'Cleanup is idempotent')
            assert(m.message:GetText():find('Removed 0',1,true))
            local count
            local readOnly=ns.CreateAtlasJournal({schema=999})
            assert(not S.CleanInterior(readOnly,101,function() error('read only') end))
        ''')

    def test_cleanup_preserves_overlapping_region_ownership_and_rejects_stale_work(self):
        self.lua.execute('''
            j.state.subzoneFillMethod='convex'
            s.store[101]={}
            local function point(name,x,y)
                s.store[101][#s.store[101]+1]={kind='interior',mapID=101,name=name,x=x,y=y,at=100}
            end
            for _,p in ipairs({{1000,1000},{7000,1000},{7000,7000},{1000,7000},{2000,2000},{6500,4000}}) do point('A',p[1],p[2]) end
            for _,p in ipairs({{5000,2000},{9000,2000},{9000,6000},{5000,6000},{6000,4000}}) do point('B',p[1],p[2]) end
            s.index={};s:Changed(101)
            local before=S.Build(s:Samples(101),nil,nil,nil,'convex');local removed
            assert(S.CleanInterior(j,101,function(n) removed=n end));settle()
            assert(removed and removed>0)
            local after=S.Build(s:Samples(101),nil,nil,nil,'convex')
            for x=1000,9000,100 do for y=1000,7000,100 do
                local a,b=before:At(x,y),after:At(x,y)
                assert((a and a.name)==(b and b.name),'Cleanup must preserve overlap ownership')
            end end
            point('A',2000,2000);s.index={};s:Changed(101);s:Index(101)
            local message;removed=nil
            S.CleanInterior(j,101,function(n,text) removed=n;message=text end)
            local clock=0;debugprofilestop=function() clock=clock+2;return clock end
            S.Step();debugprofilestop=nil
            point('A',2500,2500);s:Changed(101)
            local unchanged=snapshot(s.store);settle()
            assert(removed==nil and message and snapshot(s.store)==unchanged,'New observations invalidate cleanup')
        ''')

    def test_hide_zone_named_areas_is_display_only_and_survives_buffer_swaps(self):
        self.lua.execute('''
            s.store[101]={}
            for _,p in ipairs({{'Meadow',2000,2000},{'Meadow',4500,2000},{'Meadow',2000,7000},
                {'Forest',5500,2000},{'Forest',8000,2000},{'Forest',8000,7000}}) do
                s.store[101][#s.store[101]+1]={kind='interior',mapID=101,name=p[1],x=p[2],y=p[3],at=100}
            end
            s:Changed(101)
            C_Map.GetMapInfo=function(id) return {mapID=id,name=id==101 and 'Meadow' or 'Other'} end
            j.state.showSubzones=true;j.state.showSubzoneLabels=true;j.state.showSubzonePoints=true
            c:Refresh();settle()
            local model=m.map.subzoneModel;local original=snapshot(s.store)
            local function verify(hidden)
                local visible,other=0,0
                for _,kind in ipairs({'strips','triangles'}) do
                    local pool=kind=='strips' and m.map.subzoneTextures or m.map.subzoneTriangles
                    for i,row in ipairs(model[kind]) do
                        local shown=pool[i] and pool[i]:IsVisible()
                        if row.area.name=='Meadow' then
                            assert(shown==not hidden,'Matching shading must follow the filter')
                            visible=visible+1
                        elseif shown then other=other+1 end
                    end
                end
                assert(visible>0 and other>0,'Exercise matching and neighbouring shading')
                for _,label in ipairs(m.map.subzoneLabels) do
                    if hidden and label:IsVisible() then assert(label:GetText()~='Meadow') end
                end
                local dots=0;for _,dot in ipairs(m.map.subzoneDots) do if dot:IsVisible() then dots=dots+1 end end
                assert(dots==#model.rows,'Filtering shading cannot hide checked sample points')
                assert(m.map.subzoneModel==model and snapshot(s.store)==original,'Do not rebuild geometry or mutate evidence')
            end
            verify(false)
            for i=1,6 do
                local hidden=i%2==1
                m.hideZoneAreas:SetChecked(hidden);click(m.hideZoneAreas);settle();verify(hidden)
            end
            m.hideZoneAreas:SetChecked(true);click(m.hideZoneAreas);settle()
            assert(ns.CreateAtlasJournal(saved).state.hideZoneNameSubzones==true,'Save the character display preference')
            C_Map.GetMapInfo=function(id) return {mapID=id,name='Other'} end
            c:Refresh();settle();verify(false)
        ''')

    def test_logging_labels_positions_deduplication_and_reload(self):
        self.lua.execute('''
            assert(not j.state.showSubzones and #s:Crossings(101)==0)
            assert(sample('Forest',.401,.4))
            local rows=s:Crossings(101);local r=rows[1]
            assert(r.from=='Meadow' and r.to=='Forest' and r.x==4010 and r.fromX==4000 and r.mapID==101 and r.at==now)
            assert(not sample('Forest',.401,.4) and #s:Crossings(101)==1)
            sample('Meadow',.4,.4);sample('Forest',.401,.4)
            assert(#s:Crossings(101)==2,'Same-direction cell crossings coalesce; reverse direction is retained')
            r.from='Detached';assert(s:Crossings(101)[1].from=='Meadow')
            j.state.showSubzones=true
            local reload=ns.CreateAtlasJournal(saved)
            assert(reload.state.showSubzones and #reload.subzones:Crossings(101)==2)
            assert(not reload.subzones:Observe(),'Reload must only establish baseline')
            sample('',.402,.4);assert(s:Crossings(101)[3].to=='Coast')
            assert(not next(j.records) and not next(j.expeditions),'Automatic evidence never creates discoveries')
        ''')

    def test_discontinuities_and_unreadable_values_do_not_draw_boundaries(self):
        self.lua.execute('''
            sample('Forest',.9,.9);assert(#s:Crossings(101)==0)
            mapID=102;sample('Hill',.901,.9);assert(#s:Crossings(102)==0)
            mapID=101;sample('Meadow',.4,.4)
            px=nil;name='Forest';s:Observe();sample('Forest',.401,.4)
            tick=tick+10;sample('Hill',.402,.4);assert(#s:Crossings(101)==0)
            sample(nil,.403,.4);sample('Meadow',.404,.4);assert(#s:Crossings(101)==0)
            name='Forest';px=.405;c.subzoneObserver.scripts.OnEvent(c.subzoneObserver,'PLAYER_ENTERING_WORLD')
            assert(#s:Crossings(101)==0)
            c.subzoneObserver.scripts.OnEvent(c.subzoneObserver,'PLAYER_LEAVING_WORLD')
            name='Hill';px=.406;c.subzoneObserver.scripts.OnUpdate(c.subzoneObserver,1)
            assert(#s:Crossings(101)==0)
            c.subzoneObserver.scripts.OnEvent(c.subzoneObserver,'PLAYER_ENTERING_WORLD')
            name='Meadow';px=.407;c.subzoneObserver.scripts.OnEvent(c.subzoneObserver,'ZONE_CHANGED_NEW_AREA')
            assert(#s:Crossings(101)==0)
            local future={schema=999,subzones={keep=true}}
            local before=snapshot(future);local newer=ns.CreateAtlasJournal(future)
            newer.subzones:Observe();assert(snapshot(future)==before)
        ''')

    def test_hidden_background_observer_records_indoor_and_poll_changes(self):
        self.lua.execute('''
            shell:ShowSection('test');assert(not m.map:IsVisible())
            name='Forest';px=.401;c.subzoneObserver.scripts.OnEvent(c.subzoneObserver,'ZONE_CHANGED_INDOORS')
            assert(#s:Crossings(101)==1 and not j.state.showSubzones)
            name='Meadow';px=.4;c.subzoneObserver.scripts.OnUpdate(c.subzoneObserver,.25)
            assert(#s:Crossings(101)==2)
        ''')

    def test_geometry_is_unseeded_non_overlapping_and_neighbours_differ(self):
        self.lua.execute('''
            local empty=S.Build({});assert(#empty.strips==0 and #empty.names==0)
            local one=S.Build({crossing('Meadow','Forest',5000,5000)})
            assert(#one.strips==0 and one.areas.Meadow.colourID~=one.areas.Forest.colourID)
            local line=S.Build({crossing('Meadow','Forest',3000,3000),crossing('Meadow','Forest',5000,3000),crossing('Meadow','Forest',7000,3000)})
            assert(#line.strips==0,'Collinear boundaries do not enclose an area')
            local model=S.Build(ring());assert(#model.strips>0 and model:At(5000,5000).name=='Meadow')
            assert(not model:At(1000,1000),'Do not extrapolate across unseen map')
            local occupied={}
            for _,strip in ipairs(model.strips) do
                for x=strip.x,strip.x+strip.width-1 do
                    local key=x..':'..strip.y;assert(not occupied[key]);occupied[key]=true
                end
            end
            for _,a in pairs(model.areas) do
                for name in pairs(a.neighbours) do assert(a.colourID~=model.areas[name].colourID) end
            end
            -- A dense graph cannot wrap a short palette and reuse neighbour colours.
            local rows={}
            for i=1,10 do for k=i+1,10 do rows[#rows+1]=crossing('Area '..i,'Area '..k,5000,5000) end end
            local dense=S.Build(rows);local used={}
            for _,a in pairs(dense.areas) do assert(not used[a.colourID]);used[a.colourID]=true end
        ''')

    def test_sparse_map_uses_unique_accents_deterministically(self):
        self.lua.execute("""
            local rows={}
            for i=1,S.MAX_AREAS-1 do rows[#rows+1]=crossing('Hub','Area '..i,5000,5000) end
            local model=S.Build(rows);local again=S.Build(rows);local used={};local count=0
            for name,a in pairs(model.areas) do
                assert(a.colourID==again.areas[name].colourID)
                if not used[a.colourID] then used[a.colourID]=true;count=count+1 end
                for neighbour in pairs(a.neighbours) do assert(a.colourID~=model.areas[neighbour].colourID) end
            end
            assert(count==S.MAX_AREAS,'Never reuse a colour, even on non-neighbouring areas')
            local firstTen=S.Build({unpack(rows,1,9)});local seen={}
            for _,a in pairs(firstTen.areas) do
                assert(not seen[a.colourID],'prefer unused colours while available')
                seen[a.colourID]=true
            end
        """)

    def test_new_colour_maximises_nearest_perceptual_distance_and_keeps_existing_colours(self):
        self.lua.execute('''
            local rows={}
            for i=1,12 do rows[i]=crossing('Hub','Zone '..i,5000,5000) end
            local old=S.Build(rows)
            rows[#rows+1]=crossing('Hub','Added first alphabetically',5000,5000)
            local model=S.Build(rows,nil,nil,old)
            local used={}
            for name,area in pairs(old.areas) do
                assert(model.areas[name].colourID==area.colourID,'New discoveries must not recolour existing areas')
                used[area.colourID]=true
            end
            local function distanceToClosest(rgb)
                local best=math.huge
                for _,area in pairs(old.areas) do
                    local a,b=rgb.lab,area.colour.lab
                    best=math.min(best,(a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)
                end
                return best
            end
            local chosen=model.areas['Added first alphabetically']
            local distance=distanceToClosest(chosen.colour)
            assert(not used[chosen.colourID] and distance>0)
            local seen={}
            for i,rgb in ipairs(S.Palette()) do
                local key=string.format('%.8f:%.8f:%.8f',rgb[1],rgb[2],rgb[3])
                assert(not seen[key],'Candidate palette must not contain duplicate RGB colours');seen[key]=true
                assert(rgb.lab[1]>=.60,'Candidate colours must stay bright enough for map artwork')
                if not used[i] then assert(distanceToClosest(rgb)<=distance+1e-12,'Choose the furthest available colour from the entire existing set') end
            end
        ''')

    def test_checkbox_render_pool_hover_and_map_isolation(self):
        self.lua.execute('''
            s.store[101]=ring();s:Changed(101)
            local width,height=m.map:GetWidth(),m.map:GetHeight();local point=m.map.point
            m.subzones:SetChecked(true);click(m.subzones)
            assert(j.state.showSubzones and m.map.subzoneModel and #m.map.subzoneTextures>0)
            assert(m.map:GetWidth()==width and m.map:GetHeight()==height and m.map.point==point)
            local count=#objects;local textures=#m.map.subzoneTextures
            for i=1,5 do c:Refresh() end
            assert(#objects==count and #m.map.subzoneTextures==textures)
            m.map.left=100;m.map.top=700
            local left,top=m.map:GetLeft(),m.map:GetTop();local scale=m.map:GetEffectiveScale()
            cursorX=(left+.3*width)*scale;cursorY=(top-.3*height)*scale
            m.map.scripts.OnEnter(m.map)
            local lines='';for _,v in ipairs(GameTooltip.lines) do lines=lines..v.text end
            assert(lines:find('Meadow -> Forest',1,true))
            m.map.scripts.OnLeave(m.map);assert(not GameTooltip:IsShown())
            c:SetZone(102,'Synthetic hills');assert(#m.map.subzoneModel.names==0)
            for _,t in ipairs(m.map.subzoneTextures) do assert(not t:IsVisible()) end
            c:SetZone(101,'Synthetic coast');assert(#m.map.subzoneModel.names==3)
            m.subzones:SetChecked(false);click(m.subzones)
            assert(not m.map.subzoneModel and #s:Crossings(101)==4)
            for _,t in ipairs(m.map.subzoneDots) do assert(not t:IsVisible()) end
            for _,t in ipairs(m.map.subzoneLabels) do assert(not t:IsVisible()) end
            m.subzones:SetChecked(true);click(m.subzones)
            C_Map.GetMapArtLayers=function() return nil end;m.map:Invalidate();c:Refresh()
            assert(not m.map.subzoneModel,'Unavailable map art must hide overlay')
        ''')

    def test_bounded_storage_and_invalid_saved_records(self):
        self.lua.execute('''
            s.store[101]={false,{mapID=101,from='bad'}}
            assert(#s:Crossings(101)==0)
            s.store[101]={};S.MAX_CROSSINGS=1
            assert(sample('Forest',.401,.4));assert(not sample('Hill',.402,.4))
            assert(#s:Crossings(101)==1)
        ''')

    def test_isolated_dots_stay_small_and_disappear_when_incorporated(self):
        self.lua.execute('''
            s.store[101]={crossing('Meadow','Forest',3000,3000)};s:Changed(101)
            m.subzonePoints:SetChecked(false);click(m.subzonePoints)
            m.subzones:SetChecked(true);click(m.subzones)
            local dot=m.map.subzoneDots[1]
            assert(dot:IsShown() and dot:GetWidth()*m.map.zoom==3)
            m.map:ZoomBy(20)
            assert(m.map.zoom==4 and dot:GetWidth()*m.map.zoom==3,'Zoom must not enlarge isolated samples')
            local rows=ring();rows[#rows+1]=crossing('Cave','Pass',9000,9000)
            s.store[101]=rows;s:Changed(101);c:Refresh()
            local model=m.map.subzoneModel
            for i=1,4 do assert(model.covered[i],'Boundary and interior evidence must stop displaying dots') end
            assert(not model.covered[5],'An unrelated isolated sample still needs a dot')
            local shown=0
            for _,t in ipairs(m.map.subzoneDots) do
                if t:IsShown() then shown=shown+1;assert(t:GetWidth()*m.map.zoom==3) end
            end
            assert(shown==1 and #s:Crossings(101)==5,'Hiding dots must preserve the recorded samples')
            s.store[101]=ring();s:Changed(101);c:Refresh()
            for _,t in ipairs(m.map.subzoneDots) do assert(not t:IsVisible()) end
            s.store[101]={crossing('Meadow','Forest',3000,3000)};s:Changed(101);c:Refresh()
            dot=m.map.subzoneDots[1];assert(dot:IsShown() and dot:GetWidth()*m.map.zoom==3,'Reused dots must retain constant size')
            m.map:ZoomBy(-20);assert(dot:GetWidth()==3)
        ''')

    def test_independent_labels_size_brightness_and_persistence(self):
        self.lua.execute('''
            s.store[101]=ring();s:Changed(101)
            local initial=snapshot(s.store)
            local point=m.map.point;local width,height=m.map:GetWidth(),m.map:GetHeight()
            assert(m.labelSize.track.colorTexture and m.brightness.track.colorTexture)
            m.subzoneLabels:SetChecked(true);click(m.subzoneLabels)
            assert(not j.state.showSubzones and m.map.subzoneLabels[1]:IsShown())
            assert(#m.map.subzoneTextures==0 and #m.map.subzoneTriangles==0)
            local label=m.map.subzoneLabels[1]
            assert(label.fontSize==4 and m.labelSize.valueLabel:GetText()=='4','Unsaved label size must default to 4 in the map and slider')
            assert(label.fontFlags=='OUTLINE','Use a thin outline without MONOCHROME or THICKOUTLINE')
            m.labelSize.scripts.OnValueChanged(m.labelSize,20)
            label=m.map.subzoneLabels[1];assert(label.fontSize==20 and label:GetHeight()==24 and j.state.subzoneLabelSize==20)
            m.labelSize.scripts.OnValueChanged(m.labelSize,2)
            label=m.map.subzoneLabels[1];assert(label.fontSize==2 and label:GetHeight()==6 and j.state.subzoneLabelSize==2)
            assert(label.fontFlags=='OUTLINE','Outline must survive font-size edits and buffer swaps')
            m.subzones:SetChecked(true);click(m.subzones)
            m.subzoneLabels:SetChecked(false);click(m.subzoneLabels)
            assert(m.map.subzoneTextures[1]:IsShown() and not label:IsVisible())
            local colour=snapshot(m.map.subzoneTextures[1].colorTexture)
            C_MapExplorationInfo={GetExploredMapTextures=function() return {{textureWidth=128,textureHeight=128,offsetX=0,offsetY=0,fileDataIDs={7777}}} end}
            m.map:Invalidate();c:Refresh()
            m.brightness.scripts.OnValueChanged(m.brightness,.4)
            local base,overlay=0,0
            for _,o in ipairs(objects) do
                if o.parent==m.map.canvas and type(o.texture)=='number' and o:IsShown() then
                    if o.texture==7777 then overlay=overlay+1 else base=base+1 end
                    assert(o.vertexColor[1]==.4 and o.vertexColor[2]==.4 and o.vertexColor[3]==.4)
                end
            end
            assert(base==12 and overlay==1)
            assert(snapshot(m.map.subzoneTextures[1].colorTexture)==colour)
            assert(m.map.point==point and m.map:GetWidth()==width and m.map:GetHeight()==height)
            local reload=ns.CreateAtlasJournal(saved)
            assert(reload.state.mapBrightness==.4 and reload.state.subzoneLabelSize==2 and reload.state.showSubzoneLabels==false)
            assert(snapshot(s.store)==initial,'Display controls cannot change crossing evidence')
            local old=ns.CreateAtlasJournal({settings={showSubzones=true}})
            assert(old.state.showSubzoneLabels,'Preserve visible labels for existing enabled overlays')
            m.labelSize.scripts.OnValueChanged(m.labelSize,100)
            m.brightness.scripts.OnValueChanged(m.brightness,0/0)
            assert(j.state.subzoneLabelSize==2 and j.state.mapBrightness==.4)
        ''')

    def test_points_toggle_is_independent_persistent_and_reuses_geometry(self):
        self.lua.execute('''
            s.store[101]=ring();s.store[101][5]=crossing('Cave','Pass',9000,9000);s:Changed(101)
            local evidence=snapshot(s.store)
            assert(not j.state.showSubzonePoints and not m.subzonePoints:GetChecked())
            m.subzonePoints:SetChecked(true);click(m.subzonePoints)
            assert(j.state.showSubzonePoints and not j.state.showSubzones and not j.state.showSubzoneLabels)
            assert(m.map.subzoneDots[1]:IsVisible() and #m.map.subzoneDots==5,'Checked must show all points even without shading')
            assert(#m.map.subzoneTextures==0 and #m.map.subzoneTriangles==0 and #m.map.subzoneLabels==0)
            local model=m.map.subzoneModel
            local build=S.Build
            S.Build=function() error('Display toggles cannot rebuild unchanged geometry') end
            m.subzones:SetChecked(true);click(m.subzones)
            m.subzoneLabels:SetChecked(true);click(m.subzoneLabels)
            -- Exercise both reusable buffers and a change during queued painting.
            autoSettle=false
            local clock=0;function debugprofilestop() clock=clock+.6;return clock end
            m.subzonePoints:SetChecked(false);click(m.subzonePoints)
            S.Step()
            assert(m.map.subzonePending,'Exercise cancellation part-way through painting')
            m.subzonePoints:SetChecked(true);click(m.subzonePoints);settle()
            j.state.subzoneLabelSize=14;m.map:RenderSubzones();settle()
            assert(m.map.subzoneDots[1]:IsVisible())
            autoSettle=true
            for i=1,4 do
                m.subzonePoints:SetChecked(i%2==1);click(m.subzonePoints)
                local visible=0;for _,dot in ipairs(m.map.subzoneDots) do if dot:IsVisible() then visible=visible+1 end end
                assert(visible==(i%2==1 and 5 or 1),'Unchecked retains automatic isolated dots')
                assert(m.map.subzoneTextures[1]:IsVisible() and m.map.subzoneLabels[1]:IsVisible())
                assert(m.map.subzoneModel==model)
            end
            assert(snapshot(s.store)==evidence,'Visibility cannot change saved evidence')
            local reload=ns.CreateAtlasJournal(saved)
            assert(reload.state.showSubzonePoints==false and reload.state.showSubzones and reload.state.showSubzoneLabels)
            local old=ns.CreateAtlasJournal({settings={showSubzones=true}})
            assert(old.state.showSubzonePoints,'Existing visible points survive upgrade')
            local optedOut=ns.CreateAtlasJournal({settings={showSubzones=true,showSubzonePoints=false}})
            assert(not optedOut.state.showSubzonePoints,'A saved opt-out survives reload')
            S.Build=build
            assert(sample('Forest',.401,.4) and #s:Crossings(101)==6,'Hidden points must keep recording')
        ''')

    def test_smooth_contours_cover_hull_without_cell_steps_and_bound_complexity(self):
        self.lua.execute('''
            local model=S.Build(ring());assert(model.grid==64 and #model.triangles>0)
            local total,refined=0,false;local step=10000/model.grid
            for _,strip in ipairs(model.strips) do total=total+strip.width*step*step end
            for _,t in ipairs(model.triangles) do
                local a,b,c=t[1],t[2],t[3]
                total=total+math.abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))/2
                for _,v in ipairs(t) do
                    if math.abs(v.x/step-math.floor(v.x/step+.5))>.01 then refined=true end
                end
            end
            assert(refined and math.abs(total-16000000)<5000,'Contour covers the hull to sub-pixel precision')
            for _,buffer in ipairs(m.map.subzoneBuffers) do
                local create=buffer.frame.CreateTexture
                function buffer.frame:CreateTexture(...)
                    local t=create(self,...)
                    function t:SetVertexOffset(i,x,y) self.offsets=self.offsets or {};self.offsets[i]={x,y} end
                    return t
                end
            end
            s.store[101]=ring();s:Changed(101)
            m.subzones:SetChecked(true);click(m.subzones)
            for _,t in ipairs(m.map.subzoneTriangles) do
                local o=t.offsets;assert(o and #o==4 and t:IsShown())
                local ax,ay=o[1][1],o[1][2]
                local bx,by=o[2][1],o[2][2]-t:GetHeight()
                local cx,cy=o[3][1]+t:GetWidth(),o[3][2]
                assert((bx-ax)*(cy-ay)-(by-ay)*(cx-ax)>0,'Native triangle winding must face the viewer')
                assert(t.colorTexture[4]==.4)
            end
            local rows={}
            for i=1,4096 do rows[i]=crossing('Meadow','Forest',10+(i*127)%9990,(i*191)%10000) end
            local dense=S.Build(rows)
            assert(#dense.triangles<=S.MAX_TRIANGLES and dense.grid>=8)
            for _,a in pairs(dense.areas) do
                for name in pairs(a.neighbours) do assert(a.colourID~=dense.areas[name].colourID) end
            end
        ''')

    def test_ten_yard_spacing_respects_border_pair_map_scale_and_reload(self):
        self.lua.execute('''
            C_Map.GetMapWorldSize=function() return 1000,2000 end
            local data={subzones={[101]={
                crossing('A','B',1000,1000),crossing('B','A',1050,1000),
                crossing('A','C',1050,1000),crossing('A','B',1101,1000),
                crossing('A','B',1000,1060),{invalid='preserve'}}}}
            data.subzones[101].metadata='preserve'
            local journal=ns.CreateAtlasJournal(data);local survey=journal.subzones
            survey:Index(101,true)
            assert(#data.subzones[101]==6,'Compaction must not run in the caller frame')
            settle()
            assert(#data.subzones[101]==5 and data.subzones[101][2].to=='C')
            assert(data.subzones[101][3].x==1101 and data.subzones[101][4].y==1060)
            assert(data.subzones[101][5].invalid=='preserve' and data.subzones[101].metadata=='preserve')
            local before=snapshot(data.subzones)
            ns.CreateAtlasJournal(data).subzones:Index(101,true);settle()
            assert(snapshot(data.subzones)==before,'Thinning must be idempotent after reload')

            local live=ns.CreateAtlasJournal({}).subzones
            name='A';px=.1;py=.1;live:Observe()
            name='B';px=.101;assert(live:Observe())
            name='A';px=.106;assert(not live:Observe(),'Reverse crossing within ten yards is redundant')
            name='B';px=.111;assert(not live:Observe(),'Ten-yard threshold is inclusive')
            name='A';px=.112;assert(live:Observe(),'Keep a point more than ten yards from retained evidence')
            name='C';px=.113;assert(live:Observe(),'Different borders at the same position remain distinct')
            mapID=102;name='A';live:Observe();name='B';px=.114;assert(live:Observe())
            assert(#live:Crossings(101)==3 and #live:Crossings(102)==1)
        ''')

    def test_deferred_index_preserves_pending_crossings_and_flushes_on_logout(self):
        self.lua.execute('''
            local data={subzones={[101]={}}}
            for i=1,1000 do data.subzones[101][i]=crossing('A','B',i*9,1000) end
            C_Map.GetMapWorldSize=function() return 1000,2000 end
            local journal=ns.CreateAtlasJournal(data);local survey=journal.subzones
            name='C';px=.4;py=.4;survey:Observe(true)
            assert(not survey.index[101].ready)
            name='D';px=.401;survey:Observe(true)
            assert(#survey.index[101].pending==3 and #data.subzones[101]==1000,'Queue both interior observations and the genuine crossing')
            local observer=S.Track(journal)
            observer.scripts.OnEvent(observer,'PLAYER_LOGOUT')
            local rows=survey:Crossings(101)
            assert(survey.index[101].ready and #rows<1000)
            assert(rows[#rows].from=='C' and rows[#rows].to=='D' and rows[#rows].x==4010)
            local samples=survey:Samples(101)
            assert(samples[#samples-1].kind=='interior' and samples[#samples-1].name=='C','Retain the first pending interior sample')
            assert(samples[#samples].to=='D','Reject the nearby pending interior sample without suppressing its crossing')
            local value=snapshot(data);settle();assert(snapshot(data)==value,'Cancelled index job must not commit twice')
            local future={schema=999,subzones=data.subzones}
            value=snapshot(future);local newer=ns.CreateAtlasJournal(future).subzones
            newer:Index(101,true);newer:Flush();settle();assert(snapshot(future)==value)

            C_Map.GetMapWorldSize=nil
            local partial={subzones={[101]={crossing('A','B',1000,1000)}}}
            local pending=ns.CreateAtlasJournal(partial).subzones
            local index=pending:Index(101,true)
            for i=1,600 do index.pending[i]=crossing('C','D',i*10,2000) end
            S.Step();assert(not index.ready and #partial.subzones[101]>1,'Exercise a partially committed pending queue')
            name='E';px=.4;pending:Observe(true);name='F';px=.401;pending:Observe(true)
            pending:Flush()
            local final=partial.subzones[101]
            assert(final[#final].from=='E' and final[#final].to=='F','A late crossing must survive a mid-drain logout')
            local seen={}
            for _,row in ipairs(final) do
                local key=row.from..row.to..math.floor(row.x/25)..':'..math.floor(row.y/25)
                assert(not seen[key],'Logout restart must not duplicate already committed rows');seen[key]=true
            end
            local snapshotAfter=snapshot(partial);settle();assert(snapshot(partial)==snapshotAfter)
        ''')

    def test_interior_sampling_uses_yards_without_fabricating_crossings(self):
        self.lua.execute('''
            local dimensions=0
            C_Map.GetMapWorldSize=function() dimensions=dimensions+1;return 1000,2000 end
            local data={};local survey=ns.CreateAtlasJournal(data).subzones
            name='Mine';px=.1;py=.1
            assert(survey:Observe() and #survey:Samples(101)==1,'Seed the current area without needing a crossing')
            assert(not survey:Observe(),'Stationary polling must not add data')
            px=.15;assert(not survey:Observe(),'Exactly 50 yards is too close')
            px=.2;assert(survey:Observe(),'Exactly 100 horizontal yards permits a sample')
            py=.125;assert(not survey:Observe(),'Use the map height for vertical yard distances')
            py=.15;assert(survey:Observe(),'Exactly 100 vertical yards permits a sample')
            assert(#survey:Samples(101)==3 and #survey:Crossings(101)==0)
            local model=S.Build(survey:Samples(101))
            assert(model.areas.Mine.hasFill and model:At(1800,1100).name=='Mine','Interior samples must expand the estimated region')
            assert(not next(model.areas.Mine.neighbours),'Interior data must not invent another sub-zone')
            px=.1;py=.1;assert(not survey:Observe(),'Returning to a sampled location must not grow saved data')
            local before=snapshot(data.subzones)
            local restored=ns.CreateAtlasJournal(data).subzones
            assert(not restored:Observe() and snapshot(data.subzones)==before,'Reload must not duplicate the initial sample')
            assert(dimensions==2,'Read dimensions once per map index, not each poll')
            mapID=102;assert(restored:Observe(),'Maps have independent interior coverage')
            name='Tunnel';assert(restored:Observe(),'A nearby name change still records its crossing')
            assert(#restored:Crossings(102)==1,'The real name change still records a crossing')
            assert(#restored:Samples(102)==2,'A different area does not bypass interior spacing')
            px=nil;assert(not restored:Observe(),'Unavailable coordinates cannot become interior evidence')
            local future={schema=999};ns.CreateAtlasJournal(future).subzones:Observe()
            assert(not future.subzones)
        ''')

    def test_interior_spacing_checks_all_samples_but_does_not_restrict_crossings(self):
        self.lua.execute('''
            C_Map.GetMapWorldSize=function() return 1000,2000 end
            local data={subzones={[101]={crossing('A','B',1000,1000),
                {kind='interior',mapID=101,name='Elsewhere',x=5000,y=1000,at=100}}}}
            local survey=ns.CreateAtlasJournal(data).subzones
            name='Mine';px=.15;py=.1
            assert(not survey:Observe(),'An existing crossing blocks an interior sample within or exactly 50 yards')
            px=.1501
            assert(survey:Observe(),'50.1 yards is eligible immediately after a rejected attempt')
            survey:Reset();px=.55
            assert(not survey:Observe(),'Interior samples from other named areas also block sampling')
            survey:Reset();px=.6
            assert(survey:Observe(),'Allow an interior sample outside the exclusion radius')
            name='Tunnel';px=.601
            assert(survey:Observe(),'A crossing can be recorded beside an interior sample')
            assert(#survey:Crossings(101)==2)
            assert(#survey:Samples(101)==5,'The crossing must not also create a nearby interior sample')
        ''')

    def test_interior_capture_is_bounded_continues_hidden_and_has_honest_hover(self):
        self.lua.execute('''
            C_Map.GetMapWorldSize=function() return 1000,2000 end
            s.index={};s:Reset();name='Mine';px=.1;py=.1
            shell:ShowSection('test')
            c.subzoneObserver.scripts.OnUpdate(c.subzoneObserver,.25)
            assert(#s:Samples(101)==1 and #s:Crossings(101)==0)
            S.MAX_INTERIORS=1;px=.3;c.subzoneObserver.scripts.OnUpdate(c.subzoneObserver,.25)
            assert(#s:Samples(101)==1,'Interior sample budget must be bounded')
            name='Tunnel';px=.301;c.subzoneObserver.scripts.OnEvent(c.subzoneObserver,'ZONE_CHANGED')
            assert(#s:Crossings(101)==1,'The interior budget must leave room for border observations')
            j.state.showSubzonePoints=true;shell:ShowSection('atlas');settle()
            m.map.left=100;m.map.top=700
            cursorX=(100+.1*m.map:GetWidth())*m.map:GetEffectiveScale()
            cursorY=(700-.1*m.map:GetHeight())*m.map:GetEffectiveScale()
            m.map.scripts.OnEnter(m.map)
            local lines='';for _,v in ipairs(GameTooltip.lines) do lines=lines..v.text end
            assert(lines:find('Mine — interior observation',1,true) and not lines:find('Crossed at',1,true))
            local rows=s:Samples(101);rows[1].name='Detached'
            assert(s:Samples(101)[1].name=='Mine','Rendering receives detached copies')
            local invalid=crossing('A','B',1000,1000);invalid.kind='interior'
            s.store[101][#s.store[101]+1]=invalid;s.index={}
            s:Index(101);assert(#s:Samples(101)==2,'Malformed typed samples must be preserved but ignored')
        ''')

    def test_checked_points_show_all_samples_over_shading(self):
        self.lua.execute('''
            s.store[101]=ring()
            for _,p in ipairs({{4000,4000},{4100,4000},{6000,6000}}) do
                s.store[101][#s.store[101]+1]={kind='interior',mapID=101,name='Meadow',x=p[1],y=p[2],at=100}
            end
            s:Changed(101);j.state.showSubzones=true;j.state.showSubzonePoints=true;c:Refresh()
            local model=m.map.subzoneModel
            assert(model.areas.Meadow.hasFill)
            for i=1,7 do assert(model.covered[i],'All samples qualify for automatic suppression') end
            local function visibleDots()
                local n=0;for _,dot in ipairs(m.map.subzoneDots) do
                    if dot:IsVisible() then n=n+1;assert(dot:GetWidth()*m.map.zoom==3) end
                end;return n
            end
            assert(visibleDots()==7,'Checked must show every sample without coarse-cell merging')
            m.map:ZoomBy(20);assert(visibleDots()==7)
            for i=1,4 do
                m.subzonePoints:SetChecked(i%2==0);click(m.subzonePoints)
                assert(visibleDots()==(i%2==0 and 7 or 0),'Both buffers must respect the toggle')
            end
            m.subzones:SetChecked(false);click(m.subzones);assert(visibleDots()==7)
            m.subzonePoints:SetChecked(false);click(m.subzonePoints);assert(visibleDots()==0)
            assert(#s:Samples(101)==7 and #s:Crossings(101)==4,'Display changes preserve evidence')
        ''')

    def test_automatic_mapping_toggle_preserves_manual_points(self):
        self.lua.execute(r'''
            assert(m.automaticMapping:GetChecked(),'Automatic mapping defaults on')
            C_Map.GetMapWorldSize=function() return 1000,2000 end
            s.index={};s.store[101]={}
            m.automaticMapping:SetChecked(false);click(m.automaticMapping)
            assert(j.state.automaticMapping==false)
            assert(not sample('Meadow',.2,.2) and #s:Samples(101)==0)
            assert(s:RecordPoint() and #s:Samples(101)==1,'Manual recording remains enabled')
            local fresh=S.Attach(j)
            assert(not fresh:Observe() and j.state.automaticMapping==false,'Preference survives attachment')
            j.subzones=s
            m.automaticMapping:SetChecked(true);click(m.automaticMapping)
            sample('Forest',.7,.7)
            assert(#s:Crossings(101)==0,'Resume cannot bridge movement while disabled')
            assert(#s:Samples(101)==2)
        ''')

    def test_manual_points_enforce_fifteen_yards_and_survive_reload(self):
        self.lua.execute(r'''
            C_Map.GetMapWorldSize=function() return 1000,2000 end
            s.index={};s.store[101]={};name='Meadow';px=.4;py=.4
            assert(s:RecordPoint())
            px=.414;assert(not s:RecordPoint(),'Reject points within 15 yards')
            px=.416;assert(s:RecordPoint(),'Manual points may be closer than automatic 50-yard samples')
            py=.408;assert(s:RecordPoint(),'Use map height for north-south distances')
            assert(#s.store[101]==3)
            local fresh=S.Attach(j);fresh:Index(101)
            assert(#fresh.store[101]==3,'Reload cannot compact deliberate dense samples')
            name='Other area';assert(not fresh:RecordPoint(),'Spacing applies across sub-zone names')
            fresh.store[102]={crossing('A','B',5000,5000)};mapID=102;px=.51;py=.5
            assert(not fresh:RecordPoint(),'Crossing samples also reserve space')
            mapID=103;C_Map.GetMapWorldSize=nil
            assert(not fresh:RecordPoint(),'Never guess a yard distance')
        ''')

    def test_label_placement_searches_free_space_before_culling(self):
        self.lua.execute(r'''
            local placed={}
            for i=1,12 do
                local p=S.PlaceLabel(placed,120,100,25,12,60,50)
                assert(p,'Clustered names must move into available space')
                assert(p.x>=12.5 and p.x<=107.5 and p.y>=6 and p.y<=94)
                for _,other in ipairs(placed) do
                    assert(math.abs(p.x-other.x)>=30-0.000001 or math.abs(p.y-other.y)>=14-0.000001)
                end
                placed[#placed+1]=p
            end
            local p,d=S.PlaceLabel({},120,100,25,12,60,50)
            assert(p.x==60 and p.y==50 and d==0)
            assert(not S.PlaceLabel({{x=60,y=50,width=120,height=100}},120,100,25,12,60,50))
        ''')

    def test_colours_survive_reload_and_new_discoveries(self):
        self.lua.execute(r'''
            s.store[101]=ring();s:Changed(101);j.state.showSubzones=true;c:Refresh()
            local original=m.map.subzoneModel
            assert(j.saved.subzoneColours.maps[101])
            local fresh=S.Attach(j)
            local rows=ring();rows[#rows+1]=crossing('Meadow','A new area',5000,5000)
            local restored=S.Build(rows,nil,nil,fresh:RecallColours(101))
            local used={}
            for name,a in pairs(restored.areas) do
                assert(not used[a.colourID]);used[a.colourID]=true
                if original.areas[name] then assert(a.colourID==original.areas[name].colourID) end
            end
            fresh:RememberColours(101,restored)
            local nextSession=S.Attach(j)
            local again=S.Build(rows,nil,nil,nextSession:RecallColours(101))
            for name,a in pairs(restored.areas) do assert(again.areas[name].colourID==a.colourID) end
            local readonly={readOnly=true,saved=j.saved,state={}}
            S.Attach(readonly):RememberColours(102,restored)
            assert(not j.saved.subzoneColours.maps[102])
        ''')

    def test_labels_measure_text_and_wrap_before_hiding(self):
        self.lua.execute(r'''
            local function observation(name,x,y)
                return {kind='interior',mapID=101,name=name,x=x,y=y,at=100}
            end
            s.store[101]={observation('A',4000,5000),observation('Silver Stream Mine',5100,5000),
                observation('Silver Stream Mining Outpost',8000,8000),observation(string.rep('W',100),1000,1000)}
            s:Changed(101);j.state.showSubzoneLabels=true;j.state.subzoneLabelSize=12;c:Refresh()
            local visible={};local count=0
            for _,label in ipairs(m.map.subzoneLabels) do
                if label:IsVisible() then
                    visible[label:GetText()]=label;count=count+1
                    assert(label.fontFlags=='OUTLINE' and label.wordWrap and not label.nonSpaceWrap)
                end
            end
            assert(count==3,'Only the unbreakable oversized name should be hidden')
            assert(visible.A and visible['Silver\nStream Mine'],'Try two lines when a one-line label would collide')
            local wrapped
            for text,label in pairs(visible) do if text:gsub('\n',' ')=='Silver Stream Mining Outpost' then wrapped=label end end
            assert(wrapped and wrapped:GetWidth()<=m.map:GetWidth(),'Long names may use the full map width')
            assert(visible.A:GetWidth()<20,'Short names should not reserve a full fixed-width collision box')
            local objectsBefore=#objects
            for i=1,4 do c:Refresh() end
            assert(#objects==objectsBefore,'Unchanged labels reuse their font strings')
        ''')

    def test_worker_slices_atomic_updates_and_handles_crossings_during_build(self):
        self.lua.execute('''
            local time=0;function debugprofilestop() time=time+.1;return time end
            autoSettle=false
            s.store[101]=ring();s:Changed(101);j.state.showSubzones=true
            local builds=0;local build=S.Build
            S.Build=function(...) builds=builds+1;return build(...) end
            m.map:RenderSubzones()
            assert(builds==0 and not m.map.subzoneModel,'Requesting an update cannot build geometry inline')
            S.Step();assert(m.map.subzonePending and not m.map.subzoneModel,'A build must yield before publication')
            local pending=m.map.subzonePending
            local p=crossing('Meadow','Forest',8000,4000);s.store[101][5]=p;s:Changed(101)
            m.map:RenderSubzones();assert(m.map.subzonePending==pending,'New crossings must not repeatedly restart an in-flight build')
            settle();assert(#m.map.subzoneModel.rows==5 and not m.map.subzonePending)
            local front=m.map.subzoneModel;local count=builds
            s:Changed(102);m.map:RenderSubzones();settle()
            assert(builds==count and m.map.subzoneModel==front,'Other maps cannot invalidate the displayed mesh')
            s.store[101][6]=crossing('Meadow','Hill',2000,4000);s:Changed(101)
            m.map:RenderSubzones();S.Step()
            assert(m.map.subzoneModel==front,'Keep the completed overlay while preparing a replacement')
            c:SetZone(102,'Synthetic hills');settle()
            assert(#m.map.subzoneModel.rows==0,'A cancelled job must not paint its old map')
            c:SetZone(101,'Synthetic coast');S.Step()
            shell:ShowSection('test');settle()
            assert(not m.map:IsVisible() and not S.worker:IsShown())
            shell:ShowSection('atlas');settle();assert(#m.map.subzoneModel.rows==6)
            local n=builds
            for i=1,4 do j.state.subzoneLabelSize=i+8;m.map:RenderSubzones();settle() end
            assert(builds==n,'Changing label size must reuse the completed mesh')
        ''')

    def test_capture_avoids_metadata_reads_and_worker_failure_does_not_spin(self):
        self.lua.execute('''
            C_Map.GetMapInfo=function() error('Sampling must not read display metadata') end
            C_Map.GetMapWorldSize=function() error('An already indexed map must not query dimensions repeatedly') end
            local reads=0;local copy=s.Crossings
            s.Crossings=function(...) reads=reads+1;return copy(...) end
            for i=1,20 do sample('Meadow',.4+i*.0001,.4) end
            assert(sample('Forest',.403,.4) and reads==0,'Capturing a crossing must not copy the saved history')
            autoSettle=false;j.state.showSubzones=true
            S.Build=function() error('Synthetic build failure') end
            m.map:RenderSubzones()
            for i=1,200 do if not S.worker:IsShown() then break end;S.Step() end
            assert(m.map.subzoneError and not S.worker:IsShown())
            for i=1,10 do m.map:RenderSubzones() end
            assert(not S.worker:IsShown(),'An unchanged failing request must not retry every player tick')
        ''')

    def test_cancelled_jobs_release_snapshots_and_double_buffers_stop_growing(self):
        self.lua.execute('''
            local weak=setmetatable({},{__mode='v'})
            local job=S.Queue(function(checkpoint)
                local held={};weak[1]=held
                for i=1,10000 do checkpoint() end
                return held
            end)
            S.Step();assert(weak[1])
            S.Cancel(job);collectgarbage('collect');assert(not weak[1],'Cancelled coroutine must release its snapshot')
            settle()
            s.store[101]=ring();s:Changed(101);j.state.showSubzones=true;c:Refresh()
            weak[2]=m.map.subzoneModel
            for i=1,2 do s:Changed(101);c:Refresh() end
            collectgarbage('collect');assert(not weak[2],'Only the two reusable buffers may retain completed meshes')
            local count=#objects
            for i=1,8 do s:Changed(101);c:Refresh() end
            assert(#objects==count,'Native texture pools must plateau after both buffers are warm')
            j.state.showSubzones=false;c:Refresh();assert(not S.worker:IsShown())
            for _,buffer in ipairs(m.map.subzoneBuffers) do assert(not buffer.frame:IsShown()) end
        ''')


if __name__ == '__main__':
    unittest.main()
