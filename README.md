# Azeroth Fieldbook 0.17.0 (Beta)

Version 0.17.0 protects saved data at initialization, Lore consolidation and
report validation boundaries. An unsupported or malformed main save disables
initialization with a chat notice and leaves the original data untouched; it
does not allocate a new account import key or initialize other journals.
Only a genuinely absent main save receives defaults. After a blocked load, restore
a supported save and reload; capture stays disabled for the rest of that session.

Fishing reports retain the original contributor when another character exports
them. Account migration preserves Lore links to Atlas discoveries and reconciles
duplicate merchant contacts with the same original report, retaining both
characters' notes and receipt evidence. Historical fishing observers that were
never saved remain unknown; ambiguous old Atlas links remain unavailable rather
than selecting another discovery. See [identity and migration repair](tests/IDENTITY_MIGRATION.md).

**Lore & Landmarks** is a personal archive of writings, landmarks, noteworthy
people and mysteries. Open a supported readable source to preserve its displayed
pages, then read them later in the Fieldbook. Both capture options start on:
**Automatically archive readable lore** and **Only archive pages I open**. Turn
off the second option for best-effort whole-book archiving through supported
page navigation; keep the source open while it runs. Automatically retrieved
pages remain distinct from pages you personally opened. Partial captures retain
their text, and unavailable sources can be transcribed manually.
Rereading matching captured pages reuses the archive; different source text is
retained separately. Delete a selected record through **Sources / manage →
Delete entry…**. Deleted books can be archived again. Distinct saved writings
remain separate, even when their captured text matches, so their IDs, annotations,
links and previously exported report identities survive. Optional consolidation
is checked on detached data and reports why records were kept separate; a skipped
consolidation does not undo a successfully captured page. Ordinary matching
rereads still reuse their existing record.
Object dialogue readers such as **Draconic for Dummies** also archive their
displayed text as writings. Draconic for Dummies is a complete single-page reader;
other object readers retain unconfirmed page boundaries.
**Capture / retry current text** works when automatic archiving is disabled.

Record people and deliberately save displayed gossip or quest passages; record
landmarks, private thoughts, related evidence and a mystery's next step. Entry
and Location views share the existing window. The separate character archive
`AzerothFieldbookLoreDB` is independent of account tracking and other journals.
Lore reports use bounded copy/paste, exact previews and explicit acceptance.
Malformed report lists are rejected without dropping source text. Valid older
stored reports remain readable; malformed stored evidence is retained in the
archive's invalid-entry handling. New imports still require matching addon versions;
private annotations are excluded by default. There is no Lore addon-message
delivery, Knowledge charge or reward. Captured statements and received reports
never establish their truth. See [Lore capture, limits and live checklist](tests/LORE.md).

**Treasure & Salvage** now records container kinds and historical encounters in
its existing tab. Use **Record a find** for world finds, portable acquisitions,
salvage, access attempts and observed contents. Browse known names, zones, items
and notes with combinable filters; save **Look for again** bookmarks and correct
or remove individual encounters. Its independent map uses the Atlas viewport:
**Past finds — current availability unknown.**

Readable openable bag items are recorded in the background as **Observed
carried**. Strictly matched portable loot can record a partial contents
inspection; neither bag changes nor loot visibility prove personal recovery.
World identity, acquisition context and recovery claims require manual input.
Treasure remains per character in `AzerothFieldbookTreasureDB`. Sharing has tested
report-builder, validator, preview and merge hooks; delivery/import/export UI
awaits an extension to the existing transport and points policy. See
[Treasure model, capture limits and pending in-game checks](tests/TREASURE.md).

**Merchant’s Ledger** is now a personal directory of encountered merchants,
trainers and services. Class trainers with recognized English trainer titles
are also discovered on target, mouseover or dialogue. Open an NPC's service
interface to remember readable
offerings, quoted bundle prices, stock and training without buying anything.
Search goods, recipes, lessons, NPC sublabels, places and access notes; use
role, zone, provenance, favourite and recipe filters. Its independent map uses
the exact Atlas viewport. All availability is explicitly historical.

Ledger reports support selected-contact preparation, copy/paste, validation,
preview and acceptance into separate reported facts. Notes are opt-in. Ledger
addon-message delivery and contact discovery rewards remain deferred because
the existing transport and reward policy are Bestiary-specific. See
[Ledger data/API boundaries and in-game checklist](tests/LEDGER.md).

Atlas and Almanac maps support scroll-wheel zoom (1×–4×) toward the pointer,
including over map pins. Scroll down to return to the full map. Changing maps
resets zoom; the map frame and border stay fixed. Player coordinates remain
visible in the map's lower-left corner with a thin antialiased black outline.
While zoomed in, hold the left mouse button and drag to pan, including from a
marker. Movement stays within the map edges; a short click retains its usual action.

Both maps show the native zone/continent glow under the pointer when map
navigation is enabled, following the artwork through zoom and pan.

Both maps also support world-map navigation: **left-click** a zone to open it,
or **right-click** to open the parent map. Disable **World-map click navigation**
under **Options → Atlas and Almanac maps** to turn this off; it defaults on.
Marker selection, Ctrl+right-click removal and Atlas point placement keep their
existing actions. Map navigation does not assign a fishing source.

The single zone selector on both pages opens a cascading menu. Hover a base map
such as Eastern Kingdoms or Kalimdor to choose one of its zones, or select
**View** to open that base map. **Battlegrounds** has its own submenu; Zephras
Isle is under **Other**. Long menus scroll and selecting a map adds no discoveries.

On Almanac map markers, **Ctrl+right-click** removes a remembered spot or the
displayed automatic fishing position. Catch history remains intact. Restore
remembered spots through **Show: removed**; new catches can display a fresh
automatic position. For overlapping markers, select the intended spot first.

*A personal monster journal for World of Warcraft.*

Azeroth Fieldbook currently contains the **Bestiary**, a personal record of
creatures encountered by the player, with individually accepted reports from
other players. It starts empty and records only readable personal observations
or explicitly accepted shared information. It does not ship with creature or
spell databases. Version 0.17.0 includes sharing, addon-version compatibility
checks, account-wide tracking and a separate Rumours review window.

The main window now has seven native icon tabs down its outside right edge:
**Bestiary**, **Gatherer's Compendium**, **Traveller’s Atlas**, **Angler’s Almanac**,
**Merchant’s Ledger**, **Treasure & Salvage**, and **Lore & Landmarks**.
Bestiary is selected on first opening. **Gatherer's Compendium** is a personal gathering
journal; **Traveller’s Atlas** is a personal geographical journal, and **Angler’s
Almanac** records personal fishing knowledge. **Merchant’s Ledger** remembers
encountered contacts, goods, training and useful services. **Treasure & Salvage**
records historical container knowledge. **Lore & Landmarks** preserves encountered
writings, significant places, noteworthy people and personal investigations.
Hover a tab for its name; the selected tab has a gold border. Switching
tabs retains the Bestiary's creature selection, filters, list/ability browsing
positions and unfinished fields. Creature-entry actions select the Bestiary.

Each newly recorded Lore entry is announced in chat and the persistent Event log,
available from Lore & Landmarks. Rereads and extra pages do not repeat the announcement.

## Angler’s Almanac

The title-bar **Event log** button opens the active journal’s ongoing history of Almanac
events: acquired catches, fish getting away, pool discoveries, source changes,
skipped captures and journal corrections. Events survive reloads and appear
newest first, in pages of 50. Partial loot updates share one catch entry. **Clear
log**, then **Confirm clear**, removes only the log; catches and notes remain.
Older activity cannot be reconstructed, and this log is not included in reports.
The Catches list puts the most recently caught item first. Record names appear
in the yellow detail title without a duplicate heading in the description.

