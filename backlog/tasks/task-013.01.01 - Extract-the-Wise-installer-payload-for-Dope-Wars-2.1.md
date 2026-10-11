---
id: TASK-013.01.01
title: Extract the Wise installer payload for Dope Wars 2.1
status: To Do
assignee: []
created_date: '2026-10-11 04:02'
labels:
  - beermat-2.1
  - reverse-engineering
milestone: m-4
dependencies: []
references:
  - tools/re/extract_beermat.py
  - taskfiles/re.yml
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.01
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`vendor/dopewars-2001/dw21.exe` is a Wise installer: a PE32 stub followed by raw-deflate streams (no zip, 7z or NSIS container, so `7z l` rejects it). The game exe is a 1.48 MB stream at file offset 0xe0acd; `cities.txt`, `oldlady.txt` and 39 wavs are further streams. Add a tool that finds and inflates these streams and writes the game files to the gitignored `vendor/dopewars-2001/game/`, so the later RE and CrossOver tasks have a reproducible input. The installer's Gator adware stub (`Trickler_PIC_Beermat_Dopewars.exe`) must never be written out or run. Follows the layout of the existing tools: Python run through `uv`, a `task re:` target, and a self-test that needs no vendor files.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 task re:unwise writes DopeWars.exe, cities.txt, oldlady.txt and the Sounds directory into vendor/dopewars-2001/game/
- [ ] #2 The Gator stub and the installer's own helper executables are never written
- [ ] #3 Re-running the task is idempotent and leaves identical files
- [ ] #4 A self-test builds a synthetic Wise-style payload (raw deflate streams) and checks the extractor against it without any vendor file, and is wired into task re:test
- [ ] #5 docs/beermat-2.1-re.md names the command and the output directory
<!-- AC:END -->
