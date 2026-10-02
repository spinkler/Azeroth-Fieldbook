local _, ns = ...
local function textFont(base) return ns.TextSize and ns.TextSize:Font(base) or base end
local A=ns.Atlas
local S={MAX_MAPS=256,MAX_CROSSINGS=4096,MAX_AREAS=128,GRID=64,MAX_TRIANGLES=3000,SPACING_YARDS=10,DEFAULT_LABEL_SIZE=4}
S.INTERIOR_YARDS=50
S.MAX_INTERIORS=1024
ns.AtlasSubzones=S
S.WORK_MS=1
local jobs={}
local function noWork() end
-- Search the free rectangles around existing names. Obstacle edges include every
-- place where a free horizontal span can begin, so there is no search-radius cap.
function S.PlaceLabel(placed,width,height,w,h,anchorX,anchorY,checkpoint)
    checkpoint=checkpoint or noWork
    if w>width or h>height then return end
    local minX,maxX=w/2,width-w/2
    local minY,maxY=h/2,height-h/2
    local x=math.max(minX,math.min(maxX,anchorX))
    local y=math.max(minY,math.min(maxY,anchorY))
    local rows={y,minY,maxY}
    for _,p in ipairs(placed) do
        checkpoint()
        local gap=(p.height+h)/2+2
        rows[#rows+1]=p.y-gap;rows[#rows+1]=p.y+gap
    end
    table.sort(rows,function(a,b) return math.abs(a-y)<math.abs(b-y) end)
    local best,bestDistance
    for _,cy in ipairs(rows) do
        checkpoint()
        local dy=(cy-y)^2
        if bestDistance and dy>bestDistance then break end
        if cy>=minY and cy<=maxY then
            local intervals={}
            for _,p in ipairs(placed) do
                checkpoint()
                if math.abs(p.y-cy)<(p.height+h)/2+2-0.000001 then
                    local gap=(p.width+w)/2+5
                    intervals[#intervals+1]={p.x-gap,p.x+gap}
                end
            end
            table.sort(intervals,function(a,b) return a[1]<b[1] end)
            local function consider(left,right)
                if left>right then return end
                local cx=math.max(left,math.min(right,x))
                local distance=(cx-x)^2+dy
                if not bestDistance or distance<bestDistance then
                    best={x=cx,y=cy,width=w,height=h};bestDistance=distance
                end
            end
            local left=minX
            for _,span in ipairs(intervals) do
                checkpoint()
                if span[1]>=left then consider(left,math.min(maxX,span[1])) end
                left=math.max(left,span[2])
                if left>maxX then break end
            end
            consider(left,maxX)
            if bestDistance==0 then break end
        end
    end
    return best,bestDistance
end
-- One shared budget for indexing, geometry and native texture updates. Lua
-- coroutines yield only at our checkpoints, never inside native callbacks.
function S.Queue(run,done,owner)
    if not S.worker then
        S.worker=CreateFrame("Frame");S.worker:Hide()
        S.worker:SetScript("OnUpdate",function() S.Step() end)
    end
    local job={done=done,owner=owner}
    job.thread=coroutine.create(function()
        return run(function(cost)
            job.units=job.units+(cost or 1)
            if job.units>=job.limit or (job.units>=job.checkAt and job.clock and job.clock()>=job.deadline) then
                coroutine.yield()
            end
            if job.units>=job.checkAt then job.checkAt=job.units+16 end
        end)
    end)
    jobs[#jobs+1]=job;S.worker:Show();return job
end
function S.Cancel(job)
    if job then job.thread,job.done,job.owner=nil,nil,nil end
end
function S.Step()
    if ns.InitializationBlocked then return end
    local job=table.remove(jobs,1)
    if job and job.thread then
        if job.owner and A.Read(job.owner.IsVisible,job.owner)==false then
            S.Cancel(job)
        else
            job.clock=type(debugprofilestop)=="function" and debugprofilestop or nil
            job.units,job.checkAt,job.limit=0,16,job.clock and 4096 or 256
            job.deadline=job.clock and job.clock()+S.WORK_MS or 0
            local ok,result=coroutine.resume(job.thread)
            if not ok or coroutine.status(job.thread)=="dead" then
                local done=job.done;S.Cancel(job)
                if done then done(ok,result) end
            else jobs[#jobs+1]=job end
        end
    end
    if #jobs==0 and S.worker then S.worker:Hide() end
end

local function valid(p)
    return type(p)=="table" and p.kind~="interior" and A.Position(p) and A.Text(p.from,160) and A.Text(p.to,160)
        and p.from~=p.to and A.Integer(p.fromX,0,10000) and A.Integer(p.fromY,0,10000)
        and A.Integer(p.at,0,9999999999)
end
local function interior(p)
    return type(p)=="table" and p.kind=="interior" and A.Position(p)
        and A.Text(p.name,160) and A.Integer(p.at,0,9999999999)
end
local function sampleNames(p)
    if p.kind=="interior" then return p.name end
    return p.from,p.to
end
local function extraNames(names,p)
    local first,second=sampleNames(p)
    return (names[first] and 0 or 1)+(second and not names[second] and 1 or 0)
end
local function key(p)
    if p.kind=="interior" then return "interior\t"..p.name.."\t"..math.floor(p.x/25)..":"..math.floor(p.y/25) end
    return p.from.."\t"..p.to.."\t"..math.floor(p.x/25)..":"..math.floor(p.y/25)
end
local function airborne(fn,...)
    if type(fn)~="function" then return false end
    local ok,value=pcall(fn,...)
    -- Do not record while an available flight signal cannot safely be read.
    if not ok or not A.Public(value) then return true end
    return value==true or value==1
end
function S.Attach(j)
    if not j.readOnly then
        j.saved.subzones=type(j.saved.subzones)=="table" and j.saved.subzones or {}
        if j.state.showSubzoneLabels==nil then j.state.showSubzoneLabels=j.state.showSubzones==true end
        if j.state.showSubzonePoints==nil then j.state.showSubzonePoints=j.state.showSubzones==true end
    end
    local store=not j.readOnly and j.saved.subzones or {}
    local s={store=store,revision=0,revisions={},index={}}
    j.subzones=s
    -- Palette IDs are presentation metadata, separate from observed geography.
    -- Version the palette mapping so future palette changes cannot reinterpret IDs.
    function s:RecallColours(id)
        local saved=j.saved.subzoneColours
        local rows=type(saved)=="table" and saved.version==1 and type(saved.maps)=="table" and saved.maps[id]
        if type(rows)~="table" then return end
        local model={areas={}}
        for name,colourID in pairs(rows) do
            if A.Text(name,160) and A.Integer(colourID,1,#S.Palette()) then
                model.areas[name]={colourID=colourID}
            end
        end
        return model
    end
    function s:RememberColours(id,model)
        if j.readOnly or not A.Integer(id,1,999999) then return end
        local saved=j.saved.subzoneColours
        if type(saved)~="table" or saved.version~=1 or type(saved.maps)~="table" then
            saved={version=1,maps={}};j.saved.subzoneColours=saved
        end
        local rows={}
        for _,name in ipairs(model.names) do rows[name]=model.areas[name].colourID end
        saved.maps[id]=rows
    end
    function s:Changed(id)
        self.revision=self.revision+1;self.revisions[id]=(self.revisions[id] or 0)+1
    end
    function s:Revision(id) return self.revisions[id] or 0 end
    function s:Samples(id,checkpoint,crossingsOnly)
        checkpoint=checkpoint or noWork
        local out,names={},{};local count=0;local rows=store[id]
        if type(rows)=="table" then
            for i=1,math.min(#rows,S.MAX_CROSSINGS) do
                checkpoint()
                local p=rows[i]
                if (valid(p) or (not crossingsOnly and interior(p))) and p.mapID==id then
                    local extra=extraNames(names,p)
                    if count+extra<=S.MAX_AREAS then
                        local first,second=sampleNames(p)
                        count=count+extra;names[first]=true;if second then names[second]=true end
                        if p.kind=="interior" then
                            out[#out+1]={kind="interior",mapID=id,x=p.x,y=p.y,name=p.name,at=p.at}
                        else out[#out+1]={mapID=id,x=p.x,y=p.y,fromX=p.fromX,fromY=p.fromY,from=p.from,to=p.to,at=p.at} end
                    end
                end
            end
        end
        return out
    end
    function s:Crossings(id,checkpoint) return self:Samples(id,checkpoint,true) end
    function s:Reset() self.previous=nil end
    local function spatial(index,row,add,allSamples,radius)
        if not index.width then return index.keys[key(row)] end
        local isInterior=row.kind=="interior"
        local grid,spacing
        if allSamples then
            spacing=S.INTERIOR_YARDS;grid=index.sampleGrid
        elseif isInterior then
            spacing=S.INTERIOR_YARDS;grid=index.interiorGrid[row.name]
            if not grid then grid={};index.interiorGrid[row.name]=grid end
        else
            spacing=S.SPACING_YARDS
            local from,to=row.from,row.to;if from>to then from,to=to,from end
            local borders=index.borders[from]
            if not borders then borders={};index.borders[from]=borders end
            grid=borders[to];if not grid then grid={};borders[to]=grid end
        end
        local x,y=row.x*index.width/10000,row.y*index.height/10000
        local cx,cy=math.floor(x/spacing),math.floor(y/spacing)
        if add then
            local cell=cx..":"..cy;local bucket=grid[cell]
            if not bucket then bucket={};grid[cell]=bucket end
            bucket[#bucket+1]={x=x,y=y};return
        end
        for dx=-1,1 do for dy=-1,1 do
            local bucket=grid[(cx+dx)..":"..(cy+dy)]
            if bucket then for _,p in ipairs(bucket) do
                local d=(x-p.x)^2+(y-p.y)^2
                local limit=radius or spacing
                if d<limit^2 or ((allSamples or not isInterior) and d==limit^2) then return true end
            end end
        end end
    end
    local function remember(index,row)
        local extra=extraNames(index.names,row)
        if index.count+extra>S.MAX_AREAS then return end
        index.keys[key(row)]=true
        local first,second=sampleNames(row)
        if not index.names[first] then index.names[first]=true;index.count=index.count+1 end
        if second and not index.names[second] then index.names[second]=true;index.count=index.count+1 end
        if row.kind=="interior" then index.interiors=index.interiors+1 end
        if index.width then
            spatial(index,row,true)
            spatial(index,row,true,true)
        end
    end
    local function append(row,index)
        local rows=store[row.mapID]
        local extra=extraNames(index.names,row)
        if row.kind=="interior" and index.interiors>=S.MAX_INTERIORS then return end
        if #rows>=S.MAX_CROSSINGS or index.count+extra>S.MAX_AREAS or (row.manual~=true and spatial(index,row)) then return end
        -- Interior spacing is map-wide; crossings retain their own border-pair rule.
        if row.kind=="interior" and spatial(index,row,false,true,row.manual==true and 15 or nil) then return end
        rows[#rows+1]=row;remember(index,row);s:Changed(row.mapID);return true
    end
    function s:Index(id,deferred)
        local index=self.index[id]
        if index then return index end
        index={keys={},names={},count=0,pending={}};self.index[id]=index
        if C_Map and type(C_Map.GetMapWorldSize)=="function" then
            local ok,w,h=pcall(C_Map.GetMapWorldSize,id)
            if ok and A.Number(w,1,100000) and A.Number(h,1,100000) then index.width,index.height=w,h end
        end
        local rows=store[id];local count=type(rows)=="table" and math.min(#rows,S.MAX_CROSSINGS) or 0
        local function build(checkpoint)
            -- A logout flush may restart a partially drained job. Re-index the
            -- current store, including any pending rows already committed.
            rows=store[id];count=type(rows)=="table" and math.min(#rows,S.MAX_CROSSINGS) or 0
            index.keys,index.names,index.borders,index.count={},{},{},0
            index.interiorGrid,index.interiors,index.sampleGrid={},0,{}
            local kept={};local removed=0
            local compact=not j.readOnly and index.width and type(rows)=="table" and #rows<=S.MAX_CROSSINGS
            local sparse=false
            for i=1,count do
                checkpoint()
                local row=rows[i]
                if row==nil then sparse=true end
                if (valid(row) or interior(row)) and row.mapID==id then
                    if compact and row.manual~=true and spatial(index,row) then removed=removed+1
                    else remember(index,row);kept[#kept+1]=row end
                else kept[#kept+1]=row end
            end
            if removed>0 and not sparse then
                -- Retain non-sample metadata and malformed entries; only remove
                -- validated redundant border/interior observations.
                for k,v in pairs(rows) do checkpoint();if not A.Integer(k,1,count) then kept[k]=v end end
                store[id]=kept;self:Changed(id)
            else removed=0 end
            local changed=removed>0
            for _,row in ipairs(index.pending) do checkpoint();if append(row,index) then changed=true end end
            index.pending={};index.ready=true;return changed
        end
        if deferred and count>0 then
            index.build=build
            index.job=S.Queue(build,function(ok,changed)
                index.job=nil
                if ok then index.build=nil else index.error=tostring(changed) end
                if ok and changed and self.onChange then self.onChange(id) end
            end)
        else build(noWork) end
        return index
    end
    function s:Flush()
        -- PLAYER_LOGOUT is the persistence boundary; do not lose crossings
        -- captured while a populated map's spatial index was still warming.
        for _,index in pairs(self.index) do
            if index.build then S.Cancel(index.job);index.build(noWork);index.build,index.job=nil,nil end
        end
    end
    local function record(row,index)
        local rows=store[row.mapID]
        if rows~=nil and type(rows)~="table" then return end
        if not rows then
            if A.Count(store)>=S.MAX_MAPS then return end
            rows={};store[row.mapID]=rows
        end
        if not index.ready then
            if #index.pending<S.MAX_CROSSINGS then index.pending[#index.pending+1]=row end
            return
        end
        return append(row,index)
    end
    local function observeInterior(id,name,x,y,index)
        -- Actual map dimensions are required for yard-spaced interior evidence.
        -- Existing crossing capture keeps its fallback on unsupported maps.
        if not index.width then return end
        return record({kind="interior",mapID=id,name=name,x=x,y=y,at=A.Now()},index)
    end
    function s:RecordPoint()
        if j.readOnly then return false,"Atlas recording is unavailable." end
        local name=A.Read(GetSubZoneText)
        if name=="" then name=A.Read(GetRealZoneText) end
        local id=A.Read(C_Map and C_Map.GetBestMapForUnit,"player")
        local p=A.Integer(id,1,2147483647) and A.Read(C_Map and C_Map.GetPlayerMapPosition,id,"player")
        if not A.Text(name,160) or type(p)~="table" or not A.Number(p.x,0,1) or not A.Number(p.y,0,1)
            or (p.x==0 and p.y==0) then return false,"Current Atlas position is unavailable." end
        local index=self:Index(id,true)
        if not index.ready then return false,"Atlas points are still loading; try again shortly." end
        if not index.width then return false,"Map dimensions are unavailable; cannot verify 15-yard spacing." end
        local row={kind="interior",manual=true,mapID=id,name=name,
            x=math.floor(p.x*10000+0.5),y=math.floor(p.y*10000+0.5),at=A.Now()}
        if spatial(index,row,false,true,15) then return false,"An Atlas point is already within 15 yards." end
        if not record(row,index) then return false,"Atlas point could not be recorded; the map may be full." end
        if self.onChange then self.onChange(id) end
        return true,"Traveller’s Atlas point recorded: "..A.Safe(name).."."
    end
    function s:Observe(deferred)
        if j.readOnly or j.state.automaticMapping==false then self:Reset();return end
        if airborne(UnitOnTaxi,"player") or airborne(IsFlying) then self:Reset();return end
        -- Read the raw labels: unavailable/secret values must not become an
        -- invented sub-zone called "Unavailable". Blank sub-zones are the zone.
        local name=A.Read(GetSubZoneText)
        if name=="" then name=A.Read(GetRealZoneText) end
        if not A.Text(name,160) then self:Reset();return end
        -- Offshore water can retain a coastal map ID. Check the current area
        -- labels rather than excluding that whole coastal map from surveys.
        if name=="The Great Sea" or A.Read(GetRealZoneText)=="The Great Sea" or A.Read(GetZoneText)=="The Great Sea" then
            self:Reset();return
        end
        -- World dimensions are cached once per map index; proximity queries
        -- use the cached spatial grids, including inside cities.
        local id=A.Read(C_Map and C_Map.GetBestMapForUnit,"player")
        local position=A.Integer(id,1,2147483647) and A.Read(C_Map and C_Map.GetPlayerMapPosition,id,"player")
        local clock=A.Read(GetTime) or A.Now()
        if type(position)~="table" or not A.Number(position.x,0,1) or not A.Number(position.y,0,1)
            or (position.x==0 and position.y==0) or not A.Number(clock,0,1e12) then self:Reset();return end
        local x,y=math.floor(position.x*10000+0.5),math.floor(position.y*10000+0.5)
        local old=self.previous
        local index=self:Index(id,deferred)
        if not old then
            self.previous={mapID=id,x=x,y=y,name=name,clock=clock}
            return observeInterior(id,name,x,y,index)
        end
        local oldID,oldName,oldX,oldY,oldClock=old.mapID,old.name,old.x,old.y,old.clock
        old.mapID,old.name,old.x,old.y,old.clock=id,name,x,y,clock
        local gap=clock-oldClock
        -- Loading screens, stale samples and large jumps are not boundaries.
        local crossed
        if oldID==id and oldName~=name and gap>=0 and gap<=2 and (x-oldX)^2+(y-oldY)^2<=300^2 then
            crossed=record({mapID=id,x=x,y=y,fromX=oldX,fromY=oldY,from=oldName,to=name,at=A.Now()},index)
        end
        local sampled=observeInterior(id,name,x,y,index)
        return crossed or sampled
    end
    return s
end

local palette
local function linear(v) return v<=0.04045 and v/12.92 or ((v+0.055)/1.055)^2.4 end
local function perceptual(rgb)
    -- Oklab measures differences in perceived lightness and hue. Matrices from
    -- Bjorn Ottosson's public-domain reference: https://bottosson.github.io/posts/oklab/
    local r,g,b=linear(rgb[1]),linear(rgb[2]),linear(rgb[3])
    local l=(0.4122214708*r+0.5363325363*g+0.0514459929*b)^(1/3)
    local m=(0.2119034982*r+0.6806995451*g+0.1073969566*b)^(1/3)
    local s=(0.0883024619*r+0.2817188376*g+0.6299787005*b)^(1/3)
    return {0.2104542553*l+0.7936177850*m-0.0040720468*s,
        1.9779984951*l-2.4285922050*m+0.4505937099*s,
        0.0259040371*l+0.7827717662*m-0.8086757660*s}
end
function S.Palette(checkpoint)
    if palette then return palette end
    checkpoint=checkpoint or noWork
    local candidates={{0.05,0.9,1}}
    candidates[1].lab=perceptual(candidates[1])
    for hue=0,47 do
        local h=hue/8;local x=1-math.abs(h%2-1)
        local sectors={{1,x,0},{x,1,0},{0,1,x},{0,x,1},{x,0,1},{1,0,x}}
        local rgb=sectors[math.floor(h)+1]
        for _,saturation in ipairs({0.5,0.75,1}) do
            for _,value in ipairs({0.7,0.85,1}) do
                checkpoint(8)
                local c={}
                for i=1,3 do c[i]=value*(1-saturation+saturation*rgb[i]) end
                c.lab=perceptual(c)
                -- Exclude dark/muddy candidates that disappear into map art.
                if c.lab[1]>=0.60 and c.lab[2]^2+c.lab[3]^2>=0.09^2 then candidates[#candidates+1]=c end
            end
        end
    end
    palette=candidates;return palette
end
local function colourDistance(a,b)
    return (a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2
end
local function cross(a,b,c) return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x) end
-- Cooperative merge sorting avoids a long, non-yielding table.sort on a
-- populated zone. KD subranges share one scratch array instead of copying trees.
local function sortRange(points,lo,hi,axis,checkpoint,scratch)
    local size=1
    local function less(a,b)
        if axis then return a[axis]<b[axis] end
        return a.x<b.x or (a.x==b.x and a.y<b.y)
    end
    while size<=hi-lo do
        for start=lo,hi,size*2 do
            local middle,finish=math.min(start+size-1,hi),math.min(start+size*2-1,hi)
            local i,k=start,middle+1
            for target=start,finish do
                checkpoint()
                if i<=middle and (k>finish or less(points[i],points[k])) then scratch[target]=points[i];i=i+1
                else scratch[target]=points[k];k=k+1 end
            end
            for target=start,finish do checkpoint();points[target]=scratch[target] end
        end
        size=size*2
    end
end
local function hull(points,checkpoint)
    sortRange(points,1,#points,nil,checkpoint,{})
    local unique={}
    for _,p in ipairs(points) do
        checkpoint()
        local last=unique[#unique]
        if not last or p.x~=last.x or p.y~=last.y then unique[#unique+1]=p end
    end
    if #unique<3 then return unique end
    local out={}
    for _,p in ipairs(unique) do
        checkpoint()
        while #out>=2 and cross(out[#out-1],out[#out],p)<=0 do table.remove(out) end
        out[#out+1]=p
    end
    local lower=#out
    for i=#unique-1,1,-1 do
        checkpoint()
        local p=unique[i]
        while #out>lower and cross(out[#out-1],out[#out],p)<=0 do table.remove(out) end
        out[#out+1]=p
    end
    table.remove(out);return out
end
local function inside(points,x,y,checkpoint)
    if #points<3 then return false end
    for i,a in ipairs(points) do
        if i%32==0 then checkpoint(32) end
        local b=points[i%#points+1]
        if (b.x-a.x)*(y-a.y)-(b.y-a.y)*(x-a.x)<0 then return false end
    end
    return true
end
-- Preserve the original convex hull above for an exact, selectable rollback.
-- Peel empty triangles off long edges. Each accepted detour uses a real sample,
-- shortens both replacement edges, and cannot remove any observed location.
local function tracedHull(points,checkpoint)
    local outline=hull(points,checkpoint)
    if #outline<3 then return outline end
    local used,unique={},{}
    -- hull sorted the input already; reuse point identities, avoiding string
    -- allocation for every candidate on every edge of a dense survey.
    for _,p in ipairs(points) do
        checkpoint()
        local last=unique[#unique]
        if not last or p.x~=last.x or p.y~=last.y then unique[#unique+1]=p end
    end
    points=unique
    for _,p in ipairs(outline) do used[p]=true end
    local function onSegment(a,b,p)
        return math.abs(cross(a,b,p))<0.000001 and p.x>=math.min(a.x,b.x) and p.x<=math.max(a.x,b.x)
            and p.y>=math.min(a.y,b.y) and p.y<=math.max(a.y,b.y)
    end
    local function intersects(a,b,c,d)
        return (cross(a,b,c)*cross(a,b,d)<0 and cross(c,d,a)*cross(c,d,b)<0)
            or (c~=a and c~=b and onSegment(a,b,c)) or (d~=a and d~=b and onSegment(a,b,d))
            or (a~=c and a~=d and onSegment(c,d,a)) or (b~=c and b~=d and onSegment(c,d,b))
    end
    local i=1
    while i<=#outline do
        checkpoint()
        local a,b=outline[i],outline[i%#outline+1]
        local dx,dy=b.x-a.x,b.y-a.y
        local length=dx*dx+dy*dy
        local best,depth
        -- Below 2% of the map, leave closely sampled edges alone.
        if length>200^2 then for _,p in ipairs(points) do
            checkpoint()
            if not used[p] then
                local side=cross(a,b,p)
                local projection=((p.x-a.x)*dx+(p.y-a.y)*dy)/length
                local ap=(p.x-a.x)^2+(p.y-a.y)^2
                local bp=(p.x-b.x)^2+(p.y-b.y)^2
                if side>0.000001 and projection>0.1 and projection<0.9
                    and ap<length*0.81 and bp<length*0.81 and (not depth or side<depth) then
                    best,depth=p,side
                end
            end
        end end
        local safe=best~=nil
        if best then
            for _,p in ipairs(points) do
                checkpoint()
                if p~=a and p~=b and p~=best
                    and cross(a,b,p)>=0 and cross(b,best,p)>0 and cross(best,a,p)>0 then
                    safe=false;break
                end
            end
            if safe then for n,c in ipairs(outline) do
                checkpoint()
                local d=outline[n%#outline+1]
                local touching=onSegment(c,d,best)
                if touching or intersects(a,best,c,d) or intersects(best,b,c,d) then safe=false;break end
            end end
        end
        if safe then table.insert(outline,i+1,best);used[best]=true
        else i=i+1 end
    end
    return outline
end
local function traceBuckets(points,checkpoint)
    local buckets={}
    for i,a in ipairs(points) do
        local b=points[i%#points+1];local edge={a,b}
        for row=math.floor(math.min(a.y,b.y)/100),math.floor(math.max(a.y,b.y)/100) do
            checkpoint()
            if not buckets[row] then buckets[row]={} end
            buckets[row][#buckets[row]+1]=edge
        end
    end
    return buckets
end
local function insideTrace(points,x,y,checkpoint,buckets)
    if #points<3 then return false end
    local hit=false
    -- Only edges crossing this horizontal band can affect the ray test.
    -- Keep hover and contour refinement cheap even for detailed outlines.
    for i,edge in ipairs(buckets[math.floor(y/100)] or {}) do
        if i%32==0 then checkpoint(32) end
        local a,b=edge[1],edge[2]
        local side=(b.x-a.x)*(y-a.y)-(b.y-a.y)*(x-a.x)
        if math.abs(side)<0.000001 and x>=math.min(a.x,b.x) and x<=math.max(a.x,b.x)
            and y>=math.min(a.y,b.y) and y<=math.max(a.y,b.y) then return true end
        if (a.y>y)~=(b.y>y) and x<(b.x-a.x)*(y-a.y)/(b.y-a.y)+a.x then hit=not hit end
    end
    return hit
end
function S.FillMethod(journal) return journal.state.subzoneFillMethod=="convex" and "convex" or "traced" end
local function preserveTrialPoints(journal,done)
    if S.FillMethod(journal)=="convex" then return false end
    if done then done(0,"Points preserved: cleanup is paused while traced sub-zone fill is being tested.") end
    return true
end
-- Test whether removing each interior anchor can let a competing area take
-- ownership anywhere in their overlapping hulls; keep all perimeter evidence.
local function cleanInterior(journal,id,done,progress,batch)
    local survey=journal.subzones
    if journal.readOnly or not A.Integer(id,1,2147483647) or (survey.cleaning and survey.cleaning~=batch) then return false end
    survey.cleaning=batch or true
    if progress then progress("Starting cleanup on map "..id.."; preparing saved samples.") end
    S.Queue(function(checkpoint)
        local index=survey:Index(id,true)
        while not index.ready do
            if index.error then error(index.error) end
            checkpoint(4096)
        end
        local source=survey.store[id]
        local revision=survey:Revision(id)
        if type(source)~="table" or not A.Array(source,S.MAX_CROSSINGS) then return {removed=0,reason="No supported sample list to clean."} end
        if progress then progress("Checking "..#source.." saved samples; cross-over points will be kept.") end
        local areas={}
        local function area(name)
            if not areas[name] then areas[name]={points={},anchors={}} end
            return areas[name]
        end
        for _,p in ipairs(survey:Samples(id,checkpoint)) do
            checkpoint()
            if p.kind=="interior" then
                local a=area(p.name);a.points[#a.points+1]=p;a.anchors[#a.anchors+1]=p
            else
                local a,b=area(p.from),area(p.to)
                local mid={x=(p.fromX+p.x)/2,y=(p.fromY+p.y)/2}
                a.points[#a.points+1]=mid;b.points[#b.points+1]=mid
                a.anchors[#a.anchors+1]={x=p.fromX,y=p.fromY};b.anchors[#b.anchors+1]=p
            end
        end
        for _,a in pairs(areas) do a.hull=hull(a.points,checkpoint) end
        local function clip(polygon,nx,ny,limit)
            local out={}
            for i,v in ipairs(polygon) do
                checkpoint()
                local w=polygon[i%#polygon+1]
                local dv,dw=nx*v.x+ny*v.y-limit,nx*w.x+ny*w.y-limit
                if dv<=0 then out[#out+1]=v end
                if (dv<0 and dw>0) or (dv>0 and dw<0) then
                    local t=dv/(dv-dw);out[#out+1]={x=v.x+t*(w.x-v.x),y=v.y+t*(w.y-v.y)}
                end
            end
            return out
        end
        local function closer(polygon,p,q)
            return clip(polygon,2*(q.x-p.x),2*(q.y-p.y),q.x*q.x+q.y*q.y-p.x*p.x-p.y*p.y)
        end
        local function redundant(p)
            local a=areas[p.name]
            if not a or #a.hull<3 then return false,"edges" end
            for i,v in ipairs(a.hull) do
                checkpoint()
                if cross(v,a.hull[i%#a.hull+1],p)<=0.000001 then return false,"edges" end
            end
            local candidate
            for i,q in ipairs(a.anchors) do
                if q.kind=="interior" and q.x==p.x and q.y==p.y then candidate=i;break end
            end
            if not candidate then return false,"edges" end
            for _,other in pairs(areas) do
                if other~=a and #other.hull>=3 then
                    local overlap=other.hull
                    for i,v in ipairs(a.hull) do
                        local w=a.hull[i%#a.hull+1]
                        overlap=clip(overlap,w.y-v.y,v.x-w.x,(w.y-v.y)*v.x+(v.x-w.x)*v.y)
                        if #overlap==0 then break end
                    end
                    if #overlap>0 then for _,rival in ipairs(other.anchors) do
                        checkpoint()
                        -- Find places this point wins now but a rival could win
                        -- after its removal, against every remaining own anchor.
                        local polygon=closer(overlap,p,rival)
                        for i,q in ipairs(a.anchors) do
                            if #polygon==0 then break end
                            if i~=candidate then polygon=closer(polygon,rival,q) end
                        end
                        if #polygon>0 then return false,"boundaries" end
                    end end
                end
            end
            table.remove(a.anchors,candidate)
            return true
        end
        local kept,removed={},0
        local counts={edges=0,boundaries=0,crossings=0,other=0}
        for i,p in ipairs(source) do
            checkpoint()
            local remove,reason
            if interior(p) and p.mapID==id then remove,reason=redundant(p)
            else reason=valid(p) and "crossings" or "other" end
            if remove then removed=removed+1
            else kept[#kept+1]=p;counts[reason]=counts[reason]+1 end
            if progress and i%64==0 then progress("Checked "..i.."/"..#source.." samples; "..removed.." removable so far.") end
        end
        return {source=source,revision=revision,kept=kept,removed=removed,counts=counts}
    end,function(ok,result)
        if not batch then survey.cleaning=nil end
        if not ok then if done then done(nil,"Cleanup could not complete; no samples were removed.") end;return end
        if S.FillMethod(journal)~="convex" then
            if done then done(0,"Points preserved: traced fill was enabled during cleanup.") end
            return
        end
        if result.removed>0 then
            if survey.store[id]~=result.source or survey:Revision(id)~=result.revision then
                if done then done(nil,"New samples arrived during cleanup; try again while stationary.") end;return
            end
            survey.store[id]=result.kept;survey.index[id]=nil;survey:Changed(id)
            if survey.onChange then survey.onChange(id) end
        end
        if progress then
            local c=result.counts
            progress(result.reason or ("Cleanup complete: removed "..result.removed.." interior points; kept "..c.edges..
                " edge/insufficient-boundary points, "..c.boundaries.." overlap-boundary points, "..c.crossings..
                " cross-over points and "..c.other.." other records."))
        end
        if done then done(result.removed) end
    end)
    return true
end

function S.CleanInterior(journal,id,done,progress)
    if journal.readOnly then return false end
    if preserveTrialPoints(journal,done) then return false end
    return cleanInterior(journal,id,done,progress)
end

function S.CleanAllInterior(journal,done,progress)
    if journal.readOnly then return false end
    if preserveTrialPoints(journal,done) then return false end
    local survey=journal.subzones
    if journal.readOnly or survey.cleaning then return false end
    local maps={}
    for id in pairs(survey.store) do
        if A.Integer(id,1,2147483647) then maps[#maps+1]=id end
    end
    table.sort(maps)
    if #maps==0 then
        if done then done(0,"No saved Atlas maps to clean.") end
        return false
    end
    -- Keep one lock across the batch. Each map gets the same budgeted cleanup
    -- and revision checks as a normal click; never build all maps at once.
    local batch={};survey.cleaning=batch
    local index,total,skipped=0,0,0
    local function nextMap()
        index=index+1
        if index>#maps then
            survey.cleaning=nil
            local message="All-map cleanup complete: removed "..total.." redundant interior points across "..#maps..(#maps==1 and " map." or " maps.")
            if skipped>0 then message=message.." "..skipped..(skipped==1 and " map" or " maps").." could not be cleaned; try again while stationary." end
            if done then done(total,message) end
            return
        end
        local id=maps[index]
        local function report(message)
            if progress then progress("Map "..index.."/"..#maps.." ("..id.."): "..message) end
        end
        local started=cleanInterior(journal,id,function(count,message)
            if count==nil then skipped=skipped+1;report(message)
            else total=total+count end
            nextMap()
        end,report,batch)
        if not started then
            survey.cleaning=nil
            if done then done(total,"All-map cleanup stopped; remaining maps were not changed.") end
        end
    end
    nextMap()
    return true
end

local function tree(points,depth,lo,hi,checkpoint,scratch)
    if lo>hi then return end
    local axis=depth%2==0 and "x" or "y"
    sortRange(points,lo,hi,axis,checkpoint,scratch)
    local middle=math.floor((lo+hi)/2)
    return {point=points[middle],axis=axis,
        left=tree(points,depth+1,lo,middle-1,checkpoint,scratch),
        right=tree(points,depth+1,middle+1,hi,checkpoint,scratch)}
end
local function nearest(node,x,y,best)
    if not node then return best end
    local q=node.point;local d=(x-q.x)^2+(y-q.y)^2
    if d<best then best=d end
    local delta=node.axis=="x" and x-q.x or y-q.y
    local near,far=node.left,node.right;if delta>0 then near,far=far,near end
    best=nearest(near,x,y,best)
    if delta*delta<best then best=nearest(far,x,y,best) end
    return best
end
function S.Build(rows,checkpoint,preferredResolution,previousModel,method)
    checkpoint=checkpoint or noWork
    local checking=checkpoint
    method=method=="convex" and "convex" or "traced"
    local contains=method=="convex" and inside or insideTrace
    local outline=method=="convex" and hull or tracedHull
    local model={areas={},names={},rows=rows,strips={},triangles={},method=method}
    local function area(name)
        if not model.areas[name] then
            model.names[#model.names+1]=name
            model.areas[name]={name=name,points={},anchors={},neighbours={}}
        end
        return model.areas[name]
    end
    for _,p in ipairs(rows) do
        checkpoint()
        if p.kind=="interior" then
            local a=area(p.name);local point={x=p.x,y=p.y}
            a.points[#a.points+1]=point;a.anchors[#a.anchors+1]=point
        else
            local a,b=area(p.from),area(p.to)
            local midpoint={x=(p.fromX+p.x)/2,y=(p.fromY+p.y)/2}
            a.points[#a.points+1]=midpoint;b.points[#b.points+1]=midpoint
            a.anchors[#a.anchors+1]={x=p.fromX,y=p.fromY}
            b.anchors[#b.anchors+1]={x=p.x,y=p.y}
            a.neighbours[b.name]=true;b.neighbours[a.name]=true
        end
    end
    table.sort(model.names)
    local active={};local minX,minY,maxX,maxY=10000,10000,0,0
    for _,name in ipairs(model.names) do
        local a=model.areas[name];a.hull=outline(a.points,checkpoint);a.points=nil
        if method=="traced" then a.traceBuckets=traceBuckets(a.hull,checkpoint) end
        a.x,a.y=0,0
        for _,p in ipairs(a.anchors) do checkpoint();a.x=a.x+p.x;a.y=a.y+p.y end
        a.x,a.y=a.x/#a.anchors,a.y/#a.anchors
        if #a.hull>=3 then
            a.minX,a.minY,a.maxX,a.maxY=10000,10000,0,0
            for _,p in ipairs(a.hull) do
                checkpoint()
                a.minX,a.minY=math.min(a.minX,p.x),math.min(a.minY,p.y)
                a.maxX,a.maxY=math.max(a.maxX,p.x),math.max(a.maxY,p.y)
            end
            minX,minY=math.min(minX,a.minX),math.min(minY,a.minY)
            maxX,maxY=math.max(maxX,a.maxX),math.max(maxY,a.maxY)
            active[#active+1]=a
        end
    end
    for _,a in ipairs(active) do
        if #active>1 then a.tree=tree(a.anchors,0,1,#a.anchors,checkpoint,{}) end
    end
    for _,a in pairs(model.areas) do a.anchors=nil end
    -- Broad-phase bounds reject unseen space without testing hulls or allocating
    -- a point table. A sole enclosing area needs no nearest-neighbour query.
    function model:At(x,y)
        local best,distance
        for _,a in ipairs(active) do
            if x>=a.minX and x<=a.maxX and y>=a.minY and y<=a.maxY and contains(a.hull,x,y,checking,a.traceBuckets) then
                if #active==1 then return a end
                local d=nearest(a.tree,x,y,distance or math.huge)
                if not distance or d<distance then best,distance=a,d end
            end
        end
        return best
    end
    local step
    local edges={}
    local function vertex(x,y) checkpoint();return {x=x,y=y,area=model:At(x,y)} end
    local function neighbours(a,b)
        if a and b and a~=b then a.neighbours[b.name]=true;b.neighbours[a.name]=true end
    end
    local function triangle(a,b,c,area)
        if area and math.abs(cross(a,b,c))>0.000001 then
            model.triangles[#model.triangles+1]={a,b,c,area=area}
        end
    end
    -- Canonical endpoint order gives adjoining triangles exactly the same edge.
    -- Binary refinement locates the classification change within 1/256 cell.
    local function boundary(a,b)
        if a.x>b.x or (a.x==b.x and a.y>b.y) then a,b=b,a end
        local cache=edges[a]
        if not cache then cache={};edges[a]=cache end
        if cache[b] then return cache[b] end
        local ax,ay,bx,by=a.x,a.y,b.x,b.y
        for _=1,8 do
            checkpoint()
            local x,y=(ax+bx)/2,(ay+by)/2
            if model:At(x,y)==a.area then ax,ay=x,y else bx,by=x,y end
        end
        local point={x=(ax+bx)/2,y=(ay+by)/2};cache[b]=point;return point
    end
    local function contour(a,b,c)
        neighbours(a.area,b.area);neighbours(b.area,c.area);neighbours(c.area,a.area)
        if a.area==b.area and b.area==c.area then triangle(a,b,c,a.area);return end
        -- With two labels, split the odd corner from the other two. The
        -- resulting triangle and quadrilateral partition the cell exactly.
        local odd,p,q
        if a.area==b.area then odd,p,q=c,a,b
        elseif b.area==c.area then odd,p,q=a,b,c
        elseif c.area==a.area then odd,p,q=b,c,a end
        if odd then
            local u,v=boundary(odd,p),boundary(odd,q)
            triangle(odd,u,v,odd.area);triangle(p,q,v,p.area);triangle(p,v,u,p.area)
        else
            local ab,bc,ca=boundary(a,b),boundary(b,c),boundary(c,a)
            local centre={x=(a.x+b.x+c.x)/3,y=(a.y+b.y+c.y)/3}
            triangle(a,ab,centre,a.area);triangle(a,centre,ca,a.area)
            triangle(b,bc,centre,b.area);triangle(b,centre,ab,b.area)
            triangle(c,ca,centre,c.area);triangle(c,centre,bc,c.area)
        end
    end
    local function raster(resolution)
        step=10000/resolution;edges={};model.strips={};model.triangles={};model.grid=resolution
        if #active==0 then return true end
        local left=math.max(0,math.floor(minX/step))
        local right=math.min(resolution,math.ceil(maxX/step))
        local top=math.max(0,math.floor(minY/step))
        local bottom=math.min(resolution,math.ceil(maxY/step))
        local previous={}
        for x=left,right do previous[x]=vertex(x*step,top*step) end
        for y=top+1,bottom do
            local current={}
            for x=left,right do current[x]=vertex(x*step,y*step) end
            for x=left+1,right do
                local centre=vertex((x-0.5)*step,(y-0.5)*step)
                local a=centre.area
                local tl,tr,br,bl=previous[x-1],previous[x],current[x],current[x-1]
                if a==tl.area and a==tr.area and a==br.area and a==bl.area then
                    if a then
                        local last=model.strips[#model.strips]
                        if last and last.area==a and last.y==y-1 and last.x+last.width==x-1 then last.width=last.width+1
                        else model.strips[#model.strips+1]={x=x-1,y=y-1,width=1,area=a} end
                    end
                else
                    contour(centre,tl,tr);contour(centre,tr,br)
                    contour(centre,br,bl);contour(centre,bl,tl)
                end
                if #model.triangles>S.MAX_TRIANGLES then return false end
            end
            previous=current
        end
        return true
    end
    -- Dense, contradictory evidence can create many tiny islands. Bound native
    -- texture allocation while preserving vector (not stair-stepped) edges.
    local resolution=A.Integer(preferredResolution,8,S.GRID) and preferredResolution or S.GRID
    while not raster(resolution) do resolution=math.max(8,resolution/2) end
    local candidates=#model.names>0 and S.Palette(checkpoint) or {}
    local used,distances,colourOrder,degrees={},{},{},{}
    for _,name in ipairs(model.names) do
        colourOrder[#colourOrder+1]=name;degrees[name]=0
        for _ in pairs(model.areas[name].neighbours) do checkpoint();degrees[name]=degrees[name]+1 end
    end
    -- Highly connected areas get first choice. Name ties keep cold builds
    -- deterministic; a live update retains every existing area's colour.
    table.sort(colourOrder,function(a,b)
        if degrees[a]~=degrees[b] then return degrees[a]>degrees[b] end
        return a<b
    end)
    local function assign(a,id)
        used[id]=true;a.colourID=id;a.colour=candidates[id]
        for i,candidate in ipairs(candidates) do
            checkpoint()
            if not used[i] then
                local d=colourDistance(candidate.lab,a.colour.lab)
                distances[i]=math.min(distances[i] or math.huge,d)
            end
        end
    end
    for _,name in ipairs(colourOrder) do
        local old=previousModel and previousModel.areas[name]
        if old and A.Integer(old.colourID,1,#candidates) and not used[old.colourID] then
            assign(model.areas[name],old.colourID)
        end
    end
    for _,name in ipairs(colourOrder) do
        local a=model.areas[name]
        if not a.colourID then
            local best,score
            for i in ipairs(candidates) do
                checkpoint()
                local d=distances[i] or math.huge
                if not used[i] and (not best or d>score) then best,score=i,d end
            end
            -- Maximise distance to the closest assigned colour, so a candidate
            -- cannot win by contrasting with most areas but matching one.
            -- The bright candidate pool exceeds the 128-area storage limit.
            assign(a,best)
        end
    end
    for _,strip in ipairs(model.strips) do
        checkpoint()
        local a=strip.area
        a.hasFill=true
        if not a.labelWidth or strip.width>a.labelWidth then
            a.labelWidth=strip.width;a.labelX=(strip.x+strip.width/2)*step;a.labelY=(strip.y+0.5)*step
        end
    end
    for _,triangle in ipairs(model.triangles) do checkpoint();triangle.area.hasFill=true end
    model.covered={}
    for i,p in ipairs(rows) do
        checkpoint()
        -- Every crossing supplies boundary evidence to both named areas. Once
        -- either area has rendered shading, its sample no longer needs a dot.
        local first,second=sampleNames(p)
        model.covered[i]=model.areas[first].hasFill or (second and model.areas[second].hasFill) or false
    end
    checking=noWork -- Hover queries must never resume the completed build job.
    return model
end

function S.Track(j,onChange)
    local s=j.subzones;local observer=CreateFrame("Frame");local elapsed=0;local away=false
    s.onChange=onChange
    observer:SetScript("OnEvent",function(_,event)
        if ns.InitializationBlocked then return end
        if event=="PLAYER_LOGOUT" then s:Flush();return end
        if event=="PLAYER_LEAVING_WORLD" then away=true;s:Reset();return end
        if event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then away=false;s:Reset() end
        if not away and s:Observe(true) and onChange then onChange() end
    end)
    for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","PLAYER_LOGOUT","ZONE_CHANGED","ZONE_CHANGED_INDOORS","ZONE_CHANGED_NEW_AREA"}) do
        pcall(observer.RegisterEvent,observer,event)
    end
    observer:SetScript("OnUpdate",function(_,dt)
        if ns.InitializationBlocked then return end
        elapsed=elapsed+dt
        if elapsed<0.25 then return end
        elapsed=0
        if not away and s:Observe(true) and onChange then onChange() end
    end)
    return observer
end

function S.InstallMap(map,journal,cursorPoint)
    local function buffer()
        local frame=CreateFrame("Frame",nil,map.canvas)
        frame:SetAllPoints(map.canvas);frame:SetFrameLevel(map.canvas:GetFrameLevel());frame:EnableMouse(false);frame:Hide()
        return {frame=frame,strips={},triangles={},dots={},labels={}}
    end
    local front,back=buffer(),buffer()
    map.subzoneBuffers={front,back}
    local cacheID,cacheRevision,model,width,height
    local lastRegions,lastLabels,lastPoints,lastSize,lastHidden
    local failed
    local function expose()
        map.subzoneTextures, map.subzoneTriangles=front.strips,front.triangles
        map.subzoneDots,map.subzoneLabels=front.dots,front.labels
    end
    expose()
    local dotZoom
    function map:UpdateSubzoneDotSize()
        if dotZoom==self.zoom then return end
        dotZoom=self.zoom
        for _,pool in ipairs(self.subzoneBuffers) do
            for _,dot in ipairs(pool.dots) do dot:SetSize(3/self.zoom,3/self.zoom) end
        end
    end
    function map:CancelSubzones()
        S.Cancel(self.subzonePending);self.subzonePending=nil;back.frame:Hide()
    end
    local function hide(pool,checkpoint)
        for _,v in ipairs(pool) do checkpoint(2);v:Hide() end
    end
    local function paint(self,target,model,width,height,regions,names,points,size,hidden,checkpoint)
        local strips,triangles,dots,labels=target.strips,target.triangles,target.dots,target.labels
        local geometryChanged=target.model~=model or target.width~=width or target.height~=height
        -- A cancelled paint may have changed some widgets already. Only a fully
        -- completed buffer may reuse its geometry/visibility on the next request.
        target.model=nil
        if geometryChanged or target.regions~=regions or target.hidden~=hidden then
            hide(strips,checkpoint);hide(triangles,checkpoint)
            for i,row in ipairs(regions and model.strips or {}) do
                checkpoint(8)
                local t=strips[i] or target.frame:CreateTexture(nil,"ARTWORK",nil,-7);strips[i]=t;t:Hide()
                if row.area.name~=hidden then
                local rgb=row.area.colour
                t:ClearAllPoints();t:SetPoint("TOPLEFT",row.x/model.grid*width,-row.y/model.grid*height)
                t:SetSize(row.width/model.grid*width,height/model.grid);t:SetColorTexture(rgb[1],rgb[2],rgb[3],0.4);t:Show()
                end
            end
            for i,row in ipairs(regions and model.triangles or {}) do
                checkpoint(16)
                local t=triangles[i] or target.frame:CreateTexture(nil,"ARTWORK",nil,-7);triangles[i]=t;t:Hide()
                if row.area.name~=hidden then
                local a,b,c=row[1],row[2],row[3]
                if cross(a,b,c)>0 then b,c=c,b end
                local ax,ay,bx,by,cx,cy=a.x/10000*width,a.y/10000*height,b.x/10000*width,b.y/10000*height,c.x/10000*width,c.y/10000*height
                local left,top=math.min(ax,bx,cx),math.min(ay,by,cy)
                local tw,th=math.max(ax,bx,cx)-left,math.max(ay,by,cy)-top
                t:ClearAllPoints();t:SetPoint("TOPLEFT",left,-top);t:SetSize(tw,th)
                local rgb=row.area.colour;t:SetColorTexture(rgb[1],rgb[2],rgb[3],0.4)
                -- UL=a, LL=b, UR=c, LR=b (second native triangle degenerates).
                t:SetVertexOffset(1,ax-left,top-ay);t:SetVertexOffset(2,bx-left,top+th-by)
                t:SetVertexOffset(3,cx-left-tw,top-cy);t:SetVertexOffset(4,bx-left-tw,top+th-by);t:Show()
                end
            end
        end
        if geometryChanged or target.points~=points or target.regions~=regions then
            hide(dots,checkpoint)
            -- Points explicitly reveals every sample. Unchecked, shading keeps
            -- its automatic isolated-dot presentation and hides incorporated data.
            local cells={};local n=0
            for i,p in ipairs((points or regions) and model.rows or {}) do
                checkpoint()
                local cell=math.floor(p.x/200)..":"..math.floor(p.y/200)
                if points or (not self.subzoneStrictPoints and not model.covered[i] and not cells[cell]) then
                    cells[cell]=true;n=n+1
                    local t=dots[n] or target.frame:CreateTexture(nil,"ARTWORK",nil,-6);dots[n]=t
                    t:ClearAllPoints();t:SetPoint("CENTER",self.canvas,"TOPLEFT",p.x/10000*width,-p.y/10000*height)
                    t:SetSize(3/self.zoom,3/self.zoom);t:SetTexture("Interface\\AddOns\\AzerothFieldbook\\Artwork\\GatheringDot.tga")
                    t:SetVertexColor(1,0.94,0.72,0.85);t:Show()
                end
            end
        end
        hide(labels,checkpoint)
        -- Measure each layout and move it the shortest distance into free space.
        local placed={}
        for _,name in ipairs(names and model.names or {}) do
            checkpoint(8)
            if name~=hidden then
                local a=model.areas[name]
                local i=#placed+1
                local label=labels[i] or target.frame:CreateFontString(nil,"OVERLAY",textFont("GameFontHighlightSmall"));labels[i]=label
                local font=label:GetFont();label:SetFont(font,size,"OUTLINE")
                label:SetWordWrap(false);label:SetWidth(0);label:SetHeight(0)
                local text=A.Safe(name)
                local function measure(value)
                    checkpoint(8);label:SetText(value)
                    local measured=A.Read(label.GetStringWidth,label)
                    return A.Number(measured,0,100000) and measured or #value*size*0.6
                end
                local best,bestDistance,bestText
                local function try(value,textWidth,lines)
                    local p,d=S.PlaceLabel(placed,width,height,textWidth+4,size*lines+4,
                        (a.labelX or a.x)/10000*width,(a.labelY or a.y)/10000*height,checkpoint)
                    if p and (not bestDistance or d<bestDistance) then best,bestDistance,bestText=p,d,value end
                end
                try(text,measure(text),1)
                if bestDistance~=0 then
                    -- Every word boundary is a possible two-line layout. Byte
                    -- slicing at ASCII whitespace preserves UTF-8 names.
                    for left,space,right in text:gmatch("()( +)()") do
                        local first,second=text:sub(1,left-1),text:sub(right)
                        if first~="" and second~="" then
                            try(first.."\n"..second,math.max(measure(first),measure(second)),2)
                            if bestDistance==0 then break end
                        end
                    end
                end
                if best then
                    placed[#placed+1]=best
                    label:ClearAllPoints();label:SetPoint("CENTER",self.canvas,"TOPLEFT",best.x,-best.y)
                    label:SetWidth(best.width);label:SetHeight(best.height);label:SetWordWrap(true);label:SetNonSpaceWrap(false)
                    label:SetText(bestText);label:SetTextColor(a.colour[1],a.colour[2],a.colour[3])
                    label:SetShadowColor(0,0,0,1);label:SetShadowOffset(1,-1);label:Show()
                else label:Hide() end
            end
        end
        target.hidden=hidden
        target.model,target.width,target.height,target.regions=model,width,height,regions
        target.points=points
    end
    function map:RenderSubzones()
        local id=self.subzoneMapID
        local regions=journal.state.showSubzones==true
        local names=journal.state.showSubzoneLabels==true
        local points=journal.state.showSubzonePoints==true
        if self.subzoneWorldLayers then
            regions=self.subzoneWorldLayers("Zones")
            names=self.subzoneWorldLayers("Labels")
            points=self.subzoneWorldLayers("Points")
        end
        local method=S.FillMethod(journal)
        local hidden
        if journal.state.hideZoneNameSubzones==true then
            local info=A.Read(C_Map and C_Map.GetMapInfo,id)
            local zone=type(info)=="table" and info.name or (journal.state.mapID==id and journal.state.zone)
            if A.Text(zone,160) then hidden=zone end
        end
        local size=A.Integer(journal.state.subzoneLabelSize,2,24) and journal.state.subzoneLabelSize or S.DEFAULT_LABEL_SIZE
        if not self.available or not (regions or names or points) or A.Read(self.IsVisible,self)==false then
            self:CancelSubzones();front.frame:Hide();self.subzoneModel=nil
            if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            return
        end
        local w,h=self:GetWidth(),self:GetHeight()
        local revision=journal.subzones:Revision(id)
        if cacheID~=id then front.frame:Hide();self.subzoneModel=nil end
        if failed and failed.id==id and failed.revision==revision and failed.method==method then return end
        local pending=self.subzonePending
        if pending and not pending.thread then self.subzonePending=nil;pending=nil end
        if pending and pending.thread then
            if pending.id==id and pending.width==w and pending.height==h and pending.regions==regions
                and pending.names==names and pending.points==points and pending.size==size and pending.hidden==hidden and pending.method==method then return end
            self:CancelSubzones()
        end
        if cacheID==id and cacheRevision==revision and model and model.method==method and width==w and height==h
            and lastRegions==regions and lastLabels==names and lastPoints==points and lastSize==size and lastHidden==hidden then
            self.subzoneModel=model;front.frame:Show();return
        end
        local revisionAtStart=revision
        local job
        job=S.Queue(function(checkpoint)
            local index=journal.subzones:Index(id,true)
            while not index.ready do
                if index.error then error(index.error) end
                checkpoint(4096)
            end
            revisionAtStart=journal.subzones:Revision(id)
            local nextModel=model
            if cacheID~=id or cacheRevision~=revisionAtStart or not model or model.method~=method then
                local rows=journal.subzones:Samples(id,checkpoint)
                local resolution=cacheID==id and model and #rows>=#model.rows*0.75 and model.grid or nil
                nextModel=S.Build(rows,checkpoint,resolution,cacheID==id and model or journal.subzones:RecallColours(id),method)
            end
            paint(self,back,nextModel,w,h,regions,names,points,size,hidden,checkpoint)
            return nextModel
        end,function(ok,result)
            if self.subzonePending~=job then return end
            self.subzonePending=nil
            if not ok then
                failed={id=id,revision=revisionAtStart,method=method};self.subzoneError=tostring(result)
                local handler=A.Read(geterrorhandler);if type(handler)=="function" then handler(result) end
                return
            end
            if self.subzoneMapID~=id or A.Read(self.IsVisible,self)==false then return end
            front.frame:Hide();front,back=back,front;front.frame:Show();expose()
            journal.subzones:RememberColours(id,result)
            model=result;self.subzoneModel=model;self.subzoneError=nil;failed=nil
            cacheID,cacheRevision,width,height=id,revisionAtStart,w,h
            lastRegions,lastLabels,lastPoints,lastSize,lastHidden=regions,names,points,size,hidden
            -- Crossings arriving during a build are collected in the next
            -- snapshot, rather than repeatedly restarting and starving drawing.
            if journal.subzones:Revision(id)~=revisionAtStart then self:RenderSubzones() end
        end,self)
        job.id,job.width,job.height,job.regions,job.names,job.size=id,w,h,regions,names,size
        job.points=points;job.hidden=hidden;job.method=method
        self.subzonePending=job
    end
    local hoverX,hoverY,hoverModel
    function map:SubzoneHover()
        if not self.subzoneHover or not self.subzoneModel or self.placing or not GameTooltip then return end
        local x,y=cursorPoint();if not x then return end
        x,y=(x+self.panX)/(width*self.zoom)*10000,(y+self.panY)/(height*self.zoom)*10000
        if x==hoverX and y==hoverY and hoverModel==model and GameTooltip:IsOwned(self) and GameTooltip:IsShown() then return end
        hoverX,hoverY,hoverModel=x,y,model
        local a=model:At(x,y);local nearest,distance
        for _,p in ipairs(model.rows) do
            local d=((x-p.x)/10000*width*self.zoom)^2+((y-p.y)/10000*height*self.zoom)^2
            if d<=12^2 and (not distance or d<distance) then nearest,distance=p,d end
        end
        GameTooltip:SetOwner(self,"ANCHOR_LEFT");GameTooltip:SetText(a and A.Safe(a.name) or "Sub-zone observations")
        GameTooltip:AddLine("Estimated from your crossings and interior observations; unexplored boundaries are unknown.",1,1,1,true)
        if nearest then
            if nearest.kind=="interior" then
                GameTooltip:AddLine(A.Safe(nearest.name).." — interior observation",1,0.82,0.14,true)
                GameTooltip:AddLine(string.format("Observed at %.2f, %.2f",nearest.x/100,nearest.y/100),1,1,1,true)
            else
                GameTooltip:AddLine(A.Safe(nearest.from).." -> "..A.Safe(nearest.to),1,0.82,0.14,true)
                GameTooltip:AddLine(string.format("Crossed at %.2f, %.2f; from %.2f, %.2f",nearest.x/100,nearest.y/100,nearest.fromX/100,nearest.fromY/100),1,1,1,true)
            end
            if ns.AtlasUI then GameTooltip:AddLine("Observed "..ns.AtlasUI.Date(nearest.at),1,1,1) end
        end
        GameTooltip:AddLine(#model.rows.." observation samples / "..#model.names.." observed areas",0.75,0.8,0.8)
        if #model.rows==0 then GameTooltip:AddLine("Explore this map to begin recording sub-zones.",1,1,1,true) end
        GameTooltip:Show()
    end
    map:SetScript("OnEnter",function(self) self.subzoneHover=true;self:SubzoneHover() end)
    map:SetScript("OnLeave",function(self)
        self.subzoneHover=false
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end


-- A display-only adapter for Blizzard's canvas. Reuse the survey renderer and
-- its shared 1 ms work budget; never attach an idle OnUpdate or scan all maps.
function S.CreateWorldOverlay(journal)
    local controller={}
    local keys={Points="showSubzonePoints",Labels="showSubzoneLabels",Zones="showSubzones"}
    local function selected(layer)
        local value=journal.state["worldSubzone"..layer]
        if value==nil then value=journal.state[keys[layer]] end
        return value==true
    end
    if ns.RegisterWorldMapLayer then for _,label in ipairs({"Points","Labels","Zones"}) do
        local layer=label
        ns.RegisterWorldMapLayer(layer,function() return journal.state.showSubzonesOnWorldMap==true and selected(layer) end,function(on)
            if journal.readOnly then return end
            for name in pairs(keys) do
                if journal.state["worldSubzone"..name]==nil then
                    journal.state["worldSubzone"..name]=journal.state.showSubzonesOnWorldMap==true and selected(name)
                end
            end
            journal.state["worldSubzone"..layer]=on
            if on then journal.state.showSubzonesOnWorldMap=true end
        end,function() return not journal.readOnly end,function() controller:Refresh() end)
    end end
    local world,overlay,pending
    local function stop()
        if overlay then overlay:CancelSubzones();overlay:Hide() end
    end
    local function draw()
        pending=nil
        if not world or journal.state.showSubzonesOnWorldMap~=true or not world:IsShown() then stop();return end
        local canvas=A.Read(world.GetCanvas,world)
        local id=A.Read(world.GetMapID,world)
        if not canvas or not A.Integer(id,1,2147483647) then stop();return end
        local scale=A.Read(world.GetCanvasScale,world) or A.Read(canvas.GetScale,canvas) or 1
        local w,h=canvas:GetWidth(),canvas:GetHeight()
        if not A.Number(scale,0.0001,1000) or not A.Number(w,1,100000) or not A.Number(h,1,100000) then stop();return end
        if not overlay then
            overlay=CreateFrame("Frame",nil,canvas);controller.overlay=overlay
            overlay.canvas=overlay;overlay.zoom=1
            overlay.subzoneWorldLayers=selected;overlay.subzoneStrictPoints=true
            S.InstallMap(overlay,journal,function() return nil end)
            -- The shared Atlas renderer installs hover scripts, which enable
            -- mouse input implicitly. This native-map layer is display-only:
            -- remove those handlers, then disable input after installation.
            overlay:SetScript("OnEnter",nil);overlay:SetScript("OnLeave",nil)
            overlay:EnableMouse(false);overlay:EnableMouseWheel(false)
            overlay:SetScript("OnHide",function(self) self:CancelSubzones() end)
        end
        overlay:SetParent(canvas)
        local manager=A.Read(world.GetPinFrameLevelsManager,world)
        local level=manager and A.Read(manager.GetValidFrameLevel,manager,"PIN_FRAME_LEVEL_AREA_POI")
        overlay:SetFrameLevel(A.Integer(level,0,65535) and level or canvas:GetFrameLevel()+1)
        for _,buffer in ipairs(overlay.subzoneBuffers) do buffer.frame:SetFrameLevel(overlay:GetFrameLevel()) end
        -- Counter-scale so label sizes and dots remain legible on both the
        -- windowed and full-screen native map. Anchors follow its pan/zoom.
        overlay:SetScale(1/scale);overlay:ClearAllPoints();overlay:SetPoint("TOPLEFT",canvas,"TOPLEFT",0,0)
        overlay:SetSize(w*scale,h*scale);overlay.subzoneMapID=id;overlay.available=true;overlay:Show()
        overlay:RenderSubzones()
    end
    function controller:Refresh()
        if journal.state.showSubzonesOnWorldMap~=true then stop();return end
        if not world then self:Attach() end
        if not world or not world:IsShown() then stop();return end
        -- Collapse bursts of map/zoom/selection notifications into one request.
        if pending then return end
        if C_Timer and type(C_Timer.After)=="function" then pending=true;C_Timer.After(0,draw)
        else draw() end
    end
    function controller:Attach()
        if world or not WorldMapFrame or type(WorldMapFrame.GetCanvas)~="function" then return end
        world=WorldMapFrame
        world:HookScript("OnShow",function() self:Refresh() end)
        world:HookScript("OnHide",stop)
        world:HookScript("OnSizeChanged",function() self:Refresh() end)
        if type(hooksecurefunc)=="function" then
            for _,owner in ipairs({world,world.ScrollContainer}) do
                if type(owner)=="table" or type(owner)=="userdata" then
                    for _,method in ipairs({"SetMapID","SetCanvasScale","OnCanvasScaleChanged"}) do
                        if type(owner[method])=="function" then hooksecurefunc(owner,method,function() self:Refresh() end) end
                    end
                end
            end
        end
        local canvas=A.Read(world.GetCanvas,world)
        if canvas and type(canvas.HookScript)=="function" then canvas:HookScript("OnSizeChanged",function() self:Refresh() end) end
        if canvas and type(hooksecurefunc)=="function" and type(canvas.SetScale)=="function" then
            hooksecurefunc(canvas,"SetScale",function() self:Refresh() end)
        end
    end
    controller.loader=CreateFrame("Frame")
    controller.loader:RegisterEvent("ADDON_LOADED")
    controller.loader:SetScript("OnEvent",function() controller:Attach();if world then controller.loader:UnregisterEvent("ADDON_LOADED");controller:Refresh() end end)
    controller:Attach();controller:Refresh()
    return controller
end
