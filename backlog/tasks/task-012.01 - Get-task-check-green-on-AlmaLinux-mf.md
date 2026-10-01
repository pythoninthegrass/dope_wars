---
id: TASK-012.01
title: Get task check green on AlmaLinux (mf)
status: In Progress
assignee:
  - Claude
created_date: '2026-10-01 21:00'
updated_date: '2026-10-01 21:11'
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

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. On mf, checked out branch task-012-linux-windows-testing (has the new backlog files only; no code changes yet).\n2. Run `mise exec -- task check` and capture full log to scratchpad; triage failures.\n3. Expected/likely fixes based on reading taskfiles/game.yml, extension.yml, SConstruct before running:\n   - `game:icon` task's sips/iconutil step only runs if `.task/checksum` cache is stale; mf already has a `.task/checksum` dir from a prior partial build, so it may or may not trigger. Gate the sips/iconutil block with `platforms: [darwin]` regardless (plain `cp logo.png` step stays unconditional/cross-platform; icon.icns is committed to git and only consumed by Godot's macOS-only native-icon API).\n   - Add `extension:build-linux` (template_debug + template_release), gated `platforms: [linux]`, mirroring `build-macos`.\n   - Verify `readelf -d game/bin/libdopewars.linux.*.so` shows `$ORIGIN` rpath and the vendored KGEN libs sit next to it (SConstruct already has generic Linux logic via readelf/NEEDED walk -- confirm it actually works end to end rather than assuming).\n4. Fix whatever `task check` actually reports beyond these predictions -- do not assume the list above is complete.\n5. Add a short Linux section to docs/build-and-test.md recording host prerequisites discovered (readelf/objcopy package names, etc).\n6. Re-run `task check` to green, attach the log to task notes, verify each AC, then finalize per the finalization guide.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Ran `task check` on mf against the new branch: failed at `game:icon`'s `sips` step (exit 127, "executable file not found in $PATH"), exactly the predicted macOS-only assumption. Nothing else failed.

Fix: gated the `.icns`-generation `cmd` block in `taskfiles/game.yml`'s `icon` task with `platforms: [darwin]`; the unconditional `cp logo.png game/content/icon.png` step stays cross-platform. `game/content/icon.icns` is already checked into git from the last macOS build, so Linux checkouts still get a valid file, just not regenerated.

Added `taskfiles/extension.yml`'s `build-linux` task (template_debug + template_release), gated `platforms: [linux]`, mirroring `build-macos`. Ran it on mf: clean build, no SConstruct changes needed.

Re-ran `task check` on mf after the fix: exit 0, first clean pass. All test-floor assertion counts present: bridge-test 16 assertions, bridge-test-script 94 assertions, ui-test 539 assertions -- none silently skipped.

Verified AC#3 directly: `readelf -d game/bin/libdopewars.linux.template_debug.x86_64.so` and the `template_release` variant both show `RPATH: [$ORIGIN]` and `NEEDED: [libKGENCompilerRTShared.so]`; the three vendored KGEN `.so` files sit next to it in `game/bin/`.

Noted (not a regression, not fixed): both Linux and macOS `task check` runs print a benign "ERROR: Parse JSON failed... highscore_store.gd:32" and "2 resources still in use at exit" during `game:ui-test`/`game:smoke-test`. Confirmed present on macOS too via a fresh local run, so this is pre-existing Godot/test-harness noise unrelated to this task -- left alone, out of scope here.

Added a "Linux" section to `docs/build-and-test.md` (prerequisites, the `build-linux` task, the icon-task skip rationale, the `readelf` verification command). `task lint` (markdownlint) passes locally.

Confirmed `task check` still exits 0 on macOS after these Taskfile edits (no cross-platform regression).
<!-- SECTION:NOTES:END -->
