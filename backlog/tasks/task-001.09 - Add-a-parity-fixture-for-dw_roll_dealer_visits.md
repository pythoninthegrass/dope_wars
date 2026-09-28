---
id: TASK-001.09
title: Add a parity fixture for dw_roll_dealer_visits
status: To Do
assignee:
  - lance
created_date: '2026-09-28 01:28'
labels:
  - parity
  - fixtures
  - mojo
milestone: m-3
dependencies:
  - TASK-001.06
references:
  - 'index.html:1387-1388'
  - core/src/dealers.mojo
  - tests/fixtures/README.md
documentation:
  - tests/fixtures/README.md
  - docs/abi-contract.md
parent_task_id: TASK-001
priority: high
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Close the one parity gap TASK-001.06 left open: `dw_roll_dealer_visits` is new RNG consumption in the Mojo core, and no entry in `tests/fixtures/*.jsonl` pins it. `task core:test` therefore proves nothing about it, and its parity rests entirely on `game/tests/test_bridge.gd`'s self-consistency checks (same seed agrees with itself, the stream advances, a dead player is suppressed). Those are not oracle comparisons.

This blocks TASK-001.07 AC#1, which signs off parity "for all oracle scenarios defined in TASK-001.02" — a scenario that has no oracle cannot be part of that signoff.

**Why it needs a runner helper rather than a plain engine call:** the two 15% draws live in the JS *UI* layer, not the engine (`index.html:1387-1388`, inside `runArrivalSequence`). `window.DopeWarsEngine` exports no function that performs them, so there is no engine export to record. The fixture needs a new runner helper alongside `setPrices` / `setField` / `buyCheapest`, implemented against the JS engine's own `state.rng` with the exact prototype semantics:

```js
const coat = state.rng() < 0.15
const gun  = state.rng() < 0.15
return { coat: state.dead ? false : coat, gun: state.dead ? false : gun }
```

Both draws are consumed unconditionally. That is the load-bearing detail: in JS `state.rng() < 0.15 && !state.dead` evaluates the draw *first*, so short-circuiting happens after the RNG has already advanced. A helper that short-circuits before drawing would desync the stream for the rest of the run, and `core/src/dealers.mojo:roll_dealer_visits` deliberately does not.

**Risk worth recording:** `index.html` is deleted at the end of TASK-001. Once it is gone, this helper's JS implementation is the only surviving statement of the prototype's semantics. `tests/fixtures/run-step.mjs` must cite `index.html:1387-1388` in a comment on the case, the same way `run-step.mjs` and `core/src/*.mojo` already cite line numbers back to the prototype.

## Files

- `tests/fixtures/run-step.mjs` — new `rollDealerVisits` case, citing `index.html:1387-1388`.
- `tests/fixtures/generate.mjs` — new `12-dealer-visits` entry in `FIXTURES`.
- `tests/fixtures/12-dealer-visits.jsonl` + `.meta.json` — generated, committed together with the generator change.
- `tests/mojo/replay.mojo` — matching dispatch arm calling `dealers.roll_dealer_visits(game)`, alongside the existing helper arms at :236-247.
- `tests/fixtures/README.md` — coverage table row and a "runner helpers" paragraph, so a future harness knows to implement the same helper.

## Cases the fixture must cover

1. **Seeded stream.** A fresh game, then N back-to-back `rollDealerVisits` calls, pinning both the reported pair and the resulting `rngState` after each. This is what makes the core's draw *count* and *order* a parity fact rather than an assumption.
2. **Scripted-RNG forcing.** Scripted `rng` arrays that hit coat-only, gun-only, both, and neither, so all four reported combinations are covered without depending on which way the seed falls.
3. **Dead player.** `setField: { health: 0 }` (or `applyDamage` to zero) then a call: both reported false, **and** the post-call `rngState` must equal the live run's for the same script. That equality is the proof the draws happened anyway; asserting only the false/false output would pass against an implementation that never drew.
4. **Chase interaction.** `shouldStartChase` returning true, showing the presentation layer skips the dealer rolls entirely on a chase (`index.html:1382-1383`). The fixture should make the skip explicit rather than leaving it to be inferred from an absent step.

## Verifying

- `node tests/fixtures/generate.mjs` then `shasum` twice to confirm byte-identical regeneration (`tests/fixtures/README.md` "Regenerating after intentional engine changes").
- `node tests/fixtures/run.mjs 12`
- `task core:test -- 12`
- `task check` in full, since adding a fixture touches the shared replay dispatch in `tests/mojo/replay.mojo`.

**Do not** delete or renumber the existing fixtures. This is a new `12-`; `09-full-run-31day` is a different scenario and is unaffected.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A rollDealerVisits runner helper exists in tests/fixtures/run-step.mjs, implementing index.html:1387-1388 with both draws consumed unconditionally, plus a matching dispatch arm in tests/mojo/replay.mojo calling dealers.roll_dealer_visits
- [ ] #2 A 12-dealer-visits fixture pins the seeded stream across repeated calls, so both the reported pair and the post-call rngState are compared against the oracle
- [ ] #3 Scripted-rng cases cover all four reported combinations (coat only, gun only, both, neither)
- [ ] #4 The dead-player case asserts the post-call rngState equals the equivalent live run's, proving the draws are consumed even when both are suppressed
- [ ] #5 A chase case makes explicit that the dealer rolls are skipped entirely when shouldStartChase fires (index.html:1382-1383)
- [ ] #6 node tests/fixtures/run.mjs 12 and task core:test -- 12 pass, regeneration is byte-identical across two runs, and task check passes in full
- [ ] #7 tests/fixtures/README.md coverage table and runner-helpers prose document the new helper and cite index.html:1387-1388, since index.html is deleted at the end of TASK-001
<!-- AC:END -->
