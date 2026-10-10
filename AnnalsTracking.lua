local _,ns=...
local A=ns.Annals
local function recapLink()
    local link=A.Read(C_DeathRecap and C_DeathRecap.GetRecapLink or GetDeathRecapLink)
    return A.Text(link,2048) and link or nil
end
local function deathCapture(j)
    local d={units={},lastRecap=recapLink()}
    function d:Observe(unit)
        local guid=A.Read(UnitGUID,unit)
        if not A.Text(guid,128) or guid=='' then return end
        local level=A.Read(UnitLevel,unit)
        local player=A.Read(UnitIsPlayer,unit)
        local row={at=A.Now(),level=A.Int(level,1,1000) and level or nil,player=player==true}
        if row.player then
            local race,class=A.Read(UnitRace,unit),A.Read(UnitClass,unit)
            row.race=A.RewardName(race);row.class=A.RewardName(class)
        end
        self.units[guid]=row
        local count=0
        for key,value in pairs(self.units) do
            if A.Now()-value.at>30 then self.units[key]=nil else count=count+1 end
        end
        if count>128 then self.units={[guid]=row} end
    end
    function d:Snapshot(guid,name,environment)
        if A.Text(environment,40) and environment~='' then return {environment=environment} end
        if not A.RewardName(name) then return end
        local result={name=name}
        if A.Text(guid,128) and guid~='' then
            for _,unit in ipairs({'target','mouseover','focus'}) do self:Observe(unit) end
            local observed=self.units[guid]
            if observed and A.Now()-observed.at<=30 then
                result.level=observed.level;result.race=observed.race;result.class=observed.class
            end
            result.player=guid:match('^Player%-')~=nil
            if result.player then
                local class=A.Read(GetPlayerInfoByGUID,guid)
                local race=A.Read(function() return select(3,GetPlayerInfoByGUID(guid)) end)
                result.class=A.RewardName(class) or result.class;result.race=A.RewardName(race) or result.race
            else result.race=nil;result.class=nil end
        end
        return result
    end
    function d:Save(killer)
        if not killer or not self.pending or A.Now()-self.pending.at>2 then return end
        self.pending.killer=killer;j.revision=j.revision+1
        if j.onChange then j.onChange() end
    end
    function d:Combat()
        if type(CombatLogGetCurrentEventInfo)~='function' then return end
        local ok,_,event,_,guid,name,_,_,dest,_,_,_,p1,p2,p3,p4,p5=pcall(CombatLogGetCurrentEventInfo)
        local player=A.Read(UnitGUID,'player')
        if not ok or not A.Text(event,80) or not A.Text(dest,128) or not A.Text(player,128) or dest~=player then return end
        local overkill,environment
        if event=='SWING_DAMAGE' then overkill=p2
        elseif event=='ENVIRONMENTAL_DAMAGE' then overkill=p3;environment=p1
        elseif event=='SPELL_DAMAGE' or event=='SPELL_PERIODIC_DAMAGE' or event=='RANGE_DAMAGE' or event=='SPELL_BUILDING_DAMAGE' then overkill=p5
        else return end
        -- Nonlethal damage must never become a guessed killer.
        self.blow=nil
        if not A.Int(overkill,0,2147483647) then return end
        local killer=self:Snapshot(guid,name,environment)
        if killer then
            killer.ability=event=='SWING_DAMAGE' and 'Melee attack' or (not environment and A.RewardName(p2) or nil)
            killer.spellID=event~='SWING_DAMAGE' and not environment and A.Int(p1,1,2147483647) and p1 or nil
        end
        if killer then self.blow={at=A.Now(),killer=killer};self:Save(killer) end
    end
    function d:Recap()
        if not self.pending or A.Now()-self.pending.at>2 then return end
        local link=recapLink()
        if not link or link==self.lastRecap then return end
        local events=A.Read(C_DeathRecap and C_DeathRecap.GetRecapEvents or DeathRecap_GetEvents)
        local first=type(events)=='table' and A.Read(function() return events[1] end)
        if type(first)~='table' then return end
        -- Blizzard's recap places the fatal event first. Never reuse an old recap.
        self.lastRecap=link
        local function field(key) return A.Read(function() return first[key] end) end
        if field('hideCaster')==true then return end
        if self.pending.killer then return end
        local killer=self:Snapshot(field('sourceGUID'),field('sourceName'),field('environmentalType'))
        if killer then
            killer.ability=field('event')=='SWING_DAMAGE' and 'Melee attack' or A.RewardName(field('spellName'))
            local spellID=field('spellId')
            killer.spellID=A.Int(spellID,1,2147483647) and spellID or nil
        end
        self:Save(killer)
    end
    function d:Reset()
        self.pending=nil;self.blow=nil;self.units={};self.lastRecap=recapLink()
    end
    return d
end
-- Travel spells, not portal-creation spells: creating a portal does not move
-- its caster. IDs avoid depending on the client's localized spell names.
local travelSpells={
    [8690]='hearth', [556]='hearth', -- Hearthstone, Astral Recall
    [3561]='teleport',[3562]='teleport',[3563]='teleport',
    [3565]='teleport',[3566]='teleport',[3567]='teleport', -- Classic capital teleports
    [18960]='teleport', -- Teleport: Moonglade
}
local gatheringEvents={UNIT_SPELLCAST_START=true,UNIT_SPELLCAST_STOP=true,UNIT_SPELLCAST_SUCCEEDED=true,
    UNIT_SPELLCAST_FAILED=true,UNIT_SPELLCAST_FAILED_QUIET=true,UNIT_SPELLCAST_INTERRUPTED=true}
