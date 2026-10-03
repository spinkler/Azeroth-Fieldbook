local _,ns=...
local A={SCHEMA=1,MAX_POINTS=256};ns.Annals=A
function A.Public(v) return not (issecretvalue and issecretvalue(v)) end
function A.Int(v,lo,hi) return A.Public(v) and type(v)=='number' and v==math.floor(v) and v>=lo and v<=hi end
function A.Text(v,n) return A.Public(v) and type(v)=='string' and #v<=n and not v:find('%c') end
function A.Read(fn,...)
    if type(fn)~='function' then return end
    local ok,v=pcall(fn,...);if ok and A.Public(v) then return v end
end
function A.Now() return A.Read(time) or 0 end
function A.Copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v) do out[k]=A.Copy(x) end;return out
end
function A.JourneyInstance(kind) return kind=='party' or kind=='raid' or kind=='scenario' end
function A.Location()
    local p={zone=A.Read(GetRealZoneText),subzone=A.Read(GetSubZoneText),level=A.Read(UnitLevel,'player')}
    local instance=A.Read(function() local _,kind=IsInInstance();return kind end)
    if A.JourneyInstance(instance) then p.instanceType=instance end
    local ghost,dead,taxi=A.Read(UnitIsGhost,'player'),A.Read(UnitIsDeadOrGhost,'player'),A.Read(UnitOnTaxi,'player')
    if ghost==true or ghost==1 then p.state='ghost'
    elseif dead==true or dead==1 then p.state='dead'
    elseif taxi==true or taxi==1 then p.state='flight'
    elseif dead==false or dead==0 then p.state='alive' end
    if not A.Text(p.zone,160) then p.zone=nil end
    if not A.Text(p.subzone,160) then p.subzone=nil end
    if not A.Int(p.level,1,1000) then p.level=nil end
    local E=ns.AtlasEnvironment
    local mapID=A.Read(C_Map and C_Map.GetBestMapForUnit,'player')
    -- Position is queried in exactly the stored map, including Micro maps.
    local pos=E and E.Position(mapID)
    if pos then p.mapID,p.x,p.y=pos.mapID,pos.x,pos.y
    elseif A.Int(mapID,1,2147483647) then p.mapID=mapID end
    return p
end
local kinds={accepted=true,removed=true,completed=true,discovery=true,flight=true,death=true,hearth=true,teleport=true,crossing=true,battleground=true,instance=true}
local function validItem(v)
    return type(v)=='table' and (A.Int(v.itemID,1,2147483647) or A.Int(v.currencyID,1,2147483647) or A.Int(v.spellID,1,2147483647)) and A.Int(v.quantity,0,2147483647)
        and (v.name==nil or A.Text(v.name,240)) and (v.icon==nil or A.Int(v.icon,1,2147483647))
        and (v.quality==nil or A.Int(v.quality,0,8))
        and (v.link==nil or (A.Text(v.link,2048) and v.link:match('^item:[%d:%-]+$') and tonumber(v.link:match('^item:(%d+)'))==v.itemID))
