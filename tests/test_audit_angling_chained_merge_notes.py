"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from angling_test_harness import new_angling

lua = new_angling(ui=True)
lua.execute(r'''
local function mergeThroughUI(from,into)
    c:Select(from.id)
    c:OpenLinks('merge')
    local panel=c.panels.links
    for _,row in ipairs(panel.rows) do
        if row.data and row.data.id==into.id then
            assert(row:IsShown())
            row.scripts.OnClick(row)
            assert(c:State().selected==into.id)
            return
        end
    end
    error('Expected compatible merge destination was unavailable.')
end
local alpha=spot('Alpha pier')
local bravo=spot('Bravo pier')
local charlie=spot('Charlie pier')
local alphaNote='Alpha evidence: submerged supply chest'
local bravoNote='Bravo evidence: fish after dawn'
local charlieNote='Charlie evidence: bring a lantern'
assert(j:Edit(alpha.id,alpha.name,alphaNote,false))
assert(j:Edit(bravo.id,bravo.name,bravoNote,false))
assert(j:Edit(charlie.id,charlie.name,charlieNote,false))
observe('alpha-catch','unclassified',nil,alpha.id)
observe('bravo-catch','unclassified',nil,bravo.id)
observe('charlie-catch','unclassified',nil,charlie.id)

mergeThroughUI(alpha,bravo)
local firstDetail=table.concat(c:Details(bravo),'\n')
assert(firstDetail:find(alphaNote,1,true) and firstDetail:find(bravoNote,1,true))
assert(j.db.merged[alpha.id].note==alphaNote)
assert(j:Summary(bravo).events==2)

mergeThroughUI(bravo,charlie)
assert(A.Count(j.db.spots)==1 and j:Get(charlie.id))
assert(not j:Get(alpha.id) and not j:Get(bravo.id))
assert(j:Summary(charlie).events==3)
assert(j.db.merged[alpha.id].note==alphaNote)
assert(j.db.merged[bravo.id].note==bravoNote)
local detail=table.concat(c:Details(charlie),'\n')
assert(detail:find(charlieNote,1,true) and detail:find(bravoNote,1,true))
assert(detail:find(alphaNote,1,true))

local reloaded=ns.CreateAnglingJournal(saved)
local laterBook=ns.CreateAnglingBook(reloaded,ns.CreateAnglingTracking(reloaded),ns.CreateFieldbookShell())
local later=table.concat(laterBook:Details(reloaded:Get(charlie.id)),'\n')
assert(reloaded.db.merged[alpha.id].note==alphaNote)
assert(later:find(alphaNote,1,true))
assert(reloaded:Summary(reloaded:Get(charlie.id)).events==3)
local delta=spot('Delta');local echo=spot('Echo')
assert(j:Edit(echo.id,echo.name,'Branch note',false))
mergeThroughUI(charlie,delta);mergeThroughUI(echo,delta)
local all=table.concat(c:Details(delta),'\n')
assert(all:find(alphaNote,1,true) and all:find(bravoNote,1,true) and all:find(charlieNote,1,true) and all:find('Branch note',1,true))
assert(j:Summary(delta).events==3 and j.db.merged[alpha.id].note==alphaNote)
-- Malformed repeated/cyclic ancestry is finite and displayed at most once.
j.db.merged[alpha.id].mergedFrom={bravo.id,alpha.id}
all=table.concat(c:Details(delta),'\n')
local _,count=all:gsub(alphaNote,'');assert(count==1)
''')
