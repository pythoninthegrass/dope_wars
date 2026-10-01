---
id: TASK-010.02.03
title: 'Match Beermat drug availability (1/8 absent, location independent)'
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
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-03 in docs/beermat-re.md (decompile at 0x0045d120). The real game removes each drug independently with probability 1/8 on every arrival, the same at every location. The engine instead picks a per-borough subset size (minDrugs..maxDrugs). Decision recorded by Lance: per-borough drug counts are a rule, not part of the intentional location model. Remove the per-location minDrugs/maxDrugs from the engine and core, and update anything (ABI rules accessors, UI) that exposes them.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each drug is unavailable with probability 1/8 independently of location, with a failing test first
- [ ] #2 Per-location drug count fields are removed from the engine, core and any ABI surface; DW_ABI_VERSION bumped if the change is breaking
- [ ] #3 Selling an unavailable drug is still refused
- [ ] #4 Fixtures regenerated and task check passes
- [ ] #5 docs/beermat-re.md marks M-03 as match
<!-- AC:END -->
