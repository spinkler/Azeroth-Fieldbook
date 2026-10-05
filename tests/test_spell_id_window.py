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
function methods:GetScript(k) return self.scripts[k] end
function methods:SetShown(v) self.shown=v end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetFrameStrata() end
function methods:SetClampedToScreen() end
function methods:SetMovable(v) self.movable=v end
function methods:EnableMouse(value) self.mouseEnabled=value end
function methods:SetAlpha(value) self.alpha=value end
function methods:RegisterForDrag() end
function methods:RegisterForClicks(...) self.clicks={...} end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:SetAllPoints() end
function methods:SetColorTexture(r,g,b,a) self.alpha=a end
function methods:SetTexture(value) self.image=value end
function methods:AddMaskTexture(value) self.mask=value end
function methods:SetJustifyH() end
function methods:SetPoint(...) self.point={...} end
function methods:GetPoint() return unpack(self.point) end
function methods:ClearAllPoints() self.point=nil end
function methods:SetTextColor(...) self.color={...} end
function IsShiftKeyDown() return shiftDown == true end
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
function methods:CreateMaskTexture() return object() end
function CreateFrame(_,name,parent)
    local f=object(); f.parent=parent; frames[#frames+1]=f
    if name then _G[name]=f end
    return f
end
now=0
function GetTime() return now end
exists,enemy,controlled,targetPlayer=true,true,false,false
function UnitGUID() return "Creature-0-1-2-3-42-1" end
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
assert(db.spellIDWindowPosition.point=='BOTTOM' and db.spellIDWindowPosition.x==12 and db.spellIDWindowPosition.y==12)
db.spellIDWindowLocked=true; db.spellIDWindowAlpha=0.6
ns.SpellIDWindow:ApplySettings()
panel.scripts.OnDragStart(panel)
assert(not panel.moving and not panel.movable and panel.texture.alpha==0.6)
auras.target={{sourceUnit='target',auraInstanceID=1,spellId=123,name='Rushing Charge',dispelName='Magic'}}
fire('UNIT_AURA','target',{})
assert(buff.shown and id(buff)==123 and buff.strings[3].text=='Magic')
assert(buff.strings[4].text=='Rushing Charge')
advance(60)
auras.player={{sourceUnit='target',auraInstanceID=2,spellId=secret,name=secret,dispelName=secret}}
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
local combatAura={sourceUnit='target',auraInstanceID=secret,spellId=secret,name=secret,dispelName=secret}
secretTables[combatAura]=true
slotAuras[7]=combatAura
slotAuras[8]={sourceUnit='target',auraInstanceID=88,spellId=6288,name='Another buff'}
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
slotAuras[7]={sourceUnit='target',auraInstanceID=secret,spellId=134,name='Fire Shield',dispelName='Magic'}
slotAuras[8]=slotAuras[7]
fire('UNIT_AURA','target',{})
assert(id(buff)==134 and buff.strings[3].text=='Magic')
-- Public instance replacement in an occupied slot is a new observation.
slotAuras[7]={sourceUnit='target',auraInstanceID=99,spellId=6288,name='Rushing Charge'}
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
auras.target={{sourceUnit='target',auraInstanceID=1234,spellId=6268,name='Rushing Charge'}}
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
slotAuras[7]={sourceUnit='target',auraInstanceID=900,spellId=134,name='Fire Shield'}
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
assert(panel.point[1]=='BOTTOM' and panel.point[4]==12 and panel.point[5]==12)
AzerothFieldbookBestiary={}
ns.SpellIDWindow:AnchorToBook(AzerothFieldbookBestiary)
assert(panel.point[1]=='BOTTOM','saved spell-window positions stay independent')
db.spellIDWindowPosition=nil
ns.SpellIDWindow:Initialize(db)
assert(panel.point[1]=='BOTTOMRIGHT' and panel.point[2]==AzerothFieldbookBestiary and panel.point[3]=='BOTTOMLEFT',
    'untouched spell window defaults beside the main book once it exists')
''')
lua.execute(r'''
local panel=AzerothFieldbookSpellIDWindow
db.spellIDWindowLocked=false; ns.SpellIDWindow:ApplySettings()
assert(panel.hint.text=='Right-click: hide / Ctrl+Right-click: blacklist')
assert(panel.hint.color[1]==0.6)
shiftDown=false; panel.scripts.OnMouseUp(panel,'LeftButton'); assert(panel.shown)
shiftDown=true; panel.scripts.OnMouseUp(panel,'RightButton'); assert(panel.shown)
panel.scripts.OnMouseUp(panel,'LeftButton'); assert(not panel.shown)
ns.SpellIDWindow:ApplySettings(); assert(not panel.shown,'hide persists through settings refresh')
''')
print('Spell ID window lifecycle checks passed (live rendering still requires WoW).')

lua.execute(r'''
local window=ns.SpellIDWindow
local panel=AzerothFieldbookSpellIDWindow
local cast,instant,debuff,buff=frames[3],frames[4],frames[5],frames[6]
local function id(row) return row.strings[2].text end
function IsControlKeyDown() return ctrlDown==true end
function UnitName(unit)
    if unit=='target' then return casterName end
    if unit=='friend' then return 'Helpful friend' end
    if unit=='hidden' then return secret end
end
C_UnitAuras.GetAuraSlots=nil
auras={player={},target={}};casting=false;channel=false;enemy=true;controlled=false;exists=true
shiftDown=false;ctrlDown=false;casterName='Kobold Geomancer'
db={displaySpellIDWindow=true}
window:Initialize(db)
assert(panel.height==44 and not cast.shown and not instant.shown and not debuff.shown and not buff.shown)
local anchor=panel.point
fire('UNIT_SPELLCAST_SUCCEEDED','target',nil,20793,101)
assert(cast.shown and panel.height==122 and cast.strings[7].text=='Kobold Geomancer')
assert(panel.point==anchor,'height changes retain the bottom anchor')
assert(cast.point[5]==-48)
auras.player={{auraInstanceID=901,spellId=888,name='Curse',sourceUnit='target'}}
fire('UNIT_AURA','player',{})
assert(debuff.shown and panel.height==194 and debuff.point[5]==-120)
cast.scripts.OnMouseUp(cast,'RightButton')
assert(not cast.shown and debuff.shown and panel.height==122 and debuff.point[5]==-48)
fire('UNIT_SPELLCAST_SUCCEEDED','target',nil,20793,101)
assert(not cast.shown,'dismissed cast token stays hidden')
fire('UNIT_SPELLCAST_SUCCEEDED','target',nil,20793,102)
assert(cast.shown,'new cast can display again')
ctrlDown=true;cast.scripts.OnMouseUp(cast,'RightButton');ctrlDown=false
assert(window:IsBlacklisted(20793) and not cast.shown)
fire('UNIT_SPELLCAST_SUCCEEDED','target',nil,20793,103);assert(not cast.shown)
window:Initialize(db);assert(window:IsBlacklisted(20793),'blacklist survives reload')
assert(window:AddBlacklist(' 12544 '))
auras.target={{auraInstanceID=902,spellId=12544,name='Frost Armor',sourceUnit='friend'}}
fire('UNIT_AURA','target',{});assert(not buff.shown)
window:RemoveBlacklist(12544);fire('UNIT_AURA','target',{})
assert(buff.shown and buff.strings[7].text=='Helpful friend')
ctrlDown=true;buff.scripts.OnMouseUp(buff,'RightButton');ctrlDown=false
assert(not buff.shown and window:IsBlacklisted(12544))
window:RemoveBlacklist(12544);fire('UNIT_AURA','target',{})
assert(buff.shown,'removing blacklist also clears its dismissal token')
auras.target={{auraInstanceID=903,spellId=900,name='Unknown caster buff'}}
fire('UNIT_AURA','target',{})
assert(not buff.strings[6].shown and not buff.strings[7].shown and buff.height==52)
auras.target={{auraInstanceID=904,spellId=901,name='Hidden caster buff',sourceUnit='hidden'}}
fire('UNIT_AURA','target',{})
assert(buff.strings[6].shown and rawequal(buff.strings[7].text,secret) and buff.height==68)
local managerMessage
window.OpenBlacklist=function(_,message) managerMessage=message end
auras.target={{auraInstanceID=905,spellId=secret,name=secret,sourceUnit='target'}}
fire('UNIT_AURA','target',{})
ctrlDown=true;buff.scripts.OnMouseUp(buff,'RightButton');ctrlDown=false
assert(not buff.shown and managerMessage:find('restricted',1,true))
assert(not window:IsBlacklisted(secret))
for _,value in ipairs({'bad','-1','0','1.5','2147483648',secret}) do assert(not window:AddBlacklist(value)) end
for key,value in pairs(db.spellIDWindowBlacklist) do
    assert(type(key)=='number' and not issecretvalue(key) and value==true)
end
local ids=window:GetBlacklist();assert(#ids==1 and ids[1]==20793)
-- Legacy anchors migrate to a bottom point, preserving the former bottom edge.
db.spellIDWindowPosition={point='TOPLEFT',relativePoint='TOPLEFT',x=50,y=-40}
window:Initialize(db)
assert(panel.point[1]=='BOTTOMLEFT' and panel.point[5]==-326)
''')
print('PASS: collapsing rows, caster attribution, dismissal, blacklist persistence and anchor migration')

# A short-lived disarm can arrive in UNIT_AURA without a cast or readable scan.
lua.execute(r'''
ns.SpellIDWindow:Initialize({})
auras.player={};C_UnitAuras.GetAuraSlots=nil
C_UnitAuras.GetAuraDataByIndex=function() error('scan unavailable') end
local debuff=frames[5]
local disarm={sourceUnit='target',auraInstanceID=67130,spellId=6713,name='Disarm',isHarmful=true}
fire('UNIT_AURA','player',{addedAuras={disarm}})
assert(debuff.shown and debuff.strings[2].text==6713)
fire('UNIT_AURA','player',{addedAuras={{spellId=123,isHelpful=true,isHarmful=false}}})
assert(debuff.strings[2].text==6713,'helpful aura must not overwrite disarm')
fire('UNIT_AURA','player',{addedAuras={{spellId=123,isHarmful=secret}}})
assert(debuff.strings[2].text==6713,'restricted polarity is not classified')
ns.SpellIDWindow:AddBlacklist(6713)
fire('UNIT_AURA','player',{addedAuras={disarm}})
assert(not debuff.shown,'direct event respects blacklist')
ns.SpellIDWindow:RemoveBlacklist(6713)
C_UnitAuras.GetAuraDataByIndex=function(unit,index) return auras[unit][index] end
auras.player={disarm}
fire('UNIT_AURA','player',{addedAuras={disarm}})
local panel=AzerothFieldbookSpellIDWindow
advance(100);fire('UNIT_AURA','player',{});advance(21)
assert(not debuff.shown,'later scan must not extend the addition lifetime')
''')

lua.execute(r'''
-- Accessible event containers may contain restricted fields. issecrettable
-- describes their contents, not whether the whole container can be read.
ns.SpellIDWindow:Initialize({})
local debuff=frames[5]
C_UnitAuras.GetAuraSlots=function() error('slot query blocked') end
C_UnitAuras.GetAuraDataByIndex=function() error('indexed query blocked') end
local aura={sourceUnit='target',auraInstanceID=secret,spellId=secret,name=secret,isHarmful=true}
local added={aura};local update={addedAuras=added}
secretTables[aura]=true;secretTables[added]=true;secretTables[update]=true
fire('UNIT_AURA','player',update)
assert(debuff.shown and rawequal(debuff.strings[2].text,secret))
-- Slot enumeration succeeds but its data fetch returns nil: still try index.
C_UnitAuras.GetAuraSlots=function() return nil,7 end
C_UnitAuras.GetAuraDataBySlot=function() return nil end
C_UnitAuras.GetAuraDataByIndex=function(unit,index)
    if unit=='player' and index==1 then
        return {sourceUnit='target',auraInstanceID=67139,spellId=6713,name='Disarm'}
    end
end
fire('UNIT_AURA','player',{})
assert(debuff.strings[2].text==6713)
local lines={};ns.SpellIDWindow:Report(function(line) lines[#lines+1]=line end)
assert(table.concat(lines,'\n'):find('path=index fallback',1,true))
-- A later empty scan does not erase evidence of the last actual aura event.
C_UnitAuras.GetAuraSlots=function() return nil end
fire('PLAYER_REGEN_ENABLED')
lines={};ns.SpellIDWindow:Report(function(line) lines[#lines+1]=line end)
assert(table.concat(lines,'\n'):find('last event: path=index fallback',1,true))
assert(table.concat(lines,'\n'):find('Disarm 6713 blacklisted=false',1,true))
-- Entirely restricted updates and denied containers must fail safely.
fire('UNIT_AURA','player',secret)
forbiddenTables[update]=true
fire('UNIT_AURA','player',update)
''')

lua.execute(r'''
-- LOC has its own row, without a redundant [A]. Ordinary debuffs cannot erase it.
local settings={};ns.SpellIDWindow:Initialize(settings)
local loc=frames[7]
assert(ns.SpellIDWindow:ObserveLossOfControl(12345,'Disarming Smash','Disarm','Creature A','loc:1'))
assert(loc.shown and loc.strings[2].text==12345 and loc.strings[3].text=='Disarm')
assert(loc.strings[4].text=='Disarming Smash' and loc.strings[5].text=='Loss of Control on you')
assert(loc.strings[7].text=='Creature A')
fire('UNIT_AURA','player',{addedAuras={{sourceUnit='target',auraInstanceID=22,spellId=999,name='Other debuff',isHarmful=true}}})
assert(loc.shown and loc.strings[2].text==12345)
loc.scripts.OnMouseUp(loc,'RightButton');assert(not loc.shown)
assert(ns.SpellIDWindow:ObserveLossOfControl(12345,'Disarming Smash','Disarm',nil,'loc:1'))
assert(not loc.shown,'same application remains dismissed')
assert(ns.SpellIDWindow:ObserveLossOfControl(12345,nil,'DISARM',nil,'loc:2'))
assert(loc.shown and loc.strings[4].text=='Name unavailable' and not loc.strings[7].shown)
advance(121);assert(not loc.shown)
ns.SpellIDWindow:AddBlacklist(12345)
assert(ns.SpellIDWindow:ObserveLossOfControl(12345,nil,'Disarm',nil,'loc:3') and not loc.shown)
settings.displaySpellIDWindow=false;ns.SpellIDWindow:ApplySettings()
assert(not ns.SpellIDWindow:ObserveLossOfControl(54321,nil,'SCHOOL_INTERRUPT',nil,'loc:4'))
assert(not ns.SpellIDWindow:ObserveLossOfControl(secret,nil,nil,nil,'loc:5'))
''')

lua.execute(r'''
-- The portrait is a frozen rendering of the captured target, with a deliberate
-- assignment callback. It remains usable when dragging the window is locked.
local settings={spellIDWindowLocked=true};ns.SpellIDWindow:Initialize(settings)
local loc,portrait=frames[7],frames[12]
targetGUID='Creature-0-1-2-3-43-target'
function UnitGUID() return targetGUID end
local renders,assignments=0,0
function SetPortraitTexture(texture,unit)
    assert(unit=='target');renders=renders+1;texture.image=targetGUID
end
GameTooltip={lines={},SetOwner=function(self,owner) self.owner=owner end,
    SetText=function(self,value) self.lines={value} end,
    AddLine=function(self,value) self.lines[#self.lines+1]=value end,
    Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end}
local candidate={id=43,guid=targetGUID,name='Creature B',level=14,assign=function()
    assignments=assignments+1;return true
end}
assert(ns.SpellIDWindow:ObserveLossOfControl(6713,'Disarm','DISARM',nil,'portrait:1',candidate))
assert(portrait.shown and renders==1 and loc.strings[6].text=='Target:' and loc.strings[7].text=='Creature B')
assert(loc.strings[4].width==260 and loc.strings[3].width==106)
local frozen=portrait.texture.image
targetGUID='Creature-0-1-2-3-42-other';fire('PLAYER_TARGET_CHANGED')
assert(portrait.texture.image==frozen and renders==1)
portrait.scripts.OnEnter(portrait)
assert(GameTooltip.lines[1]=='Creature B' and GameTooltip.lines[2]:find('unverified',1,true))
portrait.scripts.OnClick(portrait,'LeftButton')
assert(assignments==1 and loc.strings[6].text=='Saved:' and GameTooltip.lines[2]:find('Assigned',1,true))
portrait.scripts.OnClick(portrait,'LeftButton');assert(assignments==1)
local opened
ns.SpellIDWindow:SetCreatureOpener(function(candidate) opened=candidate.id end)
ctrlDown=true;portrait.scripts.OnClick(portrait,'LeftButton');ctrlDown=false
assert(opened==43 and assignments==1,'Ctrl+Click also opens saved LOC rows')
-- An authoritative source later removes the target action and restores width.
ns.SpellIDWindow:ObserveLossOfControl(6713,'Disarm','DISARM','Creature A','portrait:1')
assert(not portrait.shown and loc.strings[6].text=='Cast by:' and loc.strings[4].width==310)
portrait.scripts.OnClick(portrait,'LeftButton');assert(assignments==1)
-- A stale token cannot render the newly selected creature as the old target.
ns.SpellIDWindow:ObserveLossOfControl(6713,'Disarm','DISARM',nil,'portrait:2',candidate)
assert(portrait.shown and portrait.texture.image==nil and renders==1)
assert(portrait.strings[1].shown,'unavailable portraits use the question-mark fallback')
portrait.scripts.OnEnter(portrait);assert(GameTooltip.lines[1]=='Creature B')
ns.InitializationBlocked=true
portrait.scripts.OnClick(portrait,'LeftButton');assert(assignments==1)
ns.InitializationBlocked=nil
portrait.scripts.OnClick(portrait,'RightButton')
assert(not portrait.shown and not loc.shown and not GameTooltip.shown)
portrait.scripts.OnClick(portrait,'LeftButton');assert(assignments==1)
ns.SpellIDWindow:ObserveLossOfControl(6713,'Disarm','DISARM',nil,'portrait:3',candidate)
advance(121);assert(not portrait.shown and not loc.shown)
ns.SpellIDWindow:ObserveLossOfControl(6713,'Disarm','DISARM',nil,'portrait:4',candidate)
ns.SpellIDWindow:AddBlacklist(6713);assert(not portrait.shown)
-- Rejected assignments stay available for retry after unlocking the entry.
ns.SpellIDWindow:RemoveBlacklist(6713)
candidate.assign=function() return false end
ns.SpellIDWindow:ObserveLossOfControl(6713,'Disarm','DISARM',nil,'portrait:5',candidate)
portrait.scripts.OnClick(portrait,'LeftButton');assert(loc.strings[6].text=='Target:')
candidate.assign=function() assignments=assignments+1;return true end
portrait.scripts.OnClick(portrait,'LeftButton');assert(assignments==2 and loc.strings[6].text=='Saved:')
''')
print('PASS: frozen target portraits, explicit assignment, lifecycle and layout')

lua.execute(r'''
-- Every observation route uses its own captured creature, including a buff
-- recipient that differs from its caster and a debuff source off target.
local settings={spellIDWindowIndefinite=true};ns.SpellIDWindow:Initialize(settings)
casting,channel=false,false;auras={player={},target={}}
C_UnitAuras={GetAuraDataByIndex=function(unit,index) return auras[unit][index] end}
local targets={target={id=43,name='Creature B',guid='Creature-0-1-2-3-43-B'},
    nameplate1={id=42,name='Creature A',guid='Creature-0-1-2-3-42-A'}}
function UnitGUID(unit) return targets[unit] and targets[unit].guid end
function UnitName(unit) return targets[unit] and targets[unit].name end
function SetPortraitTexture(texture,unit) texture.image=UnitGUID(unit) end
local assignments={}
local opened={}
ns.SpellIDWindow:SetCreatureOpener(function(candidate) opened[#opened+1]=candidate.id end)
ns.SpellIDWindow:SetAssignmentCapture(function(unit,spellID,kind)
    local target=targets[unit];if not target then return end
    local capturedID=target.id
    return {id=target.id,name=target.name,guid=target.guid,unit=unit,level=14,assign=function()
        if issecretvalue(spellID) then return false end
        assignments[#assignments+1]={id=capturedID,spellID=spellID,kind=kind};return true
    end}
end)
local cast,instant,debuff,buff=frames[3],frames[4],frames[5],frames[6]
local castPortrait,instantPortrait,debuffPortrait,buffPortrait=frames[8],frames[9],frames[10],frames[11]
casting,castID=true,456
fire('UNIT_SPELLCAST_START','target')
assert(castPortrait.shown and cast.strings[6].text=='Cast by:' and cast.strings[7].text=='Creature B')
casting=false
auras.target={{auraInstanceID=71,spellId=12544,name='Frost Armor',sourceUnit='nameplate1'}}
fire('UNIT_AURA','target',{})
assert(buffPortrait.shown and buff.strings[6].text=='Target:' and buff.strings[7].text=='Creature B')
buffPortrait.scripts.OnEnter(buffPortrait)
assert(GameTooltip.lines[1]=='Creature B' and GameTooltip.lines[2]:find('Another unit',1,true))
assert(GameTooltip.lines[3]=='Cast by: Creature A')
auras.player={{auraInstanceID=72,spellId=6713,name='Disarm',sourceUnit='nameplate1'}}
fire('UNIT_AURA','player',{})
assert(debuffPortrait.shown and debuff.strings[7].text=='Creature A')
assert(debuffPortrait.texture.image==targets.nameplate1.guid)
targets.target=targets.nameplate1;auras.target={};fire('PLAYER_TARGET_CHANGED')
assert(castPortrait.texture.image:find('43-B',1,true) and buffPortrait.texture.image:find('43-B',1,true))
ctrlDown=true
for _,portrait in ipairs({castPortrait,buffPortrait,debuffPortrait}) do portrait.scripts.OnClick(portrait,'LeftButton') end
ctrlDown=false
assert(opened[1]==43 and opened[2]==43 and opened[3]==42 and #assignments==0)
castPortrait.scripts.OnClick(castPortrait,'LeftButton')
buffPortrait.scripts.OnClick(buffPortrait,'LeftButton')
debuffPortrait.scripts.OnClick(debuffPortrait,'LeftButton')
assert(assignments[1].id==43 and assignments[1].spellID==456 and assignments[1].kind=='cast')
assert(assignments[2].id==43 and assignments[2].spellID==12544 and assignments[2].kind=='buff')
assert(assignments[3].id==42 and assignments[3].spellID==6713 and assignments[3].kind=='debuff')
castPortrait.scripts.OnClick(castPortrait,'LeftButton');assert(#assignments==3)
fire('UNIT_SPELLCAST_SUCCEEDED','target',secret,99,81)
assert(instantPortrait.shown and instant.strings[7].text=='Creature A')
instantPortrait.scripts.OnClick(instantPortrait,'LeftButton')
assert(assignments[4].id==42 and assignments[4].spellID==99)
ctrlDown=true;instantPortrait.scripts.OnClick(instantPortrait,'LeftButton');ctrlDown=false
assert(opened[4]==42 and #assignments==4)
channel,castID=true,567;fire('UNIT_SPELLCAST_CHANNEL_START','target');channel=false
castPortrait.scripts.OnEnter(castPortrait);assert(GameTooltip.lines[2]:find('channeling',1,true))
castPortrait.scripts.OnClick(castPortrait,'LeftButton');assert(assignments[5].spellID==567)
auras.player={{auraInstanceID=73,spellId=777,name='Unattributed'}}
fire('UNIT_AURA','player',{})
debuffPortrait.scripts.OnEnter(debuffPortrait)
assert(debuff.strings[2].text~=777,'unattributed player effects are ignored')
-- Secret IDs render but never enter a tooltip concatenation or assignment.
casting,castID=true,secret;fire('UNIT_SPELLCAST_START','target');casting=false
assert(castPortrait.shown and rawequal(cast.strings[2].text,secret))
castPortrait.scripts.OnEnter(castPortrait)
assert(GameTooltip.lines[3]:find('restricted',1,true))
assert(GameTooltip.lines[#GameTooltip.lines]:find('Ctrl+Click',1,true))
ctrlDown=true;castPortrait.scripts.OnClick(castPortrait,'LeftButton');ctrlDown=false
assert(opened[5]==42 and #assignments==5,'restricted IDs still allow navigation')
castPortrait.scripts.OnClick(castPortrait,'LeftButton');assert(#assignments==5 and cast.strings[6].text=='Cast by:')
-- Retargeting during aura/cast reads cannot associate the old spell with a new NPC.
local normalCast=UnitCastingInfo
UnitCastingInfo=function() targets.target={id=44,name='Creature C',guid='Creature-0-1-2-3-44-C'};return 'Cast',nil,nil,nil,nil,nil,nil,nil,456,82 end
fire('UNIT_SPELLCAST_START','target');assert(not castPortrait.shown)
UnitCastingInfo=normalCast
local normalAura=C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex=function(unit,index)
    if unit=='target' and index==1 then targets.target=targets.nameplate1;return {spellId=888,auraInstanceID=74,name='Buff'} end
end
fire('UNIT_AURA','target',{});assert(not buffPortrait.shown)
C_UnitAuras.GetAuraDataByIndex=normalAura
-- All row portraits follow expiry, dismissal, hiding and blacklist settings.
instantPortrait.scripts.OnClick(instantPortrait,'RightButton');assert(not instantPortrait.shown)
ns.SpellIDWindow:AddBlacklist(6713);assert(not debuffPortrait.shown)
settings.displaySpellIDWindow=false;ns.SpellIDWindow:ApplySettings()
for i=8,12 do assert(not frames[i].shown) end
''')
print('PASS: cast/channel/instant/buff/debuff portraits, secret IDs and capture races')

lua.execute(r'''
local window=ns.SpellIDWindow
local normalGUID=UnitGUID
for _,guid in ipairs({'Player-1-2','Pet-0-1-2-3-42-1','Vehicle-0-1-2-3-42-1',secret}) do
    window:Initialize({displaySpellIDWindow=true})
    controlled=false;exists=true;enemy=true
    UnitGUID=function() return guid end
    auras.player={{auraInstanceID=991,spellId=991,name='Excluded',sourceUnit='target'}}
    fire('UNIT_AURA','player',{})
    fire('UNIT_SPELLCAST_SUCCEEDED','target',nil,991,991)
    assert(not frames[3].shown and not frames[5].shown,'non-creature sources excluded')
end
UnitGUID=normalGUID
controlled=secret
UnitPlayerControlled=function() return secret end
window:Initialize({displaySpellIDWindow=true})
fire('UNIT_AURA','player',{})
assert(not frames[5].shown,'unknown ownership excluded')
''')
print('PASS: player, pet, vehicle, secret identity and unknown ownership exclusions')
