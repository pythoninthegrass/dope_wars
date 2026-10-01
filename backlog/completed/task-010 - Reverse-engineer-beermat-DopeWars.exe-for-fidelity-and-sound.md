---
id: TASK-010
title: Reverse engineer beermat DopeWars.exe for fidelity and sound
status: Done
assignee: []
created_date: '2026-09-30 05:01'
updated_date: '2026-10-01 19:37'
labels:
  - reverse-engineering
dependencies: []
references:
  - CLAUDE.local.md
  - TASK-008
  - TASK-009
priority: medium
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Godot port's rules were reconstructed from secondary sources (benmwebb C source, Keymash web port) plus two oracle play sessions (TASK-008, TASK-009), which found several wrong constants. The real Beermat "Dope Wars for Windows" 1.2.0.0 (1999) binary (`vendor/dopewars-1999/DopeWars.exe`, PE32, Delphi 4, gitignored) is the ground truth. Goal: recover its actual rules by static analysis so the port is faithful with minimal QOL additions, and wire the game's own wav effects to the right events (sound is currently an inert menu).

Constraints and decisions:
- Static analysis with Ghidra headless on macOS; ambiguous points are confirmed on the live oracle described in CLAUDE.local.md (gitignored; never copy its hostnames, ports or credentials into tasks, docs or commits).
- Keep this repo's own 6 boroughs. The oracle's `cities.txt` is a modded list using a "1 city = 6 sub-locations" model that is deliberately not adopted; do not port city names or that model.
- Sound is implemented in Godot only; `index.html` stays the frozen oracle prototype.
- The original wavs are copyrighted: they are copied from gitignored `vendor/dopewars-1999/` at build time and never committed; the game must stay silent and working when they are absent.
- Every engine fix found gets its own subtask and needs Lance's approval before being applied.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Subtasks .01 (extraction tooling), .02 (decompilation and findings doc) and .03 (Godot SFX) are Done
- [x] #2 Every rule delta found between the binary and the engine is either fixed under its own approved subtask or recorded as intentional in docs/parity-deltas.md
- [x] #3 No infra details from CLAUDE.local.md appear in any committed file or backlog task
<!-- AC:END -->