end
function A.ValidEvent(e)
    if type(e)~='table' or not A.Int(e.at,0,9999999999) or not kinds[e.kind]
        or not A.Text(e.title,240) or (e.questID~=nil and not A.Int(e.questID,1,2147483647)) then return false end
    for _,k in ipairs({'zone','subzone'}) do if e[k]~=nil and not A.Text(e[k],160) then return false end end
    if e.level~=nil and not A.Int(e.level,1,1000) then return false end
    if e.sequence~=nil and not A.Int(e.sequence,1,1000000000000) then return false end
    if e.mapID~=nil and not A.Int(e.mapID,1,2147483647) then return false end
    if e.instanceType~=nil and not A.JourneyInstance(e.instanceType) then return false end
    if e.instanceName~=nil and not A.Text(e.instanceName,160) then return false end
    if e.instanceID~=nil and not A.Int(e.instanceID,1,2147483647) then return false end
    if e.instanceAction~=nil and (e.kind~='instance' or (e.instanceAction~='enter' and e.instanceAction~='exit')) then return false end
    for _,k in ipairs({'x','y'}) do if e[k]~=nil and not A.Int(e[k],0,10000) then return false end end
    if e.link~=nil and (type(e.link)~='table' or not A.Text(e.link.section,40) or not A.Text(e.link.key,500)
        or not A.Text(e.link.identity,500)) then return false end
    local r=e.reward
    if r~=nil then
        if type(r)~='table' or (r.chosen~=nil and not validItem(r.chosen)) or (r.automatic~=nil and type(r.automatic)~='table') then return false end
        if r.single~=nil and not validItem(r.single) then return false end
        if r.currencyOffers~=nil and type(r.currencyOffers)~='table' then return false end
        if r.count~=nil and not A.Int(r.count,0,64) then return false end
        if r.automaticCount~=nil and not A.Int(r.automaticCount,0,64) then return false end
        if r.captureSource~=nil and not A.Text(r.captureSource,80) then return false end
        if r.capturedAt~=nil and not A.Int(r.capturedAt,e.at,9999999999) then return false end
        for _,key in ipairs({'choices','spellOffers'}) do
            if r[key]~=nil then
                if type(r[key])~='table' then return false end
                for i,v in pairs(r[key]) do if not A.Int(i,1,64) or not validItem(v) then return false end end
            end
        end
        for i,v in ipairs(r.currencyOffers or {}) do if i>64 or not validItem(v) then return false end end
        for i,v in ipairs(r.automatic or {}) do if i>64 or not validItem(v) then return false end end
        for _,k in ipairs({'xp','money','offeredXP','offeredMoney'}) do if r[k]~=nil and not A.Int(r[k],0,2147483647) then return false end end
    end
    return true
end
local function dense(t)
    local n=0;for k in pairs(t) do if not A.Int(k,1,100000000) then return false end;n=n+1 end
    for i=1,n do if t[i]==nil then return false end end;return true
