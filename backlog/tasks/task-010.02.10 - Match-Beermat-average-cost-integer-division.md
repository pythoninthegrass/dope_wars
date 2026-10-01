---
id: TASK-010.02.10
title: Match Beermat average cost integer division
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
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-12 in docs/beermat-re.md (decompile at 0x0045e448). The real game keeps the average cost per drug as an integer: avg = (qty*price + held*avg) div (held + qty). The engine keeps a float average. Display-only, since selling uses the market price, but the value shown in the coat table differs. Interacts with the arrival-event subtask, where free drugs dilute the average with the same integer division.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Average cost is an integer computed with truncating division on buy, with a failing test first
- [ ] #2 Fixtures regenerated and task core:test passes
- [ ] #3 docs/beermat-re.md marks M-12 as match
<!-- AC:END -->
