#!/usr/bin/env python3
"""Extract the declared ABI symbol surface from include/dopewars.h.

Single source of truth for every gate that needs to know "what does the frozen
contract declare?". The nm-based export gate (task core:build), the exporter
validator (tools/validate_abi_exporter.py) and the conformance harness all ask
this module instead of carrying their own regex, so the gate cannot drift from
the header.

Usage:
  abi_symbols.py                    # every dw_* declaration, one per line
  abi_symbols.py --exported-only    # same (documents intent for the nm gate)
  abi_symbols.py --json             # machine-readable detail
  abi_symbols.py --check            # exit 1 if the header declares nothing
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HEADER = REPO_ROOT / "include" / "dopewars.h"

# A declaration ends at the `;` that closes its parameter list, so match the
# whole `ret name(args);` run rather than a single line. `typedef` lines are
# excluded because `typedef int32_t dw_result;` would otherwise read as a call.
_DECL_RE = re.compile(
    r"^\s*"
    r"(?P<ret>[A-Za-z_][A-Za-z0-9_]*\**)"  # return type, possibly a pointer
    r"\s+"
    r"(?P<name>dw_[A-Za-z0-9_]*)"  # the symbol
    r"\s*\((?P<args>[^;]*?\))\s*;"  # parameter list, up to the terminator
)

# re.M is required: without it ^ and $ anchor to the whole string and the
# pattern matches nothing, which would make macro_ints() silently return {} and
# every caller that trusts it see "macro absent".
_DEFINE_RE = re.compile(r"^\s*#\s*define\s+(DW_[A-Z0-9_]+)\s+(?P<val>.*?)\s*$", re.M)
_STRUCT_ASSERT_RE = re.compile(
    r"DW_STATIC_ASSERT\(\s*sizeof\(\s*(?P<type>[A-Za-z_][A-Za-z0-9_]*)\s*\)"
    r"\s*==\s*(?P<size>\d+)\s*,"
)


@dataclass(frozen=True)
class Declaration:
    name: str
    return_type: str
    params: tuple[str, ...]
    line: int

    @property
    def takes_pointer(self) -> bool:
        return any("*" in p for p in self.params)


def _strip_comments(text: str) -> str:
    """Blank out comments but keep line count stable for accurate line numbers."""
    text = re.sub(
        r"/\*.*?\*/", lambda m: re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S
    )
    text = re.sub(r"//[^\n]*", "", text)
    return text


def parse_declarations(header_text: str) -> list[Declaration]:
    text = _strip_comments(header_text)
    decls: list[Declaration] = []
    for offset, line in enumerate(text.splitlines(), start=1):
        m = _DECL_RE.match(line)
        if not m:
            continue
        if line.lstrip().startswith("typedef"):
            continue
        args = m.group("args").strip().rstrip(")")
        params = (
            tuple(p.strip() for p in args.split(",")) if args and args != "void" else ()
        )
        decls.append(
            Declaration(
                name=m.group("name"),
                return_type=m.group("ret"),
                params=params,
                line=line_count_at(header_text, text, offset),
            )
        )
    return decls


def line_count_at(original: str, stripped: str, stripped_line: int) -> int:
    """Map a line index in the comment-blanked text back to the original.

    Comments are blanked rather than removed, so the two texts have identical
    line counts; this is an identity function kept explicit so the invariant is
    visible if someone switches to a removing strategy.
    """
    assert len(original.splitlines()) == len(stripped.splitlines())
    return stripped_line


def declared_symbols(header_text: str) -> list[str]:
    return [d.name for d in parse_declarations(header_text)]


# C scalar types used by this ABI surface, mapped to the ctypes type name that
# has the same width. Pointers are not in this table: they all become c_void_p.
C_SCALAR_CTYPES: dict[str, str] = {
    "uint32_t": "c_uint32",
    "int32_t": "c_int32",
    "int64_t": "c_int64",
    "uint64_t": "c_uint64",
    "uint16_t": "c_uint16",
    "int16_t": "c_int16",
    "uint8_t": "c_uint8",
    "int8_t": "c_int8",
    "size_t": "c_size_t",
    "unsigned int": "c_uint",
    # The ABI's own scalar typedefs, mapped to the width they alias (see
    # include/dopewars.h:102,156,170,177). Listing them explicitly rather than
    # resolving typedefs generically keeps this table the single place a width
    # is asserted: a typedef whose underlying type changes must be updated here
    # in the same commit, which is the drift signal we want.
    "dw_result": "c_int32",
    "dw_arrival_event_kind": "c_uint8",
    "dw_price_event_kind": "c_uint8",
    "dw_finances_action": "c_uint8",
}


# Strips a parameter's declarator name, leaving only the type: the header writes
# `const dw_location_view *out_locations` and `uint32_t out[]`, and only the type
# informs marshalling. Two shapes: a trailing identifier (pointer or plain), and
# an identifier before an array suffix. Both require preceding whitespace or `*`
# so the type token itself is never eaten.
_PARAM_NAME_RE = re.compile(r"([\s*])[A-Za-z_]\w*(\[[^\]]*\])?$")


class UnsupportedCType(Exception):
    """A header scalar type with no entry in C_SCALAR_CTYPES."""


def c_type_to_ctypes(c_type: str) -> str:
    """One C type as the *name* of its ctypes counterpart.

    Names rather than ctypes classes, so this module stays importable by gates
    and generators that never load a library. Pointers (``dw_world *``,
    ``uint32_t *``) all map to ``c_void_p``: the ABI passes them opaquely and
    this layer never dereferences through a typed pointer, so the pointee type
    carries no marshalling information. Scalars must map exactly, because their
    width decides register placement -- an unmapped scalar raises instead of
    defaulting, since a wrong-width argument is memory corruption that usually
    appears to work.
    """
    # The substitution keeps the separator (group 1) that made the trailing
    # identifier a *name* rather than the type; \1 puts it back.
    normalized = _PARAM_NAME_RE.sub(r"\1", re.sub(r"\s+", " ", c_type).strip()).strip()
    if not normalized or normalized == "void":
        return "None"
    # `const`/`volatile` do not change a value's width or register class.
    normalized = re.sub(r"\b(const|volatile)\b\s*", "", normalized).strip()
    if normalized.endswith(("*", "]")):
        return "c_void_p"
    if normalized in C_SCALAR_CTYPES:
        return C_SCALAR_CTYPES[normalized]
    raise UnsupportedCType(normalized)


def ctypes_prototype(decl: Declaration) -> tuple[str, list[str]]:
    """`(restype, argtypes)` as ctypes type names for one parsed declaration."""
    return c_type_to_ctypes(decl.return_type), [
        c_type_to_ctypes(p) for p in decl.params
    ]


def prototype_map(header_text: str) -> dict[str, tuple[str, list[str]]]:
    """Every declared function's ctypes prototype, keyed by name, in header order."""
    return {d.name: ctypes_prototype(d) for d in parse_declarations(header_text)}


