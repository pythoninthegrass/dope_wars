# core/src/serialize.mojo — save and restore a whole world.
#
# The JS engine round-trips through JSON (serializeState / deserializeState,
# index.html:1033-1047). Core produces an opaque byte buffer instead, which is
# what dw_world_dump / dw_world_load hand to the game layer; the game layer owns
# the file format around it.
#
# The encoding is little-endian and fixed-layout per field, with the ordered maps
# written as a count followed by all DW_NUM_DRUGS order slots (zero-padded past
# the live count) and all DW_NUM_DRUGS dense slots. Floats go through floatbits,
# so a save/load cycle is bit-exact -- which matters because bank accrues
# fractional interest and a lossy round-trip would change the score.
#
# The layout is fixed-size on purpose: dw_world_dump_len() must report the exact
# byte count dw_world_dump will write, independent of inventory occupancy or
# price-table content (docs/abi-contract.md). DUMP_LEN is that count; dump()
# asserts it at runtime so a layout edit cannot silently desync the two.
#
# There is no version tag yet: the buffer is only ever produced and consumed by
# the same build. TASK-001.05 owns the on-disk format and its versioning.

import floatbits
import rules
import rng as rng_mod
import sharks
import world


# seed(4) + rng_state(4) + day(8) + num_days(8) + cash/bank(2*17)
# + start_cash(17) + health/coat_capacity/guns/location_index(4*8)
# + dead/last_day_warned(2) + price_order(4+12) + price slots(12*10)
# + prev_price_order(4+12) + prev price slots(12*9) + inv_order(4+12)
# + inv slots(12*26) + price_events(4+8*16) with 12 drugs and 8 events; now 13 drugs and
# 13 events, plus last_price/seen_price(13*8 each) and last_event/price_direction(13 each), then the
# loans: count(4), 5 slots of shark(1) + balance(8) + days_left(8), and 5 released flags.
comptime LOAN_COUNT_OFFSET = 1191
comptime DUMP_LEN = 1285


struct ByteWriter:
    var bytes: List[UInt8]

    def __init__(out self):
        self.bytes = List[UInt8]()

    def u8(mut self, value: UInt8):
        self.bytes.append(value)

    def u32(mut self, value: UInt32):
        for i in range(4):
            self.bytes.append(UInt8((value >> UInt32(8 * i)) & UInt32(0xFF)))

    def i64(mut self, value: Int64):
        # Two's-complement bytes, extracted arithmetically. rebind cannot cross
        # Int64/UInt64 (it requires the same SIMD kind), and an arithmetic shift
        # right on a signed value preserves the sign bits, which is exactly the
        # two's-complement byte sequence.
        var remaining = value
        for _ in range(8):
            self.bytes.append(UInt8(remaining & 0xFF))
            remaining = remaining >> 8

    def f64(mut self, value: Float64) raises:
        var parts = floatbits.decompose(value)
        self.u8(UInt8(parts.sign))
        self.i64(Int64(parts.exponent))
        self.i64(parts.mantissa)

    def boolean(mut self, value: Bool):
        self.u8(UInt8(1) if value else UInt8(0))


struct ByteReader:
    var bytes: List[UInt8]
    var pos: Int

    def __init__(out self, bytes: List[UInt8]):
        self.bytes = bytes.copy()
        self.pos = 0

    def u8(mut self) raises -> UInt8:
        if self.pos >= len(self.bytes):
            raise Error("serialized world is truncated")
        var value = self.bytes[self.pos]
        self.pos += 1
        return value

    def u32(mut self) raises -> UInt32:
        var out: UInt32 = 0
        for i in range(4):
            out = out | (UInt32(self.u8()) << UInt32(8 * i))
        return out

    def i64(mut self) raises -> Int64:
        var out: Int64 = 0
        for i in range(8):
            out = out | (Int64(self.u8()) << Int64(8 * i))
        return out

    def f64(mut self) raises -> Float64:
        var sign = Int(self.u8())
        var exponent = Int(self.i64())
        var mantissa = self.i64()
        return floatbits.compose(sign, exponent, mantissa)

    def boolean(mut self) raises -> Bool:
        return self.u8() != 0


# Writes the live count followed by every order slot, zero-padded past the live
# count, so the byte count does not depend on how many drugs are live.
def _write_order(mut writer: ByteWriter, order: Array[UInt8, rules.NUM_DRUGS], count: Int):
    writer.u32(UInt32(count))
    for i in range(rules.NUM_DRUGS):
        writer.u8(order[i])


