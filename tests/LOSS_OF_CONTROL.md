Current capture policy: only effects with an exact readable aura instance and verified, non-player-controlled Creature source are displayed or recorded. Unknown, restricted, player, pet and vehicle sources are ignored, including manual target fallback. Automatic spell feedback is independently opt-in. Historical observations below describe the earlier unrestricted diagnostic investigation.

# Player Loss of Control observations

## API evidence and live limits

The installed `WowB.exe` reports **1.60.1.70170** (checked read-only, 2026-10-02).
Gethe's mirror of Blizzard's Forever source at
[`9a789c074b8e73c5d604ef2d6af3bb5b3aefb348`](https://github.com/Gethe/wow-ui-source/commit/9a789c074b8e73c5d604ef2d6af3bb5b3aefb348)
is labelled `1.60.1 (70170)`. The implementation was checked against that build:

- [LossOfControlDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/9a789c074b8e73c5d604ef2d6af3bb5b3aefb348/Interface/AddOns/Blizzard_APIDocumentationGenerated/LossOfControlDocumentation.lua):
  `LOSS_OF_CONTROL_ADDED(unitTarget, effectIndex)` and
  `LOSS_OF_CONTROL_UPDATE(unitTarget)`; player getters take `index` and no
  arguments, respectively. The structure includes the requested type, ID,
  display, timing, school and optional `auraInstanceID` fields. Only priority
  and displayType explicitly promise NeverSecret. The ByUnit getter carries a
  restriction annotation; this observer uses the player-only getters.
- [UnitAuraDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/9a789c074b8e73c5d604ef2d6af3bb5b3aefb348/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua):
  `GetAuraDataByAuraInstanceID(unit, auraInstanceID)` requires unit-aura access
  and can return restricted information. `UNIT_AURA` payloads are also subject
  to aura restrictions. Accessible additions are useful evidence, not a bypass.

These declarations establish signatures, not live combat access. The addon
checks capabilities and guards calls, containers and fields. Secret spell IDs
are neither persisted nor converted into text by this observer. A readable LOC
spell survives missing/denied/secret aura access as an unattributed notification.
Missing getters degrade safely; if count is unavailable, a public ADDED index
can still be queried. Older index-only ADDED and payload-free UPDATE shapes are
accepted via the same player getters. No combat-log or forbidden-tooltip route
is involved. Expired effects with no remaining public API evidence cannot be
reconstructed. The operator's live test on 2026-10-02 confirmed the independent
LOC row displays Disarm **6713**, type **DISARM**, aura instance **27**. Exact aura
access failed with an API error, so the record correctly remained unattributed;
ADDED=1, UPDATE=2 and player UNIT_AURA=4 were received. On 2026-10-03 the operator
confirmed that the LOC portrait interaction works well. Automatic aura-source
recording still needs live acceptance. No WoW UI was controlled.

## Architecture and exact attribution

`LossOfControl.lua` receives events from `AzerothFieldbook.lua`, including login,
world entry and combat end. It enumerates only active player LOC records; all
`locType` strings are eligible. It uses the exact matching player aura from the
current UNIT_AURA addition or an instance-ID query. Full updates query only the
active LOC instances. No ordinary harmful-aura harvesting or new polling occurs.
No aura source tokens are retained across events.

Automatic recording requires all of:

1. A public positive integer spell ID and matching public aura instance ID.
2. An accessible corresponding player aura with a public `sourceUnit`.
3. That source exists, is visible and attackable, is not player-controlled, and
   has a public Creature GUID accepted by the existing Bestiary identity path.
   Player, pet, vehicle, friendly and uncertain ownership identities fail closed.
4. The GUID remains the same through discovery and the final storage check.
   The normal `journal:Observe` path supplies the named entry, including discovery
   of an NPC never targeted. It never selects or changes a target.
5. The existing **Automatically record verified creature abilities** option is on.

Current/recent targets, nearby nameplates, other casts, timing and target-of-target
are never source evidence. A nameplate token is usable only when supplied as the
matching aura's actual source. Identity failure produces chat information for
manual entry. Turning automatic recording off preserves observation/display and
explains the disabled recording in chat. Wipe holds and startup guards apply.

The existing `BestiaryBuffs.lua` storage path deduplicates by spell ID, retains
origins/notes/effects/tooltip choices, and uses the existing chat/Event log callback.
Name-unavailable records use `Spell ID <number>` and can later be resolved through
the existing editor. No behaviour, immunity or damage trait is inferred.

The transient **Last observed spell IDs** window gets a **Loss of Control on you**
row. It uses existing font, placement, expiry, dismissal, blacklist and visibility
settings, with no [A] per the operator's clarification. The latest LOC appears even
without an attributable source. Multiple active effects are all processed for
recording/notification; this existing latest-observation window shows the latest.
Notes and its raw ID list are unchanged. Saved Bestiary abilities display the
existing cyan [A], with player-effect attribution explained in their tooltip.

## Manual target portraits

The shared capture and manual assignment methods now live in `BestiaryBuffs.lua`.
`LossOfControl.lua` and the other spell-window rows use the same guarded path;
see [SPELL_PORTRAITS.md](SPELL_PORTRAITS.md) for the extended row semantics and checks.

When an effect is first detected, a read-only snapshot uses the existing eligible
NPC identity path for `target`: public GUID, NPC ID, name and optional effective
level. No entry, ability or credit is mutated by the snapshot. Unattributed rows
show a 42px circular portrait and **Target:** name. Its tooltip explicitly says
the caster is unverified. The portrait is rendered once only while the live GUID
still matches; rendering failure or a stale token uses **?** with the captured
name. Target changes never refresh the texture or redirect assignment.

An explicit click confirms the public observed spell ID for that captured NPC,
using the existing recorder and a named `Ensure` only if the page is absent.
This works in combat and independently of the automatic-recording option. Entry
locks, startup guards, resets and deletion of a captured page block stale writes.
New confirmations use `Your note`; an existing confirmed record retains its
origin. Notes, effect annotations, tooltip choices and prior verified LOC evidence
survive. A manual click never creates `playerLossOfControl` evidence. Spell-ID
deduplication prevents duplicate abilities, even with an edited name. Unknown
spell names still use `Spell ID <number>`.

Success changes the row to **Saved:** with a green rim and a chat/Event log entry.
Repeated clicks do not repeat the action. Later verified aura evidence replaces
the unverified target action with the authoritative caster. Portraits share row
expiry, dismissal, blacklist and window visibility; right-click and Shift-click
retain the normal row/window actions. No extra polling or saved snapshot exists.

## Persistence and deduplication

The only additive saved field is `entry.abilities[name].playerLossOfControl=true`.
An existing `origin` is retained; fresh abilities use
`Automatic player Loss of Control observation`. Manual edits retaining that ID
keep the evidence; changing the ID drops it. Existing account merge and stable
content preservation carry the boolean. The backup validator accepts it; old
records remain valid with no migration or schema/version increment. Sharing
continues to send reviewable rumours, without conferring automatic evidence.

The session cache prefers aura instance identity. Without an aura it uses public
spell/type/start/duration/school fields and an occurrence ordinal for identical
simultaneous effects; decreasing timeRemaining and active-list indices are not
identities. Missing timing is allowed. Active effects stay deduplicated; after
absence they have a two-second grace period and are pruned on events. Ambiguous
identical, untimed reapplications within that grace period may be coalesced.
Caches are capped at 512 entries and never saved. Restricted scans do not establish
an effect's absence. Later exact aura evidence can upgrade a previously notified
application without issuing another fallback message.

## Automated validation

`test_loss_of_control.py` exercises the real addon event/discovery/storage path:
all 13 requested types plus an unknown type, sources differing from targets,
target switches, absent targets, source invalidation, no aura, simultaneous
effects, repeated ADDED/UPDATE/UNIT_AURA, full updates, optional timing, secret
containers/fields/identity, denied/missing APIs, reload/login, existing provenance,
account imports, backup round trips, sharing, option/wipe gates and native-widget
marker/tooltip flow. `test_spell_id_window.py` covers the new row's independent
display, lack of [A], dismissal, blacklist, expiry and hidden-window behavior.
Portrait coverage adds manual confirmation during combat, automatic recording
off, unknown spell names, target changes/capture races, forbidden identity,
existing notes and provenance, deduplication, lock/reset/delete guards, later
verified-source replacement, frozen native rendering, fallback, tooltip, row
widths, retry after a blocked assignment, and portrait cleanup.
Mocks cannot establish the client's security behavior or native rendering.

Initial validation on 2026-10-02: all 20 focused LOC test methods passed, including the
known/unknown-type and secret-field subcases. The spell-window assertions and
selected regressions also passed: automatic buffs/casts, detected-ability hints,
creature identity/discovery, observation tracking, kills, backups, account tracking,
root initialization, Notes, ability resolution, locks, models, behaviour emotes,
section tabs, text size and UI scale (20 test files including the LOC module).
All 87 TOC Lua files compile as Lua 5.1; manifest/version/bindings and diff checks
passed. The complete suite was not run. One pre-existing observation-test fixture
was corrected to inspect `Observe`, rather than a model viewer's subsequent
read-only identity query; the failure was reproduced without LOC behavior.

Portrait follow-up validation on 2026-10-02: all 26 LOC methods and spell-window
assertions passed, together with automatic buffs/casts, ability resolution,
creature identity, entry locks, backups, root initialization, text size and UI
scale (11 test files). All 87 Lua files compile; manifest/version/bindings and
diff checks pass. The complete suite was not repeated. Native portrait rendering
and combat-time clicks remain for operator testing.

## Files changed for this feature

- `LossOfControl.lua`: event-driven observer, safety gates, transient deduplication
  and bounded diagnostics.
- `AzerothFieldbook.lua`, `AzerothFieldbook.toc`: event wiring, shared identity
  validation, module loading and debug report integration.
- `BestiaryBuffs.lua`, `BestiaryJournal.lua`, `BestiaryBackups.lua`: existing
  recorder, source-checked discovery, additive provenance and backup validation.
- `SpellIDWindow.lua`, `BestiaryBook.lua`, `BestiaryPages.lua`: LOC window row,
  saved ability tag/tooltip and Help/option explanation.
- `tests/test_loss_of_control.py`, `tests/test_spell_id_window.py`,
  `tests/test_observation_tracking.py`: new coverage and the fixture correction.
- `README.md`, `CHANGELOG.md`, `tests/LOSS_OF_CONTROL.md`: behavior and validation.

Previously existing local changes were preserved. The addon version remains
0.20.1; the recommended accumulated feature release is 0.21.0-beta.1 pending
live acceptance. No commit, tag or publication was performed.

## Operator live checklist

1. `/reload`; enable the spell-ID window and leave automatic ability recording on.
   Encounter a creature that Disarms you. Confirm **Loss of Control on you** shows
   its spell ID and available name/type, with no [A] in this window.
2. Run `/fieldbook debug` during or just after the effect. Copy the LOC section:
   ADDED/UPDATE counts, `locType`, spell ID, `auraInstanceID`, aura query/addition
   result, `sourceUnit`, NPC ID and final decision. SECRET and API ERROR are
   classifications only; hidden values and error payloads are never printed.
3. With accessible source evidence, verify the correct NPC's Recorded abilities
   has exactly one ID and cyan [A]. Hover for the LOC explanation. Without it,
   expect one useful chat message and no invented NPC association. The current
   eligible target should appear as a small portrait beside the row. Hover to
   check its name and unverified-caster explanation, then click only if that
   creature caused the effect. Expect **Saved:**, a green rim and one manual
   confirmed ability in its Bestiary page, without a newly granted [A].
4. Repeat while targeting another creature, then with no target. Switching
   targets before clicking must not change the portrait or its captured creature.
   With no eligible target, expect no assignment portrait. Let the effect update repeatedly;
   expect no repeated message or record. A later application can be reported again.
5. Try a school interrupt/no-aura effect. Expect its ID in the window and one
   fallback message. Reload to check saved provenance, and verify hiding the
   window does not stop observation. Existing cast/buff rows should still work.

No temporary addon or special tracing command is needed. Diagnostics are bounded
session data in the existing copyable debug report.
