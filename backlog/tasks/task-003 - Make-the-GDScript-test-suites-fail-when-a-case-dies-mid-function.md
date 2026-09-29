---
id: TASK-003
title: Make the GDScript test suites fail when a case dies mid-function
status: In Progress
assignee: []
created_date: '2026-09-28 03:41'
updated_date: '2026-09-29 06:18'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation: GDScript has no try/catch, so the detection is per-case assertion bookkeeping + a frame watchdog, in all three suites. A case's runtime error (sync throw, unexpected null, early return) aborts that case's function but — verified by experiment — the caller continues (for awaited scene cases the throw is orphaned on the next frame and the run still reaches completion), so a single reconciliation at the end of the run sees the short count. Each case marks its start (_case); its passes/failures accumulate until the next _case; the reconciler (_finish) names every case that ran fewer than its declared floor as 'died mid-function' (or 'never ran'). A _process watchdog (WATCHDOG_FRAMES=600, guarded by _reconciled) is the AC#6 backstop: a synchronous harness error that skips _finish would otherwise hang to the 300s task timeout; the watchdog turns it into a named failure. Floors are declared per case: test_bridge.gd EXPECTED_ASSERTIONS (hand-derived, kept in sync like the old MIN_ASSERTIONS), bridge_test.gd derives per-case floors from the generated surface (forwarded_values = value-row count, others 1/1/2), ui_flow_test.gd CASE_FLOORS (happy-path counts for the fixed seed).

AC#5 interpretation (decided, not to be re-derived): 'task check stays green' means the detection machinery is correct and breaks nothing it shouldn't — every previously-green suite stays green and the build/other gates are unaffected. On this tree task check is red on EXACTLY one gate, bridge:test:script, solely because the known world_dump/ready_ defect (TASK-004, which depends on THIS task) is now correctly surfaced as the named failure 'case serialize_round_trip died mid-function (ran 11, expected 12)'. A literal 'everything exits 0' reading is unachievable before TASK-004 lands and would defeat the task's own purpose; it goes green when TASK-004 fixes the shim.

Env note: core/.venv was in a stale path-keyed uv install state (uv reported mojo installed, site-packages empty, no mojo binary). Repaired by building a working venv at a fresh path and copying it into core/.venv; the taskfile's _install-venv status checks (test -x .venv/bin/mojo; mojo --version grep 1.1.0) now pass and the standard task build ran unmodified. No gating tooling was changed.
<!-- SECTION:NOTES:END -->