local function travelContext()
    local location=A.Location()
    local instance=A.Read(function() local _,kind=IsInInstance();return kind end)
    local continent,id=nil,location.mapID
    for _=1,12 do
        if not A.Int(id,1,2147483647) then break end
        local info=A.Read(C_Map and C_Map.GetMapInfo,id)
        if type(info)~='table' then break end
        local kind=A.Read(function() return info.mapType end)
        if kind==2 then continent=id;break end
        id=A.Read(function() return info.parentMapID end)
    end
    local name=A.Read(GetInstanceInfo)
    local instanceID=A.Read(function() return select(8,GetInstanceInfo()) end)
    return {location=location,instance=A.Text(instance,40) and instance or nil,continent=continent,
        name=A.Text(name,160) and name or location.zone,
        instanceID=A.Int(instanceID,1,2147483647) and instanceID or nil}
end
local function title(id)
    local text=A.Read(C_QuestLog and C_QuestLog.GetTitleForQuestID,id)
    if not A.Text(text,240) and A.Read(GetQuestID)==id then text=A.Read(GetTitleText) end
    return A.Text(text,240) and text or nil
end
local function item(kind,index,questID)
    local lootType=questID and (kind=='choice' and A.Read(GetQuestLogChoiceInfoLootType,index) or 0) or A.Read(GetQuestItemInfoLootType,kind,index)
    if lootType==1 then
        local v
        if questID then v=A.Read(C_QuestLog and C_QuestLog.GetQuestRewardCurrencyInfo,questID,index,kind=='choice')
        else v=A.Read(C_QuestOffer and C_QuestOffer.GetQuestRewardCurrencyInfo,kind,index) end
        if type(v)=='table' and A.Int(v.currencyID,1,2147483647) and A.Int(v.totalRewardAmount,0,2147483647) then
            return {currencyID=v.currencyID,quantity=v.totalRewardAmount,name=A.RewardName(v.name),
                icon=A.Int(v.texture,1,2147483647) and v.texture or nil,quality=A.Int(v.quality,0,8) and v.quality or nil,offered=true}
        end
        return
    end
    local fn=GetQuestItemInfo
    if questID then if kind=='choice' then fn=GetQuestLogChoiceInfo else fn=GetQuestLogRewardInfo end end
    if type(fn)~='function' then return end
    local ok,name,icon,count,quality,_,id
    if questID then ok,name,icon,count,quality,_,id=pcall(fn,index)
    else ok,name,icon,count,quality,_,id=pcall(fn,kind,index) end
    if not ok then return end
    local link
    if questID then link=A.Read(GetQuestLogItemLink,kind,index) else link=A.Read(GetQuestItemLink,kind,index) end
    if not A.Int(id,1,2147483647) then
        id=A.Text(link,2048) and tonumber(link:match('item:(%d+)')) or nil
    end
    if not A.Int(id,1,2147483647) or not A.Int(count,1,1000000) then return end
    local data=A.Text(link,2048) and link:match('|H(item:[%d:%-]+)|h') or nil
    return {itemID=id,quantity=count,name=A.RewardName(name),icon=A.Int(icon,1,2147483647) and icon or nil,
        quality=A.Int(quality,0,8) and quality or nil,link=data and tonumber(data:match('^item:(%d+)'))==id and data or nil}
end
function A.RewardSnapshot(questID)
    local id=questID or A.Read(GetQuestID);if not A.Int(id,1,2147483647) then return end
    local choices,rewards,xp,money
    if questID then
        choices=A.Read(GetNumQuestLogChoices,id,true);rewards=A.Read(GetNumQuestLogRewards)
        xp,money=A.Read(GetQuestLogRewardXP),A.Read(GetQuestLogRewardMoney)
    else
        choices,rewards=A.Read(GetNumQuestChoices),A.Read(GetNumQuestRewards)
        xp,money=A.Read(GetRewardXP),A.Read(GetRewardMoney)
    end
    local snapshotTitle
    if questID then snapshotTitle=A.Read(C_QuestLog and C_QuestLog.GetTitleForQuestID,id) else snapshotTitle=A.Read(GetTitleText) end
    local s={questID=id,at=A.Now(),title=snapshotTitle,choices={},automatic={},status='observed',choiceStatus='unknown'}
    local description,objective
    if questID then
        description=A.Read(GetQuestLogQuestText)
        objective=A.Read(function() local _,text=GetQuestLogQuestText();return text end)
    else
        description=A.Read(GetQuestText);objective=A.Read(GetObjectiveText)
    end
    s.questText=A.QuestText(description) and description or nil
    s.objectiveText=A.QuestText(objective) and objective or nil
    s.offeredXP=A.Int(xp,0,2147483647) and xp or nil;s.offeredMoney=A.Int(money,0,2147483647) and money or nil
    if not A.Int(choices,0,64) or not A.Int(rewards,0,64) then s.status='incomplete';return s end
    s.count=choices;s.automaticCount=rewards;if choices==0 then s.choiceStatus='none' end
    for i=1,choices do s.choices[i]=item('choice',i,questID);if not s.choices[i] then s.status='incomplete' end end
    for i=1,rewards do local v=item('reward',i,questID);if v then s.automatic[#s.automatic+1]=v else s.status='incomplete' end end
    local currencies=A.Read(C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardCurrencies,id)
    s.currencyStatus='unknown'
    if type(currencies)=='table' then
        s.currencyOffers={};s.currencyStatus='offered amounts'
        for i,v in ipairs(currencies) do
            if i>64 then s.currencyStatus='incomplete';break end
            if type(v)=='table' and A.Int(v.currencyID,1,2147483647) and A.Int(v.totalRewardAmount,0,2147483647) then
                s.currencyOffers[#s.currencyOffers+1]={currencyID=v.currencyID,quantity=v.totalRewardAmount,name=A.RewardName(v.name),
                    icon=A.Int(v.texture,1,2147483647) and v.texture or nil,quality=A.Int(v.quality,0,8) and v.quality or nil}
            else s.currencyStatus='incomplete' end
        end
    end
    local spells=A.Read(C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardSpells,id)
    if type(spells)=='table' then
        s.spellOffers={}
        for i,spellID in ipairs(spells) do
            if i>64 then s.status='incomplete';break end
            if A.Int(spellID,1,2147483647) then
                local info=A.Read(C_QuestInfoSystem.GetQuestRewardSpellInfo,id,spellID)
                s.spellOffers[#s.spellOffers+1]={spellID=spellID,quantity=1,
                    name=type(info)=='table' and A.RewardName(info.name) or nil,
                    icon=type(info)=='table' and A.Int(info.texture,1,2147483647) and info.texture or nil}
            else s.status='incomplete' end
        end
    end
    -- Offers are not measured balance changes or proof a spell was learned.
    s.otherRewards='reputation not captured'
    return s
end
function A.CanReadLogRewards()
    return C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID)=='function' and type(C_QuestLog.GetInfo)=='function'
        and type(C_QuestLog.GetSelectedQuest)=='function' and type(C_QuestLog.SetSelectedQuest)=='function'
        and type(GetNumQuestLogChoices)=='function' and type(GetNumQuestLogRewards)=='function'
        and type(GetQuestLogChoiceInfo)=='function' and type(GetQuestLogRewardInfo)=='function'
