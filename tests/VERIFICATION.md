# Current verification record

Updated 2026-09-27 for 0.10.8 Beta. Older research documents retain historical
captures and limitations; this record distinguishes their status from current
operator confirmations.

| Area | Evidence and current status |
| --- | --- |
| Pet kill credit | Operator confirmed live testing and correct credit on 2026-09-27. The former missing-pet-event issue is resolved, subject to future regressions. |
| SavedVariables persistence | Operator confirmed on 2026-09-27 that the Forever bug is fixed and data/settings are saving correctly across reloads/logins. No longer blocked by the client. |
| Normal sharing | Earlier live delivery, receipt and recipient attribution are recorded in SHARING.md. General persistence is now confirmed. Individual interruption, faction and throttle cases remain regression scenarios, not newly claimed live passes. |
| Beast Lore | Live capture and two-player lore delivery await a beta level cap that permits testing the spell. Automated event, tooltip, storage and protocol tests do not replace this check. |
| Index layering | 0.10.8 places Index/A–Z buttons exactly one frame level below native/fallback trim and above parchment, with mouse-disabled trim and title controls above it. Widget checks pass; the inset rolodex appearance and native hit regions await in-game verification. |
| Shared shell extraction | Automated tests cover lazy construction, section switching, preserved selection, page routing, closing, focus, legacy position restoration and inherited scaling. In-game visual acceptance of the refactor is not claimed. |
| Seven-section navigation | 0.10.0 adds the native right-side tabs and six wishlist pages. Automated checks cover order, default/active selection, tooltip routing, exact text, section lifetimes, Bestiary state, explicit creature opening, supported scales, full-column bounds and auxiliary placement. All seven icon files were read and decoded from installed Forever 1.60.1.70009 archives. Native rendering remains pending; see [SECTION_NAVIGATION.md](SECTION_NAVIGATION.md). |
| Airborne observations and map layers | 0.10.1 covers explicit flight selection, mouseover-open entries without map points, visibility range, first personal Event log entries, target-time player coordinates, violet/cyan layer switching, brightness independence, scope merging, backup validation and sharing isolation. Full live acceptance remains pending in [LOCATIONS.md](LOCATIONS.md). |
| Skull presentation | Automated checks cover maximum-level sorting, marker replacement and the 18px info skull. The operator confirmed list placement; the 2px upward info-skull adjustment awaits visual acceptance. See [BEHAVIOUR_EMOTES.md](BEHAVIOUR_EMOTES.md). |
| Basic information colours | 0.10.5 uses Blizzard's creature-difficulty API for each Level Range endpoint and its tooltip faction palette for disposition. Three difficulty scenarios cover native-band delegation, independent endpoints, effective-level refresh on locked pages and missing/restricted/error fallbacks; disposition tests check palette use. Native colours, wrapping and level-up rendering still require an in-game check. |
| Zone colours and entry keys | 0.10.5 uses the minimap territory palette with a bounded faction-specific cache of visited zones. Four tests cover palette rendering, silent zone events, locked pages, subzone/restricted-data guards, cache limits, persistence, backup/account merging and sharing isolation. Two navigation tests cover binding XML/global routing, lazy/hidden/inactive guards, typing, filters, sorting, wrapping and scrolling. The operator found a synthetic header action under Other; 0.10.6 replaces the legacy header with explicit categories on all four actions, covered by XML regression checks. Native heading acceptance, zone colours and assigned key presses remain pending; see [BASIC_INFO_COLOURS.md](BASIC_INFO_COLOURS.md). |
| Flee recording follow-up | The operator confirmed flee recording works after 0.10.2. The precise original live payload rejection remains unconfirmed; an absent-GUID failure was reproduced and fixed using an unambiguous watched-creature match. Chat/Event log notices and `/fieldbook debug` diagnostics have automated coverage. |
| Automatic behaviours and locked entries | 0.10.5 preserves cyan [A] history through toggles and restores unchecked marks on fresh evidence. Hostile / Neutral now update quietly as red/yellow basic information, with no behaviour controls or notices. Automatic behaviours and verified abilities can update locked entries. Ten behaviour and five reaction scenarios cover storage, notice suppression for disposition, UI wiring, migration, restrictions, reloads and backups; buff/cast tests cover locked capture. New native styling, reaction observations and lock/override cycles still require the in-game checklist in [BEHAVIOUR_EMOTES.md](BEHAVIOUR_EMOTES.md). |
| Automatic buff recording | Live 0.9.138 testing showed Frost Armor (12544) missing from Recorded abilities. Read-only SavedVariables inspection found a Frost Armor removal flag on the unlocked wizard entry, with automatic recording enabled. 0.9.139 restores freshly verified buffs while enabled; the regression passes in the mock host. Live retesting is pending. See AUTO_BUFFS.md. |
| Automatic cast recording | Public-ID capture passes ten mocked regressions, including locked capture. Live 0.9.140 Fireball (20793) testing showed an eligible target and delivered cast events, but the supplied debug trace classified the IDs and active-cast names as SECRET. Those display-only values cannot be stored automatically. Live capture of a public combat ID remains unverified. See AUTO_BUFFS.md. |
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

Local validation for 0.10.8 passed all 39 test files and compiled all 33
runtime Lua files. Automatic recording has fourteen buff capture/storage/UI checks
and ten combat-cast checks. Native rendering remains outside the mock test host.

The reusable tests workflow runs on main pushes and pull requests. The release
workflow also calls it for the exact tagged commit and requires its success
before invoking the packager. Local `.codex-test-deps` is optional; a clean
checkout uses the pinned pip dependency.

## Candidate smoke check

For the seven-section window, follow [SECTION_NAVIGATION.md](SECTION_NAVIGATION.md).
It separates local asset verification and automated behavior/geometry checks from
the pending in-game tab, text, scale and Bestiary acceptance pass.

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

## Flight discovery and skull levels (updated 0.10.1)

Automated `test_discovery_rules.py` covers taxi/flying mouseover exclusions,
explicit targets, landing, hidden/secret/error effective levels, deferred discovery
and kill Knowledge, locked skull placeholders, UI skull replacement and Help text.
`test_observation_tracking.py` adds deliberate mouseover-open during flight,
explicit targets beyond the visibility range, first personal encounters of named
shared entries in the Event log, and target-time player coordinates. Passive
hovering, mouseover-open and polls cannot create observation-map trails. `test_sorting.py` covers
skulls as the highest maximum level with stable ties and reversible ordering.
The pinned 1.60.1 target-frame source uses UnitEffectiveLevel for the level/skull
decision; Fieldbook now follows it, with no hardcoded player-level difference.

Pending live checks:
- On a flight path, hover a new NPC: no discovery. Target it or use the
  mouseover-open binding: readable basics and one Event log entry appear,
  including at the edge of render range. The cyan layer records your position
  only when targeting; mouseover-open must not add a map point.
- Target a skull NPC: both the name marker and enlarged info skull appear, with
  no Knowledge. Sort by Max Level descending/ascending and check its placement.
- Observe that NPC later with a visible level: the skull becomes a range and
  discovery Knowledge is awarded once. Existing historical ranges remain intact.
- Compare native and Fieldbook levels for a creature 10+ levels above the player.
  If the client supplies a positive effective level, Fieldbook records it; this
  does not independently establish whether Forever's level visibility is a bug.

Locations 0.9.152: automated coverage verifies the empty-state footer and player-arrow movement, facing, zone changes, terrain-brightness independence and unavailable/restricted coordinates. Pending live check: confirm arrow orientation and size while moving/turning, and its disappearance when another zone is selected.
