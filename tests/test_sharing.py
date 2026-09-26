"""Lua 5.1 report/accounting/protocol tests; simulated clients are not live networking."""
from pathlib import Path
import sys
import re
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().buildVersion = re.search(r"^## Version: (\S+)", (root / "AzerothFieldbook.toc").read_text(encoding="utf-8"), re.MULTILINE).group(1)
lua.execute(r'''
ns={}; secret={}
function issecretvalue(value) return rawequal(value,secret) end
now=1000000
function time() return now end
function InCombatLockdown() return false end
level,zone,npcID,guid,dead=9,'Elwynn',42,'one',false
function UnitName() return 'Defias Pillager' end
function UnitLevel() return level end
function UnitCreatureType() return 'Humanoid' end
function UnitGUID() return guid end
function UnitIsDead() return dead end
function GetRealZoneText() return zone end
function identify() return npcID end
function eq(actual,expected,why) assert(actual==expected,(why or '')..': '..tostring(actual)..' ~= '..tostring(expected)) end
''')
for name in ['SharingReport.lua', 'BestiaryJournal.lua', 'Sharing.lua']:
    lua.execute((root/name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)

lua.execute(r'''
S=ns.SharingReport
function report(id,rumours)
    return {version=1,transaction=id or '1000000-1-1',created=1000000,recipient='Bob Stonewell',creatureID=42,
        name='Defias Pillager',category='Humanoid',levelMin=9,levelMax=11,locations={'Elwynn'},rumours=rumours or {}}
end
fire={kind='ability',value='Fireball',spellID=133}
flee={kind='behaviour',value='Flees at low health'}
melee={kind='behaviour',value='Melee'}
eq(S.Cost({}),1); eq(S.Cost({fire}),2); eq(S.Cost({fire,flee}),3); eq(S.Cost({fire,flee,melee}),4)
assert(not S.Cost({[1]=fire,[3]=melee}) and not S.Cost({extra=fire}))
assert(not S.Validate(report(nil,{fire,flee,fire})))
local encoded=assert(S.Encode(report(nil,{fire,flee})))
local decoded=assert(S.Decode(encoded))
eq(decoded.rumours[1].spellID,133); eq(decoded.creatureID,42)
assert(not S.Decode(encoded..'1:x'))
assert(not S.Decode(string.rep('x',2049)))
assert(not S.Decode('10000:x'))
assert(not S.Decode(secret))
for _,mutation in ipairs({function(r) r.version=2 end,function(r) r.creatureID=0 end,
    function(r) r.creatureID='42' end,function(r) r.levelMin=12 end,function(r) r.levelMax=999 end,
    function(r) r.name='|Hspell:1|hFoo' end,function(r) r.category='A\nB' end,
    function(r) r.locations[9]='Too many' end,function(r) r.locations.extra='bad' end,
    function(r) r.kills=100 end,function(r) r.points=999 end,function(r) r.author='Forged Name' end,
    function(r) r.rumours={{kind='note',value='Private note'}} end,
    function(r) r.rumours={{kind='ability',value='Fireball; also heals'}} end,
    function(r) r.rumours={{kind='immunity',value='Made up'}} end,
    function(r) r.rumours={{kind='ability',value='Fireball',confirmed=true}} end,
    function(r) r.rumours={fire,fire} end,function(r) r.version=secret end,
    function(r) r.name=secret end,function(r) r.rumours=secret end,function(r) r.levelMin=secret end,
    function(r) r.rumours={{kind='ability',value='Fireball',spellID=secret}} end}) do
    local r=report(); mutation(r); assert(not S.Encode(r),'invalid report accepted')
end
-- Construct a three-rumour wire payload without the sender-side validator.
local base=assert(S.Encode(report()))
local function field(s) s=tostring(s); return #s..':'..s end
local crafted=base:sub(1,-4)..field(3)
for _,c in ipairs({fire,flee,melee}) do crafted=crafted..field(c.kind)..field(c.value)..field(c.spellID or 0) end
eq(#assert(S.Decode(crafted)).rumours,3,'receiver accepts more than two distinct rumours')
assert(not S.Decode(base:sub(1,-4)..field(999999999999)),'impossible counts fail without unbounded allocation')
many={}
for i=1,32 do many[i]={kind='ability',value='Spell '..i..string.rep('x',25)} end
eq(S.Cost(many),33);eq(#assert(S.Decode(assert(S.Encode(report(nil,many))))).rumours,32)
oversized={}
for i=1,32 do oversized[i]={kind='ability',value='Spell '..i..string.rep('x',85)} end
local tooLarge,tooLargeError=S.Encode(report(nil,oversized))
assert(not tooLarge and tooLargeError:find('too large',1,true),'payload size safeguard remains')
eq(S.Character('Alice'),'Alice')
eq(S.Character('  Alice   Sunstrider  '),'Alice Sunstrider')
eq(S.Character("Élan O'Connor-Smith"),"Élan O'Connor-Smith")
assert(S.SameCharacter('Alice Sunstrider','alice sunstrider'))
assert(not S.SameCharacter('Alice Sunstrider','Alice Riverwind'),'surnames identify distinct senders')
for _,name in ipairs({'Alice|r','Alice\nSunstrider','Alice\tSunstrider','Alice123','   ','-Alice','Alice-','Alice / Bob',string.rep('A',101),secret}) do
    assert(not S.Character(name),'unsafe character name accepted')
end
eq(decoded.recipient,'Bob Stonewell','full recipient name survives wire encoding')

local legacyDB={bestiary={entries={[42]={id=42,name='Defias Pillager',category='Humanoid',levelMin=9,levelMax=11,
    locations={Elwynn=true},abilities={},kills=25}},creatures={}}}
local legacy=ns.CreateBestiaryJournal(legacyDB,identify)
eq(legacy:GetSharingBalance(),5,'legacy entry + endpoint + gold')
assert(legacy:ReserveShare('migration',2))
assert(not legacy:ReserveShare('overlap',4))
assert(legacy:CommitShare('migration')); assert(not legacy:CommitShare('migration'))
local reload=ns.CreateBestiaryJournal(legacyDB,identify)
eq(reload:GetSharingBalance(),3,'migration does not repeat or erase spending')
reload:DeleteEntry(42); eq(reload:GetSharingBalance(),3,'delete keeps credit and spending')
assert(reload:ImportReport(report(), 'Alice Sunstrider',now))
eq(reload:GetSharingBalance(),3,'reimport no points')
reload:Observe('target'); eq(reload:GetSharingBalance(),3,'already credited level no points')
level=10; reload:Observe('target'); eq(reload:GetSharingBalance(),3,'new intermediate level is recorded without a reward')
reload:DeleteEntry(42); reload:Observe('target'); eq(reload:GetSharingBalance(),3,'rediscover same milestones no points')

local importedDB={}
local j=ns.CreateBestiaryJournal(importedDB,identify)
assert(j:ImportReport(report(nil,{fire,flee}),'Alice Sunstrider',now))
eq(j:GetSharingBalance(),0); eq(select(2,j:GetTotals()),0)
assert(not importedDB.bestiary.points.credits[42],'import does not create personal credit flags')
local entry=j.entries[42]
assert(not entry.name and not entry.levelMin and not next(entry.locations),'basic sources stay separate')
assert(not entry.personalEncountered and not entry.confirmed and entry.kills==0)
assert(not next(entry.abilities) and not next(entry.offenses) and not next(entry.behaviours))
eq(#j:ConfirmedNames(42),0,'rumours not in tooltips')
local view=j:GetBasicInfo(42)
eq(view.name,'Defias Pillager'); eq(view.levelMin,9); assert(view.locations.Elwynn)
eq(#j:List('Humanoid','pillager',false),1,'shared entries are browsable')
j:SetEntryConfirmed(42,true)
local more=report('1000000-9-1'); more.levelMax=50; more.locations={'Westfall'}
assert(j:ImportReport(more,'Carol Riverwind',now))
eq(j:GetBasicInfo(42).levelMax,11,'locked imported-only page cannot silently change')
assert(not j:GetBasicInfo(42).locations.Westfall)
j:SetEntryConfirmed(42,false); eq(j:GetBasicInfo(42).levelMax,50,'unlock makes separately stored basics available')
assert(j:ImportReport(report('1000000-2-1',{fire,flee}),'Alice Sunstrider',now))
eq(#j:GetRumours(42),2,'same-source identical rumours dedup')
assert(j:ImportReport(report('1000000-3-1',{fire}),'Carol Riverwind',now))
eq(#j:GetRumours(42),3,'different sources keep attribution')
assert(j:DismissRumour(42,j:GetRumours(42)[1])); eq(#j:GetRumours(42),2)
assert(j:ImportReport(report('1000000-4-1',{fire}),'Alice Sunstrider',now))
eq(#j:GetRumours(42),3,'a new report can repeat a rejected claim for review')
assert(j:GetRumours(42)[1].previouslyRejected,'repeated claim remembers rejection')
local zero=j:GetSharingBalance()
level=9; j:Observe('target'); eq(j:GetSharingBalance(),zero+1,'first genuine discovery is still earned')
level=11; j:Observe('target'); eq(j:GetSharingBalance(),zero+1,'personally observing a shared level awards no knowledge')
zone='Westfall'; j:Observe('target'); eq(j:GetSharingBalance(),zero+2,'new real location')
local r=report('1000000-5-1'); r.locations={'Westfall','Duskwood'}
assert(j:ImportReport(r,'Alice Sunstrider',now)); eq(j:GetSharingBalance(),zero+2)
zone='Duskwood'; j:Observe('target'); eq(j:GetSharingBalance(),zero+3,'imported location still earns real credit')
j:DeleteEntry(42); j:ImportReport(r,'Alice Sunstrider',now); j:Observe('target')
eq(j:GetSharingBalance(),zero+3,'delete/reimport/rediscover cannot mint points')
local oldGUID,oldExists,oldControlled,oldTap,oldTime=UnitGUID,UnitExists,UnitPlayerControlled,UnitIsTapDenied,GetTime
UnitGUID=function(unit) if unit=='player' then return 'Player-1-1' elseif unit=='target' then return guid end end
UnitExists=function() return true end
UnitPlayerControlled=function() return false end
UnitIsTapDenied=function() return false end
GetTime=function() return now end
local function creditedDeath(suffix)
    guid='Creature-0-1-2-3-42-'..suffix
    dead=false; j:Observe('target')
    j:RecordPartyKill('Player-1-1',guid)
    dead=true; j:RecordUnitDeath(guid)
end
creditedDeath('death1'); eq(j:GetSharingBalance(),zero+3)
j=ns.CreateBestiaryJournal(importedDB,identify); assert(not j:RecordKill('target'),'same death survives reload')
creditedDeath('death2'); eq(j:GetSharingBalance(),zero+3)
for i=3,24 do creditedDeath('death'..i) end
eq(j:GetSharingBalance(),zero+4,'silver remains the only kill reward until 25')
creditedDeath('death25'); eq(j:GetSharingBalance(),zero+6)
j:DeleteEntry(42); j:Observe('target')
for i=1,25 do creditedDeath('repeated'..i) end
eq(j:GetSharingBalance(),zero+6,'already credited kill stars cannot pay twice')
dead=false
UnitGUID,UnitExists,UnitPlayerControlled,UnitIsTapDenied,GetTime=oldGUID,oldExists,oldControlled,oldTap,oldTime

local localDB={}; local localJ=ns.CreateBestiaryJournal(localDB,identify)
zone='Local zone'; level=9; localJ:Observe('target')
localJ.entries[42].name='Local name'
localJ:AddManual(42,'Manual spell','Long private note with many claims',nil,{Fear=true,Stun=true})
localJ:SetResistance(42,'Fire',true); localJ:SetImmunity(42,'Frost',true); localJ:SetBehaviour(42,'Patrols',true)
localJ:SetCreatureNotes(42,'Private notes'); localJ:AddNoteSpell(42,'123')
localJ:Offer(42,'Pending spell'); localJ:Offer(42,'Rejected spell'); localJ:SetAbility(42,'Rejected spell','rejected')
local choices=S.Candidates(localJ.entries[42]); eq(#choices,5,'individual manual/pending ability and traits only')
for _,c in ipairs(choices) do assert(not c.note and not c.effects and not c.confirmed) end
localJ:SetEntryConfirmed(42,true)
local before=localJ:GetSharingBalance(); local revision=localJ.revision
local incoming=report(nil,{fire,flee}); incoming.name='Conflicting name'; incoming.levelMax=90
local p=assert(localJ:PreviewReport(incoming,'Alice Sunstrider')); assert(p.locked and p.conflict and p.newInformation)
assert(localJ:ImportReport(incoming,'Alice Sunstrider',now))
eq(localJ.entries[42].name,'Local name'); eq(localJ:GetBasicInfo(42).levelMax,9,'locked metadata frozen')
assert(localJ.entries[42].confirmed and localJ.entries[42].resistances.Fire)
assert(not localJ.entries[42].behaviours['Flees at low health'] and not localJ.entries[42].abilities.Fireball)
eq(localJ:GetIDNotes(42).text,'Private notes'); eq(localJ:GetSharingBalance(),before)
assert(not localJ:PreviewReport(incoming,'Alice Sunstrider').newInformation,'already stored conflicting report adds no new information')
local captured=S.Capture(localJ,42); captured.transaction='1000000-10-1'; captured.created=now; captured.recipient='Bob Stonewell'
local outbound=assert(S.Decode(assert(S.Encode(captured))))
assert(not outbound.kills and not outbound.confirmed and not outbound.abilities and not outbound.idNotes)
localJ.entries[42].id=99; assert(not localJ:ImportReport(incoming,'Alice Sunstrider',now),'ID mismatch rejected atomically')
localJ.entries[42].id=42
local bad=report(); bad.rumours={fire,flee,fire}; revision=localJ.revision
assert(not localJ:ImportReport(bad,'Alice Sunstrider',now)); eq(localJ.revision,revision)
localJ:Reset(); eq(localJ:GetSharingBalance(),0); assert(not next(localJ.entries))
''')
print('PASS: sharing schema, per-rumour pricing, larger reports, atomic records, migration, independent credit, locks, attribution and storage separation')

lua.execute(r'''
wire,clients,delivered={}, {}, {}
drop=nil
function endpoint(name,db)
    local e={name=name,db=db or {},blocked=false}
    e.j=ns.CreateBestiaryJournal(e.db,identify)
    e.env={ready=true,addonVersion=buildVersion,character=name,now=function() return now end,
        blocked=function() return e.blocked end,nonce=function() return 12345 end,
        send=function(prefix,message,channel,target)
            if e.failure then return false,e.failure end
            wire[#wire+1]={from=name,to=target,prefix=prefix,text=message,channel=channel}
            return true
        end}
    e.engine=ns.CreateSharing(e.j,e.env)
    clients[name]=e
    return e
end
function pump(seconds)
    for _=1,seconds do
        now=now+1
        for _,e in pairs(clients) do e.engine:Tick() end
        local messages=wire; wire={}
        for _,m in ipairs(messages) do
            delivered[#delivered+1]=m
            local target=clients[m.to]
            if target and not (drop and drop(m)) then target.engine:Receive(m.prefix,m.text,m.channel,m.from) end
        end
    end
end
function setup()
    now=1000000; clients={};wire={};delivered={};drop=nil
    a=endpoint('Alice Sunstrider'); b=endpoint('Bob Stonewell')
    local e=a.j:Ensure(42,false,'Defias Pillager'); e.category='Humanoid'; e.levelMin=9; e.levelMax=11; e.locations.Elwynn=true
    for i=1,9 do a.j:Ensure(100+i,false,'Funding creature') end
    capture=assert(S.Capture(a.j,42))
end
function start(claims)
    local tx=assert(a.engine:Start(capture,'Bob Stonewell',claims or {}))
    pump(20)
    return tx,assert(b.engine:GetIncoming()[1],'no incoming preview')
end
do
    setup()
    for _,name in ipairs({'Alice Sunstrider','alice sunstrider','  ALICE   SUNSTRIDER  '}) do
        local sequence=a.j:GetSharingStorage().sequence
        local tx,err=a.engine:Start(capture,name,{fire})
        assert(not tx and err=='You cannot send an offer to yourself.')
        assert(not a.engine:GetOutgoing(),'self-offers never create a transaction')
        eq(a.j:GetSharingStorage().sequence,sequence)
        eq(a.j:GetSharingBalance(),10); eq(select(3,a.j:GetSharingBalance()),0)
        eq(select(4,a.j:GetSharingBalance()),0,'self-offers never reserve points')
    end
    pump(5); eq(#delivered,0,'self-offers never send packets')
    eq(a.engine:ValidateRecipient('Alice Riverwind'),'Alice Riverwind','a different surname is a different character')
end
-- Reproduce the live Goldtooth report with a surname and three behaviour rumours.
do
    setup(); clients['Bob Stonewell']=nil; b=endpoint('Erna Lionguard')
    local gold={version=1,creatureID=327,name='Goldtooth',category='Humanoid',levelMin=8,levelMax=8,
        locations={'Elwynn Forest'},rumours={}}
    local traits={flee,{kind='behaviour',value='Hostile'},melee}
    local tx=assert(a.engine:Start(gold,'Erna Lionguard',traits));pump(20)
    local item=assert(b.engine:GetIncoming()[1],'Goldtooth reaches the preview before acceptance')
    eq(item.report.name,'Goldtooth');eq(#item.report.rumours,3);eq(select(3,a.j:GetSharingBalance()),0)
    assert(b.engine:Accept(item));pump(12);eq(tx.stage,'complete')
    eq(select(3,a.j:GetSharingBalance()),4);eq(#b.j:GetRumours(327),3)
end
-- Every pre-preview rejection reports a specific cause and releases the reservation.
do
    for _,case in ipairs({
        {'blocked',function() b.j:SetBlockIncomingOffers(true) end},
        {'busy',function()
            for i=1,3 do b.j:GetSharingStorage().incoming['held'..i]={id='1-1-'..i,sender='Other',state='receiving',expires=now+180} end
        end},
        {'recipient',function() b.env.character='Bob' end},
        {'future',function() b.env.now=function() return now-600 end end},
        {'expired',function() b.env.now=function() return now+86401 end end},
        {'malformed',function(tx) tx.payload='1:9'..tx.payload:sub(4) end},
        {'transaction',function(tx)
            local value=assert(S.Decode(tx.payload));value.transaction='1-1-1';tx.payload=assert(S.Encode(value))
        end},
        {'identity',function() b.j:Ensure(42,true,'Defias Pillager').id=43 end},
    }) do
        setup(); local tx=assert(a.engine:Start(capture,'Bob Stonewell',{}));case[2](tx);pump(20)
        eq(tx.stage,'declined',case[1]);eq(select(3,a.j:GetSharingBalance()),0)
        eq(select(4,a.j:GetSharingBalance()),0);eq(a.j:GetSharingBalance(),10)
        local events=b.j:GetEventLog().entries
        eq(events[#events].details.reason,case[1],'recipient event log identifies rejection')
        assert(tx.message:find('No knowledge spent.',1,true))
        assert(not tx.message:find('Offer declined, invalid, or receiver busy',1,true))
        eq(#b.engine:GetIncoming(),0)
    end
    setup();local tx,item=start();assert(b.engine:Decline(item));pump(5)
    assert(tx.message:find('The recipient declined the offer.',1,true))
    setup();tx=assert(a.engine:Start(capture,'Bob Stonewell',{}))
    a.engine:Receive('AFBShare','4~D~'..tx.id..'~untrusted error text','WHISPER','Bob Stonewell')
    eq(tx.stage,'preflight','unknown reason codes cannot change the transaction')
    a.engine:Receive('AFBShare','4~D~'..tx.id,'WHISPER','Bob Stonewell')
    eq(tx.stage,'declined','legacy empty declines remain supported')
end
-- Incoming blocking is a per-character preference, separate from transport
-- restrictions. It must never turn a free decline into spent points.
do
    setup()
    assert(not b.j:GetBlockIncomingOffers(),'incoming offers allowed by default')
    b.j:SetBlockIncomingOffers(true)
    assert(ns.CreateBestiaryJournal(b.db,identify):GetBlockIncomingOffers(),'setting survives reload')
    assert(not a.j:GetBlockIncomingOffers(),'other characters are unaffected')
    local tx=assert(a.engine:Start(capture,'Bob Stonewell',{}))
    pump(20)
    eq(tx.stage,'declined'); eq(a.j:GetSharingBalance(),10)
    eq(select(3,a.j:GetSharingBalance()),0); eq(select(4,a.j:GetSharingBalance()),0)
    assert(not next(b.j:GetSharingStorage().incoming) and not b.j.entries[42])
    b.j:SetBlockIncomingOffers(false)
    local resumed,item=start()
    assert(b.engine:Accept(item)); pump(12); eq(resumed.stage,'complete')

    setup()
    local pending,item=start({fire})
    b.j:SetBlockIncomingOffers(true)
    eq(#b.engine:GetIncoming(),0); assert(not b.engine:Accept(item),'stale preview cannot accept')
    pump(10); eq(pending.stage,'declined'); eq(a.j:GetSharingBalance(),10)
    assert(not b.j.entries[42])

    setup()
    local partial=assert(a.engine:Start(capture,'Bob Stonewell',{fire,flee}))
    pump(2) -- Hello/ready exchanged, report chunks have not arrived yet.
    assert(next(b.j:GetSharingStorage().incoming))
    b.j:SetBlockIncomingOffers(true); pump(20)
    eq(partial.stage,'declined'); eq(a.j:GetSharingBalance(),10)
    assert(not next(b.j:GetSharingStorage().incoming) and not b.j.entries[42])

    setup()
    a.j:SetBlockIncomingOffers(true) -- Outbound sharing must still work.
    local accepted,item=start({fire})
    assert(b.engine:Accept(item))
    b.j:SetBlockIncomingOffers(true); pump(12)
    eq(accepted.stage,'complete'); eq(select(3,a.j:GetSharingBalance()),2)
    assert(b.j.entries[42])
    b.j:ResetDatabase(); assert(not b.j:GetBlockIncomingOffers(),'full reset restores default off')

    for _,packet in ipairs({'~C~','~K~'}) do
        setup()
        local paid,item=start()
        drop=function(message) return message.text:find(packet,1,true) end
        assert(b.engine:Accept(item)); b.j:SetBlockIncomingOffers(true); pump(75)
        eq(paid.stage,'unknown')
        b=endpoint('Bob Stonewell',b.db); drop=nil
        assert(b.j:GetBlockIncomingOffers(),'reload keeps incoming blocking enabled')
        assert(a.engine:Retry()); pump(15)
        eq(paid.stage,'complete'); eq(select(3,a.j:GetSharingBalance()),1)
        eq(#b.j.entries[42].sharedReports,1,'accepted deliveries and receipts reconcile once while blocked')
    end
end
setup()
local tx,item=start()
eq(a.j:GetSharingBalance(),9); eq(select(3,a.j:GetSharingBalance()),0,'offer only reserves')
eq(b.j:GetSharingBalance(),0); assert(not b.j.entries[42],'preview does not import')
assert(not a.engine:Start(capture,'Bob Stonewell',{}),'double click does not create second transfer')
assert(b.engine:Accept(item)); pump(12)
eq(tx.stage,'complete'); eq(a.j:GetSharingBalance(),9); eq(select(3,a.j:GetSharingBalance()),1)
assert(b.j.entries[42]); eq(b.j:GetSharingBalance(),0); eq(#b.j.entries[42].sharedReports,1)
local id=tx.id
b.engine:Receive('AFBShare','4~C~'..id,'WHISPER','Alice Sunstrider'); pump(5)
eq(#b.j.entries[42].sharedReports,1,'duplicate commit no duplicate import')
a.engine:Receive('AFBShare','4~A~'..id..'~1','WHISPER','Bob Stonewell'); eq(select(3,a.j:GetSharingBalance()),1)

setup(); tx,item=start({fire,flee}); assert(b.engine:Accept(item)); pump(12)
eq(a.j:GetSharingBalance(),7); eq(select(3,a.j:GetSharingBalance()),3); eq(#b.j:GetRumours(42),2)
eq(b.j:GetRumours(42)[1].sender,'Alice Sunstrider'); eq(b.j:GetRumours(42)[1].source,'WHISPER')
local second=assert(a.engine:Start(capture,'Bob Stonewell',{fire,flee})); pump(20)
item=assert(b.engine:GetIncoming()[1]); assert(b.engine:Accept(item)); pump(12)
eq(#b.j:GetRumours(42),2,'fresh same-source report dedups rumours'); eq(a.j:GetSharingBalance(),5)
eq(second.cost,2,'known basics are free; selected rumours retain their price')

local function knownBasics()
    local entry=b.j:Ensure(42,true,capture.name)
    entry.category=capture.category;entry.levelMin=capture.levelMin;entry.levelMax=capture.levelMax
    entry.locations={}
    for _,location in ipairs(capture.locations) do entry.locations[location]=true end
    return entry
end
do
    setup();knownBasics()
    local notices={}
    a.engine:SetCostAdjustedCallback(function(report) notices[#notices+1]=report.cost end)
    local tx,item=start({fire,flee})
    eq(tx.cost,3);eq(select(4,a.j:GetSharingBalance()),3,'maximum cost stays reserved until acceptance')
    assert(b.engine:Accept(item));eq(item.basicCost,0);eq(select(3,a.j:GetSharingBalance()),0)
    pump(12)
    eq(tx.stage,'complete');eq(tx.cost,2);eq(tx.basicCost,0);assert(tx.basicInfoWaived)
    eq(a.j:GetSharingBalance(),8);eq(select(3,a.j:GetSharingBalance()),2);eq(select(4,a.j:GetSharingBalance()),0)
    eq(#b.j:GetRumours(42),2,'new rumours import when basics match');eq(#notices,1);eq(notices[1],2)
    a.engine:Receive('AFBShare','4~A~'..tx.id..'~0','WHISPER','Bob Stonewell')
    pump(5);eq(select(3,a.j:GetSharingBalance()),2);eq(#notices,1,'duplicates cannot apply or announce a second waiver')

    setup();knownBasics();tx,item=start();assert(b.engine:Accept(item));pump(12)
    eq(tx.stage,'complete');eq(tx.cost,0);eq(a.j:GetSharingBalance(),10)
    eq(select(3,a.j:GetSharingBalance()),0,'a known basics-only report has no charge')
    eq(#b.j.entries[42].sharedReports,1,'free matching basics may still record attribution')

    -- Existing broader observations also mean the report adds no new basics.
    setup();local entry=knownBasics();entry.levelMin=1;entry.levelMax=60;entry.locations.Westfall=true
    tx,item=start({fire});assert(b.engine:Accept(item));pump(12);eq(tx.cost,1)
    setup();knownBasics();b.j:SetEntryConfirmed(42,true)
    tx,item=start({fire});assert(b.engine:Accept(item));pump(12);eq(tx.cost,1)

    -- Any genuinely new/conflicting basic field retains its normal one-point cost.
    for _,change in ipairs({
        function(entry) entry.name='Other name' end,
        function(entry) entry.category='Beast' end,
        function(entry) entry.levelMin=capture.levelMin+1 end,
        function(entry) entry.levelMax=capture.levelMax-1 end,
        function(entry) entry.locations={} end,
    }) do
        setup();change(knownBasics());tx,item=start({fire});assert(b.engine:Accept(item));pump(12)
        eq(tx.cost,2);assert(not tx.basicInfoWaived)
    end

    -- Recheck at acceptance, after any observations or edits since preview.
    setup();tx,item=start({fire});knownBasics();assert(b.engine:Accept(item));pump(12);eq(tx.cost,1)
    setup();knownBasics();tx,item=start({fire});b.j.entries[42].locations={}
    assert(b.engine:Accept(item));pump(12);eq(tx.cost,2)

    -- Both missing import and missing receipt reconcile at the original price.
    for _,packet in ipairs({'~C~','~K~'}) do
        setup();knownBasics();tx,item=start({fire,flee})
        drop=function(message) return message.text:find(packet,1,true) end
        assert(b.engine:Accept(item));pump(75);eq(tx.stage,'unknown');eq(tx.cost,2)
        a=endpoint('Alice Sunstrider',a.db);b=endpoint('Bob Stonewell',b.db);drop=nil
        local repeatNotices=0;a.engine:SetCostAdjustedCallback(function() repeatNotices=repeatNotices+1 end)
        tx=a.engine:GetOutgoing();assert(tx.basicInfoWaived);assert(a.engine:Retry());pump(15)
        eq(tx.stage,'complete');eq(select(3,a.j:GetSharingBalance()),2);eq(#b.j:GetRumours(42),2)
        eq(repeatNotices,0,'reload/retry preserves the settled price without another adjustment notice')
    end
    setup();knownBasics();tx,item=start()
    drop=function(message) return message.text:find('~K~',1,true) end
    assert(b.engine:Accept(item));pump(75);eq(tx.stage,'unknown');eq(tx.cost,0)
    a=endpoint('Alice Sunstrider',a.db);b=endpoint('Bob Stonewell',b.db);drop=nil
    tx=a.engine:GetOutgoing();assert(a.engine:Retry());pump(15)
    eq(tx.stage,'complete');eq(select(3,a.j:GetSharingBalance()),0,'zero-cost commits also reconcile without charging')

    -- Missing/invalid pricing or a forged recipient cannot consume a reservation.
    setup();tx,item=start({fire})
    for _,quote in ipairs({'','2','-1','00','0.5','0~junk'}) do
        a.engine:Receive('AFBShare','4~A~'..tx.id..'~'..quote,'WHISPER','Bob Stonewell')
        eq(tx.stage,'offering');eq(select(3,a.j:GetSharingBalance()),0)
    end
    a.engine:Receive('AFBShare','4~A~'..tx.id..'~0','WHISPER','Mallory Falsewind')
    a.engine:Receive('AFBShare','3~A~'..tx.id..'~0','WHISPER','Bob Stonewell')
    eq(tx.stage,'offering');eq(select(4,a.j:GetSharingBalance()),2)
end

setup(); tx,item=start({fire,flee,melee})
eq(select(4,a.j:GetSharingBalance()),4,'one base point plus three rumours reserved')
assert(b.engine:Accept(item));pump(12)
eq(tx.stage,'complete');eq(#b.j:GetRumours(42),3);eq(a.j:GetSharingBalance(),6);eq(b.j:GetSharingBalance(),0)
setup();tx,item=start({fire,flee,melee});b.engine:Decline(item);pump(5)
eq(a.j:GetSharingBalance(),10);eq(select(3,a.j:GetSharingBalance()),0,'decline releases the full larger reservation')
setup();tx,item=start({fire,flee,melee});assert(a.engine:Cancel());pump(5)
eq(a.j:GetSharingBalance(),10);eq(select(4,a.j:GetSharingBalance()),0)
setup();assert(not a.engine:Start(capture,'Bob Stonewell',many),'larger selection cannot exceed funds')
eq(a.j:GetSharingBalance(),10);eq(select(4,a.j:GetSharingBalance()),0)
assert(not a.engine:Start(capture,'Bob Stonewell',oversized),'oversized report rejected before reservation')
eq(select(4,a.j:GetSharingBalance()),0)
for i=201,230 do a.j:Ensure(i,false,'Funding creature') end
tx,item=start(many);eq(#item.report.rumours,32);eq(tx.cost,33)
assert(b.engine:Accept(item));pump(12)
eq(tx.stage,'complete');eq(#b.j:GetRumours(42),32);eq(a.j:GetSharingBalance(),7);eq(select(3,a.j:GetSharingBalance()),33)
eq(b.j:GetSharingBalance(),0,'receiving a larger report is still free')

setup(); tx,item=start({fire}); b.engine:Decline(item); pump(5)
eq(tx.stage,'declined'); eq(a.j:GetSharingBalance(),10); assert(not b.j.entries[42])
setup(); tx,item=start({fire,flee}); assert(a.engine:Cancel()); pump(5)
eq(tx.stage,'cancelled'); eq(a.j:GetSharingBalance(),10); eq(#b.engine:GetIncoming(),0)
setup(); a.j:Reset(); assert(not a.engine:Start(capture,'Bob Stonewell',{})); eq(a.j:GetSharingBalance(),0)
setup(); clients['Bob Stonewell']=nil; tx=assert(a.engine:Start(capture,'Bob Stonewell',{}))
eq(a.engine:GetPreflightSecondsRemaining(),20)
pump(19);eq(tx.stage,'preflight');eq(a.engine:GetPreflightSecondsRemaining(),1)
pump(1);eq(tx.stage,'failed');eq(a.j:GetSharingBalance(),10)
eq(select(3,a.j:GetSharingBalance()),0);eq(select(4,a.j:GetSharingBalance()),0)
assert(not a.engine:HasActiveOutgoing() and a.engine:GetPreflightSecondsRemaining()==nil)
assert(tx.message:find('No response from Bob Stonewell after 20 seconds.',1,true))
assert(tx.message:find('may be missing or disabled',1,true) and tx.message:find('No knowledge spent.',1,true))
assert(a.engine:Start(capture,'Bob Stonewell',{}),'a timed-out check allows a new attempt')

-- Lagged replies inside the deadline still proceed to normal consent/import.
setup();drop=function(m) return m.text:find('~R~',1,true) end
tx=assert(a.engine:Start(capture,'Bob Stonewell',{}));pump(19)
a.engine:Receive('AFBShare','4~R~'..tx.id..'~'..buildVersion,'WHISPER','Bob Stonewell')
eq(tx.stage,'offering');assert(a.engine:GetPreflightSecondsRemaining()==nil)
pump(10);assert(b.engine:Accept(assert(b.engine:GetIncoming()[1])));pump(10)
eq(tx.stage,'complete')

-- A late reply cannot race the periodic timer or revive its expired reservation.
setup();tx=assert(a.engine:Start(capture,'Bob Stonewell',{}));now=now+20
a.engine:Receive('AFBShare','4~R~'..tx.id..'~'..buildVersion,'WHISPER','Bob Stonewell')
eq(tx.stage,'failed');eq(a.j:GetSharingBalance(),10)
a.engine:Receive('AFBShare','4~A~'..tx.id,'WHISPER','Bob Stonewell')
pump(5);eq(tx.stage,'failed');eq(#delivered,0,'expired queued packets are purged')

-- Entering combat/restrictions after Send must not suspend the timeout.
setup();tx=assert(a.engine:Start(capture,'Bob Stonewell',{}));a.blocked=true;pump(20)
eq(tx.stage,'failed');eq(a.j:GetSharingBalance(),10)
a.blocked=false;pump(5);eq(#delivered,0)
setup(); tx=assert(a.engine:Start(capture,'Bob Stonewell',{}))
a.engine:Receive('AFBShare','1~I~'..tx.id,'WHISPER','Bob Stonewell')
eq(tx.stage,'failed'); eq(a.j:GetSharingBalance(),10)
assert(tx.message:find('compatible addon version',1,true),'old pricing build is explicitly incompatible')
setup();b.engine:Receive('AFBShare','1~H~1000000-77-1','WHISPER','Alice Sunstrider');pump(1)
eq(delivered[1].text,'1~I~1000000-77-1','old sender receives a readable incompatibility reply')
eq(#b.engine:GetIncoming(),0)
for _,peerVersion in ipairs({'0.9.0','9.9.9'}) do
    setup();b.env.addonVersion=peerVersion
    tx=assert(a.engine:Start(capture,'Bob Stonewell',{fire,flee,melee}));pump(8)
    eq(tx.stage,'failed');eq(a.j:GetSharingBalance(),10);eq(select(3,a.j:GetSharingBalance()),0)
    assert(tx.message:find(buildVersion,1,true) and tx.message:find(peerVersion,1,true),'mismatch identifies both addon versions')
    eq(#b.engine:GetIncoming(),0);assert(not b.j.entries[42])
    for _,packet in ipairs(delivered) do assert(not packet.text:find('~O~',1,true),'mismatch prevents sending the report payload') end
end
setup();tx,item=start({fire});b.env.addonVersion='0.9.0'
assert(not b.engine:Accept(item),'acceptance rechecks compatibility after a version change')
eq(select(3,a.j:GetSharingBalance()),0);assert(not b.j.entries[42])
setup();tx,item=start({fire});assert(b.engine:Accept(item));b.env.addonVersion='0.9.0'
b.engine:Receive('AFBShare','4~C~'..tx.id,'WHISPER','Alice Sunstrider')
assert(not b.j.entries[42],'an older consent cannot import into a mismatched build')
setup();tx=assert(a.engine:Start(capture,'Bob Stonewell',{}))
a.engine:Receive('AFBShare','4~R~'..tx.id..'~9.9.9','WHISPER','Mallory Falsewind')
eq(tx.stage,'preflight','version replies must come from the expected character')
a.engine:Receive('AFBShare','4~R~'..tx.id..'~9.9.9','WHISPER','Bob Stonewell')
eq(tx.stage,'failed');eq(a.j:GetSharingBalance(),10)
for _,peerVersion in ipairs({'','nonsense',string.rep('9',33)}) do
    setup();tx=assert(a.engine:Start(capture,'Bob Stonewell',{}))
    a.engine:Receive('AFBShare','4~R~'..tx.id..'~'..peerVersion,'WHISPER','Bob Stonewell')
    eq(tx.stage,'failed');eq(a.j:GetSharingBalance(),10,'missing or malformed version cannot consume points')
    setup();b.engine:Receive('AFBShare','4~H~1000000-77-1~'..peerVersion,'WHISPER','Alice Sunstrider')
    assert(not next(b.j:GetSharingStorage().incoming),'invalid version cannot stage a report')
end
setup();a.env.addonVersion=nil
assert(not a.engine:Available() and not a.engine:Start(capture,'Bob Stonewell',{}));eq(a.j:GetSharingBalance(),10)
setup(); a.blocked=true; assert(not a.engine:Start(capture,'Bob Stonewell',{})); a.blocked=false
a.failure='recipient offline'; tx=assert(a.engine:Start(capture,'Bob Stonewell',{})); pump(2)
eq(tx.stage,'failed'); eq(a.j:GetSharingBalance(),10)
setup(); a.failure='throttle'; tx=assert(a.engine:Start(capture,'Bob Stonewell',{})); pump(10)
eq(tx.stage,'failed'); eq(a.j:GetSharingBalance(),10)

setup(); tx,item=start({fire,flee})
drop=function(m) return m.text:find('~K~',1,true) end
b.engine:Accept(item); pump(75)
eq(tx.stage,'unknown'); eq(a.j:GetSharingBalance(),7); eq(#b.j:GetRumours(42),2)
assert(not a.engine:Cancel(),'uncertain paid reports cannot be blindly refunded')
local adb,bdb=a.db,b.db
a=endpoint('Alice Sunstrider',adb); b=endpoint('Bob Stonewell',bdb); drop=nil
tx=a.engine:GetOutgoing(); eq(tx.stage,'unknown'); eq(a.j:GetSharingBalance(),7)
assert(a.engine:Retry()); pump(10); eq(tx.stage,'complete'); eq(#b.j:GetRumours(42),2)
eq(select(3,a.j:GetSharingBalance()),3,'retry no second debit')

-- A paid report from the previous pricing keeps its historical cost when both
-- clients update. Its schema-1 payload and receipt remain usable for retries.
setup();tx,item=start({fire,flee})
tx.cost=2;a.db.bestiary.points.reservations[tx.id]=2
drop=function(m) return m.text:find('~K~',1,true) end
assert(b.engine:Accept(item));pump(75)
adb,bdb=a.db,b.db;a=endpoint('Alice Sunstrider',adb);b=endpoint('Bob Stonewell',bdb);drop=nil
tx=a.engine:GetOutgoing();eq(tx.cost,2);assert(a.engine:Retry());pump(12)
eq(tx.stage,'complete');eq(select(3,a.j:GetSharingBalance()),2,'historical spending is not repriced')
eq(#b.j:GetRumours(42),2,'historical paid retry imports only once')

-- Paid retries re-check versions; updating one side cannot import or charge again.
setup();tx,item=start({fire})
drop=function(m) return m.text:find('~C~',1,true) end
assert(b.engine:Accept(item));pump(75);assert(not b.j.entries[42])
b.env.addonVersion='9.9.9';drop=nil;assert(a.engine:Retry());pump(8)
eq(tx.stage,'unknown');eq(select(3,a.j:GetSharingBalance()),2);assert(not b.j.entries[42])
assert(tx.message:find('Version mismatch',1,true))
b.env.addonVersion=buildVersion;pump(16);assert(a.engine:Retry());pump(20)
item=assert(b.engine:GetIncoming()[1]);assert(b.engine:Accept(item));pump(12)
eq(tx.stage,'complete');eq(select(3,a.j:GetSharingBalance()),2);eq(#b.j:GetRumours(42),1)

setup(); tx,item=start({fire})
drop=function(m) return m.text:find('~C~',1,true) end
b.engine:Accept(item); pump(75)
eq(tx.stage,'unknown'); assert(not b.j.entries[42],'missing commit cannot import')
adb,bdb=a.db,b.db; a=endpoint('Alice Sunstrider',adb); b=endpoint('Bob Stonewell',bdb)
eq(b.engine:GetIncoming()[1].state,'accepted','accepted preview survives reload')
drop=nil; tx=a.engine:GetOutgoing(); a.engine:Retry(); pump(15)
eq(tx.stage,'complete'); eq(#b.j:GetRumours(42),1); eq(a.j:GetSharingBalance(),8)

setup(); tx,item=start({fire}); b.engine:Accept(item)
drop=function(m) return m.text:find('~C~',1,true) end
pump(75); assert(not b.j.entries[42])
-- Receiver reset loses consent. Retry must re-offer, not silently import.
b.j:Reset(); drop=nil; assert(a.engine:Retry()); pump(25)
item=assert(b.engine:GetIncoming()[1]); eq(item.state,'pending'); assert(not b.j.entries[42])
b.engine:Accept(item); pump(12); eq(tx.stage,'complete'); eq(a.j:GetSharingBalance(),8)

setup(); tx,item=start(); adb=a.db; a=endpoint('Alice Sunstrider',adb)
eq(a.engine:GetOutgoing().stage,'cancelled'); eq(a.j:GetSharingBalance(),10)
b.engine:Accept(item); pump(190); assert(not b.j.entries[42],'late accept after sender reload cannot import')

setup(); tx,item=start({fire}); b.engine:Accept(item)
drop=function(m) return m.text:find('~K~',1,true) end
pump(75); clients['Bob Stonewell']=nil
for i=1,3 do assert(a.engine:Retry()); pump(65); eq(tx.stage,'unknown') end
assert(not a.engine:Retry()); assert(a.engine:CloseUnknown()); eq(tx.stage,'unresolved'); eq(a.j:GetSharingBalance(),8)

setup(); tx=assert(a.engine:Start(capture,'Bob Stonewell',{}))
a.engine:Receive('AFBShare','4~A~'..tx.id,'WHISPER','Bob Riverwind')
eq(tx.stage,'preflight','same first name with a different surname cannot accept')
a.engine:Receive('AFBShare','4~A~'..tx.id,'WHISPER','Mallory Falsewind')
a.engine:Receive('AFBShare','4~K~'..tx.id,'WHISPER','Bob Stonewell')
eq(tx.stage,'preflight'); eq(select(3,a.j:GetSharingBalance()),0)
b.engine:Receive('AFBShare','4~O~1000000-1-1~1~1~anything','WHISPER','Mallory Falsewind')
b.engine:Receive('AFBShare','4~C~1000000-1-1','WHISPER','Mallory Falsewind')
eq(#b.engine:GetIncoming(),0); assert(not b.j.entries[42])
for _,message in ipairs({'junk',string.rep('x',241),'4~H~bad','4~O~1000000-1-1~999~999~x','4~H~1000000-1-1\n'}) do
    b.engine:Receive('AFBShare',message,'WHISPER','Mallory Falsewind')
end
b.engine:Receive('AFBShare',secret,'WHISPER','Mallory Falsewind')
b.engine:Receive(secret,'valid','WHISPER','Mallory Falsewind')
b.engine:Receive('AFBShare','4~H~1000000-1-1',secret,'Mallory Falsewind')
b.engine:Receive('AFBShare','4~H~1000000-1-1','GUILD','Mallory Falsewind')
eq(#b.engine:GetIncoming(),0)
''')
print('PASS: simulated offers, free declines, insufficient funds, cancellation, compatibility, drops, reloads, retry limits and sender matching')

lua.execute(r'''
-- Raw chunk exercise: out-of-order and duplicate chunks, recipient mismatch,
-- altered duplicates, missing chunks, incoming capacity and expiry.
setup(); clients['Alice Sunstrider']=nil
local payload=assert(S.Encode(report(nil,{fire,flee})))
local function receive(text,sender) b.engine:Receive('AFBShare',text,'WHISPER',sender or 'Alice Sunstrider') end
local id='1000000-1-1'
receive('4~H~'..id..'~'..buildVersion)
local total=math.ceil(#payload/180)
for i=total,1,-1 do
    local chunk='4~O~'..id..'~'..i..'~'..total..'~'..payload:sub((i-1)*180+1,i*180)
    receive(chunk); receive(chunk)
end
eq(#b.engine:GetIncoming(),1,'ordered assembly independent of delivery order')
receive('4~C~'..id); assert(not b.j.entries[42],'unsolicited commit before acceptance ignored')
b.engine:Decline(b.engine:GetIncoming()[1]); pump(16)
id='1000000-2-1'; receive('4~H~'..id..'~'..buildVersion)
receive('4~O~'..id..'~1~2~'..string.rep('x',180))
receive('4~O~'..id..'~1~2~'..string.rep('y',180))
eq(#b.engine:GetIncoming(),0,'conflicting duplicate rejected')
pump(16); id='1000000-3-1'; receive('4~H~'..id..'~'..buildVersion)
receive('4~O~'..id..'~2~2~x'); pump(185); eq(#b.engine:GetIncoming(),0)
local r=report('1000000-4-1'); r.recipient='Carol Riverwind'; payload=assert(S.Encode(r))
receive('4~H~'..r.transaction..'~'..buildVersion)
receive('4~O~'..r.transaction..'~1~1~'..payload)
eq(#b.engine:GetIncoming(),0,'recipient binding')
setup(); clients['Alice Sunstrider']=nil
for _,sender in ipairs({'One Person','Two Person','Three Person','Four Person','Five Person'}) do
    receive('4~H~1000000-1-1~'..buildVersion,sender)
end
local n=0; for _ in pairs(b.j:GetSharingStorage().incoming) do n=n+1 end
eq(n,3,'bounded incoming transfers'); pump(185)
n=0; for _ in pairs(b.j:GetSharingStorage().incoming) do n=n+1 end; eq(n,0)

-- Full storage rejects atomically, rather than accepting only part of a report.
local capacity=ns.CreateBestiaryJournal({},identify)
local base=report()
for i=1,S.MAX_BASIC_REPORTS do
    base.name='Report '..i; base.transaction='1000000-'..i..'-1'; assert(capacity:ImportReport(base,'Alice Sunstrider',now))
end
local revision=capacity.revision
base.name='Overflow'; base.rumours={fire}
assert(not capacity:ImportReport(base,'Alice Sunstrider',now)); eq(capacity.revision,revision); eq(#capacity:GetRumours(42),0)
capacity:ResetDatabase(); eq(capacity:GetSharingBalance(),0); assert(not next(capacity:GetSharingStorage().receipts))
-- Per-creature rumour storage includes dismissed claims, keeping dedup bounded.
for i=1,S.MAX_STORED_RUMOURS do
    local r=report('1000000-'..i..'-1',{{kind='ability',value='Spell '..i}})
    assert(capacity:ImportReport(r,'Alice Sunstrider',now))
end
capacity:DismissRumour(42,capacity:GetRumours(42)[1])
revision=capacity.revision
assert(not capacity:ImportReport(report('1000000-99-1',{{kind='ability',value='Overflow'}}),'Alice Sunstrider',now))
eq(capacity.revision,revision)
-- In-flight reservations cannot overlap into a negative available balance.
local budget=ns.CreateBestiaryJournal({},identify)
budget:Ensure(1,false,'First creature'); budget:Ensure(2,false,'Second creature'); budget:Ensure(3,false,'Third creature')
assert(budget:ReserveShare('first',2)); assert(not budget:ReserveShare('second',2))
assert(budget:ReserveShare('second',1)); eq(budget:GetSharingBalance(),0)
assert(budget:CommitShare('second')); assert(budget:CommitShare('first')); eq(budget:GetSharingBalance(),0)
for i=4,8 do budget:Ensure(i,false,'Funding creature') end
for _,cost in ipairs({-1,1.5,math.huge,0/0,'4',secret}) do
    assert(not budget:ReserveShare('invalid',cost),'reservations require readable nonnegative finite integers')
end
assert(budget:ReserveShare('free',0));assert(budget:CommitShare('free'))
assert(budget:ReserveShare('larger',4));assert(budget:ReserveShare('larger',4))
assert(not budget:ReserveShare('larger',3));assert(not budget:ReserveShare('overspend',2))
eq(budget:GetSharingBalance(),1);assert(budget:CommitShare('larger'));eq(budget:GetSharingBalance(),1)
local beforeSpent=select(3,budget:GetSharingBalance())
assert(budget:ReserveShare('waived',1));eq(budget:GetSharingBalance(),0)
local ok,charged=budget:CommitShare('waived',true)
assert(ok);eq(charged,0);eq(budget:GetSharingBalance(),1)
eq(select(3,budget:GetSharingBalance()),beforeSpent);eq(select(4,budget:GetSharingBalance()),0)
assert(not budget:CommitShare('waived',true),'a removed reservation cannot be discounted or committed again')
''')
print('PASS: chunk ordering/duplicates, recipient binding, bounded queues, expiry, storage caps and full reset')

lua.execute(r'''
local function events(client,stage)
    local result={}
    for _,event in ipairs(client.j:GetEventLog().entries) do
        if event.details and event.details.kind=='sharing_transfer' and (not stage or event.details.stage==stage) then result[#result+1]=event end
    end
    return result
end
setup();a.db.pointAnnouncements=false;a.db.creatureAnnouncements=false
local tx,item=start({fire,flee,melee});eq(#events(a,'offered'),1);eq(#events(b,'received'),0)
assert(b.engine:Accept(item));pump(12)
eq(#events(a,'accepted'),1);eq(#events(a,'complete'),1);eq(#events(b,'received'),1)
local sent=events(a,'complete')[1]
eq(sent.details.peer,'Bob Stonewell');eq(sent.details.creatureID,42);eq(sent.details.rumours,3);eq(sent.details.knowledge,4)
assert(sent.message:find('Defias Pillager',1,true) and sent.message:find('4 knowledge',1,true))
local received=events(b,'received')[1];eq(received.details.peer,'Alice Sunstrider');eq(received.details.knowledge,0)
a.engine:Receive('AFBShare','4~K~'..tx.id,'WHISPER','Bob Stonewell')
b.engine:Receive('AFBShare','4~C~'..tx.id,'WHISPER','Alice Sunstrider');pump(4)
eq(#events(a,'complete'),1);eq(#events(b,'received'),1,'duplicate commit never duplicates the receipt log')
setup();tx,item=start();assert(a.engine:Cancel());pump(4)
eq(#events(a,'cancelled'),1);eq(#events(a,'complete'),0);eq(#events(b,'received'),0)
setup();tx,item=start({fire});drop=function(m) return m.text:find('~K~',1,true) end
assert(b.engine:Accept(item));pump(75)
eq(#events(a,'delivery unknown'),1);eq(#events(b,'received'),1)
drop=nil;assert(a.engine:Retry());pump(12)
eq(#events(a,'retrying'),1);eq(#events(a,'accepted'),1);eq(#events(a,'complete'),1)
eq(#events(b,'received'),1,'paid retry logs no second import')
b=endpoint('Bob Stonewell',b.db);eq(#events(b,'received'),1,'received account persists across reload')
''')
print('PASS: transfer history, costs, cancellation, retries and duplicate receipt suppression')

lua.execute(r'''
local function loreSetup()
    setup()
    a.db.bestiary.points.earned=0;a.db.bestiary.points.spent=0
    local e=a.j.entries[42];e.category='Beast'
    e.beastLore={level=9,observed=now,rows={{left='Diet:',right='Meat'},{left='Tameable'}}}
    e.beastLoreSource='gameTooltip'
    capture=assert(S.CaptureLore(a.j,42))
end
loreSetup()
local tx,item=start()
eq(tx.cost,0);eq(a.j:GetSharingBalance(),0)
assert(not b.j.entries[42],'offer alone cannot import lore')
assert(b.engine:Accept(item));pump(10)
eq(tx.stage,'complete');eq(tx.cost,0)
eq(b.j.entries[42].beastLore.rows[1].right,'Meat')
eq(b.j.entries[42].beastLoreSender,'Alice Sunstrider')
eq(#b.j:GetRumours(42),0);eq(select(3,a.j:GetSharingBalance()),0);eq(b.j:GetSharingBalance(),0)
assert(not tx.basicInfoWaived,'free lore was never a paid basic offer')
local received=b.j.entries[42].beastLore
a.engine:Receive(a.engine.PREFIX,'4~K~'..tx.id,'WHISPER','Bob Stonewell')
assert(b.j.entries[42].beastLore==received)
loreSetup();tx,item=start();assert(b.engine:Decline(item));pump(5)
assert(not b.j.entries[42]);eq(select(3,a.j:GetSharingBalance()),0)
loreSetup();tx,item=start();drop=function(m) return m.text:find('~K~',1,true) end
assert(b.engine:Accept(item));pump(75);eq(tx.stage,'unknown')
local stored=b.j.entries[42].beastLore
drop=nil;assert(a.engine:Retry());pump(15);eq(tx.stage,'complete')
assert(b.j.entries[42].beastLore==stored,'receipt retry cannot replace or duplicate lore')
eq(select(3,a.j:GetSharingBalance()),0)
b=endpoint('Bob Stonewell',b.db);eq(b.j.entries[42].beastLore.rows[1].right,'Meat')
-- A full native snapshot can exceed the original paid report's byte budget.
loreSetup()
for i=1,30 do capture.beastLore.rows[i]={left='Field '..i..':',right=string.rep('x',180)} end
tx=assert(a.engine:Start(capture,'Bob Stonewell',{}));assert(#tx.payload>2048)
pump(70);item=assert(b.engine:GetIncoming()[1]);assert(b.engine:Accept(item));pump(10)
eq(tx.stage,'complete');eq(#b.j.entries[42].beastLore.rows,30);eq(tx.cost,0)
''')
print('PASS: free Beast Lore offers, full surnames, consent, zero balances, retries, reload and large snapshots')
