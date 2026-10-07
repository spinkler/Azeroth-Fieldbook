from ui_test_harness import new_ui_client
lua=new_ui_client(['BestiaryLoot.lua'])
lua.execute(r"""
j={entries={[42]={personalEncountered=true}},revision=0,Touch=function(self) self.revision=self.revision+1 end}
UnitGUID=nil -- Existing corpse fixtures have no live unit token.
local a='Creature-0-1-2-3-42-1'
local b='Creature-0-1-2-3-42-2'
slots={{link='item:100',sources={a,3,b,2}},{sources={a,0,b,0}}}
function GetNumLootItems() return #slots end
function GetLootSourceInfo(i) return unpack(slots[i].sources) end
function GetLootSlotLink(i) return slots[i].link end
local f=ns.StartBestiaryLoot(j)
local allocated=#objects
for i=1,100 do assert(ns.StartBestiaryLoot(j)==f) end
eq(#objects,allocated,'Repeated startup must reuse one event listener')
local function fire() f.scripts.OnEvent(f,'LOOT_READY') end
fire();fire()
local loot=j.entries[42].loot
eq(loot.samples,2);eq(loot.items[100].quantity,5);eq(loot.items[100].drops,2)
f=ns.StartBestiaryLoot(j);fire()
eq(loot.samples,2);eq(loot.items[100].quantity,5)
slots={{sources={'Creature-0-1-2-3-42-3',0}}};fire()
eq(loot.samples,3);eq(loot.items[100].drops,2)
slots={{link='item:100',sources={a,1}}};fire();eq(loot.items[100].quantity,5)
slots={{link='item:100',sources={'GameObject-0-1-2-3-42-9',4}}};fire();eq(loot.samples,3)
slots={{link='item:100',sources={secret,4}}};fire();eq(loot.samples,3)
slots={{link='item:100',sources={'Creature-0-1-2-3-42-4',2}}}
function IsFishingLoot() return true end
fire();eq(loot.samples,3)
IsFishingLoot=nil
j.entries[42]={personalEncountered=true};fire();eq(j.entries[42].loot.samples,1)
for i=5,200 do slots[1].sources={'Creature-0-1-2-3-42-'..i,1};fire() end
eq(#j.entries[42].loot.recent,128)
""")
print('PASS: loot quantities, per-corpse samples, duplicate events/reloads, partial loot, source exclusions, reset and bounded history')

lua.execute(r"""
local guid='Creature-0-1-2-3-42-900'
local dead=false
function UnitGUID(unit) if unit=='target' then return guid end end
function UnitName(unit) if unit=='target' then return 'Bandit' end end
function UnitIsDead() return dead end
function GetTime() return now end
j.entries[42]={personalEncountered=true}
local f=j.lootObserver
local function event(name,...) f.scripts.OnEvent(f,name,...) end
local function sent(cast) event('UNIT_SPELLCAST_SENT','player','Bandit',cast,921) end
local function success(cast) event('UNIT_SPELLCAST_SUCCEEDED','player',cast,921) end
slots={{link='item:200',sources={guid,2}}}
event('LOOT_READY');assert(not j.entries[42].loot,'unclassified living source excluded')
sent('Cast-1');event('LOOT_READY');assert(not j.entries[42].pickpocketLoot)
slots={};success('Cast-1') -- READY before success survives autoloot clearing slots.
local pocket=j.entries[42].pickpocketLoot
eq(pocket.samples,1);eq(pocket.items[200].quantity,2);assert(not j.entries[42].loot)
slots={{link='item:200',sources={guid,2}}};event('LOOT_OPENED');eq(pocket.samples,1)
event('LOOT_CLOSED');dead=true;event('LOOT_READY')
eq(j.entries[42].loot.samples,1);eq(j.entries[42].loot.items[200].quantity,2)
event('LOOT_CLOSED');dead=false
sent('Cast-2');event('UNIT_SPELLCAST_FAILED','player','Cast-2',921);event('LOOT_READY');eq(pocket.samples,1)
event('LOOT_CLOSED');sent('Cast-3');success('Cast-3');event('LOOT_READY');eq(pocket.samples,2)
event('LOOT_CLOSED');sent('Cast-4');now=now+4;success('Cast-4');event('LOOT_READY');eq(pocket.samples,2)
-- Two matching names with different GUIDs cannot identify a cast target.
event('LOOT_CLOSED')
function UnitGUID(unit) return unit=='target' and guid or 'Creature-0-1-2-3-42-901' end
function UnitName() return 'Bandit' end
sent('Cast-5');success('Cast-5');event('LOOT_READY');eq(pocket.samples,2)
event('LOOT_CLOSED');event('UNIT_SPELLCAST_SENT','player',secret,secret,secret)
assert(not j.entries[42].loot.items[999])
""")
print('PASS: pickpocket source isolation, event ordering, autoloot, duplicate events, corpse after pick, failures, expiry and ambiguous targets')

lua.execute(r"""
local guid='Creature-0-1-2-3-42-950'
function UnitGUID(unit) if unit=='target' then return guid end end
function UnitName() return 'Bandit' end
function UnitIsDead() return false end
local f=j.lootObserver
local function event(name,...) f.scripts.OnEvent(f,name,...) end
event('PLAYER_ENTERING_WORLD');j.entries[42]={personalEncountered=true};slots={}
event('UNIT_SPELLCAST_SENT','player','Bandit','Cast-empty',921)
event('UNIT_SPELLCAST_SUCCEEDED','player','Cast-empty',921)
local loot=j.entries[42].pickpocketLoot
eq(loot.samples,1);assert(next(loot.items)==nil)
local context=ns.TakePickpocketMoneyContext()
assert(context and context.confirmed,'Successful empty pick supplies bounded cash context')
event('UNIT_SPELLCAST_SUCCEEDED','player','Cast-empty',921);event('LOOT_READY');event('LOOT_OPENED')
eq(loot.samples,1)
event('LOOT_CLOSED')
event('UNIT_SPELLCAST_SENT','player','Bandit','Cast-fail',921)
event('UNIT_SPELLCAST_FAILED','player','Cast-fail',921);eq(loot.samples,1)
""")
print('PASS: successful empty picks counted once, failed picks excluded and successful empty picks supply cash context')

lua.execute(r"""
local d=ns.PickpocketDiagnostics
d:Log('disabled');eq(#d.rows,0)
d.enabled=true
d:Log('guard',secret,nil,'a|b')
assert(d:Report():find('<restricted>',1,true))
assert(d:Report():find('<nil>',1,true))
for i=1,250 do d:Log('bounded',i) end
eq(#d.rows,200)
d.enabled=false;d:Log('disabled again');eq(#d.rows,200)
""")
print('PASS: opt-in cash diagnostics are bounded and redact restricted values')
