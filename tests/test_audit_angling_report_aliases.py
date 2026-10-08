"""R1: complete local contributor references and bounded historical wire aliases.

The 33 real Context/RecordCatch/import setup comes from the independent R1
diagnostic. These assertions require successful export, not the old defect.
"""
import unittest

from angling_test_harness import new_angling
from test_account_sections import account
from test_player_names_preservation import full_client


class ContributorReportTests(unittest.TestCase):
    def test_annals_and_lore_use_complete_local_references(self):
        lua = full_client()
        account(lua)
        lua.execute(r'''
            local originals,keys={},{}
            local shared
            for owner=1,33 do
                local db={origin='no-catches-'..owner};originals[owner]=db
                local journal=ns.CreateAnglingJournal(db)
                local e=journal:Ensure('item',{name='Common fish',itemID=999},'recorded',100)
                keys[owner]=e.origin.key
                ns.Angling.AddLegacyKey(e.origin,'prior-'..owner)
                scope(owner);shared=ns.SelectSectionStorage('angling',db)
            end
            local journal=ns.CreateAnglingJournal(shared);local e=shared.items[next(shared.items)]
            local shell=ns.CreateFieldbookShell()
            shell:RegisterSection('angling',{title='Source',build=function() end})
            local sources={angling={journal=journal,Select=function() end}}
            local annals=ns.InitializeAnnals(shell,sources)
            local lore={references=ns.CreateLoreReferences(ns.CreateLoreJournal({}),shell)}
            ns.RegisterLoreReferences(lore,shell,sources)
            for owner=1,33 do
                assert(annals:Resolve({section='angling',key='item:1',identity=keys[owner]})==e)
                assert(not lore.references:Resolve({section='angling',id=keys[owner]}).missing)
                assert(journal:Reference('prior-'..owner)==e)
            end
            local r=assert(ns.AnglingReports.Build(journal,e.id,'personal'))
            assert(ns.AnglingReports.Encode(r) and #r.records[1].origin.legacyKeys==2)
            local clone=ns.Angling.Copy(e);clone.id='duplicate';shared.items.duplicate=clone
            assert(not annals:Resolve({section='angling',key=e.id,identity=keys[1]}))
            assert(lore.references:Resolve({section='angling',id=keys[33]}).missing)
            shared.items.duplicate=nil;e.removed=true
            assert(not annals:Resolve({section='angling',key=e.id,identity=keys[33]}))
        ''')

    def test_contributors_and_saved_n4_aliases(self):
        for legacy, same_name in ((False, False), (True, False), (True, True)):
            with self.subTest(saved_n4=legacy, same_name=same_name):
                lua = new_angling()
                account(lua)
                lua.globals().legacy = legacy
                lua.globals().sameName = same_name
                lua.execute(r'''
                    local function serialize(v)
                        if type(v)=='string' then return string.format('%q',v) end
                        if type(v)~='table' then return tostring(v) end
                        local parts={}
                        for k,value in pairs(v) do parts[#parts+1]='['..serialize(k)..']='..serialize(value) end
                        return '{'..table.concat(parts,',')..'}'
                    end
                    local stores,before,refs={},{},{}
                    local shared
                    for owner=1,33 do
                        playerName='Synthetic angler '..(sameName and 1 or owner)
                        local personal={origin='contributor-'..owner};stores[owner]=personal
                        local journal=ns.CreateAnglingJournal(personal)
                        local context=journal:Context(A.CurrentLocation(),{source='open'},'observed',{effective=205})
                        assert(journal:RecordCatch('one',context,{{name='Common fish',itemID=999,quantity=owner}}))
                        refs[owner]={}
                        for _,field in ipairs({'waters','items'}) do
                            local e=personal[field][next(personal[field])]
                            refs[owner][field]=e.origin.key
                            -- Historical aliases need not have a parseable store/ID shape.
                            if owner==1 or not legacy then
                                A.AddLegacyKey(e.origin,'historical-'..owner..'-'..field)
                            end
                        end
                        before[owner]=snapshot(personal)
                        scope(owner,true);shared=ns.SelectSectionStorage('angling',personal)
                        if owner==32 or owner==33 then
                            local selected=ns.CreateAnglingJournal(shared)
                            local id=next(shared.items)
                            local snapshotBefore=snapshot(shared)
                            local report=assert(R.Build(selected,id,'personal'))
                            assert(R.Encode(report) and R.Preview(report))
                            assert(#report.facts==owner and #report.records==2)
                            assert(snapshot(shared)==snapshotBefore,'export/preview changed evidence')
                        end
                    end
                    if legacy then
                        -- Reconstruct the already-saved N4 representation: one mixed
                        -- list, no new local map. Put genuine history AFTER entry 32.
                        for _,field in ipairs({'waters','items'}) do
                            local e=shared[field][next(shared[field])]
                            e.referenceAliases=nil;e.origin.legacyKeys={}
                            for owner=1,33 do A.AddLegacyKey(e.origin,refs[owner][field]) end
                            A.AddLegacyKey(e.origin,'historical-1-'..field)
                            assert(#e.origin.legacyKeys==34)
                        end
                    end
                    -- Actual serialization/reconstruction, without retained source
                    -- stores attached to the account or selected character globals.
                    local encoded=serialize(AzerothFieldbookAccountDB)
                    AzerothFieldbookAccountDB=assert(loadstring('return '..encoded))()
                    shared=AzerothFieldbookAccountDB.sections.angling
                    local selected=ns.CreateAnglingJournal(shared)
                    local fish=shared.items[next(shared.items)]
                    assert(size(shared.aggregates)==33 and #shared.history==33)
                    assert(selected:Summary(fish).events==33)
                    local quantity=0;local sources={}
                    for _,fact in pairs(shared.aggregates) do
                        assert(fact.events==1 and fact.method=='observed')
                        sources[fact.origin.source]=true
                        for _,item in pairs(fact.items) do quantity=quantity+item.quantity end
                    end
                    assert(size(sources)==(sameName and 1 or 33) and quantity==561)
                    for owner=1,33 do
                        assert(snapshot(stores[owner])==before[owner],'personal original was changed')
                        for _,field in ipairs({'waters','items'}) do
                            local e=shared[field][next(shared[field])]
                            assert(selected:Reference(refs[owner][field])==e)
                            if owner==1 or not legacy then
                                assert(selected:Reference('historical-'..owner..'-'..field)==e)
                            end
                        end
                        scope(owner,true)
                        assert(ns.SelectSectionStorage('angling',stores[owner])==shared)
                        scope(owner,false)
                        local personal=ns.CreateAnglingJournal(ns.SelectSectionStorage('angling',stores[owner]))
                        assert(personal:Reference(fish.origin.key)==stores[owner].items[next(stores[owner].items)])
                    end
                    local unchanged=snapshot(shared)
                    local report=assert(R.Build(selected,fish.id,'personal'))
                    for _,r in ipairs(report.records) do
                        assert(#r.origin.legacyKeys==2,'wire origin included contributor navigation aliases')
                        assert(r.origin.legacyKeys[2]=='historical-1-'..(r.kind=='item' and 'items' or 'waters'))
                    end
                    assert(R.Preview(report) and R.Encode(report))
                    assert(snapshot(shared)==unchanged)
                    assert(snapshot(ns.CreateAnglingJournal(shared).db)==unchanged,'reload is not idempotent')

                    -- A genuine historical report must reconcile on both sides of
                    -- forwarding and reconstruction, without promoting catch facts.
                    local old=A.Copy(report)
                    for _,r in ipairs(old.records) do
                        r.origin.key=r.origin.legacyKeys[2];r.origin.legacyKeys=nil;r.origin.source='Historical courier'
                    end
                    local receiver=ns.CreateAnglingJournal({})
                    assert(import(receiver,old));assert(import(receiver,report));assert(import(receiver,report))
                    assert(import(receiver,old))
                    local received=receiver:List('catches')[1]
                    assert(receiver:Summary(received).reportedEvents==33 and receiver:Summary(received).events==0)
                    assert(size(receiver.db.reported)==33 and size(receiver.db.aggregates)==0)
                    local receiverBefore=snapshot(receiver.db)
                    local forwarded=assert(R.Build(receiver,received.id,'reported'))
                    assert(snapshot(receiver.db)==receiverBefore)
                    for _,r in ipairs(forwarded.records) do
                        assert(r.origin.source=='Synthetic angler 1' and #r.origin.legacyKeys==2)
                    end
                    local third=ns.CreateAnglingJournal({})
                    assert(import(third,old));assert(import(third,forwarded))
                    third=ns.CreateAnglingJournal(assert(loadstring('return '..serialize(third.db)))())
                    assert(import(third,report));assert(import(third,forwarded));assert(import(third,old))
                    assert(size(third.db.reported)==33 and third:Summary(third:List('catches')[1]).reportedEvents==33)
                    local roundTrip=assert(R.Build(third,third:List('catches')[1].id,'reported'))
                    assert(import(receiver,roundTrip))
                    assert(size(receiver.db.reported)==33 and receiver:Summary(received).reportedEvents==33)

                    local clone=A.Copy(fish);clone.id='duplicate';shared.items.duplicate=clone
                    assert(not selected:Reference(refs[33].items),'ambiguous ownership must remain unavailable')
                    shared.items.duplicate=nil;fish.removed=true
                    assert(not selected:Reference(refs[33].items))
                ''')

    def test_unproven_aliases_and_wire_capacity_are_not_discarded(self):
        lua = new_angling()
        lua.execute(r'''
            observe('one');local id=next(saved.items);local fish=j:Get(id)
            for i=1,31 do A.AddLegacyKey(fish.origin,'historical-'..i) end
            j=ns.CreateAnglingJournal(saved)
            local good=assert(R.Build(j,id,'personal'));assert(R.Encode(good))
            assert(#fish.origin.legacyKeys==32)
            A.AddLegacyKey(fish.origin,'unclassified-history')
            local before=snapshot(saved)
            j=ns.CreateAnglingJournal(saved)
            assert(snapshot(saved)==before,'unproven alias was removed to make a report fit')
            assert(not R.Build(j,id,'personal'))
            local bad=A.Copy(good);bad.records[1].origin.legacyKeys={}
            for i=1,33 do bad.records[1].origin.legacyKeys[i]='alias-'..i end
            assert(not R.Normalize(bad) and not R.Encode(bad),'wire alias limit must remain 32')
            bad=A.Copy(good);bad.records[1].origin.referenceAliases={private=true}
            assert(not R.Normalize(bad),'local reference map is not a protocol field')
            assert(R.MAX_RECORDS==120 and R.MAX_FACTS==128 and R.MAX_BYTES==98304)
        ''')


if __name__ == '__main__':
    unittest.main()
