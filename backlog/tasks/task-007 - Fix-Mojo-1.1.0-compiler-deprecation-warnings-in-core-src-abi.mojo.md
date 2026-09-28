---
id: TASK-007
title: Fix Mojo 1.1.0 compiler deprecation warnings in core/src/abi.mojo
status: Done
assignee: []
created_date: '2026-09-28 18:45'
updated_date: '2026-09-28 21:55'
labels: []
dependencies: []
modified_files:
  - core/src/abi.mojo
priority: low
type: chore
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`task core:build` (and therefore `task dev` / `task run`) compiles cleanly today but emits two classes of compiler warnings against the pinned Mojo 1.1.0 toolchain (`MOJO_VERSION` in `taskfiles/core.yml`), all localized to `core/src/abi.mojo`:

1. `positional __getitem__ is deprecated, use unsafe_offset= instead` — pointer-like indexing using the bare `ptr[i]` / `value()[i]` form.
2. `transfer from an owned value has no effect and can be removed` — trailing `^` transfer sigils on values already being consumed or returned (e.g. `)^` at the end of a constructor call).

Neither class fails the build or `task check` today, but both indicate reliance on syntax the toolchain is already flagging for removal. Since Mojo is pinned to an exact version, a future bump to unpin or advance `MOJO_VERSION` could turn these into hard compile errors with no warning. Cleaning them up now keeps `task core:build` output free of noise, making it easier to spot a genuinely new warning later.

Ruleset/architecture context for the eventual reader: `core/src/abi.mojo` is the sole `@export` source for the frozen C ABI (`include/dopewars.h`); see `docs/abi-contract.md` and the "Target architecture (Godot port)" section of `AGENTS.md`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `task core:build` output contains zero `warning:` lines from `core/src/abi.mojo`
- [x] #2 All positional `ptr[i]` / `value()[i]` indexing in `core/src/abi.mojo` is migrated to the `unsafe_offset=` keyword form
- [x] #3 All flagged redundant `^` transfer sigils in `core/src/abi.mojo` are removed
- [x] #4 `task core:test` (Mojo parity fixture replay) still passes after the changes
- [x] #5 `task abi:check` and `task abi:conformance` still pass after the changes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Migrated all 12 positional pointer indexings (ptr[i], value()[i]) to the unsafe_offset= keyword form and removed all 11 compiler-flagged redundant ^ transfer sigils on fresh view-constructor rvalues passed positionally to unsafe_write (the argument is a deinit move, so the ^ was a no-op). The 4 remaining ^ sigils (return out^, game^, loaded^) are local-variable transfers the compiler does not flag and were left as-is. No semantic change: the migration is the exact fix-it the 1.1.0 compiler suggests, and the export-surface gate confirms the symbol set is unchanged (56/56).

Environment notes (machine-level, no repo files touched): two stale env vars from a prior harness had to be unset for the gates to run in this shell — VIRTUAL_ENV pointed at a leftover gnhf cache venv, which made uv pip install install into that venv instead of core/.venv (uv venv --allow-existing then left core/.venv without the mojo binary); and clang was falling back to the Command Line Tools MacOSX27.0.sdk, whose libSystem.B.tbd the installed ld rejects (malformed file / unknown architecture) — every cc link failed, even a hello world. Run the gates with env -u VIRTUAL_ENV SDKROOT=/Applications/Xcode.app/.../MacOSX.sdk task ... to reproduce.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed all Mojo 1.1.0 deprecation warnings from core/src/abi.mojo (the sole @export source for include/dopewars.h). 12 positional pointer indexings became the unsafe_offset= keyword form and 11 redundant ^ transfer sigils on constructor rvalues passed to unsafe_write were dropped — 23 lines, pure syntax, no behavioral change. Verified: task core:build now emits zero warnings (56/56 dw_* exports), task core:test passes 32/32 parity fixtures, task abi:check and task abi:conformance (40 ctypes + 23 mojo external_call + C11 header check) all pass.
<!-- SECTION:FINAL_SUMMARY:END -->
