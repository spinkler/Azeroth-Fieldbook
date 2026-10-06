"""Client-verified dispositions are quiet, coloured basic information."""
import unittest
from test_discovery_rules import client
from ui_test_harness import new_ui_client


class DispositionTests(unittest.TestCase):
    def test_readable_reactions_update_basics_without_chat_events_or_behaviours(self):
        for reaction in (1, 2, 3, 4):
            with self.subTest(reaction=reaction):
                lua=client()
                lua.globals().reaction=reaction
                lua.execute('''
                    units.target=mob(5);fire('PLAYER_TARGET_CHANGED')
                    local log=journal:GetEventLog().entries
                    local notices,events=#messages,#log
                    function UnitReaction(unit,other) assert(unit=='target' and other=='player');return reaction end
                    tick()
                    local e=journal.entries[42]
                    assert(e.disposition==(reaction==4 and 'Neutral' or 'Hostile'))
                    assert(not e.behaviours.Hostile and not e.behaviours.Neutral)
                    assert(not e.behaviourSources or not next(e.behaviourSources))
                    assert(#log==events and #messages==notices and points()==0)
                    tick();tick();assert(#messages==notices and #log==events)
                ''')

    def test_locked_reactions_and_reload_remain_quiet_and_not_manually_editable(self):
        lua=client()
        lua.execute('''
            reaction=4;function UnitReaction() return reaction end
            units.target=mob(5);fire('PLAYER_TARGET_CHANGED')
            local e=journal.entries[42]
            assert(e.disposition=='Neutral')
            assert(not journal:SetBehaviour(42,'Neutral',false))
            assert(not journal:SetBehaviour(42,'Hostile',true))
            journal:SetEntryConfirmed(42,true);local snapshot=e.lockedBasic
            local n=#journal:GetEventLog().entries;local notices=#messages
            reaction=2;tick()
            assert(e.disposition=='Hostile' and e.confirmed and e.lockedBasic==snapshot)
            assert(#journal:GetEventLog().entries==n and #messages==notices)
            fire('ADDON_LOADED','AzerothFieldbook');tick()
            assert(journal.entries[42].disposition=='Hostile' and #journal:GetEventLog().entries==n)
        ''')

    def test_unknown_friendly_secret_and_changed_identity_do_not_guess(self):
        lua=client()
        lua.execute('''
            units.target=mob(5)
            for _,value in ipairs({secret,0,-1,1.5,5,6,7,8,9,0/0,math.huge,'hostile'}) do
                function UnitReaction() return value end
                fire('PLAYER_TARGET_CHANGED');assert(not journal.entries[42].disposition)
            end
            UnitReaction=nil;tick();assert(not journal.entries[42].disposition)
            UnitReaction=function() error('unavailable') end;tick();assert(not journal.entries[42].disposition)
            UnitReaction=function() units.target.guid='Creature-0-1-2-3-99-other';return 4 end
            tick();assert(not journal.entries[42].disposition)
        ''')

    def test_basic_colours_picker_removal_backup_merge_and_sharing_isolation(self):
        lua=new_ui_client(['SharingReport.lua','BestiaryBackups.lua','BestiaryJournal.lua','Tracking.lua',
            'Scrollbars.lua','ActionButtons.lua','WindowFocus.lua','WindowPositions.lua','UIScale.lua',
            'FieldbookShell.lua','BestiaryPages.lua','BestiaryBook.lua'])
        lua.execute('''
            local settings={accountWideTracking=false};local j=ns.CreateBestiaryJournal(settings,function() return 42 end)
            reaction=4;function UnitReaction() return reaction end
            FACTION_BAR_COLORS={[2]={r=0.8,g=0.13,b=0.13},[4]={r=0.9,g=0.7,b=0}}
            local book=ns.CreateBestiaryBook(j);book:OpenAtUnit('target')
            local section=AzerothFieldbookBestiarySection
            for _,c in ipairs(section.behaviourPicker.controls) do
                assert(c.behaviourName~='Neutral' and c.behaviourName~='Hostile')
            end
            local function text(rows)
                local result='';for _,row in ipairs(rows) do if row:IsShown() then result=result..row.text end end;return result
            end
            assert(not text(section.summaryBasicRows):find('Neutral',1,true))
            assert(section.title.textColor[1]==0.9,'neutral disposition colours the creature name')
            assert(not text(section.summaryCombatRows):find('Neutral',1,true))
            j:SetEntryConfirmed(42,true);reaction=2;j:Observe('target');book:Refresh()
            assert(j:GetBasicInfo(42).disposition=='Hostile')
            assert(not text(section.summaryBasicRows):find('Hostile',1,true))
            assert(section.title.textColor[1]==0.8,'hostile disposition colours the creature name')
            j:SetDispositionNameColour(false);book:Refresh()
            assert(text(section.summaryBasicRows):find('Hostile',1,true),'turning the option off restores hostility text')
            local saved=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(assert(j:CreateBackup())))))
            assert(saved.bestiary.entries[42].disposition=='Hostile');assert(j:RestoreBackup(saved))
            settings.accountWideTracking=true;local account=ns.InitializeTracking(settings)
            assert(account.bestiary.entries[42].disposition=='Hostile')
            local other={accountWideTracking=false};local j2=ns.CreateBestiaryJournal(other,function() return 42 end)
            reaction=4;j2:Observe('target');other.accountWideTracking=true;ns.InitializeTracking(other)
            assert(account.bestiary.entries[42].disposition=='Hostile','existing account value wins until fresh observation')
            local captured,candidates=ns.SharingReport.Capture(j,42)
            assert(captured and not captured.disposition)
            for _,claim in ipairs(candidates) do assert(claim.value~='Hostile' and claim.value~='Neutral') end
            saved.bestiary.entries[42].disposition='Friendly'
            assert(not ns.BestiaryBackups.Validate(saved))
        ''')

    def test_legacy_migration_only_promotes_unambiguous_client_evidence(self):
        lua=client()
        lua.execute('''
            units.target=mob(5);fire('PLAYER_TARGET_CHANGED')
            local e=journal.entries[42]
            e.behaviours={Neutral=true,['Flees at low health']=true}
            e.behaviourSources={Neutral='unitReaction',['Flees at low health']='monsterEmote'}
            e.ignoredBehaviours={Hostile=true}
            e.rumours={{kind='behaviour',value='Hostile'},{kind='behaviour',value='Patrols'}}
            local n=#journal:GetEventLog().entries
            fire('ADDON_LOADED','AzerothFieldbook');e=journal.entries[42]
            assert(e.disposition=='Neutral' and not e.behaviours.Neutral and not e.behaviourSources.Neutral)
            assert(not e.ignoredBehaviours.Hostile and #e.rumours==1 and e.rumours[1].value=='Patrols')
            assert(e.behaviours['Flees at low health'] and e.behaviourSources['Flees at low health']=='monsterEmote')
            assert(#journal:GetEventLog().entries==n)
            for _,legacy in ipairs({
                {personalEncountered=true,behaviours={Hostile=true}},
                {personalEncountered=true,behaviours={Hostile=true,Neutral=true},behaviourSources={Hostile='unitReaction',Neutral='unitReaction'}},
                {behaviours={Hostile=true},behaviourSources={Hostile='unitReaction'}}
            }) do ns.MigrateDisposition(legacy);assert(not legacy.disposition and not next(legacy.behaviours)) end
        ''')


if __name__=='__main__':
    unittest.main()
