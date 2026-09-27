---
id: TASK-001.05
title: Implement ABI conformance and bridge integration tests
status: Done
assignee:
  - '@pi'
created_date: '2026-09-26 04:34'
updated_date: '2026-09-27 22:15'
labels:
  - mojo
  - ffi
  - parity
  - testing
milestone: m-2
dependencies:
  - TASK-001.03
  - TASK-001.04
references:
  - ~/git/jumpnbump/core/abitest.zig
  - ~/git/jumpnbump/core/abi.zig
  - ~/git/jumpnbump/tools/validate_abi_test_purity.py
  - ~/git/jumpnbump/tools/validate_abi_exporter.py
documentation:
  - include/dopewars.h
parent_task_id: TASK-001
priority: high
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement `core/abi.mojo` as the sole ABI exporter (following the single-exporter discipline from `~/git/jumpnbump/core/abi.zig`), then write two test tiers:

1. **ABI conformance tests** (`core/abitest/`) — exercise the compiled library only through `include/dopewars.h` via C-import or ctypes, never by calling Mojo directly. Test: world lifecycle, every result code, two-call buffer contracts, struct size assertions, step/pump determinism, and serialization round-trips. Mirror `~/git/jumpnbump/core/abitest.zig`.

2. **Bridge integration tests** — exercise the full Godot → C++ GDExtension → Mojo path for world lifecycle, a game step sequence, and serialize/deserialize. These run headlessly against the extension `.so`.

Also add:

- Export surface gate: `tools/validate_abi_exporter.py` fails if any symbol outside `core/abi.mojo` exports a `dopewars_` symbol
- `tools/validate_abi_test_purity.py` fails if any conformance test directly imports a Mojo core module

Cross-reference `~/git/jumpnbump/core/abitest.zig` (notes on the jnb_world_dump two-call bug caught by this tier — anticipate similar edge cases here) and `~/git/jumpnbump/tools/`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 nm -g --defined-only on the built Mojo static lib shows only symbols matching the dopewars_ ABI prefix and nothing else

      Verified: `task core:build` runs check_abi_exports.py on the archive and reports
      `OK libdopewars.a: 19/54 declared dw_* exported, 35 blocked on the toolchain, 0 leaked`.
      `nm -g --defined-only core/build-output/lib/libdopewars.a` lists exactly 19 dw_* names
      and no third-party/runtime symbols. Mojo emits its runtime's symbols as globals, so
      taskfiles/core.yml demotes them with `objcopy --keep-global-symbols=<list generated
      from the header>`; the list is generated, so the gate cannot drift from the contract.

- [x] #2 ABI conformance tests reach the library exclusively through the C header (ctypes or equivalent C-import mechanism) and never call Mojo functions directly

      core/abitest/abi_conformance_test.py (41 assertions) loads the library with ctypes and
      derives every prototype from include/dopewars.h via tools/abi_symbols.py; core/abitest/
      abi_header_check.c is a C11 TU that #includes the header. No Mojo module is imported and
      the Mojo toolchain is never invoked. Verified to fail (not just skip) when the library
      returns a wrong value or is missing an export.

- [x] #3 A purity validator script (following ~/git/jumpnbump/tools/validate_abi_test_purity.py) fails if any conformance test imports Mojo core modules directly

      tools/validate_abi_test_purity.py, wired into `task abi:check`. Beyond the import rule it
      rejects driving the Mojo toolchain from a test, and requires the header to be a live input
      rather than a comment mention. Verified against three negative controls: `from rules import
      ...`, a `mojo run` subprocess, and a header referenced only in a docstring — all three fail.

- [x] #4 Integration tests exercise at least: world init/destroy, a full game step sequence, and a serialize/deserialize round-trip through the Godot->C++->Mojo call path

      Partially done, and the gap is the toolchain, not the harness. The bridge test exists and
      runs (game/godot_tests/bridge_test.gd, 20 assertions, `task bridge:test`), and it does the
      full Godot -> C++ -> C ABI -> Mojo trip for the 19 exported functions, checking each against
      expectations generated from the header. The three named behaviours all require a `dw_world *`:
      init/destroy takes a pointer, a game step takes a world plus out-pointers, and serialize takes
      a buffer pointer. None can be exported on Mojo 1.1.0, so none can be crossed yet.

- [x] #5 A CI gate fails if any non-ABI symbol is exposed in the built library

      tools/check_abi_exports.py, run inside `task core:build` (so it is unavoidable) and again on
      the conformance .so. The leak direction — an exported symbol with no header declaration — is
      an unconditional exit 1. The missing direction distinguishes toolchain-blocked from
      regression: blocked is derived from pointer-ness in the signature, so lifting the toolchain
      limit makes the newly-buildable functions *required*, and the list can only shrink by
      upgrade, never by editing a list to make a red build green. `--strict` demands all 54 today
      and is verified to fail, which is what keeps the leniency honest.
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
### What landed

- `core/src/abi.mojo` — sole `@export` source; 19 pointer-free `dw_*` functions
  (ABI identity, RULES constants, the two length queries, `dw_world_align`,
  `dw_world_dump_len`).
- `core/abitest/abi_conformance_test.py` — Tier-C, ctypes, 41 assertions.
- `core/abitest/abi_header_check.c` — compile-time proof that
  `include/dopewars.h` is self-consistent as C11.
- `game/godot_tests/bridge_test.gd` (+ scene) — bridge tier, 20 assertions.
- `game/bridge_expectations.gd` — generated; do not hand-edit.
- `tools/abi_symbols.py` (shared header parser), `validate_abi_exporter.py`,
  `validate_abi_test_purity.py`, `check_abi_exports.py`,
  `gen_bridge_expectations.py`.
