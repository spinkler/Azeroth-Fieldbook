"""Recipient controls, outcomes and appearance through the real sharing UI."""
from ui_test_harness import new_ui_client

lua = new_ui_client([
    'Scrollbars.lua', 'SharingReport.lua', 'BestiaryJournal.lua',
    'Sharing.lua', 'SharingWindow.lua',
])
lua.execute(r'''
local shift=false
function IsShiftKeyDown() return shift end
local nativeCalls,hooks=0,0
ChatFrameUtil={InsertLink=function() nativeCalls=nativeCalls+1;return 'native' end}
ChatEdit_InsertLink=function() nativeCalls=nativeCalls+1;return 'legacy' end
local references={}
function SetItemRef(...)
    references[#references+1]={...}
    -- A native name-click path can bypass InsertLink completely, and its
    -- normal processing can take focus away from the addon field.
    if AzerothFieldbookShare then AzerothFieldbookShare.recipient:ClearFocus() end
    return 'native reference','second result'
end
function hooksecurefunc(target,key,callback)
    if type(target)=='string' then callback=key;key=target;target=_G end
    local original=target[key]
    target[key]=function(...) local result=original(...);callback(...);return result end
    hooks=hooks+1
end
local db={}
local journal=ns.CreateBestiaryJournal(db,function() return 42 end)
local entry=journal:Ensure(42,false,'Defias Pillager',{level=9})
entry.category='Humanoid';entry.locations.Elwynn=true
db.bestiary.points.earned=10
local env={ready=true,addonVersion=buildVersion,character='Alice Sunstrider',now=function() return now end,
    blocked=function() return combat end,send=function() return true end}
local engine=ns.CreateSharing(journal,env)
local ui=ns.CreateSharingWindow(journal,engine)
ui:Open(42)
local composer=AzerothFieldbookShare
composer.recipient.HasFocus=function(self) return self.focus==true end
shift=true
composer.recipient:SetFocus()
SetItemRef("player:Élan O'Connor-Smith:17:SAY",'[Nickname]','LeftButton')
eq(composer.recipient:GetText(),"Élan O'Connor-Smith",'chat player clicks work without calling InsertLink')
eq(#references,0,'the focused recipient consumes the click before native who/whisper handling')
assert(composer.recipient:HasFocus())
SetItemRef('player:Bob Stonewell:18:WHISPER','[Different display name]','LeftButton')
eq(composer.recipient:GetText(),'Bob Stonewell','a second click replaces the complete name')
for _,case in ipairs({
    {'player:Carol Riverwind:1:SAY','RightButton',true},
    {'player:Carol Riverwind:1:SAY','LeftButton',false},
    {'item:123','LeftButton',true}, {'spell:133','LeftButton',true},
    {'BNplayer:Display Name:123','LeftButton',true}, {'player:Bad123:1','LeftButton',true},
    {secret,'LeftButton',true},
}) do
    composer.recipient:SetFocus();shift=case[3]
    local frame={};local count=#references
    local first,second=SetItemRef(case[1],'display',case[2],frame)
    eq(first,'native reference');eq(second,'second result');eq(#references,count+1)
    assert(references[#references][4]==frame,'unhandled clicks retain their native context and results')
    eq(composer.recipient:GetText(),'Bob Stonewell')
end
shift=true;composer.recipient:ClearFocus()
SetItemRef('player:Carol Riverwind:1:SAY','[Carol]','LeftButton')
eq(composer.recipient:GetText(),'Bob Stonewell','unfocused fields preserve normal chat behavior')
composer.recipient:SetText('')
ChatFrameUtil.InsertLink('Bob Stonewell')
eq(composer.recipient:GetText(),'','unfocused fields ignore chat names')
composer.recipient:SetFocus();shift=false
ChatFrameUtil.InsertLink('Bob Stonewell');eq(composer.recipient:GetText(),'','ordinary clicks do not fill names')
shift=true
eq(ChatFrameUtil.InsertLink("Élan O'Connor-Smith"),'native')
eq(composer.recipient:GetText(),"Élan O'Connor-Smith",'full surnames replace the field contents')
for _,text in ipairs({'|Hitem:123|h[Item]|h','|Hspell:133|h[Fireball]|h','Bad123',secret}) do
    ChatFrameUtil.InsertLink(text);eq(composer.recipient:GetText(),"Élan O'Connor-Smith")
end
eq(ChatEdit_InsertLink('|cffabcdef|Hplayer:Bob Stonewell:1:SAY|h[Nickname]|h|r'),'legacy')
eq(composer.recipient:GetText(),'Bob Stonewell','use the player identity rather than decorated display text')
assert(not engine:GetOutgoing() and #engine:GetSavedRecipients()==0,'shift-click only fills the field')
ChatFrameUtil.InsertLink('Alice Sunstrider');assert(not composer.send.enabled,'self-offer checks still apply')
composer.recipient:ClearFocus();composer.recipient:SetText('')
assert(not composer.saveName.enabled)
composer.recipient:SetText('  Bob   Stonewell  ')
assert(composer.saveName.enabled)
composer.saveName.scripts.OnClick()
assert(engine:IsSavedRecipient('Bob Stonewell'))
assert(not composer.saveName.enabled and composer.saveName.text=='Name saved')
composer.recipient:SetText('Alice Sunstrider');assert(not composer.saveName.enabled)
composer.names.scripts.OnClick()
local names=AzerothFieldbookRecipients
assert(names:IsShown() and names.clamped)
eq(names.rows[1].text.text,'Bob Stonewell')
names.rows[1].use.scripts.OnClick()
eq(composer.recipient:GetText(),'Bob Stonewell');assert(not names:IsShown())
assert(not engine:GetOutgoing(),'selecting a name never sends an offer')
composer.send.scripts.OnClick()
local tx=assert(engine:GetOutgoing())
composer.recipient:SetFocus();ChatFrameUtil.InsertLink('Carol Riverwind')
eq(composer.recipient:GetText(),'Bob Stonewell','shift-click cannot change an active transfer')
SetItemRef('player:Carol Riverwind:1:SAY','[Carol]','LeftButton')
eq(composer.recipient:GetText(),'Bob Stonewell','player-link clicks cannot change an active transfer')
composer.recipient:ClearFocus()
assert(composer.lastSent.text:find('Checking compatibility',1,true))
composer.names.scripts.OnClick()
assert(not names.rows[1].use.enabled,'active transfers keep their captured recipient')
names.rows[1].use.scripts.OnClick();eq(composer.recipient:GetText(),'Bob Stonewell')
names.tabs.history.scripts.OnClick()
assert(names.rows[1].text.text:find('Defias Pillager',1,true))
assert(names.rows[1].text.text:find('Checking compatibility',1,true))
engine:Receive('AFBShare','4~R~'..tx.id..'~'..buildVersion,'WHISPER','Bob Stonewell')
engine:Receive('AFBShare','4~A~'..tx.id..'~0','WHISPER','Bob Stonewell')
assert(names.rows[1].text.text:find('Awaiting receipt',1,true))
assert(not names.rows[1].text.text:find('Delivered',1,true))
engine:Receive('AFBShare','4~K~'..tx.id,'WHISPER','Bob Stonewell')
assert(names.rows[1].text.text:find('Delivered',1,true))
assert(composer.lastSent.text:find('Delivered',1,true))
assert(composer.lastSent.text:find('0 knowledge spent',1,true),'discounted cost is retained')
assert(names.rows[1].use.enabled)
names.tabs.recent.scripts.OnClick();eq(names.rows[1].recipient,'Bob Stonewell')
names.tabs.saved.scripts.OnClick();names.rows[1].save.scripts.OnClick()
assert(names.empty:IsShown() and not engine:IsSavedRecipient('Bob Stonewell'))
assert(composer.saveName.enabled)
names.tabs.history.scripts.OnClick()
assert(names.rows[1]:IsShown(),'removing a saved name keeps its history available')
assert(names.rows[1].save.enabled)
names.rows[1].save.scripts.OnClick();assert(engine:IsSavedRecipient('Bob Stonewell'))
assert(not names.rows[1].save.enabled)

-- A received offer can be built with the book closed. All three parchment
-- windows use the same tint, including changes while they remain open.
local value=assert(ns.SharingReport.Capture(journal,42))
value.transaction='1000000-700-1';value.created=now;value.recipient='Alice Sunstrider';value.rumours={}
local payload=assert(ns.SharingReport.Encode(value))
engine:Receive('AFBShare','4~H~'..value.transaction..'~'..buildVersion,'WHISPER','Carol Riverwind')
local count=math.ceil(#payload/180)
for i=1,count do
    engine:Receive('AFBShare','4~O~'..value.transaction..'~'..i..'~'..count..'~'..payload:sub((i-1)*180+1,i*180),
        'WHISPER','Carol Riverwind')
end
local receiver=AzerothFieldbookReceive
assert(receiver:IsShown())
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a)..' ~= '..tostring(b)) end
for _,frame in ipairs({composer,names,receiver}) do
    frame.paper.SetDesaturated=function(self,value) self.desaturated=value end
end
for _,dark in ipairs({false,true}) do
    for _,brightness in ipairs({0.5,1,1.5}) do
        journal:SetDarkMode(dark);journal:SetBackgroundBrightness(brightness);ui:Refresh()
        for _,frame in ipairs({composer,names,receiver}) do
            eq(frame.paper.desaturated,dark)
            near(frame.paper.vertexColor[1],0.504*brightness*(dark and 0.34 or 1))
            near(frame.paper.vertexColor[3],(dark and 0.504 or 0.48888)*brightness*(dark and 0.34 or 1))
        end
    end
end
for i=1,10 do assert(engine:SaveRecipient('Contact '..string.rep('Long ',16)..string.char(64+i))) end
names.tabs.saved.scripts.OnClick()
assert(names.body:GetHeight()>names.area:GetHeight(),'long saved-name lists scroll')
for i,row in ipairs(names.rows) do
    if row:IsShown() then
        assert(row:GetHeight()>=row.text:GetStringHeight()+12,'wrapped names fit their rows')
        if i>1 then
            local previous=names.rows[i-1]
            assert(-row.point[3]>=-previous.point[3]+previous:GetHeight(),'rows never overlap')
        end
    end
end
assert(-names.done.point[3]>=374+names.status:GetStringHeight()+12,'wrapped footer stays above Done')
assert(-names.done.point[3]+names.done:GetHeight()+20<=names:GetHeight())
composer.recipient:SetText('Other Name')
assert(composer.lastSent.text:find('No previous reports',1,true),'history summary follows the typed recipient')
composer:Hide();assert(not names:IsShown(),'the recipient panel follows composer close')
composer.recipient:SetFocus();ChatFrameUtil.InsertLink('Carol Riverwind')
eq(composer.recipient:GetText(),'Other Name','hidden composers ignore chat names')
SetItemRef('player:Carol Riverwind:1:SAY','[Carol]','LeftButton')
eq(composer.recipient:GetText(),'Other Name','hidden composers ignore player-link clicks')
local installedSetItemRef=SetItemRef
ui:Open(42);composer.names.scripts.OnClick()
assert(SetItemRef==installedSetItemRef,'reopening Share does not wrap chat clicks again')
eq(hooks,2,'reopening Share does not install duplicate hooks');assert(nativeCalls>0)
journal:Reset()
assert(not composer:IsShown() and not names:IsShown() and not receiver:IsShown())
''')
print('PASS: recipient reuse, explicit saves/removal, sent outcomes, busy controls and live appearance updates')
