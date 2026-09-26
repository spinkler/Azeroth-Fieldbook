# Kill attribution: implementation and live evidence

## Current verification — 2026-09-27

The operator has tested pet kills and confirmed that they give credit correctly.
The Forever SavedVariables bug is also fixed, with data/settings persisting
across reloads/logins. These confirmations supersede the older unverified-pet
and blocked-persistence status below. Historical captures remain for diagnosis;
they are not the current release checklist. See [VERIFICATION.md](VERIFICATION.md).

## Current policy — 0.9.119

The user's current rule is **tag eligibility**, replacing the historical
finishing-blow restriction below. A recently observed creature's death counts
when the client reports `UnitExists == true`, `UnitPlayerControlled == false`
and `UnitIsTapDenied == false` for that exact full GUID at kill/death time.
Player, pet, party, raid or outside finishing blows are treated alike. No XP,
level, loot drop, loot distribution or current `CanLootUnit` result gates credit.
Missing, secret or invalid eligibility still waits rather than guessing; an
explicit denied tag rejects the instance. Ordinary living unclaimed mobs do not
provide cached eligibility and first discovering a corpse does not count.

`PARTY_KILL` is now optional: it can sample eligibility before the target clears,
but neither the event nor an attacker/group-membership match is required.
`UNIT_DIED` or a readable watched alive-to-dead transition supplies death evidence.
If the target clears before eligibility can be read, a matching corpse mouseover
can complete the pending kill within ten seconds. If eligibility never becomes
readable, the kill remains uncounted. Existing observation bounds, world/reset
invalidation, saved GUID replay protection and milestone accounting remain.

### Build 70009 reproduction and validation

The September 26 captures show a personal Kobold Tunneler kill advancing 49 to
50 and awarding the crown. A subsequent level-5 Tunneler (GUID suffix
`0000B77B65`) emits `UNIT_DIED` at 7764.886, clears the target, then appears as a
mouseover corpse with readable `tapDenied=false`. It emits no `PARTY_KILL` and
the old gate expires it at 7775.061. The user confirmed pet finishing blows cause
the failure regardless of creature level. The new gate accepts that eligible
death without requiring an attacker event or waiting for loot.

Automated tests cover this ordering, pet/party/raid roles, outside finishers,
low-level and no-loot deaths, denied and unreadable tags, first-seen corpses,
49 → 50 → 51 with no `PARTY_KILL`, duplicate suppression and reload persistence.
Mocks validate the policy and recorded ordering, not additional live API behavior.
Pet credit was subsequently confirmed in game by the operator on 2026-09-27.
For future regressions, repeat an eligible pet kill, corpse reinspection and a
denied-tag kill. The operator confirmation does not supply a new per-scenario
capture or exact client build number.

## Historical implementation and captures (0.9.11 onward)

Status statements in this archive describe their original test dates. Current
pet-credit and persistence status is recorded at the top of this document.

The remainder records the previous finishing-blow policy and its original
validation. Its actor/event requirements are superseded by 0.9.119 above.

Status: implemented locally against **main, HEAD f33e392, addon 0.9.11**.
The automated checks passed. Solo event delivery with and without XP was observed
on the installed Forever client. Live acceptance now confirms a party member's
finishing blow counts once through the new production gate, corpse reinspection
does not duplicate it, and an unrelated watched death receives no credit. A
personal finishing blow on another player's tag is also correctly rejected.
Own zero-XP, no-loot ram and squirrel kills have now passed through the production
gate. Pet coverage remains unverified live. Live reload/relog acceptance is blocked
by the user-reported Forever client bug that incorrectly reloads SavedVariables;
the operator confirmed this cannot currently be tested. Automated persistence
checks passed, but do not establish working persistence in that client.
Nothing is committed, pushed, tagged or published; this attribution work adds no
version bump.
Existing sharing/Rumours/ledger work is preserved.

## Final policy and root cause

The user's latest clarification requires the player, their pet, or a party member
to make the kill, with this character eligible for its credit. Actual loot drops
and XP are not required. An ungrouped friend's finishing blow is excluded under
this clarified rule, even if the player's earlier tag yielded XP or loot.

