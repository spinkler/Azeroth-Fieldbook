# AGENTS.md — Azeroth Fieldbook

## Project

Azeroth Fieldbook is a World of Warcraft addon created by Spinkler.

Current functionality includes the Bestiary, a personal monster journal, and
Herbs & Minerals, with mouseover zone discovery and interaction-only coordinate
markers, plus Traveller’s Atlas for deliberate geographical records, routes and
expedition notes, and Angler’s Almanac for personal fishing observations.
Merchant’s Ledger adds a personal contact and offering directory with a separate character store in
`AzerothFieldbookLedgerDB`; see `tests/LEDGER.md` for identity, capture, report,
storage and validation boundaries.
Treasure Journal adds a historical container journal with a retained character store in
`AzerothFieldbookTreasureDB`; see `tests/TREASURE.md` for attribution, report
adapter and manual-recording boundaries. Lorekeeper's Chronicle adds a personal archive
of writings, landmarks, people and mysteries in per-character
`AzerothFieldbookLoreDB`; see `tests/LORE.md` for capture, provenance, report and
live-verification boundaries. All seven section slots are implemented.
Account-wide tracking applies to all seven journals. Bestiary uses
`AzerothFieldbookAccountDB.bestiary`; `AccountSections.lua` selects shared stores
under `.sections` for gathering, Atlas, angling, Ledger, Treasure and Lore. Each character's
existing section journals import once, with collision-safe IDs and preserved
links. Original per-character SavedVariables remain intact for opt-out. Section
resets, legacy Bestiary backups and report protocols retain their independent scope.
Whole-Fieldbook backups capture the account root plus all seven loaded character
SavedVariables, with identity maps and private fields; see `tests/WHOLE_BACKUPS.md`.
Their separate account archive survives section resets. Restoration is staged
until a fresh reload, and must preserve the startup guard and atomic rollback.
See `tests/ACCOUNT_TRACKING.md`, `tests/ANGLING.md` and `tests/LEDGER.md` for
migration, provenance and validation boundaries. Display-only expected immunity
guidance is optional, off by default, and never grants observed knowledge.

Canonical public repository:

