# core/src/combat.mojo — the cop chase: start, run, stay, fight and the doctor.
#
# Ported from shouldStartChase / startChase / runFromChase / stayInChase /
# fight / acceptDoctorOffer in index.html (docs/beermat-re.md, M-04, M-07 to M-09).
#
# shouldStartChase is Beermat's Random(6) == 0: a flat 1 in 6 at every location.
# Run escapes on Random(6) < 3 whatever the player carries. Anything but an
# escape (and Stay) lets the cops fire: Random(2), 1 hits for Random(11) + 5.
# Fight is the player's shot (Random(2), 1 kills a deputy) and then, while the
# deputy count is still 0 or more, the cops' return fire. Dropping below 0 wins:
# +1 gun, (Random(1000) + 1000) + Random(1500) cash, and a doctor offer priced
# at the first term.

import events
import result
import rules
import rng as rng_mod
import world


struct Chase(Copyable, Movable):
    var deputies: Int64

    def __init__(out self, deputies: Int64):
        self.deputies = deputies


struct CopFire(Copyable, Movable):
    var hit: Bool
    var damage: Int64
    var dead: Bool

    def __init__(out self, hit: Bool, damage: Int64, dead: Bool):
        self.hit = hit
        self.damage = damage
        self.dead = dead


struct RunResult(Copyable, Movable):
    var escaped: Bool
    var fire: CopFire

    def __init__(out self, escaped: Bool, fire: CopFire):
        self.escaped = escaped
        self.fire = fire.copy()


struct DoctorOffer(Copyable, Movable):
    var price: Int64

    def __init__(out self, price: Int64):
        self.price = price


struct FightResult(Copyable, Movable):
    var killed: Bool
    var fire: CopFire
    var won: Bool
    var reward: Int64
    var doctor: DoctorOffer

    def __init__(
        out self,
        killed: Bool,
        fire: CopFire,
        won: Bool,
        reward: Int64,
        doctor: DoctorOffer,
    ):
        self.killed = killed
        self.fire = fire.copy()
        self.won = won
        self.reward = reward
        self.doctor = doctor.copy()


def should_start_chase(mut game: world.World) raises -> Bool:
    return rng_mod.rand_int(game.rng, 0, 5) == 0


def start_chase(mut game: world.World) raises -> Chase:
    # beermat-verified (TASK-009): deputy count isn't day-scaled -- observed
    # (day, deputies) pairs {2:10, 9:11, 14:6, 15:2, 17:4, 20:2} show no day
    # correlation, only a flat range wider than docs/gameplay.md's C-source
    # Officer Hardass table (2-8).
    var deputies = rng_mod.rand_int(game.rng, 2, 11)
    return Chase(deputies)


# One volley from the cops: Random(2), 1 hits for Random(11) + 5 damage.
def _cops_fire(mut game: world.World) raises -> CopFire:
    if rng_mod.rand_int(game.rng, 0, 1) != 1:
        return CopFire(False, 0, game.dead)
    var damage = rng_mod.rand_int(game.rng, 5, 15)
    _ = events.apply_damage(game, damage)
    return CopFire(True, damage, game.dead)


def run_from_chase(mut game: world.World) raises -> RunResult:
    if rng_mod.rand_int(game.rng, 0, 5) < 3:
        return RunResult(True, CopFire(False, 0, game.dead))
    return RunResult(False, _cops_fire(game))


def stay_in_chase(mut game: world.World) raises -> CopFire:
    return _cops_fire(game)


# The caller has checked the player owns a gun. The count goes below 0 on the last kill.
def fight(mut game: world.World, mut chase: Chase) raises -> FightResult:
    var killed = rng_mod.rand_int(game.rng, 0, 1) == 1
    if killed:
        chase.deputies -= 1
    if chase.deputies < 0:
        var doctor_price = rng_mod.rand_int(game.rng, 1000, 1999)
        var reward = doctor_price + rng_mod.rand_int(game.rng, 0, 1499)
        game.cash += Float64(reward)
        game.guns += 1
        return FightResult(killed, CopFire(False, 0, False), True, reward, DoctorOffer(doctor_price))
    return FightResult(killed, _cops_fire(game), False, 0, DoctorOffer(0))


# The doctor is always offered after a win; accepting pays the price from cash and restores full health.
def accept_doctor_offer(mut game: world.World, offer: DoctorOffer) -> Int:
    if Float64(offer.price) > game.cash:
        return result.ERR_INSUFFICIENT_CASH
    game.cash -= Float64(offer.price)
    game.health = rules.START_HEALTH
    return result.OK
