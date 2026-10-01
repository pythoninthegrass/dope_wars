# core/src/abi.mojo — the only file in core/ that declares @export symbols.
#
# Every game rule lives in a sibling module (rng, rules, world, prices, trade,
# travel, finances, events, dealers, combat, score, serialize) and is plain Mojo
# with no C ABI of its own. This file is the single seam where those functions
# are re-exported as the `dw_*` symbols declared in include/dopewars.h. The
# export-surface gate (tools/validate_abi_exporter.py) fails if any other file
# in core/src declares a `dw_`-prefixed export.
#
# The ABI structs below mirror include/dopewars.h field for field. Mojo 1.1.0
# has no @cImport, so the conformance suite (core/abitest/) declares the same
# structs and reaches the library through std.ffi.external_call; the
# `_assert_layouts` comptime asserts here are the Mojo-side twin of the header's
# DW_STATIC_ASSERT, so a layout drift breaks the build on both sides.
#
# DW_ABI_VERSION must match include/dopewars.h's #define exactly.

from std.sys import size_of, align_of

import combat
import dealers
import events
import finances
import jsmath
import prices
import result
import rng as rng_mod
import rules
import score
import serialize
import trade
import travel
import world as world_mod


comptime DW_ABI_VERSION = 3

# dw_result values (include/dopewars.h). Frozen from ABI v1 onward.
comptime DW_OK = Int32(0)
comptime DW_ERR_INVALID_ARGUMENT = Int32(1)
comptime DW_ERR_BUFFER_TOO_SMALL = Int32(2)
comptime DW_ERR_ABI_VERSION_MISMATCH = Int32(3)
comptime DW_ERR_UNKNOWN_LOCATION = Int32(4)
comptime DW_ERR_UNKNOWN_DRUG = Int32(5)
comptime DW_ERR_NOT_TRADED_HERE = Int32(6)
comptime DW_ERR_INSUFFICIENT_CASH = Int32(7)
comptime DW_ERR_INSUFFICIENT_BANK = Int32(8)
comptime DW_ERR_INSUFFICIENT_INVENTORY = Int32(9)
comptime DW_ERR_INSUFFICIENT_SPACE = Int32(10)
comptime DW_ERR_GAME_OVER = Int32(11)
comptime DW_ERR_DEAD = Int32(12)
comptime DW_ERR_SERIALIZATION_FAILED = Int32(13)

comptime DW_FINANCES_DEPOSIT = UInt8(0)
comptime DW_FINANCES_WITHDRAW = UInt8(1)
comptime DW_FINANCES_PAY_LOAN = UInt8(2)

comptime DW_MAX_HIGHSCORES = 10


# ---------------------------------------------------------------------------
# ABI structs (mirror include/dopewars.h)
# ---------------------------------------------------------------------------


@fieldwise_init
struct Config(Copyable, Movable):
    var abi_version: UInt16
    var _pad0: UInt16
    var rng_seed: UInt32
    var num_days: UInt32
    var start_cash: Int32


@fieldwise_init
struct LocationView(Copyable, Movable):
    var id: Array[UInt8, 32]
    var name: Array[UInt8, 32]
    var police: UInt32
    var min_drugs: UInt32
    var max_drugs: UInt32
    var _pad0: UInt32


@fieldwise_init
struct DrugView(Copyable, Movable):
    var id: Array[UInt8, 32]
    var name: Array[UInt8, 32]
    var min_price: Int32
    var max_price: Int32
    var cheap: UInt8
    var expensive: UInt8
    var _pad0: Array[UInt8, 2]


@fieldwise_init
struct StateView(Copyable, Movable):
    var day: UInt32
    var num_days: UInt32
    var cash: Int32
    var bank: Int64
    var debt: Int64
    var health: Int32
    var coat_capacity: Int32
    var coat_used: Int32
    var guns: UInt32
    var location_index: UInt32
    var dead: UInt8
    var last_day_warned: UInt8
    var _pad0: Array[UInt8, 2]


@fieldwise_init
struct InventorySlot(Copyable, Movable):
    var drug_index: UInt32
    var qty: UInt32
    var avg_price_cents: Int64


@fieldwise_init
struct PriceSlot(Copyable, Movable):
    var drug_index: UInt32
    var price: Int32
    var was_event: UInt8
    var _pad0: Array[UInt8, 3]


@fieldwise_init
struct PriceEventView(Copyable, Movable):
    var kind: UInt8
    var _pad0: Array[UInt8, 3]
    var drug_index: UInt32


@fieldwise_init
struct ArrivalEventView(Copyable, Movable):
    var kind: UInt8
    var _pad0: Array[UInt8, 3]
    var drug_index: UInt32
    var qty: Int32
    var amount: Int32
    var damage: Int32
    var _pad1: Int32


@fieldwise_init
struct CoatOfferView(Copyable, Movable):
    var pockets: UInt32
    var price: Int32


@fieldwise_init
struct GunOfferView(Copyable, Movable):
    var price: Int32
    var damage: UInt32
    var space: UInt32
    var _pad0: UInt32


