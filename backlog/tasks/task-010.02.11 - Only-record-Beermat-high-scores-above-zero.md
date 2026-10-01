---
id: TASK-010.02.11
title: Only record Beermat high scores above zero
status: Done
assignee:
  - pythoninthegrass
created_date: '2026-10-01 06:17'
updated_date: '2026-10-01 19:20'
labels:
  - reverse-engineering
  - parity
dependencies: []
documentation:
  - docs/beermat-re.md
parent_task_id: TASK-010.02
priority: low
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Mismatch M-13 in docs/beermat-re.md (decompile at 0x004609fc). The real game only enters a final score (cash + bank - debt, also computed on death) in the top-10 list when it is above 0; otherwise it shows "<name> was not good enough to get on your highest score list." and records nothing. The engine offers every score for the list. The list size (10) and the score formula already match.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Scores of 0 or less are not inserted into the high-score list and the player sees the 'not good enough' message, with failing tests first
- [x] #2 Behaviour is the same in the prototype and the Godot build
- [x] #3 Fixtures regenerated and task check passes
- [x] #4 docs/beermat-re.md marks M-13 as match
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Fix M-13: `dw_insert_highscore` (and its JS/Mojo equivalents) must refuse to insert a score <= 0 instead of always inserting.

Research findings (see Implementation Notes for the Explore agent's full file:line map):
- JS: `insertHighScore` (index.html:1051) always appends; `offerHighScore` (index.html:1613) always shows the Save/Skip name dialog.
- Mojo core: `score.insert_high_score` (core/src/score.mojo:48) always appends/truncates, returns None. `dw_insert_highscore` (core/src/abi.mojo:1123) always returns DW_OK on success.
- No "rejected" notion exists anywhere in the stack today (no dw_result code, no bool return).
- GDScript: `HighscoreStore.insert` (game/platform/highscore_store.gd:58) already no-ops when the ABI returns non-OK, but its only caller (`main.gd:_show_score`) ignores the return value and always proceeds as if saved.

Chosen approach (keeps `dw_finish`/`dw_finish_result` untouched — no struct layout change needed):
1. JS engine: `insertHighScore(scores, entry)` returns a Bool; rejects `entry.score <= 0` without mutating the array. `finish()` is unchanged.
2. JS UI: `offerHighScore`'s Save handler branches on that Bool; on reject, shows a "not good enough" alert (no name in the message, since our ports capture the name at save time, not at new-game like Beermat) instead of persisting, then still calls `after()`.
3. Mojo: `score.insert_high_score` returns Bool with the same `<= 0` guard.
4. ABI: new anonymous-enum constant `DW_ERR_SCORE_TOO_LOW` (appended, value 14 — additive per docs/abi-contract.md). `dw_insert_highscore` returns it (array/out_count unchanged) instead of DW_OK when the entry is rejected. Per this repo's own versioning policy ("change to the observable semantics of an existing function" bumps the version) and the precedent of every prior M-xx fix (v2-v9), this bumps `DW_ABI_VERSION` 9 -> 10, with a changelog entry in docs/abi-contract.md. Touches: include/dopewars.h, core/src/abi.mojo, core/abitest/abitest.mojo, core/abitest/abi_conformance_test.py, extension/src/dopewars_world.cpp (BIND_CONSTANT), game/simulation/world.gd (re-export), game/bridge_expectations.gd (regenerate via `task gen:bridge-expectations`).
5. GDScript: `HighscoreStore.insert` return type changes from `Array[Dictionary]` to `{"table": Array[Dictionary], "inserted": bool}` (only caller, main.gd, currently discards the return, so this is safe). `main.gd:_show_score` shows a new `Copy.MSG_SCORE_NOT_HIGH_ENOUGH` alert (new tr() key in strings.csv) when `inserted` is false, before continuing to `_after_score`.
6. Tests first (TDD): tests/engine.test.mjs (insertHighScore rejection), core/abitest/abitest.mojo + abi_conformance_test.py (dw_insert_highscore rejection case), game/godot_tests/ui_flow_test.gd (score <= 0 shows the new alert and does not persist a row). Then implement until green.
7. Fixtures: tests/fixtures/run-step.mjs's `insertHighScores` helper gets an optional `offset` arg so a new step in generate.mjs/07-finish-scoring.jsonl can exercise a sub-threshold score without truncation ambiguity (count=3, offset=-100 -> scores -100/0/100, only the 100 entry survives). Regenerate the .jsonl via `node tests/fixtures/generate.mjs` and tests/mojo/fixtures.mojo via `node tests/fixtures/gen-mojo.mjs`.
8. docs/beermat-re.md: mark M-13 row and summary-table row as "match".
9. Run `task check` (or at least core:test, abi:check, abi:conformance, bridge:test, game:ui-test, lint) before closing.

This plan was presented to Lance for approval before implementation given the ABI version bump (asked via AskUserQuestion).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Starting research: index.html engine's insertHighScore (index.html:1051) always inserts; offerHighScore UI (index.html:1613) always shows name-entry dialog on Save. Decompile M-13 wants scores <=0 rejected with a 'not good enough' message instead. Dispatched Explore agent to map the equivalent logic across core/ (Mojo), include/dopewars.h, extension/, game/ (GDScript), and tests/fixtures before drafting the plan.

Verification: `node --test tests/engine.test.mjs` (109/109, new insertHighScore rejection test added first and confirmed failing before the fix); `task core:test` (all Mojo suites green, including 07-finish-scoring replay with the new offset-based reject fixture step); `task abi:check` and `task abi:conformance` (36 ctypes + 24 Mojo abitest assertions, including a new test_every_result_code_is_reachable case and test_finish_and_highscore extension for DW_ERR_SCORE_TOO_LOW); `task gen:bridge-expectations` regenerated (DW_ABI_VERSION 9->10) and `:check` passes; `task bridge:test` and `task bridge:test:script` green; `task game:ui-test` green (539 assertions; _test_endgame_and_highscores rewritten to cover both the M-13 rejection path -- default fresh game finishes at -3500, Save shows the 'not good enough' alert, no row persisted -- and the normal positive-score save path via a new _fresh(seed, start_cash) override); `task lint` and full `task check` both exit 0.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed M-13 (docs/beermat-re.md): Beermat never records a final score of 0 or below, showing \"<name> was not good enough to get on your highest score list.\" instead. The engine previously inserted every score unconditionally.

**JS prototype (index.html):** `insertHighScore` now returns a Bool and refuses `entry.score <= 0` without mutating the table. `offerHighScore`'s Save handler shows the exact Beermat message via `showAlert` when rejected, instead of persisting.

**Mojo core:** `score.insert_high_score` gained the same `<= 0` guard and returns Bool. `dw_insert_highscore` returns a new `DW_ERR_SCORE_TOO_LOW` (14, appended) instead of `DW_OK` when rejected, leaving `scores`/`*out_count` untouched. Per this repo's versioning policy and the precedent of every prior Beermat-parity fix (v2-v9), this is an observable-semantics change to an existing function, so `DW_ABI_VERSION` bumps 9 -> 10 (include/dopewars.h, core/src/abi.mojo, core/abitest/*, game/bridge_expectations.gd regenerated, extension BIND_CONSTANT, world.gd re-export). Approved with the user via AskUserQuestion before implementing.

**Godot:** `HighscoreStore.insert` now returns `{\"table\": ..., \"inserted\": bool}` instead of a bare array (its only caller discarded the return previously, so this was a safe signature change). `main.gd:_show_score` shows a new `Copy.MSG_SCORE_NOT_HIGH_ENOUGH` alert (new strings.csv tr() key) when `inserted` is false, otherwise proceeds as before.

**Fixtures:** `tests/fixtures/run-step.mjs`'s `insertHighScores` helper gained an `offset` arg so a new 07-finish-scoring.jsonl step (count=3, offset=-100) unambiguously proves the <=0 rejection independent of top-10 truncation. Regenerated via `node tests/fixtures/generate.mjs` and mirrored into `tests/mojo/fixtures.mojo` via `node tests/fixtures/gen-mojo.mjs` (needed an `offset` entry in gen-mojo.mjs's closed ALLOWED list, plus matching support in `tests/mojo/replay.mojo`).

