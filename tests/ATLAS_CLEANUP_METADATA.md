# Atlas interior cleanup implementation notes — 2026-10-04

## Performance follow-up — planned before edits

User reports a zone takes over a minute, making periodic full-map cleanup
impractical. Profile the existing algorithm on read-only survey copies; retain
the 1 ms worker budget and all geometry/ownership guarantees. The first profile
shows tracedHull/cross/intersection tests dominate, not overlap clipping.
Move inexpensive convex rejection before traced reconstruction and reuse sorted
points / initial hulls where their invariants are established. Do not raise the
frame budget to disguise total work, or introduce automatic periodic cleanup.
New sampling can still invalidate a full-map run; local incremental maintenance
is a separate design requirement, not solved merely by faster manual cleanup.

### Performance result and rollback

- `hull` accepts a presorted flag only for cleanup's filtered sorted input.
  `tracedHull` accepts an existing convex hull plus its sorted input, copying
  vertices before inserting detours. Geometry construction reuses its first
  hull; cleanup runs both convex tolerance checks before tracing candidates.
- Segment containment checks bounds before cross products; intersection checks
  reject disjoint bounding boxes first. These are exact early exits, with no
  tolerance, point-cap, storage-schema or work-budget changes.
- Read-only Westfall replay: 695 samples (479 interiors, 216 crossings), modeled
  dimensions 3500 by 2333.33 yards. Before: 4760 ms, 4963 worker frames;
  after: 3633 ms, 3617 frames (24% less elapsed work, 27% fewer frames).
  Both removed 192 identical samples; 197 shape and 90 ownership rejections.
  Per-step peaks were 1.21 / 1.25 ms in the Python/Lua harness. These are not
  live WoW timings. At 60 FPS the frame counts imply about 83 / 60 seconds;
  faster code does not make full-map validation suitable for frequent repeats.
- 55 cleanup/sub-zone tests pass; 93 Lua files compile and manifest, bindings
  and version checks pass. Thirty seeded comparisons against the pre-change
  source produced identical traced outlines, retained samples, compact coverage
  and diagnostics, including duplicate coordinates, overlaps and manual points.
- Rollback: remove the optional hull/tracing reuse arguments, restore the
  original sorting and unconditional traced reconstruction in `simplify`, and
  remove the segment early exits. No saved-data migration is involved.
- Periodic cleanup is still not enabled. A future background implementation
  should coalesce changed regions, validate against nearby boundary evidence,
  and commit bounded jobs without discarding an entire map's work whenever
  an unrelated new sample arrives. Preserve the existing shared frame budget.

## Tolerance-based simplification follow-up (plan recorded before implementation)

The user now authorizes small boundary changes: retain 25-yard capture, replace
the blanket 50-yard edge exclusion and exact-outline rule with a 5-yard maximum
deviation. Preserve manual samples and crossings, reject shortcutting narrow
passages, and protect shared borders/ownership. Compact coverage must suppress
removed edge samples too, while accepting contradictory/new boundary evidence.
Use reconstructed retained + compact observations as the tolerance reference so
repeated cleanup does not accumulate 5-yard shifts. Retain the coverage schema
and existing caps. Update retention diagnostics and regression tests. Reverting
this follow-up requires restoring exact outline checks and the 50-yard sampling
guard; preserve optional timestamps and coverage compatibility. SavedVariables
are used only as read-only replay input, never edited on disk by these tools.

### Current implementation and verification

- `S.SIMPLIFY_YARDS=5`; automatic capture stays at 25 yards. All valid automatic
  interior samples, including perimeter samples, can be candidates. Manual
  points and crossings remain protected. The old 50-yard exclusion is removed.
- A proposed outline must follow a cyclic subsequence of the reference vertices.
  Every omitted chain vertex must lie within five world yards of its replacement
  segment, using separate map width/height scales. The convex capsule and
  continuous projection bound both directions of boundary deviation. Collapsing
  a filled polygon, reversing its order or introducing new outline vertices is
  rejected. Non-collinear shortcuts are rejected near nonadjacent boundary
  segments within ten yards, or if they intersect another original edge.
- The convex patch enclosing each changed chain must not intersect another
  area's convex footprint. Shared boundaries are therefore protected more
  strictly than the five-yard allowance. Half-plane ownership checks still
  protect overlap ownership when interior anchors are removed. Their potential
  influence cell is clipped against remaining own anchors before testing rivals.
- Reconstruct original observations from retained samples plus packed coverage
  solely for validation. Rendering uses retained samples. Validate against both
  this reconstructed reference and the current displayed outline, so repeated
  cleanup cannot accumulate shifts and later observations cannot trigger an
  unbounded correction. Ambiguous comparisons retain the samples.
