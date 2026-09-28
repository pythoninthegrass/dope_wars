---
id: TASK-007
title: Fix Mojo 1.1.0 compiler deprecation warnings in core/src/abi.mojo
status: To Do
assignee: []
created_date: '2026-09-28 18:45'
labels: []
dependencies: []
priority: low
type: chore
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`task core:build` (and therefore `task dev` / `task run`) compiles cleanly today but emits two classes of compiler warnings against the pinned Mojo 1.1.0 toolchain (`MOJO_VERSION` in `taskfiles/core.yml`), all localized to `core/src/abi.mojo`:

1. `positional __getitem__ is deprecated, use unsafe_offset= instead` — pointer-like indexing using the bare `ptr[i]` / `value()[i]` form.
2. `transfer from an owned value has no effect and can be removed` — trailing `^` transfer sigils on values already being consumed or returned (e.g. `)^` at the end of a constructor call).

Neither class fails the build or `task check` today, but both indicate reliance on syntax the toolchain is already flagging for removal. Since Mojo is pinned to an exact version, a future bump to unpin or advance `MOJO_VERSION` could turn these into hard compile errors with no warning. Cleaning them up now keeps `task core:build` output free of noise, making it easier to spot a genuinely new warning later.

Ruleset/architecture context for the eventual reader: `core/src/abi.mojo` is the sole `@export` source for the frozen C ABI (`include/dopewars.h`); see `docs/abi-contract.md` and the "Target architecture (Godot port)" section of `AGENTS.md`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `task core:build` output contains zero `warning:` lines from `core/src/abi.mojo`
- [ ] #2 All positional `ptr[i]` / `value()[i]` indexing in `core/src/abi.mojo` is migrated to the `unsafe_offset=` keyword form
- [ ] #3 All flagged redundant `^` transfer sigils in `core/src/abi.mojo` are removed
- [ ] #4 `task core:test` (Mojo parity fixture replay) still passes after the changes
- [ ] #5 `task abi:check` and `task abi:conformance` still pass after the changes
<!-- AC:END -->
