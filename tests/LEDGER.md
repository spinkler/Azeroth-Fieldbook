# Merchant’s Ledger — 0.14.0, unreleased

Current storage scope: the global Account-wide tracking option selects this
section's account or character journal. The original per-character SavedVariable
is preserved. Earlier per-character implementation notes below describe the
original section boundary; see [account tracking](ACCOUNT_TRACKING.md) for the
current migration and storage contract.


The existing `merchants` tab is a discovery-driven contact directory. There is
no bundled NPC, inventory, trainer, recipe or coordinate database. The original
wishlist remains in Help. No Forever client interaction or visual verification
was performed for this implementation; synthetic checks are a separate form of
evidence and the in-game checklist below remains outstanding.

The funnel menu includes **Current Zone**. Combine it with a search such as
`repair` to list matching known contacts with a recorded or reported sighting
in the player's current zone. It follows zone changes while the Ledger is open,
retains the checkbox across reopening, and returns no matches if the current
zone is unavailable. Choosing a fixed zone/subzone, All zones or Clear disables
Current Zone. This filters historical sightings; it does not discover NPCs or
establish their current presence.
**Link identity** sits between Search and the contact list in the left pane.

## Ownership and files

| File | Responsibility |
| --- | --- |
| `LedgerJournal.lua` | Character schema, contact references/identity decisions, observations, bounded stores, cached search index and queries |
| `LedgerTracking.lua` | Guarded Forever API reads, frozen interaction visits, bounded refreshes, deferred item metadata and service events |
| `LedgerMap.lua` | Selected-contact location adapter to an independent existing Atlas map renderer |
| `LedgerReports.lua` | Contact report selection, literal envelope, strict normalization, preview tickets, acceptance, deduplication and forwarding |
| `LedgerBook.lua` | Existing section registration, directory, details, notes, explicit identity linking, report controls and initialization |
| `tests/ledger_test_harness.py`, `tests/test_ledger.py` | Synthetic events, data and real widget-builder regressions |

Necessary integration outside Ledger files: one initializer in
`AzerothFieldbook.lua`; five module loads, one SavedVariable and version metadata
in the TOC; removal of only the merchant placeholder definition from
`FieldbookSections.lua`; updated tab regression tests and documentation.
The complete modified-file list outside the new Ledger modules/tests is
`AzerothFieldbook.lua`, `AzerothFieldbook.toc`, `FieldbookSections.lua`,
`tests/test_fieldbook_tabs.py`, `README.md`, `CHANGELOG.md`, `AGENTS.md` and
`tests/ARCHITECTURE.md`.
Bestiary, gathering, Atlas, Almanac, Treasure and Lore implementation files are
unchanged. No additional outer tab or top-level window is created. Editors are
section children; the shared Options, Help, focus, scale and auxiliary-window
policies remain owned by the shell.

## Identity and per-vendor stock

Each record has a durable local `contact:N` ID and `ledger:<journal-origin>:N`
reference. The NPC template ID is separate; it is never an inventory key.
Names and localized sublabels are display/search data, never merge keys.
At most eight observed GUID aliases correlate known individuals with stable
local contacts, including movement and reloads while that GUID remains valid.

An unfamiliar GUID can reuse exactly one personally encountered contact with the
same NPC template and name, compatible titles (missing titles do not conflict),
and a personal sighting within a circular 0.25 map-coordinate-unit radius.
Map, zone, subzone and coordinate precision must agree. This is a map-relative
radius, not yards. A contact with another GUID already seen during this journal
session is excluded to keep concurrently encountered individuals separate.
Known GUIDs continue to follow travelling contacts regardless of distance.

Missing positions, conflicting titles and multiple eligible contacts do not
trigger this fallback. It never merges existing records or matches report-only
contacts. Existing duplicates still use **Link identity**, which preserves
notes, observations and stable references after explicit confirmation.

