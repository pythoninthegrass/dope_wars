---
id: TASK-013.02.04
title: 'Loan sharks part 1: lenders, borrowing, repayment and interest'
status: Done
assignee:
  - Claude
created_date: '2026-10-11 04:02'
updated_date: '2026-10-14 00:29'
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
- [x] #1 The core holds a list of loans, each with lender, balance, rate and days left, and the opening 5,500 debt is one of them per the findings
- [x] #2 Borrowing from an offered shark, repaying a chosen loan, per-day interest and the 1,000,000 total-debt cap behave as documented in docs/beermat-2.1-re.md
- [x] #3 Score and net worth sum over all loans
- [x] #4 Lender offers are generated and refreshed as the findings specify
- [x] #5 The Finances dialog lists offers and outstanding loans, covered by game:ui-test
- [x] #6 Mojo tests cover borrow, repay, cap and interest; dump, load and dump is byte identical
- [x] #7 docs/abi-contract.md and docs/architecture.md describe the loan state and ABI additions
- [x] #8 The jail release roll (Random(7) < 3, uniform pick among sharks still in jail, only while fewer than 5 are released) runs on a non-chase arrival ahead of the coat dealer roll, is deterministic for a seed, and announces the release (moved here from TASK-013.02.05 AC#3 with Lance's approval)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Core model (core/src/loans.mojo, world.mojo): shark table (name, sex, rate, duration days, multiplier, bruisers; N-06). World holds up to 5 loans in append order (shark index, balance Int64, days_left Int64) and a released flag per shark; the Float64 `debt` field goes away and total debt is the sum of balances. New game: Harry released, one loan 5500 / 10 days at Harry's 15%.
2. Rules (TDD, Mojo tests first in tests/mojo/loans_test.mojo): daily interest `Round(balance * (rate / 100.0) + balance)` in double precision then days_left -= 1, pinned on the observed chain 5500, 6325, 7274 ... 44752 incl. the 22,250 -> 25,587 tie; borrow (shark released, not owed, 0 < amount <= min(multiplier * (cash + bank), 1,000,000 - total debt), cash += amount, loan appended); repay one loan by shark index (days_left > 0: balance + Round(remaining * 30 / 100.0) where remaining = balance compounded days_left times minus balance, e.g. 6325 / 9 days / 15% -> 11,103; days_left <= 0: balance; needs cash >= payoff, else insufficient-cash and no state change); offers = released and not owed; score and finish use total debt.
3. Release roll (core): while released < 5, draw Random(7); on < 3 draw Random(5) until it lands on an unreleased shark, release it, return its index. Exposed as its own export called by the arrival flow after the chase check and before the coat dealer roll (N-09, stage 1 of the 2.1 arrival roll).
4. travel.mojo: replace the debt step with per-loan interest; remove the old single-debt interest, `ACTION_PAY_LOAN`, `DEBT_INTEREST`, `START_DEBT` rule constant semantics (keep START_DEBT = 5500 as the starter loan principal).
5. serialize.mojo: write loans (count + 5 fixed slots) and released flags, update DUMP_LEN; test dump -> load -> dump byte identical with loans, a partly released set and a negative days_left.
6. ABI (include/dopewars.h, core/src/abi.mojo, extension, game/simulation/world.gd): bump DW_ABI_VERSION to 11 (state dump layout and dw_finances pay-loan removal are breaking). Add `dw_rules_sharks_copy` (+ len), `dw_loans_copy`, `dw_offers_copy` (two-call), `dw_borrow(world, shark_index, amount)`, `dw_repay(world, shark_index, out_paid)`, `dw_roll_shark_release(world, out_shark_index)`. dw_state_view.debt stays and reports total debt (layout unchanged). Remove DW_FINANCES_PAY_LOAN. Update abitest, header check, bridge_expectations (tools/gen_bridge_expectations.py).
7. Fixtures and parity: 07 and 11 projections and replay.mojo/harness.mojo `debt` set-field now mean a single starter-loan balance (or drop it from the projections); retire 11 `payLoan` steps already retired; update docs/parity-fixture-classification.md if the projection changes. Remove the old debt interest test and un-skip/replace the pending loan tests in pending_2_1_test.mojo.
8. Godot: rebuild the loan section of FinancesDialog (Name / % Rate / Duration / Amount offers list with a borrow amount box capped per the core, "Outstanding Loans" list with days left and a Repay of the selected loan showing the payoff, the "maximum TOTAL debt cannot exceed 1,000,000" note), main.gd handlers, copy/strings.csv, hud debt LED stays total debt, release news toast in arrival_flow.gd. Extend game/godot_tests/ui_flow_test.gd and game/tests/test_bridge.gd (borrow, repay, offers list, release toast, debt LED).
9. Docs: docs/abi-contract.md (loan state, new calls, dump layout, version 11), docs/architecture.md, docs/parity-deltas.md if a delta applies, TODO.md untouched; update TASK-013.02.05 so it no longer owns the release roll.
10. Verify with `task core:test`, `task core:abitest`, `task core:abi:header-check`, `task game:bridge-test`, `task game:ui-test`; then finalize the task per the backlog finalization guide.
Out of scope, left for later slices: "Pay All Loans" button, "visiting you tomorrow" news line (N-08, TASK-013.02.05), overdue visits and beatings (05), 2.2's one-loan-per-day limit.

