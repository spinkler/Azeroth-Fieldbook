# Spell-window creature portraits

The LOC portrait was accepted by the operator on 2026-10-03. This follow-up
extends that interaction to every other row without new polling or saved fields.

| Row | Captured creature |
| --- | --- |
| Enemy cast / channel / instant | The casting target |
| Buff on target | The buff recipient; a readable caster name remains in the tooltip |
| Debuff on you | Its eligible NPC source, otherwise the target explicitly marked unverified |
| Unattributed player LOC | The target at first detection, unchanged |

`BestiaryBuffs.lua` owns `CaptureSpellAssignment` and `AssignObservedAbility`.
Capture uses the existing Bestiary identity callback and public GUID/name/level
checks. Capturing does not discover a creature or save an ability. The spell ID
is retained for assignment only when public and valid. Cast/aura rows can still
relay secret IDs to native text and show a public NPC portrait; their tooltip and
click explain that the displayed ID needs manual entry. Nothing reads UI text
back or attempts to convert secret IDs.

`AzerothFieldbook.lua` binds the capture callback before initializing the window,
with the existing startup and wipe holds. `SpellIDWindow.lua` snapshots target
identity before aura/cast reads, then rejects a candidate if that GUID changes.
Portrait rendering checks the captured token/GUID before and after the native
call; no later target event refreshes historical textures. Each row owns its
candidate and action, so simultaneous rows can refer to different NPCs.

Clicks use captured IDs, work in combat with automatic recording off, respect
entry locks, and fail after the captured page is deleted or storage is reset.
The wipe hold also applies to snapshots created during window reinitialization.
Spell-ID deduplication preserves existing notes, effects, tooltip choices and
confirmed origins. New manual records use `Your note` and an Event log kind of
`manual cast`, `manual buff`, `manual debuff` or `manual Loss of Control`; they
never acquire automatic LOC evidence just from the click. Successful buttons
show **Saved:** with a green rim. Existing dismissal, blacklist, expiry and
window visibility apply to all portraits.

Ctrl+Click routes the captured creature ID to the Bestiary section through its
normal shell navigation, without assigning an ability. It works after saving,
on locked entries and with restricted spell IDs. A missing page can be opened
from the captured public identity; deleted/reset snapshots still fail closed.
The tooltip advertises the shortcut on both saved and unsaved portraits.

## Validation — 2026-10-03

`test_spell_portraits.py` exercises the real root binding and journal through
six test methods with per-kind/identity/reset subcases: independent recipients
and sources, target switches, combat, disabled automation, restricted IDs,
unavailable identity, lock/delete/reset/startup/wipe guards and duplicate clicks.
`test_spell_id_window.py` covers all four added row routes, channels, simultaneous
portraits, source/recipient distinction, native rendering snapshots, restricted
tooltip values, target races, dismissal and cleanup. Existing LOC tests verify
the shared path retains notes and provenance and still upgrades exact sources.

Ten focused test files passed: portraits, spell window, LOC, automatic buffs,
automatic casts, auto-lock, ability resolution, root initialization, text size
and UI scale. All 87 TOC Lua files compiled with manifest/version/bindings checks.
The full suite was not rerun. The other rows need an operator live check:

1. `/reload`; observe an enemy cast, instant cast, channel and target buff.
2. Hover each portrait and confirm its captured name/context. Switch targets
   before clicking and confirm the ability goes to the originally shown creature.
3. Check a buff from another caster: portrait/assignment should use the recipient,
   with the readable caster retained in the tooltip. Check a player debuff with
   and without an accessible eligible source.
4. A readable spell ID should save once and turn the rim green; a restricted ID
   should remain visible and explain manual entry without saving it.

Version remains 0.21.0 (Release). Recommended next feature version:
0.22.0-beta.1 (Beta), pending live acceptance of the expanded manual-assignment UI.
No commit or publication was requested.

Ctrl+Click follow-up: the portrait, window, LOC and root-initialization checks
passed again, along with all 87 Lua compilation checks. Coverage includes all
five row buttons, saved and restricted-ID rows, locked-page navigation and
opening the captured identity after retargeting without assigning a spell.
