# Classic Bestiary - Field Journal 0.5.49 (alpha)

A personal bestiary for WoW: Forever beta 1.60.1 (Interface 16001). The book starts
empty, records encountered NPCs and lets you confirm what you have learned. No
preloaded creature abilities, spell descriptions, or unknown-ability counts.

## Open the book

Enable **Classic Bestiary - Field Journal** and `/reload` after updating.
`/bestiary` or `/bestiary book` opens the parchment field guide. Assign a shortcut
in **Options > Keybindings > Other > Open / close bestiary book**. The adjacent
**Open bestiary at mouseover** binding opens directly to the eligible NPC beneath
your cursor.
No existing keybind is overwritten. Escape closes the book; drag its background
or header to move it. The window scales down to fit smaller screens.

Target or mouse over an attackable NPC to collect its readable name, creature
type, and level. Player-controlled creatures, players, pets and vehicles are
excluded. The book selects your current eligible target when opened.

The left page is an alphabetical index with search, review filtering and paging.
Creature-type buttons run down its left edge; A-Z tabs on the right edge restrict
the list to names beginning with that letter. **Index** clears the letter tab.
Filters combine, so a large journal remains quick to browse. Search matches both
name and creature type. Entries with unreadable types stay Unclassified.
Unavailable type and letter buttons remain visible but grey; active filters have
a gold outline. **Previous** and **Next** cycle through the currently filtered
creatures, wrapping at the beginning and end.

The right page shows the creature's name, type and observed minimum/maximum
levels. It requests the in-game 3D model for that already encountered creature ID;
no other IDs are searched. The illustration may be unavailable if the client does
not provide/load it. It represents the creature type, not a saved screenshot of
an individual NPC. Hold the mouse on the model to rotate it.

The **?** beside the title opens an in-game workflow guide covering encounters,
recording, review, locking, tooltips and journal navigation.

## Review and lock in

New entries and automatically discovered abilities are field notes awaiting
review. Click **Lock this entry**, then **Confirm** for each ability you accept.
Only confirmed abilities on a locked-in entry appear in creature tooltips. A
locked entry can be unlocked again, immediately hiding its abilities from tooltips.
Reject a mistaken ability to keep it out of tooltips. Its button then changes to
**Remove**, which deletes it from the visible list and prevents automatic rescans
from immediately restoring it. Adding that ability manually restores it.
Hover a confirmed ability with an accepted spell ID/link to see that spell's
standard in-game tooltip.

**Choose effects** opens a compact multi-select picker for manually observed
control, combat and dispel-type tags. It does not infer effects or inspect an
unseen spell. Selected tags appear beneath the ability name with its field note.
Scroll the ability rows to inspect longer lists.

Existing observations from previous versions are preserved and migrated to
pending review. Old encounter-only entries can initially show an NPC ID; target
or mouse over that NPC to record its readable name, type and levels.

## Manual abilities and spell links

Select the creature, type the ability you experienced (for example a trap), add
an optional effect note, and click **Confirm this ability**. This is deliberately
manual evidence, so it works even when cast information is hidden from addons.
Use the same name to edit or replace an existing note. Text fields do not accept
embedded textures/color markup as notes.

An optional field accepts a numeric spell ID, pasted in-game spell hyperlink, or
an exact spell name. **Resolve** asks the client for one exact name match and
fills its ID/link; it cannot search or list alternatives because Forever exposes
no addon-facing spell-name catalogue.
Outside combat, the addon resolves that exact spell. The name must match the
manual name (or the name field can be left empty to use the linked spell's name).
No candidate abilities are suggested or searched for the NPC. Invalid, restricted
or uncached links are rejected; retry or save the plain name without a link.
Known automatic spell IDs are retained for linking. The **Link** button loads an
existing linked ability into the editing fields. It does not send chat messages
or display potentially revealing spell descriptions.

## Equal-level damage notes

**Record equal-level hits** opens a form for observations you personally confirm.
Its level dropdown contains only the creature's observed minimum-through-maximum
range. Each submitted minimum/maximum range is retained as an individual note.
Click a level summary in the bordered damage section to inspect and remove notes;
the combined range is recalculated after every removal.

These are personal damage-taken values affected by your armor, buffs, critical
hits and other circumstances, not the creature's theoretical base damage. Forever
blocks third-party combat-log events. Its supported post-combat damage-meter API
provides totals but no individual hit ranges or critical flags, so automatic
equal-hit recording is unavailable. The form rejects reversed ranges and levels
outside the creature's observed range.

## Automatic observations

Readable casts on your visible target/mouseover still become pending ability
notes. Active casts are checked every 0.2 seconds. A readable cast name is enough
even when its ID is hidden; fully hidden data is skipped. Interrupted attempts
count. Client visibility is not proof of camera direction or gaze.

Post-combat C_DamageMeter imports include your retained participated encounters
and attacks on party members. Incoming NPC names must match one creature ID in
the SAME readable encounter enemy roster. Ambiguous names, incomplete rosters,
players and pets are skipped. Enemy Damage Taken supplies identities only: its
spell list is never treated as the NPC's own abilities. Direct NPC damage/healing
is used only if the client exposes that source in the relevant summary.

The meter is not a complete cast log. Traps, buffs, self-heals, interrupted casts
and other non-damage abilities may be absent. Manual notes cover these gaps.
The addon does not change the game's damage-meter settings or read disk logs.

## Commands, saving and diagnostics

- `/bestiary` or `/bestiary book`: open/close the book.
- `/bestiary status`: observation totals and scan status.
- `/bestiary encounters`: encounter import diagnostics.
- `/bestiary scan`: retry encounter imports outside combat.
- `/bestiary debug`: detailed API and tooltip diagnostics.
- `/bestiary alerts`: toggle local discovery messages.
- `/bestiary wipe`: start a wipe request (nothing deleted).
- `/bestiary wipe confirm`: command 2/2; erase this character's entire bestiary and settings.
- `/bestiary wipe cancel`: cancel the pending request.

The confirmation must be entered within 60 seconds of the first command.
The old `reset` and `reset confirm` commands only start this same two-step flow.

Data uses per-character `ClassicBestiaryObservedDB`, saved by the game on logout
or reload. All instances of the same NPC ID share an entry; different IDs and
characters remain separate. Clearing the meter does not clear the journal.
Wiping excludes existing meter history, including after reload, so it cannot
restore deleted observations. Retarget an NPC to begin collecting again.

Debug distinguishes confirmed SECRET values, API ERROR, API MISSING,
MISSING/INVALID data, and normal IDLE results. It does not print raw error or
unidentified spell payloads. Prior unreadable results can belong to prior targets.

## Verification

Python/lupa Lua 5.1 tests in `tests/` cover direct observations, secret handling,
encounter attribution, NPC-only filters, persistence, review/rejection, creature
types, level ranges, manual linking, damage validation, tooltip integration and
book construction/interactions using mocked native widgets. In-game rendering,
model availability and client persistence still require actual beta verification.

Original addon/concept: Urbit @ Benediction, https://github.com/icheatatlan/ClassicBestiary
Original tooltip inspiration: https://wago.io/q1YbxB5Pz
API source: https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated
