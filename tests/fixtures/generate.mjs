// Fixture generator. Runs each scripted trace against the JS engine and
// writes a JSONL file (one step per line) plus a meta.json sidecar. The
// resulting files are the golden oracle; run.mjs replays them and asserts
// deep equality on every step.
//
// Regenerate after intentional engine changes:
//   node tests/fixtures/generate.mjs
//
// Adding a fixture: append a script to FIXTURES below. Each step is
//   { call: 'fnName', args: {...}, rng?: [floats] }
// where `call` is either an engine export or one of the runner helpers
// documented in tests/fixtures/README.md.
import { writeFileSync, mkdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { loadEngine, snapshotState } from './engine-loader.mjs'
import { makeRunStep } from './run-step.mjs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// A fixture is:
//   name: file basename (no extension)
//   meta: { seed, description, mechanic }
//   steps: array of { call, args?, rng? }
// Steps are executed in order against a single persistent state variable
// (populated by the first `newGame` step). Each step's expected return and
// post-call state snapshot are captured into the JSONL.
const FIXTURES = [
  {
    name: '01-price-generation',
    meta: { seed: 7, description: '10 generatePrices calls at seed 7 (bronx)', mechanic: 'price roster + event scaling' },
    steps: [
      { call: 'newGame', args: { seed: 7 } },
      ...Array.from({ length: 10 }, () => ({ call: 'generatePrices' })),
    ],
  },
  {
    name: '02-buy-sell-edges',
    meta: { seed: 1, description: 'buy/sell edge cases', mechanic: 'coat overflow, unaffordable, non-tradeable, partial sell' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      { call: 'setPrices', args: { speed: 100 } },
      { call: 'setField', args: { coatCapacity: 5 } },
      { call: 'buy', args: { drug: 'speed', qty: 5 } },
      { call: 'buy', args: { drug: 'speed', qty: 1 } }, // overflow
      { call: 'buy', args: { drug: 'cocaine', qty: 1 } }, // not tradeable
      { call: 'setField', args: { cash: 5 } },
      { call: 'setPrices', args: { cocaine: 15000 } },
      { call: 'buy', args: { drug: 'cocaine', qty: 1 } }, // unaffordable
      { call: 'setField', args: { cash: 2000, coatCapacity: 100 } },
      { call: 'setPrices', args: { speed: 100 } },
      { call: 'sell', args: { drug: 'speed', qty: 3 } },
      { call: 'sell', args: { drug: 'speed', qty: 99 } }, // over
      { call: 'setPrices', args: { cocaine: 20000 } },
      { call: 'sell', args: { drug: 'speed', qty: 1 } }, // not tradeable
    ],
  },
  {
    name: '03-travel-interest',
    meta: { seed: 1, description: 'travel across 5 days', mechanic: '10% debt compounding, 2% bank interest, day advancement' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      { call: 'setField', args: { bank: 1000 } },
      { call: 'travel', args: { dest: 'ghetto' } },
      { call: 'travel', args: { dest: 'centralpark' } },
      { call: 'travel', args: { dest: 'manhattan' } },
      { call: 'travel', args: { dest: 'coneyisland' } },
      { call: 'travel', args: { dest: 'brooklyn' } },
    ],
  },
  {
    name: '04-arrival-events',
    meta: { seed: 1, description: 'every rollArrivalEvent branch via scripted RNG', mechanic: 'mugged/freeDrugs/dogChase/foundDrugs/mamasBrownies/freeWeedDeath/flavor/none' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      { call: 'setPrices', args: { speed: 100 } },
      // mugged with cash: roll < 10, then randInt(80,95) for pct
      { call: 'setField', args: { cash: 1000, health: 100 } },
      { call: 'rollArrivalEvent', rng: [0.05, 0.5] },
      // mugged with $0: roll < 10, cash === 0 branch
      { call: 'setField', args: { cash: 0, health: 100 } },
      { call: 'rollArrivalEvent', rng: [0.05] },
      // freeDrugs: 10..30, drug pick, qty roll
      { call: 'setField', args: { cash: 500, health: 100, inventory: {}, coatCapacity: 100 } },
      { call: 'setPrices', args: { speed: 100 } },
      { call: 'rollArrivalEvent', rng: [0.15, 0.0, 0.0] },
      // freeDrugs with full coat -> none
      { call: 'setField', args: { coatCapacity: 5 } },
      { call: 'setInventory', args: { speed: 5 } },
      { call: 'rollArrivalEvent', rng: [0.15, 0.0, 0.5] },
      // dogChase: 30..50, held inventory, second rng < 0.5
      { call: 'setField', args: { coatCapacity: 100 } },
      { call: 'setInventory', args: { speed: 10 } },
      { call: 'rollArrivalEvent', rng: [0.35, 0.2, 0.0, 0.2] },
      // foundDrugs: 30..50, no held OR second rng >= 0.5
      { call: 'setInventory', args: {} },
      { call: 'setPrices', args: { speed: 100 } },
      { call: 'rollArrivalEvent', rng: [0.35, 0.0, 0.0] },
      // mamasBrownies: 50..60 with weed/hashish held
      { call: 'setInventory', args: { weed: 8 } },
      { call: 'rollArrivalEvent', rng: [0.55, 0.0] },
      // mamasBrownies with no weed/hashish -> none
      { call: 'setInventory', args: { speed: 5 } },
      { call: 'rollArrivalEvent', rng: [0.55] },
      // freeWeedDeath: 60..60.5
      { call: 'setField', args: { health: 100, dead: false } },
      { call: 'rollArrivalEvent', rng: [0.602] },
      // flavor: 60.5..75
      { call: 'setField', args: { health: 100, dead: false, cash: 500 } },
      { call: 'rollArrivalEvent', rng: [0.70, 0.0] },
      // none: >= 75
      { call: 'rollArrivalEvent', rng: [0.99] },
    ],
  },
  {
    name: '05-dealers',
    meta: { seed: 1, description: 'coat + gun dealer paths', mechanic: 'cash / bank+25% fee / insufficient' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      // coat cash path
      { call: 'setField', args: { cash: 500, bank: 0 } },
      { call: 'acceptCoatOffer', args: { offer: { pockets: 10, price: 300 } } },
      // coat bank+fee path
      { call: 'setField', args: { cash: 0, bank: 1000, coatCapacity: 100 } },
      { call: 'acceptCoatOffer', args: { offer: { pockets: 10, price: 400 } } },
      // coat insufficient
      { call: 'setField', args: { cash: 0, bank: 100, coatCapacity: 100 } },
      { call: 'acceptCoatOffer', args: { offer: { pockets: 10, price: 400 } } },
      // gun cash path
      { call: 'setField', args: { cash: 500, bank: 0, guns: 0 } },
      { call: 'acceptGunOffer', args: { offer: { price: 300, damage: 5, space: 4 } } },
      // gun bank+fee path
      { call: 'setField', args: { cash: 0, bank: 1000, guns: 0 } },
      { call: 'acceptGunOffer', args: { offer: { price: 400, damage: 5, space: 4 } } },
      // gun insufficient
      { call: 'setField', args: { cash: 0, bank: 100, guns: 0 } },
      { call: 'acceptGunOffer', args: { offer: { price: 400, damage: 5, space: 4 } } },
    ],
  },
  {
    name: '06-chase-combat',
    meta: { seed: 1, description: 'chase + combat branches', mechanic: 'startChase, runFromChase escape/fail/aggressor, fight hit/miss/won' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      // startChase without gun
      { call: 'startChase', rng: [] },
      // startChase with gun (canFight true)
      { call: 'setField', args: { guns: 1 } },
      { call: 'startChase', rng: [] },
      // runFromChase escape (defender, rng < 0.60)
      { call: 'setField', args: { health: 100 } },
      { call: 'runFromChase', args: { chase: { deputies: 3 }, isAggressor: false }, rng: [0.5] },
      // runFromChase fail (defender, rng > 0.60), incurs damage
      { call: 'setField', args: { health: 100 } },
      { call: 'runFromChase', args: { chase: { deputies: 3 }, isAggressor: false }, rng: [0.9, 0.5] },
      // runFromChase aggressor fails (rng > 0.30)
      { call: 'setField', args: { health: 100 } },
      { call: 'runFromChase', args: { chase: { deputies: 3 }, isAggressor: true }, rng: [0.5, 0.5] },
      // fight hit: attackRoll high, defendRoll low
      { call: 'setField', args: { health: 100, guns: 1 } },
      { call: 'fight', args: { chase: { deputies: 3 } }, rng: [0.99, 0.01] },
      // fight miss: attackRoll low, defendRoll high
      { call: 'setField', args: { health: 100 } },
      { call: 'fight', args: { chase: { deputies: 3 } }, rng: [0.01, 0.99, 0.99] },
      // fight kills last deputy -> won
      { call: 'setField', args: { health: 100 } },
      { call: 'fight', args: { chase: { deputies: 1 } }, rng: [0.99, 0.01] },
    ],
  },
  {
    name: '07-finish-scoring',
    meta: { seed: 1, description: 'finish + high score table', mechanic: 'score = cash + bank - debt, top-10 sort/truncate' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      { call: 'setField', args: { cash: 1000, bank: 500, debt: 200 } },
      { call: 'finish' },
      { call: 'setField', args: { dead: true, cash: 10, bank: 0, debt: 0 } },
      { call: 'finish' },
      { call: 'insertHighScores', args: { count: 12 } },
    ],
  },
  {
    name: '08-serialize-roundtrip',
    meta: { seed: 42, description: 'serialize -> deserialize preserves state', mechanic: 'save/load fidelity' },
    steps: [
      { call: 'newGame', args: { seed: 42 } },
      { call: 'travel', args: { dest: 'ghetto' } },
      { call: 'travel', args: { dest: 'manhattan' } },
      { call: 'serializeRoundTrip' },
    ],
  },
  {
    name: '09-full-run-31day',
    meta: { seed: 12345, description: '31-day playthrough with deterministic policy', mechanic: 'end-to-end golden run' },
    steps: (() => {
      // Policy: on each of days 1..30, travel to locations[(day) % 6]; on arrival,
      // if any drug is affordable and fits, buy 1 unit of the cheapest listed
      // drug. This exercises travel, price gen, buy, arrival events, and
      // interest compounding under a single seed's RNG stream.
      const steps = [{ call: 'newGame', args: { seed: 12345 } }]
      const locs = ['bronx', 'ghetto', 'centralpark', 'manhattan', 'coneyisland', 'brooklyn']
      for (let day = 1; day <= 30; day++) {
        const dest = locs[day % 6]
        steps.push({ call: 'travel', args: { dest } })
        steps.push({ call: 'buyCheapest' })
      }
      steps.push({ call: 'finish' })
      return steps
    })(),
  },
]

const Engine = loadEngine()
const runStep = makeRunStep(Engine)

function generate(fixture) {
  let state = null
  const lines = []
  fixture.steps.forEach((step, i) => {
    const ret = runStep(state, step)
    if (step.call === 'newGame') state = ret
    const record = {
      step: i,
      call: step.call,
      args: step.args || {},
    }
    if (step.rng) record.rng = step.rng
    record.expect = {
      return: JSON.parse(JSON.stringify(ret)),
      state: state ? snapshotState(state) : null,
    }
    lines.push(JSON.stringify(record))
  })
  return lines
}

function main() {
  const outDir = __dirname
  mkdirSync(outDir, { recursive: true })
  for (const fx of FIXTURES) {
    const lines = generate(fx)
    const jsonlPath = path.join(outDir, `${fx.name}.jsonl`)
    const metaPath = path.join(outDir, `${fx.name}.meta.json`)
    writeFileSync(jsonlPath, lines.join('\n') + '\n')
    writeFileSync(metaPath, JSON.stringify(fx.meta, null, 2) + '\n')
    console.log(`wrote ${fx.name}.jsonl (${lines.length} steps)`)
  }
}

main()
