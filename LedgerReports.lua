local addonName, ns = ...
local L=ns.Ledger
local R={VERSION=1,MAX_BYTES=131072,MAX_OFFERINGS=80,MAX_STORED_REPORTS=512};ns.LedgerReports=R
local function version() return L.Read(C_AddOns and C_AddOns.GetAddOnMetadata,addonName,"Version") end
local function need(ok,msg) if not ok then error(msg,0) end end
local function fields(t,allowed)
    need(L.Public(t) and type(t)=="table" and not getmetatable(t),"Expected a plain table.")
    for k,v in pairs(t) do need(L.Public(k) and allowed[k] and L.Public(v),"Unexpected or unreadable report field.") end
end
local function text(v,max,empty) need(L.Text(v,max,empty) and (max>160 or not v:find('%c')),"Invalid plain text.");return v end
local function num(v,lo,hi) need(L.Integer(v,lo,hi),"Invalid report number.");return v end
local function array(v,max) need(L.Array(v,max),"Invalid or oversized list.");return v end
local function origin(v,created)
    fields(v,{source=true,key=true,method=true,at=true})
    need(v.method=="observed" or v.method=="recorded","Invalid fact provenance.")
    local key=text(v.key,700);need(not key:find('%c'),"Invalid original fact identifier.")
    return {source=text(v.source,160),key=key,method=v.method,at=num(v.at,0,created)}
end
local function dates(v,out,created)
    out.first=num(v.first,0,created);out.last=num(v.last,out.first,created);out.origin=origin(v.origin,created)
    need(out.origin.at==out.last,"Fact timestamp differs from original observation.")
end
local function facts(value,created,roles)
    need(type(value)=="table" and not getmetatable(value) and L.Count(value)<=32,"Invalid service facts.")
    local out={};for k,v in pairs(value) do text(k,160);if roles then need(L.roles[k],"Unknown service role.") end;out[k]=origin(v,created) end;return out
