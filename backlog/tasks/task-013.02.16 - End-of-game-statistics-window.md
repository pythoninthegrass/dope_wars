---
id: TASK-013.02.16
title: End-of-game statistics window
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.04
  - TASK-013.02.09
  - TASK-013.02.12
documentation:
  - docs/beermat-2.1-re.md
  - docs/abi-contract.md
parent_task_id: TASK-013.02
ordinal: 69000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2.1 added an end-of-game statistics window, opened from a "View Stats" button on the end screen. Sections: The Law (cops faced, cops scared, possession arrests, assault arrests, chases), Loan Sharks (loans, total borrowed, repaid, interest, owed), Weapons (use count per weapon), and a "Day End Financial History" chart. Add the counters to the core (updated at the points the earlier slices already change state), a per-day net-worth history, and the stats window in Godot reachable from the end screen. Counter definitions (what counts as faced versus scared, etc.) come from TASK-013.01.04.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The core exposes every counter listed in the description and the day-end financial history, saved and restored with the game
- [ ] #2 Counters change exactly where the findings define them, pinned by Mojo tests
- [ ] #3 The end screen offers View Stats and the window shows the sections and a financial history chart
- [ ] #4 game:ui-test covers the window after a scripted game; docs/abi-contract.md lists the ABI additions
<!-- AC:END -->
