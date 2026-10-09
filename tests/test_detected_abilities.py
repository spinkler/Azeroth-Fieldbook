"""Per-creature display hints: opaque relay, live events, manual acknowledgement."""
import unittest
from test_auto_casts import cast_client
from kill_test_harness import ROOT
from ui_test_harness import new_ui_client


def client():
    lua = cast_client()
    lua.execute((ROOT/'DetectedAbilities.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute('''
        function date(format) assert(format=='%Y-%m-%d %H:%M:%S');return '2026-09-27 12:00:00' end
        C_Spell.GetSpellName=function(id)
            if issecretvalue(id) then return secret end
            if id==20793 then return 'Fireball' end
            if id==12544 then return 'Frost Armor' end
        end
        fire('ADDON_LOADED','AzerothFieldbook');fire('PLAYER_TARGET_CHANGED')
        function hint() return journal:GetDetectedAbility(42) end
        function detected(id,bar) fire('UNIT_SPELLCAST_START','target','guid',id,bar) end
    ''')
    return lua


class DetectedAbilityTests(unittest.TestCase):
    def test_restricted_events_persist_per_creature_without_saved_secrets(self):
        lua=client()
        lua.execute('''
            detected(secret,100)
            local first=hint()
            assert(first and first.restricted and rawequal(first.spellID,secret))
            assert(rawequal(first.name,secret) and first.stamp=='2026-09-27 12:00:00')
            fire('UNIT_SPELLCAST_SUCCEEDED','target','guid',secret,100)
            assert(hint()==first, 'same cast is not a second observation')
            local wizard=units.target
            units.target=spawn('other',false);units.target.guid='Creature-0-1-2-3-43-other'
            fire('PLAYER_TARGET_CHANGED');detected(secret,101)
            assert(journal:GetDetectedAbility(43)~=first and hint()==first)
            units.target=nil;fire('PLAYER_TARGET_CHANGED')
            for i=1,1000 do tick() end
            assert(hint()==first, 'no timeout or target-change expiry')
            units.target=wizard;fire('PLAYER_TARGET_CHANGED');detected(secret,102)
            assert(hint()~=first and journal:GetDetectedAbilities(42)[1]==first, 'another cast appends for this creature only')
            publicTree(AzerothFieldbookDB)
            fire('ADDON_LOADED','AzerothFieldbook');assert(not hint(), 'opaque evidence is session only')
        ''')

    def test_polling_relays_secret_name_and_id_and_deduplicates(self):
        for channel in (False,True):
            lua=client();lua.globals().channel=channel
            lua.execute('''
                C_Spell.GetSpellName=function() error('cache unavailable') end
                detected(secret,100);assert(hint().name=='Name unavailable')
                if channel then
                    function UnitChannelInfo() return secret,nil,nil,nil,nil,nil,nil,secret,nil,nil,100 end
                else
                    function UnitCastingInfo() return secret,nil,nil,nil,nil,nil,nil,nil,secret,100 end
                end
                tick();local h=hint();assert(rawequal(h.name,secret))
                tick();assert(hint()==h)
                publicTree(AzerothFieldbookDB)
            ''')

    def test_readable_recorded_ids_are_suppressed_and_preserve_unrelated_hints(self):
        lua=client()
        lua.execute('''
            detected(secret,100);assert(hint())
            detected(20793,100)
            assert(entry().abilities.Fireball.state=='confirmed' and not hint())
            journal:SetAutoRecordAbilities(false)
            detected(20793,102);assert(not hint())
            -- A readable cast with a missing name/cache can still offer its ID.
            detected(888,103);assert(hint() and hint().spellID==888 and not hint().restricted)
            detected(20793,104);assert(hint().spellID==888, 'recorded cast preserves another unknown spell')
            journal:RemoveAbility(42,'Fireball');detected(20793,105)
            assert(hint(), 'removed ability can be suggested for manual recording')
        ''')

    def test_linked_manual_save_clears_opaque_hint_but_does_not_map_future_secrets(self):
        lua=client()
        lua.execute('''
            detected(secret,100)
            combat=false
            assert(journal:AddManual(42,'Name only',''))
            assert(hint(), 'unlinked notes do not acknowledge an ID hint')
            assert(journal:AddManual(42,'','','20793'))
            assert(entry().abilities.Fireball.spellID==20793 and not hint())
            detected(secret,100);assert(not hint(), 'same cast remains acknowledged')
            detected(secret,101);assert(hint(), 'a new secret cannot be compared with recorded IDs')
            journal:SetAbility(42,'Fireball','rejected');assert(hint())
            journal:SetAbility(42,'Fireball','confirmed');assert(not hint())
            detected(secret,102);assert(hint())
            assert(journal:ResolveAbility(42,'Fireball'));assert(not hint())
        ''')

    def test_exclusions_reset_and_spell_window_independence(self):
        lua=client()
        lua.execute('''
            AzerothFieldbookDB.displaySpellIDWindow=false
            units.target.controlled=true;detected(secret,100);assert(not hint())
            units.target.controlled=false;units.target.attackable=false;detected(secret,101);assert(not hint())
            units.target.attackable=true
            fire('UNIT_SPELLCAST_SENT','target','player','guid',secret);assert(not hint())
            detected(secret,102);assert(hint())
            journal:DeleteEntry(42);assert(not hint())
            fire('PLAYER_TARGET_CHANGED');detected(secret,103);assert(not hint(), 'the deleted selection stays suppressed')
            units.target=nil;fire('PLAYER_TARGET_CHANGED')
            units.target=spawn('reselected',false);fire('PLAYER_TARGET_CHANGED');detected(secret,103)
            assert(hint(), 'leaving the selection allows rediscovery')
            SlashCmdList.AZEROTHFIELDBOOK('wipe');SlashCmdList.AZEROTHFIELDBOOK('wipe confirm')
            detected(secret,104);assert(not hint() and not next(journal.entries))
            fire('PLAYER_TARGET_CHANGED');detected(secret,105);assert(hint())
            publicTree(AzerothFieldbookDB)
        ''')

    def test_four_casts_roll_over_without_comparing_secrets_or_replaying_old_events(self):
        lua=client()
        lua.execute('''
            journal:SetAutoRecordAbilities(false)
            for bar=100,103 do detected(secret,bar) end
            local list=journal:GetDetectedAbilities(42)
            assert(#list==4 and list[1].key==100 and list[4].key==103)
            local first=list[1]
            detected(secret,100);assert(#list==4 and list[1]==first)
            detected(secret,104)
            assert(#list==4 and list[1].key==101 and list[4].key==104)
            detected(secret,100);assert(list[1].key==101, 'evicted casts stay deduplicated')
            local keep=list[3]
            journal:DismissDetectedAbility(42,list[2])
            assert(#list==3 and list[2]==keep)
            detected(secret,102);assert(#list==3, 'dismissed cast stays dismissed')
            detected(999,103)
            assert(list[2]==keep and keep.spellID==999 and not keep.restricted,
                'late public evidence enriches its original slot')
            journal:AcknowledgeDetectedAbility(42,999)
            assert(#list==2 and list[1].key==101 and list[2].key==104)
            combat=false
            assert(journal:AddManual(42,'','','20793'))
            assert(#list==2, 'a typed ID cannot identify one of multiple secret hints')
            publicTree(AzerothFieldbookDB)
            for bar=105,180 do detected(secret,bar) end
            assert(#list==4 and list[1].key==177 and list[4].key==180)
        ''')

    def test_casts_without_public_tokens_rearm_only_after_idle(self):
        lua=client()
        lua.execute('''
            journal:DetectAbility(42,secret,secret,secret)
            journal:DetectAbility(42,secret,secret,secret)
            assert(#journal:GetDetectedAbilities(42)==1)
            journal:FinishDetectedCast(42)
            journal:DetectAbility(42,secret,secret,nil)
            local list=journal:GetDetectedAbilities(42)
            assert(#list==2)
            journal:DetectAbility(42,999,'New readable name',nil)
            assert(list[1].restricted and list[2].spellID==999)
        ''')

    def test_book_label_is_beneath_input_and_tooltip_is_a_guarded_display_relay(self):
        lua=new_ui_client(['Scrollbars.lua','DetectedAbilities.lua','BestiaryJournal.lua',
                           'ActionButtons.lua','FieldbookShell.lua','BestiaryPages.lua','BestiaryBook.lua'])
        lua.execute('''
            secret=setmetatable({}, {__tostring=function() error('secret stringify') end,
                __eq=function() error('secret comparison') end})
            function issecretvalue(v) return rawequal(v,secret) end
            function date() return '2026-09-27 12:00:00' end
            db={};journal=ns.CreateBestiaryJournal(db,function() return 42 end)
            controller=ns.CreateBestiaryBook(journal);controller:OpenAtUnit('target')
            local book=AzerothFieldbookBestiarySection
            local h=book.detectedAbility
            assert(h and not h:IsShown())
            h:Refresh(nil);assert(not h:IsShown(), 'empty selection is safe')
            -- Simulate a FontString renderer accepting opaque values. No readback.
            local slot=h.slots[1]
            slot.ability.SetText=function(self,value) self.cleared=value end
            slot.ability.SetFormattedText=function(self,format,id)
                self.format=format;self.relayID=id
            end
            slot.ability.GetText=function() error('forbidden text readback') end
            journal:DetectAbility(42,secret,secret,100);controller:Refresh()
            assert(h:IsShown() and rawequal(slot.ability.relayID,secret))
            assert(h.heading:GetText():find('Last detected spells:',1,true))
            assert(slot.ability.format=='|cff9999991:|r |cffffffff%s|r')
            assert(h.point[3] < book.spellLink.point[3], 'hint below reference input')
            assert(h.point[3]-h:GetHeight() >= book.message.point[3], 'feedback below hint')
            GameTooltip={SetOwner=function() end,SetSpellByID=function(self,id) self.id=id end,
                Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end}
            slot.scripts.OnEnter(slot);assert(GameTooltip.shown and rawequal(GameTooltip.id,secret))
            slot.scripts.OnLeave();assert(not GameTooltip.shown)
            GameTooltip.SetSpellByID=function() error('restricted API') end
            slot.scripts.OnEnter(slot);assert(not GameTooltip.shown)
            journal:AcknowledgeDetectedAbility(42,20793);controller:Refresh()
            assert(not h:IsShown() and slot.ability.cleared=='')
            for _,item in ipairs(h.slots) do
                item.ability.SetFormattedText=slot.ability.SetFormattedText
                item.ability.GetText=function() error('forbidden text readback') end
            end
            for bar=101,104 do journal:DetectAbility(42,secret,secret,bar) end
            controller:Refresh()
            for index,item in ipairs(h.slots) do
                assert(item:IsShown() and rawequal(item.ability.relayID,secret))
                assert(item.ability.format:find(index .. ':',1,true))
                assert(item:GetWidth()==145 and item.point[2]==(index-1)*146)
            end
            local third=h.slots[3].current
            h.slots[2].scripts.OnMouseUp(h.slots[2],'RightButton')
            assert(h.slots[2].current==third and not h.slots[4]:IsShown())
            journal:DetectAbility(42,secret,secret,102);controller:Refresh()
            assert(not h.slots[4]:IsShown(), 'dismissal survives polling')
            h.slots[2].ability.SetFormattedText=function() error('rejected rendering') end
            controller:Refresh()
            assert(h:IsShown() and h.slots[1]:IsShown() and not h.slots[2]:IsShown() and h.slots[3]:IsShown())
            h:Refresh(nil)
            assert(not h:IsShown())
            for _,item in ipairs(h.slots) do assert(not item.current) end
        ''')


if __name__=='__main__':
    unittest.main(verbosity=2)
