"""Atlas-only storage, navigation, maps, adapters and untrusted report boundary."""
import unittest
from atlas_test_harness import new_atlas
from ui_test_harness import ROOT


class AtlasDataTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_atlas()

    def test_sparse_arrays_cannot_silently_discard_route_stops(self):
        self.lua.execute('''
            -- Lua 5.1 can report #t == 4 for keys 1,2,4,6. Comparing the
            -- length with the key count therefore does not prove contiguity.
            for mask=0,1023 do
                local values,count={},0
                for i=1,10 do
                    if math.floor(mask/2^(i-1))%2==1 then values[i]='x';count=count+1 end
                end
                local contiguous=0;for _ in ipairs(values) do contiguous=contiguous+1 end
                assert(A.Array(values,10)==(contiguous==count),'Sparse list passed validation')
            end
            local route=fixture('Route','route');local id=assert(j:Save(route))
            route.stops={}
            for _,i in ipairs({1,2,4,6}) do route.stops[i]={name='Waypoint '..i} end
            assert(not j:Save(route,id),'Invalid edit must be rejected, not truncated')
            assert(#j:Get(id).stops==0,'Rejected edit must preserve saved data')
            local report=assert(R.Build(j,{title='Test report',region={kind='selection',name='Test region'},
                records={[id]=true}},'Test author'))
            report.records[1].stops=route.stops
            assert(not R.Validate(report) and not R.Encode(report),'Reports must reject sparse lists too')
        ''')

    def test_crud_stable_ids_reload_and_non_destructive_migration(self):
        self.lua.execute('''
            local other={bestiary={private='keep'},gathering={private='keep'}}
            local before=snapshot(other)
            saved.unknown={keep=true};saved.schema=0
            j=ns.CreateAtlasJournal(saved)
            local id=assert(j:Save(fixture()))
            local e=j:Get(id);assert(e.created==now and not e.explored)
            e.name='Edited synthetic cave';now=now+5;assert(j:Save(e,id)==id)
            local value=snapshot(saved);j=ns.CreateAtlasJournal(saved)
            assert(value==snapshot(saved) and saved.schema==1 and saved.unknown.keep)
            assert(j:Get(id).name=='Edited synthetic cave' and j:Get(id).updated==now)
            e=j:Get(id);e.notes='Detached copy';assert(j:Get(id).notes~='Detached copy')
            assert(j:Delete(id) and not j:Get(id))
            assert(j:Save(fixture())~=id and before==snapshot(other))
            local future={schema=999,records={untouched={anything=true}}}
            local raw=snapshot(future);local newer=ns.CreateAtlasJournal(future)
            assert(newer.readOnly and not newer:Save(fixture()))
            newer:SetLayer('cave',false);assert(snapshot(future)==raw)
        ''')

    def test_positions_unpositioned_and_explicit_exploration(self):
        self.lua.execute('''
            for _,bad in ipairs({-1,10001,0/0,math.huge,'5'}) do
                local e=fixture();e.x=bad;assert(not j:Save(e))
            end
            local e=fixture();e.x=nil;assert(not j:Save(e))
            e.y=nil;e.mapID=nil;local id=assert(j:Save(e));assert(not A.Position(j:Get(id)))
            local updated=j:Get(id);updated.mapID=101;updated.x=0;updated.y=0
            assert(j:Save(updated,id) and A.Position(j:Get(id)) and not j:Get(id).explored)
            updated.explored=true;j:Save(updated,id);assert(j:Get(id).explored)
            local x,y,err=A.Coordinates('1.25','99.99');assert(x==125 and y==9999 and not err)
            x,y,err=A.Coordinates('','');assert(not x and not y and not err)
            x,y,err=A.Coordinates('101','');assert(err)
            px,py=0,0;assert(not A.Position(A.CurrentLocation()))
            px,py=0.3,nil;assert(not A.Position(A.CurrentLocation()))
            C_Map=nil;assert(not A.CurrentLocation().mapID)
        ''')

    def test_search_and_layers_are_independent(self):
        self.lua.execute('''
            local id=j:Save(fixture())
            j:Save(fixture('Synthetic camp','camp',102))
            for _,word in ipairs({'entrance','cave','coast','hollow','lantern','ford','chamber'}) do
                assert(#j:List(word,101,false)==1,word)
            end
            assert(#j:List('',101,false)==1 and #j:List('',101,true)==2)
            for _,category in ipairs(A.categories) do
                j:SetLayer(category.id,false);assert(not j:Layer(category.id))
                assert(#j:List('',101,true)==2)
            end
            j:SetLayer('cave',true);assert(j:Layer('cave') and not j:Layer('camp'))
            local reload=ns.CreateAtlasJournal(saved);assert(reload:Layer('cave') and not reload:Layer('camp'))
        ''')

    def test_routes_order_segments_hidden_categories_and_deleted_stops(self):
        self.lua.execute('''
            local a=j:Save(fixture('First','cave',101,1000,1000))
            local b=j:Save(fixture('Second','crossing',101,2000,2000))
            local route=fixture('Synthetic itinerary','route');route.stops={
                {recordID=a,name='First'},{recordID=b,name='Second'},
                {name='Far waypoint',mapID=102,zone='Synthetic hills',x=100,y=200},
                {name='Return waypoint',mapID=101,zone='Synthetic coast',x=4000,y=5000}}
            local id=j:Save(route);route=j:Get(id)
            local pins,segments=j:RouteMap(route,101);assert(#pins==3 and #segments==1 and pins[3].number==4)
            pins,segments=j:RouteMap(route,102);assert(#pins==1 and #segments==0 and pins[1].number==3)
            j:SetLayer('crossing',false);pins,segments=j:RouteMap(route,101);assert(#pins==2 and #segments==0)
            j:SetLayer('route',false);pins,segments=j:RouteMap(route,101);assert(#pins==0 and #segments==0)
            assert(j:MoveStop(route,4,1) and route.stops[1].name=='Return waypoint')
            assert(not j:MoveStop(route,1,0))
            j:Save(route,id);j:Delete(a);route=j:Get(id)
            assert(#route.stops==4 and j:ResolveStop(route.stops[2]).missing)
            assert(j:InZone(route,102));assert(#j:List('itinerary',102,false)==1)
        ''')

    def test_expeditions_associations_and_missing_references(self):
        self.lua.execute(r'''
            local a=j:Save(fixture());local route=j:Save(fixture('Route','route'))
            local note={name='Synthetic expedition',notes='Long journal',related={a,route},
                zones={{mapID=101,zone='Synthetic coast'},{mapID=102,zone='Synthetic hills'}},
                references={{section='gathering',key='herb:synthetic herb',name='Synthetic herb'}}}
            local id=j:Save(note,nil,true);assert(#j:Associated(a)==1)
            note=j:Get(id,true);note.notes=string.rep('notes\n',800);assert(j:Save(note,id,true))
            local reload=ns.CreateAtlasJournal(saved);assert(#reload:Get(id,true).zones==2)
            j:Delete(a);assert(#j:Get(id,true).related==2 and #j:Associated(a)==1)
            source.entries={};local resolved=refs:Resolve(note.references[1]);assert(resolved.missing)
            assert(j:Delete(id,true) and #j:Associated(a)==0)
        ''')

    def test_plain_text_limits_and_provenance_preservation(self):
        self.lua.execute(r'''
            for _,text in ipairs({'|Hitem:1|hClick|h','|Tfake|t','\0bad',string.rep('x',8001)}) do
                local e=fixture();e.notes=text;assert(not j:Save(e))
            end
            local e=fixture();e.provenance={kind='reported',source='Unverified correspondent'}
            local id=j:Save(e);e=j:Get(id);e.provenance={kind='recorded',source='Me'};j:Save(e,id)
            assert(j:Get(id).provenance.kind=='reported' and not j:Get(id).explored)
            assert(A.Safe('|Hfoo|h')=='¦Hfoo¦h')
        ''')

    def test_adapters_read_only_known_targets_and_existing_navigation(self):
        for name in ['SharingReport.lua', 'BestiaryJournal.lua']:
            self.lua.execute((ROOT/name).read_text(encoding='utf-8'), 'AzerothFieldbook', self.lua.globals().ns)
        self.lua.execute('''
            local best=ns.CreateBestiaryJournal({},function() return 42 end)
            local known=best:Ensure(42,true,'Known synthetic creature');known.category='Beast'
            known.abilities.Hidden={state='pending',note='private hidden claim'}
            best:Ensure(99,true,nil)
            local shell={ShowSection=function(_,section,context) opened=section;openedID=context.creatureID;return true end}
            local adapters=ns.CreateAtlasReferences(best,function() return source end,shell)
            local before=snapshot(best.entries)..snapshot(source)
            local list=adapters:List('');assert(#list==2)
            assert(#adapters:List('Hidden')==0 and #adapters:List('private')==0)
            for _,ref in ipairs(list) do assert(not ref.note and not ref.abilities) end
            local ref={section='bestiary',key='42',name='old name'}
            assert(adapters:Resolve(ref).name=='Known synthetic creature')
            assert(adapters:Open(ref) and opened=='bestiary' and openedID==42)
            local ok,summary=adapters:Open({section='gathering',key='herb:synthetic herb',name='Synthetic herb'})
            assert(not ok and summary:find('Synthetic herb',1,true))
            assert(snapshot(best.entries)..snapshot(source)==before)
            best.entries[42]=nil;assert(adapters:Resolve(ref).missing)
            assert(not adapters:Open({section='future',key='unknown',name='Retained reference'}))
        ''')


class AtlasReportTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_atlas()
        self.lua.execute('''
            a=j:Save(fixture());b=j:Save(fixture('Second synthetic place','crossing',102))
            local route=fixture('Synthetic route','route');route.stops={{recordID=a,name='Entrance'},{recordID=b,name='Crossing'}}
            r=j:Save(route)
            n=j:Save({name='Synthetic expedition',notes='Private expedition journal',related={a,b,r},
                zones={{mapID=101,zone='Synthetic coast'}}},nil,true)
            draft={title='Synthetic report',region={kind='selection',name='Synthetic region'},records={[a]=true,[r]=true},notes={},expeditions={}}
        ''')

    def test_selection_local_ids_privacy_explicit_excerpts_and_round_trip(self):
        self.lua.execute('''
            local e=j:Get(a);e.related={b,r};e.references={{section='gathering',key='herb:synthetic herb',name='Synthetic herb'}};j:Save(e,a)
            local p=assert(R.Build(j,draft,'Synthetic author'))
            assert(#p.records==2 and #p.expeditions==0)
            assert(not p.records[1].notes and not p.records[1].access and #p.records[1].references==0)
            assert(p.records[1].id=='r1' and not p.records[1].recordID)
            assert(#p.records[1].related==1 and p.records[1].related[1]=='r2')
            assert(p.records[2].stops[1].ref=='r1' and not p.records[2].stops[2].ref)
            assert(p.records[2].stops[2].name=='Second synthetic place')
            local preview=R.Preview(p);assert(not preview:find('Private lantern',1,true))
            draft.notes[a]=true;draft.expeditions[n]='Only this excerpt';draft.includeReferences=true
            p=assert(R.Build(j,draft,'Synthetic author'))
            assert(p.records[1].notes=='Private lantern note' and #p.records[1].references==1)
            assert(p.expeditions[1].notes=='Only this excerpt' and #p.expeditions[1].related==2)
            local encoded=assert(R.Encode(p));local decoded=assert(R.Decode(encoded))
            assert(R.Encode(decoded)==encoded and snapshot(decoded)==snapshot(p))
            preview=R.Preview(p);assert(preview:find('Only this excerpt',1,true) and not preview:find('Private expedition journal',1,true))
        ''')

    def test_untrusted_input_schema_types_counts_positions_links_and_bytes(self):
        self.lua.execute(r'''
            local good=assert(R.Build(j,draft,'Synthetic author'))
            local function rejects(change) local p=A.Copy(good);change(p);assert(not R.Validate(p)) end
            rejects(function(p) p.version=2 end)
            rejects(function(p) p.evil='unexpected' end)
            rejects(function(p) p.records[1].name='|Hfoo|h' end)
            rejects(function(p) p.records[1].x=10001 end)
            rejects(function(p) p.records[1].y=nil end)
            rejects(function(p) p.records[1].mapID=0 end)
            rejects(function(p) p.records[1].knowledge.kind='confirmed' end)
            rejects(function(p) p.records[1].related={'sender-local-id'} end)
            rejects(function(p) p.records[2].stops[1].ref='r999' end)
            rejects(function(p) p.records[1].explored=true end)
            rejects(function(p) p.records[2].id=p.records[1].id end)
            rejects(function(p) p.records[3]=p.records[1];p.records[2]=nil end)
            rejects(function(p) p.records[1].notes=string.rep('x',8001) end)
            rejects(function(p) p.region={kind='zone',name='Zone'} end)
            rejects(function(p) p.created=math.huge end)
            rejects(function(p) p.records=setmetatable({}, {}) end)
            for _,bad in ipairs({'return function() end','AFBA2:t0:','AFBA1:t99999999:',
                'AFBA1:s9999999:x','AFBA1:s3:a','AFBA1:n3:nan','AFBA1:b2','AFBA1:t2:s1:as1:bs1:as1:c',
                string.rep('x',131073),R.Encode(good)..'trailing'}) do assert(not R.Decode(bad),bad:sub(1,30)) end
            local deep='s1:a';for i=1,14 do deep='t1:s1:a'..deep end;assert(not R.Decode('AFBA1:'..deep))
            local p=A.Copy(good);p.records={}
            for i=1,201 do local e=A.Copy(good.records[1]);e.id='r'..i;p.records[i]=e end
            assert(not R.Validate(p))
            local large=A.Copy(good);large.records={}
            for i=1,20 do local e=A.Copy(good.records[1]);e.id='r'..i;e.notes=string.rep('x',8000);e.related={};large.records[i]=e end
            assert(not R.Validate(large) and not R.Encode(large) and not R.StageReported(large))
        ''')

    def test_missing_selections_and_recipient_staging_never_writes(self):
        self.lua.execute('''
            local e=j:Get(a);e.provenance={kind='reported',source='Prior source'};e.explored=true;j.records[a]=e
            local p=assert(R.Build(j,draft,'Synthetic claimed sender'));local before=snapshot(saved)
            local staged=assert(R.StageReported(p))
            assert(snapshot(saved)==before and staged.records[1].explored==false)
            assert(staged.records[1].provenance.kind=='reported' and staged.records[1].provenance.source=='Synthetic claimed sender')
            assert(staged.records[1].originalKnowledge.kind=='reported' and not staged.records[1].id)
            j:Delete(a);local value,err=R.Build(j,draft,'Synthetic author');assert(not value and err:find('missing'))
            draft.records[a]=nil;value=assert(R.Build(j,draft,'Synthetic author'));assert(value.records[1].stops[1].missing)
            draft.expeditions[n]='Excerpt';j:Delete(n,true);assert(not R.Build(j,draft,'Synthetic author'))
        ''')


