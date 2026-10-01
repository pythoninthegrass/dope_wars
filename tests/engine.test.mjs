// Extracts the #engine <script> block from index.html and evaluates it in a
// vm context, so the game logic is tested exactly as shipped in the single
// playable file (no build step, no separate module to drift from index.html).
import { test, describe } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import vm from 'node:vm'
import { snapshotState } from './fixtures/engine-loader.mjs'
import { makeRunStep } from './fixtures/run-step.mjs'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const html = readFileSync(path.join(__dirname, '..', 'index.html'), 'utf8')

function extractScript(id) {
  const re = new RegExp(`<script id="${id}">([\\s\\S]*?)</script>`)
  const m = html.match(re)
  if (!m) throw new Error(`could not find <script id="${id}"> in index.html`)
  return m[1]
}

function loadEngine() {
  const context = { console }
  context.window = context
  vm.createContext(context)
  vm.runInContext(extractScript('engine'), context, { filename: 'engine.js' })
  return context.DopeWarsEngine
}

const Engine = loadEngine()

describe('engine module shape', () => {
  test('exports DopeWarsEngine with RULES and core functions', () => {
    assert.ok(Engine, 'DopeWarsEngine global should exist after evaluating #engine')
    assert.ok(Engine.RULES, 'RULES table should be exported')
    assert.equal(typeof Engine.newGame, 'function')
    assert.equal(typeof Engine.generatePrices, 'function')
    assert.equal(typeof Engine.buy, 'function')
    assert.equal(typeof Engine.sell, 'function')
    assert.equal(typeof Engine.travel, 'function')
    assert.equal(typeof Engine.finances, 'function')
    assert.equal(typeof Engine.rollArrivalEvent, 'function')
    assert.equal(typeof Engine.startChase, 'function')
    assert.equal(typeof Engine.runFromChase, 'function')
    assert.equal(typeof Engine.fight, 'function')
    assert.equal(typeof Engine.finish, 'function')
    assert.equal(typeof Engine.mulberry32, 'function')
    assert.equal(typeof Engine.randInt, 'function')
  })

  test('RULES has 6 boroughs and 12 drugs', () => {
    assert.equal(Engine.RULES.locations.length, 6)
    assert.equal(Engine.RULES.drugs.length, 12)
  })

  test('drug table matches the Beermat records (min, max, crash=cheap, spike=expensive)', () => {
    const beermat = {
      acid: [1000, 4500, true, false],
      cocaine: [15000, 30000, false, true],
      crack: [1000, 3500, false, false],
      ecstasy: [10, 60, true, false],
      hashish: [450, 1350, true, false],
      heroin: [5000, 14000, false, true],
      opium: [500, 1300, false, true],
      peyote: [200, 700, false, false],
      shrooms: [600, 1350, false, false],
      smack: [1500, 4500, false, false],
      speed: [70, 250, false, true],
      weed: [300, 900, true, false],
    }
    assert.deepEqual(Object.keys(beermat).sort(), [...Engine.RULES.drugs.map((d) => d.id)].sort())
    for (const d of Engine.RULES.drugs) {
      assert.deepEqual([d.min, d.max, d.cheap, d.expensive], beermat[d.id], d.id)
    }
  })
})

describe('seeded RNG', () => {
  test('mulberry32 is deterministic for a given seed', () => {
    const a = Engine.mulberry32(12345)
    const b = Engine.mulberry32(12345)
    const seqA = Array.from({ length: 10 }, () => a())
    const seqB = Array.from({ length: 10 }, () => b())
    assert.deepEqual(seqA, seqB)
  })

  test('randInt stays within [min, max] inclusive over many draws', () => {
    const rng = Engine.mulberry32(42)
    for (let i = 0; i < 1000; i++) {
      const n = Engine.randInt(rng, 5, 9)
      assert.ok(n >= 5 && n <= 9, `randInt out of range: ${n}`)
    }
  })
})

describe('newGame', () => {
  test('sets the classic starting state', () => {
    const state = Engine.newGame({ seed: 1 })
    assert.equal(state.day, 1)
    assert.equal(state.numDays, 31)
    assert.equal(state.cash, 2000)
    assert.equal(state.debt, 5500)
    assert.equal(state.bank, 0)
    assert.equal(state.health, 100)
    assert.equal(state.coatCapacity, 100)
    assert.equal(state.guns, 0)
    assert.equal(state.location, 'bronx')
    assert.equal(Object.keys(state.inventory).length, 0)
  })

  test('honors custom numDays and startCash overrides', () => {
    const state = Engine.newGame({ seed: 1, numDays: 10, startCash: 5000 })
    assert.equal(state.numDays, 10)
    assert.equal(state.cash, 5000)
  })
})

// Builds the rng draw sequence generatePrices consumes: per drug, in engine order, price then availability then the spike and crash rolls (drawn even when the drug is absent), then the bust/addicts pick only for an available spike hit.
function priceDraws(drugs, { absent = new Set(), spike = false, crash = false } = {}) {
  const draws = []
  for (const drug of drugs) {
    const available = !absent.has(drug.id)
    draws.push(0)
    draws.push(available ? 0.999 : 0)
    if (drug.expensive) {
      const hit = spike
      draws.push(hit ? 0 : 0.999)
      if (hit && available) draws.push(0)
    }
    if (drug.cheap) draws.push(crash ? 0 : 0.999)
  }
  return draws
}

function scriptedRng(draws) {
  let i = 0
  const rng = () => {
    if (i >= draws.length) throw new Error(`rng exhausted after ${draws.length} draws`)
    return draws[i++]
  }
  rng.drawn = () => i
  return rng
}

describe('shouldStartChase', () => {
  test('locations carry no police weight', () => {
    for (const loc of Engine.RULES.locations) assert.equal('police' in loc, false, loc.id)
  })

  test('starts on a Random(6) == 0 draw at every location, spending one draw', () => {
    const state = Engine.newGame({ seed: 3 })
    for (const loc of Engine.RULES.locations) {
      state.location = loc.id
      const hit = scriptedRng([0.0])
      assert.equal(Engine.shouldStartChase(state, hit), true, loc.id)
      assert.equal(hit.drawn(), 1)
      // 1/6 is the edge of the first bucket; 1/6 + epsilon rolls a 1
      assert.equal(Engine.shouldStartChase(state, scriptedRng([0.1666])), true, loc.id)
      assert.equal(Engine.shouldStartChase(state, scriptedRng([0.1667])), false, loc.id)
      assert.equal(Engine.shouldStartChase(state, scriptedRng([0.999])), false, loc.id)
    }
  })

  test('chase frequency is about 1 in 6 at every location', () => {
    const n = 12000
    for (const loc of Engine.RULES.locations) {
      const state = Engine.newGame({ seed: 5 })
      state.location = loc.id
      let hits = 0
      for (let i = 0; i < n; i++) if (Engine.shouldStartChase(state, state.rng)) hits++
      const rate = hits / n
      assert.ok(rate > 0.15 && rate < 0.185, `${loc.id} chase rate ${rate}`)
    }
  })
})

describe('generatePrices', () => {
  test('locations carry no per-borough drug count', () => {
    for (const loc of Engine.RULES.locations) {
      assert.equal('minDrugs' in loc, false, loc.id)
      assert.equal('maxDrugs' in loc, false, loc.id)
    }
  })

  test('each drug is unavailable about 1 time in 8 at every location', () => {
    const state = Engine.newGame({ seed: 8 })
    const n = 3000
    for (const loc of Engine.RULES.locations) {
      state.location = loc.id
      const absent = {}
      for (let i = 0; i < n; i++) {
        Engine.generatePrices(state)
        for (const drug of Engine.RULES.drugs) {
          if (!(drug.id in state.prices)) absent[drug.id] = (absent[drug.id] || 0) + 1
        }
      }
      for (const drug of Engine.RULES.drugs) {
        const rate = (absent[drug.id] || 0) / n
        assert.ok(rate > 0.10 && rate < 0.15, `${loc.id} ${drug.id} absent rate ${rate}`)
      }
    }
  })

  test('the traded count can be anywhere from none to all twelve drugs', () => {
    const drugs = Engine.RULES.drugs
    const none = Engine.newGame({ seed: 1 })
    none.rng = scriptedRng(priceDraws(drugs, { absent: new Set(drugs.map((d) => d.id)) }))
    Engine.generatePrices(none)
    assert.equal(Object.keys(none.prices).length, 0)
    assert.deepEqual([...none.priceEvents], [])

    const all = Engine.newGame({ seed: 1 })
    all.rng = scriptedRng(priceDraws(drugs))
    Engine.generatePrices(all)
    assert.equal(Object.keys(all.prices).length, drugs.length)
  })

  test('draws per drug are price, availability, then the flagged spike and crash rolls, even for an absent drug', () => {
    const drugs = Engine.RULES.drugs
    const flagged = drugs.filter((d) => d.cheap).length + drugs.filter((d) => d.expensive).length
    const expectedDraws = drugs.length * 2 + flagged
    const state = Engine.newGame({ seed: 1 })
    const absent = new Set(['acid', 'cocaine'])
    const rng = scriptedRng(priceDraws(drugs, { absent, spike: true, crash: true }))
    state.rng = rng
    Engine.generatePrices(state)
    assert.equal(rng.drawn(), expectedDraws + drugs.filter((d) => d.expensive && !absent.has(d.id)).length)
    assert.equal('acid' in state.prices, false)
    assert.equal('cocaine' in state.prices, false)
    assert.equal(state.priceEvents.some((e) => absent.has(e.drug)), false)
    assert.ok(state.priceEvents.some((e) => e.drug === 'heroin'))
  })

  test('every listed price is within the drug base range, or scaled x5 / div 10 for an event', () => {
    const state = Engine.newGame({ seed: 99 })
    for (let i = 0; i < 50; i++) {
      Engine.generatePrices(state)
      for (const [drugId, price] of Object.entries(state.prices)) {
        const drug = Engine.RULES.drugs.find((d) => d.id === drugId)
        const cheapFloor = Math.floor(drug.min / 10)
        const expensiveCeil = drug.max * 5
        assert.ok(price >= cheapFloor && price <= expensiveCeil, `${drugId} price ${price} outside plausible [${cheapFloor},${expensiveCeil}]`)
      }
    }
  })

  test('when every 1-in-20 roll hits, each available spike drug costs min x5 and each crash drug min div 10', () => {
    const state = Engine.newGame({ seed: 5 })
    state.rng = scriptedRng(priceDraws(Engine.RULES.drugs, { spike: true, crash: true }))
    Engine.generatePrices(state)
    assert.equal(Engine.RULES.expensiveMultiply, 5)
    assert.equal(Engine.RULES.cheapDivide, 10)
    let spikes = 0
    let crashes = 0
    for (const drug of Engine.RULES.drugs) {
      if (!(drug.id in state.prices)) continue
      if (drug.expensive) {
        spikes++
        assert.equal(state.prices[drug.id], drug.min * 5, drug.id)
      } else if (drug.cheap) {
        crashes++
        assert.equal(state.prices[drug.id], Math.floor(drug.min / 10), drug.id)
      } else {
        assert.equal(state.prices[drug.id], drug.min, drug.id)
      }
    }
    assert.ok(spikes > 0 && crashes > 0)
    assert.equal(state.priceEvents.length, spikes + crashes)
  })

  test('when no 1-in-20 roll hits, there are no price events and prices stay in the base range', () => {
    const state = Engine.newGame({ seed: 5 })
    state.rng = () => 0.999
    Engine.generatePrices(state)
    assert.deepEqual([...state.priceEvents], [])
    for (const [drugId, price] of Object.entries(state.prices)) {
      const drug = Engine.RULES.drugs.find((d) => d.id === drugId)
      assert.ok(price >= drug.min && price <= drug.max, drugId)
    }
  })

  test('a spike message is one of the two Beermat texts, drawn about 50/50', () => {
    const forced = Engine.newGame({ seed: 5 })
    forced.rng = scriptedRng(priceDraws(Engine.RULES.drugs, { spike: true }))
    Engine.generatePrices(forced)
    const forcedSpikes = forced.priceEvents.filter((e) => e.type === 'bust' || e.type === 'expensive')
    assert.ok(forcedSpikes.length > 0)
    for (const ev of forcedSpikes) {
      const name = Engine.RULES.drugs.find((d) => d.id === ev.drug).name
      assert.equal(ev.type, 'bust')
      assert.equal(ev.message, `Cops made a big ${name} bust!  Prices are outrageous!`)
    }

    const state = Engine.newGame({ seed: 77 })
    let busts = 0
    let addicts = 0
    for (let i = 0; i < 4000; i++) {
      Engine.generatePrices(state)
      for (const ev of state.priceEvents) {
        const name = Engine.RULES.drugs.find((d) => d.id === ev.drug).name
        if (ev.type === 'bust') {
          busts++
          assert.equal(ev.message, `Cops made a big ${name} bust!  Prices are outrageous!`)
        } else if (ev.type === 'expensive') {
          addicts++
          assert.equal(ev.message, `Addicts are buying ${name} at outrageous prices!`)
        }
      }
    }
    const share = busts / (busts + addicts)
    assert.ok(share > 0.4 && share < 0.6, `bust share ${share}`)
  })

  test('each crash drug has its own fixed message', () => {
    const expected = {
      acid: 'The market has been flooded with cheap home-made acid!',
      hashish: 'The Marrakesh Express has arrived!',
      ecstasy: 'Rival dealers raided a pharmacy and are selling cheap ecstasy!',
      weed: 'Columbian freighter dusted the Coast Guard!  Weed prices have bottomed out!',
    }
    const state = Engine.newGame({ seed: 31 })
    const seen = new Set()
    for (let i = 0; i < 4000; i++) {
      Engine.generatePrices(state)
      for (const ev of state.priceEvents.filter((e) => e.type === 'cheap')) {
        assert.equal(ev.message, expected[ev.drug], ev.drug)
        seen.add(ev.drug)
      }
    }
    assert.deepEqual([...seen].sort(), Object.keys(expected).sort())
  })

  test('each flagged, available drug spikes or crashes about 1 time in 20', () => {
    const state = Engine.newGame({ seed: 2024 })
    let opportunities = 0
    let hits = 0
    for (let i = 0; i < 4000; i++) {
      Engine.generatePrices(state)
      for (const drug of Engine.RULES.drugs) {
        if (drug.id in state.prices && (drug.cheap || drug.expensive)) opportunities++
      }
      hits += state.priceEvents.length
    }
    const rate = hits / opportunities
    assert.ok(rate > 0.04 && rate < 0.06, `event rate ${rate}`)
  })

  test('an unavailable drug is absent from prices and can be neither bought nor sold', () => {
    const state = Engine.newGame({ seed: 3 })
    state.rng = scriptedRng(priceDraws(Engine.RULES.drugs, { absent: new Set(['speed']) }))
    Engine.generatePrices(state)
    assert.equal('speed' in state.prices, false)
    state.inventory = { speed: { qty: 3, avgPrice: 100 } }
    assert.equal(Engine.buy(state, 'speed', 1).ok, false)
    const sold = Engine.sell(state, 'speed', 1)
    assert.equal(sold.ok, false)
    assert.equal(state.inventory.speed.qty, 3)
  })
})

