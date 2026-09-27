local _, ns = ...

-- Fishing facts have their own lifetime. Never put them in the Bestiary root.
local A={SCHEMA=1,HISTORY_LIMIT=200,SESSION_LIMIT=32,RECENT_LIMIT=256}
ns.Angling=A
for _,key in ipairs({"Public","Read","Text","Safe","Integer","Number","Copy","Array","Count","Now","Position"}) do
    A[key]=ns.Atlas[key] -- stateless, already exposed helpers; no Atlas journal is created
end
A.CurrentLocation=ns.Atlas.CurrentLocation
A.SourceLabels={pool="Identified pool",open="Open water",unclassified="Unclassified water"}
A.VISION="Record fish and other catches alongside the waters and fishing spots where they were found. Build a personal catch history and share useful findings with other anglers."
function A.Key(...)
    local parts={};for i=1,select("#",...) do local v=tostring(select(i,...) or "");parts[i]=#v..":"..v end
    return table.concat(parts)
end
function A.Name(value)
    if not A.Text(value,160) or value:find("%c") then return end
    return (value:gsub("^%s+",""):gsub("%s+$",""))
end
function A.Player()
    local name=A.Read(UnitName,"player") or "Unknown character"
    if ns.PlayerNames and ns.PlayerNames.Current then name=ns.PlayerNames:Current() or name end
    if NameUtil and type(NameUtil.GetFullNameWithoutRealm)=="function" and type(UnitName)=="function" then
        local ok,first,last=pcall(UnitName,"player")
        if ok and A.Public(first) and A.Public(last) then name=A.Read(NameUtil.GetFullNameWithoutRealm,first,last) or name end
    end
    return A.Name(name) or "Unknown character"
end
function A.Location(p)
    local out={zone=A.Name(p and p.zone) or "Unknown waters",subzone=A.Name(p and p.subzone) or ""}
    if p and A.Integer(p.mapID,1,2147483647) then out.mapID=p.mapID end
    if p and A.Position(p) and not (p.x==0 and p.y==0) then out.x,out.y=p.x,p.y end
    out.precision=out.x and "player" or "unknown"
    return out
end
function A.WaterKey(p) return A.Key(p.mapID,p.zone,p.subzone) end
function A.PositionLabel(p)
    if not A.Position(p) then return "Position unknown" end
    local labels={player="Player fishing position (approximate)",exact="Observed pool position",approximate="Player-placed approximate position"}
    return (labels[p.precision] or "Approximate position")..string.format(": %.2f, %.2f",p.x/100,p.y/100)
end
function A.Skill(value)
    local out={}
    for _,k in ipairs({"base","modifier","temporary","effective","equipment","lure"}) do
        if type(value)=="table" and A.Integer(value[k],k=="modifier" and -1000 or 0,10000) then out[k]=value[k] end
    end
    return out
