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
    assert.equal(state.bank, 1000 * 1.05)
    assert.ok(Object.keys(state.prices).length > 0)
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

describe('arrival events', () => {
  test('mugging (roll < 10) takes 5-20% of cash', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 1000
    const rng = () => 0.05
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.equal(ev.type, 'mugged')
    assert.ok(state.cash >= 800 && state.cash <= 950)
  })

  test('mugging with $0 subtracts 5% of health instead', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 0
    const healthBefore = state.health
    const rng = () => 0.05
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.equal(ev.type, 'mugged')
    assert.equal(state.cash, 0)
    assert.equal(state.health, Math.floor(healthBefore * 0.95))
  })

  test('free drugs (roll 10-29) adds inventory at $0 cost if coat space allows', () => {
    const state = Engine.newGame({ seed: 1 })
    state.prices = { speed: 100 }
    const cashBefore = state.cash
    const rng = () => 0.15
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.equal(ev.type, 'freeDrugs')
    assert.equal(state.cash, cashBefore)
    assert.ok(state.inventory[ev.drug].qty > 0)
  })

  test('free drugs (roll 10-29) returns none when coat is full', () => {
    const state = Engine.newGame({ seed: 1 })
    state.prices = { speed: 100 }
    // fill the coat completely
    const drugId = Object.keys(state.prices)[0]
    state.inventory[drugId] = { qty: state.coatCapacity, avgPrice: 0 }
    const rng = () => 0.15
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.equal(ev.type, 'none')
  })

  test('instant death event (roll 60-60.5) kills the player', () => {
    const state = Engine.newGame({ seed: 1 })
    const rng = () => 0.602
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.equal(ev.type, 'freeWeedDeath')
    assert.equal(state.health, 0)
    assert.equal(state.dead, true)
  })

  test('no-op roll (>=65, below dealer/chase thresholds) returns a flavor event', () => {
    const state = Engine.newGame({ seed: 1 })
    const rng = () => 0.99
    const ev = Engine.rollArrivalEvent(state, rng)
    assert.ok(['flavor', 'none'].includes(ev.type))
  })
})

