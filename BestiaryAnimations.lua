local _, ns = ...

-- AnimationData IDs, shared by creature rigs. Availability belongs to the
-- loaded model, never to the creature's recorded spells.
local melee = {16, 17, 18, 19} -- Unarmed, 1H, 2H, 2HL
local ranged = {47, 49, 106} -- FireBow, AttackRifle, AttackThrown
local casts = {53, 54, 32, 33, 2}
local schools = {"Arcane", "Fire", "Frost", "Holy", "Nature", "Shadow"}
-- Directed cast HAND kits, not missiles, impact effects or persistent auras.
-- Provenance and native verification checklist: tests/BESTIARY_ANIMATIONS.md.
local castKits = {Arcane=730, Fire=38, Frost=202, Holy=119, Nature=3291, Shadow=118}

function ns.CreateBestiaryAnimations(model)
    local controller = {}
    local supported, failedKits = {}, {}
    local signature, entryID, actions, active, remaining, lastAction, lastSchool
    local function call(method, ...)
        if type(model[method]) ~= "function" then return false end
        local ok, result = pcall(model[method], model, ...)
        return ok and not (issecretvalue and issecretvalue(result)) and result ~= false
    end
    local function has(id)
        if supported[id] == nil then
            local ok, value = false, nil
            if type(model.HasAnimation) == "function" then ok, value = pcall(model.HasAnimation, model, id) end
            supported[id] = ok and not (issecretvalue and issecretvalue(value)) and value == true
        end
        return supported[id]
    end
    local function play(id)
        if has(id) and call("SetAnimation", id) then return true end
        supported[id] = false
        return false
    end
    local function delay(first)
        return first and math.random(20, 40)/10 or math.random(40, 80)/10
    end
    local function choose(values, previous)
        local choices = {}
        for _, value in ipairs(values) do
            if value ~= previous then choices[#choices+1] = value end
        end
        if #choices == 0 then return values[1] end
        return choices[math.random(#choices)]
    end
    local function idle()
        if active then play(0) end
        active = nil
    end
    function controller:Reset()
        idle()
        supported, failedKits = {}, {}
        signature, entryID, actions, remaining, lastAction, lastSchool = nil, nil, nil, nil, nil, nil
    end
    local function profile(entry)
        local flags = {}
        local behaviours = type(entry.behaviours) == "table" and entry.behaviours or {}
        local offenses = type(entry.offenses) == "table" and entry.offenses or {}
        for _, name in ipairs({"Melee", "Ranged", "Caster"}) do flags[#flags+1] = behaviours[name] == true and "1" or "0" end
        for _, name in ipairs(schools) do flags[#flags+1] = offenses[name] == true and "1" or "0" end
        return table.concat(flags), behaviours, offenses
    end
    local function build(behaviours, offenses)
        actions = {}
        -- Without a supported idle we cannot reliably return the illustration
        -- to rest; do not start a one-shot action in that case.
        if not has(0) or type(model.SetAnimation) ~= "function" then return end
        local function add(kind, ids)
            for _, id in ipairs(ids) do
                if has(id) then actions[#actions+1] = {kind=kind, id=id, key=kind..id} end
            end
        end
        if behaviours.Melee == true then add("melee", melee) end
        if behaviours.Ranged == true then add("ranged", ranged) end
        if behaviours.Caster == true then
            local selectedSchools = {}
            for _, name in ipairs(schools) do
                if offenses[name] == true then selectedSchools[#selectedSchools+1] = name end
            end
            -- These kits carry directed animation 53 themselves. Never apply
            -- them to a rig which only supports an omni/legacy casting slot.
            local candidates = #selectedSchools > 0 and has(53) and {53} or casts
            add("cast", candidates)
            for _, action in ipairs(actions) do
                if action.kind == "cast" then action.schools = selectedSchools end
            end
        end
    end
    local function release()
        if not play(active.id) then
            idle(); remaining = delay(false)
            return
        end
        if active.id == 53 and active.school then
            local kit = castKits[active.school]
            if not failedKits[kit] and not call("ApplySpellVisualKit", kit, true) then failedKits[kit] = true end
        end
        active.phase = "release"
        remaining = 1.4
    end
    function controller:Update(elapsed, entry, ready, rotating)
        if not ready or not entry then
            if signature then self:Reset() end
            return
        end
        local key, behaviours, offenses = profile(entry)
        if signature ~= key or entryID ~= entry.id then
            idle()
            signature, entryID, lastAction, lastSchool = key, entry.id, nil, nil
            build(behaviours, offenses)
            remaining = delay(true)
        end
        if rotating then
            idle(); remaining = delay(true)
            return
        end
        if #actions == 0 then return end
        remaining = remaining - math.max(0, elapsed or 0)
        if remaining > 0 then return end
        -- At most one transition per update: a long frame never bursts several
        -- attacks or advances a new action straight through to idle.
        if active then
            if active.phase == "prepare" then release()
            else idle(); remaining = delay(false) end
            return
        end
        local choices = {}
        for _, action in ipairs(actions) do
            if supported[action.id] ~= false and action.key ~= lastAction then choices[#choices+1] = action end
        end
        if #choices == 0 then
            for _, action in ipairs(actions) do
                if supported[action.id] ~= false then choices[#choices+1] = action end
            end
        end
        if #choices == 0 then return end
        local action = choose(choices)
        active = {id=action.id, phase="release"}
        lastAction = action.key
        if action.kind == "cast" then
            active.school = choose(action.schools, lastSchool)
            lastSchool = active.school
            local prep = (action.id == 54 or action.id == 33) and 52 or 51
            if play(prep) then
                active.phase = "prepare"; remaining = math.random(10, 18)/10
            else release() end
        elseif play(action.id) then remaining = 1.2
        else idle(); remaining = delay(false) end
    end
    return controller
end
