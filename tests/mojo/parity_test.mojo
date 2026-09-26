# tests/mojo/parity_test.mojo — the parity gate.
#
# Replays every oracle fixture against the Mojo core. Each fixture is one test,
# so a failure names the fixture that diverged. Fixture 09 is the 31-day
# full-game run, which is the end-to-end determinism check.

import replay
from std.testing import TestSuite


def test_01_price_generation() raises:
    replay.replay_fixture("01-price-generation")


def test_02_buy_sell_edges() raises:
    replay.replay_fixture("02-buy-sell-edges")


def test_03_travel_interest() raises:
    replay.replay_fixture("03-travel-interest")


def test_04_arrival_events() raises:
    replay.replay_fixture("04-arrival-events")


def test_05_dealers() raises:
    replay.replay_fixture("05-dealers")


def test_06_chase_combat() raises:
    replay.replay_fixture("06-chase-combat")


def test_07_finish_scoring() raises:
    replay.replay_fixture("07-finish-scoring")


def test_08_serialize_roundtrip() raises:
    replay.replay_fixture("08-serialize-roundtrip")


def test_09_full_run_31day() raises:
    replay.replay_fixture("09-full-run-31day")


def test_10_rolls_and_helpers() raises:
    replay.replay_fixture("10-rolls-and-helpers")


def test_11_finances() raises:
    replay.replay_fixture("11-finances")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
