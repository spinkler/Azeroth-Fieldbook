# Adventurer's Annals

Reward names that are empty or whitespace-only are treated as unavailable.
Existing saved entries remain intact: the detail view can resolve their item
names from the client cache, refresh when item data loads, or show an explicit
`Item #ID` fallback while unavailable. Recorded nonblank names retain priority.
Icons, quantities, quality colours and tooltip links remain independent of name
availability. New reward snapshots omit blank names so a later readable snapshot
can supply them. `tests/test_annals_reward_names.py` covers the blank-name detail
rows, delayed cache refresh, immutable history, fallbacks and capture recovery.

## Idle and gathering arrow

The arrow turns grey after ten seconds of observed stationary time out of combat.
Movement, combat or gathering resumes its active colour. After combat or a gather
ends, a fresh ten-second stationary interval is required. Idle requires a known
out-of-combat state and does not replace death, ghost or flight colours. It uses
the existing two-second observations; the saved boundary is the ten-second mark
even when a poll arrives later. Leaving idle through movement preserves the last
stationary observation as the departure, so interpolated movement is active.

Observed Herbalism and Mining casts turn the arrow yellow. Annals reuses the
Gatherer's spell classifier, including localized profession-rank names. Player
cast start/end events capture short casts, while guarded `UnitCastingInfo` reads
provide a baseline after reload. Matching completion, stop, failure and interrupt
events clear gathering; unrelated units and stale cast GUIDs cannot end a newer
cast. If an end event is missing and the cast query is unavailable, the observed
cast expires after thirty seconds. Hovering a node or crafting does not establish
gathering. Combat orange takes priority over gathering yellow.

The optional segment `activity` header stores `idle` or `gathering`, without
changing the version-1 point codec. State boundaries retain their timestamps for
playback without timeline entries or periodic idle writes. Unknown/older activity
is not backfilled. Loading and missing-position gaps reset the idle baseline.
These two colours affect only the arrow; trail colours are unchanged. The footer
names the activity and the Journey legend shows both arrow swatches in its
existing compact layout. Held instance entrances do not show interior activity.

`tests/test_annals_activity.py` covers the exact threshold, sparse polls, small
movements, stationary combat, gathering completion/failure/interruption, localized
spell ranks, stale casts, reload capture, expiry, gaps, recording-off and unknown
data, plus mock arrow/footer/legend rendering and unchanged trail colours.
Native acceptance: wait at least ten seconds out of combat, move, gather a herb
or mineral, cancel a gather, and fight while stationary. Scrub the same intervals
in Journey and inspect the new legend rows at the supported text/UI scales.

## Combat trail and compact legend

Journey records the player's observed combat entry and exit without adding
timeline rows, event filters or map pins. The arrow and trail turn orange during
recorded combat; the footer says **in combat** or **out of combat**. Death, ghost
and flight colours take priority, while combat overrides mounted trail colours.
This records the player's state, not enemy locations, damage, kills or a battle
heatmap. Combat transitions follow **Record Journey**; existing events still
retain their observed location and state. An instance entrance held on
the outdoor map does not imply the character's combat state inside.

`PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED` sample transitions immediately.
Guarded `UnitAffectingCombat('player')` reads provide the baseline on ordinary
location captures, including after login/reload. These APIs/events are present
in the locally inspected Forever 69977 generated `UnitDocumentation.lua`
(function at line 614, events at lines 3869/3875); the
[Blizzard source mirror](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ActionBar/Shared/ActionBar.lua)
also uses these events with the player combat query. Native Forever acceptance
remains required.

The optional boolean `combat` lives on the existing version-1 trail segment
header. The nine-byte point codec and archive schema are unchanged. A connected
combat transition anchors the old segment's endpoint and starts the new state
at the same observed time and place, retaining the timing of stationary fights
without periodic idle writes. Gaps, missing positions, loading and large jumps
keep their existing discontinuities. Projection, interpolation and smoothing
preserve combat boundaries. Absent metadata remains unknown: older trails are
neither rewritten nor labelled out of combat. Restricted queries cannot create a
combat observation. Like the other trail states, a previously observed state may
remain on a continuous segment until another observation changes it.

