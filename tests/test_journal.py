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
db = {bestiary={creatures={[42]={spells={[123]={name='Test Trap'}},names={}}},entries={}}}
function check(v,msg) assert(v,msg) end
''')
root = Path(__file__).resolve().parents[1]
lua.execute(root.joinpath('BestiaryJournal.lua').read_text(), 'AzerothFieldbook', lua.globals().ns)
lua.execute(r'''
journal = ns.CreateBestiaryJournal(db,identify)
check(journal.entries[42].abilities['Test Trap'].state=='pending','migration requires review')
check(db.bestiary.creatures[42],'Bestiary storage uses the section namespace')
journal:Observe('target')
check(journal.entries[42].name=='Defias Test' and journal.entries[42].category=='Humanoid' and journal.entries[42].rank=='Elite','identity, creature type and elite rank')
check(journal.entries[42].levelMin==9 and journal.entries[42].levelMax==9,'observed level')
check(journal.entries[42].locations['Elwynn Forest'],'observed location')
journal:Observe('target')
check(journal.entries[42].sightings==1,'repeat observations deduplicated')
level=11; guid='Creature-0-1-2-3-42-2'; journal:Observe('mouseover')
check(journal.entries[42].levelMax==11 and journal.entries[42].sightings==2,'level range grows from observations only')
local separate = ns.CreateBestiaryJournal({bestiary={creatures={},entries={}}},identify)
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
journal:SetEntryConfirmed(42,false)
journal:SetAbility(42,'Test Trap','confirmed')
journal:SetEntryConfirmed(42,true)
check(#journal:ConfirmedNames(42)==1,'confirmed ability shown')
journal:SetEntryConfirmed(42,false)
check(journal:SetAbilityTooltip(42,'Test Trap',false),'unchecked ability saved')
journal:SetEntryConfirmed(42,true)
check(#journal:ConfirmedNames(42)==0,'unchecked ability hidden from tooltip')
journal:SetEntryConfirmed(42,false)
check(journal:SetAbilityTooltip(42,'Test Trap',true),'checked ability saved')
journal:SetEntryConfirmed(42,true)
check(#journal:ConfirmedNames(42)==1,'checked ability restored to tooltip')
journal:SetEntryConfirmed(42,false)
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
check(journal:SetOffense(42,'Fire',true) and journal.entries[42].offenses.Fire,'offensive school stored on creature')
check(journal:SetResistance(42,'Frost',true) and journal.entries[42].resistances.Frost,'resistance stored on creature')
check(journal:SetImmunity(42,'Shadow',true) and journal.entries[42].immunities.Shadow,'immunity stored on creature')
check(not journal:SetOffense(42,'Physical',true),'non-magic school rejected')
check(journal:SetBehaviour(42,'Hostile',true) and journal:SetBehaviour(42,'Neutral',true),'behaviour observations stored')
check(not journal.entries[42].behaviours.Hostile and journal.entries[42].behaviours.Neutral,'hostile and neutral remain mutually exclusive')
journal.entries[77]={id=77,name='Unknown Test',category='Not specified',abilities={},locations={},confirmed=false}
journal.entries[78]={id=78,name='Unreadable Test',category='Unclassified',abilities={},locations={},confirmed=false}
check(#journal:List('Unclassified','',false)==2,'unclassified filter includes not-specified entries')
journal.entries[77]=nil; journal.entries[78]=nil
check(#journal:List(nil,'',false,nil,{['Elwynn Forest']=true})==1,'location filter includes an observed location')
check(#journal:List(nil,'',false,nil,{Westfall=true})==0,'location filter excludes other locations')
check(#journal:List('Humanoid','',false,nil,{['Elwynn Forest']=true})==1,'location filter combines with creature type')
check(#journal:List('Beast','',false,nil,{['Elwynn Forest']=true})==0,'location filter does not override creature type')
journal:SetEntryConfirmed(42,true)
local beforeRevision=journal.revision
check(not journal:SetOffense(42,'Nature',true),'locked offense blocked')
check(not journal:SetResistance(42,'Fire',true),'locked resistance blocked')
check(not journal:SetImmunity(42,'Fire',true),'locked immunity blocked')
check(not journal:SetBehaviour(42,'Hostile',true),'locked behaviour blocked')
check(not journal:AddManual(42,'New ability',''),'locked manual ability blocked')
check(not journal:SetAbility(42,'Test Trap','rejected'),'locked review blocked')
check(not journal:SetAbilityTooltip(42,'Test Trap',false),'locked tooltip selection blocked')
check(not journal:RemoveAbility(42,'Test Trap'),'locked removal blocked')
check(not journal:AddDamage(42,9,1,2) and not journal:RemoveDamageNote(42,9,1),'locked damage changes blocked')
journal:Offer(42,'New automatic ability','Test',999)
local oldMax=journal.entries[42].levelMax
level=50; zone='New zone'; journal:Observe('target')
check(journal.entries[42].levelMax==oldMax and not journal.entries[42].locations['New zone'],'locked metadata unchanged')
level=10; zone='Elwynn Forest'
check(journal.revision==beforeRevision and not journal.entries[42].abilities['New automatic ability'],'locked automatic ability blocked')
check(journal:SetCreatureNotes(42,'Still editable') and journal:AddNoteSpell(42,'777'),'locked creature notes editable')
check(journal:RemoveNoteSpell(42,777),'locked manual ID removal allowed')
local restored=ns.CreateBestiaryJournal(db,identify)
check(restored.entries[42].confirmed and restored.entries[42].damage[9].high==24,'journal survives reload')
check(restored.entries[42].offenses.Fire and restored.entries[42].resistances.Frost and restored.entries[42].immunities.Shadow,'creature observations survive reload')
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
lua.execute(root.joinpath('CreatureNotes.lua').read_text(), 'AzerothFieldbook', lua.globals().ns)
lua.execute(root.joinpath('BestiaryBook.lua').read_text(), 'AzerothFieldbook', lua.globals().ns)
lua.execute(r'''
controller=ns.CreateBestiaryBook(journal)
controller:Toggle()
check(AzerothFieldbookBestiary:IsShown(),'book opens')
check(#UISpecialFrames==9 and BINDING_NAME_CLASSICBESTIARY_BOOK and BINDING_NAME_CLASSICBESTIARY_MOUSEOVER_BOOK,'escape and keybinding registration')
check(controller:OpenAtUnit('mouseover'),'mouseover binding opens the observed NPC page')
for _,o in ipairs(objects) do check(o.text~='Your note','empty manual field note stays visually empty') end
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
check(click('Locations') and AzerothFieldbookBestiaryLocations:IsShown(),'location filter window opens')
for _,control in ipairs({AzerothFieldbookBestiary.offenseButton,AzerothFieldbookBestiary.defenseButton,
    AzerothFieldbookBestiary.behaviourButton,AzerothFieldbookBestiary.effectButton,
    AzerothFieldbookBestiary.confirmAbilityButton,AzerothFieldbookBestiary.manualName}) do
    check(not control.enabled,'locked editor disabled')
end
check(AzerothFieldbookBestiary.creatureNotesButton.enabled,'notes button stays enabled')
check(click('Unlock this entry'),'confirmed entry unlocks')
check(not journal.entries[42].confirmed,'unlock state saved')
check(AzerothFieldbookBestiary.offenseButton.enabled and AzerothFieldbookBestiary.confirmAbilityButton.enabled,'unlock restores editing')
check(click('Offenses') and AzerothFieldbookBestiaryOffenses:IsShown(),'offenses window opens')
check(click('Defenses') and AzerothFieldbookBestiaryDefenses:IsShown(),'defenses window opens')
check(click('Behaviour') and AzerothFieldbookBestiaryBehaviour:IsShown(),'behaviour window opens')
check(click('Lock this entry'),'entry can be locked again')
local help=AzerothFieldbookHelp
help.scripts.OnShow(help)
check(journal:GetSpellIDWindowOption('displaySpellIDWindow'),'ID window defaults on')
check(not journal:GetSpellIDWindowOption('spellIDWindowLocked'),'ID window defaults unlocked')
check(not journal:GetSpellIDWindowOption('spellIDWindowIndefinite'),'ID window defaults expiring')
check(journal:GetSpellIDWindowOption('spellIDWindowAlpha')==0.35,'ID window default opacity')
help.spellIDWindowAlpha.scripts.OnValueChanged(help.spellIDWindowAlpha,0.7)
check(db.spellIDWindowAlpha==0.7,'opacity control saves setting')
help.spellIDWindowLocked.GetChecked=function() return true end
help.spellIDWindowLocked.scripts.OnClick(help.spellIDWindowLocked)
check(db.spellIDWindowLocked,'lock checkbox saves setting')
controller:Toggle(); check(not AzerothFieldbookBestiary:IsShown(),'book closes')
controller:Toggle(); check(AzerothFieldbookBestiary:IsShown(),'book reopens')
controller:OpenNotes()
local notes=AzerothFieldbookCreatureNotes
check(notes:IsShown() and notes.creature.text==journal.entries[42].name,'notes opens for selected creature')
notes.spellInput:SetText('6268'); notes.spellInput.scripts.OnEnterPressed(notes.spellInput)
notes.notes:SetText('Boar field notes')
journal:Ensure(43).name='Other creature'; controller:Refresh()
local function selectEntry(id)
    for _,row in ipairs(AzerothFieldbookBestiary.rows) do
        if row.id==id then row.scripts.OnClick(row); return end
    end
    error('entry not visible')
end
selectEntry(43)
check(notes.creature.text=='Other creature' and notes.count.text=='0/10','book selection switches notes')
selectEntry(42)
check(notes.count.text=='1/10' and notes.notes.text=='Boar field notes','book selection restores notes')
check(click('Creature Notes'),'creature notes button opens window')
local abilityBook=AzerothFieldbookBestiary
local savedAbilities=journal.entries[42].abilities
journal.entries[42].abilities={}
for i=1,4 do journal.entries[42].abilities['Ability '..i]={state='confirmed',spellID=i} end
controller:Refresh()
check(not abilityBook.abilityScrollBar:IsShown(),'four abilities fit without scrollbar')
journal.entries[42].abilities['Ability 5']={state='confirmed',spellID=5}; controller:Refresh()
check(abilityBook.abilityScrollBar:IsShown(),'fifth ability enables scrollbar')
abilityBook.abilityScrollBar.scripts.OnValueChanged(abilityBook.abilityScrollBar,1)
check(abilityBook.abilities[1].name=='Ability 2','scrollbar changes displayed abilities')
abilityBook.abilities[1].scripts.OnMouseWheel(abilityBook.abilities[1],1)
check(abilityBook.abilities[1].name=='Ability 1','mouse wheel changes displayed abilities')
journal.entries[42].abilities['Ability 5']=nil; controller:Refresh()
check(not abilityBook.abilityScrollBar:IsShown(),'scrollbar hides when abilities fit again')
journal.entries[42].abilities=savedAbilities; controller:Refresh()
local damageBook=AzerothFieldbookBestiary
local savedDamage=journal.entries[42].damage
journal.entries[42].damage={}
damageBook.damageScrollBar=CreateFrame('Frame')
for level=1,5 do journal.entries[42].damage[level]={low=10,high=20,reports=1} end
controller:Refresh()
for _, row in ipairs(damageBook.damageRows) do row.text.GetStringHeight=function() return 14 end end
controller:Refresh()
check(not damageBook.damageScrollBar:IsShown(),'five single-line damage rows need no scrollbar')
journal.entries[42].damage[6]={low=10,high=20,reports=1}; controller:Refresh()
check(damageBook.damageScrollBar:IsShown(),'six damage rows show scrollbar')
journal.entries[42].damage[6]=nil
local text=damageBook.damageRows[1].text
text.GetStringHeight=function() return 28 end
controller:Refresh()
check(damageBook.damageScrollBar:IsShown(),'wrapped damage text counts toward overflow')
text.GetStringHeight=function() return 14 end
controller:Refresh()
check(not damageBook.damageScrollBar:IsShown(),'scrollbar hides again when content fits')
journal.entries[42].damage=savedDamage; controller:Refresh()

check(click('Delete'),'delete button opens confirmation')
local deletion=AzerothFieldbookDeleteCreature
check(deletion:IsShown() and deletion.id==42,'confirmation identifies selected creature')
deletion.input:SetText('DELETE'); deletion.input.scripts.OnEnterPressed(deletion.input)
check(journal.entries[42],'incorrect confirmation preserves entry')
selectEntry(43)
check(not deletion:IsShown(),'changing selection cancels confirmation')
deletion.input:SetText('delete'); deletion.input.scripts.OnEnterPressed(deletion.input)
check(journal.entries[42] and journal.entries[43],'stale confirmation cannot delete either entry')
selectEntry(42); click('Delete')
deletion.input.scripts.OnEscapePressed(deletion.input)
check(journal.entries[42] and not deletion:IsShown(),'escape cancels deletion')
db.bestiary.creatures[42]={spells={}}
click('Delete'); deletion.input:SetText('delete'); deletion.input.scripts.OnEnterPressed(deletion.input)
check(not journal.entries[42] and not db.bestiary.creatures[42],'confirmed deletion removes locked entry and legacy data')
check(journal.entries[43] and not AzerothFieldbookBestiary.deleteButton.enabled,'other entries survive; no selection disables delete')
check(notes.count.text=='0/10','deleted creature notes cleared from window')
local reloaded=ns.CreateBestiaryJournal(db,function() return nil end)
check(not reloaded.entries[42],'deleted entry does not return through legacy migration')
local ranksDB={bestiary={entries={},creatures={}}}
local ranksJournal=ns.CreateBestiaryJournal(ranksDB,function() return nil end)
for i, rank in ipairs({'Elite','Rare','Rare Elite','World Boss'}) do
    local entry=ranksJournal:Ensure(i); entry.rank=rank; entry.name='Rank '..i
end
ranksJournal:Ensure(5).name='Ordinary'
check(#ranksJournal:List(nil,'',false,nil,nil,{})==5,'empty rank filter includes ordinary creatures')
check(#ranksJournal:List(nil,'',false,nil,nil,{Elite=true,Rare=true})==2,'rank filters combine with OR')
check(#ranksJournal:List(nil,'',false,nil,nil,{['Rare Elite']=true})==1,'rare elite is separately selectable')
check(#ranksJournal:List(nil,'Rank 4',false,nil,nil,{['World Boss']=true})==1,'rank combines with text')
check(#ranksJournal:List(nil,'Rank 1',false,nil,nil,{Rare=true})==0,'rank and text both required')
check(click('Ranks') and AzerothFieldbookBestiaryRanks:IsShown(),'rank picker opens')
journal:Reset(); controller:Refresh()
check(#journal:List(nil,'',false)==0,'reset clears book')
''')
print('PASS: journal review, creature types, level ranges, spell linking, damage notes, persistence and book interactions')
