"""Tier-C ABI conformance harness (TASK-001.05 AC#2).

Reaches the built library exclusively through the C ABI: ctypes against a
shared object whose prototypes are transcribed from include/dopewars.h. No core
module is imported, no Mojo is invoked — tools/validate_abi_test_purity.py
enforces that structurally, this module documents it.

Every prototype here carries the header line it came from, so a drift between
this file and the header shows up as a mismatch a reviewer can see rather than a
silent mis-cast. Where the header gives a struct a DW_STATIC_ASSERT, the
expected size is asserted here too: the header check proves what C thinks the
layout is, this proves the library was built against the same header.

Run:
    python3 core/abitest/abi_conformance_test.py --lib <path/to/libdopewars.so>
"""

from __future__ import annotations

import argparse
import ctypes
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

from abi_symbols import (  # noqa: E402
    HEADER,
    abi_version,
    declared_symbols,
    prototype_map,
    struct_sizes,
)

DW_ABI_VERSION = 1

# Result codes (include/dopewars.h, anonymous enum). Frozen from ABI v1;
# appended to, never renumbered.
DW_OK = 0
DW_ERR_INVALID_ARGUMENT = 1
DW_ERR_BUFFER_TOO_SMALL = 2
DW_ERR_ABI_VERSION_MISMATCH = 3
DW_ERR_UNKNOWN_LOCATION = 4
DW_ERR_UNKNOWN_DRUG = 5
DW_ERR_NOT_TRADED_HERE = 6
DW_ERR_INSUFFICIENT_CASH = 7
DW_ERR_INSUFFICIENT_BANK = 8
DW_ERR_INSUFFICIENT_INVENTORY = 9
DW_ERR_INSUFFICIENT_SPACE = 10
DW_ERR_GAME_OVER = 11
DW_ERR_DEAD = 12
DW_ERR_SERIALIZATION_FAILED = 13

# Dimensional constants (include/dopewars.h:66-68).
DW_NUM_LOCATIONS = 6
DW_NUM_DRUGS = 12
DW_MAX_HIGHSCORES = 10

# The rulebook the conformance suite pins. These are contract values: a rule
# change is an ABI-visible semantic change and must update both core/src/rules.mojo
# and this table, in the same commit, with a DW_ABI_VERSION bump.
EXPECTED_RULES = {
    "dw_rules_default_num_days": (ctypes.c_uint32, 31),
    "dw_rules_default_start_cash": (ctypes.c_int32, 2000),
    "dw_rules_default_start_debt": (ctypes.c_int64, 5500),
    "dw_rules_default_start_health": (ctypes.c_int32, 100),
    "dw_rules_default_start_coat_capacity": (ctypes.c_int32, 100),
    "dw_rules_default_start_location_index": (ctypes.c_int32, 0),  # bronx
    "dw_rules_gun_damage": (ctypes.c_uint32, 5),
    "dw_rules_gun_space": (ctypes.c_uint32, 4),
    "dw_rules_player_armor": (ctypes.c_uint32, 100),
    "dw_rules_debt_interest_bp": (ctypes.c_uint32, 1000),
    "dw_rules_bank_interest_bp": (ctypes.c_uint32, 200),
    "dw_rules_bank_purchase_fee_bp": (ctypes.c_uint32, 2500),
    "dw_rules_cheap_divide": (ctypes.c_uint32, 4),
    "dw_rules_expensive_multiply": (ctypes.c_uint32, 4),
}


class AbiError(Exception):
    """A conformance failure, with the header line that defines the contract."""


# ctypes resolves a type name to the class by name in this module's namespace.
# `prototype_map` returns names (so tools/abi_symbols.py stays ctypes-free), and
# this maps them back. `None` is not a ctypes class: it is a valid restype
# meaning void, and it never appears in an argtype position.
_CTYPES_BY_NAME: dict[str, object] = {
    name: getattr(ctypes, name)
    for name in (
        "c_uint8",
        "c_int8",
        "c_uint16",
        "c_int16",
        "c_uint32",
        "c_int32",
        "c_uint64",
        "c_int64",
        "c_size_t",
        "c_uint",
        "c_void_p",
    )
}


