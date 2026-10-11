# Beast Lore in-game checks

## Current verification — 2026-10-11

The author confirmed live Beast Lore capture and persistence between sessions
in the Forever beta. The supplied native-tooltip and Known Beast Lore screenshots
show matching information for a level-5 Mangy Wolf: Tameable, Specialization:
Default, and Diet: Meat. The Fieldbook view also shows the observed level and
Locked / Verified / Observed in game provenance. Cross-session persistence is
confirmed by the author's report, not inferred from the screenshots.

The author suspects the beta client omits additional expected Beast Lore fields.
The supplied evidence shows Fieldbook retaining the information the client
exposes; it does not establish the cause of the missing native fields. Treat
this as a suspected client limitation, not a demonstrated addon capture failure.
Unavailable native information remains unknown.

**Two-player Beast Lore delivery remains unverified in the live client.** This
includes offer/receipt, recipient attribution, zero-cost accounting, conflict
precedence and interrupted-transfer recovery. Normal Bestiary sharing results
and automated protocol tests do not establish live Beast Lore delivery.

The former level-cap block on capture testing is historical. Capture and
cross-session persistence are confirmed; the remaining checklist is not a claim
that every edge case has passed. The 1.0 milestone remains an explicit author
decision and is not automatically triggered by this verification update.

## Regression and remaining acceptance checklist

Retain the confirmed capture/persistence results above when reviewing these
scenarios. Target-switch races, failed casts, delayed fields, backup/restore and
broader layout checks have no new live confirmation in this report. Automated
Lua tests cover event routing and public-tooltip mocks, not native delivery or
every visual state. Use two players on the same addon version for delivery checks.

1. On a hunter, select a beast and open Known Beast Lore. Check both headings are
   yellow, the empty text fits the dark inset box, and the full-name field and
   Send Beast Lore button fit below it without changing the main book layout.
   The lore view replaces Recorded abilities below the divider without an outer
   window or close button. Toggle Known Beast Lore off to restore the abilities.
2. Cast Beast Lore on the target. Compare every field exposed in the native tooltip
   with the saved box (both columns, including resistances, diet and abilities
   where the client supplies them). Do not infer fields absent from the tooltip.
   Wait five seconds for delayed fields. Check the observed level and source.
   Repeat on an untameable beast and with a mouseover cast.
3. Change targets immediately after casting, including to another instance of
   the same species. Confirm no data from the replacement is assigned to the
   original creature. An interrupted/failed cast must not create lore.
4. Lock the main entry and repeat the cast. Lore remains readable and can update
   from the client, but offers no manual editor or unlock control. Recast with
   already-revealed tooltip data and check no fields disappear.
5. Cross-session persistence is confirmed; retain reload/reopen as a regression
   check. Separately export/restore a backup and check the recorded fields,
   observation level and source survive too; this path remains unverified live.
6. Enter the other player's full name and surname. Send from a zero-Knowledge
   account. Confirm the offer preview shows all lore, Locked and verified, and
   zero cost. Decline once (nothing imported), then accept another offer.
7. On receipt, check a beast page can be opened, the lore is read-only and names
   the sender, and there are no corresponding unverified rumours. Neither
   player's Knowledge balance should change. Personal lore must win conflicts.
8. Check cancellation, blocked offers, mismatched addon versions and offline
   recipients retain normal behavior. If an acknowledgement is lost, use Share
   to retry the same transaction; no duplicate import or charge should occur.
9. Resize using the UI-scale option, change parchment brightness, drag the lore
   window, close/reopen it and use Escape. Verify scrolling with a long report
   and switch between beasts and non-beasts to check visibility/layout restoration.

The page overlay omits the repeated creature name. Its provenance row moves up
24 pixels and the lore viewport grows from 170 to 194 pixels, keeping sharing
controls fixed. Confirm the name above the overlay still identifies the creature.
