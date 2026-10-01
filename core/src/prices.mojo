# core/src/prices.mojo — the per-turn price roster.
#
# Ported from generatePrices / shuffle in index.html (<script id="engine">).
#
# The draw order is load-bearing, so it is spelled out here:
#
#   1. the target roster size
#   2. the Fisher-Yates shuffle of all twelve drugs; the first `target` of them
#      are the drugs traded this turn
#   3. for each traded drug in drug-index order: a base price, then -- only for a
#      spike-flagged drug -- a 1-in-20 roll (a hit multiplies the price by 5 and
#      draws one more roll that picks the cops-bust or addicts message), then --
#      only for a crash-flagged drug -- a 1-in-20 roll (a hit divides by 10)
#
# The conditional rolls are the trap: drawing them for an unflagged drug would
# desynchronise every subsequent draw.

import rules
import rng as rng_mod
import world


def shuffle(mut arr: List[UInt8], mut source: rng_mod.Rng) raises:
    # Fisher-Yates from the end, exactly as the JS shuffle does.
    var i = len(arr) - 1
    while i > 0:
        var j = Int(rng_mod.rand_int(source, 0, Int64(i)))
        var tmp = arr[i]
        arr[i] = arr[j]
        arr[j] = tmp
        i -= 1


def _add_unique(mut arr: List[UInt8], value: Int):
    # A JS Set: duplicates collapse and the first insertion position wins.
    for entry in arr:
        if Int(entry) == value:
            return
    arr.append(UInt8(value))


def _event_roll_hits(mut source: rng_mod.Rng) raises -> Bool:
    return rng_mod.rand_int(source, 0, Int64(rules.EVENT_ODDS - 1)) == 0


def generate_prices(mut game: world.World) raises -> List[world.PriceEvent]:
    game.snapshot_prices_to_prev()
    game.clear_prices()

    var table = rules.drugs()
    var location_table = rules.locations()
    var min_drugs = location_table[game.location_index].min_drugs
    var max_drugs = location_table[game.location_index].max_drugs

    var target_count = rng_mod.rand_int(game.rng, min_drugs, max_drugs)

    var roster = List[UInt8]()
    for i in range(rules.NUM_DRUGS):
        roster.append(UInt8(i))
    shuffle(roster, game.rng)

    var traded = List[Bool]()
    for _ in range(rules.NUM_DRUGS):
        traded.append(False)
    for i in range(Int(target_count)):
        traded[Int(roster[i])] = True

    for drug_index in range(rules.NUM_DRUGS):
        if not traded[drug_index]:
            continue
        ref drug = table[drug_index]
        var price = rng_mod.rand_int(game.rng, drug.min_price, drug.max_price)
        var was_event = False
        if drug.expensive and _event_roll_hits(game.rng):
            price *= rules.EXPENSIVE_MULTIPLY
            was_event = True
            if rng_mod.rand_int(game.rng, 0, 1) == 0:
                game.add_price_event(world.PRICE_EVENT_BUST, drug_index)
            else:
                game.add_price_event(world.PRICE_EVENT_EXPENSIVE, drug_index)
        if drug.cheap and _event_roll_hits(game.rng):
            price = price // rules.CHEAP_DIVIDE
            was_event = True
            game.add_price_event(world.PRICE_EVENT_CHEAP, drug_index)
        game.set_price(drug_index, price, was_event)

    var produced = List[world.PriceEvent]()
    for i in range(game.price_events_len):
        produced.append(game.price_events[i].copy())
    return produced^
