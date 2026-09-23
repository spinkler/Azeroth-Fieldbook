"""Encounter fixtures model Blizzard's documented direction and field names."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
ns = {}
secret = {}
function issecretvalue(v) return rawequal(v, secret) end
combat = false
function InCombatLockdown() return combat end
function UnitAffectingCombat() return combat end
Enum = {
    DamageMeterType = {DamageDone=0, HealingDone=2, DamageTaken=7, EnemyDamageTaken=10},
    DamageMeterSourceDisplayType = {None=0, Ally=1, Enemy=2}
}
function npc(id, name)
    return {sourceCreatureID=id, name=name, classFilename='', isLocalPlayer=false,
        sourceDisplayType=0, sourceGUID='Creature-0-1-2-3-'..id..'-00001'}
end
function spell(id, name, mob, pet)
    return {spellID=id, creatureName='', combatSpellDetails={unitName=name,
        unitClassFilename=mob and '' or 'MAGE', isMob=mob, isPet=pet}}
end
calls = 0
sessionID = 1
roster = {npc(42, 'Test NPC')}
incoming = {spell(101, 'Test NPC', true, false), spell(901, 'Enemy Player', false, false),
    spell(902, 'Test NPC', true, true)}
outgoing = {spell(102, '', false, false)}
healing = {spell(103, '', false, false)}
petSpell = spell(903, '', false, false)
petSpell.creatureName = 'Pet contributor'
outgoing[#outgoing+1] = petSpell
party = {sourceGUID='Player-1-1', classFilename='MAGE', isLocalPlayer=false}
function summary(mode)
    if mode == 10 then return {combatSources=roster} end
    if mode == 7 then return {combatSources={party}} end
    return {combatSources={roster[1], party}}
end
function details(mode, guid, creatureID)
    if mode == 10 then error('EnemyDamageTaken must NEVER be imported') end
    if mode == 7 then return {combatSpells=incoming} end
    if creatureID == 42 then
        return {combatSpells=mode==2 and healing or outgoing}
    end
    return {combatSpells={spell(904, '', false, false)}}
end
C_DamageMeter = {
    IsDamageMeterAvailable = function() return true end,
    GetAvailableCombatSessions = function() calls=calls+1; return {{sessionID=sessionID}} end,
    GetCombatSessionFromID = function(_, mode) calls=calls+1; return summary(mode) end,
    GetCombatSessionSourceFromID = function(_, mode, guid, creatureID)
        calls=calls+1; return details(mode, guid, creatureID)
    end
}
saved = {}
function record(creatureID, spellID)
    saved[creatureID] = saved[creatureID] or {}
    if saved[creatureID][spellID] then return false end
    saved[creatureID][spellID] = true
    return true
end
function count()
    local n=0
    for _, spells in pairs(saved) do for _ in pairs(spells) do n=n+1 end end
    return n
end
function check(v, msg) assert(v, msg) end
''')
source = Path(__file__).resolve().parents[1].joinpath('EncounterReader.lua').read_text()
lua.execute(source, 'ClassicBestiary', lua.globals().ns)
lua.execute(r'''
reader = ns.CreateEncounterReader(record)
combat = true
reader:Scan()
check(calls == 0 and count() == 0, 'no API queries during combat')
combat = secret
reader:Scan()
check(calls == 0, 'unreadable combat state fails closed')
combat = false
reader:Scan()
check(count() == 3, 'party incoming damage plus direct NPC damage/healing imported')
check(saved[42][101] and saved[42][102] and saved[42][103], 'correct spell-to-caster relationships')
check(not saved[42][901] and not saved[42][902] and not saved[42][903] and not saved[42][904], 'players and pets excluded')
reader:Scan()
check(count() == 3 and reader.status:find('0 new',1,true), 'rescanning deduplicates')
incoming = {spell(104, 'Test NPC', true, false)}
roster[#roster+1] = npc(43, 'Test NPC')
reader:Scan()
check(count() == 3 and reader.stats.ambiguous == 1, 'same name/different ID rejected')
roster[2] = npc(42, 'Test NPC')
reader:Scan()
check(count() == 4 and saved[42][104], 'multiple instances of same NPC ID accepted')
roster[2] = nil
incoming = {spell(105, 'Unknown NPC', true, false)}
reader:Scan()
check(count() == 4, 'no cross-session/global name guessing')
incoming = {spell(105, 'Test NPC', true, false)}
roster[2] = secret
reader:Scan()
check(count() == 4, 'partially unreadable roster disables name matching')
roster[2] = nil
for i=2,251 do roster[i] = npc(42, 'Test NPC') end
reader:Scan()
check(count() == 4 and reader.stats.capped > 0, 'truncated roster disables name matching')
roster = {npc(42, 'Test NPC')}
incoming[1].spellID = secret
reader:Scan()
check(count() == 4, 'secret spell ID skipped')
incoming = {spell(106, 'Test NPC', true, false)}
incoming[1].combatSpellDetails.unitName = secret
reader:Scan()
check(count() == 4, 'secret attacker name skipped')
incoming[1].combatSpellDetails.unitName = 'Test NPC'
roster[1].sourceGUID = 'Pet-0-1-2-3-42-00001'
reader:Scan()
check(count() == 4, 'pet GUID excluded even with creature ID')
roster[1] = npc(42, 'Test NPC')
roster[1].sourceGUID = 'Player-1-42'
reader:Scan()
check(count() == 4, 'player GUID excluded even with creature ID')
roster[1] = npc(42, 'Test NPC')
roster[1].classFilename = 'MAGE'
reader:Scan()
check(count() == 4, 'player-like creature excluded')
roster[1] = npc(42, 'Test NPC')
roster[1].sourceDisplayType = 1
reader:Scan()
check(count() == 4, 'friendly creature excluded')
roster[1] = npc(42, 'Test NPC')
local oldSessions = C_DamageMeter.GetAvailableCombatSessions
C_DamageMeter.GetAvailableCombatSessions = function() error('Never print this payload') end
reader:Scan()
check(count() == 4 and reader.stats.errors == 1, 'API failure diagnosed safely')
C_DamageMeter.GetAvailableCombatSessions = function() return secret end
reader:Scan()
check(count() == 4 and reader.stats.unreadable == 1, 'secret session list skipped')
C_DamageMeter.GetAvailableCombatSessions = oldSessions
local oldName = roster[1].name
roster[1].name = nil
setmetatable(roster[1], {__index=function() error('restricted table access') end})
reader:Scan()
check(count() == 4 and reader.status:find('discarded',1,true), 'unexpected table error discards scan')
setmetatable(roster[1], nil)
roster[1].name = oldName
-- Two sessions with same name: matching must stay within each session.
C_DamageMeter.GetAvailableCombatSessions = function() return {{sessionID=1},{sessionID=2}} end
C_DamageMeter.GetCombatSessionFromID = function(sid, mode)
    if mode==10 then return {combatSources={npc(sid==1 and 42 or 99,'Test NPC')}} end
    if mode==7 then return {combatSources={party}} end
    return {combatSources={}}
end
C_DamageMeter.GetCombatSessionSourceFromID = function(sid)
    return {combatSpells={spell(200+sid,'Test NPC',true,false)}}
end
reader:Scan()
check(saved[42][201] and saved[99][202] and not saved[42][202] and not saved[99][201], 'session isolation')
-- Clearing the bestiary must not immediately reimport retained old encounters.
reader:ForgetHistory()
saved = {}
reader:Scan()
check(count() == 0, 'reset excludes existing history')
C_DamageMeter.GetAvailableCombatSessions = function() return {{sessionID=3}} end
reader:Event('PLAYER_REGEN_ENABLED')
reader:Update(0.5)
check(count() == 0, 'post-combat delay')
reader:Update(0.6)
check(saved[99][203], 'new encounter after reset learned automatically')
reader:Event('DAMAGE_METER_RESET')
check(saved[99][203], 'meter reset preserves bestiary')
local lines = {}
reader:Report(function(s) lines[#lines+1]=s end)
check(#lines >= 5, 'encounter diagnostic report')
''')
print('PASS: encounter direction, party damage, NPC healing, exclusions, ambiguity, secrets, retries and reset')
