---
id: TASK-012.01
title: Get task check green on AlmaLinux (mf)
status: To Do
assignee: []
created_date: '2026-10-01 21:00'
labels: []
dependencies: []
parent_task_id: TASK-012
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`task check` (the full gate set: Mojo parity replay, static ABI gates, conformance drivers, the game/simulation boundary check, both bridge tests, the presentation-layer test, the full build, and the headless Godot smoke test) has never been run to completion on Linux. The project has been built and gated on macOS only.

`mf` is an AlmaLinux 10.2 (glibc 2.39) x86_64 box reachable over ssh with the repo already checked out; connection details are in `CLAUDE.local.md` at the repo root (do not copy them into this task). It already has `godot 4.7.2-stable`, `task 3.49.1`, and `scons 4.11.1` resolvable through `mise exec`, plus `readelf`, `objcopy`, `ar`, `g++`, and `timeout`. It has built the Linux debug `.so` once before, but `task check` itself has not been run there.

Known risk areas going in (to investigate, not assume are bugs):
- `taskfiles/game.yml`'s `game:icon` task shells out to `sips`/`iconutil`, which exist only on macOS.
- `extension/SConstruct`'s Linux rpath branch (`$ORIGIN`, `readelf`-based dependency walk for vendoring the Mojo/KGEN runtime libraries) has wiring for Linux but has not been exercised end to end on a real Linux host.
- There is no Linux release-build task today (`taskfiles/extension.yml`'s `build-macos` task is restricted to darwin/arm64).

Any gate failure caused by a genuine macOS-only assumption in the build/test tooling should be fixed (gated by `platforms:` in the Taskfile where the fix is platform-specific, not by disabling the check). This is Linux build/test tooling only — it does not include producing an exported, distributable Linux game build (that is a separate task).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `task check` exits 0 when run on mf (AlmaLinux 10.2) against a current checkout of `main`
- [ ] #2 Any Taskfile command that depends on a macOS-only tool (e.g. `sips`, `iconutil`) is gated with `platforms:` so it is skipped rather than failing on Linux, with the skip explained in a comment
- [ ] #3 `readelf -d` on the Linux-built `game/bin/libdopewars.linux.*.so` confirms a self-relative `$ORIGIN` rpath and the vendored Mojo/KGEN runtime libraries are present alongside it, matching the macOS `@loader_path` behavior already verified in TASK-002
- [ ] #4 A Linux equivalent of the macOS release-build task exists in `taskfiles/extension.yml` (producing `template_release`, not just `template_debug`), gated to `platforms: [linux]`
- [ ] #5 `docs/build-and-test.md` gains a short Linux section noting any host package prerequisites (e.g. `readelf`/`objcopy` availability) discovered while getting the gate green
- [ ] #6 A full `task check` log from mf is attached to this task's implementation notes
<!-- AC:END -->
