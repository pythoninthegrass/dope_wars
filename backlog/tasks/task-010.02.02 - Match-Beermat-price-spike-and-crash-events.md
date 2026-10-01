---
id: TASK-010.02.02
title: Match Beermat price spike and crash events
status: Done
assignee: []
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 06:41'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-02 in docs/beermat-re.md (decompile at 0x0045d120). Replace the engine's 70%/40%/5% event-count scheme with the real per-drug rule: for each available drug that carries the spike flag, a 1-in-20 chance multiplies the price by 5, with the message chosen 50/50 between "Cops made a big <drug> bust!  Prices are outrageous!" and "Addicts are buying <drug> at outrageous prices!"; for each available drug with the crash flag, a 1-in-20 chance divides the price by 10 (integer division) with a fixed message per drug (acid, hashish, ecstasy, weed). Depends on the drug table subtask for the flags.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Spike is x5 and crash is integer div 10, each at 1 in 20 per flagged, available drug, with failing tests first
- [x] #2 Spike and crash messages match the strings in docs/beermat-re.md
- [x] #3 Fixtures regenerated and task core:test passes
- [x] #4 docs/beermat-re.md marks M-02 as match
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Failing tests first: engine.test.mjs (x5 / div 10, 1-in-20, messages, 50/50 bust text) and tests/mojo (rules constants, forced-roll price tests).
2. Implement in index.html generatePrices and core/src/prices.mojo; add DW_PRICE_EVENT_BUST, grow MAX_PRICE_EVENTS to 8, bump DW_ABI_VERSION to 3 (RNG draw order).
3. Per-drug crash text through tr() keys in game/; regenerate fixtures and bridge expectations.
4. Update docs/beermat-re.md (M-02 match, crash strings) and docs/abi-contract.md; run task check.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Engine now picks the traded set first (shuffle, first N drugs), then per traded drug in drug-index order rolls price, spike (randInt 0..19 == 0, x5, then randInt 0..1 for bust vs addicts text) and crash (randInt 0..19 == 0, integer div 10). Beermat rolls spike and crash before the availability check, so RNG draw order still differs until M-03 (TASK-010.02.03). Event types: cheap (crash), expensive (spike, addicts text), bust (spike, cops text, new DW_PRICE_EVENT_BUST = 2). MAX_PRICE_EVENTS 3 -> 8, dump 766 -> 846 bytes, DW_ABI_VERSION 2 -> 3. Crash text is per drug via tr() keys MSG_PRICE_CRASH_<ID>. Existing seed-dependent tests (abitest, test_bridge.gd, ui_flow_test floors) adjusted to the new rosters.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
M-02 matched: x5 spike and div-10 crash at 1 in 20 per traded flagged drug, bust/addicts spike messages 50/50, per-drug crash messages. ABI bumped to v3 (new DW_PRICE_EVENT_BUST, MAX_PRICE_EVENTS 8, dump 846 bytes). Fixtures regenerated; task check passes.
<!-- SECTION:FINAL_SUMMARY:END -->
