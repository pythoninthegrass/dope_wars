# core/src/abi.mojo — the only file in core/ that declares @export symbols.
#
# Every game rule lives in a sibling module (rng, rules, world, prices,
# trade, travel, finances, events, dealers, combat, score, serialize) and is
# plain Mojo with no C ABI of its own. This file is the single seam where
# those functions are re-exported as `dw_*` symbols declared in
# include/dopewars.h. The imports below keep the whole core in the build;
# TASK-001.05 replaces each import with its dw_* wrapper.
#
# DW_ABI_VERSION must match include/dopewars.h's #define exactly.

@export("dw_abi_version")
def dw_abi_version() abi("C") -> UInt32:
    return 1
