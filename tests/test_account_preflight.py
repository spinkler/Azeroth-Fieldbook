"""H1: unsupported account data holds before imports and UI settings writes."""
from test_fieldbook_backups import client
for tracking in (False,True):
    for root in ("'RECOVER ME'",'{version=2,nextCharacter=8,evidence="KEEP"}',
                 '{version=1,sectionImports={lore="KEEP"}}','{version=1,importedCharacters="KEEP"}',
                 '{version=1,atlasReferenceMaps={[1]="KEEP"}}','{version=1,sections={lore="KEEP"}}'):
        lua=client(account=tracking,initialize=False)
        lua.execute('AzerothFieldbookAccountDB='+root)
        lua.execute("""
            local before=capture()
            mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
            assert(ns.InitializationBlocked);unchanged(before,'account preflight')
            ns.UIScale:Initialize(AzerothFieldbookDB);ns.UIScale:Set(1.2)
            ns.TextSize:Set(2);ns.InitializeTracking(AzerothFieldbookDB)
            mainEvent(main,'PLAYER_ENTERING_WORLD');unchanged(before,'held callbacks')
            local raw=assert(ns.FieldbookBackups.Decode(assert(ns.FieldbookBackups.Capture())))
            assert(literal(raw.stores.AzerothFieldbookAccountDB)==literal(AzerothFieldbookAccountDB))
        """)
    for root in ('nil','{}','{uiScale=0.8}','{version=1,sections={},sectionImports={lore={}}}'):
        lua=client(account=tracking,initialize=False);lua.execute('AzerothFieldbookAccountDB='+root)
        lua.execute("mainEvent(main,'ADDON_LOADED','AzerothFieldbook');assert(not ns.InitializationBlocked)")
print('PASS: H1 fresh/legacy compatibility, future/scalar/nested malformed preservation, scope on/off and raw recovery')
