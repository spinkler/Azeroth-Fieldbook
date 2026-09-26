"""Public out-of-combat buffs through the real addon events, storage and book UI."""
import unittest

from kill_test_harness import ROOT, new_client
from ui_test_harness import new_ui_client


def client(account=False):
    lua = new_client(tracking=account)
    for name in ['SharingReport.lua', 'BestiaryBackups.lua', 'BestiaryBuffs.lua']:
        lua.execute((ROOT / name).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute('''
        local create = ns.CreateBestiaryJournal
        ns.CreateBestiaryJournal = function(...)
            journal = create(...)
            return journal
        end
        combat = false
        function InCombatLockdown() return combat end
        function time() return 1790400000 end
        units.player = {combat=false}
        units.target = spawn('wizard', false)
        units.target.name = 'Defias Rogue Wizard'
        auras, auraReads = {target={}, mouseover={}}, 0
        function buff(id, name, source)
            return {spellId=id or 12544, name=name or 'Frost Armor', sourceUnit=source}
        end
        C_UnitAuras = {GetAuraDataByIndex=function(unit, index, filter)
            assert(filter=='HELPFUL')
            auraReads = auraReads + 1
            return auras[unit][index]
        end}
        C_Spell = {GetSpellName=function(id) if id==12544 then return 'Frost Armor' end end}
        -- Visibility of the display-only Spell ID window cannot gate recording.
        AzerothFieldbookDB.displaySpellIDWindow = false
        fire('ADDON_LOADED', 'AzerothFieldbook')
        function entry() return journal.entries[42] end
        function ability() return entry() and entry().abilities['Frost Armor'] end
        function buffEvents()
            local count=0
            for _, event in ipairs(journal:GetEventLog().entries) do
                if event.details and event.details.kind=='buff' then count=count+1 end
            end
            return count
        end
        function publicTree(value)
            assert(not issecretvalue(value), 'secret entered saved data')
            if type(value)=='table' then
                for key,item in pairs(value) do publicTree(key);publicTree(item) end
            end
        end
    ''')
    return lua


class AutomaticBuffTests(unittest.TestCase):
    def test_legacy_name_dismissal_is_superseded_by_verified_buff_id(self):
        lua = client(account=True)
        lua.execute('''
            -- Reproduce the user's saved wizard record: unlocked, empty
            -- abilities, and a legacy Frost Armor name-only removal marker.
            units.target.guid='Creature-0-1-2-3-474-wizard'
            fire('PLAYER_TARGET_CHANGED')
            local wizard=journal.entries[474]
            wizard.ignoredAbilities={['Frost Armor']=true,Test=true}
            assert(not wizard.confirmed and not next(wizard.abilities))
            auras.target={buff()};fire('UNIT_AURA','target')
            local frost=wizard.abilities['Frost Armor']
            assert(frost and frost.state=='confirmed' and frost.spellID==12544)
            assert(frost.origin=='Automatic buff observation')
            assert(not wizard.ignoredAbilities['Frost Armor'] and wizard.ignoredAbilities.Test)
            assert(journal:RemoveAbility(474,'Frost Armor'))
            fire('UNIT_AURA','target');fire('ADDON_LOADED','AzerothFieldbook')
            fire('PLAYER_TARGET_CHANGED')
            assert(journal.entries[474].abilities['Frost Armor'].state=='confirmed', 'verified buffs always return while enabled')
        ''')

    def test_public_id_resolves_name_without_optional_aura_fields(self):
        lua = client()
        lua.execute('''
            C_Spell.GetSpellName=function(id)
                assert(id==12544 and not issecretvalue(id))
                return 'Frost Armor'
            end
            auras.target={setmetatable({spellId=12544,name=secret}, {
                __index=function(_,key) if key=='sourceUnit' then error('optional field unavailable') end end
            })}
            fire('PLAYER_TARGET_CHANGED')
            assert(ability() and ability().spellID==12544 and ability().state=='confirmed')
            assert(ability().origin=='Automatic buff observation')
            publicTree(AzerothFieldbookDB)
        ''')

    def test_new_automatic_buffs_announce_once_in_chat_and_log(self):
        lua = client()
        lua.execute('''
            fire('PLAYER_TARGET_CHANGED')
            messages={}
            auras.target={buff()};fire('UNIT_AURA','target')
            assert(#messages==1 and messages[1]:find('Frost Armor',1,true))
            assert(messages[1]:find('12544',1,true) and messages[1]:find('Defias Rogue Wizard',1,true))
            assert(buffEvents()==1)
            fire('UNIT_AURA','target');fire('PLAYER_TARGET_CHANGED')
            for i=1,10 do tick() end
            fire('ADDON_LOADED','AzerothFieldbook');fire('PLAYER_TARGET_CHANGED')
            assert(#messages==1 and buffEvents()==1, 'duplicates and reloads must be silent')
            journal:SetAbility(42,'Frost Armor','rejected');fire('UNIT_AURA','target')
            assert(#messages==2 and buffEvents()==2 and ability().state=='confirmed')
            journal:RemoveAbility(42,'Frost Armor');fire('UNIT_AURA','target')
            assert(#messages==3 and buffEvents()==3 and ability().state=='confirmed')
            journal:SetAutoRecordBuffs(false)
            journal:RemoveAbility(42,'Frost Armor');fire('UNIT_AURA','target')
            assert(#messages==3 and buffEvents()==3 and not ability(), 'off suppresses restoration and messages')
            journal:SetAutoRecordBuffs(true);fire('UNIT_AURA','target')
            assert(#messages==4 and buffEvents()==4 and ability())
        ''')

    def test_debug_reports_public_recording_status(self):
        lua = client()
        lua.execute('''
            auras.target={buff(secret)};fire('PLAYER_TARGET_CHANGED')
            messages={};SlashCmdList.AZEROTHFIELDBOOK('debug')
            assert(output():find('Automatic buffs target: spell ID unreadable or invalid',1,true))
            auras.target={buff()};fire('UNIT_AURA','target')
            messages={};SlashCmdList.AZEROTHFIELDBOOK('debug')
            assert(output():find('Automatic buffs target: recorded spell ID 12544',1,true))
            journal:SetAutoRecordBuffs(false)
            messages={};SlashCmdList.AZEROTHFIELDBOOK('debug')
            assert(output():find('Automatic ability recording: OFF',1,true))
        ''')

    def test_default_on_all_buffs_deduplicate_and_persist(self):
        lua = client()
        lua.execute('''
            assert(journal:GetAutoRecordBuffs())
            auras.target={buff(nil,nil,'target'),buff(900,'Second Buff')}
            fire('PLAYER_TARGET_CHANGED')
            assert(ability().spellID==12544 and ability().state=='confirmed')
            assert(ability().origin=='Automatic buff observation')
            assert(entry().abilities['Second Buff'].spellID==900)
            assert(buffEvents()==2)
            local original=ability()
            fire('UNIT_AURA','target',secret)
            fire('PLAYER_TARGET_CHANGED')
            for i=1,10 do tick() end
            assert(ability()==original and buffEvents()==2)
            assert(#journal:ConfirmedNames(42)==0, 'unlocked entry still hides tooltip abilities')
            journal:SetEntryConfirmed(42,true)
            assert(#journal:ConfirmedNames(42)==2)
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(ability()==original and ability().origin=='Automatic buff observation')
            assert(AzerothFieldbookDB.displaySpellIDWindow==false)
            publicTree(AzerothFieldbookDB)
        ''')

    def test_disabled_setting_survives_reload_and_keeps_records(self):
        lua = client()
        lua.execute('''
            journal:SetAutoRecordBuffs(false)
            auras.target={buff()}
            fire('PLAYER_TARGET_CHANGED')
            fire('ADDON_LOADED','AzerothFieldbook')
            fire('UNIT_AURA','target')
            for i=1,5 do tick() end
            assert(not journal:GetAutoRecordBuffs() and not ability() and auraReads==0)
            journal:SetAutoRecordBuffs(true)
            for i=1,5 do tick() end
            assert(ability() and buffEvents()==1)
            journal:SetAutoRecordBuffs(false)
            auras.target={buff(),buff(900,'Second Buff')}
            fire('UNIT_AURA','target')
            assert(ability() and not entry().abilities['Second Buff'])
        ''')

    def test_combat_and_unknown_state_block_then_recover_without_retarget(self):
        lua = client()
        lua.execute('''
            auras.target={buff()}
            for _,state in ipairs({true,secret}) do
                combat=state; fire('PLAYER_TARGET_CHANGED')
                combat=false;units.player.combat=state;fire('UNIT_AURA','target')
                units.player.combat=false;units.target.combat=state;fire('UNIT_AURA','target')
                units.target.combat=false
            end
            local original=InCombatLockdown
            InCombatLockdown=function() error('unavailable') end
            fire('UNIT_AURA','target')
            InCombatLockdown=function() end
            fire('UNIT_AURA','target')
            InCombatLockdown=original
            assert(not ability() and auraReads==0)
            fire('PLAYER_REGEN_ENABLED')
            assert(ability() and buffEvents()==1)
            units.target.combat=true;auras.target={buff(900,'Second Buff')}
            fire('UNIT_AURA','target')
            units.target.combat=false
            for i=1,5 do tick() end
            assert(entry().abilities['Second Buff'], 'target combat may end after player combat')
        ''')

    def test_npc_ownership_scope_and_caster_checks(self):
        lua = client()
        lua.execute('''
            auras.target={buff()}
            local originalGUID=units.target.guid
            for _,guid in ipairs({'Player-1-42','Pet-0-1-2-3-42-1','Vehicle-0-1-2-3-42-1',secret}) do
                units.target.guid=guid;fire('PLAYER_TARGET_CHANGED')
            end
            units.target.guid=originalGUID
            for _,controlled in ipairs({true,secret}) do
                units.target.controlled=controlled;fire('PLAYER_TARGET_CHANGED')
            end
            units.target.controlled=false;units.target.attackable=false;fire('PLAYER_TARGET_CHANGED')
            units.target.attackable=true;units.target.dead=true;fire('PLAYER_TARGET_CHANGED')
            units.target.dead=false
            assert(not ability() and auraReads==0)
            auras.target={buff(nil,nil,'player'),buff(900,'Other NPC Buff','party1target')}
            fire('UNIT_AURA','target')
            assert(not ability() and not entry().abilities['Other NPC Buff'])
            units.alias=units.target
            auras.target={buff(nil,nil,'alias')}
            fire('UNIT_AURA','focus');fire('UNIT_AURA',secret)
            assert(not ability(), 'background and restricted event units are ignored')
            fire('UNIT_AURA','alias')
            assert(ability(), 'readable alias of the target is accepted')
            units.mouseover=spawn('second',false)
            units.mouseover.guid='Creature-0-1-2-3-43-second'
            auras.mouseover={buff(900,'Second Buff')}
            fire('UPDATE_MOUSEOVER_UNIT')
            assert(journal.entries[43].abilities['Second Buff'])
            assert(not entry().abilities['Second Buff'], 'associate the buff with the watched creature')
        ''')

    def test_restricted_tables_fields_and_failed_api_never_persist(self):
        lua = client()
        lua.execute('''
            local forbidden=setmetatable({}, {__index=function() error('forbidden table access') end})
            local throwing=setmetatable({}, {__index=function() error('field unavailable') end})
            function canaccesstable(value) return not rawequal(value,forbidden) end
            auras.target={forbidden,throwing,buff(secret),buff(0),buff(-1),buff(1.5),buff(math.huge),
                buff(2147483648),buff('12544'),buff(12600,secret),buff(12600,'')}
            fire('PLAYER_TARGET_CHANGED')
            assert(not next(entry().abilities))
            auras.target={secret};fire('UNIT_AURA','target')
            local readAura=C_UnitAuras.GetAuraDataByIndex
            C_UnitAuras.GetAuraDataByIndex=function() error(secret) end
            fire('UNIT_AURA','target')
            C_UnitAuras.GetAuraDataByIndex=readAura
            canaccesstable=nil
            function issecrettable() return true end
            auras.target={buff()};fire('UNIT_AURA','target')
            assert(not ability())
            -- Accessible tables can have unrelated secret fields. Only the
            -- necessary public fields are ever saved.
            function canaccesstable() return true end
            auras.target[1].duration=secret
            fire('UNIT_AURA','target')
            assert(ability().spellID==12544 and not ability().duration)
            publicTree(AzerothFieldbookDB)
        ''')

    def test_slot_pagination_and_index_fallback(self):
        lua = client()
        lua.execute('''
            local slots={[0]=buff(),[33]=buff(900,'Second Buff')}
            C_UnitAuras.GetAuraSlots=function(unit,filter,maxSlots,token)
                assert(filter=='HELPFUL' and maxSlots==32)
                if token==nil then return 10,0,secret end
                assert(token==10);return nil,33
            end
            C_UnitAuras.GetAuraDataBySlot=function(_,slot) return slots[slot] end
            fire('PLAYER_TARGET_CHANGED')
            assert(ability() and entry().abilities['Second Buff'] and auraReads==0)
            assert(buffEvents()==2)
            C_UnitAuras.GetAuraSlots=function() error('unsupported') end
            auras.target={buff(901,'Fallback Buff')}
            fire('UNIT_AURA','target')
            assert(entry().abilities['Fallback Buff'] and buffEvents()==3)
            -- Secret continuation cannot be passed back into the API.
            C_UnitAuras.GetAuraSlots=function() return secret,0 end
            auras.target={buff(902,'Another Buff')}
            fire('UNIT_AURA','target')
            assert(entry().abilities['Another Buff'] and buffEvents()==4)
        ''')

    def test_review_choices_notes_and_existing_spell_identity_win(self):
        lua = client()
        lua.execute('''
            fire('PLAYER_TARGET_CHANGED')
            journal:Offer(42,'Frost Armor','Automatic observation',12544)
            local pending=ability()
            pending.note='Keep this note';pending.effects={Slow=true};pending.showInTooltip=false
            entry().rumours={{kind='ability',value='Frost Armor',spellID=12544,sender='Bob'}}
            journal:TrackStableContent(42);entry().unchangedKills=9
            auras.target={buff()};fire('UNIT_AURA','target')
            assert(ability()==pending and ability().state=='confirmed')
            assert(ability().origin=='Automatic buff observation' and ability().note=='Keep this note')
            assert(ability().effects.Slow and ability().showInTooltip==false and entry().rumours[1].resolved)
            assert(entry().unchangedKills==0, 'new buff evidence resets automatic lock progress immediately')
            entry().unchangedKills=2;fire('UNIT_AURA','target')
            assert(entry().unchangedKills==2, 'repeated buff evidence does not restart lock progress')
            journal:Offer(42,'Another spelling','Automatic observation',12544)
            assert(not entry().abilities['Another spelling'])
            journal:SetAbility(42,'Frost Armor','rejected');fire('UNIT_AURA','target')
            assert(ability().state=='confirmed', 'fresh verified evidence restores rejected abilities')
            journal:RemoveAbility(42,'Frost Armor');fire('UNIT_AURA','target')
            assert(ability().state=='confirmed', 'fresh verified evidence restores removed abilities')
            journal:SetAutoRecordBuffs(false)
            journal:RemoveAbility(42,'Frost Armor');fire('UNIT_AURA','target')
            fire('ADDON_LOADED','AzerothFieldbook');fire('PLAYER_TARGET_CHANGED')
            assert(not ability(), 'off keeps the removed buff absent across reload')
            assert(journal:AddManual(42,'Frost Armor','Personal record',nil,{Slow=true}))
            journal:SetAutoRecordBuffs(true)
            fire('UNIT_AURA','target')
            assert(ability().spellID==12544 and ability().origin=='Your note' and ability().note=='Personal record')
            local manual=ability()
            entry().abilities['Custom name']=manual;entry().abilities['Frost Armor']=nil
            fire('UNIT_AURA','target')
            assert(not ability() and entry().abilities['Custom name']==manual)
            entry().abilities['Custom name']=nil
            entry().abilities['Frost Armor']={state='pending',spellID=900}
            fire('UNIT_AURA','target')
            assert(ability().spellID==900 and ability().state=='pending', 'conflicting IDs require review')
        ''')

    def test_locked_entries_and_wipe_hold(self):
        lua = client()
        lua.execute('''
            fire('PLAYER_TARGET_CHANGED')
            journal:SetEntryConfirmed(42,true)
            auras.target={buff()};fire('UNIT_AURA','target')
            assert(not ability() and auraReads==1, 'locked record bypasses enumeration')
            journal:SetEntryConfirmed(42,false)
            for i=1,5 do tick() end
            assert(ability())
            SlashCmdList.AZEROTHFIELDBOOK('wipe')
            SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
            fire('UNIT_AURA','target');fire('PLAYER_REGEN_ENABLED');fire('PLAYER_ENTERING_WORLD')
            for i=1,10 do tick() end
            assert(not next(journal.entries), 'wipe hold prevents passive recapture')
            fire('PLAYER_TARGET_CHANGED')
            assert(ability() and journal:GetAutoRecordBuffs())
        ''')

    def test_account_storage_backup_and_sharing_provenance(self):
        lua = client(account=True)
        lua.execute('''
            auras.target={buff()};fire('PLAYER_TARGET_CHANGED')
            assert(AzerothFieldbookAccountDB.bestiary.entries[42]==entry())
            assert(not AzerothFieldbookDB.bestiary.entries[42])
            local saved=assert(journal:CaptureBackup())
            local decoded=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(saved))))
            journal:RemoveAbility(42,'Frost Armor')
            assert(journal:RestoreBackup(decoded))
            assert(ability().origin=='Automatic buff observation' and ability().spellID==12544)
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(ability().origin=='Automatic buff observation')
            local report,claims=ns.SharingReport.Capture(journal,42)
            report.rumours=claims;report.transaction='1-1-1';report.created=1790400000;report.recipient='Recipient'
            local receiver=ns.CreateBestiaryJournal({},function() end)
            assert(receiver:ImportReport(report,'Sender',1790400001))
            assert(not next(receiver.entries[42].abilities))
            assert(#receiver:GetRumours(42)==1 and receiver:GetRumours(42)[1].spellID==12544)
            publicTree(AzerothFieldbookAccountDB)
        ''')

    def test_option_marker_tooltip_and_manual_edit(self):
        lua = new_ui_client(['Scrollbars.lua', 'SharingReport.lua', 'BestiaryBuffs.lua', 'BestiaryJournal.lua',
                             'ActionButtons.lua', 'FieldbookShell.lua', 'BestiaryPages.lua', 'BestiaryBook.lua'])
        lua.execute('''
            StaticPopupDialogs={};YES='Yes';NO='No'
            function UnitAffectingCombat() return false end
            C_UnitAuras={GetAuraDataByIndex=function(_,index)
                if index==1 then return {name='Frost Armor',spellId=12544} end
            end}
            C_Spell={GetSpellName=function() return 'Frost Armor' end}
            db={}
            journal=ns.CreateBestiaryJournal(db,function() return 42 end)
            controller=ns.CreateBestiaryBook(journal)
            controller:OpenAtUnit('target')
            assert(journal:ObserveBuffs('target'))
            controller:Refresh()
            local row=AzerothFieldbookBestiarySection.abilities[1]
            assert(row.text:GetText()=='Frost Armor  |cff80d0ff[A]|r')
            assert(row.note:GetText()=='|cff999999Automatic buff observation|r')
            assert(not row.resolve:IsShown() and not row.accept.enabled)
            GameTooltip={lines={}}
            function GameTooltip:SetOwner() end
            function GameTooltip:SetSpellByID(id) self.id=id end
            function GameTooltip:AddLine(text) self.lines[#self.lines+1]=text end
            function GameTooltip:Show() end
            row.tooltipArea.scripts.OnEnter(row.tooltipArea)
            assert(GameTooltip.id==12544 and GameTooltip.lines[1]:find('[A]',1,true))
            journal:RemoveAbility(42,'Frost Armor')
            assert(journal:RecordVerifiedCast(42,12544))
            controller:Refresh();GameTooltip.lines={}
            assert(row.text:GetText()=='Frost Armor  |cff80d0ff[A]|r')
            row.tooltipArea.scripts.OnEnter(row.tooltipArea)
            assert(GameTooltip.lines[1]:find("creature's readable cast spell ID",1,true))
            local options=AzerothFieldbookOptions
            options.scripts.OnShow(options)
            assert(options.autoRecordBuffs:GetChecked())
            options.autoRecordBuffs:SetChecked(false)
            options.autoRecordBuffs.scripts.OnClick(options.autoRecordBuffs)
            options.scripts.OnShow(options)
            assert(not options.autoRecordBuffs:GetChecked() and not journal:GetAutoRecordBuffs())
            assert(journal.entries[42].abilities['Frost Armor'])
            assert(journal:AddManual(42,'Frost Armor','My note','12544'))
            controller:Refresh()
            assert(row.text:GetText()=='Frost Armor' and row.note:GetText()=='My note')
            StaticPopupDialogs.AZEROTHFIELDBOOK_BESTIARY_RESET_CONFIRM.OnAccept()
            assert(journal:GetAutoRecordBuffs() and options.autoRecordBuffs:GetChecked())
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
