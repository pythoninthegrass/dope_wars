#!/usr/bin/env python3
"""Conformance-test purity gate (TASK-001.05 AC#2/#3).

Tier-C ABI conformance tests must reach the simulation *only* through the C ABI
in include/dopewars.h — via ctypes against the linked library, or via a C
translation unit that `#include`s the header. If a conformance test were allowed
to `import rules` (or `from world import World`, or to shell out to
`mojo run`), it would silently degrade into a second copy of the Tier-A parity
suite in tests/mojo/ and stop proving anything about the boundary.

Enforced here:

1. No import of a core module (the modules under core/src, or `src.`/`core.src`
   dotted forms).
2. No Mojo subprocess. ctypes is the sanctioned mechanism; spawning the Mojo
   toolchain from a conformance test is a purity escape hatch.
3. Every Python conformance test must actually name the shared library it loads
   and must name include/dopewars.h somewhere, so "it imports nothing" cannot be
   satisfied by a test that does nothing at all.

Scanned: core/abitest/**. That is where Tier-C lives; tests/mojo/** is Tier-A
and is intentionally allowed to import core modules directly.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ABITEST_DIR = REPO_ROOT / "core" / "abitest"

CORE_MODULE_NAMES = (
    "abi",
    "combat",
    "dealers",
    "events",
    "finances",
    "floatbits",
    "jsmath",
    "prices",
    "result",
    "rng",
    "rules",
    "score",
    "serialize",
    "trade",
    "travel",
    "world",
)

# `import rules`, `import rules as r`, `from rules import X`, and the dotted
# package spellings that reach the same files (`core.src.rules`, `src.rules`).
_IMPORT_RE = re.compile(
    r"^\s*(?:import|from)\s+(?P<mod>(?:core\.)?src\.|)(?P<leaf>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?P<rest>[^\n]*)",
    re.M,
)

_MOJO_SUBPROCESS_RE = re.compile(
    r"\b(mojo run|mojo build|mojo test|\.venv/bin/mojo|subprocess[^\n]*mojo)\b"
)

# A test that names neither the library nor the header is not reaching the ABI
# by any mechanism we recognise.
#
# Both checks run against the code, not the prose: strip_noise() has already
# blanked docstrings and comments, so "include/dopewars.h" mentioned only in a
# comment proves nothing and does not satisfy the gate. What does is the header
# being a live input to the test -- parsed, or passed in as an argument -- which
# is what makes "it imports no core module" a statement about the C boundary
# rather than about a test that does nothing.
_LIB_REF_RE = re.compile(r"libdopewars|CDLL|LoadLibrary|dlopen|ctypes\.cdll")
_HEADER_REF_RE = re.compile(
    r"""
      HEADER                                   # the parsed-header constant
    | dopewars\.h                              # the path, spelled
    | parse_declarations|prototype_map         # consuming the header
    """,
    re.X,
)


def strip_noise(text: str) -> str:
    """Blank block strings and comments so prose about imports is not scanned."""
    # Triple-quoted strings first (module docstrings mention the words we match).
    text = re.sub(
        r'""".*?"""', lambda m: re.sub(r"[^\n]", " ", m.group(0)), text, flags=re.S
    )
    text = re.sub(r"#[^\n]*", "", text)
    return text


def _is_core_import(mod_prefix: str, leaf: str, rest: str) -> bool:
    if mod_prefix:  # src. / core.src. — always the core tree
        return leaf in CORE_MODULE_NAMES or leaf == "*"
    if leaf in ("core", "src"):
        return True
    if leaf in CORE_MODULE_NAMES:
        # `import json` etc. never collide, but `from result import ...` from a
        # stdlib-ish name is worth a look at the rest of the line.
        return True
    del rest
    return False


def scan_python(path: Path) -> list[str]:
    text = strip_noise(path.read_text(encoding="utf-8"))
    problems: list[str] = []

    for m in _IMPORT_RE.finditer(text):
        if _is_core_import(
            m.group("mod") or "", m.group("leaf"), m.group("rest") or ""
        ):
            lineno = text[: m.start()].count("\n") + 1
            problems.append(f"{path}:{lineno}: imports core module '{m.group('leaf')}'")

    for m in _MOJO_SUBPROCESS_RE.finditer(text):
        lineno = text[: m.start()].count("\n") + 1
        problems.append(f"{path}:{lineno}: drives the Mojo toolchain ({m.group(1)})")

    if not _LIB_REF_RE.search(text):
        problems.append(f"{path}: never references the shared library (ctypes/CDLL)")
    if not _HEADER_REF_RE.search(text):
        problems.append(f"{path}: never references include/dopewars.h")

    return problems


def scan_c(path: Path) -> list[str]:
    """A C conformance TU must get its declarations from the header, nowhere else."""
    raw = path.read_text(encoding="utf-8")
    text = re.sub(r"/\*.*?\*/", " ", raw, flags=re.S)
    text = re.sub(r"//[^\n]*", "", text)
    problems: list[str] = []

    includes = re.findall(r'#\s*include\s*[<"]([^">]*)[">]', text)
    if not any(i.endswith("dopewars.h") for i in includes):
        problems.append(f'{path}: does not #include "dopewars.h"')
    for inc in includes:
        if inc.endswith((".mojo", ".cpp", ".hpp")) or "core/src" in inc:
            problems.append(f"{path}: #includes core internals ({inc})")
    # Redeclaring an ABI symbol locally instead of taking it from the header
    # would let a test pass against a prototype the library does not export.
    if re.search(r"\bextern\s+[A-Za-z_][\w\s\*]*\bdw_[A-Za-z0-9_]+\s*\(", text):
        problems.append(f"{path}: redeclares a dw_* symbol instead of using the header")
    return problems


def find_violations(abitest_dir: Path = ABITEST_DIR) -> list[str]:
    problems: list[str] = []
    if not abitest_dir.is_dir():
        return [f"{abitest_dir}: Tier-C conformance directory does not exist"]
    files = sorted(
        p
        for p in abitest_dir.rglob("*")
        if p.is_file() and p.suffix in {".py", ".c", ".mojo"}
    )
    if not files:
        return [f"{abitest_dir}: no conformance test files found"]
    for path in files:
        if path.suffix == ".mojo":
            # A .mojo file in Tier-C is only legitimate as the ctypes-side
            # library-under-test, which purity forbids calling directly.
            problems.append(
                f"{path}: .mojo file in the conformance tier (must reach the ABI via C)"
            )
        elif path.suffix == ".py":
            problems.extend(scan_python(path))
        elif path.suffix == ".c":
            problems.extend(scan_c(path))
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--abitest-dir", type=Path, default=ABITEST_DIR)
    ns = parser.parse_args()

    problems = find_violations(ns.abitest_dir)
    if problems:
        print("ABI conformance test purity violated:", file=sys.stderr)
        for p in problems:
            print(f"  {p}", file=sys.stderr)
        print(
            "\nTier-C reaches the library exclusively through include/dopewars.h "
            "(ctypes or a C TU). Core modules are tested by Tier-A in tests/mojo/.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