describe('buy / sell', () => {
  test('buy deducts cash, adds inventory, and respects coat space', () => {
    const state = Engine.newGame({ seed: 1 })
    state.prices = { speed: 100 }
    state.coatCapacity = 5
    const res = Engine.buy(state, 'speed', 5)
    assert.equal(res.ok, true)
    assert.equal(state.cash, 2000 - 500)
    assert.equal(state.inventory.speed.qty, 5)
    const overflow = Engine.buy(state, 'speed', 1)
    assert.equal(overflow.ok, false)
  })

  // Beermat computes avg = (qty*price + held*avg) div (held + qty) in integers (docs/beermat-re.md M-12).
  test('buy truncates the weighted-average cost to an integer', () => {
    const state = Engine.newGame({ seed: 1 })
    state.prices = { speed: 100 }
    Engine.buy(state, 'speed', 3)
    assert.equal(state.inventory.speed.avgPrice, 100)
    state.prices = { speed: 101 }
    Engine.buy(state, 'speed', 2)
    // (3*100 + 2*101) / 5 = 100.4, truncated to 100.
    assert.equal(state.inventory.speed.avgPrice, 100)
  })

  test('buy refuses a drug not on offer here', () => {
    const state = Engine.newGame({ seed: 1 })
    state.prices = { speed: 100 }
    const res = Engine.buy(state, 'cocaine', 1)
    assert.equal(res.ok, false)
  })

  test('buy refuses when cash cannot cover even 1 unit', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 5
    state.prices = { cocaine: 15000 }
    const res = Engine.buy(state, 'cocaine', 1)
    assert.equal(res.ok, false)
    assert.match(res.reason, /check the price/i)
  })

  test('sell adds cash and removes inventory, refuses more than held', () => {
    const state = Engine.newGame({ seed: 1 })
    state.prices = { speed: 100 }
    Engine.buy(state, 'speed', 5)
    const res = Engine.sell(state, 'speed', 3)
    assert.equal(res.ok, true)
    assert.equal(state.inventory.speed.qty, 2)
    assert.equal(state.cash, 2000 - 500 + 300)
    const over = Engine.sell(state, 'speed', 3)
    assert.equal(over.ok, false)
  })

  test('sell refuses a drug not tradeable at the current location even if held', () => {
    const state = Engine.newGame({ seed: 1 })
    state.prices = { speed: 100 }
    Engine.buy(state, 'speed', 5)
    state.prices = { cocaine: 20000 }
    const res = Engine.sell(state, 'speed', 1)
    assert.equal(res.ok, false)
  })
})

