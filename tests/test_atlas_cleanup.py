"""Border preservation, compact coverage, reload and changed-evidence contracts."""
import unittest
from atlas_test_harness import new_atlas
from test_account_sections import account
from test_player_names_preservation import full_client


class AtlasCleanupTests(unittest.TestCase):
    def test_account_merge_preserves_exclusions_on_duplicate_observations(self):
        account(self.lua)
        self.lua.execute('''
            local first={schema=1,subzones={[101]={{kind='interior',mapID=101,name='Village',x=2362,y=5554}}}}
            local second={schema=1,subzones={[101]={{kind='interior',mapID=101,name='Village',x=2362,y=5554,excluded=true}}}}
            local original=snapshot(first.subzones)
            local shared=ns.SelectSectionStorage('atlas',first)
            scope(2);shared=ns.SelectSectionStorage('atlas',second)
            assert(#shared.subzones[101]==1 and shared.subzones[101][1].excluded==true)
            assert(snapshot(first.subzones)==original and second.subzones[101][1].excluded)
        ''')

    def setUp(self):
        self.lua = new_atlas(ui=True)
        self.lua.execute('''
            S=ns.AtlasSubzones;s=j.subzones
            C_Map.GetMapWorldSize=function() return 4000,4000 end
            function settle()
                for i=1,30000 do if not S.worker or not S.worker:IsShown() then return end;S.Step() end
                error('worker did not settle')
            end
            function seed()
                s.store[101]={}
                for x=2000,8000,1000 do for y=2000,8000,1000 do
                    s.store[101][#s.store[101]+1]={kind='interior',mapID=101,name='Lake',x=x,y=y,at=100}
                end end
                s.index={};s:Changed(101)
            end
            function clean()
                assert(S.CleanInterior(j,101,function(n) removed=n end));settle()
            end
            name='Lake';function GetSubZoneText() return name end
            seed()
        ''')

    def test_cleanup_preserves_both_shapes_and_cumulative_ownership(self):
        self.lua.execute('''
            local before={traced=S.Build(s:Samples(101)),convex=S.Build(s:Samples(101),nil,nil,nil,'convex')}
            clean();assert(removed==45 and #s.store[101]==4)
            for method,model in pairs(before) do
                local after=S.Build(s:Samples(101),nil,nil,nil,method)
                for x=1000,9000,100 do for y=1000,9000,100 do
                    local a,b=model:At(x,y),after:At(x,y)
                    assert((a and a.name)==(b and b.name))
                end end
            end
            assert(#j.saved.subzoneCoverage.maps[101].Lake==360)
            local before=snapshot(j.saved);clean();assert(removed==0 and snapshot(j.saved)==before)
        ''')

    def test_coverage_survives_reload_and_does_not_block_manual_or_crossings(self):
        self.lua.execute('''
            clean();local data=j.saved
            j=ns.CreateAtlasJournal(data);s=j.subzones
            px=.5;py=.5
            assert(not s:Observe(true));settle()
            assert(not s:Observe(true));settle()
            assert(not s:Observe(true) and #s.store[101]==4,'No repeat point after reload')
            assert(s:RecordPoint(),'Manual survey bypasses compact coverage');assert(#s.store[101]==5)
            px=.3;py=.3;s:Reset();s:Observe(true);settle();s:Observe(true)
            name='New area';px=.301
            assert(s:Observe(true),'Changed name still records its crossing')
            assert(#s:Crossings(101)==1)
        ''')

    def test_changed_name_and_changed_edges_reopen_sampling(self):
        self.lua.execute('''
            clean();px=.5;py=.5;s:Reset();name='Different area'
            assert(s:Observe(),'Coverage for Lake cannot block a different name')
            seed();j.saved.subzoneCoverage=nil;clean()
            -- Simulate later geometry moving the boundary beside a covered point.
            local kept={}
            for _,p in ipairs(s.store[101]) do if p.x>=5500 then kept[#kept+1]=p end end
            kept[#kept+1]={kind='interior',mapID=101,name='Lake',x=5500,y=2000}
            kept[#kept+1]={kind='interior',mapID=101,name='Lake',x=5500,y=8000}
            s.store[101]=kept;s.index={};s:Changed(101);s:Reset();name='Lake'
            s:Observe(true);settle();s:Observe(true);settle()
            assert(s:Observe(true),'Old coverage near the current edge cannot suppress evidence')
        ''')

    def test_old_timestamps_removed_without_losing_dense_or_manual_evidence(self):
        self.lua.execute('''
            table.insert(s.store[101],{kind='interior',manual=true,mapID=101,name='Lake',x=5001,y=5001,at=99})
            local n=#s.store[101];s:Index(101)
            assert(#s.store[101]==n,'Indexing cannot proximity-prune interior evidence')
            for _,p in ipairs(s.store[101]) do assert(p.at==nil) end
            local future={schema=999,subzones={[101]={{kind='interior',mapID=101,name='Lake',x=5000,y=5000,at=99}}}}
            local before=snapshot(future);ns.CreateAtlasJournal(future).subzones:Index(101)
            assert(snapshot(future)==before)
        ''')

    def test_unsupported_coverage_and_full_coverage_are_preserved(self):
        self.lua.execute('''
            j.saved.subzoneCoverage={version=999,maps={}}
            local before=snapshot(j.saved.subzoneCoverage);clean()
            assert(removed==0 and snapshot(j.saved.subzoneCoverage)==before)
            j.saved.subzoneCoverage={version=1,maps={[101]={Lake='invalid'}}}
            before=snapshot(j.saved.subzoneCoverage);clean()
            assert(removed==0 and snapshot(j.saved.subzoneCoverage)==before)
            j.saved.subzoneCoverage={version=1,maps={[101]={Lake=string.rep('00000000',S.MAX_COVERAGE)}}}
            clean();assert(removed==0,'Never delete samples without room to remember them')
        ''')

    def test_account_merge_unions_coverage_without_mutating_character_stores(self):
        account(self.lua)
        self.lua.execute('''
            local a={schema=1,subzoneCoverage={version=1,maps={[101]={Lake='13881388'}}}}
            local b={schema=1,subzoneCoverage={version=1,maps={[101]={Lake='1388138817701770'}}}}
            local beforeA,beforeB=snapshot(a.subzoneCoverage),snapshot(b.subzoneCoverage)
            local shared=ns.SelectSectionStorage('atlas',a)
            scope(2);shared=ns.SelectSectionStorage('atlas',b)
            assert(#shared.subzoneCoverage.maps[101].Lake==16)
            assert(snapshot(a.subzoneCoverage)==beforeA and snapshot(b.subzoneCoverage)==beforeB)
            scope(2);assert(#ns.SelectSectionStorage('atlas',b).subzoneCoverage.maps[101].Lake==16)
        ''')

    def test_real_options_control_defaults_off_and_updates_atlas_preference(self):
        lua=full_client()
        lua.execute('''
            AzerothFieldbookToggleBestiary()
            local options=AzerothFieldbookOptions
            options.scripts.OnShow(options)
            assert(options.legacySubzones and not options.legacySubzones:GetChecked())
            options.legacySubzones:SetChecked(true)
            options.legacySubzones.scripts.OnClick(options.legacySubzones)
            assert(ns.AtlasOptions.GetLegacy())
            options.scripts.OnShow(options);assert(options.legacySubzones:GetChecked())
            options.legacySubzones:SetChecked(false)
            options.legacySubzones.scripts.OnClick(options.legacySubzones)
            assert(not ns.AtlasOptions.GetLegacy())
        ''')

    def test_overlapping_rectangles_do_not_veto_disjoint_polygons(self):
        self.lua.execute('''
            -- Lake's box intersects Triangle's box, but their polygons are disjoint.
            seed()
            for _,p in ipairs(s.store[101]) do p.x=p.x-1000;p.y=p.y-1000 end
            for _,p in ipairs({{6500,8000},{8000,6500},{8000,8000}}) do
                table.insert(s.store[101],{kind='interior',mapID=101,name='Triangle',x=p[1],y=p[2]})
            end
            s:Changed(101);local before=S.Build(s:Samples(101))
            clean();assert(removed==45,'A remote rectangle overlap must not protect the whole area')
            local after=S.Build(s:Samples(101))
            for x=1000,9000,100 do for y=1000,9000,100 do
                local a,b=before:At(x,y),after:At(x,y)
                assert((a and a.name)==(b and b.name))
            end end
        ''')

    def test_real_overlap_can_clean_remote_points_without_moving_borders(self):
        self.lua.execute('''
            seed()
            for _,p in ipairs({{6000,3000},{9000,3000},{9000,7000},{6000,7000}}) do
                table.insert(s.store[101],{kind='interior',mapID=101,name='Neighbour',x=p[1],y=p[2]})
            end
            s:Changed(101)
            local before={traced=S.Build(s:Samples(101)),convex=S.Build(s:Samples(101),nil,nil,nil,'convex')}
            local stats,message
            assert(S.CleanInterior(j,101,function(n,msg,t) removed=n;message=msg;stats=t end));settle()
            assert(removed>0,'Real overlap must not veto safe remote points')
            assert(stats.interior==53 and stats.outline+stats.ownership>0)
            local retained=stats.edge+stats.nearby+stats.outline+stats.ownership+stats.manual+stats.capacity
            assert(retained+removed==stats.interior,'Every interior point has a counted outcome')
            for method,model in pairs(before) do
                local after=S.Build(s:Samples(101),nil,nil,nil,method)
                for x=1000,9500,50 do for y=1000,9000,50 do
                    local a,b=model:At(x,y),after:At(x,y)
                    assert((a and a.name)==(b and b.name),'Nearest-anchor ownership must stay unchanged')
                end end
            end
            assert(message:find('5%-yard limit') and message:find('protecting overlap borders'))
        ''')

    def test_cleanup_result_stays_in_button_tooltip(self):
        self.lua.execute('''
            click(m.cleanPoints);settle()
            m.cleanPoints.scripts.OnEnter(m.cleanPoints)
            local text=''
            for _,line in ipairs(GameTooltip.lines) do text=text..line.text end
            assert(text:find('Last cleanup') and text:find('Removed 45 of 49 interior points'))
            assert(text:find('4 protecting shape') and text:find('0 protecting overlap borders'))
        ''')

    def test_overlap_guard_rejects_a_removed_anchor_that_would_lose_territory(self):
        self.lua.execute('''
            local function up(fn,key)
                for i=1,50 do local name,value=debug.getupvalue(fn,i)
                    if name==key then return value end;if not name then break end
                end
            end
            local safe=assert(up(up(S.CleanInterior,'cleanInterior'),'ownershipSafe'))
            local a={convex={{x=0,y=0},{x=10000,y=0},{x=10000,y=10000},{x=0,y=10000}},minX=0,minY=0,maxX=10000,maxY=10000}
            local b={convex={{x=6000,y=2000},{x=10000,y=2000},{x=10000,y=8000},{x=6000,y=8000}},minX=6000,minY=2000,maxX=10000,maxY=8000,anchors={{x=9000,y=5000}}}
            local removed={{x=5000,y=5000}}
            -- At (6500,5000), the removed own anchor beats the rival, but none
            -- of the retained corner anchors does. This cannot be simplified.
            assert(not safe({A=a,B=b},a,a.convex,removed,1,1,function() end))
        ''')

    def test_outline_tolerance_uses_yards_preserves_necks_and_shared_edges(self):
        self.lua.execute('''
            local original={{x=0,y=0},{x=100,y=0},{x=100,y=100},{x=50,y=104},{x=0,y=100}}
            local simpler={{x=0,y=0},{x=100,y=0},{x=100,y=100},{x=0,y=100}}
            assert(S.OutlineWithinTolerance(original,simpler,10000,10000))
            assert(not S.OutlineWithinTolerance(original,simpler,10000,20000),'Use vertical world dimensions')
            original[4].y=106
            assert(not S.OutlineWithinTolerance(original,simpler,10000,10000),'Six yards exceeds tolerance')
            original[4].y=104
            local neighbour={convex={{x=40,y=102},{x=60,y=102},{x=60,y=110},{x=40,y=110}}}
            assert(not S.OutlineWithinTolerance(original,simpler,10000,10000,nil,{Neighbour=neighbour},'Own'),'Do not alter shared strips')
            original[3].y=8;original[4].y=12;original[5].y=8
            simpler[3].y=8;simpler[4].y=8
            assert(not S.OutlineWithinTolerance(original,simpler,10000,10000),'Protect thin passages even within tolerance')
        ''')

    def test_tolerance_cannot_accumulate_across_repeated_shortcuts(self):
        self.lua.execute('''
            local baseline={{x=0,y=0},{x=100,y=0},{x=100,y=100},{x=75,y=106},{x=50,y=104},{x=0,y=100}}
            local first={{x=0,y=0},{x=100,y=0},{x=100,y=100},{x=50,y=104},{x=0,y=100}}
            local second={{x=0,y=0},{x=100,y=0},{x=100,y=100},{x=0,y=100}}
            assert(S.OutlineWithinTolerance(baseline,first,10000,10000))
            assert(S.OutlineWithinTolerance(first,second,10000,10000))
            assert(not S.OutlineWithinTolerance(baseline,second,10000,10000),'Two acceptable steps may exceed the original error budget')
        ''')

    def test_curved_edge_cleanup_reloads_without_redropping_and_keeps_original_budget(self):
        self.lua.execute('''
            C_Map.GetMapWorldSize=function() return 10000,10000 end
            s.store[101]={};s.index={}
            for i=0,31 do
                local angle=i*math.pi/16
                s.store[101][#s.store[101]+1]={kind='interior',mapID=101,name='Lake',
                    x=5000+math.floor(100*math.cos(angle)+0.5),y=5000+math.floor(100*math.sin(angle)+0.5)}
            end
            s:Changed(101)
            local original=S.Build(s:Samples(101)).areas.Lake.hull
            clean();assert(removed>10 and #s.store[101]>=3)
            local source=j.saved
            for run=1,3 do
                j=ns.CreateAtlasJournal(source);s=j.subzones
                clean()
                local shape=S.Build(s:Samples(101)).areas.Lake.hull
                assert(S.OutlineWithinTolerance(original,shape,10000,10000),'Reconstruct original coverage after reload')
            end
            local packed=j.saved.subzoneCoverage.maps[101].Lake
            local x,y=tonumber(packed:sub(1,4),16),tonumber(packed:sub(5,8),16)
            px=x/10000;py=y/10000;name='Lake';s:Reset()
            local count=#s.store[101]
            s:Observe(true);settle();s:Observe(true);settle();s:Observe(true)
            assert(#s.store[101]==count,'Do not redrop a removed edge sample')
            -- New evidence farther outside the shape, but still in the old
            -- sample exclusion disk, must remain eligible.
            local dx,dy=x-5000,y-5000;local length=math.sqrt(dx*dx+dy*dy)
            px=(x+20*dx/length)/10000;py=(y+20*dy/length)/10000
            assert(s:Observe(),'Accept evidence beyond the simplified boundary')
        ''')


if __name__ == '__main__':
    unittest.main()
