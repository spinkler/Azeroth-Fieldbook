# AGENTS.md — Azeroth Fieldbook

## Project

Azeroth Fieldbook is a World of Warcraft addon created by Spinkler.

Current functionality is the Bestiary: a personal monster journal that learns
about creatures from the player's own encounters.

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

1. Make the requested change and increment the addon version as described below.
2. Test it and update the changelog and current-version references.
3. Leave it ready for review. Do not automatically commit or push each change.
4. When the operator explicitly requests a batch push, commit the accumulated
   changes to `main`, push `main`, and publish the current version using the
   matching annotated Beta tag and the release workflow below.

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
6. Create an annotated `v<TOC version>-beta` tag under the operator's release or
   batch-push authorization, unless another release channel was requested.
7. Push only that tag.

The tag push automatically:

- packages the addon
- creates a GitHub Release
- attaches the distributable ZIP
- uploads the same release to CurseForge

Do not manually create a GitHub Release or manually upload a CurseForge build
unless explicitly requested or recovering from automation failure.

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
only the changelog presentation: each completed request still advances the
addon version, and the range must include every version it represents.

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

Every completed user-requested change set must visibly advance the addon version,
even while changes remain uncommitted and unpublished. This applies to code, UI,
fixes, tests, documentation and workflow changes. Read-only work needs no bump.

Routine changes increment the **last numeric component**:
`0.9.0` → `0.9.1` → `0.9.2`. The operator explicitly designated the sharing
feature milestone as **0.9.0**. Larger version jumps follow explicit operator
instructions; otherwise keep the first two components unchanged.

- Increment `## Version:` in `AzerothFieldbook.toc` once per completed change set.
  Internal edits and test-fix iterations for that same request share one bump;
  a subsequent request that changes the project requires another increment.
- Keep the README's current version and a versioned `CHANGELOG.md` entry in sync.
  Mark local versions unreleased until publication; preserve historical entries.
- Runtime version displays and sharing checks must read the TOC metadata. Do not
  add stale hardcoded version fallbacks or change SavedVariables schema numbers
  merely to reflect an addon-version increment.
- Do not wait for a commit or release to bump the number, and do not reuse an
  earlier completed version for later changes. Publish the latest accumulated
  version; intermediate local versions do not require individual release tags.
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

During early development, CurseForge builds use Beta release tags so they can
be distributed through the CurseForge app to users who accept Beta versions.

CurseForge moderation occurs after upload and is outside the release workflow.
An automated upload succeeding does not imply CurseForge moderation approval.

Every release should represent meaningful changes and have an appropriate
changelog. Do not create trivial releases solely to increase project visibility.

## Scope

Azeroth Fieldbook may later expand beyond the Bestiary into gathering or
collection journals such as herbs, minerals, or skinning.

Do not implement speculative future sections unless explicitly requested.

The existing monster journal should conceptually remain the Bestiary section of
the broader Azeroth Fieldbook.
