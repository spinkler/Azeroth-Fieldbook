local addonName, ns = ...

-- A bounded, literal format: imported text is data, never Lua or executable code.
-- Strings are escaped so exported text contains no UI markup or whitespace.
local backups = { VERSION=1, MAX_BYTES=4*1024*1024, MAX_SAVED=5 }
ns.BestiaryBackups = backups
local MAX_NODES, MAX_DEPTH = 300000, 24
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok and public(value) then return value end
end
local function integer(value, low, high)
    return public(value) and type(value)=="number" and value>=low and value<=high and value==math.floor(value)
end
local function copy(value)
    if type(value)~="table" then return value end
    local result={}
    for key,child in pairs(value) do result[key]=copy(child) end
    return result
end
local function checksum(text)
    local a,b=1,0
    for i=1,#text do a=(a+text:byte(i))%65521; b=(b+a)%65521 end
    return string.format("%08x",b*65536+a)
end
local function pack(value, output, budget, depth)
    budget.nodes=budget.nodes+1
    if budget.nodes>MAX_NODES or depth>MAX_DEPTH then error("limit") end
    local kind, token=type(value)
    if kind=="table" then
        local keys={}
        for key in pairs(value) do keys[#keys+1]=key end
        table.sort(keys,function(a,b)
            if type(a)~=type(b) then return type(a)<type(b) end
            return a<b
        end)
        token="m"..#keys..":"
        output[#output+1]=token; budget.bytes=budget.bytes+#token
        for _,key in ipairs(keys) do pack(key,output,budget,depth+1);pack(value[key],output,budget,depth+1) end
        return
    elseif kind=="string" then
        local escaped=value:gsub("[^A-Za-z0-9_.%-]",function(c) return string.format("%%%02X",c:byte()) end)
        token="s"..#escaped..":"..escaped
    elseif kind=="number" then token="n"..string.format("%.0f",value)..":"
    elseif kind=="boolean" then token=value and "y" or "z"
    else error("type") end
    budget.bytes=budget.bytes+#token
    if budget.bytes>backups.MAX_BYTES-14 then error("limit") end
    output[#output+1]=token
end
local function unpackData(text)
    local position,nodes=1,0
    local function length()
        local last=text:find(":",position,true)
        if not last or last-position>12 then error("length") end
        local digits=text:sub(position,last-1)
        if not digits:match("^%d+$") then error("length") end
        position=last+1
        return tonumber(digits)
    end
    local parse
    parse=function(depth)
        nodes=nodes+1
        if nodes>MAX_NODES or depth>MAX_DEPTH then error("limit") end
        local tag=text:sub(position,position); position=position+1
        if tag=="y" then return true elseif tag=="z" then return false end
        local count=length()
        if tag=="n" then return count end
        if tag=="s" then
            if count>backups.MAX_BYTES or position+count-1>#text then error("length") end
            local escaped=text:sub(position,position+count-1);position=position+count
            if escaped:gsub("%%[A-Fa-f0-9][A-Fa-f0-9]",""):find("[^A-Za-z0-9_.%-]") then error("escape") end
            return (escaped:gsub("%%(%x%x)",function(hex) return string.char(tonumber(hex,16)) end))
        end
        if tag~="m" or count>MAX_NODES then error("table") end
        local result={}
        for _=1,count do
            local key=parse(depth+1)
            if (type(key)~="string" and type(key)~="number") or result[key]~=nil then error("key") end
            result[key]=parse(depth+1)
        end
        return result
    end
    local result=parse(0)
    if position~=#text+1 then error("trailing data") end
    return result
end

local function text(limit, multiline)
    return function(value)
        if not public(value) or type(value)~="string" or #value>limit or value:find("|") then return false end
        if multiline then value=value:gsub("[\n\r\t]","") end
        return not value:find("%c")
    end
end
local function natural(value) return integer(value,0,999999999999) end
local function positive(value) return integer(value,1,2147483647) end
local function timestamp(value) return integer(value,1,9999999999) end
local function boolean(value) return type(value)=="boolean" and public(value) end
local function enum(values)
    return function(value) return public(value) and type(value)=="string" and values[value]==true end
end
local function record(fields, required) return {fields=fields,required=required or {}} end
local function map(key,value) return {key=key,value=value} end
local function array(value) return {key=positive,value=value,array=true} end
local names, words, prose = text(256), text(1024), text(4096,true)
local flags=map(names,boolean)
local levels=map(positive,boolean)
local basic=record({name=names,category=names,levelMin=positive,levelMax=positive,locations=flags,personal=boolean,hasShared=boolean})
local progress=record({levels=levels,zones=flags,points=natural,killPoints=natural,initial=boolean,discovered=boolean,killGUIDs=array(names),firstEncounteredAt=timestamp})
local ability=record({state=enum({pending=true,confirmed=true,rejected=true}),origin=words,note=prose,
    effects=flags,spellID=positive,showInTooltip=boolean},{"state"})
local damageNote=record({low=positive,high=positive,playerLevel=positive,creatureLevel=positive,legacy=boolean},{"low","high"})
local damage=record({low=positive,high=positive,reports=natural,notes=array(damageNote),
    normalLow=positive,normalHigh=positive,normalCount=natural,critLow=positive,critHigh=positive,critCount=natural})
local shared=record({creatureID=positive,name=names,category=names,levelMin=positive,levelMax=positive,
    locations=array(names),sender=names,transaction=names,received=natural,source=names},{"name","category","locations"})
local rumour=record({creatureID=positive,kind=enum({ability=true,offense=true,resistance=true,immunity=true,behaviour=true}),
    value=names,spellID=positive,sender=names,transaction=names,received=natural,source=names,
    previouslyRejected=boolean,dismissed=boolean,resolved=boolean,rejected=boolean},{"kind","value","sender"})
local entry=record({id=positive,name=names,category=names,rank=names,levelMin=positive,levelMax=positive,
    firstEncounteredAt=timestamp,
    kills=natural,sightings=natural,confirmed=boolean,personalEncountered=boolean,lockedBasic=basic,
    locations=flags,offenses=flags,resistances=flags,immunities=flags,behaviours=flags,
    abilities=map(names,ability),ignoredAbilities=flags,damage=map(positive,damage),
    idNotes=record({spells=array(positive),text=prose}),tameable=boolean,tameabilitySource=names,
    discoveryProgress=progress,sharedReports=array(shared),rumours=array(rumour),unchangedKills=natural},{"id"})
local bestiary=record({entries=map(positive,entry),creatures=map(positive,record({names=flags,spells=map(positive,record({name=names},{"name"}))})),
    points=record({version=positive,earned=natural,spent=natural,credits=map(positive,progress)},{"earned","spent","credits"}),
    recentKills=array(names)},{"entries","creatures","points"})
local snapshotSchema=record({version=positive,created=natural,addonVersion=names,scope=enum({account=true,character=true}),
    character=names,bestiary=bestiary},{"version","created","addonVersion","scope","bestiary"})

-- Project local data onto the supported schema; imports reject unknown fields.
-- Cached signatures and live sharing transactions are intentionally not backups.
local function project(value, rule, importing, budget, depth)
    if not public(value) then error("restricted") end
    if value==nil then return end
    budget.nodes=budget.nodes+1
    if budget.nodes>MAX_NODES or depth>MAX_DEPTH or not public(value) then error("limit") end
    if type(rule)=="function" then if not rule(value) then error("field") end;return value end
    if type(value)~="table" or getmetatable(value)~=nil then error("table") end
    local result={}
    if rule.fields then
        for key,childRule in pairs(rule.fields) do result[key]=project(value[key],childRule,importing,budget,depth+1) end
        for _,key in ipairs(rule.required) do if result[key]==nil then error("required") end end
        if importing then for key in pairs(value) do if not rule.fields[key] then error("field") end end end
    else
        local count=0
        for key,child in pairs(value) do
            if not rule.key(key) then error("key") end
            result[key]=project(child,rule.value,importing,budget,depth+1);count=count+1
        end
        if rule.array then for index=1,count do if result[index]==nil then error("array") end end end
    end
    return result
end
local function range(value, low, high)
    if (value[low]==nil)~=(value[high]==nil) or (value[low] and value[low]>value[high]) then error("range") end
end
local function normalize(snapshot)
    if snapshot.version~=backups.VERSION then error("version") end
    local saved=snapshot.bestiary
    saved.recentKills=saved.recentKills or {}
    for id,e in pairs(saved.entries) do
        if e.id~=id then error("identity") end
        range(e,"levelMin","levelMax")
        e.category=e.category or "Unclassified";e.kills=e.kills or 0
        for _,field in ipairs({"abilities","locations","offenses","resistances","immunities","behaviours","damage"}) do e[field]=e[field] or {} end
        if e.lockedBasic then range(e.lockedBasic,"levelMin","levelMax") end
        if e.idNotes then e.idNotes.spells=e.idNotes.spells or {};e.idNotes.text=e.idNotes.text or "" end
        for _,r in ipairs(e.sharedReports or {}) do range(r,"levelMin","levelMax") end
        for _,d in pairs(e.damage) do
            range(d,"low","high");range(d,"normalLow","normalHigh");range(d,"critLow","critHigh")
            d.notes=d.notes or {};d.reports=d.reports or #d.notes
            if d.normalLow then d.normalCount=d.normalCount or 0 end
            if d.critLow then d.critCount=d.critCount or 0 end
            for _,note in ipairs(d.notes) do range(note,"low","high") end
        end
        if e.discoveryProgress then
            e.discoveryProgress.levels=e.discoveryProgress.levels or {};e.discoveryProgress.zones=e.discoveryProgress.zones or {}
        end
    end
    for _,c in pairs(saved.creatures) do c.spells=c.spells or {};c.names=c.names or {} end
    for _,credit in pairs(saved.points.credits) do
        credit.levels=credit.levels or {};credit.zones=credit.zones or {};credit.killGUIDs=credit.killGUIDs or {}
        credit.points=credit.points or 0;credit.killPoints=credit.killPoints or 0
    end
    return snapshot
end
function backups.Validate(snapshot, importing)
    local ok, result=pcall(function() return normalize(project(snapshot,snapshotSchema,importing,{nodes=0},0)) end)
    if ok then return result end
    return nil,"This backup contains unsupported or invalid data. Your Bestiary has not changed."
end
function backups.Encode(snapshot)
    local value,err=backups.Validate(snapshot,true)
    if not value then return nil,err end
    local output={}
    local ok=pcall(pack,value,output,{nodes=0,bytes=0},0)
    if not ok then return nil,"This backup is too large to export as a single copy." end
    local payload=table.concat(output)
    return "AFB1:"..checksum(payload)..":"..payload
end
function backups.Decode(textValue)
    if not public(textValue) or type(textValue)~="string" or #textValue>backups.MAX_BYTES then
        return nil,"This backup text is too large. Paste a single Azeroth Fieldbook backup."
    end
    local clean=textValue:gsub("%s","")
    local digest,payload=clean:match("^AFB1:(%x%x%x%x%x%x%x%x):(.*)$")
    if not payload then return nil,"Paste the complete Azeroth Fieldbook backup text, starting with AFB1:." end
    if checksum(payload)~=digest:lower() then return nil,"The backup text is incomplete or changed. Copy the whole backup and try again." end
    local ok,value=pcall(unpackData,payload)
    if not ok then return nil,"This backup text is not valid. Your Bestiary has not changed." end
    return backups.Validate(value,true)
end
function backups.Summary(snapshot)
    local creatures,abilities,notes=0,0,0
    for _,e in pairs(snapshot.bestiary.entries) do
        creatures=creatures+1
        for _ in pairs(e.abilities) do abilities=abilities+1 end
        if e.idNotes and (e.idNotes.text~="" or #e.idNotes.spells>0) then notes=notes+1 end
    end
    return creatures,abilities,notes
end
function backups.Date(snapshot)
    return read(date,"%d %b %Y, %H:%M:%S",snapshot.created) or "Unknown date"
end

-- Preserve earned milestones, spending and outstanding reservations. Restoring
-- creature records must not re-award old discoveries or replay/refund offers.
function backups.MergePoints(current, saved)
    local result=copy(current)
    local added=0
    for id,credit in pairs(saved.credits) do
        local existing=result.credits[id]
        if not existing then
            result.credits[id]=copy(credit)
            added=added+(credit.discovered and 1 or 0)+credit.points+credit.killPoints
        else
            existing.firstEncounteredAt=ns.EarliestEncounterTime(existing.firstEncounteredAt,credit.firstEncounteredAt)
            added=added+((credit.discovered and not existing.discovered) and 1 or 0)
                +math.max(0,credit.points-(existing.points or 0))+math.max(0,credit.killPoints-(existing.killPoints or 0))
            existing.discovered=existing.discovered or credit.discovered
            existing.initial=existing.initial and credit.initial
            existing.points=math.max(existing.points or 0,credit.points)
            existing.killPoints=math.max(existing.killPoints or 0,credit.killPoints)
            for level in pairs(credit.levels) do existing.levels[level]=true end
            for zone in pairs(credit.zones) do existing.zones[zone]=true end
        end
    end
    result.earned=math.max(current.earned+added,saved.earned)
    result.spent=math.max(current.spent,saved.spent)
    return result
end

function ns.InstallBestiaryBackups(journal, db, trackingDB, apply)
    local function archive()
        if type(trackingDB.bestiaryBackups)~="table" then trackingDB.bestiaryBackups={saved={}} end
        return trackingDB.bestiaryBackups
    end
    function journal:CaptureBackup()
        local version=read(C_AddOns and C_AddOns.GetAddOnMetadata,addonName,"Version") or "unknown"
        local stamp=read(time) or 0
        local character=read(UnitName,"player")
        if not names(character) then character=nil end
        return backups.Validate({version=backups.VERSION,created=stamp,addonVersion=version,
            scope=self:IsAccountWideTrackingActive() and "account" or "character",character=character,bestiary=trackingDB.bestiary},false)
    end
    function journal:GetBackups() return archive() end
    function journal:CreateBackup()
        local snapshot,err=self:CaptureBackup()
        if not snapshot then return nil,err end
        local saved=archive().saved
        table.insert(saved,1,snapshot)
        while #saved>backups.MAX_SAVED do table.remove(saved) end
        self:RecordEvent("Bestiary backup saved: "..backups.Summary(snapshot).." creatures.",{kind="backup"})
        return snapshot
    end
    function journal:RestoreBackup(snapshot)
        if InCombatLockdown and read(InCombatLockdown)~=false then return nil,"Restore outside combat so your journal is not changing during a fight." end
        local restored,err=backups.Validate(snapshot,true)
        if not restored then return nil,err end
        local recovery,recoveryError=self:CaptureBackup()
        if not recovery then return nil,"A recovery copy could not be saved. "..recoveryError end
        restored.bestiary.points=backups.MergePoints(trackingDB.bestiary.points,restored.bestiary.points)
        archive().recovery=recovery
        apply(restored.bestiary)
        self:RecordEvent("Bestiary restored from "..backups.Date(restored)..". A recovery copy was saved.",{kind="restore"})
        return true
    end
end