Previously `RecordKill` checked death, identity and deduplication, but no credit.
`UnitPlayerControlled == false` excluded player-controlled NPCs; it did not mean
that this character owned a kill. The alive-observation fallback had the same
problem. A first corpse scan could create an entry; the next could award a kill.

Affected callers were `observeCurrent` (target/mouseover changes, matched casts,
and the existing 0.2-second scanner) and `UNIT_HEALTH` (including watched aliases).
Both now reach the same gated completion function as the new GUID-bearing events.
Only that completion function increments kills and runs the milestone award path.
`Ensure` and `recordDiscovery` still separately award permitted discovery points.

## Evidence model

Each accepted kill requires all of these, bound to one full creature GUID:

1. A recently observed living, eligible target/mouseover NPC instance. A journal
   entry or imported creature record cannot supply this observation.
2. A readable standalone `PARTY_KILL(attackerGUID, targetGUID)`, whose attacker
   matches the readable GUID of `player`, `pet`, `party1` through `party4`, or one
   of those party members' pets. Membership alone is never a kill signal.
3. Readable eligibility sampled from the exact victim at a kill/death event or
   corpse observation: `UnitExists == true`, `UnitPlayerControlled == false`,
   and `UnitIsTapDenied == false`. GUIDs are rechecked around token queries.
4. Independent death evidence: `UNIT_DIED` with that GUID, or readable
   `UnitIsDead == true` for that same instance.
5. No accepted-death replay record for that GUID.

False tap denial is **not** positive evidence by itself. In the live captures it
was also false on untouched creatures. The qualifying attacker event and death
must be present as well; someone else's denied tap rejects even a player/party
finishing blow. Missing, nil, throwing, invalid or secret values do not qualify.
An explicit denial cannot be undone by a later cleared denial on that corpse.

No XP, loot, quest, reputation, threat or damage-total condition grants credit.
`CanLootUnit` and legacy tap functions are diagnostic probes only. There is no
combat-log subscription or attempt to inspect restricted values/error payloads.

The tested solo event/death/tap combination distinguishes the user's own kills
from unrelated deaths without relying on XP. One party-assisted kill has now
passed through the production gate with a readable non-player attacker and no
duplicate reward. Pet delivery, range, party changes and loot-method edge cases
remain unverified. This is not a claim that all possible Forever credit behavior
has been established.

## Ordering, resets and bounded storage

- Instance identity is kept by GUID, never by a reusable unit token. The in-memory
  table holds at most **64** observations, refreshed while observed alive and
  expiring **120 seconds** after their last living observation.
- The first kill/death evidence starts a **10-second** pending window. Repeated
  notifications/scans do not extend it. Either event ordering is supported, and
  late readable eligibility can finish a pending death exactly once.
- Ordinary living tap state is not cached as credit. Terminal eligibility is
  retained only during that bounded pending window. A living reset/out-of-combat
  or unknown combat state clears terminal evidence; a world change, journal
  reset or entry deletion clears the associated instance evidence. Expired or
  evicted evidence cannot turn into a guessed kill.
- Accepted records are consumed before callbacks. The last **512** counted GUIDs
  persist in `bestiary.recentKills`, with no schema/version bump or reward replay.
  The existing ledger's last 16 GUIDs per creature remain intact and bounded.
- Reload/relog clears pending/living observations. Re-hovering a corpse supplies
  neither a living observation nor a fresh qualifying kill event, including after
  a replay GUID eventually falls out of the saved ring. Repeated loading is
  idempotent and preserves earned/spent/reserved points.

The existing watched-unit scope is retained. Kills not recently observed alive,
notifications outside the pending window, unreadable evidence, or missing event
support are conservatively missed. No broad enemy scanning or new timer is added.
Raid-wide attribution is not added; the clarified policy is player/pet/party.

## Changed files and rewards

- `BestiaryJournal.lua`: central attribution gate, bounded instance/pending state,
  eligibility/actor checks, replay persistence and normal milestone accounting.
