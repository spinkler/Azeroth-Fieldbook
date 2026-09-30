# O1 — Whole-Fieldbook backup and recovery

## Investigation and scope

The starting tree was `main` at `0698876` (0.18.0), including the accepted local
O2/O3/O4/O6/O7/O8 changes. No accepted changes were reset or replaced.
The investigation covered the actual journal loaders, report adapters, legacy
backup implementation and tests, initialization guard, scope selection/imports,
Options, shared shell and resets before implementation.

| Existing storage | State protected by the new backup |
| --- | --- |
| `AzerothFieldbookDB`, version 1 | Retained Bestiary, private notes, settings, Event log, source classes and account tracking identity/preference |
| `AzerothFieldbookAccountDB`, version 1/additive container | Shared Bestiary; all six `.sections` stores, import markers, next character key, Atlas reference mappings/issues/repair markers, Angling repair markers, shared appearance preferences |
| Gathering, schema 1 | Entries, counters, loot observations, zones, coordinate samples, field notes, favourites and display preferences |
| Atlas, schema 1 | Discoveries, routes/stops, expeditions, private notes, weather, subzone mapping evidence, preferences, durable references and legacy aliases |
| Angling, schema 1 | Waters/pools/items/spots, merged identities, aggregates and contributor partitions, bounded history/sessions/replay guards, notes, reports, claims, receipts, origin indexes, Event log and state |
| Ledger, schema 1 | Contacts, goods/lessons/services, sightings, private annotations, migration originals, durable references, contact aliases, received reports and report indexes |
| Treasure, schema 1 | Kinds, all retained encounters/contents, historical origins, reports/receipts, annotations/bookmarks, browsing state and preserved invalid records |
| Lore, schema 1 | All writings/pages/passages, mysteries/people/landmarks, private annotations, tags, variants, internal and cross-section links, reader state, original report identities, revisions/receipts and preserved invalid records |

The six additional per-character globals are `AzerothFieldbookGatheringDB`,
`AzerothFieldbookAtlasDB`, `AzerothFieldbookAnglingDB`, `AzerothFieldbookLedgerDB`,
`AzerothFieldbookTreasureDB`, and `AzerothFieldbookLoreDB`. The TOC declares all
seven character roots separately from the account root. AccountSections selects
active stores, but retains character copies for opt-out. A whole backup therefore
captures **all eight loaded roots**, regardless of the pending/active scope option.
It never backs up only the current seven UI views.

Original Bestiary backups use `BestiaryBackups.lua`, snapshot version 1 and
`AFB1:` literal text with Adler-32 integrity checking. They project onto a strict
creature schema, use a 4 MiB / 300,000-node / depth-24 boundary, retain five copies
plus recovery in the active root, and restore in place while retaining Knowledge
accounting and current sharing transactions. Those buttons, archives, codec,
tests and restore semantics are retained. Bestiary reset and `/fieldbook wipe`
remain Bestiary/settings operations; no new whole-Fieldbook wipe was added.

Reports are not backups. Bestiary reports are bounded creature claims; Atlas
reports omit private expedition text and weather/mapping data; Angling/Ledger
reports select knowledge and omit notes by default; Lore selects evidence and
private fields explicitly; Treasure has a bounded data-only report adapter.
Their limits (2/8 KiB, 128 KiB, 96 KiB, 128 KiB, 1 MiB, 64 KiB respectively),
exact installed-addon compatibility and acceptance/provenance rules are unchanged.
No new addon-message transport or report protocol is introduced.

## Design and transaction boundaries

`FieldbookBackups.lua` owns one whole-save codec and transaction, rather than
seven report/export/merge implementations. `AFBWB1:` has its own version and
checksum. The envelope contains creation time, installed addon version, owner,
an explicit presence map and all eight roots. Root absence is different from a
malformed scalar, including `false`. All literal descendants are kept: unknown
fields, booleans, sparse preserved maps, markup/raw bytes and full-precision
finite numbers. No `loadstring`, executable serialization or schema projection
is used. Decoding and review allocate detached data and perform no journal writes.

Backup containers are excluded: the new archive is not among the eight roots,
and each root's `bestiaryBackups` field is omitted. This avoids recursive backup
growth. Existing legacy archives are retained at the destination during restore;
they are not portable as part of the new format. Export an old Bestiary copy
separately if its historical contents are needed. Transient unsaved UI drafts,
live capture sessions and not-yet-observed facts are not persisted knowledge.

The new account-wide `AzerothFieldbookBackupDB` has version 1, two saved encoded
copies, one encoded `recovery` and an optional encoded `pending` restore. It is
outside the existing reset roots. Reads do not default a missing archive;
unsupported/malformed archives are never overwritten. A failed save does not
evict an older copy. Archive creation occurs only after successful bounded capture.

