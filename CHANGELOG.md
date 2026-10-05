# Changelog

## v0.29.0 - 2026-10-05

Release-channel update covering the complete batch since v0.28.0 and previous-push baseline 788bec9b1776c1668de193d2a19c53b0d62a0dbf.

- Add Current Zone at the top of the Annals zone selector to switch to the player's current map without changing playback time or filters.
- Widen Treasure Journal's observed-contents container header to match the button above it, giving the container name the additional space.
- Let Annals Show detail follow the playhead event when no item is manually selected; click a selected event again to deselect it and resume following.
- Retry missing location metadata on new Annals login records for up to ten seconds while retaining their original timestamp; stop retries on leaving-world/logout and leave historical entries unchanged.
- Mark the latest filtered Annals event at or before the playhead with a soft cyan highlight using the hover's fading texture, updating during playback and scrubbing independently of hover and selection.
- Put Annals scrubber coordinates beside the timestamp, with a grey Last sample: date/time on its own second line, using the recorded sample time even during estimated movement.
- Scroll clipped Annals event titles gently on hover while retaining their original styling, and show full event/date/location metadata in a row tooltip.
- Group Annals custom playback speed with the preset speeds in a compact field with an x suffix; move the range menu to the right and show elapsed time from the scrubber's start / total span above it, with seconds below one day and days/hours/minutes for longer timelines.
- Remove default-state parentheticals from Options labels without changing the saved settings or defaults.
- Extend Annals regression coverage for playhead details and highlighting, login-location retries, hover scrolling and elapsed-time formatting; update playback validation guidance.

## v0.28.0 - 2026-10-05

Release-channel update covering the complete batch since v0.27.0 and previous-push baseline e8a87605af69890f8967e35c3ac5a526ef663626.

- Add a master AFB tooltip toggle, on by default, retaining individual choices and gating the client-wide aura spell-ID preference.
- Separate automatic spell/ID chat feedback from discovery announcements; spell feedback starts off. Explicit commands and manual assignment responses remain available.
- Require verified NPC sources for player debuff and Loss of Control observations; exclude player-controlled and unidentified sources from spell-ID display, and fail closed on unavailable cast-overlay ownership.
- Update regression coverage for source exclusion, NPC provenance, opt-in spell announcements and retained tooltip preferences.

## v0.27.0 - 2026-10-05

Release-channel update covering the complete batch since v0.26.1 and previous-push baseline b7561e13c592b86db530daa50a8a48be9737eeac.

- Add matching event icons beside Annals filter labels in both timeline and map filter menus.
- Record Annals Login and Logout events with separate timeline/map icons, filters and Journey legend entries. Preserve the observed logout time and location until the next real login confirms it; discard provisional logout markers on UI reload and keep offline gaps disconnected. Crashes and forced disconnects may leave no logout marker.
- Add the red Dead / ghost trail swatch to the Annals Journey legend, using the actual trail colour and fitting all six trail examples within the existing overlay.
- Use the existing button highlight outline on Almanac and Treasure expand/collapse arrows only while expanded. Darken the shared footer gold and apply it consistently to their detail borders/dividers and the Ledger and Annals dark footers.
- Show recorded quest text and objectives for Annals Completed Quests as for Accepted Quests. When turn-in text is unavailable, preserve text from the same observed acceptance cycle; older missing records remain explicitly unknown.
- Format Almanac details and Treasure summary, history and notes with gold headings, cyan labels, muted guidance and metadata, and fading dark gold entry dividers. Match both detail-window borders to the dividers and retain scrolling, selection and provenance.
- Hide zero kill counts and remove the AFB: Bestiary heading from creature tooltips.
- Replace the Almanac's ambiguous list help text with guidance on the Waters, Pool Types and Catches tabs. Extend the list and align Merge spot and Restore with the other journals' lower button row.
- Extend regression coverage for detail formatting and data preservation, completed quest text and cycle boundaries, session recording/reload suppression, event filter icons and legend colours; document session capture and remaining native acceptance checks.

## v0.26.1 - 2026-10-04

Release-channel update covering the complete batch since v0.26.0 and previous-push baseline 3891a81bfef0d8b3c3cffa02dfc020bbb6a58a9e.

- Show recorded quest descriptions and objectives once in Annals Accepted Quest details alongside location and reward data. Preserve paragraphs and observed text through reward retries and reloads; older entries explicitly indicate missing text.
- Fix Classic acceptance events using the quest-log slot instead of the quest ID, which could suppress reaccepted quests and associate acceptance data with the wrong quest. Simplify XP and money display by removing redundant labels.
- Add an Annals chronology toggle beside the filter, defaulting to newest first at the top each session. Keep paging, Latest and Now consistent with the selected order while preserving historical data, selection and playback.
- Put date/time above position, state and level in the Annals map footer with 1-pixel line spacing. Expand Details by 72 pixels and align Around event, Quest interval and Open linked journal above Refresh on the shared 34-pixel button rows.
- Add right-click reset and tooltip guidance to all ten journal filter funnels, including Bestiary loot, Atlas layers and both Annals event filters. Centre entry counts beneath journal headings.
- Match Treasure Edit and Ledger Edit, Record contact, Share and Delete to the Almanac/Chronicle Share button dimensions (120 × 24). Left-align the Almanac session status with the right pane.
- Style Chronicle Entry & personal notes with a gold title, cyan section headings, muted metadata and spaced body text while retaining distinct source readers.
- Accept zero-quantity coin slots from a confirmed Treasure loot source without discarding accompanying item contents. Preserve the original capture failure reason after autoloot clears the window and include rejected source identities for diagnosis. The reported Redridge Battered Chest source-identification failure remains unresolved; retain it in validation notes for the next opportunistic observation.
- Extend regression checks for quest capture/reacceptance, text deduplication, chronology, filter resets and mixed coin/item loot, and update layout expectations and Treasure validation guidance.

## v0.26.0 - 2026-10-04

Release-channel update covering the complete batch since v0.25.0 and previous-push baseline 0a3c5121ecf9db331a2cc3aa680542eaead2a7a7.

- Add sliding information overlays to Treasure Journal and Angler's Almanac, with controls above the text, top-right expand/collapse arrows, matching dark parchment and thin borders, aligned full-height scrollbars, and scrolling edge fades. Apply the matching footer size, position and styling to Ledger notes and Annals controls; keep status text below the box.
- Improve Treasure list spacing, enlarge contact names and the Observed contents header, remove technical IDs from list tooltips, move Kind notes beside Delete as Edit, add a Container type reset, and standardize Save / Back labels.
- Add header-style portraits beneath Ledger contact names and tags. Label personal notes, automatic services, manual annotations and reports clearly; use cyan labels, larger footer text, extra padding and automatic services first. Standardize Edit's Save / Back buttons.
- Make Bestiary Index letters jump through the list instead of filtering it, with fading dividers between letter groups. Reopening preserves the previous entry, then falls back to a known target before showing the blank page.
- Organize Options with fading dividers and consistent section spacing. Add Reset entire Fieldbook with two confirmations and deletion on fresh reload, covering account-wide data, this character's journals/settings and saved backups. Other characters' separate saves remain and may import again.
- Move Current Zone into the first zone-menu option in Atlas and Almanac. Make Annals' play/pause button square, reduce the pause symbol and widen its speed buttons uniformly.
- Replace convex-only Atlas cleanup with budgeted cumulative simplification for both fill methods, including edge samples, within a 5-yard outline tolerance. Protect narrow passages, shared borders, manual points and crossings. Retain compact coverage so repeated cleanup cannot accumulate error or repeatedly record removed samples; preserve it through account imports and whole-Fieldbook backups.
- Improve cleanup performance through geometry reuse, early rejection and disjoint-segment checks while retaining the 1 ms frame budget. Correct overly broad overlap exclusions, report reasons points remain, retain the last breakdown in the cleanup tooltip and refresh storage estimates after cleanup. Automatic periodic cleanup remains disabled.
- Reduce automatic interior survey spacing to 25 yards and remove obsolete sample timestamps without changing discovery or Annals dates. Pause survey points and crossings while dead or a ghost, then resume without drawing a crossing across the corpse run.
- Move Legacy Fill to Atlas Options, off by default, with its CPU/detail tradeoff explained. Restrict world-map sub-zone labels to local maps and hide stale overlays when changing maps or zooming out.
- Add an estimated Atlas archive-size counter beneath Share, including survey/crossing counts and average bytes per point, measured with the shared background work budget. Move Bestiary's knowledge counter beneath Share.
- Consolidate duplicate personally observed flight-master contacts at matching nearby locations, retaining evidence, notes, favourites, GUID aliases and historical references. Reuse identities across spawns/layers, persist migration completion and recheck after character imports.
- Shorten Bestiary and minimap tooltip headings, remove the Behaviour prefix in favour of sage-coloured text, and remove the obsolete Bestiary keybinding hint and handlers.
- Expand regression coverage for cleanup geometry, storage, reload/import/backup preservation, Ledger identity migration, footer navigation, Index behavior and full-reset staging. Include Atlas cleanup implementation/rollback notes and an optional synthetic benchmark.

## v0.25.0 - 2026-10-04

Release-channel update covering all changes since v0.24.1 and previous-push
baseline e619c7242777ab754f88a06243563fcf5cffbf6a.

- Update the Treasure documentation to describe automatic world-container capture and its attribution limits; remove the stale Beta label from the README introduction.
- Add regression coverage for container attribution and autoloot, Ledger identity reuse and flight-path discovery, journal scrolling and selection, world-map label controls, chat announcements and Annals death-state trails. Update Ledger and Treasure validation guidance.

- Discover Merchant's Ledger Transport contacts when a flight path is learned, without waiting for the flight map to open.

- Match shared entry dividers to the vertical page divider's warm brown colour and 35% opacity, preserving their fading edges.

- Align shared entry dividers to physical pixel rows and a consistent pixel thickness so scrolling and selection changes do not alter their apparent weight.

- Hide the dividers directly above and below selected Ledger and Annals entries so they do not clash with the gold selection border; restore them when selection changes.

- Show the shared gold selection border on the selected Annals timeline entry, updating it as selection and visible rows change.

- Add matching fading dividers between Ledger contacts and give Annals timeline text more top and bottom padding inside its highlight rows.

- Make world-map sub-zone labels follow map zoom and default to size 14, with an independently saved Label size slider shown only while Labels is enabled. Place the background-free control at the map's top-right with edge padding, shadowed text and a black slider track. Traveller's Atlas keeps its own label-size setting.

- Soften Treasure's fading dividers slightly and reuse them between Annals timeline entries. Increase Atlas list-row padding for easier reading.

- Give the observed-container header the journal list's gold selection outline and standardize contents dividers to fixed dimensions, colour and edge fades.

- Identify the selected container above Treasure's observed contents and separate encounter groups with thin, dark dividers that fade at the edges.

- Move Treasure's Observed contents into an independently toggled left-pane view, highlight the selected right-footer view, and place Kind notes between Encounter history and Personal notes.

- Match Treasure Journal detail-row hover highlights to the gold highlight used by journal lists, including expanded details.

- Use blue book-section labels across Bestiary, Ledger, Gatherer, Treasure, Atlas and Chronicle chat announcements, with yellow event tags, white names and grey contextual details.

- Format Ledger discovery chat as “AFB: [New discovery!] Merchant’s Ledger: Name (Role)”, with blue book labels, a yellow discovery tag, white name and grey role.

- Announce all newly recorded Ledger contacts using their service role (including trainers), gated by discovery chat logging; repeat visits remain silent.

- Fix skipped clam contents when the loot-origin flag is missing or false despite an exact observed bag-container GUID; retain source matching and separate encounters for distinct clams.

- Announce “Contents recorded” with the container name after automatic Treasure captures when discovery chat messages are enabled; repeated loot-window updates do not repeat the announcement.

- Fix skipped world-container captures when tooltips lack an object ID: correlate a fresh world click or completed opening cast with a single GameObject loot source, support omitted world-loot origin flags, and show capture failure reasons in Treasure status.

- Automatically record recognized world containers such as Weapon Crates when the observed tooltip identity matches the loot source. Preserve autoloot contents, group matching object types, and record approximate player locations; uncertain sources remain manual.

- Standardize the seven entry journals on grey “X entries • Y shown” counts beneath their titles, with aligned search/filter/sort rows. Move Gatherer and Chronicle counts into the header and keep page-specific controls below search.

- Colour Annals Journey trails crimson while dead or a ghost, distinct from walking, flight and mounted trails, including older death-state recordings and rounded corners.

- Reuse a unique nearby personal Ledger contact after a spawn GUID changes between sessions, requiring matching NPC template/name, compatible title and location precision within 0.25 map-coordinate units. Keep ambiguous and same-session identities separate; existing duplicates retain explicit identity linking.

- Extend the Treasure Journal list and replace Previous/Next with mouse-wheel scrolling and an automatic scrollbar, preserving the visible entry when records update.

- Extend the Chronicle list and replace Previous/Next buttons with mouse-wheel scrolling and a scrollbar shown only when needed.

- Double the Atlas label-size slider width for finer control. Hide Ledger offering buttons without recorded goods/training and align the available buttons to the right.

- Remove the Atlas Label size caption and position its slider immediately to the right of Labels.

- Move Atlas and Almanac Current Zone buttons directly above their zone selectors; move Atlas Clean Redundant Points to the former top-right button position.

- Make the Atlas discovery list scrollable with a scrollbar and mouse wheel, replacing Previous/Next buttons and keeping selected entries in view.

- Replace the Atlas scope label with a themed Current map toggle: off shows all recorded zones by default; on filters to the current map. Preserve saved scope choices.

- Remove the redundant > prefix from selected Atlas list entries, retaining their selection highlight.

- Enlarge player arrows on Fieldbook maps by 50% while preserving map and icon scaling.
- Set Annals Journey icons to 60% opacity, retaining the additional fade for older events; scale dungeon entry/exit badges with icon size.
- Place Atlas Map Layers in a square funnel button at the map top-left, and move the Annals map filter to the same corner.

## v0.24.1 - 2026-10-04

- Annals: add Rare-blue 60% and Epic-purple 100% mounted trails, 256x and custom numeric playback speeds, and a mirrored filter button at the map top right.
- Limit Journey trails to the selected duration behind playback; show the latest 15 located event icons, fading the oldest five.
- Show a scrollbar for the Annals timeline when more than seven entries are available; retain the detail pane overflow scrollbar.
- Add regression coverage for mount capture and transitions, time-window clipping, icon fading, custom playback speeds, and timeline/detail scrollbar visibility; document the controls and live mount-speed validation.

## v0.24.0 - 2026-10-04

Release-channel update covering all changes since v0.23.0-beta and previous-push
baseline 2e13fb6ffe89a764a330b059fd5271bdf51e9ca9.

- Remove the Discovery index label from Traveller’s Atlas.

- Standardize Annals, Treasure and Almanac zone selectors and Ledger’s
  NPC Locations button at 256 × 24. Fit Treasure’s adjacent controls with six-pixel
  gaps while preserving the shared row edges and map dimensions. Keep Atlas’s
  zone selector expanded to 306 pixels to fill its control area.

- Align Annals Journey controls with the other map pages: place the zone and
  navigation row seven pixels above the map with matching left/right overhang,
  and align the date-filter and Around selected event rows. Preserve map and control sizes.

- Add inner padding to Chronicle and Treasure entry rows; show eight Chronicle
  entries per page to keep the padded rows clear of navigation. Ledger training
  icons and titles now show cached ability tooltips, with a fallback for unavailable details.

- Increase Ledger contact-list names by two font points and tags by one, adjusting
  row spacing and scroll heights to fit the larger text.

- Match Gatherer’s Location window to Bestiary’s 603 × 627 panel at the same
  position, preserving their shared bottom edge.

- Add four pixels of inner padding to Almanac list rows and match Atlas entrance
  discovery checkboxes to the automatic-mapping checkbox.

- Remove Atlas discovery pins’ outer borders while keeping their icon bevels.
  Close Map Layers on outside clicks, place the zone selector on the bottom
  control row, and move entrance, mapping and layer controls up one row.
- Remove Bestiary and Gatherer Previous/Next buttons and expand both scrolling
  lists to 18 rows. Retain Bestiary entry-navigation keybindings.

- Replace Almanac main-list pagination with scrolling. Show Merge spot only on
  Waters in the former Previous slot; reserve the former Next slot for Restore
  when a removed record is selected on any Almanac tab.

- Remove the darkened background behind Ledger's contact list, retaining row
  selection highlights.
- Swap the Almanac's session-source buttons and zone selector rows, placing
  the zone selector directly above the map with Record catch right-aligned on
  that row, clear of the session-source buttons. Preserve the remaining layout.
- Add four pixels of padding on each side inside Ledger contact selection rows,
  increasing row heights and scroll spacing to preserve readable contact details.
- Keep Lorekeeper's Chronicle on Entry by default, remove the Entry button,
  and make Location a standard highlighted toggle that returns to Entry when off.
- Centre the Annals legend horizontally over the Journey map. Adjust Bestiary's
  Locations panel to 603 × 627 while preserving its bottom edge after the main
  window height adjustment.
- Reorder the page tabs: Bestiary, Gatherer's Compendium, Traveller's Atlas,
  Adventurer's Annals, Merchant's Ledger, Treasure Journal, Angler's Almanac,
  then Lorekeeper's Chronicle. Use the pocket-watch icon for Annals.
- Left-align Annals' Around selected event button in the right pane, retaining
  the compact settings row beneath the map. Match Bestiary's base height to the
  other sections by tightening its ability form and footer spacing; long
  summaries retain their required expansion without clipping lower controls.
- Restore the Annals Journey map to the shared map position. Put the contrast
  and icon-size labels, sliders and values on one row beneath it. Explain the
  one-hour window (30 minutes each side) in Around selected event's tooltip,
  including the exact dates/times when an event is selected.
- Add Ledger's Current Zone filter beside its other filter options. Combine it
  with searches such as "repair" and refresh matches when the player changes
  zones; selecting a fixed zone or clearing filters disables it.
- Move Ledger's Link identity button below Search and above the contact list
  in the left pane.
- Replace Annals' Event filter text button with the standard funnel beside
  Search, highlighted when event types are filtered out.
- Open Annals with Journey on the right and its timeline on the left. Put the
  highlighted Show detail toggle in the left pane, where it overlays scrollable
  event details while the map and playback remain available. Restore the same
  timeline page and selection when closing details. Selecting a timeline event
  seeks its Journey time and map. Move Around selected event, recorded level,
  trail age contrast and map icon size into the right pane; explain contrast
  in a hover tooltip.
- Use the minimap's book icon for Azeroth Fieldbook in the addon selection list.
- Soften Annals timeline icon
  shadows and match both Timeline and Journey to the standard pane divider.
  Place Find player and Follow player together immediately left of Legend.
  Show only the newest three events in grouped map tooltips, indicate older
  events, and remove the redundant discovery/quest-causation disclaimer.
- Add player-supplied Lore translations through copy/paste report sharing.
  Translate a selected source page, type a transcription or explicitly choose
  your own readable capture, then share it back with language labels, translator
  credit and an exact copy of the original. Keep both versions in the reader,
  preserve attribution on forwarding, and include translations in search.
  Report schema 2 retains schema 1 compatibility and installed-version checks;
  translations never replace captured text or grant encounter credit.
- Recover incomplete new Annals acceptance rewards from the matching quest log
  for up to ten seconds after fast acceptance. Preserve the observed time,
  location and known offers; restore the selected quest after guarded reads,
  retain pending capture across reloads, and freeze incomplete data when the
  retry window ends or the quest leaves the log. Never backfill older events.
- Omit ×1 from single rewards, enlarge reward names by two points and add
  shadows to timeline icons, including quest ! / ? markers. Give instance
  entries/exits green inward and orange outward arrow badges in the timeline,
  map and legend. Use the shared toggle glow for Legend and Follow player,
  remove the legend close button and keep the Follow player label unchanged.
- Record dungeon, raid and scenario entry/exit in Annals. Hold the Journey arrow
  at the observed outdoor entrance during a visit, including after reloads and
  when entry precedes the selected range. Keep interior events in the timeline,
  suppress interior trails, and jump to observed exits or hearth destinations.
  Leave unobserved entrances unknown instead of guessing their coordinates.
- Confirm disabling Record Journey with Yes / No; keep recording until Yes.
  Align Choose zone above the map's top left without moving the map. Replace
  the text legend with a compact button opening an overlay of actual marker
  icons, player arrows and trail colours. Offer Full / 3 hours / 1 hour /
  15 minutes as Journey time ranges.
- Recover Bestiary entries from readable post-combat enemy rosters even when
  no creature ability can be imported, fixing missing entries when the client
  restricts live unit identity. Retry when addon restrictions change and report
  hidden roster fields. Keep dungeon and raid observations under their instance
  name when maps are missing or lead to an outdoor parent. Add regressions for
  restricted identities, roster-only recovery and unmapped instance discovery/kill
  recording. Operator confirmed Hall of Thanes creatures appeared after reload.
  Explain post-combat dungeon/raid discovery, party encounters and the scan retry
  command in Bestiary Help.
- Add the shared styled search bar to Annals. Match partial, case-insensitive
  text across quests, event details, places and offered/received rewards, with
  multi-word searches across fields. Include client item names, weapon/armour
  types, equipment slots, quality, descriptions and readable tooltip text, so
  sword rewards match even when their names do not contain "sword". Refresh
  results as missing item data loads, combine with date/type/level filters, and
  filter Journey markers without hiding the historical arrow or route.
- Add Annals Follow player mode: keep the historical arrow in view during
  playback, switch recorded zones/continents automatically and jump at observed
  hearth/teleport arrivals without connecting the gap. Keep panning smooth between
  route redraws and retain zoom when changing maps.
- Add Annals Now / reset to return to the current time, clear search/date/level/event
  filters and restore full-range timing, 1x speed and an unfollowed current-map view.
- Style Annals timeline entries and details with clear headings, event colours,
  quieter location/time metadata and coloured gold/silver/copper units. Show
  quality-coloured reward names, item icons and hover tooltips in scrollable rows;
  resolve missing cached artwork/quality without rewriting historical records.
- Capture potential choices and guaranteed rewards when a quest is accepted,
  including readable XP/money and currency/spell offers. Completed entries show
  the observed chosen reward separately from guaranteed rewards and actual
  XP/money. Preserve unknown older or incomplete offers and exact item links.
- Add a remembered Level / Name sort-arrow menu to Ledger's Observed Training.
  Match Known Goods with large ability headings and icons, coloured availability,
  highlighted requirements and compact coin prices. Retain native trainer icons
  and use cached artwork for older lessons when available. Enable scrolling over
  the text, headings and icons when the list overflows, and omit the cost-line date.
- Smooth Annals playback between connected samples using recorded timestamps,
  with per-frame arrow movement and a progressively revealed route. Preserve
  real gaps and label estimated positions; retain stop/resume timing and speed
  changes in future recordings without adding periodic stationary samples.
- Replace the Annals -1 sec / +1 sec buttons with Find player, which pauses and
  centers the historical position at the selected time, changing maps when needed.
  Keep mouse-wheel adjustments for second-by-second scrubbing.
- Fix blank gathering previews with a broad camera clipping range and a shared
  bounds-based scene viewer for herbs and minerals, verified in-client with Copper
  Vein and Bruiseweed. Load visible actors, clear failed loads, and retain rotation
  and automatic framing when switching entries or reopening the book.
- Add `/fieldbook debug model` to inspect the selected gathering preview's loaded
  asset, visibility and camera state in a copyable report.
- Add Annals Hearthstone/recall and Classic teleport cast markers, battleground
  entry/exit markers, and ship markers for observed cross-continent transfers.
  Record departures and loading-transition arrivals without drawing connecting
  trails across the transfer; include independent event filters and tooltip colours.
- Colour-code Annals map tooltips: yellow names, cyan discoveries, grey timestamps
  and supporting details, with distinct event colours and spacing between entries.
- Keep map icon counts small, proportional and anchored to the artwork's bottom
  corner. Borderless icons fill their selected base size, and icons and counts
  scale together with map zoom.
- Join Annals journey trails into continuous ribbons with shallow elbows, removing
  overlapping square segment ends. Keep the visible stroke at two UI pixels
  throughout map zoom and rebuild elbow detail for the current zoom level.
- Fix Chronicle capture gaps for standard world-book readers: recover ready text
  after a missed opening event, bind book identity when text is ready instead of
  retaining stale opening metadata, and accept a false no-creator result.
- Give the Annals Map icon size slider an opaque black track.
- Add Annals journey playback with play/pause symbols and 1x/8x/32x/64x/128x speeds, stopping at
  the selected range's end. Improve timeline precision with relative slider
  values, time zoom and second-by-second mouse-wheel scrubbing.
- Remove added map-pin frames in Annals, Lore, Ledger and Angling, preserving
  the full original icon artwork and its built-in bevels.
- Add persistent multi-select Annals event filters, a map icon-size slider and a
  historical player arrow showing the latest recorded position and state at the
  selected time; heading follows recorded movement where available.
- Keep rounded journey elbows visible at low zoom by avoiding tiny line pieces.
- Colour newly recorded flight travel green and record deaths in the Annals
  timeline and map, including when journey recording is disabled.
- Round connected Annals journey corners into shallow curves while preserving
  recorded gaps, original samples and the map's drawing budget.
- Show Annals archive usage at the bottom left in both views, with a tooltip
  estimating the full character store and detailing events and journey data.
- Fix the Search placeholder overlapping entered text in all journal and picker
  search bars; restore it when the query is cleared.
- Expand regression coverage for Annals playback, tracking, rewards, storage and
  layout; Lore translations and capture; Bestiary identity and instance recovery;
  gathering previews, Ledger filters/training, and journal navigation. Update
  section, architecture, storage and verification documentation.

## v0.23.0-beta - 2026-10-03

Beta-channel update covering all changes since v0.22.0 and previous-push
baseline b3c760af71a2114a65407fe3990b74786a35295a.

- Shade journey lines from warm gold to faint cool blue as they age relative to
  the scrubber, with a saved 0–100% Trail age contrast slider (75% default).
- Give the Annals tab a combined gold ?! icon using the native quest markers.
- Add an eighth character-specific journal with append-only quest history, observed
  reward choices, automatic rewards, currency offer snapshots and linked discoveries
  from all seven existing journals. Keep repeat quest cycles and missing references.
- Add date/type/level browsing, surrounding-quest journey selection, independent
  Atlas maps, bounded historical geometry and a timestamp scrubber.
- Record adaptive compact trail segments with preserved event anchors, explicit
  breaks, geometric simplification and an independent recording control.
- Use balanced journey retention with a 15-second minimum ordinary-point interval,
  larger movement/bend thresholds and less storage for long play histories.
- Keep flights continuous across subzone names, record confirmed departures with
  flight-master icons, and project trails/events onto continent and world maps.
  Preserve genuine loading gaps and original coordinates; add a black scrubber track.
- Include Annals in whole-Fieldbook backups; older backups preserve existing Annals.
- Add deterministic capture, codec, lifecycle, UI and storage tests, a reproducible
  300-day storage report, API evidence and an in-game acceptance checklist.
- Refresh storage measurements for current segment context and document balanced
  retention, flight events, map projection, bounded drawing and the age gradient.
- Annals remains subject to native API and visual acceptance in this Beta build.

## v0.22.0 - 2026-10-03

Release-channel update covering all changes since v0.21.0 and previous-push
baseline 3f1f0ff1b47c06872793b7fa90492b71c1bcf7e8.

- Consolidate Treasure Journal filters and Clear into a highlighted funnel beside
  search, with a matching Sort menu. Filter groups stay independent and checkbox
  menus remain open; Kind notes remains a separate action.

- Place Ledger’s Known Goods and Observed Training buttons side by side beneath
  Favourite, keep Favourite’s label fixed when toggled, and move
  notes up into the vacated row with a taller reading area.

- Consolidate Angler’s Almanac zone, knowledge, source and show filters into a
  funnel beside search, with independent checked selections, persistent menus,
  an active-filter highlight and Clear for the current tab.

- Align Chronicle’s search, filter and sort controls with Merchant’s Ledger and
  increase its main lore source text by two points.

