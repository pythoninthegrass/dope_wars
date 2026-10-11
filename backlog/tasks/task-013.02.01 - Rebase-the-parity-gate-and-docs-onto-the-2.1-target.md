---
id: TASK-013.02.01
title: Rebase the parity gate and docs onto the 2.1 target
status: To Do
assignee: []
created_date: '2026-10-11 04:02'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.01.04
documentation:
  - docs/parity-deltas.md
  - docs/architecture.md
  - docs/build-and-test.md
parent_task_id: TASK-013.02
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`core:test` replays `tests/fixtures/*.jsonl`, recorded from the frozen JS engine in `index.html` (1.2 rules). With 2.1 as the target and Mojo-first development, rules that 2.1 keeps stay under JS-oracle fixtures, and rules that 2.1 replaces (see docs/beermat-2.1-re.md, from TASK-013.01.04) must stop being gated on the 1.2 behaviour. Decide per fixture which side it falls on, retire or re-home the replaced ones as Mojo-native tests, and record the new target in the docs: AGENTS.md ("What this repo is" and the prototype section), docs/architecture.md, docs/parity-deltas.md (2.1 is the target; airport flights are skipped and so is the rest of the out-of-scope list from TASK-013). This is the prerequisite for every rule-changing slice in TASK-013.02, so the gate does not fail for the right reasons.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every fixture in tests/fixtures is classified as kept (rule unchanged in 2.1) or retired (rule replaced), with the reason recorded
- [ ] #2 Retired fixtures are replaced by Mojo-native tests that pin the 2.1 rule, not simply deleted
- [ ] #3 task core:test and task check are green
- [ ] #4 AGENTS.md, docs/architecture.md and docs/parity-deltas.md state the 2.1 target, the Mojo-first rule, the frozen index.html and the airport and out-of-scope decisions
<!-- AC:END -->
