local _, ns = ...
local schema=ns.SharingReport
local SPELL=1462

local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok and schema.Public(value) then return value end
end
local function text(value)
    if not schema.Public(value) or type(value)~="string" then return end
    value=value:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("\r\n","\n"):gsub("\n"," / "):gsub("\t"," "):match("^%s*(.-)%s*$")
    if schema.Text(value,200) then return value end
end
local function tooltip(unit)
    local data=read(C_TooltipInfo and C_TooltipInfo.GetUnit,unit)
    if type(data)~="table" or not schema.Public(data.lines) or type(data.lines)~="table" then return end
    local rows={}
    for _,line in ipairs(data.lines) do
        if not schema.Public(line) or type(line)~="table" then return end
        -- Never accept a partial snapshot with hidden fields.
        if not schema.Public(line.leftText) or not schema.Public(line.rightText) then return end
        local left,right=text(line.leftText),text(line.rightText)
        for _,value in ipairs({line.leftText or "",line.rightText or ""}) do
            if type(value)~="string" or (value:match("%S") and not text(value)) then return end
        end
        if not left and right then left,right=right,nil end
        if left then rows[#rows+1]={left=left,right=right} end
        if #rows>64 then return end
    end
    return rows
end
local function key(row) return row.left .. "\t" .. (row.right or "") end
local function loreLine(row)
    local prefix=row.left:match("^([^:]+):") or row.left
    return ({Damage=true,Health=true,Armor=true,Armour=true,Diet=true,Abilities=true,
        Resistances=true,Resistance=true,["Fire Resistance"]=true,["Frost Resistance"]=true,
        ["Nature Resistance"]=true,["Shadow Resistance"]=true,["Arcane Resistance"]=true,
        ["Holy Resistance"]=true,Tameable=true,["Cannot be Tamed"]=true,Exotic=true,
        ["Pet Family"]=true,Family=true,Specialization=true})[prefix]==true
end

function ns.InstallBeastLore(journal,identify)
    local pending
    function journal:ClearBeastLoreCapture(id)
        if not id or (pending and pending.id==id) then pending=nil end
    end
    function journal:BeastLoreEvent(event,unit,targetOrCast,castOrSpell,spell)
        if not schema.Public(unit) or unit~="player" then return end
        if event=="UNIT_SPELLCAST_SENT" then
            if not schema.Public(spell) or spell~=SPELL then return end
            pending=nil
            if not schema.Text(targetOrCast,200) or not schema.Text(castOrSpell,100) then return end
            for _,token in ipairs({"target","mouseover"}) do
                local id=read(identify,token)
                local guid=read(UnitGUID,token)
                local name=read(UnitName,token)
                if id and schema.Text(guid,100) and name==targetOrCast and read(UnitCreatureType,token)=="Beast" then
                    -- SENT supplies a name, not a GUID. Two different beasts
                    -- with that name are ambiguous (for example a mouseover macro).
                    if pending and pending.guid~=guid then pending=nil;return end
                    local before=tooltip(token)
                    if not before then return end
                    pending={id=id,guid=guid,cast=castOrSpell,before={},elapsed=0}
                    for _,row in ipairs(before) do pending.before[key(row)]=true end
                end
            end
        elseif event=="UNIT_SPELLCAST_SUCCEEDED" and schema.Public(castOrSpell) and castOrSpell==SPELL
            and schema.Public(targetOrCast) and pending and pending.cast==targetOrCast then
            pending.succeeded=true
            pending.elapsed=0
            self:PollBeastLore(0)
        end
    end
    function journal:PollBeastLore(elapsed)
        if not pending then return end
        pending.elapsed=pending.elapsed+elapsed
        if pending.elapsed>5 then pending=nil;return end
        if not pending.succeeded then return end
        pending.scan=(pending.scan or 0)+elapsed
        if elapsed>0 and pending.scan<0.2 then return end
        pending.scan=0
        for _,unit in ipairs({"target","mouseover"}) do
            if read(UnitGUID,unit)==pending.guid and read(identify,unit)==pending.id then
                local rows=tooltip(unit)
                local level=read(UnitLevel,unit)
                if not rows or not schema.Integer(level,1,255) then return end
                local captured,hasLore={},false
                local existing=self.entries[pending.id]
                local remembered={}
                if existing and existing.beastLoreSource=="gameTooltip" and schema.ValidLore(existing.beastLore) then
                    for _,row in ipairs(existing.beastLore.rows) do remembered[key(row)]=true end
                end
                for _,row in ipairs(rows) do
                    -- The native tooltip diff preserves additional/localized lore
                    -- fields; known labels also survive repeated casts unchanged.
                    local known=loreLine(row)
                    if known or remembered[key(row)] or not pending.before[key(row)] then
                        captured[#captured+1]=row
                        hasLore=hasLore or known
                    end
                end
                if not hasLore then return end
                if #captured<(pending.rowCount or 0) then return end
                local value={level=level,observed=read(time),rows=captured}
                if not schema.ValidLore(value) then return end
                pending.rowCount=#captured
                local entry=self.entries[pending.id]
                if not entry then
                    self:Observe(unit)
                    entry=self.entries[pending.id]
                end
                if not entry then return end
                local old=entry.beastLore
                if not old or schema.LoreText(old)~=schema.LoreText(value) or entry.beastLoreSource~="gameTooltip" then
                    entry.beastLore=value
                    entry.beastLoreSource="gameTooltip"
                    entry.beastLoreSender=nil
                    self:Touch()
                end
                -- Continue the bounded retry window to include delayed fields.
                return
            end
        end
    end
end
