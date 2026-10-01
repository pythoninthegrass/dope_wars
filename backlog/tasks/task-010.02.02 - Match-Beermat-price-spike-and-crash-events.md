---
id: TASK-010.02.02
title: Match Beermat price spike and crash events
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
ordinal: 28000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-02 in docs/beermat-re.md (decompile at 0x0045d120). Replace the engine's 70%/40%/5% event-count scheme with the real per-drug rule: for each available drug that carries the spike flag, a 1-in-20 chance multiplies the price by 5, with the message chosen 50/50 between "Cops made a big <drug> bust!  Prices are outrageous!" and "Addicts are buying <drug> at outrageous prices!"; for each available drug with the crash flag, a 1-in-20 chance divides the price by 10 (integer division) with a fixed message per drug (acid, hashish, ecstasy, weed). Depends on the drug table subtask for the flags.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Spike is x5 and crash is integer div 10, each at 1 in 20 per flagged, available drug, with failing tests first
- [ ] #2 Spike and crash messages match the strings in docs/beermat-re.md
- [ ] #3 Fixtures regenerated and task core:test passes
- [ ] #4 docs/beermat-re.md marks M-02 as match
<!-- AC:END -->
