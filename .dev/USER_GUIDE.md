# AutoLazy User Guide

Configuration, loot automation, and Shift-click quest turn-ins for **AutoLazy**.

---

## 1. Floating Hub Button & Addon Tray

- **The Floating Button**:
  - **Left-Click**: Toggle the Floating Addon Tray open or closed.
  - **Right-Click**: Open the AutoLazy configuration panel (`/al`).
  - **Click & Drag**: Move the button anywhere on your screen. The position is saved across sessions.
  - Use `/al resetpos` to return the button to its default position in the top-right corner.
  - The **Minimap** tab contains floating button, tray and icon controls. Hover a control for details; its checkbox label is clickable.
- **Addon Tray**:
  - Discovers named minimap launchers and new Lua-created buttons using their parent, anchors, name, input scripts, and visual content.
  - Opening and closing use the registered button list. Full discovery runs during addon/world initialization; newly created buttons are inspected incrementally.
  - Dynamically supports buttons parented to `Minimap`, `MinimapBackdrop`, `MinimapCluster`, or `UIParent`.
  - Core system icons (minimap tracking, mail, battlefields, zoom, clock, and ticket status) stay in place.
  - Pirate Radio and Looking For Group join the tray. Enable **Hide Pirate Radio** or **Hide Group Finder** to hide them independently.
  - Open **Minimap > Choose minimap icons** and check any detected launcher to keep it outside the tray, including ItemRack. Uncheck it to put it back in the tray. Changes apply immediately. An icon marked **(hidden)** still has a separate Hide setting enabled.
  - Choices are saved by the launcher's frame name and survive reloads, including when its addon loads later. Unnamed icons support a session-only choice, explained on hover. A separate Hide setting still takes priority; the addon's own disabled icon stays disabled.
  - Left-click the floating AutoLazy button to open or close the grid. Click outside or press Escape to close it. Outside clicks continue to their original target.
  - Turn off **Collapse minimap addons** to restore the managed launchers. Buttons disabled in their own addons stay disabled.
  - Existing private anonymous buttons or unusual container designs may need an adapter. See [development notes](README.md).

---

## 2. Dungeon Loot Automation

Configure automated rolling in `/al` > **Loot**:
- **Per-Item Roll Actions**: Select a dungeon, then choose one column in each item row. The grid keeps exactly one action selected:
  - **Need**: Automatically rolls Need.
  - **Greed**: Automatically rolls Greed.
  - **Pass**: Automatically passes on the item.
  - **Manual**: Leaves the roll window open for you to decide.
- **Supported Farm Items**:
  - **Zul'Gurub**: Hakkari Bijous and Tribal Coins.
  - **Ruins of Ahn'Qiraj (AQ20)**: Scarabs and Idols.
  - **Naxxramas**: Wartorn Cloth, Leather, Chain, and Plate Scraps.
  - **The Black Morass**: Corrupted Sand.
- **Global Toggle**: Check **Enable auto-roll** to enable or pause automation. Unlisted items (gear, weapons, boes) are never rolled automatically by AutoLazy.
- Rolling checks the native item ID against the listed dungeon's catalog. It does not match shared words in item names or require cached item names. AQ20 idols are IDs 20866–20873; AQ40 tier idols and Primal Hakkari Idols stay manual. Existing roll settings retain their keys and choices.
- **Clean Group Loot Presentation**: Toggleable via `/al clean` or **Hide loot roll spam** in the Loot tab (enabled by default). Suppresses intermediate Need/Greed/Pass notifications, roll numbers, and all-pass clutter during group loot rolls, presenting only a single final winner line with a clickable item link. Non-roll loot (corpse looting, direct item acquisition, and money) remains fully visible.
- **BoP Auto-Confirmation**: Toggle **Auto-confirm loot** to confirm Bind-on-Pickup popups during loot rolls and corpse looting. It dims while auto-roll is disabled; your choice remains saved.
- The zone readout is removed from options. Dungeon detection still drives loot rules; use `/al status` for diagnostics.

---

## 3. Shift-click Quest Turn-ins

Configure turn-ins in `/al` > **Quests**. All available quests, including repeatables, must be accepted manually.

### Usage
- **Enable Shift-click**: Hold **Shift** when talking to an NPC to start a turn-in session and supported gossip shortcuts. Each new NPC greeting requires Shift. `/al quest` toggles this setting.
- **Turn in completed quests**: Automates progress and reward dialogs for completed quests during the session. `/al turnin` toggles this setting. Dependent controls dim when their parent setting is off, retaining your preferences.
- **Quest Selection**: AutoLazy selects a single completed quest automatically. When several ordinary completed quests are ready, choose one yourself. Supported completed repeatables use inventory-based priority.
- **Manual Acceptance**: Accept new and repeatable quests yourself. AutoLazy can then turn in completed quests during a Shift-initiated session. It never selects an available quest or accepts its detail dialog automatically.

### Supported Reputation Quests
- **Argent Dawn**: Scourgestones (Minion's, Invader's, Corruptor's), Craftsman's Writs, Healthy Dragon Scales, and bone parts.
- **Winterspring E'ko**: Witch Doctor Mau'ari E'ko turn-ins.
- **Thorium Brotherhood**: Dark Iron Residue, Dark Iron Ore, Fiery/Lava Cores, Blood of the Mountain.
- **Cenarion Circle**: Encrypted Twilight Texts, Abyssal Crests/Signets/Scepters, combat badges.
- **Timbermaw Hold**: Deadwood Feathers and Winterfall Beads.
- **Zandalar Tribe**: Bijou destruction at the Altar of Zanza, Coin combinations.
- **Battlegrounds**: AV Armor Scraps, Soldier's Blood, Lieutenant's Flesh.
- **City Donations & Morrowgrain**: Repeatable Runecloth donations and Un'Goro Morrowgrain.

### Reward Choices
- **Choose rewards manually** is enabled by default. It pauses turn-ins when multiple rewards are offered so you can select one. Turning this option off permits automatic selection of the first reward.
