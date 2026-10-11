---
id: TASK-013.03.02
title: '2.2: bank interest rate reduced to 3%'
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
  - changelog-only
milestone: m-4
dependencies:
  - TASK-013.02.01
references:
  - vendor/CHANGELOG.md
  - core/src/interest.mojo
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-013.03
ordinal: 72000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Changelog-only (no 2.2 binary available): 2.2 reduced the bank interest rate to 3% ("play changes"). The 1.2 rate is 5% a day (`bank_after_interest` in `core/src/interest.mojo`, with extended-precision rounding documented in docs/beermat-re.md M-10). Change the rate to 3% and work out the rounding behaviour for the new constant, using the same ties-to-even integer method and validating against an exact emulation as M-10 did, unless the 2.1 dump shows the original arithmetic differently. Record the choice in docs/parity-deltas.md as changelog-only.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Bank balances grow at 3% a day with rounding defined and tested, including tie cases
- [ ] #2 The 1.2 and 2.1 rate stays reproducible only if kept behind a documented constant; no dead code is left otherwise
- [ ] #3 docs/parity-deltas.md records the change as changelog-only with no binary evidence
<!-- AC:END -->
