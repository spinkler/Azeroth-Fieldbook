"""Lifecycle tests; mocks do not emulate WoW's secret-value/rendering engine."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
ns, frames, UIParent = {}, {}, {}
secret = setmetatable({}, {__tostring=function() error('secret stringify') end,
    __concat=function() error('secret concat') end})
function issecretvalue(v) return rawequal(v,secret) end
secretTables, forbiddenTables = {}, {}
function issecrettable(v) return secretTables[v] == true or rawequal(v,secret) end
function canaccesstable(v) return not forbiddenTables[v] end
local methods = {}
function methods:SetScript(k,f) self.scripts[k]=f end
function methods:SetSize() end
function methods:SetFrameStrata() end
function methods:SetClampedToScreen() end
function methods:SetMovable(v) self.movable=v end
function methods:EnableMouse(value) self.mouseEnabled=value end
function methods:SetAlpha(value) self.alpha=value end
function methods:RegisterForDrag() end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:SetAllPoints() end
function methods:SetColorTexture(r,g,b,a) self.alpha=a end
function methods:SetJustifyH() end
function methods:SetPoint(...) self.point={...} end
function methods:GetPoint() return unpack(self.point) end
function methods:ClearAllPoints() self.point=nil end
function methods:SetText(v) self.text=v end
function methods:GetText() error('text readback') end
function methods:Hide() self.shown=false end
function methods:Show() self.shown=true end
function methods:RegisterEvent(event) self.events[event]=true end
function methods:RegisterUnitEvent(event,...) self.events[event]={...} end
function methods:UnregisterAllEvents() self.events={} end
local function object() return setmetatable({scripts={},events={},strings={}}, {__index=methods}) end
function methods:CreateFontString()
    local f=object(); table.insert(self.strings,f); return f
end
function methods:CreateTexture() self.texture=object(); return self.texture end
function CreateFrame(_,name,parent)
    local f=object(); f.parent=parent; frames[#frames+1]=f
    if name then _G[name]=f end
    return f
end
now=0
function GetTime() return now end
exists,enemy,controlled=true,true,false
function UnitExists() return exists end
function UnitIsPlayer() return targetPlayer end
function UnitIsEnemy() return enemy end
function UnitPlayerControlled() return controlled end
function UnitIsUnit(u) return u=='alias' end
function UnitCastingInfo()
    if casting then return secret,nil,nil,nil,nil,nil,nil,secret,castID,71 end
end
function UnitChannelInfo()
    if channel then return secret,nil,nil,nil,nil,nil,nil,castID,nil,nil,72 end
end
auras={player={},target={}}
C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
    assert(filter==(unit=='player' and 'HARMFUL' or 'HELPFUL'))
    return auras[unit][index]
end}
C_Spell={GetSpellInfo=function(id)
    if issecretvalue(id) then return {castTime=secret} end
    return {castTime=id==99 and 0 or 1500}
end,GetSpellName=function(id) return issecretvalue(id) and secret or 'Spell name' end}
function fire(event,...) frames[1].scripts.OnEvent(frames[1],event,...) end
function advance(seconds)
    now=now+seconds
    local panel=AzerothFieldbookSpellIDWindow
    if panel.shown then panel.scripts.OnUpdate(panel,seconds) end
end
''')
lua.execute((Path(__file__).resolve().parents[1] / 'SpellIDWindow.lua').read_text(), 'AzerothFieldbook', lua.globals().ns)
lua.execute(r'''
db={}
ns.SpellIDWindow:Initialize(db)
local panel=AzerothFieldbookSpellIDWindow
local cast,instant,debuff,buff=frames[3],frames[4],frames[5],frames[6]
local function id(row) return row.strings[2].text end
assert(panel.shown and panel.movable and panel.texture.alpha==0.35)
assert(db.displaySpellIDWindow and not db.spellIDWindowLocked and not db.spellIDWindowIndefinite)
assert(not cast.shown and not buff.shown)
panel.scripts.OnDragStart(panel); assert(panel.moving)
panel:SetPoint('CENTER',UIParent,'CENTER',12,34)
panel.scripts.OnDragStop(panel)
assert(db.spellIDWindowPosition.x==12 and db.spellIDWindowPosition.y==34)
db.spellIDWindowLocked=true; db.spellIDWindowAlpha=0.6
ns.SpellIDWindow:ApplySettings()
panel.scripts.OnDragStart(panel)
assert(not panel.moving and not panel.movable and panel.texture.alpha==0.6)
auras.target={{auraInstanceID=1,spellId=123,name='Rushing Charge',dispelName='Magic'}}
fire('UNIT_AURA','target',{})
assert(buff.shown and id(buff)==123 and buff.strings[3].text=='Magic')
assert(buff.strings[4].text=='Rushing Charge')
advance(60)
auras.player={{auraInstanceID=2,spellId=secret,name=secret,dispelName=secret}}
fire('UNIT_AURA','player',{})
assert(debuff.shown and rawequal(id(debuff),secret))
fire('UNIT_AURA','target',{}) -- Same instance must not extend its expiry.
advance(60)
assert(not buff.shown and debuff.shown)
fire('UNIT_AURA','target',{updatedAuraInstanceIDs={1}})
assert(buff.shown)
advance(60)
assert(not debuff.shown and buff.shown)
auras.target={}; fire('PLAYER_TARGET_CHANGED')
assert(buff.shown) -- Historical observations survive target changes/removal.
advance(60); assert(not buff.shown)
casting,castID=true,456
fire('UNIT_SPELLCAST_START','target')
assert(cast.shown and id(cast)==456)
casting=false
fire('UNIT_SPELLCAST_SUCCEEDED','target',secret,456,71)
assert(not instant.shown)
channel,castID=true,secret
fire('UNIT_SPELLCAST_CHANNEL_START','target')
assert(rawequal(id(cast),secret))
fire('UNIT_SPELLCAST_SUCCEEDED','target',secret,secret,72)
assert(not instant.shown)
channel=false
fire('UNIT_SPELLCAST_SUCCEEDED','focus',secret,99,80)
assert(not instant.shown)
fire('UNIT_SPELLCAST_SUCCEEDED','alias',secret,99,80)
assert(instant.shown and id(instant)==99)
fire('UNIT_SPELLCAST_SUCCEEDED','target',secret,secret,81)
assert(rawequal(id(cast),secret) and id(instant)==99)
-- Secret cast time never becomes a comparison or a claim of a confirmed instant.
db.spellIDWindowIndefinite=true; ns.SpellIDWindow:ApplySettings()
advance(121); assert(cast.shown and instant.shown)
db.spellIDWindowIndefinite=false; ns.SpellIDWindow:ApplySettings()
advance(1); assert(not cast.shown and not instant.shown)
db.displaySpellIDWindow=false; ns.SpellIDWindow:ApplySettings()
assert(not panel.shown and next(frames[1].events)==nil)
fire('UNIT_SPELLCAST_SUCCEEDED','target',secret,99,82)
assert(not instant.shown)
db.displaySpellIDWindow=true; ns.SpellIDWindow:ApplySettings()
controlled=true
fire('UNIT_SPELLCAST_SUCCEEDED','target',secret,99,82)
assert(not instant.shown)
controlled=false; enemy=false
fire('UNIT_SPELLCAST_START','target')
assert(not cast.shown)
-- Slot API returns a nil continuation before its slot values on the final page.
-- Exercise pagination as well as accessible tables whose contents are secret.
local slotAuras = {}
local slotCalls = 0
C_UnitAuras.GetAuraSlots=function(unit,filter,maxSlots,token)
    assert(filter==(unit=='player' and 'HARMFUL' or 'HELPFUL'))
    if unit=='player' then return nil end
    slotCalls=slotCalls+1
    if not next(slotAuras) then return nil end
    if token==nil then return 12, 7 end
    assert(token==12)
    return nil, 8
end
C_UnitAuras.GetAuraDataBySlot=function(unit,slot) return slotAuras[slot] end
local combatAura={auraInstanceID=secret,spellId=secret,name=secret,dispelName=secret}
secretTables[combatAura]=true
slotAuras[7]=combatAura
slotAuras[8]={auraInstanceID=88,spellId=6288,name='Another buff'}
enemy=true; targetPlayer=false
fire('PLAYER_TARGET_CHANGED')
assert(slotCalls==2 and id(buff)==6288) -- Final page was not lost after nil token.
slotAuras[8]=combatAura
fire('UNIT_AURA','target',{})
assert(buff.shown and rawequal(id(buff),secret))
advance(60)
fire('UNIT_AURA','target',{})
advance(60)
assert(not buff.shown) -- Secret identity must not reset expiry on unchanged scans.
slotAuras={}; fire('UNIT_AURA','target',{})
slotAuras[7]=combatAura; slotAuras[8]=combatAura
fire('UNIT_AURA','target',{})
assert(buff.shown and rawequal(id(buff),secret))
-- No reads from friendly/hostile players, even if PlayerControlled disagrees.
local before=slotCalls
targetPlayer=true; controlled=false
for _, hostile in ipairs({false,true}) do
    enemy=hostile
    fire('PLAYER_TARGET_CHANGED'); fire('UNIT_AURA','target',{})
    ns.SpellIDWindow:ApplySettings()
end
assert(slotCalls==before)
-- Historical NPC row remains, but player buffs cannot replace it.
assert(rawequal(id(buff),secret))
targetPlayer=false; controlled=true
fire('PLAYER_TARGET_CHANGED'); assert(slotCalls==before)
-- Friendly NPCs remain eligible; inaccessible aura tables are never indexed.
controlled=false; enemy=false
local forbidden=setmetatable({}, {__index=function() error('forbidden read') end})
forbiddenTables[forbidden]=true
slotAuras[7]=forbidden; slotAuras[8]=forbidden
fire('PLAYER_TARGET_CHANGED')
local messages={}
ns.SpellIDWindow:Report(function(message) messages[#messages+1]=message end)
assert(table.concat(messages,' '):find('aura table access denied',1,true))
slotAuras[7]={auraInstanceID=secret,spellId=134,name='Fire Shield',dispelName='Magic'}
slotAuras[8]=slotAuras[7]
fire('UNIT_AURA','target',{})
assert(id(buff)==134 and buff.strings[3].text=='Magic')
-- Public instance replacement in an occupied slot is a new observation.
slotAuras[7]={auraInstanceID=99,spellId=6288,name='Rushing Charge'}
slotAuras[8]=slotAuras[7]
fire('UNIT_AURA','target',{})
assert(id(buff)==6288)
advance(119)
fire('UNIT_AURA','target',{updatedAuraInstanceIDs={99}})
advance(2); assert(buff.shown)
advance(118); assert(not buff.shown)
-- A slot query that throws must try indexed access, not look like an empty scan.
local workingSlots=C_UnitAuras.GetAuraSlots
C_UnitAuras.GetAuraSlots=function() error('slot access denied') end
auras.target={{auraInstanceID=1234,spellId=6268,name='Rushing Charge'}}
fire('PLAYER_TARGET_CHANGED')
assert(buff.shown and id(buff)==6268)
messages={}
ns.SpellIDWindow:Report(function(message) messages[#messages+1]=message end)
local report=table.concat(messages,' ')
assert(report:find('path=index fallback',1,true) and report:find('slot access denied',1,true))
advance(60)
fire('UNIT_AURA','target',{})
advance(60); assert(not buff.shown)
-- Public instances keep their identity if enumeration later switches back to slots.
C_UnitAuras.GetAuraSlots=workingSlots
slotAuras[7]=auras.target[1]; slotAuras[8]=auras.target[1]
fire('UNIT_AURA','target',{})
assert(not buff.shown)
-- Both APIs may be denied. Report both errors, preserve history and never leak secret errors.
C_UnitAuras.GetAuraSlots=function() error('slot access denied') end
local workingIndex=C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex=function() error('index access denied') end
fire('UNIT_AURA','target',{})
messages={}
ns.SpellIDWindow:Report(function(message) messages[#messages+1]=message end)
report=table.concat(messages,' ')
assert(report:find('slot access denied',1,true) and report:find('index access denied',1,true))
C_UnitAuras.GetAuraSlots=function() error(secret) end
C_UnitAuras.GetAuraDataByIndex=function() error(secret) end
fire('UNIT_AURA','target',{})
messages={}
ns.SpellIDWindow:Report(function(message) messages[#messages+1]=message end)
assert(table.concat(messages,' '):find('error text unavailable',1,true))
C_UnitAuras.GetAuraDataByIndex=workingIndex
fire('UNIT_AURA','target',{})
assert(not buff.shown) -- Failed queries did not erase deduplication state.
C_UnitAuras.GetAuraSlots=workingSlots
-- Combat ending discovers still-active buffs without a target change.
slotAuras[7]={auraInstanceID=900,spellId=134,name='Fire Shield'}
slotAuras[8]=slotAuras[7]
fire('PLAYER_REGEN_ENABLED')
assert(buff.shown and id(buff)==134)
assert(frames[1].events.PLAYER_REGEN_ENABLED)
-- Fade depends on observation state, never secret text contents.
db.spellIDWindowAutoFade=true; db.spellIDWindowIndefinite=false
ns.SpellIDWindow:ApplySettings()
now=now+121; panel.scripts.OnUpdate(panel,0.3)
assert(panel.alpha==0 and not panel.mouseEnabled and panel.shown)
enemy=true
fire('UNIT_SPELLCAST_SUCCEEDED','target',nil,134)
assert(panel.alpha==1) -- New data restores immediately.
now=now+121; panel.scripts.OnUpdate(panel,0.3)
assert(panel.alpha==0)
db.spellIDWindowAutoFade=false; ns.SpellIDWindow:ApplySettings()
assert(panel.alpha==1)
-- Only settings, never observed IDs/names, go into the saved database.
assert(db.spellId==nil and db.observed==nil)
ns.SpellIDWindow:Initialize(db)
assert(panel.point[1]=='CENTER' and panel.point[4]==12 and panel.point[5]==34)
AzerothFieldbookBestiary={}
ns.SpellIDWindow:AnchorToBook(AzerothFieldbookBestiary)
assert(panel.point[1]=='CENTER','saved spell-window positions stay independent')
db.spellIDWindowPosition=nil
ns.SpellIDWindow:Initialize(db)
assert(panel.point[1]=='RIGHT' and panel.point[2]==AzerothFieldbookBestiary and panel.point[3]=='LEFT',
    'untouched spell window defaults beside the main book once it exists')
''')
print('Spell ID window lifecycle checks passed (live rendering still requires WoW).')
