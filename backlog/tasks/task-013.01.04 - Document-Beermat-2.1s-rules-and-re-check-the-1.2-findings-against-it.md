---
id: TASK-013.01.04
title: Document Beermat 2.1's rules and re-check the 1.2 findings against it
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-11 04:02'
updated_date: '2026-10-11 06:41'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Map features to 2.1 handlers via methods.tsv, index.tsv, strings.txt (serial reading of the decompile, no parallel agents).
2. Find the 2.1 Random/Randomize addresses, then re-check M-01..M-13 and classify each unchanged/changed/removed with VA, constants and RNG draw order.
3. Document every new feature (loans, hospital, Super Store, weapons, cop chase, dump-drugs, jail, doctor, kidneys, dialysis, infection, Old Lady, game lengths, price model, bank interest, score, stats, sound table) with VA, constants, draw order, text; assign N-01+ IDs mapped to TASK-013.02.xx.
4. Resolve the joke vs real weapon set from code.
5. Confirm ambiguous rules in the CrossOver bottle (approved); Binary Ninja MCP for xref/x87 constant questions (approved).
6. Rewrite docs/beermat-2.1-re.md in the style of beermat-re.md, replacing the unverified table; commit atomically after each section.
7. markdownlint, grep for key/bottle path/CLAUDE.local.md infra, check ACs, add notes.
<!-- SECTION:PLAN:END -->
