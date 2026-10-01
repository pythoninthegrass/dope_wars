# tests/mojo/interest_test.mojo — Beermat's daily interest (docs/beermat-re.md, M-10).
#
# The binary multiplies in x87 extended precision and rounds with FISTP, so the
# expectations here are the extended-precision results, not Float64 products.

import interest
import rules
import world
import travel
from std.testing import assert_equal, TestSuite


def test_debt_interest_rounds_ties_to_even() raises:
    assert_equal(interest.debt_after_interest(6655), 7320)
    assert_equal(interest.debt_after_interest(5), 6)
    assert_equal(interest.debt_after_interest(15), 16)
    assert_equal(interest.debt_after_interest(5500), 6050)
    assert_equal(interest.debt_after_interest(7320), 8052)


def test_bank_interest_rounds_to_whole_dollars() raises:
    assert_equal(interest.bank_after_interest(5500), 5775)
    assert_equal(interest.bank_after_interest(1001), 1051)
    assert_equal(interest.bank_after_interest(1000), 1050)


def test_bank_interest_matches_extended_product_on_ties() raises:
    assert_equal(interest.bank_after_interest(10), 10)
    assert_equal(interest.bank_after_interest(30), 31)
    assert_equal(interest.bank_after_interest(50), 52)
    assert_equal(interest.bank_after_interest(70), 74)
    assert_equal(interest.bank_after_interest(90), 94)
    assert_equal(interest.bank_after_interest(110), 115)
    assert_equal(interest.bank_after_interest(190), 199)


def test_interest_skipped_at_zero_or_below() raises:
    assert_equal(interest.debt_after_interest(0), 0)
    assert_equal(interest.debt_after_interest(-100), -100)
    assert_equal(interest.bank_after_interest(0), 0)
    assert_equal(interest.bank_after_interest(-100), -100)


def test_travel_applies_interest() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.debt = 6655.0
    game.bank = 30.0
    var dest = 1 if game.location_index == 0 else 0
    _ = travel.travel(game, dest)
    assert_equal(game.debt, 7320.0)
    assert_equal(game.bank, 31.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
