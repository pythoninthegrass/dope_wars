# Fixture corpus — JS engine golden oracle

Seed-stable JSONL traces recorded from the `<script id="engine">` block in `index.html` (lines 609-1079). These files are the authoritative parity oracle for TASK-001: any future implementation (Mojo, GDScript, …) that reproduces every fixture line-for-line is considered at parity with the JS prototype.

The target is Beermat 2.1 and the engine is frozen at 1.2, so a fixture stays only while every rule it pins is unchanged in 2.1 (see "Coverage").

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
- `call` — one of the engine exports (`newGame`, `generatePrices`, `buy`, `sell`, `travel`, `finances`, `rollArrivalEvent`, `rollDealerVisit`, `rollCoatDealerOffer`, `acceptCoatOffer`, `rollGunDealerOffer`, `acceptGunOffer`, `shouldStartChase`, `startChase`, `applyDamage`, `runFromChase`, `stayInChase`, `fight`, `acceptDoctorOffer`, `finish`) or a runner helper (`setPrices`, `setPrevPrices`, `setInventory`, `setField`, `buyCheapest`, `insertHighScores`, `serializeRoundTrip`).
- `args` — positional-arg bag; each dispatch case unpacks the fields it needs (see `run-step.mjs`).
- `rng` — optional array of `[0,1)` floats for a scripted RNG. Used by fixtures that force specific arrival-event / combat branches. Full-run fixtures omit `rng` and let the engine consume the seeded `state.rng` (mulberry32) it was born with. A scripted call draws from the array only, so it never advances `state.rng` and its snapshot records `rngState` unchanged; the scaling a call applies is part of the contract (`shouldStartChase` scales by `randInt`'s span, `rollDealerVisit` scales by `randInt` the same way).
- `expect.return` — deep-equal target for the call's return value.
- `expect.state` — deep-equal target for the full state snapshot after the call. `state.rng` (a closure) is stripped and replaced with `rngState` (the mulberry32 integer), matching what `serializeState()` does.

The runner helpers exist so a fixture can drive the engine into a specific state without depending on prior RNG history (e.g. force a `speed`-only price roster before testing `buy` overflow). Any Mojo/GDScript replay harness must implement the same helpers.

Each `.meta.json` sidecar records (`stateFields` is optional; see "State projection"):

```json
{
  "seed": 12345,
  "description": "31-day playthrough with deterministic policy",
  "mechanic": "end-to-end golden run",
  "stateFields": ["day", "bank"]
}
```

## Coverage

Beermat 2.1 is the fidelity target and `index.html` is frozen at the 1.2 rules, so the corpus holds only rules 2.1 keeps. Fixtures for replaced rules were retired (01, 04, 06, 08, 09, 12); `docs/parity-fixture-classification.md` records why and where each rule is pinned now.

| File | Exercises |
| --- | --- |
| `02-buy-sell-edges` | coat overflow, unaffordable, non-tradeable, partial sell |
| `03-travel-interest` | day advancement, 5% bank interest (the 1050 and 70 balances), no interest at 0 or below |
| `05-dealers` | coat dealer: cash path, pockets drawn on acceptance, no bank fallback |
| `07-finish-scoring` | `finish` score = cash + bank − debt, a dead player's score |
| `10-rolls-and-helpers` | `rollCoatDealerOffer` range ends and the `price < cash` offer rule, `applyDamage` health floor |
| `11-finances` | `finances` deposit/withdraw clamping to available cash/bank, amount floor, unknown action |

## State projection

A fixture's `.meta.json` may carry `stateFields`, the top-level state fields its steps exercise. `gen-mojo.mjs` then emits only those state pairs for the Mojo replay, so a kept fixture keeps gating the Mojo core when 2.1 changes the shape of a field it does not exercise (weapons for `guns`, loans for `debt`). Without the list every state field is compared. The node replay (`run.mjs`, `engine.test.mjs`) always compares the full snapshot, because the JS engine is frozen.

## Runner helpers

`setPrices`, `setPrevPrices`, `setInventory` and `setField` put the engine into a state without depending on RNG history, and a step with no `rng` draws from the seeded stream. The offer and accept calls take the RNG too (`rollCoatDealerOffer` one draw, `acceptCoatOffer` one on success and none on failure). A kept fixture's `setField` steps do not set fields outside its `stateFields` (no `debt` or `guns`).

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
node tests/fixtures/run.mjs 02 05
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

This overwrites every `.jsonl` and `.meta.json` named in `generate.mjs`. It does not delete a retired fixture's files; `git rm` them with the script entry. Review the diff carefully — any change means the parity contract with future ports has shifted. Regeneration must be a deliberate, reviewed step, not a reflex to a red test.

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

2. Run `node tests/fixtures/generate.mjs` to produce the `.jsonl` + `.meta.json`, then `node tests/fixtures/gen-mojo.mjs` for the Mojo corpus.
3. Run `node tests/fixtures/run.mjs 10-my-scenario` to confirm replay is stable.
4. Commit both files together with the generator change.

If your scenario needs a new kind of state manipulation, add a case to the `runStep` dispatch in `run-step.mjs` and document it under "runner helpers" above so a Mojo harness knows to implement it too.

## Why this exists

The Mojo port (TASK-001) will land layer by layer. Each layer is validated by replaying these fixtures against the Mojo `dw_world` handle via the frozen C ABI — same input sequence, same expected return, same expected snapshot. Any divergence is a bug in the port, full stop.
