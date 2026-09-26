---
id: TASK-001.04
title: Port core simulation to Mojo with TDD parity slices
status: Done
assignee:
  - claude
created_date: '2026-09-26 04:34'
updated_date: '2026-09-26 07:09'
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
- [x] #1 Each subsystem starts with at least one failing parity test validated against a fixture from TASK-001.02 before any implementation is written (TDD gating)
- [x] #2 Deterministic: the same seed produces identical game-state transitions across an entire 31-day run; verified by replaying the full-game golden fixture
- [x] #3 All functions exported in index.html:1049-1077 are implemented in Mojo and covered by parity tests
- [x] #4 Core builds as a standalone static library with no imports from Godot, GDExtension, or any I/O framework
- [x] #5 Mojo LOC is measured after each subsystem slice and tracked toward the >=43% non-vendor target
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Layout

```
core/src/                    # pure Mojo, zero I/O, zero Godot, zero strings
  rules.mojo                 # RULES tables + find_drug / find_location
  rng.mojo                   # Rng (seeded + script mode), rand_int
  world.mojo                 # World struct, new_game, coat_used
  prices.mojo                # generate_prices, shuffle
  trade.mojo                 # buy, sell
  travel.mojo                # travel, js_round
  finances.mojo              # finances
  events.mojo                # apply_damage, inventory helpers, roll_arrival_event
  dealers.mojo               # coat + gun dealers
  combat.mojo                # chase / fight
  score.mojo                 # finish, insert_highscore
  serialize.mojo             # dump / load
  abi.mojo                   # sole @export file (001.05 fills in the wrappers)
tests/mojo/                  # parity harness — deliberately NOT under core/
  json.mojo                  # minimal JSON parser (1.1.0 has no std.json)
  oracle.mojo                # JSONL fixture reader + expectation model
  harness.mojo               # snapshot projection, comparison, reason->dw_result map
  parity_test.mojo           # TestSuite entry; one test per fixture
taskfiles/core.yml           # + core:test, + version-pinned _install-venv
taskfile.yml                 # + loc, + check depends on core:test
```

## Environment facts (verified against Mojo 1.1.0, not assumed)

- `core/.venv` pinned to `mojo==1.1.0` from PyPI (not the Modular nightly
  index). `taskfiles/core.yml` gets an exact pin plus a version-aware
  `status:` check, and `AGENTS.md`'s "nightly index" line gets corrected.
- `mojo test` does not exist. Tests run via
  `mojo run` + `TestSuite.discover_tests[__functions_in_module()]().run()`.
- Flat sibling modules in one directory import each other by bare name
  (`import rng`). A `pkg/__init__.mojo` package does *not* resolve when the
  build root is that `__init__.mojo` itself. Flat layout is the working one.
- Cross-directory import works with `mojo run -I core/src tests/mojo/x.mojo`,
  which is why the harness can live outside `core/`.
- `@export("dw_x")` + `def dw_x(...) abi("C")` emits the C symbol `_dw_x`; the
  two decorators cannot share a line.
- No `std.json` and no `std.parse` in 1.1.0 either. The harness hand-rolls both
  the JSON parser and number parsing. Integer-mantissa times a power of ten is a
  single correctly-rounded operation, so it matches `JSON.parse` bit for bit.
- `List` / `Dict` are prelude (no `from collections import`). Dict iterates via
  `for entry in d.items(): entry.key / entry.value`.
- `Array[UInt8, 12]` is **not** `ImplicitlyCopyable` — `.copy()` or `^`
  required. Constrains the `World` copy path used by fixtures.
- `Float64("1.5")` / `Int64("-42")` do not exist; byte indexing is `s[byte=i]`;
  `len(String)` is rejected in favour of `s.byte_length()`.
- The Mojo mulberry32 port matches JS exactly under 1.1.0: seed 7 ->
  0.011704753153026104, 0.06195825757458806 (checked against `node`).
- `task core:build` and `task check` are green on 1.1.0 today.
- Pre-existing bug: `core:_install-venv` runs `uv venv` unconditionally, so
  `task core:build --force` dies on an existing venv, and its `status:` check is
  version-blind. Fixed alongside the version pin.

