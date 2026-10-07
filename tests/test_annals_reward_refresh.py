"""A4: active completion snapshots improve before finalization, never afterwards."""
from annals_test_harness import client
for choices in (0,1,2):
    for reverse in (False,True):
        lua=client();lua.globals().choiceCount=choices;lua.globals().reverse=reverse
        lua.execute("""
            missing=true;t:Event('QUEST_COMPLETE')
            missing=false;t:Event('QUEST_ITEM_UPDATE')
            -- A later unreadable update must not downgrade readable evidence.
            missing=true;t:Event('QUEST_ITEM_UPDATE')
            if reverse then t:Event('QUEST_TURNED_IN',42,500,100) end
            t:RewardRequested(choiceCount)
            if not reverse then t:Event('QUEST_TURNED_IN',42,500,100) end
            advance(1)
            assert(#db.events==1)
            local r=db.events[1].reward
            assert(r.status=='observed' and r.automatic[1].itemID==201)
            if choiceCount==2 then assert(r.chosen.itemID==102)
            elseif choiceCount==1 then assert(r.single.itemID==101)
            else assert(r.choiceStatus=='none') end
            missing=false;quest=99;t:Event('QUEST_ITEM_UPDATE');t:RewardRequested(1);advance(1)
            assert(#db.events==1 and db.events[1].reward==r)
        """)
for boundary in ('unreadable','closed','changed','expired'):
    lua=client();lua.globals().boundary=boundary
    lua.execute("""
        missing=true;t:Event('QUEST_COMPLETE')
        if boundary=='closed' then t:Event('QUEST_FINISHED') end
        if boundary=='changed' then quest=99 end
        if boundary=='expired' then advance(601) end
        missing=boundary=='unreadable';t:Event('QUEST_ITEM_UPDATE');t:RewardRequested(2)
        t:Event('QUEST_TURNED_IN',42,500,100);advance(1)
        assert(#db.events==1)
        local r=db.events[1].reward
        assert(r.status~='observed' and not r.chosen)
    """)
print('PASS: A4 delayed rewards, both callback orderings, 0/1/multiple choices, stale boundaries')

# Same quest ID and timestamp still cannot bridge two completion tokens.
lua=client()
lua.execute("""
    missing=true;t:Event('QUEST_COMPLETE');t:Event('QUEST_TURNED_IN',42,500,100)
    local token=db.pending[42].token
    missing=false;t:Event('QUEST_COMPLETE');t:Event('QUEST_ITEM_UPDATE');t:RewardRequested(2)
    assert(db.pending[42].token==token and not db.pending[42].snapshot.chosen)
    advance(1)
    assert(db.events[1].reward.status=='incomplete' and not db.events[1].reward.chosen)
""")
print('PASS: A4 repeated same-quest dialogue tokens do not rewrite an earlier pending completion')
