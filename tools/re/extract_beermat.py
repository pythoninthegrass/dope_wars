#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["pefile"]
# ///

"""
Extracts the Delphi form resources from the Beermat "Dope Wars for Windows"
1.2.0.0 exe into text DFM files (TASK-010.01.01 to .04).

Everything written is derived from copyrighted material, so the default output
directory sits under the gitignored vendor/dopewars-1999/. Only this tool and
its self-test are committed.

Usage: uv run tools/re/extract_beermat.py [--exe PATH] [--out DIR]
"""

import argparse
import math
import os
import re
import struct
import sys
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

import pefile

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_EXE = REPO_ROOT / "vendor" / "dopewars-1999" / "DopeWars.exe"
DEFAULT_OUT = REPO_ROOT / "vendor" / "dopewars-1999" / "re"

RT_RCDATA = 10
PCGUARD_SECTION = b".PCGW32"
ENCRYPTED_ENTROPY = 7.5
MIN_ENCRYPTED_SECTION_LEN = 0x1000
TPF0_MAGIC = b"TPF0"
FLAG_PREFIX_MASK = 0xF0
FLAG_CHILD_POS = 0x02

MIN_STRING_LEN = 4
HIT_SUFFIX = "hit"
SOUND_CURRENT_RE = re.compile(r"AppEvents\\Schemes\\Apps\\DopeWars\\(\w+)\\\.current")
EVENT_LABEL_PREFIX = "AppEvents\\EventLabels\\"
EXPECTED_SOUNDS = {
    "DWCopGunShot": "gun.wav",
    "DWYourGunShot": "gun2.wav",
    "DWYouHitByGun": "youhit.wav",
    "DWCopHitByGun": "cophit.wav",
    "DWCopChase": "siren.wav",
    "DWPoliceDog": "bark.wav",
    "DWCashReg": "cashreg.wav",
    "DWMugged": "hrdpunch.wav",
    "DWDead": "wasted.wav",
    "DWLastDay": "uhoh.wav",
}

VMT_SELF_PTR = -76
VMT_METHOD_TABLE = -52
VMT_CLASS_NAME = -44
VMT_PARENT = -36
CLASS_NAME_RE = re.compile(r"[A-Za-z_]\w*")

VA_NULL, VA_LIST, VA_INT8, VA_INT16, VA_INT32, VA_EXTENDED, VA_STRING, VA_IDENT = range(
    8
)
VA_FALSE, VA_TRUE, VA_BINARY, VA_SET, VA_LSTRING, VA_NIL, VA_COLLECTION = range(8, 15)
VA_SINGLE, VA_CURRENCY, VA_DATE, VA_WSTRING, VA_INT64 = range(15, 20)


@dataclass(frozen=True)
class Ident:
    text: str


@dataclass(frozen=True)
class Binary:
    data: bytes


@dataclass(frozen=True)
class SetValue:
    names: tuple[str, ...]


@dataclass(frozen=True)
class Currency:
    scaled: int


@dataclass
class Collection:
    items: list[list[tuple[str, object]]] = field(default_factory=list)


@dataclass
class Component:
    class_name: str
    name: str
    props: list[tuple[str, object]] = field(default_factory=list)
    children: list["Component"] = field(default_factory=list)


class Reader:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.pos = 0

    def peek(self) -> int:
        return self.data[self.pos]

    def take(self, count: int) -> bytes:
        if self.pos + count > len(self.data):
            raise ValueError(f"truncated TPF0 data at offset {self.pos}")
        chunk = self.data[self.pos : self.pos + count]
        self.pos += count
        return chunk

    def unpack(self, fmt: str) -> tuple:
        return struct.unpack(fmt, self.take(struct.calcsize(fmt)))

    def byte(self) -> int:
        return self.take(1)[0]

    def shortstring(self) -> str:
        return self.take(self.byte()).decode("latin-1")


def extended_to_float(raw: bytes) -> float:
    mantissa, sign_exp = struct.unpack("<QH", raw)
    sign = -1.0 if sign_exp & 0x8000 else 1.0
    exp = sign_exp & 0x7FFF
    if exp == 0 and mantissa == 0:
        return 0.0 * sign
    return sign * mantissa * 2.0 ** (exp - 16383 - 63)