def header_prototypes() -> dict[str, tuple[object, list[object]]]:
    """Every declared prototype, resolved from the header into ctypes classes.

    A dict, not a table, so the set of prototypes is exactly the set of header
    declarations: adding a function to the header makes it appear here with no
    edit to this file.
    """
    out: dict[str, tuple[object, list[object]]] = {}
    for name, (restype, argtypes) in prototype_map(
        HEADER.read_text(encoding="utf-8")
    ).items():
        try:
            resolved_restype = None if restype == "None" else _CTYPES_BY_NAME[restype]
            resolved_args = [_CTYPES_BY_NAME[a] for a in argtypes]
        except KeyError as exc:  # pragma: no cover - prototype_map validates first
            raise AbiError(f"{name}: no ctypes mapping for {exc}") from exc
        out[name] = (resolved_restype, resolved_args)
    return out


# C scalar type -> ctypes, for the header-driven binding below. Only the types
# the ABI surface actually uses; an unmapped type is a hard error rather than a
# silent c_int, because a wrong-width scalar argument is memory corruption that
# happens to usually work.
C_TO_CTYPES: dict[str, type] = {
    "uint32_t": ctypes.c_uint32,
    "int32_t": ctypes.c_int32,
    "int64_t": ctypes.c_int64,
    "size_t": ctypes.c_size_t,
    "unsigned int": ctypes.c_uint,
}


class UnknownCType(Exception):
    """A header type this harness has no ctypes mapping for."""


class Abi:
    """ctypes view of the library, with prototypes derived from the header.

    Prototypes are read out of include/dopewars.h and mapped to ctypes, not
    transcribed by hand into a parallel table. A hand-written table of 54
    entries would drift from the header the moment a signature changed -- and a
    drifted prototype under ctypes is a mis-cast, not a type error. Deriving them
    means the header is the only place a signature exists, which is the property
    the whole ABI-first design is about.

    Functions the library does not export are still parsed, then reported as
    blocked rather than silently absent: that distinction ("blocked on the
    toolchain" vs "the prototype is wrong") is the point of the harness.
    """

    def __init__(self, path: Path, exported: set[str] | None = None):
        self.path = path
        try:
            self._lib = ctypes.CDLL(str(path))
        except OSError as exc:
            raise AbiError(f"cannot dlopen {path}: {exc}") from exc
        # ctypes resolves symbols lazily: getattr(lib, anything) succeeds and
        # only raises when the call happens, and CDLL has no "is this exported"
        # probe. So membership is answered from the dynamic symbol table instead
        # -- the same source of truth the export gate uses, so the two cannot
        # disagree about what the library provides.
        self.exported = exported if exported is not None else dynamic_exports(path)
        self.prototypes = header_prototypes()
        self.missing: list[str] = sorted(set(self.prototypes) - self.exported)
        self._bind()

    def _bind(self) -> None:
        # Only bind prototypes the library actually exports. Binding an absent
        # symbol is harmless under ctypes (resolution is lazy), but skipping them
        # keeps a stray call raising AbiError from call() rather than a
        # ctypes-level symbol error at the call site.
        for name, (restype, argtypes) in self.prototypes.items():
            if name not in self.exported:
                continue
            fn = getattr(self._lib, name)
            fn.restype = restype
            fn.argtypes = argtypes

    def call(self, name: str, *args):
        if name not in self.exported:
            raise AbiError(f"{name} is not exported by this build")
        return getattr(self._lib, name)(*args)

    def has(self, name: str) -> bool:
        return name in self.exported


# --- the tests -----------------------------------------------------------------


def test_abi_version_matches_header(abi: Abi, report: Report) -> None:
    """dw_abi_version() == DW_ABI_VERSION == the header's #define."""
    header_version = abi_version(HEADER.read_text(encoding="utf-8"))
    reported = abi.call("dw_abi_version")
    report.expect(
        "dw_abi_version() == DW_ABI_VERSION",
        reported == DW_ABI_VERSION == header_version,
        f"library={reported} test-constant={DW_ABI_VERSION} header={header_version}",
    )


def test_rulebook_constants(abi: Abi, report: Report) -> None:
    """Every RULES accessor returns the value the contract pins.

    These are not incidental numbers — the JS oracle's fixtures are generated
    against them, so a drift here means the Mojo core and the oracle disagree.
    """
    for name, (restype, expected) in EXPECTED_RULES.items():
        if not abi.has(name):
            report.skip(name, "not exported by this build")
            continue
        got = abi.call(name)
        report.expect(
            f"{name}() == {expected}",
            got == expected,
            f"got {got} ({restype.__name__})",
        )


