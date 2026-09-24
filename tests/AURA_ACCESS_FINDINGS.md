# Forever target-aura access findings

Observed in game on 2026-09-24: both GetAuraSlots and GetAuraDataByIndex
throw "Auras cannot be accessed when secret while tainted by 'AzerothFieldbook'".
No aura table or spell ID reaches the display. This differs from cast APIs
returning a secret ID that FontString:SetText accepts.

Inspected Blizzard-generated documentation for Forever build 69977, pinned to
[c6e8998](https://github.com/Gethe/wow-ui-source/tree/c6e89983189e4f626f549204a23c2d2bea93080a):

- [SecretPredicatesDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua):
  RequiresUnitAuraAccess is a precondition with FailureMode Error.
- [UnitAuraDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua):
  slot, index, instance-ID, buff-index and bulk aura queries share this precondition.
  UNIT_AURA is marked SecretWhenAurasRestricted; its payload is not an assured
  unrestricted substitute for a rejected query.
- [TooltipInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoDocumentation.lua):
  GetUnitAura and GetUnitBuff also require unit-aura access. Seeing an ID in
  Blizzard's tooltip does not establish that addon tooltip-data queries can obtain it.

Conclusion: the observed failure is an API access denial, not a FontString
formatting failure. No supported combat-time retrieval route was established
by this investigation. Do not infer the buff ID from the cast ID, or describe
the indexed fallback as a confirmed combat fix.

PLAYER_REGEN_ENABLED now rescans the current target and player so still-active
auras can be observed when access returns, without retargeting. Expired auras
cannot be reconstructed by this rescan. Player/player-controlled targets remain
excluded; the historical NPC row may remain until its ordinary expiry.

After /reload, /fieldbook debug opens a selectable snapshot of all its existing
chat output. Select all and press Ctrl+C; long reports scroll. Running the
command again replaces the snapshot. No hidden spell values are exported.
Verify text selection, Ctrl+C, multiline scroll and combat-end recovery in game;
Lua mocks cannot reproduce the client's security or rendering engine.

## Hovered tooltip experiment

AuraTooltipSnapshot.lua post-hooks the existing GameTooltip aura setters. It
does not invoke an aura getter, open a hidden tooltip, inspect tooltip text,
or infer a spell ID. Accessible rendered left/right text is relayed directly
to independent FontStrings in a scrollable snapshot beside the ID window.
Layout uses fixed-size text cells; this is a text snapshot rather than a
pixel-identical copy. Spell-ID visibility depends on the original tooltip.

Only target-NPC buffs and player debuffs qualify. Generic aura setters require
a public helpful/harmful filter, either supplied or exposed by the tooltip
owner. Ambiguous/forbidden tooltips are skipped. The snapshot is ephemeral,
shares the ID window's visibility/opacity/indefinite settings, and expires
120 seconds after the latest capture. Right-click dismisses it. A subsequent
tooltip refresh can create a new snapshot. Displayed durations are historical.

Live test: /reload, hover a buff on an NPC during combat, then move away.
Check that the retained tooltip includes the correct name and Spell ID; repeat
with a player debuff and verify friendly/hostile player buffs are excluded.
If it fails, /fieldbook debug now includes "Hovered aura snapshot" with the
access/relay result. SetText acceptance alone does not prove visible rendering.

### Target hover result: private tooltip, inaccessible to addons

The live report showed no GameTooltip aura callback after hovering an enemy
buff in combat. Further source tracing establishes why:

- [Blizzard_AuraButton.lua](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.lua)
  uses AuraContainerUtil.GetDefaultTooltip() and ShowAuraTooltip for these buttons.
- [Blizzard_AuraContainerUtil.lua](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua)
  returns AuraButtonTooltip, not GameTooltip.
- Both the [Mainline tooltip definition](https://github.com/Gethe/wow-ui-source/blob/c6e89983189e4f626f549204a23c2d2bea93080a/Interface/AddOns/Blizzard_AuraContainer/Mainline/Blizzard_AuraButtonTooltip.xml)
  and its Classic counterpart explicitly set forbidden="true" and
  hideFromGlobalEnv="true". The addon cannot hook or read that tooltip.
- The exported AuraContainerInbound tooltip functions style the tooltip; they
  do not expose its text or provide a snapshot/retention interface.

The hover-copy experiment therefore does not support this native target-aura
path. No further combat reload/retest is required to establish that limitation.
The experimental relay remains limited to accessible GameTooltip paths. Its
diagnostic now names that scope and reports installed hooks and callback counts.

### Player debuff capture confirmed; compact layout and toggle

The user subsequently confirmed an in-combat player Poison tooltip snapshot
(Spell ID 744). This verifies the accessible GameTooltip player-debuff path,
not the private target-aura path described above.

Public text now uses its wrapped height with small inter-line gaps. Secret text
uses a fixed 32-pixel allowance without measuring it. The window shrinks to fit
and only shows its scrollbar when needed. The ? menu's **Retain hovered aura
tooltips** checkbox defaults on and independently controls snapshot capture and
visibility, including when the ID window is hidden. Opacity and indefinite
retention still follow the existing shared settings.
