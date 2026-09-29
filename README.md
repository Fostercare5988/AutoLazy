# AutoLazy

A dungeon loot automation, quest chaining, and interface utility add-on for World of Warcraft 1.12.1.

## Features

- **Dungeon Loot Automation**: Automatically roll Need, Greed, Pass, or Manual on common dungeon farm items (ZG Bijous/Coins, AQ20 Scarabs/Idols, Naxxramas Scraps, Black Morass Sand). Unlisted items and gear drops are never rolled automatically.
- **Bind-on-Pickup Auto-Confirmation**: Optionally confirm Bind-on-Pickup roll prompts and direct corpse-looting dialogs.
- **Repeatable Quest Chaining**: Hold Shift when speaking to an NPC to continuously turn in repeatable reputation and token quests in one fluid sequence.
- **Reward Safety**: Automatically pauses quest turn-ins if a quest offers multiple equipment rewards so you can choose manually.
- **Floating Hub & Addon Tray**: A draggable minimap button that collapses installed add-on buttons into a clean, collapsible tray.
- **Interface Bloat Suppression**: Optionally suppress custom server radio and LFG widgets without breaking underlying functionality.

## Requirements

- **World of Warcraft 1.12.1** (Build 5875)
- [ClassicAPI v1.15.15+](https://github.com/brues-code/ClassicAPI) (`ClassicAPI.dll`)
- [SuperWoW v2.2+](https://github.com/balakethelock/SuperWoW) (`SuperWoWhook.dll` / `SuperWoWlauncher.exe`)
- *Optional:* [UnitXP SP3](https://codeberg.org/konaka/UnitXP_SP3) (`UnitXP_SP3.dll`)

> Note: Completely restart the game client after installing or updating DLLs. `/reload` cannot reload DLLs.

## Installation

1. Copy or clone this repository into your WoW add-on directory:
   ```text
   World of Warcraft/Interface/AddOns/AutoLazy/
   ```
2. Verify that `AutoLazy.toc` is located directly at `Interface/AddOns/AutoLazy/AutoLazy.toc`.
3. Launch WoW using the SuperWoW launcher.
4. Ensure AutoLazy is checked on the character selection AddOn screen.

## Useful Commands & Shortcuts

| Command | Description |
| :--- | :--- |
| `/al` or `/autolazy` | Open main configuration window |
| `/al tray` | Toggle the Floating Addon Tray |
| `/al toggle` | Pause or resume automatic loot rolls |
| `/al quest` | Toggle Shift-Click Quest Automation |
| `/al bop` | Toggle auto-confirmation of BoP popups |
| `/al status` | Display auto-roll state and detected dungeon in chat |
| `/al resetpos` | Reset Floating Hub Button to top right |

| Shortcut | Context | Action |
| :--- | :--- | :--- |
| `Left-Click` Hub Button | Screen | Toggle Addon Tray |
| `Right-Click` Hub Button | Screen | Open AutoLazy configuration |
| `Left-Click Drag` Hub Button | Screen | Reposition hub icon |
| Hold `Shift` | Speaking to Quest NPC | Continuously chain repeatable quest turn-ins |

## Limitations & Notes

- **Loot Whitelist**: Auto-rolling only acts on explicitly listed farm items configured under `/al`. Gear, rare drops, and unlisted items are left for manual rolling.
- **Quest Reward Safety**: If a completed quest offers a choice of multiple rewards, AutoLazy pauses immediately to prevent accidental reward selection.

---

For detailed loot configuration and covered repeatable reputation quests, see the [User Guide](docs/USER_GUIDE.md).

## License

MIT License. Maintained by [Fostercare5988](https://github.com/Fostercare5988).
