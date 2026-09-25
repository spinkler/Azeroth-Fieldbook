local _, ns = ...

-- Deliberately small, literal, versioned reports. No Lua evaluation, compression,
-- SavedVariables serialization, authorship field, or received-rumour forwarding.
local report = { VERSION = 1, MAX_BYTES = 2048, MAX_LOCATIONS = 8,
    MAX_BASIC_REPORTS = 16, MAX_STORED_RUMOURS = 32, MAX_SHARED_ENTRIES = 500 }
ns.SharingReport = report
local schools = { Arcane=true, Fire=true, Frost=true, Holy=true, Nature=true, Shadow=true }
local behaviours = { Hostile=true, Neutral=true, Melee=true, Ranged=true, Caster=true,
    ["Flees at low health"]=true, ["Calls allies"]=true, Patrols=true, Summons=true,
    Heals=true, Enrages=true, Stealths=true }
function report.Public(value) return not (issecretvalue and issecretvalue(value)) end
function report.Text(value, limit)
    return report.Public(value) and type(value)=="string" and #value>0 and #value<=limit
        and not value:find("[%c|]") and value:match("%S") ~= nil
end
local function integer(value, low, high)
    return report.Public(value) and type(value)=="number" and value>=low and value<=high and value==math.floor(value)
end
report.Integer = integer
function report.Character(value)
    if not report.Text(value, 100) then return end
    -- Forever names are realm-free. Keep every surname component; hyphens
    -- and apostrophes belong to the name, never to an inferred realm suffix.
    local name=value:gsub("^ +",""):gsub(" +$",""):gsub(" +"," ")
    if name:find("[^%a\128-\255 '%-]") or not name:match("^[%a\128-\255]")
        or not name:match("[%a\128-\255]$") or name:find("[ '%-][ '%-]") then return end
    return name
end
function report.SameCharacter(a,b)
    a,b=report.Character(a),report.Character(b)
    return a~=nil and b~=nil and a:lower()==b:lower()
end
function report.Transaction(value)
    return report.Text(value,40) and value:match("^%d+%-%d+%-%d+$") ~= nil
end
local function keys(value, allowed)
    if not report.Public(value) or type(value)~="table" or getmetatable(value) then return false end
    for key in pairs(value) do if not report.Public(key) or not allowed[key] then return false end end
    return true
end
local function array(value, maximum)
    if not report.Public(value) or type(value)~="table" or getmetatable(value) then return false end
    local count=0
    for key in pairs(value) do
        if not integer(key,1,maximum) then return false end
        count=count+1
    end
    if count>maximum then return false end
    for i=1,count do if value[i]==nil then return false end end
    return count
end
local function validClaim(claim)
    if not keys(claim,{kind=true,value=true,spellID=true}) then return false end
    if not report.Text(claim.kind,16) or not report.Text(claim.value,100) then return false end
    if not report.Public(claim.spellID) then return false end
    if claim.kind=="ability" then
        -- One ability identity, never its freeform note or bundle of effects.
        if claim.value:find("[;.!?\n]") then return false end
        return claim.spellID==nil or integer(claim.spellID,1,2147483647)
    end
    if claim.spellID~=nil then return false end
    if claim.kind=="behaviour" then return behaviours[claim.value]==true end
    return (claim.kind=="offense" or claim.kind=="resistance" or claim.kind=="immunity") and schools[claim.value]==true
end
function report.ClaimText(claim)
    if claim.kind=="ability" then return "Casts " .. claim.value end
    if claim.kind=="offense" then return "Uses " .. claim.value .. " magic" end
    if claim.kind=="resistance" then return "Resistant to " .. claim.value end
    if claim.kind=="immunity" then return "Immune to " .. claim.value end
    return claim.value
end
local function claimName(value) return value:lower():gsub("^%s+",""):gsub("%s+$",""):gsub("%s+"," ") end
function report.ClaimKey(claim) return claim.kind .. ":" .. claimName(claim.value) end
function report.SameClaim(a,b)
    return a.kind==b.kind and (claimName(a.value)==claimName(b.value)
        or (a.kind=="ability" and a.spellID~=nil and a.spellID==b.spellID))
