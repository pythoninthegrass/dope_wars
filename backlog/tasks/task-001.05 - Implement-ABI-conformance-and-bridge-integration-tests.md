---
id: TASK-001.05
title: Implement ABI conformance and bridge integration tests
status: Done
assignee:
  - claude
created_date: '2026-09-26 04:34'
updated_date: '2026-09-26 07:56'
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
- [x] #2 ABI conformance tests reach the library exclusively through the C header (ctypes or equivalent C-import mechanism) and never call Mojo functions directly
- [x] #3 A purity validator script (following ~/git/jumpnbump/tools/validate_abi_test_purity.py) fails if any conformance test imports Mojo core modules directly
- [x] #4 Integration tests exercise at least: world init/destroy, a full game step sequence, and a serialize/deserialize round-trip through the Godot->C++->Mojo call path
- [x] #5 A CI gate fails if any non-ABI symbol is exposed in the built library
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Approved plan (Lance, 2026-09-26)

Decisions locked:
- **D1 = A**: refactor `World` to plain data (fixed `Array[T,N]` + count for the 3 order lists and the price-event list) so the ABI's caller-owned-storage / no-destroy contract holds. No `dw_world_destroy`.
- **D2 = yes**: conformance tests are Mojo `external_call` + `mojo build -Xlinker libdopewars.a` in `core/abitest/`, mirroring `abitest.zig` as closely as Mojo 1.1.0 allows (no `@cImport`). Structs declared with `comptime assert size_of[T]() == N` mirroring the header's `DW_STATIC_ASSERT`.
- **D3 = full shim**: `extension/` gets the complete 1:1 forwarding surface now.

### Phases

1. **World plain-data refactor** — `world.mojo` (order lists + price events → `Array` + count), `prices.mojo`, `events.mojo`, `serialize.mojo`, `tests/mojo/{harness,replay,prices_test}.mojo`. Gate: `task core:test` stays green.
2. **`core/src/abi.mojo`** — declare every ABI struct with size asserts; implement every `dw_*` in `include/dopewars.h`: lifecycle, state/prices/inventory copies (two-call), trade, travel, finances, arrival/dealer events, chase/combat, finish/highscore, dump/load, rules accessors, RNG, find_*. `result.Outcome` → `DW_*` mapping; NULL via `OptionalPointer`; placement-construct via `unsafe_write`.
3. **`core/abitest/`** — conformance suite (lifecycle, every result code, two-call contracts, struct sizes, determinism, serialization round-trip, rules/RNG) + `README.md`.
4. **`tools/`** — `validate_abi_exporter.py`, `validate_abi_test_purity.py`, `nm -g --defined-only` symbol gate.
5. **`extension/`** — full 1:1 shim (jumpnbump aligned-storage pattern), bound methods + constants.
6. **`game/tests/test_bridge.gd`** — headless SceneTree test: init → state → buy/sell/travel → dump/load round-trip → determinism.
7. **Taskfile + docs** — `core:abitest`, `game:bridge-test`, wire into `task check`/`task lint`; update `AGENTS.md`, `docs/abi-contract.md`, `tests/mojo/README.md`.

### Verification
`task check` (core:test + core:abitest + four-layer build + smoke + bridge) and `task lint` exit 0; `nm` gate clean.

### Out of scope
UI flows (001.06), CI workflow files, Windows/web.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC#1/#5 verified: `nm -g --defined-only core/build-output/lib/libdopewars.a` shows 52 `_dw_*` defined globals and 0 non-`dw_` defined globals. Enforced by `tools/validate_abi_symbols.py`, wired into `task lint`.

AC#2 verified: `core/abitest/abitest.mojo` imports only `std.ffi`, `std.memory`, `std.sys`, `std.testing`; every ABI call goes through `std.ffi.external_call` against the linked static lib.

AC#3 verified: `tools/validate_abi_test_purity.py` fails on a non-std import (negative-tested) and passes clean.

AC#4 verified: `game/tests/test_bridge.gd` covers init/reset, a buy/sell/travel/finances step sequence, and a dump->load->dump byte-identical round-trip through Godot -> C++ -> Mojo. Note on 'destroy': D1=A made `World` plain data, so there is no `dw_world_destroy`; teardown is the caller releasing its storage (the RefCounted shim frees it). `reset` covers re-initialization over existing storage.

D1=A required refactoring `World`'s four `List` fields to fixed `Array` + length fields, and adding a `start_cash` field so `dw_world_reset` can rebuild the same fresh game. The dump format became fixed-size (766 bytes) to satisfy `dw_world_dump_len()`'s fixed-length contract; `serialize.mojo` asserts the length at runtime.

Mojo runtime: the ABI's use of `List`/`Error` makes `libdopewars.a` reference `KGEN_CompilerRT_*`. `extension/SConstruct` links `libKGENCompilerRTShared.dylib` from `core/.venv` by absolute path and bakes it into the rpath (dev-build dependency; a distributable bundle would copy the dylib next to the framework).

