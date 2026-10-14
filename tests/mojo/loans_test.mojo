# tests/mojo/loans_test.mojo — loan sharks: the loan list, borrowing, repaying, daily interest and
# the jail release roll (docs/beermat-2.1-re.md, "Loan sharks", N-06, N-07, N-09, N-30).

import interest
import loans
import result
import score
import sharks
import travel
import world
from std.testing import assert_equal, assert_true, TestSuite


# Random(n) == k as a scripted draw.
def rnd(k: Int, n: Int) -> Float64:
    return (Float64(k) + 0.5) / Float64(n)


def _new_game() raises -> world.World:
    return world.new_game(UInt32(1), 0, -1)


def _release_all(mut game: world.World):
    for i in range(sharks.NUM_SHARKS):
        game.shark_released[i] = 1


def test_shark_table_matches_findings() raises:
    var harry = sharks.shark(0)
    assert_equal(harry.name, "Honest Harry")
    assert_equal(harry.rate, 15)
    assert_equal(harry.duration, 10)
    assert_equal(harry.multiplier, 10)
    assert_equal(harry.bruisers, 1)
    assert_true(not harry.female)
    var bertha = sharks.shark(3)
    assert_equal(bertha.name, "Bulbous Bertha")
    assert_equal(bertha.rate, 30)
    assert_equal(bertha.duration, 1)
    assert_equal(bertha.multiplier, 50)
    assert_true(bertha.female)
    var mickey = sharks.shark(4)
    assert_equal(mickey.rate, 25)
    assert_equal(mickey.duration, 5)
    assert_equal(mickey.multiplier, 100)
    assert_equal(sharks.shark(1).rate, 10)
    assert_equal(sharks.shark(2).duration, 7)


def test_new_game_opens_with_the_starter_loan() raises:
    var game = _new_game()
    assert_equal(game.loan_count, 1)
    assert_equal(Int(game.loan_shark[0]), 0)
    assert_equal(game.loan_balance[0], 5500)
    assert_equal(game.loan_days_left[0], 10)
    assert_equal(game.total_debt(), 5500)
    assert_equal(Int(game.shark_released[0]), 1)
    for i in range(1, sharks.NUM_SHARKS):
        assert_equal(Int(game.shark_released[i]), 0)


def test_daily_interest_follows_the_observed_chain() raises:
    var chain = [5500, 6325, 7274, 8365, 9620, 11063, 12722, 14630, 16824, 19348, 22250, 25587, 29425, 33839, 38915, 44752]
    var game = _new_game()
    for day in range(len(chain)):
        assert_equal(game.loan_balance[0], Int64(chain[day]))
        assert_equal(game.loan_days_left[0], Int64(10 - day))
        loans.apply_daily_interest(game)


def test_interest_ties_follow_the_double_rate() raises:
    # 22,250 * 1.15 is 25,587.5 and rate / 100.0 sits a hair below 0.15, so the tie goes down.
    assert_equal(interest.loan_after_interest(22250, 15), 25587)
    # 0.10 sits a hair above, so the tie goes up.
    assert_equal(interest.loan_after_interest(5, 10), 6)
    # 0.25 is exact, so the tie rounds to even.
    assert_equal(interest.loan_after_interest(2, 25), 2)
    assert_equal(interest.loan_after_interest(6, 25), 8)


def test_travel_compounds_every_loan_and_counts_down() raises:
    var game = _new_game()
    game.shark_released[1] = 1
    assert_true(loans.borrow(game, 1, 1000).ok())
    var dest = 1 if game.location_index == 0 else 0
    _ = travel.travel(game, dest)
    assert_equal(game.loan_balance[0], 6325)
    assert_equal(game.loan_days_left[0], 9)
    assert_equal(game.loan_balance[1], 1100)
    assert_equal(game.loan_days_left[1], 14)
    assert_equal(game.total_debt(), 7425)