@fieldwise_init
struct PurchaseResultView(Copyable, Movable):
    var used_bank: UInt8
    var _pad0: Array[UInt8, 3]
    var fee: Int32


@fieldwise_init
struct ChaseView(Copyable, Movable):
    var deputies: UInt32
    var can_fight: UInt8
    var _pad0: Array[UInt8, 3]


@fieldwise_init
struct FightRatingsView(Copyable, Movable):
    var attack: UInt32
    var defend: UInt32


@fieldwise_init
struct RunResultView(Copyable, Movable):
    var escaped: UInt8
    var _pad0: Array[UInt8, 3]
    var damage_taken: Int32


@fieldwise_init
struct FightResultView(Copyable, Movable):
    var hit: UInt8
    var dead: UInt8
    var won: UInt8
    var _pad0: UInt8
    var damage_taken: Int32


@fieldwise_init
struct FinishResultView(Copyable, Movable):
    var score: Int64
    var day: UInt32
    var dead: UInt8
    var _pad0: Array[UInt8, 3]


@fieldwise_init
struct HighscoreEntryView(Copyable, Movable):
    var name: Array[UInt8, 32]
    var score: Int64
    var day: UInt32
    var dead: UInt8
    var _pad0: Array[UInt8, 3]


# The Mojo-side twin of the header's DW_STATIC_ASSERT. Called from the exported
# entry points so the asserts are instantiated at compile time.
def _assert_layouts():
    comptime assert size_of[Config]() == 16, "dw_config layout changed"
    comptime assert size_of[LocationView]() == 80, "dw_location_view layout changed"
    comptime assert size_of[DrugView]() == 76, "dw_drug_view layout changed"
    comptime assert size_of[StateView]() == 56, "dw_state_view layout changed"
    comptime assert size_of[InventorySlot]() == 16, "dw_inventory_slot layout changed"
    comptime assert size_of[PriceSlot]() == 12, "dw_price_slot layout changed"
    comptime assert size_of[PriceEventView]() == 8, "dw_price_event layout changed"
    comptime assert size_of[ArrivalEventView]() == 24, "dw_arrival_event layout changed"
    comptime assert size_of[CoatOfferView]() == 8, "dw_coat_offer layout changed"
    comptime assert size_of[GunOfferView]() == 16, "dw_gun_offer layout changed"
    comptime assert size_of[PurchaseResultView]() == 8, "dw_purchase_result layout changed"
    comptime assert size_of[ChaseView]() == 8, "dw_chase layout changed"
    comptime assert size_of[FightRatingsView]() == 8, "dw_fight_ratings layout changed"
    comptime assert size_of[RunResultView]() == 8, "dw_run_result layout changed"
    comptime assert size_of[FightResultView]() == 8, "dw_fight_result layout changed"
    comptime assert size_of[FinishResultView]() == 16, "dw_finish_result layout changed"
    comptime assert size_of[HighscoreEntryView]() == 48, "dw_highscore_entry layout changed"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _cstr_array[N: Int](s: String) -> Array[UInt8, N]:
    # Copies up to N-1 bytes of s into a NUL-terminated fixed array.
    var out = Array[UInt8, N](fill=0)
    var n = s.byte_length()
    if n > N - 1:
        n = N - 1
    for i in range(n):
        out[i] = UInt8(ord(s[byte=i]))
    return out^


def _bytes_to_string[N: Int](arr: Array[UInt8, N]) -> String:
    var bytes = List[UInt8]()
    for i in range(N):
        if arr[i] == 0:
            break
        bytes.append(arr[i])
    return String(StringSlice(unsafe_from_utf8=Span(bytes)))


def _cstr_to_string(ptr: Pointer[UInt8, origin=ImmUntrackedOrigin]) -> String:
    var bytes = List[UInt8]()
    var i = 0
    while ptr[unsafe_offset=i] != 0:
        bytes.append(ptr[unsafe_offset=i])
        i += 1
    return String(StringSlice(unsafe_from_utf8=Span(bytes)))


def _map_trade_code(code: Int) -> Int32:
    if code == result.OK:
        return DW_OK
    if code == result.ERR_NOT_TRADED_HERE:
        return DW_ERR_NOT_TRADED_HERE
    if code == result.ERR_INSUFFICIENT_CASH:
        return DW_ERR_INSUFFICIENT_CASH
    if code == result.ERR_INSUFFICIENT_SPACE:
        return DW_ERR_INSUFFICIENT_SPACE
    if code == result.ERR_INSUFFICIENT_INVENTORY:
        return DW_ERR_INSUFFICIENT_INVENTORY
    return DW_ERR_INVALID_ARGUMENT


def _map_purchase_code(code: Int) -> Int32:
    if code == result.OK:
        return DW_OK
    if code == result.ERR_INSUFFICIENT_BANK:
        return DW_ERR_INSUFFICIENT_BANK
    if code == result.ERR_INSUFFICIENT_SPACE:
        return DW_ERR_INSUFFICIENT_SPACE
    return DW_ERR_INVALID_ARGUMENT


