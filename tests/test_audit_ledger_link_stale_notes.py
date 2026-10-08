"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from ledger_test_harness import new_ledger

lua = new_ledger(ui=True)
lua.execute(r'''
local function press(parent,label)
    for _,object in ipairs(objects) do
        if object.parent==parent and object.GetText and object:GetText()==label and object.scripts.OnClick then
            assert(object:IsEnabled(), 'Expected an enabled user-facing action: '..label)
            object.scripts.OnClick(object)
            return
        end
    end
    error('Button unavailable: '..label)
end
local source=assert(j:Manual({name='Same contact, first record'}))
local destination=assert(j:Manual({name='Same contact, second record'}))
local sourceNote='Source note: rear entrance'
local destinationNote='Destination note: ask upstairs'
assert(j:Annotate(source.id,sourceNote,{repair=true},''))
assert(j:Annotate(destination.id,destinationNote,{banker=true},''))

-- Merely visit the destination's Edit panel. No unsaved text or role edits.
c:Select(destination.id)
c:Notes()
local editor=c.panels.notes
assert(editor.edit:GetText()==destinationNote)
assert(editor.roles.banker and not editor.roles.repair)
c:ClosePanel()

-- Perform the ordinary explicit identity link through its production callback.
c:Select(source.id)
c:Identity()
local identity=c.panels.identity
identity.destination=destination.id
press(identity,'Confirm same individual')
local combined=assert(j:Get(destination.id))
assert(not j:Get(source.id))
assert(combined.note:find(sourceNote,1,true) and combined.note:find(destinationNote,1,true))
assert(combined.manualRoles.repair and combined.manualRoles.banker)

-- A clean cached editor refreshes to the merged saved baseline.
c:Notes()
assert(c.panels.notes==editor)
assert(editor.edit:GetText()==combined.note and editor.roles.repair and editor.roles.banker)
editor.edit:SetText(editor.edit:GetText()..' -- additional direction')
press(editor,'Save')
local persisted=assert(ns.CreateLedgerJournal(saved):Get(destination.id))
assert(persisted.note:find(sourceNote,1,true) and persisted.note:find('additional direction',1,true))
assert(persisted.manualRoles.repair and persisted.manualRoles.banker)
-- Preserve a real dirty draft, including after section switching, and reject stale Save.
c:Notes();editor.edit:SetText('Unsaved directions');editor.roles.banker=nil
c:ClosePanel()
assert(j:Annotate(destination.id,'Newer saved directions',{repair=true,banker=true},''))
c:Notes()
assert(editor.edit:GetText()=='Unsaved directions' and not editor.roles.banker)
press(editor,'Save')
assert(j:Get(destination.id).note=='Newer saved directions' and j:Get(destination.id).manualRoles.banker)
assert(editor.edit:GetText()=='Unsaved directions')
press(editor,'Reload saved notes')
assert(editor.edit:GetText()=='Newer saved directions' and editor.roles.banker)
editor.edit:SetText('Reviewed directions');press(editor,'Save')
assert(j:Get(destination.id).note=='Reviewed directions')
''')
