---
id: TASK-010.02.04
title: Match Beermat chase start chance (flat 1 in 6)
status: Done
assignee: []
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 06:54'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-04 in docs/beermat-re.md (decompile at 0x0045d428). In the real game each travel starts a chase with Random(6) == 0, the same at every location, and a chase replaces the arrival events and dealer visits for that travel (they are mutually exclusive). The engine weights the chance by a per-borough police value. Decision recorded by Lance: per-borough police weights are a rule, not part of the intentional location model. Remove them and make chase and arrival events exclusive.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A chase starts with probability 1/6 at every location, with a failing test first
- [x] #2 When a chase starts, no arrival event and no dealer visit is rolled for that travel
- [x] #3 Per-location police fields are removed from the engine, core and any ABI surface; DW_ABI_VERSION bumped if breaking
- [x] #4 Fixtures regenerated and task check passes
- [x] #5 docs/beermat-re.md marks M-04 as match
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Failing engine tests for flat 1/6 chase and no police field. 2. Engine, Mojo core and ABI v5 (location view loses police). 3. Regenerate fixtures and bridge expectations. 4. Docs, task check.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Chase/arrival exclusivity already held in index.html runArrivalSequence and game/presentation/arrival_flow.gd (which consults dw_should_start_chase), so no flow change was needed. RNG draw order is unchanged: should_start_chase is still one draw; prices are still rolled inside travel before the chase check (not a listed mismatch). ABI v5: dw_location_view 68 -> 64 bytes.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Chase start is Random(6)==0 at every location in the JS engine and Mojo core. Police field removed from RULES, core Location, dw_location_view and the extension/GDScript surfaces. ABI bumped to 5. Fixtures and bridge expectations regenerated; task check passes.
<!-- SECTION:FINAL_SUMMARY:END -->
