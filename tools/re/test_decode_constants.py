#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["pefile"]
# ///

"""
Self-test for tools/re/decode_constants.py (TASK-013.01.04).

Usage: uv run tools/re/test_decode_constants.py
"""

import sys
import tempfile
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import decode_constants

# Encoded constants read from the 2.1 dump and the value the game computes from each.
KNOWN = {"35": "5", "37": "7", "EBCE": "15", "D29033": "150", "49C8": "13"}


def test_decode_known_values() -> None:
    for encoded, plain in KNOWN.items():
        assert decode_constants.decode(encoded) == plain, encoded


def test_annotate_replaces_literal_calls_only() -> None:
    consts = {0x4BEA58: "7"}
    src = "a = FUN_004c2c90(param_1,0x4bea58);\nb = FUN_004c2c90(param_1,DAT_004e211c);\nc = FUN_004c2c90(param_1,0x4bea58);"
    out = decode_constants.annotate(src, consts)
    assert out == (
        "a = K(7);\nb = FUN_004c2c90(param_1,DAT_004e211c);\nc = K(7);"
    ), out


def test_annotate_leaves_unknown_addresses() -> None:
    src = "a = FUN_004c2c90(param_1,0x4bea58);"
    assert decode_constants.annotate(src, {}) == src


def test_find_addresses() -> None:
    src = "FUN_004c2c90(param_1,0x4bea4c); FUN_004c2c90(param_1,DAT_004e211c);"
    assert decode_constants.find_addresses(src) == {0x4BEA4C}


def test_annotate_directory() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        src_dir = Path(tmp) / "in"
        out_dir = Path(tmp) / "out"
        src_dir.mkdir()
        (src_dir / "f.c").write_text("x = FUN_004c2c90(p,0x4bea58);")
        (src_dir / "index.tsv").write_text("keep")
        decode_constants.annotate_directory(src_dir, out_dir, {0x4BEA58: "7"})
        assert (out_dir / "f.c").read_text() == "x = K(7);"
        assert (out_dir / "index.tsv").read_text() == "keep"


def main() -> int:
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    failed = 0
    for test in tests:
        try:
            test()
            print(f"ok   {test.__name__}")
        except Exception:
            failed += 1
            print(f"FAIL {test.__name__}")
            traceback.print_exc()
    print(f"{len(tests) - failed}/{len(tests)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
