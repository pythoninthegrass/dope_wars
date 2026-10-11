#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["pefile"]
# ///

"""
Decode the obfuscated numeric constants in the Beermat 2.1 decompile (TASK-013.01.04).

2.1 never stores a number literally. A game rule calls `FUN_004c2c90(Self, <string>)`, which turns a hex-pair string into bytes, runs four XOR/multiply passes over them and converts the resulting text with StrToInt. This tool reads each literal string address from the dump and writes a copy of decompiled/ with those calls replaced by `K(<value>)`, plus constants.tsv.

Usage: uv run tools/re/decode_constants.py [--exe vendor/dopewars-2001/dump/DopeWars.dump.exe] [--re vendor/dopewars-2001/re]
"""

import argparse
import re
import shutil
import struct
import sys
from pathlib import Path

import pefile

DECODER = "FUN_004c2c90"
# Multipliers of the four passes, in the order the decoder applies them.
MULTIPLIERS = (0xE2, 0xE4, 0xE6, 0xEA)

CALL = re.compile(rf"{DECODER}\(\s*\w+\s*,\s*0x([0-9a-fA-F]+)\s*\)")
# A reference to a string literal: Ghidra's s_<text>_<va> label or a DAT_<va> label, with the cast it usually wears.
REFERENCE = re.compile(
    r"(?:\(undefined4 \*\))?(?:s_[0-9A-Fa-f]+_|&?DAT_)([0-9a-f]{8})\b"
)


def decode(encoded: str) -> str:
    """Plain text of one encoded constant (hex pairs in, characters out)."""
    n = len(encoded) // 2
    b = [int(encoded[2 * i : 2 * i + 2], 16) for i in range(n)]
    m1, m2, m3, m4 = MULTIPLIERS
    for i in range(n - 2):
        b[i] ^= b[i + 2] ^ ((m1 * b[i + 1]) & 0xFF)
    for j in range(n - 1, 1, -1):
        b[j] ^= b[j - 2] ^ ((m2 * b[j - 1]) & 0xFF)
    for i in range(n - 1):
        b[i] ^= b[i + 1] ^ ((b[i + 1] * m3) & 0xFF)
    for j in range(n - 1, 0, -1):
        b[j] ^= b[j - 1] ^ ((b[j - 1] * m4) & 0xFF)
    return "".join(chr(x) for x in b)


def find_addresses(source: str) -> set[int]:
    """Addresses of the literal strings a function passes to the decoder."""
    found = {int(m.group(1), 16) for m in CALL.finditer(source)}
    return found | {int(m.group(1), 16) for m in REFERENCE.finditer(source)}


def annotate(source: str, consts: dict[int, str]) -> str:
    def replace(m: re.Match[str]) -> str:
        value = consts.get(int(m.group(1), 16))
        return m.group(0) if value is None else f"K({value})"

    def replace_reference(m: re.Match[str]) -> str:
        value = consts.get(int(m.group(1), 16))
        return m.group(0) if value is None else f"S({value})"

    return REFERENCE.sub(replace_reference, CALL.sub(replace, source))


def annotate_directory(src: Path, dst: Path, consts: dict[int, str]) -> None:
    dst.mkdir(parents=True, exist_ok=True)
    for path in src.iterdir():
        if path.suffix == ".c":
            (dst / path.name).write_text(
                annotate(path.read_text(encoding="utf-8"), consts), encoding="utf-8"
            )
        else:
            shutil.copy(path, dst / path.name)


def read_long_string(pe: pefile.PE, va: int) -> str:
    """The Delphi literal string at va: reference count -1 (literal), a length, then the characters."""
    base = pe.OPTIONAL_HEADER.ImageBase
    refcount, length = struct.unpack("<iI", pe.get_data(va - 8 - base, 8))
    if refcount != -1 or length == 0 or length % 2 or length > 64:
        raise ValueError("not a string literal")
    text = pe.get_data(va - base, length).decode("latin1")
    int(text, 16)
    return text


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--exe", default="vendor/dopewars-2001/dump/DopeWars.dump.exe")
    ap.add_argument("--re", default="vendor/dopewars-2001/re")
    args = ap.parse_args()

    re_dir = Path(args.re)
    src = re_dir / "decompiled"
    addresses: set[int] = set()
    for path in src.glob("*.c"):
        addresses |= find_addresses(path.read_text(encoding="utf-8"))

    pe = pefile.PE(args.exe)
    consts: dict[int, str] = {}
    for va in sorted(addresses):
        try:
            consts[va] = decode(read_long_string(pe, va))
        except (ValueError, struct.error, pefile.PEFormatError):
            continue

    annotate_directory(src, re_dir / "decompiled_k", consts)
    with (re_dir / "constants.tsv").open("w", encoding="utf-8") as fh:
        for va, value in consts.items():
            fh.write(f"{va:08x}\t{value}\n")
    print(f"decoded {len(consts)} constants -> {re_dir}/decompiled_k")
    return 0


if __name__ == "__main__":
    sys.exit(main())
