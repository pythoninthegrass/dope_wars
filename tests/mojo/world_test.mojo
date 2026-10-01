# tests/mojo/world_test.mojo — slice 3 parity: world construction and coat usage.
#
# newGame is checked field by field against fixture 01 step 0 (seed 7), which is
# the oracle's own record of what a fresh game looks like. Prices are asserted in
# slice 4, once generatePrices exists; this test covers identity, config and the
# coat accounting that buy/sell and the dealers all depend on.

import fixtures
import lexeme
import record
import rules
import world
from std.testing import assert_equal, assert_true, assert_false, TestSuite


def _fixture_step(name: String, index: Int) raises -> record.Record:
    var remaining = index
    for line in fixtures.mjo_steps():
        var parsed = record.parse_record(String(line))
        if parsed.call == name:
            if remaining == 0:
                return parsed^
            remaining -= 1
    raise Error("no step " + name + "[" + String(index) + "] in the corpus")


def test_new_game_identity_matches_oracle() raises:
    var expected = _fixture_step("newGame", 0)
    ref state = expected.state
    var game = world.new_game(UInt32(7), 0, -1)
    assert_equal(Int64(game.seed), state.int_at("seed"))
    assert_equal(game.day, state.int_at("day"))
    assert_equal(game.num_days, state.int_at("numDays"))
    assert_equal(game.cash, state.float_at("cash"))
    assert_equal(game.debt, state.float_at("debt"))
    assert_equal(game.bank, state.float_at("bank"))
    assert_equal(game.health, state.int_at("health"))
    assert_equal(game.coat_capacity, state.int_at("coatCapacity"))
    assert_equal(game.guns, state.int_at("guns"))
    assert_equal(game.dead, state.bool_at("dead"))
    assert_equal(game.last_day_warned, state.bool_at("lastDayWarned"))
    assert_equal(game.location_index, rules.find_location_index(state.string_at("location")))
    assert_equal(Int64(game.rng.get_state()), state.int_at("rngState"))


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
