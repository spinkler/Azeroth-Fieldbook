"""External report arrays stay strict without reinterpreting keyed local pages."""
import unittest
from ui_test_harness import new_ui_client


class LoreReportListTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_ui_client(['AtlasJournal.lua', 'LoreJournal.lua', 'LoreReports.lua'])
        self.lua.execute(r'''
            L=ns.Lore;R=ns.LoreReports
            function literal(v)
                if type(v)=='string' then return 's'..#v..':'..v end
                if type(v)=='number' then local s=tostring(v);return 'n'..#s..':'..s end
                if type(v)=='boolean' then return v and 'b1' or 'b0' end
                local keys={};for k in pairs(v) do keys[#keys+1]=k end
                table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
                local out={'t'..#keys..':'}
                for _,k in ipairs(keys) do out[#out+1]=literal(k);out[#out+1]=literal(v[k]) end
                return table.concat(out)
            end
            source=ns.CreateLoreJournal({});entry=assert(source:Create('writing',{title='Source'}))
            recipient=ns.CreateLoreJournal({});assert(recipient:Create('mystery',{title='Existing entry',notes='KEEP'}))
            function report() return assert(R.Build(source,entry.id)) end
            function listValue(kind,k)
                if kind=='pages' then return {number=k,raw='Source '..k,method='displayed',origin='captured',nature='source',source='Witness',at=now}
                elseif kind=='passages' then return {raw='Passage '..k,method='displayed',origin='captured',nature='source',source='Witness',at=now}
                elseif kind=='locations' then return {meaning='observation',zone='Zone',source='Witness',at=now}
                elseif kind=='references' then return {section='atlas',label='Reference '..k}
                else return 'tag'..k end
            end
            function setList(r,kind,keys)
                local values={};for _,k in ipairs(keys) do values[k]=listValue(kind,type(k)=='number' and math.max(1,k) or 1) end
                if kind=='tags' then r.annotations.tags=values else r[kind]=values end
                return values
            end
        ''')

    def test_each_sparse_wire_list_is_rejected_before_ticket_or_mutation(self):
        for field in ('pages', 'passages', 'locations', 'references', 'tags'):
            with self.subTest(field=field):
                self.lua.globals().field = field
                self.lua.execute(r'''
                    for _,keys in ipairs({{1,2,4,6},{2},{1,3},{0,1},{1,'2'},{1,999}}) do
                        local r=report();local values=setList(r,field,keys)
                        assert(not L.Array(values,field=='tags' and 32 or 256),'fixture must be invalid')
                        local before=literal(recipient.db);local wire='AFBLR1:'..literal(r)
                        local decoded=R.Decode(wire)
                        assert(decoded==nil,'sparse '..field..' was accepted by Decode')
                        assert(R.Normalize(r)==nil,'sparse '..field..' produced a normalized report')
                        local ticket=R.Prepare(wire)
                        assert(ticket==nil,'sparse '..field..' produced an acceptance ticket')
                        assert(not R.Accept(recipient,ticket),'invalid report reached acceptance')
                        assert(literal(recipient.db)==before,'invalid report changed recipient storage')
                    end
                ''')

    def test_valid_empty_contiguous_and_boundary_lists_roundtrip(self):
        self.lua.execute(r'''
            for _,kind in ipairs({'pages','passages','locations','references','tags'}) do
                local limit=kind=='tags' and 32 or (kind=='pages' or kind=='passages') and 256 or 128
                for _,n in ipairs({0,3,limit}) do
                    local r=report();local keys={};for i=1,n do keys[i]=i end
                    setList(r,kind,keys)
                    local decoded=assert(R.Decode(assert(R.Encode(r))))
                    local values=kind=='tags' and decoded.annotations.tags or decoded[kind]
                    assert(#values==n,'valid report list was shortened')
                    local imported=assert(R.Accept(recipient,assert(R.Prepare(assert(R.Encode(r))))))
                    local stored=imported.reports[#imported.reports]
                    local retained=kind=='tags' and stored.annotations.tags or stored[kind]
                    assert(#retained==n)
                end
            end
        ''')

    def test_older_stored_snapshots_load_but_fresh_version_mismatches_are_rejected(self):
        self.lua.execute(r'''
            metadataVersion='0.16.9'
            local r=report();setList(r,'pages',{1,2,3})
            local wire=assert(R.Encode(r));local e=assert(R.Accept(recipient,assert(R.Prepare(wire,'Courier'))))
            local before=literal(e.reports)
            metadataVersion='0.17.0'
            local reloaded=ns.CreateLoreJournal(recipient.db)
            assert(reloaded:Get(e.id) and literal(reloaded:Get(e.id).reports)==before,'older stored report changed')
            assert(not R.Decode(wire) and not R.Prepare(wire),'fresh version-mismatched report accepted')
        ''')

    def test_malformed_stored_lists_remain_raw_in_invalid_entry_handling(self):
        for field in ('pages', 'passages', 'locations', 'references', 'tags'):
            with self.subTest(field=field):
                self.lua.globals().field = field
                self.lua.execute(r'''
                    local db={};local journal=ns.CreateLoreJournal(db)
                    local r=report();setList(r,field,{1,2,3,4})
                    local e=assert(R.Accept(journal,assert(R.Prepare(assert(R.Encode(r))))))
                    setList(e.reports[1],field,{1,2,4,6})
                    e.notes='PRIVATE ANNOTATION';local original=db.entries[e.id];local before=literal(original)
                    local loaded=ns.CreateLoreJournal(db)
                    assert(loaded.invalid==1 and loaded:Get(e.id)==nil,'malformed stored report was accepted')
                    assert(db.entries[e.id]==original and literal(original)==before,'stored evidence was truncated or deleted')
                    assert(ns.CreateLoreJournal(db).invalid==1 and literal(original)==before,'reload altered invalid evidence')
                ''')

    def test_boolean_keyed_stored_lists_remain_lossless_across_reload(self):
        for field in ('pages', 'passages', 'locations', 'references', 'tags'):
            with self.subTest(field=field):
                self.lua.globals().field = field
                self.lua.execute(r'''
                    local db={};local journal=ns.CreateLoreJournal(db)
                    local r=report();setList(r,field,{1,2})
                    local e=assert(R.Accept(journal,assert(R.Prepare(assert(R.Encode(r)),'Courier'))))
                    local original=db.entries[e.id];local stored=original.reports[1]
                    local values=field=='tags' and stored.annotations.tags or stored[field]
                    local payload=listValue(field,3);values[true]=payload
                    original.notes='PRIVATE ANNOTATION'
                    -- literal visits every key, including boolean keys. L.Copy
                    -- must not construct either the malformed fixture or snapshot.
                    local before=literal(db)
                    local envelope={}
                    for k,v in pairs(stored) do
                        if k~='received' and k~='receivedFrom' then envelope[k]=v end
                    end
                    assert(not R.Normalize(envelope,true),'raw malformed list must be rejected')
                    assert(literal(db)==before,'normalization mutated its input')
                    for reload=1,3 do
                        local loaded=ns.CreateLoreJournal(db)
                        assert(loaded.invalid==1 and loaded:Get(e.id)==nil,
                            'boolean-keyed '..field..' was exposed as valid stored evidence')
                        assert(db.entries[e.id]==original and original.reports[1]==stored)
                        assert((field=='tags' and stored.annotations.tags or stored[field])==values)
                        assert(values[true]==payload and literal(db)==before,
                            'reload shortened or rewrote boolean-keyed '..field)
                    end
                ''')

    def test_keyed_internal_pages_are_not_report_arrays(self):
        self.lua.execute(r'''
            local e=assert(source:CapturePage({sessionID='partial',title='Partial'},
                {number=4,raw='Only page four',last=true,method='displayed'}))
            assert(e.pages[4] and e.pages[1]==nil)
            local reloaded=ns.CreateLoreJournal(source.db)
            assert(reloaded:Get(e.id).pages[4].raw=='Only page four')
            local r=assert(R.Build(reloaded,e.id));assert(#r.pages==1 and r.pages[1].number==4)
            assert(R.Decode(assert(R.Encode(r))).pages[1].raw=='Only page four')
        ''')


if __name__ == '__main__':
    unittest.main()
