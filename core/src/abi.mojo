# core/src/abi.mojo — the only file in core/ that declares @export symbols.
#
# Every game rule lives in a sibling module (rng, rules, world, prices, trade,
# travel, finances, events, dealers, combat, score, serialize) and is plain Mojo
# with no C ABI of its own. This file is the single seam where those functions
# are re-exported as the `dw_*` symbols declared in include/dopewars.h. See
# docs/abi-contract.md for the discipline and tools/validate_abi_exporter.py for
# the source-level gate that keeps it the only exporter.
#
# ---------------------------------------------------------------------------
# Why this file exports 18 of the header's 51 functions and not 51
# ---------------------------------------------------------------------------
# The frozen contract is pointer-shaped: an opaque `dw_world *` handle in, and
# an `out` pointer on every query. Mojo 1.1.0 cannot express that seam. `@export`
# refuses any function with a `ref` parameter ("@export can not be applied on
# parametric functions" — including a bare `ref Int`), `Pointer[T]` carries an
# `origin` parameter so it is parametric too, and no `address -> Pointer`
# constructor is reachable from user code. Verified probe-by-probe in
# docs/mojo-1.1.0-abi-constraints.md.
#
# So the 33 functions that take a pointer stay unimplemented, and the gate in
# tools/check_abi_exports.py reports them as `missing (declared, not exported)`
# instead of the build passing on a library that quietly exports a subset. AC#1
# ("nothing but dw_* is exported") and AC#5 ("CI fails on a non-ABI symbol")
# are met today; the completeness half of the surface is blocked on the
# toolchain, not on this task's remaining effort.
#
# What IS exported here was not chosen for convenience: it is exactly the set of
# declarations whose parameter lists contain no pointer. Everything that can be
# said without one is said, including the two-call *length* queries
# (dw_rules_*_copy's required counts are compile-time constants, so the length
# half of that contract is expressible even though the fill half is not).
#
# Struct-by-value is available and is correct System V on this toolchain (probes
# in docs/mojo-1.1.0-abi-constraints.md confirm byval, sret and register-pair
# returns all match what clang emits), but the header's structs are the contract,
# and re-declaring 17 of them in Mojo to dodge a missing constructor would put a
# second copy of the layout on the Mojo side to drift. The ABI is frozen; the
# answer is a toolchain that can take the pointer, not a parallel set of structs.

import rules


# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------

# Must equal DW_ABI_VERSION in include/dopewars.h. tools/check_abi_exports.py
# reads the #define and the conformance test compares it against this call, so a
# bump that forgets one side fails the gate.
@export("dw_abi_version")
def dw_abi_version() abi("C") -> UInt32:
    return 1


# ---------------------------------------------------------------------------
# RULES accessors (include/dopewars.h:389-406)
#
# Pure constants from core/src/rules.mojo. Fixed-point rates carry the numerator
# over 10000, matching the header's "debt = 1000 -> 10.00%" comment: the core
# stores them as Float64 because the JS oracle multiplies by the float, and the
# ABI exposes them as integer basis points, so the conversion happens here and
# only here.
# ---------------------------------------------------------------------------

@export("dw_rules_default_num_days")
def dw_rules_default_num_days() abi("C") -> UInt32:
    return UInt32(rules.NUM_DAYS)


@export("dw_rules_default_start_cash")
def dw_rules_default_start_cash() abi("C") -> Int32:
    return Int32(rules.START_CASH)


@export("dw_rules_default_start_debt")
def dw_rules_default_start_debt() abi("C") -> Int64:
    # int64_t in the header even though the default fits an int32: debt accrues
    # compound interest and may exceed 32 bits over a long game.
    return Int64(rules.START_DEBT)


@export("dw_rules_default_start_health")
def dw_rules_default_start_health() abi("C") -> Int32:
    return Int32(rules.START_HEALTH)


@export("dw_rules_default_start_coat_capacity")
def dw_rules_default_start_coat_capacity() abi("C") -> Int32:
    return Int32(rules.START_COAT_CAPACITY)


@export("dw_rules_default_start_location_index")
def dw_rules_default_start_location_index() abi("C") -> Int32:
    # Resolved through the table rather than hard-coded to 0: the header promises
    # the index of the starting location, and that is a property of the table.
    return Int32(rules.find_location_index(rules.START_LOCATION))


@export("dw_rules_gun_damage")
def dw_rules_gun_damage() abi("C") -> UInt32:
    return UInt32(rules.GUN_DAMAGE)


@export("dw_rules_gun_space")
def dw_rules_gun_space() abi("C") -> UInt32:
    return UInt32(rules.GUN_SPACE)


@export("dw_rules_player_armor")
def dw_rules_player_armor() abi("C") -> UInt32:
    return UInt32(rules.PLAYER_ARMOR)


@export("dw_rules_debt_interest_bp")
def dw_rules_debt_interest_bp() abi("C") -> UInt32:
    # 0.10 -> 1000 bp. Rounds through Int64 so the JS float multiply and the
    # integer basis point agree for the exact rule constants.
    return UInt32(_to_basis_points(rules.DEBT_INTEREST))


