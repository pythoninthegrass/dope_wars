---
id: TASK-012.04
title: Probe whether Mojo can cross-compile the simulation core for Windows
status: Done
assignee: []
created_date: '2026-10-01 21:01'
updated_date: '2026-10-20 05:17'
labels: []
dependencies:
  - TASK-012.04.01
  - TASK-012.04.02
parent_task_id: TASK-012
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Modular's documentation states Mojo supports macOS and Linux natively and Windows only via WSL — there is no native Windows Mojo toolchain. This means there is currently no way to build a Windows `.dll` of the GDExtension shim, since `core/` (the sole `@export` surface, see `core/src/abi.mojo`) can only be compiled to a static library on macOS/Linux.

Before concluding Windows is unreachable, do a timeboxed (~2 hours) spike using `mojo build`'s cross-compilation flags (`--target-triple`, `--target-cpu`, `--emit object`) on `mf` to see how far compilation gets toward a Windows target, and what exactly blocks it (expected: missing Windows builds of the Mojo runtime support libraries, e.g. `libKGENCompilerRTShared`, `libAsyncRTRuntimeGlobals`). This should produce hard evidence (compiler output, missing-symbol lists), not speculation, written up in the style of the existing `docs/mojo-1.1.0-abi-constraints.md` (dead ends recorded as dead ends).

This task is a research spike, not an implementation task. If the probe unexpectedly succeeds end to end (a linkable Windows object with all runtime symbols resolvable), stop and get explicit direction before doing any further Windows build-system work — do not start wiring `extension/SConstruct` or `taskfiles/*.yml` for Windows as part of this task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `mojo build --emit object --target-triple x86_64-pc-windows-msvc` (and the `x86_64-w64-windows-gnu` variant, if supported) is attempted against `core/src/abi.mojo` on mf, with full compiler output captured
- [ ] #2 If an object file is produced, its undefined/external symbols are inspected (e.g. via `objdump`/`nm`) and categorized, specifically checking whether `KGEN_CompilerRT_*` and AsyncRT symbols are resolvable against anything shipped in the installed Mojo toolchain
- [ ] #3 The installed Mojo PyPI package/venv is checked for whether it ships any Windows build of the runtime support libraries (`libKGENCompilerRTShared`, `libAsyncRTRuntimeGlobals`, `libMSupportGlobals`) alongside the existing macOS/Linux ones
- [ ] #4 Findings (what compiles, what doesn't, exact error/symbol output) are written to a new `docs/mojo-windows-probe.md`
- [ ] #5 A conclusion is recorded in this task's final summary: Windows support is either blocked (with the specific blocking reason) or viable (with a clear description of what would be needed), suitable for someone else to decide next steps from
<!-- AC:END -->

## Final Summary

**Windows is blocked, at two independent points (see `docs/mojo-windows-probe.md`):**

1. **Package distribution (decisive):** the pinned `mojo==1.1.0` publishes only
   `manylinux_2_34_{x86_64,aarch64}` and `macosx_13_0_arm64` wheels — no
   `win_amd64`. uv 0.13.1 in the dockurr/windows container confirmed this directly
   (`No solution found ... no wheels with a matching platform tag`), so the toolchain
   cannot even be installed natively on Windows. `import mojo` fails, so there is
   no `mojo build` to run and no Windows runtime libraries to inspect.
2. **Linking (from Linux):** `mojo build --emit object` cross-compiles
   `core/src/abi.mojo` to valid Windows COFF for both the MSVC and GNU triples,
   but the Mojo runtime libraries ship only as Linux ELF and the object's
   `KGEN_CompilerRT_*` symbols are unresolvable without Windows builds of them
   plus a Windows linker.

**What would be needed:** Windows builds of
`libKGENCompilerRTShared`, `libAsyncRTRuntimeGlobals` and `libMSupportGlobals`
distributed as a `win_amd64` wheel (or the runtime cross-compiled), plus a Windows
linker (MSVC `link.exe` / MinGW) to produce `libdopewars.dll`, plus wiring into
`extension/SConstruct` and the taskfiles — all out of scope for this spike.

Subtasks created: `TASK-012.04.01` (Phase A, Linux cross-compile probe) and
`TASK-012.04.02` (Phase B, native Windows install). `docs/windows.md` documents
the container access.
