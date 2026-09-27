# Section navigation — 0.10.0

## Automated validation

On 2026-09-27, `tests/run_tests.py` passed all 34 test files and compiled all 33
runtime Lua files with Lua 5.1. Manifest completeness, binding XML and matching
TOC/README/changelog versions also passed. The pinned dependency is `lupa==2.8`.
The local run used the bundled Python 3.12 executable because `python` is not on
this machine's PATH; the runner and arguments were unchanged:

```text
python -B -X utf8 tests/run_tests.py
```

`test_fieldbook_tabs.py` runs the real shell, Bestiary and wishlist builders in
the widget host. It verifies the seven-section order, default selection, native
template selection, single active highlight, tooltip text/ownership/dismissal,
mouse-release routing, no-op active clicks, lazy content reuse, exact wishlist
copy and wrapping bounds. It also checks Bestiary creature/category/search/list
and ability browsing state, unfinished fields, observation while hidden, explicit
mouseover entry opening, Help/observation/Notes/Rumours/backup closure, reset-popup
dismissal and the existing pinned Notes lifetime.

Scale coverage includes 50%, 75%, 100%, 125% and 150% at 1920×1080, 1280×720 and
1024×768 UIParent dimensions. It verifies screen-fit bounds including every tab,
unchanged clamp insets and one inherited scale. `test_window_positions.py` checks
the extra width during registration, restore and scaling; right-side placement
with different main/dialog scales and with automatic anchoring disabled; crowded
screens that must overlap content; and reflow after dragging, including windows
without a placement-preference flag. Existing tracking, sharing, backups, notes,
locations and Bestiary regressions remain in the full runner.

These are behavior and geometry checks, not screenshots or native font/texture
rendering tests. The mock models the native tab callback contract.

## Verified client assets

All icons below were opened by their full `Interface\Icons\<name>.blp` path in
the installed **Forever 1.60.1.70009** `wow_classic_beta` storage, read completely
and decoded with Pillow. Each is a **64×64 BLP2** image and was visually inspected.
The installed build key is `05215079e3905ef5922ae0b03ffefb73`. The verification used
a locally built [CascLib reader](https://github.com/ladislav-zezula/CascLib/tree/38a34665624b8775bb875274b36191b21c38d97b)
without modifying the game archives. Extracted icons and build tools stay outside
the addon repository and package; the addon uses Blizzard's installed assets.

| Section | Blizzard icon | Visual |
| --- | --- | --- |
| Bestiary | `Ability_Tracking` | Track Beasts paw prints |
| Herbs & Minerals | `INV_Misc_Flower_02` | Find Herbs flowers |
| Traveller’s Atlas | `INV_Misc_Map_01` | Parchment map |
| Angler’s Almanac | `Trade_Fishing` | Fishing hook |
| Merchant’s Ledger | `INV_Misc_Coin_01` | Gold coins |
| Treasure & Salvage | `INV_Misc_TreasureChest01a` | Wooden treasure chest |
| Lore & Landmarks | `INV_Misc_Book_09` | Old bound book |

The initial chest name without the final `a` did not resolve and was replaced
before delivery. The six future-page definitions live in `FieldbookSections.lua`;
the Bestiary title/icon remain in its `RegisterSection` definition.

The native `LargeSideTabButtonTemplate` and its Camelot behavior were checked
against the repository's pinned
[Forever 1.60.1 UI source](https://github.com/Gethe/wow-ui-source/tree/c6e89983189e4f626f549204a23c2d2bea93080a).
It supplies `common-sidetab`, `common-sidetab-mask`, `common-sidetab-hover` and
`common-sidetab-selected`, native icon cropping, press feedback and tooltips.
Fieldbook uses this template directly and follows its two-pixel vertical spacing.
Asset decoding confirms icon availability; it does not claim that the complete
tab column has been rendered in game.

## Pending in-game acceptance

1. Reload and open `/fieldbook`. Confirm the unchanged Bestiary layout and all
   seven framed icons attached outside the right edge, in the specified order.
   Bestiary is initially gold; hover each tab for its exact section name and
   native feedback. Check clicks and release-outside behavior, including combat.
2. Open every future section. Confirm its exact title, gold wishlist heading and
   complete paragraph with readable wrapping and comfortable margins. Check
   background brightness at its supported extremes. The shared frame, close
   control and all tabs must remain available; Bestiary toolbar controls disappear.
3. Select a creature, apply category/search/location/rank/letter filters and
   scroll the creature and ability lists. Enter an unfinished manual field.
   Change the target while on another tab, then return: selection, filters,
   browsing and the draft should remain. Use the mouseover creature binding
   from a placeholder and confirm that it selects the Bestiary and that creature.
4. Open Notes, Locations, Rumours, Share, damage/trait/effect panels, Help,
   Options, Event log and backups. Switch sections and confirm section-owned
   panels close. Pinned Notes and the independent spell-ID utility keep their
   existing lifetime. Accepted sharing and background discovery/kill/ability
   tracking must continue while a placeholder is selected.
5. Repeat at 50%, 100% and 150% addon scale and the user's normal WoW UI scale,
   including a small window/resolution. Drag the main frame to every screen edge,
   with auxiliary windows open, then reopen saved windows. Verify the full tab
   column remains visible and clickable; right-side windows clear it. Test with
   automatic anchoring enabled and disabled and with pinned utility windows.
   On a crowded screen, any unavoidable overlap should spare the tab column.
6. Close/reopen through Escape, close button, minimap and `/fieldbook`; general
   opening resumes the last section. Test the normal Bestiary and mouseover
   bindings. Reload to confirm the default is Bestiary, saved frame positions
   still work and existing creature data/settings remain intact.

No in-game pass is claimed for these new visuals. No future-section tracking or
storage is implemented, and no SavedVariables or sharing schema was changed.