Executed with these deviations from the plan above: DW_ABI_VERSION stays 10 (earlier 2.1 slices changed layouts and the dump length without a bump and docs/abi-contract.md records them under 'Beermat 2.1 slices'; this slice is recorded there too), no dw_rules_sharks_len (DW_NUM_SHARKS covers it), interest helpers live in interest.mojo and the shark table in sharks.mojo. Finances dialog uses one Borrow button per offer and one Repay button per loan instead of Beermat's select-a-row-then-act layout.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Core, ABI v11 and Mojo/ctypes/abitest suites done and green (core:test, core:abitest, core:abitest:mojo, header-check). Loans are stored per slot (shark, balance, days_left) plus released flags; one loan per shark. Loan interest uses integer rounding with the double-rate residual deciding exact .5 ties (pure Float64 gets 22,250 wrong; x87 extended gave 25,587). Repay is full payoff of one loan only (findings document no partial repay). Remaining: extension shim, world.gd, bridge expectations, Godot dialog and arrival flow, ui/bridge tests, docs.

Verification: `task check` passes (core:test incl. loans_test 23 tests and serialize_test 5, ctypes abitest 38, Mojo abitest 26, header check, bridge:test, bridge:test:script 121 assertions, game:ui-test 619 assertions with the new loan_sharks case, smoke test), plus task lint, core:test:check-generated, gen:bridge-expectations:check and game:boundary-check. The strings.csv change needed a manual `godot --headless --import` because game:import skips when .godot exists.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replaces the single 10% debt with Beermat 2.1 loan sharks across the Mojo core, ABI, GDExtension and Godot UI.

Core: `sharks.mojo` holds the five-shark table (rate, duration, borrow multiplier, bruisers, sex); `loans.mojo` has borrow, repay, offers and the jail release roll; `interest.mojo` compounds each loan at its shark's rate and prices the early payoff (balance plus 30% of remaining interest). The world keeps up to five loans (shark, balance, days left) and a released flag per shark; `debt` is gone and total debt is the sum of balances. A new game releases Honest Harry and opens the 5,500 / 10 day / 15% starter loan. Borrowing is limited to multiplier x (cash + bank) and 1,000,000 minus total debt. Interest ties follow the findings: the double rate's error decides exact .5 ties (22,250 -> 25,587), pinned on the observed 16-step chain. Score and finish use total debt. The dump drops the debt float and adds the loans block (1208 -> 1285 bytes) and round-trips byte for byte.

ABI (version stays 10, recorded in docs/abi-contract.md and docs/architecture.md like the earlier 2.1 slices): adds `dw_rules_sharks_copy`, `dw_loans_copy`, `dw_offers_copy`, `dw_borrow`, `dw_repay`, `dw_roll_shark_release`, `dw_shark_view`/`dw_loan_view`/`dw_offer_view`, `DW_NUM_SHARKS`, `DW_ERR_NOT_OFFERED`, `DW_ERR_NO_SUCH_LOAN`; removes `DW_FINANCES_PAY_LOAN` and `dw_rules_debt_interest_bp`; `dw_state_view.debt` reports the total.

Godot: the Finances dialog lists shark offers (Borrow opens a quantity dialog capped at the offer), outstanding loans with days left and a Repay button showing the payoff, and the debt cap note. The arrival flow rolls the jail release before the coat dealer (not on the last day) and announces it.

Moved from TASK-013.02.05 with Lance's approval: the jail release roll (its AC#3 is removed). Out of scope and left for later: Pay All Loans, the 'visiting you tomorrow' line, overdue visits and beatings (TASK-013.02.05).

Tests: tests/mojo/loans_test.mojo (23), serialize_test additions, abitest additions (ctypes and Mojo), test_bridge.gd loan_sharks case, ui_flow_test.gd loan_sharks case; `task check` is green.
<!-- SECTION:FINAL_SUMMARY:END -->
