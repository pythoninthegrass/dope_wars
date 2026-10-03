---
id: TASK-012.02
title: Export a distributable Linux build
status: Done
assignee: []
created_date: '2026-10-01 21:00'
updated_date: '2026-10-01 21:32'
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
- [x] #1 `game/bin/dopewars.gdextension` has a `[dependencies]` section listing the three vendored Mojo/KGEN runtime `.so` files for `linux.debug` and `linux.release`
- [x] #2 `game/export_presets.cfg` exists with a working `Linux` preset
- [x] #3 A `task export:templates` (or equivalent) downloads and checksum-verifies the pinned Godot export templates into a repo-local location, never touching the user's global Godot data directory
- [x] #4 A `task export:linux` produces a Linux executable + `.pck` (+ release `.so`) under a gitignored build directory
- [x] #5 Copying the exported output to a fresh directory outside the repo and launching it (`--headless --quit-after 2` or windowed) succeeds with no missing-library errors, verified on mf
- [x] #6 The measured glibc floor of the exported artifacts is recorded in `docs/build-and-test.md`, along with whether it is met by `mf`'s own glibc or requires a container build (no container work required unless the floor is unmet)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a `[dependencies]` section to `game/bin/dopewars.gdextension` for `linux.debug.x86_64`/`linux.release.x86_64`, listing the three vendored Mojo/KGEN runtime `.so` files so Godot copies them alongside the export.
2. Add `game/export_presets.cfg` with a Linux preset (`architecture="x86_64"`, `embed_pck=false`), adapted from `~/git/neo_snake`'s preset.
3. Pin the Godot export-template version/URL/sha256 in `tools/game_toolchain.lock`, matched to this repo's mise-pinned godot 4.7.2-stable.
4. Add `tools/fetch_export_templates.py`: checksum-verified download, extracted to `.tools/game/xdg-data/godot/export_templates/<version>/` (fake XDG_DATA_HOME, never the real `~/.local/share/godot`).
5. Add `taskfiles/export.yml` (`export:templates`, `export:linux`) wired into `taskfile.yml`; `export:linux` sets `XDG_DATA_HOME` to the repo-local dir before invoking `godot --headless --export-release Linux`.
6. Gitignore `.tools/` (build/ already covers `game/build/`).
7. Measure the glibc floor with `objdump -T` and record the finding in `docs/build-and-test.md`.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified on mf (AlmaLinux 10.2, glibc 2.39): `task export:templates` then `task export:linux` produced game/build/linux/{dopewars.x86_64,dopewars.pck,libdopewars.linux.template_release.x86_64.so,libAsyncRTRuntimeGlobals.so,libKGENCompilerRTShared.so,libMSupportGlobals.so}. Copied that directory to /tmp outside the repo and ran `./dopewars.x86_64 --headless --quit-after 2`: exit 0, `ldd` showed no missing libraries.

glibc floor: game/bin/libdopewars.linux.template_release.x86_64.so requires up to GLIBC_2.38 (objdump -T) -- higher than the three Mojo/KGEN runtime .so files (max GLIBC_2.35) and Godot's own linux_release.x86_64 export template (GLIBC_2.28), so the GDExtension itself sets the floor. mf's glibc 2.39 satisfies it, so no container build is needed for this host; recorded in docs/build-and-test.md.

The session's non-interactive bash PATH was briefly stuck resolving `godot` to a stale 4.7.1-stable install (mise's PROMPT_COMMAND-based PATH refresh doesn't fire in non-interactive shells) -- not a project bug, worked around locally with `eval "$(mise activate bash)"`.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Made the Linux export distributable outside the dev tree (TASK-012.02).

**Changes:**
- `game/bin/dopewars.gdextension`: added `[dependencies]` for `linux.debug.x86_64`/`linux.release.x86_64` listing the three vendored Mojo/KGEN runtime `.so` files, so Godot copies them next to the exported binary instead of shipping `libdopewars.linux.*.so` alone.
- `game/export_presets.cfg` (new): a `Linux` preset (`x86_64`, `embed_pck=false`, `export_path="build/linux/dopewars.x86_64"`), adapted from `~/git/neo_snake`'s.
- `tools/game_toolchain.lock` (new) + `tools/fetch_export_templates.py` (new): checksum-verified download of the Godot 4.7.2-stable export templates into a repo-local `.tools/game/xdg-data/godot/export_templates/4.7.2.stable/`, never the user's real `~/.local/share/godot`.
- `taskfiles/export.yml` (new), wired into `taskfile.yml`: `task export:templates` (the download above) and `task export:linux` (sets `XDG_DATA_HOME` to that repo-local dir, runs `godot --headless --export-release Linux`).
- `.gitignore`: added `.tools/` (build output under `game/build/` was already covered by the existing `build/` entry).
- `docs/build-and-test.md`: new "Tier 7 — Linux export" section documenting the two tasks and the glibc finding.

**glibc floor finding:** `game/bin/libdopewars.linux.template_release.x86_64.so` needs up to `GLIBC_2.38` (the repo's own GDExtension sets the floor — higher than the Mojo/KGEN runtime libs or Godot's own export template). `mf` ships glibc 2.39, which meets it, so **no container build is needed** for distribution from this host.

**Verification:** ran `task export:templates` then `task export:linux` on `mf`; copied `game/build/linux/`'s contents to `/tmp` outside the repo and ran `./dopewars.x86_64 --headless --quit-after 2` — exit 0, `ldd` reported no missing libraries.

**Follow-ups (not done here, out of scope):** macOS/Windows export presets, and TASK-012.03/012.04 (play-test screenshots, Windows cross-compile probe).
<!-- SECTION:FINAL_SUMMARY:END -->
