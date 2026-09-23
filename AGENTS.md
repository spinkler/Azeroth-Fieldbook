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

Normal development should be:

1. Make and test changes.
2. Commit them to `main`.
3. Push `main` to GitHub.

Normal pushes to `main` DO NOT publish a release.

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

Before creating or pushing any `v*` tag, obtain explicit approval from the
operator.

Current release naming convention:

- `v0.7.2-alpha` = Alpha/prerelease
- `v0.7.2-beta` = Beta/prerelease
- `v1.0.0` = stable Release

The BigWigsMods packager determines release type from the tag name.

The normal release sequence is:

1. Update `## Version:` in `AzerothFieldbook.toc`.
2. Update current-version references in `README.md` where appropriate.
3. Commit the version preparation.
4. Push `main`.
5. Verify the working tree is clean and `main` matches `origin/main`.
6. Create an annotated release tag only after explicit operator approval.
7. Push only that tag.

The tag push automatically:

- packages the addon
- creates a GitHub Release
- attaches the distributable ZIP
- uploads the same release to CurseForge

Do not manually create a GitHub Release or manually upload a CurseForge build
unless explicitly requested or recovering from automation failure.

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

Before a release, ensure:

- TOC version matches the intended release version
- README current-version references are correct
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