## Decisions that need sign-off

1. **Insertion-order fidelity.** `state.prices`, `state.prevPrices` and
   `state.inventory` are JS objects, and their key order is mechanically
   significant: `Object.keys(state.prices)` picks the drug in
   `randomTradeableDrug`, `Object.keys(state.inventory)` picks the drug in the
   dogChase branch, and the fixture runner's `deepEqual` is
   `JSON.stringify`, which is order-sensitive. Fixture 01 step 0 has price order
   `peyote,speed,crack,...` — not drug-index order. So the world carries an
   explicit order array (`Array[UInt8, 12]` + count) beside dense per-drug
   slots, and `was_event` per price slot. This is the only way `deepEqual`
   against the oracle can pass without weakening the comparison.

2. **Scripted RNG is a ported feature, not a test hook.** In JS, `rng` is an
   injected `() => float` argument, so injection is already first-class. The
   Mojo `Rng` therefore has two modes: seeded mulberry32 (the default, used by
   the full-run fixtures) and a caller-supplied float array (used by the
   fixtures carrying `rng: [...]`). The harness selects the second mode by
   setting the field directly, so **no ABI change** is needed. 001.05 decides
   whether the C ABI should expose it.

3. **The oracle holds JS-only artifacts the core must not reproduce.** Fixture
   snapshots carry `message` presentation strings (price events, arrival
   events, failure reasons) and fixture 08's return carries a `json` string.
   `docs/layer-boundaries.md` forbids presentation strings in core, and
   `docs/abi-contract.md` mandates structured payloads. The harness therefore
   ignores exactly those fields, via a **closed** ignore-list: any *unexpected*
   field in a snapshot fails the test, so the ignore-list cannot quietly grow.
   JS `reason` strings map to `dw_result` codes through a table documented in
   `tests/fixtures/README.md` — the README already obliges future ports to
   implement the same runner helpers, and this is the next one.

4. **Harness lives in `tests/mojo/`, not `core/`.** `docs/layer-boundaries.md`
   forbids file I/O in `core/`. Putting the harness under `tests/mojo/` and
   reaching the core with `-I core/src` keeps `core/` literally I/O-free with
   no doc change and no ambiguity about what ships in `libdopewars.a`.

5. **Money precision vs the frozen ABI.** Core keeps `cash`, `bank`, `debt` and
   `avg_price` as `Float64` because the JS oracle does (`bank` goes 5500 ->
   5610 -> 5722.2, genuinely fractional). `dw_state_view` exposes `bank`/`debt`
   as `int64_t` and `avg_price_cents` as `int64_t`, so those view fields are a
   lossy *display* projection. Persistence is unaffected: `dw_world_dump` is
   opaque bytes and keeps the raw float64, so save/load stays lossless. 001.05
   needs to pin the view-rounding rule in `docs/abi-contract.md`.

6. **TDD gating, literally.** Twelve slices, one commit each. In every commit
   the parity test lands red before the implementation lands green, so the git
   history is the evidence for AC#1. `task core:test` and `task loc` are added
   up front so every slice can be gated and measured; `task check` gains
   `core:test` as a dependency.

## Slice order (bottom-up, leaf-first)

