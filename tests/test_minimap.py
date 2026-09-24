from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'.codex-test-deps'))
from lupa.lua51 import LuaRuntime
lua=LuaRuntime()
lua.execute(r'''ns={}; created=0
local methods={}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:SetShown(v) self.shown=v end
function methods:SetTexture(v) self.texture=v end
function methods:GetFrameLevel() return 1 end
function methods:GetEffectiveScale() return rawget(self, 'scale') or 1 end
function methods:GetWidth() return 140 end
function methods:GetHeight() return 140 end
function methods:GetCenter() return 200,200 end
function methods:SetPoint(_,_,_,x,y) self.x=x; self.y=y end
function IsShiftKeyDown() return shift end
function GetCursorPosition() return cursorX,cursorY end
function methods:CreateTexture() local t=CreateFrame(); self.lastTexture=t; return t end
function CreateFrame(_,name)
 local f=setmetatable({scripts={}}, {__index=function(_,k)
 if k=='CreateMaskTexture' then return nil end
 return methods[k] or function() end
 end})
 if name then _G[name]=f; created=created+1 end
 return f
end
Minimap=CreateFrame()
settings={}; toggles=0
book={Toggle=function() toggles=toggles+1 end}
''')
root=Path(__file__).resolve().parents[1]
lua.execute((root/'MinimapButton.lua').read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
lua.execute((root/'BestiaryJournal.lua').read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)
lua.execute(r'''local journal=ns.CreateBestiaryJournal(settings,function() end)
ns.MinimapButton:Initialize(settings,book)
local button=AzerothFieldbookMinimapButton
assert(button.shown and journal:GetMinimapButton())
button.scripts.OnClick(); assert(toggles==1)
button.scripts.OnMouseDown(); cursorX,cursorY=300,200
button.scripts.OnDragStart()
assert(settings.minimapButtonAngle==0 and math.abs(button.x-78)<0.001)
cursorX,cursorY=200,300; button.scripts.OnUpdate()
button.scripts.OnDragStop(); button.scripts.OnClick()
assert(toggles==1 and settings.minimapButtonAngle==90 and math.abs(button.y-78)<0.001)
button.scripts.OnMouseDown(); shift=true; button.scripts.OnClick()
assert(settings.minimapButtonLocked and toggles==1)
shift=false; cursorX,cursorY=100,200; button.scripts.OnMouseDown(); button.scripts.OnDragStart()
assert(not button.scripts.OnUpdate and settings.minimapButtonAngle==90)
ns.MinimapButton:Initialize(settings,book)
assert(settings.minimapButtonLocked and math.abs(button.y-78)<0.001)
shift=true; button.scripts.OnClick(); shift=false
assert(not settings.minimapButtonLocked)
Minimap.scale=0.8; button.scale=1.2
ns.MinimapButton:UpdatePosition()
assert(math.abs(button.y-52)<0.001) -- Same map perimeter despite different UI scales.
Minimap.scale=1; button.scale=1
journal:SetMinimapButton(false); assert(not button.shown)
ns.MinimapButton:Initialize(settings,book); assert(created==1 and not button.shown)
local restored=ns.CreateBestiaryJournal(settings,function() end)
assert(not restored:GetMinimapButton())
restored:SetMinimapButton(true); assert(button.shown)
restored:SetMinimapButton(false); restored:ResetDatabase(); assert(button.shown)
''')
print('PASS: minimap toggle, click, initialization reuse, persistence and reset')
