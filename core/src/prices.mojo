# core/src/prices.mojo — the per-turn price roster.
#
# Ported from generatePrices in index.html (<script id="engine">).
#
# The draw order is load-bearing, so it is spelled out here. For each of the
# twelve drugs in drug-index order:
#
#   1. a base price
#   2. an availability roll: a 1-in-8 hit makes the drug absent this turn
#   3. only for a spike-flagged drug: a 1-in-20 roll; a hit on an available drug
#      multiplies the price by 5 and draws one more roll that picks the
#      cops-bust or addicts message
#   4. only for a crash-flagged drug: a 1-in-20 roll; a hit on an available drug
#      divides the price by 10
#
# The spike and crash rolls are drawn even when the drug is absent, and the
# conditional rolls are the trap: drawing them for an unflagged drug would
# desynchronise every subsequent draw.

import rules
import rng as rng_mod
import world


def _roll_hits(mut source: rng_mod.Rng, odds: Int) raises -> Bool:
    return rng_mod.rand_int(source, 0, Int64(odds - 1)) == 0


def generate_prices(mut game: world.World) raises -> List[world.PriceEvent]:
    game.snapshot_prices_to_prev()
    game.clear_prices()

    var table = rules.drugs()

    for drug_index in range(rules.NUM_DRUGS):
        ref drug = table[drug_index]
        var price = rng_mod.rand_int(game.rng, drug.min_price, drug.max_price)
        var available = not _roll_hits(game.rng, rules.ABSENT_ODDS)
        var was_event = False
        if drug.expensive and _roll_hits(game.rng, rules.EVENT_ODDS) and available:
            price *= rules.EXPENSIVE_MULTIPLY
            was_event = True
            if rng_mod.rand_int(game.rng, 0, 1) == 0:
                game.add_price_event(world.PRICE_EVENT_BUST, drug_index)
            else:
                game.add_price_event(world.PRICE_EVENT_EXPENSIVE, drug_index)
        if drug.cheap and _roll_hits(game.rng, rules.EVENT_ODDS) and available:
            price = price // rules.CHEAP_DIVIDE
            was_event = True
            game.add_price_event(world.PRICE_EVENT_CHEAP, drug_index)
        if available:
            game.set_price(drug_index, price, was_event)

    var produced = List[world.PriceEvent]()
    for i in range(game.price_events_len):
        produced.append(game.price_events[i].copy())
    return produced^
