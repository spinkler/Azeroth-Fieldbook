# Lore & Landmarks — 0.16.0

Lore remembers what you found out and what you still do not understand. Atlas
continues to own its existing geography. No lore database, canonical answers,
quest walkthrough, automatic relationship inference or rewards are added.

## Implemented interaction

Open a supported readable, wait for its text, leave the source, then select the
writing in Lore & Landmarks. The Entry reader displays saved pages, gaps,
capture labels, passages, personal notes and received reports. It works without
the source and saves each work's reading position. The Location switch uses a
separate `CreateAtlasMap` instance at the exact Atlas anchor `(632, -205)`.

The existing shared Options page contains two character settings in
`AzerothFieldbookDB`, initialized only when missing:

| Option | Default | Behaviour |
| --- | --- | --- |
| Automatically archive readable lore | ON | Quiet capture during supported interactions, independently of which section is open. OFF prevents new automatic capture and cancels traversal. Stored sources, editing and explicit capture/transcription remain available. |
| Only archive pages I open | ON | Restricts automatic capture to pages presented by normal reader navigation. No automatic page requests. OFF enables bounded whole-book navigation where capabilities permit; turning it back ON cancels further navigation. |

Whole-book capture can turn the original reader's pages. Keep the interaction
open until it completes. A discreet reader footer shows progress; the Lore page
shows actionable capture status. Player navigation or scroll input wins. Source
closure, changed context, restrictions, translation delays, timeout or capacity
limits preserve already captured text and leave an honest partial/interrupted
status. No background operation reopens the interaction or switches the Fieldbook.

Capture / retry explicitly saves the current ready text, including ambiguous
correspondence the automatic path excludes. With automatic capture OFF it saves
only that displayed page. With automatic capture ON and the restriction OFF it
may retry whole-book capture for an eligible source. Manual transcription remains
available even when item-text APIs are absent. Manual source passages are labelled
as transcribed; observations and interpretations remain distinct.

Captured pages are not marked “read.” Page labels distinguish normal display
from automatic retrieval; no dwell-time inference is made. A source's claim
does not become established truth because it was preserved.

## Client capability investigation and boundaries

