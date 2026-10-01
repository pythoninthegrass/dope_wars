---
id: TASK-010.02.08
title: Match Beermat interest rounding
status: Done
assignee: []
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 07:43'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-10 in docs/beermat-re.md (decompile at 0x0045e3a4 and 0x0045e3d4, constants 1.05 and 1.1). The real game, once per day advance and only when the balance is above 0, sets bank = Round(bank * 1.05) and debt = Round(debt * 1.1) with round-to-nearest, ties-to-even (x87 FISTP). The engine rounds debt with Math.round (ties up) and leaves bank as a fractional float. Oracle evidence: debt 6655 became 7320, not 7321. Bank balances become whole dollars.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Debt and bank interest both round ties-to-even to whole dollars, with failing tests first including the 6655 -> 7320 case
- [x] #2 Interest is skipped when the balance is 0 or less
- [x] #3 Fixtures regenerated and task check passes
- [x] #4 docs/beermat-re.md marks M-10 as match
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify the binary: both handlers skip at balance <= 0 (JLE), multiply in x87 extended with extended-precision constants, round via FISTP.
2. Failing tests first: engine.test.mjs (6655 -> 7320, bank ties, skip at <= 0) and tests/mojo/interest_test.mojo.
3. Implement exact integer interest in index.html and core/src/interest.mojo (debt*11/10 ties-to-even; bank*105/100 with the extended 1.05 constant sitting below 1.05, which rounds some ties down).
4. Regenerate fixtures, update docs (M-10 match), run task check, merge.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Binary verified at 0x0045e3a4 and 0x0045e3d4: CMP [balance],0; JLE skips zero and negative; FILD, FLD of an 80-bit constant, FMULP, Round (FISTP). Float64 cannot reproduce it (Float64 6655*1.1 rounds up to 7321). Debt uses exact integer debt*11/10 ties-to-even. Bank cannot use plain ties-to-even: the extended 1.05 is below 1.05, so some .5 ties (for example 30 -> 31.5) are stored one ulp low and round down; the rule 4*bank > 5*2^k captures it. Both validated against an exact emulation of the extended product (2M consecutive balances plus random up to 2^31). Layout unchanged (bank stays Float64, whole valued), but dw_travel's observable result changes, so ABI bumped to v9 per docs/abi-contract.md policy. UI already formats bank as an int.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Debt and bank interest now round to whole dollars with x87-equivalent ties-to-even and are skipped at a balance of 0 or less, in index.html and core/src/interest.mojo. Tests added first (engine.test.mjs, tests/mojo/interest_test.mojo), fixtures 03 and 09 regenerated, ABI bumped to v9, docs/beermat-re.md marks M-10 as match. task check passes.
<!-- SECTION:FINAL_SUMMARY:END -->
