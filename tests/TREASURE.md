# Treasure Journal — 0.15.0 review and validation

This is a functional first iteration in the existing Treasure tab. It records
container kinds and historical encounters, never live availability. No bundled
container locations, requirements or loot tables seed the journal. Work remains
uncommitted; no push, tag, release or publication is part of this request.

## Using the page

1. Open **Treasure Journal**, then **Record a find**. Choose an existing kind
   explicitly, or **New provisional kind**. Choose world/portable form and
   container, recoverable-find or salvage category. A portable item ID is optional.
2. Record independent sighting, access-attempt and inspection facts. Portable
   acquisition, opening/inspection and observed carriage are separate contexts.
   Enter an attempt result or access observation only when known.
3. Location starts unknown. **Use player position** offers an approximate player
   location for review. Enter a map ID and both percentage coordinates to place
   or correct a point manually. Zone-only records need no coordinates; optional
   subzone, floor/interior and instance labels remain attached to that encounter.
4. Contents accept one item ID, pasted item link or item name per line. Optional
   `; observed quantity ; recovered quantity` fields allow, for example,
   `12345;3;1`. Numbers default to one observed item and unconfirmed recovery.
   Choose partial/full capture after inspection. Full capture and recovered
   quantities are explicit player assertions. Missing/partial capture is not empty.
5. Scroll the left editor for encounter notes and **Observation time unknown**.
   A new manual encounter otherwise uses its save time as the player's asserted
   observation time. Unknown observation time stays absent; local recording time
   is separate. Corrections preserve an existing observation date.
6. Search known names, labels, notes, zones and observed items. Combine category,
   location, personal/reported/contents and bookmark filters. Sort by name,
   location or original observation time. **Reset filters** affects only Treasure.
7. Select historical pins or rows in **Encounter history**, then **Correct** or
   **Remove**. Removal has a separate confirmation and recalculates summaries,
   search and pins. Automatic encounter corrections permit location, access and
   notes, while retaining their original contents/outcome evidence. To correct a
   mistaken form/identity, remove that encounter and record it under the right
   kind. **Kind notes** edits personal labels, category, notes and bookmark reason.
8. **Look for again** is entirely player-controlled. Opening a container does
   not clear it, and failed interactions do not create it. **Expand** gives the
   selected detail tab a taller left-column reader. **Newer / Older** pages through
   eight encounters at a time; all retained history remains available.

## Model and provenance

`TreasureJournal.lua` owns schema 1 in `AzerothFieldbookTreasureDB` in character
mode, or `AzerothFieldbookAccountDB.sections.treasure` with Account-wide tracking
enabled. Its initializer uses the existing section selector. Kinds and encounters
import once, preserving annotations, references, origins and receipts; the local
store remains intact. Other journals' resets/backups remain independent.
See [ACCOUNT_TRACKING.md](ACCOUNT_TRACKING.md). Future schemas use
a detached read-only view. Invalid saved kinds/encounters remain in the original
store, excluded from active views with a count notice. Valid sparse records have
their optional fields normalized. No active-loot assignment is persisted.

- **Kind:** local stable ID/reference, observed/manual name, form, category,
  optional portable item ID, personal label, private notes and bookmark/reason.
  Client item IDs identify portable kinds. World identities remain provisional;
  neither same-name records nor matching coordinates are automatically merged.
  No world GUID format or object template ID is invented or parsed.
- **Encounter:** local ID, kind reference, context, original observer/key/method
  and optional observation time; independent outcome flags; missing/partial/full
  contents capture; item rows and optional explicitly recovered quantities;
  location/precision/meaning, access text/method, result and private notes.
  Locations can be approximate player positions or manual placements; both retain
  their coordinate map and optional interior context. Editing automatic locations
  adds manual location provenance without relabelling automatic contents.
- **Reported evidence:** original per-encounter provenance plus recipient-side
  receipt time and original reported kind identity. Later compatible additions
  retain the first receipt and record an enrichment receipt separately. Imported
  inspections/recoveries never increment personal counts. A later personal
  sighting does not validate reported contents or access requirements.

Summary statistics are derived from remaining encounters. “Recorded encounters”
includes the player's manual assertions and automatic observations, and labels
reports separately; it is not a lifetime-opening total. Contents counts require
actual item rows or an explicit full manual capture. There are no drop rates,
gold estimates, current-possession indicators, completion flags or exhaustion
states. Acquisition history does not assert that the item is still owned.

