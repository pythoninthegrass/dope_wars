---
id: TASK-013.01.04
title: Document Beermat 2.1's rules and re-check the 1.2 findings against it
status: Done
assignee:
  - '@claude'
created_date: '2026-10-11 04:02'
updated_date: '2026-10-11 17:39'
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
- [x] #1 Every 1.2 rule M-01 to M-13 is classified unchanged, changed or removed, with a 2.1 virtual address
- [x] #2 Every feature listed in this description has its constants, draw order and text documented with a virtual address
- [x] #3 Open questions are either answered with evidence or listed as unresolved with the reason
- [x] #4 Each new or changed rule has an N-xx ID and a mapping to the TASK-013.02 slice that implements it
- [x] #5 markdownlint passes and no key, bottle path or CLAUDE.local.md infra appears
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Reread docs/beermat-2.1-re.md against decompiled_k and corrected it section by section. Corrections to the first pass: Randomize runs at startup and new game only; coat capacity starts at 100; 0x004e20f8 is kidneys and 0x004e20dc is health; drug records are 860 bytes; crash drugs are Acid, Hashish, Ecstasy, Crack, Weed (Peyote and Mushrooms are unflagged); 0x004bfbe0 is the status refresh, bank interest is 0x004c0358 at 5% per day, loan interest is 0x004c0420; Stay is an arrest check with no draw; the chase win reward is cash; 0x004bf420 is a mugging that costs health, not a doctor; the hospital price is (Random(9)+1)*50, the $300 is a form caption.

Open questions: (1) loan sharks answered: rates 15/10/20/30/25 percent per day, durations 10/15/7/1/5 days, amounts 10/20/30/50/100 times cash plus bank, bruisers 1/1/2/3/4, jail release is Random(7) < 3 per day then a uniform pick among sharks still in jail (0x004be728); (2) spike messages answered, Random(2) per spike drug, Special K has its own text; (3) bank interest answered, 5%; (4) arrival split answered, coat dealer 1 in 15 gated on capacity, event gate 1 in 13, dialysis 1 in 3, Old Lady 1 in 5, shark release 3 in 7.

Unresolved and listed in the doc with reasons: fight scare count, nasty doctor outcomes 3 and 4 and the kidney removal text, tip text joining words, weapon field +0x10, Old Lady phrase file contents. A follow-up session ran 2.1 natively on the Windows 11 reference machine, registered it and played 15 days; the shark table, borrow cap, early payoff, visits and beating, interest rounding (bank ties round up, loan interest follows double-precision rounding), hospital price, store prices, crash and spike texts, chase and Stay arrest were all confirmed and are listed under Verification on the 2.1 build in the doc. The arrival event table, coat dealer, dialysis, Old Lady, nasty doctor, Fight with a weapon and chase win reward were not observed. Weapon field +0x10 is the ammo price per round. Subtask mapping: N-28 and N-29 (arrival event table) and N-19 and N-20 (score) have no dedicated TASK-013.02 slice and are mapped to the closest one.
<!-- SECTION:NOTES:END -->
