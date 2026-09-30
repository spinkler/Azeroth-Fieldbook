"""Player summaries through full-TOC initialization; migration remains one-time."""
import unittest
from test_player_names_preservation import full_client


def client(root='{version=1}', setup=''):
    lua = full_client(root, initialize=False)
    lua.execute('''
        messages={}
        DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
        function boot()
            messages={};mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
        end
        function summary()
            local result
            for _,text in ipairs(messages) do
                if text:find('Account-wide tracking ',1,true) then
                    assert(not result,'multiple grouped summaries');result=text
                end
            end
            return result
        end
        function serialize(value)
            if type(value)=='string' then return string.format('%q',value) end
            if type(value)~='table' then return tostring(value) end
            local rows={}
            for key,child in pairs(value) do rows[#rows+1]='['..serialize(key)..']='..serialize(child) end
            return '{'..table.concat(rows,',')..'}'
        end
    ''' + setup)
    return lua


class AccountSummaryTests(unittest.TestCase):
    def test_first_enable_names_committed_sections_once_and_retains_character_data(self):
        lua = client('{version=1,accountWideTracking=false}')
        lua.execute('''
            boot();assert(not summary())
            local j=ns.CreateBestiaryJournal(AzerothFieldbookDB,function() end)
            j:Ensure(42,false,'Original creature')
            local personal=literal(AzerothFieldbookDB.bestiary)
            j:SetAccountWideTracking(true);assert(not summary(),'option is pending until reload')
            boot();local text=assert(summary())
            assert(text:find('One-time import completed for: Bestiary, Herbs & Minerals, Atlas, Almanac, Ledger, Treasure, Lore.',1,true),text)
            assert(text:find('Original character journals retained separately.',1,true))
            assert(text:find('not continuously synchronized',1,true))
            assert(literal(AzerothFieldbookDB.bestiary)==personal)
            assert(AzerothFieldbookAccountDB.bestiary.entries[42])
            boot();assert(not summary(),'ordinary login must not repeat summary')
        ''')
        # A fresh Lua namespace with actual serialized SavedVariables proves the
        # quiet subsequent login is not just a process-local notification latch.
        setup = '\n'.join(name + '=' + lua.eval('serialize(' + name + ')')
                          for name in lua.globals().stores.values())
        reloaded = client(setup=setup)
        reloaded.execute('boot();assert(not summary())')

    def test_default_enable_imports_and_disable_reenable_explain_separate_stores(self):
        lua = client()
        lua.execute('''
            boot();assert(summary():find('One-time import',1,true))
            local db=AzerothFieldbookDB;local account=AzerothFieldbookAccountDB
            local j=ns.CreateBestiaryJournal(db,function() end,account)
            j:Ensure(42,false,'Account-only creature')
            j:SetAccountWideTracking(false);boot()
            local text=assert(summary())
            assert(text:find('disabled.',1,true) and text:find('account data was not copied back',1,true))
            assert(not db.bestiary.entries[42] and account.bestiary.entries[42])
            j=ns.CreateBestiaryJournal(db,function() end);j:Ensure(43,false,'Character-only creature')
            boot();assert(not summary())
            j:SetAccountWideTracking(true);boot();text=assert(summary())
            assert(text:find('Resumed existing account journals',1,true))
            assert(text:find('do not re-import later character-only changes',1,true))
            assert(not text:find('One-time import completed',1,true))
            assert(not account.bestiary.entries[43] and db.bestiary.entries[43])
            boot();assert(not summary())
            ns.CreateBestiaryJournal(db,function() end,account):ResetDatabase()
            boot();assert(not summary(),'settings reset is not a scope transition or import')
        ''')

    def test_deferred_future_and_malformed_sections_are_preserved_and_named_truthfully(self):
        for unsupported in ("{schema=2,marker='Future original'}", "{schema=1,entries='Malformed original'}"):
            with self.subTest(unsupported=unsupported):
                lua = client(setup='AzerothFieldbookLoreDB=' + unsupported)
                lua.execute(r'''
                    local original=AzerothFieldbookLoreDB;local before=literal(original)
                    boot();local text=assert(summary())
                    assert(text:find('One-time import completed for: Bestiary, Herbs & Minerals, Atlas, Almanac, Ledger, Treasure.',1,true))
                    assert(text:find('Migration deferred for: Lore; saved data preserved.',1,true))
                    assert(AzerothFieldbookLoreDB==original and literal(original)==before)
                    assert(not AzerothFieldbookAccountDB.sections.lore)
                    assert(not AzerothFieldbookAccountDB.sectionImports.lore)
                    assert(table.concat(messages,'\n'):find('account migration deferred',1,true),'keep existing detailed warning')
                    boot();assert(not summary(),'unchanged deferral must not repeat grouped success')
                    assert(literal(original)==before)
                    AzerothFieldbookLoreDB={};boot();text=assert(summary())
                    assert(text:find('One-time import completed for: Lore.',1,true),text)
                    boot();assert(not summary())
                ''')

    def test_existing_markers_on_upgrade_do_not_announce_an_import(self):
        lua = client()
        lua.execute('''
            boot();assert(summary());AzerothFieldbookDB.accountTrackingActive=nil
            boot();assert(not summary(),'legacy saves with completed imports remain quiet')
            AzerothFieldbookAccountDB.sectionImports.lore[AzerothFieldbookDB.accountTrackingKey]=nil
            boot();local text=assert(summary())
            assert(text:find('One-time import completed for: Lore.',1,true))
            assert(not text:find('for: Bestiary',1,true))
        ''')

    def test_newer_schema_deferral_and_existing_account_future_data_keep_warnings(self):
        lua = client(setup="AzerothFieldbookGatheringDB={schema=2,marker='Retained'}")
        lua.execute(r'''
            local before=literal(AzerothFieldbookGatheringDB)
            boot();local text=assert(summary())
            assert(text:find('Migration deferred for: Herbs & Minerals;',1,true),text)
            assert(not text:find('for: Bestiary, Herbs & Minerals',1,true))
            assert(table.concat(messages,'\n'):find('newer data schema; account migration deferred',1,true))
            assert(literal(AzerothFieldbookGatheringDB)==before)
            local future={schema=2,marker='Future shared Lore'}
            AzerothFieldbookAccountDB.sections.lore=future
            AzerothFieldbookDB.accountWideTracking=false;boot()
            local personal=literal(AzerothFieldbookLoreDB)
            AzerothFieldbookDB.accountWideTracking=true;boot();text=assert(summary())
            assert(text:find('Resumed existing account journals',1,true))
            assert(text:find('Migration deferred for: Herbs & Minerals, Lore;',1,true),text)
            assert(AzerothFieldbookAccountDB.sections.lore==future and literal(future)==literal({schema=2,marker='Future shared Lore'}))
            assert(literal(AzerothFieldbookLoreDB)==personal)
        ''')

    def test_interrupted_bestiary_import_does_not_record_success(self):
        lua = client()
        lua.execute('''
            local real=ns.CreateBestiaryJournal
            ns.CreateBestiaryJournal=function() error('interrupted before commit') end
            assert(not pcall(boot) and not summary())
            assert(not AzerothFieldbookAccountDB.importedCharacters[AzerothFieldbookDB.accountTrackingKey])
            ns.CreateBestiaryJournal=real;boot()
            assert(summary():find('One-time import completed',1,true))
            boot();assert(not summary())
        ''')


if __name__ == '__main__':
    unittest.main()
