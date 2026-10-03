local _,ns=...
local A=ns.Annals
A.eventNames={accepted='Accepted',removed='Abandoned / removed',completed='Completed',discovery='Fieldbook discovery',flight='Flight path'}
A.icons={accepted='Interface\\GossipFrame\\AvailableQuestIcon',removed='Interface\\Icons\\INV_Misc_Note_01',
    completed='Interface\\GossipFrame\\ActiveQuestIcon',discovery='Interface\\Icons\\INV_Misc_Map_01',flight='Interface\\Minimap\\Tracking\\FlightMaster'}
function A.EventText(e)
    local text=(A.eventNames[e.kind] or e.kind)..' — '..e.title..'\n'..ns.AtlasUI.Date(e.at)
    if e.level then text=text..' • Level '..e.level end
    if e.zone then text=text..'\n'..e.zone end
    if e.subzone and e.subzone~='' and e.subzone~=e.zone then text=text..' — '..e.subzone end
    if A.Int(e.x,0,10000) and A.Int(e.y,0,10000) then text=text..string.format(' • %.1f, %.1f',e.x/100,e.y/100) end
    if e.removal=='abandoned' then text=text..'\nAbandon request observed.' end
    local r=e.reward
    local function item(prefix,v)
        return '\n'..prefix..': '..(v.name or ((v.currencyID and 'Currency #' or 'Item #')..tostring(v.currencyID or v.itemID)))..' ×'..tostring(v.quantity)
    end
    if type(r)=='table' then
        if r.chosen then text=text..item(r.chosen.currencyID and 'Chosen currency (offered amount)' or 'Chosen reward',r.chosen)
        elseif r.single then text=text..item('Automatic reward (sole option)',r.single)
        elseif r.choiceStatus=='none' then text=text..'\nNo item choice.'
        else text=text..'\nChosen reward unknown / incomplete.' end
        for _,v in ipairs(r.automatic or {}) do text=text..item('Automatic reward',v) end
        for _,v in ipairs(r.currencyOffers or {}) do text=text..item('Automatic currency (offered amount)',v) end
        if r.xp then text=text..'\nXP: '..r.xp end
        if r.money then text=text..' • Money: '..r.money..' copper' end
        if r.status=='incomplete' or r.status=='unknown' then text=text..'\nReward information incomplete.' end
    end
    if e.link then text=text..'\n'..e.link.section..' • Discovered during the journey; no quest causation implied.' end
    return text
