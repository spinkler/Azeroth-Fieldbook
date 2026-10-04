"""Treasure model, conservative attribution, report adapter and real UI builders."""
import unittest
from pathlib import Path
from treasure_test_harness import new_treasure

ROOT = Path(__file__).resolve().parents[1]


class TreasureJournalTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_treasure()

    def test_empty_per_character_store_and_background_isolation(self):
        self.lua.execute('''
            assert(next(j.kinds)==nil and next(j.encounters)==nil and shell:GetFrame()==nil)
            AzerothFieldbookDB={points=999};AzerothFieldbookAtlasDB={records={x={note='private'}}}
            AzerothFieldbookAccountDB={sections={ledger={contacts={}}}}
            local before=snapshot({AzerothFieldbookDB,AzerothFieldbookAtlasDB,AzerothFieldbookAccountDB})
            local e=carried();assert(e and shell:GetFrame()==nil)
            assert(snapshot({AzerothFieldbookDB,AzerothFieldbookAtlasDB,AzerothFieldbookAccountDB})==before)
            assert(j:History(e.id)[1].context=='carried' and #j:Markers(e.id)==0)
        ''')

    def test_same_name_provisional_kinds_stay_distinct(self):
        self.lua.execute('''
            local a=record('Chest');local b=record('Chest');assert(a.id~=b.id)
            record('Chest',a.id);assert(#j:History(a.id)==2 and #j:History(b.id)==1)
            assert(j:History(a.id)[1].location.x==2500)
        ''')

    def test_item_identity_reuses_kind_but_not_world_name_or_physical_spawn(self):
        self.lua.execute('''
            local e=carried();openitem();assert(T.Count(j.kinds)==1 and #j:History(e.id)==2)
            fire('LOOT_CLOSED');now=now+130;bags[0][1].guid='Item-exact-2';fire('BAG_UPDATE_DELAYED');flush()
            loot={lootrow(2001,1,'Item-exact-2')};fire('LOOT_READY');fire('LOOT_OPENED',false,true)
            assert(#j:History(e.id)==3 and T.Count(j.kinds)==1)
            local other=record('Container 1001');assert(other.id~=e.id)
            local bad=T.Kind({name='Chest',form='world',category='container',itemID=1001});assert(not bad)
        ''')

    def test_later_same_location_is_new_encounter(self):
        self.lua.execute('''
            local e,a=record();now=now+600;local _,b=record(nil,e.id)
            assert(a.id~=b.id and a.origin.at<b.origin.at and a.location.x==b.location.x)
            assert(#j:Markers(e.id)==2 and j:Summary(e).personal==2)
        ''')

    def test_sighting_partial_missing_and_full_are_independent(self):
        self.lua.execute('''
            local e,v=record();assert(v.capture=='missing' and #v.items==0 and not v.facts.inspected)
            local _,p=inspect(e.id,{},'partial');assert(p.capture=='partial' and #p.items==0 and j:Summary(e).contents==0)
            local _,f=inspect(e.id,{},'full');assert(f.capture=='full' and j:Summary(e).inspections==2)
            assert(not f.facts.attempted and j:Summary(e).recoveries==0)
            local bad=inspect(e.id,{{itemID=1,quantity=1}},'missing');assert(not bad)
        ''')

    def test_removal_recomputes_items_locations_and_search_without_erasing_notes(self):
        self.lua.execute('''
            local e,v=record();j:Annotate(e.id,{note='Private guidance',bookmarkNote='Later'});j:Bookmark(e.id)
            now=now+10;mapID=102;local _,contents=inspect(e.id,{{name='Special crystal',quantity=2,recovered=1}})
            assert(#j:List({query='crystal'})==1 and j:Summary(e).recoveries==1)
            assert(not j:Remove(contents.id));assert(j:Remove(contents.id,true))
            assert(#j:List({query='crystal'})==0 and j:Summary(e).recoveries==0)
            assert(#j:Markers(e.id)==1 and e.note=='Private guidance' and e.bookmark)
            j:Remove(v.id,true);assert(j:Summary(e).personal==0 and j:Get(e.id)==e)
        ''')

    def test_location_accuracy_unknown_coordinates_and_portable_meaning(self):
        self.lua.execute('''
            local p=T.CurrentLocation('world');assert(p.precision=='player' and T.LocationText(p):find('approximate player',1,true))
            assert(not T.Location({mapID=101,x=0,y=0,precision='manual'},'world'))
            assert(not T.Location({mapID=101,x=500,precision='manual'},'world'))
            px=0;py=0;local e,v=record();assert(v.location.x==nil and #j:Markers(e.id)==0)
            px=.2;py=.3;local portable,a=record('Box',nil,'portable','acquired');mapID=102
            local _,b=inspect(portable.id,{{itemID=99,quantity=1}})
            assert(#j:Markers(portable.id)==1 and j:Markers(portable.id)[1].id==a.id)
            assert(b.location.meaning=='opened' and b.location.mapID==102)
        ''')

    def test_combined_search_filters_and_recent_sort_use_observation_time(self):
        self.lua.execute('''
            local a=record('Alpha');j:Annotate(a.id,{label='Iron cache',note='Check the cellar',category='salvage'});j:Bookmark(a.id)
            inspect(a.id,{{name='Amber fragment',quantity=1}})
            now=now+50;mapID=102;local b=record('Beta')
            assert(j:List({query='cellar',category='salvage',bookmarks=true,knowledge='personal'})[1].entry==a)
            assert(#j:List({query='amber',zone='Synthetic coast',knowledge='contents'})==1)
            assert(#j:List({query='amber',category='portable'})==0)
            assert(#j:List({zone='@current'})==1 and #j:List({knowledge='missing'})==1)
            assert(j:List({sort='recent'})[1].entry==b)
            assert(j:List({sort='location'})[1].entry==a)
        ''')

    def test_notes_bookmark_and_classification_are_manual_and_never_auto_clear(self):
        self.lua.execute('''
            local e=carried();j:Bookmark(e.id);j:Annotate(e.id,{category='salvage',note='Private',bookmarkNote='Learn more'})
            openitem();assert(e.bookmark and e.category=='salvage' and e.bookmarkNote=='Learn more')
            assert(not j:Annotate(e.id,{form='world'}))
            j=ns.CreateTreasureJournal(saved);assert(j:Get(e.id).bookmark and j:Get(e.id).note=='Private')
        ''')

    def test_manual_correction_does_not_relabel_auto_contents(self):
        self.lua.execute('''
            local e=carried();openitem();local v=j.encounters[t.active.id]
            local changes=T.Copy(v);changes.note='Correction';changes.access='Last observed locked'
            changes.items={{itemID=42,quantity=500,recovered=500}};changes.location.x=7000;changes.location.precision='manual';changes.location.method='manual'
            assert(j:EditEncounter(v.id,changes));v=j.encounters[v.id]
            assert(v.note=='Correction' and v.origin.method=='observed' and v.items[1].itemID==2001)
            assert(v.location.precision=='manual' and v.location.method=='manual' and v.accessMethod=='manual')
            assert(j:Summary(e).recoveries==0)
        ''')

    def test_reload_preserves_history_but_no_active_claim(self):
        self.lua.execute('''
            local e=carried();openitem();local before=snapshot(saved)
            j=ns.CreateTreasureJournal(saved);t=ns.CreateTreasureTracking(j)
            assert(snapshot(saved)==before and not t.active and not t.pending and next(t.bagGUIDs)==nil)
            assert(#j:History(e.id)==2 and #j:Markers(e.id)==0)
            local _,world=record();assert(not world.available and not world.completed and not world.exhausted)
        ''')

    def test_schema_future_malformed_and_capacity_preserve_existing_data(self):
        self.lua.execute('''
            local e=record();saved.kinds.bad={note='Keep malformed notes'};saved.encounters.bad={note='Keep raw evidence'}
            j=ns.CreateTreasureJournal(saved);assert(j.invalid==2 and saved.kinds.bad.note=='Keep malformed notes')
            assert(j:Get(e.id))
            local future={schema=99,note='untouched'};local before=snapshot(future)
            local f=ns.CreateTreasureJournal(future);assert(f.readOnly and snapshot(future)==before)
            assert(not f:Record(nil,{name='x'},{}))
            local limit=T.MAX_ENCOUNTERS;T.MAX_ENCOUNTERS=T.Count(saved.encounters)
            local before=snapshot(saved);local no,err=inspect(e.id,{});assert(not no and err and snapshot(saved)==before)
            T.MAX_ENCOUNTERS=limit
        ''')

    def test_sparse_saved_records_normalize_and_malformed_report_notes_are_preserved(self):
        self.lua.execute('''
            local e,v=record();e.label=nil;e.note=nil;e.bookmarkNote=nil;v.note=nil;v.access=nil;v.result=nil
            j=ns.CreateTreasureJournal(saved);assert(j:Get(e.id).label=='' and #j:List({})==1)
            local report=assert(R.Build(j,e.id));local other=ns.CreateTreasureJournal({});local out=assert(import(other,report))
            local imported=other:History(out.id)[1];imported.reportNote={corrupt='preserve'}
            local reloaded=ns.CreateTreasureJournal(other.db)
            assert(reloaded.invalid==1 and #reloaded:History(out.id)==0 and imported.reportNote.corrupt=='preserve')
        ''')

    def test_invalid_manual_input_is_atomic(self):
        self.lua.execute('''
            local before=snapshot(saved)
            local no,err=j:Record(nil,{name='',form='world',category='container'},{},'manual')
            assert(not no and err and snapshot(saved)==before)
            no,err=j:Record(nil,{name='Chest',form='world',category='container'},
                {context='world',facts={sighted=true},capture='partial',items={{itemID=1,quantity=-1}}})
            assert(not no and err and snapshot(saved)==before)
        ''')


class TreasureCaptureTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_treasure()

    def world_fixture(self):
        self.lua.execute("""
            Enum={TooltipDataType={Object=4}}
            worldData={type=4,id=99,lines={{leftText='Weapon Crate'}}}
            C_TooltipInfo={GetWorldCursor=function() return worldData end}
            function openworld(guid)
                loot={lootrow(2001,1,guid or 'GameObject-0-1-2-3-99-ABC')}
                fire('LOOT_READY');fire('LOOT_OPENED',false,false)
            end
        """)

    def test_food_crate_without_tooltip_id_after_completed_opening(self):
        self.world_fixture()
        self.lua.execute("""
            worldData.id=nil;worldData.lines[1].leftText='Food Crate'
            t:ObserveWorldCursor();assert(t.world and not t.world.objectID)
            fire('UNIT_SPELLCAST_SENT','player','Food Crate','Cast-1',3365)
            worldData=nil;now=now+5
            fire('UNIT_SPELLCAST_SUCCEEDED','player','Cast-1',3365)
            loot={lootrow(3770,3,'GameObject-0-1-2-3-99-ABC')}
            fire('LOOT_READY');loot={};fire('LOOT_OPENED',true)
            local v=assert(j.encounters[t.active.id]);local e=j:Get(v.kindID)
            assert(e.name=='Food Crate' and e.objectID==99)
            assert(v.items[1].itemID==3770 and v.items[1].quantity==3)
            assert(v.items[1].recovered==nil and v.capture=='partial')
        """)

    def test_idless_hover_requires_world_click_and_expires(self):
        self.world_fixture()
        self.lua.execute("""
            worldData.id=nil;worldData.lines[1].leftText='Food Crate'
            openworld();assert(T.Count(j.kinds)==0)
            assert(t.status:find('no matching container',1,true))
            GetMouseFoci=function() return {CreateFrame('Button')} end
            fire('GLOBAL_MOUSE_DOWN','RightButton');openworld();assert(T.Count(j.kinds)==0)
            GetMouseFoci=function() return {WorldFrame} end
            t:ObserveWorldCursor();fire('GLOBAL_MOUSE_DOWN','RightButton')
            worldData=nil;now=now+4;openworld();assert(T.Count(j.kinds)==0)
            worldData={type=4,lines={{leftText='Food Crate'}}}
            fire('GLOBAL_MOUSE_DOWN','RightButton');worldData=nil
            openworld();assert(T.Count(j.encounters)==1)
        """)

    def test_opening_failure_unrelated_cast_and_wrong_source_cancel_fallback(self):
        self.world_fixture()
        self.lua.execute("""
            worldData=nil
            fire('UNIT_SPELLCAST_SENT','player','Food Crate','Cast-1',3365)
            fire('UNIT_SPELLCAST_INTERRUPTED','player','Cast-1',3365)
            openworld();assert(T.Count(j.kinds)==0)
            fire('UNIT_SPELLCAST_SENT','player','Food Crate','Cast-2',3365)
            fire('UNIT_SPELLCAST_SENT','player','Copper Vein','Cast-3',2575)
            fire('UNIT_SPELLCAST_SUCCEEDED','player','Cast-2',3365)
            openworld();assert(T.Count(j.kinds)==0)
            fire('UNIT_SPELLCAST_SENT','player','Food Crate','Cast-4',3365)
            fire('UNIT_SPELLCAST_SUCCEEDED','player','Cast-4',3365)
            openworld('Creature-0-1-2-3-99-ABC');assert(T.Count(j.kinds)==0)
            fire('LOOT_CLOSED');openworld();assert(T.Count(j.kinds)==0)
        """)

    def test_exact_bag_source_accepts_missing_or_false_origin_flag(self):
        self.lua.execute("""
            local e=carried()
            for i=1,2 do
                local guid='Clam-exact-'..i
                bags[0]={bagitem(1001,guid)};fire('BAG_UPDATE_DELAYED');flush()
                loot={lootrow(2001,1,guid)};fire('LOOT_READY')
                if i==1 then loot={};fire('LOOT_OPENED',true)
                else fire('LOOT_OPENED',false,false) end
                local v=assert(j.encounters[t.active.id])
                assert(v.kindID==e.id and v.items[1].quantity==1)
                fire('LOOT_SLOT_CHANGED');fire('LOOT_CLOSED')
            end
            assert(#j:History(e.id)==3,'carriage plus two distinct clam openings')
            loot={lootrow(2001,1,'Unknown-item')}
            fire('LOOT_READY');fire('LOOT_OPENED',false,false)
            assert(#j:History(e.id)==3,'flag alone never identifies a bag container')
        """)

    def test_world_crate_capture_identity_reuse_and_reload(self):
        self.world_fixture()
        self.lua.execute("""
            openworld();assert(T.Count(j.kinds)==1 and T.Count(j.encounters)==1)
            local v=j.encounters[t.active.id];local e=j:Get(v.kindID)
            assert(e.name=='Weapon Crate' and e.objectID==99 and e.form=='world')
            assert(v.context=='world' and v.capture=='partial' and v.facts.inspected)
            assert(v.location.precision=='player' and v.items[1].recovered==nil)
            fire('LOOT_SLOT_CHANGED');assert(T.Count(j.encounters)==1)
            fire('LOOT_CLOSED');openworld();assert(T.Count(j.encounters)==1)
            fire('LOOT_CLOSED');openworld('GameObject-0-1-2-3-99-DEF')
            assert(T.Count(j.kinds)==1 and T.Count(j.encounters)==2)
            local restored=ns.CreateTreasureJournal(saved)
            assert(restored:Get(e.id).objectID==99)
        """)

    def test_contents_chat_respects_setting_and_deduplicates_captures(self):
        self.world_fixture()
        self.lua.execute("""
            local chatEnabled=false;local messages={}
            DEFAULT_CHAT_FRAME={AddMessage=function(_,message) messages[#messages+1]=message end}
            local book=ns.InitializeTreasure(ns.CreateFieldbookShell(),{
                GetCreatureAnnouncement=function() return chatEnabled end})
            j=book.journal;t=book.tracking
            -- Drive only the initialized tracker, without the fixture's old frame.
            function fire(event,...) t:Event(event,...) end
            openworld();assert(#messages==0)
            fire('LOOT_CLOSED');chatEnabled=true
            openworld('GameObject-0-1-2-3-99-DEF')
            assert(#messages==1 and messages[1]:find('[Contents recorded]',1,true))
            assert(messages[1]:find('Weapon Crate',1,true))
            fire('LOOT_SLOT_CHANGED');fire('LOOT_CLOSED')
            openworld('GameObject-0-1-2-3-99-DEF');assert(#messages==1)
            carried();assert(#messages==1,'carriage has no recorded contents')
            openitem();assert(#messages==2 and messages[2]:find('Container 1001',1,true))
            chatEnabled=false;fire('LOOT_CLOSED')
            openworld('GameObject-0-1-2-3-99-EEE');assert(#messages==2)
        """)

    def test_world_chest_coin_slot_does_not_discard_item_contents(self):
        self.world_fixture()
        self.lua.execute("""
            worldData.lines[1].leftText='Battered Chest'
            LOOT_SLOT_MONEY=2;LOOT_SLOT_ITEM=1
            function GetLootSlotType(slot) return loot[slot].coin and LOOT_SLOT_MONEY or LOOT_SLOT_ITEM end
            local guid='GameObject-0-1-2-3-99-ABC'
            loot={{coin=true,name='98 Copper',quantity=0,sources={guid,0}},
                lootrow(2455,2,guid),lootrow(858,3,guid),lootrow(2589,2,guid)}
            fire('LOOT_READY');loot={};fire('LOOT_OPENED',true)
            local v=assert(t.active and j.encounters[t.active.id],t.status)
            assert(j:Get(v.kindID).name=='Battered Chest' and #v.items==3)
            local quantities={};for _,item in ipairs(v.items) do quantities[item.itemID]=item.quantity end
            assert(quantities[2455]==2 and quantities[858]==3 and quantities[2589]==2)
            fire('LOOT_CLOSED')
            loot={{coin=true,quantity=0,sources={'Creature-0-1-2-3-99-ABC',0}},lootrow(2455,2,guid)}
            fire('LOOT_READY');fire('LOOT_OPENED',false)
            assert(not t.active and T.Count(j.encounters)==1,'mixed-source money was accepted')
            loot={lootrow(2455,0,guid)};fire('LOOT_READY');fire('LOOT_OPENED',false)
            assert(not t.active and T.Count(j.encounters)==1,'zero-count item was accepted')
        """)

    def test_world_autoloot_retains_ready_snapshot(self):
        self.world_fixture()
        self.lua.execute("""
            loot={lootrow(2001,1,'GameObject-0-1-2-3-99-ABC')}
            fire('LOOT_READY');worldData=nil;loot={};fire('LOOT_OPENED',true,false)
            assert(T.Count(j.encounters)==1 and j.encounters[t.active.id].items[1].itemID==2001)
        """)

    def test_world_rejects_wrong_source_stale_tooltip_and_noncontainers(self):
        self.world_fixture()
        self.lua.execute("""
            openworld('GameObject-0-1-2-3-100-ABC');assert(T.Count(j.kinds)==0)
            worldData.guid='GameObject-0-1-2-3-99-DEF';openworld();assert(T.Count(j.kinds)==0)
            worldData.guid=nil;worldData.lines[1].leftText='Copper Vein'
            openworld();assert(T.Count(j.kinds)==0)
            worldData.lines[1].leftText='Weapon Crate';t:ObserveWorldCursor()
            worldData=nil;now=now+16;openworld();assert(T.Count(j.kinds)==0)
        """)

    def test_world_rejects_fishing_mixed_sources_and_item_context(self):
        self.world_fixture()
        self.lua.execute("""
            fishing=true;openworld();assert(T.Count(j.kinds)==0);fishing=false
            loot={lootrow(2001,1,'GameObject-0-1-2-3-99-ABC'),lootrow(2002,1,'Creature-0-1-2-3-99-ABC')}
            fire('LOOT_READY');fire('LOOT_OPENED',false,false);assert(T.Count(j.kinds)==0)
            loot={lootrow(2001,1,'GameObject-0-1-2-3-99-ABC')}
            fire('LOOT_READY');fire('LOOT_OPENED',false,true);assert(T.Count(j.kinds)==0)
            fire('LOOT_READY');fire('PLAYER_ENTERING_WORLD');loot={};worldData=nil
            fire('LOOT_OPENED',true,false);assert(T.Count(j.kinds)==0)
        """)

    def test_ordinary_loot_fishing_gathering_and_inventory_do_not_become_treasure(self):
        self.lua.execute('''
            bags[0]={{itemID=55,itemName='Ordinary herb',hasLoot=false}};fire('BAG_UPDATE_DELAYED');flush()
            for _,guid in ipairs({'Creature-0-1-2-3-42-ABC','GameObject-0-1-2-3-99-ABC','Unknown'}) do
                loot={lootrow(123,2,guid)};fire('LOOT_READY');fire('LOOT_OPENED',false,false);fire('LOOT_CLOSED')
            end
            fire('CHAT_MSG_LOOT','You receive loot');fire('QUEST_LOOT_RECEIVED');fire('UNIT_SPELLCAST_SUCCEEDED','player')
            assert(next(j.kinds)==nil and next(j.encounters)==nil)
            local e=carried();fishing=true;openitem();assert(#j:History(e.id)==1)
        ''')

    def test_repeated_events_coalesce_and_observation_never_confirms_receipt(self):
        self.lua.execute('''
            local e=carried();openitem()
            for _=1,30 do fire('LOOT_READY');fire('LOOT_OPENED',false,true);fire('LOOT_SLOT_CHANGED',1) end
            fire('LOOT_SLOT_CLEARED',1);fire('CHAT_MSG_LOOT','You receive item 2001');fire('BAG_UPDATE_DELAYED');flush()
            assert(#j:History(e.id)==2 and j:Summary(e).inspections==1 and j:Summary(e).recoveries==0)
            local v=j.encounters[t.active.id];assert(v.capture=='partial' and v.items[1].quantity==3 and v.items[1].recovered==nil)
            fire('LOOT_CLOSED');openitem();assert(#j:History(e.id)==2)
        ''')

    def test_ready_snapshot_retains_items_removed_by_autoloot(self):
        self.lua.execute('''
            local e=carried();loot={lootrow(2001,3,'Item-exact-1'),lootrow(2002,1,'Item-exact-1')}
            fire('LOOT_READY');loot={lootrow(2002,1,'Item-exact-1')};fire('LOOT_OPENED',true,true)
            assert(#j.encounters[t.active.id].items==2 and #j:History(e.id)==2)
            fire('LOOT_CLOSED');now=now+130;fire('BAG_UPDATE_DELAYED');flush()
            loot={lootrow(3001,1,'Item-exact-1')};fire('LOOT_READY');loot={};fire('LOOT_OPENED',true,true)
            assert(#j:History(e.id)==3 and j.encounters[t.active.id].items[1].itemID==3001)
        ''')

    def test_removed_active_inspection_is_not_recreated_by_repeated_signals(self):
        self.lua.execute('''
            local e=carried();openitem();local id=t.active.id
            assert(j:Remove(id,true));assert(not t.active and #j:History(e.id)==1)
            openitem();fire('LOOT_SLOT_CHANGED',1);assert(#j:History(e.id)==1)
            fire('LOOT_CLOSED');openitem();assert(#j:History(e.id)==2)
        ''')

    def test_deleted_closed_inspection_can_be_rediscovered_immediately(self):
        self.lua.execute('''
            local e=carried();openitem();local id=t.active.id;fire('LOOT_CLOSED')
            assert(j:Remove(id,true));assert(#j:History(e.id)==1)
            openitem();assert(t.active.id~=id and #j:History(e.id)==2)
        ''')

    def test_transient_correlation_capacity_omits_rather_than_recounts(self):
        self.lua.execute('''
            local e=carried()
            for i=1,128 do t.recent['held-'..i]={id='missing:'..i,at=now} end
            openitem();assert(#j:History(e.id)==1 and not t.active and t.status:find('buffer is full',1,true))
            now=now+121;fire('BAG_UPDATE_DELAYED');flush();openitem();assert(#j:History(e.id)==2)
        ''')

    def test_mixed_unreadable_changed_and_unattributed_windows_are_omitted(self):
        self.lua.execute('''
            local e=carried();loot={lootrow(2001,1,'Item-exact-1')};fire('LOOT_READY')
            loot={lootrow(2001,1,'unrelated')};fire('LOOT_OPENED',false,true);assert(not t.active and #j:History(e.id)==1)
            loot={lootrow(2001,1,'Item-exact-1')};loot[1].sources={'Item-exact-1',1,'Creature-other',1}
            fire('LOOT_READY');fire('LOOT_OPENED',false,true);assert(#j:History(e.id)==1)
            loot[1].sources={secret,1};fire('LOOT_READY');fire('LOOT_OPENED',false,true);assert(#j:History(e.id)==1)
            loot={lootrow(2001,1,'Item-exact-1')};fire('LOOT_READY');fire('LOOT_OPENED',false,secret);assert(not t.active)
        ''')

    def test_timeouts_close_reload_and_changed_source_drop_transient_context(self):
        self.lua.execute('''
            local e=carried();loot={lootrow(2001,3,'Item-exact-1')};fire('LOOT_READY')
            now=now+4;loot={};fire('LOOT_OPENED',true,true);assert(#j:History(e.id)==1)
            bags[0]={};fire('BAG_UPDATE_DELAYED');flush();now=now+61;openitem();assert(#j:History(e.id)==1)
            bags[0]={bagitem(1001,'Item-exact-1')};fire('BAG_UPDATE_DELAYED');flush();openitem();assert(t.active)
            fire('PLAYER_ENTERING_WORLD');assert(not t.active and not t.pending);flush()
            assert(#j:History(e.id)==2)
        ''')

    def test_openable_item_identity_survives_idle_and_autoloot_consumption(self):
        self.lua.execute('''
            local e=carried();now=now+900
            bags[0]={};fire('BAG_UPDATE_DELAYED');flush();openitem()
            assert(#j:History(e.id)==2 and t.active,'an idle bag item consumed by opening can still match its exact source')
        ''')

    def test_missing_apis_fail_closed_without_errors_or_fabricated_coordinates(self):
        self.lua.execute('''
            C_Container.GetContainerItemInfo=function() error('unsupported') end;fire('BAG_UPDATE_DELAYED');flush()
            assert(next(j.kinds)==nil)
            local e=record();C_Map.GetPlayerMapPosition=function() return secret end
            local p=T.CurrentLocation('world');assert(p.x==nil and p.y==nil)
            GetLootSourceInfo=nil;fire('LOOT_READY');fire('LOOT_OPENED',false,true);assert(#j:History(e.id)==1)
        ''')

    def test_bag_events_are_bounded_and_metadata_is_not_an_encounter(self):
        self.lua.execute('''
            bags[0]={bagitem(1001,'Item-exact-1')}
            for _=1,100 do fire('BAG_UPDATE_DELAYED') end;assert(#timers==1);flush()
            local e=j:FindItem(1001);j:Title(e);metadata[1001]='Resolved chest';fire('GET_ITEM_INFO_RECEIVED',1001,true)
            assert(j:Title(e)=='Resolved chest' and #j:History(e.id)==1 and shell:GetFrame()==nil)
            for _=1,100 do fire('BAG_UPDATE_DELAYED');flush() end;assert(#j:History(e.id)==1)
        ''')


class TreasureReportTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_treasure()

    def test_reports_are_detached_previewed_and_private_by_default(self):
        self.lua.execute('''
            local e,v=record();e.note='Private kind';e.bookmarkNote='Private reason';v.note='Private encounter'
            local r=assert(R.Build(j,e.id));assert(r.note==nil and r.encounters[1].note=='' and r.identity.label==nil)
            assert(not snapshot(r):find('Private',1,true))
            local shared=assert(R.Build(j,e.id,{notes=true}));assert(shared.note=='Private kind' and shared.encounters[1].note=='Private encounter')
            local other=ns.CreateTreasureJournal({});assert(not R.Accept(other,shared))
            local ticket=assert(R.Prepare(r));r.identity.name='Tampered';ticket.preview='Tampered display'
            local out=assert(R.Accept(other,ticket));assert(out.name=='Synthetic chest' and other:Summary(out).personal==0)
            assert(not R.Accept(other,ticket))
        ''')

    def test_original_time_receipt_forwarding_dedup_and_no_personal_credit(self):
        self.lua.execute('''
            local e,v=record();local _,a=inspect(e.id,{{itemID=22,quantity=4,recovered=3}})
            local original=v.origin.at;local report=assert(R.Build(j,e.id));now=now+1000
            AzerothFieldbookDB={knowledge=321};local other=ns.CreateTreasureJournal({})
            local out,n=assert(import(other,report));assert(n==2)
            local s=other:Summary(out);assert(s.personal==0 and s.inspections==0 and s.recoveries==0 and s.reported==2 and s.last==original)
            local first=other:History(out.id)[1];assert(first.received==now and first.origin.at==original)
            now=now+100;local same,n=import(other,report);assert(same==out and n==0 and #other:History(out.id)==2)
            assert(first.received==now-100 and AzerothFieldbookDB.knowledge==321)
            local forwarded=assert(R.Forward(other,first.id));assert(forwarded.encounters[1].origin.at==original)
            local third=ns.CreateTreasureJournal({});local accepted=assert(import(third,forwarded))
            assert(third:History(accepted.id)[1].origin.source==v.origin.source and #third:History(accepted.id)==2)
        ''')

    def test_personal_observation_does_not_verify_reported_contents_or_access(self):
        self.lua.execute('''
            local e,v=record();v.access='Reported locked';inspect(e.id,{{itemID=444,quantity=1}})
            local other=ns.CreateTreasureJournal({});local out=assert(import(other,assert(R.Build(j,e.id))))
            other:Record(out.id,nil,{context='world',facts={sighted=true},capture='missing',items={}},'manual')
            local s=other:Summary(out);assert(s.personal==1 and s.inspections==0 and s.reported==2)
            assert(other:History(out.id)[1].origin.method=='manual')
            local found=0;for _,row in ipairs(other:History(out.id)) do if row.reported then found=found+#row.items end end
            assert(found==1 and out.note=='')
        ''')

    def test_conflicts_and_capacity_reject_atomically(self):
        self.lua.execute('''
            local e=record();local r=assert(R.Build(j,e.id));local other=ns.CreateTreasureJournal({})
            local out=assert(import(other,r));local before=snapshot(other.db)
            r.encounters[1].location.x=9999;assert(not import(other,r));assert(snapshot(other.db)==before)
            local p=record('Portable',nil,'portable','acquired');local rp=assert(R.Build(j,p.id))
            assert(not import(other,rp,out.id));assert(snapshot(other.db)==before)
            local e2=record('Second');local report=assert(R.Build(j,e2.id))
            local cap=T.MAX_ENCOUNTERS;T.MAX_ENCOUNTERS=1;assert(not import(other,report))
            assert(snapshot(other.db)==before);T.MAX_ENCOUNTERS=cap
        ''')

    def test_unknown_observation_time_stays_unknown(self):
        self.lua.execute('''
            local e=record();local r=assert(R.Build(j,e.id));r.encounters[1].origin.at=nil
            local other=ns.CreateTreasureJournal({});local out=assert(import(other,r))
            assert(other:Summary(out).last==0 and other:History(out.id)[1].origin.at==nil)
            assert(T.Date(nil)=='Time unknown')
        ''')

    def test_untrusted_and_oversized_payloads_are_rejected(self):
        self.lua.execute('''
            local e=record();local base=assert(R.Build(j,e.id))
            local bad={nil,false,'return os.execute()',{},setmetatable({},{})}
            for _,v in pairs(bad) do assert(not R.Validate(v)) end
            local r=T.Copy(base);r.extra=true;assert(not R.Validate(r))
            r=T.Copy(base);r.schema=99;assert(not R.Validate(r))
            r=T.Copy(base);r.addonVersion='0.0.0';assert(not R.Validate(r))
            r=T.Copy(base);r.identity.name='|Hplayer:bad|hclick|h';assert(not R.Validate(r))
            r=T.Copy(base);r.encounters[1].location.x=0;r.encounters[1].location.y=0;assert(not R.Validate(r))
            r=T.Copy(base);r.encounters[1].location.meaning='opened';assert(not R.Validate(r))
            r=T.Copy(base);r.encounters[1].origin.at=now+1;assert(not R.Validate(r))
            r=T.Copy(base);r.encounters[3]=T.Copy(r.encounters[1]);assert(not R.Validate(r))
            r=T.Copy(base);r.encounters[1].facts.opened=true;assert(not R.Validate(r))
            r=T.Copy(base);r.identity.secret=secret;assert(not R.Validate(r))
            r=T.Copy(base);r.note=string.rep('x',4001);assert(not R.Validate(r))
            r=T.Copy(base);r.cycle=r;assert(not R.Validate(r))
            r=T.Copy(base);for i=2,51 do r.encounters[i]=T.Copy(r.encounters[1]);r.encounters[i].origin.key='key'..i end;assert(not R.Validate(r))
            r=T.Copy(base);for i=1,30 do r.encounters[i]=T.Copy(base.encounters[1]);r.encounters[i].origin.key='key'..i;r.encounters[i].note=string.rep('x',4000) end
            assert(not R.Validate(r))
        ''')

    def test_report_selection_bounds_and_optional_fields(self):
        self.lua.execute('''
            local e,v=record();v.note='Secret';v.access='Manual lock';inspect(e.id,{{itemID=33,quantity=1}})
            local r=assert(R.Build(j,e.id,{selection={[v.id]=true},locations=false,contents=false,access=false}))
            assert(#r.encounters==1 and r.encounters[1].location.mapID==nil and r.encounters[1].access=='' and r.encounters[1].capture=='missing')
            assert(R.Encode==nil and R.Decode==nil,'no parallel protocol or alternate free exports')
        ''')

    def test_selected_report_facts_can_enrich_an_origin_without_multiplying_history(self):
        self.lua.execute('''
            local e,v=record();v.note='Shared by explicit opt-in';v.access='Manual access';e.note='Shared kind note'
            local _,inspection=inspect(e.id,{{itemID=33,quantity=1}})
            local partial=assert(R.Build(j,e.id,{locations=false,contents=false,access=false}))
            local other=ns.CreateTreasureJournal({});local out=assert(import(other,partial))
            local originalReceipt=other:History(out.id)[1].received;now=now+50
            assert(import(other,assert(R.Build(j,e.id,{notes=true}))))
            assert(#other:History(out.id)==2 and #other:Markers(out.id)==2 and other:Summary(out).personal==0)
            local items=0;local note
            for _,row in ipairs(other:History(out.id)) do
                items=items+#row.items;if row.note~='' then note=row.note end
                assert(row.received==originalReceipt and row.enrichedAt==now and row.reportNote=='Shared kind note')
            end
            assert(items==1 and note=='Shared by explicit opt-in')
            assert(import(other,partial));assert(#other:History(out.id)==2 and #other:Markers(out.id)==2)
        ''')

    def test_staged_enrichment_rolls_back_if_a_later_fact_conflicts(self):
        self.lua.execute('''
            local e,v=record();local _,second=record(nil,e.id)
            local full=assert(R.Build(j,e.id));local other=ns.CreateTreasureJournal({});local out=assert(import(other,full))
            full.encounters[1].note='New shared annotation';full.encounters[2].location.x=1234
            local before=snapshot(other.db);assert(not import(other,full));assert(snapshot(other.db)==before)
        ''')

    def test_original_encounter_dedup_cannot_attach_a_conflicting_item_identity(self):
        self.lua.execute('''
            local e=carried();local report=assert(R.Build(j,e.id));local other=ns.CreateTreasureJournal({})
            assert(import(other,report));local before=snapshot(other.db)
            report.identity.source='Different claim';report.identity.key='different';report.identity.itemID=9876
            assert(not import(other,report));assert(snapshot(other.db)==before)
        ''')