Each contact separately owns goods, lessons, roles, manual annotations and
sightings. Goods use item/currency/spell identity plus purchase bundle and
extended-cost type/identity context, not a global item catalogue. Duplicate
indistinguishable listings make a scan partial instead of allowing a completeness
claim. Quotes, stock and timestamps never move to a newly selected target.
Maximum item stack size is not used as purchase quantity.

Goods retain first/last observation and a latest snapshot. Price and stock have
their own timestamps: an unreadable price retains the last readable quote with
its original date; unreadable stock is unknown, never zero. The merchant stock
contract is positive = finite, zero = listed/sold out, -1 = unrestricted; other
negative/unreadable/missing values are unknown. Zero copper is valid. Additional
costs are separate, per bundle. A derived per-item copper price appears only
with a positive known bundle and an exact integer division. No replenishment,
remote purchase, current availability or restock inference is made.

Opening/reopening creates a frozen visit identity. Refreshes update the same
bounded catalogue instead of appending full inventories. Scans require a
readable count, stable interaction NPC, resolved offering identities and the
native All filter for completeness. Empty, filtered, changed, oversized,
ambiguous, failed or partially loaded scans remain partial. Only a complete
inspection marks prior goods **Not seen on the latest inspection**; no item is
deleted or described as no longer sold. Trainer observations always explicitly
leave full curriculum completeness unestablished. Buyback is never scanned.

## Capture and source distinctions

| Field | Capture / limitation |
| --- | --- |
| Name / template / GUID correlation | Readable `UnitName("npc")` / creature GUID at interaction; no target fallback |
| Actual sublabel | Readable native tooltip title, including name-typed, bracketed and legacy level-line layouts; matching-GUID target/mouseover fallback. Ambiguous/missing layouts stay unknown. An observed Innkeeper title also grants the Innkeeper role alongside Merchant; names alone do not. |
| Merchant / repair / trainer | Native merchant/trainer interaction and `CanMerchantRepair`; exact English class-trainer titles also identify trainers on target, mouseover and gossip; overlapping roles on one contact |
| Banker / auctioneer / stable / transport / innkeeper | Readable `npc` identity at the corresponding service event, including innkeeper bind confirmation. Missing event/identity stays unsupported; manual role annotation is available |
| Target / mouseover | Discovers the nine Classic classes with exact English class-trainer titles (plain or bracketed); otherwise revisits already identified service GUIDs only. Ordinary NPCs and trainer-like names are excluded. Other locales still use native training interactions |
| Zone / subzone / map | Existing stateless map/location sampler; unknown maps remain usable directory entries |
| Coordinates | Prefer the existing guarded `CreatureLocations.Sample` NPC position when readable and natively converted to the same recorded map, source `npc`. Otherwise use player position only during a nearby service interaction, source `player`, labelled **Encountered near**, approximate. No distant player-position substitution, 0,0 placeholder, guessed conversion or inferred route |
| Goods | Readable merchant item/currency/spell ID, name/icon, price, purchase bundle, additional costs, stock, purchasable/usable flags and typed displayed requirements |
| Recipe / profession | `C_Item.GetItemInfo` class `Enum.ItemClass.Recipe` and localized subtype only; no name-based recipe or profession inference |
| Training | Native name, rank/subtext, icon, category, quoted cost, availability, required level, skill/ability requirements. Pet training costs remain training points, not copper |
| Manual facts | Contact name/sublabel, service role and speciality; personal access notes and favourite. Manual claims retain method `recorded` |
| Reports | Identity, sublabel provenance, services, locations, selected goods/lessons and explicitly included notes remain reported claims. Meeting/linking confirms only actually observed fields |
| Unsupported | Unreadable NPC positions, undisplayed requirements, unreadable restrictions, hidden inventory/curriculum, recipe graphs, current remote stock, route planning, automated purchases and external service databases |

Restricted API results are rejected with public-value checks and `pcall`.
Nothing reads hidden protected frame state or tries an alternate path around
denied data. Delayed metadata jobs retain contact and offering identity, never
the mutable target or merchant slot. They cannot refresh observation/quote
dates. Close/reopen invalidates queued visit scans. Updates coalesce at 150 ms,
with two bounded load retries and at most one metadata-triggered rescan per
visit. Unsupported metadata cannot create a recurring inventory poll.

