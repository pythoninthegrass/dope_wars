---
id: TASK-013.02.06
title: 'Finances redesign: Deposit All But and the withhold option'
status: Done
assignee:
  - '@Claude'
created_date: '2026-10-11 04:02'
updated_date: '2026-10-14 04:55'
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
- [x] #1 Deposit All But deposits cash minus the withhold amount, and deposits nothing when cash is at or below it
- [x] #2 The withhold amount is editable in the options UI, capped at 1,000,000, and persists across restarts
- [x] #3 Deposit, Withdraw and Withdraw All keep their documented behaviour
- [x] #4 game:ui-test covers the new button and the setting; any core change has Mojo tests
- [x] #5 Strings are tr() keys
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Oracle check on the 2.1 container: Deposit All But.. deposits at once with no prompt and disables when cash is at or below the withhold; the Options dialog holds the withhold as its first field (default 1000, max 1,000,000).
2. game:ui-test case `deposit_all_but` first (red), then WithholdSettingsStore, a Tools > Options.. menu item and dialog, and the finDepositAllBut button.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added Deposit All But.. to the Finances dialog and a Tools > Options.. dialog that sets the withhold amount. The withhold is a UI setting stored in WithholdSettingsStore (user://dopewars.withhold.json, default 1000, clamped to 0..1,000,000). The button deposits cash minus the withhold through the existing deposit call and is disabled when cash is at or below the withhold, so the core and ABI are unchanged. Options reuses QuantityDialog. game:ui-test case `deposit_all_but` covers the button, the default, the cap, persistence and cancel. Not done: Withdraw All, which the 2.1 dialog shows but the port has never had; the task kept Withdraw semantics as is. Strings are tr() keys.
<!-- SECTION:FINAL_SUMMARY:END -->
