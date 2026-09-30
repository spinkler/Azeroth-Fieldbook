local addonName,ns=...

-- Whole saves, not report projections. Keep unknown fields, private text, raw
-- preserved records and identity maps. Never evaluate imported text as Lua.
local B={VERSION=1,MAX_BYTES=256*1024*1024,MAX_NODES=4000000,MAX_DEPTH=64,
    MAX_SAVED=2,PART_BYTES=256*1024}
ns.FieldbookBackups=B
B.roots={"AzerothFieldbookDB","AzerothFieldbookAccountDB","AzerothFieldbookGatheringDB",
    "AzerothFieldbookAtlasDB","AzerothFieldbookAnglingDB","AzerothFieldbookLedgerDB",
    "AzerothFieldbookTreasureDB","AzerothFieldbookLoreDB"}
local sections={gathering=3,atlas=4,angling=5,ledger=6,treasure=7,lore=8}
local rootSet={};for _,name in ipairs(B.roots) do rootSet[name]=true end
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function plain(v) return public(v) and type(v)=="table" and getmetatable(v)==nil end
local function need(ok,message) if not ok then error(message,0) end end
local function integer(v,low,high) return type(v)=="number" and v>=low and v<=high and v==math.floor(v) end
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...);if ok and public(v) then return v end
end
local function label(v) return type(v)=="string" and #v>0 and #v<=256 and not v:find("[%c|]") end
local function owner()
    if not label(read(UnitName,"player")) then return end
    local name=ns.Ledger.Player()
    if not label(name) then return end
    local result={name=name}
    local guid=read(UnitGUID,"player")
    if label(guid) and guid:match("^Player%-") then result.guid=guid end
    local realm=read(GetRealmName);if label(realm) then result.realm=realm end
    return result
end
local function sameOwner(a,b)
    if not a or not b then return false end
    if a.guid and b.guid then return a.guid==b.guid end
    return a.name==b.name and (not a.realm or not b.realm or a.realm==b.realm)
end
local function fields(v,allowed)
    need(plain(v),"Expected a plain backup table.")
    for k in pairs(v) do need(allowed[k],"Unsupported backup field.") end
end
local function envelope(v)
    fields(v,{format=true,version=true,created=true,addonVersion=true,owner=true,present=true,stores=true})
    need(v.format=="AFB-WHOLE" and v.version==B.VERSION,"Unsupported whole-Fieldbook backup version.")
    need(integer(v.created,0,9999999999) and label(v.addonVersion),"Invalid backup date or addon version.")
    fields(v.owner,{name=true,realm=true,guid=true})
    need(label(v.owner.name) and (v.owner.realm==nil or label(v.owner.realm))
        and (v.owner.guid==nil or label(v.owner.guid)),"Invalid backup owner.")
    fields(v.present,rootSet);fields(v.stores,rootSet)
    for _,name in ipairs(B.roots) do
        need(type(v.present[name])=="boolean","The backup is missing a saved-variable slot.")
        need(v.present[name]==(v.stores[name]~=nil),"The backup has an incomplete saved-variable slot.")
        local root=v.stores[name]
        need(not plain(root) or root.bestiaryBackups==nil,"Nested backup archives are not supported.")
    end
    return v
end
local function checksum(s)
    local a,b=1,0
    for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end
    return string.format("%08x",b*65536+a)
