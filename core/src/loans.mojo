# core/src/loans.mojo — borrowing from and repaying the loan sharks (docs/beermat-2.1-re.md, "Loan sharks").
#
# A shark makes an offer once released from jail and while the player owes them nothing. The offer
# is limited to the shark's multiplier times cash plus bank, and total debt may not pass 1,000,000
# at the moment of borrowing (N-07); interest can still carry it past that.

import events
import interest
import result
import rng as rng_mod
import sharks
import world


def is_offered(ref game: world.World, shark_index: Int) -> Bool:
    if shark_index < 0 or shark_index >= sharks.NUM_SHARKS:
        return False
    return game.shark_released[shark_index] != 0 and game.loan_slot_of(shark_index) < 0


# The most this shark would lend right now; 0 when the cap is already used up.
def borrow_limit(ref game: world.World, shark_index: Int) -> Int64:
    var wealth = Int64(game.cash + game.bank)
    var limit = sharks.shark(shark_index).multiplier * wealth
    var room = Int64(sharks.MAX_TOTAL_DEBT) - game.total_debt()
    if limit > room:
        limit = room
    if limit < 0:
        return 0
    return limit


def borrow(mut game: world.World, shark_index: Int, amount: Int64) -> result.Outcome:
    if shark_index < 0 or shark_index >= sharks.NUM_SHARKS:
        return result.Outcome(result.ERR_INVALID_ARGUMENT)
    if not is_offered(game, shark_index):
        return result.Outcome(result.ERR_NOT_OFFERED)
    if amount <= 0 or amount > borrow_limit(game, shark_index):
        return result.Outcome(result.ERR_INVALID_ARGUMENT)
    game.cash += Float64(amount)
    game.add_loan(shark_index, amount, sharks.shark(shark_index).duration)
    return result.Outcome(result.OK, amount)


# What settling the loan owed to this shark costs, or -1 when there is none.
def payoff(ref game: world.World, shark_index: Int) -> Int64:
    var slot = game.loan_slot_of(shark_index)
    if slot < 0:
        return -1
    return interest.early_payoff(
        game.loan_balance[slot], sharks.shark(shark_index).rate, game.loan_days_left[slot]
    )


def repay(mut game: world.World, shark_index: Int) -> result.Outcome:
    if shark_index < 0 or shark_index >= sharks.NUM_SHARKS:
        return result.Outcome(result.ERR_INVALID_ARGUMENT)
    var slot = game.loan_slot_of(shark_index)
    if slot < 0:
        return result.Outcome(result.ERR_NO_SUCH_LOAN)
    var cost = payoff(game, shark_index)
    if Float64(cost) > game.cash:
        return result.Outcome(result.ERR_INSUFFICIENT_CASH)
    game.cash -= Float64(cost)
    game.remove_loan(slot)
    return result.Outcome(result.OK, cost)


def apply_daily_interest(mut game: world.World):
    for i in range(game.loan_count):
        var rate = sharks.shark(Int(game.loan_shark[i])).rate
        game.loan_balance[i] = interest.loan_after_interest(game.loan_balance[i], rate)
        game.loan_days_left[i] -= 1


# One arrival's release roll: Random(7) < 3 while any shark is still in jail, then Random(5) until
# it lands on one that is (N-09). Returns the released shark, or -1.
def roll_release(mut game: world.World) raises -> Int:
    var released = 0
    for i in range(sharks.NUM_SHARKS):
        if game.shark_released[i] != 0:
            released += 1
    if released >= sharks.NUM_SHARKS:
        return -1
    if rng_mod.rand_int(game.rng, 0, 6) >= 3:
        return -1
    while True:
        var pick = Int(rng_mod.rand_int(game.rng, 0, sharks.NUM_SHARKS - 1))
        if game.shark_released[pick] == 0:
            game.shark_released[pick] = 1
            return pick


# Loans at or past their due day, in loan order; each one opens a visit before the day advances.
def overdue_sharks(ref game: world.World) -> List[Int]:
    var due = List[Int]()
    for i in range(game.loan_count):
        if game.loan_days_left[i] <= 0:
            due.append(Int(game.loan_shark[i]))
    return due^


# Loans with exactly one day left, in loan order; the news says the shark visits tomorrow.
def due_tomorrow_sharks(ref game: world.World) -> List[Int]:
    var soon = List[Int]()
    for i in range(game.loan_count):
        if game.loan_days_left[i] == 1:
            soon.append(Int(game.loan_shark[i]))
    return soon^


# How hard a visit lands: days past due plus the shark's bruisers less one. Level 4 and up beats.
def visit_level(days_left: Int64, bruisers: Int64) -> Int:
    var days = days_left
    if days < 0:
        days = -days
    var level = Int(days + bruisers) - 1
    if level < 0:
        return 0
    return level


comptime BEATING_LEVEL = 4
comptime BEATING_MIN = 15
comptime BEATING_MAX = 30


struct Visit(Copyable, Movable):
    # -1 when nothing is owed to that shark.
    var level: Int
    var days_left: Int64
    var owed: Int64
    var damage: Int64
    # 1 window, 2 stairs, 3 chainsaw; 0 when there was no beating.
    var message: Int
    var dead: Bool

    def __init__(
        out self,
        level: Int,
        days_left: Int64 = 0,
        owed: Int64 = 0,
        damage: Int64 = 0,
        message: Int = 0,
        dead: Bool = False,
    ):
        self.level = level
        self.days_left = days_left
        self.owed = owed
        self.damage = damage
        self.message = message
        self.dead = dead


# Opens a visit from one shark: at level 4 and up the beating lands now, Random(16) + 15 capped at
# health, then Random(3) + 1 picks the text (text 1 with no draw when it takes the last of the
# health). Paying afterwards is dw_repay; refusing changes nothing further (N-08).
def visit(mut game: world.World, shark_index: Int) raises -> Visit:
    var slot = game.loan_slot_of(shark_index)
    if shark_index < 0 or shark_index >= sharks.NUM_SHARKS or slot < 0:
        return Visit(-1)
    var days_left = game.loan_days_left[slot]
    var owed = game.loan_balance[slot]
    var level = visit_level(days_left, sharks.shark(shark_index).bruisers)
    if level < BEATING_LEVEL:
        return Visit(level, days_left, owed)
    var damage = rng_mod.rand_int(game.rng, BEATING_MIN, BEATING_MAX)
    if damage > game.health:
        damage = game.health
    var message = 1
    if damage != game.health:
        message = Int(rng_mod.rand_int(game.rng, 1, 3))
    _ = events.apply_damage(game, damage)
    return Visit(level, days_left, owed, damage, message, game.dead)