The Almanac starts with no fishing knowledge. **Waters**, **Pool Types**, and
**Catches** browse the same character-owned observations. Search recorded names,
places and notes; cycle the compact zone, source, knowledge and activity filters.
Use **Sources / spots** on a caught item to find where you caught it before.

- Readable fishing loot records acquired
  item slots in the background, including autoloot and non-fish items. Quantities
  and catch-event occurrences are separate; interrupted casts and uncollected
  full-bag slots do not count. Unidentified sources remain **Unclassified water**.
  A missing client cast ID no longer blocks confirmed fishing loot; the collector
  uses a local event identity without inventing historical skill evidence.
  Fish-escaped and fish-not-hooked errors discard pending loot and show a status;
  they do not add catches, change skill evidence or clear the session source.
- Hovering a recognizable fishing-pool world tooltip adds its type to the current
  zone, without a coordinate pin or catch association. Localized Fishing requirements
  are recognized; English school/pool/shoal and wreckage names also have a fallback.
  Select a pool type and **Remove pool** to hide it and suppress automatic re-addition.
  Use **Show: removed**, select the type, then **Restore pool** to bring it back.
  Removal preserves notes and catch history.
  In **Waters**, select an incorrect pool sighting and use **Remove sighting**;
  **Show: removed** offers **Restore sighting**. Other sightings and the pool
  type remain. Removed automatic sightings stay suppressed in that zone.
- **Remember spot** and **Pool sighting** record deliberate, named observations
  at your approximate player position. A sighting reveals no pool contents.
  Map pins remember past observations; they do not promise a live pool.
- **Assign selected pool** or **Assign open water** explicitly assigns the next
  session's source. The assignment is visible and clearable. Movement, changed
  waters, another activity, five minutes idle, or reload invalidate it.
- **Record catch** is a player-recorded fallback when automatic evidence is
  unavailable. Enter only catches missing from the history. **Notes / edit**
  saves personal notes; **Merge spot** corrects compatible duplicate spots while
  preserving original notes, positions and catch history.
- Successful effective skill is qualified evidence, never a minimum requirement.
  Unreadable requirements and separate equipment/lure contributions stay unknown.
- **Recorded catches** and the main **Catches** index show item icons and native
  item tooltips on hover. Uncached or name-only items have a safe text fallback.
- **Reports** prepares selected knowledge, excludes notes by default, and provides
  a data-only copy/paste boundary. Incoming data must be **Previewed** and
  **Accepted**. Reported facts keep original source claims (not authenticated),
  remain separate from personal statistics, and survive forwarding without adding
  duplicate results. Addon-message transport, fishing prices and rewards are not
  configured; Bestiary sharing and its point rules remain unchanged.

`AzerothFieldbookAnglingDB` holds the separate character journal. Account-wide
tracking selects the shared Almanac store; other sections' resets and backups
remain independent. The last 200 catch events and 32 sessions
are retained alongside durable source-specific totals. Browsing, notes and map
selection persist. The map uses the Atlas renderer and exactly the same anchor,
dimensions and aspect-fit policy, with independent state. See the
[implementation contract and remaining in-game checks](tests/ANGLING.md).

## Traveller’s Atlas

Build a personal record of caves, ruins, routes, crossings and useful places.
Add expedition notes, connect discoveries across Fieldbook sections, and prepare
regional field reports. The Atlas starts empty, with no seeded sub-zone boundaries
or secret-place database. Named discoveries are added deliberately; personal
sub-zone crossings and encountered weather are observed automatically.

- **Add Discovery** captures readable current-map context and coordinates. Give
  the entry a name and category; notes are optional. Coordinates can be left
  blank and added later. **Choose on displayed map** explicitly picks a map
  position. Record cave entrances deliberately; interior labels/maps are optional.
- Browse continent/zone selectors or use **Current Zone**. Search the displayed
  map or all recorded zones. Pins and the index share selection. Eight independent
  map layers do not filter the index; **Reveal layer** explicitly shows a hidden
  selected category. Overlapping pins cycle on repeated clicks.
  A facing arrow shows your live position when viewing your current map; it
  hides on other maps or unavailable position data and records no movement history.
- Choose **Route / Passage**, then **Save & route stops** to add, remove and reorder
  existing places and named waypoints. Numbered stops span zones; supported line
  rendering connects consecutive visible stops only within one coordinate space.
- **Map Layers** opens a dropdown with a checkbox for each discovery category,
  plus **Show all** and **Hide all**. Changes apply immediately; the menu stays
  open for selecting several layers. Settings persist without filtering the index
  or changing the sub-zone controls. The button sits directly above the map;
  the Zone selector stays at the top. Both match the Almanac's zone-selector width.
  The selectors use native dropdown arrow artwork with a dark drop shadow.
- The **Sub-zones** group beside Map Layers contains independent **Shading**,
  **Points** and **Labels** toggles on separate rows (off by default for new journals).
  The group fills the space beside the matching-width Zone and Map Layers selectors. Shading
  estimates regions from your crossings and interior observations, with a unique colour for each area
  on the map. New colours maximise their minimum perceptual distance from those
  already assigned, retaining existing colours as the visible map updates.
  **Clean redundant points**, beside Map Layers, removes interior samples strictly
  inside an area's perimeter on the displayed map. Cross-over points, edge samples
  and interior evidence needed to separate overlapping regions are retained.
  Cleanup reports a count and leaves other maps and discoveries untouched.
  **Hide zone-name areas** hides shading and labels matching the displayed zone
  name (such as Loch Modan in Loch Modan). It defaults off, saves per character,
  and leaves sample points, neighbouring regions and recorded evidence intact.
  Checked **Points** shows every recorded crossing and interior sample, including
  incorporated samples, as small dots that stay the same size when zooming.
  Unchecked retains automatic isolated dots with shading and hides incorporated
  samples. Saved evidence remains available. Shading needs at least
  three non-collinear samples. Brighter saturated colours and refined
  triangle contours replace the coarse square-cell edges. **Labels**
  independently shows names with a thin, non-monochrome outline. Names use their
  measured width and try two lines before being hidden for lack of space. **Label size**
  adjusts text from 2–24, defaulting to 4 while preserving saved sizes. The styled
  **Brightness** slider adjusts map artwork from 20–100% without dimming labels,
  shading, markers or the player arrow. Settings persist per character; existing
  enabled overlays retain their visible points on upgrade. Hiding points leaves
  recording and saved evidence intact.
  Hover the map for names, from/to labels,
  coordinates and observation time; interior samples are identified separately
  from crossings. Convex estimates may bridge bays or holes;
  these are personal approximations, not exact game borders. Crossings collect
  with the Atlas closed or the layer hidden, persist per character, and stay out
  of discovery entries and field reports. Automatic mapping pauses in The Great Sea, on flight
  paths, while flying and in Stormwind, Ironforge, Darnassus, Orgrimmar,
  Thunder Bluff and Undercity. Existing evidence and manual survey points remain
  available; ordinary inns and settlements are not excluded. Sampling resumes
  without drawing a crossing across the pause. Loading screens, unavailable positions
  and large jumps break continuity. Samples of the same border within about
  10 yards coalesce, including reverse crossings. Redundant saved samples are
  thinned when you visit or display their map; different border pairs remain
  distinct. If map dimensions are unavailable, the existing same-direction
  0.25% coordinate-cell fallback applies for borders. With readable map dimensions,
  the Atlas also records your initial sub-zone position and further interior
  samples only when more than 50 yards from every existing sample on that map,
  including other named areas and
  cross-over points. Cross-over recording keeps its separate ten-yard rule. Up to
  4,096 total samples per map are retained, with at most 1,024 interior samples
  to leave room for crossing evidence. Interior samples carry a name, position
  and time, never an invented from/to transition.
  Recording queues lightweight updates; indexing, geometry and drawing are spread
  across frames. The previous completed shading remains visible while updating,
  and observations on another map do not rebuild the displayed map.
