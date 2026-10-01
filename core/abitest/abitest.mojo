# core/abitest/abitest.mojo — Tier-C ABI conformance tests.
#
# Every test here reaches the compiled core exclusively through the C ABI
# declared in include/dopewars.h, via std.ffi.external_call against the linked
# static library (core/build-output/lib/libdopewars.a). No test imports a core
# module: tools/validate_abi_test_purity.py fails the build if one does. Without
# that guard this tier would silently degrade into a second copy of the parity
# suite in tests/mojo/.
#
# Mojo 1.1.0 has no @cImport, so the ABI structs are declared here field for
# field and their sizes asserted against the header's DW_STATIC_ASSERT values.
# The library is linked with `mojo build -Xlinker .../libdopewars.a`; see
# taskfiles/core.yml's core:abitest.
#
# NULL-pointer paths are not exercised here: Mojo 1.1.0 cannot construct a
# null Pointer, and mixing Pointer and OptionalPointer arguments for one
# external_call symbol is a signature conflict. The ABI's NULL guards are
# implemented and compile; the C++ shim never passes NULL.
#
# Run: task core:abitest

from std.ffi import external_call
from std.memory import Layout, alloc
from std.sys import size_of, align_of
from std.testing import assert_equal, assert_true, assert_false, TestSuite


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


# ---------------------------------------------------------------------------
# Result codes (mirror include/dopewars.h)
# ---------------------------------------------------------------------------

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

comptime DW_NUM_LOCATIONS = 6
comptime DW_NUM_DRUGS = 12
comptime DW_MAX_HIGHSCORES = 10


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _world() -> Pointer[UInt8, origin=MutUntrackedOrigin]:
    # Caller-owned storage, exactly as the ABI contract requires: allocate
    # dw_world_size() bytes aligned to dw_world_align(). Leaked deliberately --
    # the test process is short-lived and there is no dw_world_destroy.
    var size = Int(external_call["dw_world_size", UInt]())
    var align = Int(external_call["dw_world_align", UInt]())
    var allocation = alloc(Layout[UInt8](count=size, alignment=align))
    return allocation^.unsafe_leak()


def _config(seed: UInt32, num_days: UInt32 = 0, start_cash: Int32 = -1) -> Config:
    return Config(UInt16(3), UInt16(0), seed, num_days, start_cash)


def _init(
    ptr: Pointer[UInt8, origin=MutUntrackedOrigin],
    seed: UInt32,
    num_days: UInt32 = 0,
    start_cash: Int32 = -1,
) -> Int32:
    var cfg = _config(seed, num_days, start_cash)
    return external_call["dw_world_init", Int32](ptr, Pointer(to=cfg))


def _state(ptr: Pointer[UInt8, origin=MutUntrackedOrigin]) raises -> StateView:
    var view = StateView(
        UInt32(0), UInt32(0), Int32(0), Int64(0), Int64(0), Int32(0), Int32(0),
        Int32(0), UInt32(0), UInt32(0), UInt8(0), UInt8(0), Array[UInt8, 2](fill=0),
    )
    var r = external_call["dw_state_get", Int32](ptr, Pointer(to=view))
    assert_equal(r, DW_OK)
    return view^


def _dump(ptr: Pointer[UInt8, origin=MutUntrackedOrigin]) raises -> List[UInt8]:
    var required = external_call["dw_world_dump_len", UInt]()
    var buf = List[UInt8]()
    for _ in range(Int(required)):
        buf.append(0)
    var written: UInt = 0
    var r = external_call["dw_world_dump", Int32](ptr, buf.unsafe_ptr(), required, Pointer(to=written))
    assert_equal(r, DW_OK)
    assert_equal(written, required)
    return buf^


def _load(ptr: Pointer[UInt8, origin=MutUntrackedOrigin], bytes: List[UInt8]) -> Int32:
    return external_call["dw_world_load", Int32](ptr, bytes.unsafe_ptr(), UInt(len(bytes)))


