---
id: TASK-010.02.07
title: 'Match Beermat chase resolution (run, stay, fight, win reward)'
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
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatches M-07, M-08 and M-09 in docs/beermat-re.md (decompile at 0x0045a878, 0x0045a9f8, 0x0045ab38, 0x0045a834). Real rules: Run escapes when Random(6) < 3 (50%, regardless of guns); otherwise the cops fire. Stay: the cops fire. Cops fire = Random(2): 1 hits for Random(11)+5 (5-15) damage, health floored at 0, 0 misses. Fight (needs at least one gun): the player's shot kills one deputy with probability 1/2; the chase is won when the deputy count drops below 0 (so deputies+1 kills); the cops return fire only while the count is still >= 0. Winning gives +1 gun and cash of (Random(1000)+1000) + Random(1500), then offers a doctor for the first term (1000-1999) that sets health to 100. Deputy count (2-11) already matches. Remove the attack/defend rating model and the aggressor flag.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Run, Stay, Fight, cop damage and the win condition match the rules above, with failing tests first
- [ ] #2 A chase win grants +1 gun and the cash reward, and offers the doctor at the stated price
- [ ] #3 The Stay button makes the cops fire
- [ ] #4 Fixtures regenerated and task check passes (ABI version bumped if the surface changes)
- [ ] #5 docs/beermat-re.md marks M-07, M-08 and M-09 as match
<!-- AC:END -->