def read_value(r: Reader) -> object:
    kind = r.byte()
    match kind:
        case 2:
            return r.unpack("<b")[0]
        case 3:
            return r.unpack("<h")[0]
        case 4:
            return r.unpack("<i")[0]
        case 5:
            return extended_to_float(r.take(10))
        case 6:
            return r.shortstring()
        case 7:
            return Ident(r.shortstring())
        case 8:
            return False
        case 9:
            return True
        case 10:
            return Binary(r.take(r.unpack("<I")[0]))
        case 11:
            names = []
            while name := r.shortstring():
                names.append(name)
            return SetValue(tuple(names))
        case 12:
            return r.take(r.unpack("<I")[0]).decode("latin-1")
        case 13:
            return None
        case 14:
            return read_collection(r)
        case 15:
            return r.unpack("<f")[0]
        case 16:
            return Currency(r.unpack("<q")[0])
        case 17:
            return r.unpack("<d")[0]
        case 18:
            return r.take(r.unpack("<I")[0] * 2).decode("utf-16-le")
        case 19:
            return r.unpack("<q")[0]
        case 1:
            values = []
            while r.peek() != VA_NULL:
                values.append(read_value(r))
            r.byte()
            return values
    raise ValueError(f"unknown TPF0 value type {kind} at offset {r.pos - 1}")


def read_properties(r: Reader) -> list[tuple[str, object]]:
    props = []
    while name := r.shortstring():
        props.append((name, read_value(r)))
    return props


def read_collection(r: Reader) -> Collection:
    collection = Collection()
    while r.peek() != VA_NULL:
        if r.peek() in (VA_INT8, VA_INT16, VA_INT32):
            read_value(r)
        if r.byte() != VA_LIST:
            raise ValueError(
                f"collection item without list start at offset {r.pos - 1}"
            )
        collection.items.append(read_properties(r))
    r.byte()
    return collection


def read_component(r: Reader) -> Component:
    if r.peek() & FLAG_PREFIX_MASK == FLAG_PREFIX_MASK:
        flags = r.byte()
        if flags & FLAG_CHILD_POS:
            read_value(r)
    component = Component(r.shortstring(), r.shortstring())
    component.props = read_properties(r)
    while r.peek() != VA_NULL:
        component.children.append(read_component(r))
    r.byte()
    return component


def decode_tpf0(data: bytes) -> Component:
    if data[:4] != TPF0_MAGIC:
        raise ValueError("not a TPF0 resource")
    return read_component(Reader(data[4:]))


def quote(text: str) -> str:
    out = []
    in_quote = False
    for ch in text:
        if 32 <= ord(ch) < 127:
            if not in_quote:
                out.append("'")
                in_quote = True
            out.append("''" if ch == "'" else ch)
        else:
            if in_quote:
                out.append("'")
                in_quote = False
            out.append(f"#{ord(ch)}")
    if in_quote:
        out.append("'")
    return "".join(out) or "''"


def render_value(value: object, indent: str) -> list[str]:
    match value:
        case bool():
            return ["True" if value else "False"]
        case Ident(text):
            return [text]
        case str():
            return [quote(value)]
        case Binary(data):
            return ["{" + data.hex().upper() + "}"]
        case SetValue(names):
            return ["[" + ", ".join(names) + "]"]
        case Currency(scaled):
            return [f"{scaled / 10000:.4f}"]
        case None:
            return ["nil"]
        case list():
            lines = ["("]
            for item in value:
                lines.append(f"{indent}  {' '.join(render_value(item, indent + '  '))}")
            lines[-1] += ")"
            return lines
        case Collection(items):
            lines = ["<"]
            for item in items:
                lines.append(f"{indent}  item")
                lines.extend(render_property(n, v, indent + "    ") for n, v in item)
                lines.append(f"{indent}  end")
            lines[-1] += ">"
            return lines if items else ["<>"]
        case _:
            return [str(value)]


def render_property(name: str, value: object, indent: str) -> str:
    return f"{indent}{name} = " + "\n".join(render_value(value, indent))


def render_component(component: Component, indent: str) -> list[str]:
    lines = [f"{indent}object {component.name}: {component.class_name}"]
    lines.extend(render_property(n, v, indent + "  ") for n, v in component.props)
    for child in component.children:
        lines.extend(render_component(child, indent + "  "))
    lines.append(f"{indent}end")
    return lines


