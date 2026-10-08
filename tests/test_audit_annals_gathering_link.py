"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from test_player_names_preservation import full_client
from test_account_sections import account

lua = full_client()
account(lua)
lua.execute(r'''
    local personal,other={},{ }
    ns.CreateGatheringJournal(other):Discover('herb','Peacebloom',100,'Elwynn')
    scope(1,true)
    local shared=ns.CreateGatheringJournal(ns.SelectSectionStorage('gathering',personal))
    local shell=ns.CreateFieldbookShell()
    shell:RegisterSection('gathering',{title='Gathering',build=function() end})
    AzerothFieldbookAnnalsDB={}
    local c=ns.InitializeAnnals(shell,{gathering={journal=shared,Select=function() end}})
    local id=shared:Discover('herb','Peacebloom',200,'Elwynn')
    local event=c.journal.db.events[1]
    assert(event.kind=='discovery' and event.link.section=='gathering')
    assert(event.link.identity==shared.entries[id].reference and shared.entries[id].firstSeen==200)
    assert(c:Resolve(event.link)==shared.entries[id], 'precondition: original link must resolve correctly')
    scope(2,true)
    ns.SelectSectionStorage('gathering',other)
    scope(1,true)
    shared=ns.CreateGatheringJournal(ns.SelectSectionStorage('gathering',personal))
    shell=ns.CreateFieldbookShell()
    shell:RegisterSection('gathering',{title='Gathering',build=function() end})
    c=ns.InitializeAnnals(shell,{gathering={journal=shared,Select=function() end}})
    assert(shared.entries[id] and shared.entries[id].firstSeen==100, 'precondition: supported import must keep the same type and earlier firstSeen')
    assert(event.link.key==id and event.link.identity==shared.entries[id].reference)
    assert(#c.journal.events==1 and c.journal.db.events[1]==event, 'historical discovery must remain intact')
    assert(c:Resolve(event.link)==shared.entries[id], 'Earlier imports must preserve the original event target')
''')
