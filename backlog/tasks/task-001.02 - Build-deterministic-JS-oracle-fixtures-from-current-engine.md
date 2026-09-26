---
id: TASK-001.02
title: Build deterministic JS oracle fixtures from current engine
status: To Do
assignee: []
created_date: '2026-09-26 04:33'
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
- [ ] #1 Golden fixtures cover all major engine subsystems: price generation, buy/sell, travel (day advancement, 10% debt compounding, 2% bank interest), all rollArrivalEvent outcome types, coat and gun dealer accept/reject paths, chase/combat (hit/miss/run/escape), finish scoring, and serializeState/deserializeState round-trip
- [ ] #2 Each fixture encodes: seed, ordered input sequence (function name + arguments), and expected output (return value and/or post-call state snapshot) so any implementation can replay it
- [ ] #3 A fixture runner script (Node.js or shell) can validate all fixtures against the current JS engine in one command and exits non-zero on any mismatch
- [ ] #4 Fixtures are stored as structured data (JSONL or JSON array) under tests/fixtures/ so a future Mojo parity harness can consume the same files
- [ ] #5 Fixture generation and extension workflow is documented in tests/fixtures/README.md
<!-- AC:END -->
