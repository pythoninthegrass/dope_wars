---
id: TASK-013.02.19
title: Bank interest 2.1 rounding
status: To Do
assignee: []
created_date: '2026-10-13 05:13'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.01
documentation:
  - docs/beermat-2.1-re.md
  - docs/beermat-re.md
parent_task_id: TASK-013.02
ordinal: 79000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bank interest in 2.1 is `bank += Round(bank * (5 / 100.0))`, only above 0 (docs/beermat-2.1-re.md, "Interest", N-33). The rate is built as a double, so an exact .5 tie lands a hair above and rounds up; 1.2's ties-to-even and extended-precision `1.05` analysis (docs/beermat-re.md, "Interest arithmetic") do not carry over. Observed on a running 2.1: bank 30 becomes 32 and 50 becomes 53 (1.2 gave 31 and 52); 1,050 becomes 1,103. Replace `interest.bank_after_interest` and the Mojo tests that pin the 1.2 ties (`interest_test.mojo`). Debt interest is not in scope: it is per loan and belongs to the loan shark slices (TASK-013.02.04).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 interest.bank_after_interest follows Round(bank * 0.05) with the 2.1 tie behaviour and skips balances of 0 or below
- [ ] #2 test_pending_n33_bank_interest_ties_round_up in tests/mojo/pending_2_1_test.mojo is un-skipped and passes
- [ ] #3 interest_test.mojo no longer pins the 1.2 bank ties, and fixture 03's kept steps (bank 1050 and 70) still pass
- [ ] #4 task core:test and task check are green
<!-- AC:END -->