end
local function offering(v,created,training)
    local allowed={name=true,key=true,first=true,last=true,origin=true,price=true,priceAt=true,requirements=true}
    local extra=training and {rank=true,category=true,availability=true,requiredLevel=true,costUnit=true}
        or {itemID=true,currencyID=true,spellID=true,bundle=true,variant=true,recipe=true,profession=true,stock=true,stockAt=true,costs=true,costsAt=true,costsKnown=true,purchasable=true,usable=true}
    for k in pairs(extra) do allowed[k]=true end;fields(v,allowed)
    local out={name=text(v.name,160),key=text(v.key,700),requirements={}};dates(v,out,created)
    if v.price~=nil then out.price=num(v.price,0,1000000000000);out.priceAt=num(v.priceAt,out.first,out.last) else need(v.priceAt==nil,"Price time without a quote.") end
    for _,s in ipairs(array(v.requirements,16)) do out.requirements[#out.requirements+1]=text(s,160) end
    if training then
        out.rank=text(v.rank,160,true);out.category=text(v.category,160,true)
        need(({available=true,unavailable=true,used=true,unknown=true})[v.availability],"Invalid training state.");out.availability=v.availability
        need(v.costUnit=="copper" or v.costUnit=="training points" or v.costUnit=="unknown","Invalid training cost unit.");out.costUnit=v.costUnit
        if v.requiredLevel then out.requiredLevel=num(v.requiredLevel,1,255) end
        need(out.key==L.LessonKey(out),"Training key mismatch.")
    else
        local identities=0
        for _,k in ipairs({"itemID","currencyID","spellID"}) do if v[k] then out[k]=num(v[k],1,2147483647);identities=identities+1 end end
        need(identities==1,"An offering needs one stable identity.")
        if v.bundle then out.bundle=num(v.bundle,1,1000000) end
        out.variant=text(v.variant,700,true)
        for _,k in ipairs({"recipe","purchasable","usable","costsKnown"}) do if v[k]~=nil then need(type(v[k])=="boolean","Invalid offering flag.");out[k]=v[k] end end
        if v.profession then need(v.recipe==true,"Profession needs recipe evidence.");out.profession=text(v.profession,160) end
        fields(v.stock,{state=true,quantity=true});need(({finite=true,soldout=true,unlimited=true,unknown=true})[v.stock.state],"Invalid stock state.")
        out.stock={state=v.stock.state}
        out.stockAt=num(v.stockAt,out.first,out.last)
        if v.stock.state=="finite" then out.stock.quantity=num(v.stock.quantity,1,1000000000)
        elseif v.stock.state=="soldout" then out.stock.quantity=num(v.stock.quantity,0,0)
        else need(v.stock.quantity==nil,"Unknown or unrestricted stock has no numeric quantity.") end
        out.costs={}
        if v.costsAt then out.costsAt=num(v.costsAt,out.first,out.last) end
        for _,c in ipairs(array(v.costs,8)) do
            fields(c,{kind=true,id=true,quantity=true,name=true});need(c.kind=="item" or c.kind=="currency","Invalid additional cost.")
            local cost={kind=c.kind,id=num(c.id,1,2147483647),quantity=num(c.quantity,0,1000000000)}
            if c.name then cost.name=text(c.name,160) end;out.costs[#out.costs+1]=cost
        end
        need(out.key==L.GoodKey(out),"Offering key mismatch.")
    end
    return out
end
local function normalize(v)
    fields(v,{format=true,version=true,addonVersion=true,sender=true,created=true,identity=true,locations=true,roles=true,specialities=true,goods=true,lessons=true,notes=true,notesOrigin=true})
    need(v.format=="AFB-LEDGER" and v.version==R.VERSION,"Unsupported Ledger report schema.")
    need(version() and text(v.addonVersion,32)==version(),"Ledger reports require the same installed addon version.")
    local out={format=v.format,version=v.version,addonVersion=v.addonVersion,sender=text(v.sender,160),created=num(v.created,0,L.Now()),locations={},goods={},lessons={}}
    fields(v.identity,{name=true,sublabel=true,npcID=true,origin=true,sublabelOrigin=true})
    out.identity={name=text(v.identity.name,160),sublabel=text(v.identity.sublabel,160,true),origin=origin(v.identity.origin,out.created)}
    if v.identity.npcID then out.identity.npcID=num(v.identity.npcID,1,10000000) end
    if v.identity.sublabelOrigin then out.identity.sublabelOrigin=origin(v.identity.sublabelOrigin,out.created) end
    out.roles=facts(v.roles,out.created,true);out.specialities=facts(v.specialities,out.created)
    for _,p in ipairs(array(v.locations,L.MAX_SIGHTINGS)) do
        fields(p,{zone=true,subzone=true,mapID=true,x=true,y=true,precision=true,first=true,last=true,origin=true})
        local loc={zone=text(p.zone,160),subzone=text(p.subzone,160,true),precision=p.precision};dates(p,loc,out.created)
        need(p.precision=="unknown" or p.precision=="player" or p.precision=="npc","Invalid location source.")
        if p.mapID then loc.mapID=num(p.mapID,1,2147483647) end
        if p.x~=nil or p.y~=nil then
            need(loc.mapID and p.precision~="unknown","Coordinates need their original map and source.")
            loc.x=num(p.x,0,10000);loc.y=num(p.y,0,10000);need(loc.x~=0 or loc.y~=0,"Unknown location cannot use 0,0.")
        else need(p.precision=="unknown","Unpositioned observation needs unknown precision.") end
        out.locations[#out.locations+1]=loc
    end
    for _,kind in ipairs({"goods","lessons"}) do
        local seen={};for _,item in ipairs(array(v[kind],R.MAX_OFFERINGS)) do
            local o=offering(item,out.created,kind=="lessons");need(not seen[o.key],"Duplicate offering.");seen[o.key]=true;out[kind][#out[kind]+1]=o
        end
    end
    if v.notes~=nil then
        out.notes=text(v.notes,4000,true);out.notesOrigin=origin(v.notesOrigin,out.created)
        need(out.notesOrigin.method=="recorded","Notes require manual provenance.")
    else need(v.notesOrigin==nil,"Note provenance without a note.") end
    return out
end
function R.Normalize(v) local ok,value=pcall(normalize,v);if ok then return value end;return nil,tostring(value) end
function R.Validate(v) local value,err=R.Normalize(v);return value~=nil,err end
-- Same bounded literal/length-prefix convention as the existing section report
-- adapters. Bestiary's fixed creature wire schema has no section dispatch hook.
local function encode(v)
    if type(v)=="string" then return 's'..#v..':'..v end
    if type(v)=="number" then local s=string.format('%.0f',v);return 'n'..#s..':'..s end
    if type(v)=="boolean" then return v and 'b1' or 'b0' end
    local keys={};for k in pairs(v) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
    local out={'t'..#keys..':'};for _,k in ipairs(keys) do out[#out+1]=encode(k);out[#out+1]=encode(v[k]) end;return table.concat(out)
end
function R.Encode(v)
    local value,err=R.Normalize(v);if not value then return nil,err end
    local data='AFBL1:'..encode(value);if #data>R.MAX_BYTES then return nil,"Report exceeds 128 KiB; select fewer offerings." end;return data
end
function R.Decode(data)
    if not L.Public(data) or type(data)~="string" or #data>R.MAX_BYTES or data:sub(1,6)~='AFBL1:' then return nil,"Invalid Ledger envelope." end
    local function parse()
        local at,nodes=7,0
        local function length(max)
            local colon=data:find(':',at,true);need(colon and colon-at<=7,"Malformed length.")
            local raw=data:sub(at,colon-1);need(raw:match('^%d+$'),"Invalid length.")
            local n=tonumber(raw);need(n<=max,"Oversized field.");at=colon+1;return n
        end
        local function read(depth)
            nodes=nodes+1;need(nodes<=24000 and depth<=12,"Report nesting limit exceeded.")
            local kind=data:sub(at,at);at=at+1
            if kind=='b' then local v=data:sub(at,at);at=at+1;need(v=='0' or v=='1',"Invalid boolean.");return v=='1' end
            if kind=='s' or kind=='n' then
                local n=length(kind=='s' and 4000 or 16);need(at+n-1<=#data,"Truncated data.")
                local v=data:sub(at,at+n-1);at=at+n
                if kind=='n' then need(v:match('^%d+$'),"Invalid number.");return tonumber(v) end;return v
            end
            need(kind=='t',"Invalid literal type.");local n=length(200);local t={}
            for _=1,n do local k=read(depth+1);need(type(k)=='string' or type(k)=='number',"Invalid key.");need(t[k]==nil,"Duplicate field.");t[k]=read(depth+1) end;return t
        end
        local v=read(0);need(at==#data+1,"Trailing report data.");return v
    end
    local ok,v=pcall(parse);if not ok then return nil,tostring(v) end;return R.Normalize(v)
end
local function pick(t,keys) local out={};for _,k in ipairs(keys) do out[k]=L.Copy(t[k]) end;return out end
local function offeringCopy(v,training)
    local out=pick(v,{"name","key","first","last","origin","price","priceAt","requirements"});out.name=out.name or "Pending item metadata"
    local fields=training and {"rank","category","availability","requiredLevel","costUnit"}
        or {"itemID","currencyID","spellID","bundle","variant","recipe","profession","stock","stockAt","costs","costsAt","costsKnown","purchasable","usable"}
    for _,k in ipairs(fields) do out[k]=L.Copy(v[k]) end;return out
end
function R.Build(journal,id,options)
    local e=journal:Get(id);if not e then return nil,"Select a contact." end;options=options or {}
    if options.report then
        local report=e.reports[options.report];if not report then return nil,"Select an original report to forward." end
        local out=pick(report,{"format","version","addonVersion","sender","created","identity","locations","roles","specialities","goods","lessons","notes","notesOrigin"})
        out.sender=L.Player();out.addonVersion=version();if not options.notes then out.notes=nil;out.notesOrigin=nil end
        -- Original creation and every original fact timestamp/source survive forwarding.
        return R.Normalize(out)
    end
    if not e.identityOrigin then return nil,"This contact has reported knowledge only; choose a received report." end
    local out={format="AFB-LEDGER",version=R.VERSION,addonVersion=version(),sender=L.Player(),created=L.Now(),
        identity={name=e.name,sublabel=e.sublabelOrigin and e.sublabel or "",npcID=e.npcID,origin=L.Copy(e.identityOrigin),sublabelOrigin=L.Copy(e.sublabelOrigin)},
        roles=L.Copy(e.roles),specialities=L.Copy(e.specialities),locations={},goods={},lessons={}}
    for role,o in pairs(e.manualRoles) do if not out.roles[role] then out.roles[role]=L.Copy(o) end end
    if options.locations~=false then for _,p in ipairs(e.sightings) do out.locations[#out.locations+1]=pick(p,{"zone","subzone","mapID","x","y","precision","first","last","origin"}) end end
    for _,kind in ipairs({"goods","lessons"}) do if options[kind]~=false then
        local keys={};for key in pairs(e[kind]) do if not options.selection or options.selection[key] then keys[#keys+1]=key end end;table.sort(keys)
        if #keys>R.MAX_OFFERINGS then return nil,"Select at most 80 offerings per report using the current search, or exclude goods/training." end
        for _,key in ipairs(keys) do out[kind][#out[kind]+1]=offeringCopy(e[kind][key],kind=="lessons") end
    end end
    if options.notes and e.noteOrigin then out.notes=e.note;out.notesOrigin=L.Copy(e.noteOrigin) end
    return R.Normalize(out)
end
function R.Preview(value)
    local r,err=R.Normalize(value);if not r then return nil,err end
    local lines={"Contact report: "..r.identity.name,r.identity.sublabel,"Sender claim: "..r.sender.." (not authenticated)",
        "Original observer: "..r.identity.origin.source.." • "..L.Date(r.identity.origin.at),
        "Accept stores reported facts. Personal notes, observations and points stay unchanged.",""}
    for role,o in pairs(r.roles) do lines[#lines+1]=L.roles[role].." • "..o.source.." / "..o.method.." • "..L.Date(o.at) end
    for _,p in ipairs(r.locations) do lines[#lines+1]=L.PositionLabel(p).." • "..p.origin.source.." • "..L.Date(p.last) end
    for _,kind in ipairs({"goods","lessons"}) do
        lines[#lines+1]="\n"..(kind=="goods" and "Reported offerings" or "Reported training")
        for _,v in ipairs(r[kind]) do
            lines[#lines+1]=v.name..(kind=="goods" and " — last reported stock: "..L.StockLabel(v.stock) or " — "..v.availability.." when inspected")
            lines[#lines+1]="Quoted cost: "..(v.price and tostring(v.price) or "Unknown").." "..(v.costUnit or "copper")..
                (v.bundle and " per bundle of "..v.bundle or "").." • "..v.origin.source.." • quote "..L.Date(v.priceAt or v.last).." / observation "..L.Date(v.last)
            for _,cost in ipairs(v.costs or {}) do lines[#lines+1]="Additional quoted cost: "..cost.quantity.." × "..cost.kind.." #"..cost.id.." • "..L.Date(v.costsAt or v.last) end
            for _,requirement in ipairs(v.requirements) do lines[#lines+1]=requirement end
        end
    end
    if r.notes then lines[#lines+1]="\nIncluded reported note: "..r.notes.."\n"..r.notesOrigin.source.." / recorded • "..L.Date(r.notesOrigin.at) end
    return table.concat(lines,'\n')
end
local pending=setmetatable({},{__mode="k"})
function R.Prepare(data) local r,err=R.Decode(data);if not r then return nil,err end;local ticket={preview=R.Preview(r)};pending[ticket]=r;return ticket end
function R.Cancel(ticket) if ticket then pending[ticket]=nil end end
function R.MergeStored(existing,incoming)
    -- Shared by report acceptance and account identity repair. Work on copies;
    -- account repair additionally retains both complete original contacts.
    local r=L.Copy(incoming);local merged=L.Copy(existing)
    for _,kind in ipairs({"goods","lessons"}) do
        local keys={};for i,o in ipairs(merged[kind]) do keys[o.key]=i end
        for _,o in ipairs(r[kind]) do
            local i=keys[o.key]
            if i then if o.last>merged[kind][i].last then merged[kind][i]=o end
            elseif #merged[kind]<R.MAX_OFFERINGS then merged[kind][#merged[kind]+1]=o;keys[o.key]=#merged[kind]
            else return nil,"Reported offering limit reached; personal knowledge is unchanged." end
        end
    end
    for _,kind in ipairs({"roles","specialities"}) do
        for k,o in pairs(r[kind]) do if not merged[kind][k] or o.at>merged[kind][k].at then merged[kind][k]=o end end
        if L.Count(merged[kind])>32 then return nil,"Reported speciality limit reached." end
    end
    if r.identity.origin.at>merged.identity.origin.at then merged.identity=r.identity end
    if r.notes and (not merged.notesOrigin or r.notesOrigin.at>merged.notesOrigin.at) then merged.notes=r.notes;merged.notesOrigin=r.notesOrigin end
    local locs={};for _,p in ipairs(merged.locations) do locs[L.Key(p.origin.source,p.origin.key)]=p end
    for _,p in ipairs(r.locations) do local key=L.Key(p.origin.source,p.origin.key);if not locs[key] or p.last>locs[key].last then locs[key]=p end end
    merged.locations={};for _,p in pairs(locs) do merged.locations[#merged.locations+1]=p end
    table.sort(merged.locations,function(a,b) return a.last>b.last end);while #merged.locations>L.MAX_SIGHTINGS do table.remove(merged.locations) end
    merged.created=math.max(merged.created,r.created);merged.sender=r.sender
    if r.received then
        merged.received=math.min(existing.received or r.received,r.received)
        merged.lastReceived=math.max(existing.lastReceived or existing.received or 0,r.lastReceived or r.received)
        if (existing.lastReceived or existing.received or 0)>(r.lastReceived or r.received) then merged.sender=existing.sender end
        merged.factReceipts=merged.factReceipts or {}
        for key,receipt in pairs(r.factReceipts or {}) do
            local old=merged.factReceipts[key]
            if not old or receipt.observed>old.observed or (receipt.observed==old.observed and receipt.received<old.received) then
                merged.factReceipts[key]=L.Copy(receipt)
            end
        end
    end
    return merged
end
-- Compare evidence only: forwarding/receipt times do not make facts new.
local function evidence(value)
    local out={}
    for _,key in ipairs({"identity","roles","specialities","goods","lessons","notes","notesOrigin"}) do out[key]=value[key] end
    out.locations={}
    for _,p in ipairs(value.locations) do out.locations[L.Key(p.origin.source,p.origin.key)]=p end
    return encode(out)
end
function R.Accept(journal,ticket,selected,dryRun)
    local original=pending[ticket];if not original then return nil,"Preview this report first." end
    local r,err=R.Normalize(original);if not r then return nil,err end
    if journal.readOnly or ns.InitializationBlocked then return nil,"Ledger is read-only." end
    if selected then local contact=journal:Get(selected);selected=contact and contact.id or selected end
    local sourceKey=L.Key(r.identity.origin.source,r.identity.origin.key)
    local id=journal.db.reportKeys[sourceKey];local e=journal:Get(id or selected)
    if id and selected and id~=selected then return nil,"This original report already belongs to another contact." end
    if e and e.npcID and r.identity.npcID and e.npcID~=r.identity.npcID then return nil,"NPC template conflicts with selected contact." end
    local existing,index
    for i,old in ipairs(e and e.reports or {}) do if L.Key(old.identity.origin.source,old.identity.origin.key)==sourceKey then existing=old;index=i;break end end
    if not existing and e and #e.reports>=L.MAX_REPORTS then return nil,"Contact report-source limit reached." end
    if not existing and L.Count(journal.db.reportKeys)>=R.MAX_STORED_REPORTS then return nil,"Character report-source limit reached." end
    local newContact=not e
    if not e then
        local available;available,err=journal:New(r.identity.name,true);if not available then return nil,err end
    end
    if existing then
        -- Same-source cumulative updates cannot delete earlier positive facts.
        local merged,mergeError=R.MergeStored(existing,r);if not merged then return nil,mergeError end
        -- Compare factual payload before receipt fields; forwards do not refresh old observations.
        r=merged;r.received=existing.received
    else r.received=L.Now() end
    local changed=existing and evidence(existing)~=evidence(r) or false
    local delta={newContact=newContact,newSource=not existing,
        updatedSource=changed,knownSource=existing~=nil and not changed}
    if dryRun then return true,nil,delta end
    if not e then e,err=journal:New(r.identity.name);if not e then return nil,err end end
    -- A bounded receipt per fact version, distinct from observation and forwarding time.
    local receipts={}
    local function received(o)
        local key=L.Key(o.source,o.key);local old=existing and existing.factReceipts and existing.factReceipts[key]
        receipts[key]=old and old.observed==o.at and L.Copy(old) or {observed=o.at,received=L.Now()}
    end
    received(r.identity.origin);if r.identity.sublabelOrigin then received(r.identity.sublabelOrigin) end
    if r.notesOrigin then received(r.notesOrigin) end
    for _,kind in ipairs({"roles","specialities"}) do for _,o in pairs(r[kind]) do received(o) end end
    for _,kind in ipairs({"goods","lessons","locations"}) do for _,v in ipairs(r[kind]) do received(v.origin) end end
    r.factReceipts=receipts;r.lastReceived=L.Now();e.reports[index or #e.reports+1]=r;journal.db.reportKeys[sourceKey]=e.id
    if not e.personal and not e.recorded then e.name=r.identity.name;e.sublabel=r.identity.sublabel;e.npcID=r.identity.npcID end
    pending[ticket]=nil;journal:Changed(e.id);return e,nil,delta
end

function R.Preflight(journal,ticket,selected)
    local result,err,delta=R.Accept(journal,ticket,selected,true)
    if not result then return "Cannot accept now: "..err,false end
    local summary=delta.newContact and "Would add 1 contact with 1 report source."
        or delta.newSource and "Would add 1 report source to an existing contact."
        or delta.updatedSource and "Would update an existing contact's reported evidence."
        or "Reported evidence already known; only delivery details would update."
    return "Against this journal now: "..summary,true,delta
end
