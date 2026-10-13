# core/src/interest.mojo — Beermat's daily interest; bank follows 2.1 (docs/beermat-2.1-re.md, N-33), debt follows 1.2 (docs/beermat-re.md, M-10).


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


def debt_after_interest(debt: Int64) -> Int64:
    if debt <= 0:
        return debt
    return _round_quotient_ties_even(debt * 11, 10)


def bank_after_interest(bank: Int64) -> Int64:
    if bank <= 0:
        return bank
    # Round(bank * 0.05) with the double rate pushing exact .5 ties up
    return bank + (bank + 10) // 20
