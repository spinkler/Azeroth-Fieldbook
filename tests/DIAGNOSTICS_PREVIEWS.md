# O2 / O6 / O7 bounded implementation review

This batch extends the accepted O3/O4/O8 and F1-F8 behavior without changing
SavedVariables or report schemas, exact addon-version matching, provenance,
merge precedence, deduplication, or atomic import guarantees.

## Capacity selection (O2)

Lore is the proactive display added in this batch: arbitrary source text and
reported revisions can consume its 32 MiB archive during long-term preservation,
and its 2,000 entry slots independently block new entries. The display and tooltip
reuse current accounting rather than estimating serialized memory. The 4 MiB
work limit is explained on hover, without another per-entry display.

Other limits were inspected but intentionally receive no capacity dashboard:

- Ledger's 2,000 contacts and Treasure's 2,000 kinds already have visible journal
  counts. Treasure's 20,000 encounters have explicit preservation/capacity errors.
  These are plausible very-long-term limits, but this batch prioritizes Lore's
  less-visible, highly variable byte usage rather than adding parallel counters.
- Angling's 4,096 reported summaries / 8,192 claims and Ledger's 512 report
  sources / 16 sources per contact are checked before accepting in the new
  preflight. Bestiary already reports rumour/basic/shared-entry saturation.
  Exact source/index-slot constants remain developer details, not standing UI.
- Lore's 32 evidence revisions per entry are checked by preflight. Per-page,
  page-count, passage, location and link bounds retain contextual failures;
  capture continues to preserve valid pages when only an extra location is full.
- Report byte/record/parser bounds, map/location correlation budgets, rolling
  sighting history and rendering/page limits are safeguards or bounded views,
  not useful archive-health gauges. Existing failures and Event logs remain.

## Report investigation (O6)

| System | Existing preview / decision |
| --- | --- |
| Bestiary | Existing PreviewReport already checks local basics, new/known/rejected rumours, identity conflicts, source provenance and capacity. Unchanged. |
| Gathering | No report importer or recipient review UI. Unchanged. |
| Atlas | Export payload preview and StageReported adapter; no accepting recipient UI. Unchanged. |
| Angling | Existing sender and per-identity/result detail augmented with actual acceptance-stage new/updated/known result and identity counts. |
| Ledger | Existing observer, source, offering, location and notes preview augmented with contact/report-source outcome from real merge validation. |
| Lore | Existing selected evidence, sender and private-field detail augmented with entry/revision/duplicate-receipt outcome from real validated writes in dry-run mode. Conflicting source versions stay separate. |
| Treasure | Tested data-only Prepare/Accept adapter with identity/conflict/enrichment/capacity logic, but explicitly no delivery/import UI. Unchanged; no new transport or acceptance surface introduced. |

Previews add short summaries to existing scrollable readers. They are current
preflight estimates, not reservations: acceptance always checks live state again.
No preflight consumes its ticket, allocates live IDs, updates live receipts,
invalidates live caches or invokes journal callbacks. No second merge algorithm
or full-archive cache is introduced.

## Integration and automated coverage

Scope uses one shared header widget, actual active stores and a short tooltip.
Lore capacity stays below the catalogue; the existing capture-status control
stays unchanged. A footer scope label was rejected during layout review because
Bestiary already uses that space for messages. Native rendering is still pending.

New tests: `test_storage_diagnostics.py`, `test_storage_scope.py`, and
`test_report_preflight.py`. They cover empty/near/full/incomplete/read-only archive
status, additions/removals, actual all-section scope, reload/deferred migration,
new/repeated/mixed/updated/conflicting reports, provenance, non-mutation, actual
acceptance agreement, validation failures and UI invalidation/blocked acceptance.

Native checks were appended to existing `LORE.md`, `ACCOUNT_TRACKING.md`,
`ANGLING.md` and `LEDGER.md` for the later combined O3/O4/O8 acceptance batch.

## Files in this batch

