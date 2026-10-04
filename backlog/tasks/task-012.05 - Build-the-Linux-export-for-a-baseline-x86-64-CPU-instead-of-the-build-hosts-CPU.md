---
id: TASK-012.05
title: >-
  Build the Linux export for a baseline x86-64 CPU instead of the build host's
  CPU
status: Done
assignee:
  - '@claude'
created_date: '2026-10-04 00:02'
updated_date: '2026-10-04 00:11'
labels: []
dependencies:
  - TASK-012.02
parent_task_id: TASK-012
priority: high
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Linux release export from TASK-012.02 crashes with SIGILL (illegal instruction) on any x86-64 CPU that lacks the instruction-set extensions of the CPU that built it. Found while trying to run the exported build on a Fedora 42 laptop with an Intel Core Ultra 7 155H (AVX2, no AVX-512): the kernel trap log names `libdopewars.linux.template_release.x86_64.so` (the Mojo core) as the faulting module, on every launch.

Cause: `task core:build` runs `mojo build src/abi.mojo --emit object` (taskfiles/core.yml) without a target CPU, and `mojo build` defaults to the host CPU. The export was built on mf (AMD Ryzen 7 7840HS, which has AVX-512), and the resulting `.so` contains 85 `%zmm` (AVX-512) instructions. `mojo build` has `--target-cpu` and `--target-features` options that override the host default.