def render_dfm(root: Component) -> str:
    return "\n".join(render_component(root, "")) + "\n"


def walk(component: Component):
    yield component
    for child in component.children:
        yield from walk(child)


def collect_handlers(root: Component) -> list[tuple[str, str, str]]:
    return [
        (c.name, name, value.text)
        for c in walk(root)
        for name, value in c.props
        if isinstance(value, Ident) and name.startswith("On")
    ]


def read_forms(pe: pefile.PE) -> list[Component]:
    forms = []
    if not hasattr(pe, "DIRECTORY_ENTRY_RESOURCE"):
        return forms
    for type_entry in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if type_entry.id != RT_RCDATA:
            continue
        for name_entry in type_entry.directory.entries:
            for lang_entry in name_entry.directory.entries:
                leaf = lang_entry.data.struct
                data = pe.get_data(leaf.OffsetToData, leaf.Size)
                if data.startswith(TPF0_MAGIC):
                    forms.append(decode_tpf0(data))
    return forms


def scan_strings(data: bytes) -> list[tuple[int, str]]:
    return [
        (m.start(), m.group().decode("ascii"))
        for m in re.finditer(rb"[\x20-\x7e]{%d,}" % MIN_STRING_LEN, data)
    ]


def parse_sounds(strings: list[tuple[int, str]]) -> list[tuple[str, str, str]]:
    found: dict[str, tuple[str, str]] = {}
    for i in range(len(strings) - 3):
        wav, current, label, event_label = (text for _, text in strings[i : i + 4])
        match = SOUND_CURRENT_RE.fullmatch(current)
        if not wav.lower().endswith(".wav") or not match:
            continue
        event = match.group(1)
        if event_label == EVENT_LABEL_PREFIX + event:
            found[event] = (wav, label)
    problems = [
        f"{event}: expected {wav}, found {found[event][0] if event in found else 'nothing'}"
        for event, wav in EXPECTED_SOUNDS.items()
        if event not in found or found[event][0].lower() != wav
    ]
    if problems:
        raise ValueError("AppEvent table mismatch: " + "; ".join(problems))
    return [(event, *found[event]) for event in EXPECTED_SOUNDS]


def load_app_events(path: Path) -> list[tuple[str, str, str]]:
    return [
        (event, wav, label)
        for event, wav, label in (
            line.split("\t") for line in path.read_text(encoding="utf-8").splitlines()
        )
    ]


def resolve_app_events(
    strings: list[tuple[int, str]], table: list[tuple[str, str, str]]
) -> list[tuple[str, str, str]]:
    """Check each Wise-registered event name is in the image (2.1 keeps no wav records); registry names are case-insensitive and <weapon>Hit is built at run time."""
    present = {text.lower() for _, text in strings}

    def in_image(event: str) -> bool:
        name = event.lower()
        return name in present or (
            name.endswith(HIT_SUFFIX) and name.removesuffix(HIT_SUFFIX) in present
        )

    missing = [event for event, _, _ in table if not in_image(event)]
    if missing:
        raise ValueError("AppEvent names not in the image: " + ", ".join(missing))
    return table


def write_strings(
    data: bytes, offset_to_va: Callable[[int], int], out: Path
) -> list[tuple[int, str]]:
    out.mkdir(parents=True, exist_ok=True)
    strings = scan_strings(data)
    (out / "strings.txt").write_text(
        "".join(f"{offset_to_va(off):08X}\t{text}\n" for off, text in strings),
        encoding="utf-8",
    )
    print(f"{len(strings)} strings written to {out / 'strings.txt'}")
    return strings


def write_string_outputs(
    data: bytes,
    offset_to_va: Callable[[int], int],
    out: Path,
    app_events: list[tuple[str, str, str]] | None = None,
) -> int:
    strings = write_strings(data, offset_to_va, out)
    try:
        rows = (
            parse_sounds(strings)
            if app_events is None
            else resolve_app_events(strings, app_events)
        )
    except ValueError as err:
        print(f"error: {err}", file=sys.stderr)
        return 1
    (out / "sounds.tsv").write_text(
        "".join("\t".join(row) + "\n" for row in rows), encoding="utf-8"
    )
    for event, wav, label in rows:
        print(f"{event}\t{wav}\t{label}")
    return 0


