#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["pefile"]
# ///

"""
Extracts the Delphi form resources from the Beermat "Dope Wars for Windows"
1.2.0.0 exe into text DFM files (TASK-010.01.01).

Everything written is derived from copyrighted material, so the default output
directory sits under the gitignored vendor/dopewars-1999/. Only this tool and
its self-test are committed.

Usage: uv run tools/re/extract_beermat.py [--exe PATH] [--out DIR]
"""

import argparse
import os
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path

import pefile

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_EXE = REPO_ROOT / "vendor" / "dopewars-1999" / "DopeWars.exe"
DEFAULT_OUT = REPO_ROOT / "vendor" / "dopewars-1999" / "re"

RT_RCDATA = 10
TPF0_MAGIC = b"TPF0"
FLAG_PREFIX_MASK = 0xF0
FLAG_CHILD_POS = 0x02

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
    return 0 if forms else 1


if __name__ == "__main__":
    sys.exit(main())
