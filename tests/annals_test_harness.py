from ui_test_harness import new_ui_client
from atlas_test_harness import ENV

MODULES = ['AtlasJournal.lua', 'AtlasEnvironment.lua', 'GatheringTracking.lua', 'AnnalsJournal.lua',
           'AnnalsTrail.lua', 'AnnalsTracking.lua', 'AnnalsMap.lua']


def client():
    lua = new_ui_client(MODULES)
    lua.execute(ENV)
    lua.execute(r'''
        now=1800000000;timers={};quest=42
        function advance(seconds)
            now=now+seconds
            local old=timers;timers={}
            for _,v in ipairs(old) do if v.at<=now then v.fn() else timers[#timers+1]=v end end
        end
        C_Timer={After=function(seconds,fn) timers[#timers+1]={at=now+seconds,fn=fn} end}
        C_QuestLog={GetTitleForQuestID=function(id) return 'Quest '..id end,
            GetNumQuestLogEntries=function() return 0 end}
        function GetQuestID() return quest end
        function GetTitleText() return 'Quest '..quest end
        choiceCount=2;autoCount=1
        function GetNumQuestChoices() return choiceCount end
        function GetNumQuestRewards() return autoCount end
        function GetQuestItemInfo(kind,i)
            if missing then return end
            return kind..' item '..i,123,kind=='reward' and 3 or 1,2,true,(kind=='reward' and 200 or 100)+i
        end
        function GetSubZoneText() return 'Synthetic valley' end
        function GetRealZoneText() return 'Synthetic coast' end
        function reset(saved)
            db=saved or {};j=ns.CreateAnnalsJournal(db);trail=ns.CreateAnnalsTrail(j);t=ns.CreateAnnalsTracking(j)
        end
        function point(x,y,at,map,anchor)
            trail:Sample({x=x,y=y,at=at,mapID=map or 101,level=23},anchor)
        end
        function points()
            local n=0;for _,s in ipairs(db.segments) do n=n+#assert(ns.Annals.Decode(s)) end;return n
        end
        reset()
    ''')
    return lua
