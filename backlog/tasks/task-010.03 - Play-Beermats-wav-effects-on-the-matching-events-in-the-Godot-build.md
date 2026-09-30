---
id: TASK-010.03
title: Play Beermat's wav effects on the matching events in the Godot build
status: To Do
assignee: []
created_date: '2026-09-30 05:01'
labels:
  - reverse-engineering
  - sound
dependencies:
  - TASK-010.02
parent_task_id: TASK-010
priority: medium
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Sound is currently an inert menu in the Godot port (`game/presentation/hud.gd`, "no sound in this build"). Play the ten original effects (gun, gun2, youhit, cophit, Siren, bark, cashreg, hrdpunch, wasted, uhoh) at the events where the original does, using the trigger points documented in docs/beermat-re.md, and turn the Sounds menu into a checkable Allow Sound item that mirrors the original's AllowSound setting and default. Sound is Godot-only; `index.html` is untouched. The wavs are copyrighted and live only in gitignored `vendor/dopewars-1999/`: a build step copies them into a gitignored game assets directory, and the game must run silently without error when they are absent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A presentation-layer test with an injected recording sound player asserts the cue sequence for a buy/sell round trip, a mugging, a dog chase, a chase with fight, the last day and death
- [ ] #2 Toggling Allow Sound mutes cues and the setting persists across a cold start
- [ ] #3 The game boots and passes the UI test suite with the wavs absent
- [ ] #4 No wav file is committed and the new files are covered by .gitignore
- [ ] #5 New tr() keys resolve; game/README.md, docs/parity-deltas.md, TODO.md and README.md no longer say sound is missing
<!-- AC:END -->
