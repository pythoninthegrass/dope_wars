---
id: TASK-013.02.02
title: 'Game length selection: 15, 30, 60 and 90 day games'
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
  - docs/parity-deltas.md
parent_task_id: TASK-013.02
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2.1 offers 15, 30, 60 and 90 day games in the new-game form; only 30 is available unregistered. The port has a fixed 31-day game (`numDays` in the core). Make the length a core parameter chosen at new game, with day counter, last-day handling and Finish following it, and expose a selector in the Godot new-game form. Registration is out of scope, so all lengths are available; record the registration gate as an intentional delta in docs/parity-deltas.md. Exact day-counting (31 vs 30 days, when the last-day message fires) comes from TASK-013.01.04. Follow the common slice criteria in TASK-013.02.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A game can be started with 15, 30, 60 or 90 days and ends on the day the 2.1 findings specify
- [ ] #2 The last-day message, Finish button and score recording follow the chosen length
- [ ] #3 The length survives save and load and is part of the high score entry or its display, as in 2.1
- [ ] #4 Mojo tests cover each length and the boundary day; game:ui-test covers the selector
- [ ] #5 The registration gate is recorded as an intentional delta in docs/parity-deltas.md
<!-- AC:END -->