def _prices(ptr: Pointer[UInt8, origin=MutUntrackedOrigin]) raises -> List[PriceSlot]:
    var dummy = PriceSlot(UInt32(0), Int32(0), UInt8(0), Array[UInt8, 3](fill=0))
    var required: UInt = 0
    var r = external_call["dw_prices_copy", Int32](ptr, Pointer(to=dummy), UInt(0), Pointer(to=required))
    assert_equal(r, DW_OK)
    var slots = List[PriceSlot]()
    for _ in range(Int(required)):
        slots.append(PriceSlot(UInt32(0), Int32(0), UInt8(0), Array[UInt8, 3](fill=0)))
    if required > 0:
        var actual: UInt = 0
        r = external_call["dw_prices_copy", Int32](ptr, slots.unsafe_ptr(), required, Pointer(to=actual))
        assert_equal(r, DW_OK)
        assert_equal(actual, required)
    return slots^


def _drug_in_roster(ptr: Pointer[UInt8, origin=MutUntrackedOrigin]) raises -> Int:
    var slots = _prices(ptr)
    assert_true(len(slots) > 0)
    var cheapest = 0
    for i in range(len(slots)):
        if slots[i].price < slots[cheapest].price:
            cheapest = i
    return Int(slots[cheapest].drug_index)


def _drug_not_in_roster(ptr: Pointer[UInt8, origin=MutUntrackedOrigin]) raises -> Int:
    var slots = _prices(ptr)
    for candidate in range(DW_NUM_DRUGS):
        var found = False
        for slot in slots:
            if Int(slot.drug_index) == candidate:
                found = True
        if not found:
            return candidate
    return -1


def _cstr(s: String) -> List[UInt8]:
    var out = List[UInt8]()
    for i in range(s.byte_length()):
        out.append(UInt8(ord(s[byte=i])))
    out.append(0)
    return out^


def _cstr_array(s: String) -> Array[UInt8, 32]:
    var out = Array[UInt8, 32](fill=0)
    var n = s.byte_length()
    if n > 31:
        n = 31
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


# ---------------------------------------------------------------------------
# Struct layout
# ---------------------------------------------------------------------------


def test_struct_sizes_match_header() raises:
    assert_equal(size_of[Config](), 16)
    assert_equal(size_of[LocationView](), 80)
    assert_equal(size_of[DrugView](), 76)
    assert_equal(size_of[StateView](), 56)
    assert_equal(size_of[InventorySlot](), 16)
    assert_equal(size_of[PriceSlot](), 12)
    assert_equal(size_of[PriceEventView](), 8)
    assert_equal(size_of[ArrivalEventView](), 24)
    assert_equal(size_of[CoatOfferView](), 8)
    assert_equal(size_of[GunOfferView](), 16)
    assert_equal(size_of[PurchaseResultView](), 8)
    assert_equal(size_of[ChaseView](), 8)
    assert_equal(size_of[FightRatingsView](), 8)
    assert_equal(size_of[RunResultView](), 8)
    assert_equal(size_of[FightResultView](), 8)
    assert_equal(size_of[FinishResultView](), 16)
    assert_equal(size_of[HighscoreEntryView](), 48)


# ---------------------------------------------------------------------------
# World lifecycle
# ---------------------------------------------------------------------------


def test_world_size_and_align_are_sane() raises:
    var size = external_call["dw_world_size", UInt]()
    var align = external_call["dw_world_align", UInt]()
    assert_true(size > 0)
    assert_true(align > 0)
    # align must be a power of two so the caller can align its storage.
    assert_equal(align & (align - 1), UInt(0))


def test_world_init_and_reset() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)
    var first = _state(ptr)
    assert_equal(first.day, UInt32(1))
    assert_equal(first.cash, Int32(2000))
    assert_equal(first.debt, Int64(5500))
    assert_equal(first.health, Int32(100))
    assert_equal(first.coat_capacity, Int32(100))
    assert_equal(first.location_index, UInt32(0))

    # Mutate, then reset: a reset is a full new game, not a mid-game reset.
    var health: Int32 = 0
    _ = external_call["dw_apply_damage", Int32](ptr, Int32(40), Pointer(to=health))
    assert_equal(_state(ptr).health, Int32(60))
    assert_equal(external_call["dw_world_reset", Int32](ptr), DW_OK)
    var reset = _state(ptr)
    assert_equal(reset.day, UInt32(1))
    assert_equal(reset.health, Int32(100))
    assert_equal(reset.cash, Int32(2000))


