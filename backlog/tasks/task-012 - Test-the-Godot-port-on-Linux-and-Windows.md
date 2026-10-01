---
id: TASK-012
title: Test the Godot port on Linux and Windows
status: To Do
assignee: []
created_date: '2026-10-01 21:00'
labels:
  - cross-platform
dependencies: []
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Godot port (core/, extension/, game/) has reached feature parity with Beermat Software's "Dope Wars for Windows" 1.2.0.0 (1999), but has only ever been built, gated, and played on macOS. We now have an AlmaLinux 10.2 x86_64 box (`mf`, reachable over ssh, connection details in `CLAUDE.local.md`) with the repo checked out, and a Windows 11 container on the same box running the real beermat executable as a reference oracle.

This parent task tracks getting the project actually exercised on Linux, and determining what (if anything) is possible on Windows given that Mojo (the simulation core's language) has no native Windows target — only macOS and Linux, with Windows support only via WSL.

Each subtask is independently deliverable; see each subtask for its own acceptance criteria and context.
<!-- SECTION:DESCRIPTION:END -->
