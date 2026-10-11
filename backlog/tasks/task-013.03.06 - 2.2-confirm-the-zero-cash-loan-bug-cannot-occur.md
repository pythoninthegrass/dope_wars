---
id: TASK-013.03.06
title: '2.2: confirm the zero-cash loan bug cannot occur'
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
  - changelog-only
milestone: m-4
dependencies:
  - TASK-013.02.04
references:
  - vendor/CHANGELOG.md
parent_task_id: TASK-013.03
ordinal: 76000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Changelog-only (no 2.2 binary available): 2.2 "fixed the zero cash loan bug". The notes do not describe it; plausibly borrowing or repaying behaved wrongly with zero cash. Check the 2.1 dump (TASK-013.01.04) for the actual defect if it is visible, then write Mojo tests that borrow and repay with zero cash and at other boundaries (zero debt, debt at the 1,000,000 cap) and make sure the port handles them sanely. Record what was found, or that the defect could not be identified, in docs/parity-deltas.md.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Mojo tests cover borrow and repay at zero cash, zero debt and the cap, and pass
- [ ] #2 The defect is described in docs/beermat-2.1-re.md if visible in the 2.1 dump, otherwise recorded as unidentified
- [ ] #3 docs/parity-deltas.md notes the outcome as changelog-only
<!-- AC:END -->
