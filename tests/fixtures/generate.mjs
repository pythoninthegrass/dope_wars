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
  {
    name: '10-rolls-and-helpers',
    meta: { seed: 1, description: 'RNG-driven rolls and pure helpers', mechanic: 'shouldStartChase police weighting, coat/gun dealer offer ranges, getFightRatings, applyDamage' },
    steps: [
      { call: 'newGame', args: { seed: 1 } },
      // shouldStartChase: randInt(rng, 0, 80 + police) >= 50. Bronx has police 10,
      // so the span is 0..90 and the threshold sits between 49 and 50.
      { call: 'shouldStartChase', rng: [0.0] },
      { call: 'shouldStartChase', rng: [0.54] }, // floor(0.54*91) = 49 -> false
      { call: 'shouldStartChase', rng: [0.55] }, // floor(0.55*91) = 50 -> true
      { call: 'shouldStartChase', rng: [0.999] },
      // Manhattan has police 90, so the span widens to 0..170.
      { call: 'travel', args: { dest: 'manhattan' } },
      { call: 'shouldStartChase', rng: [0.0] },
      { call: 'shouldStartChase', rng: [0.999] },
      // rollCoatDealerOffer: pockets = randInt(10,30), price = randInt(200,500).
      { call: 'rollCoatDealerOffer', rng: [0.0, 0.0] },
      { call: 'rollCoatDealerOffer', rng: [0.999, 0.999] },
      // rollGunDealerOffer: price = randInt(250,600), damage/space from RULES.
      { call: 'rollGunDealerOffer', rng: [0.0] },
      { call: 'rollGunDealerOffer', rng: [0.999] },
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
    meta: { seed: 13, description: 'coat/gun dealer visit draws', mechanic: 'rollDealerVisits seeded stream, four scripted combinations, dead-player draw consumption, chase skip' },
    steps: [
      // A) Seeded stream: eight back-to-back calls. Seed 13 is chosen so the
      //    first eight pairs are varied (coat-only, both, and five plain
      //    misses) rather than eight identical false/false lines. Every line
      //    pins the pair *and* rngState, so the draw count and the coat-then-gun
      //    order are oracle facts: a core that drew once per call, or skipped a
      //    draw when the pair came out false/false, would desync rngState from
      //    this line onward, not just on the line it got wrong.
      { call: 'newGame', args: { seed: 13 } },
      ...Array.from({ length: 8 }, () => ({ call: 'rollDealerVisits' })),
      // B) Scripted RNG: the four reported combinations, forced rather than
      //    left to whichever way a seed falls. A script is injected for one
      //    call and is not drawn from state.rng, so each of these lines records
      //    rngState unchanged from the seeded run — scripted mode is not an
      //    extra draw. The last two pin the 0.15 boundary itself: just under it
      //    visits, exactly it does not.
      { call: 'rollDealerVisits', rng: [0.1, 0.5] }, // coat only
      { call: 'rollDealerVisits', rng: [0.5, 0.1] }, // gun only
      { call: 'rollDealerVisits', rng: [0.1, 0.1] }, // both
      { call: 'rollDealerVisits', rng: [0.5, 0.5] }, // neither
      { call: 'rollDealerVisits', rng: [0.1499999999, 0.1499999999] },
      { call: 'rollDealerVisits', rng: [0.15, 0.15] },
      // C) The dead player draws anyway. `dead` is true, so this call reports
      //    false/false -- and its post-call rngState is required to equal the
      //    live twin's two steps below, which made the same two scripted draws
      //    with `dead` false. Asserting only the false/false pair would also
      //    pass an implementation that tested `dead` before drawing; the
      //    rngState equality is the part that rules that out. The live twin's
      //    pair here (coat, gun both true) is what makes the next line's
      //    false/false a suppression rather than two losing draws.
      { call: 'setField', args: { dead: true, health: 0 } },
      { call: 'rollDealerVisits', rng: [0.1, 0.1] },
      { call: 'setField', args: { dead: false, health: 100 } },
      { call: 'rollDealerVisits', rng: [0.1, 0.1] },
      // D) Chase: index.html:1382-1383 pushes the chase and the two dealer
      //    draws in the else branch are never reached. The skip is stated as a
      //    draw budget rather than inferred from an absent step: Manhattan
      //    (police 90) makes shouldStartChase spend exactly one draw, so
      //    repeating the identical roll must land on the same rngState. Had the
      //    chase path also spent the two dealer draws, the second line would be
      //    two draws further along.
      { call: 'setField', args: { location: 'manhattan' } },
      // 0.5 scales to floor(0.5 * 171) = 85 >= 50, so the chase fires.
      { call: 'shouldStartChase', rng: [0.5] },
      { call: 'shouldStartChase', rng: [0.5] },
      // A live twin that *is* offered the dealers spends the two draws the chase
      // path saved, so it lands two draws further along than the chase twin
      // above.
      { call: 'setField', args: { location: 'bronx' } },
      { call: 'rollDealerVisits' },
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
