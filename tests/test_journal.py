from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
ns = {}
secret = {}
function issecretvalue(v) return rawequal(v,secret) end
name, category, classification, zone, level, npcID, guid = 'Defias Test', 'Humanoid', 'elite', 'Elwynn Forest', 9, 42, 'Creature-0-1-2-3-42-1'
function UnitName() return name end
function UnitCreatureType() return category end
function UnitClassification() return classification end
function GetRealZoneText() return zone end
function UnitLevel() return level end
function UnitGUID() return guid end
function identify() return npcID end
combat = false
function InCombatLockdown() return combat end
C_Spell = {GetSpellName=function(id) if id==123 then return 'Test Trap' elseif id==2139 then return 'Counterspell' end end,
    GetSpellLink=function(id) return '|Hspell:'..id..'|h[Test Trap]|h' end,
    GetSpellIDForSpellIdentifier=function(name) if name=='Counterspell' then return 2139 end end,
    GetSpellInfo=function(name) if name=='Counterspell' then return {spellID=2139} end end}
db = {creatures={[42]={spells={[123]={name='Test Trap'}},names={}}}}
function check(v,msg) assert(v,msg) end
''')
root = Path(__file__).resolve().parents[1]
lua.execute(root.joinpath('Journal.lua').read_text(), 'ClassicBestiary', lua.globals().ns)
lua.execute(r'''
journal = ns.CreateJournal(db,identify)
check(journal.entries[42].abilities['Test Trap'].state=='pending','migration requires review')
journal:Observe('target')
check(journal.entries[42].name=='Defias Test' and journal.entries[42].category=='Humanoid' and journal.entries[42].rank=='Elite','identity, creature type and elite rank')
check(journal.entries[42].levelMin==9 and journal.entries[42].levelMax==9,'observed level')
check(journal.entries[42].locations['Elwynn Forest'],'observed location')
journal:Observe('target')
check(journal.entries[42].sightings==1,'repeat observations deduplicated')
level=11; guid='Creature-0-1-2-3-42-2'; journal:Observe('mouseover')
check(journal.entries[42].levelMax==11 and journal.entries[42].sightings==2,'level range grows from observations only')
local separate = ns.CreateJournal({creatures={}},identify)
name='Defias Trapper'; level=14; separate:Observe('target')
level=15; guid='Creature-0-1-2-3-42-3'; separate:Observe('mouseover')
check(#separate:List(nil,'',false)==1,'different levels do not duplicate an NPC')
check(separate.entries[42].levelMin==14 and separate.entries[42].levelMax==15,'level range 14-15')
npcID=43; separate:Observe('target')
check(#separate:List(nil,'',false)==2,'different NPC IDs retain distinct identities')
npcID=42; name='Defias Test'
level=secret; category=secret; name=secret; journal:Observe('target')
check(journal.entries[42].name=='Defias Test' and journal.entries[42].category=='Humanoid','secret metadata never replaces observations')
name='Defias Test'; category='Humanoid'; level=10
npcID=nil; check(not journal:Observe('target'),'players excluded by identity gate'); npcID=42
check(#journal:ConfirmedNames(42)==0,'unconfirmed entry and ability hidden')
journal:SetEntryConfirmed(42,true)
check(#journal:ConfirmedNames(42)==0,'entry confirmation does not confirm ability')
journal:SetAbility(42,'Test Trap','confirmed')
check(#journal:ConfirmedNames(42)==1,'confirmed ability shown')
check(journal:SetAbilityTooltip(42,'Test Trap',false) and #journal:ConfirmedNames(42)==0,'unchecked ability hidden from tooltip')
check(journal:SetAbilityTooltip(42,'Test Trap',true) and #journal:ConfirmedNames(42)==1,'checked ability restored to tooltip')
journal:SetAbility(42,'Test Trap','rejected'); journal:Offer(42,'Test Trap')
check(#journal:ConfirmedNames(42)==0,'rejection survives rescans')
check(journal:RemoveAbility(42,'Test Trap'),'rejected ability removable')
journal:Offer(42,'Test Trap')
check(not journal.entries[42].abilities['Test Trap'],'removed automatic ability stays dismissed')
local ok,msg=journal:AddManual(42,'Test Trap','Roots the victim.','123',{['Root/Immobilize']=true})
check(ok and journal.entries[42].abilities['Test Trap'].spellID==123 and journal.entries[42].abilities['Test Trap'].effects['Root/Immobilize'],'manual note stores selected effects')
ok=journal:AddManual(42,'Wrong name','','123'); check(not ok,'mismatched linked spell rejected')
local resolvedID,resolvedName=journal:ResolveSpell('Counterspell')
check(resolvedID==2139 and resolvedName=='Counterspell','exact-name resolve uses client spell lookup')
ok=journal:AddManual(42,'','','|cff71d5ff|Hspell:123:0|h[Test Trap]|h|r'); check(ok,'pasted spell hyperlink resolved')
combat=true; ok=journal:AddManual(42,'Test Trap','','123'); check(not ok,'spell linking blocked in combat')
ok=journal:AddManual(42,'Another observed ability','No link'); check(ok,'plain notes usable without spell APIs')
combat=false
ok=journal:AddManual(999,'Unknown creature ability',''); check(not ok,'no unseen NPC creation from manual notes')
ok=journal:AddManual(42,'|T123:10|tTest',''); check(ok,'markup stripped from notes')
check(not journal.entries[42].abilities['|T123:10|tTest'],'no executable markup stored')
ok=journal:AddDamage(42,9,12,20); check(ok,'equal-level observation')
ok=journal:AddDamage(42,9,10,24); check(ok,'second damage note')
check(journal.entries[42].damage[9].low==10 and journal.entries[42].damage[9].high==24,'damage range accumulates at same level')
check(#journal:DamageNotes(42,9)==2,'individual damage notes retained')
check(journal:RemoveDamageNote(42,9,1),'individual damage note removable')
check(#journal:DamageNotes(42,9)==1 and journal.entries[42].damage[9].low==10,'range recalculated after removal')
ok=journal:AddDamage(42,12,1,2); check(not ok,'unobserved mob level rejected')
ok=journal:AddDamage(42,9,30,2); check(not ok,'reversed range rejected')
check(#journal:List('Humanoid','defias',false)==1,'name search and category')
check(#journal:List(nil,'',false,'D')==1 and #journal:List(nil,'',false,'M')==0,'alphabet index filter')
check(#journal:List(nil,'humanoid',false)==1,'type searchable')
check(#journal:List('Beast','',false)==0,'category isolation')
journal.entries[77]={id=77,name='Unknown Test',category='Not specified',abilities={},locations={},confirmed=false}
journal.entries[78]={id=78,name='Unreadable Test',category='Unclassified',abilities={},locations={},confirmed=false}
check(#journal:List('Unclassified','',false)==2,'unclassified filter includes not-specified entries')
journal.entries[77]=nil; journal.entries[78]=nil
check(#journal:List(nil,'',false,nil,{['Elwynn Forest']=true})==1,'location filter includes an observed location')
check(#journal:List(nil,'',false,nil,{Westfall=true})==0,'location filter excludes other locations')
check(#journal:List('Humanoid','',false,nil,{['Elwynn Forest']=true})==1,'location filter combines with creature type')
check(#journal:List('Beast','',false,nil,{['Elwynn Forest']=true})==0,'location filter does not override creature type')
local restored=ns.CreateJournal(db,identify)
check(restored.entries[42].confirmed and restored.entries[42].damage[9].high==24,'journal survives reload')
check(restored.entries[42].abilities['Test Trap'].state=='confirmed','migration does not reset confirmation')
''')
# Native-widget mock: execute construction, selection, edits, scrolling and reopen.
lua.execute(r'''
objects={}
local methods={}
function methods:SetScript(event,fn) self.scripts[event]=fn end
function methods:SetText(text)
    self.text=text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return rawget(self,'text') or '' end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:GetWidth() return self.width or 1920 end
function methods:GetHeight() return self.height or 1080 end
function methods:GetStringHeight() return 32 end
function methods:GetFrameLevel() return 10 end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
function methods:SetEnabled(v) self.enabled=v end
local function noop() end
local function object(kind,parent)
    local o={kind=kind,parent=parent,scripts={},shown=true,enabled=true}
    setmetatable(o,{__index=function(_,key) return methods[key] or noop end})
    objects[#objects+1]=o
    return o
end
function methods:CreateTexture() return object('Texture',self) end
function methods:CreateFontString() return object('FontString',self) end
function CreateFrame(kind,name,parent)
    local o=object(kind,parent)
    if name then _G[name]=o end
    return o
end
UIParent=CreateFrame('Frame'); UIParent:SetSize(1920,1080)
UISpecialFrames={}
''')
lua.execute(root.joinpath('Book.lua').read_text(), 'ClassicBestiary', lua.globals().ns)
lua.execute(r'''
controller=ns.CreateBook(journal)
controller:Toggle()
check(ClassicBestiaryBook:IsShown(),'book opens')
check(#UISpecialFrames==4 and BINDING_NAME_CLASSICBESTIARY_BOOK and BINDING_NAME_CLASSICBESTIARY_MOUSEOVER_BOOK,'escape and keybinding registration')
check(controller:OpenAtUnit('mouseover'),'mouseover binding opens the observed NPC page')
local function click(text)
    for _,o in ipairs(objects) do
        if o.kind=='Button' and o.text==text and o.scripts.OnClick then o.scripts.OnClick(o); return true end
    end
    return false
end
check(click('Record equal-level hits'),'damage form opens')
check(click('Cancel'),'damage form closes')
check(click('All'),'category selection')
check(click('D'),'alphabet tab')
check(click('Index'),'alphabet index reset')
check(click('Next') and click('Previous'),'entry navigation buttons')
check(click('Pending'),'review filter')
check(click('All entries'),'review filter clears')
check(click('Locations') and ClassicBestiaryLocations:IsShown(),'location filter window opens')
check(click('Unlock this entry'),'confirmed entry unlocks')
check(not journal.entries[42].confirmed,'unlock state saved')
check(click('Lock this entry'),'entry can be locked again')
controller:Toggle(); check(not ClassicBestiaryBook:IsShown(),'book closes')
controller:Toggle(); check(ClassicBestiaryBook:IsShown(),'book reopens')
journal:Reset(); controller:Refresh()
check(#journal:List(nil,'',false)==0,'reset clears book')
''')
print('PASS: journal review, creature types, level ranges, spell linking, damage notes, persistence and book interactions')
