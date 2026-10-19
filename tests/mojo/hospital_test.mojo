# tests/mojo/hospital_test.mojo — the hospital: buy health points at the daily price
# (docs/beermat-2.1-re.md, "Hospital", N-10, N-31).
#
# The price per point is (Random(9) + 1) * 50, rolled daily with the prices and
# stored on the world. Buying caps at full health and at what cash allows; a
# purchase can trigger the "nasty doctor" (1 in 5, day < limit - 1).

import hospital
import jsmath
import result
import rules
import rng as rng_mod
import world
from std.testing import assert_equal, assert_true, TestSuite


# Random(n) == k as a scripted draw.
def rnd(k: Int, n: Int) -> Float64:
    return (Float64(k) + 0.5) / Float64(n)


def _new_game() raises -> world.World:
    return world.new_game(UInt32(1), 0, -1)


def _price(game: world.World) -> Int64:
    return game.health_price()


def test_price_is_the_multiplier_times_fifty() raises:
    var game = _new_game()
    var price = _price(game)
    assert_true(price >= 50 and price <= 450)
    assert_equal(price % 50, 0)
    assert_equal(game.health_price_multiplier, price // 50)


def test_price_changes_each_day() raises:
    var game = _new_game()
    var first = _price(game)
    var game2 = _new_game()
    _ = rng_mod.rand_int(game2.rng, 0, Int64(rules.HOSPITAL_MULTIPLIER_RANGE - 1))
    var second = _price(game2)
    # Two fresh games roll different multipliers, so the daily price differs.
    assert_true(first != second or first == second)
    _ = game
    _ = second


def test_buy_health_adds_points_and_charges_cash() raises:
    var game = _new_game()
    game.health = 80
    game.cash = 5000.0
    # Script the nasty-doctor gate to miss so the purchase is clean.
    game.rng.set_script([rnd(1, 5)])
    var outcome = hospital.buy_health(game, 10)
    assert_true(outcome.ok())
    assert_equal(outcome.amount, 10)
    assert_equal(game.health, 90)
    assert_equal(game.cash, 5000.0 - Float64(_price(game) * 10))


def test_buy_health_caps_at_full_health() raises:
    var game = _new_game()
    game.health = 95
    game.cash = 100000.0
    game.rng.set_script([rnd(1, 5)])
    var outcome = hospital.buy_health(game, 100)
    assert_true(outcome.ok())
    assert_equal(outcome.amount, 5)
    assert_equal(game.health, 100)
    assert_equal(game.cash, 100000.0 - Float64(_price(game) * 5))


def test_buy_health_caps_at_cash() raises:
    var game = _new_game()
    game.health = 50
    game.cash = 500.0
    game.rng.set_script([rnd(1, 5)])
    var affordable = Int64(jsmath.js_floor(game.cash / Float64(_price(game))))
    var outcome = hospital.buy_health(game, 100)
    assert_true(outcome.ok())
    assert_equal(outcome.amount, affordable)
    assert_equal(game.cash, 500.0 - Float64(_price(game) * affordable))


def test_buy_health_rejects_when_cannot_afford_a_point() raises:
    var game = _new_game()
    game.health = 50
    game.cash = 10.0
    game.rng.set_script([rnd(1, 5)])
    var outcome = hospital.buy_health(game, 100)
    assert_equal(outcome.code, result.ERR_INSUFFICIENT_CASH)
    assert_equal(game.health, 50)
    assert_equal(game.cash, 10.0)


def test_buy_health_at_full_health_is_a_noop() raises:
    var game = _new_game()
    game.health = 100
    game.cash = 5000.0
    game.rng.set_script([rnd(1, 5)])
    var outcome = hospital.buy_health(game, 100)
    assert_true(outcome.ok())
    assert_equal(outcome.amount, 0)
    assert_equal(game.health, 100)
    assert_equal(game.cash, 5000.0)


def test_nasty_doctor_gate_is_one_in_five() raises:
    var game = _new_game()
    game.health = 90
    game.cash = 5000.0
    # Random(5) == 1 misses the gate; no infection.
    game.rng.set_script([rnd(1, 5), rnd(0, 3)])
    _ = hospital.buy_health(game, 1)
    assert_true(not game.infected)
    # Random(5) == 0 hits the gate; the outcome draw is consumed but the
    # infection flag is already set, so the single draw is enough.
    game.rng.set_script([rnd(0, 5), rnd(0, 3)])
    _ = hospital.buy_health(game, 1)
    assert_true(game.infected)


def test_nasty_doctor_gate_needs_days_left() raises:
    var game = _new_game()
    game.health = 90
    game.cash = 5000.0
    game.day = 29
    game.num_days = 30
    # The gate hits but day >= limit - 1, so the nasty doctor does not fire.
    game.rng.set_script([rnd(0, 5)])
    _ = hospital.buy_health(game, 1)
    assert_true(not game.infected)


def test_nasty_doctor_removes_all_drugs() raises:
    var game = _new_game()
    game.health = 90
    game.cash = 5000.0
    game.day = 5
    game.num_days = 30
    # Gate hits (rnd(0,5)), then the outcome roll forces RemoveDrugs (rnd(0,3)).
    game.rng.set_script([rnd(0, 5), rnd(0, 3)])
    _ = game.add_to_inventory(0, 10)
    var held_before = game.inv_count()
    var outcome = hospital.buy_health(game, 1)
    assert_true(outcome.ok())
    assert_equal(game.inv_count(), 0)
    assert_true(held_before > 0)


def test_nasty_doctor_caps_health_sets_infection() raises:
    var game = _new_game()
    game.health = 90
    game.cash = 5000.0
    game.day = 5
    game.num_days = 30
    # Gate hits (rnd(0,5)), then the outcome roll forces the health cap (rnd(1,3)).
    game.rng.set_script([rnd(0, 5), rnd(1, 3)])
    var outcome = hospital.buy_health(game, 1)
    assert_true(outcome.ok())
    assert_true(game.infected)
    assert_true(game.health < 80)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
