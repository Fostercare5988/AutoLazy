# Development

This folder is excluded from addon ZIP downloads and is not loaded by the TOC.
Runtime files are the three Lua modules and AutoLazy.toc.

## Checks

Tests require Python and `lupa.lua51` (Lupa 2.6 supports it):

```text
python -B .dev/tests/test_autolazy.py
python -B .dev/tests/test_minimap_tray.py
```

Each runner also accepts a directory containing Lupa as its first argument.
Run your addon static checks before committing. Do not bypass failed hooks.

## Tray constraints

- Never enumerate engine frames/children or reparent foreign launchers.
- Discover named globals at initialization; inspect newly created Lua buttons incrementally. Clicks use the registry.
- Preserve native input scripts. Control Show/Hide and geometry only while owning a launcher, retaining requested normal state for restoration.
- Pirate Radio and LFT use exact identities. AtlasLoot has a container/child adapter; pfQuest map pins remain excluded.
- Private anonymous launchers or unusual layouts may require `AutoLazy.Tray.Register(frame, child)` or explicit `AutoLazy.Tray.Rescan()`.
- ClassicAPI input/visibility APIs used here exist at the declared floor: [API reference](https://github.com/brues-code/ClassicAPI/blob/v1.15.15/docs/API.md).

## 3.8.0 review

Tray discovery, restoration and suppression; compact lazy options; removal of automatic quest acceptance and Always Active; clearer loot labels; clean packaging. The Lua model verifies state and callback behavior, not native C++ memory safety, rendering or real hit testing. The user reports the tray and compact UI working in game. No zero CPU/GPU cost claim is made.

Saved settings retain existing names; removed quest keys are purged. Developer state is not SavedVariables state. The static allocation advisory in cold `GetRegions` discovery is accepted; engine child traversal must not replace it.

Regression tests and source/API evidence were retained in this folder. Long task reports and temporary runtimes were removed. No new framework lesson was needed.
