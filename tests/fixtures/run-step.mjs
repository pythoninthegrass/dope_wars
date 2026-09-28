// Executes a single fixture step against the loaded engine. Shared between
// generate.mjs (records the return + snapshot) and run.mjs (compares them
// against the recorded oracle). Any implementation replaying these fixtures
// needs the same dispatch table plus the same handful of state-shaping
// helpers (setPrices/setInventory/setField/buyCheapest/...).
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
      case 'rollCoatDealerOffer':
        return Engine.rollCoatDealerOffer(state, rngArg)
      case 'acceptCoatOffer':
        return Engine.acceptCoatOffer(state, args.offer)
      case 'rollGunDealerOffer':
        return Engine.rollGunDealerOffer(state, rngArg)
      case 'acceptGunOffer':
        return Engine.acceptGunOffer(state, args.offer)
      case 'shouldStartChase':
        return Engine.shouldStartChase(state, rngArg)
      case 'startChase':
        return Engine.startChase(state, rngArg)
      case 'getFightRatings':
        return Engine.getFightRatings(state)
      case 'applyDamage':
        return Engine.applyDamage(state, args.amount)
      case 'runFromChase':
        return Engine.runFromChase(state, args.chase, args.isAggressor, rngArg)
      case 'fight':
        return Engine.fight(state, args.chase, rngArg)
      case 'finish':
        return Engine.finish(state)
      case 'setPrices':
        state.prices = { ...args }
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
      case 'rollDealerVisits': {
        // The two 15% dealer draws live in the UI layer, not the engine —
        // index.html:1387-1388 inside runArrivalSequence, and only reached when
        // shouldStartChase came back false (index.html:1382-1383). index.html is
        // deleted at the end of TASK-001, so this case is the surviving
        // statement of those lines' semantics.
        //
        // Both draws are consumed before `dead` is consulted. The prototype
        // spells the guard as `state.rng() < 0.15 && !state.dead`, so
        // short-circuit evaluation has already advanced state.rng by the time
        // the guard is tested: a dead player spends two draws and reports
        // neither dealer. A helper that tested `dead` first would desync the
        // stream for the rest of the run. core/src/dealers.mojo
        // `roll_dealer_visits` draws unconditionally for the same reason.
        //
        // Without `rng` the helper draws from the state's own seeded stream, so
        // the reported pair and the post-call `rngState` are both oracle facts.
        // With `rng` the case is a script-mode assertion: the pair is forced,
        // and the state snapshot proves nothing was drawn from the seed.
        const draw = rngArg ?? state.rng
        const coat = draw() < 0.15
        const gun = draw() < 0.15
        if (state.dead) return { coat: false, gun: false }
        return { coat, gun }
      }
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
        for (let i = 0; i < args.count; i++) {
          Engine.insertHighScore(scores, { name: `p${i}`, score: i * 100, day: 31, dead: false, date: '2026-01-01' })
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