def dump(ref game: world.World) raises -> List[UInt8]:
    var writer = ByteWriter()
    writer.u32(game.seed)
    writer.u32(game.rng.get_state())
    writer.i64(game.day)
    writer.i64(game.num_days)
    writer.f64(game.cash)
    writer.f64(game.bank)
    writer.f64(game.start_cash)
    writer.i64(game.health)
    writer.i64(game.coat_capacity)
    writer.i64(game.guns)
    writer.i64(Int64(game.location_index))
    writer.boolean(game.dead)
    writer.boolean(game.last_day_warned)

    _write_order(writer, game.price_order, game.price_order_len)
    for i in range(rules.NUM_DRUGS):
        writer.i64(game.price_value[i])
        writer.u8(game.price_present[i])
        writer.u8(game.price_was_event[i])

    _write_order(writer, game.prev_price_order, game.prev_price_order_len)
    for i in range(rules.NUM_DRUGS):
        writer.i64(game.prev_price_value[i])
        writer.u8(game.prev_price_present[i])

    _write_order(writer, game.inv_order, game.inv_order_len)
    for i in range(rules.NUM_DRUGS):
        writer.i64(game.inv_qty[i])
        writer.f64(game.inv_avg_price[i])
        writer.u8(game.inv_present[i])

    writer.u32(UInt32(game.price_events_len))
    for i in range(world.MAX_PRICE_EVENTS):
        writer.i64(Int64(game.price_events[i].kind))
        writer.i64(Int64(game.price_events[i].drug_index))

    for i in range(rules.NUM_DRUGS):
        writer.i64(game.last_price[i])
        writer.u8(game.last_event[i])
        writer.i64(game.seen_price[i])
        writer.u8(UInt8(Int(game.price_direction[i]) + 1))

    writer.u32(UInt32(game.loan_count))
    for i in range(sharks.NUM_SHARKS):
        writer.u8(game.loan_shark[i])
        writer.i64(game.loan_balance[i])
        writer.i64(game.loan_days_left[i])
    for i in range(sharks.NUM_SHARKS):
        writer.u8(game.shark_released[i])

    if len(writer.bytes) != DUMP_LEN:
        raise Error(
            "serialized world is "
            + String(len(writer.bytes))
            + " bytes, expected "
            + String(DUMP_LEN)
        )
    return writer.bytes.copy()


def load(bytes: List[UInt8]) raises -> world.World:
    var reader = ByteReader(bytes.copy())
    var seed = reader.u32()
    var rng_state = reader.u32()
    var game = world.World(seed, 1, 0.0)
    game.rng.set_state(rng_state)
    game.day = reader.i64()
    game.num_days = reader.i64()
    game.cash = reader.f64()
    game.bank = reader.f64()
    game.start_cash = reader.f64()
    game.health = reader.i64()
    game.coat_capacity = reader.i64()
    game.guns = reader.i64()
    game.location_index = Int(reader.i64())
    game.dead = reader.boolean()
    game.last_day_warned = reader.boolean()

    game.price_order_len = Int(reader.u32())
    for i in range(rules.NUM_DRUGS):
        game.price_order[i] = reader.u8()
    for i in range(rules.NUM_DRUGS):
        game.price_value[i] = reader.i64()
        game.price_present[i] = reader.u8()
        game.price_was_event[i] = reader.u8()

    game.prev_price_order_len = Int(reader.u32())
    for i in range(rules.NUM_DRUGS):
        game.prev_price_order[i] = reader.u8()
    for i in range(rules.NUM_DRUGS):
        game.prev_price_value[i] = reader.i64()
        game.prev_price_present[i] = reader.u8()

    game.inv_order_len = Int(reader.u32())
    for i in range(rules.NUM_DRUGS):
        game.inv_order[i] = reader.u8()
    for i in range(rules.NUM_DRUGS):
        game.inv_qty[i] = reader.i64()
        game.inv_avg_price[i] = reader.f64()
        game.inv_present[i] = reader.u8()

    game.price_events_len = Int(reader.u32())
    for i in range(world.MAX_PRICE_EVENTS):
        var kind = Int(reader.i64())
        var drug_index = Int(reader.i64())
        game.price_events[i] = world.PriceEvent(kind, drug_index)

    for i in range(rules.NUM_DRUGS):
        game.last_price[i] = reader.i64()
        game.last_event[i] = reader.u8()
        game.seen_price[i] = reader.i64()
        game.price_direction[i] = Int8(Int(reader.u8()) - 1)

    game.loan_count = Int(reader.u32())
    if game.loan_count > sharks.NUM_SHARKS:
        raise Error("serialized world has more loans than sharks")
    for i in range(sharks.NUM_SHARKS):
        game.loan_shark[i] = reader.u8()
        if Int(game.loan_shark[i]) >= sharks.NUM_SHARKS:
            raise Error("serialized loan names an unknown shark")
        game.loan_balance[i] = reader.i64()
        game.loan_days_left[i] = reader.i64()
    for i in range(sharks.NUM_SHARKS):
        game.shark_released[i] = reader.u8()

    return game^
