---
id: TASK-010.02.07
title: 'Match Beermat chase resolution (run, stay, fight, win reward)'
status: Done
assignee: []
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 07:32'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatches M-07, M-08 and M-09 in docs/beermat-re.md (decompile at 0x0045a878, 0x0045a9f8, 0x0045ab38, 0x0045a834). Real rules: Run escapes when Random(6) < 3 (50%, regardless of guns); otherwise the cops fire. Stay: the cops fire. Cops fire = Random(2): 1 hits for Random(11)+5 (5-15) damage, health floored at 0, 0 misses. Fight (needs at least one gun): the player's shot kills one deputy with probability 1/2; the chase is won when the deputy count drops below 0 (so deputies+1 kills); the cops return fire only while the count is still >= 0. Winning gives +1 gun and cash of (Random(1000)+1000) + Random(1500), then offers a doctor for the first term (1000-1999) that sets health to 100. Deputy count (2-11) already matches. Remove the attack/defend rating model and the aggressor flag.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Run, Stay, Fight, cop damage and the win condition match the rules above, with failing tests first
- [x] #2 A chase win grants +1 gun and the cash reward, and offers the doctor at the stated price
- [x] #3 The Stay button makes the cops fire
- [x] #4 Fixtures regenerated and task check passes (ABI version bumped if the surface changes)
- [x] #5 docs/beermat-re.md marks M-07, M-08 and M-09 as match
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Failing JS tests for run/stay/cop fire/fight/win reward/doctor, then rewrite the engine chase functions and drop the ratings and aggressor model.
2. Mojo core: port combat.mojo, add stay and doctor accept; ABI v8 (remove dw_get_fight_ratings, is_aggressor, gun_damage/player_armor accessors; add dw_stay_in_chase, dw_accept_doctor_offer; fight result carries reward and doctor offer).
3. Propagate through extension, SimWorld, ArrivalFlow, chase dialog and a doctor dialog, tr() keys, abitest, bridge tests, ui_flow_test.
4. Regenerate fixtures, docs, task check, merge.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified against the binary (0x0045a834/a878/a9f8/ab38): the doctor is a Yes/No box that is always shown after a win, with no health or affordability check; cash already includes the reward, so Yes deducts the first term. Full text: "You find a gun and $T on Officer Hardass' carcass. Will you pay $X to have a doctor sew you up?". Draw order: Run Random(6), Random(2), Random(11); Stay Random(2), Random(11); Fight shot Random(2), then Random(1000), Random(1500) on a win, else Random(2), Random(11).
ABI v8: dw_run_from_chase(world, out), new dw_stay_in_chase and dw_accept_doctor_offer; dw_fight needs a gun (DW_ERR_INVALID_ARGUMENT, no draw); dw_chase.deputies is int32 (below 0 = won); dw_fight_result is 16 bytes (killed, cop_hit, dead, won, damage_taken, reward, doctor). Removed dw_get_fight_ratings, dw_fight_ratings, dw_rules_gun_damage, dw_rules_player_armor. Declaration count 53 (was 54), DW_* constants still 32, dump length 846.
Fixture runner gotcha: the engine mutates a chase arg in place, so generate.mjs now clones args before running a step. Godot: ArrivalFlow calls run/stay/fight, a win shows "You killed them all!" then DoctorDialog; ui_flow_test gained chase_and_doctor (12 assertions), test_bridge gained chase_resolution (7). Added docs/parity-deltas.md section 6 (Fight round shows shot and return fire together), which needs Lance's approval.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Chase resolution now matches Beermat (M-07, M-08, M-09) in the JS engine, Mojo core, ABI v8, C++ shim, SimWorld, the web UI and the Godot chase flow (Stay fires, win reward, doctor dialog). Attack/defend ratings and the aggressor flag are removed everywhere. Fixtures regenerated (06 and 10 changed), second generation byte-identical, task check passes.
<!-- SECTION:FINAL_SUMMARY:END -->
