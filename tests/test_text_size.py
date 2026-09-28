"""Font isolation, exact defaults and consistent reload semantics."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime()
lua.execute('''
ns={}
function CreateFont(name)
    local f={name=name,path='font.ttf',size=12,flags='OUTLINE',colour='gold'}
    function f:CopyFontObject(source)
        self.path,self.size,self.flags,self.colour=source.path,source.size,source.flags,source.colour
    end
    function f:GetFont() return self.path,self.size,self.flags end
    function f:SetFont(path,size,flags) self.path,self.size,self.flags=path,size,flags end
    _G[name]=f; return f
end
base=CreateFont('GameFontHighlight')
heading=CreateFont('GameFontNormalLarge');heading.size=16
''')
source = (Path(__file__).resolve().parents[1] / 'TextSize.lua').read_text(encoding='utf-8')
lua.execute(source, 'AzerothFieldbook', lua.globals().ns)
lua.execute('''
local t=ns.TextSize
assert(t:Get()==0 and t:Font('GameFontHighlight')=='GameFontHighlight')
assert(t:Font(base)==base and not t:NeedsReload())
-- Native template controls must receive no font calls at the default size.
local untouched=setmetatable({}, {__index=function(_,key)
    error('Default size accessed native font API: '..key)
end})
t:StyleControl(untouched)
t:Set(3);assert(t:Get()==3 and t:NeedsReload())
assert(t:Font('GameFontNormalLarge')=='GameFontNormalLarge', 'Late windows keep active size')
t:Set(0);assert(not t:NeedsReload())
t:Set(999);assert(t:Get()==3)
t:Set(-999);assert(t:Get()==-3)
t:Set(1.2);assert(t:Get()==1)
t:Set('invalid');assert(t:Get()==0)
t:Set(0/0);assert(t:Get()==0)
t:Set(2)
''')
# A new module instance simulates the UI reload, retaining SavedVariables.
lua.execute(source, 'AzerothFieldbook', lua.globals().ns)
lua.execute('''
local t=ns.TextSize
local name=t:Font('GameFontHighlight')
assert(type(name)=='string', 'CreateFontString requires a template name')
local font=_G[name]
assert(font.size==14 and font.flags=='OUTLINE' and font.colour=='gold')
assert(base.size==12 and heading.size==16, 'Shared Blizzard fonts must not change')
assert(_G[t:Font('GameFontNormalLarge')].size==18)
assert(t:Font(name)==name and t:Font(font)==font, 'Never apply offset twice')
assert(t:Font('GameFontHighlight')==name, 'Reuse cloned fonts')
assert(t:Font(base).size==14 and not t:NeedsReload())
local control={normal=base,disabled=base}
function control:GetNormalFontObject() return self.normal end
function control:SetNormalFontObject(f) self.normal=f end
function control:GetDisabledFontObject() return self.disabled end
function control:SetDisabledFontObject(f) self.disabled=f end
t:StyleControl(control);t:StyleControl(control)
assert(control.normal.size==14 and control.disabled.size==14)
-- Forever's EditBox:GetFontObject can expose its own native font wrapper.
-- Reassigning it caused the supplied 0xC00000FD crash; copying a wrapper back
-- through a new font object is not a safe workaround either. Use font values.
function editBox()
    local edit={size=12,writes=0}
    function edit:GetFontObject() error('Unsafe EditBox font wrapper read') end
    function edit:SetFontObject() error('Native font inheritance cycle / stack overflow') end
    function edit:GetFont() return 'edit.ttf',self.size,'OUTLINE' end
    function edit:SetFont(path,size,flags)
        assert(path=='edit.ttf' and flags=='OUTLINE')
        self.size=size;self.writes=self.writes+1
    end
    return edit
end
local edit=editBox()
t:StyleControl(edit);t:StyleControl(edit)
assert(edit.size==14 and edit.writes==1, 'Resize directly without compounding or font inheritance')
t:Set(-3);assert(font.size==14 and t:NeedsReload())
local late=editBox();t:StyleControl(late);assert(late.size==14)
''')
lua.execute(source, 'AzerothFieldbook', lua.globals().ns)
lua.execute('''
assert(_G[ns.TextSize:Font('GameFontHighlight')].size==9)
local edit=editBox();ns.TextSize:StyleControl(edit);assert(edit.size==9)
''')
print('PASS: text size defaults, seven steps, font isolation, templates and reload persistence')
