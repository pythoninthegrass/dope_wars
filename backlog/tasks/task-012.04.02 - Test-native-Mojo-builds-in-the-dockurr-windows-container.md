---
id: TASK-012.04.02
title: Test native Mojo builds in the dockurr/windows container
status: Done
assignee: []
created_date: '2026-10-20 03:37'
labels: []
dependencies: []
parent_task_id: TASK-012.04
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research spike using the running dockurr/windows container (image de1f5a165879, name `windows`) to test whether Mojo builds natively on Windows. Container access is scriptable over SSH: `ssh -p 2222 lance@mf` (lands in PowerShell; SSH keys already work). All package installs go through Chocolatey — install Chocolatey itself first if absent.

Steps:
1. `choco install python3` (or `python312`); verify `python --version` over SSH.
2. `pip install mojo==1.1.0` — the decisive test. Outcomes:
   - No win_amd64 wheel on PyPI → pip error is the hard evidence, stop here.
   - Installs but fails to run → capture the failure, equally conclusive.
   - Installs and runs → build core/src/abi.mojo natively with `mojo build --emit object`, and check the wheel for Windows runtime libs (would contradict current docs and change the conclusion).
3. Checkpoint: only if step 2 fully works, attempt the `libdopewars.dll` link with MSVC — but confirm with the user first, since VS Build Tools is a multi-GB Chocolatey install.
4. Installs are additive; the Beermat 2.1 oracle install in the container is not touched.

Chocolatey is already installed in the container (verified pre-check). Write up findings in the style of docs/mojo-1.1.0-abi-constraints.md.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Chocolatey (and Python, if needed) is installed in the container via choco, with commands captured
- [ ] #2 `pip install mojo==1.1.0` is attempted on native Windows and the exact outcome is captured (any of: no win_amd64 wheel, install fails to run, or install succeeds and runs)
- [ ] #3 If install succeeds and runs, core/src/abi.mojo is built natively and the wheel is checked for Windows runtime libs
- [ ] #4 Findings are appended to docs/mojo-windows-probe.md (Phase B section)
- [ ] #5 The Beermat 2.1 oracle install is verified untouched
<!-- AC:END -->
