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
    GameTooltip={lines={},SetOwner=function(self,owner) self.owner=owner end,
        IsOwned=function(self,owner) return self.owner==owner end,
        Show=function(self) self.shown=true end,Hide=function(self) self.shown=false end,
        IsShown=function(self) return self.shown end,
        GetName=function() return 'GameTooltip' end,NumLines=function(self) return #self.lines end,
        SetText=function(self,text) self.lines={text} end,
        AddLine=function(self,text) self.lines[#self.lines+1]=text end}
    local lock
    for _,object in ipairs(objects) do if object.lockIcon then lock=object;break end end
    assert(lock)
    local _,entry=next(journal.entries);assert(entry)
    entry.confirmed=false;entry.unchangedKills=7
    journal:SetAutoLockKills(10)
    lock.scripts.OnEnter(lock)
    assert(table.concat(GameTooltip.lines,' '):find('3 kills until auto-lock.',1,true))
    assert(table.concat(GameTooltip.lines,' '):find('Last reset: none recorded.',1,true))
    entry.unchangedKills=8;journal:Touch();controller:Refresh()
    assert(table.concat(GameTooltip.lines,' '):find('2 kills until auto-lock.',1,true),
        'the visible counter updates without leaving and re-entering the padlock')
    journal:SetAutoLockEnabled(false);lock.scripts.OnEnter(lock)
    assert(not table.concat(GameTooltip.lines,' '):find('until auto-lock',1,true))
    journal:SetAutoLockEnabled(true);entry.unchangedKills=10;lock.scripts.OnEnter(lock)
    assert(not table.concat(GameTooltip.lines,' '):find('until auto-lock',1,true))
    entry.unchangedKills=9;lock.scripts.OnEnter(lock)
    assert(table.concat(GameTooltip.lines,' '):find('1 kill until auto-lock.',1,true))
    entry.confirmed=true;lock.scripts.OnEnter(lock)
    assert(not table.concat(GameTooltip.lines,' '):find('until auto-lock',1,true))
    journal:SetEntryConfirmed(entry.id,false);controller:Refresh()
    assert(table.concat(GameTooltip.lines,' '):find('10 kills until auto-lock.',1,true))
    assert(table.concat(GameTooltip.lines,' '):find('Last reset: manually unlocked.',1,true))
    journal:SetEntryConfirmed(entry.id,true,true);controller:Refresh()
    assert(table.concat(GameTooltip.lines,' '):find('|cff80d0ff[Auto-locked]|r',1,true))
    assert(not table.concat(GameTooltip.lines,' '):find('until auto-lock',1,true))
    lock.scripts.OnLeave(lock)
    journal:SetEntryConfirmed(entry.id,false);controller:Refresh()
    assert(not GameTooltip:IsShown(),'refresh must not reopen a tooltip after mouse leave')
    GameTooltip:SetOwner({});GameTooltip:SetText('Another tooltip');GameTooltip:Show()
    journal:Touch();controller:Refresh()
    assert(GameTooltip.lines[1]=='Another tooltip','refresh must not replace another control tooltip')
""")
print('PASS: lock tooltip remaining kills, disabled, threshold and locked states')
