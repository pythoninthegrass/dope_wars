#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = []
# ///

"""
Self-test for tools/re/unwise.py (TASK-013.01.01).

Builds a synthetic Wise-style payload (PE-like stub, a script stream, raw
deflate file streams with CRC trailers) in memory, so the extractor is checked
without the copyrighted installer being present.

Usage: uv run tools/re/test_unwise.py
"""

import struct
import sys
import tempfile
import traceback
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import unwise

STUB = b"MZ" + bytes(range(64)) * 16
GATOR_NAME = "GatInst\\Trickler_PIC_Beermat_Dopewars.exe"
FILES = [
    ("Sounds\\gun.wav", b"RIFF" + b"\x01\x02" * 400),
    ("Sounds\\cash.wav", b"RIFF" + b"\x03\x04\x05" * 300),
    ("Trickler.exe", b"MZ" + b"gator" * 200),
    ("oldlady.txt", b"Wouldn't you like a drink?\n" * 20),
    ("cities.txt", b"New York\n" * 30),
    ("DopeWars.exe", b"MZP" + bytes(range(256)) * 12),
    ("WiseUpdt.exe", b"MZ" + b"updater" * 150),
]


def raw_deflate(payload: bytes) -> bytes:
    comp = zlib.compressobj(9, zlib.DEFLATED, -15)
    return (
        comp.compress(payload) + comp.flush() + struct.pack("<I", zlib.crc32(payload))
    )


def record(name: str, start: int, end: int, size: int) -> bytes:
    """Mirror the layout seen in dw21.exe: start, end, datetime, size, padding, then the path."""
    fields = struct.pack("<IIII", start, end, 0, size)
    return (
        fields.ljust(unwise.START_BACK, b"\0") + b"%MAINDIR%\\" + name.encode() + b"\0"
    )


def build_installer(files: list[tuple[str, bytes]], noise: bytes = b"") -> bytes:
    streams = [raw_deflate(data) for _, data in files]
    records = b""
    start = 0
    for (name, data), stream in zip(files, streams):
        records += record(name, start, start + len(stream), len(data))
        start += len(stream)
    # a trailing uninstall-style listing without usable record fields
    listing = b"\0" * 0x30 + b"%MAINDIR%\\" + files[0][0].encode() + b"\0"
    script = b"%MAINDIR%\\INSTALL.LOG\0" + records + listing
    return STUB + noise + raw_deflate(script) + b"".join(streams)


def extract(installer: bytes) -> dict[str, bytes]:
    return {e.path: e.data for e in unwise.extract_entries(installer)}


def test_extracts_wanted_files() -> None:
    got = extract(build_installer(FILES))
    expected = {
        "Sounds/gun.wav": FILES[0][1],
        "Sounds/cash.wav": FILES[1][1],
        "oldlady.txt": FILES[3][1],
        "cities.txt": FILES[4][1],
        "DopeWars.exe": FILES[5][1],
    }
    assert got == expected, sorted(got)


def test_never_extracts_gator_or_helpers() -> None:
    files = FILES + [(GATOR_NAME, b"MZ" + b"gator" * 99)]
    got = extract(build_installer(files))
    assert not any("trickler" in p.lower() or "wiseupdt" in p.lower() for p in got), (
        sorted(got)
    )
    assert not any(b"gator" in data for data in got.values())


def test_duplicate_streams_keep_record_order() -> None:
    same = b"RIFF" + b"\x07" * 500
    files = [("Sounds\\a.wav", same), ("Sounds\\b.wav", same)] + FILES[3:6]
    got = extract(build_installer(files))
    assert got["Sounds/a.wav"] == got["Sounds/b.wav"] == same


def test_ignores_deflate_lookalikes_without_crc() -> None:
    noise = zlib.compress(b"decoy" * 100)[2:-4]
    got = extract(build_installer(FILES, noise=noise))
    assert set(got) == {
        "Sounds/gun.wav",
        "Sounds/cash.wav",
        "oldlady.txt",
        "cities.txt",
        "DopeWars.exe",
    }


def test_rejects_missing_script() -> None:
    try:
        unwise.extract_entries(STUB + raw_deflate(b"no script here" * 10))
    except ValueError:
        return
    raise AssertionError("expected ValueError")


def test_write_is_idempotent() -> None:
    entries = unwise.extract_entries(build_installer(FILES))
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp)
        assert unwise.write_entries(entries, out) == len(entries)
        before = {
            p.relative_to(out): p.read_bytes() for p in out.rglob("*") if p.is_file()
        }
        assert unwise.write_entries(entries, out) == 0
        after = {
            p.relative_to(out): p.read_bytes() for p in out.rglob("*") if p.is_file()
        }
        assert before == after
        assert (out / "Sounds" / "gun.wav").read_bytes() == FILES[0][1]
        assert not list(out.rglob("*rickler*"))


def test_wanted_path_filters() -> None:
    assert str(unwise.wanted_path("DopeWars.exe")) == "DopeWars.exe"
    assert str(unwise.wanted_path("sounds\\store.wav")) == "Sounds/store.wav"
    assert unwise.wanted_path("WiseUpdt.exe") is None
    assert unwise.wanted_path("Sounds\\evil.exe") is None
    assert unwise.wanted_path("Sounds\\..\\DopeWars.exe") is None
    assert unwise.wanted_path("License.txt") is None


def main() -> int:
    tests = [
        (n, f)
        for n, f in sorted(globals().items())
        if n.startswith("test_") and callable(f)
    ]
    failed = 0
    for name, fn in tests:
        try:
            fn()
        except Exception:
            failed += 1
            print(f"FAIL {name}", file=sys.stderr)
            traceback.print_exc()
    print(f"{len(tests) - failed}/{len(tests)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
