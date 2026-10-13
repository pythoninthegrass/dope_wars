---
id: TASK-013.02.01
title: Rebase the parity gate and docs onto the 2.1 target
status: Done
assignee:
  - '@claude'
created_date: '2026-10-11 04:02'
updated_date: '2026-10-13 05:11'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.01.04
  - TASK-013.02.18
documentation:
  - docs/parity-deltas.md
  - docs/architecture.md
  - docs/build-and-test.md
parent_task_id: TASK-013.02
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Supervised half: act on the fixture classification table from TASK-013.02.18 (docs/parity-fixture-classification.md). `core:test` replays `tests/fixtures/*.jsonl`, recorded from the frozen JS engine in `index.html` (1.2 rules). With 2.1 as the target and Mojo-first development, rules that 2.1 keeps stay under JS-oracle fixtures, and rules that 2.1 replaces (see docs/beermat-2.1-re.md) must stop being gated on the 1.2 behaviour. Review the table with Lance, settle every "needs human decision" row, then retire or re-home the replaced fixtures as Mojo-native tests (splitting mixed fixtures as the table says), and record the new target in the docs: AGENTS.md ("What this repo is" and the prototype section), docs/architecture.md, docs/parity-deltas.md (2.1 is the target; airport flights are skipped and so is the rest of the out-of-scope list from TASK-013). This changes what the parity gate enforces, so it is not a gnhf candidate: it runs supervised. It is the prerequisite for every rule-changing slice in TASK-013.02, so the gate does not fail for the right reasons.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Every 'needs human decision' row in docs/parity-fixture-classification.md is resolved with Lance and the reason recorded
- [x] #2 Every fixture in tests/fixtures ends as kept (rule unchanged in 2.1) or retired (rule replaced), split fixtures divided as the table says
- [x] #3 Retired fixtures are replaced by Mojo-native tests that pin the 2.1 rule, not simply deleted
- [x] #4 task core:test and task check are green
- [x] #5 AGENTS.md, docs/architecture.md and docs/parity-deltas.md state the 2.1 target, the Mojo-first rule, the frozen index.html and the airport and out-of-scope decisions
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Decisions settled with Lance (2026-10-13):
- 02 buy/sell and 11 deposit/withdraw/unknown-action steps: keep under the JS oracle. No 2.1 observation contradicts them; TASK-013.01.05 retires a step if a playtest does.
- 08 serialize round-trip: retire the JS golden, re-home as a Mojo-native round-trip test that survives state-shape changes.
- 09 31-day full run: retire, replace with a Mojo-native end-to-end test (determinism per seed plus invariants, no exact goldens), because index.html is frozen at 1.2 and cannot regenerate it.
- Cross-cutting state shape: per-fixture projection. Each kept fixture's .meta.json lists the state fields it exercises (`stateFields`); gen-mojo.mjs emits only those state pairs and harness.assert_state_matches checks only the pairs present. The node replay (run.mjs, engine.test.mjs) stays full deep-equal because the JS engine is frozen.
- Pending 2.1 tests: rules the core already implements identically become live Mojo tests; 2.1-only rules are written with the 2.1 values from docs/beermat-2.1-re.md as skipped tests named test_pending_<task>_..., and the owning slice un-skips them.
- Retired groups and steps are deleted from tests/fixtures (via generate.mjs); git history is the record.

Steps:
1. Fixtures (generate.mjs): delete 01, 04, 06, 08, 09, 12. Trim 03 to steps 0-2 and 11-16 (bank 70 tie and the bank-only zero/negative cases), 05 to steps 0-6, 07 to steps 0-4, 10 to steps 0, 8-14 and 22-24, 11 to steps 0-5 and 8-12. Drop the shape-bound args (debt, guns) from kept setField steps. Add stateFields to each kept .meta.json. Regenerate and confirm kept steps' returns are unchanged against the old goldens (diff).
2. Projection plumbing: gen-mojo.mjs filters state pairs by stateFields; harness.assert_state_matches checks only present fields; regenerate tests/mojo/fixtures.mojo.
3. Mojo tests: parity_test.mojo drops retired groups. prices_test drops the fixture-01 replay (existing scripted range, x5 and /10 tests stay live). world_test newGame test asserts the 2.1-stable start state as literals. New serialize round-trip test and end-to-end run test (live). Skipped pending tests with 2.1 values for: price roll (13 drugs, 1 in 5 keep, 1 in 40), bank interest ties (1050->1103, 30->32, 50->53), loan compounding (5500->6325), arrival event gate and table, mugging health loss, no wealth cap, chase start 1 in 8, run 20%, stay arrest, fight accuracy, win reward formula, deputy count 2-8, coat dealer 1 in 15 gate, 30-entry high score list, per-loan repayment and early payoff.
4. Docs: tests/fixtures/README.md (coverage table, stateFields, retired groups), docs/parity-fixture-classification.md (record the resolved verdicts and reasons), AGENTS.md, docs/architecture.md, docs/parity-deltas.md (2.1 is the target, Mojo-first, index.html frozen at 1.2, airport flights skipped, out-of-scope list from TASK-013), docs/build-and-test.md if it names the fixture count.
5. Verify: task core:test, task core:test:check-generated, node tests/fixtures/run.mjs, node --test tests/engine.test.mjs, task check.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Rebased the parity gate onto the 2.1 target.

Fixtures: retired 01, 04, 06, 08, 09, 12 and trimmed 03, 05, 07, 10, 11 through generate.mjs; 02 is unchanged. Kept steps' returns are identical to the old goldens (03's bank 70 case is a rebuilt step, 70 to 74 as classified). Each kept fixture's .meta.json has stateFields; gen-mojo.mjs emits only those state pairs and harness.assert_state_matches compares only the pairs present. A mutation of a kept expectation (bank 74 to 75) fails the gate as expected.

Mojo-native tests: new serialize_test.mojo and run_test.mojo (live) replace 08 and 09; prices_test and world_test no longer read fixture 01 (existing scripted range, x5 and /10 tests stay live). New pending_2_1_test.mojo holds 9 skipped tests with 2.1 values (N-19, N-21, N-22, N-23, N-24, N-28, N-33, N-34, wealth cap removal); each was confirmed to fail on the 1.2 code before being skipped.

Docs: AGENTS.md, docs/architecture.md, docs/parity-deltas.md (new section 8), docs/build-and-test.md, tests/fixtures/README.md and docs/parity-fixture-classification.md (resolution section) state the 2.1 target, Mojo-first, the frozen index.html, airport and the out-of-scope list.

Verification: task core:test (all files green, 9 skipped), task core:test:check-generated, node tests/fixtures/run.mjs, node --test tests/engine.test.mjs (103 pass), task check exit 0, markdownlint clean.

Follow-ups for Lance: (1) several 2.1 mismatches (N-22 chase start, N-23 deputies, N-24 run, N-28 coat dealer trigger, N-29 arrival table, N-33 bank interest) have no owning TASK-013.02 slice in the backlog; their pending tests are the only record. (2) Rules with no entry point yet (loans, weapons, game length, 13-drug price roll, fight/stay/reward) get tests with their slice's API. (3) replay.mojo still has dispatch cases for calls no fixture uses any more (gun dealer, arrival event, chase, serialize round-trip); the slices that remove those APIs should delete the cases. (4) Changes are staged, not committed.
<!-- SECTION:FINAL_SUMMARY:END -->
