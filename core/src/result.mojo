# core/src/result.mojo — core-level outcome codes.
#
# The JS engine reports failures as `{ ok: false, reason: "<English sentence>" }`.
# Core must not carry presentation strings (docs/layer-boundaries.md), so it
# reports a code instead and the game layer renders the sentence. These codes
# map 1:1 onto the dw_result values in include/dopewars.h; the ABI layer does
# the translation, so core stays free of ABI types.
#
# `OK` is zero so a default-constructed result reads as success.

comptime OK = 0
comptime ERR_NOT_TRADED_HERE = 1
comptime ERR_INSUFFICIENT_CASH = 2
comptime ERR_INSUFFICIENT_SPACE = 3
comptime ERR_INSUFFICIENT_BANK = 10
comptime ERR_INSUFFICIENT_INVENTORY = 4
comptime ERR_INVALID_ARGUMENT = 5
comptime ERR_UNKNOWN_LOCATION = 6
comptime ERR_ALREADY_THERE = 7
comptime ERR_GAME_OVER = 8
comptime ERR_DEAD = 9


struct Outcome:
    # `code == OK` means the call succeeded. `amount` carries the quantity the
    # call actually moved, which several JS returns report alongside `ok`.
    var code: Int
    var amount: Int64

    def __init__(out self, code: Int, amount: Int64 = 0):
        self.code = code
        self.amount = amount

    def ok(ref self) -> Bool:
        return self.code == OK
