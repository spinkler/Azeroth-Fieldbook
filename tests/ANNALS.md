# Adventurer's Annals Beta

Annals is the eighth native right-edge section. Its purpose is a character's
historical record, not quest tracking or quest guidance. The addon version is **0.23.0** (Beta tag `v0.23.0-beta`) for public testing. Native API and visual
acceptance remain pending.

## Using Annals

Open **Adventurer's Annals** using the gold ?! tab. The timeline is oldest first,
with seven reusable rows, local dates/times, page buttons, mouse-wheel paging,
type filters, an optional character level and explicit date fields. **All dates**
resumes the complete history; **Latest** moves to its last page. **Refresh** reads
newly captured history while the page is open.

Select an event to read its immutable snapshot, chosen/automatic rewards and
location. **Around event** selects the surrounding hour. **Quest interval** uses
that observed quest cycle's acceptance and removal/turn-in, where known. Linked
discoveries in an interval mean temporal overlap only; no causal link is stored.

**Show Journey** displays a separate instance of the existing Atlas map renderer.
Choose a historical map and move the time slider. The clock reports the selected
time and most recent retained sample's actual time and coordinates. It does not
interpolate constant travel speed. Marker tooltips carry event details; clicking
a marker opens its timeline detail. Repeated clicks cycle overlapping events.
Each map uses its own stored coordinates, including micro maps; parent maps do
not receive relabelled child coordinates or invented connecting lines.

Date and level filters affect both events and trail chunks; event-type filters
affect markers, not unrelated route geometry. Dense views show at most 64 recent
chunks and 2,048 edges at the scrubbed time, plus 512 recent event candidates
(the Atlas renderer groups at most 192 visible pins). A visible notice asks you
to scrub earlier or narrow the dates. This is a display bound, not retention.

Uncheck **Record Journey** to stop future breadcrumbs. Quest events, their
observed player locations and linked discoveries continue. No old data is erased.
**Storage** shows counts and exact compact point payload; headers and events are
additional. See the [measured storage report](ANNALS_STORAGE.md) for estimates.

## Architecture and changed modules

| Module | Responsibility |
|---|---|
| `AnnalsJournal.lua` | Schema, immutable events, quest lifecycle deduplication, reference deduplication, date/type/level queries and source-safe location snapshots |
| `AnnalsTrail.lua` | Nine-byte codec, bounded chunks, adaptive sampling, break detection and anchor-preserving simplification |
| `AnnalsTracking.lua` | Guarded Forever quest/reward APIs, provisional removal/turn-in coalescing, login baseline and two-second ticker |
| `AnnalsMap.lua` | Exact-map historical index/cache, bounded geometry/markers and the existing Atlas factory adapter |
| `AnnalsBook.lua` | Native eighth section, filters, paging, details, cross-links, date ranges, Journey controls, help and diagnostics |
| `AnnalsIntegration.lua` | Optional discovery publication bus, registered read-only reference adapters and initialization |

Narrow emitters were added to Bestiary's existing entry callback in
`AzerothFieldbook.lua`, and to `GatheringJournal`, `AtlasJournal`, `AtlasEntrances`,
`AnglingJournal`, `LedgerJournal`, `TreasureJournal` and `LoreJournal`. They publish
only local observed/deliberate recording boundaries. They do not enumerate source
databases to manufacture history, and imports do not publish discoveries. Existing
Atlas subzone samples remain under Atlas ownership; they are not duplicated as
Annals discoveries. Deliberate Atlas entries and detected entrances do publish.

Sources can use `ns.RecordFieldbookDiscovery(section, entry, owner)`; listeners
register by name through `ns.RegisterFieldbookDiscoveryListener`. Observer failures
are isolated from source recording and retained in `ns.AnnalsDiscoveryError` for
diagnosis. The Annals reference registry supplies `resolve` and `open` adapters.
It retains ID, durable source identity, label and icon rather than the source
entry. The existing section controllers handle navigation; Gathering gains a
small `Select(id)` method. Deleted/unavailable references retain their historical
labels. Ledger/Treasure references and Angling identity aliases support remapping;
unsupported moves fail closed rather than resolve by a reused numeric ID.

