"""A8: matching prerelease round trips retain exact transfer compatibility."""
from ui_test_harness import new_ui_client,ROOT
from test_lore_reports import MODULES
for version in ('0.36.1','0.36.2-beta','0.36.2-beta.1','0.36.2-alpha','0.36.2+build.1'):
    lua=new_ui_client(MODULES);lua.globals().metadataVersion=version
    lua.execute("""
        local R=ns.LoreReports
        local j=ns.CreateLoreJournal({});local e=assert(j:Create('writing',{title='Test book'}))
        assert(j:AddPassage(e.id,{raw='Test source',nature='source'}))
        local report=assert(R.Build(j,e.id));local wire=assert(R.Encode(report))
        assert(R.Decode(wire));local ticket=assert(R.Prepare(wire))
        local db={};local recipient=ns.CreateLoreJournal(db)
        local imported=assert(R.Accept(recipient,ticket))
        assert(#imported.reports==1)
        recipient=ns.CreateLoreJournal(db)
        local again=assert(R.Prepare(wire))
        R.Accept(recipient,again,imported.id)
        assert(#recipient:Get(imported.id).reports==1)
        metadataVersion='9.9.9';assert(not R.Decode(wire));assert(not R.Prepare(wire))
    """)
for version in ('0.36','0.36.2bad','0.36.2-','0.36.2-beta..1','0.36.2-beta+','0.36.2 beta','0.36.2-beta/1'):
    lua=new_ui_client(MODULES);lua.globals().metadataVersion=version
    lua.execute("local j=ns.CreateLoreJournal({});local e=assert(j:Create('writing',{title='Test'}));assert(not ns.LoreReports.Build(j,e.id))")
print('PASS: A8 stable/beta/numbered beta/alpha/build full round trips, deduplication, mismatches and malformed versions')
