"""Saved tooltip intent through startup, explicit choices and scoped resets."""
import unittest
from kill_test_harness import new_client


class SpellIDPreferenceTests(unittest.TestCase):
    def client(self, root='nil', current=False):
        lua = new_client(tracking=True, initialize=False)
        lua.execute('AzerothFieldbookDB=' + root)
        lua.globals().cvar = current
        lua.execute('''
            writes=0
            function GetCVarBool(key) assert(key=='tooltipShowAuraSpellIDs');return cvar end
            function SetCVar(key,value)
                assert(key=='tooltipShowAuraSpellIDs');writes=writes+1;cvar=value=='1'
            end
            function boot() fire('ADDON_LOADED','AzerothFieldbook') end
            function journal() return ns.CreateBestiaryJournal(AzerothFieldbookDB,function() end,AzerothFieldbookAccountDB) end
            boot()
        ''')
        return lua

    def test_new_default_enables_without_interaction_and_skips_redundant_writes(self):
        lua = self.client()
        lua.execute('''
            assert(cvar and writes==1 and AzerothFieldbookDB.showSpellIDs)
            boot();boot();assert(writes==1)
            cvar=false
            fire('PLAYER_ENTERING_WORLD');tick();assert(not cvar and writes==1)
            assert(journal():GetSpellIDTooltips(),'UI shows saved intent, not external CVar drift')
            boot();assert(cvar and writes==2,'startup repairs enabled intent')
        ''')
        lua = self.client(current=True)
        lua.execute('assert(writes==0 and AzerothFieldbookDB.showSpellIDs)')

    def test_explicit_opt_out_survives_missing_or_stale_legacy_marker(self):
        for marker in ('nil', 'false', 'true'):
            with self.subTest(marker=marker):
                lua = self.client('{version=1,showSpellIDs=false,spellIDTooltipInitialized=' + marker + '}', True)
                lua.execute('''
                    assert(not cvar and writes==1 and not journal():GetSpellIDTooltips())
                    assert(AzerothFieldbookDB.spellIDTooltipInitialized==nil)
                    boot();assert(not cvar and writes==1)
                    journal():SetSpellIDTooltips(true);assert(cvar and writes==2)
                    journal():SetSpellIDTooltips(true);boot();assert(writes==2)
                    journal():SetSpellIDTooltips(false);boot();assert(not cvar and writes==3)
                ''')

    def test_old_marker_without_preference_defaults_on(self):
        lua = self.client('{version=1,spellIDTooltipInitialized=true}')
        lua.execute('assert(cvar and writes==1 and AzerothFieldbookDB.showSpellIDs)')

    def test_journal_only_reset_preserves_choice_but_documented_settings_reset_defaults_on(self):
        lua = self.client('{version=1,showSpellIDs=false}')
        lua.execute('''
            journal():Reset();boot();assert(not cvar and writes==0 and not AzerothFieldbookDB.showSpellIDs)
            journal():ResetDatabase();assert(cvar and writes==1 and AzerothFieldbookDB.showSpellIDs)
            boot();assert(writes==1)
            journal():SetSpellIDTooltips(false)
            SlashCmdList.AZEROTHFIELDBOOK('wipe');SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
            assert(cvar and writes==3 and AzerothFieldbookDB.showSpellIDs)
            boot();assert(writes==3)
        ''')

    def test_unavailable_or_failing_client_api_keeps_saved_choice(self):
        lua = self.client()
        lua.execute('''
            GetCVarBool=function() error('unavailable') end
            SetCVar=function() error('unavailable') end
            journal():SetSpellIDTooltips(false);boot()
            assert(not AzerothFieldbookDB.showSpellIDs)
            GetCVarBool=nil;SetCVar=nil;boot()
            assert(not AzerothFieldbookDB.showSpellIDs)
        ''')


if __name__ == '__main__':
    unittest.main()
