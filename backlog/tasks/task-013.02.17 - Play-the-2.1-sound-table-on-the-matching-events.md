---
id: TASK-013.02.17
title: Play the 2.1 sound table on the matching events
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
updated_date: '2026-10-11 04:15'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.05
  - TASK-013.02.07
  - TASK-013.02.08
  - TASK-013.02.09
  - TASK-013.02.12
references:
  - game/platform/sound_player.gd
  - TASK-010.03
documentation:
  - docs/beermat-2.1-re.md
  - docs/parity-deltas.md
parent_task_id: TASK-013.02
ordinal: 70000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2.1 ships 38 wavs (weapon fire and hit per weapon, jail door, chainsaw, window, hospital, store, borrow, airport, warnings, headlines, last day and more) versus the ten cues of 1.2 that `game/platform/sound_player.gd` plays today (TASK-010.03). Extend the event-to-file table from the 2.1 findings and play each cue at its trigger in the Godot build, skipping cues for features not ported (airport). The wavs are copyrighted and never committed: copy them at build time from gitignored `vendor/dopewars-2001/game/Sounds/` (written by `task re:unwise`) the way `task game:sounds` does for 1.2, and the game must run silently without them. Needs the feature slices whose events trigger the cues.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every ported event with a 2.1 cue plays it at the trigger the findings document
- [ ] #2 task game:sounds copies the 2.1 wavs from vendor/dopewars-2001/game/Sounds/ and no wav or .import sidecar is tracked by git
- [ ] #3 The game runs without error when the wavs are absent
- [ ] #4 docs/parity-deltas.md section 7 and docs/beermat-2.1-re.md list the sound table and the cues skipped for unported features
<!-- AC:END -->
