# Pickpocket native verification

Status: operator confirmed native item capture and coin-only Cash Flow attribution in the Forever client. Remaining checklist edge cases still require native verification; the follow-ups below retain the investigation history.

Reload the addon on a rogue. Use a personally encountered humanoid with no previous pickpocket records. Keep the creature targeted until its loot window opens.

1. Before picking, confirm Pickpocket Loot is absent beneath the viewer. A confirmed successful pick should reveal it even with no items; confirm the count and empty-items message.
2. With autoloot off, successfully Pick Pocket a creature containing an item. Confirm the toggle appears, highlights when clicked, and displays that item in the existing loot panel. Toggle off to return to normal drops.
3. Reopen/inspect the same loot window: quantities and observed picks must not increase twice.
4. Kill and loot that same creature. Confirm corpse items update only normal loot.
5. Repeat with autoloot enabled, then with a Pick Pocket/attack macro. Confirm separation; ambiguous timing may intentionally skip capture.
6. Try failed/interrupted picks, successful empty picks, another creature, and mouseover casting with two identically named creatures. Successful empty picks count once; failures must not increase the count. Ambiguous matching names are deliberately skipped.
7. Change creature while the toggle is active. Confirm normal loot returns and the toggle hides on entries with neither recorded picks nor pocket items. Check Show Damage, quality filters, Rumours, and Beast Lore for overlap or stale highlights.
8. Reload and confirm records persist. Check account tracking/character opt-out and a local backup round trip on disposable test data.

Pocket counts include matched successful casts even without items, deduplicated against their loot windows. Failed or ambiguous casts are excluded. The button appears when the count is positive OR items exist. Historical empty picks were not captured and cannot be reconstructed. Existing mixed historical normal loot is unchanged because its method was never saved. Sharing remains unchanged.

If capture fails, record autoloot setting, macro used, target versus mouseover, whether the creature died before loot appeared, item names, and any Lua error. The conservative three-second cast window requires readable matching source GUIDs and a living target/mouseover/softenemy token at capture time.

## Cash Flow follow-up

After reload, pick coins from a creature and open Merchant's Ledger > Cash Flow. Confirm "Pickpocketed cash" and the creature name, with the exact balance increase. Test coins-only pockets, manual looting and autoloot, then kill/loot the same creature: ordinary cash must form a separate row. Consecutive picks from the same named creature may consolidate. Search for "pickpocket" to isolate them. Old cash history is not relabelled.

Automated integration covers both money/chat event orders, a notification just after loot closes, coins-only capture, separate corpse income, expiry, totals and display/search. The source evidence is consumed once and expires one second after closing; ambiguous or late notifications retain ordinary loot attribution. Amounts still come exclusively from actual character balance changes.

### Cash attribution regression follow-up

Operator reported that pickpocket cash still appeared as ordinary Looted cash. Code inspection found two unsupported paths: coin slots without a source GUID, and money chat arriving before loot-window confirmation. Synthetic regressions now cover both, including failed casts and contradictory source GUIDs. These tests reproduce gaps in the old implementation; no native event trace has established which ordering the operator encountered.

The runtime evidence token is now created for an unambiguous cast target and becomes confirmed only after a successful cast plus a compatible loot window. A readable money slot can identify that window when its source GUID is absent, provided the matched unit is still alive and no contradictory source appears. Cash Flow holds an early transaction apart for 0.2 seconds before resolving its label. Amounts remain actual balance deltas; existing ordinary-loot history is unchanged. Reload and retest manual/auto coin-only picks, picks with items, and corpse loot immediately afterwards.

### Coin-only payouts without loot slots

Further native feedback: attribution succeeds when items accompany the coins, but coin-only picks still appear as Looted cash. The previous fix still required a slot/window, so it did not cover this path. Successful matched casts now provide single-use attribution for the next CHAT_MSG_MONEY within three seconds even with zero slots and no loot-window events. The creature must still be readable and alive when the token is consumed. Failed casts, conflicting windows, new casts, expired evidence and dead targets exclude attribution. A readable matching window can retain the context until closing, with the existing one-second close grace.

Automated tests cover no window, an empty window, money before cast success, failure, dead target and expiry. Retest several coin-only picks after reload, then a pick with items and ordinary corpse cash. No historical rows were changed. Earlier notes requiring a readable slot/window for attribution are superseded by this follow-up.

### Native trace required

Operator still reports coin-only payouts labelled Looted cash after the cast-based change. Synthetic sequences do not reproduce the client failure. Do not consider cash attribution verified. Reload, run `/fieldbook debug pickpocket on`, perform one coin-only pick, wait one second, then run `/fieldbook debug pickpocket`. The copyable report records event ordering, context acceptance/discard, loot snapshot availability and transaction classification. Send that report for diagnosis. `/fieldbook debug pickpocket off` disables recording; re-enabling clears the bounded 200-row buffer, and reload discards it. No source attribution changes were made in this diagnostic follow-up.

### Confirmed native cause: close grace expires before chat

The supplied trace does contain readable coin slots and matching source GUIDs. Cast success and window evidence are valid. LOOT_CLOSED occurs twice at 931497.772, balance increases at 931497.948, and CHAT_MSG_MONEY arrives at 931498.774: the context expired at 931498.772, two milliseconds earlier. This establishes expiry rather than missing coin slots as the cause in this captured run.

Cash Flow now consumes and retains the source token with the positive balance candidate while fresh. The later matching chat uses that candidate's token; it does not re-read expired window context. The existing candidate timeout and amount match remain in force, and balance changes alone stay unclassified. Regression coverage reproduces the supplied close/balance/chat timings, including duplicate close events. Native re-verification after reload remains pending.

## Native outcome

Operator confirmed the balance-bound attribution fix works successfully for coin-only picks, then disabled diagnostics. Pickpocket item capture and coin-only Cash Flow attribution are verified in the Forever client. Other checklist edge cases remain separate from this confirmation.
