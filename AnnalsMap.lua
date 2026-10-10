local _,ns=...
local A=ns.Annals
A.eventNames={accepted='Accepted',removed='Abandoned / removed',completed='Completed',discovery='Fieldbook discovery',flight='Flight path',death='Death',levelup='Level ups',hearth='Hearth / recall',teleport='Teleport',crossing='Cross-continent crossing',battleground='Battleground transfer',instance='Instance entry / exit',login='Login',logout='Logout'}
A.icons={accepted='Interface\\GossipFrame\\AvailableQuestIcon',removed='Interface\\Icons\\INV_Misc_Note_01',
    completed='Interface\\GossipFrame\\ActiveQuestIcon',discovery='Interface\\Icons\\INV_Misc_Map_01',flight='Interface\\Minimap\\Tracking\\FlightMaster',death='Interface\\TargetingFrame\\UI-TargetingFrame-Skull',
    levelup='Interface\\Icons\\Spell_Holy_HolyNova',
    hearth='Interface\\Icons\\INV_Misc_Rune_01',teleport='Interface\\Icons\\Spell_Arcane_TeleportStormWind',
    crossing='Interface\\Icons\\Creatureportrait_Darkshoreboat',battleground='Interface\\Icons\\Achievement_BG_winWSG',instance='Interface\\Icons\\INV_Misc_Key_10',login='Interface\\Icons\\Spell_Holy_Resurrection',logout='Interface\\Icons\\INV_Misc_PocketWatch_01'}
A.eventColours={discovery='55ddee',accepted='55ddee',completed='77dd88',removed='eeaa66',flight='77dd88',death='ee7777',levelup='ffd100',hearth='bb99ff',teleport='bb99ff',crossing='55ddee',battleground='eeaa66',instance='bb99ff',login='77dd88',logout='eeaa66'}
function A.InstanceDirection(parent,icon,e,shadowAlpha,scale)
    scale=scale or 1
    local action=e.kind=='instance' and e.instanceAction
    if action and not parent.instanceArrow then
        parent.instanceArrowShadow=parent:CreateTexture(nil,'OVERLAY',nil,5)
        parent.instanceArrow=parent:CreateTexture(nil,'OVERLAY',nil,6)
        for _,arrow in ipairs({parent.instanceArrowShadow,parent.instanceArrow}) do
            arrow:SetTexture('Interface\\ChatFrame\\ChatFrameExpandArrow')
        end
        parent.instanceArrowShadow:SetVertexColor(0,0,0,shadowAlpha or 0.95)
    end
    if parent.instanceArrow then
        parent.instanceArrow:SetShown(action~=nil and action~=false);parent.instanceArrowShadow:SetShown(action~=nil and action~=false)
        if action then
            for _,arrow in ipairs({parent.instanceArrowShadow,parent.instanceArrow}) do
                arrow:SetSize(11*scale,13*scale);arrow:ClearAllPoints()
            end
            parent.instanceArrowShadow:SetPoint('BOTTOMRIGHT',icon,'BOTTOMRIGHT',4*scale,-3*scale)
            parent.instanceArrow:SetPoint('BOTTOMRIGHT',icon,'BOTTOMRIGHT',3*scale,-2*scale)
            local rotation=action=='exit' and math.pi or 0
            parent.instanceArrow:SetRotation(rotation);parent.instanceArrowShadow:SetRotation(rotation)
            if action=='exit' then parent.instanceArrow:SetVertexColor(1,0.6,0.25) else parent.instanceArrow:SetVertexColor(0.3,1,0.4) end
        end
    end
end
function A.InstanceNote(e)
    if e.instanceAction=='enter' then
        return e.mapID and A.Int(e.x,0,10000) and A.Int(e.y,0,10000) and 'Journey holds at this entrance until an observed exit.' or 'Entrance position was not observed.'
    elseif e.instanceType then return 'Recorded inside an instance; interior movement is not mapped.' end
