---
id: TASK-006.01
title: Trenchcoat capacity shows 4/100 with no drugs held
status: To Do
assignee: []
created_date: '2026-09-28 08:00'
labels: []
dependencies: []
parent_task_id: TASK-006
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When a new game starts (or the player is otherwise carrying zero drugs), the trenchcoat capacity indicator reads 4/100 instead of 0/100. Suspect a gun occupying inventory space is being counted incorrectly, but this needs confirmation against the capacity formula in the reference implementation (see docs/gameplay.md) and the engine/core capacity calculation (index.html `<script id="engine">` for the prototype's equivalent logic, or the Mojo core once ported).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Root cause of the 4/100 baseline reading is identified and documented
- [ ] #2 Capacity display matches the reference ruleset's expected baseline (0 used space when holding no drugs, or the correct non-zero value if guns/items are meant to consume space)
- [ ] #3 A regression test covers the capacity calculation for the zero-drugs case
<!-- AC:END -->