**Tests added/updated (TDD, written first and confirmed failing):** `tests/engine.test.mjs` (insertHighScore rejection), `core/abitest/abitest.mojo` (test_finish_and_highscore extended + a new DW_ERR_SCORE_TOO_LOW case in test_every_result_code_is_reachable, plus two now-stale hardcoded `DW_ABI_VERSION`/enum constants in abitest.mojo and abi_header_check.c fixed), `core/abitest/abi_conformance_test.py` (version + enum constant), `game/godot_tests/ui_flow_test.gd` (`_test_endgame_and_highscores` rewritten: a new `_fresh(seed, start_cash)` override lets one sub-scenario force a positive score for the normal save path while the rules-default fresh game -- already negative at -3500 -- exercises the rejection path; CASE_FLOORS bumped 16 -> 22).

**Docs:** docs/abi-contract.md gained a v10 changelog entry; docs/beermat-re.md marks M-13 as match in both the detail table and the summary table.

**Verification:** `task check` passes end to end (core tests, ABI static + conformance gates, both bridge tests, the game boundary check, the UI regression suite, lint, headless smoke test), alongside `node --test tests/engine.test.mjs`. No regressions observed.

**Risk/follow-up:** None identified. The name-entry-at-save-time vs. Beermat's name-entry-at-new-game timing difference already existed before this task and is out of scope here.
<!-- SECTION:FINAL_SUMMARY:END -->
