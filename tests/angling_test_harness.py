"""Almanac synthetic fixtures; no player knowledge or in-game assertions."""
from ui_test_harness import new_ui_client
from atlas_test_harness import ENV

ANGLING_MODULES = [
    'AnglingJournal.lua', 'AnglingTracking.lua', 'AnglingReports.lua',
    'AnglingMap.lua', 'AnglingEventLog.lua', 'AnglingBook.lua',
]


def new_angling(ui=False):
    lua = new_ui_client([
        'Scrollbars.lua', 'CreatureLocations.lua', 'FieldbookShell.lua',
        'AtlasJournal.lua', 'AtlasUI.lua', 'AtlasMap.lua', *ANGLING_MODULES,
    ])
    lua.execute(ENV)
    lua.execute(r'''
        local create=CreateFrame
        function CreateFrame(...)
            local f=create(...);f.events={}
            function f:RegisterEvent(event) self.events[event]=true end
            function f:RegisterUnitEvent(event,unit) self.events[event]=unit end
            return f
        end
        function fire(event,...)
            for _,f in ipairs(objects) do
                if f.events and f.events[event] and f.scripts.OnEvent and (f.events[event]==true or f.events[event]==select(1,...)) then f.scripts.OnEvent(f,event,...) end
            end
        end
        Enum=Enum or {};Enum.TooltipDataType={Object=4,Unit=2,Item=0}
        tooltipCallbacks={}
        TooltipDataProcessor={AddTooltipPostCall=function(kind,fn) tooltipCallbacks[kind]=fn end}
        C_TooltipInfo={GetWorldCursor=function() return cursorData end}
        function GameTooltip:GetPrimaryTooltipInfo() return cursorInfo end
        function hoverPool(name,requirement,kind)
            cursorInfo={getterName='GetWorldCursor'}
            cursorData={type=kind or 4,lines={{leftText=name},{leftText=requirement}}}
            tooltipCallbacks[4](GameTooltip,cursorData)
        end
        A=ns.Angling;R=ns.AnglingReports;saved={};j=ns.CreateAnglingJournal(saved)
        t=ns.CreateAnglingTracking(j);shell=ns.CreateFieldbookShell()
        shell:RegisterSection('other',{title='Other',build=function() end})
        c=ns.CreateAnglingBook(j,t,shell)
        elapsed=1;function GetTime() return elapsed end
        function GetLocale() return 'enUS' end
        function GetRealZoneText() return mapID==102 and 'Synthetic hills' or 'Synthetic coast' end
        C_SkillInfo={GetSkillLineInfoByID=function() return {skillID=356,rank=150,modifier=55,tempPoints=0} end}
        C_Spell={GetSpellName=function(id) return id==7620 and 'Fishing' or 'Other spell' end}
        loot={};fishing=true
        function IsFishingLoot() return fishing end
        function GetNumLootItems() return #loot end
        function GetLootSlotLink(slot) local v=loot[slot];return v and v.itemID and '|Hitem:'..v.itemID..'|h[Item]|h' end
        function GetLootSlotInfo(slot) local v=loot[slot];if v then return 123,v.name,v.quantity,nil,1 end end
        function spot(name,pool)
            return assert(j:Remember({name=name or 'Quiet pier',location=A.CurrentLocation(),
                note='Bring a lantern',pool=pool and {name=pool} or nil}))
        end
        function observe(token,source,poolID,spotID,method,items,skill)
            local context=j:Context(A.CurrentLocation(),source and {source=source,poolID=poolID,spotID=spotID},method or 'observed',skill or {effective=205})
            return assert(j:RecordCatch(token,context,items or {{itemID=1001,name='Synthetic fish',quantity=3}}))
        end
        function begin(guid,spell)
            t:OnEvent('UNIT_SPELLCAST_SENT','player','',guid,spell or 7620)
            t:OnEvent('UNIT_SPELLCAST_CHANNEL_START','player',guid,spell or 7620)
        end
        function catch(guid,items)
            begin(guid);loot=items or {{itemID=1001,name='Synthetic fish',quantity=3}}
            t:OnEvent('LOOT_READY',true);t:OnEvent('LOOT_OPENED',true,false)
            for i=1,#loot do t:OnEvent('LOOT_SLOT_CLEARED',i) end
            t:OnEvent('LOOT_CLOSED')
        end
        function total()
            local n=0;for _,a in pairs(j.db.aggregates) do n=n+a.events end;return n
        end
        function reportFor(id,knowledge,notes) return assert(R.Build(j,id,knowledge or 'personal',notes)) end
        function import(recipient,report)
            local ticket=assert(R.Prepare(assert(R.Encode(report))))
            return R.Accept(recipient,ticket)
        end
    ''')
    if ui:
        lua.execute("shell:ShowSection('angling');m=c.main")
    return lua
