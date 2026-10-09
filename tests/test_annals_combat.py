"""Combat is trail metadata, never a timeline event or an inferred old encounter."""
import unittest

from annals_test_harness import client
from atlas_test_harness import ENV
from test_player_names_preservation import full_client


COMBAT = '''
    local A=ns.Annals
    combat=false
    function UnitAffectingCombat(unit) assert(unit=='player');return combat end
    function UnitIsDeadOrGhost() return false end
    function UnitIsGhost() return false end
    function UnitOnTaxi() return false end
    function IsMounted() return false end
    function IsInInstance() return false,'none' end
    function transition(value)
        combat=value;t:Event(value and 'PLAYER_REGEN_DISABLED' or 'PLAYER_REGEN_ENABLED')
    end
'''


class AnnalsCombatTests(unittest.TestCase):
    def test_moving_boundaries_playback_and_projection_without_events(self):
        l = client(); l.execute(COMBAT)
        l.execute('''
            local A=ns.Annals;local first=now
            t:Start()
            assert(t.capabilities.PLAYER_REGEN_DISABLED and t.capabilities.PLAYER_REGEN_ENABLED)
            t:Poll()
            advance(4);px=.26;t:Poll()
            advance(2);px=.27;transition(true)
            advance(2);px=.28;t:Poll()
            advance(2);px=.29;transition(false)
            advance(2);px=.30;t:Poll();trail:Break('done')
            assert(#db.events==0 and #j:Range(0,now)==0 and j.revision==0)
            assert(#db.segments==3 and db.segments[2].joinFrom==1 and db.segments[3].joinFrom==2)
            assert(db.segments[1].combat==false and db.segments[2].combat==true and db.segments[3].combat==false)
            local before=A.Decode(db.segments[1]);local during=A.Decode(db.segments[2])
            assert(before[#before].at==first+6 and before[#before].x==2700 and before[#before].anchor)
            assert(during[1].at==first+6 and during[#during].at==first+10 and during[#during].anchor)
            local idx=A.JourneyIndex(j,first,now,101,{accepted=false})
            for _,test in ipairs({{5,false},{6,true},{9,true},{10,false},{12,false}}) do
                local lines,markers,p=A.JourneyFrame(idx,first+test[1])
                assert(#markers==0 and p.combat==test[2],test[1])
                assert(A.JourneyPosition(idx,first+test[1]).combat==test[2])
                for _,edge in ipairs(lines) do
                    if edge.to.at>edge.from.at then
                        assert(edge.to.combat==edge.from.combat,'edge straddles a combat boundary')
                        if edge.to.combat then assert(edge.from.at>=first+6 and edge.to.at<=first+10) end
                    end
                end
            end
            C_Map.GetMapRectOnMap=function() return .1,.6,.2,.7 end
            local parent=A.JourneyIndex(j,first,now,100)
            local _,_,p=A.JourneyFrame(parent,first+6)
            assert(p.combat==true and p.x==2350)
        ''')

    def test_stationary_combat_retains_times_without_periodic_writes(self):
        l = client(); l.execute(COMBAT)
        l.execute('''
            local A=ns.Annals;local first=now;t:Poll()
            advance(2);transition(true)
            for i=1,30 do advance(2);t:Poll() end
            assert(points()==3,'stationary combat must not add periodic points')
            transition(false)
            assert(points()==5 and #db.segments==3)
            local idx=A.JourneyIndex(j,first,now,101)
            assert(A.JourneyPosition(idx,first+40).combat==true)
            assert(A.JourneyPosition(idx,now).combat==false)
            local saved=A.Copy(db);reset(saved)
            assert(#db.events==0 and A.JourneyPosition(A.JourneyIndex(j,first,now,101),first+40).combat==true)
            local count=points();t:Poll()
            assert(points()==count+1 and not db.segments[4].joinFrom,'reload starts a new segment')
        ''')

    def test_same_second_transitions_and_duplicate_notifications(self):
        l = client(); l.execute(COMBAT)
        l.execute('''
            local A=ns.Annals;t:Poll();transition(true);transition(true);transition(false)
            assert(#db.segments==3 and #db.events==0)
            assert(A.JourneyPosition(A.JourneyIndex(j,now,now,101),now).combat==false)
            advance(2);transition(true);advance(2);t:Poll()
            local revision=trail.revision
            transition(true);assert(trail.revision==revision,'duplicate notification must not force a point')
            assert(A.JourneyPosition(A.JourneyIndex(j,0,now,101),now).combat==true)
        ''')

    def test_discontinuities_do_not_join_combat_boundaries(self):
        l = client(); l.execute(COMBAT)
        l.execute('''
            t:Poll();advance(13);transition(true)
            assert(not db.segments[2].joinFrom and db.segments[1].finish<now)
            advance(2);px=.9;transition(false)
            assert(not db.segments[3].joinFrom)
            advance(2);C_Map.GetPlayerMapPosition=function() return nil end;transition(true)
            assert(#db.segments==3)
            C_Map.GetPlayerMapPosition=function() return {x=px,y=py} end
            advance(2);t:Poll();assert(#db.segments==4 and not db.segments[4].joinFrom and db.segments[4].combat)
        ''')

    def test_disabled_recording_loading_instances_and_write_guards(self):
        l = client(); l.execute(COMBAT)
        l.execute('''
            trail:SetEnabled(false);transition(true);transition(false);t:Poll()
            assert(#db.segments==0 and #db.events==0)
            trail:SetEnabled(true);t.loading=true;transition(true)
            assert(#db.segments==0)
            t.loading=false;t:Poll();assert(#db.segments==1 and db.segments[1].combat)
            j.readOnly=true;transition(false);assert(#db.segments==1)
            j.readOnly=false;ns.InitializationBlocked=true;transition(false);assert(#db.segments==1)
            ns.InitializationBlocked=nil
            function IsInInstance() return true,'party' end
            transition(false);assert(#db.segments==1)
        ''')

    def test_legacy_unknown_and_restricted_state_are_not_backfilled(self):
        l = client(); l.execute(COMBAT)
        l.execute('''
            local A=ns.Annals
            for _,value in ipairs({secret,'true',2}) do
                UnitAffectingCombat=function() return value end
                assert(A.Location().combat==nil)
            end
            UnitAffectingCombat=function() error('restricted') end
            assert(A.Location().combat==nil)
            t:Poll();local first=db.segments[1]
            assert(A.Decode(first)[1].combat==nil)
            advance(2);transition(true)
            assert(first.combat==nil and A.Decode(first)[1].combat==nil and db.segments[2].combat)
            advance(2);transition(false)
            assert(A.Decode(db.segments[3])[1].combat==false)
            local copy=A.Copy(first);local before=snapshot(copy)
            reset({schema=1,segments={copy}});A.JourneyFrame(A.JourneyIndex(j,0,now,101),now)
            assert(snapshot(copy)==before and copy.combat==nil)
        ''')

    def test_colours_priority_fading_and_smoothing(self):
        l = client(); l.execute('''
            local A=ns.Annals
            for _,age in ipairs({0,1800,99999}) do
                local r,g,b,alpha,heat=A.TrailColor(age,0,1,false,100,'alive',true)
                assert(r==1 and g==.35 and b==.05)
                local _,_,_,normalAlpha,normalHeat=A.TrailColor(age,0,1)
                assert(alpha==normalAlpha and heat==normalHeat)
            end
            for _,state in ipairs({'dead','ghost','dead / ghost','flight'}) do
                assert(snapshot({A.PlayerColor(state,true)})==snapshot({A.PlayerColor(state,false)}))
                assert(snapshot({A.TrailColor(0,0,1,state=='flight',100,state,true)})==snapshot({A.TrailColor(0,0,1,state=='flight',100,state,false)}))
            end
            local a={x=0,y=0,at=0,combat=true};local b={x=5000,y=0,at=10,combat=true}
            local c={x=5000,y=5000,at=20,combat=true}
            local lines=A.SmoothTrail({{from=a,to=b},{from=b,to=c}},500,500)
            assert(#lines>2)
            for _,edge in ipairs(lines) do assert(edge.from.combat and edge.to.combat) end
            c.combat=false;assert(#A.SmoothTrail({{from=a,to=b},{from=b,to=c}},500,500)==2)
        ''')

    def test_combat_change_at_map_join_does_not_recolour_the_approach(self):
        l = full_client(); l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local j=c.journal;local A=ns.Annals
            ns.AtlasEnvironment.World=function(p)
                return {x=p.x+(p.mapID==102 and 10000 or 0),y=p.y,continentID=1}
            end
            C_Map.GetMapRectOnMap=function(source)
                if source==101 then return 0,.5,0,1 end
                return .5,1,0,1
            end
            j.trail:Sample({mapID=101,x=9800,y=5000,at=100,state='alive',combat=false})
            j.trail:Sample({mapID=101,x=9900,y=5000,at=102,state='alive',combat=false})
            j.trail:Sample({mapID=102,x=100,y=5000,at=104,state='alive',combat=true})
            assert(j.db.segments[2].joinFrom==1)
            j.trail:Sample({mapID=102,x=300,y=5000,at=108,state='alive',combat=true},true)
            j.trail:SetEnabled(false)
            c.shell:ShowSection('annals')
            local idx=A.JourneyIndex(j,100,108,100);local map=c.main.map
            assert(A.JourneyPosition(idx,103).combat==false)
            map:ShowJourney(idx,104)
            assert(map.historicalPlayer.combat==true)
            local visible=0
            for _,line in ipairs(map.lines) do
                if line:IsShown() then
                    visible=visible+1;assert(line.colorTexture[2]~=.35,'approach must not inherit arrival combat')
                end
            end
            assert(visible>0)
            map:ShowJourney(idx,108)
            local orange=false
            for _,line in ipairs(map.lines) do if line:IsShown() and line.colorTexture[2]==.35 then orange=true end end
            assert(orange)
        ''')

    def test_map_footer_arrow_trail_and_legend_pages(self):
        l = full_client(); l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local j=c.journal;local A=ns.Annals
            for _,p in ipairs({{100,2500,false},{104,2700,true},{108,2900,true},{112,3100,false}}) do
                j.trail:Sample({mapID=101,x=p[2],y=5000,at=p[1],state='alive',combat=p[3]},true)
            end
            j.trail:SetEnabled(false)
            c.shell:ShowSection('annals');c:SetRange(100,112);c:Seek(108)
            local m=c.main;local map=m.map
            assert(map.playerArrow.vertexColor[2]==.35 and map.playerCoordinates:GetText():find('in combat',1,true))
            local orange=false
            for _,line in ipairs(map.lines) do
                if line:IsShown() and line.colorTexture and line.colorTexture[2]==.35 then orange=true end
            end
            assert(orange and #c.rows==0)
            c:Seek(112);assert(map.playerArrow.vertexColor[2]==1 and map.playerCoordinates:GetText():find('out of combat',1,true))
            click(m.legendButton)
            local legend=m.legend
            assert(legend.journey:IsShown() and not legend.events:IsShown() and legend.journeyTab.afbSelected)
            assert(legend.arrows[5].vertexColor[2]==.35 and legend.trails[7].texture.colorTexture[2]==.35)
            click(legend.eventsTab)
            assert(not legend.journey:IsShown() and legend.events:IsShown() and legend.eventsTab.afbSelected)
            assert(legend.icons.enter and legend.icons.exit and legend.icons.login and legend.icons.logout)
            click(legend.journeyTab);assert(legend.journey:IsShown() and not legend.events:IsShown())
            click(m.legendButton);assert(not legend:IsShown() and not m.legendButton.afbSelected)
            j:Append('instance','Entered',{instanceAction='enter',instanceName='Cave'},{mapID=101,x=3100,y=5000,state='alive',combat=true},113,true)
            local held=A.JourneyPosition(A.JourneyIndex(j,100,120,101),120)
            assert(held.instanceName=='Cave' and held.combat==nil,'held entrance must not imply interior combat')
        ''')


if __name__ == '__main__':
    unittest.main()