def test_init_rejects_bad_abi_version() raises:
    var ptr = _world()
    var cfg = Config(UInt16(1), UInt16(0), UInt32(7), UInt32(0), Int32(-1))
    assert_equal(
        external_call["dw_world_init", Int32](ptr, Pointer(to=cfg)),
        DW_ERR_ABI_VERSION_MISMATCH,
    )


def test_init_honours_overrides() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7), UInt32(5), Int32(1234)), DW_OK)
    var view = _state(ptr)
    assert_equal(view.num_days, UInt32(5))
    assert_equal(view.cash, Int32(1234))

    assert_equal(_init(ptr, UInt32(7), UInt32(0), Int32(0)), DW_OK)
    assert_equal(_state(ptr).cash, Int32(0))


# ---------------------------------------------------------------------------
# Every result code is reachable
# ---------------------------------------------------------------------------


def test_every_result_code_is_reachable() raises:
    # DW_OK
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)

    # DW_ERR_ABI_VERSION_MISMATCH
    var bad_cfg = Config(UInt16(99), UInt16(0), UInt32(7), UInt32(0), Int32(-1))
    assert_equal(external_call["dw_world_init", Int32](ptr, Pointer(to=bad_cfg)), DW_ERR_ABI_VERSION_MISMATCH)

    # DW_ERR_INVALID_ARGUMENT: unknown finances action
    var actual: Int64 = 0
    assert_equal(external_call["dw_finances", Int32](ptr, UInt8(9), Int64(1), Pointer(to=actual)), DW_ERR_INVALID_ARGUMENT)
    # DW_ERR_INVALID_ARGUMENT: buy qty 0
    assert_equal(external_call["dw_buy", Int32](ptr, UInt32(_drug_in_roster(ptr)), UInt32(0)), DW_ERR_INVALID_ARGUMENT)
    # DW_ERR_INVALID_ARGUMENT: travel to the current location
    assert_equal(external_call["dw_travel", Int32](ptr, UInt32(0)), DW_ERR_INVALID_ARGUMENT)

    # DW_ERR_BUFFER_TOO_SMALL
    var one = List[PriceSlot]()
    one.append(PriceSlot(UInt32(0), Int32(0), UInt8(0), Array[UInt8, 3](fill=0)))
    var required: UInt = 0
    assert_equal(external_call["dw_prices_copy", Int32](ptr, one.unsafe_ptr(), UInt(1), Pointer(to=required)), DW_ERR_BUFFER_TOO_SMALL)
    assert_true(required > 1)

    # DW_ERR_UNKNOWN_LOCATION
    assert_equal(external_call["dw_travel", Int32](ptr, UInt32(99)), DW_ERR_UNKNOWN_LOCATION)
    var index: UInt32 = 0
    var name = _cstr("nope")
    assert_equal(external_call["dw_find_location_index", Int32](name.unsafe_ptr(), Pointer(to=index)), DW_ERR_UNKNOWN_LOCATION)

    # DW_ERR_UNKNOWN_DRUG
    assert_equal(external_call["dw_buy", Int32](ptr, UInt32(99), UInt32(1)), DW_ERR_UNKNOWN_DRUG)
    var drug_name = _cstr("nope")
    assert_equal(external_call["dw_find_drug_index", Int32](drug_name.unsafe_ptr(), Pointer(to=index)), DW_ERR_UNKNOWN_DRUG)

    # DW_ERR_NOT_TRADED_HERE
    var absent = _drug_not_in_roster(ptr)
    assert_true(absent >= 0)
    assert_equal(external_call["dw_buy", Int32](ptr, UInt32(absent), UInt32(1)), DW_ERR_NOT_TRADED_HERE)

    # DW_ERR_INSUFFICIENT_CASH
    var broke = _world()
    assert_equal(_init(broke, UInt32(7), UInt32(0), Int32(0)), DW_OK)
    var present = _drug_in_roster(broke)
    assert_equal(external_call["dw_buy", Int32](broke, UInt32(present), UInt32(1)), DW_ERR_INSUFFICIENT_CASH)

    # DW_ERR_INSUFFICIENT_BANK: cash 0, bank 0, coat offer costs money
    var offer = CoatOfferView(UInt32(10), Int32(100))
    var purchase = PurchaseResultView(UInt8(0), Array[UInt8, 3](fill=0), Int32(0))
    assert_equal(external_call["dw_accept_coat_offer", Int32](broke, Pointer(to=offer), Pointer(to=purchase)), DW_ERR_INSUFFICIENT_BANK)

    # DW_ERR_INSUFFICIENT_INVENTORY
    assert_equal(external_call["dw_sell", Int32](ptr, UInt32(present), UInt32(1)), DW_ERR_INSUFFICIENT_INVENTORY)

    # DW_ERR_INSUFFICIENT_SPACE: rich, buy more than the coat holds
    var rich = _world()
    assert_equal(_init(rich, UInt32(7), UInt32(0), Int32(1000000)), DW_OK)
    var cheap = _drug_in_roster(rich)
    assert_equal(external_call["dw_buy", Int32](rich, UInt32(cheap), UInt32(200)), DW_ERR_INSUFFICIENT_SPACE)

    # DW_ERR_GAME_OVER: one-day game, travel on day 1
    var short_game = _world()
    assert_equal(_init(short_game, UInt32(7), UInt32(1), Int32(-1)), DW_OK)
    assert_equal(external_call["dw_travel", Int32](short_game, UInt32(1)), DW_ERR_GAME_OVER)

    # DW_ERR_DEAD
    var doomed = _world()
    assert_equal(_init(doomed, UInt32(7)), DW_OK)
    var dead_health: Int32 = 0
    _ = external_call["dw_apply_damage", Int32](doomed, Int32(1000), Pointer(to=dead_health))
    assert_equal(dead_health, Int32(0))
    assert_equal(external_call["dw_travel", Int32](doomed, UInt32(1)), DW_ERR_DEAD)

    # DW_ERR_SERIALIZATION_FAILED
    var short_buf = List[UInt8]()
    short_buf.append(0)
    assert_equal(_load(ptr, short_buf), DW_ERR_SERIALIZATION_FAILED)


