# Basic information colours and entry keys — 0.10.5

Implementation was checked against local Blizzard Forever 1.60.1.69977 UI source:

- `Blizzard_FrameXMLUtil/Mainline/DifficultyUtil.lua`: the native creature colour
  uses effective player level and the client's trivial-level range, including an
  orange band. The addon delegates to the function instead of duplicating thresholds.
- `Blizzard_GameTooltip/Mainline/GameTooltip.lua` and
  `Blizzard_SharedXML/SharedColorConstants.lua`: tooltip reaction colours come from
  `FACTION_BAR_COLORS`. Hostile uses the red slot (2), Neutral the yellow slot (4).
- `Blizzard_Minimap/Mainline/Minimap.lua`: friendly `(0.1,1,0.1)`, hostile/arena
  `(1,0.1,0.1)`, contested `(1,0.7,0)`, sanctuary `(0.41,0.8,0.94)`, otherwise
  `NORMAL_FONT_COLOR`. These are territory colours, independent of creature reaction.
- `Blizzard_APIDocumentationGenerated/PvpInfoDocumentation.lua`: `GetZonePVPInfo`
  has no zone argument; it reports the current territory and a subzone flag.
  Therefore older zone names cannot safely be assigned a territory remotely.

Each Level Range endpoint gets its own native colour. The existing visible-book
refresh detects changes to player effective level within 0.5 seconds, independent
of journal changes. Unknown levels retain the existing skull. Unavailable or
restricted colour data leaves the level readable in the normal font colour.

Territory observations use `C_PvP.GetZonePVPInfo`, or the older global when needed,
on world/zone events and normal observations. Valid current-zone results are
stored in `bestiary.zoneTerritories[zone][faction]`, capped at 1024 zones. Subzone
overrides, unreadable results and unknown factions are skipped. This cache creates
no creatures, Knowledge, chat notices or Event log records. It is included in
backups and local account merging, but never in shared reports. Original location
names stay unchanged for filters, sorting and sharing. Existing zones acquire
colours as they are revisited for the current faction.

Next / Previous keybindings reuse the existing `cycleEntry` path and wrap at list
ends. They never create/open a window, change section or act while a text field
has keyboard focus. Both are unassigned until configured by the player.
All bindings appear under Azeroth Fieldbook. Toggle Azeroth Fieldbook uses the
shared shell, preserving the last selected tab; Open Azeroth Fieldbook at mouseover now prefers remembered Ledger contacts and otherwise
selects the Bestiary explicitly. Existing action IDs and assigned keys are retained.

The operator's 0.10.5 screenshot showed the legacy XML `header` becoming a bindable
`HEADER_AZEROTHFIELDBOOK` action under Other. Forever's
`Blizzard_SettingsDefinitions_Frame/Keybindings.lua` groups by the category from
`GetBinding`, resolves its name through `_G`, and treats uncategorized rows as
ordinary actions. In 0.10.6 all four bindings instead specify
`category="BINDING_HEADER_AZEROTHFIELDBOOK"`, with no legacy `header` attribute.
The XML regression checks all four categories, absence of synthetic headers,
display labels and unchanged action routing. Native menu acceptance awaits reload.

Automated coverage is in `test_level_difficulty.py`, `test_disposition.py`,
`test_zone_colours.py` and `test_fieldbook_tabs.py`. The complete repository runner
also checks existing navigation, locations, backups, sharing and journal behaviour.
Widget mocks cannot establish native font rendering or actual keyboard dispatch.

Pending in-game checks after `/reload`:

1. Compare single levels and mixed ranges against Blizzard creature difficulty
   colours, including orange. Level up with a locked page open and confirm its
   displayed range stays unchanged while its colours update. Check unknown skulls.
2. Compare Hostile / Neutral with tooltip reaction colours. Check readable wrapping
   at supported UI scales with a long name and multiple locations.
3. Visit friendly, contested and hostile territories and compare recorded zone
   labels with minimap colours. Check remembered zones after leaving and reloading;
   a sanctuary/arena subzone must not overwrite its parent zone's status.
4. Assign both entry bindings in WoW's keybinding options. Check Next/Previous with
   filters, descending sorts, a list longer than one page, empty results and wrapping.
   Close the book, select a future section or focus search/notes: no navigation.
5. Confirm the Azeroth Fieldbook heading and exact toggle/mouseover labels. Select
   a wishlist tab and toggle closed/open: that tab must remain active. Mouseover
   opening should instead select the Bestiary and the pointed creature.
