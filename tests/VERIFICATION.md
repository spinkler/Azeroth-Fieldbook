# Current verification record

Updated 2026-09-27 for 0.9.150 Beta. Older research documents retain historical
captures and limitations; this record distinguishes their status from current
operator confirmations.

| Area | Evidence and current status |
| --- | --- |
| Pet kill credit | Operator confirmed live testing and correct credit on 2026-09-27. The former missing-pet-event issue is resolved, subject to future regressions. |
| SavedVariables persistence | Operator confirmed on 2026-09-27 that the Forever bug is fixed and data/settings are saving correctly across reloads/logins. No longer blocked by the client. |
| Normal sharing | Earlier live delivery, receipt and recipient attribution are recorded in SHARING.md. General persistence is now confirmed. Individual interruption, faction and throttle cases remain regression scenarios, not newly claimed live passes. |
| Beast Lore | Live capture and two-player lore delivery await a beta level cap that permits testing the spell. Automated event, tooltip, storage and protocol tests do not replace this check. |
| Shared shell extraction | Automated tests cover lazy construction, section switching, preserved selection, page routing, closing, focus, legacy position restoration and inherited scaling. In-game visual acceptance of the refactor is not claimed. |
| Automatic buff recording | Live 0.9.138 testing showed Frost Armor (12544) missing from Recorded abilities. Read-only SavedVariables inspection found a Frost Armor removal flag on the unlocked wizard entry, with automatic recording enabled. 0.9.139 restores freshly verified buffs while enabled; the regression passes in the mock host. Live retesting is pending. See AUTO_BUFFS.md. |
| Automatic cast recording | Public-ID capture passes nine mocked regressions. Live 0.9.140 Fireball (20793) testing showed an eligible target and delivered cast events, but the supplied debug trace classified the IDs and active-cast names as SECRET. Those display-only values cannot be stored automatically. Live capture of a public combat ID remains unverified. See AUTO_BUFFS.md. |
| Copyable debug report | Local 0.9.141 opens the report in the foreground with all text selected for Ctrl+C, without chat duplication. Automated checks cover repeated opening, selection, partial reports after collection failures and independence from chat output. Native foreground behavior still needs a live check. |
| Last detected ability hint | Local 0.9.142 adds per-creature session hints with timestamp and guarded hover tooltip. Six automated scenarios cover opaque relay, events, polling, acknowledgement, persistence within the session and the book UI. Native rendering/tooltip behavior remains unverified; see DETECTED_ABILITIES.md. |
| Compact Spell ID window and blacklist | Local 0.9.144 adds upward resizing, populated-only sections, optional caster lines, dismissal and a character blacklist manager. Mock tests cover row geometry, anchor migration, caster handling, restricted values, filtering, persistence and the Options controls. Native layout and clicks still require SPELL_ID_WINDOW.md live checks. |
| Creature Locations | Local 0.9.145 adds zone maps, persisted kill positions, a labelled player-position fallback, and triangles limited to 180-yard edges. Automated regressions cover credit integration, secrets, storage, geometry, backups and window controls. The operator screenshot confirms an area rendered in-game. 0.9.146 changes it to violet with a boundary glow and adds saved terrain brightness; the new styling and exact NPC-coordinate availability require the pending LOCATIONS.md checklist. 0.9.147 adds right/top book anchoring and parchment tied to UI brightness. |

The operator intends to continue with 0.x Beta milestones for additional journal
sections. Stable 1.0 is reserved for successful Beast Lore live testing,
independently of how many other sections have shipped.

## Automated checks

From the repository root, using Python 3.12:

```text
python -m pip install -r tests/requirements.txt
python -B -X utf8 tests/run_tests.py
```

The runner compiles every runtime file with Lua 5.1, validates the TOC and binding
XML, checks the current README/changelog version, and checks release tags against
the TOC when running in GitHub Actions. It executes every `test_*.py` file in a
separate process, including the scripts that do not use unittest discovery.
Any failed validation or script fails the run.

Local validation for this batch passed all 32 test files and compiled all 32
runtime Lua files. Automatic recording has fourteen buff capture/storage/UI checks
and nine combat-cast checks. Native rendering remains outside the mock test host.

The reusable tests workflow runs on main pushes and pull requests. The release
workflow also calls it for the exact tagged commit and requires its success
before invoking the packager. Local `.codex-test-deps` is optional; a clean
checkout uses the pinned pip dependency.

## Candidate smoke check

For automatic buff recording, use [AUTO_BUFFS.md](AUTO_BUFFS.md), including the
Frost Armor reproduction, option persistence, combat recovery, combat casts and
the blue [A].

For the last-cast hint, use [DETECTED_ABILITIES.md](DETECTED_ABILITIES.md), including
session retention, manual acknowledgement, form spacing and tooltip behavior.

For the shell extraction, verify the normal and mouseover bindings, minimap and
`/fieldbook`, the saved main-window position, dragging and scale, Help/Options
toggling, Event log, and closing via Escape. Open observation windows, enter
notes, and check that the Bestiary layout and selection behave as before.
Check the shared-only question marks and disabled-control explanations, then
personally encounter the creature. This is the focused in-game check for the
new batch; it does not reopen the resolved pet-credit or persistence blocker.

Use [BEAST_LORE.md](BEAST_LORE.md) once the spell can be tested. Exercise capture,
target changes, delayed fields, repeated casts, persistence, backup/restore,
zero-cost delivery and personal/shared precedence before declaring stable 1.0.

Publication baseline for v0.9.150-beta: origin/main and v0.9.137-beta both resolve
to be1016c4824b7fa77d1d1c571ff14c6aa0ac561c, verified before publication.
The cumulative release entry covers all changes since that baseline.
