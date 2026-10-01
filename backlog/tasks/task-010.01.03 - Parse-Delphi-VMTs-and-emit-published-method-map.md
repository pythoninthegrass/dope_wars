---
id: TASK-010.01.03
title: Parse Delphi VMTs and emit published-method map
status: Done
assignee: []
created_date: '2026-10-01 01:49'
labels:
  - reverse-engineering
dependencies:
  - TASK-010.01.01
parent_task_id: TASK-010.01
priority: medium
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Third slice of TASK-010.01; depends on the extractor skeleton subtask. Extend tools/re/extract_beermat.py and its test to find Delphi 4 VMTs and read their published method tables. Delphi 4 layout, offsets from the VMT address: selfPtr -76, intfTable -72, autoTable -68, initTable -64, typeInfo -60, fieldTable -56, methodTable -52, dynamicTable -48, className -44 (pointer to shortstring), instanceSize -40, parent -36, virtual methods from +0. Find VMTs by scanning CODE and DATA for a dword equal to its own address + 76 (ImageBase 0x400000; sections CODE 0x1000, DATA 0x62000, BSS 0x6d000). Published method table: word count, then per entry `word size; dword code VA; shortstring name`. Convert VA to file offset through the PE section table. Write the test first against a synthetic 128-byte fake VMT with a published method table, watch it fail, then implement. Output OUT/methods.tsv (`class<TAB>method<TAB>VA hex`) under the gitignored vendor/dopewars-1999/re/. Prior probing found 64 published methods across 9 classes (TForm1, TBuyDlg, TAmountDlg, TFinanceDlg, ...), and handler names like BuyBtnClick and SellBtnClick match the form contents. Do not start the Ghidra subtask.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A synthetic fake-VMT test was written first, observed failing, then passes
- [x] #2 Running the extractor on the real exe writes OUT/methods.tsv and prints the class count and method count
- [x] #3 Handler names found in the decoded forms resolve to a method VA in methods.tsv
- [x] #4 `ruff format --check tools/re` passes and nothing derived from the exe is committed
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Extended tools/re/extract_beermat.py with an Image section-map reader, find_vmts, read_vmt, read_published_methods, collect_methods, unresolved_handlers and write_methods. The 7 new self-tests (synthetic fake VMT with a published method table) were written first and observed failing, then pass with the earlier tests (25/25). On the real exe the extractor finds 180 VMTs, 8 classes with 64 published methods (TForm1 35, TBuyDlg 5, TCopChaseDlg 5, TFinanceDlg 5, TIntroDlg 5, TAmountDlg 4, TViewHiScoreDlg 4, TBltBitmap 1) and writes methods.tsv. TAboutDlg has a VMT but no published methods, so it is the ninth class from the earlier probe. All 52 event handlers in the decoded forms resolve to a method VA, and the extractor exits non-zero if any does not. ruff format --check tools/re passes; nothing derived from the exe is committed.
<!-- SECTION:FINAL_SUMMARY:END -->
