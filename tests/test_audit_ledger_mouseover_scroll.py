"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from ledger_test_harness import new_ledger

for title in ('', 'Bowyer', 'mixed'):
    lua = new_ledger(ui=True)
    lua.globals().fixture_title = title
    lua.execute(r'''
    sublabel=fixture_title
    local chosen
    for index=1,100 do
        if fixture_title=='mixed' then sublabel=index%2==0 and 'Bowyer' or '' end
        name=string.format('Contact %03d',index)
        chosen=visit(1000+index,string.format('%X',index),{})
    end
    flush()
    assert(L.Count(saved.contacts)==100)
    assert(j:Get(j.db.aliases[L.Unit('mouseover').guid])==chosen)
    c.state.query='No matching contacts';c.state.favourites=true
    assert(c:OpenAtUnit('mouseover'))
    assert(c.state.query=='' and not c.state.favourites)
    assert(c.state.selected==chosen.id)
    assert(m.name:GetText()==chosen.name)

    local index
    for number,row in ipairs(c.rows) do if row.contact.id==chosen.id then index=number;break end end
    assert(index==100)
    local expectedTop=c.contactTops[index]
    local actualScroll=c.state.contactScroll
    local viewport=m.contactList:GetHeight()
    assert(expectedTop>=actualScroll and expectedTop+ (fixture_title=='' and 63 or 77)<=actualScroll+viewport)
    local present=false
    for _,row in ipairs(m.rows) do if row.id==chosen.id and row:IsShown() then present=true end end
    assert(present)
    local expectedRowHeight=fixture_title=='' and 63 or 77
    assert(expectedTop==(fixture_title=='mixed' and 50*63+49*77 or 99*expectedRowHeight))
    assert(actualScroll==(fixture_title=='mixed' and 50*63+50*77 or 100*expectedRowHeight)-viewport)
    ''')
