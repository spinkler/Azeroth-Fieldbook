# Angler’s Almanac — v0.13.0 implementation and validation

This is a personal, discovery-led fishing journal. There is no bundled catch,
spawn, requirement or fishing-location database. No in-game testing has been
performed for this change. Synthetic Lua/widget checks do not establish native
rendering or the actual order/readability of events during live fishing.

## Scope and ownership

| File | Responsibility |
| --- | --- |
| `AnglingJournal.lua` | Character schema, identities, observations, durable aggregates, bounded history, queries and spot correction |
| `AnglingTracking.lua` | Event-only fishing capture, readable skill snapshots, expiring source assignments and manual fallback |
| `AnglingReports.lua` | Selected reports, literal codec, validation, preview tickets, atomic acceptance, deduplication and forwarding |
| `AnglingMap.lua` | Local data adapter to the exposed Atlas map renderer, fishing pin labels and selection |
| `AnglingEventLog.lua` | Section-owned event page, live refresh, newest-first pagination and confirmed clearing |
| `AnglingBook.lua` | Existing `angling` tab, three browse views, filters, notes, controls and report UI |
| `tests/angling_test_harness.py`, `tests/test_angling.py` | Synthetic data, client-event and real widget-builder tests |

Integration is one initialization call in `AzerothFieldbook.lua`, six load
entries and one per-character SavedVariable in the TOC, and removal of only the
Angling wishlist definition from `FieldbookSections.lua`. The original vision
is retained in Almanac Help. Tab order, default section, shell dimensions and
global appearance are unchanged. Other pages' implementation files are not edited.
The existing navigation test loads the new section and continues checking the
remaining wishlist pages and Bestiary state. Documentation/version references
advance to the operator-designated **0.13.0** milestone, unreleased.

## Event log

The Almanac also owns a separate persisted `eventLog`, retained until cleared,
with 50 events per page. Logging operates before the UI is built. Cumulative
catch tokens update one row, repeated hover sightings stay silent, and private
note contents are omitted. Clearing removes only log rows, not catch history,
notes or source assignments. Reports exclude the log; old history is not backfilled.
The existing shell title-bar button routes to the Almanac page while this section
is selected. Bestiary’s log remains independent.
An in-memory key index references existing rows for cumulative updates without
scanning the full history. Clearing releases that index. Only 50 rows are rendered
at once, using reused widgets; regression checks cover 5,000 entries and garbage
collection of cleared rows. Stored history grows intentionally; UI state does not.

## Map geometry

`CreateAnglingMap` calls the already-exposed `CreateAtlasMap` factory with a
detached Almanac adapter. No Atlas journal, registration, saved data, layer
settings, map selection or opened Atlas page is needed. Reusable `AtlasUI` and
stateless Atlas value helpers likewise have no section-owned data dependency.

The actual Atlas renderer supplies its maximum fit region:

- width: `578 * 0.99 = 572.22` UI units;
- height: `302 * 1.25 * 0.99 = 373.725` UI units;
- anchor: `TOP` to the Almanac main content's `TOPLEFT`, `(632, -205)`, exactly
  the corresponding Atlas main-content anchor;
- artwork scale: `min(width / layerWidth, height / layerHeight)`, keeping the
  native aspect ratio, top alignment and horizontal centering;
- identical tile cropping, edge texcoords, explored overlays, unavailable-art
  fallback, player arrow and inherited scale. As of v0.13.1, both maps also use
  a thin, click-through border from the main window's native frame-art family,
  anchored outside the artwork bounds without changing viewport geometry.

For example, 1000×668 artwork occupies approximately 559.469×373.725 UI units
inside that reserved region. This is the Atlas policy, not a separately guessed
map size. Empty journals and the three browse modes use the same map region.
The artwork may have different intrinsic aspect ratios on different maps, as
it does in Atlas. Missing artwork uses the renderer's unchanged fallback bounds.
Almanac panels stay in the left pane and never cover or re-anchor the map.
Scroll-wheel zoom (v0.13.2) magnifies the shared clipped map canvas from 1× to
4× around the pointer, including pins, routes and player position. The map frame
and border stay fixed; switching maps resets zoom, and section instances remain
independent. Player coordinates (v0.13.3) sit eight units inside the map's
lower-left corner, above the artwork, and do not zoom with it.
The divider `(306, -53)`, `3×661`, the detail region `(342, -606)`, `555×64`,
and bottom action positions follow the existing Atlas layout.

