---
id: TASK-010.01.04
title: 'Emit Ghidra labels and ApplyLabels.java with re:apply-labels-check'
status: Done
assignee:
  - '@claude'
created_date: '2026-10-01 01:49'
updated_date: '2026-10-01 03:40'
labels:
  - reverse-engineering
dependencies:
  - TASK-010.01.03
parent_task_id: TASK-010.01
priority: medium
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Final slice of TASK-010.01; depends on the VMT method map subtask. Write OUT/labels.csv (`VA hex,label`) from methods.tsv, with `Class_Method` labels sanitized to [A-Za-z0-9_] plus one `Class_VMT` per VMT. Add tools/re/ghidra/ApplyLabels.java (Java GhidraScript; Ghidra 12.1.4 ships PyGhidra, not Jython): it reads the CSV path from the script arguments; per row it calls createLabel(addr, name, true), and for Class_Method rows also disassemble(addr) and createFunction(addr, name) when no function exists. Add `re:apply-labels-check` to taskfiles/re.yml (desc, no YAML comments): it depends on re:extract, re:_install-ghidra and re:_install-java and runs `{{.GHIDRA_RUN}} {{.GHIDRA_HEADLESS}} <tmpproj> dw -import vendor/dopewars-1999/DopeWars.exe -scriptPath tools/re/ghidra -postScript ApplyLabels.java OUT/labels.csv -deleteProject`. Do not use brew, sudo or dnf; wrap any long-running command in `timeout`, because a previous agent run hung 21 minutes on `brew list ghidra`. When this subtask is done, finish TASK-010.01: check its acceptance criteria, add implementationNotes with the exact commands run and a result summary (form count, method count, sound row count, labels applied), and set it Done. Do not start TASK-010.02.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A test for the label-name sanitizer and CSV rows was written first, observed failing, then passes
- [x] #2 `task re:apply-labels-check` imports the real exe into a throwaway Ghidra project, applies OUT/labels.csv, exits 0 with no ERROR script lines, and logs the applied label count
- [x] #3 `ruff format --check tools/re` passes and nothing derived from the exe is committed
- [x] #4 TASK-010.01 acceptance criteria are checked and the task is set Done with implementationNotes
<!-- AC:END -->



## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Tests first in tools/re/test_extract_beermat.py for sanitize_label and labels rows (Class_Method plus one Class_VMT per VMT); run, confirm failing.
2. Implement sanitize_label, label_rows, write_labels in extract_beermat.py; main() writes vendor/dopewars-1999/re/labels.csv and prints the row count.
3. Add tools/re/ghidra/ApplyLabels.java (reads CSV path from script args; createLabel(addr, name, true); for Class_Method rows disassemble + createFunction when none exists; logs applied count).
4. Add re:apply-labels-check to taskfiles/re.yml (desc, no comments; deps extract, _install-ghidra, _install-java). Per user approval, replace the darwin `$(brew --prefix ghidra)` in GHIDRA_HEADLESS with the absolute path /opt/homebrew/opt/ghidra/libexec/support/analyzeHeadless.
5. Verify under timeout: task re:test, task re:apply-labels-check (exit 0, no ERROR lines, applied count logged), ruff format --check tools/re, git status shows nothing exe-derived.
6. Check AC, then finish TASK-010.01 (check its AC, implementationNotes with commands and counts, Done). Do not start TASK-010.02.
7. Conventional commit with no Claude attribution (user global rule).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tests written first (3 new, observed failing 25/28), then passing 28/28. task re:apply-labels-check: 244 labels applied, 40 functions created, 0 failures, exit 0. Two fixes found while running: Ghidra's launch.sh stalls (SIGTTIN) under `timeout` unless stdin is </dev/null; go-task's shell returned 1 for `! cmd | rg -q`, so an explicit `if` is used. GHIDRA_HEADLESS on darwin now uses the absolute /opt/homebrew/opt/ghidra path (user-approved). Commit 6823c59.
<!-- SECTION:NOTES:END -->
