from ui_test_harness import new_ui_client
for event,wait in [('UNIT_SPELLCAST_FAILED',1),('UNIT_SPELLCAST_FAILED',4),('UNIT_SPELLCAST_INTERRUPTED',1),('UNIT_SPELLCAST_INTERRUPTED',4),('IGNORED',4)]:
    lua=new_ui_client(['BestiaryLoot.lua'])
    lua.globals().wait_after_fail=wait
    lua.globals().failure_event=event
    lua.execute(r'''
local guid='Creature-0-1-2-3-42-901'
local dead=false
now=100
function UnitGUID(unit) if unit=='target' then return guid end end
function UnitName(unit) if unit=='target' then return 'Bandit' end end
function UnitIsDead() return dead end
function GetTime() return now end
function IsFishingLoot() return false end
slots={}
function GetNumLootItems() return #slots end
function GetLootSourceInfo(i) return unpack(slots[i].sources) end
function GetLootSlotLink(i) return slots[i].link end
j={entries={[42]={personalEncountered=true}},revision=0,Touch=function(self) self.revision=self.revision+1 end}
local f=ns.StartBestiaryLoot(j)
local function fire(e,...) return f.scripts.OnEvent(f,e,...) end
fire('UNIT_SPELLCAST_SENT','player','Bandit','Cast-failed',921)
fire(failure_event,'player','Cast-failed',921)
-- A failed cast opens no loot window, so no LOOT_CLOSED is expected yet.
now=now+wait_after_fail;dead=true
slots={{link='item:100',sources={guid,2}}}
fire('LOOT_READY')
slots={};fire('LOOT_OPENED');fire('LOOT_CLOSED')
print('After failed pick + '..wait_after_fail..' seconds + corpse autoloot: '..(j.entries[42].loot and 'RECORDED' or 'MISSING'))
assert(j.entries[42].loot.items[100].quantity==2 and j.entries[42].loot.samples==1)
assert(not j.entries[42].pickpocketLoot)
-- Control: a fresh ordinary corpse capture works with otherwise identical APIs.
slots={{link='item:100',sources={guid,2}}};fire('LOOT_READY')
assert(j.entries[42].loot.items[100].quantity==2)
print('Same corpse with stale pick state cleared: RECORDED quantity='..j.entries[42].loot.items[100].quantity)
''')
