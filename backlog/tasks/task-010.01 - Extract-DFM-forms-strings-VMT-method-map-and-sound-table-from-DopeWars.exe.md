---
id: TASK-010.01
title: 'Extract DFM forms, strings, VMT method map and sound table from DopeWars.exe'
status: In Progress
assignee: []
created_date: '2026-09-30 05:01'
updated_date: '2026-10-01 03:02'
labels:
  - reverse-engineering
dependencies: []
documentation:
  - docs/layer-boundaries.md
parent_task_id: TASK-010
priority: medium
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build a tested, repeatable extractor for `vendor/dopewars-1999/DopeWars.exe` (PE32, Delphi 4) so later decompilation starts from named code. It must recover the TPF0 form resources (components, captions, menu items, event handler names), the string table, the AppEvent-to-wav table (DWCashReg, DWCopGunShot, DWYourGunShot, DWYouHitByGun, DWCopHitByGun, DWCopChase, DWPoliceDog, DWMugged, DWDead, DWLastDay and their wav files), and the Delphi VMT published-method map (method name to virtual address), and emit a Ghidra label script. Outputs are derived from copyrighted material, so they go to a gitignored directory; only the tool and its tests are committed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A self-test built on a synthetic TPF0 blob passes and was written before the extractor
- [ ] #2 Running the extractor on the real exe prints the 10-row AppEvent to wav table
- [ ] #3 Running the extractor on the real exe lists the named forms and their event handlers, and emits a Ghidra label script
- [ ] #4 Extractor outputs are written under a gitignored directory and nothing derived from the exe is committed
- [ ] #5 `task re:test` runs the self-test and `task re:extract` runs the extractor; both targets have a desc
- [ ] #6 `task re:apply-labels-check` imports the real exe into a throwaway Ghidra project, applies OUT/labels.csv via tools/re/ghidra/ApplyLabels.java, exits 0 with no ERROR script lines, and logs the applied label count
- [ ] #7 `ruff format --check tools/re` passes
- [ ] #8 tools/re/extract_beermat.py exits 2 with a clear message when the exe is missing
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Toolchain (all via mise/uv, no manual install): `uv` and `task` come from `.tool-versions` (`mise install`). On a non-interactive SSH shell put `~/.local/bin` first on PATH and use `mise exec task@3.49.1 -- task ...` if `task` is not on PATH. Ghidra and the JDK come from the internal `re:_install-ghidra` / `re:_install-java` tasks in taskfiles/re.yml (`~/.local/opt/ghidra` on Linux); they are dependencies of `re:apply-labels-check`. Do not use sudo, dnf or brew.
2. Worktree setup: `vendor/dopewars-1999/` is gitignored and absent in a gnhf worktree. Copy it from the main checkout with `cp -R <main-checkout>/vendor/dopewars-1999 vendor/` (about 800 KB; do not symlink, the ignore rule targets a directory). Confirm `git status --short` stays clean and `git check-ignore -v vendor/dopewars-1999/DopeWars.exe` reports the rule. If the prompt gives no main checkout path, use `$DW_EXE` if set, else stop and report the missing input.
3. Files (mirror tools/validate_game_boundary.py and tools/test_validate_game_boundary.py: `#!/usr/bin/env -S uv run --script`, PEP 723 header, `requires-python = ">=3.13,<3.14"`):
   - tools/re/extract_beermat.py (dependency: `pefile` only, in the PEP 723 header)
   - tools/re/test_extract_beermat.py (run with `uv run tools/re/test_extract_beermat.py`; exits non-zero on failure and prints a one-line pass count)
   - tools/re/ghidra/ApplyLabels.java (Java GhidraScript; Ghidra 12.1.4 ships PyGhidra, not Jython, so no .py script)
   - taskfiles/re.yml targets, each with a `desc` and no YAML comments: `re:test` (self-test), `re:extract` (extractor), `re:apply-labels-check` (step 10)
