---
id: TASK-001.02
title: Build deterministic JS oracle fixtures from current engine
status: Done
assignee:
  - claude
created_date: '2026-09-26 04:33'
updated_date: '2026-09-26 05:24'
labels:
  - parity
  - migration
  - testing
milestone: m-0
dependencies: []
references:
  - ~/git/jumpnbump/tests/corpus/README.md
  - ~/git/jumpnbump/core/game_loop_difftest.zig
documentation:
  - index.html
  - tests/engine.test.mjs
parent_task_id: TASK-001
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Produce a seed-stable golden-fixture corpus from the existing `<script id="engine">` (lines 609-1079 of `index.html`) by extending `tests/engine.test.mjs`. These fixtures become the authoritative oracle that every Mojo port slice is validated against — any Mojo implementation that reproduces every fixture is considered at parity.

The corpus should cover all paths that carry behavioral risk: price event probabilities, inventory accounting edge cases, interest compounding, the full arrival-event roll table (mugged/freeDrugs/dogChase/foundDrugs/mamasBrownies/freeWeedDeath/flavor/none), both dealer purchase paths (cash and bank+fee), each combat outcome, serialization fidelity, and the 31-day full-game golden run.

Pattern reference: `~/git/jumpnbump/core/` differential-test JSONL input-trace corpus and `~/git/jumpnbump/tests/corpus/`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Golden fixtures cover all major engine subsystems: price generation, buy/sell, travel (day advancement, 10% debt compounding, 2% bank interest), all rollArrivalEvent outcome types, coat and gun dealer accept/reject paths, chase/combat (hit/miss/run/escape), finish scoring, and serializeState/deserializeState round-trip
- [x] #2 Each fixture encodes: seed, ordered input sequence (function name + arguments), and expected output (return value and/or post-call state snapshot) so any implementation can replay it
- [x] #3 A fixture runner script (Node.js or shell) can validate all fixtures against the current JS engine in one command and exits non-zero on any mismatch
- [x] #4 Fixtures are stored as structured data (JSONL or JSON array) under tests/fixtures/ so a future Mojo parity harness can consume the same files
- [x] #5 Fixture generation and extension workflow is documented in tests/fixtures/README.md
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Plan

Build seed-stable JSONL golden fixtures + runner validating them against the current JS engine in `<script id="engine">` (index.html:609-1079), so a future Mojo port can replay identical traces.

### Format
- `tests/fixtures/*.jsonl` — one JSON object per line = one engine call:
  `{"step": N, "call": "fnName", "args": {...}, "rng": [floats?], "expect": {"return": ..., "state": ...}}`
- `tests/fixtures/*.meta.json` — seed, description, mechanic exercised.
- State snapshots strip `state.rng` (function, not serializable) and record all other fields.
- Scripted-RNG traces pass an explicit float array; full-run traces use `mulberry32(seed)` stored on `state.rng` and let the engine consume it.

### Fixtures
1. `01-price-generation.jsonl` — N `generatePrices` calls, snapshot `state.prices`.
2. `02-buy-sell-edges.jsonl` — overflow, unaffordable, non-tradeable, partial sells.
3. `03-travel-interest.jsonl` — multi-day travel; verify 10% debt / 2% bank compounding.
4. `04-arrival-events.jsonl` — every branch of rollArrivalEvent via scripted RNG (mugged w/ cash, mugged $0, freeDrugs, freeDrugs-full-coat, dogChase, foundDrugs, mamasBrownies, freeWeedDeath, flavor, none).
5. `05-dealers.jsonl` — coat + gun offers: cash path, bank+25% fee path, insufficient path.
6. `06-chase-combat.jsonl` — startChase w/ + w/o guns; runFromChase escape/fail/aggressor; fight hit/miss/won/killed-last-deputy.
7. `07-finish-scoring.jsonl` — finish() outputs + insertHighScore top-10 truncation.
8. `08-serialize-roundtrip.jsonl` — serialize→deserialize deep-equal.
9. `09-full-run-31day.jsonl` — 31-day playthrough, deterministic policy (travel to `locations[day % 6]`, buy cheapest-fill-coat, sell-all on arrival), driven by `mulberry32(seed)`.

### Runner & generator
- `tests/fixtures/generate.mjs` — scripts describe input sequence + rng plan; runs engine, captures returns/state, writes JSONL + meta.
- `tests/fixtures/run.mjs` — replays each fixture through a fresh engine load, deep-equals return + state on every step. Non-zero exit on any mismatch. Also wired into `tests/engine.test.mjs` as a describe block.
- `tests/fixtures/README.md` — format, generator workflow, adding new fixtures.

### Acceptance mapping
- AC#1 → fixtures 1-9
- AC#2 → each JSONL line carries seed(meta) + call + args + expect{return,state}
- AC#3 → `node tests/fixtures/run.mjs`
- AC#4 → JSONL under `tests/fixtures/`
- AC#5 → `tests/fixtures/README.md`
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Files added

