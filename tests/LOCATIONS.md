# Creature Locations

The button beside Creature Notes is separate from the existing Locations index
filter. The button beside Map brightness switches between retained violet kill
history and cyan observation tracking. New locations require the automatic
40-yard proximity / 42-yard map guard below. Clicking a creature still adds its
entry even when its location fails the guard. Kills add no zones, subzones or
coordinates; tag eligibility, pet credit and kill rewards continue.

## Data and algorithm

- Targeting and hovering record identity and readable facts independently of
  location qualification. A living, identified creature with positive proximity
  and all 25 map samples agreeing adds the enclosing zone and observer position.
- The first qualified observation per creature and zone per session emits
  **New Location Observed**, including existing saved points/zones and unreadable
  levels. The notice respects creature-announcement preferences and is retained
  in the Event log. Simultaneous entry discovery includes the zone in its one entry message instead
  of a second location notice. Further captures stay silent and award no Knowledge.
- Capture has a separate one-second limit per creature, including event-triggered
  observations. Once accepted, movement of about 10 yards (using map yard scale)
  or a map change is required for another range/border check. Rejected positions
  retry after the interval so moving inland or approaching the target can recover.
  Ordinary entry discovery and combat observations keep their existing cadence.
- Stationary accepted captures do no repeated range checks, border lookups or
  writes. Existing coordinates receive no timestamp-only refresh. New eligible
  captures check the current position; no moved-position safe result is reused.
  Eviction sorts occur only when a newly inserted point exceeds the storage cap.
- Terminal kill notifications, corpse targeting, pending credit and living resets
  never sample or save positions, zone names or subzones. Existing location history
  remains intact, including on locked entries and through reloads.
- Old zone names resolve through the client's map hierarchy when the name is
  unique. Ambiguous names/floors wait for supported map evidence instead of
  choosing an arbitrary map. This resolves artwork only, never past coordinates.
- The historical `Sample` helper and exact/approximate storage compatibility
  remain available for retained data; live observations use only player map
  coordinates. No restricted coordinate is compared, formatted or saved.
- `killLocations[mapID]` holds a name, optional map dimensions in yards, and up to
  256 recent distinct points keyed by `1 + x*10001 + y`. Exact samples upgrade
  approximate ones at the same coordinate. Cap at 64 maps per creature. Retained
  samples follow the active tracking scope and literal backup/restore validation;
  merging characters unions coordinates without downgrading precise samples.
- `observationLocations` has the same bounded format and independent limits.
  Its points represent the player's position at a qualified observation, not an estimated
  creature position, so they do not use the kill fallback's approximate flag.
  Reload, merge, backup, restore and deletion handle both optional fields; neither
  coordinate layer is sent through sharing. Old backups still restore unchanged.
- `locationTrackingMode` is a per-character display preference, defaulting to
  kills. Switching layers retains the selected creature and map and reuses the
  map, fill, border and marker pools. Cyan and violet each have a bright border;
  terrain brightness never dims either layer. The zone selector includes maps
  from both layers, without mistaking same-named map IDs for the same map.
- Deterministic Delaunay triangulation in world-yard dimensions, then retain only
  triangles whose **three** edges are at most 180 yards. Render these with a
  translucent violet or cyan texture whose fourth vertex is collapsed. Points belonging
  to no retained triangle remain dots. Collinear samples and maps with no world
  dimensions remain dots. These estimate kill areas or observer positions, not spawn boundaries, and
  does not infer terrain passability, walls or floors absent a separate map ID.
- Historical approximate kill positions can be offset by attack range or pet
  distance. Several observations while standing still produce one point, not a region.
- Coordinates remain personal and are excluded from sharing. Existing backups
  without this optional field continue to work; new imports validate dimensions,
  coordinate ranges, coordinate keys and per-map/per-creature limits.

## API sources

Checked against Blizzard UI source for Forever 1.60.1 build 69977, mirrored at
commit `c6e89983189e4f626f549204a23c2d2bea93080a`:

- [Map API and restrictions](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua)
- [UnitPosition signature](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Base map tile layout](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_MapCanvas/Blizzard_MapCanvasDetailLayer.lua)
- [Explored map overlays](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_SharedMapDataProviders/MapExplorationDataProvider.lua)
- [Texture vertex API](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua) and [corner indices](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_FrameXMLBase/Constants.lua)

