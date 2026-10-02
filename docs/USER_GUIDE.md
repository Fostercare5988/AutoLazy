# AutoLazy User Guide

Detailed configuration, loot automation, and quest chaining reference for **AutoLazy**.

---

## 1. Floating Hub Button & Addon Tray

- **The Floating Button**:
  - **Left-Click**: Toggle the Floating Addon Tray open or closed.
  - **Right-Click**: Open the AutoLazy configuration panel (`/al`).
  - **Click & Drag**: Move the button anywhere on your screen. The position is saved across sessions.
  - Use `/al resetpos` to return the button to its default position in the top-right corner.
- **Universal Addon Tray**:
  - Automatically discovers and collapses installed 3rd-party add-on minimap buttons (ItemRack, Gatherer, Questie, Decursive, KTM, AtlasLoot, Bagnon, BigWigs, etc.) into a clean, collapsible tray.
  - Dynamically supports buttons parented to `Minimap`, `MinimapBackdrop`, `MinimapCluster`, or `UIParent`.
  - Core system icons (Minimap tracking, mail, battlefields) and server features (Pirate Radio, Group Finder) are strictly excluded from the tray.
  - Prevents minimap clutter while keeping all your add-on launchers accessible in one click.

---

## 2. Dungeon Loot Automation

Configure automated rolling in `/al` > **Loot**:
- **Per-Item Roll Actions**: For each supported farm item, choose exactly one action:
  - **Need**: Automatically rolls Need.
  - **Greed**: Automatically rolls Greed.
  - **Pass**: Automatically passes on the item.
  - **Manual**: Leaves the roll window open for you to decide.
- **Supported Farm Items**:
  - **Zul'Gurub**: Hakkari Bijous and Tribal Coins.
  - **Ruins of Ahn'Qiraj (AQ20)**: Scarabs and Idols.
  - **Naxxramas**: Wartorn Cloth, Leather, Chain, and Plate Scraps (Intelligently defaults to **Need** for your class's armor type and **Manual** for other armor types, preventing accidental guild loot drama while remaining 100% customizable).
  - **The Black Morass**: Corrupted Sand.
- **Global Toggle**: Check **Auto-roll listed items** to enable or pause automation. Unlisted items (gear, weapons, boes) are never rolled automatically by AutoLazy.
- **Clean Group Loot Presentation**: Toggleable via `/al clean` or the **Clean Roll Chat** checkbox in Tab 2 (enabled by default). Suppresses intermediate Need/Greed/Pass notifications, roll numbers, and all-pass clutter during group loot rolls, presenting only a single final winner line with a clickable item link. Non-roll loot (corpse looting, direct item acquisition, and money) remains fully visible.
- **BoP Auto-Confirmation**: Toggle **Auto-confirm BoP** to confirm Bind-on-Pickup popups during loot rolls and corpse looting.

---

## 3. Repeatable Quest Automation

Turn in stacks of repeatable reputation and token quests without clicking through repetitive dialogue:

### Usage
- **Shift-Click Chaining (Default)**: Hold the **Shift** key when talking to a quest NPC to continuously turn in all repeatable quests in one uninterrupted sequence.
- **Multi-Quest NPCs**: When an NPC offers multiple quests, AutoLazy keeps the list visible so you can select the quest you want. Once clicked, accept and turn-in automation proceeds seamlessly while the Shift automation session remains active. AutoLazy never blindly chooses quest #1.
- **Always Active Mode**: Toggle `/al always` or enable the setting in `/al` to automate quest dialogue without needing to hold Shift.

### Supported Reputation Quests
- **Argent Dawn**: Scourgestones (Minion's, Invader's, Corruptor's), Craftsman's Writs, Healthy Dragon Scales, and bone parts.
- **Winterspring E'ko**: Witch Doctor Mau'ari E'ko turn-ins.
- **Thorium Brotherhood**: Dark Iron Residue, Dark Iron Ore, Fiery/Lava Cores, Blood of the Mountain.
- **Cenarion Circle**: Encrypted Twilight Texts, Abyssal Crests/Signets/Scepters, combat badges.
- **Timbermaw Hold**: Deadwood Feathers and Winterfall Beads.
- **Zandalar Tribe**: Bijou destruction at the Altar of Zanza, Coin combinations.
- **Battlegrounds**: AV Armor Scraps, Soldier's Blood, Lieutenant's Flesh.
- **City Donations & Morrowgrain**: Repeatable Runecloth donations and Un'Goro Morrowgrain.

### Safety Guarantee
- If a quest offers multiple reward choices (such as choosing between multiple pieces of equipment), AutoLazy pauses immediately to allow manual selection.
