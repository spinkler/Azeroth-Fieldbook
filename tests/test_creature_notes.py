from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''ns,db,objects,UISpecialFrames,UIParent={},{},{},{},{}
secret={}
function issecretvalue(v) return rawequal(v,secret) end
function InCombatLockdown() return true end
C_Spell={GetSpellName=function(id) return id==6268 and 'Rushing Charge' or secret end}
local methods={}
function methods:SetScript(k,f) self.scripts[k]=f end
function methods:SetText(v) self.text=v; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function methods:GetText() return self.text or '' end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:SetMaxLetters(v) self.limit=v end
function methods:SetShown(v) self.shown=v end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetEnabled(v) self.enabled=v end
function methods:SetFocus() self.focused=true end
function methods:SetVerticalScroll(v) self.scroll=v end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:GetVerticalScrollRange() return 0 end
function methods:CreateFontString() return CreateFrame('FontString') end
function methods:CreateTexture() return CreateFrame('Texture') end
function CreateFrame(kind,name,parent)
    local f=setmetatable({scripts={},kind=kind,parent=parent},{__index=function(_,k) return methods[k] or function() end end})
    objects[#objects+1]=f; if name then _G[name]=f end; return f
end
GameTooltip={lines={}}
function GameTooltip:SetOwner() end
function GameTooltip:SetSpellByID(id) self.id=id;self.lines={} end
function GameTooltip:AddLine(text) self.lines[#self.lines+1]=text end
function GameTooltip:Show() end
function GameTooltip:Hide() end
''')
for name in ['Scrollbars.lua','BestiaryJournal.lua','CreatureNotes.lua']:
    lua.execute((root/name).read_text(),'AzerothFieldbook',lua.globals().ns)
lua.execute(r'''journal=ns.CreateBestiaryJournal(db,function() return nil end)
journal:Ensure(1,false,'Mountain Boar')
journal:Ensure(2,false,'Geomancer')
assert(not journal:AddNoteSpell(nil,'6268'))
for _,input in ipairs({'abc','-1','0','1.5','2147483648','1e3'}) do assert(not journal:AddNoteSpell(1,input)) end
assert(not journal:AddNoteSpell(1,secret))
assert(journal:AddNoteSpell(1,' 6268 ')) -- Manual logging remains available in combat.
assert(not journal:AddNoteSpell(1,'6268'))
for id=1,9 do assert(journal:AddNoteSpell(1,tostring(id))) end
assert(not journal:AddNoteSpell(1,'10'))
assert(#journal:GetIDNotes(1).spells==10 and #journal:GetIDNotes(2).spells==0)
assert(journal:RemoveNoteSpell(1,5))
assert(journal:AddNoteSpell(1,'10'))
assert(journal:SetCreatureNotes(1,'Charges first.\nWatch the buff.'))
assert(journal:SetCreatureNotes(2,string.rep(string.char(195,169),401)))
assert(journal:GetIDNotes(2).text==string.rep(string.char(195,169),400))
assert(journal:SetCreatureNotes(2,'Uses wards.'))
local restored=ns.CreateBestiaryJournal(db,function() return nil end)
assert(restored:GetIDNotes(1).spells[1]==6268 and restored:GetIDNotes(2).text=='Uses wards.')
local notes=ns.CreateCreatureNotesWindow(journal)
notes:Open(1)
local frame=AzerothFieldbookCreatureNotes
assert(frame.shown and frame.creature.text=='Mountain Boar |cff999999[#1]|r')
assert(frame.notes.limit==400 and frame.notesBorder.shown and frame.notesArea.shown)
journal:SetEntryConfirmed(1,true)
notes:Open(1)
assert(frame.notes.enabled and frame.notesToggle.enabled)
frame.notesBorder.scripts.OnMouseDown(frame.notesBorder,'LeftButton')
assert(frame.notes.focused)
frame.notes:SetText('Personal note while locked')
assert(journal:GetIDNotes(1).text=='Personal note while locked' and journal.entries[1].confirmed)
frame.notes:SetText('Charges first.\nWatch the buff.')
assert(frame.count.text=='10/10' and frame.notes.text=='Charges first.\nWatch the buff.')
assert(frame.rows[1].text.text:find('|Hspell:6268|h[Rushing Charge]',1,true))
local fullHeight=frame.height
frame.rows[2].remove.scripts.OnClick()
assert(frame.count.text=='9/10' and frame.height==fullHeight-26)
frame.spellInput:SetText('134');frame.spellInput.scripts.OnEnterPressed(frame.spellInput)
assert(frame.count.text=='10/10' and frame.spellInput.text=='')
frame.notes:SetText('Saved automatically.\nSecond line.')
notes:SetCreature(2)
assert(frame.creature.text=='Geomancer |cff999999[#2]|r' and frame.count.text=='0/10' and frame.notes.text=='Uses wards.')
frame.spellInput:SetText('4979');frame.spellInput.scripts.OnEnterPressed(frame.spellInput)
assert(journal:GetIDNotes(2).spells[1]==4979)
notes:SetCreature(1)
assert(frame.notes.text=='Saved automatically.\nSecond line.' and frame.count.text=='10/10')
journal:SetSpellIDTooltips(true)
frame.rows[1].scripts.OnEnter()
assert(GameTooltip.id==6268 and GameTooltip.lines[1]=='Spell ID: 6268')
journal:SetSpellIDTooltips(false)
frame.rows[1].scripts.OnEnter()
assert(#GameTooltip.lines==0)
assert(journal:GetNotesFollowTarget())
local originalObserve=journal.Observe
local targetID=2
journal.Observe=function() return targetID end
notes:FollowTarget()
assert(frame.creature.text=='Geomancer |cff999999[#2]|r' and frame.notes.text=='Uses wards.')
notes:Refresh()
assert(frame.creature.text=='Geomancer |cff999999[#2]|r') -- Book refresh must not undo target following.
frame.notes:SetText('Target-follow note')
targetID=nil; notes:FollowTarget()
assert(frame.creature.text=='Geomancer |cff999999[#2]|r')
journal:SetNotesFollowTarget(false); targetID=1; notes:FollowTarget()
assert(frame.creature.text=='Geomancer |cff999999[#2]|r')
local restoredSettings=ns.CreateBestiaryJournal(db,function() return nil end)
assert(not restoredSettings:GetNotesFollowTarget())
journal:SetNotesFollowTarget(true); notes:FollowTarget()
assert(frame.creature.text=='Mountain Boar |cff999999[#1]|r' and journal:GetIDNotes(2).text=='Target-follow note')
local function escapeRegistered()
    for _,name in ipairs(UISpecialFrames) do if name=='AzerothFieldbookCreatureNotes' then return true end end
    return false
end
assert(escapeRegistered())
frame.pinButton.scripts.OnClick()
assert(not frame.closeButton.enabled and not escapeRegistered())
frame.closeButton.scripts.OnClick(); assert(frame.shown)
targetID=2; notes:FollowTarget(); assert(frame.creature.text=='Geomancer |cff999999[#2]|r')
frame.pinButton.scripts.OnClick()
assert(frame.closeButton.enabled and escapeRegistered())
frame.closeButton.scripts.OnClick(); assert(not frame.shown)
targetID=1; notes:FollowTarget(); assert(not frame.shown)
journal.Observe=originalObserve
journal:Offer(1176,'Bottle of Poison','Automatic observation',7365,'Tunnel Rat Forager')
notes:Open(1176)
assert(frame.creature.text=='Tunnel Rat Forager |cff999999[#1176]|r' and frame.notes.enabled and frame.spellInput.shown)
frame.notes:SetText('Encounter-only creature notes')
assert(journal:GetIDNotes(1176).text=='Encounter-only creature notes')
notes:Open(nil)
assert(frame.count.text=='0/10'  and not frame.spellInput.shown and frame.notes.text=='')
notes:Open(1)
journal:Reset()
notes:SetCreature(1)
assert(not frame.spellInput.shown and frame.notes.text=='')
''')
print('PASS: per-creature ID logs, limits, combat input, persistence, removal, notes switching and tooltip option')
