# Changelog

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

## v0.9.98 - Unreleased

- Show the selected-filter yellow border on Rumours, Creature Notes, Record
  damage taken, Offenses, Defenses, Behaviour, Choose effects, Locations, Ranks
  and Share while their windows are open. Keep their existing actions and text
  styling; clear the border whenever the corresponding window closes.
- Move the Creature level dropdown another 1px down and 2px left.

## v0.9.97 - Unreleased

- Restore the Pending toggle’s native red face, with grey text when off and
  yellow border and text when on.
- Lower the Search placeholder by 1px and the Creature level dropdown by
  another 3px. Move Shared by 1px down and 1px left inside the viewer.

## v0.9.96 - Unreleased

- Lower the viewer’s Shared by attribution by 2px.
- Keep the Pending filter label fixed on an enabled grey button; use the common
  yellow border and text to show when the filter is active.
- Move the damage observation Creature level dropdown 3px left and 3px down.

## v0.9.95 - Unreleased

- Limit yellow selection styling to the native button bevel and text, keeping
  the original red face unchanged.
- Place Shared by inside the creature viewer at the bottom left; hide it after
  a personal encounter while retaining source history in Rumours.
- Prefer bottom-aligned docking on the main window’s right edge for Offenses,
  Defenses and Behaviour, preserving overlap avoidance, pinned positions and
  screen containment.

## v0.9.94 - Unreleased

- Brighten selected filters with pure-yellow additive colour on the native
  button artwork; restore normal blending when deselected. No separate outline.
- Align Shared by with the creature viewer's left edge and use the available
  width beneath the panels. Put the missing-illustration caption inside the
  viewer so the two labels cannot overlap.
- Keep Locations and reduce filter-button fonts by 1pt in every state, including
  category, alphabet, Index, Locations, Ranks and Pending controls.

## v0.9.93 - Unreleased

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

## v0.9.92 - Unreleased

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

## v0.9.91 - Unreleased

- Make the main creature page's Shared by attribution grey, matching the
  understated list legend.

## v0.9.90 - Unreleased

- Replace the glowing filter selection outlines with one crisp yellow border
  and yellow text. Unselected filters keep their red button and use grey text;
  unavailable filters retain their disabled appearance. Apply this consistently
  to creature types, alphabet tabs and the Index/Locations/Ranks controls.
- Remove the filter hover glow so it cannot obscure the selected border or turn
  unselected text yellow. Native pressed-button feedback remains available.

## v0.9.89 - Unreleased

- Put the green verify tick first on the left of each rumour, followed by the
  reject cross and then the text, with consistent gaps and divider padding.
- Fit the Rumours window width to its creature name and report text, retaining a
  comfortable minimum, a capped width for long lines, and room for its scrollbar.
  Recalculate wrapping and height as content changes; keep four rumours visible
  before scrolling when screen space permits.
- Check control order, text bounds, wrapping and shrinking after long content in
  the Rumours UI regression checks.

## v0.9.88 - Unreleased

- Lower creature-list names by another 1px, keeping their review asterisks aligned.

## v0.9.87 - Unreleased

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

## v0.9.86 - Unreleased

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

## v0.9.85 - Unreleased

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


## v0.9.84 - Unreleased

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


## v0.9.83 - Unreleased

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

## v0.9.81 - Unreleased

- Shift+left-click the unlocked Spell ID window to hide it; re-enable it with Display Spell ID window in Options. Update its hint to grey “Drag to move / Shift+Click to hide”.

## v0.9.80 - Unreleased

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


## v0.9.78 - Unreleased

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

## v0.9.77 - Unreleased

- Add Heal immediately above Heal over Time in the ability effects list. Move the
  following sections down and extend the window to retain their existing spacing.

## v0.9.76 - Unreleased

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

## v0.9.75 - Unreleased

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

## v0.9.73 - Unreleased

