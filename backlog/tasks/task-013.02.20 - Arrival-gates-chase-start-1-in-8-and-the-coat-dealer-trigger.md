---
id: TASK-013.02.20
title: 'Arrival gates: chase start 1 in 8 and the coat dealer trigger'
status: Done
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
- [x] #1 should_start_chase draws Random(8) and returns false when day is not below limit - 1
- [x] #2 roll_dealer_visit draws one Random(15), offers the coat dealer only while coat capacity is below day + 150, and never returns a gun dealer
- [x] #3 test_pending_n22_chase_starts_one_in_eight and test_pending_n28_coat_dealer_one_in_fifteen in tests/mojo/pending_2_1_test.mojo are un-skipped and pass, extended with the day < limit - 1 and capacity < day + 150 cases
- [x] #4 Fixture 05 (coat dealer acceptance) and the kept coat dealer offer steps in fixture 10 still pass
- [x] #5 game:ui-test covers a travel with a chase, a travel with a coat dealer offer and a travel with neither
- [x] #6 task core:test and task check are green
<!-- AC:END -->

## Implementation notes

Mojo-first, test-first. The two pending tests were un-skipped and extended first
(N-22 gains the `day >= num_days - 1` case on a 2-day game; N-28 gains the
`coat_capacity == day` and `coat_capacity == day + 150` cases), confirmed red,
then the rules landed.

- `combat.mojo`: `should_start_chase` returns false when `day >= num_days - 1`,
  else `Random(8) == 0` (was `Random(6) == 0`).
- `dealers.mojo`: `roll_dealer_visit` draws one `Random(15)`, returns
  `DEALER_COAT` only while `coat_capacity < day + 150`, else `DEALER_NONE` (no
  gun branch). The coat/gun split is gone; the standalone gun offer is kept for
  the Super Store.
- `rules.mojo`: `DEALER_ODDS` 14 -> 15, added `COAT_DAY_OFFSET = 150`.
- `arrival_flow.gd`: dropped the `GUN_DEALER` step and `_present_dealer(is_gun)`
  -> `_present_dealer()`, which rolls the coat offer only.
- `ui_flow_test.gd`: `_test_dealer_dialogs` now covers only the coat dealer via
  arrival; added `_test_travel_arrival_outcomes` (chase, coat dealer offer,
  neither).
- `rules_test.mojo`: pinned `DEALER_ODDS = 15`, added `COAT_DAY_OFFSET = 150`.
- `include/dopewars.h`: refreshed the `dw_roll_dealer_visit` and
  `dw_should_start_chase` comments to the 2.1 rule. The gun-dealer ABI surface
  (`dw_roll_gun_dealer_offer`, `dw_accept_gun_offer`, `dw_gun_offer`,
  `DW_DEALER_GUN`) is kept -- the Super Store slice repurposes it.

`task core:test` (36 passed) and `task check` (bridge 16, ui flow 553) green.
Fixtures 05 and 10 pass; `core:test:check-generated` clean.
