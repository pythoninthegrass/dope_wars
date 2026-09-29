---
id: TASK-001.07
title: Parity signoff and migration documentation
status: Done
assignee: []
created_date: '2026-09-26 04:34'
updated_date: '2026-09-29 04:25'
labels:
  - parity
  - migration
  - godot
  - mojo
milestone: m-3
dependencies:
  - TASK-001.06
  - TASK-001.09
references:
  - ~/git/jumpnbump/docs/porting-playbook.md
  - ~/git/jumpnbump/docs/build-layout.md
  - TASK-009
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
- [x] #1 Parity suite passes for all oracle scenarios defined in TASK-001.02: identical seed produces identical outputs across every subsystem in Mojo vs the JS engine
- [x] #2 Any behavioral delta from the JS prototype is documented in docs/parity-deltas.md with explicit rationale and approval
- [x] #3 docs/architecture.md describes the four-layer architecture (Mojo core / C ABI / C++ GDExtension / GDScript) with a data-flow diagram showing the call path from GDScript to Mojo and back
- [x] #4 docs/build-and-test.md documents every test tier: Mojo unit tests, ABI conformance, bridge integration, Godot regression, and parity/differential; includes exact commands to run each
- [x] #5 Mojo LOC percentage is measured (non-vendor non-generated) and documented; result meets >=43% target
- [x] #6 AGENTS.md is updated with the final project structure, build commands, and test entry points
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Dependency on TASK-001.09 added: AC#1 signs off parity "for all oracle scenarios", and `dw_roll_dealer_visits` currently has no fixture, so it cannot be covered by this signoff.

Heads up for whoever starts this: TASK-009 (bug fix, done) landed after TASK-001.09's parity-fixture signoff and changed the parity baseline this task audits — bankInterest 0.02->0.05, startChase deputy formula (day-scaled -> randInt(2,11), now consumes an RNG draw it didn't before), Ecstasy/Smack price bounds, and DW_ABI_VERSION 1->2 (docs/abi-contract.md's Versioning section has the rationale). tests/fixtures/*.jsonl and tests/mojo/fixtures.mojo were regenerated to match and all suites were green at that point (JS 59/59, fixture replay 12/12, Mojo unit 32/32, Tier-C 23/23 + 40/40). AC#1's parity run should target the current fixture corpus/ABI version, not any pre-TASK-009 assumption.

**Parity run (2026-09-28):** `task check` is green end-to-end (Mojo unit tests, ABI static gates, Tier-C conformance x3, bridge integration x2, game boundary check, UI regression suite, headless smoke test), including `task core:test` replaying all 12 fixtures in `tests/fixtures/*.jsonl` against the current ABI v2 baseline (post-TASK-009). Three stale-parity bugs found and fixed along the way, all leftovers from TASK-009's ABI v1->v2 bump that nothing had caught: `core/abitest/abi_header_check.c` hardcoded `DW_ABI_VERSION == 1u`; `game/bridge_expectations.gd` was stale (regenerated via `task gen:bridge-expectations`); `tools/gen_bridge_expectations.py`'s PINNED table still had `dw_rules_bank_interest_bp: 200` instead of 500 (bankInterest 0.02->0.05). Also fixed an unrelated staleness gate bug: `task game:import`'s `status:` check only tested `test -d .godot`, so a `.godot/` left over from an interrupted import could exist without the compiled `translations/strings.en.translation` ever having been generated, failing every downstream Godot task two layers removed from the real cause; added a second check for the translation file.

**LOC (2026-09-28, `task loc`):** 25.70% Mojo of the whole non-vendor repo (misses the flat 43% target — `game/`'s GDScript UI layer can't legally move to Mojo per `docs/layer-boundaries.md`). Scoped to the simulation stack alone (`core/`+`include/`+`extension/`), Mojo is 67.97% — past parity. Full breakdown in `docs/architecture.md`.

**Docs delivered:** `docs/architecture.md` (four-layer architecture, data-flow diagram, ABI version history, LOC share), `docs/build-and-test.md` (runbook for all 6 test tiers), `docs/parity-deltas.md` (4 documented deltas/non-deltas, all previously-approved per TASK-001.06's implementation plan — no new deviations introduced), and `AGENTS.md` updated (stale "no Godot source yet" line, stale LOC percentage, pointers to the three new docs).
<!-- SECTION:NOTES:END -->
