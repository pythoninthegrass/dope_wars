# core/src/dopewars.mojo — Mojo simulation core, stub stage (TASK-001.03).
#
# At this stage the ABI declared in include/dopewars.h is unimplemented
# except for a single placeholder symbol: dw_abi_version(). Its only job
# is to prove the four-layer build+load pipeline (Mojo -> static lib
# -> C++ GDExtension -> Godot) works end-to-end. Real game logic lands
# in TASK-001.04.
#
# DW_ABI_VERSION must match include/dopewars.h's #define exactly.


@export("dw_abi_version")
def dw_abi_version() abi("C") -> UInt32:
    return 1
