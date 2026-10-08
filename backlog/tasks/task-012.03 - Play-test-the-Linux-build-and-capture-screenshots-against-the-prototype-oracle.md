---
id: TASK-012.03
title: Play-test the Linux build and capture screenshots against the prototype oracle
status: In Progress
assignee:
  - '@claude'
created_date: '2026-10-01 21:00'
updated_date: '2026-10-04 01:41'
labels: []
dependencies:
  - TASK-012.02
parent_task_id: TASK-012
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
With a working Linux export (TASK-012.02), play the game interactively on mf and capture visual evidence that it matches the web prototype (`index.html`) for the same seed, so parity can be checked by eye without the macOS desktop.

`mf` has no Xvfb installed. It does have `sway`, `wtype`, and `grim`, which is what `~/git/neo_snake`'s `decision-025 - Parity-capture-via-sway-wtype-grim-not-xvfb-run.md` and `tools/capture_parity.sh` already use successfully for the same AlmaLinux host. Important finding from that prior work: under headless sway, `wtype` keyboard events reach the Godot window but do **not** change game state — Godot has to be driven by a debug command-line hook instead (neo_snake's `--capture-state=<state>` user arg, handled in `game/presentation/screens/game_screen.gd`). Real `wtype` input is only reliable for the browser-based oracle side (Firefox/Chromium loading `index.html?seed=<n>`).

Gameplay *correctness* (does the Mojo core produce the right values) is already covered headlessly by `task core:test`, `task bridge:test`, and `task game:ui-test` — this task is specifically about producing a human-reviewable visual artifact on Linux, and about actually playing the Linux build interactively (windowed, over the existing noVNC/SSH access to mf) at least once.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A command-line hook (e.g. `--capture-state=<state>`) exists in `game/presentation/main.gd` that drives the running game to a named state (at minimum: boot/day-1 prices, post-buy, post-travel, finances dialog) by calling the same entry points `game:ui-test` already exercises — no duplicated logic
- [x] #2 A new `game:ui-test` case asserts each capture-state hook actually reaches the state it claims to
- [x] #3 A `platforms: [linux]` task (e.g. `task capture:linux -- --seed=42`) starts a headless sway session, launches the exported Linux build with a given seed, and uses `grim` to save one screenshot per captured state to a gitignored output directory
- [ ] #4 The same seed is loaded in `index.html?seed=<n>` under the same headless sway session (browser driven with real `wtype` input) and screenshotted at matching states
- [x] #5 Screenshots from both sides show the same day-1 drug prices for the same seed, confirming the Mojo core and JS oracle agree visually, not just in fixture tests
- [ ] #6 The exported Linux build is launched windowed at least once on mf (e.g. via the existing noVNC/SSH access) and played through a few turns interactively, with any visual or input issues noted
- [ ] #7 Beermat itself is not required to be screenshotted in this task — its RNG cannot be seeded, so side-by-side comparison with the real 1999 executable remains the existing manual TASK-008-style workflow and is out of scope here
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-04 progress. AC#1/#2: `--capture-state=<boot|buy|travel|finances>` in game/presentation/main.gd (Main.drive_capture_state), covered by the `capture_states` ui-test case (17 assertions, floor registered in CASES/CASE_FLOORS; suite 557 assertions); commit 77a1309. AC#3: `task capture:linux -- --seed=42` (taskfiles/capture.yml, tools/capture_parity.sh, platforms: [linux], gitignored artifacts/parity) runs clean on mf, exit 0, 7 PNGs. AC#5: for seed 42 the day-1 market (Acid 3,104 / Cocaine 25,046 / Crack 1,683 / Ecstasy 54 / Hashish 1,244 / Heroin 6,775 / Speed 103 / Weed 316, cash 2,000, debt 5,500, start Bronx), the day-2 market after travelling to Brooklyn (prices and trend arrows, debt 6,050) and the finances figures are identical in the Godot and prototype screenshots, compared by eye. Cosmetic differences seen, not judged: the prototype's dialog title bar is a blue gradient, Godot's is flat navy; Close sits on its own row in the prototype's finances dialog, inline in Godot's.

AC#4 is only partly met: the oracle side is captured for boot, travel and finances with real wtype keystrokes, but NOT for buy. The prototype can only select a drug by clicking a row, and headless sway's seat has no pointer capability (get_seats capabilities 0 until a virtual keyboard exists; then 2 = keyboard only). Tried: swaymsg seat cursor (events dropped), wlrctl built from source (one-shot virtual pointer, no effect), ydotool (needs a libinput backend; WLR_BACKENDS=headless,libinput works but sway then grabs mf's real physical keyboard/power button/video bus, so rejected). Remaining option is a small persistent virtual-pointer helper (wlr-virtual-pointer protocol) -- awaiting Lance's decision. Also lone per-invocation wtype lost keystrokes until one `wtype -s` was held open (neo_snake decision-025).
<!-- SECTION:NOTES:END -->
