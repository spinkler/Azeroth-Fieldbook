"""Native close/reopen and repeat-cast cash evidence; real Lua/Ledger observers."""
import unittest
from ledger_test_harness import new_ledger
from ui_test_harness import ROOT


class PickpocketCashReopen(unittest.TestCase):
    def test_native_sequence_and_rejection_boundaries(self):
        for mode in ('native', 'reopen', 'failed_repeat', 'interrupted_repeat',
                     'expired', 'corpse', 'conflict', 'other_target', 'ambiguous',
                     'no_sources', 'fishing', 'world', 'taken', 'unconfirmed',
                     'expired_reopen', 'item_window', 'unreadable'):
            with self.subTest(mode=mode):
                lua = new_ledger()
                lua.execute((ROOT/'BestiaryLoot.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
                lua.globals().mode = mode
                lua.execute(r"""
                    AzerothFieldbookLedgerDB={};balance=1000;now=770974.246
                    function GetMoney() return balance end
                    function GetTime() return now end
                    GOLD_AMOUNT='%d Gold';SILVER_AMOUNT='%d Silver';COPPER_AMOUNT='%d Copper'
                    fire('PLAYER_ENTERING_WORLD')
                    local original='Creature-0-4621-1-137-2152-00004610C2'
                    local other='Creature-0-4621-1-137-2152-00004610FF'
                    local guid,source,dead,slots=original,original,false,1
                    function UnitGUID(unit)
                        if unit=='target' then return guid end
                        if mode=='ambiguous' and unit=='mouseover' then return other end
                    end
                    function UnitName() return 'Gnarlpine Ambusher' end
                    function UnitIsDead() return dead end
                    function IsFishingLoot() return mode=='fishing' end
                    function GetNumLootItems() return slots end
                    function GetLootSourceInfo() return source,0 end
                    function GetLootSlotType() return mode=='item_window' and 1 or 2 end
                    function GetLootSlotLink() return nil end
                    local best={entries={[2152]={personalEncountered=true}},Touch=function() end}
                    local observer=ns.StartBestiaryLoot(best)
                    local function event(e,...) observer.scripts.OnEvent(observer,e,...) end
                    event('UNIT_SPELLCAST_SENT','player','Gnarlpine Ambusher','Cast-first',921)
                    if mode~='unconfirmed' then event('UNIT_SPELLCAST_SUCCEEDED','player','Cast-first',921) end
                    now=770974.386;event('LOOT_READY')
                    now=770974.646;event('LOOT_OPENED');event('LOOT_READY')
                    now=770974.821
                    if mode=='taken' then balance=balance+2;fire('PLAYER_MONEY') end
                    if mode=='other_target' then guid=other;source=other end
                    if mode~='reopen' then
                        event('UNIT_SPELLCAST_SENT','player','Gnarlpine Ambusher','Cast-repeat',921)
                        local outcome=mode=='failed_repeat' and 'UNIT_SPELLCAST_FAILED'
                            or mode=='interrupted_repeat' and 'UNIT_SPELLCAST_INTERRUPTED'
                            or 'UNIT_SPELLCAST_SUCCEEDED'
                        event(outcome,'player','Cast-repeat',921)
                    end
                    event('LOOT_CLOSED')
                    local delay=mode=='expired_reopen' and 2 or 0
                    now=now+delay
                    if mode=='corpse' then dead=true end
                    if mode=='conflict' then source=other end
                    if mode=='no_sources' then source=nil end
                    if mode=='unreadable' then slots=nil end
                    if mode=='world' then event('PLAYER_ENTERING_WORLD') end
                    event('LOOT_READY')
                    now=770975.105+delay;event('LOOT_OPENED');event('LOOT_READY')
                    now=770975.167+delay;event('LOOT_CLOSED');event('LOOT_CLOSED')
                    now=mode=='expired' and 770977.224 or 770975.224+delay
                    if mode~='taken' then balance=balance+2;fire('PLAYER_MONEY') end
                    now=now+1.045 -- Chat trails close grace; balance must already own evidence.
                    fire('CHAT_MSG_MONEY','You loot 2 Copper');flush()
                    local cash=AzerothFieldbookLedgerDB.cashFlow
                    local matched=mode=='native' or mode=='reopen' or mode=='failed_repeat'
                        or mode=='interrupted_repeat' or mode=='taken'
                    assert(#cash.entries==1 and cash.income==2 and cash.entries[1].amount==2)
                    assert(cash.entries[1].context==(matched and 'Pickpocketed cash' or 'Looted cash'),mode..': '..tostring(cash.entries[1].context))
                    if matched then assert(cash.entries[1].counterparty=='Gnarlpine Ambusher') end
                    -- Evidence is single-use; corpse money remains separate and unlabelled as a pick.
                    dead=true;event('LOOT_READY');event('LOOT_CLOSED')
                    balance=balance+10;fire('PLAYER_MONEY');fire('CHAT_MSG_MONEY','You loot 10 Copper');flush()
                    assert(cash.entries[1].context=='Looted cash' and cash.income==12)
                    if matched then assert(#cash.entries==2 and cash.entries[2].amount==2) end
                """)


if __name__ == '__main__':
    unittest.main()
