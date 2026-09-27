---
id: TASK-001.08
title: Unblock stateful dw_world ABI surface (Mojo pointer-param limit)
status: To Do
assignee: []
created_date: '2026-09-27 21:28'
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
type: spike
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
