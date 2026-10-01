# AutoLazy

A dungeon loot automation, quest chaining, and interface utility add-on for World of Warcraft 1.12.1.

## Features

- **Dungeon Loot Automation**: Automatically roll Need, Greed, Pass, or Manual on common dungeon farm items (ZG Bijous/Coins, AQ20 Scarabs/Idols, Naxxramas Scraps, Black Morass Sand). Unlisted items and gear drops are never rolled automatically.
- **Clean Group Loot Presentation**: Toggleable suppression (`/al clean` or Tab 2 checkbox, enabled by default) of noisy intermediate Need/Greed/Pass chatter and numeric dice roll spam, presenting only the final winner with a clickable item link. Direct item loot and money messages are preserved.
- **Bind-on-Pickup Auto-Confirmation**: Optionally confirm Bind-on-Pickup roll prompts and direct corpse-looting dialogs.
- **Quest Automation & Chaining**: Hold Shift when speaking to an NPC to auto-accept or turn in quests. Single quests and supported repeatable chains are automated; on multi-quest NPCs, choose your quest and AutoLazy completes the interaction.
- **Reward Safety**: Automatically pauses quest turn-ins if a quest offers multiple equipment rewards so you can choose manually.
- **Floating Hub & Addon Tray**: A draggable minimap button that collapses installed add-on buttons into a clean, collapsible tray.
- **Interface Bloat Suppression**: Optionally suppress custom server radio and LFG widgets without breaking underlying functionality.

## Requirements

- **World of Warcraft 1.12.1** (Build 5875)
- [ClassicAPI v1.15.15+](https://github.com/brues-code/ClassicAPI) (`ClassicAPI.dll`)

> Note: Completely restart the game client after installing or updating DLLs. `/reload` cannot reload DLLs.

## Installation

1. Copy or clone this repository into your WoW add-on directory:
   ```text
   World of Warcraft/Interface/AddOns/AutoLazy/
   ```
2. Verify that `AutoLazy.toc` is located directly at `Interface/AddOns/AutoLazy/AutoLazy.toc`.
3. Launch WoW with `ClassicAPI.dll` loaded.
4. Ensure AutoLazy is checked on the character selection AddOn screen.

## Useful Commands & Shortcuts

| Command | Description |
| :--- | :--- |
| `/al` or `/autolazy` | Open main configuration window |
| `/al tray` | Toggle the Floating Addon Tray |
| `/al toggle` | Pause or resume automatic loot rolls |
| `/al clean` | Toggle Clean Roll Chat suppression |
| `/al quest` | Toggle Shift-Click Quest Automation |
| `/al bop` | Toggle auto-confirmation of BoP popups |
| `/al status` | Display auto-roll state and detected dungeon in chat |
| `/al resetpos` | Reset Floating Hub Button to top right |

| Shortcut | Context | Action |
| :--- | :--- | :--- |
| `Left-Click` Hub Button | Screen | Toggle Addon Tray |
| `Right-Click` Hub Button | Screen | Open AutoLazy configuration |
| `Left-Click Drag` Hub Button | Screen | Reposition hub icon |
| Hold `Shift` | Speaking to Quest NPC | Accelerate quest interaction and chain repeatable turn-ins |

## Limitations & Notes

- **Loot Whitelist**: Auto-rolling only acts on explicitly listed farm items configured under `/al`. Gear, rare drops, and unlisted items are left for manual rolling.
- **Multi-Quest Intent**: On NPCs offering multiple quests, AutoLazy leaves the list visible for you to pick your quest. Once selected, turn-in and accept automation continues while Shift automation is active.
- **Quest Reward Safety**: If a completed quest offers a choice of multiple rewards, AutoLazy pauses immediately to prevent accidental reward selection.

---

For detailed loot configuration and covered repeatable reputation quests, see the [User Guide](docs/USER_GUIDE.md).

## License

MIT License. Maintained by [Fostercare5988](https://github.com/Fostercare5988).
