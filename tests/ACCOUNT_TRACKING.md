# Account-wide Fieldbook journals

## Individual journal scopes

Options > Data provides seven independent account-wide checkboxes. Sparse boolean
`accountTrackingSections` overrides inherit `accountWideTracking` when absent, so
existing opt-outs and default-on saves retain their behavior. These preferences
belong to each character. Annals has no account option. Choices apply on reload;
the active-store badges remain truthful when a migration is deferred.

Account identity allocation runs when any journal is shared, even with Bestiary
disabled. Disabled journals neither import nor select account data. Imports remain
one-time; switching back never copies shared data into retained character journals.
Bestiary reset preserves all scope preferences and the applied section snapshot
`accountTrackingSectionsActive`. Startup and whole-backup validation reject malformed
scope maps before migration. Whole backups retain both maps with character settings.

`test_individual_tracking.py` checks all seven journals individually against both
legacy defaults, quiet reloads, deferred changes, reset preservation and one-time
imports. The options category test covers tab visibility and independent toggles.
Native text wrapping, tab appearance and scroll fades still require an in-game check.

## Reset and unsupported-account preservation

Full reset retains only the ownership allocator in AccountDB. Cleared import
markers permit returning characters to import their retained originals once;
new arrivals allocate above every previously assigned key. Older whole backups
continue to preserve the current allocator high-water value.
Startup accepts fresh nil and supported versionless partial account roots.
Explicit future versions, scalar roots and malformed nested registries hold the
session before account imports or shared UI writes. Raw recovery export remains
available. This compatibility hardening is separate from reset identity repair.


Account-wide tracking defaults on and applies after reload to seven journal
families. Adventurer's Annals remains character-local. Bestiary retains its existing migration. AccountSections.lua selects
`.sections.gathering`, `.atlas`, `.angling`, `.ledger`, `.treasure` and `.lore` in
AzerothFieldbookAccountDB.
Each section imports once per accountTrackingKey, independently of the older
Bestiary importedCharacters marker. Original character evidence remains in
independent stores; identity repair adds metadata without erasing that evidence.
Opt-out restores these stores; later edits after
first import do not repeatedly merge. Offline character files are never read.

Merges stage a detached copy before publishing the account store and import flag.
Gathering combines counters/zones/points and notes within existing editor limits;
existing account preferences win conflicts. Atlas records and expedition links
are rekeyed, including dangling references to deleted records. Existing account
IDs and unresolved references are reserved before assigning import IDs, so a
missing destination cannot silently become another character's landmark.
Angling deduplicates water/pool/item identities, rekeys catch facts
and their references, and keeps source observations distinct. Existing bounded
history limits still apply after merging; durable totals survive. Ledger contacts
retain durable references and distinct identities when local IDs collide.
Original character stores retain conflicting or over-limit private notes.

The 0.17.0 F1-F3 repair additionally retains those Ledger originals on the
canonical account contact. Fishing captures keep original contributor identities;
Atlas references use durable identities plus scoped aliases, including a bounded
one-time repair of older migrations. New allocations in the account and local
stores have separate namespaces. See [IDENTITY_MIGRATION.md](IDENTITY_MIGRATION.md)
for repair rules, explicit historical ambiguities and regression coverage.

F8 adds Lore and Treasure through these existing per-section markers. An older
five-section save has no Lore/Treasure markers, so each imports once without
resetting Bestiary's or any earlier section's migration. No versioned global
repair or repeated import is needed. Disable selects the retained character
journal after reload; re-enable selects the existing shared journal. Neither
action copies account records down or imports later local additions.

Lore imports preserve distinct entries even when their text matches. Entry IDs,
variants, internal links and reader-state keys are remapped when joining an
existing archive. Dangling internal links are reserved. Passage/location IDs and
read flags stay intact, and the serial advances beyond both input stores so new
annotations cannot reuse imported child IDs. Each imported entry retains its
original export key and source name; newly created account entries use a separate
export origin and retain their creator's source name. The sender still identifies
the exporting character. This preserves the identity pair used by the existing
receiver. This is a mechanical identity adaptation only: F5 report deduplication, receipts,
export timestamps, snapshot semantics and capacity policies are unchanged.