describe('combat', () => {
  test('ratings floor at 10 and scale with guns/armor per gameplay.md', () => {
    const state = Engine.newGame({ seed: 1 })
    const ratings = Engine.getFightRatings(state)
    assert.ok(ratings.attack >= 10)
    assert.ok(ratings.defend >= 10)
  })

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

  test('running has a base 60% escape chance, 30% if the player is the aggressor', () => {
    const state = Engine.newGame({ seed: 1 })
    const chase = Engine.startChase(state, Engine.mulberry32(1))
    const rngEscape = () => 0.5
    const rngFail = () => 0.9
    assert.equal(Engine.runFromChase(state, chase, false, rngEscape).escaped, true)
    assert.equal(Engine.runFromChase(state, chase, false, rngFail).escaped, false)
    assert.equal(Engine.runFromChase(state, chase, true, rngEscape).escaped, false)
  })

  test('health reaching 0 marks the player dead', () => {
    const state = Engine.newGame({ seed: 1 })
    state.health = 1
    Engine.applyDamage(state, 50)
    assert.equal(state.health, 0)
    assert.equal(state.dead, true)
  })

  test('fight hit kills a deputy and does not damage the player', () => {
    const state = Engine.newGame({ seed: 1 })
    state.guns = 1
    const chase = Engine.startChase(state, Engine.mulberry32(1))
    const deputiesBefore = chase.deputies
    const healthBefore = state.health
    // high first call → big attackRoll; low second call → small defendRoll → guaranteed hit
    let calls = 0
    const rng = () => calls++ === 0 ? 0.99 : 0.01
    const res = Engine.fight(state, chase, rng)
    assert.equal(res.hit, true)
    assert.equal(chase.deputies, deputiesBefore - 1)
    assert.equal(state.health, healthBefore)
  })

  test('fight miss damages the player and does not kill a deputy', () => {
    const state = Engine.newGame({ seed: 1 })
    state.guns = 1
    const chase = Engine.startChase(state, Engine.mulberry32(1))
    const deputiesBefore = chase.deputies
    const healthBefore = state.health
    // low first call → small attackRoll; high second call → big defendRoll → guaranteed miss
    let calls = 0
    const rng = () => calls++ === 0 ? 0.01 : 0.99
    const res = Engine.fight(state, chase, rng)
    assert.equal(res.hit, false)
    assert.equal(chase.deputies, deputiesBefore)
    assert.ok(state.health < healthBefore)
  })

  test('fight returns won when last deputy is killed', () => {
    const state = Engine.newGame({ seed: 1 })
    state.guns = 1
    const chase = Engine.startChase(state, Engine.mulberry32(1))
    chase.deputies = 1
    let calls = 0
    const rng = () => calls++ === 0 ? 0.99 : 0.01
    const res = Engine.fight(state, chase, rng)
    assert.equal(res.won, true)
    assert.equal(chase.deputies, 0)
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

describe('bank-purchase fee (coat and gun dealers)', () => {
  // Coat dealer
  test('acceptCoatOffer pays from cash when sufficient', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 500
    const offer = { pockets: 10, price: 300 }
    const res = Engine.acceptCoatOffer(state, offer)
    assert.equal(res.ok, true)
    assert.equal(res.usedBank, false)
    assert.equal(state.cash, 200)
    assert.equal(state.coatCapacity, 110)
  })

  test('acceptCoatOffer uses bank with 25% fee when cash is short but bank is sufficient', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 0
    state.bank = 1000
    const offer = { pockets: 10, price: 400 }
    const totalExpected = Math.ceil(400 * 1.25) // 500
    const res = Engine.acceptCoatOffer(state, offer)
    assert.equal(res.ok, true)
    assert.equal(res.usedBank, true)
    assert.equal(res.fee, Math.ceil(400 * Engine.RULES.bankPurchaseFee))
    assert.equal(state.bank, 1000 - totalExpected)
    assert.equal(state.cash, 0) // cash untouched
    assert.equal(state.coatCapacity, 110)
  })

  test('acceptCoatOffer fails when both cash and bank are insufficient', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 0
    state.bank = 100
    const offer = { pockets: 10, price: 400 }
    const res = Engine.acceptCoatOffer(state, offer)
    assert.equal(res.ok, false)
    assert.equal(state.coatCapacity, 100)
  })

  // Gun dealer
  test('acceptGunOffer pays from cash when sufficient', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 500
    const offer = { price: 300, damage: 5, space: 4 }
    const res = Engine.acceptGunOffer(state, offer)
    assert.equal(res.ok, true)
    assert.equal(res.usedBank, false)
    assert.equal(state.cash, 200)
    assert.equal(state.guns, 1)
  })

  test('acceptGunOffer uses bank with 25% fee when cash is short but bank is sufficient', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 0
    state.bank = 1000
    const offer = { price: 400, damage: 5, space: 4 }
    const totalExpected = Math.ceil(400 * 1.25) // 500
    const res = Engine.acceptGunOffer(state, offer)
    assert.equal(res.ok, true)
    assert.equal(res.usedBank, true)
    assert.equal(res.fee, Math.ceil(400 * Engine.RULES.bankPurchaseFee))
    assert.equal(state.bank, 1000 - totalExpected)
    assert.equal(state.cash, 0)
    assert.equal(state.guns, 1)
  })

  test('acceptGunOffer fails when both cash and bank are insufficient', () => {
    const state = Engine.newGame({ seed: 1 })
    state.cash = 0
    state.bank = 100
    const offer = { price: 400, damage: 5, space: 4 }
    const res = Engine.acceptGunOffer(state, offer)
    assert.equal(res.ok, false)
    assert.equal(state.guns, 0)
  })

  test('bankPurchaseFee is 0.25 in RULES', () => {
    assert.equal(Engine.RULES.bankPurchaseFee, 0.25)
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
