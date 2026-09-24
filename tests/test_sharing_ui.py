"""Native enum adapter and mock widget integration; no claim of visual correctness."""
from pathlib import Path
import sys
import re
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().buildVersion = re.search(r"^## Version: (\S+)", (root / "AzerothFieldbook.toc").read_text(encoding="utf-8"), re.MULTILINE).group(1)
lua.execute(r'''
ns,objects,UISpecialFrames={},{},{}
secret={}; now=1000000; combat=false; chatState=0; npcID=42; playerName='Alice Sunstrider'
function issecretvalue(value) return rawequal(value,secret) end
function time() return now end
function InCombatLockdown() return combat end
function UnitName(unit) if unit=='player' then return playerName end; return 'Creature '..npcID end
function UnitCreatureType() return 'Humanoid' end
function UnitLevel() return 9 end
function UnitGUID() return 'Creature-0-1-2-3-'..npcID..'-1' end
function UnitIsDead() return false end
function GetNormalizedRealmName() error('sharing must not require a realm') end
function GetRealmName() error('sharing must not require a realm') end
function GetRealZoneText() return 'Elwynn' end
metadataVersion=buildVersion
C_AddOns={GetAddOnMetadata=function(addon,field)
    assert(addon=='AzerothFieldbook' and field=='Version');return metadataVersion
end}
Enum={RegisterAddonMessagePrefixResult={Success=0,DuplicatePrefix=1,InvalidPrefix=2,MaxPrefixes=3},
    SendAddonMessageResult={Success=0,AddonMessageThrottle=3,ChannelThrottle=8,AddOnMessageLockdown=11,TargetOffline=12},
    AddOnRestrictionType={Chat=5},AddOnRestrictionState={Inactive=0,Activating=1,Active=2}}
C_RestrictedActions={GetAddOnRestrictionState=function(kind) assert(kind==5); return chatState end}
local methods={}
function methods:SetScript(event,fn) self.scripts[event]=fn end
function methods:SetText(text)
    assert(type(text)=='string' or type(text)=='number','UI received nonliteral text: '..type(text))
    self.text=tostring(text)
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function methods:GetText() return rawget(self,'text') or '' end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:SetPoint(...) self.point={...} end
function methods:GetWidth() return rawget(self,'width') or 100 end
function methods:GetHeight() return rawget(self,'height') or 100 end
function methods:GetStringHeight() return math.max(14,math.ceil(#self:GetText()/math.max(1,math.floor(self:GetWidth()/7)))*14) end
function methods:GetFrameLevel() return 10 end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetShown(v) self.shown=v end
function methods:IsShown() return self.shown end
function methods:SetEnabled(v) self.enabled=v end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
function methods:SetScale(v) self.scale=v end
function methods:GetScale() return rawget(self,'scale') or 1 end
function methods:SetClampedToScreen(v) self.clamped=v end
function methods:SetFocus() self.focus=true end
function methods:ClearFocus() self.focus=false end
function methods:SetVerticalScroll(v) self.scroll=v end
function methods:GetVerticalScroll() return rawget(self,'scroll') or 0 end
function methods:GetVerticalScrollRange() return 0 end
function methods:CreateTexture() return CreateFrame('Texture',nil,self) end
function methods:CreateFontString() return CreateFrame('FontString',nil,self) end
function CreateFrame(kind,name,parent)
    local f={kind=kind,parent=parent,scripts={},shown=true,enabled=true}
    setmetatable(f,{__index=function(_,k)
        if methods[k] then return methods[k] end
        if k:match('^%u') then return function() end end
    end})
    objects[#objects+1]=f; if name then _G[name]=f end
    return f
end
UIParent=CreateFrame('Frame'); UIParent:SetSize(1920,1080)
function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
''')
for name in ['Scrollbars.lua','UIScale.lua','SharingReport.lua','BestiaryJournal.lua','Sharing.lua','SharingWindow.lua','CreatureNotes.lua','RumoursWindow.lua','BestiaryBook.lua']:
    lua.execute((root/name).read_text(encoding='utf-8'),'AzerothFieldbook',lua.globals().ns)

