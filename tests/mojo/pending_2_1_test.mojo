# tests/mojo/pending_2_1_test.mojo — Beermat 2.1 rules the core does not implement yet.
#
# Each test states the 2.1 behaviour from docs/beermat-2.1-re.md against the
# entry point that exists today, so it fails on the 1.2 code and passes once the
# rule lands. They are skipped in main() until then; the slice that implements a
# rule removes its skip line, and the test must pass. The N-xx ID names the rule.
# Rules with no entry point yet (loans, weapons, game length, the 13-drug roster's
# price roll) get their tests with the API their slice adds.

import combat
import dealers
import events
import interest
import rules
import score
import world
from std.testing import assert_equal, assert_true, TestSuite


# Random(n) == k as a scripted draw.
def rnd(k: Int, n: Int) -> Float64:
    return (Float64(k) + 0.5) / Float64(n)


# N-33: bank interest is Round(bank * 0.05) and an exact .5 tie rounds up.
def test_pending_n33_bank_interest_ties_round_up() raises:
    assert_equal(interest.bank_after_interest(1050), 1103)
    assert_equal(interest.bank_after_interest(30), 32)
    assert_equal(interest.bank_after_interest(50), 53)
    assert_equal(interest.bank_after_interest(70), 74)


# N-22: a chase starts on Random(8) == 0, not Random(6) == 0.
def test_pending_n22_chase_starts_one_in_eight() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.rng.set_script([rnd(0, 8)])
    assert_true(combat.should_start_chase(game))
    game.rng.set_script([0.15])
    assert_true(not combat.should_start_chase(game))


# N-23: deputies are Random(7) + 2, so 2 to 8.
def test_pending_n23_deputies_range_two_to_eight() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.rng.set_script([0.0])
    assert_equal(combat.start_chase(game).deputies, 2)
    game.rng.set_script([0.999999])
    assert_equal(combat.start_chase(game).deputies, 8)


# N-24: Run escapes on Random(10) < 2; otherwise Random(3) picks the cop's shot.
def test_pending_n24_run_escapes_two_in_ten() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.rng.set_script([rnd(1, 10)])
    assert_true(combat.run_from_chase(game).escaped)
    game.rng.set_script([rnd(2, 10), rnd(0, 3)])
    assert_true(not combat.run_from_chase(game).escaped)


# N-28: the coat dealer is one draw, Random(15) == 0, with no gun-dealer split.
def test_pending_n28_coat_dealer_one_in_fifteen() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.rng.set_script([rnd(0, 15)])
    assert_equal(dealers.roll_dealer_visit(game), dealers.DEALER_COAT)
    game.rng.set_script([0.07])
    assert_equal(dealers.roll_dealer_visit(game), dealers.DEALER_NONE)


# 2.1 removed the wealth cap: a rich player gets no forced mugging.
def test_pending_wealth_cap_removed() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.cash = Float64(60000000)
    game.bank = Float64(40000000)
    game.rng.set_script([rnd(1, 13)])
    assert_equal(events.roll_arrival_event(game).kind, events.ARRIVAL_NONE)


# N-21: a mugging costs Random(10) + 1 health, then cash div (Random(2) + 3).
def test_pending_n21_mugging_costs_health() raises:
    var game = world.new_game(UInt32(1), 0, -1)
    game.cash = Float64(1000)
    game.rng.set_script([rnd(0, 13), rnd(1, 2), rnd(0, 3), rnd(4, 10), rnd(1, 2)])
    var event = events.roll_arrival_event(game)
    assert_equal(event.kind, events.ARRIVAL_MUGGED)
    assert_equal(game.health, 95)
    assert_equal(game.cash, Float64(750))


# N-19: the high score list holds 30 entries.
def test_pending_n19_high_score_list_holds_thirty() raises:
    var scores = List[score.HighScore]()
    for i in range(31):
        _ = score.insert_high_score(
            scores, score.HighScore("p" + String(i), Float64(i + 1), 30, False, "2026-01-01")
        )
    assert_equal(len(scores), 30)


# N-34: the roster has 13 drugs (MDA, Mushrooms and Special K replace and extend 1.2's 12).
def test_pending_n34_thirteen_drug_roster() raises:
    assert_equal(rules.NUM_DRUGS, 13)


def main() raises:
    var suite = TestSuite.discover_tests[__functions_in_module()]()
    suite.skip[test_pending_n22_chase_starts_one_in_eight]()
    suite.skip[test_pending_n23_deputies_range_two_to_eight]()
    suite.skip[test_pending_n24_run_escapes_two_in_ten]()
    suite.skip[test_pending_n28_coat_dealer_one_in_fifteen]()
    suite.skip[test_pending_wealth_cap_removed]()
    suite.skip[test_pending_n21_mugging_costs_health]()
    suite.skip[test_pending_n19_high_score_list_holds_thirty]()
    suite.skip[test_pending_n34_thirteen_drug_roster]()
    suite^.run()