Open question that must be answered, not assumed: `libKGENCompilerRTShared.so` (Modular's prebuilt runtime, vendored into the export) also contains 555 `%zmm` instructions. It is expected to select its code paths at runtime, but this has not been verified. If it does not, this task cannot be fully solved by a flag in this repo and the finding must be reported.

The goal is a distributable Linux export that runs on ordinary modern x86-64 machines, not only on the machine that built it. macOS (arm64) builds are unaffected and must keep building for the host.

Scope guard: the Mojo parity gate (`task core:test`, fixtures replayed against the JS oracle) must stay green, because changing the target CPU can change floating-point codegen (FMA contraction).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The exported Linux build launches and runs (headless smoke test at minimum) on an x86-64 CPU without AVX-512; the Fedora 42 / Core Ultra 7 155H laptop is the known-failing reproduction
- [x] #2 The baseline CPU level chosen (e.g. which x86-64 microarchitecture level) is documented in docs/build-and-test.md with the reason, and applies to Linux x86-64 only; macOS arm64 builds are unchanged
- [x] #3 A gate fails the build if the exported core library contains instructions beyond the chosen baseline (e.g. AVX-512 registers in the disassembly), so the regression cannot return silently
- [x] #4 The question of whether libKGENCompilerRTShared.so is safe on non-AVX-512 CPUs is answered with evidence (runtime dispatch verified, or the limitation recorded in docs)
- [x] #5 `task check` stays green on both macOS and mf, including the Mojo parity replay against the JS oracle fixtures, with no fixture or expectation edited to make it pass
- [x] #6 The Mojo core ABI export check (`task abi:check` / tools/check_abi_exports.py) still passes unchanged
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Findings so far (read-only probes on mf, scratch dir only):
- `mojo build src/abi.mojo --emit object` with the default (host) CPU: 85 zmm insns. With `--target-cpu x86-64` or `x86-64-v2`: 0 zmm, 0 ymm. With `x86-64-v3`: 0 zmm, 431 ymm (AVX2). All four values are accepted by Mojo 1.1.0.
- The C++ shim already has no AVX-512 (the 85 zmm in the exported .so equal the Mojo object's 85).
- libKGENCompilerRTShared.so: 555 zmm insns in one contiguous ~16KB block (vpmuludq/vpaddq/vpsrlq/vpshufd: hash-style vector math), near cpuid/xgetbv feature-probe code. Suggests runtime dispatch, not proven yet.

Approach, TDD order:
1. Write the gate first: tools/check_cpu_baseline.py scans an object/archive/.so via objdump and fails on any VEX/EVEX instruction touching xmm/ymm/zmm (i.e. anything above x86-64-v2). Add tools/test_check_cpu_baseline.py with synthetic disassembly (clean, ymm, zmm, k-reg cases) and run it red then green. Then run the gate against the existing host-built libdopewars.a on mf and confirm it FAILS (the real regression).
2. Add `--target-cpu x86-64-v2` to the `mojo build` line in taskfiles/core.yml for Linux x86-64 only (macOS arm64 and Linux aarch64 stay host-native), via a Taskfile var computed from uname. Wire the gate into core:build on Linux x86-64 after the ABI export check. Chosen level x86-64-v2 (SSE4.2): widest compatibility, and this turn-based sim has no vector-throughput need; v3 would exclude pre-2013 CPUs for no benefit.
3. Rebuild on mf, re-run `task check` there (parity replay, ABI checks) and on macOS (`task check`), confirming no fixture or expectation edits.
4. Re-export on mf (`task export:linux`), re-run the gate on the exported .so, zip, and run `--headless --quit-after 2` on the Fedora laptop (previously SIGILL) as the smoke test (AC#1).
5. AC#4: identify the function containing the zmm block in libKGENCompilerRTShared.so, show its callers are guarded by the cpuid/xgetbv check (disassembly evidence), and corroborate with the laptop run. If the guard cannot be shown, record the limitation in docs instead of claiming safety.
6. Document the baseline, the reason, and the gate in docs/build-and-test.md (one long line per paragraph, markdownlint clean).
7. Conventional commit(s) on main, no Claude attribution. Close the task per the finalization guide.

Revision (approved by Lance 2026-10-04): baseline is x86-64-v3 (AVX2/FMA/BMI2, Haswell 2013+), not v2; older CPUs are explicitly not supported. Consequences: the target flag is `--target-cpu x86-64-v3`, and the gate must ALLOW ymm/VEX but FAIL on anything AVX-512: %zmm, k-mask registers (%k0-%k7 / {%kN} masking), and the extended xmm16-31/ymm16-31 registers. Docs state v3 and the 2013 cutoff.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Evidence. AC#1: release export rebuilt on mf, zipped, run on the Fedora 42 / Core Ultra 7 155H laptop in a scratch dir: `./dopewars.x86_64 --headless --quit-after 120 --seed=42` exits 0, no new `trap invalid opcode` in the kernel log (previously faulted at offset 0x6d597 of the core .so on every launch). AC#3: tools/check_cpu_baseline.py fails the pre-fix libdopewars.a (115 AVX-512 hits) and passes the rebuilt one (0) and the exported release .so. AC#4: libKGENCompilerRTShared.so dispatches at runtime: cpuid leaves 0/1/7 + xgetbv (XCR0 & 0xe6) pick one row of a four-row function-pointer table (scalar/SSE2/AVX2/AVX-512); the zmm functions have no direct callers and are reachable only through that table; the laptop has AVX-512F=0 so it takes the AVX2 row. AC#5: task check exit 0 on mf and macOS, assertion counts 16/94/539 on both, no fixture or expectation edited. Caveat: core:test runs via `mojo run` (host-native), so only the bridge/ui tests exercise the v3 codegen; recorded in docs/build-and-test.md.

Side finding: the tracked root Taskfile is lowercase `taskfile.yml`; on case-insensitive macOS an edit to `Taskfile.yml` hits it, but on case-sensitive mf an rsync of `Taskfile.yml` creates a stray second file that task prefers. Synced as `taskfile.yml` and removed the stray; worth remembering when rsyncing to mf.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Linux x86-64 core is now built with `--target-cpu x86-64-v3` (Haswell/2013+; older CPUs intentionally unsupported) via a Taskfile var that is empty on macOS and other hosts. New gate tools/check_cpu_baseline.py (with a self-test wired into `task abi:check`) runs in `core:build` and fails on any zmm, k-mask or xmm/ymm16-31 use. The previously crashing laptop now runs the export headless. Documented the baseline, the gate, and the evidence that Modular's vendored runtime dispatches its AVX-512 paths at runtime (docs/build-and-test.md, "CPU baseline").
<!-- SECTION:FINAL_SUMMARY:END -->