- `AzerothFieldbook.lua`: standalone event routing, world-change invalidation and
  diagnostic slash commands. Event registration failure leaves kills uncredited.
- `DebugReport.lua`: opt-in 80-record diagnostic ring; actual accepted/rejected,
  pending, duplicate, stale and expired decisions include kill/point awards.
  Raw event records and observation snapshots are distinguished from decisions.
- `tests/kill_test_harness.py`, `test_kill_attribution.py`,
  `test_kill_diagnostics.py`: real event/scan integration and diagnostic tests.
- Existing `test_observed.py`, `test_journal.py` and `test_sharing.py`: reward
  fixtures now include qualifying kill evidence; their other assertions remain.
- `README.md`, `CHANGELOG.md`, and this report document the change.

As of 0.9.21, thresholds are **10 kills: silver/+1; 25 kills: gold/+2 more;
50 kills: gold crown/+3 more**, 6 cumulative kill points. Existing personal entries
receive newly available crown credit once on load; old silver credit is preserved.
Discovery, notes, abilities, locks, spending and sharing transactions
are preserved. No historical counts are reset or points removed. Historical data
cannot reliably distinguish legitimate kills from the old incorrect attribution.

## Matching source and observed client behavior

Installed `WowB.exe`, `.build.info` and every live capture identify
**Forever 1.60.1.69977 / interface 16001**. Research uses Gethe's pinned Forever
snapshot [`c6e89983189e4f626f549204a23c2d2bea93080a`](https://github.com/Gethe/wow-ui-source/commit/c6e89983189e4f626f549204a23c2d2bea93080a),
whose commit message is `1.60.1 (69977)`, rather than a moving-branch web cache.

- [Unit documentation](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
  declares standalone `PARTY_KILL` with attacker/victim GUIDs and `UNIT_DIED`
  with a victim GUID, both conditionally secret; it documents the boolean
  `UnitIsTapDenied(unit)` and token-bearing flag/faction notifications.
- [Camelot target frame](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_UnitFrame/Camelot/TargetFrame.lua)
  uses denial to grey a target; that alone does not establish positive ownership.
- [CombatLog documentation](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogDocumentation.lua)
  marks the separate combat-log callback events restricted. They are not used.
- [PlayerScript documentation](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua)
  documents `CanLootUnit(GUID)` with two separate booleans, `hasLoot` and `canLoot`.
  Its zero-drop semantics have not been established; it cannot authorize a kill.

The original diagnostic revision suspended awards while collecting these captures:

| Capture | Observed result |
| --- | --- |
| Unrelated player kills Forest Lurker, NPC 1195, GUID ending `00013552FD` (attachment `4deeddfd-c2ca-47c0-a3cc-0b555feda273`) | Untouched: denial false. Other player's tag: denial true, still true on corpse. Exact `UNIT_DIED`; zero `PARTY_KILL`. Discovery points 7 to 8 before combat/death. |
| Solo Tunnel Rat Scout, NPC 1173, ending `0000B55487` (`1dff73b6-2480-4167-84f2-31805c64056f`) | One readable `PARTY_KILL`, attacker matches player, victim matches observed GUID and `UNIT_DIED`. One XP notification. Target clears at death. Denial false throughout. |
| Solo zero-XP Tunnel Rat Vermin, NPC 1172, ending `0000355510` (`4c364d79-8947-4c63-8ad0-a696bb2abcbe`) | One readable matching `PARTY_KILL` and `UNIT_DIED`; zero XP notifications. Other nearby corpses/deaths share the NPC ID but have different GUIDs. Hovering another level-11 corpse adds a discovery point while the level-10 target remains alive. |
| Ungrouped friend finishes the player's tagged Elder Black Bear, NPC 1186, ending `000035552C` (user's inline response) | Exact `UNIT_DIED`, loot notification and XP, but zero `PARTY_KILL`; denial false. This disproves using `PARTY_KILL` as universal game reward credit. The user then clarified that the kill must be made by player/party, so this outsider finish is now excluded. |

`UnitIsTappedByPlayer` was absent at runtime. HP was secret, while the tested
GUIDs and `UnitIsDead` were readable. Neither secret HP nor an XP event was used
to recover identity or infer a nearby death's credit.

### Production-gate acceptance: party-assisted Mountain Boar

Attachment `5bfbab94-ece4-46a9-a0da-21a3d4bcedd8` reports revision 3 with qualified
kill tracking active on the same client/build. This is the response to the
party-assisted live test:

- Mountain Boar, NPC **1190**, full GUID
  `Creature-0-6782-0-59358-1190-0000355BDE`, was observed alive with readable
  `tapDenied=false`. It had zero saved kills before the fight.
- At **148684.681**, `PARTY_KILL` reports attacker `Player-4613-00D527EA`
  (Erna), distinct from player `Player-4613-00CCEA49`. The gate recognizes the
  attacker and waits for death; it does not award on that event alone.
- `UNIT_DIED` for the exact victim completes the pending evidence in the same
  timestamp. There is exactly one `accepted; killAward=1; killPointsAward=1`.
  The subsequent corpse samples show `savedKills=1; killTierPoints=1`.
  These point values describe the running build in this capture; the separately
  0.9.2 update required two kills for silver; the current thresholds are listed above.
- Corpse hover at **148686.241** reports `duplicate; killAward=0;
  killPointsAward=0`. Later targeting and repeated hovering retain one saved kill.
- Earlier in the same capture, Forest Lurker NPC 1195, ending `0000B55B8A`, was
  observed alive with denial true and then died. It received no qualifying
  `PARTY_KILL`; the gate reported pending at **148600.649** and expired at
  **148614.024**, both with zero kill/point awards. A different already-dead
  Forest Lurker, ending `0000B55B72`, also showed zero saved kills. The only
  accepted decision anywhere in this capture belongs to the Mountain Boar.
- Total earned points rose from 6 to 9 before the accepted kill, while the
  sampled kill counts remained zero. Those earlier changes must not be confused
  with kill rewards. The accepted kill changes the total from 9 to 10.
- `CanLootUnit` returned `hasLoot=true,canLoot=false` for the accepted party corpse.
  This capture does not establish a universal loot-entitlement predicate; both
  return values remain diagnostic only and do not gate credit.

### Production-gate acceptance: own finishing blow on another player's tag

Attachment `dfbdc871-23b3-4552-8949-a011ab84369a` reports revision 3 on the same
client/build, in response to the ungrouped-friend-tags/player-finishes test:

- Elder Black Bear, NPC **1186**, full GUID
  `Creature-0-6782-0-59358-1186-0000355E78`, was observed alive before combat.
  At **149402.552**, `UNIT_FACTION` reports `tapDenied=true`; it remains true
  through the player's attack and subsequent corpse inspections.
- At **149409.637**, `PARTY_KILL` names attacker `Player-4613-00CCEA49`, matching
  the player, with the exact observed victim GUID. `UNIT_DIED` names that same
  victim. Thus this test exercises the eligibility check despite a qualifying
  personal finishing-blow event; the lack of credit is not due to a missing event.
- The gate reports `rejected: tap denied or player-controlled; killAward=0;
  killPointsAward=0`. The victim's `controlled=false` and `tapDenied=true` samples
  identify tap denial as the rejection reason. There are no accepted decisions.
- Repeated corpse hovering and targeting retain `savedKills=0; killTierPoints=0`.
  `totalEarned=11` remains unchanged throughout the entire capture. XP and loot
  notifications are both zero, but neither was needed to reject the kill.
- The loot probe reports `hasLoot=false,canLoot=true` before death and on the
  denied corpse. The `canLoot` return alone therefore cannot establish ownership
  for this policy and must not override readable tap denial. The production gate
  correctly ignores this research probe.

### Production-gate acceptance: zero-XP, no-loot ram and squirrel

Attachment `608fef5d-ba7e-4909-8e94-429eb8f5767a` contains the level-5 Ram test;
the user's following inline report contains the level-1 Squirrel test. Both
report revision 3 with qualified tracking active on the same client/build:

- Ram, NPC **2098**, full GUID `Creature-0-6782-0-59358-2098-0000355318`, was
  observed alive with zero saved kills and readable `tapDenied=false`. At
  **149949.625**, a matching personal `PARTY_KILL` followed by same-GUID death
  produces exactly one `accepted; killAward=1; killPointsAward=0`. Subsequent
  corpse scans show `savedKills=1; killTierPoints=0`; repeated inspection reports
  duplicate with no further awards. Total earned points remain 13 throughout.
- Squirrel, NPC **1412**, full GUID `Creature-0-6782-0-59358-1412-00003547BD`, was
  also observed alive with zero saved kills and readable `tapDenied=false`. At
  **150046.482**, the player's exact-GUID `PARTY_KILL` first waits for death;
  matching death evidence then produces one `accepted; killAward=1;
  killPointsAward=0`. HP remains secret and is not needed for attribution.
- Both captures record **zero `PLAYER_XP_UPDATE` and zero `UNIT_LOOT` events**.
  Both corpse probes report `hasLoot=false`; the squirrel also reports
  `canLoot=false` throughout. Its qualifying kill still counts, demonstrating
  that neither actual loot nor a true loot-probe return is required.
- The squirrel's earned total increases **7 to 8 at 150045.242**, while it is
  still alive and before the kill at 150046.482. That is the discovery increase,
  not a kill reward. The total stays 8 at death. Zero kill points for these first
  kills matches the capture-time **two kills for silver** milestone and the current
  ten-kill threshold.
- A nearby Mountain Boar death, ending `0000356062`, in the ram capture has no
  qualifying `PARTY_KILL` and remains uncredited. The ram's credit is not applied
  to that unrelated GUID.

The differing starting earned totals are from separate captures without a supplied
reset/reload sequence; they do not establish persistence behavior or a data-loss
cause. These grey-level kills establish no-XP acceptance, not actual level-cap
event compatibility. No code correction was needed for these production captures.

## Automated checks

Run from the AzerothFieldbook repository with the existing Python/lupa runtime:

```powershell
$testPython = 'C:\Users\Spinkler\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $testPython -B tests/test_kill_attribution.py
& $testPython -B tests/test_kill_diagnostics.py
$failedTests = @()
$testFiles = @(Get-ChildItem -LiteralPath tests -Filter 'test_*.py' | Sort-Object Name)
foreach ($testFile in $testFiles) {
    & $testPython -B $testFile.FullName
    if ($LASTEXITCODE -ne 0) { $failedTests += $testFile.Name }
}
[pscustomobject]@{Files=$testFiles.Count;Failures=$failedTests} | ConvertTo-Json -Compress
if ($failedTests.Count -gt 0) { exit 1 }
git diff --check
```

Before fixing production code, the real scan regressions produced four failures:
mouseover/target corpse inspection, observed-alive unrelated death, and untagged
death. After implementation: **15 test files pass**, including **20 attribution
methods and six diagnostic methods**; `git diff --check` passes. No skipped or
expected-failure markers hide these regressions. Group/pet and capped no-XP mocks
verify the policy only; live evidence is limited to the scenarios recorded above.

## Live acceptance status and client blocker

The operator explicitly confirmed that reload behavior **cannot currently be
tested** because the Forever client does not reload SavedVariables correctly.
The previously requested same-corpse reload test is withdrawn. Do not request
another reload/relog persistence test while this client issue remains unresolved.

Automated reload, replay protection, idempotent loading and point-preservation
checks passed. Live persistence remains **blocked, not passed**. This client
limitation does not invalidate the completed same-session attribution tests and
does not justify changing the attribution gate or rewriting existing saved data.
Revisit live persistence only after the operator reports that the client issue
is resolved. Pet delivery and actual level-cap coverage remain unverified live.

Party-assisted credit, same-session duplicate protection, an unrelated watched
death, another player's tag despite a personal finishing blow, and own zero-XP,
no-loot kills have passed in the production captures above. A discovery point can
still occur during inspection; it must not be mistaken for a kill reward.
