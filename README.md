# Azeroth Fieldbook 0.7.1 (alpha)

*A personal monster journal for World of Warcraft.*

Azeroth Fieldbook currently contains the **Bestiary**, a personal record of
creatures encountered by the player. It starts empty and records only readable
information from the player's own encounters. It does not ship with creature or
spell databases.

The project may later contain gathering or collection journals. Those sections
are not part of version 0.7.1.

## Installation and opening

Install the addon as `Interface/AddOns/AzerothFieldbook` and enable
**Azeroth Fieldbook** in the addon list.

- `/fieldbook` or `/fieldbook book` opens the Bestiary.
- `/bestiary` remains available as a compatibility alias.
- The two keybindings open the Bestiary normally or directly at the creature
  beneath the mouse pointer.

No existing keybinding is overwritten. Escape closes the primary and secondary
windows. The book and its dialogs can be dragged and are clamped to the screen.

## Bestiary

Target or mouse over an attackable NPC to record its readable name, creature
type, level range, location and model. Players, pets, vehicles and
player-controlled creatures are excluded.

The index supports creature-type, location, review-state, text and A-Z filters.
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
- `/fieldbook debug`: show API and tooltip diagnostics.
- `/fieldbook alerts`: toggle local discovery messages.
- `/fieldbook wipe`: begin the destructive reset confirmation.
- `/fieldbook wipe confirm`: erase this character's Bestiary and settings within
  60 seconds of the first command.
- `/fieldbook wipe cancel`: cancel the pending reset.

The legacy `/bestiary` command accepts the same arguments.

## Data compatibility

Version 0.7.1 stores per-character data in `AzerothFieldbookDB`, with monster
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