- Consolidate Merchant’s Ledger filters and Clear into a highlighted funnel menu
  beside search, with a matching Sort button and a taller contact list. Filter
  selections stay independent and checkbox menus remain open.

- Move the Bestiary’s summary and behaviour rows down eight pixels for more
  space below the heading, keeping the portrait and other panels in place.

- Match the main horizontal dividers to the vertical pane dividers’ brown colour
  and 35% opacity.

- Align the top row of each journal’s right pane with its left-pane heading.

- Keep Chronicle filter menus open while choosing checkboxes, with independent,
  exclusive selections in each submenu. Center all journal pane titles and enlarge
  them by four points, with yellow text and black drop shadows.

- Consolidate Chronicle entry kinds, filters and Clear under a square funnel button
  beside search, with a matching arrow menu for sorting and nine entries per page.

- Ctrl+Click any spell-ID portrait to open its captured creature in the Bestiary,
  including saved observations and restricted spell IDs, without assigning an ability.

- Extend clickable creature portraits to Enemy cast (including channels), Enemy
  instant cast, Buff on target and Debuff on you in the spell-ID window. Each
  portrait keeps its captured creature when targets change and manually assigns
  readable spell IDs to the Bestiary. Buff portraits identify the recipient;
  debuffs use their eligible source or an explicitly unverified target. Restricted
  IDs remain display-only, with an explanation in the portrait tooltip. Preserve
  existing notes, entry locks, reset guards and the Loss of Control workflow.

- Update help and verification documentation for spell portraits, and regression
  coverage for portrait attribution, navigation, toggles and journal menus.

## v0.21.0 - 2026-10-03

Release-channel update covering all changes since v0.20.0 and previous-push
baseline 2cf30da564cff1d03d94dc9a089291bb6cfdcd7d.

- Hide the Compendium Locations list scrollbar when its rows fit, including
  after template updates, and reset its scroll offset when the list shrinks.

- Match embedded Rumours to Loot and Damage with the same panel backdrop,
  gold heading, content margins and muted empty-state text.

- Add Known Goods icon tooltips and show per-item stack prices in parentheses,
  including fractional copper (for example, 3s / 200 (1.5c ea)).

- Show Bestiary Rumours inside the loot/damage panel, with scrolling and existing
  verification controls. Toggle Rumours to return or use Show Damage to switch.

- Enable native hover region highlights and one-level left/right-click map
  navigation in Bestiary and Compendium Locations without recording discoveries.

- Add Current Zone beside the Bestiary and Compendium Locations zone selectors.
  Show the current map even without recorded positions, without saving discoveries.

- Place Ledger Known Goods names across the full row above their icons. Move
  Record contact above Delete and put Edit in its former slot. Support multiple
  manual service selections with checkboxes, preserving observed service evidence.

- Preserve space below the lowered Bestiary entry fields for the detected-ability
  hint and feedback, extending the book by 16px. Refresh regression expectations
  for the current list widths, nested filter menus and default map layer.

- Enlarge Ledger Known Goods icons to two rows high below the item name, with
  price and details beside them; lower item names by 1 point.

- Remove redundant checkboxes from the Atlas editor’s Location type dropdown
  button and choices.

- Default Lorekeeper’s Chronicle to Entry on startup instead of restoring a
  previously saved Location view.

- Anchor the Bestiary Sort menu’s top-left to the button’s bottom-left, matching
  the filter menu.

- Remove the redundant Tracking: Interactions label from Compendium Locations,
  which has only one tracking mode.

- Move the Bestiary loot filter left when the scrollbar appears, reserving
  matching heading space and restoring its position when the content fits.

- Hide the Compendium Observed Loot scrollbar whenever its content fits, including
  after template updates, and reset scrolling when the content shrinks.

- Standardize all journal and picker search boxes with a grey Search placeholder,
  red clear cross, and native text scrolling that stays clear of the cross.

- Remove Bestiary lock/unlock status messages, lower the right-pane entry fields
  to align the bottom controls with the left pane, and align list names and the
  entry count with the search text, keeping review stars outside that margin.
- Match Gatherer’s Compendium list names, including hover-scrolling text, and
  its entry count to the search text’s left margin.

- Add a small clickable target portrait beside unattributed Loss of Control
  observations in the spell-ID window. Capture the target at detection so later
  target changes cannot redirect the click. Clicking manually confirms the spell
  for that creature in the Bestiary, preserving notes and respecting entry locks;
  a tooltip explains the unverified target and a green rim confirms saving.

- Restore Bestiary content and clear overlay button selections when reopening
  the Fieldbook after closing it with Locations or an observation panel open.

- Vertically centre the Bestiary unlocked/rumours legend between navigation
  and the bottom action buttons.

- Default Bestiary Locations to observation positions when no kill positions
  are recorded, preferring kill positions when available. Manual layer switching
  remains available.

- Lower Bestiary and Compendium Previous/Next buttons by 8px to match Treasure
  Journal and Lorekeeper’s Chronicle navigation rows.

- Widen the Bestiary and Compendium Locations panels 9px to the left, giving
  both panels equal 24px margins from the divider edge and the right book edge.

- Raise Bestiary and Compendium list names by 2px, including hover-scrolling
  text and the Bestiary review marker, to align within the compact rows.

- Align all seven journal titles at the same left-pane coordinates, adding
  titles to Bestiary and Gatherer's Compendium without losing list rows.
- Anchor the Bestiary lock beside the creature name. Align the Compendium model
  with the Bestiary's standard model position, put Basic info and Locations
  headers on one row, and move the lower details down to preserve spacing. Keep
  the Compendium node title vertically aligned with the top-row Locations button.

- Consolidate Bestiary and Gatherer's Compendium filters into matching funnel
  dropdowns, with nested Locations (and Bestiary Ranks) menus. Remove the sidebar
  filter columns, widen both lists and retain the Bestiary's expandable index.
- Align both pane dividers with the other journals. Expand left-side detail
  content inward while retaining right-column positions and overlay boundaries;
  preserve models, notes, loot, ability controls and filter selections.

- Hide the loot filter when no item drops are recorded, including empty observed
  corpses. Keep it available when quality filtering hides existing drops.
- Fix shared map rendering for Angling and other journal adapters without Atlas
  settings; their markers retain the default size instead of raising a Lua error.

- Open Locations and Ranks as nested slide-out menus within the Bestiary filter
  menu, with shared selections, Clear all and scrolling for long location lists.
  Anchor the menu’s top-left to the filter button’s bottom-left. Close creature
  and loot filter menus on outside clicks while preserving interaction within
  their menus, buttons and slide-out submenus.

- Refine Atlas map controls: allow 6px icons, inset Map Layers backgrounds by
  2px, and select discovery types in an anchored dropdown instead of a full page.
- Keep Bestiary ability confirm/reject controls beneath overlays. Compact the
  shared funnel icon and colour the seven loot-quality options. Add a
  shared creature filter menu beside Sort.

- Add a saved Atlas icon-size slider to Map Layers and toggle the menu closed on
  a second click. Move Edit above Share and use the shared shadowed list arrow
  for discovery types. Match map brightness labels to coordinate outlines.
- Match Bestiary Locations to the Compendium's embedded panel, map dimensions,
  wrapped footer and zone-list styling, retaining kill/observation tracking.
- Add a square funnel button to Bestiary Loot with quality toggles, an Unknown
  category for uncached items, and Show all. Filtering preserves recorded drops.

- Observe every player Loss of Control type through Forever's LOC events. Add a
  dedicated row to the spell-ID window and a deduplicated manual-entry chat
  notice when attribution is unavailable. Only the matching player's aura and a
  readable, eligible NPC source can automatically record a Bestiary ability.
  Retain existing provenance and attach cyan [A] player-effect help to saved
  abilities; no [A] is added to the transient spell-ID window. Preserve account
  imports and backups with additive provenance, and add safe debug diagnostics,
  attribution/security/UI regressions and a Forever 70170 live checklist.
- Match discovery chat messages, Event log labels and account-tracking notices
  to their section page titles, including Gatherer's Compendium. Display older
  Atlas and Chronicle events with their full titles without rewriting saved history.
- Add opt-in Atlas entrance discovery with independent evidence, explicit zone
  coordinates, repeated-traversal corroboration and distance-based clustering.
  Preserve the existing sub-zone mapper and deliberate discovery/report data.
  Guard loading, teleports, summons, death, spirit release and resurrection.
- Add Generic Entrances as an independently hidden-by-default map layer. Reuse
  the category editor for explicit player confirmation of inferred choices.
- Announce newly discovered Atlas entrances in chat and the shared Event log.
  Mark automatic Atlas entries and locally captured Lore entries with the
  Bestiary's cyan [A] tag in chat and journal displays. Repeat observations,
  rereads and reloads do not repeat new-entry notices; manual and reported
  entries keep their existing presentation.
- Remove the unsupported Display Micro Map button and temporary map renderer.
- Mirror a matching live target/mouseover in the Bestiary model viewer, with
  the creature-ID model as a fallback when no matching unit is available.
- Read accessible UNIT_AURA additions directly in the Spell ID tracker, including
  short-lived player debuffs when a fresh aura scan cannot return them. Accept
  accessible event containers with restricted contents and fall back to indexed
  queries when enumerated slots supply no usable aura data. Preserve the last
  player aura-event diagnostic and report whether Disarm 6713 is blacklisted.
- Add regression coverage for transitions, coordinate provenance, clustering,
  classification, storage scopes and sub-zone preservation.
  Forever API behaviour and native visuals still require the live checklist in
  `tests/ATLAS_ENTRANCES.md`.

## v0.20.0 - 2026-10-02

Release-channel update covering the complete batch since published v0.19.2-beta
and previous-push baseline `5908c66705f56b13fd00f1c619626479961e14e5`.
Native acceptance remains pending for the full mineral catalog, map-filter
callout placement and traced sub-zone outlines. The level-cap-gated Beast Lore
milestone remains a requirement for 1.0.

- Default behaviour traits in creature tooltips to on, preserving saved opt-outs.

- Give Bestiary Offenses, Defenses and Behaviour overlays dark parchment
  backgrounds and dialog borders matching the other in-window overlays.

- Replace the Compendium location dropdown's text arrow with the shared dropdown
  artwork and its drop shadow.

- Add consistent subtle drop shadows to right-pane entry headers, including
  the Bestiary's scrolling title, without changing their placement or type size.

- Embed gathering Locations in a dark right-pane overlay beneath the node title
  and Locations button. Keep the resource list accessible and preserve zone
  selection, interaction markers, coordinates, brightness and map explanations.
  Cover the Basic info heading fully and use the Locations toggle without a
  separate close button.

- Remove the repeated timestamp from Known Goods price lines, retaining First
  and Last seen dates below each offering. Show single-item prices as "X each"
  instead of "X / 1".

- Add a gentle drop shadow behind the Merchant's Ledger NPC portrait.

- Inset the Compendium's Field notes and Observed loot backgrounds by two pixels
  on each side so they no longer protrude at the border corners.

- Remove the redundant Ledger source label beneath Favourite and the Chronicle
  Capture status header/tooltip. Keep contact-list provenance, entry capture
  details and active capture progress feedback.

- Match Chronicle titles and Ledger NPC names to the Bestiary/Compendium's
  larger gold type and header height. Align the Chronicle title and Ledger
  portrait with the left edge of their location controls, keeping NPC text
  beside its portrait and header buttons clear.

- Move Chronicle's Entry and Location view buttons into the top-right header,
  matching the other journals and reserving title space beside them.

- Use the Flight Master tracking icon for Ledger flight-master map pins,
  recognizing recorded taxi service and flight-master titles.

- Exclude coordinate-free Ledger sightings from the NPC Locations dropdown and
  its count, retaining their zone observations in the journal.

- Remove the gathering-window recording hint, retaining its Help guidance.
  Label Ledger locations as NPC Location or NPC Locations, explain Link identity
  on hover, and use the shared dark delete dialog for Ledger contacts.

- Center Compendium mineral previews on their model bounds and fit the camera
  from geometry, keeping rotation within the viewer without per-node offsets.
  Preserve the existing herb presentation.
- Remove the redundant Atlas main-map sub-zone checkbox; use the world map's
  Points, Labels and Zones filters, preserving saved choices.
- Show a gold tutorial callout at the world map filter dropdown on its first
  opening, once per account after the callout is introduced.

- Keep the Compendium's map checkboxes synchronized when the world map's Nodes
  filter changes, including changes made while the Compendium is closed.

- Give Almanac, Lore and Atlas entry deletion a Ledger-style warning panel with
  explicit Delete and Cancel buttons. Use the same layout for Bestiary and
  Gatherer’s Compendium, preserving permanent-loss warnings and requiring the
  exact word **delete** before confirmation is enabled.

- Standardize entry deletion as **Delete** at the same footer position beside
  **Share**: move Atlas deletion out of its discovery editor, Ledger contact
  removal out of its record row, Lore deletion out of Sources / manage, and
  Treasure encounter removal out of its map toolbar. Add confirmed deletion
  to the Gatherer's Compendium. Keep journal scope and require confirmation before deletion.
- Add the same **Delete** button to Almanac Waters, Pool Types and Catches.
  Disable it without a displayed selection and reject selections from another
  view. Retain catch history and offer restoration through **Show: removed**.
- Deletion never prevents rediscovery: re-hovering Almanac pools/sightings and
  observing waters or catch types makes them visible again. Reopening a Treasure
  container can immediately record a new encounter after deletion; duplicate
  events from the old open window stay ignored. Ledger contacts reappear on the next interaction.

- Expand regression coverage for deletion scope, confirmation and rediscovery,
  map-filter synchronization and the first-use tutorial, mineral geometry,
  embedded location maps, Ledger displays and the new tooltip default. Update
  UI mocks for embedded dialogs and document deletion and restoration behavior.

## v0.19.2-beta - 2026-10-01

This Beta covers the complete batch since the published v0.19.1-beta and
previous-push baseline `1556271fe30b68dafa3a9aae1eee174d95c0ab26`, verified before
fetching; origin/main remained there after fetch. Native acceptance of the new
map layout and the candidate native-filter correction remains pending.
Pre-release validation passed all 77 test files, all 82 Lua 5.1 files, manifest,
bindings, version consistency, publication-note extraction and whitespace checks.

- Remove the Gatherer's Compendium **Index** button, A–Z filter strip and its
  hint. Browse with type/location filters, search and sorting; keep scrolling
  and Previous/Next available for longer lists.

- Move Atlas **Legacy Fill** into the Sub-zones panel with a compact checkbox,
  clearing its overlap with **Map Layers**. Place a brightness slider on every
  Fieldbook map below the coordinate footer with no surrounding background.
  Align both rows to the same left edge and use grey text. Share one saved
  terrain brightness across all seven journals and their Locations windows.
  Preserve the current Atlas brightness on upgrade and keep overlays at full
  contrast. Save the shared preference per character, independent of journal
  storage scope.

- Standardize Bestiary, Atlas, Almanac, Ledger and Lore on a **Share** button
  with identical bottom-left position and size across page switches. Preserve
  window framing, pane proportions and map controls. Move nearby footer actions
  and shorten the Ledger contact viewport; group Lore export/import under Share
  and retain Capture / retry current text in its Record menu. Existing report
  capabilities, privacy defaults and delivery rules stay unchanged.

- Announce newly discovered herb/mineral types, observed zones and new
  interaction locations when discovery chat messages are enabled. Repeated
  sightings and nearby recorded points stay quiet. Match existing gold discovery
  titles and grey details, and shorten chat prefixes to AFB while preserving
  their colours.

- Add **Show behaviour traits in creature tooltips** under Options → Tooltips
  and cast IDs, off by default. When enabled, show checked recognised Behaviour
  traits even without displayed abilities or kill counts. Exclude Disposition,
  tameability, unchecked marks and unverified Rumours; preserve saved knowledge
  when toggled. Cover tooltip output, option wiring and preference persistence.

- Harden the native map filter callbacks following an out-of-combat addon-block
  report. Use the native checkbox's default response, exclude addon choices from
  Blizzard's filter-button selection summary, and defer map redraws to an addon
  worker on the next frame. Coalesce rapid clicks and discard queued redraws for
  replaced journals. Add callback-boundary regressions. This is a candidate
  correction: the reported block has no captured action stack and still needs
  native confirmation after reloading the updated addon.

- Extend regressions for shared map brightness, upgrade/reload persistence,
  compact Atlas controls, gathering filters and discovery announcements,
  behaviour tooltip options, Share layouts and deferred map-filter callbacks.
  Update older coordinate-placement and gathering-initialization fixtures;
  update Help, README and native acceptance checklists for the final controls.

## v0.19.1-beta - 2026-10-01

This Beta includes the complete unpublished batch since v0.19.0-beta
(`238f5259fbcd5ce58acea146a3cca4c8c9ffad2d`), including the push-only stability
checkpoint. The previous-push baseline was verified before fetching as
`d24677e3fc027ddd73b31e50697873fcc178472d`; origin/main remained there after fetch.
Full pre-release validation passed all 75 test files and all 81 Lua 5.1 files,
manifest, bindings, version consistency and whitespace checks.
Native acceptance of the new map changes is pending. Earlier stability
acceptance recorded 144 passes and no failures, but remains incomplete; see
`tests/NATIVE_ACCEPTANCE_2026-09-30.txt` for its scope and deferred checks.

- Trial traced sub-zone fill that bends inward through supporting samples,
  preserving observed locations instead of directly joining every outer border
  sample. Keep the original convex method under Atlas **Legacy fill** for
  immediate rollback on both maps without converting saved observations.
  Pause cleanup in traced mode to preserve supporting points. Sparse evidence
  can still bridge unknown space; this remains an estimated outline.
- Add **Points**, **Labels**, **Zones**, **Merchants** and **Nodes** to the native
  main map's Filters dropdown under **Azeroth Fieldbook**. Main-map sub-zone
  choices become independent of Atlas selections when edited. Nodes uses the
  existing world-map gathering preference without changing the minimap.
  Add bounded, zoom-scaled merchant pins for recorded locations, preferring
  personal sightings and identifying reported evidence. Recording is unchanged.
- Fix large-paste stalls in whole-Fieldbook and legacy Bestiary backup imports
  using bounded clipboard capture, received-byte counts and short previews.
  Validate the complete captured data, reject overflow/incomplete parts and
  invalidate stale restore confirmations on edits. Preserve selected backups,
  part navigation and approved reviews across unchanged delayed text events;
  batch paste work and cancel pending work on replacement or close.
  Native backup capture, replacement restore and automatic recovery retests
  passed within the recorded acceptance scope; broader acceptance is pending.
- Split large Merchant's Ledger reports into numbered parts of at most 80 goods
  and 80 lessons. Advance with Next, import each part separately and merge facts
  under the original source. Keep repeat imports idempotent, limits atomic,
  forwarding and note opt-in intact; reset prepared parts when selections change.
- Preserve Lore report export/import previews across unchanged delayed text
  events. Actual report or courier edits still require a fresh preview.
- Keep shared Options open while switching journals and refresh the active
  storage scope there. Move the grey account/character scope label beside
  Account-wide tracking; grey Lore's archive usage text as well.
- Keep the Bestiary count on one line, retain creature-name shadows during
  marking and hover scrolling, and remove the ability-confirmation message
  and Index filter hint. Disable Ledger goods/training controls when the
  contact has no corresponding personal or reported offerings.
- Fix Bestiary model request timing and replacement: show the viewer before
  requesting, retry transient failures up to three times, conceal and unload
  the outgoing appearance before layout changes, and reveal only the loaded
  replacement. Preserve the personal-encounter requirement; native rendering
  acceptance remains pending.
- Extend regressions for outline concavity, rollback, cleanup preservation,
  independent native filters, merchant/node layers, backup paste and review
  lifecycle, multipart reports, model lifecycle and Options navigation. Update
  older backup/sharing tests for bounded input and document live map checks.

## Development checkpoint - 2026-09-30

Stability checkpoint against previous-push baseline
`238f5259fbcd5ce58acea146a3cca4c8c9ffad2d`. This batch covers the fixes,
UI adjustments and regression tests below. Native acceptance has 144 recorded
passes and no current failures; it remains incomplete. Favourite filtering is
the next unperformed check. This checkpoint is for repository access, not a
new published release. See `tests/NATIVE_ACCEPTANCE_2026-09-30.txt` for evidence
and deferred observations, including fishing-detail readability and uncollected
loot semantics.

Pre-commit validation passed all 74 test files, all 80 Lua 5.1 files, manifest,
bindings and version consistency; diff whitespace checks passed.

- Update older backup lifecycle and sharing UI tests to exercise the bounded
  clipboard input rather than writing into the export-only text box.

- Remove the Bestiary ability-confirmation message and Index filter hint.

- Split oversized Merchant's Ledger contact exports into numbered parts of at
  most 80 goods and 80 lessons each. Preparing again advances to the next part;
  importing them separately merges all facts under the same original source up
  to the journal's 500-per-kind limit. Repeat imports stay idempotent and
  capacity failures leave the recipient unchanged. Native multipart preparation,
  acceptance, forwarding and note opt-in/persistence retests passed.

- Keep prepared Lore report export and import previews when delayed text-change
  notifications report unchanged programmatic content. Genuine edits to report
  text or recorded courier still require a fresh preview. Native revision,
  note opt-in, forwarding, receipt and persistence retests passed.

- Keep the shared Options window open when switching between journals, including
  when leaving Bestiary, and refresh its active storage-scope label for the new
  journal. Add a navigation regression; native retest passed.

- Keep the Bestiary entry count above its search bar on one line with room for at least four digits,
  and retain name drop shadows while long names scroll on hover.
- Disable Known Goods and Observed Training for contacts without the corresponding
  personally recorded or reported offerings.
- Move the grey active Account-wide / Character-specific label beside Account-wide
  tracking in Options. Also grey the Lore archive usage text.

- Apply bounded clipboard capture to legacy Bestiary backup imports after native
  testing reproduced the large-paste stall there. Show received bytes and a short
  preview while validating the complete AFB1 text within its existing 4 MiB limit.
  Clear captured input on mode changes/close and reject stale restore confirmations
  after edits. Add large-paste, overflow, corruption, cleanup and restore regressions.
  Native retest captured and checked a 171,497-byte legacy backup with a reported
  split-second pause and the original backup summary intact.

- Fix whole-Fieldbook export losing its selected backup and part navigation
  after delayed native text notifications. Unchanged text keeps the current
  review; actual edits still invalidate restore approval. Add immediate and
  deferred notification regressions for multipart export and import review.
  Batch paste-time text reads, layout and cursor scrolling per frame while
  immediately invalidating restore approval. Cancel queued work on replacement
  or close, and test burst input, explicit checks and stale confirmations.
  Keep the native clipboard field at the 96-byte capacity verified by an in-game
  character-delivery probe, and collect the complete paste in bounded Lua chunks.
  Show received bytes and a short preview, validate the complete captured input,
  and reject overflow or incomplete parts. Existing
  exported parts remain compatible. Native retest captured a 262,173-byte part
  in a reported split second and validated all three parts back to the original
  backup summary. Native replacement restore and automatic recovery both returned
  the expected Lore and Gathering notes; broader acceptance remains in progress.

- Restore creature-name drop shadows on marked Bestiary rows by removing their
  static text fade; retain the narrower name width to leave room for icons.

- Fix Bestiary model loading to show the viewer before requesting a creature,
  retry transient failures up to three times, and stop retrying when the model
  loads or selection changes. Keep the viewer blank while a model is loading or
  unavailable, conceal the previous appearance immediately on selection, and
  reveal the replacement only after it loads. Hide and unload the outgoing
  model before resizing the viewer or changing the Beast Lore header, then
  request the replacement after layout is complete.
  Start replacements immediately without an artificial transition delay.
  Preserve the personal-encounter requirement.
  Add model request lifecycle regression coverage; native rendering needs an
  in-game check.

## v0.19.0-beta - 2026-09-30

This Beta includes the complete batch since v0.18.0 and previous-push baseline
`0698876c6ffd629103fe010d77e59c5ed9ed4d35`, verified before publication.
Automated validation passed all 72 test files, followed by nine affected suites
after final recovery refinements. Native WoW acceptance remains pending for the
combined in-game verification batch.

- Add whole-Fieldbook backup and recovery for all seven journals, including
  account and retained character knowledge, private text, provenance, reader
  state and cross-journal identities. Keep two saved copies and one automatic
  recovery copy in a separate archive; export/import checksummed text in parts.
  Preview scope and counts before replacing data on a fresh reload, retain
  Knowledge accounting and identity allocation counters, and roll back if startup
  fails. Recovery remains available when normal startup is blocked. Preserve
  legacy Bestiary backups and independent reports/resets. Add full preservation,
  failure, lifecycle and large-archive tests, plus offline SavedVariables recovery
  instructions and a deferred native acceptance checklist.

- Show Lore archive byte usage below the catalogue, with exact bytes, entry
  slots, near-capacity and preservation/read-only explanations on hover.
- Show the actual active account or character scope in the shared shell across
  all seven journals, including pending reloads and deferred section migrations.
- Add local preflight summaries to Angling, Ledger and Lore import reviews.
  Reuse acceptance validation without writes, retain provenance/detail, explain
  repeated evidence and surface conflicts/capacity failures before acceptance.
  Add focused regressions and defer native layout checks to the combined batch.

- Keep automatic spell/aura tooltip IDs on by default using the saved Fieldbook
  choice, respect opt-out on reload, avoid redundant client preference writes,
  and explain the client-wide setting and settings-reset behaviour.
- Archive valid Lore pages when the 100-location list is full. Keep existing
  locations and show a capture-status note that the extra location was declined;
  page validation, byte limits and preservation rules remain in force.
- Summarize actual one-time account imports and applied scope changes in one
  chat message, naming imported/deferred sections without invented counts.
  Explain retained character journals and independent later changes; ordinary
  logins stay quiet. Add focused lifecycle and preservation regressions.

## v0.18.0 - 2026-09-30

This release includes the full batch since v0.17.0 and previous-push commit
`4a947ab966af9ca75404c312d4380999ef02caa2`.

- Rewrite journal help around current controls and player workflows, clarifying
  observation limits, report handling and account-wide tracking.

- Name the container journal Treasure Journal and the lore archive Lorekeeper's
  Chronicle throughout the interface, help, cross-references and documentation.

- Use `Trade_Herbalism` for the Gatherer’s Compendium section icon.

- Use `INV_Misc_Map03` for the Traveller’s Atlas section icon.

- Use the Classic `INV_Box_03` icon for Treasure Journal.

- Increase Merchant’s Ledger Known Goods item names and detail text, including
  prices and dates, by one point. Show an ellipsis on overflowing item names
  until mouseover reveals the full name with horizontal scrolling.
  Use a stationary hover area for scrolling and item tooltips, with full-width
  text measurement before applying the resting ellipsis. Keep item icons fixed
  while only the names scroll.

- Remove internal contact index numbers from the Merchant’s Ledger directory rows.

- Reserve the full automated suite and slow stress tests for batch pre-commit
  and pre-push/release validation; use proportionate focused checks during local iteration.

- Make Bestiary Offenses, Defenses and Behaviour native alternate views over the
  Recorded Abilities area. Keep them within the main book, switch between them
  one at a time, and restore abilities when toggled off. Remove their redundant
  close buttons now that the main-window buttons toggle these views. Remove the
  obsolete multiple-window option while preserving saved settings and positions.
- Rename the Bestiary awaiting-review status to Unlocked and shorten its green
  legend to rumours. Colour the Rumours button text green while the selected
  creature has unresolved rumours, returning to its normal colour once resolved.
  Shorten the knowledge counter to "# knowledge".

- Use the Lore reader's parchment hover across all seven journal menus, with
  Bestiary's gold border and dark fill for every selected entry.
- Remove repeated page labels from the Lore reader, separate source details in
  grey, and display preserved lore in white at two points above the normal text size.

- Keep the Atlas overlay on Blizzard's main map click-through after renderer
  initialization, preserving native map clicks, dragging and mouse-wheel zoom.
  Left-align both mapping checkboxes beneath the zone selector and let their
  labels use the full column width.