lua.execute(r'''
local S=ns.SharingReport
function native(registerResult,sendResult)
    local calls=0
    C_ChatInfo={RegisterAddonMessagePrefix=function(prefix) eq(prefix,'AFBShare'); return registerResult end,
        SendAddonMessage=function(prefix,text,channel,target)
            eq(prefix,'AFBShare'); eq(channel,'WHISPER'); eq(target,'Bob Stonewell'); assert(#text<=240)
            if text:find('~H~',1,true) then assert(text:sub(-#buildVersion)==buildVersion,'native handshake advertises TOC version') end
            calls=calls+1; return sendResult
        end}
    local j=ns.CreateBestiaryJournal({},function() return nil end)
    local e=j:Ensure(42); e.name='Defias Pillager';e.category='Humanoid';e.levelMin=9;e.levelMax=11;e.locations.Elwynn=true
    j:Ensure(43).name='Another creature'
    local engine=ns.InitializeSharing(j)
    return j,engine,function() return calls end,objects[#objects]
end
for _,result in ipairs({0,1}) do
    local j,e,calls=native(result,0); assert(e:Available())
    local tx=assert(e:Start(S.Capture(j,42),'Bob Stonewell',{})); now=now+1;e:Tick()
    eq(calls(),1);eq(tx.stage,'preflight','API success is not receipt');eq(select(3,j:GetSharingBalance()),0)
end
for _,result in ipairs({2,3,true,false,secret}) do local _,e=native(result,0); assert(not e:Available(),'non-success registration enum') end
local _,unavailable=native(nil,0);assert(not unavailable:Available())
for _,result in ipairs({12,11,9,false,secret}) do
    local j,e=native(0,result);local tx=assert(e:Start(S.Capture(j,42),'Bob Stonewell',{}));now=now+1;e:Tick()
    eq(tx.stage,'failed');eq(j:GetSharingBalance(),2,'API errors release preflight reservation')
end
local j,e,calls=native(0,3);local tx=assert(e:Start(S.Capture(j,42),'Bob Stonewell',{}))
for i=1,12 do now=now+1;e:Tick() end
eq(calls(),3,'bounded throttle retries');eq(tx.stage,'failed')
for _,state in ipairs({1,2,secret}) do
    chatState=state;local j,e,calls=native(0,0)
    assert(e:Blocked() and not e:Start(S.Capture(j,42),'Bob Stonewell',{}));eq(calls(),0)
end
chatState=0;combat=true
j,e,calls=native(0,0);assert(not e:Start(S.Capture(j,42),'Bob Stonewell',{}));eq(calls(),0)
combat=false

-- Identity can be unavailable at ADDON_LOADED; login must enable sending
-- without requiring another reload or inventing a realm/surname component.
playerName=nil
local _,early,_,frame=native(0,0)
local ready,reason=early:Available();assert(not ready and reason:find('full name',1,true))
playerName='Alice Sunstrider';frame.scripts.OnEvent(frame,'PLAYER_LOGIN')
assert(early:Available())
playerName='Alice'
UnitFullName=function() return 'Alice Sunstrider','NotASurname' end
local j,e,calls=native(0,0)
assert(not e:Start(S.Capture(j,42),'  alice  sunstrider  ',{}),'full client name identifies self')
local tx=assert(e:Start(S.Capture(j,42),'  Bob   Stonewell  ',{}));now=now+1;e:Tick()
eq(tx.recipient,'Bob Stonewell');eq(calls(),1,'native target preserves the surname without a realm')
UnitFullName=nil;playerName='Alice Sunstrider'
for _,value in ipairs({'unknown','',secret}) do
    metadataVersion=value
    local j,e,calls=native(0,0);local ready,reason=e:Available()
    assert(not ready and reason:find('version',1,true));assert(not e:Start(S.Capture(j,42),'Bob Stonewell',{}))
    eq(calls(),0);eq(j:GetSharingBalance(),2)
end
metadataVersion=nil
local _,missing=native(0,0);assert(not missing:Available())
metadataVersion=buildVersion
''')
print('PASS: Forever enum handling, unreadable results, bounded throttle retries, combat, Chat restrictions, full names and login readiness')

