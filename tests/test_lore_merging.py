"""Compatible partial writings consolidate without retiring their references."""
import unittest

from ui_test_harness import new_ui_client


def client():
    lua = new_ui_client(['AtlasJournal.lua', 'LoreJournal.lua', 'LoreReports.lua'])
    lua.execute(r'''
        L=ns.Lore;R=ns.LoreReports
        saved={};j=ns.CreateLoreJournal(saved)
        function historical(id,n,raw,options)
            options=options or {}
            local other=ns.CreateLoreJournal({})
            local e=assert(other:CapturePage({sessionID='old',title=options.title or 'The Guardians of Tirisfal',
                identity=options.identity,locale=options.locale or 'enUS',sourceKind='readable'},
                {number=n,raw=raw or 'Page '..n,first=n==1,last=options.last==true,personallyViewed=options.viewed==true}))
            e=L.Copy(e);e.id=id;e.reference=L.RecordReference(saved,e)
            saved.entries[id]=e;j.entries[id]=e
            return e
        end
        function reload() j=ns.CreateLoreJournal(saved);return j end
        function count() return #j:List({kind='writing'}) end
    ''')
    return lua


class LoreMergingTests(unittest.TestCase):
    def test_reference_ambiguity_distinguishes_records_from_same_target_aliases(self):
        lua = client()
        lua.execute(r'''
            local a=historical('a',1);local b=historical('b',2,nil,{last=true})
            local reference=b.reference
            reload();local merged=j:Get('a')
            assert(j:Reference(reference)==merged)
            saved.aliases['same-target']={target=merged.id,reference=reference}
            assert(j:Reference(reference)==merged,'Multiple aliases to one record remain unambiguous')
            local other=L.Copy(merged);other.id='another-owner';other.reference=reference
            j.entries[other.id]=other
            assert(j:Reference(reference)==nil,'Active record and alias cannot disagree on ownership')
            j.entries[other.id]=nil
            other.reference=merged.reference;j.entries[other.id]=other
            assert(j:Reference(merged.reference)==nil,'Two active records cannot share durable ownership')
            j.entries[other.id]=nil
            assert(j:Reference(reference)==merged and not j:Reference(nil))
        ''')

    def test_three_historical_partials_merge_and_gaps_fill_across_visits(self):
        lua = client()
        lua.execute(r'''
            local ids={'old:1','old:3','old:5'};local refs,keys={},{}
            for i,n in ipairs({1,3,5}) do
                local e=historical(ids[i],n,nil,{last=n==5,viewed=n==3})
                if n==3 then e.variantOf=ids[1] end -- old readers also forked compatible partials
                refs[i]=e.reference;keys[i]=R.Build(j,e.id).sourceKey
            end
            reload();assert(count()==1)
            local merged=j:Get(ids[1]);assert(merged==j:Get(ids[2]) and merged==j:Get(ids[3]))
            assert(table.concat(j:WritingSummary(merged).missing,', ')=='2, 4' and merged.pages[3].personallyViewed)
            for i,id in ipairs(ids) do
                assert(j:Reference(refs[i])==merged and R.Build(j,id).sourceKey==keys[i])
            end
            for _,n in ipairs({2,4}) do
                local e=assert(j:CapturePage({sessionID='visit'..n,title=merged.sourceTitle,locale='enUS',sourceKind='readable'},
                    {number=n,raw='Page '..n,personallyViewed=true}))
                assert(e.id==merged.id)
            end
            assert(j:WritingSummary(merged).complete and count()==1)
            local serial=saved.serial;reload();assert(count()==1 and saved.serial==serial)
        ''')

    def test_conflicting_versions_and_ambiguous_disjoint_pages_stay_separate(self):
        lua = client()
        lua.execute(r'''
            local a=historical('a',1,'Version A')
            local b=historical('b',1,'Version B')
            historical('c',3,'Unattributed continuation')
            reload();assert(count()==3)
            local e=assert(j:CapturePage({sessionID='new',title=a.sourceTitle,locale='enUS',sourceKind='readable'},
                {number=2,raw='Another continuation'}))
            assert(count()==4 and not e.pages[1] and not e.pages[3])
            assert(j:Get(a.id).pages[1].raw=='Version A' and j:Get(b.id).pages[1].raw=='Version B')
        ''')

    def test_different_sources_locales_and_page_boundaries_stay_separate(self):
        lua = client()
        lua.execute(r'''
            historical('a',1,'Beginning',{identity='item:1'})
            historical('b',2,'Continuation',{identity='item:2'})
            historical('c',2,'Fortsetzung',{identity='item:1',locale='deDE'})
            historical('d',1,'Another source',{title='Different writing'})
            historical('e',3,'After the ending',{identity='item:1'})
            j:Get('a').lastPage=1
            reload();assert(count()==5)
        ''')

    def test_annotations_reading_positions_reports_and_extension_metadata_survive(self):
        lua = client()
        lua.execute(r'''
            local a=historical('a',1);local b=historical('b',2,nil,{last=true})
            a.notes='First note';b.notes='Second note';b.description='My description'
            b.extension={source='Other module',value=123}
            saved.state.selected='a';saved.state.reading={a={source='page:1',scroll=12},b={source='page:2',scroll=34}}
            local report=assert(R.Build(j,b.id))
            assert(R.Accept(j,assert(R.Prepare(report)),a.id))
            reload();local e=j:Get('a');assert(count()==1 and j:Get('b')==e)
            local texts={};for _,p in ipairs(e.passages) do texts[p.raw]=p.private end
            assert(e.notes=='First note' and texts['Second note'] and texts['My description'])
            assert(e.reports[1].pages[1].raw=='Page 2')
            assert(saved.aliases.b.metadata.extension.value==123)
            assert(saved.state.reading.a.scroll==12 and saved.state.reading.b.scroll==34 and saved.state.selected=='a')
            assert(j:Update('b',{notes='Updated merged note'}));assert(j:Get('a').notes=='Updated merged note')
        ''')

    def test_alias_deletion_does_not_retarget_old_links_when_book_is_recaptured(self):
        lua = client()
        lua.execute(r'''
            historical('lore:1',1);historical('lore:2',2,nil,{last=true});reload()
            assert(count()==1 and j:Get('lore:1')==j:Get('lore:2'))
            assert(j:Delete('lore:2'));assert(not j:Get('lore:1') and not j:Get('lore:2'))
            local e=assert(j:CapturePage({sessionID='new',title='The Guardians of Tirisfal',locale='enUS',sourceKind='readable'},
                {number=1,raw='Page 1',first=true}))
            assert(e.id~='lore:1' and e.id~='lore:2')
            assert(not j:Get('lore:2'),'A retired identity must not point to a new encounter')
        ''')

    def test_existing_aliases_survive_account_id_remapping(self):
        from test_account_lore_treasure import client as account_client
        lua = account_client()
        lua.execute(r'''
            local personal,treasure={},{}
            local original=init(2,false,personal,treasure)
            local a=writing(original)
            local b=L.Copy(a);b.id='retired:original';b.reference=L.RecordReference(personal,b)
            personal.entries[b.id]=b;original.entries[b.id]=b
            local exportKey=LR.Build(original,b.id).sourceKey;local reference=b.reference
            original:CollapseDuplicateWritings();assert(original:Get(a.id)==original:Get(b.id))
            local foreign=init(1,true,{},{});writing(foreign,'Other source')
            local shared=init(2,true,personal,treasure)
            local found
            for id,alias in pairs(shared.db.aliases) do if alias.reference==reference then
                found=shared:Get(id)
                assert(LR.Build(shared,id).sourceKey==exportKey and id~=b.id)
            end end
            assert(found and shared:Reference(reference)==found)
            assert(original:Get(b.id)==a,'Account import must leave the character archive intact')
        ''')

    def test_annals_links_and_whole_backup_resolve_merged_identities(self):
        from test_player_names_preservation import full_client
        lua = full_client()
        lua.execute(r'''
            local L,R=ns.Lore,ns.LoreReports
            local source=ns.CreateLoreJournal({})
            local a=assert(source:CapturePage({sessionID='old',title='Merged book',locale='enUS'},
                {number=1,raw='First page',first=true}))
            local b=L.Copy(a);b.id='z:former';b.reference=L.RecordReference(source.db,b)
            b.legacyAnnalsIdentity=tostring(b.created)
            b.pages={[2]=assert(L.Page({number=2,raw='Second page',origin='captured',last=true}))}
            b.firstPage=nil;b.lastPage=2
            source.db.entries[b.id]=b;source.entries[b.id]=b
            local exportKey=R.Build(source,b.id).sourceKey
            source=ns.CreateLoreJournal(source.db);assert(source:Get(a.id)==source:Get(b.id))
            local shell=ns.CreateFieldbookShell()
            shell:RegisterSection('lore',{title='Lore',build=function() end})
            local c=ns.InitializeAnnals(shell,{lore={journal=source}})
            assert(c:Resolve({section='lore',key=b.id,identity=b.reference})==source:Get(a.id))
            assert(c:Resolve({section='lore',key=b.id,identity=b.legacyAnnalsIdentity})==source:Get(a.id))
            AzerothFieldbookLoreDB=source.db
            local B=ns.FieldbookBackups
            local wire=assert(B.Capture());local decoded=assert(B.Decode(wire));assert(B.CanRestore(decoded))
            local restored=ns.CreateLoreJournal(decoded.stores.AzerothFieldbookLoreDB)
            assert(restored:Get(b.id)==restored:Get(a.id) and R.Build(restored,b.id).sourceKey==exportKey)
        ''')


if __name__ == '__main__':
    unittest.main()