## Pending live observation — 2026-10-04

Follow-up on 2026-10-08: a Battered Chest in Darkshore recorded Haunch of
Meat ×2, Minor Mana Potion ×3 and Small Dagger ×1, but omitted the
Red-speckled Mushroom ×3 visible in the loot chat. The screenshot establishes
the missing row, but not the native event sequence or which slot fields were
unreadable. The repeated "Receipt unconfirmed" label reflected the observer's
lack of automatic recovery tracking, rather than a failed inventory transaction.

The contents reader and report preview now show observed quantities without
that repeated receipt label; explicitly recorded recovery details remain visible.
Capture retains readable item names for explicitly typed item slots when links
are not yet available. Unique, unambiguous names can gain a later item ID without
duplicating the observation, including report enrichment and older report replay.
Ambiguous names never replace an existing ID. All item quantities still require
agreement with the single-source quantity.

READY updates retain earlier items. Slot changes/clears, item-data events, a
bounded 0.2-second retry and the final close-time read revisit the attributed
window, including when no item was initially readable. Explicit None slots with
no remaining sources are skipped; occupied/unreadable or mixed-source slots
still reject a snapshot. OPENED rejection, close, world entry and expiry clear
retry state. Polling does not extend its lifetime or redraw unchanged contents.
Regression fixtures exercise these gaps, but the screenshot's exact cause and
the fix's native behavior remain unverified. Existing historical omissions are
not backfilled. Reload, then compare the next naturally encountered chest with
its loot; no search for another chest or scheduled reminder is required.

Solid Chest follow-up on 2026-10-07: the expanded diagnostic identifies source
`GameObject-0-4615-0-2158-2850-000045AA0A`, observed Solid Chest, no tooltip
object ID, and Opening spell 3365 targeting Solid Chest with no clicked context.
This establishes a named opening was observed but does not establish the success
event order. The reader previously ignored pending casts. It now accepts a fresh
pending Opening (3365) when all loot slots validate one compatible GameObject
source; it need not wait for SUCCEEDED. Failed/interrupted or expired casts,
conflicting identities, mixed sources, fishing and item-origin windows remain
excluded. Regression tests cover delayed/absent success and close-only autoloot.
Diagnostics now also indicate whether a cast or completed interaction remains.
The operator confirmed successful live capture after this correction on
2026-10-07. This validates the reported case; the exact native event order was
not traced.

Follow-up on 2026-10-07: a Battered Chest in Teldrassil was missed. The
screenshot shows the world-loot identity rejection, but truncates at `Source:
GameObject-...`; the observed identity and opening details are not visible.
Review found that a newer identified container hover could override a fresh
opening interaction. Attribution now prioritizes that interaction and rejects
its mismatches without falling back to the hovered object. Regression coverage
includes both ID-bearing and ID-less openings followed by a different hover,
and a matching hover that must not override a conflicting opening.
The full status is now available by hovering the bottom status line. This is
a code correction, not a confirmed explanation of this particular missed chest;
live verification remains pending and the missed contents are not backfilled.

Food Crate follow-up on 2026-10-06: the player received Mutton Chop ×4,
but Food Crate was absent from the unfiltered five-entry journal. The status
remained the default capture guidance, with no rejection diagnostic. The
screenshots do not establish the loot event sequence or source GUID.

Code now retains a fresh, validated LOOT_READY snapshot if LOOT_CLOSED arrives
without LOOT_OPENED. It preserves partial inspected contents only, never claims
personal recovery, and keeps fishing, exact single-source attribution and
quantity checks. OPENED rejections and expired snapshots cannot use this path.
READY failures involving a world-source mismatch retain their diagnostic even
without tooltip context or OPENED. All 68 focused Treasure tests passed,
including Food Crate close-only capture, retained rejection diagnostics and
rejected/expired snapshots. Food Crate live capture remains unverified: reload
and open another crate; check for its contents or the retained status message.

A Battered Chest looted in Redridge did not appear in Treasure Journal.
The supplied loot screenshot showed Minor Mana Potion ×2, Lesser Healing
Potion ×3, Linen Cloth ×2 and 98 Copper. Autoloot usage was not confirmed.
The journal reported: “Capture skipped: Loot source is not a recognized container.”
The source-identification cause remains unresolved; do not mark this fixed.

