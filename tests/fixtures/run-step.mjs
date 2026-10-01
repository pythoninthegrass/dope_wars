// Executes a single fixture step against the loaded engine. Shared between
// generate.mjs (records the return + snapshot) and run.mjs (compares them
// against the recorded oracle). Any implementation replaying these fixtures
// needs the same dispatch table plus the same handful of state-shaping
// helpers (setPrices/setPrevPrices/setInventory/setField/buyCheapest/...).
import { scriptedRng, snapshotState } from './engine-loader.mjs'

export function makeRunStep(Engine) {
  return function runStep(state, step) {
    const { call, args = {}, rng } = step
    const rngArg = rng ? scriptedRng(rng) : null
    switch (call) {
      case 'newGame':
        return Engine.newGame(args)
      case 'generatePrices':
        return Engine.generatePrices(state)
      case 'buy':
        return Engine.buy(state, args.drug, args.qty)
      case 'sell':
        return Engine.sell(state, args.drug, args.qty)
      case 'travel':
        return Engine.travel(state, args.dest)
      case 'finances':
        return Engine.finances(state, args.action, args.amount)
      case 'rollArrivalEvent':
        return Engine.rollArrivalEvent(state, rngArg)
      case 'rollDealerVisit':
        return Engine.rollDealerVisit(state, rngArg ?? state.rng)
      case 'rollCoatDealerOffer':
        return Engine.rollCoatDealerOffer(state, rngArg ?? state.rng)
      case 'acceptCoatOffer':
        return Engine.acceptCoatOffer(state, args.offer, rngArg ?? state.rng)
      case 'rollGunDealerOffer':
        return Engine.rollGunDealerOffer(state, rngArg ?? state.rng)
      case 'acceptGunOffer':
        return Engine.acceptGunOffer(state, args.offer)
      case 'shouldStartChase':
        return Engine.shouldStartChase(state, rngArg)
      case 'startChase':
        return Engine.startChase(state, rngArg)
      case 'applyDamage':
        return Engine.applyDamage(state, args.amount)
      case 'runFromChase':
        return Engine.runFromChase(state, args.chase, rngArg)
      case 'stayInChase':
        return Engine.stayInChase(state, rngArg)
      case 'fight':
        return Engine.fight(state, args.chase, rngArg)
      case 'acceptDoctorOffer':
        return Engine.acceptDoctorOffer(state, args.offer)
      case 'finish':
        return Engine.finish(state)
      case 'setPrices':
        state.prices = { ...args }
        return { ok: true }
      case 'setPrevPrices':
        state.prevPrices = { ...args }
        return { ok: true }
      case 'setInventory': {
        const inv = {}
        for (const [k, v] of Object.entries(args)) inv[k] = { qty: v, avgPrice: 0 }
        state.inventory = inv
        return { ok: true }
      }
      case 'setField':
        Object.assign(state, args)
        return { ok: true }
      case 'buyCheapest': {
        const prices = state.prices
        const ids = Object.keys(prices).sort((a, b) => prices[a] - prices[b])
        for (const id of ids) {
          const r = Engine.buy(state, id, 1)
          if (r.ok) return { ok: true, drug: id, price: prices[id] }
        }
        return { ok: false, reason: 'nothing affordable' }
      }
      case 'insertHighScores': {
        const scores = []
        const offset = args.offset || 0
        for (let i = 0; i < args.count; i++) {
          Engine.insertHighScore(scores, { name: `p${i}`, score: i * 100 + offset, day: 31, dead: false, date: '2026-01-01' })
        }
        return { scores }
      }
      case 'serializeRoundTrip': {
        const json = Engine.serializeState(state)
        const restored = Engine.deserializeState(json)
        const before = snapshotState(state)
        const after = snapshotState(restored)
        const equal = JSON.stringify(before) === JSON.stringify(after)
        return { equal, json }
      }
      default:
        throw new Error(`unknown step call: ${call}`)
    }
  }
}
