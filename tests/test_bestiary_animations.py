"""Profile-driven playback and cancellation; native assets still need WoW."""
import unittest
from ui_test_harness import new_ui_client
from test_bestiary_models import new_ui_client as model_client
from test_bestiary_model_reuse import FILES
from run_tests import validate_addon


class BestiaryAnimationsTests(unittest.TestCase):
    def client(self):
        lua = new_ui_client(['BestiaryAnimations.lua'])
        lua.execute('''
            math.randomseed(124)
            animations, effects, allowed = {}, {}, {[0]=true}
            model={}
            function model:HasAnimation(id) return allowed[id] == true end
            function model:SetAnimation(id) animations[#animations+1]=id end
            function model:ApplySpellVisualKit(id,oneShot)
                assert(oneShot==true);effects[#effects+1]=id
            end
            controller=ns.CreateBestiaryAnimations(model)
            entry={id=42,behaviours={},offenses={}}
            function tick(dt,ready,rotating)
                controller:Update(dt,entry,ready~=false,rotating)
            end
            function advance(seconds)
                for i=1,seconds*10 do tick(.1) end
            end
        ''')
        return lua

    def test_melee_ranged_supported_choices_and_timing(self):
        lua = self.client()
        lua.execute('''
            allowed[16]=true;allowed[17]=true;allowed[47]=true
            entry.behaviours={Melee=true,Ranged=true}
            local times,previous,clock={},nil,0
            function model:SetAnimation(id)
                assert(id==0 or id==16 or id==17 or id==47)
                if id~=0 then
                    assert(id~=previous,'repeated choice despite alternatives')
                    previous=id;times[#times+1]=clock
                end
            end
            for i=1,1800 do clock=i/10;tick(.1) end
            assert(#times>15 and #times<40)
            assert(times[1]>=2 and times[1]<=4.1)
            local gaps={}
            for i=2,#times do
                local gap=times[i]-times[i-1]
                assert(gap>=5.1 and gap<=9.5,'unbounded or repetitive attack timing')
                gaps[math.floor(gap*10+.5)]=true
            end
            local count=0;for _ in pairs(gaps) do count=count+1 end
            assert(count>3,'pauses did not vary')
            assert(#effects==0)
        ''')

    def test_selected_schools_only_and_cast_sequence(self):
        lua = self.client()
        lua.execute('''
            allowed[51]=true;allowed[53]=true
            entry.behaviours.Caster=true;entry.offenses={Fire=true,Frost=true}
            advance(80)
            assert(#effects>4)
            for i,kit in ipairs(effects) do
                assert(kit==38 or kit==202)
                if i>1 then assert(kit~=effects[i-1]) end
            end
            for i,id in ipairs(animations) do
                local stage=(i-1)%3
                assert(id==(stage==0 and 51 or stage==1 and 53 or 0))
            end
            for school,kit in pairs({Arcane=730,Fire=38,Frost=202,Holy=119,Nature=3291,Shadow=118}) do
                controller:Reset();animations={};effects={};entry.offenses={[school]=true}
                advance(7);assert(#effects==1 and effects[1]==kit)
            end
        ''')

    def test_missing_capabilities_and_no_inferred_combat_style(self):
        lua = self.client()
        lua.execute('''
            allowed[53]=true;entry.offenses.Fire=true
            advance(20);assert(#animations==0 and #effects==0)
            entry.behaviours.Melee=true
            advance(20);assert(#animations==0,'unsupported melee became a cast')
            entry.behaviours={Caster=true};allowed[53]=nil;allowed[54]=true
            controller:Reset();advance(7)
            assert(animations[1]==54 and animations[2]==0 and #effects==0,
                'directed visual kit must not override an omni-only rig')
            controller:Reset();animations={};model.HasAnimation=nil
            advance(20);assert(#animations==0)
            model.HasAnimation=function() return secret end
            controller:Reset();advance(20);assert(#animations==0)
            model.HasAnimation=function() error('unsupported API') end
            controller:Reset();advance(20);assert(#animations==0)
        ''')

    def test_profile_changes_rotation_and_readiness_cancel(self):
        lua = self.client()
        lua.execute('''
            allowed[51]=true;allowed[53]=true
            entry.behaviours.Caster=true;entry.offenses.Fire=true
            tick(4);assert(animations[1]==51)
            entry.behaviours={};tick(.1)
            advance(20);assert(animations[2]==0 and #effects==0)
            entry.behaviours.Caster=true;tick(4)
            tick(.1,true,true);assert(animations[#animations]==0)
            for i=1,20 do tick(1,true,true) end
            assert(#effects==0)
            tick(4);assert(animations[#animations]==51)
            tick(.1,false);assert(animations[#animations]==0)
            for i=1,20 do tick(1,false) end
            assert(#effects==0)
            tick(60);assert(animations[#animations]==51 and #effects==0,
                'long frame must not run a whole sequence at once')
        ''')

    def test_failures_are_bounded_and_cast_without_visual_still_returns_idle(self):
        lua = self.client()
        lua.execute('''
            allowed[53]=true;entry.behaviours.Caster=true;entry.offenses.Fire=true
            local failures=0
            function model:ApplySpellVisualKit() failures=failures+1;error('missing visual') end
            advance(40)
            assert(failures==1 and animations[1]==53 and animations[2]==0)
            controller:Reset();animations={};local attempts=0
            function model:SetAnimation(id)
                if id==53 then attempts=attempts+1;error('unavailable animation') end
            end
            advance(40);assert(attempts==1)
        ''')

    def test_book_loading_selection_and_hiding(self):
        files = list(FILES)
        files.insert(files.index('BestiaryBook.lua'), 'BestiaryAnimations.lua')
        lua = model_client(files)
        lua.execute('''
            function modelSetup(frame)
                frame.complete=true
                function frame:HasAnimation(id) return id==0 or id==51 or id==53 end
                function frame:SetAnimation(id) self.anim=id end
                function frame:ApplySpellVisualKit(id) self.effect=id end
            end
            j=ns.CreateBestiaryJournal({},function() return npcID end)
            c=ns.CreateBestiaryBook(j);c:OpenAtUnit('target')
            section=AzerothFieldbookBestiarySection;model=section.model
            assert(section.modelAnimations)
            j.entries[42].behaviours={Caster=true};j.entries[42].offenses={Fire=true}
            model.scripts.OnUpdate(model,4);assert(model.anim==51)
            npcID=43;c:OpenAtUnit('target')
            model.scripts.OnUpdate(model,10)
            assert(model.anim==0 and model.effect==nil,'old cast leaked into next creature')
            j.entries[43].behaviours={Caster=true};j.entries[43].offenses={Frost=true}
            model.scripts.OnUpdate(model,4);assert(model.anim==51)
            section:Hide()
            -- The widget host does not propagate ancestor OnHide to children;
            -- WoW does. Deliver that native child notification explicitly.
            model.scripts.OnHide(model);assert(model.anim==0)
            model.scripts.OnUpdate(model,10);assert(model.effect==nil)
            section:Show();model.scripts.OnUpdate(model,4);assert(model.anim==51)
            model.complete=false;c:OpenAtUnit('target')
            model.scripts.OnUpdate(model,10)
            assert(section.modelPending and model.effect==nil)
            j.entries[43].personalEncountered=false;c:Refresh()
            model.scripts.OnUpdate(model,10);assert(model.effect==nil)
        ''')


if __name__ == '__main__':
    validate_addon()
    unittest.main(verbosity=2)
