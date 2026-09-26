---
id: TASK-001.03
title: 'Scaffold Godot project, C++ GDExtension shell, and Mojo build wiring'
status: To Do
assignee: []
created_date: '2026-09-26 04:33'
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
- [ ] #1 mojo build (or equivalent Taskfile step) from core/ produces a static library exporting at least one placeholder ABI symbol; symbol is visible in nm output
- [ ] #2 scons from extension/ links against the Mojo-produced library and produces a loadable shared library (.so or .dylib)
- [ ] #3 The Godot project boots, loads the GDExtension without errors, and a GDScript one-liner can call a no-op stub method and receive a response
- [ ] #4 task check (or equivalent) runs the full build and stub-test pipeline in one command and exits non-zero on any failure
- [ ] #5 .tool-versions entries for Mojo and Godot are committed and validated via mise
<!-- AC:END -->
