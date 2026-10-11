---
id: TASK-013.01.02
title: Generalize the RE extractor to take a target exe and output directory
status: Done
assignee:
  - pythoninthegrass
created_date: '2026-10-11 04:02'
updated_date: '2026-10-11 04:23'
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
`tools/re/extract_beermat.py` and `taskfiles/re.yml` hardcode `vendor/dopewars-1999/DopeWars.exe` and its `re/` output. Parametrize both so the same pipeline (forms, strings, sound table, labels, Ghidra decompile and disasm) runs on a 2.1 binary or a 2.1 process dump, with the 1.2 defaults unchanged. The 2.1 exe is PC Guard-protected, so the extractor must detect `.PCGW32` sections and say plainly that code and VMT recovery are skipped, instead of emitting empty or misleading output. The DFM forms are readable without a dump and should come out, along with `strings.txt`. The 2.1 AppEvent sound table (38 wavs) is NOT readable statically (the strings sit in the encrypted sections), so it is deferred to TASK-013.01.03. The extracted 2.1 exe is `vendor/dopewars-2001/game/DopeWars.exe` (`task re:unwise`, TASK-013.01.01).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The extractor and the re: tasks accept an EXE and an OUT directory; with no arguments they behave exactly as before
- [x] #2 task re:test stays green and gains a case for a PC Guard-style exe, which must skip the VMT parse with an explicit message and exit zero
- [x] #3 Run against the 2.1 game exe, it writes the decoded forms and strings.txt to the chosen output directory; the sound table is deferred to TASK-013.01.03 because the AppEvent strings sit in the PC Guard-encrypted sections
- [x] #4 No 1.2 output under vendor/dopewars-1999/re/ changes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Tests first: synthetic PC Guard-style exe (.PCGW32 section plus one TPF0 form resource); assert main exits 0, writes forms and strings.txt, prints an explicit skip message, and writes no sounds.tsv, methods.tsv or labels.csv. Add a unit test for is_pcguard.
2. extract_beermat.py: add is_pcguard(pe); when true, main writes forms and strings.txt only, prints the skip message, exits 0. The 1.2 path stays byte-identical.
3. Leave EXPECTED_SOUNDS (1.2's 10 cues) alone; the 2.1 sound table needs the decrypted dump (TASK-013.01.03).
4. taskfiles/re.yml: add EXE and OUT vars defaulting to the 1.2 paths and use them in extract, apply-labels-check, decompile and disasm.
5. Verify: task re:test; checksum vendor/dopewars-1999/re/ before and after a default task re:extract; run on the 2.1 exe into vendor/dopewars-2001/re/ and confirm 25 DFMs plus strings.txt.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added is_pcguard() and a PC Guard branch in main (forms and strings.txt only, explicit skip message, exit 0). write_strings() split out of write_string_outputs() so both paths share it. re.yml gains EXE and OUT vars (1.2 defaults) used by extract, apply-labels-check, decompile and disasm; check_decompiled.py takes an optional re dir argument. Tests: FakePE-based cases in test_extract_beermat.py (30/30, unwise 7/7). Default task re:extract leaves vendor/dopewars-1999/re/ byte-identical (shasum of all 2639 files before and after). 2.1 exe: 25 DFMs and 21303 strings written to vendor/dopewars-2001/re/. The Ghidra tasks were only dry-run (task -n) with the new vars, not run against Ghidra.

Finding: the 2.1 AppEvent sound table is NOT readable statically (no AppEvents or .wav strings in the encrypted exe), so it moves to TASK-013.01.03 (decrypted dump).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added `is_pcguard()` to `tools/re/extract_beermat.py`. On a `.PCGW32` exe, `main` writes the forms and `strings.txt`, prints an explicit message that the sound table, VMT, methods and labels are skipped, and exits 0. `write_strings()` is split out of `write_string_outputs()` so both paths share it. `taskfiles/re.yml` gains `EXE` and `OUT` vars (1.2 defaults) used by `extract`, `apply-labels-check`, `decompile` and `disasm`, and `check_decompiled.py` takes an optional re-dir argument. `task re:test` gains two fake-PE cases (30/30, unwise 7/7). A default `task re:extract` leaves all 2639 files under `vendor/dopewars-1999/re/` byte-identical. Run on the 2.1 exe it wrote 25 DFMs and 21303 strings to `vendor/dopewars-2001/re/`. The Ghidra tasks were only dry-run with the new vars. The 2.1 sound table is not readable statically and moves to TASK-013.01.03.
<!-- SECTION:FINAL_SUMMARY:END -->
