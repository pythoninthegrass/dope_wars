#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Fail unless the Ghidra decompile export under vendor/dopewars-1999/re/decompiled is populated and address-tagged."""

import re
import sys
from pathlib import Path

OUT = Path("vendor/dopewars-1999/re/decompiled")
LABELS = Path("vendor/dopewars-1999/re/labels.csv")
MIN_FUNCTIONS = 200
INDEX_ROW = re.compile(r"^[0-9a-f]{8}\t\S+\t\S+\.c$")


def check(out: Path = OUT) -> list[str]:
    index = out / "index.tsv"
    if not index.is_file():
        return [f"missing {index}"]
    rows = [r for r in index.read_text().splitlines() if r.strip()]
    errors = [f"malformed index row: {r!r}" for r in rows if not INDEX_ROW.match(r)]
    if len(rows) < MIN_FUNCTIONS:
        errors.append(f"index has {len(rows)} rows, expected >= {MIN_FUNCTIONS}")
    for row in rows:
        if not INDEX_ROW.match(row):
            continue
        va, _, rest = row.split("\t")[0], None, row.split("\t")[2]
        src = out / rest
        if not src.is_file() or not src.read_text().strip():
            errors.append(f"empty or missing {src}")
            continue
        if f"0x{va}" not in src.read_text().splitlines()[0]:
            errors.append(f"{src} first line lacks address 0x{va}")
    return errors + missing_labeled_functions(out, rows)


def missing_labeled_functions(out: Path, rows: list[str], labels: Path = LABELS) -> list[str]:
    """Every non-VMT label must have been decompiled, or the handler it names was never disassembled."""
    exported = {r.split("\t")[0] for r in rows}
    errors = []
    for line in labels.read_text().splitlines():
        va, _, name = line.partition(",")
        if line.strip() and not name.endswith("_VMT") and f"{int(va, 16):08x}" not in exported:
            errors.append(f"labeled function {name} at 0x{va} was not decompiled")
    return errors


if __name__ == "__main__":
    errs = check()
    for e in errs[:20]:
        print(f"ERROR: {e}", file=sys.stderr)
    if errs:
        sys.exit(1)
    print("check_decompiled: ok")
