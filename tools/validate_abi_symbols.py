#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///
"""Fails if the built Mojo static library exposes any symbol outside the dw_ ABI
surface (TASK-001.05).

This is the post-link half of the single-exporter discipline: it catches every
symbol regardless of source file, so it is stronger than the source-level
tools/validate_abi_exporter.py. Run against core/build-output/lib/libdopewars.a.

Usage: tools/validate_abi_symbols.py <path-to-libdopewars.a>
"""

import subprocess
import sys
from pathlib import Path

# nm prints one line per symbol: "<address> <type> <name>". Only defined global
# symbols (uppercase type letters) matter; undefined references (U) and local
# symbols (lowercase) are not part of the exported surface.
DEFINED_TYPES = set("TDBRSVW")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_abi_symbols.py <libdopewars.a>", file=sys.stderr)
        return 2
    lib = Path(sys.argv[1])
    if not lib.exists():
        print(f"{lib}: not found", file=sys.stderr)
        return 1

    result = subprocess.run(
        ["nm", "-g", "--defined-only", str(lib)],
        capture_output=True,
        text=True,
        check=True,
    )

    offenders: list[str] = []
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) < 3:
            continue
        symbol_type, name = parts[-2], parts[-1]
        if symbol_type not in DEFINED_TYPES:
            continue
        # macOS prefixes C symbols with an underscore; Linux does not.
        bare = name[1:] if name.startswith("_") else name
        if not bare.startswith("dw_"):
            offenders.append(name)

    if offenders:
        print(f"{lib}: non-ABI symbols exposed:", file=sys.stderr)
        for name in offenders:
            print(f"  {name}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