Follow-up on 2026-10-05: another Battered Chest was first opened with Shift
held to inspect its contents, then cancelled, then fully looted. Neither attempt
appeared in the journal. Screenshots show Minor Mana Potion ×2, Haunch of Meat
×2, Moss Agate, Ice Cold Milk ×2, Scroll: STHENIC LUNATE and 1 Silver, 6 Copper.
The zone and bottom capture-status diagnostic are not shown. The failed manual
inspection means an autoloot-cleared window alone cannot explain this attempt.
Opening should suffice; taking every item is not required by the observer.
The retained status was subsequently supplied: "Capture skipped: World loot
has no matching container tooltip or recent opening interaction". This confirms
the GameObject source path rejected the identity correlation, but does not
distinguish missing context from mismatching tooltip identity.

Code review found that an empty UNIT_SPELLCAST_SENT target discarded the
right-click identity. Opening (3365) now retains a container clicked within
0.5 seconds when the target is empty; it still requires matching cast completion
and a single compatible GameObject loot source. Hover, unrelated spells, stale
clicks and failed casts cannot enable this fallback. This is a tested correction,
not yet a confirmed explanation of the live failure. World rejection diagnostics
now include source GUID, observed name/object ID and last opening-cast details.
Focused validation on 2026-10-05: all 65 Treasure tests passed.

Subsequent live observation on 2026-10-05: the player confirmed success and
supplied a screenshot showing Battered Chest, World / container, Redridge
Mountains, Contents recorded. This verifies capture for that encounter after
the correction; it does not establish every opening/event-order variant.

Diagnostics now include the rejected readable source GUID and observed container
name, and preserve the original failure reason if autoloot clears the window.
A separate zero-quantity coin-slot rejection was corrected and passed the
Treasure tests, but is not established as the cause of this encounter.

When the player naturally encounters another chest, after loading these changes
with `/reload`, open/loot it and check Treasure Journal. If capture fails, retain
the complete bottom status message (especially `Source:` and `observed container:`),
chest name, zone and whether autoloot was enabled. World-source failures now
also expose tooltip object ID and opening details. Use that evidence to diagnose
source recognition. The player does not know another chest location; wait for an
opportunistic observation rather than asking them to find one. No scheduled
reminder or active monitor is requested. Previously missed loot is not backfilled.

## Automatic observation and exact limitations

The observer is initialized before any page UI exists. It performs a debounced
read of ordinary carried bags on `PLAYER_ENTERING_WORLD` / `BAG_UPDATE_DELAYED`.
Only readable `C_Container.GetContainerItemInfo(...).hasLoot == true` items can
create portable knowledge. The first observed carriage of a kind is recorded
once in the retained history; ordinary bag movements add no new encounter and
never imply recovery, acquisition source or current possession.

For portable contents, every readable loot slot must identify the **same single exact
GUID** previously returned by `C_Item.GetItemGUID` for an observed openable bag
item. The code compares opaque GUIDs without parsing them. It also requires
readable `IsFishingLoot() == false`. A missing/false `isFromItem` flag does not
override an exact observed bag GUID; restricted or malformed flags still reject.
No current target, spell outcome or loot-chat text supplies portable identity.
World objects use the separate guarded path below; creature/fishing/gathering
loot cannot enter the portable path merely by opening a loot window. Purchases, trades, mail, quest
rewards and generic inventory changes cannot become recovered contents. They
may expose an openable item as carried; its acquisition source remains unknown.

World containers use a fresh `C_TooltipInfo.GetWorldCursor` Object tooltip,
retained for at most 15 seconds to survive its dismissal during opening. Its
observed GUID (when supplied) or numeric object ID must match the GameObject
source GUID of every loot slot. Names must contain an English whole word:
chest, crate, coffer, strongbox, footlocker, lockbox, cache, barrel or sack.
Unrecognized/localized names remain manual. If the tooltip lacks an object ID,
a world right-click on that tooltip or a matching completed player opening cast
provides a three-second correlation window. The object ID then comes from the
single GameObject loot source. A pending Opening (3365), retained for at most
30 seconds, can also correlate when compatible world loot arrives before or
without the success notification. Hover alone never enables this fallback. Cast
failure/interruption, unrelated casts, other clicks, window close and world entry
clear the relevant interaction. A missing isFromItem flag is accepted only for
world-object samples and exact observed bag-item samples. The page status
reports attribution failures even when the page was closed during looting.
Fishing, creature sources, mixed sources,
and item-origin windows are rejected. Autoloot retains the bounded READY snapshot.
World records use `context=world`, approximate player coordinates and partial
contents without asserting recovery. The optional local `objectID` kind field
survives reload and groups subsequent spawns; manual name-only kinds stay separate.
The existing report format does not transmit this local identity field.

