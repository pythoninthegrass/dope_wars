# core/src/finances.mojo — moving money between cash and the bank; loans live in loans.mojo.
#
# Ported from finances in index.html:816-834.
#
# The amount is floored and clamped to zero first, so a negative or fractional
# request is normalised before any action runs. Each action then moves at most
# what is available: deposit is capped by cash and withdraw by bank. The
# returned amount is what actually moved, not what was asked for.

import jsmath
import result
import world


comptime ACTION_DEPOSIT = 0
comptime ACTION_WITHDRAW = 1
comptime ACTION_UNKNOWN = -1


def parse_action(name: String) -> Int:
    if name == "deposit":
        return ACTION_DEPOSIT
    if name == "withdraw":
        return ACTION_WITHDRAW
    return ACTION_UNKNOWN


def finances(mut game: world.World, action: Int, amount: Float64) raises -> result.Outcome:
    # Math.max(0, Math.floor(amount || 0))
    var requested = amount
    if requested != requested:  # NaN, the JS `|| 0` case
        requested = 0.0
    var normalised = Float64(jsmath.js_floor(requested))
    if normalised < 0.0:
        normalised = 0.0

    if action == ACTION_DEPOSIT:
        var moved = normalised
        if moved > game.cash:
            moved = game.cash
        game.cash -= moved
        game.bank += moved
        return result.Outcome(result.OK, Int64(moved))

    if action == ACTION_WITHDRAW:
        var moved = normalised
        if moved > game.bank:
            moved = game.bank
        game.bank -= moved
        game.cash += moved
        return result.Outcome(result.OK, Int64(moved))

    return result.Outcome(result.ERR_INVALID_ARGUMENT)