- Restore automatic Atlas mapping in capital cities, including their sub-maps.
  Keep flight-path and flying exclusions and update the help and regression tests.

- Add an opt-in Atlas checkbox above Automatic Mapping to display the selected
  sub-zone shading, labels and points on Blizzard's main map. Reuse cached,
  time-budgeted drawing, update on map/selection changes and cancel hidden work;
  no additional idle polling.

- Move Knowledge rewards from discovery to the first kill (+1), silver (+1),
  gold (+2), and crown (+3). Apply Elite 1.5x and Rare 2x multipliers to each
  reward and sharing totals, rounding down to integers; Rare Elites use 2x.
  Keep discovery chat and Event log celebrations, existing balances and spending,
  and free Beast Lore sharing. Update help and scoring/sharing regressions.

## v0.17.0 - 2026-09-29

This release includes all changes since v0.16.9-beta and the previous push at
`bf8baf3fdaa0b184e079d54485a3ac8c675c8624`, completing the eight-finding
stabilisation pass.

- Extend the existing Account-wide tracking option to Lore and Treasure. Import
  each character's earlier collections once, including accounts migrated before
  these sections were supported; keep local and shared journals independent on
  later toggles. Preserve Lore entries, pages, annotations, reader state, export
  identities and scoped Atlas references, plus Treasure kinds, encounter history,
  original provenance and receipts. Update help/storage documentation and add
  production-path migration, reload, identity and guard regressions.

- Deduplicate unchanged Lore re-exports by original identity and selected
  evidence, independently of sender and export time. Preserve the first and
  latest delivery receipts in the existing reader, keep meaningful revisions
  distinct, and count historical equivalent snapshots once toward the unchanged
  32-revision limit without deleting them. Cover account/local exports, selected
  pages, forwarding, historical capacity, reloads and guarded receipt updates.

- Persist fishing evidence identities and contributor partitions at capture.
  Preserve original attribution across character exports and account imports;
  reconcile grounded legacy aliases without replaying earlier cumulative totals.
  Keep historical totals with missing observers explicitly unknown, and keep
  reported evidence out of personal counts. Separate new account allocations
  from the retained opt-out stores.
- Preserve Lore-to-Atlas destinations with durable references and saved,
  character-scoped migration mappings. Repair already-migrated links from
  surviving identity evidence; retain ambiguous mappings as unavailable.
  Local scope can resolve the corresponding original discovery without borrowing
  another character's colliding ID. Lore's stored references are not rewritten.
- Reconcile account Ledger contacts sharing an exact original-report identity,
  including duplicates left by earlier migration. Preserve old contact aliases,
  both characters' annotations, full original evidence and delivery receipts;
  direct subsequent report updates to the canonical contact. Retain long notes
  in the existing details pane. Matching NPC templates alone do not merge contacts.
- Add production-path F1-F3 regressions for capture, export/import, both migration
  orders, already-migrated saves, reloads, scope changes, aliases, missing identity
  evidence, private annotations and the latched startup guard.
- Preserve unsupported or malformed main saves before normalization, account
  import-key allocation or journal/UI setup. Initialize defaults only for absent
  saves, show a concise diagnostic when blocked, and disable the session until a
  real reload. Stop main and section callbacks, queued captures, commands and
  bindings from using stale state or a pending reset. Force pinned Bestiary notes
  closed and block retained text and spell-edit callbacks after shutdown.
  Guard the shared player-name class store against blocked observers, retained
  helpers and formatting reads; defer initial observation until login so file
  loading cannot default an unsupported save before main-save validation.
- Preflight Lore duplicate consolidation on detached data. Keep accepted pages
  and both original records when limits or identity preservation prevent a merge;
  leave the destination, locations and read flags unchanged. Keep distinct saved
  IDs on reload as well, preserving annotations, references, reading positions and
  exported report identities until durable alias semantics are designed. Ordinary
  matching rereads still reuse records; the 101st-location capture policy is unchanged.
- Reject sparse Lore report lists before normalization can discard elements.
  Preserve valid older stored reports and retain malformed saved evidence through
  existing invalid-entry handling. Validate original nested stored lists before
  copying can discard invalid keys, including boolean-keyed evidence.
  Keep schema versions, exact installed-version
  compatibility and explicit acceptance unchanged.
- Add Lua 5.1 regressions for blocked initialization and later callbacks, supported
  reloads, real Lore location/work/archive limits, skipped-merge status, identity
  preservation and all five report-list types. Update duplicate-preservation
  coverage and documentation. The bounded stabilisation pass completed matching
  implementation validation, independent review and focused native acceptance
  in the isolated synthetic client environment.

## v0.16.9-beta - 2026-09-29

This release includes all changes since v0.16.6-beta and the previous push at
`142276e6cfea5c0478e156c4dfbef9649b5dde38` (local versions 0.16.7–0.16.9).

- Ctrl+Click Clean Redundant Points to clean all saved Atlas maps; ordinary clicks
  still clean the displayed map. Update the tooltip and help, reuse the budgeted
  cleanup and per-map safety checks, and report total removals and skipped maps.
- Pause automatic Atlas mapping in The Great Sea, including offshore areas that
  retain a coastal map ID. Preserve saved evidence and manual survey points, and
  break crossing continuity when automatic recording pauses.
- Capture object gossip readers such as Draconic for Dummies as writings, including
  manual retry when automatic capture is disabled. Preserve the displayed language,
  deduplicate repeated reads, and avoid claiming unverified page completeness.
- Mark Draconic for Dummies as a complete single-page writing; reopening it
  upgrades the earlier partial archive without creating a duplicate.

- Add regression coverage and usage documentation for all-map cleanup, Great Sea
  exclusions, object-reader capture, repeated reads and completeness upgrades.

## v0.16.6-beta - 2026-09-29

This release includes all changes since v0.15.39-beta and the previous push at
`ede3c2cf73cd65d2be3f13da75545da3442bb4a1` (local versions 0.15.40–0.16.6).

- Add Lorekeeper's Chronicle as the seventh functional journal: a separate character
  archive for writings, landmarks, people and mysteries, with searchable filters,
  private annotations, related-record links, revisit flags and investigation status.
  Keep source evidence, personal interpretation and received reports distinct.
- Automatically preserve displayed pages from supported readable sources. Both
  capture preferences default on; disabling Only archive pages I open enables
  bounded whole-book navigation where supported. Retain original text, page order,
  partial captures and source provenance; distinguish automatic retrieval from
  personally displayed pages. Preserve player control and stop interrupted work.
- Add manual transcription, deliberate NPC and displayed-passage recording, a
  stored-text reader with retained positions, and an independent Location view
  using the Atlas map layout. Preserve Lore settings through Bestiary resets.
- Fix the readable-source lifecycle, early READY events and Classic next-page
  flags. Reuse exact matching page evidence on rereads, preserve conflicting text
  separately, and repair exact saved duplicates while retaining annotations and
  related-entry links. Deleting an entry allows later recapture.
- Add bounded copy/paste Lore reports with exact previews and explicit, atomic
  acceptance. Private notes require opt-in; imported material remains reported
  and grants no personal credit or Knowledge.
- Announce every newly recorded Lore entry in chat and the persistent Event log,
  including captures, manual records and new imports. Make the shared Event log
  accessible from Lore; avoid duplicate announcements for rereads and extra pages.
- Show darkened current-map fallbacks in Merchant's Ledger and Lore when no
  recorded map is available, preserving empty-state explanations and selections.
- Pause automatic Atlas sub-zone mapping on flight paths, while flying and inside
  Classic capitals. Break crossing continuity across pauses while preserving
  existing evidence, ordinary inn sampling and deliberate survey points.
- Add an account-wide Text size slider with seven one-point steps from -3 to +3,
  centred on the unchanged default. Include Default and Apply / reload controls;
  preserve relative heading sizes and independent UI scaling. Fix the native
  edit-box font reassignment that caused a client stack overflow.
- Move the seven section tabs inward by two UI units to close the border seam,
  preserving native artwork, dimensions and vertical spacing.
- Expand Lua 5.1 regression coverage for Lore storage, capture, reports, UI and
  announcements; font-wrapper safety; Atlas exclusions; and tab geometry at
  1920x1200 and 7680x2160. Update architecture, storage and live-check documentation.
  Automated coverage does not substitute for native Forever client verification.

## v0.16.4 - v0.16.6 - Development notes (included in v0.16.6-beta)

- Add an account-wide Text size slider in Options with seven steps from -3 to
  +3 points, centred on the unchanged default. Include Default and Apply / reload
  buttons; preserve heading/body size differences and independent UI scaling.
- Fix a native client stack overflow when opening the book: leave template fonts
  untouched at Default and size edit boxes directly without assigning their own
  font wrappers back to them. Add regression coverage for this native API hazard.
- Move the seven section tabs inward by just two UI units to seal the border seam;
  preserve native art, dimensions and vertical spacing. Check screen-fit geometry
  at 1920x1200 and 7680x2160 as well as the existing resolutions.
- Announce each newly recorded Lore entry in chat and the persistent Event log,
  including captured writings, manual records and new imported entries. Expose
  the shared Event log from Lore; do not repeat messages for rereads or extra pages.

## v0.16.3 - Development notes (included in v0.16.6-beta)

- Keep readable page-load events in the active book session, preserve READY
  delivered before native navigation hooks, and accept Classic truthy/nil
  next-page flags. Capture opened pages into their ordered archive.
- Reuse exact overlapping source text on rereads without relying on a title
  alone. Preserve conflicting versions separately. Repair exact saved duplicates
  on load while retaining private annotations and related-entry references.
- Verify deletion through Sources / manage allows later recapture without
  blacklisting the book; add native lifecycle, reread and duplicate-repair tests.

## v0.16.1 - v0.16.2 - Development notes (included in v0.16.6-beta)

- Show a darkened copy of the player's current map when Lorekeeper's Chronicle has
  no recorded or selected map, using the shared Atlas size, position and border.
  Keep the fallback display-only and preserve deliberate map selection.
- Pause automatic Atlas sub-zone sampling on flight paths, while flying and
  inside Classic capitals. Break crossing continuity across pauses; preserve
  existing evidence, ordinary inn sampling and deliberate manual points.

## v0.16.0 - Development notes (included in v0.16.6-beta)

- Implement Lorekeeper's Chronicle as a separate character archive for writings,
  landmarks, people and mysteries in the existing seventh section tab.
- Preserve supported readable text through the item-text lifecycle. Default
  capture stores only displayed pages; disabling Only archive pages I open
  enables bounded asynchronous whole-book navigation where supported, including
  earlier pages, interruption handling and same-interaction restoration. Keep
  partial text, original formatting, capture methods and evidence-based gaps.
- Add the two default-on capture preferences to shared Options, manual
  transcription, deliberate NPC and passage recording, source-labelled notes,
  searchable filters, related-record references, revisit flags and investigation
  status. Keep source text separate from private interpretation and reports.
- Add a stored-text reader with retained positions and an independent Location
  view using the Atlas map factory and geometry. Location meanings distinguish
  reading, observations and deliberately placed landmarks.
- Add selected-source copy/paste reports, exact previews, bounded validation and
  atomic acceptance. Notes and interpretations require explicit inclusion;
  received material remains reported and grants no personal credit or Knowledge.
- Add Lua 5.1 model, capture, UI, report and integration regression coverage and
  document capability assumptions and outstanding Forever in-game checks.

## v0.15.40 - Development notes (included in v0.16.6-beta)

- Show a darkened current local map in Merchant’s Ledger when no contact map
  is recorded, keeping the empty-state message visible, matching Treasure Journal.

## v0.15.39-beta - 2026-09-28

This release includes all changes since v0.15.37-beta and the previous push at
`fdc108596ff7efae3f1029961389b9b7c39d008b` (local versions 0.15.38–0.15.39).

- Include class trainers in Merchant’s Ledger on target, mouseover and dialogue
  discovery using exact English class-trainer titles, even without opening training.
  Keep lesson and price capture tied to actual training inspections.
- Open the Bestiary on its title page initially, then retain the last selected
  creature and unfinished inputs when reopening or returning from another section.
  The mouseover binding still opens the explicitly chosen creature.
- Add regression coverage for class-trainer discovery and Bestiary reopening,
  and update the capture documentation and in-game verification checklist.

## v0.15.37-beta - 2026-09-28

This release includes all changes since v0.13.37-beta and the previous push at
`8bb3102199e710b52eebfc34165e54f961bf8fcb` (local versions 0.14.0–0.15.37).

- Add Merchant’s Ledger: remember encountered merchants, trainers and services;
  search contacts, items, recipes and lessons; combine role, location, source,
  favourite and recipe filters. Capture readable offerings without purchasing,
  preserving per-contact prices, stock, requirements, observation dates and
  provenance through incomplete inspections. Buyback is excluded. Stable local
  references, explicit identity linking and historical map sightings keep
  similarly named NPCs and moving contacts distinct.
- Refine the Ledger with a scrolling contact list, gentle background and hover
  fills, yellow names, bracketed NPC titles and collapsed missing-title space.
  Recover Innkeeper titles and roles alongside Merchant, retry NPC capture when
  the interaction opens before identity is readable, and announce new merchants
  once. Add circular 2D portraits with copper rings, aligned Favourite/Saved
  indicators, compact buttons and confirmed contact removal that allows later
  rediscovery. Prefer a positioned sighting in the same area over a newer
  coordinate-free observation while respecting explicit selections.
- Put Known Goods and Observed Training in tall, toggleable left-pane lists with
  yellow selection borders. Show available item icons, tooltips, quality colours
  and larger, fixed-size names that scroll on hover. Format prices as cost /
  quantity (individual cost each), omit zero denominations and colour currency
  suffixes. Hide unrestricted stock and redundant usability/per-item lines;
  retain historical and unknown-state distinctions. Keep notes below the map
  with an Edit Notes toggle and remove redundant Access Notes controls.
- Add bounded Ledger report preparation, copy/paste preview and acceptance with
  provenance-aware deduplication, preserved observation dates and opt-in private
  notes. Ledger addon-message transport, Knowledge prices and rewards remain
  deferred; imported facts are labelled Reported and grant no personal credit.
- Add Treasure Journal: a searchable journal of world finds, portable
  containers and salvage with separate historical encounters, contents, access
  details, notes, filters, bookmarks, corrections and confirmed removal. Record
  finds manually; observe readable openable bag items and portable contents only
  when loot matches a recently observed exact item GUID. Partial captures do not
  claim receipt or invent acquisition locations. Reuse the shared map layout,
  show recorded find/acquisition positions and a darkened current-zone map when
  no historical markers exist. Provide validated report-building and import
  hooks; Treasure report delivery/import-export UI remains deferred.
- Extend Account-wide tracking to Gathering, Atlas, Almanac and Ledger alongside
  the Bestiary. Import each character’s existing journal once, remap conflicting
  IDs and preserve relationships, observations, notes and original character
  stores for opt-out. Treasure remains per character. Preserve deleted Atlas
  references as unresolved instead of accidentally attaching them to imported
  records. Keep section resets, backups and sharing boundaries independent.
- Show confirmed Bestiary abilities in creature tooltips without requiring a
  locked entry. Preserve each ability’s tooltip checkbox, allow changes while
  locked, add available spell icons and Ctrl-expanded descriptions, and omit
  unreadable or restricted metadata. Add 20 recorded effect immunities plus
  optional expected-type guidance and persistent overrides. Expected immunities
  default OFF, remain visibly unverified and are excluded from shared evidence.
- Record Bestiary parent zones and their observed sub-zones separately, with
  sub-zone hover lists and conservative repairs for identifiable legacy entries
  such as Sentinel Tower/Westfall. Preserve Knowledge, backups, account merges
  and ambiguous history. Fix auto-lock streaks restarting for routine loot
  quantities or corpse history; newly learned loot item identities still restart
  progress. Cache unchanged content checks during routine observation without
  retaining deleted/replaced entries, and preserve streaks across migration.
- Improve Atlas label placement by measuring text, trying line breaks and moving
  names into free space before hiding them. Save per-map sub-zone colours across
  sessions while retaining unique assignments and perceptual contrast for new
  areas. Initially open the current zone and retain later deliberate map choices.
  Add the Record Atlas survey point keybinding with more-than-15-yard spacing
  from existing survey samples, preserving manual samples through reloads.
  Toggle Automatic Mapping starts ON, persists across sessions and pauses only
  automatic recording; manual mapping and Clean Redundant Points remain available.
- Split Gatherer’s Field Notes into notes and Observed Loot columns. Record
  readable drops from completed gathers, with item icons, quality colours,
  tooltips and observed stack ranges; exclude unrelated or ambiguous sources and
  preserve observations through account merges. Existing past gathers cannot be
  reconstructed. Protect unsupported future Gathering saves with a detached,
  read-only view and update notice.
- Extend the existing mouseover keybind to open the most relevant journal:
  hovered herbs/mining nodes in the Compendium, remembered service NPCs in the
  Ledger, or creatures in the Bestiary. Select and reveal the matching entry,
  preserve note drafts and existing key assignments, and retain the old macro
  function. Hovering a resource does not count a gather or record coordinates.
- Align Ledger and Treasure map dimensions, borders and toolbar spacing with the
  Almanac. Repair fishing hover lookups through spot merges, chained corrections,
  reloads and account imports; rebuild catch indexes while preserving historical
  aggregates. Expand Lua 5.1 model, capture, migration, report and widget tests,
  architecture documentation and in-game verification checklists. Automated
  verification remains separate from live-client visual checks.

## v0.15.37 - Included in v0.15.37-beta

- Fix Bestiary auto-lock progress restarting on routine loot counters and corpse
  history. New loot item identities still restart progress immediately; existing
  kill streaks survive the signature-format update and reloads.
- Reuse unchanged Bestiary content checks during target/mouseover polling,
  avoiding repeated signature serialization and temporary memory allocation.
  The cache does not retain deleted or replaced journal entries.
- Keep deleted Atlas destinations and related links unresolved during account
  imports, and avoid assigning incoming records to existing missing-reference IDs.
- Preserve unsupported future Gathering saves without normalization or capture;
  show an update notice in the detached read-only journal view.
- Preserve merged fishing hover lookups through further sightings, chained
  corrections, reloads and account imports; repair older stale merge lookups.
  Rebuild catch indexes without combining historical aggregates or unnecessarily
  splitting future catches into new aggregates.
- Add regression coverage for these audit findings, saved-state compatibility,
  repeated idle observation and the corresponding section storage boundaries.

## v0.15.1 - v0.15.37 - Included in v0.15.37-beta

- Extend Open Azeroth Fieldbook at mouseover to herb and mining nodes, selecting
  and revealing the matching Gatherer’s Compendium entry without recording a gather.

- Announce newly discovered merchants in chat once per recorded merchant;
  repeat visits and reloads do not repeat the notice.

- Split Gatherer’s Field notes into side-by-side notes and Observed loot panels.
  Record readable drops from completed gathers, with icons, quality colours,
  tooltips and observed stack ranges; retain loot through account-store merges.
- Add Toggle Automatic Mapping above Atlas cleanup, enabled by default and
  saved between sessions. Manual survey points remain available while paused.

- Add the Record Atlas survey point keybinding, with map-wide 15-yard spacing
  from existing survey samples. Preserve manual points across reloads; use
  Clean Redundant Points to simplify them deliberately.

- Shift Atlas labels to nearby free space and try alternate line breaks before
  hiding them; remove the fixed label-width limit.
- Remember each map’s sub-zone colour assignments between sessions, preserving
  unique colours and the existing perceptual-contrast selection for new areas.

- Hide missing NPC sub-labels in Merchant’s Ledger and show contact names in
  yellow with sub-labels in white in the directory and contact details.
- Add a gentle dark background behind the Merchant’s Ledger contacts list.

- Collapse missing sub-label lines in contact rows and details, including shorter
  list rows so subsequent contacts move up.

- Retry merchant/trainer capture when the interaction NPC is initially unreadable;
  recover on updates and cancel pending opening retries on close.

- Show available item icons and item hover tooltips in Known goods and its
  expanded details view, retaining readable names when metadata is unavailable.

- Display NPC sub-labels in angle brackets and recover titles from matching
  target/mouseover tooltips, including bracketed titles without a typed level line.

- Replace unsupported favourite/bookmark star glyphs with native checkbox/check
  textures in buttons and saved contact, fishing and treasure list entries.

- Anchor favourite/bookmark checkboxes and checkmarks in the same fixed left
  slot, with stable label alignment when switching between Favourite and Saved.

- Add confirmed Ledger contact removal, clearing saved observations and identity
  indexes while allowing ordinary future interactions to record the NPC again.

- Correct escaped texture paths for the fixed favourite/bookmark indicators;
  verify both texture paths as well as stable toggle positioning.

- Enlarge Known Goods item headings and use cached item-quality colours, with
  white text when quality metadata is unavailable.

- Move Known Goods and Observed Training into toggleable tall left-pane overlays
  with Bestiary-style yellow selected borders; reserve the lower panel for notes.

- Replace Ledger contact pagination with a scrollable, bounded row pool. Preserve
  scroll position on updates and reset it when filters change.
- Accept NPC titles on name-typed or legacy untyped tooltip lines and add the
  Innkeeper role alongside Merchant when the observed title identifies it.

- Add a portrait beside the selected Ledger contact’s name, using the matching
  live NPC or its recorded creature template, with a placeholder for manual entries.
- Increase the fixed favourite/bookmark checkbox inset and accompanying text padding.

- Replace the stretched contact-row hover image with a light translucent fill.

- Render Ledger NPC portraits as masked circular 2D textures with native portrait
  trim, using live unit portraits or resolved creature display portraits.

- Hide unrestricted stock lines in Known Goods, grey the First/Last observation
  details, and omit purchase warnings for items that were unusable when inspected.

- Replace the decorative Ledger portrait border with a simple masked copper ring.
- Narrow Favourite/Saved to 110 pixels while retaining its checkbox padding and
  right-edge alignment.

- Make Edit Notes a yellow-outlined toggle. Increase Known Goods headings by
  two points and gently scroll overflowing names on hover.
- Shorten the Known Goods price label to Price.

- Compact Known Goods prices to cost / quantity (individual cost each), omitting
  zero currency denominations and retaining Free and Unknown price states.

- Colour the g/s/c suffixes gold, silver and copper on the combined Price line;
  the redundant separate per-item line is omitted.

- Remove the redundant Not usable when inspected line from Known Goods.

- Keep Known Goods heading sizes fixed at the base font plus two points across
  mouseover refreshes and overlay reuse; reset body fonts from their base as well.

- Rename the mouseover binding to Open Azeroth Fieldbook at mouseover and route
  remembered service NPCs to their Ledger contact before trying the Bestiary.
  Preserve existing key assignments and the old macro function.

- Remove redundant Access Notes controls/helper text. Align Ledger and Treasure
  map toolbars to Almanac’s six-pixel button gaps and map clearance.
- Show a darkened current-zone map when Treasure has no historical markers, using
  the shared aspect-fit map renderer without adding observations.
- Start Traveller’s Atlas on the current zone at its first opening each session;
  preserve subsequent deliberate map choices.

- Prefer a recorded Ledger position in the latest sighting’s area over a newer
  zone-only sighting, keeping explicit selections and provenance intact. Clarify
  that missing coordinates apply to the selected sighting, not the whole contact.

## v0.15.0 - Included in v0.15.37-beta

- Implement Treasure Journal in its existing tab: a searchable catalogue of
  world finds, portable containers and salvage, independent historical encounters,
  personal/manual/reported provenance, combined filters and name/location/recent
  sorting. Preserve selection, list position, detail state and editor drafts.
- Add a scrollable Record a find form, explicit contents/recovery assertions,
  approximate or manually corrected locations, access observations, kind and
  encounter notes, Look for again bookmarks and confirmed encounter removal.
- Reuse an independent Atlas map instance with its exact viewport and anchor.
  Show historical world finds and recorded portable acquisitions, overlapping
  encounter selection and an all-finds-in-zone scope. Portable openings and
  observed carriage never create acquisition/world-treasure markers.
- Observe readable openable bag items in the background. Capture portable
  contents only when item-origin loot matches an exact recently observed item
  GUID; coalesce repeated events and expire transient context. Captures remain
  partial and do not claim receipt. Ambiguous world identities, access outcomes
  and acquisition sources remain manual; unrelated loot is omitted.
- Add bounded versioned report builders, validation, detached preview/acceptance
  and provenance-aware deduplication/forwarding hooks. Private notes are opt-in;
  reported evidence grants no personal counts or points. Existing transport is
  Bestiary-specific, so delivery and import/export UI are explicitly deferred;
  no parallel protocol or alternate cost-free export is introduced.
- Add isolated per-character SavedVariables and additive loading/registration.
  Document data/API boundaries and pending in-game checks; add focused Lua 5.1
  model, capture, report, map, UI and regression tests. Other page implementations
  and existing working-tree changes are preserved. No publication is performed.

## v0.14.7 - v0.14.8 - Included in v0.15.37-beta

- Use the same shared arrow artwork, shadow and label spacing for Effect
  Immunities, zone and map-layer dropdowns. Expected immunities remain optional
  and OFF by default in Options.
- Remove the Effect Immunities dropdown header and its unused vertical space.

## v0.14.6 - Included in v0.15.37-beta

- Extend Account-wide tracking to Herbs & Minerals, Atlas, Almanac and Ledger.
  Import each character section once, preserve original character stores, and
  remap colliding record IDs while retaining routes, catches and contact references.
- Put effect immunities in a compact checkbox dropdown. Rename the summary to
  Expected Immunities and add optional Polymorph guidance excluding Humanoids, Beasts and Critters.
- Add Show expected immunities in Options, OFF by default. Toggling it preserves
  recorded marks and overrides; suggestions remain unverified and unshared.
- Keep burning Fire damage under the existing Fire immunity control; update
  documentation, help, migration tests and defense regressions.

## v0.14.5 - Included in v0.15.37-beta

- Add 20 effect immunities to Bestiary Defenses, including Fear, Polymorph, Bleed,
  crowd-control effects and debuff types. Show recorded effects in the creature
  summary and support normal backup, account merge and rumour-review sharing.
- Automatically show Bleed and Fear expectations for personally encountered
  Mechanical creatures, clearly labelled as unverified Classic type guidance.
  Allow persistent overrides; keep expectations out of verified marks and sharing.
- Document the guidance sources and limitations and add regression coverage.

## v0.14.4 - Included in v0.15.37-beta

- Record Bestiary locations using the parent zone map, keeping observed subzones
  separately. Hover a zone name in the creature summary to see its sorted subzones,
  including fresh observations on locked entries.
- Repair identifiable legacy subzone locations, including Sentinel Tower when
  Westfall is also recorded, in live locations, locked snapshots and discovery
  credit keys without changing earned Knowledge. Preserve ambiguous history.
- Preserve subzones in backups and account merges; document migration limits
  and add zone, hover, migration, persistence and restricted-data regression checks.

## v0.14.1 - v0.14.3 - Included in v0.15.37-beta

- Add spell icons beside resolved Bestiary tooltip abilities. Hold Ctrl to expand
  readable spell descriptions, with a grey (Ctrl for details) hint when available
  and live refresh when Ctrl is pressed or released. Preserve checkbox filtering
  and safely omit unavailable or restricted metadata.

- Show confirmed Bestiary abilities in creature tooltips without requiring a locked
  entry. Each ability checkbox defaults to on and remains usable while locked;
  existing tooltip choices are preserved. Update help and regression coverage.
- Clarify tooltip defaults, preserved OFF choices and pending/rejected exclusions
  in the README and automatic-recording notes; add a native UI verification checklist.

## v0.14.0 - Included in v0.15.37-beta

- Implement Merchant’s Ledger in its existing tab: a per-character directory
  of encountered merchants, trainers and useful services, with actual NPC
  sublabels, overlapping roles, favourites and prominent private access notes.
- Capture readable merchant and trainer offerings in the background without
  purchases. Freeze each visit's contact, retain per-vendor quotes and stock,
  distinguish finite/sold-out/unrestricted/unknown states, exclude buyback and
  preserve positive history through partial or filtered inspections. Deferred
  metadata cannot move stock between contacts or refresh observation dates.
