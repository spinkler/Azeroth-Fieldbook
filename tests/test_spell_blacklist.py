"""The retired blacklist has no runtime or Options controls."""
from pathlib import Path
from ui_test_harness import new_ui_client
root=Path(__file__).resolve().parents[1]
assert not (root/'SpellBlacklist.lua').exists()
assert 'SpellBlacklist.lua' not in (root/'AzerothFieldbook.toc').read_text()
lua=new_ui_client(['Scrollbars.lua','BestiaryJournal.lua','ActionButtons.lua','FieldbookShell.lua','BestiaryPages.lua','BestiaryBook.lua'])
lua.execute("journal=ns.CreateBestiaryJournal({},function() return 42 end);controller=ns.CreateBestiaryBook(journal);controller:OpenAtUnit('target');assert(AzerothFieldbookOptions.spellIDBlacklist==nil)")
print('PASS: retired spell blacklist has no runtime or Options entry')

lua.execute("""
    GameTooltip={lines={},SetOwner=function() end,Show=function() end,
        GetName=function() return 'GameTooltip' end,NumLines=function(self) return #self.lines end,
        SetText=function(self,text) self.lines={text} end,
        AddLine=function(self,text) self.lines[#self.lines+1]=text end}
    local lock
    for _,object in ipairs(objects) do if object.lockParts then lock=object;break end end
    assert(lock)
    local _,entry=next(journal.entries);assert(entry)
    entry.confirmed=false;entry.unchangedKills=7
    journal:SetAutoLockKills(10)
    lock.scripts.OnEnter(lock)
    assert(table.concat(GameTooltip.lines,' '):find('3 kills until auto-lock.',1,true))
    journal:SetAutoLockEnabled(false);lock.scripts.OnEnter(lock)
    assert(not table.concat(GameTooltip.lines,' '):find('until auto-lock',1,true))
    journal:SetAutoLockEnabled(true);entry.unchangedKills=10;lock.scripts.OnEnter(lock)
    assert(not table.concat(GameTooltip.lines,' '):find('until auto-lock',1,true))
    entry.unchangedKills=9;lock.scripts.OnEnter(lock)
    assert(table.concat(GameTooltip.lines,' '):find('1 kill until auto-lock.',1,true))
    entry.confirmed=true;lock.scripts.OnEnter(lock)
    assert(not table.concat(GameTooltip.lines,' '):find('until auto-lock',1,true))
""")
print('PASS: lock tooltip remaining kills, disabled, threshold and locked states')
