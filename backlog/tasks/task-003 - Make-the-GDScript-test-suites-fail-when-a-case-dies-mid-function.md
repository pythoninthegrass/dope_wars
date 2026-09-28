---
id: TASK-003
title: Make the GDScript test suites fail when a case dies mid-function
status: To Do
assignee: []
created_date: '2026-09-28 03:41'
labels:
  - testing
  - game
dependencies: []
references:
  - >-
    AGENTS.md — headless Godot runs: a test that exits 0 having run zero
    assertions is a false pass
documentation:
  - AGENTS.md
modified_files:
  - game/tests/test_bridge.gd
  - game/godot_tests/bridge_test.gd
  - game/godot_tests/ui_flow_test.gd
priority: high
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A GDScript runtime error inside a test function aborts only that function; the caller keeps running. `game/tests/test_bridge.gd` cannot tell a case that completed from one that died on its third assertion, so it prints `OK` and exits 0.

Observed concretely: `_test_serialize_round_trip` in `game/tests/test_bridge.gd` dies on its final assertion with

    SCRIPT ERROR: Invalid access to property or key 'bytes' on a base object of type 'Dictionary'.
      at: _test_serialize_round_trip (res://tests/test_bridge.gd:157)

and the run still reports `test_bridge: OK (86 assertions)` with exit 0. The remaining assertions in that function never execute. The `MIN_ASSERTIONS` floor (40) exists to catch a suite that asserts nothing at all, and 86 sails past it, so the coarse backstop does not help. This is confirmed present on a clean tree, not introduced by any recent change.

AGENTS.md requires that a test which exits 0 having run zero assertions fails loudly, and calls out the related case explicitly: "A test that exits 0 having run zero assertions is a false pass". Dying halfway is the same failure one level up, and it is the mechanism by which a real regression in the bridge or the presentation layer can be reported as green.

`game/godot_tests/ui_flow_test.gd` has partial coverage: its `_case`/`_per_case` bookkeeping catches a case that asserted *nothing*, but not one that asserted fewer than intended, so the same class of failure hides there too. `game/godot_tests/bridge_test.gd` and `game/tests/test_bridge.gd` are both `--script`/scene suites that need the same guarantee.

Why this is filed first: it is what makes any other bridge regression detectable. Until a suite reports a dead case as a failure, a fix for the `world_dump` defect (filed separately) cannot be trusted to have stuck, because the assertion proving it can be skipped without anyone noticing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A case that aborts partway through — via a GDScript runtime error, an unexpected null, or an early return that skips its remaining work — makes its suite exit non-zero instead of reporting OK
- [ ] #2 Each case in game/tests/test_bridge.gd declares the number of assertions it expects to run, and the suite fails if a case runs fewer than that number
- [ ] #3 game/godot_tests/bridge_test.gd and game/godot_tests/ui_flow_test.gd gain the same per-case assertion floor, not only a whole-suite floor
- [ ] #4 The new detection is proven by deliberately breaking a case and showing the suite turns red, with the failure named in the output rather than a bare script error
- [ ] #5 task check stays green with the detection in place
- [ ] #6 A GDScript runtime error anywhere in a suite's own harness code is reported as a suite failure rather than passing silently
<!-- AC:END -->
