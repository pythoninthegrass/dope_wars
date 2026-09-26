# core/src/floatbits.mojo — exact float64 <-> (sign, exponent, mantissa).
#
# Mojo 1.1.0 has no cross-dtype bitcast: `rebind` requires the source and target
# to be the same SIMD shape, and a 1-lane SIMD collapses to a scalar, so there is
# no way to reinterpret a Float64's bytes as an integer. Serialization still
# needs to store floats exactly, so this decomposes them arithmetically instead.
#
# Every step is exact:
#   - scaling by 2.0 and 0.5 is exact, so normalising into [1, 2) loses nothing
#   - (normalised - 1.0) is exact, and multiplying by 2^52 is exact
#   - rounding that product to an integer is the only rounding, and it is the
#     same rounding the hardware already applied when the float was formed
#   - recomposition is exact for the same reasons
#
# `decompose` verifies its own output by recomposing and comparing, so a value
# this cannot represent fails loudly rather than round-tripping silently wrong.

import jsmath


comptime _MANTISSA_SCALE = 4503599627370496.0  # 2^52
comptime _EXPONENT_BIAS = 1023


struct FloatParts(Copyable, Movable):
    var sign: Int
    var exponent: Int
    var mantissa: Int64

    def __init__(out self, sign: Int, exponent: Int, mantissa: Int64):
        self.sign = sign
        self.exponent = exponent
        self.mantissa = mantissa


def compose(sign: Int, exponent: Int, mantissa: Int64) raises -> Float64:
    if exponent == 0:
        # Zero or subnormal. The engine's money values are never either, and
        # treating exponent 0 as a normal would silently produce 2^-1023.
        if mantissa == 0:
            return 0.0
        raise Error("subnormal floats are not representable by compose")
    var value = 1.0 + Float64(mantissa) / _MANTISSA_SCALE
    var scale = exponent - _EXPONENT_BIAS
    while scale > 0:
        value *= 2.0
        scale -= 1
    while scale < 0:
        value *= 0.5
        scale += 1
    if sign != 0:
        value = -value
    return value


def decompose(value: Float64) raises -> FloatParts:
    if value == 0.0:
        return FloatParts(0, 0, 0)
    var sign = 0
    var magnitude = value
    if magnitude < 0.0:
        sign = 1
        magnitude = -magnitude

    # Normalise into [1, 2), counting the power of two applied.
    var exponent = 0
    while magnitude >= 2.0:
        magnitude *= 0.5
        exponent += 1
    while magnitude < 1.0:
        magnitude *= 2.0
        exponent -= 1

    var mantissa = jsmath.js_round((magnitude - 1.0) * _MANTISSA_SCALE)
    if mantissa == 4503599627370496:  # rounded up to 2.0
        mantissa = 0
        exponent += 1

    var parts = FloatParts(sign, exponent + _EXPONENT_BIAS, mantissa)
    if compose(parts.sign, parts.exponent, parts.mantissa) != value:
        raise Error("float decomposition is not exact for this value")
    return parts^