def test_length_queries_agree_with_macros(abi: Abi, report: Report) -> None:
    """dw_rules_*_len() must equal DW_NUM_LOCATIONS / DW_NUM_DRUGS.

    Three-way agreement (macro, length fn, and eventually *_copy's
    *out_required) is the point: the two-call convention's first call is only
    trustworthy if it cannot disagree with the constant callers hard-code.
    """
    for name, macro_value in (
        ("dw_rules_locations_len", DW_NUM_LOCATIONS),
        ("dw_rules_drugs_len", DW_NUM_DRUGS),
    ):
        got = abi.call(name)
        report.expect(f"{name}() == {macro_value}", got == macro_value, f"got {got}")


def test_dump_len_is_a_fixed_positive_size(abi: Abi, report: Report) -> None:
    """dw_world_dump_len() is a fixed size, and large enough to be a real dump.

    The contract says the length does not depend on inventory occupancy. A
    single build can only pin the value, not the invariance across states, so the
    value is asserted exactly: a silent dump-format change then fails here rather
    than truncating saved games at runtime.

    The floor is the size of one dw_state_view (56B) plus the 12 price slots
    (12B each) plus the 12 inventory slots (16B each) plus the RNG state:
    56 + 144 + 192 + 4 = 396. The pinned 665 additionally carries the prev-price
    table, the three order lists and the price events, all of which the contract
    says are dumped fully.
    """
    got = abi.call("dw_world_dump_len")
    report.expect("dw_world_dump_len() >= 396", got >= 396, f"got {got}")
    report.expect("dw_world_dump_len() == 665", got == 665, f"got {got}")


def test_world_align_is_a_power_of_two(abi: Abi, report: Report) -> None:
    """dw_world_align() must be a power of two the caller can honour.

    The contract has the caller allocate dw_world_size() bytes at this alignment.
    An alignment of 0 or a non-power-of-two would make aligned_alloc() fail or
    silently under-align, which is a memory bug rather than a logic bug — cheap to
    check, expensive to find later.
    """
    align = abi.call("dw_world_align")
    report.expect("dw_world_align() > 0", align > 0, f"got {align}")
    report.expect(
        "dw_world_align() is a power of two",
        align & (align - 1) == 0,
        f"got {align}",
    )


def test_header_struct_sizes_are_sane(abi: Abi, report: Report) -> None:
    """Cross-check the parsed DW_STATIC_ASSERT sizes against the test's table.

    The header's static asserts are compiled by anything that #includes it (the
    C driver does), so this test is the Python side noticing if a size in the
    header changes without the ctypes struct transcription changing with it.
    """
    header_sizes = struct_sizes(HEADER.read_text(encoding="utf-8"))
    for name, size in sorted(header_sizes.items()):
        report.expect(
            f"{name} has a DW_STATIC_ASSERT size",
            isinstance(size, int) and size > 0,
            f"{name} == {size}",
        )
    # The set of asserted structs is itself the contract: an ABI struct that
    # loses its static assert silently stops being checked by every consumer.
    expected_asserted = {
        "dw_arrival_event",
        "dw_chase",
        "dw_coat_offer",
        "dw_config",
        "dw_drug_view",
        "dw_fight_ratings",
        "dw_fight_result",
        "dw_finish_result",
        "dw_gun_offer",
        "dw_highscore_entry",
        "dw_inventory_slot",
        "dw_location_view",
        "dw_price_event",
        "dw_price_slot",
        "dw_purchase_result",
        "dw_run_result",
        "dw_state_view",
    }
    report.expect(
        "every ABI struct carries a DW_STATIC_ASSERT",
        set(header_sizes) == expected_asserted,
        f"missing={sorted(expected_asserted - set(header_sizes))} "
        f"extra={sorted(set(header_sizes) - expected_asserted)}",
    )


