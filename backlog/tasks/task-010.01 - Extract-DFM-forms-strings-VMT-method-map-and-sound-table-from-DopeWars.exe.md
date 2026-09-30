---
id: TASK-010.01
title: 'Extract DFM forms, strings, VMT method map and sound table from DopeWars.exe'
status: To Do
assignee: []
created_date: '2026-09-30 05:01'
labels:
  - reverse-engineering
dependencies: []
documentation:
  - docs/layer-boundaries.md
parent_task_id: TASK-010
priority: medium
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build a tested, repeatable extractor for `vendor/dopewars-1999/DopeWars.exe` (PE32, Delphi 4) so later decompilation starts from named code. It must recover the TPF0 form resources (components, captions, menu items, event handler names), the string table, the AppEvent-to-wav table (DWCashReg, DWCopGunShot, DWYourGunShot, DWYouHitByGun, DWCopHitByGun, DWCopChase, DWPoliceDog, DWMugged, DWDead, DWLastDay and their wav files), and the Delphi VMT published-method map (method name to virtual address), and emit a Ghidra label script. Outputs are derived from copyrighted material, so they go to a gitignored directory; only the tool and its tests are committed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A self-test built on a synthetic TPF0 blob passes and was written before the extractor
- [ ] #2 Running the extractor on the real exe prints the 10-row AppEvent to wav table
- [ ] #3 Running the extractor on the real exe lists the named forms and their event handlers, and emits a Ghidra label script
- [ ] #4 Extractor outputs are written under a gitignored directory and nothing derived from the exe is committed
<!-- AC:END -->
