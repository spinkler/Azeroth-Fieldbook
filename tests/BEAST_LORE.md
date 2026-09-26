# Beast Lore in-game checks

Status on 2026-09-27: pending the WoW Forever beta level-cap increase. The
operator is reserving stable 1.0 until this feature is tested, independently
of progress on other Fieldbook sections. The general SavedVariables blocker
has been resolved; Beast Lore itself still needs its own persistence check.

Automated Lua tests cover event routing and public tooltip mocks, not live spell
delivery or visual correctness. Use two players on the same addon version.

1. On a hunter, select a beast and open Known Beast Lore. Check both headings are
   yellow, the empty text fits the dark inset box, and the full-name field and
   Send Beast Lore button fit below it without changing the main book layout.
2. Cast Beast Lore on the target. Compare every field in the native tooltip with
   the saved box (both columns, including resistances, diet and any abilities).
   Wait five seconds for delayed fields. Check the observed level and source.
   Repeat on an untameable beast and with a mouseover cast.
3. Change targets immediately after casting, including to another instance of
   the same species. Confirm no data from the replacement is assigned to the
   original creature. An interrupted/failed cast must not create lore.
4. Lock the main entry and repeat the cast. Lore remains readable and can update
   from the client, but offers no manual editor or unlock control. Recast with
   already-revealed tooltip data and check no fields disappear.
5. Reload and reopen the page. Check lore survives. Export/restore a backup and
   check the recorded fields, observation level and source survive too.
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