The TOC adds six modules and `AzerothFieldbookAnnalsDB` to
`SavedVariablesPerCharacter`. Initialization runs after the seven source journals.
`AccountSections.lua` only adds the explicit character-scope label; Annals never
enters shared stores, import/reset paths, or report/network protocols.

`FieldbookBackups.lua` adds a ninth saved root and preserves Annals when restoring
an older AFBWB1 archive that lacks that slot. New archives explicitly encode its
presence/absence. The same staging, owner check, rollback and startup hold apply.
Backup window/Options descriptions include the eighth journal. Old addon versions
will reject the additional root rather than silently drop it.

## Historical integrity and storage

Schema 1 has `events`, `segments`, `quests`, `pending`, `seen`, `settings`, and an
observation sequence counter. `events` only grows. `quests` is a small mutable
capture-state index, not the historical record. Accept → remove → accept → turn-in
produces four events. Confirmed repeat reward transactions remain distinct, while
duplicate notifications for the same cycle are suppressed. Real Unix timestamps
and sequence values preserve same-second ordering even when confirmation is delayed.

Removal is provisional for two seconds to allow a corresponding turn-in to win;
turn-in finalization waits 0.2 seconds for a secure reward post-hook, since native
events can be synchronous. Provisional evidence is persisted immediately and
finalized after reload. A fresh login reads the quest log once to cache current
IDs/titles; it never fabricates historical acceptances or offline removals.

Events preserve readable quest title, quest ID, player level, zone/subzone, exact
map context and player coordinates where available. A discovery's event position
is where the player was when it was recorded, not proof of an object's position.
Unknown fields stay absent. No current API lookup rewrites an old event.

Trail chunks have their own format version, map, start/end seconds, start level,
boundary reason, instance/death context and printable payload. Event markers remain
durable independently of trail fidelity. See [storage design and measurements](ANNALS_STORAGE.md).
There is no total history cap or age eviction. Each decoder input is bounded to
256 points/2,304 payload bytes. Malformed/future chunks are preserved and not drawn;
sparse/malformed collection roots or unknown schemas disable writes without
replacing the saved root. Invalid individual events remain in raw storage but are
excluded from the active index. Future schemas require an explicit migration.

SavedVariables become durable on successful `/reload` or logout. A process crash
or forced termination may lose session changes; no addon can force an ordinary
SavedVariables disk flush. Reload never connects a new session to an old live chunk.

## Forever API evidence and genuine limitations

The installed `WowB.exe` reports **1.60.1.70170** (Interface 16001 in the addon TOC).
Inspected Blizzard's current `forever` branch sources, mirrored by Gethe, during this
implementation. These were source inspections, not a live API probe of build 70170.
The client's native source determines the adapter shape; mocked
tests do **not** certify this installed client's live event order or access rules.

- [UIPanels TOC](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Blizzard_UIPanels_Game.toc)
  selects family QuestFrame/QuestInfo for Camelot and explicitly lists its overrides.
- [QuestLog API/event definitions](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua)
  expose `QUEST_ACCEPTED(questID)`, `QUEST_REMOVED(questID, wasReplayQuest)` and
  `QUEST_TURNED_IN(questID, xpReward, moneyReward)`. The last event supplies XP and
  copper. `QUEST_COMPLETE` opens reward dialogue; it is not a completed quest.
  Removal alone does not prove abandonment; a matching observed abandon request
  permits the stronger label. The adapter does not assume an older Classic
  quest-log-index-first event signature.
- [QuestFrame reward handler](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua)
  passes `itemChoice` to `GetQuestReward`, and selects the sole option automatically.
  A guarded secure post-hook observes that request; it never requests a reward.
  An observed multi-option index is paired with cached offered metadata and a
  confirmed turn-in. A sole option is labelled automatic, not a player choice.
- [QuestInfo reward rendering](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestInfo.lua)
  reads `GetQuestItemInfo(type,index)` as name, texture, quantity, quality,
  usability, item ID, and uses `GetQuestItemLink` as a fallback. The prototype
  stores only stable ID, quantity, optional historical name/icon. Unavailable
  metadata or an unobserved request leaves the choice unknown. Automatic item
  offers are recorded separately after confirmed completion.
