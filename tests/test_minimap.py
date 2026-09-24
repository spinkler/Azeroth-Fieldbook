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
journal:SetMinimapButton(false); assert(not button.shown)
ns.MinimapButton:Initialize(settings,book); assert(created==1 and not button.shown)
local restored=ns.CreateBestiaryJournal(settings,function() end)
assert(not restored:GetMinimapButton())
restored:SetMinimapButton(true); assert(button.shown)
restored:SetMinimapButton(false); restored:ResetDatabase(); assert(button.shown)
''')
print('PASS: minimap toggle, click, initialization reuse, persistence and reset')
