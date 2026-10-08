# Bestiary profile animations

The existing PlayerModel gains a small local playback controller. It reads only
the current entry's checked Melee/Ranged/Caster behaviours and offensive schools;
it does not infer or write creature knowledge. Only personally encountered,
verified, visible models animate. Unknown/unsupported actions remain idle.

First action: 2–4 seconds. Subsequent idle gaps: 4–8 seconds, following a short
attack or a 1–1.8 second preparation and 1.4 second release. Native sequence
lengths vary; these are presentation timings, not measured asset durations.
Consecutive action IDs and schools differ when alternatives are available.
Rotation cancels playback and postpones the next action. Hiding, clearing,
revalidating or replacing the model resets playback and capability caches.
No timers, extra model frames, database writes or spell casts are created.

## Visual provenance and limits

API signatures were checked against the Classic beta generated documentation:
https://raw.githubusercontent.com/Gethe/wow-ui-source/classic_beta/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICharacterModelBaseDocumentation.lua

Hand kits were traced through Spell.dbc → SpellVisual.dbc (CastKit) →
SpellVisualKit.dbc → SpellVisualEffectName.dbc in the public 3.3.5 data on
2026-10-08: https://github.com/Torrer/TrinityCore-3.3.5-data/tree/master/dbc
This establishes asset intent, not Forever-native rendering compatibility.

| School | Reference spell | Cast kit | Hand effect |
| --- | ---: | ---: | --- |
| Arcane | 30451 | 730 | Magic_Cast_Hand |
| Fire | 133 | 38 | Fire_Cast_Hand |
| Frost | 116 | 202 | Ice_Precast_Low_Hand |
| Holy | 585 | 119 | Holy_Precast_Low_Hand |
| Nature | 5176 | 3291 | wrath_precast_hand |
| Shadow | 686 | 118 | Shadow_Precast_Low_Hand |

Every selected kit requests directed cast animation 53. They are applied only
when that animation is supported, with oneShot=true, once at release. Unsupported
directed casts can use another supported cast motion without effects. No looping
precast kits, target impacts, area explosions or projectiles are applied.
HasAnimation verifies movements; there is no equivalent kit/attachment support
query here. pcall catches API failures, not silently missing visual assets.
Unavailable methods or rejected kits leave the ordinary animation working.
Some kits may include native sound; actual sound and attachment behaviour require
client inspection. One-shot effects expire natively; Reset restores idle but
does not purport to synchronously remove an already emitted particle.

## Validation

Run `python -B -X utf8 tests/test_bestiary_animations.py` for Lua 5.1/TOC
validation and focused playback tests. Also run `tests/test_bestiary_models.py`
for existing model-loading and portrait regressions.

2026-10-08: six new playback tests and eight existing model tests passed, along
with compilation of all 95 Lua files, TOC/bindings/version validation and
`git diff --check`. Used the bundled Python 3.12 runtime, matching the existing
`.codex-test-deps` Lupa 2.8 binaries; system Python 3.10 cannot load those wheels.

Native acceptance remains pending:

- Mark a humanoid Melee, then Ranged; confirm only supported attacks play and
  return to idle without changing the camera or leaving a frozen pose.
- Mark a caster with each of the six offense schools. Check the hand effects,
  sound, preparation/release timing and particle expiry on the Forever client.
- Check a non-humanoid caster and a rig lacking casting or ranged animations.
- Select several styles/schools and watch variation over a minute.
- Change profiles, rotate, switch creatures during preparation/release, close
  the book and change sections. Verify clean idle/restart and no outgoing effect
  on the next creature. Check reopening and slow model loads.
- Verify no animation or appearance is exposed for an unencountered report.