end
function report.Cost(claims)
    -- No selection quota. Every encoded claim needs multiple bytes, so the
    -- payload byte limit also provides a loose bound for validating arrays.
    local count=array(claims,report.MAX_BYTES)
    if not count then return nil end
    return 1+count
end
function report.Validate(value)
    if not keys(value,{version=true,transaction=true,created=true,recipient=true,creatureID=true,
        name=true,category=true,levelMin=true,levelMax=true,locations=true,rumours=true}) then return nil,"Unexpected report fields." end
    if not report.Public(value.version) or value.version~=report.VERSION then return nil,"Incompatible report version." end
    if not report.Transaction(value.transaction) or not integer(value.created,1,9999999999)
        or not report.Character(value.recipient) or not integer(value.creatureID,1,10000000)
        or not report.Text(value.name,100) or not report.Text(value.category,50) then return nil,"Invalid creature identity or report header." end
    if not report.Public(value.levelMin) or not report.Public(value.levelMax) then return nil,"Unreadable level range." end
    if value.levelMin~=nil or value.levelMax~=nil then
        if not integer(value.levelMin,1,255) or not integer(value.levelMax,1,255) or value.levelMin>value.levelMax then
            return nil,"Invalid level range."
        end
    end
    local n=array(value.locations,report.MAX_LOCATIONS)
    if not n then return nil,"Too many or invalid locations (maximum eight)." end
    local seen={}
    for _,location in ipairs(value.locations) do
        if not report.Text(location,80) or seen[location] then return nil,"Invalid or duplicate location." end
        seen[location]=true
    end
    if not report.Cost(value.rumours) then return nil,"Invalid rumour selection." end
    seen={}
    for _,claim in ipairs(value.rumours) do
        if not validClaim(claim) then return nil,"Invalid individual rumour." end
        local key=report.ClaimKey(claim)
        if seen[key] then return nil,"Duplicate rumour selection." end
        seen[key]=true
    end
    return true