- Use stable local contact references and bounded GUID aliases; preserve
  same-template ambiguity and provide explicit same-individual identity linking.
  Add case-insensitive reverse item/recipe/lesson search, matching reasons,
  multi-role, recorded-zone/subzone, personal/reported, favourite and recipe
  filters, name/recent sorting, scoped reset and persistent browsing state.
- Reuse the exposed Atlas map factory with its exact viewport and anchor in an
  independent Ledger instance. Show selectable historical sightings and provenance,
  approximate interaction coordinates, and honest unknown-location fallbacks.
- Add bounded literal Ledger reports with preparation, copy/paste, validation,
  frozen preview/acceptance and per-fact provenance/receipt dates. Private notes
  are opt-in; imports preserve personal evidence and forwarding preserves age.
  Bestiary-specific transport, point prices and rewards are unchanged; Ledger
  delivery/rewards are explicitly deferred rather than simulated.
- Add isolated Ledger SavedVariables, additive module/section initialization,
  focused Lua/widget regressions and a Forever in-game acceptance checklist.
  Other section implementation files are unchanged. Native visual/runtime
  verification remains a client smoke test.

## v0.13.37-beta - 2026-09-28

This release includes all changes since v0.13.30-beta and the previous push at
`6475d750ef47d6610e981ba29bfdeeca6599bdcd` (local versions 0.13.31–0.13.37).

- Atlas interior samples now require strictly more than 50 yards from every
  recorded sample on the same map, including cross-over points and differently
  named sub-zones. Exactly 50 yards is rejected; rejected attempts do not delay
  the next eligible sample. Cached spatial checks apply to queued observations
  and reloads. Cross-over recording retains its separate ten-yard border rule.
- Atlas and Almanac maps show the client's native zone/continent hover glow,
  positioned for the current zoom and pan. The highlight clears on mouse exit,
  hidden maps, placement mode and disabled navigation; missing map APIs are safe.
- Add the saved, opt-in Hide zone-name areas checkbox to Atlas Sub-zones controls.
  It hides shading and labels matching the displayed zone name, while preserving
  sample points, stored observations, neighbouring geometry and colours. Four
  checkboxes fit within the existing controls box without moving the map.
- Add Clean Redundant Points beside a narrowed Map Layers selector. Cleanup
  removes strictly enclosed interior observations on the selected map, retaining
  perimeter evidence, cross-over points and samples needed to separate overlapping
  regions. It checks potential ownership changes rather than protecting every
  point whose influence overlaps another area's perimeter. Consecutive removal
  decisions account for already removed samples.
- Run cleanup in small background work slices. Report the start, sample count,
  progress, removals and retention reasons in chat. Preserve other maps and
  discoveries; reject stale results if samples arrive during processing, and
  prohibit cleanup of read-only journals. The cleanup button has extra text room.
- Merge gathering positions within or exactly ten yards for the same herb/mineral
  on the same map, on load and during interaction capture. Keep a stable position
  and newest observation time, without changing resource identities, notes or
  interaction counts. Use cached map dimensions; unavailable dimensions preserve
  positions and defer cleanup until a subsequent interaction can resolve them.
- Group leatherworking materials under a Skinning heading at the bottom of
  creature loot lists. Use item categories for existing records as well as new
  ones; leather armour remains ordinary loot. Historical loot method was not
  recorded, so this is material grouping, not a new source attribution or drop
  rate calculation. Quantities and observed rates are unchanged.
- Expand regression coverage for spacing thresholds, reloads, pending samples,
  cleanup boundaries and concurrency, display filtering, hover rendering,
  gathering cleanup and loot grouping. The full 47-file test suite passes.

## v0.13.35 - v0.13.37 - Included in v0.13.37-beta

- Gathering locations now merge positions within or exactly 10 yards for the same resource on the same map. Existing saved nodes are cleaned on load, keeping a stable position and the newest observation time; nearby interactions update that position instead of adding another pin.
- Different resources/maps, notes and interaction totals remain distinct. Distances use cached map dimensions; unavailable dimensions leave existing positions intact and cleanup retries on the next interaction.
- Creature loot lists place leatherworking materials under a Skinning heading after other loot. Classification uses item metadata (including existing records); historical loot method and observed rates are unchanged. Leather armour remains ordinary loot.
- Widened Clean Redundant Points and added chat progress and retention-reason counts. Cleanup now tests actual potential ownership changes instead of protecting every interior point whose influence overlaps another area's perimeter.



## v0.13.34-beta - Included in v0.13.37-beta

- Added “Clean redundant points” beside the narrowed Map Layers button. Cleanup removes strictly enclosed interior samples on the displayed map, preserving cross-over observations, perimeter samples and evidence influencing overlapping sub-zone boundaries.
- Cleanup runs in small background work slices, reports the removal count and rejects stale results if new samples arrive. Read-only journals cannot be modified.

## v0.13.33-beta - Included in v0.13.37-beta

- Added a saved, opt-in “Hide zone-name areas” checkbox in the Atlas Sub-zones group. It hides shading and labels whose name exactly matches the displayed map's zone name, without altering sample points, recorded evidence, neighbouring geometry or colours.
- Fits the fourth checkbox within the existing controls box and preserves the map layout.

## v0.13.32-beta - Included in v0.13.37-beta

- Interior samples now require strictly more than 50 yards from every other sample on the same map. Cross-over spacing is unchanged. Rejected attempts no longer impose a separate movement delay on the next eligible sample.
- Atlas and Almanac maps use the client's native region-highlight artwork when hovering navigable zones or continents, with coordinates adjusted for zoom and pan. Highlights clear on mouse exit, hidden maps, placement mode and disabled navigation.

## v0.13.31-beta - Included in v0.13.37-beta

- New 100-yard interior observations are skipped when any recorded sample on the same map is less than 100 yards away, regardless of sub-zone name or sample type. A cached spatial grid keeps nearby-point checks inexpensive, including queued observations and reloads.
- Cross-over points retain their existing border-pair spacing rules. Existing observations are preserved under their previous compaction rules.

## v0.13.30-beta - 2026-09-28

Traveller's Atlas and Angler's Almanac are now working personal journals. This
release includes the full development batch from v0.12.0 through v0.13.30, plus
the publication tooling introduced after the previous release. Previous-push
baseline: `d0aafda624c451d552cec39ff67ec64ecf6cbe5c`. Previous release:
`v0.11.0-beta` at `6460b95e73462df4c89faae904f2378a97937b51`.
Both players must use the same installed addon version to share Bestiary records.

- Add Traveller's Atlas with a searchable discovery index, eight independently
  selectable map-marker layers, synchronized map/list selection, place and entrance
  editing, optional coordinates, access notes and explicit explored status. Add
  ordered routes and waypoints, expedition journals, related discoveries and
  read-only links to Bestiary and gathering records. Keep browsing state and
  unfinished forms when changing pages. Atlas records use their own character
  SavedVariables and stay separate from Bestiary resets, backups and account mode.
- Add Atlas regional-report drafts with explicit record, note and excerpt
  selection, complete previews, bounded literal serialization and strict validation.
  Preserve provenance and unresolved references; imported staging remains Reported
  and unexplored. Atlas report delivery/import controls remain deferred.
- Discover Atlas sub-zones from actual border crossings and interior observations.
  Record crossing from/to names, both positions and time; add an initial interior
  observation and further samples about every 100 map yards. Coalesce same-border
  crossings within ten yards, including reverse crossings, and deduplicate interior
  revisits. Retain pending observations on logout. Map/area/sample caps bound storage;
  interior data leaves capacity for borders. Missing coordinates and discontinuities
  never fabricate a crossing. Observations continue with the Atlas closed.
- Estimate sub-zone coverage with smooth triangle contours and unique colours,
  selecting new colours for maximum minimum perceptual separation while retaining
  current assignments during live updates. Keep unexplored areas empty and identify
  estimates and observation types in hover details. Checked Points shows every
  sample; unchecked preserves automatic isolated dots and hides incorporated samples.
  Dots stay small at every zoom. Independent outlined labels try two lines before
  hiding; size spans 2-24 and defaults to 4, preserving saved preferences. Map
  brightness spans 20-100% without dimming overlays or the player arrow.
- Remove synchronous sub-zone rebuilds from crossing capture. Share a small
  per-frame work budget across indexing, geometry and pooled drawing; retain the
  completed overlay while preparing its replacement. Reuse per-map geometry,
  bound mesh detail, skip unseen space and release cancelled work. Keep all display
  controls in a grouped panel; Map Layers is a checkable dropdown directly above
  the map, with Show all / Hide all and saved independent category filters.
- Give Atlas and Almanac matching native map borders, facing arrows and outlined
  player coordinates. Support cursor-centred 1x-4x zoom, clamped drag panning,
  marker selection and optional left-click zone/right-click parent navigation.
  Use shared cascading, scrollable zone menus with battleground and Other groups,
  matching selector widths and native dropdown arrows with drop shadows. Preserve
  the map frame while zooming; Atlas also records encountered weather per zone.
- Add Angler's Almanac with linked Waters & Spots, Pool Types and Catches views,
  search, filters, favourites, notes, saved browsing state and reverse source lookup.
  Record acquired fishing loot from readable fishing evidence, deduplicate autoloot,
  partial snapshots and retries, and keep uncertain sources unclassified. Retain
  source-specific quantities, occurrences, first/latest observations and measured
  successful-skill evidence. Provide expiring source assignments and manual catch,
  spot and sighting fallbacks; keep player assertions distinct from observations.
- Discover fishing pool types from live world tooltips without inventing positions
  or assigning catches. Support removable/restorable pools and sightings, spot
  merging, Ctrl+right-click marker removal and corrections that preserve catch
  history. Handle localized escaped/not-hooked failures and late loot notifications.
  Show real item icons/tooltips and order catches newest first. Almanac records are
  character-owned and isolated from the other journals.
- Add selected fishing reports with optional notes, strict validation, literal
  serialization, preview/accept import, original provenance and idempotent result
  handling. Reports cannot change personal totals or rewards; addon-message
  transport and fishing pricing remain unconfigured. Add a persistent, uncapped
  Almanac Event Log with newest-first pages, live updates, combined catch entries,
  duplicate suppression and confirmed clearing independent of journal data.
- Rename Herbs & Minerals to Gatherer's Compendium. Add independent character
  toggles for recorded nodes on the world map and minimap, both initially off.
  Share round green herb/gold mineral artwork with dark borders, retain readable
  size through world-map zoom, and draw above terrain/fog. Reuse at most 512 world
  and 128 nearby minimap pins while preserving all saved locations. Improve detail
  headings, dividers and location controls. Capture quick first-click tooltip
  identity immediately while keeping coordinates gated on confirmed interactions.
- Add Bestiary Loot as the default detail panel, with item quantities, corpse-based
  drop percentages, icons/tooltips and a Show Damage toggle. Deduplicate recent
  corpse snapshots, retain money-only source evidence, support modern/legacy item
  APIs and safe unavailable-item placeholders, and include loot in backups and
  account migration. Move Known Beast Lore above the model and keep the loot panel
  full height with inset scroll controls. Start one loot listener at initialization
  and reuse it, fixing repeated listener allocation from tooltip updates.
- Add shared Help and Options access across sections, saved Dark Mode alongside
  brightness, consistent pane dividers and native-window stacking that lets game
  panels rise above Fieldbook. Three remaining wishlist pages stay presentation-only.
  Preserve existing window positioning, section navigation and Bestiary data.
- Bound transient creature/player caches, reconcile combat-session identities with
  readable retained history, handle meter resets and defer wipe reconciliation when
  history is unreadable. Release closed backup snapshots and hidden map references,
  remove stale report-draft selections, and reject sparse lists rather than silently
  truncating routes/reports. Add retained-memory, pooled-widget, dense-map, capture,
  geometry, persistence and report regressions plus a repeatable sub-zone benchmark.
- Validate all 55 runtime Lua files and run all 47 test files before publication.
  Keep tests as a release dependency, publish a size-checked version-specific
  changelog to GitHub and CurseForge, and retain recovery support for an existing
  immutable tag without duplicating a successful CurseForge upload. Native game
  API/visual checks remain documented; stable 1.0 still awaits live Beast Lore
  verification after the Forever beta level cap permits it.

## v0.13.29 - Included in v0.13.30-beta

- Make checked Atlas Points reveal every recorded sample, including crossings
  and interior observations already incorporated into shading, without coarse
  display-cell merging. Unchecked retains automatic isolated dots with shading
  and hides incorporated samples. Verify toggles, zoom, both rendering buffers
  and unchanged saved evidence.

## v0.13.28 - Included in v0.13.30-beta

- Record an initial sub-zone interior observation and further samples about every
  100 map yards, so exploring an area expands estimated shading without requiring
  a border crossing. Deduplicate revisits, cap interior data to reserve space for
  crossings, preserve queued observations on logout, and keep capture and rendering
  within the existing asynchronous workflow. Distinguish interior observations in
  saved data and tooltips; retain the ten-yard border filter.
- Measure sub-zone label widths and try a balanced two-line name before hiding
  it for width or overlap. Keep the thin outline, chosen text size and reusable
  font pools. Add coverage for interior sampling, geometry, bounds, persistence,
  tooltips and label wrapping.
- Move only Atlas Map Layers directly above the map, keeping the Zone selector
  in place. Match the Angler's Almanac zone selector to the Atlas's 306-unit width.
  Replace typed dropdown markers with native arrow artwork and dark drop shadows
  on all three buttons.

## v0.13.6 - v0.13.27 - Included in v0.13.30-beta

- Match the Atlas Zone selector to the Map Layers dropdown width. Extend the
  sub-zone panel upward into the freed space and place Shading, Points and Labels
  on separate rows, with label size alongside Labels.

- Add a saved Atlas Points toggle for isolated sub-zone crossovers, independent
  of shading and labels. Group the sub-zone controls in a compact bordered panel
  beside the map-marker layers, aligned with the page's right edge and preserving
  the map's size and position. Display
  changes reuse geometry and leave recording and saved observations intact.
- Expand sub-zone colours beyond the ten-accent palette. Give each discovered
  area on a map its own colour, choosing new colours by their greatest minimum
  perceptual distance from all assigned colours. Preserve existing colours during
  live updates and keep selection within the background drawing budget. Add a
  thin non-monochrome outline to sub-zone labels and default their size to 4,
  preserving explicitly saved sizes.
- Replace the Atlas marker-layer rows with a Map Layers dropdown containing
  checkboxes for every category and Show all / Hide all actions. Keep the menu
  open while changing several filters, preserve saved preferences, and leave
  discovery records and sub-zone controls independent.

- Keep the Loot/damage scrollbar and arrow artwork inset inside the panel. Remove the separate track backdrop that created a visible seam beside the content.

- Capture gathering tooltip identity immediately so a quick first click followed by a missing-profession error can record the node before the polling fallback runs. Keep coordinates gated on confirmed interactions.

- Default the Bestiary panel to Loot and reverse its toggle to Show Damage. Fill the scrollbar strip behind both arrows and align its outer edge with the panel to close visible gaps. Move Known Beast Lore above the creature viewer and retain the full loot-panel height for beasts.

- Fix the Loot panel crash when the legacy GetItemInfo global is unavailable. Prefer C_Item.GetItemInfo, retain the legacy fallback, and show placeholders safely while item information is unavailable. Add regression coverage for modern, legacy, missing and uncached item APIs.

- Add a matching Loot toggle above Behaviour, showing observed item quantities, corpse drop percentages, icons and tooltips in the damage panel. Persist observations and include them in backups and account migration.

- Remove synchronous Atlas mesh rebuilds from crossing capture. Prepare spatial
  indexes, geometry and pooled texture updates in small shared-budget slices;
  retain completed shading until its replacement is ready. Cache per map, reuse
  workable mesh detail, skip unobserved space and avoid repeated metadata reads.
- Thin same-border samples within approximately 10 map yards, in either direction,
  including existing saved observations when their map is visited or displayed.
  Preserve distinct borders and retained records' labels/positions/timestamps;
  retain pending crossings across logout and use the existing coordinate fallback
  when map dimensions are unavailable. Reduce mesh density while keeping smooth
  triangle contours. Add scheduling/compaction regressions and a repeatable
  synthetic performance benchmark.

- Lower the Atlas sub-zone label-size minimum from 8 to 2 for close-up map
  viewing. Keep the default at 12 and maximum at 24; retain small sizes on reload.

- Keep isolated Atlas sub-zone samples as small round dots at every map zoom.
  Hide dots once their evidence contributes to shaded boundary geometry, while
  preserving the underlying crossing records and hover details.

- Move Sub-zones into the map-layer rows and add independent Sub-zone labels,
  a styled label-size slider (8–24) and map-brightness slider (20–100%). Save
  display preferences per character; dim artwork without dimming observations.
  Use brighter saturated shading and refined triangle contours instead of
  coarse square edges, with adaptive detail to bound native texture allocation.
  Preserve map dimensions, discovery evidence and the Almanac.

- Add a Sub-zones checkbox beside Atlas map layers without moving existing controls.
  Record personal same-map crossings in the background with from/to labels, both
  positions and time; persist per character and reject discontinuous observations.
  Show crossing dots, names and estimated perimeter shading, assign different
  colours to neighbouring regions, and expose evidence on hover. Keep unseen
  regions empty and label geometric estimates honestly. Add isolated storage,
  geometry, reload, background tracking and pooled-overlay regression coverage.

- Add left-button drag panning to zoomed Atlas and Almanac maps, including drags
  starting on markers. Clamp movement to the map edges and distinguish dragging
  from clicks so zone navigation, marker selection and point placement still work.

- Replace Atlas continent/zone controls with one cascading zone selector and
  share it with the Almanac. Base maps expand into zone submenus; battlegrounds
  have a separate group and Zephras Isle appears under Other. Native scrollable
  menus reuse the same catalogue and selection code without adding journal data.

- Add world-map click navigation to Atlas and Almanac: right-click opens the
  parent map, left-click opens the zone under the pointer. A shared Options toggle
  defaults on and applies immediately; preserve wheel zoom, placement and marker
  actions. Widen Almanac Reports to match adjacent button spacing.

- Put Fieldbook windows on the normal game-window layer, preserving click-to-front
  behavior so native game panels can rise above the addon when clicked.

- Add Ctrl+right-click removal and tooltip instructions to Almanac map markers.
  Remembered spots can be restored through Show: removed; removing an automatic
  fishing-position marker retains catch history and allows new catches to show
  a new position. Give both maps' player coordinates a thin antialiased outline.

- Match the Almanac Current Zone button to the Atlas button's size, keeping its
  right edge aligned with Record catch underneath.

- Rotate Almanac actions so Current Zone is at the top right, Reports is to its
  left and Record catch is underneath. Move player coordinates to the bottom-left
  of both the Almanac and Atlas maps.

- Keep record names in the yellow detail title without repeating them in the
  description, and sort the Catches list by most recent catch first.

- Add an Almanac Event Log through the existing title-bar log button. Keep the
  ongoing timestamped history per character across reloads, with newest-first
  pages of 50, live updates, and confirmed clearing that leaves journal data intact.
  Record acquired catches, explicit fishing failures, pool discoveries, source
  assignments, skipped captures and corrections; combine partial catch updates
  and suppress repeated observations. Add regression coverage and documentation.
- Remove the initial event cap. Reuse log widgets, render only the current page,
  and index cumulative updates without scanning the history. Verify thousands of
  retained entries, reloads and garbage collection after clearing.

## v0.13.5 - Included in v0.13.30-beta

- Handle localized fish-escaped and fish-not-hooked errors: discard pending loot,
  ignore late notifications from that attempt and resume on the next cast/loot
  window without changing catch totals, skill evidence or the session source.
- Add Remove sighting / Restore sighting in Waters. Keep notes and catch history,
  suppress removed automatic sightings in their zone, and omit corrected sightings
  from pins, location links and outgoing reports without removing the pool type.
- Cover native world tooltips that bypass processor callbacks with throttled
  visible-tooltip checks and a world-focus guard when processing info is absent.
  Automatically recorded entries are labelled Pool zone sighting.
- Show actual item icons and native item tooltips in Recorded catches and the
  main Catches index, with safe fallbacks for uncached or name-only items.

## v0.13.4 - Included in v0.13.30-beta

- Discover fishing pool types in the current zone from recognizable live world
  tooltips, without creating coordinate pins or assigning subsequent catches.
- Add Remove pool and a Show: removed / Restore pool path. Suppress automatic
  re-addition while preserving notes, reports and catch history.
- Fix missing-cast-identity rejection of confirmed fishing loot with local
  event IDs. Preserve pending autoloot evidence when the fishing flag arrives
  after loot-slot snapshots or clear events; retain retry deduplication and
  require acquired items, not chat messages or bag changes.

## v0.13.1 - v0.13.3 - Included in v0.13.30-beta

- Place player coordinates inside the displayed map's lower-right corner in
  Atlas and Almanac, right-aligned and fixed above the zooming map artwork.

- Enable cursor-centred scroll-wheel zoom from 1× to 4× on Atlas and Almanac
  maps, including over pins. Clip artwork, overlays, routes and markers within
  the existing border; preserve map placement coordinates and reset zoom when
  changing maps. Each journal keeps its own zoom while browsing the same map.

- Give Atlas and Almanac maps a thin border using the main window's native
  frame artwork, with matching dialog-border fallback. Keep map geometry and
  mouse interaction unchanged.

## v0.13.0 - Included in v0.13.30-beta

- Implement Angler’s Almanac as a character-owned fishing journal with linked
  Waters & Spots, Pool Types and Catches views, search, compact filters,
  reverse source lookup, saved browsing state, notes and favourites.
- Record acquired fishing loot in the background using readable fishing-loot
  and cast evidence. Deduplicate repeated slots, autoloot and full-bag retries;
  keep uncertain sources unclassified. Add visible, expiring player source
  assignments and explicit manual catch/sighting/spot fallbacks.
- Preserve quantities, event occurrences, first/latest observations and measured
  successful-skill evidence in durable source-specific aggregates with bounded
  recent history. Keep player assertions and reported claims distinct.
- Reuse the exposed Atlas map renderer through an Almanac-local data adapter,
  matching its exact geometry without changing Atlas or another page. Recorded
  pins select journal entries; duplicate-spot merging preserves original notes,
  positions and associated history.
- Add selected fishing-report construction, bounded literal serialization,
  strict validation, preview/accept import, original provenance and idempotent
  result deduplication. Notes are opt-in; reports never alter personal totals or
  rewards. Addon-message transport and fishing pricing remain unconfigured.
- Add automated data, capture, report, UI-state, layout and section-regression
  coverage, and document Forever API evidence and unperformed in-game checks.

## v0.12.15 - v0.12.20 - Included in v0.13.30-beta

- Color the “Observed Weather:” label yellow, keeping weather types in their
  existing text color.
- Move Observed Weather beneath the map as one comma-separated line, separate
  from discovery details. Place route/map status text inside the details area.
- Center the Atlas right-pane controls, map and details between the divider and
  inner window edge, balancing the left and right margins.
- Reduce Atlas maps by 1%, giving the details panel four more pixels. Remove
  the map drop shadow introduced in v0.12.16 in v0.12.17.
- Add Observed Weather for the selected Atlas zone. Encountered weather types
  accumulate per zone in the character’s Atlas journal, including while the
  Atlas is closed; unavailable weather never implies clear skies.

- Add live player coordinates to Traveller’s Atlas, explicitly labeling another
  map and unavailable data. Enlarge standard zone maps by 25% within the existing
  window, keeping unusually wide assets within the map column. Reflow the
  scrollable details and action buttons below the enlarged map.
- Remove the persistent map-layer reminder and selected-pin asterisk, retaining
  the gold border and larger selected pin. Test coordinate updates, map sizing
  and unchanged shell dimensions alongside the full regression suite.

## v0.12.14 - Included in v0.13.30-beta

- Audit runtime memory ownership, UI reuse, tracking, persistence and report
  validation. Bound transient creature-instance and player-class caches; retain
  combat-session identities only while the client retains those sessions.
  Preserve durable discovery/kill credit and saved report-source class colours.
- Fix combat-history cleanup after meter resets, including reused session IDs.
  If a Bestiary wipe encounters unreadable history, wait for a complete readable
  snapshot before allowing new encounter imports.
- Bound gathering overlays to 512 recent world-map positions and 128 nearest
  minimap positions, reuse the native frames, and retain at most the two displayed
  maps' caches. Release hidden node references; all saved locations remain intact.
- Release unused Atlas marker groups and closed backup-import snapshots, and
  remove deselected Atlas report-draft keys, including existing false entries.
- Reject sparse Atlas lists explicitly instead of relying on Lua's undefined
  length for tables with holes, preventing silent route/report truncation.
- Add retained-heap, garbage-collection, dense-map, navigation and malformed-list
  regression coverage. Document findings, measured limits and live-client checks
  in `tests/AUDIT.md`.

## v0.12.3 - v0.12.13 - Included in v0.13.30-beta

- Show the player's facing arrow on the Atlas when viewing their current map.
  Update its position while visible, hide it for other maps or unavailable data,
  and stop updates when leaving Atlas without saving a movement history.

- Replace the unavailable Camp / Settlement icon with the native fire icon for
  both Atlas map markers and index rows; test the missing-asset case.

- Show Atlas Route / Passage markers at their recorded positions when they have
  no itinerary stops, whether selected or not. Preserve route-layer visibility
  and map boundaries; do not invent stops or positions. Add regression coverage
  for marker selection, hidden layers, unpositioned entries and later stop editing.

- Fix Atlas discovery-row tooltip errors, including Route / Passage entries:
  return only cleaned text from the Atlas sanitizer, preventing Lua's `gsub`
  replacement count from becoming an unintended tooltip color argument. Add
  regression coverage for single-value sanitization and all eight category hovers.

- Add a saved Dark Mode toggle beside background brightness in Options. Shared
  parchment uses the Locations greyscale treatment at 34% of the selected
  brightness; already-dark map backgrounds retain their existing treatment.

- Fix world-map gathering dots being covered by explored terrain and fog:
  use the normal map-location icon layer instead of the lower default pin layer.
  Verify ordering against installed Forever 70009 UI source and add a regression
  that reproduces working tooltips with obscured markers.

- Replace gathering-dot runtime masks with a bundled circular alpha texture to
  retain the circular appearance without runtime masks, preserving the
  same green/gold fill and dark border on all three maps.

- Combine Compendium node name and type into one heading (Peacebloom • Herb),
  and move the details, notes and map controls up to close the removed row.

- Counter-scale world-map gathering dots so they retain a visible six-pixel size
  as terrain zoom changes. Compensate their coordinate offsets and use Blizzard's
  map-pin drawing layer. Add regression coverage across five canvas scales.

- Add a vertical divider between the Atlas index and map panes, matching the
  Bestiary and Compendium colour, opacity, thickness and height.

- Match the Compendium divider's colour and opacity to the Bestiary divider,
  preserving their shared three-pixel thickness.

- Add Help to all main-window sections using the Bestiary button and shared
  parchment help-window layout. Include Compendium and Atlas usage instructions
  and each placeholder section's wishlist; keep Help and shared Options mutually
  exclusive, with navigation and help-window regression coverage.

- Share the Compendium location page's
  opaque, circular dot renderer with world-map and minimap markers: green herbs
  and gold minerals with a dark border. Add rendering-property regression checks.

## v0.12.2 - Included in v0.13.30-beta

- Rename Herbs & Minerals to Gatherer's Compendium throughout the current UI.
- Keep Locations button text the same size when hovered or pressed, and add a
  three-pixel horizontal divider above Field notes. Thicken the matching Bestiary
  divider above recorded abilities to three pixels as well.
- Add independent, per-character world-map and minimap node display checkboxes
  to the Compendium, both off by default. Show recorded approximate interaction
  positions on their zone map and nearby positions on the rotating/zooming minimap.
- Make the Options button available from every main-window section, including
  direct opening before visiting the Bestiary. Preserve the active section.

## v0.12.1 - Included in v0.13.30-beta

