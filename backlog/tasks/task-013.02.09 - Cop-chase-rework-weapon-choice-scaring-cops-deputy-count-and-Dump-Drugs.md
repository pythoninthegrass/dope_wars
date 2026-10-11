---
id: TASK-013.02.09
title: 'Cop chase rework: weapon choice, scaring cops, deputy count and Dump Drugs'
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.08
documentation:
  - docs/beermat-2.1-re.md
  - docs/beermat-re.md
parent_task_id: TASK-013.02
ordinal: 62000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 2.1 chase dialog offers Stay, Run, Fight with a selectable weapon, and "Dump the drugs in your trenchcoat". The 2.1 changelog says cops no longer get killed and real weapons are gone: cops "just run away from humourous weapons". The sample caption shows 22 deputies, where 1.2 had 2 to 11. Rebuild the chase on the 2.1 rules from TASK-013.01.04: deputy count, run odds, the damage the cops deal, weapon-specific hit and scare rules using the inventory from the Super Store slice, the Dump Drugs action and its effect, the chase win reward (replacing the 1.2 gun and cash reward as the findings dictate), and the dialog UI with weapon selection. Keep the cop-chase timer option (500 to 4000 ms between events in the Options window) as a game setting if the findings show it is part of the chase flow.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Deputy count, run odds, cop damage, fight outcome per weapon and the win and loss conditions follow docs/beermat-2.1-re.md, with draw order pinned in Mojo tests
- [ ] #2 The player can choose which owned weapon to fight with; using ammo-limited weapons consumes ammo as documented
- [ ] #3 Dump Drugs removes the trenchcoat drugs and ends or advances the chase as documented
- [ ] #4 The 1.2 chase rules that 2.1 replaces are removed and their fixtures retired or replaced under TASK-013.02.01's classification
- [ ] #5 game:ui-test covers weapon selection, dump drugs, run, stay and fight flows; save mid-chase round trips
<!-- AC:END -->
