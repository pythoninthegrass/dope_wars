---
id: TASK-010.02.10
title: Match Beermat average cost integer division
status: Done
assignee:
  - claude
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 18:59'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
priority: low
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-12 in docs/beermat-re.md (decompile at 0x0045e448). The real game keeps the average cost per drug as an integer: avg = (qty*price + held*avg) div (held + qty). The engine keeps a float average. Display-only, since selling uses the market price, but the value shown in the coat table differs. Interacts with the arrival-event subtask, where free drugs dilute the average with the same integer division.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Average cost is an integer computed with truncating division on buy, with a failing test first
- [x] #2 Fixtures regenerated and task core:test passes
- [x] #3 docs/beermat-re.md marks M-12 as match
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a failing test in tests/engine.test.mjs asserting buy() truncates the weighted-average cost to an integer (e.g. a second buy at a price that produces a non-integer mean).
2. index.html buy(): `held.avgPrice = Math.floor(totalCost / held.qty)` (was plain float division).
3. core/src/trade.mojo buy(): compute the new average with `jsmath.js_floor` the same way `_receive_drugs` in events.mojo already does, instead of a plain float divide.
4. Run `node --test tests/engine.test.mjs` to confirm the new test passes and nothing else regresses.
5. Regenerate fixtures: `node tests/fixtures/generate.mjs`, then `task core:test` to replay them against the Mojo core.
6. Update docs/beermat-re.md: flip M-12's row/entry from mismatch to match.
No material design decision here — straightforward integer-truncation port matching the existing `_receive_drugs` pattern.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added a failing test (tests/engine.test.mjs: 'buy truncates the weighted-average cost to an integer') confirming float avgPrice (100.4) before the fix.

index.html buy(): held.avgPrice now Math.floor(totalCost / held.qty).

core/src/trade.mojo buy(): new average computed via jsmath.js_floor, matching the pattern events.mojo:_receive_drugs already used for arrival-event dilution.

Regenerated tests/fixtures/*.jsonl (node tests/fixtures/generate.mjs) and tests/mojo/fixtures.mojo (node tests/fixtures/gen-mojo.mjs); only 09-full-run-31day.jsonl/.mojo changed, since it's the only fixture with a second buy at a different price producing a non-integer mean.

node --test tests/engine.test.mjs: 108/108 pass. task core:test: all 12 parity suites pass (12/12), plus prices/rng/rules/world suites unaffected.

docs/beermat-re.md: M-12 flipped from mismatch to match in both the drug-table row and the mismatch index.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed mismatch M-12: Beermat computes a drug's average cost as a truncating integer division ((qty*price + held*avg) div (held+qty)), while the engine kept a float average.

Changes:
- `index.html` `buy()`: `held.avgPrice = Math.floor(totalCost / held.qty)` instead of plain float division.
- `core/src/trade.mojo` `buy()`: new average now computed with `jsmath.js_floor`, mirroring the existing `_receive_drugs` dilution logic in `core/src/events.mojo` (which already matched Beermat for the arrival-event gift-drug case).
- `docs/beermat-re.md`: M-12 marked match in the "Buying" rules table and the mismatch index.

Tests:
- Added a failing-first test in `tests/engine.test.mjs` that buys at two different prices and asserts the resulting avgPrice truncates (100.4 → 100); confirmed it failed before the fix.
- Regenerated the JS fixture corpus (`tests/fixtures/*.jsonl`) and the generated Mojo fixture source (`tests/mojo/fixtures.mojo`); only `09-full-run-31day` changed, since it's the only existing fixture where a second buy at a different price yields a non-integer mean.
- `node --test tests/engine.test.mjs`: 108/108 pass.
- `task core:test`: all parity suites pass, including `test_09_full_run_31day` which exercises the changed average.

No ABI or serialization format change: `avg_price_cents` in the C ABI is still `Int64(avg_price * 100.0)`; it now always yields a multiple of 100 rather than arbitrary cents, which is the intended, more-correct behavior.
<!-- SECTION:FINAL_SUMMARY:END -->
