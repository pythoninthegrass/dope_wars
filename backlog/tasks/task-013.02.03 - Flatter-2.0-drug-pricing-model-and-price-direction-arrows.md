---
id: TASK-013.02.03
title: Flatter 2.0 drug pricing model and price-direction arrows
status: To Do
assignee: []
created_date: '2026-10-11 04:02'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.01
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.02
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 2.0 release notes say pricing became "flatter and more varied to increase the skill factor", and 2.1's drug list shows an up/down arrow next to each drug for the price direction (registered only). The port still uses the 1.2 model (`price = Random(spread + 1) + min`, independent per arrival, spike x5 and crash /10). Recover the 2.1 price model from the dump (TASK-013.01.04), implement it in the core, and show the direction indicator in the Godot drug tables. The core must expose the previous price per drug so the arrow is a core fact, not a GDScript comparison.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The core generates prices with the 2.1 model, including whatever spike, crash and availability rules the findings document
- [ ] #2 The core exposes each drug's previous price and the Godot tables show an up, down or no-change indicator from it
- [ ] #3 Mojo tests pin the price ranges and draw order from the findings, including spike and crash behaviour
- [ ] #4 docs/beermat-2.1-re.md and parity-deltas.md record the model and any simplification
<!-- AC:END -->