Observed Training uses the Known Goods heading/icon layout. Its top sort arrow
chooses required level (ascending, unknown last) or name (A–Z), remembered in
`state.trainingSort`. The chosen order spans personal and reported lessons;
rank and stable source/key ties keep repeated refreshes consistent. Green means
available when inspected, red unavailable, grey already known and gold unknown.
Required levels use gold, categories/report labels blue and dates/source details grey.
These labels remain historical; viewing a lesson does not recheck availability.
Native trainer textures are retained locally across unreadable refreshes. Older
lessons and reports can resolve cached artwork through `C_Spell.GetSpellTexture`
using name/subtext, falling back to a question mark. This is display-only; report
fields, lesson identity and observation times are unchanged.

### Forever compatibility evidence

Target: TOC Interface 16001. Inspected installed-research source commit
`c6e89983189e4f626f549204a23c2d2bea93080a` (Forever 69977) and current `forever`
branch on 2026-09-28. These are Blizzard UI/API sources mirrored by Gethe:

- [Merchant API structure and events](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/MerchantFrameDocumentation.lua)
  exposes `C_MerchantFrame.GetItemInfo` as a possibly absent table, not the old
  Classic multi-return function. Its structured fields include `stackCount`,
  `numAvailable`, `hasExtendedCost`, `currencyID` and `spellID`.
- [Native merchant UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua)
  uses the `npc` unit, separates buyback, applies `stackCount` to purchase
  calculations, renders zero availability as unavailable, and reads extended
  costs via `GetMerchantItemCostInfo` / `GetMerchantItemCostItem`.
- [Native trainer UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.lua)
  establishes return order `name, type, texture, requiredLevel, subtext, category`,
  skill/ability requirements and separate pet training-point costs. No player
  level is substituted for required level.
- [Typed tooltip lines](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoSharedDocumentation.lua)
  supply UnitName, UnitLevel, None, UsageRequirement, ErrorLine and DisabledLine.
  Only those last three native displayed requirement/error kinds are retained
  as item requirements; item level is not treated as a purchase requirement.

Source inspection establishes contracts, not runtime accessibility. The -1
stock sentinel and actual native unit-title line layout remain explicit live
smoke assertions below; mock inputs do not verify values returned by the
running Forever build. Client-hidden or unsupported fields stay unknown.

## Directory, state and map

Search uses the repository's `string.lower` plain substring convention and
matches names, actual sublabels, roles, specialities, zones/subzones, known or
reported goods/recipe names, observed lessons and personal notes. Item/lesson
matches show their reason in the row; selecting one switches to its details and
moves the matching offering first. Reported matches are labelled. Multiple
selected roles are OR; zone, knowledge, favourite, recipe and query groups are
AND. Location menus contain only recorded zones/subzones. Name and last personal
encounter sorting are available; reported-only contacts have no invented
personal encounter date. Empty knowledge and no-search-match states differ.

Six rows are reused. Search indices are cached per contact and invalidated for
the changed contact. The visible UI coalesces updates at 100 ms; it is never
opened or focused by tracking. Background changes preserve the current list
anchor. Notes/reports/identity panels occupy the left column; inventories scroll
in toggleable tall left reading panels, with yellow selected borders matching
the Bestiary filters. The bottom panel remains dedicated to notes. Draft notes
survive section switching; saved notes and directory/detail/filter state survive
reload. As with the existing renderer, pan/zoom persists in its instance during
section switching and resets across a full reload or changed map.

