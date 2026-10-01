# Traveller’s Atlas — v0.12.1 (unreleased)

## Automatic survey exclusions (0.16.2)

Automatic crossing and interior sampling pauses when `UnitOnTaxi("player")`
or `IsFlying()` reports flight. Missing optional APIs are tolerated; errors or
secret results from an available flight API pause recording until readable.
Classic capital map IDs 1453–1458 and their child maps are excluded using
bounded map ancestry checks. This covers Stormwind, Orgrimmar, Ironforge,
Thunder Bluff, Darnassus and Undercity without treating all inns as cities.
No new polling, saved-data migration or deletion is introduced. Every skipped
observation clears crossing continuity. Manual survey points remain deliberate
and available under their existing spacing rules.

Focused mocked tests cover taxi/flying suppression, resumed ground crossings,
capital maps and children, ordinary resting areas, preserved evidence and
manual points. Actual Forever flight signals and capital map IDs still need
live verification: take a flight across sub-zone boundaries with the Atlas
closed, confirm no new points, land and confirm sampling resumes without a
bridging crossing; repeat across capital districts, then visit an ordinary inn.
Check an existing capital survey remains visible and a manual point still saves.

Current storage scope: the global Account-wide tracking option selects this
section's account or character journal. The original per-character SavedVariable
is preserved. Earlier per-character implementation notes below describe the
original section boundary; see [account tracking](ACCOUNT_TRACKING.md) for the
current migration and storage contract.


## Scope and review baseline

Implementation began on `main` at
`d0aafda624c451d552cec39ff67ec64ecf6cbe5c` on 2026-09-27. `git status --short`
was empty: no staged, unstaged or untracked repository changes. All work remains
uncommitted. No commit, push, tag, package, release or publication was performed.

The initial full runner passed 41 test files. The final full runner passes 42
test files, including 17 Atlas tests, and compiles 46 runtime files as Lua 5.1.
Manifest completeness, binding XML and TOC/README/changelog version checks pass.
The pinned `lupa==2.8` dependency was already available. Python is not on PATH on
this host, so the runner used the bundled executable with the required arguments:

```powershell
& 'C:\Users\Spinkler\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -B -X utf8 tests/run_tests.py
```

These are automated logic/widget-host checks, **not in-game visual checks**.
No live Forever validation was performed for this implementation.

The v0.12.1 follow-up addresses a user-reported live error on map-layer hover.
The regression test first reproduced the invalid boolean alpha argument, then
passed after moving wrapped description text to `GameTooltip:AddLine`. It covers
all eight layer checkboxes and tooltip dismissal. The fix still needs live retesting.

The v0.12.12 follow-up fixes discovery-row hover errors, including routes. The
Atlas sanitizer now returns only its cleaned string, not `gsub`'s additional
replacement count. Regression coverage checks return arity, sanitization and row
hover/dismissal for all eight categories; live retesting is still required.

The v0.12.13 follow-up restores map icons for positioned Route / Passage records
without itinerary stops. Their own recorded position supplies an unnumbered
marker, selected or unselected, on the matching map with Routes enabled. No
positions or stops are generated. Once stops exist, itinerary rendering applies.
Regression coverage reproduces the missing marker and checks selection, layer
visibility, map boundaries, unpositioned records and adding a real stop.
The same patch replaces the unavailable `INV_Misc_Campfire` texture with
`Spell_Fire_Fire` for Camp / Settlement markers and index rows. A simulated
missing-asset regression verifies both render an icon, with layer hiding intact.

In v0.12.15, the Atlas adds a live two-decimal player coordinate readout, labeled
when the player is on another map. Coordinates remain available without facing
or map art; unavailable positions never leave stale numbers. Standard zone maps
are 25% larger, with a 578-pixel width cap for unusually wide assets, and the
details/actions are reflowed within the unchanged 960 × 740 shell. The persistent
layer reminder and selection asterisk are removed. All 44 test files pass;
native visual/layout verification remains a live-client check.

## File ownership and integration

| File | Responsibility |
| --- | --- |
| `AtlasJournal.lua` | Central categories/icons, validation, per-character schema, CRUD, search, route geometry, expedition associations |
| `AtlasMap.lua` | Client map catalogue, owned tile/exploration textures, bounded grouped pins, selected-route lines, map picking |
| `AtlasReferences.lua` | Read-only source adapters and existing Bestiary navigation |
| `AtlasReports.lua` | Versioned payload construction, normalization, validation, literal serialization, complete preview, detached recipient staging |
| `AtlasUI.lua` | Atlas-only use of shell labels/buttons/edit boxes, parchment panels, text entry and scrolling |
| `AtlasBook.lua` | Registration, lazy page construction, map/index synchronization, layers, selectors and browsing lifetime |
| `AtlasEditors.lua` | Places/entrances, routes/waypoints, expeditions and connection pickers |
| `AtlasReportUI.lua` | Persistent report selections, private-note opt-ins, expedition excerpts and preview |
| `AzerothFieldbook.toc` | Load Atlas modules; register `AzerothFieldbookAtlasDB`; version 0.12.1 |
| `AzerothFieldbook.lua` | One additive initialization call after gathering and before future sections |
| `FieldbookSections.lua` | Remove only Atlas's placeholder; retain the other four definitions verbatim |
| `README.md`, `CHANGELOG.md`, `AGENTS.md`, `tests/ARCHITECTURE.md` | Current-version, feature, integration and ownership documentation |
| `tests/atlas_test_harness.py`, `tests/test_atlas.py` | Synthetic-only data and real Atlas callback coverage |
| Existing tab/gathering tests | Register the actual Atlas in page-switch regressions; retain checks for all four remaining wishlist pages |

