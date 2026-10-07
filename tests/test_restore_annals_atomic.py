"""A2: late failures leave all nine original roots and pending Annals unchanged."""
from test_fieldbook_backups import client,reload_client
for kind in ('accepted','completed','removed'):
    lua=client(account=True)
    lua.globals().kind=kind
    lua.execute("""
        local snapshot=assert(B.Decode(assert(B.Capture())))
        snapshot.present.AzerothFieldbookAnnalsDB=nil;snapshot.stores.AzerothFieldbookAnnalsDB=nil
        local wire=assert(B.Encode(snapshot))
        AzerothFieldbookAnnalsDB.pending[123]={kind=kind,at=now-20,title='Pending quest',location={zone='Test'},sequence=1,
            reward={status='unknown',choiceStatus='unknown'}}
        assert(B.RequestRestore(wire))
    """)
    fresh=reload_client(lua,initialize=False)
    fresh.execute("""
        local before=capture();assert(#stores==9)
        ns.MapBrightness.Initialize=function()
            assert(not AzerothFieldbookAnnalsDB.pending[123] and #AzerothFieldbookAnnalsDB.events==1)
            error('late failure after actual Annals startup')
        end
        mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
        assert(ns.InitializationBlocked and AzerothFieldbookBackupDB.pending)
        unchanged(before,'late Annals rollback')
        assert(B.CancelPending());unchanged(before,'cancel')
    """)
    retry=reload_client(lua)
    retry.execute('assert(not AzerothFieldbookAnnalsDB.pending[123] and #AzerothFieldbookAnnalsDB.events==1)')
    retry=reload_client(retry)
    retry.execute('assert(#AzerothFieldbookAnnalsDB.events==1)')
print('PASS: A2 all nine roots atomic after Annals startup; cancel, retry and successful legacy restore')
