---
id: TASK-010.02.09
title: Lock New Game until day 6 like Beermat
status: Done
assignee: []
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 17:54'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-11 in docs/beermat-re.md (decompile at 0x0045ceb8 and 0x0045d428). In the real game the New Game button and the File > New menu item are disabled from the start of a game until the first travel made on day 5, so a restart is possible from day 6. Finances is enabled from day 1. Confirmed on the live oracle. The engine allows New Game at any time. This is presentation-layer behaviour: decide with Lance whether it belongs in the core (a flag in the ABI) or only in game/presentation and the prototype UI.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 New Game and File > New are disabled on days 1-5 and enabled from day 6, in the prototype and the Godot build, with a failing UI test first
- [ ] #2 Finances stays enabled from day 1
- [ ] #3 Where the rule lives (core or presentation) is recorded in docs/layer-boundaries.md or docs/architecture.md
- [ ] #4 docs/beermat-re.md marks M-11 as match
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Resolved as a deliberate divergence rather than implementing the gate: Lance prefers being able to start a new game at any time. Recorded as parity-deltas.md section 6; docs/beermat-re.md M-11 and its mismatch table entry now point there instead of listing it as an open mismatch to fix. No gating code added to the prototype or Godot port.
<!-- SECTION:FINAL_SUMMARY:END -->