Permanent pins are deliberate spots/sightings. Selecting waters can show one
**transient latest observed player-position marker**, labelled as such; it
creates no spot and disappears on changing the selection. Overlapping pins
cycle records. Item reverse lookup uses the selected item's latest observed
position in the chosen source context, not another item's later position.
Reported waters without such evidence do not acquire a guessed position. Pins
from reports and approximate positions are labelled; no pin claims a
pool is live or predicts a respawn. Selection and map state are Almanac-owned.

Tests instantiate the actual Atlas and Almanac builders, compare their map
dimensions/anchors at three UI scales and three artwork aspect ratios, exercise
missing artwork, and assert unchanged Atlas saved state and shell size.

## Forever capability evidence and conservative boundaries

The target is Interface 16001. The inspected Blizzard Forever source is pinned
to `bd2470aed543f72697a044e989285b6c83e63f73`, also used by the existing Atlas
capability investigation. Relevant primary client sources:

- [Forever LootFrame](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.lua)
  uses `IsFishingLoot`, `GetLootSlotLink`, `GetLootSlotInfo`, and distinguishes
  `LOOT_OPENED`'s `isFromItem` flag from fishing loot.
- [Loot event documentation](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootDocumentation.lua)
  describes READY, OPENED, SLOT_CHANGED, SLOT_CLEARED and CLOSED. READY is used
  to take the pre-autoloot snapshot, not as evidence that items were acquired.
