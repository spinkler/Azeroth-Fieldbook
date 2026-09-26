"""Automatic confirmation from fresh public enemy cast IDs, including combat."""
import unittest

from test_auto_buffs import client


def cast_client(account=False):
    lua = client(account=account)
    lua.execute('''
        combat=true;units.player.combat=true;units.target.combat=true
        lookups=0
        C_Spell.GetSpellName=function(id)
            assert(not issecretvalue(id), 'secret ID must never be looked up')
            lookups=lookups+1
            if id==12544 then return 'Frost Armor' end
        end
        function cast(event,unit,id)
            fire(event or 'UNIT_SPELLCAST_START',unit or 'target','cast-guid',id or 12544)
        end
        function castEvents()
            local count=0
            for _,event in ipairs(journal:GetEventLog().entries) do
                if event.details and event.details.kind=='cast' then count=count+1 end
            end
            return count
        end
        fire('PLAYER_TARGET_CHANGED');messages={}
    ''')
    return lua


class AutomaticCastTests(unittest.TestCase):
    def test_cast_events_in_combat_confirm_and_announce_once(self):
        for event in ['UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_SUCCEEDED',
                      'UNIT_SPELLCAST_CHANNEL_START', 'UNIT_SPELLCAST_EMPOWER_START']:
            with self.subTest(event=event):
                lua = cast_client()
                lua.globals().event = event
                lua.execute('''
                    cast(event)
                    assert(ability().state=='confirmed' and ability().spellID==12544)
                    assert(ability().origin=='Automatic cast observation')
                    assert(#messages==1 and castEvents()==1)
                    assert(messages[1]:find('Automatically recorded:',1,true))
                    assert(messages[1]:find('12544',1,true) and messages[1]:find('Defias Rogue Wizard',1,true))
                    cast(event);cast('UNIT_SPELLCAST_SUCCEEDED');tick()
                    fire('ADDON_LOADED','AzerothFieldbook');cast(event)
                    assert(#messages==1 and castEvents()==1)
                    -- The same buff after combat must not duplicate the cast.
                    combat=false;units.player.combat=false;units.target.combat=false
                    auras.target={buff()};fire('UNIT_AURA','target')
                    assert(#messages==1 and buffEvents()==0)
                    assert(ability().origin=='Automatic cast observation')
                ''')

    def test_active_cast_and_channel_polling_resolve_public_id(self):
        for channel in [False, True]:
            with self.subTest(channel=channel):
                lua = cast_client()
                lua.globals().channel = channel
                lua.execute('''
                    -- The name can be secret when the independently public ID resolves.
                    if channel then
                        function UnitChannelInfo() return secret,nil,nil,nil,nil,nil,nil,12544 end
                    else
                        function UnitCastingInfo() return secret,nil,nil,nil,nil,nil,nil,nil,12544 end
                    end
                    tick()
                    assert(ability().state=='confirmed' and #messages==1 and castEvents()==1)
                    tick();assert(#messages==1)
                    publicTree(AzerothFieldbookDB)
                ''')

    def test_optional_name_fallback_and_later_spell_cache_retry(self):
        lua = cast_client()
        lua.execute('''
            C_Spell.GetSpellName=function() error('cache unavailable') end
            cast();assert(not ability())
            function UnitCastingInfo() return 'Frost Armor',nil,nil,nil,nil,nil,nil,nil,12544 end
            tick();assert(ability().state=='confirmed')
            journal:RemoveAbility(42,'Frost Armor')
            C_Spell.GetSpellName=function() return secret end
            tick();assert(ability().state=='confirmed')
            journal:RemoveAbility(42,'Frost Armor');UnitCastingInfo=nil
            cast();assert(not ability())
            C_Spell.GetSpellName=function() return 'Frost Armor' end
            cast();assert(ability().state=='confirmed')
        ''')

    def test_secret_ids_never_confirm_lookup_or_save(self):
        lua = cast_client()
        lua.execute('''
            cast(nil,nil,secret);assert(not ability() and lookups==0)
            function UnitCastingInfo() return 'Frost Armor',nil,nil,nil,nil,nil,nil,nil,secret end
            tick()
            assert(ability().state=='pending' and not ability().spellID and lookups==0)
            publicTree(AzerothFieldbookDB)
            function UnitCastingInfo() return secret,nil,nil,nil,nil,nil,nil,nil,secret end
            tick();assert(ability().state=='pending' and lookups==0)
            for _,id in ipairs({0,-1,math.huge,1.5,2147483648}) do
                cast(nil,nil,id)
            end
            assert(ability().state=='pending' and lookups==0)
            publicTree(AzerothFieldbookDB)
        ''')

    def test_option_persists_and_fresh_evidence_restores_removals(self):
        lua = cast_client()
        lua.execute('''
            journal:SetAutoRecordAbilities(false)
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(not journal:GetAutoRecordAbilities())
            cast();assert(ability().state=='pending')
            journal:RemoveAbility(42,'Frost Armor');cast();assert(not ability())
            journal:SetAutoRecordAbilities(true);messages={}
            cast();assert(ability().state=='confirmed' and #messages==1)
            journal:RemoveAbility(42,'Frost Armor')
            fire('ADDON_LOADED','AzerothFieldbook');assert(not ability(), 'old saved casts are not fresh evidence')
            cast();assert(ability().state=='confirmed' and #messages==2)
            journal:SetAbility(42,'Frost Armor','rejected')
            cast();assert(ability().state=='confirmed' and #messages==3)
        ''')

    def test_watched_identity_locks_and_reset_hold(self):
        lua = cast_client()
        lua.execute('''
            units.nameplate1=spawn('unwatched',false)
            cast(nil,'nameplate1');cast(nil,'player');cast(nil,secret)
            assert(not ability())
            units.target.controlled=true;cast();assert(not ability())
            units.target.controlled=false;units.target.attackable=false;cast();assert(not ability())
            units.target.attackable=true
            local guid=units.target.guid;units.target.guid=secret;cast();assert(not ability())
            units.target.guid=guid
            local name=entry().name
            entry().name=nil;units.target.name=secret
            cast();assert(not ability(), 'legacy nameless entries cannot receive new records')
            entry().name=name;units.target.name=name
            journal:SetEntryConfirmed(42,true);cast();assert(not ability())
            journal:SetEntryConfirmed(42,false)
            units.nameplate1=units.target;cast(nil,'nameplate1');assert(ability())
            SlashCmdList.AZEROTHFIELDBOOK('wipe');SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
            cast();tick();assert(not next(journal.entries))
            fire('PLAYER_TARGET_CHANGED');cast();assert(ability())
            journal:RemoveAbility(42,'Frost Armor')
            units.mouseover=units.target;units.target=nil
            cast('UNIT_SPELLCAST_SUCCEEDED','mouseover');assert(ability())
        ''')

    def test_sent_alone_and_historical_records_do_not_auto_confirm(self):
        lua = cast_client()
        lua.execute('''
            fire('UNIT_SPELLCAST_SENT','target','player','cast-guid',12544)
            assert(not ability(), 'SENT alone is not observed execution')
            AzerothFieldbookDB.bestiary.creatures[42]={spells={[12544]={name='Frost Armor'}}}
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(ability().state=='pending')
            cast();assert(ability().state=='confirmed')
        ''')

    def test_preserves_manual_data_and_deduplicates_by_spell_id(self):
        lua = cast_client()
        lua.execute('''
            journal:Offer(42,'My frost name','Automatic observation',12544)
            local a=entry().abilities['My frost name']
            a.note='Keep me';a.effects={Slow=true};a.showInTooltip=false
            cast()
            assert(not ability() and a.state=='confirmed' and a.origin=='Automatic cast observation')
            assert(a.note=='Keep me' and a.effects.Slow and a.showInTooltip==false)
            cast();assert(#messages==1)
            journal:RemoveAbility(42,'My frost name')
            journal:AddManual(42,'Frost Armor','Personal note')
            cast();assert(ability().spellID==12544 and ability().origin=='Your note')
            assert(ability().note=='Personal note')
        ''')

    def test_account_reload_backup_and_sharing(self):
        lua = cast_client(account=True)
        lua.execute('''
            cast()
            assert(AzerothFieldbookAccountDB.bestiary.entries[42]==entry())
            combat=false
            local saved=assert(journal:CaptureBackup())
            local decoded=assert(ns.BestiaryBackups.Decode(assert(ns.BestiaryBackups.Encode(saved))))
            journal:RemoveAbility(42,'Frost Armor');assert(journal:RestoreBackup(decoded))
            fire('ADDON_LOADED','AzerothFieldbook')
            assert(ability().origin=='Automatic cast observation' and ability().spellID==12544)
            local report,claims=ns.SharingReport.Capture(journal,42)
            report.rumours=claims;report.transaction='1-1-1';report.created=1790400000;report.recipient='Recipient'
            local receiver=ns.CreateBestiaryJournal({},function() end)
            assert(receiver:ImportReport(report,'Sender',1790400001))
            assert(not next(receiver.entries[42].abilities) and #receiver:GetRumours(42)==1)
            publicTree(AzerothFieldbookAccountDB)
        ''')


if __name__ == '__main__':
    unittest.main(verbosity=2)