describe('travel', () => {
  test('advances day, accrues 10% debt and 5% bank, regenerates prices', () => {
    const state = Engine.newGame({ seed: 1 })
    state.bank = 1000
    const before = state.day
    const res = Engine.travel(state, 'ghetto')
    assert.equal(res.ok, true)
    assert.equal(state.day, before + 1)
    assert.equal(state.location, 'ghetto')
    assert.equal(state.debt, 6050)
    assert.equal(state.bank, 1050)
    assert.ok(Object.keys(state.prices).length > 0)
  })

  // Beermat computes the product in x87 extended precision and rounds with FISTP (ties to even, docs/beermat-re.md M-10).
  test('debt interest rounds ties to even: 6655 becomes 7320, not 7321', () => {
    const state = Engine.newGame({ seed: 1 })
    state.debt = 6655
    Engine.travel(state, 'ghetto')
    assert.equal(state.debt, 7320)
  })

  test('debt interest rounds an odd-floor tie up to the even neighbour', () => {
    const state = Engine.newGame({ seed: 1 })
    state.debt = 5
    Engine.travel(state, 'ghetto')
    assert.equal(state.debt, 6, '5 * 1.1 = 5.5 -> 6')
    state.debt = 15
    Engine.travel(state, 'bronx')
    assert.equal(state.debt, 16, '15 * 1.1 = 16.5 -> 16')
  })

  test('bank interest is a whole dollar amount rounded to nearest', () => {
    const state = Engine.newGame({ seed: 1 })
    state.bank = 5500
    Engine.travel(state, 'ghetto')
    assert.equal(state.bank, 5775)
    state.bank = 1001
    Engine.travel(state, 'bronx')
    assert.equal(state.bank, 1051, '1001 * 1.05 = 1051.05')
  })

  // The binary's extended 1.05 sits just below 1.05, so a product that lands exactly on .5 can fall below it and round down.
  test('bank interest matches the extended-precision product on .5 ties', () => {
    const cases = [[10, 10], [30, 31], [110, 115], [50, 52], [70, 74], [90, 94]]
    for (const [bank, expected] of cases) {
      const state = Engine.newGame({ seed: 1 })
      state.bank = bank
      Engine.travel(state, 'ghetto')
      assert.equal(state.bank, expected, `${bank} * 1.05`)
    }
  })

  test('interest is skipped when the balance is 0 or negative', () => {
    const state = Engine.newGame({ seed: 1 })
    state.debt = 0
    state.bank = 0
    Engine.travel(state, 'ghetto')
    assert.equal(state.debt, 0)
    assert.equal(state.bank, 0)
    state.debt = -100
    state.bank = -100
    Engine.travel(state, 'bronx')
    assert.equal(state.debt, -100)
    assert.equal(state.bank, -100)
  })

  test('cannot travel to the current location', () => {
    const state = Engine.newGame({ seed: 1 })
    const res = Engine.travel(state, state.location)
    assert.equal(res.ok, false)
  })

  test('cannot travel past the final day', () => {
    const state = Engine.newGame({ seed: 1, numDays: 2 })
    state.day = 2
    const res = Engine.travel(state, 'ghetto')
    assert.equal(res.ok, false)
  })

  test('cannot travel when dead', () => {
    const state = Engine.newGame({ seed: 1 })
    state.dead = true
    const res = Engine.travel(state, 'ghetto')
    assert.equal(res.ok, false)
    assert.match(res.reason, /dead/i)
  })
})

describe('finances', () => {
  test('deposit moves cash to bank, clamped to available cash', () => {
    const state = Engine.newGame({ seed: 1 })
    const res = Engine.finances(state, 'deposit', 999999)
    assert.equal(res.ok, true)
    assert.equal(state.cash, 0)
    assert.equal(state.bank, 2000)
  })

  test('withdraw moves bank to cash, clamped to available bank', () => {
    const state = Engine.newGame({ seed: 1 })
    state.bank = 500
    const res = Engine.finances(state, 'withdraw', 999999)
    assert.equal(res.ok, true)
    assert.equal(state.bank, 0)
    assert.equal(state.cash, 2500)
  })

  test('payLoan reduces debt, clamped to min(cash, debt)', () => {
    const state = Engine.newGame({ seed: 1 })
    const res = Engine.finances(state, 'payLoan', 999999)
    assert.equal(res.ok, true)
    assert.equal(state.debt, 5500 - 2000)
    assert.equal(state.cash, 0)
  })

  test('paying full debt after interest accrues zeroes it out', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 999999
    // Travel several times to compound interest
    Engine.travel(state, 'ghetto')
    Engine.travel(state, 'bronx')
    Engine.travel(state, 'central_park')
    // Debt should be an integer (no floating-point remainder)
    assert.equal(state.debt, Math.round(state.debt), 'debt must be an integer after interest')
    // Paying the exact debt should zero it out
    const debtBefore = state.debt
    Engine.finances(state, 'payLoan', debtBefore)
    assert.equal(state.debt, 0, 'debt must be zero after full payoff')
  })

  test('never drives cash, bank, or debt negative', () => {
    const state = Engine.newGame({ seed: 1 })
    Engine.finances(state, 'deposit', 50)
    Engine.finances(state, 'withdraw', 9999)
    assert.ok(state.cash >= 0)
    assert.ok(state.bank >= 0)
    const state2 = Engine.newGame({ seed: 1 })
    state2.debt = 100
    Engine.finances(state2, 'payLoan', 9999)
    assert.ok(state2.debt >= 0)
  })
})

// Random(n) == k as a scripted draw: randInt(rng, 0, n - 1) floors draw * n.
const rnd = (k, n) => (k + 0.5) / n

function eventState(prevPrices, inventory = {}) {
  const state = Engine.newGame({ seed: 1 })
  state.prevPrices = prevPrices
  state.prices = {}
  for (const [id, qty] of Object.entries(inventory)) state.inventory[id] = { qty, avgPrice: 0 }
  return state
}