- [Unit event documentation](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
  and the repository's installed 69977 extraction establish player unit, cast
  GUID and spell-ID signatures. SENT has the extra target-name argument.
- [SkillInfo documentation](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_APIDocumentationGenerated/SkillInfoDocumentation.lua)
  exposes `C_SkillInfo.GetSkillLineInfoByID` and named fields. This is not the
  older Classic `GetSkillLineInfo` multiple-return API.
- [Forever SkillsFrame](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_UIPanels_Game/Camelot/SkillsFrame.lua)
  displays rank and modifier. Raw `tempPoints` is not interpreted as a lure.

All optional reads are guarded and secret values are excluded. There is no
attempt to bypass restrictions. Native source establishes API shape, not a
guarantee of readable values or event order during gameplay.

Automatic capture requires `IsFishingLoot() == true` and acquired item slots.
As of v0.13.4 a missing cast GUID no longer rejects confirmed fishing loot:
readable player casts use their GUID (or a local cast token), and fishing loot
without a usable cast uses a local loot-window identity. Partial windows retain
that identity across retries. A new nonempty READY after a fully collected,
closed fallback window starts the next event. No bag deltas or loot chat are used.
Fishing spell 7620, or its readable localized name on another spell, supplies
optional pre-loot context. Cast evidence alone never classifies loot as fishing.
READY snapshots and clear events can be retained before the fishing flag arrives;
they commit only after fishing is confirmed. A bare interruption records nothing.
An interrupted channel has a two-second opportunity to receive authoritative
loot evidence. Without a cast-time skill snapshot, skill remains unknown.
From v0.13.5, UI_ERROR_MESSAGE/UI_INFO_MESSAGE match ERR_FISH_ESCAPED and
ERR_FISH_NOT_HOOKED using guarded GetGameMessageInfo names or exact localized
global strings. An explicit failure drops pending slots and ignores late window
events until a new fishing cast or fresh nonempty READY. It preserves the source
assignment and committed catches, and records no failed-cast skill requirement.
Unrelated errors (including full bags), secret text and substring matches do not
discard retry evidence. See the client
[UIErrorsFrame](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIErrorsFrame/Mainline/UIErrorsFrame.lua)
and [GameError API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GameErrorDocumentation.lua).

No supported signal was established that securely ties a caught item to a
specific physical pool. A world tooltip/mouseover or opaque loot-source GUID
is not used as that proof. Pool types and sightings therefore have a usable,
explicitly player-recorded entry path. From v0.13.4, Object tooltip post-callbacks
also inspect fresh `GetWorldCursor` data using the existing gathering observer's
guarded approach. Localized Fishing requirement text identifies pool sightings;
an English-only name fallback recognizes school, shoal, pool and wreckage endings,
Floating Debris and Patch of Elemental Water. This is tooltip-text recognition,
not a bundled source database. Other unrecognized/localized names need manual entry.
Unit/item/UI tooltips, secret text, missing zones and bobbers are skipped. One
unpositioned sighting per type/zone accumulates first/latest times, with no pin,
loot, skill requirement or session assignment inferred. Sources / spots, zone
filters, search and reports use these linked sightings. The processor API is in
[Forever TooltipDataHandler](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua),
and [TooltipInfoShared](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua)
defines the Object discriminator. A guarded SetWorldCursor post-hook supplements
the processor. From v0.13.5, native tooltips that bypass these callbacks are also
checked on show and at most five times per second while visible. Fresh cursor
data is still required; missing processing info additionally requires world-only
mouse focus. Hidden tooltips do no work, and no hidden world scan is added.

**Remove pool** hides a selected type and its automatic zone sightings, suppressing
future hover additions across reloads. **Show: removed** exposes the reversible
**Restore pool** action. Notes, catch history, reports and manually remembered
spots remain intact; assignments to removed types are cleared/rejected.
From v0.13.5, **Remove sighting** independently hides a selected pool sighting in
Waters, with **Show: removed / Restore sighting** available there. Automatic
zone sightings are suppressed per type/zone across reloads. Other zones and the
pool identity survive. Removed sightings are excluded from pins, location links,
and outgoing reports; catch facts tied to an incorrect sighting stay in local
history but are omitted from reports until it is restored, preserving forwarded
provenance rather than rewriting the source claim. Historical reverse lookup
uses the waters when the specific sighting has been removed.

Recorded catches and the Catches index use C_Item.GetItemIconByID (or the
legacy GetItemIcon), with observed loot icons and a question mark as fallbacks.
Readable item IDs open native item tooltips; uncached/name-only items show text
instead. Item-info events refresh icons and names without adding observations
or treating an imported item as personally observed.
**Assign selected pool** records a
player's source assertion. **Assign open water** is likewise an assertion;
failure to find a pool always stays **Unclassified water**. **Use selected
spot** ties catches to a remembered non-pool spot without claiming open water.

Assignments are visible, clearable and runtime-only. Movement events, zone/
subzone/world changes, unrelated casts and reload clear them. Every use also
checks the water identity, a conservative 0.5%-of-map displacement guard when
coordinates are readable, and a five-minute idle limit. Each cast freezes its
source context. Cast evidence expires after 90 seconds; later confirmed fishing
loot uses a fresh local context without cast-time skill. A source change applies
to subsequent casts/windows.

Skill is sampled at cast time and compared at first fishing loot. If readable
components change (including a skill-up or bonus expiry), that event does not
assert measured successful skill. A stable readable base plus modifier supplies
effective skill only when `tempPoints` is zero; nonzero/unreadable temporary
points leave effective skill unknown. Raw readable fields remain separate.
Rod/equipment and lure contributions cannot be split reliably and remain unknown.
No sufficiently reliable requirement or skill-rejection association was
established, so neither is fabricated. Player advice belongs in provenance-labelled
notes. Interruptions/missed bites are never skill rejection evidence.

## Counting, history and corrections

One catch event means a fishing cast from which at least one readable **item
slot was actually cleared/acquired**. An item occurrence is one event containing
that item. Quantities sum slot quantities; multiple slots of the same item still
contribute one occurrence. Multi-item occurrence percentages need not total 100%.
The manual form accepts a primary item and optional additional ID/quantity
pairs from that same catch, all contributing one player-recorded event.
The UI defines the denominator as obtained events in the displayed contexts,
never fishing attempts, guaranteed loot tables or drop probabilities. Item
history shows only events containing the selected item; a source-context
denominator still includes obtained events without that item. The activity
filter says “With recorded catches” / “No catches recorded”, never asserting
that a place without successful observations has not been fished.

READY/OPENED snapshot and can confirm previously cleared pending slots.
SLOT_CLEARED supplies cumulative obtained quantities; nothing counts until
both collection and the fishing-loot classification are established.
Repeated READY/OPENED/CLEARED, close/reopen retries and duplicate GUIDs add only
new obtained quantities, not another event. Full bags add nothing until a
slot clears. If uncleared slots change identity/quantity on retry, the ambiguous
slots are withheld and the status offers manual fallback. If all readable
pre-loot information is lost, it cannot be reconstructed safely.

Trades, purchases, mail, bag events and loot chat are not acquisition inputs.
Containers are recorded as the caught item; later `isFromItem` loot is excluded.
An item ID with a missing name remains `Item #ID`, with an item-data request and
event-based name refresh. No loot-window clicks, autoloot settings, channels,
cast commands or other sections are intercepted or modified.

`AzerothFieldbookAnglingDB`, schema 1, contains:

- canonical waters (map plus exact zone/subzone), pool identities (readable
  observed object ID where supplied, otherwise exact name and locale), and item
  identities (item ID, otherwise exact name and locale);
- independent spot IDs with position meaning, first/latest sightings, notes
  and favourites; no coordinate-proximity merge and no per-cast permanent pin;
- durable aggregates distinguished by waters, spot, pool, source class,
  association evidence, and observed versus player-recorded acquisition;
- at most **200** detailed catch events, **32** sessions, and **256** recent
  cumulative event ledgers, with source totals and first/latest/minimum measured
  successful-skill evidence retained independently;
- separate reported result aggregates and origin claims, never personal counts,
  sessions, skill minima or rewards;
- independent state for each browse view: query, filters, selected ID, list
  offset, detail scroll and displayed map.

Empty/missing-schema data initializes without seeded knowledge; schema 0 adds
the missing current stores without clearing existing fields. A newer schema
is left untouched and uses detached read-only presentation state. Reload drops
pending casts/assignments, retains committed aggregates and recent dedupe ledgers,
and does not infer a new event from a loot window left open across reload.

An explicit compatible spot merge remaps references without coalescing source
aggregates. It archives the original spot's position, notes and provenance, and
keeps those notes visible on the surviving spot. Local notes and preferences are
never overwritten by a report. Personal identity observation can coexist with
reported identity/catch claims; it does not verify the rest of a report.

## Report foundation and integration boundary

Bestiary's wire schema, authenticated delivery hooks, offers and point charges
are creature-specific. Atlas exposes schema-bound report functions and staging,
not a generic fishing transport. Neither implementation is changed. Almanac
uses the same bounded length-prefix principle in its own data-only codec.
It adds no addon-wide networking, fishing prices, discovery points or cross-page
writes. Copy/paste is a local foundation and deliberate user action; there is
no Send button, automatic export, incoming message handler or price assumption.

`ns.AnglingReports` exposes these functional integration hooks:

1. `Build(journal, selectedID, knowledge, includeNotes)` selects the record and
   supporting references/results. The Reported mode forwards original claims.
2. `Normalize`, `Encode`, `Decode`, and `Preview` validate plain data and render
   the included content. The `AFBF1:` envelope requires schema 1 and exact TOC
   addon-version compatibility. Private notes are excluded by default; the one
   selected note requires explicit inclusion.
3. `Prepare(serialized)` returns a preview ticket backed by a detached validated
   snapshot. Editing the UI input invalidates it. `Cancel(ticket)` releases it.
4. `Accept(journal, ticket)` stages all writes and commits only a valid complete
   import after the user's separate acceptance. Raw tables cannot be accepted.

Limits: 96 KiB, 120 record identities, 128 catch summaries, bounded field
lengths, 12 parser nesting levels and 24,000 parser nodes. Types, plain tables,
versions, integer ranges, dense arrays, counts, coordinates, precision, dates,
reference kinds and source relationships are checked. Control/interface markup,
unknown fields, duplicate keys, malformed literals and trailing bytes are
rejected. Imported text is never executed.

Imported IDs only address the current envelope; local IDs are allocated or
matched by conservative identity. Source+origin keys deduplicate claims/results
across re-imports and forwarding. Forwarded claims retain their original content
and source, even after local name changes. Later cumulative snapshots replace
the same reported aggregate only if its context agrees and counts never decrease;
incompatible source/position changes are rejected atomically. This does not
authenticate an origin claim. Reports are capped at 4,096 stored result origins
and 8,192 identity claims; capacity failures change nothing. No separate inbox
or unbounded per-import payload log is retained.

## Automated and remaining manual verification

Run the repository-mandated command from the addon root:

```text
python -B -X utf8 tests/run_tests.py
```

The bundled Python executable is usable when `python` is not on PATH. The
existing pinned Lupa dependency is already available in `.codex-test-deps`.
The runner compiles all TOC Lua as Lua 5.1, validates manifest/version/bindings,
and runs every unittest module and top-level assertion script. The dedicated
Almanac suite covers the data, event, report, layout and interaction contracts
above; the existing section suite checks the new seven-tab registration and
retained behaviour of other pages. The initial worktree passed 44 test files
before this task; the new suite is the 45th file.

Final automated verification on 2026-09-27 passed: **52 Lua 5.1 files**, the
manifest/bindings/version checks for **0.13.0**, and **45 test files with zero
failures**, including **39 Almanac tests**. `git diff --check` passed. Starting
file hashes confirm that existing implementation files outside the three
necessary loading/initialization/registration files are unchanged, including
the Bestiary, Gatherer's Compendium, Atlas and shared shell/style code.

Remaining in-game checks — **all unperformed**:

- [ ] Escape a fish and click before a bite, then catch successfully. Check
  no failed catches/skill evidence, retained source assignment, no late-event
  duplicates and recovery with unreadable cast IDs.
- [ ] Hover a name-only school using the native world tooltip without Lua
  processor callbacks. Verify a Pool zone sighting appears with no coordinates.
- [ ] Remove an individual sighting in Waters; verify other zones/type/history
  remain, its pin/report inclusion disappears, re-hover is suppressed, and restore works.
- [ ] Check item icons and native tooltips in both catch lists, including uncached
  items, name-only manual entries, long names and panel reuse for source links.

The user supplied v0.13.3 screenshots showing an Oily Blackmouth caught in
Darkshore with an empty journal and "Cast identity unavailable" status. This
is evidence of the old failure, not live verification of the v0.13.4 fix.

- [ ] After reload, catch from open water with and without explicit assignment.
  Confirm new items/quantities record even if cast GUIDs are unavailable; test
  repeated catches, autoloot and full-bag retries without duplicates.
- [ ] Hover named pools and localized Fishing requirement tooltips. Verify the
  type appears in the current-zone list without a pin or catch attribution;
  unrelated objects, bobbers, inventory items and unit tooltips add nothing.
- [ ] Remove a pool type, hover again, reload, then restore through Show: removed.
  Check automatic suppression, preserved notes/history and report behaviour.

- [ ] First login with a new/empty journal; open Almanac before Atlas. Verify
  background acquisition before any Fieldbook page is opened.
- [ ] Switch Atlas ↔ Almanac on the same map: no map-position/size jump. Check
  supported UI scales, resolution changes, uncommon aspect ratios and missing
  artwork. Verify unchanged main-window size and independent map selections.
- [ ] Long names, text wrapping, empty filters, nine-row paging, scrolling,
  notes drafts, report text copy/paste and tooltips; left editors must leave
  the map visible and stationary.
- [ ] List ↔ pin selection, overlapping spots, transient water position,
  reverse lookup, reports-only filters, merged spots and reported labels.
- [ ] Normal fishing, uncertain pools, explicit source assignment, open water,
  non-fish items, multiple slots/quantities, autoloot, interrupted casts, missed
  bites, full bags and close/reopen retries. Check actual event order/readability.
- [ ] Expired/replaced lures, skill increases and unavailable fields: no invented
  requirement, equipment contribution or minimum skill.
- [ ] Movement, subzone changes, another spell, five-minute idle, leave/return,
  close/reopen and reload: saved views/notes survive, stale assignments do not.
- [ ] Two-character reports: preview/accept, notes opt-in, repeat import, later
  cumulative updates and forwarding; personal totals/rewards remain separate.
- [ ] Bestiary, Gatherer's Compendium, Atlas and all other pages retain their
  appearance, controls, navigation, state and existing tracking behaviour.

No commit, push, tag, package or publication is part of this work.

v0.13.28: the Almanac zone selector now matches the Atlas selector at 306 UI units
wide; its position, menu behavior and saved selection are unchanged.
Its shared dropdown arrow now uses native artwork with a dark drop shadow rather
than a typed `v`.
