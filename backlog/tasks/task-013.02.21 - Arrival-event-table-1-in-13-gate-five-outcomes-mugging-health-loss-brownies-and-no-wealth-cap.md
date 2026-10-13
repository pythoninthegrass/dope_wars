---
id: TASK-013.02.21
title: >-
  Arrival event table: 1 in 13 gate, five outcomes, mugging health loss,
  brownies and no wealth cap
status: To Do
assignee: []
created_date: '2026-10-13 05:13'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.01
  - TASK-013.02.03
documentation:
  - docs/beermat-2.1-re.md
  - docs/beermat-re.md
parent_task_id: TASK-013.02
ordinal: 81000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Replace the 1.2 arrival event with the 2.1 stage-4 event (docs/beermat-2.1-re.md, "Event outcomes", N-29 and N-21). The event fires on `Random(13) == 0` (1.2 was `Random(14)`). The outcome draw is `Random(2)`: 0 gives `Random(2)` (find or friend), 1 gives `Random(3) + 2` (mugging, police dogs or brownies). Outcome 2 becomes 3 when cash is 0, and outcome 4 becomes 3 when neither Weed nor Hashish is held. Find and friend use all 13 drugs and `N = min(Random(7) + 2, free space)`. Mugging costs `Random(10) + 1` health, floored at 1, and cash `div (Random(2) + 3)`. Police dogs draw the held drug from `Random(12)` redrawn up to 21 times and drop `min(Random(held) + 1, 10)` on `Random(4) > 1`, then `Random(4) + 2` blocks. Brownies zero Weed if held, else Hashish. The 1.2 wealth cap (`cash + bank > 99,999,999` forces a mugging) is removed. Depends on the 13-drug roster from TASK-013.02.03. Update `events.roll_arrival_event`, the Godot arrival messages and the Mojo tests that pin the 1.2 table (`events_test.mojo`). The chase gate and coat dealer stage belong to the arrival gates slice, not this one.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 roll_arrival_event follows the 2.1 gate, outcome table and substitutions with draw order pinned in Mojo tests
- [ ] #2 Mugging reduces health by Random(10) + 1, floored at 1, and the Godot HUD shows it
- [ ] #3 Brownies and the 13-drug find and friend pool are implemented; the wealth cap is gone
- [ ] #4 test_pending_n21_mugging_costs_health and test_pending_wealth_cap_removed in tests/mojo/pending_2_1_test.mojo are un-skipped and pass
- [ ] #5 events_test.mojo no longer pins the 1.2 table
- [ ] #6 game:ui-test covers each outcome's message and a mugging's health loss
- [ ] #7 task core:test and task check are green
<!-- AC:END -->
