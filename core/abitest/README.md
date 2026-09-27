# ABI conformance suite

Tier-C tests for the frozen C ABI in `include/dopewars.h`. This directory holds
three drivers that cross the same boundary by different mechanisms: the ctypes
suite (`abi_conformance_test.py`), the C header self-consistency TU
(`abi_header_check.c`), and the Mojo driver below, which reaches the compiled
core exclusively through the header via `std.ffi.external_call` against the
linked static library (`core/build-output/lib/libdopewars.a`). No driver imports
a core module — `tools/validate_abi_test_purity.py` fails the build if one does
(std-only imports and an `external_call["dw_..."]` are required of the Mojo
driver).

```sh
task core:abitest:mojo
```

`task abi:conformance` runs all three drivers; `task check` runs them before
the Godot build, so an ABI regression fails the whole pipeline.

## Why `external_call` and not `@cImport`

Mojo 1.1.0 has no `@cImport` (the `from C import ...` form does not resolve).
`std.ffi.external_call` is the working equivalent: it declares the C symbol and
links against the static library. The ABI structs are therefore declared here
field for field, and `test_struct_sizes_match_header` asserts each `size_of`
against the header's `DW_STATIC_ASSERT` value, so a layout drift breaks the
build on both sides.

## What is covered

- **Struct layout** — every ABI struct's size.
- **World lifecycle** — `dw_world_size`/`dw_world_align`, init, reset, config
  overrides, ABI-version mismatch.
- **Every result code** — each `DW_ERR_*` is reached from at least one call
  path, plus `DW_OK`.
- **Two-call buffer contracts** — `dw_prices_copy`, `dw_inventory_copy`,
  `dw_price_events_drain`, `dw_world_dump`, `dw_rules_locations_copy`,
  `dw_rules_drugs_copy`: length query, too-small rejection, exact fill.
- **Determinism** — same seed produces byte-identical dumps; different seeds
  diverge.
- **Serialization** — dump → load → dump is byte-identical; a truncated buffer
  is rejected and leaves the world unchanged.
- **Rules / RNG / lookups** — the rule accessors, `dw_mulberry32_*` against the
  JS oracle's raw draws, `dw_rand_int` bounds and state advance, and
  `dw_find_drug_index` / `dw_find_location_index`.
- **Game step sequence** — buy, sell, travel, finances, dealer offers, combat,
  finish, high-score insertion.

## Not covered

NULL-pointer paths. Mojo 1.1.0 cannot construct a null `Pointer`, and mixing
`Pointer` and `OptionalPointer` arguments for one `external_call` symbol is a
signature conflict. The ABI's NULL guards are implemented and compile; the C++
shim never passes NULL.