[https://github.com/spinkler/Azeroth-Fieldbook](https://github.com/spinkler/Azeroth-Fieldbook)

CurseForge project ID:

1708795

Current target client:
World of Warcraft: Forever

## Authorship

Project author: Spinkler

Git commit identity for this repository:

Spinkler spinkler417@gmail.com

The project is developed with AI-assisted coding tools.
Design, direction, testing, release decisions, and final development decisions
belong to the author.

Do not change the Git author identity to Codex or another AI identity.

## Git workflow

`main` is the canonical development branch and tracks `origin/main`.

Normal development is local and may accumulate several changes before a push:

1. Make the requested change and recommend a version as described below; change
   the version only when the current task or explicit operator instruction authorizes it.
2. Test it and update the changelog; sync current-version references when versioning is authorized.
3. Leave it ready for review. Do not automatically commit or push each change.
4. When the operator explicitly requests a batch push, commit the accumulated
   changes to `main`, push `main`, and publish the current version using the
   matching annotated tag for the selected release channel and the workflow below.

A bare push to `main` does not trigger publication: the matching `v*` tag push
is required. By the operator's workflow, a request to push the accumulated batch
includes that publication step unless they explicitly say push-only/no release.
This standing workflow does not authorize a push or publication merely because
a local change or version increment is complete.

Do not:

- force-push published history
- rewrite public commits without explicit approval
- push anything under `refs/safety/`
- use `git push --mirror`
- create release tags casually

Historical `refs/safety/` references are local recovery data and must remain
private.

## Releases

IMPORTANT: pushing a Git tag beginning with `v` triggers the production release
workflow in `.github/workflows/release.yml`.

A release tag is therefore a publication action, not merely a local Git marker.

Create or push a `v*` tag only when the operator explicitly requests publication
or a batch push under the workflow above. That batch-push request is sufficient
release authorization; do not ask again solely because it includes a release tag.

Current release naming convention:

- `v0.7.2-alpha` = Alpha/prerelease
- `v0.7.2-beta` = Beta/prerelease
- `v0.18.0-beta.1` = numbered Beta/prerelease
- `v0.17.0` or `v0.18.0` = stable Release, including pre-1.0
- `v1.0.0` = stable Release

The BigWigsMods packager determines release type from the tag name.

The normal release sequence is:

1. Verify the version already recorded in `AzerothFieldbook.toc` and `README.md`.
   Do not increment it again solely to publish an already-versioned batch.
2. Finalize the cumulative changelog for the entire batch since the previous
   push, following Changelog coverage below, and run the required checks.
3. Commit the accumulated changes to `main`.
4. Push `main`.
5. Verify the working tree is clean and `main` matches `origin/main`.
6. Create an annotated tag matching the intended version and selected channel
   under the operator's release or batch-push authorization: for example,
   `v0.18.0-beta.1` for Beta or `v0.18.0` for Release. Do not append a second
   prerelease suffix when the TOC version already includes one.
7. Push only that tag.

The tag push automatically:

- packages the addon
- creates a GitHub Release
- attaches the distributable ZIP
- uploads the same release to CurseForge

Do not manually create a GitHub Release or manually upload a CurseForge build
unless explicitly requested or recovering from automation failure.

Publication extracts the tagged version's dated, self-contained summary from
`CHANGELOG.md`, validates its size, and supplies that summary to the packager.
The full historical changelog remains in the repository. For a partial failure,
the release workflow supports manual dispatch with an existing `release_tag`;
leave `github_only` enabled if CurseForge already accepted the upload. Recovery
must test and package the unchanged tag, never move it or duplicate that upload.

## Changelog coverage

Group consecutive patch versions that each contain only one or two changes
under one version-range heading, rather than giving every small patch its own
heading. For example:

```markdown
## v0.9.120 - v0.9.124 - Unreleased

- First change.
- Second change.
- Further changes from the grouped patches.
```

Keep all changes represented in the combined bullet list. Related adjustments
may be combined when the final result remains clear. Extend an existing range
when another qualifying patch follows it; keep larger change sets under their
own headings. Do not combine released and unreleased entries. Grouping changes
only the changelog presentation: version changes require authorization under
Version consistency, and the range must include every version it represents.

Every push must include changelog coverage for **all changes since the previous
push**, not just the latest local version or the most recent user request. Local
iteration often spans many version increments before one public push.

Before committing and pushing a batch:

- Verify and record the current remote `origin/main` commit as the previous-push
  baseline **before** updating it. Review all commits and intended working-tree
  changes since that baseline, including staged, unstaged and new files.
- Cross-check that complete change set against every intervening local changelog
  entry. Include features, fixes, UI changes, behavior/default changes, tests,
  documentation and workflow changes; group related items for readability.
- Make the latest version's release entry a self-contained cumulative summary
  of the whole batch. Do not rely on readers finding older local-version entries
  to learn what the new release contains. Preserve historical entries and do not
  invent changes or describe superseded intermediate behavior as current.
- If any push since the last public release was push-only, the next published
  release must also cover those still-unreleased changes. Use the last published
  release tag as the additional baseline so they are not omitted.
- Ensure the changelog actually supplied to the packager, GitHub Release and
  CurseForge contains this complete summary. Check the publication configuration
  rather than assuming it includes every local entry automatically.

Changelog completeness is a required pre-push check, including for push-only
requests. A version bump or a final small fix must never hide the rest of the
accumulated batch. This requirement does not itself authorize a push or release.

## Packaging

Packaging is handled by BigWigsMods/packager.

CurseForge project metadata is stored in `AzerothFieldbook.toc`:

`## X-Curse-Project-ID: 1708795`

Packaging configuration is stored in `.pkgmeta`.

The distributable addon must be packaged as:

AzerothFieldbook/

Development-only content such as `tests/` and `.github/` must not be included
in the addon package.

Never commit API tokens, GitHub credentials, CurseForge credentials, or other
secrets.

`CF_API_TOKEN` is stored as a GitHub Actions repository secret.

## Version consistency

Azeroth Fieldbook uses semantic-style versioning while pre-1.0. Choose the
version number and release channel separately; `0.` does not imply Beta.

- Recommend a patch increment (`0.x.Y`, e.g. `0.17.0` → `0.17.1`) for bugs,
  regressions, small corrections, documentation/help or packaging fixes, and
  narrow behavioral corrections that do not materially expand the addon.
- Recommend a minor increment (`0.X.0`, e.g. `0.17.0` → `0.18.0`) for new
  user-facing features or substantial system expansion, including journal
  capabilities, scoring/rewards, storage/sharing behavior or meaningful UI
  functionality. Classify accumulated product behavior and scope, not commit
  count or diff size; a small feature diff does not make it a patch.
- Recommend **Beta** for intentional public testing or significant new behavior
  below the project's normal release-confidence threshold; recommend **Release**
  for the normal supported build. A typical sequence is `0.18.0-beta.1` →
  `0.18.0-beta.2` → `0.18.0` (Release). Sufficiently validated changes intended
  as the supported build may go directly to Release; development alone does
  not require a beta, and pre-1.0 versions can be normal stable Releases.
- Treat `1.0.0` as an explicit operator-decided project milestone, not an
  automatic consequence of stability. Pre-1.0 minor lines may continue to
  expand substantially. If 1.0 seems appropriate, recommend it with reasons;
  preserve the Beast Lore milestone in Scope and never transition automatically.

Track accumulated release scope as the operator dictates changes. When
versioning becomes relevant, proactively state the recommended next version,
present channel (Beta or Release), and a concise explanation of both choices
so the operator can learn from the decision. Revise the recommendation if scope
changes, such as a corrective `0.17.1` cycle gaining a feature warranting
`0.18.0`. Base the final recommendation on the entire accumulated release scope.

A recommendation is not publication authority. Without authorization from the
current task or explicit operator instruction, do not change the version, create
a release-preparation commit, create or push a tag, publish a GitHub or
CurseForge release, or change a CurseForge release channel. When no release
action is requested, maintain or report the recommendation as useful development
context. The explicit batch-push authorization in Git workflow remains valid;
recommendations do not replace existing testing, Git or publication safeguards.

When a version change is authorized:

- Update `## Version:` in `AzerothFieldbook.toc` to the agreed release version.
  Internal edits and test-fix iterations do not independently require bumps.
- Keep the README's current version and a versioned `CHANGELOG.md` entry in sync.
  Mark local versions unreleased until publication; preserve historical entries.
- Runtime version displays and sharing checks must read the TOC metadata. Do not
  add stale hardcoded version fallbacks or change SavedVariables schema numbers
  merely to reflect an addon-version increment.
- An authorized version change may precede commit or publication. Do not reuse
  an earlier completed version for later changes. Publish the final accumulated version;
  intermediate local versions do not require individual release tags.
- Changes to sharing compatibility must keep the explicit protocol/schema checks
  and installed-addon version check aligned. Both players must use the same addon
  version to offer/import reports; a new offer rejected for mismatch spends no points.

Before a release, ensure:

- TOC version matches the intended release version
- README current-version references are correct
- cumulative changelog covers the complete batch since the previous push and
  any earlier changes not yet included in a public release
- tests pass
- working tree is clean
- `main` is synchronized with `origin/main`
- the intended tag points to the correct commit

Do not retag or move an already published release tag without explicit operator
approval.

## CurseForge

CurseForge releases are automated through GitHub Actions.

Choose Beta or Release using Version consistency, independently of the `0.`
prefix. Beta builds serve users who accept testing versions; Release identifies
the normal supported build, including during pre-1.0 development.

CurseForge moderation occurs after upload and is outside the release workflow.
An automated upload succeeding does not imply CurseForge moderation approval.

Every release should represent meaningful changes and have an appropriate
changelog. Do not create trivial releases solely to increase project visibility.

## Automated checks and section architecture

During local iteration, use checks proportionate to the change: review the diff,
and run focused syntax or relevant tests only when useful. Do not rerun the full
suite or slow navigation, preservation, and lifecycle stress tests for every
small change. Documentation-only edits need only a diff review.

Reserve the full suite and slow stress tests for pre-commit validation of the
accumulated batch and pre-push/release checks, or an explicit operator request.
Reuse a passing full-suite result when the tested code has not changed; rerun
affected checks when subsequent changes warrant it.

For full validation, run `python -B -X utf8 tests/run_tests.py` from the repository root. Install the
pinned test dependency with `python -m pip install -r tests/requirements.txt`.
The suite contains both unittest modules and scripts with top-level Lua
assertions; unittest discovery alone is not a substitute for the full runner.
The tag-triggered release workflow must keep its dependency on the automated
test workflow so failing tagged commits cannot publish.

`FieldbookShell.lua` owns the main window and section/page navigation.
`BestiaryBook.lua` owns the Bestiary content; `BestiaryPages.lua` supplies its
Help, Options and Event log contents. See `tests/ARCHITECTURE.md` before adding
sections. Preserve existing window-position keys and Bestiary data compatibility.

## Decorative icon artwork workflow

For future icon-based parchment illustrations, use the Chronicle chained-book
process approved by the operator: start from an actual Blizzard game icon,
enlarge and clean its edges, then use imagegen with the kobold drawing as a
stroke-quality reference. Prefer loose pencil contours, variable pressure,
broken/searching lines and restrained cross-hatching over smooth vector outlines.
Preserve icon identity, geometry and orientation unless a flip is requested.
Remove paper and interior white fills; match the original kobold ink
(sampled RGB 75,32,2), retain alpha details, and use direct RGBA TGA rendering.
Do not replace cropped artwork with solid-colour native ink masks: that smeared
the drawings on this client. Default to 33% opacity, parchment edge fades and
dark-mode desaturation; respect each illustration's established exceptions.
Keep the prior asset as a fallback and visually inspect the new result before
installation. User-requested changes to placement and opacity take precedence.

## Scope

The operator reserves the 1.0 milestone for successful live Beast Lore testing
after the Forever beta level cap permits it, regardless of other sections'
progress. Meeting that condition does not authorize an automatic 1.0 transition;
the operator must explicitly decide. Earlier versions may be stable Releases.
The operator designated sharing as 0.9.0, section navigation as 0.10.0 and Herbs & Minerals as
0.11.0, Traveller’s Atlas as 0.12.0, Angler’s Almanac as 0.13.0, Merchant’s Ledger as 0.14.0,
Treasure Journal as 0.15.0, and Lorekeeper's Chronicle as 0.16.0.
Recommend subsequent patch or minor versions by accumulated scope under Version
consistency; apply version changes only when authorized.

Azeroth Fieldbook may later add further gathering or collection journals,
such as skinning, beyond its seven implemented sections.

Do not implement speculative future sections unless explicitly requested.

The existing monster journal should conceptually remain the Bestiary section of
the broader Azeroth Fieldbook.
