---
id: TASK-013.03.04
title: '2.2: fewer deputies that deal more damage'
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
  - changelog-only
milestone: m-4
dependencies:
  - TASK-013.02.09
references:
  - vendor/CHANGELOG.md
parent_task_id: TASK-013.03
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Changelog-only (no 2.2 binary available): 2.2 changed cop chases: "less deputies chasing you, but more damage done by them". The 2.1 values come from the findings and the chase rework slice; 2.2 gives no numbers, so choose a smaller deputy range and a larger per-hit damage range, keeping the average threat comparable unless Lance decides otherwise, and record the chosen numbers and the reasoning in docs/parity-deltas.md as changelog-only. Ask Lance to approve the numbers before changing them.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Lance approves the chosen deputy range and damage range before implementation
- [ ] #2 Chases use the new ranges with draw order unchanged, pinned by Mojo tests
- [ ] #3 docs/parity-deltas.md records the numbers as changelog-only with no binary evidence
<!-- AC:END -->
