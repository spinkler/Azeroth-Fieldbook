"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from ui_test_harness import new_ui_client
lua = new_ui_client(['AtlasJournal.lua','LoreJournal.lua','LoreReports.lua'])
lua.execute(r'''
L=ns.Lore;R=ns.LoreReports
source=ns.CreateLoreJournal({});receiver=ns.CreateLoreJournal({})
local e
for i=1,256 do
 e=assert(source:CapturePage({sessionID='source',title='Collected source'}, {number=i,raw='Page '..i,first=i==1,last=i==256,method='displayed'}))
end
for i=1,256 do assert(source:AddPassage(e.id,{raw='Passage '..i,nature='source',origin='manual',source='Collected quotations'})) end
for i=1,100 do
 assert(source:AddLocation(e.id,{zone='Place '..i,origin='manual',meaning='observation'}))
 assert(source:AddLink(e.id,{section='bestiary',id=i,label='Creature '..i}))
end
assert(L.Count(e.pages)==256 and #e.passages==256 and #e.locations==100 and #e.links==100)
assert(source:ArchiveBytes()<L.MAX_WORK_BYTES)
local mine=assert(receiver:CapturePage({sessionID='mine',title='Personal field journal'}, {number=1,raw='PERSONAL PAGE',first=true,last=true,method='displayed'}))
assert(receiver:Update(mine.id,{tags={'PERSONAL TAG'}}))
assert(receiver:AddPassage(mine.id,{raw='PERSONAL PASSAGE'}))
assert(receiver:AddLocation(mine.id,{zone='PERSONAL LOCATION'}))
assert(receiver:AddLink(mine.id,{section='bestiary',id=123,label='PERSONAL LINK'}))
mine.customMetadata={deep={text='Preserve me'}}
local targetID=mine.id
local function countTables(t)
 if type(t)~='table' then return 0 end
 local n=1;for _,x in pairs(t) do n=n+countTables(x) end;return n
end
for i=1,32 do
 assert(source:Update(e.id,{notes='Revision '..i}))
 local report=assert(R.Build(source,e.id,{includeReferences=true,notes=true}))
 local wire=assert(R.Encode(report))
 local ticket=assert(R.Prepare(wire,'Courier'))
 if i==29 then
  local original=receiver:Get(targetID)
  assert(#original.passages==1 and #original.locations==1)
  local summary,canAccept=R.Preflight(receiver,ticket,targetID)
  assert(canAccept and receiver:Get(targetID)==original and #original.passages==1 and #original.locations==1)
 end
 local ok,new,err=pcall(R.Accept,receiver,ticket,targetID)
 local current=receiver:Get(targetID)
 local valid,why=L.ValidateEntry(current,current.id)
 assert(ok and new, err or 'Precondition: every report is accepted through current production APIs')
 assert(valid, why)
 assert(receiver:ArchiveBytes()<L.MAX_WORK_BYTES)
 assert(L.Count(current.pages)==1 and #current.passages==1 and #current.locations==1 and #current.links==1 and #current.tags==1)
 assert(current.customMetadata.deep.text=='Preserve me')
 if i==28 then
  local beforeTags=#current.tags
  local result,error=receiver:Update(targetID,{revisit=true})
  assert(result and result.revisit==true and beforeTags==1 and #result.tags==1, 'Revisit must preserve unrelated tags')
 end
 if not ok or not new then break end
end
local fresh=ns.CreateLoreJournal(receiver.db):Get(targetID)
assert(#fresh.reports==32 and #fresh.passages==1 and #fresh.locations==1 and #fresh.tags==1, 'Personal evidence must survive reinitialization')
assert(L.ValidateEntry(fresh,fresh.id))
local current=receiver:Get(targetID)
local duplicate=assert(R.Prepare(assert(R.Encode(assert(R.Build(source,e.id,{includeReferences=true,notes=true})))),'Another courier'))
local before=current.reports[32].latestReceipt
local _,canAccept=R.Preflight(receiver,duplicate,targetID)
assert(canAccept and current.reports[32].latestReceipt==before)
assert(R.Accept(receiver,duplicate,targetID))
current=receiver:Get(targetID)
assert(#current.reports==32 and #current.passages==1 and current.reports[32].latestReceipt.receivedFrom=='Another courier')
assert(source:Update(e.id,{notes='Over capacity'}))
local over=assert(R.Prepare(assert(R.Encode(assert(R.Build(source,e.id,{includeReferences=true,notes=true})))),'Courier'))
assert(not R.Accept(receiver,over,targetID) and receiver:Get(targetID)==current)
assert(current.customMetadata.deep.text=='Preserve me')
local function disk(value)
 if type(value)=='string' then return string.format('%q',value) end
 if type(value)~='table' then return tostring(value) end
 local rows={};for key,v in pairs(value) do rows[#rows+1]='['..disk(key)..']='..disk(v) end
 return '{'..table.concat(rows,',')..'}'
end
local restored=ns.CreateLoreJournal(assert(loadstring('return '..disk(receiver.db)))()):Get(targetID)
assert(#restored.reports==32 and #restored.passages==1 and #restored.locations==1 and #restored.links==1 and #restored.tags==1)
assert(restored.pages[1].raw=='PERSONAL PAGE' and restored.customMetadata.deep.text=='Preserve me')
''')
