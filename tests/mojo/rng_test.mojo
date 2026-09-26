# tests/mojo/rng_test.mojo — slice 1 parity: the seeded draw stream.
#
# The draw stream is the foundation every other subsystem's determinism rests on,
# so it is checked against the JS oracle's own mulberry32 output for several
# seeds, including both wraparound edges, and against the rngState the oracle
# recorded in tests/fixtures/01-price-generation.jsonl after its first
# generatePrices (which draws a known, seed-dependent number of values).
#
# Expected values are transcribed from `node`, running the engine's mulberry32
# verbatim. The fixture-derived rngState values are cross-checked in
# test_rng_state_matches_oracle_fixture below.

import lexeme
import rng
from std.testing import assert_equal, assert_raises, assert_true, TestSuite


def test_seeded_stream_matches_js() raises:
    # seed -> first three draws, from the engine's mulberry32.
    # Transcribed from `node` running the engine's mulberry32, and encoded in
    # the same decomposed form the oracle uses so no decimal rounding is
    # involved. seed -> first three draws.
    var cases: List[String] = [
        "7|d:0:1016:2243731180748800|d:0:1018:4425526315843584|d:0:1022:4295602074550272",
        "1|d:0:1022:1144580302962688|d:0:1014:1804543931187200|d:0:1022:247220957872128",
        "12345|d:0:1022:4321008095854592|d:0:1021:1022357909012480|d:0:1021:4219069796450304",
        # 0xFFFFFFFF and 0 are the two seeds where the seed itself is the
        # addend boundary, so they catch a missing wraparound.
        "4294967295|d:0:1022:3570657474379776|d:0:1020:2323074024210432|d:0:1022:1942426642022400",
        "0|d:0:1021:295962312441856|d:0:1011:1579134920687616|d:0:1020:3540622929559552",
        "42|d:0:1022:910661638946816|d:0:1021:3572085150449664|d:0:1022:3174729632448512",
    ]
    for case_ in cases:
        var parts = case_.split("|")
        var source = rng.Rng(UInt32(lexeme.to_int(String(parts[0]))))
        for i in range(1, 4):
            assert_equal(source.next(), lexeme.to_float(String(parts[i])))


def test_get_state_matches_js() raises:
    var cases: List[String] = [
        "7|1199730150", "1|1199730144", "12345|1199742488",
        "4294967295|1199730142", "0|1199730143", "42|1199730185",
    ]
    for case_ in cases:
        var parts = case_.split("|")
        var source = rng.Rng(UInt32(lexeme.to_int(String(parts[0]))))
        _ = source.next()
        _ = source.next()
        _ = source.next()
        assert_equal(Int64(source.get_state()), lexeme.to_int(String(parts[1])))


def test_state_round_trips() raises:
    var source = rng.Rng(UInt32(7))
    _ = source.next()
    var saved = source.get_state()
    var expected_next = source.next()
    source.set_state(saved)
    assert_equal(source.next(), expected_next)


def test_script_mode_yields_the_script() raises:
    var source = rng.Rng(UInt32(7))
    source.set_script([0.25, 0.5, 0.75])
    assert_true(source.is_scripted())
    assert_equal(source.next(), 0.25)
    assert_equal(source.next(), 0.5)
    assert_equal(source.next(), 0.75)
    # A scripted Rng is exhausted, never silently wrapped back to the stream.
    with assert_raises(contains="scripted Rng exhausted"):
        _ = source.next()


def test_rand_int_is_inclusive_on_both_ends() raises:
    # randInt(rng, 0, 0) must be 0 even though the span is one wide.
    var fixed = rng.Rng(UInt32(0))
    fixed.set_script([0.0])
    assert_equal(rng.rand_int(fixed, 3, 3), 3)

    var low = rng.Rng(UInt32(0))
    low.set_script([0.0])
    assert_equal(rng.rand_int(low, 7, 19), 7)

    # 0.999... still lands on the inclusive upper bound, never past it.
    var high = rng.Rng(UInt32(0))
    high.set_script([0.9999999])
    assert_equal(rng.rand_int(high, 7, 19), 19)

    var mid = rng.Rng(UInt32(0))
    mid.set_script([0.5])
    assert_equal(rng.rand_int(mid, 0, 10), 5)


def test_rand_int_matches_js_on_the_seeded_stream() raises:
    # randInt(rng, 80, 95) is the mugged-loss roll in rollArrivalEvent and
    # randInt(rng, 0, i) drives the shuffle, so both matter.
    var source = rng.Rng(UInt32(7))
    var a = rng.rand_int(source, 80, 95)
    var b = rng.rand_int(source, 0, 11)
    assert_equal(a, 80)
    assert_equal(b, 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