class TreasureUITests(unittest.TestCase):
    def setUp(self):
        self.lua = new_treasure(True)

    def test_empty_states_and_fixed_atlas_geometry_with_independent_instances(self):
        self.lua.execute('''
            assert(m.empty:IsShown() and m.empty:GetText():find('begins empty',1,true))
            local atlasJournal=ns.CreateAtlasJournal({});local atlas=ns.CreateAtlasMap(m,atlasJournal,function() end,function() end)
            atlas:SetPoint('TOP',m,'TOPLEFT',632,-205);atlas:Render(mapID)
            assert(m.map:GetWidth()==atlas:GetWidth() and m.map:GetHeight()==atlas:GetHeight())
            for i=1,5 do assert(m.map.point[i]==atlas.point[i]) end
            assert(m.map.available and m.map.emptyShade:IsShown() and c.state.mapID==nil)
            local e=record();c:Select(e.id);atlas:Render(101)
            assert(not m.map.emptyShade:IsShown())
            assert(m.map:GetWidth()==atlas:GetWidth() and m.map:GetHeight()==atlas:GetHeight())
            m.map:ZoomBy(1);assert(m.map.zoom~=atlas.zoom)
            state=nil;c.state.query='No matching name';c:Filter();assert(m.empty:GetText():find('No entries match',1,true))
            assert(c.state.selected==e.id)
        ''')

    def test_map_toolbar_gaps_and_empty_fallback_do_not_record_data(self):
        self.lua.execute('''
            local previous
            for _,button in ipairs({m.mapZone,m.scope,m.edit}) do
                assert(button.point[3]==-174)
                if previous then assert(button.point[2]-(previous.point[2]+previous:GetWidth())==6) end
                previous=button
            end
            assert(m.remove:GetText()=='Delete' and m.remove.point[2]==174 and m.remove.point[3]==-672)
            local before=snapshot(j.db);mapID=102;c:Refresh()
            assert(m.map.available and m.map.emptyShade:IsShown())
            assert(snapshot(j.db)==before)
            C_Map.GetMapArtLayers=nil;m.map:Invalidate();c:Refresh()
            assert(not m.map.available and not m.map.emptyShade:IsShown() and m.map.empty:IsShown())
        ''')

    def test_real_manual_form_saves_items_provenance_and_unknown_location(self):
        self.lua.execute(r'''
            c:Manual();local p=c.panels.manual;p.name:SetText('Manual chest')
            p.inspected:SetChecked(true);p.captureID='partial';p.items:SetText('123;3;1\nUnidentified shard;2')
            p.note:SetText('My private note');click(p.save)
            local e=j:Get(c.state.selected);assert(e and #j:History(e.id)==1)
            local v=j:History(e.id)[1];assert(v.origin.method=='manual' and v.location.x==nil and #v.items==2)
            assert(v.items[1].recovered==1 and j:Summary(e).recoveries==1 and #j:Markers(e.id)==0)
            assert(c.panel==nil)
        ''')

    def test_player_suggestion_and_manual_coordinate_correction_are_labelled(self):
        self.lua.execute('''
            c:Manual();local p=c.panels.manual;p.name:SetText('Positioned chest');click(p.current)
            assert(p.precisionID=='player' and p.x:GetText()=='25')
            p.x:SetText('26');p.x.scripts.OnTextChanged();assert(p.precisionID=='manual')
            click(p.save);local v=j:History(c.state.selected)[1]
            assert(v.location.x==2600 and v.location.precision=='manual' and v.location.method=='manual')
        ''')

    def test_manual_unknown_time_does_not_invent_an_observation_date(self):
        self.lua.execute('''
            c:Manual();local p=c.panels.manual;p.name:SetText('Remembered find');p.timeUnknown:SetChecked(true);click(p.save)
            local e=j:Get(c.state.selected);local v=j:History(e.id)[1]
            assert(v.origin.at==nil and v.recordedAt==now and j:Summary(e).last==0)
            assert(c:DetailRows()[1].text:find('Time unknown',1,true))
        ''')

    def test_arriving_observations_preserve_top_row_and_selection(self):
        self.lua.execute('''
            for i=1,20 do record(string.format('Chest %02d',i)) end;c:Refresh()
            c:Select(c.rows[12].entry.id);m.list.scripts.OnMouseWheel(m.list,-7);m.list.scripts.OnVerticalScroll(m.list,m.list:GetVerticalScroll());assert(not m.previous and not m.next);local top=m.rows[1].id;local selected=c.state.selected
            record('AAA newest');flush();assert(m.rows[1].id==top and c.state.selected==selected)
        ''')

    def test_removal_requires_confirmation_and_refreshes_map(self):
        self.lua.execute('''
            local e,v=record();c:Select(e.id);assert(m.map.pins[1]:IsShown())
            c:RemoveEncounter();assert(j.encounters[v.id] and c.panels.remove.encounterID==v.id)
            assert(j:Remove(v.id,true));c:ClosePanel();c:Refresh()
            assert(not m.map.pins[1]:IsShown() and m.map.empty:IsShown() and j:Summary(e).personal==0)
        ''')

    def test_pin_groups_cycle_history_without_losing_selected_kind(self):
        self.lua.execute('''
            local e,a=record();now=now+10;local _,b=record(nil,e.id);local other,v=record('Other')
            c:Select(e.id);assert(#m.map.pins[1].group==2)
            local previous=c.state.encounter;m.map.pins[1].scripts.OnClick(m.map.pins[1],'LeftButton')
            assert(c.state.selected==e.id and c.state.encounter~=previous)
            c.state.allZone=true;c:Refresh();assert(#m.map.pins[1].group==3)
            c:Encounter(v.id);assert(c.state.selected==e.id and c.state.encounter==v.id)
            assert(c:DetailRows()[1].text:find('Other',1,true))
            m.map.pins[1].scripts.OnEnter(m.map.pins[1]);assert(GameTooltip.text:find('current availability unknown',1,true))
        ''')

    def test_browsing_drafts_scroll_and_map_survive_page_switching(self):
        self.lua.execute('''
            local e=record();c:Select(e.id);c.state.query='Synthetic';m.search:SetText('Synthetic');c:Notes()
            c.panels.notes.note:SetText('Unsaved draft');m.details:SetVerticalScroll(14);m.map:ZoomBy(1)
            local zoom=m.map.zoom;local panel=c.panel
            shell:ShowSection('other');assert(c.state.detailScroll==14 and not m.map:IsVisible())
            shell:ShowSection('treasure');assert(c.state.selected==e.id and c.state.query=='Synthetic')
            assert(c.panel==panel and c.panels.notes.note:GetText()=='Unsaved draft' and m.map.zoom==zoom)
            assert(m.details:GetVerticalScroll()==14)
        ''')

    def test_hidden_updates_do_not_redraw_and_delayed_metadata_preserves_selection(self):
        self.lua.execute('''
            local a=record('A');local b=record('B');c:Select(b.id)
            local renders=0;local refresh=c.Refresh;c.Refresh=function(self,...) renders=renders+1;return refresh(self,...) end
            shell:ShowSection('other');local count=renders;carried();assert(renders==count)
            shell:ShowSection('treasure');assert(c.state.selected==b.id)
            local e=j:FindItem(1001);j:Title(e);metadata[1001]='AAA item';fire('GET_ITEM_INFO_RECEIVED',1001,true);flush()
            assert(c.state.selected==b.id and m.name:GetText()=='B')
        ''')

    def test_large_history_is_paged_and_widgets_are_reused(self):
        self.lua.execute('''
            local e=record();for i=1,1000 do now=now+1;record(nil,e.id) end;c:Select(e.id)
            c.state.detail='history';c:Refresh();assert(#c:DetailRows()<=10 and #m.detailRows<=12)
            click(m.older);assert(c.state.historyOffset==8)
            c:Notes();c:Manual();c:Expand();c:ClosePanel();shell:ShowSection('other');shell:ShowSection('treasure');local objectsBefore=#objects
            for _=1,30 do c:Notes();c:Manual();c:Expand();c:ClosePanel();shell:ShowSection('other');shell:ShowSection('treasure') end
            assert(#objects==objectsBefore,'repeat navigation/editor visits must reuse widgets')
            assert(#j:History(e.id)==1001)
        ''')

    def test_tooltips_and_link_input_use_only_observed_item_identity(self):
        self.lua.execute('''
            local e=record();inspect(e.id,{{itemID=555,quantity=2}});c:Select(e.id);click(m.showContents)
            function GameTooltip:SetHyperlink(link) self.link=link end
            local itemRow;for _,row in ipairs(m.contentsRows) do if row.data and row.data.item then itemRow=row;break end end
            itemRow.scripts.OnEnter(itemRow);assert(GameTooltip.link=='item:555')
            local parsed=assert(T.ParseItems('|cff00ff00|Hitem:777|h[Test]|h|r;2;1'))
            assert(parsed[1].itemID==777 and parsed[1].quantity==2 and parsed[1].recovered==1)
        ''')

    def test_contents_overlay_is_independent_of_footer_selection(self):
        self.lua.execute('''
            local e,v=record();inspect(e.id,{{itemID=555,quantity=2}});c:Select(e.id)
            m.list:SetVerticalScroll(0);m.details:SetVerticalScroll(14)
            click(m.showContents)
            assert(c.state.detail=='summary' and m.details:GetVerticalScroll()==14)
            assert(m.showContents.afbSelected and m.contents:IsShown() and not m.list:IsShown())
            for _,key in ipairs({'history','notes','summary'}) do
                click(m.detailButtons[key])
                assert(c.state.showContents and m.contents:IsShown())
                for other,button in pairs(m.detailButtons) do assert(button.afbSelected==(other==key)) end
            end
            c:Encounter(v.id)
            assert(m.detailButtons.history.afbSelected and m.showContents.afbSelected)
            click(m.showContents)
            assert(c.state.detail=='history' and not m.contents:IsShown() and m.list:IsShown())
            assert(not m.showContents.afbSelected)
            click(m.notes);assert(c.panel==c.panels.notes)
            c:ClosePanel();assert(m.list:IsShown())
        ''')

    def test_notes_overlay_animation_switching_reversal_and_restore(self):
        self.lua.execute("""
            local e=record();c:Select(e.id)
            local before=snapshot(j.db)
            assert(m.notesOverlay.point[3]==-588 and m.details:GetHeight()==80)
            click(m.expand)
            m.notesOverlay.scripts.OnUpdate(m.notesOverlay,.09)
            assert(m.notesOverlay.point[3]>-588 and m.notesOverlay.point[3]<-174)
            assert(m.notesPaper:IsShown())
            click(m.expand)
            m.notesOverlay.scripts.OnUpdate(m.notesOverlay,.18)
            assert(m.notesOverlay.point[3]==-588 and m.notesPaper:IsShown())
            click(m.expand);m.notesOverlay.scripts.OnUpdate(m.notesOverlay,.18)
            assert(m.notesOverlay.point[3]==-174 and m.details:GetHeight()==494)
            assert(m.notesOverlay.scripts.OnUpdate==nil)
            for _,key in ipairs({'notes','history','summary'}) do
                click(m.detailButtons[key])
                assert(c.state.detail==key and m.notesExpanded and m.notesOverlay.point[3]==-174)
            end
            click(m.expand);m.notesOverlay.scripts.OnUpdate(m.notesOverlay,.18)
            assert(m.notesOverlay.point[3]==-588 and m.details:GetHeight()==80)
            assert(snapshot(j.db)==before,'overlay navigation must not alter saved evidence')
        """)

    def test_edit_category_can_reset_to_default(self):
        self.lua.execute("""
            local e=record();j:Annotate(e.id,{category='salvage'});c:Select(e.id);c:Notes()
            local p=c.panels.notes
            local actions={}
            function c:Menu(button,build)
                local root={}
                function root:CreateButton(label,action) actions[label]=action end
                function root:CreateDivider() end
                build(button,root)
            end
            click(p.category);assert(actions.Clear);actions.Clear()
            assert(p.categoryID=='container' and p.category:GetText()=='Container type')
            assert(j:Get(e.id).category=='salvage','clearing a draft must wait for Save')
            assert(p.back:GetText()=='Back')
            c:Manual();assert(c.panels.manual.save:GetText()=='Save' and c.panels.manual.back:GetText()=='Back')
        """)

    def test_editors_and_map_stay_inside_existing_shell_bounds(self):
        self.lua.execute('''
            local e=record();c:Select(e.id);c:Notes();c:Manual();c:Expand();c:RemoveEncounter()
            for _,p in pairs(c.panels) do
                assert(p.point[2]==38 and p:GetWidth()==262 and p.point[2]+p:GetWidth()<306)
                assert(-p.point[3]+p:GetHeight()<=715)
            end
            for _,scale in ipairs({.5,.75,1,1.25,1.5}) do
                shell:GetFrame():SetScale(scale)
                assert(m.map:GetEffectiveScale()==shell:GetFrame():GetEffectiveScale())
                assert(m.map.point[4]==632 and m.map.point[5]==-205)
            end
        ''')


if __name__ == '__main__':
    unittest.main()
