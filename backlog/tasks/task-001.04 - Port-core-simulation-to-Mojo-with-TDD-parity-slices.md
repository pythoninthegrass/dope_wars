---
id: TASK-001.04
title: Port core simulation to Mojo with TDD parity slices
status: To Do
assignee: []
created_date: '2026-09-26 04:34'
labels:
  - mojo
  - parity
  - migration
milestone: m-1
dependencies:
  - TASK-001.01
  - TASK-001.02
references:
  - ~/git/jumpnbump/core/game_loop.zig
  - ~/git/jumpnbump/core/rnd.zig
  - ~/git/jumpnbump/core/abi.zig
documentation:
  - index.html
  - tests/engine.test.mjs
  - docs/gameplay.md
  - docs/mechanics-notes.md
parent_task_id: TASK-001
priority: high
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the full game simulation in Mojo (`core/`), porting every function from `<script id="engine">` (lines 609-1079) one subsystem at a time, strictly test-first against the oracle fixtures from TASK-001.02.

**Porting order (bottom-up, leaf-first):**
1. RNG: `mulberry32` / `randInt` — foundation for all downstream determinism
2. RULES constants and lookup helpers (`findDrug`, `findLocation`)
3. `newGame` / state initialisation
4. `generatePrices` / `shuffle`
5. `buy` / `sell` / `coatUsed`
6. `travel` / interest compounding (`debtInterest`, `bankInterest`)
7. `finances` (deposit/withdraw/payLoan)
8. `rollArrivalEvent` and helpers (`addToInventory`, `removeFromInventory`, `applyDamage`, `randomTradeableDrug`)
9. Coat and gun dealers (`rollCoatDealerOffer`, `acceptCoatOffer`, `rollGunDealerOffer`, `acceptGunOffer`)
10. Chase/combat (`shouldStartChase`, `startChase`, `getFightRatings`, `runFromChase`, `fight`)
11. `finish` / `insertHighScore`
12. `serializeState` / `deserializeState` (round-trip fidelity)

Each slice: write failing test → implement → pass → move on. Core must never import Godot headers, FFI shims, or platform I/O.

Use `~/git/jumpnbump/core/` as the structural reference (one `.mojo` file per logical subsystem, a single `abi.mojo` as the sole ABI exporter — TASK-001.05 will populate that file from this core).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each subsystem starts with at least one failing parity test validated against a fixture from TASK-001.02 before any implementation is written (TDD gating)
- [ ] #2 Deterministic: the same seed produces identical game-state transitions across an entire 31-day run; verified by replaying the full-game golden fixture
- [ ] #3 All functions exported in index.html:1049-1077 are implemented in Mojo and covered by parity tests
- [ ] #4 Core builds as a standalone static library with no imports from Godot, GDExtension, or any I/O framework
- [ ] #5 Mojo LOC is measured after each subsystem slice and tracked toward the >=43% non-vendor target
<!-- AC:END -->
