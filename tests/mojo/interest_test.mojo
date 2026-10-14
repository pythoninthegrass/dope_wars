# tests/mojo/interest_test.mojo — Beermat's daily interest (docs/beermat-re.md, M-10).
#
# Bank interest follows the 2.1 rule `Round(bank * 0.05)` (docs/beermat-2.1-re.md, N-33):
# the rate is a double, so an exact .5 tie rounds up. Loan interest is covered in loans_test.mojo.

import interest
import rules
import world
import travel
from std.testing import assert_equal, TestSuite


def test_bank_interest_rounds_to_whole_dollars() raises:
    assert_equal(interest.bank_after_interest(5500), 5775)
    assert_equal(interest.bank_after_interest(1001), 1051)
    assert_equal(interest.bank_after_interest(1000), 1050)


def test_bank_interest_rounds_ties_up() raises:
    assert_equal(interest.bank_after_interest(10), 11)
    assert_equal(interest.bank_after_interest(30), 32)
    assert_equal(interest.bank_after_interest(50), 53)
    assert_equal(interest.bank_after_interest(70), 74)
    assert_equal(interest.bank_after_interest(90), 95)
    assert_equal(interest.bank_after_interest(110), 116)
    assert_equal(interest.bank_after_interest(190), 200)


def test_interest_skipped_at_zero_or_below() raises:
    assert_equal(interest.loan_after_interest(0, 15), 0)
    assert_equal(interest.loan_after_interest(-100, 15), -100)
    assert_equal(interest.bank_after_interest(0), 0)
    assert_equal(interest.bank_after_interest(-100), -100)


def test_travel_applies_interest() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.loan_balance[0] = 6655
    game.bank = 30.0
    var dest = 1 if game.location_index == 0 else 0
    _ = travel.travel(game, dest)
    assert_equal(game.loan_balance[0], 7653)
    assert_equal(game.bank, 32.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