- `docs/mojo-1.1.0-abi-constraints.md` — the probe log behind the blocked list.
- Task graph: `abi:check`, `abi:conformance`, `gen:bridge-expectations[:check]`,
  `bridge:test`, `core:abi:shared-lib`, `core:abi:header-check`; all wired into
  `task check`.

### Blocking constraint

Mojo 1.1.0 `@export` refuses any function with a `ref`/pointer parameter, and
there is no reachable `address -> Pointer` constructor or `sizeof` intrinsic, so
the opaque `dw_world` handle can neither be created nor measured across the C
seam. 35 of 54 declarations are unreachable, including every one AC#4 names. The
path forward is a toolchain upgrade past the version where `@export` accepts an
unbound `Pointer`; `check_abi_exports.py --strict` is already wired to fail until
they appear, so the lift is a build failure that must be actioned rather than a
forgotten TODO.

### Corrections worth keeping

- `dw_state_view.dead` is at offset **52**, not 48. The C header check caught
  this in my first draft; the size-only assertion in the header would not have.
- The GDExtension never linked the Mojo runtime. It linked fine and failed at
  `dlopen` with `undefined symbol: KGEN_CompilerRT_AlignedFree` — the TASK-001.03
  smoke test passed only because nothing it called reached the allocator.
- A conformance suite that runs zero assertions must fail, not pass. The first
  bridge test exited 0 while every check threw; it now has a floor derived from
  the surface size.
- `_DEFINE_RE` lacked `re.M`, so macro parsing silently returned `{}` and a
  length expectation quietly disappeared rather than failing loudly.

### Not done

(Superseded 2026-09-27: everything below landed via merge 0352fdb; see Final Summary and the correction section.)

- AC#4's three named behaviours (blocked as above).
- Two-call buffer contracts, result-code coverage, and serialization round-trips
  are asserted only for the pointer-free subset. The two-call machinery is in
  place and the harness distinguishes "blocked" from "wrong", but the pointer
  surface itself is untested until the toolchain moves.

### Correction to "Blocking constraint" (superseded, kept for the record)

The claim that no reachable spelling crosses the `dw_world *` seam was wrong.
`OptionalPointer[T, origin=MutUntrackedOrigin]` (params out) /
`ImmUntrackedOrigin` (params in) is accepted by `@export` on 1.1.0 because an
explicitly-bound untracked origin is not parametric; `size_of[T]()`/
`align_of[T]()` from `std.sys` provide the missing measurement intrinsics.
Full evidence and the working signatures: docs/mojo-1.1.0-abi-constraints.md
(2026-09-27 amendment).

## Comments

<!-- COMMENTS:BEGIN -->
created: 2026-09-27 21:28
---
Landed via PR #1 (squash f34aed4) from a gnhf unattended run (pi / aperture/qwen3.8-flash-next-iq4). ACs #1, #2, #3, #5 met and independently verified by review: task check rc=0, abitest 41/41, nm -g on libdopewars.a = 19 dw_* / 0 leaked, both validators fail planted violations, markdownlint rc=0.

AC#4 remains open: Mojo 1.1.0 @export refuses pointer-parameter functions and offers no address->Pointer constructor, so the dw_world * seam is unexportable and the stateful surface (init/step/dump-load) is unreachable. Probe log in docs/mojo-1.1.0-abi-constraints.md; three independent reviewer probes confirmed it. Follow-up task tracks the decision (toolchain bump vs ABI restructure). Task intentionally left In Progress until AC#4 closes.
---
<!-- COMMENTS:END -->
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
AC#4 closed via merge 0352fdb (local full-surface work reconciled with PR #1). All 54/54 `include/dopewars.h` declarations are now exported from `core/src/abi.mojo` on Mojo 1.1.0 — the TASK-001.08 'blocked' diagnosis was wrong: `@export` accepts `OptionalPointer[T, origin=MutUntrackedOrigin]` / `ImmUntrackedOrigin` (an explicitly-bound untracked origin is not parametric), and the header's NULL-rejection discipline maps onto the Optional wrapper. Probe doc amended: docs/mojo-1.1.0-abi-constraints.md 'The spelling that works'.

Bridge tier now covers AC#4 end-to-end through Godot -> C++ -> Mojo: `game/godot_tests/bridge_test.gd` (scene, 20 assertions) plus `game/tests/test_bridge.gd` (`--script` driver: lifecycle, buy/sell/travel/finances, dump->load->dump byte-identical round-trip, seed determinism), wired as `task bridge:test` and `task bridge:test:script`.

Conformance tier is three drivers: ctypes (`core/abitest/abi_conformance_test.py`, 40 assertions, dump length pinned at 766), std-only Mojo `external_call` driver (`core/abitest/abitest.mojo`, 23 assertions, task `core:abitest:mojo`), and the C11 header self-consistency check. The blocked-surface test now asserts all-declared-exported; `NON_POINTER_BLOCKED` is empty.

Cross-platform fixes in the same merge (this tree is macOS/Mach-O): objcopy-conditional strip, leading-underscore normalization in the export gate, `libKGENCompilerRTShared.{so,dylib}` glob, ld64 `-force_load` instead of `--whole-archive`.

Verified: `task check` exit 0 — 54/54 exports on .a and .so, 0 blocked, 0 leaked; parity 31 fixtures; ctypes 40; Mojo 23; header check; both bridge tiers; headless smoke. `task lint` exit 0.
<!-- SECTION:FINAL_SUMMARY:END -->
