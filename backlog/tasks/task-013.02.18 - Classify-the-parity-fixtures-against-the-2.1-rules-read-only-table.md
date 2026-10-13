---
id: TASK-013.02.18
title: Classify the parity fixtures against the 2.1 rules (read-only table)
status: To Do
assignee: []
created_date: '2026-10-13 04:32'
labels:
  - beermat-2.1
  - gnhf-candidate
milestone: m-4
dependencies:
  - TASK-013.01.04
documentation:
  - docs/beermat-2.1-re.md
  - docs/beermat-re.md
  - docs/parity-deltas.md
  - tests/fixtures/README.md
parent_task_id: TASK-013.02
priority: high
type: docs
ordinal: 78000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
First half of the old TASK-013.02.01 scope. Produce docs/parity-fixture-classification.md: one row per fixture group in tests/fixtures (01-price-generation through 12-dealer-visits, each a .jsonl with a .meta.json), saying which 1.2 rules (M-01 to M-13) it exercises, what docs/beermat-2.1-re.md says about each rule in 2.1 (unchanged, changed or removed, with the N-xx ID where one exists), and a verdict of keep (every rule it pins is unchanged in 2.1), retire (every rule it pins is replaced) or split (it mixes both), with the reason and, for split, which steps or ops fall on which side. Read the .meta.json, tests/fixtures/README.md, generate.mjs and the .jsonl op names to learn what each group pins. This is read-only analysis: do not edit any fixture, generator, Taskfile, Mojo test, AGENTS.md or other doc, and do not run anything that regenerates fixtures. Where the 2.1 doc does not settle a rule (listed unresolved or not observed on a running game), mark the row "needs human decision" with the reason instead of guessing. Prior art for the style: the classification tables in docs/beermat-re.md and docs/parity-deltas.md. The supervised half is TASK-013.02.01, which consumes this table.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

Produced `docs/parity-fixture-classification.md`: one row per fixture group (01-12) naming the M-rule(s) it pins, the 2.1 verdict with N-xx where one exists, and a keep/retire/split/needs-human-decision outcome. 6 keep, 4 retire, 2 split, 2 needs-human-decision (08 serialize-roundtrip and 09 full-run are scope questions the 2.1 doc does not settle).

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 docs/parity-fixture-classification.md has one row for each of the 12 fixture groups, each naming the M-rules it pins
- [x] #2 Each row cites the matching 2.1 verdict from docs/beermat-2.1-re.md (with N-xx where one exists) and gives keep, retire, split or needs human decision with a reason
- [x] #3 Split rows list which steps or ops fall on the kept side and which on the retired side
- [x] #4 Rules the 2.1 doc leaves unresolved or unobserved are marked needs human decision, never guessed
- [x] #5 git diff shows only docs/parity-fixture-classification.md and this task's notes; no fixture, generator, Taskfile, test, AGENTS.md or other doc is touched
- [x] #6 markdownlint -c .markdownlint.jsonc passes on the new file and it contains no key or machine detail
<!-- AC:END -->
