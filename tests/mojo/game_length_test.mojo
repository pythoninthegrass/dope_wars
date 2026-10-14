# tests/mojo/game_length_test.mojo — Beermat 2.1 game lengths (N-01).
#
# A game runs 15, 30, 60 or 90 days, chosen at new game. Day 1 is the first
# turn and a travel on the last day ends the game (docs/beermat-2.1-re.md,
# "Travel, chase start and the day loop"), so a length of N allows N - 1 travels.

import combat
import result
import rules
import score
import serialize
import travel
import world
from std.testing import assert_equal, assert_true, TestSuite


def _lengths() -> List[Int64]:
    return [Int64(15), Int64(30), Int64(60), Int64(90)]


def _step(mut game: world.World) raises -> result.Outcome:
    var dest = (game.location_index + 1) % rules.NUM_LOCATIONS
    return travel.travel(game, dest)


def test_the_default_length_is_thirty_days() raises:
    assert_equal(rules.NUM_DAYS, 30)
    assert_equal(world.new_game(UInt32(7), 0, -1).num_days, 30)


def test_each_length_is_accepted_at_new_game() raises:
    for length in _lengths():
        var game = world.new_game(UInt32(7), length, -1)
        assert_equal(game.num_days, length)
        assert_equal(game.day, 1)


def test_a_game_ends_on_the_chosen_last_day() raises:
    for length in _lengths():
        var game = world.new_game(UInt32(7), length, -1)
        var travels = 0
        while game.day < game.num_days:
            assert_true(_step(game).ok())
            travels += 1
        assert_equal(Int64(travels), length - 1)
        assert_equal(game.day, length)


def test_travel_on_the_last_day_is_refused() raises:
    for length in _lengths():
        var game = world.new_game(UInt32(7), length, -1)
        while game.day < game.num_days:
            _ = _step(game)
        var outcome = _step(game)
        assert_equal(outcome.code, result.ERR_GAME_OVER)
        assert_equal(game.day, length)


def test_no_chase_starts_on_the_last_two_days() raises:
    for length in _lengths():
        var game = world.new_game(UInt32(7), length, -1)
        game.day = length - 2
        game.rng.set_script([0.0])
        assert_true(combat.should_start_chase(game))
        game.day = length - 1
        game.rng.set_script([0.0])
        assert_true(not combat.should_start_chase(game))


def test_the_chase_draw_is_consumed_on_the_last_two_days() raises:
    for length in _lengths():
        var game = world.new_game(UInt32(7), length, -1)
        game.day = length - 1
        game.rng.set_script([0.0, 0.5])
        assert_true(not combat.should_start_chase(game))
        assert_equal(game.rng._script_pos, 1)


def test_finish_reports_the_last_day_of_each_length() raises:
    for length in _lengths():
        var game = world.new_game(UInt32(7), length, -1)
        while game.day < game.num_days:
            _ = _step(game)
        assert_equal(score.finish(game).day, length)


def test_the_length_survives_save_and_load() raises:
    for length in _lengths():
        var game = world.new_game(UInt32(7), length, -1)
        _ = _step(game)
        var loaded = serialize.load(serialize.dump(game))
        assert_equal(loaded.num_days, length)
        assert_equal(loaded.day, 2)


def test_a_high_score_entry_carries_its_game_length() raises:
    var scores = List[score.HighScore]()
    _ = score.insert_high_score(scores, score.HighScore("a", 500.0, 60, False, "", 60))
    _ = score.insert_high_score(scores, score.HighScore("b", 900.0, 15, False, "", 15))
    assert_equal(scores[0].name, "b")
    assert_equal(scores[0].num_days, 15)
    assert_equal(scores[1].num_days, 60)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
