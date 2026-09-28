local addonName, ns = ...
local T=ns.Treasure
-- Data-only adapter for a future authorized shared dispatcher. There is no
-- Treasure wire protocol, copy/export UI, networking or separate points path.
local R={SCHEMA=1,MAX_BYTES=65536,MAX_ENCOUNTERS=50};ns.TreasureReports=R
local function version() return T.Read(C_AddOns and C_AddOns.GetAddOnMetadata,addonName,"Version") end
local function need(ok,message) if not ok then error(message,0) end end
local function fields(v,allowed)
    need(T.Public(v) and type(v)=="table" and not getmetatable(v),"Expected a plain table.")
    for k in pairs(v) do need(T.Public(k) and allowed[k],"Unexpected report field.") end
end
local function bounded(v,seen,depth,budget)
    need(T.Public(v),"Unreadable report value.")
    local kind=type(v);budget.nodes=budget.nodes+1;need(budget.nodes<=20000 and depth<=10,"Report nesting/size limit exceeded.")
    if kind=="table" then
        need(not getmetatable(v) and not seen[v],"Report cycles/metatables are invalid.");seen[v]=true
        for k,x in pairs(v) do bounded(k,seen,depth+1,budget);bounded(x,seen,depth+1,budget) end
        seen[v]=nil
    elseif kind=="string" then budget.bytes=budget.bytes+#v;need(#v<=4000,"Oversized report text.")
    else need(kind=="number" or kind=="boolean","Invalid report value.");budget.bytes=budget.bytes+16 end
    need(budget.bytes<=R.MAX_BYTES,"Report exceeds 64 KiB.")
end
local function origin(v,created)
    fields(v,{source=true,key=true,method=true,at=true})
    need(T.Name(v.source) and T.Text(v.key,200) and not v.key:find('%c'),"Invalid origin identity.")
    need(v.method=="manual" or v.method=="observed","Invalid origin method.")
    need(v.at==nil or T.Integer(v.at,0,created),"Invalid original observation time.")
    return T.Copy(v)
