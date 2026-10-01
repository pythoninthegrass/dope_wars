---
id: TASK-010.02.06
title: Match Beermat arrival event table
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
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-06 in docs/beermat-re.md (decompile at 0x0045d96c). Replace the engine's percentile table with the real one: the event fires with Random(14) == 0 (always, as a mugging, when cash + bank >= 99,999,999), then Random(4) picks one of: (0) find N units of a random available drug on a dead dude, N = min(Random(7)+2, free space), skipped if the coat is full; (1) mugged, cash loses cash div (Random(2)+3); (2) a friend lays N units of a random available drug on you; (3) police dogs chase you Random(4)+2 blocks, and with drugs held a random held drug loses min(Random(held)+1, 10) units with 50% probability. Found or given drugs dilute the average cost (avg = held*avg div (held+N)). The engine-only events (Mama's brownies, hallucination death, bite to eat) are removed. Exact message strings are in docs/beermat-re.md.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Event chance, the four outcomes and their quantities match the rules above, with failing tests first
- [ ] #2 The engine-only events are removed
- [ ] #3 The wealth-cap forced mugging is implemented
- [ ] #4 Message strings match docs/beermat-re.md
- [ ] #5 Fixtures regenerated and task check passes
- [ ] #6 docs/beermat-re.md marks M-06 as match
<!-- AC:END -->
