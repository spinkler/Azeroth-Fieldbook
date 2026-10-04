"""Fishing data, capture, provenance, reports and real section widget tests."""
import unittest
from angling_test_harness import new_angling
from atlas_test_harness import ATLAS_MODULES
from ui_test_harness import ROOT


class AnglingDataTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_angling()

    def test_event_log_cumulative_catches_unlimited_reload_and_clear_isolation(self):
        self.lua.execute('''
            observe('one',nil,nil,nil,nil,{{itemID=1001,name='Fish',quantity=1}})
            assert(#saved.eventLog==1 and saved.eventLog[1].kind=='Catch')
            local stamp=saved.eventLog[1].at;now=now+1
            observe('one',nil,nil,nil,nil,{{itemID=1001,name='Fish',quantity=3}})
            assert(#saved.eventLog==1 and saved.eventLog[1].at==stamp)
            assert(saved.eventLog[1].message:find('3',1,true))
            local before=snapshot(saved.eventLog)
            observe('one',nil,nil,nil,nil,{{itemID=1001,name='Fish',quantity=3}})
            assert(snapshot(saved.eventLog)==before)
            observe('manual',nil,nil,nil,'recorded');assert(saved.eventLog[2].kind=='Manual catch')
            for i=1,210 do j:Log('Test','Event '..i) end
            assert(#saved.eventLog==212 and saved.eventLog[1].kind=='Catch')
            j=ns.CreateAnglingJournal(saved);assert(#saved.eventLog==212)
            local facts=snapshot(saved.aggregates);local history=snapshot(saved.history)
            j:ClearEventLog();assert(#saved.eventLog==0 and facts==snapshot(saved.aggregates) and history==snapshot(saved.history))
            j=ns.CreateAnglingJournal(saved);assert(#saved.eventLog==0,'no backfill')
            saved.schema=99;before=snapshot(saved);local future=ns.CreateAnglingJournal(saved)
            future:Log('Test','No');future:ClearEventLog();assert(snapshot(saved)==before)
        ''')

    def test_event_log_discovery_corrections_and_private_notes(self):
        self.lua.execute('''
            local e=assert(j:ObservePool({name='Oily Blackmouth School'},A.CurrentLocation()))
            assert(#saved.eventLog==1)
            j:ObservePool({name='Oily Blackmouth School'},A.CurrentLocation());assert(#saved.eventLog==1)
            j:SetSightingRemoved(e.id,true);j:SetSightingRemoved(e.id,true);assert(#saved.eventLog==2)
            j:SetSightingRemoved(e.id,false);assert(#saved.eventLog==3)
            j:Edit(e.id,e.name,'Private secret note',true)
            assert(not snapshot(saved.eventLog):find('Private secret note',1,true))
        ''')

    def test_large_event_log_reload_index_and_clear_release_rows(self):
        self.lua.execute('''
            local data={};local log=ns.CreateAnglingJournal(data)
            for i=1,5000 do log:Log('Test','Event '..i,'event:'..i) end
            assert(#data.eventLog==5000 and data.eventLog[1].message=='Event 1')
            log=ns.CreateAnglingJournal(data)
            log:Log('Test','Updated oldest','event:1')
            assert(#data.eventLog==5000 and data.eventLog[1].message=='Updated oldest')
            local refs=setmetatable({data.eventLog,data.eventLog[1],data.eventLog[5000]},{__mode='v'})
            log:ClearEventLog();collectgarbage('collect');collectgarbage('collect')
            assert(next(refs)==nil,'cleared rows must not remain in the index')
            log:Log('Test','New history','event:1')
            assert(#data.eventLog==1 and data.eventLog[1].message=='New history')
        ''')

    def test_empty_schema_migration_future_protection_and_reload(self):
        self.lua.execute('''
            for _,v in ipairs({'waters','pools','catches'}) do assert(#j:List(v)==0) end
            assert(#saved.history==0 and #saved.sessions==0 and total()==0)
            saved.schema=0;saved.extension={keep='mine'};j=ns.CreateAnglingJournal(saved)
            local e=spot();observe('one');j:View('waters').selected=e.id;j:View('waters').query='lantern'
            local before=snapshot(saved);j=ns.CreateAnglingJournal(saved)
            assert(before==snapshot(saved) and saved.schema==1 and saved.extension.keep=='mine')
            assert(j:Get(e.id).note=='Bring a lantern' and #j:List('catches')==1)
            saved.schema=99;before=snapshot(saved);local future=ns.CreateAnglingJournal(saved)
            assert(future.readOnly and not future:Remember({name='No',location=A.CurrentLocation()}))
            future:View('waters').query='detached';assert(before==snapshot(saved))
        ''')

    def test_pool_type_identity_locations_and_reverse_lookup(self):
        self.lua.execute('''
            local a=spot('West pool','Synthetic school')
            observe('a','pool',a.poolID,a.id)
            mapID=102;local b=spot('Hill pool','Synthetic school')
            observe('b','pool',b.poolID,b.id)
            observe('open','open');observe('unknown')
            assert(a.poolID==b.poolID and A.Count(saved.pools)==1 and A.Count(saved.spots)==2)
            local fish=j:List('catches')[1];local s=j:Summary(fish)
            assert(s.events==4 and s.items[fish.id].quantity==12 and #j:Links(fish,'locations')==3)
            local pool=j:Get(a.poolID);assert(j:Summary(pool).events==2 and #j:Links(pool,'locations')==2)
            assert(j:Summary(pool,{mapID=101}).events==1)
            assert(#j:List('pools',{mapID=102})==1 and #j:List('pools',{mapID=999})==0)
            assert(j:Summary(j:Get(a.waterID)).events==1)
        ''')

    def test_name_fallbacks_are_conservative_and_sightings_reveal_no_contents(self):
        self.lua.execute('''
            local a=spot('Pool one','Similar Pool');local b=spot('Pool two','Similar Pools')
            assert(a.poolID~=b.poolID and #j:List('pools')==2)
            assert(#j:List('catches')==0 and j:Summary(j:Get(a.poolID)).events==0)
            assert(#j:List('pools',{status='unfished'})==2)
            local idPool=j:Ensure('pool',{objectID=123,name='Similar Pool'},'observed')
            assert(idPool.id~=a.poolID,'a name does not prove an object ID')
            local fr=j:Ensure('pool',{name='Similar Pool',locale='frFR'},'recorded');assert(fr.id~=a.poolID)
        ''')

    def test_search_filters_favourites_and_connected_notes(self):
        self.lua.execute('''
            local e=spot('Moonlit pier','Synthetic school');observe('one','pool',e.poolID,e.id)
            j:Edit(e.id,e.name,'Lantern beside the ferry',true)
            assert(#j:List('catches',{query='ferry'})==1)
            assert(#j:List('pools',{query='Moonlit'})==1)
            assert(#j:List('waters',{query='Synthetic fish',status='fished'})==2)
            assert(#j:List('waters',{status='favourites'})==1)
            assert(#j:List('catches',{source='open'})==0)
            assert(#j:List('catches',{knowledge='reported'})==0)
            assert(#j:List('catches',{mapID=101,source='pool'})==1)
        ''')

    def test_occurrences_quantities_multislot_duplicates_and_bounded_history(self):
        self.lua.execute('''
            local context=j:Context(A.CurrentLocation(),nil,'observed',{effective=205})
            local items={{itemID=1001,name='Fish',quantity=2},{itemID=1001,name='Fish',quantity=3},{itemID=2001,name='Old boot',quantity=1}}
            local f=assert(j:RecordCatch('same',context,items));assert(f.events==1)
            assert(j:RecordCatch('same',context,items));assert(f.events==1)
            local fish=saved.itemKeys['item:1001'];local boot=saved.itemKeys['item:2001']
            assert(f.items[fish].quantity==5 and f.items[fish].occurrences==1 and f.items[boot].occurrences==1)
            for i=1,300 do now=now+1;observe('cast-'..i) end
            assert(total()==301 and #saved.history==A.HISTORY_LIMIT and #saved.recentOrder==A.RECENT_LIMIT)
            assert(A.Count(saved.recent)==A.RECENT_LIMIT and #saved.sessions<=A.SESSION_LIMIT)
            local s=j:Summary(j:Get(context.waterID));assert(s.events==301 and s.items[fish].quantity==905)
            assert(f.first==1000000 and f.last==now)
            j=ns.CreateAnglingJournal(saved);assert(j:RecordCatch('cast-300',j:Context(A.CurrentLocation(),nil,'observed'),{{itemID=1001,quantity=3}}))
            assert(total()==301,'durable replay ledger survives reload')
        ''')

    def test_skill_evidence_stays_in_context_and_manual_success_is_not_measured(self):
        self.lua.execute('''
            local e=spot('Pool','School');local f=observe('pool','pool',e.poolID,e.id,'observed',nil,{base=150,modifier=55,temporary=0,effective=205})
            observe('open','open',nil,nil,'observed',nil,{effective=125})
            observe('manual','pool',e.poolID,e.id,'recorded',nil,{effective=1})
            assert(f.lowestSkill.effective==205 and f.requirement==nil and f.minimum==nil)
            local facts=j:Facts(j:Get(e.poolID),'personal');assert(#facts==2)
            for _,row in ipairs(facts) do if row.fact.method=='recorded' then assert(not row.fact.lowestSkill) end end
            local r=reportFor(e.poolID);local text=R.Preview(r)
            assert(text:find('Lowest successful effective skill reported: 205',1,true))
            assert(text:find('requirement unknown',1,true))
        ''')

    def test_spots_do_not_coalesce_by_proximity_and_merge_preserves_history(self):
        self.lua.execute('''
            local a=spot('First','School');px=px+0.0001;local b=spot('Second','School')
            assert(a.id~=b.id and A.Count(saved.spots)==2)
            local f1=observe('one','pool',a.poolID,a.id);local f2=observe('two','pool',b.poolID,b.id)
            j:Edit(a.id,a.name,'First original note',true)
            local merged=assert(j:MergeSpots(a.id,b.id))
            assert(A.Count(saved.spots)==1 and merged.favourite and saved.merged[a.id].note=='First original note')
            assert(saved.merged[a.id].x~=nil and f1.spotID==b.id and f2.spotID==b.id)
            assert(j:Summary(merged).events==2 and #j:Links(j:List('catches')[1],'locations')==1)
            mapID=102;local other=spot('Other','School');assert(not j:MergeSpots(other.id,b.id))
        ''')

    def test_location_precision_invalid_coordinates_and_no_per_cast_pins(self):
        self.lua.execute('''
            local e=spot();assert(e.precision=='player' and A.PositionLabel(e):find('approximate',1,true))
            for i=1,25 do px=px+0.001;observe('c'..i) end
            assert(A.Count(saved.spots)==1)
            px=0;py=0;local blank=spot('Unpositioned')
            assert(blank.x==nil and blank.y==nil and blank.precision=='unknown')
            px=0/0;py=5;assert(not A.Location(A.CurrentLocation()).x)
        ''')

    def test_hover_merge_chains_survive_reload_and_repair_legacy_lookup(self):
        self.lua.execute('''
            local p=A.CurrentLocation();p.subzone=''
            local input={name='Synthetic school'}
            local hover=assert(j:ObservePool(input,p))
            local first=assert(j:Remember({name='First correction',location=p,pool=input}))
            local final=assert(j:Remember({name='Final correction',location=p,pool=input}))
            assert(j:MergeSpots(hover.id,first.id));assert(j:MergeSpots(first.id,final.id))
            local function check()
                local events=#saved.eventLog
                assert(j:ObservePool(input,p).id==final.id)
                assert(A.Count(saved.spots)==1 and #saved.eventLog==events)
            end
            now=now+1;check()
            j=ns.CreateAnglingJournal(saved);now=now+1;check()
            -- Older versions persisted the deleted hover ID, even through chained merges.
            saved.hoverKeys[A.Key(hover.poolID,hover.waterID)]=hover.id
            j=ns.CreateAnglingJournal(saved);now=now+1;check()
            assert(j:SetSightingRemoved(final.id,true))
            assert(j:ObservePool(input,p).id==final.id)
            check();assert(not j:Get(final.id).removed and A.Count(saved.spots)==1)
            assert(final.x==p.x and final.y==p.y and not final.hover,
                'Hovering must not replace the deliberately recorded position or its provenance')
        ''')

    def test_merge_reindexes_aggregates_without_fragmenting_future_catches(self):
        self.lua.execute('''
            local a=spot('First','School');local b=spot('Second','School')
            local f1=observe('one','pool',a.poolID,a.id)
            local f2=observe('two','pool',b.poolID,b.id)
            local elsewhere=observe('elsewhere','open')
            assert(j:MergeSpots(a.id,b.id))
            assert(A.Count(saved.aggregates)==3 and f1.id~=f2.id)
            assert(observe('three','pool',b.poolID,b.id).id==f2.id)
            assert(observe('elsewhere-again','open').id==elsewhere.id)
            assert(A.Count(saved.aggregates)==3 and total()==5)
            j=ns.CreateAnglingJournal(saved)
            assert(observe('four','pool',b.poolID,b.id).id==f2.id)
            saved.aggregateKeys={};j=ns.CreateAnglingJournal(saved)
            observe('legacy-index','pool',b.poolID,b.id)
            assert(A.Count(saved.aggregates)==3 and total()==7)
            assert(saved.aggregates[f1.id] and saved.aggregates[f2.id],
                'Correction must retain separate historical source aggregates')
        ''')

    def test_duplicate_token_cannot_move_quantity_between_pool_contexts(self):
        self.lua.execute('''
            local a=spot('First pool','School A');local b=spot('Second pool','School B')
            observe('one','pool',a.poolID,a.id)
            local context=j:Context(A.CurrentLocation(),{source='pool',poolID=b.poolID,spotID=b.id},'observed')
            assert(not j:RecordCatch('one',context,{{itemID=1001,quantity=9}}))
            assert(j:Summary(a).events==1 and j:Summary(b).events==0)
        ''')


class AnglingCaptureTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_angling()

    def test_hover_discovers_zone_without_pins_catches_or_assignment(self):
        self.lua.execute('''
            hoverPool('Synthetic School')
            local pool=j:List('pools',{mapID=101})[1];assert(pool and pool.personal.observed)
            assert(#j:List('pools',{mapID=102})==0 and total()==0 and not t:Assignment())
            local locations=j:Links(pool,'locations');assert(#locations==1)
            local e=locations[1];assert(e.hover and not e.x and not e.y and e.subzone=='')
            local count=A.Count(saved.spots);now=now+5;hoverPool('Synthetic School')
            assert(A.Count(saved.spots)==count and e.last==now)
            mapID=102;hoverPool('Synthetic School');assert(#j:List('pools')==1 and A.Count(saved.spots)==2)
            assert(#j:List('pools',{mapID=102,query='hills'})==1)
            catch('after-hover');assert(j:Summary(pool).events==0 and total()==1)
            local report=reportFor(pool.id);assert(#report.facts==0 and #report.records==5)
        ''')

    def test_native_hover_without_processor_callback_or_processing_info(self):
        self.lua.execute('''
            cursorInfo={getterName='GetWorldCursor'}
            cursorData={type=4,lines={{leftText='Oily Blackmouth School'}}}
            GameTooltip:Show();GameTooltip.scripts.OnUpdate(GameTooltip,0.2)
            assert(#j:List('pools',{mapID=101})==1)
            local count=A.Count(saved.spots)
            GameTooltip.scripts.OnUpdate(GameTooltip,0.2);assert(A.Count(saved.spots)==count)
            cursorInfo=nil;WorldFrame=CreateFrame('Frame')
            local focus=WorldFrame;function GetMouseFoci() return {focus} end
            cursorData={type=4,lines={{leftText='Sagefish School'}}}
            GameTooltip.scripts.OnUpdate(GameTooltip,0.1);assert(#j:List('pools')==1)
            GameTooltip.scripts.OnUpdate(GameTooltip,0.1);assert(#j:List('pools')==2)
            focus=CreateFrame('Button');cursorData={type=4,lines={{leftText='UI School'}}}
            GameTooltip.scripts.OnUpdate(GameTooltip,0.2);assert(#j:List('pools')==2)
            focus=WorldFrame;GameTooltip:Hide();GameTooltip.scripts.OnUpdate(GameTooltip,0.2)
            assert(#j:List('pools')==2 and total()==0)
        ''')

    def test_removed_sighting_is_rediscovered_in_its_zone(self):
        self.lua.execute('''
            hoverPool('Synthetic School');local pool=j:List('pools')[1]
            local sighting=j:Links(pool,'locations')[1]
            assert(j:SetSightingRemoved(sighting.id,true))
            assert(#j:List('pools')==1 and #j:List('pools',{mapID=101})==0)
            assert(#j:List('waters',{status='removed'})==1 and #j:Links(pool,'locations')==0)
            local reloaded=ns.CreateAnglingJournal(saved);assert(reloaded:Get(sighting.id).removed)
            assert(reloaded:ObservePool({name='Synthetic School'},A.CurrentLocation()).id==sighting.id)
            assert(not sighting.removed and #j:Links(pool,'locations')==1)
            now=now+10;hoverPool('Synthetic School')
            mapID=102;hoverPool('Synthetic School');assert(#j:List('pools',{mapID=102})==1)
            assert(A.Count(saved.spots)==2 and #j:Links(pool,'locations')==2)
            local r=reportFor(pool.id);assert(#r.records==5 and #r.facts==0)
            assert(R.Build(j,sighting.id,'personal'))
            assert(#j:List('pools',{mapID=101})==1)
        ''')

    def test_removed_sighting_keeps_catches_but_is_not_shared_or_pinned(self):
        self.lua.execute('''
            local e=spot('Incorrect spot','School');observe('old','pool',e.poolID,e.id)
            local before=snapshot(saved.aggregates);assert(j:SetSightingRemoved(e.id,true))
            assert(snapshot(saved.aggregates)==before and j:Summary(e).events==1)
            local pool=j:Get(e.poolID);local r=reportFor(pool.id)
            assert(#r.facts==0 and #r.records==1)
            assert(not t:Assign('pool',e.id))
            local links=j:Links(j:List('catches')[1],'locations')
            assert(#links==1 and links[1].kind=='water')
            assert(j:SetSightingRemoved(e.id,false));assert(#reportFor(pool.id).facts==1)
        ''')

    def test_hover_rejects_ui_units_secrets_and_handles_localized_requirements(self):
        self.lua.execute('''
            hoverPool('Synthetic School',nil,2);hoverPool('Synthetic School',nil,0)
            hoverPool('Fishing Bobber');hoverPool('Peacebloom','Requires Herbalism')
            assert(#j:List('pools')==0)
            cursorInfo={getterName='GetBagItem'};cursorData={type=4,lines={{leftText='Synthetic School'}}}
            t:ObserveWorldCursor();assert(#j:List('pools')==0)
            hoverPool(secret,'Fishing');assert(#j:List('pools')==0)
            function GetLocale() return 'deDE' end
            C_Spell.GetSpellName=function() return 'Angeln' end
            LOCKED_WITH_SPELL_KNOWN='Benötigt %s (%d)'
            hoverPool('Fischschwarm','Benötigt Angeln (25)');assert(#j:List('pools')==1)
            hoverPool('English Pool');assert(#j:List('pools')==1)
        ''')

    def test_deleted_pool_is_rediscovered_without_losing_history(self):
        self.lua.execute('''
            hoverPool('Synthetic School');local pool=j:List('pools')[1]
            assert(t:Assign('pool',pool.id));catch('before-remove')
            local history=snapshot(saved.history);local totals=snapshot(saved.aggregates)
            assert(j:SetPoolRemoved(pool.id,true));assert(not t:Assignment())
            assert(#j:List('pools')==0 and #j:List('pools',{status='removed'})==1)
            local reloaded=ns.CreateAnglingJournal(saved);assert(#reloaded:List('pools')==0)
            assert(reloaded:ObservePool({name='Synthetic School'},A.CurrentLocation()))
            assert(not pool.removed and #j:List('pools')==1)
            now=now+10;hoverPool('Synthetic School');mapID=102;hoverPool('Synthetic School')
            assert(A.Count(saved.spots)==2 and #j:List('pools')==1)
            assert(history==snapshot(saved.history) and totals==snapshot(saved.aggregates))
            reloaded=ns.CreateAnglingJournal(saved);assert(#reloaded:List('pools')==1)
            assert(j:Summary(pool).events==1)
        ''')

    def test_deleted_water_and_catch_types_return_on_new_catch(self):
        self.lua.execute('''
            local fact=observe('first');local water=j:Get(fact.waterID);local fish=j:List('catches')[1]
            assert(j:SetEntryRemoved(water.id,true));assert(j:SetEntryRemoved(fish.id,true))
            assert(#j:List('waters')==0 and #j:List('catches')==0)
            observe('second')
            assert(not water.removed and not fish.removed)
            assert(#j:List('waters')==1 and #j:List('catches')==1 and total()==2)
            assert(j:Summary(fish).items[fish.id].quantity==6)
            assert(#saved.history==2 and j:Summary(fish).events==2)
            assert(j:SetEntryRemoved(fish.id,true));j=ns.CreateAnglingJournal(saved)
            observe('third');assert(not j:Get(fish.id).removed and total()==3)
        ''')

    def test_capture_hidden_autoloot_duplicates_and_non_fish_items(self):
        self.lua.execute('''
            assert(c.main==nil and t.frame.scripts.OnUpdate==nil)
            begin('cast-a');loot={{itemID=1001,name='Fish',quantity=3},{itemID=2001,name='Old boot',quantity=2}}
            t:OnEvent('LOOT_READY',true);t:OnEvent('LOOT_READY',true);t:OnEvent('LOOT_OPENED',true,false)
            assert(total()==0,'visible loot is not acquired loot')
            t:OnEvent('LOOT_SLOT_CLEARED',1);t:OnEvent('LOOT_SLOT_CLEARED',1)
            t:OnEvent('LOOT_SLOT_CLEARED',2);t:OnEvent('LOOT_CLOSED')
            assert(total()==1 and #j:List('catches')==2 and #saved.history==1)
            local f=j:Facts(j:List('catches')[1])[1].fact
            assert(f.source=='unclassified' and not f.poolID and f.lowestSkill.effective==205)
            t:OnEvent('LOOT_OPENED',false,false);t:OnEvent('LOOT_SLOT_CLEARED',1);assert(total()==1)
        ''')

    def test_unrelated_loot_bags_trade_mail_purchases_and_container_contents_are_excluded(self):
        self.lua.execute('''
            catch('container',{{itemID=3001,name='Sealed crate',quantity=1}});assert(total()==1)
            loot={{itemID=3002,name='Crate contents',quantity=2}}
            t:OnEvent('LOOT_OPENED',false,true);t:OnEvent('LOOT_SLOT_CLEARED',1)
            for _,event in ipairs({'BAG_UPDATE','CHAT_MSG_LOOT','ITEM_PUSH','TRADE_CLOSED','MAIL_CLOSED'}) do t:OnEvent(event,'anything') end
            fishing=false;catch('unrelated');assert(total()==1 and #j:List('catches')==1)
            assert(j:List('catches')[1].name=='Sealed crate')
            begin('other',999);fishing=false;t:OnEvent('LOOT_READY',false);t:OnEvent('LOOT_SLOT_CLEARED',1);assert(total()==1)
        ''')

    def test_full_bags_retry_multiple_slots_and_quantity_counting(self):
        self.lua.execute('''
            begin('full');loot={{itemID=1001,name='Fish',quantity=2},{itemID=1001,name='Fish',quantity=3}}
            t:OnEvent('LOOT_READY',true);t:OnEvent('LOOT_CLOSED');assert(total()==0)
            t:OnEvent('LOOT_OPENED',false,false);t:OnEvent('LOOT_SLOT_CLEARED',1);t:OnEvent('LOOT_CLOSED')
            t:OnEvent('LOOT_OPENED',false,false);t:OnEvent('LOOT_SLOT_CLEARED',1);t:OnEvent('LOOT_SLOT_CLEARED',2)
            local fish=j:List('catches')[1];local s=j:Summary(fish)
            assert(s.events==1 and s.items[fish.id].quantity==5 and s.items[fish.id].occurrences==1)
        ''')

    def test_interruption_timeout_reload_and_unreadable_signals(self):
        self.lua.execute('''
            begin('interrupted');t:OnEvent('UNIT_SPELLCAST_INTERRUPTED','player','interrupted',7620)
            fishing=false -- An interruption alone is not a catch; no fishing loot was produced.
            loot={{itemID=1001,name='Fish',quantity=1}};t:OnEvent('LOOT_READY',false);t:OnEvent('LOOT_SLOT_CLEARED',1);assert(total()==0)
            begin('stale');elapsed=100;t:OnEvent('LOOT_READY',false);t:OnEvent('LOOT_SLOT_CLEARED',1);assert(total()==0)
            begin('reload');t:OnEvent('LOOT_READY',false);t=ns.CreateAnglingTracking(j);t:OnEvent('LOOT_SLOT_CLEARED',1);assert(total()==0)
            IsFishingLoot=function() return secret end;catch('secret');assert(total()==0)
            assert(not A.ReadFishingSkill().equipment and not A.ReadFishingSkill().lure)
            C_SkillInfo.GetSkillLineInfoByID=function() return secret end;assert(next(A.ReadFishingSkill())==nil)
        ''')

    def test_escaped_fish_discards_pending_loot_without_changing_counts_or_source(self):
        self.lua.execute('''
            ERR_FISH_ESCAPED='Your fish got away!'
            assert(t:Assign('open'));catch('first')
            local history=snapshot(saved.history);local facts=snapshot(saved.aggregates)
            begin('escape');fishing=false;loot={{itemID=2001,name='Pending fish',quantity=1}}
            fire('LOOT_READY',true);fire('LOOT_SLOT_CLEARED',1)
            fire('UI_ERROR_MESSAGE',123,ERR_FISH_ESCAPED)
            assert(t.status:find('Fish got away',1,true) and t:Assignment().source=='open')
            fishing=true;fire('LOOT_OPENED',false,false);fire('LOOT_SLOT_CHANGED',1);fire('LOOT_SLOT_CLEARED',1)
            fire('LOOT_CLOSED')
            assert(snapshot(saved.history)==history and snapshot(saved.aggregates)==facts)
            assert(total()==1 and j.session.events==1 and #j:List('catches')==1)
            catch('next');assert(total()==2 and j.session.events==2)
        ''')

    def test_localized_failure_and_error_ids_work_without_cast_guid(self):
        self.lua.execute('''
            ERR_FISH_NOT_HOOKED='Kein Fisch am Haken.'
            fire('UI_ERROR_MESSAGE',999,ERR_FISH_NOT_HOOKED)
            assert(total()==0 and #saved.history==0 and t.status:find('No fish was hooked',1,true))
            fishing=true;loot={{itemID=1001,name='Fish',quantity=2}}
            fire('LOOT_OPENED',true,false);fire('LOOT_SLOT_CLEARED',1);assert(total()==0)
            fire('LOOT_READY',true);fire('LOOT_SLOT_CLEARED',1);fire('LOOT_CLOSED');assert(total()==1)
            function GetGameMessageInfo(id) return id==123 and 'ERR_FISH_ESCAPED' or 'ERR_INV_FULL' end
            fire('UI_INFO_MESSAGE',123,secret);assert(t.status:find('Fish got away',1,true))
            loot={};fire('LOOT_READY',true);fire('LOOT_OPENED',true,false);assert(total()==1)
            loot={{itemID=1001,name='Fish',quantity=1}}
            fire('LOOT_READY',true);fire('LOOT_SLOT_CLEARED',1);assert(total()==2)
        ''')

    def test_unrelated_or_unreadable_errors_preserve_full_bag_retry(self):
        self.lua.execute('''
            ERR_FISH_ESCAPED='Your fish got away!';ERR_FISH_NOT_HOOKED='No fish are hooked.'
            begin('bags');loot={{itemID=1001,name='Fish',quantity=2}}
            fire('LOOT_READY',true)
            for _,message in ipairs({'Inventory is full.',secret,'Quest text: Your fish got away!'}) do
                fire('UI_ERROR_MESSAGE',secret,message)
            end
            fire('LOOT_CLOSED');assert(total()==0)
            fire('LOOT_OPENED',false,false);fire('LOOT_SLOT_CLEARED',1);assert(total()==1)
        ''')

    def test_confirmed_fishing_loot_without_cast_identity_and_consecutive_catches(self):
        self.lua.execute('''
            loot={{itemID=1001,name='Oily Blackmouth',quantity=1}}
            fire('LOOT_READY',true);fire('LOOT_OPENED',true,false)
            fire('LOOT_SLOT_CLEARED',1);fire('LOOT_SLOT_CLEARED',1);fire('LOOT_CLOSED')
            assert(total()==1)
            local item=j:List('catches')[1];local f=j:Facts(item)[1].fact
            assert(f.source=='unclassified' and not f.lowestSkill and f.method=='observed')
            fire('LOOT_OPENED',false,false);fire('LOOT_SLOT_CLEARED',1);fire('LOOT_CLOSED')
            assert(total()==1,'Reopening collected loot does not duplicate it')
            elapsed=elapsed+5;fire('LOOT_READY',true);fire('LOOT_SLOT_CLEARED',1);fire('LOOT_CLOSED')
            assert(total()==2 and j:Summary(item).items[item.id].quantity==2)
            assert(t:Assign('open'));elapsed=elapsed+5
            fire('LOOT_READY',true);fire('LOOT_SLOT_CLEARED',1);fire('LOOT_CLOSED')
            assert(total()==3 and #j:Facts(item,'personal',{source='open'})==1)
        ''')

    def test_late_fishing_flag_and_secret_guid_preserve_autoloot_evidence(self):
        self.lua.execute('''
            begin(secret);loot={{itemID=1001,name='Fish',quantity=2}}
            fishing=false;fire('LOOT_READY',true);fire('LOOT_SLOT_CLEARED',1)
            assert(total()==0,'Slots alone do not establish fishing')
            fishing=true;loot={};fire('LOOT_OPENED',true,false)
            assert(total()==1 and j:Summary(j:List('catches')[1]).events==1)
            fire('LOOT_SLOT_CLEARED',1);assert(total()==1)
        ''')

    def test_no_guid_partial_retry_container_and_non_item_loot(self):
        self.lua.execute('''
            loot={{itemID=1001,name='Fish',quantity=2},{itemID=2001,name='Boot',quantity=1}}
            fire('LOOT_READY',true);fire('LOOT_SLOT_CLEARED',1);fire('LOOT_CLOSED')
            fire('LOOT_READY',false);fire('LOOT_SLOT_CLEARED',1);fire('LOOT_SLOT_CLEARED',2)
            assert(total()==1 and #j:List('catches')==2)
            fire('LOOT_CLOSED');fire('LOOT_OPENED',false,true);fire('LOOT_SLOT_CLEARED',1)
            assert(total()==1)
            fishing=false;fire('LOOT_READY',true);fire('LOOT_SLOT_CLEARED',1);assert(total()==1)
        ''')

    def test_reshuffled_retry_slots_do_not_attribute_the_wrong_item(self):
        self.lua.execute('''
            begin('reorder');loot={{itemID=1001,name='Fish',quantity=2},{itemID=2001,name='Boot',quantity=1}}
            t:OnEvent('LOOT_READY',true);t:OnEvent('LOOT_CLOSED')
            loot={loot[2],loot[1]};t:OnEvent('LOOT_OPENED',false,false)
            t:OnEvent('LOOT_SLOT_CLEARED',1);t:OnEvent('LOOT_SLOT_CLEARED',2)
            assert(total()==0 and t.status:find('Loot slots changed',1,true))
        ''')

    def test_missing_item_name_resolves_without_another_catch(self):
        self.lua.execute('''
            catch('uncached',{{itemID=1001,quantity=2}})
            local e=j:List('catches')[1];assert(e.name=='Item #1001')
            C_Item={GetItemNameByID=function() return 'Resolved fish' end}
            t:OnEvent('GET_ITEM_INFO_RECEIVED',1001,true)
            assert(e.name=='Resolved fish' and total()==1)
        ''')

    def test_manual_assignment_provenance_and_all_stale_context_guards(self):
        self.lua.execute('''
            local e=spot('School','Known school');assert(t:Assign('pool',e.id))
            assert(t:SessionText():find('player assigned',1,true))
            catch('assigned');local f=j:Facts(j:Get(e.poolID))[1].fact
            assert(f.method=='observed' and f.association=='assigned' and f.source=='pool')
            t:OnEvent('PLAYER_STARTED_MOVING');assert(not t:Assignment());catch('moved')
            assert(j:Summary(j:Get(e.poolID)).events==1)
            assert(t:Assign('open'));catch('open');assert(j:List('catches',{source='open'})[1])
            assert(t:Assign('pool',e.id));elapsed=elapsed+301;assert(not t:Assignment())
            assert(t:Assign('pool',e.id));mapID=102;assert(not t:Assignment())
            mapID=101;assert(t:Assign('pool',e.id));px=px+0.02;assert(not t:Assignment())
            assert(t:Assign('open'));begin('unrelated',999);assert(not t:Assignment())
            assert(t:Assign('open'));t:OnEvent('PLAYER_ENTERING_WORLD');assert(not t:Assignment())
        ''')

    def test_manual_fallback_records_explicit_assertion_without_current_skill(self):
        self.lua.execute('''
            IsFishingLoot=nil;assert(t:Assign('open'))
            local f=assert(t:ManualCatch({itemID=1001,name='Remembered fish',quantity=5}))
            assert(f.source=='open' and f.association=='assigned' and f.method=='recorded' and not f.lowestSkill)
            assert(total()==1 and next(f.lastSkill)==nil)
            local id=j:List('catches')[1].id;assert(f.items[id].quantity==5 and f.items[id].occurrences==1)
            local multi=assert(t:ManualCatch({{itemID=1001,quantity=2},{itemID=1001,quantity=1},{itemID=2001,name='Boot',quantity=1}}))
            assert(total()==2 and multi.items[id].quantity==8 and multi.items[id].occurrences==2)
            assert(A.Count(multi.items)==2)
        ''')

    def test_registered_background_events_and_bonus_changes_do_not_fabricate_skill(self):
        self.lua.execute('''
            assert(c.main==nil)
            fire('UNIT_SPELLCAST_CHANNEL_START','player','events',7620)
            loot={{itemID=1001,name='Fish',quantity=1}}
            C_SkillInfo.GetSkillLineInfoByID=function() return {skillID=356,rank=151,modifier=55,tempPoints=0} end
            fire('LOOT_READY',true);fire('LOOT_SLOT_CLEARED',1);fire('LOOT_CLOSED')
            assert(total()==1 and not j:Facts(j:List('catches')[1])[1].fact.lowestSkill)
            C_SkillInfo.GetSkillLineInfoByID=function() return {skillID=356,rank=151,modifier=5,tempPoints=50} end
            assert(A.ReadFishingSkill().effective==nil and A.ReadFishingSkill().temporary==50)
            local before=snapshot(saved);assert(not t:ManualCatch({itemID=-1,name='Invalid',quantity=1}))
            assert(before==snapshot(saved))
        ''')

    def test_remembered_unclassified_spot_assignment_does_not_claim_open_water(self):
        self.lua.execute('''
            local e=spot('Uncertain source');assert(t:Assign('unclassified',e.id));catch('unknown-source')
            local f=j:Facts(e)[1].fact
            assert(f.spotID==e.id and f.source=='unclassified' and f.association=='unknown' and not f.poolID)
            assert(j.session.newItems==1);t:ClearSource();catch('same-item-next-session');assert(j.session.newItems==0)
        ''')

    def test_merging_an_assigned_spot_expires_assignment_and_preserves_pending_quantities(self):
        self.lua.execute('''
            local a=spot('First','School');local b=spot('Second','School');assert(t:Assign('pool',a.id))
            begin('merge-retry');loot={{itemID=1001,name='Fish',quantity=2},{itemID=2001,name='Boot',quantity=1}}
            fire('LOOT_READY',false);fire('LOOT_SLOT_CLEARED',1)
            assert(j:MergeSpots(a.id,b.id));assert(not t:Assignment());assert(t:SessionText())
            fire('LOOT_SLOT_CLEARED',2)
            assert(total()==1 and j:Summary(b).events==1 and A.Count(j:Summary(b).items)==2)
        ''')

    def test_clearing_assignment_before_loot_preserves_fishing_proof(self):
        self.lua.execute('''
            local e=spot('Pool','School');assert(t:Assign('pool',e.id));begin('clear-before-loot');t:ClearSource()
            loot={{itemID=1001,name='Fish',quantity=2}};fire('LOOT_READY',false);fire('LOOT_SLOT_CLEARED',1)
            assert(total()==1 and j:Summary(j:Get(e.poolID)).events==0)
            assert(j:Facts(j:List('catches')[1])[1].fact.source=='unclassified')
        ''')


class AnglingReportTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_angling()
        self.lua.execute("e=spot('My pool','School');observe('one','pool',e.poolID,e.id);r=reportFor(e.id)")

    def test_roundtrip_preview_and_notes_opt_in(self):
        self.lua.execute('''
            local wire=assert(R.Encode(r));local decoded=assert(R.Decode(wire))
            assert(wire==R.Encode(decoded));assert(not wire:find('Bring a lantern',1,true))
            local included=reportFor(e.id,'personal',true)
            assert(R.Preview(included):find('Bring a lantern',1,true))
            assert(R.Preview(included):find('not authenticated',1,true))
            assert(not R.Build(j,'missing','personal',true))
            local ticket=assert(R.Prepare(wire));assert(ticket.preview==R.Preview(r))
        ''')

    def test_accept_requires_preview_is_atomic_idempotent_and_separate(self):
        self.lua.execute('''
            local recipient=ns.CreateAnglingJournal({});assert(not R.Accept(recipient,r))
            local ok,added=import(recipient,r);assert(ok and added==1)
            assert(A.Count(recipient.db.aggregates)==0 and #recipient.db.history==0 and #recipient.db.sessions==0)
            assert(not recipient.session and A.Count(recipient.db.reported)==1)
            local fish=recipient:List('catches',{knowledge='reported'})[1]
            assert(fish and #recipient:List('catches',{knowledge='personal'})==0)
            local summary=recipient:Summary(fish);assert(summary.events==0 and summary.reportedEvents==1)
            ok,added=import(recipient,r);assert(ok and added==0 and A.Count(recipient.db.reported)==1)
            local altered=A.Copy(r);altered.facts[1].source='open';altered.facts[1].poolID=nil;altered.facts[1].spotID=nil
            local before=snapshot(recipient.db);assert(not import(recipient,altered));assert(snapshot(recipient.db)==before)
            assert(recipient.db.points==nil and recipient.db.rewards==nil)
        ''')

    def test_cumulative_report_updates_and_duplicate_import_after_reload(self):
        self.lua.execute('''
            local recipient=ns.CreateAnglingJournal({});assert(import(recipient,r))
            local before=snapshot(recipient.db);now=now+10
            local ok,added,updated=import(recipient,r);assert(ok and added==0 and updated==0)
            assert(before==snapshot(recipient.db),'re-import is content-idempotent, including timestamps')
            observe('two','pool',e.poolID,e.id);local newer=reportFor(e.id)
            ok,added,updated=import(recipient,newer);assert(ok and added==0 and updated==1)
            local pool=recipient:List('pools')[1];assert(recipient:Summary(pool).reportedEvents==2)
            recipient=ns.CreateAnglingJournal(recipient.db)
            ok,added,updated=import(recipient,newer);assert(ok and added==0 and updated==0)
            assert(recipient:Summary(pool).events==0 and #recipient.db.sessions==0)
        ''')

    def test_forwarded_claim_is_not_rewritten_by_local_name_resolution(self):
        self.lua.execute('''
            local recipient=ns.CreateAnglingJournal({});assert(import(recipient,r))
            local fish=recipient:List('catches')[1];local original=fish.name
            fish.name='Different locally resolved name';fish.note='Private note'
            playerName='Another Angler'
            local forwarded=assert(R.Build(recipient,fish.id,'reported',false))
            for _,record in ipairs(forwarded.records) do
                if record.kind=='item' then assert(record.name==original and record.notes==nil) end
            end
            local receiver=ns.CreateAnglingJournal({});assert(import(receiver,r))
            local ok,added=import(receiver,forwarded);assert(ok and added==0)
        ''')

    def test_report_capacity_and_mutated_tickets_do_not_bypass_validation(self):
        self.lua.execute('''
            local recipient=ns.CreateAnglingJournal({});local before=snapshot(recipient.db)
            local ticket=assert(R.Prepare(R.Encode(r)));ticket.preview='tampered display';ticket.report={}
            R.MAX_STORED_FACTS=0;assert(not R.Accept(recipient,ticket));assert(before==snapshot(recipient.db))
            R.MAX_STORED_FACTS=4096;R.Cancel(ticket);assert(not R.Accept(recipient,ticket))
            ticket=assert(R.Prepare(R.Encode(r)));assert(R.Accept(recipient,ticket));assert(not R.Accept(recipient,ticket))
        ''')

    def test_forwarding_preserves_original_provenance_and_deduplicates(self):
        self.lua.execute('''
            local recipient=ns.CreateAnglingJournal({});assert(import(recipient,r))
            playerName='Second Angler'
            local fish=recipient:List('catches')[1];local forwarded=assert(R.Build(recipient,fish.id,'reported',true))
            assert(forwarded.sender=='Second Angler' and forwarded.facts[1].origin.source=='Alice Sunstrider')
            local third=ns.CreateAnglingJournal({});assert(import(third,r));local ok,added=import(third,forwarded)
            assert(ok and added==0 and A.Count(third.db.reported)==1)
            local f=next(third.db.reported);assert(third.db.reported[f].origin.source=='Alice Sunstrider')
        ''')

    def test_personal_corroboration_does_not_verify_unrelated_claims_or_replace_notes(self):
        self.lua.execute('''
            assert(j:Edit(e.id,e.name,'Private local note',true));assert(import(j,r))
            assert(j:Get(e.id).note=='Private local note' and total()==1)
            local pool=j:Get(e.poolID);assert(pool.personal and #pool.claims>0)
            assert(A.Count(saved.reported)==1 and j:Summary(pool).events==1 and j:Summary(pool).reportedEvents==1)
            local fish=j:List('catches')[1];assert(#j:List('catches')==1)
            assert(fish.personal and #fish.claims>0)
            observe('own-unclassified');assert(j:Summary(pool).events==1 and j:Summary(pool).reportedEvents==1)
        ''')

    def test_validation_types_limits_coordinates_references_counts_and_markup(self):
        self.lua.execute('''
            local function reject(change) local v=A.Copy(r);change(v);assert(not R.Normalize(v)) end
            reject(function(v) v.version=99 end)
            reject(function(v) v.addonVersion='wrong' end)
            reject(function(v) v.sender='|Hitem:1|h[bad]|h' end)
            reject(function(v) v.sender='False header'..string.char(10)..'another line' end)
            reject(function(v) v.sender=string.rep('x',161) end)
            reject(function(v) v.records[1].notes='|Ttexture:1000|t' end)
            reject(function(v) v.facts[1].waterID='r999' end)
            reject(function(v) v.facts[1].source='open' end)
            reject(function(v) v.facts[1].events=0/0 end)
            reject(function(v) v.facts[1].items[1].occurrences=2 end)
            reject(function(v) v.facts[1].lowestSkill.effective=-1 end)
            reject(function(v) v.facts[1].origin.method='recorded' end)
            reject(function(v) for _,s in ipairs(v.records) do if s.kind=='spot' then s.x=10001 end end end)
            reject(function(v) v.records[2]=nil end)
            reject(function(v) v.facts[2]=A.Copy(v.facts[1]);v.facts[2].id='f2' end)
            reject(function(v) v.extra='no' end)
            local wire=R.Encode(r)
            assert(not R.Decode(wire..'x') and not R.Decode(wire:sub(1,-2)))
            assert(not R.Decode('return os.execute("anything")'))
            assert(not R.Decode('AFBF1:t1:s1:xt1:s1:xt999999:'))
            assert(not R.Decode(string.rep('x',R.MAX_BYTES+1)))
            assert(not R.Normalize(setmetatable(A.Copy(r),{})))
        ''')


