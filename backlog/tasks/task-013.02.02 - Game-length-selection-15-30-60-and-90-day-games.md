---
id: TASK-013.02.02
title: 'Game length selection: 15, 30, 60 and 90 day games'
status: Done
assignee: []
created_date: '2026-10-11 04:02'
updated_date: '2026-10-13 07:25'
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
- [x] #1 A game can be started with 15, 30, 60 or 90 days and ends on the day the 2.1 findings specify
- [x] #2 The last-day message, Finish button and score recording follow the chosen length
- [x] #3 The length survives save and load and is part of the high score entry or its display, as in 2.1
- [x] #4 Mojo tests cover each length and the boundary day; game:ui-test covers the selector
- [x] #5 The registration gate is recorded as an intentional delta in docs/parity-deltas.md
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Default game length is now 30 (rules.NUM_DAYS); the core already took num_days at new game, and a game of N days allows N-1 travels, with the chase suppressed on the last two days. New tests/mojo/game_length_test.mojo covers 15/30/60/90, the boundary day, save/load and the high-score field. dw_highscore_entry gained num_days (uint16 carved from the padding, struct size unchanged, no ABI version bump). The new-game form has a 15/30/60/90 selector, the high-score store persists the length and the Scores dialog shows a Length column. Registration gate recorded as parity-deltas section 9. Oracle fixture replay now passes 31 days explicitly. The core does not validate the four-length set; that is a presentation rule. task check green.
<!-- SECTION:FINAL_SUMMARY:END -->
