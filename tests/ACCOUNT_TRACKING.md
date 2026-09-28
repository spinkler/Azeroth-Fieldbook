# Account-wide Fieldbook journals

Account-wide tracking defaults on and applies after reload to every implemented
journal. Bestiary retains its existing migration. AccountSections.lua selects
`.sections.gathering`, `.atlas`, `.angling` and `.ledger` in AzerothFieldbookAccountDB.
Each section imports once per accountTrackingKey, independently of the older
Bestiary importedCharacters marker. Original character databases are not aliased,
rewritten or erased. Opt-out restores these independent stores; later edits after
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

Bestiary resets/backups do not include or clear other section stores. Reports
keep section-specific provenance and confirmation rules. Bestiary display settings
and the shell remain per character; other sections' browsing preferences follow
the active store. Future unsupported schemas are preserved and migration deferred
with a chat notice. No publication or SavedVariables schema-version change is
needed for this additive account container.

Automated checks exercise all four migrations, repeated logins, opt-out/re-enable,
record-ID collisions, route links, fishing totals/references, contact references,
original-store preservation and future schemas. Gathering future-schema checks
exercise the real initializer and background event handlers, with account
tracking both enabled and disabled, and verify the original store stays intact.
Angling account imports preserve hover lookups redirected by explicit merges.
Existing Bestiary tracking tests
cover account ownership and reset isolation. Native multi-character acceptance
is pending: log in on two characters, inspect all five journals, reload, then
opt out and confirm each original journal returns. Verify map/reference views,
private notes, counts and reset isolation before using section resets.