Live verification still required: reload, open a Weapon Crate normally and with
autoloot, verify its name, item contents and approximate map marker, then reopen
it to check deduplication. Check a creature, fishing loot, herb and mineral node
produce no Treasure entry. Test another crate of the same type groups under the
same kind. The previously looted crate cannot be reconstructed from loot chat.

The bounded lifecycle is:

- At most 384 bag-item GUIDs. Identity remains usable while recorded bag snapshots
  still contain that item; a later snapshot that no longer finds it starts a
  60-second grace period, covering consumption before autoloot notifications.
- One `LOOT_READY` candidate, valid for three seconds; one opened window waiting
  for readable contents or active inspection, valid for 60 seconds after its last
  attributable event update. Polling cannot extend that lifetime.
- A READY snapshot preserves contents removed by autoloot before OPENED. An
  unreadable or differently attributed **nonempty** window cannot inherit it.
- At most 128 recent correlated item interactions, expiring after 120 seconds.
  Repeat READY/OPENED/slot updates and quick reinspection reuse one encounter,
  taking maximum observed quantities instead of adding duplicate quantities.
  Later encounters can be separate even at identical coordinates.
- Removing a correlated inspection suppresses its repeated signals for the
  remainder of the currently open loot window. Closing that window clears the
  suppression; reopening the same item immediately can rediscover it. Deleting
  an encounter after the window closes also allows immediate rediscovery.
  Capacity exhaustion omits new automatic
  captures with a status explanation instead of evicting context and recounting.
- Close/reload/world-entry clears transient active context. A stale open loot
  window across reload does not itself generate a new inspection.

Automatic contents are always **partial** because native event order and
autoloot can hide rows. No receipt signal is treated as strong enough to confirm
personal recovery in this iteration. World sightings/identity, access conditions,
portable acquisition locations, unsupported sources and recovery quantities use
manual recording. Missing readable APIs fail closed. Delayed item metadata can
retry the current attributed window and enrich already recorded IDs. Outside
that window it cannot create encounters or move selection.

### Client API evidence

The target remains Interface **16001**, World of Warcraft: Forever. Inspected
Blizzard UI source on the `forever` branch, accessed 2026-09-28:

- [Container API documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua)
  defines `ContainerItemInfo.hasLoot`, item ID/name and ordinary bag-slot queries.
- [Native ContainerFrame](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua)
  uses `hasLoot` for the opening action and `ItemLocation:CreateFromBagAndSlot`.
- [Item API documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)
  defines `C_Item.GetItemGUID` and item metadata reads.
- [Loot event documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootDocumentation.lua)
  defines READY, OPENED's item-origin boolean, slot changes and closure.
- [Loot slot constants](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootConstantsDocumentation.lua),
  checked 2026-10-08, define None=0, Item=1, Money=2 and Currency=3.
- [Native LootFrame](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/LootFrame.lua)
  uses loot-slot link/info reads and fishing context. The repository's existing
  `BestiaryLoot.lua` supplies precedent for guarded `GetLootSourceInfo` GUID/quantity
  pairs, but it is unchanged and not used as a Treasure data source.

**Unverified in the running client:** whether a portable opening exposes an
exact GUID equal to the prior bag-item GUID, whether it remains readable at the
required event boundary, and actual READY/OPENED/autoloot ordering. Shortest test:
carry one openable item, allow the bag observation to finish, open it once with
autoloot off, then repeat with another item and autoloot on. Expect one carriage
record for the kind and one partial inspection per attributable opening. If the
GUID/item-origin contract is unavailable, only carriage is recorded; use the
manual form. This is a conservative omission, not proof of native API behavior.

## Map and UI boundary

The map is an independent invocation of the already exposed `CreateAtlasMap`
factory. Its anchor exactly matches AtlasBook: `TOP` to content `TOPLEFT`,
**632, -205**. It uses the same **572.22 × 373.725** fit rectangle, native map
aspect fitting, borders, overlays, clipping, zoom/pan and player arrow. No Atlas
widget is reparented and no Atlas state or global map state is changed.

