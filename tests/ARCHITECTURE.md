# Fieldbook section integration

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

Only the Bestiary is registered in this release. No speculative section or
placeholder navigation button is shipped. A later section chooser should call
these navigation methods; it should not create a second root window.

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
