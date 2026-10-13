# tests/mojo/prices_test.mojo — the price roster.
#
# Scripted draws pin the rules that survive in Beermat 2.1: each drug's price
# range, the x5 spike on a spike drug, the divide-by-10 crash on a crash drug,
# and a drug that is absent still consuming its event rolls. The 1.2 engine's
# seeded ten-roll golden was retired with the move to the 2.1 target
# (docs/parity-fixture-classification.md): 2.1 draws a different stream.

import prices
import rules
import world
from std.testing import assert_equal, assert_false, assert_true, TestSuite


def _price_draws(absent: List[Int], spike: Bool, crash: Bool) -> List[Float64]:
    # The draw sequence generate_prices consumes: per drug, price, availability,
    # then the flagged spike and crash rolls (drawn even for an absent drug),
    # then the bust/addicts pick only for an available spike hit.
    var table = rules.drugs()
    var script = List[Float64]()
    for i in range(rules.NUM_DRUGS):
        var available = True
        for a in absent:
            if a == i:
                available = False
        script.append(0.0)
        script.append(0.999 if available else 0.0)
        if table[i].expensive:
            script.append(0.0 if spike else 0.999)
            if spike and available:
                script.append(0.0)
        if table[i].cheap:
            script.append(0.0 if crash else 0.999)
    return script^


def _all_drugs() -> List[Int]:
    var out = List[Int]()
    for i in range(rules.NUM_DRUGS):
        out.append(i)
    return out^


def test_every_roll_hitting_spikes_and_crashes_each_flagged_drug() raises:
    var game = world.new_game(UInt32(5), 0, -1)
    game.rng.set_script(_price_draws(List[Int](), True, True))
    var events = prices.generate_prices(game)
    var table = rules.drugs()
    var expected_events = 0
    for i in range(rules.NUM_DRUGS):
        assert_true(game.has_price(i))
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
    game.rng.set_script(_price_draws(List[Int](), False, False))
    var events = prices.generate_prices(game)
    assert_equal(len(events), 0)
    var table = rules.drugs()
    for i in range(rules.NUM_DRUGS):
        assert_true(game.has_price(i))
        assert_true(game.price_value[i] >= table[i].min_price)
        assert_true(game.price_value[i] <= table[i].max_price)


def test_every_drug_can_be_unavailable_at_once() raises:
    var game = world.new_game(UInt32(5), 0, -1)
    game.rng.set_script(_price_draws(_all_drugs(), True, True))
    var events = prices.generate_prices(game)
    assert_equal(game.price_count(), 0)
    assert_equal(len(events), 0)


def test_absent_drug_still_consumes_its_event_rolls_but_never_fires_them() raises:
    # Acid (crash) and cocaine (spike) absent; every other roll hits.
    var table = rules.drugs()
    var absent: List[Int] = [0, 1]
    var script = _price_draws(absent, True, True)
    var game = world.new_game(UInt32(5), 0, -1)
    game.rng.set_script(script)
    var events = prices.generate_prices(game)
    assert_equal(game.rng._script_pos, len(script))
    assert_false(game.has_price(0))
    assert_false(game.has_price(1))
    for event in events:
        assert_true(event.drug_index > 1)


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
