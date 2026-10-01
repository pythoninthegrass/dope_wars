---
id: TASK-012.02
title: Export a distributable Linux build
status: To Do
assignee: []
created_date: '2026-10-01 21:00'
updated_date: '2026-10-01 21:01'
labels: []
dependencies:
  - TASK-012.01
parent_task_id: TASK-012
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
There is no `game/export_presets.cfg` for any platform, and `game/bin/dopewars.gdextension` has no `[dependencies]` section — so a Godot export today would ship `libdopewars.linux.*.so` without the three vendored Mojo runtime libraries it depends on at load time (`libKGENCompilerRTShared.so`, `libAsyncRTRuntimeGlobals.so`, `libMSupportGlobals.so`), and the exported binary would fail to launch outside the dev tree.

A sibling project, `~/git/neo_snake`, already solved this for its own GDExtension-based Godot game and is a good reference: its `game/export_presets.cfg` Linux preset (`architecture="x86_64"`, `export_path="build/linux/<name>.x86_64"`, `embed_pck=false`), its checksum-verified export-template install (`tools/bootstrap.py`, installing into a repo-local `XDG_DATA_HOME` so `$HOME` is never touched), and its `taskfiles/release.yml` `export-linux` task (`godot --headless --path game --export-release Linux`) are all directly adaptable. Depends on TASK-012.01 (the Linux build/test gate must be green first).

Mojo requires glibc 2.34 or later; `mf` has glibc 2.39. Confirm with `objdump -T` what floor the actual built artifacts need before deciding whether a container build (e.g. Ubuntu 22.04, as neo_snake's `docker/linux/Dockerfile` does for its Zig core) is needed for wider distribution — that container work is out of scope here if the native `mf` build already meets a reasonable floor; record the finding either way.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `game/bin/dopewars.gdextension` has a `[dependencies]` section listing the three vendored Mojo/KGEN runtime `.so` files for `linux.debug` and `linux.release`
- [ ] #2 `game/export_presets.cfg` exists with a working `Linux` preset
- [ ] #3 A `task export:templates` (or equivalent) downloads and checksum-verifies the pinned Godot export templates into a repo-local location, never touching the user's global Godot data directory
- [ ] #4 A `task export:linux` produces a Linux executable + `.pck` (+ release `.so`) under a gitignored build directory
- [ ] #5 Copying the exported output to a fresh directory outside the repo and launching it (`--headless --quit-after 2` or windowed) succeeds with no missing-library errors, verified on mf
- [ ] #6 The measured glibc floor of the exported artifacts is recorded in `docs/build-and-test.md`, along with whether it is met by `mf`'s own glibc or requires a container build (no container work required unless the floor is unmet)
<!-- AC:END -->
