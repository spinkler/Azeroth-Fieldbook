"""Durable and timestamp-era references across account imports and deletion."""
from test_player_names_preservation import full_client
from test_account_sections import account
from ui_test_harness import ROOT

for order in (False, True):
    lua=full_client();account(lua);lua.globals().reverse=order
    lua.execute(r'''
    local personal,other={},{}
    local a=ns.CreateGatheringJournal(personal);local b=ns.CreateGatheringJournal(other)
    local id=a:Discover('herb','Peacebloom',200,'Elwynn')
    b:Discover('herb','Peacebloom',100,'Elwynn')
    -- Simulate timestamp-era saved data before migration.
    personal.entries[id].reference=nil;other.entries[id].reference=nil
    a=ns.CreateGatheringJournal(personal);b=ns.CreateGatheringJournal(other)
    local own=a.entries[id].reference
    local legacy=id..'@:200'
    assert(a:Reference(legacy)==a.entries[id])
    local function imports(key,db) scope(key,true);return ns.SelectSectionStorage('gathering',db) end
    local shared
    if reverse then imports(2,other);shared=imports(1,personal)
    else imports(1,personal);shared=imports(2,other) end
    local j=ns.CreateGatheringJournal(shared)
    assert(j:Reference(own)==j.entries[id] and j:Reference(legacy)==j.entries[id])
    assert(j.entries[id].firstSeen==100)
    local canonical=j.entries[id].reference
    assert(ns.CreateGatheringJournal(personal):Reference(canonical)==personal.entries[id])
    assert(imports(1,personal)==shared and j.entries[id].firstSeen==100)
    j=ns.CreateGatheringJournal(shared)
    assert(j:Reference(legacy)==j.entries[id])
    -- A replacement, even at the identical timestamp, cannot inherit old identity.
    j.entries[id]=nil
    j:Discover('herb','Peacebloom',200,'Elwynn')
    assert(not j:Reference(own) and not j:Reference(legacy))
    assert(j.entries[id].reference~=canonical)
    scope(1,false)
    assert(ns.CreateGatheringJournal(ns.SelectSectionStorage('gathering',personal)):Reference(own))
    ''')

for section in ('lore','treasure'):
    for legacy in (False,True):
        lua=full_client();account(lua);lua.globals().section=section;lua.globals().legacy=legacy
        lua.execute(r'''
        local create=section=='lore' and ns.CreateLoreJournal or ns.CreateTreasureJournal
        local function observe(j,name)
            if section=='lore' then return assert(j:Create('mystery',{title=name})) end
            return assert(j:Record(nil,{name=name,form='world',category='container'},
                {context='world',location={},facts={sighted=true},capture='missing',items={}},'manual'))
        end
        local personal,other={},{}
        local a,b=create(personal),create(other)
        now=100;local mine=observe(a,'Mine');local theirs=observe(b,'Other')
        assert(mine.id==theirs.id and mine.created==theirs.created)
        local originalID=mine.id
        if section=='lore' and legacy then mine.reference=nil;a=create(personal);mine=a:Get(originalID) end
        if section=='lore' then AzerothFieldbookLoreDB=personal else AzerothFieldbookTreasureDB=personal end
        local link={section=section,key=originalID,identity=section=='lore' and legacy and tostring(mine.created) or mine.reference}
        local function controller(source)
            local shell=ns.CreateFieldbookShell();shell:RegisterSection(section,{title='Source',build=function() end})
            return ns.InitializeAnnals(shell,{[section]={journal=source,Select=function() end}})
        end
        local c=controller(a);assert(c:Resolve(link)==mine)
        scope(1,true);ns.SelectSectionStorage(section,other)
        scope(2,true);local shared=create(ns.SelectSectionStorage(section,personal))
        c=controller(shared)
        local target=assert(c:Resolve(link));assert((target.title or target.name)=='Mine' and target.id~=originalID)
        scope(2,true);shared=create(ns.SelectSectionStorage(section,personal));c=controller(shared)
        assert(c:Resolve(link).reference==mine.reference)
        local records=shared.entries or shared.kinds
        local clone=ns.Lore.Copy(target);clone.id='duplicate';records.duplicate=clone
        assert(not c:Resolve(link),'ambiguous durable ownership must be unavailable')
        records.duplicate=nil
        records[target.id]=nil
        if section=='lore' then shared.db.entries[target.id]=nil else shared.db.kinds[target.id]=nil end
        assert(not c:Resolve(link),'equal timestamps and colliding local keys must never cross owners')
        scope(2,false);c=controller(create(ns.SelectSectionStorage(section,personal)))
        assert(c:Resolve(link)==mine,'retained personal original remains available')
        ''')

for reverse in (False,True):
    lua=full_client();account(lua);lua.globals().reverse=reverse
    lua.execute(r'''
    local personal,other={},{}
    local a,b=ns.CreateAnglingJournal(personal),ns.CreateAnglingJournal(other)
    local input={name='Shared fish',itemID=999}
    local mine=a:Ensure('item',input,'recorded',100)
    local theirs=b:Ensure('item',input,'recorded',100)
    local own=mine.origin.key
    local legacy=mine.id..'@'..personal.origin..':100'
    -- An actual timestamp-era store has not completed the alias migration.
    personal.loreReferencesPrepared=nil
    a=ns.CreateAnglingJournal(personal);assert(a:Reference(legacy)==mine)
    local function imports(key,db) scope(key,true);return ns.SelectSectionStorage('angling',db) end
    local shared
    if reverse then imports(2,other);shared=imports(1,personal)
    else imports(1,personal);shared=imports(2,other) end
    local j=ns.CreateAnglingJournal(shared);local target=assert(j:Reference(own))
    assert(j:Reference(legacy)==target)
    assert(ns.CreateAnglingJournal(personal):Reference(target.origin.key)==mine)
    assert(imports(1,personal)==shared)
    assert(ns.CreateAnglingJournal(shared):Reference(legacy)==target)
    target.removed=true
    assert(not j:Reference(own) and not j:Reference(legacy))
    scope(1,false);assert(ns.CreateAnglingJournal(ns.SelectSectionStorage('angling',personal)):Reference(own)==mine)
    ''')
print('PASS: reference migration, import order, deduplication, ambiguity, deletion, reload and opt-out')