- Up to three simplification passes finish straight chains on isolated maps.
  Maps with actual convex overlaps use one pass to avoid expensive rechecking
  for marginal extra savings. This is conservative simplification, not a promise
  of the mathematically smallest set of points.
- Coverage suppresses remembered edge locations as well as interiors when the
  current renderer-style ownership agrees. Previously observed positions just
  outside a simplified outline remain covered within the same five-yard
  tolerance. New positions farther outside, or observations of another area,
  remain eligible. Crossings and manual points bypass coverage as before.
- The five-yard bound applies to inferred geometric outlines, not knowledge of
  actual game walls; the renderer's existing contour approximation still applies.

Final replay of the saved Westfall survey (read-only, modelled dimensions
3500 by 2333.33 yards): removed 171 of 454 interior samples, retained 213
crossings, reduced the saved-size estimate by 21,011 bytes including coverage.
All resulting traced outlines passed the tolerance comparison. This replay took
about 4.49 seconds of host-side work across 4,700 cooperative slices; measured
peak slice 1.18 ms. Native game timings and live sample counts can differ;
overlapping maps may take time to finish and new samples invalidate stale work.
Synthetic 1,024-point square: 1,020 removed, four corners retained, 8,160 coverage
characters; about 349 ms across 508 slices, peak 1.12 ms on this host.

Validation: 115 focused tests passed across Atlas, cleanup, storage, account
merging and whole-save backups. After bounding extra passes on overlapping maps,
all 55 cleanup/sub-zone tests were rerun successfully. All 93 Lua files compile
under Lua 5.1; manifest/bindings/version validation and diff whitespace checks
pass. New cases cover yard scaling, narrow passages, shared-strip protection,
cumulative error rejection, curved-edge simplification, reload suppression of
removed edge samples, and accepting observations beyond the new boundary.
No runtime version bump, commit or publication is performed.

## Baseline and rollback

Before this change, AtlasSubzones.lua uses 50-yard automatic survey spacing,
1,024 interior samples / 4,096 total samples per map, and convex-only cleanup.
Traced cleanup is disabled; deleted points have no suppression memory. Samples
carry `at` timestamps, used only by the point hover. Legacy Fill is on the Atlas
page and defaults to traced when its setting is absent.

The working tree already contains unrelated edits, including world-map label
fixes in AtlasSubzones.lua and tests/test_atlas_subzones.py, and the Atlas storage
counter. Do not restore whole files from HEAD to revert this feature.
Baseline HEAD: `0a3c5121ecf9db331a2cc3aa680542eaead2a7a7` (plus the pre-existing
uncommitted changes above).

## Initial contract (superseded by the tolerance follow-up above)

- Automatic interior spacing becomes 25 yards; crossing and manual spacing stay
  10 and 15 yards. Existing sample limits stay unchanged.
- Cleanup preserves crossings and manual points. For traced mode, require exact
  outline equivalence after cumulative removals. Conservatively retain evidence
  for overlapping areas rather than approximating boundary ownership.
- Keep compact per-name coordinates for removed observations as coverage memory.
  These are evidence of visited positions, never inferred polygon coverage.
  Suppression applies only to automatic same-name interior points; manual points
  and crossings remain available. Changed edges must reopen sampling.
- Background cleanup keeps the shared work budget and rejects stale results.
- Accept old timestamps but stop creating new timestamps; remove legacy `at`
  fields only from validated samples in writable stores. Historical timestamps
  cannot be reconstructed after migration. Whole-Fieldbook exports made before
  this change are the recovery source for original samples/timestamps.
- Move Legacy Fill to Options, default off, documenting its CPU/detail tradeoff.

## Recovery constraints

Compact coverage remembers coordinates but does not replace a full backup.
To roll back code, preserve the new coverage data as unknown metadata; earlier
versions ignore it and may re-record cleaned interior locations. They also
require sample timestamps, so keep the new optional-`at` validation and dateless
hover when reverting cleanup alone. Do not manufacture historical dates. Restore
an earlier whole-Fieldbook export to run completely unchanged older code or if
original observations/timestamps are needed.
No automatic cleanup on login is intended; the existing cleanup button requests
the operation.

## Initial format and behaviour (historical; see current implementation above)

`saved.subzoneCoverage = {version=1, maps={[mapID]={[areaName]=packed}}}`.
Each removed position is exactly eight hexadecimal characters: four for x,
four for y, in the original 0..10000 coordinate system. The name is stored once
per area; the positions are exact observations, not inferred grid coverage.
Maximum 4,096 remembered positions per map; no samples are removed if there is
no room to remember them. Unknown coverage versions/malformed map coverage are
preserved and cleanup skips them.

