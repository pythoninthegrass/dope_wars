---
id: TASK-013.02.05
title: 'Loan sharks part 2: overdue visits and jail release order'
status: To Do
assignee: []
created_date: '2026-10-11 04:02'
updated_date: '2026-10-14 00:16'
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
- [ ] #1 Overdue loans trigger lender visits at the odds and timing the findings document, with draw order pinned in Mojo tests
- [ ] #2 Pay Now settles per the findings; Pay Later applies the documented consequence including health damage, and death by loan shark ends the game
- [ ] #3 The visit dialog is covered by game:ui-test, including multi-visit sequences
- [ ] #4 The arrival flow queue handles visits in the documented order relative to events and chases
<!-- AC:END -->
