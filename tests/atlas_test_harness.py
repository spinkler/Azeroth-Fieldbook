"""Synthetic Atlas fixtures; never installed as player discoveries."""
from ui_test_harness import new_ui_client

ATLAS_MODULES = [
    'AtlasJournal.lua', 'AtlasSubzones.lua', 'AtlasEnvironment.lua', 'AtlasEntranceTypes.lua',
    'AtlasEntrances.lua', 'AtlasEntranceTracking.lua',
    'AtlasReferences.lua', 'AtlasReports.lua', 'AtlasUI.lua',
    'AtlasMap.lua', 'AtlasEditors.lua', 'AtlasReportUI.lua', 'AtlasBook.lua',
]

ENV = r'''
    local createFrame=CreateFrame
    function CreateFrame(...)
        local frame=createFrame(...)
        function frame:IsVisible()
            local parent=self
            while parent do if not parent:IsShown() then return false end;parent=parent.parent end
            return true
        end
        return frame
    end
    mapID=101; px=0.25; py=0.75
    local names={[100]='Synthetic continent',[101]='Synthetic coast',[102]='Synthetic hills'}
    C_Map={
        GetBestMapForUnit=function() return mapID end,
        GetMapInfo=function(id) if names[id] then return {mapID=id,name=names[id],parentMapID=id~=100 and 100 or 0,mapType=id==100 and 2 or 3} end end,
        GetPlayerMapPosition=function() return {x=px,y=py} end,
        GetMapChildrenInfo=function() return {{mapID=101,name=names[101],mapType=3},{mapID=102,name=names[102],mapType=3}} end,
        GetMapArtLayers=function() return {{layerWidth=1000,layerHeight=668,tileWidth=256,tileHeight=256}} end,
        GetMapArtLayerTextures=function() local t={};for i=1,12 do t[i]=9000+i end;return t end,
    }
    function GetSubZoneText() return 'Synthetic subzone' end
    function GetCursorPosition() return cursorX or 0,cursorY or 0 end
    GameTooltip=CreateFrame('Frame')
    local setTooltipText=GameTooltip.SetText
    function GameTooltip:SetText(text,r,g,b,alpha,wrap)
        assert(r==nil or (type(g)=='number' and type(b)=='number'),
            'GameTooltip:SetText received an incomplete color argument')
        for _,value in pairs({r=r,g=g,b=b,alpha=alpha}) do
            assert(type(value)=='number','GameTooltip:SetText color/alpha must be numeric')
        end
        assert(wrap==nil or type(wrap)=='boolean','GameTooltip:SetText wrap must be boolean')
        self.lines={};setTooltipText(self,text)
    end
    function GameTooltip:AddLine(text,r,g,b,wrap)
        assert(wrap==nil or type(wrap)=='boolean')
        self.lines[#self.lines+1]={text=text,wrap=wrap}
    end
    function GameTooltip:SetOwner(owner) self.owner=owner end
    function GameTooltip:IsOwned(owner) return self.owner==owner end
    function fixture(name,category,map,x,y)
        return {name=name or 'Synthetic entrance',category=category or 'cave',mapID=map or 101,
            zone=(map==102 and 'Synthetic hills' or 'Synthetic coast'),subzone='Synthetic hollow',x=x or 2500,y=y or 7500,
            notes='Private lantern note',access='Approach from synthetic ford',interior='Synthetic chamber',explored=false}
    end
    function click(b) assert(b and b.enabled~=false,'disabled button');b.scripts.OnClick(b) end
    function snapshot(v)
        if type(v)~='table' then return tostring(v) end
        local keys={};for k in pairs(v) do keys[#keys+1]=k end
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        local out={};for _,k in ipairs(keys) do out[#out+1]=tostring(k)..'='..snapshot(v[k]) end
        return '{'..table.concat(out,',')..'}'
    end
'''


def new_atlas(ui=False):
    lua = new_ui_client([
        'Scrollbars.lua', 'CreatureLocations.lua', 'FieldbookShell.lua',
        'GatheringJournal.lua', 'GatheringModels.lua', *ATLAS_MODULES,
    ])
    lua.execute(ENV)
    lua.execute('''
        saved={};j=ns.CreateAtlasJournal(saved);A=ns.Atlas;R=ns.AtlasReports
        shell=ns.CreateFieldbookShell()
        shell:RegisterSection('test',{title='Other',build=function() end})
        source={entries={['herb:synthetic herb']={id='herb:synthetic herb',name='Synthetic herb',kind='herb',note='secret source note'}}}
        refs=ns.CreateAtlasReferences(nil,function() return source end,shell)
        c=ns.CreateAtlasBook(j,shell,refs)
    ''')
    if ui:
        lua.execute("shell:ShowSection('atlas');m=c.main")
    return lua