def test_borrow_adds_cash_and_appends_a_loan() raises:
    var game = _new_game()
    game.shark_released[1] = 1
    var outcome = loans.borrow(game, 1, 5000)
    assert_true(outcome.ok())
    assert_equal(game.cash, 7000.0)
    assert_equal(game.loan_count, 2)
    assert_equal(Int(game.loan_shark[1]), 1)
    assert_equal(game.loan_balance[1], 5000)
    assert_equal(game.loan_days_left[1], 15)
    assert_equal(game.total_debt(), 10500)


def test_borrow_limit_is_the_multiplier_times_cash_plus_bank() raises:
    var game = _new_game()
    game.bank = 500.0
    game.shark_released[1] = 1
    assert_equal(loans.borrow_limit(game, 1), 50000)
    assert_equal(loans.borrow(game, 1, 50001).code, result.ERR_INVALID_ARGUMENT)
    assert_equal(game.loan_count, 1)
    assert_equal(game.cash, 2000.0)
    assert_true(loans.borrow(game, 1, 50000).ok())


def test_borrow_rejects_zero_negative_and_unknown() raises:
    var game = _new_game()
    game.shark_released[1] = 1
    assert_equal(loans.borrow(game, 1, 0).code, result.ERR_INVALID_ARGUMENT)
    assert_equal(loans.borrow(game, 1, -5).code, result.ERR_INVALID_ARGUMENT)
    assert_equal(loans.borrow(game, 5, 100).code, result.ERR_INVALID_ARGUMENT)
    assert_equal(loans.borrow(game, -1, 100).code, result.ERR_INVALID_ARGUMENT)
    assert_equal(game.loan_count, 1)


def test_borrow_needs_a_released_shark_who_is_not_owed() raises:
    var game = _new_game()
    assert_equal(loans.borrow(game, 0, 100).code, result.ERR_NOT_OFFERED)
    assert_equal(loans.borrow(game, 2, 100).code, result.ERR_NOT_OFFERED)
    assert_equal(game.loan_count, 1)


def test_total_debt_is_capped_at_one_million() raises:
    var game = _new_game()
    _release_all(game)
    game.cash = 1000000.0
    assert_equal(loans.borrow_limit(game, 4), 994500)
    assert_equal(loans.borrow(game, 4, 994501).code, result.ERR_INVALID_ARGUMENT)
    assert_true(loans.borrow(game, 4, 994500).ok())
    assert_equal(game.total_debt(), 1000000)
    assert_equal(loans.borrow_limit(game, 3), 0)
    assert_equal(loans.borrow(game, 3, 1).code, result.ERR_INVALID_ARGUMENT)


def test_interest_may_push_debt_past_the_cap() raises:
    var game = _new_game()
    game.loan_balance[0] = 990000
    loans.apply_daily_interest(game)
    assert_equal(game.total_debt(), 1138500)
    assert_equal(loans.borrow_limit(game, 0), 0)


def test_offers_are_released_sharks_not_owed() raises:
    var game = _new_game()
    assert_true(not loans.is_offered(game, 0))
    assert_true(not loans.is_offered(game, 1))
    game.shark_released[1] = 1
    assert_true(loans.is_offered(game, 1))
    assert_true(loans.borrow(game, 1, 100).ok())
    assert_true(not loans.is_offered(game, 1))
    assert_true(loans.repay(game, 1).ok())
    assert_true(loans.is_offered(game, 1))


def test_early_payoff_is_balance_plus_30_percent_of_remaining_interest() raises:
    assert_equal(interest.early_payoff(6325, 15, 9), 11103)
    assert_equal(interest.early_payoff(6325, 15, 0), 6325)
    assert_equal(interest.early_payoff(6325, 15, -2), 6325)


def test_repay_pays_the_early_payoff_and_removes_the_loan() raises:
    var game = _new_game()
    loans.apply_daily_interest(game)
    game.cash = 20000.0
    var outcome = loans.repay(game, 0)
    assert_true(outcome.ok())
    assert_equal(outcome.amount, 11103)
    assert_equal(game.cash, 8897.0)
    assert_equal(game.loan_count, 0)
    assert_equal(game.total_debt(), 0)


