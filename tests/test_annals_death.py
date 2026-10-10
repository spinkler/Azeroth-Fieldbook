import unittest
from annals_test_harness import client
from test_player_names_preservation import full_client
from atlas_test_harness import ENV


class AnnalsDeathTests(unittest.TestCase):
    def test_startup_never_requests_forbidden_combat_log(self):
        l = self.host()
        l.execute('''
            local create=CreateFrame
            local attempts=0
            CreateFrame=function(...)
                local frame=create(...)
                local register=frame.RegisterEvent
                frame.RegisterEvent=function(self,event,...)
                    if event=='COMBAT_LOG_EVENT_UNFILTERED' then
                        attempts=attempts+1
                        error('forbidden registration already raised the native popup')
                    end
                    return register(self,event,...)
                end
                return frame
            end
            reset();t:Start()
            assert(attempts==0,'pcall cannot make a forbidden registration safe')
            t:Event('PLAYER_ENTERING_WORLD',true,false)
            t:Event('PLAYER_DEAD')
            local found=false
            for _,event in ipairs(db.events) do
                if event.kind=='death' then found=true;assert(not event.killer) end
            end
            assert(found,'ordinary death records must still work without combat log')
        ''')

    def host(self):
        l = client()
        l.execute('''
            playerGUID='Player-1-Self';killerGUID='Creature-0-1-2-3-42-1'
            function UnitGUID(unit) return unit=='player' and playerGUID or killerGUID end
            function UnitLevel(unit) return unit=='player' and 19 or 24 end
            function UnitIsPlayer(unit) return killerGUID:match('^Player')~=nil end
            function UnitRace() return 'Orc' end
            function UnitClass() return 'Warrior' end
            function blow(kind,overkill,dest)
                CombatLogGetCurrentEventInfo=function()
                    if kind=='SWING_DAMAGE' then
                        return now,kind,false,killerGUID,'Attacker',0,0,dest or playerGUID,'Me',0,0,50,overkill
                    elseif kind=='ENVIRONMENTAL_DAMAGE' then
                        return now,kind,false,nil,nil,0,0,playerGUID,'Me',0,0,'FALLING',50,overkill
                    end
                    return now,kind,false,killerGUID,'Attacker',0,0,dest or playerGUID,'Me',0,0,123,'Fire',4,50,overkill
                end
                t:Event('COMBAT_LOG_EVENT_UNFILTERED')
            end
        ''')
        return l

    def test_creature_player_and_storage(self):
        l = self.host()
        l.execute('''
            blow('SWING_DAMAGE',0);t:Event('PLAYER_DEAD');t:Event('PLAYER_DEAD')
            assert(#db.events==1 and db.events[1].killer.name=='Attacker')
            assert(db.events[1].killer.level==24 and not db.events[1].killer.player)
            assert(db.events[1].killer.ability=='Melee attack' and not db.events[1].killer.spellID)
            assert(ns.Annals.DeathText(db.events[1]):find('Level 24',1,true))
            t:Event('PLAYER_UNGHOST');killerGUID='Player-1-Enemy'
            blow('SPELL_PERIODIC_DAMAGE',5);t:Event('PLAYER_DEAD')
            local e=db.events[2];assert(e.killer.player and e.killer.race=='Orc' and e.killer.class=='Warrior')
            assert(e.killer.ability=='Fire' and e.killer.spellID==123)
            assert(ns.Annals.DeathText(e):find('Killing blow: Fire',1,true))
            assert(ns.Annals.DeathText(e):find('Orc',1,true))
            local restored=ns.CreateAnnalsJournal(db)
            assert(#restored.events==2 and restored.events[2].event.killer.class=='Warrior')
            local bad=ns.Annals.Copy(e);bad.killer.level='24';assert(not ns.Annals.ValidEvent(bad))
        ''')

    def test_nonfatal_other_victim_stale_and_environment(self):
        l = self.host()
        l.execute('''
            blow('SWING_DAMAGE',-1);t:Event('PLAYER_DEAD');assert(not db.events[1].killer)
            t:Event('PLAYER_UNGHOST');blow('SPELL_DAMAGE',5,'Player-1-Other')
            t:Event('PLAYER_DEAD');assert(not db.events[2].killer)
            t:Event('PLAYER_UNGHOST');blow('SWING_DAMAGE',5);advance(3)
            t:Event('PLAYER_DEAD');assert(not db.events[3].killer)
            t:Event('PLAYER_UNGHOST');blow('ENVIRONMENTAL_DAMAGE',0);t:Event('PLAYER_DEAD')
            assert(ns.Annals.DeathText(db.events[4])=='Killed by: Falling')
            t:Event('PLAYER_UNGHOST');t:Event('PLAYER_DEAD');assert(not db.events[5].killer)
        ''')

    def test_fresh_recap_retry_and_old_recap_rejection(self):
        l = self.host()
        l.execute('''
            link='old';recap={{sourceGUID=killerGUID,sourceName='Old killer'}}
            C_DeathRecap={GetRecapLink=function() return link end,GetRecapEvents=function() return recap end}
            reset();t:Event('PLAYER_DEAD');assert(not db.events[1].killer)
            link='new';recap={{sourceGUID=killerGUID,sourceName='New killer'},{sourceName='Earlier attacker'}}
            advance(1);assert(db.events[1].killer.name=='New killer')
            t:Event('PLAYER_UNGHOST');t:Event('PLAYER_DEAD');advance(1)
            assert(not db.events[2].killer,'old recap cannot be reused')
            t:Event('PLAYER_UNGHOST');t:Event('PLAYER_DEAD');t:Event('PLAYER_UNGHOST')
            link='later';advance(1);assert(not db.events[3].killer,'retry cannot survive resurrection')
        ''')

    def test_unknown_restricted_and_late_blow(self):
        l = self.host()
        l.execute('''
            function UnitLevel() return -1 end
            function UnitRace() return secret end
            function UnitClass() error('unavailable') end
            killerGUID='Player-1-Enemy'
            t:Event('PLAYER_DEAD');blow('SPELL_DAMAGE',0)
            local k=db.events[1].killer
            assert(k and not k.level and not k.race and not k.class)
            t:Event('PLAYER_UNGHOST')
            CombatLogGetCurrentEventInfo=function() error('unavailable') end
            t:Event('COMBAT_LOG_EVENT_UNFILTERED');t:Event('PLAYER_DEAD')
            assert(not db.events[2].killer)
            assert(ns.Annals.DeathText({kind='death'})=='Killer: unknown (not captured).')
        ''')

    def test_tooltip_detail_and_search(self):
        l = full_client();l.execute(ENV)
        l.execute('''
            local c=ns.AnnalsController;local j=c.journal
            local e,id=j:Append('death','Died',{killer={name='Enemy',level=24,player=true,race='Orc',class='Warrior'}},
                {mapID=101,x=2500,y=7500,level=19},100)
            c.shell:ShowSection('annals');c:SetRange(100,110);c:Refresh()
            local text=ns.Annals.EventText(e)
            assert(text:find('Killed by: Enemy',1,true) and text:find('Orc',1,true))
            assert(#ns.Annals.SearchEvents(j:Range(100,110),'Enemy Orc Warrior')==1)
            local pin=c.main.map.pins[1];pin.scripts.OnClick(pin,'LeftButton')
            local found=false
            for _,row in ipairs(c.main.detail.rows) do
                if row:IsShown() and row.label then
                    local value=row.label:GetText() or ''
                    if value:find('Killed by: Enemy',1,true) then found=true end
                end
            end
            assert(found,'death details must appear in Show detail')
        ''')

    def test_level_requires_matching_guid_and_loading_clears_evidence(self):
        l = self.host()
        l.execute('''
            t:Event('NAME_PLATE_UNIT_ADDED','nameplate1')
            function UnitGUID(unit) return unit=='player' and playerGUID or 'Creature-unrelated' end
            blow('RANGE_DAMAGE',0);t:Event('PLAYER_DEAD')
            assert(db.events[1].killer.level==24,'recent matching observation survives losing the unit')
            t:Event('PLAYER_UNGHOST');blow('SWING_DAMAGE',0);t:Event('PLAYER_DEAD')
            assert(not db.events[2].killer.level,'unrelated target cannot supply killer level')
            t:Event('PLAYER_UNGHOST');blow('SWING_DAMAGE',0);t:Event('PLAYER_LEAVING_WORLD')
            t:Event('PLAYER_DEAD');assert(not db.events[3].killer)
        ''')

    def test_legacy_recap_api(self):
        l = self.host()
        l.execute('''
            link='previous'
            function GetDeathRecapLink() return link end
            function DeathRecap_GetEvents() return {{sourceName='Legacy killer',spellName='Shadow Bolt',spellId=686}} end
            reset();link='current';t:Event('PLAYER_DEAD')
            assert(db.events[1].killer.name=='Legacy killer' and not db.events[1].killer.level)
            assert(db.events[1].killer.ability=='Shadow Bolt' and db.events[1].killer.spellID==686)
        ''')


if __name__ == '__main__':
    unittest.main()