- `tests/fixtures/engine-loader.mjs` — shared engine loader (extracts `<script id="engine">` via node:vm), scripted-RNG helper, and state snapshotter (strips `state.rng` closure, records the mulberry32 integer as `rngState`).
- `tests/fixtures/run-step.mjs` — shared dispatch table mapping fixture step calls to engine functions and runner helpers (`setPrices`, `setInventory`, `setField`, `buyCheapest`, `insertHighScores`, `serializeRoundTrip`). Used by generator, standalone runner, and node:test harness so all three share one execution path.
- `tests/fixtures/generate.mjs` — declarative fixture scripts + generator. Regenerate with `node tests/fixtures/generate.mjs`.
- `tests/fixtures/run.mjs` — standalone runner. `node tests/fixtures/run.mjs [filter…]` replays every fixture and exits non-zero on any mismatch.
- `tests/fixtures/README.md` — format, coverage table, regeneration workflow, how to add a new fixture.
- Nine fixture pairs (`*.jsonl` + `*.meta.json`) covering price generation, buy/sell edges, travel/interest, all rollArrivalEvent branches, both dealer paths (cash and bank+25% fee), chase/combat outcomes, finish + insertHighScore, serialize round-trip, and a 31-day full-run playthrough.
- `tests/engine.test.mjs` extended with a `describe('fixture corpus', …)` block that replays every `.jsonl` under `node --test`.

## Determinism verified

- `shasum tests/fixtures/*.jsonl` is byte-identical across repeated `generate.mjs` runs.
- Mutation of a fixture value (e.g. changing `debt:6050` to `debt:9999`) makes the runner exit 1 with a clear step + kind + diff preview; restoring the file makes it pass again.

## Snapshot design decisions

- Full state snapshot per step (uniform, jumpnbump-style), not deltas. Total corpus is well under a few hundred KB.
- `state.rng` is a closure so it is stripped from snapshots; the mulberry32 internal integer is recorded as `rngState`, matching `serializeState`. This makes snapshots language-agnostic — a Mojo port just needs to seed mulberry32 identically and expose `getState`.
- Scripted RNG (`rng: [floats]`) is used only where an exact branch must be forced (arrival events, combat outcomes). Full-run and price-generation fixtures use the seeded `state.rng` so they exercise the real RNG stream.

## Test results

`node --test tests/engine.test.mjs`: 56 tests pass (47 pre-existing + 9 fixture replays).

## Follow-ups (out of scope for this task)

None required for the JS oracle. When Mojo layers land, each layer's parity harness re-uses these JSONL files verbatim; it will need to implement the same runner-helper dispatch (`setPrices`, `setField`, etc.) documented in `tests/fixtures/README.md`.

Generated 9 fixtures totaling 161 steps. All replay identical under both `node tests/fixtures/run.mjs` and `node --test tests/engine.test.mjs`. Byte-stable across regeneration. Runner correctly exits 1 on injected mismatch.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Summary

Established the JS engine golden-oracle corpus for TASK-001 parity validation. Every future implementation of the Dope Wars engine (Mojo core in TASK-001.03+, GDScript UI, etc.) is validated by replaying these fixtures — reproducing every recorded return value and state snapshot means parity with the shipped `<script id="engine">` in `index.html`.

## What changed

- Added `tests/fixtures/` with a shared engine loader (`engine-loader.mjs`), a shared step dispatch (`run-step.mjs`), a declarative generator (`generate.mjs`), a standalone runner (`run.mjs`), and a README documenting format, coverage, and workflow.
- Recorded 9 fixture pairs (161 steps total): price generation, buy/sell edges, travel + interest compounding, every rollArrivalEvent branch, both dealer paths (cash and bank+25%), chase/combat outcomes, finish + high-score truncation, serialize round-trip, and a 31-day full-run playthrough.
- Wired fixture replay into `tests/engine.test.mjs` so `node --test tests/engine.test.mjs` covers the corpus automatically.

## Format

Each `.jsonl` line: `{ step, call, args, rng?, expect: { return, state } }`. State snapshots strip the `state.rng` closure and record the mulberry32 integer as `rngState` (matches `serializeState`), making the snapshots language-agnostic.

## Verification

- All 56 tests pass under `node --test tests/engine.test.mjs` (47 pre-existing + 9 fixture replays).
- `node tests/fixtures/run.mjs` replays all 9 fixtures, exits 0.
- `shasum tests/fixtures/*.jsonl` is byte-identical across repeated `generate.mjs` runs (deterministic).
- Injected mutations (e.g. flipping `debt:6050` → `debt:9999`) make the runner exit 1 with a clear diff; restoring the file makes it pass.
- Markdownlint clean on the README.

## Risks / follow-ups

- Regenerating fixtures after intentional engine changes is a deliberate, reviewed step — the README explicitly warns against reflexive regeneration.
- A Mojo/GDScript replay harness needs to implement the same handful of runner helpers (`setPrices`, `setInventory`, `setField`, `buyCheapest`, `insertHighScores`, `serializeRoundTrip`) documented in `tests/fixtures/README.md`. This is called out in the README and is expected work for TASK-001.03+.
<!-- SECTION:FINAL_SUMMARY:END -->