class AnglingUITests(unittest.TestCase):
    def setUp(self):
        self.lua = new_angling(ui=True)
        self.lua.execute('''
        MenuResponse={Refresh=2}
        function openMenu(button)
            local function node()
                local n={children={}}
                function n:CreateButton(label,fn) local child=node();child.label=label;child.action=fn;self.children[#self.children+1]=child;return child end
                function n:CreateCheckbox(label,selected,fn) local child=self:CreateButton(label,fn);child.selected=selected;return child end
                function n:SetResponse(response) self.response=response end
                function n:CreateDivider() end
                function n:CreateTitle(label) self.title=label end
                function n:SetScrollMode() end
                return n
            end
            MenuUtil={CreateContextMenu=function(_,build) menu=node();build(nil,menu) end}
            click(button);return menu
        end
        function choose(menu,label)
            for _,item in ipairs(menu.children) do if item.label==label then if item.action then item.action() end;return item end end
            error('Menu missing '..label)
        end
    ''')

    def test_information_overlay_animates_reverses_and_preserves_actions(self):
        self.lua.execute("""
            assert(m.locations.point[3]==0 and m.heading.point[3]==-33)
            assert(m.notesOverlay.point[3]==-588 and m.details:GetHeight()==61)
            c:Expand();m.notesOverlay.scripts.OnUpdate(m.notesOverlay,.09)
            assert(m.notesOverlay.point[3]>-588 and m.notesOverlay.point[3]<-174)
            c:Expand();m.notesOverlay.scripts.OnUpdate(m.notesOverlay,.18)
            assert(m.notesOverlay.point[3]==-588 and m.notesPaper:IsShown())
            c:Expand();m.notesOverlay.scripts.OnUpdate(m.notesOverlay,.18)
            assert(m.notesOverlay.point[3]==-174 and m.details:GetHeight()==475)
            c:SetView('pools');c:SetView('catches');c:SetView('waters')
            assert(m.notesExpanded and m.notesOverlay.point[3]==-174)
            assert(m.detailBody:GetHeight()>=m.details:GetHeight())
            c:Expand();m.notesOverlay.scripts.OnUpdate(m.notesOverlay,.18)
            assert(m.notesOverlay.point[3]==-588 and m.details:GetHeight()==61)
            assert(m.notesOverlay.scripts.OnUpdate==nil and m.notesPaper:IsShown())
        """)

    def test_scrolling_index_and_context_actions(self):
        self.lua.execute("""
            for i=1,40 do spot(string.format('Spot %02d',i)) end
            local rows=j:List('waters',c:Filters())
            assert(not m.previous and not m.next and #m.rows==11)
            assert(m.merge:IsShown() and not m.restore:IsShown())
            m.list.scripts.OnMouseWheel(m.list,-4)
            -- The widget harness does not dispatch native scroll events.
            m.list.scripts.OnVerticalScroll(m.list,m.list:GetVerticalScroll())
            assert(c:State().indexScroll==152 and m.rows[1].id==rows[5].id)
            local before=c:State().indexScroll
            c:SetView('pools');assert(not m.merge:IsShown())
            c:SetView('catches');assert(not m.merge:IsShown())
            c:SetView('waters');assert(c:State().indexScroll==before)
            c:Select(rows[#rows].id)
            assert(m.list:GetVerticalScroll()==#rows*38-380)
            local visible=false
            for _,row in ipairs(m.rows) do if row.id==rows[#rows].id then visible=true end end
            assert(visible)
            c:Select(rows[1].id);assert(m.merge.enabled)
            m.search:SetText('Spot 01')
            assert(c:State().indexScroll==0 and m.rows[1].id)
            m.search:SetText('No matching record')
            assert(m.empty:IsShown() and not m.rows[1]:IsShown())
        """)

    def test_event_log_page_navigation_live_updates_and_clear(self):
        self.lua.execute('''
            local p=c.eventLog
            assert(shell:GetFrame().eventLogButton.enabled and not p:IsShown())
            for i=1,51 do j:Log('Test','Event '..i) end
            shell:TogglePage('eventLog');p:Refresh()
            assert(p:IsShown() and p.text:GetText():find('Event 51',1,true) and p.older.enabled)
            click(p.older);assert(p.index==1 and p.text:GetText():find('Event 1',1,true) and not p.older.enabled)
            click(p.newer);j:Log('Test','Live event');assert(p.text:GetText():find('Live event',1,true))
            local e=spot();catch('log-ui');assert(t:Assign('open'))
            local facts=snapshot(saved.aggregates);local history=snapshot(saved.history)
            click(p.clear);assert(#saved.eventLog>0 and p.confirmClear)
            click(p.clear);assert(#saved.eventLog==0 and not p.confirmClear)
            assert(snapshot(saved.aggregates)==facts and snapshot(saved.history)==history)
            assert(j:Get(e.id).note=='Bring a lantern' and t:Assignment().source=='open')
            shell:ShowSection('other');assert(not p:IsShown())
            shell:ShowSection('angling');shell:TogglePage('help')
        ''')

    def test_catches_newest_first_and_description_does_not_repeat_title(self):
        self.lua.execute('''
            observe('old',nil,nil,nil,nil,{{itemID=1001,name='Alpha fish',quantity=1}})
            now=now+10;observe('new',nil,nil,nil,nil,{{itemID=2001,name='Zebra fish',quantity=2}})
            c:SetView('catches');assert(m.rows[1].id==saved.itemKeys['item:2001'])
            local e=j:Get(m.rows[1].id);c:Select(e.id)
            assert(c:Details(e)[1]~=e.name)
            assert(not c:Details(e)[2]:find(e.name,1,true))
            now=now+10;observe('again',nil,nil,nil,nil,{{itemID=1001,name='Alpha fish',quantity=1}})
            assert(m.rows[1].id==saved.itemKeys['item:1001'])
        ''')

    def test_large_event_log_pagination_reuses_widgets(self):
        self.lua.execute('''
            local p=c.eventLog;local count=#objects
            for i=1,5000 do j:Log('Test','Event '..i) end
            shell:TogglePage('eventLog');p:Refresh()
            for i=1,99 do click(p.older) end
            assert(p.index==99 and not p.older.enabled and #objects==count)
            assert(p.text:GetText():find('Event 1',1,true))
            local _,rows=p.text:GetText():gsub('Event ','')
            assert(rows==50,'only the visible page is rendered')
            click(p.clear);click(p.clear)
            assert(p.index==0 and not p.older.enabled and not p.newer.enabled)
        ''')

    def test_sighting_remove_restore_action_is_available_in_waters(self):
        self.lua.execute('''
            local e=spot('Incorrect sighting','School');c:Select(e.id)
            assert(m.deleteButton:IsShown() and m.deleteButton:GetText()=='Delete')
            click(m.deleteButton);assert(not e.removed);click(m.deleteForm.confirm);assert(e.removed and not m.deleteButton.enabled)
            choose(choose(openMenu(m.filters),'Show'),'Removed')
            assert(c:State().status=='removed' and m.rows[1].id==e.id)
            m.rows[1].scripts.OnClick(m.rows[1]);assert(m.restore:IsShown())
            click(m.restore);assert(not e.removed)
            c:SetView('pools');assert(#j:List('pools')==1)
        ''')

    def test_control_right_click_removes_spots_and_transient_positions(self):
        self.lua.execute('''
            local e=spot('Remembered pier');c:Select(e.id)
            local pin=m.map.pins[1]
            ns.IsMapClickNavigationEnabled=function() return false end
            IsControlKeyDown=function() return false end
            pin.scripts.OnClick(pin,'RightButton');assert(not e.removed)
            IsControlKeyDown=function() return true end
            pin.scripts.OnEnter(pin)
            local text='';for _,line in ipairs(GameTooltip.lines) do text=text..line.text end
            assert(text:find('Ctrl+Right Click',1,true))
            pin.scripts.OnClick(pin,'RightButton');assert(e.removed and not pin:IsShown())
            assert(j:SetSightingRemoved(e.id,false));c:Select(e.id)
            assert(m.deleteButton:GetText()=='Delete')
            click(m.deleteButton);assert(not e.removed);click(m.deleteForm.confirm);assert(e.removed)
            local fact=observe('position');local water=j:Get(fact.waterID);c:Select(water.id)
            pin=m.map.pins[1];assert(pin:IsShown() and pin.group[1].point.transient)
            local before=snapshot(saved.aggregates)
            pin.scripts.OnClick(pin,'RightButton')
            assert(water.mapPositionHidden and not pin:IsShown() and before==snapshot(saved.aggregates))
            local loaded=ns.CreateAnglingJournal(saved);assert(loaded:Get(water.id).mapPositionHidden)
            now=now+1;observe('new-position');assert(not water.mapPositionHidden and total()==2)
        ''')

    def test_map_navigation_changes_only_displayed_zone(self):
        self.lua.execute('''
            local e=spot('Pier');c:Select(e.id);assert(t:Assign('open'))
            local getInfo=C_Map.GetMapInfo
            C_Map.GetMapInfo=function(id)
                local info=getInfo(id);info.parentMapID=id==101 and 100 or 0;return info
            end
            IsControlKeyDown=function() return false end
            m.map.pins[1].scripts.OnClick(m.map.pins[1],'RightButton')
            assert(c:State().mapID==100 and not e.removed and t:Assignment().source=='open')
            local w,h=m.map:GetWidth(),m.map:GetHeight();m.map.left,m.map.top=0,h
            GetCursorPosition=function() return w/2,h/2 end
            C_Map.GetMapInfoAtPosition=function() return {mapID=101,name='Coast'} end
            m.map.scripts.OnMouseUp(m.map,'LeftButton')
            assert(c:State().mapID==101 and c:State().mapZone=='Coast' and total()==0)
        ''')

    def test_drag_from_almanac_pin_does_not_select_or_remove_it(self):
        self.lua.execute('''
            local e=spot('Pier');c:Select(e.id)
            local map=m.map;local w,h=map:GetWidth(),map:GetHeight();map.left,map.top=0,h
            local x,y=w/2,h/2;GetCursorPosition=function() return x,y end
            map:ZoomBy(2);local pin=map.pins[1];local before=map.panX
            pin.scripts.OnMouseDown(pin,'LeftButton');x=x-15;map:UpdatePan()
            pin.scripts.OnClick(pin,'LeftButton')
            assert(map.panX==before+15 and not e.removed and c:State().selected==e.id)
        ''')

    def test_shared_zone_menu_groups_and_almanac_selection(self):
        self.lua.execute('''
            local data={
                [947]={name='Azeroth',mapType=1,parentMapID=0},
                [1415]={name='Eastern Kingdoms',mapType=2,parentMapID=947},
                [1414]={name='Kalimdor',mapType=2,parentMapID=947},
                [101]={name='Coast',mapType=3,parentMapID=1414},
                [102]={name='Loch Modan',mapType=3,parentMapID=1415},
                [1460]={name='Warsong Gulch',mapType=3,parentMapID=1414},
                [900]={name='Zephras Isle',mapType=2,parentMapID=947},
                [901]={name='Island interior',mapType=3,parentMapID=900}}
            C_Map.GetMapInfo=function(id) local d=data[id];if d then d.mapID=id end;return d end
            C_Map.GetMapChildrenInfo=function() local rows={};for id,d in pairs(data) do d.mapID=id;rows[#rows+1]=d end;return rows end
            local groups=ns.Atlas.MapMenuGroups({101});local byName={};local seen={}
            for _,g in ipairs(groups) do
                byName[g.name]=g
                for _,r in ipairs(g.rows) do assert(not seen[r.mapID]);seen[r.mapID]=g.name end
            end
            assert(seen[102]=='Eastern Kingdoms' and seen[101]=='Kalimdor')
            assert(seen[1460]=='Battlegrounds' and seen[900]=='Other' and seen[901]=='Other')
            assert(byName['Eastern Kingdoms'].base.mapID==1415)
            local function description(text,action)
                local d={text=text,action=action,children={}}
                function d:SetScrollMode(height) self.scroll=height end
                function d:CreateButton(text,action) local child=description(text,action);self.children[#self.children+1]=child;return child end
                function d:CreateDivider() end
                function d:CreateTitle(text) self.title=text end
                return d
            end
            local root
            MenuUtil={CreateContextMenu=function(owner,generate)
                assert(owner==m.zone);root=description();generate(owner,root)
            end}
            local before=snapshot(saved.aggregates);local frames=#objects
            for i=1,20 do click(m.zone) end
            assert(#objects==frames and root.scroll==420)
            for _,g in ipairs(root.children) do if g.text=='Eastern Kingdoms' then
                assert(g.scroll==420)
                for _,zone in ipairs(g.children) do if zone.text=='Loch Modan' then zone.action() end end
            end end
            assert(c:State().mapID==102 and m.zone:GetText()=='Loch Modan')
            assert(snapshot(saved.aggregates)==before and A.Count(saved.pools)==0)
        ''')

    def test_catch_icons_and_native_tooltips_in_both_lists(self):
        self.lua.execute('''
            catch('icon');local item=j:List('catches')[1]
            C_Item={GetItemIconByID=function(id) assert(id==1001);return 98765 end}
            function GameTooltip:SetItemByID(id) self.itemID=id;self:SetText('Native item tooltip') end
            c:Select(item.id);assert(m.rows[1].icon.texture==98765)
            m.rows[1].scripts.OnEnter(m.rows[1]);assert(GameTooltip.itemID==1001 and GameTooltip:IsShown())
            m.rows[1].scripts.OnLeave(m.rows[1]);assert(not GameTooltip:IsShown())
            c:Select(j:List('waters')[1].id);c:OpenLinks('items')
            local p=c.panels.links;local row=p.rows[1]
            assert(row.icon:IsShown() and row.icon.texture==98765 and row.itemName:GetText()==item.name)
            row.scripts.OnEnter(row);assert(GameTooltip.itemID==1001 and GameTooltip:IsOwned(row))
            row.scripts.OnLeave(row);assert(not GameTooltip:IsShown())
            c:OpenLinks('locations');assert(not p.rows[1].icon:IsShown() and not p.rows[1].itemName:IsShown())
        ''')

    def test_uncached_and_name_only_catches_use_safe_tooltip_fallbacks(self):
        self.lua.execute('''
            catch('uncached');local item=j:List('catches')[1]
            local requested
            C_Item={IsItemDataCachedByID=function() return false end,
                RequestLoadItemDataByID=function(id) requested=id end}
            c:Select(item.id);m.rows[1].scripts.OnEnter(m.rows[1])
            assert(requested==1001 and GameTooltip:GetText()==item.name)
            c:Select(j:List('waters')[1].id);c:OpenLinks('items')
            C_Item.GetItemIconByID=function() return 9988 end
            C_Item.GetItemNameByID=function() return 'Loaded fish' end
            fire('GET_ITEM_INFO_RECEIVED',1001,true)
            assert(c.panels.links.rows[1].icon.texture==9988)
            assert(c.panels.links.rows[1].itemName:GetText()=='Loaded fish')
            assert(t:ManualCatch({name='Unidentified remembered fish',quantity=1}))
            local manual=j:List('catches',{query='Unidentified'})[1];c:Select(manual.id)
            for _,row in ipairs(m.rows) do if row.id==manual.id then
                assert(row.icon.texture=='Interface\\\\Icons\\\\INV_Misc_QuestionMark')
                row.scripts.OnEnter(row);assert(GameTooltip:GetText()==manual.name)
            end end
        ''')

    def test_pool_remove_restore_controls_keep_notes_and_hover_tooltip(self):
        self.lua.execute('''
            GameTooltip:Show();hoverPool('Synthetic School');assert(GameTooltip:IsShown())
            local pool=j:List('pools')[1];assert(j:Edit(pool.id,pool.name,'Keep this note',true))
            c:Select(pool.id);assert(m.deleteButton.enabled)
            click(m.deleteButton);assert(not pool.removed);click(m.deleteForm.confirm);assert(#j:List('pools')==0 and pool.note=='Keep this note')
            choose(choose(openMenu(m.filters),'Show'),'Removed')
            assert(c:State().status=='removed' and m.rows[1].id==pool.id)
            m.rows[1].scripts.OnClick(m.rows[1]);assert(m.restore:IsShown())
            m.restore.scripts.OnClick(m.restore);assert(#j:List('pools')==1 and pool.favourite and pool.note=='Keep this note')
        ''')

    def test_three_views_empty_states_stable_map_no_atlas_initialization(self):
        self.lua.execute('''
            assert(AzerothFieldbookAtlasDB==nil and m.map and #j:List('waters')==0)
            local w,h=m.map:GetWidth(),m.map:GetHeight();local point=m.map.point
            local root=shell:GetFrame();assert(root:GetWidth()==960 and root:GetHeight()==740)
            for _,view in ipairs({'waters','pools','catches','waters'}) do
                c:SetView(view);assert(m.empty:IsShown() and m.map:GetWidth()==w and m.map:GetHeight()==h)
                assert(m.map.point==point and root:GetWidth()==960 and root:GetHeight()==740)
            end
            C_Map.GetMapArtLayers=function() return nil end;m.map:Invalidate();c:Refresh()
            assert(not m.map.available and m.map:GetWidth()==578*.99 and m.map:GetHeight()==302*1.25*.99)
            assert(m.map.point==point)
        ''')

    def test_exact_atlas_geometry_aspect_fit_tiles_scales_and_isolated_selection(self):
        for module in ATLAS_MODULES:
            if module not in {'AtlasJournal.lua', 'AtlasUI.lua', 'AtlasMap.lua'}:
                self.lua.execute((ROOT/module).read_text(encoding='utf-8'),'AzerothFieldbook',self.lua.globals().ns)
        self.lua.execute('''
            local aj=ns.CreateAtlasJournal({});local refs=ns.CreateAtlasReferences(nil,function() return {} end,shell)
            local atlas=ns.CreateAtlasBook(aj,shell,refs);shell:ShowSection('atlas')
            local atlasMap=atlas.main.map;local before=snapshot(aj.saved)
            for _,map in ipairs({atlasMap,m.map}) do
                local point=map.playerCoordinates.point
                assert(point[1]=='BOTTOMLEFT' and point[2]==map and point[3]=='BOTTOMLEFT')
                assert(point[4]==8 and point[5]==29)
                assert(map.playerCoordinates.parent~=map.canvas,'Coordinates must not zoom with the artwork')
            end
            for _,shape in ipairs({{1000,668},{1400,500},{800,900}}) do
                C_Map.GetMapArtLayers=function() return {{layerWidth=shape[1],layerHeight=shape[2],tileWidth=256,tileHeight=256}} end
                C_Map.GetMapArtLayerTextures=function() local a={};for i=1,24 do a[i]=9000+i end;return a end
                for _,scale in ipairs({.65,1,1.25}) do
                    shell:GetFrame():SetScale(scale);atlasMap:Invalidate();m.map:Invalidate()
                    atlasMap:Render(101);m.map:Render(101)
                    assert(atlasMap:GetWidth()==m.map:GetWidth() and atlasMap:GetHeight()==m.map:GetHeight())
                    for _,i in ipairs({1,3,4,5}) do assert(atlasMap.point[i]==m.map.point[i]) end
                    assert(atlasMap:GetEffectiveScale()==m.map:GetEffectiveScale())
                end
            end
            shell:ShowSection('angling');c:SetView('pools');c:SetView('catches')
            assert(snapshot(aj.saved)==before)
            assert(shell:GetFrame():GetWidth()==960 and shell:GetFrame():GetHeight()==740)
        ''')

    def test_auto_water_selection_uses_one_transient_observed_position(self):
        self.lua.execute('''
            local f=observe('coast');local water=j:Get(f.waterID);c:Select(water.id)
            assert(A.Count(saved.spots)==0 and m.map.pins[1].group[1].point.transient)
            assert(m.map.pins[1].group[1].id==water.id)
            m.map.pins[1].scripts.OnEnter(m.map.pins[1])
            local text='';for _,line in ipairs(GameTooltip.lines) do text=text..line.text end
            assert(text:find('not a permanent remembered spot',1,true))
            c:SetView('catches');assert(not m.map.pins[1]:IsShown() and A.Count(saved.spots)==0)
        ''')

    def test_item_history_only_lists_events_containing_that_item(self):
        self.lua.execute('''
            observe('fish',nil,nil,nil,'observed',{{itemID=1001,name='Fish',quantity=2}})
            now=now+1;observe('boot',nil,nil,nil,'observed',{{itemID=2001,name='Boot',quantity=1}})
            local fish=j:Get(saved.itemKeys['item:1001']);local summary=j:Summary(fish)
            assert(summary.events==2 and A.Count(summary.items)==1 and summary.items[fish.id].occurrences==1)
            local text=table.concat(c:Details(fish),'\\n');local at=assert(text:find('Recent personal history',1,true))
            assert(text:sub(at):find('Fish',1,true) and not text:sub(at):find('Boot',1,true))
        ''')

    def test_reverse_lookup_highlights_the_selected_items_observed_position(self):
        self.lua.execute('''
            observe('fish',nil,nil,nil,'observed',{{itemID=1001,name='Fish',quantity=2}})
            now=now+1;px=0.8;observe('boot',nil,nil,nil,'observed',{{itemID=2001,name='Boot',quantity=1}})
            local fish=j:Get(saved.itemKeys['item:1001']);c:Select(fish.id);c:OpenLinks('locations');click(c.panels.links.rows[1])
            assert(c:State().focusItem==fish.id and m.map.pins[1].group[1].point.x==2500)
            assert(m.map.pins[1].group[1].point.itemName=='Fish' and A.Count(saved.spots)==0)
            assert(m.details.text:GetText():find('Selected source: Unclassified water — Fish',1,true))
            assert(R.Build(j,fish.id,'personal',false),'private last positions do not leak into report item fields')
        ''')

    def test_selection_pin_navigation_reverse_lookup_state_and_page_return(self):
        self.lua.execute('''
            local e=spot('Pier','School');observe('one','pool',e.poolID,e.id)
            c:Select(e.id);assert(c:State().selected==e.id and m.map.pins[1].group[1].id==e.id)
            assert(m.map.pins[1]:GetWidth()==24,'Adapters without Atlas state use the default selected icon size')
            m.map.pins[1].scripts.OnEnter(m.map.pins[1]);assert(GameTooltip:GetText()=='Remembered fishing locations')
            assert(GameTooltip.lines[1].text=='Pier')
            m.map.pins[1].scripts.OnClick(m.map.pins[1]);assert(c:State().selected==e.id)
            m.search:SetText('Pier');m.details:SetVerticalScroll(17)
            c:SetView('catches');local fish=j:List('catches')[1];c:Select(fish.id)
            c:OpenLinks('locations');local p=c.panels.links;assert(p.rows[1].data.id==e.id)
            click(p.rows[1]);assert(j.state.view=='waters' and c:State().selected==e.id)
            m.search:SetText('lantern');m.details:SetVerticalScroll(19)
            shell:ShowSection('other');catch('hidden');shell:ShowSection('angling')
            assert(m.search:GetText()=='lantern' and m.details:GetVerticalScroll()==19 and c:State().selected==e.id)
            assert(total()==2 and shell:GetFrame():GetWidth()==960)
            c:SetView('catches');assert(c:State().selected==fish.id)
        ''')

    def test_form_notes_manual_catch_sighting_and_report_acceptance_controls(self):
        self.lua.execute('''
            click(m.sighting);local p=c.panels.form;p.a:SetText('Pier');p.b:SetText('School');p.notes:SetText('Keep this note');click(p.save)
            local e=j:Get(c:State().selected);assert(e.kind=='spot' and e.poolID and e.note=='Keep this note')
            c:Select(e.poolID);assert(m.details.text:GetText():find('No catches recorded from this pool type.',1,true))
            click(m.assign);assert(t:Assignment().poolID==e.poolID)
            click(m.manual);p.a:SetText('1001');p.b:SetText('My fish');p.c:SetText('2');click(p.save);assert(total()==1)
            c:Select(e.id);click(m.notes);p.notes:SetText('Updated private note');click(p.save);assert(j:Get(e.id).note=='Updated private note')
            click(m.reports);local rp=c.panels.reports;click(rp.build)
            assert(rp.data:GetText():sub(1,6)=='AFBF1:' and not rp.accept.enabled)
            assert(not rp.data:GetText():find('Updated private note',1,true))
            click(rp.check);assert(rp.accept.enabled);rp.data:SetText(rp.data:GetText()..'x');assert(not rp.accept.enabled)
            click(rp.build);click(rp.check);click(rp.accept);assert(not rp.accept.enabled and total()==1)
        ''')

    def test_navigation_and_editors_reuse_frames(self):
        self.lua.execute('''
            local e=spot('Pier','School');c:Select(e.id)
            c:OpenForm('spot');c:OpenLinks('locations');c:OpenReports();c:ClosePanel()
            shell:ShowSection('other');shell:ShowSection('angling')
            local count=#objects
            for i=1,30 do
                c:SetView('waters');c:Select(e.id);c:OpenForm('edit',e.id);c:OpenLinks('locations');c:OpenReports();c:ClosePanel()
                shell:ShowSection('other');shell:ShowSection('angling')
            end
            assert(#objects==count,'native widgets must be reused')
        ''')

    def test_long_session_names_scroll_inside_fixed_header_region(self):
        self.lua.execute('''
            local e=spot(string.rep('Long spot ',16),string.rep('Long pool ',16));c:Select(e.id);click(m.assign)
            catch('long-name');c:Refresh()
            assert(m.session:GetHeight()==41 and m.session.text:GetStringHeight()>41)
            assert(m.session.point[2]==480 and m.session.point[3]==-125)
            assert(m.assign.point[3]==-91 and m.map.point[5]==-205)
            assert(m.current==nil)
        ''')

    def test_private_note_opt_in_is_scoped_to_the_selected_record(self):
        self.lua.execute('''
            local e=spot('Pier','School');c:Select(e.id);c:OpenReports()
            local p=c.panels.reports;p.notes:SetChecked(true);click(p.build)
            assert(p.data:GetText():find('Bring a lantern',1,true))
            local pool=j:Get(e.poolID);assert(j:Edit(pool.id,pool.name,'Private pool advice',false))
            c:Select(pool.id);c:OpenReports();assert(not p.notes:GetChecked());click(p.build)
            assert(not p.data:GetText():find('Private pool advice',1,true))
        ''')


if __name__ == '__main__':
    unittest.main()
