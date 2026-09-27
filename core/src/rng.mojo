# core/src/rng.mojo — the deterministic random source every other subsystem
# draws from. Ported from mulberry32 / randInt in index.html:624-639.
#
# A run is reproducible from its seed, so the whole simulation is: given the
# same seed, draw the same floats in the same order. Nothing else in core/ is
# allowed to introduce randomness.
#
# Two draw modes, mirroring the JS engine's design. There, `rng` is an injected
# `() => float` argument, so a caller may substitute any sequence and the engine
# does not care. The Mojo world owns its Rng, so the same two modes live here:
#
#   seeded  — mulberry32, the default. Fixtures that exercise the real draw
#             stream (price generation, the 31-day run) use this.
#   script  — a caller-supplied list of floats. Fixtures that need to force an
#             exact branch (arrival events, combat) use this.
#
# The JS arithmetic is reproduced exactly, including the 32-bit wraparound in
# every intermediate, because the fixture runner compares the resulting
# mulberry32 state integer against the oracle.


comptime _TWO_POW_32 = 4294967296.0
comptime _MASK32 = UInt32(0xFFFFFFFF)
comptime _INCREMENT = UInt32(0x6D2B79F5)


# The raw mulberry32 draw for a given state, before the state advances. Free
# functions so the C ABI's dw_mulberry32_next_u32 / dw_rand_int can drive a bare
# uint32_t state without constructing an Rng (which can raise in script mode).
def mulberry32_draw(state: UInt32) -> UInt32:
    # a = (a + 0x6D2B79F5) | 0
    var a = state + _INCREMENT
    # t = Math.imul(a ^ (a >>> 15), 1 | a)
    var t = (a ^ (a >> 15)) * (UInt32(1) | a)
    # t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    t = (t + ((t ^ (t >> 7)) * (UInt32(61) | t))) ^ t
    # ((t ^ (t >>> 14)) >>> 0)
    return (t ^ (t >> 14)) & _MASK32


def mulberry32_advance(state: UInt32) -> UInt32:
    return state + _INCREMENT


struct Rng:
    var state: UInt32
    # Script mode. `_script` is empty for a seeded Rng; the Mojo pointer is
    # non-nullable, so emptiness is signalled by `_script_len == 0`.
    var _script: List[Float64]
    var _script_pos: Int

    def __init__(out self, seed: UInt32):
        self.state = seed
        self._script = List[Float64]()
        self._script_pos = 0

    # Draw from a caller-supplied sequence instead of the seeded stream. Any
    # number of previous draws is discarded: a scripted Rng has no seeded
    # history to preserve.
    def set_script(mut self, script: List[Float64]):
        self._script = script.copy()
        self._script_pos = 0

    def clear_script(mut self):
        self._script = List[Float64]()
        self._script_pos = 0

    def is_scripted(ref self) -> Bool:
        return len(self._script) > 0

    # The mulberry32 internal state. serializeState / deserializeState round-trip
    # this, so it must be observable.
    def get_state(ref self) -> UInt32:
        return self.state

    def set_state(mut self, state: UInt32):
        self.state = state

    def next(mut self) raises -> Float64:
        if self.is_scripted():
            if self._script_pos >= len(self._script):
                raise Error("scripted Rng exhausted after " + String(len(self._script)) + " draws")
            var value = self._script[self._script_pos]
            self._script_pos += 1
            return value
        return Float64(self.next_u32()) / _TWO_POW_32

    # The raw uint32_t draw, before normalization. dw_mulberry32_next_u32
    # exposes exactly this so the JS oracle can be compared bit-for-bit.
    # Scripted mode has no raw draw: a script supplies normalized floats.
    def next_u32(mut self) raises -> UInt32:
        if self.is_scripted():
            raise Error("scripted Rng has no raw uint32 draw")
        var draw = mulberry32_draw(self.state)
        self.state = mulberry32_advance(self.state)
        return draw


# randInt(rng, min, max) -> min + floor(rng() * (max - min + 1))
# The bounds are inclusive on both ends.
def rand_int(mut rng: Rng, low: Int64, high: Int64) raises -> Int64:
    var span = high - low + 1
    var draw = rng.next()
    return low + Int64(_floor(draw * Float64(span)))


def _floor(value: Float64) -> Int64:
    # Math.floor. The values here are non-negative, so a truncating cast is
    # identical, but spelling it out keeps the JS correspondence visible.
    var whole = Int64(value)
    if Float64(whole) > value:
        return whole - 1
    return whole
