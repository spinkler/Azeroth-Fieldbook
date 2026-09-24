"""Explicit rumour review, matching manual records and bounded rejection history."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
ns={}
function InCombatLockdown() return false end
function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
C_Spell={GetSpellName=function(id) if id==133 then return 'Fireball' end end}
''')
for name in ['SharingReport.lua', 'BestiaryJournal.lua']:
    lua.execute((root/name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)

lua.execute(r'''
local S=ns.SharingReport
local fire={kind='ability',value='Fireball',spellID=133}
local traits={{kind='offense',value='Fire'},{kind='resistance',value='Frost'},
    {kind='immunity',value='Shadow'},{kind='behaviour',value='Hostile'}}
local sequence=0
local function report(claims)
    sequence=sequence+1
    return {version=1,transaction='1000000-'..sequence..'-1',created=1000000,recipient='Erna Lionguard',
        creatureID=42,name='Creature',category='Humanoid',levelMin=9,levelMax=11,locations={'Elwynn'},rumours=claims}
end
local function journal() return ns.CreateBestiaryJournal({},function() return nil end) end
local function import(j,claims,sender)
    local value=report(claims)
    assert(j:ImportReport(value,sender or 'Alice Sunstrider',1000000))
    return value
end

-- A receiving-only character can explicitly verify without discovery credit,
-- auto-locking, or importing any unrelated claim as a fact.
local j=journal()
import(j,{fire,unpack(traits)})
local entry=j.entries[42]
assert(not j:ConfirmRumour(42,fire),'must review a stored claim, not an arbitrary table')
assert(not j:ConfirmRumour(42,nil))
assert(j:ConfirmRumour(42,j:GetRumours(42)[1]))
eq(entry.abilities.Fireball.state,'confirmed'); eq(entry.abilities.Fireball.spellID,133)
eq(#j:GetRumours(42),4); eq(#j:ConfirmedNames(42),0,'verification does not lock the entry')
eq(#S.Candidates(entry),1,'only the verified claim is eligible to be shared')
entry.behaviours.Neutral=true
while #j:GetRumours(42)>0 do assert(j:ConfirmRumour(42,j:GetRumours(42)[1])) end
assert(entry.offenses.Fire and entry.resistances.Frost and entry.immunities.Shadow and entry.behaviours.Hostile)
assert(not entry.behaviours.Neutral,'normal mutually exclusive behaviour rules apply')
eq(j:GetSharingBalance(),0); eq(select(2,j:GetTotals()),0)
assert(not entry.personalEncountered and not entry.confirmed and entry.kills==0)
eq(#S.Candidates(entry),5)
j:SetEntryConfirmed(42,true); eq(#j:ConfirmedNames(42),1)
j:SetEntryConfirmed(42,false)
eq(j:PreviewReport(report({fire,unpack(traits)}),'Bob Stonewell').newRumours,0)
import(j,{fire,unpack(traits)},'Bob Stonewell');eq(#j:GetRumours(42),0,'known records do not reappear as rumours')

-- Name normalization and spell identity both match; confirming never replaces
-- existing notes, effect tags, origin or tooltip opt-out on a pending ability.
j=journal();import(j,{{kind='ability',value='FIREBALL'}})
import(j,{{kind='ability',value='Fireball Rank Two',spellID=133}},'Bob Stonewell')
entry=j.entries[42]
entry.abilities['Fireball']={state='pending',origin='Your note',spellID=133,note='Private note',effects={Fear=true},showInTooltip=false}
entry.ignoredAbilities={FIREBALL=true}
local original=entry.abilities.Fireball
assert(j:ConfirmRumour(42,j:GetRumours(42)[1]))
eq(entry.abilities.Fireball,original);eq(original.note,'Private note');assert(original.effects.Fear)
eq(original.origin,'Your note');assert(original.showInTooltip==false)
assert(not next(entry.ignoredAbilities)); eq(#j:GetRumours(42),0,'matching sources and aliases all resolve')
eq(#S.Candidates(entry),1);eq(j:GetSharingBalance(),0)

-- Manual abilities, confirming an observed ability, and all manual trait
-- setters remove matching rumours. Rejected/pending observations do not.
j=journal();import(j,{fire,unpack(traits)})
import(j,{{kind='ability',value='  FIREBALL  '},unpack(traits)},'Bob Stonewell')
eq(#j:GetRumours(42),10)
assert(j:AddManual(42,'fireball','Private manual note',nil,{Stun=true}))
eq(#j:GetRumours(42),8);eq(j.entries[42].abilities.fireball.note,'Private manual note')
j:SetOffense(42,'Fire',true);j:SetResistance(42,'Frost',true)
j:SetImmunity(42,'Shadow',true);j:SetBehaviour(42,'Hostile',true)
eq(#j:GetRumours(42),0)
import(j,{{kind='ability',value='Foreign Spell Name',spellID=133}})
assert(j:AddManual(42,'Fireball','', '133',{}));eq(#j:GetRumours(42),0,'manual spell ID matches alternate name')
import(j,{{kind='ability',value='Charge'}})
j.entries[42].abilities.Charge={state='pending'}
eq(#j:GetRumours(42),1)
j:SetAbility(42,'Charge','rejected');eq(#j:GetRumours(42),1)
assert(j:WasRumourRejected(42,j:GetRumours(42)[1]))
j:SetAbility(42,'Charge','confirmed');eq(#j:GetRumours(42),0)

-- Locked review rejects all promotion paths without mutating points or claims.
j=journal();import(j,{fire,unpack(traits)})
j:SetEntryConfirmed(42,true)
local revision=j.revision
for _,claim in ipairs(j:GetRumours(42)) do
    local ok,message=j:ConfirmRumour(42,claim)
    assert(not ok and message:find('Unlock',1,true))
end
assert(not j:AddManual(42,'Fireball',''))
assert(not j:SetOffense(42,'Fire',true));assert(not j:SetResistance(42,'Frost',true))
assert(not j:SetImmunity(42,'Shadow',true));assert(not j:SetBehaviour(42,'Hostile',true))
eq(j.revision,revision);eq(#j:GetRumours(42),5);eq(j:GetSharingBalance(),0)
assert(j:DismissRumour(42,j:GetRumours(42)[1]));eq(#j:GetRumours(42),4)

-- Old dismissals and rejected personal abilities are recognized across senders.
-- A new transaction surfaces a rejected claim; a duplicate delivery does not.
local db={};j=ns.CreateBestiaryJournal(db,function() return nil end)
local first=import(j,{fire})
local dismissed=j:GetRumours(42)[1]
dismissed.dismissed=true -- Historical pre-review SavedVariables shape.
assert(j:WasRumourRejected(42,fire));eq(#j:GetRumours(42),0)
assert(j:ImportReport(first,'Alice Sunstrider',1000000));eq(#j:GetRumours(42),0,'same transaction remains dismissed')
local again=import(j,{{kind='ability',value='fireball',spellID=133}})
eq(#j:GetRumours(42),1);eq(#j:GetRumours(42,true),1,'reuse same-source history slot')
eq(j:GetRumours(42)[1].transaction,again.transaction);assert(j:GetRumours(42)[1].previouslyRejected)
assert(j:DismissRumour(42,j:GetRumours(42)[1]))
import(j,{{kind='ability',value='Another name',spellID=133}},'Bob Stonewell')
eq(#j:GetRumours(42),1);assert(j:GetRumours(42)[1].previouslyRejected)
eq(j:GetRumours(42)[1].sender,'Bob Stonewell')
local restored=ns.CreateBestiaryJournal(db,function() return nil end)
assert(restored:WasRumourRejected(42,fire));assert(restored:GetRumours(42)[1].previouslyRejected)
assert(restored:ConfirmRumour(42,restored:GetRumours(42)[1]));eq(#restored:GetRumours(42),0)
import(restored,{fire});eq(#restored:GetRumours(42),0,'verified claim stays out of review despite past rejection')
restored:RemoveAbility(42,'Another name')
assert(restored:WasRumourRejected(42,{kind='ability',value='Another name'}))

-- Reviewing/reoffering is still bounded at the storage cap, without silently
-- dropping incoming claims or requiring a new slot for the same source.
j=journal()
local many={}
for i=1,32 do many[i]={kind='ability',value='Spell '..i} end
import(j,many)
assert(j:DismissRumour(42,j:GetRumours(42)[1]))
local overflow=report({{kind='ability',value='Overflow'}})
revision=j.revision
assert(not j:ImportReport(overflow,'Alice Sunstrider',1000000));eq(j.revision,revision)
import(j,{many[1]});eq(#j:GetRumours(42),32);eq(#j:GetRumours(42,true),32)
assert(j:GetRumours(42)[1].previouslyRejected)
j:ResetDatabase();assert(not j:WasRumourRejected(42,many[1]));eq(#j:GetRumours(42,true),0)
''')
print('PASS: rumour verification, manual matching, locks, private data, zero credit, rejection history, repeat offers and storage bounds')
