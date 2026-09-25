# Point-funded sharing: implementation and live checkpoint

Development baseline: clean `main`, `f33e392`, TOC 0.8.3 / interface 16001.
Release version: 0.9.11 Beta, including account-wide tracking and the separate Rumours review window,
updated kill thresholds and Index toggle after the operator-designated 0.9.0 sharing
milestone. The operator requires an increment
of the last version component for each completed local change set. No commit,
push or release has been performed for this implementation.

## Inspection and transport decision

Previously, `GetTotals()` summed one point per visible entry, saved discovery
progress, and derived kill rewards. `Ensure()` created a discovery-credited
entry. The Share button was disabled. Creature Notes already had an independent
notes editor, pinning, target following and scale support, but returned early
when refreshing the same entry.

Research checked the **forever** branch on 2026-09-25, rather than assuming Retail
or an older Classic API. Relevant primary implementation references:

- [Forever ChatInfo API and CHAT_MSG_ADDON payload](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua)
- [Forever chat result enums](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatConstantsDocumentation.lua)
- [Forever restriction APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)
- [Forever restriction constants](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsConstantsDocumentation.lua)
- [Forever UnitFullName returns](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [AceComm API](https://www.wowace.com/projects/ace3/pages/api/ace-comm-3-0),
  [maintained AceComm implementation](https://github.com/WoWUIDev/Ace3/blob/master/AceComm-3.0/AceComm-3.0.lua),
  [ChatThrottleLib implementation](https://github.com/WoWUIDev/Ace3/blob/master/AceComm-3.0/ChatThrottleLib.lua)

The Forever docs describe targeted addon messages, sender/target event fields,
and **enum** registration/send results. Registration accepts only `Success` (0)
or `DuplicatePrefix` (1); sending accepts only `Success` (0). Failure enums include
throttling, chat lockdown and offline targets. Secret arguments are prohibited
for sending. The code checks readability before interpreting return values or
messages, and blocks combat plus `Enum.AddOnRestrictionType.Chat`, including its
activating state. Restrictions remain authoritative even when the player is out
of combat.

| Option | Decision |
| --- | --- |
| Native targeted WHISPER | Implemented: explicit recipient, small bounded reports, enum-aware failure handling. |
| AceComm / ChatThrottleLib | Useful general chunking/throttling; the maintained implementation uses a 255-byte payload ceiling. It still requires application consent, bounds, receipts and economy logic. Native transport keeps this narrow feature dependency-free. |
| Group/guild channels | Rejected: expose the report to unrelated recipients and change the single-recipient design. |
| Battle.net/logged/visible chat | No concrete benefit for character-bound reports; no account identifiers or visible payload traffic. |
| Encoded copy/paste | Investigated but deferred: unauthenticated author claims and charge-on-export semantics would add a second delivery path before native testing establishes a need. No reusable export exists. |

The API documentation does **not** establish Forever's live WHISPER eligibility
for every relationship, faction or instance, nor server throttle rates.
The library ceiling is a conservative implementation reference, not a live
Forever measurement. This protocol stays at 240 bytes per packet and one packet
per second, with at most three attempts for a throttled packet. An unavailable
receiver has a useful timeout but may be offline, disabled, restricted, on an
older addon, or unreachable under server whisper rules. No claim of cross-faction
support is made. First verify two same-faction players; record group and ungrouped
results separately.

Character identity is realm-free and retains surnames, including spaces,
apostrophes, hyphens and localized letters. The native adapter reads the first
return of `UnitFullName("player")`, falling back to `UnitName`; the documented
second return is a server, not a surname, and is not appended. Received attribution
uses the actual sender's complete name. Different surnames are distinct identities.
The live receipt below confirms full-name targeting and acknowledgement for one
pair of characters; other name variants still need coverage. Identity/registration
are retried on login, entering the world,
leaving combat and player name updates. The composer displays the specific
prerequisite that currently disables sending.

Compatibility requires sharing protocol **4**, literal report schema **1**, and
the **same installed addon version** on both clients (from the current TOC). The native
adapter reads `C_AddOns.GetAddOnMetadata(addonName, "Version")`; an unavailable or
unreadable version disables sharing. `H` and `R` carry a bounded literal version
string. Both ends check it before sending/staging report data, and a mismatch
identifies both versions when available and releases a new offer's reservation.
Replies must still come from the expected recipient and transaction.

Older development protocols may reply with incompatibility or ignore the newer
handshake and time out without spending. Released 0.8.3 does not implement this
prefix and will time out. Paid retries also recheck versions. Their original
schema-1 data and historical cost remain intact after both clients update; a
mismatch keeps an already-paid transaction unknown, without refund or another
charge. Pricing is **1 point for new basics plus 1 point per selected rumour**, with
the basic point waived when the recipient already knows the reported basics.
There is no two-rumour selection cap. The maximum estimate is reserved until
acceptance; the final charge and waiver survive retries without repricing.

## Transaction lifecycle

1. Composer captures the basic report and eligible local traits. It costs nothing.
2. Send validates the frozen allowlisted report and recipient, checks funds and
   reserves 1 point plus the selected rumour count. Only one outgoing transaction
   is active per character.
3. `H`/`R` exchange installed addon versions during compatibility preflight
   (20-second deadline). Only WHISPER is used. `I` rejects incompatibility and
   includes the receiver's addon version when supported. `O` chunks carry the validated offer for
   **preview only**; they cannot import it. Offer staging expires after 180 seconds.
4. Recipient previews actual sender, NPC ID, basics, all selected unverified claims,
   conflicts and new-information status. `D` declines; closing a pending offer
   declines too. `X` cancels an uncommitted outgoing offer. No recipient points move.
5. Accept rechecks the recipient's current basics and saves the full validated
   incoming report, explicit consent and basic cost before sending `A` with a
   literal `0` (already known) or `1` (new basics). The sender atomically turns its
   reservation into the final spending **once**, releasing the waived point,
   records the committed decision, and queues `C` to authorize import. A timeout,
   cancellation, API failure or reload before this decision releases the reservation.
6. Only an accepted matching `C` can import. The receiver revalidates identity,
   capacity and schema before any journal mutation, then saves a receipt and sends
   `K`. `K` from the expected recipient and transaction completes the sender's UI.
7. A failed/missing acknowledgement after commit leaves **unknown** delivery,
   with spending retained. This includes a recipient disappearing after accepting.
   Retry sends a version-bearing `H` for the same ID. After version validation,
   a saved receipt returns `K`; saved consent returns `A` and the same `C` is
   resent; missing state returns a version-bearing `R`, prompting a fresh offer
   and explicit acceptance of the **same paid** report.
   There is no automatic refund or new transaction after an ambiguous delivery.

There are at most three user-requested reconciliation attempts within 24 hours
of creation. Requests and replies must match the actual expected character,
channel and transaction. Retry exhaustion/age permits **Close unresolved report**;
the cost stays spent. New reports are separately paid. Normal reload cancels an
uncommitted sender reservation, preserves accepted receiver consent, and restores
a committed sender as unknown. There is no automated retry loop.

This is a local addon protocol, not distributed exactly-once accounting.
SavedVariables save on normal reload/logout, not after each Lua assignment. A
client crash, restored backup, deleted SavedVariables, full reset or modified
client can lose one side's state; acknowledgement cannot guarantee that the
other client has flushed its save to disk. A refund after an uncertain commit
could authorize free deliveries, so none is automatic. Recipient binding and
sender attribution are not cryptographic truth or anti-cheat guarantees.

## Storage, validation and reward accounting

- `bestiary.points` version 1 holds earned/spent totals, reservations and durable
  per-NPC discovery/level/zone/kill-milestone credit. The one-time migration uses
  the previous derived total and its legacy endpoint logic. No intervening levels
  are invented. Previously deleted legacy records cannot be reconstructed.
- Original rewards remain: first creature 1; subsequent sighting revealing a new
  level, zone or both 1; silver at 2 kills gives 1; gold at 25 kills gives another 2.
  Spending cannot change the display entry's kills/stars. A short per-creature
  death-GUID history also prevents repeat corpse events across normal reloads.
- Imports create a display container through `Ensure(id, true)` with no personal
  credit. Importing `sharedReports` and `rumours` does not write personal
  abilities/traits, ID Logs or tooltips. Explicitly verifying a rumour adds a normal
  confirmed ability or trait without discovery credit; locked entries must first
  be unlocked. Later personal observations credit their
  own levels/zones, even when a report already includes them. Entry deletion
  retains the durable ledger and recent receipts. Full Reset Bestiary and the
  existing confirmed `/fieldbook wipe` deliberately clear all of this state and
  queued transfers; the reset interaction itself is unchanged.
- Local identity/type conflicts are preserved; shared basics remain separate.
  Unlocked display summaries can combine level/location coverage and label shared
  sources. Locking captures the display basics, including for an imported-only
  entry, so later reports cannot change its locked metadata.
- Rumour candidates are individual pending/confirmed ability names, including
  manual abilities, or existing offense/resistance/immunity school and behaviour
  toggles. Each ability contributes only its name and optional spell identifier;
  neither its many effect tags nor freeform note is a selection. ID-log-only
  spells, rejected abilities, sentence-bundled names and unverified received rumours
  are excluded. Explicitly verified journal records become normal sharing candidates.
- Wire encoding is fixed-order length-prefixed literal fields with strict types,
  key allowlists and no trailing fields, Lua evaluation or decompression. NPC IDs
  are integer 1–10,000,000; known levels are 1–255 in ordered pairs. Names, types,
  locations and claims are bounded; control codes and WoW `|` markup are rejected.
  Incompatible schemas, malformed arrays and duplicate claims are rejected on the
  receiver too. Claim counts are bounded by the available payload bytes when parsing.
- There is no per-report rumour quota. One report is at most 2,048 bytes with
  eight locations; frames at most
  240 bytes, chunks at most 180 bytes / twelve chunks. Missing chunks expire;
  duplicates and ordering are handled; conflicting duplicate chunks reject the
  entire offer. Unsolicited chunks/commits cannot populate the journal.
- Limits: 64 queued packets, three staged/accepted incoming transfers, eight new
  preflights per minute, fifteen seconds between new preflights from one source,
  180 incoming protocol packets per minute. Accepted consent expires at the
  report's 24-hour limit. Receipts are capped at 512 and retained for 48 hours;
  new imports fail closed when recent receipt storage is full.
- At most 500 creatures with shared records; sixteen basic reports and 32 rumour
  records per creature, including rejection/resolution history. Active same-source
  duplicates stay suppressed. A new transaction can reactivate a rejected claim,
  reusing that source's slot and marking it Previously rejected. Duplicate delivery
  of the rejected transaction does not reactivate it. Rejection history is checked
  across senders, including old dismissed records and rejected personal abilities.
- A green tick in the separate Rumours window confirms an ability in place or uses
  the standard trait setter. Existing notes/effects and tooltip opt-outs survive.
  The manual ability path, ability confirmation and all four trait setters resolve
  matching rumours from every source. Matching uses normalized names or equal
  ability spell IDs. Known personal facts do not create new rumour rows. Review
  does not grant points, mark personal discovery, or automatically lock an entry.

## Automated verification

Run every `tests/test_*.py` with Python and `lupa.lua51`; the existing local
`.codex-test-deps` path is supported by the tests. No extra runtime dependency is
packaged. `.pkgmeta` continues to exclude tests, and TOC loads sharing and the
Rumours window before the main book.

`test_sharing.py` covers pricing, malicious schemas, migration, spending/reloads,
imports with zero credit, subsequent personal discovery, deletion cycles, kill
rewards, local/locked merges, attribution, deduplication, receiver consent,
offline/incompatible receivers, packet/API failures, duplicates, interruptions,
retry reconciliation, bounded queues/storage and reset. `test_sharing_ui.py`
covers actual enum meanings via a mock native adapter, secret/error results,
combat/chat gates, the Share button, captured selection, per-rumour costs, selection
beyond two rumours, insufficient funds for larger reports, old-protocol rejection,
TOC metadata/version display, mismatched/malformed/missing addon versions,
spoofed version replies and rechecking versions without repricing paid retries,
acceptance UI, repeat-rejection warnings and the separate Rumours toggle, including
verification/rejection controls, locked entries, bounded scrolling, scale and
refresh without replacing Creature Notes editor input. `test_rumours.py` covers
all review paths, matching manual records, preserved private fields, no discovery
credit, source-independent rejection history, simulated reloads and storage bounds.
The existing regression scripts remain part of the check.

## Live result — receipt confirmed, 2026-09-25

These screenshots were recorded under the original two-rumour cap and pricing.
They establish the delivery/import path; the new per-rumour pricing and selections
above two still need a live check. Two rumours now cost 3 points including basics.

The operator confirmed receipt and supplied a sender-side screenshot showing:

- Forest Lurker (#1195), Beast, level 11, Loch Modan, sent to **Erna Lionguard**.
- Two selected rumours: **Hostile** and **Uses Nature magic**.
- Status: **Receipt acknowledged by Erna Lionguard. Spent 2 points.**
- Earned 6, spent 2, available 4, reserved 0.
- The surname retained without a realm suffix, two-column choices, and no
  trailing periods on the visible rumour labels.

This confirms native delivery and acknowledgement for this two-rumour report.

The operator then supplied receiving-side screenshots for a report from
**Erna Lionguard**:

- The offer preview identifies Large Crag Boar (#1126), Beast, levels 6–7,
  Dun Morogh, and the sender's full name.
- **Casts Rushing Charge** and **Melee** are presented as two unverified rumours,
  each attributed to Erna Lionguard, with explicit Accept — free / Decline controls.
- After import, the book shows the reported basic details and **Shared basics •
  not personally encountered**. Kills remain 0 and Recorded abilities is empty.
- Creature Notes shows both rumours as **Unverified**, each with the sender's
  full name, plus a separately attributed basic report. Notes and Rumours are
  both expanded in the screenshot.
- The book displays 6 earned points. These screenshots do not provide a paired
  before/after receiving balance check.

This additionally confirms the offer preview, imported basic information,
recipient-side attribution, and separation from recorded abilities for this case.
Reload persistence, group/faction relationship, and interruption handling remain
part of the acceptance checks below.

**Live persistence testing is blocked:** on 2026-09-25, the operator reported
that a current WoW Forever bug prevents persistence. Defer reload/reconnect-based
checks until that client issue is resolved. Automated persistence/reload tests
have passed with simulated SavedVariables; live persistence remains unverified.
The confirmed in-session delivery, acknowledgement and import results still stand.

## Two-player acceptance test — partially verified

**Stop at step 1 if real native delivery fails.** Record client build, exact
recipient spelling, relationship/group status and both UI status messages before
considering another transport. Mock tests cannot establish networking or layout.

1. Install this checkout on two same-faction Forever characters, A
   and B. Both reload and leave combat. A needs earned points and a recorded NPC
   that B has not personally encountered. Record both earned/available balances.
   A selects that NPC → Share → B's full character name (including surname,
   without a realm) → no rumours → Send offer. Verify that the native target and
   received sender name retain surnames, if available on the test characters.
   B must see A's character, NPC ID, basics, no rumours and new-information status.
   Before acceptance, A has one reserved point and B has no new entry. B accepts;
   A must show acknowledged completion and exactly one spent point; B's balance
   stays unchanged. Repeat the reachability check grouped if ungrouped delivery
   failed; do not claim ungrouped support from a grouped result.
2. Both clients install the same updated protocol-3 addon version. A selects at least three
   separate local records, including a manually entered ability or trait, and
   sends to B. Additional selections must remain available. Three rumours must
   cost 4 points total; each selection/deselection changes the cost by one point.
   Choices must occupy two columns, wrap without overlap and have no trailing periods.
   Change target/book selection while composing and confirm the captured NPC
   remains the one sent. B accepts and clicks **Rumours** between the kill counter
   and Creature Notes: all selected claims appear unverified and attributed to A.
   A second click closes it. Creature Notes has no embedded Rumours section.
   Test a locked page, notes input, spell-ID input/links, notes pinning, scrolling,
   Escape, brightness and 50/100/150% scale. Receiving alone must not set traits,
   confirm abilities or add knowledge to NPC tooltips.
3. Decline another offer; A's reservation returns and spending does not increase.
   B, if still at zero earned points, tries to share its imported entry: insufficient
   funds must prevent sending. Merely accepting reports never funds this attempt.
4. **Deferred until the reported client persistence bug is resolved.** Reload
   both clients. Verify earned/spent balances, shared basics, attribution,
   notes and rumour rejection/verification history. B later genuinely encounters the NPC: first
   discovery earns once; already-shared but newly personal levels/zones remain
   eligible. Delete/reimport/re-encounter the same milestones: no repeat credit.
5. Try an offline/disabled-addon recipient: useful failure, no spending. Defer
   the following reload/reconnect checks until the client persistence bug is fixed.
   For a deterministic interruption, reload A while B is previewing an unaccepted offer.
   A's reservation must return; a later acceptance of that abandoned preview must
   not import. If a real disconnect can be reproduced **after A shows spent points
   but before acknowledgement**, expect unknown, retained spending and same-ID
   Retry status after reconnecting, with no double debit/import. Record this case
   as unverified if the timing cannot be reproduced safely.

6. In the separate Rumours window, verify an ability using its green tick: it
   appears in Recorded abilities and all matching rumour rows disappear. Existing
   private notes/effects must survive. Repeat with each trait kind; their normal
   controls reflect the result. Locked entries disable verification but permit x.
   Record a matching ability/trait manually and confirm that its rumours disappear,
   including a different sender's claim. Send a previously rejected claim in a
   new transaction: the offer and received row must say **Previously rejected**.
   A repeated known fact must not create a new rumour. Balances and personal
   discovery credit remain unchanged throughout review.

Before a new offer, also test a deliberate addon-version mismatch between clients
that support protocol 4: the sender must see both versions, send no report payload,
spend no points, and regain its reservation. Restore matching versions for later
checks. Do this when installing/reloading test builds is practical given the
current client persistence bug; the existing automated mismatch checks already pass.

Outstanding: separate-window layout, verification/manual matching and repeat-rejection warnings in game;
installed-version mismatch reporting in game, per-rumour pricing and selections above two in game, basic-only
delivery, recipient-side balance checks and locked entries,
declines, insufficient funds, interrupted transfers/retries, broader whisper
eligibility/throttle behavior, long-text wrapping/scaling/clamping, and persistence
across two running game clients. Copy/paste fallback is deliberately not implemented.
