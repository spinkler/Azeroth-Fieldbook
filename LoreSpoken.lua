local _,ns=...
local L=ns.Lore
local S={};ns.LoreSpoken=S

-- Optional integration: discover capabilities at use time, so neither addon
-- becomes a dependency and an older/missing Spoken simply offers no control.
function S:Module()
    local player,readables=_G.Spoken,_G.SpokenReadables
    if type(player)~="table" or type(readables)~="table" then return end
    if type(player.IsCompatible)~="function" then return end
    for _,key in ipairs({"Data","ChecksumOf","PlaceOf","CompendiumHas","HasAudio","PlayFrom","IsNarrating","StopReading","IsPartOn"}) do
        if type(readables[key])~="function" then return end
    end
    if L.Read(player.IsCompatible,player,1) then return readables end
end

local function find(index,title,number,checksum)
    if type(index)~="table" or not checksum then return end
    for _,keys in ipairs({{"index","loose"},{"extraIndex","extraLoose"}}) do
        local titles=type(index[keys[1]])=="table" and index[keys[1]]
        local pages=titles and titles[title]
        local sums=type(pages)=="table" and number and pages[number]
        local id=type(sums)=="table" and sums[checksum]
        if id then return id end
        local loose=type(index[keys[2]])=="table" and index[keys[2]]
        if loose and loose[checksum] then return loose[checksum] end
    end
end

function S:Resolve(e,row)
    local module=self:Module()
    if not module or not e or e.kind~="writing" or not row then return end
    local p=row.page
    -- Only preserved book pages; notes, translations, missing pages and NPC
    -- passages must never be identified by title alone or by the live reader.
    if not p or p.translation or p.nature~="source" or not row.id:find("page:",1,true)
        or type(p.raw)~="string" or p.raw=="" then return end
    local title=p.sourceTitle
    if not title or title=="" then title=row.report and row.report.sourceTitle or e.sourceTitle end
    title=title or ""
    local number=row.number or p.number
    local sums={L.Read(module.ChecksumOf,module,p.raw),L.Read(module.MarkedChecksumOf,module,p.raw)}
    local indexes={}
    local packs=L.Read(module.GetAudioPacks,module)
    local locale=p.locale or (row.report and row.report.locale) or e.locale
    if not locale or locale=="" then locale=L.Read(module.GetClientLanguage,module) end
    for _,pack in ipairs(type(packs)=="table" and packs or {}) do
        if L.Read(module.PackLanguage,module,pack)==locale then indexes[#indexes+1]=pack end
    end
    local data=L.Read(module.Data,module)
    if type(data)=="table" then indexes[#indexes+1]=data end
    for _,index in ipairs(indexes) do for _,sum in ipairs(sums) do
        local id=find(index,title,number,sum)
        local book=id and L.Read(module.PlaceOf,module,id)
        if book then return {module=module,page=id,book=book} end
    end end
end

function S:Status(target)
    if not target or self:Module()~=target.module then return false,false end
    local m=target.module
    -- PlayFrom deliberately does not enforce Compendium discovery locks itself.
    local available=L.Read(m.IsPartOn,m) and L.Read(m.CompendiumHas,m,target.book)
        and L.Read(m.HasAudio,m,target.page)
    return available and true or false,L.Read(m.IsNarrating,m,target.book) and true or false
end

function S:Toggle(target)
    local available,playing=self:Status(target)
    if not available then return nil,"Spoken narration is no longer available for this page." end
    local m=target.module
    if playing then L.Read(m.StopReading,m,target.book);return true end
    -- browsing + asked: archive playback neither discovers the book nor changes
    -- Spoken's read-once history, and follows the user's book playback settings.
    local count=L.Read(m.PlayFrom,m,target.page,true,true)
    if type(count)=="number" and count>0 then return true end
    return nil,"Spoken could not play this recording. Check its voice packs and playback settings."
end
