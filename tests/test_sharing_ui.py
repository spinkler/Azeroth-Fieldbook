"""Native enum adapter and mock widget integration; no claim of visual correctness."""
from ui_test_harness import ROOT as root, new_ui_client

lua=new_ui_client()
for name in ['Scrollbars.lua','ActionButtons.lua','WindowFocus.lua','WindowPositions.lua','UIScale.lua','SharingReport.lua','PlayerNames.lua','BestiaryBackups.lua','BestiaryJournal.lua','Sharing.lua','SharingWindow.lua','CreatureNotes.lua','RumoursWindow.lua','BackupWindow.lua','FieldbookShell.lua','BestiaryPages.lua','BestiaryBook.lua','DebugReport.lua']:
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
    local e=j:Ensure(42,false,'Defias Pillager');e.category='Humanoid';e.levelMin=9;e.levelMax=11;e.locations.Elwynn=true
    j:Ensure(43,false,'Another creature')
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
playerName='Alice';playerSurname='Sunstrider'
UnitFullName=function() return 'Alice','NotASurname' end
local j,e,calls=native(0,0)
assert(not e:Start(S.Capture(j,42),'  alice  sunstrider  ',{}),'full client name identifies self')
local tx=assert(e:Start(S.Capture(j,42),'  Bob   Stonewell  ',{}));now=now+1;e:Tick()
eq(tx.recipient,'Bob Stonewell');eq(calls(),1,'native target preserves the surname without a realm')
UnitFullName=nil;playerName='Alice Sunstrider';playerSurname=nil
for _,value in ipairs({'unknown','',secret}) do
    metadataVersion=value
    local j,e,calls=native(0,0);local ready,reason=e:Available()
    assert(not ready and reason:find('version',1,true));assert(not e:Start(S.Capture(j,42),'Bob Stonewell',{}))
    eq(calls(),0);eq(j:GetSharingBalance(),2)
end
metadataVersion=nil
local _,missing=native(0,0);assert(not missing:Available())
metadataVersion=buildVersion

-- Split surname identity: native APIs must preserve the same full name used
-- by whisper routing, self-offer checks and the receiving report binding.
do
    local savedUnmodified=UnitNameUnmodified
    local formatter=NameUtil.GetFullNameWithoutRealm
    for _,parts in ipairs({{'Peww','Pewz'},{'Erna','Lionguard'},{"Élan","O'Connor-Smith"}}) do
        playerName,playerSurname=parts[1],parts[2]
        local j,e=native(0,0)
        assert(not e:ValidateRecipient(parts[1]..' '..parts[2]),'split full name rejects self-offers')
        assert(e:ValidateRecipient(parts[1]..' Different'),'same first name is not the same character')
    end
    playerName,playerSurname='Peww','Pewz'
    local _,e,_,driver=native(0,0)
    playerSurname='Updated';driver.scripts.OnEvent(driver,'UNIT_NAME_UPDATE','player')
    assert(not e:ValidateRecipient('Peww Updated'))
    assert(e:ValidateRecipient('Peww Pewz'),'name updates replace the cached identity')
    playerSurname=secret;local _,restricted=native(0,0);assert(not restricted:Available())
    playerName=secret;playerSurname='Pewz';local _,restricted=native(0,0);assert(not restricted:Available())
    playerName,playerSurname='Peww','Pewz'
    UnitNameUnmodified=function() error('unavailable name') end
    local _,restricted=native(0,0);assert(not restricted:Available())
    UnitNameUnmodified=nil;local _,fallback=native(0,0)
    assert(not fallback:ValidateRecipient('Peww Pewz'),'UnitName fallback retains surname')
    UnitNameUnmodified=savedUnmodified
    NameUtil.GetFullNameWithoutRealm=nil
    local _,missing=native(0,0);assert(not missing:Available(),'missing formatter never drops the surname')
    NameUtil.GetFullNameWithoutRealm=formatter
    playerName='Alice Sunstrider';playerSurname=nil