- Replace the manual Tameable behaviour with game-observed status and a portrait
  badge whose tooltip reads "Tameable". Read explicit Tameable/Cannot be Tamed
  lines through C_TooltipInfo.GetUnit for target/mouseover; do not infer from family,
  missing data, API errors or restricted values. Detection currently supports
  English clients and requires the game to reveal the information (e.g. Beast Lore).
- Preserve status across reloads/account merges and allow game observations on
  locked entries. Old manual flags remain stored but cannot establish the badge
  or be newly shared as behaviour rumours. Remove the manual checkbox.

## v0.9.72 - Unreleased

- Add Tameable to Behaviour's observed Traits and the creature summary. Record it
  manually after personal verification; unchecked means unknown/unrecorded, not
  untameable. Preserve it across reloads and respect creature locking.
- Allow Tameable to be shared and verified through the existing behaviour-rumour
  flow and pricing. No automatic detection or bundled tameability database is added.

## v0.9.71 - Unreleased

- Lower Help, Options and Event log title text by one additional UI pixel.

## v0.9.70 - Unreleased

- Lower the Help, Options and Event log title text by 2 UI pixels within the
  existing title bars, leaving the bars, borders and buttons in place.

## v0.9.69 - Unreleased

- Raise Help, Options and Event log title bars by another 1 UI pixel, retaining
  their height and the border-over-title layering.

## v0.9.68 - Unreleased

- Raise the top content fade in Help, Options and Event log by 1 UI pixel and
  adjust its parchment sampling to match the new position.

## v0.9.67 - Unreleased

- Raise Help, Options and Event log title bars by 1 UI pixel. Layer window borders
  over the title bars for clean edge overlaps, keeping close buttons above both.

## v0.9.66 - Unreleased

- Give Help, Options and Event log dark native-trim title bars with centered yellow
  titles matching the main book. Keep title bars above fades and below close buttons,
  with scrollbar arrows directly beneath the close buttons and content below the trim.
- Update Event log content sizing for the smaller title area while preserving its
  compact minimum, maximum height and scrolling behavior.

## v0.9.65 - Unreleased

- Reduce Options category headings by 2 points, retaining their yellow styling.

## v0.9.64 - Unreleased

- Organize Options into Tracking, Chat notifications, Appearance, Window behavior,
  Sharing, Tooltips and cast IDs, and Spell ID window sections. Use consistent
  yellow headings and section spacing, keeping existing controls and behavior.
- Clarify that chat settings do not disable Event log collection and retain the
  fixed Reset Bestiary footer outside the scrolling settings.

## v0.9.63 - Unreleased

- Refresh the hovered Reject/Remove tooltip as its action changes, using native
  tooltip ownership during the normal UI refresh. Hide it when removing the ability.

## v0.9.62 - Unreleased

- Fix corrupted Reject artwork by using the unmodified native yellow close-button
  cross instead of cropping and tinting its texture. Keep the centered yellow dash
  for Remove and preserve button alignment.

## v0.9.61 - Unreleased

- Add padding below ability-row dividers and increase row spacing while retaining
  four visible abilities and their notes. Keep the first ability in place.
- Give the ability scrollbar a dark themed track and border, extending it to
  match the revised row layout. The track hides with the inactive scrollbar.

## v0.9.60 - Unreleased

- Replace the Remove text hyphen with a centered, thick yellow dash. Use the
  native close-button cross artwork tinted red for Reject, retaining the frame colors.

## v0.9.59 - Unreleased

- Raise the confirmation tick by 1 UI pixel, keeping the Reject/Remove square
  aligned with it and preserving Edit/Resolve positions.

## v0.9.58 - Unreleased

- Replace Reject/Remove with a themed square button aligned with the confirmation
  tick. Show a red X for Reject or a yellow minus for Remove, with matching action
  tooltips. Preserve the existing reject/remove behavior and locked-entry hiding.

## v0.9.57 - Unreleased

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

## v0.9.55 - Unreleased

- Size Event log height to its content, starting at a compact 200 UI units and
  growing to the existing 767-unit maximum before scrolling. Keep footer controls
  at the bottom, hide unnecessary pagination and recheck screen placement on growth.

## v0.9.54 - Unreleased

