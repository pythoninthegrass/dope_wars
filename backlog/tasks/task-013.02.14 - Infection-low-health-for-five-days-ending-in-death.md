---
id: TASK-013.02.14
title: 'Infection: low health for five days, ending in death'
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.07
  - TASK-013.02.10
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.02
ordinal: 67000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 2.1 changelog adds "infections if your health drops below 80% and stays there for 5 days"; the status line shows "infected" and the end screen reads "Your infection got the better of you. You're dead. What a drag!". Implement infection in the core: the low-health day counter, the infection state and its effects (health loss per day or death, per the findings), how the hospital cures it, the status line, and the new cause of death with its end-of-game text. Needs the hospital slice (cure) and the kidney slice (status line shared with dialysis).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The low-health counter, infection onset, per-day effect and death follow docs/beermat-2.1-re.md, with boundary cases (79, 80 percent; day 4, 5) pinned in Mojo tests
- [ ] #2 The hospital cures or does not cure infection exactly as documented
- [ ] #3 The status line shows infection and the death cause produces the 2.1 end-of-game text and a recorded score
- [ ] #4 game:ui-test covers infection onset and death; save round trip includes the counter and flag
- [ ] #5 Strings are tr() keys
<!-- AC:END -->
