"""Observed effect immunities and overridable, unverified type guidance."""
import unittest
from test_zone_colours import client

class EffectImmunityTests(unittest.TestCase):
    def test_effect_controls_summary_and_locking(self):
        lua=client()
        lua.execute(r'''
            for _,name in ipairs(ns.BestiaryImmunityEffects) do
                assert(j:SetImmunity(42,name,true))
                assert(e.immunities[name])
                assert(not j:SetResistance(42,name,true))
                assert(not j:SetOffense(42,name,true))
            end
            assert(not j:SetImmunity(42,'Made up',true))
            book:Refresh();section.refreshDefensePicker()
            local text='';for _,row in ipairs(section.summaryCombatRows) do text=text..row.text end
            assert(text:find('Fear',1,true) and text:find('Polymorph',1,true) and text:find('Bleed',1,true))
            assert(#section.defensePicker.effectRows==20)
            local row=section.defensePicker.effectRows[1]
            row.control:SetChecked(false);row.control.scripts.OnClick(row.control)
            assert(not e.immunities.Bleed)
            j:SetEntryConfirmed(42,true);section.refreshDefensePicker()
            assert(not j:SetImmunity(42,'Fear',false) and e.immunities.Fear)
        ''')

    def test_expected_mechanical_overrides_and_persistence(self):
        lua=client()
        lua.execute(r'''
            j:SetShowExpectedImmunities(true)
            e.category='Mechanical';e.personalEncountered=true
            local expected=j:GetExpectedImmunities(42)
            assert(expected.Bleed and expected.Fear and expected.Polymorph)
            assert(not e.immunities.Bleed and #ns.SharingReport.Candidates(e)==0,'type guidance is not a verified/shareable claim')
            book:Refresh();section.refreshDefensePicker()
            assert(section.defensePicker.effectRows[1].text.text=='Bleed [Type]')
            assert(j:SetImmunity(42,'Bleed',false))
            assert(not j:GetExpectedImmunities(42).Bleed and j:GetExpectedImmunities(42).Fear)
            j=ns.CreateBestiaryJournal(settings,function() return 42 end)
            assert(not j:GetExpectedImmunities(42).Bleed)
            local saved=assert(j:CaptureBackup())
            local decoded=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(saved))))
            assert(decoded.bestiary.entries[42].ignoredTypeImmunities.Bleed)
            assert(j:RestoreBackup(decoded))
            assert(not j:GetExpectedImmunities(42).Bleed)
            settings.accountWideTracking=true;local account=ns.InitializeTracking(settings)
            assert(account.bestiary.entries[42].ignoredTypeImmunities.Bleed)
            assert(j:SetImmunity(42,'Fear',true))
            assert(not j:GetExpectedImmunities(42).Fear and j.entries[42].immunities.Fear)
            j.entries[42].personalEncountered=false
            assert(not next(j:GetExpectedImmunities(42)),'shared category alone grants no assumptions')
        ''')

    def test_optional_polymorph_guidance_and_dropdown(self):
        lua=client()
        lua.execute(r'''
            e.category='Undead';e.personalEncountered=true
            assert(not j:GetShowExpectedImmunities() and not next(j:GetExpectedImmunities(42)))
            j:SetShowExpectedImmunities(true)
            for _,kind in ipairs({'Undead','Mechanical','Dragonkin','Demon','Elemental','Giant','Totem'}) do
                e.category=kind;assert(j:GetExpectedImmunities(42).Polymorph)
            end
            for _,kind in ipairs({'Humanoid','Beast','Critter','Unclassified','Not specified','Other'}) do
                e.category=kind;assert(not j:GetExpectedImmunities(42).Polymorph)
            end
            e.category='Undead';book:Refresh();section.refreshDefensePicker()
            local picker=section.defensePicker
            assert(not picker.effectMenu:IsShown() and picker:GetWidth()==593)
            picker.effectDropdown.scripts.OnClick(picker.effectDropdown)
            assert(picker.effectMenu:IsShown())
            assert(j:SetImmunity(42,'Polymorph',false) and not j:GetExpectedImmunities(42).Polymorph)
            j:SetShowExpectedImmunities(false);j:SetShowExpectedImmunities(true)
            assert(not j:GetExpectedImmunities(42).Polymorph and e.ignoredTypeImmunities.Polymorph)
            assert(j:SetImmunity(42,'Fear',true))
            j:SetShowExpectedImmunities(false)
            assert(e.immunities.Fear and not next(j:GetExpectedImmunities(42)))
            j=ns.CreateBestiaryJournal(settings,function() return 42 end)
            assert(not j:GetShowExpectedImmunities() and j.entries[42].immunities.Fear)
        ''')

    def test_report_roundtrip_and_explicit_rumour_confirmation(self):
        lua=client()
        lua.execute(r'''
            for _,name in ipairs({'Fear','Polymorph','Bleed'}) do assert(j:SetImmunity(42,name,true)) end
            local report=assert(ns.SharingReport.Capture(j,42))
            report.rumours=ns.SharingReport.Candidates(e)
            report.transaction='1000000-1-1';report.created=1000000;report.recipient='Alice Sunstrider'
            local decoded=assert(ns.SharingReport.Decode(assert(ns.SharingReport.Encode(report))))
            local receiver=ns.CreateBestiaryJournal({},function() return nil end)
            assert(receiver:ImportReport(decoded,'Bob Stonewell',1000000))
            local received=receiver.entries[42]
            assert(not received.immunities.Fear and #receiver:GetRumours(42)==3)
            while #receiver:GetRumours(42)>0 do assert(receiver:ConfirmRumour(42,receiver:GetRumours(42)[1])) end
            assert(received.immunities.Fear and received.immunities.Polymorph and received.immunities.Bleed)
        ''')

if __name__=='__main__':
    unittest.main()
