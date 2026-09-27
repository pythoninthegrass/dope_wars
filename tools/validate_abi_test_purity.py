#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///
"""Fails if any core/abitest/*.mojo file imports anything besides std.

Tier-C conformance tests (TASK-001.05) must reach the compiled core exclusively
through include/dopewars.h via std.ffi.external_call -- never by importing
rng.mojo/world.mojo/prices.mojo/... directly. Without this guard Tier-C could
silently degrade into a second copy of the parity suite in tests/mojo/.

Modeled on ~/git/jumpnbump/tools/validate_abi_test_purity.py.
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ABITEST_DIR = REPO_ROOT / "core" / "abitest"

IMPORT_RE = re.compile(r"^\s*(?:import|from)\s+([A-Za-z0-9_.]+)")


def main() -> int:
    violations: dict[str, list[str]] = {}
    for path in sorted(ABITEST_DIR.glob("*.mojo")):
        bad: list[str] = []
        for line in path.read_text(encoding="utf-8").splitlines():
            match = IMPORT_RE.match(line)
            if match and not match.group(1).startswith("std"):
                bad.append(match.group(1))
        if bad:
            violations[str(path.relative_to(REPO_ROOT))] = bad

    if violations:
        print("non-std imports found in core/abitest/:", file=sys.stderr)
        for path, names in violations.items():
            for name in names:
                print(f"  {path}: import {name}", file=sys.stderr)
        print(
            "Tier-C tests may only import std -- reach the core via "
            "std.ffi.external_call instead.",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