Only **world finds** and **explicit portable acquisitions** can produce pins.
Portable opening and carried locations remain encounter metadata. Missing
coordinates never become a point, and 0,0 is rejected. The map retains its region
and readable empty state. Known-map selection and the optional all-finds-in-zone
scope use only recorded knowledge. Overlapping points cycle individual histories;
selecting another kind's all-zone pin preserves the catalogue selection and
reveals that encounter. Tooltips show source, original date, outcome, location
accuracy, notes and report receipt. The persistent historical caption remains
visible above the map.

UI controls use existing Fieldbook/Atlas primitives with independent instances.
Editors replace only Treasure's left directory, inside the existing content
bounds; outside-right tabs stay clear. Saved filters, selection, map ID and
scroll state survive reload. Editor drafts and map zoom/pan survive section
switching during a session. Hidden Treasure does not redraw on observations.

## Sharing foundation — intentionally no delivery UI

`Sharing.lua` / `SharingReport.lua` and the existing inbox, costs, identity and
reward rules are Bestiary-specific. There is no generic section dispatcher that
can carry Treasure payloads without changing those rules. Existing Atlas,
Almanac and Ledger report modules are also schema-specific, not reusable generic
transports. They are read-only references for validation and preview conventions.

`ns.TreasureReports` exposes **Build, Forward, Normalize, Validate, Preview,
Prepare, Cancel and Accept**. This is a tested data-only adaptation boundary for
a future integration with the existing authorized transport/points policy.
There is no parallel wire codec, addon-message prefix, networking, copy/paste
export or apparently functional Send button. Delivery and in-game report
acceptance remain explicitly deferred.

Builders select personal encounters and optional contents/access/locations.
General/encounter notes require explicit `notes=true`; private labels and
bookmark reasons are excluded. Forwarding uses original reported identities and
per-encounter origins. Exact installed TOC version and payload schema are checked.
Prepare produces a detached validated snapshot; acceptance requires its ticket.
Editing a caller's original payload cannot change the accepted snapshot.

Imports use original source+encounter key deduplication. Compatible omitted facts
can enrich one original encounter without multiplying evidence or erasing known
facts. Conflicting coordinates, quantities or nonempty notes reject atomically.
Personal evidence and private kind annotations are never overwritten. Forwarded
sources are claims, not cryptographic authentication. No Treasure path touches
points or discovery rewards. Reports permit 1–50 encounters, 80 item rows each,
64 KiB of bounded data, depth 10 and 20,000 visited values. Unknown keys, cycles,
metatables, sparse/oversized lists, invalid types/IDs/quantities/coordinates,
future dates, control text and active WoW markup are rejected. Imported strings
are never executed; native item tooltips are constructed from validated IDs.

## Storage and performance limits

There are at most 2,000 kinds and 20,000 detailed encounters, with 80 item rows
per encounter, 160-byte labels and 4,000-byte notes. New records at capacity are
refused; existing detailed history, reports and notes are never silently pruned.
History is indexed and summaries/search text cached until affected observations
change. The detail reader pages eight encounters and reuses its widgets; the
map renderer retains its existing cap of 192 visible overlap groups with History
available for the remainder. Metadata caches hold at most 4,096 names and issue
at most 512 one-off missing-item requests per session, avoiding retry loops.
Client metadata already available can still be displayed beyond that request
cap. There are no world scans, continuous hidden redraws or gameplay hooks.

## Files changed for this request

The checkout already contained unrelated uncommitted changes. This list is
relative to the **starting working tree**, not the repository's HEAD diff.

| File | Change |
| --- | --- |
| `TreasureJournal.lua` | New isolated model, validation, persistence, derived summaries/search and corrections |
| `TreasureTracking.lua` | New guarded bag/portable-loot observer and bounded correlation lifecycle |
| `TreasureReports.lua` | New data-only report builder, validator, preview and atomic merge/forwarding hooks |
| `TreasureMap.lua` | New independent historical map adapter |
| `TreasureEditors.lua` | New manual recording, notes/classification and confirmed-removal editors |
| `TreasureBook.lua` | New existing-slot registration, catalogue, details, filters and independent view state |
| `AzerothFieldbook.lua` | Minimal additive initialization immediately after Ledger |
| `AzerothFieldbook.toc` | Six module entries, own SavedVariables name and version 0.15.0 |
| `FieldbookSections.lua` | Remove only the replaced Treasure placeholder; Lore is unchanged |
| `tests/treasure_test_harness.py` | New synthetic Forever/widget fixtures, never live seed data |
| `tests/test_treasure.py` | New focused acceptance/regression tests |
| `tests/test_fieldbook_tabs.py` | Register Treasure in existing seven-tab regressions; retain Lore placeholder assertions |
| `tests/TREASURE.md` | This review, API evidence, limitations and acceptance checklist |
| `tests/ARCHITECTURE.md` | Updated section integration documentation |
| `README.md` | Current version, Treasure usage, storage and limits |
| `CHANGELOG.md` | Self-contained unreleased 0.15.0 change summary; older entries retained |
| `AGENTS.md` | Current implemented-section count, character scope and requested 0.15.0 milestone |

