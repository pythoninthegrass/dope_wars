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
    meta: { seed: 1, description: 'travel across 5 days', mechanic: '10% debt compounding, 5% bank interest, day advancement' },
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
    meta: { seed: 1, description: 'every rollArrivalEvent branch via scripted RNG', mechanic: 'Random(14) chance, wealth-cap mugging, Random(4) outcome: found/mugged/friend/police dogs' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      { call: 'setPrices', args: { cocaine: 100, acid: 50 } },
      { call: 'setPrevPrices', args: { cocaine: 100, acid: 50 } },
      // miss: Random(14) != 0
      { call: 'rollArrivalEvent', rng: [rnd(1, 14)] },
      // outcome 1, mugged for cash div 4 then cash div 3
      { call: 'setField', args: { cash: 1000, health: 100 } },
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(1, 4), rnd(1, 2)] },
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(1, 4), rnd(0, 2)] },
      // outcome 1 with no cash takes nothing
      { call: 'setField', args: { cash: 0 } },
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(1, 4), rnd(0, 2)] },
      // wealth cap: forced mugging with no event or outcome draw
      { call: 'setField', args: { cash: 60000000, bank: 40000000 } },
      { call: 'rollArrivalEvent', rng: [rnd(1, 2)] },
      // exactly 99,999,999 is not forced
      { call: 'setField', args: { cash: 99999999, bank: 0 } },
      { call: 'rollArrivalEvent', rng: [rnd(5, 14)] },
      // outcome 0, found: hashish is absent so the pick is redrawn, the average cost dilutes (10 * 100 div 15)
      { call: 'setField', args: { cash: 5000, bank: 0 } },
      { call: 'buy', args: { drug: 'cocaine', qty: 10 } },
      { call: 'setPrevPrices', args: { cocaine: 100, acid: 50 } },
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(0, 4), rnd(2, 11), rnd(1, 11), rnd(3, 7)] },
      // full coat skips outcomes 0 and 2 before any drug draw
      { call: 'setField', args: { coatCapacity: 15 } },
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(0, 4)] },
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(2, 4)] },
      // quantity capped at the free space
      { call: 'setField', args: { coatCapacity: 17 } },
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(0, 4), rnd(1, 11), rnd(6, 7)] },
      // weed (Beermat index 11) is never picked, so nothing is drawn after the outcome
      { call: 'setField', args: { coatCapacity: 100 } },
      { call: 'setPrevPrices', args: { weed: 500 } },
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(0, 4)] },
      // outcome 2, a friend lays units on the player
      { call: 'setPrevPrices', args: { speed: 100, acid: 50 } },
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(2, 4), rnd(10, 11), rnd(4, 7)] },
      // outcome 3 with drugs held: redraw until held, drop min(Random(held) + 1, 10)
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(3, 4), rnd(2, 12), rnd(1, 12), rnd(2, 4), rnd(16, 17), rnd(0, 4)] },
      // outcome 3 where the 50% roll keeps the drugs
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(3, 4), rnd(1, 12), rnd(0, 4), rnd(1, 4)] },
      // outcome 3 with an empty coat
      { call: 'setInventory', args: {} },
      { call: 'rollArrivalEvent', rng: [rnd(0, 14), rnd(3, 4), rnd(2, 4)] },
    ],
  },
  {
    name: '05-dealers',
    meta: { seed: 1, description: 'coat + gun dealer acceptance', mechanic: 'cash only, pockets drawn on acceptance, no bank fallback, a gun uses no coat space' },
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
      // gun cash path
      { call: 'setField', args: { cash: 500, bank: 0, guns: 0 } },
      { call: 'acceptGunOffer', args: { offer: { price: 300, nameIndex: 0 } } },
      // a gun fits in a full coat
      { call: 'setField', args: { cash: 500, guns: 0 } },
      { call: 'setInventory', args: { weed: 100 } },
      { call: 'acceptGunOffer', args: { offer: { price: 300, nameIndex: 1 } } },
      // gun is not paid from the bank
      { call: 'setField', args: { cash: 0, bank: 100000, guns: 0 } },
      { call: 'acceptGunOffer', args: { offer: { price: 400, nameIndex: 2 } } },
    ],
  },
  {
    name: '06-chase-combat',
    meta: { seed: 1, description: 'chase + combat branches', mechanic: 'startChase, runFromChase escape/fail/aggressor, fight hit/miss/won' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      // startChase without gun
      { call: 'startChase', rng: [0.5] },
      // startChase with gun (canFight true)
      { call: 'setField', args: { guns: 1 } },
      { call: 'startChase', rng: [0.5] },
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
  {
    name: '10-rolls-and-helpers',
    meta: { seed: 1, description: 'RNG-driven rolls and pure helpers', mechanic: 'shouldStartChase flat 1 in 6, coat/gun dealer offers, getFightRatings, applyDamage' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      // shouldStartChase: Random(6) == 0, so only the first sixth of [0,1) starts a chase.
      { call: 'shouldStartChase', rng: [0.0] },
      { call: 'shouldStartChase', rng: [0.1666] }, // floor(0.1666*6) = 0 -> true
      { call: 'shouldStartChase', rng: [0.1667] }, // floor(0.1667*6) = 1 -> false
      { call: 'shouldStartChase', rng: [0.999] },
      // The odds do not depend on the location.
      { call: 'travel', args: { dest: 'manhattan' } },
      { call: 'shouldStartChase', rng: [0.0] },
      { call: 'shouldStartChase', rng: [0.999] },
      // rollCoatDealerOffer: price = randInt(201, 350), offered only when price < cash.
      { call: 'setField', args: { cash: 10000 } },
      { call: 'rollCoatDealerOffer', rng: [0.0] },
      { call: 'rollCoatDealerOffer', rng: [0.999999] },
      { call: 'setField', args: { cash: 201 } },
      { call: 'rollCoatDealerOffer', rng: [0.0] },
      { call: 'setField', args: { cash: 202 } },
      { call: 'rollCoatDealerOffer', rng: [0.0] },
      // rollGunDealerOffer: price = randInt(301, 550), then the name draw only when offered.
      { call: 'setField', args: { cash: 10000 } },
      { call: 'rollGunDealerOffer', rng: [0.0, 0.0] },
      { call: 'rollGunDealerOffer', rng: [0.999999, 0.999] },
      { call: 'setField', args: { cash: 301 } },
      { call: 'rollGunDealerOffer', rng: [0.0] },
      { call: 'setField', args: { cash: 302 } },
      { call: 'rollGunDealerOffer', rng: [0.0, 0.5] },
      // getFightRatings: attack = 80 + guns*5, defend = 100.
      { call: 'setField', args: { guns: 0 } },
      { call: 'getFightRatings' },
      { call: 'setField', args: { guns: 3 } },
      { call: 'getFightRatings' },
      // applyDamage returns the new health and sets dead at zero.
      { call: 'setField', args: { guns: 0, health: 100, dead: false } },
      { call: 'applyDamage', args: { amount: 30 } },
      { call: 'applyDamage', args: { amount: 1000 } },
    ],
  },
  {
    name: '11-finances',
    meta: { seed: 1, description: 'deposit / withdraw / payLoan', mechanic: 'clamping to available cash/bank/debt, amount floor, unknown action' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      { call: 'setField', args: { cash: 2000, bank: 0, debt: 5500 } },
      { call: 'finances', args: { action: 'deposit', amount: 500 } },
      { call: 'finances', args: { action: 'deposit', amount: 99999 } }, // clamps to cash
      { call: 'finances', args: { action: 'withdraw', amount: 200 } },
      { call: 'finances', args: { action: 'withdraw', amount: 99999 } }, // clamps to bank
      { call: 'finances', args: { action: 'payLoan', amount: 1000 } },
      { call: 'finances', args: { action: 'payLoan', amount: 99999 } }, // clamps to min(cash, debt)
      // amount is floored, and a negative amount is clamped to zero.
      { call: 'setField', args: { cash: 100, bank: 0, debt: 0 } },
      { call: 'finances', args: { action: 'deposit', amount: 10.7 } },
      { call: 'finances', args: { action: 'deposit', amount: -50 } },
      { call: 'finances', args: { action: 'deposit', amount: 0 } },
      { call: 'finances', args: { action: 'bogus', amount: 100 } },
    ],
  },
  {
    name: '12-dealer-visits',
    meta: { seed: 4, description: 'combined dealer visit draw', mechanic: 'rollDealerVisit seeded stream, 1 in 14 boundary, Random(4) coat/gun split, chase skip' },
    steps: [
      // A) Seeded stream: back-to-back calls pin the kind and rngState, so the
      //    draw count (one on a miss, two on a visit) is an oracle fact.
      { call: 'newGame', args: { seed: 4 } },
      ...Array.from({ length: 40 }, () => ({ call: 'rollDealerVisit' })),
      // B) Scripted RNG: Random(4) of 0 and 2 is the coat dealer, 1 and 3 the gun dealer.
      { call: 'rollDealerVisit', rng: [0.0, 0.0] },
      { call: 'rollDealerVisit', rng: [0.0, 0.25] },
      { call: 'rollDealerVisit', rng: [0.0, 0.5] },
      { call: 'rollDealerVisit', rng: [0.0, 0.75] },
      // C) The 1 in 14 boundary: the last value that visits, and the first that does not.
      { call: 'rollDealerVisit', rng: [0.0714, 0.0] },
      { call: 'rollDealerVisit', rng: [0.0715] },
      { call: 'rollDealerVisit', rng: [0.999] },
      // D) Chase: the arrival sequence skips the dealer when a chase starts.
      //    shouldStartChase spends exactly one draw, so repeating the identical
      //    roll must land on the same rngState; a chase path that also spent
      //    the dealer draws would be further along.
      { call: 'setField', args: { location: 'manhattan' } },
      { call: 'shouldStartChase', rng: [0.0] },
      { call: 'shouldStartChase', rng: [0.0] },
      // A live twin that is offered the dealer spends the draw the chase saved.
      { call: 'setField', args: { location: 'bronx' } },
      { call: 'rollDealerVisit' },
    ],
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