class AtlasUITests(unittest.TestCase):
    def setUp(self):
        self.lua = new_atlas(ui=True)

    def test_scrollable_index_and_current_map_toggle(self):
        self.lua.execute('''
            assert(j.state.all and not m.scope.afbSelected and m.scope:GetText()=='Current map')
            assert(not m.previous and not m.next)
            for i=1,30 do j:Save(fixture(string.format('Discovery %02d',i),'cave',i<=15 and 101 or 102)) end
            c:Refresh()
            assert(m.listBody:GetHeight()==900 and m.list:GetVerticalScroll()==0)
            m.rows[1].scripts.OnMouseWheel(m.rows[1],-3)
            m.list.scripts.OnVerticalScroll(m.list,m.list:GetVerticalScroll())
            assert(j.state.indexScroll==90 and m.rows[1].name:GetText()=='Discovery 04')
            m.list:SetVerticalScroll(510);m.list.scripts.OnVerticalScroll(m.list,510)
            assert(m.rows[13].name:GetText()=='Discovery 30')
            local first=c.entries:List('',101,true)[1].id
            c:Select(first);assert(m.list:GetVerticalScroll()==0 and m.rows[1].id==first)
            click(m.scope)
            assert(not j.state.all and m.scope.afbSelected and m.scope:GetText()=='Current map')
            assert(m.listBody:GetHeight()==450 and j.state.indexScroll==0)
            m.list:SetVerticalScroll(60)
            m.search:SetText('Discovery 01')
            assert(m.list:GetVerticalScroll()==0 and m.listBody:GetHeight()==390)
            assert(m.rows[1].name:GetText()=='Discovery 01' and not m.rows[2]:IsShown())
            click(m.scope);assert(j.state.all and not m.scope.afbSelected)
        ''')

    def test_discovery_hover_and_safe_text_return_only_one_value(self):
        self.lua.execute(r'''
            assert(select('#',A.Safe('Plain name'))==1,'Safe text leaked gsub replacement count')
            assert(select('#',A.Safe('|Htest|h\1'))==1)
            assert(A.Safe('|Htest|h\1')=='¦Htest¦h')
            assert(select('#',A.Safe(nil))==1)
            for _,category in ipairs(A.categories) do
                local id=j:Save(fixture('Synthetic '..category.label,category.id))
                c:Select(id)
                local selected
                for _,row in ipairs(m.rows) do if row.id==id then selected=row;break end end
                assert(selected)
                selected.scripts.OnEnter(selected)
                assert(GameTooltip:IsShown() and GameTooltip:IsOwned(selected))
                assert(GameTooltip:GetText()=='Synthetic '..category.label)
                assert(GameTooltip.lines[1].text=='Synthetic coast • '..category.label)
                selected.scripts.OnLeave(selected);assert(not GameTooltip:IsShown())
            end
        ''')

    def test_layer_hover_tooltips_use_valid_native_arguments(self):
        self.lua.execute('''
            local control=m.layerMenu
            control.scripts.OnEnter(control)
            assert(GameTooltip:IsShown() and GameTooltip:IsOwned(control))
            assert(GameTooltip:GetText()=='Map layer' and GameTooltip.lines[1].wrap==true)
            control.scripts.OnLeave(control);assert(not GameTooltip:IsShown())
            control.scripts.OnEnter(control)
            shell:ShowSection('test');assert(not GameTooltip:IsShown())
        ''')

    def test_layer_menu_checkboxes_preserve_independent_filters_and_records(self):
        self.lua.execute('''
            local id=j:Save(fixture());c:Select(id)
            local before=snapshot(j.records)
            j.state.showSubzones=true;j.state.showSubzonePoints=true
            click(m.layerMenu);assert(m.layerPanel:IsShown())
            m.layerPanel.scripts.OnShow()
            local checks={};for _,check in ipairs(m.layerPanel.checks) do checks[check.layerID]=check end
            assert(#m.layerPanel.checks==#A.categories+1 and not checks.entrance:GetChecked())
            checks.cave:SetChecked(false);click(checks.cave)
            assert(not j:Layer('cave') and j:Layer('route') and m.reveal:IsShown())
            assert(snapshot(j.records)==before)
            click(m.layerMenu);assert(not m.layerPanel:IsShown(),'Second click closes the menu')
            click(m.layerMenu);m.layerPanel.scripts.OnShow();assert(not checks.cave:GetChecked())
            m.iconSize.scripts.OnValueChanged(m.iconSize,32)
            assert(j.state.iconSize==32 and snapshot(j.records)==before)
            click(m.reveal);assert(j:Layer('cave'))
            assert(m.map.pins[1]:GetWidth()==36,'Selected pins preserve their size emphasis')
            local reload=ns.CreateAtlasJournal(saved)
            assert(reload.state.iconSize==32 and reload:Layer('cave'))
            assert(j.state.showSubzones and j.state.showSubzonePoints)
            m.iconSize.scripts.OnValueChanged(m.iconSize,6)
            assert(j.state.iconSize==6 and m.map.pins[1]:GetWidth()==10)
            assert(c.entries.borderlessPins and m.map.pins[1].icon.texture==A.category.cave.icon)
            assert(m.autoEntrances.point[3]==-91 and m.automaticMapping.point[3]==-119)
            assert(m.layerMenu.parent==m.map and m.layerMenu.point[1]=="TOPLEFT" and m.layerMenu.point[4]==8 and m.layerMenu.point[5]==-8 and m.cleanPoints.point[2]==754 and m.cleanPoints.point[3]==-60 and m.current.point[2]==342 and m.current.point[3]==-146 and m.zone.point[3]==-174)
            m.layerPanel.IsMouseOver=function() return true end
            m.layerPanel.scripts.OnEvent(m.layerPanel,'GLOBAL_MOUSE_DOWN')
            assert(m.layerPanel:IsShown(),'Clicks inside must keep layer choices open')
            m.layerPanel.IsMouseOver=function() return false end
            m.layerMenu.IsMouseOver=function() return true end
            m.layerPanel.scripts.OnEvent(m.layerPanel,'GLOBAL_MOUSE_DOWN')
            assert(m.layerPanel:IsShown(),'The toggle button handles its own click')
            m.layerMenu.IsMouseOver=function() return false end
            m.layerPanel.scripts.OnEvent(m.layerPanel,'GLOBAL_MOUSE_DOWN')
            assert(not m.layerPanel:IsShown(),'Outside clicks dismiss the layer menu')

        ''')

    def test_native_shell_size_state_and_page_owned_lifetime(self):
        self.lua.execute('''
            local root=shell:GetFrame();assert(root:GetWidth()==960 and root:GetHeight()==740)
            local entry=fixture();entry.notes=string.rep('Long synthetic note ',180)
            local id=j:Save(entry);c:Select(id)
            m.search:SetText('Synthetic');j.state.all=true;m.details:SetVerticalScroll(22)
            c:OpenEditor(id);c.editor.notes:SetText('Unfinished journal edit')
            c.editor.scroll:SetVerticalScroll(150)
            local active=c.activePage;GameTooltip:Show();shell:ShowSection('test')
            assert(not c.frame:IsShown() and not GameTooltip:IsShown())
            shell:ShowSection('atlas');assert(c.activePage==active and c.editor.notes:GetText()=='Unfinished journal edit')
            assert(j.state.selected==id and j.state.query=='Synthetic' and j.state.all)
            assert(c.editor.scroll:GetVerticalScroll()==150)
            c:Show();assert(m.details:GetVerticalScroll()==22)
            local objectsBefore=#objects
            for i=1,10 do c:OpenEditor(id);c:Show();c:Refresh() end
            assert(#objects==objectsBefore,'editors and map controls are reused')
        ''')

    def test_map_assets_pin_list_zone_sync_layer_reveal_and_overlap(self):
        self.lua.execute('''
            local a=j:Save(fixture('A entrance'));local b=j:Save(fixture('B entrance'))
            local far=j:Save(fixture('Far camp','camp',102));c:Select(a)
            assert(m.map.available and #m.map.pins==1 and #m.map.pins[1].group==2)
            click(m.map.pins[1]);assert(j.state.selected==b)
            click(m.map.pins[1]);assert(j.state.selected==a)
            j:SetLayer('cave',false);c:Refresh();assert(not m.map.pins[1]:IsShown())
            c:Select(b);assert(not j:Layer('cave') and m.reveal:IsShown())
            click(m.reveal);assert(j:Layer('cave') and m.map.pins[1]:IsShown())
            j.state.all=true;c:Refresh();c:Select(far);assert(j.state.mapID==102 and j.state.selected==far)
            mapID=101;shell:ShowSection('test');shell:ShowSection('atlas');assert(j.state.mapID==102)
            C_Map.GetMapArtLayers=nil;c:SetZone(101,'Unavailable');assert(not m.map.available)
            assert(not m.map.pins[1]:IsShown() and m.map.empty:IsShown())
        ''')

    def test_editor_position_picker_crud_and_long_text(self):
        self.lua.execute(r'''
            c:OpenEditor(nil,false,A.CurrentLocation());local p=c.editor
            p.name:SetText('Synthetic new place');p.draft.category='cave';p.notes:SetText(string.rep('Long journal\n',300))
            local id=assert(p:Save());assert(j:Get(id).x==2500 and not j:Get(id).explored)
            p.location.x:SetText('invalid');assert(not p:Save())
            p.location.x:SetText('25');c:ChoosePosition();assert(m.map.placing and c.activePage==m)
            m.map.left,m.map.top=100,700;cursorX=100+m.map:GetWidth()/2;cursorY=700-m.map:GetHeight()/2
            m.map.scripts.OnMouseUp(m.map,'LeftButton')
            assert(not m.map.placing and c.activePage==p and p.location.x:GetText()=='50.00')
            assert(p:Save()==id and j:Get(id).x==5000)
            assert(not p.delete:IsShown());c:Show(m);c:Select(id)
            click(m.deleteButton);click(m.deleteForm.confirm);assert(not j:Get(id))
            local loose=j:Save({name='Unpositioned synthetic note',category='other',notes='Find it later'})
            c:Select(loose);assert(j.state.all and m.rows[1].id==loose)
        ''')

    def test_route_and_expedition_controls_and_connections(self):
        self.lua.execute('''
            local a=j:Save(fixture());local r=fixture('Synthetic route','route');r.stops={{recordID=a,name='Entrance'}}
            local route=j:Save(r);c:Stops(route);assert(c.pages.stops.rows[1]:IsShown())
            c:Waypoint(route);local w=c.pages.waypoint;w.name:SetText('Synthetic waypoint')
            -- Use the real save button found in this bounded panel.
            for _,o in ipairs(objects) do if o.parent==w and o.text=='Save waypoint' then click(o);break end end
            assert(#j:Get(route).stops==2);click(c.pages.stops.rows[2].up);assert(j:Get(route).stops[1].name=='Synthetic waypoint')
            click(c.pages.stops.rows[1].remove);assert(#j:Get(route).stops==1)
            c:Expeditions(a);click(c.pages.picker.extra);c.editor.name:SetText('Synthetic expedition');c.editor.notes:SetText('Field notes')
            local note=assert(c.editor:Save());assert(#j:Associated(a)==1)
            c:Connections(note,true);click(c.pages.picker.rows[2]);assert(#j:Get(note,true).related==2)
            c:Connections(a,false,true);click(c.pages.picker.rows[1]);assert(#j:Get(a).references==1)
            click(c.pages.picker.rows[1].secondary);assert(c.pages.picker.message:GetText():find('Synthetic herb'))
            click(c.pages.picker.rows[1]);assert(#j:Get(a).references==0 and source.entries['herb:synthetic herb'])
            c:OpenEditor(note,true);local editor=c.editor;click(editor.delete)
            click(editor.deleteForm.cancel);assert(j:Get(note,true))
            click(editor.delete);click(editor.deleteForm.confirm);assert(not j:Get(note,true) and j:Get(a))
        ''')

    def test_report_selection_excerpt_preview_and_persisted_draft(self):
        self.lua.execute('''
            local id=j:Save(fixture());local note=j:Save({name='Synthetic journal',notes='SECRET journal'},nil,true)
            c:Report();local p=c.pages.report;p.titleEdit:SetText('Synthetic report')
            click(p.rows[1]);assert(p.draft.records[id] and not p.draft.notes[id])
            local payload=assert(R.Build(j,p.draft,'Tester'));c:ReportPreview(payload)
            assert(not c.pages.preview.preview.text:GetText():find('Private lantern',1,true))
            c:Report();click(p.rows[1].note);click(p.modeButton);click(p.rows[1]);click(p.rows[1].note)
            assert(c.pages.excerpt.text:GetText()=='')
            c.pages.excerpt.text:SetText('Explicit excerpt')
            for _,o in ipairs(objects) do if o.parent==c.pages.excerpt and o.text=='Include this excerpt' then click(o);break end end
            payload=assert(R.Build(j,p.draft,'Tester'));c:ReportPreview(payload)
            local preview=c.pages.preview.preview.text:GetText()
            assert(preview:find('Private lantern',1,true) and preview:find('Explicit excerpt',1,true))
            assert(not preview:find('SECRET journal',1,true))
            assert(R.Decode(c.pages.preview.serialized) and saved.reportDraft.title=='Synthetic report')
        ''')

    def test_map_pool_bound_and_route_line_fallback(self):
        self.lua.execute('''
            for i=1,500 do j:Save(fixture('Synthetic '..i,'other',101,(i*73)%10000,(i*157)%10000)) end
            c:Refresh();assert(#m.map.pins<=192)
            local count=#objects;for i=1,5 do c:Refresh() end;assert(#objects==count)
            local route=fixture('Route','route');route.stops={{name='One',mapID=101,x=1000,y=1000},{name='Two',mapID=101,x=3000,y=3000}}
            local id=j:Save(route);c:Select(id);assert(m.details.text:GetText():find('line rendering is unavailable',1,true))
            function m.map.canvas:CreateLine() return CreateFrame('Texture',nil,self) end
            c:Refresh();assert(m.map.lines[1]:IsShown())
            j:SetLayer('route',false);c:Refresh();assert(not m.map.lines[1]:IsShown())
        ''')

    def test_route_without_stops_uses_its_recorded_map_position(self):
        self.lua.execute('''
            local id=j:Save(fixture('Synthetic passage','route',101,2500,7500))
            local function marker()
                for _,pin in ipairs(m.map.pins or {}) do
                    if pin:IsShown() then
                        for _,entry in ipairs(pin.group) do if entry.id==id then return pin,entry end end
                    end
                end
            end
            c:Refresh()
            local pin,entry=marker();assert(pin,'Unselected positioned passage must have a marker')
            assert(entry.point.x==2500 and entry.point.y==7500 and not entry.number)
            assert(pin.icon.texture==A.category.route.icon)
            click(pin);assert(j.state.selected==id and marker())
            assert(m.details.text:GetText():find('no itinerary stops',1,true))
            assert(#j:Get(id).stops==0,'Rendering must not invent route stops')
            j:SetLayer('route',false);c:Refresh();assert(not marker())
            j:SetLayer('route',true);c:SetZone(102,'Synthetic hills');assert(not marker())
            c:SetZone(101,'Synthetic coast');assert(marker())
            local route=j:Get(id);route.x=nil;route.y=nil;j:Save(route,id);c:Refresh();assert(not marker())
            route.x,route.y=2500,7500
            route.stops={{name='Actual stop',mapID=101,zone='Synthetic coast',x=5000,y=2000}}
            j:Save(route,id);c:Refresh();pin,entry=marker()
            assert(pin and entry.number==1 and entry.point.x==5000)
        ''')

    def test_camp_markers_and_index_use_an_available_icon(self):
        self.lua.execute(r'''
            local unavailable='Interface\\Icons\\INV_Misc_Campfire'
            local function simulateAssets(texture)
                local original=texture.SetTexture
                function texture:SetTexture(path,...)
                    if path==unavailable then self.texture=nil;return false end
                    return original(self,path,...)
                end
            end
            for _,object in ipairs(objects) do if object.kind=='Texture' then simulateAssets(object) end end
            local create=CreateFrame
            function CreateFrame(...)
                local frame=create(...)
                if frame.kind=='Texture' then simulateAssets(frame) end
                return frame
            end
            local id=j:Save(fixture('Synthetic camp','camp'));c:Select(id)
            assert(m.rows[1].icon.texture,'Camp index icon must load')
            local pin=m.map.pins[1]
            assert(pin:IsShown() and pin.icon.texture,'Camp marker must show an icon, not only a border')
            assert(pin.icon.texture==m.rows[1].icon.texture)
            j:SetLayer('camp',false);c:Refresh();assert(not pin:IsShown())
        ''')

    def test_player_arrow_same_map_motion_facing_and_lifetime(self):
        self.lua.execute('''
            local facing=1.2;local reads=0
            function GetPlayerFacing() reads=reads+1;return facing end
            local arrow=m.map.playerArrow
            function arrow:SetRotation(value) self.rotation=value end
            local before=snapshot(saved);c:Refresh()
            assert(arrow:IsShown() and arrow.rotation==1.2)
            assert(arrow.point[4]==px*m.map:GetWidth() and arrow.point[5]==-py*m.map:GetHeight())
            px,py,facing=0.8,0.4,2.4
            local count=reads;m.map.scripts.OnUpdate(m.map,0.05);assert(reads==count)
            m.map.scripts.OnUpdate(m.map,0.05)
            assert(arrow.point[4]==0.8*m.map:GetWidth() and arrow.rotation==2.4)
            assert(snapshot(saved)==before,'Player arrow must not record movement')
            c:SetZone(102,'Synthetic hills');assert(not arrow:IsShown())
            mapID=102;m.map.scripts.OnUpdate(m.map,0.1);assert(arrow:IsShown())
            px=nil;m.map.scripts.OnUpdate(m.map,0.1);assert(not arrow:IsShown())
            px=0.8;facing=nil;m.map.scripts.OnUpdate(m.map,0.1);assert(not arrow:IsShown())
            facing=1;c:Refresh();assert(arrow:IsShown())
            shell:ShowSection('test');assert(not arrow:IsShown() and not m.map.scripts.OnUpdate)
            shell:ShowSection('atlas');assert(arrow:IsShown() and m.map.scripts.OnUpdate)
            C_Map.GetMapArtLayers=nil;c:SetZone(101,'Synthetic coast')
            assert(not arrow:IsShown() and m.map.scripts.OnUpdate,'Coordinates remain live without map art')
        ''')

    def test_larger_maps_live_coordinates_and_clean_selection(self):
        self.lua.execute('''
            local oldScale=math.min(578/1000,302/668)
            assert(math.abs(m.map:GetWidth()-1000*oldScale*1.25*0.99)<0.001)
            assert(math.abs(m.map:GetHeight()-668*oldScale*1.25*0.99)<0.001)
            assert(m.map:GetWidth()<=578 and 205+m.map:GetHeight()<591)
            assert(shell:GetFrame():GetWidth()==960 and shell:GetFrame():GetHeight()==740)
            local id=j:Save(fixture());c:Select(id)
            local pin=m.map.pins[1];assert(pin:IsShown() and not pin.selectedMark and pin:GetWidth()==24)
            assert(m.map.playerCoordinates:GetText()=='Player: 25.00, 75.00')
            px,py=0.1234,0.5678;m.map.scripts.OnUpdate(m.map,0.1)
            assert(m.map.playerCoordinates:GetText()=='Player: 12.34, 56.78')
            c:SetZone(102,'Synthetic hills')
            assert(m.map.playerCoordinates:GetText()=='Player: 12.34, 56.78 (other map)')
            px=nil;m.map.scripts.OnUpdate(m.map,0.1)
            assert(m.map.playerCoordinates:GetText()=='Player coordinates unavailable')
        ''')


    def test_cursor_zoom_bounds_placement_and_section_independence(self):
        self.lua.execute('''
            local map=m.map;local w,h=map:GetWidth(),map:GetHeight()
            map.left,map.top=0,h
            cursorX,cursorY=w*0.25,h*0.25
            map.scripts.OnMouseWheel(map,1)
            assert(map.zoom==1.25 and map:GetWidth()==w and map:GetHeight()==h)
            assert(math.abs((map.panX+w*0.25)/(w*map.zoom)-0.25)<0.00001)
            assert(math.abs((map.panY+h*0.75)/(h*map.zoom)-0.75)<0.00001)
            local x,y
            local independent=ns.CreateAtlasMap(m,j,function() end,function(a,b) x,y=a,b end)
            independent:Render(101);independent.left,independent.top=0,h
            independent:ZoomBy(1);independent.placing=true
            independent.scripts.OnMouseUp(independent,'LeftButton')
            assert(x==2500 and y==7500,'Placement must undo cursor-centred zoom')
            map:ZoomBy(100);assert(map.zoom==4 and independent.zoom==1.25)
            c:Refresh();assert(map.zoom==4,'Same-map refresh must retain zoom')
            map:ZoomBy(-100);assert(map.zoom==1 and map.panX==0 and map.panY==0)
            local id=j:Save(fixture());c:Select(id)
            map.pins[1].scripts.OnMouseWheel(map.pins[1],1);assert(map.zoom==1.25)
            c:SetZone(102,'Other');assert(map.zoom==1 and map.panX==0 and map.panY==0)
            map.available=false;map:ZoomBy(1);assert(map.zoom==1)
        ''')

    def test_native_region_highlight_tracks_cursor_zoom_and_lifetime(self):
        self.lua.execute('''
            local map=m.map;local w,h=map:GetWidth(),map:GetHeight()
            map.left,map.top=0,h;cursorX,cursorY=w*.25,h*.25
            map.IsMouseOver=function() return true end
            local calls=0
            C_Map.GetMapHighlightInfoAtPosition=function(id,x,y)
                calls=calls+1
                assert(math.abs(x-.25)<.00001 and math.abs(y-.75)<.00001)
                return 12345,nil,.8,.9,.2,.3,.1,.4
            end
            map:UpdateRegionHighlight()
            local glow=map.regionHighlight
            assert(glow:IsShown() and glow.texture==12345)
            assert(math.abs(glow:GetWidth()-w*.2)<.001 and math.abs(glow.point[5]+h*.4)<.001)
            assert(glow.texCoord[2]==.8 and glow.texCoord[4]==.9)
            map:ZoomBy(1);assert(glow:IsShown(),'Highlight uses the same zoom transform as clicks')
            map.placing=true;map:UpdateRegionHighlight();assert(not glow:IsShown())
            map.placing=false
            ns.IsMapClickNavigationEnabled=function() return false end
            map:UpdateRegionHighlight();assert(not glow:IsShown())
            ns.IsMapClickNavigationEnabled=function() return true end
            map:UpdateRegionHighlight();assert(glow:IsShown())
            map.scripts.OnLeave(map);assert(not glow:IsShown())
            map.IsMouseOver=function() return false end
            local before=calls;map:UpdateRegionHighlight();assert(calls==before)
            map.IsMouseOver=function() return true end
            C_Map.GetMapHighlightInfoAtPosition=function() return nil end
            map:UpdateRegionHighlight();assert(not glow:IsShown())
            C_Map.GetMapHighlightInfoAtPosition=function() error('unavailable') end
            map:UpdateRegionHighlight();assert(not glow:IsShown())
            C_Map.GetMapHighlightInfoAtPosition=nil;map:UpdateRegionHighlight()
            map.scripts.OnHide(map);assert(not glow:IsShown())
        ''')

    def test_world_map_click_navigation_and_toggle(self):
        self.lua.execute('''
            local map=m.map;local w,h=map:GetWidth(),map:GetHeight()
            map.left,map.top=0,h;cursorX,cursorY=w*.25,h*.25
            C_Map.GetMapInfo=function(id) return {mapID=id,name='Map '..id,parentMapID=id==101 and 100 or 0} end
            C_Map.GetMapInfoAtPosition=function(id,x,y)
                assert(id==100 and math.abs(x-.25)<.00001 and math.abs(y-.75)<.00001)
                return {mapID=101,name='Child zone'}
            end
            map.scripts.OnMouseUp(map,'RightButton');assert(j.state.mapID==100)
            map:ZoomBy(1);map.scripts.OnMouseUp(map,'LeftButton')
            assert(j.state.mapID==101 and map.zoom==1)
            ns.IsMapClickNavigationEnabled=function() return false end
            map.scripts.OnMouseUp(map,'RightButton');assert(j.state.mapID==101)
            ns.IsMapClickNavigationEnabled=function() return true end
            map.placing=true;map.scripts.OnMouseUp(map,'RightButton');assert(j.state.mapID==101)
            map.placing=false;map.scripts.OnMouseUp(map,'RightButton')
            map.scripts.OnMouseUp(map,'RightButton');assert(j.state.mapID==100,'root stays put')
            C_Map.GetMapInfoAtPosition=function() error('unavailable') end
            map.scripts.OnMouseUp(map,'LeftButton');assert(j.state.mapID==100)
        ''')

    def test_zoomed_drag_panning_clamps_and_suppresses_click_navigation(self):
        self.lua.execute('''
            local map=m.map;local w,h=map:GetWidth(),map:GetHeight()
            map.left,map.top=0,h;cursorX,cursorY=w/2,h/2
            local navigation=0
            C_Map.GetMapInfoAtPosition=function() navigation=navigation+1;return nil end
            map:ZoomBy(2);local px,py=map.panX,map.panY
            map.scripts.OnMouseDown(map,'LeftButton')
            cursorX,cursorY=cursorX-20,cursorY+30;map:UpdatePan()
            assert(math.abs(map.panX-px-20)<.001 and math.abs(map.panY-py-30)<.001)
            map.scripts.OnMouseUp(map,'LeftButton');assert(navigation==0)
            map.scripts.OnMouseDown(map,'LeftButton');cursorX=cursorX+1
            map.scripts.OnMouseUp(map,'LeftButton');assert(navigation==1,'tiny movement remains a click')
            map:StartPan('LeftButton');cursorX,cursorY=100000,-100000;map:UpdatePan()
            assert(map.panX==0 and map.panY==0);map:FinishPan()
            map:StartPan('LeftButton');cursorX,cursorY=-100000,100000;map:UpdatePan()
            assert(map.panX==w*(map.zoom-1) and map.panY==h*(map.zoom-1))
            map.scripts.OnHide(map);local x=map.panX;cursorX=0;map:UpdatePan();assert(map.panX==x)
            map:ZoomBy(-100);map:StartPan('LeftButton');cursorX=100;map:UpdatePan()
            assert(map.panX==0 and not map:FinishPan(),'unzoomed maps do not pan')
        ''')

    def test_single_zone_menu_selects_map_without_creating_records(self):
        self.lua.execute('''
            local chosen
            local function description()
                local d={}
                function d:SetScrollMode() end
                function d:CreateDivider() end
                function d:CreateTitle() end
                function d:CreateButton(text,action)
                    if text=='Synthetic hills' then chosen=action end
                    return description()
                end
                return d
            end
            MenuUtil={CreateContextMenu=function(owner,generate)
                assert(owner==m.zone);generate(owner,description())
            end}
            local before=#j:List('',nil,true)
            assert(m.continent==nil and m.zone:GetWidth()==306 and m.layerMenu:GetWidth()==m.layerMenu:GetHeight())
            m.zone.scripts.OnClick(m.zone);assert(chosen);chosen()
            assert(j.state.mapID==102 and #j:List('',nil,true)==before)
        ''')

    def test_weather_history_selected_zone(self):
        self.lua.execute("""
            local info={type=1,intensity=0.65}
            C_Weather={GetCurrentWeather=function() return info end}
            c.weatherObserver.scripts.OnEvent()
            assert(j:WeatherText(101)=='Rain')
            c:SetZone(102,'Different viewed zone')
            assert(m.map.weatherText:GetText()=='|cffffd100Observed Weather:|r No weather observed yet.')
            info={type=0};c.weatherObserver.scripts.OnEvent()
            assert(j:WeatherText(101)=='Clear, Rain')
            shell:ShowSection('test')
            mapID=102;info={type=2};c.weatherObserver.scripts.OnEvent()
            shell:ShowSection('atlas')
            assert(m.map.weatherText:GetText()=='|cffffd100Observed Weather:|r Snow')
            c:SetZone(101,'Synthetic coast')
            assert(m.map.weatherText:GetText()=='|cffffd100Observed Weather:|r Clear, Rain')
            local before=snapshot(saved.weather)
            C_Weather.GetCurrentWeather=function() error('unavailable') end
            c.weatherObserver.scripts.OnEvent()
            C_Weather=nil;c.weatherObserver.scripts.OnEvent()
            assert(snapshot(saved.weather)==before,'Unavailable weather must not record clear skies')
            local restored=ns.CreateAtlasJournal(saved)
            assert(restored:WeatherText(101)=='Clear, Rain' and restored:WeatherText(102)=='Snow')
            local future={schema=999};ns.CreateAtlasJournal(future):ObserveWeather()
            assert(not future.weather)
            C_Map.GetMapArtLayers=nil;m.map:Invalidate();c:Refresh()
        """)


class InitialZoneTests(unittest.TestCase):
    def test_first_open_uses_current_zone_and_later_choices_survive(self):
        lua=new_atlas()
        lua.execute("""
            j.state.mapID=102;j.state.zone='Old zone'
            shell:ShowSection('atlas');assert(j.state.mapID==mapID)
            c:SetZone(102,'Chosen zone');shell:ShowSection('test');shell:ShowSection('atlas')
            assert(j.state.mapID==102)
        """)

if __name__ == '__main__':
    unittest.main()