def test_repay_of_a_due_loan_costs_the_balance() raises:
    var game = _new_game()
    game.loan_days_left[0] = 0
    game.cash = 6000.0
    var outcome = loans.repay(game, 0)
    assert_true(outcome.ok())
    assert_equal(outcome.amount, 5500)
    assert_equal(game.cash, 500.0)


def test_repay_without_the_cash_changes_nothing() raises:
    var game = _new_game()
    loans.apply_daily_interest(game)
    game.cash = 11102.0
    assert_equal(loans.repay(game, 0).code, result.ERR_INSUFFICIENT_CASH)
    assert_equal(game.cash, 11102.0)
    assert_equal(game.loan_count, 1)
    assert_equal(game.loan_balance[0], 6325)


def test_repay_needs_a_loan_from_that_shark() raises:
    var game = _new_game()
    assert_equal(loans.repay(game, 1).code, result.ERR_NO_SUCH_LOAN)
    assert_equal(loans.repay(game, 9).code, result.ERR_INVALID_ARGUMENT)


def test_repay_keeps_the_order_of_the_other_loans() raises:
    var game = _new_game()
    game.shark_released[1] = 1
    game.shark_released[2] = 1
    assert_true(loans.borrow(game, 2, 100).ok())
    assert_true(loans.borrow(game, 1, 100).ok())
    game.cash = 100000.0
    assert_true(loans.repay(game, 2).ok())
    assert_equal(game.loan_count, 2)
    assert_equal(Int(game.loan_shark[0]), 0)
    assert_equal(Int(game.loan_shark[1]), 1)
    assert_equal(game.loan_balance[1], 100)


def test_finish_scores_cash_plus_bank_minus_every_loan() raises:
    var game = _new_game()
    game.shark_released[1] = 1
    assert_true(loans.borrow(game, 1, 4500).ok())
    game.cash = 1000.0
    game.bank = 500.0
    assert_equal(score.finish(game).score, 1500.0 - 10000.0)


def test_release_roll_misses_on_four_or_more_in_seven() raises:
    var game = _new_game()
    game.rng.set_script([rnd(3, 7)])
    assert_equal(loans.roll_release(game), -1)
    assert_equal(Int(game.shark_released[1]), 0)


def test_release_roll_redraws_until_an_unreleased_shark_comes_up() raises:
    var game = _new_game()
    game.rng.set_script([rnd(2, 7), rnd(0, 5), rnd(3, 5)])
    assert_equal(loans.roll_release(game), 3)
    assert_equal(Int(game.shark_released[3]), 1)
    assert_equal(Int(game.shark_released[0]), 1)


def test_release_roll_stops_once_every_shark_is_out() raises:
    var game = _new_game()
    _release_all(game)
    game.rng.set_script([rnd(0, 7)])
    assert_equal(loans.roll_release(game), -1)
    game.rng.set_script([])
    var before = game.rng.get_state()
    assert_equal(loans.roll_release(game), -1)
    assert_equal(game.rng.get_state(), before)


def test_release_roll_is_deterministic_for_a_seed() raises:
    var a = world.new_game(UInt32(77), 0, -1)
    var b = world.new_game(UInt32(77), 0, -1)
    for _ in range(40):
        assert_equal(loans.roll_release(a), loans.roll_release(b))
    for i in range(sharks.NUM_SHARKS):
        assert_equal(Int(a.shark_released[i]), Int(b.shark_released[i]))
    assert_equal(a.rng.get_state(), b.rng.get_state())


def test_visit_level_is_days_past_due_plus_bruisers_minus_one() raises:
    assert_equal(loans.visit_level(0, 1), 0)
    assert_equal(loans.visit_level(-1, 1), 1)
    assert_equal(loans.visit_level(-3, 1), 3)
    assert_equal(loans.visit_level(-4, 1), 4)
    assert_equal(loans.visit_level(0, 4), 3)
    assert_equal(loans.visit_level(-1, 4), 4)


def test_visit_level_never_goes_below_zero() raises:
    assert_equal(loans.visit_level(0, 0), 0)
    assert_equal(loans.visit_level(5, 1), 5)


