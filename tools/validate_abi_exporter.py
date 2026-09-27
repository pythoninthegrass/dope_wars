#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///
"""Fails if any core/src/*.mojo file other than abi.mojo exports a dw_-prefixed
symbol (TASK-001.05).

include/dopewars.h's frozen ABI surface must have exactly one exporter. This is
the source-level twin of the post-link `nm -g` gate in
tools/validate_abi_symbols.py: a contributor who adds an @export("dw_...")
somewhere else in core/src gets a fast failure without waiting on a build.

Modeled on ~/git/jumpnbump/tools/validate_abi_exporter.py.
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CORE_SRC = REPO_ROOT / "core" / "src"
EXEMPT_FILES = {"abi.mojo"}

EXPORT_RE = re.compile(r'@export\(\s*"(dw_[A-Za-z0-9_]*|dopewars_[A-Za-z0-9_]*)"\s*\)')


def strip_comments(text: str) -> str:
    text = re.sub(r"#.*", "", text)
    return text


def scan(path: Path) -> list[str]:
    text = strip_comments(path.read_text(encoding="utf-8"))
    return [m.group(1) for m in EXPORT_RE.finditer(text)]


def main() -> int:
    violations: dict[str, list[str]] = {}
    for path in sorted(CORE_SRC.glob("*.mojo")):
        if path.name in EXEMPT_FILES:
            continue
        names = scan(path)
        if names:
            violations[str(path.relative_to(REPO_ROOT))] = names

    if violations:
        print("dw_-prefixed exports found outside core/src/abi.mojo:", file=sys.stderr)
        for path, names in violations.items():
            for name in names:
                print(f"  {path}: @export(\"{name}\")", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
