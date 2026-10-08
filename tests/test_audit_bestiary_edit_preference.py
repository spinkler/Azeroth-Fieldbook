"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from ui_test_harness import new_ui_client

lua = new_ui_client(['Scrollbars.lua', 'SharingReport.lua', 'BestiaryJournal.lua',
                     'ActionButtons.lua', 'FieldbookShell.lua', 'BestiaryPages.lua', 'BestiaryBook.lua'])
lua.execute(r'''
StaticPopupDialogs={};YES='Yes';NO='No'
C_Spell={GetSpellName=function(id) if id==12544 then return 'Frost Armor' end end,
    GetSpellLink=function(id) return '|Hspell:'..id..'|h[Frost Armor]|h' end}
db={}
journal=ns.CreateBestiaryJournal(db,function() return 42 end)
controller=ns.CreateBestiaryBook(journal)
controller:OpenAtUnit('target')
assert(journal:AddManual(42,'Frost Armor','Original note','12544'))
controller:Refresh()
local book=AzerothFieldbookBestiarySection
local row=book.abilities[1]
row.tooltipCheck:SetChecked(false)
row.tooltipCheck.scripts.OnClick(row.tooltipCheck)
assert(journal.entries[42].abilities['Frost Armor'].showInTooltip==false)
assert(#journal:ConfirmedNames(42)==0)
row.link.scripts.OnClick(row.link)
assert(book.manualName:GetText()=='Frost Armor')
book.manualNote:SetText('Updated note only')
book.confirmAbilityButton.scripts.OnClick(book.confirmAbilityButton)
assert(journal.entries[42].abilities['Frost Armor'].note=='Updated note only')
assert(#journal:ConfirmedNames(42)==0 and row.tooltipCheck:GetChecked()==false)
journal=ns.CreateBestiaryJournal(db,function() return 42 end)
assert(#journal:ConfirmedNames(42)==0)
''')