The already exposed `CreateAtlasMap` factory is reused unchanged, with no Atlas
journal or live Atlas frame dependency. The literal AtlasBook anchor is copied
exactly: `TOP` to main content `TOPLEFT`, **632, -205**. Its renderer owns the
same **578 × 0.99 = 572.22** by **302 × 1.25 × 0.99 = 373.725** fit rectangle,
native aspect-ratio fit/cropping, border, overlays, pan/zoom and player arrow.
Each factory call owns separate tile/pin/cache state and inherits root scale
once. Ledger map clicks select stored sightings; no cross-page navigation or
state mutation is introduced. Geometry/widget assertions are not a claim of
native rendering at every scale.

The latest personal sighting is selected by default; otherwise the latest
reported one is labelled Reported. The location menu and pins select any stored
sighting. Coordinates are hundredths of a percent (0..10000) together with their
map ID, subzone and source. A zone-only observation shows its own map without a
pin; unknown artwork retains the other contact details. Tooltips include NPC
name/sublabel, zone, coordinates/precision, observer, observation time, reported
status and receipt time. These are remembered sightings, never NPC promises.

## Reports and deferred framework facilities

Reports are bounded `AFB-LEDGER` schema 1 contact envelopes with exact installed
TOC version compatibility and `AFBL1:` literal length-prefix encoding. This
follows the existing Atlas/Almanac section report boundary and Bestiary's
literal, allowlisted validation/preview principles. The existing Bestiary wire
schema, inbox, costs and transaction/reward policy have no generic section or
contact adapter. No transport or global inbox is invented or modified. The
Ledger's working boundary is **Prepare → copy/paste → Preview → Accept**;
no control claims to have sent data. A future framework dispatcher can use
`Build`, `Encode`, `Decode`, `Normalize`, `Preview`, `Prepare`, `Accept` and
`Cancel`. Contact discovery rewards are explicitly deferred; no Ledger action,
import, price refresh or repeat visit touches points.

Select personal/manual facts or a specific original received report to forward.
Goods, training and locations can be selected independently for local reports;
the current item/lesson search selects offerings. A prepared report contains at
most 80 goods and 80 lessons. For larger selections, Prepare advances through
numbered parts and wraps to part 1 after the last; copy and import each part
separately. Parts from the same original source merge cumulatively up to the
journal's 500-per-kind contact limit. Forwarding a large received source uses
the same parts and retains original observations. Notes are unchecked by
default. The prepared text is bounded; preview shows original observers,
methods, observation dates, costs and stock.

Preview tickets retain detached validated data, and edited pasted text clears
consent. Acceptance can create a separately labelled contact or explicitly
attach to the captured selected one. NPC-template conflicts reject. Reports
have per-fact source, original key/method/time and separate recipient-side
receipt dates. Forwarding never changes original observation dates. Duplicate
source identities update one report; newer cumulative facts preserve prior
positive knowledge, while old/identical forwards do not refresh fact receipts.
Report-level latest receipt is separately retained. Personal goods, roles and
notes are never overwritten. Reported titles cannot become personally observed
merely because a later encounter lacked readable title data. Source names are
unverified claims, not cryptographic identity.

Input rejects unknown fields/versions, metatables, sparse/oversized lists,
invalid IDs/quantities/prices/coordinates, malformed provenance, future dates,
WoW markup/control text, excessive nesting, duplicate/trailing codec fields
and oversized payloads. Imported strings are never evaluated or rendered as
active links. Item links for personal data are canonical ID references.

## Migration and bounds

`AzerothFieldbookLedgerDB` is per character and schema 1. Initialization adds
missing owned stores; it does not touch existing SavedVariables. Unknown future
schemas use an empty read-only working view without changing the saved table.
Other sections' reset, account progress and backup scopes do not include Ledger.
No sightings, goods or rewards are backfilled from other sections.

- 2,000 active contacts and 8,000 durable references, including redirected IDs.
- Eight GUID aliases, 24 most recent distinct sighting cells and 32 trainer
  specialities per contact. Approximate sightings in the same 0.5% map cell,
  zone and subzone reuse one row and retain first/latest time and latest point.
- 500 known personal goods and 500 lessons per contact, one latest observation
  each; no append-only stock history. Identity collisions/limits make a scan
  partial and preserve previously stored knowledge.
