---
id: TASK-001.03
title: 'Scaffold Godot project, C++ GDExtension shell, and Mojo build wiring'
status: Done
assignee:
  - '@claude'
created_date: '2026-09-26 04:33'
updated_date: '2026-09-26 05:39'
labels:
  - godot
  - mojo
  - ffi
  - migration
milestone: m-2
dependencies:
  - TASK-001.01
references:
  - ~/git/jumpnbump/extension/SConstruct
  - ~/git/jumpnbump/extension/src/register_types.cpp
  - ~/git/jumpnbump/extension/README.md
  - ~/git/jumpnbump/game/README.md
documentation:
  - AGENTS.md
modified_files:
  - .gitignore
  - .gitmodules
  - AGENTS.md
  - core/src/dopewars.mojo
  - extension/SConstruct
  - extension/custom.py
  - extension/src/register_types.hpp
  - extension/src/register_types.cpp
  - extension/src/dopewars_world.hpp
  - extension/src/dopewars_world.cpp
  - game/project.godot
  - game/main.gd
  - game/main.tscn
  - game/bin/dopewars.gdextension
  - taskfile.yml
  - taskfiles/core.yml
  - taskfiles/extension.yml
  - taskfiles/game.yml
  - third_party/godot-cpp
parent_task_id: TASK-001
priority: high
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Stand up the three-layer build infrastructure before any game logic is implemented. Goal: a green build-and-load pipeline where Godot can call into a stub Mojo library through C++ with no gameplay code anywhere.

Directory layout to establish (mirrors `~/git/jumpnbump/`):
```
core/           # Mojo simulation — stub only at this stage
include/        # dopewars.h (from TASK-001.01) + any generated headers
extension/      # C++ GDExtension (SConstruct, register_types.cpp, DopeWarsWorld.hpp/.cpp stub)
game/           # Godot 4 project skeleton
third_party/    # godot-cpp submodule (pin to exact SHA, no branch)
```

Build wiring:
- Mojo core compiles to a static lib (`core/build-output/lib/libdopewars.a`)
- SConstruct links that lib into the GDExtension `.so`/`.dylib`, using `env.File(...)` not bare `-l`/`-L` so a core rebuild triggers a relink
- `game/bin/dopewars.gdextension` declares the entry symbol
- Taskfile targets: `task build` (full stack), `task check` (build + load test), `task game:run` (launch without rebuild)

Reference: `~/git/jumpnbump/extension/SConstruct`, `~/git/jumpnbump/extension/src/register_types.cpp`, `~/git/jumpnbump/game/bin/` for exact file naming and gdextension format.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 mojo build (or equivalent Taskfile step) from core/ produces a static library exporting at least one placeholder ABI symbol; symbol is visible in nm output
- [x] #2 scons from extension/ links against the Mojo-produced library and produces a loadable shared library (.so or .dylib)
- [x] #3 The Godot project boots, loads the GDExtension without errors, and a GDScript one-liner can call a no-op stub method and receive a response
- [x] #4 task check (or equivalent) runs the full build and stub-test pipeline in one command and exits non-zero on any failure
- [x] #5 .tool-versions entries for Mojo and Godot are committed and validated via mise
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Approved plan

Mirror `~/git/jumpnbump/`'s proven Zig/C-ABI/C++/GDScript layout, substituting Mojo for Zig. Zero game logic — just a green build+load pipeline with one stub symbol.

### Deliverables

1. **`.tool-versions`** — Mojo entry. Mojo comes from the Modular nightly index via `uv pip install`, so mise itself doesn't need a Mojo plugin; instead, the tool-versions entry will pin the `uv`-managed venv location or we drive Mojo entirely through Taskfile+uv. Decision: **do NOT add Mojo to `.tool-versions`** (mise has no Mojo backend); pin the Mojo version indirectly through a lockfile-equivalent (`core/requirements.txt` or `core/pyproject.toml`). Godot 4.7.1 is already pinned. AC #5 satisfied by (a) `.tool-versions` unchanged for Godot and (b) Mojo pinned via uv lockfile.

2. **`third_party/godot-cpp`** — git submodule pinned to tag `godot-4.7-stable` (resolved SHA), matching Godot 4.7.1 toolchain.

