# October 2026 audit repairs

## Owner acceptance and release authorization — 8 October 2026

The owner accepted this audit and explicitly requested a version bump, commit,
and push to the Release channel. The accepted batch comprises N1–N11 and the
focused R1/T1 follow-up documented below, with its stated migration limits.
Version **0.36.4 (Release)** publishes that accumulated repair batch. This
authorization supersedes the earlier hold on versioning and publication;
the chronological evidence below retains the scope of each earlier stage.

The previous-push baseline was verified against live remote `main` before any
update: `7402ae8ba21a685c7be72097db2c41bd5482c524`. The latest published release,
`v0.36.3`, points to the same commit; no earlier unpublished batch is omitted.
The cumulative 0.36.4 changelog covers all changes since that baseline.

The final canonical gate passed **117 test files, 0 failed**, including exact
backup equality. Production code and tests are unchanged since that run;
release preparation changes only version metadata, release notes and this
acceptance record. The passing full-suite result is reused under AGENTS.md.
After the bump, all 94 Lua modules, manifest/bindings, tag/version consistency,
release-summary extraction, and the release-note, Angling alias, login-coordinate
and Lore prerelease regression files passed. `git diff --check` also passed.
Acceptance does not claim additional native-client testing or measurements.

## Original repair evidence

Baseline: version 0.36.3, commit `7402ae8ba21a685c7be72097db2c41bd5482c524`.
The checkout was clean. All eleven findings reproduced with the supplied
synthetic probes against that baseline. N10 was rechecked with the HEAD version
of LedgerBook loaded in memory after its working-copy fix had landed.
The supplied diagnostics assert defects; the new tests assert correct behavior.
No live player SavedVariables were loaded or edited.

| Finding | Resolution | Regression evidence |
| --- | --- | --- |
| N1 | Clean Ledger editors reload their saved baseline. A changed baseline blocks a dirty draft's Save without clearing the draft; Reload saved notes is an explicit discard/reload action. | `test_audit_ledger_link_stale_notes.py`: real link and Save callbacks, notes/roles, reconstruction and stale dirty drafts. Existing Ledger and section-switch draft checks remain required. |
| N2 | Annotation and report candidates use complete top-level field copies. Validation creates detached owned collections before committing; report history is not recursively copied just to edit annotations. Unknown local metadata survives. | `test_audit_lore_copy.py`: 32 rich production-created revisions beyond 20,000 tables, personal evidence at every revision, read-only preflight, duplicate receipt, capacity rejection and serialized reload. Existing report capacity/deduplication/preservation tests retained. |
| N3 | Gathering has a durable reference distinct from firstSeen. Account merges retain contributing references and timestamp-era aliases; separate account allocation prevents opt-out forks reusing identities. | Both Gathering audit regressions and `test_audit_reference_lifecycle.py`: earlier imports, both orders, legacy aliases, repeated imports, reload, opt-out and same-timestamp replacement. |
| N4 | Lore uses Angling record provenance. Migration retains old store/key composites and contributing aliases for deduplicated records; lookups reject ambiguity. | `test_audit_lore_angling_link.py` and reference lifecycle cases: colliding IDs, shared fish types in both import orders, old composites, reload, deletion and personal scope. |
| N5 | Lore discoveries receive durable references derived from their preserved export ownership. Annals scans Lore/Treasure for a unique durable target; timestamp-era Lore links require the retained original. | `test_audit_annals_remapped_links.py`: real discovery publication and secondary imports. Reference lifecycle tests add equal timestamps, conflicting IDs, legacy Lore, ambiguity, repeated imports, deletion and opt-out. |
| N6 | Incoming selection prioritizes pending offers over accepted transfers waiting for commit. Accepted consent and the transport/accounting engine are retained. | `test_audit_sharing_inbox.py`: three peers, interrupted first sender, reachable second offer, delayed first commit and duplicate acceptance without extra spending. |
| N7 | Angling details traverse the saved merge ancestry iteratively, showing each archived source once without changing archives or catch facts. | `test_audit_angling_chained_merge_notes.py`: real merge UI, longer/branching chains, cycle/deduplication protection, notes, catch totals and reconstruction. |
| N8 | Login retries fill missing fields only from a compatible map, zone and subzone. Missing positions can retry through the original expiry window; departure still cancels. | `test_audit_login_coordinates.py`: same/different/missing map, known/missing position and leaving-world cancellation; existing Annals tests retained. |
| N9 | Editing the same ability name and spell ID retains an explicitly disabled tooltip preference. A different ability identity retains normal creation behavior. | `test_audit_bestiary_edit_preference.py`: actual toggle/edit/confirm callbacks and journal reconstruction. |
| N10 | Ledger mouseover selection scrolls with the contact tops computed by the actual list layout. | `test_audit_ledger_mouseover_scroll.py`: 100 untitled, titled or mixed contacts, filter reset and visible selected row. |
| N11 | Selection changes close the damage popup. Removal validates the displayed creature table, level, index and observation object; hiding clears row ownership. | `test_audit_bestiary_damage_notes_wrong_creature.py`: row/keyboard selection, normal removal and range removal, paged notes, shifted indices, unrelated creature preservation and reconstruction. |

