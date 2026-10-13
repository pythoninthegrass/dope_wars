---
id: TASK-013.02.18
title: Classify the parity fixtures against the 2.1 rules (read-only table)
status: Done
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

The gnhf run produced a first table that failed review: 02 and 11 were marked keep although the 2.1 doc does not settle them (11's payLoan is replaced by per-loan repayment), row 05's split reason was wrong, the split rows had no step numbers, and the notes tally did not match the table. The table was corrected by hand against each fixture's .jsonl. Final verdicts: retire 04, 06, 12; split 01, 03, 05, 07, 10, 11 with step numbers; needs human decision 02, 08, 09, plus a cross-cutting decision on full-state deep equality, which makes every group's state snapshot change shape under 2.1 (guns, single debt). No group is plain keep. TASK-013.02.01 consumes this table.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 docs/parity-fixture-classification.md has one row for each of the 12 fixture groups, each naming the M-rules it pins
- [x] #2 Each row cites the matching 2.1 verdict from docs/beermat-2.1-re.md (with N-xx where one exists) and gives keep, retire, split or needs human decision with a reason
- [x] #3 Split rows list which steps or ops fall on the kept side and which on the retired side
- [x] #4 Rules the 2.1 doc leaves unresolved or unobserved are marked needs human decision, never guessed
- [x] #5 git diff shows only docs/parity-fixture-classification.md and this task's notes; no fixture, generator, Taskfile, test, AGENTS.md or other doc is touched
- [x] #6 markdownlint -c .markdownlint.jsonc passes on the new file and it contains no key or machine detail
<!-- AC:END -->
