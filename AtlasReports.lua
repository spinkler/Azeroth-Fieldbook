local _, ns = ...
local A=ns.Atlas
local R={VERSION=1,MAX_BYTES=131072,MAX_RECORDS=200,MAX_EXPEDITIONS=40}
ns.AtlasReports=R
local encode
local function requireValue(ok,message) if not ok then error(message,0) end end
local function fields(t,allowed)
    requireValue(type(t)=="table" and not getmetatable(t),"Expected a plain table.")
    for k in pairs(t) do requireValue(allowed[k],"Unexpected report field.") end
end
local function text(v,max,empty) requireValue(A.Text(v,max,empty),"Invalid or oversized report text.");return v end
local function integer(v,lo,hi) requireValue(A.Integer(v,lo,hi),"Invalid report number.");return v end
local function array(v,max) requireValue(A.Array(v,max),"Invalid or oversized report list.");return v end
local function location(v)
    local out,err=A.Location(v);requireValue(out,err);return out
end
local function links(v,known)
    local out,seen={},{}
    for _,id in ipairs(array(v,100)) do
        text(id,64);requireValue(known[id] and not seen[id],"Invalid or duplicate report-local reference.")
        out[#out+1]=id;seen[id]=true
    end
    return out
end
local function references(v)
    local out={}
    for _,r in ipairs(array(v,100)) do
        fields(r,{section=true,key=true,name=true})
        out[#out+1]={section=text(r.section,40),key=text(r.key,160),name=text(r.name,160)}
    end
    return out
end
local function normalize(value)
    fields(value,{format=true,version=true,title=true,region=true,source=true,created=true,records=true,expeditions=true})
    requireValue(value.format=="AFB-ATLAS" and value.version==R.VERSION,"Unsupported Atlas report format/version.")
    fields(value.region,{kind=true,mapID=true,name=true})
    requireValue(value.region.kind=="zone" or value.region.kind=="selection","Invalid report region.")
    local region={kind=value.region.kind,name=text(value.region.name,160)}
    if value.region.mapID~=nil then region.mapID=integer(value.region.mapID,1,2147483647) end
    requireValue(region.kind~="zone" or region.mapID,"A zone region needs a map ID.")
    local out={format="AFB-ATLAS",version=R.VERSION,title=text(value.title,160),region=region,
        source=text(value.source,160),created=integer(value.created,0,9999999999),records={},expeditions={}}
    local known={}
    for _,r in ipairs(array(value.records,R.MAX_RECORDS)) do
        requireValue(type(r)=="table" and A.Text(r.id,64) and r.id:match("^r%d+$") and not known[r.id],"Invalid report-local identity.")
        known[r.id]=true
    end
    requireValue(#value.records>0,"Select at least one discovery.")
    for _,r in ipairs(value.records) do
        fields(r,{id=true,name=true,category=true,mapID=true,zone=true,subzone=true,x=true,y=true,knowledge=true,
            notes=true,access=true,interior=true,interiorMapID=true,related=true,references=true,stops=true})
        local e=location(r);e.id=r.id;e.name=text(r.name,160)
        requireValue(A.category[r.category],"Invalid place category.");e.category=r.category
        fields(r.knowledge,{kind=true,source=true})
        requireValue(r.knowledge.kind=="recorded" or r.knowledge.kind=="reported","Invalid knowledge provenance.")
        e.knowledge={kind=r.knowledge.kind,source=text(r.knowledge.source,160)}
        for _,key in ipairs({"notes","access","interior"}) do
            if r[key]~=nil then e[key]=text(r[key],key=="interior" and 160 or 8000,true) end
        end
        if r.interiorMapID~=nil then e.interiorMapID=integer(r.interiorMapID,1,2147483647) end
        e.related=links(r.related,known);e.references=references(r.references);e.stops={}
        for _,s in ipairs(array(r.stops,A.MAX_STOPS)) do
            requireValue(e.category=="route","Only routes may contain stops.")
            fields(s,{ref=true,name=true,mapID=true,zone=true,subzone=true,x=true,y=true,missing=true})
            local stop=location(s);stop.name=text(s.name,160)
            if s.ref~=nil then requireValue(known[s.ref],"Invalid route reference.");stop.ref=s.ref end
            if s.missing~=nil then requireValue(type(s.missing)=="boolean","Invalid missing flag.");stop.missing=s.missing end
            e.stops[#e.stops+1]=stop
        end
        out.records[#out.records+1]=e
    end
    local noteIDs={}
    for _,n in ipairs(array(value.expeditions,R.MAX_EXPEDITIONS)) do
        fields(n,{id=true,name=true,created=true,zones=true,notes=true,related=true,references=true})
        requireValue(A.Text(n.id,64) and n.id:match("^e%d+$") and not noteIDs[n.id],"Invalid expedition identity.")
        noteIDs[n.id]=true
        local e={id=n.id,name=text(n.name,160),created=integer(n.created,0,9999999999),notes=text(n.notes,8000,true),
            related=links(n.related,known),references=references(n.references),zones={}}
        for _,z in ipairs(array(n.zones,64)) do
            fields(z,{mapID=true,zone=true});local zone=location(z);zone.subzone=nil;e.zones[#e.zones+1]=zone
        end
        out.expeditions[#out.expeditions+1]=e
    end
    return out
end
function R.Normalize(value)
    local ok,result=pcall(normalize,value)
    if not ok then return nil,tostring(result) end
    if encode and #encode(result)+6>R.MAX_BYTES then return nil,"Report exceeds 128 KiB; select fewer records or notes." end
    return result
end
function R.Validate(value) local v,err=R.Normalize(value);return v~=nil,err end

-- A bounded, deterministic literal codec. The existing Bestiary wire format
-- has a fixed creature schema; reuse its length-prefix principle, not its
-- transport, points, inbox or compatibility rules. Nothing is evaluated.
encode=function(value)
    if type(value)=="string" then return "s"..#value..":"..value end
    if type(value)=="number" then local v=string.format("%.0f",value);return "n"..#v..":"..v end
    if type(value)=="boolean" then return value and "b1" or "b0" end
    local keys={};for k in pairs(value) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
    local chunks={"t"..#keys..":"}
    for _,k in ipairs(keys) do chunks[#chunks+1]=encode(k);chunks[#chunks+1]=encode(value[k]) end
    return table.concat(chunks)
end
function R.Encode(value)
    local out,err=R.Normalize(value);if not out then return nil,err end
    local encoded="AFBA1:"..encode(out)
    if #encoded>R.MAX_BYTES then return nil,"Report exceeds 128 KiB; select fewer records or notes." end
    return encoded
end
function R.Decode(data)
    if type(data)~="string" or #data>R.MAX_BYTES or data:sub(1,6)~="AFBA1:" then return nil,"Invalid, oversized or unsupported report envelope." end
    local function parse()
        local at,nodes=7,0
        local function length(max)
            local colon=data:find(":",at,true)
            requireValue(colon and colon-at<=7,"Malformed length prefix.")
            local raw=data:sub(at,colon-1);requireValue(raw:match("^%d+$"),"Invalid length.")
            local n=tonumber(raw);requireValue(n<=max,"Oversized field.");at=colon+1;return n
        end
        local function read(depth)
            nodes=nodes+1;requireValue(nodes<=30000 and depth<=12,"Report nesting or item limit exceeded.")
            local kind=data:sub(at,at);at=at+1
            if kind=="b" then
                local v=data:sub(at,at);at=at+1;requireValue(v=="0" or v=="1","Invalid boolean.");return v=="1"
            elseif kind=="s" or kind=="n" then
                local n=length(kind=="s" and 8000 or 16);requireValue(at+n-1<=#data,"Truncated field.")
                local v=data:sub(at,at+n-1);at=at+n
                if kind=="n" then requireValue(v:match("^%d+$"),"Invalid numeric literal.");return tonumber(v) end
                return v
            elseif kind=="t" then
                local n=length(500);local t={}
                for _=1,n do
                    local k=read(depth+1);requireValue(type(k)=="string" or type(k)=="number","Invalid key.")
                    requireValue(t[k]==nil,"Duplicate field.");t[k]=read(depth+1)
                end
                return t
            end
            error("Invalid literal type.",0)
        end
        local value=read(0);requireValue(at==#data+1,"Trailing report data.");return value
    end
    local ok,value=pcall(parse);if not ok then return nil,tostring(value) end
    return R.Normalize(value)
end
function R.Build(journal,selection,source)
    local d=selection or {};local ids={}
    for id,on in pairs(d.records or {}) do if on then ids[#ids+1]=id end end
    table.sort(ids)
    if #ids>R.MAX_RECORDS then return nil,"Select at most 200 discoveries." end
    local locals={};for i,id in ipairs(ids) do locals[id]="r"..i end
    local function related(values)
        local out={};for _,id in ipairs(values or {}) do if locals[id] then out[#out+1]=locals[id] end end;return out
    end
    local out={format="AFB-ATLAS",version=R.VERSION,title=d.title,region=A.Copy(d.region),source=source,
        created=A.Now(),records={},expeditions={}}
    for _,id in ipairs(ids) do
        local e=journal:Get(id);if not e then return nil,"A selected discovery is missing; remove it from the draft." end
        local r=A.Location(e);r.id=locals[id];r.name=e.name;r.category=e.category;r.knowledge=A.Copy(e.provenance)
        r.related=related(e.related);r.references=d.includeReferences and A.Copy(e.references) or {};r.stops={}
        if d.notes and d.notes[id]==true then r.notes=e.notes;r.access=e.access;r.interior=e.interior;r.interiorMapID=e.interiorMapID end
        if e.category=="route" then
            for _,s in ipairs(e.stops) do
                local p=journal:ResolveStop(s);local stop=A.Location(p)
                stop.name=A.Text(p.name,160) and p.name or s.name or "Missing place"
                stop.ref=locals[s.recordID];stop.missing=p.missing or nil
                r.stops[#r.stops+1]=stop
            end
        end
        out.records[#out.records+1]=r
    end
    local expIDs={};for id in pairs(d.expeditions or {}) do expIDs[#expIDs+1]=id end;table.sort(expIDs)
    for i,id in ipairs(expIDs) do
        local e=journal:Get(id,true);if not e then return nil,"A selected expedition is missing; remove it from the draft." end
        -- Only an explicitly supplied excerpt is included. Never implicitly
        -- substitute the expedition's full private text.
        out.expeditions[#out.expeditions+1]={id="e"..i,name=e.name,created=e.created,zones=A.Copy(e.zones),
            notes=d.expeditions[id],related=related(e.related),references=d.includeReferences and A.Copy(e.references) or {}}
    end
    local clean,err=R.Normalize(out);if not clean then return nil,err end
    local encoded,e=R.Encode(clean);if not encoded then return nil,e end
    return clean
end
function R.Preview(value)
    local r,err=R.Normalize(value);if not r then return nil,err end
    local function where(p) return (p.zone~="" and p.zone or "Unknown zone")..(p.mapID and " [map "..p.mapID.."]" or "")..(A.Position(p) and string.format(" (%.1f, %.1f)",p.x/100,p.y/100) or " — unpositioned") end
    local lines={r.title,"Region: "..r.region.name.." ("..r.region.kind..(r.region.mapID and ", map "..r.region.mapID or "")..")","Source attribution: "..r.source.." (not authenticated)",
        "Created: "..r.created,"Only the notes printed below are included. Routes include their recorded stop names and positions.",""}
    local function refs(e)
        for _,id in ipairs(e.related) do lines[#lines+1]="  Related in this report: "..id end
        for _,ref in ipairs(e.references) do lines[#lines+1]="  Reference: "..ref.section.." — "..ref.name end
    end
    for _,e in ipairs(r.records) do
        lines[#lines+1]=e.id.." • "..e.name.." ["..A.category[e.category].label.."]"
        lines[#lines+1]=where(e)..(e.subzone~="" and " / "..e.subzone or "")
        lines[#lines+1]="Knowledge: "..e.knowledge.kind.." — "..e.knowledge.source
        for i,s in ipairs(e.stops) do lines[#lines+1]=i..". "..s.name..(s.missing and " (missing reference)" or "").." — "..where(s)..(s.ref and " ["..s.ref.."]" or "") end
        for _,k in ipairs({"notes","access","interior"}) do if e[k]~=nil then lines[#lines+1]="Included "..k..": "..e[k] end end
        if e.interiorMapID then lines[#lines+1]="Interior map: "..e.interiorMapID end
        refs(e);lines[#lines+1]=""
    end
    for _,e in ipairs(r.expeditions) do
        lines[#lines+1]="Expedition: "..e.name.." ("..e.created..")"
        for _,z in ipairs(e.zones) do lines[#lines+1]="Zone: "..z.zone end
        lines[#lines+1]="Included excerpt: "..e.notes;refs(e);lines[#lines+1]=""
    end
    lines[#lines+1]="Recipient records must arrive as Reported and unexplored. Local journal IDs are not transferable."
    return table.concat(lines,"\n")
end
function R.StageReported(value)
    local r,err=R.Normalize(value);if not r then return nil,err end
    local staged={report=r,records={}}
    for _,e in ipairs(r.records) do
        local p=A.Location(e);p.name=e.name;p.category=e.category;p.notes=e.notes or "";p.access=e.access or ""
        p.interior=e.interior or "";p.interiorMapID=e.interiorMapID;p.explored=false
        p.provenance={kind="reported",source=r.source};p.reportKey=e.id
        p.originalKnowledge=A.Copy(e.knowledge);p.references=A.Copy(e.references)
        -- A future recipient must allocate fresh IDs, then reconcile these
        -- report-local links with explicit user consent. No database writes.
        p.reportRelated=A.Copy(e.related);p.reportStops=A.Copy(e.stops);staged.records[#staged.records+1]=p
    end
    return staged
end
