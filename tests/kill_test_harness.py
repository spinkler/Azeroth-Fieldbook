"""Minimal Lua 5.1 host for the real journal -> addon event/scan path."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime


def new_client(diagnostics=False, tracking=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(r'''
        ns, frames, messages, SlashCmdList, units, actorUnits = {}, {}, {}, {}, {}, {}
        clock = 0
        secret = setmetatable({}, {
            __tostring = function() error('secret must not be formatted') end,
            __eq = function() error('secret must not be compared') end,
            __index = function() error('secret must not be indexed') end,
        })
        function issecretvalue(v) return rawequal(v, secret) end
        function GetTime() return clock end
        function GetBuildInfo() return '1.60.1', '69977', 'Sep 23 2026', 16001 end
        function CreateFrame()
            local f = {events = {}}
            function f:RegisterEvent(event) self.events[event] = true; return true end
            function f:UnregisterAllEvents() self.events = {} end
            function f:IsEventRegistered(event) return self.events[event] == true end
            function f:SetScript(script, handler) self[script] = handler end
            frames[#frames + 1] = f
            return f
        end
        function fire(event, ...)
            for _, f in ipairs(frames) do
                if f.events[event] then f.OnEvent(f, event, ...) end
            end
        end
        function tick()
            clock = clock + 0.2
            for _, f in ipairs(frames) do if f.OnUpdate then f.OnUpdate(f, 0.2) end end
        end
        DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) messages[#messages+1] = m end}
        function spawn(suffix, dead)
            return {guid='Creature-0-1-2-3-42-'..suffix, name='Test creature',
                level=5, dead=dead, denied=false, combat=false, attackable=true}
        end
        function UnitGUID(unit)
            if unit == 'player' then return 'Player-1-1' end
            if actorUnits[unit] then return actorUnits[unit] end
            return units[unit] and units[unit].guid
        end
        function UnitExists(unit) return units[unit] ~= nil end
        function UnitIsVisible(unit) return units[unit] ~= nil end
        function UnitCanAttack(_, unit) return units[unit] and units[unit].attackable end
        function UnitPlayerControlled(unit) return units[unit] and units[unit].controlled or false end
        function UnitIsDead(unit) return units[unit] and units[unit].dead end
        function UnitName(unit) return units[unit] and units[unit].name end
        function UnitLevel(unit) return units[unit] and units[unit].level end
        function UnitCreatureType() return 'Beast' end
        function GetRealZoneText() return 'Test zone' end
        function UnitIsUnit(a, b) return units[a] ~= nil and units[a] == units[b] end
        function UnitIsTapDenied(unit) return units[unit] and units[unit].denied end
        function UnitAffectingCombat(unit) return units[unit] and units[unit].combat end
        function UnitHealth() return secret end
        function UnitXP() error('XP is not kill-credit evidence') end
        function CanLootUnit() error('loot is not required for a kill') end
        function beginKill(suffix)
            units.target=spawn(suffix, false)
            fire('PLAYER_TARGET_CHANGED')
            units.target.combat=true
            return units.target.guid
        end
        function finishKill(attacker)
            local guid=units.target.guid
            fire('PARTY_KILL', attacker or UnitGUID('player'), guid)
            units.target.dead=true; units.target.combat=false
            fire('UNIT_DIED', guid)
            tick()
            return guid
        end
        function kills() return AzerothFieldbookDB.bestiary.entries[42].kills end
        function points() return AzerothFieldbookDB.bestiary.points.earned end
        function output() return table.concat(messages, '\n') end
    ''')
    lua.execute(ROOT.joinpath('BestiaryJournal.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    if tracking:
        lua.execute(ROOT.joinpath('Tracking.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    if diagnostics:
        lua.execute(ROOT.joinpath('DebugReport.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
        lua.execute('ns.ShowDebugReport = function(text) copiedReport = text end')
    lua.execute(ROOT.joinpath('AzerothFieldbook.lua').read_text(encoding='utf-8'), 'AzerothFieldbook', lua.globals().ns)
    lua.execute("fire('ADDON_LOADED', 'AzerothFieldbook')")
    return lua
