---
id: TASK-001.01
title: Define ABI contract and module boundaries
status: To Do
assignee: []
created_date: '2026-09-26 04:33'
labels:
  - godot
  - mojo
  - ffi
  - migration
milestone: m-0
dependencies: []
references:
  - ~/git/jumpnbump/include/
  - >-
    ~/git/jumpnbump/backlog/tasks/task-012.01 -
    Write-include-jumpnbump.h-with-frozen-ABI-discipline.md
documentation:
  - index.html
  - AGENTS.md
parent_task_id: TASK-001
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Design and document the complete ABI surface that Mojo will export and C++ will consume. Every engine operation from `index.html:1049-1077` maps to a C-callable function. Establish ownership, memory, and error-handling conventions following the discipline in `~/git/jumpnbump/include/jumpnbump.h` (caller-owned opaque world pointer, `uint8_t`-typedef'd result codes never bare C enums, static-asserted struct sizes, two-call length-then-fill convention for every buffer output).

Deliverables:
1. `include/dopewars.h` — draft header (C11-clean, compiles with `cc -std=c11 -Wall -Wextra` with zero warnings)
2. `docs/abi-contract.md` — conventions document: ownership model, error codes, buffer contract, versioning policy
3. `docs/layer-boundaries.md` — what each layer is and is not allowed to do, with rationale

Cross-reference `~/git/jumpnbump/backlog/tasks/task-012.01` for the ABI discipline pattern and `~/git/jumpnbump/include/` for a concrete worked example.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ABI header draft covers all engine exports from index.html:1049-1077: RULES accessors, mulberry32/randInt, newGame, coatUsed, generatePrices, buy, sell, travel, finances, rollArrivalEvent, rollCoatDealerOffer, acceptCoatOffer, rollGunDealerOffer, acceptGunOffer, shouldStartChase, startChase, getFightRatings, runFromChase, fight, applyDamage, finish, insertHighScore, findDrug, findLocation, serializeState, deserializeState
- [ ] #2 Memory and error conventions are written and consistent: no bare C enums across the boundary, caller-owned world opaque pointer, two-call length-then-fill for all variable-length buffers, static_assert on every ABI struct size
- [ ] #3 Boundary rules document specifies what is forbidden in each layer: no Godot/FFI imports in Mojo core; no game logic in C++ shim; GDScript calls simulation only through the GDExtension class
- [ ] #4 AGENTS.md is updated to describe the four-layer architecture and directory layout
<!-- AC:END -->
