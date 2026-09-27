# Code-quality and memory audit — 2026-09-27

Audited the current working tree, including the unreleased Atlas and gathering
overlays, on top of commit `d0aafda`. Fixes are recorded as **0.12.14**. Existing
uncommitted work was preserved. No commit, push or publication was performed.

## Scope and method

Reviewed runtime allocation sites and ownership across the 47 TOC-loaded Lua
modules: frames/regions, pools, hooks, event registrations, update callbacks,
timers, transient caches, saved journals, account migration, backups, sharing
queues and report codecs. Followed reset, deletion, map-switching and window-close
paths. Used the full repository runner before and after changes, plus Lua 5.1
stress tests with garbage collection and weak references to identify retained
objects. Widget tests retain every allocated frame/region and count allocations
after warming the UI.

## Confirmed findings fixed

| Area | Defect | Resolution |
| --- | --- | --- |
| Bestiary sightings | Every distinct instance GUID remained cached until reset/reload; repeated polls allocated replacement tables. | A ring retains at most 2,048 identities and reuses repeated observations. Discovery credit and kill replay guards remain separate. |
| Player classes | Mouseovers/targets retained every observed player name for the session. | Bound the transient cache to 512 names. Previously saved report-source colours remain available after eviction. |
| Combat sessions | Seen and wiped-session sets accumulated IDs after the meter retired sessions. Reset did not clear exclusions; incomplete wipe snapshots could permit old imports. | Reconcile against complete readable retained-history snapshots, bounded to 1,000 IDs. Clear exclusions on meter reset and defer wipe reconciliation on unreadable or malformed snapshots. |
| Gathering overlays | Dense maps permanently allocated one native frame per position, with no pool limit; hidden pins and per-map caches retained old data. | Reuse pools of at most 512 world-map / 128 minimap pins, prioritizing recent / nearest positions respectively. Cache only the displayed maps and release hidden data. Saved locations are not deleted. |
| Atlas map | Unused pooled pins retained detached groups of complete discovery records after switching maps. | Clear previous group references before assigning visible markers, including when artwork is unavailable. |
| Backup imports | Closing the window cleared clipboard text but retained the decoded import through the selected-backup closure. | Release selection and row snapshot references on close; repopulate saved rows on reopening. |
| Atlas report drafts | Deselecting records/notes left false keys, accumulating obsolete identities over repeated creation/deletion. | Remove deselected keys and clean old false entries when opening the draft. Explicit selected missing references are preserved. |
| Atlas list validation | Lua 5.1 can return a length equal to the key count for a sparse list, allowing normalization to silently truncate later route stops. | Validate every consecutive index. Invalid edits/reports are rejected without replacing existing records. |

All findings above are reproducible correctness or retention defects. Tests cover
credit preservation, current-instance deduplication, wipe/reload boundaries,
saved source colours, saved gathering points and native widget reuse.

## Measurements and verification

Synthetic workloads hold durable discoveries constant. Figures are retained
Lua heap after two full collections; they exclude native game memory.

| Workload after warm-up | Before | After |
| --- | ---: | ---: |
| 10,000 additional creature GUIDs, one creature entry | +2,467 KiB | Less than 1 KiB |
| 10,000 additional retired combat sessions, including wipe reconciliation | +479 KiB | Less than 1 KiB |
| 10,000 additional observed player names | Unbounded by inspection | Less than 1 KiB |

`test_memory_lifecycle.py` exercises those workloads, verifies collection of
discarded snapshots through weak references, and displays 1,536 saved gathering
positions within the pool budgets without deleting any. Repeated map navigation
does not allocate further widgets. Section navigation tests warm all seven
sections and their Help/Options pages, then repeat the cycle 100 times and check
that frame/region counts and Escape registrations stay constant. Atlas list
validation checks all 1,024 subsets of ten list indices.

Run the complete suite from the repository root:

```powershell
python -B -X utf8 tests/run_tests.py
```

The local run used the bundled Python runtime because the Windows Store Python
launcher could not start. The same runner and pinned `lupa==2.8` dependency were
used. It checks all 47 Lua files, TOC coverage, bindings, version references and
all 44 test files. `git diff --check` also passes.

## Intentional retention and remaining limits

- The per-character Event log intentionally keeps all events, as documented in
  the README. Saved journal records, discovery/knowledge history, report-source
  identities and backups also consume increasing memory as the user collects
  data. This audit does not truncate that history. Five saved backups plus one
  recovery copy can dominate memory for a large Bestiary.
- A sighting evicted from the 2,048-instance cache can increment the internal
  sighting count if observed again. Earned knowledge, first encounter dates and
  kill deduplication do not depend on this cache. An unsaved player class may
  need a new observation after eviction; saved report-source colours persist.
- The existing sharing transport bounds its queue, incoming transfers, receipts,
  payload size and retries. Literal backup/report parsers do not evaluate code.
  Diagnostic traces, aura rows and cast-ID history are bounded. Section windows
  are created lazily and reused. No additional growth defect was confirmed in
  those paths during this pass.
- A pool retains its allocated native widgets for the rest of the session even
  when hidden. Lua heap tests and the synthetic widget host cannot establish
  native texture/model memory use, real rendering cost or a universal absence
  of leaks. Dense overlays now trade simultaneous displayed positions for a
  fixed widget budget; the per-resource Locations view remains available.

## Live-client verification still needed

1. Warm all sections, editors, Help/Options, Locations, sharing and backup windows.
   Record addon memory with the same saved dataset after garbage collection.
2. Repeat opening/closing and map navigation, toggle both gathering overlays,
   move/rotate/zoom the minimap, and compare memory after collection. Check dense
   maps for recent world-map and nearest minimap selection and stable tooltips.
3. Observe many creature instances and players, then compare retained memory
   after collection. Separate new saved events/records from transient growth.
4. Preview a large backup import and close it without restoring. Verify the
   temporary memory is released and reopening shows the existing saved backups.
5. Verify the supported client's meter-reset event ordering and first readable
   post-wipe snapshot. Keep the section-specific rendering/API checks in
   `ATLAS.md`, `GATHERING.md` and `GATHERING_MAP_PINS.md`.

No live WoW session or native memory profiler was exercised for this audit.
