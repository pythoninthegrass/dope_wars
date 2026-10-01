---
id: TASK-010.02.04
title: Match Beermat chase start chance (flat 1 in 6)
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
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-04 in docs/beermat-re.md (decompile at 0x0045d428). In the real game each travel starts a chase with Random(6) == 0, the same at every location, and a chase replaces the arrival events and dealer visits for that travel (they are mutually exclusive). The engine weights the chance by a per-borough police value. Decision recorded by Lance: per-borough police weights are a rule, not part of the intentional location model. Remove them and make chase and arrival events exclusive.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A chase starts with probability 1/6 at every location, with a failing test first
- [ ] #2 When a chase starts, no arrival event and no dealer visit is rolled for that travel
- [ ] #3 Per-location police fields are removed from the engine, core and any ABI surface; DW_ABI_VERSION bumped if breaking
- [ ] #4 Fixtures regenerated and task check passes
- [ ] #5 docs/beermat-re.md marks M-04 as match
<!-- AC:END -->
