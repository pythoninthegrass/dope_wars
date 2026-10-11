---
id: TASK-013.03.03
title: '2.2: at most one loan per day'
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
  - changelog-only
milestone: m-4
dependencies:
  - TASK-013.02.04
references:
  - vendor/CHANGELOG.md
parent_task_id: TASK-013.03
ordinal: 73000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Changelog-only (no 2.2 binary available): 2.2 added "cannot take more than one loan per day". Enforce it in the core's borrow path on top of the loan-shark slice, with a refusal message in the Finances dialog. What counts as "per day" (per game day, across all sharks) is an interpretation of the changelog; record it in docs/parity-deltas.md as changelog-only.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A second borrow on the same game day is refused with a message; the next day it is allowed
- [ ] #2 The restriction survives save and load
- [ ] #3 Mojo tests and game:ui-test cover refusal and the next-day reset
- [ ] #4 docs/parity-deltas.md records the interpretation as changelog-only
<!-- AC:END -->
