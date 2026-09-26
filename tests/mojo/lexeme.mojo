# tests/mojo/lexeme.mojo — decode the flat lexemes the oracle generator emits.
#
# A lexeme is a JSON scalar rendered as one structural-character-free token by
# tests/fixtures/gen-mojo.mjs:
#
#   -            null
#   t / f        booleans
#   5500         an integer, in plain decimal (exact in Int64)
#   d:0:1030:5864062014805
#                a non-integer float, as its IEEE-754 sign/exponent/mantissa
#   bronx        a string (the generator asserts none contains ; = or |, so
#                there is no escape scheme to read)
#
# Floats are transmitted decomposed rather than as decimals on purpose. A
# float64's shortest round-trip decimal can need 17 significant digits, which
# overflows the 2^53 that Int64 mantissa arithmetic holds exactly -- the corpus's
# 128.16666666666666 (a bank-interest product) is such a value, and no power of
# ten reproduces it exactly. Reassembling a decomposition is exact at every step:
# 1 + mantissa/2^52 needs at most 53 significant bits so it is exact, and scaling
# by powers of two introduces no rounding. So the recovered float is bit-for-bit
# the value JSON.parse produced.
#
# Scanning works on bytes, not characters: `text[byte=i]` yields a StringSpan in
# Mojo 1.1.0, and byte comparison is cheaper and unambiguous for ASCII.

comptime _ZERO = UInt8(48)
comptime _NINE = UInt8(57)
# 2**52, the float64 mantissa scale.
comptime _MANTISSA_SCALE = 4503599627370496.0


def _is_digit(b: UInt8) -> Bool:
    return b >= _ZERO and b <= _NINE


def _scale_pow2(value: Float64, exponent: Int) -> Float64:
    # Exact for every exponent the corpus uses: multiplying by 2.0 and by 0.5
    # are both exact, and the values involved stay in the normal range.
    var out = value
    var n = exponent
    while n > 0:
        out *= 2.0
        n -= 1
    while n < 0:
        out *= 0.5
        n += 1
    return out


struct IntScanner:
    var bytes: List[UInt8]
    var pos: Int
    var negative: Bool
    var value: Int64
    var text: String

    def __init__(out self, text: String):
        self.text = text
        self.bytes = List(text.bytes())
        self.pos = 0
        self.negative = False
        self.value = 0

    def read(mut self) raises -> Int64:
        var v = self.read_field()
        if not self._at_end():
            raise Error("trailing junk in integer lexeme: " + self.text)
        return v

    def read_field(mut self) raises -> Int64:
        # Stops at the first non-digit, so a d:sign:exp:mant lexeme can be read
        # field by field. A leading '-' is accepted but callers that need an
        # unsigned field check for it.
        self.value = 0
        self.negative = False
        if not self._at_end() and self._at(self.pos) == UInt8(45):  # '-'
            self.negative = True
            self.pos += 1
        if self._at_end() or not _is_digit(self._at(self.pos)):
            raise Error("not an integer field in " + self.text)
        while not self._at_end() and _is_digit(self._at(self.pos)):
            self.value = self.value * 10 + Int64(Int(self._at(self.pos)) - Int(_ZERO))
            self.pos += 1
        return -self.value if self.negative else self.value

    def read_unsigned_field(mut self) raises -> Int64:
        # Field values inside a d:... lexeme are never negative.
        var v = self.read_field()
        if self.negative:
            raise Error("expected an unsigned field in " + self.text)
        return v

    def expect(mut self, byte: UInt8) raises:
        if self._at_end() or self._at(self.pos) != byte:
            raise Error("expected " + String(byte) + " in " + self.text)
        self.pos += 1

    def _at(ref self, index: Int) raises -> UInt8:
        if index >= len(self.bytes):
            raise Error("unexpected end of lexeme: " + self.text)
        return self.bytes[index]

    def _at_end(ref self) -> Bool:
        return self.pos >= len(self.bytes)


def to_int(text: String) raises -> Int64:
    var scanner = IntScanner(text)
    return scanner.read()


def to_float(text: String) raises -> Float64:
    if text.find("d:") != 0:
        return Float64(to_int(text))
    var scanner = IntScanner(text)
    scanner.expect(UInt8(100))  # 'd'
    scanner.expect(UInt8(58))  # ':'
    var sign = scanner.read_unsigned_field()
    scanner.expect(UInt8(58))
    var exponent = scanner.read_unsigned_field()
    scanner.expect(UInt8(58))
    var mantissa = scanner.read_unsigned_field()
    if scanner.pos != len(scanner.bytes):
        raise Error("trailing junk in float lexeme: " + text)
    if exponent == 0:
        raise Error("zero or subnormal floats are not emitted: " + text)
    var value = 1.0 + Float64(mantissa) / _MANTISSA_SCALE
    value = _scale_pow2(value, Int(exponent) - 1023)
    if sign != 0:
        value = -value
    return value


def to_bool(text: String) raises -> Bool:
    if text == "t":
        return True
    if text == "f":
        return False
    raise Error("not a boolean lexeme: " + text)