The legend opens on **Journey**, with separate arrow and trail columns; **Events**
shows all existing event icons in two columns, including instance entry/exit.
The selected tab glows, and the existing Legend button closes the overlay.
Trail swatches still reflect the age-contrast setting.

Validation: `tests/test_annals_combat.py` covers transitions while moving and
stationary, same-second ordering, duplicate events, projection, persisted reloads,
recording-off/read-only/loading/instance guards, unknown and restricted reads,
colour priority/fading, smoothing, rendered mock colours/footer and legend tabs.
The existing `tests/test_annals.py` remains the broader Annals regression check.
Native acceptance: record a fight while moving and standing still, scrub across
both boundaries, verify the main list is unchanged, reload during combat, and
inspect both legend tabs and orange contrast at the supported UI/text scales.

Observed PLAYER_LEVEL_UP events record Reached level X using the event's new
level, time and location. Level ups have a golden Holy Nova icon, a separate
timeline/map filter and a Journey legend entry. They record with Journey
recording off; previous levels are not backfilled. Native level-up and icon
acceptance remain pending.

Login and Logout are separate event types with timeline/map icons, filters and
Journey legend entries. The first `PLAYER_ENTERING_WORLD(true, false)` records
login once per loaded session. `PLAYER_LOGOUT` also fires for UI reloads, so its
time, location and sequence are saved provisionally in `sessionLogout`. The next
real login confirms that logout at its original time; an entering-world reload
discards it. Zone loads do neither. Offline time remains a trail gap. Events
remain enabled when Journey recording is off. Crashes and forced disconnects
may leave no logout marker; earlier sessions are not backfilled. This still
needs native acceptance with a logout/login, `/reload`, and instance loading.

Annals is the fourth native right-edge tab, following Traveller's Atlas. Its purpose is a character's
historical record, not quest tracking or quest guidance. The addon version is **0.27.0** (Release tag `v0.27.0`). Native API and visual
acceptance remain pending.

## Using Annals

Open **Adventurer's Annals** using the pocket-watch tab. Journey stays in the right
pane, and the timeline opens on the left. The timeline is oldest first,
with seven reusable rows, local dates/times, page buttons, mouse-wheel paging, an overflow-only scrollbar,
type filters, an optional character level and explicit date fields. The shared
styled **Search** field supports case-insensitive partial words across quest
titles, event details, dates, places and all recorded reward lists (including
unchosen acceptance offers). Every typed word must occur, possibly in different
fields: `sword Westfall` matches sword rewards recorded in Westfall. Punctuation
is literal. Native item metadata adds current names, item types/subtypes, slots,
quality, descriptions and readable tooltip text; a sword need not have “sword” in
its name. Missing item data is requested once per search cache, and successful
loads refresh results. Search is debounced and cached only in memory; clearing it
or hiding Annals releases the cache. It never rewrites historical observations.
Matching funnels beside Search and at the map top right open the event-type filter menu and glow
when any types are excluded. Search combines with date/type/level filters. Journey markers respect the search;
the historical arrow, follow lookup and trail geometry remain unfiltered.
**Now / reset** returns to the current timestamp, clears search/date/level/event filters, selects the
latest page, restores full-range timing and 1x speed, disables Follow player and
resets the map to the current zone (or known outdoor instance entrance) at full extent. **Latest** moves to the last page. **Refresh** reads
newly captured history while the page is open.

Select an event to seek its recorded time and map in Journey, then toggle
**Show detail** to read its immutable snapshot with a large gold title, coloured
event status, muted time/location details, and separate reward headings. Accepted
quests list all captured offered choices and guaranteed rewards; completed quests
show the observed choice and guaranteed rewards. Reward rows have quality-coloured
names enlarged by two points, icons and native hover tooltips. Single rewards
omit ×1; larger stacks retain their count. Timeline icons, including quest ! / ?,
have offset dark shadows. Coin amounts use coloured g/s/c suffixes.
Long lists scroll over both text and icons. **Around event** selects the surrounding hour. **Quest interval** uses
that observed quest cycle's acceptance and removal/turn-in, where known. Linked
discoveries in an interval mean temporal overlap only; no causal link is stored.

