from ui_test_harness import new_ui_client
lua=new_ui_client(['BestiaryLoot.lua'])
lua.execute(r"""
j={entries={[42]={personalEncountered=true}},revision=0,Touch=function(self) self.revision=self.revision+1 end}
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
