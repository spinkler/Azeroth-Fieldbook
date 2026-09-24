# Azeroth Fieldbook 0.8.3 (Beta)

*A personal monster journal for World of Warcraft.*

Azeroth Fieldbook currently contains the **Bestiary**, a personal record of
creatures encountered by the player. It starts empty and records only readable
information from the player's own encounters. It does not ship with creature or
spell databases.

The project may later contain gathering or collection journals. Those sections
are not part of version 0.8.3.

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

## Bestiary

Target or mouse over an attackable NPC to record its readable name, creature
type, level range, location and model. Players, pets, vehicles and
player-controlled creatures are excluded.

The index supports creature-type, location, rank, review-state, text and A-Z filters.
Filters combine. Entries with unreadable or unspecified creature types share the
**Unclassified** filter.

Each creature entry can contain:

- Confirmed and pending observed abilities, optional field notes and effect tags.
- Optional exact spell IDs, hyperlinks or names resolved through the client.
- Personal equal-level damage observations.
- Observed offensive spell schools, resistances and immunities.
- Observed disposition, combat style and behavioural traits.
- A deduplicated kill counter for deaths observed on the target or mouseover.

Magic schools are color-coded in the creature summary. Creature observations
remain manual where the client does not expose reliable addon-readable evidence.

Only confirmed abilities from a locked creature entry appear in NPC tooltips.
Locking freezes the creature's recorded abilities, traits, damage observations,
and metadata. Kill and discovery-point progress continue while locked. Unlock to resume recording.
Personal ID Logs and Notes remain editable while locked.

Delete removes the selected creature and its saved records after you type
`delete` and press Enter. Future encounters can record it again. Share is a
disabled placeholder. Ability effects include school-specific resistance and
immunity tags.

Each creature entry awards 1 point, including its initial level and zone. Later
sightings revealing a new level, zone, or both award 1 discovery point per sighting.
Repeat sightings award nothing. For testing, one kill awards 1 additional
point (silver); two kills award 2 more (gold), for 3 kill points total. Existing
entries receive discovery credit for saved zones and recorded level endpoints.

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
- `/fieldbook wipe confirm`: erase this character's Bestiary and settings within
  60 seconds of the first command.
- `/fieldbook wipe cancel`: cancel the pending reset.

The legacy `/bestiary` command accepts the same arguments.

## Data compatibility

Version 0.8.3 stores per-character data in `AzerothFieldbookDB`, with monster
journal data under its `bestiary` section.

The previous binding action IDs remain registered behind the newly branded
binding labels, preserving assigned keys across the rename.

## Verification

Python/lupa Lua 5.1 tests in `tests/` cover observation boundaries, persistence,
legacy migration, encounter attribution, filters, manual notes, damage records,
creature traits, kill counting, tooltips and mocked native UI construction.
In-game rendering and client persistence still require live verification.

## About

Created by Spinkler

Developed with AI-assisted coding tools.
Design, direction, testing and final development decisions by the author.