Journey displays a separate instance of the existing Atlas map renderer.
**Show detail** sits in the left pane, keeps its label unchanged and uses the
shared toggle highlight while its scrollable detail overlay covers the timeline.
Turn it off to restore the same timeline page and selection. Journey and its
playback remain visible and usable on the right throughout. Filters still apply.
**Around selected event**, recorded level, **Trail age contrast** and **Map icon
size** sit in the right pane. Hover the contrast slider for its explanation.
Contrast and icon-size labels, sliders and values share one row below the map,
which uses the same position as the other journals. **Around selected event**
has a tooltip explaining its hour-long window, 30 minutes on either side of the
event, with the exact range when a selection is available.
**Choose zone** sits above the map's top left.
**Legend** toggles an overlay of the actual event icons, player arrows
and trail swatches, including the current age-contrast setting. Move the time
slider using **Full range / 3 hours / 1 hour / 15 minutes**. This also clips the trail to that duration behind the playback time, including edges crossing the cutoff. The clock reports the selected
time and historical position, with the recorded last-sample timestamp on a separate grey line even between connected samples.
Playback offers 1x/8x/32x/64x/128x/256x and play/pause symbols. The compact custom speed field beside the presets has an **x** suffix and accepts 0.1-4096; Enter applies it, Escape restores the current rate, and invalid input leaves playback unchanged. The gold readout at the scrubber's right edge shows elapsed time from its start / total span, including date and quest selections; full range measures elapsed recorded timestamps, including offline gaps. Below one day, seconds remain visible (e.g. **00s / 3h00m00s**). At a total span of one day or more, both values use days/hours/minutes and omit seconds (e.g. **0d01h01m / 1d00h00m**). Verify alignment and legibility in game. **Follow player** keeps
the arrow in view, switches recorded zone/continent maps and jumps at observed
teleport/hearth arrivals. It never uses the character's live position for playback.
Both **Legend** and **Follow player** use the shared yellow toggle glow while
active, with stable labels. The legend has no separate close button. Instance
markers have a green inward arrow for entry and an orange outward arrow for exit;
the timeline, grouped map pins and legend use the same graphics. Overlapping
equally important travel markers show the latest observed transition.
Marker tooltips carry event details; clicking
a marker opens its left-pane detail overlay without moving the Journey.
Repeated clicks cycle overlapping events.
Each map uses its own stored coordinates, including micro maps; parent maps do
not receive relabelled child coordinates or invented connecting lines.

Date and level filters affect both events and trail chunks; event-type filters
affect markers, not unrelated route geometry. Dense views show at most 64 recent
chunks and 2,048 edges at the scrubbed time, plus the latest 15 located events on the selected map. The newest ten retain full opacity; the next five fade to 5/6, 4/6, 3/6, 2/6 and 1/6 opacity. Overlapping groups use their newest member's opacity. A visible notice asks you
to scrub earlier or narrow the dates. This is a display bound, not retention.

Uncheck **Record Journey** and answer **Yes** to stop future breadcrumbs. **No**
or leaving the page keeps recording enabled; re-enabling needs no confirmation. Quest events, their
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
| `AnnalsBook.lua` | Native section, filters, paging, details, cross-links, date ranges, Journey controls, help and diagnostics |
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

Incomplete new acceptances use the same persisted `pending` store for up to ten
seconds while the accepted quest's log rewards load. Timestamp, position and
sequence are fixed at acceptance; its trail anchor is sampled immediately and
not replayed when the event is finalized. Complete dialogue offers append at
once. Incomplete offers are refreshed once more from the still-matching dialogue,
then retried against the verified quest log entry. Full matching log snapshots
fill missing offers, preserving previously observed item fields and XP/money.
Conflicting choice counts, reward identities or quantities are rejected.

