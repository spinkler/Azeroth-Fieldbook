# Spell ID window live checks

Reload the addon in Forever. Lua mocks verify lifecycle and settings, but cannot
verify the game's secret-value engine or actual layout.

1. With fresh settings, confirm the window is visible, draggable and has a 35%
   black background. Drag it, reload, and verify its position persists.
2. Open **Options → Tooltips and cast IDs**. Toggle the window, lock it,
   and change its background opacity. Locking prevents dragging; populated
   sections still receive right-clicks. Verify these choices survive reload.
3. Target a Mountain Boar when **Rushing Charge** appears. Check **Buff on target**
   against the aura tooltip's numeric ID. Repeat during combat.
   Also test **Fire Shield** on a Geomancer during combat. Aura slots provide
   tracking when the instance ID is secret; accessible secret fields are passed
   directly to text. Truly inaccessible tables must still be skipped.
   If the row stays blank, run `/fieldbook debug` while the buff is active and
   inspect the `ID window target buffs` line for the scan counts/access result.
   A failed slot query now tries indexed access; the diagnostic names the path
   and includes public API error text. If both queries are denied in combat,
   do not treat the fallback as a confirmed fix or infer a buff from its cast.
   Target friendly and hostile players, and player-controlled pets: their buffs
   must not replace the previous NPC observation. Friendly NPCs remain eligible.
4. Receive a debuff. Check **Debuff on you**, including its dispel type if supplied.
   Secret names, IDs and dispel types are passed directly to separate FontStrings.
5. Observe a normal enemy cast and a channel. Confirm **Enemy cast** shows the
   correct ID. A channel's success event must not classify it as an instant.
6. Observe a successful enemy instant for which the API supplies a public zero
   cast time. Confirm **Enemy instant cast** updates. Unclassified successes go
   in **Enemy cast**; absent events cannot identify a cast. SENT events alone
   are not evidence of a successful instant.
7. Change targets or let the aura disappear: the historical row should remain.
   Without another observation, each row should clear after 120 seconds.
   Unrelated aura updates and opening options must not prolong old rows.
8. Enable **Display Spell IDs in the ID window indefinitely**. Observe an item
   and wait over two minutes. Disable the option: already-expired items should
   clear promptly. Expired items cannot be restored by enabling it afterward.
9. Verify unused sections, including headings, are hidden. The window should
   grow upward as sections fill and shrink without moving its bottom edge when
   sections expire or are dismissed. An empty window retains its header unless
   auto-faded. Check an existing saved position and drag/save/reload again.
10. Observe a cast with a known target name and an aura with a known source.
    Verify Cast by identifies that source, not automatically the aura recipient.
    A missing/restricted source token or absent caster name must omit the entire
    line and its space. Secret names may be relayed to the renderer directly.
11. Right-click each populated section. It should disappear and close the gap.
    The same public cast-bar/aura token must not immediately redisplay it; a new
    observation may. Test while locked and with Shift+Click window hiding.
12. Ctrl+Right-click a readable ability ID. Expect dismissal and a saved blacklist
    entry. Future readable occurrences of that ID in any section must be hidden,
    while other abilities still display. Reload and verify the list persists.
13. Open **Spell ID window blacklist** in Options. Add a numeric ID, remove an
    entry, and exercise pagination with more than eight entries. Invalid input
    must be rejected. Removing an entry permits new observations again. Journal
    records and automatic capture must remain unaffected by the blacklist.
14. Ctrl+Right-click a restricted ID. The section should dismiss and the manager
    should explain that the value cannot be saved or compared. Manually typing
    its visible ID adds a public blacklist entry but cannot filter future secret
    payloads. Never claim hidden IDs were successfully matched.

The rows contain the most recently observed item in each category, not an
ability history. Simultaneous aura observations follow API enumeration order.
Observations are display-only and do not persist through reload or disabling
the window. Only settings, public blacklist IDs and position are saved by the display module. Since
0.9.138, a separate default-on recorder saves readable creature buffs outside
combat. In 0.9.140 it also confirms enemy casts with public spell IDs, including
in combat, independently of this window. A displayed secret ID cannot be saved;
see [AUTO_BUFFS.md](AUTO_BUFFS.md). Other
useful display-only findings can still be recorded manually.

The inspected Forever cast, aura and spell-info APIs do not supply magic school.
No school is guessed from a name, dispel type or external spell database.