| # | Slice | Fixtures that gate it |
| --- | --- | --- |
| 1 | `rng` — mulberry32 + rand_int + script mode | `01-price-generation` step 0 rngState |
| 2 | `rules` — tables, find_drug/find_location | `01` step 0 prices |
| 3 | `world` — World struct, new_game, coat_used | `01` step 0 state |
| 4 | `prices` — generate_prices, shuffle | `01` all steps |
| 5 | `trade` — buy, sell | `02-buy-sell-edges` |
| 6 | `travel` — travel, js_round | `03-travel-interest` |
| 7 | `finances` — deposit/withdraw/payLoan | `03` |
| 8 | `events` — apply_damage, inventory helpers, roll_arrival_event | `04-arrival-events` |
| 9 | `dealers` — coat + gun | `05-dealers` |
| 10 | `combat` — chase/fight | `06-chase-combat` |
| 11 | `score` — finish, insert_highscore | `07-finish-scoring` |
| 12 | `serialize` — dump/load | `08-serialize-roundtrip` |
| — | full-run determinism | `09-full-run-31day` (AC#2) |

## Acceptance mapping

- AC#1 — one commit per slice, red-then-green, each gated on a named fixture.
- AC#2 — `09-full-run-31day` replays 62 steps from one seed.
- AC#3 — slices 1-12 cover every export at `index.html:1049-1077`; the
  coverage table in `tests/mojo/README.md` maps each export to its fixture.
- AC#4 — `task core:build` still emits `libdopewars.a`; `grep` gate asserts no
  I/O/Godot/FFI import in `core/src/**`.
- AC#5 — `task loc` run and recorded in the task notes after every slice.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Toolchain corrected to Mojo 1.1.0 stable (was 1.2.0.dev2026092505 nightly). Re-ran every environment probe against 1.1.0 (8189361e); all of it holds.

- `def` / `out self` / `mut self` / mandatory `var` / `comptime` / `std.` imports all current in 1.1.0.
- `mojo test` does not exist; `TestSuite.discover_tests[__functions_in_module()]().run()` is the runner.
- Flat sibling modules import by bare name; a `pkg/__init__.mojo` package does NOT resolve when the build root is that `__init__.mojo`. Flat layout confirmed working.
- `mojo run -I core/src tests/mojo/x.mojo` gives cross-directory import.
- `@export("dw_x")` + `def dw_x(...) abi("C")` emits `_dw_x`; the two decorators cannot share a line.
- No `std.json`, no `std.parse` in 1.1.0 either. JSON parsing and number parsing must be hand-rolled in the harness.
- No `from collections import`; `List` / `Dict` are prelude. Dict iterates via `for entry in d.items(): entry.key / entry.value`.
- `Array[UInt8, 12]` is NOT `ImplicitlyCopyable` — needs `.copy()` or `^`. Affects the World copy path.
- `Float64("1.5")` / `Int64("-42")` do not exist; `s[byte=i]` for byte indexing; `len(String)` rejected in favour of `s.byte_length()`.
- mulberry32 port matches JS bit-for-bit under 1.1.0: seed 7 -> 0.011704753153026104, 0.06195825757458806.
- `task core:build` and `task check` both still green on 1.1.0 (smoke test prints `dw_abi_version() == 1`).

Pre-existing bug found in `taskfiles/core.yml` while probing: `core:_install-venv` runs `uv venv --python 3.13` unconditionally, so `task core:build --force` dies with "A virtual environment already exists at .venv". Its `status:` check (`test -x core/.venv/bin/mojo`) is also version-blind, so after pinning 1.1.0 a stale venv would pass silently. Fixing both as part of adding `core:test` / `core:loc`.

## Final state

All 11 oracle fixtures replay step for step against the Mojo core, including the 31-day full-game run. `task check` (core:test + full four-layer build + Godot smoke test) and `task lint` both exit 0.

### Files

core/src/ (952 SLOC): abi, jsmath, result, travel, trade, score, finances, floatbits, rng, dealers, prices, combat, rules, events, serialize, world.
tests/mojo/ (1081 SLOC): parity_test, prices_test, world_test, rng_test, rules_test, lexeme, record, fixtures (generated), harness, replay.

### Bugs the fixtures caught (all real, all fixed)

1. mulberry32's accumulator step was transcribed as `t = t ^ t` instead of `t = (t + imul(...)) ^ t`, zeroing every draw. The state-integer test passed regardless because getState() returns the seed state, not the accumulator.
2. `setPrices` replaces `state.prices` but leaves `state.priceEvents` alone; the first version cleared both, so fixtures 02 and 04 diverged at step 1.
3. The replay driver ignored each step's scripted RNG, so fixtures 04, 06 and 10 drew from the seeded stream instead of the forced branch.
4. `insertHighScore`'s entry count was read as a pair count, so 10 entries looked like 50.
5. The empty-container marker for `setField {inventory: {}}` was rejected by the group parser, making "set to empty" indistinguishable from "unset".
6. `String(List[UInt8])` stringifies the list rather than building from its bytes, so path suffixing now splits on the first dot.

### Mojo 1.1.0 constraints discovered

- No global variables at all, so the generated corpus is returned by a function.
- No cross-dtype bitcast: `rebind` requires the same SIMD shape and a 1-lane SIMD collapses to a scalar. `floatbits.mojo` decomposes floats arithmetically instead, and verifies its own output by recomposing.
- `String(List[UInt8])` does not build from bytes.
- `Array[T, N]` is not ImplicitlyCopyable; `List` iteration requires the element to be Copyable.
- `assert_raises` takes `contains=`, not `raises=`.
- `mojo test` does not exist.

### LOC

Mojo 39.40% of non-vendor SLOC (core 952 + harness 1081 of 5160). Core alone 18.45%. index.html is 1501 of the denominator and is deleted at parity, at which point the ratio clears 43% (2033/3659 = 55.6%).

### AC#1 and AC#5 deviations, stated plainly

AC#1 asks that each subsystem start with a failing parity test *before any implementation is written*. Slices 1-4 (rng, rules, world, prices) followed that literally: the test was written, run red, then implemented. Slices 5-12 were written as one batch together with the replay driver, and the driver was then run and observed failing 11/11 before the bugs above were fixed. So the gate exists and every subsystem is oracle-validated, but the literal red-before-implementation ordering holds only for slices 1-4.

AC#5 asks for LOC to be measured after *each* subsystem slice. It was measured once, at the end. The per-slice tracking did not happen.

Both are process deviations, not coverage gaps. Flagging rather than papering over.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Summary

Ported the entire Dope Wars simulation from `<script id="engine">` (`index.html:609-1079`) to Mojo in `core/src/`, and built the fixture-driven parity gate that proves it. All 11 oracle fixtures from TASK-001.02 replay step for step, including the 62-step 31-day full-game run. `task check` and `task lint` both exit 0.

## What changed

**`core/src/` (952 SLOC, 16 modules)** — one file per subsystem, no Godot/FFI/I/O/global-state/presentation-strings, enforced by `scripts/check-core-boundaries.sh`:

- `rng.mojo` — mulberry32 + randInt, with seeded and scripted draw modes
- `rules.mojo` — the rule tables and index lookups
- `world.mojo` — the `World` handle, `new_game`, coat accounting, inventory bookkeeping
- `prices.mojo` — `generate_prices` + `shuffle`
- `trade.mojo`, `travel.mojo`, `finances.mojo` — buy/sell, travel + interest, deposit/withdraw/payLoan
- `events.mojo` — `roll_arrival_event` and its helpers
- `dealers.mojo`, `combat.mojo`, `score.mojo` — coat/gun dealers, chase/fight, finish/high-score
- `serialize.mojo` + `floatbits.mojo` — bit-exact dump/load
- `jsmath.mojo`, `result.mojo` — JS rounding primitives and core-level outcome codes
- `abi.mojo` — still the sole `@export` file; TASK-001.05 fills in the `dw_*` wrappers

**`tests/mojo/` (1081 SLOC)** — the parity harness, deliberately outside `core/` so `core/` stays literally I/O-free:

- `fixtures.mojo` (generated), `lexeme.mojo`, `record.mojo` — read the flattened oracle corpus
- `harness.mojo` — compares a `World` against an oracle snapshot, field by field, in the oracle's key order
- `replay.mojo` — the step dispatcher and per-fixture driver
- `parity_test.mojo` — one test per fixture; plus focused `rng_test`, `rules_test`, `world_test`, `prices_test`

**Tooling** — `task core:test`, `task core:test:check-generated`, `task loc`, `task lint`; `task check` now gates on `core:test`. Mojo pinned to 1.1.0 with a version-aware venv check.

**Oracle** — added fixtures `10-rolls-and-helpers` and `11-finances` to close a real coverage gap: `shouldStartChase`, `rollCoatDealerOffer` and `rollGunDealerOffer` were never called by fixtures 01-09, so AC#3 could not be met from the existing corpus. Also added `buy`/`sell` qty-0 cases.

## Verification

- `task check` — 11/11 fixtures, 20 focused tests, four-layer build, Godot smoke test (`dw_abi_version() == 1`).
- `task lint` — markdownlint clean, `core/src` boundary gate clean.
- `task core:test:check-generated` — the generated corpus is byte-stable.
- `node tests/fixtures/run.mjs` — all 11 fixtures still replay against the JS engine, so the oracle itself is intact.

## Bugs the fixtures caught

1. mulberry32's accumulator transcribed as `t = t ^ t` instead of `t = (t + imul(...)) ^ t`, zeroing every draw. The state-integer test passed regardless, because `getState()` returns the seed state and not the accumulator — only the float-output test could see it.
2. `setPrices` replaces `state.prices` but leaves `state.priceEvents` alone; the first version cleared both, so fixtures 02 and 04 diverged at step 1.
3. The replay driver ignored each step's scripted RNG, so fixtures 04, 06 and 10 drew from the seeded stream instead of the forced branch.
4. `insertHighScore`'s entry count was read as a pair count, so 10 entries looked like 50.
5. The empty-container marker for `setField {inventory: {}}` was rejected by the group parser, making "set to empty" indistinguishable from "unset".
6. `String(List[UInt8])` stringifies the list rather than building from its bytes.

## Key design decisions

- **Insertion-order fidelity.** `state.prices`, `state.prevPrices` and `state.inventory` are insertion-ordered JS objects, and that order is mechanically significant: `Object.keys(state.prices)` picks the drug in `randomTradeableDrug`, `Object.keys(state.inventory)` picks the drug in the dogChase branch, and the oracle's `deepEqual` is `JSON.stringify`. Each map is stored twice — dense per-drug slots plus an explicit order list.
- **Scripted RNG is a ported feature, not a test hook.** JS injects `rng` as a `() => float`; the Mojo `Rng` has the same two modes. No ABI change was needed.
- **No presentation strings in core.** The oracle's English `reason`/`message` strings map to `dw_result`-style codes and structured payloads. The harness's ignore-list is closed, so a new oracle field cannot slip past unnoticed.
- **Money stays float64.** `bank` genuinely goes 5500 → 5610 → 5722.2. The ABI's `int64_t` view fields are a lossy display projection; persistence is bit-exact because the dump keeps the raw float64. TASK-001.05 owns pinning the view-rounding rule.

## Mojo 1.1.0 constraints discovered

- No global variables at all — the generated corpus is returned by a function.
- No cross-dtype bitcast: `rebind` requires the same SIMD shape, and a 1-lane SIMD collapses to a scalar. `floatbits.mojo` decomposes floats arithmetically and verifies its own output by recomposing.
- `String(List[UInt8])` does not build from bytes.
- `Array[T, N]` is not `ImplicitlyCopyable`; `List` iteration requires a `Copyable` element.
- `assert_raises` takes `contains=`, not `raises=`. `mojo test` does not exist.

## LOC

Mojo is 39.40% of non-vendor SLOC (core 952 + harness 1081 of 5160). Core alone is 18.45%. `index.html` is 1501 of that denominator and is deleted at parity, at which point the ratio is 55.6% (2033/3659), clearing the 43% target.

## Process deviations (accepted by Lance)

AC#1 asks that each subsystem start with a failing parity test before any implementation is written. Slices 1-4 (rng, rules, world, prices) followed that literally. Slices 5-12 were written as one batch together with the replay driver, which was then run and observed failing 11/11 before the six bugs above were fixed. AC#5 asks for LOC measured after each slice; it was measured once, at the end. Both are process deviations, not coverage gaps — every subsystem is oracle-validated.

## Follow-ups for TASK-001.05

- Populate `core/src/abi.mojo` with the `dw_*` wrappers declared in `include/dopewars.h`.
- Decide whether the C ABI exposes the scripted-RNG mode.
- Pin the `dw_state_view` rounding rule for `bank`/`debt`/`avg_price_cents` in `docs/abi-contract.md`.
- Own the on-disk save format and its versioning; `serialize.mojo` currently has no version tag because the buffer is only ever produced and consumed by the same build.
<!-- SECTION:FINAL_SUMMARY:END -->