The installed addon workspace does not contain an extracted Forever item-text
implementation. Reference-only investigation used the Classic client UI's
[ItemTextFrame.lua](https://raw.githubusercontent.com/Gethe/wow-ui-source/classic/Interface/AddOns/Blizzard_UIPanels_Game/Classic/ItemTextFrame.lua)
and generated
[ItemTextDocumentation.lua](https://raw.githubusercontent.com/Gethe/wow-ui-source/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemTextDocumentation.lua).
These establish the reference design, **not Forever compatibility**.

The production adapter feature-tests public globals and guards calls/results:

- `ITEM_TEXT_BEGIN`, `ITEM_TEXT_READY`, `ITEM_TEXT_TRANSLATION`,
  `ITEM_TEXT_CLOSED`, and world-leaving invalidation.
- `ItemTextGetItem`, `ItemTextGetText`, `ItemTextGetPage`,
  `ItemTextGetMaterial`, `ItemTextGetCreator`, `ItemTextHasNextPage`.
- Whole-book mode additionally needs `ItemTextPrevPage`, `ItemTextNextPage`,
  `hooksecurefunc` and `C_Timer.After`. Secure post-hooks observe takeover;
  existing handlers are never replaced. No hidden-page fetch API was established.

After READY, two consistent snapshots stabilize text and terminal evidence.
Traversal first moves backward to page 1, then forward one ready page at a
time. A known beginning, stable terminal indication, and every required captured
page establish completeness. The native adapter accepts successful Classic
truthy/nil next-page results as well as booleans; an unavailable or failed
accessor remains unknown. Classic's page zero is normalized only for a terminal
single-page source; unsupported pagination remains partial. Earlier missing
pages are not inferred from a page count. The original page and scroll are
restored only for the same active interaction and absent player takeover.

Stabilization is delayed by 0.05 then 0.12 seconds; normal navigation waits at
least 0.15 seconds. Each requested page has a six-second timeout, extended for
an announced translation up to 30 seconds. At most 768 navigation requests and
180 seconds are allowed per traversal. There is one active traversal and no
per-frame lore scan. Delayed callbacks carry their session/generation identity.

Automatic capture requires a successfully readable creator accessor returning
no player creator. A nonempty creator, unavailable creator capability, active
mail session or visible mail reader excludes automatic capture. This conservative
rule may exclude some world sources until Forever's behaviour is tested. It is
not based on guessing titles. Explicit capture/transcription remains available.

The native adapter has no established stable work/object/item identifier. It
does not pretend the observed title is one. Rereads match exact numbered source
text plus title, locale, kind and any available identity. Disjoint partial reads
remain separate. Extending a reused partial work requires its existing pages to
have been seen in the active session; conflicts fork only that session's evidence.
Reliable optional source identities are supported by the model, with overlapping
content checks and conservative variants. Conflicts never overwrite preserved
pages or combine unobserved pieces into a fictional book. Repeated events in one
session are idempotent. Read-here is always the interaction location, including
for a carried item; found-here is never inferred from opening it.

Version 0.16.3 keeps same-source adjacent page BEGIN events in one session and
handles READY delivered before a post-call navigation hook. Starting in 0.17.0,
exact saved page-set duplicates remain separate on capture and reload. A detached
candidate checks collection and byte limits, but retiring distinct IDs would also
change existing export identities without durable aliases. That destructive step
is deferred. Original annotations, locations, reports, links, read flags, selection
and reading positions stay with their original IDs. A skipped-consolidation notice
is independent of successful page capture; it does not turn a complete archive
into a failed capture. Ordinary exact rereads still reuse the same record. Delete an entry using
**Sources / manage → Delete entry…**, then confirm. Deletion sets no blacklist;
opening the source again can archive it normally. Reopen pages missing from old
captures: text never received cannot be reconstructed. Live verification remains
required: reread The Guardians of Tirisfal, open every page, reopen it, reload,
delete it, then capture it again and confirm one ordered archive remains.

## People, landmarks and investigations

Record current Person uses the actual supported NPC interaction, or a supported
creature target outside an interaction. A target-only position is an observation
position, not proof the NPC is standing there. Save Passage is deliberate:
`GOSSIP_SHOW` / gossip updates use `C_GossipInfo.GetText` or `GetGossipText`;
`QUEST_DETAIL`, `QUEST_PROGRESS`, and `QUEST_COMPLETE` use the corresponding
displayed quest text functions. Capture validates the actual `npc` context,
never an unrelated target. Missing identity is labelled Unidentified speaker.
Closing the dialogue invalidates the snapshot. No branches or quest actions are
selected. Vendor services and combat evidence stay in their original journals.

Record Landmark offers current position as an observation starting point. The
location editor can distinguish observation, landmark, reading, encounter,
deliberately established finding, reported and merely mentioned places.
Landmark map placement is deliberate and reviewed before saving. Text-only
places do not create markers or Atlas discoveries.
When no map is recorded or deliberately selected, Location shows a darkened
copy of the player's current map with the shared Atlas dimensions, anchor and
border. This fallback saves no location. Verify this empty state in the client
alongside recorded locations and deliberate map selection.

Mysteries hold a question, description, theory, private notes, next step and
Open / Investigating / Resolved by me status. They can reopen. Related searches
known records through narrow read-only adapters. References keep their labels
when the source disappears; removing a link or mystery never removes evidence.
Bestiary, Atlas, Almanac, Ledger and Treasure use supported open/select paths;
Gathering lacks a direct arbitrary-entry opener, so its reference shows the
known label for manual navigation rather than changing that section's API.

## Persistence, provenance and limits

`AzerothFieldbookLoreDB` schema 1 is per character and independent of account
tracking, resets/backups and all other section data. Missing fields initialize
additively. Unsupported saves use a detached read-only view; malformed entries
remain in the saved store and are omitted with a notice. Lore option values
survive Bestiary reset. No migrations repurpose another journal.

Raw source text is immutable evidence. A display/search projection strips
unsupported HTML, images, action hyperlinks and colour commands, retaining
paragraphs, punctuation and Unicode. No content is evaluated, and the reader
does not invoke link actions. The original received text remains stored.
Personal annotations and received report snapshots are separate. Origin
(captured, manual, received) and nature (source, observation, account,
interpretation) are independent. Reported automatic-capture claims are not
treated as verified local capture.

Limits refuse additional material with explicit errors; old books are not
pruned: 2,000 entries, 256 pages and 256 passages per work, 128 KiB per source
page/passage, 4 MiB per entry, 32 MiB archive content, 100 local locations,
100 relationships, 32 tags and 32 received snapshots per entry. No source
is silently shortened to fit. Search projections are cached per changed entry.

## Sharing path

Reports uses the existing section-report copy/paste, same-version envelope,
literal codec, preview and acceptance conventions. The current Bestiary wire
schema and points policy have no generic section dispatch; **Lore addon-message
delivery and Knowledge pricing are unavailable**. No control claims it sent a
report, and nothing is charged or awarded.

Export one entry, select local sources or a received report to forward, and
choose pages, passages, locations and optional references. Private notes,
descriptions, theory, next step, tags, personal status and private passages need
explicit inclusion. Preview shows exactly the selected text; references contain
labels, not connected records or foreign local IDs. A report never expands into
an entire linked investigation. Copy the prepared envelope and send it yourself.

Import a pasted envelope, optionally record who supplied it, Preview, then
Accept. The envelope's sender is a claim; copy/paste cannot authenticate an
actual sender. The recipient's entered sender is stored separately. Imported
pages stay in reported snapshots with source/method claims and receipt time;
they never set personally-viewed/encountered flags. Imports may attach to an
explicitly selected same-kind entry without replacing notes or local source
text. Repeated exact reports deduplicate. Historical report versions remain
readable after an addon update; new transfers require the same installed version.

Envelopes have a 1 MiB limit with bounded strings, lists, depth and node count;
unknown fields, invalid enums/coordinates/types, extra data and unsupported
versions fail before mutation. There is no code evaluation or decompression.
Oversized works require deliberately selected page batches, never truncation.
Acceptance stages a validated replacement before committing it, and no currency
transaction occurs.

## Validation record

Implementation ownership:

| Files | Purpose |
| --- | --- |
| `LoreJournal.lua` | Separate archive schema, source identity/variants, notes, queries, limits and provenance. |
| `LoreTracking.lua` | Guarded item-text lifecycle/traversal and deliberate NPC/quest passage capture. |
| `LoreSettings.lua`, `LoreIntegration.lua` | Character option defaults, background startup and read-only references to known other-section records. |
| `LoreBook.lua`, `LoreEditors.lua`, `LoreMap.lua`, `LoreReferences.lua` | Catalogue, stored reader, four-kind editing, relationships and independent Atlas-style location view. |
| `LoreReports.lua`, `LoreReportUI.lua` | Selected-source reports, exact previews, bounded literal validation and atomic import. |
| `AzerothFieldbook.lua`, `AzerothFieldbook.toc`, `FieldbookSections.lua` | Additive loading, SavedVariables, initialization and replacement of the existing Lore placeholder. |
| `BestiaryPages.lua`, `BestiaryJournal.lua` | Add the required shared Options group and preserve only the two new Lore preferences through Bestiary reset. Existing Bestiary behaviour/data are otherwise unchanged. |
| `tests/test_lore_*.py`, `tests/test_fieldbook_tabs.py` | Focused model/capture/report/widget checks plus real section order, Options and integration regressions. |
| `AGENTS.md`, `README.md`, `CHANGELOG.md`, architecture/navigation/verification notes and this guide | Version 0.16.0, current feature boundaries and honest verification status. |

The pre-existing 0.15.40 edits in `LedgerMap.lua` and `tests/LEDGER.md` were
preserved. They are not part of the Lore implementation. No commit, push, tag,
publication or release was performed.

Automated tests use Lua 5.1 through pinned lupa 2.8. `test_lore_journal.py`,
`test_lore_tracking.py`, `test_lore_reports.py`, `test_lore_ui.py`, and the extended
`test_fieldbook_tabs.py` cover model, lifecycle, privacy, reports and widget
control flow. The required command remains `python -B -X utf8 tests/run_tests.py`.
On 2026-09-28, the final required runner completed at version 0.16.0:
**56 test files, 0 failed**. The four focused Lore files contain **68 tests**
(17 model, 26 capture, 10 reports, 15 UI). The section integration file also
passed its 14 tests. All **77 Lua files** compiled under Lua 5.1; TOC contents,
bindings and release-version consistency passed. `git diff --check` passed.
The bundled Python 3.12 interpreter ran the unchanged runner/arguments because
Python was absent from PATH; the pinned lupa 2.8 dependency was installed in
the existing test-harness dependency location outside the addon repository.

Static review establishes API guarding, module loading, section isolation and
matching map geometry. **No in-game Lore behaviour has been observed in this
implementation session.** Mocked ready events, source attribution and traversal
do not prove that Forever exposes the reference semantics. Existing unrelated
operator confirmations remain recorded in VERIFICATION.md.

## Outstanding in-game acceptance

1. Open a single-page world readable with both options ON. Verify one captured
   page, original title, truthful location and saved text after leaving and
   `/reload`. Check the terminal/page-zero semantics in this client.
2. Open a multi-page book with Only archive pages I open ON. Wait without
   clicking: no other pages may turn or appear. Open subsequent pages normally;
   confirm ordered capture, no duplicates, and no claim that you read them.
3. Disable the restriction and open a multi-page book, including from its
   middle. Do not click through pages. Verify preceding and following pages,
   discreet progress, completion only with the full sequence and original-page
   restoration. If declined, record the visible partial/unavailable reason.
4. Close the reader mid-capture; open a different book during capture; reopen
   an incomplete source. Confirm retained pages, no cross-source contamination
   and conservative identity/variant behaviour.
5. Use native page buttons and scroll controls during traversal. Confirm input
   stops addon navigation and restoration. Disable capture or re-enable the
   restriction during a pending page; no later automatic requests may occur.
6. Exercise delayed/translated text and genuinely empty pages. Ensure no good
   text disappears and unknown pagination never produces a complete claim.
7. Compare a carried readable with a fixed source. Open the carried item at an
   inn: location must say Read here, not origin/found here. Test player-created
   readable correspondence and mail exclusions where the client provides them.
8. Speak to a lore NPC, target a different NPC and Save Passage. Check speaker,
   title and quotation attribution. Try the three quest-text surfaces without
   accepting/completing anything through the addon. Close dialogue and verify
   stale passage capture is refused. Try a context with missing identity.
9. Transcribe a source manually; include long text, Unicode, paragraph markup
   and links. Read, search and reload; verify raw preservation, safe display,
   wrapping, source labels and annotations remaining separate.
10. Record a landmark; deliberately place it away from the player's observation
    position. Confirm meanings and exact map alignment with Traveller's Atlas.
11. Create a mystery, link writing/person/landmark evidence and an existing
    other-section record, set a theory/next step, resolve and reopen. Delete a
    linked source and then the mystery: surviving evidence must remain intact.
12. Export selected pages with notes excluded, inspect the exact preview,
    copy/paste to another same-version character and accept. Check reported
    source versus recorded sender, no personal credit/points and unchanged
    recipient notes. Repeat for explicit private opt-in, selected batches,
    forwarding, malformed and oversized reports, cancel and duplicate import.
13. Switch sections and close/reopen while editing, searching, filtering,
    scrolling or receiving background captures. Check selection, list/page/map
    position and unsaved buffers; no Lore controls may overlay other sections.
14. Check all controls and auxiliary panels at 50%, 100%, 150% addon scale and
    the normal game UI scale/window sizes. Compare fonts, borders, button/hover
    feedback and map placement against the established pages.
15. Recheck other pages, their saved data/filters, shared Options, Bestiary
    reset, background capture while Lore is never opened, and unsupported API
    fallback. In-game visual acceptance remains separate from automated passes.

### Recording announcements (v0.16.6)

New lore entries emit one chat message and one persistent entry in the existing
character Event log. The message names the title and kind, without source text
or private annotations. Capture emits only after a new writing has its pages;
manual entries and new imported entries also notify. Failed saves, reloads,
annotation edits, duplicate rereads, extra pages and reports attached to existing
entries do not announce a new item. Lore exposes the shared Event log button,
which refreshes when open and closes on section changes. Chat is independent
of Bestiary announcement preferences; logging also works without a chat frame.

Live check: capture a readable item with Lore closed, check chat, then open Lore
and its Event log. Reopen the same item and turn pages; verify no duplicate
announcement. Save a manual landmark and confirm both messages.

Object gossip readers: native GameObject GUIDs with a displayed source name are
archived as writings on gossip events. Draconic for Dummies also supports a
missing-GUID title fallback. NPC gossip remains deliberate. Capture preserves
only displayed text. Draconic for Dummies has confirmed single-page boundaries;
other readers retain unknown boundaries. It neither translates nor
traverses dialogue options. Test in Forever by reopening the book, checking one
writing and one initial chat/event-log notice, then disabling automatic capture
and using Capture / retry current text. Native API behavior still needs live QA.
