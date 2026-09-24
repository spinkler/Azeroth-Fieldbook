from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
ns, frames, UISpecialFrames, UIParent = {}, {}, {}, {}
local methods = {}
function methods:SetScript(k,f) self.scripts[k]=f end
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetHeight() return self.height or 415 end
function methods:SetPoint() end
function methods:SetFrameStrata() end
function methods:SetClampedToScreen() end
function methods:SetMovable() end
function methods:EnableMouse() end
function methods:RegisterForDrag() end
function methods:StartMoving() end
function methods:StopMovingOrSizing() end
function methods:SetBackdrop() end
function methods:SetBackdropColor() end
function methods:SetMultiLine(v) self.multiline=v end
function methods:SetAutoFocus() end
function methods:SetFontObject() end
function methods:SetMaxLetters(v) self.maxLetters=v end
function methods:SetText(v) self.text=v end
function methods:SetCursorPosition(v) self.cursor=v end
function methods:SetFocus() self.focus=true end
function methods:ClearFocus() self.focus=false end
function methods:HighlightText() self.selected=true end
function methods:SetVerticalScroll(v) self.offset=v end
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:SetScrollChild(v) self.child=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function CreateFrame(kind,name,parent)
    local f=setmetatable({scripts={},kind=kind,parent=parent},{__index=methods})
    frames[#frames+1]=f
    return f
end
function methods:CreateFontString() return CreateFrame('FontString',nil,self) end
''')
lua.execute((Path(__file__).resolve().parents[1] / 'DebugReport.lua').read_text(), 'AzerothFieldbook', lua.globals().ns)
lua.execute(r'''
local report=string.rep('A long diagnostic line\n',500)
ns.ShowDebugReport(report)
local panel, scroll, edit=frames[1],frames[4],frames[5]
assert(panel.shown and edit.text==report and edit.selected and edit.focus)
assert(edit.multiline and edit.maxLetters==0 and scroll.child==edit)
assert(#UISpecialFrames==1)
edit.scripts.OnCursorChanged(edit,0,-800,0,14)
assert(scroll.offset==399)
edit.scripts.OnEscapePressed(edit)
assert(not panel.shown and not edit.focus)
local count=#frames
ns.ShowDebugReport('Replacement report')
assert(#frames==count and edit.text=='Replacement report' and scroll.offset==0)
edit.selected=false
frames[6].scripts.OnClick()
assert(edit.selected)
frames[7].scripts.OnClick()
assert(not panel.shown)
''')
print('PASS: debug report selection, scrolling, close, reuse and untruncated text')
