# tests/mojo/harness.mojo — compare a Mojo World against an oracle snapshot.
#
# The oracle records a full state snapshot after every step, and the JS runner
# compares it with JSON.stringify, which is order-sensitive. So this compares
# every field, and compares the ordered maps (prices, prevPrices, inventory) in
# the oracle's own key order rather than by drug index.
#
# The comparison is deliberately total: a field the oracle records but this does
# not check would be a silent hole in the parity gate. The generator's closed
# allow-list is what keeps the oracle's field set from growing unnoticed; this
# file is what keeps the Mojo side honest about every field it does record.

import record
import rules
import world
from std.testing import assert_equal, assert_true


def _first_segments(ref pairs: List[record.Pair]) raises -> List[String]:
    # Distinct leading path segments, in document order. For inventory children
    # ("speed.qty", "speed.avgPrice", "weed.qty") this yields ["speed", "weed"].
    var keys = List[String]()
    for pair in pairs:
        var parts = pair.path.split(".", maxsplit=1)
        var key = String(parts[0])
        var seen = False
        for existing in keys:
            if existing == key:
                seen = True
        if not seen:
            keys.append(key)
    return keys^


def assert_prices_match(ref game: world.World, ref expected: record.Group) raises:
    var children = expected.children("prices")
    assert_equal(game.price_count(), len(children))
    for i in range(len(children)):
        var drug_index = rules.find_drug_index(children[i].path)
        assert_true(drug_index >= 0)
        assert_equal(Int(game.price_order[i]), drug_index)
        assert_equal(game.price_value[drug_index], children[i].as_int())


def assert_prev_prices_match(ref game: world.World, ref expected: record.Group) raises:
    var children = expected.children("prevPrices")
    assert_equal(game.prev_price_count(), len(children))
    for i in range(len(children)):
        var drug_index = rules.find_drug_index(children[i].path)
        assert_true(drug_index >= 0)
        assert_equal(Int(game.prev_price_order[i]), drug_index)
        assert_equal(game.prev_price_value[drug_index], children[i].as_int())


def assert_inventory_match(ref game: world.World, ref expected: record.Group) raises:
    var children = expected.children("inventory")
    var keys = _first_segments(children)
    assert_equal(game.inv_count(), len(keys))
    for i in range(len(keys)):
        var drug_index = rules.find_drug_index(keys[i])
        assert_true(drug_index >= 0)
        assert_equal(Int(game.inv_order[i]), drug_index)
        assert_equal(game.inv_qty[drug_index], expected.int_at("inventory." + keys[i] + ".qty"))
        assert_equal(
            game.inv_avg_price[drug_index],
            expected.float_at("inventory." + keys[i] + ".avgPrice"),
        )


def assert_price_event_list_match(
    ref events: List[world.PriceEvent], ref pairs: List[record.Pair]
) raises:
    # Works for both shapes the oracle uses: a state snapshot's priceEvents
    # (paths "0.type", "0.drug") and a generatePrices return value, which is a
    # bare array with the same paths.
    var keys = _first_segments(pairs)
    assert_equal(len(events), len(keys))
    for i in range(len(keys)):
        var kind = _string_in(pairs, keys[i] + ".type")
        var drug = _string_in(pairs, keys[i] + ".drug")
        var expected_kind = world.PRICE_EVENT_CHEAP
        if kind == "expensive":
            expected_kind = world.PRICE_EVENT_EXPENSIVE
        assert_equal(events[i].kind, expected_kind)
        assert_equal(events[i].drug_index, rules.find_drug_index(drug))


def _string_in(ref pairs: List[record.Pair], path: String) raises -> String:
    for pair in pairs:
        if pair.path == path:
            return pair.lex
    raise Error("oracle record is missing " + path)


def assert_price_events_match(ref game: world.World, ref expected: record.Group) raises:
    assert_price_event_list_match(game.price_events, expected.children("priceEvents"))


def assert_state_matches(ref game: world.World, ref expected: record.Group) raises:
    assert_equal(Int64(game.seed), expected.int_at("seed"))
    assert_equal(game.day, expected.int_at("day"))
    assert_equal(game.num_days, expected.int_at("numDays"))
    assert_equal(game.cash, expected.float_at("cash"))
    assert_equal(game.debt, expected.float_at("debt"))
    assert_equal(game.bank, expected.float_at("bank"))
    assert_equal(game.health, expected.int_at("health"))
    assert_equal(game.coat_capacity, expected.int_at("coatCapacity"))
    assert_equal(game.guns, expected.int_at("guns"))
    assert_equal(game.dead, expected.bool_at("dead"))
    assert_equal(game.last_day_warned, expected.bool_at("lastDayWarned"))
    assert_equal(
        game.location_index,
        rules.find_location_index(expected.string_at("location")),
    )
    assert_equal(Int64(game.rng.get_state()), expected.int_at("rngState"))
    assert_prices_match(game, expected)
    assert_prev_prices_match(game, expected)
    assert_inventory_match(game, expected)
    assert_price_events_match(game, expected)