Log reads save and restore the selected quest and cannot fall back to a different
open dialogue. Reads are throttled to once per second per pending acceptance;
quest/item updates and bounded timers retry, with the two-second poll as fallback.
Reload preserves pending capture, but expired windows never read later rewards.
Removal/turn-in finalizes acceptance first. Recovered rewards record their source
and capture time; finalized events remain immutable. No old incomplete event is
backfilled, and unavailable APIs retain the observed partial snapshot. New
acceptance entries may therefore appear a few seconds after the click.

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
  stores stable ID, quantity, optional historical name/icon, quality and validated
  item-link data. `QUEST_DETAIL` captures offered choices before acceptance;
  `QUEST_ITEM_UPDATE` refreshes that transient offer, and only a matching accepted
  quest writes the snapshot. A closed dialogue keeps a brief grace period for
  synchronous acceptance. Missing or unrelated offers remain unknown. Unavailable
  metadata or an unobserved request leaves the choice unknown. Automatic item
  offers are recorded separately after confirmed completion.
  The same renderer uses `GetNumQuestLogChoices`, `GetNumQuestLogRewards`,
  `GetQuestLogChoiceInfo`, `GetQuestLogRewardInfo`, `GetQuestLogItemLink` and log
  XP/money getters for a selected quest, then waits on asynchronous item loads.
  Annals uses these getters only after checking `GetLogIndexForQuestID` and
  `GetInfo` against the newly accepted quest ID; it verifies the selection and
  restores it even after a getter fails. `RequestLoadQuestByID` starts loading;
  `QUEST_LOG_UPDATE`, `QUEST_DATA_LOAD_RESULT` and `GET_ITEM_INFO_RECEIVED` retry
  only pending new acceptances. This is metadata completion of an observed
  acceptance, not evidence that any offered item was actually received.
- [QuestInfoSystem](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestInfoSystemDocumentation.lua)
  and [QuestOffer](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestOfferDocumentation.lua)
  expose currency offers. Readable IDs and total offered amounts are retained,
  including a selected currency option where identifiable. These are explicitly
  labelled **offered amounts**, not measured currency-balance changes or cap effects.
  A broad reliable general-faction reputation grant API was not established;
  major-faction-only helpers are not treated as Classic reputation coverage.
  The same QuestInfo renderer reads `GetRewardXP`/`GetRewardMoney` for offered
  amounts and `GetQuestRewardSpells`/`GetQuestRewardSpellInfo` for spell offers.
  These are retained as offers, not proof of learned spells or actual grants.
  Reputation and other unsupported reward types remain uncaptured, not zero.
- [Item APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)
  provide `GetItemInfoInstant` item type/subtype and `GetItemInfo` names,
  equipment slots, quality and descriptions. Search supplements recorded reward
  names with these guarded, display-only lookups. Readable left/right text from
  [GetHyperlink tooltip data](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoDocumentation.lua)
  also participates, with formatting codes removed and at most 64 lines per item.
  Item cache completion invalidates only the relevant metadata and coalesces a
  visible search refresh. Unavailable metadata cannot establish a match.
- Existing `AtlasEnvironment.Position(mapID)` queries `C_Map.GetPlayerMapPosition`
  for that same map ID. Annals never calls Atlas's exterior entrance sampler or
  rewrites recorded micro coordinates. Unknown positions produce a break.
- [Instance API definitions](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/InstanceDocumentation.lua)
  expose `IsInInstance`'s instance type and `GetInstanceInfo`'s name/instance ID.
  Annals guards these reads and recognizes party, raid and scenario interiors.
  The numeric instance ID distinguishes different instances from floor loading;
  names provide a fallback when an ID is unavailable.
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
Events, confirmed stop/resume boundaries and segment endpoints are exceptions.
Four seconds at unchanged coordinates confirms a stop; its arrival and the last
stationary observation before departure become anchors. Continued idle time adds
no periodic samples. Closed chunks simplify at 30-unit spatial and timestamp-based
interpolation tolerance while preserving anchors, so straight-line speed changes
and rests are not discarded merely because they lie on the same line.
Subzone-name and mounting changes no longer
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

