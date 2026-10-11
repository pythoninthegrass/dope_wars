---
id: TASK-013.01.01
title: Extract the Wise installer payload for Dope Wars 2.1
status: Done
assignee: []
created_date: '2026-10-11 04:02'
updated_date: '2026-10-11 04:11'
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
modified_files:
  - tools/re/unwise.py
  - tools/re/test_unwise.py
  - taskfiles/re.yml
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
- [x] #1 task re:unwise writes DopeWars.exe, cities.txt, oldlady.txt and the Sounds directory into vendor/dopewars-2001/game/
- [x] #2 The Gator stub and the installer's own helper executables are never written
- [x] #3 Re-running the task is idempotent and leaves identical files
- [x] #4 A self-test builds a synthetic Wise-style payload (raw deflate streams) and checks the extractor against it without any vendor file, and is wired into task re:test
- [x] #5 docs/beermat-2.1-re.md names the command and the output directory
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added `tools/re/unwise.py` and `task re:unwise`. The tool scans dw21.exe for raw-deflate streams that are followed by a matching little-endian CRC32 (66 found), takes the stream containing the Wise script, reads each `%MAINDIR%\` install record (stream extent at -0x28/-0x24 and size at -0x1c from the path), and pairs records with streams by size and extent in stream order. Only an allowlist is written: DopeWars.exe, cities.txt, oldlady.txt and Sounds/*.wav. The Gator stub, WiseUpdt.exe, Olchk32.dll, the font and License.txt are never written. Re-runs compare bytes and write nothing when unchanged. Real run: 41 files, DopeWars.exe 1,487,360 bytes (matches the PE32 stream at 0xe0acd), second run 0 written.\n\nCorrection: the installer carries 38 wavs, not 39 (38 RIFF streams, 38 unique Sounds records). docs/beermat-2.1-re.md is fixed; TASK-013.01.02, 013.01.03 and 013.02.17 still say 39.\n\nSelf-test `tools/re/test_unwise.py` (7 cases, synthetic payload, no vendor files) is wired into `task re:test`.
<!-- SECTION:FINAL_SUMMARY:END -->