GetBestMapForUnit and GetPlayerMapPosition document support for the player/party,
not arbitrary NPCs. UnitPosition's presence is not proof that Forever exposes a
particular enemy's coordinates. Live exact-coordinate availability is unverified.

## Live acceptance checklist — pending

### Automatic nearby observations — fixed live-test rule

- Enabled automatically after reload. Target/mouseover observations need a living
  creature with a stable public GUID and a positive check at 40 yards or less.
  `/fieldbook debug locations off` pauses these writes until reload; `on` resumes.
  No saved preference, survey, startup dialog or debug session is required.
- `C_Item.IsItemInRange(4945, unit)` (Faintly Glowing Skull, 40 yards) is the primary
  probe. Item 18904 (35 yards) and interaction 4 (approximately 28 yards) are
  shorter positive fallbacks. Both items' data are requested once. False, nil,
  secret and failed checks never prove proximity. No spell-range checks are used.
  The [LibRangeCheck Era/Forever item list](https://github.com/WeakAuras/LibRangeCheck-3.0/blob/main/LibRangeCheck-3.0/LibRangeCheck-3.0.lua)
  lists item 4945 at 40 yards and item 18904 at 35 yards. The new 40-yard probe's
  actual availability and behaviour in the live client are not yet confirmed.
- The guard always uses a 42-yard **radius**. Twenty-five samples comprise the
  centre and eight compass/diagonal directions at radii 14, 28 and 42 yards.
  Diagonal axes are scaled by sqrt(0.5); no sample lies outside the circle.
  All samples must resolve directly to the player's enclosing zone. Any other
  zone, nil, API failure, secret, malformed hierarchy or off-map point rejects.
  There are no gap retries, interpolated classifications or adaptive guard sizes.
- Coordinates use the queried map's world dimensions. The default query map is
  the enclosing zone; `zone`/`continent` commands can select the query map until
  reload. Micro maps normalize to enclosing zones; dungeon maps are unsupported.
  Results are cached for half a second only while stationary at identical map
  coordinates with the same query map. Movement rechecks all 25 samples.
- Passing observations add zone names (also to locked location snapshots) and
  cyan observer points through existing storage/backup paths. They do not add
  subzones or kill credit. Kills never add locations, even if nearby at death.
- Probe revision 6's optional read-only report shows range evidence, all sampled
  coordinates, causes of rejection and actual point additions/refreshes. Counters
  are transient and never enter SavedVariables. The report works without a target
  and performs no bypass, world-coordinate or wider compass comparisons.
- Finite samples can miss narrow regions, and UI-map navigation data can differ
  from terrain zone labels. The rule's live accuracy has not been measured.

For live testing, simply reload and use the Bestiary normally. Passing nearby
observations should add cyan points, while distant targets or mixed/unavailable
map samples should not. Existing entries also gain points. Clicked entries must
still appear without a location when rejected; the first passing zone adds a
New Location Observed notice. Kill credit continues without location capture.

`test_location_prototype.py` covers default automatic target/mouseover writes,
positive 40-yard and shorter checks, fixed-radius diagonal/intermediate coverage,
missing/secret/error rejection without retries, stationary cache and movement,
map hierarchies/scales, identity changes, locked snapshots, optional pause/report
commands, storage limits, first-qualified notices, movement/time work limits and kill/location isolation. Mocks cannot establish the
client's actual range or terrain-boundary accuracy.

### Existing locations acceptance

Live evidence supplied on 2026-10-06 at the western Duskwood/Westfall edge:
the first snapshot resolved the player's centre to Westfall but the +25-yard
eastward column to Duskwood, while both range checks passed. Further inland,
the centre and +/-25-yard samples resolved to Duskwood; only the -50-yard
westward column resolved to Westfall, with the 35-yard item check still passing.
Further inland again, every map sample resolved to Duskwood, while both range
checks failed for the selected creature. These show usable, position-dependent
classifications and independent range rejection. They do not establish the
distance between the UI-map dividing line and the actual terrain zone border,
or a full live recording pass. The first centre discrepancy remains relevant.
Later snapshots around Duskwood 13.43, 40.15 showed the same five N-50 samples
unavailable on both zone and continent lookups. The other 20 resolved to Duskwood.
This suggests shared lookup coverage rather than a query-map-specific issue.
Revision 2 confirmed literal nil returns for those five points. Its selected-zone
bypass returned nil for all 25 points, and automatic world-to-map conversion
returned only Eastern Kingdoms for all 25. The supplied map places the player
inland at Raven Hill, suggesting a false exclusion rather than a terrain border.
The continent-map bypass remains unverified in the live client.

Revision 4 live evidence shows actual inland writes at Duskwood 30.52, 37.55
and a readable Elwynn classification across the N-40 row at 37.73, 24.54.
A later report at 57.63, 13.40 passes all 25 samples on both query maps despite
the supplied screenshot showing the player beside the river with Elwynn nearby.
The calculated N-40 point is 57.63, 11.18; neither the actual zone-change distance
nor the UI lookup's transition distance at this position has been established.
This raises a possible false-pass concern independent of nil-gap handling.
Revision 5's unconditional bypass comparisons and wider probes investigate it;
agreement between query maps is not independent proof of terrain accuracy.

`nil` here means no result from a UI-map lookup, not a confirmed zone boundary.
Blizzard's [map navigation code](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_MapCanvas/Blizzard_MapCanvas.lua)
uses this API to choose the map to open on a click and handles a missing result.
Its [generated API declaration](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua)
explicitly permits no return; it provides no diagnostic explanation from the
native lookup. The five north samples are inside normalized map bounds. Their
shared failure across query maps suggests a navigation-data gap or region edge,
but the precise underlying data defect is not established.

Revision 6 replaces the adaptive/gap-filling prototype with the operator's
simpler <=40-yard proximity AND all-42-yard-samples agreement rule. Recording is
now automatic after reload. The earlier live reports document limitations of the
lookup data; they do not validate the new rule. The new rule rejects missing
samples directly and performs no interpolation or diagnostic comparisons.

1. `/reload`; Open an old creature's Locations window. Compare the
   map orientation, labels, explored terrain and aspect with Shift+M. Old kill
   totals must not create markers. Existing index filtering must still work.
2. Click a distant creature or stand near mixed/unavailable map samples. Its
   entry must appear without a location. Move to a passing range/map position
   while keeping the living target: a cyan point and zone should appear with
   New Location Observed (when creature announcements are enabled). Repeated
   observations in that zone must not repeat the notice.
3. Observe at a second nearby position: two dots. Observe at a third offset
   from the line: a translucent cyan triangle can replace those dots. Confirm no
   rectangular fill or stretching, including larger groups and their boundaries.
4. Observe the same creature far away in the zone. Its group must remain separate
   without a broad shaded bridge. Collinear positions may remain dots.
5. Observe the same creature in another zone with passing checks. Verify the new
   zone notice, dropdown, map art and cyan markers. Kill it with credit and confirm
   rewards/counts continue without adding any location. Repeat with failed range
   and border checks, an uncredited corpse and duplicate terminal notifications.
6. Adjust Map brightness from 20% to 100%: base tiles and explored terrain should
   change together, while dots, violet fill and the soft boundary glow stay bright.
   Internal triangle seams must not glow. Close/reopen and reload to check the
   saved slider value. Change UI brightness: parchment and the dropdown should
   remain greyscale and 66% darker than the rest of the UI, independently of the
   map. Check the Options-style slider and its extra bottom padding. With Always attempt to anchor enabled,
   opening Locations should align to the right/top of the book, even after a saved
   drag. Disable it and verify a saved free position remains in place. Crowded
   screens retain the shared overlap/clamping rules. Drag, change UI scale, press
   Escape, and close the Bestiary.
   Check the Locations launcher highlight and map/window layering. Confirm the
   creature title, three header buttons and kill counter left of Rumours fit.
7. `/reload`, switch account/character tracking, and backup/export/import/restore.
   Verify locations persist in the chosen scope and through backups. Restore an
   old backup with no locations and verify an empty map rather than stale markers.
8. Select Observations beside Map brightness. Existing cyan points should remain.
   Target, hover and use the mouseover-open binding: only qualified living
   observations may add cyan points/zones. Kills and corpses add none. New
   observations must not add subzones or violet points; historical layers persist.
   Switch layers, zones and creatures and verify saved layer choice.

`test_locations.py` and `test_observation_tracking.py` cover the real addon event
paths, storage, secrecy, kill/location isolation, deduplication, scopes,
backups, distance filtering, triangulation area, layer palettes/tooltips and mocked
window controls. Mock widgets cannot validate native map textures, alpha blending,
vertex winding, font fit, or Forever's live coordinate availability.
