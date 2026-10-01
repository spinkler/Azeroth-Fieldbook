# Gatherer's Compendium

Current storage scope: the global Account-wide tracking option selects this
section's account or character journal. The original per-character SavedVariable
is preserved. Earlier per-character implementation notes below describe the
original section boundary; see [account tracking](ACCOUNT_TRACKING.md) for the
current migration and storage contract.

Unsupported future schemas are never normalized or downgraded. The constructor
creates a detached empty read-only view; edits, map preferences, hover discovery,
interaction capture and loot recording cannot write to that journal. The section
explains that an addon update is required to view the preserved data.
`test_account_sections.py` checks the real initializer, UI, background handlers
and reload with account tracking enabled and disabled.


World-map visibility investigation and regression evidence are documented in
[GATHERING_MAP_PINS.md](GATHERING_MAP_PINS.md), including the matching Forever
70009 layer ordering and remaining live checks.

## 0.12.2 live checks

Discovery chat uses the shared creatures/nodes/locations option. New resource
types and observed zones produce gold-titled messages with grey details; new
interaction coordinates are announced separately. Repeat hovers and points
within the existing ten-yard merge radius stay quiet. Disabling messages does
not disable recording. `test_gathering.py` checks the actual initialization
callback, colours, deduplication and muted discovery. In game, verify both herb
and mineral messages with the option enabled and disabled.

- Hover and hold each Locations zone button; the label must retain its normal size.
- Confirm the three-pixel divider above Field notes and the matching thickness
  above Recorded abilities in the Bestiary.
- Toggle each map checkbox independently, then reload and verify persistence.
  Checkboxes must also be available when the journal has no entries.
- Open a recorded zone on the world map, pan/zoom, change maps and reopen it.
  Only recorded interaction points should appear; hovered-only zones have no pins.
- Walk past a recorded node with the minimap option on; change zoom and toggle
  minimap rotation. Check tooltip coordinates, nearby visibility and zone changes.
  Disabling either option must remove its pins without affecting the other map.
- Open the Compendium before the Bestiary, then use Options. Repeat on all seven
  main-window sections; Options must open without switching the active section.


Run `python -B -X utf8 tests/run_tests.py` from the repository root. On this
Windows host the bundled Python 3.12 executable is used because `python` is not
on PATH. The tests run the actual Lua 5.1 modules in the existing widget host.

`test_gathering.py` covers actual registered event dispatch, both professions,
localized rank names, duplicate/mismatched/stale casts, attempts rejected before
casting, interrupted interactions, instant gathers, secret/unavailable values,
bounded coordinate histories, reloads, independent character storage, Bestiary
reset isolation, filtering/sorting, real section controls, drafts, navigation,
the Locations map and the main addon initialization path. The navigation suite
continues checking Bestiary state and the unchanged remaining wishlist pages.

