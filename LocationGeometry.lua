local _, ns = ...
local geometry = {}
ns.LocationGeometry = geometry

local function cross(a,b,c) return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x) end
local function distance(a,b) return (a.x-b.x)^2+(a.y-b.y)^2 end
local function triangle(points,a,b,c)
    local p,q,r=points[a],points[b],points[c]
    local d=2*cross(p,q,r)
    if math.abs(d)<0.000001 then return end
    -- Work relative to p to avoid cancellation for tight groups far from 0,0.
    local bx,by,cx,cy=q.x-p.x,q.y-p.y,r.x-p.x,r.y-p.y
    local b2,c2=bx*bx+by*by,cx*cx+cy*cy
    local x,y=(cy*b2-by*c2)/d,(bx*c2-cx*b2)/d
    return {a,b,c,cx=p.x+x,cy=p.y+y,r2=x*x+y*y}
end
function geometry.Build(map)
    local points,triangles,covered={},{},{}
    local scale=ns.CreatureLocations.SCALE
    for _,p in pairs(map and map.points or {}) do
        points[#points+1]={u=p.x/scale,v=p.y/scale,approximate=p.approximate}
    end
    table.sort(points,function(a,b) if a.u~=b.u then return a.u<b.u end;return a.v<b.v end)
    -- Distances are in yards, not pixels or a percentage of differently sized
    -- zones. With no map scale we can display dots but cannot join them safely.
    if #points<3 or not map.width or not map.height then return points,triangles,covered end
    for _,p in ipairs(points) do p.x=p.u*map.width;p.y=p.v*map.height end
    local n=#points
    local extent=math.max(map.width,map.height)*8
    points[n+1]={x=-extent,y=-extent};points[n+2]={x=extent*3,y=-extent}
    points[n+3]={x=-extent,y=extent*3}
    local work={triangle(points,n+1,n+2,n+3)}
    -- Deterministic Bowyer-Watson triangulation; sorted inputs break cocircular
    -- ties consistently. Filter individual triangle edges, never a cluster's
    -- convex hull: a sparse bridge cannot paint across a distant empty region.
    for i=1,n do
        local p,edges,keep=points[i],{},{}
        local function edge(a,b)
            if a>b then a,b=b,a end
            local key=a..":"..b
            if edges[key] then edges[key].count=edges[key].count+1
            else edges[key]={a,b,count=1} end
        end
        for _,t in ipairs(work) do
            if (p.x-t.cx)^2+(p.y-t.cy)^2<=t.r2+0.000001 then
                edge(t[1],t[2]);edge(t[2],t[3]);edge(t[3],t[1])
            else keep[#keep+1]=t end
        end
        local boundary={}
        for _,e in pairs(edges) do if e.count==1 then boundary[#boundary+1]=e end end
        table.sort(boundary,function(a,b) if a[1]~=b[1] then return a[1]<b[1] end;return a[2]<b[2] end)
        for _,e in ipairs(boundary) do
            local t=triangle(points,e[1],e[2],i)
            if t then keep[#keep+1]=t end
        end
        work=keep
    end
    local limit=ns.CreatureLocations.EDGE_YARDS^2
    for _,t in ipairs(work) do
        if t[1]<=n and t[2]<=n and t[3]<=n then
            local a,b,c=points[t[1]],points[t[2]],points[t[3]]
            if distance(a,b)<=limit and distance(b,c)<=limit and distance(c,a)<=limit then
                triangles[#triangles+1]={t[1],t[2],t[3]}
                covered[t[1]],covered[t[2]],covered[t[3]]=true,true,true
            end
        end
    end
    for i=n+3,n+1,-1 do points[i]=nil end
    return points,triangles,covered
end
