from test_fieldbook_backups import client,reload_client

alice=client(account=True)
bob=client(account=False,initialize=False)
bob.execute('AzerothFieldbookAccountDB='+alice.eval('disk(AzerothFieldbookAccountDB)'))
bob.execute("mainEvent(main,'ADDON_LOADED','AzerothFieldbook'); assert(not ns.InitializationBlocked)")
bob.execute("""
function upvalue(fn,key)
    for i=1,30 do local n,v=debug.getupvalue(fn,i);if not n then return end;if n==key then return v end end
end
local atlas=assert(upvalue(ns.AnnalsController.adapters.atlas.resolve,'journal'))
atlas.state.autoEntrances=true
entranceID=assert(atlas.entrances:Record({direction='entry',at=now,exterior={mapID=101,x=2500,y=2500},
    size={width=1000,height=2000},interior={zoneMapID=101,bestMapID=201,parentMapID=101,microMapID=201,
    zone='Coast',subzone='Quiet Hollow',minimap='Quiet Hollow',mapName='Quiet Hollow',microName='Quiet Hollow'}}))
local event=assert(AzerothFieldbookAnnalsDB.events[1])
assert(event.kind=='discovery' and event.link.section=='atlas' and event.link.key==entranceID)
assert(ns.AnnalsController:Resolve(event.link), 'fixture did not resolve before import')
-- Exercise a baseline timestamp-only link through this character's original.
event.link.identity=tostring(atlas.entrances.records[entranceID].firstSeen)
AzerothFieldbookDB.accountWideTracking=true
""")
print('Before account import: Annals link resolves raw entrance ID',bob.eval('entranceID'))
bob=reload_client(bob)
bob.execute("""
assert(AzerothFieldbookDB.accountTrackingKey==2)
local event=assert(AzerothFieldbookAnnalsDB.events[1])
local entries=AzerothFieldbookAccountDB.sections.atlas.entrances.records
local imported=assert(entries['char2:1'])
assert(tostring(imported.firstSeen)==event.link.identity, 'imported identity did not match original evidence')
assert(ns.AnnalsController:Resolve(event.link).id==imported.id)
assert(ns.AnnalsController:OpenLink(event.link))
assert(#AzerothFieldbookAnnalsDB.events==1)
""")
bob=reload_client(bob)
bob.execute("""
local link=AzerothFieldbookAnnalsDB.events[1].link
assert(ns.AnnalsController:Resolve(link).id=='char2:1')
local records=AzerothFieldbookAccountDB.sections.atlas.entrances.records
-- Simulate an account import completed by the baseline, before references existed.
records['char2:1'].reference='old-import-assigned-after-migration'
assert(ns.AnnalsController:Resolve(link).id=='char2:1')
local ambiguous=copy(records['char2:1']);ambiguous.id='char2:99';records['char2:99']=ambiguous
assert(not ns.AnnalsController:Resolve(link),'ambiguous legacy traversal must remain unavailable')
records['char2:99']=nil
local other=copy(records['char2:1']);other.id='n1';other.reference='another-owner';records.n1=other
assert(ns.AnnalsController:Resolve(link).id=='char2:1','reused key and equal timestamp crossed owners')
records['char2:1']=nil
assert(not ns.AnnalsController:Resolve(link),'deleted source must not select another owner')
""")
print('PASS: A5 entrance selection, character-scoped legacy import, reload and reused key isolation')
