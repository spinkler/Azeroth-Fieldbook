local _, ns = ...
local S={};ns.LoreSettings=S
local keys={autoArchiveLore=true,loreOnlyOpenedPages=true}
function S.Initialize(db)
    if type(db)~="table" then return end
    S.db=db
    for key in pairs(keys) do if db[key]==nil then db[key]=true end end
end
function S.Get(key) return keys[key] and (not S.db or S.db[key]~=false) end
function S.Set(key,value)
    if not keys[key] or not S.db then return end
    S.db[key]=value==true
    if S.tracking then S.tracking:OptionsChanged() end
end
