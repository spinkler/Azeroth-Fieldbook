local _,ns=...

-- Character preferences, independent of each journal's storage scope. Missing
-- preferences keep every section enabled, including on existing installations.
local listeners,generations={},{}
function ns.IsFieldbookSectionEnabled(id)
    local db=AzerothFieldbookDB
    local visibility=type(db)=="table" and db.sectionVisibility
    return type(visibility)~="table" or visibility[id]~=false
end
function ns.RegisterSectionVisibilityListener(id,callback)
    listeners[id]=listeners[id] or {}
    table.insert(listeners[id],callback)
end
function ns.GuardSectionCallback(id,callback)
    local generation=generations[id]
    return function(...)
        if ns.InitializationBlocked or not ns.IsFieldbookSectionEnabled(id) or generations[id]~=generation then return end
        return callback(...)
    end
end
function ns.SetFieldbookSectionEnabled(id,enabled)
    if ns.InitializationBlocked or type(AzerothFieldbookDB)~="table" then return false end
    enabled=enabled==true
    if ns.IsFieldbookSectionEnabled(id)==enabled then return true end
    local db=AzerothFieldbookDB
    if type(db.sectionVisibility)~="table" then db.sectionVisibility={} end
    db.sectionVisibility[id]=enabled
    generations[id]=(generations[id] or 0)+1
    for _,callback in ipairs(listeners[id] or {}) do callback(enabled) end
    return true
end