Playback, instance visits, controls, search and reward detail/capture pass 58 focused Annals tests plus the storage
scenario test; all 93 runtime Lua files compile under Lua 5.1. Added cases cover
fractional playback without full redraws, exact/same-second samples, date clipping,
recorded gaps, stop/resume timing, speed changes, long rests, chunk bounds,
cross-map and parent-map centering, hidden markers, missing history and map edges.
Additional cases cover source-map following through zones/continents, gap holds,
same-map teleport jumps, per-frame camera movement, pause/reset controls, reward
offer matching/partial data, acceptance versus completion, cached item metadata,
native tooltip links, coloured coin units, long reward lists and pooled-row cleanup.
Search cases cover partial quest/item names, subtype-only sword matches, tooltip
stats, multiple words, literal punctuation, sparse offers, all reward buckets,
date/type/level composition, route/arrow preservation, debounce, item cache arrival,
the shared placeholder/clear button, empty results, reset and saved-data preservation.
Instance cases cover entry positions sampled at the doorway, interior deaths and
discoveries, floor loading, exit discontinuities, reloads inside raids, hearths
out, unknown entrances, observed login exits, and Follow player across visits
whose entry precedes the selected dates. Control checks cover confirmation
accept/cancel, immediate re-enable, page-hide cancellation, map anchoring, legend
graphics and the revised time spans.
Additional regressions exercise fast acceptance with cold item data, quest-log
selection restoration, late log entries, expired/reloaded pending captures,
conflicting offers, absent/throwing APIs, duplicate acceptance, lifecycle ordering,
original timestamp/location/XP preservation and no delayed trail replay. UI cases
cover singleton/stack quantities, reward font sizing, timeline shadows, distinct
entry/exit badges (including grouped pins) and shared toggle selection state.
The regenerated storage report still retains one point for six stationary hours.
These are mocked control-flow/geometry checks; native playback feel remains a
live acceptance check.

## In-game acceptance checklist

Journey lines cool from gold toward blue and fade with age relative to the selected
scrubber time, with a 30-minute cooling half-life. The character's Trail age contrast
slider defaults to 75%; 0% restores uniform gold and 100% gives the strongest effect.
Old lines retain an opacity floor. Markers and saved trail coordinates are unchanged.

Playback linearly interpolates the arrow and partial route edge between connected
observations using their timestamps. The arrow updates each display frame from
cached endpoints; route redraws remain throttled to 0.1 seconds, with immediate
sample/event-boundary refreshes. Estimates are labelled and never saved. Explicit
short boundary joins may interpolate onto ancestor maps; loading, session and
other unconnected gaps hold the last recorded position. A lookahead chunk shares
the 64-chunk decode/cache budget. Existing recordings benefit from interpolation,
but missing historical stop timing cannot be recovered.

Find player replaces both one-second buttons. It pauses at the selected time,
finds the latest historical position across maps independently of event filters,
keeps the viewed map if it can project that position, and otherwise switches to
the recorded map. It centers at a minimum 2x zoom, retaining a closer zoom and
clamping at map edges. Missing history gives a message without moving the time or
map. The timeline mouse wheel still adjusts one second at a time.

Follow player is an independent on/off toggle. When enabled it centers the
selected historical position and follows it during playback, preserving zoom
through map changes. A separate bounded position lookup reads source-map samples
and unfiltered events; no mixed-map route is drawn. Loading gaps hold the last
known position, then recorded arrivals jump directly to their destination. Turning
follow off keeps playback running and leaves the map available for manual panning.

Travel events: successful player casts of Hearthstone (8690), Astral Recall
(556), the six Classic capital teleports (3561/3562/3563/3565/3566/3567), and
Teleport: Moonglade (18960) record the pre-cast departure with a dedicated icon.
Cancelled casts, other units and portal creation do not qualify. Cast GUIDs
suppress repeated delivery. Without a cast-start location, only a position
sample at most four seconds old may supply the departure; otherwise the event
stays unpositioned. Names come from the client rather than English-name matching.