No Bestiary, Gathering, shared shell, map helper, tracking, sharing, window,
scrollbar or source-page implementation was edited. The shared window remains
960 × 740 with the existing right-side tabs. Atlas panels are children inside
the content frame, not independent windows competing for auxiliary placement.

## Client/map approach

The client target remains Forever (`## Interface: 16001`). Atlas follows the
already-used `CreatureLocations` and gathering location-window capabilities:

- `C_Map.GetBestMapForUnit`, `GetMapInfo`, guarded `GetMapChildrenInfo` for map
  identity and continent/zone navigation. Recorded map IDs remain available if
  the catalogue API is missing. Labels are display metadata, never keys.
- Guarded `GetPlayerMapPosition` for explicit Add Discovery/current-position
  actions. No position is invented on failure. Ambiguous current-player `0,0`
  is treated as unavailable; explicit validated map/manual `0,0` is permitted.
- `GetMapArtLayers`, `GetMapArtLayerTextures`, and optionally
  `C_MapExplorationInfo.GetExploredMapTextures`. All assets are drawn in Atlas
  texture pools. No World Map frame is accessed, reparented or controlled.
- Map clicks convert cursor pixels through the frame's effective scale and
  actual letterboxed tile dimensions. Picking requires usable map artwork;
  manual map/coordinate editing and unpositioned notes remain available without it.
- `Frame:CreateLine`, when usable, draws only consecutive visible, positioned
  stops on the same map. Gaps, hidden stop categories, deleted places and map
  transitions break lines. Numbered markers/itineraries work without lines, and
  the caption states that limitation. This is not terrain-aware pathfinding.

The player arrow samples readable position/facing at most ten times per second
while the map is visible, without recording movement or refreshing the journal.
It hides on other maps or missing data and stops updating when hidden. Map art
refreshes when a map is selected or Atlas is reopened. At most 128 base textures, 256
exploration textures, 192 marker groups and 99 lines are allocated. Overlapping
icons share a tooltip and cycle records on clicks. Crowded maps announce the
192-group cap; the complete index remains available and selected groups get
priority. Unselected routes have an itinerary anchor; selecting one expands its
numbered stops. A gold border, larger pin and list caret identify selection without
depending solely on colour. Hidden pins are hidden frames with no active hits.

