"""Run with Python + lupa (Lua 5.1). No game or live SavedVariables required."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

source = Path(__file__).resolve().parents[1].joinpath('ClassicBestiary.lua').read_text()
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
clock = 0
function GetTime() return clock end
secret = {}
function issecretvalue(v) return rawequal(v, secret) end
SlashCmdList = {}
messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) messages[#messages+1] = m end }
frames = {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(script, fn)
        if script == 'OnEvent' then self.handler = fn else self[script] = fn end
    end
    frames[#frames+1] = f
    return f
end
function fire(e, ...) frames[1].handler(frames[1], e, ...) end
guid = 'Creature-0-1-2-3-42-000001'
playerGUID = 'Player-0-1-2-3-999-000001'
visible, exists, hostile, controlled = true, true, true, false
function UnitGUID(unit) return unit == 'player' and playerGUID or guid end
function UnitExists() return exists end
function UnitIsVisible() return visible end
function UnitCanAttack() return hostile end
function UnitPlayerControlled() return controlled end
function UnitIsUnit(a, b) return a == alias and b == 'target' end
function UnitCastingInfo() return castName, nil, nil, nil, nil, nil, nil, nil, castID end
function UnitChannelInfo() return channelName, nil, nil, nil, nil, nil, nil, channelID end
lookups = {}
C_Spell = {GetSpellName = function(id)
    lookups[#lookups+1] = id
    return 'Test ability '..id
end}
GameTooltip = { lines = {} }
function GameTooltip:GetUnit() return 'Test creature', 'mouseover' end
function GameTooltip:AddLine(s) self.lines[#self.lines+1] = s end
TooltipDataProcessor = {AddTooltipPostCall = function(_, fn) tooltipHook = fn end}
Enum = {TooltipDataType = {Unit = 1}}
function count()
    local n = 0
    for _, c in pairs(ClassicBestiaryObservedDB.creatures) do
        for _ in pairs(c.spells) do n=n+1 end
        for _ in pairs(c.names or {}) do n=n+1 end
    end
    return n
end
function cast(unit, id, event) fire(event or 'UNIT_SPELLCAST_START', unit, 'cast', id) end
function check(value, message) assert(value, message) end
''')
lua.execute(source, 'ClassicBestiary')
lua.execute(r'''
-- Preloaded original data must never affect the new database.
ClassicBestiary = {map = {[42] = {999}}, tip = {}, st = {}}
fire('ADDON_LOADED', 'OtherAddon')
check(ClassicBestiaryObservedDB == nil, 'unrelated load')
fire('ADDON_LOADED', 'ClassicBestiary')
check(count() == 0, 'empty start')
tooltipHook(GameTooltip)
check(#GameTooltip.lines == 0 and #lookups == 0, 'unknown hover leaks nothing')
cast('target', 101)
check(count() == 1, 'learn cast start')
cast('target', 101)
cast('mouseover', 101)
check(count() == 1, 'deduplicate unit aliases and repeat casts')
cast('target', 102, 'UNIT_SPELLCAST_SUCCEEDED')
cast('mouseover', 103, 'UNIT_SPELLCAST_CHANNEL_START')
cast('target', 104, 'UNIT_SPELLCAST_EMPOWER_START')
check(count() == 4, 'instant, channel and empower')
for _, unit in ipairs({'focus','boss1','nameplate1','party1target','player','pet'}) do
    cast(unit, 999)
end
check(count() == 4, 'ignore background and player units')
visible = false; cast('target', 999); visible = true
exists = false; cast('target', 999); exists = true
hostile = false; cast('target', 999); hostile = true
controlled = true; cast('target', 999); controlled = false
check(count() == 4, 'visibility and hostility gates')
for _, bad in ipairs({secret, 0, -1, 1.5, '999', math.huge}) do cast('target', bad) end
cast(secret, 999)
visible = secret; cast('target', 999); visible = true
hostile = secret; cast('target', 999); hostile = true
controlled = secret; cast('target', 999); controlled = false
guid = secret; cast('target', 999)
guid = 'Player-1-42'; cast('target', 999)
guid = 'Pet-0-1-2-3-42-000001'; cast('target', 999)
guid = 'Creature-0-1-2-3-42-000001'
check(count() == 4, 'fail closed on all restricted/invalid inputs')
local oldGUID = UnitGUID
UnitGUID = function() error('restricted') end
cast('target', 999)
UnitGUID = oldGUID
check(count() == 4, 'API failure')
castName, castID = 'Active cast', 105
fire('PLAYER_TARGET_CHANGED')
castName, castID = nil, nil
channelName, channelID = 'Active channel', 106
fire('UPDATE_MOUSEOVER_UNIT')
channelName, channelID = nil, nil
check(count() == 6, 'active cast and channel return positions')
castName, castID = secret, secret
fire('PLAYER_TARGET_CHANGED')
castName, castID = nil, nil
check(count() == 6, 'secret active cast')
tooltipHook(GameTooltip)
check(#GameTooltip.lines == 7, 'header plus only six observed names')
for _, name in ipairs(GameTooltip.lines) do check(not name:find('999'), 'no unseen name') end
for _, id in ipairs(lookups) do check(id ~= 999, 'never query an unseen spell') end
-- Even a matching numeric ID must not show creature discoveries on other types.
local lookupCount = #lookups
for _, otherGUID in ipairs({'Player-1-42', 'Pet-0-1-2-3-42-000001',
    'Vehicle-0-1-2-3-42-000001'}) do
    guid = otherGUID
    GameTooltip.lines = {}
    tooltipHook(GameTooltip)
    cast('target', 999)
    cast('mouseover', 999, 'UNIT_SPELLCAST_SUCCEEDED')
    castName, castID = 'Not an NPC cast', 999
    fire('PLAYER_TARGET_CHANGED')
    fire('UPDATE_MOUSEOVER_UNIT')
    castName, castID = nil, nil
    check(#GameTooltip.lines == 0 and count() == 6, 'NPC-only learning and tooltip')
end
guid = 'Creature-0-1-2-3-42-000001'
for _, ownership in ipairs({true, secret}) do
    controlled = ownership
    GameTooltip.lines = {}
    tooltipHook(GameTooltip)
    cast('target', 999)
    check(#GameTooltip.lines == 0 and count() == 6, 'controlled creature excluded')
end
controlled = false
check(#lookups == lookupCount, 'excluded units never query spell names')
GameTooltip.lines = {}
tooltipHook(GameTooltip)
check(#GameTooltip.lines == 7, 'ordinary NPC tooltip still works')
guid = 'Creature-0-1-2-3-43-000001'
GameTooltip.lines = {}
tooltipHook(GameTooltip)
check(#GameTooltip.lines == 0, 'no cross-creature leak')
cast('target', 101)
check(count() == 7, 'same spell needs independent creature evidence')
check(#messages == 0, 'alerts default off')
SlashCmdList.CLASSICBESTIARYOBSERVED('alerts')
cast('target', 107)
check(messages[#messages]:find('107'), 'optional discovery message')
saved = ClassicBestiaryObservedDB
''')
# Reload addon with the same character data; a different character has no variable.
lua.execute(source, 'ClassicBestiary')
lua.execute(r'''
frames[2].handler(frames[2], 'ADDON_LOADED', 'ClassicBestiary')
check(ClassicBestiaryObservedDB == saved and count() == 8, 'reload preserves data')
SlashCmdList.CLASSICBESTIARYOBSERVED('reset')
check(count() == 8, 'reset requires explicit command')
SlashCmdList.CLASSICBESTIARYOBSERVED('wipe confirm all')
check(count() == 8, 'cannot skip confirmation one')
SlashCmdList.CLASSICBESTIARYOBSERVED('wipe')
SlashCmdList.CLASSICBESTIARYOBSERVED('wipe cancel')
SlashCmdList.CLASSICBESTIARYOBSERVED('wipe confirm')
check(count() == 8, 'cancel disarms confirmation')
SlashCmdList.CLASSICBESTIARYOBSERVED('wipe')
clock = 61
SlashCmdList.CLASSICBESTIARYOBSERVED('wipe confirm')
check(count() == 8, 'confirmation expires')
SlashCmdList.CLASSICBESTIARYOBSERVED('wipe')
SlashCmdList.CLASSICBESTIARYOBSERVED('  WIPE   CONFIRM  ')
check(messages[#messages]:find('has been wiped', 1, true), 'second command completes wipe with extra spaces')
check(count() == 0, 'reset clears')
ClassicBestiaryObservedDB = nil
''')
lua.execute(source, 'ClassicBestiary')
lua.execute("frames[3].handler(frames[3], 'ADDON_LOADED', 'ClassicBestiary'); check(count() == 0, 'new character empty')")
lua.execute(r'''
alias = 'nameplate7'
frames[3].handler(frames[3], 'UNIT_SPELLCAST_SUCCEEDED', alias, 'cast', 201)
check(count() == 1, 'event alias matching current target is accepted')
frames[3].handler(frames[3], 'UNIT_SPELLCAST_SUCCEEDED', 'nameplate8', 'cast', 202)
check(count() == 1, 'unrelated nameplate still excluded')
castName, castID = 'Observed ongoing cast', 203
frames[3].OnUpdate(frames[3], 0.1)
check(count() == 1, 'poll throttled')
frames[3].OnUpdate(frames[3], 0.1)
check(count() == 2, 'ongoing cast detected without start event')
castName, castID = secret, secret
frames[3].OnUpdate(frames[3], 0.2)
check(count() == 2, 'poll cannot learn restricted cast')
SlashCmdList.CLASSICBESTIARYOBSERVED('debug')
local found = false
for _, m in ipairs(messages) do if m:find('name SECRET; ID SECRET', 1, true) then found = true end end
check(found, 'restricted cast diagnostic')
castName, castID = 'Player cast', 204
guid = 'Player-1-42'
frames[3].OnUpdate(frames[3], 0.2)
check(count() == 2, 'poll excludes players')
guid = 'Creature-0-1-2-3-43-000001'
local oldName = C_Spell.GetSpellName
C_Spell.GetSpellName = function() return nil end
castName, castID = 'Actually observed name', 205
frames[3].handler(frames[3], 'UNIT_SPELLCAST_START', 'target', 'cast', 205)
check(count() == 3, 'active cast name works with uncached spell')
C_Spell.GetSpellName = oldName
castName, castID = nil, nil
local beforeLookups = #lookups
castName, castID = 'Publicly observed potion', secret
frames[3].handler(frames[3], 'UNIT_SPELLCAST_START', 'target', secret, secret)
check(count() == 4, 'readable cast name does not require readable ID')
check(#lookups == beforeLookups, 'hidden ID never sent to spell API')
frames[3].OnUpdate(frames[3], 0.2)
check(count() == 4, 'name-only observations deduplicate')
GameTooltip.lines = {}
tooltipHook(GameTooltip)
local displayed = false
for _, line in ipairs(GameTooltip.lines) do
    if line == 'Publicly observed potion' then displayed = true end
end
check(displayed, 'name-only observation displayed')
castID = 206
frames[3].OnUpdate(frames[3], 0.2)
check(count() == 4, 'readable ID upgrades name record without duplicate')
castName, castID = secret, secret
frames[3].OnUpdate(frames[3], 0.2)
check(count() == 4, 'both hidden still skipped')
castName, castID = 'Unseen player ability', secret
guid = 'Player-1-42'
frames[3].OnUpdate(frames[3], 0.2)
check(count() == 4, 'name-only path remains NPC-only')
''')
lua.execute(r'''
guid = 'Creature-0-1-2-3-43-000001'
castName, castID = nil, nil
channelName, channelID = nil, nil
local oldCasting = UnitCastingInfo
local function debugOutput()
    messages = {}
    SlashCmdList.CLASSICBESTIARYOBSERVED('debug')
    return table.concat(messages, '\n')
end
UnitCastingInfo = function() error('DO_NOT_PRINT_UNSEEN_SPELL') end
frames[3].OnUpdate(frames[3], 0.2)
local output = debugOutput()
check(output:find('target UnitCastingInfo: API ERROR (pcall failed)', 1, true), 'API exception classified')
check(not output:find('DO_NOT_PRINT_UNSEEN_SPELL', 1, true), 'error payload never printed')
UnitCastingInfo = oldCasting
frames[3].OnUpdate(frames[3], 0.2)
output = debugOutput()
check(output:find('target UnitCastingInfo: IDLE', 1, true), 'nil cast is idle not restricted')
check(output:find('Earlier non-readable result: API ERROR', 1, true), 'error evidence retained after idle')
UnitCastingInfo = nil
frames[3].OnUpdate(frames[3], 0.2)
check(debugOutput():find('target UnitCastingInfo: API MISSING', 1, true), 'missing API distinguished')
UnitCastingInfo = oldCasting
castName, castID = secret, nil
frames[3].OnUpdate(frames[3], 0.2)
check(debugOutput():find('name SECRET; ID MISSING', 1, true), 'fields classified independently')
castName, castID = '', -1
frames[3].OnUpdate(frames[3], 0.2)
check(debugOutput():find('name INVALID; ID INVALID', 1, true), 'invalid public data distinguished')
castName, castID = secret, secret
frames[3].OnUpdate(frames[3], 0.2)
castName, castID = nil, nil
frames[3].OnUpdate(frames[3], 0.2)
check(debugOutput():find('Earlier non-readable result: name SECRET; ID SECRET', 1, true), 'secret evidence retained after idle')
controlled = secret
check(debugOutput():find('target: UnitPlayerControlled: SECRET', 1, true), 'ownership secret diagnosed')
controlled = false
local oldGUID = UnitGUID
UnitGUID = function() error('DO_NOT_PRINT_GUID_ERROR') end
check(debugOutput():find('target: UnitGUID: API ERROR', 1, true), 'identity error diagnosed')
UnitGUID = oldGUID
guid = 'Creature-0-1-2-3-9999-000001'
GameTooltip.lines = {}
tooltipHook(GameTooltip)
output = debugOutput()
check(output:find('Last tooltip: Eligible NPC, but no saved observations', 1, true), 'empty database distinguished from display error')
check(count() == 4, 'diagnostic failures cannot add abilities')
''')
# Exercise real TOC order and encounter -> SavedVariables -> tooltip integration.
namespace = lua.table()
lua.execute(Path(__file__).resolve().parents[1].joinpath('EncounterReader.lua').read_text(), 'ClassicBestiary', namespace)
lua.execute(source, 'ClassicBestiary', namespace)
lua.execute(r'''
ClassicBestiaryObservedDB = nil
frames[4].handler(frames[4], 'ADDON_LOADED', 'ClassicBestiary')
function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
Enum.DamageMeterType = {DamageDone=0, HealingDone=2, DamageTaken=7, EnemyDamageTaken=10}
Enum.DamageMeterSourceDisplayType = {Ally=1, Enemy=2}
C_DamageMeter = {
    IsDamageMeterAvailable = function() return true end,
    GetAvailableCombatSessions = function() return {{sessionID=1}} end,
    GetCombatSessionFromID = function(_, mode)
        if mode == 10 then return {combatSources={{sourceCreatureID=42, name='Test NPC', classFilename='', isLocalPlayer=false}}} end
        if mode == 7 then return {combatSources={{sourceGUID='Player-1-1'}}} end
        return {combatSources={}}
    end,
    GetCombatSessionSourceFromID = function()
        return {combatSpells={{spellID=601, creatureName='', combatSpellDetails={unitName='Test NPC', unitClassFilename='', isMob=true, isPet=false}}}}
    end
}
castName, castID = nil, nil
frames[4].handler(frames[4], 'PLAYER_REGEN_ENABLED')
frames[4].OnUpdate(frames[4], 1.1)
check(ClassicBestiaryObservedDB.creatures[42].spells[601].name == 'Test ability 601', 'encounter result persisted in main DB')
guid = 'Creature-0-1-2-3-42-000001'
GameTooltip.lines = {}
tooltipHook(GameTooltip)
check(GameTooltip.lines[2] == 'Test ability 601', 'encounter result rendered in tooltip')
SlashCmdList.CLASSICBESTIARYOBSERVED('wipe')
SlashCmdList.CLASSICBESTIARYOBSERVED('wipe confirm')
frames[4].OnUpdate(frames[4], 4)
check(count() == 0, 'main reset stops queued reimport')
''')
toc = Path(__file__).resolve().parents[1].joinpath('ClassicBestiary.toc').read_text()
assert 'db.lua' not in toc
assert '## SavedVariablesPerCharacter: ClassicBestiaryObservedDB' in toc
assert 'GetSpellDescription' not in source
assert 'COMBAT_LOG_EVENT_UNFILTERED' not in source
assert 'Disabled: Forever marks combat aura payloads as secret' in source
book_namespace = lua.table()
lua.execute(Path(__file__).resolve().parents[1].joinpath('Journal.lua').read_text(), 'ClassicBestiary', book_namespace)
lua.execute(source, 'ClassicBestiary', book_namespace)
lua.execute(r'''
ClassicBestiaryObservedDB = nil
function UnitName() return 'Test humanoid' end
function UnitCreatureType() return 'Humanoid' end
function UnitLevel() return 9 end
frames[5].handler(frames[5], 'ADDON_LOADED', 'ClassicBestiary')
castName, castID = 'Observed trap', nil
frames[5].handler(frames[5], 'PLAYER_TARGET_CHANGED')
local entry=ClassicBestiaryObservedDB.journal.entries[42]
check(entry.category=='Humanoid' and entry.levelMin==9,'main records creature metadata')
GameTooltip.lines={}; tooltipHook(GameTooltip)
check(#GameTooltip.lines==0,'journal review gates tooltip')
entry.confirmed=true; entry.abilities['Observed trap'].state='confirmed'
ClassicBestiaryObservedDB.creatures={}
GameTooltip.lines={}; tooltipHook(GameTooltip)
check(GameTooltip.lines[2]=='Observed trap','manual journal abilities work without automatic DB')
guid='Player-1-42'; GameTooltip.lines={}; tooltipHook(GameTooltip)
check(#GameTooltip.lines==0,'journal still excludes players')
''')
print('PASS: Lua 5.1 observation, spoiler boundaries, restricted input, tooltip, journal integration, reload and reset tests')
