# Azeroth Fieldbook 0.9.11 (Beta)

*A personal monster journal for World of Warcraft.*

Azeroth Fieldbook currently contains the **Bestiary**, a personal record of
creatures encountered by the player, with individually accepted reports from
other players. It starts empty and records only readable personal observations
or explicitly accepted shared information. It does not ship with creature or
spell databases. Version 0.9.11 includes sharing, addon-version compatibility
checks, account-wide tracking and a separate Rumours review window.

The project may later contain gathering or collection journals. Those sections
are not part of version 0.9.11.

## Installation and opening

Install the addon as `Interface/AddOns/AzerothFieldbook` and enable
**Azeroth Fieldbook** in the addon list.

- `/fieldbook` or `/fieldbook book` opens the Bestiary.
- The minimap button opens or closes the journal; its visibility is optional.
- `/bestiary` remains available as a compatibility alias.
- The two keybindings open the Bestiary normally or directly at the creature
  beneath the mouse pointer.

No existing keybinding is overwritten. Escape closes the primary and secondary
windows. The book and its dialogs can be dragged and are clamped to the screen.

The gold cog immediately left of **?** opens **Options**, containing all settings
and **Reset Bestiary**. **?** opens instructions and About. Both buttons toggle
their page and close the other page when switching between Help and Options.
Both pages share the last top-left position, so dragging either page also sets
where the other opens.

## Bestiary

**Account-wide tracking** is enabled by default in Options. It shares the Bestiary
across characters while keeping display preferences per character. Turning it off
uses the current character's separate journal. Changes apply after `/reload`.

Each character's existing journal is merged into the account journal once, the
first time that character loads with account tracking enabled. Creature records,
kills, discoveries and earned/spent points combine; repeat logins do not import
them again. Abilities, traits, locations, damage records and rumours are combined.
Notes combine within the existing editor limits; existing account decisions win
conflicts. Original character journals retain all their data, including conflicting
notes and spell IDs beyond the ten-ID limit. Switching modes after the first import
keeps the two journals independent. Sharing transactions remain owned by the
character that started them, using the active journal's point balance.

Target or mouse over an attackable NPC to record its readable name, creature
type, level range, location and model. Players, pets, vehicles and
player-controlled creatures are excluded.

The index supports creature-type, location, rank, review-state, text and A-Z filters.
The **Index** button starts red with the letters hidden and no letter filter.
Click it to highlight the button and reveal all 26 letter buttons. Click it again
to hide the letters and clear the letter filter, restoring the full creature list
within any other active filters.
Filters combine. Totems, gas clouds and entries with unreadable or unspecified
creature types share the **Other** filter.

Each creature entry can contain:

- Confirmed and pending observed abilities, optional field notes and effect tags.
- Optional exact spell IDs, hyperlinks or names resolved through the client.
- Personal equal-level damage observations.
- Observed offensive spell schools, resistances and immunities.
- Observed disposition, combat style and behavioural traits.
- A deduplicated kill counter requiring player/pet/party kill evidence and
  readable eligibility for the same observed creature GUID. Inspecting another
  player's corpse grants no kill credit; XP and actual loot drops are not required.

Magic schools are color-coded in the creature summary. Creature observations
remain manual where the client does not expose reliable addon-readable evidence.

Only confirmed abilities from a locked creature entry appear in NPC tooltips.
Locking freezes the creature's recorded abilities, traits, damage observations,
and metadata. Kill and discovery-point progress continue while locked. Unlock to resume recording.
Personal ID Logs and Notes remain editable while locked.

Delete removes the selected creature and its saved records after you type
`delete` and press Enter. Future encounters can record it again. Previously
credited milestones and spending survive deletion, so deleting and rediscovering
an entry cannot repeatedly earn its points. Ability effects include
school-specific resistance and immunity tags.

Each personal creature discovery awards 1 point, including its initial level and zone. Later
sightings revealing a new level, zone, or both award 1 discovery point per sighting.
Repeat sightings award nothing. Two kills award 1 additional point (silver);
25 kills award 2 more (gold), for 3 kill points total. Already-earned kill points
remain credited when thresholds change and cannot be earned twice. Existing
entries retain their previous legitimate total through a one-time migration,
including saved discovery progress and legacy recorded level endpoints. The
book shows lifetime **earned** points. Sharing shows **available** points:
earned minus spending and active reservations. Spending never removes kills,
stars or discovery progress.

## Sharing and Rumours (development)

Select a creature, press **Share**, enter one recipient's **full character name**
(including their surname if they have one), and select any existing traits you
want to share from the two-column list. Each selected rumour costs one additional
point; there is no two-rumour selection cap. Names are realm-free; no realm is required or
appended. Spaces, localized letters, apostrophes and hyphens in names are preserved.
The composer captures the creature when opened; changing targets or book pages
does not change the report. Both players need this compatible development build
and must be outside combat and chat restrictions. Both players must have the
**same installed addon version**. Sharing protocol 3 exchanges the TOC version
before offering a report and when retrying a paid transaction. A version mismatch
shows both version numbers when available, sends no report data and spends no
points on a new offer; older unsupported builds can time out without spending.
Native delivery to a recipient with a surname, acknowledgement,
and separate attributed imports were confirmed in game under the earlier pricing.
The new pricing and larger selections have automated coverage; remaining live checks are listed in
[tests/SHARING.md](tests/SHARING.md).

