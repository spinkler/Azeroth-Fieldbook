local _, ns = ...
local L=ns.Lore
-- References never borrow ownership of another journal's records. Only registered
-- read-only adapters may enumerate known discoveries or open existing entries.
function ns.CreateLoreReferences(journal,shell)
    local r={adapters={}}
    function r:Register(section,adapter) self.adapters[section]=adapter end
    r:Register("lore",{title="Lore & Landmarks",list=function()
        local rows={}
        for id,e in pairs(journal.entries) do rows[#rows+1]={section="lore",key=id,name=journal:Title(e)} end
        return rows
    end,resolve=function(key)
        local e=journal:Get(key);if e then return {section="lore",key=key,name=journal:Title(e)} end
    end,open=function(key) return shell:ShowSection("lore",{entryID=key}) end})
    function r:List(query,exclude)
        query=type(query)=="string" and query:lower() or ""
        local rows={}
        for section,adapter in pairs(self.adapters) do
            for _,v in ipairs(adapter.list() or {}) do
                if type(v)=="table" and type(v.key)=="string" and type(v.name)=="string" and
                    not (section=="lore" and v.key==exclude) and
                    (v.name.." "..adapter.title):lower():find(query,1,true) then
                    rows[#rows+1]={section=section,key=v.key,name=v.name,title=adapter.title}
                end
            end
        end
        table.sort(rows,function(a,b) if a.name==b.name then return a.section..a.key<b.section..b.key end;return a.name<b.name end)
        return rows
    end
    function r:Resolve(ref)
        local adapter=self.adapters[ref.section]
        local key=ref.key or ref.id
        local current=adapter and adapter.resolve(key)
        return current or {section=ref.section,key=key,name=ref.name or ref.label,missing=true},adapter and adapter.title or ref.section
    end
    function r:Open(ref)
        local current,title=self:Resolve(ref)
        if current.missing then return false,(ref.name or ref.label or "Reference").." is unavailable in this scope; its reference is retained." end
        local adapter=self.adapters[ref.section]
        if adapter.open then return adapter.open(ref.key or ref.id) end
        return false,title..": "..current.name..". Direct entry navigation is unavailable for this section."
    end
    return r
end