An in-session leaving/entering-world pair compares observed instance types and
map-continent ancestry. Changes into/out of `pvp` create battleground markers.
Known travel casts retain their own type at arrival. Otherwise, outdoor changes
between continents create ship icons labelled **Cross-continent travel**: this
covers boat/zeppelin crossings but does not establish a vessel or rule out an
unidentified portal. Login/reload and ordinary same-continent loading are excluded.
Departure and arrival are separate events, with trail breaks between them; these
events remain enabled with positional trail recording off. Arrival sampling waits
for coordinates, with a bounded retry window starting after loading completes.
There is no reconstruction of old trips, generic portal-use detection, or arrival
event for a cast which produces no loading transition. Travel types have separate
filters and take priority over ordinary discoveries in grouped map pins.

Dungeon, raid and scenario visits add `instance` events with `instanceAction`
enter/exit, a readable instance name and ID when available. Entry uses the last
observed outdoor doorway position; interior observations retain `instanceType`
and their actual location for timeline details but do not create trail points
or move the outdoor player arrow. Entry/exit breaks prevent connecting a visit
or an exit teleport. The position lookup holds the entrance independently of
search, event and level filters, even when entry precedes the selected dates.
Follow player stays on its outdoor map until an observed exit, then jumps to the
arrival (including a confirmed hearth/teleport out). Same-instance floor loading
does not create another visit. Existing recordings are not backfilled.

The latest unmatched entry restores the entrance after reload inside the same
instance. Login inside without a matching entry records an observed visit with
unknown entrance; the arrow stays unavailable instead of using an unrelated old
point. If the next observation is outside after logout, an exit is recorded at
that observation's time; no exact offline exit time is inferred. No additional
mutable SavedVariables visit cache is required.

Live checks remain required: Hearthstone, cancelled hearth, mage teleport,
Moonglade/recall where available, cross-continent boat/zeppelin, battleground
entry and exit, dungeon/raid entry, floor changes, exit and hearth-out, long loading
screens, login/reload, missing entrance coordinates, and recording disabled.

Journey rendering uses pooled texture quads with shared cross-sections and shallow
quadratic elbows. This avoids gaps and doubled opacity from square native line
caps at connected corners. Vertex offsets form the ribbon; pixel snapping is
disabled so shared vertices remain coincident. Geometry is rebuilt on zoom with
a two-UI-pixel visible stroke (canvas thickness is divided by zoom). The existing
2,048-piece budget and identity-based recording gaps still apply. Tests cover
shared edge vertices, bounded joins, zero-length edges, separate gaps, 1x/4x zoom
width and pool cleanup. A software geometry preview was inspected; native texture
rasterization still needs a live reload and zoom check.
Check overlapping routes at several slider strengths and scrub back to confirm that
historically recent travel becomes bright again.

1. `/reload`; open all eight tabs. Check the pocket-watch icon, tab fit, parchment, text size,
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
   First inspect the acceptance: all visible reward choices should be listed.
   Accept immediately with uncached items, then select a different quest and wait
   up to ten seconds. Verify rewards recover without changing that selection or
   the recorded acceptance time/location. Test reload during capture, an immediate
   abandon/turn-in, and an unresolved cache that retains an explicit partial result.
   Check quality colours, icons, hover tooltips, coloured g/s/c prices, cached item
   loading and long-list scrolling. The completion must not list unchosen options.
4. Open a reward dialogue and cancel it; it must not complete a quest. Cause a
   failed reward request (for example full bags) and retry. Check there is still
   one confirmed completion with the final observed choice, not an attempted choice.
5. Discover entries in every existing journal between quest acceptance and turn-in.
   Check Annals labels and icons, then Open linked journal. Test Gathering selection,
   an Atlas entrance, an Angling record and a Lore writing. Delete a linked entry;
   its Annals event must remain readable and navigation must fail gracefully.