Runtime changes: `AccountSections.lua`, `AzerothFieldbook.lua`,
`FieldbookShell.lua`, `LoreJournal.lua`, `LoreBook.lua`, `LoreReports.lua`,
`LoreReportUI.lua`, `AnglingReports.lua`, `AnglingBook.lua`, `LedgerJournal.lua`,
`LedgerReports.lua`, and `LedgerBook.lua`.

Tests added: `tests/test_storage_diagnostics.py`, `tests/test_storage_scope.py`,
and `tests/test_report_preflight.py` (16 focused test methods).

Documentation changed: `CHANGELOG.md`, `tests/LORE.md`,
`tests/ACCOUNT_TRACKING.md`, `tests/ANGLING.md`, `tests/LEDGER.md`, and this file.
Existing O3/O4/O8 working-tree changes were retained. No version/schema bump,
commit, push, tag, packaging or publication was performed.

## Validation commands

Run from the AzerothFieldbook repository root. The workspace Python executable
was used because `python` is not on this host's PATH. The repository's existing
`.codex-test-deps` provides the pinned Lupa 2.8 dependency.

```powershell
$afbPython = 'C:\Users\tysci\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$afbTests = @(
    'test_storage_diagnostics.py','test_storage_scope.py','test_report_preflight.py',
    'test_lore_journal.py','test_lore_preservation.py','test_lore_reports.py',
    'test_lore_report_revisions.py','test_lore_report_lists.py','test_lore_ui.py',
    'test_angling.py','test_ledger.py','test_account_sections.py',
    'test_account_lore_treasure.py','test_account_summaries.py',
    'test_fieldbook_shell.py','test_fieldbook_tabs.py'
)
$afbFailures = @()
foreach ($afbTest in $afbTests) {
    Write-Output "RUN $afbTest"
    & $afbPython -B -X utf8 "tests/$afbTest"
    if ($LASTEXITCODE -ne 0) { $afbFailures += $afbTest }
}
if ($afbFailures.Count) { throw "Failed: $($afbFailures -join ', ')" }

& $afbPython -B -X utf8 tests/run_tests.py > '..\.codex-test-deps\o2-o6-o7-full-suite.log' 2>&1
# Check $LASTEXITCODE: the runner includes all Lua compilation, manifest,
# binding XML and version consistency checks as well as all test scripts.
git diff --check
git diff --stat
git diff --numstat
git diff -- AccountSections.lua AzerothFieldbook.lua FieldbookShell.lua `
    LoreJournal.lua LoreBook.lua LoreReports.lua LoreReportUI.lua `
    AnglingReports.lua AnglingBook.lua LedgerJournal.lua LedgerReports.lua LedgerBook.lua
git diff -- CHANGELOG.md tests/LORE.md tests/ACCOUNT_TRACKING.md tests/ANGLING.md tests/LEDGER.md
git status --short
```

The three new test files and this document were also read in full; untracked
files do not appear in `git diff`. Native visual acceptance remains deferred to
the checklists above, rather than inferred from the synthetic widget harness.

## Validation results (2026-09-30)

- All 16 targeted test files passed, including the existing preservation and
  navigation stress cases. The 16 new focused test methods passed.
- Full runner: **70 test files, 0 failed**, process exit 0. The runner compiled
  **all 78 runtime Lua files with Lua 5.1**, and passed TOC/manifest, binding XML
  and version 0.18.0 consistency checks.
- `git diff --check`: passed. Final runtime/documentation diffs and all new files
  reviewed. Additional UTF-8 reads and new-file whitespace checks passed.
- Full output: `../.codex-test-deps/o2-o6-o7-full-suite.log` (local validation
  artifact outside the addon repository).
- Native WoW acceptance: not run in this task; checklists remain pending for the
  later combined O3/O4/O8 batch.

Version remains 0.18.0. For a future publication of the accumulated user-facing
UI additions, recommend 0.19.0 Beta while combined native acceptance is pending;
this recommendation does not authorize a version change or publication.
