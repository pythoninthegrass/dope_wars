# tests/mojo/serialize_test.mojo — save/load fidelity.
#
# dump then load must reproduce the world exactly. This is a property of the
# core's own save format, so it is checked on the Mojo side and survives
# changes to the state shape: it compares re-dumped bytes, not named fields.

import loans
import rules
import serialize
import trade
import travel
import world
from std.testing import assert_equal, assert_raises, assert_true, TestSuite


def _played_game(seed: UInt32) raises -> world.World:
    var game = world.new_game(seed, 0, -1)
    _ = travel.travel(game, rules.find_location_index("ghetto"))
    _ = trade.buy(game, Int(game.price_order[0]), 3)
    _ = travel.travel(game, rules.find_location_index("manhattan"))
    return game^


def _assert_same_bytes(ref a: List[UInt8], ref b: List[UInt8]) raises:
    assert_equal(len(a), len(b))
    for i in range(len(a)):
        assert_equal(a[i], b[i])


def test_new_game_round_trips() raises:
    var game = world.new_game(UInt32(42), 0, -1)
    var before = serialize.dump(game)
    _assert_same_bytes(before, serialize.dump(serialize.load(before)))


def test_played_game_round_trips() raises:
    var game = _played_game(UInt32(42))
    var before = serialize.dump(game)
    _assert_same_bytes(before, serialize.dump(serialize.load(before)))


def test_loans_and_released_sharks_round_trip() raises:
    var game = world.new_game(UInt32(5), 0, -1)
    game.shark_released[1] = 1
    game.shark_released[3] = 1
    assert_true(loans.borrow(game, 3, 9000).ok())
    assert_true(loans.borrow(game, 1, 400).ok())
    # Bertha's loan is due in 1 day, so two travels leave it past due.
    _ = travel.travel(game, rules.find_location_index("ghetto"))
    _ = travel.travel(game, rules.find_location_index("manhattan"))
    assert_equal(game.loan_count, 3)
    assert_true(game.loan_days_left[1] < 0)
    var bytes = serialize.dump(game)
    var restored = serialize.load(bytes)
    _assert_same_bytes(bytes, serialize.dump(restored))
    assert_equal(restored.loan_count, 3)
    for i in range(3):
        assert_equal(Int(restored.loan_shark[i]), Int(game.loan_shark[i]))
        assert_equal(restored.loan_balance[i], game.loan_balance[i])
        assert_equal(restored.loan_days_left[i], game.loan_days_left[i])
    assert_equal(Int(restored.shark_released[3]), 1)
    assert_equal(Int(restored.shark_released[2]), 0)


def test_load_rejects_a_loan_count_past_the_slots() raises:
    var bytes = serialize.dump(world.new_game(UInt32(5), 0, -1))
    bytes[serialize.LOAN_COUNT_OFFSET] = 6
    with assert_raises():
        _ = serialize.load(bytes)


def test_loaded_game_continues_like_the_original() raises:
    var original = _played_game(UInt32(7))
    var restored = serialize.load(serialize.dump(original))
    var dest = rules.find_location_index("bronx")
    _ = travel.travel(original, dest)
    _ = travel.travel(restored, dest)
    _assert_same_bytes(serialize.dump(original), serialize.dump(restored))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
