# tests/mojo/prices_test.mojo — the price roster (Beermat 2.1 flat price model, N-34 and N-35).
#
# Scripted draws pin docs/beermat-2.1-re.md "Price roll": Random(9) first, then per
# drug in Beermat slot order a price (kept 1 time in 5 when yesterday had no event),
# a 1 in 8 absence, and the 1 in 40 spike or crash that needs an available drug
# with no event yesterday. The 1.2 engine's seeded golden was retired with the move
# to the 2.1 target (docs/parity-fixture-classification.md).

import prices
import rules
import world
from std.testing import assert_equal, assert_false, assert_true, TestSuite


# What one drug's draws look like in a scripted roll.
struct Plan(Copyable, Movable):
    var keep: Bool  # Random(5) == 0, drawn on every day after the first
    var fresh_after_keep: Bool  # yesterday had an event, so a keep hit still rolls fresh
    var price_draw: Float64  # the fresh price draw
    var absent: Bool
    var hit: Bool  # the spike or crash Random(40) == 0

    def __init__(
        out self,
        keep: Bool = False,
        fresh_after_keep: Bool = False,
        price_draw: Float64 = 0.0,
        absent: Bool = False,
        hit: Bool = False,
    ):
        self.keep = keep
        self.fresh_after_keep = fresh_after_keep
        self.price_draw = price_draw
        self.absent = absent
        self.hit = hit


def _plans(hit: Bool = False, absent: Bool = False) -> List[Plan]:
    var out = List[Plan]()
    for _ in range(rules.NUM_DRUGS):
        out.append(Plan(hit=hit, absent=absent))
    return out^


# The draw sequence generate_prices consumes, in Beermat slot order.
def _script(first_day: Bool, plans: List[Plan]) -> List[Float64]:
    var table = rules.drugs()
    var script = List[Float64]()
    script.append(0.0)  # Random(9), the hospital multiplier
    for slot in range(rules.NUM_DRUGS):
        var drug_index = rules.beermat_slot_drug_index(slot)
        ref plan = plans[slot]
        var rolls_fresh = first_day
        if not first_day:
            script.append(0.0 if plan.keep else 0.999)
            rolls_fresh = not plan.keep or plan.fresh_after_keep
        if rolls_fresh:
            script.append(plan.price_draw)
        script.append(0.0 if plan.absent else 0.999)
        if table[drug_index].expensive:
            script.append(0.0 if plan.hit else 0.999)
            if plan.hit and not plan.absent and not plan.fresh_after_keep and drug_index != rules.find_drug_index("specialk"):
                script.append(0.0)  # Random(2): bust
        if table[drug_index].cheap:
            script.append(0.0 if plan.hit else 0.999)
    return script^


# A day-1 world with no roll history, since new_game has already rolled once.
def _fresh_game(script: List[Float64]) raises -> world.World:
    var game = world.new_game(UInt32(5), 0, -1)
    for i in range(rules.NUM_DRUGS):
        game.last_price[i] = 0
        game.last_event[i] = 0
        game.seen_price[i] = 0
    game.rng.set_script(script)
    return game^


def test_the_roster_is_rolled_in_beermat_slot_order() raises:
    var game = _fresh_game(_script(True, _plans()))
    _ = prices.generate_prices(game)
    assert_equal(game.price_count(), rules.NUM_DRUGS)
    for slot in range(rules.NUM_DRUGS):
        assert_equal(Int(game.price_order[slot]), rules.beermat_slot_drug_index(slot))


def test_random_nine_is_drawn_before_any_price() raises:
    # A high first draw is the hospital multiplier; if it were taken as the first
    # price, acid would not come out at its minimum.
    var script = _script(True, _plans())
    script[0] = 0.999
    var game = _fresh_game(script)
    _ = prices.generate_prices(game)
    assert_equal(game.price_value[rules.find_drug_index("acid")], 1000)
    assert_equal(game.rng._script_pos, len(script))


