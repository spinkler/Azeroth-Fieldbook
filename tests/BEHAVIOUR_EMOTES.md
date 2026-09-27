# Automatic behaviours and basic disposition — 0.10.4

The supplied live screenshot shows the English server emote
`Stonesplinter Scout attempts to run away in fear!` (and the same text for a
Stonesplinter Trogg). Its screenshot establishes the visible phrase, not the
readability of the addon's event payload.

## Evidence and implementation

Blizzard's Forever 1.60.1.69977
[ChatInfo documentation](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua#L1869)
defines `CHAT_MSG_MONSTER_EMOTE` with text at argument 1, sender at 2 and GUID
at 12. It marks the event `SecretInChatMessagingLockdown`; visible chat does not
guarantee those arguments are addon-readable. The handler skips restricted text,
sender or GUID before comparing or formatting them. The event schema alone
does not establish which values were supplied for the reported failed encounter.

Only this server event is parsed, using the exact English phrase, with either
the literal `%s` sender placeholder or the full readable sender name, ignoring
outer whitespace. A supplied GUID must be a Creature GUID for an existing
personal entry and the sender must agree with its recorded name. When the GUID
is nil or empty, the sender must exactly match a currently eligible target or
mouseover with a readable Creature GUID. Different matching IDs in those units
or conflicting names among personal entries reject the fallback. General chat
and historical-name-only guesses cannot set a trait. Invalid or restricted GUIDs
never use the fallback. No translated phrase is assumed. No creature entry or
Knowledge is created.

The operator reported that flee was not recording. Read-only inspection of the
2026-09-27 on-disk account entries found Stonesplinter Trogg (1161, three kills)
and Scout (1162, two kills) personally encountered, unlocked and without recorded
behaviours or removal flags. Those saved settings do not explain the failure.
The previous parser silently rejected an absent GUID, reproduced in the test
host. The exact live payload was not captured; missing GUID remains a candidate
cause, not a claimed live diagnosis. No SavedVariables were modified.
The operator subsequently confirmed that flee recording works with the fix.

`entry.behaviours[name]` retains the existing boolean format. An additional
`behaviourSources[name] = "monsterEmote"` records automatic provenance; the
summary and Behaviour panel display cyan `[A]`, with a source tooltip. Manual
unchecking or rechecking preserves this historical source. Unchecking sets
`ignoredBehaviours` to retain the off state during merging, but fresh evidence
clears it and restores the trait. Locked entries accept automatic traits while
manual changes remain disabled. New trait evidence resets
the unchanged-content auto-lock streak, while duplicate emotes do not.

`UnitReaction(unit, "player")` supplies automatic Hostile (1–3) or Neutral (4)
evidence for an eligible observed creature, stored as basic `disposition`.
Identity must remain the same before and after the read. Missing, restricted,
invalid and friendly values are skipped. Hostile and Neutral are mutually
exclusive; fresh observations update the single value, including while locked.
Basic information renders Hostile red and Neutral yellow, with no `[A]` marker
or Behaviour checkbox. These checks never produce chat or Event log notices.
Migration promotes an unambiguous, active legacy `unitReaction` mark and removes
obsolete disposition behaviour flags and rumours. Manual or ambiguous legacy
marks require fresh evidence. Backups retain the basic field; account merges
keep the existing value until fresh observation. Shared reports do not transmit
the player's disposition as a behaviour claim or verified basic fact.

`RecordAutomaticEvent` is the shared journal notification path for automatic
abilities and behaviours. A new flee record logs its creature ID, behaviour,
source and identity method, and sends one chat notice through the addon's normal
prefix. Restoring an unchecked trait or adding automatic provenance to a manual
trait also produces one notice. Repeated unchanged evidence and reloads do not
duplicate the automatic-addition notice. Event logging is
independent of the chat callback; discovery/Knowledge notice settings do not
suppress automatic-record notices.

`/fieldbook debug` includes bounded session counters for monster emotes, readable
flee matches and new behaviours. It reports the last emote decision and last
readable flee decision separately, so unrelated chatter cannot hide the reason.
It distinguishes restrictions, unsupported text, absent/ambiguous identity,
missing personal entry, name mismatch, existing
behaviour and successful recording. It retains no raw restricted payloads.

Both metadata tables are optional validated backup fields. Historical sources
remain valid even when the checkbox is off. Account merging retains current
account choices and automatic history; only fresh live evidence reapplies an
unchecked mark. Shared traits retain the existing
unverified Rumour workflow; automatic provenance is not asserted for a recipient.

## Automated verification

`test_behaviour_emotes.py` exercises ten scenarios through the real addon event
handler, journal, sharing capture, backup codec, account merge and widget host:
raw/expanded text, off-target known speakers, duplicate events, unrelated chat,
missing/wrong/secret GUIDs, name mismatches, locks, shared-only entries, wipes,
manual overrides, reloads, source validation and the summary/picker/tooltip UI.
The 0.10.2 additions cover nil/empty GUIDs with target and mouseover association,
outer whitespace, ambiguous watched/personal IDs, ineligible units, chat/Event
log content and deduplication, and rejection diagnostics. Existing buff/cast
regressions also exercise the shared automatic-record notification path.
The 0.10.3 coverage exercises retained history through checkbox changes and
backups, legacy removal flags, locked additions/restoration and notice deduplication.
`test_disposition.py` has five scenarios covering reaction values, unavailable
and restricted data, identity changes, locked silent updates, rejection of manual
behaviour edits, reloads, backup/account merging, legacy migration, sharing
isolation, basic red/yellow labels and absence from the Behaviour picker.
`test_discovery_rules.py` and `test_sorting.py` also cover the list skull, its
precedence over stars/crowns, replacement by a readable level, the 18px info icon,
and maximum-level sorting in both directions. The operator's 2026-09-27 screenshot
confirms the list skull placement is acceptable. The subsequent 2px upward
adjustment applies only to the info-panel skull; its final alignment awaits reload.

## Pending in-game checks

1. Flee recording is operator-confirmed. For regression coverage, encounter a
   Stonesplinter Scout or Trogg, trigger its low-health flee emote, and check
   whether Behaviour gains cyan `Flees at low health [A]`.
   Repeat after changing targets. Confirm one `Automatically recorded` chat
   notice and one Event log entry naming the creature and behaviour. If it does
   not appear, run `/fieldbook debug` immediately and inspect Automatic behaviours:
   event count, readable-flee count and last decision. Missing GUIDs may use a
   matching currently watched creature; secret fields must remain skipped.
2. Hover the checkbox and inspect its source tooltip. Confirm readable wrapping
   in both the picker and summary at supported scales.
3. Uncheck/recheck it: the label keeps cyan `[A]`. Uncheck again, trigger a fresh
   emote and confirm it returns with one new chat/Event log notice. Repeat with
   a locked creature: fresh automatic evidence must still apply and retain its
   lock, while manual edits remain disabled. Reload to confirm history persists.
4. Verify the larger info skull sits 2px higher and Max Level sorting in both
   directions. Once the same creature supplies a readable level, its earned
   star/crown should return to the name slot and its normal numeric sort apply.
5. Observe hostile and neutral creatures. Check Hostile is red and Neutral is
   yellow in basic information, including on locked entries. Neither should
   appear in the Behaviour picker or summary, or carry `[A]`. Check that first,
   changed and repeated disposition observations all produce no chat/Event log
   notices. Ordinary first-creature discovery notices remain unchanged.

Automated mocks establish control flow and storage, not live server payload
availability, font measurements or native rendering.
