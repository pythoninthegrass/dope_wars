# core/src/dealers.mojo — the coat and gun dealers.
#
# Ported from rollCoatDealerOffer / acceptCoatOffer / rollGunDealerOffer /
# acceptGunOffer in index.html:929-969.
#
# Both dealers share one payment rule: pay from cash if there is enough,
# otherwise draw the shortfall from the bank and add a 25% fee on the whole
# price. The fee is `Math.ceil(price * 0.25)`, so it rounds up to a whole
# dollar. If the bank cannot cover price + fee the purchase fails and nothing
# moves.
#
# The gun dealer has one extra guard the coat dealer does not: a gun occupies
# GUN_SPACE coat slots, so the purchase fails outright if it would not fit.

import jsmath
import result
import rules
import rng as rng_mod
import world


struct CoatOffer(Copyable, Movable):
    var pockets: Int64
    var price: Int64

    def __init__(out self, pockets: Int64, price: Int64):
        self.pockets = pockets
        self.price = price


struct GunOffer(Copyable, Movable):
    var price: Int64
    var damage: Int64
    var space: Int64

    def __init__(out self, price: Int64, damage: Int64, space: Int64):
        self.price = price
        self.damage = damage
        self.space = space


struct PurchaseResult(Copyable, Movable):
    var code: Int
    var used_bank: Bool
    var fee: Int64

    def __init__(out self, code: Int, used_bank: Bool = False, fee: Int64 = 0):
        self.code = code
        self.used_bank = used_bank
        self.fee = fee


struct DealerVisits(Copyable, Movable):
    var coat: Bool
    var gun: Bool

    def __init__(out self, coat: Bool = False, gun: Bool = False):
        self.coat = coat
        self.gun = gun


def roll_coat_dealer_offer(mut game: world.World) raises -> CoatOffer:
    var pockets = rng_mod.rand_int(game.rng, rules.COAT_MIN_POCKETS, rules.COAT_MAX_POCKETS)
    var price = rng_mod.rand_int(game.rng, rules.COAT_MIN_PRICE, rules.COAT_MAX_PRICE)
    return CoatOffer(pockets, price)


def roll_gun_dealer_offer(mut game: world.World) raises -> GunOffer:
    var price = rng_mod.rand_int(game.rng, rules.GUN_MIN_PRICE, rules.GUN_MAX_PRICE)
    return GunOffer(price, rules.GUN_DAMAGE, rules.GUN_SPACE)


# Ported from the two `state.rng() < 0.15` draws in index.html:1387-1388.
# Both draws always happen, coat first and gun second, even when the player
# is dead: in JS the `!state.dead` guard is the right-hand operand, so
# short-circuit evaluation has already consumed the draw by the time it is
# tested. Skipping the draw on death would desync the RNG stream for the rest
# of the run.
def roll_dealer_visits(mut game: world.World) raises -> DealerVisits:
    var coat = game.rng.next() < rules.DEALER_VISIT_CHANCE
    var gun = game.rng.next() < rules.DEALER_VISIT_CHANCE
    if game.dead:
        return DealerVisits()
    return DealerVisits(coat, gun)


# Shared payment path. Returns the code plus whether the bank was used and the
# fee charged, so the caller can apply its own side effect on success.
def _pay(mut game: world.World, price: Int64) -> PurchaseResult:
    if price > Int64(game.cash):
        # Math.ceil, not round: the fee always rounds up to a whole dollar.
        var fee = _ceil(Float64(price) * rules.BANK_PURCHASE_FEE)
        var total = price + fee
        if Int64(game.bank) < total:
            return PurchaseResult(result.ERR_INSUFFICIENT_BANK)
        game.bank -= Float64(total)
        return PurchaseResult(result.OK, True, fee)
    game.cash -= Float64(price)
    return PurchaseResult(result.OK, False, 0)


def _ceil(value: Float64) -> Int64:
    var whole = Int64(value)
    if Float64(whole) < value:
        return whole + 1
    return whole


def accept_coat_offer(mut game: world.World, offer: CoatOffer) -> PurchaseResult:
    var payment = _pay(game, offer.price)
    if payment.code != result.OK:
        return payment^
    game.coat_capacity += offer.pockets
    return payment^


def accept_gun_offer(mut game: world.World, offer: GunOffer) -> PurchaseResult:
    if game.coat_used() + offer.space > game.coat_capacity:
        return PurchaseResult(result.ERR_INSUFFICIENT_SPACE)
    var payment = _pay(game, offer.price)
    if payment.code != result.OK:
        return payment^
    game.guns += 1
    return payment^
