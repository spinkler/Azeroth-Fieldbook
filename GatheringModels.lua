local _, ns = ...

-- Presentation assets only: this catalog never creates journal entries or locations.
-- Object/display associations: AzerothCore gameobject_template; file IDs verified
-- against Forever 1.60.1.70009 GameObjectDisplayInfo and installed CASC assets.
-- Numeric file IDs are necessary: the client no longer resolves these model paths.
local models={
    {"mineral","Hakkari Thorium Vein",219550,{180215}},
    {"mineral","Small Obsidian Chunk",219544,{181068}},
    {"mineral","Large Obsidian Chunk",219544,{181069}},
    {"herb","Arthas' Tears",219436,{142141,176642}},
    {"herb","Black Lotus",219437,{176589}},
    {"herb","Blindweed",219438,{142143}},
    {"herb","Briarthorn",219502,{1621,3729}},
    {"herb","Bruiseweed",219440,{1622,3730}},
    {"mineral","Copper Vein",219514,{1731,2055,3763,103713}},
    {"mineral","Dark Iron Deposit",189103,{165658}},
    {"herb","Dreamfoil",219444,{176584,176639}},
    {"herb","Earthroot",219489,{1619,3726}},
    {"herb","Fadeleaf",219449,{2042}},
    {"herb","Firebloom",219452,{2866}},
    {"herb","Ghost Mushroom",219474,{142144}},
    {"mineral","Gold Vein",219524,{1734,150080}},
    {"herb","Golden Sansam",219486,{176583,176638}},
    {"herb","Goldthorn",219462,{2046}},
    {"herb","Grave Moss",219463,{1628}},
    {"herb","Gromsblood",219464,{142145,176637}},
    {"herb","Icecap",219465,{176588}},
    {"mineral","Incendicite Mineral Vein",219531,{1610,1667}},
    {"mineral","Indurium Mineral Vein",219531,{19903}},
    {"mineral","Iron Deposit",219532,{1735}},
    {"herb","Khadgar's Whisker",219468,{2043}},
    {"herb","Kingsblood",219443,{1624}},
    {"mineral","Lesser Bloodstone Deposit",197038,{2653}},
    {"herb","Liferoot",219469,{2041}},
    {"herb","Mageroyal",219470,{1620,3727}},
    {"mineral","Mithril Deposit",219541,{2040,150079,176645}},
    {"herb","Mountain Silversage",219473,{176586,176640}},
    {"mineral","Ooze Covered Gold Vein",219553,{73941}},
    {"mineral","Ooze Covered Iron Deposit",219553,{73939}},
    {"mineral","Ooze Covered Mithril Deposit",219553,{123310}},
    {"mineral","Ooze Covered Rich Thorium Vein",219553,{177388}},
    {"mineral","Ooze Covered Silver Vein",219553,{73940}},
    {"mineral","Ooze Covered Thorium Vein",219553,{123848}},
    {"mineral","Ooze Covered Truesilver Deposit",219553,{123309}},
    {"herb","Peacebloom",219481,{1618,3724}},
    {"herb","Plaguebloom",219482,{176587,176641}},
    {"herb","Purple Lotus",219483,{142140}},
    {"mineral","Rich Thorium Vein",219550,{175404}},
    {"mineral","Silver Vein",219569,{1733,105569}},
    {"herb","Silverleaf",219487,{1617,3725}},
    {"mineral","Small Thorium Vein",219566,{324,150082,176643}},
    {"herb","Stranglekelp",219495,{2045}},
    {"herb","Sungrass",219496,{142142,176636}},
    {"mineral","Tin Vein",219568,{1732,2054,3764,103711}},
    {"mineral","Truesilver Deposit",219569,{2047,150081}},
    {"herb","Wild Steelbloom",219494,{1623}},
    {"herb","Wintersbite",219507,{2044}},
}
local names,objects,allowed={},{},{}
for _,row in ipairs(models) do
    local kind,name,fileID,ids=unpack(row)
    names[kind..":"..string.lower(name)]=fileID
    allowed[kind..":"..fileID]=true
    for _,id in ipairs(ids) do objects[kind..":"..id]=fileID end
end
function ns.GatheringModelAllowed(kind,fileID)
    return not (issecretvalue and issecretvalue(fileID)) and type(fileID)=="number"
        and fileID>0 and fileID<2147483647 and fileID==math.floor(fileID)
        and allowed[kind..":"..fileID]==true
end
function ns.GatheringModel(kind,name,objectID)
    if kind~="herb" and kind~="mineral" then return end
    if not (issecretvalue and issecretvalue(objectID)) and type(objectID)=="number"
        and objectID>0 and objectID<2147483647 and objectID==math.floor(objectID) then
        local model=objects[kind..":"..objectID]
        if model then return model end
    end
    name=ns.GatheringName(name)
    return name and names[kind..":"..string.lower(name)] or nil
end
