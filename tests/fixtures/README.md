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
- `call` — one of the engine exports (`newGame`, `generatePrices`, `buy`, `sell`, `travel`, `finances`, `rollArrivalEvent`, `rollCoatDealerOffer`, `acceptCoatOffer`, `rollGunDealerOffer`, `acceptGunOffer`, `shouldStartChase`, `startChase`, `runFromChase`, `fight`, `finish`) or a runner helper (`setPrices`, `setInventory`, `setField`, `buyCheapest`, `insertHighScores`, `serializeRoundTrip`).
- `args` — positional-arg bag; each dispatch case unpacks the fields it needs (see `run-step.mjs`).
- `rng` — optional array of `[0,1)` floats for a scripted RNG. Used by fixtures that force specific arrival-event / combat branches. Full-run fixtures omit `rng` and let the engine consume the seeded `state.rng` (mulberry32) it was born with.
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
