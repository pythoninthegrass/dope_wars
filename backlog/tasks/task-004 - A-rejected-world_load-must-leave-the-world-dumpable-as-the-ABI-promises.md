---
id: TASK-004
title: 'A rejected world_load must leave the world dumpable, as the ABI promises'
status: To Do
assignee: []
created_date: '2026-09-28 03:41'
updated_date: '2026-09-28 03:41'
labels:
  - game
  - abi
  - bug
dependencies:
  - TASK-003
references:
  - >-
    include/dopewars.h:701-703 — dw_world_load: on failure, world state is
    unchanged
  - 'extension/src/dopewars_world.cpp:672 — ready_ = result == DW_OK'
  - >-
    game/tests/test_bridge.gd — the 'a failed load should not mutate the world'
    assertion
documentation:
  - docs/abi-contract.md
  - AGENTS.md
modified_files:
  - extension/src/dopewars_world.cpp
  - game/tests/test_bridge.gd
priority: medium
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The frozen ABI promises that a failed load leaves the world usable. `include/dopewars.h:701-703` documents `dw_world_load` as returning `DW_ERR_SERIALIZATION_FAILED` on any inconsistency, "on failure, world state is unchanged". The Mojo core honors that. The GDExtension shim does not, and the break happens before the ABI is even consulted.

`extension/src/dopewars_world.cpp:672` sets `ready_ = result == DW_OK` on every load. A rejected load therefore marks the handle not-ready, and `DopeWarsWorld::world_dump` (line 647) short-circuits on `!is_ready()` and returns a dictionary carrying only `result` — no `bytes` key at all. Every other shim method gates on `is_ready()` the same way, so a single rejected load leaves the whole handle unusable: the world that the ABI says is unchanged can no longer be read, dumped, or acted on through GDScript.

The consequence is that a documented guarantee is unobservable from the only layer the game and the tests speak to. `game/tests/test_bridge.gd` asserts it — `a failed load should not mutate the world` — and the assertion cannot even be evaluated, because indexing the returned dictionary for a missing `bytes` key throws. The script error that follows is what the companion task (TASK-003) was filed for; this task is the underlying contract violation that made the assertion unreachable.

`ready_` is doing two jobs at once: "this handle has a world" and "the last load succeeded". Collapsing them is what bricks the handle, because a handle that was just successfully loaded and then handed a corrupt buffer loses the first property along with the second.

The boot path is not affected and must stay that way: `game/platform/save_store.gd` relies on a fresh handle refusing a corrupt save so the game discards it and starts clean, and `game/godot_tests/ui_flow_test.gd` pins that behavior against index.html:1544-1553. A handle that has never held a world must still be unusable after a failed load; the fix is about preserving a world that already exists, not about making every handle permissive.

No ABI change is needed or wanted here. The header is frozen, `DW_ABI_VERSION` must not move, and the core is behaving correctly — this is a shim-side state-tracking fix in `extension/src/dopewars_world.cpp` with its bridge coverage.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 After world_load returns DW_ERR_SERIALIZATION_FAILED, a subsequent world_dump returns the same bytes it returned before that load, making the header's unchanged-world guarantee observable from GDScript
- [ ] #2 After a rejected world_load, the other world calls on that handle still work rather than returning DW_ERR_INVALID_ARGUMENT
- [ ] #3 A handle that has never held a world still refuses every call after a failed load, so a corrupt save is still discarded on boot and the next game starts clean
- [ ] #4 The existing assertion in game/tests/test_bridge.gd that a failed load should not mutate the world executes and passes instead of raising a script error
- [ ] #5 include/dopewars.h is unchanged and DW_ABI_VERSION does not move; no core source change is required
- [ ] #6 task check and the corrupt-save case in the ui flow suite stay green
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
TASK-003 must land first: until a suite reports a dead case as a failure, the assertion that proves this fix (the `a failed load should not mutate the world` check) can be skipped by a script error and the suite will still print OK. With TASK-003 in place, this fix's regression coverage is trustworthy.

Boot path deliberately unaffected: a handle that has never held a world must stay unusable after a rejected load, so `game/platform/save_store.gd` can still discard a corrupt save (index.html:1544-1553, pinned by the ui flow suite). The shim's `ready_` currently conflates "has a world" with "the last load succeeded" (extension/src/dopewars_world.cpp:672).
<!-- SECTION:NOTES:END -->
