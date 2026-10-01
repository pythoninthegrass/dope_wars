---
id: TASK-010.01.04
title: 'Emit Ghidra labels and ApplyLabels.java with re:apply-labels-check'
status: To Do
assignee: []
created_date: '2026-10-01 01:49'
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
- [ ] #1 A test for the label-name sanitizer and CSV rows was written first, observed failing, then passes
- [ ] #2 `task re:apply-labels-check` imports the real exe into a throwaway Ghidra project, applies OUT/labels.csv, exits 0 with no ERROR script lines, and logs the applied label count
- [ ] #3 `ruff format --check tools/re` passes and nothing derived from the exe is committed
- [ ] #4 TASK-010.01 acceptance criteria are checked and the task is set Done with implementationNotes
<!-- AC:END -->
