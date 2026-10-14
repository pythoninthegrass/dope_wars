# core/src/sharks.mojo — the five loan sharks (docs/beermat-2.1-re.md, "Loan sharks", N-06).
#
# Rate is a percentage per day, duration is in days and multiplier is the borrow limit as a multiple
# of cash plus bank. The table is returned by value for the same reason rules.mojo does.

comptime NUM_SHARKS = 5
comptime MAX_TOTAL_DEBT = 1000000
# Paying early costs this percentage of the interest still to come (N-30).
comptime EARLY_PAYOFF_PERCENT = 30


struct Shark:
    var name: String
    var female: Bool
    var rate: Int64
    var duration: Int64
    var multiplier: Int64
    var bruisers: Int64

    def __init__(
        out self,
        name: String,
        female: Bool,
        rate: Int64,
        duration: Int64,
        multiplier: Int64,
        bruisers: Int64,
    ):
        self.name = name
        self.female = female
        self.rate = rate
        self.duration = duration
        self.multiplier = multiplier
        self.bruisers = bruisers


def shark(index: Int) -> Shark:
    if index == 0:
        return Shark("Honest Harry", False, 15, 10, 10, 1)
    if index == 1:
        return Shark("Sandy Schwing", True, 10, 15, 20, 1)
    if index == 2:
        return Shark("Tank NoNeck", False, 20, 7, 30, 2)
    if index == 3:
        return Shark("Bulbous Bertha", True, 30, 1, 50, 3)
    return Shark("Midget Mickey", False, 25, 5, 100, 4)
