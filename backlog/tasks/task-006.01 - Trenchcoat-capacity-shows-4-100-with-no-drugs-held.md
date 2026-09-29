---
id: TASK-006.01
title: Trenchcoat capacity shows 4/100 with no drugs held
status: Done
assignee: []
created_date: '2026-09-28 08:00'
updated_date: '2026-09-29 05:54'
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
- [x] #1 Root cause of the 4/100 baseline reading is identified and documented
- [x] #2 Capacity display matches the reference ruleset's expected baseline (0 used space when holding no drugs, or the correct non-zero value if guns/items are meant to consume space)
- [x] #3 A regression test covers the capacity calculation for the zero-drugs case
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Root cause (AC #1)

The 4/100 reading is **one gun, zero drugs** — the correct value under the reference ruleset, not a miscount. Used-space = drug units + `guns * GUN_SPACE` (GUN_SPACE = 4), identically in the reference (docs/gameplay.md "Inventory" line 111: guns cost 4 each), the prototype (index.html:711-716 `coatUsed`), and the Mojo core (core/src/world.mojo `coat_used`, since first port commit b8e56d9).

Verified live through the full Godot -> C++ -> Mojo stack (headless probe driving SimWorld):
- Fresh game (0 guns, 0 drugs): `dw_state_view.coat_used = 0`, `dw_coat_used() = 0`, guns = 0 -> renders **0/100**. All new-game entry points (`dw_world_init`, `dw_world_reset`, save-reject fallback in main.gd) construct `new_game`, which sets guns = 0.
- After buying one gun with zero drugs: coat_used = 1 * 4 = **4** -> renders 4/100. The suspect's premise ("a gun ... counted incorrectly") is refuted: guns are meant to consume space, and 4 slots per gun is the reference value.
- Serialize -> deserialize round-trip of the 1-gun state: coat_used stays 4 (consistent).

So AC #2 holds with no code change: the display already matches the reference baseline (0/100 fresh; 4/100 = one gun). The report reads as a bug because a player who bought a gun early (and holds no drugs) sees 4/100 and assumes an empty coat should read 0/100.

## Regression test (AC #3)

core/abitest/abitest.mojo (Tier-C conformance, reached only through the C ABI):
- `test_game_step_sequence`: fresh world asserts `guns == 0` and `coat_used == 0` (the zero-drugs baseline, previously unasserted).
- `test_dealer_offers_and_purchases`: after accepting a gun offer, asserts `coat_used == 4` with zero drugs held — the exact reported reading, locked in as the reference-correct value, with a comment citing the ruleset and prototype lines.

Test-teeth check: temporarily adding an unconditional `+ GUN_SPACE` to `coat_used` made both new assertions fail (lines 739 and 798) and the gate exit non-zero; reverted. `task check` fully green afterwards.

Environment note: the session shell exported VIRTUAL_ENV pointing at a uv cache env, which made `uv pip install` skip the mojo console script; unsetting VIRTUAL_ENV/UV_RUN_RECURSION_DEPTH and rebuilding core/.venv fixed it.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Summary

Investigated the reported "trenchcoat capacity shows 4/100 with no drugs held" reading. **Root cause: not a defect.** The 4/100 baseline is one gun with zero drugs — guns consume 4 coat slots each by reference (docs/gameplay.md "Inventory", index.html:711-716, core/src/world.mojo coat_used). A genuine fresh game (0 guns, 0 drugs) reads 0/100, verified live through the full Godot -> C++ -> Mojo stack, including the serialize/deserialize round-trip. No code change was required; the display already matches the reference ruleset.

## Changes

- core/abitest/abitest.mojo: regression assertions in the Tier-C conformance driver — fresh world asserts guns == 0 and coat_used == 0 (the zero-drugs baseline), and the gun-purchase test asserts coat_used == 4 with zero drugs held (the exact reported reading, locked as reference-correct). Proven to fail against an injected unconditional +4 regression.

## Verification

- task check: green (parity fixture replay, ABI gates, ctypes 40 + mojo 23 + C header conformance, boundary check, both bridge tests, ui flow test 455 assertions, build, headless smoke test).
- Headless SimWorld probe: fresh 0/100; 1 gun + 0 drugs 4/100; round-trip consistent.
<!-- SECTION:FINAL_SUMMARY:END -->
