"""Generates game/bridge_expectations.gd from include/dopewars.h (TASK-001.05 AC#4).

Why generated: the bridge test's whole claim is that GDScript sees the values the
Mojo core actually computes. If its expected values were written by hand, the
test would compare the bridge against someone's memory of the rules and pass on
a bridge that returned the wrong numbers, as long as those numbers were
misremembered consistently. Generating them from the header keeps the header as
the contract; generating them from the library under test would make the test
vacuous, so the source here is the header's *declarations* plus the contract
values documented alongside them.

Two kinds of expectation come out of this:

  * the method-name list, which is the ABI surface minus the dw_rules_ prefix,
    so a method that silently disappears from the shim is caught, and
  * the pinned rulebook values, which the conformance suite pins identically.

Run via task gen:bridge-expectations; task bridge:test runs the staleness check
first, so the file cannot drift from the header unnoticed.
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "tools"))

from abi_symbols import HEADER, macro_ints, parse_declarations  # noqa: E402

OUT = REPO_ROOT / "game" / "bridge_expectations.gd"

# ABI function -> expected value, per the rules frozen in include/dopewars.h and
# mirrored by core/src/rules.mojo and the JS oracle fixtures. Keeping the same
# table in three places is deliberate: it is the ABI's definition of "v1", and an
# update that only lands in one of the three is exactly the drift being guarded.
PINNED: dict[str, int] = {
    "dw_rules_default_num_days": 31,
    "dw_rules_default_start_cash": 2000,
    "dw_rules_default_start_debt": 5500,
    "dw_rules_default_start_health": 100,
    "dw_rules_default_start_coat_capacity": 100,
    "dw_rules_default_start_location_index": 0,
    "dw_rules_debt_interest_bp": 1000,
    "dw_rules_bank_interest_bp": 500,
    "dw_rules_cheap_divide": 10,
    "dw_rules_expensive_multiply": 5,
}

# ABI length query -> the header macro that defines its value. Read from the
# header at generation time rather than restated here, so DW_NUM_DRUGS is defined
# in exactly one place: a change to the macro moves the bridge expectation with it
# and a bridge that still returns the old length fails.
LENGTH_FROM_MACRO: dict[str, str] = {
    "dw_rules_locations_len": "DW_NUM_LOCATIONS",
    "dw_rules_drugs_len": "DW_NUM_DRUGS",
}

# ABI function -> the C return type class the bridge must preserve. "uint32"
# means GDScript must see a non-negative value that would have been re-signed by
# a lossy hop; "int64" means the value can exceed 32 bits.
WIDTH_CLASS: dict[str, str] = {
    "uint32_t": "uint32",
    "int32_t": "int32",
    "int64_t": "int64",
    "size_t": "size",
}

# ABI functions the shim does not forward, with the reason.
#
# Currently empty. dw_world_size was listed here while Mojo 1.1.0's `@export`
# was believed to make it unreachable; core/src/abi.mojo exports it via
# size_of[World]() over the OptionalPointer/UntrackedOrigin spelling, so the
# shim forwards it and the surface check requires it. Keep this dict as the
# stated-gap mechanism: anything listed must also be absent from the library,
# and adding a function here without removing the shim method fails the
# surface check.
NOT_FORWARDED: dict[str, str] = {}

# ABI function -> the GDScript method name the shim binds.
#
# Written out rather than derived by a prefix rule, for two reasons. First, the
# rule is not uniform in the way a derived name pretends: the shim drops `dw_`
# from dw_abi_version and dw_world_* but keeps `rules_` on the rulebook
# accessors, because a GDScript reader wants `world.rules_cheap_divide()`, not
# `world.cheap_divide()` — the prefix says where the number comes from once it is
# sitting next to methods from other subsystems. A single strip rule would encode
# the opposite choice.
#
# Second, and more importantly, this table is the *expected* side of a comparison
# against what the extension actually binds. Deriving it with a rule the shim also
# follows would let a shared misunderstanding pass; spelling it out means the test
# fails if either side renames.
GD_NAMES: dict[str, str] = {
    "dw_abi_version": "abi_version",
    "dw_rules_default_num_days": "rules_default_num_days",
    "dw_rules_default_start_cash": "rules_default_start_cash",
    "dw_rules_default_start_debt": "rules_default_start_debt",
    "dw_rules_default_start_health": "rules_default_start_health",
    "dw_rules_default_start_coat_capacity": "rules_default_start_coat_capacity",
    "dw_rules_default_start_location_index": "rules_default_start_location_index",
    "dw_rules_debt_interest_bp": "rules_debt_interest_bp",
    "dw_rules_bank_interest_bp": "rules_bank_interest_bp",
    "dw_rules_cheap_divide": "rules_cheap_divide",
    "dw_rules_expensive_multiply": "rules_expensive_multiply",
    "dw_rules_locations_len": "rules_locations_len",
    "dw_rules_drugs_len": "rules_drugs_len",
    "dw_world_size": "world_size",
    "dw_world_align": "world_align",
    "dw_world_dump_len": "world_dump_len",
}


def gd_name(abi_fn: str) -> str:
    """The GDScript method name the shim binds for one ABI function.

    Raises rather than guessing: a declaration with no entry here has no shim
    method, which the generator reports by skipping it only when it is also in
    NOT_FORWARDED. Anything else is a hole in GD_NAMES and must be a hard error,
    or a new ABI function would silently become untested at the bridge.
    """
    if abi_fn not in GD_NAMES:
        msg = f"{abi_fn}: no GD_NAMES entry; add the shim method name or list it in NOT_FORWARDED"
        raise SystemExit(msg)
    return GD_NAMES[abi_fn]


def render() -> str:
    text = HEADER.read_text(encoding="utf-8")
    all_decls = parse_declarations(text)
    declared = {d.name for d in all_decls}
    decls = [
        d for d in all_decls if not d.takes_pointer and d.name not in NOT_FORWARDED
    ]
    names = {d.name for d in decls}
    # A GD_NAMES entry whose ABI function has no header declaration is stale: the
    # header dropped the function, but the entry would keep the shim method
    # looking sanctioned and the bridge test asserting a name nothing backs.
    stale = sorted(set(GD_NAMES) - declared)
    if stale:
        msg = f"GD_NAMES entries with no header declaration: {stale}"
        raise SystemExit(msg)
    missing_pinned = sorted(set(PINNED) - names)
    if missing_pinned:
        msg = f"pinned rulebook entries with no header declaration: {missing_pinned}"
        raise SystemExit(msg)

    width_of = {d.name: WIDTH_CLASS.get(d.return_type, "?") for d in decls}
    # Length queries take their expected value from the header macro rather than
    # from a number restated here, so DW_NUM_LOCATIONS/DW_NUM_DRUGS have exactly
    # one definition. A macro that is not present is an error, not a silently
    # missing expectation.
    macros = macro_ints(text)
    pinned = dict(PINNED)
    for abi_fn, macro_name in LENGTH_FROM_MACRO.items():
        if macro_name not in macros:
            msg = f"{macro_name} not found in {HEADER}, but {abi_fn} is expected to report it"
            raise SystemExit(msg)
        pinned[abi_fn] = macros[macro_name]
    # dw_abi_version is uint32 by declaration; the size_t pair report as "size".
    lines: list[str] = []
    lines.append("# GENERATED by tools/gen_bridge_expectations.py — do not edit.")
    lines.append("#")
    lines.append(
        "# Expected bridge surface, derived from include/dopewars.h. Regenerate with"
    )
    lines.append("#   task gen:bridge-expectations")
    lines.append(
        "# and note that task bridge:test fails if this file is stale with respect to"
    )
    lines.append(
        "# the header, so an edit here without a header change is caught, and a header"
    )
    lines.append("# change without a regeneration is caught too.")
    lines.append("")
    lines.append("class_name BridgeExpectations")
    lines.append("")
    lines.append("## Every pointer-free ABI declaration the shim forwards, as the")
    lines.append(
        "## GDScript-side method name plus the value the ABI contract pins for it."
    )
    lines.append(
        "## Only pointer-free no-argument functions appear here because this table"
    )
    lines.append(
        "## drives value and width-fidelity checks via a zero-arg call. The"
    )
    lines.append(
        "## pointer-argument side of the ABI is forwarded by the shim and covered"
    )
    lines.append(
        "## behaviourally by res://tests/test_bridge.gd and the Tier-C suites."
    )
    for abi_fn, why in sorted(NOT_FORWARDED.items()):
        lines.append(f"## Not forwarded: {abi_fn} — {why}")
    lines.append("")
    lines.append('# method name -> { "value": pinned value, "c_type": C return type,')
    lines.append(
        '#                          "width": "uint32" | "int32" | "int64" | "size" }'
    )
    lines.append("#")
    lines.append("# Untyped on purpose: Godot 4.7 rejects a nested typed collection")
    lines.append(
        "# (Dictionary[String, Dictionary[...]]) as a const type, and the shape is"
    )
    lines.append(
        "# validated by the test at load time, so a malformed table is a test failure"
    )
    lines.append("# rather than a script parse error.")
    lines.append("const ABI = {")
    for d in decls:
        entry = "{"
        if d.name in pinned:
            entry += f'"value": {pinned[d.name]}, '
        entry += f'"c_type": "{d.return_type}", "width": "{width_of[d.name]}"}}'
        lines.append(f'\t"{gd_name(d.name)}": {entry},')
    lines.append("}")
    lines.append("")
    # Read from the header's #define (spelled `1u`, hence the suffix strip) so
    # the bridge's expected identity is the header's, not a copy that survives a
    # version bump by being forgotten.
    abi_version = macros.get("DW_ABI_VERSION")
    if abi_version is None:
        raise SystemExit(f"DW_ABI_VERSION not found in {HEADER}")
    lines.append(
        "# ABI identity, read from the header's DW_ABI_VERSION #define. Not a copy:"
    )
    lines.append(
        "# a bump to the header moves this, and a shim still reporting the old value"
    )
    lines.append("# fails the bridge test.")
    lines.append(f"const DW_ABI_VERSION: int = {abi_version}")
    lines.append("")
    return "\n".join(lines) + "\n"


def main() -> int:
    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != render():
            print(
                f"{OUT}: stale with respect to {HEADER}\n"
                "  run: task gen:bridge-expectations",
                file=sys.stderr,
            )
            return 1
        return 0
    OUT.write_text(render(), encoding="utf-8")
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
