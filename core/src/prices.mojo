# core/src/prices.mojo — the per-turn price roster.
#
# Beermat 2.1's price roll (docs/beermat-2.1-re.md, "Price roll", 0x004bbfc4).
#
# The draw order is load-bearing, so it is spelled out here. First Random(9), the
# hospital price multiplier (not stored yet). Then for each of the thirteen drugs
# in Beermat slot order:
#
#   1. a price. On the first day it is a fresh roll min + Random(spread + 1). On
#      later days Random(5) == 0 keeps the price the last roll recorded, unless
#      that roll gave the drug an event; any other result rolls fresh
#   2. an availability roll: a 1-in-8 hit makes the drug absent this turn
#   3. only for a spike drug: a 1-in-40 roll; a hit on an available drug with no
#      event on the previous roll multiplies the price by 5. A hit draws one more
#      roll that picks the cops-bust or addicts message, except Special K, which
#      has its own message and draws nothing
#   4. only for a crash drug: a 1-in-40 roll; a hit under the same conditions
#      divides the price by 10
#
# The spike and crash rolls are drawn even when the drug is absent, and the
# conditional rolls are the trap: drawing them for an unflagged drug would
# desynchronise every subsequent draw. A drug that is absent still has a price:
# it is recorded in last_price and rolled forward, it is just not for sale.
#
# Not modelled yet: the tip drug the Old Lady and an arrest set (it forces a spike
# and keeps the drug available), and the hospital multiplier.

import rules
import rng as rng_mod
import world


def _roll_hits(mut source: rng_mod.Rng, odds: Int) raises -> Bool:
    return rng_mod.rand_int(source, 0, Int64(odds - 1)) == 0


def _direction(price: Int64, seen: Int64) -> Int8:
    if seen <= 0 or price == seen:
        return 0
    return Int8(1) if price > seen else Int8(-1)


def generate_prices(mut game: world.World) raises -> List[world.PriceEvent]:
    game.snapshot_prices_to_prev()
    game.clear_prices()

    var table = rules.drugs()
    var special_k = rules.find_drug_index("specialk")

    game.health_price_multiplier = rng_mod.rand_int(game.rng, 0, Int64(rules.HOSPITAL_MULTIPLIER_RANGE - 1)) + 1

    for slot in range(rules.NUM_DRUGS):
        var drug_index = rules.beermat_slot_drug_index(slot)
        ref drug = table[drug_index]
        var had_event = game.last_event[drug_index] != 0
        var price: Int64
        if game.day == 1:
            price = rng_mod.rand_int(game.rng, drug.min_price, drug.max_price)
        elif _roll_hits(game.rng, rules.PRICE_KEEP_ODDS) and not had_event and game.last_price[drug_index] > 0:
            price = game.last_price[drug_index]
        else:
            price = rng_mod.rand_int(game.rng, drug.min_price, drug.max_price)
        var available = not _roll_hits(game.rng, rules.ABSENT_ODDS)
        var event = 0
        if drug.expensive and _roll_hits(game.rng, rules.SPIKE_CRASH_ODDS) and available and not had_event:
            price *= rules.EXPENSIVE_MULTIPLY
            event = 1
            if drug_index == special_k:
                game.add_price_event(world.PRICE_EVENT_VET, drug_index)
            elif rng_mod.rand_int(game.rng, 0, 1) == 0:
                game.add_price_event(world.PRICE_EVENT_BUST, drug_index)
            else:
                game.add_price_event(world.PRICE_EVENT_EXPENSIVE, drug_index)
        if drug.cheap and _roll_hits(game.rng, rules.SPIKE_CRASH_ODDS) and available and not had_event:
            price = price // rules.CHEAP_DIVIDE
            event = 2
            game.add_price_event(world.PRICE_EVENT_CHEAP, drug_index)

        game.last_price[drug_index] = price
        game.last_event[drug_index] = UInt8(event)
        game.price_direction[drug_index] = 0
        if available:
            if event == 0:
                game.price_direction[drug_index] = _direction(price, game.seen_price[drug_index])
            game.seen_price[drug_index] = price
            game.set_price(drug_index, price, event != 0)

    var produced = List[world.PriceEvent]()
    for i in range(game.price_events_len):
        produced.append(game.price_events[i].copy())
    return produced^
