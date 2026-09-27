# Gathering world-map visibility — 0.12.10

## Confirmed rendering-order defect

The user repeatedly observed a working gathering tooltip with no visible dot.
The old renderer placed frames above the canvas, then changed to
`PIN_FRAME_LEVEL_DEFAULT` in 0.12.7. Neither clears the world map's explored
terrain and fog artwork. Changing the marker image, masking or size cannot fix
that ordering.

The installed `WowB.exe` reports **1.60.1.70009**. Its matching Blizzard UI source
is mirrored at commit `bd2470aed543f72697a044e989285b6c83e63f73`:

- [WorldMapMixin layer registration](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_WorldMap/Blizzard_WorldMap.lua)
  adds exploration and fog above DEFAULT, and AREA_POI above both.
- [Pin frame-level manager](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_MapCanvas/MapCanvas_PinFrameLevelsManager.lua)
  starts DEFAULT at 2000 and allocates subsequent ranges above it.
- [Exploration provider](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_SharedMapDataProviders/MapExplorationDataProvider.lua)
  draws explored map tiles on `PIN_FRAME_LEVEL_MAP_EXPLORATION`.
- [Fog provider](https://github.com/Gethe/wow-ui-source/blob/bd2470aed543f72697a044e989285b6c83e63f73/Interface/AddOns/Blizzard_SharedMapDataProviders/FogOfWarDataProvider.lua)
  uses `PIN_FRAME_LEVEL_FOG_OF_WAR`.

Executing the native level manager with the native world-map registrations gives:

| Layer | Initial frame level |
| --- | ---: |
| DEFAULT (old gathering marker) | 2000 |
| MAP_EXPLORATION | 2002 |
| FOG_OF_WAR | 2006 |
| AREA_POI (corrected gathering marker) | 2023 |

These are verification values, not constants to put in the renderer. The addon
queries the current AREA_POI level on refresh so later layer insertions are
respected. The ordinary icon layer keeps the dots above map imagery, without
raising them to a separate window strata or bypassing map clipping.

The earlier tests checked texture colour, scale, coordinates and a generic pin
level. They did not model the higher exploration/fog frames and therefore could
not detect occlusion. The new regression builds those levels, exercises the
working tooltip, then checks that the dots draw above both overlays. It fails
against 0.12.9 and passes after the layer change. The native 69977 and 70009
managers/registrations were also checked directly from the external research
cache; the permanent suite does not require network access or that cache.

## Remaining live verification

The widget host does not render WoW. After `/reload`, check an explored zone with
recorded herb and mineral points, including the reported Copper Vein at 31.6,
55.6 and Peacebloom at 28.5, 14.4. Confirm visible green/gold dots and tooltips,
then pan, zoom, close/reopen the map and toggle world-map nodes off/on. This
change does not alter the minimap or Compendium's own location map.
