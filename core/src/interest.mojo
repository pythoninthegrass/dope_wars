# core/src/interest.mojo — Beermat's daily interest in integers; the derivation is in docs/beermat-re.md (M-10).


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
    var product_times_twenty = bank * 21
    var rounded = _round_quotient_ties_even(product_times_twenty, 20)
    if product_times_twenty % 20 != 10:
        return rounded
    # largest power of two not above the product, which sets the x87 ulp
    var power_of_two: Int64 = 1
    while power_of_two * 2 * 20 <= product_times_twenty:
        power_of_two *= 2
    # the extended 1.05 is low enough here that the stored product sits one ulp under the tie
    if 4 * bank > 5 * power_of_two:
        return product_times_twenty // 20
    return rounded