lua.execute(r'''
local S=ns.SharingReport
local db={}
ns.UIScale:Initialize(db)
local j=ns.CreateBestiaryJournal(db,function() return npcID end)
j:Observe('target')
for i=1,5 do j:Ensure(100+i).name='Funding '..i end
j:AddManual(42,'Fireball','A long private ability note',nil,{Fear=true,Stun=true})
j:AddManual(42,'Arcane Volley With A Long Ability Name That Wraps Across Several Lines','',nil,{})
j:SetResistance(42,'Fire',true);j:SetBehaviour(42,'Flees at low health',true)
local env={ready=true,addonVersion=buildVersion,character='Alice Sunstrider',now=function() return now end,
    blocked=function() return combat end,send=function() return true end}
local engine=ns.CreateSharing(j,env)
local book=ns.CreateBestiaryBook(j)
book:OpenAtUnit('target')
local main=AzerothFieldbookBestiary
assert(main.windowTitle.text:find(buildVersion,1,true),'book displays the installed TOC version')
assert(main.shareButton.enabled)
main.shareButton.scripts.OnClick()
local composer=AzerothFieldbookShare
assert(composer.shown and composer.clamped)
eq(j:GetSharingBalance(),6,'opening composer free')
assert(composer.cost.text:find('Total cost: 1',1,true))
assert(composer.send.enabled,'funded report ready outside combat')
combat=true;main.shareButton.scripts.OnClick()
assert(not composer.send.enabled and composer.status.text:find('combat',1,true))
combat=false;env.ready=false;env.error='Messaging initialization failed';main.shareButton.scripts.OnClick()
assert(not composer.send.enabled and composer.status.text==env.error)
env.ready=true;main.shareButton.scripts.OnClick();assert(composer.send.enabled)
local first,second,third=composer.rows[1],composer.rows[2],composer.rows[3]
eq(first.point[2],0);assert(second.point[2]>first.point[2]);eq(first.point[3],second.point[3])
eq(third.point[2],0);assert(third.point[3]<first.point[3],'next pair starts below both wrapped labels')
assert(third.point[3]<=first.point[3]-math.max(first.text:GetStringHeight(),second.text:GetStringHeight())-8)
for _,row in ipairs(composer.rows) do assert(row.text.text:sub(-1)~='.','rumour labels have no trailing period') end
local baseScale=composer:GetScale(); j:SetUIScale(1.25); eq(composer:GetScale(),baseScale*1.25)
local capturedBasic=composer.basic.text
npcID=43;book:OpenAtUnit('target')
eq(composer.basic.text,capturedBasic,'book selection cannot alter composition')
composer.rows[1].scripts.OnClick(composer.rows[1])
composer.rows[2].scripts.OnClick(composer.rows[2])
assert(composer.cost.text:find('Rumours: 2',1,true) and composer.cost.text:find('Total cost: 3',1,true))
assert(composer.rows[3].enabled,'selecting two rumours does not disable additional choices')
composer.rows[3].scripts.OnClick(composer.rows[3])
assert(composer.rows[3].checked and composer.cost.text:find('Total cost: 4',1,true))
composer.rows[4].scripts.OnClick(composer.rows[4])
assert(composer.rows[4].checked and composer.cost.text:find('Total cost: 5',1,true))
local held={}
while j:GetSharingBalance()>1 do
    local id='other-reservation-'..(#held+1)
    assert(j:ReserveShare(id,math.min(2,j:GetSharingBalance()-1)));held[#held+1]=id
end
composer.rows[1].scripts.OnClick(composer.rows[1])
assert(not composer.send.enabled and composer.status.text:find('Insufficient points',1,true))
composer.rows[2].scripts.OnClick(composer.rows[2]);composer.rows[3].scripts.OnClick(composer.rows[3])
assert(not composer.send.enabled,'one available point cannot pay for even one rumour')
composer.rows[4].scripts.OnClick(composer.rows[4]);assert(composer.send.enabled,'one available point enables basic-only report')
for _,id in ipairs(held) do j:ReleaseShare(id) end
for _,row in ipairs(composer.rows) do row.scripts.OnClick(row) end
composer.recipient:SetText('Bob Stonewell');composer.send.scripts.OnClick()
local tx=engine:GetOutgoing()
eq(S.Decode(tx.payload).creatureID,42,'captured identity is sent')
eq(#S.Decode(tx.payload).rumours,4);eq(tx.cost,5);eq(select(4,j:GetSharingBalance()),5)
assert(not composer.send.enabled and not composer.recipient.enabled)
local spent=select(3,j:GetSharingBalance());composer.send.scripts.OnClick();eq(select(3,j:GetSharingBalance()),spent)
for id in pairs(j.entries) do j:DeleteEntry(id) end
book:Refresh();assert(main.shareButton.enabled,'active transfer remains accessible after entry deletion')
composer.cancel.scripts.OnClick();eq(tx.stage,'cancelled');eq(select(4,j:GetSharingBalance()),0)

npcID=42;book:OpenAtUnit('target');book:OpenNotes()
local notes=AzerothFieldbookCreatureNotes
assert(notes.notesArea.shown and notes.rumoursToggle==nil,'Rumours moved out of Creature Notes')
eq(main.rumoursButton.point[2],main.creatureNotesButton)
eq(main.killCount.point[2],main.rumoursButton,'Rumours is between Kills and Creature Notes')
main.rumoursButton.scripts.OnClick()
local rumours=AzerothFieldbookRumours
assert(rumours.shown and rumours.clamped and notes.shown)
local escapeRegistered=false
for _,name in ipairs(UISpecialFrames) do if name=='AzerothFieldbookRumours' then escapeRegistered=true end end
assert(escapeRegistered,'Escape closes the separate Rumours window')
assert(rumours.rows[1].text.text:find('No unverified rumours',1,true))
main.rumoursButton.scripts.OnClick();assert(not rumours.shown,'button toggles closed')
main.rumoursButton.scripts.OnClick();assert(rumours.shown)
notes.notesToggle.scripts.OnClick();assert(not notes.notesArea.shown and rumours.shown)
notes.notes.text='Unsaved widget input';notes.notes.focus=true;notes.spellInput:SetText('Unsubmitted ID')
local value={version=1,transaction='1000000-1-1',created=now,recipient='Alice Sunstrider',creatureID=42,
    name='Reported name',category='Humanoid',levelMin=8,levelMax=11,locations={'Reported zone'},
    rumours={{kind='ability',value=string.rep('Longname',12)}}}
assert(j:ImportReport(value,'Bob Stonewell',now));book:Refresh()
eq(notes.notes.text,'Unsaved widget input');assert(notes.notes.focus)
eq(notes.spellInput:GetText(),'Unsubmitted ID');assert(not notes.notesArea.shown and rumours.shown)
assert(rumours.rows[1].text.text:find('Reported by Bob Stonewell',1,true))
assert(rumours.rows[2].text.text:find('Shared basics:',1,true),'attributed basics remain inspectable')
eq(rumours.area.height,300,'bounded scrolling')
local baseScale=rumours:GetScale()/j:GetUIScale()
j:SetUIScale(1.5);eq(rumours:GetScale(),baseScale*1.5)
assert(rumours.height*rumours:GetScale()<=UIParent:GetHeight()-30)
rumours.rows[1].remove.scripts.OnClick();eq(#j:GetRumours(42),0)
value.transaction='1000000-2-1'
assert(j:ImportReport(value,'Bob Stonewell',now));book:Refresh()
assert(rumours.rows[1].text.text:find('Previously rejected',1,true))
assert(rumours.rows[1].verify.enabled and rumours.rows[1].remove.shown)
local points=j:GetSharingBalance()
rumours.rows[1].verify.scripts.OnClick();eq(#j:GetRumours(42),0)
eq(j.entries[42].abilities[value.rumours[1].value].state,'confirmed');eq(j:GetSharingBalance(),points)
eq(notes.notes.text,'Unsaved widget input');assert(notes.notes.focus)
value.transaction='1000000-3-1';value.rumours={{kind='offense',value='Fire'}}
assert(j:ImportReport(value,'Bob Stonewell',now));j:SetEntryConfirmed(42,true);book:Refresh()
assert(not rumours.rows[1].verify.enabled and rumours.rows[1].remove.enabled)
assert(rumours.instructions.text:find('locked',1,true))
rumours.rows[1].verify.scripts.OnClick();assert(not j.entries[42].offenses.Fire)
j:SetEntryConfirmed(42,false);j:SetOffense(42,'Fire',true)
main:Hide();rumours.scripts.OnUpdate();eq(#j:GetRumours(42),0,'manual changes refresh even with main book hidden')
assert(not rumours.rows[1].verify.shown)
value.transaction='1000000-4-1';value.rumours={}
for i=1,12 do value.rumours[i]={kind='ability',value='Spell '..i..string.rep(' wide name',8)} end
assert(j:ImportReport(value,'Bob Stonewell',now));rumours.scripts.OnUpdate()
assert(rumours.body.height>rumours.area.height,'long lists scroll instead of growing the window')
for i=2,12 do
    local previous,row=rumours.rows[i-1],rumours.rows[i]
    assert(row.point[3]<=previous.point[3]-previous.height,'wrapped rows do not overlap')
end
rumours.closeButton.scripts.OnClick();assert(not rumours.shown)
main:Show();main.rumoursButton.scripts.OnClick();assert(rumours.shown)
notes.pinButton.scripts.OnClick();notes.closeButton.scripts.OnClick();assert(notes.shown,'notes pin remains effective')
notes.pinButton.scripts.OnClick()
npcID=43;book:FollowNotesTarget();eq(notes.creature.text,'Creature 43')
book:Refresh();eq(notes.creature.text,'Creature 43','unchanged book refresh preserves notes target')
eq(rumours.creature.text,'Creature 42','Rumours follows the book independently of Notes target')
book:OpenAtUnit('target');eq(rumours.creature.text,'Creature 43','changing book selection updates Rumours')
assert(rumours.rows[1].text.text:find('No unverified rumours',1,true))
j:DeleteEntry(43);book:Refresh();assert(main.rumoursButton.enabled,'open window can still be closed after deletion')
main.rumoursButton.scripts.OnClick();assert(not rumours.shown and not main.rumoursButton.enabled)
book:OpenAtUnit('target')

-- The live receive dialog performs consent only; import still requires commit.
local bob=ns.CreateBestiaryJournal({},function() return nil end)
local bEnv={ready=true,addonVersion=buildVersion,character='Bob Stonewell',now=function() return now end,
    blocked=function() return combat end,send=function() return true end}
local b=ns.CreateSharing(bob,bEnv);local receiveUI=ns.CreateSharingWindow(bob,b)
local offered={version=1,transaction='1000000-44-1',created=now,recipient='Bob Stonewell',creatureID=42,
    name='Defias Pillager',category='Humanoid',levelMin=9,levelMax=11,locations={'Elwynn'},
    rumours={{kind='ability',value='Fireball'},{kind='behaviour',value='Melee'},{kind='behaviour',value='Hostile'}}}
local encoded=assert(S.Encode(offered))
b:Receive('AFBShare','3~H~'..offered.transaction..'~'..buildVersion,'WHISPER','Alice Sunstrider')
local n=math.ceil(#encoded/180)
for i=1,n do b:Receive('AFBShare','3~O~'..offered.transaction..'~'..i..'~'..n..'~'..encoded:sub((i-1)*180+1,i*180),'WHISPER','Alice Sunstrider') end
local receiver=AzerothFieldbookReceive
assert(receiver.shown and receiver.clamped and receiver.accept.enabled)
assert(receiver.from.text:find('Alice Sunstrider',1,true))
assert(receiver.preview.text:find('unverified rumour',1,true) and receiver.preview.text:find('Adds new information',1,true))
assert(not bob.entries[42]);receiver.accept.scripts.OnClick();assert(not bob.entries[42] and not receiver.accept.enabled)
b:Receive('AFBShare','3~C~'..offered.transaction,'WHISPER','Alice Sunstrider')
assert(bob.entries[42] and not receiver.shown);eq(bob:GetSharingBalance(),0)
eq(#bob:GetRumours(42),3,'receive UI accepts and imports more than two rumours')
assert(bob:DismissRumour(42,bob:GetRumours(42)[1]))
now=now+16;offered.transaction='1000000-45-1';encoded=assert(S.Encode(offered))
b:Receive('AFBShare','3~H~'..offered.transaction..'~'..buildVersion,'WHISPER','Alice Sunstrider')
n=math.ceil(#encoded/180)
for i=1,n do b:Receive('AFBShare','3~O~'..offered.transaction..'~'..i..'~'..n..'~'..encoded:sub((i-1)*180+1,i*180),'WHISPER','Alice Sunstrider') end
assert(receiver.shown and receiver.preview.text:find('Previously rejected',1,true),'incoming preview warns before acceptance')
receiver.accept.scripts.OnClick()
b:Receive('AFBShare','3~C~'..offered.transaction,'WHISPER','Alice Sunstrider')
assert(bob:GetRumours(42)[1].previouslyRejected)
assert(bob:AddManual(42,'Fireball',''))
now=now+16;offered.transaction='1000000-46-1';encoded=assert(S.Encode(offered))
b:Receive('AFBShare','3~H~'..offered.transaction..'~'..buildVersion,'WHISPER','Alice Sunstrider')
n=math.ceil(#encoded/180)
for i=1,n do b:Receive('AFBShare','3~O~'..offered.transaction..'~'..i..'~'..n..'~'..encoded:sub((i-1)*180+1,i*180),'WHISPER','Alice Sunstrider') end
assert(receiver.preview.text:find('Already in your journal',1,true));receiver.decline.scripts.OnClick()

-- Full reset clears in-flight composition as well as saved accounting.
main.shareButton.scripts.OnClick();assert(composer.shown)
main.rumoursButton.scripts.OnClick();assert(rumours.shown)
j:ResetDatabase();assert(not composer.shown);eq(j:GetSharingBalance(),0)
rumours.scripts.OnUpdate();assert(rumours.rows[1].text.text:find('No unverified rumours',1,true))
assert(rumours.rows[1].claim==nil and rumours.message.text=='','reset clears the open review window')
''')
print('PASS: Share button, captured selection, unrestricted rumour selection, per-rumour costs, balances, native controls, receive consent, separate Rumours toggle, verification/rejection, manual refresh, Notes input, pinning and scaling')
