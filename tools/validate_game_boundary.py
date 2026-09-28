#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///

"""
Fails if any .gd file outside game/simulation/ references DopeWarsWorld, the
GDExtension class registered in extension/src/register_types.cpp.
game/simulation/world.gd is the single pass-through wrapper over
DopeWarsWorld; everything else (presentation/, platform/, content/, tests/)
must reach the simulation only through that wrapper, never the class itself.

This is the Godot-layer edge of the same boundary that
scripts/check-core-boundaries.sh enforces at the core: that one says
core/*.mojo never touches Godot or file I/O, this one says nothing outside
game/simulation/ reaches past the wrapper into the extension.

The one sanctioned exception is a test asserting the class is registered by
name -- ClassDB.class_exists("DopeWarsWorld") names the class without
depending on its API the way instantiating or calling it does.

Usage: uv run tools/validate_game_boundary.py
"""

import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GAME_DIR = REPO_ROOT / "game"
SIM_DIR = GAME_DIR / "simulation"
EXCLUDED_DIRS = {GAME_DIR / "addons", GAME_DIR / ".godot", GAME_DIR / "reports"}

ALLOWED_LINE = re.compile(r'''ClassDB\.class_exists\(\s*["']DopeWarsWorld["']\s*\)''')

RULES: list[tuple[str, re.Pattern[str]]] = [
    ("dopewars-world", re.compile(r"\bDopeWarsWorld\b")),
]


@dataclass(frozen=True)
class Violation:
    path: Path
    line_no: int
    rule: str
    text: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line_no}: [{self.rule}] {self.text}"


def scan_file(path: Path) -> list[Violation]:
    violations = []
    for line_no, raw_line in enumerate(path.read_text().splitlines(), start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#") or ALLOWED_LINE.search(raw_line):
            continue
        for rule, pattern in RULES:
            if pattern.search(raw_line):
                violations.append(Violation(path, line_no, rule, stripped))
    return violations


def gd_files_outside_simulation() -> list[Path]:
    files = []
    for path in sorted(GAME_DIR.rglob("*.gd")):
        if path.is_relative_to(SIM_DIR) or any(path.is_relative_to(d) for d in EXCLUDED_DIRS):
            continue
        files.append(path)
    return files


def check_boundary() -> list[Violation]:
    violations = []
    for path in gd_files_outside_simulation():
        violations.extend(scan_file(path))
    return violations


def main() -> int:
    violations = check_boundary()
    for v in violations:
        print(str(v), file=sys.stderr)

    if violations:
        print(f"{len(violations)} game-boundary violation(s)", file=sys.stderr)
        return 1

    scanned = len(gd_files_outside_simulation())
    print(f"game boundary: OK ({scanned} .gd files outside game/simulation/)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