end
function ns.CreateAnnalsJournal(saved)
    local readOnly=ns.InitializationBlocked or type(saved)~='table' or (saved.schema~=nil and saved.schema~=A.SCHEMA)
    if not readOnly then
        for _,k in ipairs({'events','segments','quests','pending','settings','seen'}) do
            if saved[k]~=nil and type(saved[k])~='table' then readOnly=true end
        end
        for _,k in ipairs({'events','segments'}) do if type(saved[k])=='table' and not dense(saved[k]) then readOnly=true end end
        -- Untrusted provisional data cannot be finalized into historical evidence.
        for _,p in pairs(type(saved.pending)=='table' and saved.pending or {}) do
            if type(p)~='table' or not A.Int(p.at,0,9999999999) or (p.kind~='completed' and p.kind~='removed' and p.kind~='accepted')
                or type(p.location)~='table' then readOnly=true end
            if type(p)=='table' and p.snapshot~=nil and not A.ValidEvent({kind='completed',at=0,title='',reward=p.snapshot}) then readOnly=true end
            if type(p)=='table' and p.kind=='accepted' and (type(p.reward)~='table' or not A.ValidEvent({kind='accepted',at=0,title='',reward=p.reward})) then readOnly=true end
        end
    end
    local db=not readOnly and saved or {events={},segments={},quests={},pending={},settings={},seen={}}
    if not readOnly then
        db.schema=A.SCHEMA
        for _,k in ipairs({'events','segments','quests','pending','settings','seen'}) do db[k]=db[k] or {} end
    end
    local j={db=db,readOnly=readOnly,revision=0,events={},days={},dayOrder={}}
    function j:StorageStatus()
        if self.readOnly then return 'Archive: read-only','Saved data is unsupported; archive usage is unavailable. Original data is preserved.' end
        -- Estimate a readable Lua SavedVariables representation, including keys,
        -- escaped strings and table formatting. Never serialize or alter the store.
        local active={}
        local function size(value,depth)
            local kind=type(value)
            if kind=='string' then return #string.format('%q',value) end
            if kind=='number' or kind=='boolean' then return #tostring(value) end
            if kind~='table' or active[value] or depth>64 then return nil end
            active[value]=true
            local bytes=3+depth
            for key,item in pairs(value) do
                local k,v=size(key,depth+1),size(item,depth+1)
                if not k or not v then active[value]=nil;return nil end
                bytes=bytes+depth+1+1+k+4+v+2
            end
            active[value]=nil;return bytes
        end
        local bytes=size(db,0)
        if not bytes then return 'Archive: usage unavailable','The Annals store contains data that cannot be estimated. Original data is preserved.' end
        local points,payload=0,0
        for _,segment in ipairs(db.segments) do
            if type(segment)=='table' and type(segment.data)=='string' then
                payload=payload+#segment.data;points=points+math.floor(#segment.data/9)
            end
        end
        return string.format('Archive: ~%.2f MiB',bytes/1048576),
            string.format('%d estimated saved-data bytes\n%d event records • %d journey segments\n%d encoded points • %d trail payload bytes\nIncludes events, trail headers, quest tracking and settings for this character. No Annals archive size cap. Estimated Lua formatting; actual SavedVariables file size and memory usage differ.',bytes,#db.events,#db.segments,points,payload)
    end
    function j:Sequence()
        if self.readOnly or ns.InitializationBlocked then return end
        db.sequence=(A.Int(db.sequence,0,999999999999) and db.sequence or #db.events)+1
        return db.sequence
    end
    function j:Index(e,id)
        if not A.ValidEvent(e) then return end
        self.events[#self.events+1]={event=e,id=id}
        local day=math.floor(e.at/86400)
        if not self.days[day] then self.days[day]={};self.dayOrder[#self.dayOrder+1]=day end
        self.days[day][#self.days[day]+1]=id
    end
    for id,e in ipairs(db.events) do j:Index(e,id) end
    function j:Append(kind,title,extra,location,at,skipTrail)
        if self.readOnly or ns.InitializationBlocked or not kinds[kind] then return end
        local e=A.Copy(location or A.Location());e.kind=kind;e.at=at or A.Now()
        e.title=A.Text(title,240) and title or 'Unknown entry'
        for k,v in pairs(extra or {}) do e[k]=A.Copy(v) end
        e.sequence=e.sequence or self:Sequence()
        if not A.ValidEvent(e) then return end
        local id=#db.events+1;db.events[id]=e;self:Index(e,id);self.revision=self.revision+1
        if self.trail and not skipTrail then self.trail:Sample(e,true) end
        if self.onChange then self.onChange(id) end
        return e,id
    end
    function j:Quest(kind,id,title,reward,location,at,token,sequence,skipTrail)
        if self.readOnly or not A.Int(id,1,2147483647) then return end
        local old=db.quests[id]
        if type(old)=='table' and old.kind==kind and (not token or token==old.token) then return end
        local e,index=self:Append(kind,title or (type(old)=='table' and old.title) or ('Quest #'..id),
            {questID=id,reward=reward,sequence=sequence},location,at,skipTrail)
        if e then db.quests[id]={kind=kind,title=e.title,at=e.at,token=token};return e,index end
    end
    function j:Discover(section,key,title,icon,identity)
        if self.readOnly or not A.Text(section,40) or not A.Text(key,500) then return end
        local unique=section..'\031'..key..'\031'..tostring(identity or '')
        if db.seen[unique] then return end
        local e=self:Append('discovery',title,{link={section=section,key=key,identity=identity or '',icon=icon}})
        if e then db.seen[unique]=true end
        return e
    end
    function j:Range(first,last,filter,level)
        local out={}
        for _,row in ipairs(self.events) do local e=row.event
            if e.at>=first and e.at<=last and (not filter or filter=='all' or e.kind==filter or (type(filter)=='table' and filter[e.kind]==true))
                and (not level or e.level==level) then out[#out+1]=row end
        end
        table.sort(out,function(a,b) if a.event.at==b.event.at then return (a.event.sequence or a.id)<(b.event.sequence or b.id) end;return a.event.at<b.event.at end)
        return out
    end
    function j:Bounds()
        local lo,hi
        for _,row in ipairs(self.events) do local t=row.event.at;lo=math.min(lo or t,t);hi=math.max(hi or t,t) end
        for _,s in ipairs(db.segments) do if type(s)=='table' and A.Int(s.at,0,9999999999) and A.Int(s.finish,s.at,9999999999) then
            lo=math.min(lo or s.at,s.at);hi=math.max(hi or s.finish,s.finish)
        end end
        return lo or A.Now(),hi or A.Now()
    end
    return j
end
