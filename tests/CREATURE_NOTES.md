# ID Logs and Notes live checks

1. Reload, select a Bestiary creature, and click **Creature Notes**. Verify the
   button shares the creature-name line and the page's right content edge.
   The small movable window should match the book's parchment theme.
2. Type `6268` and press Enter. A spell link should appear below the input.
   Hover it; toggle **Show aura spell IDs on tooltips** in the ? menu and check
   that the notes link's tooltip shows/hides the appended ID accordingly.
   Click a link to open its spell tooltip; Shift-click inserts it into chat input.
3. Record ten distinct IDs. An eleventh and a duplicate should be refused.
   Remove a middle row using its red x; the remaining rows should close the gap.
4. Type in the visible bordered **Notes** textbox (400 characters maximum).
   Check its character counter, then switch creatures in the Bestiary.
   Each creature must keep its own list and notes. Switch back and verify both.
   Collapse notes, close the window, and reload; the recorded data must persist.
5. `/fieldbook notes` opens the selected creature's notes even when the book is
   hidden. With no selection it uses an eligible current target; otherwise it
   opens the book and prompts for a creature. It must never save a shared log.
6. In combat, manually type a known ID. Saving is independent of aura access.
   If the client cannot supply a public spell name, the row uses `Spell <ID>`
   as its link label. This does not automatically confirm a Bestiary ability.
7. Reset the Bestiary: notes must clear with their creature entries, including
   any currently open notes window. Verify long notes scroll and the ten-row
   expanded window fits on screen.
8. Lock a creature. Ability editors, review controls, Offenses, Defenses,
   Behaviour, Choose effects and damage recording must be disabled and dimmed.
   Open editors must close. Automatic observations, metadata and kills must not
   change its saved entry. Unlocking restores editing. ID Logs and Notes remain
   editable in both states.

Automated tests cover persistence, isolation, limits, invalid/secret inputs,
row removal, switching, tooltip options and reset. In-game rendering and native
spell-tooltip behaviour still require these live checks.
