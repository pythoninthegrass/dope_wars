---
id: TASK-010.02
title: >-
  Decompile DopeWars.exe rule handlers and document findings in
  docs/beermat-re.md
status: To Do
assignee: []
created_date: '2026-09-30 05:01'
labels:
  - reverse-engineering
dependencies: []
documentation:
  - docs/gameplay.md
  - docs/parity-deltas.md
parent_task_id: TASK-010
priority: medium
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Using Ghidra headless (installed via Homebrew; wired into the Taskfile) with the label script from the extraction subtask, decompile the game's rule handlers and record the real constants and formulas in `docs/beermat-re.md`, each with its virtual address. Cover: price generation and price events, per-location drug availability, the arrival-event table, chase start chance, deputy count, run chance, fight hit and damage math, cop tiers, coat and gun dealer prices and roll rates, interest and loan rules, last-day and scoring rules, the exact trigger point of every sound, and the default value of the AllowSound setting. Diff each rule against `index.html` (`<script id="engine">`) and `core/src/*.mojo`, classify each delta as match, mismatch or intentional, and confirm anything the decompile leaves ambiguous on the live oracle (see CLAUDE.local.md). Each mismatch becomes its own follow-up subtask awaiting Lance's approval.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A Taskfile target runs Ghidra headless against the exe and exports decompiled handlers to a gitignored directory
- [ ] #2 docs/beermat-re.md records each rule with its virtual address and its match, mismatch or intentional classification against the current engine
- [ ] #3 The sound trigger points and the AllowSound default are documented with evidence
- [ ] #4 Each mismatch has its own follow-up subtask; the city names and the location model are recorded as intentional in docs/parity-deltas.md
- [ ] #5 No infra details from CLAUDE.local.md appear in the doc
<!-- AC:END -->
