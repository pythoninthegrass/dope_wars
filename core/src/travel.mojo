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
# Interest is applied on the way out: debt compounds at 10% and bank at 5%, each
# rounded to a whole dollar and skipped at a balance of 0 or less (see interest).

import interest
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
    game.debt = Float64(interest.debt_after_interest(Int64(game.debt)))
    game.bank = Float64(interest.bank_after_interest(Int64(game.bank)))
    game.location_index = dest_index
    _ = prices.generate_prices(game)
    return result.Outcome(result.OK)