def test_only_loans_at_or_past_their_due_day_get_a_visit() raises:
    var game = _new_game()
    _release_all(game)
    game.add_loan(2, 1000, 3)
    game.add_loan(3, 2000, 0)
    game.add_loan(4, 3000, -2)
    game.loan_days_left[0] = 1
    var due = loans.overdue_sharks(game)
    assert_equal(len(due), 2)
    assert_equal(due[0], 3)
    assert_equal(due[1], 4)


def test_loans_with_one_day_left_are_announced_for_tomorrow() raises:
    var game = _new_game()
    _release_all(game)
    game.add_loan(2, 1000, 1)
    game.add_loan(3, 2000, 0)
    game.loan_days_left[0] = 1
    var soon = loans.due_tomorrow_sharks(game)
    assert_equal(len(soon), 2)
    assert_equal(soon[0], 0)
    assert_equal(soon[1], 2)


def test_a_visit_below_level_four_draws_nothing_and_costs_nothing() raises:
    var game = _new_game()
    game.loan_days_left[0] = -3
    game.rng.set_script([])
    var before = game.rng.get_state()
    var outcome = loans.visit(game, 0)
    assert_equal(outcome.level, 3)
    assert_equal(outcome.damage, 0)
    assert_equal(outcome.message, 0)
    assert_equal(outcome.owed, 5500)
    assert_equal(game.health, 100)
    assert_equal(game.rng.get_state(), before)


def test_a_level_four_visit_beats_for_fifteen_to_thirty_then_picks_a_message() raises:
    var game = _new_game()
    game.loan_days_left[0] = -4
    game.rng.set_script([rnd(6, 16), rnd(2, 3)])
    var outcome = loans.visit(game, 0)
    assert_equal(outcome.level, 4)
    assert_equal(outcome.damage, 21)
    assert_equal(outcome.message, 3)
    assert_equal(game.health, 79)
    assert_true(not outcome.dead)
    assert_true(not game.dead)


def test_the_beating_range_runs_from_fifteen_to_thirty() raises:
    var low = _new_game()
    low.loan_days_left[0] = -4
    low.rng.set_script([rnd(0, 16), rnd(0, 3)])
    assert_equal(loans.visit(low, 0).damage, 15)
    var high = _new_game()
    high.loan_days_left[0] = -4
    high.rng.set_script([rnd(15, 16), rnd(1, 3)])
    var outcome = loans.visit(high, 0)
    assert_equal(outcome.damage, 30)
    assert_equal(outcome.message, 2)


def test_a_killing_beating_caps_at_health_and_skips_the_message_draw() raises:
    var game = _new_game()
    game.health = 20
    game.loan_days_left[0] = -4
    game.rng.set_script([rnd(10, 16)])
    var outcome = loans.visit(game, 0)
    assert_equal(outcome.damage, 20)
    assert_equal(outcome.message, 1)
    assert_equal(game.health, 0)
    assert_true(outcome.dead)
    assert_true(game.dead)


def test_a_damage_roll_equal_to_remaining_health_also_kills_without_a_message_draw() raises:
    var game = _new_game()
    game.health = 25
    game.loan_days_left[0] = -4
    game.rng.set_script([rnd(10, 16)])
    var outcome = loans.visit(game, 0)
    assert_equal(outcome.damage, 25)
    assert_equal(outcome.message, 1)
    assert_true(game.dead)


def test_a_bruiser_heavy_shark_beats_from_the_first_day_past_due() raises:
    var game = _new_game()
    _release_all(game)
    game.add_loan(4, 5000, -1)
    game.rng.set_script([rnd(0, 16), rnd(1, 3)])
    var outcome = loans.visit(game, 4)
    assert_equal(outcome.level, 4)
    assert_equal(outcome.damage, 15)
    assert_equal(outcome.message, 2)


def test_visiting_a_shark_that_is_owed_nothing_is_refused() raises:
    var game = _new_game()
    var outcome = loans.visit(game, 3)
    assert_equal(outcome.level, -1)
    assert_equal(game.health, 100)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
