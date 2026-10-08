"""Per-journal scope choices through the real startup and retained stores."""
import unittest
from test_account_summaries import client


class IndividualTrackingTests(unittest.TestCase):
    def test_each_journal_can_be_the_only_shared_or_only_personal_store(self):
        for default in ('true', 'false'):
            for section in ('bestiary', 'gathering', 'atlas', 'angling', 'ledger', 'treasure', 'lore'):
                with self.subTest(default=default, section=section):
                    other = 'false' if default == 'true' else 'true'
                    lua = client('{version=1,accountWideTracking=' + default +
                                 ',accountTrackingSections={' + section + '=' + other + '}}')
                    lua.execute('''
                        boot();assert(not ns.InitializationBlocked)
                        local db,account=AzerothFieldbookDB,AzerothFieldbookAccountDB
                        assert(db.accountTrackingKey)
                        local personal={gathering=AzerothFieldbookGatheringDB,atlas=AzerothFieldbookAtlasDB,
                            angling=AzerothFieldbookAnglingDB,ledger=AzerothFieldbookLedgerDB,
                            treasure=AzerothFieldbookTreasureDB,lore=AzerothFieldbookLoreDB}
                        for _,section in ipairs(ns.TrackingSections) do
                            local key=section[1];local on=ns.GetSectionAccountTracking(db,key)
                            if key=='bestiary' then
                                assert((account.importedCharacters[db.accountTrackingKey]==true)==on)
                            else
                                local active=ns.ActiveSectionStores[key]
                                if on then
                                    assert(active==account.sections[key] and active~=personal[key],key)
                                    assert(account.sectionImports[key][db.accountTrackingKey])
                                else
                                    assert(active==personal[key],key)
                                    assert(not account.sectionImports or not account.sectionImports[key],key)
                                end
                            end
                        end
                        assert(ns.GetActiveStorageScope('annals')=='Character-specific')
                        assert(summary());boot();assert(not summary(),'unchanged mixed choices stay quiet')
                    ''')

    def test_pending_choices_reset_and_one_time_imports(self):
        lua = client('{version=1,accountWideTracking=false}')
        lua.execute('''
            boot();local db=AzerothFieldbookDB
            local journal=ns.CreateBestiaryJournal(db,function() end)
            local original=ns.ActiveSectionStores.atlas
            journal:SetAccountWideTracking(true,'atlas')
            assert(journal:IsTrackingChangePending('atlas') and journal:IsTrackingChangePending())
            assert(not journal:IsTrackingChangePending('bestiary'))
            assert(ns.ActiveSectionStores.atlas==original,'pending choice must not swap live store')
            journal:SetAccountWideTracking(false,'atlas');assert(not journal:IsTrackingChangePending())
            journal:SetAccountWideTracking(true,'atlas');journal:ResetDatabase()
            assert(db.accountTrackingSections.atlas and db.accountWideTracking==false)
            boot();local shared=ns.ActiveSectionStores.atlas
            assert(shared~=original)
            journal=ns.CreateBestiaryJournal(db,function() end)
            journal:SetAccountWideTracking(false,'atlas');boot()
            assert(ns.ActiveSectionStores.atlas==original)
            original.localOnlyMarker='later personal change'
            journal:SetAccountWideTracking(true,'atlas');boot()
            assert(ns.ActiveSectionStores.atlas==shared and not shared.localOnlyMarker)
            assert(not summary():find('One-time import completed',1,true))
            boot();assert(not summary())
        ''')

    def test_invalid_scope_maps_are_blocked_before_import(self):
        for value in ('false', '{atlas="yes"}', '{annals=true}'):
            lua = client('{version=1,accountTrackingSections=' + value + '}')
            lua.execute('''
                local before=literal(AzerothFieldbookDB)
                boot();assert(ns.InitializationBlocked)
                assert(literal(AzerothFieldbookDB)==before)
            ''')

    def test_whole_backup_restores_individual_choices(self):
        from test_fieldbook_backups import client as backup_client, reload_client
        lua = backup_client(account=True)
        lua.execute('''
            AzerothFieldbookDB.accountTrackingSections={atlas=false,ledger=false,bestiary=true}
        ''')
        lua = reload_client(lua)
        lua.execute('''
            local wire=assert(B.Create())
            local decoded=assert(B.Decode(wire))
            assert(decoded.stores.AzerothFieldbookDB.accountTrackingSections.atlas==false)
            AzerothFieldbookDB.accountTrackingSections={atlas=true,bestiary=false}
            assert(B.RequestRestore(wire))
        ''')
        fresh = reload_client(lua)
        fresh.execute('''
            assert(ns.GetSectionAccountTracking(AzerothFieldbookDB,'bestiary'))
            assert(not ns.GetSectionAccountTracking(AzerothFieldbookDB,'atlas'))
            assert(not ns.GetSectionAccountTracking(AzerothFieldbookDB,'ledger'))
            assert(ns.ActiveSectionStores.atlas==AzerothFieldbookAtlasDB)
            assert(ns.ActiveSectionStores.ledger==AzerothFieldbookLedgerDB)
        ''')


if __name__ == '__main__':
    unittest.main()
