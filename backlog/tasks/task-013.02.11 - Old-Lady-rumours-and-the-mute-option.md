---
id: TASK-013.02.11
title: Old Lady rumours and the mute option
status: To Do
assignee: []
created_date: '2026-10-11 04:03'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.01
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.02
ordinal: 64000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2.1 shows an Old Lady dialog ("An old lady on the aeroplane says: ...") with phrases from `oldlady.txt`, which can include the player's name (2.1 changelog), and an option "Mute the old lady on the subway". The phrase file is in the installer payload and is copyrighted text from the vendor tree; it must not be committed. Decide from the findings when the dialog appears (a travel event and its odds) and how a phrase is picked, then implement the trigger and draw in the core (the phrase index only, as rules data does not belong in GDScript), the dialog with name substitution in Godot, and the mute setting. The phrase text must be loaded at build time from gitignored `vendor/dopewars-2001/game/oldlady.txt` and the game must run without it, silently skipping the event, as the sound work does for wavs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The Old Lady appears at the odds and moments the findings document, and the core draws the phrase index deterministically
- [ ] #2 Phrases containing the player's name show it substituted
- [ ] #3 The mute option suppresses the dialog without changing the RNG stream, as documented
- [ ] #4 The phrase file is never committed; the game runs without it and skips the event, covered by game:ui-test
- [ ] #5 Mojo tests pin the trigger and the draw; strings and settings follow project conventions
<!-- AC:END -->
