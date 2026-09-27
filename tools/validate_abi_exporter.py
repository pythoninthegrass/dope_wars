#!/usr/bin/env python3
"""Export-surface gate (TASK-001.05 AC#1/#5, source-level half).

The frozen contract in include/dopewars.h must have exactly one exporter:
core/src/abi.mojo. This script is the fast, build-free half of that gate — it
reads the sources and fails if any core/src/*.mojo file other than abi.mojo
carries an `@export`.

It is deliberately *not* the whole gate. A source-level scan cannot see what
the linker actually exposed (Mojo emits its runtime's symbols as globals), so
task core:build pairs this with an `nm -g --defined-only` check against the set
tools/abi_symbols.py parses out of the header. Both are needed: this one fails
in a second with a message pointing at the offending line, that one is
authoritative about the artifact.

Why scoped to `@export` rather than "no exported symbol of any kind": Mojo's
`@export` is the only spelling that produces a global definition from core
source, so a blanket rule would be the same rule with more false positives.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CORE_SRC = REPO_ROOT / "core" / "src"
SOLE_EXPORTER = "abi.mojo"

# `@export("dw_thing")`, with optional whitespace/newline before the arguments,
# and the bare `@export` form (which exports under the Mojo function's own
# name). Both make a global definition, so both belong to the sole exporter.
_EXPORT_RE = re.compile(r"@export\b")


def strip_comments(text: str) -> str:
    """Blank comments so a mention inside prose does not count as an export."""
    text = re.sub(
        r'""".*?"""', lambda m: re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S
    )
    text = re.sub(r"#[^\n]*", "", text)
    return text


def scan(path: Path) -> list[int]:
    """Line numbers in `path` where an @export appears (in the original file)."""
    hits: list[int] = []
    for lineno, line in enumerate(
        strip_comments(path.read_text(encoding="utf-8")).splitlines(), 1
    ):
        if _EXPORT_RE.search(line):
            hits.append(lineno)
    return hits


def find_violations(core_src: Path = CORE_SRC) -> dict[str, list[int]]:
    violations: dict[str, list[int]] = {}
    if not core_src.is_dir():
        return violations
    for path in sorted(core_src.glob("*.mojo")):
        if path.name == SOLE_EXPORTER:
            continue
        hits = scan(path)
        if hits:
            violations[str(path.relative_to(REPO_ROOT))] = hits
    return violations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-src", type=Path, default=CORE_SRC)
    ns = parser.parse_args()

    violations = find_violations(ns.core_src)
    if violations:
        print(
            f"@export found outside core/src/{SOLE_EXPORTER} "
            f"(the ABI contract has exactly one exporter — see docs/abi-contract.md):",
            file=sys.stderr,
        )
        for path, lines in violations.items():
            for lineno in lines:
                print(f"  {path}:{lineno}: @export", file=sys.stderr)
        print(
            "\nRe-export from core/src/abi.mojo instead: keep the rule in the "
            "sibling module and wrap it there.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