Restoration is a replacement of the eight-root knowledge set, on the originating
character. Match the stable player GUID when both are available, otherwise the
full character name and available realm. This is a safeguard against overwriting
the wrong retained journals, not an authentication mechanism. Ordinary reports
remain the tool for transferring selected knowledge between players.

1. Outside combat, decode, validate, check owner and preflight a detached restore.
2. Capture current roots successfully before setting recovery/pending. If any
   preparation fails, live roots and the backup archive remain unchanged.
3. Latch the existing initialization guard, close active journal UI, drop main
   dispatch references and request a reload. No live roots are replaced here.
4. In the fresh namespace, before migrations or observers initialize, revalidate
   the pending copy, capture the final displaced roots, and prepare every root.
5. Assign all roots without callbacks, then initialize normally. Consume pending
   only for this application. On a startup exception or blocked initialization,
   put the original root objects back, retain pending/recovery and latch the hold.
   There is no repeated apply in the same namespace. Cancellation also requires
   a reload before ordinary activity resumes.

Bestiary accounting follows the accepted recovery policy: retain current spending,
credited milestones and reservations, plus the current delivery state. Never load
old offers/reservations from the backup; retain received evidence in journal
records. Reload retains the existing sharing interruption/cancellation behavior.
Sharing state is detached before startup so a failed initializer cannot mutate
the original roots through an alias. Current replay guards also survive.

Keep surviving `nextCharacter`, `serial`, `nextID` and `referenceSerial` counters
at least as high as their current values. Otherwise a rollback could allocate an
identity belonging to a later offline character or a record already referenced
or reported. No restore can infer counters or knowledge lost after the backup
when the current files are gone; backups are point-in-time recovery, not a
continuously synchronized history. Keep current completed one-time import markers
as well as backed-up markers. A snapshot predating shared storage creates empty
shared destinations for retained markers; it restores the character journals
without replaying their original counts/points on a later opt-in or offline login.
Keep the current character import key if that older snapshot had none. Existing
origins, report identities, receipts, references and ambiguous/dangling links are
copied without rekeying.

Validation checks envelope/version/presence, literal types, finite numbers, byte,
node/depth limits, collection shapes, identities, counters, import registries and
supported root schemas. It reuses Bestiary validation per record (avoiding that
codec's single-copy node limit) and Atlas record validation without replacing the
original records with projected results. Lore/Treasure preserve their existing
invalid-record handling; raw invalid evidence is not repaired into accepted
knowledge. Unsupported roots can be captured/exported for preservation but are
not applied. Failed initialization is a final rollback boundary, not proof that
arbitrary malformed records are usable. Raw exports and the displaced recovery
copy remain available if deeper manual/file recovery is needed.

## Limits and practical external recovery

Whole text has a **256 MiB encoded** limit, **4,000,000 nodes** and **64 levels**.
Strings use byte-preserving percent escapes; numbers use 17 significant digits.
Checksums detect incomplete/changed text; they are not cryptographic signatures
or encryption. Saved copies contain private material and should be kept private.
Limits fail explicitly with a file-copy alternative, never partial/truncated saves.

The UI exports `AFBWP1:` parts of **256 KiB payload** with a complete-set digest,
part index/count and individual digest. Parts may arrive out of order; identical
duplicates are harmless. Missing/mixed/conflicting/truncated parts cannot enable
restoration. Adding a bad part does not mutate the previously collected set.
Changing text/selection invalidates approval; acceptance rechecks current state.
Closing the UI releases transient decoded/part buffers and text focus.

For a large archive, use a file copy rather than hundreds of clipboard actions:

1. Exit WoW normally so its SavedVariables are written.
2. Copy the client's entire `WTF` folder to another location (ideally another
   device). This is the simplest way to retain every character and account mapping.
3. Focused copies must include both
   `WTF/Account/<account>/SavedVariables/AzerothFieldbook.lua` and each
   `WTF/Account/<account>/<realm>/<character>/SavedVariables/AzerothFieldbook.lua`,
   together with available `.lua.bak` files. Use one consistent backup set.
4. To recover, close WoW, first keep the current/damaged files separately, then
   replace the matching files from that set. Reopen and inspect both tracking
   scopes. Replacing files while WoW is running risks the client writing over them.

The account file includes the shared journals and whole-backup archive. Each
character file includes that character's settings and seven retained journals.
The addon cannot inspect offline character files; it must not claim otherwise.
Copying only the addon installation folder does not back up user knowledge.

## UI integration and native acceptance (deferred)

