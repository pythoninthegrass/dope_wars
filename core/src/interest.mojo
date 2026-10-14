# core/src/interest.mojo — Beermat 2.1's daily interest: the bank (N-33) and every loan (N-06), plus the early payoff (N-30).

from std.math import fma

import sharks


def _round_quotient_ties_even(numerator: Int64, denominator: Int64) -> Int64:
    var floor_quotient = numerator // denominator
    var twice_remainder = 2 * (numerator - floor_quotient * denominator)
    if twice_remainder < denominator:
        return floor_quotient
    if twice_remainder > denominator:
        return floor_quotient + 1
    if floor_quotient % 2 == 0:
        return floor_quotient
    return floor_quotient + 1


# Round(balance * (rate / 100.0) + balance). The rate is a double, so an exact .5 tie goes to the
# side the double's error points at: 0.15 sits a hair below, 0.10 a hair above, 0.25 is exact and
# rounds to even.
def loan_after_interest(balance: Int64, rate: Int64) -> Int64:
    if balance <= 0:
        return balance
    var total = balance * (100 + rate)
    var floor_quotient = total // 100
    var remainder = total - floor_quotient * 100
    if remainder < 50:
        return floor_quotient
    if remainder > 50:
        return floor_quotient + 1
    var residual = fma(Float64(rate) / 100.0, 100.0, -Float64(rate))
    if residual < 0.0:
        return floor_quotient
    if residual > 0.0:
        return floor_quotient + 1
    if floor_quotient % 2 == 0:
        return floor_quotient
    return floor_quotient + 1


# What settling a loan costs: past due it is the balance, otherwise the balance plus 30% of the
# interest the remaining days would add.
def early_payoff(balance: Int64, rate: Int64, days_left: Int64) -> Int64:
    if days_left <= 0:
        return balance
    var projected = balance
    for _ in range(Int(days_left)):
        projected = loan_after_interest(projected, rate)
    var remaining = projected - balance
    return balance + _round_quotient_ties_even(remaining * sharks.EARLY_PAYOFF_PERCENT, 100)


def bank_after_interest(bank: Int64) -> Int64:
    if bank <= 0:
        return bank
    # Round(bank * 0.05) with the double rate pushing exact .5 ties up
    return bank + (bank + 10) // 20