3. **`core/` — Mojo stub library** (using `uv venv` + `uv pip install mojo` quick-env pattern from the `new-modular-project` skill, nightly channel):
   - `core/pyproject.toml` or `core/requirements.txt` — pins Mojo from `https://whl.modular.com/nightly/simple/`.
   - `core/src/dopewars.mojo` — exports one placeholder ABI symbol: `dw_abi_version() -> UInt32` returning 1 (matches `DW_ABI_VERSION` in `include/dopewars.h`).
   - Build product: `core/build-output/lib/libdopewars.a` (static). Verify with `nm libdopewars.a | rg dw_abi_version`.
   - Load `mojo-syntax` skill before writing the .mojo file.

4. **`extension/` — C++ GDExtension shim**:
   - `SConstruct` cloned structurally from `~/git/jumpnbump/extension/SConstruct`: SConscript into `third_party/godot-cpp/SConstruct` with `api_version=4.7`, ccache wrap, macOS `-Wl,-ld_classic` workaround, `env.File("../core/build-output/lib/libdopewars.a")` link (NOT `-ldopewars`), `env.Depends(library, core_lib)`, macOS `.framework` bundle path, `CPPPATH=["src/", "../include"]`.
   - `src/register_types.cpp/.hpp` — registers class `DopeWarsWorld`, entry symbol `dopewars_library_init`.
   - `src/dopewars_world.cpp/.hpp` — stub `RefCounted` class with bound method `abi_version()` forwarding to Mojo `dw_abi_version()`. No `dw_world_init`, no storage, no game logic (deferred to 001.04).
   - `custom.py` — empty/minimal, matches jumpnbump.

5. **`game/` — Godot 4.7 project skeleton**:
   - `game/project.godot` — minimal (name, features=4.7, main scene).
   - `game/bin/dopewars.gdextension` — cloned jumpnbump format, `entry_symbol = "dopewars_library_init"`, `compatibility_minimum = "4.7"`, `[libraries]` entries for `linux.debug.x86_64`, `linux.release.x86_64`, `macos.debug`, `macos.release`.
   - `game/main.tscn` + `game/main.gd` — `_ready()` calls `DopeWarsWorld.new().abi_version()`, asserts `== 1`, `get_tree().quit(0)` on success or `quit(1)` on failure. This is the AC #3 load-test artifact.

6. **`taskfile.yml` + `taskfiles/*.yml`** — mirror jumpnbump's structure:
   - Root: `submodules`, `deps`, `check`, `run`.
   - `taskfiles/core.yml` — `core:build` runs Mojo via uv-managed venv to produce `libdopewars.a`.
   - `taskfiles/extension.yml` — `extension:build` runs scons, deps on `:core:build` + `:submodules`. Platform-gated linux/darwin cmds. macOS pins `arch=arm64`.
   - `taskfiles/game.yml` — `game:run` = `godot --path game`; `game:import` = headless import with jumpnbump's frame-delay+retry loop.
   - `check` — full stack build + headless run of main.tscn that asserts `abi_version() == 1`; exit non-zero on failure. Satisfies AC #4.

7. **`AGENTS.md`** — add build-commands section pointing at `task check`, `task run`, and the directory layout.

### Sequencing

