# core/src/travel.mojo — moving between boroughs and the turn's interest.
#
# Ported from travel in index.html:802-814.
#
# The guard order is part of the contract, because each guard has its own
# failure code and the oracle records which one fired:
#
#   1. already there
#   2. unknown location
#   3. dead
#   4. the game is over (day >= numDays)
#
# Interest is applied on the way out: debt compounds at 10% and is rounded to a
# whole dollar, bank compounds at 2% and is left fractional. That asymmetry is
# the original's, and it is why bank is a Float64 in the world while debt is
# always integral.

import jsmath
import prices
import result
import rules
import world


def travel(mut game: world.World, dest_index: Int) raises -> result.Outcome:
    if dest_index == game.location_index:
        return result.Outcome(result.ERR_ALREADY_THERE)
    if dest_index < 0 or dest_index >= rules.NUM_LOCATIONS:
        return result.Outcome(result.ERR_UNKNOWN_LOCATION)
    if game.dead:
        return result.Outcome(result.ERR_DEAD)
    if game.day >= game.num_days:
        return result.Outcome(result.ERR_GAME_OVER)

    game.day += 1
    game.debt = Float64(jsmath.js_round(game.debt * (1.0 + rules.DEBT_INTEREST)))
    game.bank = game.bank * (1.0 + rules.BANK_INTEREST)
    game.location_index = dest_index
    _ = prices.generate_prices(game)
    return result.Outcome(result.OK)
