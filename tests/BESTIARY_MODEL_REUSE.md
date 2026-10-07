# A7: bounded Bestiary model repair

Baseline: 0.36.2, `e16d88e` (clean local release checkout).

## Current status

The 0.36.2 baseline retains 60 PlayerModel frames after browsing 60 distinct
entries and 120 after 120; deleting/resetting does not release them. Revisits do
not grow the cache. This measures retained frames, not native asset memory or FPS.

The repair reuses ONE production PlayerModel across all selections.
**A7 is closed as of 2026-10-08:** the distinct-frame allocation regression,
callback ownership tests, owner-operated native smoke and full regression
validation pass (including the environment-only rerun documented below).
The optional diagnostic adds at most one concealed comparison frame per session;
it is disabled after reload. No version bump, commit, push, tag or publication
is part of this work.

## Model ownership rule

An asynchronous OnModelLoaded never authorizes a scene or portrait. The handler
conceals the model, then uses the callback only to trigger a fresh request for
the CURRENT selected source. Verification requires all of the following:

- The selected entry is still personally encountered and initialization is valid.
- ClearModel succeeds and its readable model file is nil or zero. An old display
  ID may survive clearing; it is never sufficient.
- The new SetCreature/SetUnit completes synchronously inside its setter, after
  clearing. Callbacks during ClearModel are ignored. The setter must return
  normally (nil is allowed; false/restricted results are rejected).
- After returning, readable display and positive model-file values still match
  the synchronous callback. The selection generation must remain current; for
  SetUnit, the same unit token must still match both creature ID and instance GUID.
- Offline SetCreature needs a positive display ID. SetUnit also permits display
  zero, observed on Forever 70245, and uses the verified live unit for its portrait.

Lua generations only guard selection/reentrancy. They do not identify native
callbacks. The design relies on the observed native operation: clearing the
file and synchronously completing the freshly requested setter establishes its
current scene. It does not assume ClearModel cancels all outstanding loads or
that display/model-file IDs uniquely identify creatures. A later old callback
conceals the frame and repeats verification, even if a newer scene was visible.

There is at most one immediate callback-triggered verification per scheduled
request. If verification is asynchronous, the existing half-second initial
retries and five-second slow retries continue; no callback loop allocates frames.
Ordinary priming retries do not clear outstanding slow loads. A client that never
provides a verified synchronous reload stays concealed and retries, rather than
accepting an unidentified completion. The owner-operated smoke below covers the current target client. Revalidation preserves dragged rotation; changing entry resets it.

## Why a native trace is needed

The released 0.36.2 guard uses permanent creature ownership of each native frame.
Changing a frame's Lua generation/handler cannot identify a native completion
that arrives on that frame after it has been reassigned. Merely waiting a fixed
delay or using an LRU pool does not establish cancellation. Serializing loads
also needs proof that no older completion can arrive after the next assignment;
retries and silent nil-return setters complicate that assumption.

Blizzard's generated API documentation in the public UI-source mirror exposes
PlayerModel `GetDisplayInfo`, `SetCreature`, and `SetUnit`, but no originating
request ID or cancellation fence. ModelScene actors expose `GetModelUnitGUID`,
but that alone does not cover offline creature fallback. Changing renderers is
not yet supported by evidence of equivalent appearance and ownership behavior.

Sources inspected at mirror commit
`09b9db7948abc9b9648dedaab51eb0cf3ee67b31`:

- [Character model API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICharacterModelBaseDocumentation.lua)
- [Simple model API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleModelAPIDocumentation.lua)
- [ModelScene actor API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPIModelSceneFrameActorBaseDocumentation.lua)

These describe the public client API; Forever's native behavior must be checked
on the owner's client. Display IDs identify appearance, not a unique creature
or request. A matching ID alone must not be promoted to ownership proof.

## Probe behavior

`/fieldbook debug bestiary model on` enables a runtime-only, 240-row trace.
Selecting personally encountered entries mirrors the viewer's SetUnit/SetCreature
requests into one concealed, mouse-disabled PlayerModel. It records getters
before and after setters, callback arguments, synchronous callback timing, and
five bounded settled observations. The original investigation used the per-creature viewer as an independently
owned reference; the current candidate reports the shared viewer selection
instead. Its frame label is diagnostic data, never callback ownership. Probe callbacks never reveal a scene, update a
portrait, or write a journal. Errors cannot escape into the viewer. Restricted
values are redacted before comparisons or formatting.

`/fieldbook debug bestiary model` opens the selectable report.
`/fieldbook debug bestiary model off` stops the recorder and clears/hides its
single reusable frame. Reload also resets all probe state. The diagnostic frame
itself remains allocated for the session, bounded at one even across toggles.

A second model request can warm the native appearance cache and affect timing;
a successful trace is evidence for a candidate design, not a complete proof.
The probe does not try to force unencountered creatures or control the game.

## First native trace and verification experiment

The owner reloaded without Lua errors and browsed encountered creatures. The v1
trace reports 42 requests and 32 callbacks; its retained tail covers requests
24-42. Every shown callback had zero arguments. No SetUnit request appears in
the retained tail.

- After ClearModel, the old display ID remains while GetModelFileID is nil.
  A display ID alone therefore cannot authorize a newly selected scene.
- Creature 721 resolves to display 139885 in the immutable reference and 139886
  in the probe, both file 125512. Equal creature IDs can choose different variants.
- Uncached SetCreature requests can return nil without resolving; file remains
  nil. After data becomes available, a retry can expose the new file before the
  asynchronous completion callback.
