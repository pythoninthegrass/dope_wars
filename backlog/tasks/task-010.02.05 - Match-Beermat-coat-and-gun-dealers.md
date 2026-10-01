---
id: TASK-010.02.05
title: Match Beermat coat and gun dealers
status: Done
assignee: []
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 07:06'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-05 in docs/beermat-re.md (decompile at 0x0045d96c). Real rules: one combined 1-in-14 dealer chance per non-chase travel, then a 50/50 split between coat and gun dealer. Coat: price Random(150)+201 (201-350), adds Random(10)+11 pockets, offered only if price < cash. Gun: price Random(250)+301 (301-550), offered only if price < cash, a gun takes no coat space, name drawn from Baretta, .38 Special, Ruger, Saturday Night Special (cosmetic). Both are paid from cash only. The engine has two independent 15% draws, wider price and pocket ranges, a 4-space gun and a bank fallback with a 25% fee; remove the bank fee path.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Dealer chance, split, prices and pockets match the values above, with failing tests first
- [x] #2 Offers are only presented when price < cash; the bank fallback and fee are removed
- [x] #3 A gun uses no coat space
- [x] #4 Fixtures regenerated and task check passes (ABI version bumped if the surface changes)
- [x] #5 docs/beermat-re.md marks M-05 as match
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Failing engine tests for the combined 1-in-14 visit, coat and gun price ranges, the price < cash offer rule, cash-only payment and gun taking no coat space.
2. Implement in index.html, regenerate fixtures 05, 10 and 12 and the generated Mojo corpus.
3. Port to core/src/dealers.mojo, drop GUN_SPACE and the bank fee, reshape the ABI offers (v6), propagate to the extension, SimWorld, abitest drivers and bridge expectations.
4. Rework the arrival flow and dealer dialog; roll the arrival event after the dealer.
5. Update docs and run task check.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Draw order verified against the decompile of 0x0045d96c: Random(14), then Random(4) (0/2 coat, 1/3 gun). Coat: price Random(150)+201 is drawn, the offer is made only if price < cash, and the pocket count Random(10)+11 is drawn only after the player accepts. Gun: price Random(250)+301, the name Random(4) is drawn only if price < cash. Both are paid from cash only. Dealers now roll before the arrival event (as in Beermat), and the event is rolled lazily after the dealer dialog, in both index.html and arrival_flow.gd. ABI v6: dw_roll_dealer_visit replaces dw_roll_dealer_visits; dw_coat_offer is {price, offered}, dw_gun_offer is {price, name_index, offered} (12 bytes); dw_accept_coat_offer returns pockets via out_pockets; dw_purchase_result, dw_rules_gun_space and dw_rules_bank_purchase_fee_bp are removed; DW_DEALER_* added (35 DW_* constants). DW_ERR_INSUFFICIENT_BANK is kept as reserved. Gun names are cosmetic: the core returns name_index, GDScript maps it to GUN_NAME_* tr() keys. coat_used no longer counts guns.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Dealers now match Beermat (M-05): one Random(14) == 0 visit per non-chase arrival, Random(4) picks coat (0, 2) or gun (1, 3), coat price 201-350 and 11-20 pockets drawn on acceptance, gun price 301-550 with a cosmetic name drawn only when offered, offers only when price < cash, cash-only payment, guns take no coat space. The bank fallback and 25% fee are removed from engine, core, ABI and UI. ABI bumped to v6 (see implementation notes); fixtures 05, 10, 12 regenerated (byte-identical on a second run); task check passes. Dealers are now rolled before the arrival event, which is rolled after the dealer dialog.
<!-- SECTION:FINAL_SUMMARY:END -->
