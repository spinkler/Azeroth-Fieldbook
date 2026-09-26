# Automatic creature ability recording

Local 0.9.140 extends the default-on **Automatically record verified creature
abilities** option under **Ability recording** to combat casts with readable IDs.
The original buff option's saved OFF preference is preserved. The 2026-09-27 screenshot supplied
by the operator shows Frost Armor (12544) on Defias Rogue Wizard in both the
ID window and native tooltip. Live 0.9.138 testing did not populate Recorded
abilities. Read-only SavedVariables inspection found the unlocked wizard entry
(ID 474) had `ignoredAbilities["Frost Armor"] = true`, with automatic recording
enabled. That name-only removal flag blocked even a valid aura scan. 0.9.139
reproduces and fixes this case in tests; live confirmation remains pending.

Buff capture uses public C_UnitAuras fields from an attackable, visible target or
mouseover. Both player and creature must be outside combat. It never reads
back ID-window text, parses a tooltip, stores secret values or reconstructs an
expired buff. The observed public ID resolves the name through C_Spell.GetSpellName,
with a readable aura name as fallback. A known different caster excludes the buff;
missing or unreadable optional caster information is allowed because the record describes a buff observed on the
creature. The [A] tooltip explains that distinction.

New automatic records and matching pending/rejected observations are confirmed with a
spell ID and the persisted `Automatic buff observation` origin. Existing
confirmed records keep their origin. A light-blue [A] marks automatic records;
[?] continues to indicate a missing spell link. Manual Edit/save removes [A].
Normal entry-lock and per-ability tooltip visibility rules still apply. With the
option on, fresh verified evidence restores removed or rejected abilities. Turn it
off to keep them absent. New/restored records announce the creature, ability and
spell ID in both chat and the Event log, once per actual change. Repeated scans
and reloads are silent. `/fieldbook debug` includes the recorder's latest status.
Sharing sends these abilities as recipient-reviewed rumours, never automatic
confirmation on another player's journal. The existing backup format preserves
the origin, so no database or protocol migration is needed.

## Cast capture (0.9.140)

Direct target/mouseover casts with a public spell ID are resolved and confirmed
using the same storage/notification path, with `Automatic cast observation`
provenance and a cast-specific [A] tooltip. Combat does not block this path.
START, CHANNEL_START, EMPOWER_START and SUCCEEDED events qualify; polling also
observes ongoing UnitCastingInfo/UnitChannelInfo casts. START establishes an
attempt even if interrupted later. SENT alone does not establish execution.
Name-only evidence and historical encounter imports keep their pending behavior.
Existing saved observations are not replayed as fresh automatic confirmation.

The public ID resolves through C_Spell.GetSpellName, with the directly observed
public cast name as fallback. Secret IDs never reach that lookup or saved data.
Earlier live evidence in [CAST_ID_PROBE.md](CAST_ID_PROBE.md) showed spell 4979
rendering while classified SECRET. A visible number is not proof of readable
recording evidence. Unknown/restricted creature identity also prevents capture.
Live combat capture with an actually public ID remains to be verified.

On 2026-09-27, the operator's 0.9.140 screenshot showed Fireball (20793) in the
spell window for Kobold Geomancer, without a journal record. Two supplied debug
reports confirmed automatic recording ON. The focused second capture identified
the target as eligible and showed START/SUCCEEDED events delivered through target,
nameplate and alias tokens, all with secret IDs in the displayed trace. Active
cast sampling also retained `name SECRET; ID SECRET`. This establishes a live
client restriction for that reproduction, not an event-delivery or entry-lock
bug. The spell window relays restricted fields directly to FontString.SetText;
it cannot read them back as public journal data. Out of combat, entering the
observed 20793 in the manual spell-reference field remains available. A local
mock of that public ID confirms successfully; the restricted case stays absent.

## Automated coverage

`test_auto_buffs.py` exercises the real addon event/poll path, all-buff capture,
slot pagination and index fallback, combat/restricted/malformed fields, caster
and NPC gates, default-on behavior and saved off preference, repeated scans, manual/pending/rejected
records, entry locks, reset hold, account storage, reload, backup/restore,
sharing provenance, the option and the rendered marker/tooltip control flow.
Additional regressions reproduce the saved wizard removal flag and check
ID-based name resolution, optional metadata, restoration, chat/log deduplication
and diagnostic output.
`test_auto_casts.py` adds nine checks covering combat events and polling, instant
casts, optional names/cache retries, secret IDs, saved options, fresh restoration,
entry locks and reset hold, watched aliases, historical data, manual notes,
account persistence, backups and sharing. The UI test checks both [A] sources.
Run them through `python -B -X utf8 tests/run_tests.py` with the rest of the suite.

## In-game smoke check

1. Reload 0.9.140. Leave the new option enabled and target an unlocked Defias
   Rogue Wizard with Frost Armor outside combat. Expect exactly one Frost Armor
   record with a blue [A], spell ID 12544 and its spell tooltip on hover. Existing
   manually confirmed Frost Armor remains a single personal record. Expect one
   chat and Event log message when a new or previously removed buff is recorded.
2. Repeat targeting and mouseover. No duplicate ability or repeated buff Event
   log entry should appear. Hide the Spell ID window and verify capture still
   works on another eligible, unlocked creature.
3. Disable the option and reload. It should remain off and add no new buffs.
   Existing records stay. Re-enable it while watching a buffed creature; capture
   should resume within a second.
4. Confirm aura scans record no buffs during player or creature combat. A directly
   observed cast of that same buff can independently qualify during combat. After combat,
   a still-active readable buff should be picked up without retargeting. Expired
   or still-restricted data remains absent.
5. Reject or remove an automatic ability with the option enabled. A fresh
   observation should restore it with one new chat/log message. Turn the option
   off, then remove it; it should remain absent across targeting and reloads.
   Locked entries stay unchanged; unlock before resuming recording. Edit/save
   should remove the [A] marker.
6. Reload and perform a backup/restore. Automatic provenance and notes should
   survive. On another character/account scope, verify the chosen storage mode
   behaves like other Bestiary abilities.

7. With the option enabled, watch an unlocked enemy cast in combat. Test a cast
   bar, a channel and an instant cast. For public IDs, expect one confirmed [A]
   record and one chat/Event log announcement with the ID. Repeated casts should
   be silent. Remove/reject, then witness a fresh cast: it should return. Verify
   no capture depends on showing the ID window. A displayed but SECRET ID is an
   expected limitation; `/fieldbook debug` distinguishes it from readable IDs.
8. Disable the option: new readable casts should remain pending and removed
   abilities should remain absent. Re-enable it and witness another public-ID
   cast to confirm automatically. Old saved observations alone must not confirm.

The mock host cannot establish native aura/cast access or visual layout on Forever.
