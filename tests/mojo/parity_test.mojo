# tests/mojo/parity_test.mojo — the parity gate.
#
# Replays every oracle fixture against the Mojo core. Each fixture is one test,
# so a failure names the fixture that diverged. The corpus holds only rules that
# Beermat 2.1 keeps; fixtures for replaced 1.2 rules were retired (see
# docs/parity-fixture-classification.md) and their 2.1 replacements live in the
# Mojo-native tests.

import replay
from std.testing import TestSuite


def test_02_buy_sell_edges() raises:
    replay.replay_fixture("02-buy-sell-edges")


def test_03_travel_interest() raises:
    replay.replay_fixture("03-travel-interest")


def test_05_dealers() raises:
    replay.replay_fixture("05-dealers")


def test_07_finish_scoring() raises:
    replay.replay_fixture("07-finish-scoring")


def test_10_rolls_and_helpers() raises:
    replay.replay_fixture("10-rolls-and-helpers")


def test_11_finances() raises:
    replay.replay_fixture("11-finances")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