# ---------------------------------------------------------------------------
# Two-call buffer contracts
# ---------------------------------------------------------------------------


def test_two_call_prices_copy() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)

    var dummy = PriceSlot(UInt32(0), Int32(0), UInt8(0), Array[UInt8, 3](fill=0))
    var required: UInt = 0
    assert_equal(external_call["dw_prices_copy", Int32](ptr, Pointer(to=dummy), UInt(0), Pointer(to=required)), DW_OK)
    assert_true(required > 0)
    assert_true(required <= UInt(DW_NUM_DRUGS))

    var slots = List[PriceSlot]()
    for _ in range(Int(required)):
        slots.append(PriceSlot(UInt32(0), Int32(0), UInt8(0), Array[UInt8, 3](fill=0)))
    var actual: UInt = 0
    assert_equal(external_call["dw_prices_copy", Int32](ptr, slots.unsafe_ptr(), required, Pointer(to=actual)), DW_OK)
    assert_equal(actual, required)
    for slot in slots:
        assert_true(Int(slot.drug_index) < DW_NUM_DRUGS)
        assert_true(slot.price > 0)


def test_two_call_inventory_copy() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)

    var dummy = InventorySlot(UInt32(0), UInt32(0), Int64(0))
    var required: UInt = 0
    assert_equal(external_call["dw_inventory_copy", Int32](ptr, Pointer(to=dummy), UInt(0), Pointer(to=required)), DW_OK)
    assert_equal(required, UInt(0))

    var drug = _drug_in_roster(ptr)
    assert_equal(external_call["dw_buy", Int32](ptr, UInt32(drug), UInt32(1)), DW_OK)
    assert_equal(external_call["dw_inventory_copy", Int32](ptr, Pointer(to=dummy), UInt(0), Pointer(to=required)), DW_OK)
    assert_equal(required, UInt(1))

    var slots = List[InventorySlot]()
    slots.append(InventorySlot(UInt32(0), UInt32(0), Int64(0)))
    var actual: UInt = 0
    assert_equal(external_call["dw_inventory_copy", Int32](ptr, slots.unsafe_ptr(), UInt(1), Pointer(to=actual)), DW_OK)
    assert_equal(actual, UInt(1))
    assert_equal(Int(slots[0].drug_index), drug)
    assert_equal(slots[0].qty, UInt32(1))


