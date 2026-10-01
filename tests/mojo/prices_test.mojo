# tests/mojo/prices_test.mojo — slice 4 parity: the price roster.
#
# Replays fixture 01 in full: newGame at seed 7 followed by ten generatePrices
# calls. Every step's roster, its insertion order, the previous-turn snapshot and
# the cheap/expensive event list are compared against the oracle.
#
# This is the first test that exercises the RNG draw order end to end. A single
# extra or missing draw anywhere in generatePrices desynchronises the stream and
# shows up as a wrong roster on the very next step, so the ten steps are a real
# check on the short-circuit in the expensive/cheap branch.

import fixtures
import harness
import record
import prices
import rules
import world
from std.testing import assert_equal, assert_true, TestSuite


def _fixture_records(name: String) raises -> List[record.Record]:
    var out = List[record.Record]()
    for line in fixtures.mjo_steps():
        var parsed = record.parse_record(String(line))
        if parsed.call == name:
            out.append(parsed^)
    return out^


def test_fixture_01_replays_step_by_step() raises:
    var records = _fixture_records("newGame")
    assert_true(len(records) > 0)
    # Fixture 01 is the first newGame in the corpus.
    ref first = records[0]
    var game = world.new_game(UInt32(7), 0, -1)
    harness.assert_state_matches(game, first.state)

    # The remaining steps of fixture 01 are generatePrices calls. They are the
    # records between the first newGame and the next fixture's newGame.
    var steps = _fixture_records("generatePrices")
    assert_equal(len(steps), 10)
    for i in range(len(steps)):
        var events = prices.generate_prices(game)
        harness.assert_price_event_list_match(events, steps[i].ret.pairs)
        harness.assert_state_matches(game, steps[i].state)


def _constant_script(value: Float64) -> List[Float64]:
    var script = List[Float64]()
    for _ in range(200):
        script.append(value)
    return script^


def test_every_roll_hitting_spikes_and_crashes_each_flagged_drug() raises:
    var game = world.new_game(UInt32(5), 0, -1)
    game.rng.set_script(_constant_script(0.0))
    var events = prices.generate_prices(game)
    var table = rules.drugs()
    var expected_events = 0
    for i in range(rules.NUM_DRUGS):
        if not game.has_price(i):
            continue
        ref drug = table[i]
        if drug.expensive:
            expected_events += 1
            assert_equal(game.price_value[i], drug.min_price * 5)
        elif drug.cheap:
            expected_events += 1
            assert_equal(game.price_value[i], drug.min_price // 10)
        else:
            assert_equal(game.price_value[i], drug.min_price)
    assert_true(expected_events > 0)
    assert_equal(len(events), expected_events)
    for event in events:
        if table[event.drug_index].expensive:
            assert_equal(event.kind, world.PRICE_EVENT_BUST)
        else:
            assert_equal(event.kind, world.PRICE_EVENT_CHEAP)


def test_no_roll_hitting_leaves_every_price_in_its_base_range() raises:
    var game = world.new_game(UInt32(5), 0, -1)
    game.rng.set_script(_constant_script(0.999))
    var events = prices.generate_prices(game)
    assert_equal(len(events), 0)
    var table = rules.drugs()
    for i in range(rules.NUM_DRUGS):
        if game.has_price(i):
            assert_true(game.price_value[i] >= table[i].min_price)
            assert_true(game.price_value[i] <= table[i].max_price)


def test_spike_events_fit_the_event_buffer() raises:
    assert_true(world.MAX_PRICE_EVENTS >= 8)


def test_roster_comes_out_in_drug_index_order() raises:
    # Prices are rolled per drug in table order, so the insertion order the
    # fixtures compare is ascending drug index.
    var game = world.new_game(UInt32(7), 0, -1)
    for i in range(1, game.price_count()):
        assert_true(Int(game.price_order[i]) > Int(game.price_order[i - 1]))


def test_prev_prices_track_the_previous_roster() raises:
    var game = world.new_game(UInt32(7), 0, -1)
    assert_equal(game.prev_price_count(), 0)
    var before = List[Int64]()
    for i in range(game.price_count()):
        before.append(game.price_value[Int(game.price_order[i])])
    _ = prices.generate_prices(game)
    assert_equal(game.prev_price_count(), len(before))
    for i in range(len(before)):
        assert_equal(game.prev_price_value[Int(game.prev_price_order[i])], before[i])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