end
-- Two real native adapters exchanging the reported names over simulated whispers.
do
    local wire,peers={},{}
    local activeSender
    C_ChatInfo={RegisterAddonMessagePrefix=function() return 0 end,
        SendAddonMessage=function(prefix,text,channel,target)
            wire[#wire+1]={sender=activeSender,prefix=prefix,text=text,channel=channel,target=target};return 0
        end}
    local function peer(first,surname,id,name)
        playerName,playerSurname=first,surname
        local j=ns.CreateBestiaryJournal({},function() return nil end)
        local entry=j:Ensure(id,false,name);entry.category='Humanoid';entry.levelMin=8;entry.levelMax=8;entry.locations['Elwynn Forest']=true
        for i=1,4 do j:Ensure(id+100+i,false,'Funding creature') end
        local e=ns.InitializeSharing(j)
        local p={j=j,e=e,driver=objects[#objects]};peers[first..' '..surname]=p;return p
    end
    local erna=peer('Erna','Lionguard',327,'Goldtooth')
    local peww=peer('Peww','Pewz',328,'Creature 328')
    local function pump(count)
        for _=1,count do
            now=now+1
            for name,p in pairs(peers) do activeSender=name;p.driver.scripts.OnUpdate(p.driver,1) end
            local pending=wire;wire={}
            for _,m in ipairs(pending) do
                local p=assert(peers[m.target]);p.driver.scripts.OnEvent(p.driver,'CHAT_MSG_ADDON',m.prefix,m.text,m.channel,m.sender)
            end
        end
    end
    local traits={{kind='behaviour',value='Flees at low health'},{kind='behaviour',value='Hostile'},{kind='behaviour',value='Melee'}}
    local tx=assert(erna.e:Start(S.Capture(erna.j,327),'Peww Pewz',traits));pump(12)
    local incoming=assert(peww.e:GetIncoming()[1],'Peww Pewz receives the offer when the game returns separate name parts')
    eq(incoming.sender,'Erna Lionguard');assert(peww.e:Accept(incoming));pump(10)
    eq(tx.stage,'complete');eq(tx.cost,4);eq(#peww.j:GetRumours(327),3)
    local reverse=assert(peww.e:Start(S.Capture(peww.j,328),'Erna Lionguard',{}));pump(12)
    assert(erna.e:Accept(assert(erna.e:GetIncoming()[1])));pump(10);eq(reverse.stage,'complete')
    playerName='Alice Sunstrider';playerSurname=nil
end

-- Exercise the real OnUpdate -> timeout -> composer path with a successful
-- native send but no addon reply. A stalled/backward wall clock cannot keep
-- the initial check pending, and the visible controls recover automatically.
do
    local j,e,calls,driver=native(0,0)
    local ui=ns.CreateSharingWindow(j,e)
    local refreshDriver=objects[#objects]
    ui:Open(42)
    local window=AzerothFieldbookShare
    window.recipient:SetText('Bob Stonewell');window.send.scripts.OnClick()
    local pending=e:GetOutgoing()
    assert(window.status.text:find('20s remaining',1,true) and not window.send.enabled)
    now=now-120
    for i=1,79 do
        driver.scripts.OnUpdate(driver,0.25)
        refreshDriver.scripts.OnUpdate(refreshDriver,0.25)
    end
    eq(pending.stage,'preflight');eq(e:GetPreflightSecondsRemaining(),1)
    assert(window.status.text:find('1s remaining',1,true))
    driver.scripts.OnUpdate(driver,0.25)
    eq(pending.stage,'failed');eq(calls(),1)
    eq(j:GetSharingBalance(),2);eq(select(3,j:GetSharingBalance()),0);eq(select(4,j:GetSharingBalance()),0)
    assert(window.send.enabled and window.recipient.enabled,'timeout restores send and recipient controls')
    assert(window.status.text==pending.message and window.status.text:find('No response from Bob Stonewell',1,true))
    assert(-window.send.point[3]>=-window.status.point[3]+window.status:GetStringHeight()+12,
        'the complete timeout explanation fits above the footer')
    window.send.scripts.OnClick()
    assert(e:GetOutgoing()~=pending and window.status.text:find('20s remaining',1,true),'fresh attempt resets the countdown')
    local accepted=e:GetOutgoing()
    e:Receive('AFBShare','4~R~'..accepted.id..'~'..buildVersion,'WHISPER','Bob Stonewell')
    e:Receive('AFBShare','4~A~'..accepted.id..'~0','WHISPER','Bob Stonewell')
    assert(window.cost.text:find('Basic info: 0',1,true) and window.cost.text:find('Total cost: 0 knowledge',1,true))
    assert(window.status.text:find('cost of 1 knowledge was waived',1,true),'accepted discount is visible to the sender')
    e:Receive('AFBShare','4~K~'..accepted.id,'WHISPER','Bob Stonewell')
    assert(window.status.text:find('This report cost 0 knowledge.',1,true),'completed report retains the actual discounted cost')
    eq(select(3,j:GetSharingBalance()),0)
    window.cancel.scripts.OnClick()
end
''')
print('PASS: Forever enum handling, unreadable results, bounded throttle retries, combat, Chat restrictions, full names and login readiness')

lua.execute(r'''
local S=ns.SharingReport
local db={}
ns.UIScale:Initialize(db)
local j=ns.CreateBestiaryJournal(db,function() return npcID end)
j:Observe('target')
for i=1,5 do j:Ensure(100+i,false,'Funding '..i) end
j:AddManual(42,'Fireball','A long private ability note',nil,{Fear=true,Stun=true})
j:AddManual(42,'Arcane Volley With A Long Ability Name That Wraps Across Several Lines','',nil,{})
j:SetResistance(42,'Fire',true);j:SetBehaviour(42,'Flees at low health',true)
local env={ready=true,addonVersion=buildVersion,character='Alice Sunstrider',now=function() return now end,
    blocked=function() return combat end,send=function() return true end}
local engine=ns.CreateSharing(j,env)
local book=ns.CreateBestiaryBook(j)
book:OpenAtUnit('target')
local main=AzerothFieldbookBestiarySection
local window=book:GetShell():GetFrame()
assert(not window.titleIcon:IsMouseClickEnabled() and not main.detail:IsMouseClickEnabled(),
    'full-book decorative overlays must not intercept clicks on the journal controls')
assert(not window.titleIcon.scripts.OnMouseDown and not main.detail.scripts.OnMouseDown,
    'focus must not install mouse handlers on decorative containers')
main.options.scripts.OnShow(main.options)
local blockOffers=main.options.blockIncomingOffers
window.eventLogButton.scripts.OnClick()
main.eventLog.scripts.OnShow(main.eventLog)
assert(main.eventLog:IsShown(),'fourth title button opens log')
assert(main.eventLog:GetHeight()==200 and not main.eventLog.older:IsShown(),'empty log is compact without pagination')
for i=1,51 do j:RecordEvent('Log event '..i..' '..string.rep('details ',20)) end
assert(main.eventLog.text:GetText():find('Log event 51',1,true),'visible log updates live')
assert(main.eventLog:GetHeight()==767,'long log stops growing at its maximum height')
main.eventLog.older.scripts.OnClick()
assert(main.eventLog.text:GetText():find('Log event 1',1,true),'older page remains available')
assert(not main.eventLog.text:GetText():find('Log event 51',1,true),'history renders in bounded pages')
assert(main.eventLog:GetHeight()<767,'short history page shrinks to fit')
window.eventLogButton.scripts.OnClick()
assert(not main.eventLog:IsShown(),'fourth title button toggles log closed')
local anchorOption=main.options.alwaysAnchorToMain
assert(anchorOption:GetChecked() and j:GetAlwaysAnchorToMain(),'main anchoring defaults on')
anchorOption:SetChecked(false);anchorOption.scripts.OnClick(anchorOption)
assert(db.alwaysAnchorToMain==false and not j:GetAlwaysAnchorToMain())
main.options.scripts.OnShow(main.options)
assert(not anchorOption:GetChecked(),'options retains the saved choice')
anchorOption:SetChecked(true);anchorOption.scripts.OnClick(anchorOption)
assert(db.alwaysAnchorToMain==true and j:GetAlwaysAnchorToMain())
assert(blockOffers:GetChecked()==false,'incoming-offer checkbox defaults off')
blockOffers:SetChecked(true); blockOffers.scripts.OnClick(blockOffers)
assert(j:GetBlockIncomingOffers() and db.blockIncomingOffers,'checkbox immediately saves setting')
main.options.scripts.OnShow(main.options)
assert(blockOffers:GetChecked(),'reopening Options reflects the saved preference')
blockOffers:SetChecked(false); blockOffers.scripts.OnClick(blockOffers)
assert(not j:GetBlockIncomingOffers(),'checkbox can allow offers again')
assert(window.windowTitle.text:find(buildVersion,1,true),'book displays the installed TOC version')
assert(main.shareButton.enabled)
main.shareButton.scripts.OnClick()
local composer=AzerothFieldbookShare
assert(composer.shown and composer.clamped)
local function checkShareLayout()
    local function top(widget) return -widget.point[3] end
    assert(top(composer.rumourHeading)>=124+composer.basicArea:GetHeight()+12)
    assert(top(composer.cost)>=top(composer.rumourArea)+composer.rumourArea:GetHeight()+12)
    assert(top(composer.balance)>=top(composer.cost)+composer.cost:GetStringHeight()+8)
    assert(top(composer.status)>=top(composer.balance)+composer.balance:GetStringHeight()+12)
    assert(top(composer.send)>=top(composer.status)+composer.status:GetStringHeight()+12)
    assert(top(composer.send)+composer.send:GetHeight()+20<=composer:GetHeight())
    if composer.resolve:IsShown() then
        assert(top(composer.resolve)>=top(composer.status)+composer.status:GetStringHeight()+12)
        assert(top(composer.send)>=top(composer.resolve)+composer.resolve:GetHeight())
    end
end
checkShareLayout()
assert(composer.basic.text=='Creature 42 |cff999999[#42]|r')
assert(composer.details.text:find('Humanoid • Level 9',1,true))
eq(j:GetSharingBalance(),6,'opening composer free')
assert(composer.cost.text:find('Total cost: 1',1,true))
assert(composer.send.enabled,'funded report ready outside combat')
for _,selfName in ipairs({'Alice Sunstrider','alice sunstrider','  ALICE   SUNSTRIDER  '}) do
    composer.recipient:SetText(selfName)
    assert(not composer.send.enabled and composer.status.text=='You cannot send an offer to yourself.')
    checkShareLayout()
    composer.send.scripts.OnClick() -- The backend must reject a bypassed disabled control too.
    assert(not engine:GetOutgoing()); eq(select(4,j:GetSharingBalance()),0)
end
composer.recipient:SetText('Bob Stonewell')
assert(composer.send.enabled and not composer.status.text:find('yourself',1,true),'editing recipient clears self-offer error')
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
assert(not composer.send.enabled and composer.status.text:find('Insufficient knowledge',1,true))
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
notes.scripts.OnShow(notes) -- Native Show dispatch, before any pin interaction.
assert(main.creatureNotesButton.afbSelected,'first notes opening highlights its launcher without pinning')
notes:Hide()
assert(not main.creatureNotesButton.afbSelected,'first notes close clears its launcher')
notes:Show();notes.scripts.OnShow(notes)
main.creatureNotesButton.scripts.OnClick();assert(not notes.shown,'Creature Notes button closes its open window')
main.creatureNotesButton.scripts.OnClick();assert(notes.shown,'Creature Notes button reopens its window')
notes.pinButton.scripts.OnClick()
main.creatureNotesButton.scripts.OnClick();assert(notes.shown,'Creature Notes toggle respects pinning')
notes.pinButton.scripts.OnClick()
assert(notes.notesArea.shown and notes.rumoursToggle==nil,'Rumours moved out of Creature Notes')
eq(main.rumoursButton.point[2],main.creatureNotesButton)
eq(main.killCount.point[2],main.rumoursButton,'Rumours is between Kills and Creature Notes')
main.rumoursButton.scripts.OnClick()
local rumours=AzerothFieldbookRumours
assert(rumours.shown and rumours.clamped and notes.shown)
eq(rumours.point[2],window,'resizing Rumours preserves its shared-window default')
eq(main.offensePicker.point[2],main,'observation defaults use the main window, not a moved damage dialog')
eq(main.rankFrame.point[2],main,'rank default uses the main window, not a moved location dialog')
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
assert(plain(rumours.rows[1].text.text):find('Reported by Bob Stonewell',1,true))
assert(plain(rumours.rows[2].text.text):find('Shared basics from Bob Stonewell:',1,true),'attributed basics remain inspectable')
eq(rumours.area.height,rumours.body.height,'one rumour and its basics fit without empty space')
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
npcID=43;book:FollowNotesTarget();eq(notes.creature.text,'Creature 43 |cff999999[#43]|r')
book:Refresh();eq(notes.creature.text,'Creature 43 |cff999999[#43]|r','unchanged book refresh preserves notes target')
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
b:Receive('AFBShare','4~H~'..offered.transaction..'~'..buildVersion,'WHISPER','Alice Sunstrider')
local n=math.ceil(#encoded/180)
for i=1,n do b:Receive('AFBShare','4~O~'..offered.transaction..'~'..i..'~'..n..'~'..encoded:sub((i-1)*180+1,i*180),'WHISPER','Alice Sunstrider') end
local receiver=AzerothFieldbookReceive
assert(receiver.shown and receiver.clamped and receiver.accept.enabled)
assert(receiver.from.text:find('Alice Sunstrider',1,true))
assert(receiver.preview.text:find('unverified rumour',1,true) and receiver.preview.text:find('Adds new information',1,true))
assert(not bob.entries[42]);receiver.accept.scripts.OnClick();assert(not bob.entries[42] and not receiver.accept.enabled)
b:Receive('AFBShare','4~C~'..offered.transaction,'WHISPER','Alice Sunstrider')
assert(bob.entries[42] and not receiver.shown);eq(bob:GetSharingBalance(),0)
eq(#bob:GetRumours(42),3,'receive UI accepts and imports more than two rumours')
assert(bob:DismissRumour(42,bob:GetRumours(42)[1]))
now=now+16;offered.transaction='1000000-45-1';encoded=assert(S.Encode(offered))
b:Receive('AFBShare','4~H~'..offered.transaction..'~'..buildVersion,'WHISPER','Alice Sunstrider')
n=math.ceil(#encoded/180)
for i=1,n do b:Receive('AFBShare','4~O~'..offered.transaction..'~'..i..'~'..n..'~'..encoded:sub((i-1)*180+1,i*180),'WHISPER','Alice Sunstrider') end
assert(receiver.shown and receiver.preview.text:find('Previously rejected',1,true),'incoming preview warns before acceptance')
assert(receiver.preview.text:find('basic-information cost of 1 knowledge will be waived',1,true),'receiver sees that matching basics are free')
receiver.accept.scripts.OnClick()
b:Receive('AFBShare','4~C~'..offered.transaction,'WHISPER','Alice Sunstrider')
assert(bob:GetRumours(42)[1].previouslyRejected)
assert(bob:AddManual(42,'Fireball',''))
now=now+16;offered.transaction='1000000-46-1';encoded=assert(S.Encode(offered))
b:Receive('AFBShare','4~H~'..offered.transaction..'~'..buildVersion,'WHISPER','Alice Sunstrider')
n=math.ceil(#encoded/180)
for i=1,n do b:Receive('AFBShare','4~O~'..offered.transaction..'~'..i..'~'..n..'~'..encoded:sub((i-1)*180+1,i*180),'WHISPER','Alice Sunstrider') end
assert(receiver.preview.text:find('Already in your journal',1,true));receiver.decline.scripts.OnClick()

-- Every movable journal dialog is registered, including unnamed child forms.
-- Help/Options fade only the clipped edges. The decorative overlays must never
-- enable mouse input or cover the close button/extended scrollbar.
for _,page in ipairs({main.help,main.options}) do
    local scroll,bar=page.scroll,page.scroll.ScrollBar
    local range=200
    scroll.GetVerticalScrollRange=function() return range end
    scroll:SetVerticalScroll(0);scroll.scripts.OnScrollRangeChanged(scroll)
    assert(not page.topFade:IsShown() and page.bottomFade:IsShown(),'topmost content stays fully legible')
    scroll:SetVerticalScroll(50);scroll.scripts.OnVerticalScroll(scroll,50)
    assert(page.topFade:IsShown() and page.bottomFade:IsShown(),'both clipped edges fade while scrolling')
    scroll:SetVerticalScroll(range);scroll.scripts.OnVerticalScroll(scroll,range)
    assert(page.topFade:IsShown() and not page.bottomFade:IsShown(),'bottommost content stays fully legible')
    range=0;scroll:SetVerticalScroll(0);scroll.scripts.OnScrollRangeChanged(scroll)
    assert(not page.topFade:IsShown() and not page.bottomFade:IsShown() and not bar:IsShown(),'fades and scrollbar hide when content fits')
    for _,edge in ipairs({page.topFade,page.bottomFade}) do
        assert(not edge:IsMouseClickEnabled() and not edge:IsMouseMotionEnabled() and not edge.scripts.OnMouseDown,
            'focus registration leaves fade overlays click-through')
        eq(edge.strips[1].alpha,1);eq(edge.strips[#edge.strips].alpha,0)
        local previous=1
        for _,strip in ipairs(edge.strips) do
            assert(strip.alpha<=previous);previous=strip.alpha
            assert(strip.texCoord[3]>=0 and strip.texCoord[4]<=1 and strip.texCoord[3]<strip.texCoord[4],
                'fade samples stay aligned within the parchment')
        end
    end
    local top,bottom=bar.points[1],bar.points[2]
    eq(top[2],page.closeButton);eq(top[3],'BOTTOM')
    eq(top[4],-1,'scrollbar top shifts one pixel left')
    eq(1-top[5],bar.ScrollUpButton:GetHeight(),'upper arrow rises one pixel to close the visual gap')
    eq(bottom[2],page);eq(bottom[3],'BOTTOMRIGHT')
    eq(bottom[4],-16,'scrollbar bottom shifts one pixel left')
    eq(bottom[5]-bar.ScrollDownButton:GetHeight(),6,'lower arrow reaches the inside of the bottom border')
    assert(bar.trackBackground and bar.trackBorder,'scrollbar has a contrasting track')
    assert(page.border:GetFrameLevel()>page.topFade:GetFrameLevel() and page.border:GetFrameLevel()>page.bottomFade:GetFrameLevel(),
        'window border draws above both fade overlays')
    assert(not page.border:IsMouseClickEnabled() and not page.border:IsMouseMotionEnabled() and not page.border.scripts.OnMouseDown,
        'border overlay never blocks window controls')
    assert(page.closeButton:GetFrameLevel()>page.border:GetFrameLevel(),'close button remains above the border')
    eq(scroll.points[1][3],-42,'content and fade begin below the compact title bar')
    assert(page.border:GetFrameLevel()>page.titleBar:GetFrameLevel()
        and page.closeButton:GetFrameLevel()>page.border:GetFrameLevel(),'border overlaps title bar while close button stays above it')
    eq(page.titleBar.points[1][3],-3,'title bar raised another pixel')
end
-- Location filters fit their contents and keep at most fifteen rows visible.
do
    local frame=main.locationFrame
    local scroll=frame.scroll
    local entries,getBasic=j.entries,j.GetBasicInfo
    local locations={}
    j.entries={[999]={locations=locations}}
    j.GetBasicInfo=function(self,id) return self.entries[id] end
    local function refreshLocations() frame.scripts.OnShow(frame) end
    refreshLocations()
    assert(frame:GetHeight()<200 and not scroll.ScrollBar.shown,'empty location picker stays compact')
    for i=1,15 do
        locations[string.format('Location %02d',i)]=true
        refreshLocations()
        eq(scroll:GetHeight(),i*28,'viewport fits every row up to fifteen')
        eq(frame:GetHeight(),150+i*28,'window follows content height')
        assert(not scroll.ScrollBar.shown and not scroll.mouseWheel,'no scrolling when all rows fit')
    end
    locations['Location 16']=true;refreshLocations()
    eq(scroll:GetHeight(),15*28,'sixteenth row does not enlarge the window')
    assert(scroll.ScrollBar.shown and scroll.mouseWheel,'overflow enables scrollbar and wheel')
    scroll:SetVerticalScroll(999);refreshLocations()
    eq(scroll:GetVerticalScroll(),28,'offset is clamped to the overflow')
    locations['Location 16']=nil;refreshLocations()
    eq(scroll:GetVerticalScroll(),0,'shrinking below the cap restores the top')
    assert(not scroll.ScrollBar.shown and not scroll.mouseWheel)
    locations[string.rep('A long location ',8)]=true;refreshLocations()
    assert(scroll:GetHeight()>15*28,'wrapped names keep enough row height for legibility')
    local bar=scroll.ScrollBar
    assert(bar.trackBackground and bar.trackBorder,'Locations uses the shared parchment scrollbar track')
    eq(bar.points[1][2],frame.closeButton,'Locations top arrow follows the close button')
    eq(bar.points[2][2],frame,'Locations scrollbar follows the resized window')
    j.entries,j.GetBasicInfo=entries,getBasic
    refreshLocations()
end
-- Both points sections contribute to the Help scroll content and cannot overlap About.
do
    main.help.scripts.OnShow(main.help)
    local block=main.help.pointsBlock
    eq(block.title.text,'Knowledge')
    assert(block.awards.text:find('+3 for 50 kills',1,true))
    assert(block.spending.text:find('1 knowledge per selected rumour',1,true))
    assert(block.spending.text:find('free if the recipient already knows it',1,true))
    local bottom=0
    for _,text in ipairs({block.title,block.awardHeading,block.awards,block.spendHeading,block.spending}) do
        local top=-text.point[3]
        assert(top>bottom,'Points subsections are separated and grow with their text')
        bottom=top+text:GetStringHeight()
    end
    eq(block:GetHeight(),bottom+14,'Points block includes both sections and bottom padding')
end
ns.ShowDebugReport('Position test')
local windows={window,main.help,main.options,main.locationFrame,main.rankFrame,
    main.offensePicker,main.defensePicker,main.behaviourPicker,AzerothFieldbookBestiaryDamageNotes,
    notes,rumours,composer,receiver,AzerothFieldbookDebugReport}
for _,frame in ipairs({window,main.help,main.options,main.locationFrame,main.rankFrame,
    main.offensePicker,main.defensePicker,main.behaviourPicker,main.notesForm,
    main.effectPicker,main.damageForm,main.deleteForm,notes,rumours,composer,receiver,AzerothFieldbookDebugReport}) do
    assert(frame.parent==UIParent and frame.strata=='DIALOG' and frame.toplevel,
        'each independent window must be able to raise above every other addon window')
    frame.scripts.OnMouseDown(frame); eq(focusedWindow,frame)
end
composer.recipient.scripts.OnMouseDown(composer.recipient)
eq(focusedWindow,composer,'clicking a text field raises its own window')
notes.notesArea.scripts.OnMouseDown(notes.notesArea,'LeftButton')
eq(focusedWindow,notes); assert(notes.notes.focus,'focus hooks preserve the original control handler')
window.titleBar.scripts.OnMouseDown(window.titleBar)
eq(focusedWindow,window,'the book can return to the front after its independent dialogs')
local lateControl=CreateFrame('Button',nil,composer)
local decoration=CreateFrame('Frame',nil,composer)
local hoverOnly=CreateFrame('Frame',nil,decoration)
hoverOnly:SetMouseMotionEnabled(true)
local disabledControl=CreateFrame('Button',nil,decoration)
disabledControl:SetMouseClickEnabled(false)
local clickOnly=CreateFrame('Button',nil,decoration)
local originalClicks=0
clickOnly:SetScript('OnMouseDown',function() originalClicks=originalClicks+1 end)
clickOnly:SetMouseMotionEnabled(false)
composer.scripts.OnShow(composer)
assert(not decoration:IsMouseClickEnabled() and not decoration.scripts.OnMouseDown)
assert(not hoverOnly:IsMouseClickEnabled() and hoverOnly:IsMouseMotionEnabled() and not hoverOnly.scripts.OnMouseDown,
    'hover-only containers retain their original mouse behavior')
assert(not disabledControl:IsMouseClickEnabled() and not disabledControl.scripts.OnMouseDown)
assert(clickOnly:IsMouseClickEnabled() and not clickOnly:IsMouseMotionEnabled(),
    'adding a focus hook must preserve click-only controls')
clickOnly.scripts.OnMouseDown(clickOnly,'LeftButton')
eq(originalClicks,1); eq(focusedWindow,composer,'interactive children still focus through decorative containers')
disabledControl:SetMouseClickEnabled(true)
composer.scripts.OnShow(composer)
disabledControl.scripts.OnMouseDown(disabledControl,'LeftButton')
eq(focusedWindow,composer,'controls enabled later gain focus handling on reopening')
clickOnly.scripts.OnMouseDown(clickOnly,'LeftButton'); eq(originalClicks,2,'reopening does not duplicate original handlers')
lateControl.scripts.OnMouseDown(lateControl)
eq(focusedWindow,composer,'reopening also hooks newly added controls')
ns.WindowFocus:Register(composer) -- Repeated registration must not replace handlers.
composer.recipient.scripts.OnMouseDown(composer.recipient); eq(focusedWindow,composer)
for _,frame in pairs(windows) do
    frame.left=320; frame.top=700
    frame.scripts.OnDragStop(frame)
    assert(db.windowPositions[frame:GetName()],frame:GetName()..' must save its position')
end
for key,frame in pairs({AbilityEffects=main.effectPicker,DamageObservation=main.damageForm}) do
    frame.left=240; frame.top=600; frame.scripts.OnDragStop(frame)
    assert(db.windowPositions[key],key..' must save its position')
end
GetCursorPosition=function() return 10,20 end
window.titleBar.scripts.OnDragStart()
window.left=360; window.top=740; window.titleBar.scripts.OnDragStop()
eq(db.windowPositions.AzerothFieldbookBestiary.left,360*window:GetEffectiveScale(),'titlebar drag saves the book')

-- Short reports shrink; long metadata and many wrapped claims keep scrolling
-- without allowing footer controls to overlap the report contents.
npcID=43;book:OpenAtUnit('target');main.shareButton.scripts.OnClick()
checkShareLayout()
local compactHeight=composer:GetHeight()
assert(compactHeight<500,'an empty report no longer reserves a full-height rumour list')
assert(composer.empty:IsShown())
local shortLocations=j.entries[43].locations
j.entries[43].locations={}
for i=1,12 do
    if i<=8 then j.entries[43].locations['Long observed location '..i..string.rep(' far away',3)]=true end
    j:AddManual(43,'Spell '..i..string.rep(' wide name',6),'')
end
main.shareButton.scripts.OnClick();checkShareLayout()
assert(composer:GetHeight()>compactHeight)
assert(composer.basicBody:GetHeight()>composer.basicArea:GetHeight(),'long locations scroll')
assert(composer.rumourBody:GetHeight()>composer.rumourArea:GetHeight(),'long rumour lists scroll')
assert(composer.rumourArea:GetHeight()<=166 and composer.basicArea:GetHeight()<=112)
j.entries[43].locations=shortLocations
j.entries[43].abilities={}
main.shareButton.scripts.OnClick();checkShareLayout()
eq(composer:GetHeight(),compactHeight,'reopening a short report removes the old empty space')

-- Reproduce the crowded creature summary: Behaviour moves intact to its own
-- hanging-indent paragraph, and extra details never cover the lower panels.
local entry=j.entries[43]
entry.offenses={Nature=true};entry.resistances={Arcane=true};entry.immunities={Fire=true}
entry.behaviours={}
for _,name in ipairs({'Hostile','Melee','Flees at low health','Calls allies','Patrols','Summons','Heals','Enrages','Stealths'}) do
    entry.behaviours[name]=true
end
book:Refresh()
assert(main.summaryCombatRows[1].text:find('Casts: |cff72d65bNature|r',1,true))
assert(not main.summaryCombatRows[1].text:find('Behaviour:',1,true))
assert(main.summaryCombatRows[2].text:find('Behaviour:',1,true)==1 and main.summaryCombatRows[2].indentedWrap)
local function checkSummaryPanels()
    local bottom=84+main.summaryArea:GetHeight()
    local extra=-main.detail.point[3]
    assert(extra-main.modelBorder.point[3]>=bottom+5,'summary stays above the illustration')
    assert(extra-main.damageBorder.point[3]>=bottom+5,'summary stays above the damage panel')
    eq(main.damageScroll:GetHeight(),75,'expanded summary preserves the damage viewport')
    eq(main.model:GetHeight(),164,'expanded summary preserves the illustration size')
    eq(main:GetHeight(),740+extra,'the book grows to include its shifted content')
    assert(main.confirm.parent==main,'entry lock stays alongside the creature title')
    assert(main.message.parent==main.detail,'footer status follows the shifted controls')
    assert(main.summaryArea.kind=='Frame' and not main.summaryArea:IsMouseClickEnabled(),
        'summary is a plain container without scrollbars or intercepted clicks')
end
checkSummaryPanels()
entry.locations={}
for i=1,8 do entry.locations['Long observed location '..i..string.rep(' far away',5)]=true end
book:Refresh();checkSummaryPanels()
assert(main.summaryArea:GetHeight()>85 and main:GetHeight()>740,
    'extensive location and trait lists grow the summary and book without scrolling')
local last=main.summaryCombatRows[2]
assert(main.summaryArea:GetHeight()>=-last.point[3]+last:GetStringHeight(),'even the final wrapped line fits in the summary')
entry.locations=shortLocations;entry.offenses={};entry.resistances={};entry.immunities={};entry.behaviours={}
book:Refresh();checkSummaryPanels()
assert(not main.summaryCombatRows[1]:IsShown() and not main.summaryCombatRows[2]:IsShown(),'cleared groups leave no stale text')
eq(-main.modelBorder.point[3],133,'short summary restores the original panel layout')
eq(main.damageScroll:GetHeight(),75)
eq(main:GetHeight(),740,'clearing the expanded summary restores the original book height')

-- Full reset clears in-flight composition as well as saved accounting and positions.
main.shareButton.scripts.OnClick();assert(composer.shown)
main.rumoursButton.scripts.OnClick();assert(rumours.shown)
j:ResetDatabase();assert(not composer.shown);eq(j:GetSharingBalance(),0)
assert(next(db.windowPositions)==nil,'full reset clears saved positions')
rumours.scripts.OnUpdate();assert(rumours.rows[1].text.text:find('No unverified rumours',1,true))
assert(rumours.rows[1].claim==nil and rumours.message.text=='','reset clears the open review window')

-- Backup buttons use the fixed Options footer; restore is previewed and requires
-- a separate confirmation. Native widgets are mocked, not visually rendered.
StaticPopupDialogs={}
local popup
function StaticPopup_Show(key,text,_,data) popup={key=key,text=text,data=data} end
local options=main.options
eq(options.backupButton.point[2],208);eq(options.restoreButton.point[2],378)
eq(options.backupButton.point[3],-722,'backup shares the reset footer baseline')
j:Ensure(43,false,'Saved creature');j:SetCreatureNotes(43,'A private note')
options.backupButton.scripts.OnClick()
local backups=main.backupWindow.frame
assert(backups:IsShown() and backups.restoreButton.enabled)
eq(#j:GetBackups().saved,1)
assert(backups.status.text:find('Backup saved',1,true))
assert(backups:GetHeight()<600,'one saved backup keeps the window compact')
backups.exportButton.scripts.OnClick()
assert(backups.text:GetText():sub(1,5)=='AFB1:' and not backups.restoreButton.enabled)
local exported=backups.text:GetText()
j:DeleteEntry(43)
backups.importButton.scripts.OnClick()
assert(not backups.restoreButton.enabled)
backups.text:SetText(exported:sub(1,-2));backups.previewButton.scripts.OnClick()
assert(not backups.restoreButton.enabled and not j.entries[43],'invalid import leaves the journal untouched')
backups.text:SetText(exported);backups.previewButton.scripts.OnClick()
assert(backups.restoreButton.enabled and not j.entries[43],'preview is read-only')
backups.restoreButton.scripts.OnClick()
assert(popup.key=='AZEROTHFIELDBOOK_RESTORE_CONFIRM' and popup.data)
assert(not j.entries[43],'clicking Restore still waits for the confirmation')
StaticPopupDialogs[popup.key].OnAccept(nil,popup.data)
eq(j.entries[43].idNotes.text,'A private note')
assert(j:GetBackups().recovery and not j:GetBackups().recovery.bestiary.entries[43])
assert(backups.status.text:find('Bestiary restored',1,true))
assert(backups.rows[1].text.text:find('Before last restore',1,true))
backups:Hide();options.restoreButton.scripts.OnClick()
assert(backups:IsShown() and backups.preview.text:find('creatures',1,true))
eq(#j:GetBackups().saved,1,'opening Restore does not create another manual backup')
-- Simulate native visibility scripts (this mock's Show does not dispatch OnShow).
for _,pair in ipairs({
    {main.rumoursButton,rumours},{main.creatureNotesButton,notes},{main.shareButton,composer},
    {main.damageButton,main.damageForm},{main.offenseButton,main.offensePicker},
    {main.defenseButton,main.defensePicker},{main.behaviourButton,main.behaviourPicker},
    {main.effectButton,main.effectPicker},{main.locationsButton,main.locationFrame},
    {main.ranksButton,main.rankFrame},
}) do
    local control,window=pair[1],pair[2]
    window:Hide()
    assert(not control.afbSelected,'closed window clears its launcher border')
    window:Show();window.scripts.OnShow(window)
    assert(control.afbSelected,'opening a window selects its launcher border')
    book:Refresh()
    assert(control.afbSelected,'journal refresh preserves the open-window indicator')
    window:Hide()
    assert(not control.afbSelected,'closing without clicking the launcher clears its border')
end
main.offensePicker:Show();main.offensePicker.scripts.OnShow(main.offensePicker)
main.defensePicker:Show();main.defensePicker.scripts.OnShow(main.defensePicker)
assert(not main.offenseButton.afbSelected and main.defenseButton.afbSelected,
    'switching the shared observation panel updates both launchers')
main.defensePicker:Hide()
''')
lua.execute(r'''
do
    local j=ns.CreateBestiaryJournal({},function() return nil end)
    for i=1,35 do local entry=j:Ensure(i,false,string.format('Creature %02d',i));entry.category='Beast' end
    local book=ns.CreateBestiaryBook(j);book:Toggle()
    local main=AzerothFieldbookBestiarySection
local window=book:GetShell():GetFrame()
    eq(#main.rows,16);assert(main.creatureScrollBar.shown)
    eq(-main.rows[16].point[3]+main.rows[16]:GetHeight(),588,'list fills space to eight pixels above navigation')
    local width=main.rows[1]:GetWidth()
    local left=main.rows[1].point[2]
    assert(left+width<main.creatureScrollBar.point[2],'scrollbar has a reserved gutter')
    main.creatureScrollBar.scripts.OnValueChanged(main.creatureScrollBar,19)
    eq(main.rows[16].id,35,'dragging reaches the last entry')
    main.rows[1].scripts.OnMouseWheel(main.rows[1],1);eq(main.rows[1].id,17,'wheel and slider use the same offset')
    main.search:SetText('Creature 01');main.search.scripts.OnTextChanged(main.search)
    assert(not main.creatureScrollBar.shown and main.rows[1].id==1)
    eq(main.rows[1]:GetWidth(),width,'hiding scrollbar never moves the row edge')
    main.search:SetText('');main.search.scripts.OnTextChanged(main.search)
    assert(main.creatureScrollBar.shown)
    local review=ns.CreateRumoursWindow(j,nil,function() return main end)
    review:Toggle(1)
    local frame=AzerothFieldbookRumours
    frame.area.GetVerticalScrollRange=function() return math.max(0,frame.body:GetHeight()-frame.area:GetHeight()) end
    local empty=frame:GetHeight()
    local base={creatureID=1,name='Creature 01',category='Beast',levelMin=8,levelMax=8,locations={'Elwynn Forest'},
        sender='Erna Lionguard',received=now,transaction='1-1-1',source='WHISPER'}
    j.entries[1].sharedReports={base}
    j.entries[1].rumours={}
    local previous=empty
    for count=1,5 do
        j.entries[1].rumours[count]={creatureID=1,kind='ability',value='Rumour '..count,sender='Erna Lionguard',received=now,transaction='1-1-1',source='WHISPER'}
        review:Refresh()
        if count<=4 then
            eq(frame.area:GetHeight(),frame.body:GetHeight(),'up to four rumours plus basics fit')
            assert(not frame.area.ScrollBar.shown)
            assert(frame:GetHeight()>previous);previous=frame:GetHeight()
        else
            assert(frame.area.ScrollBar.shown and frame.area:GetHeight()<frame.body:GetHeight())
            eq(frame:GetHeight(),previous,'fifth rumour uses scrolling instead of growing')
        end
    end
    local compactWidth=frame:GetWidth()
    local shortText=j.entries[1].rumours[1].value
    j.entries[1].rumours[1].value=string.rep('Long rumour ',8)
    review:Refresh()
    assert(frame:GetWidth()>compactWidth and frame:GetWidth()<=420,'long content grows to a bounded width')
    assert(frame.rows[1].text:GetStringHeight()>28,'long text wraps inside the bounded column')
    j.entries[1].rumours[1].value=shortText
    review:Refresh()
    eq(frame:GetWidth(),compactWidth,'short content shrinks the window again')
    assert(frame.area.ScrollBar.trackBackground and frame.area.ScrollBar.trackBorder)
    eq(frame.area.ScrollBar.points[1][2],frame.closeButton,'Rumours uses the shared window scrollbar anchors')
    for i=1,5 do
        local row=frame.rows[i]
        eq(row.divider.shown,i>1)
        if i>1 then assert(-row.text.point[3]>=12,'divider has padding below it') end
        eq(row.verify.point[3],row.remove.point[3],'tick and cross share a baseline')
        eq(row.verify.point[1],'TOPLEFT');eq(row.remove.point[1],'TOPLEFT')
        assert(row.verify.point[2]+row.verify:GetWidth()<row.remove.point[2],'verify precedes reject with a gap')
        assert(row.remove.point[2]+row.remove:GetWidth()<row.text.point[2],'rumour follows both buttons with padding')
        assert(row.text.point[2]+row.text:GetWidth()<=row:GetWidth(),'text stays inside the row')
        assert(row.verify.cover and row.verify.check,'Rumours uses the framed confirm style')
    end
    j:SetEntryConfirmed(1,true);review:Refresh();assert(not frame.rows[1].verify.enabled)
    j:SetEntryConfirmed(1,false);j.entries[1].rumours={};j.entries[1].sharedReports={};review:Refresh()
    assert(not frame.area.ScrollBar.shown);eq(frame:GetHeight(),empty,'empty page collapses again')
end
''')
lua.execute(r'''
do
    local j=ns.CreateBestiaryJournal({},function(unit) if unit=="mouseover" then return 42 end end)
    local e=j:Ensure(42,true)
    e.sharedReports={
        {name='Shared creature',category='Beast',locations={},sender='Erna Lionguard'},
        {name='Shared creature',category='Beast',locations={},sender='erna lionguard'},
        {name='Shared creature',category='Beast',locations={},sender='Peww Pewz'},
    }
    local sources=j:GetSharedSources(42)
    eq(#sources,2);eq(sources[1],'Erna Lionguard');eq(sources[2],'Peww Pewz')
    eq(#j:GetSharedSources(99),0)
    local book=ns.CreateBestiaryBook(j);book:Toggle()
    local main=AzerothFieldbookBestiarySection
local window=book:GetShell():GetFrame()
    main.rows[1].scripts.OnClick(main.rows[1])
    assert(main.modelUnknown.shown and not main.model.shown,'shared-only portrait is a question mark')
    assert(main.rows[1].unknownMark.shown and not main.rows[1].killReward.shown,'shared-only list entry shows a question mark instead of a reward')
    eq(main.rows[1].text:GetWidth(),121,'question mark reserves name space')
    local observationButtons={main.damageButton,main.offenseButton,main.defenseButton,
        main.behaviourButton,main.effectButton,main.confirmAbilityButton}
    for _,control in ipairs(observationButtons) do
        assert(not control.enabled and control.encounterHint.shown,'shared-only observations are disabled with a hover explanation')
    end
    local previousTooltip=GameTooltip
    GameTooltip={SetOwner=function(self,owner) self.owner=owner end,
        SetText=function(self,text) self.title=text end,AddLine=function(self,text) self.line=text end,
        Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end,
        IsOwned=function(self,owner) return self.owner==owner end}
    local hint=main.damageButton.encounterHint
    hint.scripts.OnEnter(hint)
    assert(GameTooltip.shown and GameTooltip.line:find('not personally encountered',1,true))
    hint.scripts.OnLeave(hint);assert(not GameTooltip.shown)
    GameTooltip=previousTooltip
    local originalSetCreature=main.model.SetCreature
    local portraitLoads=0
    main.model.SetCreature=function(self,id)
        assert(j.entries[id].personalEncountered==true,'shared IDs must not load creature artwork')
        portraitLoads=portraitLoads+1
        return originalSetCreature(self,id)
    end
    main.rows[1].scripts.OnClick(main.rows[1])
    eq(portraitLoads,0,'reselecting shared info does not load its portrait')
    assert(main.sourceStatus.text:find('Erna Lionguard',1,true))
    assert(main.sourceTooltip.text:find('Peww Pewz',1,true) and main.sourceTooltip.text:find('Not personally encountered',1,true))
    local tooltip=GameTooltip
    GameTooltip={SetOwner=function() end,SetText=function() end,Show=function() end,
        AddLine=function(self,text) self.line=text end,Hide=function() end}
    main.sourceTooltip.scripts.OnEnter(main.sourceTooltip)
    assert(GameTooltip.line:find('Erna Lionguard',1,true) and GameTooltip.line:find('Peww Pewz',1,true))
    GameTooltip=tooltip
    for _,name in ipairs({'Another Longsurname','Someone Longsurname','Yet Anothername','Very Longname'}) do
        e.sharedReports[#e.sharedReports+1]={name='Shared creature',category='Beast',locations={},sender=name}
    end
    book:Refresh()
    assert(main.sourceStatus.text:find('+5 others',1,true),'many sources use a compact label')
    for _,name in ipairs(j:GetSharedSources(42)) do assert(main.sourceTooltip.text:find(name,1,true)) end
    main.rumoursButton.scripts.OnClick()
    local rumours=AzerothFieldbookRumours
    assert(plain(rumours.rows[2].text.text):find('Shared basics from Erna Lionguard:',1,true))
    assert(main.sourceStatus.text:find('|cff8c9494',1,true),'unknown names are grey')
    local oldPlayer,oldName,oldClass=UnitIsPlayer,UnitNameUnmodified,UnitClass
    local oldColours=RAID_CLASS_COLORS
    UnitIsPlayer=function(unit) return unit=='party1' end
    UnitNameUnmodified=function(unit) if unit=='party1' then return 'Erna','Lionguard' end end
    UnitClass=function() return 'Mage','MAGE' end
    RAID_CLASS_COLORS={MAGE={r=0.25,g=0.78,b=0.92}}
    ns.PlayerNames:Observe('party1')
    main.scripts.OnUpdate(main,0.5);rumours.scripts.OnUpdate(rumours)
    assert(main.sourceTooltip.text:find('|cff40c7ebErna Lionguard|r',1,true),'open book refreshes when the class is verified')
    assert(rumours.rows[2].text.text:find('|cff40c7ebErna Lionguard|r',1,true),'Rumours also refreshes its attribution')
    eq(e.sharedReports[1].sender,'Erna Lionguard','stored sender stays plain')
    eq(main.sourceStatus.textColor[1],0.55,'Shared by text stays grey outside name markup')
    UnitIsPlayer,UnitNameUnmodified,UnitClass=oldPlayer,oldName,oldClass
    RAID_CLASS_COLORS=oldColours

    j:Observe('mouseover');book:Refresh()
    assert(not main.modelUnknown.shown and main.model.shown,'personal encounter reveals the open portrait')
    eq(portraitLoads,1,'encounter refresh loads the newly revealed portrait')
    assert(not main.rows[1].unknownMark.shown,'personal encounter removes the list question mark')
    for _,control in ipairs(observationButtons) do
        assert(control.enabled and not control.encounterHint.shown,'encounter enables unlocked observations')
    end
    eq(main.sourceStatus.text,'');assert(not main.sourceTooltip.shown,'personal encounter hides portrait attribution')
    j:SetEntryConfirmed(42,true);book:Refresh()
    for _,control in ipairs(observationButtons) do
        assert(not control.enabled and control.encounterHint.shown,'locked observations have a hover explanation')
        eq(control.encounterHint.title,'Creature locked')
        eq(control.encounterHint.description,'Unlock this creature to edit its observations.')
    end
    eq(main.sourceStatus.text,'');assert(not main.sourceTooltip.shown,'locking does not restore attribution')
    assert(e.lockedBasic.sources==nil,'source display never changes the saved basic-info schema')

    local options=main.options
    options.scripts.OnShow(options)
    assert(options.lockNewCritters:GetChecked())
    assert(options.killCountTooltips:GetChecked() and j:GetKillCountTooltips())
    options.killCountTooltips:SetChecked(false);options.killCountTooltips.scripts.OnClick(options.killCountTooltips)
    options.scripts.OnShow(options)
    assert(not options.killCountTooltips:GetChecked() and not j:GetKillCountTooltips())
    options.killCountTooltips:SetChecked(true);options.killCountTooltips.scripts.OnClick(options.killCountTooltips)
    options.lockNewCritters:SetChecked(false);options.lockNewCritters.scripts.OnClick(options.lockNewCritters)
    options.scripts.OnShow(options)
    assert(not j:GetLockNewCritters() and not options.lockNewCritters:GetChecked())
    e.sharedReports={};book:Refresh()
    eq(main.sourceStatus.text,'');assert(not main.sourceTooltip.shown)
    -- Only outstanding rumours colour a name; shared basics/history alone do not.
    local function rowFor(id)
        for _,row in ipairs(main.rows) do if row.id==id then return row end end
        error('missing creature row')
    end
    local function isGreen(row)
        local colour=row.text.textColor
        return colour[1]==114/255 and colour[2]==214/255 and colour[3]==91/255
    end
    assert(not isGreen(rowFor(42)))
    j:SetEntryConfirmed(42,false)
    local rejected={kind='behaviour',value='Melee',sender='Erna Lionguard'}
    local verified={kind='offense',value='Fire',sender='Erna Lionguard'}
    e.rumours={rejected,verified,
        {kind='ability',value='Old report',sender='Erna Lionguard',resolved=true},
        {kind='ability',value='Dismissed report',sender='Erna Lionguard',dismissed=true}}
    j:Touch();book:Refresh()
    assert(isGreen(rowFor(42)),'selected entries keep the outstanding-rumour colour')
    j:Ensure(43,false,'Another creature');book:Refresh()
    local other=rowFor(43);other.scripts.OnClick(other)
    assert(isGreen(rowFor(42)) and not isGreen(rowFor(43)))
    assert(j:DismissRumour(42,rejected));book:Refresh()
    assert(isGreen(rowFor(42)),'one remaining rumour keeps the name green')
    assert(j:ConfirmRumour(42,verified));book:Refresh()
    assert(not isGreen(rowFor(42)) and #j:GetRumours(42)==0)
    eq(rowFor(42).text.textColor[1],0.75,'unselected name returns to normal ink')
    local row=rowFor(42);row.scripts.OnClick(row)
    eq(row.text.textColor[1],1,'selected name returns to gold')
    -- Beast Lore borrows exactly one button row, preserving every other anchor.
    local detailPoint=main.detail.point
    local offensePoint=main.offenseButton.point
    local defensePoint=main.defenseButton.point
    local behaviourPoint=main.behaviourButton.point
    assert(not main.beastLoreButton.shown)
    eq(main.damageBorder:GetHeight(),115);eq(main.damageScroll:GetHeight(),75)
    eq(main.damageButton.point[3],-248)
    e.category='Beast';j:Touch();book:Refresh()
    assert(main.beastLoreButton.shown)
    eq(main.damageBorder:GetHeight(),86);eq(main.damageScroll:GetHeight(),46)
    eq(main.damageButton.point[3],-248);eq(main.beastLoreButton.point[3],-133)
    eq(main.damageBorder.point[3],-162);eq(main.damageScroll.point[3],-192)
    for _,pair in ipairs({{main.detail,detailPoint},
        {main.offenseButton,offensePoint},{main.defenseButton,defensePoint},{main.behaviourButton,behaviourPoint}}) do
        for index,value in ipairs(pair[2]) do eq(pair[1].point[index],value,'existing anchor stays fixed') end
    end
    main.beastLoreButton.scripts.OnClick();assert(main.beastLore.shown)
    eq(main.beastLore.creature.text,j:GetBasicInfo(42).name)
    eq(main.beastLore.creature.textColor[1],1);eq(main.beastLore.creature.textColor[2],0.82)
    assert(not main.beastLore.send.enabled,'empty lore cannot be sent')
    e.beastLore={level=12,observed=now,rows={{left='Health:',right='244'},{left='Diet:',right='Meat'}}}
    e.beastLoreSource='gameTooltip';j:Touch();book:Refresh()
    assert(main.beastLore.content.text:find('Health:  244',1,true))
    assert(main.beastLore.provenance.text:find('Locked',1,true))
    local sentRecipient
    local oldSharing=j.sharing
    j.sharing={Start=function(_,captured,recipient,claims)
        assert(captured.beastLore.rows[2].right=='Meat' and #claims==0)
        sentRecipient=recipient;return nil,'Test send response'
    end}
    book:Refresh();assert(main.beastLore.send.enabled)
    main.beastLore.recipient:SetText('Bob Stonewell');main.beastLore.send.scripts.OnClick()
    eq(sentRecipient,'Bob Stonewell');eq(main.beastLore.status.text,'Test send response')
    j.sharing=oldSharing
    j:SetEntryConfirmed(42,true);book:Refresh()
    assert(main.beastLore.shown and main.beastLoreButton.enabled~=false,'locked beasts can read lore')
    main.beastLore.closeButton.scripts.OnClick();assert(not main.beastLore.shown)
    main.beastLoreButton.scripts.OnClick();assert(main.beastLore.shown)
    local other=rowFor(43);other.scripts.OnClick(other)
    assert(not main.beastLore.shown and not main.beastLoreButton.shown)
    eq(main.damageBorder:GetHeight(),115);eq(main.damageScroll:GetHeight(),75)
    eq(main.damageBorder.point[3],-133);eq(main.damageScroll.point[3],-163)
    eq(main.damageButton.point[3],-248)
    eq(main.sortButton:GetWidth(),main.sortButton:GetHeight(),'sort control is square')
    assert(main.search.point[2]+main.search:GetWidth()<main.sortButton.point[2])
    main.sortButton.scripts.OnClick();assert(main.sortMenu.shown)
    assert(main.sortChoices[1].control.afbSelected and main.sortChoices[6].control.afbSelected)
    main.sortChoices[2].control.scripts.OnClick()
    eq(j:GetListSort(),'kills');assert(main.sortChoices[2].control.afbSelected)
    main.sortChoices[7].control.scripts.OnClick()
    local field,descending=j:GetListSort();assert(field=='kills' and descending)
    main.sortMenu.scripts.OnClick(main.sortMenu);assert(not main.sortMenu.shown)
    local hovering=rowFor(42)
    hovering.text:SetText('Stonesplinter Skullthumper with a long name')
    hovering.scripts.OnEnter(hovering)
    assert(hovering.nameViewport.shown and not hovering.text.shown)
    hovering.scripts.OnUpdate(hovering,0.5)
    eq(hovering.nameViewport.horizontalScroll,0,'hover pauses before moving')
    hovering.scripts.OnUpdate(hovering,0.8)
    assert(hovering.nameViewport.horizontalScroll>0,'long names gently scroll')
    eq(hovering.nameViewport:GetWidth(),hovering.text:GetWidth(),'hover text clips before rewards')
    hovering.scripts.OnLeave(hovering)
    assert(not hovering.nameViewport.shown and hovering.text.shown and not hovering.scripts.OnUpdate)
    eq(hovering.nameViewport.horizontalScroll,0)
    hovering.text:SetText('Wolf');hovering.scripts.OnEnter(hovering)
    assert(not hovering.nameViewport.shown and not hovering.scripts.OnUpdate,'short names stay still')
    hovering.text:SetText('Another long creature name that needs to scroll');hovering.scripts.OnEnter(hovering)
    book:Refresh()
    assert(not hovering.nameViewport.shown and not hovering.scripts.OnUpdate,'row refresh clears stale animated text')
end
''')
print('PASS: Share button, captured selection, unrestricted rumour selection, per-rumour costs, balances, native controls, receive consent, separate Rumours toggle, verification/rejection, manual refresh, Notes input, pinning and scaling')
