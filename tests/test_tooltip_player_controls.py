"""Master tooltip and independent feedback settings through runtime paths."""
import unittest
from test_loss_of_control import client

class Controls(unittest.TestCase):
    def test_master_defaults_and_saved_individual_choices(self):
        lua=client()
        lua.execute("""
            function GetCVarBool() return tooltipIDs end
            function SetCVar(_, value) tooltipIDs=value=="1" end
            assert(journal:GetTooltips() and not journal:GetSpellFeedback())
            journal:SetSpellIDTooltips(true)
            journal:SetTooltips(false)
            assert(not journal:GetTooltips() and journal:GetSpellIDTooltips())
            assert(not tooltipIDs)
            journal:SetTooltips(true)
            assert(tooltipIDs and journal:GetTooltips())
            journal:SetSpellIDTooltips(false)
            journal:SetTooltips(false);journal:SetTooltips(true)
            assert(not tooltipIDs and not journal:GetSpellIDTooltips())
        """)

    def test_automatic_spell_announcements_are_opt_in(self):
        lua=client()
        lua.execute("""
            apply(nil,nil,10)
            assert(ability() and not output():find("Spell ID",1,true))
            messages={}
            journal:SetSpellFeedback(true)
            auras[11]={auraInstanceID=11,sourceUnit='nameplate1'}
            apply('ROOT',54321,11)
            assert(#messages==1 and output():find('54321',1,true))
        """)

    def test_verified_feedback_is_independent_of_discovery(self):
        lua=client()
        lua.execute("""
            journal:SetAutoRecordAbilities(false)
            apply(nil,nil,10)
            assert(#displayed==1 and fallbackCount()==0)
            journal:SetSpellFeedback(true)
            active={};fire('LOSS_OF_CONTROL_UPDATE','player');clock=clock+3
            apply(nil,nil,10)
            assert(fallbackCount()==1)
            units.nameplate1.controlled=true
            active={effect('STUN',999,10)};fire('LOSS_OF_CONTROL_UPDATE','player')
            assert(fallbackCount()==1 and #displayed==2 and not ability())
        """)

if __name__ == '__main__': unittest.main()