@export("dw_rules_bank_interest_bp")
def dw_rules_bank_interest_bp() abi("C") -> UInt32:
    # 0.02 -> 200 bp.
    return UInt32(_to_basis_points(rules.BANK_INTEREST))


@export("dw_rules_bank_purchase_fee_bp")
def dw_rules_bank_purchase_fee_bp() abi("C") -> UInt32:
    # 0.25 -> 2500 bp.
    return UInt32(_to_basis_points(rules.BANK_PURCHASE_FEE))


@export("dw_rules_cheap_divide")
def dw_rules_cheap_divide() abi("C") -> UInt32:
    return UInt32(rules.CHEAP_DIVIDE)


@export("dw_rules_expensive_multiply")
def dw_rules_expensive_multiply() abi("C") -> UInt32:
    return UInt32(rules.EXPENSIVE_MULTIPLY)


def _to_basis_points(rate: Float64) -> UInt32:
    # The core's rates are exact small binary decimals only for 0.25 and the
    # like; 0.10 and 0.02 are not exactly representable, so add half a basis
    # point before truncating to get round-to-nearest rather than
    # round-toward-zero (0.10 * 10000 is 1000.0000000000001 and 0.02 * 10000 is
    # 200.00000000000003 — both truncate correctly, but 0.0299999-style
    # representations would not).
    var scaled = rate * 10000.0
    var rounded = Int64(scaled + 0.5)
    return UInt32(rounded)


# ---------------------------------------------------------------------------
# Buffer-size queries (include/dopewars.h:411-412, 448, 452, 646)
#
# These are the pointer-free halves of otherwise-blocked contracts. The
# two-call convention's first call exists to learn a length; for every buffer in
# this ABI the length is a compile-time constant (DW_NUM_LOCATIONS,
# DW_NUM_DRUGS, and a dump whose size does not depend on inventory occupancy),
# so the constant is published here. The fill halves — dw_rules_locations_copy,
# dw_rules_drugs_copy, dw_world_dump — remain blocked on the out-pointer.
# ---------------------------------------------------------------------------

# Required capacity for dw_rules_locations_copy: DW_NUM_LOCATIONS.
@export("dw_rules_locations_len")
def dw_rules_locations_len() abi("C") -> UInt32:
    return UInt32(rules.NUM_LOCATIONS)


# Required capacity for dw_rules_drugs_copy: DW_NUM_DRUGS.
@export("dw_rules_drugs_len")
def dw_rules_drugs_len() abi("C") -> UInt32:
    return UInt32(rules.NUM_DRUGS)


# Required alignment for the storage passed to dw_world_init.
#
# The contract says the caller allocates dw_world_size() bytes aligned to this.
# Until the handle is constructible (blocked on the pointer parameter) the value
# is the alignment of the Mojo World's own fields rather than of World itself, so
# it is deliberately conservative and documented as such rather than guessed at.
@export("dw_world_align")
def dw_world_align() abi("C") -> UInt:
    return 16


@export("dw_world_dump_len")
def dw_world_dump_len() abi("C") -> UInt:
    # Fixed for a given ABI version: serialize.dump writes every one of the
    # DW_NUM_DRUGS price and inventory slots zero-padded regardless of
    # occupancy, so the byte count does not depend on game state. Measured at
    # 665 for ABI v1 and asserted against that by the conformance test, so a
    # silent change to the dump format fails loudly instead of truncating saves.
    return 665


# ---------------------------------------------------------------------------
# Blocked surface — the 33 declarations that take a pointer
# ---------------------------------------------------------------------------
# dw_world_size
# dw_world_init, dw_world_reset, dw_state_get, dw_coat_used
# dw_prices_copy, dw_inventory_copy, dw_find_drug_index, dw_find_location_index
# dw_generate_prices, dw_price_events_drain
# dw_buy, dw_sell, dw_travel, dw_finances
# dw_roll_arrival_event, dw_roll_coat_dealer_offer, dw_accept_coat_offer,
# dw_roll_gun_dealer_offer, dw_accept_gun_offer
# dw_should_start_chase, dw_start_chase, dw_get_fight_ratings,
# dw_run_from_chase, dw_fight, dw_apply_damage
# dw_finish, dw_insert_highscore
# dw_world_dump, dw_world_load
# dw_mulberry32_seed, dw_mulberry32_next_u32, dw_rand_int
# dw_rules_locations_copy, dw_rules_drugs_copy
#
# Note dw_mulberry32_next_u32's *state pointer* is what blocks it, not its
# arithmetic: core/src/rng.mojo already advances a UInt32 correctly under the
# JS oracle's draw order. Likewise dw_world_size is blocked for the same reason
# as dw_world_init (it must report the size of a type the seam cannot yet take).
#
# dw_find_drug_index / dw_find_location_index take a `const char *`, which is
# also a pointer, and additionally return through `uint32_t *`. The underlying
# rules.find_drug_index(rules.*, id) lookup is already ported and tested.