- [QuestInfoSystem](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestInfoSystemDocumentation.lua)
  and [QuestOffer](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestOfferDocumentation.lua)
  expose currency offers. Readable IDs and total offered amounts are retained,
  including a selected currency option where identifiable. These are explicitly
  labelled **offered amounts**, not measured currency-balance changes or cap effects.
  A broad reliable general-faction reputation grant API was not established;
  major-faction-only helpers are not treated as Classic reputation coverage.
  Reputation, spell unlocks and other reward types remain uncaptured, not zero.
- Existing `AtlasEnvironment.Position(mapID)` queries `C_Map.GetPlayerMapPosition`
  for that same map ID. Annals never calls Atlas's exterior entrance sampler or
  rewrites recorded micro coordinates. Unknown positions produce a break.
- [Map API definitions](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua)
  provide `GetMapRectOnMap(child,parent)` with minX/maxX/minY/maxY. Annals projects
  copied points and event markers onto ancestor maps at display time. When a direct
  rectangle is unavailable, it composes validated immediate-parent rectangles.
  Missing/invalid rectangles omit that map's geometry; no hardcoded placement is
  guessed. Recorded positions remain unchanged. Atlas's shared renderer is unchanged.
- [Taxi events](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TaxiMapDocumentation.lua)
  expose `TAXIMAP_OPENED` and `TAXIMAP_CLOSED`; the
  [native taxi frame](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Shared/TaxiFrame.lua)
  reads `TaxiNodeGetType` and `TaxiNodeName`. Annals snapshots the current flight
  master's location/name and appends a flight departure only once flight state is
  observed. Merely opening the taxi map adds no flight event. Without that snapshot,
  a recent ground observation supplies the departure position and a generic label.
  Reloading already in flight does not invent a departure. Flight markers persist
  when breadcrumb recording is disabled; their locations never seed future nodes.

Balanced trail retention checks position every two seconds but keeps ordinary
points at least 15 seconds apart, normally 16 on that ticker. It requires at least
40 normalized units of movement, plus either 160 units displacement or 60 elapsed
seconds; a 40-unit bend can retain the preceding candidate under the same cadence.
Events and segment endpoints are exceptions. Closed chunks simplify at 30-unit
tolerance while preserving anchors. Subzone-name and mounting changes no longer
break continuous travel. A map crossing joins only with short, validated adjacent
world positions; loading, missing coordinates and observation gaps remain separate.
These changes affect future recording. Existing chunks remain intact, including
their old gaps; continent/world projection also works for existing valid history.

Short same-map teleports under the normalized jump threshold without a loading
event cannot be distinguished reliably from fast travel. Polling and simplification
approximate the travelled line; this is not exact movement telemetry. Corrupted or
missing native fields are not guessed. Turn-in events delayed beyond the removal
coalescing window may leave both a removal observation and later completion; these
are separate observed notifications, not retroactive rewriting.

## Automated verification

Run `python -B -X utf8 tests/run_tests.py` for the complete repository runner.
Focused checks are `tests/test_annals.py`, `tests/test_annals_storage.py` and
`tests/test_storage_scope.py`; the existing backup, startup preservation, navigation,
Atlas/micro-map, account and all journal suites cover shared integration surfaces.
Generate measurements with `python -B -X utf8 tests/annals_storage.py --write`.

Fixtures cover acceptance/removal/reacquisition/repeat completion, duplicate
suppression, baseline/reload, synchronous reward-hook ordering, chosen/automatic/
sole/missing/currency rewards, linked discoveries and missing targets, stationary/
slow/continuous movement, turns, map changes, jumps, anchor-preserving simplification,
disabled recording, compact decoding failures and version mismatches, long ranges,
cache bounds, actual Atlas render adapter, marker cycling, full-TOC eight-tab
navigation and backup compatibility. Storage fixtures exercise six-hour paths and
100/1,000/3,000/7,200-hour projections. No fixture touches player SavedVariables.

The initial prototype passed the complete repository runner: **84 test files, 0 failed**.
Subsequent map/sampling fixes pass 23 focused Annals cases and the storage scenario
test; all 93 runtime Lua files compile under Lua 5.1. These focused checks cover
cadence limits, confirmed flight departure deduplication, repeated subzone
changes, continent/world projection, safe joins, scrub cutoffs and the black track.
The focused Annals suite also includes an actual staged
restore of an older archive into a fresh Lua namespace with existing Annals.

