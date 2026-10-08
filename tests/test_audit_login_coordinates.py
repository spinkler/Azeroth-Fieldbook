"""Regression for the October 2026 audit; synthetic production Lua/UI paths."""
from annals_test_harness import client
for scenario in ('same', 'changed', 'missing', 'known', 'unavailable', 'leaving'):
    lua=client();lua.globals().scenario=scenario
    lua.execute(r'''
    if scenario=='missing' then mapID=nil else mapID=101 end
    GetRealZoneText=function() return '' end
    GetSubZoneText=function() return '' end
    C_Map.GetPlayerMapPosition=function() if scenario=='known' then return {x=.2,y=.3} end end
    t:Event('PLAYER_ENTERING_WORLD',true,false)
    local e=db.events[1];local at,seq=e.at,e.sequence
    if scenario=='missing' then
        assert(e.mapID==nil and e.x==nil and e.y==nil)
        assert(t.loginLocation and t.loginLocation.entry==e)
    end
    if scenario=='leaving' then t:Event('PLAYER_LEAVING_WORLD') end
    mapID=(scenario=='changed' or scenario=='missing') and 102 or 101
    GetRealZoneText=function() return 'Hills' end
    GetSubZoneText=function() return 'Interior' end
    C_Map.GetPlayerMapPosition=function() if scenario~='unavailable' then return {x=.61,y=.47} end end
    advance(1)
    assert(db.events[1]==e and e.at==at and e.sequence==seq)
    if scenario=='changed' or scenario=='leaving' then
        assert(e.mapID==101 and e.x==nil and e.y==nil and e.zone=='')
    elseif scenario=='known' then assert(e.mapID==101 and e.x==2000 and e.y==3000)
    elseif scenario=='unavailable' then assert(e.x==nil and e.y==nil)
    elseif scenario=='missing' then
        assert(e.mapID==102 and e.x==6100 and e.y==4700 and e.zone=='Hills')
        assert(t.loginLocation==nil)
    else assert(e.mapID==101 and e.x==6100 and e.y==4700 and e.zone=='Hills') end
    assert(ns.Annals.ValidEvent(e))
    ''')
