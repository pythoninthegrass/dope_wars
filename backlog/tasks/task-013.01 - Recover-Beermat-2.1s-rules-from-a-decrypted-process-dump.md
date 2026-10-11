---
id: TASK-013.01
title: Recover Beermat 2.1's rules from a decrypted process dump
status: To Do
assignee: []
created_date: '2026-10-11 04:01'
labels:
  - beermat-2.1
  - reverse-engineering
milestone: m-4
dependencies: []
documentation:
  - docs/beermat-2.1-re.md
  - docs/beermat-re.md
parent_task_id: TASK-013
ordinal: 47000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Group task for the 2.1 reverse engineering. `dw21.exe` is a Wise installer; the game inside is protected by PC Guard (all sections `.PCGW32`, entropy near 8.0), so the static pipeline from TASK-010 cannot read its code. This group extracts the payload, adapts the extractor to 2.1, unpacks the game in a CrossOver bottle (registering it with the license key from `vendor/dopewars-2001/key.txt`), dumps the decrypted process, and writes the findings. Every implementation task under TASK-013.02 depends on the findings task here.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Subtasks .01 to .04 are Done
- [ ] #2 docs/beermat-2.1-re.md states, for every 1.2 rule in docs/beermat-re.md (M-01 to M-13), whether it is unchanged, changed or removed in 2.1, with 2.1 virtual addresses
<!-- AC:END -->
