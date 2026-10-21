# AutoLazy

Dungeon loot automation, Shift-click quest turn-ins and a minimap button tray. Its options layout is the
model for the shared ForgeUI kit. Regression tests: `regressions/AutoLazy` in
VanillaForge (7 tests).

| File | Job |
| --- | --- |
| `AutoLazy.lua` | ClassicAPI check, settings, loot and quest automation, slash commands |
| `AutoLazy_Style.lua` | Shared surfaces and palette |
| `AutoLazy_MinimapTray.lua` | Collects other addons' minimap buttons into one tray |
| `AutoLazy_GUI.lua` | Options window |

Things to know:

- Files use CRLF line endings.
- The tray finds buttons by walking every global frame. The walk only collects
  candidates; the checks run 3 ms per frame (`Drain`), because doing them in one
  go froze the client for about 0.25 s. Keep that split.
- The repo uses sparse checkout: `tests/` and `.dev/` exist in git but not in
  the game folder.
