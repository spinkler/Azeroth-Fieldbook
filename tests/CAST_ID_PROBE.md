# Temporary target cast ID experiment

## Feature integration following the successful test

The current implementation is `TargetCastIDs.lua`. **Display Cast IDs** in the
Bestiary's **?** menu is saved per character and defaults to on, including for
existing characters without the setting. The single `Spell ID:` line is anchored
just above the default target cast bar. Secret IDs still use the verified direct
SetText path, without text readback or measurement.

After a cast/channel finishes or is interrupted, the displayed ID remains for up
to one minute. Changing targets, starting another cast/channel, right-clicking
the ID line, or disabling Display Cast IDs clears/replaces it sooner. Timers are
invalidated when the display changes so an old cast cannot hide a newer ID.
The original immediate-cleanup instructions below are historical.

Instant abilities now use the directly supplied third payload field (spellID)
from target-only UNIT_SPELLCAST_SUCCEEDED. No active cast API result or name
lookup is required. Public and secret event IDs use the same presentation path
and one-minute linger. A success matching an already displayed active cast's
public castBarID preserves that cast/channel's lifecycle (channels may succeed
at their start). This does not inspect or compare secret spell IDs or GUIDs.
See the pinned [success-event declaration](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L4827).

To test instant abilities live, reload, keep a hostile NPC targeted and observe an
instant ability. Last Spell ID should update without a cast bar needing to appear.
`/fieldbook debug` should report `succeeded event ...: SetText accepted` as the
last attempt. Secret instant-event rendering/delivery still needs live validation;
the earlier Quick Flame Ward screenshot only confirms the ordinary-cast path.

If no success event arrives, `/fieldbook debug on` now also traces
`UNIT_SPELLCAST_SENT`, `UNIT_SPELLCAST_SUCCEEDED` and related cast events without
logging any ID or secret payload. It labels whether each event's unit token is
the target, a legal target alias, a nameplate token, or another unit. The direct
`sent event` path is a deliberate
fallback for instant abilities: Forever documents SENT as carrying the same
direct Spell ID, while later restriction notes warn that secret instant spells
may suppress SUCCEEDED for non-player units. A SENT observation is therefore
useful evidence of the direct presentation path, but it is an initiation signal,
not independent proof that the ability completed. The trace distinguishes “no
event was delivered” from “an event arrived but SetText/display failed.”

Diagnostic text is off by default. `/fieldbook debug on` enables it for this
session; `/fieldbook debug off` hides it; `/fieldbook debug` reports the latest
status in chat. `/fieldbook debug ?` explains these commands. The old
`/afbcastid` command has been removed. The original probe procedure and file list
below describe the historical experiment; use the checkbox and current commands
for subsequent live tests. Channel and lifecycle observations remain pending.

Assessment: **live secret numeric rendering confirmed for one ordinary NPC cast**
by the user's screenshot on 2026-09-24. A successful protected call to SetText
alone is acceptance evidence; the screenshot supplies the visual evidence here.

## Source findings

Inspected Gethe's mirror of Blizzard's **Forever 1.60.1 (69977)** source, pinned to
commit `c6e89983189e4f626f549204a23c2d2bea93080a`. The following links are to that
snapshot, not the changing Retail/live branch.

