# Mojo parity harness

Replays the JS oracle corpus (`tests/fixtures/*.jsonl`) against the Mojo core in
`core/src/`. This is the gate that decides whether the port is at parity: every
recorded return value and every recorded state snapshot must match.

```sh
task core:test                    # every test file under tests/mojo/
task core:test:check-generated    # fail if fixtures.mojo is stale
```

`task check` runs `core:test` before the Godot build, so a parity regression
fails the whole pipeline.

## Layout

```text
tests/mojo/
  fixtures.mojo     # GENERATED from tests/fixtures/*.jsonl — do not edit
  lexeme.mojo       # decode the flat scalar lexemes
  record.mojo       # parse one flattened fixture step
  harness.mojo      # compare a World against an oracle snapshot
  replay.mojo       # the step dispatcher and per-fixture replay driver
  parity_test.mojo  # one test per fixture
  *_test.mojo       # focused per-subsystem tests
```

## Why the fixtures are flattened

Mojo 1.1.0 ships no `std.json` and no `std.parse`, and a recursive JSON value
type fights Mojo's ownership rules. So `tests/fixtures/gen-mojo.mjs` flattens
each JSONL step into one record of `dotted.path=lexeme` pairs, which the reader
handles by splitting strings only:

```text
fixture | call | rng lexemes | arg pairs | return pairs | state pairs
```

Pairs keep the oracle's document order. That is load-bearing, not cosmetic: the
JS engine's `state.prices` and `state.inventory` are insertion-ordered objects,
`Object.keys()` order picks the drug in `randomTradeableDrug()` and in the
dogChase branch, and the oracle's own `deepEqual` is `JSON.stringify`.

The generator's allow-list is closed. An oracle field that is not explicitly
permitted fails generation, so a new field in `index.html`'s engine cannot slip
past the port unnoticed. The only ignored fields are the JS-only artifacts core
must not reproduce: presentation `message` strings
(`docs/layer-boundaries.md` forbids them in core) and fixture 08's JSON save
blob.

Non-integer values are transmitted as an IEEE-754 decomposition
(`d:sign:exp:mant`) rather than a decimal. A float64's shortest round-trip
decimal can need 17 significant digits, which overflows the 2^53 that Int64
mantissa arithmetic holds exactly — the corpus's `128.16666666666666` (a
bank-interest product) is such a value, and no power of ten reproduces it
exactly. Reassembling the decomposition is exact at every step.

## Export coverage

Every function exported at `index.html:1049-1077` is implemented in `core/src/`
and covered here. "Fixture" means the oracle drives it; "direct" means a focused
test asserts it, because the corpus has no step that reaches it.

| Export | Core | Covered by |
| --- | --- | --- |
| `RULES` | `rules.mojo` | direct (`rules_test`) |
| `mulberry32` | `rng.mojo` | direct (`rng_test`) + every fixture's `rngState` |
| `randInt` | `rng.mojo` | direct (`rng_test`) |
| `newGame` | `world.mojo` | fixture 01 step 0, and every fixture's first step |
| `coatUsed` | `world.mojo` | direct (`world_test`) + fixtures 02, 05 |
| `generatePrices` | `prices.mojo` | fixture 01 |
| `buy` | `trade.mojo` | fixture 02 |
| `sell` | `trade.mojo` | fixture 02 |
| `travel` | `travel.mojo` | fixture 03 |
| `finances` | `finances.mojo` | fixture 11 |
| `rollArrivalEvent` | `events.mojo` | fixture 04 |
| `rollDealerVisit` | `dealers.mojo` | fixture 12 |
| `rollCoatDealerOffer` | `dealers.mojo` | fixture 10 |
| `acceptCoatOffer` | `dealers.mojo` | fixture 05 |
| `rollGunDealerOffer` | `dealers.mojo` | fixture 10 |
| `acceptGunOffer` | `dealers.mojo` | fixture 05 |
| `shouldStartChase` | `combat.mojo` | fixture 10 |
| `startChase` | `combat.mojo` | fixture 06 |
| `runFromChase` | `combat.mojo` | fixture 06 |
| `stayInChase` | `combat.mojo` | fixture 06 |
| `fight` | `combat.mojo` | fixture 06 |
| `acceptDoctorOffer` | `combat.mojo` | fixture 06 |
| `applyDamage` | `events.mojo` | fixture 10 |
| `finish` | `score.mojo` | fixture 07 |
| `insertHighScore` | `score.mojo` | fixture 07 |
| `findDrug` | `rules.mojo` | direct (`rules_test`) |
| `findLocation` | `rules.mojo` | direct (`rules_test`) |
| `serializeState` | `serialize.mojo` | fixture 08 |
| `deserializeState` | `serialize.mojo` | fixture 08 |

## Deliberate divergences from the JS engine

These are the only places the Mojo core is not a literal transcription. Each is
forced by `docs/layer-boundaries.md` or by the frozen ABI.

- **No presentation strings.** The JS engine returns English sentences in
  `reason` and `message`. Core returns a `dw_result`-style code
  (`core/src/result.mojo`) and structured event payloads; the game layer renders
  the sentence. The harness maps the oracle's sentence back to a code.
- **Scripted RNG is a first-class mode.** In JS, `rng` is an injected
  `() => float`. The Mojo `Rng` has the same two modes: seeded mulberry32 and a
  caller-supplied float list. The C ABI does **not** expose script mode
  (TASK-001.05): `dw_config` carries only a `rng_seed`, and the world's stream
  is always seeded. Script mode exists for the parity harness, which sets the
  field directly; a game never needs to force a branch.
- **Serialization is bytes, not JSON.** `serializeState`/`deserializeState`
  round-trip through JSON in JS. Core produces an opaque byte buffer, which is
  what `dw_world_dump`/`dw_world_load` hand to the game layer. Floats go through
  `floatbits.mojo`, so a save/load cycle is bit-exact.
- **Money stays float64.** `cash`, `bank`, `debt` and `avgPrice` are `Float64`
  because the oracle's are (`bank` goes 5500 → 5610 → 5722.2). The ABI's
  `dw_state_view` exposes `bank`/`debt` as `int64_t`, so those view fields are a
  lossy display projection; persistence is unaffected because the dump keeps the
  raw float64. TASK-001.05 owns pinning the view-rounding rule.

## Adding a test

Focused tests are plain `def test_*() raises` functions in a `*_test.mojo` file
with a `main()` that runs `TestSuite.discover_tests[__functions_in_module()]()`.
`task core:test` picks up any new `*_test.mojo` automatically.

To add fixture-driven coverage, add a fixture to `tests/fixtures/generate.mjs`,
regenerate, and add a `test_*` to `parity_test.mojo` that calls
`replay.replay_fixture("<name>")`. If the new fixture uses a call the dispatcher
does not know, add a case to `run_step` in `replay.mojo`.
