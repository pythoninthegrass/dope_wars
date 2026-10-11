---
id: TASK-013.02.15
title: Price History window
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.03
documentation:
  - docs/beermat-2.1-re.md
  - docs/abi-contract.md
  - docs/parity-deltas.md
parent_task_id: TASK-013.02
ordinal: 68000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2.0 added a Price History window (registered only in the original): a per-drug chart chosen from a drop-down, with a small view and a 3D view with rotate, tilt and zoom, opened from the "Pri&ce History" button, the drug list context menu, or the Options menu. Port a simple version: the core records each drug's price at every arrival (a per-drug series, which is rules state and saved), and the Godot window draws a 2D line chart for a selected drug. The 3D chart is not required; record it as an intentional delta in docs/parity-deltas.md. All players get the window, so registration gating is dropped as well. Needs the pricing slice for the previous-price plumbing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The core records a price series per drug for the current game, exposed through the ABI with the usual two-call length-then-fill pattern, and it round-trips through save and load
- [ ] #2 A Price History window shows the series for a drug picked from a selector, reachable from the main window button
- [ ] #3 The 3D view and registration gate are recorded as intentional deltas in docs/parity-deltas.md
- [ ] #4 Mojo tests cover series recording and reset on new game; game:ui-test covers opening the window and switching drugs
<!-- AC:END -->