- **Observed Weather** lists weather types encountered in the selected Atlas zone.
  Observations accumulate while playing, even with the Atlas closed, and persist
  per character. Unvisited zones remain empty; unavailable weather is not recorded.
- **Expeditions** stores longer journals with dates, zone associations and links.
  **Linked notes** attaches the selected discovery to new or existing expeditions.
  **Connections** links Atlas records or existing Bestiary / Gatherer's Compendium
  discoveries. Bestiary links use existing entry navigation; gathering links show
  an Atlas-contained summary. Removing a link never deletes its source record.
- **Prepare Field Report** saves a zone or named-selection draft, explicit record
  selections, optional private notes and chosen expedition excerpts. The preview
  shows the exact included content. Versioned validation, bounded literal
  serialization and recipient staging are implemented; transport, inbox and import
  UI are deferred. No report is sent or imported by this page.

Atlas data and layer/browsing settings use the active account or character
journal. `AzerothFieldbookAtlasDB` retains the separate character store. Atlas
remains independent of Bestiary resets, sharing and backups. Explored status is always a player assertion, separate from Recorded
or Reported provenance. Deleted entries leave clearly unresolved links, allowing
the player to preserve or remove their history. See [Atlas implementation and
validation](tests/ATLAS.md) for limits, sharing contracts and the live-client checklist.

## Gatherer's Compendium

The two checkboxes at the bottom of the Compendium independently show recorded
nodes on the **world map** and **minimap**. Both default to off and are saved per
character. World-map icons appear on the recorded zone's map; minimap icons show
nearby positions and follow movement, zoom and rotation. Hover an icon for its
resource name and approximate coordinates. These are historical positions, not
live node availability. Minimap pins hide when position or view-radius information
is unavailable. Dense maps display up to 512 recent world-map positions and 128
nearest minimap positions; all recorded positions remain in the journal and its
per-resource Locations view. The main window's **Options** cog is accessible from every section. Every section
also has a **? Help** button in the same title-bar position with instructions for
the active journal.

The gathering journal starts empty. Mouse over a herb or mineral to discover
its name, type and zone from its readable world-object tooltip, even without
Herbalism or Mining. Hovered zones appear under **Locations** in basic info.
Discovery adds no coordinate markers or interaction counts.
Targeting, minimap tracking, unrelated loot and opening the page never add markers.

Coordinate markers require an interaction. Starting a Herbalism or Mining cast records
one, even if interrupted; a matching successful cast also counts as a completed
gather. Without the profession or required rank, right-clicking the node can
still record a location when the client reports its matching skill requirement.
A matching skill error can identify the attempted resource from its live
world-object tooltip even when the client does not deliver a mouse-click event.
World clicks also retain the recent hovered identity briefly if the tooltip
clears before the click handler runs. A cached click must match the skill error
within two seconds; cached hover identity alone cannot create markers. Actual UI
controls, out-of-range failures and unrelated errors are excluded. Player
coordinates are sampled when the interaction is confirmed by the error. Completed gathers are casts, not quantities of looted materials.

The page follows the Bestiary's parchment, left index, A–Z filters, search,
sort menu, sixteen-row list and Previous/Next controls. Filter by Herbs,
Minerals or known locations, search names or zones, and sort by name, type,
interactions, completed gathers or encounter dates. Each entry includes saved
field notes and a draggable 3D preview using the classic node's own model in
the same frame as the Bestiary. The model catalog supplies presentation assets
only; it never seeds discoveries or locations. Unknown/new resource models
show an unavailable caption. Each entry also has **Locations**, with zone
selection, map brightness and a live
player arrow. Small round green herb markers and gold mineral markers show
your position when gathering, so node positions are approximate. Each marker
represents a discrete recorded position; gathering never triangulates or shades
areas between nodes. Missing map coordinates
leave the interaction and readable zone recorded without inventing a marker.

Gathering progress, notes and sort/map preferences use the active account or
character journal. `AzerothFieldbookGatheringDB` retains the character store. Location histories retain up to 256 positions per
map and 64 maps per resource, consolidating repeated coordinates. Gathering is
independent of Bestiary resets, backups and sharing. Click the field-notes area to edit and use **Save notes** to persist notes for
that entry. Saved notes are independent for every herb and mineral. Unsaved
note drafts remain when switching entries or sections during the same session.

Development will continue through 0.x Beta milestones. Stable 1.0 is reserved until Beast Lore
has been tested in game; it does not require every future section to be complete.

## Installation and opening

Options → Tracking includes **Auto-lock after X kills without changes**, enabled
by default at 10. Only credited kills count. Recorded-information changes and manual
unlocking restart the count; repeated sightings do not. Newly learned loot items
restart the count; repeated drops, quantities and corpse samples do not. Progress persists across
sessions, and automatic locking does not confirm pending abilities. Existing kills
are not counted retroactively. Automatic locks appear in the Event log.

**Lock newly encountered critters** is also on by default under Tracking. It
records their first basic information, then locks the page. Turn it off to start
new critter pages unlocked. Existing pages and manual unlocks are respected;
shared-only pages stay available for review until a personal encounter.

Install the addon as `Interface/AddOns/AzerothFieldbook` and enable
**Azeroth Fieldbook** in the addon list.

- `/fieldbook` or `/fieldbook book` toggles the journal, reopening its last section.
- The minimap button opens or closes the journal; its visibility is optional.
- `/bestiary` remains available as a compatibility alias.
- The Bestiary starts on its title page each session. After selecting a creature,
  reopening the book or returning to its tab keeps that entry and unfinished inputs.
- Under the **Azeroth Fieldbook** keybinding heading, **Toggle Azeroth Fieldbook**
  opens/closes the journal at its last selected tab. **Open Azeroth Fieldbook at mouseover**
  opens the Gatherer’s Compendium for a hovered herb/mining node, a matching
  remembered Merchant’s Ledger contact, or the Bestiary entry for a creature. Existing key assignments remain valid.
- Assign **Next Bestiary entry** and **Previous Bestiary entry**
  in WoW's keybinding options to browse the filtered, sorted list. They
  wrap at the ends and keep the selected entry visible. They act only while the
  Bestiary section is open and no text field has keyboard focus.

**Record Atlas survey point** adds a sub-zone survey sample at your current
position, provided all existing survey samples on that map are more than 15 yards
away. It works with the Atlas closed. Manual points survive reloads; use
**Clean Redundant Points** to simplify the displayed map, or **Ctrl+Click** it
to clean every map with saved survey points. Each map retains crossing, perimeter
and overlap-boundary evidence; your displayed map and discoveries stay unchanged.
**Toggle Automatic Mapping**, above that button, starts enabled and saves your
preference. Turning it off pauses automatic sampling but keeps the manual keybind available.

No existing keybinding is overwritten. Escape closes the primary and secondary
windows. The book and its dialogs can be dragged and are clamped to the screen.
Dragged windows remember their position per character across reloads and game
sessions. Untouched dialogs retain their book-relative defaults instead of saving
screen coordinates when closed. Full reset clears saved positions along with other settings.
Initial positions sit beside the book: damage observation, Help/Options and ID
Logs and Notes start on the right; observation panels sit below damage and
Rumours below ID Logs. Locations starts on the left, with Ranks beneath it and
their right edges aligned. The narrower Share window starts on the right with
its bottom edge aligned to the book. Default dialogs follow the book and stay
inside the screen; restored positions are clamped for the current screen size.
The default-on **Always attempt to anchor to main window** option rechecks even
saved positions on opening. Damage, offense, defense, behaviour and effect panels
prefer the book's right edge, then the right edge of the next window. Filters
prefer the book's left edge, then its bottom, then the left of another window.
Help and Options prefer the book's right edge, then its left. Disabling the option
retains saved positions unless overlap or screen bounds require adjustment.
Opening any addon window checks for
overlap with all other visible addon windows and places it beside, above or below
them when possible. Dialogs opened from the book prefer a free edge of the main
book before falling back to unrelated windows. Pinned Notes and the locked spell-ID window retain their
positions; other windows arrange around them. Screen visibility takes priority
even for pinned windows. If no free space fits, overlap is minimized; oversized
windows shrink to fit the screen. Clicking an
addon window or one of its controls brings that window to the front of the other
addon windows.

