---
id: TASK-013.03.05
title: '2.2: score breakdown in the end-of-game statistics'
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
  - changelog-only
milestone: m-4
dependencies:
  - TASK-013.02.16
references:
  - vendor/CHANGELOG.md
parent_task_id: TASK-013.03
ordinal: 75000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Changelog-only (no 2.2 binary available): 2.2 added "extra end of game statistics showing breakdown of score". Extend the statistics window with a breakdown of the final score (`cash + bank - debt`, as its components over all loans). The exact layout is not documented anywhere, so keep it to those components and record the choice in docs/parity-deltas.md as changelog-only.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The statistics window shows cash, bank, total debt and the final score, matching the recorded score
- [ ] #2 game:ui-test covers it; no new core rule is introduced
- [ ] #3 docs/parity-deltas.md records the layout as changelog-only
<!-- AC:END -->
