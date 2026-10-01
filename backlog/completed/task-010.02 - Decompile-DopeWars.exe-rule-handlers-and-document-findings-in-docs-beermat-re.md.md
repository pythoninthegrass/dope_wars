---
id: TASK-010.02
title: >-
  Decompile DopeWars.exe rule handlers and document findings in
  docs/beermat-re.md
status: Done
assignee:
  - Claude
created_date: '2026-09-30 05:01'
updated_date: '2026-10-01 19:37'
labels:
  - reverse-engineering
dependencies: []
documentation:
  - docs/gameplay.md
  - docs/parity-deltas.md
parent_task_id: TASK-010
priority: medium
ordinal: 21000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Using Ghidra headless (installed via Homebrew; wired into the Taskfile) with the label script from the extraction subtask, decompile the game's rule handlers and record the real constants and formulas in `docs/beermat-re.md`, each with its virtual address. Cover: price generation and price events, per-location drug availability, the arrival-event table, chase start chance, deputy count, run chance, fight hit and damage math, cop tiers, coat and gun dealer prices and roll rates, interest and loan rules, last-day and scoring rules, the exact trigger point of every sound, and the default value of the AllowSound setting. Diff each rule against `index.html` (`<script id="engine">`) and `core/src/*.mojo`, classify each delta as match, mismatch or intentional, and confirm anything the decompile leaves ambiguous on the live oracle (see CLAUDE.local.md). Each mismatch becomes its own follow-up subtask awaiting Lance's approval.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A Taskfile target runs Ghidra headless against the exe and exports decompiled handlers to a gitignored directory
- [x] #2 docs/beermat-re.md records each rule with its virtual address and its match, mismatch or intentional classification against the current engine
- [x] #3 The sound trigger points and the AllowSound default are documented with evidence
- [x] #4 Each mismatch has its own follow-up subtask; the city names and the location model are recorded as intentional in docs/parity-deltas.md
- [x] #5 No infra details from CLAUDE.local.md appear in the doc
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add `re:decompile` Taskfile target (deps: extract, _install-ghidra, _install-java) running Ghidra headless with ApplyLabels.java then a new tools/re/ghidra/ExportDecompiled.java; exports one C file per function plus an address index to vendor/dopewars-1999/re/decompiled/ (gitignored via vendor/dopewars-1999/). Write a failing check first (output non-empty, address-tagged).
2. Locate handlers via the VMT published-method map, labels, wav/string refs and constant scans: price gen and events, per-location availability, arrival events, chase chance, deputy count, run chance, fight hit/damage, cop tiers, dealer prices and roll rates, interest/loan, last day/scoring, sound triggers, AllowSound default.
3. Write docs/beermat-re.md: each rule with virtual address, formula/constant, and match/mismatch/intentional classification vs index.html engine and core/src/*.mojo. No infra details from CLAUDE.local.md.
4. Confirm ambiguous rules on the live oracle via chrome-devtools-axi.
5. Record city names and location model as intentional in docs/parity-deltas.md.
6. Draft one follow-up subtask per mismatch; present to Lance for approval before creating.
7. markdownlint, tick ACs, conventional commits, no Claude attribution; commit .serena changes separately.
Risk: Delphi 4 decompile noise (register calling convention, float/Comp); oracle may be needed to confirm formulas.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Step 1 done: `task re:decompile` (tools/re/ghidra/ExportDecompiled.java, tools/re/check_decompiled.py) exports 2467 functions to vendor/dopewars-1999/re/decompiled/ in ~30s; check failed before the export existed, passes after.

Step 1b: auto-analysis left ~4.6KB of Form1 code (FormCreate helper 0045c260 with the drug table, ReadCities 0045c6d8) undisassembled; added tools/re/ghidra/DiscoverFunctions.java (prologue + call-target discovery) and extended check_decompiled.py to fail when a labeled method is not exported. Export is now 2626 functions. Added `task re:disasm -- <va,...>` (DumpListing.java) for x87 constants the decompiler drops.

Step 2 findings gathered (handlers: 0045c260 drug table, 0045d120 prices, 0045d428 travel, 0045d6e4 chase start, 0045d96c events+dealers, 0045a878/0045a9f8/0045ab38 chase actions, 0045e3a4/0045e3d4 interest, 0045f3a8 first-run init incl. AllowSound=1). Nearly every engine rule differs from Beermat; writing docs/beermat-re.md next.

Steps 3-5 done: docs/beermat-re.md written (13 mismatches M-01..M-13, sounds table, AllowSound default on). Oracle confirmed: New Game (not Finances) is locked until day 6; debt rounding is ties-to-even (7320.5 -> 7320); Fight greyed with no gun; police-dog and chase strings match. Section 5 added to docs/parity-deltas.md (city names and location model intentional). AC#4 still open: follow-up subtasks M-01..M-13 drafted, awaiting Lance's approval. Nothing committed yet.

Follow-up subtasks TASK-010.02.01 to .11 created with Lance's approval (M-07..M-09 merged into .07, so 11 subtasks for 13 mismatches).
<!-- SECTION:NOTES:END -->
