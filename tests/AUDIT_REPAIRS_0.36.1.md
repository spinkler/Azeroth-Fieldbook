# Focused audit repair contract

Baseline: 0.36.1, `2a63240e034f8455a1d9d087e2c8a80cad442ed4`.
All ten supplied pre-fix probes reproduced. They assert OLD behavior, so they
are evidence, not post-fix regression tests. No native measurements are implied.

| Finding | Implementation and automated evidence |
| --- | --- |
| A1 | Full reset retains AccountDB.nextCharacter only. Existing old-backup high-water preservation remains. `test_reset_ownership.py`: three owners, both return orders, new arrival first, repeated resets, older backup, one-time imports and per-owner delivery storage. |
| A2 | Missing old-format Annals stages a full detached literal copy before root replacement. `test_restore_annals_atomic.py`: accepted/completed/removed pending evidence, failure after actual startup, identity and deep-content comparison of nine roots, cancel/retry and success. |
| A3 | Matching failure/interrupt clears pending and buffered pocket evidence. Expiry permits current ordinary snapshots but discards expired replays. `test_failed_pick_corpse.py` plus existing Bestiary/Ledger tests. |
| A4 | Matching open completion transactions recover readable reward data without downgrading observed evidence; transaction tokens, chosen index and event/post-hook ordering remain authoritative. `test_annals_reward_refresh.py` and existing Annals cases. Closed, changed, expired and finalized snapshots cannot borrow current APIs. |
| A5 | Entrance references use Atlas's durable origin/serial allocator; imports copy them. Annals selects `entrance:<id>` and verifies selected state. Old timestamp links resolve via this character's retained original and, for earlier imports, an unambiguous owner-prefixed entrance with matching immutable traversal evidence. No timestamp-only account search. `test_annals_entrance_navigation.py`, `test_annals_entrance_import.py`. |
| A6 | Cash Flow retains its archive and renders at most 25 rows. Newer/Older buttons reach all records; filtering and totals remain over the archive. Hidden updates skip rendering; reopen catches up. `test_cash_flow_paging.py` tests 100/1,000/5,001 records and stable anchors. Native memory/FPS remain unmeasured. |
| A7 — OPEN | Per-creature PlayerModel frames still grow with distinct IDs. The existing callback exposes the frame and current display state, not the originating request/creature. Recycling frames plus a Lua generation counter cannot establish native load ownership. Display IDs also describe appearance, not unique creature identity. A fixed cap would disable model browsing for later creatures. No such behavior change or speculative reuse is included. Existing stale/delayed/synchronous/nil-return ownership tests remain required. |
| A8 | Lore and Sharing accept the same numeric triple plus optional dot-separated prerelease/build identifiers; transfer version equality stays exact. `test_lore_prerelease.py`: Build/Encode/Decode/Prepare/Accept, stable/beta/numbered-beta/alpha, malformed/mismatched metadata, reload/deduplication. |
| H1 | Separate startup account preflight permits nil/versionless supported partial roots, refuses future/scalar/malformed registries and preserves recovery export. Retained tracking/UI writers honor the session hold. `test_account_preflight.py`. |
| D1 | Current AGENTS and account/backup guidance now distinguish eight journals, seven account-backed families and nine roots. Dated historical records are retained. |

## Compatibility limits

No saved journal is pruned, Annals stays character-local, and no report protocol
or saved schema version is bumped. Previously ambiguous timestamp-only links
without a retained original or demonstrable owner remain unavailable. The repair
does not infer lost ownership after resets that already collided before this fix.
The shared version syntax functions remain self-contained because Lore's text
adapter and live Sharing are also loaded independently by tools/tests.

## Native follow-up: Pick Pocket cash attribution

Owner testing confirmed startup, all main pages, the corrected Cash Flow footer
and toggle, and automatic entrance navigation. An out-of-range pick created no
pending cast; its subsequent corpse Linen Cloth was recorded. An already-picked
target reported SUCCEEDED without loot; the stale state expired on the next
corpse READY and its 10 copper had no pocket context. These checks do not prove
the matching FAILED/INTERRUPTED cleanup path natively.

The same trace exposed successful 2-copper attribution lost across a rapid repeat
cast, close and same-source reopen. Confirmed coin-window evidence now survives
that bounded sequence for the same living source. Cast-only, expired, consumed,
ambiguous, conflicting, fishing and corpse evidence cannot carry it forward.
`test_pickpocket_cash_reopen.py` replays the timing and 17 boundary scenarios;
existing Bestiary and Ledger checks remain required. Historical labels are not
rewritten. After reload without Lua errors, the owner confirmed a fresh 1-copper
pick was labelled Pickpocketed cash with the correct creature. After retrying the
rapid-press test, the owner also confirmed correct attribution and additions on
two consecutive mobs. These are owner-operated native checks, not a new captured
trace or proof of every automated boundary case.

The owner also confirmed Dry Salt Lick under Pickpocket Loot and switched off
diagnostics. For Protecting the Herd, the owner selected Coldridge Hammer from
three visible choices. Annals displayed that chosen item, 460 XP and 0 copper;
the chosen reward remained correct after reload. This verifies native choice
capture and persistence, not the specific initially-unreadable reward timing,
which remains covered by the automated regression.

The owner accumulated enough Cash Flow history to confirm Older/Newer navigation
worked as intended. With Bestiary open, the owner looted 10 copper, then reopened
Cash Flow and confirmed it was included. Native paging and visible catch-up pass;
bounded widget counts and absence of hidden rendering are established by tests,
not a native allocation or performance measurement.

## Remaining native acceptance

The owner operates the game. Offer one step at a time and wait for the result.
Normal gameplay smoke checks above have passed. Specialized matching-failure
and late-reward paths, multi-character reset/restore, account migration and
prerelease transfer remain automated-only. Any further native reset/old-backup
recovery exercises must use disposable multi-character data, never the only
journals.
A7 requires target-client evidence of safe model ownership before implementation;
then rapid model/portrait switching must be verified natively.

This repair-only batch recommends 0.36.2 Release after native acceptance; 0.36.1
remains recorded until the owner authorizes versioning. No commit, push, tag or
publication is authorized by this document.
