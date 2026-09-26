# Current verification record

Updated 2026-09-27 for 0.9.137 Beta. Older research documents retain historical
captures and limitations; this record distinguishes their status from current
operator confirmations.

| Area | Evidence and current status |
| --- | --- |
| Pet kill credit | Operator confirmed live testing and correct credit on 2026-09-27. The former missing-pet-event issue is resolved, subject to future regressions. |
| SavedVariables persistence | Operator confirmed on 2026-09-27 that the Forever bug is fixed and data/settings are saving correctly across reloads/logins. No longer blocked by the client. |
| Normal sharing | Earlier live delivery, receipt and recipient attribution are recorded in SHARING.md. General persistence is now confirmed. Individual interruption, faction and throttle cases remain regression scenarios, not newly claimed live passes. |
| Beast Lore | Live capture and two-player lore delivery await a beta level cap that permits testing the spell. Automated event, tooltip, storage and protocol tests do not replace this check. |
| Shared shell extraction | Automated tests cover lazy construction, section switching, preserved selection, page routing, closing, focus, legacy position restoration and inherited scaling. In-game visual acceptance of the refactor is not claimed. |

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

Local validation for this batch passed all 27 test files and compiled all 26
runtime Lua files. The new shell suite includes four navigation/integration
checks; native rendering remains outside the mock test host.

The reusable tests workflow runs on main pushes and pull requests. The release
workflow also calls it for the exact tagged commit and requires its success
before invoking the packager. Local `.codex-test-deps` is optional; a clean
checkout uses the pinned pip dependency.

## Candidate smoke check

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