## Compatibility and limits

No schema/report protocol or addon version was changed. Annals remains
character-local. The previous restore, reset, Atlas entrance, model lifecycle
and report-deduplication repairs remain in scope for regression validation.

Legacy recovery requires surviving ownership evidence. A timestamp alone is
not sufficient to match an account Lore record. Previously broken links whose
original ownership cannot be established remain unavailable; historical labels
and entries are retained. These repairs cannot recover notes already erased by
the old editor or copy behavior without a prior backup.

Automated verification is synthetic Lua 5.1/UI/transport testing. The owner
confirmed that a native reload and opening the addon produced no Lua errors,
and confirmed the damage-observation popup works as intended after switching
creatures (correcting an initial report that it stayed open). Other native
rendering, message delivery and delayed map API behavior were not verified in
this session. Existing native model acceptance is not reclassified or repeated.

## Validation

The canonical `tests/run_tests.py` completed all 116 test files: 115 passed
and `test_fieldbook_backups.py` failed two cases before the corrections below.
The corrected backup file passes all 18 tests in its focused rerun. Thus all
116 files have passing results across the full run and affected reruns; this
is not a claim of a single zero-failure full run. The full runner includes all
thirteen new regression files and compiles all 94 runtime Lua modules with
Lua 5.1. Manifest, XML and installed-version consistency checks pass.

Whole-fieldbook validation exposed two cases: the Gathering backup fixture
now calls the real discovery API before exact snapshot comparisons, and
Angling's legacy Lore-alias migration is one-time so newer reported records
remain unchanged on reload. Exact backup-content assertions were retained.
After those corrections, affected reruns pass all 18 whole-fieldbook backup
tests, the backup-limits stress test, 71 Angling tests, nine account-section
tests, 25 identity-migration tests, reference lifecycle checks, the Lore/Angling
link regression and chained-merge notes regression. The final Ledger editor
layout also passes its focused regression. Final Lua compilation and
`git diff --check` pass.

The full navigation suite passes all 20 tests; Lore preservation, storage
scope, restore/reset ownership, report deduplication, Atlas and model lifecycle
checks pass in the full run. Full-run output is in
`../AFBNEWAUDIT/full-validation.log`; corrected backup results are in
`../AFBNEWAUDIT/backups-final.log` and `backup-limits-final.log`. Initial
targeted logs in `../AFBNEWAUDIT/targeted/` include superseded failures: an
Angling reload mutation and two pre-fix fixture assumptions, all corrected
and rerun successfully.

Recommended next version: **0.36.4 Release**, a corrective maintenance patch,
subject to the owner's version/release decision and native UI smoke check.
The installed version remains 0.36.3; no commit, push, tag or publication was
performed. Native startup and damage-popup selection checks passed as reported
by the owner; broader native behavior remains outside the automated evidence.

## Focused R1/T1 follow-up — 8 October 2026

