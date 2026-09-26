---
id: TASK-001
title: Migrate index.html prototype to Godot with Mojo-first architecture
status: To Do
assignee: []
created_date: '2026-09-26 04:33'
updated_date: '2026-09-26 04:34'
labels:
  - godot
  - mojo
  - ffi
  - migration
  - parity
dependencies:
  - TASK-001.01
  - TASK-001.02
  - TASK-001.03
  - TASK-001.04
  - TASK-001.05
  - TASK-001.06
  - TASK-001.07
references:
  - ~/git/jumpnbump/README.md
  - ~/git/jumpnbump/core/README.md
  - ~/git/jumpnbump/extension/README.md
  - ~/git/jumpnbump/game/README.md
documentation:
  - index.html
  - tests/engine.test.mjs
  - docs/gameplay.md
  - docs/mechanics-notes.md
  - AGENTS.md
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Port the 1711-line `index.html` browser prototype to a full Godot game using Mojo for the simulation core, a frozen C ABI as the language boundary, and a C++ GDExtension shim as the bridge. This mirrors the architecture proven in `~/git/jumpnbump` (Zig → C ABI → C++ GDExtension → GDScript) but with Mojo as the dominant language, targeting Mojo at >=43% of non-vendor non-generated LOC at parity completion — the same ratio Zig reaches in that repo.

**Locked architecture (no deviation without explicit approval):**
- `core/` — Mojo simulation: RNG, pricing, trading, events, combat, scoring, serialization. Zero Godot/FFI imports.
- `include/dopewars.h` — frozen C ABI exported from Mojo, consumed only by C++.
- `extension/` — C++ GDExtension shim forwarding 1:1 to the ABI. No game logic.
- `game/` — GDScript presentation, input, persistence orchestration. Simulation state lives in Mojo; GDScript never calls Mojo directly.

**Source mapping:**
- `index.html:609-1079` (`<script id="engine">`) → Mojo core
- `index.html:1081-1710` (`<script id="ui">`) → GDScript game layer
- `tests/engine.test.mjs` → baseline oracle for parity fixtures

**Reference implementation:** `~/git/jumpnbump/` — `core/` (Zig sim), `include/jumpnbump.h` (frozen C ABI), `extension/` (C++ GDExtension), `game/` (Godot project). All architectural decisions should be grounded in how that repo solved the equivalent problem.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Full game loop is playable in Godot: new game, buy/sell, travel, arrival events, coat/gun dealers, chase/combat, finances, and end-of-game score screen
- [ ] #2 Behavior parity with JS oracle for all agreed scenarios — deterministic under fixed seed
- [ ] #3 Non-vendor non-generated LOC reaches >=43% Mojo by final parity milestone
- [ ] #4 All 7 subtasks are complete and pass their own acceptance criteria
- [ ] #5 Contributor docs explain architecture, build commands, test tiers, and how to measure Mojo LOC percentage
<!-- AC:END -->