Added `dw_abi_version()` to `include/dopewars.h` (additive, no version bump) so the shim's `abi_version()` and the TASK-001.03 smoke test keep working and a binding can assert the linked core's version at runtime.

NULL-pointer paths are not exercised in the conformance suite: Mojo 1.1.0 cannot construct a null `Pointer`, and mixing `Pointer`/`OptionalPointer` args for one `external_call` symbol is a signature conflict. The ABI's NULL guards are implemented and compile; the C++ shim never passes NULL. Documented in `core/abitest/README.md`.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Summary

Implemented the full `dw_*` C ABI in `core/src/abi.mojo`, the Tier-C conformance suite that reaches it only through `include/dopewars.h`, the Godot → C++ → Mojo bridge integration test, and the three gates that keep the ABI surface honest. `task check` and `task lint` both exit 0 from a clean state.

## What changed

**`core/src/abi.mojo` (the sole exporter, ~1150 lines)** — declares all 17 ABI structs with `comptime assert size_of[T]() == N` mirroring the header's `DW_STATIC_ASSERT`, and implements every function in `include/dopewars.h`: world lifecycle, state/prices/inventory copies (two-call), trade, travel, finances, arrival/dealer events, chase/combat, finish/high-score, dump/load, rules accessors, RNG, and id lookups. `result.Outcome` codes map to `DW_*`; the world is placement-constructed into caller storage via `unsafe_write`.

**`core/src/world.mojo` + `serialize.mojo` (D1=A)** — the four `List` fields became fixed `Array` + length fields, and a `start_cash` field was added so `dw_world_reset` can rebuild the same fresh game. The dump format is now fixed-size (766 bytes) to satisfy `dw_world_dump_len()`'s fixed-length contract; `dump()` asserts the length at runtime. `rng.mojo` gained free `mulberry32_draw`/`mulberry32_advance` helpers for the raw-u32 ABI surface.

**`core/abitest/abitest.mojo` (23 tests)** — reaches the linked static library exclusively through `std.ffi.external_call` (Mojo 1.1.0 has no `@cImport`). Covers struct layout, lifecycle, every result code, all six two-call buffer contracts, determinism, serialization round-trip, rules/RNG/lookups, and a game step sequence. `core/abitest/README.md` documents the tier and its one gap (NULL paths).

**`extension/src/dopewars_world.{hpp,cpp}`** — full 1:1 forwarding of the ABI to a `RefCounted` Godot class, with structured results as Dictionaries and all result/kind constants bound. `SConstruct` now links `libKGENCompilerRTShared.dylib` from `core/.venv` (the ABI's `List`/`Error` use pulls in the Mojo runtime) and bakes the path into the rpath.

**`game/tests/test_bridge.gd`** — headless SceneTree test: lifecycle, buy/sell/travel/finances, dump→load→dump byte-identical round-trip, determinism, and the rules surface.

**`tools/`** — `validate_abi_exporter.py` (no `dw_` export outside `abi.mojo`), `validate_abi_test_purity.py` (no non-std import in `core/abitest/`), `validate_abi_symbols.py` (`nm -g --defined-only` gate). All wired into `task lint`.

**Taskfiles/docs** — `core:abitest` and `game:bridge-test` added; `task check` runs both. `AGENTS.md`, `docs/abi-contract.md`, and `tests/mojo/README.md` updated.

## Verification

- `task check` from a clean state: 31 parity tests + 23 conformance tests + four-layer build + smoke test + bridge test, exit 0.
- `task lint`: markdownlint, core boundary gate, and all three ABI gates, exit 0.
- `nm -g --defined-only libdopewars.a`: 52 `_dw_*` defined globals, 0 non-`dw_` defined globals.
- Negative-tested both validators (they fail on injected violations).

## Key decisions

- **D1=A (plain-data World).** Honors the ABI contract's caller-owned-storage / no-destroy model exactly; no `dw_world_destroy` is needed.
- **`dw_abi_version()` added to the header** (additive, no version bump) so the shim and the TASK-001.03 smoke test keep working.
- **Float→int view projections truncate toward zero**, now pinned in `docs/abi-contract.md`.
- **Scripted RNG is not exposed by the ABI**; `dw_config` carries only a seed.

## Risks / follow-ups

- The GDExtension's rpath points at `core/.venv`'s Mojo runtime dylib — a dev-build dependency. A distributable bundle would copy `libKGENCompilerRTShared.dylib` next to the framework.
- NULL-pointer ABI paths are implemented but not exercised by the conformance suite (Mojo 1.1.0 limitation); the C++ shim never passes NULL.
- `dw_world_dump` has no version tag yet; the on-disk save format and its versioning remain open for the persistence work in TASK-001.06.
<!-- SECTION:FINAL_SUMMARY:END -->
