# core/src/jsmath.mojo — the two JavaScript rounding primitives the engine uses.
#
# Both are spelled out rather than mapped onto Mojo's own rounding, because the
# oracle's numbers come from these exact functions and a one-unit difference
# compounds: debt is rounded every turn, so a mismatch on day 2 is a different
# game by day 31.
#
#   Math.floor(x)  -> the largest integer <= x
#   Math.round(x)  -> floor(x + 0.5), including for negatives, where JS rounds
#                     -2.5 to -2 rather than away from zero
#
# The engine only ever applies these to non-negative values, but the negative
# behaviour is implemented correctly anyway so the helpers are not a trap later.


def js_floor(value: Float64) -> Int64:
    var whole = Int64(value)
    if Float64(whole) > value:
        return whole - 1
    return whole


def js_round(value: Float64) -> Int64:
    return js_floor(value + 0.5)