- Add a fourth themed title-bar button beside Options for a persistent Event log.
  Capture creature discoveries, point awards and observed-cast alerts regardless
  of their chat settings, retaining timestamps, colored messages and event details.
- Keep per-character history from first use across reloads, sessions and Bestiary
  resets, without trimming old events or fabricating pre-installation history.
  Display newest-first pages of 50 events with live updates, themed scrolling,
  saved position, scaling, Escape dismissal and normal window placement.
- Verify muted-event collection, discovery deduplication, reload/reset retention,
  the title-button toggle, live updates and access to older pages.

## v0.9.53 - Unreleased

- Restrict ability spell tooltips to the text area left of the first visible
  action button. Leaving that area hides the tooltip; button gaps no longer
  trigger it. Preserve checkbox/button hints and mouse-wheel scrolling.

## v0.9.52 - Unreleased

- Preserve the themed square border on confirmed/locked ability tick buttons by
  deriving disabled artwork from the client's normal button texture or atlas,
  desaturating the frame while retaining the green tick.

## v0.9.51 - Unreleased

- Right-align Recorded Abilities action buttons as a group, with the tick at the
  content's right edge and consistent gaps between buttons. Reserve room when
  the ability scrollbar is visible so it cannot overlap the tick.

## v0.9.50 - Unreleased

- Rename the main damage panel to "Damage taken" and the entry form to "Your
  damage observations". Keep the observed-creature-level dropdown and add an
  editable Player level field that defaults to the current level on opening.
- Recommend equal-level observations while allowing different levels. Store both
  levels on each observation and show player levels in the summary and history.
  Preserve older observations as equal-level records; validate positive integer
  levels and retain the existing damage-range and creature-level checks.
- Cover unequal-level persistence, legacy records and invalid player levels.

## v0.9.49 - Unreleased

- Replace Recorded Abilities' Confirm button with a square green-tick button
  using the close/help/options theme, positioned after Reject on the right.
  Pending, unlocked abilities use a clickable red button; confirmed abilities
  and locked entries use a disabled grey button while keeping the tick green.

## v0.9.48 - Unreleased

- Add the default-on "Always attempt to anchor to main window" option. Observation
  and effect panels prefer the book's right edge, then the next window's right;
  filters prefer the book's left, then bottom, then a neighbouring window's left;
  Help and Options prefer the book's right, then left before general placement.
- Recheck anchoring when reopening unpinned dialogs, including saved positions.
  Turning the option off retains the previous overlap-only placement behavior.
  Preserve screen bounds, pinning and overlap fallback when screen space is scarce.
- Test directional fallbacks, default/saved option state, pinning and crowded screens.

## v0.9.47 - Unreleased

- Prefer a free main-book edge when positioning overlapping dialogs opened from
  the Fieldbook, even if an unrelated window offers a nearer edge. Fall back to
  other windows when the book's edges are blocked or off-screen; retain pinning
  and screen-visibility priority.

## v0.9.46 - Unreleased

- Make the Creature Notes button toggle its window open and closed. Pinned Notes
  remain open, and reopening displays the selected creature's saved notes.

## v0.9.45 - Unreleased

- Trim 30 UI units of empty space below the Offenses buttons and narrow Behaviour
  by 40 UI units, keeping its labels inside the reduced right margin.
- Narrow the equal-level damage observation window by 36 UI units so its control
  row has matching 28-unit left and right margins; resize heading/instruction text.

## v0.9.44 - Unreleased

- Arrange every opening addon window, including the main book and spell-ID
  displays, around all other visible addon windows. Evaluate neighbouring edges
  together to avoid fixing one overlap by creating another.
- Respect pinned Creature Notes and the locked spell-ID window, treating them
  as obstacles without automatically moving them aside. Screen bounds still take
  priority, and crowded layouts use the smallest available overlap.
- Keep already-visible windows in place when moving their anchor window; cover
  multiple neighbours, hidden/faded windows, pins and main-window opening in tests.

## v0.9.43 - Unreleased

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
