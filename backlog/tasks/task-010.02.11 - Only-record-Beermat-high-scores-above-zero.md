---
id: TASK-010.02.11
title: Only record Beermat high scores above zero
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
priority: low
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-13 in docs/beermat-re.md (decompile at 0x004609fc). The real game only enters a final score (cash + bank - debt, also computed on death) in the top-10 list when it is above 0; otherwise it shows "<name> was not good enough to get on your highest score list." and records nothing. The engine offers every score for the list. The list size (10) and the score formula already match.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Scores of 0 or less are not inserted into the high-score list and the player sees the 'not good enough' message, with failing tests first
- [ ] #2 Behaviour is the same in the prototype and the Godot build
- [ ] #3 Fixtures regenerated and task check passes
- [ ] #4 docs/beermat-re.md marks M-13 as match
<!-- AC:END -->
