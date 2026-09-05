# AutoLazy

[![Interface: 1.12.1](https://img.shields.io/badge/Interface-1.12.1%20(5875)-orange.svg)](https://github.com/Fostercare5988/AutoLazy)
[![Version: 3.5.0](https://img.shields.io/badge/Version-3.5.0-blue.svg)](https://github.com/Fostercare5988/AutoLazy/releases)
[![ClassicAPI: v1.13.4+](https://img.shields.io/badge/ClassicAPI-v1.13.4+-green.svg)](https://github.com/brues-code/ClassicAPI)
[![SuperWoW: v2.2+](https://img.shields.io/badge/SuperWoW-v2.2+-brightgreen.svg)](https://github.com/balakethelock/SuperWoW)
[![NamPower: v4.6.3+](https://img.shields.io/badge/NamPower-v4.6.3+-blueviolet.svg)](https://github.com/Emyrk/nampower)
[![UnitXP: SP3](https://img.shields.io/badge/UnitXP-SP3-teal.svg)](https://codeberg.org/konaka/UnitXP_SP3)
[![DXVK: Vulkan](https://img.shields.io/badge/DXVK-Vulkan-red.svg)](https://github.com/doitsujin/dxvk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**AutoLazy v3.5.0** is an enterprise-grade, zero-bloat dungeon automation and quality-of-life suite engineered natively for **World of Warcraft 1.12.1 (Build 5875)** running on the **Enhanced Client Extension Stack** (**ClassicAPI v1.13.4+**, **SuperWoW v2.2+**, **NamPower v4.6.3+**, **UnitXP SP3**, and **DXVK**).

It provides intelligent per-dungeon automated loot rolling, global BoP auto-confirmation, continuous Shift-hold repeatable quest chaining, a draggable floating hub with popup Addon Tray, and reversible client bloat suppression (including suppression of custom server pirate radio and group finder elements).

Created and actively maintained by **[Fostercare5988](https://github.com/Fostercare5988)**.

---

## 🚀 Engine Architecture & Performance

AutoLazy is engineered around strict low-level system integration:

| Engine Component | Minimum Version | Architectural Role & Implementation |
| :--- | :--- | :--- |
| **ClassicAPI** | `v1.13.4+` | C++ hardware timers (`C_Timer.After`), modern structured quest information (`C_GossipInfo`), native `table.wipe` memory recycling, and source-rewritten Lua 5.1 syntax. |
| **SuperWoW** | `v2.2+` | Direct memory state access, OS-level window alerting, and zero-latency packet synchronization. |
| **NamPower** | `v4.6.3+` | Microsecond-precision combat pipeline and frame-0 event dispatching for loot rolling and quest chaining. |
| **UnitXP** | `SP3` | High-precision unit state inspection and target validation. |
| **DXVK** | `Latest` | Decoupled high-refresh frame pacing with zero garbage collection heap churn. |

### Elimination of 2006 Legacy Techniques
- **Zero OnUpdate Polling**: Frame-based `OnUpdate` polling loops are eradicated; all periodic scans run on C++ hardware tickers.
- **Zero-GC Register-Based Hierarchy Scanning**: Eliminated transient `{ parent:GetChildren() }` and `{ f:GetRegions() }` table instantiations during addon button discovery and bloat suppression, utilizing register-based tail-call recursion with zero heap allocations.
- **Native Table Recycling**: Integrated native C++ `table.wipe` on evaluation caches and transient lists during zone transitions.
- **Strict Mouse Passthrough (Rule C8)**: All non-interactive container and tray elements leave mouse events unintercepted, ensuring buttons and drag handles respond reliably.

---

## ⚡ Key Features

### 1. Tweaks & Floating Addon Tray
- **AutoLazy Floating Button**: Draggable floating hub icon on your screen:
  - **Left-Click**: Toggle the Floating Addon Tray.
  - **Right-Click**: Open the AutoLazy configuration panel.
  - **Click & Drag**: Move the button anywhere on your screen (positions persist across sessions).
- **Floating Addon Tray**: Neatly gathers all user-installed minimap buttons into a clean, popup tray.
- **Auto-Collapse into Tray**: Automatically gathers and hides addon minimap buttons on login, keeping your minimap 100% clean and clutter-free.
- **Strict Zero-Leak Scanner**: Excludes player combat WeakAuras/DoiteAuras, action buttons, and blizzard core elements from being swallowed into the tray.
- **System Bloat Suppression**: Permanently and reversibly suppresses custom server bloat elements:
  - **Custom Broadcasting Radio**: Suppresses the radio button, player frames, mute toggles, and all broadcasting towers.
  - **Group Finder (LFG)**: Suppresses custom meeting stone / LFG eye buttons without popping open dialog frames upon restoration.

### 2. Loot & Dungeons
- **Per-Dungeon Rules**: Direct, individual control over **Need**, **Greed**, or **Pass** in specific instances:
  - **The Black Morass**: *(Corrupted Sand)*
  - **Zul'Gurub**: *(9 Tribal Coins & 9 Hakkari Bijous)*
  - **Ruins of Ahn'Qiraj**: *(8 Scarabs, 9 Idols, Coffer Keys & Shards)*
- **Farm Items ONLY**: Only auto-rolls on spam farm and currency drops while ignoring weapons and armor so you can roll manually.
- **Dual-Path Global BoP Auto-Confirm**: Automatically confirms both dungeon roll popups (`CONFIRM_LOOT_ROLL`) and direct corpse pickup dialogs (`LOOT_BIND_CONFIRM`) globally.
- **Chat Alerts**: Announces automated rolls on dropped items in chat.

### 3. Continuous Repeatable Quest Automation
- **Continuous Repeatable Chain Hand-in**: Hold **Shift** while talking to an NPC (e.g. Witch Doctor Mau'ari, Thorium Brotherhood, Argent Dawn, ZG Bijous) to continuously turn in all repeatable quests in one uninterrupted sequence without clicking over and over.
- **Auto-Turn In**: Instantly turns in completed quests (with 0 or 1 reward choice).
- **Auto-Accept**: Automatically accepts newly offered quests.
- **Reward Safety**: Automatically pauses if multiple equipment rewards exist, allowing you to choose your desired gear manually.
- **Always Active Mode**: Optional toggle if you prefer automated quest handling on all NPC interactions without holding Shift.

---

## ⌨️ Slash Commands & Configuration Matrix

Use `/al` or `/autolazy` (or `/ar`):

| Command / Action | Description |
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

## 📦 Installation & Engine Prerequisites

### Prerequisites
1. **World of Warcraft 1.12.1** (Build 5875).
2. [**ClassicAPI v1.13.4+**](https://github.com/brues-code/ClassicAPI) (`ClassicAPI.dll`).
3. [**SuperWoW v2.2+**](https://github.com/balakethelock/SuperWoW) (`SuperWoW.dll`).
4. [**NamPower v4.6.3+**](https://github.com/Emyrk/nampower) (`nampower.dll`).
5. [**UnitXP SP3**](https://codeberg.org/konaka/UnitXP_SP3) (`UnitXP_SP3.dll`).
6. [**DXVK**](https://github.com/doitsujin/dxvk) & [**VanillaFixes**](https://github.com/hannesmann/vanillafixes).

### Step-by-Step Installation
1. Clone or download the repository into your WoW AddOns directory:
   ```text
   World of Warcraft/Interface/AddOns/AutoLazy/
   ```
2. Verify that `AutoLazy.toc` is located directly at:
   ```text
   World of Warcraft/Interface/AddOns/AutoLazy/AutoLazy.toc
   ```
3. Launch the game using your DLL loader or launcher with ClassicAPI and SuperWoW enabled.
4. Ensure **AutoLazy** is checked in the character selection AddOn screen.

---

## 📜 Changelog

### v3.5.0
- **Engine Startup Guard Enforcement**: Upgraded engine dependency guards across all modules (`AutoLazy.lua` and `AutoLazy_GUI.lua`) to strictly enforce `MIN_CLASSIC_API = 11304` (`v1.13.4+`) and `SUPERWOW_VERSION` (`v2.2+`).
- **Performance & Zero-GC Audit**: Re-verified zero-allocation register tail recursion and hardware C++ timer chaining across all UI discovery cycles.

### v3.4.0
- **Zero-GC Register Recursion**: Eliminated temporary `{ parent:GetChildren() }` and `{ f:GetRegions() }` table instantiations during addon tray button discovery and bloat suppression, replacing them with register-based tail recursion.
- **Universal Engine Guard**: Enforced strict dependency checks across both module files (`AutoLazy.lua`, `AutoLazy_GUI.lua`) for ClassicAPI v1.13.4+ and SuperWoW v2.2+.
- **Cache Management**: Added native C++ `table.wipe` resets on `ItemEvaluationCache` during dungeon zone transitions.
- **Updated Documentation**: Fully aligned README with ClassicAPI v1.13.4+ and SuperWoW standards.

### v3.3.0
- **Dual-Path Global BoP Auto-Confirmation**: Implemented native `LOOT_BIND_CONFIRM` direct corpse looting alongside `CONFIRM_LOOT_ROLL` group dungeon rolls.
- **ClassicAPI Engine Stack Upgrade**: Modernized startup dependency check to inspect `CLASSIC_API_VERSION` and `SUPERWOW_VERSION` globals.
- **Modern Lua 5.1 Syntax**: Converted loop bounds and math operations to `#` and `%` via ClassicAPI's source-rewriter.
- **C_GossipInfo Integration**: Added support for `C_GossipInfo` structured quest retrieval.

### v3.2.1
- **Continuous Repeatable Quest Chaining**: Added `QUEST_FINISHED` automated event chaining, allowing players to hold Shift and rapidly turn in stacks of repeatable turn-ins back-to-back.
- **Zero-Bloat Consolidation**: Unified system frame detection into `MatchesFrameKeywords` and streamlined startup scan.
- **GUI Centering**: Symmetrically balanced Tab 1 (Tweaks), Tab 2 (Loot), and Tab 3 (Quests) with increased header breathing room.

---

## 📄 License & Community

- **Author & Maintainer**: **[Fostercare5988](https://github.com/Fostercare5988)**
- **GitHub Repository**: [https://github.com/Fostercare5988/AutoLazy](https://github.com/Fostercare5988/AutoLazy)
- **License**: MIT License - See [LICENSE](LICENSE) for details.
