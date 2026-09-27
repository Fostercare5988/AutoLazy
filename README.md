# AutoLazy

Required ClassicAPI version: **v1.15.15+**. This is the maintainer's published support baseline for this addon suite; it is not a claim that every API used here was introduced in v1.15.15. After replacing ClassicAPI.dll, fully restart WoW; `/reload` cannot reload a DLL.

[![Interface: 1.12.1](https://img.shields.io/badge/Interface-1.12.1%20(5875)-orange.svg)](https://github.com/Fostercare5988/AutoLazy)
[![Version: 3.7.0](https://img.shields.io/badge/Version-3.7.0-blue.svg)](https://github.com/Fostercare5988/AutoLazy/releases)
[![ClassicAPI: v1.15.15+](https://img.shields.io/badge/ClassicAPI-v1.15.15+-green.svg)](https://github.com/brues-code/ClassicAPI)
[![SuperWoW: v2.2+](https://img.shields.io/badge/SuperWoW-v2.2+-brightgreen.svg)](https://github.com/balakethelock/SuperWoW)
[![UnitXP: SP3](https://img.shields.io/badge/UnitXP-SP3-teal.svg)](https://codeberg.org/konaka/UnitXP_SP3)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**AutoLazy v3.7.0** is a dungeon automation and quality-of-life addon for **World of Warcraft 1.12.1 (Build 5875)** running on the **Enhanced Client Extension Stack** (**ClassicAPI v1.15.15+**, **SuperWoW v2.2+**, and **UnitXP SP3**).

It provides intelligent per-dungeon automated loot rolling, global BoP auto-confirmation, continuous Shift-hold repeatable quest chaining, a draggable floating hub with popup Addon Tray, and reversible client bloat suppression (including suppression of custom server pirate radio and group finder elements).

Created and actively maintained by **[Fostercare5988](https://github.com/Fostercare5988)**.

---

## 🚀 Engine Architecture & Performance

AutoLazy is engineered around strict low-level system integration:

| Engine Component | Minimum Version | Architectural Role & Implementation |
| :--- | :--- | :--- |
| **ClassicAPI** | `v1.15.15+` | C++ hardware timers (`C_Timer.After`), modern structured quest information (`C_GossipInfo`), native `table.wipe` memory recycling, and source-rewritten Lua 5.1 syntax. |
| **SuperWoW** | `v2.2+` | Direct memory state access, OS-level window alerting, and packet-based event synchronization. |
| **UnitXP** | `SP3` | High-precision unit state inspection and target validation. |

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
- **One action per listed item**: In `/al` → Loot & Dungeons, choose exactly one of **Manual**, **Need**, **Greed**, or **Pass** for each item. Manual leaves the normal roll window open. The single **Auto-roll listed items** checkbox pauses or resumes these choices; unlisted items are never rolled by AutoLazy.
- **Listed items and defaults**:
  - **The Black Morass**: *Corrupted Sand* (Need).
  - **Zul'Gurub**: *Bijous* and *Coins* (Need).
  - **Ruins of Ahn'Qiraj (AQ20)**: *Scarabs* (Need) and *Idols* (Manual).
  - **Naxxramas**: *Wartorn Cloth, Leather, Chain, and Plate Scraps* (Need).
- **Reset This Dungeon** restores those item defaults for the selected dungeon.
- **BoP confirmation** is a separate option that confirms bind-on-pickup roll and direct-loot dialogs while auto-roll is enabled.
- **One-time settings migration** converts prior Auto-Need and fallback choices to item actions. A previously disabled dungeon becomes Manual for all its listed items, and obsolete per-dungeon settings are removed.
- **Chat Alerts**: Announces automated rolls on dropped items in chat.

### 3. Continuous Repeatable Quest Automation
- **Continuous Repeatable Chain Hand-in**: Hold **Shift** while talking to an NPC to continuously turn in all repeatable quests in one uninterrupted sequence without clicking over and over.
- **Comprehensive Turn-In Coverage**:
  - **Argent Dawn**: Minion's, Invader's, Corruptor's Scourgestones, Craftsman's Writs, Healthy Dragon Scales, and bone/crypt parts.
  - **Winterspring E'ko**: Witch Doctor Mau'ari (Winterfall, Frostmaul, Shardtooth, Frostsaber, Wildkin, Chillwind, Ice Thistle).
  - **Thorium Brotherhood**: Dark Iron Residue, Dark Iron Ore, Fiery/Lava Cores, Blood of the Mountain, and Searing Gorge turn-ins.
  - **Cenarion Circle**: Encrypted Twilight Texts, Abyssal Crests/Signets/Scepters, and combat/tactical/logistics badges.
  - **Timbermaw Hold**: Deadwood Headdress Feathers, Winterfall Spirit Beads, and Water Elemental Cores.
  - **Zandalar Tribe**: Hakkari Bijous (direct Altar of Zanza destruction & quests) and Tribal Coins.
  - **Alterac Valley & Battlegrounds**: Armor Scraps, Soldier's Blood, and Lieutenant's Flesh.
  - **Un'Goro & Factions**: Morrowgrain, Bloodpetal Sprouts, and repeatable city Runecloth donations.
- **Smart Inventory & Bag Prioritization**: Automatically prioritizes available repeatable quests for which you currently have items in your bags (bypassing trivial/gray quest level penalties).
- **Direct Gossip Turn-Ins**: Automatically activates repeatable turn-in options from direct gossip dialogs (e.g. Altar of Zanza, Lokhtos Darkbargainer, Alterac Valley).
- **Auto-Turn In**: Instantly turns in completed quests (with 0 or 1 reward choice).
- **Auto-Accept**: Automatically accepts newly offered quests.
- **Reward Safety**: Automatically pauses if multiple equipment rewards exist, allowing you to choose your desired gear manually.
- **Always Active Mode**: Optional toggle (`/al always`) if you prefer automated quest handling on all NPC interactions without holding Shift.

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
| `/al toggle` | Pauses or resumes automatic rolls for listed items |
| `/al quest` | Toggles Shift-Click Quest Automation |
| `/al bop` | Toggles automatic confirmation of BoP popups |
| `/al chat` | Toggles chat roll alerts |
| `/al status` | Displays auto-roll state and current dungeon detection in chat |

---

## 📦 Installation & Engine Prerequisites

### Prerequisites
1. **World of Warcraft 1.12.1** (Build 5875).
2. [**ClassicAPI v1.15.15+**](https://github.com/brues-code/ClassicAPI) (`ClassicAPI.dll`).
3. [**SuperWoW v2.2+**](https://github.com/balakethelock/SuperWoW) (`SuperWoW.dll`).
4. [**UnitXP SP3**](https://codeberg.org/konaka/UnitXP_SP3) (`UnitXP_SP3.dll`).

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

### Unreleased
- Replaced overlapping dungeon, fallback, and Auto-Need toggles with one action per listed item: Manual, Need, Greed, or Pass.
- Preserved existing choices through a one-time SavedVariables migration; removed obsolete per-dungeon state.

### v3.7.0
- **Master-Detail Loot Dashboard**: Re-engineered Tab 2 with interactive 28x28 item icons, item quality coloring, live tooltip inspection, and granular per-item Auto-Need ON/OFF toggles.
- **Strict Tedious Items Whitelist**: Scoped dungeon automation strictly to high-volume tedious farm items (The Black Morass Corrupted Sand, Zul'Gurub Bijous & Coins, AQ20 Scarabs & Idols, and Naxxramas Wartorn Scraps).
- **Naxxramas Tier 3 Armor Scraps**: Added support for Wartorn Cloth, Leather, Chain, and Plate Scraps with icons and quality borders.
- **Removed FarmOnly Toggle**: Completely eliminated the redundant "Farm items ONLY" setting; all unlisted items (gear, weapons, quest drops) are 100% ignored by default.
- **Pruned Non-Essential Dungeons**: Removed Blackrock Depths, Stratholme, and Scholomance from loot rolling.
- **Safe Fallback Actions**: Added configurable non-need actions (`Roll Manually` [Default], `Greed`, or `Pass`) when an item's Auto-Need is disabled.

### v3.6.1
- **Zero-Allocation Hierarchy & Region Scanning**: Eliminated runtime closure instantiation inside `MatchesFrameKeywords` and `HasRenderableVisual` by replacing recursive inner closures with static `select(i, ...)`-based iterators.
- **Static Table Hoisting**: Hoisted `KNOWN_RADIO_FRAMES`, `KNOWN_LFG_FRAMES`, `DISCOVERY_PARENTS`, and `EXPLICIT_ADDON_BUTTONS` to file scope, eradicating garbage collection churn during zone transitions and minimap icon sweeps.
- **Native Item Counting Optimization**: Streamlined `GetPlayerItemCount` to query native C++ `GetItemCount` directly, eliminating redundant 5-bag 80-slot manual string loops when turn-in count is zero.
- **Global Scope Hardening**: Localized `trayFrame` and `actionBtn` away from the global `_G` namespace.
- **Tray Keyboard Navigation**: Registered `AutoLazy_ButtonTray` in `UISpecialFrames` with automatic `OnHide` child synchronization, enabling seamless Escape-key dismissal.
- **Bug Fix**: Fixed uninitialized `bopStatus` nil variable reference in `/autolazy status` command.

### v3.6.0
- **Modern Clean UI Layout**: Updated tab controls, dialog dimensions, and breathing room across all options frames.
- **Native C++ Table Acceleration**: Integrated `table.wipe` memory recycling across evaluation caches and button discovery lists.

### v3.5.0
- **Engine Startup Guard Enforcement**: Upgraded engine dependency guards across all modules (`AutoLazy.lua` and `AutoLazy_GUI.lua`) to strictly enforce `MIN_CLASSIC_API = 11400` (`v1.14.0+`) and `SUPERWOW_VERSION` (`v2.2+`).
- **Performance & Zero-GC Audit**: Re-verified zero-allocation register tail recursion and hardware C++ timer chaining across all UI discovery cycles.

### v3.4.0
- **Zero-GC Register Recursion**: Eliminated temporary `{ parent:GetChildren() }` and `{ f:GetRegions() }` table instantiations during addon tray button discovery and bloat suppression, replacing them with register-based tail recursion.
- **Universal Engine Guard**: Enforced strict dependency checks across both module files (`AutoLazy.lua`, `AutoLazy_GUI.lua`) for ClassicAPI v1.14.0+ and SuperWoW v2.2+.
- **Cache Management**: Added native C++ `table.wipe` resets on `ItemEvaluationCache` during dungeon zone transitions.
- **Updated Documentation**: Fully aligned README with ClassicAPI v1.14.0+ and SuperWoW standards.

### v3.3.0
- **Dual-Path Global BoP Auto-Confirmation**: Implemented native `LOOT_BIND_CONFIRM` direct corpse looting alongside `CONFIRM_LOOT_ROLL` group dungeon rolls.
- **ClassicAPI Engine Stack Upgrade**: Modernized startup dependency check to inspect `CLASSIC_API_VERSION` and `SUPERWOW_VERSION` globals.
- **Modern Lua 5.1 Syntax**: Converted loop bounds and math operations to `#` and `%` via ClassicAPI's source-rewriter.
- **C_GossipInfo Integration**: Added support for `C_GossipInfo` structured quest retrieval.

### v3.2.1
- **Continuous Repeatable Quest Chaining**: Added `QUEST_FINISHED` automated event chaining, allowing players to hold Shift and rapidly turn in stacks of repeatable turn-ins back-to-back.
- **System Detection Consolidation**: Unified system frame detection into `MatchesFrameKeywords` and streamlined startup scan.
- **GUI Centering**: Symmetrically balanced Tab 1 (Tweaks), Tab 2 (Loot), and Tab 3 (Quests) with increased header breathing room.

---

## 📄 License & Community

- **Author & Maintainer**: **[Fostercare5988](https://github.com/Fostercare5988)**
- **GitHub Repository**: [https://github.com/Fostercare5988/AutoLazy](https://github.com/Fostercare5988/AutoLazy)
- **License**: MIT License - See [LICENSE](LICENSE) for details.