The window's tab column is included in screen clamping and auxiliary-window
placement. At large UI scales the main window fits the screen with every tab
accessible. Windows opening on the right clear the tabs, including restored
positions; when space is crowded, placement protects the tabs before minimizing
content overlap. Unpinned Bestiary panels close when changing sections; explicitly
pinned Notes and the independent spell-ID utility retain their existing lifetime.

In the Bestiary, the list button left of Options opens the **Event log**. It records timestamped discoveries, knowledge awards, observed-cast alerts and sharing activity even with chat announcements disabled. This per-character history starts on first use, survives reloads and Bestiary resets, and keeps all events with newest-first pages of 50. Earlier events cannot be reconstructed. Transfer entries record the other character, creature, rumour count, Knowledge cost and outcome, including retries and failed delivery.

The gold cog immediately left of **?** opens **Options**, containing all settings
and **Reset Bestiary**, **Backup Bestiary** and **Restore Bestiary**. **?** opens instructions and About. Both buttons toggle
their page and close the other page when switching between Help and Options.
Both pages share the last top-left position, so dragging either page also sets
where the other opens. Help includes a separate **Knowledge** block with sections
for earning knowledge through discovery and kills, and using it to share creature information.

**Backup Bestiary** saves a dated copy immediately and opens the backup window.
It keeps the five most recent manual backups for the active account-wide or
character Bestiary; saving another replaces the oldest. Backups survive Reset
Bestiary. They include creature records, abilities, damage observations, notes,
locks, rumours and knowledge history.

For a separate copy outside the game, select **Export selected**, press Ctrl+C,
and paste into a text document to save. This includes personal creature notes.
In-game backups use the addon's saved files and cannot protect against losing
those files; log out or reload normally to save them to disk.

**Restore Bestiary** opens the dated list. Select a backup and review its date,
source and record counts, then choose **Restore this backup** and confirm.
To use an exported copy, choose **Import a backup**, paste with Ctrl+V, and click
**Preview import** first. Invalid, incomplete or unsupported text is rejected
without changing the journal. Portable backups support up to 4 MiB of text.

Restore replaces creature records and saves the displaced records as **Before
last restore**, a separate recovery copy that can be selected to undo a mistake.
Current settings, Event log and active offers remain intact. Knowledge history is
combined without repeating credited milestones or refunding spent knowledge.
Restores are available outside combat and need no reload to take effect.

**Filter: Locations** fits its content up to 15 rows, then scrolls using the same
parchment scrollbar styling as Help and Options. **Filter: Rank** and **Observed
offenses** use compact windows with comfortably spaced controls.

## Bestiary

**Locations**, beside **Notes**, opens the selected creature's zone map.
It starts at the book's right edge with aligned tops and follows **Always attempt
to anchor to main window**. Its greyscale parchment and zone dropdown stay 66% darker than UI background
brightness; the separate map slider changes only terrain brightness.
A single known zone appears as a heading; multiple zones use a dropdown. The map
uses the client's own artwork and explored terrain. Kill locations begin with
new credited kills after this update; old totals have no coordinates to recover.

The **Tracking: Kills / Observations** button beside Map brightness switches
between violet kill positions and cyan observation positions, each with a bright
border. Both layers record independently of which one is displayed. Observation
tracking records **your position when you target the creature**, including from
the air. Hovering, the mouseover-open keybinding and repeated background scans
do not add observation points. These positions describe where
you observed the creature, not its exact position. The selected layer is saved
per character; unavailable coordinates never prevent the entry itself being added.

Readable creature coordinates are preferred. When those are unavailable, the
addon uses your position when the kill is credited and labels it **approximate**.
Hover a dot to see its coordinates and whether it is approximate. If neither
position is readable, the kill still counts but receives no map marker.

One or two distinct positions remain dots. Three or more nearby positions can
form translucent triangles with a soft glow around their outer
boundary, with every edge limited to **180 yards**. The window's **Map brightness**
slider adjusts only the terrain underneath (20–100%, default 80%); markers and
areas retain their brightness. This preference is saved per character.
Distant groups and isolated points stay separate; points in a straight line
remain dots. Areas estimate kill locations or observer positions, rather than
an exact spawn boundary. Repeated samples at the same coordinate share one marker.
Each layer keeps up to 256 recent distinct positions per creature per map, across 64 maps.
Maps without a readable yard scale display dots only.

Location history follows the active account/character Bestiary, is included in
backups, and is removed with its creature entry. It is not sent in shared reports.
Older zone names use the client's map hierarchy when the name is unique. An
ambiguous or unavailable map may need another observation in that zone. Close
with Escape or the window's X; closing
the Bestiary also closes its Locations window.

**Account-wide tracking** is enabled by default in Options and applies to these five
journals: Bestiary, Herbs & Minerals, Traveller’s Atlas, Angler’s Almanac and
Merchant’s Ledger. Turning it off uses this character’s separate journals.
Treasure & Salvage and Lore & Landmarks each use their own per-character store.
Changes apply after `/reload`. Shell appearance and Bestiary display options
remain character preferences; each other section keeps its browsing state with
its active journal.

Each additional section merges the character’s existing data once into
`AzerothFieldbookAccountDB.sections`. Original character databases remain intact.
Gathering combines resource observations; Atlas preserves records and remaps
route/place links; fishing combines identities while retaining distinct catch
facts; Ledger preserves distinct contact identities and references. Repeated
logins do not repeat imports. Opting out returns to the original character
journals; later edits in the two modes remain independent after their first
import. Section resets, reports and Bestiary backups retain their existing scope.
Shared storage is loaded as each character logs in; it cannot read an offline
character’s SavedVariables. Unsupported future schemas defer account migration
and leave the original data untouched.

Each character's existing journal is merged into the account journal once, the
first time that character loads with account tracking enabled. Creature records,
kills, discoveries and earned/spent knowledge combine; repeat logins do not import
them again. Abilities, traits, locations, damage records and rumours are combined.
Notes combine within the existing editor limits; existing account decisions win
conflicts. Original character journals retain all their data, including conflicting
notes and spell IDs beyond the ten-ID limit. Switching modes after the first import
keeps the two journals independent. Sharing transactions remain owned by the
character that started them, using the active journal's knowledge balance.

Target or mouse over an attackable NPC to record its readable name, creature
type, level range, location and model. Players, pets, vehicles and
player-controlled creatures are excluded.

The index supports creature-type, location, rank, review-state, text and A-Z filters.
Earned stars and crowns appear beside creature names. Personally encountered
creatures with an unknown level show a skull in that slot until a readable level
is recorded; shared-only creatures keep their question mark. Skull entries sort
above all numeric levels for maximum-level sorting (first descending, last
ascending). The information panel also uses a slightly larger skull raised by
2 pixels to align with the text.
Hover over an overflowing
name to slowly reveal the full text; leaving the row resets it to the beginning.
Bestiary **Locations** lists zones, using the client’s parent zone map when
available. Hover an individual zone name in the creature summary to see the
sorted subzones from which that creature was observed. These are observer
locations, not exact creature positions. Fresh subzone observations are retained
while an entry is locked; they do not award extra zone-discovery Knowledge.
Subzone history survives backups and account-wide merges.