- Several cached requests invoke OnModelLoaded synchronously inside SetCreature.
  Their successful setter return is still nil. Other cached requests complete
  asynchronously. Synchronous availability must be tested, not assumed.

The v2 command `/fieldbook debug bestiary model verify` tests a candidate
revalidation operation on the concealed probe. On an asynchronous callback it
clears the probe, reissues the CURRENT requested source, and records whether a
callback occurs inside that setter with a readable display and file. Callbacks
during clearing do not count; nested verification is suppressed. Live unit GUIDs
are rechecked and a changed token falls back to the selected creature ID. At most
three verification attempts run per selection, preventing an asynchronous loop.

This experiment never reveals the probe or authorizes a production model. It
must demonstrate both recovery and absence of an endless async cycle before it
can underpin a bounded viewer. Synchronous callback observation is a candidate
contract, not proof that arbitrary native callbacks carry identity.

## Further native evidence

Owner-operated Forever 1.60.1 build 70245 (interface 16001) traces established:

- The first v2 offline trace has 10 requests and 18 callbacks. All nine completed
  revalidations synchronously loaded the current source, with no verification
  limit reached. Entry 1933 was switched away before completion and is not counted
  as a successful validation. A repeated identical report adds no new evidence.
- The later live trace contains SetUnit for creature 1115 and a stable target
  GUID. Both original and revalidation callbacks occur inside SetUnit, which
  returns true and exposes display 0 with model file 126239. The original v2
  experiment marks these false only because it requires a positive display.
- The old visible viewer likewise rejects those zero-display loads and retries
  until SetCreature supplies display 726 with the same model file. The candidate
  handles this live-unit result explicitly and never passes zero to the portrait
  display-ID setter.

These traces informed the candidate. They do not establish universal native
timing, cancellation, retained asset-memory bounds, or visible candidate behavior.

## Owner-operated native acceptance — 2026-10-08

After a clean reload, with the comparison probe reset to OFF, the owner confirmed:

1. A previously encountered entry whose creature was not targeted showed the
   correct 3D model and portrait.
2. Rapid keybind switching through almost all saved creatures was very quick,
   with correct appearances and no previous creature left showing.
3. A matching living target showed the correct model and portrait.
4. Dragged rotation stayed at the released angle without snapping back.
5. Changing target to another creature while keeping the entry open preserved
   the appearance belonging to the selected entry.
6. Leaving for another Fieldbook page and returning preserved correct model
   and portrait display.

These are owner-reported native observations, not an instrumented FPS benchmark
or proof of every adversarial callback sequence. Live GUID changes during a
setter, restricted getters, shared-only gating and destructive lifecycle cycles
have automated coverage. No owner journal was reset for testing.

## Owner-operated native checks

Guide one action at a time. Reload first and confirm no Lua errors; keep the
comparison probe OFF for initial visible tests so it cannot warm the cache.
Check offline entries of different types, rapid switches and revisits, a matching
living target, target changes during loading, rotation, and leaving/reopening
the page. Confirm model and portrait remain the selected creature. Shared-only
entries must remain gated. Do not reset the owner's only saved data: automated
tests use synthetic journals for destructive lifecycle coverage.

If diagnostics are needed, `/fieldbook debug bestiary model on` records a bounded
trace and `/fieldbook debug bestiary model` opens it; `off` disables it. The older
`verify` experiment is still available, but its positive-display criterion is
stricter than the new live-unit path. A diagnostic comparison request can warm
the cache and affect timing, so finish with it disabled.

## Automated coverage and final validation

- Eight model tests preserve encounter gates, portrait clearing, layout before
  synchronous loading, nil-return live setters, preferred live tokens, fallback
  and slow-load recovery. The late-callback test now sends old native completions
  to the SAME reused frame, both before and after the current scene is visible.
- Seven additional tests cover a single frame across 180 distinct creatures,
  revisits and three delete/repopulate/reset cycles; callbacks during clearing;
  absent synchronous completion; failed/restricted getters and setters; changing
  getter values; asynchronous storms; zero-display live loads; GUID changes;
  initialization blocking; shared model-file variants and rotation.
- Eight opt-in probe tests cover its one-frame and 240-row bounds, safe API reads,
  gates, error isolation, slash dispatch and bounded verification behavior.
- Diagnostic report regression and Lua 5.1 compilation/manifest/version checks
  are part of the candidate gate. The version remains 0.36.2.

Final validation on 2026-10-08:

- Focused run: 23 model/reuse/probe tests pass, along with script-style diagnostic
  report and sharing UI checks.
- Canonical full runner: **103 test files; 102 passed, one failed; exit 1**.
  The sole failure was `test_release_notes.py`: sandbox access left Python with
  no usable default temporary directory. With TEMP/TMP directed to a writable
  workspace folder, all five release-notes tests passed on an unchanged source
  file (exit 0). All 103 test files therefore pass across the full run and this
  environment-corrected rerun. Slow navigation, memory-lifecycle and preservation
  coverage passed in the full run; those checks were not needlessly repeated.
- Lua 5.1 compilation: 94 runtime files; manifest, Bindings.xml and version
  consistency pass. The tested runtime and test-file hashes were captured before
  the suite and verified unchanged afterward. Only acceptance documentation was
  updated after this run.

Native FPS and asset-memory use remain unmeasured. The proven allocation bound
concerns PlayerModel frames, not the client's internal appearance cache.
