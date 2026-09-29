---
id: TASK-006.02
title: Cash-cost random events don't deduct money
status: Done
assignee: []
created_date: '2026-09-28 08:00'
updated_date: '2026-09-29 05:46'
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
- [x] #1 Root cause of the missing cash deduction is identified and documented
- [x] #2 Cash-cost random events correctly deduct the specified amount from player balance
- [x] #3 A regression test covers at least one cash-cost random event applying its deduction
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root-cause investigation (TASK-006.02): traced the full cash-deduction path in all four layers — JS oracle (index.html rollArrivalEvent :859-927), Mojo core (core/src/events.mojo roll_arrival_event), ABI (core/src/abi.mojo dw_roll_arrival_event), extension (extension/src/dopewars_world.cpp roll_arrival_event), presentation (game/presentation/arrival_flow.gd + main.gd _do_travel + hud.gd refresh). FINDING: no missing deduction exists in this revision. The mugged band (roll<10) applies cash = floor(cash * pct), pct in [0.80, 0.95] (loses 5-20% per docs/gameplay.md:100); the flavor band (60.5..75) applies cash = max(0, cash - amt), amt = randInt(1,10) (costs $1-10 per docs/gameplay.md:105). Both match the JS oracle line for line, and the parity corpus already pins the post-deduction cash (tests/fixtures/04-arrival-events.jsonl step 3: mugged 1000 -> 880 'lost $120'; step 25: flavor 500 -> 499 '$1'), with task core:test passing. Empirical verification on this worktree: (a) live probe through Godot -> C++ -> Mojo over 199 seeds: 732 muggings + 1070 flavors, before - after == reported amount in every case (0 problems); (b) live probe driving the real Main scene (59 seeds, ~236 travels, arrival sequences drained through the real dialogs): 45 cash-dropping events, cash LED always equal to the world's cash afterwards; (c) task check fully green. The reported symptom is therefore not reproducible against this code state; the report does not correspond to any code path in this revision (stale observation).

Added tests/mojo/events_test.mojo (4 scripted-Rng regression tests pinning the deduction math directly: mugged 5-20% deduction with exact floor, $0-cash mugged taking damage with no stray second RNG draw, flavor deducting the named amount, flavor flooring at $0). Verified the tests genuinely guard the deduction: with the two deduction lines temporarily removed from core/src/events.mojo, 3 of 4 tests fail; restored clean. The file is picked up automatically by task core:test and task check (4/4 passing there). No production code changed — the deduction path was already correct.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Investigation found no missing cash deduction in any layer: the mugged/flavor bands in core/src/events.mojo deduct exactly as the JS oracle and docs/gameplay.md specify, pinned by the 04-arrival-events parity fixture (task core:test green) and re-verified with live probes through the extension (1802 events, 0 problems) and through the real Main scene (45 cash drops, cash LED matches world cash). The report is not reproducible against this revision. Landed tests/mojo/events_test.mojo — 4 scripted-Rng regression tests pinning the deduction math, proven to fail when the deduction is removed — so a future removal is caught by task core:test / task check. task check and task lint green; diff touches only the new regression test and this bookkeeping.
<!-- SECTION:FINAL_SUMMARY:END -->
