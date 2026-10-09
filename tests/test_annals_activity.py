"""Observed idle/gathering intervals affect the arrow, never timeline volume."""
import unittest

from annals_test_harness import client
from atlas_test_harness import ENV
from test_annals_combat import COMBAT
from test_player_names_preservation import full_client


CAST = '''
    castSpell=nil
    function UnitCastingInfo()
        if castSpell then return 'Gather','Gather',1,0,1000,false,1,false,castSpell end
    end
    function start(spell,guid)
        castSpell=spell;t:Event('UNIT_SPELLCAST_START','player',guid or 'gather',spell)
    end
    function stop(event,spell,guid)
        castSpell=nil;t:Event(event or 'UNIT_SPELLCAST_STOP','player',guid or 'gather',spell or 2366)
    end
    function resting(seconds)
        for i=1,seconds/2 do advance(2);t:Poll() end
    end
    function position(at)
        return ns.Annals.JourneyPosition(ns.Annals.JourneyIndex(j,0,now,101),at or now)
    end
'''


def activity_client():
    l = client(); l.execute(COMBAT + CAST)
    return l


class AnnalsActivityTests(unittest.TestCase):
    def test_idle_at_ten_seconds_and_no_periodic_idle_points(self):
        l = activity_client(); l.execute('''
            local first=now;t:Poll();resting(8)
            assert(position().activity==nil)
            resting(2)
            assert(position(first+9.99).activity==nil and position(first+10).activity=='idle')
            local count,revision=points(),trail.revision
            resting(60)
            assert(points()==count and trail.revision==revision)
            assert(#db.segments==2 and #db.events==0)
            local saved=ns.Annals.Copy(db);reset(saved)
            assert(position(first+10).activity=='idle','reload must preserve the recorded interval')
        ''')

    def test_irregular_poll_crosses_exact_idle_threshold(self):
        l = activity_client(); l.execute('''
            local first=now;t:Poll();advance(7);t:Poll();advance(4);t:Poll()
            assert(db.segments[2].at==first+10)
            assert(position(first+9.9).activity==nil and position(first+10).activity=='idle')
        ''')

    def test_even_small_movement_resumes_and_restarts_idle_timer(self):
        l = activity_client(); l.execute('''
            local first=now;t:Poll();resting(12)
            advance(2);px=px+.0001;t:Poll()
            assert(position().activity==nil)
            assert(position(first+11).activity=='idle')
            assert(position(first+13).activity==nil and position(first+13).interpolated)
            resting(8);assert(position().activity==nil)
            resting(2);assert(position().activity=='idle')
            for i=1,10 do advance(2);px=px+.0001;t:Poll();assert(position().activity==nil) end
            assert(#db.events==0)
        ''')

    def test_combat_interrupts_idle_and_keeps_stationary_fights_active(self):
        l = activity_client(); l.execute('''
            t:Poll();resting(10);assert(position().activity=='idle')
            transition(true);assert(position().combat and position().activity==nil)
            resting(30);assert(position().combat and position().activity==nil)
            transition(false);resting(8);assert(position().activity==nil)
            resting(2);assert(position().activity=='idle')
        ''')

    def test_gathering_start_and_all_end_events_without_new_timeline_rows(self):
        l = activity_client(); l.execute('''
            for _,spell in ipairs({2366,2575}) do
                for _,ending in ipairs({'UNIT_SPELLCAST_STOP','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_FAILED_QUIET','UNIT_SPELLCAST_INTERRUPTED'}) do
                    reset();combat=false;castSpell=nil;t:Poll();resting(10)
                    local began=now;start(spell)
                    assert(position().activity=='gathering')
                    advance(3);stop(ending,spell)
                    assert(position(began+1).activity=='gathering' and position().activity==nil)
                    assert(#db.events==0)
                    resting(8);assert(position().activity==nil)
                    resting(2);assert(position().activity=='idle')
                end
            end
        ''')

    def test_gathering_localized_ranks_other_units_and_stale_cast_events(self):
        l = activity_client(); l.execute('''
            C_Spell={GetSpellName=function(id)
                if id==2366 or id==12345 then return 'Cueillette' end
                if id==2575 then return 'Minage' end
                return 'Crafting'
            end}
            t:Start();assert(t.capabilities.UNIT_SPELLCAST_STOP and t.capabilities.UNIT_SPELLCAST_FAILED_QUIET)
            t:Poll();start(12345,'first');assert(position().activity=='gathering')
            advance(2);start(2575,'second')
            t:Event('UNIT_SPELLCAST_STOP','player','first',12345)
            assert(position().activity=='gathering')
            t:Event('UNIT_SPELLCAST_STOP','target','second',2575)
            assert(position().activity=='gathering')
            advance(2);start(99999,'crafting');assert(position().activity==nil)
            t:Event('UNIT_SPELLCAST_START','target','npc',2366)
            assert(position().activity==nil)
            t:Event('UNIT_SPELLCAST_START',secret,'secret',2366)
            assert(position().activity==nil)
        ''')

    def test_gathering_baseline_reload_and_missing_stop_expiry(self):
        l = activity_client(); l.execute('''
            castSpell=2366;t:Poll();assert(position().activity=='gathering')
            local saved=ns.Annals.Copy(db);reset(saved);t:Poll()
            assert(position().activity=='gathering' and not db.segments[2].joinFrom)
            advance(2);stop();assert(position().activity==nil)
            advance(2);start(2366)
            UnitCastingInfo=nil
            resting(28);assert(position().activity=='gathering')
            resting(2);assert(position().activity==nil)
            -- A cast first seen by a reload-time query also has bounded state.
            reset();UnitCastingInfo=function() return 'Gather','Gather',1,0,1000,false,1,false,2366 end
            t:Poll();assert(position().activity=='gathering' and t.gatheringCast==nil)
            UnitCastingInfo=nil;resting(30);assert(position().activity==nil)
        ''')

    def test_activity_changes_keep_last_observed_combat_during_restricted_reads(self):
        l = activity_client(); l.execute('''
            t:Poll();transition(true)
            UnitAffectingCombat=function() return secret end
            advance(2);start(2366)
            assert(position().combat==true and position().activity=='gathering')
            assert(select(2,ns.Annals.PlayerColor('alive',position().combat,position().activity))==.35)
            advance(2);stop();assert(position().combat==true)
            transition(false);resting(10)
            assert(position().combat==false and position().activity=='idle')
        ''')

    def test_gaps_recording_off_unknown_combat_and_legacy_do_not_invent_idle(self):
        l = activity_client(); l.execute('''
            t:Poll();advance(20);t:Poll()
            assert(position().activity==nil and not db.segments[2].joinFrom)
            resting(8);assert(position().activity==nil)
            trail:SetEnabled(false);local count=#db.segments
            resting(10);start(2366);stop();assert(#db.segments==count)
            trail:SetEnabled(true);t:Poll();resting(8);assert(position().activity==nil)
            reset();UnitAffectingCombat=function() return secret end
            t:Poll();resting(20);assert(position().activity==nil)
            UnitCastingInfo=function() return secret end
            assert(ns.Annals.GatheringActivity()==nil)
            UnitCastingInfo=function() error('restricted') end
            assert(ns.Annals.GatheringActivity()==nil)
            local old={v=1,mapID=101,at=1,finish=1,data=ns.Annals.EncodePoint({x=1,y=1,at=1},1)}
            reset({schema=1,segments={old}})
            assert(position().activity==nil and old.activity==nil)
        ''')

    def test_arrow_priority_footer_legend_and_trail_colour_stays_unchanged(self):
        l = full_client(); l.execute(ENV + COMBAT + CAST)
        l.execute('''
            local c=ns.AnnalsController;j=c.journal;trail=j.trail;t=c.tracking
            local A=ns.Annals
            now=100;t:Poll()
            for at=102,110,2 do now=at;t:Poll() end
            now=112;start(2366)
            now=116;stop()
            trail:SetEnabled(false)
            c.shell:ShowSection('annals');c:SetRange(100,116)
            local map=c.main.map
            c:Seek(109);assert(map.playerArrow.vertexColor[1]==1)
            c:Seek(110);assert(map.playerArrow.vertexColor[1]==.5 and map.playerCoordinates:GetText():find('idle',1,true))
            c:Seek(112);assert(map.playerArrow.vertexColor[2]==.85 and map.playerCoordinates:GetText():find('gathering',1,true))
            c:Seek(116);assert(map.playerArrow.vertexColor[1]==1 and map.playerArrow.vertexColor[2]==1)
            assert(#c.rows==0)
            local legend=c.main.legend;click(c.main.legendButton)
            assert(#legend.arrows==7 and #legend.trails==7)
            assert(legend.arrows[6].vertexColor[1]==.5 and legend.arrows[7].vertexColor[2]==.85)
            assert(snapshot({A.PlayerColor('alive',true,'idle')})==snapshot({A.PlayerColor('alive',true,'gathering')}))
            for _,state in ipairs({'dead','ghost','flight'}) do
                assert(snapshot({A.PlayerColor(state,false,'idle')})==snapshot({A.PlayerColor(state,false,'gathering')}))
            end
            -- Activity metadata does not recolour the route ribbon.
            j.db.settings.trailContrast=0
            for _,kind in ipairs({'idle','gathering'}) do
                local p={x=1000,y=1000,at=1,mapID=101,combat=false,activity=kind}
                local q=A.Copy(p);q.x=2000;q.at=2
                local segment={v=1,mapID=101,at=1,finish=2,combat=false,activity=kind,
                    data=A.EncodePoint(p,1)..A.EncodePoint(q,1)}
                local journal=ns.CreateAnnalsJournal({segments={segment}})
                map:ShowJourney(A.JourneyIndex(journal,1,2,101),2)
                assert(map.lines[1].colorTexture[1]==1 and map.lines[1].colorTexture[2]==.82)
            end
        ''')


if __name__ == '__main__':
    unittest.main()