- 16 original report sources per contact; 512 across the character. Each wire
  part holds at most 80 goods and 80 lessons; a cumulative source can hold up
  to 500 of each after separately accepting its parts. It also retains up to
  24 locations and 32 speciality facts. Receipts are bounded to those facts.
  Each wire part is at most 128 KiB; literal parser
  depth 12, 24,000 nodes, 4,000-byte strings and 200 fields per table.
- Notes: 4,000 bytes; names/sublabels: 160 bytes; query: 200 bytes. Metadata
  callback references: at most 512, session-only. Search caches are session-only.

## Automated validation

Run `python -B -X utf8 tests/run_tests.py` from the repository root, with pinned
`lupa==2.8`. This workstation uses the bundled Python executable because its
`python` command is unavailable and the `py` launcher points to an unavailable
Windows Store installation; the full runner and dependency are unchanged.

Recorded results on 2026-09-28: **48 test files passed**, including **38 focused
Ledger tests**; **60 Lua 5.1 files**, TOC manifest, binding XML and **0.14.0**
version consistency passed. `git diff --check` passed. The protected Bestiary,
gathering, Atlas and Almanac Lua files have no changes. These are automated
results, not in-game observations.

`test_ledger.py` covers discovery/title/roles without undiscovered stock, visible
goods without purchase, distinct vendor prices/stock/times, GUID movement and
ambiguity, delayed metadata/target/close/reopen races, zero/finite/sold-out/
unrestricted/unknown values, bundle and extended costs, failed/partial/filtered
scans, historical absence, bounded refreshes/sightings, distant targeting,
Forever trainer contracts and pet costs, secret/error reads, reverse searches,
filter combinations, sorting/reset, identity linking, stable references, schema
reloads, map pins/geometry/scale/isolation, notes and section lifetimes, report
roundtrip/malicious payloads/privacy/forwarding/provenance/receipt dates/capacity,
explicit preview controls and widget reuse. The existing tab regression now
loads Ledger and still checks all seven tabs and auxiliary/window behaviour.

## In-game smoke checklist — pending

1. **Layout and other pages:** Record the exact Forever build. Open an empty
   Ledger: no seeded contacts/goods; original wishlist in Help; seven existing
   tabs. Compare Atlas → Almanac → Ledger at 50/75/100/125/150% requested scale
   and 1920×1080, 1280×720, 1024×768 window sizes (or equivalent available
   resolutions). Native map top, fitted art, border and lower edge must align.
   Long names/sublabels, scrolling directory rows, buttons and tooltips must fit.
   Check circular 2D portraits, fixed favourite checkbox alignment, flat hover
   fills, goods/training overlay toggles and contact removal/re-discovery.
2. **Native sublabel and discovery:** Open a merchant/repairer with a displayed
   title such as Bowyer in the current locale. Verify its actual sublabel in
   both list and header, combined service roles and approximate location. Target
   ordinary NPCs: no entries. Target a known contact from far away: zone-only
   sighting unless a legitimate NPC position is readable, never a fabricated
   player-location marker. Verify the NPC-position label if the client exposes it.
3. **Stock contract:** Open shops containing finite stock, sold-out items and
   normal unrestricted items. Compare native `numAvailable` with displayed
   quantities, including the expected -1 unrestricted sentinel; capture any
   differing value before accepting this contract for the running build.
   Verify free/zero quotes if available, bundle counts versus max stack, recipe
   subtype and additional currency/item costs. Merely opening records goods.
4. **Refresh/races:** Buy one available item and verify the next readable update;
   change target while the shop is open; quickly close/reopen another shop;
   exercise uncached items. Stock/price must stay with the original contact.
   Buyback must add no offerings. Filtered/empty/unloaded scans must retain
   history. A later complete scan may say Not seen, never No longer sold.
