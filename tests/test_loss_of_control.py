"""Player LOC through the real addon event, identity, storage and UI paths."""
import unittest

from kill_test_harness import ROOT, new_client
from ui_test_harness import new_ui_client


TYPES = ['STUN', 'STUN_MECHANIC', 'FEAR', 'FEAR_MECHANIC', 'ROOT', 'CHARM',
         'CONFUSE', 'POSSESS', 'SILENCE', 'PACIFY', 'PACIFYSILENCE', 'DISARM',
         'SCHOOL_INTERRUPT', 'ASTRA_TEST_FUTURE_LOC']


def client(account=False):
    lua = new_client(tracking=account, initialize=False)
    for name in ['SharingReport.lua', 'BestiaryBackups.lua', 'BestiaryBuffs.lua', 'LossOfControl.lua']:
        lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute('''
        local create=ns.CreateBestiaryJournal
        ns.CreateBestiaryJournal=function(...) journal=create(...);return journal end
        function time() return 1790400000 end
        function InCombatLockdown() return combat end
        combat=true
        units.player={combat=true,controlled=true}
        units.nameplate1=spawn('source',false);units.nameplate1.name='Creature A'
        units.target=spawn('target',false);units.target.name='Creature B'
        units.target.guid='Creature-0-1-2-3-43-target'
        active,auras,displayed={},{},{}
        auraReads=0
        C_LossOfControl={GetActiveLossOfControlDataCount=function() return #active end,
            GetActiveLossOfControlData=function(index) return active[index] end}
        C_UnitAuras={GetAuraDataByAuraInstanceID=function(unit,id)
            assert(unit=='player' and not issecretvalue(id));auraReads=auraReads+1;return auras[id]
        end}
        C_Spell={GetSpellName=function(id)
            assert(not issecretvalue(id));if id==12345 then return 'Disarming Smash' end
        end}
        ns.SpellIDWindow={Initialize=function() end,ObserveLossOfControl=function(_,id,name,effect,caster,token,candidate)
            displayed[#displayed+1]={id=id,name=name,effect=effect,caster=caster,token=token,candidate=candidate};return true
        end}
        function effect(kind,id,aura)
            return {locType=kind or 'DISARM',spellID=id or 12345,displayText='Disarm',
                auraInstanceID=aura,startTime=clock,duration=5,timeRemaining=5,lockoutSchool=0}
        end
        function apply(kind,id,aura)
            active={effect(kind,id,aura)};fire('LOSS_OF_CONTROL_ADDED','player',1)
        end
        function fallbackCount()
            local n=0;for _,v in ipairs(messages) do if v:find('Loss of Control detected',1,true) then n=n+1 end end;return n
        end
        function ability(id,spell)
            local e=journal.entries[id or 42]
            for _,a in pairs(e and e.abilities or {}) do if a.spellID==(spell or 12345) then return a end end
        end
        function abilityCount(id)
            local n=0;for _ in pairs(journal.entries[id].abilities) do n=n+1 end;return n
        end
        function publicTree(v)
            assert(not issecretvalue(v),'saved secret')
            if type(v)=='table' then for k,x in pairs(v) do publicTree(k);publicTree(x) end end
        end
        auras[10]={auraInstanceID=10,sourceUnit='nameplate1',spellId=12345}
        fire('ADDON_LOADED','AzerothFieldbook');messages={}
    ''')
    return lua


