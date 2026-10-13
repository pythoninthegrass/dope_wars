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

// A scripted draw that makes Random(n) return k.
const rnd = (k, n) => (k + 0.5) / n

// A fixture is:
//   name: file basename (no extension)
//   meta: { seed, description, mechanic }
//   steps: array of { call, args?, rng? }
// Steps are executed in order against a single persistent state variable
// (populated by the first `newGame` step). Each step's expected return and
// post-call state snapshot are captured into the JSONL.
const FIXTURES = [
  {
    name: '02-buy-sell-edges',
    meta: { seed: 1, description: 'buy/sell edge cases', mechanic: 'coat overflow, unaffordable, non-tradeable, partial sell', stateFields: ['cash', 'coatCapacity', 'inventory', 'prices'] },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      { call: 'setPrices', args: { speed: 100 } },
      { call: 'setField', args: { coatCapacity: 5 } },
      { call: 'buy', args: { drug: 'speed', qty: 5 } },
      { call: 'buy', args: { drug: 'speed', qty: 1 } }, // overflow
      { call: 'buy', args: { drug: 'speed', qty: 0 } }, // nothing to buy
      { call: 'buy', args: { drug: 'cocaine', qty: 1 } }, // not tradeable
      { call: 'setField', args: { cash: 5 } },
      { call: 'setPrices', args: { cocaine: 15000 } },
      { call: 'buy', args: { drug: 'cocaine', qty: 1 } }, // unaffordable
      { call: 'setField', args: { cash: 2000, coatCapacity: 100 } },
      { call: 'setPrices', args: { speed: 100 } },
      { call: 'sell', args: { drug: 'speed', qty: 3 } },
      { call: 'sell', args: { drug: 'speed', qty: 99 } }, // over
      { call: 'sell', args: { drug: 'speed', qty: 0 } }, // nothing to sell
      { call: 'setPrices', args: { cocaine: 20000 } },
      { call: 'sell', args: { drug: 'speed', qty: 1 } }, // not tradeable
    ],
  },
  {
    name: '03-travel-interest',
    meta: { seed: 1, description: 'travel day advancement and bank interest', mechanic: '5% bank interest at the 1050 and 70 balances, skipped at 0 or less, day advancement', stateFields: ['day', 'bank'] },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      { call: 'setField', args: { bank: 1000 } },
      { call: 'travel', args: { dest: 'ghetto' } },
      // 70 rounds to 74 in both 1.2 and 2.1; the other 1.2 tie balances and the debt chain are replaced (docs/parity-fixture-classification.md)
      { call: 'setField', args: { bank: 70 } },
      { call: 'travel', args: { dest: 'bronx' } },
      { call: 'setField', args: { bank: 0 } },
      { call: 'travel', args: { dest: 'ghetto' } },
      { call: 'setField', args: { bank: -100 } },
      { call: 'travel', args: { dest: 'bronx' } },
    ],
  },
  {
    name: '05-dealers',
    meta: { seed: 1, description: 'coat dealer acceptance', mechanic: 'cash only, pockets drawn on acceptance, no bank fallback', stateFields: ['cash', 'bank', 'coatCapacity'] },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      // coat cash path; the pocket draw is Random(10) + 11
      { call: 'setField', args: { cash: 500, bank: 0 } },
      { call: 'acceptCoatOffer', args: { offer: { price: 300 } }, rng: [0.0] },
      { call: 'setField', args: { cash: 500, bank: 0, coatCapacity: 100 } },
      { call: 'acceptCoatOffer', args: { offer: { price: 300 } }, rng: [0.999] },
      // coat is not paid from the bank, and nothing is drawn on failure
      { call: 'setField', args: { cash: 0, bank: 100000, coatCapacity: 100 } },
      { call: 'acceptCoatOffer', args: { offer: { price: 300 } }, rng: [] },
    ],
  },
  {
    name: '07-finish-scoring',
    meta: { seed: 1, description: 'finish scoring', mechanic: 'score = cash + bank - debt, dead player scores (Beermat M-13)', stateFields: ['cash', 'bank', 'dead', 'day'] },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      { call: 'setField', args: { cash: 1000, bank: 500, debt: 200 } },
      { call: 'finish' },
      { call: 'setField', args: { dead: true, cash: 10, bank: 0, debt: 0 } },
      { call: 'finish' },
    ],
  },
  {
    name: '10-rolls-and-helpers',
    meta: { seed: 1, description: 'coat dealer offer and damage helpers', mechanic: 'coat dealer offer price range and the price < cash rule, applyDamage health floor', stateFields: ['cash', 'health', 'dead'] },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      // rollCoatDealerOffer: price = randInt(201, 350), offered only when price < cash.
      { call: 'setField', args: { cash: 10000 } },
      { call: 'rollCoatDealerOffer', rng: [0.0] },
      { call: 'rollCoatDealerOffer', rng: [0.999999] },
      { call: 'setField', args: { cash: 201 } },
      { call: 'rollCoatDealerOffer', rng: [0.0] },
      { call: 'setField', args: { cash: 202 } },
      { call: 'rollCoatDealerOffer', rng: [0.0] },
      // applyDamage returns the new health and sets dead at zero.
      { call: 'setField', args: { health: 100, dead: false } },
      { call: 'applyDamage', args: { amount: 30 } },
      { call: 'applyDamage', args: { amount: 1000 } },
    ],
  },
  {
    name: '11-finances',
    meta: { seed: 1, description: 'deposit / withdraw', mechanic: 'clamping to available cash and bank, amount floor, unknown action', stateFields: ['cash', 'bank'] },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      { call: 'setField', args: { cash: 2000, bank: 0 } },
      { call: 'finances', args: { action: 'deposit', amount: 500 } },
      { call: 'finances', args: { action: 'deposit', amount: 99999 } }, // clamps to cash
      { call: 'finances', args: { action: 'withdraw', amount: 200 } },
      { call: 'finances', args: { action: 'withdraw', amount: 99999 } }, // clamps to bank
      // amount is floored, and a negative amount is clamped to zero.
      { call: 'setField', args: { cash: 100, bank: 0 } },
      { call: 'finances', args: { action: 'deposit', amount: 10.7 } },
      { call: 'finances', args: { action: 'deposit', amount: -50 } },
      { call: 'finances', args: { action: 'deposit', amount: 0 } },
      { call: 'finances', args: { action: 'bogus', amount: 100 } },
    ],
  },
]

const Engine = loadEngine()
const runStep = makeRunStep(Engine)

function generate(fixture) {
  let state = null
  const lines = []
  fixture.steps.forEach((step, i) => {
    // The engine mutates a chase argument in place; the record keeps the input.
    const ret = runStep(state, { ...step, args: structuredClone(step.args || {}) })
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
