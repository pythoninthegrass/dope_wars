# core/src/serialize.mojo — save and restore a whole world.
#
# The JS engine round-trips through JSON (serializeState / deserializeState,
# index.html:1033-1047). Core produces an opaque byte buffer instead, which is
# what dw_world_dump / dw_world_load hand to the game layer; the game layer owns
# the file format around it.
#
# The encoding is little-endian and fixed-layout per field, with the ordered maps
# written as a count followed by their order list and dense slots. Floats go
# through floatbits, so a save/load cycle is bit-exact -- which matters because
# bank accrues fractional interest and a lossy round-trip would change the score.
#
# There is no version tag yet: the buffer is only ever produced and consumed by
# the same build. TASK-001.05 owns the on-disk format and its versioning.

import floatbits
import rules
import rng as rng_mod
import world


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


def _write_order(mut writer: ByteWriter, order: List[UInt8]):
    writer.u32(UInt32(len(order)))
    for entry in order:
        writer.u8(entry)


def _read_order(mut reader: ByteReader) raises -> List[UInt8]:
    var count = Int(reader.u32())
    var out = List[UInt8]()
    for _ in range(count):
        out.append(reader.u8())
    return out^


def dump(ref game: world.World) raises -> List[UInt8]:
    var writer = ByteWriter()
    writer.u32(game.seed)
    writer.u32(game.rng.get_state())
    writer.i64(game.day)
    writer.i64(game.num_days)
    writer.f64(game.cash)
    writer.f64(game.debt)
    writer.f64(game.bank)
    writer.i64(game.health)
    writer.i64(game.coat_capacity)
    writer.i64(game.guns)
    writer.i64(Int64(game.location_index))
    writer.boolean(game.dead)
    writer.boolean(game.last_day_warned)

    _write_order(writer, game.price_order)
    for i in range(rules.NUM_DRUGS):
        writer.i64(game.price_value[i])
        writer.u8(game.price_present[i])
        writer.u8(game.price_was_event[i])

    _write_order(writer, game.prev_price_order)
    for i in range(rules.NUM_DRUGS):
        writer.i64(game.prev_price_value[i])
        writer.u8(game.prev_price_present[i])

    _write_order(writer, game.inv_order)
    for i in range(rules.NUM_DRUGS):
        writer.i64(game.inv_qty[i])
        writer.f64(game.inv_avg_price[i])
        writer.u8(game.inv_present[i])

    writer.u32(UInt32(len(game.price_events)))
    for event in game.price_events:
        writer.i64(Int64(event.kind))
        writer.i64(Int64(event.drug_index))

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
    game.debt = reader.f64()
    game.bank = reader.f64()
    game.health = reader.i64()
    game.coat_capacity = reader.i64()
    game.guns = reader.i64()
    game.location_index = Int(reader.i64())
    game.dead = reader.boolean()
    game.last_day_warned = reader.boolean()

    game.price_order = _read_order(reader)
    for i in range(rules.NUM_DRUGS):
        game.price_value[i] = reader.i64()
        game.price_present[i] = reader.u8()
        game.price_was_event[i] = reader.u8()

    game.prev_price_order = _read_order(reader)
    for i in range(rules.NUM_DRUGS):
        game.prev_price_value[i] = reader.i64()
        game.prev_price_present[i] = reader.u8()

    game.inv_order = _read_order(reader)
    for i in range(rules.NUM_DRUGS):
        game.inv_qty[i] = reader.i64()
        game.inv_avg_price[i] = reader.f64()
        game.inv_present[i] = reader.u8()

    var event_count = Int(reader.u32())
    game.price_events = List[world.PriceEvent]()
    for _ in range(event_count):
        var kind = Int(reader.i64())
        var drug_index = Int(reader.i64())
        game.price_events.append(world.PriceEvent(kind, drug_index))

    return game^
