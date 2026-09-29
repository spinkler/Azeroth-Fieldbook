local addonName, ns = ...
local A=ns.Angling
local R={VERSION=1,MAX_BYTES=98304,MAX_RECORDS=120,MAX_FACTS=128,MAX_STORED_FACTS=4096,MAX_CLAIMS=8192}
ns.AnglingReports=R
local function version() return A.Read(C_AddOns and C_AddOns.GetAddOnMetadata,addonName,"Version") or "unknown" end
local function need(ok,message) if not ok then error(message,0) end end
local function fields(t,allowed)
    need(A.Public(t) and type(t)=="table" and not getmetatable(t),"Expected a plain report table.")
    for k,v in pairs(t) do need(A.Public(k) and allowed[k] and A.Public(v),"Unexpected or unreadable report field.") end
end
local function text(v,max,empty)
    need(A.Text(v,max,empty) and (max>180 or not v:find("%c")),"Invalid or oversized plain text.");return v
end
local function num(v,lo,hi) need(A.Integer(v,lo,hi),"Invalid report number.");return v end
local function array(v,max) need(A.Array(v,max),"Invalid or oversized report list.");return v end
local function origin(v)
    fields(v,{source=true,key=true,method=true,legacyKeys=true})
    need(v.method=="observed" or v.method=="recorded","Invalid original provenance.")
    local out={source=text(v.source,160),key=text(v.key,180),method=v.method}
    if v.legacyKeys then
        out.legacyKeys={};local seen={}
        for _,key in ipairs(array(v.legacyKeys,32)) do
            key=text(key,180);need(not seen[key],"Duplicate legacy identity.");seen[key]=true
            out.legacyKeys[#out.legacyKeys+1]=key
        end
    end
    return out
end
local function skill(v)
    fields(v,{base=true,modifier=true,temporary=true,effective=true,equipment=true,lure=true})
    local s={};for k,value in pairs(v) do s[k]=num(value,k=="modifier" and -1000 or 0,10000) end
    need(s.effective~=nil,"Successful-skill evidence needs an effective value.")
    if s.base and s.modifier and s.temporary==0 then need(s.effective==s.base+s.modifier,"Inconsistent skill components.") end
    return s
end
local function normalize(value)
    fields(value,{format=true,version=true,addonVersion=true,sender=true,created=true,records=true,facts=true})
    need(value.format=="AFB-ANGLING" and value.version==R.VERSION,"Unsupported fishing report format/version.")
    need(version()~="unknown","Installed addon version metadata is unavailable.")
    need(text(value.addonVersion,32)==version(),"Fishing reports require the same installed addon version.")
    local out={format="AFB-ANGLING",version=R.VERSION,addonVersion=value.addonVersion,sender=text(value.sender,160),
        created=num(value.created,0,9999999999),records={},facts={}}
    local known,origins={},{}
    for _,v in ipairs(array(value.records,R.MAX_RECORDS)) do
        fields(v,{id=true,kind=true,name=true,origin=true,first=true,last=true,mapID=true,zone=true,subzone=true,x=true,y=true,
            precision=true,waterID=true,poolID=true,itemID=true,objectID=true,locale=true,notes=true})
        local id=text(v.id,32);need(id:match("^r%d+$") and not known[id],"Invalid or duplicate record reference.")
        need(v.kind=="water" or v.kind=="spot" or v.kind=="pool" or v.kind=="item","Invalid fishing record kind.")
        local e={id=id,kind=v.kind,name=text(v.name,160),origin=origin(v.origin),first=num(v.first,0,9999999999),last=num(v.last,0,9999999999)}
        need(e.first<=e.last,"Invalid observation dates.")
        local key=A.Key(e.origin.source,e.origin.key);need(not origins[key],"Duplicate original record identity.");origins[key]=true
        if v.kind=="water" or v.kind=="spot" then
            e.zone=text(v.zone,160);e.subzone=text(v.subzone,160,true)
            if v.mapID~=nil then e.mapID=num(v.mapID,1,2147483647) end
            if v.kind=="spot" then
                e.waterID=text(v.waterID,32);if v.poolID then e.poolID=text(v.poolID,32) end
                need(v.precision=="player" or v.precision=="approximate" or v.precision=="exact" or v.precision=="unknown","Invalid position precision.")
                e.precision=v.precision
                if v.x~=nil or v.y~=nil then
                    need(e.mapID and e.precision~="unknown","Position needs a map and precision.")
                    e.x=num(v.x,0,10000);e.y=num(v.y,0,10000)
                else need(e.precision=="unknown","Unpositioned spots must have unknown precision.") end
            else need(v.x==nil and v.y==nil and v.precision==nil and v.waterID==nil and v.poolID==nil,"Waters are not pool positions.") end
            need(v.itemID==nil and v.objectID==nil and v.locale==nil,"Unexpected location identity.")
        else
            for _,k in ipairs({"mapID","zone","subzone","x","y","precision","waterID","poolID"}) do need(v[k]==nil,"Unexpected identity position.") end
            e.locale=text(v.locale,20)
            if v.kind=="item" then
                need(v.objectID==nil,"Unexpected pool identifier.")
                if v.itemID~=nil then e.itemID=num(v.itemID,1,2147483647) end
            else
                need(v.itemID==nil,"Unexpected item identifier.")
                if v.objectID~=nil then e.objectID=num(v.objectID,1,2147483647) end
            end
        end
        if v.notes~=nil then e.notes=text(v.notes,4000,true) end
        known[id]=e;out.records[#out.records+1]=e
    end
    need(#out.records>0,"Select some fishing knowledge first.")
    local function ref(id,kind) need(known[id] and known[id].kind==kind,"Missing or incompatible report reference.");return id end
    for _,e in ipairs(out.records) do if e.kind=="spot" then
        ref(e.waterID,"water");if e.poolID then ref(e.poolID,"pool") end
        local w=known[e.waterID];need(e.mapID==w.mapID and e.zone==w.zone and e.subzone==w.subzone,"Spot belongs to different waters.")
    end end
    local factIDs,factOrigins={},{}
    for _,v in ipairs(array(value.facts,R.MAX_FACTS)) do
        fields(v,{id=true,origin=true,waterID=true,spotID=true,poolID=true,source=true,association=true,events=true,first=true,last=true,
            items=true,lowestSkill=true,lowestSkillAt=true})
        local id=text(v.id,32);need(id:match("^f%d+$") and not factIDs[id],"Invalid or duplicate catch fact.");factIDs[id]=true
        local f={id=id,origin=origin(v.origin),waterID=ref(v.waterID,"water"),source=v.source,association=v.association,
            events=num(v.events,1,1000000000),first=num(v.first,0,9999999999),last=num(v.last,0,9999999999),items={}}
        need(f.first<=f.last,"Invalid catch dates.")
        local key=A.Key(f.origin.source,f.origin.key);need(not factOrigins[key],"Duplicate original catch fact.");factOrigins[key]=true
        need(A.SourceLabels[f.source],"Invalid source classification.")
        need(f.association=="assigned" or f.association=="observed" or f.association=="unknown","Invalid association evidence.")
        if f.source=="pool" then f.poolID=ref(v.poolID,"pool");need(f.association~="unknown","A pool needs supporting association evidence.")
        else need(v.poolID==nil,"Non-pool catch cannot claim pool contents.") end
        if f.source=="unclassified" then need(f.association=="unknown","Unclassified association must be unknown.") end
        if f.source=="open" then need(f.association~="unknown","Open water requires positive evidence or assignment.") end
        if v.spotID then
            f.spotID=ref(v.spotID,"spot");local spot=known[f.spotID]
            need(spot.waterID==f.waterID and (not spot.poolID or spot.poolID==f.poolID),"Conflicting spot/source references.")
        end
        local seen={}
        for _,item in ipairs(array(v.items,100)) do
            fields(item,{itemID=true,quantity=true,occurrences=true,first=true,last=true})
            local itemID=ref(item.itemID,"item");need(not seen[itemID],"Duplicate caught item.");seen[itemID]=true
            local n={itemID=itemID,quantity=num(item.quantity,1,1000000000000),occurrences=num(item.occurrences,1,f.events),
                first=num(item.first,f.first,f.last),last=num(item.last,f.first,f.last)}
            need(n.quantity>=n.occurrences and n.first<=n.last,"Inconsistent observed item counts.");f.items[#f.items+1]=n
        end
        need(#f.items>0,"A catch fact needs obtained items.")
        if v.lowestSkill then
            need(f.origin.method=="observed","Player-recorded catches are not measured successful-skill evidence.")
            f.lowestSkill=skill(v.lowestSkill);f.lowestSkillAt=num(v.lowestSkillAt,f.first,f.last)
        else need(v.lowestSkillAt==nil,"Missing skill evidence.") end
        out.facts[#out.facts+1]=f
    end
    for _,rows in ipairs({out.records,out.facts}) do
        local aliases={}
        for i,row in ipairs(rows) do for _,key in ipairs(row.origin.legacyKeys or {}) do
            need(not aliases[key] or aliases[key]==i,"Overlapping original identity aliases.");aliases[key]=i
        end end
        for i,row in ipairs(rows) do need(not aliases[row.origin.key] or aliases[row.origin.key]==i,"Conflicting original identity alias.") end
    end
    return out
end
-- Almanac-local use of the repository's bounded length-prefixed literal format.
-- Atlas's codec is schema-bound, so it cannot safely encode a fishing report.
local function encode(v)
    if type(v)=="string" then return "s"..#v..":"..v end
    if type(v)=="number" then local s=string.format("%.0f",v);return "n"..#s..":"..s end
    local keys={};for k in pairs(v) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
    local parts={"t"..#keys..":"};for _,k in ipairs(keys) do parts[#parts+1]=encode(k);parts[#parts+1]=encode(v[k]) end
    return table.concat(parts)
end
function R.Normalize(value)
    local ok,v=pcall(normalize,value);if not ok then return nil,tostring(v) end
    if #encode(v)+6>R.MAX_BYTES then return nil,"Report exceeds 96 KiB. Select less knowledge." end
    return v
end
function R.Encode(value)
    local v,err=R.Normalize(value);if not v then return nil,err end;return "AFBF1:"..encode(v)
end
function R.Decode(data)
    if not A.Public(data) or type(data)~="string" or #data>R.MAX_BYTES or data:sub(1,6)~="AFBF1:" then return nil,"Invalid or oversized fishing envelope." end
    local function parse()
        local at,nodes=7,0
        local function length(max)
            local colon=data:find(":",at,true);need(colon and colon-at<=7,"Malformed length.")
            local s=data:sub(at,colon-1);need(s:match("^%d+$"),"Invalid length.")
            local n=tonumber(s);need(n<=max,"Oversized field.");at=colon+1;return n
        end
        local function read(depth)
            nodes=nodes+1;need(nodes<=24000 and depth<=12,"Report nesting/item limit exceeded.")
            local kind=data:sub(at,at);at=at+1
            if kind=="s" or kind=="n" then
                local n=length(kind=="s" and 4000 or 16);need(at+n-1<=#data,"Truncated field.")
                local v=data:sub(at,at+n-1);at=at+n
                if kind=="n" then need(v:match("^%-?%d+$"),"Invalid integer literal.");return tonumber(v) end
                return v
            end
            need(kind=="t","Unsupported literal type.")
            local n=length(256);local t={}
            for _=1,n do local k=read(depth+1);need(type(k)=="string" or type(k)=="number","Invalid field key.");need(t[k]==nil,"Duplicate field.");t[k]=read(depth+1) end
            return t
        end
        local value=read(0);need(at==#data+1,"Trailing report data.");return value
    end
    local ok,value=pcall(parse);if not ok then return nil,tostring(value) end
    return R.Normalize(value)
end
function R.Build(journal,id,knowledge,includeNotes)
    local selected=journal:Get(id);if not selected then return nil,"Select a location, pool type or caught item." end
    if selected.removed then return nil,"Restore the record before including it in a report." end
    local rows={}
    for _,row in ipairs(journal:Facts(selected,knowledge=="reported" and "reported" or "personal")) do
        local spot=journal:Get(row.fact.spotID)
        if not (spot and spot.removed) then rows[#rows+1]=row end
    end
    local entities,ids={},{}
    local function add(key)
        if not key or entities[key] then return end
        local e=journal:Get(key);if not e or (e.kind=="spot" and e.removed) then return end
        entities[key]=e;ids[#ids+1]=key
        if e.kind=="spot" then add(e.waterID);add(e.poolID) end
    end
    add(id)
    for _,row in ipairs(rows) do
        local f=row.fact;add(f.waterID);add(f.spotID);add(f.poolID);for key in pairs(f.items) do add(key) end
    end
    if selected.kind=="pool" or selected.kind=="water" then
        for _,spot in pairs(journal.db.spots) do
            if (selected.kind=="pool" and spot.poolID==id) or (selected.kind=="water" and spot.waterID==id) then
                if knowledge=="reported" and #(spot.claims or {})>0 or knowledge~="reported" and spot.personal then add(spot.id) end
            end
        end
    end
    table.sort(ids);local refs={};for i,key in ipairs(ids) do refs[key]="r"..i end
    local report={format="AFB-ANGLING",version=R.VERSION,addonVersion=version(),sender=A.Player(),created=A.Now(),records={},facts={}}
    for _,key in ipairs(ids) do
        local e=entities[key];local r={id=refs[key],kind=e.kind,name=e.name,first=e.personalFirst or e.first,last=e.personalLast or e.last}
        for _,field in ipairs({"mapID","zone","subzone","x","y","precision","itemID","objectID","locale"}) do r[field]=e[field] end
        r.waterID=refs[e.waterID];r.poolID=refs[e.poolID]
        if knowledge=="reported" or not e.personal then
            local claim=journal.db.claims[(e.claims or {})[1]]
            if not claim then return nil,"This selection has no reported identity to forward." end
            if claim.record then
                for _,field in ipairs({"name","mapID","zone","subzone","x","y","precision","itemID","objectID","locale"}) do r[field]=claim.record[field] end
            end
            r.origin=A.Copy(claim.origin);r.first,r.last=claim.first,claim.last
            if includeNotes and key==id then r.notes=claim.notes end
        else
            r.origin=journal:Origin(key)
            if includeNotes and key==id then r.notes=e.note end
        end
        report.records[#report.records+1]=r
    end
    for i,row in ipairs(rows) do
        local f=row.fact;local r={id="f"..i,origin=row.reported and A.Copy(f.origin) or journal:Origin(f.id),
            waterID=refs[f.waterID],spotID=refs[f.spotID],poolID=refs[f.poolID],source=f.source,association=f.association,
            events=f.events,first=f.first,last=f.last,lowestSkill=A.Copy(f.lowestSkill),lowestSkillAt=f.lowestSkillAt,items={}}
        if not row.reported then r.origin.method=f.method end
        local keys={};for key in pairs(f.items) do keys[#keys+1]=key end;table.sort(keys)
        for _,key in ipairs(keys) do
            local item=f.items[key]
            r.items[#r.items+1]={itemID=refs[key],quantity=item.quantity,occurrences=item.occurrences,first=item.first,last=item.last}
        end
        report.facts[#report.facts+1]=r
    end
    return R.Normalize(report)
end
function R.Preview(value)
    local report,err=R.Normalize(value);if not report then return nil,err end
    local lines={"Fishing field report", "Sender claim: "..report.sender.." (not authenticated)",
        #report.records.." identities • "..#report.facts.." observed-result summaries", "Import keeps every claim Reported. Personal totals and notes are unchanged.",""}
    local names={};for _,e in ipairs(report.records) do names[e.id]=e.name end
    for _,e in ipairs(report.records) do
        lines[#lines+1]=e.name.." ["..e.kind.."] — "..e.origin.source.." / "..e.origin.method
        if e.zone then lines[#lines+1]=e.zone..(e.subzone~="" and " / "..e.subzone or "") end
        if e.kind=="spot" then lines[#lines+1]=A.PositionLabel(e).."; last seen "..ns.AtlasUI.Date(e.last) end
        if e.notes then lines[#lines+1]="Included note: "..e.notes end
    end
    for _,f in ipairs(report.facts) do
        lines[#lines+1]="\n"..names[f.waterID].." • "..A.SourceLabels[f.source]..(f.poolID and ": "..names[f.poolID] or "").." ("..f.association..")"
        lines[#lines+1]=f.origin.source.." / "..f.origin.method..": "..f.events.." catch events"
        for _,item in ipairs(f.items) do lines[#lines+1]=names[item.itemID]..": "..item.quantity.." items in "..item.occurrences.." of those events" end
        if f.lowestSkill then lines[#lines+1]="Lowest successful effective skill reported: "..f.lowestSkill.effective.."; requirement unknown" end
    end
    return table.concat(lines,"\n")
end
local pending=setmetatable({},{__mode="k"})
function R.Prepare(data)
    local report,err=R.Decode(data);if not report then return nil,err end
    local ticket={preview=R.Preview(report)};pending[ticket]=report;return ticket
end
function R.Cancel(ticket) if ticket then pending[ticket]=nil end end
local function recordData(r,refs)
    local out={kind=r.kind}
    for _,key in ipairs({"name","mapID","zone","subzone","x","y","precision","itemID","objectID","locale"}) do out[key]=r[key] end
    out.waterID=refs[r.waterID];out.poolID=refs[r.poolID];return out
end
local function sameIdentity(a,b)
    if a.kind~=b.kind then return false end
    if a.kind=="item" and a.itemID and a.itemID==b.itemID then return true end
    if a.kind=="pool" and a.objectID and a.objectID==b.objectID then return true end
    return encode(a)==encode(b)
end
local function factData(f)
    local out={};for _,key in ipairs({"origin","waterID","spotID","poolID","source","association","method","events","first","last","lowestSkill","lowestSkillAt","items"}) do out[key]=f[key] end
    return out
end
local function cumulative(old,new)
    for _,key in ipairs({"waterID","spotID","poolID","source","association","method","first"}) do if old[key]~=new[key] then return false end end
    if new.events<old.events or new.last<old.last then return false end
    for id,item in pairs(old.items) do
        local n=new.items[id]
        if not n or n.quantity<item.quantity or n.occurrences<item.occurrences or n.first~=item.first or n.last<item.last then return false end
    end
    if old.lowestSkill and (not new.lowestSkill or new.lowestSkill.effective>old.lowestSkill.effective) then return false end
    return true
end
-- Only a persisted exporter identity can assert the old store/ID aliases.
-- Similar catches and arbitrary legacy source/key pairs are never matched.
local function sameOrigin(incoming,stored)
    if incoming.source==stored.source and incoming.key==stored.key then return true end
    for _,key in ipairs(incoming.legacyKeys or {}) do if stored.key==key then return true end end
    for _,key in ipairs(stored.legacyKeys or {}) do if incoming.key==key then return true end end
    return false
end
function R.Accept(journal,ticket)
    if journal.readOnly or ns.InitializationBlocked then return nil,"Almanac is read-only." end
    local report=pending[ticket];if not report then return nil,"Preview this report before accepting it." end
    -- Stage all writes. A bad reference, conflicting origin or capacity limit
    -- cannot leave half an imported report in the character's journal.
    local staged=ns.CreateAnglingJournal(A.Copy(journal.db));local db=staged.db
    local refs={};local added,updated=0,0
    for _,kind in ipairs({"water","pool","item","spot"}) do for _,r in ipairs(report.records) do if r.kind==kind then
        local originKey=A.Key(r.origin.source,r.origin.key)
        local aliases={};local prior
        for key,claim in pairs(db.claims) do if sameOrigin(r.origin,claim.origin) then
            aliases[#aliases+1]=key
            if not prior or key==originKey then prior=claim end
        end end
        local e
        if kind=="spot" then
            e=prior and staged:Get(prior.recordID)
            if not e then
                e={id=staged:ID("reportedSpot"),kind="spot",name=r.name,note="",favourite=false,claims={},waterID=refs[r.waterID],poolID=refs[r.poolID],first=r.first,last=r.last}
                for _,k in ipairs({"mapID","zone","subzone","x","y","precision"}) do e[k]=r[k] end;db.spots[e.id]=e
            end
        else e=staged:Ensure(kind,r,nil,r.first) end
        if not e then return nil,"Unable to stage report identity." end
        refs[r.id]=e.id
        local old=prior
        if old and old.recordID~=e.id then return nil,"Conflicting original identity; nothing imported." end
        local record=recordData(r,refs)
        if old and old.record and not sameIdentity(old.record,record) then return nil,"Conflicting original position or identity; nothing imported." end
        for _,key in ipairs(aliases) do
            local claim=db.claims[key]
            if claim.record and not sameIdentity(claim.record,record) then return nil,"Conflicting legacy record identity; nothing imported." end
            if r.origin.legacyKeys and encode(claim.origin)~=encode(r.origin) then
                claim.originals=claim.originals or {}
                claim.originals[A.Key(claim.origin.source,claim.origin.key)]={origin=A.Copy(claim.origin),sender=claim.sender,received=claim.received,notes=claim.notes}
                claim.origin=A.Copy(r.origin)
            end
            if claim.recordID~=e.id then
                -- Keep the old annotated spot, but direct its reported facts to
                -- the proven common identity. Personal evidence is not touched.
                for _,fact in pairs(db.reported) do if fact.spotID==claim.recordID then fact.spotID=e.id end end
                claim.recordID=e.id
            end
        end
        if not old then
            e.claims[#e.claims+1]=originKey
            db.claims[originKey]={recordID=e.id,origin=A.Copy(r.origin),first=r.first,last=r.last,notes=r.notes,sender=report.sender,received=A.Now(),record=record}
        else
            db.claims[originKey]=old
            old.first=math.min(old.first,r.first);old.last=math.max(old.last,r.last)
            if r.last>=old.last then old.record=record;if r.notes~=nil then old.notes=r.notes end end
        end
        e.last=math.max(e.last,r.last)
    end end end
    for _,r in ipairs(report.facts) do
        local f={origin=A.Copy(r.origin),waterID=refs[r.waterID],spotID=refs[r.spotID],poolID=refs[r.poolID],source=r.source,
            association=r.association,method=r.origin.method,events=r.events,first=r.first,last=r.last,
            lowestSkill=A.Copy(r.lowestSkill),lowestSkillAt=r.lowestSkillAt,items={}}
        for _,v in ipairs(r.items) do local item=A.Copy(v);item.itemID=nil;f.items[refs[v.itemID]]=item end
        local key=A.Key(r.origin.source,r.origin.key);local old=db.reportOrigins[key]
        local matches={};local previous=old and db.reported[old.id]
        for id,fact in pairs(db.reported) do if sameOrigin(r.origin,fact.origin) then
            matches[#matches+1]=id
        end end
        if previous then
            local found=false;for _,id in ipairs(matches) do if id==previous.id then found=true end end
            if not found then matches[#matches+1]=previous.id end
        end
        table.sort(matches)
        previous=previous or db.reported[matches[1]]
        if previous then
            -- An old export can arrive through a retained alias after a repair.
            -- It must neither downgrade the canonical provenance nor replay an
            -- earlier cumulative total over a newer one.
            local canonical=A.Copy(r.origin.legacyKeys and r.origin or previous.origin)
            for _,alias in ipairs(previous.origin.legacyKeys or {}) do A.AddLegacyKey(canonical,alias) end
            f.origin=canonical
            local best=f
            for _,id in ipairs(matches) do
                local prior=db.reported[id]
                if not cumulative(prior,best) then
                    if cumulative(best,prior) then best=prior
                    else return nil,"Conflicting source or non-cumulative legacy results; nothing imported." end
                end
            end
            if #matches>1 or encode(factData(previous))~=encode(factData(best)) or encode(previous.origin)~=encode(canonical) then
                local merged=A.Copy(best);merged.id=previous.id;merged.origin=canonical
                merged.sender=report.sender;merged.received=previous.received or A.Now()
                merged.receipts=A.Copy(previous.receipts or {})
                for _,id in ipairs(matches) do
                    local prior=db.reported[id]
                    for receiptKey,receipt in pairs(prior.receipts or {}) do merged.receipts[receiptKey]=A.Copy(receipt) end
                    local receiptKey=A.Key(prior.origin.source,prior.origin.key,prior.sender,prior.received)
                    merged.receipts[receiptKey]={origin=A.Copy(prior.origin),sender=prior.sender,received=prior.received}
                    for alias,index in pairs(db.reportOrigins) do if index.id==id then index.id=previous.id end end
                    db.reportOrigins[A.Key(prior.origin.source,prior.origin.key)]={id=previous.id}
                    db.reported[id]=nil
                end
                db.reported[merged.id]=merged;updated=updated+1
            end
            db.reportOrigins[key]={id=previous.id}
        else
            f.id=staged:ID("reportedCatch");f.sender=report.sender;f.received=A.Now()
            db.reported[f.id]=f;db.reportOrigins[key]={id=f.id};added=added+1
        end
    end
    if A.Count(db.reported)>R.MAX_STORED_FACTS or A.Count(db.claims)>R.MAX_CLAIMS then return nil,"Reported-knowledge capacity reached; nothing imported." end
    for _,key in ipairs({"serial","waters","pools","items","spots","waterKeys","poolKeys","itemKeys","reported","claims","reportOrigins"}) do journal.db[key]=db[key] end
    pending[ticket]=nil;journal:Changed();return true,added,updated
end
