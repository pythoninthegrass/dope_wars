# tests/mojo/record.mojo — read one flattened oracle fixture step.
#
# tests/fixtures/gen-mojo.mjs turns each tests/fixtures/*.jsonl line into a
# single flat record:
#
#   call | rng lexemes | arg pairs | return pairs | state pairs
#
# where a pair is `dotted.path=lexeme`, pairs within a group are ';'-separated,
# and pairs appear in the oracle's own document order. Nothing nests, so this
# reader only ever splits strings -- no recursive JSON value, no dynamic types.
#
# Order is load-bearing, not incidental. The JS engine stores state.prices and
# state.inventory as insertion-ordered objects, Object.keys() order picks the
# drug in randomTradeableDrug() and in the dogChase branch, and the JS fixture
# runner's deepEqual is JSON.stringify. So `children` and `child_keys` return
# document order and callers must compare in that order.


def suffix(ref text: String, start: Int) -> String:
    var all = text.bytes()
    var out = List[UInt8]()
    var i = start
    while i < len(all):
        out.append(all[i])
        i += 1
    return String(out)


struct Pair:
    var path: String
    var lex: String

    def __init__(out self, path: String, lex: String):
        self.path = path
        self.lex = lex

    def as_int(ref self) raises -> Int64:
        return lexeme.to_int(self.lex)

    def as_float(ref self) raises -> Float64:
        return lexeme.to_float(self.lex)

    def as_bool(ref self) raises -> Bool:
        return lexeme.to_bool(self.lex)


struct Group:
    var pairs: List[Pair]

    def __init__(out self):
        self.pairs = List[Pair]()

    def add(mut self, path: String, lex: String):
        self.pairs.append(Pair(path, lex))

    def has(ref self, path: String) -> Bool:
        for pair in self.pairs:
            if pair.path == path:
                return True
        return False

    def int_at(ref self, path: String) raises -> Int64:
        for pair in self.pairs:
            if pair.path == path:
                return pair.as_int()
        raise Error("oracle record is missing " + path)

    def float_at(ref self, path: String) raises -> Float64:
        for pair in self.pairs:
            if pair.path == path:
                return pair.as_float()
        raise Error("oracle record is missing " + path)

    def bool_at(ref self, path: String) raises -> Bool:
        for pair in self.pairs:
            if pair.path == path:
                return pair.as_bool()
        raise Error("oracle record is missing " + path)

    def string_at(ref self, path: String) raises -> String:
        for pair in self.pairs:
            if pair.path == path:
                return pair.lex
        raise Error("oracle record is missing " + path)

    # Every pair whose path sits strictly under `prefix`, in document order,
    # with the prefix and its dot stripped.
    def children(ref self, prefix: String) -> List[Pair]:
        var out = List[Pair]()
        var dotted = prefix + "."
        var head = dotted.byte_length()
        for pair in self.pairs:
            if pair.path.byte_length() > head and pair.path.startswith(dotted):
                out.append(Pair(suffix(pair.path, head), pair.lex))
        return out^

    # Just the child keys under `prefix`, in document order.
    def child_keys(ref self, prefix: String) -> List[String]:
        var out = List[String]()
        for pair in self.children(prefix):
            out.append(pair.path)
        return out^


struct Record:
    var call: String
    var rng: List[Float64]
    var args: Group
    var ret: Group
    var state: Group

    def __init__(out self):
        self.call = ""
        self.rng = List[Float64]()
        self.args = Group()
        self.ret = Group()
        self.state = Group()


def _parse_group(mut target: Group, text: String) raises:
    if text.byte_length() == 0:
        return
    for chunk in text.split(";"):
        var fields = chunk.split("=", maxsplit=1)
        if len(fields) != 2:
            raise Error("malformed pair in the oracle record: " + String(chunk))
        target.add(String(fields[0]), String(fields[1]))


def _parse_rng(mut target: List[Float64], text: String) raises:
    if text.byte_length() == 0:
        return
    for chunk in text.split(","):
        target.append(lexeme.to_float(String(chunk)))


def parse_record(line: String) raises -> Record:
    var out = Record()
    var fields = line.split("|", maxsplit=4)
    if len(fields) != 5:
        raise Error("expected 5 '|'-separated groups in the oracle record")
    out.call = String(fields[0])
    _parse_rng(out.rng, String(fields[1]))
    _parse_group(out.args, String(fields[2]))
    _parse_group(out.ret, String(fields[3]))
    _parse_group(out.state, String(fields[4]))
    return out^
