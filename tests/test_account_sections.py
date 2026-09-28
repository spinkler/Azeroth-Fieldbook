"""Shared stores, ID remapping and one-time imports across characters."""
import unittest
from ui_test_harness import ROOT
from test_gathering import client as gathering_client
from atlas_test_harness import new_atlas
from angling_test_harness import new_angling
from ledger_test_harness import new_ledger


def account(lua):
    lua.execute((ROOT/'AccountSections.lua').read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
    lua.execute('''
        AzerothFieldbookAccountDB={}
        function scope(key,on)
            ns.InitializeSectionTracking({accountTrackingKey=key,accountWideTracking=on~=false})
        end
        function size(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
        scope(1)
    ''')


class AccountSectionTests(unittest.TestCase):
    def test_real_section_initializers_use_selected_store(self):
        for name, factory in [('Gathering',gathering_client),('Atlas',new_atlas),
                              ('Angling',new_angling),('Ledger',new_ledger)]:
            with self.subTest(section=name):
                lua=factory();account(lua)
                lua.execute(f'''
                    AzerothFieldbook{name}DB={{}}
                    local controller=ns.Initialize{name}(ns.CreateFieldbookShell())
                    local shared=AzerothFieldbookAccountDB.sections.{name.lower()}
                    assert(shared and shared~=AzerothFieldbook{name}DB)
                    assert(ns.ActiveSectionStores.{name.lower()}==shared)
                    local journal=controller.journal
                    assert(journal and (journal.db==shared or journal.saved==shared or journal.entries==shared.entries))
                ''')

    def test_gathering_merge_once_and_opt_out_isolation(self):
        lua=gathering_client();account(lua)
        lua.execute('''
            local a,b={},{}
            local one=ns.CreateGatheringJournal(a);local two=ns.CreateGatheringJournal(b)
            one:Discover('herb','Peacebloom',100,'Elwynn')
            two:Discover('herb','Peacebloom',200,'Westfall')
            local key=next(a.entries)
            a.entries[key].interactions=2;a.entries[key].completed=1;a.entries[key].note='First note'
            b.entries[key].interactions=3;b.entries[key].completed=2;b.entries[key].note='Second note'
            one:ObserveLoot(key,{[765]={quantity=2,name='Leaf'}},100)
            two:ObserveLoot(key,{[765]={quantity=5,name='Leaf'},[2447]={quantity=1,name='Flower'}},200)
            local selected=ns.SelectSectionStorage('gathering',a)
            selected.entries[key].interactions=4
            assert(a.entries[key].interactions==2)
            scope(2);selected=ns.SelectSectionStorage('gathering',b)
            assert(selected.entries[key].interactions==7 and selected.entries[key].completed==3)
            assert(selected.entries[key].loot[765].minQuantity==2 and selected.entries[key].loot[765].maxQuantity==5)
            assert(selected.entries[key].loot[2447].name=='Flower')
            assert(selected.entries[key].zones.Elwynn and selected.entries[key].zones.Westfall)
            assert(selected.entries[key].note:find('Second note',1,true))
            scope(2);assert(ns.SelectSectionStorage('gathering',b).entries[key].interactions==7)
            scope(2,false);assert(ns.SelectSectionStorage('gathering',b)==b)
            scope(2);assert(ns.SelectSectionStorage('gathering',b).entries[key].interactions==7)
            assert(AzerothFieldbookAccountDB.bestiary==nil)
        ''')

    def test_atlas_conflicting_ids_keep_connections(self):
        lua=new_atlas();account(lua)
        lua.execute('''
            local a={schema=1,records={same={id='same',name='First place'}},expeditions={}}
            local b={schema=1,records={same={id='same',name='Second place'},
                route={id='route',name='Route',stops={{recordID='same',name='Second place'}},related={'same'}}},
                expeditions={trip={id='trip',related={'same','route'}}}}
            a.subzones={[37]={{kind='interior',mapID=37,x=100,y=200,name='Town',at=1}}}
            b.subzones={[37]={{kind='interior',mapID=37,x=100,y=200,name='Town',at=2},{kind='interior',mapID=37,x=300,y=400,name='Farm',at=3}}}
            ns.SelectSectionStorage('atlas',a);scope(2)
            local merged=ns.SelectSectionStorage('atlas',b)
            assert(size(merged.records)==3 and merged.records.same.name=='First place')
            assert(#merged.subzones[37]==2 and merged.subzones[37][2].name=='Farm')
            local route,place
            for _,r in pairs(merged.records) do if r.name=='Route' then route=r elseif r.name=='Second place' then place=r end end
            assert(route.stops[1].recordID==place.id and route.related[1]==place.id)
            local trip=next(merged.expeditions);assert(merged.expeditions[trip].related[1]==place.id)
            assert(b.records.route.stops[1].recordID=='same')
            scope(2);assert(size(ns.SelectSectionStorage('atlas',b).records)==3)
        ''')

    def test_angling_catches_references_and_future_observations(self):
        lua=new_angling();account(lua)
        lua.execute('''
            local a,b={},{}
            for _,db in ipairs({a,b}) do
                local fish=ns.CreateAnglingJournal(db)
                local spot=assert(fish:Remember({name='Pier',location=ns.Angling.CurrentLocation(),note='Private note'}))
                local context=fish:Context(ns.Angling.CurrentLocation(),{source='open',spotID=spot.id},'observed',{effective=10})
                assert(fish:RecordCatch('same-token',context,{{itemID=1001,name='Fish',quantity=3}}))
            end
            ns.SelectSectionStorage('angling',a);scope(2)
            local merged=ns.SelectSectionStorage('angling',b)
            assert(size(merged.waters)==1 and size(merged.items)==1)
            assert(size(merged.spots)==2 and size(merged.aggregates)==2 and #merged.history==2)
            local quantity=0
            for _,f in pairs(merged.aggregates) do
                assert(merged.waters[f.waterID] and merged.spots[f.spotID])
                for id,item in pairs(f.items) do assert(merged.items[id]);quantity=quantity+item.quantity end
            end
            assert(quantity==6)
            local fish=ns.CreateAnglingJournal(merged)
            local context=fish:Context(ns.Angling.CurrentLocation(),nil,'observed',{effective=20})
            assert(fish:RecordCatch('new',context,{{itemID=1001,name='Fish',quantity=2}}))
            assert(size(merged.items)==1)
            scope(2);merged=ns.SelectSectionStorage('angling',b)
            quantity=0;for _,f in pairs(merged.aggregates) do for _,item in pairs(f.items) do quantity=quantity+item.quantity end end
            assert(quantity==8)
        ''')

    def test_atlas_deleted_references_stay_missing_after_import_and_reload(self):
        lua=new_atlas();account(lua)
        lua.execute('''
            local a,b={},{}
            local first=ns.CreateAtlasJournal(a);local second=ns.CreateAtlasJournal(b)
            local accountID=assert(first:Save(fixture('Unrelated account landmark')))
            local oldRoute=fixture('Existing missing route','route')
            oldRoute.stops={{recordID='char2:1',name='Already missing'}}
            local oldRouteID=assert(first:Save(oldRoute))
            local missingID=assert(second:Save(fixture('Deleted character landmark')))
            assert(accountID==missingID)
            local route=fixture('Route to deleted landmark','route')
            route.stops={{recordID=missingID,name='Deleted character landmark'}};route.related={missingID}
            local routeID=assert(second:Save(route))
            local trip=fixture('Expedition');trip.related={missingID,routeID}
            assert(second:Save(trip,nil,true))
            assert(second:Delete(missingID))
            ns.SelectSectionStorage('atlas',a);scope(2)
            local selected=ns.SelectSectionStorage('atlas',b)
            for pass=1,2 do
                local merged=ns.CreateAtlasJournal(selected)
                local imported
                for _,e in pairs(merged.records) do if e.name==route.name then imported=e end end
                assert(imported and merged:ResolveStop(imported.stops[1]).missing)
                assert(imported.related[1]==imported.stops[1].recordID and not merged:Get(imported.related[1]))
                local expedition=merged.expeditions[next(merged.expeditions)]
                assert(expedition.related[1]==imported.related[1] and expedition.related[2]==imported.id)
                assert(merged:ResolveStop(merged:Get(oldRouteID).stops[1]).missing,
                    'New imports must not occupy an existing unresolved ID')
                local newID=assert(merged:Save(fixture('New account landmark '..pass)))
                assert(newID~=imported.related[1])
                scope(2);selected=ns.SelectSectionStorage('atlas',b)
            end
            assert(b.records[routeID].stops[1].recordID==missingID and not b.records[missingID])
        ''')

    def test_angling_merged_hover_lookup_survives_account_import(self):
        lua=new_angling();account(lua)
        lua.execute('''
            local p=A.CurrentLocation();p.subzone=''
            local hover=assert(j:ObservePool({name='Synthetic school'},p))
            local manual=assert(j:Remember({name='Corrected pool',location=p,pool={name='Synthetic school'}}))
            assert(j:MergeSpots(hover.id,manual.id))
            ns.SelectSectionStorage('angling',{});scope(2)
            local selected=ns.SelectSectionStorage('angling',saved)
            local shared=ns.CreateAnglingJournal(selected)
            local before=A.Count(selected.spots)
            local sighting=assert(shared:ObservePool({name='Synthetic school'},p))
            assert(A.Count(selected.spots)==before and sighting.name=='Corrected pool')
        ''')

    def test_future_gathering_schema_survives_initializer_and_background_tracking(self):
        for account_wide in (True,False):
            with self.subTest(account_wide=account_wide):
                lua=gathering_client();account(lua)
                lua.execute('scope(1,'+str(account_wide).lower()+')')
                lua.execute('''
                    local future={schema=99,entries={futureRecord={keep=true}},futureSettings={keep=true}}
                    local entries,record=future.entries,future.entries.futureRecord
                    AzerothFieldbookGatheringDB=future
                    local shell=ns.CreateFieldbookShell()
                    local controller=ns.InitializeGathering(shell)
                    journal=controller.journal;tracker=controller.tracking
                    assert(journal.readOnly and journal.entries~=entries)
                    hover('Silverleaf');discover();gather('Silverleaf','future-cast')
                    assert(not journal:Discover('herb','Silverleaf',100,'Elwynn'))
                    journal:RecordInteraction('herb','Silverleaf',{},'Elwynn',100)
                    journal:Complete('futureRecord');journal:ObserveLoot('futureRecord',{},100)
                    assert(not journal:SetNote('futureRecord','Changed'))
                    journal:SetShowNodesOn('worldMap',true);journal:SetListSort('completed',true)
                    journal:SetLocationMapBrightness(.4)
                    shell:ShowSection('gathering')
                    assert(controller.frame.noMatches:GetText():find('newer',1,true))
                    assert(not next(journal.entries) and not journal:ShowNodesOn('worldMap'))
                    assert(future.schema==99 and future.entries==entries and entries.futureRecord==record)
                    assert(record.keep and size(entries)==1 and size(record)==1 and size(future)==3)
                    assert(future.futureSettings.keep and size(future.futureSettings)==1)
                    assert(not AzerothFieldbookAccountDB.sections or not AzerothFieldbookAccountDB.sections.gathering)
                    local again=ns.CreateGatheringJournal(future)
                    assert(again.readOnly and future.schema==99 and entries.futureRecord==record)
                ''')

    def test_ledger_contact_id_collision_preserves_identity(self):
        lua=new_ledger();account(lua)
        lua.execute('''
            local a,b={},{}
            local ja=ns.CreateLedgerJournal(a);local jb=ns.CreateLedgerJournal(b)
            a.origin='first';b.origin='second'
            local one=ja:New('First merchant');local two=jb:New('Second merchant')
            one.note='One';two.note='Two';ja:Bind(one,'guid-one');jb:Bind(two,'guid-two')
            assert(one.id==two.id)
            ns.SelectSectionStorage('ledger',a);scope(2)
            local merged=ns.SelectSectionStorage('ledger',b)
            assert(size(merged.contacts)==2)
            local oneID=merged.references[one.reference];local twoID=merged.references[two.reference]
            assert(oneID~=twoID and merged.contacts[twoID].name=='Second merchant')
            assert(merged.aliases['guid-one']==oneID and merged.aliases['guid-two']==twoID)
            assert(merged.contacts[twoID].note=='Two' and b.contacts[two.id].id==two.id)
            local nextContact=ns.CreateLedgerJournal(merged):New('Third merchant')
            assert(size(merged.contacts)==3 and nextContact.id~=twoID)
            scope(2);assert(size(ns.SelectSectionStorage('ledger',b).contacts)==3)
        ''')

    def test_future_schema_preserved(self):
        lua=new_angling();account(lua)
        lua.execute('''
            local future={schema=99,secretHistory={keep=true}}
            assert(ns.SelectSectionStorage('angling',future)==future)
            assert(future.secretHistory.keep and not AzerothFieldbookAccountDB.sections.angling)
            assert(not AzerothFieldbookAccountDB.sectionImports.angling[1])
        ''')

if __name__=='__main__':
    unittest.main()
