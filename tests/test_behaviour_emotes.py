"""GUID-bound monster emotes, automatic provenance and durable manual choices."""
import unittest
from kill_test_harness import ROOT
from test_discovery_rules import client
from ui_test_harness import new_ui_client


def emote_client():
    lua = client()
    lua.execute('''
        units.target=mob(5);fire('PLAYER_TARGET_CHANGED')
        function flee(message,sender,guid,event)
            fire(event or 'CHAT_MSG_MONSTER_EMOTE',message,sender,'','','','',0,0,'',0,1,guid)
        end
        creatureGUID=units.target.guid
        function automatic()
            local e=journal.entries[42]
            return e.behaviours['Flees at low health'] and e.behaviourSources['Flees at low health']=='monsterEmote'
        end
    ''')
    return lua


class BehaviourEmoteTests(unittest.TestCase):
    def test_call_for_help_uses_flee_identity_and_recording_rules(self):
        for prefix in ('%s', 'Test creature'):
            for guid in ('creatureGUID', 'nil'):
                with self.subTest(prefix=prefix, guid=guid):
                    lua = emote_client()
                    lua.globals().emote = prefix + ' lets out a high pitched screech, calling for help!'
                    lua.execute("""
                        local e=journal.entries[42];e.confirmed=true;messages={}
                        local balance=points()
                    """ + f"flee(emote,'Test creature',{guid})" + """
                        local e=journal.entries[42]
                        assert(e.behaviours['Calls allies'] and e.behaviourSources['Calls allies']=='monsterEmote')
                        assert(not e.behaviours['Flees at low health'])
                        assert(#messages==1 and messages[1]:find('Calls allies',1,true))
                        local events=journal:GetEventLog().entries
                        assert(events[#events].details.source=='monsterEmote')
                        local revision=journal.revision
                        flee(emote,'Test creature',creatureGUID)
                        assert(journal.revision==revision and #messages==1)
                        fire('ADDON_LOADED','AzerothFieldbook')
                        assert(journal.entries[42].behaviourSources['Calls allies']=='monsterEmote')
                    """)

    def test_call_for_help_rejects_unverified_speakers_and_other_chat(self):
        lua = emote_client()
        lua.execute("""
            local message='%s lets out a high pitched screech, calling for help!'
            flee(message,'Test creature',creatureGUID,'CHAT_MSG_SAY')
            flee(message,'Test creature',secret)
            flee(message,'Other creature',creatureGUID)
            flee(message..' says a player','Test creature',creatureGUID)
            flee('Other creature lets out a high pitched screech, calling for help!','Test creature',creatureGUID)
            units.mouseover=spawn('other',false);units.mouseover.guid='Creature-0-1-2-3-43-other'
            flee(message,'Test creature',nil)
            units.target=nil;units.mouseover=nil
            flee(message,'Test creature',nil)
            journal.entries[42].personalEncountered=false
            flee(message,'Test creature',creatureGUID)
            assert(not journal.entries[42].behaviours['Calls allies'])
            assert(not journal.entries[43])
        """)

    def test_exact_server_text_and_guid_identify_an_existing_personal_creature(self):
        for message in ('%s attempts to run away in fear!', 'Test creature attempts to run away in fear!'):
            with self.subTest(message=message):
                lua = emote_client()
                lua.globals().emote = message
                lua.execute('''
                    units.target=nil -- The speaker need not still be targeted.
                    local balance=points()
                    flee(emote,'Test creature',creatureGUID)
                    assert(automatic() and points()==balance)
                    local revision=journal.revision
                    flee(emote,'Test creature',creatureGUID);assert(journal.revision==revision)
                    fire('ADDON_LOADED','AzerothFieldbook');assert(automatic())
                ''')

    def test_unrelated_ambiguous_and_restricted_chat_cannot_record_behaviour(self):
        lua = emote_client()
        lua.execute('''
            local message='%s attempts to run away in fear!'
            flee(message,'Test creature',creatureGUID,'CHAT_MSG_SAY')
            flee(message,'Test creature',creatureGUID,'CHAT_MSG_TEXT_EMOTE')
            for _,bad in ipairs({secret,'Player-1-1','Pet-0-1-2-3-42-pet','Creature-0-1-2-3-43-other'}) do
                flee(message,'Test creature',bad)
            end
            local target=units.target;units.target=nil
            flee(message,'Test creature',nil)
            flee(message,'Test creature','')
            units.target=target
            flee(secret,'Test creature',creatureGUID)
            flee(message,secret,creatureGUID)
            flee(message,'Other creature',creatureGUID)
            flee('Other creature attempts to run away in fear!','Test creature',creatureGUID)
            flee('Test creature attempts to run away in fear! says a player','Test creature',creatureGUID)
            flee('%s flees in fear!','Test creature',creatureGUID)
            assert(not journal.entries[42].behaviours['Flees at low health'])
            assert(not journal.entries[43],'chat never creates new entries')
        ''')

    def test_missing_guid_uses_matching_watched_creature_and_announces_once(self):
        for unit in ('target', 'mouseover'):
            for guid in ('nil', "''"):
                with self.subTest(unit=unit, guid=guid):
                    lua = emote_client()
                    lua.execute(f"units.{unit}=units.target")
                    if unit == 'mouseover':
                        lua.execute('units.target=nil')
                    lua.execute('''
                        messages={}
                        AzerothFieldbookDB.creatureAnnouncements=false
                        AzerothFieldbookDB.pointAnnouncements=false
                    ''')
                    lua.execute(f"flee('  %s attempts to run away in fear!  ','Test creature',{guid})")
                    lua.execute('''
                        assert(automatic() and #messages==1)
                        assert(messages[1]:find('Automatically recorded: Flees at low health',1,true))
                        assert(messages[1]:find('[A]',1,true) and messages[1]:find('Test creature',1,true))
                        local events=journal:GetEventLog().entries
                        assert(#events==2 and events[2].details.kind=='behaviour')
                        assert(events[2].details.source=='monsterEmote' and events[2].details.identity=='watched creature')
                        assert(events[2].details.creatureID==42)
                        flee('%s attempts to run away in fear!','Test creature',nil)
                        assert(#events==2 and #messages==1,'repeated emotes do not spam')
                        fire('ADDON_LOADED','AzerothFieldbook');messages={}
                        flee('%s attempts to run away in fear!','Test creature',nil)
                        assert(#events==2 and #messages==0,'reload cannot repeat automatic discovery')
                    ''')

    def test_fallback_rejects_ambiguous_names_and_ineligible_units(self):
        lua = emote_client()
        lua.execute('''
            local message='%s attempts to run away in fear!'
            units.mouseover=spawn('other',false);units.mouseover.guid='Creature-0-1-2-3-43-other'
            flee(message,'Test creature',nil)
            assert(not journal.entries[42].behaviours['Flees at low health'])
            units.mouseover=nil
            journal:Ensure(43,false,'Test creature')
            flee(message,'Test creature','')
            assert(not journal.entries[42].behaviours['Flees at low health'])
            journal:DeleteEntry(43)
            units.target.controlled=true;flee(message,'Test creature',nil)
            units.target.controlled=false;units.target.attackable=false;flee(message,'Test creature',nil)
            units.target.attackable=true;units.target.name=secret;flee(message,'Test creature',nil)
            assert(not journal.entries[42].behaviours['Flees at low health'])
            units.target.name='Test creature';flee(message,'Test creature',creatureGUID)
            assert(automatic(),'valid GUID remains authoritative after earlier ambiguous events')
        ''')

    def test_locked_additions_and_reapplications_log_once_manual_toggles_are_silent(self):
        lua = emote_client()
        lua.execute('''
            local message='%s attempts to run away in fear!'
            local e=journal.entries[42];messages={}
            e.confirmed=true;flee(message,'Test creature',creatureGUID)
            assert(automatic() and e.confirmed and #messages==1 and #journal:GetEventLog().entries==2)
            assert(not journal:SetBehaviour(42,'Flees at low health',false),'lock still protects manual edits')
            flee(message,'Test creature',creatureGUID)
            e.confirmed=false
            journal:SetBehaviour(42,'Flees at low health',false)
            journal:SetBehaviour(42,'Flees at low health',true)
            assert(automatic() and #messages==1 and #journal:GetEventLog().entries==2)
            flee(message,'Test creature',creatureGUID)
            assert(#messages==1 and #journal:GetEventLog().entries==2)
            assert(journal:GetEventLog().entries[2].details.identity=='event GUID')
            journal:SetBehaviour(42,'Flees at low health',false);e.confirmed=true
            flee(message,'Test creature',creatureGUID)
            assert(automatic() and #messages==2 and #journal:GetEventLog().entries==3)
            flee(message,'Test creature',creatureGUID)
            assert(#messages==2 and #journal:GetEventLog().entries==3)
        ''')

    def test_debug_report_explains_rejections_without_raw_restricted_data(self):
        lua = emote_client()
        lua.execute('''
            ns.ShowDebugReport=function(text) debugReport=text end
            flee(secret,'Test creature',creatureGUID)
            SlashCmdList.AZEROTHFIELDBOOK('debug')
            assert(debugReport:find('1 monster emotes; 0 readable behaviour messages; 0 behaviours added',1,true))
            assert(debugReport:find('Emote text is restricted.',1,true))
            flee('%s attempts to run away in fear!','Test creature',secret)
            SlashCmdList.AZEROTHFIELDBOOK('debug')
            assert(debugReport:find('Emote GUID is restricted.',1,true))
            journal.entries[42].personalEncountered=false
            flee('%s attempts to run away in fear!','Test creature',nil)
            SlashCmdList.AZEROTHFIELDBOOK('debug')
            assert(debugReport:find('Emote speaker has no personal entry.',1,true))
            journal.entries[42].personalEncountered=true
            journal:SetBehaviour(42,'Flees at low health',false)
            flee('%s attempts to run away in fear!','Test creature',nil)
            flee('%s laughs.','Test creature',creatureGUID)
            SlashCmdList.AZEROTHFIELDBOOK('debug')
            assert(debugReport:find('Last readable behaviour: Recorded Flees at low health using watched creature.',1,true))
            assert(debugReport:find('Last monster emote: Not a supported behaviour emote.',1,true))
        ''')

    def test_manual_toggles_retain_history_and_fresh_evidence_reapplies_after_reload(self):
        lua = emote_client()
        lua.execute('''
            local name='Flees at low health';local e=journal.entries[42]
            flee('%s attempts to run away in fear!','Test creature',creatureGUID);assert(automatic())
            assert(journal:SetBehaviour(42,name,false))
            assert(not e.behaviours[name] and e.behaviourSources[name]=='monsterEmote' and e.ignoredBehaviours[name])
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(not e.behaviours[name])
            journal:SetBehaviour(42,name,true)
            assert(automatic() and not e.ignoredBehaviours[name])
            local events=#journal:GetEventLog().entries
            flee('%s attempts to run away in fear!','Test creature',creatureGUID)
            assert(automatic() and #journal:GetEventLog().entries==events)
            journal:SetBehaviour(42,name,false);fire('ADDON_LOADED','AzerothFieldbook');messages={}
            flee('%s attempts to run away in fear!','Test creature',creatureGUID)
            assert(automatic() and not e.ignoredBehaviours[name])
            assert(#messages==1 and #journal:GetEventLog().entries==events+1)
            -- Older versions erased provenance and left permanent ignore flags.
            e.behaviours[name]=nil;e.behaviourSources=nil;e.ignoredBehaviours[name]=true
            flee('%s attempts to run away in fear!','Test creature',creatureGUID)
            assert(automatic() and not e.ignoredBehaviours[name])
        ''')

    def test_shared_only_and_wiped_entries_are_protected(self):
        lua = emote_client()
        lua.execute('''
            local e=journal.entries[42];e.confirmed=true;e.personalEncountered=false
            flee('%s attempts to run away in fear!','Test creature',creatureGUID)
            assert(not e.behaviours['Flees at low health'])
            e.personalEncountered=true
            SlashCmdList.AZEROTHFIELDBOOK('wipe');SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
            flee('%s attempts to run away in fear!','Test creature',creatureGUID)
            assert(not journal.entries[42])
        ''')

    def test_backups_merge_historical_provenance_and_shared_rumours(self):
        lua = new_ui_client(['SharingReport.lua','BestiaryBackups.lua','BestiaryJournal.lua','Tracking.lua'])
        lua.execute('''
            local name='Flees at low health';local guid='Creature-0-1-2-3-42-1'
            local function character(automatic,enabled)
                local db={accountWideTracking=false}
                local j=ns.CreateBestiaryJournal(db,function() return 42 end);j:Observe('target')
                if automatic then assert(j:RecordMonsterEmote('%s attempts to run away in fear!','Creature 42',guid))
                else j:SetBehaviour(42,name,enabled) end
                return db,j
            end
            local db,j=character(true)
            local backup=assert(j:CreateBackup())
            local decoded=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(backup))))
            eq(decoded.bestiary.entries[42].behaviourSources[name],'monsterEmote')
            assert(j:RestoreBackup(decoded))
            local capture,candidates=ns.SharingReport.Capture(j,42)
            assert(not capture.behaviourSources,'local provenance never claims automatic evidence for a recipient')
            local found=false;for _,claim in ipairs(candidates) do
                if claim.kind=='behaviour' and claim.value==name then found=true end
            end;assert(found)
            db.accountWideTracking=true;local account=ns.InitializeTracking(db)
            eq(account.bestiary.entries[42].behaviourSources[name],'monsterEmote')
            local other,j2=character(false,false)
            other.accountWideTracking=true;ns.InitializeTracking(other)
            local merged=account.bestiary.entries[42]
            assert(not merged.behaviours[name] and merged.behaviourSources[name]=='monsterEmote' and merged.ignoredBehaviours[name])
            local copy,j3=character(true);copy.accountWideTracking=true;ns.InitializeTracking(copy)
            assert(not merged.behaviours[name],'automatic import cannot undo manual removal')
            -- Previously witnessed automatic evidence survives a manual positive record.
            AzerothFieldbookAccountDB=nil
            local manual,j4=character(false,true);manual.accountWideTracking=true
            account=ns.InitializeTracking(manual)
            local auto,j5=character(true);auto.accountWideTracking=true;ns.InitializeTracking(auto)
            assert(account.bestiary.entries[42].behaviours[name] and account.bestiary.entries[42].behaviourSources[name]=='monsterEmote')
            j2:SetBehaviour(42,name,false)
            local ignored=assert(j2:CreateBackup())
            assert(ignored.bestiary.entries[42].ignoredBehaviours[name])
            decoded.bestiary.entries[42].behaviours[name]=nil
            assert(ns.BestiaryBackups.Validate(decoded,true),'historical provenance survives an inactive mark')
            decoded.bestiary.entries[42].behaviourSources[name]='invalid source'
            assert(not ns.BestiaryBackups.Validate(decoded,true),'unknown provenance source is invalid')
            -- An unchecked automatic observation is valid historical evidence.
            j:SetBehaviour(42,name,false)
            local off=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(assert(j:CreateBackup())))))
            assert(off.bestiary.entries[42].behaviourSources[name]=='monsterEmote')
            assert(not off.bestiary.entries[42].behaviours[name] and off.bestiary.entries[42].ignoredBehaviours[name])
            assert(j:RestoreBackup(off));j:SetBehaviour(42,name,true)
            assert(j.entries[42].behaviourSources[name]=='monsterEmote')
        ''')

    def test_summary_picker_tooltip_and_manual_toggle_show_provenance(self):
        lua = new_ui_client(['Scrollbars.lua','ActionButtons.lua','WindowFocus.lua','WindowPositions.lua','UIScale.lua',
            'SharingReport.lua','BestiaryJournal.lua','FieldbookShell.lua','BestiaryPages.lua','BestiaryBook.lua'])
        lua.execute('''
            local j=ns.CreateBestiaryJournal({},function() return 42 end)
            local book=ns.CreateBestiaryBook(j);book:OpenAtUnit('target')
            local content=AzerothFieldbookBestiarySection;local picker=content.behaviourPicker
            picker:Show();local check
            for _,control in ipairs(picker.controls) do if control.behaviourName=='Flees at low health' then check=control end end
            assert(j:RecordMonsterEmote('%s attempts to run away in fear!','Creature 42','Creature-0-1-2-3-42-1'))
            book:Refresh()
            assert(check:GetChecked() and check.text.text=='|cff80d0ffFlees at low health [A]|r')
            local summary=false
            for _,o in ipairs(objects) do
                if type(o.text)=='string' and o.text:find('Behaviour: |cff80d0ffFlees at low health [A]|r',1,true) then summary=true end
            end;assert(summary)
            local lines={};GameTooltip={SetOwner=function() end,SetText=function() end,
                AddLine=function(_,line) lines[#lines+1]=line end,Show=function() end,Hide=function() end}
            check.scripts.OnEnter(check);assert(lines[1]:find("creature's flee emote",1,true))
            check:SetChecked(false);check.scripts.OnClick(check)
            assert(not j.entries[42].behaviours['Flees at low health'] and check.text.text=='|cff80d0ffFlees at low health [A]|r')
            check:SetChecked(true);check.scripts.OnClick(check)
            assert(j.entries[42].behaviours['Flees at low health'] and check.text.text=='|cff80d0ffFlees at low health [A]|r')
        ''')


if __name__ == '__main__':
    unittest.main()
