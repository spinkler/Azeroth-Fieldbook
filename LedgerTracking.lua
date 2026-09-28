local _, ns = ...
local L=ns.Ledger
-- Only public values reach persisted facts. A failed native read is not a zero.
local function values(fn,...)
    if type(fn)~="function" then return end
    local v={pcall(fn,...)};if not v[1] then return end
    for i=2,13 do if not L.Public(v[i]) then v[i]=nil end end
    return unpack(v,2,13)
end
local function plain(v)
    if not L.Public(v) or type(v)~="string" then return end
    v=v:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')
    return L.Name(v)
end
local function innkeeperTitle(text)
    text=plain(text)
    if not text then return false end
    text=text:match("^%s*<(.-)>%s*$") or text
    return text=="Innkeeper" or (type(INNKEEPER)=="string" and text==INNKEEPER)
end
function L.Unit(unit)
    if L.Read(UnitIsPlayer,unit) then return end
    local guid=L.Read(UnitGUID,unit);local name=L.Name(L.Read(UnitName,unit))
    if not L.Text(guid,160) or not name then return end
    local npcID=tonumber(guid:match('^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%x+$'))
    if not L.Integer(npcID,1,10000000) then return end
    local v={guid=guid,npcID=npcID,name=name,location=ns.Atlas.CurrentLocation()}
    if v.location.mapID and ns.CreatureLocations then
        local sample=L.Read(ns.CreatureLocations.Sample,unit,guid,v.location.mapID)
        if sample and sample.mapID==v.location.mapID and sample.point and sample.point.approximate==false then
            v.location.x,v.location.y,v.location.precision=sample.point.x,sample.point.y,"npc"
        end
    end
    local function title(token)
    local data=L.Read(C_TooltipInfo and C_TooltipInfo.GetUnit,token)
    local types=Enum and Enum.TooltipDataLineType
    if type(data)=="table" and L.Public(data.lines) and type(data.lines)=="table" and types then
        -- Native unit title: the single untyped line between UnitName and
        -- UnitLevel. Never treat level/faction/quest text as a title or role.
        local candidate,afterName,ambiguous
        for i,line in ipairs(data.lines) do
            if i>12 then break end
            if L.Public(line) and type(line)=="table" and L.Public(line.type) then
                local text=plain(line.leftText)
                local levelPrefix=L.Name(LEVEL) or "Level"
                local levelLine=text and text:sub(1,#levelPrefix)==levelPrefix and text:sub(#levelPrefix+1):match("^%s+%d")
                if afterName and i==2 and innkeeperTitle(text) then return text end
                if i==1 and (line.type==types.UnitName or text==name) then afterName=true
                elseif afterName and levelLine then if not ambiguous then return candidate end;break
                elseif afterName and line.type==types.UnitLevel then if not ambiguous then return candidate end;break
                elseif afterName then
                    if line.type==types.None or line.type==nil or (i==2 and line.type==types.UnitName) then
                        local text=plain(line.leftText)
                        if text then
                            if i==2 and text:match("^<[^<>]+>$") then return text end
                            if candidate then ambiguous=true else candidate=text end
                        end
                    elseif line.type~=types.Blank then ambiguous=true end
                end
            end
        end
    end
    end
    v.sublabel=title(unit)
    if not v.sublabel then
        for _,token in ipairs({"mouseover","target"}) do
            if token~=unit and L.Read(UnitGUID,token)==guid then
                v.sublabel=title(token);if v.sublabel then break end
            end
        end
    end
    return v
end
local function metadata(itemID)
    local name,_,_,_,_,_,subtype,_,_,icon,_,classID=values(C_Item and C_Item.GetItemInfo,itemID)
    local out={}
    if L.Name(name) then out.name=name end
    if L.Integer(icon,1,2147483647) then out.icon=icon end
    local recipe=Enum and Enum.ItemClass and Enum.ItemClass.Recipe
    if L.Integer(classID,0,100) and recipe then
        out.recipe=classID==recipe
        if out.recipe then out.profession=L.Name(subtype) end
    end
    return out
end
local function restrictions(index)
    local data=L.Read(C_TooltipInfo and C_TooltipInfo.GetMerchantItem,index)
    local out={};local types=Enum and Enum.TooltipDataLineType or {}
    if type(data)=="table" and L.Public(data.lines) and type(data.lines)=="table" then
        for i,line in ipairs(data.lines) do
            if i>60 or #out>=8 then break end
            if L.Public(line) and type(line)=="table" and L.Public(line.type) and
                ((types.UsageRequirement and line.type==types.UsageRequirement) or (types.ErrorLine and line.type==types.ErrorLine)
                    or (types.DisabledLine and line.type==types.DisabledLine)) then
                local text=plain(line.leftText);if text then out[#out+1]=text end
            end
        end
    end
    return out
end
local function merchantItem(index)
    local info=L.Read(C_MerchantFrame and C_MerchantFrame.GetItemInfo,index)
    if type(info)~="table" then return end
    local itemID=L.Read(GetMerchantItemID,index)
    local link=L.Read(GetMerchantItemLink,index)
    if not L.Integer(itemID,1,2147483647) and L.Public(link) and type(link)=="string" then itemID=tonumber(link:match('item:(%d+)')) end
    local v={name=L.Name(info.name),costs={},requirements=restrictions(index),stock=L.Stock(info.numAvailable)}
    if L.Integer(itemID,1,2147483647) then
        v.itemID=itemID;v.link="item:"..itemID
        for k,value in pairs(metadata(itemID)) do v[k]=value end
    elseif L.Integer(info.currencyID,1,2147483647) then v.currencyID=info.currencyID
    elseif L.Integer(info.spellID,1,2147483647) then v.spellID=info.spellID
    else return end -- no durable offering identity; leave the scan partial
    if L.Integer(info.stackCount,1,1000000) then v.bundle=info.stackCount end
    if L.Integer(info.price,0,1000000000000) then v.price=info.price end
    if L.Integer(info.texture,1,2147483647) then v.icon=info.texture end
    if L.Public(info.isPurchasable) and type(info.isPurchasable)=="boolean" then v.purchasable=info.isPurchasable end
    if L.Public(info.isUsable) and type(info.isUsable)=="boolean" then v.usable=info.isUsable end
    v.costsKnown=L.Public(info.hasExtendedCost) and info.hasExtendedCost==false
    if L.Public(info.hasExtendedCost) and info.hasExtendedCost==true then
        local n=L.Read(GetMerchantItemCostInfo,index);v.costsKnown=L.Integer(n,1,8)
        if v.costsKnown then for i=1,n do
            local _,quantity,costLink,currencyName=values(GetMerchantItemCostItem,index,i)
            local id,kind
            if L.Public(costLink) and type(costLink)=="string" then
                id=tonumber(costLink:match('item:(%d+)'));kind="item"
                if not id then id=tonumber(costLink:match('currency:(%d+)'));kind="currency" end
            end
            if L.Integer(quantity,0,1000000000) and L.Integer(id,1,2147483647) then
                v.costs[#v.costs+1]={kind=kind,id=id,quantity=quantity,name=L.Name(currencyName)}
            else v.costsKnown=false end
        end end
    end
    -- Cost identity disambiguates duplicate listings without using their volatile price/stock.
    local keys={};for _,cost in ipairs(v.costs) do keys[#keys+1]=L.Key(cost.kind,cost.id) end
    v.variant=table.concat(keys,';')
    return v,v.name~=nil and v.bundle~=nil and v.costsKnown
end
local function trainerItem(index)
    -- Forever Mainline/Camelot: name, type, texture, required level, subtext, category.
    local name,status,_,level,rank,category=values(GetTrainerServiceInfo,index)
    if not L.Name(name) or status=="header" then return end
    local v={name=name,rank=L.Name(rank) or "",category=L.Name(category) or "",requirements={},availability="unknown"}
    if status=="available" or status=="unavailable" or status=="used" then v.availability=status end
    if L.Integer(level,1,255) then v.requiredLevel=level;v.requirements[#v.requirements+1]="Required level: "..level end
    local skill,required=values(GetTrainerServiceSkillReq,index)
    if L.Name(skill) then v.requirements[#v.requirements+1]=skill..(L.Integer(required,0,10000) and " ("..required..")" or "") end
    local count=L.Read(GetTrainerServiceNumAbilityReq,index)
    if L.Integer(count,0,8) then for i=1,count do local ability=L.Name(L.Read(GetTrainerServiceAbilityReq,index,i));if ability then v.requirements[#v.requirements+1]=ability end end end
    local price=L.Read(GetTrainerServiceCost,index)
    if L.Integer(price,0,1000000000000) then v.price=price end
    local trainerType=L.Read(C_Trainer and C_Trainer.GetTrainerType)
    v.costUnit="unknown"
    if Enum and Enum.TrainerType and L.Integer(trainerType,0,32) then
        v.costUnit=trainerType==Enum.TrainerType.Pet and "training points" or "copper"
    end
    return v,true
end
function ns.CreateLedgerTracking(journal)
    local t={journal=journal,pending={},pendingCount=0,visits={},opening={}}
    function t:Forget(contact)
        for kind,visit in pairs(self.visits) do if visit.contact==contact then
            visit.closed=true;self.visits[kind]=nil;self.opening[kind]=nil
        end end
        for key,job in pairs(self.pending) do if job.contact==contact then
            self.pending[key]=nil;self.pendingCount=self.pendingCount-1
        end end
    end
    function t:Open(kind)
        local opening={};self.opening[kind]=opening
        self:Begin(kind)
        if not self.visits[kind] and C_Timer and type(C_Timer.After)=="function" then
            for _,delay in ipairs({0.1,0.5,1.5}) do C_Timer.After(delay,function()
                if self.opening[kind]==opening and not self.visits[kind] then self:Begin(kind) end
            end) end
        end
    end
    function t:Begin(kind)
        if self.visits[kind] then self.visits[kind].closed=true end
        self.visits[kind]=nil
        local unit=L.Unit("npc");if not unit then return end -- never fall back to a changed target
        local roles={[kind=="merchant" and "merchant" or "trainer"]=true}
        if innkeeperTitle(unit.sublabel) then roles.innkeeper=true end
        if kind=="merchant" and L.Read(CanMerchantRepair)==true then roles.repair=true end
        local e=journal:Encounter(unit,roles,true);if not e then return end
        local visit=journal:Begin(e.id,kind);if not visit then return end
        visit.guid=unit.guid;self.visits[kind]=visit;self:Scan(visit)
        if C_Timer and type(C_Timer.After)=="function" then
            for _,delay in ipairs({0.5,1.5}) do C_Timer.After(delay,function()
                if not visit.closed and self.visits[kind]==visit and not visit.complete then self:Scan(visit) end
            end) end
        end
    end
    function t:Scan(visit)
        if visit.closed or self.visits[visit.kind]~=visit then return end
        if L.Read(UnitGUID,"npc")~=visit.guid then return end
        local contact=journal:Get(visit.contact)
        if contact and contact.sublabel=="" then
            local unit=L.Unit("npc")
            if unit and unit.guid==visit.guid and unit.sublabel then journal:Encounter(unit,innkeeperTitle(unit.sublabel) and {innkeeper=true} or {},false) end
        end
        local merchant=visit.kind=="merchant"
        if merchant and MerchantFrame and MerchantFrame.selectedTab==2 then return end
        local n=L.Read(merchant and GetMerchantNumItems or GetNumTrainerServices)
        if not L.Integer(n,0,500) then journal:Scan(visit,{},false,"Unreadable or oversized inspection");return end
        local complete,reason=true,nil;local initialFilter
        if merchant then
            initialFilter=L.Read(GetMerchantFilter)
            if not LE_LOOT_FILTER_ALL or initialFilter~=LE_LOOT_FILTER_ALL then complete=false;reason="Filtered or unknown merchant view" end
        else
            -- The visible curriculum can be category/availability filtered. No absence claim.
            complete=false;reason="Observed trainer view; full curriculum not established"
        end
        local rows={}
        for i=1,n do
            local v,loaded=(merchant and merchantItem or trainerItem)(i)
            if v then rows[#rows+1]=v end
            if not loaded then complete=false;reason="Partial or pending metadata" end
        end
        if n==0 then complete=false;reason="Empty view; completeness unverified" end
        if visit.closed or self.visits[visit.kind]~=visit then return end
        if L.Read(UnitGUID,"npc")~=visit.guid then
            journal:Scan(visit,{},false,"Interaction identity changed while reading");return
        end
        if L.Read(merchant and GetMerchantNumItems or GetNumTrainerServices)~=n or (merchant and L.Read(GetMerchantFilter)~=initialFilter) then
            complete=false;reason="Inspection changed while reading"
        end
        journal:Scan(visit,rows,complete,reason)
        if merchant then for _,v in ipairs(rows) do
            if v.itemID and (not v.name or v.recipe==nil) then
                local observationKey=v.observationKey or L.GoodKey(v)
                local key=L.Key(visit.contact,observationKey);local old=self.pending[key]
                if old or self.pendingCount<512 then
                    if not old then self.pendingCount=self.pendingCount+1 end
                    self.pending[key]={contact=visit.contact,key=observationKey,itemID=v.itemID}
                    L.Read(C_Item and C_Item.RequestLoadItemDataByID,v.itemID)
                end
            end
        end end
    end
    function t:Refresh(kind)
        local visit=self.visits[kind]
        if not visit then
            if self.opening[kind] then self:Begin(kind) end
            return
        end
        if visit.closed or visit.queued then return end
        visit.queued=true
        local function run() visit.queued=false;if self.visits[kind]==visit and not visit.closed then self:Scan(visit) end end
        if C_Timer and type(C_Timer.After)=="function" then C_Timer.After(0.15,run) else run() end
    end
    local services={BANKFRAME_OPENED="banker",AUCTION_HOUSE_SHOW="auctioneer",PET_STABLE_SHOW="stable",TAXIMAP_OPENED="transport",CONFIRM_BINDER="innkeeper"}
    function t:OnEvent(event,...)
        if event=="MERCHANT_SHOW" then self:Open("merchant")
        elseif event=="TRAINER_SHOW" then self:Open("trainer")
        elseif event=="MERCHANT_CLOSED" or event=="TRAINER_CLOSED" then
            local kind=event=="MERCHANT_CLOSED" and "merchant" or "trainer"
            self.opening[kind]=nil
            if self.visits[kind] then self.visits[kind].closed=true;self.visits[kind]=nil end
        elseif event=="MERCHANT_UPDATE" or event=="MERCHANT_FILTER_ITEM_UPDATE" then self:Refresh("merchant")
        elseif event=="TRAINER_UPDATE" or event=="TRAINER_SERVICE_INFO_NAME_UPDATE" then self:Refresh("trainer")
        elseif event=="GET_ITEM_INFO_RECEIVED" then
            local itemID,success=...;if not L.Integer(itemID,1,2147483647) or not L.Public(success) then return end
            for key,p in pairs(self.pending) do if p.itemID==itemID then
                if success then
                    journal:Metadata(p.contact,p.key,p.itemID,metadata(p.itemID))
                    for kind,visit in pairs(self.visits) do
                        if visit.contact==p.contact and not visit.closed and not visit.metadataRefreshed then
                            visit.metadataRefreshed=true;self:Refresh(kind)
                        end
                    end
                end
                self.pending[key]=nil;self.pendingCount=self.pendingCount-1
            end end
        elseif services[event] then
            local v=L.Unit("npc");if v then journal:Encounter(v,{[services[event]]=true},true) end
        elseif event=="PLAYER_TARGET_CHANGED" or event=="UPDATE_MOUSEOVER_UNIT" then
            local v=L.Unit(event=="PLAYER_TARGET_CHANGED" and "target" or "mouseover")
            -- A title is not evidence of service capability. Only revisit already identified contacts here.
            local e=v and journal:Get(journal.db.aliases[v.guid])
            if e and e.personal then journal:Encounter(v,innkeeperTitle(v.sublabel) and {innkeeper=true} or {},false) end
        end
    end
    t.frame=CreateFrame("Frame");t.frame:SetScript("OnEvent",function(_,event,...) t:OnEvent(event,...) end)
    local events={"MERCHANT_SHOW","MERCHANT_CLOSED","MERCHANT_UPDATE","MERCHANT_FILTER_ITEM_UPDATE","TRAINER_SHOW","TRAINER_CLOSED",
        "TRAINER_UPDATE","TRAINER_SERVICE_INFO_NAME_UPDATE","GET_ITEM_INFO_RECEIVED","PLAYER_TARGET_CHANGED","UPDATE_MOUSEOVER_UNIT"}
    for event in pairs(services) do events[#events+1]=event end
    for _,event in ipairs(events) do pcall(t.frame.RegisterEvent,t.frame,event) end
    return t
end
