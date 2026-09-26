// Extracts the #engine <script> block from index.html and evaluates it in a
// vm context, so the game logic is tested exactly as shipped in the single
// playable file (no build step, no separate module to drift from index.html).
import { test, describe } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import vm from 'node:vm'

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

describe('generatePrices', () => {
  test('produces a roster within the borough min/max drug count', () => {
    const state = Engine.newGame({ seed: 7 })
    for (let i = 0; i < 50; i++) {
      Engine.generatePrices(state)
      const loc = Engine.RULES.locations.find((l) => l.id === state.location)
      const count = Object.keys(state.prices).length
      assert.ok(count >= loc.minDrugs && count <= loc.maxDrugs, `count ${count} outside [${loc.minDrugs},${loc.maxDrugs}]`)
    }
  })

  test('every listed price is within the drug base range, or scaled x4/÷4 for an event', () => {
    const state = Engine.newGame({ seed: 99 })
    for (let i = 0; i < 50; i++) {
      Engine.generatePrices(state)
      for (const [drugId, price] of Object.entries(state.prices)) {
        const drug = Engine.RULES.drugs.find((d) => d.id === drugId)
        const cheapFloor = Math.floor(drug.min / 4)
        const expensiveCeil = drug.max * 4
        assert.ok(price >= cheapFloor && price <= expensiveCeil, `${drugId} price ${price} outside plausible [${cheapFloor},${expensiveCeil}]`)
      }
    }
  })

  test('a drug not selected this stop is absent from prices (not tradeable)', () => {
    const state = Engine.newGame({ seed: 3 })
    Engine.generatePrices(state)
    for (const drug of Engine.RULES.drugs) {
      if (!(drug.id in state.prices)) {
        assert.equal(Engine.buy(state, drug.id, 1).ok, false)
      }
    }
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
  test('advances day, accrues 10% debt and 2% bank, regenerates prices', () => {
    const state = Engine.newGame({ seed: 1 })
    state.bank = 1000
    const before = state.day
    const res = Engine.travel(state, 'ghetto')
    assert.equal(res.ok, true)
    assert.equal(state.day, before + 1)
    assert.equal(state.location, 'ghetto')
    assert.equal(state.debt, 6050)
    assert.equal(state.bank, 1000 * 1.02)
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
