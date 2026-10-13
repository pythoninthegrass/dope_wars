# tests/mojo/world_test.mojo — slice 3 parity: world construction and coat usage.
#
# newGame's start state, plus the coat accounting that buy/sell and the dealers
# all depend on. The seeded price roster is not pinned: it is a 1.2 stream.

import rules
import world
from std.testing import assert_equal, assert_true, assert_false, TestSuite


# The start state Beermat 2.1 shares with 1.2 (docs/beermat-2.1-re.md, "Start state").
def test_new_game_identity() raises:
    var game = world.new_game(UInt32(7), 0, -1)
    assert_equal(Int64(game.seed), 7)
    assert_equal(game.day, 1)
    assert_equal(game.cash, Float64(2000))
    assert_equal(game.bank, Float64(0))
    assert_equal(game.health, 100)
    assert_equal(game.coat_capacity, 100)
    assert_equal(game.dead, False)
    assert_equal(game.last_day_warned, False)


def test_new_game_starts_with_a_price_roster() raises:
    # newGame calls generatePrices, so a fresh game already has a roster and no
    # inventory. The roster's contents are asserted in prices_test.
    var game = world.new_game(UInt32(7), 0, -1)
    assert_equal(game.inv_count(), 0)
    assert_equal(game.prev_price_count(), 0)
    assert_true(game.price_count() > 0)
    assert_true(game.price_count() <= rules.NUM_DRUGS)


def test_new_game_honours_overrides() raises:
    # num_days 0 means "use the ruleset default"; start_cash -1 means the same.
    var defaulted = world.new_game(UInt32(7), 0, -1)
    assert_equal(defaulted.num_days, rules.NUM_DAYS)
    assert_equal(defaulted.cash, Float64(rules.START_CASH))

    var overridden = world.new_game(UInt32(7), 5, 1234)
    assert_equal(overridden.num_days, 5)
    assert_equal(overridden.cash, 1234.0)

    # start_cash 0 is a real value, not a sentinel.
    var broke = world.new_game(UInt32(7), 0, 0)
    assert_equal(broke.cash, 0.0)


def test_coat_used_counts_inventory_only() raises:
    var game = world.new_game(UInt32(7), 0, -1)
    assert_equal(game.coat_used(), 0)

    _ = game.add_to_inventory(0, 3)  # acid
    _ = game.add_to_inventory(11, 2)  # weed
    assert_equal(game.coat_used(), 5)

    # A gun takes no coat space.
    game.guns = 2
    assert_equal(game.coat_used(), 5)


def test_coat_used_ignores_emptied_slots() raises:
    var game = world.new_game(UInt32(7), 0, -1)
    _ = game.add_to_inventory(0, 3)
    assert_equal(game.coat_used(), 3)
    _ = game.remove_from_inventory(0, 3)
    assert_equal(game.coat_used(), 0)
    assert_equal(game.inv_count(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
