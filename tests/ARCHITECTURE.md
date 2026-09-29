# Fieldbook section integration

`WindowFocus` registers independent addon windows on `MEDIUM`, with native
top-level raising and hooks on clickable children. This lets normal game windows
raise above the Fieldbook instead of being trapped below its former `DIALOG`
layer. Decorative and hover-only frames remain untouched.

`FieldbookShell.lua` owns the main window, artwork, title controls, dragging,
brightness, section selection and shared scrollable page frames. Its root
retains the name `AzerothFieldbookBestiary` to preserve existing saved positions,
Escape handling and other windows' anchors. That legacy name identifies the
shared window; it does not make its contents a Bestiary-only frame.

`BestiaryBook.lua` registers `bestiary` with the shell. Its content lives in the
child frame `AzerothFieldbookBestiarySection`. Creature selection, filters,
editors, models and observation dialogs remain section responsibilities.
`BestiaryPages.lua` supplies Bestiary Help, Options and Event log contents using
the shell's page factory and callbacks into the section for reset/restore work.

## Registration and navigation

The addon creates one shell and passes it to the Bestiary. A later section can
register with that same shell without editing the Bestiary builder:

```lua
shell:RegisterSection("section-id", {
    title = "Section title",
    icon = "Interface\\Icons\\INV_Misc_Book_02",
    frameName = "AzerothFieldbookSectionContent",
    build = function(content, shell)
        -- Create this section's controls beneath content.
    end,
    onOpen = function(context)
        -- Refresh or select an entry when this section opens.
    end,
    onLeave = function()
        -- Close any additional section-owned independent windows.
    end,
})
```

Registration does not construct UI. `ShowSection(id, context)` builds each
section once, hides the previous content/pages, selects its size and title, and
calls `onOpen`. `ToggleSection(id)` opens a particular section or closes it when
already shown. `Toggle()` reopens the last active section, defaulting to the
first registration. Normal Bestiary bindings explicitly select the Bestiary;
the minimap and general book command use the shared shell.

The Bestiary registers first, followed by Herbs & Minerals (`GatheringBook.lua`),
Traveller’s Atlas (`AtlasBook.lua`), Angler’s Almanac (`AnglingBook.lua`), Merchant’s Ledger (`LedgerBook.lua`), Treasure Journal (`TreasureBook.lua`), and Lorekeeper's Chronicle (`LoreBook.lua`).
Each section owns its registration, title, icon and content.
`FieldbookSections.lua` retains an empty wishlist extension point; it registers
no additional section. The Bestiary's icon is in its registration
in `BestiaryBook.lua`. The shell uses Forever's `LargeSideTabButtonTemplate` for
the outside-right navigation. Native art provides the border, mask, gold selected
state and hover; each definition supplies its tooltip name and section builder.
Tab clicks call `ShowSection(id, {navigation=true})`. The Bestiary uses this
context to resume selection and browsing without implicitly choosing a new target.
Explicit `creatureID` context still takes priority. Clicking the active tab is a
no-op. Toolbar controls are visible only when the active section supplies them.

The shell sets `afbOutsideRight` to the native tab width plus decorative padding.
`WindowPositions` includes this in clamp insets, restored bounds and overlap
rectangles. It protects the tab strip even when content overlap is unavoidable.
`afbMaxScale` lets `UIScale` cap the main window's effective scale to the available
screen without changing the saved preference or scaling section children twice.
Display changes and size changes recompute the cap; scale/footprint changes reflow
visible auxiliary windows through the same placement rules. Keep position keys
and pinned-window behavior intact when extending this system.

Use `SetSectionSize(id, width, height)` for content-driven resizing. An inactive
section may update its own size without changing the visible window. Content
inherits the root's scale once and must not also register itself with UIScale
or WindowPositions. Independent dialogs continue to register separately.

`CreatePage(name, title, bottomInset)` supplies a parchment window and scroll
body. `SetSectionPages(id, pages)` connects optional `help`, `options` and
`eventLog` pages to the toolbar and registers their scale/positions/Escape
handling. Help and Options share the existing `BookPages` position. A page's
OnShow handler can call `ShowPage(page)` to restore that position. Content
frames should close their transient independent dialogs in OnHide, including
when the root closes. Explicitly pinned utility windows may retain their
existing independent lifetime.

## Data boundary for expansion