def test_two_call_price_events_drain() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)
    var dummy = PriceEventView(UInt8(0), Array[UInt8, 3](fill=0), UInt32(0))
    var required: UInt = 0
    assert_equal(external_call["dw_price_events_drain", Int32](ptr, Pointer(to=dummy), UInt(0), Pointer(to=required)), DW_OK)
    assert_true(required <= UInt(3))
    var events = List[PriceEventView]()
    for _ in range(Int(required)):
        events.append(PriceEventView(UInt8(0), Array[UInt8, 3](fill=0), UInt32(0)))
    var actual: UInt = 0
    assert_equal(external_call["dw_price_events_drain", Int32](ptr, events.unsafe_ptr(), required, Pointer(to=actual)), DW_OK)
    assert_equal(actual, required)


def test_two_call_world_dump() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)
    var required = external_call["dw_world_dump_len", UInt]()

    var dummy = List[UInt8]()
    dummy.append(0)
    var written: UInt = 0
    assert_equal(external_call["dw_world_dump", Int32](ptr, dummy.unsafe_ptr(), UInt(0), Pointer(to=written)), DW_OK)
    assert_equal(written, required)

    assert_equal(external_call["dw_world_dump", Int32](ptr, dummy.unsafe_ptr(), UInt(1), Pointer(to=written)), DW_ERR_BUFFER_TOO_SMALL)
    assert_equal(written, required)

    var full = List[UInt8]()
    for _ in range(Int(required)):
        full.append(0)
    assert_equal(external_call["dw_world_dump", Int32](ptr, full.unsafe_ptr(), required, Pointer(to=written)), DW_OK)
    assert_equal(written, required)


def test_two_call_rules_copies() raises:
    var dummy_loc = LocationView(Array[UInt8, 32](fill=0), Array[UInt8, 32](fill=0), UInt32(0), UInt32(0), UInt32(0), UInt32(0))
    var required: UInt = 0
    assert_equal(external_call["dw_rules_locations_copy", Int32](Pointer(to=dummy_loc), UInt(0), Pointer(to=required)), DW_OK)
    assert_equal(required, UInt(DW_NUM_LOCATIONS))
    var locations = List[LocationView]()
    for _ in range(Int(required)):
        locations.append(LocationView(Array[UInt8, 32](fill=0), Array[UInt8, 32](fill=0), UInt32(0), UInt32(0), UInt32(0), UInt32(0)))
    var actual: UInt = 0
    assert_equal(external_call["dw_rules_locations_copy", Int32](locations.unsafe_ptr(), required, Pointer(to=actual)), DW_OK)
    assert_equal(actual, required)
    assert_equal(_bytes_to_string(locations[0].id), "bronx")

    var dummy_drug = DrugView(Array[UInt8, 32](fill=0), Array[UInt8, 32](fill=0), Int32(0), Int32(0), UInt8(0), UInt8(0), Array[UInt8, 2](fill=0))
    assert_equal(external_call["dw_rules_drugs_copy", Int32](Pointer(to=dummy_drug), UInt(0), Pointer(to=required)), DW_OK)
    assert_equal(required, UInt(DW_NUM_DRUGS))
    var drugs = List[DrugView]()
    for _ in range(Int(required)):
        drugs.append(DrugView(Array[UInt8, 32](fill=0), Array[UInt8, 32](fill=0), Int32(0), Int32(0), UInt8(0), UInt8(0), Array[UInt8, 2](fill=0)))
    assert_equal(external_call["dw_rules_drugs_copy", Int32](drugs.unsafe_ptr(), required, Pointer(to=actual)), DW_OK)
    assert_equal(actual, required)
    assert_equal(_bytes_to_string(drugs[0].id), "acid")


# ---------------------------------------------------------------------------
# Determinism and serialization
# ---------------------------------------------------------------------------


def test_same_seed_same_dump() raises:
    var a = _world()
    var b = _world()
    assert_equal(_init(a, UInt32(7)), DW_OK)
    assert_equal(_init(b, UInt32(7)), DW_OK)
    var da = _dump(a)
    var db = _dump(b)
    assert_equal(len(da), len(db))
    for i in range(len(da)):
        assert_equal(da[i], db[i])


