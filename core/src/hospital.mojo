# core/src/hospital.mojo — buy health points at the hospital.
#
# Beermat 2.1's hospital (docs/beermat-2.1-re.md, "Hospital", N-10, N-31). The
# per-point price is (Random(9)+1) * 50, stored on the world as
# health_price_multiplier by generate_prices, so a point costs 50..450 and
# changes daily. Buying caps at full health and at what cash allows; the
# "nasty doctor" then fires on a 1-in-5 roll (day < limit - 1), of which only
# the drug-removal and health-cap parts are resolved (N-31).

import jsmath
import result
import rules
import rng as rng_mod
import world


# A purchase of 0 points (full health, or a request the cash cannot meet) is a
# clean no-op with amount 0; a real request that cannot be met returns
# ERR_INSUFFICIENT_CASH.
def buy_health(mut game: world.World, qty: Int64) raises -> result.Outcome:
    if qty <= 0:
        return result.Outcome(result.ERR_INVALID_ARGUMENT)
    if game.health >= rules.START_HEALTH:
        return result.Outcome(result.OK, 0)

    var price = game.health_price()
    var affordable = Int64(jsmath.js_floor(game.cash / Float64(price)))
    if affordable < 1:
        return result.Outcome(result.ERR_INSUFFICIENT_CASH)

    var space = rules.START_HEALTH - game.health
    var bought = qty
    if bought > space:
        bought = space
    if bought > affordable:
        bought = affordable

    game.cash -= Float64(price * bought)
    game.health += bought

    _roll_nasty_doctor(game)
    return result.Outcome(result.OK, bought)


# After a purchase, Random(5) == 0 (1 in 5) and day < limit - 1 trigger the
# nasty doctor. Only the resolved outcomes are modelled here: RemoveDrugs
# (outcome 1, or 3 when no drugs are held) and the health cap with the
# infection flag (outcome 2, or 4 when DAT_004e20f8 equals a decoded literal).
# The cash/kidney outcomes 3 and 4 are unresolved (N-31).
def _roll_nasty_doctor(mut game: world.World) raises:
    if rng_mod.rand_int(game.rng, 0, Int64(5) - 1) != 0:
        return
    if game.day >= game.num_days - 1:
        return
    game.infected = True
    var outcome: Int64 = rng_mod.rand_int(game.rng, 0, Int64(3) - 1)
    if outcome == 0 or (outcome == 2 and not game.inv_count() > 0):
        _remove_all_drugs(game)
    else:
        game.health = Int64(rules.INFECTION_HEALTH_CAP)
        if game.health > rules.START_HEALTH - 1:
            game.health = Int64(rules.START_HEALTH - 1)


def _remove_all_drugs(mut game: world.World):
    for i in range(rules.NUM_DRUGS):
        if game.has_inventory(i):
            game._drop_inventory(i)
