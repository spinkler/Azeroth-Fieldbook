# Last observed ability hint

Local 0.9.143 refines the display hint beneath the optional spell-reference field.
The heading has its grey local date/time immediately beside it. The next line
shows the yellow spell name, grey Spell ID label and white number inline. Native
FontString.SetFormattedText formats the opaque name and ID with static colour
codes; Lua never concatenates, measures or reads back those values. C_Spell.GetSpellName is a display
relay here, never a source of saved data. Hover attempts SetSpellByID inside
pcall; rejected calls hide the tooltip. Live tooltip acceptance is unverified.

The recorder observes the same eligible target/mouseover cast events and active
cast APIs as the journal, including restricted payloads. A readable creature ID
and a named entry are required. The hint works with the ID window hidden and
automatic recording disabled. SENT alone does not establish a cast.

Each creature has one hint, without a timeout. Selection changes and closing the
book do not clear it. A new cast overwrites it, including clearing the old hint
if the new public ID is already recorded. Public castBarID values deduplicate
target aliases, START/SUCCEEDED and polling. Without a usable castBarID, idle
sampling re-arms capture; exact alias/cast deduplication is less precise.

Readable IDs matching any non-rejected Recorded ability are suppressed. A
restricted ID cannot be compared with the journal: its heading says "Last
detected ability" without claiming it is unrecorded. Saving
or confirming a linked ability for that creature acknowledges and clears the
current restricted hint. This is a user action, not a secret-to-public mapping;
the next restricted cast may show it again even if it is already recorded.
Name-only saves do not clear a spell-ID hint. Entry deletion and reset clear it.

All hints are session-only and disappear on reload/logout. Opaque values stay
in a private runtime table, never SavedVariables, backups, sharing or event logs.
The date/time is the first detection of that cast, not the last polling time.

## Automated and live verification

`test_detected_abilities.py` exercises the real event/poll path plus the book
widget, with hostile secret sentinels and a renderer that accepts opaque input.
It checks per-creature retention/overwrite, duplicate suppression, public IDs,
manual acknowledgement, exclusions, reset, storage isolation, field positions,
empty selection and tooltip acceptance/rejection. Mocks do not establish native
secret rendering or tooltip behavior.

1. Reload, keep the Spell ID window hidden, and watch an unlocked Kobold Geomancer
   cast Fireball. Open its page: expect the hint beneath the reference field with
   Fireball, 20793 and a timestamp, even if the ID is restricted.
2. Change targets and pages, then return. The hint and timestamp should remain.
   Observe another spell from that creature; it should replace the hint. Other
   creatures retain their own hints. Repeated samples of one cast must not keep
   changing the timestamp.
3. Hover the hint. If supported by this client, expect the spell tooltip. If it
   rejects the restricted ID, expect no tooltip and no Lua error.
4. Outside combat, enter the displayed ID, resolve it and confirm the ability.
   The hint should clear. A later restricted cast may show it again; a public ID
   already recorded must remain hidden. Saving a name without an ID keeps it.
5. Check field-note and spell-input spacing, buttons, feedback and the hint at
   the normal UI scale and a smaller window scale. Close/reopen the book, then
   reload: the former preserves the hint, the latter clears it.