describe('arrival events', () => {
  test('the event fires on Random(14) == 0 only, one draw on a miss', () => {
    const state = eventState({ acid: 1000 })
    const rng = scriptedRng([rnd(1, 14)])
    assert.equal(Engine.rollArrivalEvent(state, rng).type, 'none')
    assert.equal(rng.drawn(), 1)
  })

  test('cash + bank above 99,999,999 forces the mugging with no event or outcome draw', () => {
    const state = eventState({ acid: 1000 })
    state.cash = 60000000
    state.bank = 40000000
    const rng = scriptedRng([rnd(0, 2)])
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.equal(ev.type, 'mugged')
    assert.equal(rng.drawn(), 1)
    assert.equal(state.cash, 60000000 - 20000000)
    assert.equal(ev.amount, 20000000)
  })

  test('cash + bank of exactly 99,999,999 is not forced', () => {
    const state = eventState({ acid: 1000 })
    state.cash = 99999999
    const rng = scriptedRng([rnd(5, 14)])
    assert.equal(Engine.rollArrivalEvent(state, rng).type, 'none')
    assert.equal(rng.drawn(), 1)
  })

  test('outcome 1 mugs for cash div (Random(2) + 3) and names the location', () => {
    for (const [pick, kept] of [[0, 667], [1, 750]]) {
      const state = eventState({ acid: 1000 })
      state.cash = 1000
      state.location = 'brooklyn'
      const rng = scriptedRng([rnd(0, 14), rnd(1, 4), rnd(pick, 2)])
      const ev = Engine.rollArrivalEvent(state, rng)
      assert.equal(ev.type, 'mugged')
      assert.equal(state.cash, kept)
      assert.equal(ev.amount, 1000 - kept)
      assert.equal(ev.message, 'You were mugged on the Brooklyn!')
      assert.equal(rng.drawn(), 3)
    }
  })

  test('mugging with no cash takes nothing and leaves health alone', () => {
    const state = eventState({ acid: 1000 })
    state.cash = 0
    const ev = Engine.rollArrivalEvent(state, scriptedRng([rnd(0, 14), rnd(1, 4), rnd(0, 2)]))
    assert.equal(ev.type, 'mugged')
    assert.equal(state.cash, 0)
    assert.equal(state.health, 100)
  })

  test('outcome 0 redraws Random(11) until the drug is available, then Random(7) + 2 units', () => {
    // Beermat order: 2 is hashish (absent), 1 is cocaine (available).
    const state = eventState({ cocaine: 20000, acid: 1000 }, { cocaine: 10 })
    state.inventory.cocaine.avgPrice = 100
    state.location = 'centralpark'
    const rng = scriptedRng([rnd(0, 14), rnd(0, 4), rnd(2, 11), rnd(1, 11), rnd(3, 7)])
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.equal(ev.type, 'foundDrugs')
    assert.equal(ev.drug, 'cocaine')
    assert.equal(ev.qty, 5)
    assert.equal(state.inventory.cocaine.qty, 15)
    assert.equal(state.inventory.cocaine.avgPrice, 66)
    assert.equal(ev.message, 'You find 5 units of Cocaine on a dead dude in the Central Park!')
    assert.equal(rng.drawn(), 5)
  })

  test('found quantity is capped at the free coat space', () => {
    const state = eventState({ acid: 1000 }, { crack: 97 })
    const ev = Engine.rollArrivalEvent(state, scriptedRng([rnd(0, 14), rnd(0, 4), rnd(0, 11), rnd(6, 7)]))
    assert.equal(ev.qty, 3)
    assert.equal(state.inventory.acid.qty, 3)
  })

  test('a full coat skips outcomes 0 and 2 before any drug draw', () => {
    for (const outcome of [0, 2]) {
      const state = eventState({ acid: 1000 }, { crack: 100 })
      const rng = scriptedRng([rnd(0, 14), rnd(outcome, 4)])
      assert.equal(Engine.rollArrivalEvent(state, rng).type, 'none')
      assert.equal(rng.drawn(), 2)
    }
  })

  test('the last drug in Beermat order (weed) is never picked and an empty pool draws nothing', () => {
    const state = eventState({ weed: 500 })
    const rng = scriptedRng([rnd(0, 14), rnd(0, 4)])
    assert.equal(Engine.rollArrivalEvent(state, rng).type, 'none')
    assert.equal(rng.drawn(), 2)
    const empty = eventState({})
    const rng2 = scriptedRng([rnd(0, 14), rnd(2, 4)])
    assert.equal(Engine.rollArrivalEvent(empty, rng2).type, 'none')
    assert.equal(rng2.drawn(), 2)
  })

  test('the drug comes from the market the player left, not the one just rolled', () => {
    const state = eventState({ acid: 1000 })
    state.prices = { cocaine: 20000 }
    const ev = Engine.rollArrivalEvent(state, scriptedRng([rnd(0, 14), rnd(0, 4), rnd(0, 11), rnd(0, 7)]))
    assert.equal(ev.drug, 'acid')
  })

  test('a drug held at zero average stays at zero average when more arrives', () => {
    const state = eventState({ acid: 1000 })
    Engine.rollArrivalEvent(state, scriptedRng([rnd(0, 14), rnd(0, 4), rnd(0, 11), rnd(0, 7)]))
    assert.equal(state.inventory.acid.qty, 2)
    assert.equal(state.inventory.acid.avgPrice, 0)
  })

  test('outcome 2 gives units under the same rules and omits the quantity from the text', () => {
    const state = eventState({ speed: 100, acid: 1000 }, { speed: 4 })
    state.inventory.speed.avgPrice = 90
    const ev = Engine.rollArrivalEvent(state, scriptedRng([rnd(0, 14), rnd(2, 4), rnd(10, 11), rnd(4, 7)]))
    assert.equal(ev.type, 'freeDrugs')
    assert.equal(ev.drug, 'speed')
    assert.equal(ev.qty, 6)
    assert.equal(state.inventory.speed.qty, 10)
    assert.equal(state.inventory.speed.avgPrice, 36)
    assert.equal(ev.message, 'You meet a friend! He lays some Speed on you!')
  })

  test('outcome 3 with an empty coat only chases for Random(4) + 2 blocks', () => {
    const state = eventState({ acid: 1000 })
    const rng = scriptedRng([rnd(0, 14), rnd(3, 4), rnd(2, 4)])
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.equal(ev.type, 'dogChase')
    assert.equal(ev.blocks, 4)
    assert.equal(ev.qty, 0)
    assert.equal(ev.message, 'Police dogs chased you for 4 blocks.')
    assert.equal(rng.drawn(), 3)
  })

  test('outcome 3 with drugs held drops min(Random(held) + 1, 10) of a random held drug', () => {
    // Random(12) picks Beermat index 1 (cocaine, not held) then 3 (heroin); Random(4) = 2 drops.
    const state = eventState({ acid: 1000 }, { acid: 5, heroin: 30 })
    const rng = scriptedRng([rnd(0, 14), rnd(3, 4), rnd(1, 12), rnd(3, 12), rnd(2, 4), rnd(14, 30), rnd(0, 4)])
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.equal(ev.type, 'dogChase')
    assert.equal(ev.drug, 'heroin')
    assert.equal(ev.qty, 10)
    assert.equal(ev.blocks, 2)
    assert.equal(state.inventory.heroin.qty, 20)
    assert.equal(ev.message, 'Police dogs chased you for 2 blocks. You dropped some drugs! That\'s a drag, man!')
    assert.equal(rng.drawn(), 7)
  })

  test('outcome 3 drops fewer than 10 when Random(held) + 1 is smaller, and removes the entry at zero', () => {
    const state = eventState({ acid: 1000 }, { acid: 3 })
    const ev = Engine.rollArrivalEvent(state, scriptedRng([rnd(0, 14), rnd(3, 4), rnd(0, 12), rnd(3, 4), rnd(2, 3), rnd(1, 4)]))
    assert.equal(ev.qty, 3)
    assert.equal(state.inventory.acid, undefined)
  })

  test('outcome 3 keeps the drugs on a Random(4) below 2 and draws no drop quantity', () => {
    const state = eventState({ acid: 1000 }, { acid: 5 })
    const rng = scriptedRng([rnd(0, 14), rnd(3, 4), rnd(0, 12), rnd(1, 4), rnd(1, 4)])
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.equal(ev.qty, 0)
    assert.equal(ev.blocks, 3)
    assert.equal(state.inventory.acid.qty, 5)
    assert.equal(ev.message, 'Police dogs chased you for 3 blocks.')
    assert.equal(rng.drawn(), 5)
  })

  test('only the four Beermat outcomes ever happen and none of them kills', () => {
    const seen = new Set()
    const rng = Engine.mulberry32(99)
    for (let i = 0; i < 4000; i++) {
      const state = eventState({ acid: 1000, crack: 2000 }, { acid: 5 })
      state.cash = 1000
      const ev = Engine.rollArrivalEvent(state, Engine.mulberry32(Math.floor(rng() * 2 ** 31)))
      seen.add(ev.type)
      assert.equal(state.dead, false)
    }
    assert.deepEqual([...seen].sort(), ['dogChase', 'foundDrugs', 'freeDrugs', 'mugged', 'none'])
  })
})

