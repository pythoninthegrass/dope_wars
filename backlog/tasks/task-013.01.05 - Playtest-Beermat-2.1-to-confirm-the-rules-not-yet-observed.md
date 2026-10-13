---
id: TASK-013.01.05
title: Playtest Beermat 2.1 to confirm the rules not yet observed
status: To Do
assignee: []
created_date: '2026-10-13 04:30'
labels:
  - beermat-2.1
  - reverse-engineering
milestone: m-4
dependencies: []
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.01
priority: medium
type: task
ordinal: 77000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-013.01.04 confirmed the deterministic 2.1 rules on a running game (see "Verification on the 2.1 build" in docs/beermat-2.1-re.md). These rules were read from the decompile only and were not seen in 15 days of play: the arrival event table (find, friend, mugging, police dogs, brownies), the coat dealer, the dialysis offer, the Old Lady (tip and phrases, mute), infection and kidney damage, the nasty doctor (outcomes beyond the 1-in-5 gate and drug removal), Fight with a weapon (how many deputies a hit scares away), the chase win reward, and the shark release news text. Play long games on the Windows reference machine (see CLAUDE.local.md for connection details), record each event with its exact text and numbers, and update the doc and the N-xx rows. Rates cannot be proved from a wall-clock seeded game, so tally counts and report them as consistent or inconsistent with the decoded odds. Never record the license key or machine details in the doc. Slices TASK-013.02.09 to .14 depend on the outcomes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each rule listed in the description is either observed with exact text and numbers, or listed as still unobserved with the number of travels played
- [ ] #2 The doc's unresolved list shrinks to what the play could not settle, with reasons
- [ ] #3 Tallies of event counts against travel counts are recorded for the chase, arrival event, coat dealer, dialysis, Old Lady and shark release rolls
- [ ] #4 markdownlint passes and no key or machine detail appears in the doc
<!-- AC:END -->
