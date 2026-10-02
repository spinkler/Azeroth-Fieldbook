local _,ns=...
local A=ns.Atlas
local T={};ns.AtlasEntranceTypes=T
-- Data-only vocabulary: expand by locale without changing storage or rendering.
-- All targets must already exist in Atlas's deliberate category registry.
T.words={enUS={
    cave={"cave","caves","cavern","caverns","grotto","grottos","mine","mines","burrow","burrows","den"},
    route={"tunnel","tunnels","passage","passages"},
    ruins={"ruin","ruins"},
}}
T.order={"cave","route","ruins"}
function T.Suggest(context,locale)
    locale=locale or A.Read(GetLocale) or "enUS"
    local words=T.words[locale=="enGB" and "enUS" or locale]
    if not words then return {kind="none",category="entrance"} end
    for _,field in ipairs({"microName","mapName","subzone","minimap"}) do
        local value=context[field]
        if A.Text(value,160) then
            local tokens={};for word in value:lower():gmatch("[%a\128-\255]+") do tokens[word]=true end
            for _,category in ipairs(T.order) do
                if A.category[category] then for _,word in ipairs(words[category] or {}) do
                    if tokens[word] then return {kind="inferred",category=category,field=field,keyword=word,locale=locale} end
                end end
            end
        end
    end
    return {kind="none",category="entrance"}
end