1. **Blizzard retains the ID.** `CastingBarMixin:HandleCastStart` reads casting
   return 9 or channel return 8 and assigns `self.spellID` at line 426. It also
   directly presents the returned cast text through `self.Text:SetText(text)` at
   line 405. This is evidence of the presentation pattern, not a Blizzard example
   of displaying the numeric ID itself. Blizzard's trusted comparisons elsewhere
   in this function are not a template for addon secret-value handling.
   [CastingBarFrame.lua, lines 360–426](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua#L360)

2. **The ID can be secret.** `UnitCastingInfo` and `UnitChannelInfo` carry
   `SecretWhenUnitSpellCastRestricted`. Their IDs are numeric, with no NeverSecret
   exemption; castBarID does have that exemption. The predicate applies to units
   other than the player/their pet, subject to spell-specific always/never-secret
   overrides. Hostility alone does not prove a particular ID is secret.
   [Unit declarations, lines 828–893](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L828)
   · [Secret predicates](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua#L135)

3. **SetText explicitly accepts secrets from tainted callers.** Its declaration
   specifies `SecretArguments = "AllowedWhenTainted"` and adds
   `Enum.SecretAspect.Text`. That directly supports use from ordinary addon Lua.
   The argument is documented as cstring; whether this build's native conversion
   renders a secret numeric ID is precisely what the live probe tests.
   [SimpleFontStringAPI.SetText, lines 664–673](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua#L664)

4. **Secrecy propagates to the text.** `GetText` specifies
   `SecretReturnsForAspect = { Enum.SecretAspect.Text }`: it does not provide a
   public readback path. Some character/coordinate inspection APIs instead carry
   `RequiresFontStringTextAccess`, which returns nothing to tainted callers when
   Text is secret. `ClearText` removes Text secrecy but checks the
   `RemoveSecretAspects` forbidden aspect. The probe never calls GetText,
   ClearText, character inspection or text measurement; cleanup replaces the
   contents with a public empty string and hides its own panel.
   [GetText, line 353](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua#L353)
   · [ClearText, line 63](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua#L63)
   · [Text-access predicate, line 26](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua#L26)

5. **Text secrecy is not a blanket visibility prohibition.** The generated
   `Show`/`Hide` declarations do not require FontString text access. SetPoint and
   SetSize are protected operations, and SetPoint checks inherited forbidden
   layout aspects; SetParent has its own protection/change-parent checks.
   Secret anchoring can also make geometry results secret. Thus this probe fixes
   all sizes and anchors before receiving data, makes no geometry queries, and
   does not reparent or reposition during combat. These declarations do not prove
   every protected-frame interaction safe in a live client.
   [SimpleScriptRegionAPI.Hide/Show/SetParent](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua#L355)
   · [SetPoint/SetSize](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua#L135)

6. **A native formatted presentation path also exists.** `SetFormattedText` has
   the same AllowedWhenTainted and Text-aspect declarations. This supports trying
   `text:SetFormattedText("ID: %d", spellID)` without a Lua concatenation or
   string.format call. It is not live-verified here. The probe deliberately uses
   the narrower SetText experiment and a separate static `Spell ID:` region.
   `SetTextToFit` is another declared secret-aware text sink, not a guaranteed
   workaround for a numeric conversion rejection.
   [SetFormattedText, line 539](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua#L539)

7. **The actual target bar is `TargetFrame.spellbar`, also named
   `TargetFrameSpellBar`.** The Forever TOC loads the family TargetFrame source,
   Camelot overrides/templates, then family TargetFrame.xml. The inspected
   Camelot override does not replace CreateSpellbar. TargetFrame's instance
   OnLoad calls CreateSpellbar with PLAYER_TARGET_CHANGED; CreateSpellbar creates
   the named StatusBar and stores it in `.spellbar`. The target button inherits
   SecureUnitButtonTemplate. An addon-owned UIParent child, anchored one way to
   the bar, avoids adding regions to or altering Blizzard's secure button/bar
   state. It is safer isolation, not a security exemption. Layout is created
   outside combat. The probe relies on its own target events for visibility,
   not on Blizzard's fade, visibility or cast state fields; custom cast-bar
   replacements and disabled default bars are outside this experiment.
   [Forever UnitFrame TOC](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_UnitFrame/Blizzard_UnitFrame.toc#L49)
   · [CreateSpellbar, line 697](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.lua#L697)
   · [Target instance OnLoad, line 1208](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.lua#L1208)
   · [Secure target template, line 52](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.xml#L52)

Also inspected `SecretPredicateAPIDocumentation.lua`: C_Secrets exposes
HasSecretRestrictions and general/specific cast-secrecy queries. The probe uses
`issecretvalue` on the actual supplied value instead of a general restriction
prediction. A standalone generated declaration for this Lua intrinsic was not
located in the inspected files. Its absence at runtime disables the probe.
The Spell ID is never passed to C_Secrets queries or a spell lookup API.

## Changes and safeguards

- `TargetCastIDProbe.lua`: isolated, session-only `/afbcastid` diagnostic.
- `AzerothFieldbook.toc`: one line loads the diagnostic.
- `tests/test_cast_id_probe.py`: mock control-flow checks for both layouts,
  restricted-value passthrough, rejection, public/absent ID, API failure, target
  filtering, target loss, stop/interruption cleanup and repeated casts.
- This document: source findings, test procedure and interpretation record.

Only `target` is queried. Eligibility requires UnitIsEnemy and excludes
UnitPlayerControlled targets, including players/pets. If eligibility returns
secret values, the display fails closed. Cast presence checks first ask whether
the returned name is secret; only public names are compared with nil. Secret
IDs are only assigned/passed, checked with issecretvalue, then supplied directly
to SetText through pcall. No secret error payload is logged. Public numeric IDs
alone can be stringified in the last-attempt status for manual comparison.

No SavedVariables, Bestiary, discovery, spell-name inference, lookup fallback,
Blizzard hooks or persistent settings were added. No commit or push was made.

## Live test

1. Reload the UI. Outside combat, run `/afbcastid on`.
2. Target a hostile NPC with an ordinary visible cast. Below the default target
   cast bar, look for `Spell ID:` and the numeric value. The second line identifies
   `cast` or `channel`, `public` or `secret`, and SetText acceptance/rejection.
3. Observe at least one channel separately. For each case record the visible
   number (or blank/error), the second line, NPC/spell and client build. Use
   `/afbcastid status` after the cast: the last attempt survives cleanup.
4. Change target mid-cast, interrupt/cancel a cast, and observe repeated casts.
   The ID should disappear at the end or target loss and update on the next cast.
5. Seek a cast flagged `secret`, ideally one also identified as restricted by the
   existing diagnostics. Visually observing a number beside `secret: SetText
   accepted` is the decisive result. Do not try to recover it via GetText/logs.
6. For a public case, compare the displayed number with `public API ID=...` in
   `/afbcastid status`. This reference comes from the same public API value.
7. Run `/afbcastid off` when finished. Reload also resets it to off. To remove the
   experiment completely, remove the TOC entry and TargetCastIDProbe.lua.

| Observation | Interpretation |
| --- | --- |
| Numeric ID + secret + accepted | Direct secret numeric presentation works for this cast/build; ordinary Lua readability was not required. |
| Numeric ID + public + accepted | Public numeric presentation works; no conclusion about secrets yet. |
| Secret + accepted, but blank/non-numeric | Sink accepted the call; visible numeric rendering remains unproven. Investigate conversion/rendering/layout in the live client. |
| Secret + rejected | This actual SetText call rejected the value. The probe deliberately discards the error payload; additional focused diagnostics are needed to distinguish conversion from another security rule. |
| ID absent | A cast was detected but its public ID return was nil; not a secret-rejection result. |
| Unexpected public ID type | Runtime return differs from the numeric declaration; not evidence of secret rejection. |
| UnitCastingInfo/UnitChannelInfo API call failed | Failure occurred before SetText. |
| No cast/channel while default bar visibly casts | Check client build/data path and event timing; no conclusion about SetText. |
| TargetFrame.spellbar unavailable / setup deferred | Attachment/setup issue; not a secret rendering result. |
| Protected-action error, stale display or no entire panel | Record the UI error and circumstances; this is a UI/security/lifecycle issue until isolated. |

If the direct sink fails, the documented next direct-presentation experiment is
SetFormattedText with a literal numeric format, still without Lua inspecting the
secret. Do not replace this with name-to-ID inference.

## Results so far

Mock Lua 5.1 control-flow tests passed. These mocks cannot implement WoW's secret
engine, native cstring conversion, combat protection, taint or visible rendering.

User-provided live screenshot, 2026-09-24:

- Target: Tunnel Rat Geomancer.
- Ordinary cast: Quick Flame Ward.
- Visibly rendered value: **4979**, beside `Spell ID:`.
- Simultaneous diagnostic: `cast secret: SetText accepted`.
- Evidence: `codex-clipboard-61043fdd-f296-4584-8a11-a6f3fc2a52dd.png`.

This establishes that the tested client can present an actual API-supplied secret
numeric Spell ID through the probe's direct SetText path. The number above was
read visually from the screenshot, not recovered through addon Lua or GetText.
The screenshot does not independently establish the client's exact build number.
The label sits close to the cast-name text, but the numeric value is visible.

Channels, target-change cleanup, interrupted/cancelled-cast cleanup, repeated
casts and public-ID comparison remain unverified live. No broader feature or
storage changes are justified by this single test alone.
