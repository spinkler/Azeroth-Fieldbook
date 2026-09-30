"""Whole-save limits must accommodate two nearly full, real Lore archives."""
import unittest
from test_fieldbook_backups import client


class WholeBackupLimitsTests(unittest.TestCase):
    def test_two_near_capacity_lore_archives_and_portable_limits(self):
        lua=client(account=True)
        lua.execute(r'''
            local chunk=string.rep('x',131072)
            for _,db in ipairs({AzerothFieldbookLoreDB,AzerothFieldbookAccountDB.sections.lore}) do
                local j=ns.CreateLoreJournal(db)
                for i=1,8 do
                    local e=assert(j:Create('writing',{title='Large writing '..i}))
                    for p=1,31 do
                        e.pages[p]={number=p,raw=chunk,method='manual',origin='manual',personallyViewed=false}
                    end
                    assert(ns.Lore.ValidateEntry(e,e.id))
                end
                assert(j:ArchiveBytes()>31*1024*1024 and j:ArchiveBytes()<ns.Lore.MAX_ARCHIVE_BYTES)
            end
            local beforeAccount=AzerothFieldbookAccountDB;local beforeLocal=AzerothFieldbookLoreDB
            local wire=assert(B.Capture())
            assert(#wire>62*1024*1024 and #wire<B.MAX_BYTES)
            local value=assert(B.Decode(wire));assert(B.CanRestore(value))
            for _,db in ipairs({value.stores.AzerothFieldbookLoreDB,value.stores.AzerothFieldbookAccountDB.sections.lore}) do
                local j=ns.CreateLoreJournal(db)
                assert(j.invalid==0 and ns.Lore.Count(j.entries)==8)
                for _,e in pairs(j.entries) do assert(e.pages[31].raw==chunk) end
            end
            assert(AzerothFieldbookAccountDB==beforeAccount and AzerothFieldbookLoreDB==beforeLocal)
            -- Each safeguard must fail closed, including table-only overhead.
            wire=nil;value=nil;collectgarbage('collect')
            local bytes,nodes,depth=B.MAX_BYTES,B.MAX_NODES,B.MAX_DEPTH
            B.MAX_BYTES=1024;assert(not B.Create());assert(AzerothFieldbookBackupDB==nil)
            B.MAX_BYTES=bytes;B.MAX_NODES=20;assert(not B.Create());assert(AzerothFieldbookBackupDB==nil)
            B.MAX_NODES=nodes;B.MAX_DEPTH=2;assert(not B.Create());assert(AzerothFieldbookBackupDB==nil)
            B.MAX_DEPTH=depth
        ''')


if __name__=='__main__':
    unittest.main()
