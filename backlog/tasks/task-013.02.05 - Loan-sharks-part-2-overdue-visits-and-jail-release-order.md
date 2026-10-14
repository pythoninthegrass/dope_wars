---
id: TASK-013.02.05
title: 'Loan sharks part 2: overdue visits and jail release order'
status: Done
assignee:
  - '@Claude'
created_date: '2026-10-11 04:02'
updated_date: '2026-10-14 01:18'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.04
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.02
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When a loan is past due, 2.1 sends the lender's enforcers: the Loan Shark dialog shows the lender, "Your loan is N days past due", what you owe, the visitor's health bar, "Visit 1 of N", and Pay Now or Pay Later, with the player taking damage if the debt is not paid (the dialog text mentions a chainsaw). Implement the visit trigger, the Pay Now and Pay Later outcomes and health damage in the core per TASK-013.01.04, and the dialog in Godot. Depends on the loan list from the first loan-shark slice. The random jail release order (N-09) moved to TASK-013.02.04 AC#8.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Overdue loans trigger lender visits at the odds and timing the findings document, with draw order pinned in Mojo tests
- [x] #2 Pay Now settles per the findings; Pay Later applies the documented consequence including health damage, and death by loan shark ends the game
- [x] #3 The visit dialog is covered by game:ui-test, including multi-visit sequences
- [x] #4 The arrival flow queue handles visits in the documented order relative to events and chases
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Core (core/src/loans.mojo, TDD in tests/mojo/loans_test.mojo): `visit_level(days_left, bruisers) = max(0, |days_left| + bruisers - 1)`; `overdue_slots` (days_left <= 0, loan order); `due_tomorrow` (days_left == 1); `visit(game, shark)` applies the level 4+ beating: damage `Random(16) + 15` capped at health, message `Random(3) + 1` (message 1 with no draw when damage == health before the hit), `dead` when health reaches 0. Pay Now reuses `repay` (past due payoff is the balance); Pay Later changes nothing. Draw order pinned in tests (damage draw, then message draw).
2. ABI (include/dopewars.h, core/src/abi.mojo, abitest ctypes + Mojo, header check): `dw_visits_due_copy` (overdue shark indexes in loan order, two-call), `dw_visits_tomorrow_copy`-style helper for the "visiting you tomorrow" line, `dw_shark_visit(world, shark, out dw_visit_view)` returning level, days_left, owed, damage, message, dead. Version stays 10 like the earlier 2.1 slices; record under 'Beermat 2.1 slices'.
3. Extension shim + game/simulation/world.gd wrappers + tools/gen_bridge_expectations.py.
4. Godot: `LoanSharkDialog` (lender, past-due line, owed, visitor health bar, "Visit N of M", Pay Now / Pay Later, beating text, both disabled at level 4+ with a close button), copy/strings.csv entries, sounds per level, and the visit sequence in main.gd run BEFORE `_world.travel` (Beermat runs ProcessLoanSharks before the day advances). Death mid-sequence goes through `_handle_death`. The 'visiting you tomorrow' news line is queued in arrival_flow after the toasts/price news (Beermat step 10, after interest and price roll).
5. Tests: Mojo loans_test (levels, beating draw order, cap, death), abitest, test_bridge.gd, ui_flow_test.gd (single visit, multi-visit sequence, pay now, pay later, beating, death).
6. Docs: docs/abi-contract.md, docs/architecture.md, tests/mojo/README.md if needed.
7. Verify with `task check`, then finalize per the backlog guide.
Out of scope / open: running visits before the Finish button (Beermat's shared handler does; the port's Finish path is not touched here) and EndGame(3, shark) killer attribution in the score screen.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Deviations from the plan: the two queue helpers became one `dw_visits_copy(kind)` (DW_VISITS_OVERDUE / DW_VISITS_TOMORROW); the visit sequence lives in ArrivalFlow.begin_travel (visits, then travel, then the existing arrival queue) rather than in main.gd; no new sounds (TASK-013.02.17 owns them); DW_ABI_VERSION stays 10, recorded under the 2.1 slices note. The dialog's health bar is the player's health after the beating (the task text says 'the visitor's health bar', which the findings do not describe). Level 4+ shows Pay Now and Pay Later disabled plus an OK button; Enter maps to OK there. A refused Pay Now (not enough cash) shows the findings' message and re-presents the same visit without redrawing the beating. Not done: visits before the Finish button (Beermat's shared handler runs them) and EndGame(3, shark) killer attribution on the score screen.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Adds overdue loan shark visits (N-08) across the Mojo core, ABI, extension and Godot UI. Before each travel, every loan with days left of 0 or below opens a Loan Shark dialog in loan order ("Visit N of M"): status line (due today, due yesterday, N days past due), what is owed, the player's health bar, and Pay Now / Pay Later. The level is |days left| + bruisers - 1; level 3 adds the warning text; level 4 and up applies the beating on show (Random(16) + 15 damage capped at health, then Random(3) + 1 for the text, text 1 with no draw when it takes the last health), disables Pay Now / Pay Later and shows OK. Pay Now settles the loan at its balance, or says "You do not have enough cash to pay off this loan!" and re-presents the same visit; Pay Later changes nothing. Death by beating goes through the existing death path before the day advances. Loans with one day left queue "<shark> will be visiting you tomorrow." at the end of the arrival sequence, after the chase or the release, dealer and event rolls.\n\nCore: `loans.mojo` gains `visit_level`, `overdue_sharks`, `due_tomorrow_sharks` and `visit`. ABI (version stays 10, recorded in docs/abi-contract.md and docs/architecture.md): `dw_visits_copy`, `dw_shark_visit`, `dw_visit_view`, `dw_visit_kind`, `dw_visit_message`; no world-state or dump change. Godot: `LoanSharkDialog`, `ArrivalFlow.begin_travel` (visits, then travel, then the arrival queue), copy and strings.csv entries.\n\nTests: 12 new Mojo cases in loans_test (levels, trigger, beating range, draw order, lethal cap without a message draw, no draw below level 4), ctypes and Mojo abitest coverage plus header check, a bridge test case, and a `loan_shark_visits` ui-test case (due today, Pay Later, refused and successful Pay Now, a two-visit sequence with a beating then a plain demand, death before the day advances, the tomorrow warning). `task check` passes (ui flow test 730 assertions), plus task lint and markdownlint on the touched docs. The `Parse JSON failed` line in the ui test output predates this change.\n\nFollow-ups for Lance to decide: visits before the Finish button (Beermat runs them on every use of the shared travel handler), and killer attribution for EndGame(3, shark).
<!-- SECTION:FINAL_SUMMARY:END -->
