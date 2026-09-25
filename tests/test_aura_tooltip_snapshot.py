from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''ns, UIParent, objects, hooks = {}, {}, {}, {}
secret=setmetatable({}, {__tostring=function() error('secret stringify') end, __concat=function() error('secret concat') end})
function issecretvalue(v) return rawequal(v,secret) end
now=0
function GetTime() return now end
local methods={}
function methods:SetScript(k,f) self.scripts[k]=f end
function methods:SetText(v) self.text=v end
function methods:GetStringHeight()
    assert(not issecretvalue(self.text),'must not measure secret text')
    return self.text=='Wrapped public description' and 28 or 14
end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetHeight(h) self.height=h end
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:SetBackdropColor(r,g,b,a) self.alpha=a end
function methods:SetScrollChild(f) self.child=f end
function methods:CreateFontString() return CreateFrame('FontString') end
function CreateFrame(kind,name)
    local f=setmetatable({scripts={},kind=kind}, {__index=function(_,k) return methods[k] or function() end end})
    objects[#objects+1]=f
    if name then _G[name]=f end
    return f
end
GameTooltip={}
function GameTooltip:IsForbidden() return forbidden end
function GameTooltip:IsShown() return true end
function GameTooltip:NumLines() return lineCount end
function GameTooltip:GetOwner() return {GetFilter=function() return 'HARMFUL' end} end
for _,name in ipairs({'SetUnitBuff','SetUnitDebuff','SetUnitAura','SetUnitAuraByAuraInstanceID'}) do GameTooltip[name]=function() end end
function hooksecurefunc(_,name,f) assert(not hooks[name]); hooks[name]=f end
function hover(method,unit,filter) hooks[method](GameTooltip,unit,secret,filter) end
GameTooltipTextLeft1={GetText=function() return secret end}
GameTooltipTextRight1={GetText=function() return nil end}
GameTooltipTextLeft2={GetText=function() return 'Spell ID: 6268' end}
GameTooltipTextRight2={GetText=function() return nil end}
lineCount=2
''')
lua.execute((Path(__file__).resolve().parents[1]/'AuraTooltipSnapshot.lua').read_text(),'AzerothFieldbook',lua.globals().ns)
lua.execute(r'''db={displaySpellIDWindow=true,spellIDWindowAlpha=0.35}
local function eligible(unit,kind)
    if unit=='target' and kind=='buff' and not playerTarget then return 'Buff on target' end
    if unit=='player' and kind=='debuff' then return 'Debuff on you' end
end
ns.AuraTooltipSnapshot:Initialize(db,{},eligible)
local panel=AzerothFieldbookAuraSnapshot
assert(db.displayHoveredAuraSnapshots==false,'hover retention defaults off')
hover('SetUnitBuff','target'); assert(not panel.shown,'default-off does not duplicate last-observed information')
db.displayHoveredAuraSnapshots=true; ns.AuraTooltipSnapshot:ApplySettings()
hover('SetUnitBuff','target')
assert(panel.shown and panel.height==112) -- Secret wrapping allowance plus compact public line.
local found
for _,o in ipairs(objects) do if rawequal(o.text,secret) then found=o end end
assert(found) -- Relayed without interpreting the secret text.
GameTooltipTextLeft1.GetText=function() return 'Different tooltip' end
assert(rawequal(found.text,secret)) -- Snapshot is independent of the original fontstring.
now=119; panel.scripts.OnUpdate(); assert(panel.shown)
now=120; panel.scripts.OnUpdate(); assert(not panel.shown)
playerTarget=true
hover('SetUnitBuff','target'); assert(not panel.shown)
playerTarget=false
hover('SetUnitBuff','player'); assert(not panel.shown)
hover('SetUnitAuraByAuraInstanceID','player'); assert(panel.shown) -- Owner identifies harmful aura.
panel.scripts.OnMouseUp(panel,'RightButton'); assert(not panel.shown)
forbidden=true
hover('SetUnitBuff','target'); assert(not panel.shown)
forbidden=false; lineCount=secret
hover('SetUnitBuff','target'); assert(not panel.shown)
local report
ns.AuraTooltipSnapshot:Report(function(v) if v:find("Hovered aura snapshot:",1,true) then report=v end end)
assert(report:find('line count unavailable',1,true))
lineCount=2; db.spellIDWindowIndefinite=true
hover('SetUnitDebuff','player'); now=1000; panel.scripts.OnUpdate(); assert(panel.shown)
db.displaySpellIDWindow=false; ns.AuraTooltipSnapshot:ApplySettings(); assert(panel.shown)
db.displayHoveredAuraSnapshots=false; ns.AuraTooltipSnapshot:ApplySettings(); assert(not panel.shown)
hover('SetUnitDebuff','player'); assert(not panel.shown)
ns.AuraTooltipSnapshot:Initialize(db,{},eligible) -- No duplicate hooks; preference persists.
assert(not db.displayHoveredAuraSnapshots)
db.displayHoveredAuraSnapshots=true
GameTooltipTextLeft1.GetText=function() return 'Wrapped public description' end
hover('SetUnitDebuff','player')
assert(panel.shown and panel.height==108) -- 28px wrapped line + 14px ID + spacing/header.
ns.AuraTooltipSnapshot:Initialize(db,{},eligible)
assert(db.displayHoveredAuraSnapshots==true,'saved opt-in survives reload')
hover('SetUnitDebuff','player'); assert(panel.shown)
local fresh={}; ns.AuraTooltipSnapshot:Initialize(fresh,{},eligible)
assert(fresh.displayHoveredAuraSnapshots==false and not panel.shown,'fresh settings and reset default off')
''')
print('PASS: tooltip text relay, classification, access failure, expiry, disable and hook reuse')
