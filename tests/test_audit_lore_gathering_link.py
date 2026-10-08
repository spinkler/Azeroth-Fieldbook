"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from test_gathering import client
from ui_test_harness import ROOT
from test_account_sections import account
lua=client()
for name in ('LoreJournal.lua','LoreReports.lua','LoreReferences.lua','LoreIntegration.lua'):
    lua.execute((ROOT/name).read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
account(lua)
lua.execute(r'''
local first,second,archive={},{},{}
local a=ns.CreateGatheringJournal(first);local b=ns.CreateGatheringJournal(second)
a:Discover('herb','Peacebloom',200,'Elwynn')
b:Discover('herb','Peacebloom',100,'Elwynn')
scope(1,true)
local shared=ns.CreateGatheringJournal(ns.SelectSectionStorage('gathering',first))
local lore=ns.CreateLoreJournal(ns.SelectSectionStorage('lore',archive))
local e=assert(lore:Create('mystery',{title='Question'}))
local function refs(l,f)
 local shell={ShowSection=function() return true end}
 local c={references=ns.CreateLoreReferences(l,shell)}
 ns.RegisterLoreReferences(c,shell,{gathering={journal=f,Select=function() end}})
 return c.references
end
local r=refs(lore,shared);local link
for _,row in ipairs(r:List('Peacebloom')) do
 link=assert(lore:AddLink(e.id,{section=row.section,id=row.key,label=row.name}))
end
assert(link)
assert(not r:Resolve(link).missing, 'Precondition: account link resolves before another import')
scope(2,true)
shared=ns.CreateGatheringJournal(ns.SelectSectionStorage('gathering',second))
r=refs(lore,shared)
assert(not r:Resolve(link).missing, 'Earlier imports must retain the link')
assert(shared.entries['herb:peacebloom'].firstSeen==100, 'Imported target remains present with merged earliest time')
assert(first.entries['herb:peacebloom'].firstSeen==200, 'Retained character data remains intact')
for _,row in ipairs(r:List('Peacebloom')) do print('same target present='..row.name..'; actual ref='..row.key) end
''')
