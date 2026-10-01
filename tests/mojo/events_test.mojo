# tests/mojo/events_test.mojo — the arrival event's draw order and arithmetic.
#
# The parity corpus pins the event end to end (tests/fixtures/04-arrival-events.jsonl)
# but asserts whole post-step states. These tests isolate the Beermat rules
# (docs/beermat-re.md, M-06) with a scripted Rng, which raises if the code ever
# draws more than the script holds.

import events
import rules
import world
from std.testing import assert_equal, TestSuite


# Random(n) == k as a scripted draw.
def rnd(k: Int, n: Int) -> Float64:
    return (Float64(k) + 0.5) / Float64(n)


def new_game_with_market(ids: List[String]) raises -> world.World:
    var game = world.new_game(UInt32(1), 0, -1)
    for i in range(rules.NUM_DRUGS):
        game.prev_price_present[i] = 0
    for id in ids:
        game.prev_price_present[rules.find_drug_index(id)] = 1
    return game^


def test_miss_draws_once_and_does_nothing() raises:
    var game = new_game_with_market(["acid"])
    game.rng.set_script([rnd(1, 14)])
    assert_equal(events.roll_arrival_event(game).kind, events.ARRIVAL_NONE)


def test_wealth_cap_forces_the_mugging_with_a_single_draw() raises:
    var game = new_game_with_market(["acid"])
    game.cash = Float64(60000000)
    game.bank = Float64(40000000)
    game.rng.set_script([rnd(0, 2)])
    var event = events.roll_arrival_event(game)
    assert_equal(event.kind, events.ARRIVAL_MUGGED)
    assert_equal(event.amount, Int64(20000000))
    assert_equal(game.cash, Float64(40000000))


def test_exactly_the_cap_is_not_forced() raises:
    var game = new_game_with_market(["acid"])
    game.cash = Float64(99999999)
    game.rng.set_script([rnd(5, 14)])
    assert_equal(events.roll_arrival_event(game).kind, events.ARRIVAL_NONE)


def test_mugging_takes_a_third_or_a_quarter_of_cash() raises:
    var third = new_game_with_market(["acid"])
    third.cash = Float64(1000)
    third.rng.set_script([rnd(0, 14), rnd(1, 4), rnd(0, 2)])
    var event = events.roll_arrival_event(third)
    assert_equal(event.amount, Int64(333))
    assert_equal(third.cash, Float64(667))

    var quarter = new_game_with_market(["acid"])
    quarter.cash = Float64(1000)
    quarter.rng.set_script([rnd(0, 14), rnd(1, 4), rnd(1, 2)])
    _ = events.roll_arrival_event(quarter)
    assert_equal(quarter.cash, Float64(750))


def test_mugging_with_no_cash_leaves_health_alone() raises:
    var game = new_game_with_market(["acid"])
    game.cash = Float64(0)
    game.rng.set_script([rnd(0, 14), rnd(1, 4), rnd(0, 2)])
    var event = events.roll_arrival_event(game)
    assert_equal(event.kind, events.ARRIVAL_MUGGED)
    assert_equal(game.health, Int64(100))


def test_found_drugs_redraws_absent_slots_and_dilutes_the_average() raises:
    var game = new_game_with_market(["cocaine", "acid"])
    var cocaine = rules.find_drug_index("cocaine")
    game.set_inventory(cocaine, 10, 100.0)
    # slot 2 is hashish (absent), slot 1 is cocaine
    game.rng.set_script([rnd(0, 14), rnd(0, 4), rnd(2, 11), rnd(1, 11), rnd(3, 7)])
    var event = events.roll_arrival_event(game)
    assert_equal(event.kind, events.ARRIVAL_FOUND_DRUGS)
    assert_equal(event.drug_index, cocaine)
    assert_equal(event.qty, Int64(5))
    assert_equal(game.inv_qty_of(cocaine), Int64(15))
    assert_equal(game.inv_avg_price_of(cocaine), Float64(66))


