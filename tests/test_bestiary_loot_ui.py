"""Quality filtering must affect presentation only, including uncached items."""
from test_locations import LocationsWindowTests, ROOT
lua = LocationsWindowTests().client(book=True)
for module in ['SharingReport.lua', 'RumoursWindow.lua']:
    lua.execute((ROOT / module).read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
lua.execute(r"""
    ns.InstallSharingRecords(j)
    e.loot={samples=10,items={[100]={quantity=3,drops=2},[101]={quantity=1,drops=1},[102]={quantity=2,drops=2}}}
    local qualities={[100]=0,[101]=3}
    function GetItemInfo(id) return 'Item '..id,nil,qualities[id] end
    book=ns.CreateBestiaryBook(j);book:OpenAtUnit('target')
    local b=AzerothFieldbookBestiarySection
    eq(b.spine.point[2],306)
    eq(b.rows[1].point[2],42);eq(b.rows[1]:GetWidth(),236)
    eq(b.creatureScrollBar.point[2],282)
    assert(b.letterButtons[1].point[2]+b.letterButtons[1]:GetWidth()<b.rows[1].point[2])
    for _,control in pairs(b.typeButtons) do assert(control.parent==b.listFilterMenu) end
    assert(b.review.parent==b.listFilterMenu and b.locationsButton.parent==b.listFilterMenu and b.ranksButton.parent==b.listFilterMenu)
    eq(b.summaryArea.point[2],342);eq(b.summaryArea:GetWidth(),594)
    eq(b.modelBorder.point[2]+b.modelBorder:GetWidth(),571)
    eq(b.model.point[2]+b.model:GetWidth(),569)
    eq(b.damageBorder.point[2],579);eq(b.damageBorder:GetWidth(),346)
    for _,panel in ipairs({b.offensePicker,b.defensePicker,b.behaviourPicker}) do
        eq(panel.point[4],342);eq(panel:GetWidth(),593)
    end
    eq(b.abilities[1].point[2]+b.abilities[1]:GetWidth(),935)
    eq(b.manualNote.point[2]+b.manualNote:GetWidth(),935)
    local qualityCount=0
    for _,o in ipairs(objects) do
        if o.parent==b.lootFilterMenu and o.kind=='CheckButton' then qualityCount=qualityCount+1 end
    end
    eq(qualityCount,7)
    for _,row in ipairs(b.abilities) do
        eq(row.accept.strata,'MEDIUM');eq(row.reject.strata,'MEDIUM')
        assert(row.accept:GetFrameLevel()<b.lootFilterMenu:GetFrameLevel())
    end
    b.listFilterButton.scripts.OnClick();assert(b.listFilterMenu:IsShown())
    local all=b.filterControls['All creatures'].control
    local humanoid=b.filterControls.Humanoid.control
    assert(all.afbSelected and humanoid:IsEnabled())
    humanoid.scripts.OnClick();assert(humanoid.afbSelected and b.typeButtons.Humanoid.afbSelected)
    b.typeButtons['All creatures'].scripts.OnClick();assert(all.afbSelected and not humanoid.afbSelected)
    local pending=b.filterControls.Pending.control
    pending.scripts.OnClick();assert(pending.afbSelected and b.review.afbSelected)
    b.review.scripts.OnClick();assert(not pending.afbSelected)
    local locations=b.filterSubmenus.Locations
    local ranks=b.filterSubmenus.Ranks
    b.filterControls.Locations.control.scripts.OnEnter()
    assert(locations:IsShown() and b.listFilterMenu:IsShown() and b.locationFrame==locations)
    assert(locations.parent==b.listFilterMenu and locations.point[2]==b.filterControls.Locations.control)
    local location=locations.rows[1]
    location:SetChecked(true);location.scripts.OnClick(location)
    assert(b.filterControls.Locations.control.afbSelected and b.locationsButton:GetText()=='Locations (1)')
    locations.clear.scripts.OnClick();assert(not b.filterControls.Locations.control.afbSelected)
    for i=1,20 do e.locations['Extra zone '..i]=true end
    locations:Refresh();assert(locations.scroll:GetHeight()==208)
    local allocated=#objects;locations:Refresh();eq(#objects,allocated)
    b.filterControls.Ranks.control.scripts.OnEnter()
    assert(ranks:IsShown() and not locations:IsShown() and b.rankFrame==ranks)
    ranks.rows[1]:SetChecked(true);ranks.rows[1].scripts.OnClick(ranks.rows[1])
    assert(b.filterControls.Ranks.control.afbSelected)
    ranks.clear.scripts.OnClick();assert(not b.filterControls.Ranks.control.afbSelected)
    b.filterControls.Ranks.control.scripts.OnClick();assert(ranks:IsShown())
    b.filterControls.Locations.control.scripts.OnEnter()
    b.listFilterMenu:Hide();assert(not locations:IsShown() and not ranks:IsShown())
    b.listFilterButton.scripts.OnClick();assert(b.listFilterMenu:IsShown())
    b.listFilterButton.scripts.OnClick();assert(not b.listFilterMenu:IsShown())
    eq(b.listFilterMenu.point[1],'TOPLEFT');eq(b.listFilterMenu.point[2],b.listFilterButton)
    eq(b.listFilterMenu.point[3],'BOTTOMLEFT');eq(b.listFilterMenu.point[4],0);eq(b.listFilterMenu.point[5],0)
    local function outsideClick(menu,control,submenu)
        local hover
        function menu:IsMouseOver() return hover==self end
        function control:IsMouseOver() return hover==self end
        if submenu then function submenu:IsMouseOver() return hover==self end end
        menu:Show()
        for _,inside in ipairs({menu,control,submenu}) do
            if inside then
                hover=inside;if submenu then submenu:Show() end
                menu.scripts.OnEvent(menu,'GLOBAL_MOUSE_DOWN','LeftButton')
                assert(menu:IsShown(),'Menu, trigger and submenu clicks remain interactive')
            end
        end
        hover=nil;menu.scripts.OnEvent(menu,'GLOBAL_MOUSE_DOWN','RightButton')
        assert(not menu:IsShown(),'Outside clicks dismiss the popup')
        if submenu then assert(not submenu:IsShown(),'Slide-outs close with their parent') end
        control.scripts.OnClick();assert(menu:IsShown(),'Button reopens dismissed menu')
        hover=control;menu.scripts.OnEvent(menu,'GLOBAL_MOUSE_DOWN','LeftButton')
        control.scripts.OnClick();assert(not menu:IsShown(),'Button still toggles open menu closed')
    end
    outsideClick(b.listFilterMenu,b.listFilterButton,locations)
    outsideClick(b.lootFilterMenu,b.lootFilter)
    local function shown()
        local n=0;for _,row in ipairs(b.lootRows) do if row:IsShown() then n=n+1 end end;return n
    end
    eq(shown(),3)
    assert(b.damageScrollBar:IsShown())
    eq(b.lootFilter.point[4],-26);eq(b.damageHeading:GetWidth(),276)

    b.lootFilter.scripts.OnClick();assert(b.lootFilterMenu:IsShown())
    b.lootFilter.scripts.OnClick();assert(not b.lootFilterMenu:IsShown())
    local function toggle(text)
        for _,o in ipairs(objects) do
            if o.parent==b.lootFilterMenu and o.label and type(o.label)=='table' and o.label.text==text then
                o:SetChecked(false);o.scripts.OnClick(o);return
            end
        end
        error('missing quality '..text)
    end
    toggle('Poor');eq(shown(),2)
    toggle('Unknown');eq(shown(),1)
    qualities[102]=3;b.lootFilter.scripts.OnEvent();eq(shown(),2)
    toggle('Rare');eq(shown(),0);eq(b.noDamage.text,'No drops match the quality filter.')
    assert(not b.damageScrollBar:IsShown())
    eq(b.lootFilter.point[4],-6);eq(b.damageHeading:GetWidth(),296)

    assert(b.lootFilter:IsShown(),'Recorded drops keep the filter available even when all qualities are hidden')
    b.lootFilter.scripts.OnClick(b.lootFilter,'RightButton');eq(shown(),3)
    b.listFilterButton.scripts.OnClick(b.listFilterButton,'RightButton')
    eq(e.loot.samples,10);eq(e.loot.items[100].quantity,3);eq(e.loot.items[102].drops,2)
    b.lootButton.scripts.OnClick();assert(not b.lootFilter:IsShown() and not b.lootFilterMenu:IsShown())
    b.lootButton.scripts.OnClick();assert(b.lootFilter:IsShown())
    b.lootFilter.scripts.OnClick();assert(b.lootFilterMenu:IsShown())
    e.loot={samples=10,items={}}
    b.review.scripts.OnClick()
    assert(not b.lootFilter:IsShown() and not b.lootFilterMenu:IsShown(),'Empty observed corpses have no loot to filter')
    b.rumoursButton.scripts.OnClick()
    local rumours=AzerothFieldbookRumours
    rumours.scripts.OnShow(rumours) -- Dispatch the native visibility event in this harness.
    assert(rumours:IsShown() and rumours.parent==b.damageBorder)
    eq(rumours:GetWidth(),b.damageBorder:GetWidth());eq(rumours:GetHeight(),b.damageBorder:GetHeight())
    assert(rumours.title:IsShown() and not rumours.closeButton:IsShown())
    assert(not rumours.paper:IsShown() and not b.damageHeading:IsShown() and not b.damageScroll:IsShown())
    assert(-rumours.area.point[3]+rumours.area:GetHeight()<=rumours:GetHeight())
    b.rumoursButton.scripts.OnClick();assert(not rumours:IsShown())
    b.rumoursButton.scripts.OnClick();b.lootButton.scripts.OnClick()
    assert(not rumours:IsShown() and not b.lootMode,'Show Damage replaces Rumours')
    b.lootButton.scripts.OnClick()
    e.loot=nil;b.review.scripts.OnClick();assert(not b.lootFilter:IsShown())
    e.loot={samples=1,items={[103]={quantity=1,drops=1}}}
    b.review.scripts.OnClick();assert(b.lootFilter:IsShown(),'First recorded item enables filtering')

""")
print('PASS: loot quality filtering, unknown cache refresh, toggling and record preservation')
