---
id: TASK-013.02.10
title: Kidneys and the nasty doctor event
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.01
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.02
ordinal: 63000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2.1 adds a "nasty doctor" that "can rip off your cash, your drugs, and your kidneys". The HUD shows a kidney indicator and the status line reads like "Health: 100%, infected, dialysis (2 kidneys)". Add kidney count to the core (starting at 2, effects of losing one or both per the findings, such as needing dialysis), the doctor event with its odds, trigger point and three outcomes (cash, drugs, kidney), the kidney indicator and status line in Godot, and the event messages. Where the doctor appears (an arrival event, a hospital outcome or the post-chase offer) is decided by the findings.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The core tracks kidneys and the doctor event's trigger, outcomes, amounts and draw order follow docs/beermat-2.1-re.md
- [ ] #2 Losing a kidney has the documented effect on gameplay, including what happens at zero kidneys
- [ ] #3 The HUD shows the kidney indicator and the status line from core state
- [ ] #4 Mojo tests pin each outcome and draw order; game:ui-test covers the indicator and event dialog; save round trip includes kidneys
- [ ] #5 Strings are tr() keys
<!-- AC:END -->
