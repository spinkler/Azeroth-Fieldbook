local _,ns=...
local report=ns.SharingReport
local comparison={MAX_BYTES=1048576}
ns.BestiaryComparison=comparison

-- Comparison carries only the fields offered by Share. Beast Lore is advertised
-- by its observation and fingerprint; the tooltip itself travels in a free report.
local function field(value)
    local text=tostring(value)
    return #text..":"..text
end
local function loreMark(lore)
    if not report.ValidLore(lore) then return end
    local parts={field(lore.level)}
    for _,row in ipairs(lore.rows) do
        parts[#parts+1]=field(row.left)..field(row.right or "")
    end
    local text=table.concat(parts)
    local a,b=5381,17
    for i=1,#text do
        local byte=text:byte(i)
        a=(a*33+byte)%2147483647
        b=(b*131+byte)%2147483629
    end
    return string.format("%08x%08x",a,b)
end

local function previewValue(basic,claims,recipient)
    return {version=report.VERSION,creatureID=basic.creatureID,name=basic.name,category=basic.category,
        levelMin=basic.levelMin,levelMax=basic.levelMax,locations=basic.locations,rumours=claims or {},
        transaction="1-1-1",created=1,recipient=recipient or "Preview"}
end

local function distinctClaims(claims)
    local result,names,spells={},{},{}
    for _,claim in ipairs(claims) do
        local key=report.ClaimKey(claim)
        if not names[key] and not spells[claim.spellID] then
            result[#result+1]=claim
            names[key]=true
            if claim.spellID then spells[claim.spellID]=true end
        end
    end
    return result
end

function comparison.Catalog(journal)
    local entries={}
    for id,entry in pairs(journal.entries) do
        local name=journal:GetCreatureName(id)
        if report.Integer(id,1,10000000) and report.Text(name,100) and not journal:IsFactionAffiliated(id) then
            local basic,claims=report.Capture(journal,id)
            local mark=loreMark(entry.beastLore)
            entries[#entries+1]={id=id,name=name,multiplier=journal:GetKnowledgeMultiplier(id),
                basic=basic,claims=basic and distinctClaims(claims) or {},mark=mark,observed=mark and entry.beastLore.observed,
                heldRumours=#journal:GetRumours(id),loreLevel=mark and entry.beastLore.level,
                personalLore=mark~=nil and entry.beastLoreSource=="gameTooltip"}
        end
    end
    table.sort(entries,function(a,b) return a.id<b.id end)
    return entries
end

-- Length-prefixed literals allow punctuation and localized names in every text
-- field. An unshareable basic record still appears on its owner's side.
function comparison.EncodeCatalog(entries)
    local parts,bytes={},0
    local function add(value)
        local part=field(value)
        parts[#parts+1]=part
        bytes=bytes+#part
    end
    add(#entries)
    for _,record in ipairs(entries) do
        add(record.id);add(record.name);add(record.multiplier);add(record.heldRumours)
        local basic=record.basic
        add(basic and basic.category or "")
        if basic then
            add(basic.levelMin or 0);add(basic.levelMax or 0);add(#basic.locations)
            for _,location in ipairs(basic.locations) do add(location) end
        end
        add(#record.claims)
        for _,claim in ipairs(record.claims) do add(claim.kind);add(claim.value);add(claim.spellID or 0) end
        add(record.mark or "")
        if record.mark then add(record.loreLevel);add(record.observed);add(record.personalLore and 1 or 0) end
        if bytes>comparison.MAX_BYTES then return nil,"This catalogue exceeds the comparison message limit." end
    end
    return table.concat(parts)
end

function comparison.DecodeCatalog(text)
    if not report.Text(text,comparison.MAX_BYTES) then return end
    local pos=1
    local function take(maximum)
        local _,last,digits=text:find("^(%d+):",pos)
        assert(last and #digits<=4)
        local length=tonumber(digits)
        assert(length<=maximum and last+length<=#text)
        pos=last+length+1
        return text:sub(last+1,pos-1)
    end
    local function number(low,high)
        local value=take(10)
        assert(value:match("^%d+$"))
        value=tonumber(value)
        assert(report.Integer(value,low,high))
        return value
    end
    local function decode()
        local entries,lastID={},0
        for i=1,number(0,#text) do
            local id=number(lastID+1,10000000)
            local record={id=id,name=take(100),multiplier=tonumber(take(3)),claims={}}
            assert(report.Text(record.name,100) and (record.multiplier==1 or record.multiplier==1.5 or record.multiplier==2))
            record.heldRumours=number(0,report.MAX_STORED_RUMOURS)
            local category=take(50)
            if category~="" then
                local basic={version=report.VERSION,creatureID=id,name=record.name,category=category,
                    levelMin=number(0,255),levelMax=number(0,255),locations={},rumours={}}
                if basic.levelMin==0 and basic.levelMax==0 then basic.levelMin,basic.levelMax=nil,nil end
                for j=1,number(0,report.MAX_LOCATIONS) do basic.locations[j]=take(80) end
                assert(report.Validate(previewValue(basic)))
                record.basic=basic
            end
            local seen={}
            for j=1,number(0,record.basic and report.MAX_BYTES or 0) do
                local claim={kind=take(16),value=take(100),spellID=number(0,2147483647)}
                if claim.spellID==0 then claim.spellID=nil end
                assert(report.ValidClaim(claim))
                local key=report.ClaimKey(claim)
                assert(not seen[key]);seen[key]=true
                record.claims[j]=claim
            end
            local mark=take(16)
            if mark~="" then
                assert(#mark==16 and mark:match("^[0-9a-f]+$"))
                record.mark,record.loreLevel,record.observed,record.personalLore=mark,number(1,255),number(1,9999999999),number(0,1)==1
            end
            entries[i],lastID=record,id
        end
        assert(pos==#text+1)
        return entries
    end
    local ok,entries=pcall(decode)
    if ok then return entries end
end

local function price(record,quote)
    quote.regular=not quote.unavailable and (quote.basic or #quote.indices>0)
    quote.cost=quote.regular and report.Cost(quote.indices,record.multiplier,quote.basic and 1 or 0) or 0
    quote.reserve=quote.regular and report.Cost(quote.indices,record.multiplier) or 0
    return quote
end
local function heldClaims(journal,id)
    local byName,bySpell={},{}
    local function remember(claim)
        byName[report.ClaimKey(claim)]=true
        if claim.kind=="ability" and claim.spellID then bySpell[claim.spellID]=true end
    end
    local entry=journal.entries[id]
    if entry then
        for _,claim in ipairs(report.Candidates(entry)) do remember(claim) end
        for _,claim in ipairs(journal:GetRumours(id)) do remember(claim) end
    end
    return byName,bySpell
end

-- The recipient uses the same preview as a real offer, including previously
-- received basics on locked pages. Only indices of wanted traits go back.
function comparison.Quotes(journal,catalog,peer,recipient)
    local quotes={}
    local sharedCount=journal:CountSharedCreatures()
    for i,record in ipairs(catalog) do
        local quote={indices={},unavailable=record.basic==nil}
        local entry=journal.entries[record.id]
        local preceding
        if record.mark and not (entry and entry.beastLoreSource=="gameTooltip" and report.ValidLore(entry.beastLore)) then
            local old=entry and entry.beastLore
            local mark=loreMark(old)
            quote.lore=record.mark~=mark and (not mark or record.personalLore or record.observed>old.observed)
            if quote.lore then
                local loreBasic=previewValue({creatureID=record.id,name=record.name,category="Beast",
                    levelMin=record.loreLevel,levelMax=record.loreLevel,locations={}},nil,recipient)
                local preview=journal:PreviewReport(loreBasic,peer,sharedCount)
                if preview then
                    loreBasic.duplicateBasic=preview.duplicateBasic
                    preceding=loreBasic
                else quote.lore=false end
            end
        end
        if record.basic then
            local names,spells=heldClaims(journal,record.id)
            local claims={}
            for index,claim in ipairs(record.claims) do
                local key=report.ClaimKey(claim)
                if not names[key] and not spells[claim.spellID] then
                    quote.indices[#quote.indices+1]=index
                    claims[#claims+1]=claim
                    names[key]=true
                    if claim.spellID then spells[claim.spellID]=true end
                end
            end
            local value=previewValue(record.basic,claims,recipient)
            local preview=journal:PreviewReport(value,peer,sharedCount,preceding)
            if preview and report.Encode(value) then
                quote.basic=preview.newBasic
            else
                quote.indices,quote.unavailable={},true
            end
        end
        quotes[i]=price(record,quote)
    end
    return quotes
end

function comparison.EncodeQuotes(quotes)
    local parts={}
    for i,quote in ipairs(quotes) do
        local flags=(quote.unavailable and "x" or quote.basic and "1" or "0")..(quote.lore and "1" or "0")
        parts[i]=#quote.indices==0 and flags or flags.."."..table.concat(quote.indices,".")
    end
    return #parts==0 and "-" or table.concat(parts,",")
end
function comparison.DecodeQuotes(text,catalog)
    if #catalog==0 then return text=="-" and {} or nil end
    local result={}
    for row in (text..","):gmatch("([^,]*),") do
        local record=catalog[#result+1]
        local basic,lore,indices=row:match("^([01x])([01])(.*)$")
        if not record or not basic or (not record.basic and basic~="x") or (lore=="1" and not record.mark) then return end
        local quote={indices={},basic=basic=="1",unavailable=basic=="x",lore=lore=="1"}
        local pos,last=1,0
        while pos<=#indices do
            local _,tail,digits=indices:find("^%.(%d+)",pos)
            local index=tonumber(digits)
            if not tail or not report.Integer(index,last+1,#record.claims) or quote.unavailable then return end
            quote.indices[#quote.indices+1]=index
            pos,last=tail+1,index
        end
        result[#result+1]=price(record,quote)
    end
    if #result==#catalog then return result end
end

function comparison.Rows(mine,theirs,give,take)
    local rows,byID={},{}
    local function add(catalog,quotes,owner,direction)
        for i,record in ipairs(catalog) do
            local row=byID[record.id]
            if not row then row={id=record.id,name=record.name};byID[record.id]=row;rows[#rows+1]=row end
            row[owner],row[direction]=record,quotes[i]
        end
    end
    add(mine,give,"mine","give");add(theirs,take,"theirs","take")
    table.sort(rows,function(a,b)
        local x,y=a.name:lower(),b.name:lower()
        return x<y or (x==y and a.id<b.id)
    end)
    return rows,byID
end

function comparison.CanSelect(quote) return quote and (quote.regular or quote.lore) end

-- Use the sender's catalogue order on both clients. Each report reserves its
-- own maximum, so the balance needed is the peak across sequential offers.
function comparison.Plan(catalog,quotes,selected)
    local plan={jobs={},entries=0,basics=0,traits=0,lore=0,cost=0,required=0}
    for i,record in ipairs(catalog) do
        local quote=quotes[i]
        if selected[record.id] and comparison.CanSelect(quote) then
            plan.entries=plan.entries+1
            if quote.lore then
                plan.jobs[#plan.jobs+1]={entry=record,quote=quote,lore=true}
                plan.lore=plan.lore+1
            end
            if quote.regular then
                plan.jobs[#plan.jobs+1]={entry=record,quote=quote}
                plan.basics=plan.basics+(quote.basic and 1 or 0)
                plan.traits=plan.traits+#quote.indices
                plan.required=math.max(plan.required,plan.cost+quote.reserve)
                plan.cost=plan.cost+quote.cost
            end
        end
    end
    return plan
end

local function selectedClaims(job)
    local claims={}
    for _,index in ipairs(job.quote.indices) do claims[#claims+1]=job.entry.claims[index] end
    return claims
end
function comparison.Matches(job,value)
    local record=job.entry
    if value.creatureID~=record.id or value.name~=record.name then return false end
    if job.lore then
        return value.version==report.LORE_VERSION and value.beastLore and value.beastLore.observed==record.observed
            and loreMark(value.beastLore)==record.mark and value.levelMin==value.beastLore.level
            and value.levelMax==value.beastLore.level and #value.locations==0 and #value.rumours==0
    end
    local basic=record.basic
    if value.version~=report.VERSION or value.category~=basic.category or value.levelMin~=basic.levelMin
        or value.levelMax~=basic.levelMax or #value.locations~=#basic.locations or #value.rumours~=#job.quote.indices then return false end
    for i,location in ipairs(basic.locations) do if value.locations[i]~=location then return false end end
    for i,index in ipairs(job.quote.indices) do
        local a,b=record.claims[index],value.rumours[i]
        if a.kind~=b.kind or a.value~=b.value or a.spellID~=b.spellID then return false end
    end
    return true
end

function comparison.CaptureJob(journal,job)
    local record=job.entry
    if journal:IsFactionAffiliated(record.id) then return end
    if job.lore then
        local value=report.CaptureLore(journal,record.id)
        if value and comparison.Matches(job,value) then return value,{} end
        return
    end
    if journal:GetKnowledgeMultiplier(record.id)~=record.multiplier then return end
    -- Receiving the other half of a swap may already have expanded this
    -- creature's range or locations. Send precisely the approved snapshot.
    local current=journal:GetBasicInfo(record.id)
    local basic=record.basic
    if not current or current.name~=basic.name or (current.category~=basic.category and basic.category~="Unclassified")
        or (basic.levelMin and (not current.levelMin or current.levelMin>basic.levelMin or current.levelMax<basic.levelMax)) then return end
    for _,location in ipairs(basic.locations) do if not current.locations[location] then return end end
    local claims=selectedClaims(job)
    local byKey={}
    for _,claim in ipairs(report.Candidates(journal.entries[record.id])) do byKey[claim.kind..":"..claim.value]=claim end
    for _,claim in ipairs(claims) do
        local found=byKey[claim.kind..":"..claim.value]
        if not found or found.spellID~=claim.spellID then return end
    end
    return basic,claims
end
