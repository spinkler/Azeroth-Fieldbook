local _,ns=...
local A=ns.Annals
local function title(id)
    local text=A.Read(C_QuestLog and C_QuestLog.GetTitleForQuestID,id)
    if not A.Text(text,240) and A.Read(GetQuestID)==id then text=A.Read(GetTitleText) end
    return A.Text(text,240) and text or nil
end
local function item(kind,index)
    if A.Read(GetQuestItemInfoLootType,kind,index)==1 then
        local v=A.Read(C_QuestOffer and C_QuestOffer.GetQuestRewardCurrencyInfo,kind,index)
        if type(v)=='table' and A.Int(v.currencyID,1,2147483647) and A.Int(v.totalRewardAmount,0,2147483647) then
            return {currencyID=v.currencyID,quantity=v.totalRewardAmount,name=A.Text(v.name,240) and v.name or nil,offered=true}
        end
        return
    end
    if type(GetQuestItemInfo)~='function' then return end
    local ok,name,icon,count,_,_,id=pcall(GetQuestItemInfo,kind,index)
    if not ok then return end
    if not A.Int(id,1,2147483647) then
        local link=A.Read(GetQuestItemLink,kind,index)
        id=A.Text(link,2048) and tonumber(link:match('item:(%d+)')) or nil
    end
    if not A.Int(id,1,2147483647) or not A.Int(count,1,1000000) then return end
    return {itemID=id,quantity=count,name=A.Text(name,240) and name or nil,icon=A.Int(icon,1,2147483647) and icon or nil}
