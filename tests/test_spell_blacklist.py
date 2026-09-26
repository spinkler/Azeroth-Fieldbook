"""Blacklist manager controls, pagination and Options entry point."""
from ui_test_harness import new_ui_client

lua=new_ui_client(['Scrollbars.lua','BestiaryJournal.lua','ActionButtons.lua',
                   'FieldbookShell.lua','BestiaryPages.lua','BestiaryBook.lua','SpellBlacklist.lua'])
lua.execute('''
    local ids={};for i=1,10 do ids[i]=true end
    window={}
    function window:GetBlacklist()
        local result={};for id in pairs(ids) do result[#result+1]=id end
        table.sort(result);return result
    end
    function window:AddBlacklist(value)
        local id=tonumber(value)
        if not id or id<=0 or id~=math.floor(id) then return false,'Enter a positive numeric spell ID.' end
        ids[id]=true;return true,'Added '..id
    end
    function window:RemoveBlacklist(id) ids[id]=nil end
    C_Spell={GetSpellName=function(id) return 'Spell '..id end}
    ns.SpellIDWindow=window
    function window:OpenBlacklist(message)
        if not manager then manager=ns.CreateSpellBlacklistWindow(self) end
        manager:Open(message)
    end
    journal=ns.CreateBestiaryJournal({},function() return 42 end)
    controller=ns.CreateBestiaryBook(journal);controller:OpenAtUnit('target')
    local options=AzerothFieldbookOptions
    options.spellIDBlacklist.scripts.OnClick(options.spellIDBlacklist)
    assert(manager:IsShown() and manager.pageLabel:GetText()=='Page 1 / 2')
    assert(not manager.previous.enabled and manager.next.enabled)
    manager.next.scripts.OnClick(manager.next)
    assert(manager.pageLabel:GetText()=='Page 2 / 2' and manager.previous.enabled and not manager.next.enabled)
    local remove
    for _,object in ipairs(objects) do
        if object.parent==manager and object.kind=='Button' and object:GetText()=='Remove' and object:IsShown() then remove=object;break end
    end
    remove.scripts.OnClick(remove);assert(not ids[9])
    manager.input:SetText('20793');manager.add.scripts.OnClick(manager.add)
    assert(ids[20793] and manager.input:GetText()=='')
    manager.input:SetText('bad');manager.input.scripts.OnEnterPressed(manager.input)
    assert(manager.input:GetText()=='bad' and #window:GetBlacklist()==10)
    manager:Hide();window:OpenBlacklist('Restricted ID: enter it manually.')
    assert(manager:IsShown() and ids[20793])
    local found=false
    for _,object in ipairs(objects) do
        if object.parent==manager and object.kind=='FontString' and object:GetText()=='Restricted ID: enter it manually.' then found=true end
    end
    assert(found)
    for id in pairs(ids) do ids[id]=nil end
    manager:Refresh();assert(manager.pageLabel:GetText()=='No blacklisted abilities')
''')
print('PASS: blacklist Options button, paging, remove, manual add, validation and reopen')