@dataclass
class Image:
    data: bytes
    sections: list[tuple[int, int, int]]  # (va, raw offset, raw size)

    @classmethod
    def from_pe(cls, pe: pefile.PE, data: bytes) -> "Image":
        base = pe.OPTIONAL_HEADER.ImageBase
        return cls(
            data,
            [
                (base + s.VirtualAddress, s.PointerToRawData, s.SizeOfRawData)
                for s in pe.sections
            ],
        )

    def offset(self, va: int, count: int = 1) -> int | None:
        for start, raw, size in self.sections:
            if start <= va and va + count <= start + size:
                return raw + va - start
        return None

    def read(self, va: int, count: int) -> bytes | None:
        off = self.offset(va, count)
        return None if off is None else self.data[off : off + count]

    def u16(self, va: int) -> int | None:
        raw = self.read(va, 2)
        return None if raw is None else struct.unpack("<H", raw)[0]

    def u32(self, va: int) -> int | None:
        raw = self.read(va, 4)
        return None if raw is None else struct.unpack("<I", raw)[0]

    def shortstring(self, va: int) -> str | None:
        length = self.read(va, 1)
        if length is None:
            return None
        raw = self.read(va + 1, length[0])
        return None if raw is None else raw.decode("latin-1")


@dataclass
class Vmt:
    va: int
    class_name: str
    parent: int
    methods: list[tuple[str, int]]


def find_vmts(image: Image) -> list[int]:
    found = []
    for start, raw, size in image.sections:
        words = image.data[raw : raw + size - size % 4]
        for index, (value,) in enumerate(struct.iter_unpack("<I", words)):
            if value == start + index * 4 - VMT_SELF_PTR:
                found.append(value)
    return sorted(found)


def read_published_methods(image: Image, table_va: int) -> list[tuple[str, int]]:
    count = image.u16(table_va)
    if count is None:
        raise ValueError(f"unreadable method table at {table_va:#x}")
    methods = []
    entry = table_va + 2
    for _ in range(count):
        size, code = image.u16(entry), image.u32(entry + 2)
        name = image.shortstring(entry + 6)
        if size is None or code is None or name is None:
            raise ValueError(f"unreadable method entry at {entry:#x}")
        methods.append((name, code))
        entry += size
    return methods


def read_vmt(image: Image, va: int) -> Vmt:
    name_ptr = image.u32(va + VMT_CLASS_NAME)
    name = image.shortstring(name_ptr) if name_ptr else None
    if not name or not CLASS_NAME_RE.fullmatch(name):
        raise ValueError(f"no class name for VMT at {va:#x}")
    table = image.u32(va + VMT_METHOD_TABLE)
    return Vmt(
        va,
        name,
        image.u32(va + VMT_PARENT) or 0,
        read_published_methods(image, table) if table else [],
    )


def read_vmts(image: Image) -> list[Vmt]:
    vmts = []
    for va in find_vmts(image):
        try:
            vmts.append(read_vmt(image, va))
        except ValueError:
            continue
    return vmts


def flatten_methods(vmts: list[Vmt]) -> list[tuple[str, str, int]]:
    return [(v.class_name, name, code) for v in vmts for name, code in v.methods]


def collect_methods(image: Image) -> list[tuple[str, str, int]]:
    return flatten_methods(read_vmts(image))


def orphan_forms(forms: list[Component], vmts: list[Vmt]) -> list[Component]:
    """Form resources whose class was not linked into the image, so they have no code."""
    linked = {v.class_name for v in vmts}
    return [f for f in forms if f.class_name not in linked]


def unresolved_handlers(
    forms: list[Component], methods: list[tuple[str, str, int]]
) -> list[tuple[str, str, str]]:
    known = {(cls, name.lower()) for cls, name, _ in methods}
    return [
        handler
        for form in forms
        for handler in collect_handlers(form)
        if (form.class_name, handler[2].lower()) not in known
    ]