| Category | Icon under `Interface\Icons\` |
| --- | --- |
| Cave / Entrance | `Spell_Shadow_Twilight` |
| Ruins | `INV_Misc_StoneTablet_01` |
| Route / Passage | `Ability_Tracking` |
| Crossing | `INV_Misc_Foot_Kodo` |
| Useful Place | `INV_Misc_Spyglass_03` |
| Camp / Settlement | `Spell_Fire_Fire` |
| Landmark | `INV_Misc_Map_01` |
| Other | `INV_Misc_QuestionMark` |

## Persistence and references

`AzerothFieldbookAtlasDB` schema 1 holds `records`, `expeditions`, `settings`,
an ID counter and an optional `reportDraft`. Schema 0/unversioned initialization
is additive and idempotent; unknown fields and invalid individual records are
retained. Unsupported future schemas are preserved and exposed read-only, with
no downgrade. It never migrates another SavedVariable.

IDs (`pN`/`eN`) are monotonically allocated locally. Coordinates are integer
hundredths of a percent (0–10000) relative to an explicit numeric map ID.
`Get` returns validated detached copies. Names/labels/references are plain text
with no WoW pipe markup or command interpretation; notes allow newlines/tabs.
Limits: 5,000 places/routes; 1,000 expeditions; 100 stops, related IDs or external
references per entry; 64 expedition zones; 160-byte names; 8,000-byte notes/access
text. Timestamps use seconds. These are storage limits, not completion targets.

Deleting an entry requires an Atlas confirmation. Related links, route stops,
expedition associations and report draft selections deliberately remain unresolved,
with removal available in their editors. No source record or related record is
silently deleted or rewritten. Draft previews reject missing selected entries
until removed; deleted route stops retain an explicit missing label.

Recorded/Reported provenance and explicit `explored` status are independent.
Edits preserve an existing knowledge source. Saving a position never marks a
place explored. The namespace is outside Bestiary account tracking, resets,
backups and sharing; this version does not add Atlas backup/transport features.

Adapters register `{title, list, resolve, open?}` by section ID. `list`/`resolve`
return only detached `{section,key,name}` references. Bestiary uses its visible
`List`/`GetCreatureName` accessors and opens through the existing
`ShowSection('bestiary', {creatureID=...})` context. Gathering exposes existing
observed identities and names, without notes, claims, counters or an authoritative
Atlas copy. It has no supported entry-open interface, so Atlas shows a contained
summary. Missing/unknown targets retain their saved display name. Future sections
may add Atlas-side adapters when real source records exist; none are invented.

## Regional report contract

`AtlasReports.Build(journal, draft, sourceName)` selects exactly the requested
records and returns a normalized envelope or a useful error. Draft shape:

```lua
{
  title = "Title", region = {kind="zone", mapID=123, name="Observed zone"},
  -- Or region={kind="selection",name="A named selection"}.
  records = {[localID]=true}, notes = {[localID]=true},
  expeditions = {[expeditionID]="explicitly selected excerpt"},
  includeReferences = false,
}
```

Choosing a zone resets discovery selections; check the wanted entries. A route
includes stop names/positions across its zones, as stated before selection. It
does **not** include any stop's private notes unless that place is independently
selected and opted in. Place note inclusion covers notes, access and interior
details. Expedition selection initially includes an empty excerpt; copying the
full journal requires an explicit action. Cross-section display references are
also an explicit opt-in. The draft does not modify source journals.

Envelope fields: `format='AFB-ATLAS'`, `version=1`, `title`, `region`, `source`,
`created`, `records`, `expeditions`. Each record uses an envelope-local `rN` ID;
expedition IDs are envelope-local `eN`. Related links and route `ref` values may
refer only to included `rN`s. A stop whose source place is not selected becomes a
name/location snapshot with no transferable local identity. Cross-section keys
are source-type hints plus display context, not authorization or proof that the
receiver knows that target. A sender name in `source` is **not authenticated**.

`Normalize` constructs detached, whitelisted data; `Validate` returns status and
error; `Encode`/`Decode` support deterministic `AFBA1:` length-prefixed literals.
The fixed Bestiary codec cannot represent this schema, so Atlas uses its safe
length-prefix principle in an isolated codec. It never calls `load`, `loadstring`
or executes payload text. Limits: 128 KiB total, 200 records, 40 expeditions,
100 stops/references per record, bounded string lengths, numeric/map/coordinate
ranges, depth 12 and 30,000 decoded nodes. Unknown fields/versions, sparse arrays,
duplicate IDs/keys, invalid local links, metatables, malformed lengths and trailing
data fail. `Preview` prints all included notes, source claims, stops and references.

`StageReported` validates and returns detached candidate records with
`provenance.kind='reported'`, source attribution and `explored=false`, retaining
original knowledge attribution and report-local links separately. It performs
**no database writes**. A future recipient workflow must allocate fresh IDs,
build a report-key-to-local-ID map, and resolve related/route/expedition links in
a second pass. Match candidates by map/category/position/name for user review,
never by sender database ID. Preserve original report attribution as metadata;
do not overwrite personal observations, expose an undiscovered source entry or
copy sender exploration assertions. Missing external references stay summaries
until the recipient has an appropriate source record.

Future transport should bound bytes before decode, call `Decode`/`Normalize`,
obtain explicit recipient selection/consent, then reconcile staged candidates.
Authenticated transport identity, if available, must be separate from claimed
source text. No Send/Import controls, delivery, inbox, automatic import or points
mechanics are implemented or implied by this release.

## Automated coverage

`test_atlas.py` covers CRUD/reload/IDs/migrations, unsupported-schema preservation,
coordinate rejection and unpositioned records, explicit exploration/provenance,
all search fields/scopes, independent layers, route order/map gaps/hidden stops,
deleted references, expedition associations, read-only adapters and supported
navigation, note opt-ins/excerpts, report-local IDs, serialization round trips,
invalid/oversized/malformed payloads and detached recipient staging. UI tests
exercise real control callbacks for editing, map picking, synchronized/cycling
pins, layer reveal, routes, connections, expedition linking, previews, saved
drafts, page lifetime and frame-pool reuse. Synthetic fixtures never ship as data.

Existing tab/gathering tests now register the real Atlas and still verify the
other pages' state, native tabs, tracking while hidden, entry actions, unchanged
wishlist copy, shell dimensions and supported scale/screen-fit behavior.

## Remaining live Forever checklist — all unperformed

- [ ] Compare fonts, gold headings, borders, note insets, buttons, checkboxes,
  hover/selection, scrollbars and empty states with Bestiary/Herbs & Minerals.
- [ ] Check 50/75/100/125/150% preferences at 1920×1080, 1280×720 and 1024×768;
  readable controls/long names, tab access, keyboard focus and auxiliary placement.
- [ ] Verify all eight native icons, map art and explored overlay availability;
  letterboxing, scale-correct coordinates and click-to-place at edges/centre.
- [ ] Verify the player arrow's position/facing while moving, same-map visibility,
  missing-data fallback and disappearance when leaving the Atlas map.
- [ ] Capture current position outdoors and inside a cave; keep interior context
  distinct from the entrance. Check unavailable coordinates/art and later editing.
- [ ] Check pin/list selection, overlaps, selected border/caret, all eight toggles,
  hide/show all, hidden-layer reveal, no hidden hit areas, and the crowded-map cap.
- [ ] Search every field under both scopes; open a result from another zone;
  browse continents/maps; confirm movement does not force Current Zone.
- [ ] Create/edit/delete a place and a cave; assert/unset Explored; reload and
  inspect per-character persistence, filters, IDs and reported-source retention.
- [ ] Add/reorder/remove route places and waypoints; check numbered stops, lines
  or honest line fallback, hidden stops, missing stops and multi-zone transitions.
- [ ] Create/browse/edit/delete long expedition notes, associate/remove multiple
  zones and discoveries, link to an existing note and open discoveries from it.
- [ ] Search/link/unlink both source adapters; open a Bestiary entry; inspect
  gathering summaries and missing targets; confirm source data is unchanged.
- [ ] Prepare zone/named reports; explicitly include/exclude notes and excerpts;
  inspect every preview field and reload the saved draft. Check missing selections.
- [ ] Leave/reopen Atlas with filters, scroll positions, a selected zone/entry,
  open editor and unsaved text. Close/reopen the shell; verify no lingering Atlas
  controls, tooltip, keyboard focus or overlays on another page.
- [ ] Confirm existing Bestiary open-entry actions, gathering model/map/note UI,
  background tracking, resets, backups and sharing retain their existing rules.

The live checklist is the remaining acceptance work. Automatic cave cartography,
safe-path routing, Atlas backups, transport, recipient reconciliation UI and any
completion/reward system are outside this release.


## v0.12.16 weather observations and map polish

Maps are 99% of the v0.12.15 dimensions. The four recovered pixels increase
selected-entry detail height. The map shadow added in v0.12.16 was removed in
v0.12.17. Twelve index rows remain with closer spacing.

Observed Weather lists accumulated types for the selected map. The Atlas observes
the player's actual map on world entry, zone changes and WEATHER_CHANGED, storing
one first-observed timestamp per weather type/map in its own character database.
It works with the Atlas closed, never infers Clear from unavailable data, and
respects future-schema read-only protection. Weather is not shared in reports.

API contract checked against matching Blizzard client documentation:
[WeatherScriptDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_APIDocumentationGenerated/WeatherScriptDocumentation.lua)
and sibling WeatherConstantsDocumentation.lua (types 0–4).

Live checks: observe rain, browse another zone, return and reload to verify history;
confirm observations while Atlas is closed; check lower details at the
normal UI scale. Automated tests cover map separation, accumulated types, reload,
API failure, future schemas and absent artwork.

## v0.13.15 — self-discovered sub-zones

`AtlasSubzones.lua` adds an independent `subzones[mapID]` crossing array to
Atlas schema 1, plus `settings.showSubzones` (off by default). Unknown fields
and future schemas remain untouched. Sub-zone evidence is not a discovery,
route, expedition, reward, field-report entry or another section's data.

An event observer handles ZONE_CHANGED, ZONE_CHANGED_INDOORS and world/map
transitions. A 0.25-second sampler maintains only a transient previous position
and also catches readable name changes between events, even while the book is
closed. Blank GetSubZoneText falls back to GetRealZoneText. Each crossing saves
map ID, from/to labels, old/current integer coordinates and observation time.
Missing/invalid labels or positions break continuity; loading screens, map
changes, gaps over two seconds and jumps over 3% of the map are not joined.
Very short teleports without a loading event cannot be distinguished from
movement; this is an observation heuristic, not an authoritative boundary API.

Storage limits: 256 maps, 128 named areas and 4,096 samples per map. Repeated
same-direction crossings within a 0.25% cell coalesce, retaining the first
sample; opposite directions and different neighbours retain separate evidence.
Reaching a limit preserves existing evidence and stops adding that capacity's
new samples. No full movement trail or session baseline is saved.

Geometry is built only from observed crossing brackets. The midpoint of each
bracket contributes to both areas' convex hulls; fewer than three non-collinear
points show dots/names only. An 80 by 80 grid classifies cells inside these hulls
using the nearest observed side position, accelerated with per-area spatial
trees. Horizontal runs become translucent, click-through texture strips.
Unobserved exteriors stay blank, but convex estimates can bridge concavities,
islands or holes. They are explicitly labelled estimates, not exact game
borders. A deterministic greedy colouring uses both observed adjacency and
rendered shared edges, expanding beyond its initial palette when necessary.

The checkbox occupies the existing map-layer header gap without moving existing
controls. Overlay strips, dots and non-overlapping labels reuse bounded pools,
scale/pan with the map canvas, and hide when disabled or map art is unavailable.
Hover includes from/to, both coordinates and time near a crossing. Model caches
use map/revision keys and dimensions; background logging does not build hidden
geometry. The Almanac's shared map renderer has no sub-zone state or controls.

`tests/test_atlas_subzones.py` covers logging, reloads, reverse/deduplicated
crossings, blank names, missing data, map/loading discontinuities, future-schema
protection, hidden background events, inferred geometry, colour conflicts,
map isolation, unchanged layout, tooltip evidence, pool reuse and storage caps.
A synthetic 4,096-crossing stress case rebuilt geometry in about 0.11 seconds on
the development host after spatial indexing (not a live-client frame-time claim).

Live Forever checks remain: walk several different sides of a sub-zone, inspect
from/to positions, reload, toggle the layer, zoom/pan, enter a cave and use a
loading-screen teleport. Check colour readability and estimated border accuracy
at the normal UI scale. Automated checks do not verify native visual rendering.

Validation: the full runner passes all 46 test files and compiles 54 runtime
files as Lua 5.1. Manifest, bindings and version 0.13.15 checks pass.


## v0.13.16 — sub-zone display controls and smooth contours

Sub-zones and Sub-zone labels occupy the fifth column of the existing two layer
rows. Category spacing tightens to 107 pixels; the map and lower content keep
their anchors and dimensions. The header holds two compact native sliders with
dark styled tracks: Label size (8–24, default 12) and Brightness (20–100%, default
100%). Show all / Hide all retain their category-marker scope.

Labels and shading are independent. Existing enabled overlays migrate with
labels enabled; fresh journals start with both hidden. Label font size, clipping
bounds and overlap spacing update immediately. Settings are per character under
showSubzoneLabels, subzoneLabelSize and mapBrightness. Invalid numeric settings
use defaults, and unsupported future schemas remain read-only. Map brightness
modulates only base and exploration textures, preserving overlays and markers;
the Almanac does not inherit these Atlas settings.

The earlier 80-cell stepped renderer is superseded. A 128-cell contour mesh
samples corners and centres; boundary intersections are refined eight times,
then rendered with native triangle vertex offsets. Interior horizontal strips
remain merged. Triangles partition boundary cells without overlapping fills,
and native winding follows the existing Bestiary map renderer. Dense evidence
adaptively reduces the mesh until at most 6,000 boundary triangles are needed;
even reduced meshes use interpolated edges rather than square cell boundaries.
The pool stays bounded, and geometry is reused when only visibility, text size
or brightness changes. Round crossing markers replace square point textures.

The palette uses saturated cyan, magenta, lime, violet and other accents with
40% fill opacity. Observed and rendered neighbours still get different colours.
These are still inferred perimeters: rendering improvements do not create more
observations or make the geometry authoritative.

Regression coverage includes label-only and shading-only modes, size changes,
base/exploration brightness without overlay dimming, settings/reload/migration,
unchanged map geometry, contour coverage and fractional edge precision, native
triangle winding, contrasting neighbour IDs and bounded dense geometry. Live
Forever checks remain for control readability, slider styling, map contrast
across terrain types, and contour appearance while zooming and panning.

Validation: all 46 test files pass, including eight sub-zone tests. All 54 runtime files compile as Lua 5.1; manifest, bindings and version 0.13.16 checks pass. Native visual checks remain in-game.


## v0.13.17 — isolated crossing dots

Samples now display dots only while neither of their associated sub-zones has
rendered fill geometry. Once a crossing contributes to an area's shaded hull,
its dot disappears, including interior observations already incorporated into
that hull. Unrelated unshaded samples remain visible. Coverage is derived from
the final strips/triangles, so sparse or collinear observations stay as dots.
Crossing records and hover access are preserved.

Dots measure three UI units across after map zoom, using inverse-zoom texture
sizes. Zoom changes update their size immediately without rebuilding geometry.
Regression coverage verifies isolated dots, incorporation into a boundary,
unrelated samples, zoom in/out, pooled texture reuse and retained evidence.
Native visual confirmation remains an in-game check.

Validation: all 46 test files pass, including nine sub-zone tests; 54 Lua 5.1 files, manifest, bindings and version 0.13.17 checks pass.


## v0.13.18 — smaller sub-zone labels

The label-size slider now spans 2–24, retaining its default of 12. Rendering and
saved-setting validation accept sizes below 8, so close-up map views can use
smaller text without reverting on refresh or reload. The existing display-control
regression exercises size 2, its font/label bounds and persistence. Map zoom
continues to scale labels; no layout or observation behavior changes.

Validation: all 46 test files pass, including the size-2 rendering and persistence checks; manifest and version 0.13.18 checks pass.

## v0.13.19 — crossing cost, reduced detail and ten-yard spacing

The old crossing callback synchronously rebuilt the complete geometry and
reconfigured its texture pool. A synthetic baseline on this host measured
crossing redraws of 19.7 ms (4 collinear samples), 309.1 ms (128 scattered
samples), and 789.7 ms (4,095 scattered samples). Populating the old deduplication
index also copied and validated the history in that callback: the largest cold
capture took 11.7 ms. These are Lua/widget-host measurements, not native FPS.

Recording now reads only the player's map ID, position, sub-zone name and clock.
It reuses its previous-position table, caches map dimensions and name counts,
and uses a spatial index instead of copying history during a crossing. Indexes
warm cooperatively; observations arriving meanwhile queue with their original
coordinates and timestamps. PLAYER_LOGOUT flushes remaining queued records
before SavedVariables are written. Unsupported schemas are never compacted.

Where C_Map.GetMapWorldSize supplies usable dimensions, samples of the same
unordered border pair within 10 yards of retained evidence coalesce. Distances
use both axes' actual map dimensions. Different neighbours and maps remain
separate; the earliest retained sample keeps its direction, bracket and time.
Existing rows are thinned when indexed on visiting/displaying their map. Only
validated redundant samples are removed; unknown metadata and invalid rows
remain. Unavailable dimensions retain the prior normalized-coordinate fallback.

A shared coroutine worker targets 1 ms per frame across index, mesh and widget
work. A bounded operation fallback applies without the profiling clock. Bounds,
scalar queries, cooperative merge sorting and shared KD-tree scratch storage
reduce work/allocation; empty or collinear hulls skip rasterization. The mesh
now starts at 64 instead of 128, with at most 3,000 boundary triangles. Refined
triangle edges remain; new snapshots reuse the last workable resolution unless
thinning substantially reduced the data. Revisions invalidate only their map.

Two non-interactive native frames reuse bounded texture pools. The completed
frame remains visible while the hidden frame is prepared, then they swap in
one publication step. Updates arriving mid-build queue a subsequent snapshot
without constantly restarting work. Hidden/disabled/changed-map requests cancel
stale work. Display-only edits reuse geometry; unchanged hover positions reuse
the tooltip. Completed and cancelled coroutines release their temporary data;
only the two buffers retain completed meshes. Dense updates can take several
frames to complete, without charging their entire build to a single crossing.

Reproduce the synthetic profile with:

```powershell
& 'C:\Users\Spinkler\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -B -X utf8 tests/benchmark_atlas_subzones.py
```

Observed capture times were 0.008–0.038 ms; worker p95 was 1.15–1.40 ms and the
maximum was 2.03 ms in the dense stress cases. The budget is a cooperative target,
not a guarantee about native calls or GC. A read-only, in-memory check of the
available saved 18-sample Atlas overlay took 2.76 ms of total worker time across
five worker frames (maximum 1.02 ms); the map request itself took 0.095 ms.
No character SavedVariables file was modified by these checks. Runtime thinning
uses the actual client map dimensions after reload; synthetic/host timing cannot
establish real game frame rates.

Regression coverage checks ten-yard thresholds, reverse crossings, aspect-ratio
scaling, separate maps/neighbours, old-data thinning, reload idempotence,
metadata/invalid-row preservation, queued capture/logout, future-schema safety,
cooperative publication, arrivals mid-build, map changes, hiding/reopening,
per-map invalidation, display-only reuse, failed-job suppression, cancelled
snapshot collection and stable native-pool counts. Live verification remains:
reload, cross several borders with the Atlas both open and closed, inspect
retained records/shading, and compare frame-time behavior during crossings.

Final validation: all 46 test files passed, including the 14 sub-zone regression
tests; all 54 runtime Lua files compiled under Lua 5.1. Version metadata agrees
on 0.13.19.

### v0.13.26 — grouped controls, optional points and distinct colours

The existing header space now contains a bordered Sub-zones group with Shading,
Points, Labels, Label size and Brightness. Marker categories now appear in the
Map Layers dropdown alongside it; the map dimensions and anchor are unchanged. Points is independent
of the other two layers, shows only isolated crossovers, preserves constant dot
size at every zoom and retains the existing suppression of incorporated samples.
New journals default to hidden points; upgrading an enabled overlay preserves its
visible points, and an explicit saved opt-out survives reload. Recording is
unaffected. The rendering cache includes point visibility, so toggles reuse the
mesh and changes during asynchronous painting cannot publish stale point settings.

Regression coverage exercises points-only display, both reusable buffers, toggling
during queued painting, unaffected shading/labels/evidence, persistence and upgrade,
and continued recording with points hidden. Native layout inspection after reload
remains a live-client check.

The control group's right edge matches the zone selector at x=922; Label size
has enough caption width without moving its slider or value into the border.

Colours now come from a larger generated pool, excluding dark or muddy candidates.
All areas on the displayed map receive unique colours up to the 128-area cap.
Each new assignment maximises its minimum Oklab distance from all colours already
assigned; current colours are preserved across updates to the same map. The
candidate pool is cached, distances update incrementally, and selection yields
through the existing worker checkpoints. Cold builds remain deterministic.
The conversion follows the public-domain [Oklab reference](https://bottosson.github.io/posts/oklab/).
Labels explicitly use `OUTLINE`, without `MONOCHROME` or `THICKOUTLINE`.
Label size defaults to 4 in both the slider and renderer; valid saved sizes remain.
Regressions cover unique RGB candidates, distinct colours at the area limit,
maximin selection, retained assignments and font flags after resize/buffer swaps.

Map Layers uses the same native context-menu API as the zone selector, with one
checkbox per discovery category and Show all / Hide all actions. Returning
`MenuResponse.Refresh` keeps the menu open while checking multiple options.
Regression coverage verifies independent checkbox state, persistence, bulk actions,
Reveal layer, and unchanged discovery records and sub-zone visibility settings.

Final validation: all 47 test files passed, including 29 Atlas and 17 sub-zone
tests; all 55 runtime Lua files compiled under Lua 5.1, with version 0.13.26.
The synthetic crossing benchmark still completed recording in 0.008–0.061 ms
and worker slices at a maximum of 1.85 ms in this run; these are test-host timings,
not native frame-rate measurements.

### v0.13.27 — matching selectors and separate sub-zone rows

Zone and Map Layers now share a 306-unit width. The Sub-zones group fills the
space beside them, extending from y=-91 to -198 with its right edge still at
x=922. Shading, Points and Labels occupy separate rows; Label size remains
alongside Labels. The map dimensions and anchor are unchanged. The existing
zone-selection test now checks matching selector widths while continuing to
verify map navigation without creating records.

Validation: all 47 test files passed; all 55 runtime Lua files compiled under
Lua 5.1 and version metadata agrees on 0.13.27. Native layout remains a live-client
check after reload.

### v0.13.28 — interior coverage and two-line labels

Readable positions with map dimensions seed one interior observation immediately,
then attempt another after moving 100 actual map yards from the last sampling
anchor. Separate spatial buckets per map and sub-zone reject revisits within
100 yards of retained interior evidence. The existing ten-yard border-pair filter
is unchanged. Missing dimensions disable interior capture without disabling
crossing capture. Invalid positions and loading events retain their existing
guards; no travel path or border is inferred across discontinuities.

Interior rows share the bounded per-map sample list but are explicitly typed as
`{kind="interior", mapID, name, x, y, at}`. They do not carry fabricated from/to
names or positions. `Crossings` still returns crossing events only; `Samples`
returns detached, validated evidence of both types for rendering. At most 1,024
interior samples fit inside the existing 4,096 total-row cap, reserving capacity
for borders. Area and map limits, future-schema read-only behavior, cooperative
indexing, compaction and pending-data logout flushing remain in effect. Existing
rows and unknown metadata survive. Interior points contribute only to their named
area's hull and anchors; they do not invent adjacency. Tooltips distinguish types.

Labels measure their native text width and use individual collision bounds. If
a single line is too wide or overlaps an existing label, the renderer measures
word-boundary splits and tries the narrowest balanced two-line form before hiding
the label. Splits preserve UTF-8; unbreakable names that cannot fit are hidden.
Labels stay clamped inside the map and retain the chosen size and `OUTLINE` flag.
Measurement/placement yields through the same worker and reuses font-string pools.

Map Layers now sits at y=-174 immediately above the map; Atlas Zone stays at
y=-91. The Almanac zone selector is also 306 units wide. These layout edits do
not change map dimensions, sample controls or journal data.

New regressions cover initial and 100-yard sampling, asymmetric map dimensions,
stationary/revisit/reload deduplication, independent maps and names, hull expansion
without invented borders, hidden capture, interior caps leaving border capacity,
pending interior logout persistence, malformed rows, honest hover descriptions,
detached samples, measured short labels and width/collision-triggered two-line text.

Atlas Map Layers and both journals' zone buttons share a menu-button helper with
native `ChatFrameExpandArrow` artwork and reserved label space, replacing the
typed `v`. A black copy beneath each arrow, offset one unit down and right, adds
a drop shadow. The full button retains its original menu click handler.

Validation: all 47 test files passed, including 20 sub-zone regressions, and all
55 runtime Lua files compiled under Lua 5.1 with version 0.13.28. The synthetic
crossing benchmark recorded capture times of 0.009–0.064 ms and a maximum worker
slice of 2.04 ms in this run. These are host timings; native visuals and frame
timing remain checks after reload.

### v0.13.29 — Points reveals all samples

Checked Points renders every validated crossing and interior sample, including
incorporated evidence. It bypasses both coverage suppression and coarse display
cell merging. Unchecked retains the automatic shading presentation: isolated dots
remain and incorporated samples disappear. With both Shading and Points off,
no sample dots appear. Dot visibility invalidation includes shading changes;
both buffers reuse the completed geometry and preserve constant dot size at zoom.

Regression coverage verifies all-sample display with and without shading,
automatic isolated-dot fallback, repeated toggles, zoom and unchanged saved data.
All 47 test files passed, including 21 sub-zone regressions; all 55 runtime Lua
files compiled under Lua 5.1 with version 0.13.29.

### v0.13.31 — map-wide interior spacing

New interior samples must be at least 100 yards from every retained sample on
that map, including other sub-zone names and crossings. A separate 100-yard
spatial grid indexes all retained samples and updates as pending rows commit.
Crossings still use their existing ten-yard border-pair rule. Existing saved
samples retain their previous compaction rules. Regression coverage includes
crossing proximity, different names, exact threshold distances, asymmetric
map dimensions, independent maps, reloads and pending observations at logout.

### v0.13.32 — strict 50-yard interior clearance and native region hover

Interior capture requires more than 50 yards from all retained samples; exactly
50 yards is rejected. A rejected attempt is not a movement anchor. Crossings
keep the ten-yard border-pair rule. Automated coverage exercises 50 and 50.1
yards, crossing proximity, different sub-zone names and queued observations.

The shared Atlas/Almanac renderer uses C_Map.GetMapHighlightInfoAtPosition for
native region shapes, UV cropping and map-relative placement. Reference:
https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedMapDataProviders/MapHighlightDataProvider.lua
Regression coverage checks cursor transforms at zoom, sizing, cropping, missing
APIs, failed API calls, mouse exit, disabled navigation and hidden maps.
Native verification still needed: hover Wetlands on the continent map and each
continent on the world map in both journals; compare glow with the main map,
then zoom/pan and verify placement stays aligned.

### v0.13.33 — hide zone-name areas

The fourth Sub-zones checkbox opts into hiding shading and labels whose name
exactly matches the displayed map's native name (saved selected-zone name is a
fallback when map metadata is unavailable). It persists per character, defaults
off, and does not change point visibility, stored samples, geometry or colours.
Painting and pending-job cache keys include the filtered name. Regression checks
exercise both render buffers, repeated toggles, neighbouring shading, point
visibility, unchanged geometry/data, saved preferences and map-name changes.

### v0.13.34 — redundant interior cleanup

Map Layers and Clean redundant points share the former 306-unit selector span
as two 149-unit buttons separated by eight units. Cleanup operates on the
selected map independently of shading/filter visibility. It removes only valid
interior rows strictly inside their area's convex perimeter. Every hull edge
sample (including collinear samples), crossing, malformed row and other map is
preserved. A candidate whose same-area Voronoi cell intersects another filled
area's hull is retained to preserve overlap classification. Work yields through
the shared worker budget; completion replaces the rows atomically, invalidates
the spacing index and increments the map revision. New samples during work
invalidate the result; read-only journals are rejected. Sparse/metadata-bearing
stores are left untouched. Recording can add fresh evidence on later visits.

Regression checks cover removal counts, repeated cleanup, perimeter/interior
sample distinction, crossings, malformed rows, other maps, read-only stores,
unchanged overlapping-area classification and stale-work rejection.

### v0.13.37 — cleanup diagnostics and overlap refinement

The selector row now uses 130 units for Map Layers and 168 for Clean Redundant
Points, retaining the eight-unit gap and original right edge. Chat reports the
start, sample count, each 64 checked samples and final removal/retention counts.
Retained counts distinguish perimeter/insufficient-hull evidence, overlap-boundary
anchors, cross-over observations and other records. Errors and concurrent-data
rejections also appear in chat. Overlap protection clips the potential region
where removing the candidate would allow a rival anchor to beat all remaining
same-area anchors. Removed anchors are excluded from subsequent decisions to
prevent collective removals from changing ownership.

### v0.16.7 — all-map cleanup and The Great Sea

Ordinary Clean Redundant Points clicks keep the displayed-map behavior.
Ctrl+Click snapshots every valid saved survey map ID in the active journal,
including maps not currently loaded/displayed, and cleans them sequentially
through the existing budgeted worker. One batch lock prevents overlapping runs.
Each map retains perimeter/crossing/overlap evidence and its revision safeguard;
a stale map is skipped while other maps continue. Progress identifies the map,
and completion reports total removals and skipped maps. Selection and discovery
records remain unchanged. Empty and read-only journals do not start a batch.

Automatic mapping pauses when the readable current sub-zone, zone or real-zone
label is The Great Sea. This handles offshore water still using a coastal map ID
without excluding the adjacent land. The existing automatic-mapping preference
is preserved, no old evidence is erased, crossing continuity resets, and manual
survey points remain available. The English area label matches the target client.

Regression coverage checks Ctrl+Click/tooltip behavior, undisplayed maps, batch
locking, stale-map continuation, read-only/empty journals, all three sea label
sources, preserved evidence, manual points and resumed coastal sampling.
Live check: Ctrl+Click with multiple saved maps, then cross between a coastal
sub-zone and The Great Sea and verify no automatic offshore points or bridging
crossing is recorded.

### Unreleased — traced fill trial and native map filters

The default outline now peels empty triangles from the convex hull through
supporting observations. Both replacement edges must be shorter; edges below
2% of normalized map size stay intact. Detours must preserve all observations
and cannot cross or touch unrelated outline edges. Horizontal edge buckets
keep concave containment queries bounded to relevant edges. The existing
time-budgeted worker, contour refinement and texture limits remain in use.
This is still an estimate, not proof that every shaded location was visited;
sparse surveys can retain unsupported bridges. It does not infer disconnected
patches or holes.

Atlas **Legacy fill** selects the original convex algorithm on both maps.
Geometry caches include the method, colour assignments survive switching, and
no stored samples are converted. Cleanup is paused in traced mode, including
when switched on during an in-flight legacy cleanup. Legacy cleanup remains
available and can remove evidence relevant to a later return to traced fill.

The native Filters menu gains Points, Labels, Zones, Merchants and Nodes under
Azeroth Fieldbook. Integration extends `MENU_WORLD_MAP_TRACKING` through
`Menu.ModifyMenu`; the target client's [Blizzard menu source](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_WorldMap/Blizzard_WorldMapTemplates.lua#L212)
declares that tag. Registration handles delayed menu loading without replacing
Blizzard's menu generator. Main-map survey filters become independent of Atlas
choices on their first edit. Points off hides even isolated native-map dots.
Nodes uses the existing gathering world-map preference; minimap settings are
unchanged. Merchant pins default off, show one recorded location per merchant
on the selected map (personal evidence preferred), retain report provenance,
and cap the reused frame pool at 512. Neither layer fabricates coordinates.

Automated checks: 39 sub-zone, 5 native filter/merchant, 6 gathering map and
66 Ledger tests passed, as did Lua 5.1 syntax, TOC/version/bindings validation
and whitespace checks. The synthetic 4,095-crossing benchmark completed within
the existing texture budget; this is not a measurement of native WoW frames.

Pending live acceptance after `/reload`:

1. Compare a known inward bend with Legacy fill off/on, with Points visible.
2. Open the main map's Filters dropdown and toggle each of the five layers.
3. Confirm main-map survey choices do not alter the Atlas selections or recording.
4. Check known merchant/node positions while panning, zooming, changing maps
   and closing/reopening the map. Check reported merchant tooltips.
5. Reload again and verify filter and Legacy fill preferences persist.
