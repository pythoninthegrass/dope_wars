---
id: TASK-013.02.13
title: 'Kidney dialysis machine: random offer'
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.10
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.02
ordinal: 66000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 2.1 changelog adds a "Kidney Dialysis Machine available for sale, randomly". It supports a player who has lost kidneys (the status line shows "dialysis"). Implement the offer: its trigger and odds, price, who can be offered it, what owning it does (sustaining a player with fewer than 2 kidneys, per the findings), the offer dialog, and the state in the core and HUD. Needs the kidney model from the kidneys slice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The offer's odds, price, eligibility and draw order follow docs/beermat-2.1-re.md
- [ ] #2 Owning the machine has its documented effect on kidney-loss consequences
- [ ] #3 The offer dialog and HUD status reflect core state
- [ ] #4 Mojo tests pin the offer; game:ui-test covers accept and decline; save round trip includes machine ownership
<!-- AC:END -->
