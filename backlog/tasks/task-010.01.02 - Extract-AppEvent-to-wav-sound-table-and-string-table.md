---
id: TASK-010.01.02
title: Extract AppEvent to wav sound table and string table
status: Done
assignee: []
created_date: '2026-10-01 01:49'
labels:
  - reverse-engineering
dependencies:
  - TASK-010.01.01
parent_task_id: TASK-010.01
priority: medium
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Second slice of TASK-010.01; depends on the extractor skeleton subtask. Extend tools/re/extract_beermat.py and its test to recover the AppEvent-to-wav table and every printable string of 4+ characters with its VA. Per event the exe strings read `<file>.wav`, `AppEvents\Schemes\Apps\DopeWars\<Event>\.current`, `<label>`, `AppEvents\EventLabels\<Event>`; each wav pairs with the Event in the entry that follows it. Expected exactly 10 rows: DWCopGunShot gun.wav; DWYourGunShot gun2.wav; DWYouHitByGun youhit.wav; DWCopHitByGun cophit.wav; DWCopChase siren.wav; DWPoliceDog bark.wav; DWCashReg cashreg.wav; DWMugged hrdpunch.wav; DWDead wasted.wav; DWLastDay uhoh.wav (the shipped file is Siren.wav; match case-insensitively). Write the test first (synthetic string blob), watch it fail, then implement. Outputs go to OUT/sounds.tsv (`event<TAB>wav<TAB>label`) and OUT/strings.txt under the gitignored vendor/dopewars-1999/re/. Do not start the VMT or Ghidra subtasks.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A synthetic-string test covering the entry pairing was written first, observed failing, then passes
- [x] #2 Running the extractor on the real exe prints the 10-row AppEvent to wav table and writes OUT/sounds.tsv
- [x] #3 The extractor exits non-zero if any of the 10 rows is missing, and the test asserts all 10 rows
- [x] #4 OUT/strings.txt lists every printable string of 4+ characters with its VA
- [x] #5 `ruff format --check tools/re` passes and nothing derived from the exe is committed
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Extended tools/re/extract_beermat.py with scan_strings, parse_sounds and write_string_outputs. The 8 new self-tests (synthetic string blob, pairing, case-insensitive wav match, missing row, wrong wav, output files, non-zero exit) were written first and observed failing, then pass with the 10 existing tests (18/18). On the real exe the extractor prints the 10-row AppEvent to wav table and writes sounds.tsv plus strings.txt (7624 strings with VA, e.g. AllowSound at 0045C5D8, 0045F7B8 and 004602B0) under the gitignored vendor/dopewars-1999/re/. The extractor exits 1 if any row is missing or mismatched. ruff format --check tools/re passes; nothing derived from the exe is committed.
<!-- SECTION:FINAL_SUMMARY:END -->
