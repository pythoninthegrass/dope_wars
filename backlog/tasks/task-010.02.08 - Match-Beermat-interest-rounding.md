---
id: TASK-010.02.08
title: Match Beermat interest rounding
status: To Do
assignee: []
created_date: '2026-10-01 06:17'
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
- [ ] #1 Debt and bank interest both round ties-to-even to whole dollars, with failing tests first including the 6655 -> 7320 case
- [ ] #2 Interest is skipped when the balance is 0 or less
- [ ] #3 Fixtures regenerated and task check passes
- [ ] #4 docs/beermat-re.md marks M-10 as match
<!-- AC:END -->
