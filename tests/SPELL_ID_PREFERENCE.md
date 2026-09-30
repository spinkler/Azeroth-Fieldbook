# Spell-ID tooltip preference

`showSpellIDs` is the existing per-character Fieldbook preference; absent or
invalid values default on. An explicit boolean survives initialization even if
the obsolete `spellIDTooltipInitialized` marker is absent or stale. The marker
is discarded. The Options checkbox displays saved intent rather than external
changes to the CVar.

Startup, an explicit option change and a settings reset apply the saved choice
to WoW's client-wide `tooltipShowAuraSpellIDs`. A successful `GetCVarBool` match
avoids `SetCVar`; unavailable/failing APIs leave saved intent intact. There is no
event/frame enforcement or restoration of a pre-Fieldbook value. Reload applies
the choice again. Bestiary journal-only reset preserves it; the documented
Bestiary settings reset and double-confirmed slash wipe restore the on default.

`test_spell_id_preference.py` exercises real main initialization, default-on,
legacy opt-out, re-enable, external drift, redundant-write suppression, API failure
and both reset paths. `test_journal.py` retains ability-tooltip rendering coverage.

Native acceptance remains necessary: on Forever, check spell/aura tooltip IDs
after a default load, toggle off and reload, toggle on, change the client CVar
externally during play and confirm it stays untouched until reload. Check the
Options hover text and both reset scopes. Mocked CVar APIs do not establish
which native tooltip surfaces expose IDs or whether the client accepts a write.