The retained samples keep the original 1,024 interior / 4,096 total limits.
Cleanup tries batches, recursively splitting any batch that changes an outline.
Every accepted batch preserves both convex and traced vertex sequences against
the cumulatively retained points. Candidates must be more than 50 yards inside
the traced edge and away from the actual convex footprint of rival observations.
Overlapping areas now use conservative half-plane ownership checks rather than
an area-wide bounding-box veto (see follow-up below). Crossings and
manual points are never cleanup candidates. This preserves current border
geometry, not a counterfactual history of how deleted evidence might influence
future observations; label centroids may shift after cleanup.

Coverage suppression uses a runtime spatial grid with 25-yard cells and exact
25-yard radius checks, matched by observed area name. A background geometry
cache is refreshed when the map's sample revision changes. While that cache is
warming, automatic interior sampling is deferred; crossing capture continues.
Suppression additionally requires the current position to remain more than
50 yards inside the current traced outline and away from rival observations.
Manual samples bypass coverage. Geometry need not be rebuilt for movement
outside remembered coverage. Near edges, deliberate resampling remains possible.

No new sample stores `at`. Supported old samples lose only `at` when their map
is indexed; untouched maps are migrated when visited, rendered or cleaned.
Readonly/unsupported stores are preserved. Interior proximity compaction on
indexing is disabled: only explicit border-preserving cleanup removes them.

Coverage merges by coordinate union on account import, and whole-save backups
retain it. Existing Legacy Fill preferences are respected; absent preferences
default off. Atlas Options is connected to the active journal, including shared
tracking. The archive tooltip includes coverage positions and estimated bytes.

## Validation and limits

### Follow-up: cleanup appears ineffective

Investigating the live report using read-only copies of SavedVariables. The
initial algorithm rejects every candidate in an area if that area's bounding
box overlaps another area's bounding box, even when the candidate is far from
the overlap. It also uses rival bounding boxes for proximity exclusion. This
can protect an entire zone unnecessarily. Replace these broad vetoes with
actual convex-footprint proximity and conservative half-plane ownership checks
over convex overlap (a superset of traced overlap), retaining exact outline
equivalence. Add counted retention reasons to make no-op cleanups explainable.
SavedVariables files are not edited by this investigation. For rollback of this
follow-up, restore the broad vetoes and basic summary while retaining the
coverage format, timestamp compatibility and other prior feature changes.

Confirmed: the saved account Westfall survey had 335 interior samples, all
excluded by the old area-wide rectangle-overlap rule. The revised algorithm
first checks real convex-footprint proximity. For surviving candidates, it
clips each convex overlap by the removed-anchor/rival bisector and every
rival/remaining-own-anchor bisector. Any nonempty possible ownership-change
region rejects that removal. Convex overlap contains traced overlap, so the
same test protects both fill modes; cumulative accepted batches update the
remaining anchors. A small clipping tolerance retains ambiguous/tied evidence.

Offline replay uses copies of saved data and modelled map dimensions, not live
client dimensions. Westfall replay at 3500 by 2333.33 modelled yards removed
2 of 335 samples; 248 were within the edge/insufficient-area exclusion and 85
were near another area's convex footprint. Other modelled widths produced
different counts. Therefore this fix does not promise large savings on an
edge-heavy travel survey. Grid classification before/after remained unchanged
in those replays after indexing; no saved files were modified.

The result now counts every interior outcome: removed, edge/insufficient area,
near another area, outline support, overlap ownership, manual, or coverage cap.
Crossings and unsupported records are separately counted. Results remain in
the button tooltip; all-map runs retain the per-map breakdowns. The size counter
is scheduled to refresh immediately after completion.

Focused tests cover cumulative outline/ownership preservation, idempotence,
stale cancellation, multi-map cleanup, manual/crossing preservation, suppression
after reload, changed edges/names, coverage limits, unsupported data, account
merge, dateless migration, real Options wiring and backup recovery.
Final validation: 110 focused tests passed across Atlas, sub-zones, cleanup,
storage, account sections, map brightness and whole-Fieldbook backups. All 93
runtime Lua files compiled as Lua 5.1; manifest/bindings/version checks and
`git diff --check` passed. This is not a full pre-release suite run.

Optional `tests/benchmark_atlas_cleanup.py` uses synthetic regular grids, not
native game timings. On this host, 1,024 points reduced to 124 retained points
plus 7,200 coverage characters in about 20 ms total work spread across 31 worker
slices, with a measured largest slice about 1.04 ms. Irregular/overlapping
evidence can take longer or yield much smaller savings. The shared 1 ms budget
is cooperative, not a hard frame-time guarantee. Live client visual/performance
verification remains necessary. Recommended release: 0.26.0-beta.1 for public
testing; no version increment or publication is performed by this task.
