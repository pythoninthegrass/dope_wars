---
id: TASK-012.04.01
title: Probe cross-compiling the Mojo core for Windows from Linux
status: To Do
assignee: []
created_date: '2026-10-20 03:37'
labels: []
dependencies: []
parent_task_id: TASK-012.04
ordinal: 84000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research spike on the AlmaLinux host. Using the pinned Mojo 1.1.0 venv under core/.venv, probe how far `mojo build`'s cross-compilation flags get toward a Windows target for core/src/abi.mojo, and capture hard evidence of what blocks it.

Steps:
1. Baseline: run `mojo build --emit object` on core/src/abi.mojo natively and save its symbol table as the reference.
2. Attempt `--emit object --target-triple x86_64-pc-windows-msvc`, then the `x86_64-w64-windows-gnu` variant, capturing full compiler output verbatim.
3. If an object is produced, `file` it, dump its undefined/external symbols with `llvm-nm`/`llvm-objdump`, and categorize them — specifically whether `KGEN_CompilerRT_*` and AsyncRT symbols are resolvable against anything shipped in the installed toolchain.
4. Inventory core/.venv for whether the PyPI package ships any Windows build of the runtime support libraries (libKGENCompilerRTShared, libAsyncRTRuntimeGlobals, libMSupportGlobals) alongside the macOS/Linux ones.
5. Checkpoint: if the object path fails early, retry with `--emit llvm-bitcode` to isolate whether the blocker is the compiler frontend or the backend/runtime.

This is a research spike, not an implementation task. Write dead ends up as dead ends in the style of docs/mojo-1.1.0-abi-constraints.md.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Both Windows target triples (x86_64-pc-windows-msvc and x86_64-w64-windows-gnu if supported) are attempted on core/src/abi.mojo with full compiler output captured
- [ ] #2 Any produced object file's symbol table is inspected and categorized against the shipped runtime libraries
- [ ] #3 The installed toolchain is inventoried for Windows builds of the runtime support libraries
- [ ] #4 Findings are written to docs/mojo-windows-probe.md (Phase A section), dead ends recorded as dead ends
<!-- AC:END -->