end
function A.RewardSnapshot()
    local id=A.Read(GetQuestID);if not A.Int(id,1,2147483647) then return end
    local choices=A.Read(GetNumQuestChoices);local rewards=A.Read(GetNumQuestRewards)
    local s={questID=id,at=A.Now(),title=A.Read(GetTitleText),choices={},automatic={},status='observed',choiceStatus='unknown'}
    if not A.Int(choices,0,64) or not A.Int(rewards,0,64) then s.status='incomplete';return s end
    s.count=choices;if choices==0 then s.choiceStatus='none' end
    for i=1,choices do s.choices[i]=item('choice',i);if not s.choices[i] then s.status='incomplete' end end
    for i=1,rewards do local v=item('reward',i);if v then s.automatic[#s.automatic+1]=v else s.status='incomplete' end end
    local currencies=A.Read(C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardCurrencies,id)
    s.currencyStatus='unknown'
    if type(currencies)=='table' then
        s.currencyOffers={};s.currencyStatus='offered amounts'
        for i,v in ipairs(currencies) do
            if i>64 then s.currencyStatus='incomplete';break end
            if type(v)=='table' and A.Int(v.currencyID,1,2147483647) and A.Int(v.totalRewardAmount,0,2147483647) then
                s.currencyOffers[#s.currencyOffers+1]={currencyID=v.currencyID,quantity=v.totalRewardAmount,name=A.Text(v.name,240) and v.name or nil}
            else s.currencyStatus='incomplete' end
        end
    end
    -- Offers are not measured currency/reputation balance changes.
    s.otherRewards='reputation and spells not captured'
    return s
end
function ns.CreateAnnalsTracking(j)
    local t={journal=j,capabilities={},loading=false};local db=j.db
    local reward,abandon=nil,nil
    local function later(delay,fn)
        if C_Timer and type(C_Timer.After)=='function' then C_Timer.After(delay,fn);return true end
    end
    function t:Flush(id)
        if j.readOnly or ns.InitializationBlocked then return end
        local p=db.pending[id];if type(p)~='table' then return end
        local r=p.reward
        if p.kind=='completed' then
            r=r or {status='unknown',choiceStatus='unknown'}
            if p.snapshot then
                r=A.Copy(p.snapshot);r.questID,r.at,r.title,r.count,r.choices=nil,nil,nil,nil,nil
            end
            r.xp=p.xp;r.money=p.money
        end
        j:Quest(p.kind,id,p.title,r,p.location,p.at,p.token,p.sequence)
        db.pending[id]=nil
    end
    function t:RewardRequested(index)
        if j.readOnly or ns.InitializationBlocked or not reward or A.Now()-reward.at>600 or not A.Int(index,0,64) then return end
        -- Retries within one reward dialogue are one transaction. A new dialogue
        -- or accepted quest cycle can legitimately produce another completion.
        reward.token=reward.token or tostring(j:Sequence())
        reward.chosen=reward.choices[index];reward.choiceStatus=reward.chosen and 'observed' or (reward.count==0 and 'none' or 'unknown')
        if reward.count==1 and reward.chosen then
            reward.single=reward.chosen;reward.chosen=nil;reward.choiceStatus='single automatic option'
        end
        -- QUEST_TURNED_IN can fire synchronously before a secure post-hook.
        local p=db.pending[reward.questID]
        if p and p.kind=='completed' and p.at>=reward.at then p.snapshot=A.Copy(reward);p.token=reward.token end
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
    function t:Event(event,id,xp,money)
        if j.readOnly or ns.InitializationBlocked then return end
        if event=='PLAYER_ENTERING_WORLD' then
            t.loading=false;t.taxi=nil;t.taxiOrigin=nil;t.ground=nil;j.trail:Break('session or loading')
            if not t.entered then t.entered=true;t:Seed() end
            return
        end
        if event=='PLAYER_LEAVING_WORLD' or event=='PLAYER_LOGOUT' then
            t.loading=true;j.trail:Break('loading')
            for key in pairs(db.pending) do t:Flush(key) end;return
        end
        -- Subzone names change repeatedly during a flight. Exact map changes and
        -- discontinuities are handled by the sampler, not by label-change events.
        if event=='ZONE_CHANGED_NEW_AREA' or event=='ZONE_CHANGED_INDOORS' or event=='ZONE_CHANGED' then return end
        if event=='PLAYER_DEAD' or event=='PLAYER_ALIVE' or event=='PLAYER_UNGHOST' or event=='PLAYER_LEVEL_UP' then j.trail:Break(event);return end
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
        if event=='QUEST_COMPLETE' then reward=A.RewardSnapshot();return end
        if event=='QUEST_FINISHED' then
            -- Leave the snapshot alive only through the synchronous reward event/hook batch.
            local previous=reward;later(0.5,function() if reward==previous then reward=nil end end);return
        end
        if not A.Int(id,1,2147483647) then return end
        local at=A.Now();local loc=A.Location();local text=title(id)
        if event=='QUEST_ACCEPTED' then
            if db.pending[id] then t:Flush(id) end
            j:Quest('accepted',id,text,nil,loc,at);return
        end
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
        if db.settings.trail==false then return end
        local p=A.Location();p.at=now
        if knownTaxi and not taxi then t.ground=A.Copy(p) end
        p.context=table.concat({tostring(A.Read(IsInInstance) or false),tostring(A.Read(UnitIsDeadOrGhost,'player') or false)},':')
        j.trail:Sample(p)
    end
    function t:Start()
        if j.readOnly then return end
        for id in pairs(db.pending) do t:Flush(id) end -- persisted provisional records survive reload
        self.frame=CreateFrame('Frame')
        for _,event in ipairs({'QUEST_ACCEPTED','QUEST_REMOVED','QUEST_TURNED_IN','QUEST_COMPLETE','QUEST_FINISHED',
            'PLAYER_ENTERING_WORLD','PLAYER_LEAVING_WORLD','PLAYER_LOGOUT','ZONE_CHANGED_NEW_AREA','ZONE_CHANGED_INDOORS',
            'ZONE_CHANGED','PLAYER_DEAD','PLAYER_ALIVE','PLAYER_UNGHOST','PLAYER_LEVEL_UP','TAXIMAP_OPENED','TAXIMAP_CLOSED'}) do
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
