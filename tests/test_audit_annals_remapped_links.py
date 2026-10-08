"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from test_player_names_preservation import full_client
from test_account_sections import account

for section in ('lore', 'treasure'):
    lua = full_client()
    account(lua)
    lua.globals().auditSection = section
    lua.execute(r'''
        local section=auditSection
        local create=section=='lore' and ns.CreateLoreJournal or ns.CreateTreasureJournal
        local function observe(j,name)
            if section=='lore' then return assert(j:Create('mystery',{title=name,origin='manual'})) end
            return assert(j:Record(nil,{name=name,form='world',category='container'},
                {context='world',location={},facts={sighted=true},capture='missing',items={}},'manual'))
        end
        local personal,other={},{ }
        scope(2,false)
        local original=create(personal)
        local function annals(source)
            local shell=ns.CreateFieldbookShell()
            shell:RegisterSection(section,{title='Source',build=function() end})
            return ns.InitializeAnnals(shell,{[section]={journal=source,Select=function() end}})
        end
        AzerothFieldbookAnnalsDB={}
        now=100
        local c=annals(original)
        local entry=observe(original,'Personal discovery')
        local event=c.journal.db.events[1]
        assert(event and event.kind=='discovery' and event.link.section==section)
        assert(c:Resolve(event.link)==entry, 'precondition: original link must resolve to the observed source')
        local originalKey,originalIdentity=event.link.key,event.link.identity
        now=200
        observe(create(other),'Another character discovery')
        scope(1,true)
        ns.SelectSectionStorage(section,other)
        scope(2,true)
        local shared=create(ns.SelectSectionStorage(section,personal))
        c=annals(shared)
        local found
        for id,e in pairs(shared.entries or shared.kinds) do
            if (e.title or e.name)=='Personal discovery' then found=e end
        end
        assert(found and found.id~=originalKey, 'precondition: original source must survive under a remapped ID')
        assert(found.reference==entry.reference and found.created==entry.created, 'import must retain source identity evidence')
        assert(#c.journal.events==1 and c.journal.db.events[1]==event, 'historical discovery must remain intact')
        assert(event.link.key==originalKey and event.link.identity==originalIdentity)
        assert(c:Resolve(event.link)==found, 'Remapped link must resolve to its original owner')
    ''')
