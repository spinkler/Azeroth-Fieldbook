# Account-wide Fieldbook journals

Account-wide tracking defaults on and applies after reload to every implemented
journal. Bestiary retains its existing migration. AccountSections.lua selects
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
F4's conservative preservation and the 101st-location policy are unchanged.

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

Bestiary resets/backups do not include or clear other section stores. Reports
keep section-specific provenance and confirmation rules. Bestiary display settings
and the shell remain per character; other sections' browsing preferences follow
the active store. Future unsupported schemas are preserved and migration deferred
with a chat notice. No publication or SavedVariables schema-version change is
needed for this additive account container.

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