The existing Options page gets a separate whole-backup group after Lore controls.
Legacy Bestiary buttons retain their names and meaning. `/fieldbook backups`
opens the same recovery window before the normal command guard, including when
unsupported main data has disabled the addon. The window uses existing text,
button, scrollbar, scale and focus conventions, but does not initialize settings,
register persistent positions or require a working journal/shell. Text-size reads
fall back without writes when the account root is malformed.

O7's shared actual-scope header, O2's Lore capacity display and O6's report previews
are unchanged. Whole backup scope is explained separately because it always
contains both loaded storage scopes. Preview lists seven record categories with
account/character counts; these count stored records, including preserved records,
and are not claims of validated knowledge totals. Atlas counts discoveries plus
expeditions; Angling counts identities, merged spots and personal/reported catch
summaries; Treasure counts kinds plus encounters. Nested notes/evidence and all
other saved fields are included without being added as extra primary records.

- [ ] In the combined native batch, inspect Options and the backup window at
  supported resolutions, UI scales and text sizes; scroll all text and confirm
  footer actions, O7 header, O2 capacity and O6 previews remain usable.
- [ ] On synthetic data, save/export/import each part through the native clipboard,
  including Unicode, Lore markup and multiline notes. Save to an external file,
  then import from that file; do not treat copying alone as verified persistence.
- [ ] Close/reopen and Escape during export and partial import; verify focus and
  memory release, selected-text copying and native EditBox capacity. Time larger
  on-demand captures; no responsiveness claim is inferred from Lua harness timing.
- [ ] Confirm a restore and reload, inspect all seven journals, links, private
  notes, reader positions, reports/receipts and both tracking scopes. Change scope
  before capture as well, to exercise a pending preference. Restore recovery.
- [ ] Use two characters: verify shared visibility, retained local independence,
  same-character restore refusal and later ID allocation after an older restore.
- [ ] On copied synthetic SavedVariables only, test blocked main startup,
  `/fieldbook backups`, raw export, successful external recovery, interrupted
  pending restore, cancellation, normal exit/restart and full WTF file recovery.
- [ ] Exercise committed/uncommitted Bestiary sharing across restore/reload:
  spending stays spent, reservations follow normal reload policy, and no old
  backup offer is automatically sent. Check legacy AFB1 restore independently.

Native WoW acceptance is **pending**, as requested. All automatic fixtures use
synthetic stores; no real player SavedVariables were edited by this task.

## Automated verification

`test_fieldbook_backups.py` uses the real full TOC, production journals, migrations,
reports, widget callbacks and fresh Lua 5.1 namespaces. It exercises exact capture
and codec preservation, replacement/recovery, blocked startup, late rollback,
scope toggles/import idempotence, raw quarantine, Knowledge/transfer/counter
preservation, archive/reset isolation, malformed inputs, parser limits, multipart
integrity and UI approval invalidation. `test_fieldbook_backup_limits.py` covers
two near-capacity valid Lore archives (over 62 MiB combined), and fail-closed
byte/node/depth limits. Existing accepted-feature tests remain in the full runner.

Run `python -B -X utf8 tests/run_tests.py` for the full suite, including script-style
assertions, all runtime Lua 5.1 compilation, TOC/binding and version checks.
Version remains **0.18.0**. Recommend **0.19.0 Beta** for the accumulated additions
while combined native acceptance is pending. No version bump, commit, push, tag,
package or publication is authorized or performed here.

### Results — 2026-09-30

- Confirmed remote `origin/main` remains
  `0698876c6ffd629103fe010d77e59c5ed9ed4d35` with a read-only `git ls-remote`.
  The accepted local audit changes were present before this task and retained.
- Full runner: **72 test files, 0 failed**, exit 0. It compiled **80 Lua 5.1
  runtime files** and passed TOC, binding XML and version 0.18.0 consistency.
  Log: `../.codex-test-deps/o1-full-suite.log` (local artifact outside packaging).
- Final changes to restore holding, counter/import replay protection, validation
  and preview counts were followed by fresh compilation and **nine passing
  focused test files**: whole backups, legacy backups, account sections,
  account Lore/Treasure, tracking summaries, root initialization, player-name
  preservation, storage scope and text size. The whole-backup file now has
  **14 passing test methods**, including received Angling/Ledger/Treasure report
  re-imports and restoration of a pre-account-import backup. Log:
  `../.codex-test-deps/o1-final-focused.log`.
- Near-capacity fixture: two valid Lore archives, each over 31 MiB and below
  32 MiB, round-trip with all pages intact. Byte/node/depth overflow attempts
  preserve the roots and do not create or evict a backup. This test passed
  standalone and in the full runner (about 37 seconds in this Lua harness;
  this is not a native-client responsiveness measurement).
- `git diff --check` passed. The final runtime/docs diff and new files were
  reviewed. All native checkboxes above remain pending for the combined batch.