describe('combat', () => {
  test('fight is unavailable with 0 guns', () => {
    const state = Engine.newGame({ seed: 1 })
    const chase = Engine.startChase(state, Engine.mulberry32(1))
    assert.equal(chase.canFight, false)
  })

  test('fight is available once a gun is owned', () => {
    const state = Engine.newGame({ seed: 1 })
    state.guns = 1
    const chase = Engine.startChase(state, Engine.mulberry32(1))
    assert.equal(chase.canFight, true)
  })

  test('Run escapes on Random(6) < 3 with no further draw, regardless of guns', () => {
    for (const guns of [0, 4]) {
      for (const k of [0, 1, 2]) {
        const state = Engine.newGame({ seed: 1 })
        state.guns = guns
        const rng = scriptedRng([rnd(k, 6)])
        const res = Engine.runFromChase(state, { deputies: 3 }, rng)
        assert.equal(res.escaped, true)
        assert.equal(state.health, 100)
        assert.equal(rng.drawn(), 1)
      }
    }
  })

  test('a failed Run draws Random(2) and the cops miss on 0', () => {
    for (const k of [3, 4, 5]) {
      const state = Engine.newGame({ seed: 1 })
      const rng = scriptedRng([rnd(k, 6), rnd(0, 2)])
      const res = Engine.runFromChase(state, { deputies: 3 }, rng)
      assert.deepEqual({ ...res }, { escaped: false, hit: false, damage: 0, dead: false })
      assert.equal(state.health, 100)
      assert.equal(rng.drawn(), 2)
    }
  })

  test('a failed Run that gets shot takes Random(11) + 5 damage', () => {
    const lo = Engine.newGame({ seed: 1 })
    const resLo = Engine.runFromChase(lo, { deputies: 3 }, scriptedRng([rnd(3, 6), rnd(1, 2), rnd(0, 11)]))
    assert.deepEqual({ ...resLo }, { escaped: false, hit: true, damage: 5, dead: false })
    assert.equal(lo.health, 95)
    const hi = Engine.newGame({ seed: 1 })
    const rng = scriptedRng([rnd(5, 6), rnd(1, 2), rnd(10, 11)])
    const resHi = Engine.runFromChase(hi, { deputies: 3 }, rng)
    assert.equal(resHi.damage, 15)
    assert.equal(hi.health, 85)
    assert.equal(rng.drawn(), 3)
  })

  test('cop damage floors health at 0 and kills', () => {
    const state = Engine.newGame({ seed: 1 })
    state.health = 7
    const res = Engine.runFromChase(state, { deputies: 3 }, scriptedRng([rnd(4, 6), rnd(1, 2), rnd(10, 11)]))
    assert.equal(state.health, 0)
    assert.equal(res.dead, true)
    assert.equal(state.dead, true)
  })

  test('Stay makes the cops fire: Random(2), then Random(11) + 5 on a hit', () => {
    const miss = Engine.newGame({ seed: 1 })
    const rngMiss = scriptedRng([rnd(0, 2)])
    assert.deepEqual({ ...Engine.stayInChase(miss, rngMiss) }, { hit: false, damage: 0, dead: false })
    assert.equal(miss.health, 100)
    assert.equal(rngMiss.drawn(), 1)
    const hit = Engine.newGame({ seed: 1 })
    const rngHit = scriptedRng([rnd(1, 2), rnd(4, 11)])
    assert.deepEqual({ ...Engine.stayInChase(hit, rngHit) }, { hit: true, damage: 9, dead: false })
    assert.equal(hit.health, 91)
    assert.equal(rngHit.drawn(), 2)
  })

  test('Stay can kill', () => {
    const state = Engine.newGame({ seed: 1 })
    state.health = 5
    const res = Engine.stayInChase(state, scriptedRng([rnd(1, 2), rnd(0, 11)]))
    assert.equal(res.dead, true)
    assert.equal(state.health, 0)
  })

  test('Fight needs a gun and draws nothing without one', () => {
    const state = Engine.newGame({ seed: 1 })
    const rng = scriptedRng([])
    assert.equal(Engine.fight(state, { deputies: 3 }, rng).ok, false)
  })

  test('a Fight shot that misses draws Random(2) = 0 and the cops return fire', () => {
    const state = Engine.newGame({ seed: 1 })
    state.guns = 1
    const chase = { deputies: 3 }
    const rng = scriptedRng([rnd(0, 2), rnd(0, 2)])
    const res = Engine.fight(state, chase, rng)
    assert.equal(res.ok, true)
    assert.equal(res.killed, false)
    assert.equal(res.copHit, false)
    assert.equal(res.won, false)
    assert.equal(chase.deputies, 3)
    assert.equal(rng.drawn(), 2)
  })

  test('a Fight shot that kills drops one deputy, then the cops return fire for 5-15', () => {
    const state = Engine.newGame({ seed: 1 })
    state.guns = 1
    const chase = { deputies: 3 }
    const rng = scriptedRng([rnd(1, 2), rnd(1, 2), rnd(2, 11)])
    const res = Engine.fight(state, chase, rng)
    assert.equal(res.killed, true)
    assert.equal(res.copHit, true)
    assert.equal(res.damage, 7)
    assert.equal(chase.deputies, 2)
    assert.equal(state.health, 93)
    assert.equal(rng.drawn(), 3)
  })

  test('Fight return fire can kill the player', () => {
    const state = Engine.newGame({ seed: 1 })
    state.guns = 1
    state.health = 6
    const res = Engine.fight(state, { deputies: 3 }, scriptedRng([rnd(0, 2), rnd(1, 2), rnd(10, 11)]))
    assert.equal(res.dead, true)
    assert.equal(state.health, 0)
  })

  test('the chase is won when the count goes below 0, so deputies + 1 kills are needed', () => {
    const state = Engine.newGame({ seed: 1 })
    state.guns = 1
    const chase = { deputies: 1 }
    const first = Engine.fight(state, chase, scriptedRng([rnd(1, 2), rnd(0, 2)]))
    assert.equal(first.won, false)
    assert.equal(chase.deputies, 0)
    const second = Engine.fight(state, chase, scriptedRng([rnd(1, 2), rnd(500, 1000), rnd(0, 1500)]))
    assert.equal(second.won, true)
    assert.equal(chase.deputies, -1)
  })

  test('a win draws no return fire, pays +1 gun and (Random(1000)+1000) + Random(1500) cash', () => {
    const state = Engine.newGame({ seed: 1 })
    state.guns = 2
    state.cash = 100
    const rng = scriptedRng([rnd(1, 2), rnd(5, 1000), rnd(700, 1500)])
    const res = Engine.fight(state, { deputies: 0 }, rng)
    assert.equal(res.won, true)
    assert.equal(res.copHit, false)
    assert.equal(res.damage, 0)
    assert.equal(res.reward, 1005 + 700)
    assert.deepEqual({ ...res.doctor }, { price: 1005 })
    assert.equal(state.guns, 3)
    assert.equal(state.cash, 100 + 1005 + 700)
    assert.equal(rng.drawn(), 3)
  })

  test('the win reward ranges from 1000 to 3499 and the doctor price from 1000 to 1999', () => {
    const lo = Engine.newGame({ seed: 1 })
    lo.guns = 1
    const resLo = Engine.fight(lo, { deputies: 0 }, scriptedRng([rnd(1, 2), rnd(0, 1000), rnd(0, 1500)]))
    assert.equal(resLo.reward, 1000)
    assert.equal(resLo.doctor.price, 1000)
    const hi = Engine.newGame({ seed: 1 })
    hi.guns = 1
    const resHi = Engine.fight(hi, { deputies: 0 }, scriptedRng([rnd(1, 2), rnd(999, 1000), rnd(1499, 1500)]))
    assert.equal(resHi.reward, 3498)
    assert.equal(resHi.doctor.price, 1999)
  })

  test('the doctor sets health to 100 and charges the price from cash', () => {
    const state = Engine.newGame({ seed: 1 })
    state.health = 12
    state.cash = 5000
    assert.deepEqual({ ...Engine.acceptDoctorOffer(state, { price: 1500 }) }, { ok: true })
    assert.equal(state.health, 100)
    assert.equal(state.cash, 3500)
  })

  test('the doctor refuses when the price exceeds cash and changes nothing', () => {
    const state = Engine.newGame({ seed: 1 })
    state.health = 12
    state.cash = 100
    assert.equal(Engine.acceptDoctorOffer(state, { price: 1500 }).ok, false)
    assert.equal(state.health, 12)
    assert.equal(state.cash, 100)
  })

  test('the attack/defend rating model and the aggressor flag are gone', () => {
    assert.equal(Engine.getFightRatings, undefined)
    assert.equal('gunDamage' in Engine.RULES, false)
    assert.equal('playerArmor' in Engine.RULES, false)
    assert.equal(Engine.runFromChase.length, 3)
  })

  test('health reaching 0 marks the player dead', () => {
    const state = Engine.newGame({ seed: 1 })
    state.health = 1
    Engine.applyDamage(state, 50)
    assert.equal(state.health, 0)
    assert.equal(state.dead, true)
  })
})

