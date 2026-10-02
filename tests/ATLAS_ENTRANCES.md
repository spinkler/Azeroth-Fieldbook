# Interior entrance discovery â€” 0.20.1 (unreleased)

## Preservation boundary

`AtlasSubzones.lua` owns survey recording, spacing, compaction, geometry, colours,
manual points and the native-map overlay. Its `Attach`, `Observe`, `Track`,
`Reset`, `Flush` and storage semantics must remain unchanged. Entrance automation
must not call those capture methods or share their observer, timers or state.
Both observers receive Blizzard events independently. Subzone names are read-only
evidence for entrances. Existing `records`, expeditions and report projections
remain deliberate-record data; entrance observations have a separate store.

The map follows `journal.state.mapID/zone/continent/selected`. The unsupported
Micro display override has been removed. Interior map IDs remain evidence only.

## Architecture and policy

- `AtlasEnvironment.lua`: guarded map ancestry, environmental signals and
  explicitly scoped coordinates. Zone and Micro positions are queried separately.
- `AtlasEntranceTypes.lua`: English whole-token suggestions constrained to the
  existing category registry. Micro is structural identity, never a Cave claim.
- `AtlasEntrances.lua`: versioned, bounded evidence store, clustering, detached
  presentation adapter and player edits. Legacy records/reports are untouched.
- `AtlasEntranceTracking.lua`: independent transition state machine and event
  adapter. Coalesced transition verification plus a movement-only one-second
  sampler provide fresh exterior evidence without a new OnUpdate handler.
  `AtlasMap.lua` continues to render art through the existing tile pool.

Automatic recording and Generic Entrances visibility default off independently.
Entrances follow the Atlas's selected account/character store. Whole-Fieldbook
backups retain the extension; legacy reports continue to contain deliberate
records only. Account imports retain independent evidence and collision-safe IDs.

Permanent positions are `{mapID,x,y}` in the existing 0â€“10000 integer convention,
under `exterior`; optional `interiorPosition` has its own map ID. Optional world
positions include a continent ID and conversion provenance. A fixed first exterior
point anchors clustering and the marker; later observations never drag it around.
Player edits may change the displayed zone position without moving that anchor.

Clustering uses world distance only after checked conversion/round-trip results,
otherwise actual map width and height in yards. Without either metric, recording
is skipped. Same-interior observations within 35 yards merge; uncertain identity
uses a tighter 12 yards. Conflicting Micro identities do not merge. Distances are
always measured from the fixed anchor, preventing chains from swallowing distant
entrances to one interior. These policy constants are executable test inputs.

Transitions need 0.35 seconds of stable state, fresh same-zone continuity and
at least 0.5 yards of displacement. A sample gap above 2.5 seconds resets the
baseline. Each step must fit a 24 yards/second allowance plus 6 yards of sampling
slop, capped at 60 yards. After an accepted crossing the detector must observe an
8-yard excursion before accepting another; a 3-second minimum further limits
chatter. These are conservative observation policies, not movement-speed claims.

Login, toggle changes, unavailable state, loads, transfers, death, flight, control
loss and player spellcasts reset continuity. Death latches until a life event;
ghost movement and spirit release are blocked, and resurrection starts a fresh
baseline. Pending/accepted summons block capture, even within one zone without a
loading screen. Summon events reset continuity and impose a 3-second arrival
settle; clients without readable summon APIs get a 120-second request quarantine,
reset by cancellation or world transfer. Another party member's summon event is
ignored. Cast guards deliberately favour missing an observation over recording
a hearth/teleport as an entrance. Recording is also skipped inside instances.

The adapter registers its own frame and never consumes another observer's events.
There is no entrance OnUpdate handler. Recording off queues no entrance sampling
timers; environmental context can still follow map events. A moving, enabled player gets
one sample per second, stopped on movement end, loading, death or disabling.
Generation checks invalidate pending callbacks after a reset.

## Evidence, classification and presentation

