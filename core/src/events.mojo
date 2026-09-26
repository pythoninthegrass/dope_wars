# core/src/events.mojo — the arrival-event roll and the damage helper.
#
# Ported from rollArrivalEvent, randomTradeableDrug and applyDamage in
# index.html:836-927.
#
# The roll is a percentile: one draw times 100, then a band. The bands and their
# draw counts are the whole contract, and several of them short-circuit in ways
# that change how many draws happen:
#
#   < 10    mugged. If cash is exactly 0, no second draw: damage is 5% of health.
#           Otherwise one draw picks the 80..95% the mugger leaves behind.
#   < 30    freeDrugs. A drug pick (only if any drug is traded) then a 3..7 qty.
#           If the coat is full the grant is 0 and the event degrades to none,
#           but both draws have already happened.
#   < 50    dogChase or foundDrugs. The 50/50 draw happens only when something is
#           held, so an empty coat skips it and goes straight to foundDrugs.
#   < 60    mamasBrownies. Only weed or hashish qualify; the larger holding wins,
#           ties going to weed because the candidate list is built weed-first.
#   < 60.5  freeWeedDeath. Damage equal to current health, so the player dies.
#   < 75    flavor. A 1..10 dollar snack.
#   else    none.
#
# Event kinds match dw_arrival_event_kind in include/dopewars.h.

import jsmath
import result
import rules
import rng as rng_mod
import world


comptime ARRIVAL_NONE = 0
comptime ARRIVAL_MUGGED = 1
comptime ARRIVAL_FREE_DRUGS = 2
comptime ARRIVAL_DOG_CHASE = 3
comptime ARRIVAL_FOUND_DRUGS = 4
comptime ARRIVAL_MAMAS_BROWNIES = 5
comptime ARRIVAL_FREE_WEED_DEATH = 6
comptime ARRIVAL_FLAVOR = 7


struct ArrivalEvent(Copyable, Movable):
    var kind: Int
    var drug_index: Int
    var qty: Int64
    var amount: Int64
    var damage: Int64

    def __init__(
        out self,
        kind: Int,
        drug_index: Int = -1,
        qty: Int64 = 0,
        amount: Int64 = 0,
        damage: Int64 = 0,
    ):
        self.kind = kind
        self.drug_index = drug_index
        self.qty = qty
        self.amount = amount
        self.damage = damage


def apply_damage(mut game: world.World, amount: Int64) -> Int64:
    game.health -= amount
    if game.health < 0:
        game.health = 0
    if game.health <= 0:
        game.dead = True
    return game.health


# randomTradeableDrug: pick uniformly from the drugs traded here, in roster
# order. Returns -1 when nothing is traded, which is the JS `null`.
def random_tradeable_drug(mut game: world.World) raises -> Int:
    if game.price_count() == 0:
        return -1
    var pick = rng_mod.rand_int(game.rng, 0, Int64(game.price_count() - 1))
    return Int(game.price_order[Int(pick)])


def roll_arrival_event(mut game: world.World) raises -> ArrivalEvent:
    var roll = game.rng.next() * 100.0

    if roll < 10.0:
        if game.cash == 0.0:
            var damage = jsmath.js_floor(Float64(game.health) * 0.05)
            _ = apply_damage(game, damage)
            return ArrivalEvent(ARRIVAL_MUGGED, damage=damage)
        var pct = Float64(rng_mod.rand_int(game.rng, 80, 95)) / 100.0
        var before = game.cash
        game.cash = Float64(jsmath.js_floor(game.cash * pct))
        return ArrivalEvent(ARRIVAL_MUGGED, amount=Int64(before - game.cash))

    if roll < 30.0:
        var drug_index = random_tradeable_drug(game)
        if drug_index < 0:
            return ArrivalEvent(ARRIVAL_NONE)
        var amount = rng_mod.rand_int(game.rng, 3, 7)
        var granted = game.add_to_inventory(drug_index, amount)
        if granted == 0:
            return ArrivalEvent(ARRIVAL_NONE)
        return ArrivalEvent(ARRIVAL_FREE_DRUGS, drug_index, granted)

    if roll < 50.0:
        if game.inv_count() > 0 and game.rng.next() < 0.5:
            var pick = rng_mod.rand_int(game.rng, 0, Int64(game.inv_count() - 1))
            var drug_index = Int(game.inv_order[Int(pick)])
            var amount = rng_mod.rand_int(game.rng, 3, 7)
            var lost = game.remove_from_inventory(drug_index, amount)
            return ArrivalEvent(ARRIVAL_DOG_CHASE, drug_index, lost)
        var drug_index = random_tradeable_drug(game)
        if drug_index < 0:
            return ArrivalEvent(ARRIVAL_NONE)
        var amount = rng_mod.rand_int(game.rng, 3, 7)
        var granted = game.add_to_inventory(drug_index, amount)
        return ArrivalEvent(ARRIVAL_FOUND_DRUGS, drug_index, granted)

    if roll < 60.0:
        # weed first, then hashish; the larger holding wins and a tie keeps weed.
        var best = -1
        var best_qty: Int64 = 0
        for candidate in [rules.find_drug_index("weed"), rules.find_drug_index("hashish")]:
            if game.has_inventory(candidate) and game.inv_qty_of(candidate) > best_qty:
                best = candidate
                best_qty = game.inv_qty_of(candidate)
        if best < 0:
            return ArrivalEvent(ARRIVAL_NONE)
        var amount = rng_mod.rand_int(game.rng, 2, 6)
        var lost = game.remove_from_inventory(best, amount)
        return ArrivalEvent(ARRIVAL_MAMAS_BROWNIES, best, lost)

    if roll < 60.5:
        _ = apply_damage(game, game.health)
        return ArrivalEvent(ARRIVAL_FREE_WEED_DEATH)

    if roll < 75.0:
        var amount = rng_mod.rand_int(game.rng, 1, 10)
        game.cash -= Float64(amount)
        if game.cash < 0.0:
            game.cash = 0.0
        return ArrivalEvent(ARRIVAL_FLAVOR, amount=amount)

    return ArrivalEvent(ARRIVAL_NONE)
