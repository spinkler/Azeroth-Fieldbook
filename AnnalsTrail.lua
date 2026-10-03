local _,ns=...
local A=ns.Annals
-- Printable fixed-width base64 digits: x(3), y(3), seconds delta(2), anchor(1).
-- No executable serialization, escapes, locale dependence or binary SV strings.
local alphabet='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_'
local digits={};for i=1,#alphabet do digits[alphabet:sub(i,i)]=i-1 end
local function pack(n,width)
    local out='';for _=1,width do local d=n%64;out=alphabet:sub(d+1,d+1)..out;n=math.floor(n/64) end;return out
end
local function unpackNumber(s)
    local n=0;for i=1,#s do local d=digits[s:sub(i,i)];if not d then return end;n=n*64+d end;return n
end
function A.EncodePoint(p,previous)
    local dt=p.at-previous
    if not A.Int(p.x,0,10000) or not A.Int(p.y,0,10000) or not A.Int(dt,0,4095) then return end
    return pack(p.x,3)..pack(p.y,3)..pack(dt,2)..(p.anchor and '1' or '0')
end
function A.Decode(s)
    if type(s)~='table' or s.v~=1 or not A.Int(s.mapID,1,2147483647) or not A.Int(s.at,0,9999999999)
        or type(s.data)~='string' or #s.data%9~=0 or #s.data>9*A.MAX_POINTS then return nil,'Invalid trail segment or version.' end
    local out,t={},s.at
    for i=1,#s.data,9 do
        local x=unpackNumber(s.data:sub(i,i+2));local y=unpackNumber(s.data:sub(i+3,i+5))
        local dt=unpackNumber(s.data:sub(i+6,i+7));local flag=s.data:sub(i+8,i+8)
        if not x or x>10000 or not y or y>10000 or not dt or (flag~='0' and flag~='1') or (#out==0 and dt~=0) then return nil,'Malformed trail payload.' end
        t=t+dt;if t>9999999999 then return nil,'Invalid time.' end
        local state=s.state
        if state~='dead' and state~='ghost' and state~='alive' and state~='flight' then
            state=s.flight==true and 'flight' or (type(s.context)=='string' and s.context:match(':true$') and 'dead / ghost')
                or (type(s.context)=='string' and s.context:match(':false$') and 'alive') or nil
        end
        out[#out+1]={x=x,y=y,at=t,anchor=flag=='1',mapID=s.mapID,level=A.Int(s.level,1,1000) and s.level or nil,flight=s.flight==true,mount=(s.mount==60 or s.mount==100) and s.mount or nil,state=state}
    end
    if s.finish~=nil and (not A.Int(s.finish,s.at,9999999999) or s.finish~=t) then return nil,'Trail time header mismatch.' end
    return out
end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function deviation(p,a,b)
    local dx,dy=b.x-a.x,b.y-a.y;local den=dx*dx+dy*dy
    local f=den>0 and math.max(0,math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/den)) or 0
    return math.sqrt((p.x-a.x-f*dx)^2+(p.y-a.y-f*dy)^2)
end
local function timedDeviation(p,a,b)
    local f=b.at>a.at and math.max(0,math.min(1,(p.at-a.at)/(b.at-a.at))) or 0
    return math.sqrt((p.x-a.x-f*(b.x-a.x))^2+(p.y-a.y-f*(b.y-a.y))^2)
end
function A.Simplify(points,tolerance)
    if #points<3 then return points end
    local keep={[1]=true,[#points]=true};local anchors={1}
    for i=2,#points-1 do if points[i].anchor then anchors[#anchors+1]=i;keep[i]=true end end
    anchors[#anchors+1]=#points
    local stack={};for i=2,#anchors do stack[#stack+1]={anchors[i-1],anchors[i]} end
    while #stack>0 do
        local pair=table.remove(stack);local first,last=pair[1],pair[2];local far,index=tolerance or 10
        for i=first+1,last-1 do
            -- Playback follows elapsed time, so a straight line with a stop or
            -- speed change still needs its timing observations.
            local d=math.max(deviation(points[i],points[first],points[last]),timedDeviation(points[i],points[first],points[last]))
            -- Preserve timing too: no simplified chord spans over two minutes.
            if points[last].at-points[first].at>120 and i==math.floor((first+last)/2) then d=math.huge end
            if d>far then far,index=d,i end
        end
        if index then keep[index]=true;stack[#stack+1]={first,index};stack[#stack+1]={index,last} end
    end
    local out={};for i,p in ipairs(points) do if keep[i] then out[#out+1]=p end end;return out
end
function ns.CreateAnnalsTrail(j,options)
    local t={journal=j,options=options or {},reason='session',revision=0};j.trail=t
    local current,points,lastPoll,pending,idlePoint
    local function write(p)
        local encoded=A.EncodePoint(p,points[#points] and points[#points].at or current.at)
        if not encoded then return end
        current.data=current.data..encoded;points[#points+1]=A.Copy(p);current.finish=p.at
        t.revision=t.revision+1
    end
    local function writeAnchor(p)
        local previous=points[#points]
        if p.at==previous.at and distance(p,previous)==0 then
            if not previous.anchor then previous.anchor=true;current.data=current.data:sub(1,-2)..'1';t.revision=t.revision+1 end
        elseif p.at>previous.at then
            local copy=A.Copy(p);copy.anchor=true;write(copy)
        end
    end
    function t:Break(reason)
        if j.readOnly or ns.InitializationBlocked then return end
        if current then
            if pending and pending.at>points[#points].at and distance(pending,points[#points])>=4 and #points<A.MAX_POINTS then write(pending) end
            if self.options.simplify~=false and not A.Read(InCombatLockdown) then
                local simple=A.Simplify(points,self.options.tolerance or 30)
                local data,previous={},current.at
                for _,p in ipairs(simple) do data[#data+1]=A.EncodePoint(p,previous);previous=p.at end
                current.data=table.concat(data)
            end
            current.closed=true
        end
        current,points,lastPoll,pending,idlePoint=nil,nil,nil,nil,nil;self.reason=reason or 'break';self.revision=self.revision+1
    end
    function t:SetEnabled(enabled)
        if j.readOnly or ns.InitializationBlocked then return end
        self:Break('recording resumed');j.db.settings.trail=enabled==true
    end
    function t:Sample(p,anchor)
        if j.readOnly or ns.InitializationBlocked or j.db.settings.trail==false then return end
        if p and A.JourneyInstance(p.instanceType) then self:Break('inside instance');return end
        if not p or not A.Int(p.mapID,1,2147483647) or not A.Int(p.x,0,10000) or not A.Int(p.y,0,10000) then self:Break('position unavailable');return end
        p=A.Copy(p);p.at=p.at or A.Now();p.anchor=anchor==true
        if not A.Int(p.at,0,9999999999) then return end
        local joinFrom
        if current then
            if p.flight==nil then p.flight=current.flight==true end
            if p.mount==nil then p.mount=current.mount end
            if p.state==nil then p.state=current.state end
            local gap=p.at-(lastPoll and lastPoll.at or current.finish)
            if p.at<current.finish or gap>12 then self:Break('observation gap')
            elseif p.context and current.context and p.context~=current.context then self:Break('travel state')
            elseif p.mapID~=current.mapID then
                -- Only a measured, short world-space step may bridge two maps.
                local E=ns.AtlasEnvironment
                local a=lastPoll and E and E.World(lastPoll);local b=E and E.World(p)
                if a and b and a.continentID==b.continentID and distance(a,b)<=1000 then
                    joinFrom=#j.db.segments
                end
                self:Break('map transition')
            elseif lastPoll and distance(lastPoll,p)>(self.options.jump or 1000) then self:Break('discontinuous movement')
            elseif p.flight~=nil and p.flight~=(current.flight==true) then
                joinFrom=#j.db.segments;self:Break('flight state')
            elseif p.mount~=current.mount then
                joinFrom=#j.db.segments;self:Break('mount state')
            elseif p.state and current.state and p.state~=current.state then self:Break('player state')
            elseif (anchor or distance(points[#points],p)>=(self.options.minimum or 40) or (idlePoint and distance(lastPoll,p)>0)) and
                (p.at-current.at>1800 or #points>=A.MAX_POINTS-1) then
                joinFrom=#j.db.segments;self:Break('chunk')
            end
        end
        if not current then
            current={v=1,mapID=p.mapID,at=p.at,finish=p.at,level=p.level,reason=self.reason,context=p.context,joinFrom=joinFrom,flight=p.flight==true or nil,mount=p.mount,state=p.state,data=''}
            j.db.segments[#j.db.segments+1]=current;points={};write(p);lastPoll=p;idlePoint=p;return
        end
        -- Retain arrival/departure times once a stop is confirmed. No periodic
        -- idle writes; these two anchors prevent playback drifting through rests.
        if lastPoll and p.at>lastPoll.at then
            if distance(lastPoll,p)==0 then
                idlePoint=idlePoint or lastPoll
                if p.at-idlePoint.at>=4 and (idlePoint.at==points[#points].at or distance(idlePoint,points[#points])>=4) then
                    writeAnchor(idlePoint)
                end
            else
                if idlePoint and lastPoll.at-idlePoint.at>=4 and lastPoll.at>points[#points].at then
                    writeAnchor(lastPoll)
                end
                idlePoint=nil
            end
        end
        local previous=points[#points];local moved=distance(previous,p)
        local interval=self.options.interval or 15
        local turn=pending and pending.at-previous.at>=interval and deviation(pending,previous,p)>=(self.options.turn or 40)
        if turn and distance(previous,pending)>=(self.options.minimum or 40) then write(pending);previous=points[#points];moved=distance(previous,p) end
        if anchor and p.at==previous.at and moved==0 then
            if not previous.anchor then previous.anchor=true;current.data=current.data:sub(1,-2)..'1' end
        elseif anchor or (p.at-previous.at>=interval and moved>=(self.options.minimum or 40) and (moved>=(self.options.distance or 160) or p.at-previous.at>=(self.options.seconds or 60))) then write(p) end
        pending=p;lastPoll=p
    end
    return t
end