The event argument order was checked against the installed Forever 1.60.1 build
69977 API extraction (`Blizzard_APIDocumentationGenerated__UnitDocumentation.lua`):
SENT provides unit, target name, cast GUID and spell ID; START/SUCCEEDED provide
unit, cast GUID and spell ID. Matching localized Herbalism/Mining spell names
also agrees with the collection approach in
[GatherMate2's own collector](https://github.com/Nevcairiel/GatherMate2/blob/master/Collector.lua).
Mouseover discovery uses the installed client's `C_TooltipInfo.GetWorldCursor`
and requires `GameTooltip`'s current `GetWorldCursor` context plus an Object
tooltip with a readable gathering requirement. Localized spell/skill names and
requirement formats identify the profession without checking whether it is learned.
Discovery records zone/map identity but never samples coordinates. A matching
skill-requirement error and live readable world-node tooltip can record an
interaction without a mouse event. Captured world clicks can instead use the
node identity after its tooltip clears, including a 0.5-second hover cache when
tooltip clearing precedes the click callback. Cached hover alone cannot record.
The installed Forever 1.60.1.70009 SystemDocumentation confirms that
UI_ERROR_MESSAGE provides errorType and message, and GLOBAL_MOUSE_DOWN provides
button. Tests dispatch these actual event signatures and cover empty/root-only
mouse focus, UI controls, missing click events, short-lived identity caching,
error/cast deduplication and repeat interactions. The event/input API follows the client's
[global mouse event usage](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_SharedTalentSelectionTemplates.lua).
Tests also cover wrong tooltip types, missing/stale/restricted data, UI clicks,
unrelated errors, localized ranks and combined click/cast deduplication.

The model catalog was cross-checked against the primary
[AzerothCore object definitions](https://github.com/azerothcore/azerothcore-wotlk/blob/master/data/sql/base/db_world/gameobject_template.sql)
and the installed Forever 1.60.1.70009 GameObjectDisplayInfo table. The
[WoWDBDefs schema](https://github.com/wowdev/WoWDBDefs/blob/master/definitions/GameObjectDisplayInfo.dbd)
and [DBCD reader format](https://github.com/wowdev/DBCD/blob/master/DBCD.IO/Readers/WDC5Reader.cs)
were used to interpret that client table. Model file IDs were verified by opening
those assets read-only from the installed CASC archive; model paths do not
resolve by name in this build. `PlayerModel:SetModel` accepts FileAsset IDs in
the installed SimpleModel API. These are game-object assets, not creature IDs.
The catalog contains presentation data only, not discovered resources or spawns.
The native TempPortraitAlphaMask texture was verified in the installed archive;
gathering uses separate circular masks for the 6-pixel marker border and inset.
The map regression exercises three nearby samples with triangulation disabled,
checking that each marker remains at its recorded coordinate.

These checks do not render native WoW widgets. Live acceptance remains:

1. Open Herbs & Minerals and compare typography, search, sort, list bounds,
   gold selection and scrollbar with Bestiary. Confirm the Compendium has no
   Index button or A–Z strip. Verify empty states, type/location filters,
   long names, ascending/descending order and Previous/Next.
2. Check Peacebloom, Earthroot, Copper, Silver and rare/ooze-covered node 3D
   previews. Drag to rotate, switch entries quickly and verify no stale models.
   Unrecognized model identities should show an unavailable caption. Verify the
   selected model appears on first opening, after switching away and returning,
   and after closing/reopening the book. Zoom, selected entry and note drafts
   should remain unchanged. The widget tests reject model requests under hidden
   ancestors and simulate loss of native model state between section visits.
3. Mouse over herbs and minerals on a character without the professions: readable
   tooltips should discover entries with zones under basic-info Locations, zero
   interactions and no coordinate markers. Hover in another zone, then reload: both
   zones should persist and be searchable/filterable without any markers.
   Bag items, unit tooltips, minimap tracking and unrelated loot add no entries.
4. Begin Herbalism and Mining casts. Confirm one interaction and marker per cast;
   completing a cast adds one completed gather. Interrupting an already started
   cast retains its interaction but adds no completed gather. Out-of-range and
   generic rejected attempts add nothing. On a character without the profession
   (and one below the required rank), right-click a node and verify a matching
   skill-requirement error adds one interaction/marker and no completed gather.
   Verify right-dragging the camera, a click without that error, a click on UI,
   unrelated errors, changed mouseovers and expired input add no markers. A tooltip
   dismissed by the failed click should still record the captured node, even when
   it clears before the click callback. Test an interaction key with the same
   live node tooltip: its matching skill error should also add a marker. Hovering
   alone, or an error after an unidentified/stale node, must add no marker.
5. Open each resource's Locations map. Confirm only that resource's zones and
   markers, player arrow, map brightness, missing-map messaging and approximate
   position tooltips. Confirm the smaller round markers stay discrete, with no
   connecting lines or shaded/triangulated areas. Travel without gathering: only
   the arrow moves.
6. Click blank space or the border of field notes to focus the editor. Save
   different notes for a herb and a mineral, switch entries/sections, then return.
   Verify unsaved drafts stay separate. Clear and save one note: the other must
   remain unchanged. Reload and verify saved notes, sort and map brightness
   persist. Test on a separate character.
7. Switch sections or close the book with sorting, filtering and Locations open.
   Gathering dialogs close; Bestiary and other sections retain their behavior.
   Check common window scales and crowded-screen placement.

Gathering has no account merge, portable backup, sharing protocol or bulk reset.
Bestiary's existing controls continue to apply only to Bestiary data. Positions
record the player at cast start or the matched skill-rejected interaction and
are not exact world-object coordinates. Restricted or unidentifiable tooltip
data cannot be discovered or attributed to a failed interaction safely.

### v0.13.35 — ten-yard position spacing

Load-time cleanup and interaction capture merge positions at most ten yards
apart within each resource/map. Stable coordinate-key order determines retained
positions; latest seenAt is preserved. Map width and height are applied separately
and cached per journal. Missing dimensions preserve points and retry cleanup on
interaction. Tests cover exact thresholds, asymmetric dimensions, resource/map
isolation, reload cleanup, unavailable APIs and preserved interaction totals.
