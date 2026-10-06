# Development

This folder is excluded from addon ZIP downloads and is not loaded by the TOC.
Runtime files are the three Lua modules and AutoLazy.toc. Tests append
`tests/core_access.lua` to the core in the same Lua chunk; test accessors are never shipped.

## Checks

Tests require Python and `lupa.lua51` (Lupa 2.6 supports it):

```text
python -B .dev/tests/test_autolazy.py
python -B .dev/tests/test_minimap_tray.py
```

Each runner also accepts a directory containing Lupa as its first argument.
Run the VanillaForge linter before committing. Do not bypass failed hooks.

## Tray constraints

- Never enumerate engine frames/children or reparent foreign launchers.
- Discover named globals at initialization; inspect newly created Lua buttons incrementally. Clicks use the registry.
- Preserve native input scripts. Control visibility and geometry only while owning a launcher, retaining requested normal state for restoration.
- Pirate Radio and LFT use exact identities. AtlasLoot has a container/child adapter; pfQuest map pins remain excluded.
- Private anonymous launchers or unusual layouts may require `AutoLazy.Tray.Register(frame, child)` or explicit `AutoLazy.Tray.Rescan()`.
- **Minimap > Choose minimap icons** uses eight reusable rows. Checked launchers stay on the minimap; separate Hide settings take priority. Stable names persist in `Tweaks.KeepOnMinimap`; anonymous choices and picker state remain in runtime memory.
- Exclusion releases ownership and restores native state. Re-inclusion captures a fresh snapshot. Native ItemRack parent and input scripts remain intact.

## 3.9.1 audit

Task: final integration audit and bounded polish against 3.9.0 (`a5def40`).
TOC order, SavedVariables declaration, setting keys and dependency requirements remain unchanged.
Defaults now derive from the item catalog instead of a second list. Test-only exports moved out of runtime files.

Measured API-call counts in the Lua model, before and after:

| Scenario | 3.9.0 | 3.9.1 |
| --- | ---: | ---: |
| Inventory reads for the two-quest priority example | 98 | 2 |
| Layout timer requests for 60 repeated native Show/SetShown pairs | 60 | 0 |
| Presentation/dimension setter calls for unchanged docking | 6 | 2 |
| Name normalization calls for 500 non-frame globals | 500 | 0 |

These are model counts, not client timing or FPS measurements. Foreign visibility overrides still request layout because they may change scale or presentation. Width/height writes and the existing anchor sequence remain intact. The chat filter retains only the last message/result across chat frames; inventory is never cached between quest actions. Idle target changes skip NPC identity queries.

Correctness fixes: localized numbered roll placeholders and literal percent signs now produce valid patterns. Auto-roll checks 39 explicit item IDs and the configured dungeon, so shared words cannot opt gear into a rule. AQ20 idols use IDs 20866–20873; AQ40 tier idols and Primal Hakkari Idols stay manual.

Content evidence uses Octowow's official database exclusively. All 39 item IDs/names were verified on 2026-10-04 in the rendered item/drop tables: [Corrupted Sand](https://octowow.st/db/?item=50203), [ZG coins/bijous](https://octowow.st/db/?npc=11352), [AQ20 scarabs/idols](https://octowow.st/db/?npc=15327), [Naxxramas scraps](https://octowow.st/db/?npc=16194). `tests/official_loot_items.csv` retains the identities and their primary sources independently of runtime code. Third-party addon item datasets are not accepted as content proof.

Only the canonical **Vermillion Idol** spelling is recognized. Removed unsupported `vermilion idol`, `primal idol` and bare `hakkari bijou` item-name entries, plus the generic bijou substring guess. This does not change the 39 verified roll IDs or saved actions. The AQ20 idol list now correctly states eight tokens.

[SOURCE-VERIFIED] `GetLootRollItemID` reads the native roll item ID directly, without parsing links or requiring cached names. It is documented at the existing ClassicAPI 1.15.15 minimum, alongside the input/visibility APIs used by the tray: [pinned API reference](https://github.com/brues-code/ClassicAPI/blob/v1.15.15/docs/API.md).

Integration review: 102 Lua 5.1 regression tests pass (54 core, 48 tray). New regressions were checked against 3.9.0. Coverage includes all official catalog IDs/names, rejected name aliases, wrong-dungeon/unlisted rolls, winner/ordinary loot messages, repeatable priority, fresh inventory, foreign visibility overrides, restoration, exceptions, pagination and discovery during a mouse click. VanillaForge reports zero errors and one accepted cold-discovery allocation advisory (`GetRegions`); unsafe child traversal must not replace it. Package exclusions and the six public addon files remain consistent.

[UNVERIFIED - TEST FIRST] The user reports 3.9.0 working in game. The 3.9.1 tests cannot prove native C++ safety, rendering, input ordering or real CPU/GPU cost. After `/reload`, verify ItemRack's checked state, native clicks/menus and restoration; confirm separate Radio/LFT Hide settings still take priority. Check listed versus unlisted dungeon loot, final winner messages, and Shift-click repeatable turn-in priority.

Retrospective: regressions and API-call counters identified useful changes before editing. Review retained explicit dimensions after clearing anchors and preserved foreign override side effects. Source lookup established the existing direct roll-ID API, avoiding unnecessary link parsing. The initial content check used third-party addon data; user review correctly rejected that evidence, prompting full verification against official records and removal of guessed aliases. No polling, extra global scans, new dependencies or framework changes were needed. Developer notes/tests remain excluded from addon downloads.

## v1.0.0 publication

Published 2026-10-04: [AutoLazy v1.0.0](https://github.com/Fostercare5988/AutoLazy/releases/tag/v1.0.0).
Initial commit: `12b6a50f05df5a58c20f1c408ef98c2d0004b60b`.

- 102 Lua tests pass; static validation has zero errors and the accepted cold-discovery advisory.
- Public main has one parentless commit, matching the v1.0.0 tag. Local HEAD/origin/main and the remote tag were reconciled.
- The repository has eight files; the public AutoLazy.zip has six files under AutoLazy/. The downloaded ZIP was verified byte for byte against the tagged files. GitHub recognizes the included MIT LICENSE.
- `.dev/` is now ignored and remains local, including tests and official item-source evidence.
- Local recovery files: `.git/autolazy-before-v1.0.0.bundle` and `.git/autolazy-before-v1.0.0-worktree.zip`.

Retrospective: release inventory found only main, with no prior releases/tags/issues. A verified local backup preceded the user-authorized history reset. The download uses canonical committed line endings to permit exact byte verification. No implementation refactor or framework changes were needed for publication.

### v1.0.0 command cleanup (2026-10-04)

Removed only the `/ar` slash alias; `/al` and `/autolazy` remain. Replaced the published v1.0.0 package and retained a single initial commit (`23b0d361a46d0b2f44eaaa91d506c7fa7c8d70da`). Static validation: zero errors, the existing cold discovery allocation advisory unchanged. Verified the six-file ZIP matches the tagged Git blobs, version and license; the public download matches the local archive byte for byte. GitHub has one branch, one tag and one release. Local recovery copies remain in `.git/autolazy-before-ar-removal.bundle` and `.git/AutoLazy-before-ar-removal.zip`.
