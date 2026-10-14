---
id: TASK-013.02.03
title: Flatter 2.0 drug pricing model and price-direction arrows
status: Done
assignee: []
created_date: '2026-10-11 04:02'
updated_date: '2026-10-13 07:35'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.01
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.02
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 2.0 release notes say pricing became "flatter and more varied to increase the skill factor", and 2.1's drug list shows an up/down arrow next to each drug for the price direction (registered only). The port still uses the 1.2 model (`price = Random(spread + 1) + min`, independent per arrival, spike x5 and crash /10). Recover the 2.1 price model from the dump (TASK-013.01.04), implement it in the core, and show the direction indicator in the Godot drug tables. The core must expose the previous price per drug so the arrow is a core fact, not a GDScript comparison.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The core generates prices with the 2.1 model, including whatever spike, crash and availability rules the findings document
- [x] #2 The core exposes each drug's previous price and the Godot tables show an up, down or no-change indicator from it
- [x] #3 Mojo tests pin the price ranges and draw order from the findings, including spike and crash behaviour
- [x] #4 docs/beermat-2.1-re.md and parity-deltas.md record the model and any simplification
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented the 2.1 price roll in core/src/prices.mojo from the 0x004bbfc4 findings: Random(9) first, per drug in Beermat slot order a fresh price or a keep on Random(5)==0 (blocked by a flagged previous roll), 1 in 8 absence, 1 in 40 spike or crash needing availability and no previous event, Special K spike draws nothing and has its own PRICE_EVENT_VET. Roster is 13 drugs (smack->mda, shrooms->mushrooms in place, crack gains the crash flag, specialk appended at index 12). World keeps last_price, last_event, seen_price and price_direction (dump 846 -> 1208 bytes). Direction follows the 0x004c0034 arrow logic: compared with the last day the drug was on sale; exposed as dw_price_slot.direction (padding, size unchanged) and rendered by the market table via Copy.trend(direction). Tests: rewritten prices_test.mojo pins draw order, keep, spike/crash conditions, direction and hidden prices; un-skipped N-34. Oracle fixture 02 no longer compares the newGame roster (1.2 roll); abitest deputy golden relaxed to its range. Not modelled: tip drug and stored hospital multiplier (Random(9) drawn and discarded); the fourth icon for event prices; recorded in parity-deltas section 10 and the 2.1 findings doc. AC#2 caveat: the core exposes the direction and dw_prev_prices_copy (previous turn roster) rather than a per-drug previous price field, since dw_price_slot has no room for one without a size change. Police dog drug draw is pinned to Random(12) (rules.HELD_DRUG_SLOTS) and gift draws stay over 11 slots until TASK-013.02.21. task check green.
<!-- SECTION:FINAL_SUMMARY:END -->
