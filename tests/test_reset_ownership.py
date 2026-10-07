"""A1: reset retains the allocator while discarding journals/import flags."""
import itertools
from test_fieldbook_backups import client, reload_client

PERSONAL = ['AzerothFieldbookDB','AzerothFieldbookGatheringDB','AzerothFieldbookAtlasDB',
    'AzerothFieldbookAnglingDB','AzerothFieldbookLedgerDB','AzerothFieldbookTreasureDB',
    'AzerothFieldbookLoreDB','AzerothFieldbookAnnalsDB']
def saved(lua, names):
    return '\n'.join(n+'='+lua.eval('disk('+n+')') for n in names)
def switch(account, personal=None):
    lua=client(account=True,initialize=False)
    lua.execute(saved(account,['AzerothFieldbookAccountDB','AzerothFieldbookBackupDB']))
    if personal: lua.execute(personal)
    lua.execute("mainEvent(main,'ADDON_LOADED','AzerothFieldbook');assert(not ns.InitializationBlocked)")
    return lua
def seed(account, name):
    lua=client(account=False,initialize=False)
    if account: lua.execute(saved(account,['AzerothFieldbookAccountDB']))
    lua.execute("mainEvent(main,'ADDON_LOADED','AzerothFieldbook')")
    lua.globals().ownerName=name
    lua.execute("assert(journals(false).lore:Create('mystery',{title=ownerName})); AzerothFieldbookDB.accountWideTracking=true")
    return reload_client(lua)
alice=seed(None,'Alice'); alice_files=saved(alice,PERSONAL)
bob=seed(alice,'Bob'); bob_files=saved(bob,PERSONAL); old=bob.eval('assert(B.Capture())')
carol=seed(bob,'Carol'); carol_files=saved(carol,PERSONAL)
for order in itertools.permutations([('Alice',alice_files,1),('Carol',carol_files,3)]):
    current=switch(carol,bob_files)
    current.execute('assert(B.StageFullReset())'); current=reload_client(current)
    assert current.eval('AzerothFieldbookDB.accountTrackingKey')==4
    reset_bob=saved(current,PERSONAL)
    current=switch(current)
    assert current.eval('AzerothFieldbookDB.accountTrackingKey')==5
    for name,personal,key in order:
        current=switch(current,personal)
        assert current.eval('AzerothFieldbookDB.accountTrackingKey')==key
        current.globals().ownerName=name
        current.execute("""
            local found=0
            for _,e in pairs(journals(true).lore.entries) do if e.title==ownerName then found=found+1 end end
            assert(found==1)
            local original=0
            for _,e in pairs(journals(false).lore.entries) do if e.title==ownerName then original=original+1 end end
            assert(original==1,'retained personal original lost')
            assert(AzerothFieldbookAccountDB.atlasReferenceRepairs[AzerothFieldbookDB.accountTrackingKey])
            local s=journals(true).bestiary:GetSharingStorage()
            assert(not s.receipts.owner and not s.incoming.owner and not s.outgoing)
            s.receipts.owner={received=now,owner=ownerName};s.incoming.owner={expires=now+100,owner=ownerName};s.ownerSentinel=ownerName
            s.outgoing={owner=ownerName}
            for key,other in pairs(AzerothFieldbookAccountDB.bestiary.sharingCharacters) do
                if key~=AzerothFieldbookDB.accountTrackingKey then
                    assert(other~=s and other.receipts~=s.receipts and other.incoming~=s.incoming)
                    assert(not other.outgoing or other.outgoing.owner~=ownerName)
                end
            end
            s.outgoing=nil -- Synthetic evidence never enters live transport.

        """)
        current=switch(current,saved(current,PERSONAL))
        current.globals().ownerName=name
        current.execute("""
            local s=journals(true).bestiary:GetSharingStorage()
            assert(s.ownerSentinel==ownerName)
            local found=0;for _,e in pairs(journals(true).lore.entries) do found=found+1 end
            assert(found<=2,'returning character imported twice')
        """)
    current=switch(current,reset_bob)
    current.globals().oldWire=old
    current.execute('assert(B.RequestRestore(oldWire))');current=reload_client(current)
    assert current.eval('AzerothFieldbookAccountDB.nextCharacter')>=5
    current.execute('assert(B.StageFullReset())');current=reload_client(current)
    assert current.eval('AzerothFieldbookDB.accountTrackingKey')==6
    current=switch(current)
    assert current.eval('AzerothFieldbookDB.accountTrackingKey')==7
print('PASS: A1 three owners, return orders, new arrivals, repeated reset, older restore, delivery isolation')
