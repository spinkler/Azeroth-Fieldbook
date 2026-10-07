local _, ns = ...
-- Temporary, opt-in native evidence for A7. Never authorizes a visible model
-- or writes journal data. One concealed comparison frame is reused forever.
local probe={enabled=false,rows={},sequence=0,callbacks=0}
ns.BestiaryModelProbe=probe
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function read(object,method)
    local fn=object and object[method]
    if type(fn)~="function" then return "<unavailable>" end
    local ok,value=pcall(fn,object)
    if not ok then return "<error>" end
    if not public(value) then return "<restricted>" end
    return value
end
local function literal(value)
    if not public(value) then return "<restricted>" end
    if value==nil then return "<nil>" end
    if type(value)=="string" then return value:gsub("|",""):gsub("[%c]"," "):sub(1,120) end
    if type(value)=="number" or type(value)=="boolean" then return tostring(value) end
    return "<"..type(value)..">"
end
function probe:Log(event,...)
    if not self.enabled then return end
    local now=0
    if type(GetTime)=="function" then
        local ok,value=pcall(GetTime)
        if ok and public(value) and type(value)=="number" then now=value end
    end
    local parts={string.format("%.3f",now),event}
    for i=1,select("#",...) do parts[#parts+1]=literal(select(i,...)) end
    self.rows[#self.rows+1]=table.concat(parts," | ")
    if #self.rows>240 then table.remove(self.rows,1) end
end
function probe:State(event)
    if not self.enabled or not self.model then return end
    local book=self.book
    self:Log(event,self.sequence,self.selected,self.inCall,
        read(self.model,"GetDisplayInfo"),read(self.model,"GetModelFileID"),
        book and book.model and book.model.afbEntryID,book and book.modelPending,
        book and read(book.model,"GetDisplayInfo"),book and read(book.model,"GetModelFileID"))
end
function probe:Select(book,id,personal)
    if not self.enabled then return end
    self.book=book
    self.wanted=nil;self.verifyAttempts=0;self.verifyLimitLogged=false
    self.selected=personal and id or nil
    self:Log("selection: id/encountered",id,personal)
    if self.model then
        self.model:SetAlpha(0)
        self.model:ClearModel()
        self:State("after selection clear")
        if not personal then self.model:Hide() end
    end
end
function probe:VerifyCurrent()
    if not self.enabled or not self.verify or self.verifying or self.inCall or not self.wanted then return end
    local wanted=self.wanted
    if not self.book or not self.book.modelPersonal or self.book.modelEntryID~=wanted.id
        or ns.InitializationBlocked then return end
    if (self.verifyAttempts or 0)>=3 then
        if not self.verifyLimitLogged then self:Log("verification attempt limit",wanted.id);self.verifyLimitLogged=true end
        return
    end
    local method,value=wanted.method,wanted.value
    if method=="SetUnit" then
        local ok,guid=false,nil
        if type(UnitGUID)=="function" then ok,guid=pcall(UnitGUID,value) end
        if not ok or not public(guid) or type(guid)~="string" or guid~=wanted.guid then
            method,value="SetCreature",wanted.id
        end
    end
    self.verifyAttempts=(self.verifyAttempts or 0)+1
    self.verifying=true;self.verifyPhase="clear";self.verifyCallback=false
    local cleared=pcall(self.model.ClearModel,self.model)
    local empty=read(self.model,"GetModelFileID")
    self:Log("verification cleared: entry/method/ok/file",wanted.id,method,cleared,empty)
    self.verifyPhase="setter";self.inCall=true
    local ok,result=pcall(self.model[method],self.model,value)
    self.inCall=false;self.verifyPhase=nil
    local display,file=read(self.model,"GetDisplayInfo"),read(self.model,"GetModelFileID")
    local candidate=cleared and (empty==nil or empty==0) and ok and public(result) and result~=false
        and self.verifyCallback and type(display)=="number" and display>0 and type(file)=="number" and file>0
    self:Log("verification result: entry/method/sync/display/file/candidate",wanted.id,method,self.verifyCallback,display,file,candidate==true)
    self.verifying=false
    -- This is diagnostic evidence only: never reveal or attribute this scene.
end
function probe:Request(book,method,value)
    if not self.enabled or not book.modelPersonal or not book.modelEntryID then return end
    if ns.InitializationBlocked then return end
    self.book=book;self.selected=book.modelEntryID
    if not self.model then
        local model=CreateFrame("PlayerModel",nil,book.detail)
        self.model=model
        model:SetAlpha(0);model:SetSize(223,164);model:SetPoint("TOPLEFT",346,-135)
        model:EnableMouse(false);model:SetPortraitZoom(0);model:SetCamDistanceScale(1.25)
        model:SetScript("OnModelLoaded",function(_, ...)
            if not self.enabled then return end
            self.callbacks=self.callbacks+1
            self:State("probe callback")
            self:Log("probe callback arguments",select("#",...),...)
            if self.verifying then
                if self.verifyPhase=="setter" then self.verifyCallback=true end
            elseif self.inCall then self.requestCallback=true
            elseif self.verify then self:VerifyCurrent() end
        end)
        model:SetScript("OnUpdate",function(_,elapsed)
            if not self.enabled or not self.remaining then return end
            self.elapsed=self.elapsed+(elapsed or 0)
            if self.elapsed>=0.2 then
                self.elapsed=0;self.remaining=self.remaining-1
                self:State("probe settled")
                if self.remaining<=0 then self.remaining=nil end
            end
        end)
    end
    self.sequence=self.sequence+1
    self.remaining,self.elapsed=5,0
    self.model:SetAlpha(0);self.model:Show()
    local guid
    if method=="SetUnit" and type(UnitGUID)=="function" then
        local ok,result=pcall(UnitGUID,value)
        if ok then guid=result end
    end
    self:Log("request: sequence/entry/method/value/unitGUID",self.sequence,self.selected,method,value,guid)
    self:State("before setter")
    self.wanted={id=self.selected,method=method,value=value,guid=public(guid) and guid or nil}
    self.requestCallback=false;self.inCall=true
    local fn=self.model[method]
    local ok,result=false,nil
    if type(fn)=="function" then ok,result=pcall(fn,self.model,value) end
    self.inCall=false
    if not ok then result="<error>" end
    self:Log("setter return: ok/value",ok,result)
    self:State("after setter")
    if self.verify and self.requestCallback then self:VerifyCurrent() end
end
function probe:Reference(book,model,...)
    if not self.enabled then return end
    self.book=book
    self:Log("viewer callback: frame selection/selected/display/file/argc",
        model.afbEntryID,book.modelEntryID,read(model,"GetDisplayInfo"),read(model,"GetModelFileID"),select("#",...))
    self:Log("reference callback arguments",...)
    self:State("at reference callback")
end
function probe:SetEnabled(enabled,verify)
    self.enabled=enabled==true
    self.verify=verify==true
    self.verifyAttempts=0;self.verifyLimitLogged=false;self.verifying=false;self.verifyPhase=nil;self.wanted=nil
    if self.enabled then
        self.rows={};self.sequence=0;self.callbacks=0
        self:Log("enabled: concealed comparison probe; shared viewer candidate")
        if type(GetBuildInfo)=="function" then
            local ok,version,build,date,toc=pcall(GetBuildInfo)
            if ok then self:Log("client: version/build/date/interface",version,build,date,toc) end
        end
    else
        self.remaining=nil;self.book=nil;self.selected=nil;self.inCall=false
        if self.model then self.model:Hide();self.model:ClearModel() end
    end
end
function probe:Report()
    return "A7 model reuse probe v2 (runtime only; shared viewer candidate)\n"
        .."State columns: request sequence | selected entry | inside setter | probe display | probe file | viewer selection | viewer pending | viewer display | viewer file\n"
        .."A matching display/file is appearance evidence, not proof of callback ownership.\n"
        .."Synchronous revalidation experiment: "..tostring(self.verify==true).."; maximum 3 attempts per selection.\n"
        .."Probe frames: "..(self.model and "1" or "0").."; requests: "..self.sequence.."; callbacks: "..self.callbacks.."\n"
        ..table.concat(self.rows,"\n")
end