- Fix Lua errors when hovering Atlas map-layer checkboxes: use a wrapped tooltip
  body line instead of passing a boolean as `SetText`'s numeric alpha argument.
  Add native argument validation and regression coverage for all eight layer
  tooltips, mouse-leave dismissal and section-change dismissal.

## v0.12.0 - Included in v0.13.30-beta

- Replace Traveller’s Atlas with a personal geographical journal: zone maps,
  a searchable local/all-zone discovery index, eight independent map layers,
  synchronized pin/list selection and explicit current-zone/map-position actions.
- Add place and entrance editing, optional positions and interior labels, access
  notes, explicit explored status, stable identities and separate knowledge sources.
  Add ordered routes with existing places or waypoints, numbered markers and
  capability-guarded lines that never join different maps.
- Add expedition journals, zone associations, related Atlas records and read-only
  references to existing Bestiary and Herbs & Minerals discoveries. Preserve
  unresolved links when targets disappear; source pages remain unchanged.
- Add regional-report drafts, explicit private-note/excerpt selection and complete
  previews, with versioned validation, bounded non-executable serialization and
  Reported/unexplored recipient staging. Delivery and import UI remain deferred.
- Isolate Atlas persistence in its own per-character namespace; retain browsing
  state and unfinished editors across page switches, pool map controls and keep
  Atlas forms inside the existing window. Add logic/UI regression coverage and
  an explicit in-game verification checklist in `tests/ATLAS.md`.

## v0.11.0-beta - 2026-09-27

Herbs & Minerals is now a complete personal gathering journal. This release
includes the full local development batch from v0.10.9 through v0.10.17 and the
operator-designated v0.11.0 milestone. The previous-push and previous-release
baseline is `21abba4ba73d490d1f2d40cc7743ed26d59ea69c` (`v0.10.8-beta`).
Both players must use the same installed addon version to share Bestiary records.

- Recover publication after the full historical changelog exceeded GitHub's
  release-description limit. Publish the complete current version summary with
  a size check, preserve historical entries, and allow recovery from an existing
  tag without uploading to CurseForge twice. Test the selected release source
  before packaging; all 41 test files pass, including release-note regression
  checks. Recovery baseline: `6460b95e73462df4c89faae904f2378a97937b51`;
  the original v0.11.0-beta tag and addon files remain unchanged.

- Replace the Herbs & Minerals wishlist with a working page styled after the
  Bestiary: parchment, left index, A-Z tabs, search and clear control, sorting,
  sixteen-row list, clipped hover-scrolling names, scrollbar and Previous/Next
  navigation. Filter by Herbs, Minerals or known locations and search by name
  or zone. Sort by name, type, interactions, completed gathers or encounter dates.
- Discover herbs and mineral nodes from readable world-object mouseovers,
  including on characters without Herbalism or Mining. Record name, type,
  first encounter, zones and map identity. Hovered zones appear under Locations
  in basic info and participate in search/filtering, without creating coordinate
  markers or increasing interaction counts.
- Record approximate player coordinates only for identified interactions.
  Gathering casts count when they start, retain interrupted attempts and add a
  completed gather on matching success. Missing-profession or insufficient-rank
  errors can record a location from a live node tooltip even without a global
  click event; briefly retained world-click identities also survive tooltip
  dismissal. Reject unrelated errors, UI controls, stale/unreadable identities
  and mismatched casts; deduplicate repeated error/cast notifications. Completed
  gathers count successful casts, not quantities of looted materials.
- Give every resource its own Locations map, with zone selection, brightness,
  exploration art and a live player-position/facing arrow. Display small round
  green herb/gold mineral markers at discrete recorded positions, with no
  triangulation, connecting lines or shaded coverage. Consolidate repeated
  coordinates and bound histories to 256 positions per map and 64 maps per
  resource. Missing coordinates preserve readable entry/zone data without
  inventing markers; unavailable maps have an explicit empty state.
- Display draggable native 3D models for classic herbs and mineral nodes,
  including rare and ooze-covered variants. Use client-verified model file IDs
  and recognized object IDs for localized identities when available. The catalog
  supplies presentation assets only, never discovered entries or spawn locations.
  Keep previews at approximately 40% of their original apparent size, show an
  unavailable caption for unknown assets and avoid stale models. Load only once
  the page is visible and reload on tab/book reopening to fix blank previews.
- Simplify basic info to Herb or Mineral and provide interaction/completion
  totals and encounter dates. Make field notes editable by clicking the editor
  or its border, with Save notes bound to the displayed entry. Preserve separate
  saved notes and unsaved drafts for every resource, including clearing notes.
- Store gathering progress, notes and sort/map preferences separately per
  character in AzerothFieldbookGatheringDB. Preserve browsing state and drafts
  across section changes, continue collection while the page is closed and close
  gathering dialogs when leaving. Bestiary data, zoom, account tracking, resets,
  backups, sharing and the other five wishlist pages remain unchanged.
- Update documentation, architecture and milestone/versioning guidance. Add
  gathering event, persistence, model lifecycle, marker, note-editing and section
  navigation regression coverage. All 40 test files pass; all 38 runtime Lua files
  compile under Lua 5.1, with manifest, binding and version checks passing.
  Native in-game rendering remains a separate acceptance check.

## v0.10.17 - Local development (included in v0.11.0-beta)

- Fix blank Herbs & Minerals previews by waiting until the section and book are
  visible before requesting a model, and reloading the selected asset whenever
  the page opens. Keep the model above its backdrop and preserve the current zoom.
- Add regression coverage for hidden page construction, tab/book reopening,
  failed-load retries and preserved selection, search and note drafts.


## v0.10.16 - Local development (included in v0.11.0-beta)

- Replace gathering-map squares with smaller 6-pixel circular markers, retaining
  herb/mineral colours and a dark outline. Keep node positions discrete, with
  no triangulation, connecting lines or shaded coverage areas.
- Simplify gathering basic info to Herb or Mineral, removing the redundant
  Herbalism/Mining profession label.
- Make blank space and borders in the field-notes editor focus the text box.
  Keep Save notes bound to the displayed entry, clear focus on selection changes,
  and verify separate herb/mineral notes, unsaved drafts, clearing and reloads.
- Add regression coverage for circular markers at recorded coordinates and
  independent per-entry note editing/saving. Other pages remain unchanged.

## v0.10.15 - Local development (included in v0.11.0-beta)

- Fix missing-profession location recording when the client omits the global
  right-click event: a matching Herbalism/Mining error plus a live readable
  world-node tooltip now identifies the interaction and records player coordinates.
- Accept empty/root-only world mouse focus and retain a recent hovered identity
  briefly for clicks that clear the tooltip before the input handler runs. Keep
  markers interaction-only, approximate and separate from completed gathers.
- Add regression coverage for both professions, missing input events, focus
  variants, tooltip clearing, stale/replaced identities and error/cast deduplication.
  Preserve the other pages and current model zoom settings.

## v0.10.12 - v0.10.14 - Local development (included in v0.11.0-beta)

- Zoom herb and mineral 3D previews out to approximately 40% of their original
  apparent size, superseding the two earlier 20% adjustments. Apply the camera
  settings after loading each model as well as when creating the preview.
  Preserve frame dimensions and the Bestiary's original camera distance of 1.25.

## v0.10.11 - Local development (included in v0.11.0-beta)

- Record hovered herb/mineral zones under Locations in basic info, even without
  the profession. Make those zones searchable and filterable, and retain their
  map identity without sampling coordinates or increasing interaction counts.
- Replace resource icons with draggable 3D previews matching the Bestiary's
  model frame. Use verified native model file IDs for classic herbs and mineral
  nodes, including rare and ooze-covered variants. Recognized object IDs also
  resolve localized names; unavailable models never retain a previous preview.
- Keep the clicked node identity when a skill-rejected interaction dismisses its
  tooltip, allowing approximate player coordinates without Herbalism or Mining.
  Match the recent world click to the profession error and deduplicate cast/error
  event ordering. Hovering alone still cannot create a coordinate marker.
- Add regression coverage for hovered zone persistence, model selection and
  rotation, localized identities, stale model callbacks and dismissed tooltips.
  Preserve Bestiary and all other pages.

## v0.10.10 - Local development (included in v0.11.0-beta)

- Discover herbs and mineral nodes from readable world-object mouseover tooltips
  without requiring Herbalism or Mining. Keep discovery separate from interaction
  counts, known zones and location markers; show when an entry has not yet been
  interacted with.
- Record skill-rejected gathering interactions without the profession or required
  rank when a recent world right-click and matching client error identify the
  same resource. Do not count these as completed gathers. Exclude UI clicks,
  unrelated or out-of-range failures, fading/replaced tooltips and stale input.
- Add localized requirement parsing and regression coverage for skill-free
  discovery, rejected interactions, restricted tooltip data and deduplication
  with gathering casts. Preserve existing records and other pages.

## v0.10.9 - Local development (included in v0.11.0-beta)

- Implement Herbs & Minerals with the Bestiary's parchment, left index, A–Z
  filters, search and clear control, sorting, sixteen-row list, hover-scrolling
  names, scrollbar and Previous/Next navigation. Add herb/mineral and location
  filters, interaction totals, encounter dates and saved field notes.
- Discover resources only from the player's matched Herbalism or Mining casts.
  Record a position when gathering starts, retain interrupted interactions,
  and count matching successful casts separately. Reject passive observations,
  unrelated spells/loot, pre-cast failures, stale or mismatched events and
  unreadable identities. Duplicate events never add another interaction.
- Give every discovered resource its own Locations map with recorded zones,
  green herb/gold mineral markers, brightness and a live player arrow. Mark
  gathering positions approximate, consolidate repeated coordinates and bound
  map histories. Missing coordinates never create invented positions.
- Save gathering data separately per character, outside Bestiary resets,
  account merging, backups and sharing. Preserve browsing state and unsaved
  notes across section changes; close gathering dialogs when leaving the page.
  Other page implementations are unchanged.
- Add gathering event, persistence, map and UI regression coverage; update
  section navigation tests for the implemented page and five remaining wishlists.

## v0.10.8-beta - 2026-09-27

This release includes the complete batch from v0.9.151 through v0.10.8.
The previous-push and previous-release baseline is
`b48f2a011bb944c6f49ce07b69d794335068f4e1` (`v0.9.150-beta`).
Both players must use the same installed addon version to share records.

- Expand Azeroth Fieldbook with seven native icon tabs on the outside right edge:
  Bestiary, Herbs & Minerals, Traveller's Atlas, Angler's Almanac, Merchant's
  Ledger, Treasure Journal, and Lorekeeper's Chronicle. Bestiary remains the default
  and fully functional section; the other six show their future-release wishlists.
  Use native borders, hover feedback, gold selection and section-name tooltips.
- Preserve Bestiary selection, filters, browsing positions and drafts when changing
  sections, with background tracking continuing. Explicit creature actions select
  the Bestiary. Keep section controls with their content and preserve pinned Notes.
  Include the tab column in screen-fit scaling, clamping and auxiliary-window
  placement, with attached windows reflowing after movement or scale changes.
- Add violet Kills / cyan Observations map layers, selected beside map brightness.
  Observations record the player's position only when targeting a creature, never
  passive mouseovers or the mouseover-open binding. Both bounded histories persist
  through reloads, backups and account merging and remain private to the journal.
- Improve Locations with a live player-position/facing arrow, an empty-state
  message below the map, and a compact footer. Simplify explanatory text and
  darken the approximate-position note while retaining readable margins.
- Fix deliberate creature discoveries while flying or on flight paths, including
  readable explicit selections beyond visibility range. Passive airborne hovering
  remains excluded. Log first personal encounters even if the creature's level is
  unknown or its entry was previously received through sharing.
- Use the client's effective creature level. Unknown levels show a skull and defer
  discovery, location and kill-milestone Knowledge until a readable personal level
  observation; kill counts and existing credited progress remain intact. Sort skull
  entries above numeric maximum levels, show skulls in the list's marker slot, and
  enlarge/raise the information-panel skull. Restore earned markers when resolved.
- Automatically record Flees at low health from supported readable English monster
  emotes, using a creature GUID or an unambiguous watched-creature fallback. Show
  cyan [A] provenance and source tooltips. Manual toggles retain that history;
  fresh evidence restores unchecked marks, including on locked entries. Verified
  automatic abilities can also update locked entries while manual editing stays locked.
- Give newly added/restored automatic abilities and flee behaviour one chat notice
  and Event log record; unchanged repeat evidence stays silent. Add bounded flee
  diagnostics to /fieldbook debug. Preserve behaviour provenance through reloads,
  backups and account merging; shared behaviours remain unverified Rumours.
- Move client-verified Hostile / Neutral into basic information using Blizzard's
  tooltip reaction colours, with no Behaviour controls or [A] marker. Update these
  facts quietly, even while locked, without chat/Event log notices. Migrate verified
  marks; old manual marks require fresh client evidence and are no longer shared traits.
- Colour each Level Range endpoint using Blizzard's creature-difficulty function,
  including its orange band, and refresh when the player's effective level changes.
  Colour Locations with the minimap territory palette learned as zones are visited.
  Keep territory data faction-specific, bounded, persistent and silent; skip subzone
  overrides and leave unknown territory uncoloured.
- Group the four bindings under Azeroth Fieldbook using explicit categories. Toggle
  Azeroth Fieldbook reopens the last selected tab; Open bestiary at mouseover opens
  the pointed creature. Add Next Bestiary entry / Previous Bestiary entry, following
  the filtered, sorted list with wrapping and scrolling. They work only while the
  Bestiary is visible and no text field has focus. Existing assigned keys are retained.
- Restore inset Index/A-Z layering beneath the trim. Extend letter buttons one pixel
  left while preserving their right edges and letter positions. Match Dispel type
  spacing to School immunity and preserve bottom margins; move ability tooltip
  checkboxes up two pixels.
- Update Help, README, architecture/versioning guidance and verification checklists.
  All 39 test files pass and all 33 runtime Lua files compile under Lua 5.1; manifest,
  bindings, version consistency and whitespace checks pass. All seven section icons
  were verified in installed client archives. Native visual/keybinding acceptance
  remains distinct from automated coverage; live Beast Lore awaits the beta level cap.

### Local iteration notes for v0.10.8

- Place Index and A–Z buttons one frame level beneath the main window trim and above the parchment, restoring their inset rolodex appearance. Keep native and fallback borders on the same decorative layer, leave mouse input unobstructed and retain title controls above the trim.
- Extend the index letter buttons one pixel to the left beneath the border, preserving their right edges, height, spacing and letter positions.
- Match the padding above Dispel type to School immunity in the ability-effects picker. Shift the lower sections and extend the window by 15px to preserve spacing and bottom margins.

## v0.10.6 - v0.10.7 - Local development (included in v0.10.8-beta)

- Fix the keybinding heading appearing as a bindable HEADER_AZEROTHFIELDBOOK action under Other. Use Forever's explicit category attribute on all four bindings and remove the legacy header attribute. Preserve action IDs, assigned keys and routing; update regression coverage and verification notes.
- Shorten the navigation binding labels to Next Bestiary entry and Previous Bestiary entry, removing the parenthetical text. Their visibility restrictions and assigned keys are unchanged.

## v0.10.5 - Local development (included in v0.10.8-beta)

- Colour each Level Range endpoint using Blizzard's creature-difficulty function, including grey, green, yellow, orange and red. Refresh when the player's effective level changes, including locked pages; retain the skull for unknown levels and readable plain text when colour data is unavailable.
- Use Blizzard's tooltip reaction palette for Hostile / Neutral instead of full-bright red/yellow. Add difficulty-boundary, range, level-change and unavailable-data checks and update visual verification guidance.
- Colour Locations with Blizzard's minimap territory palette, learned from readable zone observations. Keep a bounded, faction-specific cache through reloads, backups and account merging; skip subzone overrides and leave unobserved territory uncoloured. Learning is silent and does not create creature entries.
- Add optional Next / Previous Bestiary entry keybindings using existing filtered, sorted, wrapping navigation. Operate only while the Bestiary is visible and no text field has keyboard focus. Keep the selected row visible and leave bindings unassigned by default. Update Help and add binding/visibility regression coverage.
- Group bindings under Azeroth Fieldbook. Rename the main binding to Toggle Azeroth Fieldbook and route it through the shared shell to reopen the last tab; rename the mouseover action to Open bestiary at mouseover. Retain existing binding IDs and assigned keys.

## v0.10.4 - Local development (included in v0.10.8-beta)

- Move client-verified Hostile / Neutral from Behaviours into basic information, coloured red / yellow without [A] markers or manual checkboxes. Update quietly on fresh readable reactions, including locked entries, without chat or Event log notices.
- Migrate previously verified disposition marks, retain the value through backups and account merges, and remove obsolete behaviour/share claims. Manual legacy marks await fresh client evidence. Update Help, documentation and regression coverage for colours, silent updates, migration and persistence.

## v0.10.3 - Local development (included in v0.10.8-beta)

- Preserve automatic behaviour history and cyan [A] styling through unchecking, rechecking, reloads, backups and account merges. Fresh evidence restores an unchecked behaviour, with one new chat/Event log notice; unchanged repeats remain silent.
- Allow verified automatic abilities and behaviours to update locked creatures while retaining the lock and manual-edit restrictions.
- Automatically record mutually exclusive Hostile / Neutral behaviours from readable creature reactions, with source tooltips and the same [A] styling and notifications. Skip unknown, restricted and friendly reactions. Add reaction, lock and provenance regressions and update Help and verification guidance.

## v0.10.2 - Local development (included in v0.10.8-beta)

- Fix silent rejection of supported flee emotes with an absent sender GUID: match the readable sender to an eligible, currently watched creature, rejecting ambiguous IDs, invalid/restricted payloads, locked entries and manual removals. Add bounded session diagnostics to `/fieldbook debug` showing emote delivery, matching and rejection reasons.
- Route automatic behaviour and ability additions through one chat/Event log notification path. Include the creature, behaviour, automatic provenance and identity source for flee; suppress duplicate notices for repeated evidence and reloads. Add missing-GUID, ambiguity, logging and diagnostics regressions and update Help/verification documentation.

## v0.10.1 - Local development (included in v0.10.8-beta)

- Fix deliberate airborne observations: the mouseover-open keybinding bypasses the passive flight filter, and explicit selections can record readable creatures beyond the visibility range. Log first personal encounters of already-named shared entries even when the level is still unknown; preserve Knowledge rules and passive flight exclusions.
- Add a Kills / Observations toggle beside Locations' map-brightness slider. Keep violet kill tracking and add cyan observation tracking with bright borders, recording the player's position only on explicit targeting, never mouseovers or the mouseover-open binding. Both layers collect independently, retain their own bounded history and survive reloads, account merging and backups; coordinates remain private to the journal.
- Sort skull entries above numeric maximum levels, show a skull beside their names in the existing marker slot, and enlarge the information-panel skull from 14 to 18 pixels with a 2px upward offset. Restore earned stars/crowns once a readable level is known.
- Recognize the exact English flee monster emote when a readable creature GUID identifies an existing personal entry. Mark automatically recorded Flees at low health in blue with [A] and a source tooltip; respect locks, manual records and durable unchecked choices. Preserve provenance through backups/account merging; shared claims remain unverified Rumours.
- Add event, storage, map-layer, sorting, marker and behaviour-provenance regressions, updated Help/README instructions and separate in-game verification checklists.

## v0.10.0 - Local development (included in v0.10.8-beta)

- Expand the shared Fieldbook window with native framed icon tabs on its outside right edge, in order: Bestiary, Herbs & Minerals, Traveller’s Atlas, Angler’s Almanac, Merchant’s Ledger, Treasure Journal, and Lorekeeper's Chronicle. Add gold selection, native hover feedback and section-name tooltips; default to the Bestiary on first opening.
- Add six parchment wishlist pages with their supplied titles and future-release text. Keep presentation definitions easy to revise; introduce no new tracking, SavedVariables or sharing schema.
- Preserve Bestiary selection, filters, browsing positions and draft fields across tab changes. Explicit creature-entry actions select the Bestiary; its toolbar and transient panels stay with its section, while pinned Notes retain their independent lifetime and tracking continues in the background.
- Include the full tab column in saved-position clamping, screen-fit scaling and auxiliary-window placement. Reflow attached windows when the main window's footprint or UI scale changes; keep tabs accessible when the screen is crowded.
- Add navigation, text, state-retention, scale and window-placement regressions, icon verification evidence and an in-game acceptance checklist.

## v0.9.151 - v0.9.154 - Local development (included in v0.10.8-beta)

- Moved the ability tooltip checkboxes up 2 pixels.
- Locations now shows the empty-kill message below the map and a live player arrow in the currently viewed zone, with position and facing updates. The empty-map message is red. Removed the historical kill-coordinate and map-colour explanations, darkened the approximate-position note, and compacted the footer while preserving bottom padding.
- Flight paths and flying now require explicit targeting for observations; passive mouseovers cannot collect Bestiary discoveries.
- Follow the client's effective level instead of its raw level. Unknown ranges display a skull; discovery, location and kill-milestone Knowledge wait for a personally observed readable level. Existing credited history is preserved.
- Updated in-game Help and regression coverage for flight discovery, hidden levels and deferred Knowledge.

## v0.9.150-beta - 2026-09-27

This release includes the complete unpublished batch from v0.9.138 through
v0.9.150. The previous-push and previous-release baseline is
be1016c4824b7fa77d1d1c571ff14c6aa0ac561c (v0.9.137-beta). Both players must use
the same installed addon version to share creature records or Beast Lore.

- Add default-on automatic recording of verified creature abilities: readable
  buffs outside combat and enemy casts with readable spell IDs, including combat.
  Mark automatic records with a light-blue [A], show their provenance, and announce
  new/restored abilities once in chat and the Event log. Fresh verified evidence
  restores removed or rejected abilities while enabled; entry locks and manual
  notes remain protected. Resolve names from IDs and deduplicate by spell ID.
- Show Last observed ability beneath the manual spell reference field, with a
  yellow spell name, white ID, grey labels/timestamp and a guarded hover tooltip.
  Keep the latest hint per creature for the session, clear readable recorded IDs
  and acknowledge linked manual confirmations. Restricted IDs can be displayed
  but cannot be compared, saved automatically or matched against recorded spells;
  a subsequent restricted cast can show its hint again.
- Collapse empty Spell ID window sections and grow upward from the bottom edge,
  preserving saved anchors, dragging, locks, expiry and fade settings. Show caster
  names when available, omitting unknown caster lines. Right-click dismisses a
  section; Ctrl+Right-click blacklists a readable ID. Add a saved per-character
  blacklist manager in Options with removal, pagination and manual ID entry.
  Restricted IDs require manual entry and cannot be automatically filtered.
- Add Locations beside Notes, with the client's zone artwork, explored terrain
  and a dropdown for multiple zones. New credited kills record readable creature
  positions or an explicitly approximate player-position fallback. Old kill totals
  have no coordinates to recover. History follows account/character tracking,
  merges across characters, survives reloads/backups, and stays out of sharing.
- Display isolated positions as dots and nearby groups as translucent violet
  triangles with a soft pink outer glow. Every triangle edge is limited to 180
  yards so distant groups stay separate. Collinear points or maps without a yard
  scale remain dots. Keep up to 256 recent distinct positions per creature/map
  across 64 maps, and validate the added fields when importing backups.
- Anchor Locations to the book's right/top edge through the existing anchoring
  preference. Use greyscale parchment at 34% of shared UI brightness, independent
  of the saved Map brightness slider (20–100%, default 80%). Match Options slider
  styling and add footer padding. Keep the kill counter left of Rumours, rename
  Creature Notes to Notes, narrow its button, scroll overflowing creature headings
  on hover, grey automatic buff provenance, and raise tooltip checkboxes 3px.
- Make /fieldbook debug open a foreground report with text selected for Ctrl+C,
  without chat duplication. Keep partial reports useful after diagnostic failures.
- Expand automated coverage for recording, restricted values, hints, window input,
  maps/geometry, persistence, backups and positioning. All 32 test files pass and
  all 32 runtime Lua files compile. Allow grouped version headings in the release
  validator. Update verification records and live checklists: map areas have been
  seen live, while final rendering, precise NPC coordinates and remaining client
  behavior need live verification. Beast Lore testing still gates stable 1.0.

## v0.9.148 - v0.9.150 - Local development (included in v0.9.150-beta)

- Narrow Notes to 58px, returning 54px to the creature heading. Overflowing creature
  headings scroll gently on hover, resetting on leave, selection change or close.
- Rename the Creature Notes button and its window title to Notes.
- Desaturate the Locations parchment and zone dropdown, keeping them 66% darker
  than shared UI brightness. Match the Map brightness slider to the Options
  sliders with the same track, dimensions and thumb template, and add 16px of
  bottom padding. Terrain and location overlays retain their separate brightness.

## v0.9.147 - Local development (included in v0.9.150-beta)

- Return Kills and its reward marker to the left of Rumours in the creature header.
- Place Locations at the main book’s right edge with aligned tops by default, and
  apply Always attempt to anchor to main window to restored positions. With the
  option disabled, retain saved positions subject to normal overlap/screen rules.
- Give Locations and its zone dropdown the shared parchment background, following
  UI brightness independently of the map brightness slider. Verify anchoring
  preferences and independent parchment/map brightness in the regression suite.

## v0.9.146 - Local development (included in v0.9.150-beta)

- Rename the main-window hint to Last observed ability and move the recorded
  ability's Display on tooltip checkbox up 3px.
- Replace the low-contrast orange location fill with brighter violet shading and
  a soft pink glow around each area's outer boundary, excluding internal triangle
  seams. Add a saved per-character Map brightness slider (20–100%, default 80%)
  that dims terrain and explored artwork without dimming markers or areas.
- Verify boundary rendering, independent brightness and persistence; update the
  live visual checklist. The supplied screenshot confirms the previous triangles
  render in-game; the new contrast and glow still need live visual acceptance.

## v0.9.145 - Local development (included in v0.9.150-beta)

- Add a creature Locations window beside Creature Notes, with the game's zone
  map artwork, explored areas, and a zone selector for creatures seen in multiple
  locations. Move the kill counter below the model to preserve title space.
- Save positions from newly credited kills, preferring readable creature
  coordinates and explicitly labelling the player-position fallback approximate.
  Existing kill totals are not converted into invented positions. Samples follow
  the selected tracking scope, persist across reloads, and survive backup/restore.
- Draw isolated kills as dots and nearby groups as translucent orange triangles.
  All triangle edges must be at most 180 yards; distant groups and outliers stay
  separate. Keep at most 256 recent distinct positions per creature/map across
  up to 64 maps. Collinear points and maps without a readable yard scale stay dots.
- Cover kill-credit integration, restricted/unavailable APIs, triangulation,
  tracking merges, backups and window controls with automated regressions, and
  add a live Locations checklist. Native map rendering remains to be tested.

## v0.9.144 - Local development (included in v0.9.150-beta)

- Show Automatic buff observation in grey beneath recorded abilities.
- Collapse empty Spell ID window sections and grow upward from a fixed bottom
  edge. Migrate existing window anchors and preserve drag, lock, expiry and fade
  settings. Show caster names from cast targets or reported aura sources; omit
  the caster line and its space when unavailable.
- Right-click a section to dismiss it; Ctrl+Right-click also blacklists a readable
  spell ID. Repeated observations of the same public cast/aura token stay dismissed.
- Add an Options blacklist manager with pagination, removal and manual ID entry.
  The per-character blacklist affects only the Spell ID window. Restricted IDs
  cannot be matched or saved automatically; Ctrl+Right-click dismisses them and
  opens the manager with an explanation. Add layout, caster, input and persistence
  regressions and refresh the live checklist.

## v0.9.143 - Local development (included in v0.9.150-beta)

- Refine the hint heading to Last detected ability, remove the display-only suffix,
  put the grey
  timestamp beside the heading, and place the grey Spell ID label and white ID
  immediately after the yellow spell name using native secret-safe formatting.

## v0.9.142 - Local development (included in v0.9.150-beta)

- Show the latest detected enemy ability beneath the selected creature's spell
  reference field, with separate name/ID labels, local date/time and a guarded
  hover tooltip. Capture works independently of the Spell ID window and the
  automatic-recording checkbox.
