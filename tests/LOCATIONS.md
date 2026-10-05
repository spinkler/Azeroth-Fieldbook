# Creature Locations — 0.10.1

The button beside Creature Notes is separate from the existing Locations index
filter. The button beside Map brightness switches between violet kill tracking
and cyan observation tracking. Kill positions still require accepted kill credit;
observation positions preserve historical targeting samples. New zone names,
subzones and map points require accepted kill credit. Tag eligibility,
pet credit and kill rewards are unchanged.

## Data and algorithm

- Targeting and hovering record identity and readable facts, but no creature
  locations. A transient map ID guards against crossing maps before death.
- Accepted kills store zone/subzone names and normalized coordinates quantized
  to integers from 0 to 10000. No historical positions are inferred from totals.
- Old zone names resolve through the client's map hierarchy when the name is
  unique. Ambiguous names/floors wait for a direct observation instead of choosing
  an arbitrary map. This resolves artwork only, never past kill coordinates.
- Prefer public `UnitPosition` coordinates, converted through
  `C_Map.GetMapPosFromWorldPos` into the player's current zone map. Validate the
  creature GUID before and after sampling. No restricted coordinate is compared,
  formatted, transformed or saved.
- The operator approved using `C_Map.GetPlayerMapPosition(mapID, "player")` as an
  explicitly approximate fallback. Sample at the kill/death notification when
  possible; keep that first fallback while waiting for credit. Do not move a
  delayed kill to a different map or reuse a sample after an evade/living reset.
- Kill samples require existing accepted kill evidence. Duplicate terminal
  events do not append data. A locked creature still gains location history,
  just as its kill count continues to grow.
- `killLocations[mapID]` holds a name, optional map dimensions in yards, and up to
  256 recent distinct points keyed by `1 + x*10001 + y`. Exact samples upgrade
  approximate ones at the same coordinate. Cap at 64 maps per creature. Retained
  samples follow the active tracking scope and literal backup/restore validation;
  merging characters unions coordinates without downgrading precise samples.
- `observationLocations` has the same bounded format and independent limits.
  Its points represent the player's position at targeting, not an estimated
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
- Approximate positions can be offset by attack range or pet distance. Several
  kills while standing still may produce one point, not a region. This is expected.
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

1. `/reload`; confirm 0.9.148. Open an old creature's Locations window. Compare the
   map orientation, labels, explored terrain and aspect with Shift+M. Old kill
   totals must not create markers. Existing index filtering must still work.
2. Kill a creature with tag credit. Verify a dot and its hover coordinates. When
   approximate, compare with your position at death, including a ranged/pet kill.
   Duplicate death notifications, repeated corpse targeting and uncredited kills
   must not add dots. Kill rewards and notifications must still work normally.
3. Kill a second at a different nearby position: two dots. Kill a third offset
   from the line between them: a translucent violet triangular patch replaces
   those dots. Confirm no rectangular fill or texture stretching. Repeat for a
   larger nearby group, checking for holes, seams and unexpected dark overlaps.
4. Kill the same creature far away in the zone. Its dot/group must remain separate,
   with no broad shaded bridge. Points in a line may remain dots. Approximation
   can collapse multiple kills from one firing position into a single marker.
5. Observe/kill the same creature in another zone. Use the dropdown to switch;
   verify different map art and markers, and that the current zone is selected
   when first opening. Switching creatures clears the previous creature's map.
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
   Target, hover and use the mouseover-open binding while moving, including from
   a flight path: no new zones, subzones or map points should appear. Confirm a
   credited kill adds a violet point and its zone; an uncredited corpse does not.
   Switch layers, zones and creatures and verify saved layer choice.

`test_locations.py` and `test_observation_tracking.py` cover the real addon event
paths, storage, secrecy, kill-only location recording, deduplication, scopes,
backups, distance filtering, triangulation area, layer palettes/tooltips and mocked
window controls. Mock widgets cannot validate native map textures, alpha blending,
vertex winding, font fit, or Forever's live coordinate availability.