end
B.Checksum=checksum
local function encode(value)
    local out,ancestors,nodes,bytes={},{},0,0
    local function put(s)
        bytes=bytes+#s;need(bytes<=B.MAX_BYTES-16,"Backup exceeds the 256 MiB portable limit; use a SavedVariables file copy. Nothing was truncated.")
        out[#out+1]=s
    end
    local function pack(v,depth)
        nodes=nodes+1
        need(nodes<=B.MAX_NODES and depth<=B.MAX_DEPTH,"Backup structure exceeds the portable limit; use a SavedVariables file copy.")
        need(public(v),"Restricted values cannot be backed up.")
        local kind=type(v)
        if kind=="table" then
            need(plain(v) and not ancestors[v],"Cyclic or nonliteral backup data.")
            ancestors[v]=true
            local keys={}
            for k in pairs(v) do
                need(public(k) and (type(k)=="string" or type(k)=="number" or type(k)=="boolean"),"Invalid backup key.")
                if type(k)=="number" then need(k==k and math.abs(k)<math.huge,"Invalid numeric key.") end
                keys[#keys+1]=k;need(#keys<=B.MAX_NODES,"Too many backup keys.")
            end
            table.sort(keys,function(a,b)
                if type(a)~=type(b) then return type(a)<type(b) end
                if type(a)=="boolean" then return not a and b end
                return a<b
            end)
            put("m"..#keys..":")
            for _,k in ipairs(keys) do pack(k,depth+1);pack(v[k],depth+1) end
            ancestors[v]=nil
        elseif kind=="string" then
            need(#v<=B.MAX_BYTES,"Backup string exceeds the portable limit.")
            local s=v:gsub("[^A-Za-z0-9_.%-]",function(c) return string.format("%%%02X",c:byte()) end)
            put("s"..#s..":");put(s)
        elseif kind=="number" then
            need(v==v and math.abs(v)<math.huge,"Non-finite backup number.")
            put("n"..string.format("%.17g",v)..":")
        elseif kind=="boolean" then put(v and "y" or "z")
        else need(false,"Nonliteral backup value.") end
    end
    pack(value,0)
    return table.concat(out)
end
local function decode(s)
    local pos,nodes=1,0
    local function header()
        local last=s:find(":",pos,true)
        need(last and last-pos<=32,"Invalid backup length.")
        local token=s:sub(pos,last-1);pos=last+1;return token
    end
    local parse
    parse=function(depth)
        nodes=nodes+1
        need(nodes<=B.MAX_NODES and depth<=B.MAX_DEPTH,"Backup parser limit reached.")
        local tag=s:sub(pos,pos);pos=pos+1
        if tag=="y" then return true elseif tag=="z" then return false end
        local token=header()
        if tag=="n" then
            local n=tonumber(token)
            need(n and n==n and math.abs(n)<math.huge and string.format("%.17g",n)==token,"Invalid backup number.")
            return n
        end
        need(token:match("^%d+$"),"Invalid backup length.")
        local count=tonumber(token)
        if tag=="s" then
            need(count<=B.MAX_BYTES and count<=#s-pos+1,"Truncated backup string.")
            local text=s:sub(pos,pos+count-1);pos=pos+count
            need(not text:gsub("%%[A-Fa-f0-9][A-Fa-f0-9]",""):find("[^A-Za-z0-9_.%-]"),"Invalid backup escape.")
            return (text:gsub("%%(%x%x)",function(hex) return string.char(tonumber(hex,16)) end))
        end
        need(tag=="m" and count<=(B.MAX_NODES-nodes)/2,"Invalid backup table.")
        local out={}
        for _=1,count do
            local k=parse(depth+1)
            need((type(k)=="string" or type(k)=="number" or type(k)=="boolean") and out[k]==nil,"Duplicate or invalid backup key.")
            out[k]=parse(depth+1)
        end
        return out
    end
    local result=parse(0);need(pos==#s+1,"Trailing backup data.");return result
end
local function attempt(fn,...)
    local ok,value=pcall(fn,...)
    if ok then return value end
    -- Only our literal diagnostics leave this boundary, never arbitrary payloads.
    return nil,type(value)=="string" and value:sub(1,220) or "Backup validation failed."
end
function B.Encode(snapshot)
    return attempt(function()
        envelope(snapshot)
        local payload=encode(snapshot)
        return "AFBWB1:"..checksum(payload)..":"..payload
    end)
end
function B.Decode(text)
    return attempt(function()
        need(public(text) and type(text)=="string" and #text<=B.MAX_BYTES,"Backup text exceeds the 256 MiB limit.")
        local clean=text:gsub("%s","")
        local digest,payload=clean:match("^AFBWB1:(%x%x%x%x%x%x%x%x):(.*)$")
        need(payload,"Paste a whole-Fieldbook backup (AFBWB1). Reports and legacy AFB1 Bestiary copies use different formats.")
        need(checksum(payload)==digest:lower(),"Backup checksum failed. Copy every character; nothing has changed.")
        return envelope(decode(payload))
    end)
end
function B.Capture()
    return attempt(function()
        local who=owner();need(who,"Your character identity is unavailable. Try after logging in.")
        local snapshot={format="AFB-WHOLE",version=B.VERSION,created=read(time) or 0,
            addonVersion=read(C_AddOns and C_AddOns.GetAddOnMetadata,addonName,"Version") or "unknown",
            owner=who,present={},stores={}}
        for _,name in ipairs(B.roots) do
            local value=_G[name];snapshot.present[name]=value~=nil
            if plain(value) then
                -- Only backup containers are excluded. Serialization detaches all
                -- descendants and bounds cycles before anything is saved.
                local root={};for k,v in pairs(value) do if k~="bestiaryBackups" then root[k]=v end end
                snapshot.stores[name]=root
            else snapshot.stores[name]=value end
        end
        local text,err=B.Encode(snapshot);need(text,err)
        return text
    end)
end

local collections={
    gathering={"entries"},atlas={"records","expeditions","weather","settings","subzones","loreAliases"},
    angling={"waters","spots","pools","items","aggregates","history","sessions","recent","recentOrder","waterKeys",
        "poolKeys","itemKeys","aggregateKeys","reported","claims","reportOrigins","state","merged","hoverKeys","eventLog"},
    ledger={"contacts","state","aliases","reportKeys","references","contactAliases"},
    treasure={"kinds","encounters","state"},lore={"entries","state"},
}
local function tables(root,names)
    for _,name in ipairs(names) do need(root[name]==nil or plain(root[name]),"Malformed saved collection: "..name..".") end
end
local function bestiary(root)
    if root.bestiary==nil then return end
    need(plain(root.bestiary),"Malformed Bestiary store.")
    tables(root.bestiary,{"entries","creatures","points","recentKills","sharing","sharingCharacters","zoneTerritories"})
    -- Reuse the accepted schema as a check, never its lossy projection as the
    -- restored value. Legacy partial stores are checked after detached defaults.
    local b=root.bestiary
    local function check(v)
        local valid=ns.BestiaryBackups.Validate({version=1,created=0,addonVersion="backup",scope="character",bestiary=v},false)
        need(valid,"Bestiary data is not supported for restoration; the raw copy can still be exported.")
        return valid.bestiary
    end
    -- Validate each record separately so the legacy 300,000-node single-copy
    -- limit does not become a whole-Fieldbook archive limit.
    local emptyPoints={earned=0,spent=0,credits={}}
    for id,e in pairs(b.entries or {}) do check({entries={[id]=e},creatures={},points=emptyPoints}) end
    for id,e in pairs(b.creatures or {}) do check({entries={},creatures={[id]=e},points=emptyPoints}) end
    local v={entries={},creatures={},points=emptyPoints}
    for k,x in pairs(b) do if k~="entries" and k~="creatures" and k~="points" then v[k]=x end end
    check(v)
    if b.points then
        need(b.points.version==nil or b.points.version==1,"Unsupported Knowledge ledger version.")
        tables(b.points,{"credits","reservations"})
        local ledger={};for k,x in pairs(b.points) do ledger[k]=x end;ledger.credits={}
        check({entries={},creatures={},points=ledger})
        for id,credit in pairs(b.points.credits or {}) do
            check({entries={},creatures={},points={earned=0,spent=0,credits={[id]=credit}}})
        end
        for tx,cost in pairs(b.points.reservations or {}) do
            need(type(tx)=="string" and integer(cost,0,999999999999),"Invalid Knowledge reservation.")
        end
    end
end
local function section(key,value)
    need(plain(value) and (value.schema==nil or integer(value.schema,0,1)),"Unsupported "..key.." saved schema. Keep the raw export for recovery with a compatible addon.")
    tables(value,collections[key])
    for _,field in ipairs({"serial","nextID","referenceSerial"}) do
        need(value[field]==nil or integer(value[field],0,999999999),"Invalid "..key.." identity counter.")
    end
    for _,field in ipairs({"origin","referenceOrigin","captureOrigin","contactOrigin","archiveID","exportOrigin","idPrefix"}) do
        need(value[field]==nil or label(value[field]),"Invalid "..key.." identity namespace.")
    end
    -- Lore/Treasure deliberately retain invalid records outside their active
    -- views. Do not feed them through report validators or discard quarantine.
    if key=="lore" or key=="treasure" then return end
    local maps=({gathering={"entries"},atlas={"records","expeditions"},
        angling={"waters","spots","pools","items","aggregates","reported","merged","claims","reportOrigins"},ledger={"contacts"}})[key]
    for _,field in ipairs(maps) do for id,e in pairs(value[field] or {}) do
        need(type(id)=="string" and plain(e),"Invalid "..key.." record.")
        if field~="claims" and field~="reportOrigins" then need(e.id==nil or e.id==id,"Inconsistent "..key.." record identity.") end
    end end
    if key=="gathering" then
        for id,e in pairs(value.entries or {}) do
            local name=ns.GatheringName(e.name)
            need(ns.GatheringKinds[e.kind] and name and id==e.kind..":"..name:lower(),"Invalid gathering identity.")
            tables(e,{"loot","zones","locations"})
            need(e.note==nil or (type(e.note)=="string" and #e.note<=4000),"Invalid gathering note.")
            for _,field in ipairs({"interactions","completed","firstSeen","lastSeen"}) do
                need(e[field]==nil or integer(e[field],0,9999999999),"Invalid gathering counter.")
            end
            need(not e.completed or not e.interactions or e.completed<=e.interactions,"Invalid gathering completion count.")
            need(ns.Atlas.Count(e.loot or {})<=128 and ns.Atlas.Count(e.locations or {})<=64,"Gathering collection exceeds its supported limit.")
            for id,item in pairs(e.loot or {}) do
                need(integer(id,1,2147483647) and plain(item) and integer(item.minQuantity,1,1000000)
                    and integer(item.maxQuantity,item.minQuantity,1000000) and integer(item.firstSeen,0,9999999999)
                    and integer(item.lastSeen,item.firstSeen,9999999999),"Invalid gathering loot.")
            end
            for zone,flag in pairs(e.zones or {}) do
                need(ns.GatheringName(zone) and flag==true,"Invalid gathering zone evidence.")
            end
            for mapID,map in pairs(e.locations or {}) do
                need(integer(mapID,1,2147483647) and plain(map) and ns.GatheringName(map.name),"Invalid gathering map.")
                tables(map,{"points"});need(ns.Atlas.Count(map.points or {})<=256,"Gathering map exceeds its point limit.")
                for pointID,p in pairs(map.points or {}) do
                    need(plain(p) and integer(p.x,0,10000) and integer(p.y,0,10000) and integer(p.seenAt,0,9999999999)
                        and pointID==1+p.x*10001+p.y,"Invalid gathering coordinates.")
                end
            end
        end
    elseif key=="atlas" then
        for _,field in ipairs({"records","expeditions"}) do for _,e in pairs(value[field] or {}) do
            need(ns.Atlas.ValidateRecord(e,field=="expeditions"),"Invalid Atlas record.")
        end end
    elseif key=="angling" then
        for _,field in ipairs({"history","sessions","recentOrder","eventLog"}) do
            need(ns.Atlas.Array(value[field] or {},B.MAX_NODES),"Sparse Almanac list.")
        end
        for _,spec in ipairs({{"history",200},{"sessions",32},{"recentOrder",256}}) do
            need(#(value[spec[1]] or {})<=spec[2],"Almanac history exceeds the supported retained limit.")
        end
        for _,field in ipairs({"waters","spots","pools","items","merged"}) do for _,e in pairs(value[field] or {}) do
            tables(e,{"personal","origin","claims"})
            need(e.name==nil or ns.Angling.Name(e.name),"Invalid Almanac name.")
        end end
        for _,field in ipairs({"history","sessions","recent"}) do for _,e in pairs(value[field] or {}) do
            need(plain(e),"Invalid Almanac history record.");tables(e,{"items","skill"})
        end end
        for _,e in ipairs(value.eventLog or {}) do
            need(plain(e) and integer(e.at,0,9999999999) and ns.Angling.Text(e.kind,40)
                and ns.Angling.Text(e.message,4000) and (e.key==nil or ns.Angling.Text(e.key,240)),"Invalid Almanac event log.")
        end
        for _,field in ipairs({"waterKeys","poolKeys","itemKeys","aggregateKeys","hoverKeys"}) do
            for k,id in pairs(value[field] or {}) do need(type(k)=="string" and type(id)=="string","Invalid Almanac identity index.") end
        end
        for _,field in ipairs({"aggregates","reported"}) do for _,e in pairs(value[field] or {}) do
            tables(e,{"items","skill","origin"})
        end end
    elseif key=="ledger" then
        for _,e in pairs(value.contacts or {}) do
            need(ns.Ledger.Name(e.name) and ns.Ledger.Text(e.reference,160),"Invalid Ledger identity.")
            tables(e,{"roles","manualRoles","specialities","sightings","goods","lessons","reports","aliases","migrationEvidence"})
            need(ns.Atlas.Array(e.sightings or {},B.MAX_NODES) and ns.Atlas.Array(e.reports or {},B.MAX_NODES),"Sparse Ledger evidence list.")
        end
    end
end
function B.CanRestore(snapshot)
    return attempt(function()
        envelope(snapshot)
        need(sameOwner(snapshot.owner,owner()),"Restore on the character that made this backup. It includes that character's retained journals and account identity.")
        local main=snapshot.stores[B.roots[1]]
        need(plain(main) and main.version==1,"This copy has an unsupported main save; export it for file recovery.")
        need(main.accountTrackingKey==nil or integer(main.accountTrackingKey,1,2147483647),"Invalid character import identity.")
        need(main.accountWideTracking==nil or type(main.accountWideTracking)=="boolean","Invalid tracking scope.")
        need(main.accountTrackingActive==nil or type(main.accountTrackingActive)=="boolean","Invalid applied tracking scope.")
        tables(main,{"eventLog","spellIDWindowBlacklist","sourceClasses"});bestiary(main)
        if main.eventLog then tables(main.eventLog,{"entries"}) end
        local account=snapshot.stores[B.roots[2]]
        if account~=nil then
            need(plain(account) and (account.version==nil or account.version==1),"Unsupported account save.")
            tables(account,{"sections","sectionImports","importedCharacters","atlasReferenceMaps","atlasReferenceIssues","atlasReferenceRepairs","anglingIdentityRepairs"})
            bestiary(account)
            for key,value in pairs(account.sections or {}) do need(sections[key],"Unsupported account journal.");section(key,value) end
            if account.nextCharacter~=nil then need(integer(account.nextCharacter,0,2147483647),"Invalid account identity counter.") end
            local function markers(map)
                for key,flag in pairs(map or {}) do
                    need(integer(key,1,2147483647) and flag==true,"Invalid one-time import marker.")
                    need(not account.nextCharacter or key<=account.nextCharacter,"Account identity counter precedes an imported character.")
                end
            end
            markers(account.importedCharacters)
            markers(account.atlasReferenceRepairs);markers(account.anglingIdentityRepairs)
            need(account.atlasFirstImport==nil or integer(account.atlasFirstImport,1,2147483647),"Invalid Atlas import owner.")
            for _,field in ipairs({"atlasReferenceMaps","atlasReferenceIssues"}) do
                for key,map in pairs(account[field] or {}) do
                    need(integer(key,1,2147483647) and plain(map),"Invalid scoped Atlas reference map.")
                    for reference,target in pairs(map) do
                        need(type(reference)=="string" and (type(target)=="string" or (field=="atlasReferenceMaps" and target==false)),
                            "Invalid Atlas reference destination.")
                    end
                end
            end
            for key,map in pairs(account.sectionImports or {}) do
                need(sections[key] and plain(map),"Invalid section import registry.");markers(map)
            end
        end
        for key,index in pairs(sections) do
            local value=snapshot.stores[B.roots[index]];if value~=nil then section(key,value) end
        end
        return true
    end)
end

local function archive()
    local a=AzerothFieldbookBackupDB
    if a==nil then return {version=1,saved={}} end
    if not plain(a) or a.version~=1 or not plain(a.saved) then return nil,"The backup archive is unsupported; its data was left untouched. Use an external SavedVariables copy." end
    local n=0
    for k,v in pairs(a.saved) do
        if not integer(k,1,B.MAX_SAVED) or type(v)~="string" then return nil,"Malformed backup archive; nothing was changed." end
        n=n+1
    end
    for i=1,n do if a.saved[i]==nil then return nil,"Incomplete backup archive; nothing was changed." end end
    for _,key in ipairs({"recovery","pending"}) do if a[key]~=nil and type(a[key])~="string" then return nil,"Malformed backup archive; nothing was changed." end end
    return a
end
B.GetArchive=archive
local prepare
function B.Create()
    local a,err=archive();if not a then return nil,err end
    if a.pending then return nil,"A restore is awaiting /reload. No new backup was saved." end
    local text,reason=B.Capture();if not text then return nil,reason end
    local saved={text};for i=1,math.min(#a.saved,B.MAX_SAVED-1) do saved[#saved+1]=a.saved[i] end
    a.saved=saved;AzerothFieldbookBackupDB=a
    return text
end
function B.RequestRestore(text)
    if InCombatLockdown and read(InCombatLockdown)~=false then return nil,"Restore outside combat." end
    local a,err=archive();if not a then return nil,err end
    if a.pending then return nil,"A restore is already awaiting /reload." end
    local snapshot,reason=B.Decode(text);if not snapshot then return nil,reason end
    local ok,why=B.CanRestore(snapshot);if not ok then return nil,why end
    local ready,problem=attempt(prepare,snapshot);if not ready then return nil,problem end
    local recovery,failure=B.Capture()
    if not recovery then return nil,"Could not save a recovery copy. "..failure end
    -- No live roots are replaced in this namespace. A fresh load consumes this
    -- request before any migration, journal, UI or capture initialization.
    a.recovery=recovery;a.pending=text;AzerothFieldbookBackupDB=a
    if ns.HoldForFieldbookRestore then ns.HoldForFieldbookRestore() end
    return true
end
function B.CancelPending()
    local a,err=archive();if not a then return nil,err end
    a.pending=nil;return true
end
local function retainCurrent(b,current)
    -- Preserve accepted Bestiary recovery accounting and current delivery state.
    -- Never resurrect a transaction or reservation from a portable backup.
    if not b then return end
    local old=plain(current) and current.bestiary
    -- Detach delivery state as well: startup can update its stages. A failed
    -- startup must be able to put the original root objects back untouched.
    b.sharing=plain(old) and old.sharing and decode(encode(old.sharing)) or nil
    b.sharingCharacters=plain(old) and old.sharingCharacters and decode(encode(old.sharingCharacters)) or nil
    if b.points then
        b.points.reservations={}
        if plain(old) and old.points then
            -- Damaged creature records must not prevent recovering readable
            -- accounting. The recovery copy still retains the raw damaged save.
            bestiary({bestiary={points=old.points}})
            local function normalized(points)
                local ledger={};for k,v in pairs(points) do ledger[k]=v end
                ledger.credits={}
                for id,credit in pairs(points.credits or {}) do
                    local v=ns.BestiaryBackups.Validate({version=1,created=0,addonVersion="backup",scope="character",
                        bestiary={entries={},creatures={},points={earned=0,spent=0,credits={[id]=credit}}}},false)
                    ledger.credits[id]=v.bestiary.points.credits[id]
                end
                ledger.reservations=ledger.reservations or {}
                return ledger
            end
            b.points=ns.BestiaryBackups.MergePoints(normalized(old.points),normalized(b.points))
        end
    end
    if plain(old) and plain(old.recentKills) then
        b.recentKills=b.recentKills or {};local seen={}
        for _,id in ipairs(b.recentKills) do seen[id]=true end
        for _,id in ipairs(old.recentKills) do if not seen[id] then b.recentKills[#b.recentKills+1]=id;seen[id]=true end end
    end
end
prepare=function(snapshot)
    for _,name in ipairs({B.roots[1],B.roots[2]}) do
        local incoming,current=snapshot.stores[name],_G[name]
        if plain(current) and (plain(current.bestiary) or current.bestiaryBackups) then
            incoming=incoming or {version=1};snapshot.stores[name]=incoming
            if plain(current.bestiary) and current.bestiary.points then
                incoming.bestiary=incoming.bestiary or {entries={},creatures={}}
                incoming.bestiary.points=incoming.bestiary.points or {earned=0,spent=0,credits={}}
            end
            incoming.bestiaryBackups=current.bestiaryBackups
        end
        if incoming then retainCurrent(incoming.bestiary,current) end
    end
    -- Characters created since the backup still own their import keys in
    -- offline files. Never let a later new character reuse those keys.
    local oldAccount=AzerothFieldbookAccountDB
    local main=snapshot.stores[B.roots[1]]
    local currentMain=AzerothFieldbookDB
    if main.accountTrackingKey==nil and plain(currentMain) and integer(currentMain.accountTrackingKey,1,2147483647) then
        main.accountTrackingKey=currentMain.accountTrackingKey
    end
    if plain(oldAccount) and integer(oldAccount.nextCharacter,1,2147483647) then
        local name=B.roots[2]
        local incoming=snapshot.stores[name] or {version=1}
        incoming.nextCharacter=math.max(incoming.nextCharacter or 0,oldAccount.nextCharacter)
        snapshot.stores[name]=incoming
    end
    -- One-time imports are also replay guards. Rolling them back can re-import
    -- an offline character's original counts/points when that character returns.
    -- Keep supported current markers, creating empty destinations when the old
    -- snapshot predates that shared journal. Do not copy current journal records.
    if plain(oldAccount) then
        local incoming=snapshot.stores[B.roots[2]] or {version=1}
        local function markers(target,source)
            if not plain(source) then return target end
            target=target or {}
            for key,flag in pairs(source) do if integer(key,1,2147483647) and flag==true then
                target[key]=true;incoming.nextCharacter=math.max(incoming.nextCharacter or 0,key)
            end end
            return target
        end
        incoming.importedCharacters=markers(incoming.importedCharacters,oldAccount.importedCharacters)
        if plain(oldAccount.sectionImports) then
            incoming.sectionImports=incoming.sectionImports or {};incoming.sections=incoming.sections or {}
            for key,source in pairs(oldAccount.sectionImports) do if sections[key] and plain(source) then
                incoming.sectionImports[key]=markers(incoming.sectionImports[key],source)
                if next(incoming.sectionImports[key]) then incoming.sections[key]=incoming.sections[key] or {} end
            end end
        end
        snapshot.stores[B.roots[2]]=incoming
    end
    -- The same protection applies to records already referenced or reported
    -- after this backup was made. Keep allocation counters ahead of those IDs.
    local function counters(incoming,current)
        if not plain(incoming) or not plain(current) then return end
        for _,key in ipairs({"serial","nextID","referenceSerial"}) do
            if integer(current[key],0,999999999) then
                need(incoming[key]==nil or integer(incoming[key],0,999999999),"Invalid journal identity counter.")
                incoming[key]=math.max(incoming[key] or 0,current[key])
            end
        end
    end
    for key,index in pairs(sections) do
        counters(snapshot.stores[B.roots[index]],_G[B.roots[index]])
        local incoming=snapshot.stores[B.roots[2]]
        counters(incoming and incoming.sections and incoming.sections[key],
            plain(oldAccount) and plain(oldAccount.sections) and oldAccount.sections[key])
    end
    return snapshot
end
local applied
function B.ApplyPending()
    local a,err=archive();if not a then return nil,err end
    if not a.pending then return true end
    return attempt(function()
        need(not ns.InitializationBlocked,"A fresh /reload is required before applying this restore.")
        local snapshot,reason=B.Decode(a.pending);need(snapshot,reason)
        local ok,why=B.CanRestore(snapshot);need(ok,why)
        local recovery,failure=B.Capture();need(recovery,"Recovery capture failed: "..(failure or ""))
        prepare(snapshot)
        local previous={};for _,name in ipairs(B.roots) do previous[name]=_G[name] end
        -- All fallible work is complete. No callbacks or migrations in the commit.
        applied={previous=previous,pending=a.pending,archive=a}
        a.recovery=recovery
        for _,name in ipairs(B.roots) do _G[name]=snapshot.stores[name] end
        a.pending=nil
        return true
    end)
end
function B.FinishStartup(success)
    if not applied then return end
    if not success then
        for _,name in ipairs(B.roots) do _G[name]=applied.previous[name] end
        applied.archive.pending=applied.pending
    end
    applied=nil
    return true
end

function B.Parts(text)
    local out={};local count=math.ceil(#text/B.PART_BYTES);local digest=checksum(text)
    for i=1,count do
        local chunk=text:sub((i-1)*B.PART_BYTES+1,i*B.PART_BYTES)
        out[i]="AFBWP1:"..digest..":"..i..":"..count..":"..checksum(chunk)..":"..chunk
    end
    return out
end
function B.AddPart(session,text)
    return attempt(function()
        need(type(text)=="string" and #text<=B.PART_BYTES*2,"Paste one backup part at a time.")
        text=text:gsub("%s","")
        local digest,index,total,sum,chunk=text:match("^AFBWP1:(%x%x%x%x%x%x%x%x):(%d+):(%d+):(%x%x%x%x%x%x%x%x):(.*)$")
        index,total=tonumber(index),tonumber(total)
        need(chunk and integer(total,1,math.ceil(B.MAX_BYTES/B.PART_BYTES)) and integer(index,1,total),"Invalid backup part header.")
        need(#chunk>0 and #chunk<=B.PART_BYTES and (index==total or #chunk==B.PART_BYTES) and checksum(chunk)==sum:lower(),"Incomplete or changed backup part.")
        need(not session.digest or (session.digest==digest and session.total==total),"These parts belong to different backups. Start a new import.")
        need(not session[index] or session[index]==chunk,"Conflicting duplicate backup part.")
        local parts={};for k,v in pairs(session) do parts[k]=v end
        parts.digest,parts.total=digest,total;parts[index]=chunk
        local received=0;for i=1,total do if parts[i] then received=received+1 end end
        parts.received=received
        if received==total then
            local complete=table.concat(parts)
            need(#complete<=B.MAX_BYTES and checksum(complete)==digest,"Whole-backup checksum failed.")
            local snapshot,err=B.Decode(complete);need(snapshot,err)
            parts.complete=complete
        end
        return parts
    end)
end
function B.Summary(snapshot)
    local lines={"All seven journals: account data + "..snapshot.owner.name.."'s retained character data.",
        "Created "..(read(date,"%d %b %Y, %H:%M:%S",snapshot.created) or tostring(snapshot.created)).." • addon "..snapshot.addonVersion}
    local function count(v) local n=0;if plain(v) then for _ in pairs(v) do n=n+1 end end;return n end
    local main,account=snapshot.stores[B.roots[1]],snapshot.stores[B.roots[2]]
    local function store(root,key) return plain(root) and root[key] or nil end
    local function entries(root,field) return count(store(root,field)) end
    lines[#lines+1]="Account / character saved records (including preserved records):"
    lines[#lines+1]="Bestiary: "..entries(store(account,"bestiary"),"entries").." / "..entries(store(main,"bestiary"),"entries")
    for _,spec in ipairs({{"gathering","Gatherer's Compendium",{"entries"}},{"atlas","Traveller's Atlas",{"records","expeditions"}},
        {"angling","Angler's Almanac",{"waters","pools","items","spots","merged","aggregates","reported"}},
        {"ledger","Merchant's Ledger",{"contacts"}},{"treasure","Treasure Journal",{"kinds","encounters"}},
        {"lore","Lorekeeper's Chronicle",{"entries"}}}) do
        local shared,personal=0,0
        for _,field in ipairs(spec[3]) do
            shared=shared+entries(store(store(account,"sections"),spec[1]),field)
            personal=personal+entries(snapshot.stores[B.roots[sections[spec[1]]]],field)
        end
        lines[#lines+1]=spec[2]..": "..shared.." / "..personal
    end
    return table.concat(lines,"\n")
end