5. **Trainers and other services:** Target/mouse over each class trainer, including
   another class, and open dialogue without opening training. Confirm a Trainer
   contact with its actual title and no invented lessons or inspection date.
   Distant sightings must not use player coordinates. Then open training and
   confirm the same contact gains observed lessons. Inspect ordinary and pet/profession trainers
   where available; verify native rank, required level, category, costs and
   requirements. Change trainer filters without curriculum completeness claims.
   In Observed Training, check the top sort arrow's Level and Name choices,
   ordering across ranks and unknown levels, remembered selection after reload,
   40-pixel icons, availability colours, pet cost units and long heading hover
   scrolling at each text size. Toggle Known Goods and Training to check reused
   rows and icons; report-only lessons must keep their source labels.
   Check banker, stable, auctioneer, taxi and inn bind-confirmation events.
   Learn a new flight path: its Transport contact and discovery announcement
   should appear immediately, before opening the flight map. Opening the map
   afterward must not repeat the announcement; already learned paths must still
   discover their contact when the map opens.
   Unsupported identities/events must remain manual/unknown, without errors.
6. **Identity and search:** Compare same-name or same-template NPCs with different
   stock. Revisit and follow a moving NPC. Review ambiguous respawns with Link
   identity; inspect both records before confirming. Search by sublabel, item,
   recipe, lesson, zone and note; combine multiple roles with other filters;
   verify match explanation/focus, favourites, sorting, counts and reset.
   Search `repair`, tick Current Zone and cross a zone boundary; verify the list
   follows the new zone. Check fixed-zone choices and Clear disable the checkbox.
   Confirm Link identity sits below Search and above the contact list.
7. **Maps:** Test valid points, multiple sightings/maps/floors, zone-only entries,
   unavailable artwork and reported-only markers. Tooltip source, approximate
   label and observation/receipt times must agree with the selected sighting.
   Pan/zoom Ledger, switch to Atlas/Almanac and back: other map state is unchanged.
   Scrolling a long inventory or editing long notes must not move the map.
   With no selected contact or no recorded map, verify the current local map is
   darkened behind the empty-state message, with the same fitted dimensions,
   border and position as Atlas, Almanac and Treasure. Select a mapped contact
   again and verify the shading and empty-state message disappear.
8. **Reports:** Prepare without notes; explicitly opt in; copy/paste on another
   same-version installation; preview and accept; try a version mismatch and
   malformed text. Forward an old report and verify original ages. Encounter
   and explicitly link a reported NPC: only observed roles/location/goods gain
   personal status. Private notes, personal prices and points remain unchanged.
9. **Persistence and auxiliary windows:** Switch sections with search, selection,
   filters, list/detail scroll and draft notes. Continue capture with another
   page open. Reload after saving notes and verify per-character knowledge/state.
   Test Help, shared Options, Escape, pinned Bestiary notes, window raising,
   dragging/clamping and display-size changes. Confirm other sections' tracking,
   saved data and unfinished fields are preserved.

Do not report these live checks as passed based on synthetic widget assertions.

The existing mouseover binding now opens a matching Ledger contact before trying
the Bestiary. Exact GUID aliases take priority; a unique matching template/name
may be browsed without binding a new GUID or changing saved observations.
Filters are cleared and the selected contact is scrolled into view.

### O6 import preflight (pending native acceptance)

Pasted-report previews identify a new contact, a new report source on an existing
contact, an update to existing reported evidence, or already-known evidence with
only delivery details changing. Evidence comparison ignores forwarding and receipt
times, uses the real MergeStored result and retains the original sender/observer
preview. Capacity, identity and read-only errors use the acceptance path. A dry-run
capacity check allocates no contacts or references; merge works on copies.
Changing Attach to selected contact invalidates the preview. Accept revalidates
against current data; intervening captures can change the outcome.

- [ ] In the later combined O3/O4/O8 native acceptance batch, review new/repeated,
  updated and explicitly attached reports, plus conflicts and blocked imports.
  Check the summary and original observer/quote details remain readable and
  scrollable with large offering lists and supported text sizes. Toggle Attach
  after preview and verify a fresh preview is required before Accept.