def test_different_seed_different_dump() raises:
    var a = _world()
    var b = _world()
    assert_equal(_init(a, UInt32(7)), DW_OK)
    assert_equal(_init(b, UInt32(8)), DW_OK)
    var da = _dump(a)
    var db = _dump(b)
    var same = True
    for i in range(len(da)):
        if da[i] != db[i]:
            same = False
    assert_false(same)


def test_serialization_round_trip() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)
    var drug = _drug_in_roster(ptr)
    assert_equal(external_call["dw_buy", Int32](ptr, UInt32(drug), UInt32(2)), DW_OK)
    assert_equal(external_call["dw_travel", Int32](ptr, UInt32(1)), DW_OK)

    var before = _dump(ptr)
    var restored = _world()
    assert_equal(_load(restored, before), DW_OK)
    var after = _dump(restored)
    assert_equal(len(before), len(after))
    for i in range(len(before)):
        assert_equal(before[i], after[i])

    # The restored world is a live world, not just bytes.
    var view = _state(restored)
    assert_equal(view.day, UInt32(2))
    assert_equal(view.location_index, UInt32(1))


def test_load_rejects_wrong_length() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)
    var before = _dump(ptr)
    var truncated = List[UInt8]()
    for i in range(len(before) - 1):
        truncated.append(before[i])
    assert_equal(_load(ptr, truncated), DW_ERR_SERIALIZATION_FAILED)
    # State is unchanged after a failed load.
    var after = _dump(ptr)
    assert_equal(len(before), len(after))
    for i in range(len(before)):
        assert_equal(before[i], after[i])


# ---------------------------------------------------------------------------
# Rules, RNG, lookups
# ---------------------------------------------------------------------------


def test_rules_accessors() raises:
    assert_equal(external_call["dw_rules_default_num_days", UInt32](), UInt32(31))
    assert_equal(external_call["dw_rules_default_start_cash", Int32](), Int32(2000))
    assert_equal(external_call["dw_rules_default_start_debt", Int64](), Int64(5500))
    assert_equal(external_call["dw_rules_default_start_health", Int32](), Int32(100))
    assert_equal(external_call["dw_rules_default_start_coat_capacity", Int32](), Int32(100))
    assert_equal(external_call["dw_rules_default_start_location_index", Int32](), Int32(0))
    assert_equal(external_call["dw_rules_gun_damage", UInt32](), UInt32(5))
    assert_equal(external_call["dw_rules_gun_space", UInt32](), UInt32(4))
    assert_equal(external_call["dw_rules_player_armor", UInt32](), UInt32(100))
    assert_equal(external_call["dw_rules_debt_interest_bp", UInt32](), UInt32(1000))
    assert_equal(external_call["dw_rules_bank_interest_bp", UInt32](), UInt32(500))
    assert_equal(external_call["dw_rules_bank_purchase_fee_bp", UInt32](), UInt32(2500))
    assert_equal(external_call["dw_rules_cheap_divide", UInt32](), UInt32(10))
    assert_equal(external_call["dw_rules_expensive_multiply", UInt32](), UInt32(5))


def test_rng_matches_js_oracle() raises:
    # Seed 7, first two raw draws, computed from the JS mulberry32 at
    # index.html:624-635 (see tests/mojo/rng_test.mojo for the float form).
    var state: UInt32 = 0
    external_call["dw_mulberry32_seed", NoneType](UInt32(7), Pointer(to=state))
    assert_equal(state, UInt32(7))
    var first = external_call["dw_mulberry32_next_u32", UInt32](Pointer(to=state))
    assert_equal(first, UInt32(50271532))
    var second = external_call["dw_mulberry32_next_u32", UInt32](Pointer(to=state))
    assert_equal(second, UInt32(266108690))

    # dw_rand_int is inclusive on both ends and advances the same stream.
    var state2: UInt32 = 0
    external_call["dw_mulberry32_seed", NoneType](UInt32(7), Pointer(to=state2))
    var value: Int32 = 0
    assert_equal(external_call["dw_rand_int", Int32](Pointer(to=state2), Int32(0), Int32(9), Pointer(to=value)), DW_OK)
    assert_true(value >= 0 and value <= 9)
    assert_equal(state2, UInt32(7) + UInt32(0x6D2B79F5))

    # min > max is rejected without advancing state.
    var state3: UInt32 = 0
    external_call["dw_mulberry32_seed", NoneType](UInt32(7), Pointer(to=state3))
    assert_equal(external_call["dw_rand_int", Int32](Pointer(to=state3), Int32(9), Int32(0), Pointer(to=value)), DW_ERR_INVALID_ARGUMENT)
    assert_equal(state3, UInt32(7))


