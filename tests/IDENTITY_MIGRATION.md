# F1-F3 identity and migration repair, 0.17.0 unreleased

This is the coordinated implementation batch following local checkpoint
`667386507034ec9ae547f1f509c9888caa137fb4`. It does not reopen the audit.
F4/F6/F7 remain closed; F5/F8 are unchanged and reserved for the final batch.
The same-installed-version import gate, report consent, points, rewards, locks,
section ownership and one-time account-import policy are unchanged.

## Fishing (F1)

Each newly captured aggregate persists its original source and key. The context
index includes its contributor and allocation namespace. Another character's
catches use another cumulative stream; exporting an existing stream changes only
delivery attribution. Existing aggregates remain independent even when their
items, locations, dates and counts match. Waters, spots, pools and items also
retain their original captured identity rather than deriving it at export time.

The account copy uses a separate namespace for future captures, leaving imported
streams intact. A catch added later to the retained local store cannot acquire
the identity of a different catch added in account mode. Returning to account
mode does not synchronize those later local catches.

Stored origins and deterministic old store/ID remaps supply `legacyKeys`. Reports
validate these bounded alias assertions, and import reconciles compatible
cumulative evidence on a detached copy. Existing source/key lookups remain valid;
an older export through an alias cannot reduce a newer total. Independent legacy
source/key pairs are not collapsed merely because their bare keys or contents
match. A previously stored alias assertion also recognizes a later old delivery.
Conflicting, non-cumulative aliases refuse the import without changing evidence.
Original delivery/identity metadata survives canonicalization. Forwarding retains
the canonical identity. Reported catches never become personal catches or sessions.

For already-migrated account journals, the original character store can supply
deterministic aliases on that character's next load. This is an identity repair,
not a repeat of the original import. Recipient duplicates can be reconciled when
a repaired export supplies the grounded aliases; unproven stored origins are
retained independently until that evidence is available.

**Historical limit:** old personal/account aggregates did not save observers and
may already mix contributors. Their counts and original store identities survive,
but the missing names and per-contributor breakdown cannot be recovered. They are
frozen as historical streams labelled `Unknown original observer` in reports and
`original observer not recorded` in journal details. Future catches have their own
known contributor streams. No current exporter is invented as the old observer.

## Lore references to Atlas (F2)

Atlas records receive durable `reference` identities. Save/edit preserves them;
new account and local allocations have distinct namespaces. The original
`id@:creationStamp` aliases are retained. `atlasReferenceMaps[characterKey]`
records the one-time mapping between the original character reference and its
account destination, including the previously discarded migration ID mapping.
Lore records and their links are never rewritten into account-local IDs.

Account resolution applies the current character's map, then checks the actual
destination's identity. Local resolution uses the corresponding original record
or reports unavailability in that scope. Names, edits and a colliding local ID do
not substitute for identity. Deleting a destination leaves the reference missing.

For an old migration, exact surviving identities take priority. Otherwise only
legacy records in the saved `charN:` namespace (or a provable first-import owner)
with unambiguous surviving creation stamps can be mapped. The old first owner can
be recovered only when the import markers and other character namespaces establish
it. No offline character files are read. Repair markers preserve completed mapping
decisions and prevent later opt-out additions from being mistaken for imports.

**Historical limit:** a discarded ID map cannot be reconstructed when stamps have
multiple candidates, ownership is absent, the destination no longer exists, or
an old unscoped key could denote different local and account discoveries. The
reference is retained, resolution is unavailable, and `atlasReferenceIssues`
records the specific reason with a chat notice when detected. Neither a destination
nor a scope is guessed. A key whose original scope is ambiguous stays unavailable
after opting out too. The surviving local record's explicit durable identity
remains usable in local scope.

## Merchant contacts (F3)

Account reconciliation groups only exact original report identities
(`identity.origin.source` plus `identity.origin.key`). It handles both fresh imports
and duplicate contacts already in the account store. The existing indexed contact
is preferred as canonical. `reportKeys`, durable references, encounter aliases
and old contact IDs lead to that contact. Repeated load/repair does not create
duplicates, new identities or repeated note concatenations. Later report updates
use the existing report merge path on the canonical contact.

`migrationEvidence` retains full original contact snapshots, including both private
notes and their origins, annotations, conflicting personal observations, raw
reports, sender claims, received/last-received times and per-fact receipts. The
active report combines positive evidence using the existing report policies and
keeps the earliest receipt for an identical fact version. Both original delivery
records remain in the snapshots. Combined editable notes stay within 4,000 bytes;
additional originals appear in the existing details pane and remain searchable.
Snapshots and private notes are not added to outgoing reports.

If an existing report capacity prevents combining active payloads, the originals
remain in `migrationEvidence` and the contact displays the specific limit in its
ordinary details. No evidence is silently truncated to make repair succeed.
Template/NPC/name matches with distinct original reports do not merge contacts.
Explicit later identity links retain the migration evidence and aliases too.

## Verification and review boundary

`tests/test_identity_migration.py` uses the real capture, journal, account selector,
report codecs/import, Lore adapters and relevant book detail builders. Its initial
eight-test run reproduced F1 provenance, F2 migration-link and F3 canonical-contact
failures against the checkpoint; the independent-origin control passed. Both character orders
are covered for Atlas and Ledger, including existing Ledger duplicates. Extended
coverage includes legacy fishing exports, unknown observers, stale cumulative
updates, conflicting aliases, preserved receipts/long notes, active-scope identity,
missing destinations, explicit ambiguity, serialized-copy reloads and one-time
imports. The guard case triggers the real main startup callback, replaces the
blocked root with supported-looking data, and verifies the latch still prevents
all new repair entry points from writing.

Run from the repository root with the documented bundled runtime and pinned
Lupa 2.8 / Lua 5.1:

```powershell
& 'C:\Users\tysci\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -B -X utf8 tests/run_tests.py
```

The authoritative run results and SHA-256 file inventory for this implementation
are outside the addon in `../AFBAUDIT/identity-0.17.0-20260929/IMPLEMENTATION.md`,
`project-suite.log`, `tested-state.json`, `tested-hashes.json` and `final-state.json`.
Earlier logs in that directory are development iterations, not proof of later
edits. Full-suite validation includes Lua compilation, manifest, bindings and
version checks; diff whitespace and final inventory matching are recorded too.

No headless result is native acceptance. Next: a separate High-reasoning review
of this actual uncommitted diff and matching evidence, targeted corrections if
needed, then focused native acceptance. Reuse the environment identified in
`../AFBAUDIT/native-acceptance-0.17.0-20260929/ACCEPTANCE.md`; update its addon and
verify it against the reviewed tested inventory before activating any fixture.
Real-player SavedVariables and the ordinary live profile remain untouched.
