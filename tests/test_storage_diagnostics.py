"""O2: archive usage uses capture limits without changing preserved material."""
import unittest
from ui_test_harness import new_ui_client
from test_lore_ui import new_lore_ui
from test_player_names_preservation import SUPPORT


class StorageDiagnosticsTests(unittest.TestCase):
    def setUp(self):
        self.lua = new_ui_client(['AtlasJournal.lua', 'LoreJournal.lua'])
        self.lua.execute(SUPPORT)
        self.lua.execute("L=ns.Lore;saved={};j=ns.CreateLoreJournal(saved)")

    def test_empty_small_add_remove_and_no_mutation(self):
        self.lua.execute(r"""
            local before=literal(saved);local revision=j.revision
            local text,detail=j:StorageStatus()
            assert(text=='Archive: 0.00 / 32 MiB' and detail:find('0 / 2000 entry slots',1,true))
            assert(before==literal(saved) and revision==j.revision)
            local e=assert(j:Create('writing',{title='Small archive'}))
            assert(j:AddPassage(e.id,{raw=string.rep('x',20000),source='Source'}))
            before=literal(saved);text,detail=j:StorageStatus()
            assert(text:find('0.01 / 32 MiB',1,true) and detail:find('1 / 2000 entry slots',1,true))
            assert(detail:find(tostring(j:ArchiveBytes())..' / 33554432',1,true))
            assert(before==literal(saved))
            assert(j:Delete(e.id));assert(j:StorageStatus()=='Archive: 0.00 / 32 MiB')
        """)

    def test_near_byte_limit_does_not_round_up_to_full(self):
        self.lua.execute(r"""
            -- Shared immutable Lua strings keep this fixture small. The real
            -- byte traversal counts every page, as capture/import do.
            local e=assert(j:Create('writing',{title='Near capacity'}))
            local chunk=string.rep('x',131072)
            for i=1,255 do e.pages[i]={raw=chunk} end
            e.pages[256]={raw=string.rep('x',131072-j:ArchiveBytes()%131072-1)}
            local text,detail=j:StorageStatus()
            assert(j:ArchiveBytes()==L.MAX_ARCHIVE_BYTES-1)
            assert(text=='Archive: 31.99 / 32 MiB' and detail:find('Near an archive limit.',1,true))
            assert(not detail:find('has been reached',1,true))
            e.pages[256].raw=e.pages[256].raw..'x'
            text,detail=j:StorageStatus()
            assert(text=='Archive: 32.00 / 32 MiB' and detail:find('has been reached',1,true))
        """)

    def test_entry_limit_invalid_and_future_schema_are_truthful(self):
        self.lua.execute(r"""
            local e=assert(j:Create('landmark',{title='An entry'}))
            for i=2,1999 do saved.entries['slot'..i]=e end
            local _,detail=j:StorageStatus()
            assert(detail:find('1999 / 2000 entry slots',1,true) and not detail:find('has been reached',1,true))
            saved.entries.last=e;_,detail=j:StorageStatus();assert(detail:find('has been reached',1,true))
            local invalid={schema=1,entries={bad={title='Preserve me'}}}
            local journal=ns.CreateLoreJournal(invalid);local before=literal(invalid)
            local text;text,detail=journal:StorageStatus()
            assert(text=='Archive: usage incomplete' and detail:find('valid entries only',1,true))
            assert(before==literal(invalid))
            local future={schema=99,entries={keep='uninterpreted'}};before=literal(future)
            journal=ns.CreateLoreJournal(future);text,detail=journal:StorageStatus()
            assert(text=='Archive: read-only' and detail:find('unavailable',1,true))
            assert(before==literal(future))
            ns.InitializationBlocked=true;journal=ns.CreateLoreJournal({})
            assert(journal:StorageStatus()=='Archive: read-only')
        """)

    def test_visible_catalogue_refresh_and_tooltip(self):
        lua=new_lore_ui()
        lua.execute(r"""
            assert(m.capacity:GetText()=='Archive: 0.00 / 32 MiB')
            local e=writing();assert(j:AddPassage(e.id,{raw=string.rep('x',20000),source='Source'}));flush()
            assert(m.capacity:GetText():find('0.01 / 32 MiB',1,true))
            m.capacityHover.scripts.OnEnter(m.capacityHover)
            assert(snapshot(GameTooltip.lines):find('entry slots',1,true))
            j:Delete(e.id);flush();assert(m.capacity:GetText()=='Archive: 0.00 / 32 MiB')
            local requests=0;local status=j.StorageStatus
            function j:StorageStatus() requests=requests+1;return status(self) end
            shell:ShowSection('other');writing();flush()
            assert(requests==0,'hidden journals do not recalculate diagnostics')
            shell:ShowSection('lore');assert(requests>0 and m.capacity:GetText()==j:StorageStatus())
        """)


if __name__ == '__main__':
    unittest.main()