The root Atlas schema stays at 1. The additive `entrances` object has its own
schema 1, record table and ID allocator, capped at 5,000 observations. Each record
retains the fixed exterior anchor, optional independently scoped Micro/world
positions, first/latest timestamps, entry/exit/total counts, structural interior
identity, latest crossing provenance, notes and classification provenance.
Evidence is `candidate`, `repeated` or `corroborated`; no confidence percentage is
manufactured. Malformed entries are retained but excluded from presentation;
unknown extension schemas stay untouched and defer account import.

English whole-word keywords suggest only existing Cave / Entrance, Route /
Passage or Ruins categories. For example, Mine uses the existing Cave / Entrance
category; Crypt and Tomb remain Generic because there is no corresponding type.
Unsupported locales remain Generic. Category provenance is `none`, `inferred`
or `player`. The existing editor and category picker show inferred checks in grey.
Explicitly choosing a category, including the same suggested category, then
saving records player authority and the normal gold check. Saving notes alone
does not confirm a suggestion. Later observations cannot replace a player choice.

Generic observations use the independently hidden-by-default Generic Entrances
layer. Typed observations use the existing matching layer. Neither filter changes
recording. The normal index still includes hidden entries. The presentation
adapter combines entrance observations with deliberate entries only for the
Atlas index, map and editor; established report, route and reference contracts
continue to operate on deliberate records.

Each newly saved entrance emits one chat notice and one shared Event log entry,
including while Atlas is closed or Generic Entrances is hidden. Repeated
traversals, edits, reloads and failed/disabled recording emit no new-entry notice.
The index, index/map tooltips, editor provenance and announcement show the
Bestiary's cyan `[A]` suffix (`80d0ff`). This denotes automatic origin, independently
of grey/gold category confirmation, and is never appended to the saved name.
Existing saved observations gain the display tag without replaying old notices.

## Changed files

- New runtime modules: `AtlasEnvironment.lua`, `AtlasEntranceTypes.lua`,
  `AtlasEntrances.lua`, `AtlasEntranceTracking.lua`.
- Integration: `AtlasJournal.lua` attaches the extension; `AccountSections.lua`
  imports it safely; `AtlasBook.lua`, `AtlasEditors.lua`, `AtlasMap.lua` and
  `AtlasUI.lua` present its controls, evidence and classification.
- Version/docs: `AzerothFieldbook.toc`, `README.md` and `CHANGELOG.md` carry
  0.20.1; the TOC loads the new modules; `tests/ARCHITECTURE.md` describes the
  independent observers.
- Tests: new `tests/test_atlas_entrances.py`; harness module loading and the
  existing Atlas layer-menu assertion include the additive Generic layer.
- Announcement/tag follow-up: shared display helper in `AtlasJournal.lua`;
  `LoreJournal.lua`, `LoreBook.lua` and `LoreIntegration.lua` use local capture
  origin for matching Lore tags. `tests/test_lore_ui.py` and
  `tests/test_fieldbook_tabs.py` cover Lore display and background announcements.
- Preservation review: no changes to `AtlasSubzones.lua`, `AtlasReports.lua`,
  `AtlasReportUI.lua` or `CreatureLocations.lua`.

## API evidence and live validation

The repository's target-client source reference documents the map APIs and their
return order: [MapDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua).
This is API-contract evidence, not live verification of Forever map data. Optional
summon contracts were also checked against
[IncomingSummonDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/IncomingSummonDocumentation.lua)
and [SummonInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SummonInfoDocumentation.lua).
Those live-branch definitions do not establish Forever availability; each API is
feature-detected, with guarded legacy fallback. Missing, throwing, secret,
contradictory and out-of-range results fail closed.

Some valid interiors may not supply a usable position on their canonical parent
zone. Those crossings are skipped: Micro coordinates never substitute for a
missing zone position. Likewise, missing reliable distance metrics skip capture.
Thresholds may need tuning against actual wide mouths and closely spaced distinct
doors. World conversion scale, map hierarchy, art availability, death/summon event
ordering and native layout/colours require live-client checks.

## Automated validation â€” 2026-10-02

Commands use the repository's Python/Lupa Lua 5.1 runner:

```text
python -B -X utf8 tests/test_atlas_entrances.py
python -B -X utf8 tests/test_atlas.py
python -B -X utf8 tests/test_atlas_subzones.py
python -B -X utf8 tests/run_tests.py
```