6. Walk a path with turns, ride a mount and a flight path, then stand still for
   ten minutes. Compare Storage point counts. Turn Journey off and continue a quest;
   first choose No and verify recording continues, then Yes and verify events
   continue while trail counts stop. Turn it back on and verify an immediate
   resumption with a break. Leaving the page with the question open must cancel it.
   Open/cancel a taxi map (no departure), then take a flight: one flight-master icon
   should appear at departure. Fly through several named subzones and across a zone
   border; the continuous observations should form a connected path on parent maps.
7. Cross zone/continent borders, enter/exit a cave or micro map and an instance,
   hearth/portal, die/release/resurrect and board/leave transport. Check separate
   segments and absence of lines across unobserved travel. Pay special attention to
   micro-map coordinate labels and small same-map discontinuities.
   During a dungeon/raid visit, the arrow must stay at the outdoor entrance even
   after interior deaths/discoveries and a reload. Scrub a range beginning inside
   the visit, change event/search filters, then follow through an exit or hearth
   out; no interior path or connecting exit line should appear. A fresh login
   inside with no recorded entrance must show an unknown entrance, not a guess.
8. Select dates and a level in Journey, choose each historical map, scrub to
   both ends and several midpoints. Check exact sample times, progressively visible
   geometry, event tooltips, overlapping marker cycling and dense-range notice.
   Check the black slider track. Navigate up to continent and world maps; the route
   and event markers should shrink into the correct locations and still scrub.
   Open another journal and return; no live player arrow should appear in history.
   Play at 1x and 64x; the arrow should move continuously between samples and hold
   across a recorded rest or loading gap. Check Find player from another zone and
   a parent map with all marker filters off: it should pause, retain the time and
   reveal the historical arrow. Test no prior position and a position at map edges.
   Enable Follow player and play through a zone border, cross-continent crossing,
   hearth and same-zone teleport at 1x and 128x. Check map changes, retained zoom,
   gap holds and direct arrival jumps. Disable follow during playback to pan
   manually. Now / reset must clear all time/event/level filters and select now.
   Search a partial quest name, a reward name, `sword`, and `sword Westfall`.
   Verify unchosen acceptance offers, chosen completion rewards and item tooltip
   text can match. Check cold-cache item loading, empty results, the red clear
   button, Now / reset, search focus on reopening, and filtering Journey markers
   while Follow player continues to track unfiltered historical positions.
   Check Choose zone above the map's top left. Open/close
   Legend and compare its icons/arrows/line swatches with the map, including after
   changing contrast. Check Full / 3 hours / 1 hour / 15 minutes at both date ends.
   Check Legend and Follow player glow only while active, labels remain stable,
   and Legend closes with its own button. Check instance entry/exit arrow badges,
   left-pane icon shadows and larger reward names without ×1 at each text-size
   setting; stacked rewards must still show their counts.
   Check the standard 3 × 661 divider and matching pane widths in both Timeline
   and Journey. Find player and Follow player should sit together left of Legend
   without overlapping Choose zone. Revisit a flight departure at least four
   times: its tooltip should show the newest three events and an older-event
   count, while repeated clicks still reach every event. Discovery tooltips
   retain the Fieldbook discovery label without the quest-causation disclaimer.
   Verify Journey stays visible on the right while the left-pane Show detail
   toggle opens/closes a detail overlay over the timeline. Its label stays fixed
   and it glows only while details are visible; playback continues and closing
   restores timeline pagination and selection. Check long rewards scroll within
   the left pane. Selecting a timeline event should pause and seek to its time/map. Check the four moved
   controls in the right pane and hover contrast for its explanation.
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

### Mounted trail validation

New trail headers retain a mount tier inferred from the mounted player's reported maximum ground speed (including while stationary): 60% uses Rare blue (#0070dd), 100% uses Epic purple (#a335ee). Mount changes start joined chunks; flight green takes priority. Older recordings remain readable without invented mount observations. The client speed value includes movement modifiers, so verify classification in-game with both mount tiers, speed bonuses and slows, along with mount/dismount transitions.

Verify the mirrored map filter opens at its own button and stays highlighted with the original. Check both timeline and long-detail scrollbars, custom decimal speeds, 256x playback, and the 15-minute trail cutoff while scrubbing and playing.
