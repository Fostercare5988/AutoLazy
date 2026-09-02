# AutoLazy

[![Version](https://img.shields.io/badge/Version-3.3.0-blue.svg)](https://github.com/Fostercare5988/AutoLazy/releases)
[![Interface](https://img.shields.io/badge/Interface-1.12.1%20(Build%205875)-orange.svg)](https://github.com/Fostercare5988/AutoLazy)
[![Engine](https://img.shields.io/badge/Engine-ClassicAPI%20%7C%20SuperWoW%20%7C%20NamPower%20%7C%20UnitXP%20%7C%20DXVK-green.svg)](https://github.com/Fostercare5988/AutoLazy)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/Fostercare5988/AutoLazy)

**AutoLazy v3.3.0** is a high-performance, zero-bloat automation and quality-of-life suite engineered natively for **World of Warcraft 1.12.1** running the **Enhanced Client Extension Stack** (**ClassicAPI**, **SuperWoW 2.2+**, **NamPower 4.6.2+**, **UnitXP SP3**, and **DXVK**) created and maintained by **Fostercare5988**.

It features per-dungeon automated loot rolling, global BoP auto-confirmation, **Continuous Shift-Hold Repeatable Quest Automation**, a **Draggable Floating Button & Addon Tray**, and **Reversible System Bloat Suppression** (including toggles for custom server Radio and Group Finder).

---

## ✨ Features & Tabs

### 🗂️ Tab 1: Tweaks (System Bloat & Floating Addon Tray)
- **AutoLazy Floating Button**: A sleek, draggable floating hub icon on your screen.
  - **Left-Click**: Open / Close the Floating Addon Tray.
  - **Right-Click**: Open AutoLazy Options.
  - **Click & Drag**: Move the button anywhere on your screen.
- **Floating Addon Tray**: Neatly gathers all user-installed minimap buttons into a clean, popup tray.
- **Auto-Collapse into Tray**: Automatically gathers and hides addon minimap buttons on login, keeping the minimap 100% clean and clutter-free.
- **Strict Zero-Leak Scanner**: Excludes player combat WeakAuras/DoiteAuras, action buttons, and blizzard core elements from being swallowed into the tray.
- **System Bloat Suppression**: Permanently hides custom server bloat elements:
  - **Custom Broadcasting Radio**: Suppresses the radio button, player frames, mute toggles, and all broadcasting towers.
  - **Group Finder (LFG)**: Suppresses the custom meeting stone / LFG eye button without popping open large dialog frames upon restoration.

### 💰 Tab 2: Loot & Dungeons
- **Per-Dungeon Rules**: Direct, individual control over **Need**, **Greed**, or **Pass** in specific instances:
  - **The Black Morass**: *(Corrupted Sand)*
  - **Zul'Gurub**: *(9 Tribal Coins & 9 Hakkari Bijous)*
  - **Ruins of Ahn'Qiraj**: *(8 Scarabs, 9 Idols, Coffer Keys & Shards)*
- **🌾 Farm Items ONLY**: Only auto-rolls on spam farm/currency drops and ignores weapons and armor so you can roll manually.
- **⚡ Dual-Path Global BoP Auto-Confirm**: Automatically confirms both dungeon roll popups (`CONFIRM_LOOT_ROLL`) and direct corpse pickup dialogs (`LOOT_BIND_CONFIRM`) globally.
- **💬 Chat Alerts**: Announces automated rolls on dropped items in chat.

### 📜 Tab 3: Quest Automation (Continuous Shift-Hold)
- **Continuous Repeatable Chain Hand-in**: Hold **Shift** while talking to an NPC (e.g. Witch Doctor Mau'ari, Thorium Brotherhood, Argent Dawn, ZG Bijous) to continuously turn in all repeatable quests in one uninterrupted sequence without clicking over and over.
- **Auto-Turn In**: Instantly turns in completed quests (with 0 or 1 reward choice).
- **Auto-Accept**: Automatically accepts newly offered quests.
- **Reward Safety**: Automatically pauses if multiple equipment rewards exist, allowing you to choose your desired gear manually.
- **Always Active Mode**: Optional toggle if you prefer automated quest handling on all NPC interactions without holding Shift.

---

## 🏗️ Technical Architecture & Zero-Bloat Optimizations

- **ClassicAPI Source-Rewriter Integration**: Leverages ClassicAPI's native AST preprocessor, writing clean modern Lua 5.1 syntax (`#`, `%`, `C_GossipInfo`) while guaranteeing zero compile errors on the 1.12.1 engine.
- **Strict Version Globals Startup Guard**: Validates DLL initialization using `CLASSIC_API_VERSION` and `SUPERWOW_VERSION`.
- **Hybrid Modern Gossip Engine**: Prioritizes `C_GossipInfo` structured queries with zero-allocation fallback to native `GetGossipActiveQuests()`.
- **Native C++ Timers**: Leverages ClassicAPI's native `C_Timer.After` for instant startup scans and repeatable quest chaining with zero Lua `OnUpdate` polling frames.
- **DRY Unified Frame Scanner**: Single centralized, keyword-driven inspector (`MatchesFrameKeywords`) with reversible coordinate preservation (`_alOrigState`).
- **Data-Driven Dispatch**: O(1) table-driven slash command routing (`slashToggles[cmd]()`).

---

## ⌨️ Slash Commands

Use `/al` or `/autolazy` (or `/ar`):

| Command | Description |
| :--- | :--- |
| `/al` or `/autolazy` | Opens or closes the configuration window |
| `/al tray` | Toggles the Floating Addon Tray |
| `/al collapse` | Toggles Auto-Collapse Addons into Tray |
| `/al btn` | Toggles the Floating Hub Button show/hide |
| `/al resetpos` | Resets the Floating Hub Button position to the top right |
| `/al radio` | Toggles Booty Bay Pirate Radio & broadcasting towers suppression |
| `/al lfg` | Toggles Group Finder (LFG) suppression |
| `/al toggle` | Toggles Dungeon Auto-Loot ON / OFF |
| `/al farm` | Toggles Farm Items ONLY mode |
| `/al quest` | Toggles Shift-Click Quest Automation |
| `/al bop` | Toggles automatic confirmation of BoP popups |
| `/al chat` | Toggles chat roll alerts |
| `/al status` | Displays active dungeon detection and per-instance modes in chat |

---

## 📦 Installation & Requirements

1. **Requirements**:
   - **World of Warcraft 1.12.1** (Build 5875).
   - [**ClassicAPI**](https://github.com/brues-code/ClassicAPI) (`ClassicAPI.dll`).
   - [**SuperWoW**](https://github.com/balakethelock/SuperWoW) (`SuperWoW.dll` v2.2+).
   - [**NamPower**](https://github.com/Emyrk/nampower) (`nampower.dll` v4.6.2+).
   - [**UnitXP SP3**](https://codeberg.org/konaka/UnitXP_SP3) (`UnitXP_SP3.dll`).
   - [**DXVK**](https://github.com/doitsujin/dxvk) & [**VanillaFixes**](https://github.com/hannesmann/vanillafixes).
2. **Installation**:
   - Place the `AutoLazy` folder into:
     ```text
     World of Warcraft/Interface/AddOns/AutoLazy/
     ```
   - Ensure `AutoLazy.toc` is directly inside `Interface/AddOns/AutoLazy/`.
   - Enable **AutoLazy** in the AddOn list at character selection.

---

## 📜 Changelog

### v3.3.0
- **Dual-Path Global BoP Auto-Confirmation**: Implemented native `LOOT_BIND_CONFIRM` direct corpse looting alongside `CONFIRM_LOOT_ROLL` group dungeon rolls.
- **ClassicAPI Engine Stack Upgrade**: Modernized startup dependency check to inspect `CLASSIC_API_VERSION` and `SUPERWOW_VERSION` globals.
- **Modern Lua 5.1 Syntax**: Converted loop bounds and math operations to `#` and `%` via ClassicAPI's source-rewriter.
- **C_GossipInfo Integration**: Added support for `C_GossipInfo` structured quest retrieval.
- **Updated Documentation & Metadata**: Published comprehensive technical README under Rule H5 with TOC metadata.

### v3.2.1
- **Fixed Gossip API**: Resolved `GetNumGossipActiveQuests` nil function crash on 1.12.1 client by using native `GetGossipActiveQuests()` zero-allocation return signature.
- **Continuous Repeatable Quest Chaining**: Added `QUEST_FINISHED` automated event chaining, allowing players to hold Shift and rapidly turn in stacks of repeatable turn-ins (e.g. E'ko, Bijous, Scourgestones) back-to-back.
- **Zero-Bloat Consolidation**: Unified system frame detection into `MatchesFrameKeywords` and streamlined startup scan.
- **GUI Centering**: Symmetrically balanced Tab 1 (Tweaks), Tab 2 (Loot), and Tab 3 (Quests) with increased header breathing room.

---

## 👤 Author & Credits

- **Author & Maintainer**: **[Fostercare5988](https://github.com/Fostercare5988)**
- **License**: MIT License - See [LICENSE](LICENSE) for details.
