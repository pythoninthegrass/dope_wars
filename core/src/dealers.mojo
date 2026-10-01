# core/src/dealers.mojo — the coat and gun dealers.
#
# One combined visit chance per non-chase arrival, then an even coat/gun split.
# Both dealers are paid from cash only, and only when the rolled price is
# strictly below cash. See docs/beermat-re.md, "Arrival events and dealers".

import result
import rules
import rng as rng_mod
import world

comptime DEALER_NONE = 0
comptime DEALER_COAT = 1
comptime DEALER_GUN = 2


struct CoatOffer(Copyable, Movable):
    var price: Int64
    var offered: Bool

    def __init__(out self, price: Int64, offered: Bool):
        self.price = price
        self.offered = offered


struct GunOffer(Copyable, Movable):
    var price: Int64
    var offered: Bool
    var name_index: Int64

    def __init__(out self, price: Int64, offered: Bool, name_index: Int64):
        self.price = price
        self.offered = offered
        self.name_index = name_index


struct PurchaseResult(Copyable, Movable):
    var code: Int
    var pockets: Int64

    def __init__(out self, code: Int, pockets: Int64 = 0):
        self.code = code
        self.pockets = pockets


# Random(14) == 0 is a visit; Random(4) of 0 or 2 is the coat dealer, 1 or 3 the gun dealer.
def roll_dealer_visit(mut game: world.World) raises -> Int:
    if rng_mod.rand_int(game.rng, 0, rules.DEALER_ODDS - 1) != 0:
        return DEALER_NONE
    if rng_mod.rand_int(game.rng, 0, 3) % 2 == 0:
        return DEALER_COAT
    return DEALER_GUN


def roll_coat_dealer_offer(mut game: world.World) raises -> CoatOffer:
    var price = rng_mod.rand_int(game.rng, rules.COAT_MIN_PRICE, rules.COAT_MAX_PRICE)
    return CoatOffer(price, price < Int64(game.cash))


# The cosmetic name is drawn only when the offer is actually made.
def roll_gun_dealer_offer(mut game: world.World) raises -> GunOffer:
    var price = rng_mod.rand_int(game.rng, rules.GUN_MIN_PRICE, rules.GUN_MAX_PRICE)
    if price < Int64(game.cash):
        return GunOffer(price, True, rng_mod.rand_int(game.rng, 0, rules.GUN_NAME_COUNT - 1))
    return GunOffer(price, False, 0)


# The pocket count is drawn on acceptance, after the price, and not at all if the purchase fails.
def accept_coat_offer(mut game: world.World, offer: CoatOffer) raises -> PurchaseResult:
    if offer.price > Int64(game.cash):
        return PurchaseResult(result.ERR_INSUFFICIENT_CASH)
    var pockets = rng_mod.rand_int(game.rng, rules.COAT_MIN_POCKETS, rules.COAT_MAX_POCKETS)
    game.cash -= Float64(offer.price)
    game.coat_capacity += pockets
    return PurchaseResult(result.OK, pockets)


def accept_gun_offer(mut game: world.World, offer: GunOffer) -> PurchaseResult:
    if offer.price > Int64(game.cash):
        return PurchaseResult(result.ERR_INSUFFICIENT_CASH)
    game.cash -= Float64(offer.price)
    game.guns += 1
    return PurchaseResult(result.OK)
