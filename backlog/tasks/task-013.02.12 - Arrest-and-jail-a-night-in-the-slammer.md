---
id: TASK-013.02.12
title: 'Arrest and jail: a night in the slammer'
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.09
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.02
ordinal: 65000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 2.1 product text says "Let him catch you, and it's a night in the slammer for you!", and the statistics form counts possession arrests and assault arrests separately. 1.2 has no arrest: a chase ends in escape, death or a win. Implement arrest from the findings in TASK-013.01.04: what triggers possession and assault arrests (carrying drugs when caught, fighting), the penalty (lost day, confiscated drugs, fine or other), how it interacts with the chase flow, and the messages. The arrest counters feed the statistics slice, so the core must record the arrest kind.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Arrest triggers, kinds (possession, assault) and penalties follow docs/beermat-2.1-re.md, with draw order pinned in Mojo tests
- [ ] #2 The core records the number of each arrest kind
- [ ] #3 The chase dialog and arrival flow show the arrest outcome and continue to the right next state
- [ ] #4 game:ui-test covers an arrest flow; save round trip includes the counters
- [ ] #5 Strings are tr() keys
<!-- AC:END -->
