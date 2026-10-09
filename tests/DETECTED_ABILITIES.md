# Last detected spells

The footer beneath the optional spell-reference field has a "Last detected
spells" heading and four numbered ID slots, oldest first. Native
FontString.SetFormattedText formats each opaque ID with static colour codes;
Lua never concatenates, measures or reads back those values. Hover attempts
SetSpellByID inside pcall and adds the local detection time when accepted;
rejected calls hide the tooltip. Live tooltip acceptance is unverified.

The recorder observes the same eligible target/mouseover cast events and active
cast APIs as the journal, including restricted payloads. A readable creature ID
and a named entry are required. The hint works with the ID window hidden and
automatic recording disabled. SENT alone does not establish a cast.

Each creature has four hints, without a timeout. Selection changes and closing
the book preserve them. A fifth cast replaces the oldest. Public castBarID
values deduplicate target aliases, START/SUCCEEDED and polling, including recent
dismissed or evicted casts (the last 32 public tokens per creature). Late public
evidence upgrades its original slot without changing its date/time. Without a
usable castBarID, idle sampling re-arms capture; exact alias/cast deduplication
is less precise. Restricted IDs cannot be compared to merge repeated spells.

Readable IDs matching any non-rejected Recorded ability are suppressed. A
restricted ID cannot be compared with the journal. Saving or confirming a linked
ability clears matching public hints and acknowledges a lone restricted hint.
When multiple hints remain, restricted ones must be dismissed individually with
right-click; a typed ID cannot identify which opaque value to clear. The next
restricted cast may appear again even if it is already recorded. Name-only saves
do not clear a spell-ID hint. Entry deletion and reset clear the entire history.

All hints are session-only and disappear on reload/logout. Opaque values stay
in a private runtime table, never SavedVariables, backups, sharing or event logs.
The date/time is the first detection of that cast, not the last polling time.

## Automated and live verification

`test_detected_abilities.py` exercises the real event/poll path plus the book
widget, with hostile secret sentinels and a renderer that accepts opaque input.
It checks per-creature four-slot retention/rollover, duplicate suppression,
public IDs, individual dismissal, manual acknowledgement, exclusions, reset,
storage isolation, field positions, empty selection and tooltip/rendering
acceptance/rejection. `test_spell_id_window.py` additionally checks the shared
cast window's single live slot, advancement only after pinning, four-pin limit,
mouse controls, actual XML pin/unpin bindings, live expiry, pinned retention,
indefinite display, portraits, blacklist handling and compacted row order. Mocks do not establish
native secret rendering or tooltip behavior.

1. Reload, keep the Spell ID window hidden, and watch an unlocked Kobold Geomancer
   cast Fireball. Open its page: expect the hint beneath the reference field with
   20793 in the first slot, even if the ID is restricted.
2. Change targets and pages, then return. The hint and timestamp should remain.
   Observe four more casts from that creature: fill slots in order, then replace
   only the oldest. Other creatures retain their own hints. Repeated samples of
   one identifiable cast must not use more slots or change its timestamp.
3. Hover the hint. If supported by this client, expect the spell tooltip. If it
   rejects the restricted ID, expect no tooltip and no Lua error. Accepted
   tooltips include the detection date/time.
4. Outside combat, enter the displayed ID, resolve it and confirm the ability.
   A lone hint should clear; multiple restricted hints remain. Right-click one
   slot and verify the others remain in order. A later restricted cast may show
   again; a public ID already recorded must remain hidden. Saving a name without
   an ID keeps the history.
5. Check field-note and spell-input spacing, buttons, feedback and the hint at
   the normal UI scale and a smaller window scale. Close/reopen the book, then
   reload: the former preserves the hint, the latter clears it.
6. In the ID window, observe repeated cast-time, channelled and instant spells.
   Verify they replace one live row until left-click pins it. The next cast
   opens another row, up to four. Check the [Pinned] labels and hover controls,
   both on row bodies and portraits. Ctrl+click opens the captured creature
   without pinning; dragging the window must not pin. With all four pinned,
   further casts must preserve all four. Right-click removes a pin and makes
   space; pinned rows survive two minutes, unpinned rows follow the timeout or
   indefinite setting. Buff, debuff and LOC rows remain independent.
7. Assign both enemy-cast actions in Key Bindings > Azeroth Fieldbook. Pin latest
   enemy cast pins the live row; Unpin last pinned enemy cast removes the latest
   pin while preserving any live row. Check empty/full states, reuse of cleared
   slots, combat, a locked window, and reload/hiding the window clearing pins.