describe('finish', () => {
  test('score is cash + bank - debt', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 1000
    state.bank = 500
    state.debt = 200
    const result = Engine.finish(state)
    assert.equal(result.score, 1300)
    assert.equal(result.dead, false)
  })

  test('dead players still score, flagged as dead', () => {
    const state = Engine.newGame({ seed: 1 })
    state.dead = true
    state.cash = 10
    const result = Engine.finish(state)
    assert.equal(result.dead, true)
  })

  test('insertHighScore keeps the top 10 sorted descending', () => {
    const scores = []
    for (let i = 0; i < 12; i++) {
      Engine.insertHighScore(scores, { name: `p${i}`, score: i * 100, day: 31, dead: false, date: '2026-01-01' })
    }
    assert.equal(scores.length, 10)
    assert.equal(scores[0].score, 1100)
    assert.equal(scores[9].score, 200)
  })
})

describe('dealers (Beermat: one 1-in-14 visit, coat or gun, cash only)', () => {
  const scripted = (...floats) => {
    let i = 0
    const rng = () => floats[i++]
    rng.drawn = () => i
    return rng
  }

  test('rollDealerVisit draws one value and reports none unless Random(14) is 0', () => {
    const state = Engine.newGame({ seed: 1 })
    const rng = scripted(0.5)
    assert.equal(Engine.rollDealerVisit(state, rng).kind, 'none')
    assert.equal(rng.drawn(), 1)
  })

  test('rollDealerVisit hits at the first fourteenth and not past it', () => {
    const state = Engine.newGame({ seed: 1 })
    assert.equal(Engine.rollDealerVisit(state, scripted(0.0714, 0)).kind, 'coat')
    assert.equal(Engine.rollDealerVisit(state, scripted(0.0715)).kind, 'none')
  })

  test('rollDealerVisit splits Random(4): 0 and 2 coat, 1 and 3 gun', () => {
    const state = Engine.newGame({ seed: 1 })
    const kinds = [0, 0.25, 0.5, 0.75].map((r) => Engine.rollDealerVisit(state, scripted(0, r)).kind)
    assert.deepEqual([...kinds], ['coat', 'gun', 'coat', 'gun'])
  })

  test('rollDealerVisit draws two values on a visit', () => {
    const state = Engine.newGame({ seed: 1 })
    const rng = scripted(0, 0.3)
    Engine.rollDealerVisit(state, rng)
    assert.equal(rng.drawn(), 2)
  })

  test('rollCoatDealerOffer prices 201-350 with one draw', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 10000
    const low = scripted(0)
    assert.equal(Engine.rollCoatDealerOffer(state, low).price, 201)
    assert.equal(low.drawn(), 1)
    assert.equal(Engine.rollCoatDealerOffer(state, scripted(0.999999)).price, 350)
  })

  test('rollCoatDealerOffer is offered only when price is strictly below cash', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 201
    assert.equal(Engine.rollCoatDealerOffer(state, scripted(0)).offered, false)
    state.cash = 202
    assert.equal(Engine.rollCoatDealerOffer(state, scripted(0)).offered, true)
  })

  test('acceptCoatOffer pays cash and adds Random(10)+11 pockets', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 500
    const rng = scripted(0.5)
    const res = Engine.acceptCoatOffer(state, { price: 300 }, rng)
    assert.equal(res.ok, true)
    assert.equal(res.pockets, 16)
    assert.equal(state.cash, 200)
    assert.equal(state.coatCapacity, 116)
    assert.equal(rng.drawn(), 1)
  })

  test('acceptCoatOffer pocket range is 11-20', () => {
    const lo = Engine.newGame({ seed: 1 })
    lo.cash = 500
    Engine.acceptCoatOffer(lo, { price: 300 }, scripted(0))
    assert.equal(lo.coatCapacity, 111)
    const hi = Engine.newGame({ seed: 1 })
    hi.cash = 500
    Engine.acceptCoatOffer(hi, { price: 300 }, scripted(0.999999))
    assert.equal(hi.coatCapacity, 120)
  })

  test('acceptCoatOffer never touches the bank and draws nothing when cash is short', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 0
    state.bank = 100000
    const rng = scripted()
    const res = Engine.acceptCoatOffer(state, { price: 300 }, rng)
    assert.equal(res.ok, false)
    assert.equal(state.bank, 100000)
    assert.equal(state.coatCapacity, 100)
    assert.equal(rng.drawn(), 0)
  })

  test('rollGunDealerOffer prices 301-550', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 10000
    assert.equal(Engine.rollGunDealerOffer(state, scripted(0, 0)).price, 301)
    assert.equal(Engine.rollGunDealerOffer(state, scripted(0.999999, 0)).price, 550)
  })

  test('rollGunDealerOffer draws the name only when the offer is made', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 301
    const unaffordable = scripted(0)
    const none = Engine.rollGunDealerOffer(state, unaffordable)
    assert.equal(none.offered, false)
    assert.equal(unaffordable.drawn(), 1)
    state.cash = 302
    const affordable = scripted(0, 0.99)
    const made = Engine.rollGunDealerOffer(state, affordable)
    assert.equal(made.offered, true)
    assert.equal(made.nameIndex, 3)
    assert.equal(affordable.drawn(), 2)
  })

  test('gun names are the four Beermat names in order', () => {
    assert.deepEqual([...Engine.RULES.gunNames], ['Baretta', '.38 Special', 'Ruger', 'Saturday Night Special'])
  })

  test('acceptGunOffer pays cash, adds a gun and uses no coat space', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 500
    const usedBefore = Engine.coatUsed(state)
    const res = Engine.acceptGunOffer(state, { price: 300, nameIndex: 0 })
    assert.equal(res.ok, true)
    assert.equal(state.cash, 200)
    assert.equal(state.guns, 1)
    assert.equal(Engine.coatUsed(state), usedBefore)
  })

  test('acceptGunOffer succeeds with a full coat', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 500
    state.inventory.weed = { qty: state.coatCapacity, avgPrice: 0 }
    assert.equal(Engine.acceptGunOffer(state, { price: 300, nameIndex: 0 }).ok, true)
    assert.equal(state.guns, 1)
  })

  test('acceptGunOffer never touches the bank', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 0
    state.bank = 100000
    const res = Engine.acceptGunOffer(state, { price: 300, nameIndex: 0 })
    assert.equal(res.ok, false)
    assert.equal(state.bank, 100000)
    assert.equal(state.guns, 0)
  })

  test('the bank purchase fee and gun space rules are gone', () => {
    assert.equal(Engine.RULES.bankPurchaseFee, undefined)
    assert.equal(Engine.RULES.gunSpace, undefined)
  })
})

