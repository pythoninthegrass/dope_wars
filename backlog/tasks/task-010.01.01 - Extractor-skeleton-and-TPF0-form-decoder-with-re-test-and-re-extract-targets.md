---
id: TASK-010.01.01
title: 'Extractor skeleton and TPF0 form decoder with re:test and re:extract targets'
status: Done
assignee: []
created_date: '2026-10-01 01:49'
updated_date: '2026-10-01 01:54'
labels:
  - reverse-engineering
dependencies: []
parent_task_id: TASK-010.01
priority: medium
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
First slice of TASK-010.01. Create tools/re/extract_beermat.py (PEP 723 header, pefile only, requires-python >=3.13,<3.14, modeled on tools/validate_game_boundary.py) and tools/re/test_extract_beermat.py, plus taskfiles/re.yml targets `re:test` and `re:extract` (each with a desc, no YAML comments). The extractor decodes the binary TPF0 form resources (RCDATA type 0xa, read via pefile's resource directory) of vendor/dopewars-1999/DopeWars.exe into text DFM under OUT/forms/<FormName>.dfm, with handlers shown as `OnClick = BuyBtnClick`. The test is written first, fails, then the decoder makes it pass. Later subtasks (strings and sound table, VMT method map, Ghidra labels) build on this file; do not implement them here. Outputs derived from the exe go under vendor/dopewars-1999/re/ (gitignored); commit only tools/re/**, taskfiles/re.yml and docs. Follow the parent task's rules (TASK-010.01 plan steps 1-6 and 11).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A synthetic TPF0 blob test (class name, object name, integer, string, identifier handler, nested item collection, one child component, list terminator) was written first, observed failing, then passes
- [x] #2 `uv run tools/re/test_extract_beermat.py` exits non-zero on failure and prints a one-line pass count
- [x] #3 `--exe PATH` defaults to vendor/dopewars-1999/DopeWars.exe, `DW_EXE` overrides the default, `--out DIR` defaults to vendor/dopewars-1999/re/
- [x] #4 The extractor exits 2 with a clear message when the exe is missing
- [x] #5 Running the extractor on the real exe writes one .dfm per form under OUT/forms and lists the named forms with their event handlers
- [x] #6 `task re:test` and `task re:extract` exist, each with a desc
- [x] #7 `ruff format --check tools/re` passes and nothing derived from the exe is committed
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Test written first; `uv run tools/re/test_extract_beermat.py` failed with ModuleNotFoundError before the extractor existed, then passed 10/10. `uv run tools/re/extract_beermat.py` on the real exe wrote 8 forms (AboutDlg, AmountDlg, BuyDlg, CopChaseDlg, FinanceDlg, Form1, IntroDlg, ViewHiScoreDlg) and listed their handlers. `DW_EXE=/nonexistent` exits 2. `task re:test` and `task re:extract` run; `ruff format --check tools/re` passes; `git check-ignore` confirms OUT is ignored. First `uv run` took about 50s (package fetch); later runs are fast.
<!-- SECTION:NOTES:END -->
