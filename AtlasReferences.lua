local _, ns = ...
local A=ns.Atlas

-- Read-only adapters return display references, never source entries. New
-- sections can register the same list/resolve/open contract from Atlas code.
function ns.CreateAtlasReferences(bestiary,getGathering,shell)
    local adapters={}
    local result={adapters=adapters}
    function result:Register(id,adapter) adapters[id]=adapter end
    result:Register("bestiary",{title="Bestiary",list=function()
        local rows={}
        if not bestiary then return rows end
        -- This is the section's own visible index, including its locked-name
        -- rules. Do not enumerate spells, rumours or unconfirmed claims.
        for _,r in ipairs(bestiary:List(nil,"")) do
            if A.Text(r.name,160) then rows[#rows+1]={section="bestiary",key=tostring(r.id),name=r.name} end
        end
        return rows
    end,resolve=function(key)
        local id=tonumber(key)
        local name=bestiary and id and bestiary:GetCreatureName(id)
        if A.Text(name,160) then return {section="bestiary",key=key,name=name} end
    end,open=function(key)
        return shell:ShowSection("bestiary",{creatureID=tonumber(key)})
    end})
    result:Register("gathering",{title="Gatherer's Compendium",list=function()
        local rows={};local db=getGathering and getGathering()
        for id,e in pairs(type(db)=="table" and db.entries or {}) do
            if type(e)=="table" and ns.GatheringKinds[e.kind] and A.Text(id,160) and A.Text(e.name,160) then
                rows[#rows+1]={section="gathering",key=id,name=e.name}
            end
        end
        return rows
    end,resolve=function(key)
        local db=getGathering and getGathering();local e=db and db.entries and db.entries[key]
        if type(e)=="table" and ns.GatheringKinds[e.kind] and A.Text(e.name,160) then
            return {section="gathering",key=key,name=e.name}
        end
    end})
    function result:List(query)
        local rows={};query=(query or ""):lower()
        for id,adapter in pairs(adapters) do
            for _,r in ipairs(adapter.list()) do
                if (r.name.." "..adapter.title):lower():find(query,1,true) then
                    r.title=adapter.title;rows[#rows+1]=r
                end
            end
        end
        table.sort(rows,function(a,b) if a.name==b.name then return a.section..a.key<b.section..b.key end;return a.name<b.name end)
        return rows
    end
    function result:Resolve(ref)
        local adapter=adapters[ref.section]
        local current=adapter and adapter.resolve(ref.key)
        return current or {section=ref.section,key=ref.key,name=ref.name,missing=true},adapter and adapter.title or ref.section
    end
    function result:Open(ref)
        local resolved,title=self:Resolve(ref)
        if resolved.missing then return false,title..": "..ref.name.." (unavailable; reference retained)." end
        local adapter=adapters[ref.section]
        if adapter.open then return adapter.open(ref.key) end
        return false,title..": "..resolved.name.."\nThis is an existing discovery in its source journal. Entry navigation is unavailable; the reference remains here."
    end
    return result
end
