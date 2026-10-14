# tests/mojo/run_test.mojo — a whole game from new_game to finish.
#
# No exact goldens: the draw stream changes with every rule slice, so this pins
# properties that hold for any rule set. A seeded game is deterministic, a
# different seed plays differently, and the invariants the rules promise hold on
# every day.

import rules
import score
import serialize
import trade
import travel
import world
from std.testing import assert_equal, assert_true, TestSuite


# Travel to the next borough in a fixed cycle, then buy one unit of the cheapest
# drug on offer when it is affordable and fits.
def _play(seed: UInt32) raises -> world.World:
    var game = world.new_game(seed, 0, -1)
    var step = 0
    while game.day < game.num_days and not game.dead:
        var dest = (game.location_index + 1 + step % 5) % rules.NUM_LOCATIONS
        step += 1
        var day_before = game.day
        var outcome = travel.travel(game, dest)
        assert_true(outcome.ok())
        assert_equal(game.day, day_before + 1)
        var cheapest = -1
        for i in range(game.price_count()):
            var index = Int(game.price_order[i])
            if cheapest < 0 or game.price_value[index] < game.price_value[cheapest]:
                cheapest = index
        if cheapest >= 0:
            _ = trade.buy(game, cheapest, 1)
        assert_true(game.coat_used() <= game.coat_capacity)
        assert_true(game.cash >= 0.0)
    return game^


def test_the_game_runs_to_the_last_day() raises:
    var game = _play(UInt32(12345))
    assert_equal(game.day, game.num_days)
    assert_true(not game.dead)


def test_finish_scores_cash_plus_bank_minus_debt() raises:
    var game = _play(UInt32(12345))
    var outcome = score.finish(game)
    assert_equal(outcome.score, game.cash + game.bank - Float64(game.total_debt()))
    assert_equal(outcome.day, game.day)


def test_a_seed_replays_identically() raises:
    var first = serialize.dump(_play(UInt32(99)))
    var second = serialize.dump(_play(UInt32(99)))
    assert_equal(len(first), len(second))
    for i in range(len(first)):
        assert_equal(first[i], second[i])


def test_different_seeds_play_differently() raises:
    var a = serialize.dump(_play(UInt32(1)))
    var b = serialize.dump(_play(UInt32(2)))
    var differs = len(a) != len(b)
    if not differs:
        for i in range(len(a)):
            if a[i] != b[i]:
                differs = True
    assert_true(differs)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
