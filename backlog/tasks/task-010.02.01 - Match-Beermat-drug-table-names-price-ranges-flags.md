---
id: TASK-010.02.01
title: 'Match Beermat drug table (names, price ranges, flags)'
status: Done
assignee: []
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 06:30'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-01 in docs/beermat-re.md. The engine's drug table (index.html RULES.drugs, mirrored in core/src/rules.mojo) differs from the real game's table decoded at 0x0045c260. Bring the engine and core to the Beermat min/max ranges and crash/spike flags listed in the "Drug records" table of docs/beermat-re.md (price = Random(spread+1) + min, so max = min + spread). Only the data changes here; the spike/crash mechanics are M-02.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All 12 drugs use the Beermat min and max from docs/beermat-re.md, with a failing test written first
- [x] #2 Crash and spike flags per drug match the Beermat table (the multipliers themselves are out of scope, see the price events subtask)
- [x] #3 tests/fixtures are regenerated from the JS oracle and task core:test passes
- [x] #4 docs/beermat-re.md marks M-01 as match
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Failing tests: Beermat drug table in engine.test.mjs and tests/mojo/rules_test.mojo. 2. Update index.html RULES.drugs and core/src/rules.mojo (crash -> cheap, spike -> expensive, data only). 3. Regenerate fixtures, run core:test and task check. 4. Mark M-01 match in docs/beermat-re.md.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Kept the existing cheap/expensive flags as the crash/spike representation (no ABI struct change, no DW_ABI_VERSION bump): the drug-table data change alters no signature, layout or RNG draw order. Drug order stays alphabetical. Speed lost its cheap flag; Smack lost expensive; Ecstasy gained cheap. M-02 can rename or re-key the flags.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All 12 drugs use the Beermat min/max and crash/spike flags in index.html and core/src/rules.mojo. Fixtures regenerated (byte-identical on rerun), engine tests, core:test and task check pass. docs/beermat-re.md marks M-01 as match.
<!-- SECTION:FINAL_SUMMARY:END -->