This extraction does not change SavedVariables or sharing schemas. Keep new
section data outside `bestiary`, and specify how account/character scope,
backups and resets apply before introducing that data. In particular, the
current Bestiary `ResetDatabase` still resets character-wide settings by
clearing the root and restoring selected fields: scope that operation before
adding another section's character data. Do not add data to that root and assume
it will automatically survive the existing reset.

Sharing remains a Bestiary protocol with exact installed-version checks. Other
sections should not reuse creature IDs or report schemas implicitly. Preserve
old journal and backup compatibility when implementing their storage.

## Herbs & Minerals

`GatheringJournal.lua` uses the active account store or character `AzerothFieldbookGatheringDB`
(schema 1), with resource identities keyed by profession kind and normalized
observed name. It shares no entries, settings or reset/backup/sharing paths with
the Bestiary. The main addon initialization registers the gathering section
after Bestiary, before Atlas, Angling, Ledger, Treasure and Lore, and starts its event frame even
when its UI has never been opened.

`GatheringTracking.lua` reads the current world-object tooltip for mouseover
discovery, independent of professions. `Discover` creates identity/type, first
encounter time, zone names and map identity, but never coordinates or interaction
counts. `GatheringModels.lua` resolves presentation-only native model file IDs
by observed object ID (when available) or name; it does not prefill the journal.
Item/unit tooltips, unreadable fields and non-gathering requirements
are excluded.

Coordinate recording pairs the player's readable gathering SENT target with the
same cast GUID and spell ID at START/SUCCEEDED. A matching skill-requirement
error also confirms attempted use when there is a live readable world-node
tooltip and no focused UI control, even without a global mouse event. Empty or
root-only mouse focus is valid world input. A captured world right-click can
instead retain the resource identity for two seconds after its tooltip clears;
if the tooltip clears before the click callback, that callback may capture the
last observed identity only within 0.5 seconds. Cached hover alone, UI clicks,
unrelated errors and stale/replaced identities cannot create markers. Duplicate
error/cast notifications share one interaction. The existing pure location
sampler supplies player coordinates at confirmed interaction time; all gathering
markers are approximate. No target, minimap, bag or loot hooks collect data.

`GatheringBook.lua` and `GatheringLocationsWindow.lua` mirror Bestiary controls
in section-owned frames. Their local style/map code is intentionally separate to
preserve the other pages. Names, counts, notes, map history and sort preferences
survive reloads; filters, selection, scroll and unsaved notes survive section
changes during the session. `tests/GATHERING.md` defines the acceptance checks.

## Traveller’s Atlas

`AtlasJournal.lua` owns schema 1 in the active account store or character
`AzerothFieldbookAtlasDB`, outside Bestiary/gathering resets, backups and transport. Deliberate
recording uses stable local IDs and map-relative positions; no Atlas background
tracking frame is created. `AtlasBook.lua` registers after gathering and before
Angling, Ledger, Treasure and Lore without resizing the shell.

Atlas controls, editors, pickers and report previews are children of the section.
Leaving the page hides them by ancestry and clears focus/tooltips, while retaining
browsing/editor state. `AtlasUI.lua` uses shared primitives without altering them.
`AtlasMap.lua` owns tile/pin pools and never accesses the live World Map frame.
`AtlasReferences.lua` reads source identities; only the existing Bestiary open
context is used for navigation. `AtlasReports.lua` has its own bounded literal
schema/codec and detached Reported staging, without changing Bestiary sharing.
See `tests/ATLAS.md` for the complete data contract and live acceptance checklist.

## Angler’s Almanac

`AnglingJournal.lua` owns schema 1 in the active account store or character `AzerothFieldbookAnglingDB`.
The Almanac registers after Atlas in the existing `angling` slot, before the
Ledger, Treasure and Lore. `AnglingTracking.lua` starts during addon
initialization and collects guarded fishing/loot events and world-tooltip pool
sightings. Native tooltips that bypass callbacks are checked only while visible,
at most five times per second; there is no hidden world or bag scan.
Confirmed fishing loot can use local event identities
when cast GUIDs are unavailable. Zone sightings never assign catch sources.
The UI is lazy and uses section-owned state and left-pane editors.

`AnglingEventLog.lua` registers the Almanac's own Event Log page with the shell,
using its existing title-bar button. The journal persists an ongoing history per
character; log callbacks update only the visible log page. Clearing that log has
no effect on observations or other sections' data.