- Keep one hint per creature throughout the session, overwrite it on the next
  cast, and suppress readable IDs already present in Recorded abilities. Public
  cast-bar IDs deduplicate polling and alias events without comparing secret IDs.
- Clear a restricted hint when a linked ability is manually saved for that
  creature. Restricted casts cannot be checked against recorded spells, so a
  subsequent cast can show the hint again. Hints are not saved across reloads.
- Add event, polling, storage-isolation, acknowledgement, reset and UI regression
  tests; adjust form spacing and document the live verification steps and limits.

## v0.9.141 - Local development (included in v0.9.150-beta)

- Bring the copyable debug report to the foreground, with text selected for
  Ctrl+C. `/fieldbook debug` opens the report without duplicating it in chat.
- Preserve a copyable partial report if diagnostic collection fails, and allow
  remaining sections to continue after a display-module report failure. Add
  regression coverage for foreground behavior and report delivery failures.
- Record the live Fireball (20793) investigation: cast events reached an eligible
  NPC, but the client marked their IDs and active-cast names secret. Display is
  possible; automatic journal storage remains unavailable for those payloads.

## v0.9.140 - Local development (included in v0.9.150-beta)

- Extend the default-on recording option to enemy casts with readable spell IDs,
  including in combat. Observe cast starts, channels, empowered and instant casts,
  and ongoing target/mouseover casts. Buff capture still requires being out of combat.
- Confirm verified casts with the light-blue [A] marker and cast-specific hover
  text. Share the buff recorder's restoration, deduplication and once-per-change
  chat/Event log announcements while preserving manual notes and entry locks.
- Rename the option to Automatically record verified creature abilities, preserving
  existing disabled preferences. Name-only casts and historical imports remain
  pending; display-only restricted spell IDs are never looked up or saved.
- Add combat-cast regressions for events, polling, restricted data, restoration,
  persistence, backup/sharing and UI provenance. Document the remaining live check.

## v0.9.139 - Local development (included in v0.9.150-beta)

- Fix verified buff capture being blocked by saved name-only removal flags,
  including the reported Frost Armor (12544) on Defias Rogue Wizard. With the
  option enabled, fresh verified buff observations restore removed or rejected
  abilities on unlocked entries. Turning the option off stops restoration.
- Resolve the spell's name from its observed public ID; missing or restricted
  optional aura name/caster fields no longer discard a usable ID. Preserve
  combat, creature ownership, entry locks and known-caster checks.
- Announce each newly recorded or restored buff in chat and the Event log,
  naming the creature, ability and spell ID. Repeated scans and reloads are
  silent. Include automatic-buff recording status in `/fieldbook debug`.
- Add regressions for the reported saved wizard state, ID-based name resolution,
  automatic restoration, announcements and diagnostic output; refresh the live
  verification checklist with the actual failure and its cause.

## v0.9.138 - Local development (included in v0.9.150-beta)

- Add a default-on Options checkbox to automatically record readable creature
  buffs outside combat, independently of the Spell ID window. Save spell IDs,
  confirm pending matches and mark automatically recorded abilities with a
  light-blue [A] and a tooltip explaining their source. Preserve manual notes,
  locked entries, rejected/removed abilities and existing records when disabled.
- Observe only the watched target/mouseover using public aura data, skipping
  combat, player-controlled units and known different casters. Retry after combat
  and on aura/target changes; deduplicate repeated observations by name and ID.
  Add capture, restriction, persistence, sharing, backup and UI regression tests.

## v0.9.137-beta - 2026-09-27

This release includes all changes since v0.9.128-beta, covering local versions
v0.9.129 through v0.9.137. The previous-push and previous-release baseline is
commit e72f37fa9825e15855129178e7bcdcd15bf277fa. Both players must use the same
addon version to share creatures or Beast Lore.

- Extract the shared Fieldbook window, title controls, page frames and section
  navigation into FieldbookShell. Register the Bestiary as its first lazily
  built section, with independent content and size, while preserving its layout,
  bindings, existing saved-position keys and journal data.
- Move Bestiary Help, Options and Event log content into BestiaryPages. Keep
  shared-window focus, brightness and scaling available to later sections;
  route the minimap and general book command through the shared shell.
- Add a reproducible Python/Lua 5.1 test runner with a pinned dependency, syntax,
  TOC, binding and version checks. Run all test scripts on main pushes and pull
  requests; require the tagged commit to pass before packaging or publication
  to GitHub and CurseForge. Add section navigation/lifecycle regression tests
  and update existing UI checks for the separated content frame.
- Refresh verification documentation: pet kill credit and persistence are
  confirmed working in game by the author. Retain historical research results
  with their original scope. Beast Lore still awaits live testing after the
  beta level cap rises; stable 1.0 is reserved until that testing is complete.
- Show question marks for shared-only creatures in the portrait and list reward
  position until a personal encounter, including while their page is open.
  Reserve and fade name space around the list marker.
- Disable observation controls until a personal encounter and explain the
  requirement on hover. Explain locked controls with an unlock tooltip.
- Match Locations to the Ranks filter's 320px width and resize its contents.
- Keep observation windows attached to the main window when Always attempt to
  anchor is enabled, including restored positions already at the correct edge.
- Hide the keybinding hint once either Fieldbook action is bound and update it
  immediately when bindings change.
- Show Damage taken and Beast Lore scrollbars only when content exceeds their
  viewport, refreshing after content changes and template layout updates.

### Earlier local changes included in this release

## v0.9.129 - v0.9.136 - Included in v0.9.137-beta

- Show a large question mark instead of a portrait for creatures known only
  through sharing. Reveal the portrait when personally encountered, including
  while the creature's page is already open.
- Show a question mark in the creature list's reward-icon position until a
  personal encounter, reserving and fading the name space around it.
- Disable observation controls for creatures not personally encountered and
  explain the requirement in a hover tooltip. Enable them upon encounter when
  the entry is unlocked.
- Match the Locations filter window to the Ranks window's 320px width and
  resize its text and scrolling content to fit.
- Keep observation windows attached to the main window when Always attempt to
  anchor is enabled, including restored positions already at the correct edge.
- Hide the book's keybinding hint when either Fieldbook action is bound, updating
  immediately when bindings change.
- Explain locked observation controls with a short tooltip prompting the user
  to unlock the creature before editing.
- Show Damage taken and Beast Lore scrollbars only when their content exceeds
  the viewport, refreshing after content changes and template layout updates.

## v0.9.128-beta - 2026-09-26

This release includes all changes since v0.9.99-beta, covering local iterations
v0.9.100 through v0.9.128. The previous-push and previous-release baseline is
commit e353c02930e19d1ea2ec6c1ee0d112d02561b172. Both players must use this addon
version to share creatures or Beast Lore.

- Remember verified player classes for Shared by and Rumours attribution so
  names retain their class colours after logout or reload; backfill unknown
  classes when the player is later observed through public game data.
- Add a beast-only Known Beast Lore window with yellow headings and creature
  names, and a scrollable lore box. Capture readable native tooltip fields after
  a successful Beast Lore cast, preserving both text columns and additional
  revealed fields. Retry delayed results and reject hidden or mismatched data.
- Keep captured Beast Lore locked and verified, separate from editable creature
  notes and rumours. Personal observations take precedence over received lore;
  preserve lore through reloads, account migration and backup/restore.
- Add free Send Beast Lore offers with full-name/surname recipients, explicit
  acceptance, version checks, receipts and retries, including at zero Knowledge.
  Support larger bounded lore transfers without changing normal report pricing.
- Count kills using tag eligibility instead of the finishing attacker. Eligible
  pet, party, raid and outside-assisted kills count regardless of mob level, XP,
  actual loot drops or loot distribution. Denied tags do not count. Retain
  witnessed-death, exact-creature eligibility and duplicate protection, and
  update diagnostic reports to explain the new rule.
- Add Show kill count in creature tooltips under Options, enabled by default.
  Known creatures show recorded kills even before their entry is locked.
- Add a Sort menu above the list scrollbar with Name, Kills, Max Level, Min Level
  and First Encountered, ascending or descending. Default to Name / Ascending,
  remember the selection, and apply it to filters and Previous/Next navigation.
  Keep unknown levels/dates last and sort ties consistently.
- Show earned silver stars, gold stars and crowns beside creature-list names.
  Use smooth transparent artwork and drop shadows in both the list and kill
  counter, refine crown alignment, and keep the Sort menu above reward graphics.
- Fade long names before reward icons and gently scroll overflowing names on
  hover, with pauses at each end and reset when the pointer leaves.
- Add a red clear-search button, reserve space so text scrolls clear of it, and
  refine the search box alignment. Clicking an active type or A-Z filter again
  clears that filter.
- Place Known Beast Lore above Damage taken, shortening the beast damage panel
  from its top while preserving the other controls and non-beast layout. Align
  the styled damage scrollbar arrows with the panel's top and bottom edges.
- Rename the notes heading to Creature Notes. Colour Spinkler's help credit mage
  blue and thank Erna, Labrick, and Rhysdogg in their respective class colours.
- Expand regression coverage for capture, free sharing, surnames, persistence,
  backups, sorting, tooltips, UI behavior, denied tags and no-event pet kills
  across the crown milestone. Add reproducible reward-art generation and live
  Beast Lore/kill-attribution verification notes.
- Document grouping small changelog patches under version-range headings in
  AGENTS.md. Beast Lore live capture and two-player delivery still require
  in-game verification; automated checks do not establish client rendering.

### Local development history included in this release

## Local development history included in this release

## v0.9.120 - v0.9.128 - Included in v0.9.128-beta

- Raise the crown graphic by 3px, then lower it 1px in the kill counter and
  creature list, then lower only the list crown another 1px. The counter crown
  sits 2px above its original position and the list crown sits 1px above it.
- Add subtle drop shadows to stars and crowns in the kill counter and creature list.
- Add a red clear-search button inside the search bar. Reserve text space so
  long searches scroll without overlapping the button; clearing refreshes the list.
- Move the search box right in three 2px adjustments, for a total of 6px.
- Add an AGENTS.md rule to group small patches under version-range changelog
  headings, and group these recent small updates accordingly.

## v0.9.111 - v0.9.119 - Included in v0.9.128-beta

- Count kills by tag eligibility instead of requiring a player/party finishing
  blow event. Eligible pet, party, raid and outside-assisted kills count regardless
  of level, XP, loot drops or loot distribution; denied tags remain excluded.
- Preserve witnessed-death, same-creature eligibility and duplicate protection.
  Update diagnostics and test missing pet events, target clearing, no-loot kills,
  denied tags, the 49-to-51 crown boundary and reload persistence.

- Add Show kill count in creature tooltips under Options, enabled by default.
  Known creatures show their recorded kill count even before entry locking;
  disabling the option leaves confirmed ability tooltips unchanged.

- Gently scroll overflowing creature names on hover after a short pause. Pause
  at the ending before returning, clip text before reward icons, and reset on
  mouse leave or row changes. Short names remain still.

- Replace star and crown scanlines with supersampled transparent textures for
  smoother edges at different UI scales, preserving reward colours and layout.

- Keep the Sort popup and its controls in an independent foreground layer so
  list stars, crowns, and scrollbar arrows cannot draw over the open menu.

- Add First Encountered sorting: ascending shows oldest encounters first,
  descending shows newest first, and unknown dates remain last.

- Fade creature names over the final 20 pixels before earned list rewards,
  keeping text clear of stars and crowns. Clear the fade on rows without rewards.

- Show earned silver stars, gold stars, and crowns at the right edge of creature
  list rows, using the same artwork and kill milestones as the kill counter.
  Reserve name space for earned icons and update them as kills or rows change.

- Move the Sort button right to align its centre above the creature-list
  scrollbar's up arrow.

## v0.9.110 - Included in v0.9.128-beta

- Add a square down-arrow Sort menu beside Search with Name, Kills, Max Level,
  and Min Level, each supporting ascending or descending order. Default to
  alphabetical Name / Ascending and remember the character's chosen order.
- Apply sorting consistently to filtered lists and Previous/Next navigation.
  Keep unknown levels last in either direction and resolve ties consistently.
- Test ordering, filters, effective shared levels, persistence and menu controls;
  guard the Damage taken scrollbar styling when no usable scrollbar is returned.

## v0.9.104 - v0.9.109 - Included in v0.9.128-beta

- Move Known Beast Lore above the Damage taken panel. For beasts, shorten the
  panel from the top, keeping its bottom and Record damage taken in their
  original positions. Non-beast layouts remain unchanged.

- Add the Oxford comma to the beta-testing special thanks.

- Shorten the special-thanks names to Erna and Labrick, preserving class colours.

- Add Rhysdogg to the beta-testing special thanks in druid orange.

- Clicking an active creature-type or A–Z filter again clears that filter.
- Colour Spinkler's help credit mage blue and add special thanks directly below
  it to beta testers Erna Lionguard (paladin pink) and Labrick Curby (hunter green).

- Style the Damage taken scrollbar and inset it along the panel's right edge.
  Align its upper and lower arrow edges with the panel's top and bottom,
  automatically following the shorter beast layout without moving content.

## v0.9.103 - Included in v0.9.128-beta

- Make the creature name yellow in Known Beast Lore and display captured lore in
  a scrollable box styled like Damage taken, with observed creature level and
  locked/verified source attribution.
- Capture public native tooltip fields after a successful Beast Lore cast on
  the identified target or mouseover. Retry delayed data for five seconds,
  preserve left/right text and additional revealed fields, and reject hidden
  data or mismatched creature instances. Repeated observations can update lore
  independently of the main entry lock; no manual lore editing is offered.
- Add Send Beast Lore and a full-name recipient field. Use the existing version
  handshake, acceptance, delivery receipt and retry flow with zero Knowledge
  cost, including at zero balance. Imported lore is locked/verified rather than
  a rumour, names its sender, and cannot overwrite a personal observation.
- Add an explicit Beast Lore report schema and bounded larger transfers while
  retaining the existing paid-report schema and pricing. Persist lore through
  reloads, account migration and backup/restore.
- Test cast routing, delayed capture, instance identity, restricted data, free
  transfers, surnames, consent, retries, large reports, persistence and UI wiring.
  Live Forever spell/tooltip behavior and two-player delivery need in-game QA.

## v0.9.102 - Included in v0.9.128-beta

- Make the Known Beast Lore window heading yellow to match the other headings.

## v0.9.101 - Included in v0.9.128-beta

- Rename the notes window heading to Creature Notes to match its button.
- Add a beast-only Known Beast Lore button and a matching empty window. Shorten
  the damage panel by one button row and raise Record damage taken to make room,
  preserving other page positions and the original layout for non-beasts.
- Support closing, dragging, saved positioning, UI scale and brightness for the
  new window, including access on locked beast entries. Add layout and switching
  regression checks. Beast Lore capture, locked/verified sharing and gamification
  remain planned for future development.

## v0.9.100 - Included in v0.9.128-beta

- Save verified sender classes locally when importing shared reports so Shared
  by and Rumours names retain their class colours after logout or reload.
  Remember displayed sources too, and fill in unknown classes when later
  observed through public game data. Add persistence and backfill regression coverage.

## v0.9.99-beta - 2026-09-26

This release covers every change since v0.9.82-beta, including local iterations
v0.9.83 through v0.9.99. The previous-push and previous-release baseline is
commit e7dd44f05ddf0373669a5cbe950bf43af0cc3008. Both players must use the same
addon version to share creatures.

- Fix Forever sharing with separate first-name and surname API values. Preserve
  exact recipient identity, self-offer prevention and explicit consent.
- Replace ambiguous sharing failures with specific rejection reasons, including
  blocked offers, full queues, malformed reports, name mismatches, timestamps
  and storage limits. Log detailed local reasons without displaying arbitrary
  error text supplied by another player.
- Record incoming and outgoing sharing activity in Event log even when chat
  announcements are disabled: offers, acceptance, delivery, cancellations,
  expiry, failures and retries, with the creature, other player, rumour count
  and Knowledge outcome. Retries do not duplicate imports or spending. Earlier
  transfer history cannot be reconstructed.
- Display source names for shared information. Place grey Shared by text inside
  the creature viewer's bottom-left corner; hide it after a personal encounter.
  Compact long source lists and show full attribution on hover. Keep source
  history available in Rumours, including on locked pages.
- Colour source names by player class only when verified through public game
  data from targets, mouseovers or group members. Match full surnames and cache
  classes for the session; unknown names remain grey. Reports cannot establish
  a class identity, and stored names and sharing/backup formats are unchanged.
- Allow deleted creatures to be recorded again on hover while retaining the
  durable Knowledge ledger and credited kill milestones. Announce Entry restored
  without granting repeat discovery rewards, including after reload.
- Add Lock newly encountered critters under Tracking, enabled by default. Record
  initial basic information before locking; respect manual unlocks and existing
  pages. Shared-only pages stay reviewable until personally encountered.
- Stop awarding Knowledge for new levels on existing creatures. Continue recording
  levels and awarding Knowledge for new locations; preserve historical balances.
  Update Help, README and scoring/announcement checks.
- Extend the creature list to sixteen rows above Previous/Next. Add a synchronized
  scrollbar in a reserved gutter without shifting other controls, with a 70%
  transparent track. Lower creature names and review markers within their rows.
- Show creature names in green while rumours remain outstanding, including the
  selected creature; explain this in the grey legend with one green example word.
- Fit Rumours to its text with a capped width and height. Show up to four rumours
  before scrolling when screen space permits; use the Options/Event log scrollbar
  styling only when needed. Add subtle dividers and padding between records.
- Put a framed green verify tick, then the themed reject cross, to the left of
  each rumour. Share confirmation artwork with Recorded Abilities and retain
  framed grey disabled controls with green ticks.
- Use bright yellow native bevels and text for selected filters while preserving
  the original red button faces. Unselected direct filters use grey text;
  Locations and Ranks retain yellow labels. Reduce filter fonts by 1pt, keep
  Pending as a fixed-label toggle, and lower the Search placeholder.
- Highlight Rumours, Creature Notes, Record damage taken, Offenses, Defenses,
  Behaviour, Choose effects, Locations, Ranks and Share while their windows are
  open, without changing their actions or text styling. Locations and Ranks also
  stay highlighted while filters are active. Fix Creature Notes highlighting on
  first opening independently of pinning; clear closed-window indicators reliably.
- Prefer bottom-left to bottom-right docking beside the main window for Offenses,
  Defenses and Behaviour. Preserve pinning, overlap avoidance and screen bounds.
  Refine Creature level dropdown alignment and keep the missing-model caption
  inside the viewer.
- Update usage/API research documentation and extend regression coverage for
  sharing rejection/delivery/retry logs, surname identity, verified class colours,
  restored creatures without repeat rewards, critter locking, Knowledge rules,
  adaptive lists, window indicators, pinning and bounded window placement.

## v0.9.98 - Included in v0.13.30-beta

- Show the selected-filter yellow border on Rumours, Creature Notes, Record
  damage taken, Offenses, Defenses, Behaviour, Choose effects, Locations, Ranks
  and Share while their windows are open. Keep their existing actions and text
  styling; clear the border whenever the corresponding window closes.
- Move the Creature level dropdown another 1px down and 2px left.

## v0.9.97 - Included in v0.13.30-beta

- Restore the Pending toggle’s native red face, with grey text when off and
  yellow border and text when on.
- Lower the Search placeholder by 1px and the Creature level dropdown by
  another 3px. Move Shared by 1px down and 1px left inside the viewer.

## v0.9.96 - Included in v0.13.30-beta

- Lower the viewer’s Shared by attribution by 2px.
- Keep the Pending filter label fixed on an enabled grey button; use the common
  yellow border and text to show when the filter is active.
- Move the damage observation Creature level dropdown 3px left and 3px down.

## v0.9.95 - Included in v0.13.30-beta

- Limit yellow selection styling to the native button bevel and text, keeping
  the original red face unchanged.
- Place Shared by inside the creature viewer at the bottom left; hide it after
  a personal encounter while retaining source history in Rumours.
- Prefer bottom-aligned docking on the main window’s right edge for Offenses,
  Defenses and Behaviour, preserving overlap avoidance, pinned positions and
  screen containment.

## v0.9.94 - Included in v0.13.30-beta

- Brighten selected filters with pure-yellow additive colour on the native
  button artwork; restore normal blending when deselected. No separate outline.
- Align Shared by with the creature viewer's left edge and use the available
  width beneath the panels. Put the missing-illustration caption inside the
  viewer so the two labels cannot overlap.
- Keep Locations and reduce filter-button fonts by 1pt in every state, including
  category, alphabet, Index, Locations, Ranks and Pending controls.

## v0.9.93 - Included in v0.13.30-beta

- Restore yellow text on Locations and Ranks, which open filter windows rather
  than selecting a filter directly.
- Remove separate selection-border textures. Tint the native button artwork
  yellow when selected, preserving its bevel and pressed state; unselected
  direct filters retain grey text on red.
- Stop awarding Knowledge for new levels on existing creatures. Continue
  recording levels, awarding +1 for new locations, and preserving all previously
  earned balances and deletion/reload credit. Update Help and README rules.
- Update scoring, sharing and announcement regressions for location-only rewards;
  check historical balance preservation and native selection artwork.

## v0.9.92 - Included in v0.13.30-beta

- Use verified player class colours for names in Shared by and Rumours source
  labels/tooltips. Keep the surrounding Shared by text and unknown names grey.
- Learn classes only from public game data for players you target, mouse over,
  or group with. Match complete names including surnames; reject restricted
  identity/class values. Retain verified classes for the session and refresh
  open windows when a class becomes known.
- Keep stored names and the sharing/backup formats unchanged; received reports
  never establish a sender's class.
- Add class-colour checks for surname mismatches, non-player units, unavailable
  or restricted APIs, session caching, colour validation and live UI refresh.

## v0.9.91 - Included in v0.13.30-beta

- Make the main creature page's Shared by attribution grey, matching the
  understated list legend.

## v0.9.90 - Included in v0.13.30-beta

- Replace the glowing filter selection outlines with one crisp yellow border
  and yellow text. Unselected filters keep their red button and use grey text;
  unavailable filters retain their disabled appearance. Apply this consistently
  to creature types, alphabet tabs and the Index/Locations/Ranks controls.
- Remove the filter hover glow so it cannot obscure the selected border or turn
  unselected text yellow. Native pressed-button feedback remains available.

## v0.9.89 - Included in v0.13.30-beta

- Put the green verify tick first on the left of each rumour, followed by the
  reject cross and then the text, with consistent gaps and divider padding.
- Fit the Rumours window width to its creature name and report text, retaining a
  comfortable minimum, a capped width for long lines, and room for its scrollbar.
  Recalculate wrapping and height as content changes; keep four rumours visible
  before scrolling when screen space permits.
- Check control order, text bounds, wrapping and shrinking after long content in
  the Rumours UI regression checks.

## v0.9.88 - Included in v0.13.30-beta

- Lower creature-list names by another 1px, keeping their review asterisks aligned.

## v0.9.87 - Included in v0.13.30-beta

- Colour creature-list names green while they have outstanding rumours, including
  selected entries. Return to the normal colour once all rumours are resolved or
  rejected. Extend the grey legend with a single green example word.
- Make the creature-list scrollbar track 70% transparent, with a hollow border
  so its background cannot obscure the parchment through another filled layer.
- Narrow Rumours from 480 to 420 UI units, bringing its action buttons closer to
  the text while preserving wrapping and the four-rumour scrolling threshold.
- Lower creature-list names and their review asterisks by 1px within their rows.
- Cover selected/unselected rumour colours and clearing the final outstanding
  rumour through verification or rejection in the UI regression checks.

## v0.9.86 - Included in v0.13.30-beta

- Name the sender in the main Shared indicator and each shared basic report in
  Rumours. Deduplicate source names; long sender lists use a compact label with
  every source and the encounter/lock status available on hover.
- Clear transient sighting history when deleting an entry so a subsequent hover
  records a fresh sighting. Keep the durable Knowledge ledger and report
  rediscovery as Entry restored. Previously awarded discovery and kill milestones
  remain credited, including after reload; genuinely new facts can still earn
  Knowledge normally.
- Add Lock newly encountered critters under Options → Tracking, enabled by
  default. Capture the first basic observation before locking. Respect existing
  entries, manual unlocks and an explicit disabled setting; shared-only pages
  remain reviewable until personally encountered.
- Add regressions for source attribution, delete/hover/reload without repeat
  rewards, critter defaults and overrides, and the options control.

## v0.9.85 - Included in v0.13.30-beta

- Extend the creature list to sixteen rows, ending just above Previous/Next. Add
  a scroll thumb and themed track in a permanently reserved gutter; filtering,
  mouse-wheel movement and selection navigation keep the scrollbar synchronized.
- Record outgoing and incoming transfer activity in Event log, independent of
  chat announcements: offers, acceptance, delivery, cancellations, expiry,
  failures and retries. Include the creature, other character, rumour count and
  Knowledge outcome. Duplicate packets and paid retries never log a second import.
  Existing completed transfers cannot be reconstructed retroactively.
- Match Rumours verification/rejection to the Recorded Abilities framed green tick
  and themed cross, with the tick on the far right and a grey frame while locked.
  Add subtle horizontal dividers and padding between records.
- Fit Rumours to its wrapped text and status messages through four rumours, then
  scroll longer lists. Keep shared basic information available. Extremely tall
  text is bounded by the screen. Use the shared Options/Event log scrollbar style
  and hide scrolling controls when all content fits.
- Share confirm-button artwork and scrollbar track helpers. Add regressions for
  list reach/gutter stability, compact and overflowing Rumours, and transfer
  history including retry/duplicate handling.


## v0.9.84 - Included in v0.13.30-beta

- Fix the sharing surname mismatch exposed by a report addressed to Peww Pewz
  being compared with Peww. Read both name parts from UnitNameUnmodified and use
  Forever's NameUtil.GetFullNameWithoutRealm helper, falling back to UnitName only
  when the unmodified API is unavailable. The prior adapter incorrectly assumed
  the first return already contained the surname.
- Preserve exact full-name recipient binding and self-offer prevention. Restricted
  name parts remain unavailable; never infer a surname from an incoming report.
- Correct the API research notes and add native-adapter regression coverage for
  separate surnames, name changes, unavailable/restricted data, and reports sent
  in both directions between Erna Lionguard and Peww Pewz. Live confirmation is
  still required; no sharing costs, report format or consent rules change.


## v0.9.83 - Included in v0.13.30-beta

- Replace the combined sharing rejection message with specific reasons for blocked
  offers, full queues, malformed/inconsistent reports, recipient or transaction
  mismatches, timestamp failures and journal storage limits. Distinguish these
  automatic rejections from a recipient declining an offer.
- Record incoming rejection details in the recipient's Event log, including the
  names involved in a recipient mismatch and local decoding/preview errors.
  Only recognized reason codes cross the network; arbitrary remote error text
  is never displayed. Legacy empty decline replies remain supported.
- Reproduce the reported Goldtooth report with three behaviour rumours in the
  simulated two-client tests and verify delivery, consent and the four-Knowledge
  charge. Add coverage for rejection causes, reservation release and legacy/
  unrecognized replies. The live failure's exact cause remains unconfirmed until
  a retry returns the new diagnostic; no validation or consent checks are relaxed.


## v0.9.82-beta - 2026-09-26

This release includes all changes since v0.9.79-beta (local iterations v0.9.80
through v0.9.82). The previous-push and previous-release baseline is commit
1d2b9903fbe50d6009dc32466ebbb76716aaf695. Both players must use the same addon
version to share creatures.

- Keep the Last observed spell IDs window on LOW strata, including when focused,
  so bags and other game windows can appear above it. Other addon windows retain
  their existing focus behavior.
- Shift+left-click the unlocked Spell ID window to hide it. Re-enable it with
  Display Spell ID window in Options. Its hint now reads “Drag to move /
  Shift+Click to hide” in grey.
- Store UI scale account-wide, independently of Bestiary tracking scope. Migrate
  the first character’s existing scale and keep the shared value on subsequent
  characters and Bestiary resets. Window positions remain character-specific.
- Update usage documentation and version references. Extend regression coverage
  for Shift+click, persistent hiding, scale migration, cross-character settings
  and reset preservation. All 23 test files pass; live rendering requires WoW.

