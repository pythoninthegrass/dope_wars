---
id: TASK-013.01.03
title: Unpack the 2.1 game in CrossOver and dump the decrypted process
status: To Do
assignee: []
created_date: '2026-10-11 04:02'
updated_date: '2026-10-11 04:23'
labels:
  - beermat-2.1
  - reverse-engineering
milestone: m-4
dependencies:
  - TASK-013.01.01
  - TASK-013.01.02
references:
  - CLAUDE.local.md
  - taskfiles/re.yml
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.01
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 2.1 game exe is encrypted by PC Guard and only decrypts in memory, so its code can be decompiled only from a process dump. Plan: create a dedicated 32-bit CrossOver bottle (CrossOver.app is installed on the dev Mac), copy in the files extracted by TASK-013.01.01 rather than running the installer (never run the Gator stub), start the game, enter the license key from the gitignored `vendor/dopewars-2001/key.txt`, and confirm the registered-only features unlock (15/60/90 day games, Price History). Dump the live process with Scylla x86 inside the bottle, with the import table rebuilt. Fallbacks, in order: a `winedbg` minidump, then the Windows oracle described in CLAUDE.local.md. Then make `task re:decompile` and `task re:disasm` accept the dump (via TASK-013.01.02's parameters) so the existing Ghidra pipeline produces a 2.1 `index.tsv`. The key and bottle path never go into committed files.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The game runs in the CrossOver bottle and reports itself as registered
- [ ] #2 A dump exists in gitignored vendor/dopewars-2001/ whose code sections are decrypted (readable x86, entropy well below 8.0) and which Ghidra imports
- [ ] #3 task re:decompile and task re:disasm accept the dump and produce a 2.1 index.tsv plus per-function C files
- [ ] #4 The 2.1 sound table (38 wavs) and the string table resolve to their handlers in the dump
- [ ] #5 docs/beermat-2.1-re.md records the reproducible steps, the tool used and any fallback taken, with no key contents, bottle path or CLAUDE.local.md infra
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From TASK-013.01.02: the 2.1 AppEvent sound table is not readable from the static exe (no AppEvents or .wav strings; the PC Guard sections are encrypted), so it can only be recovered from the dump. extract_beermat.py's EXPECTED_SOUNDS is the 10 cues of 1.2 and must be generalized to the 38-wav 2.1 table before parse_sounds can validate a 2.1 dump.
<!-- SECTION:NOTES:END -->
