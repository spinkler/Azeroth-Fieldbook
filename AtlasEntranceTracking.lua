local _,ns=...
local A,C=ns.Atlas,ns.AtlasEnvironment
local D={SETTLE_SECONDS=0.35,SAMPLE_SECONDS=1,MAX_GAP=2.5,MAX_SPEED=24,JUMP_SLOP=6,
    MAX_STEP=60,MIN_CROSSING_YARDS=0.5,REARM_YARDS=8,MIN_CROSSING_SECONDS=3,
    SUMMON_FALLBACK_SECONDS=120,ARRIVAL_SECONDS=3}
ns.AtlasEntranceTracking=D
function D.Continuous(a,b)
    if not a or not b or a.context.zoneMapID~=b.context.zoneMapID then return false end
    local gap=b.clock-a.clock
    if gap<0 or gap>D.MAX_GAP then return false end
    local distance=C.Distance(a.position,b.position,a.world,b.world,b.size or a.size)
    return distance~=nil and distance<=math.min(D.MAX_STEP,D.JUMP_SLOP+gap*D.MAX_SPEED)
end
function D.Create(store)
    local d={store=store}
    function d:Reset(sample)
        self.stable,self.last,self.pending=sample,sample,nil
        self.anchor,self.acceptedAt=nil,nil;self.armed=true
    end
    function d:Feed(sample)
        if not sample or not store:Enabled() then self:Reset(sample);return end
        if not self.last or not D.Continuous(self.last,sample) then self:Reset(sample);return end
        if self.anchor then
            local distance=C.Distance(self.anchor.position,sample.position,self.anchor.world,sample.world,sample.size)
            if distance and distance>=D.REARM_YARDS then self.armed=true end
        end
        self.last=sample
        if sample.inside==self.stable.inside then self.stable=sample;self.pending=nil;return end
        if not self.pending then self.pending={from=self.stable,to=sample,since=sample.clock};return nil,true end
        local pending=self.pending
        if sample.clock-pending.since+0.000001<D.SETTLE_SECONDS then return nil,true end
        self.stable=sample;self.pending=nil
        if not self.armed or (self.acceptedAt and sample.clock-self.acceptedAt<D.MIN_CROSSING_SECONDS) then return end
        local displacement=C.Distance(pending.from.position,sample.position,pending.from.world,sample.world,sample.size)
        if not displacement or displacement<D.MIN_CROSSING_YARDS then return end
        local outside=sample.inside and pending.from or pending.to
        local inside=sample.inside and sample or pending.from
        local id=store:Record({direction=sample.inside and "entry" or "exit",at=pending.to.at,
            exterior=outside.position,world=outside.world,size=outside.size,interior=inside.context,
            interiorPosition=inside.interiorPosition,
            coordinateSource=sample.inside and "last-exterior" or "first-exterior"})
        if id then self.anchor=outside;self.armed=false;self.acceptedAt=sample.clock end
        return id
    end
    d:Reset();return d
