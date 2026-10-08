local addonName, ns = ...
local L=ns.Lore
local R={VERSION=2,MAX_BYTES=1048576,MAX_REPORTS=L.MAX_REPORTS};ns.LoreReports=R
local kinds={writing=true,landmark=true,person=true,mystery=true}
local origins={captured=true,manual=true,reported=true}
local natures={source=true,translation=true,observation=true,account=true,interpretation=true,annotation=true,paraphrase=true,rumour=true,theory=true}
local methods={displayed=true,automatic=true,manual=true,gossip=true,quest=true,dialogue=true,reported=true,observed=true}
local meanings={['read-here']=true,['found-here']=true,landmark=true,observation=true,encounter=true,reported=true,mentioned=true}
local function need(ok,msg) if not ok then error(msg,0) end end
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function fields(v,allowed)
    need(public(v) and type(v)=='table' and not getmetatable(v),'Expected a plain report table.')
    local count=0
    for k,x in pairs(v) do count=count+1;need(count<=512 and public(k) and public(x) and allowed[k],'Unexpected report field.') end
end
local function str(v,max,empty)
    need(public(v) and type(v)=='string' and #v<=max and (empty or #v>0) and not v:find('%z'),'Invalid or oversized report text.')
    return v
end
local function int(v,lo,hi)
    need(public(v) and type(v)=='number' and v==v and v==math.floor(v) and v>=lo and v<=hi,'Invalid report number.');return v
end
local function flag(v) need(type(v)=='boolean','Invalid report flag.');return v end
local function list(v,max)
    need(public(v) and type(v)=='table' and not getmetatable(v),'Expected a report list.')
    need(L.Array(v,max),'Invalid, sparse or oversized report list.')
    return v
end
local function version()
    return L.Read(C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata,addonName,'Version')
end
-- Same syntax policy as the live Sharing transport; equality remains exact.
local function validVersion(value)
    if type(value)~="string" or #value>32 then return false end
    local tail=value:match("^%d+%.%d+%.%d+(.*)$")
    if tail==nil then return false end
    if tail=="" then return true end
    local pre,build=tail:match("^%-([^+]+)%+(.+)$")
    if not pre then pre=tail:match("^%-(.+)$") end
    if not pre then build=tail:match("^%+(.+)$") end
    local function identifiers(s)
        return s and s:match("^[%w%-%.]+$") and not s:find("..",1,true)
            and s:sub(1,1)~="." and s:sub(-1)~="."
    end
    return (pre~=nil or build~=nil) and (not pre or identifiers(pre)) and (not build or identifiers(build))
end
local player=L.Player
local function selected(values,index) return values==nil or values[index]==true end
local encode
local function normalize(v,stored)
    fields(v,{format=true,version=true,addonVersion=true,sender=true,created=true,sourceKey=true,kind=true,title=true,sourceTitle=true,subtype=true,
        pages=true,passages=true,locations=true,annotations=true,references=true,originalSource=true})
    need(v.format=='AFB-LORE' and (v.version==R.VERSION or v.version==1),'Unsupported Lore report schema.')
    local installed=str(v.addonVersion,32)
    need(validVersion(installed) and (stored or version() and installed==version()),'Lore reports require the same installed addon version.')
    need(kinds[v.kind],'Invalid entry kind.')
    local out={format=v.format,version=R.VERSION,addonVersion=v.addonVersion,sender=str(v.sender,160),created=int(v.created,0,9999999999),
        sourceKey=str(v.sourceKey,400),kind=v.kind,title=str(v.title,200),sourceTitle=str(v.sourceTitle or '',200,true),subtype=str(v.subtype or '',80,true),
        pages={},passages={},locations={},annotations={},references={},originalSource=str(v.originalSource or v.sender,160)}
    for _,p in ipairs(list(v.pages,256)) do
        fields(p,{number=true,raw=true,method=true,origin=true,nature=true,source=true,at=true,first=true,last=true})
        need(methods[p.method] and origins[p.origin] and p.nature=='source','Invalid page provenance.')
        local page={raw=str(p.raw,131072,true),method=p.method,origin=p.origin,nature='source',source=str(p.source,240),at=int(p.at,0,9999999999)}
        if p.number~=nil then page.number=int(p.number,0,100000) end
        for _,k in ipairs({'first','last'}) do if p[k]~=nil then page[k]=flag(p[k]) end end
        out.pages[#out.pages+1]=page
    end
    for _,p in ipairs(list(v.passages,256)) do
        fields(p,{raw=true,method=true,origin=true,nature=true,source=true,at=true,title=true,private=true,speaker=true,sourceTitle=true,translation=v.version==R.VERSION})
        need(methods[p.method] and origins[p.origin] and natures[p.nature],'Invalid passage provenance.')
        need(v.version==R.VERSION or p.nature~='translation','Translations require Lore report schema 2.')
        local private=p.private;if private==nil then private=not ({source=true,account=true,translation=true})[p.nature] end
        local passage={raw=str(p.raw,131072,true),method=p.method,origin=p.origin,nature=p.nature,
            source=str(p.source,240),at=int(p.at,0,9999999999),title=str(p.title or '',240,true),
            private=flag(private),
            speaker=str(p.speaker or '',200,true),sourceTitle=str(p.sourceTitle or '',200,true)}
        if p.nature=='translation' then
            local t,err=L.Translation(p.translation);need(t,err);passage.translation=t
            need(L.Passage(p),'Invalid translation text.')
        else need(p.translation==nil,'Translation details require a translation passage.') end
        out.passages[#out.passages+1]=passage
    end
    for _,p in ipairs(list(v.locations,128)) do
        fields(p,{meaning=true,zone=true,subzone=true,mapID=true,x=true,y=true,label=true,source=true,at=true})
        need(meanings[p.meaning],'Invalid location meaning.')
        local loc={meaning=p.meaning,zone=str(p.zone or '',160,true),subzone=str(p.subzone or '',160,true),label=str(p.label or '',240,true),
            source=str(p.source or out.originalSource,240),at=int(p.at or out.created,0,9999999999)}
        if p.mapID~=nil then loc.mapID=int(p.mapID,1,2147483647) end
        if p.x~=nil or p.y~=nil then
            need(loc.mapID and p.meaning~='mentioned','Coordinates require an established map location.')
            loc.x=int(p.x,0,10000);loc.y=int(p.y,0,10000)
        end
        out.locations[#out.locations+1]=loc
    end
    fields(v.annotations,{description=true,notes=true,theory=true,nextStep=true,tags=true,status=true})
    for _,k in ipairs({'description','notes','theory','nextStep'}) do if v.annotations[k]~=nil then out.annotations[k]=str(v.annotations[k],k=='notes' and 32000 or 16000,true) end end
    if v.annotations.status~=nil then
        need(v.kind=='mystery' and ({open=true,investigating=true,resolved=true})[v.annotations.status],'Invalid personal conclusion.')
        out.annotations.status=v.annotations.status
    end
    if v.annotations.tags~=nil then out.annotations.tags={};for _,tag in ipairs(list(v.annotations.tags,32)) do out.annotations.tags[#out.annotations.tags+1]=str(tag,80) end end
    for _,ref in ipairs(list(v.references,128)) do
        fields(ref,{section=true,label=true,explanation=true})
        need(({lore=true,bestiary=true,gathering=true,atlas=true,angling=true,merchants=true,treasure=true})[ref.section],'Invalid related section.')
        out.references[#out.references+1]={section=ref.section,label=str(ref.label,240),explanation=str(ref.explanation or '',1000,true)}
    end
    return out
end
-- The existing section-report length-prefix convention; no evaluation,
-- compression, network transport, rewards or parallel inbox is introduced.
encode=function(v)
    if type(v)=='string' then return 's'..#v..':'..v end
    if type(v)=='number' then local s=string.format('%.0f',v);return 'n'..#s..':'..s end
    if type(v)=='boolean' then return v and 'b1' or 'b0' end
    local keys={};for k in pairs(v) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end;return type(a)<type(b) end)
    local out={'t'..#keys..':'};for _,k in ipairs(keys) do out[#out+1]=encode(k);out[#out+1]=encode(v[k]) end;return table.concat(out)
end
function R.Normalize(v,stored)
    local ok,out=pcall(normalize,v,stored);if not ok then return nil,tostring(out) end
    if #encode(out)+7>R.MAX_BYTES then return nil,'Report exceeds 1 MiB. Select fewer pages; no text was truncated.' end
    return out
end
-- Only validated evidence belongs in this key. Delivery claims and installed
-- addon versions do not revise a work; source identities and all selected
-- content/provenance (including observation times) still do.
function R.EvidenceKey(report)
    local evidence={}
    for k,v in pairs(report) do
        if k~='sender' and k~='created' and k~='addonVersion' and k~='received'
            and k~='receivedFrom' and k~='latestReceipt' then evidence[k]=v end
    end
    return encode(evidence)
end
local function receipt(v)
    fields(v,{sender=true,created=true,received=true,receivedFrom=true})
    local out={sender=str(v.sender,160),created=int(v.created,0,9999999999),received=int(v.received,0,9999999999)}
    if v.receivedFrom~=nil then
        need(L.Text(v.receivedFrom,160,true),'Invalid recorded sender.');out.receivedFrom=v.receivedFrom
    end
    return out
end
function R.NormalizeStored(report)
    -- Shallow projection deliberately leaves nested lists untouched until they
    -- have passed strict validation (including malformed nonnumeric keys).
    if not public(report) or type(report)~='table' or getmetatable(report) then return nil,'Invalid report snapshot.' end
    local copy={}
    for k,v in pairs(report) do if k~='received' and k~='receivedFrom' and k~='latestReceipt' then copy[k]=v end end
    local out,err=R.Normalize(copy,true);if not out then return nil,err end
    local ok,first=pcall(receipt,{sender=out.sender,created=out.created,received=report.received,receivedFrom=report.receivedFrom})
    if not ok then return nil,tostring(first) end
    out.received=first.received;out.receivedFrom=first.receivedFrom
    if report.latestReceipt~=nil then
        local valid,latest=pcall(receipt,report.latestReceipt);if not valid then return nil,tostring(latest) end
        out.latestReceipt=latest
    end
    return out
end
function R.Validate(v) local r,err=R.Normalize(v);return r~=nil,err end
function R.Encode(v) local r,err=R.Normalize(v);if not r then return nil,err end;return 'AFBLR1:'..encode(r) end
function R.Decode(data)
    if not public(data) or type(data)~='string' or #data>R.MAX_BYTES or data:sub(1,7)~='AFBLR1:' then return nil,'Invalid, oversized or unsupported Lore envelope.' end
    local function parse()
        local at,nodes=8,0
        local function length(max)
            local colon=data:find(':',at,true);need(colon and colon-at<=7,'Malformed length.')
            local raw=data:sub(at,colon-1);need(raw:match('^%d+$'),'Invalid length.')
            local n=tonumber(raw);need(n<=max,'Oversized field.');at=colon+1;return n
        end
        local function read(depth)
            nodes=nodes+1;need(nodes<=30000 and depth<=10,'Report nesting or node limit exceeded.')
            local kind=data:sub(at,at);at=at+1
            if kind=='b' then local b=data:sub(at,at);at=at+1;need(b=='0' or b=='1','Invalid boolean.');return b=='1' end
            if kind=='s' or kind=='n' then
                local n=length(kind=='s' and 131072 or 16);need(at+n-1<=#data,'Truncated report.')
                local value=data:sub(at,at+n-1);at=at+n
                if kind=='n' then need(value:match('^%d+$'),'Invalid number.');return tonumber(value) end;return value
            end
            need(kind=='t','Invalid literal type.');local n=length(512);local t={}
            for _=1,n do
                local key=read(depth+1);need(type(key)=='string' or type(key)=='number','Invalid report key.')
                need(t[key]==nil,'Duplicate report key.');t[key]=read(depth+1)
            end;return t
        end
        local value=read(0);need(at==#data+1,'Trailing report content.');return value
    end
    local ok,value=pcall(parse);if not ok then return nil,tostring(value) end;return R.Normalize(value)
end
local function pageCopy(p,originalSource)
    return {number=p.number,raw=p.raw,method=methods[p.method] and p.method or 'manual',origin=origins[p.origin] and p.origin or 'manual',
        nature='source',source=type(p.source)=='string' and p.source~='' and p.source or originalSource,at=p.at or L.Now(),first=p.first,last=p.last}
end
function R.Build(journal,id,options)
    local e=journal:Get(id);if not e then return nil,'Select an entry.' end;options=options or {}
    local base=options.report and e.reports and e.reports[options.report]
    if options.report and not base then return nil,'Select an existing received report.' end
    local out={format='AFB-LORE',version=R.VERSION,addonVersion=version(),sender=player(),created=L.Now(),
        sourceKey=base and base.sourceKey or e.exportKey or (tostring(journal.db.exportOrigin or journal.db.archiveID or player())..':'..tostring(e.id)..':'..tostring(e.created)),
        originalSource=base and base.originalSource or e.exportSource or player(),kind=e.kind,title=base and base.title or journal:Title(e),sourceTitle=base and base.sourceTitle or e.sourceTitle or '',
        subtype=base and base.subtype or e.subtype or '',pages={},passages={},locations={},annotations={},references={}}
    local pages={}
    for key,p in pairs(base and base.pages or e.pages or {}) do pages[#pages+1]={key=key,page=p} end
    table.sort(pages,function(a,b) return (a.page.number or 100001)<(b.page.number or 100001) or a.page.number==b.page.number and tostring(a.key)<tostring(b.key) end)
    if options.includePages~=false then for _,v in ipairs(pages) do if selected(options.pages,v.key) then out.pages[#out.pages+1]=pageCopy(v.page,out.originalSource) end end end
    if options.includePassages~=false then for i,p in ipairs(base and base.passages or e.passages or {}) do
        if selected(options.passages,i) and (not p.private or options.interpretations==true)
            and (({source=true,translation=true,observation=true,account=true})[p.nature] or options.interpretations==true) then
            local copy=pageCopy(p,out.originalSource);copy.number=nil;copy.first=nil;copy.last=nil;copy.nature=natures[p.nature] and p.nature or 'source';copy.title=p.title or ''
            copy.private=p.private==true;copy.speaker=p.speaker;copy.sourceTitle=p.sourceTitle;copy.translation=L.Copy(p.translation);out.passages[#out.passages+1]=copy
        end
    end end
    if options.includeLocations~=false then for i,p in ipairs(base and base.locations or e.locations or {}) do if selected(options.locations,i) then
        out.locations[#out.locations+1]={meaning=p.meaning,zone=p.zone,subzone=p.subzone,mapID=p.mapID,x=p.x,y=p.y,label=p.label or '',source=p.source~='' and p.source or nil,at=p.at}
    end end end
    local annotations=base and base.annotations or e
    for _,k in ipairs({'description','notes','theory','nextStep','tags','status'}) do if options[k]==true and annotations[k]~=nil then out.annotations[k]=L.Copy(annotations[k]) end end
    if options.includeReferences==true then for i,ref in ipairs(base and base.references or e.links or {}) do if selected(options.references,i) then
        -- Foreign local IDs never become navigation targets on another character.
        out.references[#out.references+1]={section=ref.section,label=ref.label or ref.name or 'Related record',explanation=ref.explanation or ref.reason or ''}
    end end end
    return R.Normalize(out)
end
function R.Preview(value)
    local r,err=R.Normalize(value);if not r then return nil,err end
    local lines={r.title..' — '..r.kind,'Sender claim: '..r.sender..' (copy/paste cannot authenticate a sender).',
        'Claimed original source: '..r.originalSource,'One included entry; related references never include their linked records.',
        'All received material stays reported. No personal encounter, reading credit or Knowledge is granted.',
        'Pages: '..#r.pages..' • passages: '..#r.passages..' • locations: '..#r.locations,'Original title: '..r.sourceTitle,'Subtype: '..r.subtype}
    for _,p in ipairs(r.pages) do lines[#lines+1]='\nPage '..(p.number~=nil and tostring(p.number) or 'unknown')..' • claimed '..p.method..' / '..p.source..'\n'..L.Plain(p.raw) end
    for _,p in ipairs(r.passages) do
        lines[#lines+1]='\n'..p.nature..' • '..p.source..(p.private and ' • explicitly shared private passage' or '')..
            (p.speaker~='' and '\nSpeaker: '..p.speaker or '')..(p.sourceTitle~='' and '\nSource title: '..p.sourceTitle or '')..
            (p.translation and '\n'..L.TranslationLabel(p.translation)..' (player contribution; attribution is a claim)' or '')..'\n'..L.Plain(p.raw)
        if p.translation then lines[#lines+1]='Original: '..p.translation.sourceTitle..'\n'..L.Plain(p.translation.sourceRaw) end
    end
    for _,p in ipairs(r.locations) do lines[#lines+1]='\n'..p.meaning..': '..p.zone..' '..p.subzone..' '..p.label..(p.mapID and ' (map '..p.mapID..')' or '')..(p.x and string.format(' %.2f, %.2f',p.x/100,p.y/100) or ' — coordinates unknown') end
    for _,k in ipairs({'description','notes','theory','nextStep','status'}) do if r.annotations[k] then lines[#lines+1]='\nExplicitly included '..k..': '..L.Plain(r.annotations[k]) end end
    if r.annotations.tags then lines[#lines+1]='Tags: '..table.concat(r.annotations.tags,', ') end
    for _,ref in ipairs(r.references) do lines[#lines+1]='\nReference only ('..ref.section..'): '..ref.label..' — '..ref.explanation end
    return table.concat(lines,'\n')
end
local pending=setmetatable({},{__mode='k'})
function R.Prepare(value,receivedFrom)
    local r,err
    if type(value)=='string' then r,err=R.Decode(value) else r,err=R.Normalize(value) end
    if not r then return nil,err end
    if receivedFrom~=nil and (not L.Text(receivedFrom,160,true)) then return nil,'Invalid recorded sender.' end
    local ticket={preview=R.Preview(r)};pending[ticket]={report=r,receivedFrom=receivedFrom and receivedFrom~='' and receivedFrom or nil};return ticket
end
function R.Cancel(ticket) if ticket then pending[ticket]=nil end end
function R.Accept(journal,ticket,selectedID,dryRun)
    local staged=pending[ticket];if not staged then return nil,'Preview this report first.' end
    if ns.InitializationBlocked or journal.readOnly then return nil,'This Lore journal is read-only.' end
    local r,err=R.Normalize(staged.report);if not r then return nil,err end
    local e=selectedID and journal:Get(selectedID)
    if selectedID and not e then return nil,'The selected entry no longer exists.' end
    if e and e.kind~=r.kind then return nil,'Choose an entry of the same kind.' end
    if not e then
        for _,entry in pairs(journal.entries) do for _,old in ipairs(entry.reports or {}) do
            if old.sourceKey==r.sourceKey and old.originalSource==r.originalSource then e=entry;break end
        end;if e then break end end
    end
    if e and e.kind~=r.kind then return nil,'The original report identity belongs to a different entry kind.' end
    -- Validate before copying, so malformed stored list keys cannot be lost.
    local archived={}
    if e then
        local valid;valid,err=L.ValidateEntry(e,e.id);if not valid then return nil,err end
        archived=valid.reports
    end
    local canonical=R.EvidenceKey(r)
    local seen,count,duplicate={},0,nil
    for i,old in ipairs(archived) do
        local key=R.EvidenceKey(old)
        if not seen[key] then seen[key]=true;count=count+1 end
        if key==canonical and not duplicate then duplicate=i end
    end
    if not duplicate and count>=R.MAX_REPORTS then return nil,'Entry report limit reached; no report was changed.' end
    local reports=archived
    if duplicate then
        -- Keep the original snapshot and first receipt intact. A single latest
        -- receipt is bounded even after arbitrarily many unchanged deliveries.
        reports[duplicate].latestReceipt={sender=r.sender,created=r.created,received=L.Now(),receivedFrom=staged.receivedFrom}
    else
        r.received=L.Now();r.receivedFrom=staged.receivedFrom;reports[#reports+1]=r
    end
    local result
    if e then
        local replacement=L.EntryCandidate(e);replacement.reports=reports
        result,err=journal:ReplaceEntry(e.id,replacement,dryRun)
    else result,err=journal:Create(r.kind,{title=r.title,sourceTitle=r.sourceTitle,subtype=r.subtype,origin='reported',reports=reports},nil,dryRun) end
    if not result then return nil,err end
    local delta={newEntry=not e,newEvidence=not duplicate,knownEvidence=duplicate~=nil}
    if not dryRun then pending[ticket]=nil end
    return result,duplicate and 'This evidence is already archived; latest receipt updated.' or nil,delta
end

function R.Preflight(journal,ticket,selectedID)
    local result,err,delta=R.Accept(journal,ticket,selectedID,true)
    if not result then return 'Cannot accept now: '..err,false end
    local summary=delta.newEntry and 'Would add 1 reported entry with 1 evidence revision.'
        or delta.knownEvidence and 'Evidence already archived; only the latest receipt would update.'
        or 'Would add 1 evidence revision to an existing entry. Earlier versions and personal material stay separate.'
    return 'Against this journal now: '..summary,true,delta
end
