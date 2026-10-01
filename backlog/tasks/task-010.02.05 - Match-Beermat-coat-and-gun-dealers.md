---
id: TASK-010.02.05
title: Match Beermat coat and gun dealers
status: To Do
assignee: []
created_date: '2026-10-01 06:17'
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
- [ ] #1 Dealer chance, split, prices and pockets match the values above, with failing tests first
- [ ] #2 Offers are only presented when price < cash; the bank fallback and fee are removed
- [ ] #3 A gun uses no coat space
- [ ] #4 Fixtures regenerated and task check passes (ABI version bumped if the surface changes)
- [ ] #5 docs/beermat-re.md marks M-05 as match
<!-- AC:END -->