Existing location data is repaired where a subzone’s parent zone is supported by
recorded evidence. This includes Sentinel Tower when Westfall is also recorded
as a location or observation/kill map. Known associations learned from later
observations can repair other entries with matching zone evidence. Repairs also
update locked location snapshots and discovery-credit keys, preserving earned
Knowledge. Ambiguous old names remain intact rather than being guessed or deleted.
Reports continue to share zone names only; private subzone history is not added
to the sharing protocol.

Creature tooltips also show recorded kill counts by default, including on
unlocked entries. Toggle **Show kill count in creature tooltips** under Options
→ **Tooltips and cast IDs** to hide them; the preference is saved per character.
The square arrow beside Search opens **Sort**, with **Name**, **Kills**, **Max
Level**, **Min Level**, and **First Encountered** and separate **Ascending** / **Descending** choices.
It defaults to **Name / Ascending** and remembers your character's selection.
First Encountered sorts oldest first when ascending and newest first when descending.
Skulls count as the highest maximum level; other missing levels or encounter
dates stay last in either direction. Previous/Next follows the same
order as the filtered index.
The **Index** button starts red with the letters hidden and no letter filter.
Click it to highlight the button and reveal all 26 letter buttons. Click it again
to hide the letters and clear the letter filter, restoring the full creature list
within any other active filters. Letters without entries matching the current
filters are grey and unclickable. If filtering empties the selected letter, its
letter filter clears automatically.
Filters combine. Totems, gas clouds and entries with unreadable or unspecified
creature types share the **Other** filter.

Each creature entry can contain:

- Confirmed and pending observed abilities, optional field notes and effect tags.
- Optional exact spell IDs, hyperlinks or names resolved through the client.
- Personal damage observations with separate player and creature levels. Equal-level records are recommended; other levels are supported.
- Observed offensive spell schools, resistances and immunities.
- Observed disposition, combat style and behavioural traits. A separate Tameable portrait badge records explicit game tooltip information (English clients, when revealed by the game, such as Beast Lore). Missing or unreadable data remains unknown; previous manual marks do not establish this badge.
- A deduplicated kill counter based on tag eligibility for a recently observed
  creature. Eligible deaths count regardless of who lands the killing blow,
  including pets, party and raid members, or outside help. Mob level, XP, actual
  loot drops and the group's loot distribution do not gate credit. Denied tags
  do not count. Death and readable eligibility must belong to the same creature
  GUID; first discovering an old corpse cannot add a kill.

Magic schools are color-coded in the creature summary. Creature observations
remain manual where the client does not expose reliable addon-readable evidence.

The exact English monster emote **"attempts to run away in fear!"** can record
**Flees at low health** automatically for an existing personal entry when the
client supplies readable text and sender. A readable creature GUID identifies
the entry directly; if the GUID is absent, the sender must match a currently
watched, readable creature with no conflicting personal IDs. The summary and
Behaviour panel show it in blue with **[A]**, and its checkbox tooltip explains
the source. Player chat, ambiguous names and restricted payloads cannot establish
the behaviour. Unchecking removes the mark until fresh automatic evidence
restores it. Previously observed behaviours retain their cyan **[A]** provenance
when unchecked or rechecked. Backups and account merging preserve that history;
recipients receive normal unverified Rumours, not automatic confirmation.

**Hostile** and **Neutral** use Blizzard's tooltip red/yellow reaction colours
in basic information, based on
the watched creature's readable reaction to you. They have no Behaviour checkboxes
or **[A]** marker. Fresh observations quietly update the single disposition, even
on locked entries, without chat or Event log notices. Unknown, restricted and
friendly reactions are skipped. Existing client-verified marks migrate into this
field; old manual marks require a fresh client observation. Disposition reflects
your own observations and is not offered as a shared behaviour claim.

Each **Level Range** number uses Blizzard's creature-difficulty colour relative
to your effective player level: grey, green, yellow, orange or red. Range endpoints
are coloured independently and refresh when your level changes, including on
locked pages. Unknown levels retain the skull; unavailable colour data leaves
the recorded numbers readable without colour.

**Locations** use the minimap's territory colours: green for friendly, amber for
contested, red for hostile/arena and blue for sanctuary. Other readable territory
types use the minimap's normal font colour. Zone status is learned quietly as
you visit, stored separately for each faction, and retained through backups and
account merging. Older or shared locations remain uncoloured until their territory
has been observed for your faction. Subzone PvP overrides do not recolour a whole
zone; restricted or unavailable data is ignored.
Automatic behaviours and verified abilities can update locked entries; manual
editing still requires unlocking.

Each newly automatic or restored behaviour or ability produces one chat notice and one
Event log record naming the creature and observation. Repeated evidence produces
no duplicate notices, including after reload. The discovery/Knowledge chat
settings do not suppress these automatic-record notices.
If a flee message does not record, `/fieldbook debug` now reports monster-emote
counts, readable flee matches and the last decision: missing identity, restricted
data, ambiguous matches, missing personal entry or already recorded.

**Automatically record verified creature abilities** is on by default under
Options → **Ability recording**. Enemy casts with readable spell IDs are confirmed
automatically, including during combat, for an attackable target or mouseover.
Cast starts, channels, empowered casts, successful instant casts and ongoing casts
provide evidence. An interrupted cast still shows that the creature attempted
the ability. Readable buffs are also recorded, outside combat. Both receive their
spell IDs and a light-blue **[A]** marker with a tooltip explaining the source.
Pending matches become confirmed; manual notes and tooltip choices are preserved.
For buffs, the marker means the buff was present on the creature; its caster may
be unknown. Buffs with a known different caster are skipped.

Buff capture requires both you and the creature outside combat.
Player-controlled units and restricted data are skipped. While enabled, a fresh
verified observation restores a removed or rejected ability, including old
name-only removal flags. Turn the option off to keep a verified ability removed.
Each newly recorded or restored ability produces a chat message and an Event log
entry with its creature, name and spell ID; repeated scans and reloads are silent.
Existing records and the setting persist across reloads; disabling the option
leaves records intact. A previously disabled buff-recording preference also disables
automatic cast confirmation. Name-only casts, historical encounter imports and
casts seen with the option off retain the existing pending-review behavior.
An ID visible in the spell window can still be restricted to display only; the
addon cannot save it or infer it from hidden data. Capture works with the window
hidden. Buff capture retries
after combat, on target/mouseover and aura changes, and once a second while watching
a creature. Editing and saving an automatic entry makes it a personal note.

Confirmed abilities appear in NPC tooltips whether the creature entry is locked or
unlocked. Each ability checkbox toggles its tooltip display and defaults to on;
the checkbox remains available while the entry is locked. Existing OFF choices
are preserved. Pending and rejected abilities remain hidden; locking or unlocking
an entry does not change tooltip visibility. Resolved abilities include their spell
icon on the left when available. Hold Ctrl while hovering over a creature to
expand available spell descriptions beneath the ability names; release Ctrl to
collapse them. A grey **(Ctrl for details)** hint appears when a displayed ability
has readable details. Unresolved abilities remain name-only, and unavailable or
restricted descriptions are omitted.

The **last detected enemy ability** hint beneath the optional spell ID field
shows the latest cast's name, ID and local date/time for that creature. It remains
when changing targets or pages until another cast replaces it or you record the
ability. Hover attempts to show its spell tooltip where the client permits it.
Readable IDs already recorded are hidden. For restricted IDs, saving a linked
ability clears the current hint, but a later cast can show it again because the
addon cannot compare restricted IDs against saved spells. Hints last for the
current session only and disappear on reload/logout. They work with the Spell ID
window hidden and automatic recording off.

