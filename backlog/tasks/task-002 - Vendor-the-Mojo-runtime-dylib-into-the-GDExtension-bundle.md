---
id: TASK-002
title: Vendor the Mojo runtime dylib into the GDExtension bundle
status: To Do
assignee: []
created_date: '2026-09-26 18:19'
labels:
  - build
  - packaging
  - mojo
  - godot
milestone: m-2
dependencies:
  - TASK-001.05
references:
  - extension/SConstruct
  - AGENTS.md
  - ~/git/jumpnbump/extension/SConstruct
priority: medium
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Mojo ABI uses `List`/`Error`, so `core/build-output/lib/libdopewars.a` references the Mojo runtime (`KGEN_CompilerRT_*`). TASK-001.05 made `extension/SConstruct` link `libKGENCompilerRTShared.dylib` from `core/.venv/lib/python3.13/site-packages/modular/lib/` by absolute path and bake that path into the GDExtension's rpath.

That is a dev-build dependency: the built `game/bin/libdopewars.*` only loads while `core/.venv` exists at that exact path, and it is not distributable. This task vendors the runtime so the bundle is self-contained.

**Scope:**
- Copy `libKGENCompilerRTShared.dylib` next to the framework (or into it) as part of `task extension:build`, and set the rpath to `@loader_path` (or `@loader_path/..`) instead of the venv path.
- Handle the Linux equivalent: copy the `.so` and use `$ORIGIN` in the rpath.
- Gitignore the copied runtime (it is a build artifact, not source).
- Keep `task check` green.

**Out of scope:** release/export packaging, code signing, notarization, Windows/web.

References: `extension/SConstruct`, `AGENTS.md` (the "Mojo runtime" note), `~/git/jumpnbump/extension/SConstruct` for how that repo handles its own runtime dependency.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The built GDExtension resolves the Mojo runtime with no absolute path to core/.venv in its load commands
- [ ] #2 otool -L (macOS) / readelf -d (Linux) shows the runtime as @loader_path- or $ORIGIN-relative, or a system path
- [ ] #3 task extension:build copies the runtime next to the framework as part of the build
- [ ] #4 The copied runtime is gitignored
- [ ] #5 task check still exits 0
<!-- AC:END -->