`AnglingMap.lua` adapts fishing records to the already exposed `CreateAtlasMap`
factory. Each invocation owns separate rendering/cache state; no Atlas journal
or opened Atlas page is needed. `AnglingReports.lua` implements a fishing-only
report boundary and reported storage. It does not change Bestiary transport,
permissions, costs or rewards. See `tests/ANGLING.md` for the full contract,
Forever API evidence, limits and remaining live checks.

## Merchant’s Ledger

`LedgerJournal.lua` owns schema 1 in the active account store or character `AzerothFieldbookLedgerDB`.
Five Ledger-owned modules register the existing `merchants` slot after Angling,
before Treasure and Lore. `LedgerTracking.lua` starts
before the page is built. `LedgerMap.lua` adapts observations to the existing
`CreateAtlasMap` factory with an independent instance and exact Atlas anchor.
`LedgerReports.lua` follows the existing literal, versioned section report and
preview/accept conventions. Bestiary's fixed-schema transport and rewards have
no generic contact hook, so the Ledger boundary explicitly stops at copy/paste.
Neither other pages' code nor their data are modified. `tests/LEDGER.md` records
the identity model, completeness rules, storage limits and live checklist.

`AccountSections.lua` routes the six additional journals under the same global
tracking option as Bestiary. See [account migration](ACCOUNT_TRACKING.md) for
one-time imports, identity remapping, original-store preservation and limits.

## Treasure Journal

Six Treasure-owned modules initialize immediately after Ledger and before Lore.
`TreasureJournal.lua` owns schema 1 in the separate
per-character `AzerothFieldbookTreasureDB` or `.sections.treasure` in the account
root. `InitializeTreasure` selects the active store through `AccountSections.lua`;
the journal writes only that selected store. `TreasureTracking.lua` starts before lazy UI construction.
The manual editors, item rows, details and controls belong to the Treasure page.
`TreasureMap.lua` uses the exposed independent Atlas map factory and exact Atlas
anchor. `TreasureReports.lua` provides data-only builder/validation/preview/merge
hooks: the existing fixed Bestiary transport/cost policy cannot dispatch them.
There is no alternate export protocol or inert sharing control. See
[Treasure boundaries and validation](TREASURE.md).

## Lorekeeper's Chronicle

`LoreJournal.lua` owns schema 1 in the separate per-character
`AzerothFieldbookLoreDB` or `.sections.lore` in the account root.
`InitializeLore` uses the same account-wide selector as the other sections. Lore stores captured pages, manual
passages, personal annotations, locations, relationships and received reports
with separate provenance. Its bounded additive loader retains malformed saved
records outside the active view and opens unknown future schemas read-only.

`LoreIntegration.lua` initializes the journal, starts `LoreTracking.lua` and
registers `LoreBook.lua` in the existing final tab before its UI is built.
Tracking continues while the Fieldbook is closed or another section is active.
The ItemText adapter waits for ready text and uses bounded asynchronous page
navigation for opt-in whole-book capture. Native API availability and mocked
lifecycle checks do not establish Forever compatibility; see [LORE.md](LORE.md).
NPC and supported quest passages require deliberate capture actions.

`LoreBook.lua` and `LoreEditors.lua` own the catalogue, source reader, private
drafts, entry editors and location/relationship controls. `LoreMap.lua` creates
an independent instance of the existing Atlas map factory at the exact Atlas
anchor. It never writes Atlas discoveries. `LoreReferences.lua` and the narrow
read-only adapters in `LoreIntegration.lua` enumerate already-known entries and
use existing supported navigation; missing references retain their labels.

`LoreReports.lua` and `LoreReportUI.lua` follow the existing bounded, versioned
section-report copy/paste and preview/accept conventions. Received material
remains separate from local evidence and private notes. The fixed Bestiary
addon-message transport has no Lore dispatch or pricing adapter, so Lore does
not claim network delivery or charge Knowledge.

Outside these Lore modules, integration is limited to TOC loading and the new
SavedVariable, initialization in `AzerothFieldbook.lua`, removal of the Lore
wishlist definition, the existing Options/reset interfaces and AccountSections
store selection. See [ACCOUNT_TRACKING.md](ACCOUNT_TRACKING.md) for one-time imports.
`LoreSettings.lua` initializes `autoArchiveLore` and `loreOnlyOpenedPages` on the
existing character settings root only when absent. `BestiaryPages.lua` presents
the two controls in the shared Options page; `BestiaryJournal.lua` preserves
their explicit values during Bestiary reset. Other section data, tracking,
appearance and navigation contracts remain independent.