The **Spell ID window** shows only populated sections and grows upward from its
bottom edge. Caster names appear when available; unknown casters leave no extra
line. Right-click a section to dismiss it. Ctrl+Right-click also adds a readable
ID to this character's blacklist. Manage the list, remove entries or add numeric
IDs through **Options → Tooltips and cast IDs → Spell ID window blacklist**.
Blacklisting affects this display only, leaving journal recording unchanged.
Restricted IDs cannot be compared against the blacklist, even when entered
manually; Ctrl+Right-click dismisses the section and opens the manager with that
limitation explained. Empty windows retain the header unless auto-faded.

Locking protects manual edits, pending observations and the displayed basic snapshot.
Client-verified disposition continues to update quietly.
Fresh automatic **[A]** abilities and behaviours can still be recorded or restored.
Knowledge from kills and discoveries continues while locked. Unlock to resume manual editing.
Personal ID Logs and Notes remain editable while locked.

On an unlocked entry, **Resolve** beside an ability looks up its recorded spell
ID (or exact name) outside combat and confirms it in one step. The ability adopts
the spell's canonical name and tooltip, removing its pending and automatic-origin
labels while preserving personal notes, effects and tooltip visibility choices.
Unreadable spells leave the record unchanged. Resolve is hidden once the ability
is confirmed with a spell ID; pending or unlinked abilities retain it.

Delete removes the selected creature and its saved records after you type
`delete` and press Enter. Hover over the creature again to add a fresh entry;
the Event log calls this **Entry restored**, with no repeat discovery award. Previously
credited milestones and spending survive deletion, so deleting and rediscovering
an entry cannot repeatedly earn its knowledge. Ability effects include
school-specific resistance and immunity tags, plus effect immunities including
Fear, Polymorph, Bleed, Stun, Root, Snare, Silence, Interrupt, Poison and Disease.
Use **Defenses → Effect immunities** to open the checkbox dropdown and record
or remove an immunity you have observed. The main window keeps school defenses
visible. Burning Fire-damage effects use the existing **Fire → Immune** checkbox;
there is no separate generic Burn entry.

**Options → Expected immunities → Show expected immunities** defaults to OFF.
This is optional type-based guidance, not knowledge your character has observed.
When enabled, personally encountered Mechanical creatures show expected **Bleed**
and **Fear** immunity. Known types other than Humanoid, Beast or Critter also show expected
**Polymorph** immunity. Unknown/unclassified types produce no Polymorph suggestion.
The summary says **Expected Immunities:** and checkbox labels carry **[Type]**.
Uncheck an expectation on an unlocked entry to override it; the choice survives
reloads, backups and account merges. Checking it again records your own immunity
mark. Hiding expectations preserves both recorded marks and overrides.
Expectations are excluded from shared reports; explicit marks are shared as
unverified rumours. An unmarked effect means unknown.

