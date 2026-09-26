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
check(not journal.entries[42],'migration waits for a usable creature name')
check(db.bestiary.creatures[42],'Bestiary storage uses the section namespace')
journal:Observe('target')
check(journal.entries[42].abilities['Test Trap'].state=='pending','identified legacy observations require review')
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
local older=journal:DamageNotes(42,9)[1]
older.playerLevel=nil; older.creatureLevel=nil
check(journal:DamageNotes(42,9)[1].playerLevel==9,'old notes retain their equal-level meaning')
check(journal:AddDamage(42,9,11,23,15),'unequal levels allowed')
local different=journal:DamageNotes(42,9)[2]
check(different.playerLevel==15 and different.creatureLevel==9,'both levels recorded separately')
for _,invalid in ipairs({'',0,-1,1.5,'abc'}) do
    check(not journal:AddDamage(42,9,1,2,invalid),'invalid player level rejected')
end
check(#journal:List('Humanoid','defias',false)==1,'name search and category')
check(#journal:List(nil,'',false,'D')==1 and #journal:List(nil,'',false,'M')==0,'alphabet index filter')
check(#journal:List(nil,'humanoid',false)==1,'type searchable')
check(#journal:List('Beast','',false)==0,'category isolation')
check(journal:SetOffense(42,'Fire',true) and journal.entries[42].offenses.Fire,'offensive school stored on creature')
check(journal:SetResistance(42,'Frost',true) and journal.entries[42].resistances.Frost,'resistance stored on creature')
check(journal:SetImmunity(42,'Shadow',true) and journal.entries[42].immunities.Shadow,'immunity stored on creature')
check(not journal:SetOffense(42,'Physical',true),'non-magic school rejected')
check(journal:SetBehaviour(42,'Hostile',true) and journal:SetBehaviour(42,'Neutral',true),'behaviour observations stored')
check(not journal:SetBehaviour(42,'Tameable',true),'tameability is no longer a behaviour')
GetLocale=function() return 'enUS' end
C_TooltipInfo={GetUnit=function() return {lines={{leftText='Tameable'}}} end}
journal:ObserveTameability('target')
check(journal.entries[42].tameable==true,'explicit game tooltip records tameability')
C_TooltipInfo.GetUnit=function() return {lines={{leftText='Cannot be Tamed'}}} end
journal:ObserveTameability('target')
check(journal.entries[42].tameable==false,'explicit negative is recorded')
C_TooltipInfo.GetUnit=function() return {lines={{leftText='Beast'}}} end
journal:ObserveTameability('target')
check(journal.entries[42].tameable==false,'missing data does not infer tameability')
C_TooltipInfo.GetUnit=function() return {lines={{leftText='Tameable'}}} end
journal:ObserveTameability('target')
C_TooltipInfo.GetUnit=function() error('restricted') end
journal:ObserveTameability('target')
check(journal.entries[42].tameable==true,'API failures preserve observed status')
C_TooltipInfo=nil
check(not journal.entries[42].behaviours.Hostile and journal.entries[42].behaviours.Neutral,'hostile and neutral remain mutually exclusive')
journal.entries[77]={id=77,name='Unknown Test',category='Not specified',abilities={},locations={},confirmed=false}
journal.entries[78]={id=78,name='Unreadable Test',category='Unclassified',abilities={},locations={},confirmed=false}
journal.entries[79]={id=79,name='Totem Test',category='Totem',abilities={},locations={},confirmed=false}
journal.entries[80]={id=80,name='Gas Test',category='Gas Cloud',abilities={},locations={},confirmed=false}
check(#journal:List('Other','',false)==4,'other filter combines unclassified, unspecified, totems and gas clouds')
journal.entries[77]=nil; journal.entries[78]=nil; journal.entries[79]=nil; journal.entries[80]=nil
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
check(not journal:SetBehaviour(42,'Tameable',false),'locked tameability protected')
check(not journal:AddManual(42,'New ability',''),'locked manual ability blocked')
check(not journal:SetAbility(42,'Test Trap','rejected'),'locked review blocked')
check(not journal:SetAbilityTooltip(42,'Test Trap',false),'locked tooltip selection blocked')
check(not journal:RemoveAbility(42,'Test Trap'),'locked removal blocked')
check(not journal:AddDamage(42,9,1,2) and not journal:RemoveDamageNote(42,9,1),'locked damage changes blocked')
journal:Offer(42,'New automatic ability','Test',999)
check(journal.revision==beforeRevision,'locked field edits leave revision unchanged')
local oldMax=journal.entries[42].levelMax
level=50; zone='New zone'; journal:Observe('target')
check(journal.entries[42].levelMax==oldMax and not journal.entries[42].locations['New zone'],'locked metadata unchanged')
level=10; zone='Elwynn Forest'
check(not journal.entries[42].abilities['New automatic ability'],'locked automatic ability blocked')
check(journal:SetCreatureNotes(42,'Still editable') and journal:AddNoteSpell(42,'777'),'locked creature notes editable')
check(journal:RemoveNoteSpell(42,777),'locked manual ID removal allowed')
local restored=ns.CreateBestiaryJournal(db,identify)
check(restored.entries[42].tameable and restored.entries[42].tameabilitySource=='gameTooltip','game tameability survives reload')
check(restored.entries[42].confirmed and restored.entries[42].damage[9].high==24,'journal survives reload')
check(restored:DamageNotes(42,9)[2].playerLevel==15,'unequal-level observation survives reload')
check(restored.entries[42].offenses.Fire and restored.entries[42].resistances.Frost and restored.entries[42].immunities.Shadow,'creature observations survive reload')
check(restored.entries[42].abilities['Test Trap'].state=='confirmed','migration does not reset confirmation')
''')
# Native-widget mock: execute construction, selection, edits, scrolling and reopen.
lua.execute(r'''
objects={}
local methods={}
function methods:SetScript(event,fn) self.scripts[event]=fn end
function methods:HookScript(event,fn)
    local previous=self.scripts[event]
    self:SetScript(event,function(self,...)
        if previous then previous(self,...) end
        fn(self,...)
    end)
end
function methods:SetText(text)
    self.text=text
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return rawget(self,'text') or '' end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width or 1920 end
function methods:GetHeight() return self.height or 1080 end
function methods:SetScale(value) self.scale=value end
function methods:GetScale() return rawget(self,'scale') or 1 end
function methods:GetEffectiveScale()
    local parent=rawget(self,'parent')
    return self:GetScale()*(parent and parent:GetEffectiveScale() or 1)
end
function methods:SetNormalFontObject(value) self.normalFont=value end
function methods:SetIndentedWordWrap(value) self.indentedWrap=value end
function methods:GetStringWidth()
    local text=self:GetText():gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
    local _,characters=text:gsub('[^\128-\191]','')
    return characters*6
end
function methods:GetStringHeight()
    if self.indentedWrap then return math.max(1,math.ceil(self:GetStringWidth()/self:GetWidth()))*14 end
    return 32
end
function methods:GetFrameLevel() return 10 end
function methods:GetVerticalScroll() return 0 end
function methods:GetVerticalScrollRange() return 0 end
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
function methods:GetName() return self.name end
function CreateFrame(kind,name,parent)
    local o=object(kind,parent)
    if name then _G[name]=o; o.name=name end
    return o
end
function CreateFont(name)
    local font={}
    function font:CopyFontObject() end
    function font:GetFont() return 'test-font',12,'' end
    function font:SetFont(path,size,flags) self.size=size end
    _G[name]=font
    return font
end
UIParent=CreateFrame('Frame'); UIParent:SetSize(1920,1080)
UISpecialFrames={}
''')
for name in ['Scrollbars.lua','ActionButtons.lua','FieldbookShell.lua','BestiaryPages.lua']:
    lua.execute(root.joinpath(name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
lua.execute(root.joinpath('CreatureNotes.lua').read_text(), 'AzerothFieldbook', lua.globals().ns)
lua.execute(root.joinpath('BestiaryBook.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
lua.execute(r'''
-- Property grouping measures rendered text, preserving school color markup.
do
    local function measure(text) return #text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','') end
    local casts='Casts: |cff72d65bNature|r'
    local resists='Resists: |cffd884ffArcane|r'
    local immune='Immune: |cffff7043Fire|r'
    local first=casts..'  •  '..resists
    local lines=ns.GroupPropertyLines({casts,resists,immune},measure(first),measure)
    check(#lines==2 and lines[1]==first and lines[2]==immune,'a complete group moves to the next line when it cannot fit')
    lines=ns.GroupPropertyLines({casts,resists},measure(first),measure)
    check(#lines==1 and lines[1]==first,'exact-fit groups stay together with their separator')
    local behaviour='Behaviour: Hostile, Melee, Flees at low health, Calls allies, Patrols, Summons, Heals, Enrages, Stealths'
    lines=ns.GroupPropertyLines({casts,resists,behaviour,immune},measure(first),measure)
    check(#lines==3 and lines[2]==behaviour and lines[3]==immune,'an oversized group gets its own indented-wrap paragraph')
    check(#ns.GroupPropertyLines({},574,measure)==0,'empty properties produce no rows')
end
controller=ns.CreateBestiaryBook(journal)
controller:Toggle()
check(AzerothFieldbookBestiarySection:IsShown(),'book opens')
check(#UISpecialFrames==13 and BINDING_NAME_CLASSICBESTIARY_BOOK and BINDING_NAME_CLASSICBESTIARY_MOUSEOVER_BOOK,'escape and keybinding registration')
check(controller:OpenAtUnit('mouseover'),'mouseover binding opens the observed NPC page')
for _,o in ipairs(objects) do check(o.text~='Your note','empty manual field note stays visually empty') end
local function click(text)
    for _,o in ipairs(objects) do
        if o.kind=='Button' and o.text==text and o.scripts.OnClick then o.scripts.OnClick(o); return true end
    end
    return false
end
check(click('Record damage taken'),'damage form opens')
check(click('Cancel'),'damage form closes')
check(click('All'),'category selection')
local indexBook=AzerothFieldbookBestiarySection
do
    local control=indexBook.typeButtons['All creatures']
    for _,control in ipairs({indexBook.locationsButton,indexBook.ranksButton}) do
        control:SetSelected(false)
        check(control.normalFont=='AzerothFieldbookFilterGameFontNormal','window-opening buttons retain yellow text')
    end
end
local function checkIndex(open)
    check(indexBook.indexButton.enabled,'Index always remains clickable')
    check(indexBook.indexButton.normalFont==(open and 'AzerothFieldbookFilterGameFontNormal' or 'AzerothFieldbookFilterGameFontDisable'),'Index highlights only while open')
    check(rawget(indexBook.indexButton,'selectionOutline')==nil,'selection has no extra border overlay')
    check(#indexBook.letterButtons==26,'Index contains all letters')
    for _,tab in ipairs(indexBook.letterButtons) do
        check(tab:IsShown()==open,'letters follow Index visibility')
        check(tab.enabled==(tab.letter=='D'),'only letters containing matching entries are clickable')
    end
end
checkIndex(false)
check(indexBook.rows[1].id==42,'default list is unfiltered')
check(click('Index'),'alphabet index opens')
checkIndex(true)
check(click('D') and indexBook.rows[1].id==42,'alphabet tab selects matching entries')
check(not indexBook.letterButtons[26].enabled and indexBook.rows[1].id==42,'empty letters cannot replace the current selection')
check(click('Index'),'alphabet index closes')
checkIndex(false)
check(indexBook.rows[1].id==42,'closing Index preserves entries and clears the letter filter')
check(click('Index'),'alphabet index reopens')
checkIndex(true)
check(indexBook.rows[1].id==42,'reopening Index does not restore a stale letter filter')
check(click('D') and click('Index'),'close Index after a matching filter')
checkIndex(false)
check(click('Next') and click('Previous'),'entry navigation buttons')
check(click('Pending'),'review filter')
check(indexBook.review.afbSelected and indexBook.review.normalFont=='AzerothFieldbookFilterGameFontNormal','pending filter visibly selected')
check(click('Pending'),'review filter clears using the same label')
check(not indexBook.review.afbSelected and indexBook.review.normalFont=='AzerothFieldbookFilterGameFontDisable','pending filter returns to grey text')
check(click('Locations') and AzerothFieldbookBestiaryLocations:IsShown(),'location filter window opens')
for _,control in ipairs({AzerothFieldbookBestiarySection.offenseButton,AzerothFieldbookBestiarySection.defenseButton,
    AzerothFieldbookBestiarySection.behaviourButton,AzerothFieldbookBestiarySection.effectButton,
    AzerothFieldbookBestiarySection.confirmAbilityButton,AzerothFieldbookBestiarySection.manualName}) do
    check(not control.enabled,'locked editor disabled')
end
check(AzerothFieldbookBestiarySection.creatureNotesButton.enabled,'notes button stays enabled')
check(click('Unlock this entry'),'confirmed entry unlocks')
check(not journal.entries[42].confirmed,'unlock state saved')
check(AzerothFieldbookBestiarySection.offenseButton.enabled and AzerothFieldbookBestiarySection.confirmAbilityButton.enabled,'unlock restores editing')
check(click('Offenses') and AzerothFieldbookBestiaryOffenses:IsShown(),'offenses window opens')
check(click('Defenses') and AzerothFieldbookBestiaryDefenses:IsShown(),'defenses window opens')
check(click('Behaviour') and AzerothFieldbookBestiaryBehaviour:IsShown(),'behaviour window opens')
local offense=AzerothFieldbookBestiaryOffenses
local defense=AzerothFieldbookBestiaryDefenses
local behaviour=AzerothFieldbookBestiaryBehaviour
check(journal:GetSingleObservationWindow(),'single observation window defaults on')
UIParent.GetEffectiveScale=function() return 1 end
offense.GetLeft=function() return 100 end; offense.GetTop=function() return 600 end
offense.GetEffectiveScale=function() return 0.8 end
defense.GetEffectiveScale=function() return 0.8 end
defense.SetPoint=function(self,point,relative,relativePoint,x,y) self.anchorX=x; self.anchorY=y end
offense:Show(); offense.scripts.OnShow(offense)
check(offense:IsShown() and not defense:IsShown() and not behaviour:IsShown(),'offenses closes its siblings')
defense:Show(); defense.scripts.OnShow(defense)
check(defense:IsShown() and not offense:IsShown(),'defenses replaces offenses')
check(defense.anchorX==100 and defense.anchorY==600,'swapped window shares top-left at custom scale')
defense.GetLeft=function() return 150 end; defense.GetTop=function() return 500 end
defense.scripts.OnDragStop(defense)
defense:Hide()
behaviour.GetEffectiveScale=function() return 0.8 end
behaviour.SetPoint=function(self,point,relative,relativePoint,x,y) self.anchorX=x; self.anchorY=y end
behaviour:Show(); behaviour.scripts.OnShow(behaviour)
check(behaviour.anchorX==150 and behaviour.anchorY==500,'dragged shared position survives closing before swap')
defense:Show()

journal:SetSingleObservationWindow(false)
behaviour:Show(); behaviour.scripts.OnShow(behaviour)
check(defense:IsShown() and behaviour:IsShown(),'disabled option allows simultaneous windows')
check(not ns.CreateBestiaryJournal(db,identify):GetSingleObservationWindow(),'window preference persists')
local singleOption=AzerothFieldbookOptions.singleObservationWindow
singleOption.GetChecked=function() return true end
singleOption.scripts.OnClick(singleOption)
check(behaviour:IsShown() and not defense:IsShown(),'enabling option retains latest open window')
-- The buttons toggle closed as well as open. Native OnShow drives sibling exclusion.
for _,item in ipairs({{'Locations',AzerothFieldbookBestiaryLocations},
    {'Ranks',AzerothFieldbookBestiaryRanks},{'Offenses',offense},
    {'Defenses',defense},{'Behaviour',behaviour},
    {'Choose effects',AzerothFieldbookBestiarySection.effectPicker}}) do
    item[2]:Hide()
    check(click(item[1]) and item[2]:IsShown(),'button opens '..item[1])
    check(click(item[1]) and not item[2]:IsShown(),'button closes '..item[1])
end
journal:SetSingleObservationWindow(true)
click('Offenses'); offense.scripts.OnShow(offense)
click('Defenses'); defense.scripts.OnShow(defense)
check(not offense:IsShown() and defense:IsShown(),'toggle buttons preserve single-window swapping')
click('Defenses'); check(not defense:IsShown(),'active single window can be toggled off')
journal:SetSingleObservationWindow(false)
click('Offenses'); offense.scripts.OnShow(offense)
click('Defenses'); defense.scripts.OnShow(defense)
click('Offenses')
check(not offense:IsShown() and defense:IsShown(),'multi-window mode closes only clicked window')
journal:SetSingleObservationWindow(true)
check(click('Lock this entry'),'entry can be locked again')
local options=AzerothFieldbookOptions
options.scripts.OnShow(options)
check(journal:GetAccountWideTracking() and not journal:IsTrackingChangePending(),'account-wide tracking defaults on')
options.accountWideTracking.GetChecked=function() return false end
options.accountWideTracking.scripts.OnClick(options.accountWideTracking)
check(db.accountWideTracking==false and journal:IsTrackingChangePending(),'tracking checkbox saves a pending character scope')
check(options.trackingReload.text=='Applies after /reload','tracking changes explain when they apply')
options.scripts.OnShow(options)
check(not journal:GetAccountWideTracking(),'opening options preserves an explicit off preference')
options.accountWideTracking.GetChecked=function() return true end
options.accountWideTracking.scripts.OnClick(options.accountWideTracking)
check(not journal:IsTrackingChangePending() and options.trackingReload.text=='','returning to active tracking cancels the pending change')
check(options.uiScale.scripts.OnKeyUp==nil and options.uiScale.scripts.OnKeyDown==nil,'options scale slider does not capture keyboard input')
local oldScale=journal:GetUIScale()
options.uiScale.scripts.OnValueChanged(options.uiScale,0.75)
check(journal:GetUIScale()==oldScale,'scale preview does not move the UI')
options.uiScale.scripts.OnMouseUp(options.uiScale,'LeftButton')
check(journal:GetUIScale()==0.75,'scale applies on mouse release')
options.uiScale.scripts.OnValueChanged(options.uiScale,0.5)
options.uiScale.scripts.OnHide(options.uiScale)
options.uiScale.scripts.OnMouseUp(options.uiScale,'LeftButton')
check(journal:GetUIScale()==0.75,'closing discards unfinished scale adjustment')
check(click('100%') and journal:GetUIScale()==1,'scale reset applies immediately')

check(journal:GetSpellIDWindowOption('displaySpellIDWindow'),'ID window defaults on')
check(not journal:GetSpellIDWindowOption('displayHoveredAuraSnapshots'),'hovered aura snapshots default off')
check(not journal:GetSpellIDWindowOption('spellIDWindowLocked'),'ID window defaults unlocked')
check(not journal:GetSpellIDWindowOption('spellIDWindowIndefinite'),'ID window defaults expiring')
check(journal:GetSpellIDWindowOption('spellIDWindowAlpha')==0.35,'ID window default opacity')
options.spellIDWindowAlpha.scripts.OnValueChanged(options.spellIDWindowAlpha,0.7)
check(db.spellIDWindowAlpha==0.7,'opacity control saves setting')
options.spellIDWindowLocked.GetChecked=function() return true end
options.spellIDWindowLocked.scripts.OnClick(options.spellIDWindowLocked)
check(db.spellIDWindowLocked,'lock checkbox saves setting')
controller:Toggle(); check(not AzerothFieldbookBestiarySection:IsShown(),'book closes')
controller:Toggle(); check(AzerothFieldbookBestiarySection:IsShown(),'book reopens')
controller:OpenNotes()
local notes=AzerothFieldbookCreatureNotes
check(notes:IsShown() and notes.creature.text==journal.entries[42].name..' |cff999999[#42]|r','notes opens for selected creature with grey ID')
notes.spellInput:SetText('6268'); notes.spellInput.scripts.OnEnterPressed(notes.spellInput)
notes.notes:SetText('Boar field notes')
journal:Ensure(43,false,'Other creature'); controller:Refresh()
local function selectEntry(id)
    for _,row in ipairs(AzerothFieldbookBestiarySection.rows) do
        if row.id==id then row.scripts.OnClick(row); return end
    end
    error('entry not visible')
end
selectEntry(43)
check(notes.creature.text=='Other creature |cff999999[#43]|r' and notes.count.text=='0/10','book selection switches notes')
selectEntry(42)
check(notes.count.text=='1/10' and notes.notes.text=='Boar field notes','book selection restores notes')
check(click('Notes'),'creature notes button opens window')
local abilityBook=AzerothFieldbookBestiarySection
local savedAbilities=journal.entries[42].abilities
local savedLock=journal.entries[42].confirmed
journal:SetEntryConfirmed(42,false)
journal.entries[42].abilities={['Observed Counterspell']={state='pending',origin='Automatic observation',spellID=2139}}
controller:Refresh()
local resolvedRow=abilityBook.abilities[1]
resolvedRow.resolve.scripts.OnClick()
check(resolvedRow.name=='Counterspell' and resolvedRow.text.text=='Counterspell','row Resolve saves canonical name and removes pending label: '..tostring(abilityBook.message.text))
check(resolvedRow.note.text=='' and not resolvedRow.accept.enabled,'row Resolve removes automatic origin and confirms')
local oldTooltip=GameTooltip
GameTooltip={lines={}}
function GameTooltip:SetOwner() end
function GameTooltip:SetSpellByID(id) self.id=id; self.lines={}; self.shown=false end
function GameTooltip:AddLine(text) self.lines[#self.lines+1]=text end
function GameTooltip:Show() self.shown=true end
function GameTooltip:Hide() self.shown=false end
local oldCVar=GetCVarBool
for _,native in ipairs({false,true}) do
    if native then GetCVarBool=function() return db.showSpellIDs end else GetCVarBool=nil end
    journal:SetSpellIDTooltips(true)
    resolvedRow.tooltipArea.scripts.OnEnter(resolvedRow.tooltipArea)
    check(GameTooltip.id==2139 and GameTooltip.shown and GameTooltip.lines[1]=='Spell ID: 2139','resolved ability tooltip includes ID when enabled')
    journal:SetSpellIDTooltips(false)
    resolvedRow.tooltipArea.scripts.OnEnter(resolvedRow.tooltipArea)
    check(GameTooltip.id==2139 and GameTooltip.shown and #GameTooltip.lines==0,'disabled IDs preserve the spell tooltip')
end
resolvedRow.tooltipArea.scripts.OnLeave(); check(not GameTooltip.shown,'ability tooltip hides on leave')
check(not resolvedRow.scripts.OnEnter,'button area and gaps cannot open ability tooltip')
GetCVarBool,GameTooltip=oldCVar,oldTooltip
journal:SetEntryConfirmed(42,savedLock)
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
local savedKills=journal.entries[42].kills
for _,sample in ipairs({{9,false,false},{10,true,false},{25,true,false},{50,true,true},{49,true,false}}) do
    journal.entries[42].kills=sample[1]; controller:Refresh()
    check(abilityBook.killStar:IsShown()==sample[2],'reward icon visibility follows kill threshold')
    check(#abilityBook.killStar.crownParts>0,'crown has its own silhouette')
    for _,part in ipairs(abilityBook.killStar.parts) do check(part:IsShown()~=sample[3],'crown replaces the star') end
    for _,part in ipairs(abilityBook.killStar.crownParts) do check(part:IsShown()==sample[3],'crown only appears at 50 kills') end
    for _,row in ipairs(abilityBook.rows) do
        if row.id==42 then
            check(row.killReward:IsShown()==sample[2],'index reward matches the kill counter')
            check(row.text:GetWidth()==(sample[2] and 121 or 140),'name reserves space only for earned rewards')
            for _,part in ipairs(row.killReward.crownParts) do check(part:IsShown()==sample[3],'index crown follows the same milestone') end
        end
    end
end
journal.entries[42].kills=savedKills; controller:Refresh()
local damageBook=AzerothFieldbookBestiarySection
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
check(journal.entries[43] and not AzerothFieldbookBestiarySection.deleteButton.enabled,'other entries survive; no selection disables delete')
check(notes.count.text=='0/10','deleted creature notes cleared from window')
local reloaded=ns.CreateBestiaryJournal(db,function() return nil end)
check(not reloaded.entries[42],'deleted entry does not return through legacy migration')
local ranksDB={bestiary={entries={},creatures={}}}
local ranksJournal=ns.CreateBestiaryJournal(ranksDB,function() return nil end)
for i, rank in ipairs({'Elite','Rare','Rare Elite','World Boss'}) do
    local entry=ranksJournal:Ensure(i,false,'Rank '..i); entry.rank=rank
end
ranksJournal:Ensure(5,false,'Ordinary')
check(#ranksJournal:List(nil,'',false,nil,nil,{})==5,'empty rank filter includes ordinary creatures')
check(#ranksJournal:List(nil,'',false,nil,nil,{Elite=true,Rare=true})==2,'rank filters combine with OR')
check(#ranksJournal:List(nil,'',false,nil,nil,{['Rare Elite']=true})==1,'rare elite is separately selectable')
check(#ranksJournal:List(nil,'Rank 4',false,nil,nil,{['World Boss']=true})==1,'rank combines with text')
check(#ranksJournal:List(nil,'Rank 1',false,nil,nil,{Rare=true})==0,'rank and text both required')
local rewards=ns.CreateBestiaryJournal({},function() return nil end)
local first=rewards:Ensure(1,false,'First creature')
for _,sample in ipairs({{0,0},{2,0},{9,0},{10,1,'silver'},{24,1,'silver'},{25,3,'gold'},{49,3,'gold'},{50,6,'crown'},{51,6,'crown'}}) do
    first.kills=sample[1]
    local points,star=rewards:GetKillReward(1)
    check(points==sample[2] and star==sample[3],'kill reward threshold')
end
first.kills=26
rewards:Ensure(2,false,'Second creature').kills=10
-- Saved legacy kills are credited exactly once during migration, rather than
-- by mutating a live display entry and asking the totals getter to award them.
local rewardsDB={bestiary={entries=rewards.entries,creatures={}}}
rewards=ns.CreateBestiaryJournal(rewardsDB,function() return nil end)
local count,points=rewards:GetTotals()
check(count==2 and points==6,'entry points combine with cumulative kill rewards')
-- A ledger credited under the old thresholds keeps its earned points even
-- though the star now reflects the higher threshold.
rewards.entries[1].kills=2
rewards=ns.CreateBestiaryJournal(rewardsDB,function() return nil end)
check(select(2,rewards:GetKillReward(1))==nil,'saved kill count uses the current star threshold')
check(select(2,rewards:GetTotals())==6,'threshold changes preserve previously credited points')
rewards:DeleteEntry(1)
count,points=rewards:GetTotals()
check(count==1 and points==6,'deletion removes display records but retains earned credit')
local discoveryDB={}
local discovery=ns.CreateBestiaryJournal(discoveryDB,function() return 900 end)
level=5; zone='First zone'; discovery:Observe('target')
local _,discoveryPoints=discovery:GetTotals()
check(discoveryPoints==1,'first creature level and zone award only one point')
discovery:Observe('target')
local _,repeatPoints=discovery:GetTotals(); check(repeatPoints==1,'repeat observation awards nothing')
level=7; discovery:Observe('target')
level=6; discovery:Observe('target')
zone='Second zone'; discovery:Observe('target')
local _,newPoints=discovery:GetTotals(); check(newPoints==2,'new levels award nothing; a new zone awards one')
discovery:SetEntryConfirmed(900,true); level=8; discovery:Observe('target')
level=9; zone='Third zone'; discovery:Observe('target')
local reloadedDiscovery=ns.CreateBestiaryJournal(discoveryDB,function() return 900 end)
local _,savedPoints=reloadedDiscovery:GetTotals(); check(savedPoints==3,'only new zones award points; progress persists while locked')
local legacy=ns.CreateBestiaryJournal({bestiary={entries={[1]={id=1,levelMin=3,levelMax=6,locations={Old=true},abilities={}}},creatures={}}},function() end)
local _,legacyPoints=legacy:GetTotals(); check(legacyPoints==2,'legacy credit uses only observed endpoints and zones')
local awardsDB={}
local awards=ns.CreateBestiaryJournal(awardsDB,function() return 901 end)
local notifications={}
awards:SetPointsAwardedCallback(function(_,amount,reason) notifications[#notifications+1]={amount,reason} end)
check(awards:GetPointAnnouncements(),'point messages default on')
level=3; zone='Award zone'; awards:Observe('target')
check(#notifications==1,'entry level and zone announce one point')
awards:Observe('target'); awards:GetTotals()
check(#notifications==1,'repeat observations and totals do not announce again')
local oldDead,oldGUID,oldExists,oldControlled,oldTap,oldTime=UnitIsDead,UnitGUID,UnitExists,UnitPlayerControlled,UnitIsTapDenied,GetTime
local awardDead=false
UnitIsDead=function() return awardDead end
UnitGUID=function(unit) if unit=='player' then return 'Player-1-1' elseif unit=='target' then return guid end end
UnitExists=function() return true end
UnitPlayerControlled=function() return false end
UnitIsTapDenied=function() return false end
GetTime=function() return 0 end
local function awardDeath(suffix)
    guid='Creature-0-1-2-3-901-'..suffix
    awardDead=false; awards:Observe('target')
    awards:RecordPartyKill('Player-1-1',guid)
    awardDead=true; awards:RecordUnitDeath(guid); awards:RecordKill('target')
end
awardDeath('first')
check(#notifications==1,'first kill awards no star points')
for i=2,9 do awardDeath('kill'..i) end
check(#notifications==1,'no silver reward before 10 kills')
awardDeath('silver')
check(#notifications==2 and notifications[2][1]==1 and notifications[2][2]=='silver star','tenth kill awards silver once')
for i=11,24 do awardDeath('kill'..i) end
check(#notifications==2,'kills below 25 do not announce gold')
awardDeath('gold')
check(#notifications==3 and notifications[3][1]==2 and notifications[3][2]=='gold star','25th kill announces two additional points')
awardDeath('afterGold')
check(#notifications==3,'kills above 25 do not repeat gold points')
for i=27,49 do awardDeath('kill'..i) end
check(#notifications==3,'no crown reward before 50 kills')
awardDeath('crown')
check(#notifications==4 and notifications[4][1]==3 and notifications[4][2]=='gold crown','50th kill awards three additional points')
awardDeath('afterCrown')
check(#notifications==4,'kills above 50 do not repeat crown points')
awards:SetPointAnnouncements(false); zone='Silent zone'; awards:Observe('target')
check(#notifications==4,'option disables new award messages')
local _,silentTotal=awards:GetTotals(); check(silentTotal==8,'muting messages still awards points')
local savedAwards=ns.CreateBestiaryJournal(awardsDB,function() return 901 end)
check(not savedAwards:GetPointAnnouncements(),'notification option persists')
savedAwards:SetPointsAwardedCallback(function() error('existing credit must not be reannounced') end)
savedAwards:SetPointAnnouncements(true); savedAwards:GetTotals(); savedAwards:Observe('target')
UnitIsDead,UnitGUID,UnitExists,UnitPlayerControlled,UnitIsTapDenied,GetTime=oldDead,oldGUID,oldExists,oldControlled,oldTap,oldTime
check(click('Ranks') and AzerothFieldbookBestiaryRanks:IsShown(),'rank picker opens')
journal:Reset(); controller:Refresh()
check(#journal:List(nil,'',false)==0,'reset clears book')
''')
print('PASS: journal review, creature types, level ranges, spell linking, damage notes, persistence and book interactions')