end
function D.Track(j,onChange)
    local frame=CreateFrame("Frame")
    local d=D.Create(j.entrances);frame.detector=d
    local generation,movementGeneration=0,0
    local queued,moving,away,casting=false,false,false,false
    local death,controlLost=false,false
    local holdUntil=0
    local function clock()
        local value=A.Read(GetTime);return A.Number(value,0,1e12) and value or A.Now()
    end
    local function after(delay,run)
        if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(delay,run);return true end
        return false
    end
    local function changed(id) if onChange then onChange(id,away) end end
    local update,queue,startMovement
    update=function()
        if ns.InitializationBlocked then d:Reset();return end
        if not j.entrances:Enabled() then d:Reset();changed();return end
        if away or death or controlLost or casting or clock()<holdUntil then d:Reset();changed();return end
        local id,pending=d:Feed(C.Capture())
        changed(id)
        if pending then queue(D.SETTLE_SECONDS) end
        if A.Number(A.Read(GetUnitSpeed,"player"),0.001,1000) then startMovement() end
    end
    queue=function(delay)
        if queued or not j.entrances:Enabled() then return end
        queued=true;local ticket=generation
        if not after(delay,function()
            if ticket~=generation then return end
            queued=false;update()
        end) then queued=false end
    end
    local function cancel()
        generation=generation+1;queued=false;d:Reset()
    end
    local function stopMovement() movementGeneration=movementGeneration+1;moving=false end
    startMovement=function()
        if moving or away or death or controlLost or casting or not j.entrances:Enabled() then return end
        moving=true;movementGeneration=movementGeneration+1
        local ticket=movementGeneration
        local function tick()
            if ticket~=movementGeneration or not moving then return end
            if away or not j.entrances:Enabled() or ns.InitializationBlocked then stopMovement();return end
            update();after(D.SAMPLE_SECONDS,tick)
        end
        after(D.SAMPLE_SECONDS,tick)
    end
    function frame:SetEnabled(on)
        if j.entrances.readOnly or ns.InitializationBlocked then return end
        j.state.autoEntrances=on==true;cancel();stopMovement()
        -- Enabling while already indoors establishes a baseline, never entry.
        if not away and not death and not controlLost and not casting and clock()>=holdUntil then d:Reset(C.Capture()) end
        local speed=A.Read(GetUnitSpeed,"player")
        if A.Number(speed,0.001,1000) then startMovement() end
        changed()
    end
    frame:SetScript("OnEvent",function(_,event,unit)
        if ns.InitializationBlocked then return end
        if event=="CONFIRM_SUMMON" or event=="CANCEL_SUMMON" or event=="INCOMING_SUMMON_CHANGED" then
            if event=="INCOMING_SUMMON_CHANGED" and unit~=nil and (not A.Public(unit) or unit~="player") then return end
            cancel()
            -- With readable pending/accepted state, Capture stays blocked until
            -- it clears. Older clients without that API get a bounded request
            -- quarantine. Cancellation/acceptance notifications prime afresh.
            local delay=event=="CONFIRM_SUMMON" and C.SummonPending()==nil and D.SUMMON_FALLBACK_SECONDS or D.ARRIVAL_SECONDS
            holdUntil=clock()+delay;queue(delay+0.05);changed();return
        end
        if event=="PLAYER_DEAD" or event=="PLAYER_CONTROL_LOST" then
            if event=="PLAYER_DEAD" then death=true else controlLost=true end
            cancel();stopMovement();changed();return
        end
        if event=="PLAYER_CONTROL_GAINED" then
            controlLost=false;cancel();holdUntil=clock()+D.SETTLE_SECONDS;queue(D.SETTLE_SECONDS);return
        end
        if event:find("^UNIT_SPELLCAST_") then
            if not A.Public(unit) or unit~="player" then return end
            cancel()
            if event=="UNIT_SPELLCAST_START" or event=="UNIT_SPELLCAST_CHANNEL_START" then casting=true
            elseif event~="UNIT_SPELLCAST_SENT" then casting=false end
            holdUntil=math.max(holdUntil,clock()+1);queue(1.05);return
        end
        if event=="PLAYER_LEAVING_WORLD" or event=="LOADING_SCREEN_ENABLED" or event=="PLAYER_LOGOUT" then
            away=true;cancel();stopMovement();changed();return
        end
        if event=="PLAYER_ENTERING_WORLD" or event=="LOADING_SCREEN_DISABLED" or event=="ZONE_CHANGED_NEW_AREA"
            or event=="PLAYER_ALIVE" or event=="PLAYER_UNGHOST" then
            if event=="PLAYER_ALIVE" then death=C.DeadOrGhost()~=false
            elseif event=="PLAYER_UNGHOST" or event=="PLAYER_ENTERING_WORLD" then death=C.DeadOrGhost()==true end
            away=false;casting=false;cancel();stopMovement();holdUntil=clock()+D.SETTLE_SECONDS
            queue(D.SETTLE_SECONDS);changed();return
        end
        if event=="PLAYER_STARTED_MOVING" then update();startMovement();return end
        if event=="PLAYER_STOPPED_MOVING" then stopMovement();update();return end
        -- The first event captures the boundary endpoint immediately. A single
        -- delayed verification coalesces the rest of a Blizzard event burst.
        update()
    end)
    for _,event in ipairs({"ZONE_CHANGED_INDOORS","ZONE_CHANGED","PLAYER_MAP_CHANGED","NEW_WMO_CHUNK",
        "PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","LOADING_SCREEN_ENABLED","LOADING_SCREEN_DISABLED",
        "ZONE_CHANGED_NEW_AREA","PLAYER_STARTED_MOVING","PLAYER_STOPPED_MOVING","PLAYER_DEAD","PLAYER_ALIVE",
        "PLAYER_UNGHOST","PLAYER_LOGOUT","UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP","CONFIRM_SUMMON","CANCEL_SUMMON",
        "INCOMING_SUMMON_CHANGED","PLAYER_CONTROL_LOST","PLAYER_CONTROL_GAINED"}) do
        pcall(frame.RegisterEvent,frame,event)
    end
    d:Reset(j.entrances:Enabled() and C.Capture() or nil)
    local speed=A.Read(GetUnitSpeed,"player");if A.Number(speed,0.001,1000) then startMovement() end
    return frame
end
