---
id: TASK-013.03.01
title: '2.2: 120 day game length'
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
  - changelog-only
milestone: m-4
dependencies:
  - TASK-013.02.02
references:
  - vendor/CHANGELOG.md
parent_task_id: TASK-013.03
ordinal: 71000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Changelog-only (no 2.2 binary available): the 2.2 release notes add a 120 day game length (registered version only). Add 120 as a selectable length alongside 15, 30, 60 and 90, with the same day-counting rules the 2.1 findings give for the others. Record in docs/parity-deltas.md that this comes from the changelog alone and that registration gating is dropped.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A 120 day game can be started and ends on the same boundary rule as the other lengths
- [ ] #2 Mojo tests and game:ui-test cover the new length
- [ ] #3 docs/parity-deltas.md records it as changelog-only with no binary evidence
<!-- AC:END -->