def test_found_quantity_is_capped_at_the_free_space() raises:
    var game = new_game_with_market(["acid"])
    game.set_inventory(rules.find_drug_index("crack"), 97, 0.0)
    game.rng.set_script([rnd(0, 14), rnd(0, 4), rnd(0, 11), rnd(6, 7)])
    assert_equal(events.roll_arrival_event(game).qty, Int64(3))


def test_full_coat_skips_both_gifts_before_any_drug_draw() raises:
    for outcome in range(0, 4, 2):
        var game = new_game_with_market(["acid"])
        game.set_inventory(rules.find_drug_index("crack"), 100, 0.0)
        game.rng.set_script([rnd(0, 14), rnd(outcome, 4)])
        assert_equal(events.roll_arrival_event(game).kind, events.ARRIVAL_NONE)


def test_weed_slot_is_never_eligible_and_an_empty_pool_draws_nothing() raises:
    var weed_only = new_game_with_market(["weed"])
    weed_only.rng.set_script([rnd(0, 14), rnd(0, 4)])
    assert_equal(events.roll_arrival_event(weed_only).kind, events.ARRIVAL_NONE)

    var empty = new_game_with_market([])
    empty.rng.set_script([rnd(0, 14), rnd(2, 4)])
    assert_equal(events.roll_arrival_event(empty).kind, events.ARRIVAL_NONE)


def test_friend_gives_units_of_the_drug() raises:
    var game = new_game_with_market(["speed", "acid"])
    var speed = rules.find_drug_index("speed")
    game.set_inventory(speed, 4, 90.0)
    game.rng.set_script([rnd(0, 14), rnd(2, 4), rnd(10, 11), rnd(4, 7)])
    var event = events.roll_arrival_event(game)
    assert_equal(event.kind, events.ARRIVAL_FREE_DRUGS)
    assert_equal(event.qty, Int64(6))
    assert_equal(game.inv_qty_of(speed), Int64(10))
    assert_equal(game.inv_avg_price_of(speed), Float64(36))


def test_police_dogs_with_an_empty_coat_only_chase() raises:
    var game = new_game_with_market(["acid"])
    game.rng.set_script([rnd(0, 14), rnd(3, 4), rnd(2, 4)])
    var event = events.roll_arrival_event(game)
    assert_equal(event.kind, events.ARRIVAL_DOG_CHASE)
    assert_equal(event.blocks, Int64(4))
    assert_equal(event.qty, Int64(0))


def test_police_dogs_drop_up_to_ten_of_a_held_drug() raises:
    var game = new_game_with_market(["acid"])
    var heroin = rules.find_drug_index("heroin")
    game.set_inventory(rules.find_drug_index("acid"), 5, 0.0)
    game.set_inventory(heroin, 30, 0.0)
    # slot 1 (cocaine) is not held, slot 3 (heroin) is
    game.rng.set_script([rnd(0, 14), rnd(3, 4), rnd(1, 12), rnd(3, 12), rnd(2, 4), rnd(14, 30), rnd(0, 4)])
    var event = events.roll_arrival_event(game)
    assert_equal(event.drug_index, heroin)
    assert_equal(event.qty, Int64(10))
    assert_equal(event.blocks, Int64(2))
    assert_equal(game.inv_qty_of(heroin), Int64(20))


def test_police_dogs_keep_the_drugs_on_a_low_roll() raises:
    var game = new_game_with_market(["acid"])
    var acid = rules.find_drug_index("acid")
    game.set_inventory(acid, 5, 0.0)
    game.rng.set_script([rnd(0, 14), rnd(3, 4), rnd(0, 12), rnd(1, 4), rnd(1, 4)])
    var event = events.roll_arrival_event(game)
    assert_equal(event.qty, Int64(0))
    assert_equal(event.blocks, Int64(3))
    assert_equal(game.inv_qty_of(acid), Int64(5))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