def write_methods(methods: list[tuple[str, str, int]], out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    (out / "methods.tsv").write_text(
        "".join(f"{cls}\t{name}\t{va:08X}\n" for cls, name, va in methods),
        encoding="utf-8",
    )


def sanitize_label(*parts: str) -> str:
    return "_".join(re.sub(r"[^A-Za-z0-9_]", "_", part) for part in parts)


def label_rows(vmts: list[Vmt]) -> list[tuple[int, str]]:
    methods = [
        (code, sanitize_label(v.class_name, name))
        for v in vmts
        for name, code in v.methods
    ]
    return methods + [(v.va, sanitize_label(v.class_name, "VMT")) for v in vmts]


def write_labels(vmts: list[Vmt], out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    (out / "labels.csv").write_text(
        "".join(f"{va:08X},{label}\n" for va, label in label_rows(vmts)),
        encoding="utf-8",
    )


def entropy(data: bytes) -> float:
    counts = [data.count(b) for b in set(data)]
    return -sum(c / len(data) * math.log2(c / len(data)) for c in counts)


def is_pcguard(pe: pefile.PE) -> bool:
    """True while a PC Guard section still holds ciphertext; a process dump keeps the names but not the encryption."""
    for section in pe.sections:
        data = section.get_data()
        if (
            section.Name.rstrip(b"\0") == PCGUARD_SECTION
            and len(data) >= MIN_ENCRYPTED_SECTION_LEN
            and entropy(data) >= ENCRYPTED_ENTROPY
        ):
            return True
    return False


def resolve_exe(arg: str | None) -> Path:
    if arg:
        return Path(arg)
    return Path(os.environ.get("DW_EXE") or DEFAULT_EXE)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Extract Delphi forms from Beermat DopeWars.exe"
    )
    parser.add_argument(
        "--exe",
        help="path to DopeWars.exe (default: $DW_EXE, then vendor/dopewars-1999/DopeWars.exe)",
    )
    parser.add_argument(
        "--out", help="output directory (default: vendor/dopewars-1999/re/)"
    )
    parser.add_argument(
        "--appevents",
        help="appevents.tsv from `task re:unwise`; use it as the sound table (2.1 keeps no wav records in the image)",
    )
    args = parser.parse_args(argv)

    exe = resolve_exe(args.exe)
    if not exe.is_file():
        print(
            f"error: exe not found: {exe} (pass --exe or set DW_EXE)", file=sys.stderr
        )
        return 2
    out = Path(args.out) if args.out else DEFAULT_OUT

    pe = pefile.PE(str(exe))
    forms = read_forms(pe)
    forms_dir = out / "forms"
    forms_dir.mkdir(parents=True, exist_ok=True)
    for form in forms:
        (forms_dir / f"{form.name}.dfm").write_text(render_dfm(form), encoding="utf-8")
        print(f"{form.name}: {form.class_name}")
        for owner, event, handler in collect_handlers(form):
            print(f"  {owner}.{event} = {handler}")
    print(f"{len(forms)} forms written to {forms_dir}")

    data = exe.read_bytes()
    if is_pcguard(pe):
        write_strings(data, lambda off: off, out)
        print(
            f"PC Guard sections ({PCGUARD_SECTION.decode()}) detected: skipping the "
            "sound table, VMT, methods and labels; run on a decrypted process dump "
            "to recover them"
        )
        return 0 if forms else 1

    image_base = pe.OPTIONAL_HEADER.ImageBase
    strings_status = write_string_outputs(
        data,
        lambda off: image_base + pe.get_rva_from_offset(off),
        out,
        load_app_events(Path(args.appevents)) if args.appevents else None,
    )

    vmts = read_vmts(Image.from_pe(pe, data))
    methods = flatten_methods(vmts)
    write_methods(methods, out)
    write_labels(vmts, out)
    print(f"{len(label_rows(vmts))} labels written to {out / 'labels.csv'}")
    classes = len({cls for cls, _, _ in methods})
    print(f"{len(vmts)} VMTs, {classes} classes with {len(methods)} published methods")
    orphans = orphan_forms(forms, vmts)
    for form in orphans:
        print(f"warning: form {form.name} ({form.class_name}) has no VMT in the image")
    missing = unresolved_handlers(
        [f for f in forms if f not in orphans], methods
    )
    for owner, event, handler in missing:
        print(f"error: unresolved handler {owner}.{event} = {handler}", file=sys.stderr)
    return 0 if forms and strings_status == 0 and methods and not missing else 1


if __name__ == "__main__":
    sys.exit(main())
