---
id: TASK-001.07
title: Parity signoff and migration documentation
status: To Do
assignee: []
created_date: '2026-09-26 04:34'
labels:
  - parity
  - migration
  - godot
  - mojo
milestone: m-3
dependencies:
  - TASK-001.06
references:
  - ~/git/jumpnbump/docs/porting-playbook.md
  - ~/git/jumpnbump/docs/build-layout.md
documentation:
  - docs/gameplay.md
  - AGENTS.md
parent_task_id: TASK-001
priority: high
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Run the full differential parity suite against the JS oracle corpus and formally sign off on the migration. This is the quality gate for TASK-001: it passes only when the Mojo implementation reproduces all oracle scenarios and the documentation is complete enough for a new contributor to build, run, and verify the game without prior knowledge of the project.

**Parity verification procedure:**
1. Run each oracle fixture from TASK-001.02 against the Mojo core via the ABI — compare outputs field-by-field
2. Run the full-game golden run fixture (seed-stable 31-day game) end-to-end through the Godot build
3. Document any intentional deviations (e.g. UI affordances that differ from the HTML prototype) with explicit approval
4. Measure Mojo LOC using `tokei` or `cloc` excluding `third_party/` and any generated files

**Documentation deliverables:**
- `docs/architecture.md` — architecture diagram and layer responsibilities
- `docs/build-and-test.md` — complete build and test runbook for every tier
- `docs/parity-deltas.md` — approved deviations from the JS prototype (empty file = perfect parity)
- Updated `AGENTS.md` — project structure, build entry points, test commands

**LOC target context:** at Jump'n'Bump parity, Zig is approximately 43% of the non-vendor codebase. This repo targets the same ratio for Mojo. Measurement: `tokei core/ --type Mojo` vs `tokei . --exclude third_party/ --exclude backlog/`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Parity suite passes for all oracle scenarios defined in TASK-001.02: identical seed produces identical outputs across every subsystem in Mojo vs the JS engine
- [ ] #2 Any behavioral delta from the JS prototype is documented in docs/parity-deltas.md with explicit rationale and approval
- [ ] #3 docs/architecture.md describes the four-layer architecture (Mojo core / C ABI / C++ GDExtension / GDScript) with a data-flow diagram showing the call path from GDScript to Mojo and back
- [ ] #4 docs/build-and-test.md documents every test tier: Mojo unit tests, ABI conformance, bridge integration, Godot regression, and parity/differential; includes exact commands to run each
- [ ] #5 Mojo LOC percentage is measured (non-vendor non-generated) and documented; result meets >=43% target
- [ ] #6 AGENTS.md is updated with the final project structure, build commands, and test entry points
<!-- AC:END -->
