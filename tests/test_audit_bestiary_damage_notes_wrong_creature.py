"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from ui_test_harness import new_ui_client

lua = new_ui_client(['Scrollbars.lua', 'SharingReport.lua', 'BestiaryJournal.lua',
                     'ActionButtons.lua', 'WindowPositions.lua', 'UIScale.lua', 'FieldbookShell.lua', 'BestiaryPages.lua', 'BestiaryBook.lua'])
lua.execute(r'''
StaticPopupDialogs={};YES='Yes';NO='No'
db={windowPositions={AzerothFieldbookBestiaryDamageNotes={left=1400,top=700}}}
journal=ns.CreateBestiaryJournal(db,function() return npcID end)
controller=ns.CreateBestiaryBook(journal)
npcID=42;controller:OpenAtUnit('target')
assert(journal:AddDamage(42,9,10,20,9))
npcID=43;assert(journal:Observe('target'))
assert(journal:AddDamage(43,9,70,90,9))
controller:Refresh()
local book=AzerothFieldbookBestiarySection
local function selectRow(id)
    for _,row in ipairs(book.rows) do
        if row.id==id then row.scripts.OnClick(row);return end
    end
    error('Missing list row '..id)
end
selectRow(42)
book.lootButton.scripts.OnClick(book.lootButton)
assert(book.lootMode==false and book.damageRows[1]:IsShown())
book.damageRows[1].scripts.OnClick(book.damageRows[1])
local panel=book.notesForm
local text=panel.rows[1].text:GetText()
assert(panel:IsShown() and text:find('10%-20'))
assert(panel.parent==book.damageForm.parent and panel:GetWidth()==book.damageForm:GetWidth())
assert(panel.point[3]==book.damageForm.point[3] and panel.point[4]==book.damageForm.point[4]
    and panel.point[5]==book.damageForm.point[5])
book.damageRows[1].scripts.OnClick(book.damageRows[1]);assert(not panel:IsShown())
book.damageRows[1].scripts.OnClick(book.damageRows[1]);assert(panel:IsShown())
book.damageButton.scripts.OnClick(book.damageButton)
book.damageForm.scripts.OnShow(book.damageForm)
assert(not panel:IsShown() and book.damageForm:IsShown(),'Other ability overlays replace damage notes')
book.damageRows[1].scripts.OnClick(book.damageRows[1])
panel.scripts.OnShow(panel)
assert(panel:IsShown() and not book.damageForm:IsShown())
assert(not book.abilityPanel:IsShown())
book.lootButton.scripts.OnClick(book.lootButton)
-- This harness does not dispatch visibility events automatically.
panel.scripts.OnHide(panel)
assert(not panel:IsShown() and book.abilityPanel:IsShown() and book.lootMode)
book.lootButton.scripts.OnClick(book.lootButton)
book.damageRows[1].scripts.OnClick(book.damageRows[1]);panel.scripts.OnShow(panel)
assert(panel:IsShown())


assert(#journal:DamageNotes(42,9)==1 and #journal:DamageNotes(43,9)==1)
selectRow(43)
assert(not panel:IsShown())
panel.rows[1].remove.scripts.OnClick(panel.rows[1].remove)
assert(#journal:DamageNotes(42,9)==1 and #journal:DamageNotes(43,9)==1)
selectRow(42)
book.damageRows[1].scripts.OnClick(book.damageRows[1])
assert(panel:IsShown())
panel.rows[1].remove.scripts.OnClick(panel.rows[1].remove)
assert(#journal:DamageNotes(42,9)==0 and journal.entries[42].damage[9]==nil)
assert(#journal:DamageNotes(43,9)==1)
-- Keyboard navigation invalidates the same popup ownership.
selectRow(43);book.damageRows[1].scripts.OnClick(book.damageRows[1])
assert(panel:IsShown());assert(controller:CycleEntry(1));assert(not panel:IsShown())
panel.rows[1].remove.scripts.OnClick(panel.rows[1].remove)
assert(#journal:DamageNotes(43,9)==1)
-- Paged rows retain the actual observation, not just a reusable list index.
for i=1,8 do assert(journal:AddDamage(42,9,10+i,20+i,9)) end
selectRow(42);book.damageRows[1].scripts.OnClick(book.damageRows[1])
panel.next.scripts.OnClick(panel.next)
local row=panel.rows[1];local displayed=row.observation;local index=row.noteIndex
assert(index>1 and journal:DamageNotes(42,9)[index]==displayed)
assert(journal:RemoveDamageNote(42,9,1))
row.remove.scripts.OnClick(row.remove)
assert(#journal:DamageNotes(42,9)==7,'stale shifted index must be rejected')
selectRow(43);selectRow(42);book.damageRows[1].scripts.OnClick(book.damageRows[1])
panel.rows[1].remove.scripts.OnClick(panel.rows[1].remove)
assert(#journal:DamageNotes(42,9)==6 and #journal:DamageNotes(43,9)==1)
journal=ns.CreateBestiaryJournal(db,function() return npcID end)
assert(#journal:DamageNotes(42,9)==6 and #journal:DamageNotes(43,9)==1)
''')