end
function A.Paint(value,colour) return '|cff'..colour..ns.Atlas.Safe(tostring(value))..'|r' end
function A.MoneyText(amount,coloured)
    local parts={};local gold,silver,copper=math.floor(amount/10000),math.floor(amount/100)%100,amount%100
    for _,v in ipairs({{gold,'g','ffd100'},{silver,'s','c7c7cf'},{copper,'c','b87333'}}) do
        if v[1]>0 or (v[2]=='c' and #parts==0) then parts[#parts+1]=v[1]..(coloured and A.Paint(v[2],v[3]) or v[2]) end
    end
    return table.concat(parts,' ')
end
function A.RewardPresentation(v,recordedOnly)
    local name,icon,quality=A.RewardName(v.name),v.icon,v.quality
    local link=v.itemID and (v.link or ('item:'..v.itemID)) or v.currencyID and ('currency:'..v.currencyID) or v.spellID and ('spell:'..v.spellID)
    if v.itemID and not recordedOnly then
        local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
        if type(fn)=='function' then
            local ok,n,_,q,_,_,_,_,_,_,texture=pcall(fn,v.link or v.itemID)
            if ok then
                name=name or A.RewardName(n);quality=quality or (A.Int(q,0,8) and q or nil)
                icon=icon or (A.Int(texture,1,2147483647) and texture or nil)
            end
        end
    elseif v.spellID and not recordedOnly then
        local info=A.Read(C_Spell and C_Spell.GetSpellInfo,v.spellID)
        if type(info)=='table' then name=name or A.RewardName(info.name);icon=icon or (A.Int(info.iconID,1,2147483647) and info.iconID or nil) end
    end
    local colours={[0]='9d9d9d',[1]='ffffff',[2]='1eff00',[3]='0070dd',[4]='a335ee',[5]='ff8000',[6]='e6cc80',[7]='00ccff',[8]='00ccff'}
    return name or ((v.itemID and 'Item #' or v.currencyID and 'Currency #' or 'Spell #')..tostring(v.itemID or v.currencyID or v.spellID)),
        colours[quality] or 'dddddd',icon or 134400,link
end
function A.QuestTextBlocks(e,coloured)
    local rows={}
    if e.kind~='accepted' and e.kind~='completed' then return rows end
    local r=e.reward or {}
    local function add(text,kind,colour)
        rows[#rows+1]={text=coloured and A.Paint(text,colour) or text,kind=kind}
    end
    add('Quest text','heading','55ddee')
    add(r.questText or 'Quest text was not recorded.','text','dddddd')
    if r.objectiveText then
        add('Objectives','heading','55ddee');add(r.objectiveText,'text','dddddd')
    end
    return rows
end
function A.RewardBlocks(e,coloured,recordedOnly)
    local rows={};local r=e.reward
    local function paint(text,colour) return coloured and A.Paint(text,colour) or tostring(text) end
    local function add(text,kind,item) rows[#rows+1]={text=text,kind=kind or 'text',item=item} end
    local function heading(text) add(paint(text,'77dd88'),'heading') end
    local function item(v)
        local name,colour=A.RewardPresentation(v,recordedOnly)
        add(paint(name,colour)..((v.spellID or v.quantity==1) and '' or ' ×'..v.quantity),'item',v)
    end
    if e.kind~='accepted' and e.kind~='completed' and type(r)~='table' then return rows end
    if type(r)~='table' then add(paint('Reward details were not captured for this entry.','999999'));return rows end
    if e.kind=='accepted' then
        heading('Potential rewards')
        if r.count and r.count>0 then
            add(paint(r.count==1 and 'Offered reward' or 'Choose one','dddddd'))
            for i=1,r.count do if r.choices and r.choices[i] then item(r.choices[i]) else add(paint('Reward option '..i..' unavailable','999999')) end end
        elseif r.count==0 then add(paint('No reward choice.','999999')) end
    elseif r.chosen then heading(r.chosen.currencyID and 'Chosen currency (offered amount)' or 'Chosen reward');item(r.chosen)
    elseif r.single then heading('Received reward (sole option)');item(r.single)
    elseif r.choiceStatus=='none' then add(paint('No item choice.','999999'))
    else add(paint('Chosen reward unknown / incomplete.','999999')) end
    if r.automatic and #r.automatic>0 then heading('Guaranteed rewards');for _,v in ipairs(r.automatic) do item(v) end end
    if r.currencyOffers and #r.currencyOffers>0 then heading('Currency rewards (offered amounts)');for _,v in ipairs(r.currencyOffers) do item(v) end end
    if r.spellOffers and #r.spellOffers>0 then heading('Offered spells / unlocks');for _,v in ipairs(r.spellOffers) do item(v) end end
    local xp=e.kind=='accepted' and r.offeredXP or r.xp
    local money=e.kind=='accepted' and r.offeredMoney or r.money
    if xp~=nil or money~=nil then
        heading(e.kind=='accepted' and 'Offered XP & money' or 'XP & money received')
        if xp~=nil then add(paint(xp..' XP','bb99ff')) end
        if money~=nil then add(A.MoneyText(money,coloured)) end
    end
    if r.status=='incomplete' or r.status=='unknown' then add(paint('Some reward details were not captured.','999999')) end
    return rows
end
function A.DeathText(e)
    if e.kind~='death' then return end
    local k=e.killer
    if not k then return 'Killer: unknown (not captured).' end
    if k.environment then
        local labels={FALLING='Falling',DROWNING='Drowning',FIRE='Fire',LAVA='Lava',SLIME='Slime',FATIGUE='Fatigue'}
        return 'Killed by: '..(labels[k.environment] or k.environment)
    end
    local text='Killed by: '..k.name..' • Level '..(k.level or 'unknown')
    if k.player then text=text..' • Player • '..(k.race or 'Race unknown')..' • '..(k.class or 'Class unknown') end
    text=text..'\nKilling blow: '..(k.ability or (k.spellID and ('Spell #'..k.spellID)) or 'unknown')
    return text
end
function A.EventText(e,coloured,recordedOnly)
    local function paint(value,colour)
        if not coloured then return tostring(value) end
        return '|cff'..colour..ns.Atlas.Safe(tostring(value))..'|r'
    end
    local text=paint(A.eventNames[e.kind] or e.kind,A.eventColours[e.kind] or '55ddee')..' — '..paint(e.title,'ffd100')..'\n'..paint(ns.AtlasUI.Date(e.at),'999999')
    if e.level then text=text..paint(' • Level '..e.level,'999999') end
    if e.zone then text=text..'\n'..paint(e.zone,'dddddd') end
    if e.subzone and e.subzone~='' and e.subzone~=e.zone then text=text..' — '..paint(e.subzone,'dddddd') end
    if A.Int(e.x,0,10000) and A.Int(e.y,0,10000) then text=text..paint(string.format(' • %.1f, %.1f',e.x/100,e.y/100),'999999') end
    if e.removal=='abandoned' then text=text..'\nAbandon request observed.' end
    local death=A.DeathText(e);if death then text=text..'\n'..paint(death,'ee7777') end
    local instanceNote=A.InstanceNote(e);if instanceNote then text=text..'\n'..paint(instanceNote,'999999') end
    for _,row in ipairs(A.QuestTextBlocks(e,coloured)) do text=text..(row.kind=='heading' and '\n\n' or '\n')..row.text end
    for _,row in ipairs(A.RewardBlocks(e,coloured,recordedOnly)) do text=text..(row.kind=='heading' and '\n\n' or '\n')..row.text end
    if e.link then text=text..'\n'..paint(e.link.section,'55ddee') end
    return text
end
local function searchLower(text)
    return (strlower or string.lower)(text):gsub('%s+',' ')
end
function A.SearchTerms(query)
    local terms={}
    if A.Text(query,200) then for term in searchLower(query):gmatch('%S+') do terms[#terms+1]=term end end
    return terms
end
local function searchContains(text,terms)
    for _,term in ipairs(terms) do if not text:find(term,1,true) then return false end end
    return true
end
local function searchRecord(e,cache)
    if cache.records[e] then return cache.records[e] end
    local parts,rewards={},{}
    local function add(value) if type(value)=='string' or type(value)=='number' then parts[#parts+1]=tostring(value) end end
    for _,key in ipairs({'title','kind','zone','subzone','removal','state','level','questID','spellID'}) do add(e[key]) end
    add(A.eventNames[e.kind]);add('Level '..tostring(e.level or 'unknown'))
    -- Recorded text can match without looking up any item data. Only unmatched
    -- rows need the cached display metadata below; neither cache is saved.
    if ns.AtlasUI then add(A.EventText(e,false,true)) end
    if date then add(date('%Y-%m-%d %H:%M:%S',e.at)) end
    if e.x and e.y then add(string.format('Coordinates: %.1f, %.1f',e.x/100,e.y/100)) end
    if e.link then add(e.link.section);add(e.link.key);add('Fieldbook discovery') end
    local function reward(v)
        if not v then return end
        rewards[#rewards+1]=v
        for _,key in ipairs({'name','itemID','currencyID','spellID','quantity'}) do add(v[key]) end
        if v.quality then add(_G['ITEM_QUALITY'..v.quality..'_DESC']) end
    end
    local r=e.reward
    if r then
        for _,key in ipairs({'status','choiceStatus','otherRewards','currencyStatus'}) do add(r[key]) end
        for _,key in ipairs({'xp','offeredXP'}) do if r[key] then add('Experience XP '..r[key]) end end
        for _,key in ipairs({'money','offeredMoney'}) do if r[key] then add('Money '..A.MoneyText(r[key],false));add(r[key]) end end
        if e.kind=='accepted' then add('Potential offered rewards') end
        if r.chosen then add('Chosen reward');reward(r.chosen) end
        if r.single then add('Received reward sole option');reward(r.single) end
        for _,key in ipairs({'choices','automatic','currencyOffers','spellOffers'}) do
            local list=r[key]
            if list then
                add(key=='automatic' and 'Guaranteed automatic rewards' or key=='currencyOffers' and 'Currency rewards offered amounts' or key=='spellOffers' and 'Offered spells unlocks' or 'Choose one reward')
                for i=1,64 do reward(list[i]) end
            end
        end
    end
    local record={text=searchLower(table.concat(parts,' ')),rewards=rewards}
    cache.records[e]=record;return record
end
local function searchReward(v,cache)
    if not v.itemID then return searchLower(A.RewardPresentation(v)) end
    local key=v.link or tostring(v.itemID)
    if cache.items[key] then return cache.items[key] end
    local parts={}
    local function add(value)
        if A.Public(value) and type(value)=='string' and #value<=4096 then value=value:gsub('%s+',' ') end
        if A.Text(value,4096) then parts[#parts+1]=value:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('|T.-|t',''):gsub('|A.-|a','') end
    end
    local instant=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(instant)=='function' then
        local ok,_,kind,subtype,equip=pcall(instant,v.itemID)
        if ok then add(kind);add(subtype);if A.Text(equip,80) then add(_G[equip]) end end
    end
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    local name
    if type(info)=='function' then
        local ok,n,_,quality,_,_,kind,subtype,_,equip,_,_,_,_,_,_,_,_,description=pcall(info,v.link or v.itemID)
        if ok then
            name=A.Text(n,240) and n or nil;add(name);add(kind);add(subtype);add(description)
            if A.Text(equip,80) then add(_G[equip]) end
            if A.Int(quality,0,8) then add(_G['ITEM_QUALITY'..quality..'_DESC']) end
        end
    end
    local tooltip=A.Read(C_TooltipInfo and C_TooltipInfo.GetHyperlink,v.link or ('item:'..v.itemID))
    local lines=type(tooltip)=='table' and A.Read(function() return tooltip.lines end)
    if type(lines)=='table' then
        for i,line in ipairs(lines) do
            if i>64 then break end
            if type(line)=='table' then add(A.Read(function() return line.leftText end));add(A.Read(function() return line.rightText end)) end
        end
    end
    cache.itemKeys[v.itemID]=cache.itemKeys[v.itemID] or {};cache.itemKeys[v.itemID][key]=true
    cache.items[key]=searchLower(table.concat(parts,' '))
    if not name and not cache.requested[v.itemID] and C_Item and type(C_Item.RequestLoadItemDataByID)=='function' then
        cache.requested[v.itemID]=true;A.Read(C_Item.RequestLoadItemDataByID,v.itemID)
    end
    return cache.items[key]
end
function A.SearchEvents(rows,query,cache)
    local terms=A.SearchTerms(query)
    if #terms==0 then return rows end
    cache=cache or {};cache.records=cache.records or {};cache.items=cache.items or {}
    cache.itemKeys=cache.itemKeys or {};cache.requested=cache.requested or {}
    local result={}
    for _,row in ipairs(rows) do
        local record=searchRecord(row.event,cache);local text=record.text
        if not searchContains(text,terms) then
            local parts={text}
            for _,v in ipairs(record.rewards) do parts[#parts+1]=searchReward(v,cache) end
            text=table.concat(parts,' ')
        end
        if searchContains(text,terms) then result[#result+1]=row end
    end
    return result
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
    return {x=math.floor(r.x*10000+p.x*r.w+0.5),y=math.floor(r.y*10000+p.y*r.h+0.5),at=p.at,level=p.level,mapID=index.mapID or p.mapID,flight=p.flight,mount=p.mount,state=p.state,combat=p.combat,activity=p.activity}
end
-- Date/map index is rebuilt only when a range is selected or explicitly refreshed.
-- Scrubbing decodes at most 64 nearby chunks and reuses a bounded 64-chunk cache.
function A.JourneyIndex(j,first,last,mapID,filter,level,query,searchCache)
    local result={segments={},events={},positions={},instanceEvents={},first=first,last=last,mapID=mapID,level=level,cache={},payloads={},order={},transforms={},segmentIDs={}}
    local function includes(id)
        if not A.Int(id,1,2147483647) then return false end
        if result.transforms[id]==nil then result.transforms[id]=not mapID and {x=0,y=0,w=1,h=1} or A.MapTransform(id,mapID) or false end
        return result.transforms[id]
    end
    for id,s in ipairs(j.db.segments) do
        if type(s)=='table' and includes(s.mapID) and (not level or s.level==level) and A.Int(s.at,0,9999999999) and A.Int(s.finish,0,9999999999) and s.at<=last and s.finish>=first then
            result.segments[#result.segments+1]=s;result.segmentIDs[s]=id
        end
    end
    table.sort(result.segments,function(a,b) if a.at==b.at then return result.segmentIDs[a]<result.segmentIDs[b] end;return a.at<b.at end)
    for _,row in ipairs(A.SearchEvents(j:Range(first,last,filter,level),query,searchCache)) do if includes(row.event.mapID) then result.events[#result.events+1]=row end end
    for _,row in ipairs(j:Range(first,last,nil,level)) do
        if not row.event.instanceType and includes(row.event.mapID) and A.Int(row.event.x,0,10000) and A.Int(row.event.y,0,10000) then result.positions[#result.positions+1]=row end
    end
    -- Visits may start before the selected dates and ignore marker/level/search
    -- filters. The entrance remains the position until an observed exit.
    for _,row in ipairs(j:Range(0,last,'instance')) do
        if row.event.instanceAction then result.instanceEvents[#result.instanceEvents+1]=row;includes(row.event.mapID) end
    end
    return result
end
local function upper(rows,at,get)
    local lo,hi=1,#rows
    while lo<=hi do local mid=math.floor((lo+hi)/2);if get(rows[mid])<=at then lo=mid+1 else hi=mid-1 end end
    return hi
end
local function decode(index,s)
    if index.cache[s]==nil or index.payloads[s]~=s.data then
        if index.cache[s]==nil then index.order[#index.order+1]=s end
        index.cache[s]=A.Decode(s) or false;index.payloads[s]=s.data
        if #index.order>64 then local old=table.remove(index.order,1);index.cache[old]=nil;index.payloads[old]=nil end
    end
    return index.cache[s]
end
local function instancePosition(index,at)
    local rows=index.instanceEvents or {}
    local n=upper(rows,at,function(row) return row.event.at end)
    local e=rows[n] and rows[n].event
    if not e or e.instanceAction~='enter' then return nil,false end
    local p=project(e,index)
    if p then p.instanceName=e.instanceName or 'Unknown instance';p.at=at;p.sampleAt=e.at;p.combat=nil;p.activity=nil end
    return p,true,rows[n+1] and rows[n+1].event.at or index.last
end
local function eventPosition(index,at,cursor)
    local positions=index.positions or {};local n=upper(positions,at,function(row) return row.event.at end)
    local latest=positions[n];local sampleAt=cursor and (cursor.sampleAt or cursor.at)
    local eventState=latest and (latest.event.kind=='death' and 'dead' or latest.event.kind=='flight' and 'flight')
    local changed=false
    if latest and (not cursor or latest.event.at>sampleAt or (latest.event.at==sampleAt and eventState and eventState~=(cursor.state or (cursor.flight and 'flight')))) then
        local p=project(latest.event,index)
        if p then
            p.state=eventState or p.state
            if cursor and cursor.x==p.x and cursor.y==p.y then p.previous=cursor.previous end
            cursor=p;changed=true
        end
    end
    return cursor,changed,positions[n+1] and positions[n+1].event.at or index.last
end
function A.InterpolatePosition(from,to,at)
    if not from or not to or from.mapID~=to.mapID or to.at<=from.at or at<from.at or at>=to.at then return end
    local f=(at-from.at)/(to.at-from.at)
    local moving=from.x~=to.x or from.y~=to.y
    return {x=from.x+(to.x-from.x)*f,y=from.y+(to.y-from.y)*f,at=at,mapID=from.mapID,
        level=from.level,flight=from.flight,mount=from.mount,state=from.state,combat=from.combat,activity=from.activity,sampleAt=from.at,interpolated=at>from.at,
        previous=moving and from or from.previous,headingX=moving and (to.x-from.x) or nil,headingY=moving and (to.y-from.y) or nil}
end
-- Follow mode needs a source map, not all the route geometry. Decode only the
-- latest usable chunk (plus a joined successor); never draw in mixed coordinates.
function A.JourneyPosition(index,at)
    at=math.max(index.first,math.min(index.last,at))
    local held,inside,boundary=instancePosition(index,at)
    if inside then return held,boundary end
    local finish=upper(index.segments,at,function(s) return s.at end)
    local nextSegment=index.segments[finish+1]
    local boundary=nextSegment and nextSegment.at or index.last
    local cursor
    for i=finish,math.max(1,finish-62),-1 do
        local s=index.segments[i];local points=decode(index,s)
        if points then
            local n=upper(points,at,function(p) return p.at end)
            local from=points[n] and project(points[n],index)
            if from then
                local to=points[n+1] and project(points[n+1],index)
                if not to then
                    local following=index.segments[i+1]
                    if following and following.joinFrom==index.segmentIDs[s] and following.at-from.at<=12 then
                        local nextPoints=decode(index,following)
                        to=nextPoints and nextPoints[1] and project(nextPoints[1],index)
                    end
                end
                cursor=to and A.InterpolatePosition(from,to,at) or (from.at>=index.first and from or nil)
                if cursor then boundary=math.min(boundary,to and to.at or index.last);break end
            end
        end
    end
    local _,nextEvent
    cursor,_,nextEvent=eventPosition(index,at,cursor)
    return cursor,math.min(boundary,nextEvent)
end
function A.JourneyFrame(index,at)
    at=math.max(index.first,math.min(index.last,at))
    local finish=upper(index.segments,at,function(s) return s.at end)
    local lines,markers={},{};local cursor,motion;local limited=finish>64;local invalid=0
    -- One future chunk may complete an explicitly recorded boundary connection.
    -- It shares the decode budget and never grants continuity on its own.
    local following=index.segments[finish+1]
    local stop=finish+(following and A.Int(following.joinFrom,1,100000000) and 1 or 0)
    limited=stop>64
    local nextLine=1
    local trailFirst=math.max(index.first,index.trailSpan and at-index.trailSpan or index.first)
    local function edge(from,to)
        if to.at<=trailFirst then return end
        if from.at<trailFirst then from=A.InterpolatePosition(from,to,trailFirst) end
        if not from then return end
        -- Keep the newest edges even when 64 dense chunks exceed the draw budget.
        if #lines==2048 then limited=true end
        lines[nextLine]={from=from,to=to};nextLine=nextLine%2048+1
    end
    local endpoints={}
    for i=math.max(1,stop-63),stop do local s=index.segments[i]
        local points=decode(index,s)
        if points then
            local previous
            for n,original in ipairs(points) do
                local p=project(original,index)
                if p then
                    if n==1 and A.Int(s.joinFrom,1,100000000) then
                        local prior=endpoints[s.joinFrom]
                        if prior and prior.mapID==p.mapID and p.at>=prior.at and p.at-prior.at<=12 then previous=prior end
                    end
                    if previous and p.at>=index.first then
                        p.previous=(previous.x~=p.x or previous.y~=p.y) and previous or previous.previous
                        local from=previous
                        if previous.at<index.first then from=p.at==index.first and p or A.InterpolatePosition(previous,p,index.first) end
                        if p.at>at then
                            local between=A.InterpolatePosition(previous,p,at)
                            if between and (not cursor or between.at>=cursor.at) then
                                cursor=between;motion={from=previous,to=p}
                                if from and from.at<at then edge(from,between) end
                            end
                        elseif from and from~=p and from.at<=at then edge(from,p) end
                    end
                    if p.at>at then break end
                    if p.at>=index.first and (not cursor or p.at>=cursor.at) then cursor=p;motion=nil end
                    previous=p
                    if n==#points then endpoints[index.segmentIDs[s]]=p end
                else previous=nil end
            end
        else invalid=invalid+1 end
    end
    -- Event filters hide markers, never the player's historical position/state.
    local changed,nextEvent
    cursor,changed,nextEvent=eventPosition(index,at,cursor)
    if changed then motion=nil end
    if motion then motion.untilAt=math.min(motion.to.at,nextEvent,index.last) end
    local held,inside=instancePosition(index,at)
    if inside then cursor=held;motion=nil end
    local endEvent=upper(index.events,at,function(row) return row.event.at end)
    for i=endEvent,1,-1 do
        local row=index.events[i];local e=row.event
        local p=project(e,index)
        if p then
            markers[#markers+1]={id=tostring(row.id),name=e.title,mapID=index.mapID,x=p.x,y=p.y,category='other',event=e,alpha=math.min(1,(16-(#markers+1))/6)}
            if #markers==15 then break end
        end
    end
    -- Preserve chronological overlap cycling after selecting the newest markers.
    for i=1,math.floor(#markers/2) do markers[i],markers[#markers-i+1]=markers[#markers-i+1],markers[i] end
    -- Marker limits are intentional; the timeline retains every event.
    return lines,markers,cursor,limited,invalid,motion
end
function A.TrailColor(at,stamp,strength,flight,mount,state,combat)
    strength=ns.Atlas.Number(strength,0,1) and strength or 0.75
    -- Thirty minutes behind the scrubber is halfway cooled. Keep an opacity
    -- floor so old travel remains discoverable, without altering stored history.
    local heat=2^(-math.max(0,at-stamp)/1800)
    local fade=(1-heat)*strength
    if state=='dead' or state=='ghost' or state=='dead / ghost' then return 0.9,0.15,0.25,0.8-0.68*fade,heat end
    if flight then return 0.2-0.1*fade,1-0.35*fade,0.3+0.15*fade,0.8-0.68*fade,heat end
    if combat==true then return 1,0.35,0.05,0.8-0.68*fade,heat end
    if mount==60 then return 0,112/255,221/255,0.8-0.68*fade,heat end
    if mount==100 then return 163/255,53/255,238/255,0.8-0.68*fade,heat end
    return 1-0.75*fade,0.82-0.27*fade,0.14+0.86*fade,0.8-0.68*fade,heat
end
function A.PlayerColor(state,combat,activity)
    if state=='flight' then return 0.2,1,0.3
    elseif state=='dead' or state=='dead / ghost' then return 1,0.25,0.25
    elseif state=='ghost' then return 0.55,0.8,1
    elseif combat==true then return 1,0.35,0.05
    elseif activity=='gathering' then return 1,0.85,0.1
    elseif activity=='idle' then return 0.5,0.5,0.5 end
    return 1,1,1
end
-- Round only connected display edges. Shared endpoint identity distinguishes a
-- real connection from separate recordings which happen to meet on the map.
function A.SmoothTrail(lines,width,height)
    if not width or not height or width<=0 or height<=0 then return lines end
    local incoming,outgoing,corners={},{},{}
    for _,edge in ipairs(lines) do
        if incoming[edge.to]==nil then incoming[edge.to]=edge else incoming[edge.to]=false end
        if outgoing[edge.from]==nil then outgoing[edge.from]=edge else outgoing[edge.from]=false end
    end
    local budget=math.max(0,2048-#lines)
    local function between(a,b,t)
        return {x=a.x+(b.x-a.x)*t,y=a.y+(b.y-a.y)*t,
            at=a.at+(b.at-a.at)*t,mapID=a.mapID,level=a.level,flight=b.flight,mount=b.mount,state=b.state,combat=b.combat}
    end
    -- Prefer recent corners when the existing geometry approaches its budget.
    for i=#lines,1,-1 do
        local edge=lines[i];local p=edge.to;local nextEdge=outgoing[p]
        if budget>=2 and incoming[p]==edge and nextEdge and edge.from.flight==p.flight and p.flight==nextEdge.to.flight and edge.from.mount==p.mount and p.mount==nextEdge.to.mount and edge.from.state==p.state and p.state==nextEdge.to.state and edge.from.combat==p.combat and p.combat==nextEdge.to.combat then
            local dx,dy=(p.x-edge.from.x)*width/10000,(p.y-edge.from.y)*height/10000
            local ex,ey=(nextEdge.to.x-p.x)*width/10000,(nextEdge.to.y-p.y)*height/10000
            local before,after=math.sqrt(dx*dx+dy*dy),math.sqrt(ex*ex+ey*ey)
            if before>0.5 and after>0.5 then
                local dot=(dx*ex+dy*ey)/(before*after)
                if dot>-0.95 and dot<0.9995 then
                    local trim=math.min(6,before*0.2,after*0.2)
                    local first,last=between(edge.from,p,1-trim/before),between(p,nextEdge.to,trim/after)
                    -- The ribbon supports pieces shorter than its stroke.
                    -- Avoid excessive tessellation below a quarter UI pixel.
                    for steps=math.min(6,budget),2,-1 do
                        local curve={};local previous=first;local visible=true
                        for step=1,steps do
                            local t=step/steps
                            local point=step==steps and last or between(between(first,p,t),between(p,last,t),t)
                            local x,y=(point.x-previous.x)*width/10000,(point.y-previous.y)*height/10000
                            if x*x+y*y<0.0625 then visible=false;break end
                            curve[#curve+1]=point;previous=point
                        end
                        if visible then corners[p]={first=first,last=last,curve=curve};budget=budget-steps;break end
                    end
                end
            end
        end
    end
    local result={}
    for _,edge in ipairs(lines) do
        local start,finish=corners[edge.from],corners[edge.to]
        result[#result+1]={from=start and start.last or edge.from,to=finish and finish.first or edge.to}
        if finish then
            local previous=finish.first
            for _,point in ipairs(finish.curve) do
                result[#result+1]={from=previous,to=point};previous=point
            end
        end
    end
    return result
end
-- Shared cross-sections make a continuous ribbon, rather than overlapping
-- translucent square-ended native lines. Coordinates here use UI y-up units.
function A.TrailRibbon(lines,width,height,thickness)
    local incoming,outgoing,normals,sections={},{},{},{}
    for _,edge in ipairs(lines) do
        local dx,dy=(edge.to.x-edge.from.x)*width/10000,-(edge.to.y-edge.from.y)*height/10000
        local length=math.sqrt(dx*dx+dy*dy)
        if length>0.000001 then
            normals[edge]={x=-dy/length,y=dx/length}
            incoming[edge.to]=incoming[edge.to]==nil and edge or false
            outgoing[edge.from]=outgoing[edge.from]==nil and edge or false
        end
    end
    local half=thickness/2
    local function section(p,edge)
        if sections[p] then return sections[p] end
        local n=normals[edge];local x,y=n.x*half,n.y*half
        local before,after=incoming[p],outgoing[p]
        if before and after then
            local a,b=normals[before],normals[after]
            local den=1+a.x*b.x+a.y*b.y
            if den>0.1 then
                x,y=(a.x+b.x)*half/den,(a.y+b.y)*half/den
                local size=math.sqrt(x*x+y*y)
                if size>half*2 then x,y=x*half*2/size,y*half*2/size end
            end
        end
        local cx,cy=p.x*width/10000,-p.y*height/10000
        local cross={{x=cx+x,y=cy+y},{x=cx-x,y=cy-y}}
        if before and after then sections[p]=cross end
        return cross
    end
    local quads={}
    for i,edge in ipairs(lines) do
        if normals[edge] then
            local first,last=section(edge.from,edge),section(edge.to,edge)
            quads[i]={first[1],first[2],last[1],last[2]}
        else quads[i]=false end
    end
    return quads
end
function ns.CreateAnnalsMap(parent,j,onSelect,onNavigate)
    local adapter={lines={},markers={},state=j.db.settings,borderlessPins=true,zoomMarkerGroups=true}
    function adapter:Get(id) if id=='journey' then return {id=id,name='Journey',category='route',stops={{}}} end end
    function adapter:List() return self.markers end
    function adapter:RouteMap()
        local map=self.map
        self.lines=A.SmoothTrail(self.rawLines or {},map:GetWidth()*map.zoom,map:GetHeight()*map.zoom)
        return {},self.lines
    end
    function adapter:DrawRoute(map,pool,segments)
        local quads=A.TrailRibbon(segments,map:GetWidth(),map:GetHeight(),2/map.zoom)
        for i,quad in ipairs(quads) do
            local texture=pool[i]
            if not texture then texture=map.journeyOverlay:CreateTexture(nil,'ARTWORK');pool[i]=texture end
            if quad and type(texture.SetVertexOffset)=='function' then
                local left,right,bottom,top=quad[1].x,quad[1].x,quad[1].y,quad[1].y
                for n=2,4 do
                    left=math.min(left,quad[n].x);right=math.max(right,quad[n].x)
                    bottom=math.min(bottom,quad[n].y);top=math.max(top,quad[n].y)
                end
                local w,h=math.max(0.01,right-left),math.max(0.01,top-bottom)
                texture:ClearAllPoints();texture:SetPoint('TOPLEFT',map.canvas,'TOPLEFT',left,top);texture:SetSize(w,h)
                texture:SetVertexOffset(1,quad[1].x-left,quad[1].y-top)
                texture:SetVertexOffset(2,quad[2].x-left,quad[2].y-(top-h))
                texture:SetVertexOffset(3,quad[3].x-(left+w),quad[3].y-top)
                texture:SetVertexOffset(4,quad[4].x-(left+w),quad[4].y-(top-h))
                if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
                if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
                texture:Show()
            else texture:Hide() end
        end
    end
    function adapter:Layer() return true end
    function adapter:WeatherText() return '' end
    local map=ns.CreateAtlasMap(parent,adapter,onSelect,function() end,onNavigate)
    map.journeyOverlay=CreateFrame('Frame',nil,map.canvas)
    map.journeyOverlay:SetAllPoints(map.canvas)
    map.journeyOverlay:SetFrameLevel(map.canvas:GetFrameLevel()+2)
    map.journeyOverlay:EnableMouse(false)
    adapter.map=map
    local zoomBy=map.ZoomBy
    function map:ZoomBy(delta)
        local previous=self.zoom;zoomBy(self,delta)
        if self.zoom~=previous and self.journeyIndex then self:ShowJourney(self.journeyIndex,self.journeyAt) end
    end
    -- Update hover highlights without reading or replacing the historical arrow.
    function map:ResumePlayer()
        self:SuspendPlayer();self:ShowHistoricalPlayer();self:UpdateRegionHighlight()
        if ns.Atlas.Read(self.IsVisible,self)==false then return end
        local elapsed=0
        self:SetScript('OnUpdate',function(self,dt)
            elapsed=elapsed+dt
            if elapsed>=0.1 then elapsed=0;self:UpdateRegionHighlight() end
        end)
    end
    function map:ShowHistoricalPlayer()
        local p=self.historicalPlayer;local arrow=self.playerArrow;arrow:Hide()
        self.playerCoordinates:SetWidth(self:GetWidth()-16)
        self.playerCoordinates:SetSpacing(1)
        self.playerCoordinates:SetText('Historical journey • No recorded position • '..(self.recordedLevel and ('Level '..self.recordedLevel) or 'Level unknown'))
        if not p or not self.available then return end
        local size=ns.Atlas.Number(j.db.settings.iconSize,6,40) and j.db.settings.iconSize or 20
        arrow:SetSize(size*2,size*2);arrow:ClearAllPoints()
        arrow:SetPoint('CENTER',self.canvas,'TOPLEFT',p.x/10000*self:GetWidth(),-p.y/10000*self:GetHeight())
        local state=p.state or (p.flight and 'flight') or 'unknown'
        arrow:SetVertexColor(A.PlayerColor(state,p.combat,p.activity))
        local activity=state
        if not p.instanceName and (state=='alive' or state=='unknown') then
            if p.combat==true then activity='in combat'
            elseif p.activity=='gathering' then activity='gathering'
            elseif p.activity=='idle' then activity='idle'
            elseif p.combat==false then activity='out of combat' end
        end
        local previous=p.previous
        local angle=previous and math.atan2(-(p.headingX or (p.x-previous.x))*self:GetWidth(),-(p.headingY or (p.y-previous.y))*self:GetHeight()) or 0
        arrow:SetRotation(angle);arrow:Show()
        local level=p.level or self.recordedLevel
        local position=p.instanceName and ('At entrance • '..ns.Atlas.Safe(p.instanceName)) or
            string.format('%s: %.1f, %.1f • %s',p.interpolated and 'Estimated' or 'Recorded',p.x/100,p.y/100,activity)
        self.playerCoordinates:SetText(ns.AtlasUI.Date(math.floor(p.at))..'\n'
            ..position..' • '..(level and ('Level '..level) or 'Level unknown'))
    end
    function map:AdvanceHistoricalPlayer(at)
        local motion=self.playerMotion
        if not motion then return true end
        if at>=motion.untilAt then return false end
        local p=A.InterpolatePosition(motion.from,motion.to,at)
        if not p then return false end
        self.historicalPlayer=p;self:ShowHistoricalPlayer();return true
    end
    function map:PanToHistoricalPlayer()
        local p=self.historicalPlayer
        if not p or not self.available then return false end
        self:CancelPan()
        self.panX=math.max(0,math.min(self:GetWidth()*(self.zoom-1),p.x/10000*self:GetWidth()*self.zoom-self:GetWidth()/2))
        self.panY=math.max(0,math.min(self:GetHeight()*(self.zoom-1),p.y/10000*self:GetHeight()*self.zoom-self:GetHeight()/2))
        self.canvas:ClearAllPoints();self.canvas:SetPoint('TOPLEFT',self,'TOPLEFT',-self.panX/self.zoom,self.panY/self.zoom)
        return true
    end
    function map:CenterHistoricalPlayer(zoom)
        if not self.historicalPlayer or not self.available then return false end
        -- At full extent panning has no effect. Retain a closer view.
        zoom=math.max(2,zoom or self.zoom)
        if zoom~=self.zoom then self.zoom=zoom;self:ShowJourney(self.journeyIndex,self.journeyAt) end
        return self:PanToHistoricalPlayer()
    end
    function map:ShowJourney(index,at)
        local cursor,limited,invalid
        self.journeyIndex,self.journeyAt=index,at
        adapter.rawLines,adapter.markers,cursor,limited,invalid,self.playerMotion=A.JourneyFrame(index,at)
        table.sort(adapter.rawLines,function(a,b) return a.to.at<b.to.at end)
        self.historicalPlayer=cursor
        self:Render(index.mapID,'journey');self:ResumePlayer()
        local cutoff=math.max(index.first,math.min(index.last,at))
        for i,segment in ipairs(adapter.lines) do
            local line=self.lines and self.lines[i]
            if line then
                -- A map/chunk join can end at a newly observed combat state.
                -- The connecting interval still belongs to its starting state.
                local r,g,b,alpha,heat=A.TrailColor(cutoff,segment.to.at,j.db.settings.trailContrast,segment.to.flight,segment.to.mount,segment.to.state,segment.from.combat)
                line:SetColorTexture(r,g,b,alpha)
                line:SetDrawLayer('ARTWORK',heat>=0.5 and 1 or 0)
            end
        end
        for _,pin in ipairs(self.pins or {}) do if pin.group and pin:IsShown() then
            pin:SetFrameLevel(self.canvas:GetFrameLevel()+1)
            local representative=pin.group[1].point
            local event=representative.event
            local priority={hearth=3,teleport=3,crossing=3,battleground=3,instance=3,flight=2}
            for _,member in ipairs(pin.group) do
                local other=member.point.event;local rank,selected=priority[other.kind] or 0,priority[event.kind] or 0
                if rank>selected or (rank==selected and (other.at>event.at or (other.at==event.at and (other.sequence or 0)>(event.sequence or 0)))) then event=other;representative=member.point end
            end
            -- Keep a grouped travel icon at its own recorded departure/arrival.
            pin:ClearAllPoints()
            pin:SetPoint('CENTER',self.canvas,'TOPLEFT',representative.x/10000*self:GetWidth(),-representative.y/10000*self:GetHeight())
            local alpha=0
            for _,member in ipairs(pin.group) do alpha=math.max(alpha,member.point.alpha or 1) end
            pin:SetAlpha(alpha*0.6)
            self:SetPinIcon(pin,A.icons[event.kind]);pin.icon:SetVertexColor(1,1,1)
            A.InstanceDirection(pin,pin.icon,event,nil,pin:GetWidth()/20)
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
                local recent={}
                for _,member in ipairs(p.group) do recent[#recent+1]=member end
                table.sort(recent,function(a,b)
                    local first,last=a.point.event,b.point.event
                    if first.at~=last.at then return first.at>last.at end
                    return (first.sequence or tonumber(a.id) or 0)>(last.sequence or tonumber(b.id) or 0)
                end)
                for n=1,math.min(3,#recent) do
                    local m=recent[n]
                    if n>1 then GameTooltip:AddLine(' ',1,1,1) end
                    GameTooltip:AddLine(A.EventText(m.point.event,true),1,1,1,true)
                end
                if #recent>3 then GameTooltip:AddLine('Showing the most recent 3 events; '..(#recent-3)..' more older events.',0.6,0.6,0.6,true) end
                if #p.group>1 then GameTooltip:AddLine('Click repeatedly to cycle overlapping events.',1,0.82,0.14,true) end
                GameTooltip:Show()
            end)
        end end
        return cursor,limited,invalid
    end
    return map
end