4. Input and output: CLI `--exe PATH`, default `vendor/dopewars-1999/DopeWars.exe`; env `DW_EXE` overrides the default. Exit 2 with a clear message when the exe is missing. `--out DIR`, default `vendor/dopewars-1999/re/` (`OUT` below), already covered by the `vendor/dopewars-1999/` ignore rule.
5. Binary facts (verified): PE32, ImageBase 0x400000; sections CODE 0x1000, DATA 0x62000, BSS 0x6d000, .idata 0x6e000, .rsrc 0x7a000; resource types 0x1, 0x2, 0x3, 0x6, 0xa, 0xc, 0xe, 0x10. Forms are RCDATA (type 0xa) resources starting with `TPF0`; read them through pefile's resource directory, not a byte scan. Decode the binary TPF0 format (value types: 0 list end, 1 list, 2 int8, 3 int16, 4 int32, 5 extended, 6 string, 7 identifier, 8 false, 9 true, 10 binary, 11 set, 12 lstring, 13 nil, 14 collection, 15 single, 16 currency, 17 date, 18 wstring, 19 int64) and write text DFM to `OUT/forms/<FormName>.dfm`, with handlers shown as `OnClick = BuyBtnClick`.
6. TDD: write `test_extract_beermat.py` first and watch it fail before writing the extractor. Build a synthetic TPF0 blob in the test: `TPF0`, a class-name shortstring, an object-name shortstring, a property list, one child component and a list terminator. Cover an integer, a string, an identifier (an event handler) and a nested item collection. Also build a synthetic 128-byte fake VMT with a published method table.
7. Sound table: per event the strings read `<file>.wav`, `AppEvents\Schemes\Apps\DopeWars\<Event>\.current`, `<label>`, `AppEvents\EventLabels\<Event>`. Pair each wav with the Event in the entry that follows it. Write `OUT/sounds.tsv` (`event<TAB>wav<TAB>label`) and print it. Expected, exactly 10 rows: DWCopGunShot gun.wav; DWYourGunShot gun2.wav; DWYouHitByGun youhit.wav; DWCopHitByGun cophit.wav; DWCopChase siren.wav; DWPoliceDog bark.wav; DWCashReg cashreg.wav; DWMugged hrdpunch.wav; DWDead wasted.wav; DWLastDay uhoh.wav (the shipped file is `Siren.wav`; match case-insensitively). The test asserts all 10 rows and the extractor exits non-zero if any is missing. Also write every printable string of 4+ characters to `OUT/strings.txt` with its VA.
8. VMT parsing (Delphi 4 layout, offsets from the VMT address): selfPtr -76, intfTable -72, autoTable -68, initTable -64, typeInfo -60, fieldTable -56, methodTable -52, dynamicTable -48, className -44 (pointer to shortstring), instanceSize -40, parent -36, virtual methods from +0. Find VMTs by scanning CODE and DATA for a dword equal to its own address + 76. Published method table: word count, then per entry `word size; dword code VA; shortstring name`. Convert VA to file offset through the PE section table. Write `OUT/methods.tsv` (`class<TAB>method<TAB>VA hex`).
9. Ghidra labels: write `OUT/labels.csv` (`VA hex,label`), with `Class_Method` labels sanitized to `[A-Za-z0-9_]` plus one `Class_VMT` per VMT. `ApplyLabels.java` reads the CSV path from the script arguments; per row it calls `createLabel(addr, name, true)`, and for `Class_Method` rows also `disassemble(addr)` and `createFunction(addr, name)` when no function exists.
10. Ghidra check: `re:apply-labels-check` depends on `re:extract`, `re:_install-ghidra` and `re:_install-java`, and runs `{{.GHIDRA_RUN}} {{.GHIDRA_HEADLESS}} <tmpproj> dw -import vendor/dopewars-1999/DopeWars.exe -scriptPath tools/re/ghidra -postScript ApplyLabels.java OUT/labels.csv -deleteProject`. It must exit 0 with no `ERROR` script lines and log the applied label count.
11. Rules: commit nothing derived from the exe (only tools/re/**, taskfiles/re.yml and docs). One-line comments only, none saying "new" or "improved". Follow AGENTS.md. Run `ruff format tools/re` before committing. Conventional commits (`feat(re): ...`, `test(re): ...`), no Claude attribution anywhere. Do not touch CLAUDE.local.md or read any infra details.
12. Finish: check each acceptance criterion with `task_edit` (`acceptanceCriteriaCheck`), add implementationNotes with the exact commands run and a result summary (form count, method count, sound row count, labels applied), set status Done, and commit. Do not start TASK-010.02.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Split into subtasks TASK-010.01.01 to .04. .01 (extractor skeleton, TPF0 form decoder, re:test and re:extract) is Done: 8 forms decoded from the real exe. .02 (sound table and strings), .03 (VMT method map) and .04 (Ghidra labels and re:apply-labels-check, then close this task) remain To Do. Acceptance criteria #1, #4, #5, #7 and #8 are met so far; check them off when .04 closes this task.
<!-- SECTION:NOTES:END -->