## v0.9.81 - Included in v0.13.30-beta

- Shift+left-click the unlocked Spell ID window to hide it; re-enable it with Display Spell ID window in Options. Update its hint to grey “Drag to move / Shift+Click to hide”.

## v0.9.80 - Included in v0.13.30-beta

- Keep the Last observed spell IDs window on LOW strata, including when focused, so bags and other game windows can appear above it. Other addon windows retain their existing focus behavior.

## v0.9.79-beta - 2026-09-25

This release includes all changes since v0.9.74-beta (local iterations v0.9.75
through v0.9.79). The previous-push and previous-release baseline is commit
821e9fcc7a14cb3293ffaa6c1479eed317d7cd82. Both players must use the same addon
version to share creatures.

### Knowledge

- Rename player-facing points to Knowledge throughout the Bestiary, sharing, chat announcements, Options, Help and backup notices. The main total now reads “N knowledge earned”.
- Preserve existing balances, discovery and kill awards, sharing costs, and saved-data compatibility; this is a terminology change only.


### Automatic locking

- Add an enabled-by-default auto-lock checkbox in Options with an editable
  threshold of 10 kills without changes to recorded creature information,
  abilities, traits, damage or notes.
- Reset the streak on content changes, manual unlock or toggling auto-lock.
  Repeated sightings and unchanged edits retain progress; kills and knowledge alone
  do not reset it. Streaks persist across sessions, existing entries start without
  retroactive credit, and automatic locks appear in Event log. Pending abilities
  remain pending.

### Bestiary backups

- Add Backup Bestiary and Restore Bestiary beside Reset Bestiary, separated by
  a small gap. Keep five dated manual backups for the active account or character
  Bestiary, surviving resets, plus a separate recovery copy saved before restore.
- Preview backup dates, sources and creature/ability/note counts before confirming
  replacement. Restore immediately outside combat and refresh the creature views.
  Preserve settings, Event log, earned milestones, spending and active offers;
  never replay old transactions or refund knowledge already spent.
- Support copy/paste export and import, including personal notes, with instructions
  for keeping a separate copy outside the game. Validate a bounded literal format
  before restoring; incomplete or unsupported input changes nothing and is never
  executed as Lua. In-game backups share the addon's saved files and are written
  to disk on normal logout or reload.
- Use the existing parchment, title bar, scrollbar, scale, focus and saved-position
  styling in a backup window sized to its content. Reset confirmation explains
  that saved backups and Event log are retained.

### Ability effects

- Add Heal immediately above Heal over Time. Move following sections down and
  extend the Effects window to retain their existing spacing.

### First encounter dates

- Record the date and time of each creature's first personal encounter and show
  it below the creature name in Creature Notes, using local time and grey styling.
  Expand the window slightly to preserve spacing around the spell-ID controls.
- Recover older dates from scored discovery events where available. Leave
  undated personal entries as Unknown, and shared-only entries as Not personally
  encountered until an actual observation. Repeated sightings never replace the date.
- Keep the earliest known date through account migration, deletion/re-encounter,
  reloads and backup export/import/restore. Add regression coverage for these
  paths, missing or restricted timestamps, and the Creature Notes display.

### Documentation and validation

- Update usage documentation for auto-locking, backups and encounter dates, and
  keep the TOC and README version references synchronized.
- Add tests for persistent auto-lock streaks, backup isolation and retention,
  export/import validation, recovery, knowledge continuity and live sharing state,
  encounter timestamps and account migration. Extend mocked UI coverage for
  restore preview/confirmation and Creature Notes. All 23 test files pass;
  live in-game rendering remains a separate verification step.


## v0.9.78 - Included in v0.13.30-beta

This release includes all changes since v0.9.74-beta (local iterations v0.9.75
through v0.9.78). The previous-push and previous-release baseline is commit
821e9fcc7a14cb3293ffaa6c1479eed317d7cd82. Both players must use the same addon
version to share creatures.

### Automatic locking

- Add an enabled-by-default auto-lock checkbox in Options with an editable
  threshold of 10 kills without changes to recorded creature information,
  abilities, traits, damage or notes.
- Reset the streak on content changes, manual unlock or toggling auto-lock.
  Repeated sightings and unchanged edits retain progress; kills and points alone
  do not reset it. Streaks persist across sessions, existing entries start without
  retroactive credit, and automatic locks appear in Event log. Pending abilities
  remain pending.

### Bestiary backups

- Add Backup Bestiary and Restore Bestiary beside Reset Bestiary, separated by
  a small gap. Keep five dated manual backups for the active account or character
  Bestiary, surviving resets, plus a separate recovery copy saved before restore.
- Preview backup dates, sources and creature/ability/note counts before confirming
  replacement. Restore immediately outside combat and refresh the creature views.
  Preserve settings, Event log, earned milestones, spending and active offers;
  never replay old transactions or refund points already spent.
- Support copy/paste export and import, including personal notes, with instructions
  for keeping a separate copy outside the game. Validate a bounded literal format
  before restoring; incomplete or unsupported input changes nothing and is never
  executed as Lua. In-game backups share the addon's saved files and are written
  to disk on normal logout or reload.
- Use the existing parchment, title bar, scrollbar, scale, focus and saved-position
  styling in a backup window sized to its content. Reset confirmation explains
  that saved backups and Event log are retained.

### Ability effects

- Add Heal immediately above Heal over Time. Move following sections down and
  extend the Effects window to retain their existing spacing.

### First encounter dates

- Record the date and time of each creature's first personal encounter and show
  it below the creature name in Creature Notes, using local time and grey styling.
  Expand the window slightly to preserve spacing around the spell-ID controls.
- Recover older dates from scored discovery events where available. Leave
  undated personal entries as Unknown, and shared-only entries as Not personally
  encountered until an actual observation. Repeated sightings never replace the date.
- Keep the earliest known date through account migration, deletion/re-encounter,
  reloads and backup export/import/restore. Add regression coverage for these
  paths, missing or restricted timestamps, and the Creature Notes display.

### Documentation and validation

- Update usage documentation for auto-locking, backups and encounter dates, and
  keep the TOC and README version references synchronized.
- Add tests for persistent auto-lock streaks, backup isolation and retention,
  export/import validation, recovery, point continuity and live sharing state,
  encounter timestamps and account migration. Extend mocked UI coverage for
  restore preview/confirmation and Creature Notes. All 23 test files pass;
  live in-game rendering remains a separate verification step.

## v0.9.77 - Included in v0.13.30-beta

- Add Heal immediately above Heal over Time in the ability effects list. Move the
  following sections down and extend the window to retain their existing spacing.

## v0.9.76 - Included in v0.13.30-beta

- Add Backup Bestiary and Restore Bestiary beside Reset Bestiary in the Options
  footer, with a small gap separating reset from the backup controls.
- Save five dated manual backups per active account or character Bestiary.
  Keep backups through resets and show creature, ability and note counts before
  restoring. Require confirmation and automatically save a separate recovery
  copy of the records being replaced.
- Add copy/paste export and import with clear instructions, a read-only preview
  before restoration, and validation for incomplete or unsupported data. Imported
  text is a bounded literal format and is never executed as Lua.
- Restore records immediately outside combat, preserving settings, Event log,
  earned milestones, spending and live sharing state. Refresh open creature
  views; never restore old transactions or refund points already spent.
- Match the backup window to the existing title bars, parchment, scrolling,
  scaling, focus and saved-position rules, sizing it to its content. Add regression
  coverage for persistence, recovery, scope isolation, imports and confirmation.

## v0.9.75 - Included in v0.13.30-beta

- Add an enabled-by-default auto-lock option under Tracking with an editable
  threshold of 10 kills. Lock after that many credited kills without changes to
  recorded creature information, abilities, traits, damage or notes.
- Reset progress on content changes, manual unlock or toggling auto-lock. Repeated
  sightings and unchanged setters do not reset it; kills/points alone are excluded.
  Persist streaks across sessions, start existing entries without retroactive kill
  credit, and record automatic locks in Event log. Pending abilities stay pending.

## v0.9.74-beta - 2026-09-25

This release includes all changes since v0.9.56-beta (local iterations v0.9.57
through v0.9.74). Both players must use the same addon version to share creatures.

### Restricted-value safety

- Fix the WindowPositions secret-number comparison triggered when cast-ID panels
  open. Check secrecy before numeric comparisons or arithmetic in geometry validation.
- Guard local scale, visibility and opacity reads too. Skip unreadable geometry
  instead of repositioning it, and never persist secret coordinates. Add regression
  coverage for the OnShow path, secret neighbours and resumed public positioning.

### Recorded abilities

- Replace Reject/Remove with a square button matching and aligned with the green
  confirmation tick. Reject uses the native yellow close-button cross; Remove uses
  a thick centered yellow dash. Preserve Edit/Resolve alignment and locked-entry hiding.
- Fix corrupted cropped Reject artwork by using the unmodified native button.
  Refresh the hovered Reject/Remove tooltip immediately when its action changes,
  using native ownership checks; hide it when removing the ability.
- Increase padding below row dividers while keeping four abilities and their notes
  visible. Add a dark themed scrollbar track and border, sized for the revised rows
  and hidden whenever the scrollbar is inactive.

### Options and window presentation

- Organize Options into Tracking, Chat notifications, Appearance, Window behavior,
  Sharing, Tooltips and cast IDs, and Spell ID window. Use consistent yellow category
  headings reduced by 2 points, preserve setting behavior and the fixed reset footer,
  and clarify that chat preferences do not disable Event log collection.
- Give Help, Options and Event log dark native-trim title bars matching the main
  Fieldbook, with centered yellow text. Refine bar/text alignment, keep borders
  above the bars and close buttons above both, and preserve scrollbar placement.
- Raise the top content fade by 1 pixel and align its parchment sampling. Adjust
  Event log sizing for the smaller title area while preserving its adaptive height.

### Game-observed tameability

- Add a portrait badge with a "Tameable" tooltip, populated only from explicit
  Tameable/Cannot be Tamed text returned by C_TooltipInfo.GetUnit on target/mouseover.
  Detection currently supports English clients and requires the game to reveal the
  information, such as through Beast Lore. Missing or restricted data remains unknown;
  creature families are never used to guess tameability.
- Preserve observed status across reloads/account merges and permit game status
  updates on locked entries. The experimental manual Behaviour checkbox from local
  v0.9.72 is removed; old manual flags cannot establish the badge or be newly shared.

### Validation and documentation

- Update version references and document tameability's detection limits.
- Extend tests for tooltip-derived tameability, persistence, error handling,
  title-bar layout/layering and secret geometry. All 20 test files pass. Live client
  rendering and Beast Lore detection still require in-game verification.

## v0.9.73 - Included in v0.13.30-beta

- Replace the manual Tameable behaviour with game-observed status and a portrait
  badge whose tooltip reads "Tameable". Read explicit Tameable/Cannot be Tamed
  lines through C_TooltipInfo.GetUnit for target/mouseover; do not infer from family,
  missing data, API errors or restricted values. Detection currently supports
  English clients and requires the game to reveal the information (e.g. Beast Lore).
- Preserve status across reloads/account merges and allow game observations on
  locked entries. Old manual flags remain stored but cannot establish the badge
  or be newly shared as behaviour rumours. Remove the manual checkbox.

## v0.9.72 - Included in v0.13.30-beta

- Add Tameable to Behaviour's observed Traits and the creature summary. Record it
  manually after personal verification; unchecked means unknown/unrecorded, not
  untameable. Preserve it across reloads and respect creature locking.
- Allow Tameable to be shared and verified through the existing behaviour-rumour
  flow and pricing. No automatic detection or bundled tameability database is added.

## v0.9.71 - Included in v0.13.30-beta

- Lower Help, Options and Event log title text by one additional UI pixel.

## v0.9.70 - Included in v0.13.30-beta

- Lower the Help, Options and Event log title text by 2 UI pixels within the
  existing title bars, leaving the bars, borders and buttons in place.

## v0.9.69 - Included in v0.13.30-beta

- Raise Help, Options and Event log title bars by another 1 UI pixel, retaining
  their height and the border-over-title layering.

## v0.9.68 - Included in v0.13.30-beta

- Raise the top content fade in Help, Options and Event log by 1 UI pixel and
  adjust its parchment sampling to match the new position.

## v0.9.67 - Included in v0.13.30-beta

- Raise Help, Options and Event log title bars by 1 UI pixel. Layer window borders
  over the title bars for clean edge overlaps, keeping close buttons above both.

## v0.9.66 - Included in v0.13.30-beta

- Give Help, Options and Event log dark native-trim title bars with centered yellow
  titles matching the main book. Keep title bars above fades and below close buttons,
  with scrollbar arrows directly beneath the close buttons and content below the trim.
- Update Event log content sizing for the smaller title area while preserving its
  compact minimum, maximum height and scrolling behavior.

## v0.9.65 - Included in v0.13.30-beta

- Reduce Options category headings by 2 points, retaining their yellow styling.

## v0.9.64 - Included in v0.13.30-beta

- Organize Options into Tracking, Chat notifications, Appearance, Window behavior,
  Sharing, Tooltips and cast IDs, and Spell ID window sections. Use consistent
  yellow headings and section spacing, keeping existing controls and behavior.
- Clarify that chat settings do not disable Event log collection and retain the
  fixed Reset Bestiary footer outside the scrolling settings.

## v0.9.63 - Included in v0.13.30-beta

- Refresh the hovered Reject/Remove tooltip as its action changes, using native
  tooltip ownership during the normal UI refresh. Hide it when removing the ability.

## v0.9.62 - Included in v0.13.30-beta

- Fix corrupted Reject artwork by using the unmodified native yellow close-button
  cross instead of cropping and tinting its texture. Keep the centered yellow dash
  for Remove and preserve button alignment.

## v0.9.61 - Included in v0.13.30-beta

- Add padding below ability-row dividers and increase row spacing while retaining
  four visible abilities and their notes. Keep the first ability in place.
- Give the ability scrollbar a dark themed track and border, extending it to
  match the revised row layout. The track hides with the inactive scrollbar.

## v0.9.60 - Included in v0.13.30-beta

- Replace the Remove text hyphen with a centered, thick yellow dash. Use the
  native close-button cross artwork tinted red for Reject, retaining the frame colors.

## v0.9.59 - Included in v0.13.30-beta

- Raise the confirmation tick by 1 UI pixel, keeping the Reject/Remove square
  aligned with it and preserving Edit/Resolve positions.

## v0.9.58 - Included in v0.13.30-beta

- Replace Reject/Remove with a themed square button aligned with the confirmation
  tick. Show a red X for Reject or a yellow minus for Remove, with matching action
  tooltips. Preserve the existing reject/remove behavior and locked-entry hiding.

## v0.9.57 - Included in v0.13.30-beta

- Lower the Recorded Abilities confirmation tick button by 2 UI pixels while
  preserving the positions of Edit, Reject and Resolve.

## v0.9.56-beta - 2026-09-25

This release includes all changes since v0.9.42-beta (local iterations v0.9.43
through v0.9.56). Both players must use the same addon version to share creatures.

### Window placement and sizing

- Arrange opening addon windows around all visible addon windows, preferring
  edges of the main Fieldbook for dialogs launched from it. Respect pinned Notes
  and the locked spell-ID window, and keep already-visible windows stationary
  when repositioning their anchor window.
- Add the default-on "Always attempt to anchor to main window" option. Damage,
  offense, defense, behaviour and effects prefer the book's right edge, then the
  next window's right. Filters prefer the book's left, then bottom, then another
  window's left. Help and Options prefer the book's right, then left.
- Recheck saved positions on opening with anchoring enabled. Disabling the option
  retains overlap-only repositioning. Account for UI scale, hidden windows and
  late content sizing; keep windows on-screen, minimize overlap when crowded,
  and shrink oversized windows to fit. Untouched defaults remain book-relative.
- Trim empty space below Offenses and beside Behaviour. Give the damage form
  balanced side margins. Make Creature Notes toggle open/closed while respecting
  its pinned state.

### Damage observations and recorded abilities

- Rename the damage panel to "Damage taken" and the entry form to "Your damage
  observations". Add an editable Player level before the Creature level dropdown,
  defaulting to the current player level each time the form opens.
- Store both levels per observation, allow different levels while recommending
  equal-level records, and display recorded player levels in summary/history.
  Preserve older records as equal-level observations; validate positive integer
  levels, valid hit ranges and the creature's observed level range.
- Replace Confirm with a themed square green tick to the right of Reject.
  Right-align the action group with consistent spacing and reserve scrollbar room.
  Pending buttons are red and clickable; confirmed buttons keep their full grey
  themed border and green tick. Use the client's native texture/atlas for the
  disabled border.
- Restrict spell tooltips to the area left of visible action buttons, hiding them
  when leaving that area so button gaps cannot trigger them. Preserve checkbox
  hints, the spell-ID preference and wheel scrolling.

- Show "Ability confirmed" on confirmed tick buttons. Hide the tooltip checkbox
  and all ability action buttons while the creature is locked; restore them on unlock.
- Add faint dividers between visible ability rows, with lower opacity than the
  creature-information section divider. Keep ability tooltips available while locked.

### Persistent event history

- Add a fourth themed title-bar button beside Options for Event log. Record
  discoveries, point awards and observed-cast alerts independently of chat settings,
  preserving timestamps, colored messages and event details without duplicate
  discovery messages.
- Keep per-character history from first use across reloads, sessions and Bestiary
  resets, without trimming events or inventing past history. Show newest-first
  pages of 50 events with live updates, themed scrolling, saved position, scaling,
  Escape dismissal and the normal placement rules.
- Fit the log to its content, from a compact 200-unit empty window to a 767-unit
  maximum before scrolling. Anchor footer controls to the bottom, hide unnecessary
  pagination and recheck placement when the window grows.

### Validation and documentation

- Update current documentation and retain the local iteration notes below.
- Extend regression coverage for placement priorities, scale, crowding, pinning,
  saved anchoring preferences, unequal-level records, legacy damage, muted event
  collection, log retention, live updates, pagination and adaptive window height.
  All 20 test files pass; live WoW rendering remains an in-game check.

## v0.9.55 - Included in v0.13.30-beta

- Size Event log height to its content, starting at a compact 200 UI units and
  growing to the existing 767-unit maximum before scrolling. Keep footer controls
  at the bottom, hide unnecessary pagination and recheck screen placement on growth.

## v0.9.54 - Included in v0.13.30-beta

- Add a fourth themed title-bar button beside Options for a persistent Event log.
  Capture creature discoveries, point awards and observed-cast alerts regardless
  of their chat settings, retaining timestamps, colored messages and event details.
- Keep per-character history from first use across reloads, sessions and Bestiary
  resets, without trimming old events or fabricating pre-installation history.
  Display newest-first pages of 50 events with live updates, themed scrolling,
  saved position, scaling, Escape dismissal and normal window placement.
- Verify muted-event collection, discovery deduplication, reload/reset retention,
  the title-button toggle, live updates and access to older pages.

## v0.9.53 - Included in v0.13.30-beta

- Restrict ability spell tooltips to the text area left of the first visible
  action button. Leaving that area hides the tooltip; button gaps no longer
  trigger it. Preserve checkbox/button hints and mouse-wheel scrolling.

## v0.9.52 - Included in v0.13.30-beta

- Preserve the themed square border on confirmed/locked ability tick buttons by
  deriving disabled artwork from the client's normal button texture or atlas,
  desaturating the frame while retaining the green tick.

## v0.9.51 - Included in v0.13.30-beta

- Right-align Recorded Abilities action buttons as a group, with the tick at the
  content's right edge and consistent gaps between buttons. Reserve room when
  the ability scrollbar is visible so it cannot overlap the tick.

## v0.9.50 - Included in v0.13.30-beta

- Rename the main damage panel to "Damage taken" and the entry form to "Your
  damage observations". Keep the observed-creature-level dropdown and add an
  editable Player level field that defaults to the current level on opening.
- Recommend equal-level observations while allowing different levels. Store both
  levels on each observation and show player levels in the summary and history.
  Preserve older observations as equal-level records; validate positive integer
  levels and retain the existing damage-range and creature-level checks.
- Cover unequal-level persistence, legacy records and invalid player levels.

## v0.9.49 - Included in v0.13.30-beta

- Replace Recorded Abilities' Confirm button with a square green-tick button
  using the close/help/options theme, positioned after Reject on the right.
  Pending, unlocked abilities use a clickable red button; confirmed abilities
  and locked entries use a disabled grey button while keeping the tick green.

## v0.9.48 - Included in v0.13.30-beta

- Add the default-on "Always attempt to anchor to main window" option. Observation
  and effect panels prefer the book's right edge, then the next window's right;
  filters prefer the book's left, then bottom, then a neighbouring window's left;
  Help and Options prefer the book's right, then left before general placement.
- Recheck anchoring when reopening unpinned dialogs, including saved positions.
  Turning the option off retains the previous overlap-only placement behavior.
  Preserve screen bounds, pinning and overlap fallback when screen space is scarce.
- Test directional fallbacks, default/saved option state, pinning and crowded screens.

## v0.9.47 - Included in v0.13.30-beta

- Prefer a free main-book edge when positioning overlapping dialogs opened from
  the Fieldbook, even if an unrelated window offers a nearer edge. Fall back to
  other windows when the book's edges are blocked or off-screen; retain pinning
  and screen-visibility priority.

## v0.9.46 - Included in v0.13.30-beta

- Make the Creature Notes button toggle its window open and closed. Pinned Notes
  remain open, and reopening displays the selected creature's saved notes.

## v0.9.45 - Included in v0.13.30-beta

- Trim 30 UI units of empty space below the Offenses buttons and narrow Behaviour
  by 40 UI units, keeping its labels inside the reduced right margin.
- Narrow the equal-level damage observation window by 36 UI units so its control
  row has matching 28-unit left and right margins; resize heading/instruction text.

## v0.9.44 - Included in v0.13.30-beta

- Arrange every opening addon window, including the main book and spell-ID
  displays, around all other visible addon windows. Evaluate neighbouring edges
  together to avoid fixing one overlap by creating another.
- Respect pinned Creature Notes and the locked spell-ID window, treating them
  as obstacles without automatically moving them aside. Screen bounds still take
  priority, and crowded layouts use the smallest available overlap.
- Keep already-visible windows in place when moving their anchor window; cover
  multiple neighbours, hidden/faded windows, pins and main-window opening in tests.

## v0.9.43 - Included in v0.13.30-beta

- Check secondary dialogs for overlap with the visible main Fieldbook on opening,
  including saved positions and content-sized layouts. Prefer a fully visible
  position against one of the book's four edges, accounting for UI scale.
- When no adjacent position fits, prioritize staying on-screen and minimize
  overlap. Fit oversized dialogs to the screen and preserve untouched defaults
  as book-relative anchors. Do not move the main window.
- Add geometry regression coverage for side placement, vertical alternatives,
  limited screen space, saved positions, scaling and a hidden main window.

## v0.9.42-beta - 2026-09-25

This release includes all changes since v0.9.11-beta (local iterations v0.9.12
through v0.9.42). Both players must update to the same addon version to share
creatures; sharing now uses protocol 4 with the existing report schema.

### Creature discovery and abilities

- Fix nameless "Creature #" entries created by automatic observations. Preserve
  names from attributed post-combat encounters and require a usable identity
  before creating a creature or legacy ability record, including instant casts.
- Hide existing nameless entries until a reliable observation identifies them,
  retaining their abilities, notes, locks, review decisions and earned credit.
  Conflicting encounter names are excluded; legacy ability-only records wait
  for identification. Creature Notes can select properly identified entries.
- Make an ability's Resolve button save the canonical spell name and ID, confirm
  the ability and enable its spell tooltip in one step. Remove Pending and
  Automatic observation labels while preserving personal notes, effects and
  tooltip choices. Hide Resolve once an ability is confirmed with a spell ID.
- Merge matching canonical abilities without losing notes or effects; conflicting
  IDs or oversized notes require review in Edit. Resolved observations do not
  return under their old names after rescanning or reloading.
- Respect the renamed "Show spell IDs on tooltips if possible" setting in journal
  ability tooltips. Hovering an ability's checkbox shows "Display on tooltip".
- Show grey bracketed creature IDs beside the creature name in Creature Notes
  and Share. Default "Retain hovered aura tooltips" to off while preserving
  existing saved choices.

### Points, announcements and sharing

- Award a silver star at 10 kills (+1 point), a gold star at 25 kills (+2 more)
  and a gold crown at 50 kills (+3 more), for six cumulative kill points. Credit
  qualifying existing personal entries for the crown once, preserving earlier
  awards, spending and protection against repeated credit after deletion/reload.
- Combine discovery and point messages into one named Bestiary announcement.
  Include creature type, observed level and location for discoveries, and type
  for kill rewards. Never substitute an unresolved creature ID. Keep the prefix
  cyan, bracketed rewards yellow and parenthesized details grey, with dot separators.
  Discovery/point announcement preferences remain respected; a sighting revealing
  both a new level and location still awards one point total.
- Add "Block incoming offers" to Options, off by default. Enabling it declines
  unaccepted offers without spending the sender's points while allowing already
  accepted reports and paid receipt retries to finish. Outgoing sharing remains available.
- Reject offers to the current character, including capitalization and spacing
  variants, before reserving points or sending messages.
- Time out the initial recipient check after 20 seconds, show a countdown and a
  useful error, release the reservation and restore sending. Late replies cannot
  revive expired offers. Missing addons, offline players, restrictions and lag
  are possible causes; silence is not treated as proof that an addon is absent.
- Waive the basic-information point when an accepted report adds no new basics
  to the recipient; each selected rumour still costs one point. Reserve the
  maximum estimate and settle the actual cost at acceptance, including zero-cost
  basic-only reports. Notify the sender once and show the waiver and final charge
  in Share; the receiver also sees when known basics are free.
- Preserve accepted quotes and settled prices through retries and reloads so a
  repeated transfer cannot charge twice, reprice a paid report or duplicate the
  savings notice. Retain explicit protocol and installed-version compatibility checks.

### Windows, layout and styling

- Let any addon window come to the front when opened or clicked, including its
  controls. Fix the intermediate v0.9.28 regression that let decorative overlays
  intercept main-window clicks; noninteractive decorations remain click-through.
- Remember dragged window positions per character across sessions, including
  shared Help/Options and observation-panel positions. Untouched defaults remain
  relative to the main book through opening, closing, resizing, scaling and reloads.
  Clamp windows and restored positions to the screen; full reset clears positions.
- Start damage, Help/Options and Creature Notes beside the book on the right,
  observation panels below damage, and Rumours below Notes. Put Locations on the
  left and Rank below it. Share starts on the right with its bottom aligned to the
  book. Center incoming/debug dialogs on the book when available, and anchor the
  untouched Last observed spell IDs window beside it once the book is built.
- Narrow Share, Offenses, Defenses, Behaviour and Rank windows and tighten their
  columns/buttons. Fit Share to its contents with bounded scrolling for long
  reports; align rumour checkboxes with their labels and use themed corner close buttons.
- Give Share a larger yellow creature name, grey bracketed ID and subdued details.
  Replace pipe separators with dots in the main creature details and announcements.
- Wrap creature details by complete property groups and indent continuation lines
  for oversized groups. Grow the details area and book to show all text without
  scrollbars, moving lower content together without crowding the footer.
- Grey out and disable empty alphabet-index letters, clearing a selected letter
  when filters leave it empty. Rename filter headings to "Filter: Locations" and
  "Filter: Rank". Fit Locations to its contents up to 15 visible rows, then scroll;
  allow extra height for wrapped names. Shorten Rumours when there is no content.
- Make Recorded abilities, observation panels, damage observation, Effects,
  filters, Help and Options headings yellow. Grey out optional/out-of-combat hints.
- Add short parchment fades at Help/Options scroll edges, visible only where
  content is clipped. Keep borders above the fades and decorations click-through.
  Give Help, Options and Locations matching dark scrollbar tracks, with arrows
  fitted beneath the close button and above the bottom border; adjust the shared
  scrollbar one pixel left and its top one pixel up for cleaner alignment.