**Send offer** enables when a valid creature report is captured, enough points
are available, no outgoing report is pending or unresolved, and addon messaging
is ready outside combat and chat restrictions. The status text identifies the
current blocker. Character identity and messaging registration are retried at
login and when returning to the world or leaving combat. Recipient spelling,
self-sharing and receiver compatibility are checked when sending.

| Report | Sender cost |
| --- | ---: |
| Name, NPC ID, creature type, recorded levels and locations | 1 point |
| Those basics plus one unverified rumour | 2 points |
| Those basics plus two unverified rumours | 3 points |
| Those basics plus three unverified rumours | 4 points |

Total cost is **1 point for basic information + 1 point per selected rumour**.
Selecting more rumours immediately updates the total and resulting balance;
insufficient available points disable sending.

Individual pending or confirmed ability names (including manual abilities),
offensive schools, school resistances/immunities and behaviours are selectable.
An ability selection says only that the creature casts that named ability;
its private note and effect tags are excluded. Names containing sentence
separators are not selectable. ID Logs, personal Notes, damage, kills, stars,
locks and confirmations are never sent. Unverified received rumours cannot be forwarded. Once you explicitly verify a
claim, its personal journal record is eligible for sharing like your other records.
A spell ID identifies a spell; it is not proof that this creature casts it.

Opening, previewing and cancelling the composer are free. **Send offer** reserves
the cost. An unavailable or incompatible receiver, decline, cancellation, or
timeout **before commit** releases that reservation. After the recipient accepts,
the sender commits the cost before authorizing import. A receipt acknowledgement
completes the report; an API success alone does not. A missing acknowledgement
leaves delivery **unknown**, with the points still spent. Reopen Share and use
**Retry status**: the same transaction can be reconciled at most three times
within 24 hours, without a second charge. After that it can be closed as
unresolved, with no refund. A new report is a new paid transaction.

Recipients see the sender, creature, claims, conflicts and whether the report
adds information before choosing **Accept — free** or **Decline**. Acceptance
alone does not import: the sender must subsequently commit. Shared basic reports
are stored separately from personal records and marked in the book. Local names
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

Receiving and rumour edits award **zero** points. A later genuine encounter can
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

The ? menu includes UI scale (50–150%, default 100%), applied when the slider
is released. Offenses, Defenses and Behaviour share a position and replace
one another by default; disable that option to keep multiple windows open.
Point award chat messages are enabled by default and can be disabled.

## Spell IDs and personal notes

The target cast bar can display **Last Spell ID**. It remains for up to one
minute, clearing when the target changes, another cast starts, or you right-click
it. **Display Cast IDs** is enabled by default in the book's ? menu.

A separate movable **Last observed spell IDs** window shows the latest enemy
cast, identifiable instant cast, debuff on you and buff on a non-player-controlled
NPC target. It starts enabled and unlocked with 35% background opacity. Entries
expire after two minutes unless **Display Spell IDs in the ID window indefinitely**
is enabled. Aura effect types are shown when available.

**Retain hovered aura tooltips** keeps a compact historical snapshot of accessible
buff/debuff tooltips after hovering. Right-click to dismiss it; durations are
historical text, not a countdown. This option is enabled by default and shares
the ID window's expiry setting. Combat restrictions can block enemy aura queries
or protected native tooltips, so not every buff or instant ability can be shown.
Displayable secret values are passed directly to UI text; they are not inspected
or saved as observations.

Use **Creature Notes** beside the selected creature's name, or `/fieldbook notes`,
to open its **ID Logs and Notes**. Enter up to ten spell IDs to create spell links;
remove rows with the red x. Each creature also has a 400-character personal notes
box. These records persist per creature and do not automatically confirm abilities.
The aura spell-ID tooltip option also controls IDs appended to these spell links.
Creature notes follow eligible target selections by default, without opening
a closed window or changing the selected Bestiary page. Disable this in Options
to follow only manual selections. Pin prevents Close and Escape from dismissing
the notes window.

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Automatic observations

Readable target or mouseover casts become pending field notes. Supported
post-combat damage-meter records may also contribute abilities when an NPC can be
attributed safely within the same encounter. Ambiguous, incomplete, secret or
unreadable records fail closed.

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

Version 0.9.11 stores account progress in `AzerothFieldbookAccountDB` and character
settings and separate character progress in `AzerothFieldbookDB`. Each database
keeps its journal in `bestiary`. Reset clears only the active journal and current
character's settings, preserving the tracking mode and one-time migration markers.

The previous binding action IDs remain registered behind the newly branded
binding labels, preserving assigned keys across the rename.

## Verification

Python/lupa Lua 5.1 tests in `tests/` cover observation boundaries, persistence,
legacy migration, encounter attribution, filters, manual notes, damage records,
creature traits, kill counting, tooltips and mocked native UI construction.
Account-tracking tests cover migration, replay protection, separate character
journals, shared event recording, point balances, transfer ownership and resets.
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