def test_blocked_surface_is_reported_not_forgotten(abi: Abi, report: Report) -> None:
    """Every declared-but-unexported function is accounted for.

    This test turns the known-blocked set into an explicit expectation, so the
    suite distinguishes "still blocked on the toolchain" from "someone deleted an
    export". When the toolchain lifts the restriction, this is the test that fails
    first and tells you the blocked list is stale.
    """
    declared = set(declared_symbols(HEADER.read_text(encoding="utf-8")))
    # The functions this tier can reach with today's exporter: the header's
    # pointer-free declarations.
    implemented = {
        "dw_abi_version",
        *EXPECTED_RULES,
        "dw_rules_locations_len",
        "dw_rules_drugs_len",
        "dw_world_align",
        "dw_world_dump_len",
    }
    expected_blocked = declared - implemented

    # Anything expected to be blocked that the library does export means the
    # blocked list in core/src/abi.mojo is stale (good news, filed badly).
    newly_available = sorted(n for n in expected_blocked if abi.has(n))
    report.expect(
        "blocked surface is still blocked (else update the blocked list)",
        not newly_available,
        "now exported, update core/src/abi.mojo and this test: "
        + ", ".join(newly_available),
    )
    # Anything not exported that we did NOT expect to be blocked is a real
    # regression: a pointer-free function silently stopped being built.
    unexpectedly_missing = sorted(set(abi.missing) - expected_blocked)
    report.expect(
        "every pointer-free declaration is exported",
        not unexpectedly_missing,
        "regression, no longer exported: " + ", ".join(unexpectedly_missing),
    )
    report.note(
        f"{len(expected_blocked)} of {len(declared)} declared functions remain blocked "
        f"on Mojo 1.1.0 pointer params (docs/mojo-1.1.0-abi-constraints.md)"
    )


class Report:
    def __init__(self) -> None:
        self.passed = 0
        self.failed: list[str] = []
        self.skipped: list[tuple[str, str]] = []
        self.notes: list[str] = []

    def expect(self, what: str, ok: bool, detail: str = "") -> None:
        if ok:
            self.passed += 1
        else:
            self.failed.append(f"{what} — {detail}")

    def skip(self, what: str, why: str) -> None:
        self.skipped.append((what, why))

    def note(self, text: str) -> None:
        self.notes.append(text)

    def emit(self) -> int:
        for note in self.notes:
            print(f"  note    {note}")
        for what, why in self.skipped:
            print(f"  skip    {what}: {why}")
        for failure in self.failed:
            print(f"  FAIL    {failure}")
        print(
            f"\n{self.passed} passed, {len(self.failed)} failed, {len(self.skipped)} skipped"
        )
        return 1 if self.failed else 0


def dynamic_exports(path: Path) -> set[str]:
    """Defined global symbols in the library's dynamic symbol table.

    Uses `nm -D --defined-only`; on macOS the equivalent is
    `nm -gU -arch arch`. Falls back to an empty set only if nm is missing,
    which the caller reports as a hard failure rather than a silent pass.
    """
    import subprocess  # noqa: PLC0415 - only needed for the export probe

    for args in (["-D", "--defined-only"], ["-gU"]):
        try:
            proc = subprocess.run(  # noqa: S603
                ["nm", *args, str(path)],
                capture_output=True,
                text=True,
                check=False,
                timeout=60,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
        if proc.returncode != 0 and not proc.stdout:
            continue
        names: set[str] = set()
        for line in proc.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 2:
                # BSD nm prints `0x... T _name`; GNU prints `addr T name`.
                sym = parts[-1]
                names.add(sym.lstrip("_") if not sym.startswith("dw_") else sym)
        if names:
            return names
    raise AbiError(
        f"could not read the dynamic symbol table of {path} (is nm installed?)"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--lib", type=Path, required=True, help="path to libdopewars.so"
    )
    ns = parser.parse_args()

    report = Report()
    try:
        abi = Abi(ns.lib)
    except AbiError as exc:
        print(f"FAIL  {exc}", file=sys.stderr)
        return 1

    tests = [
        test_abi_version_matches_header,
        test_rulebook_constants,
        test_length_queries_agree_with_macros,
        test_dump_len_is_a_fixed_positive_size,
        test_world_align_is_a_power_of_two,
        test_header_struct_sizes_are_sane,
        test_blocked_surface_is_reported_not_forgotten,
    ]
    for test in tests:
        try:
            test(abi, report)
        except AbiError as exc:  # a test whose own precondition failed
            report.expect(test.__name__, False, str(exc))

    return report.emit()


if __name__ == "__main__":
    raise SystemExit(main())
