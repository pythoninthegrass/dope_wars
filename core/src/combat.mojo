# core/src/combat.mojo — the cop chase and the fight.
#
# Ported from shouldStartChase / startChase / getFightRatings / runFromChase /
# fight in index.html:971-1019.
#
# shouldStartChase is weighted by the borough's police presence: the roll is
# randInt(0, 80 + police) and a chase starts at 50 or above. So the Bronx
# (police 10) starts a chase on 41 of 91 outcomes and Manhattan (police 90) on
# 121 of 171 -- the weighting is the whole point of the location table.
#
# fight compares one attack roll against one defend roll. A hit removes a
# deputy; a miss costs the player health, scaled by armour. The damage formula
# is `max(1, round(raw * (100 / playerArmor)))`, and playerArmor is 100, so it
# currently reduces to `max(1, raw)` -- but the armour term is kept because it
# is part of the rule, not an accident of the current constant.

import events
import jsmath
import result
import rules
import rng as rng_mod
import world


struct Chase(Copyable, Movable):
    var deputies: Int64

    def __init__(out self, deputies: Int64):
        self.deputies = deputies


struct FightRatings(Copyable, Movable):
    var attack: Int64
    var defend: Int64

    def __init__(out self, attack: Int64, defend: Int64):
        self.attack = attack
        self.defend = defend


struct FightResult(Copyable, Movable):
    var hit: Bool
    var damage: Int64
    var dead: Bool
    var won: Bool

    def __init__(out self, hit: Bool, damage: Int64, dead: Bool, won: Bool):
        self.hit = hit
        self.damage = damage
        self.dead = dead
        self.won = won


def should_start_chase(mut game: world.World) raises -> Bool:
    var location_table = rules.locations()
    var police = location_table[game.location_index].police
    return rng_mod.rand_int(game.rng, 0, 80 + police) >= 50


def start_chase(mut game: world.World) raises -> Chase:
    # beermat-verified (TASK-009): deputy count isn't day-scaled -- observed
    # (day, deputies) pairs {2:10, 9:11, 14:6, 15:2, 17:4, 20:2} show no day
    # correlation, only a flat range wider than docs/gameplay.md's C-source
    # Officer Hardass table (2-8).
    var deputies = rng_mod.rand_int(game.rng, 2, 11)
    return Chase(deputies)


def get_fight_ratings(ref game: world.World) -> FightRatings:
    var attack = 80 + game.guns * rules.GUN_DAMAGE
    var defend: Int64 = 100
    if attack < 10:
        attack = 10
    if defend < 10:
        defend = 10
    return FightRatings(attack, defend)


def run_from_chase(
    mut game: world.World, chase: Chase, is_aggressor: Bool
) raises -> Bool:
    # Fleeing is harder when you started it.
    var chance = 0.60
    if is_aggressor:
        chance = 0.30
    var escaped = game.rng.next() < chance
    if not escaped:
        var damage = rng_mod.rand_int(game.rng, 3, 12)
        _ = events.apply_damage(game, damage)
    return escaped


def fight(mut game: world.World, mut chase: Chase) raises -> FightResult:
    var ratings = get_fight_ratings(game)
    var attack_roll = rng_mod.rand_int(game.rng, 0, ratings.attack)
    var defend_roll = rng_mod.rand_int(game.rng, 0, ratings.defend)
    var hit = attack_roll > defend_roll
    var damage: Int64 = 0
    if hit:
        chase.deputies -= 1
        if chase.deputies < 0:
            chase.deputies = 0
    else:
        var raw = rng_mod.rand_int(game.rng, 0, rules.GUN_DAMAGE)
        damage = jsmath.js_round(Float64(raw) * (100.0 / Float64(rules.PLAYER_ARMOR)))
        if damage < 1:
            damage = 1
        _ = events.apply_damage(game, damage)
    return FightResult(hit, damage, game.dead, chase.deputies <= 0)
