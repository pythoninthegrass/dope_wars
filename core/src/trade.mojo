# core/src/trade.mojo — buying and selling.
#
# Ported from buy / sell in index.html:772-800.
#
# Two details are easy to get wrong and both are load-bearing:
#
#   - buy recomputes the running average buy price as a weighted mean over the
#     whole holding, so a second purchase at a different price moves avgPrice.
#     sell does not touch avgPrice at all.
#   - buy's "Not enough cash or coat space." is one JS sentence covering two
#     conditions. Core reports the precise code, and the harness maps the
#     sentence back by re-deriving which condition held from the state.

import jsmath
import result
import rules
import world


def buy(mut game: world.World, drug_index: Int, qty: Int64) raises -> result.Outcome:
    if not game.has_price(drug_index):
        return result.Outcome(result.ERR_NOT_TRADED_HERE)
    if qty <= 0:
        return result.Outcome(result.ERR_INVALID_ARGUMENT)
    var price = game.price_of(drug_index)
    var max_affordable = jsmath.js_floor(game.cash / Float64(price))
    if max_affordable < 1:
        return result.Outcome(result.ERR_INSUFFICIENT_CASH)
    var space_left = game.coat_capacity - game.coat_used()
    if qty > max_affordable:
        return result.Outcome(result.ERR_INSUFFICIENT_CASH)
    if qty > space_left:
        return result.Outcome(result.ERR_INSUFFICIENT_SPACE)

    var cost = price * qty
    game.cash -= Float64(cost)
    var held_qty = game.inv_qty_of(drug_index)
    var held_avg = game.inv_avg_price_of(drug_index)
    var total_cost = held_avg * Float64(held_qty) + Float64(cost)
    var new_qty = held_qty + qty
    # Beermat's avg cost is a truncating integer, not a float (docs/beermat-re.md M-12).
    var new_avg = Float64(jsmath.js_floor(total_cost / Float64(new_qty)))
    game.set_inventory(drug_index, new_qty, new_avg)
    return result.Outcome(result.OK)


def sell(mut game: world.World, drug_index: Int, qty: Int64) raises -> result.Outcome:
    if not game.has_price(drug_index):
        return result.Outcome(result.ERR_NOT_TRADED_HERE)
    if not game.has_inventory(drug_index):
        return result.Outcome(result.ERR_INSUFFICIENT_INVENTORY)
    var held = game.inv_qty_of(drug_index)
    if qty > held or qty <= 0:
        return result.Outcome(result.ERR_INSUFFICIENT_INVENTORY)

    var price = game.price_of(drug_index)
    game.cash += Float64(price * qty)
    # avgPrice is deliberately left alone: the JS sell does not touch it.
    game.set_inventory(drug_index, held - qty, game.inv_avg_price_of(drug_index))
    return result.Outcome(result.OK)
