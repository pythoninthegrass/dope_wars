---
id: TASK-010.02.01
title: 'Match Beermat drug table (names, price ranges, flags)'
status: To Do
assignee: []
created_date: '2026-10-01 06:17'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-01 in docs/beermat-re.md. The engine's drug table (index.html RULES.drugs, mirrored in core/src/rules.mojo) differs from the real game's table decoded at 0x0045c260. Bring the engine and core to the Beermat min/max ranges and crash/spike flags listed in the "Drug records" table of docs/beermat-re.md (price = Random(spread+1) + min, so max = min + spread). Only the data changes here; the spike/crash mechanics are M-02.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All 12 drugs use the Beermat min and max from docs/beermat-re.md, with a failing test written first
- [ ] #2 Crash and spike flags per drug match the Beermat table (the multipliers themselves are out of scope, see the price events subtask)
- [ ] #3 tests/fixtures are regenerated from the JS oracle and task core:test passes
- [ ] #4 docs/beermat-re.md marks M-01 as match
<!-- AC:END -->
