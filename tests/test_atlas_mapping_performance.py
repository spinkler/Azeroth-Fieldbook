"""Atlas repair semantics and deterministic traversal counts (not native timing)."""
import unittest
from atlas_test_harness import new_atlas
from test_account_sections import account


class AtlasMappingTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_atlas()
        account(self.lua)
        self.lua.execute('''
            for i=1,100 do
                local name,value=debug.getupvalue(ns.SelectSectionStorage,i)
                if name=='atlasMappings' then repair=value;break end
            end
            assert(repair)
            function record(reference,created,legacy)
                return {reference=reference,created=created,referenceLegacy=legacy,name=reference}
            end
            function fixture(first)
                a={atlasFirstImport=first,sectionImports={atlas={[1]=true,[2]=true}}}
                p={records={},loreAliases={}};s={records={},expeditions={},loreAliases={}}
                messages={};DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
            end
            function mapped(ref) return a.atlasReferenceMaps[2][ref] end
            function issue(ref) return a.atlasReferenceIssues[2][ref] end
            missing='No saved Atlas destination mapping survives in this scope.'
            ambiguous='Multiple Atlas records share the surviving migration stamp; the original ID mapping was not saved.'
        ''')

    def test_exact_ids_win_collisions_and_never_fall_back_when_missing(self):
        self.lua.execute('''
            fixture(1)
            p.records.x=record('mine',100,true);p.records.y=record('second',100,true)
            p.records.z=record('deleted',100,true);p.records.keep=record('unchanged',100,true)
            s.records.x=record('foreign',100,true)
            s.records['char2:1']=record('imported',100,true)
            s.records.y=record('second-import',100,true)
            s.records.lookalike=record('deleted',100,true)
            s.records.duplicate=record('mine',100,true)
            p.loreAliases.old='mine';s.loreAliases.old='foreign'
            a.atlasReferenceMaps={[2]={unchanged=false}}
            a.atlasReferenceIssues={[2]={unchanged='preserved issue'}}
            repair(a,p,s,2,{x='char2:1',z='char2:missing'})
            assert(mapped('mine')=='imported' and mapped('second')=='second-import')
            assert(mapped('deleted')==false and issue('deleted')==missing)
            assert(mapped('unchanged')==false and issue('unchanged')=='preserved issue')
            assert(mapped('old')=='imported','exact imports do not use legacy alias conflict rules')
            assert(#messages==1 and messages[1]=='AFB: deleted: '..missing..' Reference retained.')
            assert(a.atlasReferenceRepairs[2])
            s.records['char2:missing']=record('late',100,true)
            repair(a,p,s,2,{z='char2:missing'})
            assert(mapped('deleted')==false and #messages==1,'persisted repair is one-time')
        ''')

    def test_durable_reference_priority_including_duplicate_identities(self):
        self.lua.execute('''
            for _,duplicate in ipairs({false,true}) do
                fixture(1)
                p.records.x=record('durable',100,true);p.records.y=record('same-second',100,true)
                s.records['char2:1']=record('timestamp-match',100,true)
                s.records.foreign=record('durable',999,false)
                if duplicate then s.records['char3:1']=record('durable',100,true) end
                repair(a,p,s,2)
                if duplicate then assert(mapped('durable')==false and issue('durable')==ambiguous)
                else assert(mapped('durable')=='durable') end
                assert(mapped('same-second')==false and issue('same-second')==ambiguous)
            end
        ''')

    def test_legacy_owner_and_both_sides_of_same_second_ambiguity(self):
        self.lua.execute('''
            fixture(1)
            p.records.x=record('unique',100,true)
            p.records.y=record('local-twin-a',200,true);p.records.z=record('local-twin-b',200,false)
            p.records.multi=record('shared-twins',300,true)
            p.records.new=record('not-legacy',400,false)
            p.records.missing=record('missing',500,true)
            p.records.bad=record('string-stamp','600',true)
            s.records.x=record('first-owner',100,true)
            s.records['char3:1']=record('wrong-owner',100,true)
            s.records['char2:1']=record('owned',100,true)
            s.records['char2:2']=record('only-surviving-twin',200,true)
            s.records['char2:3']=record('shared-a',300,true)
            s.records['char2:4']=record('shared-b',300,true)
            s.records['char2:5']=record('legacy-for-modern',400,true)
            s.records['char2:6']=record('modern-for-legacy',500,false)
            s.records['char2:7']=record('string-match','600',true)
            repair(a,p,s,2)
            assert(mapped('unique')=='owned')
            for _,ref in ipairs({'local-twin-a','shared-twins'}) do
                assert(mapped(ref)==false and issue(ref)==ambiguous)
            end
            for _,ref in ipairs({'local-twin-b','not-legacy','missing','string-stamp'}) do
                assert(mapped(ref)==false and issue(ref)==missing)
            end
        ''')

    def test_first_owner_uses_original_ids_and_combines_owned_candidates(self):
        self.lua.execute('''
            fixture(2)
            p.records.x=record('local-x',100,true);p.records.y=record('local-y',100,true)
            s.records.x=record('shared-x',100,true);s.records.y=record('shared-y',100,true)
            s.records.z=record('unrelated-same-second',100,true)
            repair(a,p,s,2)
            assert(mapped('local-x')=='shared-x' and mapped('local-y')=='shared-y')
            fixture(2)
            p.records.x=record('local-x',100,true)
            s.records.x=record('shared-x',100,true);s.records['char2:1']=record('qualified',100,true)
            repair(a,p,s,2)
            assert(mapped('local-x')==false and issue('local-x')==ambiguous)
        ''')

    def test_first_owner_recovery_requires_unique_ownership_evidence(self):
        self.lua.execute('''
            for _,field in ipairs({'records','expeditions'}) do
                fixture(nil)
                p.records.x=record('local',100,true);s.records.x=record('shared',100,true)
                s[field]['char1:9']=record('other',999,true)
                repair(a,p,s,2)
                assert(a.atlasFirstImport==2 and mapped('local')=='shared')
            end
            fixture(nil)
            p.records.x=record('local',100,true);s.records.x=record('shared',100,true)
            repair(a,p,s,2)
            assert(not a.atlasFirstImport and mapped('local')==false and issue('local')==missing)
            -- An exact import still recovers the missing historical first-owner marker.
            fixture(nil);s.expeditions['char1:9']={}
            p.records.x=record('local',100,true);s.records.x=record('shared',100,true)
            repair(a,p,s,2,{})
            assert(a.atlasFirstImport==2 and mapped('local')=='shared')
        ''')

    def test_legacy_alias_conflicts_and_existing_mappings_are_preserved(self):
        self.lua.execute('''
            fixture(1)
            p.records.x=record('mine',100,true);s.records['char2:1']=record('shared',100,true)
            p.loreAliases['x@:100']='mine';s.loreAliases['x@:100']='foreign'
            p.loreAliases.safe='mine';s.loreAliases.safe='shared';p.loreAliases.absent='deleted'
            p.loreAliases.saved='mine'
            a.atlasReferenceMaps={[2]={saved='persisted',old=false}}
            repair(a,p,s,2)
            assert(mapped('mine')=='shared' and mapped('safe')=='shared')
            assert(mapped('x@:100')==false and issue('x@:100')==
                'This old Atlas key could refer to different local and account discoveries; its saved scope is unknown.')
            assert(mapped('absent')==false and mapped('saved')=='persisted' and mapped('old')==false)
            assert(#messages==1)
        ''')

    def test_record_traversals_are_linear_and_reload_does_no_work(self):
        for exact in (True, False):
            for count in (64, 128):
                with self.subTest(exact=exact, count=count):
                    self.lua.globals().count = count
                    self.lua.globals().exact = exact
                    self.lua.execute('''
                        fixture(1);local ids=exact and {} or nil
                        for i=1,count do
                            local id='p'..i;local dest='char2:'..i
                            p.records[id]=record('local-'..i,i,true)
                            s.records[dest]=record('shared-'..i,i,true)
                            if ids then ids[id]=dest end
                        end
                        local original=pairs;visits={personal=0,shared=0}
                        pairs=function(t)
                            local iter,state,key=original(t)
                            local kind=t==p.records and 'personal' or t==s.records and 'shared'
                            if not kind then return iter,state,key end
                            return function(state,key)
                                local k,v=iter(state,key)
                                if k~=nil then visits[kind]=visits[kind]+1 end
                                return k,v
                            end,state,key
                        end
                        repair(a,p,s,2,ids)
                        pairs=original
                        for i=1,count do assert(mapped('local-'..i)=='shared-'..i) end
                        print(string.format('Atlas %s N=%d: personal=%d shared=%d record visits',
                            exact and 'exact' or 'legacy',count,visits.personal,visits.shared))
                        assert(visits.shared==(exact and 0 or count))
                        assert(visits.personal<=(exact and count or 2*count))
                        -- Reload marker must short-circuit before traversing either store.
                        pairs=function() error('completed repair traversed a table') end
                        repair(a,p,s,2,ids)
                        pairs=original
                    ''')

    def test_deleted_destination_and_false_mapping_survive_serialized_reload(self):
        self.lua.execute('''
            fixture(1)
            p.records.x=record('mine',100,true);p.records.x.id='x'
            p.records.y=record('missing',100,true)
            s.records['char2:1']=record('imported',100,true)
            p.loreAliases['x@:100']='mine'
            repair(a,p,s,2,{x='char2:1',y='char2:2'})
            a.sections={atlas=s};AzerothFieldbookAccountDB=a;scope(2)
            assert(ns.ResolveAtlasLoreReference({saved=s,records=s.records},'mine')=='char2:1')
            s.records['char2:1']=nil
            function savedText(value)
                if type(value)=='string' then return string.format('%q',value) end
                if type(value)~='table' then return tostring(value) end
                local out={}
                for k,v in pairs(value) do out[#out+1]='['..savedText(k)..']='..savedText(v) end
                return '{'..table.concat(out,',')..'}'
            end
        ''')
        saved = self.lua.eval("'a='..savedText(a)..';p='..savedText(p)")
        reloaded = new_atlas()
        account(reloaded)
        reloaded.execute(saved)
        reloaded.execute('''
            AzerothFieldbookAccountDB=a;scope(2)
            local s=a.sections.atlas
            -- Same IDs and timestamps now belong to replacement discoveries.
            s.records['char2:1']={id='char2:1',reference='replacement',created=100}
            s.records['char2:2']={id='char2:2',reference='late',created=100}
            DEFAULT_CHAT_FRAME={AddMessage=function() error('repair ran after reload') end}
            assert(ns.SelectSectionStorage('atlas',p)==s)
            local map=a.atlasReferenceMaps[2]
            assert(a.atlasReferenceRepairs[2] and map.mine=='imported' and map.missing==false)
            assert(a.atlasReferenceIssues[2].missing=='No saved Atlas destination mapping survives in this scope.')
            local journal={saved=s,records=s.records}
            assert(not ns.ResolveAtlasLoreReference(journal,'mine'))
            assert(not ns.ResolveAtlasLoreReference(journal,'x@:100'))
            assert(not ns.ResolveAtlasLoreReference(journal,'missing'))
            scope(2,false)
            assert(ns.ResolveAtlasLoreReference({saved=p,records=p.records},'mine')=='x',
                'the retained personal original remains available after account deletion')
        ''')


if __name__ == '__main__':
    unittest.main()
