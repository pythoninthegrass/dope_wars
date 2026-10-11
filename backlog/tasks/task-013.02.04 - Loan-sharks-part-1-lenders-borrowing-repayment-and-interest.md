---
id: TASK-013.02.04
title: 'Loan sharks part 1: lenders, borrowing, repayment and interest'
status: To Do
assignee: []
created_date: '2026-10-11 04:02'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.01
documentation:
  - docs/beermat-2.1-re.md
  - docs/abi-contract.md
parent_task_id: TASK-013.02
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
1.2 has a single debt (5,500 at 10% a day, `debt` in the core). 2.1 replaces this with loan sharks: the Finances form lists lenders, each offering a rate, a duration and an amount; the player borrows from a selected shark, sees "Outstanding Loans" with days left, repays a selected loan, and total debt is capped at 1,000,000. The start state still reads $2,000 cash and $5,500 debt, so the opening debt must become a loan whose terms come from the findings. Replace the single-debt model in the core with a loan list (lender, principal, rate, due date), update interest and score (`cash + bank - debt`) to sum over loans, and rebuild the Finances dialog loan section. Save format changes are fine but must round-trip.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The core holds a list of loans, each with lender, balance, rate and days left, and the opening 5,500 debt is one of them per the findings
- [ ] #2 Borrowing from an offered shark, repaying a chosen loan, per-day interest and the 1,000,000 total-debt cap behave as documented in docs/beermat-2.1-re.md
- [ ] #3 Score and net worth sum over all loans
- [ ] #4 Lender offers are generated and refreshed as the findings specify
- [ ] #5 The Finances dialog lists offers and outstanding loans, covered by game:ui-test
- [ ] #6 Mojo tests cover borrow, repay, cap and interest; dump, load and dump is byte identical
- [ ] #7 docs/abi-contract.md and docs/architecture.md describe the loan state and ABI additions
<!-- AC:END -->