end
-- Display-only affine projection along the client map hierarchy. Stored zone
-- coordinates stay untouched; continent/world artwork need their own map rects.
function A.MapTransform(source,target)
    if not A.Int(source,1,2147483647) or not A.Int(target,1,2147483647) then return end
    if source==target then return {x=0,y=0,w=1,h=1} end
    local chain,seen={},{}
    local id=source
    for _=1,16 do
        if id==target then break end
        if seen[id] then return end;seen[id]=true
        local info=A.Read(C_Map and C_Map.GetMapInfo,id)
        local parent=type(info)=='table' and A.Read(function() return info.parentMapID end)
        if not A.Int(parent,1,2147483647) then return end
        chain[#chain+1]={id,parent};id=parent
    end
    if id~=target or not C_Map or type(C_Map.GetMapRectOnMap)~='function' then return end
    local function rect(child,parent)
        local ok,x,right,y,bottom=pcall(C_Map.GetMapRectOnMap,child,parent)
        local number=ns.Atlas.Number
        if ok and number(x,0,1) and number(right,0,1) and number(y,0,1) and number(bottom,0,1)
            and right>x and bottom>y then return {x=x,y=y,w=right-x,h=bottom-y} end
    end
    local direct=rect(source,target);if direct then return direct end
    local result={x=0,y=0,w=1,h=1}
    for _,pair in ipairs(chain) do
        local r=rect(pair[1],pair[2]);if not r then return end
        result={x=r.x+result.x*r.w,y=r.y+result.y*r.h,w=result.w*r.w,h=result.h*r.h}
    end
    return result
end
local function project(p,index)
    local r=index.transforms[p.mapID]
    if not r or not A.Int(p.x,0,10000) or not A.Int(p.y,0,10000) then return end
    return {x=math.floor(r.x*10000+p.x*r.w+0.5),y=math.floor(r.y*10000+p.y*r.h+0.5),at=p.at,level=p.level,mapID=index.mapID}
end
-- Date/map index is rebuilt only when a range is selected or explicitly refreshed.
-- Scrubbing decodes at most 64 nearby chunks and reuses a bounded 64-chunk cache.
function A.JourneyIndex(j,first,last,mapID,filter,level)
    local result={segments={},events={},first=first,last=last,mapID=mapID,cache={},order={},transforms={},segmentIDs={}}
    local function includes(id)
        if not A.Int(id,1,2147483647) then return false end
        if result.transforms[id]==nil then result.transforms[id]=A.MapTransform(id,mapID) or false end
        return result.transforms[id]
    end
    for id,s in ipairs(j.db.segments) do
        if type(s)=='table' and includes(s.mapID) and (not level or s.level==level) and A.Int(s.at,0,9999999999) and A.Int(s.finish,0,9999999999) and s.at<=last and s.finish>=first then
            result.segments[#result.segments+1]=s;result.segmentIDs[s]=id
        end
    end
    table.sort(result.segments,function(a,b) return a.at<b.at end)
    for _,row in ipairs(j:Range(first,last,filter,level)) do if includes(row.event.mapID) then result.events[#result.events+1]=row end end
    return result
end
local function upper(rows,at,get)
    local lo,hi=1,#rows
    while lo<=hi do local mid=math.floor((lo+hi)/2);if get(rows[mid])<=at then lo=mid+1 else hi=mid-1 end end
    return hi
end
function A.JourneyFrame(index,at)
    at=math.max(index.first,math.min(index.last,at))
    local finish=upper(index.segments,at,function(s) return s.at end)
    local lines,markers={},{};local cursor;local limited=finish>64;local invalid=0
    local nextLine=1
    local function edge(from,to)
        -- Keep the newest edges even when 64 dense chunks exceed the draw budget.
        if #lines==2048 then limited=true end
        lines[nextLine]={from=from,to=to};nextLine=nextLine%2048+1
    end
    local endpoints={}
    for i=math.max(1,finish-63),finish do local s=index.segments[i]
        local points=index.cache[s]
        if points==nil then
            points=A.Decode(s);index.cache[s]=points or false;index.order[#index.order+1]=s
            if #index.order>64 then index.cache[table.remove(index.order,1)]=nil end
        end
        if points then
            local previous
            for n,original in ipairs(points) do
                local p=project(original,index)
                if p and p.at>=index.first and p.at<=at then
                    if not cursor or p.at>cursor.at then cursor=p end
                    if n==1 and A.Int(s.joinFrom,1,100000000) then
                        local prior=endpoints[s.joinFrom]
                        if prior and p.at>=prior.at and p.at-prior.at<=12 then previous=prior end
                    end
                    if previous then edge(previous,p) end
                    previous=p
                    if n==#points then endpoints[index.segmentIDs[s]]=p end
                else previous=nil end
            end
        else invalid=invalid+1 end
    end
    local endEvent=upper(index.events,at,function(row) return row.event.at end)
    for i=math.max(1,endEvent-511),endEvent do
        local row=index.events[i];local e=row.event
        local p=project(e,index)
        if p then
            markers[#markers+1]={id=tostring(row.id),name=e.title,mapID=index.mapID,x=p.x,y=p.y,category='other',event=e}
        end
    end
    if endEvent>512 then limited=true end
    return lines,markers,cursor,limited,invalid
end
function A.TrailColor(at,stamp,strength)
    strength=ns.Atlas.Number(strength,0,1) and strength or 0.75
    -- Thirty minutes behind the scrubber is halfway cooled. Keep an opacity
    -- floor so old travel remains discoverable, without altering stored history.
    local heat=2^(-math.max(0,at-stamp)/1800)
    local fade=(1-heat)*strength
    return 1-0.75*fade,0.82-0.27*fade,0.14+0.86*fade,0.8-0.68*fade,heat
end
function ns.CreateAnnalsMap(parent,j,onSelect,onNavigate)
    local adapter={lines={},markers={}}
    function adapter:Get(id) if id=='journey' then return {id=id,name='Journey',category='route',stops={{}}} end end
    function adapter:List() return self.markers end
    function adapter:RouteMap() return {},self.lines end
    function adapter:Layer() return true end
    function adapter:WeatherText() return '' end
    local map=ns.CreateAtlasMap(parent,adapter,onSelect,function() end,onNavigate)
    -- The Atlas factory's live-player driver is instance-local; historical maps
    -- always suppress it, including OnShow after navigating back from a journal.
    function map:ResumePlayer()
        self:SuspendPlayer();self.playerArrow:Hide();self.playerCoordinates:SetText('Historical journey')
    end
    function map:ShowJourney(index,at)
        local cursor,limited,invalid
        adapter.lines,adapter.markers,cursor,limited,invalid=A.JourneyFrame(index,at)
        table.sort(adapter.lines,function(a,b) return a.to.at<b.to.at end)
        self:Render(index.mapID,'journey');self:SuspendPlayer();self.playerArrow:Hide();self.playerCoordinates:SetText("Historical journey")
        local cutoff=math.max(index.first,math.min(index.last,at))
        for i,segment in ipairs(adapter.lines) do
            local line=self.lines and self.lines[i]
            if line then
                local r,g,b,alpha,heat=A.TrailColor(cutoff,segment.to.at,j.db.settings.trailContrast)
                line:SetColorTexture(r,g,b,alpha)
                line:SetDrawLayer('ARTWORK',heat>=0.5 and 1 or 0)
            end
        end
        for _,pin in ipairs(self.pins or {}) do if pin.group and pin:IsShown() then
            local event=pin.group[1].point.event
            for _,member in ipairs(pin.group) do if member.point.event.kind=='flight' then event=member.point.event;break end end
            pin.icon:SetTexture(A.icons[event.kind]);pin.icon:SetVertexColor(1,1,1)
            pin:SetScript('OnClick',function(p,button)
                if map:FinishPan() then return end
                if button=='RightButton' then map:Navigate(button);return end
                local selected=0
                for n,m in ipairs(p.group) do if m.id==map.selectedEvent then selected=n;break end end
                local target=p.group[selected%#p.group+1];map.selectedEvent=target.id;onSelect(target.id)
            end)
            pin:SetScript('OnEnter',function(p)
                if not GameTooltip then return end
                GameTooltip:SetOwner(p,'ANCHOR_LEFT');GameTooltip:SetText('Adventurer\'s Annals')
                for n,m in ipairs(p.group) do if n>6 then break end;GameTooltip:AddLine(ns.Atlas.Safe(A.EventText(m.point.event)),1,1,1,true) end
                if #p.group>1 then GameTooltip:AddLine('Click repeatedly to cycle overlapping events.',1,0.82,0.14,true) end
                GameTooltip:Show()
            end)
        end end
        return cursor,limited,invalid
    end
    return map
end
