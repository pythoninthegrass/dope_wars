---
id: TASK-013.01.02
title: Generalize the RE extractor to take a target exe and output directory
status: To Do
assignee: []
created_date: '2026-10-11 04:02'
updated_date: '2026-10-11 04:15'
labels:
  - beermat-2.1
  - reverse-engineering
milestone: m-4
dependencies: []
references:
  - tools/re/extract_beermat.py
  - tools/re/test_extract_beermat.py
  - taskfiles/re.yml
parent_task_id: TASK-013.01
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`tools/re/extract_beermat.py` and `taskfiles/re.yml` hardcode `vendor/dopewars-1999/DopeWars.exe` and its `re/` output. Parametrize both so the same pipeline (forms, strings, sound table, labels, Ghidra decompile and disasm) runs on a 2.1 binary or a 2.1 process dump, with the 1.2 defaults unchanged. The 2.1 exe is PC Guard-protected, so the extractor must detect `.PCGW32` sections and say plainly that code and VMT recovery are skipped, instead of emitting empty or misleading output. The 2.1 AppEvent sound table (38 wavs) and DFM forms are readable without a dump and should come out. The extracted 2.1 exe is `vendor/dopewars-2001/game/DopeWars.exe` (`task re:unwise`, TASK-013.01.01).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The extractor and the re: tasks accept an EXE and an OUT directory; with no arguments they behave exactly as before
- [ ] #2 task re:test stays green and gains a case for a PC Guard-style exe, which must skip the VMT parse with an explicit message and exit zero
- [ ] #3 Run against the 2.1 game exe, it writes the decoded forms and the string and sound tables to the chosen output directory
- [ ] #4 No 1.2 output under vendor/dopewars-1999/re/ changes
<!-- AC:END -->