Contributor navigation now uses a record-local `referenceAliases` set. Account
deduplication unions every contributor key, historical key and already-retained
local alias into that set; it no longer expands the canonical report origin.
The generic account merge is also prevented from filling the origin's array
slots with another contributor's historical keys. Aliases of the same canonical
source/key still merge as report history. The protocol and its 32-key limit are
unchanged, and genuine historical aliases still reach report reconciliation.
Lore and Annals resolve the local set through the journal's ambiguity-aware
resolver, including retained-personal opt-out and removal behavior.

Already-saved N4 lists are repaired during journal/account initialization, not
during preview or export. Retained personal catch facts link records to their
original contributor namespace; the persisted contributor token must agree with
that fact's source and namespace. For a known canonical record, aliases in a
different proven contributing namespace move into the local set. This works
after serialization without loading the other characters' personal stores and
does not rely on distinct display names. Every moved key remains locally usable.
Unknown-observer origins and unclassified aliases are left intact. In particular,
missing catch provenance is not permission to truncate a list or discard a
possible historical report identity: more than 32 remaining historical or
unclassified aliases still causes the existing bounded export rejection.

The new regression converts the supplied diagnostic's real Context/RecordCatch/
SelectSectionStorage setup into successful Build/Encode assertions at 32 and 33
contributors. It covers saved oversized N4 lists, a genuine historical alias
after position 32, equal display names, all references after serialization,
untouched personal originals, 33 catch facts/events and their quantities and
provenance, repeated imports, opt-out, ambiguity, deletion, forwarding/reimport,
unchanged preview/export evidence, and the unchanged protocol limits. A separate
case covers 33 new contributors without catches through real Lore/Annals adapters.

T1 now initializes the missing map with an explicit conditional and checks that
the initial saved event has no map or coordinates and owns the retry. The retry
fills that same event from map 102, preserves its time/sequence and completes.
All other fixture scenarios remain. No Annals tracking runtime change was needed.

Validation uses Python 3.12.14 with the repository's pinned Lupa 2.8 and Lua 5.1.
The Windows `python3` application alias could not launch, so the bundled Python
executable runs the same `-B -X utf8 tests/run_tests.py` canonical command from
the addon root. This launcher issue occurred before tests and was not an addon
failure. The initial new regression needed its own valid Lua serializer because
the harness's `snapshot()` is a comparison representation, not loadable Lua;
that fixture error was corrected before final validation.

Focused validation passed the new R1/T1 checks and seven affected files,
including 71 Angling, 25 identity-migration, nine account-section and all 18
backup tests. Exact backup equality assertions are unchanged. Logs are retained
in `../AFBAUDIT3/focused-followup.log` and the canonical logs below.

The first canonical run finished `RESULT: 117 test files, 1 failed` (exit 1),
with only `test_release_notes.py` failing because the sandbox denied writing
`notes.md` in its default temporary directory. All addon tests, all 18 backup
tests, and all 20 navigation tests passed. This is an environment/fixture I/O
failure, not an addon regression. Its complete log is
`../AFBAUDIT3/canonical-followup.log`.

Pointing process-local `TEMP`, `TMP` and `TMPDIR` at the writable
`../AFBAUDIT3/test-temp` directory made all five release-note tests pass without
changing any test or production code. The same canonical command was then run
again in full with this environment correction; its log is
`../AFBAUDIT3/canonical-followup-final.log`.
Final canonical result after all production and test changes:
`RESULT: 117 test files, 0 failed`, process exit code **0**. This single run also
passed compilation of all 94 Lua 5.1 modules, manifest, bindings XML, version
consistency, all 18 backup tests and all 20 navigation tests. No production or
test changes were made between the two canonical runs; only the temporary-file
environment was corrected. `git diff --check` also passes.

The standalone `../AFBAUDIT3/R1-T1-followup.patch` contains only this follow-up
against the repaired working tree, excluding the pre-existing N1–N11 repair
diff. It is already applied locally. No new native check, version change,
commit, tag or publication is part of this follow-up.
