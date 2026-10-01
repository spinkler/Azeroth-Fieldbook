"""Options labels actual stores, including deferred/pending scopes."""
import unittest
from test_player_names_preservation import full_client


SECTIONS = "{'bestiary','gathering','atlas','angling','merchants','treasure','lore'}"


class StorageScopeTests(unittest.TestCase):
    def client(self, account=True):
        lua=full_client('{version=1,accountWideTracking='+str(account).lower()+'}')
        lua.execute("""
            local _,book=debug.getupvalue(AzerothFieldbookNextEntry,1)
            shell=book:GetShell()
            shell:EnsureSection('bestiary')
        """)
        return lua

    def test_all_seven_active_stores_and_shared_label_without_writes(self):
        for account in (True,False):
            with self.subTest(account=account):
                lua=self.client(account)
                lua.execute("ids="+SECTIONS)
                lua.execute("expected="+repr('Account-wide' if account else 'Character-specific'))
                lua.execute("""
                    local scopeFrame
                    for _,id in ipairs(ids) do
                        shell:ShowSection(id)
                        local frame=AzerothFieldbookOptions
                        assert(rawget(shell:GetFrame(),'scopeLabel')==nil,'scope appears only in Options')
                        assert(frame.scopeLabel:GetText()==expected,id..': '..frame.scopeLabel:GetText())
                        assert(not scopeFrame or scopeFrame==frame.scope,'one shared indicator')
                        scopeFrame=frame.scope
                        local before=capture()
                        frame.scope.scripts.OnEnter(frame.scope)
                        local store=expected=='Account-wide' and AzerothFieldbookAccountDB.bestiary or AzerothFieldbookDB.bestiary
                        assert(ns.GetActiveStorageScope(id,store)==expected)
                        unchanged(before,'scope inspection')
                    end
                """)

    def test_shared_options_stays_open_on_section_change(self):
        lua=self.client()
        lua.execute("""
            local options=AzerothFieldbookOptions
            local root=shell:GetFrame()
            shell:ShowSection('bestiary')
            root.optionsButton.scripts.OnClick()
            assert(options:IsShown())
            shell:ShowSection('gathering')
            assert(options:IsShown(),'Bestiary-to-Gathering closed shared Options')
            assert(options:IsShown() and options.scopeLabel:GetText()=='Account-wide')
            shell:ShowSection('gathering')
            assert(options:IsShown(),'reselecting same section closed Options')
            shell:ShowSection('atlas')
            assert(options:IsShown(),'Gathering-to-Atlas closed shared Options')
            assert(options:IsShown() and options.scopeLabel:GetText()=='Account-wide')
            shell:ShowSection('lore')
            assert(options:IsShown(),'Atlas-to-Lore closed shared Options')
        """)

    def test_pending_option_and_fresh_reload(self):
        lua=self.client()
        lua.execute("""
            AzerothFieldbookDB.accountWideTracking=false
            for _,id in ipairs(shell.order) do
                shell:ShowSection(id);assert(AzerothFieldbookOptions.scopeLabel:GetText()=='Account-wide')
            end
        """)
        # Fresh Lua namespace, copying SavedVariables exactly as a UI reload.
        names=['AzerothFieldbookDB','AzerothFieldbookAccountDB','AzerothFieldbookGatheringDB',
               'AzerothFieldbookAtlasDB','AzerothFieldbookAnglingDB','AzerothFieldbookLedgerDB',
               'AzerothFieldbookTreasureDB','AzerothFieldbookLoreDB']
        lua.execute("""
            function serialize(v)
                if type(v)=='string' then return string.format('%q',v) end
                if type(v)~='table' then return tostring(v) end
                local rows={};for k,x in pairs(v) do rows[#rows+1]='['..serialize(k)..']='..serialize(x) end
                return '{'..table.concat(rows,',')..'}'
            end
        """)
        saves='\n'.join(name+'='+lua.eval('serialize('+name+')') for name in names)
        reloaded=full_client(initialize=False)
        reloaded.execute(saves)
        reloaded.execute("""
            mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
            local _,book=debug.getupvalue(AzerothFieldbookNextEntry,1);local shell=book:GetShell()
            for _,id in ipairs(shell.order) do
                shell:ShowSection(id);assert(AzerothFieldbookOptions.scopeLabel:GetText()=='Character-specific')
            end
        """)

    def test_deferred_migration_uses_character_scope(self):
        lua=full_client(initialize=False)
        lua.execute("""
            AzerothFieldbookLoreDB={schema=99,entries={preserve='future'}}
            mainEvent(main,'ADDON_LOADED','AzerothFieldbook')
            local _,book=debug.getupvalue(AzerothFieldbookNextEntry,1);local shell=book:GetShell()
            shell:EnsureSection('bestiary')
            shell:ShowSection('lore');assert(AzerothFieldbookOptions.scopeLabel:GetText()=='Character-specific')
            shell:ShowSection('angling');assert(AzerothFieldbookOptions.scopeLabel:GetText()=='Account-wide')
            ns.InitializationBlocked=true;assert(ns.GetActiveStorageScope('lore')=='Storage unavailable')
        """)


if __name__ == '__main__':
    unittest.main()