end
local function bounded(list,value,limit) list[#list+1]=value;while #list>limit do table.remove(list,1) end end
local function touch(e,stamp,method)
    e.first=e.first and math.min(e.first,stamp) or stamp;e.last=math.max(e.last or 0,stamp)
    if method then
        e.personal=e.personal or {};e.personal[method]=true
        e.personalFirst=e.personalFirst and math.min(e.personalFirst,stamp) or stamp;e.personalLast=stamp
    end
end
local function itemIdentity(item)
    if item.itemID~=nil and not A.Integer(item.itemID,1,2147483647) then return end
    if A.Integer(item.itemID,1,2147483647) then return "item:"..item.itemID end
    local name=A.Name(item.name);if name then return "name:"..A.Key(item.locale or A.Read(GetLocale) or "unknown",name) end
end
local function poolIdentity(pool)
    if pool.objectID~=nil and not A.Integer(pool.objectID,1,2147483647) then return end
    if A.Integer(pool.objectID,1,2147483647) then return "object:"..pool.objectID end
    local name=A.Name(pool.name);if name then return "name:"..A.Key(pool.locale or A.Read(GetLocale) or "unknown",name) end
end
A.ItemIdentity=itemIdentity;A.PoolIdentity=poolIdentity

function ns.CreateAnglingJournal(saved)
    local readOnly=type(saved.schema)=="number" and saved.schema>A.SCHEMA
    local db=readOnly and {} or saved
    -- v0 is the empty wishlist/early local schema. Preserve any existing owned
    -- tables and add only missing stores. Future schemas stay completely intact.
    for _,k in ipairs({"waters","spots","pools","items","aggregates","history","sessions","recent","recentOrder",
        "waterKeys","poolKeys","itemKeys","aggregateKeys","reported","claims","reportOrigins","state","merged","hoverKeys","eventLog"}) do
        if type(db[k])~="table" then db[k]={} end
    end
    db.schema=A.SCHEMA;db.serial=A.Integer(db.serial,0,999999999) and db.serial or 0
    if not A.Text(db.origin,100) then db.origin=tostring(A.Now()).."-"..math.random(1,999999999) end
    while #db.history>A.HISTORY_LIMIT do table.remove(db.history,1) end
    while #db.sessions>A.SESSION_LIMIT do table.remove(db.sessions,1) end
    while #db.recentOrder>A.RECENT_LIMIT do db.recent[table.remove(db.recentOrder,1)]=nil end
    local events,eventKeys={},{}
    for i=1,#db.eventLog do
        local e=db.eventLog[i]
        if type(e)=="table" and A.Integer(e.at,0,9999999999) and A.Text(e.kind,40) and A.Text(e.message,4000)
            and (e.key==nil or A.Text(e.key,240)) then
            events[#events+1]=e;if e.key then eventKeys[e.key]=e end
        end
    end
    db.eventLog=events
    local j={db=db,state=db.state,readOnly=readOnly,revision=0}
    function j:Changed() self.revision=self.revision+1;if self.onChange then self.onChange() end end
    function j:Log(kind,message,key,stamp)
        if self.readOnly or not A.Text(kind,40) or not A.Text(message,4000) or (key~=nil and not A.Text(key,240)) then return end
        stamp=A.Integer(stamp,0,9999999999) and stamp or A.Now()
        local entry=key and eventKeys[key]
        if entry then
            if entry.message==message then return end
            entry.message=message -- one cumulative log row per obtained catch
        else
            entry={kind=kind,message=message,key=key,at=stamp};db.eventLog[#db.eventLog+1]=entry
            if key then eventKeys[key]=entry end
        end
        if self.onLogChange then self.onLogChange() end
        return entry
    end
    function j:ClearEventLog()
        if self.readOnly then return end
        db.eventLog={};eventKeys={};if self.onLogChange then self.onLogChange() end;return true
    end
    function j:ID(prefix) db.serial=db.serial+1;return prefix..":"..db.serial end
    function j:Writable() return not self.readOnly end
    function j:Get(id)
        return db.waters[id] or db.spots[id] or db.pools[id] or db.items[id]
    end
    function j:Origin(id) return {source=A.Player(),key=db.origin..":"..id,method="recorded"} end
    function j:Ensure(kind,input,method,stamp)
        if self.readOnly then return nil,"Newer Almanac schema: read-only." end
        stamp=stamp or A.Now()
        local store,keys,key,name
        if kind=="water" then
            input=A.Location(input);store,keys=db.waters,db.waterKeys;key=A.WaterKey(input)
            name=input.subzone~="" and input.subzone.." — "..input.zone or input.zone
        elseif kind=="pool" then
            store,keys=db.pools,db.poolKeys;key=poolIdentity(input);name=A.Name(input.name)
        elseif kind=="item" then
            store,keys=db.items,db.itemKeys;key=itemIdentity(input);name=A.Name(input.name) or (input.itemID and "Item #"..input.itemID)
        end
        if not key or not name then return nil,"A readable name or item ID is required." end
        local id=keys[key];local e=id and store[id]
        if not e then
            id=self:ID(kind);e={id=id,kind=kind,name=name,note="",favourite=false,claims={}}
            if kind=="water" then e.mapID,e.zone,e.subzone=input.mapID,input.zone,input.subzone end
            if kind=="pool" then e.objectID=input.objectID;e.locale=input.locale or A.Read(GetLocale) or "unknown" end
            if kind=="item" then e.itemID=input.itemID;e.locale=input.locale or A.Read(GetLocale) or "unknown" end
            store[id]=e;keys[key]=id
        elseif kind=="item" and method and A.Name(input.name) then e.name=A.Name(input.name) end
        if kind=="item" and method and A.Integer(input.icon,1,2147483647) then e.icon=input.icon end
        touch(e,stamp,method)
        return e
    end
    function j:Remember(input)
        if self.readOnly then return nil,"Newer Almanac schema: read-only." end
        local name=A.Name(input.name);if not name then return nil,"Give this spot a name." end
        local p=A.Location(input.location);local stamp=A.Now()
        local water=self:Ensure("water",p,"recorded",stamp)
        local pool
        if input.pool and A.Name(input.pool.name) then pool=self:Ensure("pool",input.pool,"recorded",stamp) end
        -- Never merge nearby coordinates. Saving an existing ID is the only
        -- implicit update; duplicate corrections are an explicit merge action.
        local id=input.id;local e=id and db.spots[id]
        if not e then id=self:ID("spot");e={id=id,kind="spot",claims={},note="",favourite=false};db.spots[id]=e end
        e.name,e.waterID,e.poolID=name,water.id,pool and pool.id
        for _,key in ipairs({"mapID","zone","subzone","x","y","precision"}) do e[key]=p[key] end
        if input.precision=="approximate" and A.Position(p) then e.precision="approximate" end
        e.note=A.Text(input.note,4000,true) and input.note or e.note
        touch(e,stamp,"recorded")
        self:Log("Recorded",(pool and "Recorded pool sighting: " or "Remembered spot: ")..e.name.." — "..water.name)
        self:Changed();return e
    end
    function j:ObservePool(input,location)
        if self.readOnly or not A.Name(input.name) then return end
        local key=poolIdentity(input);local existing=key and db.pools[db.poolKeys[key]]
        if not key or (existing and existing.removed) then return end
        local p=A.Location(location)
        if not p.mapID or p.zone=="Unknown waters" then return end
        -- A world hover proves the zone, never the object's coordinates.
        p.x,p.y,p.precision,p.subzone=nil,nil,"unknown",""
        local waterID=db.waterKeys[A.WaterKey(p)]
        local prior=existing and waterID and db.spots[db.hoverKeys[A.Key(existing.id,waterID)]]
        if prior and prior.removed then return end
        local stamp=A.Now();local pool=self:Ensure("pool",input,"observed",stamp)
        local water=self:Ensure("water",p,"observed",stamp)
        local hoverKey=A.Key(pool.id,water.id);local id=db.hoverKeys[hoverKey]
        local e=id and db.spots[id]
        if not e then
            id=self:ID("spot");e={id=id,kind="spot",name=pool.name,poolID=pool.id,
                waterID=water.id,mapID=p.mapID,zone=p.zone,subzone=p.subzone,precision="unknown",
                note="",favourite=false,claims={},hover=true}
            db.spots[id]=e;db.hoverKeys[hoverKey]=id
            self:Log("Discovery","Pool type seen: "..pool.name.." — "..p.zone..". Exact position unknown.")
        end
        local previous=e.last;touch(e,stamp,"observed")
        if previous~=stamp then self:Changed() end
        return e
    end
    function j:SetPoolRemoved(id,removed)
        local e=db.pools[id]
        if self.readOnly or not e then return nil,"Select a pool type first." end
        if (e.removed==true)==(removed==true) then return true end
        e.removed=removed==true or nil
        self:Log("Correction",(e.removed and "Removed pool type: " or "Restored pool type: ")..e.name..". Catch history retained.")
        self:Changed();return true
    end
    function j:SetSightingRemoved(id,removed)
        local e=db.spots[id]
        if self.readOnly or not e then return nil,"Select a remembered spot first." end
        if (e.removed==true)==(removed==true) then return true end
        e.removed=removed==true or nil
        self:Log("Correction",(e.removed and "Removed " or "Restored ")..(e.poolID and "sighting: " or "spot: ")..e.name.." — "..e.zone..". Catch history retained.")
        self:Changed();return true
    end
    function j:HideWaterPosition(id)
        local e=db.waters[id]
        if self.readOnly or not e or e.mapPositionHidden then return end
        e.mapPositionHidden=true
        self:Log("Correction","Removed fishing position marker: "..e.name..". Catch history retained; a new catch can show a new position.")
        self:Changed();return true
    end
    function j:Edit(id,name,note,favourite)
        local e=self:Get(id)
        if self.readOnly or not e then return nil,"Record unavailable or read-only." end
        if not A.Text(note,4000,true) then return nil,"Notes must be plain text (up to 4,000 bytes)." end
        local changed=e.note~=note or e.favourite~=(favourite==true) or (e.kind=="spot" and e.name~=name)
        if e.kind=="spot" then if not A.Name(name) then return nil,"Give the spot a name." end;e.name=A.Name(name) end
        e.note=note;e.favourite=favourite==true;e.noteUpdated=A.Now()
        if changed then self:Log("Notes","Updated notes or preferences: "..e.name) end
        self:Changed();return true
    end
    function j:MergeSpots(fromID,intoID)
        local from,into=db.spots[fromID],db.spots[intoID]
        if self.readOnly or not from or not into or from.removed or into.removed or from==into or from.waterID~=into.waterID or from.poolID~=into.poolID then
            return nil,"Choose two spots in the same waters with the same pool association."
        end
        -- Archive the original, including its position/notes and claim provenance.
        -- Aggregates retain separate identities; only their spot reference moves.
        db.merged[fromID]=A.Copy(from);db.merged[fromID].mergedInto=intoID
        into.mergedFrom=into.mergedFrom or {};into.mergedFrom[#into.mergedFrom+1]=fromID
        for _,store in ipairs({db.aggregates,db.reported,db.history,db.sessions,db.recent}) do
            for _,v in pairs(store) do if v.spotID==fromID then v.spotID=intoID end end
        end
        for _,v in pairs(db.claims) do if v.recordID==fromID then v.recordID=intoID end end
        for _,v in pairs(from.claims) do into.claims[#into.claims+1]=v end
        for k,on in pairs(from.personal or {}) do into.personal=into.personal or {};into.personal[k]=on end
        into.first=math.min(into.first,from.first);into.last=math.max(into.last,from.last)
        if from.personalFirst then into.personalFirst=math.min(into.personalFirst or from.personalFirst,from.personalFirst) end
        if from.personalLast then into.personalLast=math.max(into.personalLast or 0,from.personalLast) end
        into.favourite=into.favourite or from.favourite
        db.spots[fromID]=nil;db.aggregateKeys={}
        self:Log("Correction","Merged spot: "..from.name.." into "..into.name..". Original notes and history retained.")
        self:Changed();return into
    end
    function j:Context(location,assignment,method,skill)
        local p=A.Location(location);local water=self:Ensure("water",p,method or "observed")
        if not water then return end
        local c={waterID=water.id,source="unclassified",association="unknown",method=method or "observed",position=p,skill=A.Skill(skill),at=A.Now()}
        if assignment and A.SourceLabels[assignment.source] then
            c.source=assignment.source;c.association=c.source=="unclassified" and "unknown" or "assigned"
            if c.source=="pool" and db.pools[assignment.poolID] then c.poolID=assignment.poolID
            elseif c.source=="pool" then c.source="unclassified";c.association="unknown" end
            local spot=db.spots[assignment.spotID]
            if spot and spot.waterID==water.id and (not spot.poolID or spot.poolID==c.poolID) then c.spotID=spot.id end
        end
        return c
    end
    function j:RecordCatch(token,context,items)
        if self.readOnly then return nil,"Newer Almanac schema: read-only." end
        if type(context)=="table" then
            for _=1,64 do
                local archived=db.merged[context.spotID]
                if not archived then break end
                context.spotID=archived.mergedInto
            end
        end
        if not A.Text(token,200) or type(context)~="table" or not db.waters[context.waterID]
            or not A.SourceLabels[context.source] or not (context.method=="observed" or context.method=="recorded")
            or (context.source=="pool" and not db.pools[context.poolID]) or not A.Array(items,50) or #items==0 then
            return nil,"Invalid fishing observation."
        end
        if (context.source=="unclassified" and context.association~="unknown")
            or (context.source~="unclassified" and context.association~="assigned" and context.association~="observed")
            or (context.source~="pool" and context.poolID~=nil) then return nil,"Invalid source evidence." end
        if context.spotID then
            local spot=db.spots[context.spotID]
            if not spot or spot.waterID~=context.waterID or (spot.poolID and spot.poolID~=context.poolID) then return nil,"Invalid spot association." end
        end
        local quantities,info={},{}
        for _,item in ipairs(items) do
            local key=type(item)=="table" and itemIdentity(item)
            if not key or not A.Integer(item.quantity,1,1000000) then return nil,"Invalid caught item or quantity." end
            quantities[key]=(quantities[key] or 0)+item.quantity;info[key]=item
        end
        local ledger=db.recent[token];local stamp=context.at or A.Now()
        if not A.Integer(stamp,0,9999999999) then return nil,"Invalid observation time." end
        local aggregate
        if ledger then
            aggregate=db.aggregates[ledger.aggregateID]
            if not aggregate then return nil,"Observation reference unavailable." end
            for _,key in ipairs({"waterID","source","poolID","spotID","association","method"}) do
                if aggregate[key]~=context[key] then return nil,"Conflicting duplicate observation." end
            end
        else
            local key=A.Key(context.waterID,context.spotID,context.poolID,context.source,context.association,context.method)
            aggregate=db.aggregates[db.aggregateKeys[key]]
            if not aggregate then
                aggregate={id=self:ID("catch"),waterID=context.waterID,spotID=context.spotID,poolID=context.poolID,
                    source=context.source,association=context.association,method=context.method,events=0,items={},first=stamp,last=stamp}
                db.aggregates[aggregate.id]=aggregate;db.aggregateKeys[key]=aggregate.id
            end
            ledger={aggregateID=aggregate.id,items={},at=stamp};db.recent[token]=ledger
            bounded(db.recentOrder,token,A.RECENT_LIMIT+1)
            if #db.recentOrder>A.RECENT_LIMIT then db.recent[table.remove(db.recentOrder,1)]=nil end
            aggregate.events=aggregate.events+1;aggregate.first=math.min(aggregate.first,stamp);aggregate.last=math.max(aggregate.last,stamp)
            aggregate.lastPosition=A.Copy(context.position);aggregate.lastSkill=A.Skill(context.skill)
            db.waters[context.waterID].mapPositionHidden=nil
            local skill=A.Skill(context.skill)
            if context.method=="observed" and skill.effective and (not aggregate.lowestSkill or skill.effective<aggregate.lowestSkill.effective) then
                aggregate.lowestSkill=skill;aggregate.lowestSkillAt=stamp
            end
            local h={token=token,aggregateID=aggregate.id,waterID=aggregate.waterID,spotID=aggregate.spotID,at=stamp,items={},skill=skill}
            bounded(db.history,h,A.HISTORY_LIMIT)
            local current=self.session
            if not current or current.waterID~=context.waterID or current.source~=context.source or current.poolID~=context.poolID
                or current.spotID~=context.spotID or stamp-current.last>300 then
                current={id=self:ID("session"),waterID=context.waterID,spotID=context.spotID,poolID=context.poolID,source=context.source,
                    events=0,items={},first=stamp,last=stamp,newItems=0}
                bounded(db.sessions,current,A.SESSION_LIMIT);self.session=current
            end
            current.events=current.events+1;current.last=stamp;ledger.sessionID=current.id
        end
        local changed=false
        for key,quantity in pairs(quantities) do
            local prior=ledger.items[key] or 0
            if quantity>prior then
                local previous=db.items[db.itemKeys[key]]
                local newlyPersonal=not previous or not previous.personal or not next(previous.personal)
                local item=self:Ensure("item",info[key],context.method,stamp)
                local entry=aggregate.items[item.id] or {quantity=0,occurrences=0,first=stamp,last=stamp}
                aggregate.items[item.id]=entry;entry.quantity=entry.quantity+quantity-prior
                if prior==0 then entry.occurrences=entry.occurrences+1 end
                entry.first=math.min(entry.first,stamp);entry.last=math.max(entry.last,stamp)
                entry.lastPosition=A.Copy(context.position)
                for _,h in ipairs(db.history) do if h.token==token then h.items[item.id]=quantity end end
                for _,s in ipairs(db.sessions) do if s.id==ledger.sessionID then
                    if newlyPersonal then s.newItems=s.newItems+1 end
                    s.items[item.id]=(s.items[item.id] or 0)+quantity-prior
                end end
                ledger.items[key]=quantity;changed=true
            end
        end
        if changed then
            local parts={}
            for key,quantity in pairs(ledger.items) do
                local item=db.items[db.itemKeys[key]]
                parts[#parts+1]=(item and item.name or "Unknown item").." ×"..quantity
            end
            table.sort(parts);local count=#parts
            while #parts>10 do table.remove(parts) end
            if count>10 then parts[#parts+1]="and "..(count-10).." other items" end
            local water=db.waters[context.waterID];local pool=db.pools[context.poolID]
            self:Log(context.method=="recorded" and "Manual catch" or "Catch",
                (context.method=="recorded" and "Player-recorded catch" or "Fishing catch").." — "..water.name.."\n"..
                table.concat(parts,", ").."\n"..A.SourceLabels[context.source]..(pool and ": "..pool.name or "")..
                (context.association=="assigned" and " (player assigned)" or ""),"catch:"..token,stamp)
            self:Changed()
        end
        return aggregate,changed
    end
    function j:EndSession() self.session=nil end
    function j:Matches(fact,entry)
        return entry and ((entry.kind=="water" and fact.waterID==entry.id) or (entry.kind=="spot" and fact.spotID==entry.id)
            or (entry.kind=="pool" and fact.source=="pool" and fact.poolID==entry.id) or (entry.kind=="item" and fact.items[entry.id]~=nil))
    end
    function j:Facts(entry,knowledge,filters)
        local rows={};filters=filters or {}
        local function collect(store,reported)
            for _,fact in pairs(store) do
                local water=db.waters[fact.waterID]
                if self:Matches(fact,entry) and (not filters.mapID or (water and water.mapID==filters.mapID))
                    and (not filters.waterID or fact.waterID==filters.waterID)
                    and (not filters.source or filters.source=="all" or filters.source==fact.source) then
                    rows[#rows+1]={fact=fact,reported=reported}
                end
            end
        end
        if knowledge~="reported" then collect(db.aggregates,false) end
        if knowledge~="personal" then collect(db.reported,true) end
        table.sort(rows,function(a,b) return a.fact.id<b.fact.id end);return rows
    end
    function j:Summary(entry,filters)
        local result={events=0,recordedEvents=0,items={},reportedEvents=0,reportedItems={},locations={}}
        for _,row in ipairs(self:Facts(entry,nil,filters)) do
            local f=row.fact;result.locations[f.spotID or f.waterID]=true
            local items=row.reported and result.reportedItems or result.items
            if row.reported then result.reportedEvents=result.reportedEvents+f.events
            else result.events=result.events+f.events;if f.method=="recorded" then result.recordedEvents=result.recordedEvents+f.events end end
            for id,v in pairs(f.items) do
                if entry.kind~="item" or entry.id==id then
                    local s=items[id] or {quantity=0,occurrences=0};items[id]=s
                    s.quantity=s.quantity+v.quantity;s.occurrences=s.occurrences+v.occurrences
                end
            end
        end
        return result
    end
    function j:Links(entry,kind,filters)
        local ids={}
        if not entry then return {} end
        for _,row in ipairs(self:Facts(entry,filters and filters.knowledge,filters)) do
            local f=row.fact
            if kind=="items" then for id in pairs(f.items) do ids[id]=true end
            else local spot=db.spots[f.spotID];ids[spot and not spot.removed and spot.id or f.waterID]=true end
        end
        if kind~="items" then
            if entry.kind=="spot" then ids[entry.waterID]=true;if entry.poolID then ids[entry.poolID]=true end end
            for id,spot in pairs(db.spots) do
                if not spot.removed and ((entry.kind=="pool" and spot.poolID==entry.id) or (entry.kind=="water" and spot.waterID==entry.id)) then ids[id]=true end
            end
        end
        local out={};for id in pairs(ids) do local e=self:Get(id);if e then out[#out+1]=e end end
        table.sort(out,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name<b.name end);return out
    end
    function j:SearchText(entry)
        local parts={entry.name,entry.note or "",entry.zone or "",entry.subzone or ""}
        local function add(e) if e and not e.removed then parts[#parts+1]=e.name;parts[#parts+1]=e.note or "" end end
        for _,row in ipairs(self:Facts(entry)) do
            local f=row.fact;add(db.waters[f.waterID]);add(db.spots[f.spotID]);add(db.pools[f.poolID])
            for id in pairs(f.items) do add(db.items[id]) end
        end
        if entry.kind=="spot" then add(db.pools[entry.poolID]);add(db.waters[entry.waterID]) end
        if entry.kind=="pool" then for _,spot in pairs(db.spots) do if not spot.removed and spot.poolID==entry.id then add(spot);add(db.waters[spot.waterID]) end end end
        for _,key in ipairs(entry.claims or {}) do local claim=db.claims[key];if claim and claim.notes then parts[#parts+1]=claim.notes end end
        return table.concat(parts," "):lower()
    end
    function j:List(view,filters)
        filters=filters or {};local rows={};local query=(filters.query or ""):lower()
        local stores=view=="pools" and {db.pools} or view=="catches" and {db.items} or {db.waters,db.spots}
        for _,store in ipairs(stores) do for _,e in pairs(store) do
            local personal=e.personal and next(e.personal)~=nil
            local reported=#(e.claims or {})>0
            local known=(filters.knowledge~="personal" or personal) and (filters.knowledge~="reported" or reported)
            local inZone=not filters.mapID or e.mapID==filters.mapID
            if not inZone then
                for _,location in ipairs(self:Links(e,"locations",filters)) do if location.mapID==filters.mapID then inZone=true end end
            end
            local facts=self:Facts(e,filters.knowledge,filters)
            local fished=#facts>0
            local sourceOK=not filters.source or filters.source=="all" or #facts>0 or (filters.source=="pool" and (e.kind=="pool" or e.poolID~=nil))
            local removed=e.removed or (e.hover and db.pools[e.poolID] and db.pools[e.poolID].removed)
            local visible=filters.status=="removed" and e.removed or (filters.status~="removed" and not removed)
            if visible and known and inZone and sourceOK and (filters.status~="favourites" or e.favourite)
                and (filters.status~="fished" or fished) and (filters.status~="unfished" or not fished)
                and (query=="" or self:SearchText(e):find(query,1,true)) then rows[#rows+1]=e end
        end end
        table.sort(rows,function(a,b)
            if view=="catches" then
                local at,bt=a.personalLast or a.last or 0,b.personalLast or b.last or 0
                if at~=bt then return at>bt end
            end
            if a.name==b.name then return a.id<b.id end;return a.name<b.name
        end)
        return rows
    end
    function j:View(view)
        view=(view=="pools" or view=="catches") and view or "waters"
        db.state.views=db.state.views or {};local s=db.state.views[view]
        if type(s)~="table" then s={};db.state.views[view]=s end
        s.query=A.Text(s.query,200,true) and s.query or ""
        s.offset=A.Integer(s.offset,0,100000) and s.offset or 0
        s.knowledge=(s.knowledge=="personal" or s.knowledge=="reported") and s.knowledge or "all"
        s.source=A.SourceLabels[s.source] and s.source or "all"
        s.status=(s.status=="favourites" or s.status=="fished" or s.status=="unfished" or s.status=="removed") and s.status or "all"
        return s
    end
    j:View("waters");j:View("pools");j:View("catches")
    return j
end