def test_find_drug_and_location() raises:
    var index: UInt32 = 0
    var bronx = _cstr("bronx")
    assert_equal(external_call["dw_find_location_index", Int32](bronx.unsafe_ptr(), Pointer(to=index)), DW_OK)
    assert_equal(index, UInt32(0))
    var manhattan = _cstr("manhattan")
    assert_equal(external_call["dw_find_location_index", Int32](manhattan.unsafe_ptr(), Pointer(to=index)), DW_OK)
    assert_equal(index, UInt32(3))

    var acid = _cstr("acid")
    assert_equal(external_call["dw_find_drug_index", Int32](acid.unsafe_ptr(), Pointer(to=index)), DW_OK)
    assert_equal(index, UInt32(0))
    var weed = _cstr("weed")
    assert_equal(external_call["dw_find_drug_index", Int32](weed.unsafe_ptr(), Pointer(to=index)), DW_OK)
    assert_equal(index, UInt32(11))


# ---------------------------------------------------------------------------
# Game step sequence
# ---------------------------------------------------------------------------


def test_game_step_sequence() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)
    var start = _state(ptr)
    assert_equal(start.day, UInt32(1))
    # A fresh coat holds no drugs and no guns, so the used space reads 0 of
    # the 100-slot capacity, not the gun-space constant.
    assert_equal(start.guns, UInt32(0))
    assert_equal(start.coat_used, Int32(0))

    var drug = _drug_in_roster(ptr)
    assert_equal(external_call["dw_buy", Int32](ptr, UInt32(drug), UInt32(2)), DW_OK)
    var after_buy = _state(ptr)
    assert_equal(after_buy.coat_used, Int32(2))
    assert_true(after_buy.cash < start.cash)

    assert_equal(external_call["dw_sell", Int32](ptr, UInt32(drug), UInt32(1)), DW_OK)
    assert_equal(_state(ptr).coat_used, Int32(1))

    assert_equal(external_call["dw_travel", Int32](ptr, UInt32(2)), DW_OK)
    var after_travel = _state(ptr)
    assert_equal(after_travel.day, UInt32(2))
    assert_equal(after_travel.location_index, UInt32(2))
    # Debt compounds 10% and rounds to a whole dollar on travel.
    assert_equal(after_travel.debt, Int64(6050))


def test_finances_moves_money() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)
    var actual: Int64 = 0
    assert_equal(external_call["dw_finances", Int32](ptr, UInt8(0), Int64(500), Pointer(to=actual)), DW_OK)
    assert_equal(actual, Int64(500))
    var view = _state(ptr)
    assert_equal(view.cash, Int32(1500))
    assert_equal(view.bank, Int64(500))

    assert_equal(external_call["dw_finances", Int32](ptr, UInt8(1), Int64(200), Pointer(to=actual)), DW_OK)
    assert_equal(actual, Int64(200))
    assert_equal(_state(ptr).cash, Int32(1700))

    assert_equal(external_call["dw_finances", Int32](ptr, UInt8(2), Int64(1000), Pointer(to=actual)), DW_OK)
    assert_equal(actual, Int64(1000))
    assert_equal(_state(ptr).debt, Int64(4500))


def test_dealer_offers_and_purchases() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)
    var coat = CoatOfferView(UInt32(0), Int32(0))
    assert_equal(external_call["dw_roll_coat_dealer_offer", Int32](ptr, Pointer(to=coat)), DW_OK)
    assert_true(coat.pockets >= 10 and coat.pockets <= 30)
    assert_true(coat.price >= 200 and coat.price <= 500)

    var purchase = PurchaseResultView(UInt8(0), Array[UInt8, 3](fill=0), Int32(0))
    assert_equal(external_call["dw_accept_coat_offer", Int32](ptr, Pointer(to=coat), Pointer(to=purchase)), DW_OK)
    assert_equal(_state(ptr).coat_capacity, Int32(100) + Int32(coat.pockets))

    var gun = GunOfferView(Int32(0), UInt32(0), UInt32(0), UInt32(0))
    assert_equal(external_call["dw_roll_gun_dealer_offer", Int32](ptr, Pointer(to=gun)), DW_OK)
    assert_equal(gun.damage, UInt32(5))
    assert_equal(gun.space, UInt32(4))
    assert_equal(external_call["dw_accept_gun_offer", Int32](ptr, Pointer(to=gun), Pointer(to=purchase)), DW_OK)
    assert_equal(_state(ptr).guns, UInt32(1))
    # One gun with zero drugs held is 4 used slots: the gun's space, not a
    # defect. This is the state the trenchcoat indicator renders as 4/100
    # (docs/gameplay.md "Inventory"; index.html:711-716).
    assert_equal(_state(ptr).coat_used, Int32(4))