def test_every_roll_hitting_spikes_and_crashes_each_flagged_drug() raises:
    var game = _fresh_game(_script(True, _plans(hit=True)))
    var events = prices.generate_prices(game)
    var table = rules.drugs()
    for i in range(rules.NUM_DRUGS):
        assert_true(game.has_price(i))
        ref drug = table[i]
        if drug.expensive:
            assert_equal(game.price_value[i], drug.min_price * 5)
        elif drug.cheap:
            assert_equal(game.price_value[i], drug.min_price // 10)
        else:
            assert_equal(game.price_value[i], drug.min_price)
        assert_equal(game.was_event_price(i), drug.expensive or drug.cheap)
    # Six spike drugs and five crash drugs.
    assert_equal(len(events), 11)
    for event in events:
        if event.drug_index == rules.find_drug_index("specialk"):
            assert_equal(event.kind, world.PRICE_EVENT_VET)
        elif table[event.drug_index].expensive:
            assert_equal(event.kind, world.PRICE_EVENT_BUST)
        else:
            assert_equal(event.kind, world.PRICE_EVENT_CHEAP)


def test_a_spike_draws_random_two_to_pick_the_news_except_for_special_k() raises:
    # Random(2) == 1 on a spike gives the Addicts text; Special K draws nothing.
    var table = rules.drugs()
    var script = _script(True, _plans(hit=True))
    var game = _fresh_game(script)
    # Flip the bust draw of the first spike drug in slot order (cocaine) to 1.
    var position = 1  # after Random(9)
    for slot in range(rules.NUM_DRUGS):
        var drug_index = rules.beermat_slot_drug_index(slot)
        position += 2  # price, availability
        if table[drug_index].expensive:
            position += 1  # the spike roll
            if drug_index == rules.find_drug_index("cocaine"):
                script[position] = 0.999
                break
            if drug_index != rules.find_drug_index("specialk"):
                position += 1
        if table[drug_index].cheap:
            position += 1
    game.rng.set_script(script)
    var events = prices.generate_prices(game)
    var kinds = List[Int]()
    for event in events:
        if event.drug_index == rules.find_drug_index("cocaine"):
            kinds.append(event.kind)
    assert_equal(len(kinds), 1)
    assert_equal(kinds[0], world.PRICE_EVENT_EXPENSIVE)


def test_no_roll_hitting_leaves_every_price_in_its_base_range() raises:
    var plans = _plans()
    for i in range(len(plans)):
        plans[i].price_draw = 0.999999
    var game = _fresh_game(_script(True, plans))
    var events = prices.generate_prices(game)
    assert_equal(len(events), 0)
    var table = rules.drugs()
    for i in range(rules.NUM_DRUGS):
        assert_true(game.has_price(i))
        assert_equal(game.price_value[i], table[i].max_price)


def test_every_drug_can_be_unavailable_at_once() raises:
    var game = _fresh_game(_script(True, _plans(hit=True, absent=True)))
    var events = prices.generate_prices(game)
    assert_equal(game.price_count(), 0)
    assert_equal(len(events), 0)


def test_absent_drug_still_consumes_its_event_rolls_but_never_fires_them() raises:
    var plans = _plans(hit=True)
    plans[0].absent = True  # slot 0 is acid
    plans[1].absent = True  # slot 1 is cocaine
    var script = _script(True, plans)
    var game = _fresh_game(script)
    var events = prices.generate_prices(game)
    assert_equal(game.rng._script_pos, len(script))
    assert_false(game.has_price(rules.find_drug_index("acid")))
    assert_false(game.has_price(rules.find_drug_index("cocaine")))
    for event in events:
        assert_true(event.drug_index != rules.find_drug_index("acid"))
        assert_true(event.drug_index != rules.find_drug_index("cocaine"))


def test_spike_events_fit_the_event_buffer() raises:
    assert_true(world.MAX_PRICE_EVENTS >= 11)


def test_a_price_is_kept_one_day_in_five() raises:
    var first = _fresh_game(_script(True, _plans()))
    _ = prices.generate_prices(first)
    var rolled = List[Int64]()
    for i in range(rules.NUM_DRUGS):
        rolled.append(first.price_value[i])
    var plans = _plans()
    for i in range(len(plans)):
        plans[i].keep = True
    var script = _script(False, plans)
    first.day = 2
    first.rng.set_script(script)
    _ = prices.generate_prices(first)
    # No price draws were consumed and every price is yesterday's.
    assert_equal(first.rng._script_pos, len(script))
    for i in range(rules.NUM_DRUGS):
        assert_equal(first.price_value[i], rolled[i])


def test_a_price_is_rolled_fresh_when_the_keep_draw_misses() raises:
    var game = _fresh_game(_script(True, _plans()))
    _ = prices.generate_prices(game)
    var plans = _plans()
    for i in range(len(plans)):
        plans[i].price_draw = 0.999999
    game.day = 2
    game.rng.set_script(_script(False, plans))
    _ = prices.generate_prices(game)
    var table = rules.drugs()
    for i in range(rules.NUM_DRUGS):
        assert_equal(game.price_value[i], table[i].max_price)


def test_a_price_is_not_kept_after_an_event_and_cannot_spike_or_crash_again() raises:
    var table = rules.drugs()
    var game = _fresh_game(_script(True, _plans(hit=True)))
    _ = prices.generate_prices(game)
    var plans = _plans(hit=True)
    for slot in range(len(plans)):
        ref flagged = table[rules.beermat_slot_drug_index(slot)]
        plans[slot].keep = True
        plans[slot].fresh_after_keep = flagged.expensive or flagged.cheap
        plans[slot].price_draw = 0.999999
    game.day = 2
    game.rng.set_script(_script(False, plans))
    var events = prices.generate_prices(game)
    assert_equal(len(events), 0)
    for i in range(rules.NUM_DRUGS):
        assert_false(game.was_event_price(i))
        if table[i].expensive or table[i].cheap:
            assert_equal(game.price_value[i], table[i].max_price)
        else:
            # Unflagged yesterday, so the keep draw held it at yesterday's minimum.
            assert_equal(game.price_value[i], table[i].min_price)


def test_an_unavailable_drug_keeps_its_price_for_the_next_roll() raises:
    var absent_plans = _plans()
    absent_plans[0].absent = True  # acid
    absent_plans[0].price_draw = 0.5
    var game = _fresh_game(_script(True, absent_plans))
    _ = prices.generate_prices(game)
    assert_false(game.has_price(rules.find_drug_index("acid")))
    var hidden = game.last_price[rules.find_drug_index("acid")]
    assert_true(hidden > 1000 and hidden < 4500)
    var plans = _plans()
    for i in range(len(plans)):
        plans[i].keep = True
    game.day = 2
    game.rng.set_script(_script(False, plans))
    _ = prices.generate_prices(game)
    assert_equal(game.price_value[rules.find_drug_index("acid")], hidden)


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


def test_the_first_day_has_no_direction() raises:
    var game = world.new_game(UInt32(7), 0, -1)
    for i in range(rules.NUM_DRUGS):
        assert_equal(Int(game.price_direction[i]), 0)


def test_direction_compares_with_the_previous_price() raises:
    var low = List[Plan]()
    for _ in range(rules.NUM_DRUGS):
        low.append(Plan())
    var game = _fresh_game(_script(True, low))
    _ = prices.generate_prices(game)
    var high = _plans()
    for i in range(len(high)):
        high[i].price_draw = 0.999999
    game.day = 2
    game.rng.set_script(_script(False, high))
    _ = prices.generate_prices(game)
    for i in range(rules.NUM_DRUGS):
        assert_equal(Int(game.price_direction[i]), 1)
    # Falling back to the minimum is down.
    game.day = 3
    game.rng.set_script(_script(False, low))
    _ = prices.generate_prices(game)
    for i in range(rules.NUM_DRUGS):
        assert_equal(Int(game.price_direction[i]), -1)
    # An equal price is no change.
    game.day = 4
    game.rng.set_script(_script(False, low))
    _ = prices.generate_prices(game)
    for i in range(rules.NUM_DRUGS):
        assert_equal(Int(game.price_direction[i]), 0)


def test_direction_is_blank_on_an_event_price() raises:
    var game = _fresh_game(_script(True, _plans()))
    _ = prices.generate_prices(game)
    game.day = 2
    game.rng.set_script(_script(False, _plans(hit=True)))
    _ = prices.generate_prices(game)
    var table = rules.drugs()
    for i in range(rules.NUM_DRUGS):
        if table[i].expensive or table[i].cheap:
            assert_equal(Int(game.price_direction[i]), 0)


def test_direction_looks_back_to_the_last_day_the_drug_was_available() raises:
    # Acid is rolled on day 1, absent on day 2 and back on day 3: the arrow compares day 3 with day 1.
    var day_one = _plans()
    day_one[0].price_draw = 0.0
    var game = _fresh_game(_script(True, day_one))
    _ = prices.generate_prices(game)
    var day_two = _plans()
    day_two[0].absent = True
    day_two[0].price_draw = 0.999999
    game.day = 2
    game.rng.set_script(_script(False, day_two))
    _ = prices.generate_prices(game)
    var day_three = _plans()
    day_three[0].price_draw = 0.5
    game.day = 3
    game.rng.set_script(_script(False, day_three))
    _ = prices.generate_prices(game)
    assert_equal(Int(game.price_direction[rules.find_drug_index("acid")]), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
