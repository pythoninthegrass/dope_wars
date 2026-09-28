#!/usr/bin/env python3
"""Export-surface gate (TASK-001.05 AC#1/#5, artifact-level half).

Asserts that a built artifact's *global defined* symbol set is exactly the set
of dw_* functions declared in include/dopewars.h. This is the authoritative
version of the export contract: unlike tools/validate_abi_exporter.py, which
reads source, this reads what the toolchain actually produced, so it catches
Mojo emitting runtime symbols as globals and catches a binding that quietly
re-exports something the header never promised.

Sets compared:
  declared = dw_* function declarations parsed from include/dopewars.h
  exported = global, defined (nm type T/D/R/B/W/V) symbols in the artifact

Anything in exported but not declared is a leak -- unconditionally an error, and
the half of this gate that is fully enforceable today.

Anything in declared but not exported is a missing definition. The gate
distinguishes two kinds via the same objective criterion the exporter is written
against: a declaration whose signature takes a pointer, or returns one, was
*blocked* on Mojo 1.1.0 -- the version pinned when this gate was written. The
OptionalPointer[T, origin=UntrackedOrigin] spelling documented in
docs/mojo-1.1.0-abi-constraints.md exports them all, so the blocked set is
derived rather than believed: it exists to keep a downgrade-visible regression
from failing the build for a reason no commit can fix, and it subtracts nothing
while every declaration is exported. A pointer-free signature that is absent is
always a regression and fails.

dw_world_size was the one non-pointer-signature declaration listed as blocked
(no reachable sizeof for the opaque handle); core/src/abi.mojo exports it via
size_of[World](), so NON_POINTER_BLOCKED is now empty. Keep the mechanism for a
future non-pointer blockage, and record the constraint doc reference in the same
commit if anything is ever added.

Usage:
  check_abi_exports.py <artifact> [<artifact>...]
  check_abi_exports.py core/build-output/lib/libdopewars.a --nm nm
  check_abi_exports.py --strict <artifact>   # require the full 56, post-upgrade
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from abi_symbols import (  # noqa: E402
    HEADER,
    ctypes_prototype,
    declared_symbols,
    parse_declarations,
)

# Declarations blocked for a reason other than a pointer in the signature. Each
# entry must name the constraint that blocks it, in
# docs/mojo-1.1.0-abi-constraints.md, in the same commit. Empty: dw_world_size,
# the last entry, became exportable via size_of[World]().
NON_POINTER_BLOCKED: frozenset[str] = frozenset()


def blocked_declarations(header_text: str) -> set[str]:
    """Declarations Mojo 1.1.0 `@export` cannot express, derived from the header.

    The criterion is the one the exporter itself hits: any pointer in the
    signature, in a parameter or the return type. `ctypes_prototype` is used
    rather than a bespoke scan so this and the conformance harness agree on what
    "takes a pointer" means -- including array parameters, which decay to
    pointers in C and are out-pointers in this ABI.

    Raises if a scalar type has no ctypes mapping, so an unrecognised type can
    never be silently classified as unblocked.
    """
    blocked: set[str] = set()
    for decl in parse_declarations(header_text):
        restype, argtypes = ctypes_prototype(decl)
        if restype == "c_void_p" or "c_void_p" in argtypes:
            blocked.add(decl.name)
    return blocked | set(NON_POINTER_BLOCKED)


# Global + defined. `nm -g --defined-only` already filters to these, but the
# type is checked anyway so a stray absolute/weak-undefined cannot slip in if a
# future nm changes --defined-only semantics.
_DEFINED_TYPES = set("TDBRWPViI")
_WEAK_TYPES = set("WVwv")


def global_defined_symbols(artifact: Path, nm: str) -> set[str]:
    """Global defined symbol names in `artifact`, via `nm`.

    Works for both .o/.a (archive members) and .so (dynamic symbols), because
    `--defined-only -g` is meaningful for all three.
    """
    # -g/--defined-only rather than the long forms: GNU nm on some distros (and
    # llvm-nm) do not accept `--globals`.
    cmd = [nm, "-g", "--defined-only", str(artifact)]
    try:
        proc = subprocess.run(  # noqa: S603
            cmd, capture_output=True, text=True, check=False, timeout=120
        )
    except FileNotFoundError:
        raise SystemExit(f"{nm}: not found (pass --nm)") from None
    except subprocess.TimeoutExpired:
        raise SystemExit(f"{nm} timed out on {artifact}") from None

    if proc.returncode != 0 and not proc.stdout:
        raise SystemExit(f"{nm} failed on {artifact}: {proc.stderr.strip()}")

    names: set[str] = set()
    for line in proc.stdout.splitlines():
        # Archive members are prefixed `member.o:`; strip that first.
        if line.endswith(":"):
            continue
        line = line.split(":", 1)[-1] if re.match(r"^\S+\.o[a-z]?:", line) else line
        parts = line.split()
        if len(parts) < 2:
            continue
        sym_type, name = (
            (parts[0], parts[1]) if len(parts) == 2 else (parts[1], parts[2])
        )
        if sym_type in _DEFINED_TYPES and sym_type not in _WEAK_TYPES:
            # Mach-O prefixes C symbols with an underscore; ELF does not. The
            # header's names are the contract, so normalize artifact symbols to
            # that spelling before comparing.
            names.add(name[1:] if name.startswith("_") else name)
    return names


def check(
    artifact: Path,
    nm: str,
    declared: set[str],
    allow_extra: set[str] | None = None,
    blocked: set[str] | None = None,
) -> tuple[set[str], set[str], set[str]]:
    """`(leaked, unexpected_missing, expected_blocked_missing)` for one artifact.

    `blocked` is subtracted from the missing set only in non-strict mode; the
    caller decides whether the toolchain's limitation is being held against the
    build.
    """
    exported = global_defined_symbols(artifact, nm)
    allowed = declared | (allow_extra or set())
    leaked = {s for s in exported if s not in allowed}
    missing = {s for s in declared if s not in exported}
    expected = missing & (blocked or set())
    return leaked, missing - expected, expected


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact", type=Path, nargs="+")
    parser.add_argument("--header", type=Path, default=HEADER)
    parser.add_argument("--nm", default="nm")
    parser.add_argument(
        "--allow-extra",
        action="append",
        default=[],
        metavar="GLOB",
        help="symbol name (or prefix ending in *) allowed to be exported "
        "without a header declaration; repeatable",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="require every declaration, including the ones Mojo 1.1.0 cannot "
        "export. Use once the toolchain supports pointer parameters; until then "
        "the default holds the blocked surface as an expected absence.",
    )
    ns = parser.parse_args()

    header_text = ns.header.read_text(encoding="utf-8")
    declared = set(declared_symbols(header_text))
    blocked = set() if ns.strict else blocked_declarations(header_text)
    # Every build of this project also produces dw_abi_version from the stub
    # exporter; it is a declaration in the header, so nothing to add by default.
    allow_extra: set[str] = set()
    for pattern in ns.allow_extra:
        if pattern.endswith("*"):
            allow_extra |= {s for s in declared if s.startswith(pattern[:-1])}
        else:
            allow_extra.add(pattern)

    if not declared:
        print(
            f"{ns.header}: parsed zero declarations — header parse is broken",
            file=sys.stderr,
        )
        return 1

    failed = False
    for artifact in ns.artifact:
        if not artifact.exists():
            print(f"{artifact}: no such file", file=sys.stderr)
            failed = True
            continue
        leaked, missing, expected_blocked = check(
            artifact, ns.nm, declared, allow_extra, blocked
        )
        if leaked or missing:
            failed = True
            print(
                f"{artifact}: export surface does not match {ns.header}",
                file=sys.stderr,
            )
            for name in sorted(leaked):
                print(f"  leaked (exported, not declared): {name}", file=sys.stderr)
            for name in sorted(missing):
                print(f"  missing (declared, not exported): {name}", file=sys.stderr)
        exported_count = len(declared) - len(missing) - len(expected_blocked)
        status = "OK" if not (leaked or missing) else "FAIL"
        print(
            f"{status} {artifact}: {exported_count}/{len(declared)} declared dw_* exported, "
            f"{len(expected_blocked)} blocked on the toolchain, {len(leaked)} leaked"
        )

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
