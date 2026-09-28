# Fixture corpus — JS engine golden oracle

Seed-stable JSONL traces recorded from the `<script id="engine">` block in `index.html` (lines 609-1079). These files are the authoritative parity oracle for TASK-001: any future implementation (Mojo, GDScript, …) that reproduces every fixture line-for-line is considered at parity with the JS prototype.

Pattern reference: `~/git/jumpnbump/tests/corpus/` (headless input-trace + per-tick checksum corpus for the C↔Zig differential test).

## Layout

```text
tests/fixtures/
  engine-loader.mjs        # extracts <script id="engine"> from index.html, loads it in node:vm
  run-step.mjs             # shared step-dispatch table (used by generator, runner, node:test)
  generate.mjs             # scripts each fixture, records return + state snapshot per step
  run.mjs                  # replays fixtures against the current engine, exits non-zero on any mismatch
  NN-<name>.jsonl          # one step per line: { step, call, args, rng?, expect: { return, state } }
  NN-<name>.meta.json      # { seed, description, mechanic }
```

## File format

Each `.jsonl` line is one engine call plus the expected result:

```json
{"step": 0, "call": "newGame", "args": {"seed": 7}, "expect": {"return": {...}, "state": {...}}}
```

Fields:

- `step` — zero-based index; must match the line's position in the file.
- `call` — one of the engine exports (`newGame`, `generatePrices`, `buy`, `sell`, `travel`, `finances`, `rollArrivalEvent`, `rollCoatDealerOffer`, `acceptCoatOffer`, `rollGunDealerOffer`, `acceptGunOffer`, `shouldStartChase`, `startChase`, `getFightRatings`, `applyDamage`, `runFromChase`, `fight`, `finish`) or a runner helper (`setPrices`, `setInventory`, `setField`, `buyCheapest`, `insertHighScores`, `serializeRoundTrip`, `rollDealerVisits`).
- `args` — positional-arg bag; each dispatch case unpacks the fields it needs (see `run-step.mjs`).
- `rng` — optional array of `[0,1)` floats for a scripted RNG. Used by fixtures that force specific arrival-event / combat branches. Full-run fixtures omit `rng` and let the engine consume the seeded `state.rng` (mulberry32) it was born with. A scripted call draws from the array only, so it never advances `state.rng` and its snapshot records `rngState` unchanged; the scaling a call applies is part of the contract (`shouldStartChase` scales by `randInt`'s span, the dealer draws compare the raw float against `0.15`).
- `expect.return` — deep-equal target for the call's return value.
- `expect.state` — deep-equal target for the full state snapshot after the call. `state.rng` (a closure) is stripped and replaced with `rngState` (the mulberry32 integer), matching what `serializeState()` does.

The runner helpers exist so a fixture can drive the engine into a specific state without depending on prior RNG history (e.g. force a `speed`-only price roster before testing `buy` overflow). Any Mojo/GDScript replay harness must implement the same helpers.

Each `.meta.json` sidecar records:

```json
{
  "seed": 12345,
  "description": "31-day playthrough with deterministic policy",
  "mechanic": "end-to-end golden run"
}
```

## Coverage

| File | Exercises |
| --- | --- |
| `01-price-generation` | `generatePrices` roster + event scaling |
| `02-buy-sell-edges` | coat overflow, unaffordable, non-tradeable, partial sell |
| `03-travel-interest` | day advancement, 10% debt compounding, 2% bank interest |
| `04-arrival-events` | every `rollArrivalEvent` branch (mugged/freeDrugs/dogChase/foundDrugs/mamasBrownies/freeWeedDeath/flavor/none) |
| `05-dealers` | coat + gun dealers: cash path, bank+25% fee path, insufficient |
| `06-chase-combat` | `startChase` w/ + w/o guns; `runFromChase` escape/fail/aggressor; `fight` hit/miss/won |
| `07-finish-scoring` | `finish` score = cash + bank − debt; `insertHighScore` top-10 truncation |
| `08-serialize-roundtrip` | `serializeState` → `deserializeState` preserves full state |
| `09-full-run-31day` | 31-day playthrough with deterministic policy (travel to `locations[day % 6]`, buy cheapest per stop) |
| `10-rolls-and-helpers` | `shouldStartChase` police weighting (incl. the 49/50 threshold), `rollCoatDealerOffer` and `rollGunDealerOffer` range ends, `getFightRatings`, `applyDamage` |
| `11-finances` | `finances` deposit/withdraw/payLoan, clamping to available cash/bank/debt, amount floor, unknown action |
| `12-dealer-visits` | the `rollDealerVisits` helper: seeded stream over eight calls, all four scripted combinations + the 0.15 boundary, dead-player draw consumption, chase skip (`index.html:1382-1388`) |

## Runner helpers

`rollDealerVisits` is unlike the state-shaping helpers: it *consumes the RNG*.
The coat/gun dealer visits have no engine export — the two `state.rng() < 0.15`
draws live in the UI layer at `index.html:1387-1388`, inside `runArrivalSequence`,
and only when `shouldStartChase` came back false (`index.html:1382-1383`).
`index.html` is deleted at the end of TASK-001, so the `rollDealerVisits` case in
`run-step.mjs` (which cites those lines) is the surviving statement of the
prototype's semantics.

The load-bearing detail is that **both draws are consumed before `dead` is
consulted**. The prototype spells the guard `state.rng() < 0.15 && !state.dead`,
so short-circuit evaluation has already advanced `state.rng` by the time the
guard is tested: a dead player spends two draws and reports neither dealer. A
helper (or port) that tested `dead` first would desync the stream for the rest of
the run. `core/src/dealers.mojo::roll_dealer_visits` draws unconditionally for
exactly this reason. The `12-dealer-visits` fixture proves it two ways: the
dead-player step reports `false, false` yet its post-call `rngState` equals the
live twin's for the same script, and the chase steps leave `rngState` unchanged
across a repeated one-draw `shouldStartChase`, which is only consistent with the
dealer draws never having been reached. A harness replaying these fixtures must
implement the same helper — both draws, coat first, then the `dead` suppression
applied to the reported pair only.

## Failure reasons and `dw_result`

`buy`, `sell`, `travel`, `finances` and the dealer `accept*` calls return
`{ ok: false, reason: "<English sentence>" }` in JS. The Mojo core does not
carry presentation strings (`docs/layer-boundaries.md`), so it returns a
`dw_result` code instead. A replay harness maps the oracle's `reason` to the
code and compares that, rather than comparing the sentence.

| Oracle `reason` | `dw_result` |
| --- | --- |
| `<Drug> isn't traded here.` | `DW_ERR_NOT_TRADED_HERE` |
| `Duh! Check the price of <Drug>, dude!` | `DW_ERR_INSUFFICIENT_CASH` |
| `Not enough cash or coat space.` | `DW_ERR_INSUFFICIENT_CASH` or `DW_ERR_INSUFFICIENT_SPACE` |
| `You don't have that many to sell.` | `DW_ERR_INSUFFICIENT_INVENTORY` |
| `Unknown finances action.` | `DW_ERR_INVALID_ARGUMENT` |
| `nothing affordable` | runner-helper result, not an engine code |

`Not enough cash or coat space.` is one sentence covering two conditions, and a
bare `{ ok: false }` from a dealer covers two more. The harness accepts either
code for those, because the oracle genuinely does not distinguish them. The
state snapshot still pins the outcome, so this only tolerates a different
*label* on the same branch, never a different branch.

## Running

Replay every fixture against the current engine (exits non-zero on any mismatch):

```sh
node tests/fixtures/run.mjs
```

Filter by basename substring:

```sh
node tests/fixtures/run.mjs 04 05
```

The same replay logic is wired into the standard test suite as a `describe('fixture corpus', …)` block, so it runs automatically under:

```sh
node --test tests/engine.test.mjs
```

## Regenerating after intentional engine changes

If the engine behavior changes on purpose, regenerate the goldens:

```sh
node tests/fixtures/generate.mjs
```

This overwrites every `.jsonl` and `.meta.json` under `tests/fixtures/`. Review the diff carefully — any change means the parity contract with future ports has shifted. Regeneration must be a deliberate, reviewed step, not a reflex to a red test.

Verify determinism (identical bytes across regenerations):

```sh
shasum tests/fixtures/*.jsonl
node tests/fixtures/generate.mjs
shasum tests/fixtures/*.jsonl   # must match
```

## Adding a fixture

1. Append a new entry to `FIXTURES` in `generate.mjs`:

    ```js
    {
      name: '10-my-scenario',
      meta: { seed: 999, description: '...', mechanic: '...' },
      steps: [
        { call: 'newGame', args: { seed: 999 } },
        { call: 'setField', args: { cash: 5000 } },
        // … more steps
      ],
    }
    ```

2. Run `node tests/fixtures/generate.mjs` to produce the `.jsonl` + `.meta.json`.
3. Run `node tests/fixtures/run.mjs 10-my-scenario` to confirm replay is stable.
4. Commit both files together with the generator change.

If your scenario needs a new kind of state manipulation, add a case to the `runStep` dispatch in `run-step.mjs` and document it under "runner helpers" above so a Mojo harness knows to implement it too.

## Why this exists

The Mojo port (TASK-001) will land layer by layer. Each layer is validated by replaying these fixtures against the Mojo `dw_world` handle via the frozen C ABI — same input sequence, same expected return, same expected snapshot. Any divergence is a bug in the port, full stop.
