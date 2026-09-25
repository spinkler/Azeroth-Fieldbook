# Azeroth Fieldbook 0.9.99 (Beta)

*A personal monster journal for World of Warcraft.*

Azeroth Fieldbook currently contains the **Bestiary**, a personal record of
creatures encountered by the player, with individually accepted reports from
other players. It starts empty and records only readable personal observations
or explicitly accepted shared information. It does not ship with creature or
spell databases. Version 0.9.99 includes sharing, addon-version compatibility
checks, account-wide tracking and a separate Rumours review window.

The project may later contain gathering or collection journals. Those sections
are not part of version 0.9.99.

## Installation and opening

Options → Tracking includes **Auto-lock after X kills without changes**, enabled
by default at 10. Only credited kills count. Recorded-information changes and manual
unlocking restart the count; repeated sightings do not. Progress persists across
sessions, and automatic locking does not confirm pending abilities. Existing kills
are not counted retroactively. Automatic locks appear in the Event log.

**Lock newly encountered critters** is also on by default under Tracking. It
records their first basic information, then locks the page. Turn it off to start
new critter pages unlocked. Existing pages and manual unlocks are respected;
shared-only pages stay available for review until a personal encounter.

Install the addon as `Interface/AddOns/AzerothFieldbook` and enable
**Azeroth Fieldbook** in the addon list.

- `/fieldbook` or `/fieldbook book` opens the Bestiary.
- The minimap button opens or closes the journal; its visibility is optional.
- `/bestiary` remains available as a compatibility alias.
- The two keybindings open the Bestiary normally or directly at the creature
  beneath the mouse pointer.

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

The list button left of Options opens the **Event log**. It records timestamped discoveries, knowledge awards, observed-cast alerts and sharing activity even with chat announcements disabled. This per-character history starts on first use, survives reloads and Bestiary resets, and keeps all events with newest-first pages of 50. Earlier events cannot be reconstructed. Transfer entries record the other character, creature, rumour count, Knowledge cost and outcome, including retries and failed delivery.

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

**Account-wide tracking** is enabled by default in Options. It shares the Bestiary
across characters while keeping display preferences per character. Turning it off
uses the current character's separate journal. Changes apply after `/reload`.

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
- A deduplicated kill counter requiring player/pet/party kill evidence and
  readable eligibility for the same observed creature GUID. Inspecting another
  player's corpse grants no kill credit; XP and actual loot drops are not required.

Magic schools are color-coded in the creature summary. Creature observations
remain manual where the client does not expose reliable addon-readable evidence.

Only confirmed abilities from a locked creature entry appear in NPC tooltips.
Locking freezes the creature's recorded abilities, traits, damage observations,
and metadata. Knowledge from kills and discoveries continues while locked. Unlock to resume recording.
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
school-specific resistance and immunity tags.

Each personal creature discovery awards 1 knowledge, including its initial zone.
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

## Sharing and Rumours (development)

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
offensive schools, school resistances/immunities and behaviours are selectable.
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
remembered for the session; unknown classes stay grey, as does the Shared by
label. Received reports never supply class identity. Local names
and creature types win conflicts. A locked page retains its displayed basics;
additional reports remain available in Rumours and after unlocking.

Click **Rumours** between the kill counter and **Creature Notes** to open a
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
normal entry-lock and tooltip rules; accepting a report alone establishes no traits.

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

Use **Creature Notes** beside the selected creature's name, or `/fieldbook notes`,
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
- `/fieldbook debug`: show diagnostics in chat and a selectable copy window.
- `/fieldbook debug on|off`: enable or disable additional diagnostics.
- `/fieldbook alerts`: toggle local discovery messages.
- `/fieldbook wipe`: begin the destructive reset confirmation.
- `/fieldbook wipe confirm`: erase the active account or character Bestiary and
  the current character's settings within
  60 seconds of the first command.
- `/fieldbook wipe cancel`: cancel the pending reset.

The legacy `/bestiary` command accepts the same arguments.

## Data compatibility

Version 0.9.99 stores account progress in `AzerothFieldbookAccountDB` and character
settings and separate character progress in `AzerothFieldbookDB`. Each database
keeps its journal in `bestiary`. Reset clears only the active journal and current
character's settings, preserving the tracking mode, one-time migration markers,
Event log and backups. Backup archives live alongside `bestiary` in the active
database, so account and character backups remain separate.

The previous binding action IDs remain registered behind the newly branded
binding labels, preserving assigned keys across the rename.

## Verification

Python/lupa Lua 5.1 tests in `tests/` cover observation boundaries, persistence,
legacy migration, encounter attribution, filters, manual notes, damage records,
creature traits, kill counting, tooltips and mocked native UI construction.
Account-tracking tests cover migration, replay protection, separate character
journals, shared event recording, knowledge balances, transfer ownership and resets.
Backup tests cover literal export/import, Unicode notes, malformed data, snapshot
isolation, retention, reset/reload recovery, tracking scopes, knowledge continuity,
live transfers and the preview/confirmation UI workflow.
Sharing adds simulated two-client protocol tests, enum/error handling, migration,
credit preservation, import isolation, malformed reports, consent, retries and
rumour verification, manual matching, rejection history and mocked window interactions. In-game rendering, real Forever WHISPER
restrictions and cross-client persistence still require live verification; see
[the research notes and acceptance test](tests/SHARING.md). Live persistence and
reload/reconnect checks are currently blocked by an operator-reported WoW Forever
persistence bug. The successful in-session sharing results remain confirmed.

## About

Created by Spinkler

Developed with AI-assisted coding tools.
Design, direction, testing and final development decisions by the author.
