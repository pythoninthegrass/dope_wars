---
id: TASK-001.08
title: Unblock stateful dw_world ABI surface (Mojo pointer-param limit)
status: Done
assignee: []
created_date: '2026-09-27 21:28'
updated_date: '2026-09-27 22:15'
labels:
  - mojo
  - ffi
  - blocker
milestone: m-2
dependencies: []
references:
  - docs/mojo-1.1.0-abi-constraints.md
  - include/dopewars.h
  - TASK-001.05
parent_task_id: TASK-001
priority: high
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-001.05 landed the exporter, gates, and both test tiers, but AC#4 (world lifecycle, game step, serialize round-trip through the bridge) is blocked: Mojo 1.1.0 `@export` refuses any function with a pointer/`ref` parameter ("can not be applied on parametric functions") and there is no reachable address -> Pointer constructor, so the opaque `dw_world *` seam cannot be crossed. 35 of 54 declarations in `include/dopewars.h` are unexportable. Probe log: `docs/mojo-1.1.0-abi-constraints.md` (verified independently by reviewer probes incl. `~Pointer`/`~UnsafePointer` sugar).

This blocks the premise of TASK-001.06+ (UI calling stateful sim). Decide and execute one of:

1. Toolchain upgrade: find the first Mojo release where `@export` accepts an unbound-origin `Pointer` param; bump `MOJO_VERSION` in `taskfiles/core.yml`; `tools/check_abi_exports.py --strict` already fails until all 54 exports exist, so the lift surfaces as a build failure.
2. ABI restructure: e.g. opaque integer handles with core-side storage (weigh against the no-global-mutable-state boundary and the frozen `include/dopewars.h` contract).
3. Re-scope: if neither is acceptable, revisit the four-layer architecture assumption itself.

Do not weaken `check_abi_exports.py`, the purity gate, or the header contract as a workaround.
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Resolved without a toolchain bump, ABI restructure, or re-scope (options 1-3): the premise was wrong. `@export` on the pinned Mojo 1.1.0 accepts `OptionalPointer[T, origin=MutUntrackedOrigin]` (out/inout params) and `ImmUntrackedOrigin` (in params) — an explicitly-bound untracked origin is not parametric, and the Optional wrapper matches the header's NULL-rejection discipline. `size_of[T]()`/`align_of[T]()` from `std.sys` replace the supposedly missing sizeof/alignof intrinsics. The three reviewer probes that 'confirmed' the blocker tested parametric/unbound spellings only.

Outcome: all 54/54 declarations of include/dopewars.h are exported from `core/src/abi.mojo` (gate: '54/54 declared dw_* exported, 0 blocked, 0 leaked' on both .a and .so). `tools/check_abi_exports.py` `NON_POINTER_BLOCKED` is now an empty set; the strict gate that this task wired is what proves the lift. No gate or header contract was weakened — the blocked-surface conformance test was inverted to assert all-declared-exported.

Evidence: merge 0352fdb; probe log amended at docs/mojo-1.1.0-abi-constraints.md ('The spelling that works', 2026-09-27); `task check` exit 0 including both bridge tiers (scene + script) exercising init/step/dump/load through Godot -> C++ -> Mojo.
<!-- SECTION:FINAL_SUMMARY:END -->
