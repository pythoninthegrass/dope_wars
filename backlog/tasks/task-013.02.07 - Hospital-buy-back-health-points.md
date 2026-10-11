---
id: TASK-013.02.07
title: 'Hospital: buy back health points'
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
  - docs/beermat-re.md
parent_task_id: TASK-013.02
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2.0 added a Hospital button ("Visit the hospital"). The dialog reads "Welcome to my surgery! Not feeling well, huh? I can fix you up for a MERE $300 per HEALTH POINT. You CAN afford to be fully restored at a cost of $N", with a "How many do you wish to buy?" quantity box. 1.2 only heals through the post-chase doctor offer (1,000 to 1,999 for a full restore). Add a hospital action to the core (price per point and any limits from TASK-013.01.04, health capped at 100, paid from cash), a Hospital button on the main window, and the dialog. Whether the post-chase doctor offer survives in 2.1 is decided by the findings; record the decision here in the implementation notes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The core lets the player buy health points at the documented price, capped at full health and at what cash allows
- [ ] #2 The Hospital button opens a dialog showing the per-point price and the cost of a full restore, and the quantity box validates input
- [ ] #3 Whether the 1.2 post-chase doctor offer is kept or removed follows the findings, and the 1.2 fixtures or tests that depended on it are updated
- [ ] #4 Mojo tests cover buying, capping and insufficient cash; game:ui-test covers the dialog
- [ ] #5 Strings are tr() keys
<!-- AC:END -->
