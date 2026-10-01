# core/src/events.mojo — the arrival-event roll and the damage helper.
#
# Beermat's arrival event (docs/beermat-re.md, M-06, 0x0045d96c). It fires on
# Random(14) == 0, or without any draw once cash + bank passes the wealth cap,
# in which case the outcome is the mugging with no outcome draw either. Else
# Random(4) picks the outcome:
#
#   0  found drugs on a dead dude. Skipped before any draw when the coat is full.
#      Drug: Random(11) over Beermat's first 11 drug slots, redrawn until the
#      drug was traded in the market the player just left, then Random(7) + 2
#      units capped at the free space.
#   1  mugged: cash -= cash div (Random(2) + 3).
#   2  a friend gives drugs: the same drug and quantity draws as outcome 0.
#   3  police dogs: with drugs held, Random(12) redrawn until held, then
#      Random(4) > 1 drops min(Random(held) + 1, 10) units; then Random(4) + 2 blocks.
#
# The drug pool is the previous market because Beermat rolls prices after the
# event. When no eligible drug is traded the draw loop is skipped (Beermat
# would spin forever). Received units dilute the average cost with integer
# division. Event kinds match dw_arrival_event_kind in include/dopewars.h.

import jsmath
import rules
import rng as rng_mod
import world


comptime ARRIVAL_NONE = 0
comptime ARRIVAL_MUGGED = 1
comptime ARRIVAL_FREE_DRUGS = 2
comptime ARRIVAL_DOG_CHASE = 3
comptime ARRIVAL_FOUND_DRUGS = 4


struct ArrivalEvent(Copyable, Movable):
    var kind: Int
    var drug_index: Int
    var qty: Int64
    var amount: Int64
    var blocks: Int64

    def __init__(
        out self,
        kind: Int,
        drug_index: Int = -1,
        qty: Int64 = 0,
        amount: Int64 = 0,
        blocks: Int64 = 0,
    ):
        self.kind = kind
        self.drug_index = drug_index
        self.qty = qty
        self.amount = amount
        self.blocks = blocks


def apply_damage(mut game: world.World, amount: Int64) -> Int64:
    game.health -= amount
    if game.health < 0:
        game.health = 0
    if game.health <= 0:
        game.dead = True
    return game.health


# Random(11) over Beermat's first 11 slots until the drug was in the previous market; -1 when none can be.
def _pick_drug_from_left_market(mut game: world.World) raises -> Int:
    var any_eligible = False
    for slot in range(rules.GIFT_DRUG_RANGE):
        if game.prev_price_present[rules.beermat_slot_drug_index(slot)] != 0:
            any_eligible = True
    if not any_eligible:
        return -1
    while True:
        var slot = rng_mod.rand_int(game.rng, 0, Int64(rules.GIFT_DRUG_RANGE - 1))
        var drug_index = rules.beermat_slot_drug_index(Int(slot))
        if game.prev_price_present[drug_index] != 0:
            return drug_index


# Random(12) over Beermat's slots until the drug is held. Needs something held.
def _pick_held_drug(mut game: world.World) raises -> Int:
    while True:
        var slot = rng_mod.rand_int(game.rng, 0, Int64(rules.NUM_DRUGS - 1))
        var drug_index = rules.beermat_slot_drug_index(Int(slot))
        if game.has_inventory(drug_index):
            return drug_index


# Adds the units and dilutes the average cost: held * avg div (held + added).
def _receive_drugs(mut game: world.World, drug_index: Int, qty: Int64) -> Int64:
    var held = game.inv_qty_of(drug_index)
    var avg = game.inv_avg_price_of(drug_index)
    var granted = game.add_to_inventory(drug_index, qty)
    var diluted = 0.0
    if held != 0:
        diluted = Float64(jsmath.js_floor(Float64(held) * avg / Float64(held + granted)))
    game.set_inventory(drug_index, held + granted, diluted)
    return granted


def _roll_drug_gift(mut game: world.World, kind: Int) raises -> ArrivalEvent:
    var space = game.coat_capacity - game.coat_used()
    if space <= 0:
        return ArrivalEvent(ARRIVAL_NONE)
    var drug_index = _pick_drug_from_left_market(game)
    if drug_index < 0:
        return ArrivalEvent(ARRIVAL_NONE)
    var qty = rng_mod.rand_int(game.rng, 2, 8)
    if qty > space:
        qty = space
    var granted = _receive_drugs(game, drug_index, qty)
    return ArrivalEvent(kind, drug_index, granted)


def _roll_mugging(mut game: world.World) raises -> ArrivalEvent:
    var before = game.cash
    var divisor = rng_mod.rand_int(game.rng, 3, 4)
    game.cash = before - Float64(jsmath.js_floor(before / Float64(divisor)))
    return ArrivalEvent(ARRIVAL_MUGGED, amount=Int64(before - game.cash))


def _roll_police_dogs(mut game: world.World) raises -> ArrivalEvent:
    var drug_index = -1
    var dropped: Int64 = 0
    if game.coat_used() > 0:
        drug_index = _pick_held_drug(game)
        if rng_mod.rand_int(game.rng, 0, 3) > 1:
            dropped = rng_mod.rand_int(game.rng, 1, game.inv_qty_of(drug_index))
            if dropped > rules.DOG_DROP_CAP:
                dropped = rules.DOG_DROP_CAP
    var blocks = rng_mod.rand_int(game.rng, 2, 5)
    if dropped > 0:
        _ = game.remove_from_inventory(drug_index, dropped)
        return ArrivalEvent(ARRIVAL_DOG_CHASE, drug_index, dropped, blocks=blocks)
    return ArrivalEvent(ARRIVAL_DOG_CHASE, qty=0, blocks=blocks)


def roll_arrival_event(mut game: world.World) raises -> ArrivalEvent:
    var forced = game.cash + game.bank > rules.EVENT_WEALTH_CAP
    if not forced and rng_mod.rand_int(game.rng, 0, rules.ARRIVAL_EVENT_ODDS - 1) != 0:
        return ArrivalEvent(ARRIVAL_NONE)
    var outcome: Int64 = 1
    if not forced:
        outcome = rng_mod.rand_int(game.rng, 0, 3)
    if outcome == 0:
        return _roll_drug_gift(game, ARRIVAL_FOUND_DRUGS)
    if outcome == 2:
        return _roll_drug_gift(game, ARRIVAL_FREE_DRUGS)
    if outcome == 1:
        return _roll_mugging(game)
    return _roll_police_dogs(game)