class LossOfControlTests(unittest.TestCase):
    def test_manual_portrait_assignment_keeps_captured_target(self):
        lua = client()
        lua.execute('''
            auras={};apply(nil,nil,10)
            local candidate=displayed[1].candidate
            assert(candidate.id==43 and candidate.name=='Creature B')
            assert(not next(journal.entries),'capturing a target must not mutate the Bestiary')
            units.target=units.nameplate1
            fire('LOSS_OF_CONTROL_UPDATE','player')
            assert(#displayed==1 and candidate.assign())
            assert(ability(43).state=='confirmed' and ability(43).origin=='Your note')
            assert(not ability(43).playerLossOfControl and not ability(42))
            local revision=journal.revision;assert(candidate.assign())
            assert(journal.revision==revision and abilityCount(43)==1)
            local log=journal:GetEventLog().entries
            assert(log[#log].details.kind=='manual Loss of Control')
            assert(log[#log].details.creatureID==43);publicTree(AzerothFieldbookDB)
        ''')

    def test_manual_assignment_without_name_or_automatic_recording(self):
        lua = client()
        lua.execute('''
            journal:SetAutoRecordAbilities(false)
            auras={};apply('ROOT',54321,10)
            local candidate=displayed[1].candidate;units.target=nil
            assert(candidate.assign())
            local a=journal.entries[43].abilities['Spell ID 54321']
            assert(a.state=='confirmed' and a.origin=='Your note' and not a.playerLossOfControl)
        ''')

    def test_manual_assignment_preserves_notes_and_deduplicates_by_id(self):
        lua = client()
        lua.execute('''
            journal:Ensure(43,false,'Creature B')
            local entry=journal.entries[43]
            entry.abilities['Custom name']={spellID=12345,state='pending',origin='Report',note='Keep this',effects={Disarm=true},showInTooltip=false}
            auras={};apply(nil,nil,10)
            assert(displayed[1].candidate.assign())
            local a=entry.abilities['Custom name']
            assert(abilityCount(43)==1 and a.state=='confirmed' and a.origin=='Your note')
            assert(a.note=='Keep this' and a.effects.Disarm and a.showInTooltip==false and not a.playerLossOfControl)
            active={};fire('LOSS_OF_CONTROL_UPDATE','player');clock=clock+4
            a.origin='Automatic cast observation';a.playerLossOfControl=true
            apply(nil,nil,11);assert(displayed[2].candidate.assign())
            assert(a.origin=='Automatic cast observation' and a.playerLossOfControl and abilityCount(43)==1)
        ''')

    def test_manual_assignment_respects_lock_reset_and_deleted_entry(self):
        for change in ('lock', 'reset', 'delete', 'blocked'):
            with self.subTest(change=change):
                lua = client();lua.globals().change=change
                lua.execute('''
                    journal:Ensure(43,false,'Creature B');auras={};apply(nil,nil,10)
                    local candidate=displayed[1].candidate
                    if change=='lock' then journal:SetEntryConfirmed(43,true)
                    elseif change=='reset' then journal:Reset()
                    elseif change=='delete' then journal:DeleteEntry(43)
                    else ns.InitializationBlocked=true end
                    local revision=journal.revision
                    assert(not candidate.assign() and not ability(43))
                    assert(journal.revision==revision)
                ''')

    def test_portrait_target_identity_restrictions_and_capture_race(self):
        for change in ('absent', 'controlled', 'guid', 'name', 'race'):
            with self.subTest(change=change):
                lua = client();lua.globals().change=change
                lua.execute('''
                    auras={}
                    if change=='absent' then units.target=nil
                    elseif change=='controlled' then units.target.controlled=true
                    elseif change=='guid' then units.target.guid=secret
                    elseif change=='name' then units.target.name=secret
                    else UnitName=function() units.target=units.nameplate1;return 'Creature B' end end
                    apply(nil,nil,10)
                    assert(not displayed[1].candidate and not next(journal.entries))
                    publicTree(AzerothFieldbookDB)
                ''')

    def test_verified_source_replaces_unverified_target_action(self):
        lua = client()
        lua.execute('''
            local aura=auras[10];auras={};apply(nil,nil,10)
            assert(displayed[1].candidate.id==43)
            auras[10]=aura;fire('UNIT_AURA','player',{})
            assert(#displayed==2 and not displayed[2].candidate and displayed[2].caster=='Creature A')
            assert(ability(42) and not ability(43))
        ''')

    def test_attribution_discovers_source_not_target_and_deduplicates(self):
        lua = client()
        lua.execute('''
            apply(nil,nil,10)
            assert(ability() and ability().playerLossOfControl and abilityCount(42)==1)
            assert(journal.entries[42].name=='Creature A' and not journal.entries[43])
            assert(not journal.entries[42].idNotes)
            assert(displayed[1].id==12345 and displayed[1].caster=='Creature A' and not displayed[1].candidate)
            assert(fallbackCount()==0)
            local rev=journal.revision;local count=#messages
            fire('LOSS_OF_CONTROL_UPDATE','player');fire('LOSS_OF_CONTROL_ADDED','player',1)
            fire('UNIT_AURA','player',{addedAuras={auras[10]}})
            assert(journal.revision==rev and #messages==count and #displayed==1)
            assert(abilityCount(42)==1);publicTree(AzerothFieldbookDB)
        ''')

    def test_missing_source_does_not_mutate_current_or_previous_target(self):
        lua = client()
        lua.execute('''
            fire('PLAYER_TARGET_CHANGED');local rev=journal.revision
            auras={};apply(nil,nil,10)
            assert(journal.revision==rev and not ability(43) and not journal.entries[42])
            assert(fallbackCount()==1 and output():find('12345',1,true) and output():find('Disarm',1,true))
            fire('LOSS_OF_CONTROL_UPDATE','player');assert(fallbackCount()==1)
            units.target=nil;fire('LOSS_OF_CONTROL_UPDATE','player');assert(fallbackCount()==1)
        ''')

    def test_target_switch_race_and_no_target(self):
        for source in (True, False):
            lua = client();lua.globals().hasSource=source
            lua.execute('''
                local other=units.target
                units.target=units.nameplate1;fire('PLAYER_TARGET_CHANGED')
                active={effect('DISARM',12345,10)}
                units.target=other;fire('PLAYER_TARGET_CHANGED')
                if not hasSource then auras[10].sourceUnit=nil end
                fire('LOSS_OF_CONTROL_ADDED','player',1)
                assert(not ability(43))
                assert((ability()~=nil)==hasSource)
                units.target=nil;active={effect('ROOT',9876,11)}
                auras[11]={auraInstanceID=11,sourceUnit='nameplate1'}
                fire('LOSS_OF_CONTROL_UPDATE','player')
                assert(ability(42,9876) and ability(42,9876).playerLossOfControl)
            ''')

    def test_all_types_and_future_type_with_and_without_source(self):
        for kind in TYPES:
            for source in (True, False):
                with self.subTest(kind=kind, source=source):
                    lua = client();lua.globals().kind=kind;lua.globals().hasSource=source
                    lua.execute('''
                        active={effect(kind,12345,hasSource and 10 or nil)}
                        active[1].displayText=nil
                        fire('LOSS_OF_CONTROL_UPDATE','player')
                        assert(displayed[1].effect==kind and displayed[1].id==12345)
                        assert((ability()~=nil)==hasSource)
                        assert(fallbackCount()==(hasSource and 0 or 1))
                    ''')

    def test_aura_payload_only_exact_correlation_and_full_updates(self):
        lua = client()
        lua.execute('''
            active={effect('DISARM',12345,10)}
            C_UnitAuras.GetAuraDataByAuraInstanceID=function() error('denied') end
            fire('UNIT_AURA','player',{addedAuras={secret,auras[10]}})
            assert(ability() and auraReads==0 and fallbackCount()==0)
            active={effect('ROOT',4321,11)}
            fire('UNIT_AURA','player',{isFullUpdate=true,addedAuras={{auraInstanceID=11,sourceUnit='nameplate1'}}})
            assert(not ability(42,4321) and fallbackCount()==1)
            fire('UNIT_AURA','player',{addedAuras={{auraInstanceID=999,sourceUnit='nameplate1'}}})
            assert(not ability(42,4321) and fallbackCount()==1)
            C_UnitAuras.GetAuraDataByAuraInstanceID=function(_,id) return {auraInstanceID=id,sourceUnit='nameplate1'} end
            fire('UNIT_AURA','player',{isFullUpdate=true})
            assert(ability(42,4321) and fallbackCount()==1)
        ''')

    def test_added_before_aura_can_upgrade_but_aura_token_is_never_cached(self):
        lua = client()
        lua.execute('''
            auras={};apply(nil,nil,10);assert(fallbackCount()==1)
            fire('UNIT_AURA','player',{addedAuras={{auraInstanceID=10,sourceUnit='nameplate1'}}})
            assert(ability() and fallbackCount()==1 and #displayed==2)
            active={};fire('LOSS_OF_CONTROL_UPDATE','player')
            fire('UNIT_AURA','player',{addedAuras={{auraInstanceID=20,sourceUnit='target'}}})
            units.target=units.nameplate1
            active={effect('STUN',8765,20)};fire('LOSS_OF_CONTROL_ADDED','player',1)
            assert(not ability(42,8765) and not ability(43,8765))
        ''')

    def test_several_effects_same_spell_and_no_aura_timing(self):
        lua = client()
        lua.execute('''
            auras={};active={effect('STUN',12345,10),effect('SILENCE',12345,11),effect('SCHOOL_INTERRUPT',999)}
            active[3].startTime=nil;active[3].duration=nil;active[3].timeRemaining=nil
            fire('LOSS_OF_CONTROL_UPDATE','player');assert(fallbackCount()==3)
            for i=1,20 do clock=clock+10;fire('LOSS_OF_CONTROL_UPDATE','player') end
            assert(fallbackCount()==3 and not next(journal.entries))
            active={};fire('LOSS_OF_CONTROL_UPDATE','player');clock=clock+3
            active={effect('SCHOOL_INTERRUPT',999)};active[1].startTime=nil;active[1].duration=nil
            fire('LOSS_OF_CONTROL_ADDED','player',1);assert(fallbackCount()==4)
        ''')

    def test_secret_and_invalid_fields_fail_closed(self):
        fixtures = [
            'active[1].spellID=secret', 'active[1]=secret',
            'auras[10]=secret', 'auras[10].sourceUnit=secret',
            'auras[10].auraInstanceID=secret', 'units.nameplate1.guid=secret',
            'units.nameplate1.controlled=secret', 'units.nameplate1.attackable=secret',
            'units.nameplate1.name=secret', 'units.nameplate1=nil',
            "auras[10].sourceUnit='player'", "auras[10].sourceUnit='party1'",
            "units.nameplate1.guid='Player-1-2'", "units.nameplate1.guid='Pet-0-1-2-3-42-1'",
            "units.nameplate1.guid='Vehicle-0-1-2-3-42-1'", 'units.nameplate1.controlled=true',
            'auras[10]=setmetatable({}, {__index=function() error(secret) end})',
            'function canaccesstable(v) return not rawequal(v,auras[10]) end',
            'function canaccesstable() return secret end',
            'function issecrettable(v) return rawequal(v,auras[10]) end',
        ]
        for fixture in fixtures:
            with self.subTest(fixture=fixture):
                lua=client();lua.execute('active={effect("DISARM",12345,10)};'+fixture)
                lua.execute('''
                    fire('LOSS_OF_CONTROL_ADDED','player',1)
                    fire('LOSS_OF_CONTROL_UPDATE','player')
                    assert(not ability() and not ability(43));assert(fallbackCount()<=1)
                    publicTree(AzerothFieldbookDB)
                    SlashCmdList.AZEROTHFIELDBOOK('debug')
                ''')

    def test_optional_secret_fields_do_not_discard_readable_spell(self):
        lua=client()
        lua.execute('''
            active={effect('DISARM',12345,10)}
            for _,k in ipairs({'locType','displayText','startTime','duration','timeRemaining','lockoutSchool','auraInstanceID'}) do active[1][k]=secret end
            C_Spell.GetSpellName=function() return secret end
            fire('LOSS_OF_CONTROL_UPDATE','player')
            assert(fallbackCount()==1 and displayed[1].id==12345 and not ability())
            assert(output():find('Spell ID 12345',1,true));publicTree(AzerothFieldbookDB)
        ''')

    def test_accessible_tables_with_secret_contents_and_api_errors(self):
        lua=client()
        lua.execute('''
            function issecrettable() return true end
            function canaccesstable() return true end
            auras[10].name=secret;apply(nil,nil,10);assert(ability())
            active={effect('ROOT',4321,11)}
            C_UnitAuras.GetAuraDataByAuraInstanceID=function() error(secret) end
            fire('LOSS_OF_CONTROL_UPDATE','player');assert(fallbackCount()==1 and not ability(42,4321))
            C_LossOfControl.GetActiveLossOfControlDataCount=function() return secret end
            fire('LOSS_OF_CONTROL_UPDATE','player');fire('LOSS_OF_CONTROL_ADDED','player',1)
            assert(fallbackCount()==1)
            active={effect('SILENCE',777)};fire('LOSS_OF_CONTROL_ADDED','player',1)
            assert(fallbackCount()==2)
            C_LossOfControl=nil;fire('LOSS_OF_CONTROL_UPDATE','player')
        ''')

    def test_existing_manual_cast_and_pending_provenance_is_preserved(self):
        for origin, state in [('Your note','confirmed'), ('Automatic cast observation','confirmed'),
                              ('Previous observations','pending')]:
            lua=client();lua.globals().origin=origin;lua.globals().savedState=state
            lua.execute('''
                journal:Ensure(42,false,'Creature A')
                journal.entries[42].abilities['Custom name']={spellID=12345,state=savedState,origin=origin,
                    note='Keep',effects={Slow=true},showInTooltip=false}
                apply(nil,nil,10)
                local a=ability();assert(abilityCount(42)==1 and a.playerLossOfControl)
                assert(a.origin==origin and a.note=='Keep' and a.effects.Slow and a.showInTooltip==false)
                local rev=journal.revision;fire('LOSS_OF_CONTROL_UPDATE','player');assert(journal.revision==rev)
                combat=false;assert(journal:ResolveAbility(42,'Custom name'))
                assert(ability().playerLossOfControl)
                assert(journal:AddManual(42,'Disarming Smash','Manual edit','12345'))
                assert(ability().playerLossOfControl)
            ''')

    def test_no_name_and_same_name_different_id_store_exact_ids(self):
        lua=client()
        lua.execute('''
            C_Spell.GetSpellName=function() return nil end
            apply(nil,nil,10);assert(ability() and abilityCount(42)==1)
            assert(journal.entries[42].abilities['Spell ID 12345'])
            C_Spell.GetSpellName=function() return 'Shared name' end
            journal.entries[42].abilities['Shared name']={state='confirmed',spellID=999,origin='Your note'}
            active={effect('ROOT',456,11)};auras[11]={auraInstanceID=11,sourceUnit='nameplate1'}
            fire('LOSS_OF_CONTROL_UPDATE','player')
            assert(ability(42,456) and ability(42,999) and abilityCount(42)==3)
        ''')

    def test_login_reload_account_backup_and_sharing(self):
        lua=client(account=True)
        lua.execute('''
            active={effect('DISARM',12345,10)};fire('PLAYER_ENTERING_WORLD')
            assert(ability() and AzerothFieldbookAccountDB.bestiary.entries[42]==journal.entries[42])
            assert(not AzerothFieldbookDB.bestiary.entries[42])
            combat=false
            local backup=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(assert(journal:CaptureBackup())))))
            assert(journal:RestoreBackup(backup));assert(ability().playerLossOfControl)
            local messageCount=#messages
            fire('ADDON_LOADED','AzerothFieldbook');fire('PLAYER_LOGIN')
            assert(ability().playerLossOfControl and #messages==messageCount)
            local report,claims=ns.SharingReport.Capture(journal,42)
            report.rumours=claims;report.transaction='1-1-1';report.created=1790400000;report.recipient='Recipient'
            local receiver=ns.CreateBestiaryJournal({},function() end)
            assert(receiver:ImportReport(report,'Sender',1790400001))
            assert(not next(receiver.entries[42].abilities) and #receiver:GetRumours(42)==1)
            publicTree(AzerothFieldbookAccountDB)
        ''')

    def test_option_wipe_hold_and_nonplayer_events(self):
        lua=client()
        lua.execute('''
            active={effect('DISARM',12345,10)}
            fire('LOSS_OF_CONTROL_ADDED','pet',1);fire('LOSS_OF_CONTROL_UPDATE',secret)
            assert(not next(journal.entries) and #displayed==0 and #messages==0)
            journal:SetAutoRecordAbilities(false);fire('LOSS_OF_CONTROL_UPDATE','player')
            assert(not next(journal.entries) and fallbackCount()==1 and #displayed==1)
            journal:SetAutoRecordAbilities(true);fire('LOSS_OF_CONTROL_UPDATE','player');assert(ability())
            SlashCmdList.AZEROTHFIELDBOOK('wipe');SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
            fire('LOSS_OF_CONTROL_UPDATE','player');fire('PLAYER_ENTERING_WORLD')
            assert(not next(journal.entries))
        ''')

    def test_source_identity_changes_during_resolution(self):
        for during_name in (False, True):
            lua=client();lua.globals().duringName=during_name
            lua.execute('''
                local originalGUID,originalName=UnitGUID,UnitName
                local reads=0
                if duringName then
                    UnitName=function(unit)
                        if unit=='nameplate1' then units.nameplate1=units.target end
                        return originalName(unit)
                    end
                else
                    UnitGUID=function(unit)
                        if unit=='nameplate1' then
                            reads=reads+1;if reads==2 then units.nameplate1=units.target end
                        end
                        return originalGUID(unit)
                    end
                end
                apply(nil,nil,10)
                assert(not ability() and not ability(43) and fallbackCount()==1)
            ''')

    def test_account_import_merges_loc_evidence_without_replacing_origin(self):
        lua=client(account=True)
        lua.execute('''
            apply(nil,nil,10)
            local accountEntry=journal.entries[42]
            accountEntry.abilities['Disarming Smash'].origin='Your note'
            accountEntry.abilities['Disarming Smash'].playerLossOfControl=nil
            local other={version=1,bestiary={entries={[42]={id=42,name='Creature A',personalEncountered=true,
                abilities={['Disarming Smash']={state='confirmed',spellID=12345,
                    origin='Automatic player Loss of Control observation',playerLossOfControl=true}}}}}}
            ns.CreateBestiaryJournal(other,function() end)
            ns.InitializeTracking(other)
            local a=AzerothFieldbookAccountDB.bestiary.entries[42].abilities['Disarming Smash']
            assert(a.playerLossOfControl and a.origin=='Your note')
        ''')

    def test_restricted_loc_scan_does_not_reset_application_deduplication(self):
        lua=client()
        lua.execute('''
            auras={};apply(nil,nil,10)
            local data=active[1]
            active[1]=secret;clock=clock+10;fire('LOSS_OF_CONTROL_UPDATE','player')
            active[1]=data;clock=clock+10;fire('LOSS_OF_CONTROL_UPDATE','player')
            assert(fallbackCount()==1)
            assert(not next(journal.entries));publicTree(AzerothFieldbookDB)
        ''')

    def test_guid_used_to_parse_id_must_match_aura_source_guid(self):
        lua=client()
        lua.execute('''
            local originalGUID=UnitGUID;local reads=0
            UnitGUID=function(unit)
                if unit=='nameplate1' then
                    reads=reads+1
                    if reads==2 then return units.target.guid end
                end
                return originalGUID(unit)
            end
            apply(nil,nil,10)
            assert(not next(journal.entries) and fallbackCount()==1)
        ''')

    def test_locked_entry_allows_loc_and_repeated_application_keeps_saved_data(self):
        lua=client()
        lua.execute('''
            journal:Ensure(42,false,'Creature A');journal:SetEntryConfirmed(42,true)
            apply(nil,nil,10);assert(ability() and journal.entries[42].confirmed)
            local original=ability();local count=#messages
            active={};fire('LOSS_OF_CONTROL_UPDATE','player');clock=clock+4
            auras[11]={auraInstanceID=11,sourceUnit='nameplate1'}
            apply(nil,nil,11)
            assert(ability()==original and abilityCount(42)==1 and #messages==count)
        ''')

    def test_bestiary_marker_and_tooltip_preserve_other_origin(self):
        lua=new_ui_client(['Scrollbars.lua','BestiaryBuffs.lua','BestiaryJournal.lua',
                           'ActionButtons.lua','FieldbookShell.lua','BestiaryPages.lua','BestiaryBook.lua'])
        lua.execute('''
            C_Spell={GetSpellName=function() return 'Disarming Smash' end}
            journal=ns.CreateBestiaryJournal({},function() return 42 end)
            controller=ns.CreateBestiaryBook(journal);controller:OpenAtUnit('target')
            journal.entries[42].abilities['Disarming Smash']={state='confirmed',spellID=12345,origin='Automatic cast observation'}
            assert(journal:RecordPlayerLossOfControl(42,12345));controller:Refresh()
            local row=AzerothFieldbookBestiarySection.abilities[1]
            assert(row.text:GetText()=='Disarming Smash  |cff80d0ff[A]|r')
            GameTooltip={lines={},SetOwner=function() end,SetSpellByID=function() end,Show=function() end,
                AddLine=function(self,text) self.lines[#self.lines+1]=text end}
            row.tooltipArea.scripts.OnEnter(row.tooltipArea)
            assert(GameTooltip.lines[1]:find('Loss of Control',1,true))
            assert(GameTooltip.lines[2]:find('cast spell ID',1,true))
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