Imported Atlas links keep their reference strings and an `atlasOwner` identifying
the original character's existing F2 mapping. The same resolver handles durable
references, historical account aliases and unavailable ambiguous mappings from
any viewing character. The original local link is unchanged. This adds no new
Atlas migration or reference-map store. Captures still reuse matching entries;
F4's conservative preservation remains intact. The later O3 policy archives a
valid new page even when its additional reading location exceeds the cap;
see [LORE.md](LORE.md).

Treasure imports retain individual kinds and encounters, rekeying only their
local IDs, kind links and selection state. Kind references, encounter origins,
reported evidence, receipts and private metadata are copied intact. New account
IDs carry an `account:` prefix so future account/local allocations cannot share
an encounter origin or kind reference. Lore's Treasure adapter uses those
existing durable kind references, including the older ID-prefixed reference form.

Migration copies retain raw malformed list keys and invalid record/link identities
for normal validation; remapping cannot turn them into accepted evidence. The
copies do not use or broaden `L.Copy`. Unsupported new-section roots defer migration,
and both initializers/selectors respect the latched startup guard. No saved data
is written during module loading.

Bestiary resets/legacy backups do not include or clear other section stores.
Whole-Fieldbook backups include shared and retained character roots together,
including these import registries and reference maps. See [WHOLE_BACKUPS.md](WHOLE_BACKUPS.md)
for replacement scope, counter preservation and offline-character recovery. Reports
keep section-specific provenance and confirmation rules. Bestiary display settings
and the shell remain per character; other sections' browsing preferences follow
the active store. Future unsupported schemas are preserved and migration deferred
with a chat notice. No publication or SavedVariables schema-version change is
needed for this additive account container.

The O8 summary collects section outcomes only after their existing import commits.
After initialization, one formatted chat message names actual one-time imports
and any deferred sections, states that character journals remain separate, and
explains that subsequent changes are not continuously synchronized. No record
counts are inferred. Detailed unsupported-schema warnings remain separate.
Disable confirms character scope with no account-to-character copy. Re-enable
without new imports explains that existing account journals resume and later
character-only edits are not re-imported. A newly eligible deferred section gets
its own one-time result in the next grouped summary.

The additive character setting `accountTrackingActive` remembers only the last
applied scope for messaging; existing import markers still govern all migration.
Legacy saves with completed imports establish this value silently. Bestiary
settings reset preserves it. `test_account_summaries.py` covers full-TOC startup,
fresh-namespace reload, transitions, partial/deferred imports and failed commits.

Automated checks exercise all six section migrations, repeated logins, opt-out/re-enable,
record-ID collisions, route links, fishing totals/references, contact references,
original-store preservation and future schemas. Gathering future-schema checks
exercise the real initializer and background event handlers, with account
tracking both enabled and disabled, and verify the original store stays intact.
Angling account imports preserve hover lookups redirected by explicit merges.
`test_account_lore_treasure.py` exercises production initializers, captures,
reports and reference adapters for both scopes, cross-character visibility,
old migration markers, repeated toggles, fresh Lua-session reloads, colliding
IDs, retained annotations/read state/export keys, received Treasure history,
malformed report lists and unsupported stores. Existing Bestiary tracking tests
cover account ownership and reset isolation. Native multi-character acceptance
is pending: log in on two characters, inspect all seven journals, reload, then
opt out and confirm each original journal returns. Verify map/reference views,
private notes, counts and reset isolation before using section resets.

### O7 active scope reminder (pending native acceptance)

The shared shell displays **Account-wide** or **Character-specific** at the top
right, below the title and above section controls. Hover gives one sentence about
the active store. The label compares actual selected store references, including
Bestiary's active root; it does not read a pending checkbox value or keep seven
copies of that value. The merchants tab maps to the Ledger store. A deferred
section migration truthfully displays character scope even when other sections
use the account store. No synchronization or deletion is implied.

`test_storage_scope.py` exercises all seven production sections, a shared widget,
non-mutating label/tooltip reads, pending changes, fresh-namespace reload and a
future-schema deferred Lore migration.

- [ ] In the later combined O3/O4/O8 native acceptance batch, inspect all seven
  labels and hover text at supported resolutions, UI/addon scales and text sizes.
  Check the title, right-side tabs and section buttons remain unobstructed.
- [ ] Toggle tracking without reloading: the label must retain the active scope.
  Reload to apply each direction and verify the label against the actual journal.
  Include a deferred section migration and retained character journals.