end
function A.LogRewardSnapshot(id)
    if not A.CanReadLogRewards() or A.logRewardReading then return end
    local index=A.Read(C_QuestLog.GetLogIndexForQuestID,id)
    local info=A.Int(index,1,1000) and A.Read(C_QuestLog.GetInfo,index)
    if type(info)~='table' or A.Read(function() return info.questID end)~=id then return end
    local selected=A.Read(C_QuestLog.GetSelectedQuest)
    if not A.Int(selected,0,2147483647) then return end
    A.logRewardReading=true
    local ok,snapshot=pcall(function()
        if selected~=id then C_QuestLog.SetSelectedQuest(id) end
        if A.Read(C_QuestLog.GetSelectedQuest)~=id then return end
        return A.RewardSnapshot(id)
    end)
    local restored=true
    if selected~=id then restored=pcall(C_QuestLog.SetSelectedQuest,selected) end
    A.logRewardReading=nil
    if ok and restored then return snapshot end
end
local function recoverRewards(original,candidate)
    if not candidate or candidate.status~='observed' then return end
    original=original or {}
    for _,key in ipairs({'count','automaticCount'}) do
        if original[key]~=nil and original[key]~=candidate[key] then return end
    end
    local result=A.Copy(candidate)
    local function same(a,b)
        return b and a.itemID==b.itemID and a.currencyID==b.currencyID and a.spellID==b.spellID and a.quantity==b.quantity
    end
    for i,v in pairs(original.choices or {}) do
        if not same(v,result.choices[i]) then return end
        for key,value in pairs(v) do result.choices[i][key]=value end
    end
    for _,v in ipairs(original.automatic or {}) do
        local found
        for _,other in ipairs(result.automatic or {}) do
            if same(v,other) then for key,value in pairs(v) do other[key]=value end;found=true;break end
        end
        if not found then return end
    end
    for _,key in ipairs({'questText','objectiveText','offeredXP','offeredMoney','currencyOffers','currencyStatus','spellOffers','otherRewards'}) do
        if original[key]~=nil then result[key]=A.Copy(original[key]) end
    end
    result.questID,result.at,result.title=nil,nil,nil
    result.captureSource='quest log after acceptance';result.capturedAt=A.Now()
    return result