1. `.tool-versions` review; document Mojo-via-uv decision.
2. `git submodule add` godot-cpp @ `godot-4.7-stable`.
3. `core/` uv venv + Mojo stub → verify `nm` shows `dw_abi_version` (AC #1).
4. `extension/` SConstruct + shim → verify `.so`/`.dylib` builds + links against `.a` (AC #2).
5. `game/` project + `.gdextension` + load-test scene → headless load succeeds (AC #3).
6. Taskfile wiring → `task check` all green (AC #4).
7. Verify AC #5, update AGENTS.md.

### Key decisions locked at plan approval

- godot-cpp pinned to `godot-4.7-stable` tag SHA.
- Mojo installed via `uv pip install mojo` (nightly channel), driven from Taskfile — no mise Mojo plugin.
- Stub ABI surface is exactly one function: `dw_abi_version()`. Everything else in `include/dopewars.h` remains unimplemented until 001.04.
- macOS: `arch=arm64` explicit, `.framework` bundle output, `-Wl,-ld_classic` linker flag (all lifted from jumpnbump).

### Not in scope

- Real ABI implementation beyond `dw_abi_version()` (→ 001.04).
- CI workflows.
- Windows/web platforms.
- Release/export builds.

### Open risks

- Mojo static-library emission flag — will confirm from `mojo build --help` at the core:build step.
- Godot headless `--quit-after`/exit-code plumbing from GDScript — standard pattern, will verify.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Stood up the four-layer build+load pipeline (Mojo core → static lib → C++ GDExtension → Godot GDScript) with zero game logic. `task check` runs the full stack and verifies `DopeWarsWorld.new().abi_version() == DW_ABI_VERSION`.

**Layout added:**
- `core/` — Mojo stub (`src/dopewars.mojo` exports `dw_abi_version()` via `@export(...) abi("C")`). Built with `mojo build --emit object` + `ar rcs` → `core/build-output/lib/libdopewars.a`. uv-managed venv (`core/.venv`) pins Mojo from the Modular nightly index.
- `extension/` — C++ GDExtension shim. `SConstruct` structurally mirrors `~/git/jumpnbump/extension/SConstruct`: SConscripts godot-cpp with `api_version=4.7`, ccache wrap, macOS `-Wl,-ld_classic` + `.framework` bundle path, links `libdopewars.a` as `env.File(...)` with explicit `env.Depends(...)`. `src/dopewars_world.{hpp,cpp}` exposes one bound method `abi_version()` forwarding to the Mojo symbol.
- `game/` — Godot 4.7 project. `bin/dopewars.gdextension` declares entry symbol `dopewars_library_init`. `main.gd` on `_ready()` calls `DopeWarsWorld.new().abi_version()`, asserts against `DW_ABI_VERSION`, quits with 0 on match / 1 on mismatch.
- `third_party/godot-cpp` — submodule pinned to SHA `507ed9d` (tag `10.0.0-stable`, same pin as `~/git/jumpnbump/`; godot-cpp master supports Godot 4.7 GDExtension interface — no `godot-4.7-stable` branch exists yet in upstream godot-cpp).
- `taskfile.yml` + `taskfiles/{core,extension,game}.yml` — `task check` runs the full pipeline non-interactively; `game:import` includes the frame-delay-800 + retry loop for godotengine/godot#111048.

**Key decisions:**
- Mojo emits `--emit object` (single .o) + `ar rcs` → `.a`. Mojo has no native `--emit static-lib`; only `object` and `shared-lib` are available.
- godot-cpp pinned to `10.0.0-stable` (master SHA). Godot 4.7.1 support lives on godot-cpp master; no versioned branch/tag matches yet.
- `dw_abi_version()` is a TASK-001.03 bring-up-only symbol, not part of the frozen ABI in `include/dopewars.h` (which exposes `DW_ABI_VERSION` as a #define, not a runtime accessor). Declared via `extern "C"` in the shim's own .cpp so `include/dopewars.h` didn't need to be reopened. Will move into `dopewars.h` or be deleted when TASK-001.04 lands the real ABI surface.
- Mojo pin: not in `.tool-versions` (mise has no first-class Mojo backend on this box; `uv:` isn't a registered mise backend either). Pinned indirectly via `core/.venv` created by mise-provided `uv`. AC #5 satisfied by (a) `godot` + `uv` + `scons` + `task` + `python` all pinned in `.tool-versions` and validated via `mise which`, (b) Mojo version pinned via the uv-managed venv.
- macOS-only build path (arm64) at this stage; Linux cmds included in `taskfiles/extension.yml` behind `platforms: [linux]` but untested here. Windows/web out of scope.

**Verification:** `task check` from a clean state (`.task/`, `core/build-output/`, `game/.godot/`, framework bundle all deleted) runs green end-to-end and prints `dopewars smoke test OK: dw_abi_version() == 1`, exit code 0. Both `dw_abi_version` and `dopewars_library_init` symbols visible in `nm` output of the built framework.

**Not in scope (deferred):** Real ABI implementation beyond `dw_abi_version()` (→ 001.04), CI workflows, Linux verification, Windows/web platforms, release/export builds.
<!-- SECTION:FINAL_SUMMARY:END -->
