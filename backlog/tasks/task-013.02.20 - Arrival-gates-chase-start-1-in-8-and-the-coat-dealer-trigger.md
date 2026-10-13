---
id: TASK-013.02.20
title: 'Arrival gates: chase start 1 in 8 and the coat dealer trigger'
status: To Do
assignee: []
created_date: '2026-10-13 05:13'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.01
documentation:
  - docs/beermat-2.1-re.md
  - docs/beermat-re.md
parent_task_id: TASK-013.02
ordinal: 80000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two 2.1 triggers in the travel and arrival flow differ from 1.2 (docs/beermat-2.1-re.md, "Travel, chase start and the day loop" and "Arrival events and dealers"). N-22: a chase starts on `Random(8) == 0` (1 in 8, 1.2 was 1 in 6), drawn on every travel, and only while `day < limit - 1`; a chase and the arrival events are exclusive. N-28: the coat dealer is a separate `Random(15) == 0` (1 in 15, 1.2 was `Random(14)` then a `Random(4)` coat-or-gun split) and only while coat capacity is below `day + 150`; there is no gun dealer draw. The offer price, pocket count and payment rules are unchanged. Update `combat.should_start_chase`, `dealers.roll_dealer_visit` and the arrival sequence that calls them, remove the gun dealer visit path (the Super Store slice, TASK-013.02.08, replaces the gun dealer), and keep the Godot arrival flow consistent. The stage order is read from 0x004be728: shark release, coat dealer, dialysis, event, Old Lady; this slice covers only the coat dealer stage and the chase gate.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 should_start_chase draws Random(8) and returns false when day is not below limit - 1
- [ ] #2 roll_dealer_visit draws one Random(15), offers the coat dealer only while coat capacity is below day + 150, and never returns a gun dealer
- [ ] #3 test_pending_n22_chase_starts_one_in_eight and test_pending_n28_coat_dealer_one_in_fifteen in tests/mojo/pending_2_1_test.mojo are un-skipped and pass, extended with the day < limit - 1 and capacity < day + 150 cases
- [ ] #4 Fixture 05 (coat dealer acceptance) and the kept coat dealer offer steps in fixture 10 still pass
- [ ] #5 game:ui-test covers a travel with a chase, a travel with a coat dealer offer and a travel with neither
- [ ] #6 task core:test and task check are green
<!-- AC:END -->