end
-- Length-prefixed fields have an exact fixed order and count. All numeric
-- conversions occur only after bounded literal parsing; trailing fields fail.
function report.Encode(value)
    local ok,err=report.Validate(value)
    if not ok then return nil,err end
    local fields={}
    local function add(v) local s=tostring(v); fields[#fields+1]=#s .. ":" .. s end
    for _,v in ipairs({value.version,value.transaction,value.created,value.recipient,value.creatureID,
        value.name,value.category,value.levelMin or 0,value.levelMax or 0,#value.locations}) do add(v) end
    for _,location in ipairs(value.locations) do add(location) end
    add(#value.rumours)
    for _,claim in ipairs(value.rumours) do add(claim.kind); add(claim.value); add(claim.spellID or 0) end
    local encoded=table.concat(fields)
    if #encoded>report.MAX_BYTES then return nil,"Report is too large; select fewer rumours." end
    return encoded
end
function report.Decode(encoded)
    if not report.Text(encoded,report.MAX_BYTES) then return nil,"Invalid report data." end
    local position,failed=1,false
    local function take()
        local first,last,length=encoded:find("^(%d+):",position)
        if not first or #length>4 then failed=true; return "" end
        length=tonumber(length)
        if length>200 or last+length>#encoded then failed=true; return "" end
        local value=encoded:sub(last+1,last+length)
        position=last+length+1
        return value
    end
    local function numeric()
        local s=take()
        if not s:match("^%d+$") then failed=true; return -1 end
        return tonumber(s)
    end
    local value={version=numeric(),transaction=take(),created=numeric(),recipient=take(),creatureID=numeric(),
        name=take(),category=take(),levelMin=numeric(),levelMax=numeric(),locations={},rumours={}}
    if value.levelMin==0 and value.levelMax==0 then value.levelMin,value.levelMax=nil,nil end
    local n=numeric()
    if n<0 or n>report.MAX_LOCATIONS then return nil,"Invalid location count." end
    for _=1,n do value.locations[#value.locations+1]=take() end
    n=numeric()
    -- A declared count cannot exceed the remaining bytes. Reject impossible
    -- counts before allocating or iterating through claims from untrusted data.
    if failed or n<0 or n>#encoded-position+1 then return nil,"Invalid rumour count." end
    for _=1,n do
        local claim={kind=take(),value=take(),spellID=numeric()}
        if claim.spellID==0 then claim.spellID=nil end
        value.rumours[#value.rumours+1]=claim
    end
    if failed or position~=#encoded+1 then return nil,"Malformed report." end
    local ok,err=report.Validate(value)
    if not ok then return nil,err end
    return value
end
function report.Candidates(entry)
    local result={}
    for name,ability in pairs(entry.abilities or {}) do
        local claim={kind="ability",value=name,spellID=ability.spellID}
        if (ability.state=="pending" or ability.state=="confirmed") and validClaim(claim) then result[#result+1]=claim end
    end
    for _,group in ipairs({{"offenses","offense"},{"resistances","resistance"},{"immunities","immunity"},{"behaviours","behaviour"}}) do
        for value,enabled in pairs(entry[group[1]] or {}) do
            local claim={kind=group[2],value=value}
            if enabled==true and validClaim(claim) then result[#result+1]=claim end
        end
    end
    table.sort(result,function(a,b) return report.ClaimKey(a)<report.ClaimKey(b) end)
    return result
end
function report.Capture(journal,id)
    local entry=journal.entries[id]
    if not entry then return nil,"Select a creature first." end
    local basic=journal:GetBasicInfo(id)
    local captured={version=report.VERSION,creatureID=id,name=basic.name,category=basic.category,
        levelMin=basic.levelMin,levelMax=basic.levelMax,locations={},rumours={}}
    for location in pairs(basic.locations) do captured.locations[#captured.locations+1]=location end
    table.sort(captured.locations)
    -- Never silently drop recorded locations to fit the protocol.
    local probe={}
    for k,v in pairs(captured) do probe[k]=v end
    probe.transaction,probe.created,probe.recipient="1-1-1",1,"Preview"
    local ok,err=report.Encode(probe)
    if not ok then return nil,err end
    return captured,report.Candidates(entry)
end
local function basicKey(value)
    return table.concat({value.name,value.category,value.levelMin or 0,value.levelMax or 0,table.concat(value.locations,"\n")},"\n")
end
function ns.InstallSharingRecords(journal)
    function journal:GetBasicInfo(id)
        local entry=self.entries[id]
        if not entry then return end
        local localBasic=entry.confirmed and entry.lockedBasic or entry
        local basic={name=self:GetCreatureName(id),category=localBasic.category,levelMin=localBasic.levelMin,levelMax=localBasic.levelMax,locations={}}
        for location in pairs(localBasic.locations or {}) do basic.locations[location]=true end
        for _,shared in ipairs(entry.sharedReports or {}) do
            basic.hasShared=true
            -- A locked personal page keeps exactly its local metadata. Reports
            -- remain separately available in Rumours and after unlocking.
            if not entry.confirmed then
                if not basic.category or basic.category=="Unclassified" then basic.category=shared.category end
                if shared.levelMin then
                    basic.levelMin=math.min(basic.levelMin or shared.levelMin,shared.levelMin)
                    basic.levelMax=math.max(basic.levelMax or shared.levelMax,shared.levelMax)
                end
                for _,location in ipairs(shared.locations) do basic.locations[location]=true end
            end
        end
        basic.category=basic.category or "Unclassified"
        basic.personal=entry.personalEncountered==true
        return basic
    end
    local traitFields={offense="offenses",resistance="resistances",immunity="immunities",behaviour="behaviours"}
    function journal:IsRumourKnown(id,claim)
        local entry=self.entries[id]
        if not entry then return false end
        if claim.kind=="ability" then
            for name,ability in pairs(entry.abilities or {}) do
                if ability.state=="confirmed" and report.SameClaim(claim,{kind="ability",value=name,spellID=ability.spellID}) then return true end
            end
        else
            local field=traitFields[claim.kind]
            return field~=nil and entry[field]~=nil and entry[field][claim.value]==true
        end
        return false
    end
    function journal:WasRumourRejected(id,claim)
        local entry=self.entries[id]
        for _,existing in ipairs(entry and entry.rumours or {}) do
            if (existing.dismissed or existing.rejected or existing.previouslyRejected) and report.SameClaim(existing,claim) then return true end
        end
        if entry and claim.kind=="ability" then
            for name,ability in pairs(entry.abilities or {}) do
                if ability.state=="rejected" and report.SameClaim(claim,{kind="ability",value=name,spellID=ability.spellID}) then return true end
            end
            for name,ignored in pairs(entry.ignoredAbilities or {}) do
                if ignored and report.SameClaim(claim,{kind="ability",value=name}) then return true end
            end
        end
        return false
    end
    function journal:GetRumours(id,includeHistory)
        local result={}
        for _,claim in ipairs(self.entries[id] and self.entries[id].rumours or {}) do
            if includeHistory or (not claim.dismissed and not claim.resolved and not self:IsRumourKnown(id,claim)) then result[#result+1]=claim end
        end
        return result
    end
    function journal:ResolveRumours(id,claim)
        local changed=false
        for _,existing in ipairs(self.entries[id] and self.entries[id].rumours or {}) do
            if not existing.resolved and report.SameClaim(existing,claim) then
                -- Retain rejection history, including dismissals from older builds.
                existing.rejected=existing.rejected or existing.dismissed or nil
                existing.resolved=true; changed=true
            end
        end
        if changed then self:Touch() end
    end
    function journal:DismissRumour(id,claim)
        for _,existing in ipairs(self.entries[id] and self.entries[id].rumours or {}) do
            if existing==claim and not existing.resolved then
                existing.dismissed,existing.rejected=true,true
                self:Touch(); return true
            end
        end
        return false
    end
    function journal:ConfirmRumour(id,claim)
        local entry=self.entries[id]
        if not entry then return false,"Select a creature first." end
        if entry.confirmed then return false,"Unlock this creature before verifying rumours." end
        local found=false
        for _,existing in ipairs(entry.rumours or {}) do
            if existing==claim and not existing.dismissed and not existing.resolved then found=true; break end
        end
        if not found or not validClaim({kind=claim.kind,value=claim.value,spellID=claim.spellID}) then
            return false,"This rumour is no longer available."
        end
        if claim.kind=="ability" then
            local name=claim.value
            if not entry.abilities[name] then
                for existing,ability in pairs(entry.abilities) do
                    if report.SameClaim(claim,{kind="ability",value=existing,spellID=ability.spellID}) then name=existing; break end
                end
            end
            -- Confirm in place so existing private notes, effects and tooltip
            -- preferences survive. Never Ensure/Offer: verification earns no credit.
            local ability=entry.abilities[name] or {origin="Your verification"}
            ability.spellID=ability.spellID or claim.spellID
            entry.abilities[name]=ability
            for ignored in pairs(entry.ignoredAbilities or {}) do
                if claimName(ignored)==claimName(name) or claimName(ignored)==claimName(claim.value) then entry.ignoredAbilities[ignored]=nil end
            end
            self:SetAbility(id,name,"confirmed")
        else
            local setters={offense="SetOffense",resistance="SetResistance",immunity="SetImmunity",behaviour="SetBehaviour"}
            self[setters[claim.kind]](self,id,claim.value,true)
        end
        return true,"Rumour verified and added to your journal."
    end
    function journal:PreviewReport(value,sender)
        local valid,err=report.Validate(value)
        if not valid or not report.Character(sender) then return nil,err or "Invalid sender." end
        local entry=self.entries[value.creatureID]
        if entry and entry.id~=value.creatureID then return nil,"Creature identity mismatch." end
        local basic=entry and self:GetBasicInfo(value.creatureID)
        local newBasic=not entry or not basic.name or basic.name~=value.name or basic.category~=value.category
        if basic then
            if value.levelMin and (not basic.levelMin or value.levelMin<basic.levelMin or value.levelMax>basic.levelMax) then newBasic=true end
            for _,location in ipairs(value.locations) do if not basic.locations[location] then newBasic=true end end
        end
        local duplicateBasic=false
        for _,shared in ipairs(entry and entry.sharedReports or {}) do
            if basicKey(shared)==basicKey(value) then
                newBasic=false
                if report.SameCharacter(shared.sender,sender) then duplicateBasic=true end
            end
        end
        local additions,replacements,newSlots={},{},0
        for _,claim in ipairs(value.rumours) do
            local duplicate
            for _,existing in ipairs(entry and entry.rumours or {}) do
                if report.SameCharacter(existing.sender,sender) and report.SameClaim(existing,claim) then duplicate=existing; break end
            end
            if not self:IsRumourKnown(value.creatureID,claim) and (not duplicate or
                ((duplicate.dismissed or duplicate.resolved) and duplicate.transaction~=value.transaction)) then
                additions[#additions+1]=claim
                replacements[#additions]=duplicate
                if not duplicate then newSlots=newSlots+1 end
            end
        end
        if not duplicateBasic and #(entry and entry.sharedReports or {})>=report.MAX_BASIC_REPORTS then
            return nil,"This creature already holds sixteen basic reports."
        end
        if #(entry and entry.rumours or {})+newSlots>report.MAX_STORED_RUMOURS then return nil,"This creature's rumour storage is full." end
        if not entry or not entry.sharedReports then
            local count=0
            for _,e in pairs(self.entries) do if e.sharedReports then count=count+1 end end
            if count>=report.MAX_SHARED_ENTRIES then return nil,"Shared creature storage is full." end
        end
        return {newBasic=newBasic==true,newRumours=#additions,rumours=additions,replacements=replacements,duplicateBasic=duplicateBasic,
            newInformation=newBasic==true or #additions>0,locked=entry and entry.confirmed==true,
            conflict=entry and ((entry.name and entry.name~=value.name) or
                (entry.category~="Unclassified" and entry.category~=value.category)) or false}
    end
    function journal:ImportReport(value,sender,received)
        -- Only the transaction engine calls this after explicit acceptance and
        -- commit. Revalidate everything before the first database mutation.
        local preview,err=self:PreviewReport(value,sender)
        if not preview then return nil,err end
        if not integer(received,1,9999999999) then return nil,"Invalid receipt time." end
        local entry=self:Ensure(value.creatureID,true)
        entry.sharedReports=entry.sharedReports or {}
        entry.rumours=entry.rumours or {}
        if not preview.duplicateBasic then
            local shared={creatureID=value.creatureID,name=value.name,category=value.category,levelMin=value.levelMin,
                levelMax=value.levelMax,locations={},sender=sender,transaction=value.transaction,received=received,source="WHISPER"}
            for _,location in ipairs(value.locations) do shared.locations[#shared.locations+1]=location end
            entry.sharedReports[#entry.sharedReports+1]=shared
        end
        for index,claim in ipairs(preview.rumours) do
            local rejected=self:WasRumourRejected(value.creatureID,claim)
            local stored=preview.replacements[index]
            if not stored then stored={}; entry.rumours[#entry.rumours+1]=stored end
            stored.creatureID,stored.kind,stored.value,stored.spellID=value.creatureID,claim.kind,claim.value,claim.spellID
            stored.sender,stored.transaction,stored.received,stored.source=sender,value.transaction,received,"WHISPER"
            stored.previouslyRejected=rejected or nil
            stored.dismissed,stored.resolved=nil,nil
        end
        self:Touch()
        return true
    end
end
