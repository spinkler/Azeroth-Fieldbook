"""Account/character storage, one-time migration and real event routing."""
from pathlib import Path
import sys
from kill_test_harness import new_client

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("ns={}; function eq(a,b,label) assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end")
for name in ['SharingReport.lua', 'BestiaryJournal.lua', 'Tracking.lua', 'Sharing.lua']:
    lua.execute((root / name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
lua.execute(r'''
function character(kills, ability, level, zone)
    local db={version=1,uiScale=0.75,bestiary={creatures={},entries={
        [42]={id=42,name='Test creature',category='Humanoid',confirmed=true,
            kills=kills,levelMin=level,levelMax=level,locations={[zone]=true},
            abilities={[ability]={state='confirmed'}},damage={}}
    }}}
    ns.CreateBestiaryJournal(db,function() end)
    return db
end
function open(db)
    local selected=ns.InitializeTracking(db)
    return ns.CreateBestiaryJournal(db,function() end,selected),selected
end
alice=character(12,'Fireball',9,'Elwynn')
alice.bestiary.entries[42].idNotes={spells={1,2},text='Alice notes'}
alice.bestiary.entries[42].damage[9]={low=5,high=10,reports=1}
alice.bestiary.entries[42].offenses={Fire=true}
alice.bestiary.entries[42].lockedBasic={name='Locked snapshot',category='Humanoid',locations={Elwynn=true},levelMin=9,levelMax=9}
alice.bestiary.entries[42].rumours={{kind='ability',value='Rumour',sender='Carol',dismissed=true,rejected=true}}
alice.bestiary.points.spent=1
alice.bestiary.points.reservations.outgoing=1
alice.bestiary.sharing={sequence=5,receipts={},incoming={},outgoing={id='outgoing',stage='preflight',recipient='Carol'}}
local localAlice=alice.bestiary
local a,account=open(alice)
assert(alice.accountWideTracking and account==AzerothFieldbookAccountDB)
assert(a.entries~=alice.bestiary.entries and a.entries[42]~=alice.bestiary.entries[42],'imports deep-copy character records')
eq(a.entries[42].kills,12);eq(select(2,a:GetTotals()),2)
eq(a:GetSharingStorage().outgoing.id,'outgoing','migrated transfer stays owned by Alice')
eq(a:GetSharingBalance(),0,'old spending and reservation survive migration')
local key=alice.accountTrackingKey
local again=open(alice)
eq(again.entries[42].kills,12,'reload does not import the same kills twice')
eq(select(2,again:GetTotals()),2,'reload does not add historical points twice')
eq(alice.accountTrackingKey,key)

bob=character(13,'Frostbolt',11,'Westfall')
bob.uiScale=1.25
bob.bestiary.entries[42].idNotes={spells={2,3},text='Bob notes'}
bob.bestiary.entries[42].damage[9]={low=7,high=20,reports=1}
bob.bestiary.entries[42].resistances={Frost=true}
bob.bestiary.entries[43]={id=43,name='Other creature',category='Beast',kills=0,abilities={},damage={},locations={}}
-- Ensure the additional entry has genuine credit, as normal observation does.
ns.CreateBestiaryJournal(bob,function() end):Ensure(43)
local b,bobAccount=open(bob)
assert(bobAccount==account and bob.accountTrackingKey~=key)
eq(b.entries[42].kills,25,'different characters contribute their recorded kills')
assert(b.entries[42].abilities.Fireball and b.entries[42].abilities.Frostbolt and b.entries[43])
assert(b.entries[42].offenses.Fire and b.entries[42].resistances.Frost)
assert(b.entries[42].locations.Elwynn and b.entries[42].locations.Westfall)
eq(b.entries[42].levelMin,9);eq(b.entries[42].levelMax,11)
eq(b:GetBasicInfo(42).name,'Locked snapshot','merging retains an existing locked page snapshot')
eq(#b.entries[42].idNotes.spells,3);eq(b.entries[42].idNotes.text,'Alice notes\nBob notes')
eq(#b:DamageNotes(42,9),2);eq(b:DamageNotes(42,9)[1].high,10,'legacy sample is not widened during merge')
eq(b.entries[42].damage[9].low,5);eq(b.entries[42].damage[9].high,20)
assert(b.entries[42].rumours[1].rejected,'rumour rejection history survives')
eq(select(2,b:GetKillReward(42)),'gold')
eq(select(2,b:GetTotals()),7,'historical points combine; the combined gold milestone adds two once')
assert(b:GetSharingStorage().outgoing==nil,'Bob cannot resume Alice transfers')
assert(b:GetSharingStorage()~=a:GetSharingStorage())
eq(a:GetUIScale(),0.75);eq(b:GetUIScale(),1.25,'UI preferences stay per character')
open(bob);a=open(alice)
eq(account.bestiary.entries[42].kills,25);eq(account.bestiary.points.earned,7)
eq(localAlice.entries[42].kills,12,'original character journal remains unchanged')
eq(bob.bestiary.entries[42].kills,13)

-- Reload cancellation only releases the active character's uncommitted offer.
local environment={ready=true,addonVersion='0.9.3',character='Bob',now=function() return 1000 end,blocked=function() return false end}
ns.CreateSharing(b,environment)
eq(select(4,b:GetSharingBalance()),1,'Bob login cannot cancel Alice reservation')
environment.character='Alice';ns.CreateSharing(a,environment)
eq(select(4,a:GetSharingBalance()),0,'Alice reload cancels her uncommitted offer normally')

-- Opt-out is sticky and only takes effect after selecting storage on reload.
a:SetAccountWideTracking(false)
assert(a:IsTrackingChangePending() and a:IsAccountWideTrackingActive())
a:Ensure(99,false,'Account-only observation')
local personal,personalDB=open(alice)
assert(personalDB==alice and not personal:IsAccountWideTrackingActive())
eq(personal.entries[42].kills,12);assert(not personal.entries[99])
personal:Ensure(98,false,'Personal-only observation')
assert(not account.bestiary.entries[98])
personal:SetAccountWideTracking(true)
a=open(alice)
assert(a.entries[99] and not a.entries[98],'switching profiles does not repeatedly import old histories')
eq(a.entries[42].kills,25)

-- Account reset leaves the original personal journal intact and its migration
-- marker survives, so neither known character can resurrect cleared progress.
a:ResetDatabase()
assert(alice.bestiary==localAlice and localAlice.entries[42])
eq(alice.accountTrackingKey,key);assert(alice.accountWideTracking)
open(alice);b=open(bob)
eq(next(account.bestiary.entries),nil);eq(account.bestiary.points.earned,0)
assert(not b:GetSharingStorage().outgoing)
b:SetAccountWideTracking(false)
personal=open(bob);personal:ResetDatabase()
assert(not bob.accountWideTracking,'personal reset keeps the current tracking scope')
eq(next(bob.bestiary.entries),nil);eq(next(account.bestiary.entries),nil)

-- An explicit off choice never imports data until the player enables it.
local carol=character(2,'Arcane Missiles',3,'Dun Morogh');carol.accountWideTracking=false
local c,selected=open(carol);assert(selected==carol and carol.accountTrackingKey==nil)
eq(next(account.bestiary.entries),nil)
c:SetAccountWideTracking(true);c=open(carol)
eq(c.entries[42].kills,2);assert(c.entries[42].abilities['Arcane Missiles'])

-- A failed merge cannot partially add counts or mark the character imported.
local broken=character(3,'Arcane Missiles',4,'Another zone')
local before=account.bestiary
local realCreate=ns.CreateBestiaryJournal
local calls=0
ns.CreateBestiaryJournal=function(...)
    calls=calls+1
    local result=realCreate(...)
    if calls==2 then result.GetKillReward=function() error('simulated interrupted import') end end
    return result
end
assert(not pcall(ns.InitializeTracking,broken))
ns.CreateBestiaryJournal=realCreate
assert(account.bestiary==before and not account.importedCharacters[broken.accountTrackingKey])
eq(account.bestiary.entries[42].kills,2)
open(broken);eq(account.bestiary.entries[42].kills,5,'retry imports only once after failure')

-- Combined account kills can cross the crown tier; award only its new credit.
AzerothFieldbookAccountDB=nil
local crownAlice=character(25,'Fireball',9,'Elwynn')
local crownBob=character(25,'Frostbolt',9,'Elwynn')
open(crownAlice)
local crown=open(crownBob)
eq(crown.entries[42].kills,50);eq(select(2,crown:GetKillReward(42)),'crown')
eq(select(2,crown:GetTotals()),11,'two historical four-point journals plus the new three-point crown')
crown=open(crownBob)
eq(select(2,crown:GetTotals()),11,'account crown is not credited again on reload')
''')
print('PASS: default account tracking, merging, credit, migration replay protection, character preferences, transport ownership, opt-out and scoped resets')

lua = new_client(tracking=True)
lua.execute(r'''
beginKill('account1');finishKill()
beginKill('account2');finishKill()
assert(AzerothFieldbookDB.accountWideTracking==true)
assert(AzerothFieldbookAccountDB.bestiary.entries[42].kills==2)
assert(AzerothFieldbookDB.bestiary.entries[42]==nil,'live observations do not overwrite the character journal')
local account=AzerothFieldbookAccountDB
local alice=AzerothFieldbookDB
AzerothFieldbookDB={version=1}
fire('ADDON_LOADED','AzerothFieldbook')
beginKill('bob');finishKill()
assert(account.bestiary.entries[42].kills==3,'another character records into the shared journal')
AzerothFieldbookDB.accountWideTracking=false
fire('ADDON_LOADED','AzerothFieldbook')
beginKill('personal');finishKill()
assert(AzerothFieldbookDB.bestiary.entries[42].kills==1)
assert(account.bestiary.entries[42].kills==3,'off routes new observations to personal storage')
SlashCmdList.AZEROTHFIELDBOOK('wipe');SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
assert(next(AzerothFieldbookDB.bestiary.entries)==nil and account.bestiary.entries[42].kills==3)
AzerothFieldbookDB=alice;fire('ADDON_LOADED','AzerothFieldbook')
SlashCmdList.AZEROTHFIELDBOOK('wipe');SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
assert(next(account.bestiary.entries)==nil,'slash reset clears the active account journal')
fire('ADDON_LOADED','AzerothFieldbook')
assert(next(account.bestiary.entries)==nil,'reset does not reimport an old character backup')
''')
print('PASS: actual addon event paths use the selected account/character storage across character changes, reloads and slash resets')

toc = (root / 'AzerothFieldbook.toc').read_text()
assert '## SavedVariables: AzerothFieldbookAccountDB' in toc
assert '## SavedVariablesPerCharacter: AzerothFieldbookDB' in toc
assert toc.index('BestiaryJournal.lua') < toc.index('Tracking.lua') < toc.index('AzerothFieldbook.lua')
