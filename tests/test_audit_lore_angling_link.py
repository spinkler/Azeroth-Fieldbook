"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from angling_test_harness import new_angling
from ui_test_harness import ROOT
from test_account_sections import account
lua=new_angling()
for name in ('LoreJournal.lua','LoreReports.lua','LoreReferences.lua','LoreIntegration.lua'):
    lua.execute((ROOT/name).read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
account(lua)
lua.execute(r'''
local fishA,fishB,loreA,loreB={},{},{},{}
local a=ns.CreateAnglingJournal(fishA);local b=ns.CreateAnglingJournal(fishB)
local one=assert(a:Remember({name='Pier A',location=ns.Angling.CurrentLocation()}))
local two=assert(b:Remember({name='Pier B',location=ns.Angling.CurrentLocation()}))
local la=ns.CreateLoreJournal(loreA);local lb=ns.CreateLoreJournal(loreB)
local e=assert(lb:Create('mystery',{title='Question about Pier B'}))
local function refs(l,f)
 local shell={ShowSection=function() return true end}
 local c={references=ns.CreateLoreReferences(l,shell)}
 ns.RegisterLoreReferences(c,shell,{angling={journal=f,Select=function() end}})
 return c.references
end
local r=refs(lb,b)
local link
for _,row in ipairs(r:List('Pier B')) do
 if row.section=='angling' then link=assert(lb:AddLink(e.id,{section=row.section,id=row.key,label=row.name})) end
end
assert(link)
assert(not r:Resolve(link).missing, 'Precondition: local link must resolve')
scope(1,true)
ns.SelectSectionStorage('angling',fishA);ns.SelectSectionStorage('lore',loreA)
scope(2,true)
local sharedFish=ns.CreateAnglingJournal(ns.SelectSectionStorage('angling',fishB))
local sharedLore=ns.CreateLoreJournal(ns.SelectSectionStorage('lore',loreB))
local imported=sharedLore:List()[1]
local sr=refs(sharedLore,sharedFish)
local current=sr:Resolve(imported.links[1])
assert(imported.title=='Question about Pier B' and #imported.links==1)
assert(not current.missing, 'Imported Angling link must resolve')
local found=false
for _,spot in pairs(sharedFish.db.spots) do if spot.name=='Pier B' then found=true end end
assert(found, 'Precondition: actual imported Angling destination remains present')
for _,row in ipairs(sr:List('Pier B')) do if row.section=='angling' then print('account target present='..row.name..'; actual ref='..row.key) end end
scope(2,false)
local restoredFish=ns.CreateAnglingJournal(ns.SelectSectionStorage('angling',fishB))
local restoredLore=ns.CreateLoreJournal(ns.SelectSectionStorage('lore',loreB))
assert(not refs(restoredLore,restoredFish):Resolve(restoredLore:List()[1].links[1]).missing, 'Retained local link must still work')
''')