// Golden-fixture replay: every .jsonl under tests/fixtures/ must round-trip
// through the engine with byte-identical return values and state snapshots.
// See tests/fixtures/README.md for the format and generator workflow.
describe('fixture corpus', () => {
  const runStep = makeRunStep(Engine)
  const fixturesDir = path.join(__dirname, 'fixtures')
  const files = readdirSync(fixturesDir).filter((f) => f.endsWith('.jsonl')).sort()
  assert.ok(files.length > 0, 'no fixtures found under tests/fixtures/')

  for (const file of files) {
    test(`replay ${file}`, () => {
      const raw = readFileSync(path.join(fixturesDir, file), 'utf8').trim()
      const lines = raw.split('\n').filter((l) => l.length > 0)
      let state = null
      for (const line of lines) {
        const record = JSON.parse(line)
        const step = { call: record.call, args: record.args, rng: record.rng }
        const ret = runStep(state, step)
        if (record.call === 'newGame') state = ret
        const actualReturn = JSON.parse(JSON.stringify(ret))
        assert.deepEqual(actualReturn, record.expect.return, `${file} step ${record.step} ${record.call} return`)
        const actualState = state ? snapshotState(state) : null
        assert.deepEqual(actualState, record.expect.state, `${file} step ${record.step} ${record.call} state`)
      }
    })
  }
})
