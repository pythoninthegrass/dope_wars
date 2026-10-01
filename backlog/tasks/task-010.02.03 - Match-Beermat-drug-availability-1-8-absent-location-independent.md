---
id: TASK-010.02.03
title: 'Match Beermat drug availability (1/8 absent, location independent)'
status: Done
assignee: []
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 06:49'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-03 in docs/beermat-re.md (decompile at 0x0045d120). The real game removes each drug independently with probability 1/8 on every arrival, the same at every location. The engine instead picks a per-borough subset size (minDrugs..maxDrugs). Decision recorded by Lance: per-borough drug counts are a rule, not part of the intentional location model. Remove the per-location minDrugs/maxDrugs from the engine and core, and update anything (ABI rules accessors, UI) that exposes them.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Each drug is unavailable with probability 1/8 independently of location, with a failing test first
- [x] #2 Per-location drug count fields are removed from the engine, core and any ABI surface; DW_ABI_VERSION bumped if the change is breaking
- [x] #3 Selling an unavailable drug is still refused
- [x] #4 Fixtures regenerated and task check passes
- [x] #5 docs/beermat-re.md marks M-03 as match
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Failing engine tests for 1-in-8 availability, 0 to 12 drugs, draw order, unavailable sell refused.
2. Implement in index.html: per-drug availability roll after price roll, spike and crash rolls still drawn for absent drugs; drop minDrugs/maxDrugs and shuffle.
3. Mirror in core/src/prices.mojo and rules.mojo; remove min/max_drugs from dw_location_view (80 to 68 bytes); bump ABI to v4 and propagate.
4. Regenerate fixtures and bridge expectations; fix seed-dependent tests; run task check.
5. Update docs/beermat-re.md and ABI docs.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Per-drug draw order follows 0x0045d120: price, availability Random(8), spike Random(20) if flagged (Random(2) pick only on an available hit), crash Random(20) if flagged; the spike and crash rolls are drawn even for an absent drug. Absent drugs are simply omitted from prices, so sell and buy refuse them. ABI v4: dw_location_view drops min_drugs, max_drugs, _pad0 (80 -> 68 bytes); dump length unchanged. Seed-dependent tests updated: abitest deputies for seed 7 (3 -> 11, checked against the JS oracle), ui_flow_test click case now uses the cheapest traded drug. random_tradeable_drug already returns -1/null on an empty market.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Each drug is now independently absent with probability 1/8 on every arrival and at new game, at every location (M-03 match). Removed minDrugs/maxDrugs and the shuffle from the engine and core, removed min_drugs/max_drugs from dw_location_view, bumped DW_ABI_VERSION to 4. Fixtures regenerated; task check passes.
<!-- SECTION:FINAL_SUMMARY:END -->