- Add minus/plus buttons beside the UI scale reset for five-percentage-point
  changes within the existing 50-150% bounds. Keep the slider and label synchronized.
- Add a separate Points block to Help, covering discovery and kill awards plus
  sharing uses, costs, reservations and the waiver for already-known basics.

### Verification and maintenance

- Expand regression coverage for identity recovery, ability resolution, rewards,
  announcements, account migration, sharing/offer controls, pricing and timeouts,
  window focus, position persistence, scaling and dynamic layouts. Update the
  user documentation and manual testing notes for the completed behavior.
- Require cumulative pre-push changelog coverage in AGENTS.md, including all local
  iterations and any earlier push-only changes not yet publicly released.
- Audit earlier public releases against each preceding release tag, make their
  coverage ranges explicit, fill in maintenance and verification omissions, and
  restore the missing v0.7.0 and v0.7.1 release history. Historical behavior and
  original release dates are retained.

### Local iteration history

The following entries document development steps included in this release;
they were not separate public releases. The summary above describes final behavior.

## v0.9.41 - Local iteration (included in v0.9.42-beta)

- Require cumulative pre-push changelog coverage in AGENTS.md, consolidating all
  changes since the previous push and carrying forward earlier unreleased changes.

## v0.9.40 - Local iteration (included in v0.9.42-beta)

- Move the themed Help, Options and Locations scrollbars one pixel left and
  raise their top edge one pixel to close the remaining gap beneath the close button.
- Color the Help and Options page headings yellow to match other headings.

## v0.9.39 - Local iteration (included in v0.9.42-beta)

- Preserve book-relative initial dialog positions through opening, closing,
  resizing, scaling and reloads. Only dragged or previously saved positions are
  stored as independent screen coordinates; shared dialog positions follow the
  same rule.
- Anchor the observation panels, Rank filter and Rumours directly to the book,
  and center incoming reports and debug dialogs on it when available. The untouched
  Last observed spell IDs window also anchors beside the book once it is built.
- Clamp restored positions to the current screen geometry, and keep the complete
  default window rectangle inside the screen with native clamping.

## v0.9.38 - Local iteration (included in v0.9.42-beta)

- Draw Help and Options window borders above their scroll fades while preserving
  click-through decoration, and raise the top fade and clipping edge by 3 pixels.
- Close the scrollbar gaps beneath the close button and above the bottom border
  for Help, Options and the matching Locations scrollbar.

## v0.9.37 - Local iteration (included in v0.9.42-beta)

- Rename the filters to Filter: Locations and Filter: Rank, and narrow the Rank
  and Observed offenses windows with smaller, comfortably padded school buttons.
- Fit the Locations window to its contents, allowing up to 15 visible rows before
  scrolling. Accommodate wrapped names and use the Help/Options scrollbar styling.
- Rename Help's Points awarded block to Points, with separate earning and spending
  sections explaining sharing costs and the waiver for already-known basics.

## v0.9.36 - Local iteration (included in v0.9.42-beta)

- Blend clipped Help and Options content into the parchment with short top and
  bottom fades. Hide each fade when its corresponding end is fully visible, and
  preserve brightness matching and click-through controls.
- Extend both scrollbars from directly below the close button to the bottom
  window inset, and add a dark track with a parchment-colored border.

## v0.9.35 - Local iteration (included in v0.9.42-beta)

- Waive the basic-information point when an accepted report adds no new basics
  to the recipient; selected rumours retain their one-point price. Reserve the
  maximum estimate, then settle the reduced cost atomically at acceptance.
- Notify the sender once in chat and retain the adjustment and actual charge in
  Share status. Show the recipient when their known basics qualify for the waiver.
- Use sharing protocol 4 for the acceptance quote, retaining schema-1 reports
  and already-settled prices across reloads and retries. Both players must update.
- Cover matching/broader basics, changed fields, zero-cost reports, acceptance-time
  changes, duplicate/spoofed replies, notifications and interrupted deliveries.

## v0.9.34 - Local iteration (included in v0.9.42-beta)

- Add minus and plus buttons on either side of the UI scale 100% reset. Each
  click immediately changes the scale by five percentage points, synchronizes
  the slider and label, and respects the existing 50-150% limits.

## v0.9.33 - Local iteration (included in v0.9.42-beta)

- Wrap creature details by complete property group: move a group to a fresh line
  when it cannot fit alongside the preceding groups, retaining dot separators
  between groups that fit together.
- Indent continuation lines when a group is wider than a full line, preserving
  school colors and applying the same layout to locations and combat traits.
- Grow the summary and book to fit every line without scrollbars. Move the lower
  content down together, preserving panel sizes and keeping the footer visible.

## v0.9.32 - Local iteration (included in v0.9.42-beta)

- Limit the initial recipient compatibility check to 20 seconds and display a
  countdown in Share. Use runtime elapsed time so clock adjustments cannot
  prolong this check.
- Explain that an unanswered check may mean a missing/disabled addon, an offline
  or restricted player, or lag. Release reserved points and restore sending
  automatically; silence does not prove that the addon is absent.
- Ignore late replies after expiry and cover the native timer-to-window path,
  lagged replies, restrictions, queue cleanup and fresh attempts in tests.

## v0.9.31 - Local iteration (included in v0.9.42-beta)

- Give the Share creature heading larger yellow text and a grey bracketed ID,
  with separate subdued type, level and location details.
- Size the Share window around its contents, retaining scrolling for long basic
  information and rumour lists, and align rumour checkboxes with their labels.
- Use dot separators in the main creature details and discovery announcements.

## v0.9.30 - Local iteration (included in v0.9.42-beta)

- Fix the v0.9.28 focus regression that made main-window controls unresponsive:
  mouse hooks had enabled input on decorative frames covering the book.
- Hook only frames that already accept clicks, preserving mouse-motion settings
  and allowing decorative and hover-only containers to remain click-through.
  Keep click-to-front behavior for windows and their interactive controls.
- Reproduce the failure in the widget harness by modeling mouse-hook side effects;
  cover full-book overlays, hover-only containers, click-only controls and controls
  enabled later, alongside the existing journal and sharing interactions.

## v0.9.29 - Local iteration (included in v0.9.42-beta)

- Start Share one creature immediately to the right of the book with their bottom
  edges aligned, while preserving any saved window position.
- Narrow the Share window from 520 to 460 UI units, bring the two rumour columns
  closer together and resize its fields, text and buttons to fit.

## v0.9.28 - Local iteration (included in v0.9.42-beta)

- Put addon windows on one shared layer and bring a window forward when opened
  or clicked, including clicks on its buttons, text fields and other controls.
- Make the book's secondary dialogs independent windows so the book can also
  rise above them. Preserve their scale, anchors, saved positions and close behavior.
- Apply the same focus handling to sharing, Notes, Rumours, filters, Help/Options,
  diagnostics and spell-ID/aura panels, with regression coverage for child controls.

## v0.9.27 - Local iteration (included in v0.9.42-beta)

- Disable Send and show “You cannot send an offer to yourself” when the recipient
  matches the current character, including capitalization and spacing variants.
  Validate again before creating a transaction, reserving points or sending packets.
- Add a separate Points awarded block to Help with discovery and 10/25/50-kill
  rewards, including clarification of the single-point award for a sighting that
  reveals both a new level and location.
- Default Retain hovered aura tooltips to off, keeping it available as an optional
  fallback and preserving existing saved choices.

## v0.9.26 - Local iteration (included in v0.9.42-beta)

- Use the standard themed close button in the Share and incoming-report windows,
  matching the 24-pixel button and upper-right corner inset of Notes and Rumours.
  Keep the existing close/cancel behavior.

## v0.9.25 - Local iteration (included in v0.9.42-beta)

- Add a per-character “Block incoming offers” checkbox to Options, off by default.
  Enabling it declines new offers and closes unaccepted offers immediately,
  without spending the sender's points. Outgoing sharing remains available.
- Allow already accepted reports and receipt retries to finish, preserving paid
  transfers. Full reset restores the default of allowing incoming offers.
- Cover defaults, persistence, UI toggling, pending/partial offers, sender balances,
  accepted transfers and receipt reconciliation in sharing regression tests.

## v0.9.24 - Local iteration (included in v0.9.42-beta)

- Place the damage observation window to the right of the book, with Offenses,
  Defenses and Behaviour underneath it. Help and Options also start beside the
  book's upper-right corner.
- Start ID Logs and Notes at the book's upper right and Rumours below it.
- Start the location filter to the book's left, with the rank filter underneath
  and their right edges aligned.
- Use these arrangements for initial positions and full reset; existing saved
  positions continue to take precedence.

## v0.9.23 - Local iteration (included in v0.9.42-beta)

- Combine discovery and point notifications into one named Bestiary announcement.
  Never substitute a creature ID when its name cannot be resolved.
- Show the observed creature type, level and location for discovery updates, and
  only the type for the 10/25/50-kill rewards, using the requested wording and
  punctuation. A sighting with both a new level and location still awards one point.
- Keep the addon prefix cyan, color bracketed rewards yellow and parenthesized
  details grey. Preserve the discovery and point announcement settings.
- Cover exact messages, colors, duplicate prevention, locked entries, unavailable
  metadata, settings combinations and kill milestones through addon-event tests.

## v0.9.22 - Local iteration (included in v0.9.42-beta)

- Make the Offenses, Defenses, Behaviour, equal-level damage observation, Effects,
  location filter and rank filter headings yellow.
- Remember all movable window positions per character across reloads and game
  sessions, including secondary dialogs and the shared Help/Options and
  observation-panel positions. Keep the existing spell-ID window position.
- Preserve saved top-left positions through UI scale changes and varying dialog
  heights, clamp restored windows to the screen, and clear positions on full reset.
- Cover reloads, character separation, shared panels, scaling, drag/close/logout
  saves, dialog registration and reset behavior with regression tests.

## v0.9.21 - Local iteration (included in v0.9.42-beta)

- Award the silver star at 10 kills (+1 point), the gold star at 25 kills
  (+2 more), and a gold crown at 50 kills (+3 more), for 6 cumulative kill points.
- Replace the star beside the kill counter with a gold crown at 50 kills and
  announce the new reward as “gold crown”.
- Credit existing personal entries that already qualify for the crown once on
  load. Preserve earlier silver credit, spending and deletion/reload protection.
- Cover reward boundaries, locked entries, crown display, migration, account
  merges, announcements and duplicate prevention in regression tests.

## v0.9.20 - Local iteration (included in v0.9.42-beta)

- Show “Display on tooltip” when hovering over a recorded ability's tick box,
  including while the creature entry is locked.

## v0.9.19 - Local iteration (included in v0.9.42-beta)

- Shorten the Rumours window when it has no unverified rumours or shared basics.
  Restore its normal scrolling height when content appears, keep the title in
  place, and retain room for feedback messages when needed.

## v0.9.18 - Local iteration (included in v0.9.42-beta)

- Narrow Observed defenses from 540 to 360 and Observed behaviour from 540 to 390
  UI units. Tighten their columns, center defense headings over the checkboxes,
  and wrap instructions onto two lines to fit the smaller windows.

## v0.9.17 - Local iteration (included in v0.9.42-beta)

- Grey out and disable index letters with no entries matching the current
  filters. Clear a selected letter if it becomes empty after filtering.

## v0.9.16 - Local iteration (included in v0.9.42-beta)

- Hide Resolve for abilities already confirmed with a spell ID, retaining it for
  pending or unlinked abilities.

## v0.9.15 - Local iteration (included in v0.9.42-beta)

- Make `(optional)` and `(out of combat)` hints grey in the ability editor labels.

## v0.9.14 - Local iteration (included in v0.9.42-beta)

- Make the Recorded abilities heading yellow to match the other section headings.

## v0.9.13 - Local iteration (included in v0.9.42-beta)

- Show the creature ID beside its name in Creature Notes, with `[#1234]` in grey.
- Make the ability-row **Resolve** button save the canonical spell name and ID,
  confirm the ability and enable its spell tooltip in one step. Remove pending
  and automatic-observation labels while preserving personal notes, effects and
  tooltip visibility choices. Renamed observations do not return on rescan or reload.
- Merge matching canonical ability records without losing notes or effects;
  conflicting IDs or notes beyond the editor limit require review in Edit.
- Journal ability tooltips now respect the spell-ID display option, renamed
  **Show spell IDs on tooltips if possible**.

## v0.9.12 - Local iteration (included in v0.9.42-beta)

- Preserve creature names from attributed post-combat meter observations, fixing
  nameless entries with pending abilities and the misleading Creature Notes
  selection prompt. Conflicting names for one creature ID are excluded.
- Require a usable creature name before automatic observations can create a
  journal entry or legacy ability record. Instant casts resolve the watched
  creature first, and discovery-point messages use the saved name.
- Hide existing nameless entries until reliable observations identify them,
  preserving abilities, notes, review decisions, locks and earned credit. Legacy
  ability-only records wait for identification before creating an entry.
- Added regression coverage for encounter-only creatures, invalid names, instant
  casts, point messages, legacy recovery, account migration and Creature Notes.

## v0.9.11-beta - 2026-09-25

Coverage: all changes from v0.9.6-beta through v0.9.11-beta, including the local
v0.9.7-v0.9.10 iterations. These notes describe the behavior of v0.9.11.

- Added **Resolve** to recorded ability rows, allowing spell resolution outside
  combat without opening Edit. It uses the recorded spell ID when available,
  otherwise the exact ability name, and remains enabled for unlocked entries.
  Resolution preserves notes, effects and review state; pending abilities still
  use the existing Confirm button afterward.
- Ignore **Attack** during automatic ability recording, including cast events,
  encounter observations and restoration of older observation records. Ignored
  attacks produce no observation announcements or new ability entries.
- Combined Totem, Gas Cloud and Unclassified into a single **Other** creature-type
  filter, preserving each creature's recorded type.
- Halved the gap between Other and Locations, moving Locations, Ranks and Pending
  upward together to preserve their spacing.
- Update filter/ignored-ability regression checks, the README and sharing/kill
  acceptance notes for this release's behavior and installed-version checks.

## v0.9.6-beta - 2026-09-25

Coverage: all changes from v0.8.3-beta through v0.9.6-beta, including the sharing
milestone and all intervening local iterations. These notes describe v0.9.6;
later reward thresholds and pricing changes belong to subsequent releases.

- Hide scrollbars whenever a window's content fits its visible area, including
  Help, Options, Notes, Rumours, sharing previews and debug reports. Scrollbars
  reappear when content grows and disappear when it shrinks to fit again.

- Help and Options now share the last top-left window position. Dragging either
  page, switching pages or closing and reopening them retains that position,
  accounting for UI scale.

- Added a gold cog button directly to the left of the main window's help button,
  matching the existing red beveled title-bar buttons, size and spacing.
- Moved all settings and Reset Bestiary into a dedicated Options page. The help
  page now contains instructions and About only. Both pages retain parchment
  styling, scrolling, dragging, brightness/UI scale settings and Escape-to-close.

- Added **Account-wide tracking** at the top of Options, enabled by default.
  Changing it takes effect after `/reload`; the option shows when a reload is needed.
- Added account-wide Bestiary storage. Each character's existing journal merges
  once when that character first loads with account tracking enabled, combining
  creature records, kills, discoveries, notes and previously earned/spent points.
  Original character journals remain available with account tracking disabled.
- Kept UI preferences per character and sharing transactions owned by their
  original character. Migration does not replay on reload or after a reset.
- Made reset prompts identify the active account or character journal. Resets
  clear that journal and the current character's settings, preserving the other
  journal and the selected tracking mode.

- Set the silver kill star to 2 kills and the gold star to 25 kills. Silver still
  awards 1 point and gold adds 2; already-earned points remain credited.
- Moved Rumours onto the book's frame strata, below dialogs, and enabled normal
  focus raising for both windows so they can overlap without blocking each other.
- Dimmed the empty recorded-abilities prompt to grey.
- Made Index a toggle: it starts red with A-Z hidden and no letter filter. Clicking
  it highlights the button and reveals all 26 clickable letters. Switching it off
  hides the letters and clears the letter filter.

- Fixed corpse inspection and unrelated deaths granting kills or milestone
  points. Kills now require matching player/pet/party, eligibility and death
  evidence for one creature GUID, with bounded pending/replay protection.
  Discovery and existing reward amounts are unchanged; no XP or loot is required.
  Added opt-in kill decision diagnostics and regression coverage. Live testing
  confirms party-assisted credit, corpse duplicate protection and no credit for
  a watched unrelated death or a personal finishing blow on another player's
  tag. Own zero-XP, no-loot kills also pass through the new gate. Pet delivery
  remains unverified live. Live reload acceptance is blocked by the operator-
  reported Forever SavedVariables reload bug; automated persistence checks pass.
- Moved Rumours between the main window's kill counter and Creature Notes.
  It toggles a separate parchment window with attributed claims, shared basics,
  scrolling, brightness/scale settings, dragging, screen clamping and Escape.
- Added a green tick to verify a rumour directly into the personal journal,
  preserving existing ability notes and effects. Locked entries must be unlocked
  before verification; receiving and reviewing still earn no points.
- Matching manual abilities, confirmed observations and trait selections remove
  corresponding rumours across senders. Already-known facts do not add rumours.
- Kept x for rejection. Later reports of a rejected claim show Previously rejected
  in the offer preview and Rumours window, including when sent by another player.
- Retained exact installed-version checks for sharing. Added regression coverage
  for rumour review, manual matching, rejection history and the separate window.

- Added point-funded sharing of one creature to a named recipient, with explicit
  acceptance, delivery acknowledgement and attributed unverified Rumours.
- Basic information costs 1 point; each selected rumour adds 1 point, with no
  two-rumour selection cap. Reservations, spending and personal earning credit
  are tracked separately; receiving reports earns no points.
- Added realm-free character names with surnames, two-column rumour selection,
  and specific explanations when sending is unavailable.
- Added installed-addon version checking before new offers and paid retries.
  Both players must use the same version; mismatches show both versions when
  supplied and reject new offers without spending points. Sharing uses protocol
  3 while retaining report schema 1 and historical costs for paid retries.
- Required an increment of the last version number for each completed local
  change set, with batch pushes publishing through the existing Beta tag workflow.
- Live delivery, recipient attribution and separate rumour storage were confirmed
  during development. Persistence testing remains blocked by the operator-reported
  WoW Forever persistence bug.
- Bound report sizes, location counts, incoming queues and receipt/rumour storage;
  reject malformed or oversized reports instead of silently truncating them.
  Exclude private notes, ID logs, damage, kills, locks and unverified received claims
  from outgoing reports. Preserve source attribution and personal/shared separation.
- Reconcile unknown deliveries through bounded retries of the same transaction
  without a second charge; preserve settled costs and receipt deduplication across
  reloads. Entry deletion retains credit/spending, while full reset erases the
  active journal and transfer history. Handle messaging readiness, throttling,
  combat restrictions and native API result codes without treating sends as receipts.
- Add simulated sharing, account migration, kill-attribution and widget tests,
  diagnostic/manual acceptance guides, and expanded user documentation. Read
  runtime version displays from TOC metadata instead of a stale version fallback.

## v0.8.3-beta - 2026-09-25

Coverage: all changes from v0.8.2-beta through v0.8.3-beta.

- Made the minimap button draggable around the minimap perimeter, with a saved
  position and Shift-click lock toggle. Starts unlocked; dragging does not open the book.
- Made Choose effects, Offenses, Defenses, Behaviour, Locations and Ranks toggle
  their windows; observation windows still respect the single-window option.
- Renamed Record equal-level hits to Record damage taken.
- Added optional Spell ID window auto-fade when all observation rows are empty.
  New data restores it immediately; faded windows do not intercept mouse input.
- Reposition the minimap button after UI scaling and cover minimap drag/lock,
  dialog toggles and spell-window fading in regression tests.

## v0.8.2-beta - 2026-09-24

Coverage: all changes from v0.8.1-beta through v0.8.2-beta.

### Added

- Default-on Creature notes follow target selection option. Eligible targets
  switch ID Logs and Notes without changing the Bestiary page or opening a
  closed notes window.
- Pin icon beside the notes close button. Pinning depresses the button, disables
  Close and prevents Escape from dismissing the notes window.
- Default-on minimap button to open or close the journal, with a visibility
  checkbox. Both journal and minimap use the INV_Misc_Book_02 icon.
- Saved UI scale from 50% to 150%, default 100%, with a reset button. The slider
  previews the percentage and applies scaling only when released.
- Discovery points: first sightings award one point including their initial
  level and zone. Later sightings revealing a new level, zone, or both award
  one point per observation; repeated sightings award nothing.
- Silver and gold kill milestones with cumulative rewards: silver awards one
  point and gold adds two more. **Testing thresholds remain one kill for silver
  and two kills for gold.**
- Default-on point award chat messages, controlled by an Options checkbox.
- Journal entry and point totals above search, a grey Search placeholder, and
  a muted review legend below the list.

### Changed

- Widened the creature list by 24px within the same book dimensions, preserving
  action-button widths while compressing the right-pane fields.
- Colored creature names yellow and moved the kill counter beside Creature
  Notes, with its silver/gold star immediately to the left.
- Offenses, Defenses and Behaviour replace one another and share their top-left
  position by default, including after dragging. An option permits multiple windows.
- Added a yellow OPTIONS heading and grey No damage recorded empty-state text.
- Kill and discovery-point progress continue while entries are locked; reviewed
  creature information remains protected from changes.

### Fixed

- Added death polling and a same-GUID fallback for previously observed eligible
  NPCs that become unattackable corpses. Each death is counted once without an
  XP requirement; unreadable or missing death evidence still cannot be counted.
- Removed duplicate first-level and first-zone discovery bonuses. Existing
  records use saved zones and observed level endpoints; older data cannot
  reconstruct whether later discoveries occurred in the same observation.
- Removed keyboard capture from the Options scale slider.
- Add regression coverage for discovery-credit migration and duplicate prevention,
  locked progress, target-following and pinned Notes, minimap visibility and UI
  scaling, and update user/manual-test documentation.

## v0.8.1-beta - 2026-09-24

Coverage: all changes from v0.8.0-beta through v0.8.1-beta.

### Added

- Delete a selected creature with a typed `delete` confirmation. This removes
  its observations, abilities, ID logs, notes and legacy record. Cancelling or
  changing selection discards confirmation; future encounters can record it again.
- Ranks filter with Elite, Rare, Rare Elite and World Boss selections, combined
  with existing filters. Added 6px of spacing below Unclassified.
- Ability effect tags for Arcane, Fire, Frost, Holy, Nature and Shadow resistance
  and immunity.
- Disabled Share placeholder beside Delete, below Previous/Next.

### Changed

- Refined and reduced the padlock button and artwork, rounded its corners,
  added a keyhole and raised shackle, and moved it up 2px. Added 1px of padding
  on each side of the artwork and 2px of left padding to the creature pane.
- Reserved a fixed column for the review asterisk so creature names do not shift
  when entries are locked or unlocked.
- Matched the Locations, Ranks, Effects, Offenses, Defenses, Behaviour and Options
  corner close buttons to ID Logs and Notes.
- Colored the five instructions headings and ABOUT heading yellow.

### Fixed

- Kept the rank filter and its controls together when raising the window.
- Added a scrollbar for more than four Recorded Abilities, synchronized with
  mouse-wheel navigation and hidden when all abilities fit.
- Used the damage window's available height for five single-line records;
  scrolling now accounts for wrapped lines and appears only when needed.
- Hid the Locations scrollbar and disabled wheel scrolling when the list fits.
- Extend journal/widget regression tests for typed deletion, legacy-record removal,
  selection changes, rank filtering and the revised controls; update the README.

## v0.8.0-beta - 2026-09-24

Coverage: all changes from v0.7.1-beta through v0.8.0-beta, including release
guidance, workflow updates and the spell-ID/notes work accumulated before the tag.

This release moves Azeroth Fieldbook from Alpha to Beta.

### Added

- Last Spell ID above the target cast bar, with a one-minute linger and
  right-click dismissal. Enabled by default.
- Movable, lockable Last observed spell IDs window for enemy casts, identifiable
  instant casts, player debuffs and NPC target buffs. Enabled and unlocked by
  default, with 35% background opacity and a two-minute expiry. Options include
  background opacity and indefinite display.
- Optional compact snapshots of accessible hovered aura tooltips, retained as
  historical text and dismissible with a right-click. Enabled by default.
- Creature-specific ID Logs and Notes, accessible through Creature Notes or
  `/fieldbook notes`, with up to ten manually entered spell links, removable rows
  and a visible 400-character notes textbox.
- Copyable diagnostic report window for `/fieldbook debug`, including aura access
  failures and hovered-tooltip diagnostics.

### Changed

- Locking a creature now prevents automatic and manual changes to its Bestiary
  records. Ability, offense, defense, behaviour and damage editors are disabled
  while locked. Personal ID logs and notes remain editable.
- Expanded help options for spell-ID displays, hovered snapshots, locking,
  persistence and opacity; matched the opacity slider to the brightness slider.
- Tightened help spacing and hovered snapshot layout, and removed the redundant
  Locked label from the spell-ID window.

### Fixed

- Corrected cast/channel spell-ID return positions and kept diagnostic text out
  of the normal cast-ID display.
- Excluded players and player-controlled targets from target-buff observations.
- Added guarded aura-query fallbacks and an out-of-combat rescan when access
  becomes available again.

### Verification and release tooling

- Add repository development, authorship and release instructions in AGENTS.md;
  update the checkout action and configure the packager to use CHANGELOG.md.
- Add spell-ID, tooltip-snapshot, Creature Notes and debug-window tests plus
  client API research and manual acceptance notes. Extend journal/observation
  checks for locking, private notes and the new displays; update user documentation.

### Client limitations

- WoW Forever combat restrictions can prevent enemy aura queries and access to
  protected native aura tooltips. Hover retention works only for accessible
  tooltips; instant abilities require an observable event or aura.
- Displayable secret text is not inspected or converted into saved observations.
  Snapshot durations are historical and do not count down.
- The journal still starts empty. Unnamed Encountered creature entries can come
  from prior automatic observations; no creature entries are bundled as defaults.

## v0.7.1-beta - 2026-09-24

Coverage: all changes from v0.7.0 through v0.7.1-beta. This was a packaging and
publication update; gameplay behavior was unchanged from the first public alpha.

- Add CurseForge project metadata and package the addon as AzerothFieldbook,
  excluding tests and workflow files from the distributed archive.
- Add the tag-triggered GitHub Actions release workflow with full-history checkout,
  BigWigsMods packaging, GitHub release assets and CurseForge upload support.
- Advance TOC/README version references to 0.7.1. The published tag designated
  this build Beta, although the README at that tag still used an alpha label.

## v0.7.0 - 2026-09-24

First public Alpha release. There is no earlier public release baseline; this
summary covers the initial shipped feature set, including pre-release iterations.

- Introduce an empty, per-character Bestiary that learns readable creature names,
  types, level ranges, locations and models through targeting and mouseover.
  Exclude players and player-controlled creatures; do not bundle creature/spell data.
- Provide creature-type, location, review-state, text and alphabet filters;
  readable cast and safely attributed post-combat observations become pending
  abilities. Ambiguous or restricted encounter data is excluded.
- Support manual abilities, field notes, effect tags, out-of-combat spell
  resolution and equal-level damage records, with review, rejection, removal and
  tooltip visibility controls. Confirmed abilities from locked creatures appear
  in NPC tooltips.
- Record offensive schools, resistances, immunities, disposition, combat style
  and behaviour in separate observation dialogs, alongside deduplicated kill
  tracking. Separate creature identity from color-coded combat summaries.
- Ship the parchment journal, creature model, draggable/clamped dialogs, stacked
  observation windows, selection highlights, brightness control, Help and reset.
- Rebrand ClassicBestiary to Azeroth Fieldbook, introduce `/fieldbook` commands,
  retain `/bestiary` and existing binding identifiers, and use AzerothFieldbookDB
  for per-character storage. Remove the completed legacy-name migration bridge.
- Include status, encounter scanning, debug, announcement and confirmed-wipe
  commands, normal/mouseover keybindings, user documentation, Lua 5.1 regression
  tests and the MIT license. The initial archive installs as AzerothFieldbook.