end
local function normalize(v)
    bounded(v,{},0,{bytes=0,nodes=0})
    fields(v,{format=true,schema=true,addonVersion=true,created=true,identity=true,encounters=true,note=true})
    need(v.format=="AFB-TREASURE" and v.schema==R.SCHEMA,"Unsupported Treasure report schema.")
    need(T.Text(v.addonVersion,32) and version() and v.addonVersion==version(),"Reports require the same installed addon version.")
    need(T.Integer(v.created,0,T.Now()),"Invalid report creation time.")
    fields(v.identity,{name=true,form=true,category=true,itemID=true,source=true,key=true})
    local e,err=T.Kind(v.identity);need(e~=nil,err)
    need(T.Name(v.identity.source) and T.Text(v.identity.key,160),"Invalid container origin.")
    local out={format=v.format,schema=v.schema,addonVersion=v.addonVersion,created=v.created,identity=T.Copy(v.identity),encounters={}}
    need(T.Array(v.encounters,R.MAX_ENCOUNTERS) and #v.encounters>0,"Choose 1–50 encounters.")
    local seen={}
    for _,entry in ipairs(v.encounters) do
        fields(entry,{origin=true,context=true,location=true,facts=true,capture=true,items=true,access=true,accessMethod=true,note=true,result=true})
        fields(entry.location,{zone=true,subzone=true,floor=true,instance=true,mapID=true,x=true,y=true,precision=true,method=true,meaning=true})
        fields(entry.facts,{sighted=true,attempted=true,inspected=true})
        need(T.Array(entry.items,T.MAX_ITEMS),"Oversized contents list.")
        for _,item in ipairs(entry.items) do fields(item,{itemID=true,name=true,quantity=true,recovered=true}) end
        local row,why=T.Encounter(entry,e.form);need(row~=nil,why)
        need(entry.location.meaning==entry.context,"Location meaning conflicts with encounter context.")
        need(entry.location.precision==row.location.precision,"Invalid position precision.")
        row.origin=origin(entry.origin,v.created)
        local key=T.Key(row.origin.source,row.origin.key);need(not seen[key],"Duplicate original encounter.");seen[key]=true
        out.encounters[#out.encounters+1]=row
    end
    if v.note~=nil then need(T.Text(v.note,4000,true),"Invalid included note.");out.note=v.note end
    return out
end
function R.Normalize(v) local ok,out=pcall(normalize,v);if ok then return out end;return nil,tostring(out) end
function R.Validate(v) local out,err=R.Normalize(v);return out~=nil,err end
local function observation(v,options)
    local out={};for _,k in ipairs({"origin","context","location","facts","capture","items","access","accessMethod","result"}) do out[k]=T.Copy(v[k]) end
    out.note=options.notes==true and v.note or ""
    if options.locations==false then out.location=assert(T.Location({},v.context)) end
    if options.contents==false then out.items={};out.capture="missing" end
    if options.access==false then out.access="" end
    return out
end
function R.Build(journal,id,options)
    options=options or {};local e=journal:Get(id);if not e then return nil,"Choose a known kind." end
    local out={format="AFB-TREASURE",schema=R.SCHEMA,addonVersion=version(),created=T.Now(),
        identity={name=e.name,form=e.form,category=e.category,itemID=e.itemID,source=T.Player(),key=e.reference},encounters={}}
    for _,v in ipairs(journal:History(id)) do if not v.reported and (not options.selection or options.selection[v.id]) then
        out.encounters[#out.encounters+1]=observation(v,options)
    end end
    if options.notes==true then out.note=e.note end
    return R.Normalize(out)
end
function R.Forward(journal,encounterID,options)
    options=options or {};local v=journal.encounters[encounterID]
    if not v or not v.reported or not v.reportIdentity then return nil,"Choose an original reported encounter." end
    local out={format="AFB-TREASURE",schema=R.SCHEMA,addonVersion=version(),created=T.Now(),identity=T.Copy(v.reportIdentity),encounters={}}
    for _,row in ipairs(journal:History(v.kindID)) do
        if row.reported and row.reportIdentity.source==v.reportIdentity.source and row.reportIdentity.key==v.reportIdentity.key
            and (not options.selection or options.selection[row.id]) then out.encounters[#out.encounters+1]=observation(row,options) end
    end
    if options.notes==true then out.note=v.reportNote end
    return R.Normalize(out)
end
function R.Preview(v)
    local r,err=R.Normalize(v);if not r then return nil,err end
    local lines={"Historical container report: "..r.identity.name,"Source claim: "..r.identity.source.." (not authenticated)",
        "Past finds — current availability unknown. Acceptance records reported evidence only."}
    for _,row in ipairs(r.encounters) do
        lines[#lines+1]="\n"..T.Date(row.origin.at).." • "..row.origin.source.." / "..row.origin.method
        lines[#lines+1]=T.Outcome(row);lines[#lines+1]=T.LocationText(row.location);lines[#lines+1]=T.captures[row.capture]
        for _,item in ipairs(row.items) do lines[#lines+1]=(item.name or "Item #"..item.itemID).." × "..item.quantity..(item.recovered and " • source reports recovering "..item.recovered or " • receipt unconfirmed") end
        if row.access~="" then lines[#lines+1]="Access ("..row.accessMethod.."): "..row.access end
        if row.note~="" then lines[#lines+1]="Included note: "..row.note end
    end
    if r.note and r.note~="" then lines[#lines+1]="Included kind note: "..r.note end
    return table.concat(lines,"\n")
end
local pending=setmetatable({},{__mode="k"})
function R.Prepare(value)
    local r,err=R.Normalize(value);if not r then return nil,err end
    local ticket={preview=R.Preview(r)};pending[ticket]=r;return ticket
end
function R.Cancel(ticket) if ticket then pending[ticket]=nil end end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function enrich(old,incoming)
    local out=T.Copy(old)
    if not same(old.origin,incoming.origin) or old.context~=incoming.context then return nil end
    local a,b=old.location,incoming.location
    local hasA=a.mapID~=nil or a.zone~="" or a.subzone~="" or a.floor~="" or a.instance~=""
    local hasB=b.mapID~=nil or b.zone~="" or b.subzone~="" or b.floor~="" or b.instance~=""
    if hasA and hasB then
        for _,key in ipairs({"mapID","zone","subzone","floor","instance","x","y"}) do
            local av,bv=a[key],b[key]
            if av~=nil and av~="" and bv~=nil and bv~="" and av~=bv then return nil end
            if (av==nil or av=="") and bv~=nil then out.location[key]=bv end
        end
        if a.x and b.x and a.precision~=b.precision then return nil end
        if not a.x and b.x then out.location.precision=b.precision;out.location.method=b.method end
    elseif hasB then out.location=T.Copy(b) end
    for _,key in ipairs({"access","note","result"}) do
        if old[key]~="" and incoming[key]~="" and old[key]~=incoming[key] then return nil end
        if incoming[key]~="" then out[key]=incoming[key];if key=="access" then out.accessMethod=incoming.accessMethod end end
    end
    for key,value in pairs(incoming.facts) do if value then out.facts[key]=true end end
    local byKey={};local function itemKey(item) return item.itemID and "item:"..item.itemID or "name:"..item.name end
    for _,item in ipairs(out.items) do byKey[itemKey(item)]=item end
    local incomingKeys={}
    for _,item in ipairs(incoming.items) do
        local key=itemKey(item);incomingKeys[key]=true;local previous=byKey[key]
        if previous then
            if previous.quantity~=item.quantity or (previous.recovered and item.recovered and previous.recovered~=item.recovered) then return nil end
            if item.recovered then previous.recovered=item.recovered end
            if not previous.name then previous.name=item.name end
        else
            if old.capture=="full" or #out.items>=T.MAX_ITEMS then return nil end
            out.items[#out.items+1]=T.Copy(item)
        end
    end
    if incoming.capture=="full" then for key in pairs(byKey) do if not incomingKeys[key] then return nil end end end
    local rank={missing=0,partial=1,full=2};if rank[incoming.capture]>rank[out.capture] then out.capture=incoming.capture end
    return out
end
function R.Accept(journal,ticket,selected)
    if journal.readOnly then return nil,"Saved schema is read-only." end
    local r,err=R.Normalize(pending[ticket]);if not r then return nil,err or "Preview this report first." end
    local e=selected and journal:Get(selected);if selected and not e then return nil,"Selected kind is unavailable." end
    local identityKey=T.Key(r.identity.source,r.identity.key);local originals={}
    for _,old in pairs(journal.encounters) do
        originals[T.Key(old.origin.source,old.origin.key)]=old
        if old.reported and old.reportIdentity and T.Key(old.reportIdentity.source,old.reportIdentity.key)==identityKey then
            if e and e.id~=old.kindID then return nil,"This origin already belongs to another kind." end
            e=journal:Get(old.kindID)
        end
    end
    if not e and r.identity.itemID then e=journal:FindItem(r.identity.itemID) end
    if e and (e.form~=r.identity.form or (e.itemID~=r.identity.itemID and (e.itemID or r.identity.itemID))) then return nil,"Container identity conflicts with the selected kind." end
    local additions,updates={},{}
    for _,row in ipairs(r.encounters) do
        local old=originals[T.Key(row.origin.source,row.origin.key)]
        if old then
            if e and old.kindID~=e.id then return nil,"Original encounter belongs to another kind." end
            -- Omitted/private fields never delete an earlier accepted fact.
            local a=observation(old,{notes=true});local b=observation(row,{notes=true});local merged=enrich(a,b)
            if not merged then return nil,"Contradictory data for an existing original encounter; no evidence changed." end
            if old.reportNote and r.note and old.reportNote~=r.note then return nil,"Conflicting original kind notes; no evidence changed." end
            if old.reported and (not same(a,merged) or (not old.reportNote and r.note)) then
                local updated=T.Copy(old)
                for k,value in pairs(merged) do updated[k]=value end
                updated.reportNote=old.reportNote or r.note;updated.enrichedAt=T.Now();updates[#updates+1]=updated
            end
            e=journal:Get(old.kindID)
        else additions[#additions+1]=row end
    end
    if e and (e.form~=r.identity.form or (e.itemID~=r.identity.itemID and (e.itemID or r.identity.itemID))) then return nil,"Original encounter identity conflicts with the report kind." end
    if T.Count(journal.db.encounters)+#additions>T.MAX_ENCOUNTERS then return nil,"Encounter limit reached; import left unchanged." end
    if not e then e,err=journal:NewKind(r.identity);if not e then return nil,err end end
    for _,row in ipairs(additions) do
        row=T.Copy(row);row.id=journal:Next("enc:");row.kindID=e.id;row.reported=true;row.received=T.Now()
        row.reportIdentity=T.Copy(r.identity);row.reportNote=r.note
        journal.encounters[row.id]=row;journal.db.encounters[row.id]=row
    end
    for _,row in ipairs(updates) do journal.encounters[row.id]=row;journal.db.encounters[row.id]=row end
    pending[ticket]=nil
    if #additions>0 or #updates>0 then journal:Changed(e.id) end
    return e,#additions
end