- Regression cases compare identical subzone event/movement streams with no
  entrance observer, with recording off and with recording on. They compare saved
  samples, previous capture state, revisions and notifications.
- Coverage also includes canonical-zone vs Micro coordinates, guarded world
  conversions, clustering and stable anchors, chatter, loading/teleports/casts,
  pending/accepted/cancelled summons, spirit release/resurrection, classification
  reloads and actual editor checks, filtering, account migration, whole-Fieldbook
  backup round-trips and disabled timer lifetime. Additional checks exercise
  one-time background chat/log notices and cyan tags after edits and reloads.

## Live Forever checklist â€” not yet performed

Use a disposable test profile or an existing whole-Fieldbook backup. Record the
client build and each location's zone/Micro IDs; note unavailable APIs explicitly.

1. **Outdoor baseline:** open Atlas in an ordinary outdoor area. Both new defaults
   are off, ordinary layers retain their settings, and there is no Micro display button. Enable recording; no candidate appears until a crossing.
2. **Building and no-Micro interior:** walk through a building/inn doorway and an
   indoor area without a Micro map. If map data is usable, expect Generic evidence,
   not an automatic Cave claim. Verify the saved position belongs to the exterior
   zone, including while browsing a different Atlas zone.
3. **Cave/mine with Micro:** enter naturally. Verify the exterior pin and interior
   map identity, one entry count, and an appropriate grey suggested type only when
   the localized name matches the configured vocabulary.
4. **Repeat and wide mouths:** move at least 8 yards beyond the threshold, then
   return after 3 seconds; repeat across left, centre and right parts of a wide
   mouth. Expect one stable pin with entry/exit corroboration. Stand on the boundary
   and shuffle slightly; transient indoor/outdoor chatter must not spam counts.
5. **Two entrances:** traverse physically distant entrances into the same interior.
   Expect separate pins. Also inspect nearby distinct doors and very wide mouths
   to evaluate the documented 35-yard/12-yard policy against actual geometry.
6. **Classification and reload:** save notes on a suggestion and confirm it stays
   grey. Explicitly select that category, Save and /reload; it becomes gold. Select
   another existing category and repeat traversal; the player's choice persists.
7. **Recording vs filtering:** keep Generic Entrances hidden while crossing an
   unmatched doorway, then reveal it. Toggle recording off; existing pins remain
   filterable and further crossings do not add evidence. Check typed entrances
   obey their existing category layers. Verify each new entrance announces once
   with cyan `[A]`, including while Atlas is closed. Check the tag on index rows,
   tooltips and editor provenance before/after confirming a category and reloading.
8. **Subzone preservation:** compare a known survey route with recording off/on,
   the Atlas closed/open. Check automatic samples, manual
   survey-point binding, colours, points, labels, fill, cleanup setting and native
   World Map layers. Entrance recording must not turn automatic survey mapping on.
9. **Login and transfers:** log in and /reload indoors; no entry is synthesized.
    Test hearth, teleport, loading screen, continent/zone transfer, instance entry,
    taxi and flight. No crossing may bridge the interruption; later ordinary
    walking should resume observation after a fresh baseline.
10. **Summons:** test accepted same-zone and cross-zone summons, plus cancellation,
    decline and expiry. Neither origin nor arrival should create doorway evidence,
    including a close indoor destination without a loading screen. After settling,
    genuine walking crossings should work. Check another party member's summon
    does not interrupt the player's valid crossing.
11. **Death:** die near a doorway, release spirit, cross boundaries as a ghost, then
    resurrect at the corpse and with a spirit healer. No death/release/resurrection
    creates entrance evidence; a later living traversal starts from fresh state.
12. **Storage:** /reload in both account and character tracking modes, inspect the
    correct retained observations/preferences, and restore a whole-Fieldbook test
    backup. Existing deliberate records and report previews remain unchanged.

These automated checks verify code paths and synthetic API contracts. No
Forever-specific runtime behaviour or native visual result is claimed verified
until the live checklist is performed. No push, tag or publication is part of
this change.