end
function ns.CreateAnnalsTracking(j)
    local t={journal=j,capabilities={},loading=false};local db=j.db
    local deaths=deathCapture(j)
    j.sessionStart=A.Int(db.sessionStart,0,A.Now()) and db.sessionStart or A.Now()
    local reward,offer,abandon=nil,nil,nil
    local rewardIndex,rewardClosed
    local function later(delay,fn)
        if C_Timer and type(C_Timer.After)=='function' then C_Timer.After(delay,fn);return true end
    end
    function t:RestoreInstanceVisit()
        if self.visitLoaded then return end
        self.visitLoaded=true
        local rows=j:Range(0,A.Now(),'instance');local last=rows[#rows]
        if last and last.event.instanceAction=='enter' then self.instanceVisit=last.event end
    end
    function t:LeaveInstance(location,at)
        local visit=self.instanceVisit
        if not visit then return end
        j.trail:Break('instance exit')
        j:Append('instance','Instance exit — '..(visit.instanceName or 'Unknown instance'),
            {instanceAction='exit',instanceName=visit.instanceName,instanceID=visit.instanceID},location,at)
        j.trail:Break('instance exit');self.instanceVisit=nil
    end
    function t:ObserveInstance(context,entrance,at)
        self:RestoreInstanceVisit()
        local visit=self.instanceVisit
        if not A.JourneyInstance(context.instance) then
            if context.instance then self:LeaveInstance(context.location,at) end
            return
        end
        if visit and ((visit.instanceID and visit.instanceID==context.instanceID)
            or ((not visit.instanceID or not context.instanceID) and visit.instanceName==context.name)) then return end
        -- A reload inside the same instance reuses its observed entrance. A
        -- login inside an unobserved instance must not invent an outdoor point.
        if visit then self:LeaveInstance({},at) end
        local location=A.Copy(entrance or {});location.instanceType=nil
        j.trail:Break('instance entry')
        self.instanceVisit=j:Append('instance','Instance entry — '..(context.name or 'Unknown instance'),
            {instanceAction='enter',instanceName=context.name,instanceID=context.instanceID},location,at)
        j.trail:Break('instance interior')
    end
    function t:CheckWorldTransfer()
        local transfer=self.worldTransfer
        if not transfer or self.loading or j.readOnly or ns.InitializationBlocked then return end
        local elapsed=A.Now()-(transfer.readyAt or transfer.at)
        if elapsed>30 then self.worldTransfer=nil;return end
        local from,to=transfer.from,travelContext()
        if A.JourneyInstance(from.instance) or A.JourneyInstance(to.instance) then
            if not to.instance then return end
            if not A.JourneyInstance(to.instance) and not (A.Int(to.location.x,0,10000) and A.Int(to.location.y,0,10000)) and elapsed<10 then return end
            self:RestoreInstanceVisit()
            local entrance=not A.JourneyInstance(from.instance) and from.location or nil
            if A.JourneyInstance(from.instance) and A.JourneyInstance(to.instance) and self.instanceVisit then
                entrance={mapID=self.instanceVisit.mapID,x=self.instanceVisit.x,y=self.instanceVisit.y,
                    zone=self.instanceVisit.zone,subzone=self.instanceVisit.subzone,level=to.location.level}
            end
            self:ObserveInstance(to,entrance,A.JourneyInstance(to.instance) and transfer.at or A.Now())
            self.worldTransfer=nil;self.travelContext=to
            -- Hearths and teleports out still retain their confirmed arrival.
            if self.lastTravel and not self.lastTravel.arrived and transfer.at-self.lastTravel.at>=-2 and transfer.at-self.lastTravel.at<=15 then
                self.lastTravel.arrived=true;j.trail:Break('world transfer arrival')
                j:Append(self.lastTravel.kind,self.lastTravel.name..' — arrival',nil,to.location,A.Now())
            end
            return
        end
        local kind,name
        if from.instance and to.instance and from.instance~='pvp' and to.instance=='pvp' then
            kind,name='battleground','Battleground entry'
        elseif from.instance=='pvp' and to.instance and to.instance~='pvp' then
            kind,name='battleground','Battleground exit'
        elseif self.lastTravel and not self.lastTravel.arrived and transfer.at-self.lastTravel.at>=-2
            and transfer.at-self.lastTravel.at<=15 then
            kind,name=self.lastTravel.kind,self.lastTravel.name
        elseif from.instance=='none' and to.instance=='none' and from.continent and to.continent and from.continent~=to.continent then
            -- A changed continent proves a crossing, not which vessel or portal
            -- carried the player. Do not turn ordinary loading into teleports.
            kind,name='crossing','Cross-continent travel'
        end
        if not kind then return end
        if not (A.Int(to.location.x,0,10000) and A.Int(to.location.y,0,10000)) and elapsed<10 then return end
        self.worldTransfer=nil
        if kind=='hearth' or kind=='teleport' then
            self.lastTravel.arrived=true
        else
            j.trail:Break('world transfer departure')
            j:Append(kind,name..' — departure',nil,from.location,transfer.at)
        end
        j.trail:Break('world transfer arrival')
        j:Append(kind,name..' — arrival',nil,to.location,A.Now())
        self.travelContext=to
    end
    function t:Flush(id,force)
        if j.readOnly or ns.InitializationBlocked then return end
        local p=db.pending[id];if type(p)~='table' then return end
        local r=p.reward
        if p.kind=='accepted' then
            if A.Now()-p.at<=10 and (not A.Int(p.lastAttempt,0,9999999999) or p.lastAttempt<A.Now() or force) then
                p.lastAttempt=A.Now();self.readingRewards=true
                local recovered=recoverRewards(r,A.LogRewardSnapshot(id));self.readingRewards=nil
                if recovered then r=recovered;p.reward=r end
            end
            if r and r.status~='observed' and not force and A.Now()-p.at<10 then return end
        end
        if p.kind=='completed' then
            r=r or {status='unknown',choiceStatus='unknown'}
            if p.snapshot then
                r=A.Copy(p.snapshot);r.questID,r.at,r.title,r.count,r.choices=nil,nil,nil,nil,nil
            end
            -- The turn-in dialogue may no longer expose the original quest text.
            -- Reuse only this quest cycle's observed acceptance, never an older one.
            if not r.questText or not r.objectiveText then
                for i=#db.events,1,-1 do
                    local previous=db.events[i]
                    if A.ValidEvent(previous) and previous.questID==id then
                        if previous.kind=='accepted' then
                            local accepted=previous.reward or {}
                            r.questText=r.questText or accepted.questText
                            r.objectiveText=r.objectiveText or accepted.objectiveText
                            break
                        elseif previous.kind=='removed' or previous.kind=='completed' then break end
                    end
                end
            end
            r.xp=p.xp;r.money=p.money
        end
        j:Quest(p.kind,id,p.title,r,p.location,p.at,p.token,p.sequence,p.kind=='accepted')
        db.pending[id]=nil
        if p.kind=='completed' and reward and reward.token==p.token then reward=nil;rewardIndex=nil end
    end
    function t:RetryAcceptances()
        if self.readingRewards or A.logRewardReading or self.acceptanceRetry then return end
        self.acceptanceRetry=true
        local function retry()
            self.acceptanceRetry=nil
            for id,p in pairs(db.pending) do if p.kind=='accepted' then t:Flush(id) end end
        end
        if not later(0.1,retry) then retry() end
    end
    function t:RefreshReward()
        if not reward or rewardClosed or A.Now()-reward.at>600 or A.Read(GetQuestID)~=reward.questID then return end
        local candidate=A.RewardSnapshot()
        if not candidate or candidate.questID~=reward.questID then return end
        local fresh=recoverRewards(reward,candidate)
        if not fresh then return end
        fresh.questID,fresh.at,fresh.title,fresh.token=reward.questID,reward.at,reward.title,reward.token
        fresh.captureSource,fresh.capturedAt=nil,nil
        -- Preserve the dialogue object so its delayed close callback still owns it.
        for k,v in pairs(fresh) do reward[k]=v end
        if rewardIndex~=nil then self:RewardRequested(rewardIndex) end
    end
    function t:RewardRequested(index)
        if j.readOnly or ns.InitializationBlocked or not reward or A.Now()-reward.at>600 or not A.Int(index,0,64) then return end
        -- Retries within one reward dialogue are one transaction. A new dialogue
        -- or accepted quest cycle can legitimately produce another completion.
        reward.token=reward.token or tostring(j:Sequence())
        rewardIndex=index
        reward.chosen=reward.choices[index];reward.choiceStatus=reward.chosen and 'observed' or (reward.count==0 and 'none' or 'unknown')
        if reward.count==1 and reward.chosen then
            reward.single=reward.chosen;reward.chosen=nil;reward.choiceStatus='single automatic option'
        end
        -- QUEST_TURNED_IN can fire synchronously before a secure post-hook.
        local p=db.pending[reward.questID]
        if p and p.kind=='completed' and p.token==reward.token and p.at>=reward.at then p.snapshot=A.Copy(reward) end
    end
    function t:Seed()
        if j.readOnly or ns.InitializationBlocked then return end
        local count=A.Read(C_QuestLog and C_QuestLog.GetNumQuestLogEntries)
        if not A.Int(count,0,1000) then return end
        -- One login baseline, never a repeated quest-log scan or invented acceptance.
        for i=1,count do local info=A.Read(C_QuestLog.GetInfo,i)
            local id=type(info)=='table' and A.Read(function() return info.questID end)
            local header=type(info)=='table' and A.Read(function() return info.isHeader end)
            local name=type(info)=='table' and A.Read(function() return info.title end)
            if A.Int(id,1,2147483647) and header==false then
                local old=db.quests[id]
                if type(old)~='table' or old.kind~='accepted' then
                    db.quests[id]={kind='baseline',title=A.Text(name,240) and name or nil}
                end
            end
        end
    end
    function t:GatheringEvent(event,unit,guid,spellID)
        if self.loading or not A.Text(unit,40) or unit~='player' or not A.Text(guid,160)
            or not A.Int(spellID,1,2147483647) or not ns.GatheringCastKind then return end
        local gathering=ns.GatheringCastKind(spellID)
        local cast=self.gatheringCast
        if event=='UNIT_SPELLCAST_START' then
            if not gathering and not cast then return end
            self.gatheringCast=gathering and {guid=guid,spellID=spellID,at=A.Now()} or nil
        else
            if cast then
                if guid~=cast.guid or spellID~=cast.spellID then return end
            elseif not gathering then return end
            self.gatheringCast=nil;gathering=nil
        end
        self.gatheringObservedAt=gathering and A.Now() or nil
        local p=A.Location();p.at=A.Now();p.activity=gathering and 'gathering' or false
        j.trail:Sample(p)
    end
    function t:Event(event,id,xp,money)
        if j.readOnly or ns.InitializationBlocked then return end
        if event=='COMBAT_LOG_EVENT_UNFILTERED' then deaths:Combat();return end
        if event=='PLAYER_TARGET_CHANGED' or event=='UPDATE_MOUSEOVER_UNIT' or event=='NAME_PLATE_UNIT_ADDED' then
            deaths:Observe(event=='PLAYER_TARGET_CHANGED' and 'target' or event=='UPDATE_MOUSEOVER_UNIT' and 'mouseover' or id);return
        end
        if gatheringEvents[event] then
            self:GatheringEvent(event,id,xp,money)
            if event=='UNIT_SPELLCAST_STOP' or event=='UNIT_SPELLCAST_FAILED_QUIET' then return end
        end
        if event=='PLAYER_REGEN_DISABLED' or event=='PLAYER_REGEN_ENABLED' then
            if not t.loading then
                local p=A.Location();p.at=A.Now();p.combat=event=='PLAYER_REGEN_DISABLED'
                j.trail:Sample(p)
            end
            return
        end
        -- Classic sends (questLogIndex, questID); other clients send only
        -- questID. Never use a reusable log slot as a historical identity.
        if event=='QUEST_ACCEPTED' and xp~=nil then id=xp end
        if event=='QUEST_LOG_UPDATE' or event=='QUEST_DATA_LOAD_RESULT' or event=='GET_ITEM_INFO_RECEIVED' then
            if next(db.pending) then t:RetryAcceptances() end;return
        end
        if event=='UNIT_SPELLCAST_START' or event=='UNIT_SPELLCAST_SUCCEEDED'
            or event=='UNIT_SPELLCAST_FAILED' or event=='UNIT_SPELLCAST_INTERRUPTED' then
            -- These events supply unit, cast GUID, spell ID in the three slots.
            if not A.Text(id,40) or id~='player' or not A.Int(money,1,2147483647) then return end
            local kind=travelSpells[money];if not kind then return end
            local guid=A.Text(xp,160) and xp or nil
            if event=='UNIT_SPELLCAST_START' then
                t.travelCast={spellID=money,guid=guid,at=A.Now(),location=A.Location()}
            elseif event=='UNIT_SPELLCAST_SUCCEEDED' then
                if guid and t.lastTravelGUID==guid then return end
                local cast=t.travelCast
                local matched=cast and cast.spellID==money and cast.guid==guid and A.Now()-cast.at<=60
                local recent=t.travelPosition and A.Now()-t.travelPosition.at<=4 and t.travelPosition
                -- Never label an already-updated destination as the departure.
                local location=matched and cast.location or recent or {}
                local info=A.Read(C_Spell and C_Spell.GetSpellInfo,money)
                local name=type(info)=='table' and A.Read(function() return info.name end) or A.Read(GetSpellInfo,money)
                if not A.Text(name,200) then name=kind=='hearth' and 'Hearth / recall' or 'Teleport' end
                j:Append(kind,name..' — departure',{spellID=money},location,A.Now())
                t.lastTravel={kind=kind,name=name,at=A.Now()}
                j.trail:Break('hearth or teleport');t.travelCast=nil;t.travelPosition=nil;t.lastTravelGUID=guid
            elseif t.travelCast and t.travelCast.spellID==money and t.travelCast.guid==guid then
                t.travelCast=nil
            end
            return
        end
        if event=='PLAYER_ENTERING_WORLD' then
            deaths:Reset()
            t.gatheringCast=nil;t.gatheringObservedAt=nil
            if not t.sessionStarted and (id==true or xp==true) then
                t.sessionStarted=true
                if (id==true and xp~=true) or not A.Int(db.sessionStart,0,A.Now()) then db.sessionStart=A.Now() end
                j.sessionStart=db.sessionStart
                local exit=db.sessionLogout
                if id==true and xp~=true then
                    if A.ValidEvent(exit) and exit.kind=='logout' then
                        j:Append('logout',exit.title,{sequence=exit.sequence},exit,exit.at,true)
                    end
                    j.trail:Break('login')
                    local entry,index=j:Append('login','Logged in',nil,A.Location(),A.Now())
                    -- Zone and map APIs can still be empty on the initial
                    -- entering-world event. Enrich only this new session entry.
                    if entry and (not entry.zone or entry.zone=='' or not entry.mapID or not entry.x or not entry.y) then
                        local pending={entry=entry,index=index};t.loginLocation=pending
                        for _,delay in ipairs({1,2,3,5,10}) do later(delay,function()
                            if t.loginLocation~=pending or t.loading or j.readOnly or ns.InitializationBlocked then return end
                            if db.events[index]~=entry then t.loginLocation=nil;return end
                            local location=A.Location();local changed=false
                            -- A retry on another map cannot describe the login location.
                            if entry.mapID and location.mapID~=entry.mapID then
                                if delay==10 then t.loginLocation=nil end
                                return
                            end
                            if (entry.zone and entry.zone~='' and location.zone~=entry.zone)
                                or (entry.subzone and entry.subzone~='' and location.subzone~=entry.subzone) then
                                if delay==10 then t.loginLocation=nil end
                                return
                            end
                            for _,key in ipairs({'zone','subzone','mapID','x','y','level'}) do
                                if (entry[key]==nil or entry[key]=='') and location[key]~=nil and location[key]~='' then
                                    entry[key]=location[key];changed=true
                                end
                            end
                            if entry.zone and entry.zone~='' and entry.mapID and entry.x and entry.y or delay==10 then t.loginLocation=nil end
                            if changed then
                                j.revision=j.revision+1
                                if j.onChange then j.onChange(index) end
                            end
                        end) end
                    end
                end
                db.sessionLogout=nil
            end
            t.travelPosition=nil
            if id==true or xp==true then t.beforeWorld=nil;t.worldTransfer=nil;t.lastTravel=nil;t.travelCast=nil end
            if t.beforeWorld then t.worldTransfer=t.beforeWorld;t.worldTransfer.readyAt=A.Now();t.beforeWorld=nil end
            t.travelContext=travelContext()
            t.loading=false;t.taxi=nil;t.taxiOrigin=nil;t.ground=nil;j.trail:Break('session or loading')
            if not t.worldTransfer then t:ObserveInstance(t.travelContext,nil,A.Now()) end
            local dead=A.Read(UnitIsDeadOrGhost,'player');t.dead=dead==true or dead==1
            if not t.entered then t.entered=true;t:Seed() end
            later(1,function() t:CheckWorldTransfer() end)
            return
        end
        if event=='PLAYER_LEAVING_WORLD' or event=='PLAYER_LOGOUT' then
            deaths:Reset()
            t.gatheringCast=nil;t.gatheringObservedAt=nil
            t.loginLocation=nil
            local logoutLocation=event=='PLAYER_LOGOUT' and t.beforeWorld and t.beforeWorld.from.location
            if event=='PLAYER_LEAVING_WORLD' and not t.loading then
                local context=travelContext()
                -- The map may already have switched when leaving-world fires.
                -- Prefer a fresh doorway position only while context agrees.
                if t.travelContext and (context.instance~=t.travelContext.instance or context.location.mapID~=t.travelContext.location.mapID) then context=t.travelContext end
                t.beforeWorld={from=context,at=A.Now()};t.worldTransfer=nil
            elseif event=='PLAYER_LOGOUT' then t.beforeWorld=nil;t.worldTransfer=nil;t.lastTravel=nil end
            t.travelPosition=nil
            if event=='PLAYER_LOGOUT' then
                t.travelCast=nil
                if not t.sessionEnded then
                    t.sessionEnded=true
                    local location=logoutLocation or A.Location()
                    local exit=A.Copy(location);exit.kind='logout';exit.title='Logged out';exit.at=A.Now();exit.sequence=j:Sequence()
                    if A.ValidEvent(exit) then db.sessionLogout=exit end
                end
            end
            t.loading=true;j.trail:Break('loading')
            for key in pairs(db.pending) do t:Flush(key) end;return
        end
        -- Subzone names change repeatedly during a flight. Exact map changes and
        -- discontinuities are handled by the sampler, not by label-change events.
        if event=='ZONE_CHANGED_NEW_AREA' or event=='ZONE_CHANGED_INDOORS' or event=='ZONE_CHANGED' then return end
        if event=='PLAYER_DEAD' then
            t.gatheringCast=nil;t.gatheringObservedAt=nil
            if not t.dead then
                t.dead=true
                local location=A.Location();location.state='dead'
                local killer=deaths.blow and A.Now()-deaths.blow.at<=2 and deaths.blow.killer or nil
                deaths.pending=j:Append('death','Died',{killer=killer},location,A.Now())
                deaths.blow=nil
                deaths:Recap()
                local pending=deaths.pending
                for _,delay in ipairs({0.2,1}) do later(delay,function()
                    if not j.readOnly and not ns.InitializationBlocked and deaths.pending==pending then deaths:Recap() end
                end) end
            end
            j.trail:Break(event);return
        end
        if event=='PLAYER_LEVEL_UP' then
            -- UnitLevel can still report the old level during this event.
            if not A.Int(id,1,1000) then return end
            local location=A.Location();location.level=id
            j.trail:Break(event)
            j:Append('levelup','Reached level '..id,nil,location,A.Now())
            return
        end
        if event=='PLAYER_ALIVE' or event=='PLAYER_UNGHOST' then
            deaths:Reset()
            local dead=A.Read(UnitIsDeadOrGhost,'player')
            if event=='PLAYER_UNGHOST' or (event=='PLAYER_ALIVE' and (dead==false or dead==0)) then t.dead=false end
            j.trail:Break(event);return
        end
        if event=='TAXIMAP_OPENED' then
            t.taxiOrigin={location=A.Location(),at=A.Now()}
            local count=A.Read(NumTaxiNodes)
            for i=1,(A.Int(count,0,512) and count or 0) do
                if A.Read(TaxiNodeGetType,i)=='CURRENT' then
                    local name=A.Read(TaxiNodeName,i)
                    if A.Text(name,160) then t.taxiOrigin.name=name end
                    break
                end
            end
            return
        end
        if event=='TAXIMAP_CLOSED' then
            if t.taxiOrigin then t.taxiOrigin.closed=A.Now() end;return
        end
        if event=='QUEST_DETAIL' then reward=nil;rewardIndex=nil;offer=A.RewardSnapshot();return end
        if event=='QUEST_ITEM_UPDATE' then
            if offer and A.Read(GetQuestID)==offer.questID then offer=A.RewardSnapshot() end
            self:RefreshReward()
            return
        end
        if event=='QUEST_COMPLETE' then
            offer=nil;reward=A.RewardSnapshot();rewardIndex=nil;rewardClosed=false
            if reward then reward.token=tostring(j:Sequence()) end
            return
        end
        if event=='QUEST_FINISHED' then
            -- Leave the snapshot alive only through the synchronous reward event/hook batch.
            rewardClosed=true
            local previous,previousOffer=reward,offer
            later(0.5,function() if reward==previous then reward=nil end;if offer==previousOffer then offer=nil end end);return
        end
        if not A.Int(id,1,2147483647) then return end
        local at=A.Now();local loc=A.Location();local text=title(id)
        if event=='QUEST_ACCEPTED' then
            if db.pending[id] and db.pending[id].kind=='accepted' then return end
            if db.pending[id] then t:Flush(id,true) end
            local captured=offer and offer.questID==id and at-offer.at<=600 and A.Copy(offer) or nil
            if A.Read(GetQuestID)==id and (not captured or captured.status~='observed') then
                local fresh=A.RewardSnapshot()
                if fresh and (not captured or fresh.status=='observed') then captured=fresh end
            end
            if captured then captured.questID,captured.at,captured.title=nil,nil,nil end
            captured=captured or {status='unknown'};offer=nil
            local old=db.quests[id];if old and old.kind=='accepted' then return end
            if captured.status~='observed' and A.CanReadLogRewards() then
                local pending={kind='accepted',at=at,title=text,location=loc,reward=captured,sequence=j:Sequence()}
                db.pending[id]=pending
                local anchor=A.Copy(loc);anchor.at=at;j.trail:Sample(anchor,true)
                A.Read(C_QuestLog.RequestLoadQuestByID,id)
                t:Flush(id)
                for _,delay in ipairs({1,3,6,10}) do later(delay,function() if db.pending[id]==pending then t:Flush(id) end end) end
            else j:Quest('accepted',id,text,captured,loc,at) end
            return
        end
        if db.pending[id] and db.pending[id].kind=='accepted' then t:Flush(id,true) end
        if event=='QUEST_REMOVED' then
            local old=db.quests[id]
            if db.pending[id] or (type(old)=='table' and (old.kind=='completed' or old.kind=='removed')) then return end
            db.pending[id]={kind='removed',at=at,title=text,location=loc,sequence=j:Sequence()}
            if abandon and abandon.id==id and at-abandon.at<=10 then db.pending[id].location.removal='abandoned';abandon=nil end
            -- Removal precedes turn-in on some clients. Coalesce before appending, not afterwards.
            later(2,function() t:Flush(id) end)
        elseif event=='QUEST_TURNED_IN' then
            local s=reward and reward.questID==id and at-reward.at<=600 and A.Copy(reward) or nil
            db.pending[id]={kind='completed',at=at,title=text or (s and s.title),location=loc,snapshot=s,
                xp=A.Int(xp,0,2147483647) and xp or nil,money=A.Int(money,0,2147483647) and money or nil,token=s and s.token,sequence=j:Sequence()}
            later(0.2,function() t:Flush(id) end)
        end
    end
    function t:Poll()
        if t.loading or j.readOnly or ns.InitializationBlocked then return end
        local now=A.Now()
        t:CheckWorldTransfer()
        t.travelContext=travelContext()
        -- Fallback finalization remains active when positional recording is off.
        for id,v in pairs(db.pending) do if type(v)=='table' and now-v.at>=2 then t:Flush(id) end end
        local taxiValue=A.Read(UnitOnTaxi,'player')
        local knownTaxi=taxiValue==true or taxiValue==false or taxiValue==0 or taxiValue==1
        local taxi=taxiValue==true or taxiValue==1
        local origin=t.taxiOrigin
        if origin and ((origin.closed and now-origin.closed>30) or now-origin.at>1800) then t.taxiOrigin=nil;origin=nil end
        if knownTaxi and taxi and t.taxi~=true and (t.taxi==false or origin) then
            local ground=t.ground and now-t.ground.at<=12 and t.ground or nil
            local location=origin and origin.location or ground or A.Location()
            j:Append('flight',origin and origin.name and ('Flight from '..origin.name) or 'Flight departure',nil,location,now)
            t.taxiOrigin=nil
        end
        if knownTaxi then t.taxi=taxi end
        t.travelPosition=A.Location();t.travelPosition.at=now
        if db.settings.trail==false then return end
        local p=A.Location();p.at=now;p.flight=knownTaxi and taxi or nil
        if p.activity=='gathering' then
            t.gatheringObservedAt=now
        elseif p.activity==false or (t.gatheringObservedAt and now-t.gatheringObservedAt>=30) then
            t.gatheringCast=nil;t.gatheringObservedAt=nil;p.activity=false
        end
        if knownTaxi and not taxi then p.flight=false end
        if knownTaxi and not taxi then t.ground=A.Copy(p) end
        p.context=table.concat({tostring(A.Read(IsInInstance) or false),tostring(A.Read(UnitIsDeadOrGhost,'player') or false)},':')
        j.trail:Sample(p)
    end
    function t:Start()
        if j.readOnly then return end
        self.travelContext=travelContext()
        for id in pairs(db.pending) do t:Flush(id) end -- persisted provisional records survive reload
        self.frame=CreateFrame('Frame')
        for _,event in ipairs({'QUEST_ACCEPTED','QUEST_REMOVED','QUEST_TURNED_IN','QUEST_DETAIL','QUEST_ITEM_UPDATE','QUEST_COMPLETE','QUEST_FINISHED',
            'QUEST_LOG_UPDATE','QUEST_DATA_LOAD_RESULT','GET_ITEM_INFO_RECEIVED',
            'PLAYER_ENTERING_WORLD','PLAYER_LEAVING_WORLD','PLAYER_LOGOUT','ZONE_CHANGED_NEW_AREA','ZONE_CHANGED_INDOORS',
            'ZONE_CHANGED','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST','PLAYER_LEVEL_UP','TAXIMAP_OPENED','TAXIMAP_CLOSED',
            'PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED',
            -- Forever forbids addon combat-log registration. pcall does not
            -- suppress ADDON_ACTION_FORBIDDEN; do not probe that event here.
            'PLAYER_TARGET_CHANGED','UPDATE_MOUSEOVER_UNIT','NAME_PLATE_UNIT_ADDED',
            'UNIT_SPELLCAST_START','UNIT_SPELLCAST_STOP','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_FAILED_QUIET','UNIT_SPELLCAST_INTERRUPTED'}) do
            self.capabilities[event]=pcall(self.frame.RegisterEvent,self.frame,event)
        end
        self.frame:SetScript('OnEvent',function(_,...) t:Event(...) end)
        if type(hooksecurefunc)=='function' then
            if type(GetQuestReward)=='function' then self.capabilities.rewardHook=pcall(hooksecurefunc,'GetQuestReward',function(index) t:RewardRequested(index) end) end
            if C_QuestLog and type(C_QuestLog.SetAbandonQuest)=='function' and type(C_QuestLog.AbandonQuest)=='function' then
                local selected
                pcall(hooksecurefunc,C_QuestLog,'SetAbandonQuest',function()
                    if not j.readOnly and not ns.InitializationBlocked then selected=A.Read(C_QuestLog.GetAbandonQuest) end
                end)
                pcall(hooksecurefunc,C_QuestLog,'AbandonQuest',function()
                    if not j.readOnly and not ns.InitializationBlocked and A.Int(selected,1,2147483647) then
                        abandon={id=selected,at=A.Now()}
                        local pending=db.pending[selected]
                        if pending and pending.kind=='removed' then pending.location.removal='abandoned' end
                    end
                end)
            end
        end
        if C_Timer and type(C_Timer.NewTicker)=='function' then self.ticker=C_Timer.NewTicker(2,function() t:Poll() end) end
        self:Seed()
    end
    return t
end
