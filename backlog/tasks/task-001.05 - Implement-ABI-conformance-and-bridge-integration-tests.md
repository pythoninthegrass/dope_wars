---
id: TASK-001.05
title: Implement ABI conformance and bridge integration tests
status: To Do
assignee: []
created_date: '2026-09-26 04:34'
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
- [ ] #1 nm -g --defined-only on the built Mojo static lib shows only symbols matching the dopewars_ ABI prefix and nothing else
- [ ] #2 ABI conformance tests reach the library exclusively through the C header (ctypes or equivalent C-import mechanism) and never call Mojo functions directly
- [ ] #3 A purity validator script (following ~/git/jumpnbump/tools/validate_abi_test_purity.py) fails if any conformance test imports Mojo core modules directly
- [ ] #4 Integration tests exercise at least: world init/destroy, a full game step sequence, and a serialize/deserialize round-trip through the Godot->C++->Mojo call path
- [ ] #5 A CI gate fails if any non-ABI symbol is exposed in the built library
<!-- AC:END -->