Mechanical guidance follows the general Classic rules described by
[Mechanical](https://warcraft.wiki.gg/wiki/Mechanical) and
[Fear effects](https://warcraft.wiki.gg/wiki/Fear_effect). Polymorph guidance follows its
[Humanoid/Beast/Critter targeting restriction](https://www.wowhead.com/classic/spell=118/polymorph), not a verified immunity result. Exceptions
and Forever changes remain possible. Burning effects such as
[Ignite](https://warcraft.wiki.gg/wiki/Ignite_%28Classic%29) deal Fire damage.

Each personal creature discovery awards 1 knowledge once the client exposes a readable effective level, including the zone of that observation. Unknown level ranges display a skull. Flying and flight paths require active targeting or the mouseover-open keybinding; passive mouseovers cannot record observations from the air. Explicit selections with readable identity and attackability work beyond the visibility range. New personal entries appear in the Event log even before their level is known, including previously shared entries. Skull/unknown-level observations earn no discovery or location Knowledge. Kill counts still advance, but their milestone Knowledge waits for a personally observed readable level. Existing credited history is retained.
Discovering a new location for an existing creature awards 1 knowledge. New levels
are still recorded but award no knowledge. Previously earned balances are kept.
Repeat sightings award nothing. Ten kills award a silver star and 1 additional
knowledge; 25 kills award a gold star and 2 more knowledge; 50 kills award a gold crown
and 3 more knowledge, for 6 knowledge from kills in total. The crown replaces the star beside
the kill count. Existing personal entries with 50 or more kills receive any
uncredited crown knowledge on load. Already-earned kill knowledge remain credited when
thresholds change and cannot be earned twice, including earlier silver credit. Existing
entries retain their previous legitimate total through a one-time migration,
including saved discovery progress and legacy recorded level endpoints. The
book shows lifetime **knowledge earned**. Sharing shows **available** knowledge:
earned minus spending and active reservations. Spending never removes kills,
stars, crowns or discovery progress.

## Sharing and Rumours

Options includes **Block incoming offers**, off by default and saved per character.
Enable it to automatically decline new offers and close unaccepted offers, with
no knowledge spent by the sender. Outgoing sharing and already accepted deliveries
continue normally. Turn it off to receive offers again.

Select a creature, press **Share**, enter one recipient's **full character name**
(including their surname if they have one), and select any existing traits you
want to share from the two-column list. Self-offers are rejected before any
knowledge are reserved; matching ignores capitalization and extra spaces. Each selected rumour costs one additional
knowledge; there is no two-rumour selection cap. Names are realm-free; no realm is required or
appended. Spaces, localized letters, apostrophes and hyphens in names are preserved.
The composer captures the creature when opened; changing targets or book pages
does not change the report. Both players need this compatible development build
and must be outside combat and chat restrictions. Both players must have the
**same installed addon version**. Sharing protocol 4 exchanges the TOC version
before offering a report and when retrying a paid transaction. A version mismatch
shows both version numbers when available, sends no report data and spends no
knowledge on a new offer. The initial compatibility check shows a **20-second
countdown**. With no reply, it explains that the addon may be missing/disabled or
the player offline, restricted or lagging, releases reserved knowledge, and enables
a fresh send attempt. Silence alone is not treated as proof of a missing addon.
Native delivery to a recipient with a surname, acknowledgement,
and separate attributed imports were confirmed in game under the earlier pricing.
The new pricing and larger selections have automated coverage; remaining live checks are listed in
[tests/SHARING.md](tests/SHARING.md).

**Send offer** enables when a valid creature report is captured, enough knowledge
are available, no outgoing report is pending or unresolved, and addon messaging
is ready outside combat and chat restrictions. The status text identifies the
current blocker. Character identity and messaging registration are retried at
login and when returning to the world or leaving combat. Recipient spelling,
self-sharing and receiver compatibility are checked when sending.

| Report | Sender cost |
| --- | ---: |
| Name, NPC ID, creature type, recorded levels and locations | 1 knowledge if new; otherwise free |
| Those basics plus one unverified rumour | 2 knowledge |
| Those basics plus two unverified rumours | 3 knowledge |
| Those basics plus three unverified rumours | 4 knowledge |

Total cost is **1 knowledge for basic information + 1 knowledge per selected rumour**.
Selecting more rumours immediately updates the total and resulting balance;
insufficient available knowledge disable sending.

Individual pending or confirmed ability names (including manual abilities),
offensive schools, school resistances, school/effect immunities and behaviours are selectable.
An ability selection says only that the creature casts that named ability;
its private note and effect tags are excluded. Names containing sentence
separators are not selectable. ID Logs, personal Notes, damage, kills, stars,
locks and confirmations are never sent. Unverified received rumours cannot be forwarded. Once you explicitly verify a
claim, its personal journal record is eligible for sharing like your other records.
A spell ID identifies a spell; it is not proof that this creature casts it.

Opening, previewing and cancelling the composer are free. **Send offer** reserves
the maximum cost (1 basic-information cost plus the selected rumours). An unavailable or incompatible receiver, decline, cancellation, or
timeout **before commit** releases that reservation. After the recipient accepts,
their current journal determines whether the report adds any new basic information.
If those basics are already known, the sender commits 1 less knowledge, releases
the unused reservation, and receives a chat notice and a Share status explanation.
This also applies when the recipient has broader levels or more locations; new
or conflicting basic information retains its cost of one knowledge. Each selected rumour
still costs one knowledge. A matching basics-only report settles at zero knowledge.
The sender commits the final cost before authorizing import. A receipt acknowledgement
completes the report; an API success alone does not. A missing acknowledgement
leaves delivery **unknown**, with the knowledge still spent. Reopen Share and use
**Retry status**: the same transaction can be reconciled at most three times
within 24 hours, without a second charge. After that it can be closed as
unresolved, with no refund. A new report is priced separately.

Recipients see the sender, creature, claims, conflicts and whether the report
adds information before choosing **Accept — free** or **Decline**. Acceptance
alone does not import: the sender must subsequently commit. Shared basic reports
are stored separately from personal records. The book names their sender with
**Shared by** inside the viewer until you personally encounter the creature;
hover that label for every sender and the encounter/lock status.
Each shared report in Rumours also names its source. Sender names use their
class colour after the game identifies them as a player through your target,
mouseover or party/raid roster. Full surnames must match. Verified classes are
saved locally when shared reports arrive or source names are displayed, keeping
their colours after logout or reload. Unknown classes are filled in when later
observed; until then they stay grey, as does the Shared by
label. Received reports never supply class identity. Local names
and creature types win conflicts. A locked page retains its displayed basics;
additional reports remain available in Rumours and after unlocking.

Beast pages include **Known Beast Lore** above the **Damage taken** panel. Its
window is available even on locked entries. Casting Beast Lore on an identified
target or mouseover records the public native tooltip's revealed fields in a
scrollable box: damage, health, armour, resistances, diet, tameability, abilities
and other revealed text where the client provides it. The record includes the
observed creature level; values are a snapshot of that observation, not a
promise for every level or instance. The capture waits up to five seconds for
delayed fields and checks the original creature GUID. English lore labels are
currently recognized; hidden/unreadable information is never inspected or guessed.

Lore is read-only and shown as **Locked • Verified**, independently of the main
entry lock. Further client observations can update it. **Send Beast Lore** accepts
a full name including surname and sends an offer using the normal compatibility,
accept/decline, receipt and retry flow. It costs **0 Knowledge**, even for an
unknown creature and when the sender has no points. Receiving earns no points.
Both players need the same addon version. Accepted lore is stored directly with
sender attribution, rather than as an unverified rumour; personal observations
take precedence over received lore. Sender provenance comes from the message
transport; addon messages cannot independently authenticate another client's
observation. Lore survives reloads, account migration and backup/restore.

The damage panel gives up one button row to make room for the Beast Lore button;
the rest of the page and all non-beast layouts retain their positions. Beast Lore
progression rewards remain future work. See [in-game checks](tests/BEAST_LORE.md)
for the capture and delivery checks still required on the live Forever client.

Click **Rumours** between the kill counter and **Notes** to open a
separate window for the selected creature. Click it again to close the window.
It uses the book's parchment, brightness and scale settings, with dragging,
screen clamping, a top-right Close button, Escape and a bounded scrolling list.
Creature Notes keeps its own ID Logs and Notes.

Every received claim starts unverified and is attributed to the actual sender's
full character name, including any surname. Hover a row for its source details.
Click its **green tick** when you have verified the claim: it becomes a confirmed
ability or the corresponding offense, resistance, immunity or behaviour in your
personal journal. Existing ability notes, effects and tooltip preferences are
preserved. Unlock a locked entry before verifying. Confirmed abilities use the
normal ability-confirmation and tooltip-checkbox rules; accepting a report alone establishes no traits.

Recording matching data manually or confirming an observed ability removes all
matching rumours, across senders. Ability matching uses the name (ignoring case
and extra spaces) or a shared spell ID. Reports of facts already in your journal
do not add new rumours. **x** rejects a rumour and remembers that decision.
A later report of the same claim shows **Previously rejected** in the incoming
offer and the Rumours list, even from another sender. Shared basic reports are
also listed there so conflicting or locked information remains inspectable.

Receiving and rumour edits award **zero** knowledge. A later genuine encounter can
still earn the first personal discovery and previously uncredited levels/zones,
even if the report already contained them. Normal reloads preserve earned credit,
spending, accepted incoming reports and receipt deduplication. Uncommitted outgoing
offers are cancelled on reload; committed ones become unknown until retried.
Both existing full-reset paths intentionally erase the journal, credit ledger,
spending, rumours and transfer history, and cancel in-memory transfers. Normal
entry deletion retains the ledger and transaction receipts.

Reports retain the 2,048-byte and eight-location limits; an oversized report is
refused rather than silently shortened. Storage permits 500 creatures with shared
records, sixteen basic reports and 32 rumour records per creature (including
review history), three incoming transfers, and 512 recent transaction receipts.
Active duplicate claims from the same character are suppressed; different sources
keep their own attribution. A new report of a previously rejected claim reuses
its existing source record and is flagged for review. There is no copy/paste export in this first version.
SavedVariables cannot provide crash-proof delivery or resist edited saves/clients.

The ? menu includes account-wide UI scale (50–150%, default 100%), applied when the slider
is released. The minus and plus buttons beside **100%** apply five-percentage-point
changes immediately, so you can adjust scale without dragging the slider.
The account-wide Text size slider offers seven one-point steps from -3 to +3,
centred on Default (the existing fonts at 100% UI scale). It preserves the
relative sizes of headings and body text. Choose **Apply / reload** to apply it;
**Default** restores the original text sizes. UI scale remains independent.
Offenses, Defenses and Behaviour share a position and replace
one another by default; disable that option to keep multiple windows open.
Knowledge award chat messages are enabled by default and can be disabled. Discoveries
and their knowledge awards share one Bestiary announcement, using the creature's
resolved name and observed type, level and location; unavailable details are
omitted. Kill rewards show the name and type with 10/25/50-kill milestones.
The addon prefix is cyan, bracketed rewards are yellow and parenthesized details
are grey. With knowledge messages disabled, the separate discovery setting can still
show a discovery notice without its knowledge amount.

Sharing combines the first name and surname returned separately by Forever's
character-name API, keeping the full name for self-offer and recipient checks.

If an incoming report is rejected before its preview appears, the sender now sees
which check failed: incoming blocking, a full queue, report chunks/data, recipient
identity, timestamps or storage limits. The recipient's Event log records the
reason, including local validation details. Rejection before acceptance spends no
Knowledge. Both players need the updated build for these diagnostic replies.

The creature list displays sixteen rows down to Previous/Next, with a scrollbar
in a reserved gutter when more entries match. Its track is 70% transparent.
Green creature names indicate outstanding rumours, including on a selected page;
verifying or rejecting the last rumour restores the usual name colour. The grey
legend beneath the list explains the green indicator and review asterisk.
The Rumours window sizes its width to the report text, wrapping long lines at a
comfortable maximum. Each rumour starts with a green verify tick, then a reject
cross, then its text. It fits up to four rumours and their shared basic
information before scrolling longer lists; subtle dividers separate records.

## Spell IDs and personal notes

The target cast bar can display **Last Spell ID**. It remains for up to one
minute, clearing when the target changes, another cast starts, or you right-click
it. **Display Cast IDs** is enabled by default in the book's ? menu.

A separate movable **Last observed spell IDs** window shows the latest enemy
cast, identifiable instant cast, debuff on you and buff on a non-player-controlled
NPC target. It starts enabled and unlocked with 35% background opacity. Entries
expire after two minutes unless **Display Spell IDs in the ID window indefinitely**
is enabled. Aura effect types are shown when available.

**Retain hovered aura tooltips** is off by default and available as an optional
fallback; existing saved choices are preserved. When enabled, it keeps a compact
historical snapshot of accessible
buff/debuff tooltips after hovering. Right-click to dismiss it; durations are
historical text, not a countdown. This option is enabled by default and shares
the ID window's expiry setting. Combat restrictions can block enemy aura queries
or protected native tooltips, so not every buff or instant ability can be shown.
Displayable secret values are passed directly to UI text; they are not inspected
or saved as observations.

Use **Notes** beside the selected creature's name, or `/fieldbook notes`,
to open its **ID Logs and Notes**. Its heading includes the creature ID in grey,
for example `Elder Black Bear [#1234]`. **First encountered** appears beneath the
name, showing the earliest recorded personal encounter in your local date and
time. This date survives repeat sightings, locking, reloads, deletion/re-encounter,
account migration and backup restores. Older dates are recovered from scored
discovery events when available; otherwise existing personal records show
**Unknown**. Received reports show **Not personally encountered** until you
observe the creature yourself.

Enter up to ten spell IDs to create spell links;
remove rows with the red x. Each creature also has a 400-character personal notes
box. These records persist per creature and do not automatically confirm abilities.
**Show spell IDs on tooltips if possible** controls IDs on supported aura tooltips,
journal ability tooltips and these spell links. Turning it off keeps the spell
tooltips themselves available.
Creature notes follow eligible target selections by default, without opening
a closed window or changing the selected Bestiary page. Disable this in Options
to follow only manual selections. Pin prevents Close and Escape from dismissing
the notes window.

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Automatic observations

Readable target or mouseover casts become pending field notes. Supported
post-combat damage-meter records may also contribute abilities when an NPC can be
attributed safely within the same encounter, even without targeting or hovering
over it. These entries retain the meter's readable creature name; level, type and
location still require direct observation. Automatic abilities require a usable
name and a journal entry. Ambiguous, incomplete, secret or unreadable records
fail closed.

Old nameless entries stay hidden from the index and entry count until a direct
observation or attributed encounter identifies them. Their observations, notes,
review decisions and previously earned credit are preserved. Legacy ability-only
records wait for identification before creating a creature entry.

The addon does not inspect hidden spell data, ship a spell list, change damage
meter settings, or read disk combat logs.

## Commands

- `/fieldbook`: open or close the Bestiary.
- `/fieldbook status`: show observation totals and scan status.
- `/fieldbook encounters`: show encounter import diagnostics.
- `/fieldbook scan`: retry encounter imports outside combat.
- `/fieldbook notes`: open personal ID logs and notes for a creature.
- `/fieldbook debug`: open diagnostics in a foreground window with all text selected; press Ctrl+C to copy.
- `/fieldbook debug on|off`: enable or disable additional diagnostics.
- `/fieldbook alerts`: toggle local discovery messages.
- `/fieldbook wipe`: begin the destructive reset confirmation.
- `/fieldbook wipe confirm`: erase the active account or character Bestiary and
  the current character's settings within
  60 seconds of the first command.
- `/fieldbook wipe cancel`: cancel the pending reset.

The legacy `/bestiary` command accepts the same arguments.

## Data compatibility

Version 0.17.0 stores Bestiary account progress in `AzerothFieldbookAccountDB` and character
settings and separate character progress in `AzerothFieldbookDB`. Each database
keeps its journal in `bestiary`. Reset clears only the active journal and current
character's settings, preserving the tracking mode, one-time migration markers,
Event log and backups. Backup archives live alongside `bestiary` in the active
database, so account and character backups remain separate.

Merchant’s Ledger adds schema 1 in per-character `AzerothFieldbookLedgerDB`.
Account-wide tracking selects the shared Ledger store; the character store
remains intact. Ledger resets and reports remain independent of other journals. Contact knowledge, private notes, favourites and browsing
preferences survive reloads. A newer unknown Ledger schema stays untouched
and opens read-only. No existing character database is repurposed or cleared.

Treasure adds schema 1 in `AzerothFieldbookTreasureDB`, independently of account
tracking, resets, backups and the other journals. Kinds, encounters, provenance,
notes, bookmarks and browsing state persist. Active loot correlation is session
only. Malformed records are preserved but excluded from the view with a notice;
an unknown future schema uses a detached read-only view. Capacity limits refuse
new records without discarding detailed history or notes.

Lore adds schema 1 in `AzerothFieldbookLoreDB`, independent of account tracking
and the other journals' resets and backups. Preserved pages, provenance,
annotations, reports and browsing positions survive reloads. Capture sessions
are temporary and never resume against stale text after reload. Loading missing
settings defaults preserves explicit OFF choices; Bestiary reset preserves both
Lore capture preferences. Unknown future Lore schemas open read-only without
rewriting their saved data. See [Lore data and validation boundaries](tests/LORE.md).

The previous binding action IDs remain registered behind the newly branded
binding labels, preserving assigned keys across the rename.

## Verification

On 2026-09-27, the author confirmed that pet kills award credit correctly and
that the Forever SavedVariables bug is fixed: data and settings persist across
reloads/logins. Earlier research notes describing those checks as blocked or
unverified are historical. In-session sharing delivery and attribution were
also verified during Beta development.

**Lore & Landmarks has not been verified in the actual Forever client.** Its
capture state machine, journal, reports and widgets have automated coverage and
static review. The Classic ItemText reference is compatibility research, not a
Forever live pass. Whole-book traversal, source attribution, reader restoration,
dialogue surfaces and native layout still require the [Lore checklist](tests/LORE.md).

**Beast Lore remains pending live verification** until the Forever beta level
cap allows testing the spell. Its automated tests use public-tooltip mocks;
they do not establish live capture, rendering or two-player lore delivery.
See the [current verification record](tests/VERIFICATION.md) and
[Beast Lore acceptance checklist](tests/BEAST_LORE.md).

Python/lupa tests run the addon using Lua 5.1. They cover observation boundaries,
kill attribution, discovery credit, account migration, notes, abilities,
backups/restoration, sharing and retries, Rumours, window controls, positions,
scaling and section navigation. Native rendering and client restrictions still
require in-game observation. The shell extraction preserves the current Bestiary
layout; its final visual smoke check remains an in-game check.

To run the complete suite from the repository root with Python 3.12:

```text
python -m pip install -r tests/requirements.txt
python -B -X utf8 tests/run_tests.py
```

The runner validates Lua syntax, TOC contents, bindings and release-version
consistency, then runs every `test_*.py` script in a separate process. GitHub
runs the same checks on `main` pushes and pull requests. A release tag runs them
again on the tagged commit; packaging and GitHub/CurseForge publication start
only after they pass.

Section integration is described in [the architecture notes](tests/ARCHITECTURE.md).

## About

Created by Spinkler

Developed with AI-assisted coding tools.
Design, direction, testing and final development decisions by the author.

Bestiary defaults to automatically observed drops; Show Damage toggles the panel to damage records and back. Loot is displayed, with icons, tooltips, quantities and corpse drop percentages. Rates use readable creature loot sources, including money-only sources, rather than all kills. Empty or unavailable loot is not inferred. The most recent 128 corpses per creature are deduplicated across openings and reloads.

Gathering map positions for the same resource and map are kept more than 10 yards
apart. Existing nearby positions are merged on load where map dimensions are
available, retaining a stable position and the latest observation time. Different
resources remain distinct; counts and notes are unchanged.

Creature loot lists group leatherworking materials under **Skinning** after other
drops. This uses item categories, including for older records; the original loot
method was not recorded, and the displayed observed rates remain unchanged.
