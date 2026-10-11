---
id: TASK-013.02
title: Implement Beermat 2.1 features in the Mojo core and Godot port
status: To Do
assignee: []
created_date: '2026-10-11 04:01'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.01
documentation:
  - docs/beermat-2.1-re.md
  - docs/architecture.md
  - docs/abi-contract.md
  - docs/layer-boundaries.md
parent_task_id: TASK-013
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Group task for the 2.1 feature slices. Each subtask is one vertical slice through Mojo core, C ABI, GDExtension shim, `SimWorld` pass-through and Godot presentation. Specs come from TASK-013.01.04 (the findings in docs/beermat-2.1-re.md); until that lands, the form-resource evidence in the same doc is only a feature outline, not a rule source. Mojo-first: `index.html` is frozen and is not extended.

Common acceptance criteria for every slice below: a failing Mojo test first (`core/`), then the minimum code; additive ABI changes with `task gen:bridge-expectations` regenerated and `DW_ABI_VERSION` bumped only on a breaking change; a `SimWorld` pass-through with no logic; every player-visible string a `tr()` key in `game/translations/strings.csv`; `task game:ui-test` covering the new UI; a save round trip through dump/load; docs updated; `task check` green.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All slice subtasks are Done
- [ ] #2 task check is green
- [ ] #3 docs/architecture.md and docs/abi-contract.md describe the new core state and ABI surface
<!-- AC:END -->
