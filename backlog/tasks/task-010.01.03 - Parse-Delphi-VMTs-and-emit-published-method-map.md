---
id: TASK-010.01.03
title: Parse Delphi VMTs and emit published-method map
status: To Do
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
- [ ] #1 A synthetic fake-VMT test was written first, observed failing, then passes
- [ ] #2 Running the extractor on the real exe writes OUT/methods.tsv and prints the class count and method count
- [ ] #3 Handler names found in the decoded forms resolve to a method VA in methods.tsv
- [ ] #4 `ruff format --check tools/re` passes and nothing derived from the exe is committed
<!-- AC:END -->