def test_combat_flow() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)
    var should: UInt8 = 0
    assert_equal(external_call["dw_should_start_chase", Int32](ptr, Pointer(to=should)), DW_OK)
    assert_true(should == 0 or should == 1)

    var chase = ChaseView(UInt32(0), UInt8(0), Array[UInt8, 3](fill=0))
    assert_equal(external_call["dw_start_chase", Int32](ptr, Pointer(to=chase)), DW_OK)
    # beermat-verified (TASK-009): deputies is randInt(2, 11), no longer a
    # deterministic function of day alone -- this is seed 7's actual draw
    # after should_start_chase's one draw.
    assert_equal(chase.deputies, UInt32(3))
    assert_equal(chase.can_fight, UInt8(0))

    var ratings = FightRatingsView(UInt32(0), UInt32(0))
    assert_equal(external_call["dw_get_fight_ratings", Int32](ptr, Pointer(to=ratings)), DW_OK)
    assert_equal(ratings.attack, UInt32(80))
    assert_equal(ratings.defend, UInt32(100))

    var run = RunResultView(UInt8(0), Array[UInt8, 3](fill=0), Int32(0))
    assert_equal(external_call["dw_run_from_chase", Int32](ptr, Pointer(to=chase), UInt8(0), Pointer(to=run)), DW_OK)
    assert_true(run.escaped == 0 or run.escaped == 1)

    var fight = FightResultView(UInt8(0), UInt8(0), UInt8(0), UInt8(0), Int32(0))
    assert_equal(external_call["dw_fight", Int32](ptr, Pointer(to=chase), Pointer(to=fight)), DW_OK)


def test_finish_and_highscore() raises:
    var ptr = _world()
    assert_equal(_init(ptr, UInt32(7)), DW_OK)
    var finish = FinishResultView(Int64(0), UInt32(0), UInt8(0), Array[UInt8, 3](fill=0))
    assert_equal(external_call["dw_finish", Int32](ptr, Pointer(to=finish)), DW_OK)
    # cash 2000 + bank 0 - debt 5500
    assert_equal(finish.score, Int64(-3500))
    assert_equal(finish.day, UInt32(1))
    assert_equal(finish.dead, UInt8(0))

    var scores = List[HighscoreEntryView]()
    for _ in range(DW_MAX_HIGHSCORES):
        scores.append(HighscoreEntryView(Array[UInt8, 32](fill=0), Int64(0), UInt32(0), UInt8(0), Array[UInt8, 3](fill=0)))
    var entry = HighscoreEntryView(_cstr_array("alice"), Int64(1234), UInt32(31), UInt8(0), Array[UInt8, 3](fill=0))
    var count: UInt = 0
    assert_equal(external_call["dw_insert_highscore", Int32](scores.unsafe_ptr(), UInt(DW_MAX_HIGHSCORES), UInt(0), Pointer(to=entry), Pointer(to=count)), DW_OK)
    assert_equal(count, UInt(1))
    assert_equal(_bytes_to_string(scores[0].name), "alice")
    assert_equal(scores[0].score, Int64(1234))

    # A too-small table is rejected.
    var tiny = List[HighscoreEntryView]()
    tiny.append(HighscoreEntryView(Array[UInt8, 32](fill=0), Int64(0), UInt32(0), UInt8(0), Array[UInt8, 3](fill=0)))
    assert_equal(external_call["dw_insert_highscore", Int32](tiny.unsafe_ptr(), UInt(1), UInt(0), Pointer(to=entry), Pointer(to=count)), DW_ERR_BUFFER_TOO_SMALL)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
