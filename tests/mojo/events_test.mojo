# tests/mojo/events_test.mojo — regression guard: cash-cost arrival events
# deduct cash (TASK-006.02).
#
# The parity corpus already pins these deductions end to end
# (tests/fixtures/04-arrival-events.jsonl), but the fixture asserts the whole
# post-step state, so a missing deduction is easy to miss in review. These
# tests isolate the deduction itself with a scripted Rng (the same mechanism
# the corpus uses for exact-branch steps) and assert the cash math directly:
#
#   mugged  — cash = floor(cash x pct), pct = randInt(80, 95) / 100, i.e. the
#             player keeps 80-95% and loses 5-20% (docs/gameplay.md:100).
#   flavor  — cash = max(0, cash - amt), amt = randInt(1, 10)
#             (docs/gameplay.md:105).
#
# The $0-cash mugging branch takes no second draw; its single-entry script
# raises if the code ever draws the pct it must not.

import events
import world
from std.testing import assert_equal, TestSuite


def test_mugged_deducts_5_to_20_percent_of_cash() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.cash = Float64(1000)
    var script = List[Float64]()
    script.append(0.05)  # roll 5 -> mugged
    script.append(0.5)   # randInt(80, 95) = 80 + floor(0.5 x 16) = 88
    game.rng.set_script(script)

    var event = events.roll_arrival_event(game)

    assert_equal(event.kind, events.ARRIVAL_MUGGED)
    assert_equal(event.amount, Int64(120))
    assert_equal(game.cash, Float64(880))


def test_mugged_with_zero_cash_takes_damage_and_no_second_draw() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.cash = Float64(0)
    var health = game.health
    var script = List[Float64]()
    script.append(0.05)  # roll 5 -> mugged; a stray pct draw would exhaust it
    game.rng.set_script(script)

    var event = events.roll_arrival_event(game)

    assert_equal(event.kind, events.ARRIVAL_MUGGED)
    assert_equal(game.cash, Float64(0))
    # damage = floor(health x 0.05); a fresh game starts at 100.
    assert_equal(game.health, health - 5)


def test_flavor_event_deducts_the_named_amount() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.cash = Float64(500)
    var script = List[Float64]()
    script.append(0.70)  # roll 70 -> flavor (60.5..75)
    script.append(0.5)   # randInt(1, 10) = 1 + floor(0.5 x 10) = 6
    game.rng.set_script(script)

    var event = events.roll_arrival_event(game)

    assert_equal(event.kind, events.ARRIVAL_FLAVOR)
    assert_equal(event.amount, Int64(6))
    assert_equal(game.cash, Float64(494))


def test_flavor_event_never_drives_cash_negative() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.cash = Float64(3)
    var script = List[Float64]()
    script.append(0.70)  # roll 70 -> flavor
    script.append(0.9)   # randInt(1, 10) = 1 + floor(0.9 x 10) = 10
    game.rng.set_script(script)

    var event = events.roll_arrival_event(game)

    assert_equal(event.kind, events.ARRIVAL_FLAVOR)
    assert_equal(event.amount, Int64(10))
    assert_equal(game.cash, Float64(0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
