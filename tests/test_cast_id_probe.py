"""Control-flow tests only: Lua mocks cannot reproduce WoW's secret-value engine."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / '.codex-test-deps'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
SlashCmdList = {}
ns = {}
UIParent = {}
TargetFrame = {spellbar = {}}
frames, messages, timers = {}, {}, {}
secret = setmetatable({}, {
    __tostring = function() error('secret stringification') end,
    __concat = function() error('secret concatenation') end,
})
function issecretvalue(v) return rawequal(v, secret) end
function print(s) messages[#messages+1] = s end
function InCombatLockdown() return combat end
function UnitExists(u) assert(u == 'target'); return exists end
function UnitIsEnemy(a, b) assert(a == 'player' and b == 'target'); return enemy end
function UnitPlayerControlled(u) assert(u == 'target'); return controlled end
function UnitIsUnit(u, target) assert(target == 'target'); return u == 'targetalias' end
function UnitCastingInfo(u)
    assert(u == 'target')
    if apiFail then error('not logged') end
    if casting then return secret, secret, secret, secret, secret, false, secret, secret, id, 71 end
end
function UnitChannelInfo(u)
    assert(u == 'target')
    if channeling then return secret, secret, secret, secret, secret, false, secret, id, false, 0, 72 end
end
now = 0
C_Timer = {After = function(delay, f) timers[#timers+1] = {at=now+delay, callback=f} end}
local methods = {}
function methods:SetScript(_, f) self.handler = f end
function methods:EnableMouse() end
function methods:RegisterEvent() end
function methods:RegisterUnitEvent(_, u) assert(u == 'target') end
function methods:UnregisterAllEvents() end
function methods:SetSize() end
function methods:SetFrameStrata() end
function methods:SetPoint(...) self.anchor = {...} end
function methods:SetJustifyH() end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:SetText(v)
    if reject and issecretvalue(v) then error('secret rejected') end
    self.text = v
end
function methods:GetText() error('probe must not read back text') end
function methods:CreateFontString()
    local s = setmetatable({}, {__index=methods})
    self.strings = self.strings or {}
    table.insert(self.strings, s)
    return s
end
function CreateFrame()
    local f = setmetatable({}, {__index=methods})
    frames[#frames+1] = f
    return f
end
function fire(event, unit, ...) frames[1].handler(frames[1], event, unit, ...) end
function advance(seconds)
    now = now + seconds
    local pending = timers; timers = {}
    for _, timer in ipairs(pending) do
        if timer.at <= now then timer.callback() else timers[#timers+1] = timer end
    end
end
function flush() advance(0) end
exists, enemy, controlled = true, true, false
''')
lua.execute((Path(__file__).resolve().parents[1] / 'TargetCastIDs.lua').read_text(), 'AzerothFieldbook', lua.globals().ns)
lua.execute(r'''
assert(#frames == 1) -- Disabled: no visual created.
db = {}
ns.CastIDs:Initialize(db)
assert(db.displayCastIDs == true)
local panel = frames[2]
assert(not panel.shown)
assert(panel.anchor[1] == 'BOTTOM' and panel.anchor[3] == 'TOP')
casting, id = true, secret
fire('UNIT_SPELLCAST_START', 'target')
assert(panel.shown and rawequal(panel.strings[2].text, secret))
assert(not panel.strings[3].shown) -- Quiet by default.
ns.CastIDs:SetDebug(true)
assert(panel.strings[3].text == 'cast secret: SetText accepted')
casting, channeling = false, true
fire('UNIT_SPELLCAST_CHANNEL_START', 'target')
assert(rawequal(panel.strings[2].text, secret))
assert(panel.strings[3].text == 'channel secret: SetText accepted')
id = 12345
fire('UNIT_SPELLCAST_CHANNEL_UPDATE', 'target')
assert(panel.strings[2].text == 12345)
ns.CastIDs:Report(print)
assert(table.concat(messages, '\n'):find('public API ID=12345', 1, true))
id, reject = secret, true
fire('UNIT_SPELLCAST_CHANNEL_UPDATE', 'target')
assert(panel.strings[3].text == 'channel secret: SetText rejected')
assert(panel.strings[2].text == '')
reject, id = false, nil
fire('UNIT_SPELLCAST_CHANNEL_UPDATE', 'target')
assert(panel.strings[3].text == 'channel: ID absent')
channeling = false
fire('UNIT_SPELLCAST_CHANNEL_STOP', 'target')
assert(not panel.shown)
flush()
casting, id = true, secret
fire('UNIT_SPELLCAST_START', 'target')
exists = false
fire('PLAYER_TARGET_CHANGED')
assert(not panel.shown)
exists, controlled = true, true
fire('PLAYER_TARGET_CHANGED')
assert(not panel.shown)
controlled, enemy = false, false
fire('PLAYER_TARGET_CHANGED')
assert(not panel.shown)
enemy = true
for i=1,3 do
    casting = true
    fire('UNIT_SPELLCAST_START', 'target')
    assert(panel.shown)
    casting = false
    fire('UNIT_SPELLCAST_INTERRUPTED', 'target')
    assert(panel.shown)
    flush()
    advance(59)
    assert(panel.shown)
    fire('UNIT_SPELLCAST_STOP', 'target') -- Duplicate stop must not restart timeout.
    flush()
    advance(1)
    assert(not panel.shown)
end
casting = true
fire('UNIT_SPELLCAST_START', 'target')
casting = false
fire('UNIT_SPELLCAST_STOP', 'target')
flush()
advance(30)
casting, id = true, 45678
fire('UNIT_SPELLCAST_START', 'target')
advance(30) -- Old timer must not hide the new cast.
assert(panel.shown and panel.strings[2].text == 45678)
casting = false
fire('UNIT_SPELLCAST_STOP', 'target')
flush()
panel.handler(panel, 'RightButton')
assert(not panel.shown)
fire('PLAYER_REGEN_ENABLED')
assert(not panel.shown)
casting, id = true, secret
fire('UNIT_SPELLCAST_START', 'target')
assert(panel.shown)
casting = false
fire('UNIT_SPELLCAST_STOP', 'target')
fire('PLAYER_TARGET_CHANGED')
assert(not panel.shown)
flush()
advance(60)
assert(not panel.shown)
casting = true
fire('UNIT_SPELLCAST_START', 'focus')
assert(not panel.shown)
apiFail = true
fire('UNIT_SPELLCAST_START', 'target')
ns.CastIDs:Report(print)
assert(table.concat(messages, '\n'):find('UnitCastingInfo API call failed', 1, true))
ns.CastIDs:SetEnabled(false)
assert(not panel.shown)
assert(db.displayCastIDs == false)
ns.CastIDs:Initialize(db)
fire('PLAYER_LOGIN')
assert(not panel.shown and db.displayCastIDs == false)
apiFail = false
ns.CastIDs:SetDebug(false)
ns.CastIDs:SetEnabled(true)
assert(panel.shown and not panel.strings[3].shown)
reject = true
fire('UNIT_SPELLCAST_START', 'target')
assert(not panel.shown) -- No bare label or errors outside debug mode.
reject, casting, channeling = false, false, false
apiFail = true -- Instant success must not depend on casting-info APIs.
fire('UNIT_SPELLCAST_SUCCEEDED', 'target', secret, secret, 100)
assert(panel.shown and rawequal(panel.strings[2].text, secret))
ns.CastIDs:Report(print)
assert(table.concat(messages, '\n'):find('succeeded event secret: SetText accepted', 1, true))
advance(30)
fire('UNIT_SPELLCAST_SUCCEEDED', 'focus', secret, 111, 101)
assert(rawequal(panel.strings[2].text, secret))
fire('UNIT_SPELLCAST_SUCCEEDED', 'target', secret, 222, 102)
assert(panel.strings[2].text == 222)
advance(30)
assert(panel.shown) -- Previous instant's timeout cannot hide the newer one.
advance(30)
assert(not panel.shown)
fire('UNIT_SPELLCAST_SUCCEEDED', 'target', secret, secret, nil)
assert(panel.shown)
panel.handler(panel, 'RightButton')
assert(not panel.shown)
fire('UNIT_SPELLCAST_SUCCEEDED', 'target', secret, secret, nil)
assert(panel.shown) -- A subsequent instant can appear after dismissal.
exists = false
fire('PLAYER_TARGET_CHANGED')
assert(not panel.shown)
exists, controlled = true, true
fire('UNIT_SPELLCAST_SUCCEEDED', 'target', secret, secret, 103)
assert(not panel.shown)
controlled, apiFail, channeling, id = false, false, true, secret
fire('UNIT_SPELLCAST_CHANNEL_START', 'target')
fire('UNIT_SPELLCAST_SUCCEEDED', 'target', secret, secret, 72)
assert(panel.shown)
advance(61)
assert(panel.shown) -- Channel success must not start its after-cast timer.
channeling = false
fire('UNIT_SPELLCAST_CHANNEL_STOP', 'target')
flush()
advance(60)
assert(not panel.shown)
-- A public alias of the current target is eligible, without scanning other units.
fire('UNIT_SPELLCAST_SUCCEEDED', 'targetalias', secret, secret, 200)
assert(panel.shown and rawequal(panel.strings[2].text, secret))
ns.CastIDs:SetDebug(true)
local traceFrame = frames[3]
traceFrame.handler(traceFrame, 'UNIT_SPELLCAST_SUCCEEDED', 'targetalias', secret, secret, 200)
traceFrame.handler(traceFrame, 'UNIT_SPELLCAST_SENT', 'target', secret, secret, 333)
traceFrame.handler(traceFrame, 'UNIT_SPELLCAST_SUCCEEDED', 'focus', secret, 444, 201)
ns.CastIDs:Report(print)
local report = table.concat(messages, '\n')
assert(report:find('success events received=2; matched to target=1; sent events received=1', 1, true))
assert(report:find('target alias', 1, true))
assert(report:find('UNIT_SPELLCAST_SENT', 1, true) and report:find('public numeric ID', 1, true))
assert(not report:find('333', 1, true))
assert(not report:find('444', 1, true))
''')
print('Cast ID probe control-flow checks passed (not a WoW secrecy/rendering test).')
