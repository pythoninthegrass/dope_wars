---
id: TASK-006.02
title: Cash-cost random events don't deduct money
status: To Do
assignee: []
created_date: '2026-09-28 08:00'
labels: []
dependencies: []
parent_task_id: TASK-006
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Random arrival events that are supposed to cost the player money (e.g. "eating lunch") resolve without subtracting cash from the player's balance. Needs investigation into the random-event handling path (`rollArrivalEvent` and related engine logic in `index.html`, or its Mojo core equivalent once ported) to find where the cash deduction is being skipped or miscalculated, cross-checked against docs/gameplay.md's random-event tables.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Root cause of the missing cash deduction is identified and documented
- [ ] #2 Cash-cost random events correctly deduct the specified amount from player balance
- [ ] #3 A regression test covers at least one cash-cost random event applying its deduction
<!-- AC:END -->