def _highscore_from_view(view: HighscoreEntryView) -> score.HighScore:
    return score.HighScore(
        _bytes_to_string(view.name),
        Float64(view.score),
        Int64(view.day),
        view.dead != 0,
        "",
    )


def _view_from_highscore(entry: score.HighScore) -> HighscoreEntryView:
    return HighscoreEntryView(
        _cstr_array[32](entry.name),
        Int64(entry.score),
        UInt32(entry.day),
        UInt8(1) if entry.dead else UInt8(0),
        Array[UInt8, 3](fill=0),
    )


def _validate_world(ref game: world_mod.World) -> Bool:
    if game.location_index < 0 or game.location_index >= rules.NUM_LOCATIONS:
        return False
    if game.price_order_len < 0 or game.price_order_len > rules.NUM_DRUGS:
        return False
    for i in range(game.price_order_len):
        if Int(game.price_order[i]) >= rules.NUM_DRUGS:
            return False
    if game.prev_price_order_len < 0 or game.prev_price_order_len > rules.NUM_DRUGS:
        return False
    for i in range(game.prev_price_order_len):
        if Int(game.prev_price_order[i]) >= rules.NUM_DRUGS:
            return False
    if game.inv_order_len < 0 or game.inv_order_len > rules.NUM_DRUGS:
        return False
    for i in range(game.inv_order_len):
        if Int(game.inv_order[i]) >= rules.NUM_DRUGS:
            return False
    if game.price_events_len < 0 or game.price_events_len > world_mod.MAX_PRICE_EVENTS:
        return False
    return True


# ---------------------------------------------------------------------------
# Versioning
# ---------------------------------------------------------------------------


@export("dw_abi_version")
def dw_abi_version() abi("C") -> UInt32:
    _assert_layouts()
    return UInt32(DW_ABI_VERSION)


# ---------------------------------------------------------------------------
# RULES accessors
# ---------------------------------------------------------------------------


@export("dw_rules_default_num_days")
def dw_rules_default_num_days() abi("C") -> UInt32:
    return UInt32(rules.NUM_DAYS)


@export("dw_rules_default_start_cash")
def dw_rules_default_start_cash() abi("C") -> Int32:
    return Int32(rules.START_CASH)


@export("dw_rules_default_start_debt")
def dw_rules_default_start_debt() abi("C") -> Int64:
    return Int64(rules.START_DEBT)


@export("dw_rules_default_start_health")
def dw_rules_default_start_health() abi("C") -> Int32:
    return Int32(rules.START_HEALTH)


@export("dw_rules_default_start_coat_capacity")
def dw_rules_default_start_coat_capacity() abi("C") -> Int32:
    return Int32(rules.START_COAT_CAPACITY)


@export("dw_rules_default_start_location_index")
def dw_rules_default_start_location_index() abi("C") -> Int32:
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
    return UInt32(jsmath.js_round(rules.DEBT_INTEREST * 10000.0))


@export("dw_rules_bank_interest_bp")
def dw_rules_bank_interest_bp() abi("C") -> UInt32:
    return UInt32(jsmath.js_round(rules.BANK_INTEREST * 10000.0))


@export("dw_rules_bank_purchase_fee_bp")
def dw_rules_bank_purchase_fee_bp() abi("C") -> UInt32:
    return UInt32(jsmath.js_round(rules.BANK_PURCHASE_FEE * 10000.0))


@export("dw_rules_cheap_divide")
def dw_rules_cheap_divide() abi("C") -> UInt32:
    return UInt32(rules.CHEAP_DIVIDE)


@export("dw_rules_expensive_multiply")
def dw_rules_expensive_multiply() abi("C") -> UInt32:
    return UInt32(rules.EXPENSIVE_MULTIPLY)


