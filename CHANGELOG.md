# Changelog

## v0.9.6-beta - 2026-09-25

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

## v0.8.3-beta - 2026-09-25

- Made the minimap button draggable around the minimap perimeter, with a saved
  position and Shift-click lock toggle. Starts unlocked; dragging does not open the book.
- Made Choose effects, Offenses, Defenses, Behaviour, Locations and Ranks toggle
  their windows; observation windows still respect the single-window option.
- Renamed Record equal-level hits to Record damage taken.
- Added optional Spell ID window auto-fade when all observation rows are empty.
  New data restores it immediately; faded windows do not intercept mouse input.

## v0.8.2-beta - 2026-09-24

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

## v0.8.1-beta - 2026-09-24

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

## v0.8.0-beta - 2026-09-24

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

### Client limitations

- WoW Forever combat restrictions can prevent enemy aura queries and access to
  protected native aura tooltips. Hover retention works only for accessible
  tooltips; instant abilities require an observable event or aura.
- Displayable secret text is not inspected or converted into saved observations.
  Snapshot durations are historical and do not count down.
- The journal still starts empty. Unnamed Encountered creature entries can come
  from prior automatic observations; no creature entries are bundled as defaults.