def macro_ints(header_text: str) -> dict[str, int]:
    """Every integer-valued DW_* #define in the header, keyed by name.

    Anything that needs a header constant reads it here rather than restating the
    number, so the macro is defined in exactly one place. Non-integer defines
    (function-like macros, string literals) are skipped.
    """
    out: dict[str, int] = {}
    for match in _DEFINE_RE.finditer(header_text):
        raw = match.group("val").strip()
        try:
            out[match.group(1)] = int(raw.rstrip("uUlL"), 0)
        except ValueError:
            continue
    return out


def abi_version(header_text: str) -> int | None:
    """DW_ABI_VERSION as an int, or None when absent.

    The digit run is the regex match, so it always parses; the guard keeps the
    function total for callers that pass arbitrary text.
    """
    m = re.search(r"^\s*#\s*define\s+DW_ABI_VERSION\s+(\d+)", header_text, re.M)
    if not m:
        return None
    try:
        return int(m.group(1))
    except ValueError:  # pragma: no cover - regex guarantees digits
        return None


def struct_sizes(header_text: str) -> dict[str, int]:
    sizes: dict[str, int] = {}
    for m in _STRUCT_ASSERT_RE.finditer(header_text):
        try:
            sizes[m.group("type")] = int(m.group("size"))
        except ValueError:  # pragma: no cover - regex guarantees digits
            continue
    return sizes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--header", type=Path, default=HEADER)
    parser.add_argument("--json", action="store_true", help="emit detail as JSON")
    parser.add_argument("--check", action="store_true", help="validate, print nothing")
    ns = parser.parse_args()

    text = ns.header.read_text(encoding="utf-8")
    decls = parse_declarations(text)

    if ns.check:
        if not decls:
            print(f"{ns.header}: no dw_* declarations parsed", file=sys.stderr)
            return 1
        dupes = {d.name for d in decls if [x.name for x in decls].count(d.name) > 1}
        if dupes:
            print(
                f"{ns.header}: duplicate declarations {sorted(dupes)}", file=sys.stderr
            )
            return 1
        return 0

    if ns.json:
        json.dump(
            {
                "abi_version": abi_version(text),
                "header": str(ns.header),
                "struct_sizes": struct_sizes(text),
                "declarations": [
                    {
                        "name": d.name,
                        "return_type": d.return_type,
                        "params": list(d.params),
                        "line": d.line,
                        "takes_pointer": d.takes_pointer,
                    }
                    for d in decls
                ],
            },
            fp=sys.stdout,
            indent=2,
            sort_keys=True,
        )
        print()
        return 0

    for d in decls:
        print(d.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
