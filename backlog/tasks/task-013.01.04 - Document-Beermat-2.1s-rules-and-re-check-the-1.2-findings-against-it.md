---
id: TASK-013.01.04
title: Document Beermat 2.1's rules and re-check the 1.2 findings against it
status: To Do
assignee: []
created_date: '2026-10-11 04:02'
updated_date: '2026-10-11 04:02'
labels:
  - beermat-2.1
  - reverse-engineering
milestone: m-4
dependencies:
  - TASK-013.01.03
documentation:
  - docs/beermat-2.1-re.md
  - docs/beermat-re.md
parent_task_id: TASK-013.01
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
With the decompiled dump from TASK-013.01.03, replace the "unverified" table in `docs/beermat-2.1-re.md` with findings in the style of `docs/beermat-re.md`: each rule with its 2.1 virtual address, constants, RNG draw order and message text. Cover every 1.2 rule (M-01 to M-13) as unchanged, changed or removed, and every new feature: loan sharks (offers, rates, durations, the 1,000,000 cap, overdue visits, jail release order), hospital price, Super Store catalogue and prices, weapons and cop-scare rules, deputy counts, dump-drugs, arrest and jail, doctor outcomes, kidneys, dialysis machine, infection (below 80% health for 5 days), Old Lady, game lengths, drug price model, bank interest, scoring, statistics counters, and the 2.1 sound-event table. Resolve the open question of which weapon set (joke or real) the shipped build uses. Confirm ambiguous rules by playing the game in the bottle. Give new differences IDs N-01 and up. This is the spec every TASK-013.02 slice depends on.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every 1.2 rule M-01 to M-13 is classified unchanged, changed or removed, with a 2.1 virtual address
- [ ] #2 Every feature listed in this description has its constants, draw order and text documented with a virtual address
- [ ] #3 Open questions are either answered with evidence or listed as unresolved with the reason
- [ ] #4 Each new or changed rule has an N-xx ID and a mapping to the TASK-013.02 slice that implements it
- [ ] #5 markdownlint passes and no key, bottle path or CLAUDE.local.md infra appears
<!-- AC:END -->
