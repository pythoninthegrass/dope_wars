# core/src/prices.mojo — the per-turn price roster.
#
# Ported from generatePrices / shuffle in index.html:718-770.
#
# The draw order is load-bearing and easy to get subtly wrong, so it is spelled
# out here:
#
#   1. one roll for "is there an event at all" (< 0.70)
#   2. if so, a drug index, then a roll for a second (< 0.40), then a third
#      (< 0.05), each with its own drug index
#   3. for each event drug, in Set insertion order: a base price, then -- only
#      when the drug is both expensive and cheap -- one roll to decide which way
#      it goes
#   4. the target roster size
#   5. the Fisher-Yates shuffle of the remaining drugs
#   6. one price per remaining drug until the roster is full
#
# Step 3's conditional roll is the trap: `drug.expensive && (!drug.cheap ||
# rng() < 0.5)` short-circuits, so the roll happens only for a drug that is both
# expensive and cheap (speed is the only one). Drawing it unconditionally would
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


def generate_prices(mut game: world.World) raises -> List[world.PriceEvent]:
    game.snapshot_prices_to_prev()
    game.clear_prices()

    var table = rules.drugs()
    var location_table = rules.locations()
    var min_drugs = location_table[game.location_index].min_drugs
    var max_drugs = location_table[game.location_index].max_drugs

    var event_drugs = List[UInt8]()
    if game.rng.next() < 0.70:
        _add_unique(event_drugs, Int(rng_mod.rand_int(game.rng, 0, rules.NUM_DRUGS - 1)))
        if game.rng.next() < 0.40:
            _add_unique(event_drugs, Int(rng_mod.rand_int(game.rng, 0, rules.NUM_DRUGS - 1)))
            if game.rng.next() < 0.05:
                _add_unique(event_drugs, Int(rng_mod.rand_int(game.rng, 0, rules.NUM_DRUGS - 1)))

    for entry in event_drugs:
        var drug_index = Int(entry)
        ref drug = table[drug_index]
        var base = rng_mod.rand_int(game.rng, drug.min_price, drug.max_price)
        # Short-circuit matters: the roll is only drawn for a drug that is both
        # expensive and cheap.
        var go_expensive = drug.expensive and (not drug.cheap or game.rng.next() < 0.5)
        if go_expensive:
            game.set_price(drug_index, base * rules.EXPENSIVE_MULTIPLY, True)
            game.add_price_event(world.PRICE_EVENT_EXPENSIVE, drug_index)
        elif drug.cheap:
            var cheap = base // rules.CHEAP_DIVIDE
            if cheap < 1:
                cheap = 1
            game.set_price(drug_index, cheap, True)
            game.add_price_event(world.PRICE_EVENT_CHEAP, drug_index)
        else:
            game.set_price(drug_index, base, False)

    var target_count = rng_mod.rand_int(game.rng, min_drugs, max_drugs)

    var remaining = List[UInt8]()
    for i in range(rules.NUM_DRUGS):
        if not game.has_price(i):
            remaining.append(UInt8(i))
    shuffle(remaining, game.rng)

    for entry in remaining:
        if game.price_count() >= Int(target_count):
            break
        var drug_index = Int(entry)
        ref drug = table[drug_index]
        game.set_price(
            drug_index,
            rng_mod.rand_int(game.rng, drug.min_price, drug.max_price),
            False,
        )

    var produced = List[world.PriceEvent]()
    for i in range(game.price_events_len):
        produced.append(game.price_events[i].copy())
    return produced^