## In-game acceptance checklist

Journey lines cool from gold toward blue and fade with age relative to the selected
scrubber time, with a 30-minute cooling half-life. The character's Trail age contrast
slider defaults to 75%; 0% restores uniform gold and 100% gives the strongest effect.
Old lines retain an opacity floor. Markers and saved trail coordinates are unchanged.
Check overlapping routes at several slider strengths and scrub back to confirm that
historically recent travel becomes bright again.

1. `/reload`; open all eight tabs. Check the combined gold ?! icon, tab fit, parchment, text size,
   small-screen scaling, Options scope label and shared-window placement. Visit
   Atlas's normal maps/subzones/micro maps and confirm their behaviour is unchanged.
2. Accept a fresh quest with Annals closed. Confirm one acceptance with title,
   local timestamp, level and observed location. Abandon it, wait two seconds,
   reacquire it, and turn it in: four chronological entries. Reload between stages.
   Repeat a repeatable quest and verify each cycle remains separate.
3. Turn in quests with multiple item choices, one sole option, guaranteed items,
   no items, and unreadable/not-yet-cached rewards. Match selected item ID/name/count;
   verify automatic items are labelled separately and unknown is never a guess.
   Test a reward chosen by another addon. Check XP/copper against the turn-in.
   If available, verify currency offers and their explicit offered-amount label.
4. Open a reward dialogue and cancel it; it must not complete a quest. Cause a
   failed reward request (for example full bags) and retry. Check there is still
   one confirmed completion with the final observed choice, not an attempted choice.
5. Discover entries in every existing journal between quest acceptance and turn-in.
   Check Annals labels and icons, then Open linked journal. Test Gathering selection,
   an Atlas entrance, an Angling record and a Lore writing. Delete a linked entry;
   its Annals event must remain readable and navigation must fail gracefully.
6. Walk a path with turns, ride a mount and a flight path, then stand still for
   ten minutes. Compare Storage point counts. Turn Journey off and continue a quest;
   events must continue while trail counts stop. Turn it back on and verify a break.
   Open/cancel a taxi map (no departure), then take a flight: one flight-master icon
   should appear at departure. Fly through several named subzones and across a zone
   border; the continuous observations should form a connected path on parent maps.
7. Cross zone/continent borders, enter/exit a cave or micro map and an instance,
   hearth/portal, die/release/resurrect and board/leave transport. Check separate
   segments and absence of lines across unobserved travel. Pay special attention to
   micro-map coordinate labels and small same-map discontinuities.
8. Select dates and a level, Show Journey, choose each historical map, scrub to
   both ends and several midpoints. Check exact sample times, progressively visible
   geometry, event tooltips, overlapping marker cycling and dense-range notice.
   Check the black slider track. Navigate up to continent and world maps; the route
   and event markers should shrink into the correct locations and still scrub.
   Open another journal and return; no live player arrow should appear in history.
9. Reload while travelling; logout/login and restart the client. Verify earlier
   events/chunks remain, the last event is not duplicated, and new session geometry
   starts separately. A crash is only a best-effort durability test, not guaranteed
   preservation of unsaved session changes.
10. Create a whole-Fieldbook backup, inspect its Annals counts, and use the existing
    staged restore workflow on a test character. Test a pre-Annals archive: current
    Annals must be preserved. Check recovery rollback and Bestiary reset isolation.
11. Play with Annals closed and in combat; watch for Lua errors, visible hitches and
    unexpected map updates. Collect the Storage counts and the exact client build
    with the path/quest scenario for tuning. Test native visuals separately from
    mocked UI control-flow checks.

## Review concerns to carry into native testing

No native WoW session was controlled during implementation. Native timing, protected
API access, actual map art/line support and visual layout require the checklist.
Normalized movement thresholds vary in physical distance by map size; short detours
between retained points may be lost with balanced retention. Anchors and boundaries
can add points beyond the ordinary 15-second minimum interval. No destructive
retention policy has been added to hide this cost. Runtime indexing and SavedVariables
loading cost at multi-million-point histories also need real-client measurement.