The pre-edit file-hash audit confirms **no changes by this request** to Bestiary,
gathering, Atlas, Almanac or Ledger implementation files, shared shell/style/map
helpers, account tracking, their observation/reward logic or existing private
SavedVariables. Existing dirty files remain intact. No shared infrastructure was
refactored. Section order, default selection and main-window dimensions remain
unchanged.

## Automated checks actually performed

On 2026-09-28, using the bundled Python executable with the existing pinned
`lupa==2.8` dependency:

- Starting baseline: full runner, **51 test files, zero failures**.
- Focused Treasure suite: **46 tests passed**. Covers identity, history, partial
  capture, no invented receipt, unrelated events, source changes, timeouts,
  autoloot snapshots, bounded buffers, removal, private notes, report validation,
  atomic enrichment/rejection, forwarding, imports with no personal rewards,
  persistence, malformed entries, actual UI builders, tooltips, manual editing,
  empty states, Atlas geometry/isolation, page switching, stable browsing,
  supported inherited scales and a 1,001-encounter history with widget reuse.
- Full command: `python -B -X utf8 tests/run_tests.py`. The normal `python` command
  is unavailable on this workstation, so the bundled Python runs that exact
  runner. Final result recorded after implementation: **52 test files, zero
  failures**, **67 Lua 5.1 files**, manifest, bindings and version **0.15.0** valid.
- `git diff --check` and the starting-working-tree hash scope audit pass.

Synthetic widget tests establish geometry, ownership and control flow. They do
**not** establish native visual rendering or actual Forever client event order.

## Actual in-game checks performed

**None for this implementation.** No live visual, tooltip, loot-event or sharing
delivery check is claimed. No in-game SavedVariables were read or rewritten by
the development tools.

## In-game checks still required

1. Record the exact Forever build. Open an empty Treasure journal, record a
   world find, unknown-location find, failed access attempt and salvage entry.
   Test every filter together, clear them, bookmark/unbookmark and edit notes.
2. Compare Atlas and Treasure on the same map at requested scales
   50/75/100/125/150% and available resolutions such as 1920×1080, 1280×720 and
   1024×768. Verify matching top/bottom/width, readable native fonts, menus,
   clipping, empty-map state and unobscured outside tabs. Test long names/notes,
   a scrollable manual form and the expanded detail reader.
3. Use player position, then manually correct it; verify honest precision and
   map/floor/instance labels. Leave coordinates blank and try 0,0. Test overlapping
   pins, known-zone changes, all-zone scope, pan/zoom and missing artwork.
4. Manually record a portable acquisition, then open that item at an inn. Only
   the acquisition may create a find marker; opening must remain metadata. Check
   full, partial and missing contents separately, item icons/tooltips, pasted
   links, delayed metadata and explicit recovered quantities.
5. Perform the short portable GUID/autoloot test above with Treasure hidden.
   Reopen a partly looted container, change target, interrupt/close/open another,
   remove a correlated inspection and exercise full bags. Verify no duplicate
   inspection and no automatic recovery claim. If source identity is unreadable,
   confirm omission and use the manual form.
6. Loot a creature, fish, gather, buy/trade/mail items and receive a quest reward.
   None may be recorded as container contents. A newly carried openable item may
   appear as carried only, with no inferred acquisition source.
7. Switch through all seven tabs during capture, search, scrolling, notes drafts
   and map browsing; then reload saved records. Verify Treasure view state and
   notes persist, transient active correlation clears, and all other pages keep
   their original appearance, controls, tracking, data, rewards and map state.
8. Confirm manual removals update historical pins/contents/counts and retain kind
   notes/bookmarks. Future live report delivery requires an authorized transport
   integration; only the report adaptation hooks are presently testable.
