---
id: TASK-010.02.06
title: Match Beermat arrival event table
status: Done
assignee: []
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 07:17'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-06 in docs/beermat-re.md (decompile at 0x0045d96c). Replace the engine's percentile table with the real one: the event fires with Random(14) == 0 (always, as a mugging, when cash + bank >= 99,999,999), then Random(4) picks one of: (0) find N units of a random available drug on a dead dude, N = min(Random(7)+2, free space), skipped if the coat is full; (1) mugged, cash loses cash div (Random(2)+3); (2) a friend lays N units of a random available drug on you; (3) police dogs chase you Random(4)+2 blocks, and with drugs held a random held drug loses min(Random(held)+1, 10) units with 50% probability. Found or given drugs dilute the average cost (avg = held*avg div (held+N)). The engine-only events (Mama's brownies, hallucination death, bite to eat) are removed. Exact message strings are in docs/beermat-re.md.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Event chance, the four outcomes and their quantities match the rules above, with failing tests first
- [x] #2 The engine-only events are removed
- [x] #3 The wealth-cap forced mugging is implemented
- [x] #4 Message strings match docs/beermat-re.md
- [x] #5 Fixtures regenerated and task check passes
- [x] #6 docs/beermat-re.md marks M-06 as match
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Failing JS tests for the new event table (chance, wealth-cap forced mugging, four outcomes, draw order, dilution, no engine-only events). 2. Implement in index.html (event reads the previous market, prevPrices, as Beermat rolls events before the new prices). 3. Mojo port (events.mojo, rules), ABI v7 (dw_arrival_event kinds trimmed, damage replaced by blocks), extension, GDScript copy/tr() keys, abitest drivers, bridge expectations. 4. Regenerate fixtures, task check, docs (beermat-re M-06 match, parity-deltas, abi-contract, counts).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Binary (0x0045d96c) differs from the doc in four places, all followed: the wealth gate is 99,999,999 < cash + bank (so 100,000,000 and up), the found/given drug is Random(11) over Beermat slots 0-10 so Weed can never be found or given, the mugging text ends in "!" (third concat piece is the shared "!" literal at 0x45e000), and the friend text has no quantity. Event reads prevPrices: 0x0045d428 calls 0x0045d96c before 0x0045d120, so the drug pool is the market the player just left. Rejection loops are guarded (no eligible drug draws nothing). ABI v7: kinds 5-7 removed, dw_arrival_event.damage -> blocks (24 bytes), dump unchanged (846). DW_* constants 35 -> 32. New fixture helper setPrevPrices.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replaced the percentile arrival table with Beermat's event in the JS engine and the Mojo core: Random(14) chance (forced mugging above the wealth cap), then Random(4) for found drugs, mugging, friend gift or police dogs, with integer-division average dilution. Engine-only events removed. ABI v7, GDScript copy and tr() keys updated, fixtures regenerated, task check passes, docs/beermat-re.md marks M-06 as match.
<!-- SECTION:FINAL_SUMMARY:END -->
