#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = []
# ///

"""
Extracts the game files from the Wise installer for Beermat "Dope Wars for
Windows" 2.1.0.0 (TASK-013.01.01).

dw21.exe is a PE32 stub followed by raw-deflate streams, each trailed by its
little-endian CRC32. One stream is the Wise script; its install-file records
name each file and give the stream's size and extent. Only DopeWars.exe,
cities.txt, oldlady.txt and Sounds/*.wav are written: the Gator stub
(Trickler_PIC_Beermat_Dopewars.exe) and the installer's own helpers never
leave memory, and the installer is never run.

Everything written is derived from copyrighted material, so the default output
directory sits under the gitignored vendor/dopewars-2001/. Only this tool and
its self-test are committed.

Usage: uv run tools/re/unwise.py [--exe PATH] [--out DIR]
"""

import argparse
import re
import struct
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_EXE = REPO_ROOT / "vendor" / "dopewars-2001" / "dw21.exe"
DEFAULT_OUT = REPO_ROOT / "vendor" / "dopewars-2001" / "game"

CRC_LEN = 4
MAX_INFLATED = 64 * 1024 * 1024
SCAN_START = 0x400
SCRIPT_MARKER = b"%MAINDIR%\\"
PATH_RE = re.compile(rb"%(?:MAINDIR|SYS)%\\([\x20-\x7e]+?)\x00")

# Byte offsets of the record fields, counted back from the '%' of the path.
START_BACK = 0x28
END_BACK = 0x24
SIZE_BACK = 0x1C

# olchk32.dll is PC Guard's runtime check library; the installer puts it in the system dir and the game will not start without it.
WANTED_ROOT_FILES = {"dopewars.exe", "cities.txt", "oldlady.txt", "olchk32.dll"}
SOUNDS_DIR = "Sounds"


@dataclass(frozen=True)
class Stream:
    offset: int
    span: int
    data: bytes


@dataclass(frozen=True)
class Entry:
    path: str
    data: bytes


def inflate_at(data: bytes, offset: int) -> Stream | None:
    """Return the CRC-checked raw-deflate stream starting at offset, if there is one."""
    if (data[offset] >> 1) & 3 == 3:
        return None
    decomp = zlib.decompressobj(-15)
    try:
        out = decomp.decompress(memoryview(data)[offset:], MAX_INFLATED)
    except zlib.error:
        return None
    if not decomp.eof or not out:
        return None
    end = len(data) - len(decomp.unused_data)
    trailer = data[end : end + CRC_LEN]
    if len(trailer) < CRC_LEN or struct.unpack("<I", trailer)[0] != zlib.crc32(out):
        return None
    return Stream(offset, end + CRC_LEN - offset, out)


def find_streams(data: bytes) -> list[Stream]:
    streams = []
    pos = SCAN_START
    while pos < len(data) - CRC_LEN:
        found = inflate_at(data, pos)
        if found:
            streams.append(found)
            pos += found.span
        else:
            pos += 1
    return streams


def script_records(script: bytes) -> list[tuple[str, int, int, int]]:
    """Return (path, start, end, size) for every path with room for the record fields."""
    records = []
    for match in PATH_RE.finditer(script):
        at = match.start()
        if at < START_BACK:
            continue
        (start,) = struct.unpack_from("<I", script, at - START_BACK)
        (end,) = struct.unpack_from("<I", script, at - END_BACK)
        (size,) = struct.unpack_from("<I", script, at - SIZE_BACK)
        records.append((match.group(1).decode("ascii"), start, end, size))
    return records


def match_records(script: bytes, streams: list[Stream]) -> list[Entry]:
    """Pair script records with streams by size and extent, in stream order."""
    entries = []
    seen = set()
    cursor = 0
    for path, start, end, size in script_records(script):
        for stream in streams:
            if (
                stream.offset >= cursor
                and len(stream.data) == size
                and stream.span == end - start
            ):
                cursor = stream.offset + stream.span
                if path.lower() not in seen:
                    seen.add(path.lower())
                    entries.append(Entry(path, stream.data))
                break
    return entries


def wanted_path(path: str) -> PurePosixPath | None:
    """Map a script path to its output path, or None for anything not wanted."""
    parts = path.replace("\\", "/").split("/")
    if len(parts) == 1 and parts[0].lower() in WANTED_ROOT_FILES:
        return PurePosixPath(parts[0])
    if (
        len(parts) == 2
        and parts[0].lower() == SOUNDS_DIR.lower()
        and parts[1].lower().endswith(".wav")
    ):
        return PurePosixPath(SOUNDS_DIR, parts[1])
    return None


def extract_entries(data: bytes) -> list[Entry]:
    streams = find_streams(data)
    scripts = [s for s in streams if SCRIPT_MARKER in s.data]
    if not scripts:
        raise ValueError("no Wise script stream found")
    entries = []
    for script in scripts:
        entries = match_records(script.data, streams)
        if entries:
            break
    return [
        Entry(str(out), e.data)
        for e in entries
        if (out := wanted_path(e.path)) is not None
    ]


def write_entries(entries: list[Entry], out_dir: Path) -> int:
    """Write entries under out_dir, leaving files whose content already matches. Return the number changed."""
    changed = 0
    for entry in entries:
        target = out_dir / entry.path
        if target.is_file() and target.read_bytes() == entry.data:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(entry.data)
        changed += 1
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--exe", type=Path, default=DEFAULT_EXE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    if not args.exe.is_file():
        print(f"installer not found: {args.exe}", file=sys.stderr)
        return 1
    entries = extract_entries(args.exe.read_bytes())
    names = {e.path for e in entries}
    missing = [
        n for n in ("DopeWars.exe", "cities.txt", "oldlady.txt") if n not in names
    ]
    if missing or not any(n.startswith(SOUNDS_DIR + "/") for n in names):
        print(f"payload incomplete, missing: {missing or SOUNDS_DIR}", file=sys.stderr)
        return 1
    changed = write_entries(entries, args.out)
    print(
        f"{len(entries)} files in {args.out} ({changed} written, {len(entries) - changed} unchanged)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
