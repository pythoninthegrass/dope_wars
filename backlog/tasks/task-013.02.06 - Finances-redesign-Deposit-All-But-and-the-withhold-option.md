---
id: TASK-013.02.06
title: 'Finances redesign: Deposit All But and the withhold option'
status: To Do
assignee: []
created_date: '2026-10-11 04:02'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.04
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.02
ordinal: 59000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2.1 redesigned the Finances window. Besides Deposit, Withdraw and Withdraw All, it adds "Deposit All But..." which deposits all cash except an amount set in the Options window (maximum 1,000,000). Add the withhold amount as a persisted setting (a game setting, not core rules, unless the findings show it affects the sim) and the button to the Finances dialog, and fit it around the loan section from the loan-sharks slice. Deposit and withdraw semantics otherwise stay as in 1.2 (any amount up to cash or bank) unless the findings say otherwise.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Deposit All But deposits cash minus the withhold amount, and deposits nothing when cash is at or below it
- [ ] #2 The withhold amount is editable in the options UI, capped at 1,000,000, and persists across restarts
- [ ] #3 Deposit, Withdraw and Withdraw All keep their documented behaviour
- [ ] #4 game:ui-test covers the new button and the setting; any core change has Mojo tests
- [ ] #5 Strings are tr() keys
<!-- AC:END -->