@export("dw_rules_locations_copy")
def dw_rules_locations_copy(
    out_locations: OptionalPointer[LocationView, origin=MutUntrackedOrigin],
    out_capacity: UInt,
    out_required: OptionalPointer[UInt, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not out_required:
        return DW_ERR_INVALID_ARGUMENT
    var required = UInt(rules.NUM_LOCATIONS)
    out_required.value()[] = required
    if not out_locations or out_capacity == 0:
        return DW_OK
    if out_capacity < required:
        return DW_ERR_BUFFER_TOO_SMALL
    var table = rules.locations()
    for i in range(rules.NUM_LOCATIONS):
        out_locations.value()[unsafe_offset=i] = LocationView(
            _cstr_array[32](table[i].id),
            _cstr_array[32](table[i].name),
            UInt32(table[i].police),
            UInt32(table[i].min_drugs),
            UInt32(table[i].max_drugs),
            UInt32(0),
        )
    return DW_OK


@export("dw_rules_drugs_copy")
def dw_rules_drugs_copy(
    out_drugs: OptionalPointer[DrugView, origin=MutUntrackedOrigin],
    out_capacity: UInt,
    out_required: OptionalPointer[UInt, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not out_required:
        return DW_ERR_INVALID_ARGUMENT
    var required = UInt(rules.NUM_DRUGS)
    out_required.value()[] = required
    if not out_drugs or out_capacity == 0:
        return DW_OK
    if out_capacity < required:
        return DW_ERR_BUFFER_TOO_SMALL
    var table = rules.drugs()
    for i in range(rules.NUM_DRUGS):
        out_drugs.value()[unsafe_offset=i] = DrugView(
            _cstr_array[32](table[i].id),
            _cstr_array[32](table[i].name),
            Int32(table[i].min_price),
            Int32(table[i].max_price),
            UInt8(1) if table[i].cheap else UInt8(0),
            UInt8(1) if table[i].expensive else UInt8(0),
            Array[UInt8, 2](fill=0),
        )
    return DW_OK


# Length queries for the two copies above. Additive (no DW_ABI_VERSION bump):
# the required length is a compile-time constant, so a caller can size its
# buffer without a world handle or an out-pointer. The conformance suite
# asserts these agree with the DW_NUM_* macros and the *out_required of the
# copy functions.


@export("dw_rules_locations_len")
def dw_rules_locations_len() abi("C") -> UInt32:
    return UInt32(rules.NUM_LOCATIONS)


@export("dw_rules_drugs_len")
def dw_rules_drugs_len() abi("C") -> UInt32:
    return UInt32(rules.NUM_DRUGS)


# ---------------------------------------------------------------------------
# RNG (mulberry32)
# ---------------------------------------------------------------------------


@export("dw_mulberry32_seed")
def dw_mulberry32_seed(seed: UInt32, out_state: OptionalPointer[UInt32, origin=MutUntrackedOrigin]) abi("C"):
    if out_state:
        out_state.value()[] = seed


@export("dw_mulberry32_next_u32")
def dw_mulberry32_next_u32(state: OptionalPointer[UInt32, origin=MutUntrackedOrigin]) abi("C") -> UInt32:
    if not state:
        return UInt32(0)
    var draw = rng_mod.mulberry32_draw(state.value()[])
    state.value()[] = rng_mod.mulberry32_advance(state.value()[])
    return draw


@export("dw_rand_int")
def dw_rand_int(
    state: OptionalPointer[UInt32, origin=MutUntrackedOrigin],
    min_value: Int32,
    max_value: Int32,
    out_value: OptionalPointer[Int32, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not state or not out_value:
        return DW_ERR_INVALID_ARGUMENT
    if min_value > max_value:
        return DW_ERR_INVALID_ARGUMENT
    var draw = rng_mod.mulberry32_draw(state.value()[])
    state.value()[] = rng_mod.mulberry32_advance(state.value()[])
    var normalized = Float64(draw) / 4294967296.0
    var span = Int64(max_value) - Int64(min_value) + 1
    out_value.value()[] = Int32(Int64(min_value) + jsmath.js_floor(normalized * Float64(span)))
    return DW_OK


# ---------------------------------------------------------------------------
# World lifecycle
# ---------------------------------------------------------------------------


@export("dw_world_size")
def dw_world_size() abi("C") -> UInt:
    _assert_layouts()
    return UInt(size_of[world_mod.World]())


@export("dw_world_align")
def dw_world_align() abi("C") -> UInt:
    return UInt(align_of[world_mod.World]())


@export("dw_world_init")
def dw_world_init(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    config: OptionalPointer[Config, origin=ImmUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not config:
        return DW_ERR_INVALID_ARGUMENT
    ref cfg = config.value()[]
    if cfg.abi_version != UInt16(DW_ABI_VERSION):
        return DW_ERR_ABI_VERSION_MISMATCH
    try:
        var game = world_mod.new_game(cfg.rng_seed, Int64(cfg.num_days), Int64(cfg.start_cash))
        world.value().unsafe_write(game^)
    except:
        return DW_ERR_INVALID_ARGUMENT
    return DW_OK


@export("dw_world_reset")
def dw_world_reset(world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin]) abi("C") -> Int32:
    if not world:
        return DW_ERR_INVALID_ARGUMENT
    var seed = world.value()[].seed
    var num_days = world.value()[].num_days
    var start_cash = world.value()[].start_cash
    try:
        var game = world_mod.new_game(seed, num_days, Int64(start_cash))
        world.value().unsafe_write(game^)
    except:
        return DW_ERR_INVALID_ARGUMENT
    return DW_OK


# ---------------------------------------------------------------------------
# Live-state queries
# ---------------------------------------------------------------------------


@export("dw_state_get")
def dw_state_get(
    world: OptionalPointer[world_mod.World, origin=ImmUntrackedOrigin],
    out_view: OptionalPointer[StateView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_view:
        return DW_ERR_INVALID_ARGUMENT
    ref game = world.value()[]
    out_view.value().unsafe_write(
        StateView(
            UInt32(game.day),
            UInt32(game.num_days),
            Int32(game.cash),
            Int64(game.bank),
            Int64(game.debt),
            Int32(game.health),
            Int32(game.coat_capacity),
            Int32(game.coat_used()),
            UInt32(game.guns),
            UInt32(game.location_index),
            UInt8(1) if game.dead else UInt8(0),
            UInt8(1) if game.last_day_warned else UInt8(0),
            Array[UInt8, 2](fill=0),
        )
    )
    return DW_OK


@export("dw_coat_used")
def dw_coat_used(
    world: OptionalPointer[world_mod.World, origin=ImmUntrackedOrigin],
    out_used: OptionalPointer[Int32, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_used:
        return DW_ERR_INVALID_ARGUMENT
    out_used.value()[] = Int32(world.value()[].coat_used())
    return DW_OK


@export("dw_prices_copy")
def dw_prices_copy(
    world: OptionalPointer[world_mod.World, origin=ImmUntrackedOrigin],
    out_prices: OptionalPointer[PriceSlot, origin=MutUntrackedOrigin],
    out_capacity: UInt,
    out_required: OptionalPointer[UInt, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_required:
        return DW_ERR_INVALID_ARGUMENT
    ref game = world.value()[]
    var required = UInt(game.price_count())
    out_required.value()[] = required
    if not out_prices or out_capacity == 0:
        return DW_OK
    if out_capacity < required:
        return DW_ERR_BUFFER_TOO_SMALL
    for i in range(game.price_count()):
        var drug_index = Int(game.price_order[i])
        out_prices.value()[unsafe_offset=i] = PriceSlot(
            UInt32(drug_index),
            Int32(game.price_value[drug_index]),
            UInt8(1) if game.price_was_event[drug_index] != 0 else UInt8(0),
            Array[UInt8, 3](fill=0),
        )
    return DW_OK


# The previous turn's price table, for the caller's per-drug price-delta
# display. The world does not keep a was_event flag per previous-turn slot
# (the JS prevPrices is a bare id -> price map, `index.html:719`), so
# was_event is always 0 here; the delta display only reads the price.
@export("dw_prev_prices_copy")
def dw_prev_prices_copy(
    world: OptionalPointer[world_mod.World, origin=ImmUntrackedOrigin],
    out_prices: OptionalPointer[PriceSlot, origin=MutUntrackedOrigin],
    out_capacity: UInt,
    out_required: OptionalPointer[UInt, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_required:
        return DW_ERR_INVALID_ARGUMENT
    ref game = world.value()[]
    var required = UInt(game.prev_price_count())
    out_required.value()[] = required
    if not out_prices or out_capacity == 0:
        return DW_OK
    if out_capacity < required:
        return DW_ERR_BUFFER_TOO_SMALL
    for i in range(game.prev_price_count()):
        var drug_index = Int(game.prev_price_order[i])
        out_prices.value()[unsafe_offset=i] = PriceSlot(
            UInt32(drug_index),
            Int32(game.prev_price_value[drug_index]),
            UInt8(0),
            Array[UInt8, 3](fill=0),
        )
    return DW_OK


@export("dw_inventory_copy")
def dw_inventory_copy(
    world: OptionalPointer[world_mod.World, origin=ImmUntrackedOrigin],
    out_inventory: OptionalPointer[InventorySlot, origin=MutUntrackedOrigin],
    out_capacity: UInt,
    out_required: OptionalPointer[UInt, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_required:
        return DW_ERR_INVALID_ARGUMENT
    ref game = world.value()[]
    var required = UInt(game.inv_count())
    out_required.value()[] = required
    if not out_inventory or out_capacity == 0:
        return DW_OK
    if out_capacity < required:
        return DW_ERR_BUFFER_TOO_SMALL
    for i in range(game.inv_count()):
        var drug_index = Int(game.inv_order[i])
        out_inventory.value()[unsafe_offset=i] = InventorySlot(
            UInt32(drug_index),
            UInt32(game.inv_qty[drug_index]),
            Int64(game.inv_avg_price[drug_index] * 100.0),
        )
    return DW_OK


@export("dw_find_drug_index")
def dw_find_drug_index(
    id: OptionalPointer[UInt8, origin=ImmUntrackedOrigin],
    out_index: OptionalPointer[UInt32, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not id or not out_index:
        return DW_ERR_INVALID_ARGUMENT
    var index = rules.find_drug_index(_cstr_to_string(id.value()))
    if index < 0:
        return DW_ERR_UNKNOWN_DRUG
    out_index.value()[] = UInt32(index)
    return DW_OK


@export("dw_find_location_index")
def dw_find_location_index(
    id: OptionalPointer[UInt8, origin=ImmUntrackedOrigin],
    out_index: OptionalPointer[UInt32, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not id or not out_index:
        return DW_ERR_INVALID_ARGUMENT
    var index = rules.find_location_index(_cstr_to_string(id.value()))
    if index < 0:
        return DW_ERR_UNKNOWN_LOCATION
    out_index.value()[] = UInt32(index)
    return DW_OK


# ---------------------------------------------------------------------------
# Turn actions
# ---------------------------------------------------------------------------


@export("dw_generate_prices")
def dw_generate_prices(world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin]) abi("C") -> Int32:
    if not world:
        return DW_ERR_INVALID_ARGUMENT
    try:
        _ = prices.generate_prices(world.value()[])
    except:
        return DW_ERR_INVALID_ARGUMENT
    return DW_OK


@export("dw_price_events_drain")
def dw_price_events_drain(
    world: OptionalPointer[world_mod.World, origin=ImmUntrackedOrigin],
    out_events: OptionalPointer[PriceEventView, origin=MutUntrackedOrigin],
    out_capacity: UInt,
    out_required: OptionalPointer[UInt, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_required:
        return DW_ERR_INVALID_ARGUMENT
    ref game = world.value()[]
    var required = UInt(game.price_events_len)
    out_required.value()[] = required
    if not out_events or out_capacity == 0:
        return DW_OK
    if out_capacity < required:
        return DW_ERR_BUFFER_TOO_SMALL
    for i in range(game.price_events_len):
        out_events.value()[unsafe_offset=i] = PriceEventView(
            UInt8(game.price_events[i].kind),
            Array[UInt8, 3](fill=0),
            UInt32(game.price_events[i].drug_index),
        )
    return DW_OK


@export("dw_buy")
def dw_buy(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    drug_index: UInt32,
    qty: UInt32,
) abi("C") -> Int32:
    if not world:
        return DW_ERR_INVALID_ARGUMENT
    if drug_index >= UInt32(rules.NUM_DRUGS):
        return DW_ERR_UNKNOWN_DRUG
    try:
        var outcome = trade.buy(world.value()[], Int(drug_index), Int64(qty))
        return _map_trade_code(outcome.code)
    except:
        return DW_ERR_INVALID_ARGUMENT


@export("dw_sell")
def dw_sell(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    drug_index: UInt32,
    qty: UInt32,
) abi("C") -> Int32:
    if not world:
        return DW_ERR_INVALID_ARGUMENT
    if drug_index >= UInt32(rules.NUM_DRUGS):
        return DW_ERR_UNKNOWN_DRUG
    try:
        var outcome = trade.sell(world.value()[], Int(drug_index), Int64(qty))
        return _map_trade_code(outcome.code)
    except:
        return DW_ERR_INVALID_ARGUMENT


@export("dw_travel")
def dw_travel(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    dest_location_index: UInt32,
) abi("C") -> Int32:
    if not world:
        return DW_ERR_INVALID_ARGUMENT
    if dest_location_index >= UInt32(rules.NUM_LOCATIONS):
        return DW_ERR_UNKNOWN_LOCATION
    try:
        var outcome = travel.travel(world.value()[], Int(dest_location_index))
        if outcome.code == result.ERR_ALREADY_THERE:
            return DW_ERR_INVALID_ARGUMENT
        if outcome.code == result.ERR_UNKNOWN_LOCATION:
            return DW_ERR_UNKNOWN_LOCATION
        if outcome.code == result.ERR_DEAD:
            return DW_ERR_DEAD
        if outcome.code == result.ERR_GAME_OVER:
            return DW_ERR_GAME_OVER
        return DW_OK
    except:
        return DW_ERR_INVALID_ARGUMENT


@export("dw_finances")
def dw_finances(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    action: UInt8,
    amount: Int64,
    out_actual: OptionalPointer[Int64, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_actual:
        return DW_ERR_INVALID_ARGUMENT
    var core_action = -1
    if action == DW_FINANCES_DEPOSIT:
        core_action = finances.ACTION_DEPOSIT
    elif action == DW_FINANCES_WITHDRAW:
        core_action = finances.ACTION_WITHDRAW
    elif action == DW_FINANCES_PAY_LOAN:
        core_action = finances.ACTION_PAY_LOAN
    if core_action < 0:
        return DW_ERR_INVALID_ARGUMENT
    try:
        var outcome = finances.finances(world.value()[], core_action, Float64(amount))
        out_actual.value()[] = outcome.amount
        return DW_OK
    except:
        return DW_ERR_INVALID_ARGUMENT


# ---------------------------------------------------------------------------
# Arrival / dealer events
# ---------------------------------------------------------------------------


@export("dw_roll_arrival_event")
def dw_roll_arrival_event(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    out_event: OptionalPointer[ArrivalEventView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_event:
        return DW_ERR_INVALID_ARGUMENT
    try:
        var event = events.roll_arrival_event(world.value()[])
        var drug_index = UInt32(0)
        if event.drug_index >= 0:
            drug_index = UInt32(event.drug_index)
        out_event.value().unsafe_write(
            ArrivalEventView(
                UInt8(event.kind),
                Array[UInt8, 3](fill=0),
                drug_index,
                Int32(event.qty),
                Int32(event.amount),
                Int32(event.damage),
                Int32(0),
            )
        )
        return DW_OK
    except:
        return DW_ERR_INVALID_ARGUMENT


@export("dw_roll_coat_dealer_offer")
def dw_roll_coat_dealer_offer(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    out_offer: OptionalPointer[CoatOfferView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_offer:
        return DW_ERR_INVALID_ARGUMENT
    try:
        var offer = dealers.roll_coat_dealer_offer(world.value()[])
        out_offer.value().unsafe_write(CoatOfferView(UInt32(offer.pockets), Int32(offer.price)))
        return DW_OK
    except:
        return DW_ERR_INVALID_ARGUMENT


@export("dw_accept_coat_offer")
def dw_accept_coat_offer(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    offer: OptionalPointer[CoatOfferView, origin=ImmUntrackedOrigin],
    out_result: OptionalPointer[PurchaseResultView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not offer or not out_result:
        return DW_ERR_INVALID_ARGUMENT
    var core_offer = dealers.CoatOffer(Int64(offer.value()[].pockets), Int64(offer.value()[].price))
    var payment = dealers.accept_coat_offer(world.value()[], core_offer)
    out_result.value().unsafe_write(
        PurchaseResultView(
            UInt8(1) if payment.used_bank else UInt8(0),
            Array[UInt8, 3](fill=0),
            Int32(payment.fee),
        )
    )
    return _map_purchase_code(payment.code)


@export("dw_roll_gun_dealer_offer")
def dw_roll_gun_dealer_offer(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    out_offer: OptionalPointer[GunOfferView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_offer:
        return DW_ERR_INVALID_ARGUMENT
    try:
        var offer = dealers.roll_gun_dealer_offer(world.value()[])
        out_offer.value().unsafe_write(
            GunOfferView(Int32(offer.price), UInt32(offer.damage), UInt32(offer.space), UInt32(0))
        )
        return DW_OK
    except:
        return DW_ERR_INVALID_ARGUMENT


@export("dw_accept_gun_offer")
def dw_accept_gun_offer(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    offer: OptionalPointer[GunOfferView, origin=ImmUntrackedOrigin],
    out_result: OptionalPointer[PurchaseResultView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not offer or not out_result:
        return DW_ERR_INVALID_ARGUMENT
    var core_offer = dealers.GunOffer(
        Int64(offer.value()[].price),
        Int64(offer.value()[].damage),
        Int64(offer.value()[].space),
    )
    var payment = dealers.accept_gun_offer(world.value()[], core_offer)
    out_result.value().unsafe_write(
        PurchaseResultView(
            UInt8(1) if payment.used_bank else UInt8(0),
            Array[UInt8, 3](fill=0),
            Int32(payment.fee),
        )
    )
    return _map_purchase_code(payment.code)


@export("dw_roll_dealer_visits")
def dw_roll_dealer_visits(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    out_coat_visit: OptionalPointer[UInt8, origin=MutUntrackedOrigin],
    out_gun_visit: OptionalPointer[UInt8, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_coat_visit or not out_gun_visit:
        return DW_ERR_INVALID_ARGUMENT
    try:
        var visits = dealers.roll_dealer_visits(world.value()[])
        out_coat_visit.value()[] = UInt8(1) if visits.coat else UInt8(0)
        out_gun_visit.value()[] = UInt8(1) if visits.gun else UInt8(0)
        return DW_OK
    except:
        return DW_ERR_INVALID_ARGUMENT


# ---------------------------------------------------------------------------
# Chase / combat
# ---------------------------------------------------------------------------


@export("dw_should_start_chase")
def dw_should_start_chase(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    out_should_start: OptionalPointer[UInt8, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_should_start:
        return DW_ERR_INVALID_ARGUMENT
    try:
        var should = combat.should_start_chase(world.value()[])
        out_should_start.value()[] = UInt8(1) if should else UInt8(0)
        return DW_OK
    except:
        return DW_ERR_INVALID_ARGUMENT


@export("dw_start_chase")
def dw_start_chase(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    out_chase: OptionalPointer[ChaseView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_chase:
        return DW_ERR_INVALID_ARGUMENT
    try:
        ref game = world.value()[]
        var chase = combat.start_chase(game)
        out_chase.value().unsafe_write(
            ChaseView(
                UInt32(chase.deputies),
                UInt8(1) if game.guns > 0 else UInt8(0),
                Array[UInt8, 3](fill=0),
            )
        )
        return DW_OK
    except:
        return DW_ERR_INVALID_ARGUMENT


@export("dw_get_fight_ratings")
def dw_get_fight_ratings(
    world: OptionalPointer[world_mod.World, origin=ImmUntrackedOrigin],
    out_ratings: OptionalPointer[FightRatingsView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_ratings:
        return DW_ERR_INVALID_ARGUMENT
    var ratings = combat.get_fight_ratings(world.value()[])
    out_ratings.value().unsafe_write(
        FightRatingsView(UInt32(ratings.attack), UInt32(ratings.defend))
    )
    return DW_OK


@export("dw_run_from_chase")
def dw_run_from_chase(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    chase: OptionalPointer[ChaseView, origin=MutUntrackedOrigin],
    is_aggressor: UInt8,
    out_result: OptionalPointer[RunResultView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not chase or not out_result:
        return DW_ERR_INVALID_ARGUMENT
    var before = world.value()[].health
    var core_chase = combat.Chase(Int64(chase.value()[].deputies))
    try:
        var escaped = combat.run_from_chase(world.value()[], core_chase, is_aggressor != 0)
        var damage = before - world.value()[].health
        out_result.value().unsafe_write(
            RunResultView(
                UInt8(1) if escaped else UInt8(0),
                Array[UInt8, 3](fill=0),
                Int32(damage),
            )
        )
        return DW_OK
    except:
        return DW_ERR_INVALID_ARGUMENT


@export("dw_fight")
def dw_fight(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    chase: OptionalPointer[ChaseView, origin=MutUntrackedOrigin],
    out_result: OptionalPointer[FightResultView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not chase or not out_result:
        return DW_ERR_INVALID_ARGUMENT
    var core_chase = combat.Chase(Int64(chase.value()[].deputies))
    try:
        var outcome = combat.fight(world.value()[], core_chase)
        chase.value()[].deputies = UInt32(core_chase.deputies)
        out_result.value().unsafe_write(
            FightResultView(
                UInt8(1) if outcome.hit else UInt8(0),
                UInt8(1) if outcome.dead else UInt8(0),
                UInt8(1) if outcome.won else UInt8(0),
                UInt8(0),
                Int32(outcome.damage),
            )
        )
        return DW_OK
    except:
        return DW_ERR_INVALID_ARGUMENT


@export("dw_apply_damage")
def dw_apply_damage(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    amount: Int32,
    out_health: OptionalPointer[Int32, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_health:
        return DW_ERR_INVALID_ARGUMENT
    var health = events.apply_damage(world.value()[], Int64(amount))
    out_health.value()[] = Int32(health)
    return DW_OK


# ---------------------------------------------------------------------------
# Endgame
# ---------------------------------------------------------------------------


@export("dw_finish")
def dw_finish(
    world: OptionalPointer[world_mod.World, origin=ImmUntrackedOrigin],
    out_result: OptionalPointer[FinishResultView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_result:
        return DW_ERR_INVALID_ARGUMENT
    var outcome = score.finish(world.value()[])
    out_result.value().unsafe_write(
        FinishResultView(
            Int64(outcome.score),
            UInt32(outcome.day),
            UInt8(1) if outcome.dead else UInt8(0),
            Array[UInt8, 3](fill=0),
        )
    )
    return DW_OK


@export("dw_insert_highscore")
def dw_insert_highscore(
    scores: OptionalPointer[HighscoreEntryView, origin=MutUntrackedOrigin],
    scores_capacity: UInt,
    in_count: UInt,
    entry: OptionalPointer[HighscoreEntryView, origin=ImmUntrackedOrigin],
    out_count: OptionalPointer[UInt, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not scores or not entry or not out_count:
        return DW_ERR_INVALID_ARGUMENT
    if scores_capacity < UInt(DW_MAX_HIGHSCORES):
        return DW_ERR_BUFFER_TOO_SMALL
    var list = List[score.HighScore]()
    for i in range(Int(in_count)):
        list.append(_highscore_from_view(scores.value()[unsafe_offset=i]))
    score.insert_high_score(list, _highscore_from_view(entry.value()[]))
    for i in range(len(list)):
        scores.value()[unsafe_offset=i] = _view_from_highscore(list[i])
    out_count.value()[] = UInt(len(list))
    return DW_OK


# ---------------------------------------------------------------------------
# Canonical serialization
# ---------------------------------------------------------------------------


@export("dw_world_dump_len")
def dw_world_dump_len() abi("C") -> UInt:
    return UInt(serialize.DUMP_LEN)


@export("dw_world_dump")
def dw_world_dump(
    world: OptionalPointer[world_mod.World, origin=ImmUntrackedOrigin],
    out_buf: OptionalPointer[UInt8, origin=MutUntrackedOrigin],
    out_capacity: UInt,
    out_written: OptionalPointer[UInt, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_written:
        return DW_ERR_INVALID_ARGUMENT
    var required = UInt(serialize.DUMP_LEN)
    out_written.value()[] = required
    if not out_buf or out_capacity == 0:
        return DW_OK
    if out_capacity < required:
        return DW_ERR_BUFFER_TOO_SMALL
    try:
        var bytes = serialize.dump(world.value()[])
        for i in range(Int(required)):
            out_buf.value()[unsafe_offset=i] = bytes[i]
    except:
        return DW_ERR_SERIALIZATION_FAILED
    return DW_OK


@export("dw_world_load")
def dw_world_load(
    world: OptionalPointer[world_mod.World, origin=MutUntrackedOrigin],
    buf: OptionalPointer[UInt8, origin=ImmUntrackedOrigin],
    buf_len: UInt,
) abi("C") -> Int32:
    if not world or not buf:
        return DW_ERR_INVALID_ARGUMENT
    if buf_len != UInt(serialize.DUMP_LEN):
        return DW_ERR_SERIALIZATION_FAILED
    var bytes = List[UInt8]()
    for i in range(Int(buf_len)):
        bytes.append(buf.value()[unsafe_offset=i])
    try:
        var loaded = serialize.load(bytes)
        if not _validate_world(loaded):
            return DW_ERR_SERIALIZATION_FAILED
        world.value().unsafe_write(loaded^)
    except:
        return DW_ERR_SERIALIZATION_FAILED
    return DW_OK
