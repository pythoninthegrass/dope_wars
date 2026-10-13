# tests/mojo/serialize_test.mojo — save/load fidelity.
#
# dump then load must reproduce the world exactly. This is a property of the
# core's own save format, so it is checked on the Mojo side and survives
# changes to the state shape: it compares re-dumped bytes, not named fields.

import rules
import serialize
import trade
import travel
import world
from std.testing import assert_equal, TestSuite


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


def test_loaded_game_continues_like_the_original() raises:
    var original = _played_game(UInt32(7))
    var restored = serialize.load(serialize.dump(original))
    var dest = rules.find_location_index("bronx")
    _ = travel.travel(original, dest)
    _ = travel.travel(restored, dest)
    _assert_same_bytes(serialize.dump(original), serialize.dump(restored))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
